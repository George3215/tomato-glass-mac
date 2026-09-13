import AppKit

final class ResearchBoardController: NSWindowController {
    unowned let app: AppDelegate
    let canvas = ResearchCanvas()
    let search = NSSearchField()
    let kind = NSPopUpButton()
    let status = NSPopUpButton()
    let project = NSPopUpButton()
    let relation = NSPopUpButton()
    let importantOnly = NSButton(checkboxWithTitle: "只看重点", target: nil, action: nil)
    let connect = NSButton(checkboxWithTitle: "连线模式", target: nil, action: nil)
    let hint = NSTextField(wrappingLabelWithString: "")
    var undoGraphs: [ResearchGraph] = []
    private var expectedGraph: ResearchGraph?
    var graph: ResearchGraph { app.research.state.graph ?? ResearchGraph() }
    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "🦋 研究进程看板 · Research Map"; window.minSize = NSSize(width: 1000, height: 650)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
        canvas.controller = self
        func button(_ title: String, _ action: Selector) -> NSButton { let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b }
        connect.target = self; connect.action = #selector(connectChanged)
        relation.addItems(withTitles: ResearchGraph.relations)
        let toolbar = glassStack([button("＋ 新节点", #selector(addNode)), button("编辑", #selector(editSelection)), button("★ 标为重点", #selector(toggleImportant)), connect, relation, button("删除", #selector(deleteSelection)), button("撤销", #selector(undoGraph)), button("−", #selector(zoomOut)), button("＋", #selector(zoomIn)), button("显示全部", #selector(fit))], vertical: false, spacing: 8)
        search.placeholderString = "搜索标题或内容"; search.widthAnchor.constraint(equalToConstant: 220).isActive = true
        search.target = self; search.action = #selector(filtersChanged)
        kind.addItems(withTitles: ["所有类型"] + ResearchGraph.kinds)
        status.addItems(withTitles: ["所有状态"] + ResearchGraph.statuses)
        for picker in [kind, status, project] { picker.target = self; picker.action = #selector(filtersChanged) }
        project.widthAnchor.constraint(lessThanOrEqualToConstant: 220).isActive = true
        importantOnly.target = self; importantOnly.action = #selector(filtersChanged)
        let filters = glassStack([search, kind, status, project, importantOnly], vertical: false, spacing: 10)
        hint.font = AppFont.font(12); hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 2
        let layout = glassStack([toolbar, filters, canvas, hint], spacing: 12)
        let root = BoardSurface(); window.contentView = root; root.addSubview(layout)
        layout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            layout.topAnchor.constraint(equalTo: root.topAnchor, constant: 16), layout.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            layout.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16), layout.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            canvas.widthAnchor.constraint(equalTo: layout.widthAnchor), canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),
            hint.widthAnchor.constraint(equalTo: layout.widthAnchor), hint.heightAnchor.constraint(equalToConstant: 38)
        ])
        AppFont.apply(to: root); StarGlass.apply(to: root); window.center(); reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    func reload() {
        if let expectedGraph, expectedGraph != graph { undoGraphs.removeAll() }
        expectedGraph = graph
        let selectedProject = project.selectedItem?.representedObject as? String
        project.removeAllItems(); project.addItem(withTitle: "所有项目")
        project.addItem(withTitle: "未关联项目"); project.lastItem?.representedObject = "none"
        for p in app.research.state.projects {
            project.addItem(withTitle: p.title); project.lastItem?.representedObject = p.id.uuidString
        }
        if let item = project.itemArray.first(where: { ($0.representedObject as? String) == selectedProject }) { project.select(item) }
        canvas.graph = graph; filtersChanged()
    }
    @objc func filtersChanged() {
        let query = search.stringValue.lowercased(), projectID = project.selectedItem?.representedObject as? String
        canvas.visibleIDs = Set(graph.nodes.filter { n in
            (query.isEmpty || (n.title + n.body).lowercased().contains(query)) &&
            (kind.indexOfSelectedItem == 0 || n.kind == kind.titleOfSelectedItem) &&
            (status.indexOfSelectedItem == 0 || n.status == status.titleOfSelectedItem) &&
            (importantOnly.state != .on || n.important) &&
            (projectID == nil || (projectID == "none" ? n.projectID == nil : n.projectID?.uuidString == projectID))
        }.map { $0.id })
        if let id = canvas.selectedNode, !canvas.visibleIDs.contains(id) { canvas.selectedNode = nil }
        if let id = canvas.selectedEdge, !graph.edges.contains(where: { $0.id == id && canvas.visibleIDs.contains($0.from) && canvas.visibleIDs.contains($0.to) }) { canvas.selectedEdge = nil }
        canvas.linkSource = nil; canvas.needsDisplay = true; selectionChanged()
    }
    func selectionChanged() {
        if let from = canvas.linkSource, let n = graph.nodes.first(where: { $0.id == from }) {
            hint.stringValue = "起点：\(n.title) · 现在点击另一个节点建立有方向的连接。Esc 退出连线模式。"
        } else if let n = graph.nodes.first(where: { $0.id == canvas.selectedNode }) {
            hint.stringValue = "\(n.important ? "★ 重点 · " : "")\(n.kind) · \(n.status) · \(n.title)\n\(n.body.isEmpty ? "双击编辑内容；拖动移动。" : n.body.replacingOccurrences(of: "\n", with: "  "))"
        } else if let e = graph.edges.first(where: { $0.id == canvas.selectedEdge }) {
            hint.stringValue = "已选择连接：\(e.relation)。点击「编辑」可修改关系，「删除」可移除连接。"
        } else {
            hint.stringValue = "\(canvas.visibleIDs.count) / \(graph.nodes.count) 个节点 · 拖动节点移动，拖动空白平移；双击空白新增、双击节点编辑。\n滚轮平移，⌘＋滚轮或触控板捏合缩放；连线模式依次点击起点和终点。修改自动保存，删除可撤销。"
        }
    }
    @discardableResult func commit(_ edit: (inout ResearchGraph) -> Void) -> Bool {
        let old = graph
        if let expectedGraph, expectedGraph != old { undoGraphs.removeAll() }
        var new = old; edit(&new)
        guard new != old else { return true }
        do {
            try app.research.change { $0.graph = new }
            expectedGraph = new
            undoGraphs.append(old); if undoGraphs.count > 30 { undoGraphs.removeFirst() }
            reload(); return true
        } catch { NSApp.presentError(error); reload(); return false }
    }
    @objc func undoGraph() {
        guard expectedGraph == graph else { undoGraphs.removeAll(); reload(); return }
        guard let previous = undoGraphs.last else { return }
        do { try app.research.change { $0.graph = previous }; expectedGraph = previous; undoGraphs.removeLast(); reload() }
        catch { NSApp.presentError(error) }
    }
    @objc func connectChanged() { canvas.linkSource = nil; canvas.needsDisplay = true; selectionChanged() }
    @objc func addNode() { editNode(nil, at: canvas.world(NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))) }
    @objc func editSelection() {
        if let n = graph.nodes.first(where: { $0.id == canvas.selectedNode }) { editNode(n, at: NSPoint(x: n.x, y: n.y)) }
        else if let edge = graph.edges.first(where: { $0.id == canvas.selectedEdge }) {
            let alert = NSAlert(); alert.messageText = "连接关系"
            let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 30)); picker.addItems(withTitles: ResearchGraph.relations); picker.selectItem(withTitle: edge.relation)
            alert.accessoryView = picker; alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
            if alert.runGlassModal() == .alertFirstButtonReturn { commit { g in if let i = g.edges.firstIndex(where: { $0.id == edge.id }) { g.edges[i].relation = picker.titleOfSelectedItem! } } }
        }
    }
    func editNode(_ existing: ResearchGraph.Node?, at point: NSPoint) {
        var node = existing ?? ResearchGraph.Node(title: "", x: point.x, y: point.y)
        let title = NSTextField(string: node.title); title.placeholderString = "例如：关键问题 / 重要观点 / 实验名称"
        title.widthAnchor.constraint(equalToConstant: 480).isActive = true
        let type = NSPopUpButton(); type.addItems(withTitles: ResearchGraph.kinds); type.selectItem(withTitle: node.kind)
        let state = NSPopUpButton(); state.addItems(withTitles: ResearchGraph.statuses); state.selectItem(withTitle: node.status)
        let star = NSButton(checkboxWithTitle: "★ 标为重要节点", target: nil, action: nil); star.state = node.important ? .on : .off
        let projects = NSPopUpButton(); projects.addItem(withTitle: "不关联项目")
        for p in app.research.state.projects {
            projects.addItem(withTitle: p.title); projects.lastItem?.representedObject = p.id.uuidString
            if p.id == node.projectID { projects.select(projects.lastItem) }
        }
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 180))
        text.string = node.body; text.font = AppFont.font(14); text.isRichText = false
        text.isVerticallyResizable = true; text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = text
        scroll.widthAnchor.constraint(equalToConstant: 480).isActive = true; scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        let stack = glassStack([NSTextField(labelWithString: "标题（最多 160 字）"), title, glassStack([type, state, star], vertical: false), projects, NSTextField(labelWithString: "内容 / 依据 / 实验结果 / 下一步"), scroll], spacing: 10)
        stack.frame = NSRect(x: 0, y: 0, width: 480, height: 330)
        let alert = NSAlert(); alert.messageText = existing == nil ? "新建研究节点" : "编辑研究节点"
        alert.accessoryView = stack; alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
        node.title = title.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); node.body = text.string
        node.kind = type.titleOfSelectedItem!; node.status = state.titleOfSelectedItem!; node.important = star.state == .on
        node.projectID = (projects.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:)); node.updatedAt = Date()
        if commit({ g in if let i = g.nodes.firstIndex(where: { $0.id == node.id }) { g.nodes[i] = node } else { g.nodes.append(node) } }) {
            canvas.selectedNode = node.id; canvas.selectedEdge = nil; selectionChanged(); canvas.needsDisplay = true
        }
    }
    @objc func toggleImportant() {
        guard let id = canvas.selectedNode else { return }
        commit { g in if let i = g.nodes.firstIndex(where: { $0.id == id }) { g.nodes[i].important.toggle(); g.nodes[i].updatedAt = Date() } }
    }
    @objc func deleteSelection() {
        if let id = canvas.selectedNode { commit { $0.remove(node: id) }; canvas.selectedNode = nil }
        else if let id = canvas.selectedEdge { commit { $0.edges.removeAll { $0.id == id } }; canvas.selectedEdge = nil }
        selectionChanged()
    }
    func join(_ from: UUID, _ to: UUID) { commit { $0.edges.append(.init(from: from, to: to, relation: relation.titleOfSelectedItem ?? "推进到")) } }
    func move(_ id: UUID, to point: NSPoint) { commit { g in if let i = g.nodes.firstIndex(where: { $0.id == id }) { g.nodes[i].x = point.x; g.nodes[i].y = point.y; g.nodes[i].updatedAt = Date() } } }
    @objc func zoomIn() { canvas.zoom(by: 1.2, anchor: NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)) }
    @objc func zoomOut() { canvas.zoom(by: 1 / 1.2, anchor: NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)) }
    @objc func fit() { canvas.fit() }
}

