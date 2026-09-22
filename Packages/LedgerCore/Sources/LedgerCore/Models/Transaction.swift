import Foundation
import SwiftData

@Model
public final class LedgerTransaction {
    public var id: UUID
    public var amount: Decimal
    public var typeRaw: String
    public var date: Date
    public var merchant: String
    public var note: String
    public var tags: [String]
    public var sourceRaw: String
    /// Raw SMS body or statement line, kept for audit/debugging. Purgeable.
    public var sourceRef: String?
    /// Stable hash of the source (sender + body, or statement line) for exact-duplicate detection.
    public var sourceHash: String?
    /// Bank-provided reference (statement Transaction ID) when available.
    public var externalRef: String?
    public var isReviewed: Bool
    /// Balance the bank reported after this transaction, if the message/statement included one.
    public var reportedBalance: Decimal?
    public var createdAt: Date

    public var account: Account?
    /// Destination account for transfers.
    public var toAccount: Account?
    public var category: TransactionCategory?
    public var importBatch: ImportBatch?

    public init(amount: Decimal, type: TransactionType, date: Date, merchant: String,
                account: Account?, category: TransactionCategory? = nil, source: TransactionSource = .manual,
                note: String = "", sourceRef: String? = nil, sourceHash: String? = nil,
                externalRef: String? = nil, reportedBalance: Decimal? = nil, isReviewed: Bool = true) {
        self.id = UUID()
        self.amount = amount
        self.typeRaw = type.rawValue
        self.date = date
        self.merchant = merchant
        self.note = note
        self.tags = []
        self.sourceRaw = source.rawValue
        self.sourceRef = sourceRef
        self.sourceHash = sourceHash
        self.externalRef = externalRef
        self.isReviewed = isReviewed
        self.reportedBalance = reportedBalance
        self.createdAt = .now
        self.account = account
        self.category = category
    }

    public var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    public var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Signed amount from the perspective of net worth: expenses negative, income positive, transfers zero.
    public var signedAmount: Decimal {
        switch type {
        case .expense: -amount
        case .income: amount
        case .transfer: 0
        }
    }
}
