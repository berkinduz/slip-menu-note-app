import AppKit
import CoreText
import SlipCore

/// Keeps Markdown in the text storage while suppressing its presentation glyphs.
final class MarkdownGlyphLayout: NSLayoutManager, NSLayoutManagerDelegate {
    private(set) var presentation = MarkdownPresentation(source: "")
    var taskCheckColor: NSColor = .textBackgroundColor

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    /// Apply to replacement ranges. Checkbox fonts reserve horizontal space without changing line height.
    static func fontForReplacement(_ text: String, basedOn font: NSFont) -> NSFont {
        guard let character = text.utf16.first else { return font }
        var scalar = UniChar(character)
        var glyph: CGGlyph = 0
        let hasGlyph = CTFontGetGlyphsForCharacters(font as CTFont, &scalar, &glyph, 1) && glyph != 0
        let checkbox = text == "☐" || text == "☑"
        let base = checkbox ? (NSFont(name: "Apple Symbols", size: font.pointSize) ?? font) : (hasGlyph ? font : (NSFont(name: "Apple Symbols", size: font.pointSize) ?? font))
        guard checkbox else { return base }
        guard CTFontGetGlyphsForCharacters(base as CTFont, &scalar, &glyph, 1), glyph != 0 else { return base }
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(base as CTFont, .horizontal, &glyph, &advance, 1)
        guard advance.width > 0 else { return base }
        let width = max(advance.width, font.pointSize * 1.2)
        var transform = AffineTransform()
        transform.scale(x: font.pointSize * width / advance.width, y: font.pointSize)
        return NSFont(descriptor: base.fontDescriptor, textTransform: transform) ?? base
    }

