import AppKit
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
        NSColor(calibratedRed: 0.067, green: 0.075, blue: 0.059, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 210, yRadius: 210).fill()
        let green = NSColor(calibratedRed: 0.84, green: 0.98, blue: 0.51, alpha: 1)
        green.withAlphaComponent(0.6).setStroke()
        for diameter in [740.0, 570.0, 400.0] {
            let ring = NSBezierPath(ovalIn: NSRect(x: (1024-diameter)/2, y: (1024-diameter)/2, width: diameter, height: diameter)); ring.lineWidth = 5; ring.stroke()
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Georgia-Italic", size: 370) ?? NSFont.systemFont(ofSize: 370), .foregroundColor: green]
        let text = "?" as NSString; let measured = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (1024-measured.width)/2, y: (1024-measured.height)/2 + 15), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory).appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
