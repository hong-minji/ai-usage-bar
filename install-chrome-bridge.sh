#!/bin/bash
# Registers the local host. The user adds the scoped Chrome extension once.
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_ROOT="$PWD"
python3 - "$PROJECT_ROOT" <<'PY'
import hashlib, json, base64, os, sys
from pathlib import Path
root = Path(sys.argv[1])
app = root / 'build/AIUsageBar.app'
manifest = json.loads((root / 'ChromeExtension/manifest.json').read_text())
key = base64.b64decode(manifest['key'])
extension_id = ''.join(chr(ord('a') + int(c, 16)) for c in hashlib.sha256(key).hexdigest()[:32])
host = app / 'Contents/Resources/gemini-native-host'
if not host.is_file():
    raise SystemExit('먼저 ./build.sh 를 실행하세요.')
folder = Path.home() / 'Library/Application Support/Google/Chrome/NativeMessagingHosts'
folder.mkdir(parents=True, exist_ok=True)
path = folder / 'com.local.ai_usage_bar.gemini.json'
entry = {
    'name': 'com.local.ai_usage_bar.gemini',
    'description': 'AI Usage Bar: Gemini usage figures from the signed-in Chrome session',
    'path': str(host), 'type': 'stdio',
    'allowed_origins': [f'chrome-extension://{extension_id}/'],
}
temporary = path.with_suffix('.tmp')
temporary.write_text(json.dumps(entry, indent=2) + '\n')
temporary.chmod(0o600)
os.replace(temporary, path)
print(f'Chrome 연결 준비 완료: {extension_id}')
print(f'확장 프로그램 폴더: {root / "ChromeExtension"}')
PY
