# Session summary -- 2026-08-18

## Starting point
Handoff from 2026-08-17: three backlog items open (orphan enumeration
through `verify()`, storage reorg out of `$HOME`, tmux/wake-lock
relaunch dedup). This session picked up the first one -- issues.md open
item 4 -- per Tonny's request, with the explicit instruction to plan
first and only write code after sign-off.

## What actually happened
Investigated the current reconciliation code before proposing anything,
which immediately changed the shape of the task: the "only counts
orphans" description in issues.md was already stale. Commit `d55a1f4`
(2026-08-17) had added an orphan-enumeration loop inline in
`single_month_zipper.sh` that ran each orphan through the raw
`verify_webp`/`verify_video`/`verify_copy` gates and folded `VERIFIED`
ones into the zip list. What was still missing was exactly what the
issue text asked for: routing orphans through the *real* `verify()`,
and folding `FAILED` orphans into the retry-with-guard logic.

Implemented:
- **`lib/orphan_reconcile.sh`** (new): `reconcile_orphans()` scans
  staging for files not backed by a confirmed `DELETED` entry, derives
  each orphan's url+kind, and runs it through `verify_orphan()`.
  `VERIFIED` orphans fold into the zip list; `FAILED` orphans get a
  tracked entry with the exact reason and fall into Pass 1's existing
  retry-with-guard, capped by `RETRY_MAX` with the same exhausted-skip
  behavior as any other FAILED file. Also contains `_orphan_derive_url()`
  (disk original first, then manifest fold-in urls, then the default
  `.jpg` guess from the 2026-08-08 fold-in).
- **`lib/verify.sh`**: added `verify_orphan()` -- same gates as
  `verify()` but for a state-less staged file, writing `VERIFIED` or
  `FAILED` + reason directly. `verify()` itself untouched (safe).
- **`single_month_zipper.sh`**: the inline orphan loop (and its
  `ORPHAN_RECOVERED`/`ORPHAN_UNRESOLVED` bookkeeping) replaced with a
  `reconcile_orphans` call; new lib added to `REQUIRED_FILES` and
  sources.
- **`tests/diagnostics/orphan_status.sh`**: now sources the libs and
  uses the shared `_orphan_derive_url()` instead of its own copy (the
  historically-buggy gap-3 one).
- Docs: `CONTRACTS.txt` (new lib entry, verify.sh + track.py caller
  lists), `README.md` known-gap rewritten, `architecture.md` file
  reference + mermaid diagram (new `orphan_reconcile.sh` node and
  staging->reconcile->zip edges), `issues.md` gap marked resolved.

Validation was sandboxed, not on-device: isolated `STATE_LOG`, shimmed
`dwebp`/`ffprobe` (content-based pass/fail), fake manifest + staging
under a `/storage/emulated/0` symlink. Exercised all six paths --
manifest-derived webp, disk-derived webp, default-guess webp, video,
copy-with-original, copy-original-missing -- plus the `RETRY_MAX` guard
across three runs: verify (FAILED count 1), re-verify (count 2),
retry-exhausted (no new state writes, clear log line). One design
cleanup caught mid-test: `verify_orphan()` originally logged its own
failure line, duplicating `reconcile_orphans()`'s attempt-context line;
removed the inner one. `bash -n` clean on all four touched scripts.

## Why this session ended here
The gap is closed end-to-end and the mechanism ("one mechanism, two
discovery paths") behaves exactly as the issue described. It has not
run on a real device month, which is the standing caveat -- the
orphan-triggering scenarios (a pre-rewrite leftover, a crashed-run
COMPRESSED file) only exist in the finished months, so the first real
exercise will be whatever month next produces an anomaly.

## Next session
1. Storage reorg (`archive_*` out of `$HOME`), carried forward
   unchanged.
2. Duplicated tmux/wake-lock relaunch logic across three entry
   scripts, carried forward unchanged.
3. The orphan-reconcile path still needs a first real on-device
   exercise (ideally a deliberately-seeded broken staged file to watch
   the FAILED -> retry -> VERIFIED or MISSING path in production).
4. Docs updated this session: `docs/CONTRACTS.txt`, `README.md`,
   `docs/architecture.md`, `docs/archive-architecture.mermaid`,
   `docs/sessions/issues.md`, `docs/sessions/progress.md`, this
   summary.