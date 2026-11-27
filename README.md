# PatreonTV — the couch-first Patreon client for Apple TV

A native tvOS app for watching your favorite Patreon creators on the big screen.

PatreonTV is a standalone, free and open source (MIT) client: no companion app, no LAN server and no pairing portal. It signs in with your Patreon web session, so it can see the posts your membership unlocks, and plays video and audio directly without a proxy. Requires tvOS 17 or later.

## What you get

- **Home:** Recent across creators, Continue Watching, Continue Collection, and a shelf per creator.
- **Creators & search:** paid memberships above free follows, creator pages, post-type filters, collection browsing and catalog search.
- **Posts:** video, audio and podcasts, image galleries with a full-screen focus pager, text, polls and links.
- **Playback:** native Mux HLS video, Picture in Picture, chapters, Up Next, configurable autoplay, resume positions and watched state.
- **Collections:** browse, search and sort; series mode; Continue Collection with next-episode hints and new-episode badges; bulk mark watched and selection mode.
- **Comments:** threaded replies, expandable long comments and sort options.
- **Settings:** mature-content filter, language (English, Spanish, Portuguese and French), initial tab, comment order, autoplay by source, cache and viewing-history controls.
- **Top Shelf:** recent posts on the Apple TV home screen, with deep links back into the app.

## Download & install

Download the latest unsigned IPA from
[GitHub Releases](https://github.com/Alarez777/patreon-tv/releases/latest).
The asset is named `PatreonTV-<version>-unsigned.ipa`; release notes live in
[`CHANGELOG.md`](./CHANGELOG.md).

tvOS will not install it unsigned:

1. Sign it with your Apple ID or Apple Developer certificate, or build and run
   the app from Xcode with your team selected.
2. Install it with a sideloading tool such as
   [ATVLoadly](https://github.com/bitxeno/atvloadly). A free Apple ID works for
   7-day provisioning; a paid membership lasts longer.

PatreonTV is not on the App Store. It signs in with a Patreon web session, so
sideloading is the intended distribution channel.

## Sign in

PatreonTV uses the same web session as your browser. That is what lets the app
see paid posts; Patreon's OAuth tokens do not unlock them. There is no pairing
site and no intermediary server: the session ID goes straight from your browser
to the Apple TV.

> ⚠️ **Handle the `session_id` like a password.** Copy it on your own computer —
> not a shared or public one — and paste it straight into the Apple TV. Never
> send it through email, chat, or cloud notes: anyone who gets it can access
> your Patreon account. PatreonTV stores it securely in the tvOS Keychain, but
> the steps in between are up to you.

### 1. Get the `session_id` cookie

Do this on a computer. The cookie is HttpOnly, so mobile browsers can't reveal
it.

1. Open your browser's developer tools (`F12` on Windows/Linux, `⌥⌘I` on Mac)
   and sign in at [patreon.com](https://www.patreon.com).
2. Open the cookies panel:
   - **Firefox:** Storage → Cookies → `https://www.patreon.com`
   - **Chrome / Edge:** Application → Storage → Cookies → `https://www.patreon.com`
   - **Safari:** Develop → Show Web Inspector → Storage → Cookies
3. Select the `session_id` row and copy only its **value** (not the cookie
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
- Removing the app does not reliably clear the tvOS Keychain. Use
  **Settings → Sign Out** to delete the stored session.
- If you think the ID leaked, sign out of the Patreon session and sign in again
  with a fresh cookie.

## Notes

- PatreonTV uses Patreon's internal web API, so endpoints can change without
  notice.
- YouTube and Vimeo embeds open in their own apps instead of playing in-app.

## Development

Requires macOS 15.6+ and Xcode 26.3+ (the version CI uses), plus
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
git clone https://github.com/Alarez777/patreon-tv.git
cd patreon-tv/apps/tvos
xcodegen generate
open PatreonTV.xcodeproj
```

CI runs the build and tests on the tvOS Simulator. Pushing a `v*` tag runs the
`tvOS IPA` workflow and publishes the unsigned IPA to the matching GitHub
release; the tag must match `MARKETING_VERSION` in `apps/tvos/project.yml`. In a
fork, enable Actions and run **tvOS IPA** manually.

## Contributing

Issues and pull requests are welcome. AI coding agents should read
[`AGENTS.md`](./AGENTS.md) for repo-specific guidance.

## License

MIT — see [`LICENSE`](./LICENSE).

PatreonTV is an independent fork of
[DevelopmentCats/patreon-tv](https://github.com/DevelopmentCats/patreon-tv). It
is not affiliated with, endorsed by, or sponsored by Patreon, Inc. or the
upstream project.
