//
//  File.swift
//
//
//  Created by elfenlaid on 15.03.21.
//

import Collections
import Combine
import Foundation
import Logging

public final class QueueThroughputStrategy<Context: Scheduler, Limit: UnsignedInteger>: ThroughputStrategy {
    let scheduler: Context
    let interval: Context.SchedulerTimeType.Stride
    let rate: Limit

    private var id = UUID()
    private var queue = Deque<Action>()
    private var balance: Limit
    private var isRestoreScheduled: Bool = false
    private var isDequeueing: Bool = false
    private let lock = NSRecursiveLock()
    private let logger: Logger

    public init(rate: Limit, interval: Context.SchedulerTimeType.Stride, scheduler: Context) {
        self.scheduler = scheduler
        self.interval = interval
        self.rate = rate
        self.balance = rate
        self.logger = log.with(metadata: [
            "id": "\(UUID())",
            "strategy": "QueueThroughputStrategy"
        ])
    }

    public func requestThroughput(_ action: @escaping Action) {
        lock.lock()
        defer { lock.unlock() }

        queue.append(action)
        dequeueIfNeeded()
    }

    private func scheduleBalanceRestore() {
        lock.lock()
        defer { lock.unlock() }

        if isRestoreScheduled { return }
        isRestoreScheduled = true

        logger.trace("Balance restore scheduled...")

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
        logger.trace("Balance restored")

        balance = rate
    }

    private func dequeueIfNeeded() {
        logger.trace("Checking deque requisites...")

        guard queue.count > 0 else {
            logger.trace("Dequeue skipped: no queued requests")
            return
        }

        guard balance > 0 else {
            logger.trace("Dequeue skipped: no balance, queued: \(queue.count)")
            return
        }

        let actions = queue.prefix(Int(balance))
        logger.trace("Dequed actions: \(actions.count)")

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
}
