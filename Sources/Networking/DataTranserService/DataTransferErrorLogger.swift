//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation

public protocol NetworkDataTransferErrorLogger {
    func log(error: Error)
}

// MARK: Concrete Implementation

public final class DefaultNetworkDataTransferErrorLogger: NetworkDataTransferErrorLogger {
    public init(){}
    public func log(error: any Error) {
        printIfDebug("\(error)")
    }
}
