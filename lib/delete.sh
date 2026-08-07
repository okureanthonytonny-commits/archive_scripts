#!/data/data/com.termux/files/usr/bin/bash
# lib/delete.sh — deletes the original only after VERIFIED is confirmed.
# Deletion is the only side effect here — no logging convention of its
# own; summary.py derives everything from track.py's state log.
# Depends on: track.py, log() from lib/common.sh. Not meant to be run
# directly.

delete() {
  local url="$1"
  local result state_name state_int kind path note tag

  result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$url")
  IFS=$'\t' read -r state_name state_int kind path note <<< "$result"

  if [ "$state_name" != "VERIFIED" ]; then
    log "SKIP delete (state=$state_name, expected VERIFIED): $url"
    return
  fi

  rm -f "$url"
  python3 "$SCRIPT_DIR/lib/track.py" set "$url" DELETED "$kind" "$path" "$note"
}
