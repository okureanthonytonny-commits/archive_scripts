# Session 2026-10-30 -- storage audit, leftover Jan-Mar originals

## Starting point

- Files app reports ~85% storage used. Monthly totals looked off, and
  January files the owner expected to be deleted showed in Recents.
- Goal: see what is using storage, then find out why originals remain.

## What happened

- Shared storage is 37G: `Archives` 16G, `DCIM/Camera` 12G, `Android`
  7.4G, `Movies` 1.6G. The Termux home is only 413M (`.npm` 249M).
  The rest of the 85% is apps and system data, which Termux cannot see.
- `Camera` still holds 477 pre-April files: 1 from 2025-12, 137 from
  2026-01, 153 from 2026-02, 186 from 2026-03 (~10.4G). Zips exist for
  all of those months.
- Zero filename overlap with any zip. Compare stems, not names:
  originals are `.jpg`, zip entries are `.webp`. So these are not
  duplicates of archived files. They are files no run ever listed.
- January's 212 listed files, 212 zip entries and 212 file-log rows
  agree. The run list is every manifest row tagged with the month
  (`awk` in `single_month_zipper.sh`), so the leftovers were not in
  the manifest the run used.
- Run logs, files listed vs originals still on disk: 2025-12 628 / 1,
  2026-01 212 / 137, 2026-02 100 / 153. 2025-12 and 2026-02 ran the
  same day (Aug 10), so one stale manifest does not explain it alone.
  The 2026-03 log header found is from the abandoned Jul 31 run and
  was not compared.
- Changed time (ctime) updates on rename here (tested, 2.1 s apart).
  472 of the 477 leftovers have ctime within 60 s of mtime: untouched
  since capture. 5 were touched later (including `20251214_121811.jpg`,
  ctime Jan 4). So the leftovers were on disk during the runs. The
  2026-08-27 note calling them "restored/new arrivals" is not
  supported by this.
- `build_manifest.sh` is not what built the Aug 3 manifest: git
  history starts Aug 7 and the script appears from Aug 12. The code
  that built the manifest for the Aug runs is not in the repo.
- Termux was reinstalled (F-Droid build) from a backup. Verified after:
  repo clean at `83b3897`, `.env` present, `.state_log.tsv` present
  (12,643 rows, last write Oct 16), ffmpeg/ffprobe/python/zip/unzip
  installed. Restored files have a new owner and whole-second mtimes.
- Rerun semantics (from the 2026-10-16 summary): `multi_month_zipper.sh`
  skips a month whose zip exists. `single_month_zipper.sh` appends to
  the zip but would likely raise a false GHOST anomaly. Neither was
  tried on these months.

## Open items

- Find why the manifest missed these files. Compare row order in
  `~/archive_junk/archive_manifest.tsv` (Aug 26 copy) and
  `~/archive_manifest.bak-20261016.tsv`: leftovers appended in a later
  batch than the archived rows, or interleaved?
- Look at the 5 files touched later, and at `.temp-20260213_073614097_BACK`
  in `Camera`.
- Compare the later 2026-03 runs' listed counts with the 186 leftovers.
- Decide how to archive the 477 files. Not decided. Do not rerun
  2026-01/02/03 until that is settled.
- Correct the 2026-08-27 "restored/new arrivals" note in
  `progress.md` and `issues.md`.
- 2026-09 (66 files) and 2026-10 (20 files) not run yet.
- Not investigated: `Android` (7.4G) and the ~70G outside shared storage.
