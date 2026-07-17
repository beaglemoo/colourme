import Foundation

struct ImageModel: Identifiable, Hashable, Sendable {
    var id: String
    var name: String?
    var supportedParameters: [String]
    var resolutionOptions: [String] = []
    var pricePerImageToken: Double?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return id.split(separator: "/").last.map(String.init) ?? id
    }

    func supports(_ parameter: String) -> Bool {
        supportedParameters.contains(parameter)
    }

    /// Tokens billed per generated image. Not exposed by the API, but fixed
    /// per model family; verified against real billed costs (within ~15%).
    private var estimatedTokensPerImage: Double {
        if id.hasPrefix("google/") { return 1290 }
        if id.hasPrefix("openai/") { return 1610 }
        return 4096
    }

    func estimatedPricePerPage(tier: QualityTier) -> Double? {
        if let observed = PriceMemory.observedCost(modelID: id, tier: tier) {
            return observed
        }
        guard let pricePerImageToken else { return nil }
        let base = pricePerImageToken * estimatedTokensPerImage
        return base * tier.estimateMultiplier(supportsQuality: supports("quality"))
    }

    func priceLabel(tier: QualityTier) -> String? {
        guard let price = estimatedPricePerPage(tier: tier) else { return nil }
        return String(format: "~$%.3f/page", price)
    }

    /// Used when the live model list could not be fetched. Only universally
    /// accepted parameters are assumed.
    static func fallback(id: String) -> ImageModel {
        ImageModel(id: id, name: nil, supportedParameters: [], pricePerImageToken: nil)
    }
}
