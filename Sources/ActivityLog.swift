import Foundation

struct Activity: Codable {
    var task: String
    var category: String
    var start: Date
    var end: Date
    var reason: String
    var taskID: UUID?
    var sessionID: UUID?
    var seconds: TimeInterval { max(0, end.timeIntervalSince(start)) }
    func seconds(in interval: DateInterval) -> TimeInterval {
        max(0, min(end, interval.end).timeIntervalSince(max(start, interval.start)))
    }
}

struct ActivityLog: Codable {
    struct Active: Codable {
        var task: String
        var category: String
        var start: Date
        var checkpoint: Date
    }
    var entries: [Activity] = []
    var active: Active?
    var completed: [String: Date] = [:]

    mutating func begin(task: String, category: String, at now: Date) {
        finish(at: now, reason: "切换")
        completed.removeValue(forKey: task)
        active = Active(task: task, category: category, start: now, checkpoint: now)
    }
    mutating func checkpoint(at now: Date) { active?.checkpoint = now }
    mutating func finish(at now: Date, reason: String) {
        guard let active else { return }
        let end = max(active.start, now)
        if end > active.start {
            entries.append(Activity(task: active.task, category: active.category, start: active.start, end: end, reason: reason))
        }
        self.active = nil
    }
    mutating func recover() {
        if let active { finish(at: active.checkpoint, reason: "意外退出恢复") }
    }
    func records(at now: Date) -> [Activity] {
        guard let active else { return entries }
        return entries + [Activity(task: active.task, category: active.category, start: active.start, end: max(active.start, now), reason: "进行中")]
    }
    mutating func addManual(_ entry: Activity, now: Date) -> Bool {
        guard !entry.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              entry.start < entry.end, entry.end <= now,
              !records(at: now).contains(where: { $0.start < entry.end && entry.start < $0.end }) else { return false }
        entries.append(entry)
        return true
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return "\(total / 3600)小时\((total % 3600) / 60)分\(total % 60)秒"
    }
    func csv(at now: Date) -> String {
        func quote(_ text: String) -> String {
            let safe = ["=", "+", "-", "@"].contains(String(text.prefix(1))) ? "'" + text : text
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let format = ISO8601DateFormatter()
        return "任务,分类,开始,结束,秒数,状态\n" + records(at: now).sorted { $0.start < $1.start }.map {
            [$0.task, $0.category, format.string(from: $0.start), format.string(from: $0.end), String(Int($0.seconds)), $0.reason].map(quote).joined(separator: ",")
        }.joined(separator: "\n")
    }
}
