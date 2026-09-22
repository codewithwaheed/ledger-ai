import Foundation
import SwiftData

@Model
public final class TransactionCategory {
    public var id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var sortOrder: Int
    public var isSystem: Bool

    public var parent: TransactionCategory?
    @Relationship(deleteRule: .nullify, inverse: \TransactionCategory.parent)
    public var children: [TransactionCategory] = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.category)
    public var transactions: [LedgerTransaction] = []

    public init(name: String, icon: String, colorHex: String, sortOrder: Int = 0, isSystem: Bool = false, parent: TransactionCategory? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.parent = parent
    }

    public var fullName: String {
        if let parent { return "\(parent.name) / \(name)" }
        return name
    }
}
