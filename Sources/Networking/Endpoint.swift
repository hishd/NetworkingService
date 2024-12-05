//
//  Endpoint.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation

public enum HTTPMethodType: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case update = "Update"
}

public enum DecodingError: Error {
    case typeMismatch
}

public protocol ResponseDecoder {
    func decode<T: Decodable>(data: Data) throws -> T
}

public final class JsonResponseDecoder: ResponseDecoder {
    public init(){}
    public func decode<T: Decodable>(data: Data) throws -> T {
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public final class RawDataResponseDecoder: ResponseDecoder {
    public init(){}
    public func decode<T: Decodable>(data: Data) throws -> T {
        if T.self is Data.Type, let data = data as? T {
            return data
        } else {
            throw DecodingError.typeMismatch
        }
    }
}

public enum PathType {
    case urlPath(String)
    case path(String)
}

public protocol RequestableEndpoint {
    
    associatedtype ResponseType
    
    var path: PathType {get}
    var method: HTTPMethodType {get}
    var headerParameters: [String: String] {get}
    var queryParameters: [String: Any] {get}
    var bodyParameters: [String: Any] {get}
    var responseDecoder: any ResponseDecoder {get}
    
    func urlRequest(with networkConfig: ApiNetworkConfig?) throws -> URLRequest
}

public final class ApiEndpoint<T>: RequestableEndpoint {
    public typealias ResponseType = T
    
    public let path: PathType
    public let method: HTTPMethodType
    public let headerParameters: [String : String]
    public let queryParameters: [String : Any]
    public let bodyParameters: [String : Any]
    public let responseDecoder: any ResponseDecoder
    
    public init(
        path: PathType,
        method: HTTPMethodType,
        headerParameters: [String : String] = [:],
        queryParameters: [String : Any] = [:],
        bodyParameters: [String : Any] = [:],
        responseDecoder: any ResponseDecoder = JsonResponseDecoder()
    ) {
        self.path = path
        self.method = method
        self.headerParameters = headerParameters
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
        self.responseDecoder = responseDecoder
    }
}


public enum HttpEndpointGenerationError: Error {
    case componentsError
    case urlGenerationError
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
        
        return urlRequest
    }
}
