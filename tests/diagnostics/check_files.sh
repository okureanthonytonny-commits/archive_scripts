#!/data/data/com.termux/files/usr/bin/bash
# tests/diagnostics/check_files.sh -- confirms required repo files exist, prints git recovery steps for anything missing.

set -uo pipefail

REQUIRED_FILES=(
  single_month_zipper.sh
  multi_month_zipper.sh
  run_overnight.sh
  build_manifest.sh
  lib/common.sh
  lib/single_file_compressor.sh
  lib/verify.sh
  lib/delete.sh
  lib/multi_file_pipeline.sh
  lib/track.py
  lib/summary.py
)

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"

missing=()
for f in "${REQUIRED_FILES[@]}"; do
  [ -f "$SCRIPT_DIR/$f" ] || missing+=("$f")
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "OK: all required files present (${#REQUIRED_FILES[@]} checked)"
else
  echo "MISSING (required): ${missing[*]}"
  for f in "${missing[@]}"; do
    echo "  $f"
    echo "    check:   git -C \"$SCRIPT_DIR\" status -- \"$f\""
    echo "    restore: git -C \"$SCRIPT_DIR\" checkout HEAD -- \"$f\""
  done
fi

[ "${#missing[@]}" -eq 0 ]
