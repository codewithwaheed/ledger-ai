import Foundation
import SwiftData
import LedgerCore

public struct CategoryTotal: Identifiable, Sendable, Equatable {
    public var id: String { name }
    public let name: String
    public let colorHex: String
    public let amount: Decimal
    public let count: Int
}

public struct MerchantTotal: Identifiable, Sendable, Equatable {
    public var id: String { name }
    public let name: String
    public let amount: Decimal
    public let count: Int
}

public struct MonthlyReport: Sendable, Equatable {
    public let month: Date
    public let income: Decimal
    public let expense: Decimal
    public let transferVolume: Decimal
    public let byCategory: [CategoryTotal]
    public let topMerchants: [MerchantTotal]
    public let unreviewedCount: Int
    public var net: Decimal { income - expense }

    public static let empty = MonthlyReport(month: .now, income: 0, expense: 0, transferVolume: 0, byCategory: [], topMerchants: [], unreviewedCount: 0)
}

public struct MonthPoint: Identifiable, Sendable, Equatable {
    public var id: Date { month }
    public let month: Date
    public let income: Decimal
    public let expense: Decimal
}

public enum Reports {
    public static func monthRange(containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }

    @MainActor
    public static func monthly(for date: Date, excludingCategories excluded: Set<String> = [], context: ModelContext) throws -> MonthlyReport {
        let (start, end) = monthRange(containing: date)
        let d = FetchDescriptor<LedgerTransaction>(predicate: #Predicate { $0.date >= start && $0.date < end })
        let txs = try context.fetch(d)

        var income: Decimal = 0, expense: Decimal = 0, transfers: Decimal = 0
        var cats: [String: (color: String, amount: Decimal, count: Int)] = [:]
        var merchants: [String: (amount: Decimal, count: Int)] = [:]
        var unreviewed = 0

        for t in txs {
            if !t.isReviewed { unreviewed += 1 }
            switch t.type {
            case .transfer: transfers += t.amount
            case .income: income += t.amount
            case .expense:
                // Roll subcategories up to their parent for the overview.
                let top = t.category?.parent ?? t.category
                let name = top?.name ?? "Uncategorized"
                if excluded.contains(name) { continue }
                expense += t.amount
                let c = cats[name] ?? (top?.colorHex ?? "#9CA3AF", 0, 0)
                cats[name] = (c.color, c.amount + t.amount, c.count + 1)
                let m = merchants[t.merchant] ?? (0, 0)
                merchants[t.merchant] = (m.amount + t.amount, m.count + 1)
            }
        }
        return MonthlyReport(
            month: start, income: income, expense: expense, transferVolume: transfers,
            byCategory: cats.map { CategoryTotal(name: $0.key, colorHex: $0.value.color, amount: $0.value.amount, count: $0.value.count) }
                .sorted { $0.amount > $1.amount },
            topMerchants: merchants.map { MerchantTotal(name: $0.key, amount: $0.value.amount, count: $0.value.count) }
                .sorted { $0.amount > $1.amount }.prefix(8).map { $0 },
            unreviewedCount: unreviewed)
    }

    @MainActor
    public static func trend(monthsBack: Int, endingAt date: Date = .now, context: ModelContext) throws -> [MonthPoint] {
        let cal = Calendar.current
        return try (0..<monthsBack).reversed().compactMap { back in
            guard let m = cal.date(byAdding: .month, value: -back, to: date) else { return nil }
            let r = try monthly(for: m, context: context)
            return MonthPoint(month: r.month, income: r.income, expense: r.expense)
        }
    }
}
