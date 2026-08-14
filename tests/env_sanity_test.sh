#!/data/data/com.termux/files/usr/bin/bash
# tests/env_sanity_test.sh -- interactive .env/--exclude sanity test against
# real device paths and real directories. Read-only against your real data:
# only writes to a throwaway manifest (tests/sanity_manifest.tsv) and a
# throwaway test .env, both cleaned up / restored automatically. Never
# touches ~/archive_manifest.tsv or a real .env you may already have.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
cd "$SCRIPT_DIR"

DUMMY_MANIFEST="tests/sanity_manifest.tsv"
TEST_ENV="tests/.env.sanity"

echo "=== env/--exclude sanity test ==="
echo "This will NOT touch your real .env or archive_manifest.tsv."
echo "All output goes to $DUMMY_MANIFEST (throwaway)."
echo

echo "Enter your real source directories, one per line (up to 4). Blank line to stop."
DIRS=()
while [ "${#DIRS[@]}" -lt 4 ]; do
  read -r -p "Dir $(( ${#DIRS[@]} + 1 )) (e.g. /storage/emulated/0/DCIM/Camera or ~/storage/dcim/Camera): " d
  [ -z "$d" ] && break
  d="${d/#\~/$HOME}"
  if [ ! -d "$d" ]; then
    echo "  WARNING: '$d' is not a directory (skipping)"
    continue
  fi
  DIRS+=("$d")
done

if [ "${#DIRS[@]}" -eq 0 ]; then
  echo "No valid directories given. Aborting."
  exit 1
fi

echo
echo "Directories collected: ${DIRS[*]}"
echo

read -r -p "Enter a subfolder to test --exclude against (e.g. /storage/emulated/0/DCIM/Camera/WhatsApp or ~/storage/dcim/Camera/WhatsApp): " EXCLUDE_TARGET
EXCLUDE_TARGET="${EXCLUDE_TARGET/#\~/$HOME}"
if [ ! -d "$EXCLUDE_TARGET" ]; then
  echo "WARNING: '$EXCLUDE_TARGET' is not a directory -- exclude tests will likely show 0 matches."
fi

EXCLUDE_REL="$EXCLUDE_TARGET"
EXCLUDE_ABS=$(realpath "$EXCLUDE_TARGET" 2>/dev/null || echo "$EXCLUDE_TARGET")

echo
echo "Include dirs: ${DIRS[*]}"
echo "Exclude target: $EXCLUDE_TARGET (abs: $EXCLUDE_ABS)"
read -r -p "Press Enter to start, or Ctrl+C to cancel..." _

reset_manifest() {
  rm -f "$DUMMY_MANIFEST"
}

run_case() {
  local label="$1"; shift
  echo
  echo "----- $label -----"
  ./build_manifest.sh -o "$DUMMY_MANIFEST" "$@"
}

# Case 1: positional dirs, no .env involved at all
reset_manifest
run_case "1: positional dirs, no .env involved" "${DIRS[@]}"

# Case 2: INCLUDE_DIRS / EXCLUDE_DIRS via a throwaway .env (backs up any real one)
reset_manifest
{
  echo "INCLUDE_DIRS=\"${DIRS[*]}\""
  echo "EXCLUDE_DIRS=\"$EXCLUDE_ABS\""
} > "$TEST_ENV"

REAL_ENV_BACKED_UP=0
if [ -f .env ]; then
  mv .env .env.sanity_backup
  REAL_ENV_BACKED_UP=1
fi
cp "$TEST_ENV" .env

run_case "2: no args, INCLUDE_DIRS from test .env"

# Case 3: positional override -- should ignore INCLUDE_DIRS, only scan dir 1
reset_manifest
run_case "3: positional override (dir 1 only)" "${DIRS[0]}"

# Case 4: --exclude relative form
reset_manifest
run_case "4: --exclude relative" "${DIRS[@]}" --exclude "$EXCLUDE_REL"

# Case 5: --exclude absolute form -- should match case 4 exactly
reset_manifest
run_case "5: --exclude absolute" "${DIRS[@]}" --exclude "$EXCLUDE_ABS"

# Case 6: EXCLUDE_DIRS from .env alone, no --exclude flag
reset_manifest
run_case "6: EXCLUDE_DIRS from .env alone"

# Case 7: EXCLUDE_DIRS (.env) + --exclude (flag) combined on the same run
reset_manifest
run_case "7: EXCLUDE_DIRS (.env) + --exclude (flag) combined" --exclude "$EXCLUDE_REL"

# Case 8: dedup / idempotency -- rerun immediately without resetting
run_case "8: rerun immediately (dedup check, no reset)"

# Restore whatever .env setup existed before this script ran
rm -f .env
[ "$REAL_ENV_BACKED_UP" -eq 1 ] && mv .env.sanity_backup .env
rm -f "$TEST_ENV"

echo
echo "===== Case 9: manifest sanity check ====="
echo "Rows in $DUMMY_MANIFEST: $(wc -l < "$DUMMY_MANIFEST" 2>/dev/null || echo 0)"
echo "First 10 rows:"
column -t -s $'\t' "$DUMMY_MANIFEST" 2>/dev/null | head -10

echo
echo "Any excluded path leaked through?"
if grep -F "$EXCLUDE_ABS" "$DUMMY_MANIFEST" >/dev/null 2>&1; then
  echo "  FAIL -- found excluded path(s) in manifest:"
  grep -F "$EXCLUDE_ABS" "$DUMMY_MANIFEST"
else
  echo "  OK -- no excluded paths found"
fi

echo
echo "Done. Dummy manifest kept at $DUMMY_MANIFEST for inspection -- delete manually when done:"
echo "  rm $DUMMY_MANIFEST"
