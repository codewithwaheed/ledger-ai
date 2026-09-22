import Foundation
import SwiftData

public enum DefaultCategories {
    public struct Seed: Sendable { public let name: String; public let icon: String; public let color: String; public let children: [String] }

    public static let seeds: [Seed] = [
        Seed(name: "Food & Dining", icon: "fork.knife", color: "#F97316", children: ["Groceries", "Restaurants", "Delivery", "Snacks & Bakery"]),
        Seed(name: "Transport", icon: "car.fill", color: "#3B82F6", children: ["Fuel", "Ride-hailing", "Public Transport", "Maintenance"]),
        Seed(name: "Bills & Utilities", icon: "bolt.fill", color: "#EAB308", children: ["Electricity", "Gas", "Water", "Internet", "Mobile"]),
        Seed(name: "Shopping", icon: "bag.fill", color: "#EC4899", children: ["Clothing", "Electronics", "Household"]),
        Seed(name: "Health", icon: "cross.case.fill", color: "#EF4444", children: ["Pharmacy", "Doctor", "Lab"]),
        Seed(name: "Education", icon: "book.fill", color: "#8B5CF6", children: []),
        Seed(name: "Rent & Housing", icon: "house.fill", color: "#0EA5E9", children: []),
        Seed(name: "Family & Gifts", icon: "gift.fill", color: "#F43F5E", children: []),
        Seed(name: "Charity & Zakat", icon: "heart.fill", color: "#10B981", children: []),
        Seed(name: "Entertainment", icon: "tv.fill", color: "#6366F1", children: []),
        Seed(name: "Subscriptions", icon: "repeat", color: "#14B8A6", children: []),
        Seed(name: "Fees & Charges", icon: "percent", color: "#78716C", children: []),
        Seed(name: "Cash Withdrawal", icon: "banknote.fill", color: "#84CC16", children: []),
        Seed(name: "Salary", icon: "briefcase.fill", color: "#22C55E", children: []),
        Seed(name: "Business Income", icon: "chart.line.uptrend.xyaxis", color: "#16A34A", children: []),
        Seed(name: "Other Income", icon: "plus.circle.fill", color: "#4ADE80", children: []),
        Seed(name: "Uncategorized", icon: "questionmark.circle", color: "#9CA3AF", children: []),
    ]

    /// Inserts the default tree if no categories exist. Safe to call on every launch.
    @MainActor
    public static func seedIfNeeded(in context: ModelContext) throws {
        let count = try context.fetchCount(FetchDescriptor<TransactionCategory>())
        guard count == 0 else { return }
        for (i, s) in seeds.enumerated() {
            let parent = TransactionCategory(name: s.name, icon: s.icon, colorHex: s.color, sortOrder: i, isSystem: s.name == "Uncategorized")
            context.insert(parent)
            for (j, c) in s.children.enumerated() {
                context.insert(TransactionCategory(name: c, icon: s.icon, colorHex: s.color, sortOrder: j, parent: parent))
            }
        }
        try context.save()
    }

    @MainActor
    public static func uncategorized(in context: ModelContext) throws -> TransactionCategory? {
        var d = FetchDescriptor<TransactionCategory>(predicate: #Predicate { $0.name == "Uncategorized" && $0.parent == nil })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    @MainActor
    public static func find(_ name: String, in context: ModelContext) throws -> TransactionCategory? {
        var d = FetchDescriptor<TransactionCategory>(predicate: #Predicate { $0.name == name })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }
}
