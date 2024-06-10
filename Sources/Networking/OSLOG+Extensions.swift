//
//  OSLOG+Extensions.swift
//  NetworkingSample
//
//  Created by Hishara Dilshan on 2024-06-09.
//

import Foundation
import OSLog

#if !os(macOS)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")
//    Logger.viewCycle.notice("Notice example")
//    Logger.viewCycle.info("Info example")
//    Logger.viewCycle.debug("Debug example")
//    Logger.viewCycle.trace("Trace example")
//    Logger.viewCycle.warning("Warning example")
//    Logger.viewCycle.error("Error example")
//    Logger.viewCycle.fault("Fault example")
//    Logger.viewCycle.critical("Critical example")
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
//    Logger.statistics.debug("Statistics example")
}
#endif
