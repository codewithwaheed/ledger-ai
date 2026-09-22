import Foundation
import LedgerCore

public struct SmsParser: Sendable {
    public init() {}

    public enum Outcome: Sendable, Equatable {
        case parsed(ParsedTransaction)
        case ignored(reason: String)
        case unparsed
    }

    /// Tries templates in priority order. `receivedAt` is used when the message has no date, and to supply the year.
    public func parse(_ body: String, using set: SmsTemplateSet, receivedAt: Date = .now) -> Outcome {
        let text = body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        for ignore in set.ignorePatterns where text.range(of: ignore, options: [.regularExpression, .caseInsensitive]) != nil {
            return .ignored(reason: ignore)
        }
        for spec in set.templates.sorted(by: { $0.priority > $1.priority }) {
            if let tx = try? apply(spec, to: text, receivedAt: receivedAt) { return .parsed(tx) }
        }
        return .unparsed
    }

    public func apply(_ spec: SmsTemplateSpec, to text: String, receivedAt: Date) throws -> ParsedTransaction {
        guard let regex = try? NSRegularExpression(pattern: spec.pattern, options: [.caseInsensitive]) else {
            throw ParseError.badRegex(spec.pattern)
        }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            throw ParseError.noTemplateMatched
        }
        func group(_ name: String) -> String? {
            let r = m.range(withName: name)
            guard r.location != NSNotFound else { return nil }
            let s = ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }
        guard let amountText = group("amount"), let amount = Money.parse(amountText), amount > 0 else {
            throw ParseError.invalidAmount(group("amount") ?? "")
        }
        let date = try resolveDate(dateText: group("date"), timeText: group("time"), spec: spec, fallback: receivedAt)
        let accountLast4 = Self.last4(from: group("last4") ?? group("account"))
        return ParsedTransaction(
            amount: amount, type: spec.type, date: date,
            merchant: Self.cleanMerchant(group("merchant") ?? spec.defaultMerchant ?? "Unknown"),
            accountLast4: accountLast4,
            counterpartyLast4: Self.last4(from: group("cpLast4")),
            counterpartyBank: group("cpBank"),
            reportedBalance: group("balance").flatMap(Money.parse),
            externalRef: group("ref"),
            channel: group("channel"),
            templateID: spec.id, raw: text)
    }

    private func resolveDate(dateText: String?, timeText: String?, spec: SmsTemplateSpec, fallback: Date) throws -> Date {
        guard let dateText else { return fallback }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for fmt in spec.dateFormats {
            f.dateFormat = fmt
            if let d = f.date(from: dateText) {
                guard let timeText, let tf = spec.timeFormat else {
                    // Keep the wall-clock time from receipt if the SMS arrived on the same day; else noon to avoid TZ edge cases.
                    let cal = Calendar.current
                    if cal.isDate(d, inSameDayAs: fallback) { return fallback }
                    return cal.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d
                }
                f.dateFormat = "\(fmt) \(tf)"
                return f.date(from: "\(dateText) \(timeText)") ?? d
            }
        }
        throw ParseError.invalidDate(dateText)
    }

    /// "01-00***58-01" → "5801"; "53119xxxxxxxx4247" → "4247"; "0100xxx5801" → "5801".
    public static func last4(from text: String?) -> String? {
        guard let text else { return nil }
        let digits = text.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }

    public static func cleanMerchant(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,-"))
    }
}
