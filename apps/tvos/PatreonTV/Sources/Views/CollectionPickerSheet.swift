//
//  CollectionPickerSheet.swift
//  PatreonTV
//
//  Lets the user pick which collection to open when a post belongs to more than
//  one. Selecting a collection pushes it (focused on this post) inside the sheet.
//

import SwiftUI

struct CollectionPickerSheet: View {

    let collections: [PatreonCollection]
    let focusPostID: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Collections")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(PatreonColors.primaryText)
                        .padding(.top, 60)

                    ForEach(collections) { collection in
                        NavigationLink(value: DeepLinkDestination.collection(
                            id: collection.id,
                            focusPostID: focusPostID
                        )) {
                            CollectionPickerRow(collection: collection)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(60)
            }
            .background(PatreonColors.background.ignoresSafeArea())
            .appNavigationDestinations()
        }
    }
}

private struct CollectionPickerRow: View {

    let collection: PatreonCollection

    var body: some View {
        HStack(spacing: 24) {
            CollectionArtwork(urls: [collection.attributes.thumbnail?.bestImageURL])
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(collection.attributes.title ?? "Collection")
                    .font(.headline)
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(2)

                if let description = collection.attributes.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .lineLimit(2)
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
