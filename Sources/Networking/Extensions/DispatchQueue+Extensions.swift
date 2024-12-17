//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation

extension DispatchQueue: NetworkDataTransferQueue {
    public func asyncExecute(work: @escaping () -> Void) {
        async(group: nil, execute: work)
    }
}
