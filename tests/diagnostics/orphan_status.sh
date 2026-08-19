#!/data/data/com.termux/files/usr/bin/bash
# tests/diagnostics/orphan_status.sh -- manual inspection tool for
# files not yet confirmed DELETED: staged/original/track/manifest.
# Usage: orphan_status.sh <YYYY-MM>
#
# Original-url reconstruction shares lib/orphan_reconcile.sh's
# _orphan_derive_url() -- the same source of truth the production orphan
# reconciliation uses (see issues.md gap 3: .jpg/.jpeg/.png compress
# to .webp, so the staged extension can't be used to find the original).

set -uo pipefail

MONTH="${1:?usage: orphan_status.sh <YYYY-MM>}"
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/orphan_reconcile.sh"

STAGE="$STAGING/$MONTH"

if [ ! -d "$STAGE" ]; then
  echo "No staging directory for $MONTH: $STAGE" >&2
  exit 1
fi

find "$STAGE" -type f | while read -r staged; do
  rel="${staged#$STAGE/}"
  orig="$(_orphan_derive_url "$staged" "$STAGE" "$MANIFEST")"

  echo "=== $rel ==="
  echo "  staged:   EXISTS  ($staged)"
  if [ -f "$orig" ]; then
    echo "  original: EXISTS  ($orig)"
  else
    echo "  original: MISSING  ($orig)"
  fi
  echo -n "  track:    "
  python3 "$SCRIPT_DIR/lib/track.py" get "$orig" 2>/dev/null || echo "(no track entry)"
done
