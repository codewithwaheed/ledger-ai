import Foundation
import LedgerCore
import LedgerParsing
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Fallback extraction when no regex template matches. Output is always flagged for review.
public struct TransactionExtractor: Sendable {
    public init() {}

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable(description: "A bank transaction extracted from a notification message")
    struct Extracted {
        @Guide(description: "Amount of money moved, as a positive number without currency symbols or thousands separators")
        var amount: Double
        @Guide(description: "true if money left the customer's account (payment, withdrawal, transfer out); false if money came in")
        var isDebit: Bool
        @Guide(description: "Merchant, payee, or sender name. Use 'ATM Withdrawal' for cash withdrawals. Keep it short.")
        var merchant: String
        @Guide(description: "Last 4 digits of the customer's account or card, if present")
        var accountLast4: String?
        @Guide(description: "Transaction date as DD-MM-YY if present in the message")
        var date: String?
        @Guide(description: "Balance remaining after the transaction, if the message states one")
        var balance: Double?
    }
    #endif

    public func extract(sms body: String, receivedAt: Date) async -> ParsedTransaction? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), ModelAvailability.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
        You extract structured bank transaction data from SMS notifications sent by Pakistani banks. \
        Amounts are in PKR and may be written as "PKR 1,250.00" or "Rs. 1,250". Never invent fields that are not in the message.
        """)
        do {
            let response = try await session.respond(to: "Message: \(body)", generating: Extracted.self)
            let e = response.content
            guard e.amount > 0 else { return nil }
            var date = receivedAt
            if let d = e.date {
                let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "dd-MM-yy"
                if let parsed = f.date(from: d) { date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: parsed) ?? parsed }
            }
            return ParsedTransaction(
                amount: Decimal(e.amount), type: e.isDebit ? .expense : .income, date: date,
                merchant: SmsParser.cleanMerchant(e.merchant), accountLast4: SmsParser.last4(from: e.accountLast4),
                reportedBalance: e.balance.map { Decimal($0) }, templateID: "ai.extract", raw: body)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
