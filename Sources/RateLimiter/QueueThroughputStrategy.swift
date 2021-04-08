//
//  File.swift
//  
//
//  Created by elfenlaid on 15.03.21.
//

import Foundation
import Combine

extension Publishers.RateLimiter {
    public static func queue<S: Scheduler, Limit: UnsignedInteger>(rate: Limit, interval: S.SchedulerTimeType.Stride, scheduler: S) -> ThroughputStrategy {
        QueueThroughputStrategy(rate: rate, interval: interval, scheduler: scheduler)
    }
}

public final class QueueThroughputStrategy<Context: Scheduler, Limit: UnsignedInteger>: ThroughputStrategy {
    let scheduler: Context
    let interval: Context.SchedulerTimeType.Stride
    let rate: Limit

    private var balance: Limit
    private var isRestoreScheduled: Bool = false
    private var isDequeueing: Bool = false
    private let lock = NSRecursiveLock()

    public init(rate: Limit, interval: Context.SchedulerTimeType.Stride, scheduler: Context) {
        self.scheduler = scheduler
        self.interval = interval
        self.rate = rate
        self.balance = rate
    }

    public func requestThroughput(_ action: @escaping Action) {
        lock.lock()
        defer { lock.unlock() }

        queue.append(action)
        dequeueIfNeeded()
    }

    private func scheduleBalanceRestore() {
        print(#function)

        lock.lock()
        defer { lock.unlock() }

        if isRestoreScheduled { return }
        isRestoreScheduled = true

        print("Restore scheduled")

        scheduler.schedule(after: scheduler.now.advanced(by: interval), tolerance: .zero, options: nil) { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            self.isRestoreScheduled = false
            self.restoreBalance()
            self.dequeueIfNeeded()
        }
    }

    private func restoreBalance() {
        print(#function)
        balance = rate
    }

    private func dequeueIfNeeded() {
        print(#function)

        guard queue.count > 0, balance > 0 else {
            print("Dequeue skipped")
            return
        }

        let actions = queue.prefix(Int(self.balance))
        print("Dequed actions count: \(actions.count)")

        queue.removeFirst(actions.count)
        balance -= Limit(actions.count)

        for (i, action) in actions.enumerated() {
            scheduler.schedule { [weak self] in
                action()

                if i == 0 {
                    self?.scheduleBalanceRestore()
                }
            }
        }
    }

    private var queue: [Action] = []
}
