//
//  NetworkDataTransferService.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-10.
//

import Foundation

public enum NetworkDataTransferError: Error {
    case noResponse
    case parsing(Error)
    case networkFailure(NetworkError)
    case resolvedNetworkFailure(Error)
}

public protocol NetworkDataTransferQueue {
    func asyncExecute(work: @escaping () -> Void)
}

extension DispatchQueue: NetworkDataTransferQueue {
    public func asyncExecute(work: @escaping () -> Void) {
        async(group: nil, execute: work)
    }
}

public protocol NetworkDataTransferErrorLogger {
    func log(error: Error)
}

public final class DefaultNetworkDataTransferErrorLogger: NetworkDataTransferErrorLogger {
    public init(){}
    public func log(error: any Error) {
        printIfDebug("\(error)")
    }
}

public protocol NetworkDataTransferService {
    typealias CompletionHandler<T> = (Result<T, NetworkDataTransferError>) -> Void
    typealias TaskType<T> = Task<T, Error>
    typealias TaskTypeCollection<T> = Task<[T], Error>
    
    func request<T: Decodable, E: RequestableEndpoint>(
        with endpoint: E,
        on queue: NetworkDataTransferQueue,
        completion: @escaping CompletionHandler<T>
    ) -> CancellableHttpRequest? where E.ResponseType == T
    
    func request<T: Decodable, E: RequestableEndpoint>(
        with endpoint: E,
        completion: @escaping CompletionHandler<T>
    ) -> CancellableHttpRequest? where E.ResponseType == T
    
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    func request<T: Decodable, E: RequestableEndpoint>(with endpoint: E) async -> TaskType<T> where E.ResponseType == T
    
    @available(iOS 16, *)
    @available(macOS 10.15, *)
    func request<T: Decodable, E: RequestableEndpoint>(with endpoints: [E]) async -> TaskTypeCollection<T> where E.ResponseType == T
}

public final class DefaultNetworkDataTransferService {
    private let networkService: NetworkService
    private let logger: NetworkDataTransferErrorLogger
    
    public init(networkService: NetworkService, logger: NetworkDataTransferErrorLogger) {
        self.networkService = networkService
        self.logger = logger
    }
}

extension DefaultNetworkDataTransferService: NetworkDataTransferService {
    
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    public func request<T: Decodable, E: RequestableEndpoint>(with endpoints: [E]) async -> TaskTypeCollection<T> where T == E.ResponseType {
        
        let task: TaskTypeCollection = Task {
            let responseData = try await withThrowingTaskGroup(of: T.self, returning: [T].self) { taskGroup in
                for endpoint in endpoints {
                    taskGroup.addTask {
                        try await self.request(with: endpoint).value
                    }
                }
                
                var data: [T] = []
                
                for try await item in taskGroup {
                    data.append(item)
                }
                
                return data
            }
            
            return responseData
        }
        
        return task
    }
    
    @available(macOS 10.15, *)
    @available(iOS 16, *)
    public func request<T:Decodable, E: RequestableEndpoint>(with endpoint: E) async -> TaskType<T> where T == E.ResponseType {
        let task = Task {
            let responseData = try await networkService.request(endpoint: endpoint).value
            let decodedData:T = try self.decode(data: responseData, decoder: endpoint.responseDecoder)
            
            return decodedData
        }
        
        return task
    }
    
    public func request<T: Decodable, E: RequestableEndpoint>(
        with endpoint: E,
        on queue: any NetworkDataTransferQueue,
        completion: @escaping (Result<T, NetworkDataTransferError>) -> Void
    ) -> (any CancellableHttpRequest)? where E.ResponseType == T {
        
        return networkService.request(endpoint: endpoint) { result in
            let completionResult: Result<T, NetworkDataTransferError>
            
            defer {
                queue.asyncExecute {
                    completion(completionResult)
                }
            }
            
            switch result {
            case .success(let data):
                let result: Result<T, NetworkDataTransferError> = self.decode(data: data, decoder: endpoint.responseDecoder)
                completionResult = result
            case .failure(let error):
                self.logger.log(error: error)
                completionResult = .failure(.networkFailure(error))
            }
        }
        
    }
    
    public func request<T: Decodable, E: RequestableEndpoint>(
        with endpoint: E,
        completion: @escaping (Result<T, NetworkDataTransferError>) -> Void
    ) -> (any CancellableHttpRequest)? where E.ResponseType == T {
        return networkService.request(endpoint: endpoint) { result in
            let completionResult: Result<T, NetworkDataTransferError>
            
            defer {
                completion(completionResult)
            }
            
            switch result {
            case .success(let data):
                let result: Result<T, NetworkDataTransferError> = self.decode(data: data, decoder: endpoint.responseDecoder)
                completionResult = result
            case .failure(let error):
                self.logger.log(error: error)
                completionResult = .failure(.networkFailure(error))
            }
        }
    }
    
    private func decode<T: Decodable>(data: Data?, decoder: ResponseDecoder) -> Result<T, NetworkDataTransferError> {
        do {
            guard let data = data else {
                return .failure(NetworkDataTransferError.noResponse)
            }
            
            let decoded: T = try decoder.decode(data: data)
            return .success(decoded)
        } catch {
            self.logger.log(error: error)
            return .failure(NetworkDataTransferError.parsing(error))
        }
    }
    
    private func decode<T: Decodable>(data: Data?, decoder: ResponseDecoder) throws -> T {
        do {
            guard let data = data else {
                throw NetworkDataTransferError.noResponse
            }
            
            let decoded: T = try decoder.decode(data: data)
            return decoded
        } catch {
            self.logger.log(error: error)
            throw NetworkDataTransferError.parsing(error)
        }
    }
}
