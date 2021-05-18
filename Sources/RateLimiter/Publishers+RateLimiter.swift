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

import Combine
import Foundation
import Logging

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
        private let logger: Logger

        init(upstream: Upstream, downstream: Downstream, limiter: ThroughputStrategy) {
            self.upstream = upstream
            self.downstream = downstream
            self.limiter = limiter
            self.logger = log.with(metadata: [
                "id": "\(UUID())",
                "type": "RateLimiter",
                "upstream": "\(upstream)",
            ])
        }

        private func requestThroughput() {
            guard demand > 0, subscription != nil else {
                return
            }

            logger.trace("Requesting strategy throughput...")

            limiter.requestThroughput { [weak self] in
                self?.logger.trace("Strategy throughput received")

                guard let self = self else { return }

                self.lock.lock()
                defer { self.lock.unlock() }

                self.logger.trace("Requesting upstream input...")

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

        logger.trace("Demand received: \(demand)")

        self.demand += demand
        requestThroughput()
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }

        logger.trace("Subscription cancelled")

        subscription?.cancel()
        subscription = nil
    }
}

extension Publishers.RateLimiter.Inner: Subscriber {
    func receive(subscription: Subscription) {
        logger.trace("Subscription received: \(subscription)")
        self.subscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        lock.lock()
        defer { lock.unlock() }

        logger.trace("Upstream input received: \(input)")

        demand += downstream.receive(input)
        requestThroughput()
        return .none
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        logger.trace("Upstream completed with: \(completion)")

        downstream.receive(completion: completion)
    }
}
