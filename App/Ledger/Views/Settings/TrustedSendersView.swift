import SwiftUI
import SwiftData
import LedgerCore
import LedgerParsing

struct TrustedSendersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrustedSender.createdAt) private var senders: [TrustedSender]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @State private var adding = false

    var body: some View {
        List {
            Section {
                Text("Only messages from these sender IDs are recorded. Each one needs a matching Shortcuts automation; tap a sender for the setup guide.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(senders) { s in
                NavigationLink { SenderSetupGuideView(sender: s) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(s.displayName).bold(); Text(s.senderID).foregroundStyle(.secondary) }
                        Text(s.lastReceivedAt.map { "Last message \($0.formatted(.relative(presentation: .named))) · \(s.receivedCount) received" } ?? "No messages received yet")
                            .font(.caption).foregroundStyle(s.lastReceivedAt == nil ? .orange : .secondary)
                    }
                }
            }
            .onDelete { idx in idx.map { senders[$0] }.forEach(context.delete); try? context.save() }
        }
        .navigationTitle("Trusted senders")
        .toolbar { Button("Add", systemImage: "plus") { adding = true } }
        .sheet(isPresented: $adding) { AddSenderView(accounts: accounts) }
    }
}

struct AddSenderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    @State private var senderID = ""
    @State private var name = ""
    @State private var templateSet = BuiltInTemplates.standardChartered.id
    @State private var account: Account?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Sender ID exactly as it appears in Messages (e.g. 9220)", text: $senderID)
                    TextField("Bank name", text: $name)
                    Picker("Message format", selection: $templateSet) {
                        ForEach(BuiltInTemplates.all) { Text($0.bankName).tag($0.id) }
                    }
                    Picker("Default account", selection: $account) {
                        Text("Detect from message").tag(Optional<Account>.none)
                        ForEach(accounts) { Text($0.name).tag(Optional($0)) }
                    }
                } footer: {
                    Text("If the bank's messages include your account or card last-4, Ledger matches the account automatically; the default is used otherwise.")
                }
            }
            .navigationTitle("Trusted sender")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(TrustedSender(senderID: senderID, displayName: name.isEmpty ? senderID : name, templateSetID: templateSet, defaultAccount: account))
                        try? context.save(); dismiss()
                    }.disabled(senderID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: templateSet) { if name.isEmpty, let s = BuiltInTemplates.set(id: templateSet) { name = s.bankName; if senderID.isEmpty { senderID = s.defaultSenderIDs.first ?? "" } } }
        }
    }
}

struct SenderSetupGuideView: View {
    let sender: TrustedSender

    private var steps: [(String, String)] {[
        ("Open the Shortcuts app", "Go to the Automation tab and tap +."),
        ("Choose “Message”", "Under Personal Automation, pick Message."),
        ("Set the sender", "Tap Sender, type \(sender.senderID) and choose it. Leave “Message Contains” empty."),
        ("Run immediately", "Select “Run Immediately” and turn off “Notify When Run”. Tap Next."),
        ("Add the action", "Tap New Blank Automation → Add Action → search “Ingest Bank Message” (from Ledger)."),
        ("Wire the inputs", "Tap Sender → Select Variable → Shortcut Input → Sender. Tap Message Body → Shortcut Input → Content."),
        ("Done", "Tap Done. Send yourself a test or wait for the next bank SMS; it will appear in Transactions."),
    ]}

    var body: some View {
        List {
            Section {
                HStack { Text("Sender ID"); Spacer(); Text(sender.senderID).bold()
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = sender.senderID }.labelStyle(.iconOnly) }
            }
            Section("Create the automation") {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)").font(.caption.bold()).frame(width: 22, height: 22).background(Color.accentColor.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 2) { Text(s.0).bold(); Text(s.1).font(.callout).foregroundStyle(.secondary) }
                    }
                }
            }
            Section {
                Link(destination: URL(string: "shortcuts://")!) { Label("Open Shortcuts", systemImage: "arrow.up.forward.app") }
            } footer: {
                Text("If a sender goes quiet for a while, check that the automation is still enabled and that Focus modes aren't blocking it.")
            }
        }
        .navigationTitle(sender.displayName)
    }
}
