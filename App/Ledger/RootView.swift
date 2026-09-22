import SwiftUI
import SwiftData
import LedgerCore

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var pendingImportURL: URL?
    @State private var showQuickAdd = false

    var body: some View {
        Group {
            if accounts.isEmpty {
                OnboardingView()
            } else {
                TabView {
                    Tab("Overview", systemImage: "chart.pie.fill") { DashboardView() }
                    Tab("Transactions", systemImage: "list.bullet.rectangle") { TransactionListView() }
                    Tab("Accounts", systemImage: "creditcard.fill") { AccountsView() }
                    Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button { showQuickAdd = true } label: {
                        Image(systemName: "plus").font(.title2.bold()).padding(18)
                            .background(Color.accentColor, in: Circle()).foregroundStyle(.white).shadow(radius: 6, y: 3)
                    }
                    .padding(.trailing, 20).padding(.bottom, 70)
                    .accessibilityLabel("Add transaction")
                }
                .sheet(isPresented: $showQuickAdd) { QuickAddView() }
                .sheet(item: $pendingImportURL) { url in StatementImportView(url: url) }
            }
        }
        .onOpenURL { url in
            if url.pathExtension.lowercased() == "pdf" { pendingImportURL = url }
        }
        .tint(Color(hex: "#FF5A0A"))
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }
