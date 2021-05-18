import Combine
import CombineSchedulers
@testable import RateLimiter
import XCTest

final class RateLimiterTests: XCTestCase {

    override func setUp() {
        super.setUp()

        RateLimiter.setLogLevel(.trace)
    }

    func testQueueRespectsRateLimit() {
        let scheduler = DispatchQueue.testScheduler
        var cancellables = Set<AnyCancellable>()
        let strategy = QueueThroughputStrategy(rate: UInt(1), interval: .seconds(1), scheduler: scheduler)

        var values: [Int] = []

        (1...3).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: { values.append($0) })
            .store(in: &cancellables)

        XCTAssertEqual(values, [])

        scheduler.advance(by: 0)

        XCTAssertEqual(values, [1])

        scheduler.advance(by: 1)

        XCTAssertEqual(values, [1, 2])

        scheduler.advance(by: 1)

        XCTAssertEqual(values, [1, 2, 3])

        cancellables.removeAll()
    }

    func testLimiterCompletes() {
        let scheduler = DispatchQueue.testScheduler
        var cancellables = Set<AnyCancellable>()
        let strategy = QueueThroughputStrategy(rate: UInt(1), interval: .seconds(1), scheduler: scheduler)

        let expectation = expectation(description: #function)
        (1...3).publisher
            .rateLimited(by: strategy)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure: XCTFail()
                    case .finished: expectation.fulfill()
                    }
                },
                receiveValue: { _ in  }
            )
            .store(in: &cancellables)

        scheduler.advance(by: .seconds(2))
        waitForExpectations(timeout: 0, handler: nil)
        cancellables.removeAll()
    }

    func testLimiterCancels() {
        let scheduler = DispatchQueue.testScheduler
        var cancellables = Set<AnyCancellable>()
        let strategy = QueueThroughputStrategy(rate: UInt(1), interval: .seconds(1), scheduler: scheduler)

        let expectation = expectation(description: #function)
        (1...3).publisher
            .rateLimited(by: strategy)
            .handleEvents(receiveCancel: { expectation.fulfill() })
            .sink(
                receiveCompletion: { _ in XCTFail() },
                receiveValue: { _ in  }
            )
            .store(in: &cancellables)

        scheduler.advance(by: .seconds(1))
        cancellables.removeAll()
        scheduler.advance(by: .seconds(0))

        waitForExpectations(timeout: 0, handler: nil)
    }

    func testQueueProcessOperationsInOrder() {
        let scheduler = DispatchQueue.testScheduler
        var cancellables = Set<AnyCancellable>()
        let strategy = QueueThroughputStrategy(rate: UInt(3), interval: .seconds(1), scheduler: scheduler)

        var values: [Int] = []

        (1...3).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: { values.append($0) })
            .store(in: &cancellables)

        (4...6).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: { values.append($0) })
            .store(in: &cancellables)

        (7...9).publisher
            .rateLimited(by: strategy)
            .sink(receiveValue: { values.append($0) })
            .store(in: &cancellables)

        scheduler.advance(by: .seconds(0))

        XCTAssertEqual([1, 4, 7], values)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual([1, 4, 7, 2, 5, 8], values)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual([1, 4, 7, 2, 5, 8, 3, 6, 9], values)

        cancellables.removeAll()
    }
}
