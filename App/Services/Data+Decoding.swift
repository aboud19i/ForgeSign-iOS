import Foundation

extension Data {
    /// Try decode into a proper UTF-8 String, with fallbacks for common mojibake cases.
    func decodedUTF8String() -> String? {
        // 1) Try proper UTF-8 (most common & correct).
        if let s = String(data: self, encoding: .utf8) { return s }

        // 2) Try Latin1 then reinterpret bytes as UTF-8 (common server mismatch).
        if let latin = String(data: self, encoding: .isoLatin1) {
            if let utf8data = latin.data(using: .utf8),
               let round = String(data: utf8data, encoding: .utf8) {
                return round
            }
            return latin
        }

        // 3) Try Windows CP1252
        if let cp = String(data: self, encoding: .windowsCP1252) { return cp }

        return nil
    }
}
