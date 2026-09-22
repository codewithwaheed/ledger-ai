import Foundation
import SwiftData
import LedgerCore

/// JSON export of every table. Restore is a v2 item; this exists so data is never trapped in the app.
struct DataExporter {
    struct Export: Codable {
        var exportedAt: Date
        var accounts: [[String: String]]
        var transactions: [[String: String]]
        var categories: [[String: String]]
        var rules: [[String: String]]
        var trustedSenders: [[String: String]]
    }

    @MainActor
    func exportJSON(context: ModelContext) throws -> URL {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let txs = try context.fetch(FetchDescriptor<LedgerTransaction>())
        let cats = try context.fetch(FetchDescriptor<TransactionCategory>())
        let rules = try context.fetch(FetchDescriptor<Rule>())
        let senders = try context.fetch(FetchDescriptor<TrustedSender>())
        let iso = ISO8601DateFormatter()

        let e = Export(
            exportedAt: .now,
            accounts: accounts.map { ["id": $0.id.uuidString, "name": $0.name, "type": $0.typeRaw, "openingBalance": "\($0.openingBalance)", "last4": $0.last4 ?? "", "archived": "\($0.isArchived)"] },
            transactions: txs.map { ["id": $0.id.uuidString, "amount": "\($0.amount)", "type": $0.typeRaw, "date": iso.string(from: $0.date), "merchant": $0.merchant,
                                     "note": $0.note, "source": $0.sourceRaw, "account": $0.account?.id.uuidString ?? "", "toAccount": $0.toAccount?.id.uuidString ?? "",
                                     "category": $0.category?.fullName ?? "", "reviewed": "\($0.isReviewed)", "externalRef": $0.externalRef ?? ""] },
            categories: cats.map { ["id": $0.id.uuidString, "name": $0.name, "parent": $0.parent?.name ?? "", "color": $0.colorHex, "icon": $0.icon] },
            rules: rules.map { ["field": $0.fieldRaw, "op": $0.operatorRaw, "value": $0.value, "category": $0.category?.fullName ?? "", "priority": "\($0.priority)"] },
            trustedSenders: senders.map { ["senderID": $0.senderID, "name": $0.displayName, "templateSet": $0.templateSetID] })

        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]; enc.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ledger-export-\(Int(Date.now.timeIntervalSince1970)).json")
        try enc.encode(e).write(to: url)
        return url
    }
}
