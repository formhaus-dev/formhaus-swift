import FormhausCore

enum Beat: Sendable {
    case wait(Pace)
    case mark(String)
    case type(String, String)
    case fill(String, String)
    case clear(String)
    case pick(String, JSONValue)
    case toggle(String, String)
    case next
    case back
    case submit
    case language(DemoLanguage)
    case style(DemoStyle)
}

struct DemoScript: Sendable {
    let name: String
    let beats: [Beat]

    static func named(_ name: String) -> DemoScript? {
        all.first { $0.name == name }
    }

    static let all = [tour, showcase, branch, languages, styles]

    static let tour = DemoScript(name: "tour", beats: prelude + walkthrough)

    static let showcase = DemoScript(name: "showcase", beats: [.mark("start"), .wait(.intro)] + walkthrough)

    static let branch = DemoScript(
        name: "branch",
        beats: [
            .mark("start"), .wait(.intro),
            .pick("projectType", "landing-page"), .mark("landing"), .wait(.beat),
            .next, .mark("branch"), .wait(.hold),
            .submit, .mark("errors"), .wait(.beat), .wait(.short),
            .mark("typing"), .fill("name", "Ada Lovelace"), .wait(.hold),
        ])

    private static let prelude: [Beat] = [
        .mark("start"), .wait(.intro),
        .next, .mark("error"), .wait(.hold),
        .pick("projectType", "landing-page"), .mark("landing"), .wait(.beat),
        .next, .mark("branch"), .wait(.hold),
        .back, .wait(.beat),
    ]

    private static let walkthrough: [Beat] = [
        .pick("projectType", "redesign"), .mark("condition"), .wait(.beat),
        .pick("projectType", "online-store"), .mark("swap"), .wait(.beat),
        .pick("projectType", "redesign"), .mark("reveal"), .wait(.short),
        .mark("typing"), .fill("currentSite", "https://northwind.studio"), .wait(.short),
        .next, .mark("scope"), .wait(.beat),
        .toggle("services", "design"), .wait(.short), .toggle("services", "development"), .mark("services"), .wait(.short),
        .pick("siteRating", 5), .wait(.short), .pick("urgency", 4), .mark("scoped"), .wait(.beat),
        .next, .mark("contact"), .wait(.beat),
        .fill("name", "Ada Lovelace"), .wait(.short), .type("email", "ada@lovelace.dev"), .wait(.short),
        .submit, .mark("server"), .wait(.hold),
        .clear("email"), .wait(.short), .type("email", "ada@northwind.studio"), .wait(.short),
        .submit, .mark("success"), .wait(.hold),
    ]

    static let languages = DemoScript(
        name: "languages",
        beats: [
            .mark("start"), .wait(.intro),
            .language(.german), .mark("german"), .wait(.hold),
            .next, .mark("germanError"), .wait(.hold),
            .language(.english), .mark("english"), .wait(.hold),
        ])

    static let styles = DemoScript(
        name: "styles",
        beats: [
            .mark("start"), .wait(.intro),
            .pick("projectType", "redesign"), .wait(.short),
            .type("currentSite", "https://northwind.studio"), .wait(.short),
            .next, .wait(.beat),
            .toggle("services", "design"), .wait(.short), .toggle("services", "development"), .wait(.short),
            .pick("siteRating", 4), .wait(.short), .pick("urgency", 4), .mark("filled"), .wait(.hold),
            .style(.system), .mark("system"), .wait(.style),
            .style(.brand), .mark("brand"), .wait(.style),
            .style(.formhaus), .mark("formhaus"), .wait(.style),
        ])
}
