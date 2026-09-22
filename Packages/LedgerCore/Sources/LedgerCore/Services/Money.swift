import Foundation

public enum Money {
    /// "Rs 12,345" or "Rs 12,345.50". PKR is the default currency for this app.
    public static func format(_ amount: Decimal, currency: String = "PKR", showDecimals: Bool? = nil) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        let hasFraction = (amount as NSDecimalNumber).doubleValue.truncatingRemainder(dividingBy: 1) != 0
        let decimals = showDecimals ?? hasFraction
        f.minimumFractionDigits = decimals ? 2 : 0
        f.maximumFractionDigits = decimals ? 2 : 0
        let num = f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return currency == "PKR" ? "Rs \(num)" : "\(currency) \(num)"
    }

    /// Parses "30,000.00", "Rs. 1,250", "PKR 481" into a Decimal.
    public static func parse(_ text: String) -> Decimal? {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }
}
