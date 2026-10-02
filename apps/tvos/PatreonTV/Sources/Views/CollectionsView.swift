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
                Text("Collections")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PatreonColors.primaryText)
                    .padding(.horizontal, 60)
                    .padding(.top, 60)

                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(vm.collections) { collection in
                        NavigationLink(value: DeepLinkDestination.collection(id: collection.id)) {
                            CollectionRow(collection: collection)
                        }
                        .buttonStyle(.card)
                        .focused($focusedCollectionID, equals: collection.id)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }
        .scrollClipDisabled()
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
    var collections: [PatreonCollection] = []

    func load(campaignID: String) async {
        state = .loading
        do {
            let collections = try await PatreonClient.shared.collections(campaignID: campaignID)
            self.collections = collections
            state = collections.isEmpty ? .empty : .loaded
        } catch {
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
