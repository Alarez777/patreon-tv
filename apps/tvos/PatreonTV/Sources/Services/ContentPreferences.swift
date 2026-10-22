//
//  ContentPreferences.swift
//  PatreonTV
//
//  User-facing content settings, persisted in UserDefaults: mature-content
//  gate, playback behavior, launch tab and default comment order.
//

import Foundation

@MainActor
@Observable
final class ContentPreferences {

    static let shared = ContentPreferences()

    /// Which tab the app opens on. `lastUsed` restores whichever tab the user
    /// had selected when they last quit; every other case pins that tab.
    enum InitialTab: String, CaseIterable, Identifiable {
        case home, creators, search, lastUsed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: L10n.string("Home")
            case .creators: L10n.string("Creators")
            case .search: L10n.string("Search")
            case .lastUsed: L10n.string("Last used")
            }
        }
    }

    private let matureKey = "show_mature_content"
    private let autoplayNextKey = "autoplay_next"
    private let autoplayNewKey = "autoplay_new"
    private let autoplayContinueWatchingKey = "autoplay_continue_watching"
    private let autoplayChannelsKey = "autoplay_channels"
    private let autoplayCollectionsKey = "autoplay_collections"
    private let continueCollectionKey = "show_continue_collection"
    private let collectionOldestFirstKey = "collection_oldest_first"
    private let initialTabKey = "initial_tab"
    private let commentSortKey = "comments_sort"

    /// When false (default), NSFW creators are hidden from Creators and Search.
    var showMatureContent: Bool {
        didSet { UserDefaults.standard.set(showMatureContent, forKey: matureKey) }
    }

    /// Master switch for automatic advance. The per-source switches below
    /// only apply while this is on.
    var autoplayNext: Bool {
        didSet { UserDefaults.standard.set(autoplayNext, forKey: autoplayNextKey) }
    }

    /// Auto-advance for the Home "New" shelf.
    var autoplayNew: Bool {
        didSet { UserDefaults.standard.set(autoplayNew, forKey: autoplayNewKey) }
    }

    /// Auto-advance for the "Continue Watching" shelf.
    var autoplayContinueWatching: Bool {
        didSet { UserDefaults.standard.set(autoplayContinueWatching, forKey: autoplayContinueWatchingKey) }
    }

    /// Auto-advance for creator pages and creator carousels.
    var autoplayChannels: Bool {
        didSet { UserDefaults.standard.set(autoplayChannels, forKey: autoplayChannelsKey) }
    }

    /// Auto-advance for collection episodes and Continue Collection.
    var autoplayCollections: Bool {
        didSet { UserDefaults.standard.set(autoplayCollections, forKey: autoplayCollectionsKey) }
    }

    func autoplayEnabled(for source: AutoplaySource) -> Bool {
        guard autoplayNext else { return false }
        switch source {
        case .new: autoplayNew
        case .continueWatching: autoplayContinueWatching
        case .channels: autoplayChannels
        case .collections: autoplayCollections
        }
    }

    /// When true (default), Home shows a "Continue Collection" shelf with the
    /// collection the user opened most recently.
    var showContinueCollection: Bool {
        didSet { UserDefaults.standard.set(showContinueCollection, forKey: continueCollectionKey) }
    }

    /// When true, a collection's episodes open oldest-first (ascending) by
    /// default; otherwise newest-first (descending). The on-screen toggle still
    /// overrides it for the session.
    var collectionOldestFirst: Bool {
        didSet { UserDefaults.standard.set(collectionOldestFirst, forKey: collectionOldestFirstKey) }
    }

    /// Which tab to open on launch (default Home).
    var initialTab: InitialTab {
        didSet { UserDefaults.standard.set(initialTab.rawValue, forKey: initialTabKey) }
    }

    /// Default order for a post's comments (default Best). The on-screen sort
    /// menu still overrides it for the current visit.
    var commentSort: CommentSort {
        didSet { UserDefaults.standard.set(commentSort.rawValue, forKey: commentSortKey) }
    }

    /// App interface language. Resolved from the system on first launch, then
    /// user-selectable in Settings.
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey) }
    }

    private init() {
        showMatureContent = UserDefaults.standard.bool(forKey: matureKey)

        autoplayNext = UserDefaults.standard.object(forKey: autoplayNextKey) as? Bool ?? true
        autoplayNew = UserDefaults.standard.object(forKey: autoplayNewKey) as? Bool ?? true
        autoplayContinueWatching = UserDefaults.standard.object(forKey: autoplayContinueWatchingKey) as? Bool ?? true
        autoplayChannels = UserDefaults.standard.object(forKey: autoplayChannelsKey) as? Bool ?? true
        autoplayCollections = UserDefaults.standard.object(forKey: autoplayCollectionsKey) as? Bool ?? true

        showContinueCollection = UserDefaults.standard.object(forKey: continueCollectionKey) as? Bool ?? true
        collectionOldestFirst = UserDefaults.standard.object(forKey: collectionOldestFirstKey) as? Bool ?? false
        initialTab = InitialTab(rawValue: UserDefaults.standard.string(forKey: initialTabKey) ?? "") ?? .home
        commentSort = CommentSort(rawValue: UserDefaults.standard.string(forKey: commentSortKey) ?? "") ?? .best
        if let raw = UserDefaults.standard.string(forKey: AppLanguage.storageKey),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            let resolved = AppLanguage.resolved(from: Locale.preferredLanguages)
            language = resolved
            UserDefaults.standard.set(resolved.rawValue, forKey: AppLanguage.storageKey)
        }
    }
}
