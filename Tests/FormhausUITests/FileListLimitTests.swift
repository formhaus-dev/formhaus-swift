import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

@Suite("File list rows and limit", .serialized)
@MainActor
struct FileListLimitTests {
    @Test("every list item with a name gets a row, references by their last path segment")
    func rows() throws {
        let values: JSONValue = ["upload-123", "https://cdn.example.com/a/cv.pdf", ["name": "scan.png"], 5, "", ["id": "x"], "folder/"]
        let form = try receiptsForm(["docs": values])
        form.start()
        let rows = try docsContext(form).fileRows
        #expect(rows.map(\.index) == [0, 1, 2, 6])
        #expect(rows.map(\.name) == ["upload-123", "cv.pdf", "scan.png", "folder/"])
        #expect(rows.allSatisfy { $0.url == nil })
        try docsContext(form).removeFile(at: 1)
        #expect(form.engine.values["docs"] == ["upload-123", ["name": "scan.png"], 5, "", ["id": "x"], "folder/"])
        #expect(form.focusRequest?.key == "docs#remove1")
    }

    @Test("picking stops at maxLength, counting references, drops the rest and shows the limit until a removal")
    func limit() async throws {
        let form = try receiptsForm(["docs": ["upload-1"]], validation: ["maxLength": 2])
        form.start()
        let urls = try await pickedCopies(form, ["a.pdf", "b.pdf", "c.pdf"])
        #expect(try docsContext(form).fileRoom == 1)
        try docsContext(form).receiveFiles(urls)
        #expect(form.engine.values["docs"] == ["upload-1", .string(urls[0].absoluteString)])
        #expect(urls.dropFirst().allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(try docsContext(form).isFileListFull)
        #expect(form.engine.validate().isEmpty)
        #expect(form.field("docs").notice == "At most 2 allowed")
        #expect(form.focusRequest?.key == "docs#remove1")
        try docsContext(form).removeFile(at: 0)
        #expect(form.field("docs").notice == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("the limit message resolves like the maxItems validation message", arguments: [nil, "Up to {max} receipts"] as [String?])
    func message(custom: String?) throws {
        var validation: JSONObject = ["maxLength": 2]
        if let custom { validation["maxLengthMessage"] = .string(custom) }
        let form = try receiptsForm(validation: validation)
        let field = try docsContext(form).field
        #expect(form.engine.fileLimit(field).count == 2)
        #expect(form.engine.fileLimit(field).message == custom ?? "At most 2 allowed")
        #expect(validateFieldValue(field, ["a", "b", "c"], [:]) == custom ?? "At most 2 allowed")
    }

    @Test("without maxLength a list holds 100 files and never more than 1000", arguments: [(nil, 100), (5000, 1000)] as [(Int?, Int)])
    func ceiling(maxLength: Int?, count: Int) throws {
        let form = try receiptsForm(validation: maxLength.map { ["maxLength": .number(Double($0))] } ?? [:])
        #expect(form.engine.fileLimit(try docsContext(form).field).count == count)
    }

    @Test("gallery: empty, chosen files with a reference, full and an error in both sets")
    func gallery() async throws {
        let empty = try receiptsForm()
        let filled = try receiptsForm(["docs": ["https://cdn.example.com/uploads/contract.pdf"]])
        try docsContext(filled).receiveFiles(
            try await pickedCopies(filled, ["receipt-march.pdf", "a-very-long-hotel-invoice-name-2026.pdf"]))
        let full = try receiptsForm(validation: ["maxLength": 2])
        try docsContext(full).receiveFiles(try await pickedCopies(full, ["one.pdf", "two.pdf", "three.pdf"]))
        let invalid = try receiptsForm()
        await invalid.submit()
        let rows = [("empty", empty), ("files", filled), ("full", full), ("error", invalid)]
        try renderGallery("file-list", GallerySheet(title: "file list", rows: rows))
        try renderSystem("file-list", filled, height: 460)
        try renderSystem("file-list-full", full, height: 400)
        for form in [filled, full] { UploadStore.release(owner: ObjectIdentifier(form)) }
    }
}
