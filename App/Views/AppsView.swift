import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var ipaFile: UTType { UTType(filenameExtension: "ipa") ?? .data }
}

struct AppsView: View {
    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    @AppStorage("appLanguage") private var appLanguage: String = "ar"

    @StateObject private var signing = SigningService()
    @StateObject private var installController = InstallController()
    @State private var selectedApp: FeedApp?
    @State private var showSourcesSettings = false
    @State private var showCertificatesSheet = false
    @State private var showInstallStatus = false
    @State private var installingVersion: FeedVersion? = nil

    // new states for IPA import
    @State private var presentIPAImporter = false
    @State private var importTargetApp: FeedApp? = nil

    // search text for filtering apps
    @State private var searchText: String = ""

    // per-app install status (bundleIdentifier -> status text)
    @State private var installStatusMap: [String: String] = [:]
    // pending install to resume after certificate import
    @State private var pendingInstall: (app: FeedApp, version: FeedVersion)? = nil

    // Filtered apps based on searchText
    private var filteredApps: [FeedApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.apps }
        return store.apps.filter { app in
            if let title = app.title, title.localizedCaseInsensitiveContains(query) { return true }
            if let developer = app.developer, developer.localizedCaseInsensitiveContains(query) { return true }
            if app.bundleIdentifier.localizedCaseInsensitiveContains(query) { return true }
            return false
        }
    }

    var featuredApps: [FeedApp] {
        Array(filteredApps.prefix(5))
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
                            // If we have apps but no filtered results, show a friendly message
                            if filteredApps.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(T.ink3)
                                    Text(appLanguage == "ar" ? "لا توجد تطبيقات مطابقة" : "No matching apps")
                                        .font(T.sans(17, .bold))
                                        .foregroundColor(T.ink)
                                    Text(appLanguage == "ar" ? "جرّب كلمات بحث أخرى" : "Try a different search")
                                        .font(T.mono(12))
                                        .foregroundColor(T.ink3)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 80)
                                .padding(.horizontal, 16)
                            } else {
                                // 1. Featured Top Slider (Clean App Store Style)
                                if !featuredApps.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(featuredApps, id: \.bundleIdentifier) { app in
                                                Button(action: { selectedApp = app }) {
                                                    VStack(alignment: .leading, spacing: 8) {
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

                                                            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.48), Color.black.opacity(0.10)]), startPoint: .bottom, endPoint: .center)
                                                                .cornerRadius(16)
                                                                .frame(height: 170)
                                                                .clipped()

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
                                        ForEach(filteredApps, id: \.bundleIdentifier) { app in
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

                                                // Install button now triggers direct install flow
                                                let bundle = app.bundleIdentifier
                                                let statusText = installStatusMap[bundle]

                                                Button(action: {
                                                    initiateInstall(for: app)
                                                }) {
                                                    if let s = statusText {
                                                        Text(s)
                                                            .font(T.sans(13, .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(T.accent)
                                                            .clipShape(Capsule())
                                                    } else {
                                                        Text(appLanguage == "ar" ? "تثبيت" : "GET")
                                                            .font(T.sans(13, .bold))
                                                            .foregroundColor(T.accent)
                                                            .padding(.horizontal, 16)
                                                            .padding(.vertical, 6)
                                                            .background(T.accent.opacity(0.18))
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                .disabled(statusText != nil && statusText != "Failed")
                                            }
                                            .padding(12)
                                            .fGlass(cornerRadius: 14)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background { ForgeBackdrop() }
                .navigationTitle(appLanguage == "ar" ? "التطبيقات" : "Apps")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { presentIPAImporter = true }) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(T.accent)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSourcesSettings = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(T.accent)
                        }
                    }
                }
                .sheet(item: $selectedApp) { app in
                    AppDetailSheet(app: app, onInstall: { version in
                        startInstall(for: app, version: version)
                    })
                }
                .sheet(isPresented: $showSourcesSettings) {
                    SourcesSettingsView()
                }
                .sheet(isPresented: $showCertificatesSheet) {
                    CertificatesSheet(certStore: certStore)
                }
                .sheet(isPresented: $showInstallStatus) {
                    if let _ = installingVersion {
                        InstallStatusView(signing: signing, installController: installController)
                    } else {
                        EmptyView()
                    }
                }
                .sheet(isPresented: $presentIPAImporter) {
                    DocumentPicker(contentTypes: [UTType.ipaFile], onPick: { url in
                        presentIPAImporter = false
                        // start local install flow with a generic target (ask user later if needed)
                        startInstallLocal(from: url)
                    }, onCancel: {
                        presentIPAImporter = false
                    })
                }
            }
        }
        .environment(\.layoutDirection, appLanguage == "ar" ? .rightToLeft : .leftToRight)
        .searchable(text: $searchText)
        .onChange(of: certStore.certificates) { _ in
            // If certificates were just added and a pending install exists, resume
            if let pending = pendingInstall, !certStore.certificates.isEmpty {
                pendingInstall = nil
                startInstall(for: pending.app, version: pending.version)
            }
        }
    }

    // MARK: - Install helpers
    private func initiateInstall(for app: FeedApp) {
        // DEBUG: show versions parsed from feed
        print("DEBUG: app.versions for \(app.bundleIdentifier) = \(app.versions)")

        // Pick first/most-recent version
        guard let version = app.versions.first else {
            installStatusMap[app.bundleIdentifier] = appLanguage == "ar" ? "لا توجد نسخة متاحة" : "No versions available"
            // clear after a few seconds
            Task { try? await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC); await MainActor.run { installStatusMap[app.bundleIdentifier] = nil } }
            return
        }

        // If no certificates, open certs sheet and set pendingInstall
        if certStore.certificates.isEmpty {
            pendingInstall = (app, version)
            showCertificatesSheet = true
            return
        }

        // Start the install flow
        startInstall(for: app, version: version)
    }

    private func startInstall(for app: FeedApp, version: FeedVersion) {
        let bundle = app.bundleIdentifier
        installingVersion = version
        showInstallStatus = true

        // Start background task
        Task.detached(priority: .background) {
            // 0. prepare: capture tempDir on main actor
            let tempDir: URL = await MainActor.run { signing.tempDir }

            // update status: Downloading
            await MainActor.run { installStatusMap[bundle] = appLanguage == "ar" ? "Downloading…" : "Downloading…" }

            // 1. Download IPA
            guard let ipaURL = version.downloadURL else {
                await MainActor.run {
                    print("[AppsView] no download URL for \(bundle)")
                    installStatusMap[bundle] = appLanguage == "ar" ? "لا يوجد رابط تحميل" : "No download URL"
                    signing.phase = .failed("No download URL for version.")
                }
                return
            }

            let dest = tempDir.appendingPathComponent("\(app.bundleIdentifier)-\(version.version).ipa")

            do {
                // set downloading phase
                await MainActor.run {
                    print("[AppsView] setting signing.phase = .downloading for \(bundle)")
                    signing.phase = .downloading
                    installStatusMap[bundle] = appLanguage == "ar" ? "Downloading…" : "Downloading…"
                }

                print("[AppsView] starting download from \(ipaURL.absoluteString) for \(bundle)")
                let (tmpURL, response) = try await URLSession.shared.download(from: ipaURL)

                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    let code = http.statusCode
                    print("[AppsView] download HTTP error status: \(code) for \(bundle)")
                    throw NSError(domain: "DownloadError", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP status \(code)")
                }

                print("[AppsView] download finished, moving file to destination: \(dest.path) for \(bundle)")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmpURL, to: dest)

                await MainActor.run { print("[AppsView] file moved to dest \(dest.path) for \(bundle)") }

            } catch {
                // Download failed
                await MainActor.run {
                    print("[AppsView] download error for \(bundle): \(error.localizedDescription)")
                    installStatusMap[bundle] = appLanguage == "ar" ? "فشل التنزيل: \(error.localizedDescription)" : "Download failed: \(error.localizedDescription)"
                    signing.phase = .failed("Download failed: \(error.localizedDescription)")
                }
                return
            }

            // 2. Resolve P12 and password
            let p12URL: URL = await MainActor.run { certStore.fileURL(for: certStore.certificates.first!) }
            guard FileManager.default.fileExists(atPath: p12URL.path) else {
                await MainActor.run {
                    print("[AppsView] P12 not available for \(bundle)")
                    installStatusMap[bundle] = appLanguage == "ar" ? "الشهادة غير متوفرة" : "P12 not available"
                    signing.phase = .failed("P12 not available for selected certificate.")
                }
                return
            }
            let p12Password: String = await MainActor.run { certStore.savedPassword(for: certStore.certificates.first!) ?? "" }

            // pick a provisioning profile
            let profileURL: URL? = await MainActor.run { profileStore.profiles.first.map { profileStore.fileURL(for: $0) } }
            guard let profile = profileURL else {
                await MainActor.run {
                    print("[AppsView] provisioning profile not available for \(bundle)")
                    installStatusMap[bundle] = appLanguage == "ar" ? "لا يوجد ملف provisioning" : "No provisioning profile available"
                    signing.phase = .failed("No provisioning profile available.")
                }
                return
            }

            // update status: Signing
            await MainActor.run {
                print("[AppsView] setting signing.phase = .signing for \(bundle)")
                installStatusMap[bundle] = appLanguage == "ar" ? "Signing…" : "Signing…"; signing.phase = .signing
            }

            // 3. Call signing (blocking bridging call)
            let outputURL = await MainActor.run { signing.workDir.appendingPathComponent("\(app.bundleIdentifier)-signed.ipa") }

            let result = SigningService.sign(
                ipa: dest,
                p12: p12URL,
                password: p12Password,
                profile: profile,
                bundleId: app.bundleIdentifier,
                output: outputURL,
                tempDir: tempDir,
                removeExtensions: false,
                enableDocuments: false
            )

