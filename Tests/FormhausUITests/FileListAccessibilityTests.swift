import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

@Suite("File list accessibility", .serialized)
@MainActor
struct FileListAccessibilityTests {
    @Test("the remove label isolates the file name")
    func removeLabel() throws {
        let form = try receiptsForm(["docs": ["a"]])
        form.start()
        let context = try docsContext(form)
        #expect(context.removeFileName("scan.pdf") == "Remove \u{2068}scan.pdf\u{2069}")
        #expect(isolatedFileName("x") == "\u{2068}x\u{2069}")
    }

    @Test("a full list adds the limit to the picker hint")
    func fullHint() throws {
        let form = try receiptsForm(["docs": ["a", "b"]], validation: ["maxLength": 2])
        form.start()
        let context = try docsContext(form)
        #expect(context.isFileListFull)
        #expect(context.pickerHint == "At most 2 allowed")
        #expect(context.fileValueText == "Files: 2")
    }

    @Test("a list with room has no limit hint")
    func roomHint() throws {
        let form = try receiptsForm(["docs": ["a"]], validation: ["maxLength": 2])
        form.start()
        #expect(try docsContext(form).pickerHint == nil)
    }

    @Test("added and removed announcements isolate names and focus targets the Remove button")
    func focusTargets() async throws {
        let form = try receiptsForm(validation: ["maxLength": 1])
        form.start()
        let urls = try await pickedCopies(form, ["a.pdf"])
        let context = try docsContext(form)
        context.receiveFiles(urls)
        #expect(form.focusRequest?.key == "docs#remove0")
        context.removeFile(at: 0)
        #expect(form.focusRequest?.key == "docs")
        UploadStore.release(owner: ObjectIdentifier(form))
    }
}
