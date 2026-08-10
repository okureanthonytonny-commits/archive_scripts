#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

REQUIRED_FILES=(
  "$SCRIPT_DIR/lib/common.sh"
  "$SCRIPT_DIR/multi_month_zipper.sh"
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

if [ "$#" -gt 0 ]; then
  MONTHS=("$@")
else
  MONTHS=(2025-12 2026-02)
fi

if [ -z "${TMUX:-}" ]; then
  SCRIPT_PATH="$(realpath "$0")"
  SESSION="archive_overnight_$(date +%s)"
  echo "Not inside tmux — relaunching in detached session '$SESSION' with wake-lock held."
  echo "Runs unattended, ANOMALY_MODE=skip. Cleans itself up and stops when done — safe to close the app or lock the phone now."
  tmux new-session -d -s "$SESSION" "'$SCRIPT_PATH' ${MONTHS[*]}"
  echo "Started. Check progress any time with:"
  echo "  tmux attach -t $SESSION"
  echo "(If you don't check in, that's fine — it shuts itself down.)"
  exit 0
fi

source "$SCRIPT_DIR/lib/common.sh"

OVERNIGHT_LOG="$LOG_DIR/overnight_run.log"
exec > >(tee -a "$OVERNIGHT_LOG") 2>&1

log "=== Overnight wrapper starting (PID $$) ==="
log "Months: ${MONTHS[*]}"

termux-wake-lock

ANOMALY_MODE=skip "$SCRIPT_DIR/multi_month_zipper.sh" "${MONTHS[@]}"
STATUS=$?

termux-wake-unlock

if [ "$STATUS" -eq 0 ]; then
  log "=== Overnight run finished: all requested months complete ==="
  MSG="Archive run finished OK: ${MONTHS[*]}"
elif [ "$STATUS" -eq 4 ]; then
  log "=== Overnight run finished, but one or more months were skipped (isolated failures) — see overnight_run.log and orchestrator_run.log ==="
  MSG="Archive run finished with skipped month(s) — check logs: ${MONTHS[*]}"
else
  log "=== Overnight run stopped partway (exit $STATUS) — see overnight_run.log and orchestrator_run.log to debug ==="
  MSG="Archive run STOPPED (exit $STATUS) — check logs: ${MONTHS[*]}"
fi

if command -v termux-notification >/dev/null 2>&1; then
  termux-notification --title "archive_scripts" --content "$MSG"
fi

log "Shutting down to save battery — killing tmux server."
sleep 2
tmux kill-server 2>/dev/null || true
