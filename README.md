# AI Usage Bar

**AI 사용량, 확인하러 다니지 말고 메뉴바에서 보세요.**

Claude · Codex · Gemini 웹 · Antigravity의 **남은 사용량**을 Mac 메뉴바 한 줄에 모아 보여주는 무료 오픈소스 앱입니다.

**한국어** · [English](README.en.md)

[**↓ Mac용 다운로드 — v1.1.1**](https://github.com/hong-minji/ai-usage-bar/releases/download/v1.1.1/AIUsageBar-1.1.1-universal.zip) · [릴리스 / 최신 버전](https://github.com/hong-minji/ai-usage-bar/releases) · [문제 신고](https://github.com/hong-minji/ai-usage-bar/issues)

macOS 13 이상 대상 · Apple Silicon / Intel 통합 파일 · 앱 UI 한국어 · MIT 라이선스

> 초기 공개 버전입니다. Apple Developer ID 서명·공증은 아직 없어 첫 실행 때 macOS가 차단할 수 있습니다. 아래 [처음 실행할 때](#처음-실행할-때)를 먼저 읽어주세요. Windows·Linux에서는 실행되지 않습니다.

<img src="docs/screenshot.png" width="440" alt="AI Usage Bar 메뉴바와 서비스별 남은 사용량 상세 메뉴">

```text
C 75% · G 81% · Ge 93% · Ag 0%
```

위 숫자는 표시 예시입니다. 모든 퍼센트는 **사용한 양이 아니라 남은 양**입니다. 5시간·주간 한도가 함께 있으면 메뉴바에는 가장 적게 남은 한도를, 펼친 메뉴에는 세부 한도와 제공되는 리셋 시각을 보여줍니다.

## 다운로드하고 시작하기

1. 위 **Mac용 다운로드**를 눌러 `AIUsageBar-1.1.1-universal.zip`을 받습니다. Apple Silicon·Intel 중 고를 필요가 없습니다.
2. ZIP을 더블클릭해 압축을 풉니다. `AIUsageBar.app`, `START-HERE.txt`, `LICENSE.txt`가 들어 있습니다.
3. **앱을 응용 프로그램 폴더로 옮긴 뒤** 실행합니다. Gemini 연결 전에 설치 위치를 정해주세요.
4. 화면 위쪽 메뉴바에서 앱을 열고 **설정… → 표시 항목**에서 쓰는 서비스만 남겨둡니다. Dock 아이콘은 없습니다.
5. 아래 표의 로그인 조건을 확인합니다. Gemini를 쓴다면 [Chrome 연결](#gemini-웹-연결)을 한 번 진행합니다.

다운로드한 앱은 Xcode·Homebrew·Node.js 없이 실행할 수 있습니다. 각 서비스의 로그인 도구나 Chrome은 해당 서비스를 연결할 때 필요합니다. GitHub의 **Code → Download ZIP**과 릴리스의 **Source code**는 개발용 소스이며, 실행할 앱은 위 링크의 `AIUsageBar-…-universal.zip`입니다.

### 처음 실행할 때

현재 앱은 임시 서명(ad-hoc)만 되어 있습니다. 이 저장소에서 받은 파일이고 출처를 신뢰한다면, 한 번 실행을 시도한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**에서 허용할 수 있습니다. 자세한 절차는 [Apple의 공식 안내](https://support.apple.com/en-us/102445)를 참고하세요. 회사에서 관리하는 Mac에서는 허용이 제한될 수 있습니다.

Claude 연결 시 macOS가 키체인 접근을 요청할 수 있습니다. 앱이 Claude Code의 기존 로그인 정보를 읽기 위한 요청이며, 토큰을 갱신하거나 변경하지 않습니다.

## 어떤 서비스를 연결할 수 있나요?

| 메뉴바 | 표시하는 사용량 | 필요한 준비 |
|---|---|---|
| `C` | Claude 5시간·주간 한도 | 이 Mac에서 Claude Code에 로그인. macOS 키체인에 저장된 인증 정보 사용 |
| `G` | **Codex** 한도 | 이 Mac의 `~/.codex/auth.json`에 저장된 ChatGPT 계정 로그인 정보 |
| `Ge` | **Gemini 웹** 한도 | Google Chrome에서 Gemini 로그인 + 앱에 포함된 확장 설치 |
| `Ag` | Antigravity 코딩 할당량 | `agy` CLI 설치·로그인. 경로를 못 찾으면 설정에서 지정 |

**`G`는 일반 ChatGPT 채팅 한도가 아닙니다.** Gemini 웹과 Antigravity도 별도의 할당량입니다. Claude·Codex는 웹사이트 로그인만으로 연결되지 않으며, API 키 사용량을 측정하는 앱도 아닙니다.

- 필요한 서비스만 켜세요. 숨긴 서비스는 조회하지 않습니다. Antigravity는 기본적으로 꺼져 있습니다.
- 기본 5분마다, 메뉴를 열 때 갱신합니다. 앱 갱신 간격은 설정에서 1–120분으로 바꿀 수 있습니다.
- 조회 실패 시 마지막 성공값과 경과 시간, 오류를 표시합니다. 이전 값도 없으면 사용량을 알 수 없다고 표시하며, 실패를 `0%`로 바꾸지 않습니다.
- 모델에 프롬프트를 보내지 않습니다. 사용량 조회, 사용량 페이지 읽기, `agy /quota`를 이용합니다.

## Gemini 웹 연결

Google Chrome이 필요합니다. 확장은 앱 안에 포함되어 있으며 Chrome 웹 스토어에는 게시되지 않았습니다.

1. 설치한 앱에서 **설정… → Gemini 웹 → Chrome 연결…**을 누릅니다. 현재 앱 위치로 연결을 등록하고 확장 폴더 경로를 클립보드에 복사합니다.
2. Gemini에 로그인된 Chrome 프로필에서 `chrome://extensions/`를 엽니다.
3. 오른쪽 위 **개발자 모드**를 켜고 **압축해제된 확장 프로그램을 로드합니다**를 누릅니다.
4. 폴더 선택창에서 **⌘⇧G → 붙여넣기 → Enter**를 누른 뒤 해당 폴더를 선택합니다.
5. Chrome 도구 모음의 확장 메뉴에서 **AI 사용량 · Gemini 연결**을 열고 **지금 갱신**을 누릅니다.

Google 계정이 여러 개라면 확장 팝업의 계정 칸에 사용할 이메일을 지정할 수 있습니다. 비워두면 현재 Chrome 프로필의 계정을 사용합니다. 페이지에서 계정을 확인할 수 없거나 지정한 계정과 다르면 수치를 채택하지 않습니다.

Chrome 실행 중 5분마다 비활성 사용량 탭을 열어 읽고 닫습니다. 사용자가 직접 선택한 탭은 자동으로 닫지 않습니다. 사용량 페이지는 **한국어 또는 영어**여야 합니다. Chrome이 꺼져 있거나 페이지를 읽을 수 없으면 마지막 값이 오래된 값으로 표시됩니다.

앱이 안내한 확장 하나만 설치하고 앱의 위치를 유지하세요. 앱을 옮겼다면 **Chrome 연결…**을 다시 누르고 새 위치의 확장을 로드해야 합니다. 앱 버튼은 Google Chrome용입니다. 다른 Chromium 브라우저를 위한 개발용 도구는 [기여 가이드](CONTRIBUTING.md)를 참고하세요.

## 업데이트와 삭제

**업데이트:** 메뉴바에서 기존 앱을 종료 → [릴리스](https://github.com/hong-minji/ai-usage-bar/releases)에서 새 ZIP 다운로드 → 같은 응용 프로그램 위치의 앱 교체 → 다시 실행합니다. 자동 업데이트는 없습니다. Gemini 확장은 `chrome://extensions/`에서 새로고침(↻)하세요. 앱 위치가 바뀌었다면 Chrome 연결을 다시 하고 로그인 시 자동 실행도 껐다 켜세요.

**삭제:** 설정에서 **로그인 시 자동 실행**을 끄고 종료한 뒤 앱을 휴지통으로 옮깁니다. Gemini를 연결했다면 Chrome 확장과 아래 등록 파일도 삭제하세요. 기록을 지우려면 아래 캐시 폴더를, 설정까지 지우려면 환경설정 파일도 삭제합니다.

```text
연결 등록: ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.local.ai_usage_bar.gemini.json
사용량 캐시: ~/Library/Application Support/AIUsageBar/
앱 설정: ~/Library/Preferences/com.local.ai-usage-bar.plist
자동 실행: ~/Library/LaunchAgents/com.local.ai-usage-bar.plist
```

자동 실행 파일은 설정에서 기능을 끄면 삭제됩니다. 개발용 설치 스크립트를 사용했다면 해당 스크립트가 등록한 다른 브라우저의 Native Messaging 파일도 삭제하세요.

## 개인정보와 접근 범위

- 개발자 서버, 분석 도구, 광고, 텔레메트리가 없습니다. 사용량 요청은 해당 서비스 제공자에게 갑니다.
- Claude·Codex 인증 정보는 읽기만 하며, 앱이 토큰을 갱신하거나 별도 파일에 저장하지 않습니다.
- Gemini 확장은 `gemini.google.com`의 사용량 페이지에서 계정과 수치를 읽습니다. 쿠키·비밀번호·대화 내용을 복사하지 않습니다.
- 로컬 캐시에는 사용량, 라벨, 플랜, 시각이 저장됩니다. Gemini 연결 캐시에는 확인한 이메일, 페이지 URL, 연결 상태도 포함되며 파일 권한은 소유자 전용(`0600`)으로 설정합니다.
- 확장 팝업에 지정한 이메일과 연결 상태는 Chrome 확장 로컬 저장소에도 남습니다. 확장을 삭제하면 해당 저장소도 제거됩니다.

서비스 제공자가 만든 공식 앱이 아닙니다. 서비스의 인증 방식·응답·웹 페이지가 바뀌면 연결이나 수치 읽기가 중단될 수 있습니다.

## 문제가 생겼나요?

| 증상 | 확인할 것 |
|---|---|
| 앱을 열었는데 창이 없음 | 화면 위쪽 메뉴바를 확인하세요. Dock 아이콘과 일반 앱 창은 없습니다. |
| macOS에서 실행 차단 | 위의 첫 실행 안내와 Apple 공식 안내를 확인하세요. |
| Claude 로그인 정보 없음 | Claude Code 로그인과 키체인 접근 허용을 확인하세요. |
| Codex 로그인 정보 없음 | 이 Mac의 `~/.codex/auth.json`에 ChatGPT 로그인 정보가 필요합니다. |
| Gemini에서 메뉴바 앱 연결 필요 | 현재 설치된 앱의 **Chrome 연결…**을 다시 누르고 확장을 새로고침하세요. |
| Gemini가 오래된 값만 표시 | Chrome 로그인·실행 여부와 확장 팝업의 **지금 갱신** 결과를 확인하세요. |
| 안 쓰는 서비스에서 오류 | **설정… → 표시 항목**에서 해당 서비스를 끄세요. |
| Antigravity 조회 실패 | `agy` 로그인과 실행 파일 경로를 확인하세요. |

해결되지 않으면 [이슈](https://github.com/hong-minji/ai-usage-bar/issues/new/choose)에 앱 버전, macOS 버전, Mac 종류, 문제 서비스와 재현 절차를 알려주세요. 이메일·토큰·인증 파일·개인 대화는 올리지 마세요.

## 개발 및 검증

소스로 빌드하려면 Xcode Command Line Tools가 필요합니다. `xcode-select --install`로 설치를 완료한 뒤 실행하세요.

```sh
git clone https://github.com/hong-minji/ai-usage-bar.git
cd ai-usage-bar
./build.sh
open build/AIUsageBar.app
```

```sh
./build.sh test                       # Swift 검사
node --test ChromeExtension/tests.cjs # 확장 검사 (Node.js 필요)
./package.sh                         # 두 아키텍처 빌드 + ZIP + SHA-256
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once # 실제 연결 1회 조회
```

`v1.1.1`에서 Swift 검사 122개와 확장 테스트 21개, 통합 빌드, ZIP 압축 해제·서명 검증을 통과했습니다. 개발 Mac에서는 네 서비스 조회를 확인했습니다. **macOS 13 및 모든 Mac 기종에서의 실제 설치·실행을 검증한 것은 아닙니다.**

릴리스의 ZIP과 `.sha256` 파일을 같은 폴더에 저장하면 터미널에서 파일 무결성을 확인할 수 있습니다.

```sh
shasum -a 256 -c AIUsageBar-1.1.1-universal.zip.sha256
```

[개발·기여 가이드](CONTRIBUTING.md) · [Gemini 확장](ChromeExtension/) · [릴리스 노트](docs/releases/v1.1.1.md)

## 라이선스

[MIT](LICENSE). 무료로 사용·수정·재배포할 수 있습니다. 각 서비스의 계정·구독은 별도로 필요합니다. Anthropic, OpenAI, Google과 제휴하거나 이들의 승인을 받은 프로젝트가 아닙니다.
