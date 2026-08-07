#!/data/data/com.termux/files/usr/bin/bash
# tests/run_retry_test.sh — self-contained retry-on-FAILED test.
# Runs entirely against an isolated STATE_LOG; never touches production
# .state_log.tsv. Exercises Pass 1's retry branch + verify() directly —
# does NOT call delete(), so real originals in DCIM are never touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
export STATE_LOG="$SCRIPT_DIR/tests/fixtures/test_state_log.tsv"
MONTH_STAGE="/data/data/com.termux/files/home/archive_staging/2026-03"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/single_file_compressor.sh"
source "$SCRIPT_DIR/lib/verify.sh"
source "$SCRIPT_DIR/lib/delete.sh"
source "$SCRIPT_DIR/lib/multi_file_pipeline.sh"

echo "Using STATE_LOG: $STATE_LOG"
echo

for f in \
  "/storage/emulated/0/DCIM/Camera/20260324_080113.mp4" \
  "/storage/emulated/0/DCIM/Camera/20260324_080046.mp4"; do

  echo "=== $f ==="
  result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$f")
  IFS=$'\t' read -r state_name state_int kind path note <<< "$result"

  case "$state_name" in
    PENDING|COMPRESSED) ;;
    FAILED)
      attempts=$(python3 "$SCRIPT_DIR/lib/track.py" count "$f" FAILED)
      if [ "$attempts" -ge "${RETRY_MAX:-2}" ]; then
        echo "SKIP (retry exhausted, $attempts/${RETRY_MAX:-2} FAILED attempts): $f"
        continue
      fi
      echo "RETRY ($attempts/${RETRY_MAX:-2} prior FAILED attempts) — clearing stale output: $f"
      [ -n "$path" ] && [ -f "$path" ] && rm -f "$path"
      ;;
    *) echo "unexpected state $state_name, skipping"; continue ;;
  esac

  echo "recompressing..."
  compressor_process "$f" "$MONTH_STAGE"

  echo "verifying..."
  verify "$f"

  echo "final state:"
  python3 "$SCRIPT_DIR/lib/track.py" get "$f"
  echo
done
