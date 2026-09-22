import Foundation
import AppIntents
import SwiftData
import LedgerCore

/// Called by a Shortcuts Personal Automation: "When I get a message from 9220 → Ingest Bank Message
/// (Sender: Shortcut Input › Sender, Body: Shortcut Input › Content)".
public struct IngestBankMessageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ingest Bank Message"
    public static let description = IntentDescription(
        "Reads a bank SMS passed in from a Shortcuts automation and records the transaction. Messages from senders you haven't trusted in Ledger are ignored.",
        categoryName: "Transactions")
    /// Runs in the background without opening the app.
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Sender", description: "The sender ID of the message, e.g. 9220")
    public var sender: String

    @Parameter(title: "Message Body")
    public var body: String

    public init() {}
    public init(sender: String, body: String) { self.sender = sender; self.body = body }

    public static var parameterSummary: some ParameterSummary {
        Summary("Record bank message from \(\.$sender)") {
            \.$body
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let container = try LedgerSchema.container()
        let context = ModelContext(container)
        let result = try await IngestionService().ingest(sender: sender, body: body, context: context)
        let text: String
        switch result {
        case .saved(_, let merchant, let amount, let type, _): text = "\(type == .income ? "+" : "-")\(Money.format(amount)) \(merchant)"
        case .duplicate: text = "Already recorded"
        case .ignoredUntrustedSender(let s): text = "Ignored: \(s) is not a trusted sender"
        case .ignoredByPattern: text = "Ignored (not a transaction)"
        case .unparsed: text = "Saved to inbox for manual entry"
        }
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

public struct LedgerShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: IngestBankMessageIntent(),
                    phrases: ["Record a bank message in \(.applicationName)"],
                    shortTitle: "Ingest Bank Message",
                    systemImageName: "envelope.badge")
    }
}
