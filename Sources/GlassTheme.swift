import AppKit

final class DreamBackground: NSView {
    var picture: NSImage? { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(colors: [NSColor(srgbRed: 0.13, green: 0.12, blue: 0.29, alpha: 1),
                            NSColor(srgbRed: 0.46, green: 0.29, blue: 0.59, alpha: 1),
                            NSColor(srgbRed: 0.80, green: 0.47, blue: 0.65, alpha: 1)])!.draw(in: bounds, angle: 30)
        if let picture, picture.size.width > 0, picture.size.height > 0 {
            let scale = max(bounds.width / picture.size.width, bounds.height / picture.size.height)
            let size = NSSize(width: picture.size.width * scale, height: picture.size.height * scale)
            picture.draw(in: NSRect(x: (bounds.width-size.width)/2, y: (bounds.height-size.height)/2, width: size.width, height: size.height))
            NSColor.black.withAlphaComponent(0.23).setFill()
            bounds.fill()
        } else {
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
