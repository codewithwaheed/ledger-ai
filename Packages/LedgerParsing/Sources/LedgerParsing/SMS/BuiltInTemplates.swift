import Foundation
import LedgerCore

/// Templates shipped with the app. Users can copy and edit these in Settings › Trusted Senders › Templates.
public enum BuiltInTemplates {
    static let amount = #"(?<amount>\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)"#
    static let dmy = #"(?<date>\d{2}[-/]\d{2}[-/]\d{2,4})"#

    /// Standard Chartered Pakistan, sender 9220.
    public static let standardChartered = SmsTemplateSet(
        id: "scb-pk",
        bankName: "Standard Chartered",
        defaultSenderIDs: ["9220"],
        templates: [
            SmsTemplateSpec(
                id: "scb.card_payment", name: "Debit card purchase",
                pattern: #"PKR\s+"# + amount + #"\s+have been paid at\s+(?<merchant>.+?)\s+on\s+"# + dmy + #"\s+using Debit Card no\.?\s*\S*(?<last4>\d{4})"#,
                type: .expense, priority: 10),
            SmsTemplateSpec(
                id: "scb.atm_withdrawal", name: "ATM withdrawal",
                pattern: #"PKR\s+"# + amount + #"\s+were withdrawn from Account No\.?\s*\S*?(?<last4>\d{4})\s+on\s+"# + dmy + #"\s+using an ATM"#,
                type: .expense, defaultMerchant: "ATM Withdrawal", suggestedCategory: "Cash Withdrawal", priority: 10),
            SmsTemplateSpec(
                id: "scb.credit_transfer", name: "Incoming transfer (IBFT/Raast)",
                pattern: #"your account\s+(?<account>\S+)\s+has been credited with amount PKR\s+"# + amount + #"\s+from account\s+(?<cpLast4>\S+)\s+(?<merchant>.+?)\s+from\s+(?<channel>\w+).*?\bon\s+"# + dmy,
                type: .income, priority: 9),
            SmsTemplateSpec(
                id: "scb.debit_transfer", name: "Outgoing transfer (IBFT/Raast)",
                pattern: #"your account\s+(?<account>\S+)\s+has been debited with amount PKR\s+"# + amount + #"(?:.*?\bto account\s+(?<cpLast4>\S+)\s+(?<merchant>.+?)\s+from\s+(?<channel>\w+))?.*?\bon\s+"# + dmy,
                type: .expense, defaultMerchant: "Transfer", priority: 8),
            SmsTemplateSpec(
                id: "scb.generic_debit", name: "Generic debit",
                pattern: #"PKR\s+"# + amount + #".*?\b(?:debited|deducted|charged)\b.*?"# + dmy,
                type: .expense, defaultMerchant: "Standard Chartered", priority: 1),
            SmsTemplateSpec(
                id: "scb.generic_credit", name: "Generic credit",
                pattern: #"PKR\s+"# + amount + #".*?\b(?:credited|received)\b.*?"# + dmy,
                type: .income, defaultMerchant: "Standard Chartered", priority: 1),
        ],
        ignorePatterns: [#"\bOTP\b"#, #"one[- ]time (pass|pin)"#, #"\bnever share\b"#, #"\bdo not share\b"#]
    )

    /// Fallback for any Pakistani bank: finds an amount, a debit/credit keyword and, if present, a merchant after "at"/"to"/"from".
    public static let genericPakistan = SmsTemplateSet(
        id: "generic-pk",
        bankName: "Generic (Pakistan)",
        defaultSenderIDs: [],
        templates: [
            SmsTemplateSpec(
                id: "pk.generic_debit", name: "Generic debit",
                pattern: #"(?:PKR|Rs\.?)\s*"# + amount + #".*?\b(?:debited|withdrawn|paid|spent|purchase|deducted|charged|sent)\b(?:.*?\b(?:at|to)\s+(?<merchant>[A-Za-z0-9&' .-]{3,40}?))?(?:.*?"# + dmy + #")?"#,
                type: .expense, defaultMerchant: "Unknown", priority: 2),
            SmsTemplateSpec(
                id: "pk.generic_credit", name: "Generic credit",
                pattern: #"(?:PKR|Rs\.?)\s*"# + amount + #".*?\b(?:credited|received|deposited)\b(?:.*?\bfrom\s+(?<merchant>[A-Za-z0-9&' .-]{3,40}?))?(?:.*?"# + dmy + #")?"#,
                type: .income, defaultMerchant: "Unknown", priority: 2),
        ],
        ignorePatterns: [#"\bOTP\b"#, #"one[- ]time (pass|pin)"#]
    )

    public static let all: [SmsTemplateSet] = [standardChartered, genericPakistan]

    public static func set(id: String) -> SmsTemplateSet? { all.first { $0.id == id } }
}
