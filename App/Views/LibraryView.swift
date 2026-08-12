import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var certStore: CertificateStore
    @EnvironmentObject private var profileStore: ProfileStore
    @AppStorage("appLanguage") private var appLanguage: String = "ar"

    @StateObject private var signing = SigningService()
    @StateObject private var installController = InstallController()

    @State private var showCertificatesSheet = false
    @State private var showProfilesSheet = false
    @State private var showImporter = false

    @State private var stagedFiles: [URL] = []
    @State private var signStatus: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    // Certificates & Profiles row
                    HStack(spacing: 12) {
                        Button(action: { showCertificatesSheet = true }) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(T.accent)
                                    .cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appLanguage == "ar" ? "إدارة الشهادات" : "Certificates")
                                        .font(T.sans(14, .bold))
                                        .foregroundColor(T.ink)
                                    Text(appLanguage == "ar" ? "اختر شهادة p12 للتوقيع" : "Choose a .p12 certificate to sign")
                                        .font(T.mono(11))
                                        .foregroundColor(T.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .foregroundColor(T.ink3)
                            }
                            .padding(12)
                            .fGlass(cornerRadius: 12)
                        }

                        Button(action: { showProfilesSheet = true }) {
                            HStack {
                                Image(systemName: "doc.plaintext")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appLanguage == "ar" ? "الـ provisioning" : "Provisioning")
                                        .font(T.sans(14, .bold))
                                        .foregroundColor(T.ink)
                                    Text(appLanguage == "ar" ? "اختر ملف provisioning" : "Choose a provisioning profile")
                                        .font(T.mono(11))
                                        .foregroundColor(T.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .foregroundColor(T.ink3)
                            }
                            .padding(12)
                            .fGlass(cornerRadius: 12)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Import IPA controls
                    GlassSection(appLanguage == "ar" ? "استيراد IPA" : "Import IPA") {
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                Button(action: { showImporter = true }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "tray.and.arrow.down.fill")
                                        Text(appLanguage == "ar" ? "استيراد ملف .ipa" : "Import .ipa from Files")
                                    }
                                    .font(T.sans(13, .bold))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(T.accent.opacity(0.12))
                                    .cornerRadius(10)
                                }

                                Button(action: importFromInstalledApps) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "externaldrive.fill.badge.plus")
                                        Text(appLanguage == "ar" ? "استيراد من الجهاز (جلب)" : "Fetch installed app (jailbreak)")
                                    }
                                    .font(T.sans(13, .bold))
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(Color.gray.opacity(0.08))
                                    .cornerRadius(10)
                                }

                                Spacer()
                            }

                            Text(appLanguage == "ar" ? "يمكنك استيراد IPA من " : "You can import an IPA from Files")
                                .font(T.mono(11))
                                .foregroundColor(T.ink3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                            switch result {
                            case .success(let url):
                                importIPA(from: url)
                            case .failure:
                                break
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Staged IPAs list
                    GlassSection(appLanguage == "ar" ? "ملفات IPA المستوردة" : "Staged IPAs") {
                        VStack(spacing: 8) {
                            if stagedFiles.isEmpty {
                                VStack(spacing: 8) {
                                    Text(appLanguage == "ar" ? "لا توجد ملفات IPA مستوردة" : "No staged IPAs")
                                        .font(T.sans(13))
                                        .foregroundColor(T.ink3)
                                    MonoText(text: appLanguage == "ar" ? "استورد ملف .ipa لتوقيعه" : "Import an .ipa to sign it", size: 11, color: T.ink3)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(18)
                            } else {
                                ForEach(stagedFiles, id: \.[[0]]) { url in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(url.lastPathComponent)
                                                .font(T.sans(14, .bold))
                                                .foregroundColor(T.ink)
                                                .lineLimit(1)

                                            let status = signStatus[url.lastPathComponent] ?? (appLanguage == "ar" ? "جاهز" : "Ready")
                                            Text(status)
                                                .font(T.mono(11))
                                                .foregroundColor(T.ink3)
                                        }
                                        Spacer()

                                        Button(action: { startSign(for: url) }) {
                                            Text(appLanguage == "ar" ? "توقيع" : "Sign")
                                                .font(T.sans(13, .bold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                                .background(T.accent)
                                                .cornerRadius(10)
                                        }

                                        Button(action: { deleteStaged(url: url) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(T.bad)
                                                .padding(8)
                                        }
                                    }
                                    .padding(12)
                                    .fGlass(cornerRadius: 12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 60)
                }
                .padding(.top, 18)
            }
            .background { ForgeBackdrop() }
            .navigationTitle(appLanguage == "ar" ? "التوقيع" : "Sign")
            .sheet(isPresented: $showCertificatesSheet) { CertificatesSheet(certStore: certStore) }
            .sheet(isPresented: $showProfilesSheet) { ProfilesSheet().environmentObject(profileStore) }
            .onAppear(perform: loadStaged)
        }
    }

    private var header: some View {
        HStack {
            Text(appLanguage == "ar" ? "المكتبة" : "Library")
                .font(T.sans(26, .bold))
                .foregroundColor(T.ink)
            Spacer()
            Button(action: { signing.cleanStaged(); loadStaged() }) {
                Image(systemName: "trash.slash")
                    .foregroundColor(T.ink3)
                    .padding(12)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions
    private func loadStaged() {
        stagedFiles.removeAll()
        let fm = FileManager.default
        let dir = signing.workDir
        if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension.lowercased() == "ipa" {
                stagedFiles.append(item)
            }
            // sort by name
            stagedFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
        }
    }

    private func importIPA(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let staged = signing.stage(url) {
                DispatchQueue.main.async {
                    loadStaged()
                    signStatus[staged.lastPathComponent] = appLanguage == "ar" ? "تم الاستيراد" : "Imported"
                }
            } else {
                DispatchQueue.main.async {
                    signStatus[url.lastPathComponent] = appLanguage == "ar" ? "فشل الاستيراد" : "Import failed"
                }
            }
        }
    }

    private func deleteStaged(url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadStaged()
    }

    private func importFromInstalledApps() {
        // Attempt to fetch installed app .ipa from device — only possible on jailbroken devices
        // Provide a helpful message for non-jailbroken devices
        signStatus["installed-fetch"] = appLanguage == "ar" ? "الوظيفة متاحة فقط على أجهزة مكسورة" : "Fetch available on jailbroken devices only"
    }

    private func startSign(for url: URL) {
        guard let cert = certStore.selected else {
            showCertificatesSheet = true
            return
        }
        guard let profile = profileStore.selected else {
            showProfilesSheet = true
            return
        }

        // resolve p12 and password
        let p12URL = certStore.fileURL(for: cert)
        let p12Password = certStore.savedPassword(for: cert) ?? ""

        signStatus[url.lastPathComponent] = appLanguage == "ar" ? "Signing…" : "Signing…"

        Task.detached(priority: .background) {
            let tempDir = signing.tempDir
            let output = signing.workDir.appendingPathComponent("signed-\(url.lastPathComponent)")

            let result = SigningService.signWithTimeout(
                ipa: url,
                p12: p12URL,
                password: p12Password,
                profile: profileStore.fileURL(for: profile),
                bundleId: "",
                output: output,
                tempDir: tempDir,
                removeExtensions: false,
                enableDocuments: false,
                timeout: 120.0
            )

            await MainActor.run {
                if result.ok {
                    signStatus[url.lastPathComponent] = appLanguage == "ar" ? "Signed — Installing…" : "Signed — Installing…"
                    installController.onDelivered = {
                        signStatus[url.lastPathComponent] = appLanguage == "ar" ? "IPA delivered. Accept prompt…" : "IPA delivered. Accept prompt…"
                    }
                    installController.install(ipa: output, bundleId: result.signedBundleId.isEmpty ? "" : result.signedBundleId, version: result.signedVersion)
                } else {
                    signStatus[url.lastPathComponent] = appLanguage == "ar" ? "فشل التوقيع: \(result.message)" : "Signing failed: \(result.message)"
                }
            }
        }
    }
}
