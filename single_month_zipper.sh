#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

REQUIRED_FILES=(
  "$SCRIPT_DIR/lib/common.sh"
  "$SCRIPT_DIR/lib/single_file_compressor.sh"
  "$SCRIPT_DIR/lib/verify.sh"
  "$SCRIPT_DIR/lib/delete.sh"
  "$SCRIPT_DIR/lib/multi_file_pipeline.sh"
  "$SCRIPT_DIR/lib/orphan_reconcile.sh"
  "$SCRIPT_DIR/lib/track.py"
  "$SCRIPT_DIR/lib/summary.py"
)
MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
  [ -f "$f" ] || MISSING+=("$f")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "PREFLIGHT FAILED — missing required file(s):"
  printf '  %s\n' "${MISSING[@]}"
  exit 1
fi

if [ -z "${TMUX:-}" ]; then
  ANOMALY_MODE="${ANOMALY_MODE:-}"
  if [ -z "$ANOMALY_MODE" ]; then
    echo "If staging has extra/unverified files when it's time to zip, what should happen?"
    echo "  1) wait    - pause indefinitely and ask right when it happens"
    echo "  2) cancel  - if unanswered after 5 min, auto-cancel that month's zip"
    echo "  3) skip    - if unanswered after 5 min, auto-skip the extras and zip the rest"
    read -r -p "Choice [1/2/3]: " choice
    case "$choice" in
      1) ANOMALY_MODE="wait" ;;
      2) ANOMALY_MODE="cancel" ;;
      3) ANOMALY_MODE="skip" ;;
      *) echo "Invalid choice — defaulting to 'wait'."; ANOMALY_MODE="wait" ;;
    esac
  fi
  SCRIPT_PATH="$(realpath "$0")"
  SESSION="archive_$(date +%s)"
  echo "Not inside tmux — relaunching in detached session '$SESSION' with wake-lock held."
  tmux new-session -d -s "$SESSION" \
    "termux-wake-lock; ANOMALY_MODE='$ANOMALY_MODE' '$SCRIPT_PATH' $*; termux-wake-unlock; echo; echo '--- DONE. Press Enter to close. ---'; read"
  echo "Started. Check progress any time with:"
  echo "  tmux attach -t $SESSION"
  echo "Detach again with Ctrl+B then D — the job keeps running either way."
  exit 0
fi

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/single_file_compressor.sh"
source "$SCRIPT_DIR/lib/verify.sh"
source "$SCRIPT_DIR/lib/delete.sh"
source "$SCRIPT_DIR/lib/multi_file_pipeline.sh"
source "$SCRIPT_DIR/lib/orphan_reconcile.sh"

ANOMALY_MODE="${ANOMALY_MODE:-wait}"

TARGET_MONTH="${1:-}"
if [ -z "$TARGET_MONTH" ]; then
  echo "Usage: $0 YYYY-MM"
  echo "Available months in manifest:"
  awk -F'\t' '{print $1}' "$MANIFEST" | sort -u
  exit 1
fi

RUN_LOG="$LOG_DIR/${TARGET_MONTH}_run.log"
FILE_LOG="$LOG_DIR/${TARGET_MONTH}_files.tsv"
exec > >(tee -a "$RUN_LOG") 2>&1

log "=== Starting run for $TARGET_MONTH (PID $$) ==="

ZIP_NAME="$(month_to_zipname "$TARGET_MONTH")"
ZIP_PATH="$ARCHIVES_DIR/$ZIP_NAME"
MONTH_STAGE="$STAGING/$TARGET_MONTH"
mkdir -p "$MONTH_STAGE"

log "Target zip: $ZIP_NAME"

FILELIST="$HOME/.archive_tmp/filelist_${TARGET_MONTH}.txt"
awk -F'\t' -v m="$TARGET_MONTH" '$1==m {print $3}' "$MANIFEST" > "$FILELIST"

ORIGINAL_BYTES=$(awk -F'\t' -v m="$TARGET_MONTH" '$1==m {sum+=$2} END{print sum+0}' "$MANIFEST")
log "Original size for $TARGET_MONTH: $((ORIGINAL_BYTES / 1024 / 1024)) MB"

process_month "$FILELIST" "$MONTH_STAGE"

python3 "$SCRIPT_DIR/lib/summary.py" "$FILELIST" > "$FILE_LOG"

log "=== Status breakdown (this month's file log) ==="
awk -F'\t' '{c[$2]++} END {for (s in c) printf "  %s: %d\n", s, c[s]}' "$FILE_LOG" | tee -a "$RUN_LOG"

log "Building zip file list from DELETED (successfully processed) entries only..."
ZIP_FILELIST="$HOME/.archive_tmp/zip_filelist_${TARGET_MONTH}.txt"
> "$ZIP_FILELIST"
while IFS= read -r src_url; do
  [ -z "$src_url" ] && continue
  result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$src_url")
  IFS=$'\t' read -r state_name state_int kind staged_path note <<< "$result"
  if [ "$state_name" = "DELETED" ] && [ -n "$staged_path" ] && [ -f "$staged_path" ]; then
    echo "${staged_path#"$MONTH_STAGE"/}" >> "$ZIP_FILELIST"
  fi
done < "$FILELIST"

ZIP_COUNT=$(wc -l < "$ZIP_FILELIST" | tr -d ' ')
log "$ZIP_COUNT verified file(s) to zip."

