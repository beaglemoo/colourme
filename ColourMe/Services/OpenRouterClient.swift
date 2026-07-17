import Foundation

struct OpenRouterClient: Sendable {
    private let session = URLSession.shared

    func listImageModels() async throws -> [ImageModel] {
        async let pricingTask = try? listModelPricing()
        let request = try makeRequest(path: "images/models", method: "GET")
        let response: ImageModelsResponse = try await send(request)
        let pricing = await pricingTask ?? [:]
        return response.data
            .map {
                ImageModel(
                    id: $0.id,
                    name: $0.name,
                    supportedParameters: $0.supportedParameters ?? [],
                    pricePerImageToken: pricing[$0.id]
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Pricing only exists on the general models endpoint, not images/models.
    func listModelPricing() async throws -> [String: Double] {
        let request = try makeRequest(
            path: "models",
            method: "GET",
            queryItems: [URLQueryItem(name: "output_modalities", value: "image")]
        )
        let response: ModelsPricingResponse = try await send(request)
        return response.data.reduce(into: [:]) { result, item in
            if let raw = item.pricing?.imageOutput, let price = Double(raw), price > 0 {
                result[item.id] = price
            }
        }
    }

    func generatePageSubjects(theme: String, count: Int, complexity: ComplexityLevel) async throws -> [String] {
        let prompt = """
        List \(count) distinct scene ideas for a children's colouring book about "\(theme)".
        \(complexity.promptModifier)
        Reply with exactly one idea per line, no numbering, no bullets, no extra text.
        Each idea is a short visual description of a single scene, at most 15 words.
        """
        let body = ChatRequest(
            model: Constants.subjectModelID,
            messages: [ChatMessage(role: "user", content: prompt)]
        )
        let request = try makeRequest(path: "chat/completions", method: "POST", body: body)
        let response: ChatResponse = try await send(request)
        guard let content = response.choices.first?.message.content else { return [] }
        var seen = Set<String>()
        let subjects = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        return Array(subjects.prefix(count))
    }

    struct GeneratedImage: Sendable {
        let data: Data
        let cost: Double?
    }

    func generateImage(model: ImageModel, prompt: String, seed: Int?) async throws -> GeneratedImage {
        var body = ImagesRequestBody(model: model.id, prompt: prompt)
        if model.supports("output_format") { body.outputFormat = "png" }
        if model.supports("aspect_ratio") { body.aspectRatio = Constants.imageAspectRatio }
        if model.supports("resolution") { body.resolution = Constants.imageResolution }
        if model.supports("seed") { body.seed = seed }
        // Pin quality: "auto" can silently pick high, which costs ~4x for the
        // same line art. Medium is plenty for A4 colouring pages.
        if model.supports("quality") { body.quality = "medium" }

        let request = try makeRequest(path: "images", method: "POST", body: body)
        let response: ImagesResponse = try await send(request, retryOnRateLimit: true)
        guard let b64 = response.data.first?.b64Json,
              let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else {
            throw AppError.emptyImageData
        }
        return GeneratedImage(data: data, cost: response.usage?.cost)
    }

    // MARK: - Plumbing

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        guard let key = KeychainStore.load(), !key.isEmpty else { throw AppError.missingAPIKey }
        var url = Constants.openRouterBaseURL.appending(path: path)
        if let queryItems {
            url.append(queryItems: queryItems)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 180
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/beaglemoo/colourme", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("ColourMe", forHTTPHeaderField: "X-Title")
        return request
    }

    private func makeRequest(path: String, method: String, body: some Encodable) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest, retryOnRateLimit: Bool = false) async throws -> Response {
        let (data, urlResponse) = try await session.data(for: request)
        let status = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0

        if status == 429 && retryOnRateLimit {
            try await Task.sleep(for: .seconds(3))
            return try await send(request, retryOnRateLimit: false)
        }

        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(OpenRouterErrorEnvelope.self, from: data))?.error.message
                ?? String(data: data.prefix(300), encoding: .utf8)
                ?? "no details"
            throw AppError.badResponse(status: status, message: message)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AppError.decoding(String(describing: error))
        }
    }
}
