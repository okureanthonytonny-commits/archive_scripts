# Session 2026-08-25 -- FUP/FUS, codespace loss + rebuild, model saga

## What happened

- Session started as "FUP" (mis-stated), corrected to FUS (Freeing Up
  Storage) -- the storage reorg carried forward since 2026-08-10.
- Sidetracked into cleaning loose files in `$HOME`: `exploit.py` and
  `.patches_ideas` explained and moved/removed by user; `gh_cleanup`
  empty, removed; five loose debug files (`actual_stems.txt`,
  `expected_stems.txt`, `actual_march.txt`, `expected_march.txt`,
  `orphan_status.txt`) identified as manual repro evidence for the
  already-fixed orphan extension-mismatch bug (08-18/08-21) -- decided
  to formalize as a real fixture+test (like `moov-atom-missing`)
  before deleting, so the bug's context survives in the repo.
- Discussed a Substack article on code verification (ByteByteGo).
  Connected two points directly to this project: batch-size dilution
  (validates the existing one-file-at-a-time convention) and
  AI-reviewing-AI blind spots (motivated deliberately using a
  different model family than Claude for OpenCode's harness work).
- Decided: architecture/scope decisions happen in chat with Claude;
  writing/testing/revalidation is OpenCode's job going forward, to
  keep Claude's tool-call footprint (and token usage) down to review
  only.
- **Codespace `cuddly-potato-97vq66x7gj7vcx569` (from 08-18) was found
  deleted** -- auto-expired past its retention window. No
  `.devcontainer/devcontainer.json` existed yet, so recreating meant
  redoing setup by hand each time. Fixed by committing a real
  `.devcontainer/devcontainer.json` (Node 24 + `opencode-ai`).
- Recreating surfaced two real devcontainer gaps, each patched
  separately: missing `sshd` feature (`gh codespace ssh` requires it,
  base image lacks it) and missing `gh` CLI (same cause).
- New standing constraint: **user's network will be poor for months**.
  Established a new convention (AGENTS.md pitfall #15): patch scripts
  must retry `git push` with exponential backoff, 3-minute total
  budget, transient errors only.
- Model selection took most of the session's second half:
  - OpenCode Zen's `deepseek-v4-flash-free` (used successfully
    08-18) no longer exists in the current model list -- free-tier
    models rotate.
  - GitHub Copilot Free tier was tried across three different models
    (GPT-5.4 mini, Kimi K2.7/K3 ruled out by research before trying,
    Claude Sonnet 4.6) -- all failed identically ("requested model
    not supported"), pointing to Copilot Free tier not supporting
    third-party tool (OpenCode) access at all, not a per-model issue.
  - "Ox Alpha" (`x-preview-f-free`) and "Big Pickle" on Zen are
    anonymous stealth-preview models with reported launch-week
    instability -- ruled out given user's stated stability
    preference.
  - Settled on **`opencode/nemotron-3-ultra-free`** (NVIDIA, GA since
    Dec 2025, positioned as the reasoning/orchestration tier vs.
    Nemotron 3.5 Lightning's execution tier) -- first model that
    actually completed a task this session.
- First OpenCode dispatch (retry-backoff convention + CONTRACTS.txt
  scope section + devcontainer gh-cli feature) completed: branch
  `test/docs-patches-2026-08-25` pushed, 3 commits, PR link provided
  (gh CLI unavailable in-container at the time of that run).
- Session paused once at 97% context (codespace shut down cleanly,
  nothing lost) and resumed same day.
- **PR review found two structural bugs**: AGENTS.md item #14 got
  split apart by the #15 insertion (header separated from body);
  CONTRACTS.txt got a missing blank line before its new header plus a
  leaked meta-instruction sentence in the actual doc text.
- Attempted fix via non-interactive cherry-pick + Python content
  replacement (to avoid interactive `git rebase -i`/Vim, which had
  already gotten stuck once this session). The CONTRACTS.txt content
  replacement's assertion failed (content didn't match expected
  exactly), and a subsequent manual `commit --amend` landed on the
  wrong commit (the sshd commit, not the CONTRACTS.txt commit),
  producing a corrupted local branch state.
- **Recovered by discarding local state and re-fetching origin**,
  which was never pushed to and remains the original (still-buggy but
  coherent) 3-commit branch. Local repair deferred to next session
  rather than risk further corruption end-of-session.

## Current state

- PR branch `test/docs-patches-2026-08-25` exists on origin, unchanged
  from its original 3 commits. Still has the two known structural
  bugs (AGENTS.md splice, CONTRACTS.txt formatting/leaked sentence).
  Not merged. Not yet fixed.
- `.devcontainer/devcontainer.json` on `main`: Node 24, `opencode-ai`,
  `sshd` feature. (`gh-cli` feature is only on the unmerged branch.)
- Codespace `laughing-bassoon-x569rr45gr9wc67v` exists, attached to
  the PR branch, currently shutdown (not deleted).
- Model for OpenCode work going forward: `opencode/nemotron-3-ultra-free`.

## Next session

1. Fix the two PR bugs properly (AGENTS.md splice, CONTRACTS.txt
   formatting) -- redo the non-interactive cherry-pick approach, or
   have OpenCode itself redo the two commits cleanly from scratch
   instead of trying to graft fixes onto history that already caused
   one accident.
2. Merge the PR once clean.
3. The three fixture+test OpenCode dispatches, in the agreed risk
   order: reconciliation-states (`STUCK`/`GHOST`/`ORPHAN`) first,
   then orphan extension-mismatch (closes out the five loose debug
   files), then `--exclude`/`--include` parsing.
4. Original FUS goal, still not started: `archive_*` dirs out of
   `$HOME`.
5. Watch whether `nemotron-3-ultra-free` remains available/stable
   across the next few dispatches -- first real session using it.
