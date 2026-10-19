//
//  CollectionSort.swift
//  PatreonTV
//
//  Ordering and filtering for a creator's collections.
//

import Foundation

enum CollectionSort: String, CaseIterable, Identifiable, Codable {
    case newest
    case oldest
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .titleAscending: "Title A–Z"
        case .titleDescending: "Title Z–A"
        }
    }

    /// Patreon returns collections newest-first, so `.newest` keeps the fetched
    /// order untouched and `.oldest` reverses it. Title sorts are stable: equal
    /// titles retain their original relative order.
    func sorted(_ collections: [PatreonCollection]) -> [PatreonCollection] {
        switch self {
        case .newest:
            return collections
        case .oldest:
            return Array(collections.reversed())
        case .titleAscending, .titleDescending:
            break
        }

        let ascending = self == .titleAscending
        return collections.enumerated().sorted { lhs, rhs in
            let left = lhs.element.attributes.title ?? ""
            let right = rhs.element.attributes.title ?? ""
            let comparison = left.localizedStandardCompare(right)

            if comparison == .orderedSame {
                return lhs.offset < rhs.offset
            }
            return ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }.map(\.element)
    }
}

enum CollectionSearch {

    /// Case- and diacritic-insensitive match over a collection's title and
    /// description. An empty query matches everything.
    static func filter(_ collections: [PatreonCollection], query: String) -> [PatreonCollection] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return collections }

        return collections.filter { collection in
            [collection.attributes.title, collection.attributes.description]
                .compactMap { $0 }
                .contains { normalize($0).contains(normalizedQuery) }
        }
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
