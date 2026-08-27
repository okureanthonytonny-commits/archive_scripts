# Session 2026-08-27 -- FUS, on-device run + project park

## What happened

- Ran the on-device backlog for `2026-05`/`2026-06`/`2026-07`
  (`2026-08` deliberately excluded as the current month).
- Manifest-path mismatch: `build_manifest.sh`'s relative default
  output (`./archive_manifest.tsv`) doesn't match `MANIFEST`'s
  `$HOME`-anchored default -- silently populated the wrong file,
  pipeline reported "0 files to process" with no error. Fixed with
  explicit `-o ~/archive_manifest.tsv`.
- OOM kill on `2026-05` from unbounded concurrent `ffmpeg` on a 4GB
  device. Fixed with `MAX_PARALLEL_VIDEO=1`. Append-only state design
  held up -- nothing lost, just redone on rerun.
- Orphan reconciliation ran for real on-device for the first time: 3
  orphans across `2026-05`/`2026-06` (all leftover partial `ffmpeg`
  output from the OOM kill), all 3 recovered via
  `ORPHAN RETRY` -> `ORPHAN RECOVERED` and folded into their zips.
  Manually verified (`unzip -l`) and deleted the 3 originals
  afterward, since that code path zips but doesn't auto-delete.
- All three months zip-verified OK. `January-2099.zip` test fixture
  deleted from the real device.
- Confirmed `archive_manifest.tsv` was never committed to git; added
  to `.gitignore` as a precaution (device paths + app-usage patterns
  from folder names like `Pictures/Signal`, `Pictures/WhatsApp` are
  more revealing in aggregate than any single filename).
- Verified final storage: 78% used, down from the 82% baseline
  documented in the README. Investigated old-dated files sitting in
  `DCIM/Camera` (`2025-12` through `2026-03`) that looked like a
  possible delete-failure bug -- confirmed via filename-stem diff
  against `January-2026.zip` that they're restored/new arrivals with
  old EXIF dates, not leftover duplicates. Zero overlap.
- Documented four findings in README.md/architecture.md/issues.md
  rather than fixing the code (post-MVP, project being parked):
  thumbnail-cache junk in `build_manifest.sh`, the manifest-path
  default mismatch, orphan-recovery's no-auto-delete behavior, and
  the closing run `NOTE` being stale (computed before reconciliation
  runs, so it can undercount).
- Refreshed README screenshots to current state (78% storage, latest
  overnight-notification) and moved older screenshots to a
  `docs/images/` pointer instead of inlining everything.

## Current state

- `main`: fully up to date. All doc patches from both 2026-08-26 and
  2026-08-27 landed and pushed.
- Device: `Archives/` has all 8 real months (`2025-12` through
  `2026-07`) plus no test fixtures. `2026-08` in progress, untouched
  by design.
- No open bugs. Every known gap is documented, not fixed, by
  deliberate post-MVP decision.

## Next session

Project is parked. Move to `~/ideas` and `archive_scripts` docs to
review and set up the next queued task, per the original session 16
plan.
