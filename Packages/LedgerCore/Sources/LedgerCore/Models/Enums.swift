import Foundation

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case bank, creditCard, wallet, cash

    public var label: String {
        switch self {
        case .bank: "Bank"
        case .creditCard: "Credit Card"
        case .wallet: "Wallet"
        case .cash: "Cash"
        }
    }
}

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case expense, income, transfer
}

public enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual, sms, pdf, ai
}

public enum UnparsedStatus: String, Codable, Sendable {
    case open, converted, dismissed
}
