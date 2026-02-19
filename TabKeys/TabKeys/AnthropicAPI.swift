import Foundation

/// Protocol for any AI completion provider (Anthropic, OpenAI, etc.).
protocol CompletionAPI: AnyObject {
    func getCompletion(for text: String) async throws -> String
}

class AnthropicAPI: CompletionAPI {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func getCompletion(for text: String) async throws -> String {
        // Minimal prompt: chat models tend to explain; we want only the next tokens.
        let userPrompt = """
        Continue this text. Output ONLY the next few words that would naturally follow. No explanation, no quotes, no "here is" or "the completion is". Just the continuation.

        \(text)
        """

        let rawResponse = try await makeAPICall(with: userPrompt)
        return cleanResponse(rawResponse, originalText: text)
    }

    private func makeAPICall(with prompt: String) async throws -> String {
        let systemPrompt = """
        You are an autocomplete engine. Your only job is to output the next words that continue the user's text. Never add prefixes, explanations, or meta-commentary. Output nothing but the continuation (typically 1-15 words).
        """
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 25,
            "temperature": 0.8,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw APIError.encodingError(error)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let responseText = firstContent["text"] as? String else {
                throw APIError.parseError
            }

            return responseText
        } catch {
            throw APIError.parseError
        }
    }

    private func cleanResponse(_ response: String, originalText: String) -> String {
        let cleanedText = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        let withoutQuotes = cleanedText.hasPrefix("\"") && cleanedText.hasSuffix("\"")
            ? String(cleanedText.dropFirst().dropLast())
            : cleanedText

        // Remove any repetition of the original input text
        let inputLowercase = originalText.lowercased()
        let responseLowercase = withoutQuotes.lowercased()

        if responseLowercase.hasPrefix(inputLowercase) {
            let startIndex = withoutQuotes.index(withoutQuotes.startIndex, offsetBy: originalText.count)
            return String(withoutQuotes[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return withoutQuotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingError(Error)
    case invalidResponse
    case httpError(Int, String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .parseError:
            return "Failed to parse response"
        }
    }
}







