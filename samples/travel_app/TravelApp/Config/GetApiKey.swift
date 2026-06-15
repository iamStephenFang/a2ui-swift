// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case ark
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ark: return "Ark DeepSeek"
        case .gemini: return "Gemini"
        }
    }

    var environmentKey: String {
        switch self {
        case .ark: return "ARK_API_KEY"
        case .gemini: return "GEMINI_API_KEY"
        }
    }

    var userDefaultsKey: String {
        switch self {
        case .ark: return "arkAPIKey"
        case .gemini: return "geminiAPIKey"
        }
    }

    var requiredTitle: String {
        switch self {
        case .ark: return "Ark API Key Required"
        case .gemini: return "Gemini API Key Required"
        }
    }

    var keyHelpText: String {
        switch self {
        case .ark: return "Set ARK_API_KEY in the environment, or enter your Ark API key in Settings."
        case .gemini: return "Set GEMINI_API_KEY in the environment, or enter your Gemini API key in Settings."
        }
    }
}

/// Resolves API keys using a priority chain:
///
/// 1. Provider-specific environment variable
/// 2. Provider-specific key stored in UserDefaults (`@AppStorage`)
enum GetApiKey {
    /// Returns the API key if available, or an empty string if not configured.
    static func resolve(provider: AIProvider = .ark) -> String {
        if let envKey = ProcessInfo.processInfo.environment[provider.environmentKey],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey
        }

        let stored = UserDefaults.standard.string(forKey: provider.userDefaultsKey) ?? ""
        if !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    /// Whether the user has configured a key (env var or UserDefaults).
    static func hasUserProvidedKey(provider: AIProvider = .ark) -> Bool {
        !resolve(provider: provider).isEmpty
    }
}
