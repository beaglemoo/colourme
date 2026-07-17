import Foundation

enum ComplexityLevel: String, CaseIterable, Identifiable, Codable {
    case simple
    case standard
    case detailed
    case intricate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        case .intricate: return "Intricate"
        }
    }

    var subtitle: String {
        switch self {
        case .simple: return "One big shape, extra-thick lines. Ages 2-4."
        case .standard: return "Clear subject, light background. Ages 5-7."
        case .detailed: return "Fuller scene, smaller areas. Ages 8-12."
        case .intricate: return "Fine-line patterns and rich detail. Teens and adults."
        }
    }

    var promptModifier: String {
        switch self {
        case .simple:
            return "Very simple composition with one large friendly subject, extra-thick bold outlines, big open areas to colour, no background clutter. Suitable for a toddler."
        case .standard:
            return "Simple scene with a clear main subject and a light background, thick clean outlines, medium-sized areas to colour. Suitable for a young child aged 5 to 7."
        case .detailed:
            return "A fuller scene with more detail and smaller areas to colour, clean medium-weight outlines. Suitable for an older child aged 8 to 12."
        case .intricate:
            return "Highly detailed intricate line art with fine lines, decorative patterns, ornamental textures, and many small areas to colour, in the style of an adult colouring book. Suitable for teenagers and adults."
        }
    }
}
