import SwiftUI
import SwiftData
import LedgerCore

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LedgerTransaction.date, order: .reverse) private var transactions: [LedgerTransaction]
    @State private var search = ""
    @State private var onlyUnreviewed = false
    var initialCategoryName: String? = nil
    var initialMonth: Date? = nil

    private var filtered: [LedgerTransaction] {
        transactions.filter { t in
            if onlyUnreviewed && t.isReviewed { return false }
            if let c = initialCategoryName, (t.category?.parent?.name ?? t.category?.name) != c { return false }
            if let m = initialMonth, !Calendar.current.isDate(t.date, equalTo: m, toGranularity: .month) { return false }
            if !search.isEmpty {
                return t.merchant.localizedCaseInsensitiveContains(search) || t.note.localizedCaseInsensitiveContains(search)
                    || (t.category?.name.localizedCaseInsensitiveContains(search) ?? false)
            }
            return true
        }
    }

    private var grouped: [(day: Date, items: [LedgerTransaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.day) { group in
                    Section(group.day.formatted(.dateTime.weekday(.wide).day().month())) {
                        ForEach(group.items) { t in
                            NavigationLink { TransactionDetailView(transaction: t) } label: { TransactionRow(t: t) }
                                .swipeActions(edge: .leading) {
                                    if !t.isReviewed { Button("Reviewed", systemImage: "checkmark") { t.isReviewed = true; try? context.save() }.tint(.green) }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", systemImage: "trash", role: .destructive) { context.delete(t); try? context.save() }
                                }
                        }
                    }
                }
            }
            .overlay { if filtered.isEmpty { ContentUnavailableView("No transactions", systemImage: "tray") } }
            .searchable(text: $search, prompt: "Merchant, note, category")
            .navigationTitle(initialCategoryName ?? "Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $onlyUnreviewed) { Label("Unreviewed", systemImage: "exclamationmark.circle") }
                        .toggleStyle(.button)
                }
            }
        }
    }
}

struct TransactionRow: View {
    let t: LedgerTransaction
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: t.category?.colorHex ?? "#9CA3AF").opacity(0.2)).frame(width: 38)
                Image(systemName: t.type == .transfer ? "arrow.left.arrow.right" : (t.category?.icon ?? "questionmark"))
                    .foregroundStyle(Color(hex: t.category?.colorHex ?? "#9CA3AF"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t.merchant).lineLimit(1)
                HStack(spacing: 6) {
                    Text(t.category?.name ?? (t.type == .transfer ? "Transfer" : "Uncategorized"))
                    if let a = t.account { Text("· \(a.name)") }
                    SourceBadge(source: t.source)
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((t.type == .income ? "+" : (t.type == .transfer ? "" : "-")) + Money.format(t.amount))
                    .monospacedDigit()
                    .foregroundStyle(t.type == .income ? .green : (t.type == .transfer ? .secondary : .primary))
                if !t.isReviewed { Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.orange) }
            }
        }
    }
}

struct SourceBadge: View {
    let source: TransactionSource
    var body: some View {
        Text(source.rawValue.uppercased()).font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }
}
