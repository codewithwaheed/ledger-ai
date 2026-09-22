import Foundation
import SwiftData
import LedgerCore
import LedgerParsing
import LedgerAI
#if canImport(UserNotifications)
import UserNotifications
#endif

/// The single entry point for an incoming bank message, whether it arrives from the Shortcuts automation or is pasted
/// in the app's test screen. Trusted-sender check → template parse → AI fallback → dedup → transfer detection → save → notify.
public struct IngestionService: Sendable {
    public init() {}

    public enum Result: Sendable, Equatable {
        case saved(transactionID: UUID, merchant: String, amount: Decimal, type: TransactionType, viaAI: Bool)
        case duplicate(of: UUID)
        case ignoredUntrustedSender(String)
        case ignoredByPattern(String)
        case unparsed(itemID: UUID)
    }

    @MainActor
    public func ingest(sender rawSender: String, body: String, receivedAt: Date = .now, notify: Bool = true,
                       context: ModelContext) async throws -> Result {
        let sender = TrustedSender.normalize(rawSender)
        let senders = try context.fetch(FetchDescriptor<TrustedSender>())
        guard let trusted = senders.first(where: { $0.senderID == sender }) else {
            // Body is intentionally NOT stored for untrusted senders.
            return .ignoredUntrustedSender(sender)
        }
        trusted.receivedCount += 1
        trusted.lastReceivedAt = receivedAt

        let set = BuiltInTemplates.set(id: trusted.templateSetID) ?? BuiltInTemplates.genericPakistan
        var parsed: ParsedTransaction?
        var viaAI = false
        switch SmsParser().parse(body, using: set, receivedAt: receivedAt) {
        case .ignored(let reason):
            trusted.ignoredCount += 1
            try context.save()
            return .ignoredByPattern(reason)
        case .parsed(let p): parsed = p
        case .unparsed:
            parsed = await TransactionExtractor().extract(sms: body, receivedAt: receivedAt)
            viaAI = parsed != nil
        }
        guard let p = parsed else {
            let item = UnparsedItem(sender: sender, body: body, receivedAt: receivedAt)
            context.insert(item)
            try context.save()
            if notify { await Self.notify(title: "Couldn't read a message from \(trusted.displayName)", body: "Open Ledger to add it manually.") }
            return .unparsed(itemID: item.id)
        }

        let hash = Hashing.sourceHash(sender, body)
        let account = try TransferMatcher().accountOwning(last4: p.accountLast4, in: context) ?? trusted.defaultAccount
        if case .duplicate(let id) = try DeduplicationService().check(amount: p.amount, type: p.type, date: p.date,
                                                                    accountID: account?.id, sourceHash: hash, in: context) {
            try context.save()
            return .duplicate(of: id)
        }

        let tx = try Self.makeTransaction(from: p, account: account, sender: sender, hash: hash, source: viaAI ? .ai : .sms, context: context)
        context.insert(tx)
        try context.save()

        if notify {
            let verb = tx.type == .income ? "received from" : (tx.type == .transfer ? "moved to" : "spent at")
            await Self.notify(title: "\(Money.format(tx.amount)) \(verb) \(tx.merchant)",
                              body: tx.isReviewed ? (tx.category?.name ?? "") : "Tap to categorize")
        }
        return .saved(transactionID: tx.id, merchant: tx.merchant, amount: tx.amount, type: tx.type, viaAI: viaAI)
    }

    @MainActor
    static func makeTransaction(from p: ParsedTransaction, account: Account?, sender: String, hash: String,
                                source: TransactionSource, context: ModelContext) throws -> LedgerTransaction {
        // Own-account transfer detection (e.g. SCB debit whose counterparty is the user's NayaPay account).
        if let other = try TransferMatcher().ownAccount(matchingLast4: p.counterpartyLast4, excluding: account, in: context) {
            let from = p.type == .expense ? account : other
            let to = p.type == .expense ? other : account
            let tx = LedgerTransaction(amount: p.amount, type: .transfer, date: p.date, merchant: "Transfer to \(to?.name ?? "account")",
                                 account: from, source: source, note: p.channel ?? "", sourceRef: p.raw, sourceHash: hash,
                                 reportedBalance: p.reportedBalance, isReviewed: true)
            tx.toAccount = to
            return tx
        }
        var category = try RulesEngine().categorize(.init(merchant: p.merchant, note: p.channel ?? "", sender: sender, amount: p.amount), in: context)
        if category == nil, let suggested = BuiltInTemplates.set(id: "scb-pk")?.templates.first(where: { $0.id == p.templateID })?.suggestedCategory {
            category = try DefaultCategories.find(suggested, in: context)
        }
        let reviewed = category != nil && source != .ai
        let finalCategory = try category ?? DefaultCategories.uncategorized(in: context)
        return LedgerTransaction(amount: p.amount, type: p.type, date: p.date, merchant: p.merchant, account: account,
                           category: finalCategory, source: source,
                           note: p.channel ?? "", sourceRef: p.raw, sourceHash: hash, externalRef: p.externalRef,
                           reportedBalance: p.reportedBalance, isReviewed: reviewed)
    }

    static func notify(title: String, body: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        #endif
    }
}
