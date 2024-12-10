//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 10/12/2024.
//

import Foundation
import OSLog

public protocol NetworkLogger {
    func log(request: URLRequest)
    func log(responseData data: Data?, response: URLResponse?)
    func log(error: Error)
}

public enum NetworkLoggerType {
    case defaultType
    case customType(type: NetworkLogger)
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

// MARK: Concrete Implementation

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
