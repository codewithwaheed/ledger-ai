import Foundation
import SwiftData

/// Detects when a parsed transaction's counterparty is one of the user's own accounts (e.g. NayaPay statement
/// shows "Incoming fund transfer from ... SCB-5801" and the user owns an SCB account ending 5801).
public struct TransferMatcher: Sendable {
    public init() {}

    @MainActor
    public func ownAccount(matchingLast4 last4: String?, excluding: Account?, in context: ModelContext) throws -> Account? {
        guard let last4, last4.count == 4 else { return nil }
        let accounts = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { !$0.isArchived }))
        return accounts.first { $0.id != excluding?.id && $0.allLast4.contains(last4) }
    }

    @MainActor
    public func accountOwning(last4: String?, in context: ModelContext) throws -> Account? {
        guard let last4, last4.count == 4 else { return nil }
        let accounts = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { !$0.isArchived }))
        return accounts.first { $0.allLast4.contains(last4) }
    }
}
