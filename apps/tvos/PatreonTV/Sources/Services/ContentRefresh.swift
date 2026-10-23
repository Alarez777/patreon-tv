//
//  ContentRefresh.swift
//  PatreonTV
//
//  Shared refresh policy and the app-wide signal that a video/audio post
//  reached its end. Home listens for the notification so it can re-fetch the
//  stream while the player is still on screen.
//

import Foundation

enum ContentRefresh {
    /// Minimum gap between event-driven refreshes (foreground, re-appear).
    static let foregroundMinInterval: TimeInterval = 60

    /// Cadence while Home is visible and the app is active.
    static let pollInterval: TimeInterval = 5 * 60

    /// Minimum gap for creator/collection screens coming back into view.
    static let pageMinInterval: TimeInterval = 60
}

extension Notification.Name {
    /// Posted when playback of a post finishes (video or audio). Home uses it
    /// to pull the latest stream without waiting for the next poll tick.
    static let playbackDidFinish = Notification.Name("com.patreontv.playbackDidFinish")
}
