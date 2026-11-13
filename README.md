# AI Usage Bar

맥 메뉴바에 Claude · ChatGPT(Codex) · Gemini 웹 · Antigravity의 **남은 사용량**을 한 줄로 표시합니다.

A macOS menu bar app that shows **how much of your AI quota is left** — Claude, ChatGPT (Codex), Gemini web and Antigravity — in one line.

<img src="docs/screenshot.png" width="440" alt="Claude, ChatGPT, Gemini, Antigravity의 남은 사용량을 보여주는 메뉴 / the menu showing remaining quota for each provider">

```
C 75% · G 81% · Ge 93% · Ag 0%
```

모든 숫자는 **남은 양**입니다. 작을수록 한도에 가깝습니다. 모델 표시는 각 서비스의 대표색을 쓰고 퍼센트는 항상 흰색입니다. 한도가 여러 개면 메뉴바에는 가장 적게 남은 것을 띄우고, 메뉴를 열면 전부 보여줍니다.

Every number is **remaining**, not used — the smaller it gets, the closer you are to the limit. Each provider keeps its brand colour; the percentage is always white. When a provider has several windows (5-hour, weekly), the bar shows the tightest one and the dropdown lists them all.

> 앱 UI는 한국어입니다. 시스템 언어와 무관하게 동작합니다.
> The app UI is in Korean; it works regardless of your system language.

---

## 왜 만들었나 / Why

AI 구독마다 한도도, 리셋 시각도, 확인하는 페이지도 전부 다릅니다. 그래서 작업이 끊기는 지점은 늘 같았습니다 — 모델이 "한도에 도달했습니다"라고 답하는 순간. 네 개의 숫자를 이미 늘 보고 있는 곳에 모으고, 인증 정보는 원래 있던 자리에 그대로 두었습니다.

Every AI subscription has its own limit, its own reset clock and its own page to check it. Hitting a weekly cap mid-task is annoying; discovering it only when the model refuses you is worse. This puts all four numbers where you already look, and keeps every credential where it already lives.

---

## 무엇을 어떻게 읽나 / What it reads

| 표시 · Bar | 서비스 · Provider | 데이터 · Source | 인증 · Auth |
|---|---|---|---|
| `C` | Claude 5시간 + 주간 한도 | `api.anthropic.com/api/oauth/usage` | Claude Code가 키체인에 저장해 둔 로그인 |
| `G` | ChatGPT **Codex** 한도 | `~/.codex/auth.json` + Codex 사용량 기록 | 기존 Codex 로그인 |
| `Ge` | **Gemini 웹** 한도 | `gemini.google.com/usage` | 기존 Chrome 로그인 (전용 확장 경유) |
| `Ag` | Antigravity 코딩 할당량 | `agy /quota` | `agy` CLI 자체 로그인 |

`G`는 일반 ChatGPT 채팅 한도가 아니라 **Codex** 한도입니다. Gemini 웹과 Antigravity도 서로 다른 예산입니다.

`G` is the **Codex** quota, not the ChatGPT chat quota. Gemini web and Antigravity are separate budgets.

기본 5분마다, 그리고 메뉴를 열 때 갱신합니다. 한 서비스가 실패하면 그 항목만 영향을 받고, `0%`로 표시하는 대신 마지막 성공값과 경과 시간을 함께 보여줍니다(`72% · 2일 전`).

It refreshes every 5 minutes and again when you open the menu. If one provider fails, only that row degrades: it keeps the last good value with its age instead of a misleading `0%`.

### 조회 자체는 사용량을 소모하지 않습니다 / Polling costs you nothing

| | |
|---|---|
| Claude · ChatGPT | 사용량 **조회 전용** 엔드포인트입니다. 모델을 호출하는 `/messages` 류가 아니라 "얼마 남았나"를 묻는 메타데이터 요청입니다. <br> Usage-reporting endpoints, not inference endpoints. |
| Gemini | 확장이 사용량 **페이지를 읽을 뿐** 대화를 걸지 않습니다. <br> The extension reads the usage page; it never sends a prompt. |
| Antigravity | `/quota`는 `agy`가 로컬에서 처리하는 슬래시 명령입니다. 실제 출력이 `num_turns: 0`, `total_tokens: 0`입니다. <br> A local slash command — it reports zero turns and zero tokens. |

즉 5분마다 돌려도, 하루 288번 돌려도 측정 대상인 할당량은 1토큰도 줄지 않습니다.

