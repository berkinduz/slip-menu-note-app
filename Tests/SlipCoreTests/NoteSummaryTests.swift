import Testing
import SlipCore

@Suite("Readable note summaries")
struct NoteSummaryTests {
    @Test("An untitled note preview continues after its inferred title")
    func inferredTitlePreview() {
        let note = Note(body: "## Next steps\n\nSend **the update** and ==keep it short==.")
        #expect(note.displayTitle == "Next steps")
        #expect(note.excerpt == "Send the update and keep it short.")
        #expect(note.wordCount == 9)
        #expect(Note(body: "A quick single line").excerpt.isEmpty)
        #expect(Note(body: "## Plan\n- [ ] Send update\n## Later\n- [x] File notes").excerpt == "Send update Later File notes")
        #expect(Note(title: "An explicit title", body: "Keep the first body line").excerpt == "Keep the first body line")
    }
}
