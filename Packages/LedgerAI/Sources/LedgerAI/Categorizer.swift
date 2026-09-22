import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Picks a category from the user's own list when no rule matches. Returns nil below the confidence threshold.
public struct Categorizer: Sendable {
    public init() {}

    public struct Suggestion: Sendable { public let category: String; public let confidence: Double }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @Generable
    struct Pick {
        @Guide(description: "Exactly one category name copied verbatim from the provided list")
        var category: String
        @Guide(description: "Confidence from 0 to 1")
        var confidence: Double
    }
    #endif

    public func suggest(merchant: String, note: String, amount: Decimal, categories: [String], threshold: Double = 0.6) async -> Suggestion? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), ModelAvailability.isAvailable, !categories.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: """
        You categorize personal spending in Pakistan. Choose the single best category from the list. \
        Merchant names are often abbreviated card-terminal strings (e.g. "MAF HYPERMARKETS PAKIS" is Carrefour, a grocery store; \
        "TOTAL PARCO" is a fuel station; "LESCO" is an electricity utility). If unsure, pick "Uncategorized" with low confidence.
        """)
        let prompt = "Categories: \(categories.joined(separator: " | "))\nMerchant: \(merchant)\nNote: \(note)\nAmount: PKR \(amount)"
        do {
            let pick = try await session.respond(to: prompt, generating: Pick.self).content
            guard categories.contains(pick.category), pick.confidence >= threshold, pick.category != "Uncategorized" else { return nil }
            return Suggestion(category: pick.category, confidence: pick.confidence)
        } catch { return nil }
        #else
        return nil
        #endif
    }
}
