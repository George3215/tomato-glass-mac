import AppKit

final class StatisticsBoard: GroupedSurface, NSTableViewDataSource, NSTableViewDelegate {
    let date = NSDatePicker()
    let mode = NSSegmentedControl(labels: ["当日记录", "任务累计"], trackingMode: .selectOne, target: nil, action: nil)
    let table = NSTableView()
    let summary = NSStackView()
    let empty = NSTextField(labelWithString: "暂无记录，开始计时或补记一段活动。")
    var rows: [[String]] = []
    var onRefresh: (() -> Void)?
    private let columnIDs = ["time", "task", "category", "duration", "source"]

    init(delegate: AppDelegate) {
        super.init(frame: .zero)
        date.datePickerElements = [.yearMonthDay]
        date.dateValue = Date()
        date.target = self
        date.action = #selector(changed)
        mode.selectedSegment = 0
        mode.target = self
        mode.action = #selector(changed)
        let title = NSTextField(labelWithString: "我的时间记录")
        title.font = AppFont.font(23, weight: .semibold)
        let hint = NSTextField(labelWithString: "只展示实际记录 · 未记录时段可通过补记接口补充")
        hint.textColor = .secondaryLabelColor
        let toolbar = glassStack([date, mode,
            glassButton("刷新", target: delegate, action: #selector(AppDelegate.refreshStatistics)),
            glassButton("手动补记", target: delegate, action: #selector(AppDelegate.addManualActivity)),
            glassButton("导入 JSON", target: delegate, action: #selector(AppDelegate.importActivity)),
            glassButton("补记接口", target: delegate, action: #selector(AppDelegate.exportGapContext)),
            glassButton("导出 CSV", target: delegate, action: #selector(AppDelegate.exportActivity))], vertical: false, spacing: 8)
        summary.orientation = .horizontal
        summary.distribution = .fillEqually
        summary.spacing = 12
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 12
        scroll.layer?.masksToBounds = true
        table.usesAlternatingRowBackgroundColors = true
        table.style = .inset
        table.rowHeight = 42
        table.intercellSpacing = NSSize(width: 14, height: 4)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (index, width) in [170.0, 260, 85, 145, 160].enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnIDs[index]))
            column.width = width
            column.minWidth = 65
            table.addTableColumn(column)
        }
        table.delegate = self
        table.dataSource = self
        scroll.documentView = table
        empty.textColor = .secondaryLabelColor
        let layout = glassStack([title, hint, toolbar, summary, scroll, empty], spacing: 16)
        layout.translatesAutoresizingMaskIntoConstraints = false
        addSubview(layout)
        NSLayoutConstraint.activate([
            layout.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            layout.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            layout.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            layout.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            scroll.widthAnchor.constraint(equalTo: layout.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            summary.widthAnchor.constraint(equalTo: layout.widthAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        SoftGlass.drawBackground(in: bounds)
    }
    @objc private func changed() { onRefresh?() }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier, let index = columnIDs.firstIndex(of: id.rawValue) else { return nil }
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = id
        if cell.textField == nil {
            let label = NSTextField(labelWithString: "")
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        }
        cell.textField?.stringValue = rows[row][index]
        cell.textField?.font = AppFont.font(13)
        cell.textField?.textColor = index == 2 ? .systemPurple : .labelColor
        cell.toolTip = rows[row][index]
        return cell
    }

    func reload(log: ActivityLog, now: Date, tasks: [ResearchTask] = []) {
        guard let day = Calendar.current.dateInterval(of: .day, for: date.dateValue) else { return }
        let records = log.records(at: now)
        let daily = records.filter { $0.seconds(in: day) > 0 }.sorted { $0.start < $1.start }
        summary.arrangedSubviews.forEach { summary.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (category, color) in [("学习", NSColor.systemPurple), ("工作", .systemBlue), ("休息", .systemGreen), ("其他", .systemOrange)] {
            let name = NSTextField(labelWithString: category)
            name.textColor = color
            let total = NSTextField(labelWithString: ActivityLog.duration(daily.filter { $0.category == category }.reduce(0) { $0 + $1.seconds(in: day) }))
            total.font = AppFont.font(17, weight: .medium)
            let stack = glassStack([name, total], spacing: 8)
            let card = GlassCard(content: stack, padding: 14)
            card.layer?.backgroundColor = ExhibitPalette.node(category == "学习" ? "问题" : category == "工作" ? "实验" : "观点").cgColor
            summary.addArrangedSubview(card)
        }
        let titles: [String]
        if mode.selectedSegment == 0 {
            titles = ["起止时间", "任务 / 项目", "分类", "记录用时", "来源 / 状态"]
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "HH:mm:ss"
            rows = daily.map { ["\(format.string(from: max(day.start, $0.start)))–\(format.string(from: min(day.end, $0.end)))", $0.task, $0.category, ActivityLog.duration($0.seconds(in: day)), $0.reason] }
        } else {
            titles = ["完成状态", "任务 / 项目（全部日期）", "记录段数", "累计用时", "分类"]
            let grouped = Dictionary(grouping: records, by: { $0.taskID?.uuidString ?? ("unlinked:" + $0.task) })
            rows = grouped.keys.sorted().map { task in
                let items = grouped[task]!
                let linkedTask = items.first?.taskID.flatMap { id in tasks.first { $0.id == id } }
                return [linkedTask?.status ?? "未关联任务", linkedTask?.title ?? items.first!.task, String(items.count), ActivityLog.duration(items.reduce(0) { $0 + $1.seconds }), Set(items.map { $0.category }).sorted().joined(separator: " / ")]
            }
        }
        for (column, title) in zip(table.tableColumns, titles) { column.title = title; column.headerCell.font = AppFont.font(12) }
        empty.stringValue = rows.isEmpty ? "暂无记录，开始计时或补记一段活动。" : "\(rows.count) 条记录 · 汇总卡片始终显示所选日期 · 未记录时段不计入统计"
        AppFont.apply(to: summary)
        table.reloadData()
    }
}
