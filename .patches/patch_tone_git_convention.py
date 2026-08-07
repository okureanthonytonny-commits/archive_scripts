import sys

path = "docs/tone.md"
with open(path) as f:
    content = f.read()

new_frag = "**Patch scripts commit themselves:**"
if new_frag in content:
    print("SKIPPED (git-commit convention already present)")
    sys.exit(0)

old = '''**Chat-summary usage:** when something looks broken, missing, or'''

new = '''**Patch scripts commit themselves:** any file edit or file creation
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

**Chat-summary usage:** when something looks broken, missing, or'''

if old not in content:
    print("ABORT (tone.md patch): old text not found — file may have changed")
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("WRITTEN (tone.md: patch-scripts-commit-themselves convention added)")
