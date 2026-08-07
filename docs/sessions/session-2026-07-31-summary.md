# Session 2026-07-31 — Archive Pipeline: First Real Run + Two Bugs Fixed

## What happened, in order
1. `archive_compress.sh` was missing from device (docs said it was
   delivered last session — it wasn't). Rebuilt it from `common.sh`,
   `compress.sh`, and `architecture.md`, confirmed consistent.
2. First run of `archive_run_all.sh 2026-04` hit two bugs:
   - `df -m` unsupported on Termux's `df` → switched to `df -k` + math.
   - `zip` binary missing → `pkg install zip`.
3. Re-run completed 2026-04 end-to-end: 152 files, 4511MB → 564MB
   (~87.5% reduction), zip verified, staging cleared.
4. Manual check (`unzip -l` file count vs `OK_*` log count) surfaced a
   real bug: `SKIP_RESUME` returned before the verify+delete step, so
   resumed files' originals were never deleted even after a
   zip-verified success. Fixed in `compress.sh` — resume now only
   skips re-compression, still falls through to verify+delete.
5. 39 stuck originals from 2026-04 manually deleted after confirming
   they were already safely inside the verified zip.
6. Added `set_state()` to `common.sh` — single-line overwrite status
   file (`~/archive_scripts/.state`) for crash/kill recovery, following
   the `gh run list`-style "check current state directly" pattern
   rather than reconstructing from logs.
7. Decided completed-months tracking needs no new file — the zip in
   `/storage/emulated/0/Archives/` is already the ground-truth marker.
8. Attempted 2026-03 as second test month (chosen as smallest
   remaining, ~4.1GB) to exercise the SKIP_RESUME fix live:
   - First attempt: killed intentionally, but died before any file
     processed — SKIP_RESUME path never triggered.
   - Second attempt: whole tmux server died mid-run, unexplained.
     Termux battery was already Unrestricted (ruled out). Phone
     uptime was 3d23h (ruled out reboot). Load average at time of
     check: 25.23 — high, possibly relevant, not confirmed as cause.
   - Also logged spurious "missing on disk" entries for files
     manually confirmed to still exist on device.
9. Created `docs/issues.md` (didn't exist before) to hold both
   unresolved 2026-03 mysteries plus a note that SKIP_RESUME is fixed
   but still unverified in a live resume scenario.
10. Backfilled `progress.md`, updated `architecture.md` (added
    `set_state()`, the resume-fix note, and the two new gotchas).

## State at handoff
- **2026-04**: done. Compressed, zipped, verified, staging clear.
- **2026-03**: attempted twice, crashed both times before completing.
  Check `archive_staging/2026-03` for partial state before retrying.
- **2025-12, 2026-01, 2026-02**: not started.
- `compress.sh` SKIP_RESUME fix: applied, not yet exercised live.

## Immediate next step
Don't re-run 2026-03 blind. First either:
(a) watch `load average` live during a run to see if it spikes before
    the crash, or
(b) check `logcat`/`dmesg` around a kill if still in buffer, or
(c) just retry once more with closer monitoring — if it survives this
    time, the SKIP_RESUME fix gets tested for free on resume.

Read `docs/issues.md` before touching anything else.
