//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation

public enum NetworkDataTransferError: Error {
    case noResponse
    case parsing(Error)
    case networkFailure(NetworkError)
    case resolvedNetworkFailure(Error)
}
