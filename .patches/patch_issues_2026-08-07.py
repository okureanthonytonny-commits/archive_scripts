import sys

path = "docs/sessions/issues.md"
with open(path) as f:
    content = f.read()

changed_any = False

# --- Edit 1: insert "Resolved this session (2026-08-07)" block ---
new_frag_1 = "## Resolved this session (2026-08-07)"
if new_frag_1 in content:
    print("SKIPPED (resolved-2026-08-07 section already present)")
else:
    old_1 = "## Open\n\n**1. `2026-03` has 26 orphaned files from an abandoned pre-rewrite run**"
    new_1 = '''## Resolved this session (2026-08-07)

**1. No automatic retry on `FAILED` — resolved**
- Added `track.py count <url> <STATE>` — an append-only log scan, no
  schema change, giving a real attempt count per file/state without
  inventing new tracking machinery.
- Extended Pass 1's state-check in `multi_file_pipeline.sh`: a
  `FAILED` file with attempts under `RETRY_MAX` (default 2) has its
  stale staged output deleted and falls through to reprocess like
  `PENDING`; at/over the cap it's skipped with a clear log line
  instead of looping forever. Deleting the stale output first turned
  out to be load-bearing, not just tidy — `compressor_process()` only
  recompresses `if [ ! -s "$out" ]`, so a leftover broken file would
  otherwise be silently treated as already-done.
- Validated against real fixture data, not synthetic cases: the two
  `bugQueue.md` `ffprobe` failures were seeded as genuine `FAILED`
  entries (via `verify()` on their real broken staged output, isolated
  against a test `STATE_LOG` — see gap 3 below), then run through the
  new retry path end-to-end: retry fired, recompressed clean from the
  real source, re-verified, reached `VERIFIED`. Same fix then applied
  to production `track.py` to actually close out the two files.
- Broken staged originals preserved at
  `tests/fixtures/moov-atom-missing/` before the fix touched them, as
  a permanent regression fixture for this failure class.

**2. Git adopted**
- Project had grown well past the "3 simple scripts" scope it started
  as without version control. `git init`, baseline commit of current
  state (not a clean v1 — captures the mid-build snapshot as the
  starting point), pushed to GitHub.
- `.gitignore` excludes runtime state (`.state`, `.state_log.tsv`) and
  binary media fixtures — code and docs only in history.

## Open

**1. `2026-03` has 26 orphaned files from an abandoned pre-rewrite run**'''
    if old_1 not in content:
        print("ABORT (issues.md edit 1: resolved-section insert): old text not found")
        sys.exit(1)
    content = content.replace(old_1, new_1)
    changed_any = True
    print("WRITTEN (issues.md: added Resolved-2026-08-07 section)")

# --- Edit 2: update item 1, remove old item 2/3, add new item 3/4 ---
new_frag_2 = "**3. Diagnostic tooling gap found investigating item 1**"
if new_frag_2 in content:
    print("SKIPPED (item 1 update / new gaps 3-4 already present)")
else:
    old_2 = '''- Related open question: how an abandoned run leaves staging populated
  without ever touching the manifest — worth understanding so a
  stale-staging-vs-manifest mismatch doesn't recur silently.

**2. Two real `ffprobe` verify failures in `2026-03` — now tracked in `bugQueue.md`**
- Handled correctly by the pipeline (state `FAILED`, originals
  preserved) — see `bugQueue.md` for the open root-cause item.

**3. Deferred gaps (see `ideas.md` and `architecture.md` for reasoning)**
- No automatic retry on `FAILED`.
- No size-ratio sanity check before delete (verify confirms the output
  decodes, not that it actually shrank meaningfully).
- Duplicated tmux/wake-lock relaunch logic between the two entry
  scripts — works, just not shared.
- File-hash integrity checking for scripts, deferred to open-source
  prep (see `ideas.md`).
- Storage reorg (`archive_*` files out of `$HOME` into a dedicated
  parent dir) — parked until after the trust test.'''
    new_2 = '''- Answered this session: the abandoned run predates `track.py`
  entirely (pre-rewrite pipeline had no state system yet), so nothing
  wrote a track/manifest entry at the time — not a bug in the current
  system, just a gap the current system correctly detects as `ORPHAN`
  but can't yet resolve on its own (see gap 4 below).
- Still open: fold the 24 confirmed-clean video orphans + all `.webp`
  orphans into the manifest and re-run `single_month_zipper.sh
  2026-03` to complete the month. The 2 corrupted orphans are resolved
  — see `bugQueue.md`.

**2. Two real `ffprobe` verify failures in `2026-03` — resolved, see `bugQueue.md`**

**3. Diagnostic tooling gap found investigating item 1**
- The ad-hoc orphan status-dump script (staged/original/track/manifest
  per file) has a path bug for `.webp` originals: it reconstructs the
  original path by swapping the staged extension back onto the
  filename, but originals were `.jpg`/`.png`, not `.webp`, so it
  reports `original: MISSING` for nearly every webp regardless of
  whether that's actually true. Not fixed — was a one-off diagnostic,
  not a pipeline component — but worth remembering before trusting its
  webp output at face value if reused.

**4. Deferred gaps (see `ideas.md` and `architecture.md` for reasoning)**
- Orphan enumeration through `verify()` — reconciliation currently
  only *counts* orphans (`ORPHAN_COUNT = STAGE_PHYSICAL_COUNT -
  ZIP_COUNT`), it never identifies which files or checks their
  integrity. This is exactly why the 2 corrupted `2026-03` orphans
  needed a manual `ffprobe` sweep to find instead of being flagged
  automatically. Fix: have reconciliation enumerate orphans and run
  each through the real `verify()` — a `VERIFIED` orphan folds
  straight into the zip list, a `FAILED` orphan falls into the same
  retry-with-guard logic now built for gap 1 above. One mechanism, two
  discovery paths. Not done this session — scoped as the logical next
  step after retry-on-`FAILED` proved out.
- `.env` for hardcoded paths and config — paths (manifest, staging
  dir, archives dir, `STATE_LOG` default) and Termux-specific shebangs
  are hardcoded across `common.sh`, `track.py`, and the entry scripts.
  Fine single-device/single-user today; surfaced concretely this
  session when both `STATE_LOG` and `SCRIPT_DIR` being unexported in a
  fresh shell caused confusing failures (wrong-file reads, "command
  not found") with no signal pointing at the real cause. Related to
  the file-hash-integrity item below — both are "assumes single
  trusted environment" gaps, worth doing together before any
  open-source push.
- No size-ratio sanity check before delete (verify confirms the output
  decodes, not that it actually shrank meaningfully).
- Duplicated tmux/wake-lock relaunch logic between the two entry
  scripts — works, just not shared.
- File-hash integrity checking for scripts, deferred to open-source
  prep (see `ideas.md`).
- Storage reorg (`archive_*` files out of `$HOME` into a dedicated
  parent dir) — parked until after the trust test.'''
    if old_2 not in content:
        print("ABORT (issues.md edit 2: item 1 update / gaps 3-4): old text not found")
        sys.exit(1)
    content = content.replace(old_2, new_2)
    changed_any = True
    print("WRITTEN (issues.md: item 1 updated, item 2 resolved, new gaps 3-4 added)")

if changed_any:
    with open(path, "w") as f:
        f.write(content)
