//
//  CollectionArtwork.swift
//  PatreonTV
//
//  Shared artwork for a collection: a cached, flicker-free image (Nuke) with a
//  square placeholder when there's no URL or the load fails. Used by the
//  collections list, the collection detail header, and the Home shelf card.
//

import NukeUI
import SwiftUI

struct CollectionArtwork: View {

    /// Candidate URLs, tried in order (the first non-nil wins).
    let urls: [URL?]
    var iconSize: CGFloat = 40

    var body: some View {
        if let url = urls.compactMap({ $0 }).first {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    PatreonColors.cardSurface
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            PatreonColors.cardSurface
            Image(systemName: "square.stack")
                .font(.system(size: iconSize))
                .foregroundStyle(PatreonColors.tertiaryText)
        }
    }
}
