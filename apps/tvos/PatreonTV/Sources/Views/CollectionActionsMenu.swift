//
//  CollectionActionsMenu.swift
//  PatreonTV
//
//  Press-and-hold menu on collection cards: add a collection to Continue
//  Collection, remove it temporarily, or hide it permanently.
//

import SwiftUI

extension View {
    /// Actions for a collection card on the Collections or search grid.
    func collectionActionsMenu(
        collection: PatreonCollection,
        campaignName: String? = nil
    ) -> some View {
        modifier(CollectionActionsMenu(entry: .collection(collection, campaignName)))
    }

    /// Actions for a card already shown in the Continue Collection shelf.
    func continueCollectionActionsMenu(card: CollectionCardModel) -> some View {
        modifier(CollectionActionsMenu(entry: .card(card)))
    }
}

private struct CollectionActionsMenu: ViewModifier {

    enum Entry {
        case collection(PatreonCollection, String?)
        case card(CollectionCardModel)

        var id: String {
            switch self {
            case .collection(let collection, _): collection.id
            case .card(let card): card.id
            }
        }

        var recentCollection: RecentCollection {
            switch self {
            case .collection(let collection, let campaignName):
                RecentCollection(
                    id: collection.id,
                    title: collection.attributes.title ?? L10n.string("Collection"),
                    squareImageURL: collection.attributes.thumbnail?.bestImageURL,
                    wideImageURL: collection.attributes.thumbnail?.wideImageURL,
                    numPosts: collection.attributes.numPosts,
                    campaignName: campaignName,
                    nextEpisodeTitle: nil
                )
            case .card(let card):
                RecentCollection(
                    id: card.id,
                    title: card.title,
                    squareImageURL: card.squareImageURL,
                    wideImageURL: card.wideImageURL,
                    numPosts: card.numPosts,
                    campaignName: card.campaignName,
                    nextEpisodeTitle: card.episodeTitle
                )
            }
        }
    }

    let entry: Entry

    func body(content: Content) -> some View {
        content.contextMenu {
            if RecentCollectionsStore.shared.isTracked(id: entry.id) {
                Button {
                    RecentCollectionsStore.shared.remove(id: entry.id)
                } label: {
                    Label("Remove from Continue Collection", systemImage: "minus.circle")
                }

                Button {
                    RecentCollectionsStore.shared.hide(id: entry.id)
                } label: {
                    Label("Remove Permanently", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    RecentCollectionsStore.shared.add(entry.recentCollection)
                } label: {
                    Label("Add to Continue Collection", systemImage: "plus.circle")
                }
            }
        }
    }
}
