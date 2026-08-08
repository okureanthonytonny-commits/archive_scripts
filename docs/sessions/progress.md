# progress.md — Phone Archive Pipeline

## 2026-07-29
- Backed up `/storage/emulated/0` to Backblaze B2 via rclone. Verified
  with `rclone check` — 2958 matched, 22 diffs. Re-synced 5 missing
  files, re-checked clean (17 remaining diffs were already-deleted
  local files, expected).
- Found 1 duplicate file group (3 copies of one WhatsApp image),
  confirmed by hash, resolved — kept 1.
- Benchmarked compression on real device:
  - Photos → WebP q80: ~74% reduction
  - Screenshots → WebP lossless: ~46% reduction (even from JPEG source)
  - Video → H.264 CRF30 software encode: 72-90% reduction depending on
    content (daylight footage compresses less than night/noisy footage)
  - Encode rate: ~1.6x realtime at 720p, ~3.1x realtime at 1080p
- Scanned DCIM + Movies + Pictures, files 90+ days old: 1733 files,
  37.9GB, across 5 months (2025-12 through 2026-04).
- First real run (2026-04) died overnight — Termux killed by Android,
  no wake lock held. 41/152 files staged, zero data loss (deletion
  step was never reached).

## 2026-07-30
- Root-caused the crash: no `termux-wake-lock`, no `tmux`. Added both.
- Added resumability (skip already-staged files), then found device
  storage at 94% (120.8GB/128GB) — added disk-safety abort checks.
- Redesigned deletion: was "zip whole month → verify → batch delete."
  Changed to per-file delete-after-verify (compress → decode-check
  output → delete original only if verified). Removes the disk-order
  constraint entirely — space frees up continuously per file.
- Refactored from one script into modules:
  `lib/common.sh`, `lib/compress.sh`, `archive_compress.sh`,
  `archive_run_all.sh`. All four written and delivered.
- Chose processing order: oldest month first (2025-12 → 2026-04) —
  least-critical data touched first.
- Session closed with docs written (this file, architecture.md,
  session summary). Next step: run `archive_run_all.sh 2026-04` as
  first test of the full modular pipeline against the partially-staged
  month, then run the rest.

## 2026-07-31
- Recovered from missing `archive_compress.sh` (never actually delivered
  to device last session despite docs saying so) — rebuilt from
  `common.sh`/`compress.sh`/`architecture.md`, confirmed consistent.
- Fixed two bugs found on first real run: `df -m` unsupported on
  Termux's `df` (switched to `df -k` + arithmetic), and `zip` binary
  missing (`pkg install zip`).
- 2026-04 completed end-to-end: compressed, zipped (564MB from
  4511MB, ~87.5% reduction), verified, staging cleared.
- Found and fixed `SKIP_RESUME` bug: resume check returned before the
  verify+delete step, so resumed files' originals were never deleted.
  41 stuck originals from 2026-04 manually cleaned up after confirming
  they were already safely zipped.
- Added `set_state()` to `common.sh` (single-line overwrite status
  file at `~/archive_scripts/.state`) for crash/kill recovery, in
  place of relying on tmux session names or scrollback.
- Decided against a dedicated "months done" tracking file — the zip
  files in `/storage/emulated/0/Archives/` already serve as the
  ground-truth completion marker.
- Started 2026-03 as second test (chosen as smallest remaining month,
  ~4.1GB). Crashed early both times: first attempt died before any
  file processed, second attempt lost the whole tmux server mid-run
  despite Termux battery already set to Unrestricted — cause
  unresolved. Also logged spurious "missing on disk" entries for files
  manually confirmed to still exist. Both logged in new `issues.md`.
