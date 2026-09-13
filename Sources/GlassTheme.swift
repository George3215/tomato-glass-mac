import AppKit

final class DreamBackground: NSView {
    var picture: NSImage? { didSet { rebuildWater() } }
    var dynamicEnabled = false { didSet { if oldValue != dynamicEnabled { rebuildWater() } } }
    private(set) var water: RippleWater?
    private(set) var animationTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    func rebuildWater() {
        stopAnimation()
        needsDisplay = true
        syncAnimation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        if let window {
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] note in
                    if note.name == NSWindow.willCloseNotification { self?.stopAnimation() }
                    else { self?.syncAnimation() }
                })
            }
        }
        syncAnimation()
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        water = nil
    }

    func syncAnimation() {
        let visible = window?.isVisible == true && window?.isMiniaturized == false && window?.occlusionState.contains(.visible) == true
        let allowed = visible && dynamicEnabled && picture != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard allowed else { stopAnimation(); needsDisplay = true; return }
        guard animationTimer == nil else { return }
        if water == nil { water = picture.flatMap { RippleWater(image: $0, size: bounds.size) } }
        guard water != nil else { return }
        let timer = Timer(timeInterval: 1.0/30, repeats: true) { [weak self] _ in
            guard let self else { return }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.stopAnimation(); self.needsDisplay = true; return }
            self.water?.advance()
            self.needsDisplay = true
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    override func mouseDown(with event: NSEvent) { disturb(event) }
    override func mouseDragged(with event: NSEvent) { disturb(event) }
    private func disturb(_ event: NSEvent) {
        guard dynamicEnabled, let water, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let point = convert(event.locationInWindow, from: nil)
        water.poke(x: point.x/bounds.width*Double(water.width), y: (1-point.y/bounds.height)*Double(water.height))
    }

    deinit {
        animationTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    override func draw(_ dirtyRect: NSRect) {
        if let picture, picture.size.width > 0, picture.size.height > 0 {
            let scale = max(bounds.width / picture.size.width, bounds.height / picture.size.height)
            let size = NSSize(width: picture.size.width * scale, height: picture.size.height * scale)
            if let water, dynamicEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                water.draw(in: bounds)
            } else {
                picture.draw(in: NSRect(x: (bounds.width-size.width)/2, y: (bounds.height-size.height)/2, width: size.width, height: size.height))
            }
            NSColor.black.withAlphaComponent(0.23).setFill()
            bounds.fill()
        } else {
        NSGradient(colors: [NSColor(srgbRed: 0.13, green: 0.12, blue: 0.29, alpha: 1),
                            NSColor(srgbRed: 0.06, green: 0.16, blue: 0.43, alpha: 1),
                            NSColor(srgbRed: 0.27, green: 0.14, blue: 0.44, alpha: 1)])!.draw(in: bounds, angle: 30)
            for i in 0..<8 {
                let x = CGFloat(i) * bounds.width / 6 - 150
                let oval = NSBezierPath(ovalIn: NSRect(x: x, y: sin(Double(i)) * 170 - 160, width: 580, height: 600))
                NSColor(srgbRed: 0.80, green: 0.65, blue: 1, alpha: 0.055).setFill()
                oval.fill()
            }
            let curve = NSBezierPath()
            curve.move(to: NSPoint(x: -60, y: 130))
            curve.curve(to: NSPoint(x: bounds.width + 80, y: 390), controlPoint1: NSPoint(x: 330, y: 560), controlPoint2: NSPoint(x: 420, y: -140))
            curve.lineWidth = 2
            NSColor.white.withAlphaComponent(0.16).setStroke()
            curve.stroke()
        }
    }
}

final class GlassCard: NSView {
    init(content: NSView, padding: CGFloat = 24) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.30).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.alphaValue = 0.32
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 24
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor), effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor), effect.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            content.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

func glassLabel(_ title: String, size: CGFloat = 13, muted: Bool = false) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.font = AppFont.font(size, weight: size >= 20 ? .semibold : .regular)
    label.textColor = NSColor.white.withAlphaComponent(muted ? 0.68 : 0.96)
    return label
}

func glassStack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = 16) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = vertical ? .vertical : .horizontal
    stack.alignment = vertical ? .leading : .centerY
    stack.spacing = spacing
    return stack
}

func glassButton(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.bezelStyle = .rounded
    return button
}


/// Shared, static night-sky backdrop. No timer or additional image buffers.
class StarfieldSurface: NSView {
    override func draw(_ dirtyRect: NSRect) { StarGlass.drawSky(in: bounds) }
}

enum StarGlass {
    static let panel = NSColor(srgbRed: 0.13, green: 0.16, blue: 0.36, alpha: 0.78)
    static let accent = NSColor(srgbRed: 0.66, green: 0.76, blue: 1, alpha: 1)
    static func drawSky(in rect: NSRect) {
        NSGradient(colors: [NSColor(srgbRed: 0.035, green: 0.055, blue: 0.16, alpha: 1),
                            NSColor(srgbRed: 0.06, green: 0.16, blue: 0.43, alpha: 1),
                            NSColor(srgbRed: 0.27, green: 0.14, blue: 0.44, alpha: 1)])!.draw(in: rect, angle: 28)
        for i in 0..<65 {
            let x = rect.minX + CGFloat((i * 173 + 31) % 997) / 997 * rect.width
            let y = rect.minY + CGFloat((i * 283 + 73) % 991) / 991 * rect.height
            NSColor.white.withAlphaComponent(i % 4 == 0 ? 0.30 : 0.12).setFill()
            let size: CGFloat = i % 5 == 0 ? 2 : 1
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: size, height: size)).fill()
        }
    }
    static func frost(_ view: NSView) {
        guard !view.subviews.contains(where: { $0.identifier?.rawValue == "star-glass-effect" }) else { return }
        view.wantsLayer = true
        view.layer?.backgroundColor = panel.withAlphaComponent(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.40).cgColor
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
        view.layer?.borderColor = accent.withAlphaComponent(0.22).cgColor
        let effect = NSVisualEffectView(frame: view.bounds)
        effect.identifier = .init("star-glass-effect")
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow; effect.blendingMode = .withinWindow; effect.state = .active
        effect.wantsLayer = true
        effect.layer?.backgroundColor = panel.withAlphaComponent(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.40).cgColor
        view.addSubview(effect, positioned: .below, relativeTo: nil)
    }
    static func apply(to view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.drawsBackground = false; scroll.contentView.drawsBackground = false
            frost(scroll)
        }
        if let table = view as? NSTableView {
            table.backgroundColor = .clear
            table.usesAlternatingRowBackgroundColors = false
        }
        if let field = view as? NSTextField, field.isEditable {
            field.backgroundColor = panel; field.textColor = .labelColor
        }
        if let text = view as? NSTextView {
            text.drawsBackground = false; text.textColor = .labelColor
            text.insertionPointColor = .white
        }
        for child in view.subviews where !(child is NSVisualEffectView) { apply(to: child) }
    }
}

extension NSAlert {
    @discardableResult func runGlassModal() -> NSApplication.ModalResponse {
        window.appearance = NSAppearance(named: .darkAqua)
        if let accessoryView { StarGlass.apply(to: accessoryView) }
        if let root = window.contentView {
            let sky = StarfieldSurface(frame: root.bounds)
            sky.autoresizingMask = [.width, .height]
            root.addSubview(sky, positioned: .below, relativeTo: nil)
            StarGlass.apply(to: root)
        }
        return runModal()
    }
}
