import Foundation
import SwiftData
import LedgerCore
import LedgerParsing

/// One statement row plus what the app intends to do with it. Shown on the review screen before commit.
public struct ReviewItem: Identifiable, Sendable {
    public enum Status: Sendable, Equatable { case new, duplicate(of: UUID), needsAttention(String) }
    public let id: String
    public var row: StatementRow
    public var status: Status
    public var include: Bool
    public var resolvedType: TransactionType
    public var toAccountID: UUID?
    public var categoryName: String?

    public var isDuplicate: Bool { if case .duplicate = status { return true }; return false }
}

public struct ImportPreview: Sendable {
    public var fileName: String
    public var metadata: StatementMetadata
    public var items: [ReviewItem]
    public var reconciles: Bool
    public var newCount: Int { items.filter { !$0.isDuplicate }.count }
    public var duplicateCount: Int { items.filter(\.isDuplicate).count }
}

public enum ImportError: Error, Sendable {
    case unknownBank
    case accountRequired
}

public struct StatementImportPipeline: Sendable {
    public init() {}

    /// Step 1: extract, detect bank, parse, dedup, and detect own-account transfers. No writes.
    @MainActor
    public func preview(url: URL, password: String? = nil, targetAccount: Account, context: ModelContext) async throws -> ImportPreview {
        let pages = try await PDFTextExtractor().extractPages(from: url, password: password)
        guard let parser = StatementParserRegistry.parser(for: pages.first ?? "") else { throw ImportError.unknownBank }
        let parsed = try parser.parse(pages: pages)

        let dedup = DeduplicationService()
        let matcher = TransferMatcher()
        let rules = RulesEngine()

        var items: [ReviewItem] = []
        for row in parsed.rows {
            let hash = Hashing.sourceHash(parser.bankID, row.rawBlock)
            var status: ReviewItem.Status = .new
            var resolvedType = row.type
            var toAccountID: UUID? = nil

            // Own-account transfer: counterparty last4 belongs to another of the user's accounts.
            if let own = try matcher.ownAccount(matchingLast4: row.counterpartyLast4, excluding: targetAccount, in: context) {
                resolvedType = .transfer
                toAccountID = own.id
            }
            let verdict = try dedup.checkStatementRow(amount: row.amount, type: resolvedType == .transfer ? row.type : resolvedType,
                                                       date: row.date, accountID: targetAccount.id, sourceHash: hash,
                                                       externalRef: row.externalRef, in: context)
            if case .duplicate(let id) = verdict { status = .duplicate(of: id) }
            // A transfer already captured from the other side (e.g. SCB SMS debit) also counts as a duplicate.
            if status == .new, resolvedType == .transfer, let toAccountID {
                let mirror = try dedup.checkStatementRow(amount: row.amount, type: row.type == .income ? .expense : .income,
                                                          date: row.date, accountID: toAccountID, sourceHash: nil, externalRef: nil, in: context)
                if case .duplicate(let id) = mirror { status = .duplicate(of: id) }
            }
            let category = try rules.categorize(.init(merchant: row.counterparty, note: row.bankTypeLabel, amount: row.amount), in: context)

            items.append(ReviewItem(id: hash, row: row, status: status, include: status == .new, resolvedType: resolvedType,
                                    toAccountID: toAccountID, categoryName: category?.name))
        }
        return ImportPreview(fileName: url.lastPathComponent, metadata: parsed.metadata, items: items, reconciles: parsed.reconciles)
    }

    /// Step 2: write the included rows as one undoable batch.
    @MainActor
    @discardableResult
    public func commit(_ preview: ImportPreview, into account: Account, context: ModelContext) throws -> ImportBatch {
        let batch = ImportBatch(fileName: preview.fileName, bankName: preview.metadata.bankName,
                                periodStart: preview.metadata.periodStart, periodEnd: preview.metadata.periodEnd,
                                newCount: preview.items.filter(\.include).count, duplicateCount: preview.duplicateCount)
        context.insert(batch)
        let uncategorized = try DefaultCategories.uncategorized(in: context)
        let accounts = try context.fetch(FetchDescriptor<Account>())

        for item in preview.items where item.include {
            let row = item.row
            let category = try item.categoryName.flatMap { try DefaultCategories.find($0, in: context) }
            let tx: LedgerTransaction
            if item.resolvedType == .transfer, let toID = item.toAccountID, let other = accounts.first(where: { $0.id == toID }) {
                // Transfers are stored from the debited side.
                let from = row.type == .expense ? account : other
                let to = row.type == .expense ? other : account
                tx = LedgerTransaction(amount: row.amount, type: .transfer, date: row.date, merchant: "Transfer to \(to.name)",
                                 account: from, category: nil, source: .pdf, note: row.bankTypeLabel,
                                 sourceRef: row.rawBlock, sourceHash: item.id, externalRef: row.externalRef,
                                 reportedBalance: row.balance, isReviewed: true)
                tx.toAccount = to
            } else {
                tx = LedgerTransaction(amount: row.amount, type: row.type, date: row.date, merchant: row.counterparty,
                                 account: account, category: category ?? uncategorized, source: .pdf, note: row.bankTypeLabel,
                                 sourceRef: row.rawBlock, sourceHash: item.id, externalRef: row.externalRef,
                                 reportedBalance: row.balance, isReviewed: category != nil)
            }
            if row.fee > 0 {
                let fee = LedgerTransaction(amount: row.fee, type: .expense, date: row.date, merchant: "\(preview.metadata.bankName) fee",
                                      account: account, category: try DefaultCategories.find("Fees & Charges", in: context),
                                      source: .pdf, note: "Service charge", sourceRef: row.rawBlock, isReviewed: true)
                fee.importBatch = batch
                context.insert(fee)
            }
            tx.importBatch = batch
            context.insert(tx)
        }
        try context.save()
        return batch
    }

    @MainActor
    public func undo(_ batch: ImportBatch, context: ModelContext) throws {
        context.delete(batch) // cascade removes its transactions
        try context.save()
    }
}
