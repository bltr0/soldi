#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
  DART=(fvm dart)
else
  FLUTTER=(flutter)
  DART=(dart)
fi

CLIENT_ID="${GOOGLE_OAUTH_WEB_CLIENT_ID:-}"
if [[ -z "$CLIENT_ID" && -f "$ROOT/.google_oauth_web_client_id" ]]; then
  CLIENT_ID="$(tr -d '[:space:]' < "$ROOT/.google_oauth_web_client_id")"
fi

DEFINE_ARGS=()
if [[ -n "$CLIENT_ID" ]]; then
  DEFINE_ARGS+=(--dart-define="GOOGLE_OAUTH_WEB_CLIENT_ID=${CLIENT_ID}")
else
  echo "Warning: GOOGLE_OAUTH_WEB_CLIENT_ID is unset; Drive backup will be disabled in this APK." >&2
  echo "Export it, or put the Web client ID in .google_oauth_web_client_id at the repo root." >&2
fi

"${FLUTTER[@]}" pub get
"${DART[@]}" run build_runner build --delete-conflicting-outputs

"${FLUTTER[@]}" build apk --no-pub --flavor default --release "${DEFINE_ARGS[@]}"

APK="$ROOT/build/app/outputs/flutter-apk/app-default-release.apk"
if [[ ! -f "$APK" ]]; then
  echo "Build finished but APK was not found at $APK" >&2
  exit 1
fi

cp -f "$APK" "$ROOT/sossoldi-bltr.apk"
echo "Wrote $ROOT/sossoldi-bltr.apk"
