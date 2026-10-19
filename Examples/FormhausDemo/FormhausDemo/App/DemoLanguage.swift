enum DemoLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        }
    }

    var copy: DemoCopy {
        switch self {
        case .english: .english
        case .german: .german
        }
    }
}

struct DemoCopy: Sendable {
    let language: String
    let restart: String
    let emailTaken: String
    let thanks: String
    let thanksAnonymous: String
    let reply: String
    let project: String
    let replyTo: String
    let newInquiry: String

    static let english = DemoCopy(
        language: "Language", restart: "Restart", emailTaken: "This email is already registered. Try another one.",
        thanks: "Thanks, {name}!", thanksAnonymous: "Thanks!", reply: "We got your inquiry and will reply within one business day.",
        project: "Project", replyTo: "Reply to", newInquiry: "Start a new inquiry")

    static let german = DemoCopy(
        language: "Sprache", restart: "Neu starten", emailTaken: "Diese E-Mail ist bereits registriert. Versuchen Sie eine andere.",
        thanks: "Danke, {name}!", thanksAnonymous: "Danke!",
        reply: "Wir haben Ihre Anfrage erhalten und antworten innerhalb eines Werktags.",
        project: "Projekt", replyTo: "Antwort an", newInquiry: "Neue Anfrage starten")
}
