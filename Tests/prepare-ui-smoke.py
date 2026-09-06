"""Generate a separate native smoke-test app without shipping test hooks."""
from pathlib import Path
source = Path("Sources/AppDelegate.swift").read_text()
tests = r''' 
    func runUISmoke() {
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
        togglePause()
        precondition(countdown.isPaused && window.isVisible)
        togglePause()
        precondition(countdown.isRunning)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            precondition(NSApp.modalWindow != nil, "Reminder must be visible")
            NSApp.abortModal()
        }
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
        print("PASS: dynamic ripple frame changes/on-off; wallpaper/theme/showcase/reminder; start stays visible; pause/resume; transparency 0/40/80; saved preference; reminder alpha; close/reopen; controls fit")
    }
'''
source = source.replace("    @objc func quit()", tests + "\n    @objc func quit()")
output = Path(".build/Smoke")
output.mkdir(parents=True, exist_ok=True)
(output / "AppDelegate.swift").write_text(source)
entry = Path("Sources/main.swift").read_text().replace("app.run()", """DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    delegate.runUISmoke()
    app.terminate(nil)
}
app.run()""")
(output / "main.swift").write_text(entry)