- Created `docs/issues.md` for this project (didn't exist before).
- Session closed with SKIP_RESUME fix applied but not yet exercised
  live (2026-03 never got far enough to test it). Next session: resolve
  the two 2026-03 mysteries before re-attempting, or route around them
  if a device-level cause is found (e.g. checking load average during
  a live run, or logcat around the kill time).

## 2026-08-02
- Long session: full pipeline rewrite, from monolithic per-file script
  to a state-tracked, multi-pass architecture.
- Root cause of the naming confusion (`compress.sh` secretly containing
  `process_month()`) diagnosed via a fresh architecture diagram, then
  split into single-responsibility files.
- Designed and built `track.py`: append-only per-url state log
  (`PENDING/COMPRESSED/VERIFIED/DELETED/FAILED/MISSING`), replacing
  ad-hoc log strings with a queryable single source of truth. Added a
  `note` field after realizing FAILED states carried no diagnostic
  info — now captures real tool stderr + which check failed, the
  practical equivalent of a traceback in bash.
- Split the pipeline into: `single_file_compressor.sh` (one file in,
  one file out), `verify.sh` (decode-check + reason), `delete.sh`
  (remove original iff verified), `multi_file_pipeline.sh`
  (orchestration only — three passes with a hard `wait` barrier
  between compress and verify, to prevent a real race condition with
  backgrounded video jobs).
- Replaced incrementally-written `files.tsv` with `summary.py` — a
  pure query over `state_log.tsv`, removing a second source of truth
  that could silently drift from the real state on a crash.
- Found and fixed three real bugs during testing (see `issues.md` for
  detail): a video/verify race, a DELETED-file-misread-as-MISSING
  resume bug, and missing `source` lines that would have failed at
  runtime on the very first real invocation.
- Full rename pass for clarity: `archive_run_all.sh` →
  `multi_month_zipper.sh`, `archive_compress.sh` →
  `single_month_zipper.sh`, `lib/compress.sh` →
  `lib/single_file_compressor.sh`, `lib/process_month.sh` →
  `lib/multi_file_pipeline.sh`. Removed dead `compress_one.sh` and
  `file_log()`.
- Created `docs/CONTRACTS.txt` — explicit map of every cross-file
  reference (by-name vs by-path), specifically to catch the class of
  bug that caused the missing-source-lines issue above.
- Rewrote `architecture.md` and the architecture diagram fresh against
  the final structure (both were badly stale mid-session).
- Migrated the old backlog note (tiered compression, preview+link
  architecture, semantic search, dedup-by-hash) into `ideas.md`.
- Everything proven in a sandbox against synthetic files, NOT yet run
  on-device. Next session: on-device smoke test with disposable files,
  then a monitored real retry of 2026-03.

## 2026-08-03
- On-device smoke test, first real run of the rewritten pipeline: 6
  disposable files (3 video, 3 photo/screenshot) under a fake month
  `2099-01`, added directly to `archive_manifest.tsv` by hand (bypassing
  whatever normally builds it). Clean pass — 68MB → 9.9MB (~85%
  reduction), zip verified, staging cleared, `track.py get` confirmed
  state matched `files.tsv`. One non-bug surfaced: WhatsApp-path files
  get `OK_STORED_DELETED` (copied, not compressed) by design — WhatsApp
  already compresses on send.
- Everything below was written *after* that smoke test and is still
  UNTESTED on-device — this is the key thing session 5 needs to verify
  before trusting a real month:
  - Preflight checks in both entry scripts: hard-fail immediately if
    any required lib/code file is missing, instead of a confusing
    mid-run "command not found" crash (the same bug class as the
    missing-`source`-lines issue from 2026-08-02).
  - Zip-list fix: `single_month_zipper.sh` used to `zip -rq` the whole
    staging directory. Now it builds the zip's file list from
    `track.py`'s `DELETED` (terminal success) state only — a corrupt
    or leftover file physically sitting in staging can no longer
    silently ride into the archive.
  - `ANOMALY_MODE` (wait/cancel/skip): prompted once at launch (outer,
    pre-tmux invocation, while attended), passed via env var into the
    detached tmux session and through to any `single_month_zipper.sh`
    calls `multi_month_zipper.sh` makes. Governs what happens when a
    reconciliation anomaly is found.
  - Three-way reconciliation check before zipping, using per-file state
    from `track.py` rather than filename-diffing: `STUCK` (never
    reached a terminal state), `GHOST` (state says `DELETED` but the
    staged file is physically gone), `ORPHAN` (physical file in staging
    with no confirmed `DELETED` entry backing it — supersedes the
    narrower staging-vs-zip-count check from earlier the same session).
    Any of the three trips the same wait/cancel/skip gate; `cancel`
    exits 3, `skip` proceeds with only the confirmed files.
  - `multi_month_zipper.sh` now recognizes exit code 3 distinctly (was
    falling into the generic "exit 1 = zip problem" message).
- Decided against running the full 5-month batch immediately. Plan
  instead: a deliberate mixed trust test — `2026-04` (already archived,
  tests the orchestrator's skip-existing-zip path), `2026-01` (clean,
  untouched), `2026-03` (the messy half-crashed-under-the-old-pipeline
  one) — each run individually via `single_month_zipper.sh` before
  trusting `multi_month_zipper.sh` unattended on everything.
- Added a documentation convention to `tone.md`: patch-script output
  (`SKIPPED`/`WRITTEN`/`ABORT`) must name the change it belongs to,
  not just print the bare status word — several one-off patch scripts
  piling up in `$HOME` made scrollback untraceable otherwise.
- Session closed here on token-budget grounds (this chat had grown
  very long) rather than a natural stopping point in the work. Next
  session starts by re-verifying the 2099-01 test data note below,
  then proceeding to the mixed trust test.

## 2026-08-06
- Ran the mixed trust test planned last session: `2026-04`, `2026-01`,
  `2026-03`, each via `single_month_zipper.sh` individually.
- `2026-04` hung indefinitely with 0 files to process. Root cause: a
  bare `wait` in `multi_file_pipeline.sh`'s Pass 1 barrier waits on
  *every* background job in the shell, not just the video compress
  jobs it was meant for — including the `tee` process substitution
  `single_month_zipper.sh` uses for logging, which never exits until
  the script's own stdout closes. Deadlock, even with zero video jobs
  spawned. Fixed by tracking video job PIDs in an array and waiting
  only on those.
- `2026-01` (212 files, ~6.4GB) ran clean end-to-end after the fix,
  confirming it holds under real multi-hour load, not just the
  instant-exit case.
- `2026-03`: Pass 2 correctly caught 2 real `ffprobe` verify failures.
  Reconciliation then flagged 28 `ORPHAN` files. Investigated by hand
  rather than trusting `[s]kip` blind — found 26 genuine orphans,
  `.webp`/`.mp4` outputs from an earlier abandoned March run (staged
  2026-07-31, three days before the current manifest was rebuilt).
  Originals no longer exist in `DCIM` — these staged files are the
  only surviving copies. Chose `[c]ancel`: reversible, leaves staging
  untouched, versus an unverified `[s]kip` behavior on untracked files
  with irreplaceable data at stake.
- Logged an idea to `ideas.md`: throttling the pipeline to spread
  work over time and compete less with other apps running
  concurrently.
- Trust test: 2/3 months clean (`2026-04`, `2026-01`). `2026-03`
  passed for the tooling (anomaly detection worked as designed) but
  the month itself is blocked pending a manual fix.

## Open items
- Apps+System storage (~45GB) not addressable by this pipeline —
  needs manual `Settings → Apps → clear cache` pass.
- (2026-07-31 backlog items migrated into `ideas.md` on 2026-08-02.)
- **2026-03 unblocked (2026-08-08):** all 75 true orphans folded into
  manifest + track.py. Ready for `single_month_zipper.sh 2026-03`.

## 2026-08-07
- Diagnosed the 2 `ffprobe`-failed files from 2026-08-06: checked the
  real originals in `DCIM` directly with `ffprobe` — both decode
  clean. Root cause isolated to the staged compressor output, not the
  source: `moov atom not found` (truncated write), consistent with the
  abandoned 2026-07-31 pre-rewrite run.
- Decided to use the two broken files as real regression-test fixture
  data rather than just fixing them by hand — copied the broken staged
  copies to `tests/fixtures/moov-atom-missing/` before touching
  anything, so the specimens survive the fix.
- Built retry-on-`FAILED` logic: `track.py count <url> <STATE>` (log
  scan, no schema change) for attempt counting, plus a Pass 1
  extension in `multi_file_pipeline.sh` — a `FAILED` file under
  `RETRY_MAX` attempts gets its stale staged output cleared and falls
  through to reprocess; at the cap it's skipped with a clear log
  instead of looping. Found along the way that clearing the stale
  output isn't optional cleanup — `compressor_process()` skips
  recompression if the output file already exists non-empty, so
  without the delete the retry would silently no-op.
- Test isolation went through two real mistakes before landing
  correctly: first seeded fixture `FAILED` entries directly into
  production `.state_log.tsv` (should have used an isolated log from
  the start — caught after the fact, left the accidental rows in place
  per the append-only convention rather than editing history, noted in
  the fixtures README instead). Second, a manual isolated-log test
  silently fell back to production because `STATE_LOG`'s export didn't
  survive between shell commands — no error, just a wrong-looking
  right answer. Fixed by writing `tests/run_retry_test.sh`, a
  self-contained script that sets `STATE_LOG` and sources everything
  itself rather than depending on caller-shell state.
- With retry logic validated in isolation, re-ran it against
  production `track.py` (bypassing the automated retry-count guard
  once, deliberately and knowingly, since the count was inflated by
  the earlier accidental seed rather than reflecting a real second
  failure) — both files recompressed clean and reached `VERIFIED`.
  `bugQueue.md` entry closed.
- Surfaced two related deferred gaps while debugging test isolation:
  reconciliation only counts orphans, never inspects them (why the 2
  corrupted files needed a manual `ffprobe` sweep instead of being
  auto-flagged); and hardcoded paths/config (`STATE_LOG`, `SCRIPT_DIR`,
  Termux-specific shebangs) causing confusing silent failures when a
  shell's environment doesn't carry what every script assumes it will
  — both logged to `issues.md`/`ideas.md` as follow-ups, not built
  this session.
- Adopted git: project had outgrown the "3 simple scripts" assumption
  it started under. Initialized, `.gitignore` for runtime state and
  binary fixtures, baseline commit pushed to GitHub.

## 2026-08-08
- Verified `orphan_status.sh` output against last session's narrative and
  found a mismatch: only 3 of the 26 "orphans" were true orphans (original
  gone, no manifest row) — the other 2 flagged as corrupted last session
  actually still had real originals in `DCIM` and were `VERIFIED`, not
  orphaned. They need normal Pass 3 delete, not manual state writes.
- Integrity-checked all 75 true orphans (72 `.webp` via `dwebp`, 3 `.mp4`
  via `ffprobe`) — all clean.
- Folded all 75 into `archive_manifest.tsv` (2026-03) and `track.py`
  (`DELETED` state, staged path as sole surviving copy) — idempotent
  append loop, verified independently after: `PASS=75 FAIL=0`.
- Hit the Termux `/tmp` permission wall twice more (dwebp error redirect,
  orphan_status.sh output) — same fix as before, redirect to `./`.
  Heredoc paste also proved unreliable mid-session; switched to
  base64+python3 for the data file transfer, which held up clean.
- `2026-03` is now unblocked: manifest has all 84 rows it needs. Next
  `single_month_zipper.sh 2026-03` run zips everything and resolves the
  2 pending Pass-3 deletes.
