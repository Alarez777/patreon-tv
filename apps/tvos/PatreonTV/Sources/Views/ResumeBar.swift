//
//  ResumeBar.swift
//  PatreonTV
//
//  A thin resume indicator pinned to the bottom edge of a poster: the filled
//  fraction is how much of the post has been watched. Hidden when there's no
//  progress, the post is finished, or playback barely started.
//
//  Reads the persisted progress at render time (no live observation), so it
//  refreshes when the card is re-rendered — e.g. when you return to a collection.
//

import SwiftUI

struct ResumeBar: View {

    let postID: String
    /// Width of the poster it sits on; the bar tracks it.
    let width: CGFloat

    private let barHeight: CGFloat = 5
    /// Ignore trivially small progress (an accidental tap into a video).
    private let minPositionSeconds: Double = 5

    var body: some View {
        if let fraction {
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.45))
                Rectangle()
                    .fill(PatreonColors.brand)
                    .frame(width: width * fraction)
            }
            .frame(width: width, height: barHeight)
        }
    }

    private var fraction: Double? {
        guard let progress = PlaybackProgressStore.shared.progress(for: postID),
              progress.durationSeconds > 0,
              !progress.isFinished,
              progress.positionSeconds > minPositionSeconds
        else { return nil }
        return min(max(progress.positionSeconds / progress.durationSeconds, 0), 1)
    }
}
