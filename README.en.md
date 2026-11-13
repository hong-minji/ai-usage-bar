# AI Usage Bar

**Your remaining AI quota, right in your Mac menu bar.**

A free, open-source macOS app that puts **Claude, Codex, Gemini web and Antigravity** usage in one place.

[한국어](README.md) · **English**

[**↓ Download for Mac — v1.1.1**](https://github.com/hong-minji/ai-usage-bar/releases/download/v1.1.1/AIUsageBar-1.1.1-universal.zip) · [Releases / latest version](https://github.com/hong-minji/ai-usage-bar/releases) · [Report an issue](https://github.com/hong-minji/ai-usage-bar/issues)

Targets macOS 13+ · One download for Apple Silicon and Intel · Korean app UI · MIT license

> This is an early public release. It is ad-hoc signed, without Apple Developer ID signing or notarization, so macOS may block the first launch. Read [First launch](#first-launch) below. Windows and Linux are not supported.

<img src="docs/screenshot.png" width="440" alt="AI Usage Bar menu bar and dropdown showing remaining quota by provider">

```text
C 75% · G 81% · Ge 93% · Ag 0%
```

These are example values. Every percentage means **remaining, not used**. If a provider has multiple limits, such as a five-hour and weekly window, the menu bar shows the smallest remaining percentage. Open the menu for individual limits and reset times where available.

## Install with AI — share this link

Not familiar with installing apps? **Give your AI assistant the repository URL below and ask it to help.** This README includes the download links, installation steps and provider setup instructions, so you do not need to gather files separately.

Copy and paste this to get started:

```text
https://github.com/hong-minji/ai-usage-bar

I'd like to install this app on my Mac. Read the README and help me set it up
for my environment. Prefer the app ZIP from the latest release and connect
only the AI services I use. Walk me through any sign-in, macOS launch approval
and Chrome extension steps I need to do myself. At the end, help me check
that the app appears in the menu bar and its usage readings refresh.
```

An AI chat that can read web links can guide you step by step. **An AI tool with permission to work with files and the terminal on your Mac** can also help download and install the app. What it can do depends on its access; you may need to handle sign-in and first-launch approvals yourself. You do not need to paste passwords or authentication tokens into the chat.

To install it yourself, follow the steps below.

## Download and get started

1. Use **Download for Mac** above to get `AIUsageBar-1.1.1-universal.zip`. The same file supports Apple Silicon and Intel.
2. Double-click the ZIP to extract it. It contains `AIUsageBar.app`, `START-HERE.txt` and `LICENSE.txt`.
3. **Move the app to Applications before opening it.** Choose its permanent location before connecting Gemini.
4. Find the app in the menu bar at the top of the screen. Open **설정…** (Settings) → **표시 항목** (Visible items) and keep only the services you use. There is no Dock icon.
5. Check the sign-in requirements below. For Gemini, complete the one-time [Chrome setup](#connect-gemini-web).

The downloaded app does not require Xcode, Homebrew or Node.js. A provider's login tool or Chrome is needed only for that provider. GitHub's **Code → Download ZIP** and the **Source code** release assets contain source files; the runnable app is in `AIUsageBar-…-universal.zip` linked above.

### First launch

The app currently has an ad-hoc signature only. If you downloaded it from this repository and trust its origin, try opening it once, then go to **System Settings → Privacy & Security → Open Anyway**. See [Apple's official instructions](https://support.apple.com/en-us/102445). A managed work Mac may restrict this option.

macOS may also ask for Keychain access when connecting Claude. This lets the app read the existing Claude Code login. It never refreshes or changes the token.

## Supported services

| Menu bar | Quota shown | What you need |
|---|---|---|
| `C` | Claude five-hour and weekly limits | Claude Code signed in on this Mac, with credentials in the macOS Keychain |
| `G` | **Codex** limits | A ChatGPT account login saved in `~/.codex/auth.json` on this Mac |
| `Ge` | **Gemini web** limits | Google Chrome signed into Gemini, plus the bundled extension |
| `Ag` | Antigravity coding quota | The `agy` CLI installed and signed in; set its path in Settings if needed |

**`G` does not show general ChatGPT chat limits.** Gemini web and Antigravity also have separate quotas. Signing into the Claude or ChatGPT website alone is insufficient. This app does not track API-key billing or usage.

- Enable only the services you use. Hidden services are not queried. Antigravity is off by default.
- Refreshes every five minutes and when you open the menu. The app's interval is configurable from 1–120 minutes.
- On failure, it shows the last successful reading with its age and an error. With no previous reading, it shows that usage is unavailable. A failed request never becomes a fabricated `0%`.
- It sends no model prompts. It uses quota requests, the usage page and `agy /quota`.

## Connect Gemini web

Google Chrome is required. The extension is bundled inside the app; it is not published on the Chrome Web Store.

1. In the installed app, open **설정…** (Settings) → **Gemini 웹** → **Chrome 연결…** (Connect Chrome). This registers the current app location and copies the extension folder path to your clipboard.
2. In the Chrome profile signed into Gemini, open `chrome://extensions/`.
3. Turn on **Developer mode** in the top right and choose **Load unpacked**.
4. In the folder picker, press **⌘⇧G**, paste, press **Enter**, then select that folder.
5. Open **AI 사용량 · Gemini 연결** from Chrome's extensions menu and press **지금 갱신** (Refresh now).

If you use multiple Google accounts, enter the desired email in the extension popup to pin an account. Leave it empty to use the current Chrome profile's account. Readings are rejected when the displayed account cannot be verified or does not match the pinned account.

While Chrome is running, the extension opens an inactive usage tab every five minutes, reads it and closes it. A tab you select yourself is not automatically closed. The usage page must be in **Korean or English**. If Chrome is closed or the page cannot be read, previous readings become stale.

Load only the extension folder supplied by the app and keep the app in its installed location. If you move it, click **Chrome 연결…** again and load the extension from the new location. The app button supports Google Chrome. See [Contributing](CONTRIBUTING.md) for the developer tool for other Chromium browsers.

## Update and uninstall

**Update:** Quit the existing app from its menu → download the new ZIP from [Releases](https://github.com/hong-minji/ai-usage-bar/releases) → replace the app in the same Applications location → reopen it. Updates are manual. Reload the Gemini extension at `chrome://extensions/`. If the app moved, reconnect Chrome and toggle launch at login off and on.

**Uninstall:** In Settings, turn off **로그인 시 자동 실행** (Launch at login), quit, then move the app to Trash. If you connected Gemini, remove its Chrome extension and the registration file below. Remove the cache folder to erase usage history, and the preferences file to erase settings.

```text
Chrome registration: ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.local.ai_usage_bar.gemini.json
Usage cache: ~/Library/Application Support/AIUsageBar/
App preferences: ~/Library/Preferences/com.local.ai-usage-bar.plist
Launch at login: ~/Library/LaunchAgents/com.local.ai-usage-bar.plist
```

Turning off launch at login removes its file. If you used the developer installer, also remove the Native Messaging registrations it created for other browsers.

## Privacy and access

- No developer server, analytics, advertising or telemetry. Usage requests go to the relevant service provider.
- Claude and Codex credentials are read only. The app never refreshes tokens or saves its own copy of them.
- The Gemini extension reads account identity and figures from usage pages on `gemini.google.com`. It does not copy cookies, passwords or conversations.
- Local caches contain usage, labels, plan information and timestamps. The Gemini bridge cache also contains the verified email, page URL and connection status. Cache file permissions are set to owner-only (`0600`).
- A pinned email and connection state are also kept in Chrome extension local storage, which is removed when the extension is uninstalled.

This is an independent app. Changes to a provider's authentication, responses or page layout can interrupt a connection or prevent readings.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No window after opening the app | Look in the top menu bar. There is no Dock icon or regular app window. |
| macOS blocks launch | Follow First launch above and Apple's official guidance. |
| Claude login unavailable | Check Claude Code sign-in and Keychain access. |
| Codex login unavailable | A ChatGPT login must be saved in `~/.codex/auth.json` on this Mac. |
| Gemini needs a menu bar app connection | Click **Chrome 연결…** in the currently installed app and reload the extension. |
| Gemini shows old values | Check that Chrome is running and signed in, then press **지금 갱신** in the extension popup. |
| An unused service shows an error | Disable it under **설정… → 표시 항목**. |
| Antigravity fails | Check `agy` sign-in and the executable path. |

Still stuck? [Open an issue](https://github.com/hong-minji/ai-usage-bar/issues/new/choose) with the app version, macOS version, Mac architecture, affected service and reproduction steps. Do not include emails, tokens, authentication files or private conversations.

## Development and verification

Source builds require Xcode Command Line Tools. Run `xcode-select --install` and finish installation first.

```sh
git clone https://github.com/hong-minji/ai-usage-bar.git
cd ai-usage-bar
./build.sh
open build/AIUsageBar.app
```

```sh
./build.sh test                       # Swift checks
node --test ChromeExtension/tests.cjs # Extension tests; requires Node.js
./package.sh                         # Both architectures, ZIP and SHA-256
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once # One live check
```

For `v1.1.1`, 122 Swift checks and 21 extension tests passed, along with the universal build, ZIP extraction and signature verification. All four providers were checked on the development Mac. **Installation and execution have not been verified on macOS 13 or every supported Mac model.**

To verify file integrity, download the release ZIP and its `.sha256` file into the same folder, then run:

```sh
shasum -a 256 -c AIUsageBar-1.1.1-universal.zip.sha256
```

[Contributing](CONTRIBUTING.md) · [Gemini extension](ChromeExtension/) · [Release notes](docs/releases/v1.1.1.md)

## License

[MIT](LICENSE). Free to use, modify and redistribute. Provider accounts and subscriptions are separate. This project is not affiliated with or endorsed by Anthropic, OpenAI or Google.
