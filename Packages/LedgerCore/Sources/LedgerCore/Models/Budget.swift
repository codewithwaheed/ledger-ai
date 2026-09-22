import Foundation
import SwiftData

@Model
public final class Budget {
    public var id: UUID
    public var monthlyLimit: Decimal
    public var startMonth: Date
    public var category: TransactionCategory?

    public init(category: TransactionCategory, monthlyLimit: Decimal, startMonth: Date = .now) {
        self.id = UUID()
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.startMonth = startMonth
    }
}
