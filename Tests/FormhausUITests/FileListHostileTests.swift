import Foundation
import SwiftUI
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

private let hostile: [(Double, Int)] = [(.nan, 100), (.infinity, 100), (-.infinity, 100), (1e300, 1000), (-1e300, 0), (-5, 0), (2.7, 2)]

@Suite("File lists with hostile limits", .serialized)
@MainActor
struct FileListHostileTests {
    private func render(_ form: FormModel, count: Int) throws {
        form.start()
        let field = try docsContext(form)
        #expect(form.engine.fileLimit(field.field).count == count)
        #expect(field.fileRoom == count)
        #expect(field.isFileListFull == (count == 0))
        #expect(field.fileValueText == "Choose file")
        _ = host(FormFields(model: form), width: 393, height: 800)
        _ = host(FormFields(model: form).formhausComponents(.system), width: 393, height: 800)
    }

    @Test("maxLength and minLength values the JSON cannot carry never trap", arguments: hostile)
    func direct(maxLength: Double, count: Int) throws {
        let json = receipts(["maxLength": .number(maxLength), "minLength": .number(-maxLength)]).objectValue ?? [:]
        try render(FormModel(definition: FormDefinition(unchecked: json)) { _, _ in nil }, count: count)
    }

    @Test(
        "decoded limits clamp to 0 through 1000 and infinite ones are rejected",
        arguments: [("1e300", 1000), ("-1e300", 0), ("-5", 0), ("1e400", nil), ("-1e400", nil)] as [(String, Int?)])
    func decoded(literal: String, count: Int?) throws {
        let text = """
            {"formatVersion": "1.7", "id": "r", "title": "R", "submit": {"label": "Send"},
             "fields": [{"key": "docs", "type": "file", "label": "D", "multiple": true,
             "validation": {"maxLength": \(literal), "minLength": \(literal)}}]}
            """
        let json = try JSONValue(parsing: text)
        guard let count else {
            #expect(throws: FormDefinitionError.self) { try FormDefinition(json: json) }
            return
        }
        try render(FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }, count: count)
    }
}
