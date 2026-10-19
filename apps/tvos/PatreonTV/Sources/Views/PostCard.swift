//
//  PostCard.swift
//  PatreonTV
//
//  A single card on a shelf. Landscape 16:9 aspect (`400x225` at TV distance
//  is comfortable), with title + creator underneath. Uses NukeUI's
//  `LazyImage` for cached, non-flickering thumbnails.
//
//  tvOS rules honored:
//  - FOCUS-04: parallax effect on focus — .buttonStyle(.card) on the parent
//    NavigationLink applies this natively.
//  - FOCUS-05: 400×225 exceeds 250×150 minimum.
//  - ACCESS-01: full accessibility label + hint.
//

import NukeUI
import SwiftUI

struct PostCard: View {

    let post: Post
    var campaign: Campaign? = nil

    private let cardWidth: CGFloat = 400
    private let cardHeight: CGFloat = 225   // 16:9

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            posterImage
                .frame(width: cardWidth, height: cardHeight)
                .background(PatreonColors.cardSurface)
                .overlay(alignment: .topTrailing) {
                    if showsProgress { UnwatchedCorner(postID: post.id) }
                }
                .overlay(alignment: .topTrailing) {
                    if let count = post.galleryImageCount {
                        galleryBadge(count)
                    }
                }
                .overlay(alignment: .bottom) {
                    if showsProgress { ResumeBar(postID: post.id, width: cardWidth) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) { badge }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.attributes.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: cardWidth, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let url = post.attributes.posterImageURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            PatreonColors.cardSurface
            Image(systemName: post.attributes.postType.iconName)
                .font(.system(size: 48))
                .foregroundStyle(PatreonColors.tertiaryText)
        }
    }

    /// Instagram-style count for image galleries: number then overlapping
    /// squares, in a dark capsule so it reads over any artwork.
    private func galleryBadge(_ count: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(count)")
            Image(systemName: "square.on.square")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.65), in: Capsule())
        .padding(14)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        if post.attributes.isPaid == true {
            Text("PATRON")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PatreonColors.brand.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(14)
        }
    }

    private var subtitle: String? {
        campaign?.attributes.name
    }

    /// Watched/resume cues only make sense for content that can actually be
    /// played (video/audio). Polls, text, images and links never get progress.
    private var showsProgress: Bool {
        UpNextResolver.isPlayable(post)
    }

    private var accessibilityLabel: String {
        let title = post.attributes.title ?? "Untitled post"
        let creator = campaign?.attributes.name.map { " by \($0)" } ?? ""
        let paid = post.attributes.isPaid == true ? ", patron-only" : ""
        let images = post.galleryImageCount.map { ", \($0) images" } ?? ""
        return "\(title)\(creator)\(paid)\(images)"
    }
}
