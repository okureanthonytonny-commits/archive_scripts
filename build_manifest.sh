#!/data/data/com.termux/files/usr/bin/bash
# build_manifest.sh -- scan directories, (re)build/extend archive_manifest.tsv. See docs/architecture.md.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

OUTPUT="./archive_manifest.tsv"
MIN_AGE_DAYS=0
EXCLUDE_ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) OUTPUT="$2"; shift 2 ;;
    -a) MIN_AGE_DAYS="$2"; shift 2 ;;
    --exclude) EXCLUDE_ARGS+=("$2"); shift 2 ;;
    --) shift; break ;;
    -*) echo "Usage: $0 [-o OUTPUT] [-a MIN_AGE_DAYS] [--exclude PATH ...] [DIR [DIR2 ...]]" >&2; exit 1 ;;
    *) break ;;
  esac
done

DIRS=("$@")
if [ "${#DIRS[@]}" -eq 0 ]; then
  read -r -a DIRS <<< "${INCLUDE_DIRS:-}"
fi

if [ "${#DIRS[@]}" -eq 0 ]; then
  echo "Usage: $0 [-o OUTPUT] [-a MIN_AGE_DAYS] [--exclude PATH ...] [DIR [DIR2 ...]]" >&2
  echo "No directories given and INCLUDE_DIRS is not set in .env." >&2
  exit 1
fi

read -r -a ENV_EXCLUDES <<< "${EXCLUDE_DIRS:-}"
EXCLUDES=("${EXCLUDE_ARGS[@]}" "${ENV_EXCLUDES[@]}")

for d in "${DIRS[@]}"; do
  if [ ! -d "$d" ]; then
    echo "ERROR: not a directory: $d" >&2
    exit 2
  fi
done

# Resolve dirs and excludes to absolute paths so prefix matching (and
# dedup against the manifest) is consistent regardless of whether the
# caller passed relative or absolute paths.
for i in "${!DIRS[@]}"; do
  DIRS[$i]=$(realpath "${DIRS[$i]}")
done
for i in "${!EXCLUDES[@]}"; do
  [ -n "${EXCLUDES[$i]}" ] && EXCLUDES[$i]=$(realpath "${EXCLUDES[$i]}" 2>/dev/null || echo "${EXCLUDES[$i]}")
done

touch "$OUTPUT" || { echo "ERROR: cannot write to $OUTPUT" >&2; exit 1; }

NOW_EPOCH=$(date +%s)
MIN_AGE_SECONDS=$((MIN_AGE_DAYS * 86400))

ADDED=0
SKIPPED_DUP=0
SKIPPED_AGE=0
SKIPPED_EXCLUDE=0

EXISTING_PATHS_FILE=$(mktemp)
cut -f3 "$OUTPUT" > "$EXISTING_PATHS_FILE" 2>/dev/null || true

TMP_OUT=$(mktemp)

is_excluded() {
  local filepath="$1"
  local ex
  for ex in "${EXCLUDES[@]}"; do
    [ -n "$ex" ] || continue
    case "$filepath" in
      "$ex"*) return 0 ;;
    esac
  done
  return 1
}

for dir in "${DIRS[@]}"; do
  find "$dir" -type f | while IFS= read -r filepath; do
    if is_excluded "$filepath"; then
      echo "EXCLUDE" >> "${TMP_OUT}.excludecount"
      continue
    fi

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
if [ -f "${TMP_OUT}.excludecount" ]; then
  SKIPPED_EXCLUDE=$(wc -l < "${TMP_OUT}.excludecount" | tr -d ' ')
else
  SKIPPED_EXCLUDE=0
fi

cat "$TMP_OUT" >> "$OUTPUT"
rm -f "$TMP_OUT" "${TMP_OUT}.dupcount" "${TMP_OUT}.agecount" "${TMP_OUT}.excludecount" "$EXISTING_PATHS_FILE"

echo "=== build_manifest.sh run summary ($(date '+%Y-%m-%d %H:%M:%S')) ==="
echo "Scanned dirs:     ${DIRS[*]}"
echo "Excluded paths:   ${EXCLUDES[*]:-none}"
echo "Min age filter:   ${MIN_AGE_DAYS} day(s) (0 = no filter)"
echo "Manifest file:    $OUTPUT"
echo "Added:            $ADDED new row(s)"
echo "Skipped (dup):    $SKIPPED_DUP -- path already in $OUTPUT, not re-added"
echo "Skipped (age):    $SKIPPED_AGE -- mtime newer than the ${MIN_AGE_DAYS}-day cutoff"
echo "Skipped (exclude):$SKIPPED_EXCLUDE -- matched an --exclude/EXCLUDE_DIRS path prefix"
echo "Total rows now:   $(wc -l < "$OUTPUT" | tr -d ' ') in $OUTPUT"
