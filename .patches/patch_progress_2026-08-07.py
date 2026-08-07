import sys

path = "docs/sessions/progress.md"
with open(path) as f:
    content = f.read()

changed_any = False

# --- Edit 1: update the session handoff note ---
new_frag_1 = "**Note for session 7:**"
if new_frag_1 in content:
    print("SKIPPED (session-7 handoff note already present)")
else:
    old_1 = '''- **Note for session 6:** `2026-03` has 26 files physically staged
  (from an abandoned pre-rewrite run) with no `DELETED` entry backing
  them and no surviving originals in `DCIM`. Verify they aren't
  corrupted (`ffprobe -v error`), fold them into the manifest, then
  re-run `single_month_zipper.sh 2026-03` to complete the month.'''
    new_1 = '''- **Note for session 7:** `2026-03` still has 24 clean video orphans
  + all `.webp` orphans (from the same abandoned pre-rewrite run,
  see 2026-08-07 below) needing manifest fold-in before
  `single_month_zipper.sh 2026-03` can complete the month. The 2
  corrupted orphans from that batch are resolved.'''
    if old_1 not in content:
        print("ABORT (progress.md edit 1: handoff note): old text not found")
        sys.exit(1)
    content = content.replace(old_1, new_1)
    changed_any = True
    print("WRITTEN (progress.md: session-7 handoff note updated)")

# --- Edit 2: append 2026-08-07 narrative ---
new_frag_2 = "## 2026-08-07"
if new_frag_2 in content:
    print("SKIPPED (2026-08-07 section already present)")
else:
    addition = '''

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
  binary fixtures, baseline commit pushed to GitHub.'''
    content = content.rstrip("\n") + addition + "\n"
    changed_any = True
    print("WRITTEN (progress.md: 2026-08-07 narrative appended)")

if changed_any:
    with open(path, "w") as f:
        f.write(content)
