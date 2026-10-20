# PatreonTV — the couch-first Patreon client for Apple TV

A native tvOS app for watching your favorite Patreon creators on the big screen.

- **One app.** No companion. No LAN server. Downloaded from the App Store, sign in once, done.
- **Netflix-style browsing.** Focus-driven shelves, hero art that follows what you're looking at, snappy transitions.
- **Native video.** Patreon-hosted video plays directly in `AVPlayer` via signed Mux HLS — no proxy, HDR, PiP, AirPlay.
- **Free & open source** — MIT.

## Status

**Early scaffolding.** Do not attempt to ship yet.

## Repo layout

```
patreon-tv/
├── apps/tvos/          The Apple TV app (SwiftUI, tvOS 17+, XcodeGen)
├── site/               Marketing + legal + deep-link fallback
│                       (Astro → Cloudflare Pages)
├── harness/            Node scripts for live-testing the Patreon API
└── docs/               User-facing docs (WIP)
```

## Getting started (on a Mac)

Prerequisites:
- macOS 14+ (Sonoma)
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Apple Developer Program membership (paid)

Steps:

```bash
git clone <this-repo>
cd patreon-tv/apps/tvos
xcodegen generate
open PatreonTV.xcodeproj
```

Choose your Apple TV or the tvOS Simulator as the run destination and build.

## Build an installable IPA

The **tvOS IPA** GitHub Actions workflow builds the Release app and uploads
three artifacts: an unsigned `.ipa` (`PatreonTV-unsigned`), the raw
`.xcarchive`, and the `xcodebuild` log. It is `workflow_dispatch`-only, so run
it from **your own fork**:

1. Fork this repo on GitHub.
2. In the fork, open the **Actions** tab and enable workflows (forks start with
   Actions disabled).
3. Run **tvOS IPA → Run workflow**.
4. Download `PatreonTV-unsigned` from the finished run's Artifacts.

The IPA is unsigned. Sign it with your own Apple Developer certificate (or just
build/run from Xcode with your team selected), then install it with a
sideloading tool such as [ATVLoadly](https://github.com/bitxeno/atvloadly)
(Docker, Linux/OpenWrt) — it signs the IPA with your Apple ID or certificate and
can auto-refresh it.

The same build, locally:

```bash
cd apps/tvos
xcodegen generate
xcodebuild \
  -project PatreonTV.xcodeproj \
  -scheme PatreonTV \
  -configuration Release \
  -destination "generic/platform=tvOS" \
  -archivePath "$PWD/build/PatreonTV.xcarchive" \
  archive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

## Sign-in

PatreonTV has no web intermediary. On first launch, open a browser and its
developer tools (F12, or ⌥⌘I on Mac), sign in at patreon.com, then copy the
`session_id` cookie from Application → Cookies (Chrome) or Storage → Cookies
(Firefox/Safari). Paste it into the Apple TV using the iPhone/iPad keyboard (or
type it with the Siri Remote). The cookie is validated against Patreon and
stored only in the tvOS Keychain.

## Contributing

See [`AGENTS.md`](./AGENTS.md) if you're an AI coding agent working in this repo — it points you at the right skills and reference patterns for each task.

## License

MIT — see [`LICENSE`](./LICENSE).

This project is not affiliated with, endorsed by, or sponsored by Patreon.
