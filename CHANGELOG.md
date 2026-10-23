# Changelog

All notable changes to PatreonTV are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.1] - 2026-10-23

### Added

- **Clear cache** in Settings, right above Sign Out. It reports how much the HTTP cache, the image cache and the Top Shelf snapshot are holding, and asks whether to clear the cache alone or the cache plus viewing history (Continue Watching and Continue Collection).
- A cookie-handling warning on the sign-in screen: copy the `session_id` on your own computer, never send it through email, chat or cloud notes, and remember that a leak gives access to the whole Patreon account. Translated into all four languages.
- `AuthStore` now takes a `SessionStorage` abstraction, with a unit test proving that signing out removes the stored credential.

### Changed

- The session-expired notice moved from the left column to the top of the sign-in card, where there is more room, and the cookie warning uses a smaller type size so both fit together.
- Signing out, and a session that Patreon rejects mid-use, now clear every cache layer: HTTP cache, Nuke's image cache, the in-memory collections caches and the Top Shelf snapshot. Viewing history is kept unless you delete it from Settings.
- Removed the marketing site (`site/`) and its Cloudflare Pages workflow. The app is distributed through GitHub Releases only.

### Fixed

- Explicitly documented that uninstalling the app does not reliably clear the tvOS Keychain; use Settings → Sign Out instead.

## [2.0.0] - 2026-10-22

First public release of the maintained fork. The app diverged from [DevelopmentCats/patreon-tv](https://github.com/DevelopmentCats/patreon-tv) and is now a standalone tvOS client: no companion app, no LAN server, no pairing portal.

### Added

- **Manual session sign-in.** Paste the Patreon `session_id` cookie from a desktop browser straight into the Apple TV; it is validated against Patreon and stored only in the tvOS Keychain. The web pairing relay was removed.
- **Home.** "New from Your Creators" shelf with pagination, optional Continue Watching and Continue Collection shelves, per-shelf focus handling, and an optional initial tab.
- **Creators.** Creator pages with member and post counts, post-type filters, path-based search across the whole catalog, and follow/unfollow actions.
- **Collections.** Browse a creator's collections, newest-first ordering matching Patreon's feed, collection playback that advances through episodes, and Continue Collection progress cards with the target episode title.
- **Comments.** Read a post's comments in threaded, line-aware blocks with on-demand replies and sort options.
- **Post types.** Text posts with ProseMirror rendering, polls with focusable rows, image galleries with a native focus carousel, and audio posts.
- **Playback.** Native Mux HLS playback, collection-aware Up Next, playback progress with resume bars and unwatched indicators, autoplay split by source, and chapter parsing.
- **Settings.** Two-column layout, initial tab, autoplay source and collection order, plus a language picker.
- **Localization.** English, Spanish (Latin America), Portuguese (Brazil), and French, with a CI check for missing keys.
- **Top Shelf.** Recent videos from your creators on the Apple TV home screen, with deep links into the app.
- **CI.** tvOS build and test workflow, a tag-driven Release IPA workflow that publishes the unsigned IPA to GitHub Releases, and repo hygiene checks.

### Changed

- Downloads and images use Nuke instead of `AsyncImage`, so shelves no longer flicker while recycling.
- The auto-advancing featured hero was removed; "New from Your Creators" now leads the Home screen.
- The player's Details tab was merged into the system Info panel, which now also shows a collection's episodes.
- Feeds refresh silently as new posts arrive, and returning to a collection keeps it instant.
- Watched posts are dropped from Continue Watching as soon as they finish.

### Fixed

- Mux playback failures on posts served through Patreon's preview endpoint.
- Long comments clamp to five lines before replies are shown.
- Focus contrast on settings controls and in the comment reader.
- Stale player events are ignored by post ID.
- Unexpected session-validation failures now show a distinct error instead of looking like an expired session.

### Known limitations

- The GitHub Release ships an **unsigned** IPA. Sign it with your own Apple Developer certificate or sideload it with [ATVLoadly](https://github.com/bitxeno/atvloadly).
- Universal Links are not enabled. Deep links use the `patreontv://` custom scheme only (for example from the Top Shelf).
- YouTube and Vimeo embeds open in their own apps; they are not played in-app.
- tvOS 17 or later is required.
