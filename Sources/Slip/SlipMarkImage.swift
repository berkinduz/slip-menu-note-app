import AppKit

enum SlipMarkImage {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        draw(in: NSRect(x: 0, y: 0, width: 20, height: 20))
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "slip"
        return image
    }

    static func draw(in rect: NSRect, ink: NSColor = .black, accent: NSColor? = nil) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 20, yBy: rect.height / 20)
        transform.concat()

        let paper = NSBezierPath()
        paper.move(to: NSPoint(x: 4, y: 2.5))
        paper.line(to: NSPoint(x: 10, y: 2.5))
        paper.move(to: NSPoint(x: 14, y: 8))
        paper.line(to: NSPoint(x: 14, y: 13))
        paper.line(to: NSPoint(x: 10, y: 17))
        paper.line(to: NSPoint(x: 4, y: 17))
        paper.curve(to: NSPoint(x: 2, y: 15), controlPoint1: NSPoint(x: 2.8, y: 17), controlPoint2: NSPoint(x: 2, y: 16.2))
        paper.line(to: NSPoint(x: 2, y: 4.5))
        paper.curve(to: NSPoint(x: 4, y: 2.5), controlPoint1: NSPoint(x: 2, y: 3.3), controlPoint2: NSPoint(x: 2.8, y: 2.5))
        paper.move(to: NSPoint(x: 10, y: 17))
        paper.line(to: NSPoint(x: 10, y: 13))
        paper.line(to: NSPoint(x: 14, y: 13))
        paper.move(to: NSPoint(x: 5, y: 10))
        paper.line(to: NSPoint(x: 8, y: 10))
        paper.move(to: NSPoint(x: 5, y: 7))
        paper.line(to: NSPoint(x: 7, y: 7))
        paper.lineWidth = 1.4
        paper.lineCapStyle = .round
        paper.lineJoinStyle = .round
        ink.setStroke()
        paper.stroke()

        let pencil = NSBezierPath()
        pencil.move(to: NSPoint(x: 9, y: 2))
        pencil.line(to: NSPoint(x: 10, y: 5.2))
        pencil.line(to: NSPoint(x: 16.4, y: 11.6))
        pencil.curve(to: NSPoint(x: 18.3, y: 9.7), controlPoint1: NSPoint(x: 17.6, y: 12.8), controlPoint2: NSPoint(x: 19.5, y: 10.9))
        pencil.line(to: NSPoint(x: 11.9, y: 3.3))
        pencil.close()
        (accent ?? ink).setFill()
        pencil.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
