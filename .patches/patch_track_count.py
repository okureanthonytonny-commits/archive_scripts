import sys

path = "lib/track.py"
with open(path) as f:
    content = f.read()

if "def cmd_count" in content:
    print("SKIPPED: cmd_count already present")
    sys.exit(0)

old_dispatch = '''    elif cmd == "get":
        if len(sys.argv) < 3:
            sys.exit("usage: track.py get <url>")
        cmd_get(sys.argv[2])
    else:'''

new_dispatch = '''    elif cmd == "get":
        if len(sys.argv) < 3:
            sys.exit("usage: track.py get <url>")
        cmd_get(sys.argv[2])
    elif cmd == "count":
        if len(sys.argv) < 4:
            sys.exit("usage: track.py count <url> <STATE_NAME>")
        cmd_count(sys.argv[2], sys.argv[3])
    else:'''

count_fn = '''

def cmd_count(url, state_name):
    try:
        state = State[state_name.upper()]
    except KeyError:
        sys.exit(f"unknown state: {state_name}")
    n = 0
    if os.path.exists(STATE_LOG):
        with open(STATE_LOG) as fh:
            for line in fh:
                parts = line.rstrip("\\n").split("\\t")
                if len(parts) == 7 and parts[1] == url and parts[2] == str(int(state)):
                    n += 1
    print(n)
'''

if old_dispatch not in content:
    print("ABORT: dispatch block not found — file may have changed")
    sys.exit(1)

content = content.replace(old_dispatch, new_dispatch)
content = content.replace("\ndef main():", count_fn + "\ndef main():")

with open(path, "w") as f:
    f.write(content)

print("WRITTEN")
