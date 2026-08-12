#!/data/data/com.termux/files/usr/bin/bash
# tests/diagnostics/check_deps.sh — confirm required external binaries
# are on PATH before a pipeline run. Data-driven: add/remove commands
# in the arrays below, one loop checks all of them.
#
# REQUIRED_CMDS: pipeline fails without these (see README "Getting started").
# OPTIONAL_CMDS: needed for unattended/overnight runs (termux-wake-lock,
#   termux-notification) but require the separate Termux:API companion
#   app (F-Droid), not just `pkg install` -- missing these degrades
#   gracefully rather than breaking the run, so they're flagged, not fatal.

set -uo pipefail

REQUIRED_CMDS=(python3 ffmpeg cwebp zip unzip tmux)
OPTIONAL_CMDS=(termux-wake-lock termux-notification)

missing_required=()
missing_optional=()

for cmd in "${REQUIRED_CMDS[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing_required+=("$cmd")
done

for cmd in "${OPTIONAL_CMDS[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing_optional+=("$cmd")
done

if [ "${#missing_required[@]}" -eq 0 ]; then
  echo "OK: all required commands present (${REQUIRED_CMDS[*]})"
else
  echo "MISSING (required): ${missing_required[*]}"
fi

if [ "${#missing_optional[@]}" -eq 0 ]; then
  echo "OK: all optional commands present (${OPTIONAL_CMDS[*]})"
else
  echo "MISSING (optional, needed for overnight/unattended runs via Termux:API): ${missing_optional[*]}"
fi

[ "${#missing_required[@]}" -eq 0 ]
