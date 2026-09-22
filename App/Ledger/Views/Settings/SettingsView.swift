import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import LedgerCore
import LedgerAI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var unparsed: [UnparsedItem]
    @Query(sort: \ImportBatch.importedAt, order: .reverse) private var batches: [ImportBatch]
    @State private var showImporter = false
    @State private var importURL: URL?
    @State private var exportURL: URL?

    private var openUnparsed: Int { unparsed.filter { $0.status == .open }.count }

    var body: some View {
        NavigationStack {
            List {
                Section("Automatic capture") {
                    NavigationLink { TrustedSendersView() } label: { Label("Trusted SMS senders", systemImage: "message.badge.filled.fill") }
                    NavigationLink { TestMessageView() } label: { Label("Test a message", systemImage: "text.magnifyingglass") }
                    NavigationLink { UnparsedInboxView() } label: {
                        Label("Unparsed inbox", systemImage: "tray.full").badge(openUnparsed)
                    }
                }
                Section("Statements") {
                    Button { showImporter = true } label: { Label("Import PDF statement", systemImage: "doc.badge.plus") }
                    ForEach(batches.prefix(5)) { b in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(b.bankName) · \(b.fileName)").lineLimit(1)
                                Text("\(b.importedAt.formatted(date: .abbreviated, time: .shortened)) · \(b.newCount) new").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Undo", role: .destructive) { context.delete(b); try? context.save() }.buttonStyle(.borderless)
                        }
                    }
                }
                Section("Categories & rules") {
                    NavigationLink { RulesView() } label: { Label("Rules", systemImage: "list.bullet.indent") }
                }
                Section("Data") {
                    Button { exportURL = try? DataExporter().exportJSON(context: context) } label: { Label("Export everything (JSON)", systemImage: "square.and.arrow.up") }
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "lock.shield") }
                }
                Section("On-device AI") {
                    switch ModelAvailability.state {
                    case .available: Label("Apple Intelligence available", systemImage: "checkmark.seal").foregroundStyle(.green)
                    case .unavailable(let r): VStack(alignment: .leading) { Label("Unavailable", systemImage: "xmark.seal"); Text(r).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { r in if case .success(let u) = r { importURL = u } }
            .sheet(item: $importURL) { StatementImportView(url: $0) }
            .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Text("Everything Ledger stores lives in this app's sandbox on this phone. There is no server, no analytics, and the app makes no network requests.")
            Text("SMS bodies reach Ledger only through the Shortcuts automations you create, and only from sender IDs you add to Trusted Senders. Anything else is dropped without being stored.")
            Text("On-device AI (Apple Intelligence) never sends your data off the device. Monthly summaries are generated from aggregated totals, not individual transactions.")
            Text("Back up regularly with Export: there is no cloud sync in this build, so losing the phone means losing the data.")
        }
        .font(.callout)
        .navigationTitle("Privacy")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
