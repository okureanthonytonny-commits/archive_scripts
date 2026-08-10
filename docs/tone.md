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

**Verify the path before patching.** Don't assume a file's location
from memory, a prior session, or another project's layout — projects
here have different structures (this bit us: `tone.md` assumed at
root, actually under `docs/`). `find`/`ls` first, then patch against
the confirmed path.

### File delivery convention

`.patches/` is the default scratch location for one-off delivery/patch
scripts — never `$HOME` or the project root. That's the one place to
check for anything mid-run or left behind.

Paths inside a patch script should be relative to `~` (or given in
full), not relative to whatever directory a prior session said it was
"in" — that's stale info once a session is cold. `cd ~/project_name`
first, or use the full path.

**Heredoc delimiter must be unique to the outer shell call** — if the
content being written itself contains an example heredoc (like the
skeleton below), give the outer `cat` a different terminator than any
delimiter appearing inside the content, or bash closes the outer
heredoc early at the first inner match. (Learned the hard way,
2026-08-10.)

**New file (nothing to check against):**
~~~bash
cat > <path> << 'EOF'
<content>
EOF
~~~
If `<content>` itself contains a triple-backtick fence, wrap the whole
delivery in a 4-backtick outer fence instead of 3 — nested 3-tick fences
break markdown rendering (see QA.md 2026-07-08).

**Editing an existing file — patch script skeleton:**
~~~bash
cat > .patches/<name>.py << 'INNER_EOF'
import subprocess, os

path = "<path, e.g. docs/tone.md>"
new_fragment = "<unique string only in the NEW state>"

with open(path) as f:
    content = f.read()

if new_fragment in content:
    print("SKIPPED (<change name> already present)")
else:
    old = '''<exact old text>'''
    new = '''<exact new text>'''

    if old not in content:
        print("ABORT (old block not found)")
    else:
        content = content.replace(old, new)
        with open(path, "w") as f:
            f.write(content)
        print("WRITTEN (<change name>)")

        subprocess.run(["git", "add", path], check=True)
        diff = subprocess.run(["git", "diff", "--cached", "--", path], capture_output=True, text=True).stdout
        if "<new_fragment>" in diff:
            subprocess.run(["git", "commit", "-m", "<commit message>"], check=True)
            print("Committed.")
            os.remove(__file__)
            print("Patch script removed.")
        else:
            print("git diff did not confirm the expected change — not committing.")
INNER_EOF
python3 .patches/<name>.py
~~~

If `ABORT` — don't retry with a tweaked match. Fall back to the
new-file template above with the complete new content instead. Costs
more tokens but is safe.

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

Once `WRITTEN` prints, confirm with `git diff` before committing, then
delete the script — don't keep it around after. `.patches/` predates
git and was doing git's job by hand (the only record of what changed
and why); now the commit itself is that record, searchable and
permanent, so the script's only remaining value is the run itself.
The `SKIPPED`/`WRITTEN`/`ABORT` check stays exactly as-is — it's still
a better automated safety net than eyeballing a diff by hand before
running. It's specifically the *file*, post-commit, that's now
disposable. The script does this itself, not as separate manual
steps: writes, confirms via `git diff` the diff actually contains the
intended change (not just that *a* write happened), then `git add` +
`git commit` on just the file(s) it touched, prints confirmation, then
deletes itself (`os.remove(__file__)`). One run, no manual follow-up
commands. The patch script is never `git add`ed itself — it does its
job and removes itself before anything would track it, so `.patches/`
stays empty between sessions rather than accumulating.

**Chat-summary usage:** `archive_scripts` has no `INDEX.md` (that
convention is from the Ledger project only). When something looks
broken, missing, or untested, check `docs/sessions/` directly --
summaries are named `session-YYYY-MM-DD-summary.md`, most recent last
alphabetically. Read the relevant one as a starting point before
re-deriving from scratch. Doesn't replace verification -- checking
code, running it, or a screenshot is still the normal next step when
it matters.

**End-of-session checklist:** no `INDEX.md`/`rules.md` in this
project, so no draft checklist to point to. Informal checklist before
wrapping up: session summary file, progress.md entry, bugQueue.md/
issues.md sweep, git/CI status.

**JWT territory:** we never build within one continuous context
window — each session/chat starts cold. So every patch script, log
message, exit code, and commit message needs to carry enough of its
own context to be understood on its own, like a JWT carries its own
claims instead of relying on server-side session state. Don't write
something that only makes sense if the reasoning from *this* chat is
still in the room — a future session (or future Tonny at 6am) should
be able to read a log line or commit message cold and know what
happened and why, without re-deriving it.
