# Session summary — 2026-08-03

## Starting point
Handoff from 2026-08-02: full pipeline rewrite complete, proven only
against synthetic sandbox files, never run on a real device.

## What actually happened
Ran the first real on-device test: 6 disposable files (3 video, 3
photo/screenshot) under a fake month `2099-01`, manifest rows added by
hand. Clean pass — compress, verify, delete, zip, zip-verify, staging
cleared, `track.py get` confirmed consistent with `files.tsv`. This
closed the "never tested on-device" item from `issues.md`.

Everything after that was hardening, prompted by direct questions about
what could still go wrong:

- **Preflight checks** (both entry scripts): hard-fail immediately if
  any required lib/code file is missing, instead of a confusing
  mid-run crash — same bug class as the missing-`source`-lines issue
  from 2026-08-02.
- **Zip-list fix**: `single_month_zipper.sh` used to `zip -rq` the
  entire staging directory. While designing the fix, found a real
  related bug — `delete.sh` never cleans up a `FAILED` file's
  corrupt/partial staged output, so it could have silently ridden into
  the zip. Fixed by building the zip's file list from `track.py`'s
  `DELETED` state only.
- **`ANOMALY_MODE` prompting** (wait/cancel/skip): asked once at
  launch, in the outer pre-tmux invocation while attended, passed via
  env var into the detached tmux session and through to
  `multi_month_zipper.sh`'s calls to `single_month_zipper.sh` — one
  prompt per orchestrator run, not per month.
- **Three-way reconciliation**, using per-file `track.py` state instead
  of filename-diffing: `STUCK` (never reached a terminal state),
  `GHOST` (state says `DELETED`, file physically gone), `ORPHAN`
  (physical file in staging, no confirmed `DELETED` entry). Any of the
  three gates the zip step through `ANOMALY_MODE`. This also
  structurally resolves the standing caution about checking
  `archive_staging/2026-03` for old-pipeline leftovers by hand — it'll
  now surface as `ORPHAN` automatically.
- **Exit code 3** wired into `multi_month_zipper.sh`'s status messages
  (was falling into the generic exit-1 message).
- **`tone.md` convention added**: patch-script output must name the
  change it belongs to, not just print a bare `SKIPPED`/`WRITTEN` —
  several one-off patch scripts piling up in `$HOME` made scrollback
  untraceable otherwise.
- **`ideas.md`**: logged file-hash integrity checking (deferred to
  open-source prep) and a per-target interactive setup script concept
  (deferred as feature creep, noted for later).

Plan shifted from "run everything, then upload to GitHub" to a
deliberate mixed trust test first: `2026-04` (tests orchestrator's
skip-existing-zip path), `2026-01` (clean), `2026-03` (the messy
half-crashed one) — each run individually before trusting
`multi_month_zipper.sh` unattended.

## Where the original issues.md items landed
- Never-tested-on-device: resolved for the base pipeline (smoke test
  passed).
- No final reconciliation pass: resolved, then extended beyond the
  original ask into the three-way `STUCK`/`GHOST`/`ORPHAN` check.

## Everything past the smoke test is unverified
All of the hardening above (preflight, zip-list fix, `ANOMALY_MODE`,
reconciliation, exit-code-3) was written and patched onto the device
blind, against pasted file contents — none of it has been exercised by
an actual run yet.

## Why this session ended here
Token budget, not a natural stopping point — this chat had grown very
long. Splitting into a new session for the actual trust test rather
than continuing here.

## Next session
0. Move patch scripts into `archive_scripts/.patches/` instead of loose
   in `$HOME`, and add that as a `tone.md` convention — first thing,
   before any real code work.
1. Note: `2099-01`'s 6 smoke-test files were already deleted by the
   successful run — re-running it now tests the `MISSING` path, not a
   repeat of the original smoke test.
2. Run the mixed trust test in order: `2026-04`, then `2026-01`, then
   `2026-03` — via `single_month_zipper.sh` individually, watching for
   the new preflight/zip-list/reconciliation code actually firing
   correctly (or not) against real conditions.
3. If clean: consider `multi_month_zipper.sh` unattended for the
   remaining months.
4. Docs current as of this session's close: `progress.md`, `issues.md`,
   `ideas.md`, `tone.md` all reflect this session's changes.
