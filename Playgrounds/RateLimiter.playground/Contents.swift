import UIKit
import RateLimiter
import CombineSchedulers
import Combine

let scheduler = DispatchQueue.testScheduler
let strategy = QueueLimiter(rate: UInt(3), interval: .seconds(1), scheduler: scheduler)

var cancellables = Set<AnyCancellable>()

(1...5).publisher
    .rateLimited(by: strategy)
    .sink(receiveValue: {
        print($0)
    })
    .store(in: &cancellables)

(6...10).publisher
    .rateLimited(by: strategy)
    .sink(receiveValue: {
        print($0)
    })
    .store(in: &cancellables)

scheduler.advance(by: .seconds(1))

cancellables.removeAll()
