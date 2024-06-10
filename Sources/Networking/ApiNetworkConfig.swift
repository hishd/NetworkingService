//
//  ApiNetworkConfig.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation

public final class ApiNetworkConfig {
    var baseUrl: URL
    var headers: [String : String]
    var queryParameters: [String : String]
    
    public init(baseUrl: URL, headers: [String : String] = [:], queryParameters: [String : String] = [:]) {
        self.baseUrl = baseUrl
        self.headers = headers
        self.queryParameters = queryParameters
    }
}
