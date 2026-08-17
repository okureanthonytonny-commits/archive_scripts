AGENTS.md — codebase context for an AI agent working in archive_scripts

WHAT THIS FILE IS
Project/codebase context: what this is, how to run it, how it's laid
out, and what tends to go wrong when patching it. For communication
style (how to talk to Tonny), see tone.md — that's a separate concern
and stays there. For exact function/file call relationships (by-name
vs by-path, which renames are safe), see CONTRACTS.txt.

---

## Repo

https://github.com/okureanthonytonny-commits/archive_scripts

## What this is

Compresses and archives phone media to usable quality, running
entirely in Termux on a Samsung A16. State-tracked, resumable,
crash-safe pipeline — full reasoning and history in
docs/architecture.md and docs/sessions/.

## Dev commands

Build the manifest (scan real dirs, list what would be archived):
  ./build_manifest.sh --include DIR [DIR2 ...] --exclude DIR [...]

Run one month by hand:
  ./single_month_zipper.sh YYYY-MM

Run several months, stop-on-systemic-failure:
  ./multi_month_zipper.sh [YYYY-MM ...]

Run unattended overnight (wake-lock + tmux + notification):
  ./run_overnight.sh [YYYY-MM ...]

Preflight checks before a real run:
  bash tests/diagnostics/check_deps.sh     # required/optional external tools
  bash tests/diagnostics/check_files.sh    # required repo files present
  bash tests/diagnostics/orphan_status.sh YYYY-MM   # per-file staged/state status

Tests:
  bash tests/run_retry_test.sh             # retry-on-FAILED, isolated STATE_LOG, no real deletes
  bash tests/env_sanity_test.sh            # interactive: real device dirs, .env/--include/--exclude, dummy manifest only

## Architecture, short version

Three-pass pipeline per file, two barriers, resumable at any point:

  PENDING -> COMPRESSED -> VERIFIED -> DELETED
                        \-> FAILED (retried up to a cap before giving up)

Pass 1 compress (parallel, MAX_PARALLEL_VIDEO) -> wait -> Pass 2 verify
(parallel, MAX_PARALLEL_VERIFY) -> wait -> Pass 3 delete (only if still
VERIFIED). Every pass re-checks current state before acting, so a
crashed/resumed run is safe by construction — never trust in-place
state, always re-derive from the last row in state_log.tsv.

Full walkthrough with the "why" behind each barrier: docs/architecture.md.

## Key files

