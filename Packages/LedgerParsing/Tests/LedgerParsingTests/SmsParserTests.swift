import Testing
import Foundation
@testable import LedgerParsing
import LedgerCore

@Suite("Standard Chartered SMS (9220)")
struct SmsParserTests {
    let parser = SmsParser()
    let set = BuiltInTemplates.standardChartered

    static func fixtureMessages() throws -> [String] {
        let url = Bundle.module.url(forResource: "scb_9220", withExtension: "txt", subdirectory: "Fixtures")!
        return try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    @Test("every fixture message parses")
    func allFixturesParse() throws {
        for msg in try Self.fixtureMessages() {
            guard case .parsed = parser.parse(msg, using: set) else { Issue.record("Unparsed: \(msg)"); continue }
        }
    }

    @Test("debit card purchase")
    func cardPayment() throws {
        let msg = "Dear Client, PKR 2,267.00 have been paid at TOTAL PARCO on 14-09-26 using Debit Card no. 53119xxxxxxxx4247."
        guard case .parsed(let tx) = parser.parse(msg, using: set) else { throw ParseError.noTemplateMatched }
        #expect(tx.amount == Decimal(2267))
        #expect(tx.type == .expense)
        #expect(tx.merchant == "TOTAL PARCO")
        #expect(tx.accountLast4 == "4247")
        #expect(tx.templateID == "scb.card_payment")
        let c = Calendar.current.dateComponents([.year, .month, .day], from: tx.date)
        #expect(c.day == 14 && c.month == 9 && c.year == 2026)
    }

    @Test("ATM withdrawal")
    func atm() throws {
        let msg = "Dear Client, PKR 30,000.00 were withdrawn from Account No. 0100xxx5801 on 14-09-26 using an ATM."
        guard case .parsed(let tx) = parser.parse(msg, using: set) else { throw ParseError.noTemplateMatched }
        #expect(tx.amount == Decimal(30000))
        #expect(tx.accountLast4 == "5801")
        #expect(tx.merchant == "ATM Withdrawal")
    }

    @Test("incoming IBFT credit")
    func credit() throws {
        let msg = "Dear Client, your account 01-00***58-01 has been credited with amount PKR 28,300.00 from account 02-76xxxxx-9805804 BISMA KARAMAT from IBFT 02/09/202 on 02/09/26."
        guard case .parsed(let tx) = parser.parse(msg, using: set) else { throw ParseError.noTemplateMatched }
        #expect(tx.type == .income)
        #expect(tx.amount == Decimal(28300))
        #expect(tx.accountLast4 == "5801")
        #expect(tx.merchant == "BISMA KARAMAT")
        #expect(tx.counterpartyLast4 == "5804")
        #expect(tx.channel == "IBFT")
    }

    @Test("OTP messages are ignored")
    func otpIgnored() {
        let r = parser.parse("Your OTP is 123456. Do not share it with anyone.", using: set)
        guard case .ignored = r else { Issue.record("expected .ignored, got \(r)"); return }
    }

    @Test("identical messages produce identical source hashes")
    func hashStable() {
        let a = Hashing.sourceHash("9220", "Dear Client, PKR 481.00 have been paid at MALMO BAKERS SWEETS on 14-09-26")
        let b = Hashing.sourceHash("9220", "Dear  Client, PKR 481.00 have been paid at MALMO BAKERS SWEETS on 14-09-26 ")
        #expect(a == b)
    }
}
