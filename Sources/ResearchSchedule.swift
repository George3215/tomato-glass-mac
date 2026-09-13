import Foundation

struct ResearchSchedule: Codable, Equatable {
    var goals: [Goal] = []
    struct Goal: Codable, Equatable, Identifiable {
        var id = UUID()
        var projectID: UUID
        var parentID: UUID?
        var kind: String // month or week
        var period: String // month first day or ISO week Monday, YYYY-MM-DD
        var title: String
        var detail = ""
        var done = false
        var createdAt = Date()
        var updatedAt = Date()
    }
    func validate(projects: Set<UUID>, tasks: [ResearchTask]) throws {
        guard Set(goals.map { $0.id }).count == goals.count else { throw ResearchError.message("目标 ID 重复") }
        for g in goals {
            guard projects.contains(g.projectID), !g.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  g.title.count <= 300, let date = PlanDates.date(g.period), ["month", "week"].contains(g.kind),
                  g.period == (g.kind == "month" ? PlanDates.month(date) : PlanDates.week(date)) else { throw ResearchError.message("目标名称、课题或周期无效") }
            if g.kind == "month" {
                guard g.parentID == nil else { throw ResearchError.message("月目标不应有上级周目标") }
            } else if let parentID = g.parentID {
                guard let month = goals.first(where: { $0.id == parentID }), month.kind == "month", month.projectID == g.projectID,
                      PlanDates.days(start: date, count: 7).contains(where: { PlanDates.month($0) == month.period }) else { throw ResearchError.message("周目标需关联同一课题、且与该周有日期交集的月目标") }
            }
        }
        for t in tasks {
            if let day = t.plannedDay, PlanDates.date(day) == nil { throw ResearchError.message("无效日程日期") }
            if let minutes = t.plannedMinutes, !(0..<1440).contains(minutes) { throw ResearchError.message("计划时间应在 00:00–23:59") }
            if let duration = t.plannedDuration, !(1...1440).contains(duration) { throw ResearchError.message("预计用时应为 1–1440 分钟") }
            if let id = t.planningGoalID {
                guard let g = goals.first(where: { $0.id == id }), g.kind == "week", g.projectID == t.projectID,
                      let day = PlanDates.taskDay(t), let date = PlanDates.date(day), PlanDates.week(date) == g.period else { throw ResearchError.message("每日 Todo 需关联同一课题、同一周的周目标") }
            }
        }
    }
    func taskIDs(for goal: Goal, tasks: [ResearchTask]) -> Set<UUID> {
        let goals = goal.kind == "week" ? Set([goal.id]) : Set(self.goals.filter { $0.parentID == goal.id }.map { $0.id })
        return Set(tasks.filter { $0.archivedAt == nil && $0.planningGoalID.map(goals.contains) == true }.map { $0.id })
    }
}

enum PlanDates {
    static var calendar: Calendar { var c = Calendar(identifier: .iso8601); c.timeZone = .current; return c }
    static func key(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = timeZone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func date(_ key: String) -> Date? {
        let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let d = f.date(from: key), self.key(d) == key else { return nil }; return d
    }
    static func week(_ date: Date) -> String { key(calendar.dateInterval(of: .weekOfYear, for: date)!.start) }
    static func month(_ date: Date) -> String { key(calendar.dateInterval(of: .month, for: date)!.start) }
    static func days(start: Date, count: Int) -> [Date] { (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start)! } }
    static func taskDay(_ task: ResearchTask) -> String? { task.plannedDay ?? task.scheduledDate.map { key($0, timeZone: TimeZone(identifier: task.timeZoneID) ?? .current) } }
    static func time(_ task: ResearchTask) -> String {
        guard let m = task.plannedMinutes else { return "时间灵活" }; return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
