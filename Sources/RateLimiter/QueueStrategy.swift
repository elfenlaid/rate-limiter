//
//  File.swift
//  
//
//  Created by elfenlaid on 15.03.21.
//

import Foundation
import Combine

extension Publishers.RateLimiter {
    public static func queue<S: Scheduler, Limit: UnsignedInteger>(rate: Limit, interval: S.SchedulerTimeType.Stride, scheduler: S) -> LimitStrategy {
        QueueLimiter(rate: rate, interval: interval, scheduler: scheduler)
    }
}

public final class QueueLimiter<Context: Scheduler, Limit: UnsignedInteger>: LimitStrategy {
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

    public func enqueue(_ action: @escaping Action) {
        lock.lock()
        defer { lock.unlock() }

        queue.append(action)
        dequeueIfNeeded()
    }

    private func scheduleBalanceRestore() {
        if isRestoreScheduled { return }
        isRestoreScheduled = true

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
        guard queue.count > 0, balance > 0, !isDequeueing else {
            return
        }

        isDequeueing = true

        scheduler.schedule { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            let actions = self.queue.prefix(Int(self.balance))
            print("Actions count: \(actions.count)")
            self.queue.removeFirst(actions.count)
            self.balance -= Limit(actions.count)

            // Schedule restore on deque?
            self.scheduleBalanceRestore()

            for action in actions {
                action()
            }

            self.isDequeueing = false
        }
    }

    private var queue: [Action] = []
}
