//
//  NetworkDataTransferService.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-10.
//

import Foundation

public protocol NetworkDataTransferErrorLogger {
    func log(error: Error)
}

public final class DefaultNetworkDataTransferErrorLogger: NetworkDataTransferErrorLogger {
    public init(){}
    public func log(error: any Error) {
        printIfDebug("\(error)")
    }
}

public struct ResponseData<T> {
    private(set) var results: [T]
    private(set) var errors: [NetworkDataTransferError]
    
    mutating func addResult(result: T) {
        self.results.append(result)
    }
    
    mutating func addError(error: NetworkDataTransferError) {
        self.errors.append(error)
    }
}

public protocol NetworkDataTransferService {
    typealias CompletionHandler<T> = (Result<T, NetworkDataTransferError>) -> Void
    typealias CompletionHandlerCollection<T> = (Result<ResponseData<T>, NetworkDataTransferError>) -> Void
    typealias TaskType<T> = Task<T, Error>
    typealias TaskTypeCollection<T> = Task<[T], Error>
    
    func request<T: Decodable, E: RequestableEndpoint>(
        with endpoint: E,
        on queue: NetworkDataTransferQueue?,
        completion: @escaping CompletionHandler<T>
    ) -> CancellableHttpRequest? where E.ResponseType == T
    
    func request<T: Decodable, E: RequestableEndpoint>(
        with endpoints: [E],
        on queue: NetworkDataTransferQueue,
        completion: @escaping CompletionHandlerCollection<T>
    ) -> CancellableHttpRequestCollection where E.ResponseType == T
    
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
    
    private func executeRequest<E: RequestableEndpoint ,T: Decodable>(endpoint: E, group: DispatchGroup, completion: @escaping CompletionHandler<T>) -> CancellableHttpRequest? where T == E.ResponseType {
        group.enter()
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
            
            group.leave()
        }
    }
}

extension DefaultNetworkDataTransferService: NetworkDataTransferService {
    
    public func request<T: Decodable, E: RequestableEndpoint>(with endpoints: [E], on queue: any NetworkDataTransferQueue = DispatchQueue.global(), completion: @escaping CompletionHandlerCollection<T>) -> CancellableHttpRequestCollection where T == E.ResponseType {
        let dispatchGroup = DispatchGroup()
        let requestCollection = CancellableHttpRequestCollection()
        var responseData = ResponseData<T>(results: .init(), errors: .init())
        
        for endpoint in endpoints {
            let request = self.executeRequest(endpoint: endpoint, group: dispatchGroup) { result in
                switch result {
                case .success(let data):
                    responseData.addResult(result: data)
                case .failure(let error):
                    self.logger.log(error: error)
                    responseData.addError(error: error)
                }
            }
            
            if let request = request {
                requestCollection.add(request: request)
            }
        }
        
        dispatchGroup.notify(queue: queue as! DispatchQueue) {
            printIfDebug("====Notifying from group====")
            completion(.success((responseData)))
        }
        
        return requestCollection
    }
    
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
        on queue: (any NetworkDataTransferQueue)? = nil,
        completion: @escaping (Result<T, NetworkDataTransferError>) -> Void
    ) -> (any CancellableHttpRequest)? where E.ResponseType == T {
        
        return networkService.request(endpoint: endpoint) { result in
            let completionResult: Result<T, NetworkDataTransferError>
            
            defer {
                if let queue = queue {
                    queue.asyncExecute {
                        completion(completionResult)
                    }
                }
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
