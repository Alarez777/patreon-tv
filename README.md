# PatreonTV — the couch-first Patreon client for Apple TV

A native tvOS app for watching your favorite Patreon creators on the big screen.

- **One app.** No companion, no LAN server, no pairing portal. Sign in once, done.
- **Netflix-style browsing.** Focus-driven shelves, hero art that follows what you're looking at, snappy transitions.
- **Native video.** Patreon-hosted video plays directly in `AVPlayer` via signed Mux HLS — no proxy, HDR, PiP, AirPlay.
- **Four languages.** English (US), Spanish (Latin America), Portuguese (Brazil), and French. The first launch follows the Apple TV language; Settings can change it.
- **Free & open source** — MIT.

> **Fork notice:** This repository started from
> [DevelopmentCats/patreon-tv](https://github.com/DevelopmentCats/patreon-tv)
> and has since diverged. It is maintained independently and is not affiliated
> with the upstream project.

## Status

**v2.0.0** — first public release of this fork (October 2026). The app is
feature-complete for browsing creators, collections, posts, comments and
video/audio playback, and ships as an unsigned IPA attached to the GitHub
release. See [`CHANGELOG.md`](./CHANGELOG.md) for everything that changed since
the fork.

## Repo layout

```
patreon-tv/
├── apps/tvos/          The Apple TV app (SwiftUI, tvOS 17+, XcodeGen)
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

## Download & install

Grab `PatreonTV-2.0.0-unsigned.ipa` from the
[latest release](https://github.com/Alarez777/patreon-tv/releases/latest).

The IPA is unsigned, so tvOS will not install it as-is:

1. Sign it with your own Apple Developer certificate, **or** build and run
   `apps/tvos` from Xcode with your team selected.
2. Install it with a sideloading tool such as
   [ATVLoadly](https://github.com/bitxeno/atvloadly) (Docker, Linux/OpenWrt) —
   it signs the IPA with your Apple ID or certificate and can auto-refresh it
   before the provisioning profile expires (7 days on a free Apple ID).

PatreonTV is **not on the App Store and there are no plans to publish it
there**. Sideloading is the only distribution channel: the project does not
ship with a paid developer account, and an app that signs in by asking for a
Patreon session cookie is a poor fit for App Store review.

## Build an installable IPA

Pushing a `v*` tag runs the **tvOS IPA** workflow, which builds the Release app
and attaches `PatreonTV-<version>-unsigned.ipa` to the matching GitHub release.
The version is read from `apps/tvos/project.yml`, and the workflow fails if the
tag does not match it. The `xcodebuild` log is kept as a run artifact.

To build without publishing — or from **your own fork**:

1. Fork this repo on GitHub.
2. In the fork, open the **Actions** tab and enable workflows (forks start with
   Actions disabled).
3. Run **tvOS IPA → Run workflow**.
4. Download `PatreonTV-unsigned` from the finished run's Artifacts.

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

PatreonTV uses the same web session as your browser. That is what lets the app
see paid posts; Patreon's OAuth tokens do not unlock them. There is no pairing
site and no intermediary server: the session ID goes straight from your browser
to the Apple TV.

> **Handle the `session_id` like a password.** Copy it on your own computer —
> not a shared or public one — and paste it straight into the Apple TV. Never
> send it through email, chat, or cloud notes: anyone who gets it can access
> your Patreon account. PatreonTV stores it securely in the tvOS Keychain, but
> the steps in between are up to you.

### 1. Get the `session_id` cookie

Do this on a computer. The cookie is HttpOnly, so mobile browsers can't reveal
it.

1. Open your browser and the developer tools:
   - Windows / Linux: `F12`
   - Mac: `⌥⌘I`
2. Sign in at [patreon.com](https://www.patreon.com).
3. Open the cookies panel:
   - **Firefox:** Storage → Cookies → `https://www.patreon.com`
   - **Chrome / Edge:** Application → Storage → Cookies → `https://www.patreon.com`
   - **Safari:** Develop → Show Web Inspector → Storage → Cookies
4. Select the `session_id` row and copy only its **value** (not the cookie
   name). In Firefox/Chrome you can right-click the value or double-click it
   and copy.

### 2. Send it to your iPhone or iPad

- **Mac + iPhone/iPad on the same Apple Account:** use **Universal Clipboard**.
  Copy the value on the Mac, focus the TV's session field, then paste from the
  iPhone/iPad keyboard. Make sure Handoff and Universal Clipboard are enabled on
  both devices.
- **Linux or Windows:** use [LocalSend](https://localsend.org) to send the
  value from the computer to the phone over your local network. It does not go
  through an internet service. KDE Connect is another option on Linux.
- **Avoid** email, chat, or cloud notes for this value — see the warning above.

### 3. Paste it on the TV

1. On the TV's sign-in screen, focus the **Session ID** field. The iPhone/iPad
   keyboard should appear.
2. Paste the value and choose **Continue**. The app checks it against Patreon
   and stores it only in the tvOS Keychain.
3. If pasting fails, you can type the value with the Siri Remote. It's long, but
   you should only need to do it once.

### Security notes

- The `session_id` grants full access to your Patreon account while it is valid.
  Keep it private.
- Signing out of that browser session may also sign out the TV.
- On a shared TV, use **Settings → Sign Out** when you're done. That removes the
  local copy; to revoke the session itself, sign out of it in the browser or
  change your Patreon password.
- If you think the ID leaked, sign out of the Patreon session and sign in again
  with a fresh cookie.

## Contributing

See [`AGENTS.md`](./AGENTS.md) if you're an AI coding agent working in this repo — it points you at the right skills and reference patterns for each task.

## License

MIT — see [`LICENSE`](./LICENSE).

This project is not affiliated with, endorsed by, or sponsored by Patreon.
