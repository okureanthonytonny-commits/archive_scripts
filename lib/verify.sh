#!/data/data/com.termux/files/usr/bin/bash
# lib/verify.sh — checks a COMPRESSED output is actually valid, and
# transitions it to VERIFIED or FAILED. On failure, records exactly
# which gate rejected it, combined with any tool stderr already noted
# at compress time — this is the "why", not just "it failed".
# Depends on: track.py, log() from lib/common.sh. Not meant to be run directly.

verify_webp() {
  local out="$1"
  [ -s "$out" ] && dwebp "$out" -o /dev/null >/dev/null 2>&1
}

verify_video() {
  local out="$1"
  [ -s "$out" ] && ffprobe -v error -i "$out" -show_entries format=duration \
    -of default=noprint_wrappers=1 >/dev/null 2>&1
}

verify_copy() {
  local src="$1" dst="$2"
  [ -s "$dst" ] && [ "$(stat -c%s "$src")" = "$(stat -c%s "$dst")" ]
}

verify() {
  local url="$1"
  local result state_name state_int kind path prev_note ok reason note

  result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$url")
  IFS=$'\t' read -r state_name state_int kind path prev_note <<< "$result"

  if [ "$state_name" != "COMPRESSED" ]; then
    log "SKIP verify (state=$state_name, expected COMPRESSED): $url"
    return
  fi

  ok=0
  reason=""
  case "$kind" in
    webp)  verify_webp "$path" && ok=1 || reason="dwebp decode check failed" ;;
    video) verify_video "$path" && ok=1 || reason="ffprobe duration check failed" ;;
    copy)  verify_copy "$url" "$path" && ok=1 || reason="size mismatch: original vs staged" ;;
    *)     reason="unknown kind '$kind'" ;;
  esac

  if [ "$ok" = "1" ]; then
    python3 "$SCRIPT_DIR/lib/track.py" set "$url" VERIFIED "$kind" "$path" "$prev_note"
  else
    note="${prev_note:+$prev_note | }$reason"
    log "VERIFY FAILED ($kind): $url — $note"
    python3 "$SCRIPT_DIR/lib/track.py" set "$url" FAILED "$kind" "$path" "$note"
  fi
}

# verify_orphan() — same gates as verify(), but for a staged file with no
# track.py entry (a reconciliation orphan). url/kind/path are passed in
# explicitly (nothing to read from state), and the terminal state is
# written directly: VERIFIED folds the file into the zip list, FAILED
# records the reason and lets the retry-with-guard logic handle it on a
# later run. Called from lib/orphan_reconcile.sh.
verify_orphan() {
  local url="$1" kind="$2" path="$3"
  local ok=0 reason=""

  case "$kind" in
    webp)  verify_webp "$path" && ok=1 || reason="dwebp decode check failed" ;;
    video) verify_video "$path" && ok=1 || reason="ffprobe duration check failed" ;;
    copy)  if [ ! -f "$url" ]; then
             reason="original not found on disk"
           else
             verify_copy "$url" "$path" && ok=1 || reason="size mismatch: original vs staged"
           fi ;;
    *)     reason="unknown kind '$kind'" ;;
  esac

  if [ "$ok" = "1" ]; then
    python3 "$SCRIPT_DIR/lib/track.py" set "$url" VERIFIED "$kind" "$path" ""
    return 0
  else
    _ORPHAN_VERIFY_REASON="$reason"
    python3 "$SCRIPT_DIR/lib/track.py" set "$url" FAILED "$kind" "$path" "$reason"
    return 1
  fi
}
