#!/bin/bash
# Registers the local native-messaging host for every Chromium-family browser
# on this Mac, walks through the one-time extension load, and then verifies the
# connection actually works.
#
#   ./install-chrome-bridge.sh          register, guide, verify
#   ./install-chrome-bridge.sh --check  diagnose an existing setup
set -euo pipefail
cd "$(dirname "$0")"
exec python3 - "$PWD" "${1:-install}" <<'PY'
import base64, hashlib, json, os, subprocess, sys, time
from pathlib import Path

root = Path(sys.argv[1])
check_only = sys.argv[2] in ("--check", "check", "--verify")

HOST = "com.local.ai_usage_bar.gemini"
SUPPORT = Path.home() / "Library/Application Support"
CACHE = SUPPORT / "AIUsageBar/gemini-chrome.json"
APPLE_EPOCH = 978307200  # Swift encodes Date as seconds since 2001-01-01.
# The app treats a reading older than this as stale, so the same window decides
# whether the bridge counts as currently working.
FRESH = 15 * 60
EXT_DIR = root / "ChromeExtension"
NATIVE_HOST = root / "build/AIUsageBar.app/Contents/Resources/gemini-native-host"

# Chromium forks each read their own NativeMessagingHosts directory. Registering
# only Chrome's is why a Brave or Edge user would see "host unavailable".
BROWSERS = [
    ("Google Chrome",  "Google/Chrome",               "/Applications/Google Chrome.app"),
    ("Chrome Beta",    "Google/Chrome Beta",          "/Applications/Google Chrome Beta.app"),
    ("Chrome Canary",  "Google/Chrome Canary",        "/Applications/Google Chrome Canary.app"),
    ("Chromium",       "Chromium",                    "/Applications/Chromium.app"),
    ("Brave",          "BraveSoftware/Brave-Browser", "/Applications/Brave Browser.app"),
    ("Microsoft Edge", "Microsoft Edge",              "/Applications/Microsoft Edge.app"),
    ("Vivaldi",        "Vivaldi",                     "/Applications/Vivaldi.app"),
    ("Arc",            "Arc/User Data",               "/Applications/Arc.app"),
]

OK, BAD, WARN, DOT, NONE = "✅", "❌", "⚠️ ", "·", "  "


def fail(message, hint=""):
    print(f"\n{BAD} {message}")
    if hint:
        print(f"   {hint}")
    raise SystemExit(1)


def extension_id():
    """Chrome derives the ID from the manifest's public key, so it is stable."""
    manifest = json.loads((EXT_DIR / "manifest.json").read_text())
    digest = hashlib.sha256(base64.b64decode(manifest["key"])).hexdigest()[:32]
    return "".join(chr(ord("a") + int(c, 16)) for c in digest)


def installed_browsers():
    found = []
    for name, data_dir, app in BROWSERS:
        if (SUPPORT / data_dir).is_dir():
            found.append((name, SUPPORT / data_dir / "NativeMessagingHosts", app))
    return found


def register(target_dir, ext_id):
    target_dir.mkdir(parents=True, exist_ok=True)
    path = target_dir / f"{HOST}.json"
    entry = {
        "name": HOST,
        "description": "AI Usage Bar: Gemini usage figures from the signed-in browser session",
        "path": str(NATIVE_HOST),
        "type": "stdio",
        "allowed_origins": [f"chrome-extension://{ext_id}/"],
    }
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(entry, indent=2) + "\n")
    temporary.chmod(0o600)
    os.replace(temporary, path)
    return path


def registration_problem(path, ext_id):
    """Returns None when the registration on disk is usable, else why not."""
    if not path.is_file():
        return "등록 안 됨 / not registered"
    try:
        entry = json.loads(path.read_text())
    except Exception:
        return "등록 파일이 깨졌습니다 / registration file is corrupt"
    if not Path(entry.get("path", "")).is_file():
        return "앱 경로가 없습니다 — 앱을 옮겼다면 다시 실행하세요 / app path is gone"
    if entry.get("allowed_origins") != [f"chrome-extension://{ext_id}/"]:
        return "확장 ID가 다릅니다 / extension ID mismatch"
    return None


def connection():
    """The latest report the extension delivered, or None."""
    try:
        cache = json.loads(CACHE.read_text())
    except Exception:
        return None
    latest = cache.get("latest") or {}
    received = cache.get("receivedAt")
    if not isinstance(received, (int, float)):
        return None
    return {
        "age": time.time() - (received + APPLE_EPOCH),
        "status": latest.get("status", "?"),
        "account": latest.get("account", ""),
        "used": latest.get("used") or [],
        "labels": latest.get("labels") or [],
    }


def describe(report):
    if report["status"] != "ok":
        states = {
            "login_required": "브라우저에서 Gemini 로그인이 필요합니다 / sign in to Gemini",
            "account_mismatch": "지정한 계정과 다른 계정이 선택되어 있습니다 / wrong account selected",
            "unavailable": "사용량을 읽지 못했습니다 / could not read the usage page",
        }
        return states.get(report["status"], report["status"])
    pairs = [f"{l} {round(100 - u)}% 남음" for l, u in zip(report["labels"], report["used"])]
    return f"{report['account']} {DOT} " + " · ".join(pairs)


# --- run ---------------------------------------------------------------------

ext_id = extension_id()
browsers = installed_browsers()

if not NATIVE_HOST.is_file():
    fail("앱이 아직 빌드되지 않았습니다 / the app is not built yet",
         "먼저 ./build.sh 를 실행하세요 / run ./build.sh first")
