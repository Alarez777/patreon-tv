//
//  CreatorsView.swift
//  PatreonTV
//
//  Grid of the creators the user follows, split into paid memberships (listed
//  first) and free follows. Sourced from /api/members (active patrons + free
//  follows) unioned with /api/pledges (which surfaces hidden paid subscriptions
//  that /members can miss). See CreatorsViewModel.reload().
//

import NukeUI
import SwiftUI
import os

struct CreatorsView: View {

    /// When the app opens pinned to Creators, focus the first card instead of
    /// leaving focus on the tab bar.
    var focusFirstCardOnEntry: Bool = false

    @State private var vm = CreatorsViewModel()
    @State private var prefs = ContentPreferences.shared
    /// Navigation path, so a Creator page here can start playback within this
    /// tab (remote Play button on a focused post).
    @State private var path: [DeepLinkDestination] = []

    @FocusState private var focusedCardID: String?
    @State private var didFocusFirstCard = false

    /// Entries after applying the mature-content gate, split so the paid
    /// memberships are listed above the free follows.
    private var visiblePaid: [CreatorsViewModel.Entry] { visible(vm.paidEntries) }
    private var visibleFree: [CreatorsViewModel.Entry] { visible(vm.freeEntries) }

    private func visible(_ entries: [CreatorsViewModel.Entry]) -> [CreatorsViewModel.Entry] {
        prefs.showMatureContent
            ? entries
            : entries.filter { $0.campaign.attributes.isNSFW != true }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch vm.state {
                case .idle, .loading:
                    ProgressView().controlSize(.large)
                case .loaded:
                    if visiblePaid.isEmpty && visibleFree.isEmpty {
                        CreatorsEmptyView()
                    } else {
                        content
                    }
                case .empty:
                    CreatorsEmptyView()
                case .error(let m):
                    ErrorView(message: m) { Task { await vm.reload() } }
                }
            }
            .task { await vm.load() }
            .background(PatreonColors.background.ignoresSafeArea())
            .appNavigationDestinations(
                onPlayPost: { path.append(.post(id: $0, autoplay: true, collectionID: $1, queue: nil, source: .channels)) },
                onPlayCollection: { path.playCollection(collectionID: $0, postID: $1) }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                if !visiblePaid.isEmpty {
                    section(
                        title: L10n.string("Paid memberships"),
                        entries: visiblePaid,
                        isPaid: true
                    )
                }

                if !visibleFree.isEmpty {
                    section(
                        title: L10n.string("Free memberships"),
                        entries: visibleFree,
                        isPaid: false
                    )
                }
            }
            .padding(60)
        }
        .scrollClipDisabled()
        // Keyed on the first entry id and the enabled flag so it fires once
        // entries decode, and is cancelled if the page navigates away mid-delay
        // (so the launch focus can't steal focus from a pushed creator).
        .task(id: focusTaskID) {
            guard focusFirstCardOnEntry, path.isEmpty, !didFocusFirstCard,
                  let first = (visiblePaid.first ?? visibleFree.first)?.id else { return }
            didFocusFirstCard = true
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            focusedCardID = first
        }
    }

    /// One section header plus the grid of its creators. Paid memberships get
    /// the brand heart and primary text so they read as the important group.
    private func section(
        title: String,
        entries: [CreatorsViewModel.Entry],
        isPaid: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                if isPaid {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(PatreonColors.brand)
                }

                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        isPaid ? PatreonColors.primaryText : PatreonColors.secondaryText
                    )

                Text(L10n.number(entries.count))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(PatreonColors.tertiaryText)
            }
            .accessibilityElement(children: .combine)

            LazyVGrid(columns: gridColumns, spacing: 40) {
                ForEach(entries) { entry in
                    NavigationLink(value: DeepLinkDestination.creator(id: entry.campaign.id)) {
                        CreatorCard(campaign: entry.campaign)
                    }
                    .buttonStyle(.card)
                    .focused($focusedCardID, equals: entry.campaign.id)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 320, maximum: 380), spacing: 40)]
    }

    /// Identity for the focus task. Includes the flag/path so navigating away
    /// cancels the pending focus instead of letting it fire under a pushed page.
    private var focusTaskID: String {
        "\((visiblePaid.first ?? visibleFree.first)?.id ?? "")|\(focusFirstCardOnEntry && path.isEmpty)"
    }
}

