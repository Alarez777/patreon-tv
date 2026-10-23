//
//  CommentSort.swift
//  PatreonTV
//
//  Sort order for a post's comments. The raw values match the labels shown in
//  Settings; `apiValue` is what the internal comments endpoint expects.
//

enum CommentSort: String, CaseIterable, Identifiable {
    case best
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .best: L10n.string("Best")
        case .newest: L10n.string("Newest")
        case .oldest: L10n.string("Oldest")
        }
    }

    /// JSON:API sort: `-` prefix means descending.
    var apiValue: String {
        switch self {
        case .best: "-vote_sum"
        case .newest: "-created"
        case .oldest: "created"
        }
    }
}
