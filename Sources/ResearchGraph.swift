import Foundation

struct ResearchGraph: Codable, Equatable {
    var nodes: [Node] = []
    var edges: [Edge] = []
    struct Node: Codable, Equatable, Identifiable {
        var id = UUID()
        var title: String
        var kind = "问题"
        var body = ""
        var status = "待探索"
        var important = false
        var projectID: UUID?
        var x: Double = 0
        var y: Double = 0
        var createdAt = Date()
        var updatedAt = Date()
    }
    struct Edge: Codable, Equatable, Identifiable {
        var id = UUID()
        var from: UUID
        var to: UUID
        var relation = "推进到"
    }
    static let kinds = ["问题", "观点", "Idea", "假设", "实验", "结果", "论文", "讨论", "失败"]
    static let statuses = ["待探索", "进行中", "已验证", "已解决", "已否定"]
    static let relations = ["推进到", "启发", "验证", "反驳", "产生", "依赖", "相关"]
    func validate(projects: Set<UUID>) throws {
        let ids = Set(nodes.map { $0.id })
        guard ids.count == nodes.count, Set(edges.map { $0.id }).count == edges.count else { throw ResearchError.message("看板 ID 重复") }
        for n in nodes {
            guard !n.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, n.title.count <= 160,
                  Self.kinds.contains(n.kind), Self.statuses.contains(n.status),
                  n.x.isFinite, n.y.isFinite, abs(n.x) <= 1_000_000, abs(n.y) <= 1_000_000,
                  n.projectID == nil || projects.contains(n.projectID!) else { throw ResearchError.message("节点名称、类型、状态、位置或项目无效") }
        }
        var pairs = Set<String>()
        for e in edges {
            guard ids.contains(e.from), ids.contains(e.to), e.from != e.to, Self.relations.contains(e.relation),
                  pairs.insert(e.from.uuidString + e.to.uuidString + e.relation).inserted else { throw ResearchError.message("连接无效或重复，请选择两个不同节点") }
        }
    }
    mutating func remove(node id: UUID) { nodes.removeAll { $0.id == id }; edges.removeAll { $0.from == id || $0.to == id } }
}
