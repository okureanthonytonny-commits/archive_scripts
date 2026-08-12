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

## Resolved this session (2026-08-08)

**1. `2026-03` orphan fold-in — resolved**
- `orphan_status.sh` gave per-file ground truth, correcting the prior
  session's count: only 3 of 26 flagged files were true orphans (no
  original, no manifest row); the other 2 still had real originals in
  `DCIM` and were `VERIFIED`, not orphaned — those resolve normally via
  Pass 3, not a manual write.
- The real orphan set was 75 files (72 `.webp` + 3 `.mp4`, not 26) —
  integrity-checked clean, folded into `archive_manifest.tsv` and
  `track.py` (`DELETED` state). Verified independently after:
  `PASS=75 FAIL=0`.
- `2026-03` is unblocked. Next `single_month_zipper.sh 2026-03` run
  completes the month.

## Resolved this session (2026-08-09)

**1. `2026-03` completed — 3/3 trust test**
- Confirmed the 2 pending mp4s (`20260324_080113.mp4`,
  `20260324_080046.mp4`) as `VERIFIED` in `track.py` before running
  (key is the full manifest path, not the bare filename -- tripped on
  this checking).
- Ran `single_month_zipper.sh 2026-03`: 84 files zipped (12
  `OK_H264_DELETED` + 72 `OK_WEBP_DELETED`), zip verified, staging
  cleared. Month complete.
- Ran a second time deliberately to observe anomaly-gate behavior on
  an already-finished month: all 84 correctly flagged `GHOST` (state
  `DELETED`, staged file already gone -- expected, not a bug). Chose
  `[c]ancel`, exited clean, no side effects.
- Trust test now 3/3 (`2026-04`, `2026-01`, `2026-03`).
  `multi_month_zipper.sh` unattended is viable for the remaining
  months.

## Resolved this session (2026-08-10)

**1. Unattended overnight run — first real end-to-end, backlog now clear**
- Built `run_overnight.sh`: wraps `multi_month_zipper.sh`, holds a
  wake-lock, runs detached in `tmux`, releases the wake-lock and kills
  its own `tmux` server on finish (so nothing keeps running or
  draining battery), fires a `termux-notification` on completion if
  Termux:API is installed.
- Added a real circuit-breaker to `multi_month_zipper.sh`: an isolated
  per-month failure (zip creation/verify, exit 1) now skips that month
  and continues to the next; a systemic failure (low disk space, exit
  2; anomaly-cancel, exit 3) still stops outright, since continuing
  would just repeat the same failure for every remaining month. New
  exit code 4 signals "completed, but with skipped months" distinct
  from clean success (0) or a hard stop (1/2/3) — `run_overnight.sh`'s
  notification text was updated to say so rather than reporting a
  partial run as "OK".
- Ran it for real across `2025-12` and `2026-02`, unattended, phone
  locked overnight: 6h59m (03:26:35 → 10:25:12), both months succeeded,
  no skips. **Every month in the original backlog is now archived**
  (`2026-01`, `2026-03`, `2026-04`, `2025-12`, `2026-02`).

**2. Process-tree false alarm — investigated, no bug found**
- Mid-run, `top`/`ps` showed what looked like recursive
  `single_month_zipper.sh` invocations (3 stacked PIDs per chain) and
  two concurrent `ffmpeg` processes. Traced fully before touching
  anything.
- Explanation: `process_month()` intentionally backgrounds video
  compression up to `MAX_PARALLEL_VIDEO=2` — two concurrent `ffmpeg`
  jobs is by design. The stacked `single_month_zipper.sh` entries were
  `ps` showing a backgrounded shell function's forked subshell under
  its parent's original command line (same argv, since it's a fork,
  not a re-exec) — not the script actually calling itself. No fix
  needed; confirmed the manifest/state log stayed clean throughout
  (`.state_log.tsv` entries were sequential, no duplicates).

**3. Pass 2 (verify) parallelized — real fix, wrong idea correctly rejected first**
- Proposed idea (splitting one file's verification into overlapping
  byte-region threads with cross-checking) was self-rejected before
  being built, for the right reason: it solves a consistency problem
  it would itself create, for a benefit that isn't real here — verify
  reads container metadata / does a size comparison, not a full-file
  decode, so there's no "portion of the file" that benefits from
  splitting.
