//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 10/12/2024.
//

import Foundation

public enum NetworkError: Error {
    case error(statusCode: Int, data: Data?)
    case notConnected
    case cancelled
    case timedOut
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
