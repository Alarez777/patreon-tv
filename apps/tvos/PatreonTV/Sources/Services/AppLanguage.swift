//
//  AppLanguage.swift
//  PatreonTV
//
//  In-app language preference. The first launch resolves it from the system
//  language; the Settings screen can then override it.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case spanish = "es"
    case portuguese = "pt-BR"
    case french = "fr"

    static let storageKey = "app_language"

    var id: String { rawValue }

    /// Native names: never translated.
    var displayName: String {
        switch self {
        case .english: "English (US)"
        case .spanish: "Español (LatAm)"
        case .portuguese: "Português (Brasil)"
        case .french: "Français"
        }
    }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en-US")
        case .spanish: Locale(identifier: "es-419")
        case .portuguese: Locale(identifier: "pt-BR")
        case .french: Locale(identifier: "fr-FR")
        }
    }

    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let stored = AppLanguage(rawValue: raw) {
            return stored
        }
        return resolved(from: Locale.preferredLanguages)
    }

    /// Maps the first supported system language to one of the four variants.
    /// Spanish and Portuguese always use the Latin American / Brazilian
    /// translations, regardless of the system region.
    static func resolved(from preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .first?
                .lowercased() ?? ""

            switch code {
            case "en": return .english
            case "es": return .spanish
            case "pt": return .portuguese
            case "fr": return .french
            default: break
            }
        }
        return .english
    }
}
