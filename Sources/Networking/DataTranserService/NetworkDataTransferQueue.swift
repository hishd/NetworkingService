//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation

public protocol NetworkDataTransferQueue {
    func asyncExecute(work: @escaping () -> Void)
}
