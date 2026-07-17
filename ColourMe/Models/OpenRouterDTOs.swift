import Foundation

// MARK: - Image generation

struct ImagesRequestBody: Encodable {
    let model: String
    let prompt: String
    var n = 1
    var outputFormat: String?
    var aspectRatio: String?
    var resolution: String?
    var seed: Int?
    var quality: String?

    enum CodingKeys: String, CodingKey {
        case model, prompt, n, resolution, seed, quality
        case outputFormat = "output_format"
        case aspectRatio = "aspect_ratio"
    }
}

struct ImagesResponse: Decodable {
    struct Item: Decodable {
        let b64Json: String?
        let mediaType: String?

        enum CodingKeys: String, CodingKey {
            case b64Json = "b64_json"
            case mediaType = "media_type"
        }
    }

    struct Usage: Decodable {
        let cost: Double?
    }

    let data: [Item]
    let usage: Usage?
}

/// From GET /models?output_modalities=image - the only endpoint that carries
/// pricing. Values arrive as JSON strings.
struct ModelsPricingResponse: Decodable {
    struct Item: Decodable {
        struct Pricing: Decodable {
            let imageOutput: String?

            enum CodingKeys: String, CodingKey {
                case imageOutput = "image_output"
            }
        }

        let id: String
        let pricing: Pricing?
    }

    let data: [Item]
}

// MARK: - Model discovery

struct ImageModelsResponse: Decodable {
    /// Tolerant parameter spec: keeps enum values when present, accepts any
    /// other shape without failing.
    struct ParamSpec: Decodable {
        let values: [String]?

        enum CodingKeys: String, CodingKey {
            case values
        }

        init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)
            values = try? container?.decodeIfPresent([String].self, forKey: .values)
        }
    }

    struct Item: Decodable {
        let id: String
        let name: String?
        let supportedParameters: [String]?
        let resolutionOptions: [String]

        enum CodingKeys: String, CodingKey {
            case id, name
            case supportedParameters = "supported_parameters"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            // The API returns this as a dictionary of parameter name to spec;
            // tolerate a plain array of names too.
            if let dict = try? container.decodeIfPresent([String: ParamSpec].self, forKey: .supportedParameters) {
                supportedParameters = Array(dict.keys)
                resolutionOptions = dict["resolution"]?.values ?? []
            } else if let names = try? container.decodeIfPresent([String].self, forKey: .supportedParameters) {
                supportedParameters = names
                resolutionOptions = []
            } else {
                supportedParameters = nil
                resolutionOptions = []
            }
        }
    }

    let data: [Item]
}

/// Decodes successfully against any JSON value while keeping nothing.
struct IgnoredValue: Decodable {
    init(from decoder: Decoder) throws {}
}

// MARK: - Chat completions (page subject ideas)

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

struct ChatResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
    }

    let choices: [Choice]
}

// MARK: - Error envelope

struct OpenRouterErrorEnvelope: Decodable {
    struct Body: Decodable {
        let message: String?
    }

    let error: Body
}
