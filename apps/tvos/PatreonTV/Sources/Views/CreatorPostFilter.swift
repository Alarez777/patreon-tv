//
//  CreatorPostFilter.swift
//  PatreonTV
//
//  Content-type filter for a creator's posts. Counts come from the campaign's
//  `post_count` breakdown so the menu can show real totals and hide categories
//  with no posts.
//

import Foundation

enum CreatorPostFilter: String, CaseIterable, Identifiable {
    case all, videos, images, text, audio, podcasts, polls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .videos: "Videos"
        case .images: "Images"
        case .text: "Text"
        case .audio: "Audio"
        case .podcasts: "Podcasts"
        case .polls: "Polls"
        }
    }

    /// Post types the API should return for this filter. Empty means unfiltered.
    var postTypes: [Post.PostType] {
        switch self {
        case .all: []
        case .videos: [.videoExternalFile, .videoEmbed]
        case .images: [.imageFile]
        case .text: [.textOnly]
        case .audio: [.audioFile, .audioEmbed]
        case .podcasts: [.podcast]
        case .polls: [.poll]
        }
    }

    /// Post count for this category from the campaign's `post_count` map.
    func count(in counts: Campaign.PostCount?) -> Int? {
        guard let counts else { return nil }
        switch self {
        case .all: return counts.total
        case .videos: return counts.video
        case .images: return counts.image
        case .text: return counts.text
        case .audio: return counts.audio
        case .podcasts: return counts.podcast
        case .polls: return counts.poll
        }
    }
}
