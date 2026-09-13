import Foundation

struct ResearchProject: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var goal = ""
    var stage = "探索"
    var nextAction = ""
    var milestones: [Milestone] = []
    var weeklyObjectives: [WeeklyObjective] = []
    var createdAt = Date()
    var updatedAt = Date()
    var archivedAt: Date?
    struct Milestone: Codable, Equatable, Identifiable { var id = UUID(); var title: String; var done = false }
    struct WeeklyObjective: Codable, Equatable, Identifiable { var id = UUID(); var title: String; var weekStart: Date; var done = false }
    var progress: String { milestones.isEmpty ? "未设里程碑" : "\(milestones.filter { $0.done }.count) / \(milestones.count)" }
}

struct ResearchTask: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var description = ""
    var projectID: UUID?
    var status = "待办"
    var priority = "普通"
    var planningGoalID: UUID?
    var plannedDay: String?
    var plannedMinutes: Int?
    var plannedDuration: Int?
    var schedule = "Inbox"
    var timeZoneID = TimeZone.current.identifier
    var scheduledDate: Date?
    var dueDate: Date?
    var createdAt = Date()
    var updatedAt = Date()
    var completedAt: Date?
    var archivedAt: Date?
}

struct FocusSession: Codable, Equatable, Identifiable {
    var id = UUID()
    var projectID: UUID?
    var taskID: UUID?
    var title: String
    var category: String
    var workType: String
    var timeZoneID = TimeZone.current.identifier
    var source = "timer"
    var createdAt: Date
    var endedAt: Date?
    var reason = ""
    var countdown: Countdown
    var segments: [Segment] = []
    var activeStart: Date?
    var checkpoint: Date?
    var note = SessionNote()
    struct Segment: Codable, Equatable { var start: Date; var end: Date }
    var isOpen: Bool { endedAt == nil }
    func seconds(at now: Date) -> TimeInterval {
        segments.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) }
        + (activeStart.map { max(0, min(now, countdown.deadline ?? now).timeIntervalSince($0)) } ?? 0)
    }
}

struct SessionNote: Codable, Equatable {
    var text = ""
    var result = ""
    var finding = ""
    var question = ""
    var idea = ""
    var nextAction = ""
}

struct ResearchState: Codable, Equatable {
    var agent: AgentArchive?
    var schedule: ResearchSchedule?
    var graph: ResearchGraph?
    var version = 1
    var projects: [ResearchProject] = []
    var tasks: [ResearchTask] = []
    var sessions: [FocusSession] = []
    var openIndex: Int? { sessions.lastIndex { $0.isOpen } }
    static let workTypes = ["论文阅读", "科研思考", "Idea", "写代码", "实验", "实验分析", "论文写作", "数据处理", "讨论", "学习", "其他"]
    func validate() throws {
        func require(_ test: Bool, _ text: String) throws { if !test { throw ResearchError.message(text) } }
        try require(version == 1, "不支持的科研数据版本")
        let pids = Set(projects.map { $0.id }), tids = Set(tasks.map { $0.id })
        try agent?.validate()
        try graph?.validate(projects: pids)
        try (schedule ?? ResearchSchedule()).validate(projects: pids, tasks: tasks)
        try require(pids.count == projects.count && tids.count == tasks.count && Set(sessions.map { $0.id }).count == sessions.count, "数据 ID 重复")
        try require(sessions.filter { $0.isOpen }.count <= 1, "只能有一个未结束的 Session")
        for p in projects { try require(!p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && p.title.count <= 300, "项目名需为 1–300 字") }
        for t in tasks {
            try require(!t.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "任务名不能为空")
            try require(["待办", "进行中", "已完成"].contains(t.status) && ["低", "普通", "高"].contains(t.priority), "无效任务状态或优先级")
            try require(["Inbox", "今天", "本周", "指定日期"].contains(t.schedule), "无效任务安排")
            try require(t.projectID == nil || pids.contains(t.projectID!), "任务的项目不存在")
        }
        var allSegments: [FocusSession.Segment] = []
        for s in sessions {
            try require(!s.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Self.workTypes.contains(s.workType) && ["学习", "工作", "休息", "其他"].contains(s.category), "无效 Session 名称、工作类型或分类")
            try require(s.projectID == nil || pids.contains(s.projectID!), "Session 的项目不存在")
            try require(s.taskID == nil || tids.contains(s.taskID!), "Session 的任务不存在")
            if let id = s.taskID { try require(tasks.first { $0.id == id }?.projectID == s.projectID, "Session 与任务的项目不一致") }
            try require(s.createdAt.timeIntervalSince1970.isFinite && (s.endedAt?.timeIntervalSince1970.isFinite ?? true), "无效日期")
            try require(s.countdown.deadline?.timeIntervalSince1970.isFinite ?? true, "无效截止时间")
            if let remaining = s.countdown.pausedRemaining { try require(remaining.isFinite && remaining >= 0 && remaining <= s.countdown.duration, "无效暂停时间") }
            try require(s.countdown.duration.isFinite && s.countdown.duration > 0 && s.countdown.duration <= 599 * 60, "无效计时时长")
            try require(!s.isOpen || (s.countdown.isRunning != s.countdown.isPaused), "未结束 Session 必须运行或暂停")
            try require(s.isOpen || (s.activeStart == nil && !s.countdown.isRunning && !s.countdown.isPaused), "结束 Session 仍在计时")
            try require((s.activeStart != nil) == s.countdown.isRunning, "片段与计时状态不一致")
            try require(s.activeStart == nil || s.checkpoint != nil, "运行中的 Session 缺少保存点")
            if let start = s.activeStart, let checkpoint = s.checkpoint { try require(checkpoint >= start, "保存点早于开始时间") }
            var last: Date?
            for segment in s.segments {
                try require(segment.start.timeIntervalSince1970.isFinite && segment.end.timeIntervalSince1970.isFinite && segment.end > segment.start && (last == nil || segment.start >= last!), "时间片段无效或重叠")
                try require(segment.start >= s.createdAt && (s.endedAt == nil || segment.end <= s.endedAt!), "片段超出 Session 边界")
                last = segment.end
            }
            if let start = s.activeStart, let last { try require(start >= last, "活动片段与历史重叠") }
            allSegments += s.segments
            if let start = s.activeStart, let checkpoint = s.checkpoint, checkpoint > start { allSegments.append(.init(start: start, end: checkpoint)) }
        }
        let sorted = allSegments.sorted { $0.start < $1.start }
        for i in sorted.indices.dropFirst() { try require(sorted[i].start >= sorted[i - 1].end, "不同 Session 的时间重叠") }
    }
    func activityLog(at now: Date) -> ActivityLog {
        var log = ActivityLog()
        for s in sessions {
            for segment in s.segments {
                log.entries.append(Activity(task: s.title, category: s.category, start: segment.start, end: segment.end, reason: s.reason.isEmpty ? "已记录" : s.reason, taskID: s.taskID, sessionID: s.id))
            }
            if let start = s.activeStart {
                log.entries.append(Activity(task: s.title, category: s.category, start: start, end: max(start, min(now, s.countdown.deadline ?? now)), reason: "进行中", taskID: s.taskID, sessionID: s.id))
            }
        }
        return log
    }
}

enum ResearchError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
