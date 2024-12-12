//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 12/12/2024.
//

import Foundation

public enum DecodingError: Error {
    case typeMismatch
}

public protocol ResponseDecoder {
    func decode<T: Decodable>(data: Data) throws -> T
}

// MARK: Concrete Implementation

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
