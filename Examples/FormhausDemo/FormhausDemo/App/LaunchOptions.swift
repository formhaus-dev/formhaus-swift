import Foundation

struct LaunchOptions {
    var script: String?
    var stopAt: String?
    var language: DemoLanguage
    var speed: Double?

    init(defaults: UserDefaults = .standard) {
        script = defaults.string(forKey: "demoScript")
        stopAt = defaults.string(forKey: "demoStop")
        language = defaults.string(forKey: "demoLanguage").flatMap(DemoLanguage.init(rawValue:)) ?? .english
        speed = defaults.object(forKey: "demoSpeed") == nil ? nil : defaults.double(forKey: "demoSpeed")
    }
}
