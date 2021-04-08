//
//  File.swift
//  
//
//  Created by elfenlaid on 15.03.21.
//

import Foundation

public protocol ThroughputStrategy {
    typealias Action = () -> Void

    func requestThroughput(_ action: @escaping Action)
}
