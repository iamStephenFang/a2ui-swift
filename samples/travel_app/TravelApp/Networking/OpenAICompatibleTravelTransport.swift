// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import A2UISwiftCore
import Primitives

/// Transport for OpenAI-compatible chat completion APIs.
///
/// The default configuration targets Volcengine Ark:
/// `https://ark.cn-beijing.volces.com/api/v3/chat/completions`.
final class OpenAICompatibleTravelTransport: TravelTransport {
    var supportsStreaming: Bool = false

    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let systemInstructionFragments: [String]
    private var conversationHistory: [[String: Any]] = []

    var clientDataModel: A2uiClientDataModel?
    private(set) var lastTextResponse: String?

    init(
        apiKey: String,
        model: String = "deepseek-v4-flash-260425",
        endpoint: URL = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!,
        systemInstruction: [String] = []
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.systemInstructionFragments = systemInstruction
    }

    func sendText(_ text: String, contextId: String?) async throws -> TransportResponse {
        print("[OpenAICompatibleTransport] sendText: \"\(text.prefix(100))\"")
        conversationHistory.append(["role": "user", "content": text])

        let messages = try await generateContent()
        print("[OpenAICompatibleTransport] sendText returning \(messages.count) messages")
        return TransportResponse(messages: messages, contextId: contextId, textResponse: lastTextResponse)
    }

    func sendAction(_ action: ResolvedAction, surfaceId: String, contextId: String?) async throws -> TransportResponse {
        let interactionText = buildInteractionText(action: action, surfaceId: surfaceId)
        print("[OpenAICompatibleTransport] sendAction: \(interactionText)")
        conversationHistory.append(["role": "user", "content": interactionText])

        let messages = try await generateContent()
        print("[OpenAICompatibleTransport] sendAction returning \(messages.count) messages")
        return TransportResponse(messages: messages, contextId: contextId, textResponse: lastTextResponse)
    }