So polling never spends any of the quota it measures.

---

## 요구 사항 / Requirements

- macOS 13 이상 · macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — Xcode도 패키지 매니저도 외부 의존성도 필요 없습니다 / no Xcode, no package manager, no dependencies
- 실제로 쓰는 서비스의 로그인만 있으면 됩니다. 안 쓰는 건 숨기면 됩니다 (아래 참고) / only the providers you actually use; hide the rest

---

## 설치 / Install

```sh
git clone https://github.com/hong-minji/ai-usage-bar.git
cd ai-usage-bar
./build.sh                 # 테스트 후 build/AIUsageBar.app 생성 / tests, then builds the app
open build/AIUsageBar.app
```

메뉴바 전용 앱이라 Dock 아이콘이 없습니다. 이전 버전이 돌고 있으면 메뉴에서 먼저 종료하세요.

Menu bar only — no Dock icon. Quit any older copy from its menu first.

공증(notarize) 없이 로컬 임시 서명만 합니다. 직접 빌드한 앱이라 격리 속성이 없어 Gatekeeper 경고 없이 열립니다. Claude 로그인을 읽기 위해 macOS가 키체인 접근을 한 번 묻습니다 — 읽기만 하며 어떤 토큰도 갱신하거나 변경하지 않습니다.

Signed ad-hoc, not notarised. Because you built it yourself it is not quarantined, so it opens without a Gatekeeper prompt. macOS asks once for Keychain access to read the Claude login; the app only ever reads, and never refreshes or rotates a token.

---

## 안 쓰는 서비스 숨기기 / Hide what you don't use

네 개를 다 쓰는 사람은 드뭅니다. **설정 → 표시 항목**에서 체크를 끄면 그 서비스는 메뉴바에서 사라지고, **조회도 하지 않습니다.** 없는 로그인 때문에 빨간 오류가 뜨는 일이 없습니다.

Few people use all four. Untick a provider in **설정 → 표시 항목** (Settings → Visible items) and it disappears from the bar — and is **not fetched at all**, so a provider you never signed into cannot sit there as an error.

- Antigravity는 기본적으로 꺼져 있습니다 / Antigravity is off by default.
- 껐다 켜도 기록은 지워지지 않습니다. 다시 켜면 마지막 값부터 보여줍니다 / Toggling does not erase history; a re-enabled provider resumes from its last reading.
- Claude 하나만 쓴다면 나머지 셋을 끄면 됩니다. 그러면 메뉴바는 `C 75%` 한 칸만 차지합니다 / Using only Claude? Turn off the other three and the bar is just `C 75%`.

---

## Gemini: 이미 로그인된 Chrome 세션 사용 / Use the Chrome session you already have

Gemini는 로컬에서 읽을 인증 파일이 없습니다. 그래서 별도 브라우저 로그인 대신 **Gemini 전용 Chrome 확장**이 기존 프로필에서 사용량 페이지를 읽고, Chrome Native Messaging으로 숫자만 앱에 넘깁니다.

Gemini has no local credential to read, so instead of a second browser login this project ships a **Gemini-only Chrome extension** that reads the usage page in your existing profile and hands just the numbers to the app over Chrome Native Messaging.

```sh
./install-chrome-bridge.sh   # 최초 빌드 후 1회 / once, after the first build
```

이 스크립트가 할 수 있는 건 전부 합니다 — 이 맥에 있는 **모든 크로미움 계열 브라우저**(Chrome·Brave·Edge·Arc·Vivaldi·Chromium)에 로컬 호스트를 등록하고, 확장 폴더 경로를 **클립보드에 복사**하고, 확장 관리 화면과 Finder를 열어줍니다. 그리고 연결이 실제로 들어올 때까지 기다렸다가 **확인된 수치를 보여줍니다.**

The script does everything that can be automated: it registers the local host for **every Chromium-family browser** on the Mac, copies the extension folder path to your **clipboard**, opens the extensions page and the folder, then waits and confirms the connection with real numbers.

마지막 세 번의 클릭은 브라우저가 직접 승인해야 합니다. 웹 스토어에 올리지 않은 확장을 스크립트가 프로필에 설치하는 길은 Chrome이 보안상 막아두었습니다.

The last three clicks must be yours — Chrome deliberately offers no way for a script to load an unpacked extension into your profile.

