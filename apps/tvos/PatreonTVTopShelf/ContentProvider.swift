//
//  ContentProvider.swift
//  PatreonTVTopShelf
//
//  Populates the tvOS Home Screen's top shelf with the current user's most
//  recent posts. The extension reads a shared App Group container that the
//  main app writes to; it does not talk to Patreon directly (extensions
//  have restricted lifecycles and shouldn't make long network calls).
//
//  The App Group only exists when the build's provisioning profile grants it
//  (paid account / not stripped by a re-sign). When it's missing the snapshot
//  is unavailable, so we fall back to a bundled branded board rather than
//  returning nil — a nil top shelf renders as a blank/black area.
//
//  Design rules from tvos-design-guidelines skill (Top Shelf category):
//  - TOP-01: sectioned layout for organized content presentation
//  - TOP-02: use TVTopShelfContentProvider (TVTopShelfProvider is deprecated
//    since tvOS 14)
//  - TOP-03: images high-quality (1920x720 wide, 620x800 poster)
//  - TOP-04: every item deep-links via URL scheme (patreontv://post/<id>)
//  - TOP-05: keep content fresh — regenerate on app-side snapshots
//

import Foundation
import os
// TVServices' TVTopShelfContent isn't marked Sendable yet; @preconcurrency
// keeps the async override warning-free under strict concurrency.
@preconcurrency import TVServices

final class ContentProvider: TVTopShelfContentProvider {

    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "TopShelf")

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        // Load the snapshot the main app wrote. It's absent on a fresh install,
        // when the app hasn't loaded Home yet, or when the App Group container
        // isn't available (e.g. a re-signed build without the entitlement).
        let snapshot = TopShelfSnapshot.load()
        if let snapshot {
            log.info("Top shelf: snapshot with \(snapshot.items.count, privacy: .public) items")
        } else {
            log.info("Top shelf: no snapshot; showing the fallback board")
        }

        let items: [TVTopShelfSectionedItem] = (snapshot?.items.prefix(10) ?? []).compactMap { entry in
            // Post IDs are numeric today, but a malformed snapshot must not
            // crash the extension — skip the entry instead of force-unwrapping.
            guard let displayURL = URL(string: "patreontv://post/\(entry.postID)"),
                  let playURL = URL(string: "patreontv://post/\(entry.postID)/play")
            else { return nil }

            let item = TVTopShelfSectionedItem(identifier: entry.postID)
            item.title = entry.title
            item.playAction = TVTopShelfAction(url: playURL)
            item.displayAction = TVTopShelfAction(url: displayURL)

            if let imageURL = entry.imageURL {
                item.setImageURL(imageURL, for: .screenScale1x)
                item.setImageURL(imageURL, for: .screenScale2x)
            }

            item.imageShape = .hdtv

            return item
        }

        // Never return nil — a nil top shelf is a blank area. With no content to
        // draw, show the bundled branded board instead.
        let sectionItems = items.isEmpty ? [Self.fallbackItem()] : items
        log.info("Top shelf: returning \(sectionItems.count, privacy: .public) items")

        let section = TVTopShelfItemCollection(items: sectionItems)
        if !items.isEmpty {
            section.title = "Recent from Your Creators"
        }

        return TVTopShelfSectionedContent(sections: [section])
    }

    /// A single focusable board shown when there's no snapshot. Its image is a
    /// plain bundle resource (a file URL — asset catalogs don't expose one), so
    /// it needs no network and no App Group. Tapping it opens the app's Home.
    private static func fallbackItem() -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: "patreon-tv-fallback")
        item.imageShape = .hdtv

        if let displayURL = URL(string: "patreontv://home") {
            item.displayAction = TVTopShelfAction(url: displayURL)
        }
        if let oneX = Bundle.main.url(forResource: "top-shelf-fallback", withExtension: "png") {
            item.setImageURL(oneX, for: .screenScale1x)
        }
        if let twoX = Bundle.main.url(forResource: "top-shelf-fallback@2x", withExtension: "png") {
            item.setImageURL(twoX, for: .screenScale2x)
        }

        return item
    }
}
