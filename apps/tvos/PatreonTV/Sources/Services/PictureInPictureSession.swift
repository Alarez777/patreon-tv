//
//  PictureInPictureSession.swift
//  PatreonTV
//
//  Owns the native player while its video floats in Picture in Picture, so the
//  delegate that brings it back to full screen survives the screen that started
//  it. Without this, navigating away deallocates the player host and the system
//  closes PiP instead of restoring it.
//

import Observation
import os.log

@Observable
@MainActor
final class PictureInPictureSession {

    static let shared = PictureInPictureSession()

    /// Player host retained while PiP runs.
    private(set) var host: PlayerHostViewController?
    /// Post floating in PiP, so pressing Play on it resumes that instance
    /// instead of starting a second player.
    private(set) var postID: String?
    /// Drives the app-level full-screen cover that brings the video back.
    var isRestoringFullScreen = false

    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "Player")

    private init() {}

    func adopt(host: PlayerHostViewController, postID: String) {
        self.host = host
        self.postID = postID
        log.info("PiP adopted post \(postID)")
    }

    func canRestore(postID: String) -> Bool {
        host != nil && self.postID == postID
    }

    /// Ask the app to present the floating player full screen again.
    func requestFullScreen() {
        guard let host else { return }
        // Already on screen: the screen that owns it never went away.
        guard host.viewIfLoaded?.window == nil else { return }
        isRestoringFullScreen = true
    }

    /// Dispose of the floating player and its session.
    func finish() {
        let current = host
        host = nil
        postID = nil
        isRestoringFullScreen = false
        current?.endSessionPlayback()
    }

    /// The host stopped on its own (PiP window closed or restored cover
    /// dismissed), so just forget it.
    func release(host: PlayerHostViewController) {
        guard self.host === host else { return }
        self.host = nil
        postID = nil
        isRestoringFullScreen = false
    }
}
