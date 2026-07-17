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
    var hasCover: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, title, theme, complexity, childName, modelID, createdAt, cost, subjects
        case hasCover
    }

    init(id: UUID, title: String, theme: String, complexity: ComplexityLevel, childName: String?,
         modelID: String, createdAt: Date, cost: Double, subjects: [String], hasCover: Bool = false) {
        self.id = id
        self.title = title
        self.theme = theme
        self.complexity = complexity
        self.childName = childName
        self.modelID = modelID
        self.createdAt = createdAt
        self.cost = cost
        self.subjects = subjects
        self.hasCover = hasCover
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        theme = try c.decode(String.self, forKey: .theme)
        complexity = try c.decode(ComplexityLevel.self, forKey: .complexity)
        childName = try c.decodeIfPresent(String.self, forKey: .childName)
        modelID = try c.decode(String.self, forKey: .modelID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        cost = try c.decode(Double.self, forKey: .cost)
        subjects = try c.decode([String].self, forKey: .subjects)
        hasCover = try c.decodeIfPresent(Bool.self, forKey: .hasCover) ?? false
    }

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
