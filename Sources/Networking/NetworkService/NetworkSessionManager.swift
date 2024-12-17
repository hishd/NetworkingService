//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 10/12/2024.
//

import Foundation

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

// MARK: Concrete implementation

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
