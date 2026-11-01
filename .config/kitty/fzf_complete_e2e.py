"""End-to-end test for fzf_complete.py: drives the overlay in a throwaway kitty instance.
Run:  python3 ~/.config/kitty/fzf_complete_e2e.py   (opens and closes one kitty window)
"""
import json, subprocess, time, sys, os
SOCK = "unix:/tmp/kitty-fzc-test"
def rc(*a):
    return subprocess.run(["kitten", "@", "--to", SOCK, *a], capture_output=True, text=True, timeout=10)
def windows():
    try: return json.loads(rc("ls").stdout)[0]["tabs"][0]["windows"]
    except Exception: return []
def wait(cond, secs=15, what=""):
    t0 = time.time()
    while time.time() - t0 < secs:
        if cond(): return True
        time.sleep(0.2)
    print(f"  timeout waiting for {what}"); return False
line = 'Hallmark lives in ~/.claude/skills/hallmark now. The docs are at https://example.com/docs today.'
subprocess.Popen(["kitty", "--detach", "--listen-on", SOCK, "-o", "allow_remote_control=yes", "-o", "confirm_os_window_close=0",
                  "--title", "fzc-test", "--directory", os.path.expanduser("~/.config/kitty"), "sh", "-c", f'echo "{line}"; exec cat'])
if not wait(lambda: len(windows()) == 1, 15, "kitty instance"): sys.exit(1)
pid = windows()[0]["pid"]
def parent_text(): return rc("get-text", "--match", f"pid:{pid}", "--extent", "all").stdout
ok = True
def run(name, keys, expect):
    global ok
    before = parent_text().count(expect)
    r = rc("kitten", "fzf_complete.py")
    if r.returncode: print(name, "launch failed:", r.stderr.strip()[-300:]); ok = False; return
    if not wait(lambda: len(windows()) == 2, 15, "overlay"): ok = False; return
    time.sleep(1.5)                                  # fzf start + provider list
    for k in keys:
        rc("send-text", "--match", "state:focused", k); time.sleep(0.7)
    closed = wait(lambda: len(windows()) == 1, 10, "overlay to close")
    time.sleep(0.5)
    after = parent_text().count(expect)
    passed = closed and after == before + (1 if expect else 0)
    ok &= passed
    print(f"{name}: {'PASS' if passed else 'FAIL'}  ({expect!r} count {before}->{after}, overlay closed={closed})")
run("files",      ["fzf_comp", "\r"], "fzf_complete.py")
run("sentences",  ["\x1bs", "docs", "\r"], "The docs are at https://example.com/docs today.")
run("urls",       ["\x1bu", "\r"], "https://example.com/docs")
run("paths",      ["\x1bp", "skills", "\r"], "~/.claude/skills/hallmark")
run("cycle+dirs", ["\x14", "sessions", "\r"], "sessions")
run("multi",      ["\x1bd", "sessions", "\t", "\r"], "sessions")





txt0 = parent_text(); run("abort", ["\x1b"], ""); print("  abort left screen unchanged:", parent_text() == txt0)
print("final screen tail:\n" + "\n".join(parent_text().rstrip().splitlines()[-8:]))
rc("close-window", "--match", "all")
print("overall:", "ALL PASS" if ok else "SOME FAILED")
