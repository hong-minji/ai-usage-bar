# AI Usage Bar

**AI 사용량, 확인하러 다니지 말고 메뉴바에서 보세요.**

Claude · GPT · Gemini · agy를 Mac 메뉴바에 나란히 표시합니다. **Claude·GPT·Gemini는 웹 로그인으로 연결**할 수 있고, 기존 로컬 로그인과 agy CLI도 지원하는 무료 오픈소스 앱입니다.

**한국어** · [English](README.en.md)

[**↓ Mac용 다운로드 — v1.2.1**](https://github.com/hong-minji/ai-usage-bar/releases/download/v1.2.1/AIUsageBar-1.2.1-universal.zip) · [릴리스 / 최신 버전](https://github.com/hong-minji/ai-usage-bar/releases) · [문제 신고](https://github.com/hong-minji/ai-usage-bar/issues)

macOS 13 이상 대상 · Apple Silicon / Intel 통합 파일 · 앱 UI 한국어 · MIT 라이선스

> 초기 공개 버전입니다. Apple Developer ID 서명·공증은 아직 없어 첫 실행 때 macOS가 차단할 수 있습니다. 아래 [처음 실행할 때](#처음-실행할-때)를 먼저 읽어주세요. Windows·Linux에서는 실행되지 않습니다.

![Claude · GPT · Gemini · agy의 남은 사용량을 보여주는 Mac 메뉴바 앱 화면](docs/screenshot.png)

**실제 앱 화면이며, 수치는 사용 시점에 따라 달라집니다. GPT는 ChatGPT 설정 → 사용량의 플랜 한도를 표시**합니다. 별도의 빈 GPT 채팅 항목은 없습니다. 펼친 메뉴의 ‘ChatGPT 플랜 사용량 확인…’에서 수치의 적용 범위를 확인할 수 있습니다. 모든 퍼센트는 **사용한 양이 아니라 남은 양**입니다. 5시간·주간 한도가 함께 있으면 메뉴바에는 가장 적게 남은 한도를, 펼친 메뉴에는 세부 한도와 제공되는 리셋 시각을 보여줍니다.

## AI와 함께 설치하기 — 안내받기와 설치 맡기기

**일반 웹 채팅에서도 설치 방법을 물어볼 수 있습니다. 다만 내 Mac에 직접 설치하려면, 이 Mac에서 파일을 다루고 명령을 실행할 수 있는 AI 환경과 권한이 필요합니다. 데스크톱 앱에 입력한다는 것만으로 자동 설치되는 것은 아닙니다.**

| AI를 사용하는 환경 | 가능한 도움 |
|---|---|
| 내 Mac 연결이 없는 일반 ChatGPT·Claude 웹 채팅 / 데스크톱 채팅 | README를 읽고 단계별 안내. 다운로드·앱 이동·실행은 사용자가 진행 |
| 내 Mac에서 실행하는 Codex·Claude Code의 터미널 또는 데스크톱 로컬 작업 세션 | 허용된 범위에서 다운로드·압축 해제·앱 이동 등 설치 작업 수행 가능 |
| Work·Cowork 등 파일 접근이 있는 작업 환경 | 로컬/클라우드 실행 위치와 연결한 도구·폴더 권한에 따라 가능 범위가 다름. 파일 접근만으로 Mac 앱 설치 전체를 보장하지 않음 |

**직접 설치를 맡기려면 ‘이 컴퓨터 / 로컬’에서 실행하는 세션인지 확인하세요.** 클라우드 작업 환경에 설치하는 것은 내 Mac에 설치하는 것과 다릅니다. 기능 이름과 제공 여부는 앱 버전·계정에 따라 달라질 수 있습니다. [Codex 로컬 실행 안내](https://learn.chatgpt.com/docs/environments/modes) · [Claude Code 실행 환경](https://code.claude.com/docs/en/overview) · [Claude Cowork 권한 안내](https://support.claude.com/en/articles/13345190-get-started-with-claude-cowork)

아래 저장소 주소와 요청문을 함께 보내세요. README에 다운로드와 연결 방법이 정리되어 있습니다.

```text
https://github.com/hong-minji/ai-usage-bar

이 앱을 내 Mac에 설치하고 싶어. README를 읽어줘.
먼저 이 대화에서 내 Mac의 파일을 다루고 명령을 실행할 수 있는지 확인해줘.
가능하면 최신 릴리스의 앱 ZIP으로 설치하고 내가 쓰는 AI 서비스만 연결해줘.
직접 작업할 수 없다면 내가 따라 할 다운로드·설치 순서를 한 단계씩 안내해줘.
로그인, macOS 실행 승인, Chrome 확장 설치 중 내가 해야 하는 단계는 알려줘.
마지막에 메뉴바 표시와 사용량 갱신을 실제로 확인할 수 있는 방법을 안내해줘.
```

로그인이나 macOS 보안 승인 등은 사용자가 직접 진행해야 할 수 있습니다. 비밀번호나 인증 토큰을 채팅에 붙여 넣을 필요는 없습니다. AI 없이도 아래 순서대로 설치할 수 있습니다.

## 다운로드하고 시작하기

1. 위 **Mac용 다운로드**를 눌러 `AIUsageBar-1.2.1-universal.zip`을 받습니다. Apple Silicon·Intel 중 고를 필요가 없습니다.
2. ZIP을 더블클릭해 압축을 풉니다. `AIUsageBar.app`, `START-HERE.txt`, `LICENSE.txt`가 들어 있습니다.
3. **앱을 응용 프로그램 폴더로 옮긴 뒤** 실행합니다. Chrome 연결 전에 설치 위치를 정해주세요.
4. 화면 위쪽 메뉴바에서 앱을 열고 **설정… → 표시 항목**에서 쓰는 서비스만 남겨둡니다. Dock 아이콘은 없습니다.
5. 아래 표의 로그인 조건을 확인합니다. 웹 로그인으로 사용하려면 [Chrome 연결](#터미널-없이-chrome-웹-연결)을 한 번 진행합니다.

다운로드한 앱은 Xcode·Homebrew·Node.js 없이 실행할 수 있습니다. 각 서비스의 로그인 도구나 Chrome은 해당 서비스를 연결할 때 필요합니다. GitHub의 **Code → Download ZIP**과 릴리스의 **Source code**는 개발용 소스이며, 실행할 앱은 위 링크의 `AIUsageBar-…-universal.zip`입니다.

### 처음 실행할 때

현재 앱은 임시 서명(ad-hoc)만 되어 있습니다. 이 저장소에서 받은 파일이고 출처를 신뢰한다면, 한 번 실행을 시도한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**에서 허용할 수 있습니다. 자세한 절차는 [Apple의 공식 안내](https://support.apple.com/en-us/102445)를 참고하세요. 회사에서 관리하는 Mac에서는 허용이 제한될 수 있습니다.

Claude 연결 시 macOS가 키체인 접근을 요청할 수 있습니다. 앱이 Claude Code의 기존 로그인 정보를 읽기 위한 요청이며, 토큰을 갱신하거나 변경하지 않습니다.

## 어떤 서비스를 연결할 수 있나요?

| 표시 | 측정 대상 | 터미널 없이 연결 | 기존 로컬 연결 |
|---|---|---|---|
| **Claude** | 세션·주간 사용 한도 | Chrome에서 Claude 로그인 + 확장 | Claude Code 로그인 정보 |
| **GPT** | ChatGPT의 플랜 사용 한도 | Chrome에서 ChatGPT 로그인 + 확장 | `~/.codex/auth.json`의 ChatGPT 로그인 정보 |
| **Gemini** | Gemini 웹 사용 한도 | Chrome에서 Gemini 로그인 + 확장 | Chrome 연결 사용 |
| **agy** | Antigravity 코딩 할당량 | 지원하지 않음 | `agy` CLI 설치·로그인 |

Claude·GPT·Gemini를 웹으로 연결하면 터미널용 도구를 따로 설치할 필요가 없습니다. **이미 로컬 도구를 쓴다면 설치뿐 아니라 로그인까지 되어 있어야** 합니다. 이후 터미널 창을 켜 두거나 직접 명령을 반복할 필요는 없습니다. Codex는 CLI 설치 자체보다 해당 Mac의 로그인 파일 유무가 중요합니다.

**GPT 수치의 범위 (2026-11-14 확인):** 현재 Codex와 ChatGPT Work는 사용 한도를 공유합니다. OpenAI는 Plus·Pro·Business의 ChatGPT와 Codex 통합 한도를 **12월부터** 적용한다고 안내하며, Instant 채팅은 차감 대상에서 제외합니다. 따라서 모든 일반 채팅이 이미 이 숫자에 포함된다고 가정하지 않습니다. 이 앱은 사용량 페이지가 제공하는 플랜 한도를 그대로 표시하며 채팅 횟수나 별도 모델 한도를 추정하지 않습니다. [공식 통합 한도 안내](https://help.openai.com/en/articles/20001625-understanding-chatgpt-and-codex-usage-limits) · [현재 Work/Codex 공유 한도](https://learn.chatgpt.com/docs/agent-configuration/speed)

Gemini 웹과 agy도 별도 할당량입니다. API 과금액을 측정하지 않습니다.

- 표시 항목은 설정에서 선택합니다. agy는 기본 숨김이며 CLI를 쓰는 사람만 켜면 됩니다.
- 앱은 기본 5분마다, 메뉴를 열 때 갱신합니다. 간격은 1–120분으로 설정할 수 있습니다.
- 웹 확장은 Chrome 실행 중 5분마다 수치를 확인합니다. 메뉴를 여는 것은 최신 로컬 보고서를 읽는 동작이며, 즉시 웹 재조회하려면 확장 팝업의 ‘지금 갱신’을 누르세요.
- 실패를 `0%`로 표시하지 않습니다. 이전 성공값이 있으면 경과 시간과 오류를 표시합니다.
- 사용량 확인용 요청만 하며 모델에 프롬프트를 보내지 않습니다.

## 터미널 없이 Chrome 웹 연결

확장은 앱에 포함되어 있으며 Chrome 웹 스토어에는 게시되지 않았습니다. 웹 사용량 페이지는 한국어 또는 영어여야 합니다. 사용하는 Chrome 프로필에서 각 서비스에 먼저 로그인하세요.

1. 설치한 앱에서 **설정… → 웹 연결 → Chrome 연결…**을 누릅니다. 현재 앱 위치를 등록하고 확장 폴더 경로를 복사합니다.
2. 해당 Chrome 프로필에서 `chrome://extensions/`를 열고 **개발자 모드**를 켭니다.
3. **압축해제된 확장 프로그램을 로드합니다** → **⌘⇧G → 붙여넣기 → Enter** 후 폴더를 선택합니다.
4. Chrome 확장 메뉴에서 **AI 사용량 · 웹 연결**을 엽니다.
5. 사용할 **Claude 웹 연결**, **GPT 플랜 웹 연결**을 켭니다. Gemini는 기존처럼 자동 연결됩니다.
6. ‘지금 갱신’을 눌러 수치를 확인합니다. 앱에서는 연결 출처가 **Chrome 웹**으로 표시됩니다.

**v1.1.1에서 업데이트했다면** 확장을 새로고침하고 Claude·ChatGPT 사이트 접근 권한을 확인하세요. 새 연결 토글은 기본적으로 꺼져 있습니다.

앱 설정의 Claude·GPT 연결 방식:

| 방식 | 동작 |
|---|---|
| 자동 (연결된 Chrome 우선) | 확장에서 켠 웹 연결이 있으면 웹 사용. 없으면 기존 로컬 로그인 사용 |
| Chrome 웹만 — 터미널 불필요 | 로컬 인증 정보를 조회하지 않고 Chrome 보고서만 사용 |
| 기존 로컬 로그인만 | 기존 Claude Code / Codex 인증 정보 사용 |

웹 연결 오류가 나도 다른 로컬 계정으로 몰래 전환하지 않습니다. **Chrome과 로컬 앱이 서로 다른 계정일 수 있으므로 연결할 프로필을 확인하세요.** Claude·GPT 웹 연결은 선택한 Chrome 프로필의 현재 로그인 계정을 사용하며 이메일은 수집하지 않습니다. 한 Chrome 프로필에서 연결하는 것을 권장합니다.

Gemini는 확장 팝업에서 Google 계정을 이메일로 고정할 수 있습니다. 이메일을 비워두면 현재 Google 계정을 사용하며, 페이지에서 계정을 확인할 수 없으면 수치를 채택하지 않습니다.

확장은 비활성 사용량 탭을 열어 확인한 뒤 닫습니다. 사용자가 직접 선택한 탭은 닫지 않습니다. 앱을 옮기면 **Chrome 연결…**을 다시 누르고 새 위치의 확장을 로드하세요. 연결한 확장 폴더와 앱을 유지해야 합니다.

## 기존 로컬 로그인으로 연결

Claude Code 또는 Codex에 이미 로그인했다면 별도 웹 연결 없이 사용할 수 있습니다. 웹도 연결한 상태에서 로컬 계정을 사용하려면 앱 설정에서 **기존 로컬 로그인만**을 고르세요. Claude는 macOS 키체인 접근 승인이 필요할 수 있습니다.

agy는 CLI 설치·로그인이 필요합니다. 설정의 경로 자동 탐색이 실패하면 실행 파일을 지정하세요. 사용하지 않는 사람은 표시 항목을 끄면 됩니다.

## 업데이트와 삭제

**업데이트:** 메뉴바에서 기존 앱을 종료 → [릴리스](https://github.com/hong-minji/ai-usage-bar/releases)에서 새 ZIP 다운로드 → 같은 응용 프로그램 위치의 앱 교체 → 다시 실행합니다. 자동 업데이트는 없습니다. 웹 확장은 `chrome://extensions/`에서 새로고침(↻)하세요. 앱 위치가 바뀌었다면 Chrome 연결을 다시 하고 로그인 시 자동 실행도 껐다 켜세요.

**삭제:** 설정에서 **로그인 시 자동 실행**을 끄고 종료한 뒤 앱을 휴지통으로 옮깁니다. 웹 연결을 했다면 Chrome 확장과 아래 등록 파일도 삭제하세요. 기록을 지우려면 아래 캐시 폴더를, 설정까지 지우려면 환경설정 파일도 삭제합니다.

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
- 확장은 `claude.ai`, `chatgpt.com`, `gemini.google.com` 접근 권한을 사용합니다. Claude·Codex의 사용량 설정 영역과 Gemini 사용량 페이지에서만 수치를 읽습니다. 쿠키·비밀번호·인증 토큰을 추출하지 않으며 대화 원문을 전송하지 않습니다.
- Claude·GPT 웹 보고서는 서비스 이름, 고정된 사용량 URL, 시각, 사용 퍼센트와 한도 라벨만 저장합니다. 이메일·사용자명·페이지 원문은 저장하지 않습니다.
- 로컬 캐시에는 사용량, 라벨, 플랜, 시각이 저장됩니다. Gemini 연결 캐시에는 확인한 이메일, 페이지 URL, 연결 상태도 포함되며 파일 권한은 소유자 전용(`0600`)으로 설정합니다.
- 확장 팝업에 지정한 이메일과 연결 상태는 Chrome 확장 로컬 저장소에도 남습니다. 확장을 삭제하면 해당 저장소도 제거됩니다.

서비스 제공자가 만든 공식 앱이 아닙니다. 서비스의 인증 방식·응답·웹 페이지가 바뀌면 연결이나 수치 읽기가 중단될 수 있습니다.

## 문제가 생겼나요?

| 증상 | 확인할 것 |
|---|---|
| 앱을 열었는데 창이 없음 | 화면 위쪽 메뉴바를 확인하세요. Dock 아이콘과 일반 앱 창은 없습니다. |
| macOS에서 실행 차단 | 위의 첫 실행 안내와 Apple 공식 안내를 확인하세요. |
| Claude 로그인 정보 없음 | Chrome 웹 연결을 켜거나 기존 Claude Code 로그인·키체인 접근을 확인하세요. |
| GPT 로그인 정보 없음 | Chrome 웹 연결을 켜거나 이 Mac의 기존 Codex 로그인을 확인하세요. |
| GPT에 `–` 표시 | 아직 플랜 사용량을 읽지 못한 상태입니다. Chrome 연결 또는 기존 Codex 로그인을 확인하세요. |
| 웹 연결 수치가 없음 | 확장 새로고침·사이트 접근 권한·서비스 로그인·연결 토글을 확인하세요. |
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
node --test ChromeExtension/*tests.cjs # 확장 검사 (Node.js 필요)
./package.sh                         # 두 아키텍처 빌드 + ZIP + SHA-256
./build/AIUsageBar.app/Contents/MacOS/AIUsageBar --once # 실제 연결 1회 조회
```

`v1.2.1`에서 Swift 검사 144개와 확장 테스트 33개, 통합 빌드, ZIP 압축 해제·서명 검증을 통과했습니다. 실제 연결 검증 범위는 릴리스 노트에 기록합니다. GPT는 제공되는 플랜 사용량을 표시하며 별도 채팅 횟수를 추정하지 않습니다. **macOS 13 및 모든 Mac 기종에서의 실제 설치·실행을 검증한 것은 아닙니다.**

릴리스의 ZIP과 `.sha256` 파일을 같은 폴더에 저장하면 터미널에서 파일 무결성을 확인할 수 있습니다.

```sh
shasum -a 256 -c AIUsageBar-1.2.1-universal.zip.sha256
```

[개발·기여 가이드](CONTRIBUTING.md) · [Gemini 확장](ChromeExtension/) · [릴리스 노트](docs/releases/v1.2.1.md)

## 라이선스

[MIT](LICENSE). 무료로 사용·수정·재배포할 수 있습니다. 각 서비스의 계정·구독은 별도로 필요합니다. Anthropic, OpenAI, Google과 제휴하거나 이들의 승인을 받은 프로젝트가 아닙니다.
