import Foundation

func expectFailure(_ operation: () throws -> Void) { do { try operation(); fatalError("Expected failure") } catch {} }
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tomato-research-test-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at: folder) }
let repository = try SQLiteResearchStore(url: folder.appendingPathComponent("research.sqlite"))
let t = Date(timeIntervalSince1970: 1_700_000_000)
var old = ActivityLog()
old.begin(task: "old task", category: "学习", at: t)
old.finish(at: t.addingTimeInterval(60), reason: "暂停")
old.begin(task: "old task", category: "学习", at: t.addingTimeInterval(120))
old.checkpoint(at: t.addingTimeInterval(150))
var oldTimer = Countdown(); oldTimer.start(seconds: 600, at: t.addingTimeInterval(120))
let suite = "research-test-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
defaults.set(try JSONEncoder().encode(old), forKey: "activityLog.v1")
defaults.set(try JSONEncoder().encode(oldTimer), forKey: "savedCountdown.v1")
let migrated = try LegacyMigration.bootstrap(store: repository, defaults: defaults, now: t.addingTimeInterval(180))
assert(migrated.sessions.count == 2 && migrated.tasks.count == 1)
assert(migrated.sessions.reduce(0) { $0 + $1.seconds(at: t.addingTimeInterval(200)) } == 90)
assert(migrated.sessions.last!.countdown.isPaused)
assert(try! repository.isInitialized)
let again = try LegacyMigration.bootstrap(store: repository, defaults: defaults, now: t.addingTimeInterval(300))
assert(again == migrated)
assert(FileManager.default.fileExists(atPath: folder.appendingPathComponent("legacy-v1-backup.json").path))
let coordinator = FocusSessionCoordinator(state: migrated, repository: repository)
_ = try coordinator.finish(at: t.addingTimeInterval(300), reason: "结束历史暂停")
let project = ResearchProject(title: "Project A")
let project2 = ResearchProject(title: "Project B")
let task = ResearchTask(title: "same name", projectID: project.id)
let otherTask = ResearchTask(title: "same name", projectID: project2.id)
try coordinator.change { $0.projects += [project, project2]; $0.tasks += [task, otherTask] }
let start = t.addingTimeInterval(1000)
try coordinator.start(projectID: project.id, taskID: task.id, title: task.title, category: "学习", workType: "实验", seconds: 60, at: start)
let sessionID = coordinator.current!.id
try coordinator.pause(at: start.addingTimeInterval(10))
try coordinator.resume(at: start.addingTimeInterval(100))
assert(coordinator.current!.id == sessionID)
assert(try! coordinator.tick(at: start.addingTimeInterval(150)) == sessionID)
assert(try! coordinator.tick(at: start.addingTimeInterval(151)) == nil)
let finished = coordinator.state.sessions.last!
assert(finished.seconds(at: start.addingTimeInterval(200)) == 60 && finished.segments.count == 2)
try coordinator.change { s in let i = s.tasks.firstIndex { $0.id == task.id }!; s.tasks[i].title = "renamed" }
assert(coordinator.state.sessions.last!.taskID == task.id && coordinator.state.sessions.last!.title == "same name")
try coordinator.completeTask(task.id, at: start.addingTimeInterval(200))
expectFailure { try coordinator.start(projectID: project.id, taskID: task.id, title: "renamed", category: "学习", workType: "实验", seconds: 60, at: start.addingTimeInterval(300)) }
assert(coordinator.state.tasks.first { $0.id == task.id }!.completedAt != nil)
expectFailure { try coordinator.start(projectID: project.id, taskID: otherTask.id, title: "invalid", category: "学习", workType: "实验", seconds: 60, at: start.addingTimeInterval(300)) }
assert(coordinator.current == nil)
try coordinator.start(projectID: project2.id, taskID: otherTask.id, title: "same name", category: "学习", workType: "实验", seconds: 120, at: start.addingTimeInterval(300))
_ = try coordinator.tick(at: start.addingTimeInterval(331))
let crash = FocusSessionCoordinator(state: try repository.load(), repository: repository)
try crash.recover()
assert(crash.current!.countdown.isPaused && crash.current!.seconds(at: start.addingTimeInterval(1000)) == 31)
_ = try crash.finish(at: start.addingTimeInterval(1000), reason: "结束")
let snapshot = crash.state
expectFailure { try crash.importActivities([Activity(task: "overlap", category: "工作", start: start, end: start.addingTimeInterval(5), reason: "manual")], now: start.addingTimeInterval(2000)) }
assert(crash.state == snapshot)
let good = Activity(task: "manual", category: "工作", start: start.addingTimeInterval(2000), end: start.addingTimeInterval(2030), reason: "AI补记")
expectFailure { try crash.importActivities([good, good], now: start.addingTimeInterval(3000)) }
assert(crash.state == snapshot)
try crash.importActivities([good], now: start.addingTimeInterval(3000))
let encoded = try ResearchBackup.encode(crash.state)
let decoded = try JSONDecoder().decode(ResearchState.self, from: encoded)
assert(decoded == crash.state)
let restoredStore = try SQLiteResearchStore(url: folder.appendingPathComponent("restored.sqlite"))
let restored = try ResearchBackup.merge(decoded, into: ResearchState())
try restoredStore.save(restored)
assert(try! restoredStore.load() == crash.state)
assert(try! ResearchBackup.merge(decoded, into: decoded) == decoded)
var conflict = decoded; conflict.tasks[0].title = "conflict"
expectFailure { _ = try ResearchBackup.merge(conflict, into: decoded) }
var invalid = decoded; invalid.tasks[0].projectID = UUID()
expectFailure { try repository.save(invalid) }
assert(try! repository.load() == crash.state)
let span = DateInterval(start: start.addingTimeInterval(5), end: start.addingTimeInterval(105))
assert(finished.segments.reduce(0) { $0 + max(0, min($1.end, span.end).timeIntervalSince(max($1.start, span.start))) } == 10)
print("PASS: SQLite migration/backup/idempotence, stable IDs, session pause/resume, expiry once, crash recovery, imports atomic, backup restore/conflicts, interval clipping")

