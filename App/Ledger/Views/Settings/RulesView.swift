import SwiftUI
import SwiftData
import LedgerCore

struct RulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Rule.priority) private var rules: [Rule]

    var body: some View {
        List {
            ForEach(rules) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(r.field.rawValue) \(r.op.rawValue) “\(r.value)”")
                        Text("→ \(r.category?.fullName ?? "?") · \(r.hitCount) hits · \(r.origin.rawValue)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { r.isEnabled }, set: { r.isEnabled = $0; try? context.save() })).labelsHidden()
                }
            }
            .onDelete { idx in idx.map { rules[$0] }.forEach(context.delete); try? context.save() }
            .onMove { from, to in
                var arr = rules; arr.move(fromOffsets: from, toOffset: to)
                for (i, r) in arr.enumerated() { r.priority = i }
                try? context.save()
            }
        }
        .overlay { if rules.isEmpty { ContentUnavailableView("No rules yet", systemImage: "list.bullet.indent", description: Text("Rules are created when you categorize a transaction and choose “Always categorize…”.")) } }
        .navigationTitle("Rules")
        .toolbar { EditButton() }
    }
}
