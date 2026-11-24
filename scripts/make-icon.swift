import AppKit

// The vector drawing is the canonical icon source. Raster sizes and ICNS are generated.
func sparkle(center: NSPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let x = center.x, y = center.y, r = radius
    path.move(to: NSPoint(x: x, y: y + r))
    path.curve(to: NSPoint(x: x + r, y: y), controlPoint1: NSPoint(x: x + r * 0.18, y: y + r * 0.22), controlPoint2: NSPoint(x: x + r * 0.22, y: y + r * 0.18))
    path.curve(to: NSPoint(x: x, y: y - r), controlPoint1: NSPoint(x: x + r * 0.22, y: y - r * 0.18), controlPoint2: NSPoint(x: x + r * 0.18, y: y - r * 0.22))
    path.curve(to: NSPoint(x: x - r, y: y), controlPoint1: NSPoint(x: x - r * 0.18, y: y - r * 0.22), controlPoint2: NSPoint(x: x - r * 0.22, y: y - r * 0.18))
    path.curve(to: NSPoint(x: x, y: y + r), controlPoint1: NSPoint(x: x - r * 0.22, y: y + r * 0.18), controlPoint2: NSPoint(x: x - r * 0.18, y: y + r * 0.22))
    path.close()
    return path
}
func render(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.63, blue: 0.47, alpha: 1), ending: NSColor(srgbRed: 0.035, green: 0.26, blue: 0.25, alpha: 1))!.draw(in: tile, angle: -65)
    let inner = NSBezierPath(roundedRect: NSRect(x: 77, y: 77, width: 870, height: 870), xRadius: 190, yRadius: 190)
    NSColor.white.withAlphaComponent(0.12).setStroke(); inner.lineWidth = 2; inner.stroke()
    NSColor(srgbRed: 0.94, green: 0.99, blue: 0.89, alpha: 1).setFill()
    sparkle(center: NSPoint(x: 464, y: 474), radius: 248).fill()
    sparkle(center: NSPoint(x: 727, y: 726), radius: 91).fill()
    NSColor.white.withAlphaComponent(0.75).setFill()
    sparkle(center: NSPoint(x: 299, y: 767), radius: 42).fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: url, options: .atomic)
}

guard CommandLine.arguments.count == 2 else { fatalError("Usage: make-icon.swift OUTPUT.iconset") }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    try render(size: pixels, to: output.appendingPathComponent(name + ".png"))
}
