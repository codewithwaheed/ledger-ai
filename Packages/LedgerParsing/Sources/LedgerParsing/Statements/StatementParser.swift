import Foundation
import LedgerCore

/// One row of a bank statement after parsing.
public struct StatementRow: Sendable, Equatable, Identifiable {
    public var id: String { externalRef ?? Hashing.sourceHash(bankID, rawBlock) }
    public var bankID: String
    public var date: Date
    public var type: TransactionType
    public var amount: Decimal
    public var balance: Decimal?
    public var fee: Decimal
    public var bankTypeLabel: String
    public var counterparty: String
    public var counterpartyBank: String?
    public var counterpartyLast4: String?
    public var externalRef: String?
    public var descriptionLines: [String]
    public var rawBlock: String

    public init(bankID: String, date: Date, type: TransactionType, amount: Decimal, balance: Decimal?, fee: Decimal,
                bankTypeLabel: String, counterparty: String, counterpartyBank: String?, counterpartyLast4: String?,
                externalRef: String?, descriptionLines: [String], rawBlock: String) {
        self.bankID = bankID; self.date = date; self.type = type; self.amount = amount; self.balance = balance; self.fee = fee
        self.bankTypeLabel = bankTypeLabel; self.counterparty = counterparty; self.counterpartyBank = counterpartyBank
        self.counterpartyLast4 = counterpartyLast4; self.externalRef = externalRef; self.descriptionLines = descriptionLines; self.rawBlock = rawBlock
    }
}

public struct StatementMetadata: Sendable, Equatable {
    public var bankID: String
    public var bankName: String
    public var accountLast4: String?
    public var periodStart: Date?
    public var periodEnd: Date?
    public var openingBalance: Decimal?
    public var closingBalance: Decimal?
    public var totalIn: Decimal?
    public var totalOut: Decimal?
    public init(bankID: String, bankName: String, accountLast4: String? = nil, periodStart: Date? = nil, periodEnd: Date? = nil,
                openingBalance: Decimal? = nil, closingBalance: Decimal? = nil, totalIn: Decimal? = nil, totalOut: Decimal? = nil) {
        self.bankID = bankID; self.bankName = bankName; self.accountLast4 = accountLast4; self.periodStart = periodStart; self.periodEnd = periodEnd
        self.openingBalance = openingBalance; self.closingBalance = closingBalance; self.totalIn = totalIn; self.totalOut = totalOut
    }
}

public struct ParsedStatement: Sendable, Equatable {
    public var metadata: StatementMetadata
    public var rows: [StatementRow]
    /// True when sum of rows equals the statement's own totals (or no totals were found).
    public var reconciles: Bool {
        guard let tin = metadata.totalIn, let tout = metadata.totalOut else { return true }
        let sin = rows.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let sout = rows.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        return sin == tin && sout == tout
    }
}

/// Implemented once per bank. `detect` inspects the extracted text of page 1.
public protocol StatementParser: Sendable {
    var bankID: String { get }
    var bankName: String { get }
    func detect(pageOneText: String) -> Bool
    func parse(pages: [String]) throws -> ParsedStatement
}

public enum StatementParserRegistry {
    public static let parsers: [any StatementParser] = [NayaPayStatementParser()]

    public static func parser(for pageOneText: String) -> (any StatementParser)? {
        parsers.first { $0.detect(pageOneText: pageOneText) }
    }
    public static func parser(id: String) -> (any StatementParser)? { parsers.first { $0.bankID == id } }
}
