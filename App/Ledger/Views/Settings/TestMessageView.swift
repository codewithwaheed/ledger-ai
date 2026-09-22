import SwiftUI
import SwiftData
import LedgerCore
import LedgerIntents

/// Paste any bank SMS to see exactly what the ingestion pipeline would do with it. Optionally saves the result.
struct TestMessageView: View {
    @Environment(\.modelContext) private var context
    @Query private var senders: [TrustedSender]
    @State private var sender = ""
    @State private var body_ = ""
    @State private var result: String?
    @State private var save = false

    var body: some View {
        Form {
            Section("Sender") {
                Picker("Sender", selection: $sender) { Text("Choose").tag(""); ForEach(senders) { Text("\($0.displayName) (\($0.senderID))").tag($0.senderID) } }
            }
            Section("Message") { TextEditor(text: $body_).frame(minHeight: 120) }
            Section {
                Toggle("Actually save the transaction", isOn: $save)
                Button("Run") { Task { await run() } }.disabled(sender.isEmpty || body_.isEmpty)
            }
            if let result { Section("Result") { Text(result).font(.callout) } }
        }
        .navigationTitle("Test a message")
    }

    private func run() async {
        // Dry run uses an in-memory copy of the store so nothing is written unless requested.
        do {
            if save {
                let r = try await IngestionService().ingest(sender: sender, body: body_, notify: false, context: context)
                result = describe(r)
            } else {
                let scratch = try LedgerSchema.container(inMemory: true)
                let ctx = ModelContext(scratch)
                // Mirror senders and accounts so matching behaves like the real store.
                for s in senders { ctx.insert(TrustedSender(senderID: s.senderID, displayName: s.displayName, templateSetID: s.templateSetID)) }
                for a in try context.fetch(FetchDescriptor<Account>()) { ctx.insert(Account(name: a.name, type: a.type, last4: a.last4, aliasLast4: a.aliasLast4)) }
                try DefaultCategories.seedIfNeeded(in: ctx)
                let r = try await IngestionService().ingest(sender: sender, body: body_, notify: false, context: ctx)
                result = "Dry run: " + describe(r)
            }
        } catch { result = "Error: \(error)" }
    }

    private func describe(_ r: IngestionService.Result) -> String {
        switch r {
        case .saved(_, let m, let a, let t, let ai): "\(t.rawValue.capitalized) \(Money.format(a)) — \(m)\(ai ? " (via on-device AI, needs review)" : "")"
        case .duplicate: "Duplicate of an existing transaction; skipped."
        case .ignoredUntrustedSender(let s): "Ignored: \(s) is not a trusted sender."
        case .ignoredByPattern(let p): "Ignored as non-transaction (matched \(p))."
        case .unparsed: "Couldn't parse; would go to the Unparsed inbox."
        }
    }
}
