import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let pauseItem = NSMenuItem(title: "暂停", action: #selector(togglePause), keyEquivalent: "")
    let resetItem = NSMenuItem(title: "重置", action: #selector(reset), keyEquivalent: "")
    var countdown = Countdown()
    var timer: Timer?
    var settings: NSWindow?
    var minutesField: NSTextField?
    var errorLabel: NSTextField?
    var background: DreamBackground?
    var controlsLayout: NSView?
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
        phaseLabel?.stringValue = countdown.isRunning ? "正在专注 · 每一刻都算数" : countdown.isPaused ? "已暂停 · 按自己的节奏来" : "准备好了，就开始吧"
        windowPauseButton?.title = pauseItem.title
        windowPauseButton?.isEnabled = pauseItem.isEnabled
        windowResetButton?.isEnabled = resetItem.isEnabled
    }

    @objc func tick() {
        if countdown.finishIfDue(at: Date()) {
            save()
            menu.cancelTracking()
            DispatchQueue.main.async { [weak self] in self?.showReminder() }
        }
        refresh()
    }

    func begin(seconds: TimeInterval) {
        countdown.start(seconds: seconds, at: Date())
        save()
        refresh()
    }

    @objc func startPreset(_ sender: AnyObject) {
        let minutes = (sender as? NSMenuItem)?.tag ?? (sender as? NSButton)?.tag ?? 25
        minutesField?.stringValue = String(minutes)
        begin(seconds: Double(minutes) * 60)
    }

    @objc func togglePause() {
        if countdown.isRunning {
            // Never turn an already expired timer into a paused timer.
            if countdown.remaining(at: Date()) <= 0 { tick(); return }
            countdown.pause(at: Date())
        } else {
            countdown.resume(at: Date())
        }
        save()
        refresh()
    }

    @objc func reset() {
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
        NSSound(named: "Glass")?.play()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "时间到了 🍅"
        alert.informativeText = "这一段倒计时已完成。放松一下眼睛，起身活动活动吧。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.addButton(withTitle: "休息 5 分钟")
        alert.addButton(withTitle: "再专注 25 分钟")
        alert.window.level = .floating
        reminderWindow = alert.window
        applyTransparency()
        alert.window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let response = alert.runModal()
        reminderWindow = nil
        isShowingReminder = false
        if response == .alertSecondButtonReturn { begin(seconds: 5 * 60) }
        if response == .alertThirdButtonReturn { begin(seconds: 25 * 60) }
    }

    @objc func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) { save() }
}
