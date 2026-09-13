import Foundation

enum ResearchBackup {
    static func encode(_ state: ResearchState) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }
    static func merge(_ incoming: ResearchState, into current: ResearchState) throws -> ResearchState {
        try incoming.validate()
        guard !incoming.sessions.contains(where: { s in s.createdAt > Date() || s.segments.contains { $0.end > Date() } }) else { throw ResearchError.message("备份含未来活动时间") }
        var result = current
        func append<T: Codable & Identifiable>(_ values: [T], to existing: inout [T]) throws where T.ID == UUID {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for value in values {
                if let old = existing.first(where: { $0.id == value.id }) {
                    guard try encoder.encode(old) == encoder.encode(value) else { throw ResearchError.message("相同 ID 的记录内容冲突，未导入。请核对备份版本。") }
                } else { existing.append(value) }
            }
        }
        try append(incoming.projects, to: &result.projects)
        try append(incoming.tasks, to: &result.tasks)
        // Imported running sessions stop at the saved checkpoint, never at the import time.
        var sessions = incoming.sessions
        for i in sessions.indices where sessions[i].countdown.isRunning && !current.sessions.contains(where: { $0.id == sessions[i].id }) {
            let end = sessions[i].checkpoint ?? sessions[i].activeStart ?? sessions[i].createdAt
            if let start = sessions[i].activeStart, end > start { sessions[i].segments.append(.init(start: start, end: end)) }
            sessions[i].activeStart = nil; sessions[i].checkpoint = nil
            sessions[i].countdown.pause(at: end); sessions[i].reason = "备份恢复后暂停"
        }
        try append(sessions, to: &result.sessions)
        if let archive = incoming.agent {
            var merged = result.agent ?? AgentArchive()
            try append(archive.conversations, to: &merged.conversations)
            result.agent = merged
        }
        if let graph = incoming.graph {
            var merged = result.graph ?? ResearchGraph()
            try append(graph.nodes, to: &merged.nodes)
            try append(graph.edges, to: &merged.edges)
            result.graph = merged
        }
        if let schedule = incoming.schedule {
            var merged = result.schedule ?? ResearchSchedule()
            try append(schedule.goals, to: &merged.goals)
            result.schedule = merged
        }
        try result.validate()
        let records = result.activityLog(at: Date()).entries.sorted { $0.start < $1.start }
        for i in records.indices.dropFirst() where records[i].start < records[i - 1].end {
            throw ResearchError.message("备份与当前正在进行的活动重叠，未导入。")
        }
        return result
    }
}
