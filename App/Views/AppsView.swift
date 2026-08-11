import SwiftUI

struct AppsView: View {
    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    @AppStorage("appLanguage") private var appLanguage: String = "ar"

    @StateObject private var signing = SigningService()
    @State private var selectedApp: FeedApp?
    @State private var showSourcesSettings = false
    @State private var showCertificatesSheet = false
    @State private var showInstallStatus = false
    @State private var installingVersion: FeedVersion? = nil

    var featuredApps: [FeedApp] {
        Array(store.apps.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        if store.isLoading && store.apps.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(T.accent)
                                Text(appLanguage == "ar" ? "جاري تحميل التطبيقات..." : "Loading Apps...")
                                    .font(T.sans(14, .regular))
                                    .foregroundColor(T.ink2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                        } else if store.apps.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "square.stack.3d.up.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(T.ink3)

                                Text(appLanguage == "ar" ? "لا توجد تطبيقات معروضة" : "No Apps Displayed")
                                    .font(T.sans(17, .bold))
                                    .foregroundColor(T.ink)

                                Button(action: { showSourcesSettings = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text(appLanguage == "ar" ? "إدارة وتأكيد المصادر" : "Manage Sources")
                                    }
                                    .font(T.sans(14, .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(T.accent)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(24)
                            .fGlass(cornerRadius: 18)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 40)
                        } else {

                            // 1. Featured Top Slider (Clean App Store Style)
                            if !featuredApps.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(featuredApps, id: \.bundleIdentifier) { app in
                                            Button(action: { selectedApp = app }) {
                                                VStack(alignment: .leading, spacing: 8) {

                                                    // Featured card: background image (banner/image/icon) with dark gradient overlay
                                                    ZStack(alignment: .bottomLeading) {
                                                        let bgURL = app.bannerURL ?? app.imageURL ?? app.iconURL

                                                        if let bgURL = bgURL {
                                                            AsyncImage(url: bgURL) { phase in
                                                                switch phase {
                                                                case .empty:
                                                                    Color.gray.opacity(0.08)
                                                                case .success(let image):
                                                                    image
                                                                        .resizable()
                                                                        .scaledToFill()
                                                                case .failure:
                                                                    Color.gray.opacity(0.08)
                                                                @unknown default:
                                                                    Color.clear
                                                                }
                                                            }
                                                            .frame(height: 170)
                                                            .clipped()
                                                            .cornerRadius(16)
                                                        } else {
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .fill(LinearGradient(gradient: Gradient(colors: [T.accent.opacity(0.9), T.accent.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                                                .frame(height: 170)
                                                        }

                                                        // Dark gradient overlay to improve text contrast
                                                        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.48), Color.black.opacity(0.10)]), startPoint: .bottom, endPoint: .center)
                                                            .cornerRadius(16)
                                                            .frame(height: 170)
                                                            .clipped()

                                                        // Bottom content: small icon, title, description, GET button
                                                        HStack(spacing: 12) {
                                                            AsyncImage(url: app.iconURL) { img in
                                                                img.resizable().scaledToFill()
                                                            } placeholder: {
                                                                Color.gray.opacity(0.3)
                                                            }
                                                            .frame(width: 48, height: 48)
                                                            .cornerRadius(10)

                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(app.title ?? "App")
                                                                    .font(T.sans(14, .bold))
                                                                    .foregroundColor(.white)
                                                                    .lineLimit(1)

                                                                if let desc = app.description, !desc.isEmpty {
                                                                    Text(desc)
                                                                        .font(T.sans(11, .regular))
                                                                        .foregroundColor(Color.white.opacity(0.9))
                                                                        .lineLimit(1)
                                                                }
                                                            }

                                                            Spacer()

                                                            Text(appLanguage == "ar" ? "تثبيت" : "GET")
                                                                .font(T.sans(12, .bold))
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 14)
                                                                .padding(.vertical, 6)
                                                                .background(Color.white.opacity(0.12))
                                                                .clipShape(Capsule())
                                                        }
                                                        .padding(12)
                                                        .padding(.bottom, 10)
                                                    }

                                                }
                                                .frame(width: 300)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            // 2. Main App List Section
                            VStack(alignment: .leading, spacing: 14) {
                                Text(appLanguage == "ar" ? "تطبيقات لا تستغني عنها" : "Must-Have Apps")
                                    .font(T.sans(18, .bold))
                                    .foregroundColor(T.ink)
                                    .padding(.horizontal, 16)

                                LazyVStack(spacing: 12) {
                                    ForEach(store.apps, id: \.bundleIdentifier) { app in
                                        Button(action: { selectedApp = app }) {
                                            HStack(spacing: 14) {
                                                AsyncImage(url: app.iconURL) { img in
                                                    img.resizable().scaledToFill()
                                                } placeholder: {
                                                    Color.gray.opacity(0.3)
                                                }
                                                .frame(width: 52, height: 52)
                                                .cornerRadius(12)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(app.title ?? "App")
                                                        .font(T.sans(15, .bold))
                                                        .foregroundColor(T.ink)
                                                        .lineLimit(1)

                                                    Text(app.description ?? app.developer ?? "")
                                                        .font(T.sans(12, .regular))
                                                        .foregroundColor(T.ink2)
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                Text(appLanguage == "ar" ? "تثبيت" : "GET")
                                                    .font(T.sans(13, .bold))
                                                    .foregroundColor(T.accent)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 6)
                                                    .background(T.accent.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                            .padding(12)
                                            .fGlass(cornerRadius: 14)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background { ForgeBackdrop() }
                .navigationTitle(appLanguage == "ar" ? "التطبيقات" : "Apps")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSourcesSettings = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(T.accent)
                        }
                    }
                }
                .sheet(item: $selectedApp) { app in
                    // Pass a real onInstall handler so installs start immediately
                    AppDetailSheet(app: app, onInstall: { version in
                        startInstall(for: app, version: version)
                    })
                }
                .sheet(isPresented: $showSourcesSettings) {
                    SourcesSettingsView()
                }
                // Certificates sheet (shown when no certs or user chooses)
                .sheet(isPresented: $showCertificatesSheet) {
                    CertificatesSheet(certStore: certStore)
                }
                // Install status sheet
                .sheet(isPresented: $showInstallStatus) {
                    if let _ = installingVersion {
                        InstallStatusView(signing: signing)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage == "ar" ? .rightToLeft : .leftToRight)
    }

    // MARK: - Install flow
    private func startInstall(for app: FeedApp, version: FeedVersion) {
        // If no certificates, show certificate import sheet
        if certStore.certificates.isEmpty {
            // Opens certificates UI so user can add one
            showCertificatesSheet = true
            return
        }

        // Choose a certificate to use (here we pick the first remembered certificate).
        guard let cert = certStore.certificates.first else {
            showCertificatesSheet = true
            return
        }

        // Prepare to show install status UI
        installingVersion = version
        showInstallStatus = true

        // Start background task to download IPA and call SigningService.sign(...)
        Task.detached(priority: .background) {
            // 1. Download IPA to temporary path
            guard let ipaURL = version.downloadURL else {
                await MainActor.run {
                    signing.phase = .failed("No download URL for version.")
                }
                return
            }

            let dest = signing.tempDir.appendingPathComponent("\(app.bundleIdentifier)-\(version.version).ipa")
            do {
                let (data, _) = try await URLSession.shared.data(from: ipaURL)
                try data.write(to: dest, options: .atomic)
            } catch {
                await MainActor.run {
                    signing.phase = .failed("Download failed: \(error.localizedDescription)")
                }
                return
            }

            // 2. Resolve P12 and provision profile paths & password
            // Using assumed field names per user's instruction
            guard let p12URL = cert.fileURL else {
                await MainActor.run {
                    signing.phase = .failed("P12 not available for selected certificate.")
                }
                return
            }

            let p12Password = cert.password ?? ""

            // pick a provisioning profile (simplest: first one)
            let profileURL = profileStore.profiles.first.map { profileStore.fileURL(for: $0) }
            guard let profile = profileURL else {
                await MainActor.run {
                    signing.phase = .failed("No provisioning profile available.")
                }
                return
            }

            // 3. Call the synchronous C++ binding (runs in background thread)
            await MainActor.run {
                signing.phase = .signing
            }

            let outputURL = signing.workDir.appendingPathComponent("\(app.bundleIdentifier)-signed.ipa")
            let result = SigningService.sign(
                ipa: dest,
                p12: p12URL,
                password: p12Password,
                profile: profile,
                bundleId: app.bundleIdentifier,
                output: outputURL,
                tempDir: signing.tempDir,
                removeExtensions: false,
                enableDocuments: false
            )

            await MainActor.run {
                if result.ok {
                    signing.phase = .done(result.message)
                } else {
                    signing.phase = .failed(result.message)
                }
            }

            // optional: trigger local install server or OTA flow here using outputURL
        }
    }
}
