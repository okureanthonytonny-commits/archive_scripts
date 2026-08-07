# moov-atom-missing fixtures

Two staged `.mp4` outputs from the abandoned pre-rewrite 2026-07-31
March run. Both fail `ffprobe -v error` with "moov atom not found"
(truncated/incomplete write). Confirmed originals in `DCIM/Camera` are
clean — this is a broken staged output, not a corrupt source. Kept as
a regression fixture for retry-on-`FAILED` logic (see `bugQueue.md`,
`issues.md` 2026-08-06/08-07 entries).

Files:
- 20260324_080113.mp4
- 20260324_080046.mp4

Note: two extra `FAILED` rows for these URLs exist in the production
`.state_log.tsv` dated 2026-08-07T12:13:5x — written accidentally
during retry-logic test setup, before test-log isolation
(`STATE_LOG` env var) was adopted. Harmless (real 2026-08-06 `FAILED`
entries are still the authoritative first occurrence), but explains
the count=2 if anyone greps for it later. All retry-logic testing from
2026-08-07 onward uses `tests/fixtures/test_state_log.tsv` instead.
