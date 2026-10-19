//
//  CommentsView.swift
//  PatreonTV
//
//  A post's comments. Top-level comments come from `/posts/{id}/comments2`;
//  replies are fetched per comment from `/comments/{id}/replies2` and only
//  shown once the comment is expanded. Expansion is recursive with no depth
//  limit — the viewer decides how far to drill in.
//

import NukeUI
import SwiftUI
import os

struct CommentsView: View {

    let postID: String

    @State private var vm: CommentsViewModel
    @FocusState private var focusedCommentID: String?

    init(postID: String, commentCount: Int? = nil) {
        self.postID = postID
        _vm = State(initialValue: CommentsViewModel(postID: postID, commentCount: commentCount))
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
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                ForEach(vm.items) { item in
                    CommentRow(
                        item: item,
                        focusedID: $focusedCommentID,
                        onExpandText: { vm.setTextExpanded(item.comment.id, true) },
                        onCollapseText: { vm.setTextExpanded(item.comment.id, false) },
                        onToggleReplies: { Task { await vm.toggleReplies(item.comment) } },
                        onCollapseReplies: { vm.collapseReplies(item.comment.id) }
                    )
                    .onAppear {
                        if item.id == vm.lastRootID {
                            Task { await vm.loadMoreRoots() }
                        }
                        if let parentID = item.parentID, item.isLastSibling {
                            Task { await vm.loadMoreReplies(parentID) }
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Comments")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PatreonColors.primaryText)
                Text(vm.total == 1 ? "1 comment" : "\(vm.total) comments")
                    .font(.title3)
                    .foregroundStyle(PatreonColors.secondaryText)
            }

            Spacer()

            sortMenu
        }
        .padding(.bottom, 14)
        .focusSection()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CommentSort.allCases) { sort in
                Button {
                    Task { await vm.select(sort: sort) }
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
        .accessibilityLabel("Sort comments")
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

// MARK: - Row

private struct CommentRow: View {

    let item: CommentThread.Item
    @FocusState.Binding var focusedID: String?
    let onExpandText: () -> Void
    let onCollapseText: () -> Void
    let onToggleReplies: () -> Void
    let onCollapseReplies: () -> Void

    /// Whether the body exceeds the visible line limit. Measured by the body
    /// view and used to decide what a click does.
    @State private var isTruncated = false

    var body: some View {
        Button(action: handleSelect) {
            HStack(alignment: .top, spacing: 16) {
                avatar

                VStack(alignment: .leading, spacing: 8) {
                    metadata
                    parentLine
                    bodyContent
                }
            }
            .padding(18)
            .background(
                focusedID == item.id ? Color.black.opacity(0.55) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focusedID, equals: item.id)
        .padding(.leading, CGFloat(item.depth) * 40)
        .accessibilityElement(children: .combine)
        .accessibilityHint(accessibilityHint)
    }

    private var metadata: some View {
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

            Label("\(item.replyCount)", systemImage: "bubble.left")
                .font(.subheadline)
                .foregroundStyle(PatreonColors.secondaryText)

            if item.hasReplies {
                Image(systemName: item.isRepliesExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PatreonColors.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var parentLine: some View {
        if let parentAuthor = item.parentAuthor {
            Text("Reply to \(parentAuthor.attributes.fullName ?? "someone")")
                .font(.caption)
                .foregroundStyle(PatreonColors.tertiaryText)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if item.comment.attributes.deletedAt != nil {
            Text("This comment was deleted.")
                .italic()
                .foregroundStyle(PatreonColors.secondaryText)
        } else if let body = item.comment.attributes.body, !body.isEmpty {
            CommentBodyText(
                text: HTMLRenderer.attributedString(from: body),
                isExpanded: item.isTextExpanded,
                isTruncated: $isTruncated
            )

            if isTruncated && !item.isTextExpanded {
                Label("Show more", systemImage: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PatreonColors.brand)
                    .padding(.top, 2)
            } else if isTruncated && item.isTextExpanded && !item.hasReplies {
                Label("Show less", systemImage: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PatreonColors.brand)
                    .padding(.top, 2)
            }
        }
    }

    /// Click order: expand clipped text → show replies → hide replies → clip
    /// the text again. A short comment skips straight to its replies.
    private func handleSelect() {
        if isTruncated && !item.isTextExpanded {
            onExpandText()
        } else if item.hasReplies && !item.isRepliesExpanded {
            onToggleReplies()
        } else if item.hasReplies && item.isRepliesExpanded {
            onCollapseReplies()
        } else if item.isTextExpanded {
            onCollapseText()
        }
    }

    private var accessibilityHint: String {
        if isTruncated && !item.isTextExpanded { return "Shows the full comment" }
        if item.hasReplies && !item.isRepliesExpanded { return "Shows replies" }
        if item.hasReplies && item.isRepliesExpanded { return "Hides replies" }
        if item.isTextExpanded { return "Collapses the comment" }
        return ""
    }

    private var avatar: some View {
        LazyImage(url: item.author?.attributes.imageURL ?? item.author?.attributes.thumbURL) { state in
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
}

// MARK: - Clamped body

/// Renders a comment body clamped to five lines. Two hidden copies (full and
/// clamped) are measured to know whether anything was cut off.
private struct CommentBodyText: View {

    let text: AttributedString
    let isExpanded: Bool
    @Binding var isTruncated: Bool

    private static let maxLines = 5

    @State private var fullHeight: CGFloat = 0
    @State private var clampedHeight: CGFloat = 0

    var body: some View {
        Text(text)
            .lineLimit(isExpanded ? nil : Self.maxLines)
            .background(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Text(text)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .background(measure(FullHeightKey.self))
                    Text(text)
                        .lineLimit(Self.maxLines)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .background(measure(ClampedHeightKey.self))
                }
            }
            .onPreferenceChange(FullHeightKey.self) { height in
                fullHeight = height
                updateTruncation()
            }
            .onPreferenceChange(ClampedHeightKey.self) { height in
                clampedHeight = height
                updateTruncation()
            }
    }

    private func updateTruncation() {
        guard fullHeight > 0, clampedHeight > 0 else { return }
        let truncated = fullHeight > clampedHeight + 1
        if truncated != isTruncated {
            isTruncated = truncated
        }
    }

    private func measure<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        GeometryReader { proxy in
            Color.clear.preference(key: key, value: proxy.size.height)
        }
    }
}

private struct FullHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ClampedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Thread flattening

/// Pure tree flattening so the visible rows are easy to test. Replies are kept
/// in `replies` by their direct parent id and only included when that parent is
/// in `expandedReplies`.
enum CommentThread {

    struct Item: Identifiable {
        let comment: Comment
        let author: PatreonUser?
        let parentAuthor: PatreonUser?
        let depth: Int
        /// Direct parent comment id. Nil for top-level comments.
        let parentID: String?
        /// True for the last reply a parent has loaded (drives reply paging).
        let isLastSibling: Bool
        /// Whether the body is showing in full.
        let isTextExpanded: Bool
        /// Whether this comment's replies are currently shown.
        let isRepliesExpanded: Bool

        var id: String { comment.id }
        var replyCount: Int { comment.attributes.replyCount ?? 0 }
        var hasReplies: Bool { replyCount > 0 }
    }

    static func flatten(
        roots: [Comment],
        replies: [String: [Comment]],
        expandedReplies: Set<String>,
        expandedText: Set<String>,
        authorByID: [String: PatreonUser]
    ) -> [Item] {
        var items: [Item] = []

        func append(_ comment: Comment, depth: Int, parentID: String?, isLastSibling: Bool) {
            items.append(Item(
                comment: comment,
                author: authorByID[comment.id],
                parentAuthor: parentID.flatMap { authorByID[$0] },
                depth: depth,
                parentID: parentID,
                isLastSibling: isLastSibling,
                isTextExpanded: expandedText.contains(comment.id),
                isRepliesExpanded: expandedReplies.contains(comment.id)
            ))
            guard expandedReplies.contains(comment.id) else { return }
            let children = replies[comment.id] ?? []
            for (index, child) in children.enumerated() {
                append(child, depth: depth + 1, parentID: comment.id, isLastSibling: index == children.count - 1)
            }
        }

        for (index, root) in roots.enumerated() {
            append(root, depth: 0, parentID: nil, isLastSibling: index == roots.count - 1)
        }
        return items
    }
}

// MARK: - View model

@Observable
@MainActor
final class CommentsViewModel {

    enum ViewState: Equatable { case idle, loading, loaded, empty, error(String) }

    private(set) var state: ViewState = .idle
    private(set) var items: [CommentThread.Item] = []
    private(set) var total: Int
    private(set) var sort: CommentSort

    private let postID: String
    private let providedTotal: Int?
    private var roots: [Comment] = []
    private var replies: [String: [Comment]] = [:]
    private var replyCursors: [String: String] = [:]
    private var expandedReplies: Set<String> = []
    private var expandedText: Set<String> = []
    private var usersByID: [String: PatreonUser] = [:]
    private var nextCursor: String?
    private var isFetchingMore = false
    private var loadingReplies: Set<String> = []

    private let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "Comments")

    init(postID: String, commentCount: Int?) {
        self.postID = postID
        self.providedTotal = commentCount
        self.sort = ContentPreferences.shared.commentSort
        self.total = commentCount ?? 0
    }

    /// Last top-level row currently visible — used to page the root list.
    var lastRootID: String? {
        items.last(where: { $0.parentID == nil })?.id
    }

    func load() async {
        guard state == .idle else { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            let page = try await PatreonClient.shared.comments(postID: postID, sort: sort)
            roots = page.data
            replies.removeAll()
            replyCursors.removeAll()
            expandedReplies.removeAll()
            expandedText.removeAll()
            nextCursor = page.nextCursor
            indexUsers(page.included)
            total = providedTotal ?? page.meta?.count ?? page.data.count
            rebuild()
            state = items.isEmpty ? .empty : .loaded
        } catch {
            log.error("Comments load failed: \(String(describing: error))")
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func select(sort newSort: CommentSort) async {
        guard newSort != sort else { return }
        sort = newSort
        // Keep the current list on screen while the new order loads, so focus
        // doesn't bounce back to the tab bar.
        do {
            let page = try await PatreonClient.shared.comments(postID: postID, sort: sort)
            roots = page.data
            replies.removeAll()
            replyCursors.removeAll()
            expandedReplies.removeAll()
            expandedText.removeAll()
            nextCursor = page.nextCursor
            indexUsers(page.included)
            total = providedTotal ?? page.meta?.count ?? page.data.count
            rebuild()
            state = items.isEmpty ? .empty : .loaded
        } catch {
            log.error("Comments re-sort failed: \(String(describing: error))")
        }
    }

    func loadMoreRoots() async {
        guard let cursor = nextCursor, !isFetchingMore else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }
        do {
            let page = try await PatreonClient.shared.comments(postID: postID, sort: sort, cursor: cursor)
            let known = Set(roots.map(\.id))
            roots.append(contentsOf: page.data.filter { !known.contains($0.id) })
            nextCursor = page.data.isEmpty ? nil : page.nextCursor
            indexUsers(page.included)
            rebuild()
        } catch {
            log.error("Comments load-more failed: \(String(describing: error))")
        }
    }

    func setTextExpanded(_ commentID: String, _ expanded: Bool) {
        if expanded {
            expandedText.insert(commentID)
        } else {
            expandedText.remove(commentID)
        }
        rebuild()
    }

    func toggleReplies(_ comment: Comment) async {
        guard (comment.attributes.replyCount ?? 0) > 0 else { return }

        if expandedReplies.contains(comment.id) {
            expandedReplies.remove(comment.id)
            rebuild()
            return
        }

        expandedReplies.insert(comment.id)
        rebuild()

        if replies[comment.id] == nil {
            await loadReplies(comment.id)
        }
    }

    func collapseReplies(_ commentID: String) {
        expandedReplies.remove(commentID)
        rebuild()
    }

    func loadMoreReplies(_ commentID: String) async {
        guard let cursor = replyCursors[commentID] else { return }
        await loadReplies(commentID, cursor: cursor)
    }

    private func loadReplies(_ commentID: String, cursor: String? = nil) async {
        guard !loadingReplies.contains(commentID) else { return }
        loadingReplies.insert(commentID)
        defer { loadingReplies.remove(commentID) }

        do {
            let page = try await PatreonClient.shared.replies(commentID: commentID, cursor: cursor)
            var merged = replies[commentID] ?? []
            let known = Set(merged.map(\.id))
            merged.append(contentsOf: page.data.filter { !known.contains($0.id) })
            replies[commentID] = merged.sorted {
                ($0.attributes.created ?? "") < ($1.attributes.created ?? "")
            }
            if merged.isEmpty {
                expandedReplies.remove(commentID)
            }
            if page.data.isEmpty {
                replyCursors.removeValue(forKey: commentID)
            } else if let next = page.nextCursor {
                replyCursors[commentID] = next
            } else {
                replyCursors.removeValue(forKey: commentID)
            }
            indexUsers(page.included)
            rebuild()
        } catch {
            log.error("Replies load failed for \(commentID): \(String(describing: error))")
            if cursor == nil {
                expandedReplies.remove(commentID)
                rebuild()
            }
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

    private func rebuild() {
        var authorByID: [String: PatreonUser] = [:]
        for root in roots {
            if let user = author(for: root) { authorByID[root.id] = user }
        }
        for list in replies.values {
            for comment in list {
                if let user = author(for: comment) { authorByID[comment.id] = user }
            }
        }
        items = CommentThread.flatten(
            roots: roots,
            replies: replies,
            expandedReplies: expandedReplies,
            expandedText: expandedText,
            authorByID: authorByID
        )
    }
}
