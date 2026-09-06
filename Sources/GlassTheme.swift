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
                            NSColor(srgbRed: 0.46, green: 0.29, blue: 0.59, alpha: 1),
                            NSColor(srgbRed: 0.80, green: 0.47, blue: 0.65, alpha: 1)])!.draw(in: bounds, angle: 30)
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
    label.font = .systemFont(ofSize: size, weight: size >= 20 ? .semibold : .regular)
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
