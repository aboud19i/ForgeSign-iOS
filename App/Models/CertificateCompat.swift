import Foundation

// Compatibility shims for CertificateRecord fields used by AppsView.
// Some projects may name stored p12 path/password fields differently; this
// computed extension uses reflection to locate likely candidates at runtime.

extension CertificateRecord {
    /// Attempts to locate a URL or path-like property on CertificateRecord
    /// that points to the imported .p12 file. This is intentionally
    /// permissive to avoid compile-time coupling to a particular field name.
    var fileURL: URL? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            // look for likely candidates
            if label.contains("p12") || label.contains("certificate") || label.contains("file") || label.contains("path") || label.contains("url") {
                if let url = child.value as? URL { return url }
                if let s = child.value as? String {
                    // If the string looks like a path (has /) prefer fileURL, otherwise try URL(string:)
                    if s.contains("/") { return URL(fileURLWithPath: s) }
                    if let u = URL(string: s) { return u }
                }
            }
        }
        return nil
    }

    /// Attempts to locate a password-like property on CertificateRecord.
    var password: String? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label.contains("pass") || label.contains("pwd") || label.contains("password") {
                return child.value as? String
            }
        }
        return nil
    }
}
