"""Generate a separate native smoke-test app without shipping test hooks."""
from pathlib import Path
source = Path("Sources/AppDelegate.swift").read_text()
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
        func acceptNewForm(_ title: String, capture: Bool = false) {
            let timer = Timer(timeInterval: 0.25, repeats: false) { _ in
                guard let root = NSApp.modalWindow?.contentView else { fatalError("Missing edit form") }
                func fields(_ view: NSView) -> [NSTextField] {
                    (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
                }
                let editable = fields(root).filter { $0.isEditable }
                precondition(!editable.isEmpty, "Form fields missing")
                editable[0].stringValue = title
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
        print("FONT: " + AppFont.font(13).fontName)
        if let board = statisticsBoard, let bitmap = board.bitmapImageRepForCachingDisplay(in: board.bounds) {
            board.layoutSubtreeIfNeeded()
            board.cacheDisplay(in: board.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/records.png"))
        }
        statisticsWindow?.close()
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
