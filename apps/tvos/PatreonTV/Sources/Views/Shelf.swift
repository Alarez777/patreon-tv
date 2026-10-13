//
//  Shelf.swift
//  PatreonTV
//
//  A horizontal shelf of posts. tvOS design rules FOCUS-02 (predictable
//  spatial movement), FOCUS-05 (minimum 250x150pt cards), FOCUS-09
//  (stable order).
//
//  Uses .focusSection() so vertical swipes move between shelves in the
//  parent VStack, and horizontal swipes move within this shelf.
//

import NukeUI
import SwiftUI

struct Shelf: View {

    let title: String
    let posts: [Post]
    /// Optional lookup: given a post, return its owning Campaign, so each card
    /// can show the creator's name.
    var campaignFor: ((Post) -> Campaign?)? = nil
    /// Called when the shelf's data source should page in more items — we pass
    /// the last-visible post so the caller can decide whether to fetch more.
    var onNearEnd: ((Post) -> Void)? = nil
    /// When set, the header becomes a focusable link (creator rows navigate
    /// to the creator's page). Shown with the optional avatar.
    var headerLink: DeepLinkDestination? = nil
    var headerAvatarURL: URL? = nil
    /// Called when the user presses Play/Pause on a focused card: open the post
    /// and start playback directly, skipping the detail screen's Play button.
    var onPlay: ((String) -> Void)? = nil
    /// When true, the shelf takes focus on its first card once posts are
    /// available. Used for Home's leading shelf when the app opens on a pinned
    /// tab, so focus lands in the content instead of the tab bar.
    var focusFirstCardOnEntry: Bool = false

    @FocusState private var focusedPostID: String?
    @State private var didFocusFirstCard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(posts) { post in
                        NavigationLink(value: DeepLinkDestination.post(id: post.id, autoplay: false, collectionID: nil)) {
                            PostCard(post: post, campaign: campaignFor?(post))
                        }
                        .buttonStyle(.card)   // Native tvOS focus effect (parallax + lift)
                        .postActionsMenu(postID: post.id)
                        .focused($focusedPostID, equals: post.id)
                        .onPlayPauseCommand { onPlay?(post.id) }
                        .onAppear {
                            // Cheap heuristic: if we're within 5 of the end,
                            // ask for more. Real prefetch policy lives in the
                            // view model.
                            if posts.suffix(5).contains(where: { $0.id == post.id }) {
                                onNearEnd?(post)
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 30)   // Breathing room for focused-card scale
            }
            .scrollClipDisabled()
        }
        .focusSection()
        // Keyed on the first post id and the enabled flag so it fires once posts
        // decode, and is *cancelled* if focus-on-entry is withdrawn mid-delay
        // (e.g. a deep link pushes a detail page right after launch), so the
        // launch focus can never steal focus from a pushed page.
        .task(id: focusTaskID) {
            guard focusFirstCardOnEntry, !didFocusFirstCard, let first = posts.first?.id else { return }
            didFocusFirstCard = true
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            focusedPostID = first
        }
    }

    /// Identity for the focus task. Includes the flag so a later `false` cancels
    /// the pending focus instead of letting it fire under a pushed page.
    private var focusTaskID: String {
        "\(posts.first?.id ?? "")|\(focusFirstCardOnEntry)"
    }

    @ViewBuilder
    private var header: some View {
        if let headerLink {
            NavigationLink(value: headerLink) {
                HStack(spacing: 16) {
                    if let headerAvatarURL {
                        LazyImage(url: headerAvatarURL) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                PatreonColors.cardSurface
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    }
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PatreonColors.secondaryText)
                }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 60)
            .accessibilityLabel("\(title), view creator")
        } else {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatreonColors.primaryText)
                .padding(.horizontal, 60)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
