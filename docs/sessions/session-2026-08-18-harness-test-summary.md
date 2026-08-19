# Session summary -- 2026-08-18 (harness test)

## Goal
Set up GitHub Codespaces to run an AI coding agent, after Aider and
OpenCode both failed to install natively on Termux (Samsung A16) --
psutil has no Android wheel (Aider), aarch64 binary isn't Android-ABI
compatible (OpenCode). Test on a real backlog task, not a scratch
throwaway. Full prior tooling context in
~/ideas/workflow/coding-harness-decision.md.

## What happened
- Created a private 2-core Codespace on archive_scripts (needed
  `gh auth refresh -h github.com -s codespace` first -- default token
  scope doesn't include Codespaces).
- Confirmed Node v24.14.0 (in the 18-24 supported range).
- Installed Claude Code (v2.1.234) but had no subscription and
  limited funds (~UGX 13k) for Console/API billing -- backed out of
  that OAuth flow, no cost incurred.
- Installed OpenCode (v1.18.18) instead -- real x86_64 Ubuntu means
  neither original harness blocker applies here; re-evaluated Aider
  vs OpenCode fresh rather than defaulting to the prior Termux-era
  choice. Picked OpenCode: matches preferred working style (let it
  work freely, review closely only at flagged high-risk logic,
  rubber-duck elsewhere) over Aider's diff-approval-per-change loop.
- Ran `opencode/deepseek-v4-flash-free` -- genuinely free, no billing
  needed.
- Scoped task: issues.md open item 4, orphan enumeration through
  verify(). Agent read AGENTS.md + issues.md first, then caught that
  the doc was stale before proposing a plan -- commit d55a1f4 had
  already partially implemented it same-day. Real remaining gap was
  narrower: orphans bypassed the real verify() (no state tracking),
  and FAILED orphans didn't fold into retry-with-guard.
- Work done on branch `test/orphan-enum-review` (pushed, not merged --
  new convention: test branch per harness session, merge only after
  review). PR #1 opened for diff visibility.
- Manual review of the two risk-zone files (lib/verify.sh,
  lib/orphan_reconcile.sh) caught a real gap: the FAILED-orphan retry
  path re-ran verify_orphan() on the same stale staged output instead
  of deleting it and recompressing from the original first, unlike
  Pass 1's real retry. Fix queued, blocked on free-tier quota reset
  (~10h40m) before it could be sent.
- Stopped the Codespace to conserve free-tier core-hours (120/month
  at 2-core = 60hrs runtime) while waiting on the quota reset.

## Findings
1. Codespaces + OpenCode is a working harness path, unblocking the
   Termux dead-end (full writeup in coding-harness-decision.md).
2. `opencode/*-free` models have a real daily/usage cap -- hit it
   mid-task. Not unlimited; plan sessions around it.
3. issues.md staleness: doc claimed an item "unchanged" when code had
   already moved same-day (logged in issues.md itself this session).
4. Review-before-merge caught a real bug that would otherwise have
   shipped -- validates the test-branch-per-session convention, not
   just process overhead.

## Status
- `test/orphan-enum-review` pushed, PR #1 open, not merged -- pending
  the retry-recompress fix.
- Free-tier quota resets ~10h40m from this session's end.
- Codespace `cuddly-potato-97vq66x7gj7vcx569` stopped.

## Next session
1. Resume Codespace, re-run OpenCode with the retry-recompress fix
   prompt (already drafted, held in chat).
2. Update CONTRACTS.txt, architecture.md, issues.md, and the
   2026-08-18 session summary (on the test branch) once the fix is in.
3. Review the fix, then decide on merging test/orphan-enum-review to
   main.
4. Backlog untouched: storage reorg out of $HOME, tmux/wake-lock
   relaunch dedup.