    func update(presentation: MarkdownPresentation) {
        self.presentation = presentation
        guard let textStorage else { return }
        let range = NSRange(location: 0, length: textStorage.length)
        invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
        invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let textStorage else { return }
        for span in presentation.spans where span.style == .rule && span.range.location < textStorage.length {
            let glyphRange = glyphRange(forCharacterRange: span.range, actualCharacterRange: nil)
            guard glyphRange.length > 0,
                  let container = textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil) else { continue }
            let endOfRule = NSMaxRange(span.range)
            let line: NSRect
            var anchorGlyph = glyphRange.location
            let text = textStorage.string as NSString
            if endOfRule < text.length && (text.character(at: endOfRule) == 10 || text.character(at: endOfRule) == 13) {
                anchorGlyph = glyphIndexForCharacter(at: endOfRule)
                line = lineFragmentRect(forGlyphAt: anchorGlyph, effectiveRange: nil)
            } else if endOfRule == textStorage.length, extraLineFragmentTextContainer === container,
                      !extraLineFragmentRect.isEmpty {
                line = extraLineFragmentRect
            } else {
                line = lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            }
            guard NSIntersectionRange(glyphRange, glyphsToShow).length > 0 ||
                    NSLocationInRange(anchorGlyph, glyphsToShow) else { continue }
            let padding = container.lineFragmentPadding
            let x = origin.x + line.minX + padding
            let end = origin.x + line.maxX - padding
            guard end > x else { continue }
            let color = textStorage.attribute(.foregroundColor, at: span.range.location, effectiveRange: nil) as? NSColor ?? .labelColor
            color.withAlphaComponent(0.35).setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1
            path.move(to: NSPoint(x: x, y: origin.y + line.midY))
            path.line(to: NSPoint(x: end, y: origin.y + line.midY))
            path.stroke()
        }
    }

    /// Checkbox bounds in the text container's coordinate system.
    func taskCheckboxRect(for replacement: MarkdownPresentation.Replacement, in textContainer: NSTextContainer) -> NSRect {
        guard let storage = textStorage, replacement.taskChecked != nil,
              replacement.range.location < storage.length else { return .zero }
        let glyph = glyphIndexForCharacter(at: replacement.range.location)
        guard self.textContainer(forGlyphAt: glyph, effectiveRange: nil) === textContainer else { return .zero }
        let fragment = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let location = self.location(forGlyphAt: glyph)
        var x = fragment.minX + location.x
        let font = storage.attribute(.font, at: replacement.range.location, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: 14)
        var side = min(font.pointSize, fragment.height - 2)
        // Preserve at least five points between the box and the following text.
        let source = storage.string as NSString
        var next = NSMaxRange(replacement.range)
        while next < source.length && (source.character(at: next) == 32 || source.character(at: next) == 9) { next += 1 }
        if next < source.length && source.character(at: next) != 10 && source.character(at: next) != 13 {
            let nextGlyph = glyphIndexForCharacter(at: next)
            if self.textContainer(forGlyphAt: nextGlyph, effectiveRange: nil) === textContainer {
                let nextLine = lineFragmentRect(forGlyphAt: nextGlyph, effectiveRange: nil)
                if nextLine.minY == fragment.minY {
                    let nextX = nextLine.minX + self.location(forGlyphAt: nextGlyph).x
                    if nextX > x {
                        side = min(side, max(0, nextX - x - 5))
                    } else if nextX < x {
                        // In right-to-left text, the visually nearest character can be
                        // the last logical character on the line.
                        let lineEnd = NSMaxRange(source.lineRange(for: NSRange(location: next, length: 0)))
                        var index = next
                        var rightEdge = nextX
                        while index < lineEnd {
                            let character = source.rangeOfComposedCharacterSequence(at: index)
                            let value = source.substring(with: character)
                            if value.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil {
                                let range = glyphRange(forCharacterRange: character, actualCharacterRange: nil)
                                if range.length > 0,
                                   self.textContainer(forGlyphAt: range.location, effectiveRange: nil) === textContainer,
                                   lineFragmentRect(forGlyphAt: range.location, effectiveRange: nil).minY == fragment.minY {
                                    rightEdge = max(rightEdge, boundingRect(forGlyphRange: range, in: textContainer).maxX)
                                }
                            }
                            index = NSMaxRange(character)
                        }
                        let rightLimit = fragment.maxX - textContainer.lineFragmentPadding - side
                        x = min(max(x, rightEdge + 5), rightLimit)
                    }
                }
            }
        }
        return NSRect(x: x, y: fragment.midY - side / 2, width: side, height: side)
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        let tasks = presentation.replacements.filter { $0.taskChecked != nil }
        guard !tasks.isEmpty else { super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin); return }
        var segmentStart = glyphsToShow.location
        for glyph in glyphsToShow.location..<NSMaxRange(glyphsToShow) {
            let character = characterIndexForGlyph(at: glyph)
            guard tasks.contains(where: { NSLocationInRange(character, $0.range) }) else { continue }
            if glyph > segmentStart {
                super.drawGlyphs(forGlyphRange: NSRange(location: segmentStart, length: glyph - segmentStart), at: origin)
            }
            segmentStart = glyph + 1
        }
        if segmentStart < NSMaxRange(glyphsToShow) {
            super.drawGlyphs(forGlyphRange: NSRange(location: segmentStart, length: NSMaxRange(glyphsToShow) - segmentStart), at: origin)
        }
        guard let storage = textStorage else { return }
        for task in tasks where task.range.location < storage.length {
            let glyph = glyphIndexForCharacter(at: task.range.location)
            guard NSLocationInRange(glyph, glyphsToShow),
                  let container = textContainer(forGlyphAt: glyph, effectiveRange: nil) else { continue }
            var box = taskCheckboxRect(for: task, in: container)
            guard !box.isEmpty else { continue }
            box.origin.x += origin.x; box.origin.y += origin.y
            let color = storage.attribute(.foregroundColor, at: task.range.location, effectiveRange: nil) as? NSColor ?? .labelColor
            NSGraphicsContext.saveGraphicsState()
            let outline = NSBezierPath(roundedRect: box.insetBy(dx: 0.65, dy: 0.65), xRadius: max(2, box.width * 0.18), yRadius: max(2, box.width * 0.18))
            outline.lineWidth = 1.3
            color.setStroke()
            if task.taskChecked == true { color.setFill(); outline.fill() }
            outline.stroke()
            if task.taskChecked == true {
                taskCheckColor.setStroke()
                let check = NSBezierPath()
                check.lineWidth = max(1.3, box.width * 0.115)
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                let flipped = NSGraphicsContext.current?.isFlipped ?? true
                func y(_ value: CGFloat) -> CGFloat { box.minY + box.height * (flipped ? value : 1 - value) }
                check.move(to: NSPoint(x: box.minX + box.width * 0.23, y: y(0.53)))
                check.line(to: NSPoint(x: box.minX + box.width * 0.43, y: y(0.72)))
                check.line(to: NSPoint(x: box.minX + box.width * 0.78, y: y(0.30)))
                check.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes: UnsafePointer<Int>, font: NSFont, forGlyphRange glyphRange: NSRange) -> Int {
        var values = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
        var properties = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
        let indexes = Array(UnsafeBufferPointer(start: characterIndexes, count: glyphRange.length))
        var changed = false
        for i in 0..<glyphRange.length {
            let index = indexes[i]
            if presentation.hiddenRanges.contains(where: { NSLocationInRange(index, $0) }) {
                properties[i] = .null
                changed = true
            } else if let replacement = presentation.replacements.first(where: { NSLocationInRange(index, $0.range) }) {
                if index == replacement.range.location, let scalar = replacement.text.utf16.first {
                    var character = UniChar(scalar)
                    var glyph: CGGlyph = 0
                    CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1)
                    values[i] = glyph
                } else {
                    properties[i] = .null
                }
                changed = true
            }
        }
        guard changed else { return 0 }
        layoutManager.setGlyphs(&values, properties: &properties, characterIndexes: indexes, font: font, forGlyphRange: glyphRange)
        return glyphRange.length
    }
}
