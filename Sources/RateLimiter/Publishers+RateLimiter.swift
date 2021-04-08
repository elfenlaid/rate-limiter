//
//  File.swift
//
//
//  Created by elfenlaid on 15.03.21.
//

import Combine
import Foundation

public extension Publisher {
    func rateLimited<S: Scheduler>(by rate: UInt, per interval: S.SchedulerTimeType.Stride, scheduler: S) -> Publishers.RateLimiter<Self> {
        rateLimited(by: QueueThroughputStrategy(rate: rate, interval: interval, scheduler: scheduler))
    }

    func rateLimited(by strategy: ThroughputStrategy) -> Publishers.RateLimiter<Self> {
        Publishers.RateLimiter(
            upstream: self,
            limiter: strategy
        )
    }
}

public extension Publishers {
    struct RateLimiter<Upstream>: Publisher where Upstream: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure

        let upstream: Upstream
        let limiter: ThroughputStrategy

        public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            let inner = Inner(upstream: upstream, downstream: subscriber, limiter: limiter)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.RateLimiter {
    final class Inner<Upstream: Publisher, Downstream: Subscriber>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        let upstream: Upstream
        let downstream: Downstream
        let limiter: ThroughputStrategy
        private let lock = NSRecursiveLock()
        private var subscription: Subscription?
        private var demand: Subscribers.Demand = .none

        init(upstream: Upstream, downstream: Downstream, limiter: ThroughputStrategy) {
            self.upstream = upstream
            self.downstream = downstream
            self.limiter = limiter
        }

        private func requestThroughput() {
            guard demand > 0, subscription != nil else {
                return
            }

            Swift.print("Enquing throughput for \(upstream)")

            limiter.requestThroughput { [weak self] in
                guard let self = self else { return }

                Swift.print("Recieved through for \(self.upstream)")

                self.lock.lock()
                defer { self.lock.unlock() }

                self.demand -= 1
                self.subscription?.request(.max(1))
            }
        }
    }
}

extension Publishers.RateLimiter.Inner: Subscription {
    func request(_ demand: Subscribers.Demand) {
        lock.lock()
        defer { lock.unlock() }

        print("request(_ demand: \(demand))")
        self.demand += demand
        requestThroughput()
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }

        print(#function)
        subscription?.cancel()
        subscription = nil
    }
}

extension Publishers.RateLimiter.Inner: Subscriber {
    func receive(subscription: Subscription) {
        print("receive(subscription: \(subscription))")
        self.subscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        lock.lock()
        defer { lock.unlock() }

        print("receive(_ input: \(input))")
        demand += downstream.receive(input)
        requestThroughput()
        return .none
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        print("receive(completion: \(completion))")
        downstream.receive(completion: completion)
    }
}
