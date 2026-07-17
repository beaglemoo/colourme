import Foundation

/// Persists finished books to Application Support so a misclick never loses
/// a generated (and paid-for) book. Layout: Books/<uuid>/book.json + page-N.png.
@MainActor
enum BookStore {
    static var booksDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "ColourMe/Books")
    }

    private static func directory(for id: UUID) -> URL {
        booksDirectory.appending(path: id.uuidString)
    }

    @discardableResult
    static func save(spec: BookSpec, pages: [GeneratedPage], cost: Double, coverImage: Data?) throws -> SavedBook {
        let done = pages.filter { $0.status.imageData != nil }
        let book = SavedBook(
            id: UUID(),
            title: spec.title,
            theme: spec.theme,
            complexity: spec.complexity,
            childName: spec.childName,
            modelID: spec.modelID,
            createdAt: Date(),
            cost: cost,
            subjects: done.map(\.subject),
            hasCover: coverImage != nil
        )
        try write(book, images: done.compactMap { $0.status.imageData }, coverImage: coverImage)
        return book
    }

    static func update(_ book: SavedBook, pages: [GeneratedPage], cost: Double, coverImage: Data?) throws -> SavedBook {
        let done = pages.filter { $0.status.imageData != nil }
        var updated = book
        updated.cost = cost
        updated.subjects = done.map(\.subject)
        updated.hasCover = coverImage != nil
        try write(updated, images: done.compactMap { $0.status.imageData }, coverImage: coverImage)
        return updated
    }

    static func list() -> [SavedBook] {
        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: booksDirectory, includingPropertiesForKeys: nil
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return dirs
            .compactMap { dir -> SavedBook? in
                guard let data = try? Data(contentsOf: dir.appending(path: "book.json")) else { return nil }
                return try? decoder.decode(SavedBook.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func pageImages(for book: SavedBook) -> [Data] {
        let dir = directory(for: book.id)
        return (0..<book.pageCount).compactMap {
            try? Data(contentsOf: dir.appending(path: "page-\($0).png"))
        }
    }

    static func firstPageImage(for book: SavedBook) -> Data? {
        try? Data(contentsOf: directory(for: book.id).appending(path: "page-0.png"))
    }

    static func coverImage(for book: SavedBook) -> Data? {
        guard book.hasCover else { return nil }
        return try? Data(contentsOf: directory(for: book.id).appending(path: "cover.png"))
    }

    static func delete(_ book: SavedBook) throws {
        try FileManager.default.removeItem(at: directory(for: book.id))
    }

    /// Moves one page (image + subject) from one archived book to the end of
    /// another. Returns both books with updated metadata.
    static func movePage(at index: Int, from source: SavedBook, to target: SavedBook) throws -> (source: SavedBook, target: SavedBook) {
        var sourceImages = pageImages(for: source)
        var sourceBook = source
        guard sourceImages.indices.contains(index), sourceBook.subjects.indices.contains(index) else {
            return (source, target)
        }
        let image = sourceImages.remove(at: index)
        let subject = sourceBook.subjects.remove(at: index)

        var targetImages = pageImages(for: target)
        var targetBook = target
        targetImages.append(image)
        targetBook.subjects.append(subject)

        let sourceCover = coverImage(for: sourceBook)
        let targetCover = coverImage(for: targetBook)
        try write(sourceBook, images: sourceImages, coverImage: sourceCover)
        try write(targetBook, images: targetImages, coverImage: targetCover)
        return (sourceBook, targetBook)
    }

    private static func write(_ book: SavedBook, images: [Data], coverImage: Data?) throws {
        let dir = directory(for: book.id)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(book).write(to: dir.appending(path: "book.json"))
        for (index, image) in images.enumerated() {
            try image.write(to: dir.appending(path: "page-\(index).png"))
        }
        if let coverImage {
            try coverImage.write(to: dir.appending(path: "cover.png"))
        }
    }
}
