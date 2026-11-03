import AppKit

enum SlipMarkImage {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Slip"
        return image
    }

    static func draw(in rect: NSRect, ink: NSColor = .black, accent: NSColor? = nil) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 20, yBy: rect.height / 20)
        transform.concat()

        let rail = NSBezierPath()
        rail.move(to: NSPoint(x: 1.8, y: 17.5))
        rail.line(to: NSPoint(x: 6.9, y: 17.5))
        rail.move(to: NSPoint(x: 12.5, y: 17.5))
        rail.line(to: NSPoint(x: 18.2, y: 17.5))
        rail.lineWidth = 1.7
        rail.lineCapStyle = .round
        (accent == nil ? ink : ink.withAlphaComponent(0.52)).setStroke()
        rail.stroke()
        (accent ?? ink).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8.85, y: 16.65, width: 1.7, height: 1.7)).fill()

        let note = NSBezierPath()
        note.move(to: NSPoint(x: 5.8, y: 13.2))
        note.line(to: NSPoint(x: 8, y: 13.2))
        note.line(to: NSPoint(x: 9.45, y: 14.65))
        note.curve(to: NSPoint(x: 10.3, y: 14.3), controlPoint1: NSPoint(x: 9.75, y: 14.95), controlPoint2: NSPoint(x: 10.3, y: 14.75))
        note.line(to: NSPoint(x: 10.3, y: 13.2))
        note.line(to: NSPoint(x: 14.2, y: 13.2))
        note.curve(to: NSPoint(x: 15.8, y: 11.6), controlPoint1: NSPoint(x: 15.25, y: 13.2), controlPoint2: NSPoint(x: 15.8, y: 12.65))
        note.line(to: NSPoint(x: 15.8, y: 3.4))
        note.curve(to: NSPoint(x: 14.2, y: 1.8), controlPoint1: NSPoint(x: 15.8, y: 2.35), controlPoint2: NSPoint(x: 15.25, y: 1.8))
        note.line(to: NSPoint(x: 5.8, y: 1.8))
        note.curve(to: NSPoint(x: 4.2, y: 3.4), controlPoint1: NSPoint(x: 4.75, y: 1.8), controlPoint2: NSPoint(x: 4.2, y: 2.35))
        note.line(to: NSPoint(x: 4.2, y: 11.6))
        note.curve(to: NSPoint(x: 5.8, y: 13.2), controlPoint1: NSPoint(x: 4.2, y: 12.65), controlPoint2: NSPoint(x: 4.75, y: 13.2))
        note.close()
        note.lineWidth = 1.6
        note.lineJoinStyle = .round
        ink.setStroke()
        note.stroke()

        let binding = NSBezierPath()
        binding.move(to: NSPoint(x: 7, y: 4.1))
        binding.line(to: NSPoint(x: 7, y: 10.7))
        binding.lineWidth = 1.15
        binding.lineCapStyle = .round
        (accent == nil ? ink : ink.withAlphaComponent(0.52)).setStroke()
        binding.stroke()

        let lines = NSBezierPath()
        lines.move(to: NSPoint(x: 9.3, y: 9.1))
        lines.line(to: NSPoint(x: 13.1, y: 9.1))
        lines.move(to: NSPoint(x: 9.3, y: 5.9))
        lines.line(to: NSPoint(x: 12.1, y: 5.9))
        lines.lineWidth = 1.55
        lines.lineCapStyle = .round
        (accent ?? ink).setStroke()
        lines.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
