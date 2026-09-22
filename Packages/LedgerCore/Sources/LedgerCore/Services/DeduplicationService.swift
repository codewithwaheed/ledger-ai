import Foundation
import SwiftData

public struct DeduplicationService: Sendable {
    public init() {}

    public enum Verdict: Sendable, Equatable {
        case unique
        case duplicate(of: UUID)
    }

    /// A transaction is a duplicate if an exact source hash already exists, or if the same account saw the
    /// same amount and direction within `window` of the same time.
    @MainActor
    public func check(amount: Decimal, type: TransactionType, date: Date, accountID: UUID?, sourceHash: String?,
                      externalRef: String? = nil, window: TimeInterval = 120, in context: ModelContext) throws -> Verdict {
        if let sourceHash {
            var d = FetchDescriptor<LedgerTransaction>(predicate: #Predicate { $0.sourceHash == sourceHash })
            d.fetchLimit = 1
            if let hit = try context.fetch(d).first { return .duplicate(of: hit.id) }
        }
        if let externalRef, !externalRef.isEmpty {
            var d = FetchDescriptor<LedgerTransaction>(predicate: #Predicate { $0.externalRef == externalRef })
            d.fetchLimit = 1
            if let hit = try context.fetch(d).first { return .duplicate(of: hit.id) }
        }
        let lo = date.addingTimeInterval(-window), hi = date.addingTimeInterval(window)
        let typeRaw = type.rawValue
        let d = FetchDescriptor<LedgerTransaction>(predicate: #Predicate {
            $0.amount == amount && $0.typeRaw == typeRaw && $0.date >= lo && $0.date <= hi
        })
        let candidates = try context.fetch(d)
        if let hit = candidates.first(where: { accountID == nil || $0.account?.id == accountID || $0.toAccount?.id == accountID }) {
            return .duplicate(of: hit.id)
        }
        return .unique
    }

    /// Statement lines carry a date but often only day precision relative to SMS timestamps; use a wider window
    /// and ignore the time when matching PDF rows against existing SMS-sourced transactions.
    @MainActor
    public func checkStatementRow(amount: Decimal, type: TransactionType, date: Date, accountID: UUID?,
                                  sourceHash: String?, externalRef: String?, in context: ModelContext) throws -> Verdict {
        try check(amount: amount, type: type, date: date, accountID: accountID, sourceHash: sourceHash,
                  externalRef: externalRef, window: 36 * 3600, in: context)
    }
}
