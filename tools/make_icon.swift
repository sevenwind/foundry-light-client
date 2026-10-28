import AppKit
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let bg = NSBezierPath(roundedRect: NSRect(x: s*0.06, y: s*0.06, width: s*0.88, height: s*0.88), xRadius: s*0.2, yRadius: s*0.2)
    NSGradient(colors: [NSColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1), NSColor(red: 0.75, green: 0.2, blue: 0.1, alpha: 1)])!.draw(in: bg, angle: -60)
    // Шестиугольник, как грань d20
    let hex = NSBezierPath()
    for i in 0..<6 {
        let a = CGFloat(i) * .pi / 3 + .pi / 6
        let p = NSPoint(x: s*0.5 + cos(a) * s*0.3, y: s*0.5 + sin(a) * s*0.3)
        i == 0 ? hex.move(to: p) : hex.line(to: p)
    }
    hex.close()
    NSColor.white.setFill(); hex.fill()
    let font = NSFont.systemFont(ofSize: s*0.28, weight: .heavy)
    let str = NSAttributedString(string: "F", attributes: [.font: font, .foregroundColor: NSColor(red: 0.75, green: 0.2, blue: 0.1, alpha: 1)])
    let size = str.size()
    str.draw(at: NSPoint(x: (s - size.width)/2, y: (s - size.height)/2))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for (n, px) in [("16",16),("16@2x",32),("32",32),("32@2x",64),("128",128),("128@2x",256),("256",256),("256@2x",512),("512",512),("512@2x",1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(n.replacingOccurrences(of: "@2x", with: "x2")).png"))
}
