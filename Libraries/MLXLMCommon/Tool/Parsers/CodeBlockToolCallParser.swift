// Copyright © 2025 Apple Inc.

import Foundation

/// Parser for JSON format: <tag>{"name": "...", "arguments": {...}}</tag>
/// Reference: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/tool_parsers/default.py
public struct CodeBlockToolCallParser: ToolCallParser, Sendable {
    public let startTag: String?
    public let endTag: String?
    private let codeType: String?
    private let codeBlock: String?

    public init(codeType: String, codeBlock: String = "```") {
        self.codeType = codeType
        self.codeBlock = codeBlock
        self.startTag = codeBlock + codeType
        self.endTag = nil
    }

    public func parse(content: String, tools: [[String: any Sendable]]?) -> ToolCall? {
        guard let start = startTag, let type = codeType, let end = codeBlock else { return nil }

        // Find the JSON content between tags
        var text = content

        // Strip tags if present
        if let startRange = text.range(of: start) {
            text = String(text[startRange.upperBound...])
        }
        if let codeRange = text.range(of: type) {
            text = String(text[codeRange.upperBound...])
        }
        if let endRange = text.range(of: end) {
            text = String(text[..<endRange.lowerBound])
        }

        let jsonStr = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = jsonStr.data(using: .utf8),
            let normalizedData = normalizedToolCallData(from: data),
            let function = try? JSONDecoder().decode(ToolCall.Function.self, from: normalizedData)
        else { return nil }

        return ToolCall(function: function)
    }


    private func normalizedToolCallData(from data: Data) -> Data? {
        guard var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let stringifiedArguments = jsonObject["arguments"] as? String {
            guard
                let argumentsData = stringifiedArguments.data(using: .utf8),
                let argumentsObject = try? JSONSerialization.jsonObject(with: argumentsData)
                    as? [String: Any]
            else { return nil }
            jsonObject["arguments"] = argumentsObject
        }

        return try? JSONSerialization.data(withJSONObject: jsonObject)
    }
}
