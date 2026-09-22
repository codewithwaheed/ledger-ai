import Foundation
import SwiftData

/// Assigns categories from ordered user rules. First matching enabled rule wins.
public struct RulesEngine: Sendable {
    public init() {}

    public struct Input: Sendable {
        public var merchant: String
        public var note: String
        public var sender: String?
        public var amount: Decimal
        public init(merchant: String, note: String = "", sender: String? = nil, amount: Decimal) {
            self.merchant = merchant; self.note = note; self.sender = sender; self.amount = amount
        }
    }

    @MainActor
    public func categorize(_ input: Input, in context: ModelContext) throws -> TransactionCategory? {
        var d = FetchDescriptor<Rule>(predicate: #Predicate { $0.isEnabled })
        d.sortBy = [SortDescriptor(\.priority)]
        let rules = try context.fetch(d)
        for rule in rules where matches(rule, input) {
            rule.hitCount += 1
            return rule.category
        }
        return nil
    }

    public func matches(_ rule: Rule, _ input: Input) -> Bool {
        let haystack: String
        switch rule.field {
        case .merchant: haystack = input.merchant
        case .note: haystack = input.note
        case .sender: haystack = input.sender ?? ""
        case .amount:
            guard rule.op == .between else { return false }
            let parts = rule.value.components(separatedBy: "..")
            guard parts.count == 2, let lo = Decimal(string: parts[0]), let hi = Decimal(string: parts[1]) else { return false }
            return input.amount >= lo && input.amount <= hi
        }
        switch rule.op {
        case .contains: return haystack.localizedCaseInsensitiveContains(rule.value)
        case .equals: return haystack.compare(rule.value, options: .caseInsensitive) == .orderedSame
        case .regex: return haystack.range(of: rule.value, options: [.regularExpression, .caseInsensitive]) != nil
        case .between: return false
        }
    }

    /// Creates a "merchant contains X → category" rule from a user correction.
    @MainActor
    public func learn(merchant: String, category: TransactionCategory, origin: RuleOrigin = .learned, in context: ModelContext) throws {
        let key = merchant.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        let existing = try context.fetch(FetchDescriptor<Rule>()).first {
            $0.field == .merchant && $0.value.compare(key, options: .caseInsensitive) == .orderedSame
        }
        if let existing {
            existing.category = category
            existing.isEnabled = true
        } else {
            let maxPriority = try context.fetch(FetchDescriptor<Rule>()).map(\.priority).max() ?? 0
            context.insert(Rule(priority: maxPriority + 1, field: .merchant, op: .contains, value: key, category: category, origin: origin))
        }
        try context.save()
    }
}
