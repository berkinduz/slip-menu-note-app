import AppKit

let size = NSSize(width: 640, height: 400)
let image = NSImage(size: size)

func centeredText(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    let text = text as NSString
    text.draw(at: NSPoint(x: (640 - text.size(withAttributes: attributes).width) / 2, y: y),
              withAttributes: attributes)
}

for scale in [1, 2] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: 640 * scale, pixelsHigh: 400 * scale,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    NSColor(srgbRed: 0.965, green: 0.961, blue: 0.945, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    let ink = NSColor(srgbRed: 0.18, green: 0.18, blue: 0.17, alpha: 1)
    centeredText("Install Slip", y: 318, size: 25, weight: .semibold, color: ink)
    centeredText("Drag Slip to Applications", y: 70, size: 16, weight: .medium, color: ink)

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 286, y: 210))
    arrow.line(to: NSPoint(x: 354, y: 210))
    arrow.move(to: NSPoint(x: 344, y: 220))
    arrow.line(to: NSPoint(x: 354, y: 210))
    arrow.line(to: NSPoint(x: 344, y: 200))
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(srgbRed: 0.60, green: 0.55, blue: 0.44, alpha: 1).setStroke()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(bitmap)
}

try image.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
