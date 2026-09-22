import SwiftUI
import SwiftData
import LedgerCore

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var transaction: LedgerTransaction
    @Query(sort: \TransactionCategory.sortOrder) private var categories: [TransactionCategory]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @State private var offerRule = false

    var body: some View {
        Form {
            Section {
                TextField("Merchant", text: $transaction.merchant)
                HStack { Text("Amount"); Spacer(); Text(Money.format(transaction.amount)).monospacedDigit() }
                DatePicker("Date", selection: $transaction.date)
                Picker("Account", selection: $transaction.account) { ForEach(accounts) { Text($0.name).tag(Optional($0)) } }
                if transaction.type == .transfer {
                    Picker("To account", selection: $transaction.toAccount) { ForEach(accounts) { Text($0.name).tag(Optional($0)) } }
                }
            }
            if transaction.type != .transfer {
                Section("TransactionCategory") {
                    Picker("TransactionCategory", selection: $transaction.category) {
                        ForEach(categories.filter { $0.parent == nil }) { c in
                            Text(c.name).tag(Optional(c))
                            ForEach(c.children.sorted { $0.sortOrder < $1.sortOrder }) { Text("   \($0.name)").tag(Optional($0)) }
                        }
                    }
                    .onChange(of: transaction.category) { offerRule = transaction.category?.name != "Uncategorized" }
                    if offerRule, let cat = transaction.category {
                        Button("Always categorize \"\(transaction.merchant)\" as \(cat.name)") {
                            try? RulesEngine().learn(merchant: transaction.merchant, category: cat, origin: .user, in: context)
                            offerRule = false
                        }
                    }
                }
            }
            Section {
                Toggle("Reviewed", isOn: $transaction.isReviewed)
                TextField("Note", text: $transaction.note)
            }
            Section("Source") {
                LabeledContent("Captured via", value: transaction.source.rawValue.uppercased())
                if let b = transaction.reportedBalance { LabeledContent("Bank balance after", value: Money.format(b)) }
                if let r = transaction.externalRef { LabeledContent("Reference", value: r).font(.caption) }
                if let raw = transaction.sourceRef { Text(raw).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Transaction")
        .onDisappear { try? context.save() }
    }
}
