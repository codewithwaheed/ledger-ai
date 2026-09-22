import Foundation
import SwiftData

public enum LedgerSchema {
    public static let models: [any PersistentModel.Type] = [
        Account.self, LedgerTransaction.self, TransactionCategory.self, Rule.self,
        TrustedSender.self, ImportBatch.self, UnparsedItem.self, Budget.self
    ]

    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(models), configurations: [config])
    }
}
