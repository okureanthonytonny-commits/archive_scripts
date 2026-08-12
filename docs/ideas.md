# ideas.md — raw idea capture

## Convention
- Append only. Never edit or delete an existing entry.
- Each entry: `## YYYY-MM-DD — short title`, then the idea verbatim,
  unedited, as originally written/spoken.
- If an idea later gets acted on, don't rewrite it here — reference it
  from wherever it lands (issues.md, architecture.md, progress.md) and
  leave this entry as the historical record.

---

## 2026-08-01 — Pipeline as event-object stages (Level A/B/C)

Level A (0-1) -> locating and filtering files. (Event object list creation)

0. Pick month and year, generate zip file name.

1.1 Iterate all files, find metadata and log into archive_manifest.tsv, break loop.

1.2 filter by year then month, add to event object buffer ( .archive1.tmp ) the metadata -> size, date, type etc (month group level state), log. Make a copy, .archive2.tmp for reference during process.

Intermediate tracking before full level B (unloading and setting tracker for event object via set_state)

2. Dispatch first in object URL in .archive.tmp event buffer, pick a file, set_state (file level state), await.

Level B -> compress event object.
3. try compress_one_file() (parallelism to maximize cores), exceptions -> log & exit, else verify if successful (3.1), fail (3.2)

3.2 log, retry 3, if retry.times == X, skip, I.e no staging. // no, we probably must not retry here. It means fewer files to process in the tmux session. A retry should fix failed attempts.

3.1 log, stage, log staging,

3.3 yield to object-URLS-for-deletion buffer, run 2 | None? Run 4

Level C -> delete originals
4. Iterate object-URLS-for-deletion, confirm original is > by ~X% than staged sizes: True?-> delete original && confirm existence check is null && append stage URL to before-zip buffer && log, False? -> delete compressed, log original's URL to undone list ( roll back ) log. Yield if item worked on is final item in archive2.tmp.
//successfully staged files, failed or initially excluded originals exist at this stage.

ZIP per year && month
OK check
5. Dispatch item from before-zip buffer file, check if "$Month" && "$year" not in Archives:
5.1 True -> append URL to ready-buffer file.
5.2 False -> skip

"""I think this check must be there for all of the stages as an idempotency check in case i decide to run only one script, it should log and refuse if argument already finished any of the stages after it."""

Pause if no more files exist for current month until 5.1.1 zipping yields.

actual zipping
5.1.1 ZIP the files at ready-buffer file URLs by copying and zipping without modifying stage, log, if successful yield zipped file else rollback or freeze current if possible as a zip, log into unfinished-zip URLs files buffer but idk whether it saves anything and it's totally useless if zipped files can't be merged safely without unzipping like a normal file merge.

5.2 The zip file url is logged to a url map file and yield

Confirmation
6. Iterate the zip file url map, for Final check of the zip file count vs archive2.tmp file count. If there's a difference or not, log it for a separate file and give a summary for mismatched and clear ones. // this can be compared with R2 bucket if needed since originals no longer exist locally.

---

## 2026-08-01 — Truth-table style logs instead of long strings

these tests are expensive.. They take long. My description was happy path only. Didn't talk anything about usage of logs to recover from failure at certain points and log data structure. With hundreds of files, and ever increasing steps w8th retries, we can't just log long strings, readable data is useful but I feel like truth table like logs might work depending on where. But idk why most logs I've seen look different.

I won't try to over engineer anything since this is not something that is supposed to be production grade.
The problem is that the data is sensitive, and space is limited so we can make a copy of only a few files to test on which means we can't know performance at high load.

---

## 2026-08-01 — Open-source the archive pipeline

I had an idea to open-source this in my github. So I faced feature creep of "lacking", but I just need what's good enough. People use what's good enough like java on a Linux machine instead of native C, or bash instead of js for CLI UI.

## 2026-07-31 (migrated from progress.md's "Open items" backlog on 2026-08-02)

