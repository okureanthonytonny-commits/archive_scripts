#!/usr/bin/env python3
"""lib/summary.py — regenerates a FILE_LOG-format summary purely by
reading state_log.tsv. Not a second source of truth: files.tsv should
no longer be written incrementally by verify.sh/delete.sh, only
produced on demand by this script, right before archive_compress.sh's
existing awk-based status breakdown reads it.

Usage:
  python3 summary.py <filelist_path>   # prints ts\ttag\turl lines to stdout

Output format matches the original file_log() convention exactly, so
archive_compress.sh's existing awk commands need no changes.
"""
import sys
import os

STATE_LOG = os.environ.get(
    "STATE_LOG",
    os.path.expanduser("~/archive_scripts/.state_log.tsv"),
)


def last_rows():
    """{url: (ts, state_name, kind)} using the LAST row per url — never
    trust an earlier row once a later one for the same url exists."""
    rows = {}
    if not os.path.exists(STATE_LOG):
        return rows
    with open(STATE_LOG) as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 7:
                continue
            ts, url, state_int, state_name, kind, path, note = parts
            rows[url] = (ts, state_name, kind)
    return rows


def tag_for(state_name, kind):
    if state_name == "DELETED":
        return {
            "webp": "OK_WEBP_DELETED",
            "video": "OK_H264_DELETED",
            "copy": "OK_STORED_DELETED",
        }.get(kind, "OK_UNKNOWN_KIND_DELETED")
    if state_name == "FAILED":
        return {
            "webp": "FAIL_WEBP",
            "video": "FAIL_VIDEO",
            "copy": "FAIL_COPY",
        }.get(kind, "FAIL_UNKNOWN_KIND")
    if state_name == "MISSING":
        return "MISSING"
    return None  # PENDING/COMPRESSED/VERIFIED — not terminal, skip


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: summary.py <filelist_path>")
    filelist_path = sys.argv[1]

    with open(filelist_path) as fh:
        urls = [line.rstrip("\n") for line in fh if line.strip()]

    last = last_rows()
    for url in urls:
        if url not in last:
            continue
        ts, state_name, kind = last[url]
        tag = tag_for(state_name, kind)
        if tag is None:
            continue
        print(f"{ts}\t{tag}\t{url}")


if __name__ == "__main__":
    main()
