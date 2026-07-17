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

    enum CodingKeys: String, CodingKey {
        case model, prompt, n, resolution, seed
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

    let data: [Item]
}

// MARK: - Model discovery

struct ImageModelsResponse: Decodable {
    struct Item: Decodable {
        let id: String
        let name: String?
        let supportedParameters: [String]?

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
            if let dict = try? container.decodeIfPresent([String: IgnoredValue].self, forKey: .supportedParameters) {
                supportedParameters = Array(dict.keys)
            } else if let names = try? container.decodeIfPresent([String].self, forKey: .supportedParameters) {
                supportedParameters = names
            } else {
                supportedParameters = nil
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
