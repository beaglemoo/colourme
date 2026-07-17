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
    }

    var stage: Stage = .form
    var theme = ""
    var pageCount = 8
    var complexity: ComplexityLevel = .standard
    var childName = ""
    var selectedModelID = UserDefaults.standard.string(forKey: "defaultModelID") ?? Constants.defaultImageModelID
    var availableModels: [ImageModel] = []
    var errorMessage: String?

    let generator = BookGenerator()
    private let client = OpenRouterClient()

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

    func generate() async {
        errorMessage = nil
        UserDefaults.standard.set(selectedModelID, forKey: "defaultModelID")
        stage = .generating
        await generator.generate(spec: spec, model: selectedModel)
        stage = .preview
    }

    func startOver() {
        stage = .form
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(spec.title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PDFBuilder.buildPDF(spec: spec, pages: generator.pages)
            try data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
