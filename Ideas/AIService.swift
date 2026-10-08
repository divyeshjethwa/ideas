import Foundation

enum AIError: LocalizedError {
    case noKey(AIProvider)
    case badResponse(String)
    case noSuggestions

    var errorDescription: String? {
        switch self {
        case .noKey(let provider):
            "\(provider.displayName) isn't connected yet. Add a key in Settings (gear icon)."
        case .badResponse(let message):
            message
        case .noSuggestions:
            "The AI didn't return any steps. Try again."
        }
    }
}

/// Talks to whichever AI is selected in Settings.
enum AIService {
    static let providerKey = "ai.selectedProvider"
    static func modelKey(_ provider: AIProvider) -> String { "ai.model.\(provider.rawValue)" }

    static var selectedProvider: AIProvider {
        AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .groq
    }

    static func model(for provider: AIProvider) -> String {
        let saved = (UserDefaults.standard.string(forKey: modelKey(provider)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return saved.isEmpty ? provider.defaultModel : saved
    }

    // MARK: - Features

    static func suggestSteps(title: String, notes: String, existingSteps: [String]) async throws -> [String] {
        let provider = selectedProvider
        guard let key = KeychainStore.read(provider.rawValue) else { throw AIError.noKey(provider) }

        let system = """
        You help break app ideas into small, concrete next steps. \
        Reply with ONLY a JSON array of 5 to 8 short strings and nothing else. \
        Each string is one clear action, under 12 words.
        """

        var user = "Idea: \(title)"
        if !notes.isEmpty {
            user += "\nNotes: \(notes)"
        }
        if !existingSteps.isEmpty {
            user += "\nSteps already planned (don't repeat these):\n- " + existingSteps.joined(separator: "\n- ")
        }

        let reply = try await complete(provider: provider, key: key, system: system, user: user)
        let steps = parseList(reply)
        guard !steps.isEmpty else { throw AIError.noSuggestions }
        return steps
    }

    // MARK: - Networking

    private static func complete(provider: AIProvider, key: String, system: String, user: String) async throws -> String {
        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let modelName = model(for: provider)
        let body: [String: Any]

        if provider == .claude {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": modelName,
                "max_tokens": 1024,
                "system": system,
                "messages": [["role": "user", "content": user]]
            ]
        } else {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            body = [
                "model": modelName,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(statusCode) else {
            let apiMessage = (json?["error"] as? [String: Any])?["message"] as? String
            let hint = statusCode == 401 || statusCode == 403
                ? " Check your key in Settings."
                : ""
            throw AIError.badResponse("\(provider.displayName): \(apiMessage ?? "Request failed (\(statusCode)).")\(hint)")
        }

        if provider == .claude {
            let content = json?["content"] as? [[String: Any]] ?? []
            return content.compactMap { $0["text"] as? String }.joined()
        } else {
            let choices = json?["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            return message?["content"] as? String ?? ""
        }
    }

    /// Pulls a list of strings out of the AI's reply. Prefers a JSON array,
    /// falls back to one item per line if the AI ignored the format.
    static func parseList(_ text: String) -> [String] {
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]"),
           start < end,
           let data = String(text[start...end]).data(using: .utf8),
           let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
            return array
                .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let bullets = CharacterSet(charactersIn: "-*•0123456789.) ")
        return text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: bullets) }
            .filter { !$0.isEmpty }
    }
}
