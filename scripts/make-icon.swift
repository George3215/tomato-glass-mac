import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func drawTomato(_ size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()

    let body = NSBezierPath()
    body.move(to: NSPoint(x: 512, y: 754))
    body.curve(to: NSPoint(x: 112, y: 454), controlPoint1: NSPoint(x: 268, y: 856), controlPoint2: NSPoint(x: 95, y: 681))
    body.curve(to: NSPoint(x: 512, y: 115), controlPoint1: NSPoint(x: 127, y: 220), controlPoint2: NSPoint(x: 313, y: 92))
    body.curve(to: NSPoint(x: 912, y: 454), controlPoint1: NSPoint(x: 711, y: 92), controlPoint2: NSPoint(x: 897, y: 220))
    body.curve(to: NSPoint(x: 512, y: 754), controlPoint1: NSPoint(x: 929, y: 681), controlPoint2: NSPoint(x: 756, y: 856))
    body.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    shadow.set()
    NSColor.systemRed.setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 1, green: 0.34, blue: 0.26, alpha: 1),
               ending: NSColor(calibratedRed: 0.78, green: 0.055, blue: 0.10, alpha: 1))!.draw(in: body, angle: -70)

    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: 224, y: 526))
    shine.curve(to: NSPoint(x: 341, y: 672), controlPoint1: NSPoint(x: 223, y: 602), controlPoint2: NSPoint(x: 280, y: 655))
    shine.lineWidth = 40
    shine.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.33).setStroke()
    shine.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 516, y: 760))
    stem.curve(to: NSPoint(x: 575, y: 905), controlPoint1: NSPoint(x: 502, y: 833), controlPoint2: NSPoint(x: 544, y: 898))
    stem.lineWidth = 46
    stem.lineCapStyle = .round
    NSColor(calibratedRed: 0.14, green: 0.39, blue: 0.15, alpha: 1).setStroke()
    stem.stroke()
    let leaves = NSBezierPath()
    let points: [(CGFloat, CGFloat)] = [(512,790),(398,858),(419,771),(285,740),(429,703),(404,611),(515,689),(626,620),(601,722),(749,765),(601,791),(628,859)]
    leaves.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { leaves.line(to: NSPoint(x: point.0, y: point.1)) }
    leaves.close()
    NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.72, blue: 0.23, alpha: 1),
               ending: NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.18, alpha: 1))!.draw(in: leaves, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
        try drawTomato(base * scale).write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    }
}
