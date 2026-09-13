import AppKit

final class PlanItem: NSObject {
    let key: String
    var title: String
    var projectID: UUID?
    var goalID: UUID?
    var taskID: UUID?
    var day: String?
    var children: [PlanItem] = []
    init(_ key: String, _ title: String, project: UUID? = nil) { self.key = key; self.title = title; self.projectID = project }
}

final class PlanCheck: NSButton { var itemKey = "" }

final class ScheduleController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    unowned let app: AppDelegate
    let modes = NSSegmentedControl(labels: ["周日程", "月日程", "目标大纲 · 可折叠"], trackingMode: .selectOne, target: nil, action: nil)
    let date = NSDatePicker()
    let projects = NSPopUpButton()
    let hideDone = NSButton(checkboxWithTitle: "隐藏已完成", target: nil, action: nil)
    let summary = NSTextField(labelWithString: "")
    let detail = NSTextField(wrappingLabelWithString: "")
    let outline = NSOutlineView()
    let outlineScroll = NSScrollView()
    let calendar = ScheduleCanvas()
    let content = NSView()
    var roots: [PlanItem] = []
    private var tasksByDay: [String:[ResearchTask]] = [:]
    var selectedTaskID: UUID?
    var selectedGoalID: UUID?
    var selectedDay = PlanDates.key(Date())
    var expanded = Set(UserDefaults.standard.stringArray(forKey: "scheduleExpanded") ?? [])
    var restoring = false
    var state: ResearchState { app.research.state }
    var plan: ResearchSchedule { state.schedule ?? ResearchSchedule() }
    var projectID: UUID? { (projects.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:)) }
    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790), styleMask: [.titled,.closable,.miniaturizable,.resizable], backing: .buffered, defer: false)
        window.title = "日程与目标 · Research Planner"; window.minSize = NSSize(width: 1080, height: 700)
        window.appearance = NSAppearance(named: .aqua); window.isReleasedWhenClosed = false
        super.init(window: window)
        func button(_ title: String, _ selector: Selector) -> NSButton { let b = NSButton(title: title,target:self,action:selector); b.bezelStyle = .rounded; return b }
        let title = NSTextField(labelWithString: "RESEARCH PLANNER  /  课题 · 月目标 · 周目标 · 每日执行")
        title.font = .systemFont(ofSize: 20,weight:.semibold); title.textColor = .white
        modes.selectedSegment = 0; modes.target = self; modes.action = #selector(viewChanged)
        date.datePickerElements = [.yearMonthDay]; date.dateValue = Date(); date.target = self; date.action = #selector(dateChanged)
        projects.target = self; projects.action = #selector(projectChanged); projects.widthAnchor.constraint(lessThanOrEqualToConstant:220).isActive = true
        hideDone.target = self; hideDone.action = #selector(viewChanged)
        let navigation = glassStack([modes, button("‹",#selector(previous)),button("今天",#selector(today)),button("›",#selector(next)), date, projects, hideDone],vertical:false,spacing:8)
        let navCard = NSView(); navCard.wantsLayer = true
        navCard.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor; navCard.layer?.cornerRadius = 8
        navCard.addSubview(navigation); navigation.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([navigation.leadingAnchor.constraint(equalTo:navCard.leadingAnchor,constant:8),navigation.trailingAnchor.constraint(lessThanOrEqualTo:navCard.trailingAnchor,constant:-8),navigation.topAnchor.constraint(equalTo:navCard.topAnchor,constant:6),navigation.bottomAnchor.constraint(equalTo:navCard.bottomAnchor,constant:-6)])
        let actions = glassStack([button("＋ 月目标",#selector(addMonth)),button("＋ 周目标",#selector(addWeek)),button("＋ 每日 Todo",#selector(addTodo)),button("编辑选中",#selector(editSelected)),button("勾选 / 重开",#selector(toggleSelected)),button("去专注",#selector(focusSelected)),button("全部折叠",#selector(collapseAll)),button("全部展开",#selector(expandAll))],vertical:false,spacing:8)
        summary.lineBreakMode = .byTruncatingTail; summary.textColor = NSColor.white.withAlphaComponent(0.9); summary.font = AppFont.font(13)
        detail.textColor = .white; detail.font = AppFont.font(13); detail.maximumNumberOfLines = 3
        calendar.controller = self; calendar.translatesAutoresizingMaskIntoConstraints = false
        let col = NSTableColumn(identifier:.init("plan")); col.title = "课题 → 月份 / 月目标 → 周目标 → 日期 → Todo"; col.width = 1020
        outline.addTableColumn(col); outline.outlineTableColumn = col
        outline.dataSource = self; outline.delegate = self; outline.rowHeight = 34; outline.indentationPerLevel = 22
        outline.usesAlternatingRowBackgroundColors = true; outline.target = self; outline.doubleAction = #selector(editSelected)
        outlineScroll.documentView = outline; outlineScroll.hasVerticalScroller = true; outlineScroll.translatesAutoresizingMaskIntoConstraints = false
        for v in [calendar,outlineScroll] { content.addSubview(v); NSLayoutConstraint.activate([v.leadingAnchor.constraint(equalTo:content.leadingAnchor),v.trailingAnchor.constraint(equalTo:content.trailingAnchor),v.topAnchor.constraint(equalTo:content.topAnchor),v.bottomAnchor.constraint(equalTo:content.bottomAnchor)]) }
        let layout = glassStack([title,navCard,actions,summary,content,detail],spacing:12)
        let root = KleinSurface(); window.contentView = root; root.addSubview(layout); layout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([layout.topAnchor.constraint(equalTo:root.topAnchor,constant:22),layout.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:22),layout.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-22),layout.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-20),navCard.widthAnchor.constraint(equalTo:layout.widthAnchor),summary.widthAnchor.constraint(equalTo:layout.widthAnchor),content.widthAnchor.constraint(equalTo:layout.widthAnchor),content.heightAnchor.constraint(greaterThanOrEqualToConstant:430),detail.widthAnchor.constraint(equalTo:layout.widthAnchor),detail.heightAnchor.constraint(equalToConstant:64)])
        window.center(); reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func projectChanged() { selectedTaskID = nil; selectedGoalID = nil; reload() }
    @objc func viewChanged() { reload() }
    @objc func dateChanged() { selectedDay = PlanDates.key(date.dateValue); reload() }
    @objc func today() { date.dateValue = Date(); dateChanged() }
    @objc func previous() { navigate(-1) }
    @objc func next() { navigate(1) }
    func navigate(_ n: Int) { date.dateValue = PlanDates.calendar.date(byAdding:modes.selectedSegment == 0 ? .day : .month,value:modes.selectedSegment == 0 ? n*7 : n,to:date.dateValue)!; dateChanged() }
    func tasks(on day: String) -> [ResearchTask] { tasksByDay[day] ?? [] }
    func reload() {
        let id = projectID
        projects.removeAllItems(); projects.addItem(withTitle:"所有课题")
        for p in state.projects { projects.addItem(withTitle:p.title); projects.lastItem?.representedObject = p.id.uuidString; if p.id == id { projects.select(projects.lastItem) } }
        tasksByDay = [:]
        for t in state.tasks where t.archivedAt == nil && (projectID == nil || t.projectID == projectID) && (hideDone.state != .on || t.completedAt == nil) {
            if let day=PlanDates.taskDay(t) { tasksByDay[day,default:[]].append(t) }
        }
        for day in Array(tasksByDay.keys) { tasksByDay[day]!.sort { ($0.plannedMinutes ?? 1440,$0.title) < ($1.plannedMinutes ?? 1440,$1.title) } }
        let week = PlanDates.week(date.dateValue), month = PlanDates.month(date.dateValue)
        let relevant = plan.goals.filter { (projectID == nil || $0.projectID == projectID) && ($0.kind == "month" ? $0.period == month : $0.period == week) }
        summary.stringValue = "\(month.prefix(7))  ·  周一 \(week)  ·  本月 / 本周目标 \(relevant.filter{$0.done}.count)/\(relevant.count) 已完成  ·  \(relevant.map{$0.title}.joined(separator:" / "))"
        outlineScroll.isHidden = modes.selectedSegment != 2; calendar.isHidden = modes.selectedSegment == 2
        rebuildOutline(); calendar.needsDisplay = true; updateDetail()
    }
    func updateDetail() {
        if let t = state.tasks.first(where:{$0.id == selectedTaskID}) {
            let goal = plan.goals.first{$0.id == t.planningGoalID}
            detail.stringValue = "\(t.completedAt == nil ? "☐" : "☑") \(t.title)  ·  \(PlanDates.taskDay(t) ?? "未安排")  \(PlanDates.time(t))  ·  预计 \(t.plannedDuration.map(String.init) ?? "未设") 分钟\n周目标：\(goal?.title ?? "未关联")  ·  \(t.description)"
        } else if let g = plan.goals.first(where:{$0.id == selectedGoalID}) {
            let ids = plan.taskIDs(for:g,tasks:state.tasks), done = state.tasks.filter{ids.contains($0.id) && $0.completedAt != nil}.count
            detail.stringValue = "\(g.kind == "month" ? "月目标" : "周目标")：\(g.title)  ·  \(g.period)  ·  关联 Todo \(done)/\(ids.count) 完成\n\(g.detail)"
        } else { detail.stringValue = "选中日期：\(selectedDay)。双击日历空白新建 Todo；点击复选框完成，点击文字选中，双击编辑。\n切换「目标大纲」可折叠课题、月份、月目标、周目标和日期；折叠状态自动记住。计划时间与实际专注时间分开记录。" }
    }
    func select(day: String, task: UUID?) { selectedDay = day; selectedTaskID = task; selectedGoalID = nil; calendar.needsDisplay = true; updateDetail() }
    @discardableResult func change(_ edit: (inout ResearchState) throws -> Void) -> Bool {
        do { try app.research.change(edit); app.workspace?.reload(); app.refreshResearchPickers(); reload(); return true }
        catch { NSApp.presentError(error); return false }
    }
    @objc func toggleSelected() {
        if let id = selectedTaskID { toggleTask(id) }
        else if let id = selectedGoalID { change { state in guard var p = state.schedule, let i = p.goals.firstIndex(where:{$0.id == id}) else { return }; p.goals[i].done.toggle(); p.goals[i].updatedAt = Date(); state.schedule = p } }
    }
    func toggleTask(_ id: UUID) {
        guard let task = state.tasks.first(where:{$0.id == id}) else { return }
        do {
            if task.completedAt == nil { try app.research.completeTask(id,at:Date()) }
            else { try app.research.change { s in let i=s.tasks.firstIndex{$0.id == id}!; s.tasks[i].completedAt=nil; s.tasks[i].status="待办"; s.tasks[i].updatedAt=Date() } }
            app.countdown = app.research.current?.countdown ?? Countdown(duration:app.countdown.duration)
            app.refresh(); app.workspace?.reload(); app.refreshResearchPickers(); reload()
        } catch { NSApp.presentError(error) }
    }
    @objc func focusSelected() {
        guard let t = state.tasks.first(where:{$0.id == selectedTaskID}), t.completedAt == nil, t.archivedAt == nil else { return }
        guard app.research.current == nil else { app.showSettings(); return }
        app.selectedProjectID=t.projectID; app.selectedTaskID=t.id; app.showSettings()
    }
    @objc func addMonth() { editGoal(nil,kind:"month") }
    @objc func addWeek() { editGoal(nil,kind:"week") }
    @objc func addTodo() { editTodo(nil) }
    @objc func editSelected() {
        if let t = state.tasks.first(where:{$0.id == selectedTaskID}) { editTodo(t) }
        else if let g = plan.goals.first(where:{$0.id == selectedGoalID}) { editGoal(g,kind:g.kind) }
    }

    // Outline nodes are rebuilt from IDs; expansion state is stored by stable keys.
    func rebuildOutline() {
        restoring = true; defer { restoring = false }
        roots = []
        let allTasks = state.tasks.filter{$0.archivedAt == nil && (hideDone.state != .on || $0.completedAt == nil)}
        let topicIDs: [UUID?] = projectID.map{[$0]} ?? state.projects.map{Optional($0.id)} + [nil]
        func todoItem(_ t: ResearchTask) -> PlanItem { let i=PlanItem("t:"+t.id.uuidString,t.title,project:t.projectID); i.taskID=t.id; i.day=PlanDates.taskDay(t); return i }
        func dayItems(_ tasks: [ResearchTask], prefix: String) -> [PlanItem] {
            let grouped=Dictionary(grouping:tasks,by:{PlanDates.taskDay($0) ?? "未安排"})
            return grouped.keys.sorted().map { day in let i=PlanItem(prefix+day,"\(day) · \(grouped[day]!.filter{$0.completedAt != nil}.count)/\(grouped[day]!.count)"); i.day=day; i.children=grouped[day]!.sorted{($0.plannedMinutes ?? 1440) < ($1.plannedMinutes ?? 1440)}.map(todoItem); return i }
        }
        func goalItem(_ g: ResearchSchedule.Goal) -> PlanItem {
            let i=PlanItem("g:"+g.id.uuidString,"\(g.kind == "month" ? "月目标" : "周目标 \(g.period)") · \(g.title)",project:g.projectID); i.goalID=g.id
            if g.kind == "week" { i.children=dayItems(allTasks.filter{$0.planningGoalID == g.id},prefix:i.key+":day:") }
            else { i.children=plan.goals.filter{$0.parentID == g.id && (hideDone.state != .on || !$0.done)}.sorted{$0.period < $1.period}.map(goalItem) }
            return i
        }
        for pid in topicIDs {
            let gs=plan.goals.filter{$0.projectID == pid && (hideDone.state != .on || !$0.done)}, ts=allTasks.filter{$0.projectID == pid}
            let topic=PlanItem("p:"+(pid?.uuidString ?? "none"),state.projects.first{$0.id == pid}?.title ?? "未关联课题 / 临时任务",project:pid)
            var months=Set(gs.filter{$0.kind == "month" || $0.parentID == nil}.map{String($0.period.prefix(7))})
            months.formUnion(ts.filter{$0.planningGoalID == nil}.compactMap{PlanDates.taskDay($0).map{String($0.prefix(7))}})
            for month in months.sorted() {
                let m=PlanItem(topic.key+":m:"+month,"\(month) · 月计划",project:pid)
                m.children=gs.filter{$0.kind == "month" && $0.period.hasPrefix(month)}.map(goalItem)
                m.children += gs.filter{$0.kind == "week" && $0.parentID == nil && $0.period.hasPrefix(month)}.map(goalItem)
                let loose=ts.filter{$0.planningGoalID == nil && PlanDates.taskDay($0)?.hasPrefix(month) == true}
                let weeks=Dictionary(grouping:loose,by:{PlanDates.week(PlanDates.date(PlanDates.taskDay($0)!)!)})
                for w in weeks.keys.sorted() { let i=PlanItem(m.key+":w:"+w,"\(w) 起 · 待关联周目标",project:pid); i.children=dayItems(weeks[w]!,prefix:i.key+":day:"); m.children.append(i) }
                topic.children.append(m)
            }
            let inbox=ts.filter{PlanDates.taskDay($0) == nil}
            if !inbox.isEmpty { let i=PlanItem(topic.key+":inbox","Inbox · 未安排",project:pid); i.children=inbox.map(todoItem); topic.children.append(i) }
            if !topic.children.isEmpty || pid != nil { roots.append(topic) }
        }
        outline.reloadData()
        func restore(_ items:[PlanItem]) { for item in items where expanded.contains(item.key) { outline.expandItem(item); restore(item.children) } }
        restore(roots)
    }
    func outlineView(_ outlineView:NSOutlineView,numberOfChildrenOfItem item:Any?) -> Int { (item as? PlanItem)?.children.count ?? roots.count }
    func outlineView(_ outlineView:NSOutlineView,child index:Int,ofItem item:Any?) -> Any { ((item as? PlanItem)?.children ?? roots)[index] }
    func outlineView(_ outlineView:NSOutlineView,isItemExpandable item:Any) -> Bool { !(item as! PlanItem).children.isEmpty }
    func outlineView(_ outlineView:NSOutlineView,viewFor tableColumn:NSTableColumn?,item:Any) -> NSView? {
        let item=item as! PlanItem
        if item.taskID != nil || item.goalID != nil {
            let button=PlanCheck(checkboxWithTitle:item.title,target:self,action:#selector(checkRow(_:)))
            button.itemKey=item.key; button.font=AppFont.font(13)
            let done=item.taskID.flatMap { id in state.tasks.first{$0.id == id}?.completedAt != nil } ?? item.goalID.flatMap { id in plan.goals.first{$0.id == id}?.done } ?? false
            button.state=done ? .on : .off; button.lineBreakMode = .byTruncatingTail; return button
        }
        let label=NSTextField(labelWithString:item.title); label.font=AppFont.font(14,weight:.semibold); return label
    }
    func find(_ key:String,_ items:[PlanItem]? = nil) -> PlanItem? { for i in items ?? roots { if i.key == key { return i }; if let child=find(key,i.children) { return child } }; return nil }
    @objc func checkRow(_ sender:PlanCheck) { guard let i=find(sender.itemKey) else { return }; selectedTaskID=i.taskID; selectedGoalID=i.goalID; toggleSelected() }
    func outlineViewSelectionDidChange(_ notification:Notification) {
        guard let i=outline.item(atRow:outline.selectedRow) as? PlanItem else { return }
        selectedTaskID=i.taskID; selectedGoalID=i.goalID
        if let g=plan.goals.first(where:{$0.id == i.goalID}) { selectedDay=g.period }
        if let day=i.day, PlanDates.date(day) != nil { selectedDay=day }; updateDetail()
    }
    func outlineViewItemDidExpand(_ notification:Notification) { expansion(notification,open:true) }
    func outlineViewItemDidCollapse(_ notification:Notification) { expansion(notification,open:false) }
    func expansion(_ n:Notification,open:Bool) { guard !restoring,let i=n.userInfo?["NSObject"] as? PlanItem else { return }; if open { expanded.insert(i.key) } else { expanded.remove(i.key) }; UserDefaults.standard.set(Array(expanded),forKey:"scheduleExpanded") }
    @objc func collapseAll() { if modes.selectedSegment != 2 { modes.selectedSegment=2; reload() }; expanded.removeAll(); UserDefaults.standard.set([],forKey:"scheduleExpanded"); outline.collapseItem(nil,collapseChildren:true) }
    @objc func expandAll() { modes.selectedSegment=2; reload(); outline.expandItem(nil,expandChildren:true) }

    func editor(_ heading:String,_ items:[(String,NSView)]) -> Bool {
        let alert=NSAlert(); alert.messageText=heading; alert.addButton(withTitle:"保存"); alert.addButton(withTitle:"取消")
        let stack=glassStack(items.flatMap{[NSTextField(labelWithString:$0.0),$0.1]},spacing:7)
        stack.frame=NSRect(x:0,y:0,width:520,height:Double(items.count)*55+80)
        alert.accessoryView=stack
        return alert.runModal() == .alertFirstButtonReturn
    }
    func field(_ value:String) -> NSTextField { let f=NSTextField(string:value); f.widthAnchor.constraint(equalToConstant:520).isActive=true; return f }
    func note(_ value:String) -> (NSScrollView,NSTextView) {
        let t=NSTextView(frame:NSRect(x:0,y:0,width:520,height:100)); t.string=value; t.font=AppFont.font(13); t.isRichText=false; t.isVerticallyResizable=true; t.autoresizingMask=[.width]; t.textContainer?.widthTracksTextView=true
        let s=NSScrollView(); s.hasVerticalScroller=true; s.documentView=t; s.widthAnchor.constraint(equalToConstant:520).isActive=true; s.heightAnchor.constraint(equalToConstant:100).isActive=true; return (s,t)
    }
    func topicPicker(_ selected:UUID?, optional:Bool) -> NSPopUpButton {
        let p=NSPopUpButton(); if optional { p.addItem(withTitle:"未关联课题") }
        for t in state.projects where t.archivedAt == nil || t.id == selected { p.addItem(withTitle:t.title); p.lastItem?.representedObject=t.id.uuidString; if t.id == selected { p.select(p.lastItem) } }; return p
    }
    func editGoal(_ existing:ResearchSchedule.Goal?,kind:String) {
        guard !state.projects.isEmpty else { let a=NSAlert(); a.messageText="请先在科研工作台建立一个课题 / 项目"; a.runModal(); app.showWorkspace(); return }
        let topic=topicPicker(existing?.projectID ?? projectID,optional:false), title=field(existing?.title ?? "")
        let period=NSDatePicker(); period.datePickerElements=[.yearMonthDay]; period.dateValue=existing.flatMap{PlanDates.date($0.period)} ?? PlanDates.date(selectedDay) ?? date.dateValue
        let parent=NSPopUpButton(); parent.addItem(withTitle:"未关联月目标")
        for g in plan.goals where g.kind == "month" { parent.addItem(withTitle:"\(g.period.prefix(7)) · \(g.title)"); parent.lastItem?.representedObject=g.id.uuidString; if g.id == existing?.parentID || (existing == nil && g.id == selectedGoalID) { parent.select(parent.lastItem) } }
        parent.isEnabled=kind == "week"
        let repetitions=field("1"); repetitions.isEnabled=existing == nil && kind == "month"
        let (scroll,body)=note(existing?.detail ?? "")
        guard editor(kind == "month" ? "安排月目标" : "安排周目标",[("课题",topic),("目标标题",title),(kind == "month" ? "月份（选择该月任一天）" : "周（周一开始，选择该周任一天）",period),("关联月目标（周目标可选）",parent),("连续月数（新月目标可填 1–24，各月可独立修改）",repetitions),("成果标准 / 执行要点",scroll)]) else { return }
        guard let id=(topic.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:)),let count=Int(repetitions.stringValue), (1...24).contains(count) else { NSApp.presentError(ResearchError.message("请选择课题；连续月数需为 1–24")); return }
        let parentID=kind == "week" ? (parent.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:)) : nil
        let day=kind == "month" ? PlanDates.month(period.dateValue) : PlanDates.week(period.dateValue)
        var goal=existing ?? ResearchSchedule.Goal(projectID:id,kind:kind,period:day,title:"")
        goal.projectID=id; goal.parentID=parentID; goal.period=day; goal.title=title.stringValue.trimmingCharacters(in:.whitespacesAndNewlines); goal.detail=body.string; goal.updatedAt=Date()
        if change({ s in
            var plan=s.schedule ?? ResearchSchedule()
            if let i=plan.goals.firstIndex(where:{$0.id == goal.id}) { plan.goals[i]=goal }
            else {
                for offset in 0..<(kind == "month" ? count : 1) { var copy=goal; if offset > 0 { copy.id=UUID() }; copy.period=kind == "month" ? PlanDates.month(PlanDates.calendar.date(byAdding:.month,value:offset,to:PlanDates.date(day)!)!) : day; plan.goals.append(copy) }
            }
            s.schedule=plan
        }) {
            selectedGoalID=goal.id; selectedTaskID=nil; modes.selectedSegment=2; reload()
            func reveal(_ item:PlanItem) -> Bool {
                if item.goalID == goal.id { return true }
                for child in item.children { if reveal(child) { outline.expandItem(item); return true } }
                return false
            }
            for root in roots { _ = reveal(root) }
            if let item=find("g:"+goal.id.uuidString) { let row=outline.row(forItem:item); if row >= 0 { outline.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false); outline.scrollRowToVisible(row) } }
        }
    }
    func editTodo(_ existing:ResearchTask?) {
        let title=field(existing?.title ?? ""), topic=topicPicker(existing?.projectID ?? plan.goals.first{$0.id == selectedGoalID}?.projectID ?? projectID,optional:true)
        topic.isEnabled = existing.map{t in !state.sessions.contains{$0.taskID == t.id}} ?? true
        let day=NSDatePicker(); day.datePickerElements=[.yearMonthDay]; day.dateValue=existing.flatMap{PlanDates.taskDay($0)}.flatMap(PlanDates.date) ?? PlanDates.date(selectedDay) ?? date.dateValue
        let goal=NSPopUpButton(); goal.addItem(withTitle:"未关联周目标")
        for g in plan.goals where g.kind == "week" { goal.addItem(withTitle:"\(g.period) · \(g.title)"); goal.lastItem?.representedObject=g.id.uuidString; if g.id == existing?.planningGoalID || (existing == nil && g.id == selectedGoalID) { goal.select(goal.lastItem) } }
        let time=field(existing?.plannedMinutes.map{String(format:"%02d:%02d",$0/60,$0%60)} ?? "")
        let duration=field(existing?.plannedDuration.map(String.init) ?? "")
        let (scroll,body)=note(existing?.description ?? "")
        guard editor("每日 Todo · 详细执行安排",[("Todo 标题",title),("课题（有历史记录后不可换绑）",topic),("执行日期",day),("关联周目标",goal),("计划开始 HH:mm（留空表示时间灵活）",time),("预计分钟数（可留空）",duration),("具体步骤 / 预期产出 / 注意事项",scroll)]) else { return }
        var task=existing ?? ResearchTask(title:"")
        task.title=title.stringValue.trimmingCharacters(in:.whitespacesAndNewlines); task.description=body.string
        task.projectID=(topic.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:))
        task.planningGoalID=(goal.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:))
        task.plannedDay=PlanDates.key(day.dateValue); task.scheduledDate=PlanDates.calendar.startOfDay(for:day.dateValue); task.schedule="指定日期"; task.timeZoneID=TimeZone.current.identifier
        let value=time.stringValue.trimmingCharacters(in:.whitespaces)
        if value.isEmpty { task.plannedMinutes=nil }
        else {
            let parts=value.split(separator:":")
            guard parts.count == 2,let h=Int(parts[0]),let m=Int(parts[1]),(0..<24).contains(h),(0..<60).contains(m) else { NSApp.presentError(ResearchError.message("开始时间格式为 HH:mm，例如 14:30")); return }
            task.plannedMinutes=h*60+m
        }
        if duration.stringValue.isEmpty { task.plannedDuration=nil }
        else { guard let d=Int(duration.stringValue),(1...1440).contains(d) else { NSApp.presentError(ResearchError.message("预计用时为 1–1440 分钟")); return }; task.plannedDuration=d }
        task.updatedAt=Date()
        if change({ s in if let i=s.tasks.firstIndex(where:{$0.id == task.id}) { s.tasks[i]=task } else { s.tasks.append(task) } }) { selectedTaskID=task.id; selectedGoalID=nil; selectedDay=task.plannedDay!; updateDetail() }
    }
}