- Real bottleneck confirmed by reading `verify.sh`: three process
  spawns per file (`track.py get`, the actual check, `track.py set`),
  fully serial. February's 100-file Pass 2 took ~5 min — ~3s/file for
  checks that are each individually near-instant, pointing at spawn
  overhead, not I/O.
- Fix: applied the same pattern Pass 1 already uses for video
  compression — background `verify()` calls across *different* files,
  capped by new `MAX_PARALLEL_VERIFY` (`common.sh`). Zero consistency
  risk, since each worker touches a disjoint file. Relies on the same
  `track.py` atomic-append safety Pass 1's backgrounded jobs already
  depend on in production — not a new bet. `multi_file_pipeline.sh`'s
  Pass 3 barrier now also waits on Pass 2's backgrounded jobs, mirroring
  the existing Pass 1→Pass 2 barrier.
- Not yet run on a real month — the two months that ran this session
  predate the patch. First live test is whatever month runs next.

**4. Session-mechanics fixes, folded into `tone.md`**
- **Heredoc delimiter collision** — a patch script's own outer `cat >
  ... << 'PATCH_EOF'` was closed early by an identical `PATCH_EOF`
  appearing inside the example content being delivered (a documented
  skeleton, not code that ran). Real bug, not a paste error: bash
  matches the first unindented occurrence of the delimiter regardless
  of context. Fixed by giving nested example delimiters distinct
  names from the outer call; now documented in `tone.md` as a
  requirement, not just a one-off fix.
- **Verify the path before patching** — `tone.md`'s own file-delivery
  section was assumed to be at project root once, was actually under
  `docs/`. `find`/`ls` before patching is now a stated rule, applied
  in both `archive_scripts` and `Ledger`.
- **`tone.md`'s file-delivery convention rewritten as a literal code
  template** (was prose) — a reusable skeleton for both new-file
  delivery and the idempotency-check/`ABORT`/git-commit/self-delete
  patch pattern, instead of describing it in words. Same change ported
  to `Ledger/docs/tone.md`; `.patches/` created there too.
- **`.patches/` added to `.gitignore`** — by design it should stay
  empty between sessions (every patch script self-deletes on success);
  one leftover from an `ABORT`ed README patch (superseded by a manual
  full-file overwrite once two byte-level mismatches — a stale
  blank-line count, then an em-dash encoding mismatch from a
  chat-pasted `sed` copy — made re-matching not worth chasing) was
  cleaned up and the directory excluded going forward.
- **Upload over paste, when a patch has already `ABORT`ed once** — a
  file uploaded directly gives exact bytes; text pasted through chat
  round-trips through markdown rendering and copy/paste, which is
  exactly what caused the em-dash mismatch above. Costs fewer tokens
  too. No formal `tone.md` line for this yet — worth adding next time
  it comes up.

**5. `README.md` and `architecture.md` refreshed**
- Usage sections fixed (`multi_month_zipper.sh` takes a month list, not
  a start/end range — was stale); `run_overnight.sh` documented as a
  third entry point in both docs.
- `architecture.md`'s pipeline section now describes two barriers (was
  one), and Pass 2's new parallelism.
- Storage screenshots swapped: stale 95%→91% pair replaced with a
  82% baseline / 96% mid-run-peak pair, captioned to explain the spike
  as expected (staging + originals briefly coexisting), not a leak.
  Added a third image showing the `termux-notification` completion
  alert — a real feature worth showing, not just documenting in text.

## Resolved this session (2026-08-12)

**1. Post-write `git diff` confirmation string spanned a line-wrap — false "did not confirm", correct write already landed**
- A patch script's post-write check searched `git diff --cached` for a
  single-line fragment, but the actual written content wrapped across
  two lines at that exact point (a backticked filename and an em dash,
  then a line break before the next word). The edit itself was
  correct and already staged; only the confirmation string was wrong,
  so the script printed "git diff did not confirm the expected
  change -- not committing" and left the file staged-but-uncommitted.
- Recovered by checking `git status`/`git diff --cached` directly
  instead of re-running the write, then committing manually once the
  diff was confirmed by eye.
- Lesson: post-write confirmation fragments must be guaranteed
  single-line -- pulled from a line that won't wrap in the actual
  output -- not assembled from prose that might.

**2. Heredoc delimiter collision recurred -- this time the payload itself was the culprit**
- Same underlying bug as 2026-08-10 (item 4), new trigger: delivering
  `tone.md` wrapped in `INNER_EOF`, when `tone.md`'s own body contains
  the literal text `EOF`/`INNER_EOF` as example strings (its own
  patch-script template documentation). The outer heredoc closed
  early at the first inner match, dumping the rest of the payload as
  raw shell input at the terminal.
- `tone.md`'s delimiter-collision rule rewritten to be explicit the
  check is "delimiter absent from the whole payload," not just
  "different from `EOF`" -- self-documenting files that show heredoc
  examples are the case most likely to trip this, and this file is
  exactly that case.

## Open

**1. `2026-03` orphan fold-in — RESOLVED 2026-08-08, see above**

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
  discovery paths. Still not done — no longer the single most urgent
  gap now that the backlog itself is clear, but still real.
- `.env` for hardcoded paths and config — paths (manifest, staging
  dir, archives dir, `STATE_LOG` default) and Termux-specific shebangs
  are hardcoded across `common.sh`, `track.py`, and the entry scripts.
  Fine single-device/single-user today; surfaced concretely once
  already when both `STATE_LOG` and `SCRIPT_DIR` being unexported in a
  fresh shell caused confusing failures (wrong-file reads, "command
  not found") with no signal pointing at the real cause. Related to
  the file-hash-integrity item below — both are "assumes single
  trusted environment" gaps, worth doing together before any
  open-source push.
- No size-ratio sanity check before delete (verify confirms the output
  decodes, not that it actually shrank meaningfully).
- No timeout on individual `ffmpeg` calls — a genuinely hung encode
  (distinct from a slow-but-progressing one, confirmed distinguishable
  this session by checking source file size against elapsed time)
  would never be caught by anything currently in the pipeline; it
  would just occupy a `MAX_PARALLEL_VIDEO` slot indefinitely.
- Duplicated tmux/wake-lock relaunch logic, now across *three* entry
  scripts (`single_month_zipper.sh`, `multi_month_zipper.sh`,
  `run_overnight.sh`, not two) — works in each, just not shared.
- File-hash integrity checking for scripts, deferred to open-source
  prep (see `ideas.md`).
- Storage reorg (`archive_*` files out of `$HOME` into a dedicated
  parent dir) — parked until after the trust test; trust test is now
  done, so this is unblocked whenever it's next picked up.

## Status snapshot at handoff
- **All 5 months in the original backlog are fully done**: compressed,
  zipped, verified, staging cleared. `2026-04`, `2026-01`, `2026-03`
  ran individually across earlier sessions; `2025-12` and `2026-02` ran
  together, fully unattended, via `run_overnight.sh` this session
  (6h59m, no skips, no manual intervention).
- 2099-01 (test month, not real data): fully done, same as above — zip
  exists in `Archives/`. Its 6 source files are gone (correctly
  deleted); re-running it now tests `MISSING` handling, not a repeat
  smoke test.
- Trust test: **3/3**, and now proven at the unattended-multi-month
  level too, not just single-month. The specific "can this run
  unattended overnight" question this trust test existed to answer is
  closed.
- Pass 2 (verify) is now backgrounded across files
  (`MAX_PARALLEL_VERIFY`), same pattern as Pass 1's video compression
  — not yet exercised on a real month, since both months this session
  predate the patch.
- Circuit-breaker (skip isolated month failures, stop on systemic
  ones) is live in `multi_month_zipper.sh` but has never actually
  fired for real — both months this session succeeded outright. Still
  unverified in practice, only by code reading.
- No months remain in the original backlog. Future runs are new data
  going forward, not backlog clearance — a different mode than every
  session so far.