1. 오른쪽 위 **개발자 모드**를 켭니다 / turn on **Developer mode** (top right)
2. **압축해제된 확장 프로그램을 로드합니다** / click **Load unpacked**
3. 파일 선택창에서 **⌘⇧G → 붙여넣기 → Enter** (경로는 이미 클립보드에 있습니다) / press **⌘⇧G**, paste, Enter — the path is already on your clipboard

성공하면 이렇게 나옵니다 / On success:

```
✅ 연결 확인 / connected · you@example.com · 5시간 79% 남음 · 주간 93% 남음
```

언제든 상태를 다시 점검할 수 있습니다 / Re-check the setup any time:

```sh
./install-chrome-bridge.sh --check
```

브라우저별 등록 상태, 확장 ID 일치 여부, 마지막으로 수치를 받은 시각을 한 번에 보여주고 무엇을 고쳐야 하는지 알려줍니다.

It reports per-browser registration, extension-ID match, and when figures last arrived — with the fix for whatever is wrong.

앱의 **설정 → Gemini 웹 → Chrome 연결…** 버튼도 확장 관리 화면과 폴더를 열어줍니다.

In the app, **설정 → Gemini 웹 → Chrome 연결…** also opens the extensions page and the folder.

**구글 계정이 여러 개라면** 팝업의 계정 칸에 주소를 입력해 하나로 고정하세요. 비워두면 현재 프로필에 로그인된 계정을 그대로 씁니다.

**Multiple Google accounts?** Type one address in the popup's account field to pin it, or leave it empty to use whichever account the profile is signed in to.

소스 폴더와 앱 번들 안의 복사본 중 **하나만** 설치하세요. 확장 ID는 둘 다 같습니다.

Install either the source folder or the copy inside the app bundle, not both; the extension ID is the same.

동작 방식 / How it behaves:

- Chrome이 실행 중이면 5분마다 비활성 사용량 탭을 열어 읽고 닫습니다. 사용자가 직접 선택한 탭은 닫지 않습니다. <br> Opens a background usage tab every 5 minutes and closes it; a tab you selected yourself is never closed.
- 쿠키·비밀번호·토큰은 읽거나 복사하지 않습니다. 페이지에 표시된 계정과 퍼센트만 전달됩니다. <br> Cookies, passwords and tokens are never read or copied.
- 페이지에 렌더링된 계정을 확인할 수 있을 때만 수치를 채택합니다. 다른 계정의 수치나 못 읽은 페이지는 `0%`가 아니라 오류로 표시됩니다. <br> Numbers are accepted only when the account on the page can be verified; anything else surfaces as an error, never as `0%`.
- Chrome이 꺼져 있으면 마지막 성공값과 경과 시간을 보여줍니다. <br> With Chrome closed, the last good value is shown with its age.
- 퍼센트를 읽으려면 페이지가 한국어 또는 영어로 표시되어야 합니다. <br> The page must render in Korean or English to be parsed.

확장은 `gemini.google.com`에만 접근하고, 로컬 호스트는 아래 확장 ID의 요청만 받습니다.

The extension reaches `gemini.google.com` only, and the native host accepts this one extension ID:

```
edmmoiejceaokbohcdedkehoabkgkole
```

이 ID는 `manifest.json`의 공개키로 고정됩니다 — 공개 값이라 누가 설치해도 ID가 같습니다. 서명용 개인키는 이 저장소에 없고, 확장은 Chrome 웹 스토어에 게시되지 않았습니다.

The ID is pinned by the public key in `manifest.json` — a public value, so the ID is stable for everyone. The private key is not in this repository and the extension is not on the Web Store.

설치 스크립트가 만드는 파일은 하나뿐입니다 / The install script writes exactly one file:

```
~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.local.ai_usage_bar.gemini.json
```

전부 되돌리려면 Chrome에서 확장을 삭제하고 이 파일을 지우면 됩니다.

To undo everything: remove the extension in Chrome and delete that file.

---

## 설정 / Settings

메뉴바 아이콘 → **설정…** (`⌘,`)

| 항목 · Setting | 의미 · Meaning |
|---|---|
| 갱신 주기 | 분 단위 갱신 간격 (1–120, 기본 5) / refresh interval in minutes |
| 표시 항목 | 메뉴바에 표시하고 조회할 서비스 / which providers are shown and fetched |
| agy 경로 | `agy` 자동 탐색 실패 시 지정 / path to `agy` if not auto-detected |
| Gemini 웹 | Chrome 확장 설치 화면 열기 / opens the extension setup |
| 로그인 시 자동 실행 | LaunchAgent로 로그인 시 실행 / launch at login |

