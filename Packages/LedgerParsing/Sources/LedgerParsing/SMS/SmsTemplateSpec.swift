import Foundation
import LedgerCore

/// A single regex-based SMS pattern. Named groups recognised: amount, merchant, date, time, last4, account,
/// balance, ref, channel, cpLast4, cpBank. Stored as JSON so users can edit/add templates in-app.
public struct SmsTemplateSpec: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var pattern: String
    public var type: TransactionType
    /// Used when the pattern captures no merchant (e.g. ATM withdrawal).
    public var defaultMerchant: String?
    /// Date formats to try for the `date` group, e.g. ["dd-MM-yy", "dd/MM/yy"].
    public var dateFormats: [String]
    public var timeFormat: String?
    /// TransactionCategory name to pre-assign when this template fires (rules still run first and can override).
    public var suggestedCategory: String?
    /// Higher runs first within a set.
    public var priority: Int

    public init(id: String, name: String, pattern: String, type: TransactionType, defaultMerchant: String? = nil,
                dateFormats: [String] = ["dd-MM-yy", "dd/MM/yy", "dd-MM-yyyy", "dd/MM/yyyy"], timeFormat: String? = nil,
                suggestedCategory: String? = nil, priority: Int = 0) {
        self.id = id; self.name = name; self.pattern = pattern; self.type = type; self.defaultMerchant = defaultMerchant
        self.dateFormats = dateFormats; self.timeFormat = timeFormat; self.suggestedCategory = suggestedCategory; self.priority = priority
    }
}

/// All templates for one sender/bank.
public struct SmsTemplateSet: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var bankName: String
    public var defaultSenderIDs: [String]
    public var templates: [SmsTemplateSpec]
    /// Messages matching any of these are dropped silently (OTPs, promos).
    public var ignorePatterns: [String]

    public init(id: String, bankName: String, defaultSenderIDs: [String], templates: [SmsTemplateSpec], ignorePatterns: [String] = []) {
        self.id = id; self.bankName = bankName; self.defaultSenderIDs = defaultSenderIDs; self.templates = templates; self.ignorePatterns = ignorePatterns
    }
}
