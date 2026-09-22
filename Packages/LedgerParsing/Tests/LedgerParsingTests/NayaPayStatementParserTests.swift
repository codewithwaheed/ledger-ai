import Testing
import Foundation
@testable import LedgerParsing
import LedgerCore

@Suite("NayaPay statement")
struct NayaPayStatementParserTests {
    static func fixturePages() throws -> [String] {
        let url = Bundle.module.url(forResource: "nayapay_sep2026_extracted", withExtension: "txt", subdirectory: "Fixtures")!
        // The fixture is all pages concatenated; the parser only needs page 1 separately for metadata.
        let text = try String(contentsOf: url, encoding: .utf8)
        let parts = text.components(separatedBy: "CARRIED FORWARD")
        return parts
    }

    @Test("detects bank and parses all 18 rows")
    func parsesAll() throws {
        let pages = try Self.fixturePages()
        let parser = StatementParserRegistry.parser(for: pages[0])
        #expect(parser?.bankID == "nayapay")
        let result = try NayaPayStatementParser().parse(pages: pages)
        #expect(result.rows.count == 18)
        #expect(result.metadata.accountLast4 == "8688")
        #expect(result.metadata.totalIn == Decimal(50600))
        #expect(result.metadata.totalOut == Decimal(49986))
        #expect(result.reconciles)
    }

    /// PDFKit's `PDFPage.string` puts the type label and description before the date/time and amount line,
    /// not after, and the type label is glued onto the description rather than trailing on its own line.
    /// This fixture captures that real ordering (see the NayaPay import that returned zero rows).
    static func pdfKitOrderPages() throws -> [String] {
        let url = Bundle.module.url(forResource: "nayapay_sep2026_pdfkit_order", withExtension: "txt", subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.components(separatedBy: "=== PAGE ").dropFirst().map {
            String($0.drop(while: { $0 != "\n" }).dropFirst())
        }
    }

    @Test("parses all 18 rows from real PDFKit line ordering")
    func parsesPdfKitOrder() throws {
        let result = try NayaPayStatementParser().parse(pages: try Self.pdfKitOrderPages())
        #expect(result.rows.count == 18)
        #expect(result.reconciles)
        let first = result.rows[0]
        #expect(first.counterparty == "Waheed Ahmad")
        #expect(first.bankTypeLabel == "Raast In")
        let bill = result.rows.first { $0.counterparty == "LESCO" }
        #expect(bill?.bankTypeLabel == "Bill Payment (1LINK)")
    }

    @Test("row details")
    func rowDetails() throws {
        let result = try NayaPayStatementParser().parse(pages: try Self.fixturePages())
        let first = result.rows[0]
        #expect(first.type == .income)
        #expect(first.amount == Decimal(2000))
        #expect(first.balance == Decimal(string: "3390.18"))
        #expect(first.counterparty == "Waheed Ahmad")
        #expect(first.counterpartyBank == "SCB")
        #expect(first.counterpartyLast4 == "5801")
        #expect(first.externalRef == "SCBLPKKA20260902788322678825305")
        #expect(first.bankTypeLabel == "Raast In")

        let bill = result.rows.first { $0.counterparty == "LESCO" }!
        #expect(bill.bankTypeLabel == "Bill Payment (1LINK)")
        #expect(bill.amount == Decimal(13542))

        let jazz = result.rows.first { $0.counterparty == "Ali Zaman" }!
        #expect(jazz.counterpartyBank == "JazzCash/Mobilink MFB")
        #expect(jazz.counterpartyLast4 == "6180")
    }
}
