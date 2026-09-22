import Foundation
import SwiftData

public enum RuleField: String, Codable, CaseIterable, Sendable { case merchant, note, sender, amount }
public enum RuleOperator: String, Codable, CaseIterable, Sendable { case contains, equals, regex, between }
public enum RuleOrigin: String, Codable, Sendable { case user, learned }

@Model
public final class Rule {
    public var id: UUID
    public var priority: Int
    public var fieldRaw: String
    public var operatorRaw: String
    /// For `between`, formatted as "min..max".
    public var value: String
    public var isEnabled: Bool
    public var hitCount: Int
    public var originRaw: String
    public var createdAt: Date

    public var category: TransactionCategory?

    public init(priority: Int, field: RuleField, op: RuleOperator, value: String, category: TransactionCategory, origin: RuleOrigin = .user) {
        self.id = UUID()
        self.priority = priority
        self.fieldRaw = field.rawValue
        self.operatorRaw = op.rawValue
        self.value = value
        self.isEnabled = true
        self.hitCount = 0
        self.originRaw = origin.rawValue
        self.createdAt = .now
        self.category = category
    }

    public var field: RuleField { RuleField(rawValue: fieldRaw) ?? .merchant }
    public var op: RuleOperator { RuleOperator(rawValue: operatorRaw) ?? .contains }
    public var origin: RuleOrigin { RuleOrigin(rawValue: originRaw) ?? .user }
}
