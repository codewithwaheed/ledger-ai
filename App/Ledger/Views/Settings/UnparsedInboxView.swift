import SwiftUI
import SwiftData
import LedgerCore

struct UnparsedInboxView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UnparsedItem.receivedAt, order: .reverse) private var items: [UnparsedItem]
    @State private var converting: UnparsedItem?

    var body: some View {
        List {
            ForEach(items.filter { $0.status == .open }) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(item.sender) · \(item.receivedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    Text(item.body).font(.callout)
                    HStack {
                        Button("Add manually") { converting = item }
                        Spacer()
                        Button("Dismiss", role: .destructive) { item.status = .dismissed; try? context.save() }
                    }.buttonStyle(.borderless).font(.callout)
                }
            }
        }
        .overlay { if items.filter({ $0.status == .open }).isEmpty { ContentUnavailableView("Nothing to review", systemImage: "checkmark.circle") } }
        .navigationTitle("Unparsed inbox")
        .sheet(item: $converting) { item in
            QuickAddView().onDisappear { item.status = .converted; try? context.save() }
        }
    }
}
