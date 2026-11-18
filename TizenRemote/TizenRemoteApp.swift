import SwiftUI

@main
struct TizenRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            DiscoveryView()
                .preferredColorScheme(.dark)
        }
    }
}
