import SwiftUI
import SwiftData
import Charts
import LedgerCore
import LedgerReports
import LedgerAI

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query private var allTransactions: [LedgerTransaction]   // observed so the report refreshes on any change
    @State private var month = Date.now
    @State private var report: MonthlyReport = .empty
    @State private var trend: [MonthPoint] = []
    @State private var summary: String?
    @State private var summarizing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthPicker
                    totals
                    if !report.byCategory.isEmpty { categoryChart }
                    if trend.count > 1 { trendChart }
                    if !report.topMerchants.isEmpty { merchants }
                    accountBalances
                    aiSummary
                }
                .padding()
            }
            .navigationTitle("Overview")
            .task(id: month) { refresh() }
            .onChange(of: allTransactions.count) { refresh() }
        }
    }

    private var monthPicker: some View {
        HStack {
            Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
            Spacer()
            Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
        }
    }

    private var totals: some View {
        HStack(spacing: 12) {
            StatCard(title: "Income", value: report.income, tint: .green)
            StatCard(title: "Spent", value: report.expense, tint: .red)
            StatCard(title: "Net", value: report.net, tint: report.net >= 0 ? .green : .red)
        }
    }

    private var categoryChart: some View {
        VStack(alignment: .leading) {
            Text("Spending by category").font(.subheadline.bold())
            Chart(report.byCategory) { c in
                SectorMark(angle: .value("Amount", (c.amount as NSDecimalNumber).doubleValue), innerRadius: .ratio(0.6), angularInset: 1.5)
                    .foregroundStyle(Color(hex: c.colorHex))
                    .cornerRadius(3)
            }
            .frame(height: 200)
            ForEach(report.byCategory.prefix(6)) { c in
                NavigationLink { TransactionListView(initialCategoryName: c.name, initialMonth: month) } label: {
                    HStack {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 10)
                        Text(c.name); Spacer()
                        Text(Money.format(c.amount)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var trendChart: some View {
        VStack(alignment: .leading) {
            Text("Last 6 months").font(.subheadline.bold())
            Chart {
                ForEach(trend) { p in
                    BarMark(x: .value("Month", p.month, unit: .month), y: .value("Income", (p.income as NSDecimalNumber).doubleValue))
                        .foregroundStyle(.green.opacity(0.7)).position(by: .value("Kind", "Income"))
                    BarMark(x: .value("Month", p.month, unit: .month), y: .value("Spent", (p.expense as NSDecimalNumber).doubleValue))
                        .foregroundStyle(.red.opacity(0.7)).position(by: .value("Kind", "Spent"))
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .frame(height: 160)
        }
        .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var merchants: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top merchants").font(.subheadline.bold())
            ForEach(report.topMerchants.prefix(5)) { m in
                HStack { Text(m.name).lineLimit(1); Spacer(); Text(Money.format(m.amount)).foregroundStyle(.secondary).monospacedDigit() }
            }
        }
        .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var accountBalances: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accounts").font(.subheadline.bold())
            ForEach(accounts) { a in
                HStack {
                    Circle().fill(Color(hex: a.colorHex)).frame(width: 10)
                    Text(a.name); Spacer()
                    Text(Money.format(a.computedBalance)).monospacedDigit()
                }
            }
        }
        .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var aiSummary: some View {
        if ModelAvailability.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("On-device summary", systemImage: "sparkles").font(.subheadline.bold())
                    Spacer()
                    if summarizing { ProgressView() } else {
                        Button(summary == nil ? "Generate" : "Refresh") { Task { await generateSummary() } }.font(.caption)
                    }
                }
                if let summary { Text(summary).font(.callout) }
            }
            .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func refresh() {
        report = (try? Reports.monthly(for: month, context: context)) ?? .empty
        trend = (try? Reports.trend(monthsBack: 6, endingAt: month, context: context)) ?? []
        summary = nil
    }

    private func generateSummary() async {
        summarizing = true; defer { summarizing = false }
        let prev = Calendar.current.date(byAdding: .month, value: -1, to: month).flatMap { try? Reports.monthly(for: $0, context: context) }
        let agg = MonthlySummarizer.Aggregates(
            monthLabel: month.formatted(.dateTime.month(.wide).year()), income: report.income, expense: report.expense,
            previousExpense: prev?.expense, byCategory: report.byCategory.map { ($0.name, $0.amount) },
            topMerchants: report.topMerchants.map { ($0.name, $0.amount) })
        summary = await MonthlySummarizer().summarize(agg) ?? "Summary unavailable right now."
    }
}

struct StatCard: View {
    let title: String; let value: Decimal; let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Money.format(value)).font(.headline).foregroundStyle(tint).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}
