//
//  UpNextOverlayView.swift
//  PatreonTV
//
//  Visual "Up Next" card shown over the player in the final seconds. It's a
//  preview only — the actionable controls are the player's native
//  `contextualActions` (Siguiente / Cancelar), so they get system focus.
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
        ZStack(alignment: .bottomTrailing) {
            // Dim the video behind so the card reads at 10 feet.
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            card
                .padding(.trailing, 80)
                // Sit above the native contextual-action buttons.
                .padding(.bottom, 200)
        }
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

                Text(post.attributes.title ?? "Untitled")
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
            return "Up Next in \(max(countdown, 0))s"
        }
        return "Up Next"
    }

    private var accessibilitySummary: String {
        var parts = ["Up next: \(post.attributes.title ?? "Untitled")"]
        if let creatorName { parts.append("from \(creatorName)") }
        if let countdown { parts.append("playing automatically in \(max(countdown, 0)) seconds") }
        return parts.joined(separator: ", ")
    }
}
