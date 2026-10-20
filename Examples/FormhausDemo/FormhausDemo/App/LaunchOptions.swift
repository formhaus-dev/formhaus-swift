import Foundation

struct LaunchOptions {
    var script: String?
    var stopAt: String?
    var language: DemoLanguage
    var speed: Double?
    var style: DemoStyle
    var ticker: Bool
    var warmup: Bool

    init(defaults: UserDefaults = .standard) {
        script = defaults.string(forKey: "demoScript")
        stopAt = defaults.string(forKey: "demoStop")
        language = defaults.string(forKey: "demoLanguage").flatMap(DemoLanguage.init(rawValue:)) ?? .english
        style = defaults.string(forKey: "demoStyle").flatMap(DemoStyle.init(rawValue:)) ?? .formhaus
        ticker = defaults.bool(forKey: "demoTicker")
        warmup = defaults.bool(forKey: "demoWarmup")
        speed = defaults.object(forKey: "demoSpeed") == nil ? nil : defaults.double(forKey: "demoSpeed")
    }
}
