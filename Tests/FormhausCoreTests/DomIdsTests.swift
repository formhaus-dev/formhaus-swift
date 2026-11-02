import Foundation
import Testing

@testable import FormhausCore

private let lookalikeDefinition = """
    {"formatVersion":"1.8","id":"f","title":"F","submit":{"label":"S"},"fields":[
    {"key":"plan","type":"radio","label":"Plan","helperText":"Pick",
     "options":[{"value":"a","label":"A","description":"First"},{"value":"b","label":"B"}]},
    {"key":"plan-helper","type":"text","label":"P"},
    {"key":"plan-0-description","type":"text","label":"P"},
    {"key":"plan-description","type":"text","label":"P"},
    {"key":"nps","type":"scale","label":"N","validation":{"min":0,"max":3},"options":[{"value":"0","label":"Low"}]},
    {"key":"nps-3","type":"text","label":"N"},
    {"key":"nps-anchor-1","type":"text","label":"N"},
    {"key":"opts","type":"multiselect","label":"O","optionsFrom":"opts"},
    {"key":"opts-17-description","type":"text","label":"O"},
    {"key":"r","type":"rating","label":"R"},
    {"key":"r-5","type":"text","label":"R"},
    {"key":"crew","type":"group","label":"C",
     "fields":[{"key":"name","type":"text","label":"N"},{"key":"name-error","type":"text","label":"N"}]},
    {"key":"crew-error","type":"text","label":"C"},
    {"key":"crew-confirm","type":"text","label":"C"},
    {"key":"about","type":"section","title":"About","description":"More",
     "fields":[{"key":"city","type":"autocomplete","label":"City","options":[{"value":"x","label":"X"}]}]},
    {"key":"about-description","type":"text","label":"A"},
    {"key":"city-list","type":"text","label":"C"},
    {"key":"k--reveal","type":"text","label":"K"},
    {"key":"k-reveal","type":"text","label":"K"},
    {"key":"docs","type":"file","label":"D","multiple":true},
    {"key":"docs-notice","type":"text","label":"D"},
    {"key":"agree","type":"checkbox","label":"A"},
    {"key":"agree-label","type":"text","label":"A"}
    ]}
    """

private let expected: [(String, String)] = [
    ("plan", "f-plan"), ("plan-helper", "f-plan-helper-1fv3r79"), ("plan-0-description", "f-plan-0-description-dgzwlc"),
    ("plan-description", "f-plan-description-9fqs9t"), ("nps", "f-nps"), ("nps-3", "f-nps-3-p5xz64"),
    ("nps-anchor-1", "f-nps-anchor-1-7mk0uw"), ("opts", "f-opts"), ("opts-17-description", "f-opts-17-description-lnnpop"),
    ("r", "f-r"), ("r-5", "f-r-5-e490n"), ("crew", "f-crew-14v7hiw"), ("crew-error", "f-crew-error"),
    ("crew-confirm", "f-crew-confirm"), ("about", "f-about"), ("city", "f-city"),
    ("about-description", "f-about-description-1qxz0n1"), ("city-list", "f-city-list-1pjeza1"),
    ("k--reveal", "f-k-reveal-12b1uvx"), ("k-reveal", "f-k-reveal"), ("docs", "f-docs"),
    ("docs-notice", "f-docs-notice-1obu5ex"), ("agree", "f-agree"), ("agree-label", "f-agree-label"),
]

@Suite("DOM ids")
struct DomIdsTests {
    @Test("move a field id off the generated ids of another node like the TypeScript core")
    func lookalike() throws {
        let ids = DomIds(try FormDefinition(json: try JSONValue(parsing: Data(lookalikeDefinition.utf8))))
        #expect(expected.map { ids.field("f", $0.0) } == expected.map(\.1))
        #expect(ids.item("f", "crew", 0, "name") == "f-crew-14v7hiw--0--name")
        #expect(ids.item("f", "crew", 0, "name-error") == "f-crew-14v7hiw--0--name-error-11fplyt")
    }

    @Test("collapse the dashes before reveal")
    func reveal() throws {
        let ids = DomIds(try FormDefinition(json: ["id": "f", "submit": ["label": "S"], "fields": []]))
        #expect(ids.field("fh", "a--reveal") == "fh-a-reveal")
    }
}
