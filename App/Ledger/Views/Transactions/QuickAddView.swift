import SwiftUI
import SwiftData
import LedgerCore

struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query(sort: \TransactionCategory.sortOrder) private var categories: [TransactionCategory]

    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var merchant = ""
    @State private var account: Account?
    @State private var toAccount: Account?
    @State private var category: TransactionCategory?
    @State private var date = Date.now
    @State private var note = ""

    private var topLevel: [TransactionCategory] { categories.filter { $0.parent == nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0", text: $amount).keyboardType(.decimalPad).font(.system(size: 40, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense); Text("Income").tag(TransactionType.income); Text("Transfer").tag(TransactionType.transfer)
                    }.pickerStyle(.segmented)
                }
                Section {
                    TextField(type == .income ? "From (payer)" : "Merchant / payee", text: $merchant)
                    Picker(type == .transfer ? "From account" : "Account", selection: $account) {
                        ForEach(accounts) { Text($0.name).tag(Optional($0)) }
                    }
                    if type == .transfer {
                        Picker("To account", selection: $toAccount) { ForEach(accounts.filter { $0.id != account?.id }) { Text($0.name).tag(Optional($0)) } }
                    } else {
                        Picker("TransactionCategory", selection: $category) {
                            Text("None").tag(Optional<TransactionCategory>.none)
                            ForEach(topLevel) { c in
                                Text(c.name).tag(Optional(c))
                                ForEach(c.children.sorted { $0.sortOrder < $1.sortOrder }) { Text("   \($0.name)").tag(Optional($0)) }
                            }
                        }
                    }
                    DatePicker("Date", selection: $date)
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
            .onAppear { account = account ?? accounts.first }
        }
    }

    private var canSave: Bool {
        guard let a = Money.parse(amount), a > 0, account != nil else { return false }
        return type != .transfer || toAccount != nil
    }

    private func save() {
        guard let a = Money.parse(amount) else { return }
        let m = merchant.isEmpty ? (type == .transfer ? "Transfer to \(toAccount?.name ?? "")" : "Manual entry") : merchant
        let fallback = try? DefaultCategories.uncategorized(in: context)
        let tx = LedgerTransaction(amount: a, type: type, date: date, merchant: m, account: account,
                             category: type == .transfer ? nil : (category ?? fallback),
                             source: .manual, note: note)
        tx.toAccount = type == .transfer ? toAccount : nil
        context.insert(tx)
        if type != .transfer, let category, !merchant.isEmpty { try? RulesEngine().learn(merchant: merchant, category: category, origin: .learned, in: context) }
        try? context.save()
        dismiss()
    }
}
