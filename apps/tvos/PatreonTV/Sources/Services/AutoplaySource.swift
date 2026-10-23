//
//  AutoplaySource.swift
//  PatreonTV
//
//  Where the post being played came from. Each source has its own
//  auto-advance preference.
//

enum AutoplaySource: String, Codable {
    case new
    case continueWatching
    case channels
    case collections
}
