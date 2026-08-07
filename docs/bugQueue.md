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

- [open] Two files in `2026-03` (`20260324_080113.mp4`,
  `20260324_080046.mp4`) fail the `ffprobe` duration check in Pass 2
  verify. Pipeline handled it correctly (state `FAILED`, originals not
  deleted) — root cause (corrupt source vs. compressor edge case) not
  yet investigated. See `issues.md` 2026-08-06 entry.

## Deferred

(none currently)