final class KleinSurface: NSView {
    override func draw(_ dirtyRect:NSRect) {
        NSGradient(colors:[NSColor(srgbRed:0.0,green:0.075,blue:0.56,alpha:1),NSColor(srgbRed:0.0,green:0.184,blue:0.655,alpha:1),NSColor(srgbRed:0.17,green:0.32,blue:0.88,alpha:1)])!.draw(in:bounds,angle:25)
    }
}

final class ScheduleCanvas: NSView {
    weak var controller:ScheduleController?
    var cells: [(NSRect,String)] = []
    var hits: [(NSRect,NSRect,UUID,String)] = []
    var overflow: [(NSRect,String)] = []
    override var isFlipped:Bool { true }
    func label(_ text:String,_ r:NSRect,_ size:CGFloat,_ color:NSColor,_ bold:Bool=false) {
        let p=NSMutableParagraphStyle(); p.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in:r,withAttributes:[.font:AppFont.font(size,weight:bold ? .semibold : .regular),.foregroundColor:color,.paragraphStyle:p])
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let c=controller else { return }; cells=[]; hits=[]; overflow=[]
        let month=c.modes.selectedSegment == 1
        let begin=PlanDates.date(month ? PlanDates.week(PlanDates.date(PlanDates.month(c.date.dateValue))!) : PlanDates.week(c.date.dateValue))!
        let monthStart=PlanDates.date(PlanDates.month(c.date.dateValue))!
        let end=PlanDates.calendar.dateInterval(of:.month,for:monthStart)!.end
        let needed=PlanDates.calendar.dateComponents([.day],from:begin,to:end).day!
        let rows=month ? Int(ceil(Double(needed)/7)) : 1
        let days=PlanDates.days(start:begin,count:rows*7), w=bounds.width/7, h=(bounds.height-26)/CGFloat(rows)
        let ink=NSColor(srgbRed:0.0,green:0.184,blue:0.655,alpha:1)
        for (i,name) in ["周一","周二","周三","周四","周五","周六","周日"].enumerated() { label(name,NSRect(x:CGFloat(i)*w+10,y:0,width:w-12,height:22),13,.white,true) }
        for (i,date) in days.enumerated() {
            let key=PlanDates.key(date), r=NSRect(x:CGFloat(i%7)*w+3,y:26+CGFloat(i/7)*h+3,width:w-6,height:h-6)
            let outside=month && PlanDates.month(date) != PlanDates.month(c.date.dateValue)
            NSColor.white.withAlphaComponent(outside ? 0.72 : 0.96).setFill(); let path=NSBezierPath(roundedRect:r,xRadius:10,yRadius:10); path.fill()
            if key == c.selectedDay { NSColor(srgbRed:0.45,green:0.79,blue:1,alpha:1).setStroke(); path.lineWidth=3; path.stroke() }
            let dateTitle=String(key.suffix(5))+(key == PlanDates.key(Date()) ? " 今天" : "")
            label(dateTitle,NSRect(x:r.minX+9,y:r.minY+8,width:r.width-16,height:20),month ? 12 : 14,ink,true)
            cells.append((r,key)); let tasks=c.tasks(on:key)
            let rowHeight:CGFloat=month ? 18 : 55
            let capacity=max(0,Int((r.height-(month ? 41 : 53))/rowHeight))
            for (j,t) in tasks.prefix(capacity).enumerated() {
                let line=NSRect(x:r.minX+5,y:r.minY+(month ? 24 : 34)+CGFloat(j)*rowHeight,width:r.width-10,height:rowHeight-3)
                if t.id == c.selectedTaskID { ink.withAlphaComponent(0.12).setFill(); NSBezierPath(roundedRect:line,xRadius:5,yRadius:5).fill() }
                let box=NSRect(x:line.minX+3,y:line.minY+3,width:month ? 11 : 13,height:month ? 11 : 13)
                ink.setStroke(); let check=NSBezierPath(roundedRect:box,xRadius:3,yRadius:3); check.lineWidth=1.2; check.stroke()
                if t.completedAt != nil { ink.setFill(); check.fill(); label("✓",box.insetBy(dx:1,dy:-1),11,.white,true) }
                label(t.title,NSRect(x:box.maxX+5,y:line.minY+2,width:line.maxX-box.maxX-7,height:16),month ? 11 : 12,t.completedAt == nil ? .labelColor : .secondaryLabelColor,true)
                if !month { label(PlanDates.time(t)+" · "+(t.plannedDuration.map{"\($0) 分钟"} ?? "未估时"),NSRect(x:line.minX+4,y:line.minY+25,width:line.width-6,height:18),11,ink) }
                hits.append((line,box,t.id,key))
            }
            if tasks.count > capacity {
                let more=NSRect(x:r.minX+8,y:r.maxY-17,width:r.width-16,height:16); label("＋\(tasks.count-capacity) 条 · 查看当天",more,11,ink,true); overflow.append((more,key))
            }
        }
    }
    override func mouseDown(with event:NSEvent) {
        guard let c=controller else { return }; let p=convert(event.locationInWindow,from:nil)
        if let hit=hits.first(where:{$0.0.contains(p)}) {
            c.select(day:hit.3,task:hit.2)
            if hit.1.insetBy(dx:-3,dy:-3).contains(p) { c.toggleTask(hit.2) }
            else if event.clickCount == 2 { c.editSelected() }
        } else if let more=overflow.first(where:{$0.0.contains(p)}) {
            c.selectedDay=more.1; c.modes.selectedSegment=2; c.expandAll()
            for row in 0..<c.outline.numberOfRows { if let item=c.outline.item(atRow:row) as? PlanItem,item.day == more.1 { c.outline.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false); c.outline.scrollRowToVisible(row); break } }
        } else if let day=cells.first(where:{$0.0.contains(p)}) { c.select(day:day.1,task:nil); if event.clickCount == 2 { c.addTodo() } }
    }
}
