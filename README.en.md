# AI Usage Bar

> **v1.2.0 under review:** This guide describes the upcoming version. Live Chrome integration testing for the new Claude/Codex web connections is pending. See [published releases](https://github.com/hong-minji/ai-usage-bar/releases) for available downloads.

**Your remaining AI quota, right in your Mac menu bar.**

A free, open-source Mac menu bar app with **Claude · GPT · Codex · Gemini · agy** entries. Connect Claude, Codex and Gemini through Chrome, or keep using existing local logins and the agy CLI.

[한국어](README.md) · **English**

[**↓ Published Mac downloads**](https://github.com/hong-minji/ai-usage-bar/releases) · [Releases / latest version](https://github.com/hong-minji/ai-usage-bar/releases) · [Report an issue](https://github.com/hong-minji/ai-usage-bar/issues)

Targets macOS 13+ · One download for Apple Silicon and Intel · Korean app UI · MIT license

> This is an early public release. It is ad-hoc signed, without Apple Developer ID signing or notarization, so macOS may block the first launch. Read [First launch](#first-launch) below. Windows and Linux are not supported.

```text
Claude 75% · GPT – · Codex 81% · Gemini 93% · agy 0%
```

**These are example values. GPT chat shows `–` because an exact remaining allowance is not available to this app.** Its menu links to ChatGPT for model-specific limits. Codex figures are never substituted for GPT chat. Every percentage means **remaining, not used**. If a provider has multiple limits, such as a five-hour and weekly window, the menu bar shows the smallest remaining percentage. Open the menu for individual limits and reset times where available.

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

1. Use **Download for Mac** above to get `AIUsageBar-1.2.0-universal.zip`. The same file supports Apple Silicon and Intel.
2. Double-click the ZIP to extract it. It contains `AIUsageBar.app`, `START-HERE.txt` and `LICENSE.txt`.
3. **Move the app to Applications before opening it.** Choose its permanent location before connecting Chrome.
4. Find the app in the menu bar at the top of the screen. Open **설정…** (Settings) → **표시 항목** (Visible items) and keep only the services you use. There is no Dock icon.
5. Check the sign-in requirements below. For web logins, complete the one-time [Chrome setup](#connect-through-chrome-without-a-terminal).

The downloaded app does not require Xcode, Homebrew or Node.js. A provider's login tool or Chrome is needed only for that provider. GitHub's **Code → Download ZIP** and the **Source code** release assets contain source files; the runnable app is in `AIUsageBar-…-universal.zip` linked above.

### First launch

The app currently has an ad-hoc signature only. If you downloaded it from this repository and trust its origin, try opening it once, then go to **System Settings → Privacy & Security → Open Anyway**. See [Apple's official instructions](https://support.apple.com/en-us/102445). A managed work Mac may restrict this option.

macOS may also ask for Keychain access when connecting Claude. This lets the app read the existing Claude Code login. It never refreshes or changes the token.

## Supported services

| Label | What it measures | Without terminal tools | Existing local connection |
|---|---|---|---|
| **Claude** | Session and weekly quota | Claude signed in through Chrome + extension | Claude Code login |
| **GPT** | General ChatGPT chat | Exact remaining quota unsupported; `–` and a ChatGPT shortcut | Never borrows Codex figures |
| **Codex** | The web page's Codex / Work quota | ChatGPT signed in through Chrome + extension | ChatGPT login in `~/.codex/auth.json` |
| **Gemini** | Gemini web quota | Gemini signed in through Chrome + extension | Uses Chrome |
| **agy** | Antigravity coding quota | Not supported | agy CLI installed and signed in |

Web connections for Claude, Codex and Gemini do not require CLI installation. **For local connections, installation alone is insufficient: you must also be signed in.** You do not need to leave a terminal window open or repeatedly enter commands. Codex depends on its local login file, not on whether you personally use its CLI.

General GPT chat and Codex / Work are distinct entries. This version reflects the usage surfaces currently verified; provider policy or UI changes require revalidation. Gemini web and agy also have separate quotas. This is not an API billing tracker.

- Choose visible services in Settings. agy is hidden by default; enable it only if you use the CLI.
- The app refreshes every five minutes and when its menu opens; its interval is configurable from 1–120 minutes.
- Chrome polls every five minutes while running. Opening the app menu reads the latest report; use Refresh now in the extension for an immediate web fetch.
- Failures show the previous successful reading with its age and an error, never a fabricated `0%`.
- Only usage queries are made. No model prompts are sent.

## Connect through Chrome without a terminal

The extension is bundled in the app and is not on the Chrome Web Store. Usage pages must be in Korean or English. Sign into the services in the Chrome profile you want to use.

1. In the installed app, open **설정… → 웹 연결 → Chrome 연결…** (Settings → Web connection → Connect Chrome). This registers the app and copies the extension folder path.
2. Open `chrome://extensions/` in that Chrome profile and enable **Developer mode**.
3. Choose **Load unpacked**, press **⌘⇧G**, paste, press **Enter**, then select the folder.
4. Open **AI 사용량 · 웹 연결** from Chrome's extension menu.
5. Turn on **Claude 웹 연결** and/or **Codex / Work 웹 연결**. Gemini connects automatically as before.
6. Press the provider's **지금 갱신** (Refresh now). The app labels these readings **Chrome 웹** (Chrome web).

**Upgrading from v1.1.1?** Reload the extension and review its new Claude and ChatGPT site permissions. The new connection toggles are off by default.

Claude/Codex connection choices in the app:

| Choice | Behavior |
|---|---|
| 자동 (연결된 Chrome 우선) / Automatic | Uses an enabled Chrome connection when present, otherwise the existing local login |
| Chrome 웹만 — 터미널 불필요 / Chrome only | Reads browser reports without querying local credentials |
| 기존 로컬 로그인만 / Local only | Uses existing Claude Code / Codex credentials |

A browser error does not silently switch to a different local account. **Your browser and local apps may be signed into different accounts: check the Chrome profile you choose.** Claude/Codex reports use that profile's current signed-in account without collecting its email. Use one Chrome profile for the connection.

For Gemini, you can optionally pin a Google email in the extension popup. Otherwise it uses the current Google account. Unverifiable account identity is rejected.

The extension opens inactive usage tabs and closes them after reading. Tabs you select yourself are preserved. If you move the app, reconnect Chrome and load the extension from the new location. Keep the app and extension folder in place.

## Connect existing local logins

If you already signed into Claude Code or Codex, you can continue using that login. To choose the local account while Chrome is also connected, select **기존 로컬 로그인만** (Local only) in app Settings. Claude may ask for Keychain access.

agy requires CLI installation and sign-in. Set its executable path if automatic discovery fails. Hide agy if you do not use it.

## Update and uninstall

**Update:** Quit the existing app from its menu → download the new ZIP from [Releases](https://github.com/hong-minji/ai-usage-bar/releases) → replace the app in the same Applications location → reopen it. Updates are manual. Reload the web extension at `chrome://extensions/`. If the app moved, reconnect Chrome and toggle launch at login off and on.

**Uninstall:** In Settings, turn off **로그인 시 자동 실행** (Launch at login), quit, then move the app to Trash. If you connected Chrome, remove the extension and the registration file below. Remove the cache folder to erase usage history, and the preferences file to erase settings.

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
- The extension has site access to `claude.ai`, `chatgpt.com` and `gemini.google.com`. It extracts figures only from Claude/Codex usage settings and Gemini usage pages. It does not extract cookies, passwords or authentication tokens, or transmit conversation text.
- Claude/Codex web reports store only the provider, a fixed usage URL, time, percentages and quota labels. No emails, display names or page text are stored.
- Local caches contain usage, labels, plan information and timestamps. The Gemini bridge cache also contains the verified email, page URL and connection status. Cache file permissions are set to owner-only (`0600`).
- A pinned email and connection state are also kept in Chrome extension local storage, which is removed when the extension is uninstalled.

This is an independent app. Changes to a provider's authentication, responses or page layout can interrupt a connection or prevent readings.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No window after opening the app | Look in the top menu bar. There is no Dock icon or regular app window. |
| macOS blocks launch | Follow First launch above and Apple's official guidance. |
| Claude login unavailable | Enable Chrome web access or check the existing Claude Code login and Keychain access. |
| Codex login unavailable | Enable Chrome web access or check the existing local Codex login. |
| GPT shows `–` | Exact remaining chat quota is unavailable. Use the ChatGPT shortcut in the menu. |
| No web reading | Check extension reload, site permissions, service login and connection toggles. |
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
node --test ChromeExtension/*tests.cjs # Extension tests; requires Node.js
./package.sh                         # Both architectures, ZIP and SHA-256
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once # One live check
```

For `v1.2.0`, 144 Swift checks and 32 extension tests passed, along with the universal build, ZIP extraction and signature verification. Live verification scope is recorded in the release notes. Exact remaining GPT chat percentages are unsupported. **Installation and execution have not been verified on macOS 13 or every supported Mac model.**

To verify file integrity, download the release ZIP and its `.sha256` file into the same folder, then run:

```sh
shasum -a 256 -c AIUsageBar-1.2.0-universal.zip.sha256
```

[Contributing](CONTRIBUTING.md) · [Gemini extension](ChromeExtension/) · [Release notes](docs/releases/v1.2.0.md)

## License

[MIT](LICENSE). Free to use, modify and redistribute. Provider accounts and subscriptions are separate. This project is not affiliated with or endorsed by Anthropic, OpenAI or Google.
