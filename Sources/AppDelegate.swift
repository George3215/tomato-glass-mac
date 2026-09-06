import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let pauseItem = NSMenuItem(title: "暂停", action: #selector(togglePause), keyEquivalent: "")
    let resetItem = NSMenuItem(title: "重置", action: #selector(reset), keyEquivalent: "")
    var countdown = Countdown()
    var activityLog = ActivityLog()
    var taskField: NSComboBox?
    var categoryPicker: NSPopUpButton?
    var activityTitle: String = "未命名任务"
    var activityCategory: String = "学习"
    var statisticsWindow: NSWindow?
    var statisticsBoard: StatisticsBoard?
    var statisticsDate: NSDatePicker?
    let activityKey = "activityLog.v1"
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
    let storageKey = "savedCountdown.v1"
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
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Countdown.self, from: data),
           saved.duration.isFinite, saved.duration >= 1, saved.duration <= 599 * 60 {
            countdown = saved
        }
        if let data = UserDefaults.standard.data(forKey: activityKey),
           let saved = try? JSONDecoder().decode(ActivityLog.self, from: data) { activityLog = saved }
        if let active = activityLog.active {
            activityTitle = active.task
            activityCategory = active.category
            if countdown.isRunning { countdown.pause(at: active.checkpoint) }
            activityLog.recover()
            saveActivity()
        } else {
            activityTitle = UserDefaults.standard.string(forKey: "selectedTask") ?? "未命名任务"
            activityCategory = UserDefaults.standard.string(forKey: "selectedCategory") ?? "学习"
            if countdown.isRunning { countdown.pause(at: Date()) }
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

    func save() {
        if let data = try? JSONEncoder().encode(countdown) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func syncTimer() {
        if !countdown.isRunning {
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
        taskField?.isEnabled = !countdown.isRunning && !countdown.isPaused
        categoryPicker?.isEnabled = !countdown.isRunning && !countdown.isPaused
        windowPauseButton?.title = pauseItem.title
        windowPauseButton?.isEnabled = pauseItem.isEnabled
        windowResetButton?.isEnabled = resetItem.isEnabled
    }

    @objc func tick() {
        let now = Date()
        let deadline = countdown.deadline
        if countdown.finishIfDue(at: now) {
            activityLog.finish(at: deadline ?? now, reason: "到时")
            saveActivity()
            save()
            menu.cancelTracking()
            DispatchQueue.main.async { [weak self] in self?.showReminder() }
        }
        if let active = activityLog.active, now.timeIntervalSince(active.checkpoint) >= 30 {
            activityLog.checkpoint(at: now)
            saveActivity()
        }
        refresh()
    }

    func begin(seconds: TimeInterval) {
        let now = Date()
        if let deadline = countdown.deadline { activityLog.finish(at: min(now, deadline), reason: "切换") }
        activityTitle = taskField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? activityTitle
        if activityTitle.isEmpty { activityTitle = "未命名任务" }
        activityCategory = categoryPicker?.titleOfSelectedItem ?? activityCategory
        if activityCategory != "休息" {
            UserDefaults.standard.set(activityTitle, forKey: "lastFocusTask")
            UserDefaults.standard.set(activityCategory, forKey: "lastFocusCategory")
        }
        activityLog.begin(task: activityTitle, category: activityCategory, at: now)
        UserDefaults.standard.set(activityTitle, forKey: "selectedTask")
        UserDefaults.standard.set(activityCategory, forKey: "selectedCategory")
        saveActivity()
        countdown.start(seconds: seconds, at: now)
        save()
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
        if countdown.isRunning {
            // Never turn an already expired timer into a paused timer.
            if countdown.remaining(at: Date()) <= 0 { tick(); return }
            activityLog.finish(at: Date(), reason: "暂停")
            countdown.pause(at: Date())
        } else if countdown.isPaused {
            activityLog.begin(task: activityTitle, category: activityCategory, at: Date())
            countdown.resume(at: Date())
        }
        saveActivity()
        save()
        refresh()
    }

    @objc func reset() {
        activityLog.finish(at: min(Date(), countdown.deadline ?? Date()), reason: "提前结束")
        saveActivity()
        countdown.reset()
        save()
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
        NSApp.setActivationPolicy(.accessory)
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
        AppFont.apply(to: alert.window.contentView)
        alert.window.level = .floating
        reminderWindow = alert.window
        applyTransparency()
        alert.window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let response = alert.runModal()
        reminderSound?.stop()
        reminderSound = nil
        reminderWindow = nil
        isShowingReminder = false
        if response == .alertSecondButtonReturn { let item = NSMenuItem(); item.tag = 5; startPreset(item) }
        if response == .alertThirdButtonReturn { let item = NSMenuItem(); item.tag = 25; startPreset(item) }
    }

    @objc func quit() { NSApp.terminate(nil) }

    func saveActivity() {
        if let data = try? JSONEncoder().encode(activityLog) { UserDefaults.standard.set(data, forKey: activityKey) }
    }

    @objc func willSleep() {
        if countdown.isRunning {
            activityLog.finish(at: min(Date(), countdown.deadline ?? Date()), reason: "睡眠")
            countdown.pause(at: Date())
            saveActivity()
            save()
            refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if countdown.isRunning {
            activityLog.finish(at: min(Date(), countdown.deadline ?? Date()), reason: "退出")
            countdown.pause(at: Date())
        }
        saveActivity()
        save()
    }
}
