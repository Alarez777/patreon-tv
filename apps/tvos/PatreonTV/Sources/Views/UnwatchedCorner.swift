//
//  UnwatchedCorner.swift
//  PatreonTV
//
//  A folded-corner triangle marking a post the viewer hasn't started. Sits in
//  the poster's top-right corner. Watched or in-progress posts omit it.
//
//  Reads the persisted progress at render time (like ResumeBar), so it updates
//  when the card is re-rendered.
//

import SwiftUI

struct UnwatchedCorner: View {

    let postID: String
    var size: CGFloat = 64

    var body: some View {
        if shows {
            CornerTriangle()
                .fill(PatreonColors.brand)
                .frame(width: size, height: size)
        }
    }

    private var shows: Bool {
        PlaybackProgressStore.shared.progress(for: postID) == nil
    }
}

/// Right triangle filling the top-right corner (right angle at top-right).
private struct CornerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