    func sendTextStream(_ text: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>? {
        nil
    }

    func sendActionStream(_ action: ResolvedAction, surfaceId: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>? {
        nil
    }

    private func generateContent() async throws -> [A2uiMessage] {
        lastTextResponse = nil
        var toolCycles = 0
        let maxToolCycles = 40

        while toolCycles < maxToolCycles {
            let responseJson = try await callChatCompletions()
            let extracted = extractResponse(from: responseJson)

            if extracted.finishReason == "length" {
                print("[OpenAICompatibleTransport] Response truncated (length) — output may be incomplete")
            }

            if extracted.toolCalls.isEmpty {
                if let assistantMessage = extracted.assistantMessage {
                    conversationHistory.append(assistantMessage)
                }

                let fullText = extracted.textParts.joined()
                print("[OpenAICompatibleTransport] Model text response (\(fullText.count) chars): \(fullText.prefix(300))...")

                let messages = await parseA2uiMessages(from: fullText)
                if !messages.isEmpty {
                    if messages.containsUpdateComponents || !messages.containsCreateSurface {
                        return messages
                    }

                    toolCycles += 1
                    let surfaceIds = messages.createdSurfaceIds.joined(separator: ", ")
                    print("[OpenAICompatibleTransport] Parsed createSurface without updateComponents; asking model to complete surface(s): \(surfaceIds)")
                    conversationHistory.append([
                        "role": "user",
                        "content": "The previous response only produced createSurface, so the UI is still empty. Output a valid fenced ```json updateComponents block for surfaceId(s): \(surfaceIds). Use strict JSON only: no raw line breaks inside strings, no trailing commas, and include a root component plus visible travel cards."
                    ])
                    continue
                } else {
                    let cleanText = stripJSONBlocks(from: fullText).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanText.isEmpty {
                        lastTextResponse = cleanText
                    }
                }

                return messages
            }

            toolCycles += 1
            print("[OpenAICompatibleTransport] Tool cycle \(toolCycles): \(extracted.toolCalls.count) function call(s)")

            if let assistantMessage = extracted.assistantMessage {
                conversationHistory.append(assistantMessage)
            }

            var uiToolMessages: [A2uiMessage] = []
            for call in extracted.toolCalls {
                let args = (call.arguments ?? [:]).compactMapValues { $0.anyValue }
                if let a2uiMessage = a2uiMessageFromToolCall(call) {
                    print("[OpenAICompatibleTransport] Converted UI tool call '\(call.toolName)' to A2UI message")
                    uiToolMessages.append(a2uiMessage)
                    conversationHistory.append(openAIUIToolResultMessage(for: call))
                    continue
                }

                print("[OpenAICompatibleTransport] Executing tool: \(call.toolName) args: \(args)")
                let result = await executeTool(name: call.toolName, args: args)
                conversationHistory.append(openAIToolResultMessage(for: call, result: result))
            }
            if !uiToolMessages.isEmpty {
                if uiToolMessages.containsUpdateComponents {
                    print("[OpenAICompatibleTransport] Converted \(uiToolMessages.count) UI tool call(s) to A2UI messages")
                    return uiToolMessages
                }
                print("[OpenAICompatibleTransport] UI tool call(s) did not include updateComponents; asking model for component JSON")
                conversationHistory.append([
                    "role": "user",
                    "content": "You created a surface, but it is empty until updateComponents is provided. Do not use function calls for A2UI operations. Output the remaining A2UI updateComponents message as a fenced ```json block for the same surfaceId, with a root component and visible travel cards."
                ])
                continue
            }
        }

        print("[OpenAICompatibleTransport] Exceeded max tool cycles (\(maxToolCycles))")
        return []
    }

    private func callChatCompletions() async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300

        var body: [String: Any] = [
            "model": model,
            "messages": openAIMessages(),
        ]

        let tools = openAITools()
        if !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[OpenAICompatibleTransport] Calling \(endpoint.host ?? "chat completions API")...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("[OpenAICompatibleTransport] API responded, \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleTransportError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "unknown error"
            print("[OpenAICompatibleTransport] API error \(httpResponse.statusCode): \(responseBody.prefix(500))")
            throw OpenAICompatibleTransportError.apiError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? "nil"
            print("[OpenAICompatibleTransport] Response is not a JSON dictionary: \(preview)")
            throw OpenAICompatibleTransportError.invalidResponse
        }

        return json
    }

    private func openAIMessages() -> [[String: Any]] {
        [
            ["role": "system", "content": systemInstructionText()]
        ] + conversationHistory
    }

    private func openAITools() -> [[String: Any]] {
        toolDefinitions.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.inputSchema,
                ] as [String: Any],
            ] as [String: Any]
        }
    }

    private func extractResponse(
        from responseJson: [String: Any]
    ) -> (assistantMessage: [String: Any]?, toolCalls: [ToolPartContent], textParts: [String], finishReason: String?) {
        guard
            let choices = responseJson["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            return (nil, [], [], nil)
        }

        let finishReason = firstChoice["finish_reason"] as? String
        let content = message["content"] as? String ?? ""
        let rawToolCalls = message["tool_calls"] as? [[String: Any]] ?? []

        var assistantMessage: [String: Any] = ["role": "assistant"]
        if !content.isEmpty {
            assistantMessage["content"] = content
        } else if !rawToolCalls.isEmpty {
            assistantMessage["content"] = NSNull()
        }
        if !rawToolCalls.isEmpty {
            assistantMessage["tool_calls"] = rawToolCalls
        }

        var toolCalls: [ToolPartContent] = []
        for rawToolCall in rawToolCalls {
            guard
                let id = rawToolCall["id"] as? String,
                let function = rawToolCall["function"] as? [String: Any],
                let name = function["name"] as? String
            else { continue }

            var arguments: [String: JSONValue] = [:]
            if let rawArguments = function["arguments"] as? String,
               let data = rawArguments.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in parsed {
                    if let jsonValue = JSONValue(value) {
                        arguments[key] = jsonValue
                    }
                }
            }

            toolCalls.append(ToolPartContent.call(callId: id, toolName: name, arguments: arguments))
        }

        return (assistantMessage, toolCalls, content.isEmpty ? [] : [content], finishReason)
    }

    private func openAIToolResultMessage(for call: ToolPartContent, result: [String: Any]) -> [String: Any] {
        let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        let content = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return [
            "role": "tool",
            "tool_call_id": call.callId,
            "name": call.toolName,
            "content": content,
        ]
    }

    private func openAIUIToolResultMessage(for call: ToolPartContent) -> [String: Any] {
        let content: [String: Any] = [
            "ok": true,
            "message": "A2UI operations must be emitted as fenced JSON text blocks, not function calls. Continue by outputting updateComponents JSON for the created surface."
        ]
        let data = try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])
        return [
            "role": "tool",
            "tool_call_id": call.callId,
            "name": call.toolName,
            "content": data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}",
        ]
    }

    private func buildInteractionText(action: ResolvedAction, surfaceId: String) -> String {
        var actionContext: [String: Any] = [:]
        for (key, value) in action.context {
            switch value {
            case .string(let string): actionContext[key] = string
            case .number(let number): actionContext[key] = number
            case .bool(let bool): actionContext[key] = bool
            default: actionContext[key] = "\(value)"
            }
        }

        let interactionJson: [String: Any] = [
            "interaction": [
                "version": "v0.9",
                "action": [
                    "surfaceId": surfaceId,
                    "name": action.name,
                    "sourceComponentId": action.sourceComponentId,
                    "context": actionContext,
                ] as [String: Any],
            ] as [String: Any],
        ]

        if let data = try? JSONSerialization.data(withJSONObject: interactionJson, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "User action: \(action.name) on surface: \(surfaceId)"
    }

    private let tools: [any AiTool] = [
        ListHotelsTool(onListHotels: { search in
            await BookingService.instance.listHotels(search)
        }),
    ]

    private var toolDefinitions: [ToolDefinition] {
        tools.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.parameters ?? [:]
            )
        }
    }

    private func executeTool(name: String, args: [String: Any]) async -> [String: Any] {
        if let tool = tools.first(where: { $0.name == name }) {
            do {
                return try await tool.invoke(args)
            } catch {
                return ["error": "Tool \(name) failed: \(error.localizedDescription)"]
            }
        }
        return ["error": "Unknown tool: \(name)"]
    }

    private func a2uiMessageFromToolCall(_ call: ToolPartContent) -> A2uiMessage? {
        let args = (call.arguments ?? [:]).compactMapValues { $0.anyValue }
        var json: [String: Any] = ["version": "v0.9"]
        switch call.toolName {
        case "createSurface", "updateComponents", "updateDataModel", "deleteSurface":
            json[call.toolName] = args
        default:
            return nil
        }
        return decodeA2uiMessage(json, sourceDescription: "tool call \(call.toolName)")
    }

    private func systemInstructionText() -> String {
        var parts = systemInstructionFragments
        parts.append("Use the provided tools to respond to user using rich UI elements.")
        parts.append("IMPORTANT: You do not have the ability to execute code. If you need to perform calculations, do them yourself.")
        parts.append("IMPORTANT: You do not have the ability to use tools for UI generation.")
        parts.append("IMPORTANT: You do not have the ability to use function calls for UI generation.")
        parts.append("IMPORTANT: `createSurface`, `updateComponents`, `updateDataModel`, and `deleteSurface` are NOT callable tools. You MUST output them as fenced ```json text blocks. A visible UI always requires `updateComponents`; `createSurface` alone renders nothing.")
        parts.append(GeminiTravelTransport.controllingTheUI)
        parts.append(GeminiTravelTransport.outputFormat)
        parts.append(GeminiTravelTransport.catalogSchema)

        if let clientDataModel {
            var dataDict: [String: Any] = [:]
            for (surfaceId, surfaceData) in clientDataModel.surfaces {
                dataDict[surfaceId] = anyCodableToAny(surfaceData)
            }
            if let data = try? JSONSerialization.data(withJSONObject: dataDict, options: [.prettyPrinted, .sortedKeys]),
               let dataString = String(data: data, encoding: .utf8) {
                parts.append("Client Data Model:\n\(dataString)")
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private func anyCodableToAny(_ value: AnyCodable) -> Any {
        switch value {
        case .string(let string): return string
        case .number(let number): return number
        case .bool(let bool): return bool
        case .null: return NSNull()
        case .array(let array): return array.map { anyCodableToAny($0) }
        case .dictionary(let dictionary):
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                result[key] = anyCodableToAny(value)
            }
            return result
        }
    }

    private func parseA2uiMessages(from text: String) async -> [A2uiMessage] {
        var messages = parseA2uiMessagesFromFencedJSON(text)
        if !messages.isEmpty {
            print("[OpenAICompatibleTransport] parseA2uiMessages: \(messages.count) messages from \(text.count) chars")
            return messages
        }

        let parser = A2UIStreamParser()
        await parser.add(text)
        await parser.finish()

        for await event in parser.events {
            switch event {
            case .message(let message):
                messages.append(message)
            case .text, .error:
                break
            }
        }

        print("[OpenAICompatibleTransport] parseA2uiMessages: \(messages.count) messages from \(text.count) chars")
        return messages
    }

    private func parseA2uiMessagesFromFencedJSON(_ text: String) -> [A2uiMessage] {
        let blocks = extractFencedJSONBlocks(from: text)
        print("[OpenAICompatibleTransport] fenced JSON blocks: \(blocks.count)")
        var messages: [A2uiMessage] = []

        for (index, block) in blocks.enumerated() {
            guard let parsed = parseJSONObject(from: block) else {
                if let data = block.data(using: .utf8) {
                    do {
                        _ = try JSONSerialization.jsonObject(with: data)
                    } catch {
                        print("[OpenAICompatibleTransport] JSON block \(index + 1) is invalid: \(error); preview=\(blockPreview(block))")
                    }
                } else {
                    print("[OpenAICompatibleTransport] JSON block \(index + 1) is not valid UTF-8; preview=\(blockPreview(block))")
                }
                continue
            }

            if parsed.wasRepaired {
                print("[OpenAICompatibleTransport] JSON block \(index + 1) parsed after escaping control characters inside strings")
            }

            guard var json = parsed.object as? [String: Any] else {
                print("[OpenAICompatibleTransport] JSON block \(index + 1) is not an object; preview=\(blockPreview(block))")
                continue
            }
            if json["version"] == nil {
                json["version"] = "v0.9"
            }
            let keys = json.keys.sorted().joined(separator: ",")
            if let message = decodeA2uiMessage(json, sourceDescription: "JSON block \(index + 1) keys=[\(keys)]") {
                messages.append(message)
            }
        }

        return messages
    }

    private func parseJSONObject(from block: String) -> (object: Any, wasRepaired: Bool)? {
        if let data = block.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            return (object, false)
        }

        let repaired = escapingControlCharactersInsideStrings(block)
        guard repaired != block,
              let data = repaired.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }

        return (object, true)
    }

    private func escapingControlCharactersInsideStrings(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        var inString = false
        var isEscaped = false

        for character in text {
            if isEscaped {
                result.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                result.append(character)
                if inString {
                    isEscaped = true
                }
                continue
            }

            if character == "\"" {
                inString.toggle()
                result.append(character)
                continue
            }

            if inString {
                switch character {
                case "\n":
                    result.append("\\n")
                case "\r":
                    result.append("\\r")
                case "\t":
                    result.append("\\t")
                default:
                    result.append(character)
                }
                continue
            }

            result.append(character)
        }

        return result
    }

    private func decodeA2uiMessage(_ json: [String: Any], sourceDescription: String) -> A2uiMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            print("[OpenAICompatibleTransport] Failed to serialize \(sourceDescription)")
            return nil
        }
        do {
            return try JSONDecoder().decode(A2uiMessage.self, from: data)
        } catch {
            print("[OpenAICompatibleTransport] Failed to decode A2UI \(sourceDescription): \(error); preview=\(jsonPreview(json))")
            return nil
        }
    }

    private func extractFencedJSONBlocks(from text: String) -> [String] {
        let pattern = #"(?s)```(?:json)?\s*(.*?)\s*```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func blockPreview(_ block: String) -> String {
        String(block.replacingOccurrences(of: "\n", with: "\\n").prefix(500))
    }

    private func jsonPreview(_ json: [String: Any]) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "\(json)"
        }
        return blockPreview(text)
    }

    private func stripJSONBlocks(from text: String) -> String {
        JsonBlockParser.stripJsonBlock(text)
    }
}

enum OpenAICompatibleTransportError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI-compatible API"
        case .apiError(let statusCode, let message):
            let short = extractErrorMessage(from: message)
            return "OpenAI-compatible API error (\(statusCode)): \(short)"
        }
    }

    private func extractErrorMessage(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(raw.prefix(200))
    }
}

private extension Array where Element == A2uiMessage {
    var containsUpdateComponents: Bool {
        contains { message in
            if case .updateComponents = message {
                return true
            }
            return false
        }
    }

    var containsCreateSurface: Bool {
        contains { message in
            if case .createSurface = message {
                return true
            }
            return false
        }
    }

    var createdSurfaceIds: [String] {
        compactMap { message in
            if case .createSurface(let payload) = message {
                return payload.surfaceId
            }
            return nil
        }
    }
}
