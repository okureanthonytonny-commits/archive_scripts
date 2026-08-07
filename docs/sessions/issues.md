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
- Related open question: how an abandoned run leaves staging populated
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
