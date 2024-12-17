//
//  NetworkService.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation
import OSLog

public protocol NetworkService {
    typealias CompletionHandler = (Result<Data?, NetworkError>) -> Void
    typealias TaskType = Task<Data, Error>
    
    func request(endpoint: any RequestableEndpoint, completion: @escaping CompletionHandler) -> CancellableHttpRequest?
    @available(iOS 16, *)
    @available(macOS 10.15, *)
    func request(endpoint: any RequestableEndpoint) async -> TaskType
}

//MARK: Concrete Implementation

public final class DefaultNetworkService {
    private let networkConfig: ApiNetworkConfig?
    private let sessionManagerType: NetworkSessionManagerType
    private let loggerType: NetworkLoggerType
    
    public init(networkConfig: ApiNetworkConfig?, sessionManagerType: NetworkSessionManagerType, loggerType: NetworkLoggerType) {
        self.networkConfig = networkConfig
        self.sessionManagerType = sessionManagerType
        self.loggerType = loggerType
    }
    
    private func request(request: URLRequest, completion: @escaping CompletionHandler) -> CancellableHttpRequest {
        let dataTask = sessionManagerType.sessionManager.request(request) { data, response, requestError in
            if let response = response as? HTTPURLResponse, !(200...300).contains(response.statusCode) {
                let error: NetworkError = .error(statusCode: response.statusCode, data: data)
                self.loggerType.logger.log(error: error)
                completion(.failure(error))
                return
            }
            
            if let requestError = requestError {
                let error: NetworkError
                if let response = response as? HTTPURLResponse {
                    error = .error(statusCode: response.statusCode, data: data)
                } else {
                    error = self.resolve(error: requestError)
                }
                
                self.loggerType.logger.log(error: error)
                completion(.failure(error))
            } else {
                self.loggerType.logger.log(responseData: data, response: response)
                completion(.success(data))
            }
        }
        
        loggerType.logger.log(request: request)
        
        return dataTask
    }
    
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    private func request(request: URLRequest) async throws -> TaskType {
        let task = TaskType {
            do {
                let (data, response) = try await sessionManagerType.sessionManager.request(request).value
    
                if let response = response as? HTTPURLResponse, !(200...300).contains(response.statusCode) {
                    let error: NetworkError = .error(statusCode: response.statusCode, data: data)
                    self.loggerType.logger.log(error: error)
                    throw error
                }
    
                self.loggerType.logger.log(responseData: data, response: response)
                return data
            } catch {
                self.loggerType.logger.log(error: error)
                throw self.resolve(error: error)
            }
        }
        
        return task
    }
    
    private func resolve(error: Error) -> NetworkError {
        let code = URLError.Code(rawValue: (error as NSError).code)
        switch code {
        case .notConnectedToInternet:
            return .notConnected
        case .cancelled:
            return .cancelled
        default:
            return .generic(error: error)
        }
    }
}

extension DefaultNetworkService: NetworkService {
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    public func request(endpoint: any RequestableEndpoint) async -> TaskType {
        let task = TaskType {
            do {
                let request = try endpoint.urlRequest(with: networkConfig)
                return try await self.request(request: request).value
            } catch let error as NetworkError {
                throw error
            } catch {
                throw NetworkError.urlGeneration
            }
        }
        
        return task
    }
    
    public func request(endpoint: any RequestableEndpoint, completion: @escaping CompletionHandler) -> (any CancellableHttpRequest)? {
        do {
            let request = try endpoint.urlRequest(with: networkConfig)
            return self.request(request: request, completion: completion)
        } catch let error as NetworkError {
            completion(.failure(error))
            return nil
        } catch {
            completion(.failure(.urlGeneration))
            return nil
        }
    }
}

func printIfDebug(_ text: String) {
    #if DEBUG
        #if os(iOS)
            Logger.viewCycle.error("\(text)")
        #elseif os(macOS)
            print("\(text)")
        #endif
    #endif
}
