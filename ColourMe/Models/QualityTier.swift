import Foundation

enum QualityTier: String, CaseIterable, Identifiable, Codable {
    case draft
    case standard
    case fine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .standard: return "Standard"
        case .fine: return "Fine"
        }
    }

    var subtitle: String {
        switch self {
        case .draft: return "Cheapest, slightly simpler lines."
        case .standard: return "Good balance for printing."
        case .fine: return "Highest detail, costs the most."
        }
    }

    /// Value for OpenAI-style `quality` parameter.
    var openAIQuality: String {
        switch self {
        case .draft: return "low"
        case .standard: return "medium"
        case .fine: return "high"
        }
    }

    /// Value for `resolution` parameter, picked from what the model offers.
    func resolution(from available: [String]) -> String? {
        let preferred: [String]
        switch self {
        case .draft: preferred = ["512", "1K"]
        case .standard: preferred = ["1K"]
        case .fine: preferred = ["2K", "1K"]
        }
        return preferred.first { available.contains($0) } ?? available.first
    }

    /// Estimate multiplier applied to the standard-tier static heuristic
    /// until real observed prices are learned.
    func estimateMultiplier(supportsQuality: Bool) -> Double {
        switch self {
        case .draft: return supportsQuality ? 0.25 : 0.5
        case .standard: return 1
        case .fine: return supportsQuality ? 4 : 2.5
        }
    }
}