Pending entries noted before ideas.md existed as a file: tiered
compression by age, preview+link architecture, semantic/vector search
over media, dedup-by-hash as a standard pre-archive step.

---

## 2026-08-03 — File-hash integrity checking, for the open-source case

Later, we could be more strict with file hashes to make sure rogue
scripts don't get in the way. Useful when open-sourced to GitHub —
right now anyone with device access could swap a lib file and the
pipeline would just source it and run. Not needed at solo-scale, but
worth having before publishing the repo.

---

## 2026-08-03 — Interactive setup script for per-target run behavior

A script that makes the process interactive like a setup, to configure
targets and what to do — run, skip, don't prompt, just zip! The
anomaly-mode prompt (wait/cancel/skip) is one global choice per run
right now, but the actual need is per-context: user doesn't care about
some months (test files) but cares a lot about others (production —
2025-12 through 2026-04, real irreplaceable data). Won't go into
details now, feature creep, but the shape of it: a config step before
the run that lets different months/batches get different anomaly
handling instead of one setting for everything.

---
## 2026-08-06 — Throttle pipeline to run alongside other apps

If we shall later throttle our own process so it works in the background
with other apps running i.e spread the work over a longer period of time
to compete lesser with other processes.

---

## 2026-08-07 — .env for hardcoded paths and config

Right now paths (manifest, staging dir, archives dir, STATE_LOG
default) and Termux-specific shebangs are hardcoded across common.sh,
track.py, and the entry scripts. Works fine single-device, single-user
— but caught mid-session while building retry-logic tests: we had to
hand-export STATE_LOG per-shell with no enforcement, which is the same
underlying problem. Related to the file-hash-integrity item (both are
"assumes single trusted environment" gaps) — worth doing together
before any open-source push, not urgent before then.

## 2026-08-09 — Reddit post draft: storage crisis story

I thought you meant I'm compressing and packaging them for upload to backblaze.

Here's why the whole point to this project came about.
My Device storage is almost full at about 91% currently but it was about 95% before we compressed any month data.

I wanted to free up storage without losing my original data. So first I made a backup to backblaze for it's low storage pricing. I'll connect it to cloudflare for zero egress fees for downloads later.

Next was to actually free up storage.
Most searches and AI responses told me,
A. to delete more stuff after backup,
B. if not backed up, compress and delete not so important stuff.

Which had some trade offs:
For A. zero egress fees and cheaper storage than Google drive doesn't mean faster access or zero data costs for downloads which downloads would fill up space anyway.
And backup doesn't mean the risk of losing data is zero e.g forgotten password. Platform breaches are nolonger breaking news.

For B. I'd lose original data. And there's no available tool that can iterate my entire gallery compressing the files. If it did exist, it had to progressively delete the original copies because storing compressed and original would fill up memory and brick my phone.
Also even if I can do one file at a time during free times, I'm lazy and forgetful.

So, I decided to do both A and B.
Backup originals, compress old files aggressively while keeping the quality usable.
As an extra, I decided to package the data on a monthly basis just to make sure I don't mix compressed and originals during the process. WhatsApp data is already compressed by default, so needed a tool which could be configured to skip them.

The screenshot is of my files app fresh today 10am 9th August 2026. Only one month has been successfully compressed, verified, packaged, originals deleted with logging at each stage for tracing anomalies.

---
\n
---

## 2026-08-12 — File-hash integrity check, deferred as over-engineering for current repo size

Scoped a hash-check design (git-tracked file_hashes.tsv, sha256 via
python3, separate deliberate regen step, mismatch pointing at git log
-p to distinguish own edits from unexpected changes) to protect
against a rogue/malicious code swap in a required file -- the axios/
event-stream/ua-parser-js style supply-chain case. Decided against
building it now: repo has 2 stars, low realistic risk at this scale,
and check_files.sh's existence-check already covers the more likely
failure (a file missing or reverted, not tampered with). Revisit if
the repo gets real outside attention, or per the existing "before any
open-source push" note this was already tied to in issues.md.
