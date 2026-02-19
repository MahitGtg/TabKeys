import Foundation

class OpenAIAPI: CompletionAPI {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func getCompletion(for text: String) async throws -> String {
        let userPrompt = """
        Continue this text. Output ONLY the next few words that would naturally follow. No explanation, no quotes, no "here is" or "the completion is". Just the continuation.

        \(text)
        """
        let rawResponse = try await makeAPICall(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return cleanResponse(rawResponse, originalText: text)
    }

    private var systemPrompt: String {
        """
        You are an autocomplete engine. Your only job is to output the next words that continue the user's text. Never add prefixes, explanations, or meta-commentary. Output nothing but the continuation (typically 1-15 words).
        """
    }
    

    private func makeAPICall(systemPrompt: String, userPrompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 25,
            "temperature": 0.8,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let responseText = message["content"] as? String else {
                throw APIError.parseError
            }
            return responseText
        } catch {
            throw APIError.parseError
        }
    }
    

    private func cleanResponse(_ response: String, originalText: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove original text from the start if present (case-insensitive)
        let inputLower = originalText.lowercased()
        let responseLower = cleaned.lowercased()
        if responseLower.hasPrefix(inputLower) {
            let start = cleaned.index(cleaned.startIndex, offsetBy: originalText.count)
            cleaned = String(cleaned[start...])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}




