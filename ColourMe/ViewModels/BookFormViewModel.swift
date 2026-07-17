import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class BookFormViewModel {
    enum Stage {
        case form
        case generating
        case preview
        case library
        case savedBook
    }

    var stage: Stage = .form
    var theme = ""
    var pageCount = 8
    var complexity: ComplexityLevel = .standard
    var childName = ""
    var selectedModelID = UserDefaults.standard.string(forKey: "defaultModelID") ?? Constants.defaultImageModelID
    var availableModels: [ImageModel] = []
    var errorMessage: String?

    var savedBooks: [SavedBook] = []
    var openedBook: SavedBook?
    var openedBookImages: [Data] = []

    let generator = BookGenerator()
    private let client = OpenRouterClient()
    private var generationTask: Task<Void, Never>?
    private var currentBook: SavedBook?

    var hasAPIKey: Bool {
        KeyState.shared.hasKey
    }

    var canGenerate: Bool {
        hasAPIKey && !theme.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var spec: BookSpec {
        BookSpec(
            theme: theme.trimmingCharacters(in: .whitespacesAndNewlines),
            pageCount: pageCount,
            complexity: complexity,
            childName: childName.isEmpty ? nil : childName,
            modelID: selectedModelID
        )
    }

    private var selectedModel: ImageModel {
        availableModels.first { $0.id == selectedModelID } ?? .fallback(id: selectedModelID)
    }

    var estimatedBookCostLabel: String? {
        guard let perPage = selectedModel.estimatedPricePerPage else { return nil }
        return String(format: "Estimated cost: ~$%.2f for %d pages", perPage * Double(pageCount), pageCount)
    }

    func loadModels() async {
        guard hasAPIKey, availableModels.isEmpty else { return }
        do {
            var models = try await client.listImageModels()
            // Keep the current selection valid even if it is not in the list,
            // otherwise the picker renders empty.
            if !models.contains(where: { $0.id == selectedModelID }) {
                models.insert(.fallback(id: selectedModelID), at: 0)
            }
            availableModels = models
        } catch {
            // Non-fatal: the picker falls back to the default model id.
        }
    }

    // MARK: - Generation

    func generate() {
        errorMessage = nil
        UserDefaults.standard.set(selectedModelID, forKey: "defaultModelID")
        stage = .generating
        currentBook = nil
        let spec = spec
        let model = selectedModel
        generationTask = Task {
            await generator.generate(spec: spec, model: model)
            archiveCurrentBook(spec: spec)
            let hasPages = generator.pages.contains { $0.status.imageData != nil }
            // Cancelled with nothing generated: back to the form. Otherwise
            // show what we have (including failures, which can be retried).
            stage = hasPages || !Task.isCancelled ? .preview : .form
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
    }

    func regenerate(pageID: UUID) async {
        await generator.regenerate(pageID: pageID)
        archiveCurrentBook(spec: spec)
    }

    /// Books archive themselves the moment generation finishes - clicking
    /// Back can never lose a paid-for book.
    private func archiveCurrentBook(spec: BookSpec) {
        guard generator.pages.contains(where: { $0.status.imageData != nil }) else { return }
        do {
            if let book = currentBook {
                currentBook = try BookStore.update(book, pages: generator.pages, cost: generator.totalCost)
            } else {
                currentBook = try BookStore.save(spec: spec, pages: generator.pages, cost: generator.totalCost)
            }
        } catch {
            errorMessage = "Could not archive the book: \(error.localizedDescription)"
        }
    }

    func startOver() {
        stage = .form
    }

    // MARK: - Library

    func openLibrary() {
        savedBooks = BookStore.list()
        stage = .library
    }

    func openSavedBook(_ book: SavedBook) {
        openedBook = book
        openedBookImages = BookStore.pageImages(for: book)
        stage = .savedBook
    }

    func deleteSavedBook(_ book: SavedBook) {
        try? BookStore.delete(book)
        savedBooks = BookStore.list()
    }

    var moveTargets: [SavedBook] {
        guard let openedBook else { return [] }
        return BookStore.list().filter { $0.id != openedBook.id }
    }

    func movePage(at index: Int, to target: SavedBook) {
        guard let book = openedBook else { return }
        do {
            let result = try BookStore.movePage(at: index, from: book, to: target)
            openedBook = result.source
            openedBookImages = BookStore.pageImages(for: result.source)
            savedBooks = BookStore.list()
        } catch {
            errorMessage = "Could not move the page: \(error.localizedDescription)"
        }
    }

    // MARK: - PDF export

    func exportPDF() {
        exportPDF(spec: spec, pages: generator.pages)
    }

    func exportOpenedBookPDF() {
        guard let book = openedBook else { return }
        let pages = zip(book.subjects, openedBookImages).enumerated().map { index, pair in
            GeneratedPage(index: index, subject: pair.0, status: .done(pair.1))
        }
        exportPDF(spec: book.spec, pages: pages)
    }

    private func exportPDF(spec: BookSpec, pages: [GeneratedPage]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(spec.title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PDFBuilder.buildPDF(spec: spec, pages: pages)
            try data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
