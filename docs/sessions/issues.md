# issues.md — archive project

## Resolved this session (2026-08-02)

**1. tmux server died mid-run on 2026-03 — still unexplained, now instrumented**
- Root cause never confirmed. Leading theory: OOM-kill of the tmux
  server under memory pressure from parallel video jobs, despite
  battery-unrestricted status.
- Fix isn't a root-cause fix — it's forensics. `set_state()` now fires
  every file in pass 1 with the current filename + load average, so a
  repeat crash leaves a breadcrumb instead of nothing. Won't confirm
  the cause until it happens again with this in place.

**2. "SKIP (missing on disk)" logged for files that still exist — mitigated, not explained**
- Original cause still unconfirmed (race condition / storage timing
  hiccup was the working theory).
- Added: retry-before-declaring-missing (checks twice, half a second
  apart) before committing to MISSING.
- Found and fixed a *related* bug during testing: a file that was
  correctly `DELETED` (successful full pipeline) was being misread as
  "missing" on a resumed run, because the existence check ran before
  the state check. Order fixed — state is checked first now, so a
  legitimately-deleted file is never re-examined for existence. This
  was a real, reproducible bug (not the original mystery, but adjacent
  and worth knowing was there).

**3. SKIP_RESUME fix — superseded by full rewrite**
- The specific bug (resume skipped verify+delete) can no longer occur
  structurally: the whole compress→verify→delete flow was rebuilt
  around explicit per-file state tracking (`track.py` / `state_log.tsv`),
  where each stage checks current state before acting. There's no more
  "resume path" to silently skip a step in — every run just asks "what
  state is this file in" and does the right next thing.

## New: found and fixed during the rewrite (2026-08-02)

- **Video/verify race condition** — caught before it shipped, not in
  production. Backgrounding compression without a barrier before
  verify would have let verify run on a still-compressing video file.
  Fixed with a `wait` barrier between the compress and verify passes.
- **Missing `source` lines** — `single_month_zipper.sh` was calling
  functions (`compressor_process()`, `verify()`, `delete()`) that were
  never sourced into its shell. Would have failed loudly at runtime
  ("command not found") the first time the new pipeline actually ran.
  Found while re-checking sourcing during a naming cleanup, fixed
  before any real run.
- **Dead code removed**: `lib/compress_one.sh` (superseded, never
  wired in), `file_log()` in `common.sh` (superseded by `summary.py`
  deriving `files.tsv` from `state_log.tsv` on demand instead of it
  being written incrementally).

## Resolved this session (2026-08-03)

**1. Never tested against a real on-device run — resolved for the base pipeline**
- On-device smoke test (6 disposable files, fake month `2099-01`) ran
  clean end-to-end: compress, verify, delete, zip, zip-verify, staging
  cleared. `track.py get` confirmed consistent with `files.tsv`.
- Caveat: everything built *after* the smoke test (see item 2 below)
  has not itself been run on-device yet.

**2. No final reconciliation pass — resolved, then hardened further**
- Built as planned: zip step now only includes `track.py`-confirmed
  `DELETED` files, not everything physically in the staging directory.
- While designing it, found a related real gap: a `FAILED` file's
  corrupt/partial staged output was never being cleaned out of staging
  by `delete.sh` (it only removes originals for `VERIFIED` files) — so
  it could have ridden into the zip under the old `zip -rq .` approach.
  Not just closing the requested gap, actually catching a bug that gap
  would have hidden.
- Extended into a three-way reconciliation using per-file `track.py`
  state (not filename-diffing): `STUCK` (never reached a terminal
  state), `GHOST` (state says `DELETED`, staged file physically gone —
  the state log lying), `ORPHAN` (physical file in staging, no
  confirmed `DELETED` entry backing it). Any of the three now pauses
  for a wait/cancel/skip decision (`ANOMALY_MODE`, prompted once at
  launch) instead of proceeding silently.
- This also structurally resolves the standing "check
  `archive_staging/2026-03` for partial old-pipeline output before
  re-running" caution note — leftover files there will now surface as
  `ORPHAN` automatically rather than needing a manual look first. Still
  worth eyeballing once, but no longer a hard blocker.

## Resolved this session (2026-08-06)

