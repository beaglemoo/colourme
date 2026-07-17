import Foundation

struct BookSpec: Sendable {
    var theme: String
    var pageCount: Int
    var complexity: ComplexityLevel
    var childName: String?
    var modelID: String
    var qualityTier: QualityTier = .standard
    var illustratedCover = true

    var title: String {
        let themeTitle = theme.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let base = "\(themeTitle) Colouring Book"
        if let name = childName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "\(name)'s \(base)"
        }
        return base
    }
}
