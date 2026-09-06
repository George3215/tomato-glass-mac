// Native adaptation of the Internal Beyond gw-ripple simulation.
// Required Notice: Copyright © 2025–2026 Sui.
// Internal Beyond (https://github.com/Sui-IB/InternalBeyond)
// PolyForm Noncommercial 1.0.0; see Resources/Licenses/InternalBeyond-CODE.md.
// Changes: Swift/AppKit port, native pointer coordinates and fixed 30 Hz rendering.
import AppKit

final class RippleWater {
    let width: Int
    let height: Int
    private let renderWidth: Int
    private let renderHeight: Int
    private var current: [Float]
    private var previous: [Float]
    private let source: [UInt8]
    private let output: NSBitmapImageRep
    private var time: Float = 0
    private var rainTime: Double = 0.5
    private var ambientTime: Double = 2
    private struct Drop { var x: Double; var y: Double; let target: Double; let speed: Double; let strength: Float }
    private var drops: [Drop] = []
    private(set) var frame: NSImage?

    init?(image: NSImage, size: NSSize) {
        guard size.width > 0, size.height > 0, image.size.width > 0, image.size.height > 0 else { return nil }
        width = min(320, max(150, Int(size.width / 4)))
        height = max(80, Int(Double(width) * size.height / size.width))
        renderWidth = width * 4
        renderHeight = height * 4
        current = .init(repeating: 0, count: width * height)
        previous = current
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: renderWidth, pixelsHigh: renderHeight,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: renderWidth * 4, bitsPerPixel: 32),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        output = bitmap
        let reusableFrame = NSImage(size: NSSize(width: renderWidth, height: renderHeight))
        reusableFrame.cacheMode = .never
        reusableFrame.addRepresentation(bitmap)
        frame = reusableFrame
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let scale = max(CGFloat(renderWidth)/image.size.width, CGFloat(renderHeight)/image.size.height)
        image.draw(in: NSRect(x: (CGFloat(renderWidth)-image.size.width*scale)/2,
            y: (CGFloat(renderHeight)-image.size.height*scale)/2, width: image.size.width*scale, height: image.size.height*scale))
        NSGraphicsContext.restoreGraphicsState()
        source = Array(UnsafeBufferPointer(start: bitmap.bitmapData!, count: renderWidth * renderHeight * 4))
        poke(x: Double(width) * 0.48, y: Double(height) * 0.55, strength: 1.2, radius: 3)
    }

    func poke(x: Double, y: Double, strength: Float = 2, radius: Double = 2.8) {
        let cx = Int(x), cy = Int(y), r = Int(ceil(radius))
        for dy in -r...r {
            for dx in -r...r {
                let px = cx + dx, py = cy + dy
                guard px > 0, py > 0, px < width-1, py < height-1 else { continue }
                let f = Double(dx*dx + dy*dy) / (radius*radius)
                if f <= 1 { current[py*width+px] += strength * Float(0.5 + 0.5*cos(.pi*sqrt(f))) }
            }
        }
    }

    func advance() {
        let dt = 1.0 / 30
        time += Float(dt)
        rainTime -= dt
        ambientTime -= dt
        if rainTime <= 0 {
            rainTime = Double.random(in: 0.9...2.4)
            let target = Double.random(in: 2...Double(height-3))
            let fall = Double(height) * Double.random(in: 0.34...0.52)
            drops.append(Drop(x: Double.random(in: 2...Double(width-3)), y: target-fall,
                target: target, speed: fall/Double.random(in: 0.3...0.42), strength: Float.random(in: 0.8...1.5)))
        }
        if ambientTime <= 0 {
            ambientTime = Double.random(in: 2.5...5.5)
            poke(x: Double.random(in: 2...Double(width-3)), y: Double.random(in: 2...Double(height-3)), strength: 0.4, radius: 3)
        }
        for i in drops.indices.reversed() {
            drops[i].y += drops[i].speed * dt
            if drops[i].y >= drops[i].target {
                let drop = drops.remove(at: i)
                poke(x: drop.x, y: drop.target, strength: drop.strength*1.15, radius: 1.6)
                poke(x: drop.x, y: drop.target, strength: -drop.strength*0.4, radius: 3.2)
            }
        }
        for y in 1..<height-1 {
            for x in 1..<width-1 {
                let i = y*width+x
                previous[i] = ((current[i-1]+current[i+1]+current[i-width]+current[i+width])*0.5-previous[i])*0.9855
                    + 0.0024*sin(time*0.7+Float(x)*0.05+Float(y)*0.021)
                    + 0.0019*sin(time*0.43-Float(x)*0.023+Float(y)*0.041)
            }
        }
        swap(&current, &previous)
        let dst = output.bitmapData!
        for y in 0..<renderHeight {
            let wy = min(height-1,y/4)
            for x in 0..<renderWidth {
                let wx = min(width-1,x/4)
                let gx = current[wy*width+max(0,wx-1)]-current[wy*width+min(width-1,wx+1)]
                let gy = current[max(0,wy-1)*width+wx]-current[min(height-1,wy+1)*width+wx]
                let sx = min(renderWidth-1,max(0,Int(Float(x)+gx*8)))
                let sy = min(renderHeight-1,max(0,Int(Float(y)+gy*8)))
                let offset = (sy*renderWidth+sx)*4
                let destination = (y*renderWidth+x)*4
                for channel in 0..<3 {
                    let shade = gy * (channel == 2 ? 12.5 : 10)
                    dst[destination+channel] = UInt8(min(255,max(0,Float(source[offset+channel])+shade)))
                }
                dst[destination+3] = 255
            }
        }

    }

    func draw(in bounds: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        output.draw(in: bounds)
        NSColor.white.withAlphaComponent(0.6).setStroke()
        for drop in drops {
            let x = drop.x/Double(width)*bounds.width
            let y = bounds.height-drop.y/Double(height)*bounds.height
            let line = NSBezierPath()
            line.move(to: NSPoint(x: x, y: y))
            line.line(to: NSPoint(x: x-1, y: y+18))
            line.lineWidth = 1
            line.stroke()
        }
    }
}
