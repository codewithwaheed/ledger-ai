import SwiftUI
import SwiftData
import LedgerCore
import LedgerParsing

/// First run: create the first account. Trusted senders and the Shortcuts guide live in Settings and are linked from here.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var last4 = ""
    @State private var opening = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Ledger keeps everything on this phone. Start by adding one account; you can add the rest later.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("First account") {
                    TextField("Name (e.g. Standard Chartered)", text: $name)
                    Picker("Type", selection: $type) { ForEach(AccountType.allCases, id: \.self) { Text($0.label).tag($0) } }
                    TextField("Last 4 digits of account/card", text: $last4).keyboardType(.numberPad)
                    TextField("Current balance (Rs)", text: $opening).keyboardType(.decimalPad)
                }
                Section {
                    Button("Create account") {
                        let acct = Account(name: name, type: type, openingBalance: Money.parse(opening) ?? 0, last4: last4.isEmpty ? nil : last4)
                        context.insert(acct)
                        try? context.save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
