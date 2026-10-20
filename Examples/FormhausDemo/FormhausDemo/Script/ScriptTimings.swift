import Foundation

struct ScriptTimings: Decodable, Sendable {
    var speed = 1.0
    var intro = 1.6
    var beat = 0.9
    var short = 0.45
    var hold = 2.2
    var style = 2.8
    var keystroke = 0.07
    var wordPause = 0.12
    var submitDelay = 1.3

    static func load(from bundle: Bundle, speed: Double?) -> ScriptTimings {
        var timings = ScriptTimings()
        if let url = bundle.url(forResource: "demo-timings", withExtension: "json"), let data = try? Data(contentsOf: url) {
            timings = (try? JSONDecoder().decode(ScriptTimings.self, from: data)) ?? timings
        }
        if let speed, speed > 0 { timings.speed = speed }
        timings.submitDelay /= timings.speed
        return timings
    }

    func faster(_ factor: Double) -> ScriptTimings {
        var timings = self
        timings.speed *= factor
        timings.submitDelay /= factor
        return timings
    }

    func duration(_ pace: Pace) -> Double {
        let seconds =
            switch pace {
            case .intro: intro
            case .beat: beat
            case .short: short
            case .hold: hold
            case .style: style
            }
        return seconds / speed
    }

    func keystroke(after character: Character) -> Double {
        let base = character == " " || character == "." || character == "@" ? keystroke + wordPause : keystroke
        return base / speed
    }
}

enum Pace: Sendable {
    case intro
    case beat
    case short
    case hold
    case style
}
