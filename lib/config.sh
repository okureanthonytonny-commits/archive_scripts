#!/data/data/com.termux/files/usr/bin/bash
# lib/config.sh -- reads .env, exports every pipeline config variable with its fallback default.

[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

export MANIFEST="${MANIFEST:-$HOME/archive_manifest.tsv}"
export STAGING="${STAGING:-$HOME/archive_staging}"
export ARCHIVES_DIR="${ARCHIVES_DIR:-/storage/emulated/0/Archives}"
export LOG_DIR="${LOG_DIR:-$HOME/archive_logs}"
export MAX_PARALLEL_VIDEO="${MAX_PARALLEL_VIDEO:-2}"
export MAX_PARALLEL_VERIFY="${MAX_PARALLEL_VERIFY:-4}"
export MIN_FREE_MB="${MIN_FREE_MB:-800}"
export STATE_FILE="${STATE_FILE:-$HOME/archive_scripts/.state}"
export STATE_LOG="${STATE_LOG:-$HOME/archive_scripts/.state_log.tsv}"
export INCLUDE_DIRS="${INCLUDE_DIRS:-}"
export EXCLUDE_DIRS="${EXCLUDE_DIRS:-}"
