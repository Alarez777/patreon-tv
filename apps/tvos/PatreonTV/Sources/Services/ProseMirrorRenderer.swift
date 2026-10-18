//
//  ProseMirrorRenderer.swift
//  PatreonTV
//
//  Flattens Patreon's ProseMirror JSON post body (`content_json_string`) into
//  readable plain text. Newer posts use this instead of the HTML `content`
//  field, which arrives null for them.
//

import Foundation

enum ProseMirrorRenderer {

    /// Returns the document's text with paragraph/list breaks, or nil when the
    /// JSON isn't a ProseMirror doc (or is empty).
    static func plainText(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONDecoder().decode(Node.self, from: data)
        else { return nil }

        var out = ""
        append(root, to: &out)
        let text = out
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private struct Node: Decodable {
        let type: String?
        let text: String?
        let content: [Node]?
    }

    private static func append(_ node: Node, to out: inout String) {
        switch node.type {
        case "text":
            out += node.text ?? ""
        case "hard_break":
            out += "\n"
        case "list_item":
            if !out.isEmpty, !out.hasSuffix("\n") { out += "\n" }
            out += "• "
            for child in node.content ?? [] { appendInline(child, to: &out) }
            out += "\n"
        case "paragraph", "heading":
            if !out.isEmpty, !out.hasSuffix("\n") { out += "\n" }
            for child in node.content ?? [] { append(child, to: &out) }
            out += "\n"
        case "bullet_list", "ordered_list", "blockquote", "doc":
            for child in node.content ?? [] { append(child, to: &out) }
        default:
            for child in node.content ?? [] { append(child, to: &out) }
        }
    }

    /// Text inside a list item: flatten without the paragraph newlines.
    private static func appendInline(_ node: Node, to out: inout String) {
        switch node.type {
        case "text":
            out += node.text ?? ""
        case "hard_break":
            out += "\n"
        default:
            for child in node.content ?? [] { appendInline(child, to: &out) }
        }
    }
}
