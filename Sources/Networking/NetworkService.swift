//
//  NetworkService.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation
import OSLog

public enum NetworkError: Error {
    case error(statusCode: Int, data: Data?)
    case notConnected
    case cancelled
    case generic(error: Error)
    case urlGeneration
}

public extension NetworkError {
    var isNotFoundError: Bool {
        hasStatusCode(404)
    }
    
    private func hasStatusCode(_ errorCode: Int) -> Bool {
        switch self {
        case .error(let code, _):
            return code == errorCode
        default:
            return false
        }
    }
}

public protocol CancellableHttpRequest {
    func cancel()
}

public class CancellableHttpRequestCollection {
    private (set) var requests: [CancellableHttpRequest] = []
    
    func add(request: CancellableHttpRequest) {
        requests.append(request)
    }
    
    func cancelAll() {
        for request in requests {
            request.cancel()
        }
    }
}

extension URLSessionDataTask: CancellableHttpRequest{}

public protocol NetworkService {
    typealias CompletionHandler = (Result<Data?, NetworkError>) -> Void
    typealias TaskType = Task<Data, Error>
    
    func request(endpoint: any RequestableEndpoint, completion: @escaping CompletionHandler) -> CancellableHttpRequest?
    @available(iOS 16, *)
    @available(macOS 10.15, *)
    func request(endpoint: any RequestableEndpoint) async -> TaskType
}

public protocol NetworkSessionManager {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    typealias TaskType = Task<(Data, URLResponse), Error>
    
    func request(_ request: URLRequest, completion: @escaping CompletionHandler) -> CancellableHttpRequest
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    func request(_ request: URLRequest) async throws -> TaskType
}

public enum NetworkSessionManagerType {
    case defaultType
    case customType(type: NetworkSessionManager)
}

public protocol NetworkLogger {
    func log(request: URLRequest)
    func log(responseData data: Data?, response: URLResponse?)
    func log(error: Error)
}

public enum NetworkLoggerType {
    case defaultType
    case customType(type: NetworkLogger)
}

//MARK: Concrete Implementation

public extension NetworkSessionManagerType {
    var sessionManager: NetworkSessionManager {
        switch self {
        case .defaultType:
            return DefaultNetworkSessionManager()
        case .customType(let customType):
            return customType
        }
    }
}

public extension NetworkLoggerType {
    var logger: NetworkLogger {
        switch self {
        case .defaultType:
            return DefaultNetworkDataLogger()
        case .customType(let customType):
            return customType
        }
    }
}

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

public final class DefaultNetworkSessionManager: NetworkSessionManager {
    public init(){}
    
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    public func request(_ request: URLRequest) async throws -> TaskType {
        let task = TaskType {
            return try await URLSession.shared.data(for: request)
        }
        
        return task
    }
    
    public func request(_ request: URLRequest, completion: @escaping CompletionHandler) -> any CancellableHttpRequest {
        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
        task.resume()
        return task
    }
}

public final class DefaultNetworkDataLogger: NetworkLogger {
    public init(){}
    #if os(iOS)
    private func printData(request: URLRequest) {
        Logger.viewCycle.error("----NETWORK REQUEST----")
        Logger.viewCycle.error("Request: \(request.url!)")
        Logger.viewCycle.error("Headers: \(request.allHTTPHeaderFields!)")
        Logger.viewCycle.error("Method: \(request.httpMethod!)")
    }
    #elseif os(macOS)
    private func printData(request: URLRequest) {
        print("----NETWORK REQUEST----")
        print("Request: \(request.url!)")
        print("Headers: \(request.allHTTPHeaderFields!)")
        print("Method: \(request.httpMethod!)")
    }
    #endif
    
    public func log(request: URLRequest) {
        printData(request: request)
        
        if let httpBody = request.httpBody, let result = String(data: httpBody, encoding: .utf8) {
            printIfDebug(result)
        }
    }
    
    public func log(responseData data: Data?, response: URLResponse?) {
        guard let data = data else {
            return
        }
        
        if let dataDict = String(data: data, encoding: .utf8) {
            printIfDebug(dataDict)
        }
    }
    
    public func log(error: any Error) {
        printIfDebug("\(error)")
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
