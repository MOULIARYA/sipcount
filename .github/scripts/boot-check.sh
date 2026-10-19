#!/usr/bin/env bash
# THE APP OPENS (I-74 / I-75 / I-76).
#
# Installs the exact APK we are about to publish on the running emulator, launches it, and waits
# for the marker the app prints once its first screen is up:
#     SIPCOUNT_BOOT ok                   → pass
#     SIPCOUNT_BOOT failed: <reason>     → fail, with the reason in the log
#     nothing within the limit           → fail ("frozen on the launch logo?")
#     process gone                       → fail (crash)
#
# A file, not inline YAML: the emulator action runs its `script` one line at a time with `sh`,
# so a multi-line bash loop there is split into fragments and `set -o pipefail` alone exits 2.
# That is exactly how run 32 failed (I-76). `docs/test/ci.js` syntax-checks this file and asserts
# the workflow calls it on one line.
#
# Usage: boot-check.sh <apk> [seconds-to-wait]
set -euo pipefail

APK="${1:?apk path required}"
LIMIT="${2:-90}"
PKG="io.sipcount.ai_water"

echo "Installing $APK"
adb install -r "$APK"
adb logcat -c || true
echo "Launching $PKG"
adb shell am start -W -n "$PKG/.MainActivity"

marker=""
waited=0
while [ "$waited" -lt "$LIMIT" ]; do
  sleep 2
  waited=$((waited + 2))
  if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
    echo "::error::Sipcount's process died ${waited}s after launch"
    adb logcat -d | grep -E 'flutter|AndroidRuntime|sipcount' | tail -200 || true
    exit 1
  fi
  marker="$(adb logcat -d 2>/dev/null | grep -E 'SIPCOUNT_BOOT (ok|failed)' | head -1 || true)"
  if [ -n "$marker" ]; then
    break
  fi
done

echo "boot marker after ${waited}s: ${marker:-<none>}"
if printf '%s' "$marker" | grep -q 'SIPCOUNT_BOOT ok'; then
  echo "The app reached its first screen."
  exit 0
fi

echo "::error::The app did not reach its first screen: ${marker:-no boot marker within ${LIMIT}s (frozen on the launch logo?)}"
adb logcat -d | grep -E 'flutter|AndroidRuntime|sipcount' | tail -200 || true
exit 1
