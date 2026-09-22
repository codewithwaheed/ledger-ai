import Foundation
import CryptoKit

public enum Hashing {
    /// Deterministic SHA-256 hex of normalized text; used as `LedgerTransaction.sourceHash`.
    public static func sourceHash(_ parts: String...) -> String {
        let normalized = parts.joined(separator: "|")
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
