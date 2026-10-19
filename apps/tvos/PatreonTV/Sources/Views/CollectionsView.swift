//
//  CollectionsView.swift
//  PatreonTV
//
//  A creator's collections (creator-curated lists of posts). Patreon exposes
//  them only as `include=collections` on the campaign (there is no list
//  endpoint), so this decodes those resources. Two-column grid: square art on
//  the left, title + description on the right.
//

import Observation
import SwiftUI

struct CollectionsView: View {

    let campaignID: String
    /// Remote Play on a collection card starts playback. Args: collection, post.
    var onPlayCollection: ((String, String) -> Void)? = nil

    @State private var vm = CollectionsViewModel()
    /// Initial focus lands on the first collection (a pushed page otherwise
    /// leaves focus on the tab bar).
    @FocusState private var focusedCollectionID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 32),
        GridItem(.flexible(), spacing: 32),
    ]

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView().controlSize(.large)
            case .error(let message):
                ErrorView(message: message) { Task { await vm.load(campaignID: campaignID) } }
            case .empty:
                empty
            case .loaded:
                content
            }
        }
        .task {
            await vm.load(campaignID: campaignID)
            // Move focus onto the first collection once the content is on screen.
            try? await Task.sleep(for: .milliseconds(200))
            focusedCollectionID = vm.collections.first?.id
        }
        .background(PatreonColors.background.ignoresSafeArea())
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                header

                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(vm.collections) { collection in
                        NavigationLink(value: DeepLinkDestination.collection(id: collection.id, focusPostID: nil)) {
                            CollectionRow(collection: collection)
                        }
                        .buttonStyle(.card)
                        .focused($focusedCollectionID, equals: collection.id)
                        .collectionPlay(collectionID: collection.id, onPlay: onPlayCollection)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }
        .scrollClipDisabled()
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Collections")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatreonColors.primaryText)

            Spacer()

            sortMenu

            NavigationLink {
                CollectionsSearchView(
                    collections: vm.collections,
                    onPlayCollection: onPlayCollection
                )
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .padding(14)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Search collections")
        }
        .padding(.horizontal, 60)
        .padding(.top, 60)
        // Lets Up from the first card reach the sort and search buttons.
        .focusSection()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CollectionSort.allCases) { sort in
                Button {
                    vm.select(sort: sort)
                } label: {
                    if sort == vm.sort {
                        Label(sort.title, systemImage: "checkmark")
                    } else {
                        Text(sort.title)
                    }
                }
            }
        } label: {
            Label(vm.sort.title, systemImage: "arrow.up.arrow.down")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Sort collections")
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack")
                .font(.system(size: 60))
                .foregroundStyle(PatreonColors.secondaryText)
            Text("No collections yet")
                .font(.title3)
                .foregroundStyle(PatreonColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search

private struct CollectionsSearchView: View {

    let collections: [PatreonCollection]
    let onPlayCollection: ((String, String) -> Void)?

    @State private var query = ""

    private let columns = [
        GridItem(.flexible(), spacing: 32),
        GridItem(.flexible(), spacing: 32),
    ]

    private var results: [PatreonCollection] {
        CollectionSearch.filter(collections, query: query)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if results.isEmpty {
                Text(emptyMessage)
                    .font(.title3)
                    .foregroundStyle(PatreonColors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(results) { collection in
                        NavigationLink(value: DeepLinkDestination.collection(id: collection.id, focusPostID: nil)) {
                            CollectionRow(collection: collection)
                        }
                        .buttonStyle(.card)
                        .collectionPlay(collectionID: collection.id, onPlay: onPlayCollection)
                    }
                }
                .padding(60)
            }
        }
        .scrollClipDisabled()
        .searchable(text: $query, prompt: "Search collections")
        .background(PatreonColors.background.ignoresSafeArea())
    }

    private var emptyMessage: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? "No collections"
            : "No collections match \"\(query)\""
    }
}

// MARK: - Row

private struct CollectionRow: View {

    let collection: PatreonCollection

    var body: some View {
        HStack(spacing: 24) {
            CollectionArtwork(urls: [collection.attributes.thumbnail?.bestImageURL])
                .frame(width: 200, height: 200)
                .background(PatreonColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(collection.attributes.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let description = collection.attributes.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                if let count = collection.attributes.numPosts {
                    Text("\(count) posts")
                        .font(.caption)
                        .foregroundStyle(PatreonColors.tertiaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(PatreonColors.cardSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - View model

@MainActor
@Observable
final class CollectionsViewModel {

    enum State: Equatable {
        case loading
        case loaded
        case empty
        case error(String)
    }

    var state: State = .loading
    private(set) var collections: [PatreonCollection] = []
    private(set) var sort: CollectionSort = .created
    /// The order Patreon sent, kept as the stable source for every sort.
    private var fetched: [PatreonCollection] = []
    /// The campaign already loaded; guards against a re-fetch on re-appear.
    private var loadedCampaignID: String?

    func load(campaignID: String) async {
        guard loadedCampaignID != campaignID else { return }
        state = .loading
        do {
            fetched = try await PatreonClient.shared.collections(campaignID: campaignID)
            loadedCampaignID = campaignID
            applySort()
            state = fetched.isEmpty ? .empty : .loaded
        } catch {
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func select(sort newSort: CollectionSort) {
        guard newSort != sort else { return }
        sort = newSort
        applySort()
    }

    private func applySort() {
        collections = sort.sorted(fetched)
    }
}
