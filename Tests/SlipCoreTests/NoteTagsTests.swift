import XCTest
import Foundation
@testable import SlipCore

final class NoteTagsTests: XCTestCase {
    func testInlineTagsAndUTF16Ranges() {
        let source = "😀 #Work #work/Ideas #multi word# #work/multi word#"
        let tags = NoteTags.parse(in: source)
        XCTAssertEqual(tags.map(\.name), ["work", "work/ideas", "multi word", "work/multi word"])
        XCTAssertEqual((source as NSString).substring(with: tags[0].range), "#Work")
    }

    func testIgnoresMarkdownCodeDestinationsHeadingsEscapesAndURLs() {
        let source = "# Heading\n\\#escaped `#code` [label](https://x/#fragment) https://x/#url\n```\n#code\n```\n#real"
        XCTAssertEqual(NoteTags.parse(in: source).map(\.name), ["real"])
    }

    func testManualMetadataTagsGroupAndSearchWithoutReadingBody() {
        let note = Note(body: "#unassigned", tags: ["Legacy", "work/ideas"])
        let removed = Note(body: "#gone", deletedAt: .now)
        let library = NoteLibrary(notes: [note, removed])
        XCTAssertEqual(note.allTags, ["legacy", "work/ideas"])
        XCTAssertEqual(library.tags, ["legacy", "work", "work/ideas"])
        XCTAssertEqual(library.filtered(by: .tag("work")).map(\.id), [note.id])
        XCTAssertEqual(library.filtered(by: .all, query: "legacy").map(\.id), [note.id])
        XCTAssertEqual(library.tagTree.map(\.id), ["legacy", "work"])
        XCTAssertEqual(library.tagTree[1].children.map(\.id), ["work/ideas"])
    }

    func testMalformedMetadataCannotCauseRecursiveTree() {
        XCTAssertEqual(TagNode.tree(for: ["/", "good"]).map(\.id), ["good"])
    }

    func testSearchAcceptsClosedMultiwordPartialAndMultipleTags() {
        let note = Note(body: "A useful thought", tags: ["project alpha", "work/ideas"])
        for query in ["#project alpha#", "#work#", "#ide", "#project alpha# #work/ide"] {
            let search = NoteSearchQuery(query)
            XCTAssertTrue(search.matches(note), query)
            XCTAssertEqual(search.text, "", query)
        }
        let search = NoteSearchQuery("#work #project alpha# useful thought")
        XCTAssertEqual(search.tags, ["work", "project alpha"])
        XCTAssertEqual(search.text, "useful thought")
        XCTAssertFalse(NoteSearchQuery("#work #missing").matches(note))
    }

}
