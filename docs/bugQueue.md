# bugQueue.md

> **Navigation:** [tone.md](tone.md) · [progress.md](sessions/progress.md) ·
> [issues.md](sessions/issues.md)

Live list of confirmed, reproducible bugs only. For capability gaps,
design proposals, and process/doc tasks, see
[issues.md](sessions/issues.md). Unlike `progress.md` (append-only
narrative), this file is mutable — edit in place, remove a line when
it's resolved.

## Format

Each entry:
- [status] Short description — link to fuller doc if one exists
Status: `open` (known, not started) · `deferred` (known, intentionally
not next)

---

## Open

(none currently)

## Deferred

(none currently)

## Resolved

- [resolved 2026-08-07] Two files in `2026-03` (`20260324_080113.mp4`,
  `20260324_080046.mp4`) failed the `ffprobe` duration check in Pass 2
  verify (`moov atom not found`). Root cause: interrupted/truncated
  write during the abandoned 2026-07-31 pre-rewrite run — confirmed by
  checking the real originals in `DCIM` with `ffprobe`, which decode
  clean. Sources were never corrupt; only the staged compressor output
  was. Fixed by building retry-on-`FAILED` logic (see `issues.md`
  2026-08-07 entry) and running it against these two files: stale
  staged output cleared, recompressed from the clean source,
  re-verified, both now `VERIFIED` in production `track.py`. Broken
  staged copies preserved as regression fixtures at
  `tests/fixtures/moov-atom-missing/` before the fix touched them.
