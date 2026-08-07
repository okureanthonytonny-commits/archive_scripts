import sys

path = "docs/bugQueue.md"
with open(path) as f:
    content = f.read()

new_fragment = "[resolved 2026-08-07] Two files in `2026-03`"
if new_fragment in content:
    print("SKIPPED (ffprobe bug already marked resolved)")
    sys.exit(0)

old = '''## Open

- [open] Two files in `2026-03` (`20260324_080113.mp4`,
  `20260324_080046.mp4`) fail the `ffprobe` duration check in Pass 2
  verify. Pipeline handled it correctly (state `FAILED`, originals not
  deleted) — root cause (corrupt source vs. compressor edge case) not
  yet investigated. See `issues.md` 2026-08-06 entry.

## Deferred

(none currently)'''

new = '''## Open

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
  `tests/fixtures/moov-atom-missing/` before the fix touched them.'''

if old not in content:
    print("ABORT (bugQueue.md ffprobe patch): old text not found — file may have changed")
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("WRITTEN (ffprobe bug marked resolved in bugQueue.md)")
