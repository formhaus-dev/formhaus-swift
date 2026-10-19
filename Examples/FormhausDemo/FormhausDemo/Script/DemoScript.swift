import FormhausCore

enum Beat: Sendable {
    case wait(Pace)
    case mark(String)
    case reveal(String)
    case type(String, String)
    case clear(String)
    case pick(String, JSONValue)
    case toggle(String, String)
    case next
    case back
    case submit
    case language(DemoLanguage)
}

struct DemoScript: Sendable {
    let name: String
    let beats: [Beat]

    static func named(_ name: String) -> DemoScript? {
        all.first { $0.name == name }
    }

    static let all = [tour, languages]

    static let tour = DemoScript(
        name: "tour",
        beats: [
            .mark("start"), .wait(.intro),
            .next, .mark("error"), .wait(.hold),
            .pick("projectType", "landing-page"), .mark("landing"), .wait(.beat),
            .next, .mark("branch"), .wait(.hold),
            .back, .wait(.beat),
            .pick("projectType", "redesign"), .mark("condition"), .wait(.beat),
            .reveal("currentSite"), .type("currentSite", "https://northwind.studio"), .wait(.short),
            .reveal("siteRating"), .pick("siteRating", 2), .mark("project"), .wait(.beat),
            .next, .mark("scope"), .wait(.beat),
            .toggle("services", "design"), .wait(.short), .toggle("services", "development"), .mark("services"), .wait(.short),
            .reveal("priorities"), .pick("priorityLaunch", "high"), .wait(.short),
            .pick("priorityPolish", "high"), .wait(.short), .pick("prioritySearch", "medium"), .wait(.short),
            .reveal("urgency"), .pick("urgency", 4), .mark("scoped"), .wait(.beat),
            .next, .mark("contact"), .wait(.beat),
            .type("name", "Ada Lovelace"), .wait(.short), .type("email", "ada@lovelace.dev"), .wait(.short),
            .submit, .mark("server"), .wait(.hold),
            .clear("email"), .wait(.short), .type("email", "ada@northwind.studio"), .wait(.short),
            .submit, .mark("success"), .wait(.hold),
        ])

    static let languages = DemoScript(
        name: "languages",
        beats: [
            .mark("start"), .wait(.intro),
            .language(.german), .mark("german"), .wait(.hold),
            .next, .mark("germanError"), .wait(.hold),
            .language(.english), .mark("english"), .wait(.hold),
        ])
}
