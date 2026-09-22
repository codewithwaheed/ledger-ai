import Foundation
import SwiftData

@Model
public final class Account {
    public var id: UUID
    public var name: String
    public var typeRaw: String
    public var currency: String
    public var openingBalance: Decimal
    public var colorHex: String
    /// Last 4 digits of the account or card number. Used to match SMS/statement lines and to detect own-account transfers.
    public var last4: String?
    /// Additional identifiers (e.g. debit card last4) that also point at this account.
    public var aliasLast4: [String]
    public var isArchived: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LedgerTransaction.account)
    public var transactions: [LedgerTransaction] = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.toAccount)
    public var incomingTransfers: [LedgerTransaction] = []

    public init(name: String, type: AccountType, currency: String = "PKR", openingBalance: Decimal = 0,
                colorHex: String = "#FF5A0A", last4: String? = nil, aliasLast4: [String] = []) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.currency = currency
        self.openingBalance = openingBalance
        self.colorHex = colorHex
        self.last4 = last4
        self.aliasLast4 = aliasLast4
        self.isArchived = false
        self.createdAt = .now
    }

    public var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .bank }
        set { typeRaw = newValue.rawValue }
    }

    public var allLast4: Set<String> {
        var s = Set(aliasLast4)
        if let l = last4 { s.insert(l) }
        return s
    }

    /// Opening balance plus every transaction that touches this account.
    public var computedBalance: Decimal {
        let outgoing = transactions.reduce(Decimal(0)) { acc, t in
            switch t.type {
            case .income: acc + t.amount
            case .expense, .transfer: acc - t.amount
            }
        }
        let incoming = incomingTransfers.reduce(Decimal(0)) { $0 + $1.amount }
        return openingBalance + outgoing + incoming
    }
}