// A failed write must leave the in-memory source of truth untouched.
final class FailingStore: ResearchRepository {
    func load() throws -> ResearchState { ResearchState() }
    func save(_ state: ResearchState) throws { throw ResearchError.message("disk full") }
}
let failure = FocusSessionCoordinator(state: ResearchState(), repository: FailingStore())
expectFailure { try failure.start(projectID: nil, taskID: nil, title: "test", category: "学习", workType: "学习", seconds: 60, at: t) }
assert(failure.current == nil && failure.state.sessions.isEmpty)
expectFailure { try repository.save(ResearchState()) }
assert(try! repository.load() == crash.state)

let corruptedStore = try SQLiteResearchStore(url: folder.appendingPathComponent("corrupted.sqlite"))
defaults.set(Data("broken".utf8), forKey: "activityLog.v1")
expectFailure { _ = try LegacyMigration.bootstrap(store: corruptedStore, defaults: defaults, now: t) }
assert(try! !corruptedStore.isInitialized)

// A running backup is restored paused at its checkpoint, with no invented gap.
let runningRepo = try SQLiteResearchStore(url: folder.appendingPathComponent("running.sqlite"))
let running = FocusSessionCoordinator(state: ResearchState(), repository: runningRepo)
try running.start(projectID: nil, taskID: nil, title: "test", category: "学习", workType: "学习", seconds: 120, at: t)
_ = try running.tick(at: t.addingTimeInterval(31))
let recoveredBackup = try ResearchBackup.merge(running.state, into: ResearchState())
assert(recoveredBackup.sessions[0].countdown.isPaused && recoveredBackup.sessions[0].seconds(at: t.addingTimeInterval(1000)) == 31)
var overlapping = decoded
var overlap = decoded.sessions[0]; overlap.id = UUID(); overlapping.sessions.append(overlap)
expectFailure { _ = try ResearchBackup.merge(overlapping, into: decoded) }
print("PASS: failed-write rollback, deletion protection, corrupted migration, running backup recovery, cross-session overlap rejection")
