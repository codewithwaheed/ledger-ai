import SwiftUI
import SwiftData
import LedgerCore

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var editing: Account?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts.filter { !$0.isArchived }) { a in
                    Button { editing = a } label: {
                        HStack {
                            Circle().fill(Color(hex: a.colorHex)).frame(width: 12)
                            VStack(alignment: .leading) {
                                Text(a.name).foregroundStyle(.primary)
                                Text([a.type.label, a.last4.map { "····\($0)" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(a.computedBalance)).monospacedDigit().foregroundStyle(.primary)
                        }
                    }
                }
                let archived = accounts.filter(\.isArchived)
                if !archived.isEmpty {
                    Section("Archived") { ForEach(archived) { a in Text(a.name).foregroundStyle(.secondary) } }
                }
            }
            .navigationTitle("Accounts")
            .toolbar { Button("Add", systemImage: "plus") { creating = true } }
            .sheet(item: $editing) { AccountEditView(account: $0) }
            .sheet(isPresented: $creating) { AccountEditView(account: nil) }
        }
    }
}

struct AccountEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account?
    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var last4 = ""
    @State private var aliases = ""
    @State private var opening = ""
    @State private var color = "#FF5A0A"

    private let palette = ["#FF5A0A", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899", "#EAB308", "#0EA5E9", "#78716C"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) { ForEach(AccountType.allCases, id: \.self) { Text($0.label).tag($0) } }
                    TextField("Opening balance (Rs)", text: $opening).keyboardType(.decimalPad)
                }
                Section {
                    TextField("Account last 4 digits", text: $last4).keyboardType(.numberPad)
                    TextField("Other last-4s (e.g. debit card), comma separated", text: $aliases).keyboardType(.numbersAndPunctuation)
                } header: { Text("Matching") } footer: {
                    Text("Ledger uses these to link SMS and statement lines to this account, and to spot transfers between your own accounts.")
                }
                Section("Color") {
                    HStack { ForEach(palette, id: \.self) { p in
                        Circle().fill(Color(hex: p)).frame(width: 28).overlay { if p == color { Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) } }
                            .onTapGesture { color = p }
                    } }
                }
                if let account {
                    Section { Button(account.isArchived ? "Unarchive" : "Archive account", role: .destructive) { account.isArchived.toggle(); try? context.save(); dismiss() } }
                }
            }
            .navigationTitle(account == nil ? "New account" : "Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) }
            }
            .onAppear {
                guard let a = account else { return }
                name = a.name; type = a.type; last4 = a.last4 ?? ""; aliases = a.aliasLast4.joined(separator: ", ")
                opening = "\(a.openingBalance)"; color = a.colorHex
            }
        }
    }

    private func save() {
        let aliasList = aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count == 4 }
        if let a = account {
            a.name = name; a.type = type; a.last4 = last4.isEmpty ? nil : last4; a.aliasLast4 = aliasList
            a.openingBalance = Money.parse(opening) ?? 0; a.colorHex = color
        } else {
            context.insert(Account(name: name, type: type, openingBalance: Money.parse(opening) ?? 0, colorHex: color,
                                   last4: last4.isEmpty ? nil : last4, aliasLast4: aliasList))
        }
        try? context.save()
        dismiss()
    }
}