**1. Everything built after the 2026-08-03 smoke test — now on-device tested**
- Preflight checks, zip-list fix, `ANOMALY_MODE` prompting, and the
  three-way reconciliation check all fired correctly against real
  runs (`2026-04`, `2026-01`, `2026-03`). See item 2 below for the one
  real bug found along the way.
- `2026-03` specifically exercised the `ORPHAN` path against real
  leftover files from the old pre-rewrite pipeline, as anticipated in
  the 2026-08-03 notes — confirmed it correctly gated the zip instead
  of proceeding silently.

**2. Bare `wait` in `multi_file_pipeline.sh` deadlocked Pass 1 — fixed**
- `wait` with no arguments blocks on every background job in the
  shell, not just the video-compress jobs it was meant for. This
  included the `tee` process substitution `single_month_zipper.sh`
  uses for logging (`exec > >(tee -a "$RUN_LOG") 2>&1`), which never
  exits until the script's own stdout closes — a deadlock, reproduced
  even with 0 files to process (no video jobs spawned at all).
- Fixed by tracking video job PIDs explicitly in an array as they're
  backgrounded (and logging each one), then waiting only on those PIDs
  instead of a bare `wait`.
- Same underlying lesson as the `track.py` `note` field: bash gives no
  traceback when something blocks, so tracking state explicitly (here,
  PIDs; there, per-file state) is the only way to debug it after the
  fact instead of staring at silence.

## Resolved this session (2026-08-07)

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

**1. `2026-03` has 26 orphaned files from an abandoned pre-rewrite run**
- Reconciliation correctly flagged 28 `ORPHAN` files (2 of which were
  the separately-explained verify failures below). The remaining 26
  are `.webp`/`.mp4` outputs from an earlier, abandoned March run —
  staged 2026-07-31, three days before the current manifest was
  rebuilt (2026-08-03), so the manifest never knew about them.
  Originals no longer exist in `DCIM` — these are the only surviving
  copies. Chose `[c]ancel` over `[s]kip` since skip's exact behavior
  on untracked files was unverified and the data can't be re-shot.
- Next: verify not corrupted (`ffprobe -v error`), fold into the
  manifest, re-run to complete the month.
- Answered this session: the abandoned run predates `track.py`
  entirely (pre-rewrite pipeline had no state system yet), so nothing
  wrote a track/manifest entry at the time — not a bug in the current
  system, just a gap the current system correctly detects as `ORPHAN`
  but can't yet resolve on its own (see gap 4 below).
- Still open: fold the 24 confirmed-clean video orphans + all `.webp`
  orphans into the manifest and re-run `single_month_zipper.sh
  2026-03` to complete the month. The 2 corrupted orphans are resolved
  — see `bugQueue.md`.

**2. Two real `ffprobe` verify failures in `2026-03` — resolved, see `bugQueue.md`**

**3. Diagnostic tooling gap found investigating item 1 — fixed**
- The ad-hoc orphan status-dump script (staged/original/track/manifest
  per file) had a path bug for `.webp` originals: it reconstructed the
  original path by swapping the staged extension back onto the
  filename, but originals were `.jpg`/`.png`, not `.webp`, so it
  reported `original: MISSING` for nearly every webp regardless of
  whether that was actually true. Fixed and now saved and fixed at
  `tests/diagnostics/orphan_status.sh` (tries real candidate
  extensions for webp outputs) instead of living only in chat history
  as a one-off.

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
  parent dir) — parked until after the trust test.

## Status snapshot at handoff
- 2026-04: fully done (compressed, zipped, verified, staging cleared).
- 2026-01: fully done (compressed, zipped, verified, staging cleared) —
  212 files, ~6.4GB, ran clean end-to-end after the bare-`wait` fix.
- 2099-01 (test month, not real data): fully done, same as above —
  zip exists in `Archives/`. Its 6 source files are gone (correctly
  deleted); re-running it now tests `MISSING` handling, not a repeat
  smoke test.
- 2026-03: blocked, not crashed — pipeline ran correctly (2 verify
  failures handled safely, reconciliation caught 26 real orphans from
  an old abandoned run) but stopped short of zipping pending manual
  fold-in of those 26 files. See Open item 1.
- 2025-12, 2026-02: not started.
- Trust test result: 2 of 3 months (`2026-04`, `2026-01`) fully clean.
  `2026-03` is a pass for the tooling itself — reconciliation did
  exactly what it was built for — but the month is not yet complete.
  `multi_month_zipper.sh` unattended still pending full 3/3.
