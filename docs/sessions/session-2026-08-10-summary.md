# Session summary -- 2026-08-10

## Starting point
Handoff from 2026-08-09: trust test at 3/3 (`2026-04`, `2026-01`,
`2026-03` all clean). `multi_month_zipper.sh` unattended was confirmed
viable but never actually run that way. Next step was the first real
unattended overnight run across the two remaining months (`2025-12`,
`2026-02`).

## What actually happened
Before running unattended, added a real circuit-breaker to
`multi_month_zipper.sh`: an isolated per-month failure (exit 1, zip
creation/verify) now skips that month and continues; a systemic
failure (exit 2 low disk, exit 3 anomaly-cancel) still stops outright,
since continuing would just repeat the same failure for every
remaining month. New exit code 4 marks "completed, but with skipped
months," distinct from clean success or a hard stop.

Built `run_overnight.sh`: unattended wrapper holding a wake-lock,
running detached in `tmux`, releasing the wake-lock and killing its
own `tmux` server on finish so nothing keeps draining battery, and
firing a `termux-notification` on completion. `run_overnight.sh`'s
status message was updated to distinguish exit-4 (skipped, still
completed) from an actual stop, so a completed-with-skips run doesn't
read as "OK" when it wasn't fully clean.

Ran it for real across `2025-12` and `2026-02`, phone locked overnight:
6h59m (03:26:35 -> 10:25:12), both months succeeded, no skips. **Every
month in the original backlog is now archived.**

Mid-run, `top`/`ps` showed what looked like recursive
`single_month_zipper.sh` calls and two concurrent `ffmpeg` processes --
investigated fully before touching anything, rather than killing blind
at 96% memory. Turned out to be `ps` showing a backgrounded shell
function's forked subshell under its parent's original command line
(same argv, since it's a fork not a re-exec) -- the intended
`MAX_PARALLEL_VIDEO=2` design, not a bug. `.state_log.tsv` confirmed
clean throughout (sequential, no duplicates).

Storage screenshots (82% baseline, 96% mid-run peak) prompted a look at
`verify.sh`'s slowness. Proposed idea -- splitting one file's
verification into overlapping byte-region threads with cross-checking
-- was self-rejected before being built, correctly: it solves a
consistency problem it would create itself, for a benefit that isn't
real, since `verify()` reads container metadata / does a size
comparison, not a full-file decode. Read `verify.sh` to confirm; real
bottleneck was three serial process spawns per file (`track.py get`,
the check, `track.py set`) -- February's 100-file Pass 2 took ~5 min
for checks that are each near-instant. Fixed by applying Pass 1's
existing across-file backgrounding pattern to Pass 2
(`MAX_PARALLEL_VERIFY`, `common.sh`), relying on the same `track.py`
atomic-append safety Pass 1 already depends on in production. Not yet
exercised on a real month -- both months this session predate the
patch.

`README.md` and `architecture.md` refreshed: stale usage/status
sections corrected (`multi_month_zipper.sh` takes a month list, not a
start/end range), `run_overnight.sh` documented as a third entry
point, Pass 2 parallelism and the second barrier added to the
architecture doc. New storage screenshots (82%/96%) replaced the stale
95%/91% pair; a third image showing the completion notification was
added as a real feature, not just described.

## Process note
Several session-mechanics bugs surfaced and got folded into `tone.md`
(and ported to `Ledger/docs/tone.md` where applicable) rather than
just fixed silently:
- A patch script's own outer heredoc was closed early by an identical
  delimiter appearing inside the example content being delivered --
  real bug, not a paste error. Nested example delimiters now must be
  distinct from the outer call's.
- `tone.md`'s own file-delivery section was assumed to be at project
  root once, was actually under `docs/` -- "verify the path before
  patching" is now a stated rule, not just something we tell Tonny.
- Two `README.md` patches `ABORT`ed on invisible byte drift (a stale
  blank-line count, then an em dash that round-tripped through chat
  paste and came out as different bytes than the source file). `cat
  -A` confirmed the mismatch instead of guessing at it. Resolved by
  uploading the file directly instead of re-pasting, then a full-file
  overwrite instead of a third match attempt -- both now documented as
  the standard response to a second `ABORT`.
- `tone.md`'s file-delivery convention itself was rewritten from prose
  into a literal code template (heading added, per Tonny's request),
  and `.patches/` added to `.gitignore` in both projects since it
  should stay empty between sessions by design.

## Why this session ended here
The original backlog is fully cleared -- there's no more "next month to
run" the way every prior session had. That's a natural, structural
stopping point: what comes next (Pass 2 parallelism exercised on a
real month, orphan-enumeration-through-`verify()`, `.env` adoption) is
new work on a clean base, not a continuation of clearing the backlog.

## Next session
1. First real month to exercise the new parallel Pass 2 -- watch for
   `verify progress: N/total` jumping in clusters of `MAX_PARALLEL_VERIFY`
   rather than one at a time, and a shorter Pass 2 duration than the
   ~3s/file baseline from `2026-02`.
2. Circuit-breaker (skip isolated month failure, stop on systemic) has
   never actually fired -- both months this session succeeded outright.
   Still unverified in practice, only by code reading.
3. Orphan-enumeration-through-`verify()` (issues.md open gap) -- no
   longer the single most urgent gap now that the backlog is clear,
   but still real.
4. `.env` adoption for hardcoded paths/config (issues.md open gap) --
   still scoped as its own short session.
5. Storage reorg (`archive_*` out of `$HOME`) -- unblocked now that
   the trust test is fully done, previously parked pending it.
6. Docs updated this session: `progress.md`, `issues.md`, `README.md`,
   `architecture.md`, `tone.md` (both projects), this summary.
