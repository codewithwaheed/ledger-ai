import Foundation
import LedgerCore

/// NayaPay account statement PDF. Text extraction (PDFKit or pypdf) yields one record per block:
///
///     Service Charges Rs. 0
///     Outgoing fund transfer to Roman Afzal
///     easypaisa Bank-6088
///     Transaction ID 6a9847b4e5801b35e5136b4b
///     02 Sep 2026
///     08:58 PM
///     Raast Out -Rs. 1,250 Rs. 2,140.18
///
/// Type may wrap onto the line(s) before the amount line ("Bill Payment" / "(1LINK)" / "-Rs. 13,542 Rs. 25,978.18").
public struct NayaPayStatementParser: StatementParser {
    public let bankID = "nayapay"
    public let bankName = "NayaPay"
    public init() {}

    public func detect(pageOneText: String) -> Bool {
        pageOneText.localizedCaseInsensitiveContains("nayapay") && pageOneText.localizedCaseInsensitiveContains("Account Statement")
    }

    nonisolated(unsafe) private static let amountLine = try! NSRegularExpression(
        pattern: #"^(?<type>.*?)\s*(?<sign>[+-])\s*Rs\.?\s*(?<amount>[\d,]+(?:\.\d+)?)\s+Rs\.?\s*(?<balance>[\d,]+(?:\.\d+)?)\s*$"#)
    nonisolated(unsafe) private static let dateLine = try! NSRegularExpression(pattern: #"^\d{2} [A-Z][a-z]{2} \d{4}$"#)
    nonisolated(unsafe) private static let timeLine = try! NSRegularExpression(pattern: #"^\d{2}:\d{2} [AP]M$"#)
    nonisolated(unsafe) private static let refLine = try! NSRegularExpression(pattern: #"^Transaction ID\s*(?<ref>\S*)$"#)
    nonisolated(unsafe) private static let bareRef = try! NSRegularExpression(pattern: #"^[A-Za-z0-9]{20,}$"#)
    nonisolated(unsafe) private static let bankRef = try! NSRegularExpression(pattern: #"^(?<bank>[A-Za-z/ ]+?)\s*(?:Bank)?-(?<last4>\d{4})$"#)
    nonisolated(unsafe) private static let counterparty: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: #"^(?:Incoming|Outgoing) fund transfer (?:from|to)\s+(?<name>.+)$"#, options: .caseInsensitive), "transfer"),
        (try! NSRegularExpression(pattern: #"^Money (?:sent to|received from)\s+(?<name>.+)$"#, options: .caseInsensitive), "p2p"),
        (try! NSRegularExpression(pattern: #"^Paid to\s+(?<name>.+)$"#, options: .caseInsensitive), "bill"),
        (try! NSRegularExpression(pattern: #"^(?:Purchase|Payment) at\s+(?<name>.+)$"#, options: .caseInsensitive), "card"),
    ]

    /// Known bank type labels. Real-world PDFKit extraction glues these onto the front of the description
    /// line ("Raast In Incoming fund transfer from Waheed Ahmad"); "Bill Payment" alone stays on its own line.
    nonisolated(unsafe) private static let knownTypes = ["Raast In", "Raast Out", "IBFT Out", "IBFT In", "Peer to Peer", "Bill Payment"]

    public func parse(pages: [String]) throws -> ParsedStatement {
        var meta = parseMetadata(pages.first ?? "")
        var rows: [StatementRow] = []
        var block: [String] = []
        var fee: Decimal = 0

        for page in pages {
            for rawLine in page.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
                if line.hasPrefix("TIME TYPE DESCRIPTION") {
                    // Table header: marks the start of this page's rows, discarding any account-summary
                    // header text collected above it.
                    block = []
                    continue
                }
                if line.hasPrefix("Service Charges") {
                    fee = Money.parse(line.replacingOccurrences(of: "Service Charges", with: "")) ?? 0
                    continue
                }
                if let m = Self.amountLine.first(in: line) {
                    if let row = buildRow(lines: block, amountMatch: m, amountLineText: line, fee: fee, meta: meta) {
                        rows.append(row)
                    }
                    block = []
                    fee = 0
                    continue
                }
                block.append(line)
            }
        }
        meta.totalIn = rows.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        meta.totalOut = rows.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        meta.closingBalance = rows.max(by: { $0.date < $1.date })?.balance
        return ParsedStatement(metadata: meta, rows: rows)
    }

    private func buildRow(lines: [String], amountMatch m: RegexMatch, amountLineText: String, fee: Decimal, meta: StatementMetadata) -> StatementRow? {
        guard let dateText = lines.first(where: { Self.dateLine.matches($0) }) else { return nil }
        let timeText = lines.first(where: { Self.timeLine.matches($0) })

        var ref: String? = nil
        var contentLines: [String] = []
        for l in lines {
            if Self.dateLine.matches(l) || Self.timeLine.matches(l) { continue }
            if let rm = Self.refLine.first(in: l) { ref = rm["ref"].flatMap { $0.isEmpty ? nil : $0 }; continue }
            if Self.bareRef.matches(l) { if ref == nil { ref = l }; continue }
            contentLines.append(l)
        }

        // The type label ("Raast In", "Bill Payment", ...) can sit on its own line or glued onto the front of
        // the description line, and its position among the description lines is not fixed between renderings.
        var typeLabel = m["type"]?.trimmingCharacters(in: .whitespaces) ?? ""
        var description: [String] = []
        var typeIndex: Int? = nil
        for (i, l) in contentLines.enumerated() {
            guard typeIndex == nil, let matchedType = Self.knownTypes.first(where: { l.hasPrefix($0) }) else {
                description.append(l)
                continue
            }
            typeIndex = i
            typeLabel = matchedType
            let rest = String(l.dropFirst(matchedType.count)).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { description.append(rest) }
        }
        // A parenthesised continuation ("(1LINK)") right after the type line belongs to the type, not the description.
        if let idx = typeIndex, idx + 1 < contentLines.count {
            let next = contentLines[idx + 1]
            if next.hasPrefix("("), next.hasSuffix(")") {
                typeLabel += " " + next
                description.removeAll { $0 == next }
            }
        }

        guard let amount = Money.parse(m["amount"] ?? ""), amount > 0 else { return nil }
        let sign = m["sign"] ?? "-"
        let balance = Money.parse(m["balance"] ?? "")
        let date = Self.parseDate(dateText, time: timeText) ?? .now

        var name = description.first ?? typeLabel
        for (rx, _) in Self.counterparty {
            if let cm = rx.first(in: name), let n = cm["name"] { name = n; break }
        }
        var cpBank: String? = nil, cpLast4: String? = nil
        for l in description.dropFirst() {
            if let bm = Self.bankRef.first(in: l) {
                cpBank = bm["bank"]?.trimmingCharacters(in: .whitespaces)
                cpLast4 = bm["last4"]
                break
            }
        }
        // "SCB-5801" can also be glued onto the first description line in some renderings.
        if cpLast4 == nil, let bm = Self.bankRef.first(in: name) {
            cpBank = bm["bank"]; cpLast4 = bm["last4"]
        }

        return StatementRow(
            bankID: bankID, date: date, type: sign == "+" ? .income : .expense, amount: amount, balance: balance, fee: fee,
            bankTypeLabel: typeLabel, counterparty: SmsParser.cleanMerchant(name), counterpartyBank: cpBank, counterpartyLast4: cpLast4,
            externalRef: ref, descriptionLines: description, rawBlock: (lines + [amountLineText]).joined(separator: "\n"))
    }

    /// The summary-card numbers (opening/closing balance, total income/spent) extract in an order that varies
    /// by renderer and doesn't line up with their labels, so totals and closing balance are derived from the
    /// parsed rows instead (see `parse`). Only opening balance and the account number are read from the text
    /// here, since opening balance is reliably glued onto the IBAN line in every observed rendering.
    private func parseMetadata(_ text: String) -> StatementMetadata {
        var meta = StatementMetadata(bankID: bankID, bankName: bankName)
        if let m = try? NSRegularExpression(pattern: #"(\d{2} [A-Z][a-z]{2} \d{4})\s*-\s*(\d{2} [A-Z][a-z]{2} \d{4})"#).first(in: text) {
            meta.periodStart = Self.parseDate(m[1] ?? "", time: nil)
            meta.periodEnd = Self.parseDate(m[2] ?? "", time: nil)
        }
        if let m = try? NSRegularExpression(pattern: #"PK\d{2}NAYA\d*?(\d{4})\s+(?<opening>[\d,]+(?:\.\d{2})?)"#).first(in: text) {
            meta.accountLast4 = m[1]
            meta.openingBalance = m["opening"].flatMap(Money.parse)
        }
        return meta
    }

    private static func parseDate(_ date: String, time: String?) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        if let time {
            f.dateFormat = "dd MMM yyyy hh:mm a"
            if let d = f.date(from: "\(date) \(time)") { return d }
        }
        f.dateFormat = "dd MMM yyyy"
        return f.date(from: date)
    }
}

// MARK: - Small NSRegularExpression helpers

public struct RegexMatch {
    let text: NSString
    let result: NSTextCheckingResult
    public subscript(_ name: String) -> String? {
        let r = result.range(withName: name)
        return r.location == NSNotFound ? nil : text.substring(with: r)
    }
    public subscript(_ index: Int) -> String? {
        guard index < result.numberOfRanges else { return nil }
        let r = result.range(at: index)
        return r.location == NSNotFound ? nil : text.substring(with: r)
    }
}

public extension NSRegularExpression {
    func first(in s: String) -> RegexMatch? {
        let ns = s as NSString
        guard let m = firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return RegexMatch(text: ns, result: m)
    }
    func matches(_ s: String) -> Bool { first(in: s) != nil }
}