# --- Orphan reconciliation: any physical staged file not covered by a
# confirmed DELETED entry above gets its original url + kind reconstructed
# and run through verify_orphan() (lib/orphan_reconcile.sh). A VERIFIED
# orphan folds straight into the zip list; a FAILED one gets a tracked
# FAILED entry with a reason and falls into the same retry-with-guard
# logic as Pass 1 (recompress if the original exists, MISSING if it's
# gone), capped by RETRY_MAX.
log "Checking staging for orphans (files not backed by a confirmed DELETED entry)..."
reconcile_orphans "$MONTH_STAGE" "$ZIP_FILELIST" "$MANIFEST"

ZIP_COUNT=$(wc -l < "$ZIP_FILELIST" | tr -d ' ')
log "$ZIP_COUNT verified file(s) to zip (after orphan reconciliation)."

# --- Two-way reconciliation: manifest vs terminal states vs physical staging ---
ORIGINAL_COUNT=$(wc -l < "$FILELIST" | tr -d ' ')
TERMINAL_COUNT=$(wc -l < "$FILE_LOG" | tr -d ' ')
DELETED_TAG_COUNT=$(awk -F'\t' '$2 ~ /^OK_.*_DELETED$/' "$FILE_LOG" | wc -l | tr -d ' ')
STAGE_PHYSICAL_COUNT=$(find "$MONTH_STAGE" -type f | wc -l | tr -d ' ')

STUCK_COUNT=$((ORIGINAL_COUNT - TERMINAL_COUNT))
GHOST_COUNT=$((DELETED_TAG_COUNT - ZIP_COUNT))
ORPHAN_COUNT=$((STAGE_PHYSICAL_COUNT - ZIP_COUNT))

if [ "$STUCK_COUNT" -gt 0 ] || [ "$GHOST_COUNT" -gt 0 ] || [ "$ORPHAN_COUNT" -gt 0 ]; then
  log "ANOMALY in $TARGET_MONTH reconciliation:"
  log "  Original files (manifest):    $ORIGINAL_COUNT"
  log "  Reached a terminal state:     $TERMINAL_COUNT"
  [ "$STUCK_COUNT" -gt 0 ]  && log "  -> STUCK mid-pipeline (no terminal state yet): $STUCK_COUNT"
  [ "$GHOST_COUNT" -gt 0 ]  && log "  -> GHOST (state says DELETED, staged file missing): $GHOST_COUNT"
  [ "$ORPHAN_COUNT" -gt 0 ] && log "  -> ORPHAN (still unresolved after verification attempt): $ORPHAN_COUNT"

  RESOLUTION=""
  case "$ANOMALY_MODE" in
    skip)
      log "ANOMALY_MODE=skip — proceeding with only the $ZIP_COUNT confirmed file(s), excluding everything flagged above."
      RESOLUTION="skip"
      ;;
    cancel)
      log "ANOMALY_MODE=cancel — waiting up to 5 min for confirmation, auto-cancelling if unanswered."
      read -r -t 300 -p "Reconciliation anomaly found. [s]kip flagged files and zip / [c]ancel this month: " choice
      case "${choice:-}" in
        s|S) RESOLUTION="skip" ;;
        *) RESOLUTION="cancel" ;;
      esac
      ;;
    wait|*)
      log "ANOMALY_MODE=wait — pausing indefinitely for confirmation."
      read -r -p "Reconciliation anomaly found. [s]kip flagged files and zip / [c]ancel this month: " choice
      case "$choice" in
        s|S) RESOLUTION="skip" ;;
        *) RESOLUTION="cancel" ;;
      esac
      ;;
  esac

  if [ "$RESOLUTION" = "cancel" ]; then
    log "Cancelled: reconciliation anomaly in $TARGET_MONTH. Not zipping."
    log "Nothing lost — originals for any non-DELETED file are untouched; $MONTH_STAGE left as-is for investigation."
    log "Investigate $MONTH_STAGE and $FILE_LOG by hand, then re-run: $0 $TARGET_MONTH"
    exit 3
  fi
  log "Proceeding: zipping the $ZIP_COUNT confirmed file(s), excluding everything flagged above."
fi

if [ "$ZIP_COUNT" -eq 0 ]; then
  log "No verified files to zip for $TARGET_MONTH. Skipping zip."
  log "Check $FILE_LOG for FAIL_*/MISSING entries if this is unexpected."
  exit 0
fi

check_space_for_zip "$MONTH_STAGE"

log "Zipping to $ZIP_PATH..."
if ( cd "$MONTH_STAGE" && zip -q "$ZIP_PATH" -@ < "$ZIP_FILELIST" ); then
  log "Zip created."
else
  log "ZIP CREATION FAILED. Staged (already-verified) files remain in $MONTH_STAGE — nothing lost, just not yet archived. Investigate and re-run."
  exit 1
fi

log "Verifying zip integrity..."
if unzip -tq "$ZIP_PATH" > /dev/null 2>>"$RUN_LOG"; then
  log "Zip verified OK: $ZIP_PATH"
  ls -lh "$ZIP_PATH"
else
  log "ZIP VERIFICATION FAILED. Staged files remain in $MONTH_STAGE for safety — do not trust $ZIP_PATH. Investigate before re-running."
  exit 1
fi

rm -rf "$MONTH_STAGE"
log "Staging cleared for $TARGET_MONTH."

log "=== Run finished for $TARGET_MONTH ==="
log "Run log: $RUN_LOG"
log "File log: $FILE_LOG"

FAIL_COUNT=$(awk -F'\t' '$2 ~ /^FAIL_/' "$FILE_LOG" | wc -l)
if [ "$FAIL_COUNT" -gt 0 ]; then
  log "NOTE: $FAIL_COUNT file(s) failed and were left in place (originals untouched). Check $FILE_LOG for FAIL_* entries."
fi
