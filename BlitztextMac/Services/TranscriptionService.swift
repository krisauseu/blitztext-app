import Foundation

enum TranscriptionError: LocalizedError {
    case noFile
    case notConfigured
    case networkError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noFile:
            return "Keine Audio-Datei gefunden"
        case .notConfigured:
            return "Gemini API Key fehlt. Bitte in den Einstellungen hinterlegen."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .apiError(let msg):
            return "Gemini-Fehler: \(msg)"
        }
    }
}

private struct GeminiInteractionRequest: Encodable {
    struct InputItem: Encodable {
        let type: String
        let data: String
        let mime_type: String
    }

    struct GenerationConfig: Encodable {
        struct TranscriptionConfig: Encodable {
            struct Mode: Encodable {
                let type: String
            }
            let mode: Mode?
            let language_codes: [String]?
            let custom_vocabulary: [String]?
        }
        let transcription_config: TranscriptionConfig?
    }

    let model: String
    let input: [InputItem]
    let generation_config: GenerationConfig?
}

private struct GeminiInteractionResponse: Decodable {
    struct Step: Decodable {
        struct Content: Decodable {
            let type: String?
            let text: String?
        }
        let type: String?
        let content: [Content]?
    }

    let steps: [Step]?
    let output_text: String?

    var extractedTranscript: String? {
        if let output_text, !output_text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return output_text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let steps else { return nil }
        let textParts = steps
            .compactMap { $0.content }
            .flatMap { $0 }
            .compactMap { $0.text }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let combined = textParts.joined(separator: "\n")
        return combined.isEmpty ? nil : combined
    }
}

private struct GeminiErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: Int?
        let message: String?
        let status: String?
    }

    let error: APIError?
}

enum TranscriptionService {
    static let remoteModel = "gemini-3.5-transcribe"
    private static let interactionsURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    static func transcribe(
        audioURL: URL,
        customTerms: [String] = [],
        language: String? = nil
    ) async throws -> String {
        guard let apiKey = KeychainService.load(key: .geminiAPIKey) else {
            throw TranscriptionError.notConfigured
        }

        return try await Task.detached(priority: .userInitiated) {
            defer {
                try? FileManager.default.removeItem(at: audioURL)
            }

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw TranscriptionError.noFile
            }

            let audioData = try Data(contentsOf: audioURL, options: [.mappedIfSafe])
            let base64Audio = audioData.base64EncodedString()

            let trimmedLanguage = language?.trimmingCharacters(in: .whitespacesAndNewlines)
            let languageCodes: [String]
            if let trimmedLanguage, !trimmedLanguage.isEmpty {
                languageCodes = [normalizeLanguageCode(trimmedLanguage)]
            } else {
                languageCodes = []
            }

            let customVocabulary = customTerms
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let transcriptionConfig = GeminiInteractionRequest.GenerationConfig.TranscriptionConfig(
                mode: .init(type: "verbatim"),
                language_codes: languageCodes,
                custom_vocabulary: customVocabulary.isEmpty ? nil : customVocabulary
            )

            let payload = GeminiInteractionRequest(
                model: remoteModel,
                input: [
                    .init(
                        type: "audio",
                        data: base64Audio,
                        mime_type: "audio/m4a"
                    )
                ],
                generation_config: .init(transcription_config: transcriptionConfig)
            )

            var request = URLRequest(url: interactionsURL)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 60
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.networkError("Ungültige Antwort")
            }

            guard httpResponse.statusCode == 200 else {
                throw TranscriptionError.apiError(geminiErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
            }

            let interactionResponse = try JSONDecoder().decode(GeminiInteractionResponse.self, from: data)

            guard let text = interactionResponse.extractedTranscript,
                  !text.isEmpty else {
                throw TranscriptionError.apiError("Transkription fehlgeschlagen")
            }

            return text
        }.value
    }

    private static func geminiErrorMessage(from data: Data) -> String? {
        if let errorObj = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
           let message = errorObj.error?.message, !message.isEmpty {
            return message
        }
        if let plainText = String(data: data, encoding: .utf8), !plainText.isEmpty {
            return plainText
        }
        return nil
    }

    private static func normalizeLanguageCode(_ lang: String) -> String {
        switch lang.lowercased() {
        case "de": return "de-DE"
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "es": return "es-ES"
        case "it": return "it-IT"
        default: return lang
        }
    }
}
