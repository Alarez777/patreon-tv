//
//  SessionIDParser.swift
//  PatreonTV
//
//  Normalizes what the user pastes into the manual sign-in field. The value
//  may be the bare cookie value, a `session_id=...;` pair, or a full cookie
//  header copied from the browser's developer tools.
//

import Foundation

enum SessionIDParser {

    static func parse(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let range = value.range(of: "session_id=", options: .caseInsensitive) {
            value = String(value[range.upperBound...])
        }

        if let semicolon = value.firstIndex(of: ";") {
            value = String(value[..<semicolon])
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        value = strippingQuotes(value)
        return value.isEmpty ? nil : value
    }

    private static func strippingQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }

        if value.hasPrefix("\""), value.hasSuffix("\"") {
            return String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("'"), value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
