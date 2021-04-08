//
//  File.swift
//  
//
//  Created by elfenlaid on 15.03.21.
//

import Foundation

public protocol LimitStrategy { // throughput
    typealias Action = () -> Void

    func enqueue(_ action: @escaping Action) // request
}
