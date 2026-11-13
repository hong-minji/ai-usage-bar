# 기여 가이드 / Contributing

이 문서는 두 가지를 다룹니다 — **내가 쓰는 모델을 추가하는 법**, 그리고 **그 작업을 AI와 함께 하는 법**.

This covers two things: **adding a provider you use**, and **doing that work with an AI assistant**.

---

## 0. 먼저 알아야 할 규칙 / The rules that matter

코드를 고치기 전에 이것부터 보세요. 이 프로젝트의 거의 모든 설계 결정이 여기서 나옵니다.

Read this first — nearly every design decision in the project follows from it.

| 규칙 · Rule | 이유 · Why |
|---|---|
| **모르는 값을 `0%`로 표시하지 않는다** <br> Never render an unknown value as `0%` | `0%`와 "모름"은 완전히 다른 정보입니다. 조회에 실패하면 마지막 성공값 + 경과 시간을 보여주고, 그것도 없으면 오류를 보여줍니다. <br> Zero and unknown are different facts. Fall back to the last good reading, or show the error. |
| **인증 정보는 읽기만 한다** <br> Credentials are read, never written | 토큰을 갱신하면 그 토큰의 원래 주인(Claude Code, Codex)의 세션이 깨집니다. <br> Refreshing a token would rotate it out from under the tool that owns it. |
| **토큰은 메모리에서 끝낸다** <br> Tokens stay in memory | 디스크·로그·오류 메시지 어디에도 남기지 않습니다. `FetchError`가 고정 문자열과 상태 코드만 담는 이유입니다. <br> Never to disk, logs or error strings. |
| **조회가 사용량을 소모하면 안 된다** <br> Polling must not consume quota | 5분마다 도는 코드입니다. 추론 엔드포인트를 부르면 측정 대상을 측정 행위가 깎습니다. <br> It runs every 5 minutes; an inference call would eat the thing being measured. |
| **`usedPercent`로 저장하고 `remainingPercent`로 표시한다** <br> Store used, display remaining | 서비스마다 '쓴 양'과 '남은 양' 중 아무거나 주기 때문에 저장 단계에서 하나로 정규화합니다. <br> Upstreams report either one; normalise at the parse boundary. |
| **테스트는 네트워크 없이 돈다** <br> Tests run offline | 실제 응답을 픽스처로 박아 둡니다. 로그인 없이도 전부 통과해야 합니다. <br> Real responses are pinned as fixtures. |
| **`TESTABLE` 파일에 AppKit을 넣지 않는다** <br> No AppKit in `TESTABLE` files | `build.sh`의 `TESTABLE` 목록은 테스트 바이너리로 링크됩니다. AppKit이 들어가면 빌드가 깨집니다. <br> Those files link into the test binary. |

---

## 1. 쓰는 모델 추가하기 / Adding a provider

### 먼저: 실제 응답을 확보하세요 / First, get a real response

**이 단계를 건너뛰지 마세요.** 응답 스키마를 추측해서 파서를 쓰면 반드시 틀립니다. 이미 연결된 서비스는 이렇게 볼 수 있습니다:

**Do not skip this.** A parser written against a guessed schema will be wrong. For an already-wired provider:

```sh
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once
```

새 서비스라면 해당 CLI의 사용량 명령을 직접 돌리거나, 브라우저 개발자 도구의 Network 탭에서 사용량 페이지가 호출하는 엔드포인트를 찾아 응답 JSON을 복사해 두세요.

For a new one, run its CLI's usage command, or find the endpoint its usage page calls in the browser's Network tab, and save the JSON.

### 어느 패턴에 해당하나 / Pick the pattern it fits

| 인증이 어디 있나 | 참고할 기존 코드 |
|---|---|
| 키체인 또는 로컬 파일 + HTTP API | `ClaudeSource` (키체인), `ChatGPTSource` (`~/.codex/auth.json`) |
| 로컬 CLI가 숫자를 뱉음 | `AgySource` — 프로세스 실행, 파이프 드레인, 타임아웃 |
| 브라우저 로그인뿐, 로컬에 아무것도 없음 | `ChromeExtension/` + `GeminiChromeBridge` — 가장 손이 많이 갑니다 |

### 순서대로 / In order

1. **`Sources/Model.swift`** — `ProviderID`에 `case`를 추가합니다. 그러면 `shortLabel`, `brandHex`, `displayName` 세 `switch`가 컴파일 에러를 냅니다. 채우세요. Swift의 exhaustive switch 덕분에 **빠뜨린 곳은 컴파일러가 전부 알려줍니다** (`MenuBarController`의 로그인 안내 문구 포함).

   Add the `case`; the compiler then points at every `switch` that must handle it.

