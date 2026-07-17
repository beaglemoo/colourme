import Foundation
import Observation

@MainActor
@Observable
final class BookGenerator {
    private(set) var pages: [GeneratedPage] = []
    private(set) var coverImage: Data?
    private(set) var totalCost: Double = 0
    private let client = OpenRouterClient()
    private var spec: BookSpec?
    private var model: ImageModel?

    var completedCount: Int {
        pages.filter { !$0.status.isBusy }.count
    }

    var isFinished: Bool {
        !pages.isEmpty && pages.allSatisfy { !$0.status.isBusy }
    }

    func generate(spec: BookSpec, model: ImageModel) async {
        self.spec = spec
        self.model = model
        totalCost = 0
        coverImage = nil

        var subjects = (try? await client.generatePageSubjects(
            theme: spec.theme, count: spec.pageCount, complexity: spec.complexity
        )) ?? []
        if subjects.count < spec.pageCount {
            let extras = PromptBuilder.fallbackSubjects(theme: spec.theme, count: spec.pageCount)
            subjects += extras.suffix(spec.pageCount - subjects.count)
        }

        pages = subjects.enumerated().map { GeneratedPage(index: $0.offset, subject: $0.element) }

        if spec.illustratedCover {
            await generateCover(spec: spec, model: model)
        }

        let batches = stride(from: 0, to: pages.count, by: Constants.maxConcurrentRequests).map {
            Array(pages.indices[$0..<min($0 + Constants.maxConcurrentRequests, pages.count)])
        }
        for batch in batches {
            if Task.isCancelled { break }
            await withTaskGroup(of: Void.self) { group in
                for index in batch {
                    group.addTask { await self.generatePage(at: index, seed: nil) }
                }
            }
        }
    }

    func regenerate(pageID: UUID) async {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        await generatePage(at: index, seed: Int.random(in: 1...1_000_000))
    }

    private func generateCover(spec: BookSpec, model: ImageModel) async {
        let prompt = PromptBuilder.coverPrompt(theme: spec.theme, complexity: spec.complexity)
        do {
            let result = try await client.generateImage(
                model: model, prompt: prompt, tier: spec.qualityTier, seed: nil
            )
            coverImage = result.data
            recordCost(result.cost)
        } catch {
            // A missing cover illustration never blocks the book; the cover
            // page falls back to title-only.
        }
    }

    private func generatePage(at index: Int, seed: Int?) async {
        guard let spec, let model, !Task.isCancelled else { return }
        pages[index].status = .generating
        let prompt = PromptBuilder.imagePrompt(subject: pages[index].subject, complexity: spec.complexity)
        do {
            let result = try await client.generateImage(
                model: model, prompt: prompt, tier: spec.qualityTier, seed: seed
            )
            pages[index].status = .done(result.data)
            recordCost(result.cost)
        } catch is CancellationError {
            pages[index].status = .pending
        } catch let error as URLError where error.code == .cancelled {
            pages[index].status = .pending
        } catch {
            pages[index].status = .failed(error.localizedDescription)
        }
    }

    private func recordCost(_ cost: Double?) {
        guard let cost, cost > 0, let spec else { return }
        totalCost += cost
        PriceMemory.record(modelID: spec.modelID, tier: spec.qualityTier, pageCost: cost)
    }
}
