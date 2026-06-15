import Foundation

struct VolcengineChatClient {
    var apiKey: String
    var model: String = "deepseek-v4-flash-260425"
    var endpoint: URL = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func generateAssistantText(for userText: String) async throws -> String? {
        guard isConfigured else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are an iOS image-editing assistant. Keep responses under 40 words.
                    The app can perform only local edits: filter, brightness, square crop, reset.
                    Do not mention Gemini. Do not claim server-side image editing.
                    """,
                ],
                [
                    "role": "user",
                    "content": userText,
                ],
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VolcengineChatError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw VolcengineChatError.apiError(statusCode: httpResponse.statusCode, body: body)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw VolcengineChatError.invalidResponse
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum VolcengineChatError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Volcengine Ark returned an invalid response."
        case .apiError(let statusCode, let body):
            return "Volcengine Ark request failed with HTTP \(statusCode): \(body.prefix(180))"
        }
    }
}

enum APIKeyResolver {
    static func resolveArkAPIKey() -> String {
        if let value = ProcessInfo.processInfo.environment["ARK_API_KEY"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return UserDefaults.standard.string(forKey: "arkAPIKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
