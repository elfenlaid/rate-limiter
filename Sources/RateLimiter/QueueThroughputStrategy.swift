// RateLimiter
//
// Copyright (c) 2021 elfenlaid
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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
