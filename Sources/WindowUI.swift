import AppKit
import UniformTypeIdentifiers

extension AppDelegate {
    @objc func showSettings() {
        NSApp.setActivationPolicy(.regular)
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 700), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "🍅 菜单栏番茄钟"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            let backdrop = DreamBackground(frame: window.contentView!.bounds)
            window.contentView = backdrop
            background = backdrop
            applyBackground()
            let brand = glassLabel("🍅  番茄时光", size: 23)
            let subtitle = glassLabel("给自己一小段，不被打扰的时间。", muted: true)
            let heading = glassStack([brand, subtitle], spacing: 7)

            let caption = glassLabel("F O C U S   /   专 注", size: 12, muted: true)
            let currentTime = glassLabel("25:00", size: 76)
            currentTime.font = .monospacedDigitSystemFont(ofSize: 76, weight: .light)
            countdownLabel = currentTime
            let phase = glassLabel("准备好了，就开始吧", muted: true)
            phase.lineBreakMode = .byTruncatingTail
            phase.widthAnchor.constraint(lessThanOrEqualToConstant: 430).isActive = true
            phaseLabel = phase
            let presets = glassStack([], vertical: false, spacing: 8)
            for (name, value) in [("专注 25′",25), ("小憩 5′",5), ("休息 15′",15)] {
                let button = NSButton(title: name, target: self, action: #selector(startPreset))
                button.tag = value
                button.bezelStyle = .rounded
                presets.addArrangedSubview(button)
            }
            let start = glassButton("开始专注", target: self, action: #selector(startCustom))
            start.controlSize = .large
            start.bezelColor = NSColor(srgbRed: 0.73, green: 0.42, blue: 0.69, alpha: 1)
            start.keyEquivalent = "\r"
            let pause = glassButton("暂停", target: self, action: #selector(togglePause))
            let reset = glassButton("重置", target: self, action: #selector(reset))
            windowPauseButton = pause
            windowResetButton = reset
            let controls = glassStack([start, pause, reset], vertical: false, spacing: 8)
            let task = NSComboBox()
            task.addItems(withObjectValues: Array(Set(activityLog.entries.map { $0.task })).sorted())
            task.stringValue = activityTitle
            task.placeholderString = "项目 / 学习任务名称"
            task.widthAnchor.constraint(equalToConstant: 430).isActive = true
            taskField = task
            let categories = NSPopUpButton()
            categories.addItems(withTitles: ["学习", "工作", "休息", "其他"])
            categories.selectItem(withTitle: activityCategory)
            categoryPicker = categories
            let stats = glassButton("时间统计 / 补记", target: self, action: #selector(showStatistics))
            let done = glassButton("任务完成", target: self, action: #selector(completeTask))
            let taskControls = glassStack([categories, stats, done], vertical: false, spacing: 8)
            let focus = glassStack([caption, task, taskControls, currentTime, phase, presets, controls], spacing: 16)
            focus.alignment = .centerX
            let focusCard = GlassCard(content: focus)

            let field = NSTextField(string: "25")
            field.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)
            field.alignment = .center
            field.widthAnchor.constraint(equalToConstant: 74).isActive = true
            let durationRow = glassStack([field, glassLabel("分钟", muted: true)], vertical: false, spacing: 10)
            minutesField = field
            let error = glassLabel("支持 1–599 分钟", size: 11, muted: true)
            errorLabel = error
            let opacityText = glassLabel("透明度 0%", size: 12)
            transparencyLabel = opacityText
            let slider = NSSlider(value: transparency, minValue: 0, maxValue: 80, target: self, action: #selector(changeTransparency(_:)))
            slider.isContinuous = true
            slider.trackFillColor = NSColor(srgbRed: 0.92, green: 0.61, blue: 0.79, alpha: 1)
            slider.setAccessibilityLabel("窗口透明度")
            slider.widthAnchor.constraint(equalToConstant: 190).isActive = true
            let imageButton = glassButton("选择背景图片…", target: self, action: #selector(chooseBackground))
            let picker = NSPopUpButton()
            picker.addItems(withTitles: ["冰蓝蝴蝶 · Internal Beyond", "粉紫渐变", "自选壁纸"])
            picker.target = self
            picker.action = #selector(changeTheme(_:))
            picker.widthAnchor.constraint(equalToConstant: 190).isActive = true
            picker.selectItem(at: selectedTheme)
            themePicker = picker
            let motion = NSButton(checkboxWithTitle: "动态雨滴与涟漪", target: self, action: #selector(toggleMotion(_:)))
            motion.state = motionEnabled ? .on : .off
            let fonts = NSPopUpButton()
            fonts.addItems(withTitles: ["Comic Sans MS", "系统字体"])
            fonts.selectItem(at: AppFont.useComic ? 0 : 1)
            fonts.target = self
            fonts.action = #selector(changeFont(_:))
            let sounds = NSPopUpButton()
            sounds.addItems(withTitles: ["提示音：关闭", "Ping", "Glass", "Pop", "Purr", "自选音频…"])
            sounds.target = self
            sounds.action = #selector(changeSound(_:))
            sounds.widthAnchor.constraint(equalToConstant: 128).isActive = true
            soundPicker = sounds
            refreshSoundPicker()
            let soundRow = glassStack([sounds, glassButton("试听", target: self, action: #selector(previewSound))], vertical: false, spacing: 6)
            let options = glassStack([glassLabel("我的空间", size: 19), glassLabel("自定义时长", size: 12, muted: true), durationRow, error,
                opacityText, slider, picker, motion, imageButton, fonts, soundRow], spacing: 13)
            let optionsCard = GlassCard(content: options, padding: 20)
            optionsCard.widthAnchor.constraint(equalToConstant: 234).isActive = true
            let cards = glassStack([focusCard, optionsCard], vertical: false, spacing: 18)
            cards.alignment = .top
            let footer = glassLabel("✧  时间到会弹窗提醒    ·    关闭窗口后，菜单栏仍继续计时", size: 11, muted: true)
            let layout = glassStack([heading, cards, footer], spacing: 24)
            layout.translatesAutoresizingMaskIntoConstraints = false
            backdrop.addSubview(layout)
            NSLayoutConstraint.activate([
                layout.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 30),
                layout.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -30),
                layout.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 54),
                cards.widthAnchor.constraint(equalTo: layout.widthAnchor),
                focusCard.widthAnchor.constraint(equalTo: cards.widthAnchor, constant: -252),
                focusCard.heightAnchor.constraint(equalTo: optionsCard.heightAnchor)
            ])
            controlsLayout = layout
            let show = glassButton("壁纸展示", target: self, action: #selector(toggleShowcase))
            show.translatesAutoresizingMaskIntoConstraints = false
            backdrop.addSubview(show)
            NSLayoutConstraint.activate([
                show.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -30),
                show.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -18)
            ])
            showcaseButton = show
            settings = window
            window.center()
        }
        controlsLayout?.isHidden = false
        showcaseButton?.title = "壁纸展示"
        minutesField?.stringValue = String(Int(countdown.duration / 60))
        applyTransparency()
        AppFont.apply(to: settings?.contentView)
        menu.font = AppFont.font(13)
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
        settings?.orderFrontRegardless()
        settings?.makeFirstResponder(minutesField)
        background?.syncAnimation()
    }

    @objc func changeFont(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem == 0, forKey: "comicFont")
        AppFont.apply(to: settings?.contentView)
        AppFont.apply(to: statisticsWindow?.contentView)
        menu.font = AppFont.font(13)
        refreshStatistics()
    }

    @objc func chooseBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard let settings else { return }
        panel.beginSheetModal(for: settings) { [weak self] response in
            guard response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
            self?.background?.picture = image
            UserDefaults.standard.set(url.path, forKey: "backgroundImagePath")
            UserDefaults.standard.set(2, forKey: "backgroundTheme")
            self?.themePicker?.selectItem(at: 2)
            self?.background?.dynamicEnabled = false
        }
    }

    var selectedTheme: Int {
        let value = UserDefaults.standard.object(forKey: "backgroundTheme") as? Int
        return value.map { (0...2).contains($0) ? $0 : 0 } ?? (UserDefaults.standard.string(forKey: "backgroundImagePath") == nil ? 0 : 2)
    }

    var motionEnabled: Bool { (UserDefaults.standard.object(forKey: "wallpaperMotion") as? Bool) ?? true }

    @objc func toggleMotion(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "wallpaperMotion")
        background?.dynamicEnabled = selectedTheme == 0 && motionEnabled
    }

    func applyBackground() {
        defer { background?.dynamicEnabled = selectedTheme == 0 && motionEnabled }
        switch selectedTheme {
        case 2:
            background?.picture = UserDefaults.standard.string(forKey: "backgroundImagePath").flatMap { NSImage(contentsOfFile: $0) }
        case 1: background?.picture = nil
        default:
            background?.picture = Bundle.main.url(forResource: "internal-beyond-butterfly", withExtension: "png", subdirectory: "Wallpapers").flatMap { NSImage(contentsOf: $0) }
        }
    }

    @objc func changeTheme(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "backgroundTheme")
        applyBackground()
    }

    @objc func toggleShowcase() {
        guard let controlsLayout else { return }
        controlsLayout.isHidden.toggle()
        showcaseButton?.title = controlsLayout.isHidden ? "返回番茄钟" : "壁纸展示"
    }
}


extension AppDelegate {
    var selectedSound: String { UserDefaults.standard.string(forKey: "reminderSound") ?? "" }

