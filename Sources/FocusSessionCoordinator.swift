import Foundation

final class FocusSessionCoordinator {
    private(set) var state: ResearchState
    let repository: ResearchRepository
    init(state: ResearchState, repository: ResearchRepository) { self.state = state; self.repository = repository }
    var current: FocusSession? { state.openIndex.map { state.sessions[$0] } }
    func change(_ edit: (inout ResearchState) throws -> Void) throws {
        var copy = state
        try edit(&copy)
        try copy.validate()
        try repository.save(copy)
        state = copy
    }
    private static func closeSegment(_ s: inout FocusSession, at now: Date) {
        if let start = s.activeStart {
            let end = max(start, min(now, s.countdown.deadline ?? now))
            if end > start { s.segments.append(.init(start: start, end: end)) }
        }
        s.activeStart = nil; s.checkpoint = nil
    }
    func start(projectID: UUID?, taskID: UUID?, title: String, category: String, workType: String, seconds: TimeInterval, at now: Date) throws {
        try change { state in
            if let i = state.openIndex {
                Self.closeSegment(&state.sessions[i], at: now)
                state.sessions[i].countdown.reset(); state.sessions[i].endedAt = now; state.sessions[i].reason = "切换"
            }
            if let id = projectID, state.projects.first(where: { $0.id == id })?.archivedAt != nil { throw ResearchError.message("已归档项目不能开始新计时") }
            if let id = taskID, let t = state.tasks.first(where: { $0.id == id }), t.archivedAt != nil || t.completedAt != nil { throw ResearchError.message("请先在任务页重新打开该任务") }
            var timer = Countdown(); timer.start(seconds: seconds, at: now)
            state.sessions.append(FocusSession(projectID: projectID, taskID: taskID, title: title, category: category, workType: workType, createdAt: now, countdown: timer, activeStart: now, checkpoint: now))
        }
    }
    func pause(at now: Date, reason: String = "暂停") throws {
        guard current?.countdown.isRunning == true else { return }
        try change { state in
            let i = state.openIndex!
            Self.closeSegment(&state.sessions[i], at: now)
            state.sessions[i].countdown.pause(at: now); state.sessions[i].reason = reason
        }
    }
    func resume(at now: Date) throws {
        guard current?.countdown.isPaused == true else { return }
        try change { state in
            let i = state.openIndex!
            state.sessions[i].countdown.resume(at: now)
            state.sessions[i].activeStart = now; state.sessions[i].checkpoint = now; state.sessions[i].reason = ""
        }
    }
    @discardableResult func finish(at now: Date, reason: String) throws -> UUID? {
        guard let current else { return nil }
        try change { state in
            let i = state.openIndex!
            let end = min(now, state.sessions[i].countdown.deadline ?? now)
            Self.closeSegment(&state.sessions[i], at: end)
            state.sessions[i].countdown.reset(); state.sessions[i].endedAt = end; state.sessions[i].reason = reason
        }
        return current.id
    }
    @discardableResult func tick(at now: Date) throws -> UUID? {
        guard let current, let deadline = current.countdown.deadline else { return nil }
        if now >= deadline { return try finish(at: deadline, reason: "到时") }
        if now.timeIntervalSince(current.checkpoint ?? now) >= 30 {
            try change { $0.sessions[$0.openIndex!].checkpoint = now }
        }
        return nil
    }
    func recover() throws {
        guard let s = current, s.countdown.isRunning else { return }
        try pause(at: s.checkpoint ?? s.activeStart ?? s.createdAt, reason: "意外退出恢复")
    }
    func importActivities(_ entries: [Activity], now: Date) throws {
        try change { state in
            var log = state.activityLog(at: now)
            for entry in entries {
                guard log.addManual(entry, now: now) else { throw ResearchError.message("补记无效：时间重叠、未来时间或任务名为空。整批未保存。") }
                var s = FocusSession(title: entry.task, category: entry.category, workType: "其他", source: "manual", createdAt: entry.start, endedAt: entry.end, reason: entry.reason, countdown: Countdown())
                s.segments = [.init(start: entry.start, end: entry.end)]
                state.sessions.append(s)
            }
        }
    }
    func completeTask(_ id: UUID, at now: Date) throws {
        try change { state in
            if let i = state.openIndex, state.sessions[i].taskID == id {
                Self.closeSegment(&state.sessions[i], at: now)
                state.sessions[i].countdown.reset(); state.sessions[i].endedAt = now; state.sessions[i].reason = "任务完成"
            }
            guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { throw ResearchError.message("任务不存在") }
            state.tasks[i].status = "已完成"; state.tasks[i].completedAt = now; state.tasks[i].updatedAt = now
        }
    }
}
