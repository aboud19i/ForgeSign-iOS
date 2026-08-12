import SwiftUI

@main
struct ForgeSignMobileApp: App {
    @StateObject private var sourceStore = SourceStore()
    @StateObject private var certStore = CertificateStore()
    @StateObject private var profileStore = ProfileStore()

    init() {
        // Migrate old userdefaults key "app_language" -> "appLanguage" if present
        let defaults = UserDefaults.standard
        if let old = defaults.string(forKey: "app_language"), defaults.string(forKey: "appLanguage") == nil {
            defaults.set(old, forKey: "appLanguage")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sourceStore)
                .environmentObject(certStore)
                .environmentObject(profileStore)
        }
    }
}
