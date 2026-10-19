//
//  CommentsView.swift
//  PatreonTV
//
//  Read-only comments for a post. The API returns a flat, chronological list
//  with a `parent` pointer per comment; we rebuild the reply tree on each page
//  so replies sit under their parent.
//

import NukeUI
import SwiftUI
import os

struct CommentsView: View {

    let postID: String

    @State private var vm: CommentsViewModel
    @FocusState private var focusedCommentID: String?

    init(postID: String) {
        self.postID = postID
        _vm = State(initialValue: CommentsViewModel(postID: postID))
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView().controlSize(.large)
            case .empty:
                emptyState
            case .error(let message):
                ErrorView(message: message) { Task { await vm.reload() } }
            case .loaded:
                content
            }
        }
        .task {
            await vm.load()
            // A pushed page otherwise leaves focus on the tab bar.
            try? await Task.sleep(for: .milliseconds(250))
            focusedCommentID = vm.items.first?.id
        }
        .background(PatreonColors.background.ignoresSafeArea())
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                ForEach(vm.items) { item in
                    row(item)
                        .onAppear {
                            if item.id == vm.items.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
            .padding(.bottom, 60)
        }
        .scrollClipDisabled()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Comments")
                .font(.largeTitle.bold())
                .foregroundStyle(PatreonColors.primaryText)
            Text(vm.total == 1 ? "1 comment" : "\(vm.total) comments")
                .font(.title3)
                .foregroundStyle(PatreonColors.secondaryText)
        }
        .padding(.bottom, 14)
    }

    private func row(_ item: CommentsViewModel.Item) -> some View {
        Button {} label: {
            HStack(alignment: .top, spacing: 16) {
                avatar(item.author)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(item.author?.attributes.fullName ?? "Someone")
                            .font(.headline)
                            .foregroundStyle(PatreonColors.primaryText)

                        if item.comment.attributes.isByCreator == true {
                            badge("Creator")
                        }
                        if item.comment.attributes.isByPatron == true {
                            badge("Patron")
                        }

                        if let date = dateText(item.comment.attributes.created) {
                            Text(date)
                                .font(.subheadline)
                                .foregroundStyle(PatreonColors.tertiaryText)
                        }

                        Spacer()

                        Label("\(item.comment.attributes.voteSum ?? 0)", systemImage: "heart")
                            .font(.subheadline)
                            .foregroundStyle(PatreonColors.secondaryText)
                    }

                    if let parentAuthor = item.parentAuthor {
                        Text("Reply to \(parentAuthor.attributes.fullName ?? "someone")")
                            .font(.caption)
                            .foregroundStyle(PatreonColors.tertiaryText)
                    }

                    if item.comment.attributes.deletedAt != nil {
                        Text("This comment was deleted.")
                            .italic()
                            .foregroundStyle(PatreonColors.secondaryText)
                    } else if let body = item.comment.attributes.body, !body.isEmpty {
                        Text(HTMLRenderer.attributedString(from: body))
                            .font(.body)
                            .foregroundStyle(PatreonColors.primaryText.opacity(0.92))
                    }
                }
            }
            .padding(18)
            .background(
                focusedCommentID == item.id ? Color.black.opacity(0.55) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focusedCommentID, equals: item.id)
        .padding(.leading, CGFloat(min(item.depth, 3)) * 44)
        .accessibilityElement(children: .combine)
    }

    private func avatar(_ user: PatreonUser?) -> some View {
        LazyImage(url: user?.attributes.imageURL ?? user?.attributes.thumbURL) { state in
            if let image = state.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    PatreonColors.cardSurface
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(PatreonColors.tertiaryText)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(PatreonColors.brand.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }

    private func dateText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else {
            return nil
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(PatreonColors.secondaryText)
            Text("No comments yet")
                .font(.title2)
                .foregroundStyle(PatreonColors.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View model

@Observable
@MainActor
final class CommentsViewModel {

    /// One comment in display order, with its resolved author and reply depth.
    struct Item: Identifiable {
        let comment: Comment
        let author: PatreonUser?
        let parentAuthor: PatreonUser?
        let depth: Int
        var id: String { comment.id }
    }

    enum ViewState: Equatable { case idle, loading, loaded, empty, error(String) }

    private(set) var state: ViewState = .idle
    /// Flattened reply tree, in display order.
    private(set) var items: [Item] = []
    private(set) var total = 0

    private let postID: String
    private var comments: [Comment] = []
    private var usersByID: [String: PatreonUser] = [:]
    private var nextCursor: String?
    private var isFetchingMore = false

    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "Comments")

    init(postID: String) {
        self.postID = postID
    }

    func load() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            let page = try await PatreonClient.shared.comments(postID: postID)
            comments = page.data
            indexUsers(page.included)
            total = page.meta?.count ?? page.data.count
            nextCursor = page.nextCursor
            rebuild()
            state = items.isEmpty ? .empty : .loaded
        } catch {
            log.error("Comments load failed: \(String(describing: error))")
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isFetchingMore else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }
        do {
            let page = try await PatreonClient.shared.comments(postID: postID, cursor: cursor)
            let known = Set(comments.map(\.id))
            comments.append(contentsOf: page.data.filter { !known.contains($0.id) })
            indexUsers(page.included)
            nextCursor = page.nextCursor
            rebuild()
        } catch {
            log.error("Comments load-more failed: \(String(describing: error))")
        }
    }

    private func indexUsers(_ included: [Included]?) {
        for inc in included ?? [] {
            if case .user(let user) = inc { usersByID[user.id] = user }
        }
    }

    private func author(for comment: Comment) -> PatreonUser? {
        guard let userID = comment.relationships?.commenter?.data?.id else { return nil }
        return usersByID[userID]
    }

    /// Rebuild the flattened reply tree from the flat comment list. Comments
    /// whose parent isn't loaded yet stay at the root.
    private func rebuild() {
        let sorted = comments.sorted {
            ($0.attributes.created ?? "") < ($1.attributes.created ?? "")
        }
        var byID: [String: Comment] = [:]
        for comment in sorted { byID[comment.id] = comment }

        var children: [String: [Comment]] = [:]
        var roots: [Comment] = []
        for comment in sorted {
            if let parentID = comment.relationships?.parent?.data?.id, byID[parentID] != nil {
                children[parentID, default: []].append(comment)
            } else {
                roots.append(comment)
            }
        }

        var flattened: [Item] = []
        func walk(_ comment: Comment, depth: Int) {
            var parentAuthor: PatreonUser?
            if let parentID = comment.relationships?.parent?.data?.id {
                parentAuthor = usersByID[parentID]
            }
            flattened.append(Item(
                comment: comment,
                author: author(for: comment),
                parentAuthor: parentAuthor,
                depth: depth
            ))
            for child in children[comment.id] ?? [] {
                walk(child, depth: depth + 1)
            }
        }
        for root in roots { walk(root, depth: 0) }
        items = flattened
    }
}
