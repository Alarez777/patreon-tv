//
//  ContentPreferences.swift
//  PatreonTV
//
//  User-facing content settings, persisted in UserDefaults. Currently just the
//  mature-content gate: NSFW creators are hidden by default and revealed via a
//  Settings toggle.
//

import Foundation

@MainActor
@Observable
final class ContentPreferences {

    static let shared = ContentPreferences()

    private let matureKey = "show_mature_content"
    private let autoplayKey = "autoplay_next"
    private let continueCollectionKey = "show_continue_collection"

    /// When false (default), NSFW creators are hidden from Creators and Search.
    var showMatureContent: Bool {
        didSet { UserDefaults.standard.set(showMatureContent, forKey: matureKey) }
    }

    /// When true (default), the Up Next overlay auto-advances to the creator's
    /// next post after a countdown. When false the overlay still appears but
    /// waits for the user.
    var autoplayNext: Bool {
        didSet { UserDefaults.standard.set(autoplayNext, forKey: autoplayKey) }
    }

    /// When true (default), Home shows a "Continue Collection" shelf with the
    /// collection the user opened most recently.
    var showContinueCollection: Bool {
        didSet { UserDefaults.standard.set(showContinueCollection, forKey: continueCollectionKey) }
    }

    private init() {
        showMatureContent = UserDefaults.standard.bool(forKey: matureKey)
        autoplayNext = UserDefaults.standard.object(forKey: autoplayKey) as? Bool ?? true
        showContinueCollection = UserDefaults.standard.object(forKey: continueCollectionKey) as? Bool ?? true
    }
}
