import Foundation
import SwiftData

/// A message from a trusted sender that no template (or the AI fallback) could parse. Surfaced in an inbox for manual conversion.
@Model
public final class UnparsedItem {
    public var id: UUID
    public var sender: String
    public var body: String
    public var receivedAt: Date
    public var attempts: Int
    public var statusRaw: String

    public init(sender: String, body: String, receivedAt: Date) {
        self.id = UUID()
        self.sender = sender
        self.body = body
        self.receivedAt = receivedAt
        self.attempts = 1
        self.statusRaw = UnparsedStatus.open.rawValue
    }

    public var status: UnparsedStatus {
        get { UnparsedStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
}
