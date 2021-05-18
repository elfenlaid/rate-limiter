//
//  File.swift
//  
//
//  Created by elfenlaid on 2021-05-18.
//

import Foundation
import Logging

var log = Logger.makeLogger()

extension Logger {
    static func makeLogger() -> Logger {
        var logger = Logger(label: "com.rate-limitter.logs")
        logger.logLevel = .critical
        return logger
    }

    func with(metadata: Metadata) -> Logger {
        var logger = self

        metadata.forEach { (key, value) in
            logger[metadataKey: key] = value
        }

        return logger
    }
}

