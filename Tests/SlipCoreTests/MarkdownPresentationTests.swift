import Foundation
import XCTest
@testable import SlipCore

final class MarkdownPresentationTests: XCTestCase {
    func testCommonAlternateAndCombinedEmphasisIsFullyHidden() {
        for source in ["__bold__", "***both***", "___both___"] {
            let presentation = MarkdownPresentation(source: source)
            let visible = presentation.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length))
            XCTAssertEqual(visible, source == "__bold__" ? "bold" : "both")
            XCTAssertTrue(presentation.spans.contains { $0.style == .strong })
            if source != "__bold__" { XCTAssertTrue(presentation.spans.contains { $0.style == .emphasis }) }
        }
    }

    func testCompletedFormattingProjectsVisibleTextWithoutChangingSource() {
        let source = "**bold _nested_** and ~~old~~ `**code**` [link](https://x) 😀"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "bold nested and old **code** link 😀")
        XCTAssertTrue(p.spans.contains { $0.style == .strong })
        XCTAssertTrue(p.spans.contains { $0.style == .emphasis })
        XCTAssertTrue(p.spans.contains { $0.style == .link(destination: "https://x") })
    }

    func testEscapedIncompleteAndFencedContentRemainsLiteral() {
        let source = "\\**literal** and **open\n```\n**code**\n```\n"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "\\**literal** and **open\n**code**\n")
    }

    func testBackspaceAtClosingDelimiterDeletesOneVisibleCharacter() {
        let source = "**hi😀**"
        let p = MarkdownPresentation(source: source)
        let edit = p.backwardDeletion(in: source, selection: NSRange(location: (source as NSString).length, length: 0))
        XCTAssertEqual(edit?.applying(to: source), "**hi**")
    }
    func testNestedInlineCodeKeepsOuterStrong() {
        let source = "**a `*code*` b**"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "a *code* b")
        XCTAssertTrue(p.spans.contains { $0.style == .strong })
    }

    func testBackspaceLastFormattedCharacterRemovesEmptyMarkers() {
        let source = "**a**"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.backwardDeletion(in: source, selection: NSRange(location: 5, length: 0))?.applying(to: source), "")
    }

    func testMismatchedFenceDoesNotEndCodeBlock() {
        let source = "```swift\n~~~\n**literal**\n```"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "~~~\n**literal**\n")
    }

    func testEmptyHeadingPrefixIsHidden() {
        let p = MarkdownPresentation(source: "# ")
        XCTAssertEqual(p.visibleText(in: "# ", range: NSRange(location: 0, length: 2)), "")
    }

    func testCaretMovesOneVisibleGraphemeAcrossMarkers() {
        let source = "**bold**"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.movingCaret(in: source, from: 8, direction: -1), 5)
        XCTAssertEqual(p.movingCaret(in: source, from: 0, direction: 1), 3)
        let emoji = "**😀x**"
        let ep = MarkdownPresentation(source: emoji)
        XCTAssertEqual(ep.movingCaret(in: emoji, from: 0, direction: 1), 4)
        XCTAssertEqual(ep.movingCaret(in: emoji, from: 4, direction: -1), 2)
    }

    func testCaretMovesAcrossWholeTaskReplacement() {
        let source = "- [ ] item"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.movingCaret(in: source, from: 0, direction: 1), 5)
        XCTAssertEqual(p.movingCaret(in: source, from: 5, direction: -1), 0)
    }

    func testDeletingSelectedFormattedContentRemovesItsMarkers() {
        let source = "before **bold** after"
        let p = MarkdownPresentation(source: source)
        let selection = NSRange(location: 9, length: 4)
        XCTAssertEqual(p.backwardDeletion(in: source, selection: selection)?.applying(to: source), "before  after")
        XCTAssertNil(p.backwardDeletion(in: source, selection: NSRange(location: 10, length: 2)))
    }

    func testForwardDeletionSkipsOpeningMarkersAndDeletesGrapheme() {
        let source = "**😀hi**"
        let p = MarkdownPresentation(source: source)
        let edit = p.forwardDeletion(in: source, selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(edit?.applying(to: source), "**hi**")
        XCTAssertEqual(edit?.selection, NSRange(location: 2, length: 0))
        XCTAssertNil(p.forwardDeletion(in: source, selection: NSRange(location: 2, length: 0)))
    }

    func testForwardDeletionOfLastCharacterRemovesEmptyMarkers() {
        let source = "**😀**"
        let p = MarkdownPresentation(source: source)
        let edit = p.forwardDeletion(in: source, selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(edit?.applying(to: source), "")
        XCTAssertEqual(edit?.selection, NSRange(location: 0, length: 0))
    }

    func testDeletingListReplacementRemovesWholePrefixAndGap() {
        for source in ["- [ ] item", "- item"] {
            let p = MarkdownPresentation(source: source)
            let end = NSMaxRange(p.replacements[0].range)
            XCTAssertEqual(p.backwardDeletion(in: source, selection: NSRange(location: end, length: 0))?.applying(to: source), "item")
            XCTAssertEqual(p.forwardDeletion(in: source, selection: NSRange(location: 0, length: 0))?.applying(to: source), "item")
        }
    }

    func testDeletingOnlyFormattedCharacterFromContentBoundary() {
        let source = "**a**"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.backwardDeletion(in: source, selection: NSRange(location: 3, length: 0))?.applying(to: source), "")
        XCTAssertEqual(p.forwardDeletion(in: source, selection: NSRange(location: 2, length: 0))?.applying(to: source), "")
    }

    func testBackspaceAtBlockContentStartRemovesWholePrefix() {
        for source in ["# title", "> title"] {
            let p = MarkdownPresentation(source: source)
            XCTAssertEqual(p.backwardDeletion(in: source, selection: NSRange(location: 2, length: 0))?.applying(to: source), "title")
        }
    }

    func testHorizontalRulesAreProjectedWithoutSourceMarkers() {
        for marker in ["---", "***", "___", "  - - -  ", "* * *"] {
            let source = "before\n" + marker + "\nafter"
            let p = MarkdownPresentation(source: source)
            XCTAssertTrue(p.spans.contains { $0.style == .rule }, marker)
            XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "before\n\nafter")
        }
    }

    func testRuleBoundariesDeleteTheWholeMarker() {
        let source = "before\n---\nafter"
        let p = MarkdownPresentation(source: source)
        XCTAssertEqual(p.backwardDeletion(in: source, selection: NSRange(location: 10, length: 0))?.applying(to: source), "before\n\nafter")
        XCTAssertEqual(p.forwardDeletion(in: source, selection: NSRange(location: 7, length: 0))?.applying(to: source), "before\n\nafter")
    }

    func testRuleWithinFenceRemainsLiteral() {
        let source = "```\n---\n```"
        let p = MarkdownPresentation(source: source)
        XCTAssertFalse(p.spans.contains { $0.style == .rule })
        XCTAssertEqual(p.visibleText(in: source, range: NSRange(location: 0, length: (source as NSString).length)), "---\n")
    }

    func testHighlightProjectsEmojiAndIgnoresCodeAndIncompleteMarkers() {
        let source = "😀 ==bright😀== ==open `==code==` [x](https://x/==dest==)\n```\n==literal==\n```"
        let p = MarkdownPresentation(source: source)
        let range = NSRange(location: 0, length: (source as NSString).length)
        XCTAssertEqual(p.visibleText(in: source, range: range), "😀 bright😀 ==open ==code== x\n==literal==\n")
        XCTAssertEqual(p.spans.filter { $0.style == .highlight }.count, 1)
        let emoji = "==😀=="
        let ep = MarkdownPresentation(source: emoji)
        XCTAssertEqual(ep.movingCaret(in: emoji, from: 0, direction: 1), 4)
        XCTAssertEqual(ep.backwardDeletion(in: emoji, selection: NSRange(location: 4, length: 0))?.applying(to: emoji), "")
        XCTAssertEqual(ep.forwardDeletion(in: emoji, selection: NSRange(location: 0, length: 0))?.applying(to: emoji), "")
    }

}
