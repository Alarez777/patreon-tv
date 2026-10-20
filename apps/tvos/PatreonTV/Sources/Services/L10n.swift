//
//  L10n.swift
//  PatreonTV
//
//  Localization for strings built outside SwiftUI's `Text` literals
//  (enum titles, errors, counts). SwiftUI views use the environment locale
//  set from `AppLanguage`.
//

import Foundation

enum L10n {

    static func string(_ key: String) -> String {
        languageBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: AppLanguage.current.locale,
            arguments: arguments
        )
    }

    /// Singular/plural strings. French uses the singular for zero, matching
    /// CLDR; English, Spanish and Portuguese use the plural.
    static func count(_ count: Int, one: String, other: String) -> String {
        let key = count == 1 || (AppLanguage.current == .french && count == 0)
            ? one
            : other
        return String(
            format: string(key),
            locale: AppLanguage.current.locale,
            arguments: [number(count) as NSString]
        )
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = AppLanguage.current.locale
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static var languageBundle: Bundle {
        let language = AppLanguage.current
        // Xcode may keep the regional folder (`pt-BR.lproj`) or collapse it
        // to the language (`pt.lproj`); try both.
        let candidates = [language.rawValue, String(language.rawValue.prefix(2))]
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return Bundle.main
    }
}
