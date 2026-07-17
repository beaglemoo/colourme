import Foundation

/// Remembers what pages actually cost per model and tier so estimates match
/// reality after the first generation, regardless of how a provider bills.
enum PriceMemory {
    private static let key = "observedPageCosts"
    private static let smoothing = 0.4

    private static var table: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    private static func entryKey(modelID: String, tier: QualityTier) -> String {
        "\(modelID)|\(tier.rawValue)"
    }

    static func record(modelID: String, tier: QualityTier, pageCost: Double) {
        guard pageCost > 0 else { return }
        var current = table
        let k = entryKey(modelID: modelID, tier: tier)
        if let existing = current[k] {
            current[k] = existing * (1 - smoothing) + pageCost * smoothing
        } else {
            current[k] = pageCost
        }
        table = current
    }

    static func observedCost(modelID: String, tier: QualityTier) -> Double? {
        table[entryKey(modelID: modelID, tier: tier)]
    }
}
