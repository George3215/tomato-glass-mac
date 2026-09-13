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
            NSColor(srgbRed: 0.15, green: 0.15, blue: 0.17, alpha: 1).setFill()
            bounds.fill()
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


/// A quiet, grouped background shared by the planning and record windows.
class GroupedSurface: NSView {
    override func draw(_ dirtyRect: NSRect) { SoftGlass.drawBackground(in: bounds) }
}

enum SoftGlass {
    static let panel = NSColor.white
    static let accent = NSColor(srgbRed: 0, green: 0.478, blue: 1, alpha: 1)
    static let separator = NSColor(srgbRed: 0.23, green: 0.23, blue: 0.26, alpha: 0.12)
    static func drawBackground(in rect: NSRect) {
        NSColor(srgbRed: 0.949, green: 0.949, blue: 0.969, alpha: 1).setFill()
        rect.fill()
    }
    static func frost(_ view: NSView) {
        guard !view.subviews.contains(where: { $0.identifier?.rawValue == "soft-glass-effect" }) else { return }
        view.wantsLayer = true
        view.layer?.backgroundColor = panel.withAlphaComponent(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.40).cgColor
        view.layer?.cornerRadius = 18
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
        view.layer?.borderColor = separator.cgColor
        let effect = NSVisualEffectView(frame: view.bounds)
        effect.identifier = .init("soft-glass-effect")
        effect.autoresizingMask = [.width, .height]
        effect.material = .contentBackground; effect.blendingMode = .withinWindow; effect.state = .active
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
            text.insertionPointColor = accent
        }
        for child in view.subviews where !(child is NSVisualEffectView) { apply(to: child) }
    }
}

extension NSAlert {
    @discardableResult func runGlassModal() -> NSApplication.ModalResponse {
        window.appearance = NSAppearance(named: .aqua)
        if let accessoryView { SoftGlass.apply(to: accessoryView) }
        if let root = window.contentView {
            let background = GroupedSurface(frame: root.bounds)
            background.autoresizingMask = [.width, .height]
            root.addSubview(background, positioned: .below, relativeTo: nil)
            SoftGlass.apply(to: root)
        }
        return runModal()
    }
}