    func refreshSoundPicker() {
        let names = ["", "Ping", "Glass", "Pop", "Purr", "custom"]
        soundPicker?.selectItem(at: names.firstIndex(of: selectedSound) ?? 0)
        soundPicker?.toolTip = selectedSound == "custom" ? "自选音频已保存；再次选择可更换" : "关闭仅静音，时间到仍弹窗"
    }

    @objc func changeSound(_ sender: NSPopUpButton) {
        reminderSound?.stop()
        reminderSound = nil
        if sender.indexOfSelectedItem == 5 {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.audio]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { refreshSoundPicker(); return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= 20_000_000, NSSound(contentsOf: url, byReference: false) != nil else {
                    throw ActivityImport.error("请选择可播放的音频文件（最大 20 MB）。")
                }
                let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(Bundle.main.bundleIdentifier ?? "local.ry.menubar-pomodoro")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent("reminder-audio")
                try Data(contentsOf: url).write(to: destination, options: .atomic)
                UserDefaults.standard.set(destination.path, forKey: "reminderSoundPath")
                UserDefaults.standard.set("custom", forKey: "reminderSound")
            } catch { NSApp.presentError(error) }
        } else {
            UserDefaults.standard.set(["", "Ping", "Glass", "Pop", "Purr"][sender.indexOfSelectedItem], forKey: "reminderSound")
        }
        refreshSoundPicker()
    }

    func makeReminderSound() -> NSSound? {
        if selectedSound == "custom" {
            return UserDefaults.standard.string(forKey: "reminderSoundPath").flatMap { NSSound(contentsOfFile: $0, byReference: false) }
        }
        guard ["Ping", "Glass", "Pop", "Purr"].contains(selectedSound) else { return nil }
        return NSSound(named: NSSound.Name(selectedSound))
    }

    func playReminderSound() {
        reminderSound?.stop()
        reminderSound = makeReminderSound()
        reminderSound?.loops = false
        reminderSound?.play()
    }

    @objc func previewSound() { playReminderSound() }
}
