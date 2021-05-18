import Logging

struct RateLimiter {
    static func setLogLevel(_ level: Logger.Level) {
        log.logLevel = level
    }
}
