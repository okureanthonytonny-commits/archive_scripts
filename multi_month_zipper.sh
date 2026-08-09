#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

REQUIRED_FILES=(
  "$SCRIPT_DIR/lib/common.sh"
  "$SCRIPT_DIR/single_month_zipper.sh"
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
    echo "If staging has extra/unverified files when it's time to zip, what should happen (applies to every month in this batch)?"
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
  SESSION="archive_all_$(date +%s)"
  echo "Not inside tmux — relaunching in detached session '$SESSION' with wake-lock held."
  tmux new-session -d -s "$SESSION" \
    "termux-wake-lock; ANOMALY_MODE='$ANOMALY_MODE' '$SCRIPT_PATH' $*; termux-wake-unlock; echo; echo '--- ALL MONTHS DONE. Press Enter to close. ---'; read"
  echo "Started. Check progress any time with:"
  echo "  tmux attach -t $SESSION"
  echo "Detach again with Ctrl+B then D — the job keeps running either way."
  exit 0
fi

source "$SCRIPT_DIR/lib/common.sh"

if [ "$#" -gt 0 ]; then
  MONTHS=("$@")
else
  MONTHS=(2025-12 2026-01 2026-02 2026-03 2026-04)
fi

ORCH_LOG="$LOG_DIR/orchestrator_run.log"
exec > >(tee -a "$ORCH_LOG") 2>&1

log "=== Orchestrator starting (PID $$) ==="
log "Month order: ${MONTHS[*]}"

SUCCEEDED=()
SKIPPED_MONTHS=()
FAILED_MONTH=""

for month in "${MONTHS[@]}"; do
  ZIP_NAME="$(month_to_zipname "$month")"
  ZIP_PATH="$ARCHIVES_DIR/$ZIP_NAME"

  if [ -f "$ZIP_PATH" ]; then
    log "--- $month: zip already exists ($ZIP_NAME) — skipping ---"
    SUCCEEDED+=("$month")
    continue
  fi

  log "--- Starting $month ---"
  "$SCRIPT_DIR/single_month_zipper.sh" "$month"
  status=$?

  if [ "$status" -eq 0 ]; then
    log "--- $month finished OK ---"
    SUCCEEDED+=("$month")
  elif [ "$status" -eq 1 ]; then
    log "--- $month FAILED (exit code 1 = zip creation/verification problem) — isolated to this month. Skipping, continuing to next. ---"
    log "Reason context is in $LOG_DIR/${month}_run.log and $LOG_DIR/${month}_files.tsv"
    SKIPPED_MONTHS+=("$month")
  else
    log "--- $month FAILED (exit code $status) — stopping orchestration here. ---"
    log "Reason context is in $LOG_DIR/${month}_run.log and $LOG_DIR/${month}_files.tsv"
    if [ "$status" -eq 2 ]; then
      log "Exit code 2 = low disk space. This will hit every remaining month too — free space, then resume with:"
    else
      log "Exit code 3 = reconciliation anomaly, cancelled by choice. Investigate staging/file log, then resume with:"
    fi
    log "  $0 ${MONTHS[*]:$(( ${#SUCCEEDED[@]} + ${#SKIPPED_MONTHS[@]} ))}"
    FAILED_MONTH="$month"
    break
  fi
done

log "=== Orchestrator summary ==="
log "Succeeded: ${SUCCEEDED[*]:-none}"
log "Skipped (failed, isolated): ${SKIPPED_MONTHS[*]:-none}"
if [ -n "$FAILED_MONTH" ]; then
  log "Stopped at: $FAILED_MONTH (not yet complete)"
else
  log "All requested months attempted."
fi

log "Archives so far:"
ls -lh "$ARCHIVES_DIR" 2>>"$ORCH_LOG" | tee -a "$ORCH_LOG"

if [ -n "$FAILED_MONTH" ]; then
  exit 1
elif [ "${#SKIPPED_MONTHS[@]}" -gt 0 ]; then
  exit 4
else
  exit 0
fi
