import sys

path = "lib/multi_file_pipeline.sh"
with open(path) as f:
    content = f.read()

marker = "# --- Pass 1: compress ---"
if "RETRY_MAX" in content:
    print("SKIPPED: retry logic already present")
    sys.exit(0)

old = '''    result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$f")
    IFS=$'\\t' read -r state_name state_int kind path note <<< "$result"
    case "$state_name" in
      PENDING|COMPRESSED) ;;
      *) continue ;;
    esac'''

new = '''    result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$f")
    IFS=$'\\t' read -r state_name state_int kind path note <<< "$result"
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
    esac'''

if old not in content:
    print("ABORT: Pass 1 state-check block not found — file may have changed")
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("WRITTEN")
