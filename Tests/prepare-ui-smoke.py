"""Generate a separate native smoke-test app without shipping test hooks."""
from pathlib import Path
source = Path("Sources/AppDelegate.swift").read_text().replace("import AppKit", "import AppKit\nimport CoreText")
source = source.replace("if let identifier = Bundle.main.bundleIdentifier,", "if false, let identifier = Bundle.main.bundleIdentifier,")
tests = r''' 
    func runUISmoke() {
        precondition(makeReminderSound() == nil, "Sound defaults to off")
        soundPicker!.selectItem(at: 1)
        changeSound(soundPicker!)
        precondition(selectedSound == "Ping" && makeReminderSound() != nil)
        soundPicker!.selectItem(at: 0)
        changeSound(soundPicker!)
        precondition(selectedSound.isEmpty && makeReminderSound() == nil)
        let demoProject = ResearchProject(title: "示例科研项目", goal: "验证研究流程", nextAction: "完成第一次专注")
        let demoTask = ResearchTask(title: "示例任务", projectID: demoProject.id)
        try! research.change { $0.projects.append(demoProject); $0.tasks.append(demoTask) }
        selectedProjectID = demoProject.id; selectedTaskID = demoTask.id
        refreshResearchPickers()
        showWorkspace()
        precondition(workspace!.window!.isVisible)
        workspace!.navigation.selectedSegment = 2; workspace!.reload()
        precondition(workspace!.rowIDs.contains(demoProject.id))
        workspace!.navigation.selectedSegment = 1; workspace!.reload()
        precondition(workspace!.rowIDs.contains(demoTask.id))
        func acceptNewForm(_ title: String, capture: Bool = false, configure: ((NSView) -> Void)? = nil) {
            let timer = Timer(timeInterval: 0.25, repeats: false) { _ in
                guard let root = NSApp.modalWindow?.contentView else { fatalError("Missing edit form") }
                func fields(_ view: NSView) -> [NSTextField] {
                    (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
                }
                let editable = fields(root).filter { $0.isEditable }
                precondition(!editable.isEmpty, "Form fields missing")
                editable[0].stringValue = title
                configure?(root)
                if capture, let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
                    root.layoutSubtreeIfNeeded(); root.cacheDisplay(in: root.bounds, to: bitmap)
                    try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/research-project-editor.png"))
                }
                NSApp.stopModal(withCode: .alertFirstButtonReturn)
            }
            RunLoop.main.add(timer, forMode: .modalPanel)
        }
        workspace!.navigation.selectedSegment = 2; workspace!.reload()
        acceptNewForm("表单测试项目", capture: true); workspace!.newItem()
        precondition(research.state.projects.contains { $0.title == "表单测试项目" })
        workspace!.navigation.selectedSegment = 1; workspace!.reload()
        acceptNewForm("表单测试任务"); workspace!.newItem()
        precondition(research.state.tasks.contains { $0.title == "表单测试任务" })
        let newTaskID = research.state.tasks.first { $0.title == "表单测试任务" }!.id
        workspace!.reload()
        workspace!.table.selectRowIndexes(IndexSet(integer: workspace!.rowIDs.firstIndex(of: newTaskID)!), byExtendingSelection: false)
        workspace!.archiveItem()
        precondition(research.state.tasks.first { $0.id == newTaskID }!.archivedAt != nil)
        workspace!.filter.selectItem(at: 5); workspace!.reload()
        precondition(workspace!.rowIDs.contains(newTaskID))
        workspace!.table.selectRowIndexes(IndexSet(integer: workspace!.rowIDs.firstIndex(of: newTaskID)!), byExtendingSelection: false)
        workspace!.archiveItem()
        precondition(research.state.tasks.first { $0.id == newTaskID }!.archivedAt == nil)
        workspace!.window?.close()
        let original = countdown
        let savedMotion = UserDefaults.standard.object(forKey: "wallpaperMotion")
        let savedTheme = UserDefaults.standard.object(forKey: "backgroundTheme")
        let savedTransparency = UserDefaults.standard.object(forKey: "windowTransparency")
        defer {
            countdown = original
            if let savedMotion { UserDefaults.standard.set(savedMotion, forKey: "wallpaperMotion") }
            else { UserDefaults.standard.removeObject(forKey: "wallpaperMotion") }
            if let savedTheme { UserDefaults.standard.set(savedTheme, forKey: "backgroundTheme") }
            else { UserDefaults.standard.removeObject(forKey: "backgroundTheme") }
            if let savedTransparency {
                UserDefaults.standard.set(savedTransparency, forKey: "windowTransparency")
            } else {
                UserDefaults.standard.removeObject(forKey: "windowTransparency")
            }
        }
        guard let window = settings, let content = window.contentView else { fatalError("Missing window") }
        precondition(window.isVisible)
        minutesField?.stringValue = "1"
        startCustom()
        precondition(window.isVisible && countdown.isRunning, "Start must keep window open")
        let firstSession = research.current!.id
        togglePause()
        precondition(countdown.isPaused && window.isVisible && timer == nil)
        togglePause()
        precondition(countdown.isRunning && timer != nil && research.current!.id == firstSession)
        func descendants(_ view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let views = descendants(content)
        let slider = views.compactMap { $0 as? NSSlider }.first!
        for value in [0.0, 40.0, 80.0] {
            slider.doubleValue = value
            changeTransparency(slider)
            precondition(abs(window.alphaValue - (1 - value / 100)) < 0.001)
            precondition(UserDefaults.standard.double(forKey: "windowTransparency") == value)
        }
        let reminder = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        reminderWindow = reminder
        applyTransparency()
        precondition(abs(reminder.alphaValue - window.alphaValue) < 0.001)
        reminderWindow = nil
        window.close()
        precondition(background?.water == nil && background?.animationTimer == nil, "Close releases renderer")
        precondition(!applicationShouldTerminateAfterLastWindowClosed(NSApp))
        _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        precondition(window.isVisible && abs(window.alphaValue - 0.2) < 0.001)
        content.layoutSubtreeIfNeeded()
        for view in views where view is NSControl {
            precondition(content.bounds.contains(view.convert(view.bounds, to: content)), "Control outside window: \(view)")
        }
        themePicker!.selectItem(at: 0)
        changeTheme(themePicker!)
        precondition(background?.picture != nil, "Bundled wallpaper must load")
        let motionToggle = NSButton(checkboxWithTitle: "Motion", target: nil, action: nil)
        motionToggle.state = .on
        toggleMotion(motionToggle)
        precondition(background!.dynamicEnabled && background!.water != nil)
        let water = background!.water!
        water.advance()
        let frameA = water.frame!.tiffRepresentation!
        water.poke(x: 70, y: 60)
        for _ in 0..<20 { water.advance() }
        let frameB = water.frame!.tiffRepresentation!
        precondition(frameA != frameB, "Ripple pixels must change")
        motionToggle.state = .off
        toggleMotion(motionToggle)
        precondition(background!.water == nil && background!.animationTimer == nil)
        motionToggle.state = .on
        toggleMotion(motionToggle)
        toggleShowcase()
        precondition(controlsLayout!.isHidden && countdown.isRunning)
        toggleShowcase()
        precondition(!controlsLayout!.isHidden)
        themePicker!.selectItem(at: 1)
        changeTheme(themePicker!)
        precondition(background?.picture == nil)
        themePicker!.selectItem(at: 0)
        changeTheme(themePicker!)
        let dismissTimer = Timer(timeInterval: 0.2, repeats: false) { _ in
            precondition(NSApp.modalWindow != nil, "Reminder must be visible")
            NSApp.abortModal()
        }
        RunLoop.main.add(dismissTimer, forMode: .modalPanel)
        showReminder()
        precondition(!isShowingReminder)
        slider.doubleValue = 0
        changeTransparency(slider)
        background!.water?.advance()
        window.alphaValue = 1
        minutesField?.stringValue = "25"
        startCustom()
        if let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.cacheDisplay(in: content.bounds, to: bitmap)
            let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/screenshot.png")
            try! bitmap.representation(using: .png, properties: [:])!.write(to: output)
        }
        showStatistics()
        precondition(statisticsWindow!.isVisible && statisticsBoard!.table.numberOfRows > 0)
        precondition(statisticsBoard!.rows.allSatisfy { !$0.contains("未记录") })
        statisticsBoard!.mode.selectedSegment = 1
        refreshStatistics()
        precondition(statisticsBoard!.table.tableColumns[1].title.contains("全部日期"))
        statisticsBoard!.mode.selectedSegment = 0
        refreshStatistics()
        precondition(AppFont.font(13).fontName == "ComicNeue-Regular", "Bundled Comic Neue must load")
        precondition(AppFont.font(18, weight: .bold).fontName == "ComicNeue-Bold", "Bundled bold must load")
        precondition(NSFont(name: "LXGWWenKaiLite-Regular", size: 13) != nil, "Bundled Chinese font must load")
        let chineseFont = CTFontCreateForString(AppFont.font(13) as CTFont, "研究日程" as CFString, CFRange(location: 0, length: 4))
        precondition((CTFontCopyPostScriptName(chineseFont) as String).contains("LXGWWenKai"), "Chinese must use WenKai cascade")
        print("FONT: " + AppFont.font(13).fontName)
        if let board = statisticsBoard, let bitmap = board.bitmapImageRepForCachingDisplay(in: board.bounds) {
            board.layoutSubtreeIfNeeded()
            board.cacheDisplay(in: board.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/records.png"))
        }
        statisticsWindow?.close()
        showResearchBoard()
        let board = researchBoard!
        let q = ResearchGraph.Node(title: "示例：关键研究问题", kind: "问题", body: "哪些信息影响实验结果？", important: true, x: 40, y: 60)
        let v = ResearchGraph.Node(title: "示例：重要观点", kind: "观点", body: "将观点与证据分开记录。", important: true, x: 400, y: 40)
        let e = ResearchGraph.Node(title: "示例：实验验证", kind: "实验", body: "记录条件、结果和下一步。", status: "进行中", x: 400, y: 290)
        precondition(board.commit { $0.nodes = [q,v,e]; $0.edges = [.init(from: q.id, to: v.id, relation: "启发"), .init(from: v.id, to: e.id, relation: "验证")] })
        board.fit()
        let surface = board.canvas
        // Drive the actual AppKit drag handlers at the current zoom.
        let startPoint = surface.screen(NSPoint(x: q.x + 40, y: q.y + 40))
        func mouse(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: surface.convert(point, to: nil), modifierFlags: [], timestamp: 0, windowNumber: board.window!.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        surface.mouseDown(with: mouse(.leftMouseDown,startPoint))
        let destination = NSPoint(x:startPoint.x+30,y:startPoint.y+20)
        surface.mouseDragged(with: mouse(.leftMouseDragged,destination)); surface.mouseUp(with: mouse(.leftMouseUp,destination))
        precondition(board.graph.nodes.first { $0.id == q.id }!.x > q.x)
        board.undoGraph(); precondition(board.graph.nodes.first { $0.id == q.id }!.x == q.x)
        surface.selectedNode = q.id; board.deleteSelection(); precondition(board.graph.edges.count == 1)
        board.undoGraph(); precondition(board.graph.nodes.count == 3 && board.graph.edges.count == 2)
        board.importantOnly.state = .on; board.filtersChanged(); precondition(surface.visibleIDs.count == 2)
        board.importantOnly.state = .off; board.filtersChanged()
        board.connect.state = .on; board.relation.selectItem(withTitle: "依赖")
        let qp = surface.screen(NSPoint(x:q.x+40,y:q.y+40)), ep = surface.screen(NSPoint(x:e.x+40,y:e.y+40))
        surface.mouseDown(with: mouse(.leftMouseDown,qp)); surface.mouseUp(with: mouse(.leftMouseUp,qp))
        surface.mouseDown(with: mouse(.leftMouseDown,ep)); surface.mouseUp(with: mouse(.leftMouseUp,ep))
        precondition(board.graph.edges.count == 3)
        board.connect.state = .off; board.undoGraph()
        let anchor = NSPoint(x:surface.bounds.midX,y:surface.bounds.midY), beforeZoom = surface.world(NSPoint(x:surface.bounds.midX,y:surface.bounds.midY))
        surface.zoom(by: 1.2, anchor: anchor)
        precondition(abs(surface.world(anchor).x-beforeZoom.x) < 0.001)
        board.fit()
        acceptNewForm("表单测试节点"); board.addNode()
        precondition(board.graph.nodes.contains { $0.title == "表单测试节点" })
        board.undoGraph(); board.fit()
        if let root = board.window?.contentView, let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
            root.layoutSubtreeIfNeeded(); root.cacheDisplay(in: root.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/research-board.png"))
        }
        board.window?.close()
        showSchedule()
        let planner = scheduleWindow!
        planner.date.dateValue = PlanDates.date("2026-09-16")!
        planner.selectedDay="2026-09-16"
        let monthly = ResearchSchedule.Goal(projectID: demoProject.id, kind: "month", period: "2026-09-01", title: "示例：完成课题基线")
        let weekly = ResearchSchedule.Goal(projectID: demoProject.id, parentID: monthly.id, kind: "week", period: "2026-09-14", title: "示例：验证实验方案")
        try! research.change { s in
            s.schedule = ResearchSchedule(goals:[monthly,weekly])
            for i in 0..<5 {
                var t = ResearchTask(title:["阅读与整理问题","准备实验数据","运行对照实验","分析结果","整理本周结论"][i], projectID:demoProject.id)
                t.planningGoalID=weekly.id; t.plannedDay="2026-09-\(14+i)"; t.plannedMinutes=14*60; t.plannedDuration=60; t.description="示例执行步骤与验收标准"
                t.scheduledDate=PlanDates.date(t.plannedDay!); t.schedule="指定日期"; s.tasks.append(t)
            }
        }
        planner.reload()
        func plannerShot(_ filename:String) {
            guard let root=planner.window?.contentView, let bitmap=root.bitmapImageRepForCachingDisplay(in:root.bounds) else { fatalError("Missing planner") }
            root.layoutSubtreeIfNeeded(); root.cacheDisplay(in:root.bounds,to:bitmap)
            try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(filename))
        }
        plannerShot("docs/schedule-week.png")
        precondition(planner.calendar.cells.count == 7 && planner.calendar.hits.count == 5)
        let firstTodo = research.state.tasks.first{$0.planningGoalID == weekly.id}!
        let checkbox = planner.calendar.hits.first{$0.2 == firstTodo.id}!.1
        let clickPoint = planner.calendar.convert(NSPoint(x:checkbox.midX,y:checkbox.midY),to:nil)
        let clickEvent = NSEvent.mouseEvent(with:.leftMouseDown,location:clickPoint,modifierFlags:[],timestamp:0,windowNumber:planner.window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        planner.calendar.mouseDown(with:clickEvent)
        precondition(research.state.tasks.first{$0.id == firstTodo.id}!.completedAt != nil)
        planner.modes.selectedSegment=1; planner.reload(); plannerShot("docs/schedule-month.png")
        precondition(planner.calendar.cells.count == 35 && planner.calendar.hits.count == 5)
        planner.expandAll()
        let expandedCount=planner.outline.numberOfRows
        planner.collapseAll(); precondition(planner.outline.numberOfRows < expandedCount)
        planner.reload(); precondition(planner.outline.numberOfRows == planner.roots.count)
        planner.expandAll(); plannerShot("docs/schedule-outline.png")
        planner.selectedGoalID=nil; planner.selectedDay="2026-09-16"
        acceptNewForm("表单测试日程"); planner.addTodo()
        precondition(research.state.tasks.contains{$0.title == "表单测试日程" && $0.plannedDay == "2026-09-16"})
        acceptNewForm("表单测试月目标", configure: { root in
            func fields(_ v:NSView) -> [NSTextField] { (v as? NSTextField).map{[$0]} ?? v.subviews.flatMap(fields) }
            fields(root).first{$0.isEditable && $0.stringValue == "1"}!.stringValue="3"
        }); planner.addMonth()
        precondition(research.state.schedule!.goals.filter{$0.title == "表单测试月目标"}.count == 3)
        planner.selectedGoalID=monthly.id
        acceptNewForm("表单测试周目标"); planner.addWeek()
        precondition(research.state.schedule!.goals.contains{$0.title == "表单测试周目标" && $0.parentID == monthly.id})
        planner.collapseAll()
        let reopenedPlanner = ScheduleController(app:self)
        reopenedPlanner.modes.selectedSegment=2; reopenedPlanner.reload()
        precondition(reopenedPlanner.outline.numberOfRows == reopenedPlanner.roots.count)
        reopenedPlanner.window?.close()
        planner.window?.close()
        print("PASS: planner calendar week/month, Todo completion, folding persistence and editor saves")
        print("PASS: research board node form, dragging, filter, connected deletion and undo")
        showWorkspace(); workspace!.navigation.selectedSegment = 4; workspace!.reload()
        precondition(!workspace!.rowIDs.isEmpty)
        workspace!.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        acceptNewForm("测试短记：已完成一次验证"); workspace!.editItem()
        precondition(research.state.sessions.contains { $0.note.text == "测试短记：已完成一次验证" })
        if let content = workspace?.window?.contentView, let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.layoutSubtreeIfNeeded(); content.cacheDisplay(in: content.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/research-workspace.png"))
        }
        workspace?.window?.close()
        willSleep()
        precondition(countdown.isPaused && activityLog.active == nil)
        try! Data("passed".utf8).write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/ui-smoke-passed"))
        print("PASS: statistics/sleep tracking; dynamic ripple frame changes/on-off; wallpaper/theme/showcase/reminder; start stays visible; pause/resume; transparency 0/40/80; saved preference; reminder alpha; close/reopen; controls fit")
    }
'''
source = source.replace("    @objc func quit()", tests + "\n    @objc func quit()")
output = Path(".build/Smoke")
output.mkdir(parents=True, exist_ok=True)
(output / "AppDelegate.swift").write_text(source)
# Occlusion notifications lag behind synchronous close/reopen in this test.
# Keep production visibility/motion gating unchanged.
theme = Path("Sources/GlassTheme.swift").read_text().replace(" && window?.occlusionState.contains(.visible) == true", "")
(output / "GlassTheme.swift").write_text(theme)
source_path = 'FileManager.default.temporaryDirectory.appendingPathComponent("tomato-research-smoke-" + UUID().uuidString)'
# Every UI run uses a fresh, isolated database; never touch the installed app data.
app_source = (output / "AppDelegate.swift").read_text()
a = app_source.index('            let folder = try FileManager.default.url(')
b = app_source.index('            let store =', a)
app_source = app_source[:a] + '            let folder = ' + source_path + '\n' + app_source[b:]
(output / "AppDelegate.swift").write_text(app_source)
entry = Path("Sources/main.swift").read_text().replace("app.run()", """DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    delegate.runUISmoke()
    app.terminate(nil)
}
app.run()""")
(output / "main.swift").write_text(entry.replace("let app =", 'UserDefaults.standard.removePersistentDomain(forName: "local.tomato-glass.smoke")\nlet app ='))
