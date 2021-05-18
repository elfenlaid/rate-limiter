import RateLimiter
import CombineSchedulers
import Combine

var cancellables = Set<AnyCancellable>()
defer { cancellables.removeAll() }

let scheduler = DispatchQueue.testScheduler
let strategy = QueueThroughputStrategy(rate: UInt(2), interval: .seconds(1), scheduler: scheduler)

var values: [Int] = []

(1...5).publisher
    .rateLimited(by: strategy)
    .sink(receiveValue: {
        values.append($0)
    })
    .store(in: &cancellables)

(1...5).publisher
    .rateLimited(by: strategy)
    .sink(receiveValue: {
        values.append($0)
    })
    .store(in: &cancellables)

scheduler.advance(by: .seconds(0))

// Rate limiter starts immediately, and throughputs events up to the initial capacity:
print(values) // [1,1]

// Now limiter waits for its interval to pass...
scheduler.advance(by: .seconds(1))

// ... to get another round of values
print(values) // [1,1, 2,2]

// Though, the limit restore starts right after the first value is emmited
