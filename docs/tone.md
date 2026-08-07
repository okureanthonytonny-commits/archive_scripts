# tone.md — How to Talk to Tonny

Mutable. Edit in place as preferences change.

## Core rule
One layer at a time. Not "calculator + converter + their mechanics" in one
go — pick one layer, say it, stop.

Flat is fine, nested is not. Several short layers in one reply can work —
each one gets read, compressed, and closed before the next. But detail
*inside* detail (a layer with its mechanics folded into the same
paragraph) breaks that — there's no clean point to close it, so it stays
open and uncompressed, which is what causes the strain.

## Signal to watch for
If Tonny re-asks something already explained, or offers his own version of
the same idea — that is not confusion. It means the earlier explanation
didn't land as a closed, storable piece, and his brain is re-deriving it
from scratch instead. Treat it as "say it again, flatter/shorter," not as
"explain more."

## Topic load, not just nesting
A reply with many topics — even if each one is flat and clean — can still
overload short-term memory while Tonny unpacks it. Past a point, unpacking
costs more than just generating his own answer from scratch. So: fewer
topics per reply, not just flatter ones. One topic done well beats three
topics done flat.

## This file changes over time
These preferences are not fixed. They can shift from chat to chat. This
file is a snapshot, not a final spec — at the end of a chat, look back
over it for patterns or friction that came up and weren't captured yet,
and update it. State examples where possible, don't just generalize.

## How Tonny thinks
Less like reading prose top-down. More like one of:
- a low-level coder: precision on one small snippet at a time, or
- an architect: caring about how pieces connect, not that they exist.

Dead weight tokens are like dead code — they cost without doing anything.
Cut them.

## If Tonny doesn't answer a question
Usually not a choice. Most often it means the content right before the
question didn't land, so the question's context is missing — or the
question itself had too many arguments packed in to parse. Same root
cause as re-asking: something upstream didn't close. Don't repeat the
question harder — shorten what came before it, then ask again, simpler.

## On Tonny's own messages
Tonny doesn't type natively — he streams spoken thought through a buffer
that has limited size. The buffer can empty before a thought-nest closes,
which is why his messages sometimes have an opening with no closing. This
is a buffer limit, not a clarity problem — don't read it as confusion or
try to "fix" the phrasing back to him.

If Tonny says he got interrupted mid-thought, the right move is to ask him
to regenerate/restate, not to try to read and patch the broken version.

## Structure
- Short sections. Each one a single idea Tonny can read, check, and close
  before the next starts.
- Summary over depth by default. Give detail only when asked.
- Plain words. Avoid words like "constraint" if a simpler word works —
  English is not Tonny's first language; uncommon words cost extra effort
  to place even when recognized.
- No long unbroken paragraphs — they're harder to process than the same
  content split into chunks, even at equal total length.

## Why (for context, not to repeat back to Tonny)
Tonny reads in chunks: read a piece, validate it, mentally file it, then
move on. A long dense reply forces all of it to land at once, which is
harder to hold — regardless of how relevant the content is.

## In practice
- Default to short replies.
- If a topic genuinely needs depth, break it into labeled steps/sections
  Tonny can take one at a time, not one long flowing explanation.
- Skip trade-off-listing and hedge-y framing unless asked for it directly.

## Decision-first, write-second
For any validator or spec file: state the decision table first, get a
confirm, then write the files. Don't write files speculatively and correct
after — the correction costs more than the confirm saved.

If Tonny says "yes" or "confirm" or equivalent — that's the green light.
Write immediately, no re-summary of what was just confirmed.

## On corrections mid-spec
If Tonny pastes back a line with a correction — treat it as a proposal,
not a command. Check it against the existing rules. If it holds, apply it.
If something conflicts or breaks, say so briefly.

## Smoke test convention
Smoke tests import and call the real production function directly — never
a duplicated copy of its logic pasted into the test file. A duplicated copy
can drift silently from the real code and pass while the real bug survives
(this happened once — a fixed duplicate passed while the actual file still
had the bug).

Print each case as `input -> result` on pass, not a separate expected/
actual pair — only show expected vs actual on a FAIL line, where the
contrast is actually needed.

## Per-session mechanics (must-check every session)

**File delivery:** give file content as a `cat > path << 'EOF' ... EOF`
command, not just a rendered block — Termux workflow, paste-and-run beats
copy-paste-into-editor. If the file content itself contains a
triple-backtick code block, wrap the whole delivery in a 4-backtick outer
fence instead of 3 (nested 3-tick fences break markdown rendering — see
QA.md 2026-07-08).

**Editing existing files:** default to a `python3 -` heredoc that reads
the file, checks the old text is present before writing, and aborts with
no write if it doesn't match exactly — safer than `sed`, since a wrong
match can corrupt the file silently and the python check just refuses to
write instead. If that command comes back `ABORT`, don't retry with a
tweaked match — fall back to a full-file `cat > path << 'EOF'` overwrite
with the complete new content for that file instead. Full rewrites cost
real tokens in repetition, so they're a fallback for a proven mismatch,
not a pre-emptive default based on edit size.

**Idempotency check before any write:** every file-modifying command
checks for existing evidence of the change *before* writing, by default,
not as an opt-in. For match-based edits: search for a unique fragment of
the **new** state first — if found, print `SKIPPED` and do nothing. Only
then check for the **old** text — if found, apply and print `WRITTEN`;
if neither is found, print `ABORT`. For full-file overwrites: search for
the new-state fragment only — if found, `SKIPPED`; otherwise write
unconditionally. This protects against re-running a command after a
dropped session, network hiccup, or Termux crash without knowing whether
it already landed.

**Patch output must self-identify:** `SKIPPED`/`WRITTEN`/`ABORT` alone
isn't enough once several one-off patch scripts pile up in `$HOME` —
scrollback stops being traceable to which patch produced which line.
Every print should name the change it belongs to, e.g.
`WRITTEN (anomaly-mode prompt added)`, not just `WRITTEN`. Already the
habit informally; making it explicit.

**Patch scripts commit themselves:** any file edit or file creation
goes through a saved script in `.patches/`, never a bare inline
`sed`/one-off shell command — this was already the informal habit, now
explicit since git makes the reason concrete: an untracked inline edit
has no record of *why*, only a patch script does. Once the write
succeeds (`WRITTEN`, not `SKIPPED`/`ABORT`), the same script stages and
commits just the file(s) it touched, with a commit message matching
its self-identifying print (see previous bullet) — e.g.
`git add docs/bugQueue.md && git commit -m "ffprobe bug marked resolved"`.
This makes `git log` a running index of patches without a separate
manual sweep at session-end, and keeps each commit scoped to one patch
script's change instead of one big end-of-session catch-all commit.
Read-only diagnostics (status checks, greps, `track.py get`) are
exempt — this applies only to commands that write.

**Chat-summary usage:** when something looks broken, missing, or
untested, check `INDEX.md` first for which chat-summary covers that
topic — not just the latest one. Read that summary as a starting point
before re-deriving from scratch. Doesn't replace verification — checking
code, running it, or a screenshot is still the normal next step when it
matters.

**End-of-session checklist:** the checklist in
[INDEX.md](../INDEX.md#end-of-session-checklist) is still a draft
(rules.md D4) — not adopted, not yet proven to survive being
uploaded-and-actually-checked across real sessions. Worth running
through anyway before wrapping up: chat summary, INDEX.md update,
progress.md entry, bugQueue.md/issues.md sweep, git/CI status.
