//
//  CollectionShelf.swift
//  PatreonTV
//
//  A horizontal shelf of collection cards, used by Home's "Continue Collection".
//

import SwiftUI

/// The fields a collection card needs, decoupled from where it came from
/// (the stored `RecentCollection`).
struct CollectionCardModel: Identifiable {
    let id: String
    let title: String
    let squareImageURL: URL?
    let wideImageURL: URL?
    let numPosts: Int?
    /// The collection's creator (campaign) name, when known.
    let campaignName: String?
    /// Title of the episode the Play would start (display hint). Nil hides it.
    let episodeTitle: String?
}

struct CollectionShelf: View {

    let title: String
    let cards: [CollectionCardModel]
    /// Remote Play on a collection card starts playback. Args: collection, post.
    var onPlayCollection: ((String, String) -> Void)? = nil

    @FocusState private var focusedCardID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatreonColors.primaryText)
                .padding(.horizontal, 60)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(cards) { card in
                        NavigationLink(value: DeepLinkDestination.collection(id: card.id, focusPostID: nil)) {
                            CollectionShelfCard(card: card, isActive: focusedCardID == card.id)
                        }
                        .buttonStyle(.card)
                        .focused($focusedCardID, equals: card.id)
                        .collectionPlay(collectionID: card.id, onPlay: onPlayCollection)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct CollectionShelfCard: View {

    let card: CollectionCardModel
    /// Scrolls the episode title while this card holds focus.
    var isActive: Bool = false

    private let cardWidth: CGFloat = 400
    private let cardHeight: CGFloat = 225   // 16:9

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CollectionArtwork(urls: [card.wideImageURL, card.squareImageURL])
                .frame(width: cardWidth, height: cardHeight)
                .background(PatreonColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "square.stack")
                        .font(.callout.weight(.semibold))
                        .padding(8)
                        .background(.black.opacity(0.55), in: Circle())
                        .foregroundStyle(.white)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                }
                if let episodeTitle = card.episodeTitle {
                    MarqueeText(
                        text: episodeTitle,
                        availableWidth: cardWidth,
                        isActive: isActive
                    )
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.title)
    }

    /// "N posts · Channel", whichever parts are available.
    private var subtitle: String? {
        var parts: [String] = []
        if let count = card.numPosts { parts.append("\(count) posts") }
        if let name = card.campaignName, !name.isEmpty { parts.append(name) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
