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
}

struct CollectionShelf: View {

    let title: String
    let cards: [CollectionCardModel]

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
                            CollectionShelfCard(card: card)
                        }
                        .buttonStyle(.card)
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
                if let count = card.numPosts {
                    Text("\(count) posts")
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.title)
    }
}