private final class BoardSurface: StarfieldSurface {}

final class ResearchCanvas: NSView {
    weak var controller: ResearchBoardController?
    var graph = ResearchGraph()
    var visibleIDs = Set<UUID>()
    var selectedNode: UUID?
    var selectedEdge: UUID?
    var linkSource: UUID?
    var scale: CGFloat = 1
    var offset = NSPoint(x: 50, y: 50)
    private var down: NSPoint?
    private var original = NSPoint.zero
    private var moved = false
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    func world(_ p: NSPoint) -> NSPoint { NSPoint(x: (p.x - offset.x) / scale, y: (p.y - offset.y) / scale) }
    func screen(_ p: NSPoint) -> NSPoint { NSPoint(x: p.x * scale + offset.x, y: p.y * scale + offset.y) }
    func rect(_ n: ResearchGraph.Node) -> NSRect { NSRect(x: n.x, y: n.y, width: 240, height: 138) }
    func color(_ kind: String) -> NSColor {
        switch kind { case "问题": return NSColor(srgbRed: 0.78, green: 0.61, blue: 1, alpha: 1); case "观点", "Idea": return .systemOrange; case "实验": return StarGlass.accent; case "结果": return .systemGreen; case "失败": return .systemRed; default: return .systemTeal }
    }
    private func label(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor, bold: Bool = false) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: AppFont.font(size, weight: bold ? .semibold : .regular), .foregroundColor: color, .paragraphStyle: style])
    }
    func endpoints(_ e: ResearchGraph.Edge) -> (NSPoint, NSPoint)? {
        guard visibleIDs.contains(e.from), visibleIDs.contains(e.to), let a = graph.nodes.first(where: { $0.id == e.from }), let b = graph.nodes.first(where: { $0.id == e.to }) else { return nil }
        let ac = NSPoint(x: a.x + 120, y: a.y + 69), bc = NSPoint(x: b.x + 120, y: b.y + 69)
        let dx = bc.x - ac.x, dy = bc.y - ac.y
        guard abs(dx) + abs(dy) > 0.1 else { return nil }
        let t = min(120 / max(abs(dx), 0.001), 69 / max(abs(dy), 0.001))
        return (NSPoint(x: ac.x + dx * t, y: ac.y + dy * t), NSPoint(x: bc.x - dx * t, y: bc.y - dy * t))
    }
    override func draw(_ dirtyRect: NSRect) {
        StarGlass.panel.withAlphaComponent(0.25).setFill(); bounds.fill()
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform(); transform.translateX(by: offset.x, yBy: offset.y); transform.scale(by: scale); transform.concat()
        let tl = world(.zero), br = world(NSPoint(x: bounds.maxX, y: bounds.maxY))
        StarGlass.accent.withAlphaComponent(0.20).setFill()
        let spacing: CGFloat = scale < 0.5 ? 80 : 32
        for x in stride(from: floor(tl.x / spacing) * spacing, through: br.x, by: spacing) {
            for y in stride(from: floor(tl.y / spacing) * spacing, through: br.y, by: spacing) { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill() }
        }
        for e in graph.edges {
            guard let (a,b) = endpoints(e) else { continue }
            let ink: NSColor = selectedEdge == e.id ? .systemPurple : .secondaryLabelColor
            ink.setStroke(); let line = NSBezierPath(); line.move(to: a); line.line(to: b); line.lineWidth = selectedEdge == e.id ? 3 : 1.5; line.stroke()
            let angle = atan2(b.y-a.y,b.x-a.x)
            let arrow = NSBezierPath(); arrow.move(to: b)
            arrow.line(to: NSPoint(x: b.x - 12*cos(angle-0.45), y: b.y - 12*sin(angle-0.45)))
            arrow.line(to: NSPoint(x: b.x - 12*cos(angle+0.45), y: b.y - 12*sin(angle+0.45))); arrow.close(); ink.setFill(); arrow.fill()
            let r = NSRect(x: (a.x+b.x)/2 - 28, y: (a.y+b.y)/2 - 10, width: 64, height: 21)
            StarGlass.panel.setFill(); NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill()
            label(e.relation, in: r.insetBy(dx: 5, dy: 2), size: 11, color: ink)
        }
        for n in graph.nodes where visibleIDs.contains(n.id) {
            let r = rect(n), ink = color(n.kind)
            StarGlass.panel.setFill(); let path = NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14); path.fill()
            (n.id == selectedNode || n.id == linkSource ? ink : ink.withAlphaComponent(0.25)).setStroke()
            path.lineWidth = n.id == selectedNode || n.id == linkSource ? 3 : 1; path.stroke()
            label(n.kind + (n.important ? "  ★ 重点" : ""), in: NSRect(x: r.minX+14, y: r.minY+12, width: 210, height: 18), size: 12, color: ink, bold: true)
            label(n.title, in: NSRect(x: r.minX+14, y: r.minY+38, width: 212, height: 36), size: 15, color: .labelColor, bold: true)
            label(n.body.replacingOccurrences(of: "\n", with: " "), in: NSRect(x: r.minX+14, y: r.minY+80, width: 212, height: 20), size: 12, color: .secondaryLabelColor)
            label(n.status, in: NSRect(x: r.minX+14, y: r.minY+110, width: 212, height: 18), size: 11, color: ink)
        }
        NSGraphicsContext.restoreGraphicsState()
        if graph.nodes.isEmpty { label("双击空白，创建第一个研究节点\n问题 → 观点 → 实验 → 结果", in: NSRect(x: 40, y: 80, width: 430, height: 70), size: 20, color: .secondaryLabelColor) }
    }
    func node(at point: NSPoint) -> ResearchGraph.Node? { graph.nodes.reversed().first { visibleIDs.contains($0.id) && rect($0).contains(point) } }
    func edge(at p: NSPoint) -> UUID? {
        graph.edges.reversed().first { e in
            guard let (a,b) = endpoints(e) else { return false }
            let dx=b.x-a.x, dy=b.y-a.y, len=dx*dx+dy*dy
            guard len > 0 else { return false }
            let t = max(0,min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/len))
            return hypot(p.x-a.x-t*dx,p.y-a.y-t*dy) < 9 / scale
        }?.id
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil), w = world(p)
        down = p; moved = false
        if let n = node(at: w) {
            selectedNode = n.id; selectedEdge = nil; original = NSPoint(x: n.x, y: n.y)
            if controller?.connect.state == .on {
                if let from = linkSource, from != n.id { controller?.join(from,n.id); linkSource = nil }
                else { linkSource = n.id }
                down = nil
            } else if event.clickCount == 2 { down = nil; controller?.editSelection() }
        } else {
            selectedNode = nil; selectedEdge = edge(at: w); original = offset
            if event.clickCount == 2 && selectedEdge == nil { down = nil; controller?.editNode(nil, at: w) }
        }
        controller?.selectionChanged(); needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard let down else { return }
        let p = convert(event.locationInWindow, from: nil), delta = NSPoint(x: p.x-down.x,y:p.y-down.y)
        moved = hypot(delta.x,delta.y) > 2
        if let id = selectedNode, let i = graph.nodes.firstIndex(where: { $0.id == id }) {
            graph.nodes[i].x = max(-1_000_000,min(1_000_000,original.x+delta.x/scale))
            graph.nodes[i].y = max(-1_000_000,min(1_000_000,original.y+delta.y/scale))
        } else { offset = NSPoint(x: original.x+delta.x,y:original.y+delta.y) }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if moved, let id = selectedNode, let n = graph.nodes.first(where: { $0.id == id }) { controller?.move(id,to:NSPoint(x:n.x,y:n.y)) }
        down = nil; moved = false
    }
    func zoom(by factor: CGFloat, anchor: NSPoint) {
        let before = world(anchor); scale = max(0.2,min(2.5,scale*factor))
        offset = NSPoint(x:anchor.x-before.x*scale,y:anchor.y-before.y*scale); needsDisplay = true
    }
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { zoom(by: exp(-event.scrollingDeltaY*0.01), anchor: convert(event.locationInWindow,from:nil)) }
        else { offset.x -= event.scrollingDeltaX; offset.y -= event.scrollingDeltaY; needsDisplay = true }
    }
    override func magnify(with event: NSEvent) { zoom(by: 1+event.magnification, anchor: convert(event.locationInWindow,from:nil)) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { linkSource = nil; controller?.connect.state = .off; needsDisplay = true }
        else { super.keyDown(with: event) }
    }
    func fit() {
        let nodes = graph.nodes.filter { visibleIDs.contains($0.id) }
        guard let first = nodes.first else { scale = 1; offset = NSPoint(x:50,y:50); needsDisplay = true; return }
        let r = nodes.reduce(rect(first)) { $0.union(rect($1)) }.insetBy(dx:-40,dy:-40)
        scale = max(0.2,min(1.3,min(bounds.width/r.width,bounds.height/r.height)))
        offset = NSPoint(x:bounds.midX-r.midX*scale,y:bounds.midY-r.midY*scale); needsDisplay = true
    }
}
