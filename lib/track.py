#!/usr/bin/env python3
"""lib/track.py — append-only state tracking for the archive pipeline.
Called from bash, once per file, per state transition. Never trust a
value in place — 'get' always re-derives current state from the log.

Usage:
  python3 track.py set <url> <STATE_NAME> [kind] [path]
  python3 track.py get <url>

States (the int is the source of truth; name is for readability):
  PENDING    0   not yet touched this run
  COMPRESSED 1   output written, not yet checked
  VERIFIED   2   decode-check passed
  DELETED    4   original removed — terminal success
  FAILED    -1   verify failed, original kept
  MISSING   -2   original not found on disk
"""
# Example bash usage (compress.sh call pattern):
#   python3 "$SCRIPT_DIR/lib/track.py" set "$url" COMPRESSED webp "$outpath"
#   result=$(python3 "$SCRIPT_DIR/lib/track.py" get "$url")
#   IFS=$'\t' read -r state_name state_int kind path <<< "$result"

import sys
import os
from datetime import datetime
from enum import IntEnum


class State(IntEnum):
    PENDING = 0
    COMPRESSED = 1
    VERIFIED = 2
    DELETED = 4
    FAILED = -1
    MISSING = -2


STATE_LOG = os.environ.get(
    "STATE_LOG",
    os.path.expanduser("~/archive_scripts/.state_log.tsv"),
)


def cmd_set(url, state_name, kind="", path="", note=""):
    try:
        state = State[state_name.upper()]
    except KeyError:
        sys.exit(f"unknown state: {state_name}")
    ts = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    note = note.replace("\t", " ").replace("\n", " | ")
    row = "\t".join([ts, url, str(int(state)), state.name, kind, path, note])
    os.makedirs(os.path.dirname(STATE_LOG), exist_ok=True)
    with open(STATE_LOG, "a") as fh:
        fh.write(row + "\n")


def cmd_get(url):
    if os.path.exists(STATE_LOG):
        last = None
        with open(STATE_LOG) as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 7 and parts[1] == url:
                    last = parts
        if last is not None:
            _, _, state_int, state_name, kind, path, note = last
            print(f"{state_name}\t{state_int}\t{kind}\t{path}\t{note}")
            return
    print("PENDING\t0\t\t\t")



def cmd_count(url, state_name):
    try:
        state = State[state_name.upper()]
    except KeyError:
        sys.exit(f"unknown state: {state_name}")
    n = 0
    if os.path.exists(STATE_LOG):
        with open(STATE_LOG) as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 7 and parts[1] == url and parts[2] == str(int(state)):
                    n += 1
    print(n)

def main():
    if len(sys.argv) < 2:
        sys.exit("usage: track.py set|get ...")
    cmd = sys.argv[1]
    if cmd == "set":
        if len(sys.argv) < 4:
            sys.exit("usage: track.py set <url> <STATE_NAME> [kind] [path] [note]")
        url = sys.argv[2]
        state_name = sys.argv[3]
        kind = sys.argv[4] if len(sys.argv) > 4 else ""
        path = sys.argv[5] if len(sys.argv) > 5 else ""
        note = sys.argv[6] if len(sys.argv) > 6 else ""
        cmd_set(url, state_name, kind, path, note)
    elif cmd == "get":
        if len(sys.argv) < 3:
            sys.exit("usage: track.py get <url>")
        cmd_get(sys.argv[2])
    elif cmd == "count":
        if len(sys.argv) < 4:
            sys.exit("usage: track.py count <url> <STATE_NAME>")
        cmd_count(sys.argv[2], sys.argv[3])
    else:
        sys.exit(f"unknown command: {cmd}")


if __name__ == "__main__":
    main()
