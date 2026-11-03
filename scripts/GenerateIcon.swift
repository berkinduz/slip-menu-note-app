import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func drawIcon() {
    let background = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -13)
    shadow.shadowBlurRadius = 25
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.set()
    NSColor(srgbRed: 0.095, green: 0.086, blue: 0.086, alpha: 1).setFill()
    background.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(srgbRed: 0.19, green: 0.19, blue: 0.17, alpha: 1), ending: NSColor(srgbRed: 0.075, green: 0.070, blue: 0.070, alpha: 1))!.draw(in: background, angle: -75)
    SlipMarkImage.draw(in: NSRect(x: 182, y: 182, width: 660, height: 660),
                       ink: NSColor(srgbRed: 0.91, green: 0.90, blue: 0.86, alpha: 1),
                       accent: NSColor(srgbRed: 0.77, green: 0.69, blue: 0.52, alpha: 1))
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
    }
}

// ICNS stores PNG representations in a typed, big-endian container.
func bigEndianData(_ value: UInt32) -> Data {
    var number = value.bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var chunks = Data()
for (type, filename) in [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
] {
    let png = try Data(contentsOf: destination.appendingPathComponent(filename))
    chunks.append(Data(type.utf8))
    chunks.append(bigEndianData(UInt32(png.count + 8)))
    chunks.append(png)
}
var container = Data("icns".utf8)
container.append(bigEndianData(UInt32(chunks.count + 8)))
container.append(chunks)
try container.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))


if CommandLine.arguments.count > 3 {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    SlipMarkImage.draw(in: NSRect(x: 0, y: 0, width: 40, height: 40), ink: .white)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
}
