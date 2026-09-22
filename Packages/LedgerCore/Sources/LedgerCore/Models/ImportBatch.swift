import Foundation
import SwiftData

@Model
public final class ImportBatch {
    public var id: UUID
    public var fileName: String
    public var bankName: String
    public var importedAt: Date
    public var periodStart: Date?
    public var periodEnd: Date?
    public var newCount: Int
    public var duplicateCount: Int

    @Relationship(deleteRule: .cascade, inverse: \LedgerTransaction.importBatch)
    public var transactions: [LedgerTransaction] = []

    public init(fileName: String, bankName: String, periodStart: Date?, periodEnd: Date?, newCount: Int, duplicateCount: Int) {
        self.id = UUID()
        self.fileName = fileName
        self.bankName = bankName
        self.importedAt = .now
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.newCount = newCount
        self.duplicateCount = duplicateCount
    }
}
