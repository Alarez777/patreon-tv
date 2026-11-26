//
//  CollectionActionsMenu.swift
//  PatreonTV
//
//  Press-and-hold menu on collection cards: add a collection to Continue
//  Collection, remove it temporarily, hide it permanently, or mark every
//  episode as watched/unwatched.
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
                    nextEpisodeTitle: card.episodeTitle,
                    newEpisodeCount: card.newEpisodeCount
                )
            }
        }
    }

    private enum WatchAction: Equatable {
        case watched
        case unwatched
    }

    let entry: Entry
    @State private var pendingWatchAction: WatchAction?
    @State private var updateFailed = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
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

                Divider()

                Button {
                    pendingWatchAction = .watched
                } label: {
                    Label("Mark All Episodes as Watched", systemImage: "checkmark.circle")
                }

                Button {
                    pendingWatchAction = .unwatched
                } label: {
                    Label("Mark All Episodes as Unwatched", systemImage: "arrow.uturn.backward.circle")
                }
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: confirmationPresented,
                titleVisibility: .visible
            ) {
                if let action = pendingWatchAction {
                    switch action {
                    case .watched:
                        Button("Mark as Watched") { perform(.watched) }
                    case .unwatched:
                        Button("Mark as Unwatched", role: .destructive) { perform(.unwatched) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(confirmationMessage)
            }
            .alert("Couldn't Update Collection", isPresented: $updateFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(L10n.string("error.network"))
            }
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingWatchAction != nil },
            set: { if !$0 { pendingWatchAction = nil } }
        )
    }

    private var confirmationTitle: LocalizedStringKey {
        pendingWatchAction == .unwatched
            ? "Mark all episodes as unwatched?"
            : "Mark all episodes as watched?"
    }

    private var confirmationMessage: LocalizedStringKey {
        pendingWatchAction == .unwatched
            ? "Your progress for every episode in this collection will be cleared."
            : "Every playable episode in this collection will be marked as watched."
    }

    private func perform(_ action: WatchAction) {
        pendingWatchAction = nil
        Task { @MainActor in
            let updated = await CollectionWatchService.markAll(
                watched: action == .watched,
                collectionID: entry.id
            )
            if updated == nil {
                updateFailed = true
            }
        }
    }
}
