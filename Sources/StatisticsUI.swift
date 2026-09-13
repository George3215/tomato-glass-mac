import AppKit
import UniformTypeIdentifiers

extension AppDelegate {
    @objc func showStatistics() {
        if statisticsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 650), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "时间记录 · 番茄时光"
            window.appearance = NSAppearance(named: .aqua)
            window.minSize = NSSize(width: 980, height: 530)
            window.isReleasedWhenClosed = false
            let board = StatisticsBoard(delegate: self)
            board.onRefresh = { [weak self] in self?.refreshStatistics() }
            window.contentView = board
            statisticsBoard = board
            statisticsDate = board.date
            statisticsWindow = window
            AppFont.apply(to: board); SoftGlass.apply(to: board)
            window.center()
        }
        refreshStatistics()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        statisticsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func refreshStatistics() { statisticsBoard?.reload(log: activityLog, now: Date(), tasks: research.state.tasks) }

    @objc func completeTask() {
        guard let id = research.current?.taskID ?? selectedTaskID else { showWorkspace(); return }
        _ = researchAction { try research.completeTask(id, at: Date()) }
        refresh(); refreshResearchPickers(); showStatistics()
    }

    @objc func addManualActivity() {
        let alert = NSAlert()
        alert.messageText = "补记一段活动"
        alert.informativeText = "填写实际开始和结束时间；不能与已有记录重叠，也不能记录未来。"
        let task = NSTextField(string: activityTitle)
        let category = NSPopUpButton()
        category.addItems(withTitles: ["学习", "工作", "休息", "其他"])
        let start = NSDatePicker(), end = NSDatePicker()
        for picker in [start, end] { picker.datePickerElements = [.yearMonthDay, .hourMinuteSecond] }
        end.dateValue = Date()
        start.dateValue = Date().addingTimeInterval(-1800)
        let stack = glassStack([NSTextField(labelWithString: "任务名称"), task, category,
            NSTextField(labelWithString: "开始"), start, NSTextField(labelWithString: "结束"), end], spacing: 8)
        stack.frame = NSRect(x: 0, y: 0, width: 400, height: 230)
        task.widthAnchor.constraint(equalToConstant: 380).isActive = true
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
        let entry = Activity(task: task.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), category: category.titleOfSelectedItem!, start: start.dateValue, end: end.dateValue, reason: "手动补记")
        if researchAction({ try research.importActivities([entry], now: Date()) }) { refreshStatistics() }
        else {
            let warning = NSAlert()
            warning.messageText = "未保存"
            warning.informativeText = "请检查任务名、起止时间和是否与已有记录重叠。"
            warning.runGlassModal()
        }
    }

    @objc func exportActivity() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "时间记录.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ("\u{feff}" + activityLog.csv(at: Date())).write(to: url, atomically: true, encoding: .utf8) }
        catch { NSApp.presentError(error) }
    }
}

extension AppDelegate {
    @objc func importActivity() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_000_000 else { throw ActivityImport.error("JSON 文件不能超过 1 MB。") }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let batch = try decoder.decode(ActivityImport.self, from: Data(contentsOf: url))
            _ = try batch.applying(to: activityLog, now: Date())
            let alert = NSAlert()
            alert.messageText = "预览补记 · \(batch.entries.count) 条"
            alert.informativeText = "请核对任务、分类与时间。确认后才写入本机记录。来源：\(batch.source == "ai" ? "AI补记" : "导入补记")"
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 540, height: 260))
            scroll.hasVerticalScroller = true
            let text = NSTextView(frame: scroll.bounds)
            text.isEditable = false
            text.isVerticallyResizable = true
            text.textContainer?.widthTracksTextView = true
            text.autoresizingMask = [.width]
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd HH:mm:ss"
            text.string = batch.entries.map { "[\($0.category)] \($0.task)\n\(format.string(from: $0.start)) → \(format.string(from: $0.end))\n" }.joined(separator: "\n")
            text.font = AppFont.font(13)
            scroll.documentView = text
            alert.accessoryView = scroll
            alert.addButton(withTitle: "确认导入")
            alert.addButton(withTitle: "取消")
            guard alert.runGlassModal() == .alertFirstButtonReturn else { return }
            let entries = batch.entries.map { Activity(task: $0.task, category: $0.category, start: $0.start, end: $0.end, reason: batch.source == "ai" ? "AI补记" : "导入补记") }
            try research.importActivities(entries, now: Date())
            workspace?.reload()
            refreshStatistics()
        } catch { NSApp.presentError(error) }
    }

    @objc func exportGapContext() {
        guard let date = statisticsDate?.dateValue,
              let day = Calendar.current.dateInterval(of: .day, for: date) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "补记上下文.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let now = Date()
        let format = ISO8601DateFormatter()
        let gaps = activityLog.gaps(in: day, now: now).map { ["start": format.string(from: $0.start), "end": format.string(from: $0.end)] }
        let context: [String: Any] = ["version": 1, "source": "ai", "entries": [],
            "unrecorded": gaps,
            "timezone": TimeZone.current.identifier,
            "instructions": "仅依据用户明确提供的实际活动填写 entries，不猜测空白时段。字段 task/category/start/end；分类为学习、工作、休息、其他。时间用带时区的 ISO 8601（精确到秒，无小数），不得重叠或记录未来。保留不确定时段为空。将完成的 JSON 交给用户核对后在番茄钟导入。"]
        do { try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic) }
        catch { NSApp.presentError(error) }
    }
}
