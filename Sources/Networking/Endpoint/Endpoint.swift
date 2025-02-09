//
//  Endpoint.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation

public enum PathType {
    case urlPath(String)
    case path(String)
}

public enum HttpEndpointGenerationError: Error {
    case componentsError
    case urlGenerationError
}

public protocol RequestableEndpoint {
    
    associatedtype ResponseType
    
    var path: PathType {get}
    var method: HTTPMethodType {get}
    var headerParameters: [String: String] {get}
    var queryParameters: [String: Any] {get}
    var bodyParameters: [String: Any] {get}
    var timeout: TimeInterval {get}
    var responseDecoder: any ResponseDecoder {get}
    
    func urlRequest(with networkConfig: ApiNetworkConfig?) throws -> URLRequest
}

public extension RequestableEndpoint {
    private func url(with networkConfig: ApiNetworkConfig?) throws -> URL {
        let endpoint: String
        
        switch path {
        case .urlPath(let path):
            endpoint = path
        case .path(let path):
            if let baseUrl = networkConfig?.baseUrl {
                let url = baseUrl.absoluteString.last != "/" ? baseUrl.absoluteString + "/" : baseUrl.absoluteString
                endpoint = url.appending(path)
            } else {
                throw HttpEndpointGenerationError.urlGenerationError
            }
        }
        
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw HttpEndpointGenerationError.componentsError
        }
        
        var queryItems: [URLQueryItem] = []
        
        self.queryParameters.forEach { (key, value) in
            queryItems.append(URLQueryItem(name: key, value: "\(value)"))
        }
        
        networkConfig?.queryParameters.forEach { (key, value) in
            queryItems.append(URLQueryItem(name: key, value: "\(value)"))
        }
        
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = urlComponents.url else {
            throw HttpEndpointGenerationError.urlGenerationError
        }
        
        return url
    }
    
    func urlRequest(with networkConfig: ApiNetworkConfig?) throws -> URLRequest {
        let url = try self.url(with: networkConfig)
        var urlRequest = URLRequest(url: url)
        var allHeaders: [String: String] = networkConfig?.headers ?? .init()
        headerParameters.forEach { (key, value) in
            allHeaders.updateValue(value, forKey: key)
        }
        
        if !self.bodyParameters.isEmpty {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyParameters)
        }
        
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = allHeaders
        urlRequest.timeoutInterval = timeout
        
        return urlRequest
    }
}

// MARK: Concrete Implementation

public final class ApiEndpoint<T>: RequestableEndpoint {
    public typealias ResponseType = T
    
    public let path: PathType
    public let method: HTTPMethodType
    public let headerParameters: [String : String]
    public let queryParameters: [String : Any]
    public let bodyParameters: [String : Any]
    public let timeout: TimeInterval
    public let responseDecoder: any ResponseDecoder
    
    public init(
        path: PathType,
        method: HTTPMethodType,
        headerParameters: [String : String] = [:],
        queryParameters: [String : Any] = [:],
        bodyParameters: [String : Any] = [:],
        timeout: TimeInterval = 60.0,
        responseDecoder: any ResponseDecoder = JsonResponseDecoder()
    ) {
        self.path = path
        self.method = method
        self.headerParameters = headerParameters
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
        self.timeout = timeout
        self.responseDecoder = responseDecoder
    }
}