| File | Role |
|---|---|
| `build_manifest.sh` | scan real dirs -> archive_manifest.tsv (pre-pipeline step, not in architecture.md's pass diagram) |
| `multi_month_zipper.sh` | orchestrator — loop months, circuit-breaker on systemic failure |
| `single_month_zipper.sh` | worker — one month -> zip |
| `run_overnight.sh` | unattended wrapper — wake-lock, tmux, notify, self-close |
| `lib/config.sh` | reads .env, exports every config var with its fallback default |
| `lib/common.sh` | log(), set_state(), check_space() |
| `lib/single_file_compressor.sh` | compressor_process() — one file in, one file out |
| `lib/verify.sh` | verify() — decode-check + gate reason |
| `lib/delete.sh` | delete() — remove original iff VERIFIED |
| `lib/multi_file_pipeline.sh` | process_month() — the 3-pass loop + 2 barriers |
| `lib/track.py` | state_log.tsv reader/writer, CLI — the one source of truth |
| `lib/summary.py` | derives FILE_LOG from state_log.tsv, pure query |

Full call-by-call reference (by-name vs by-path, safe-to-rename or
not) plus every script's valid CLI forms and exact violation messages:
`docs/CONTRACTS.txt`.

## Common pitfalls

1. **Verify path before patching** — don't assume from memory; `find`/
   `ls` first, then patch against the confirmed path.
2. **Heredoc delimiter must be unique to the whole payload**, not just
   different from `EOF` — a doc file containing literal `EOF`/
   `INNER_EOF` text as an example closes the heredoc early the instant
   bash scans past that line.
3. **4-backtick outer fence** if delivered content has its own
   3-backtick code blocks — CommonMark only closes a fence on a
   matching-or-longer backtick run, so 3-in-3 is ambiguous but
   4-outer/3-inner never is.
4. **`/tmp` isn't writable in Termux** for the shell user
   (`drwxrwx--x`) — use an in-repo scratch path instead, removed after
   use.
5. **Byte drift check before assuming a match failed** —
   `sed -n 'Np' file | cat -A` before falling back; trailing
   whitespace and curly quotes/em-dashes don't render visibly in plain
   `view`/`sed` output but break an exact string match.
6. **Re-upload beats re-paste** after a failed match — paste round-
   trips through markdown rendering and introduces the exact drift
   byte-check #5 catches.
7. **Idempotency by default, every patch** — check for the new-state
   fragment first (`SKIPPED` if found), then the old-state text
   (`WRITTEN` if found and replaced), else `ABORT`. Never re-run a
   patch blind after a dropped session.
8. **Patch scripts commit + push + self-delete themselves** —
   `.patches/` should be empty between sessions. `SKIPPED` and
   confirmed-already-in-sync outcomes self-delete too, not just
   `WRITTEN`; only `ABORT` leaves the script behind for inspection.
9. **Large file content -> staged heredoc, not one giant Python
   string** — a full-file overwrite embedded as one long
   `new_content = '...'` line is fragile to paste into a mobile
   terminal. Stage the actual content as its own multi-line heredoc,
   then a short Python wrapper does the SKIPPED/WRITTEN/git logic
   against the staged file.
10. **Never base64/obfuscate to route around a delivery problem** —
    tried once for a corruption issue; made the message look like it
    was hiding code from inspection and tripped a safety classifier
    mid-session. Any delivery-friction problem gets solved with plain,
    readable text.
11. **Quoted heredocs (`<< 'EOF'`) pass bytes through literally** — a
    Python string literal needs exactly one backslash to become a real
    newline (`"\n"`, not `"\\n"`) when written inside a quoted
    heredoc; doubling it out of habit writes the literal two-character
    text into the file instead. Caused a real `.gitignore` corruption
    once — check delivered file output for stray literal `\n`/`\t`
    text as part of the normal post-write look, not just `bash -n`.

12. **Preferred patch-delivery format: single artifact, heredoc-wrapped,
    self-running** — one `.sh` artifact containing `mkdir -p .patches`,
    then `cat > .patches/patch_name.py << 'UNIQUE_EOF' ... UNIQUE_EOF`,
    then the `python3 .patches/patch_name.py` call, all in one block.
    Copy-paste straight into Termux with no separate save-then-run
    step. Supersedes delivering the raw `.py` as its own artifact plus
    typed instructions.
13. **Self-delete a patch script with plain `rm`, not `git rm -f`** —
    `.patches/*` is itself gitignored (see `.gitignore`), so a patch
    script is never tracked in the first place; `git rm -f` on it
    fails with "pathspec did not match any files" and aborts the
    script before the push-of-self-delete step. Use `os.remove(path)`
    (or plain `rm` in shell) instead, no `git add`/`git rm`/commit
    needed for the delete itself.
14. **Check `.gitignore` before treating an untracked file as a
    problem** — an untracked file in `git status` isn't automatically
    an anomaly needing manual cleanup; check whether it's a
    known-regenerable artifact (test scratch output, runtime state)
    that belongs in `.gitignore` instead.

This list grows as new mechanics bite us — add an entry, don't just
fix and move on.

## End-of-session checklist

Before wrapping up a session that touched code or docs:
1. Session summary file — `docs/sessions/session-YYYY-MM-DD-summary.md`.
2. `docs/sessions/progress.md` entry — append-only narrative, what
   happened and why.
3. `docs/bugQueue.md` sweep — any new reproducible bug goes in Open
   (or straight to Resolved if fixed same-session); anything stale
   gets removed.
4. `docs/sessions/issues.md` sweep — capability gaps, design
   proposals, deferred items; update the "Status snapshot at handoff"
   section at the bottom.
5. `git status` / `git log` — confirm nothing's staged-but-uncommitted,
   `.patches/` is empty, `origin/main` is up to date.

Not every session needs all five — a small doc tweak doesn't need a
progress.md entry of its own. Use judgment; the point is not leaving
a session's reasoning trapped in chat history where the next cold
session can't reach it.
