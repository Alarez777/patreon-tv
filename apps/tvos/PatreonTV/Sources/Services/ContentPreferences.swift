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
            case .home: "Home"
            case .creators: "Creators"
            case .search: "Search"
            case .lastUsed: "Last used"
            }
        }
    }

    private let matureKey = "show_mature_content"
    private let autoplayKey = "autoplay_next"
    private let continueCollectionKey = "show_continue_collection"
    private let collectionOldestFirstKey = "collection_oldest_first"
    private let initialTabKey = "initial_tab"
    private let commentSortKey = "comments_sort"

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

    private init() {
        showMatureContent = UserDefaults.standard.bool(forKey: matureKey)
        autoplayNext = UserDefaults.standard.object(forKey: autoplayKey) as? Bool ?? true
        showContinueCollection = UserDefaults.standard.object(forKey: continueCollectionKey) as? Bool ?? true
        collectionOldestFirst = UserDefaults.standard.object(forKey: collectionOldestFirstKey) as? Bool ?? false
        initialTab = InitialTab(rawValue: UserDefaults.standard.string(forKey: initialTabKey) ?? "") ?? .home
        commentSort = CommentSort(rawValue: UserDefaults.standard.string(forKey: commentSortKey) ?? "") ?? .best
    }
}
