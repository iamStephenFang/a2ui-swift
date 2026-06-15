// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

/// The root content view with a navigation-based layout.
/// Provides navigation to the AI chat planner and widget catalog.
struct ContentView: View {
    @AppStorage("aiProvider") private var aiProviderRawValue = AIProvider.ark.rawValue
    @AppStorage("arkAPIKey") private var arkAPIKey = ""
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("useStreaming") private var useStreaming = false
    @State private var travelViewId = UUID()
    @State private var showSettings = false
    @State private var showCatalog = false

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: aiProviderRawValue) ?? .ark
    }

    /// Resolved API key: env var → user-entered key.
    private var resolvedAPIKey: String {
        let stored: String
        switch selectedProvider {
        case .ark: stored = arkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        case .gemini: stored = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !stored.isEmpty { return stored }
        return GetApiKey.resolve(provider: selectedProvider)
    }

    private var hasAPIKey: Bool {
        !resolvedAPIKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasAPIKey {
                TravelPlannerView(
                    provider: selectedProvider,
                    apiKey: resolvedAPIKey
                )
                    .id(travelViewId)
                } else {
                    APIKeyRequiredView(provider: selectedProvider) {
                        showSettings = true
                    }
                }
            }
            .navigationTitle("Agentic Travel Inc.")
            #if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem() {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem() {
                    Button {
                        showCatalog = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
            .navigationDestination(isPresented: $showCatalog) {
                CatalogView()
                    .navigationTitle("Widget Catalog")
                    #if !os(tvOS) && !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(
                        aiProviderRawValue: $aiProviderRawValue,
                        arkAPIKey: $arkAPIKey,
                        geminiAPIKey: $geminiAPIKey,
                        useStreaming: $useStreaming,
                        onProviderChanged: {
                            travelViewId = UUID()
                        },
                        onRestartChat: {
                            travelViewId = UUID()
                            showSettings = false
                        }
                    )
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSettings = false }
                        }
                    }
                }
            }
        }
    }

}

// MARK: - Settings

private struct SettingsView: View {
    @Binding var aiProviderRawValue: String
    @Binding var arkAPIKey: String
    @Binding var geminiAPIKey: String
    @Binding var useStreaming: Bool
    var onProviderChanged: () -> Void
    var onRestartChat: () -> Void

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: aiProviderRawValue) ?? .ark
    }

    private var maskedKey: String {
        let key = GetApiKey.resolve(provider: selectedProvider)
        guard !key.isEmpty else { return "Not set" }
        guard key.count > 8 else { return "********" }
        return String(key.prefix(4)) + "****" + String(key.suffix(4))
    }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $aiProviderRawValue) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
            } footer: {
                Text("Ark uses an OpenAI-compatible chat completions API with the default model deepseek-v4-flash-260425.")
            }

            Section {
                Toggle("Streaming Mode", isOn: $useStreaming)
                    .disabled(selectedProvider == .ark)
            } footer: {
                Text(selectedProvider == .ark ? "Streaming is currently only implemented for Gemini in this sample." : "When enabled, responses appear incrementally as they are generated. When disabled (default), the complete response is received before display — matching Flutter's behavior and more reliable for complex UI responses.")
            }

            Section {
                NavigationLink {
                    APIKeySettingsView(
                        provider: selectedProvider,
                        arkAPIKey: $arkAPIKey,
                        geminiAPIKey: $geminiAPIKey,
                        onRestartChat: onRestartChat
                    )
                } label: {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(maskedKey)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(selectedProvider.displayName)
            } footer: {
                Text("Priority: user-entered key → \(selectedProvider.environmentKey) env var.")
            }
        }
        .onChange(of: aiProviderRawValue) {
            onProviderChanged()
        }
    }
}

// MARK: - API Key Settings

private struct APIKeySettingsView: View {
    let provider: AIProvider
    @Binding var arkAPIKey: String
    @Binding var geminiAPIKey: String
    var onRestartChat: () -> Void

    private var apiKey: Binding<String> {
        switch provider {
        case .ark: return $arkAPIKey
        case .gemini: return $geminiAPIKey
        }
    }

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: apiKey)
                    .autocorrectionDisabled()
            } footer: {
                Text("Leave empty to use the \(provider.environmentKey) environment variable.")
            }

            if !apiKey.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    Button("Clear Custom Key", role: .destructive) {
                        apiKey.wrappedValue = ""
                    }
                } footer: {
                    Text("Removes the custom key and falls back to the environment variable.")
                }
            }

            Section {
                Button("Apply & Restart Chat") {
                    onRestartChat()
                }
            }
        }
        .navigationTitle("API Key")
        #if !os(tvOS) && !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - API Key Required

private struct APIKeyRequiredView: View {
    let provider: AIProvider
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(provider.requiredTitle)
                .font(.title2.bold())
            Text(provider.keyHelpText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                onOpenSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
