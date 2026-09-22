import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps Apple's on-device Foundation Models availability. Every AI feature in the app checks this first and
/// degrades to the regex/rules path when the model is missing (non-Apple-Intelligence device, AI disabled, etc.).
public enum ModelAvailability {
    public enum State: Sendable, Equatable {
        case available
        case unavailable(reason: String)
    }

    public static var state: State {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(let reason): return .unavailable(reason: String(describing: reason))
            }
        }
        #endif
        return .unavailable(reason: "Foundation Models framework not present on this OS")
    }

    public static var isAvailable: Bool { state == .available }
}
