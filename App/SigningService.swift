import Foundation
import UniformTypeIdentifiers

/// Bridges the zsign C++ engine into Swift and manages file staging.
@MainActor
final class SigningService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case downloading
        case signing
        case done(String)
        case failed(String)
    }

    @Published var phase: Phase = .idle {
        didSet {
            print("[SigningService] phase -> \(phase)")
        }
    }

    let tempDir: URL
    let workDir: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ForgeSign", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        workDir = base
        tempDir = base.appendingPathComponent("tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    /// Copies a security-scoped picked file into the app container, returning the local path.
    func stage(_ url: URL, as name: String? = nil) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let dest = workDir.appendingPathComponent(name ?? url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    /// Blocking sign call wrapper that runs the C++ signing inside a detached Task and
    /// enforces a timeout watchdog to avoid UI hangs. The underlying C++ call may
    /// not be cancellable; the watchdog will mark the operation as failed after
    /// `timeout` seconds and return with a failure message while the background
    /// thread may continue to run.
    nonisolated static func signWithTimeout(ipa: URL, p12: URL, password: String, profile: URL,
                                   bundleId: String, output: URL, tempDir: URL,
                                   removeExtensions: Bool, enableDocuments: Bool,
                                   timeout: TimeInterval = 120.0)
    -> (ok: Bool, message: String, signedBundleId: String, signedVersion: String) {
        print("[SigningService] signWithTimeout: starting sign task for \(ipa.path) with timeout \(timeout)s")

        // Use a semaphore to wait for the detached Task to finish or timeout.
        let sem = DispatchSemaphore(value: 0)
        var result: (Bool, String, String, String) = (false, "Signing timed out.", "", "")

        Task.detached {
            print("[SigningService] signWithTimeout: running actual sign on background thread")
            let res = sign(ipa: ipa, p12: p12, password: password, profile: profile,
                           bundleId: bundleId, output: output, tempDir: tempDir,
                           removeExtensions: removeExtensions, enableDocuments: enableDocuments)
            result = (res.ok, res.message, res.signedBundleId, res.signedVersion)
            sem.signal()
        }

        // Wait with timeout
        let waitResult = sem.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            print("[SigningService] signWithTimeout: timed out after \(timeout)s")
            return (false, "Signing timed out after \(Int(timeout)) seconds.", "", "")
        }

        print("[SigningService] signWithTimeout: finished with ok=\(result.0) message=\(result.1)")
        return result
    }

    /// Runs the zsign signing engine. Blocking — call from a background task.
    /// Returns success, a message, the signed bundle identifier, and version.
    nonisolated static func sign(ipa: URL, p12: URL, password: String, profile: URL,
                     bundleId: String, output: URL, tempDir: URL,
                     removeExtensions: Bool, enableDocuments: Bool)
        -> (ok: Bool, message: String, signedBundleId: String, signedVersion: String) {
        var msgBuf = [CChar](repeating: 0, count: 1024)
        var bidBuf = [CChar](repeating: 0, count: 512)
        var verBuf = [CChar](repeating: 0, count: 128)
        let status = forgesign_sign_ipa(
            ipa.path, p12.path, password, profile.path,
            bundleId.isEmpty ? nil : bundleId,
            output.path,
            tempDir.path,
            removeExtensions ? 1 : 0,
            enableDocuments ? 1 : 0,
            &msgBuf, Int32(msgBuf.count),
            &bidBuf, Int32(bidBuf.count),
            &verBuf, Int32(verBuf.count)
        )
        let message = String(decoding: msgBuf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let signedId = String(decoding: bidBuf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let signedVersion = String(decoding: verBuf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return (status == 0, message.isEmpty ? (status == 0 ? "Signed." : "Failed.") : message,
                signedId, signedVersion.isEmpty ? "1.0" : signedVersion)
    }

    func cleanStaged() {
        if let items = try? FileManager.default.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil) {
            for item in items where item.lastPathComponent != "tmp" {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }
}
