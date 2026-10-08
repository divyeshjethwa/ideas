import Foundation

/// Every AI the app can talk to. Add a new case here to support another provider.
enum AIProvider: String, CaseIterable, Identifiable {
    case groq
    case gemini
    case openRouter
    case openAI
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: "Groq"
        case .gemini: "Google Gemini"
        case .openRouter: "OpenRouter"
        case .openAI: "ChatGPT (OpenAI)"
        case .claude: "Claude (Anthropic)"
        }
    }

    var isFree: Bool {
        switch self {
        case .groq, .gemini, .openRouter: true
        case .openAI, .claude: false
        }
    }

    /// Where "Get key" sends you.
    var keyPageURL: URL {
        switch self {
        case .groq: URL(string: "https://console.groq.com/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .claude: URL(string: "https://console.anthropic.com/settings/keys")!
        }
    }

    /// Used when you leave the Model field empty in Settings.
    var defaultModel: String {
        switch self {
        case .groq: "openai/gpt-oss-120b"
        case .gemini: "gemini-flash-latest"
        case .openRouter: "openrouter/free"
        case .openAI: "gpt-5-mini"
        case .claude: "claude-haiku-5-5"
        }
    }

    /// Groq, Gemini, OpenRouter and OpenAI all speak the same "chat completions" format.
    /// Claude uses its own Messages API.
    var endpoint: URL {
        switch self {
        case .groq: URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .openAI: URL(string: "https://api.openai.com/v1/chat/completions")!
        case .claude: URL(string: "https://api.anthropic.com/v1/messages")!
        }
    }
}
