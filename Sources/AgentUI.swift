import AppKit
import UniformTypeIdentifiers

/// Deliberately refuses redirects so API credentials never follow another endpoint.
final class AgentTransport: NSObject, URLSessionTaskDelegate {
    let config: URLSessionConfiguration
    init(config: URLSessionConfiguration = .ephemeral) { self.config = config; super.init() }
    lazy var session: URLSession = {
        config.timeoutIntervalForRequest = 90
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

final class AgentController: NSWindowController {
    unowned let app: AppDelegate
    let conversations = NSPopUpButton()
    let proposals = NSPopUpButton()
    let transcript = NSTextView()
    let input = NSTextView()
    let includeContext = NSButton(checkboxWithTitle: "发送当前项目 / 任务 / 看板 / 日程上下文", target: nil, action: nil)
    let status = NSTextField(labelWithString: "先配置服务，或导入外部 Agent 的 JSON。聊天自动保存在本机。")
    let sendButton = NSButton(title: "发送", target: nil, action: nil)
    var transport = AgentTransport()
    var selectedID: UUID?
    var task: URLSessionDataTask?
    var requestID: UUID?
    var apiKey = "" // Only this window's memory; never in defaults, SQLite, exports or logs.
    var endpoint: String { UserDefaults.standard.string(forKey: "agentEndpoint") ?? "" }
    var model: String { UserDefaults.standard.string(forKey: "agentModel") ?? "" }
    var current: AgentConversation? { app.research.state.agent?.conversations.first { $0.id == selectedID } }

    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Agent Studio · 对话与积累"; window.minSize = NSSize(width: 1050, height: 700)
        window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: .aqua)
        super.init(window: window)
        func button(_ title: String, _ action: Selector) -> NSButton { let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b }
        let heading = ExhibitHeading("Agent Studio · 对话与积累", subtitle: "聊清问题 → 提出修改 → 预览应用 → 留下记录", color: ExhibitPalette.blocks[1])
        conversations.target = self; conversations.action = #selector(selectConversation)
        conversations.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let tools = glassStack([conversations, button("新对话", #selector(newConversation)), button("连接设置", #selector(configure)), button("导出上下文", #selector(exportContext)), button("导入回复", #selector(importReply)), button("预览 / 应用修改", #selector(previewChanges)), button("打开展板", #selector(openBoard)), button("编辑任务", #selector(openTasks))], vertical: false, spacing: 8)
        transcript.isEditable = false; transcript.isSelectable = true; transcript.font = AppFont.font(14)
        input.font = AppFont.font(14); input.isRichText = false
        let history = scroll(transcript), editor = scroll(input)
        sendButton.target = self; sendButton.action = #selector(send); sendButton.bezelStyle = .rounded
        proposals.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let actions = glassStack([sendButton, button("停止", #selector(cancel)), button("保存为复盘笔记", #selector(saveNote)), includeContext], vertical: false, spacing: 10)
        status.font = AppFont.font(12); status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        let proposalRow = glassStack([NSTextField(labelWithString: "选择修改提案"), proposals], vertical: false, spacing: 8)
        let inputHint = NSTextField(labelWithString: "输入消息，或写下一段复盘笔记…")
        let layout = glassStack([heading, tools, proposalRow, history, inputHint, editor, actions, status], spacing: 12)
        let root = GroupedSurface(); window.contentView = root; root.addSubview(layout); layout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([layout.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), layout.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20), layout.topAnchor.constraint(equalTo: root.topAnchor, constant: 20), layout.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20), heading.widthAnchor.constraint(equalTo: layout.widthAnchor), history.widthAnchor.constraint(equalTo: layout.widthAnchor), history.heightAnchor.constraint(greaterThanOrEqualToConstant: 280), editor.widthAnchor.constraint(equalTo: layout.widthAnchor), editor.heightAnchor.constraint(equalToConstant: 100), status.widthAnchor.constraint(equalTo: layout.widthAnchor)])
        AppFont.apply(to: root); SoftGlass.apply(to: root)
        editor.drawsBackground = true; editor.backgroundColor = .white
        input.drawsBackground = true; input.backgroundColor = .white
        if app.research.state.agent?.conversations.isEmpty != false { newConversation() } else { selectedID = app.research.state.agent?.conversations.last?.id; reload() }
        window.center()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func scroll(_ text: NSTextView) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = text
        text.isVerticallyResizable = true; text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true; text.textContainerInset = NSSize(width: 12, height: 12)
        return scroll
    }
    @discardableResult func change(_ body: (inout ResearchState) throws -> Void) -> Bool {
        app.researchAction { try app.research.change(body) }
    }
    @discardableResult func append(_ message: AgentMessage, to id: UUID) -> Bool {
        let saved = change { state in
            guard let index = state.agent?.conversations.firstIndex(where: { $0.id == id }) else { throw ResearchError.message("对话不存在") }
            state.agent?.conversations[index].messages.append(message)
            if state.agent?.conversations[index].messages.count == 1 { state.agent?.conversations[index].title = String(message.text.prefix(32)) }
        }
        reload(); return saved
    }
    func reload() {
        conversations.removeAllItems()
        for c in app.research.state.agent?.conversations ?? [] {
            conversations.addItem(withTitle: c.title); conversations.lastItem?.representedObject = c.id.uuidString
            if c.id == selectedID { conversations.select(conversations.lastItem) }
        }
        let format = DateFormatter(); format.dateFormat = "MM-dd HH:mm"
        transcript.string = current?.messages.map { m in
            let role = m.role == "user" ? "你" : m.role == "note" ? "复盘 / 记录" : "AI"
            let names = ["create_project":"创建项目", "create_task":"创建任务", "update_task":"修改任务", "create_node":"创建节点", "update_node":"修改节点", "create_edge":"创建连线"]
            let actions = (m.operations ?? []).map { "• \(names[$0.action] ?? $0.action) · \($0.title ?? $0.id.uuidString)" }.joined(separator: "\n")
            let suffix = actions.isEmpty ? "" : "\n\n" + (m.appliedAt == nil ? "待预览修改" : "已应用修改") + "\n" + actions
            return "\(role)  ·  \(format.string(from: m.createdAt))\n\(m.text)\(suffix)"
        }.joined(separator: "\n\n────────────────────────\n\n") ?? ""
        let priorProposal = proposals.selectedItem?.representedObject as? String
        proposals.removeAllItems()
        for message in current?.messages ?? [] where !(message.operations ?? []).isEmpty {
            proposals.addItem(withTitle: (message.appliedAt == nil ? "待应用 · " : "已应用 · ") + String(message.text.prefix(35)))
            proposals.lastItem?.representedObject = message.id.uuidString
        }
        if let item = proposals.itemArray.first(where: { ($0.representedObject as? String) == priorProposal }) { proposals.select(item) }
        else { proposals.select(proposals.lastItem) }
        transcript.scrollToEndOfDocument(nil)
        sendButton.isEnabled = requestID == nil
    }
    @objc func selectConversation() { selectedID = (conversations.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:)); reload() }
    @objc func newConversation() {
        let c = AgentConversation(title: "新对话")
        if change({ state in if state.agent == nil { state.agent = AgentArchive() }; state.agent?.conversations.append(c) }) { selectedID = c.id; reload() }
    }
    @objc func saveNote() {
        guard let id = selectedID, !input.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if append(AgentMessage(role: "note", text: input.string), to: id) { input.string = ""; status.stringValue = "复盘笔记已保存。" }
    }
    @objc func openTasks() { app.showWorkspace(); app.workspace?.navigation.selectedSegment = 1; app.workspace?.reload() }
    @objc func openBoard() { app.showResearchBoard() }
    @objc func configure() {
        let alert = NSAlert(); alert.messageText = "连接 AI 服务"
        alert.informativeText = "填写完整 Chat Completions 地址。仅在点击发送时联网；API Key 只保留在本次运行内存中。"
        let url = NSTextField(string: endpoint), name = NSTextField(string: model), key = NSSecureTextField(string: apiKey)
        url.placeholderString = "https://服务地址/v1/chat/completions"; name.placeholderString = "模型 ID"
        let stack = glassStack([NSTextField(labelWithString: "完整接口地址"), url, NSTextField(labelWithString: "模型"), name, NSTextField(labelWithString: "API Key（本地服务可留空）"), key], spacing: 8)
        stack.frame = NSRect(x: 0, y: 0, width: 560, height: 180)
        for v in [url, name, key] { v.widthAnchor.constraint(equalToConstant: 540).isActive = true }
        alert.accessoryView = stack; alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
        let value = url.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        do { _ = try Self.endpointURL(value) } catch { status.stringValue = error.localizedDescription; return }
        UserDefaults.standard.set(value, forKey: "agentEndpoint"); UserDefaults.standard.set(name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "agentModel")
        apiKey = key.stringValue; status.stringValue = "连接设置已保存，尚未发送数据。"
    }
    static func endpointURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), let host = url.host, url.user == nil, url.password == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { throw ResearchError.message("服务地址需 HTTPS；本机服务支持 HTTP。") }
        return url
    }
    @objc func send() {
        guard requestID == nil, let c = current else { return }
        let text = input.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let url = try Self.endpointURL(endpoint)
            guard !model.isEmpty else { throw ResearchError.message("请先填写模型 ID") }
            var instructions = AgentActions.instructions
            if includeContext.state == .on { instructions += "\nUser-authorized current context:\n" + (try AgentActions.context(app.research.state)) }
            var messages = [["role": "system", "content": instructions]]
            for m in c.messages.filter({ $0.role != "note" }).suffix(20) {
                var content = m.text
                if let ops = m.operations, !ops.isEmpty { content += "\nProposal " + (m.appliedAt == nil ? "not applied" : "applied") + ": " + String(decoding: try JSONEncoder().encode(ops), as: UTF8.self) }
                messages.append(["role": m.role, "content": content])
            }
            messages.append(["role": "user", "content": text])
            let data = try JSONSerialization.data(withJSONObject: ["model": model, "messages": messages, "stream": false])
            guard data.count <= 2_000_000 else { throw ResearchError.message("上下文过大，请关闭上下文或新建对话") }
            var request = URLRequest(url: url); request.httpMethod = "POST"; request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty { request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization") }
            guard append(AgentMessage(role: "user", text: text), to: c.id) else { return }
            input.string = ""; let token = UUID(); requestID = token; reload()
            status.stringValue = "正在请求 \(url.host ?? "AI")… 用户消息已保存，可随时停止。"
            task = transport.session.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let self, self.requestID == token else { return }
                    self.requestID = nil; self.task = nil
                    do {
                        guard error == nil else { throw ResearchError.message("请求失败或超时；用户消息已保留，可重新发送。") }
                        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ResearchError.message("服务返回 HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)，请检查地址、模型和授权。") }
                        guard let data, data.count <= 2_000_000,
                              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any],
                              let content = message["content"] as? String else { throw ResearchError.message("服务返回格式不兼容或内容过大。支持非流式 Chat Completions。") }
                        let reply = AgentReply.parse(content)
                        if self.append(AgentMessage(role: "assistant", text: reply.reply, operations: reply.operations), to: c.id) { self.status.stringValue = "回复已保存；有修改建议时，点击“预览 / 应用修改”。" }
                    } catch { self.status.stringValue = error.localizedDescription; _ = self.append(AgentMessage(role: "note", text: error.localizedDescription), to: c.id) }
                    self.reload()
                }
            }
            task?.resume()
        } catch { status.stringValue = error.localizedDescription }
    }
    @objc func cancel() {
        guard requestID != nil else { return }
        requestID = nil; task?.cancel(); task = nil; status.stringValue = "请求已停止，已保存的消息保留。"; reload()
    }
    @objc func exportContext() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "agent-context.json"; panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let object: [String: Any] = ["version": 1, "instructions": AgentActions.instructions, "context": try JSONSerialization.jsonObject(with: Data(AgentActions.context(app.research.state).utf8))]
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            status.stringValue = "上下文已导出（不含聊天历史、专注记录或 API Key）。"
        } catch { status.stringValue = error.localizedDescription }
    }
    @objc func importReply() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let id = selectedID else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 2_000_000 else { throw ResearchError.message("回复文件超过 2 MB") }
            let reply = try JSONDecoder().decode(AgentReply.self, from: Data(contentsOf: url))
            if append(AgentMessage(role: "assistant", text: reply.reply, operations: reply.operations), to: id) { status.stringValue = "已导入回复；操作尚未应用。" }
        } catch { status.stringValue = error.localizedDescription }
    }
    @objc func previewChanges() {
        guard let c = current, let message = c.messages.first(where: { $0.id.uuidString == (proposals.selectedItem?.representedObject as? String) && $0.appliedAt == nil && !($0.operations ?? []).isEmpty }) else { status.stringValue = "当前对话没有待应用的修改。"; return }
        do {
            _ = try AgentActions.applying(message.operations ?? [], to: app.research.state)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 620, height: 380)); text.isEditable = false; text.font = AppFont.font(13)
            text.string = String(decoding: try encoder.encode(message.operations), as: UTF8.self)
            let scroll = NSScrollView(frame: text.frame); scroll.hasVerticalScroller = true; scroll.documentView = text
            let alert = NSAlert(); alert.messageText = "应用 \(message.operations?.count ?? 0) 项修改？"
            alert.informativeText = "以下字段会写入任务 / 展板；所有操作一起保存，失败则全部不变。原始对话与应用时间保留。"; alert.accessoryView = scroll
            alert.addButton(withTitle: "应用全部"); alert.addButton(withTitle: "取消")
            guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
            if change({ try AgentActions.commit(messageID: message.id, conversationID: c.id, in: &$0) }) {
                app.workspace?.reload(); app.researchBoard?.reload(); app.scheduleWindow?.reload(); app.refreshResearchPickers(); app.refreshStatistics()
                status.stringValue = "修改已保存，可在任务、日程和展板中继续手动编辑。"; reload()
            }
        } catch { status.stringValue = error.localizedDescription }
    }
}