struct CreatorsEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 80))
                .foregroundStyle(PatreonColors.secondaryText)
            Text("No creators yet")
                .font(.title2)
                .foregroundStyle(PatreonColors.primaryText)
            Text("Creators you actively support on Patreon will appear here.")
                .foregroundStyle(PatreonColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreatorCard: View {

    let campaign: Campaign

    private let cardWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyImage(url: campaign.attributes.bestAvatarURL) { state in
                // Initials placeholder sits underneath so it still shows when a
                // campaign's avatar is a broken/empty image (some return 200 blank).
                ZStack {
                    avatarPlaceholder
                    if let img = state.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    }
                }
            }
            .frame(width: cardWidth, height: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.attributes.name ?? L10n.string("Unknown creator"))
                    .font(.headline)
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(1)
                    .frame(width: cardWidth, alignment: .leading)

                if let creation = campaign.attributes.creationName {
                    Text(creation)
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: cardWidth, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("format.accessibilityCreator", campaign.attributes.name ?? L10n.string("Creator"), campaign.attributes.creationName ?? ""))
    }

    /// A colored tile with the creator's initial, used when no avatar loads.
    private var avatarPlaceholder: some View {
        let name = campaign.attributes.name ?? "?"
        let hue = Double(name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 360) / 360
        let tint = Color(hue: hue, saturation: 0.45, brightness: 0.5)
        return ZStack {
            LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(name.first.map { String($0).uppercased() } ?? "?")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - View model

@Observable
@MainActor
final class CreatorsViewModel {

    enum ViewState: Equatable { case idle, loading, loaded, empty, error(String) }

    /// A followed creator's campaign. Wrapped so the view can iterate directly.
    struct Entry: Identifiable {
        let campaign: Campaign
        /// Active paid membership, as opposed to a free follow.
        let isPaid: Bool
        var id: String { campaign.id }
    }

    private(set) var state: ViewState = .idle
    private(set) var entries: [Entry] = []

    var paidEntries: [Entry] { entries.filter(\.isPaid) }
    var freeEntries: [Entry] { entries.filter { !$0.isPaid } }

    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "Creators")

    func load() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            // The user's current creators, listed directly from /api/members
            // (active patrons + free follows; lapsed excluded), unioned with
            // /api/pledges to catch any paid sub missing from members. NSFW
            // filtering happens in the view so the Settings toggle applies live.
            let memberDoc = try await PatreonClient.shared.members()
            let pledgeDoc = try await PatreonClient.shared.pledges()

            var campaignsByID: [String: Campaign] = [:]
            for inc in (memberDoc.included ?? []) + (pledgeDoc.included ?? []) {
                if case .campaign(let campaign) = inc {
                    campaignsByID[campaign.id] = campaign
                }
            }

            let relationships = memberDoc.data
                .filter(\.isCurrentRelationship)
                .compactMap { member -> (campaignID: String, isPaid: Bool)? in
                    guard let campaignID = member.relationships?.campaign?.data?.id
                    else { return nil }
                    return (campaignID, member.isActivePatron)
                }

            let pledgeCampaignIDs = pledgeDoc.data.compactMap {
                $0.relationships?.campaign?.data?.id
            }

            let split = CreatorSections.split(
                members: relationships,
                pledgeCampaignIDs: pledgeCampaignIDs
            )

            entries = split.paid.compactMap { id in
                campaignsByID[id].map { Entry(campaign: $0, isPaid: true) }
            } + split.free.compactMap { id in
                campaignsByID[id].map { Entry(campaign: $0, isPaid: false) }
            }

            state = entries.isEmpty ? .empty : .loaded
        } catch {
            log.error("Creators load failed: \(String(describing: error))")
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
