import AppKit
import UniformTypeIdentifiers

final class ResearchWorkspaceWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    unowned let app: AppDelegate
    let navigation = NSSegmentedControl(labels: ["概览", "任务 Tasks", "项目 Projects", "专注 Focus", "Session 记录", "设置", "研究看板", "日程目标"], trackingMode: .selectOne, target: nil, action: nil)
    let search = NSSearchField()
    let filter = NSPopUpButton()
    let table = NSTableView()
    let detail = NSTextView()
    let summary = NSTextField(labelWithString: "")
    let create = NSButton(title: "新建", target: nil, action: nil)
    let edit = NSButton(title: "编辑 / 短记", target: nil, action: nil)
    let start = NSButton(title: "去专注", target: nil, action: nil)
    let complete = NSButton(title: "完成 / 重开", target: nil, action: nil)
    let archive = NSButton(title: "归档 / 恢复", target: nil, action: nil)
    var rowIDs: [UUID] = []
    var rowValues: [[String]] = []
    var selection: UUID? { table.selectedRow >= 0 && table.selectedRow < rowIDs.count ? rowIDs[table.selectedRow] : nil }
    var state: ResearchState { app.research.state }

    init(delegate: AppDelegate) {
        app = delegate
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "🍅 Research Workspace · 科研工作台"
        window.minSize = NSSize(width: 1100, height: 600)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
        navigation.selectedSegment = 0; navigation.target = self; navigation.action = #selector(pageChanged)
        search.placeholderString = "搜索名称 / 短记"
        search.target = self; search.action = #selector(filterChanged)
        search.widthAnchor.constraint(equalToConstant: 220).isActive = true
        filter.addItems(withTitles: ["全部（未归档）", "Inbox", "今天", "本周", "已完成", "已归档"])
        filter.target = self; filter.action = #selector(filterChanged)
        let buttons: [(NSButton, Selector)] = [(create, #selector(newItem)), (edit, #selector(editItem)), (start, #selector(focusItem)), (complete, #selector(completeItem)), (archive, #selector(archiveItem))]
        for (button, action) in buttons { button.bezelStyle = .rounded; button.target = self; button.action = action }
        let toolbar = glassStack([search, filter, create, edit, start, complete, archive], vertical: false, spacing: 6)
        for (name, width) in [("名称 / 任务", 340.0), ("项目 / 状态", 230), ("时间 / 进度", 190)] {
            let c = NSTableColumn(identifier: .init(name)); c.title = name; c.width = width; table.addTableColumn(c)
        }
        table.delegate = self; table.dataSource = self
        table.usesAlternatingRowBackgroundColors = true; table.rowHeight = 34
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = table
        detail.isEditable = false; detail.isSelectable = true; detail.font = AppFont.font(14)
        detail.textContainerInset = NSSize(width: 14, height: 14)
        detail.isVerticallyResizable = true; detail.autoresizingMask = [.width]
        detail.textContainer?.widthTracksTextView = true
        let details = NSScrollView(); details.hasVerticalScroller = true; details.documentView = detail
        let layout = glassStack([navigation, summary, toolbar, scroll, details], spacing: 14)
        let root = ResearchSurface(); window.contentView = root
        root.addSubview(layout); layout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            layout.topAnchor.constraint(equalTo: root.topAnchor, constant: 20), layout.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            layout.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20), layout.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            scroll.widthAnchor.constraint(equalTo: layout.widthAnchor), scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            details.widthAnchor.constraint(equalTo: layout.widthAnchor), details.heightAnchor.constraint(equalToConstant: 225)
        ])
        AppFont.apply(to: root); StarGlass.apply(to: root)
        window.center(); reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func pageChanged() {
        filter.selectItem(at: 0); search.stringValue = ""; reload()
        if navigation.selectedSegment == 3 { app.showSettings() }
        if navigation.selectedSegment == 6 { app.showResearchBoard() }
        if navigation.selectedSegment == 7 { app.showSchedule() }
    }
    @objc func filterChanged() { reload() }
    func numberOfRows(in tableView: NSTableView) -> Int { rowValues.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, let index = table.tableColumns.firstIndex(of: column) else { return nil }
        let label = NSTextField(labelWithString: rowValues[row][index])
        label.font = AppFont.font(13); label.lineBreakMode = .byTruncatingTail; label.toolTip = label.stringValue
        return label
    }
    func tableViewSelectionDidChange(_ notification: Notification) { showDetail() }
    func reload() {
        let selected = selection
        let page = navigation.selectedSegment
        let now = Date(), day = Calendar.current.dateInterval(of: .day, for: Date())!
        let today = state.activityLog(at: now).entries.filter { $0.category != "休息" }.reduce(0) { $0 + $1.seconds(in: day) }
        summary.stringValue = "今日投入 \(ActivityLog.duration(today))  ·  \(state.projects.filter { $0.archivedAt == nil }.count) 个项目  ·  \(state.tasks.filter { $0.completedAt == nil && $0.archivedAt == nil }.count) 个待办"
        rowIDs = []; rowValues = []
        let query = search.stringValue.lowercased()
        if page == 2 {
            for p in state.projects where (filter.indexOfSelectedItem == 5 ? p.archivedAt != nil : p.archivedAt == nil) && (query.isEmpty || (p.title + p.goal).lowercased().contains(query)) {
                rowIDs.append(p.id); rowValues.append([p.title, p.stage, p.progress])
            }
        } else if page == 0 || page == 1 {
            for t in state.tasks where matches(t) && (query.isEmpty || (t.title + t.description).lowercased().contains(query)) {
                rowIDs.append(t.id)
                rowValues.append([t.title, projectName(t.projectID), "\(t.status) · \(t.schedule)"])
            }
        } else if page == 4 {
            for s in state.sessions.reversed() where query.isEmpty || (s.title + s.note.text).lowercased().contains(query) {
                rowIDs.append(s.id)
                rowValues.append([s.title, "\(projectName(s.projectID)) · \(s.workType)", ActivityLog.duration(s.seconds(at: now))])
            }
        }
        create.isEnabled = page == 0 || page == 1 || page == 2
        filter.isEnabled = page == 0 || page == 1 || page == 2
        table.reloadData()
        if let selected, let index = rowIDs.firstIndex(of: selected) { table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false) }
        showDetail()
    }
    private func matches(_ t: ResearchTask) -> Bool {
        let cal = Calendar.current, now = Date()
        switch filter.indexOfSelectedItem {
        case 5: return t.archivedAt != nil
        case 4: return t.archivedAt == nil && t.completedAt != nil
        case 1: return t.archivedAt == nil && t.completedAt == nil && t.schedule == "Inbox"
        case 2: return t.archivedAt == nil && t.completedAt == nil && t.scheduledDate.map { cal.isDate($0, inSameDayAs: now) } == true
        case 3: return t.archivedAt == nil && t.completedAt == nil && t.scheduledDate.map { cal.dateInterval(of: .weekOfYear, for: now)!.contains($0) } == true
        default: return t.archivedAt == nil
        }
    }
    private func projectName(_ id: UUID?) -> String { state.projects.first { $0.id == id }?.title ?? "未分配项目" }
    private func stamp(_ date: Date) -> String { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: date) }
    func showDetail() {
        let page = navigation.selectedSegment, id = selection
        edit.isEnabled = id != nil; start.isEnabled = page == 3 || (id != nil && page != 4)
        complete.isEnabled = id != nil && (page == 0 || page == 1)
        archive.isEnabled = id != nil && (page == 0 || page == 1 || page == 2)
        if page == 5 {
            create.isEnabled = true; create.title = "导出完整备份"
            edit.isEnabled = true; edit.title = "导入备份（合并）"
            detail.string = "设置与数据\n\n字体、背景、透明度和提示音：在 Focus 窗口的「我的空间」设置。\n科研数据：本机 Application Support 下 research.sqlite。旧版原始数据保留于 legacy-v1-backup.json。\n完整备份导出项目、任务、Session、短记、研究看板与月/周目标；导入按 ID 合并，相同 ID 内容冲突会拒绝，避免覆盖当前记录。导入前自动保存本机备份。\n当前仍离线运行；研究看板可由顶部或菜单栏打开。习惯、日志与 AI 分析将在后续阶段加入。"
            return
        }
        create.title = "新建"; edit.title = "编辑 / 短记"
        if let p = state.projects.first(where: { $0.id == id }), page == 2 {
            let seconds = state.sessions.filter { $0.projectID == p.id && $0.category != "休息" }.reduce(0) { $0 + $1.seconds(at: Date()) }
            detail.string = "\(p.title) · \(p.stage) · \(p.progress)\n目标：\(p.goal)\n下一步：\(p.nextAction)\n累计投入：\(ActivityLog.duration(seconds))\n\n里程碑\n" + p.milestones.map { "\($0.done ? "☑" : "☐") \($0.title)" }.joined(separator: "\n") + "\n\n本周目标\n" + p.weeklyObjectives.filter { Calendar.current.isDate($0.weekStart, equalTo: Date(), toGranularity: .weekOfYear) }.map { "\($0.done ? "☑" : "☐") \($0.title)" }.joined(separator: "\n")
            let planned = (state.schedule?.goals ?? []).filter { $0.projectID == p.id && $0.kind == "week" && $0.period == PlanDates.week(Date()) }
            if !planned.isEmpty { detail.string += "\n\n日程周目标\n" + planned.map { "\($0.done ? "☑" : "☐") \($0.title)" }.joined(separator:"\n") }
        } else if let t = state.tasks.first(where: { $0.id == id }), page == 0 || page == 1 {
            let seconds = state.sessions.filter { $0.taskID == t.id }.reduce(0) { $0 + $1.seconds(at: Date()) }
            detail.string = "\(t.title)\n\(projectName(t.projectID)) · \(t.status) · \(t.priority)\n安排：\(t.schedule) \(t.scheduledDate.map(stamp) ?? "")\n截止：\(t.dueDate.map(stamp) ?? "未设置")\n累计：\(ActivityLog.duration(seconds))\n\n\(t.description)\n\nID：\(t.id.uuidString)"
        } else if let s = state.sessions.first(where: { $0.id == id }), page == 4 {
            detail.string = "\(s.title) · \(s.workType) · \(s.isOpen ? (s.countdown.isPaused ? "暂停中" : "计时中") : s.reason)\n\(stamp(s.createdAt)) → \(s.endedAt.map(stamp) ?? "未结束")\n\(s.segments.count) 个已保存片段 · 来源 \(s.source)\(s.source == "legacy" ? "（旧版番茄次数不可还原）" : "")\n\n短记：\(s.note.text)\n结果：\(s.note.result)\n发现：\(s.note.finding)\n问题：\(s.note.question)\nIdea：\(s.note.idea)\n下一步：\(s.note.nextAction)"
        } else { detail.string = page == 3 ? "Focus\n\n沿用原来的番茄钟。选择项目、任务、工作类型后开始。暂停和继续属于同一个 Session；结束可快速短记，也可以稍后补写。\n\n点击「去专注」打开番茄钟。" : "欢迎来到科研工作台\n\n先新建一个项目或临时任务，再开始专注。任务可保留在 Inbox，也可安排到今天、本周或指定日期。\n选择列表中的记录查看详情；Session 页面可补写记录。\n项目、任务不会自动变成节点；请在「研究看板」手动整理重要问题、观点和实验。" }
    }
    @objc func newItem() {
        if navigation.selectedSegment == 5 { exportBackup(); return }
        if navigation.selectedSegment == 2 { editProject(nil) } else { editTask(nil) }
    }
    @objc func editItem() {
        if navigation.selectedSegment == 5 { importBackup(); return }
        guard let id = selection else { return }
        if navigation.selectedSegment == 2 { editProject(state.projects.first { $0.id == id }) }
        else if navigation.selectedSegment == 4 { editNote(id) }
        else { editTask(state.tasks.first { $0.id == id }) }
    }
    @objc func focusItem() {
        guard app.research.current == nil else { app.showSettings(); return }
        if navigation.selectedSegment == 2 { app.selectedProjectID = selection; app.selectedTaskID = nil }
        else if let t = state.tasks.first(where: { $0.id == selection }) {
            guard t.archivedAt == nil, t.completedAt == nil else { return }
            app.selectedProjectID = t.projectID; app.selectedTaskID = t.id
        }
        app.showSettings()
    }
    @objc func completeItem() {
        guard let id = selection, let task = state.tasks.first(where: { $0.id == id }) else { return }
        _ = app.researchAction {
            if task.completedAt == nil { try app.research.completeTask(id, at: Date()) }
            else { try app.research.change { s in let i = s.tasks.firstIndex { $0.id == id }!; s.tasks[i].completedAt = nil; s.tasks[i].status = "待办"; s.tasks[i].updatedAt = Date() } }
        }
        app.refresh(); app.refreshResearchPickers(); reload()
    }
    @objc func archiveItem() {
        guard let id = selection else { return }
        _ = app.researchAction { try app.research.change { s in
            if let i = s.projects.firstIndex(where: { $0.id == id }), navigation.selectedSegment == 2 {
                guard app.research.current?.projectID != id else { throw ResearchError.message("请先结束该项目的计时") }
                s.projects[i].archivedAt = s.projects[i].archivedAt == nil ? Date() : nil; s.projects[i].updatedAt = Date()
            } else if let i = s.tasks.firstIndex(where: { $0.id == id }) {
                guard app.research.current?.taskID != id else { throw ResearchError.message("请先结束该任务的计时") }
                s.tasks[i].archivedAt = s.tasks[i].archivedAt == nil ? Date() : nil; s.tasks[i].updatedAt = Date()
            }
        } }
        app.refreshResearchPickers(); reload()
    }

    private func text(_ value: String, multiline: Bool = false) -> NSTextField {
        let field = multiline ? NSTextField(wrappingLabelWithString: value) : NSTextField(string: value)
        field.isEditable = true; field.isSelectable = true; field.isBezeled = true; field.drawsBackground = true
        field.font = AppFont.font(13)
        field.widthAnchor.constraint(equalToConstant: 550).isActive = true
        if multiline { field.heightAnchor.constraint(equalToConstant: 66).isActive = true; field.maximumNumberOfLines = 0 }
        return field
    }
    private func picker(_ titles: [String], selected: String) -> NSPopUpButton {
        let p = NSPopUpButton(); p.addItems(withTitles: titles); p.selectItem(withTitle: selected); return p
    }
    private func datePicker(_ date: Date?) -> NSDatePicker {
        let p = NSDatePicker(); p.datePickerElements = [.yearMonthDay]; p.dateValue = date ?? Date(); return p
    }
    private func form(_ title: String, _ items: [(String, NSView)]) -> Bool {
        let alert = NSAlert(); alert.messageText = title
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 590, height: min(510, items.count * 88)))
        scroll.hasVerticalScroller = true
        scroll.contentView.wantsLayer = true; scroll.contentView.layer?.masksToBounds = true
        let stack = glassStack(items.flatMap { [NSTextField(labelWithString: $0.0), $0.1] }, spacing: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = ResearchFormDocument(); content.addSubview(stack); scroll.documentView = content
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 10), stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            content.widthAnchor.constraint(equalToConstant: 575)
        ])
        content.layoutSubtreeIfNeeded(); content.setFrameSize(content.fittingSize)
        scroll.documentView?.scroll(.zero)
        AppFont.apply(to: stack); alert.accessoryView = scroll
        return alert.runGlassModal() == .alertFirstButtonReturn
    }
    private func editProject(_ existing: ResearchProject?) {
        var project = existing ?? ResearchProject(title: "")
        let title = text(project.title), goal = text(project.goal, multiline: true), next = text(project.nextAction, multiline: true)
        let stage = text(project.stage)
        let milestones = text(project.milestones.map { "\($0.done ? "[x]" : "[ ]") \($0.title)" }.joined(separator: "\n"), multiline: true)
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
        let current = project.weeklyObjectives.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: week) }
        let weekly = text(current.map { "\($0.done ? "[x]" : "[ ]") \($0.title)" }.joined(separator: "\n"), multiline: true)
        guard form(existing == nil ? "新建项目" : "编辑项目", [("名称", title), ("目标", goal), ("当前阶段", stage), ("下一步", next), ("里程碑：每行一项，[x] 已完成 / [ ] 待完成", milestones), ("本周目标：每行一项，[x] 已完成 / [ ] 待完成", weekly)]) else { return }
        func lines(_ text: String) -> [(String, Bool)] { text.components(separatedBy: .newlines).compactMap { line in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let done = value.lowercased().hasPrefix("[x]")
            return (value.hasPrefix("[ ]") || done ? String(value.dropFirst(3)).trimmingCharacters(in: .whitespaces) : value, done)
        } }
        project.title = title.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); project.goal = goal.stringValue
        project.stage = stage.stringValue; project.nextAction = next.stringValue; project.updatedAt = Date()
        project.milestones = lines(milestones.stringValue).enumerated().map { index, line in
            var m = ResearchProject.Milestone(title: line.0, done: line.1)
            if index < project.milestones.count { m.id = project.milestones[index].id }; return m
        }
        project.weeklyObjectives.removeAll { Calendar.current.isDate($0.weekStart, inSameDayAs: week) }
        project.weeklyObjectives += lines(weekly.stringValue).enumerated().map { index, line in
            var item = ResearchProject.WeeklyObjective(title: line.0, weekStart: week, done: line.1)
            if index < current.count { item.id = current[index].id }; return item
        }
        _ = app.researchAction { try app.research.change { s in
            if let i = s.projects.firstIndex(where: { $0.id == project.id }) { s.projects[i] = project } else { s.projects.append(project) }
        } }
        app.refreshResearchPickers(); reload()
    }
    private func editTask(_ existing: ResearchTask?) {
        var task = existing ?? ResearchTask(title: "")
        let title = text(task.title), description = text(task.description, multiline: true)
        let project = NSPopUpButton(); project.addItem(withTitle: "不关联项目（临时任务）")
        for p in state.projects where p.archivedAt == nil || p.id == task.projectID {
            project.addItem(withTitle: p.title); project.lastItem?.representedObject = p.id.uuidString
            if p.id == task.projectID { project.select(project.lastItem) }
        }
        // Reparenting a task with sessions would reinterpret historical research context.
        project.isEnabled = !state.sessions.contains { $0.taskID == task.id }
        let status = picker(["待办", "进行中", "已完成"], selected: task.status)
        let priority = picker(["低", "普通", "高"], selected: task.priority)
        let schedule = picker(["Inbox", "今天", "本周", "指定日期"], selected: task.schedule)
        let scheduled = datePicker(task.scheduledDate), due = datePicker(task.dueDate)
        let hasDue = NSButton(checkboxWithTitle: "设置截止日期", target: nil, action: nil); hasDue.state = task.dueDate == nil ? .off : .on
        guard form(existing == nil ? "新建任务" : "编辑任务", [("名称", title), ("说明", description), ("所属项目（已有记录后不可换绑）", project), ("状态", status), ("优先级", priority), ("安排", schedule), ("指定日期（仅在选择指定日期时生效）", scheduled), ("截止日期", hasDue), ("截止日期值", due)]) else { return }
        task.title = title.stringValue.trimmingCharacters(in: .whitespacesAndNewlines); task.description = description.stringValue
        task.projectID = (project.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:))
        task.status = status.titleOfSelectedItem!; task.priority = priority.titleOfSelectedItem!; task.schedule = schedule.titleOfSelectedItem!
        switch task.schedule {
        case "今天": task.scheduledDate = Calendar.current.startOfDay(for: Date())
        case "本周": task.scheduledDate = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
        case "指定日期": task.scheduledDate = scheduled.dateValue
        default: task.scheduledDate = nil
        }
        if existing?.plannedDay != nil {
            task.plannedDay = task.scheduledDate.map { PlanDates.key($0) }
            if task.plannedDay == nil { task.planningGoalID = nil; task.plannedMinutes = nil }
        }
        task.dueDate = hasDue.state == .on ? due.dateValue : nil
        task.completedAt = task.status == "已完成" ? (task.completedAt ?? Date()) : nil; task.updatedAt = Date()
        _ = app.researchAction {
            if app.research.current?.taskID == task.id && task.completedAt != nil { throw ResearchError.message("请使用任务列表的完成按钮结束当前任务，或先结束计时") }
            try app.research.change { s in
                if let i = s.tasks.firstIndex(where: { $0.id == task.id }) { s.tasks[i] = task } else { s.tasks.append(task) }
            }
        }
        app.refreshResearchPickers(); reload()
    }
    private func editNote(_ id: UUID) {
        guard let s = state.sessions.first(where: { $0.id == id }) else { return }
        let values = [s.note.text, s.note.result, s.note.finding, s.note.question, s.note.idea, s.note.nextAction].map { text($0, multiline: true) }
        guard form("Session 短记 · 每项都可留空", Array(zip(["做了什么", "结果", "发现", "问题", "Idea", "下一步"], values))) else { return }
        _ = app.researchAction { try app.research.change { state in
            let i = state.sessions.firstIndex { $0.id == id }!
            state.sessions[i].note = SessionNote(text: values[0].stringValue, result: values[1].stringValue, finding: values[2].stringValue, question: values[3].stringValue, idea: values[4].stringValue, nextAction: values[5].stringValue)
        } }
        reload()
    }
    private func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Research-OS-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ResearchBackup.encode(state).write(to: url, options: .atomic) } catch { NSApp.presentError(error) }
    }
    private func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 50_000_000 else { throw ResearchError.message("备份文件最大 50 MB") }
            let imported = try JSONDecoder().decode(ResearchState.self, from: Data(contentsOf: url))
            let merged = try ResearchBackup.merge(imported, into: state)
            let alert = NSAlert(); alert.messageText = "确认合并科研备份？"
            alert.informativeText = "导入文件包含 \(imported.projects.count) 个项目、\(imported.tasks.count) 个任务、\(imported.sessions.count) 个 Session、\(imported.graph?.nodes.count ?? 0) 个研究节点、\(imported.schedule?.goals.count ?? 0) 个日程目标。相同内容不会重复导入。"
            alert.addButton(withTitle: "合并"); alert.addButton(withTitle: "取消")
            guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
            // Revalidate against current state after the modal loop (the timer may have advanced).
            _ = merged
            let storeURL = (app.research.repository as? SQLiteResearchStore)?.url
            if let storeURL {
                try ResearchBackup.encode(state).write(to: storeURL.deletingLastPathComponent().appendingPathComponent("before-import-\(UUID().uuidString).json"), options: .atomic)
            }
            _ = app.researchAction { try app.research.change { state in state = try ResearchBackup.merge(imported, into: state) } }
            if let session = app.research.current {
                app.selectedProjectID = session.projectID; app.selectedTaskID = session.taskID
                app.activityTitle = session.title; app.activityCategory = session.category
                app.workTypePicker?.selectItem(withTitle: session.workType)
            }
            app.refreshResearchPickers(); app.refresh(); reload()
        } catch { NSApp.presentError(error) }
    }
}


private final class ResearchSurface: StarfieldSurface {}


private final class ResearchFormDocument: NSView {
    override var isFlipped: Bool { true }
}
