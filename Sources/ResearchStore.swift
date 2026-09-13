import Foundation
import SQLite3

protocol ResearchRepository {
    func load() throws -> ResearchState
    func save(_ state: ResearchState) throws
}

final class SQLiteResearchStore: ResearchRepository {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "tomato.research.storage")
    private var saved = ResearchState()
    let url: URL
    init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw ResearchError.message("无法打开科研数据库") }
        do {
            try execute("PRAGMA foreign_keys = ON")
            _ = try rows("PRAGMA journal_mode = WAL")
            try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            if let version = try rows("SELECT value FROM metadata WHERE key='schemaVersion'").first?.first, version != "1" {
                throw ResearchError.message("数据库版本较新，请勿使用旧版覆盖")
            }
            try execute("CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, data TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id), data TEXT NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, project_id TEXT REFERENCES projects(id), task_id TEXT REFERENCES tasks(id), data TEXT NOT NULL)")
            try execute("CREATE INDEX IF NOT EXISTS sessions_task ON sessions(task_id)")
            try execute("CREATE INDEX IF NOT EXISTS sessions_project ON sessions(project_id)")
            try execute("INSERT OR IGNORE INTO metadata VALUES ('schemaVersion', '1')")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }
    private func execute(_ sql: String, _ values: [String?] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        for (i, value) in values.enumerated() {
            if let value { sqlite3_bind_text(statement, Int32(i + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            else { sqlite3_bind_null(statement, Int32(i + 1)) }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }
    private func rows(_ sql: String) throws -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure() }
            result.append((0..<sqlite3_column_count(statement)).map { String(cString: sqlite3_column_text(statement, $0)) })
        }
    }
    private func failure() -> Error { ResearchError.message("科研数据保存失败：" + String(cString: sqlite3_errmsg(db))) }
    var isInitialized: Bool { get throws { try queue.sync { !(try rows("SELECT value FROM metadata WHERE key='initialized'")).isEmpty } } }
    func load() throws -> ResearchState {
        try queue.sync {
            let decoder = JSONDecoder()
            func read<T: Decodable>(_ table: String, as: T.Type) throws -> [T] {
                try rows("SELECT data FROM \(table) ORDER BY rowid").map { try decoder.decode(T.self, from: Data($0[0].utf8)) }
            }
            var state = ResearchState(projects: try read("projects", as: ResearchProject.self), tasks: try read("tasks", as: ResearchTask.self), sessions: try read("sessions", as: FocusSession.self))
            if let raw = try rows("SELECT value FROM metadata WHERE key='researchGraph'").first?.first {
                state.graph = try decoder.decode(ResearchGraph.self, from: Data(raw.utf8))
            }
            try state.validate()
            saved = state
            return state
        }
    }
    func save(_ state: ResearchState) throws {
        try state.validate()
        try queue.sync {
            guard Set(saved.projects.map { $0.id }).isSubset(of: Set(state.projects.map { $0.id })),
                  Set(saved.tasks.map { $0.id }).isSubset(of: Set(state.tasks.map { $0.id })),
                  Set(saved.sessions.map { $0.id }).isSubset(of: Set(state.sessions.map { $0.id })) else {
                throw ResearchError.message("不允许通过覆盖快照删除历史，请使用归档。")
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
            try execute("BEGIN IMMEDIATE")
            do {
                // Changed rows only: a timer checkpoint never rewrites the complete history.
                let oldProjects = Dictionary(uniqueKeysWithValues: saved.projects.map { ($0.id, $0) })
                let oldTasks = Dictionary(uniqueKeysWithValues: saved.tasks.map { ($0.id, $0) })
                let oldSessions = Dictionary(uniqueKeysWithValues: saved.sessions.map { ($0.id, $0) })
                for p in state.projects where oldProjects[p.id] != p {
                    try execute("INSERT INTO projects VALUES (?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data WHERE data != excluded.data", [p.id.uuidString, try json(p)])
                }
                for t in state.tasks where oldTasks[t.id] != t {
                    try execute("INSERT INTO tasks VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, data=excluded.data WHERE data != excluded.data", [t.id.uuidString, t.projectID?.uuidString, try json(t)])
                }
                for s in state.sessions where oldSessions[s.id] != s {
                    try execute("INSERT INTO sessions VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, task_id=excluded.task_id, data=excluded.data WHERE data != excluded.data", [s.id.uuidString, s.projectID?.uuidString, s.taskID?.uuidString, try json(s)])
                }
                if state.graph != saved.graph {
                    try execute("INSERT OR REPLACE INTO metadata VALUES ('researchGraph', ?)", [try json(state.graph ?? ResearchGraph())])
                }
                try execute("INSERT OR REPLACE INTO metadata VALUES ('initialized', '1')")
                try execute("COMMIT")
                saved = state
            } catch { try? execute("ROLLBACK"); throw error }
        }
    }
}

struct LegacyMigration {
    static func convert(log: ActivityLog, countdown: Countdown?, now: Date) throws -> ResearchState {
        var state = ResearchState()
        var ids: [String: UUID] = [:]
        func task(_ title: String) -> UUID {
            if let id = ids[title] { return id }
            var task = ResearchTask(title: title.isEmpty ? "未命名任务" : title)
            task.description = "旧版迁移：未分配项目，原始 Session 边界不可还原。"
            task.completedAt = log.completed[title]
            task.status = task.completedAt == nil ? "待办" : "已完成"
            state.tasks.append(task); ids[title] = task.id
            return task.id
        }
        for entry in log.entries {
            guard entry.start < entry.end, entry.start.timeIntervalSince1970.isFinite, entry.end.timeIntervalSince1970.isFinite else { throw ResearchError.message("旧记录时间无效，未迁移；请保留备份检查。") }
            let id = task(entry.task)
            var session = FocusSession(taskID: id, title: entry.task, category: entry.category, workType: "其他", source: "legacy", createdAt: entry.start, endedAt: entry.end, reason: entry.reason, countdown: Countdown())
            session.segments = [.init(start: entry.start, end: entry.end)]
            state.sessions.append(session)
        }
        for title in log.completed.keys { _ = task(title) }
        if let active = log.active {
            guard active.checkpoint >= active.start else { throw ResearchError.message("旧记录保存点无效") }
            var timer = countdown ?? Countdown()
            if timer.isRunning { timer.pause(at: active.checkpoint) }
            if !timer.isPaused { timer.pausedRemaining = timer.duration }
            var session = FocusSession(taskID: task(active.task), title: active.task, category: active.category, workType: "其他", source: "legacy", createdAt: active.start, reason: "迁移后暂停", countdown: timer)
            if active.checkpoint > active.start { session.segments = [.init(start: active.start, end: active.checkpoint)] }
            state.sessions.append(session)
        } else if var timer = countdown, timer.isPaused || timer.isRunning {
            if timer.isRunning { timer.pause(at: now) }
            state.sessions.append(FocusSession(title: "旧版暂停计时", category: "学习", workType: "其他", source: "legacy", createdAt: now, reason: "迁移后暂停", countdown: timer))
        }
        try state.validate()
        return state
    }

    static func bootstrap(store: SQLiteResearchStore, defaults: UserDefaults, now: Date) throws -> ResearchState {
        if try store.isInitialized { return try store.load() }
        let backup = store.url.deletingLastPathComponent().appendingPathComponent("legacy-v1-backup.json")
        let keys = ["activityLog.v1", "savedCountdown.v1"]
        let original = Dictionary(uniqueKeysWithValues: keys.compactMap { key in defaults.data(forKey: key).map { (key, $0.base64EncodedString()) } })
        // Never overwrite the initial backup, even after an interrupted migration.
        if !FileManager.default.fileExists(atPath: backup.path) {
            try JSONEncoder().encode(original).write(to: backup, options: .atomic)
        }
        let decoder = JSONDecoder()
        let log = try defaults.data(forKey: keys[0]).map { try decoder.decode(ActivityLog.self, from: $0) } ?? ActivityLog()
        let countdown = try defaults.data(forKey: keys[1]).map { try decoder.decode(Countdown.self, from: $0) }
        let state = try convert(log: log, countdown: countdown, now: now)
        try store.save(state)
        return state
    }
}
