import AppKit
import Foundation
import Observation
import PDFKit
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
    var qualityTier: QualityTier = QualityTier(
        rawValue: UserDefaults.standard.string(forKey: "qualityTier") ?? ""
    ) ?? .standard
    var illustratedCover = true
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
            modelID: selectedModelID,
            qualityTier: qualityTier,
            illustratedCover: illustratedCover
        )
    }

    private var selectedModel: ImageModel {
        availableModels.first { $0.id == selectedModelID } ?? .fallback(id: selectedModelID)
    }

    var estimatedBookCostLabel: String? {
        guard let perPage = selectedModel.estimatedPricePerPage(tier: qualityTier) else { return nil }
        let billedPages = pageCount + (illustratedCover ? 1 : 0)
        let learned = PriceMemory.observedCost(modelID: selectedModelID, tier: qualityTier) != nil
        let prefix = learned ? "Estimated cost (from your usage)" : "Estimated cost"
        return String(format: "%@: ~$%.2f for %d pages", prefix, perPage * Double(billedPages), pageCount)
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
        UserDefaults.standard.set(qualityTier.rawValue, forKey: "qualityTier")
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
                currentBook = try BookStore.update(
                    book, pages: generator.pages, cost: generator.totalCost, coverImage: generator.coverImage
                )
            } else {
                currentBook = try BookStore.save(
                    spec: spec, pages: generator.pages, cost: generator.totalCost, coverImage: generator.coverImage
                )
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

    var totalSpend: Double {
        savedBooks.reduce(0) { $0 + $1.cost }
    }

    func revealArchiveInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([BookStore.booksDirectory])
    }

    // MARK: - PDF export and printing

    func exportPDF() {
        exportPDF(spec: spec, pages: generator.pages, coverImage: generator.coverImage)
    }

    func exportOpenedBookPDF() {
        guard let book = openedBook else { return }
        exportPDF(spec: book.spec, pages: openedBookPages(book), coverImage: BookStore.coverImage(for: book))
    }

    func printCurrentBook() {
        printBook(spec: spec, pages: generator.pages, coverImage: generator.coverImage)
    }

    func printOpenedBook() {
        guard let book = openedBook else { return }
        printBook(spec: book.spec, pages: openedBookPages(book), coverImage: BookStore.coverImage(for: book))
    }

    private func openedBookPages(_ book: SavedBook) -> [GeneratedPage] {
        zip(book.subjects, openedBookImages).enumerated().map { index, pair in
            GeneratedPage(index: index, subject: pair.0, status: .done(pair.1))
        }
    }

    private func exportPDF(spec: BookSpec, pages: [GeneratedPage], coverImage: Data?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(spec.title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PDFBuilder.buildPDF(spec: spec, pages: pages, coverImage: coverImage)
            try data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printBook(spec: BookSpec, pages: [GeneratedPage], coverImage: Data?) {
        do {
            let data = try PDFBuilder.buildPDF(spec: spec, pages: pages, coverImage: coverImage)
            guard let document = PDFDocument(data: data) else {
                throw AppError.decoding("Could not prepare the PDF for printing")
            }
            let printInfo = NSPrintInfo.shared
            printInfo.paperSize = NSSize(width: PDFBuilder.a4.width, height: PDFBuilder.a4.height)
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            document.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false)?
                .run()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
