# archive_scripts

Compresses phone media by month, verifies the compressed copy, deletes
the original only once verified, zips the result. Runs entirely in
Termux, no PC.

- [What it does](#what-it-does)
- [Getting started](#getting-started)
- [Usage](#usage)
- [Status](#status)
- [Known gaps](#known-gaps)
- [Docs](#docs)

## What it does

- Goal: free device storage without losing data.
- Backup-only and compress-only were rejected on their own: backup
  still costs time/data to restore and isn't risk-free; compress-only
  needs progressive delete mid-run or both copies fill the phone. This
  pipeline does both — originals backed up off-device (Backblaze B2)
  separately, this pipeline compresses locally and deletes only after
  verify.
- One month at a time — compressed and original data never mix
  mid-run. WhatsApp media skipped (already compressed on send).
- State is append-only, file-based (`state_log.tsv`). Nothing inferred
  from disk state — a crash is recoverable, not a mystery.

![Internal storage baseline, 82% used, 10 Aug 2026](docs/images/storage-baseline-82-percent.jpg)
![Internal storage after archiving through July, 78% used, 27 Aug 2026](docs/images/storage-after-8-months-78-percent.jpg)

82% at the start (10 Aug) down to 78% after archiving through
`2026-07` (27 Aug) — `2026-08` (current month) deliberately untouched.
See [docs/images/](docs/images/) for the mid-run 96% peak.

## Getting started

Dependencies:

~~~
pkg install python tmux termux-api ffmpeg webp zip unzip
~~~

`termux-api` needs the **Termux:API** companion app (F-Droid) for
`termux-wake-lock`/`termux-notification`.

~~~
git clone https://github.com/okureanthonytonny-commits/archive_scripts
cd archive_scripts
./build_manifest.sh -a 90 /path/to/source/dir1 /path/to/source/dir2
./single_month_zipper.sh 2026-01
~~~

## Usage

- `build_manifest.sh [-o OUTPUT] [-a MIN_AGE_DAYS] [--include DIR ...]
  [--exclude DIR ...] [DIR [DIR2 ...]]` — scan dirs, (re)build/extend
  `archive_manifest.tsv`. Safe to re-run: skips already-recorded
  paths. `--include`/`--exclude` are mode switches, not one-value
  flags — bare dirs before either are implicitly `--include`; a dir
  after a switch stays in that list until the other switch appears, in
  any order. No dirs given falls back to `INCLUDE_DIRS` in `.env`; a
  command-line include replaces it entirely. `--exclude` always merges
  with `EXCLUDE_DIRS`.
- `single_month_zipper.sh <YYYY-MM>` — compress, verify,
  delete-if-verified, zip one month.
- `multi_month_zipper.sh <YYYY-MM> [<YYYY-MM> ...]` — same, looped.
  Skips a month whose zip already exists. Isolated per-month failure:
  skip and continue. Systemic failure (low disk, anomaly-cancel): stop
  outright.
- `run_overnight.sh [<YYYY-MM> ...]` — wraps `multi_month_zipper.sh`:
  wake-lock, detached `tmux`, releases lock and kills its own tmux
  session on finish. Fires a completion notification if
  `termux-notification` is installed.

![archive_scripts overnight run finished notification, 27 Aug 2026](docs/images/archive-run-ok-2026-08-27.jpg)

All three self-relaunch into a detached `tmux` session with a
wake-lock if not already inside one.

## Status

Backlog clear through `2026-07`. Every month from `2025-12` onward
has run end-to-end on real device data — `2026-01`–`2026-04` in the
original 3/3-trust-tested backlog, then `2026-05`–`2026-07` in a
follow-up run, both fully unattended via `run_overnight.sh`. `2026-08`
(current month) deliberately untouched. See
[docs/images/](docs/images/) for the original zips listing.

Retry-on-failure: a file that fails verify gets recompressed
automatically, up to a cap, before being given up on. Pass 2 (verify)
runs several files concurrently (`MAX_PARALLEL_VERIFY`), same pattern
as Pass 1.

## Known gaps

- Orphan reconciliation (staged file, no confirmed `DELETED` entry):
  decode-checked via `verify()` pre-zip; `VERIFIED` folds into the
  zip, `FAILED` retries via the same guard as Pass 1. Exercised for
  real on-device during the 2026-08-27 backlog run (`2026-05`/
  `2026-06`) — 3 orphans hit, all 3 recovered and folded into their
  zips. Caveat: recovery zips the file but doesn't delete its
  original (only Pass 3's normal delete does that) — check `unzip -l`
  before manually deleting a flagged original.
- `build_manifest.sh` doesn't filter Android thumbnail-cache junk
  (`.thumbnails/.nomedia`, `.thumbnails/.database_uuid`) — recorded
  like real media (harmless, 0–36 bytes). Left as-is deliberately: the
  manifest reflects exactly what was scanned, not a filtered guess.
- `build_manifest.sh`'s default output path is relative to wherever
  it's run (`./archive_manifest.tsv`), while `MANIFEST` (used by every
  other script) defaults to `$HOME/archive_manifest.tsv` — running it
  from inside `archive_scripts/` silently writes to the wrong file,
  and the pipeline just reports "0 files to process" with no error.
  Always pass `-o ~/archive_manifest.tsv` explicitly.
- Paths and config are read from `.env` (see `.env.example`) via
  `lib/config.sh`, so another device just needs its own `.env` — no
  code changes.
- Only proven under Termux/Android. Never tried in a plain Linux
  shell.
- No timeout on individual `ffmpeg` calls — a genuinely hung encode
  (distinct from a slow-but-progressing one) would never be caught.
  See `docs/sessions/issues.md`.

## Docs

- [images/](docs/images/) — screenshots not embedded above: mid-run
  storage peak (96%, 10 Aug), original overnight notification (10
  Aug), first compressed-months listing (9 Aug).
- [architecture.md](docs/architecture.md) — full pipeline detail:
  state machine, verify barrier, what each log file is for.
- [archive-architecture.mermaid](docs/archive-architecture.mermaid) —
  same pipeline as a diagram.
- [sessions/](docs/sessions/) — session-by-session history: every bug
  found, decision made, and rewrite, in order.