경고·위험 색상 임계값은 각각 남은 20%, 5%가 기본입니다. / Warning and danger thresholds default to 20% and 5% remaining.

---

## 개인정보 / Privacy

- 아무 데로도 전송하지 않습니다. 모든 요청은 이미 계정이 있는 서비스로만 갑니다. <br> Nothing is sent anywhere; every request goes to a provider you already have an account with.
- 분석·텔레메트리·서버·외부 의존성이 없습니다. <br> No analytics, telemetry, server or third-party dependency.
- 인증 정보는 읽기만 합니다. 토큰은 메모리에서 해당 서비스의 `Authorization` 헤더로만 쓰이고 디스크에 저장되지 않습니다. <br> Credentials are read, never written; tokens live in memory only and are never persisted.
- 캐시는 `~/Library/Application Support/AIUsageBar/`에 `0600` 권한으로 저장되며, 퍼센트·라벨·시각만 담깁니다. <br> Cached state holds only percentages, labels and timestamps.

---

## 문제 해결 / Troubleshooting

**Gemini 관련 문제는 먼저 이것부터** / For anything Gemini-related, start here:

```sh
./install-chrome-bridge.sh --check
```

| 증상 · Symptom | 해결 · Fix |
|---|---|
| `설정에서 Gemini 크롬 연결을 완료하세요` | `./install-chrome-bridge.sh` 실행 후 확장 로드 / run the script, then load the extension |
| 팝업에 `메뉴바 앱 연결이 필요합니다` | 빌드 후 `./install-chrome-bridge.sh` 재실행 / re-run it after a build |
| 앱을 다른 폴더로 옮긴 뒤 안 됨 | 등록 파일이 옛 경로를 가리킵니다. 설치를 다시 실행하세요 / re-run the installer |
| Chrome 말고 Brave·Arc 등을 씀 | 설치 스크립트가 전부 등록합니다. 빌드 후 한 번 실행하세요 / the installer covers them all |
| Gemini가 옛날 값에서 멈춤 | Chrome이 켜져 있어야 합니다. 팝업에서 지금 갱신 / Chrome must be running |
| 확장을 고쳤는데 반영이 안 됨 | `chrome://extensions`에서 새로고침(↻) / press reload on the extension card |
| 다시 빌드한 뒤 Claude 오류 | macOS가 키체인 접근을 다시 묻습니다. 한 번 허용 / allow Keychain access once more |
| 안 쓰는 서비스가 오류로 뜸 | 설정 → 표시 항목에서 끄세요 / untick it in Settings |

---

## 개발 / Development

```sh
./build.sh test                                   # Swift 단위 테스트 / Swift unit tests
node --test ChromeExtension/tests.cjs             # 확장 파서·워커 테스트 / extension tests
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once   # 실제 조회 1회 출력 / one real fetch
```

두 테스트 모두 네트워크나 로그인 없이 실행됩니다. / Both suites run without network access or a signed-in account.

**쓰는 모델을 추가하고 싶다면** — 어떤 파일을 어떤 순서로 건드려야 하는지, 그리고 AI와 함께 작업할 때 무엇을 먼저 주면 되는지 [CONTRIBUTING.md](CONTRIBUTING.md)에 정리해 두었습니다.

**Want to add a provider you use?** [CONTRIBUTING.md](CONTRIBUTING.md) walks through which files to touch in what order, and how to work through it with an AI assistant.

구조 / Layout:

- `Sources/Sources.swift`, `Parsing.swift` — 서비스별 조회와 응답 파싱 / fetching and parsing
- `Sources/GeminiChromeBridge.swift` — Native Messaging 호스트, 메시지 검증, 신선도 검사 / the bridge
- `Sources/Coordinator.swift` — 스케줄링, 서비스별 오류 격리 / scheduling and error isolation
- `Sources/MenuBarController.swift`, `BarFormatter.swift` — 메뉴바 문자열과 상세 메뉴 / the bar and dropdown
- `ChromeExtension/` — 페이지 관찰, 계정 확인, 백그라운드 조회, 팝업 / the extension
- `Tests/main.swift` — Swift 파싱과 연동 메시지 픽스처 / fixtures

---

## 라이선스 / License

MIT — [LICENSE](LICENSE)
