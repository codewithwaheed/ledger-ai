import Foundation
import LedgerCore

/// Bank-agnostic result of parsing an SMS or a statement row. Not persisted; converted to `LedgerTransaction` by the ingestion layer.
public struct ParsedTransaction: Sendable, Equatable {
    public var amount: Decimal
    public var type: TransactionType
    public var date: Date
    public var merchant: String
    /// Last 4 of the account/card the money moved through on the user's side.
    public var accountLast4: String?
    /// Last 4 of the counterparty's account, when the message includes it (used for own-account transfer detection).
    public var counterpartyLast4: String?
    public var counterpartyBank: String?
    public var reportedBalance: Decimal?
    public var externalRef: String?
    public var channel: String?
    public var templateID: String
    public var raw: String

    public init(amount: Decimal, type: TransactionType, date: Date, merchant: String, accountLast4: String? = nil,
                counterpartyLast4: String? = nil, counterpartyBank: String? = nil, reportedBalance: Decimal? = nil,
                externalRef: String? = nil, channel: String? = nil, templateID: String, raw: String) {
        self.amount = amount; self.type = type; self.date = date; self.merchant = merchant
        self.accountLast4 = accountLast4; self.counterpartyLast4 = counterpartyLast4; self.counterpartyBank = counterpartyBank
        self.reportedBalance = reportedBalance; self.externalRef = externalRef; self.channel = channel
        self.templateID = templateID; self.raw = raw
    }
}

public enum ParseError: Error, Sendable, Equatable {
    case noTemplateMatched
    case invalidAmount(String)
    case invalidDate(String)
    case badRegex(String)
}
