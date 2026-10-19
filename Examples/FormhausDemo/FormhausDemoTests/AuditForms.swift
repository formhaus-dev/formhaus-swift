import FormhausCore
import FormhausUI
import SwiftUI

@testable import FormhausDemo

let rareDefinition: JSONValue = [
    "id": "rare", "title": "Rare", "submit": ["label": "Book"],
    "fields": [
        [
            "key": "plan", "type": "select", "label": "Plan", "validation": ["required": true],
            "options": [["value": "free", "label": "Free"], ["value": "pro", "label": "Pro"]],
        ],
        ["key": "when", "type": "date", "label": "Start date", "validation": ["required": true]],
        ["key": "time", "type": "time", "label": "Arrival"],
        ["key": "cv", "type": "file", "label": "Brief", "accept": ".pdf"],
        ["key": "news", "type": "switch", "label": "Product news"],
        ["key": "agree", "type": "checkbox", "label": "I agree to the terms", "validation": ["required": true]],
        ["key": "notes", "type": "textarea", "label": "Notes"],
        [
            "key": "team", "type": "group", "label": "Team", "itemLabel": "Member {index}", "defaultItems": 2,
            "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["required": true]]],
        ],
    ],
]

struct AuditCase: Sendable {
    let name: String
    let build: @MainActor @Sendable () async throws -> FormModel
}

@MainActor
func demoModel(_ values: JSONObject = [:]) throws -> FormModel {
    let localized = try FormSource(bundle: .main).localized(.english)
    return FormModel(localized: localized, initialValues: values) { _, _ in .ok }
}

let auditCases: [AuditCase] = [
    AuditCase(name: "project-empty") { try demoModel() },
    AuditCase(name: "project-error") {
        let model = try demoModel()
        await model.next()
        return model
    },
    AuditCase(name: "project-filled") {
        try demoModel(["projectType": "redesign", "currentSite": "https://northwind.studio", "siteRating": 4])
    },
    AuditCase(name: "scope-error") {
        let model = try demoModel(["projectType": "new-site"])
        await model.next()
        await model.next()
        return model
    },
    AuditCase(name: "contact-error") {
        let model = try demoModel(["projectType": "landing-page"])
        await model.next()
        await model.submit()
        return model
    },
    AuditCase(name: "rare-error") {
        let model = FormModel(definition: try FormDefinition(json: rareDefinition)) { _, _ in .ok }
        await model.submit()
        return model
    },
]

@MainActor
func auditView(_ model: FormModel, _ style: DemoStyle, typeSize: DynamicTypeSize = .large) -> some View {
    NavigationStack {
        if style == .system {
            FormhausFormContent(model: model)
        } else {
            ScrollView { FormhausFormContent(model: model).padding(16) }
        }
    }
    .formhausComponents(style.components)
    .formhausTheme(style == .brand ? .kiln : .touch)
    .formhausBehavior(FormBehavior(errorSummary: true))
    .environment(\.dynamicTypeSize, typeSize)
}
