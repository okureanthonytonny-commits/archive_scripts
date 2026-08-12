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
#
# Interactive: for each missing REQUIRED command, offers to
# `pkg install` its package right now (y/N). OPTIONAL commands are
# never offered for auto-install -- termux-wake-lock/termux-notification
# come from the termux-api package, but also need the Termux:API
# companion app from F-Droid, which pkg can't install, so a partial
# `pkg install` fix would be misleading.

set -uo pipefail

REQUIRED_CMDS=(python3 ffmpeg cwebp zip unzip tmux)
OPTIONAL_CMDS=(termux-wake-lock termux-notification)

declare -A CMD_PKG=(
  [python3]=python
  [ffmpeg]=ffmpeg
  [cwebp]=webp
  [zip]=zip
  [unzip]=unzip
  [tmux]=tmux
)

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
  for cmd in "${missing_required[@]}"; do
    pkg="${CMD_PKG[$cmd]:-$cmd}"
    read -r -p "  Install '"'"'$pkg'"'"' now to provide '"'"'$cmd'"'"'? [y/N] " ans
    case "$ans" in
      [Yy]*)
        pkg install -y "$pkg"
        if command -v "$cmd" >/dev/null 2>&1; then
          echo "  OK: $cmd now available."
        else
          echo "  STILL MISSING: $cmd (install ran but command not found -- check package name)"
        fi
        ;;
      *)
        echo "  SKIPPED: $cmd not installed. Fix later with: pkg install $pkg"
        ;;
    esac
  done
fi

if [ "${#missing_optional[@]}" -eq 0 ]; then
  echo "OK: all optional commands present (${OPTIONAL_CMDS[*]})"
else
  echo "MISSING (optional, needed for overnight/unattended runs): ${missing_optional[*]}"
  echo "  Fix: pkg install termux-api, then install the Termux:API companion app from F-Droid (pkg alone is not enough)."
fi

# Re-derive final required-missing count post-install attempts, for exit code.
still_missing=0
for cmd in "${REQUIRED_CMDS[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || still_missing=$((still_missing + 1))
done

[ "$still_missing" -eq 0 ]
