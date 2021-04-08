@testable import RateLimiter
import XCTest
import Combine
import CombineSchedulers

final class RateLimiterTests: XCTestCase {
    func testDeque() {
        let scheduler = DispatchQueue.testScheduler
        let strategy = QueueThroughputStrategy(rate: UInt(1), interval: .seconds(1), scheduler: scheduler)
        var cancellables = Set<AnyCancellable>()

        (1...4).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: {
                print($0)
            })
            .store(in: &cancellables)

        scheduler.advance(by: 4)

        cancellables.removeAll()
    }

    func testOne() {
        let scheduler = DispatchQueue.testScheduler
        let strategy = QueueThroughputStrategy(rate: UInt(3), interval: .seconds(1), scheduler: scheduler)

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

        (11...15).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: {
                print($0)
            })
            .store(in: &cancellables)

        scheduler.advance(by: .seconds(0))

        cancellables.removeAll()
    }
}
