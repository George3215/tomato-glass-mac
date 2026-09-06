import AppKit
import UniformTypeIdentifiers

extension AppDelegate {
    @objc func showStatistics() {
        if statisticsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "时间统计 · 任务与每日时间线"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 650, height: 450)
            let date = NSDatePicker()
            date.datePickerElements = [.yearMonthDay]
            date.dateValue = Date()
            date.target = self
            date.action = #selector(refreshStatistics)
            statisticsDate = date
            let refresh = glassButton("刷新", target: self, action: #selector(refreshStatistics))
            let manual = glassButton("补记时间", target: self, action: #selector(addManualActivity))
            let export = glassButton("导出全部 CSV", target: self, action: #selector(exportActivity))
            let toolbar = glassStack([date, refresh, manual, export], vertical: false, spacing: 12)
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.borderType = .bezelBorder
            let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 690, height: 540))
            text.isEditable = false
            text.isSelectable = true
            text.isVerticallyResizable = true
            text.autoresizingMask = [.width]
            text.textContainer?.widthTracksTextView = true
            text.textContainerInset = NSSize(width: 16, height: 16)
            text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            scroll.documentView = text
            statisticsText = text
            let content = window.contentView!
            for view in [toolbar, scroll] { view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(view) }
            NSLayoutConstraint.activate([
                toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
                toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
                scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 16),
                scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
                scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
                scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
            ])
            statisticsWindow = window
            window.center()
        }
        refreshStatistics()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        statisticsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func refreshStatistics() {
        guard let date = statisticsDate?.dateValue,
              let day = Calendar.current.dateInterval(of: .day, for: date) else { return }
        let now = Date()
        let records = activityLog.records(at: now)
        let daily = records.filter { $0.seconds(in: day) > 0 }.sorted { $0.start < $1.start }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        let title = DateFormatter()
        title.dateFormat = "yyyy-MM-dd EEEE"
        var lines = [title.string(from: date), "", "每日分类（实际记录时长）"]
        for category in ["学习", "工作", "休息", "其他"] {
            let seconds = daily.filter { $0.category == category }.reduce(0) { $0 + $1.seconds(in: day) }
            lines.append("  \(category)：\(ActivityLog.duration(seconds))")
        }
        let recorded = daily.reduce(0) { $0 + $1.seconds(in: day) }
        let elapsed = max(0, min(day.end, now).timeIntervalSince(day.start))
        lines += ["  合计：\(ActivityLog.duration(recorded))", "  未记录：\(ActivityLog.duration(max(0, elapsed-recorded)))", "", "当天时间线"]
        var cursor = day.start
        for record in daily {
            let start = max(record.start, day.start), end = min(record.end, day.end)
            if start > cursor { lines.append("\(fmt.string(from: cursor))–\(fmt.string(from: start))  未记录") }
            lines.append("\(fmt.string(from: start))–\(fmt.string(from: end))  [\(record.category)] \(record.task)\n  \(ActivityLog.duration(record.seconds(in: day))) · \(record.reason)")
            cursor = max(cursor, end)
        }
        let cutoff = min(now, day.end)
        if cutoff > cursor { lines.append("\(fmt.string(from: cursor))–\(fmt.string(from: cutoff))  未记录") }
        if daily.isEmpty { lines.append("暂无活动记录。开始计时或补记一段时间。") }
        lines += ["", "任务累计（全部日期，同名任务合并）"]
        let grouped = Dictionary(grouping: records, by: { $0.task })
        for task in grouped.keys.sorted() {
            let seconds = grouped[task]!.reduce(0) { $0 + $1.seconds }
            let state = activityLog.completed[task] == nil ? "进行中 / 未标记完成" : "已完成"
            lines.append("\(task)：\(ActivityLog.duration(seconds)) · \(state)")
        }
        lines += ["", "用已完成任务的累计耗时估算类似任务，不把一次番茄等同于一个任务。", "未记录不代表浪费；睡眠、暂停、退出不计时。分类由你手动选择。", "切换到新任务：先重置，再修改名称和分类。正在计时的记录以刷新时刻为准。"]
        statisticsText?.string = lines.joined(separator: "\n")
    }

    @objc func completeTask() {
        let task = activityTitle
        reset()
        activityLog.completed[task] = Date()
        saveActivity()
        showStatistics()
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
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let entry = Activity(task: task.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), category: category.titleOfSelectedItem!, start: start.dateValue, end: end.dateValue, reason: "手动补记")
        if activityLog.addManual(entry, now: Date()) { saveActivity(); refreshStatistics() }
        else {
            let warning = NSAlert()
            warning.messageText = "未保存"
            warning.informativeText = "请检查任务名、起止时间和是否与已有记录重叠。"
            warning.runModal()
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
