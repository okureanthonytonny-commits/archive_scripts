#!/data/data/com.termux/files/usr/bin/bash
#
# build_manifest.sh — scan directories, (re)build/extend archive_manifest.tsv.
# Usage: build_manifest.sh [-o OUTPUT] [-a MIN_AGE_DAYS] DIR [DIR2 ...]
# See docs/architecture.md for format, options, and exit codes.

set -uo pipefail

OUTPUT="./archive_manifest.tsv"
MIN_AGE_DAYS=0

while getopts "o:a:" opt; do
  case "$opt" in
    o) OUTPUT="$OPTARG" ;;
    a) MIN_AGE_DAYS="$OPTARG" ;;
    *) echo "Usage: $0 [-o OUTPUT] [-a MIN_AGE_DAYS] DIR [DIR2 ...]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 [-o OUTPUT] [-a MIN_AGE_DAYS] DIR [DIR2 ...]" >&2
  exit 1
fi

for d in "$@"; do
  if [ ! -d "$d" ]; then
    echo "ERROR: not a directory: $d" >&2
    exit 2
  fi
done

touch "$OUTPUT" || { echo "ERROR: cannot write to $OUTPUT" >&2; exit 1; }

NOW_EPOCH=$(date +%s)
MIN_AGE_SECONDS=$((MIN_AGE_DAYS * 86400))

ADDED=0
SKIPPED_DUP=0
SKIPPED_AGE=0

# Build a lookup of paths already in the manifest, for idempotency.
EXISTING_PATHS_FILE=$(mktemp)
cut -f3 "$OUTPUT" > "$EXISTING_PATHS_FILE" 2>/dev/null || true

TMP_OUT=$(mktemp)

for dir in "$@"; do
  find "$dir" -type f | while IFS= read -r filepath; do
    # Skip if already recorded (idempotent re-run).
    if grep -qxF "$filepath" "$EXISTING_PATHS_FILE"; then
      echo "DUP" >> "${TMP_OUT}.dupcount"
      continue
    fi

    mtime_epoch=$(stat -c '%Y' "$filepath" 2>/dev/null) || continue
    size_bytes=$(stat -c '%s' "$filepath" 2>/dev/null) || continue

    if [ "$MIN_AGE_SECONDS" -gt 0 ]; then
      age=$((NOW_EPOCH - mtime_epoch))
      if [ "$age" -lt "$MIN_AGE_SECONDS" ]; then
        echo "AGE" >> "${TMP_OUT}.agecount"
        continue
      fi
    fi

    basename_f=$(basename "$filepath")
    if [[ "$basename_f" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_ ]]; then
      month="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    else
      month=$(date -d "@$mtime_epoch" +%Y-%m 2>/dev/null || date -r "$mtime_epoch" +%Y-%m)
    fi

    printf '%s\t%s\t%s\n' "$month" "$size_bytes" "$filepath" >> "$TMP_OUT"
  done
done

ADDED=$(wc -l < "$TMP_OUT" | tr -d ' ')
if [ -f "${TMP_OUT}.dupcount" ]; then
  SKIPPED_DUP=$(wc -l < "${TMP_OUT}.dupcount" | tr -d ' ')
else
  SKIPPED_DUP=0
fi
if [ -f "${TMP_OUT}.agecount" ]; then
  SKIPPED_AGE=$(wc -l < "${TMP_OUT}.agecount" | tr -d ' ')
else
  SKIPPED_AGE=0
fi

cat "$TMP_OUT" >> "$OUTPUT"
rm -f "$TMP_OUT" "${TMP_OUT}.dupcount" "${TMP_OUT}.agecount" "$EXISTING_PATHS_FILE"

echo "=== build_manifest.sh run summary ($(date '+%Y-%m-%d %H:%M:%S')) ==="
echo "Scanned dirs:     $*"
echo "Min age filter:   ${MIN_AGE_DAYS} day(s) (0 = no filter)"
echo "Manifest file:    $OUTPUT"
echo "Added:            $ADDED new row(s)"
echo "Skipped (dup):    $SKIPPED_DUP -- path already in $OUTPUT, not re-added"
echo "Skipped (age):    $SKIPPED_AGE -- mtime newer than the ${MIN_AGE_DAYS}-day cutoff"
echo "Total rows now:   $(wc -l < "$OUTPUT" | tr -d ' ') in $OUTPUT"
