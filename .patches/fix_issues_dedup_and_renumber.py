import pathlib

path = pathlib.Path.home() / "archive_scripts" / "docs" / "sessions" / "issues.md"
text = path.read_text()

patches = [
    (
        "de-dup ffprobe entry, now tracked in bugQueue.md",
        '''**2. Two real `ffprobe` verify failures in `2026-03` — now tracked in `bugQueue.md`**
- Handled correctly by the pipeline (state `FAILED`, originals
  preserved) — see `bugQueue.md` for the open root-cause item.

''',
        '''**2. Two real `ffprobe` verify failures in `2026-03` — handled correctly, cause not investigated**
- `20260324_080113.mp4` and `20260324_080046.mp4` failed the duration
  check in Pass 2. Pipeline behaved exactly as designed: state set to
  `FAILED`, `delete.sh` correctly skipped removing the originals. Not
  yet looked into why these two specifically failed (corrupt source
  files vs. a compressor edge case) — low priority since the pipeline
  already handled it safely.


''',
    ),
    (
        "renumber Deferred gaps from duplicate 2 to 3",
        "**3. Deferred gaps (see `ideas.md` and `architecture.md` for reasoning)**",
        "**2. Deferred gaps (see `ideas.md` and `architecture.md` for reasoning)**",
    ),
]

for name, new_fragment, old_fragment in patches:
    if new_fragment.strip() in text and old_fragment not in text:
        print(f"SKIPPED ({name})")
        continue
    if old_fragment not in text:
        print(f"ABORT ({name}) — old text not found, no write")
        continue
    text = text.replace(old_fragment, new_fragment, 1)
    print(f"WRITTEN ({name})")

path.write_text(text)
