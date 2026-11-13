# AI 사용량 · 웹 연결 / Web usage bridge

Claude·GPT·Gemini 사용량 페이지의 표시값을 이 Mac의 앱에 전달합니다. 터미널용 Claude Code·Codex 설치는 필요하지 않습니다. GPT는 ChatGPT 설정의 플랜 사용량을 표시합니다. 포함되는 기능은 사용량 페이지를 확인하세요.

Reads displayed Claude, GPT and Gemini usage figures into the local app. Claude Code and Codex CLI installations are not required. GPT displays the reported plan allowance; check the usage page for included features.

## 설치 / Setup

1. 설치된 앱의 **설정 → 웹 연결 → Chrome 연결…**을 누릅니다. / Use the installed app's Connect Chrome button.
2. 원하는 Chrome 프로필의 `chrome://extensions/`에서 개발자 모드를 켭니다. / Enable Developer mode in the intended Chrome profile.
3. 압축해제된 확장 프로그램 로드 → `⌘⇧G` → 복사된 경로 붙여넣기 → 폴더 선택. / Load unpacked, press `⌘⇧G`, paste and select the folder.
4. **AI 사용량 · 웹 연결** 팝업에서 Claude / GPT 연결을 켜고 지금 갱신을 누릅니다. Gemini는 자동 연결됩니다. / Enable Claude and/or GPT in the popup and refresh. Gemini connects automatically.

v1.1.1에서 업데이트하면 확장을 새로고침하고 새 사이트 권한을 확인하세요. / Reload and review new site permissions when upgrading from v1.1.1.

## 데이터 / Data

- Claude·Codex는 명시적으로 켰을 때만 5분마다 비활성 탭을 열어 확인합니다. / Claude and Codex polling is opt-in.
- 다른 페이지·프레임·요청한 탭이 아닌 곳의 메시지는 거부합니다. / Reports from unrelated pages, frames and tabs are rejected.
- 사용자가 선택한 탭은 자동으로 닫지 않습니다. / User-selected tabs are retained.
- 새 웹 연결은 이메일·사용자명·쿠키·토큰·페이지 원문을 저장하거나 앱에 보내지 않습니다. / New web connections never store or forward identity, credentials or page text.
- Gemini만 Google 계정 확인을 위해 이메일을 사용합니다. 선택적으로 고정할 수 있으며 로컬 캐시에도 저장됩니다. / Gemini uses a verified email for account matching, with optional pinning and a local cache.
- Claude·Codex는 현재 Chrome 로그인 계정을 사용합니다. 로컬 앱의 계정과 다를 수 있습니다. / Claude and Codex use the current Chrome account, which may differ from local apps.
- 계정 전환·페이지 변경·로그아웃 때 갱신 실패 또는 오래된 값이 표시될 수 있습니다. / Account changes, page changes and logout can produce an error or stale values.

권한 / Permissions: `alarms`, `nativeMessaging`, `storage`; site access to `gemini.google.com`, `claude.ai`, `chatgpt.com`.

Claude 콘텐츠 스크립트는 `/settings/usage`와 `/new`에서 로드되지만, `/new#settings/usage` 사용량 설정이 열렸을 때만 읽습니다. ChatGPT는 `/settings/usage`, Gemini는 `/usage`와 `/u/숫자/usage`만 읽습니다. / Claude's script loads on the usage route and `/new`, but reads `/new` only when the usage-settings fragment is active. ChatGPT and Gemini scripts are limited to their usage routes.

고정 ID / Fixed extension ID: `edmmoiejceaokbohcdedkehoabkgkole`. `manifest.json`의 키는 공개키이며 인증 비밀이 아닙니다. / The manifest key is public, not a credential.

## 개발 / Development

```sh
node --test ChromeExtension/*tests.cjs
```

`fixtures/` contains only sanitized quota-section excerpts; no names, emails, account IDs, cookies or tokens. Only runtime JS, HTML and the manifest are bundled in the released app.

The internal `codex` report/cache identifier remains unchanged for compatibility. The visible label is GPT.
