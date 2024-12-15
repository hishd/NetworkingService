//
//  File.swift
//  NetworkingService
//
//  Created by Hishara Dilshan on 13/12/2024.
//

import Foundation
import OSLog

func printIfDebug(_ text: String) {
    #if DEBUG
        #if os(iOS)
            Logger.viewCycle.error("\(text)")
        #elseif os(macOS)
            print("\(text)")
        #endif
    #endif
}
