import Foundation

struct SavedBook: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var theme: String
    var complexity: ComplexityLevel
    var childName: String?
    var modelID: String
    var createdAt: Date
    var cost: Double
    var subjects: [String]

    var pageCount: Int { subjects.count }

    var spec: BookSpec {
        BookSpec(
            theme: theme,
            pageCount: pageCount,
            complexity: complexity,
            childName: childName,
            modelID: modelID
        )
    }
}
