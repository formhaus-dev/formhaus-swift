import Benchmark
import FormhausCore
import Foundation

private struct Case {
    let name: String
    let pattern: String
    let short: String
    let long: String
}

private let typical = [
    Case(
        name: "email", pattern: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", short: "ada@example.com",
        long: String(repeating: "a", count: 9988) + "@example.com"),
    Case(
        name: "phone", pattern: "^\\+?[0-9 ()-]{7,20}$", short: "+44 (20) 7946-0958",
        long: String(repeating: "0", count: 10000)),
    Case(
        name: "postcode", pattern: "^[A-Z]{1,2}\\d[A-Z\\d]? ?\\d[A-Z]{2}$", short: "SW1A 1AA",
        long: String(repeating: "A", count: 10000)),
    Case(
        name: "iban", pattern: "^[A-Z]{2}\\d{2}[A-Z0-9]{11,30}$", short: "GB82WEST12345698765432",
        long: "GB82" + String(repeating: "W", count: 9996)),
    Case(
        name: "password", pattern: "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$", short: "Passw0rd!",
        long: String(repeating: "a", count: 9999) + "A"),
    Case(
        name: "quoted", pattern: "^(['\"]).*\\1$", short: "\"hello\"",
        long: "\"" + String(repeating: "a", count: 9998) + "'"),
]

private let pathological = [
    Case(name: "(a+)+$", pattern: "(a+)+$", short: "", long: String(repeating: "a", count: 9999) + "!"),
    Case(name: "(a|aa)+$", pattern: "(a|aa)+$", short: "", long: String(repeating: "a", count: 9999) + "!"),
    Case(name: "(x+x+)+y", pattern: "(x+x+)+y", short: "", long: String(repeating: "x", count: 10000)),
    Case(
        name: "captures cleared in a loop", pattern: "(?:a|[]" + String(repeating: "()", count: 15000) + ")*\\1(?!)", short: "",
        long: String(repeating: "a", count: 9999)),
    Case(
        name: "nested lookarounds", pattern: "(?=(?!b)[^]*x)y(?:z|$)", short: "",
        long: String(repeating: "y", count: 9999) + "x"),
    Case(name: "large DFA states", pattern: "[^]*a[^]{3900}$", short: "", long: randomText(10000, seed: 1)),
    Case(name: "large counted repeat", pattern: "[a-z]{0,4001}1", short: "", long: String(repeating: "b", count: 6000) + "1"),
    Case(name: "DFA cache reset", pattern: "[ab]*a[ab]{12}$", short: "", long: randomText(10000, seed: 7)),
]

private func randomText(_ count: Int, seed: UInt64) -> String {
    var state = seed
    return String(
        (0..<count).map { _ -> Character in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state >> 63 == 0 ? "a" : "b"
        })
}

private func field(_ pattern: String) -> FormField {
    let escaped = pattern.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let text = """
        {"id": "bench", "submit": {"label": "Send"}, "fields": [
          {"key": "value", "type": "text", "label": "Value", "validation": {"pattern": "\(escaped)"}}
        ]}
        """
    guard let json = try? JSONValue(parsing: text), let definition = try? FormDefinition(json: json),
        case .field(let field)? = definition.fields?.first
    else {
        fatalError("invalid benchmark pattern \(pattern)")
    }
    return field
}

private func validate(_ field: FormField, _ text: String) -> String? {
    validateFieldValue(field, .string(text), [:])
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(metrics: [.wallClock, .throughput], maxDuration: .seconds(2))
    for item in typical {
        let variants = (0..<300).map { field("\(item.pattern)(?:z\($0)){0}") }
        Benchmark("compile \(item.name)", configuration: .init(scalingFactor: .kilo)) { benchmark in
            for index in benchmark.scaledIterations {
                blackHole(validate(variants[index % variants.count], item.short))
            }
        }
        let cached = field(item.pattern)
        Benchmark("match \(item.name) short", configuration: .init(scalingFactor: .kilo)) { benchmark in
            for _ in benchmark.scaledIterations { blackHole(validate(cached, item.short)) }
        }
        Benchmark("match \(item.name) long") { _ in blackHole(validate(cached, item.long)) }
    }
    for item in pathological {
        let cached = field(item.pattern)
        Benchmark("pathological \(item.name)", configuration: .init(maxIterations: 20)) { _ in
            blackHole(validate(cached, item.long))
        }
    }
}
