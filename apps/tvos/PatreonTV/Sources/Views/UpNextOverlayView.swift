//
//  UpNextOverlayView.swift
//  PatreonTV
//
//  Visual "Up Next" card shown over the player in the final seconds. It's a
//  preview only — the actionable controls are the player's native
//  `contextualActions` (Next / Cancel), so they get system focus.
//

import NukeUI
import SwiftUI

struct UpNextOverlayView: View {

    let post: Post
    let creatorName: String?
    /// Seconds left before auto-advance; nil hides the countdown ("Autoplay
    /// next" setting off). Driven by the player so it matches the video.
    let countdown: Int?

    var body: some View {
        // Fill the screen and anchor the card bottom-trailing so it reads as
        // part of the native action buttons. No full-screen dim (it would
        // darken those buttons).
        card
            .padding(.trailing, 80)
            // Sit above the native contextual-action buttons.
            .padding(.bottom, 200)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(false)
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 32) {
            poster

            VStack(alignment: .leading, spacing: 10) {
                Text(countdownLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PatreonColors.brand)
                    .textCase(.uppercase)

                Text(post.attributes.title ?? L10n.string("Untitled"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let creatorName {
                    Text(creatorName)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var poster: some View {
        LazyImage(url: post.attributes.posterImageURL) { state in
            if let image = state.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    PatreonColors.cardSurface
                    Image(systemName: post.attributes.postType.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(PatreonColors.tertiaryText)
                }
            }
        }
        .frame(width: 280, height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private var countdownLabel: String {
        if let countdown {
            return L10n.format("format.upNextIn", max(countdown, 0))
        }
        return L10n.string("Up Next")
    }

    private var accessibilitySummary: String {
        var parts = [
            L10n.format(
                "format.upNextTitle",
                post.attributes.title ?? L10n.string("Untitled")
            )
        ]
        if let creatorName { parts.append(L10n.format("format.fromCreator", creatorName)) }
        if let countdown { parts.append(L10n.format("format.autoPlayIn", max(countdown, 0))) }
        return parts.joined(separator: ", ")
    }
}
