import Foundation
import LedgerCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Plain-language monthly summary. Receives aggregates only, never individual transactions.
///
/// The model returns structured fields rather than free-form prose so the app can render every amount with
/// `Money.format` itself — free text let the model pick its own number style ("Rs 50,600" one run, "50600" or
/// "PKR 50,600.00" the next), which made the summary inconsistent between runs.
public struct MonthlySummarizer: Sendable {
    public init() {}

    public struct Aggregates: Sendable {
        public var monthLabel: String
        public var income: Decimal
        public var expense: Decimal
        public var previousExpense: Decimal?
        public var byCategory: [(name: String, amount: Decimal)]
        public var topMerchants: [(name: String, amount: Decimal)]
        public init(monthLabel: String, income: Decimal, expense: Decimal, previousExpense: Decimal?,
                    byCategory: [(name: String, amount: Decimal)], topMerchants: [(name: String, amount: Decimal)]) {
            self.monthLabel = monthLabel; self.income = income; self.expense = expense; self.previousExpense = previousExpense
            self.byCategory = byCategory; self.topMerchants = topMerchants
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct Summary {
        @Guide(description: "The category name with the highest spend, copied verbatim from the provided list")
        var topCategory: String
        @Guide(description: "One sentence comparing this month's spend to last month's, or noting there's no prior month to compare")
        var comparison: String
        @Guide(description: "One concrete, specific observation about the spending pattern this month. No advice unless the numbers clearly warrant it.")
        var observation: String
    }
    #endif

    public func summarize(_ a: Aggregates) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), ModelAvailability.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
        You analyze one person's monthly spending in Pakistan and fill in the requested fields. Each field is plain \
        spoken language, no currency amounts (the app inserts those itself), no bullet points, no headings.
        """)
        var lines = ["Month: \(a.monthLabel)", "Income: \(Money.format(a.income))", "Spent: \(Money.format(a.expense))"]
        if let p = a.previousExpense { lines.append("Spent last month: \(Money.format(p))") }
        lines.append("By category: " + a.byCategory.map { "\($0.name)=\(Money.format($0.amount))" }.joined(separator: ", "))
        lines.append("Top merchants: " + a.topMerchants.map { "\($0.name)=\(Money.format($0.amount))" }.joined(separator: ", "))
        do {
            let s = try await session.respond(to: lines.joined(separator: "\n"), generating: Summary.self).content
            return render(a, s)
        } catch { return nil }
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func render(_ a: Aggregates, _ s: Summary) -> String {
        "Spent \(Money.format(a.expense)) against \(Money.format(a.income)) income in \(a.monthLabel). "
        + "\(s.topCategory) was the biggest category. \(s.comparison) \(s.observation)"
    }
    #endif
}
