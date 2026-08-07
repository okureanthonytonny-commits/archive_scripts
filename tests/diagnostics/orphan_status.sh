#!/data/data/com.termux/files/usr/bin/bash
# tests/diagnostics/orphan_status.sh — per-file status dump for staged
# files not yet confirmed DELETED: staged/original/track/manifest.
# Usage: orphan_status.sh <YYYY-MM>
#
# Fixed vs. the 2026-08-06 ad-hoc version (see issues.md gap 3): that
# version assumed the original had the same extension as the staged
# file, which is wrong for images \xe2\x80\x94 .jpg/.jpeg/.png compress to
# .webp, so it reported original:MISSING for nearly every photo
# regardless of whether that was true. This version tries the real
# candidate extensions for webp outputs instead of the staged one.

set -uo pipefail

MONTH="${1:?usage: orphan_status.sh <YYYY-MM>}"
STAGE="$HOME/archive_staging/$MONTH"
MANIFEST="$HOME/archive_manifest.tsv"
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"

if [ ! -d "$STAGE" ]; then
  echo "No staging directory for $MONTH: $STAGE" >&2
  exit 1
fi

find "$STAGE" -type f | while read -r staged; do
  rel="${staged#$STAGE/}"
  reldir="$(dirname "$rel")"
  base="$(basename "$rel")"
  base_noext="${base%.*}"
  ext_lower=$(echo "${base##*.}" | tr '[:upper:]' '[:lower:]')
  orig_dir="/storage/emulated/0/$reldir"

  orig=""
  if [ "$ext_lower" = "webp" ]; then
    for cand_ext in jpg jpeg JPG JPEG png PNG; do
      cand="$orig_dir/${base_noext}.${cand_ext}"
      if [ -f "$cand" ]; then
        orig="$cand"
        break
      fi
    done
    [ -z "$orig" ] && orig="$orig_dir/${base_noext}.jpg (no match found, showing default guess)"
  else
    orig="$orig_dir/$base"
  fi

  echo "=== $rel ==="
  echo "  staged:   EXISTS  ($staged)"
  if [[ "$orig" == *"(no match found"* ]]; then
    echo "  original: MISSING  ($orig)"
  else
    echo "  original: $([ -f "$orig" ] && echo EXISTS || echo MISSING)  ($orig)"
  fi
  echo -n "  track:    "
  python3 "$SCRIPT_DIR/lib/track.py" get "$orig" 2>/dev/null || echo "(no track entry)"
  echo -n "  manifest: "
  if grep -qF "$orig" "$MANIFEST" 2>/dev/null; then echo "YES"; else echo "NO"; fi
  echo
done
