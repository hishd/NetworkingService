//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 10/12/2024.
//

import Foundation

public protocol CancellableHttpRequest {
    func cancel()
}

public class CancellableHttpRequestCollection {
    private(set) var requests: [CancellableHttpRequest] = []
    
    func add(request: CancellableHttpRequest) {
        requests.append(request)
    }
    
    func cancelAll() {
        for request in requests {
            request.cancel()
        }
    }
}
