import Foundation

struct LaunchOptions {
    var script: String?
    var stopAt: String?
    var language: DemoLanguage
    var speed: Double?
    var style: DemoStyle

    init(defaults: UserDefaults = .standard) {
        script = defaults.string(forKey: "demoScript")
        stopAt = defaults.string(forKey: "demoStop")
        language = defaults.string(forKey: "demoLanguage").flatMap(DemoLanguage.init(rawValue:)) ?? .english
        style = defaults.string(forKey: "demoStyle").flatMap(DemoStyle.init(rawValue:)) ?? .formhaus
        speed = defaults.object(forKey: "demoSpeed") == nil ? nil : defaults.double(forKey: "demoSpeed")
    }
}