2. **`Sources/Parsing.swift`** — `parseXUsage(_ data: Data, now: Date) throws -> ProviderReading`를 추가합니다. 순수 함수여야 합니다. 네트워크도, 전역 상태도, 현재 시각 읽기도 없이 `now`를 받습니다.

   Add a pure parsing function. No network, no globals, and take `now` as a parameter.

3. **`Tests/main.swift`** — 1단계에서 받아 둔 실제 응답을 픽스처로 넣고 **테스트를 먼저** 씁니다. 정상 응답 하나, 그리고 깨진 입력들(빈 값, 음수, 100 초과, 필드 누락)이 추측 대신 `throw` 하는지.

   Pin the real response as a fixture and write the test **first** — one good case, plus malformed inputs that must throw rather than guess.

4. **`Sources/Sources.swift`** — `enum XSource`에 `fetch()`를 추가합니다. 자격증명 읽기 → 요청 → 2단계의 파서 호출. 자격증명이 없으면 `FetchError.notSignedIn`.

5. **`Sources/Coordinator.swift`** — `fetchX(skip:)`를 추가하고 `refresh()`의 `async let` 묶음과 `next[...]` 대입에 연결합니다. 실패 경로는 반드시 `degrade(...)`를 거쳐 마지막 성공값으로 떨어져야 합니다.

6. **`Sources/MenuBarController.swift`** — `hintItem(for:)`에 로그인 안내 문구 한 줄.

7. **`Sources/Prefs.swift`** — 소수만 쓰는 서비스라면 `hiddenProviders` 기본값에 넣어 기본 숨김으로 둡니다.

### 확인 / Verify

```sh
./build.sh test                                            # 픽스처 테스트 / fixtures
./build.sh                                                 # 전체 빌드 / full build
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once     # 실제 연결 확인 / live check
```

`--once` 출력에 새 줄이 올바른 퍼센트로 뜨면 끝입니다. 테스트 숫자를 실제 사용량 캐시에 쓰지 마세요.

---

## 2. AI와 함께 개발하기 / Working on this with an AI

Claude Code 같은 도구로 작업한다면, 아래 순서가 가장 적게 헤맵니다.

### 먼저 쥐여줄 것 / What to hand it up front

1. **이 문서의 0번 규칙 표.** 그대로 붙여넣으세요. 이걸 안 주면 AI는 거의 항상 "실패 시 0% 반환"을 짭니다.
2. **1단계에서 받아 둔 실제 응답 JSON.** 가장 중요합니다. 이게 없으면 AI는 그럴듯한 스키마를 지어내고, 테스트까지 그 가짜 스키마에 맞춰 통과시킵니다.
3. **가장 닮은 기존 프로바이더 파일.** "Claude와 같은 방식(키체인 + HTTP)으로 X를 추가해줘"가 "X를 추가해줘"보다 훨씬 정확한 결과를 냅니다.

Paste the rules table, the **real** response JSON, and the closest existing provider as the pattern to copy. Without the real JSON an assistant will invent a plausible schema and then write tests that pass against the invention.

### 프롬프트 예시 / A prompt that works

```
ai-usage-bar에 <서비스> 사용량을 추가하려고 해.

인증: <어디에 있는지 — 키체인 / ~/.config/... / CLI>
엔드포인트: <URL 또는 CLI 명령>
실제 응답 (직접 받은 것):
<JSON 붙여넣기>

CONTRIBUTING.md의 규칙 표를 먼저 읽고, ClaudeSource와 같은 패턴으로 가줘.
Tests/main.swift에 이 응답을 픽스처로 박는 테스트를 먼저 쓰고,
그 다음 구현해줘. 깨진 입력은 추측하지 말고 throw 해야 해.
```

### 검토할 때 집중해서 볼 곳 / What to check in the diff

AI가 이 저장소에서 자주 틀리는 지점입니다:

Common mistakes to look for:

- **실패를 `0%`로 둔갑시키기** — `catch`에서 `usedPercent: 100`이나 빈 `windows`를 반환하지 않는지. 반드시 `throw` 하거나 `degrade(...)`로 가야 합니다.
- **`usedPercent` / `remainingPercent` 뒤집기** — 서비스가 "남은 양"을 주면 `100 - value`로 저장해야 합니다. 테스트 픽스처의 숫자와 기대값을 직접 계산해 보세요.
- **`TESTABLE` 파일에 `import AppKit`** — `./build.sh test`가 바로 깨지니 금방 드러납니다.
- **토큰이 로그·오류 메시지로 새기** — `print`나 `FetchError.toolFailed("...\(response)")` 형태가 있는지.
- **검증 없이 신뢰하기** — 특히 브라우저에서 오는 값은 범위(0–100)·형식·신선도를 전부 확인해야 합니다. `GeminiChromeBridge.validateFields`가 기준입니다.
- **테스트가 구현을 따라간 경우** — 구현을 고친 뒤 테스트를 거기에 맞춰 수정했다면, 그 테스트는 이제 아무것도 검증하지 않습니다.

