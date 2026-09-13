import Foundation

struct Countdown: Codable, Equatable {
    var duration: TimeInterval = 25 * 60
    var deadline: Date?
    var pausedRemaining: TimeInterval?

    var isRunning: Bool { deadline != nil }
    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: Date) -> TimeInterval {
        if let deadline { return max(0, deadline.timeIntervalSince(now)) }
        return pausedRemaining ?? duration
    }

    mutating func start(seconds: TimeInterval, at now: Date) {
        duration = seconds
        pausedRemaining = nil
        deadline = now.addingTimeInterval(seconds)
    }

    mutating func pause(at now: Date) {
        guard isRunning else { return }
        pausedRemaining = remaining(at: now)
        deadline = nil
    }

    mutating func resume(at now: Date) {
        guard let pausedRemaining else { return }
        deadline = now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
    }

    mutating func reset() {
        deadline = nil
        pausedRemaining = nil
    }

    mutating func finishIfDue(at now: Date) -> Bool {
        guard let deadline, deadline <= now else { return false }
        reset()
        return true
    }

    static func display(_ seconds: TimeInterval) -> String {
        let total = Int(ceil(max(0, seconds)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
