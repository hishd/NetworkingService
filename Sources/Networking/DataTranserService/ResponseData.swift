//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation

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