### 끝내기 전에 / Before you call it done

```sh
./build.sh test && node --test ChromeExtension/tests.cjs
```

둘 다 통과하고, `--once`가 실제 숫자를 뱉는 것까지 **직접 눈으로** 확인하세요. "통과할 것"과 "통과했다"는 다릅니다.

Run both suites and look at `--once` output yourself. "Should pass" and "passed" are different claims.

---

## 3. 그 밖의 기여 / Other contributions

- **파서가 깨졌을 때** — 서비스가 응답 형식이나 페이지 문구를 바꾸면 파싱이 실패합니다. 이슈에 **실제 응답(토큰은 지우고)** 이나 사용량 페이지의 해당 문구를 붙여주시면 가장 빠릅니다.
- **다른 언어의 Gemini 페이지** — 현재 파서는 한국어·영어 문구만 인식합니다. `ChromeExtension/parser.js`의 `parseUsage`와 `labelFor`에 패턴을 추가하고 `tests.cjs`에 케이스를 넣어주세요.
- **버그** — macOS 버전, 어느 프로바이더인지, `--once` 출력(계정 이메일은 지우고)을 함께 적어주세요.

If a provider changes its response shape, paste the **real** response (with tokens removed) into the issue — that is the one thing that makes the fix quick.


## 4. 배포 준비 / Preparing a release

`./package.sh`는 Swift 검사, 확장 테스트, macOS 13을 대상으로 한 arm64/x86_64 빌드, 임시 코드서명 검증을 수행합니다. 결과물은 `build/AIUsageBar-버전-universal.zip`과 `.sha256`입니다. ZIP에는 앱, 한·영 `START-HERE.txt`, `LICENSE.txt`가 들어 있습니다. 버전은 `build.sh`에서 관리하며 릴리스 시 README 다운로드 링크와 `docs/START-HERE.txt`의 버전도 갱신하세요.

`./package.sh` runs the Swift checks and extension tests, builds both Mac architectures targeting macOS 13, and verifies the ad-hoc signature. It produces a ZIP and checksum in `build/`. The ZIP includes the app, bilingual `START-HERE.txt` and `LICENSE.txt`. Versions are defined in `build.sh`; update the README download links and the version in `docs/START-HERE.txt` for each release.

공개 릴리스 전 확인:

- 새 macOS 사용자 계정에서 설치 안내대로 앱을 설치하고 메뉴바와 설정 창을 확인합니다.
- 사용하는 서비스마다 실제 로그인으로 수치를 확인합니다. 픽스처 테스트 통과만으로 서버나 웹 페이지와의 호환성을 보장할 수는 없습니다.
- Gemini는 앱의 Chrome 연결 버튼, 확장 수동 로드, 팝업 새로고침, 앱 이동 후 재연결을 확인합니다.
- Apple Silicon과 Intel, 지원하는 최소 macOS에서 실제 실행을 확인합니다. 두 아키텍처의 컴파일 성공과 실행 검증은 별개입니다.
- 다운로드 배포에서 불필요한 보안 경고를 줄이려면 Developer ID 서명과 Apple 공증을 적용합니다. 현재 패키징 스크립트에는 공증이 포함되어 있지 않습니다.
- ZIP과 체크섬을 릴리스에 첨부하고 README의 다운로드 안내를 실제 릴리스 주소로 바꿉니다.

Before publishing, test installation in a fresh macOS account, verify live provider readings and Gemini setup, and test on both architectures and the minimum supported OS. The packaging script does not perform Developer ID signing or notarization. Attach the ZIP and checksum to a release and update the README download instructions when a release is available.


### 개발용 Chrome 연결 / Developer Chrome setup

설치된 앱의 버튼은 Google Chrome에 연결합니다. 소스에서 `build/AIUsageBar.app`을 직접 실행하는 개발자는 `./install-chrome-bridge.sh`로 감지된 Chromium 계열 브라우저 프로필에 연결을 등록할 수 있습니다. `./install-chrome-bridge.sh --check`는 등록 상태를 진단합니다. 이 스크립트는 호스트 경로를 `build/` 앱으로 바꾸므로 일반 다운로드 사용자는 앱의 연결 버튼을 쓰세요. 다른 브라우저의 실제 연결은 별도 검증이 필요합니다.

The installed app button supports Google Chrome. Developers running `build/AIUsageBar.app` can use `./install-chrome-bridge.sh` to register detected Chromium-family browser profiles, and `--check` to diagnose registrations. This points the host at the `build/` app; release users should use the app button. Other browsers require separate live verification.
