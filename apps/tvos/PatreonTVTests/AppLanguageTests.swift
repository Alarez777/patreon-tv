//
//  AppLanguageTests.swift
//  PatreonTVTests
//
//  System-language resolution and the locale used for formatting.
//

import XCTest
@testable import PatreonTV

final class AppLanguageTests: XCTestCase {

    func test_resolves_supported_system_languages() {
        XCTAssertEqual(AppLanguage.resolved(from: ["es-MX"]), .spanish)
        XCTAssertEqual(AppLanguage.resolved(from: ["es-ES"]), .spanish)
        XCTAssertEqual(AppLanguage.resolved(from: ["pt-PT"]), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(from: ["pt-BR"]), .portuguese)
        XCTAssertEqual(AppLanguage.resolved(from: ["fr-CA"]), .french)
        XCTAssertEqual(AppLanguage.resolved(from: ["en-GB"]), .english)
    }

    func test_skips_unsupported_languages_until_a_supported_one() {
        XCTAssertEqual(AppLanguage.resolved(from: ["de-DE", "fr-FR"]), .french)
        XCTAssertEqual(AppLanguage.resolved(from: ["zh-Hans", "en-US"]), .english)
    }

    func test_falls_back_to_english() {
        XCTAssertEqual(AppLanguage.resolved(from: []), .english)
        XCTAssertEqual(AppLanguage.resolved(from: ["de-DE", "it-IT"]), .english)
    }

    func test_locales_have_the_expected_language_and_region() {
        XCTAssertEqual(AppLanguage.english.locale.language.languageCode?.identifier, "en")
        XCTAssertEqual(AppLanguage.english.locale.language.region?.identifier, "US")

        XCTAssertEqual(AppLanguage.spanish.locale.language.languageCode?.identifier, "es")
        XCTAssertEqual(AppLanguage.spanish.locale.language.region?.identifier, "419")

        XCTAssertEqual(AppLanguage.portuguese.locale.language.languageCode?.identifier, "pt")
        XCTAssertEqual(AppLanguage.portuguese.locale.language.region?.identifier, "BR")

        XCTAssertEqual(AppLanguage.french.locale.language.languageCode?.identifier, "fr")
        XCTAssertEqual(AppLanguage.french.locale.language.region?.identifier, "FR")
    }

    func test_storage_values_are_stable() {
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.spanish.rawValue, "es")
        XCTAssertEqual(AppLanguage.portuguese.rawValue, "pt-BR")
        XCTAssertEqual(AppLanguage.french.rawValue, "fr")
    }
}
