import Foundation
import SwiftData

/// A sender ID the user has explicitly allowed (e.g. "9220"). Messages from anyone else are dropped.
@Model
public final class TrustedSender {
    public var id: UUID
    /// Normalized sender: digits only for numeric short codes, uppercased for alphanumeric IDs.
    public var senderID: String
    public var displayName: String
    /// Identifier of the parser template set to apply (see LedgerParsing.BuiltInTemplates).
    public var templateSetID: String
    public var lastReceivedAt: Date?
    public var receivedCount: Int
    public var ignoredCount: Int
    public var createdAt: Date

    public var defaultAccount: Account?

    public init(senderID: String, displayName: String, templateSetID: String, defaultAccount: Account? = nil) {
        self.id = UUID()
        self.senderID = TrustedSender.normalize(senderID)
        self.displayName = displayName
        self.templateSetID = templateSetID
        self.receivedCount = 0
        self.ignoredCount = 0
        self.createdAt = .now
        self.defaultAccount = defaultAccount
    }

    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        // Short codes and phone numbers: compare on digits only. Alphanumeric IDs (e.g. "HBL"): uppercase.
        return digits.count == trimmed.count || digits.count >= 4 ? digits : trimmed.uppercased()
    }
}
