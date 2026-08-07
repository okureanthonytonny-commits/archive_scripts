#!/data/data/com.termux/files/usr/bin/bash
# lib/common.sh — shared config, logging, and disk-safety functions.
# Sourced by single_month_zipper.sh (and indirectly by multi_month_zipper.sh).
# Not meant to be run directly.

MANIFEST="$HOME/archive_manifest.tsv"
STAGING="$HOME/archive_staging"
ARCHIVES_DIR="/storage/emulated/0/Archives"
LOG_DIR="$HOME/archive_logs"
MAX_PARALLEL_VIDEO=2
MIN_FREE_MB=800
STATE_FILE="$HOME/archive_scripts/.state"

mkdir -p "$ARCHIVES_DIR" "$LOG_DIR" "$HOME/.archive_tmp"

declare -A MONTH_NAMES=(
  [01]="January" [02]="February" [03]="March" [04]="April"
  [05]="May" [06]="June" [07]="July" [08]="August"
  [09]="September" [10]="October" [11]="November" [12]="December"
)

month_to_zipname() {
  local ym="$1"
  local year="${ym%-*}"
  local mon="${ym#*-}"
  echo "${MONTH_NAMES[$mon]}-${year}.zip"
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

set_state() {
  echo "$(date '+%Y-%m-%dT%H:%M:%S')  $*" > "$STATE_FILE"
}

check_space() {
  local free_mb
  free_mb=$(df -k /storage/emulated/0 | awk 'NR==2{print int($4/1024)}')
  if [ "$free_mb" -lt "$MIN_FREE_MB" ]; then
    log "LOW DISK SPACE: only ${free_mb}MB free (threshold ${MIN_FREE_MB}MB)."
    log "Aborting safely — progress so far is preserved, nothing corrupted."
    log "Free up space, then re-run to resume."
    exit 2
  fi
}

check_space_for_zip() {
  local stage_dir="$1"
  local stage_mb free_mb needed_mb
  stage_mb=$(du -sm "$stage_dir" | cut -f1)
  free_mb=$(df -k /storage/emulated/0 | awk 'NR==2{print int($4/1024)}')
  needed_mb=$((stage_mb + 200))
  if [ "$free_mb" -lt "$needed_mb" ]; then
    log "LOW DISK SPACE before zipping: staging is ${stage_mb}MB, only ${free_mb}MB free (need ~${needed_mb}MB)."
    log "Aborting before zip — originals and staging both preserved, nothing lost."
    exit 2
  fi
}
