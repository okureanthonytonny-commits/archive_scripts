#!/data/data/com.termux/files/usr/bin/bash
# lib/multi_file_pipeline.sh — orchestration only. No compression, verification,
# or deletion logic lives here — it dispatches to single_file_compressor.sh,
# verify.sh, and delete.sh, using track.py as the single source of truth
# for what still needs doing. Three passes, one hard barrier between
# compress and verify so a backgrounded video job can never be
# verified/deleted before it's actually finished.
# Depends on: log(), set_state(), check_space(), $MAX_PARALLEL_VIDEO from
# lib/common.sh; compressor_process(), verify(), delete() from
# lib/single_file_compressor.sh, lib/verify.sh, lib/delete.sh (all must
# be sourced first). Not meant to be run directly.

process_month() {
  local filelist="$1"
  local month_stage="$2"
  local total f base ext ext_lower
  local result state_name state_int kind path note attempts
  local video_jobs=0
  local video_pids=()
  local count=0

  total=$(wc -l < "$filelist")
  log "$total files to process"

  # --- Pass 1: compress ---
  log "--- Pass 1: compress ---"
  while IFS= read -r f; do
    check_space
    set_state "compress: $f (load:$(uptime | awk -F'load average:' '{print $2}'))"

    # State check FIRST. A DELETED/VERIFIED/FAILED/MISSING file is already
    # resolved — for DELETED specifically, the original being absent is
    # correct and expected, not a new problem to detect.
    result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$f")
    IFS=$'\t' read -r state_name state_int kind path note <<< "$result"
    case "$state_name" in
      PENDING|COMPRESSED) ;;
      FAILED)
        attempts=$(python3 "$SCRIPT_DIR/lib/track.py" count "$f" FAILED)
        if [ "$attempts" -ge "${RETRY_MAX:-2}" ]; then
          log "SKIP (retry exhausted, $attempts/${RETRY_MAX:-2} FAILED attempts): $f"
          continue
        fi
        log "RETRY ($attempts/${RETRY_MAX:-2} prior FAILED attempts) — clearing stale output: $f"
        [ -n "$path" ] && [ -f "$path" ] && rm -f "$path"
        ;;
      *) continue ;;
    esac

    # Only a PENDING/COMPRESSED file's original SHOULD still be on disk —
    # existence is only meaningful to check here.
    if [ ! -f "$f" ]; then
      sleep 0.5
      if [ ! -f "$f" ]; then
        log "SKIP (missing on disk): $f"
        python3 "$SCRIPT_DIR/lib/track.py" set "$f" MISSING "" "" "retry exhausted"
        continue
      fi
      log "TRANSIENT: $f was missing on first check, present on retry"
    fi

    count=$((count+1))
    base="$(basename "$f")"
    ext="${base##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    if [[ "$ext_lower" == "mp4" || "$ext_lower" == "mov" ]]; then
      compressor_process "$f" "$month_stage" &
      video_pids+=("$!")
      log "backgrounded video compress: $f (PID $!)"
      video_jobs=$((video_jobs+1))
      if [ "$video_jobs" -ge "$MAX_PARALLEL_VIDEO" ]; then
        wait -n
        video_jobs=$((video_jobs-1))
      fi
    else
      compressor_process "$f" "$month_stage"
    fi

    if [ $((count % 50)) -eq 0 ]; then
      log "...compress progress: $count/$total"
    fi
  done < "$filelist"

  for pid in "${video_pids[@]}"; do
    kill -0 "$pid" 2>/dev/null && wait "$pid"
  done
  log "Pass 1 complete."

  # --- Pass 2: verify ---
  log "--- Pass 2: verify ---"
  while IFS= read -r f; do
    verify "$f"
  done < "$filelist"
  log "Pass 2 complete."

  # --- Pass 3: delete ---
  log "--- Pass 3: delete ---"
  while IFS= read -r f; do
    delete "$f"
  done < "$filelist"
  log "Pass 3 complete."

  log "All files processed."
}
