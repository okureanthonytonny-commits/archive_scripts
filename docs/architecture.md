# archive_scripts — architecture

Compresses and archives phone media to usable quality, running entirely
in Termux on Android. Rewritten in the 2026-08-02 session from a
monolithic per-file script into a small state-tracked pipeline, after
two unexplained crashes made "what actually happened" impossible to
answer from logs alone.

## Entry points

- **`multi_month_zipper.sh`** — run by hand or via `run_overnight.sh`.
  Loops a list of months, calls `single_month_zipper.sh` once per
  month, skips a month whose zip already exists. On a real per-month
  failure: skips that month and continues if it's isolated (zip
  creation/verify problem), but stops outright if it's systemic (low
  disk space, or an anomaly-cancel choice) — no point repeating the
  same failure for every remaining month.
- **`single_month_zipper.sh`** — handles exactly one month: filters the
  manifest into a filelist, runs the pipeline, zips staging, verifies
  the zip. Callable by hand too: `single_month_zipper.sh <YYYY-MM>`.
- **`run_overnight.sh`** — wraps `multi_month_zipper.sh` for unattended
  runs. Holds a wake-lock, runs detached in `tmux`, and on finish
  releases the wake-lock and kills its own `tmux` server so nothing
  keeps running afterward. Fires a `termux-notification` on completion
  if Termux:API is installed.

All three self-relaunch into a detached tmux session with a wake-lock if
not already running inside one — this logic is currently duplicated
across the three files, a known small piece of debt (see `ideas.md`).

## The pipeline: three passes, two barriers

For each month, every file moves through three states in order:

```
PENDING → COMPRESSED → VERIFIED → DELETED
                    ↘ FAILED
   (or MISSING, if the original never existed / vanished before pass 1)
```

**Pass 1 (compress)** — `lib/single_file_compressor.sh`'s
`compressor_process()` runs the format branch (webp/h264/copy), writes
an output file, records `COMPRESSED`. Video files are backgrounded up
to `MAX_PARALLEL_VIDEO` concurrent jobs; everything else runs inline.

**Barrier 1** — `multi_file_pipeline.sh` calls `wait` after pass 1.
Nothing in pass 2 starts until every backgrounded job — fast or slow —
has actually finished. This exists because verifying a video before its
background ffmpeg job completes was a real race we caught before it
shipped: without the barrier, a slow file could be wrongly marked
`FAILED` while still mid-compression.

**Pass 2 (verify)** — `verify.sh` decode-checks each `COMPRESSED` file
(dwebp / ffprobe / size-match, depending on kind) and moves it to
`VERIFIED` or `FAILED`. On failure, the state row carries both the
specific gate that rejected it *and* any real tool stderr captured
during compression — this is the closest bash gets to a traceback: not
a call stack, but the actual error text plus which check failed it.
Since each check is fast and cheap (no full-file decode, just a
container-metadata read or size comparison), the real cost here was
serial dispatch overhead, not per-file I/O — so, like pass 1, verify
calls are now backgrounded across files up to `MAX_PARALLEL_VERIFY`
concurrent jobs. Safe because each job touches a completely disjoint
file; there's no shared region or merge step needed.

**Barrier 2** — same pattern as barrier 1: `multi_file_pipeline.sh`
waits for every backgrounded pass 2 job before pass 3 starts. A file
never gets deleted before its own verify has actually finished.

**Pass 3 (delete)** — `delete.sh` removes the original only for files
still `VERIFIED`, and transitions to `DELETED`. This is the only place
an original file is ever removed.

Each pass simply loops the same filelist and asks the current state
before acting — `compressor_process()`/`verify()`/`delete()` all no-op
harmlessly on a url that's already past their concern. That's what
makes a crashed, resumed run safe: re-running pass 1 on an already-
`DELETED` file is a no-op, not an attempt to re-read a file that's
gone (a real bug we hit and fixed during testing).

## State: one source of truth, not several

**`lib/track.py`** is the only place state lives. Append-only rows:
`ts, url, state_int, state_name, kind, path, note`. Every read (`get`)
re-derives "current state" from the last row for that url — nothing is
ever trusted in place, so a crash mid-write can't corrupt what recovery
depends on. Append-mode writes are small enough to be atomic even under
concurrent writers, which both pass 1 and pass 2 now rely on for their
backgrounded jobs.

**`lib/summary.py`** replaces what used to be an incrementally-written
`FILE_LOG`. It's a pure query: read `state_log.tsv`, take the last row
per url in this month's filelist, map terminal states to the same
`OK_WEBP_DELETED` / `FAIL_VIDEO` tags the old code used, print. Nothing
writes `FILE_LOG` directly anymore — it's regenerated on demand right
before `single_month_zipper.sh`'s existing status-breakdown `awk`
commands read it, so those commands needed zero changes.

This was a deliberate fix, not a refactor for its own sake: the old
design had `FILE_LOG` and (implicitly) real pipeline state as two
things that could silently disagree if a crash landed between writing
one and the other. Now there's exactly one thing to trust.

## Logging layers

| File | Written by | Job |
|---|---|---|
| `.state` | `set_state()`, every file, pass 1 | single line, overwritten — "what's happening right now," for crash forensics |
| `.state_log.tsv` | `track.py`, from `single_file_compressor.sh`/`verify.sh`/`delete.sh` | append-only per-url truth table — the real source of truth |
| `files.tsv` | `summary.py`, generated on demand | terminal-outcome tally, derived, never written directly |
| `run.log` | `log()`, throughout | narrative, human-readable |
| `overnight_run.log` | `log()`, `run_overnight.sh` | wrapper-level: start/end, wake-lock, notification status |

## File reference

```
multi_month_zipper.sh    orchestrator — loop months, circuit-breaker
single_month_zipper.sh   worker — one month → zip
run_overnight.sh         unattended wrapper — wake-lock, tmux, notify, self-close
lib/
  common.sh                config, log(), set_state(), check_space()
  single_file_compressor.sh  compressor_process() — one file in, one file out
  verify.sh                 verify() — decode-check + gate reason
  delete.sh                 delete() — remove original iff VERIFIED
  multi_file_pipeline.sh    process_month() — the 3-pass loop + 2 barriers
  track.py                  state_log.tsv reader/writer, CLI
  summary.py                derives FILE_LOG from state_log.tsv
```

Full call-by-call reference, including which references are by-name
(safe across file renames) vs by-path (break on rename): `CONTRACTS.txt`.

## Known gaps (see `ideas.md` for the original reasoning)

- No size-ratio sanity check before delete — verify confirms the output
  *decodes*, not that compression actually shrank the file meaningfully.
- No final reconciliation pass — nothing yet cross-checks the zip's file
  count against the manifest's expected count for the month.
- No timeout on individual `ffmpeg` calls — a genuinely hung encode
  (distinct from a slow-but-progressing one) would never be caught by
  anything; it would just occupy a `MAX_PARALLEL_VIDEO` slot forever.
- Every real month in the original backlog (`2026-01`, `2026-03`,
  `2026-04`, `2025-12`, `2026-02`) has now run end-to-end on real
  device data — the last two fully unattended via `run_overnight.sh`,
  after a 3/3 trust test on the other three.

Retry-on-failure shipped: a file that fails verify gets recompressed
automatically, up to a cap, before it's given up on as a real failure.

## History

Full narrative of how this pipeline got here — the original monolith,
the two unexplained crashes, the state-machine redesign, the naming
back-and-forth, and the bugs each rewrite step surfaced — lives in
`docs/sessions/`.
