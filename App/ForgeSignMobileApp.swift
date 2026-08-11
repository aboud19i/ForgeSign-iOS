import SwiftUI

@main
struct ForgeSignMobileApp: App {
    @StateObject private var sourceStore = SourceStore()
    @StateObject private var certStore = CertificateStore()
    @StateObject private var profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sourceStore)
                .environmentObject(certStore)
                .environmentObject(profileStore)
        }
    }
}
