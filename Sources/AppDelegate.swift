import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let pauseItem = NSMenuItem(title: "暂停", action: #selector(togglePause), keyEquivalent: "")
    let resetItem = NSMenuItem(title: "重置", action: #selector(reset), keyEquivalent: "")
    var countdown = Countdown()
    var research: FocusSessionCoordinator!
    var workspace: ResearchWorkspaceWindowController?
    var researchBoard: ResearchBoardController?
    var scheduleWindow: ScheduleController?
    var projectPicker: NSPopUpButton?
    var researchTaskPicker: NSPopUpButton?
    var workTypePicker: NSPopUpButton?
    var selectedProjectID: UUID?
    var selectedTaskID: UUID?
    var lastSessionID: UUID?
    var storageFailed = false
    var activityLog: ActivityLog { research?.state.activityLog(at: Date()) ?? ActivityLog() }
    var taskField: NSComboBox?
    var categoryPicker: NSPopUpButton?
    var activityTitle: String = "未命名任务"
    var activityCategory: String = "学习"
    var statisticsWindow: NSWindow?
    var statisticsBoard: StatisticsBoard?
    var statisticsDate: NSDatePicker?
    var timer: Timer?
    var settings: NSWindow?
    var minutesField: NSTextField?
    var errorLabel: NSTextField?
    var background: DreamBackground?
    var controlsLayout: NSView?
    var soundPicker: NSPopUpButton?
    var reminderSound: NSSound?
    var themePicker: NSPopUpButton?
    var showcaseButton: NSButton?
    var phaseLabel: NSTextField?
    var countdownLabel: NSTextField?
    var windowPauseButton: NSButton?
    var windowResetButton: NSButton?
    var transparencyLabel: NSTextField?
    weak var reminderWindow: NSWindow?
    var transparency: Double {
        let value = UserDefaults.standard.double(forKey: "windowTransparency")
        return value.isFinite ? min(80, max(0, value)) : 0
    }
    var isShowingReminder = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch should not create a second menu-bar timer.
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSWorkspace.shared.openApplication(at: existing.bundleURL ?? Bundle.main.bundleURL,
                configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            NSApp.terminate(nil)
            return
        }
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "local.ry.menubar-pomodoro")
            let store = try SQLiteResearchStore(url: folder.appendingPathComponent("research.sqlite"))
            research = FocusSessionCoordinator(state: try LegacyMigration.bootstrap(store: store, defaults: .standard, now: Date()), repository: store)
            try research.recover()
            if let session = research.current {
                countdown = session.countdown
                selectedProjectID = session.projectID; selectedTaskID = session.taskID
                activityTitle = session.title; activityCategory = session.category
            }
        } catch {
            let alert = NSAlert(); alert.messageText = "科研数据未能打开"
            alert.informativeText = error.localizedDescription + "\n原数据不会被覆盖。请保留 Application Support 中的备份。"
            alert.runModal(); NSApp.terminate(nil); return
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        status.menu = menu
        status.button?.toolTip = "番茄钟：点击设置倒计时"
        menu.addItem(timeItem)
        menu.addItem(.separator())
        add("开始专注 · 25 分钟", action: #selector(startPreset), tag: 25)
        add("短休息 · 5 分钟", action: #selector(startPreset), tag: 5)
        add("长休息 · 15 分钟", action: #selector(startPreset), tag: 15)
        add("自定义倒计时…", action: #selector(showSettings))
        add("日程与目标…", action: #selector(showSchedule))
        add("研究进程看板…", action: #selector(showResearchBoard))
        add("科研工作台…", action: #selector(showWorkspace))
        add("时间统计与补记…", action: #selector(showStatistics))
        menu.addItem(.separator())
        pauseItem.target = self
        resetItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(resetItem)
        menu.addItem(.separator())
        add("退出番茄钟", action: #selector(quit))
        menu.autoenablesItems = false
        timeItem.isEnabled = false
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(tick), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        tick()
        DispatchQueue.main.async { [weak self] in self?.showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func add(_ title: String, action: Selector, tag: Int = 0) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag
        menu.addItem(item)
    }

    @discardableResult func researchAction(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            countdown = research.current?.countdown ?? Countdown(duration: countdown.duration)
            storageFailed = false
            workspace?.reload()
            scheduleWindow?.reload()
            return true
        } catch {
            NSApp.presentError(error)
            return false
        }
    }

    @objc func showSchedule() {
        if scheduleWindow == nil { scheduleWindow = ScheduleController(app: self) }
        scheduleWindow?.reload(); scheduleWindow?.showWindow(nil)
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showResearchBoard() {
        if researchBoard == nil { researchBoard = ResearchBoardController(app: self) }
        researchBoard?.reload(); researchBoard?.showWindow(nil)
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showWorkspace() {
        if workspace == nil { workspace = ResearchWorkspaceWindowController(delegate: self) }
        workspace?.showWindow(nil); workspace?.reload()
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
    }

    func syncTimer() {
        if !countdown.isRunning || storageFailed {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let ticker = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            ticker.tolerance = 0.05
            RunLoop.main.add(ticker, forMode: .common)
            timer = ticker
        }
    }

    func refresh() {
        syncTimer()
        let text = Countdown.display(countdown.remaining(at: Date()))
        status.button?.title = "🍅 " + (countdown.isPaused ? "Ⅱ " : "") + text
        timeItem.title = (countdown.isRunning ? "倒计时 " : countdown.isPaused ? "已暂停 " : "准备开始 ") + text
        pauseItem.title = countdown.isPaused ? "继续倒计时" : "暂停倒计时"
        pauseItem.isEnabled = countdown.isRunning || countdown.isPaused
        resetItem.isEnabled = countdown.isRunning || countdown.isPaused
        countdownLabel?.stringValue = text
        phaseLabel?.stringValue = (countdown.isRunning ? "计时中" : countdown.isPaused ? "已暂停" : "准备开始") + " · " + activityTitle
        taskField?.isEnabled = !countdown.isRunning && !countdown.isPaused && selectedTaskID == nil
        categoryPicker?.isEnabled = !countdown.isRunning && !countdown.isPaused
        for picker in [projectPicker, researchTaskPicker, workTypePicker] { picker?.isEnabled = research.current == nil }
        windowPauseButton?.title = pauseItem.title
        windowPauseButton?.isEnabled = pauseItem.isEnabled
        windowResetButton?.isEnabled = resetItem.isEnabled
    }

    @objc func tick() {
        guard research != nil, !storageFailed else { return }
        let now = Date()
        do {
            if let id = try research.tick(at: now) {
                lastSessionID = id
                menu.cancelTracking()
                DispatchQueue.main.async { [weak self] in self?.showReminder() }
                workspace?.reload()
            }
            countdown = research.current?.countdown ?? Countdown(duration: countdown.duration)
        } catch { storageFailed = true; timer?.invalidate(); timer = nil; NSApp.presentError(error) }
        refresh()
    }

    func begin(seconds: TimeInterval) {
        let title = taskField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? activityTitle
        activityTitle = title.isEmpty ? "未命名任务" : title
        activityCategory = categoryPicker?.titleOfSelectedItem ?? activityCategory
        let isBreak = activityCategory == "休息"
        if !isBreak {
            UserDefaults.standard.set(activityTitle, forKey: "lastFocusTask")
            UserDefaults.standard.set(activityCategory, forKey: "lastFocusCategory")
        }
        let task = research.state.tasks.first { $0.id == selectedTaskID }
        let name = isBreak ? "休息" : (task?.title ?? activityTitle)
        if researchAction({ try research.start(projectID: isBreak ? nil : selectedProjectID, taskID: isBreak ? nil : selectedTaskID, title: name, category: activityCategory, workType: isBreak ? "其他" : (workTypePicker?.titleOfSelectedItem ?? "学习"), seconds: seconds, at: Date()) }) {
            activityTitle = name
        }
        refresh()
    }

    @objc func startPreset(_ sender: AnyObject) {
        let minutes = (sender as? NSMenuItem)?.tag ?? (sender as? NSButton)?.tag ?? 25
        minutesField?.stringValue = String(minutes)
        if minutes == 5 || minutes == 15 {
            taskField?.stringValue = "休息"
            categoryPicker?.selectItem(withTitle: "休息")
            activityTitle = "休息"
            activityCategory = "休息"
        }
        if minutes == 25 && activityCategory == "休息" {
            activityTitle = UserDefaults.standard.string(forKey: "lastFocusTask") ?? "未命名任务"
            activityCategory = UserDefaults.standard.string(forKey: "lastFocusCategory") ?? "学习"
            taskField?.stringValue = activityTitle
            categoryPicker?.selectItem(withTitle: activityCategory)
        }
        begin(seconds: Double(minutes) * 60)
    }

    @objc func togglePause() {
        if countdown.isRunning && countdown.remaining(at: Date()) <= 0 { tick(); return }
        _ = researchAction {
            if countdown.isRunning { try research.pause(at: Date()) }
            else { try research.resume(at: Date()) }
        }
        refresh()
    }

    @objc func reset() {
        _ = researchAction { lastSessionID = try research.finish(at: Date(), reason: "提前结束") }
        refresh()
    }

    @objc func startCustom() {
        let raw = minutesField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let minutes = Int(raw), (1...599).contains(minutes) else {
            errorLabel?.stringValue = "请输入 1–599 之间的整数分钟。"
            errorLabel?.textColor = .systemRed
            return
        }
        errorLabel?.stringValue = "支持 1–599 分钟"
        errorLabel?.textColor = .secondaryLabelColor
        begin(seconds: Double(minutes) * 60)
    }

    @objc func changeTransparency(_ sender: NSSlider) {
        UserDefaults.standard.set(sender.doubleValue, forKey: "windowTransparency")
        applyTransparency()
    }

    func applyTransparency() {
        let alpha = CGFloat(1 - transparency / 100)
        settings?.alphaValue = alpha
        reminderWindow?.alphaValue = alpha
        transparencyLabel?.stringValue = "透明度 \(Int(transparency.rounded()))%"
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        if ![settings, workspace?.window, researchBoard?.window, scheduleWindow?.window, statisticsWindow].compactMap({ $0 }).contains(where: { $0 !== closing && $0.isVisible }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func showReminder() {
        guard !isShowingReminder else { return }
        isShowingReminder = true
        playReminderSound()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "时间到了 🍅"
        alert.informativeText = "这一段倒计时已完成。放松一下眼睛，起身活动活动吧。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.addButton(withTitle: "休息 5 分钟")
        alert.addButton(withTitle: "再专注 25 分钟")
        let note = NSTextField(string: "")
        note.placeholderString = "可选短记：做了什么 / 发现 / 下一步（也可稍后在工作台补写）"
        note.frame = NSRect(x: 0, y: 0, width: 440, height: 28)
        alert.accessoryView = note
        let finishedID = lastSessionID
        AppFont.apply(to: alert.window.contentView)
        alert.window.level = .floating
        reminderWindow = alert.window
        applyTransparency()
        alert.window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let response = alert.runModal()
        if !note.stringValue.isEmpty, let id = finishedID {
            _ = researchAction { try research.change { state in
                if let i = state.sessions.firstIndex(where: { $0.id == id }) { state.sessions[i].note.text = note.stringValue }
            } }
        }
        reminderSound?.stop()
        reminderSound = nil
        reminderWindow = nil
        isShowingReminder = false
        if response == .alertSecondButtonReturn { let item = NSMenuItem(); item.tag = 5; startPreset(item) }
        if response == .alertThirdButtonReturn { let item = NSMenuItem(); item.tag = 25; startPreset(item) }
    }

    @objc func quit() { NSApp.terminate(nil) }

    @objc func willSleep() {
        _ = researchAction { try research.pause(at: Date(), reason: "睡眠") }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard research != nil else { return }
        do { try research.pause(at: Date(), reason: "退出") }
        catch { NSLog("Research state could not be saved on exit; checkpoint recovery will be used.") }
    }
}
