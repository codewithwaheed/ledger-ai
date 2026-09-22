import SwiftUI
import SwiftData
import LedgerCore
import LedgerImport

struct StatementImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    let url: URL
    @State private var account: Account?
    @State private var password = ""
    @State private var preview: ImportPreview?
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Group {
                if let preview { review(preview) } else { setup }
            }
            .navigationTitle("Import statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var setup: some View {
        Form {
            Section { Text(url.lastPathComponent).font(.callout) }
            Section("Import into") { Picker("Account", selection: $account) { ForEach(accounts) { Text($0.name).tag(Optional($0)) } } }
            Section { SecureField("PDF password (if any)", text: $password) }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section {
                Button { Task { await run() } } label: { HStack { Text("Read statement"); if loading { Spacer(); ProgressView() } } }
                    .disabled(account == nil || loading)
            }
        }
        .onAppear { account = account ?? accounts.first }
    }

    private func review(_ p: ImportPreview) -> some View {
        List {
            Section {
                LabeledContent("Bank", value: p.metadata.bankName)
                if let s = p.metadata.periodStart, let e = p.metadata.periodEnd {
                    LabeledContent("Period", value: "\(s.formatted(date: .abbreviated, time: .omitted)) – \(e.formatted(date: .abbreviated, time: .omitted))")
                }
                LabeledContent("New", value: "\(p.newCount)")
                LabeledContent("Already recorded", value: "\(p.duplicateCount)")
                if !p.reconciles { Label("Row totals don't match the statement's totals. Check rows before importing.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            Section("Rows") {
                ForEach(p.items) { item in
                    Toggle(isOn: binding(for: item.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.row.counterparty).lineLimit(1)
                                Text("\(item.row.date.formatted(date: .abbreviated, time: .shortened)) · \(item.resolvedType == .transfer ? "Transfer (own account)" : item.row.bankTypeLabel)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if item.isDuplicate { Text("Already recorded").font(.caption2).foregroundStyle(.orange) }
                                else if let c = item.categoryName { Text(c).font(.caption2).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text((item.row.type == .income ? "+" : "-") + Money.format(item.row.amount)).monospacedDigit()
                                .foregroundStyle(item.row.type == .income ? .green : .primary)
                        }
                    }
                }
            }
            Section {
                Button("Import \(p.items.filter(\.include).count) transactions") {
                    if let account { _ = try? StatementImportPipeline().commit(p, into: account, context: context) }
                    dismiss()
                }
                .disabled(account == nil)
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(get: { preview?.items.first { $0.id == id }?.include ?? false },
                set: { v in if let i = preview?.items.firstIndex(where: { $0.id == id }) { preview?.items[i].include = v } })
    }

    private func run() async {
        guard let account else { return }
        loading = true; defer { loading = false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            preview = try await StatementImportPipeline().preview(url: url, password: password.isEmpty ? nil : password, targetAccount: account, context: context)
        } catch ImportError.unknownBank {
            error = "Couldn't recognise this statement's bank. Currently supported: NayaPay."
        } catch PDFExtractionError.locked {
            error = "This PDF is password protected."
        } catch {
            self.error = "\(error)"
        }
    }
}
