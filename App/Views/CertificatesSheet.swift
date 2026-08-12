import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension UTType {
    static var p12File: UTType {
        UTType(filenameExtension: "p12") ?? .data
    }
    static var mobileprovisionFile: UTType {
        UTType(filenameExtension: "mobileprovision") ?? .data
    }
}

// UIKit-based document picker wrapper (more permissive across providers)
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

struct CertificatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var certStore: CertificateStore

    private enum ImporterKind {
        case p12
        case provision
    }

    @State private var activeImporter: ImporterKind? = nil
    @State private var passwordInput = ""
    @State private var showPasswordAlert = false
    @State private var selectedP12URL: URL?

    @State private var invalidSelectionMessage: String = ""
    @State private var showInvalidSelectionAlert = false
    @State private var presentDocumentPicker = false

    var body: some View {
        let certificates = certStore.certificates

        VStack(spacing: 0) {
            HStack {
                Text("Ø§ÙØ´ÙØ§Ø¯Ø§Øª").font(.headline)
                Spacer()
                Button(action: { dismiss() }) { Text("Ø¥ØºÙØ§Ù") }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Ø¥Ø¯Ø§Ø±Ø© Ø§ÙØ´ÙØ§Ø¯Ø§Øª").font(.headline)

                        Text("ÙÙ Ø¨Ø¥Ø¶Ø§ÙØ© Ø´ÙØ§Ø¯Ø© (.p12) ÙÙÙÙ Ø§ÙØªØ¹Ø±ÙÙ (.mobileprovision) ÙØ¨Ø¯Ø¡ Ø§ÙØªÙÙÙØ¹.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    Button(action: {
                        activeImporter = .p12
                        presentDocumentPicker = true
                    }) {
                        Label("Ø§Ø³ØªÙØ±Ø§Ø¯ Ø´ÙØ§Ø¯Ø© P12", systemImage: "doc.badge.plus")
                    }

                    Button(action: {
                        activeImporter = .provision
                        presentDocumentPicker = true
                    }) {
                        Label("Ø§Ø³ØªÙØ±Ø§Ø¯ ÙÙÙ MobileProvision", systemImage: "shield.badge.plus")
                    }
                }

                if !certificates.isEmpty {
                    CertificatesListSection(certificates: certificates, onRemove: removeCertificate)
                }
            }
        }
        // Present UIKit DocumentPicker when requested (more compatible with providers)
        .sheet(isPresented: $presentDocumentPicker) {
            if let kind = activeImporter {
                DocumentPicker(contentTypes: documentTypes(for: kind), onPick: { url in
                    presentDocumentPicker = false
                    handlePicked(url: url)
                }, onCancel: {
                    presentDocumentPicker = false
                    activeImporter = nil
                })
                .edgesIgnoringSafeArea(.all)
            } else {
                EmptyView()
            }
        }
        .alert("ÙÙÙØ© Ø³Ø± Ø§ÙØ´ÙØ§Ø¯Ø©", isPresented: $showPasswordAlert) {
            SecureField("Ø£Ø¯Ø®Ù ÙÙÙØ© Ø§ÙØ³Ø±", text: $passwordInput)
            Button("Ø§Ø³ØªÙØ±Ø§Ø¯") {
                if let url = selectedP12URL {
                    importP12(from: url, password: passwordInput)
                    passwordInput = ""
                }
            }
            Button("Ø¥ÙØºØ§Ø¡", role: .cancel) { passwordInput = "" }
        } message: { Text("ÙØ±Ø¬Ù Ø¥Ø¯Ø®Ø§Ù ÙÙÙØ© Ø³Ø± ÙÙÙ P12 Ø§ÙÙØ±ÙÙ.") }
        .alert("ÙÙÙ ØºÙØ± ØµØ§ÙØ­", isPresented: $showInvalidSelectionAlert) {
            Button("Ø­Ø³ÙÙØ§", role: .cancel) { showInvalidSelectionAlert = false }
        } message: { Text(invalidSelectionMessage) }
    }

    private func documentTypes(for kind: ImporterKind) -> [UTType] {
        switch kind {
        case .p12:
            return [UTType.p12File, .data, .item]
        case .provision:
            return [UTType.mobileprovisionFile, .data, .item]
        }
    }

    private func handlePicked(url: URL) {
        let ext = url.pathExtension.lowercased()
        switch activeImporter {
        case .p12:
            if ext == "p12" {
                selectedP12URL = url
                showPasswordAlert = true
            } else {
                invalidSelectionMessage = "Ø§ÙÙÙÙ Ø§ÙÙØ­Ø¯Ø¯ ÙÙØ³ Ø¨ÙØ§Ø­ÙØ© .p12: \(url.lastPathComponent)"
                showInvalidSelectionAlert = true
            }
        case .provision:
            if ext == "mobileprovision" {
                importProvision(from: url)
            } else {
                invalidSelectionMessage = "Ø§ÙÙÙÙ Ø§ÙÙØ­Ø¯Ø¯ ÙÙØ³ Ø¨ÙØ§Ø­ÙØ© .mobileprovision: \(url.lastPathComponent)"
                showInvalidSelectionAlert = true
            }
        case .none:
            break
        }
        activeImporter = nil
    }

    private func removeCertificate(_ cert: CertificateRecord) { certStore.delete(cert) }

    private func importProvision(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let profilesDir = base.appendingPathComponent("Profiles", isDirectory: true)
            try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
            var filename = url.lastPathComponent
            if FileManager.default.fileExists(atPath: profilesDir.appendingPathComponent(filename).path) {
                let stem = url.deletingPathExtension().lastPathComponent
                let short = UUID().uuidString.prefix(6)
                filename = "\(stem)-\(short).\(url.pathExtension)"
            }
            let dest = profilesDir.appendingPathComponent(filename)
            try data.write(to: dest, options: .completeFileProtection)
        } catch {
            invalidSelectionMessage = "ÙØ´Ù Ø§Ø³ØªÙØ±Ø§Ø¯ ÙÙÙ Ø§ÙØªØ¹Ø±ÙÙ: \(error.localizedDescription)"
            showInvalidSelectionAlert = true
        }
    }

    private func importP12(from url: URL, password: String) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        _ = certStore.importCertificate(from: url, password: password, rememberPassword: false)
    }
}

private struct CertificatesListSection: View {
    let certificates: [CertificateRecord]
    let onRemove: (CertificateRecord) -> Void

    var body: some View {
        Section(header: Text("Ø§ÙØ´ÙØ§Ø¯Ø§Øª Ø§ÙÙØ¶Ø§ÙØ©")) {
            ForEach(certificates, id: \.id) { cert in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cert.displayName)
                            .font(.body)
                            .fontWeight(.semibold)

                        if let exp = cert.notAfter {
                            Text(exp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        onRemove(cert)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
        }
    }
}