if not browsers:
    fail("크로미움 계열 브라우저를 찾지 못했습니다 / no Chromium-family browser found",
         "Chrome을 한 번 실행한 뒤 다시 시도하세요 / launch Chrome once, then retry")

if check_only:
    print("AI 사용량 메뉴바 — Gemini 연결 점검 / connection check\n")
    print(f"확장 ID / extension ID: {ext_id}\n")
    registered = 0
    for name, target_dir, _ in browsers:
        path = target_dir / f"{HOST}.json"
        if not path.is_file():
            # Installed but unused browsers are not a problem worth a red mark.
            print(f"  {NONE} {name} — 미등록 (이 브라우저를 쓰면 설치를 다시 실행하세요)")
            continue
        problem = registration_problem(path, ext_id)
        registered += 0 if problem else 1
        print(f"  {BAD if problem else OK} {name}{': ' + problem if problem else ''}")

    report = connection()
    print()
    if registered == 0:
        print(f"  {BAD} 등록된 브라우저가 없습니다 / no browser is registered")
        print(f"     ./install-chrome-bridge.sh 를 실행하세요 / run the installer")
    elif report is None:
        print(f"  {BAD} 확장에서 받은 데이터가 없습니다 / no data received from the extension")
        print(f"     확장을 로드했는지, chrome://extensions 에서 새로고침(↻)했는지 확인하세요.")
        print(f"     Load the extension, or press reload on its card.")
    elif report["age"] > FRESH:
        minutes = int(report["age"] // 60)
        print(f"  {WARN}마지막 수신이 {minutes}분 전입니다 / last report was {minutes} min ago")
        print(f"     브라우저가 실행 중이어야 합니다 / the browser must be running")
    else:
        print(f"  {OK} 연결됨 / connected {DOT} {describe(report)}")
    raise SystemExit(0)

print("AI 사용량 메뉴바 — Gemini 연결 설치 / setup\n")

for name, target_dir, _ in browsers:
    register(target_dir, ext_id)
    print(f"  {OK} {name} 등록 완료 / registered")

# Re-running a working setup should say so, not reopen windows and wait.
baseline = connection()
if baseline and baseline["age"] < FRESH:
    print(f"\n{OK} 이미 연결되어 있습니다 / already connected {DOT} {describe(baseline)}")
    raise SystemExit(0)

# Paste-ready: the file picker's ⌘⇧G accepts this directly.
try:
    subprocess.run(["pbcopy"], input=str(EXT_DIR).encode(), check=True)
    clipboard = "   폴더 경로를 클립보드에 복사했습니다. 파일 선택창에서 ⌘⇧G 후 붙여넣기 하세요.\n" \
                "   The folder path is on your clipboard — press ⌘⇧G in the picker and paste."
except Exception:
    clipboard = f"   폴더 / folder: {EXT_DIR}"

primary = next((b for b in browsers if Path(b[2]).exists()), None)

print(f"""
남은 단계는 브라우저가 직접 승인해야 합니다. 세 번만 누르면 됩니다.
Three clicks left — the browser requires you to do these itself.

  1. 개발자 모드를 켭니다 (오른쪽 위)        Turn on Developer mode (top right)
  2. "압축해제된 확장 프로그램을 로드합니다"  Click "Load unpacked"
  3. 아래 폴더를 선택합니다                  Select the folder below

{clipboard}
""")

if primary:
    name, _, app = primary
    print(f"   {name} 의 확장 관리 화면과 폴더를 엽니다 / opening {name} and the folder…\n")
    subprocess.run(["open", "-R", str(EXT_DIR / "manifest.json")], check=False)
    subprocess.run(["open", "-a", app, "chrome://extensions/"], check=False)

print("연결을 기다리는 중입니다… (Ctrl-C 로 중단) / waiting for the extension…")

deadline = time.time() + 180
baseline_age = baseline["age"] if baseline else None
try:
    while time.time() < deadline:
        report = connection()
        fresh = report and report["age"] < FRESH and (baseline_age is None or report["age"] < baseline_age)
        if fresh:
            print(f"\n{OK} 연결 확인 / connected {DOT} {describe(report)}")
            print("\n메뉴바 앱을 열면 Gemini 수치가 표시됩니다 / open the app and Gemini will appear.")
            raise SystemExit(0)
        remaining = int(deadline - time.time())
        print(f"\r   {remaining}초 남음 / {remaining}s left ", end="", flush=True)
        time.sleep(2)
except KeyboardInterrupt:
    print("\n\n중단했습니다. 나중에 ./install-chrome-bridge.sh --check 로 확인할 수 있습니다.")
    print("Stopped. Run ./install-chrome-bridge.sh --check later to verify.")
    raise SystemExit(130)

print(f"\n\n{WARN}아직 연결되지 않았습니다 / not connected yet\n")
print("확인할 것 / things to check:")
print("  · 확장을 로드했나요? 이미 로드했다면 chrome://extensions 에서 새로고침(↻)을 누르세요.")
print("    Loaded the extension? If it was already loaded, press reload on its card.")
print("  · Gemini에 로그인된 프로필인가요? / Is this profile signed in to Gemini?")
print("  · 확장 팝업의 '지금 갱신'을 눌러보세요. / Press 지금 갱신 in the extension popup.")
print("\n언제든 ./install-chrome-bridge.sh --check 로 다시 점검할 수 있습니다.")
print("Re-check any time with ./install-chrome-bridge.sh --check")
raise SystemExit(1)
PY
