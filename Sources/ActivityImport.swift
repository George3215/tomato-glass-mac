import Foundation

struct ActivityImport: Codable {
    struct Entry: Codable {
        var task: String
        var category: String
        var start: Date
        var end: Date
    }
    var version: Int
    var source: String
    var entries: [Entry]

    func applying(to log: ActivityLog, now: Date) throws -> ActivityLog {
        guard version == 1, ["ai", "manual"].contains(source), !entries.isEmpty, entries.count <= 1000 else {
            throw Self.error("版本需为 1，source 为 ai 或 manual，记录数量需为 1–1000。")
        }
        var copy = log
        for (index, entry) in entries.enumerated() {
            let task = entry.task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard task.count <= 300, ["学习", "工作", "休息", "其他"].contains(entry.category),
                  copy.addManual(Activity(task: task, category: entry.category, start: entry.start, end: entry.end,
                    reason: source == "ai" ? "AI补记" : "导入补记"), now: now) else {
                throw Self.error("第 \(index + 1) 条记录无效：检查任务名、分类、起止时间、未来时间或记录重叠。未保存任何导入记录。")
            }
        }
        return copy
    }
    static func error(_ message: String) -> NSError {
        NSError(domain: "TomatoGlass.Import", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension ActivityLog {
    func gaps(in day: DateInterval, now: Date) -> [DateInterval] {
        let cutoff = min(day.end, now)
        guard cutoff > day.start else { return [] }
        var cursor = day.start
        var result: [DateInterval] = []
        for entry in records(at: now).filter({ $0.seconds(in: day) > 0 }).sorted(by: { $0.start < $1.start }) {
            let start = max(day.start, entry.start), end = min(cutoff, entry.end)
            if start > cursor { result.append(DateInterval(start: cursor, end: start)) }
            cursor = max(cursor, end)
        }
        if cursor < cutoff { result.append(DateInterval(start: cursor, end: cutoff)) }
        return result
    }
}
