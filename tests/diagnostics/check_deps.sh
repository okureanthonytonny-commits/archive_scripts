#!/data/data/com.termux/files/usr/bin/bash
# tests/diagnostics/check_deps.sh -- checks required/optional external deps, interactive install prompts.

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
