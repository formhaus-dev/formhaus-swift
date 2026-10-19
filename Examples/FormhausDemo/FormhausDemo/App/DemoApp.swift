import SwiftUI

@main
struct DemoApp: App {
    @State private var session = DemoSession(launch: LaunchOptions())

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
        #if os(macOS)
            .defaultSize(width: 760, height: 880)
        #endif
    }
}
