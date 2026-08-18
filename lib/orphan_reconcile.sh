#!/data/data/com.termux/files/usr/bin/bash
# lib/orphan_reconcile.sh — orphan enumeration + reconciliation for the
# pre-zip stage check. Scans every physical file in the month's staging
# dir that isn't backed by a confirmed DELETED entry in the zip list,
# reconstructs its original url + kind, and runs each through
# verify_orphan(): a VERIFIED orphan folds straight into the zip list, a
# FAILED orphan gets a tracked FAILED state with a reason and falls into
# Pass 1's retry-with-guard on a later run (recompress if the original
# still exists, MISSING if it's gone), capped by RETRY_MAX like every
# other FAILED file. One mechanism, two discovery paths — see
# docs/sessions/issues.md open item 4.
# Depends on: log() from lib/common.sh; verify_orphan() from
# lib/verify.sh; python3 lib/track.py (by path) — all must be sourced
# first. Not meant to be run directly.

# Reconstruct the original url for a staged output file. Staged layout
# mirrors the original's relpath under /storage/emulated/0, except
# images compress to .webp (extension swapped), so a .webp staged file
# is ambiguous: try the real original on disk first, then the manifest
# (fold-in urls), then fall back to the default .jpg guess used by the
# 2026-08-08 2026-03 fold-in.
_orphan_derive_url() {
  local staged="$1" stage_dir="$2" manifest="$3"
  local rel reldir base base_noext ext_lower cand
  rel="${staged#"$stage_dir"/}"
  reldir="$(dirname "$rel")"
  base="$(basename "$rel")"
  base_noext="${base%.*}"
  ext_lower=$(echo "${base##*.}" | tr '[:upper:]' '[:lower:]')

  if [ "$ext_lower" = "webp" ]; then
    for cand_ext in jpg jpeg JPG JPEG png PNG; do
      cand="/storage/emulated/0/$reldir/$base_noext.$cand_ext"
      [ -f "$cand" ] && { echo "$cand"; return 0; }
    done
    for cand_ext in jpg jpeg JPG JPEG png PNG; do
      cand="/storage/emulated/0/$reldir/$base_noext.$cand_ext"
      grep -qF -- "$cand" "$manifest" 2>/dev/null && { echo "$cand"; return 0; }
    done
    echo "/storage/emulated/0/$reldir/$base_noext.jpg"
  else
    echo "/storage/emulated/0/$rel"
  fi
}

# Scan staging, fold verified orphans into the zip list, track FAILED
# ones. Returns 0; only logs. The caller's STUCK/GHOST/ORPHAN anomaly
# gate still decides what to do with whatever this leaves unresolved.
reconcile_orphans() {
  local month_stage="$1" zip_filelist="$2" manifest="${3:-$MANIFEST}"
  local max_retry="${RETRY_MAX:-2}"
  local recovered=0 failed=0 exhausted=0
  local staged_path rel url kind ext_lower attempts

  while IFS= read -r -d '' staged_path; do
    rel="${staged_path#"$month_stage"/}"
    grep -qxF "$rel" "$zip_filelist" && continue

    url="$(_orphan_derive_url "$staged_path" "$month_stage" "$manifest")"
    ext_lower=$(echo "${staged_path##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext_lower" in
      webp)      kind="webp" ;;
      mp4|mov)   kind="video" ;;
      *)         kind="copy" ;;
    esac

    attempts=$(python3 "$SCRIPT_DIR/lib/track.py" count "$url" FAILED)
    if [ "$attempts" -ge "$max_retry" ]; then
      log "ORPHAN FAILED (retry exhausted, $attempts/$max_retry FAILED attempts — left out of zip, needs manual look): $rel"
      exhausted=$((exhausted + 1))
      continue
    fi

    if verify_orphan "$url" "$kind" "$staged_path"; then
      echo "$rel" >> "$zip_filelist"
      log "ORPHAN RECOVERED (verified, folded into zip): $rel"
      recovered=$((recovered + 1))
    else
      log "ORPHAN VERIFY FAILED ($kind, attempt $((attempts + 1))/$max_retry — ${_ORPHAN_VERIFY_REASON:-failed}; left out of zip, retried on next run): $rel"
      failed=$((failed + 1))
    fi
  done < <(find "$month_stage" -type f -print0)

  if [ "$recovered" -gt 0 ] || [ "$failed" -gt 0 ] || [ "$exhausted" -gt 0 ]; then
    log "Orphan reconcile: $recovered recovered, $failed failed, $exhausted retry-exhausted."
  fi
}