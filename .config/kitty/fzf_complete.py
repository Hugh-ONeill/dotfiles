#!/usr/bin/env python3
"""kitty kitten: an fzf completion overlay for any program's prompt.

Bound to a key in kitty.conf, it opens fzf over the current window and pastes
the selection back into it, so paths, URLs, lines of output and git objects
can be dropped into a prompt that the shell's own fzf bindings cannot reach
(an AI coding agent, a REPL, a TUI).

Providers (CTRL-T cycles, or jump straight to one):
  ALT-F files        ALT-D directories      ALT-H git commit hashes
  ALT-P paths on screen   ALT-U URLs on screen   ALT-B git branches
  ALT-S sentences on screen, rebuilt from the rows they were wrapped into
Inside fzf: TAB multi-select, CTRL-O open (URL in the browser, anything else
in the editor), CTRL-Y copy, CTRL-R rescrape the screen, CTRL-/ preview.

The same file doubles as the helper fzf calls for reload/preview/open/copy:
    python3 -I fzf_complete.py {scrape|switch|preview|open|copy} ...
"""
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

def _here():
    """kitty execs this module without __file__; find it from the config dir."""
    try:
        return os.path.abspath(__file__)
    except NameError:
        d = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser("~/.config/kitty")
        return os.path.join(d, "fzf_complete.py")


HERE = _here()
ORDER = ["files", "dirs", "paths", "urls", "sentences", "hashes", "branches"]
PROMPT = {
    "files": "files", "dirs": "dirs", "paths": "paths on screen",
    "urls": "urls on screen", "sentences": "sentences on screen",
    "hashes": "git hashes", "branches": "git branches",
}
JUMP = {"alt-f": "files", "alt-d": "dirs", "alt-p": "paths", "alt-u": "urls",
        "alt-s": "sentences", "alt-h": "hashes", "alt-b": "branches"}
SCREEN = {"paths", "urls", "sentences"}
HEADER = "C-t next · A-f files A-d dirs A-p paths A-u urls A-s sentences A-h hashes A-b branches · C-o open C-y copy C-r rescrape"

URL_RE = re.compile(r"""(?:https?|ftp|file)://[^\s<>"'`)\]]+""")
PATH_RE = re.compile(
    r"""(?<![\w/.-])(?:(?:~|\.{1,2})?/[^\s'"`<>|()\[\]{}]+"""      # /abs ~/home ./rel ../rel
    r"""|[\w.@%+=-]+(?:/[^\s'"`<>|()\[\]{}]+)+"""                  # rel/with/slash
    r"""|[\w@%+=-]+\.[A-Za-z0-9]{1,8})"""                           # bare file.ext
    r"""(?::\d+)*(?![\w/])"""
)
DECOR_RE = re.compile(r"^[\s│┃|●○◐◑◒◓⎿└├┌┐┘┬┴┼─━╭╮╰╯>*•·▸▪■□✓✔✗✘⏺⎯-]+|^\s*\d+[.)]\s+")
TRAIL_RE = re.compile(r"[\s│┃|]+$")
SENT_SPLIT = re.compile(r"""(?<=[.!?])\s+(?=["'(]?[A-Z])""")
HASH_RE = re.compile(r"^[0-9a-f]{7,40}$")


# ----------------------------------------------------------------- scraping
def screen_text():
    """Fresh text of the window under the overlay, else the cached snapshot."""
    pid, listen = os.environ.get("KITTY_CHILD_PID"), os.environ.get("KITTY_LISTEN_ON")
    if pid and listen and shutil.which("kitten"):
        try:
            r = subprocess.run(
                ["kitten", "@", "get-text", "--match", f"pid:{pid}", "--extent", "all", "--add-wrap-markers"],
                capture_output=True, timeout=5)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.decode("utf-8", "replace")
        except (OSError, subprocess.SubprocessError):
            pass
    cache = os.environ.get("FZC_TEXT")
    if cache and os.path.exists(cache):
        with open(cache, encoding="utf-8", errors="replace", newline="") as f:
            return f.read()
    return ""


def logical_lines(text):
    """Join rows kitty soft-wrapped (marked with a trailing \\r)."""
    out, buf = [], None
    for raw in text.split("\n"):
        soft = raw.endswith("\r")
        raw = raw.rstrip("\r")
        buf = raw if buf is None else buf + raw
        if not soft:
            out.append(buf)
            buf = None
    if buf is not None:
        out.append(buf)
    return out


def recent_unique(items):
    """Most recent first, duplicates dropped."""
    seen, out = set(), []
    for it in reversed(items):
        if it not in seen:
            seen.add(it)
            out.append(it)
    return out


def scrape_urls(text):
    found = []
    for line in logical_lines(text):
        for m in URL_RE.finditer(line):
            found.append(m.group(0).rstrip(".,;:!?'\")"))
    return recent_unique(found)


def scrape_paths(text, cwd):
    found = []
    for line in logical_lines(text):
        line = URL_RE.sub(" ", line)
        for m in PATH_RE.finditer(line):
            tok = m.group(0).rstrip(".,;:!?'\"")
            base = re.sub(r"(?::\d+)+$", "", tok)
            if not base or base in (".", "..", "/"):
                continue
            if base.startswith(("/", "~")):
                found.append(tok)
            elif os.path.exists(os.path.join(cwd, base)):
                found.append(tok)
    return recent_unique(found)


def scrape_sentences(text):
    rows = [TRAIL_RE.sub("", DECOR_RE.sub("", l)).strip() for l in logical_lines(text)]
    full = 0.7 * max((len(r) for r in rows), default=0)   # a row the program wrapped is near full width
    paras, cur, prev_len = [], "", 0
    for s in rows:
        if not s:
            if cur:
                paras.append(cur)
            cur, prev_len = "", 0
            continue
        if cur and not re.search(r"[.!?:]$", cur) and prev_len >= full:
            cur += " " + s
            prev_len = len(s)
        else:
            if cur:
                paras.append(cur)
            cur, prev_len = s, len(s)
    if cur:
        paras.append(cur)
    out = []
    for p in paras:
        for sent in SENT_SPLIT.split(p):
            sent = sent.strip()
            if len(sent.split()) >= 3 and len(sent) <= 500:
                out.append(sent)
    return recent_unique(out)


def scrape(provider):
    text = screen_text()
    cwd = os.environ.get("FZC_CWD") or os.getcwd()
    if provider == "urls":
        return scrape_urls(text)
    if provider == "paths":
        return scrape_paths(text, cwd)
    if provider == "sentences":
        return scrape_sentences(text)
    return []


# ------------------------------------------------------------- fzf plumbing
def py():
    """Interpreter for the helper calls. Under kitty, sys.executable is kitty itself."""
    exe = sys.executable if sys.executable and "python" in os.path.basename(sys.executable) else shutil.which("python3") or "python3"
    return f"{shlex.quote(exe)} -I {shlex.quote(HERE)}"


def list_cmd(provider):
    """Shell command fzf runs to (re)load a provider's list."""
    if provider in ("files", "dirs"):
        t = "f" if provider == "files" else "d"
        if shutil.which("fd"):
            return f"fd --type {t} --hidden --follow --exclude .git --color=never 2>/dev/null"
        return f"find . -path ./.git -prune -o -type {t} -print 2>/dev/null | sed 's|^\\./||'"
    if provider == "hashes":
        return "git log --color=always --format='%C(yellow)%h%C(reset)  %s %C(dim)(%cr)%C(reset)' -n 2000 2>/dev/null"
    if provider == "branches":
        return ("git branch -a --color=always --sort=-committerdate "
                "--format='%(color:green)%(refname:short)%(color:reset)  %(contents:subject)' 2>/dev/null")
    return f"{py()} scrape {provider}"


def read_state():
    p = os.environ.get("FZC_STATE")
    try:
        with open(p) as f:
            s = f.read().strip()
        return s if s in ORDER else "files"
    except (OSError, TypeError):
        return "files"


def write_state(provider):
    p = os.environ.get("FZC_STATE")
    if p:
        with open(p, "w") as f:
            f.write(provider)


def cmd_switch(arg):
    """Print fzf actions that move to a provider (used by `transform` bindings)."""
    cur = read_state()
    if arg == "next":
        new = ORDER[(ORDER.index(cur) + 1) % len(ORDER)]
    elif arg == "same":
        new = cur
    else:
        new = arg if arg in ORDER else "files"
    write_state(new)
    print(f"change-prompt({PROMPT[new]}> )+reload({list_cmd(new)})")


def strip_ansi(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)


def to_insert(provider, line):
    line = strip_ansi(line).rstrip()
    if provider in ("hashes", "branches"):
        return line.split()[0] if line.split() else ""
    if provider in ("files", "dirs", "paths"):
        return shlex.quote(line) if re.search(r"[\s'\"$`\\!&|;<>()*?\[\]{}]", line) else line
    return line


def cmd_preview(item):
    provider = read_state()
    item = strip_ansi(item).strip()
    cols = int(os.environ.get("FZF_PREVIEW_COLUMNS") or 80)
    if provider == "hashes" and item:
        h = item.split()[0]
        os.execvp("git", ["git", "show", "--stat", "--color=always", h])
    if provider == "branches" and item:
        b = item.split()[0]
        os.execvp("git", ["git", "log", "--color=always", "--oneline", "-n", "40", b, "--"])
    base = re.sub(r"(?::\d+)+$", "", item)
    path = os.path.expanduser(base)
    if os.path.isdir(path):
        os.execvp("ls", ["ls", "-la", "--color=always", path])
    if os.path.isfile(path):
        if shutil.which("bat"):
            os.execvp("bat", ["bat", "--color=always", "--style=numbers", "--line-range", ":300", path])
        os.execvp("head", ["head", "-n", "300", path])
    import textwrap
    print("\n".join(textwrap.wrap(item, max(20, cols - 2))))


def cmd_open(item):
    item = strip_ansi(item).strip()
    if URL_RE.match(item):
        subprocess.run(["xdg-open", item], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    m = re.match(r"^(.*?)(?::(\d+))?(?::\d+)?$", item)
    path, line = os.path.expanduser(m.group(1)), m.group(2)
    if not os.path.exists(path):
        return
    editor = os.environ.get("EDITOR") or os.environ.get("VISUAL") or ("nvim" if shutil.which("nvim") else "vi")
    args = shlex.split(editor)
    if line:
        args.append(f"+{line}")
    args.append(path)
    subprocess.run(args)


def cmd_copy(items):
    provider = read_state()
    text = " ".join(to_insert(provider, i) for i in items)
    if shutil.which("wl-copy"):
        subprocess.run(["wl-copy"], input=text, text=True)
    elif shutil.which("kitten"):
        subprocess.run(["kitten", "clipboard"], input=text, text=True)


def theme_colors():
    f = os.path.expanduser("~/.config/themes/current/fzf.sh")
    if not os.path.exists(f):
        return []
    try:
        r = subprocess.run(["sh", "-c", f'. {shlex.quote(f)} >/dev/null 2>&1; printf %s "$FZF_COLORS"'],
                           capture_output=True, text=True, timeout=3)
        return shlex.split(r.stdout) if r.returncode == 0 else []
    except (OSError, subprocess.SubprocessError, ValueError):
        return []


# ------------------------------------------------------------ kitten entry
def _log(msg):
    """Append to ~/.cache/fzf_complete.log; only written when something goes wrong."""
    try:
        d = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"))
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "fzf_complete.log"), "a") as f:
            f.write(msg.rstrip() + "\n")
    except OSError:
        pass


def main(args):
    """Runs in the overlay. stdin carries the parent window's screen text."""
    try:
        return _main(args)
    except Exception as e:                      # noqa: BLE001 - surface it in the log, never hang the overlay
        import traceback
        _log(f"main crashed: {e}\n{traceback.format_exc()}")
        return ""


def _main(args):
    data = sys.stdin.buffer.read().decode("utf-8", "replace") if not sys.stdin.isatty() else ""
    tmp = tempfile.mkdtemp(prefix="fzc-")
    text_path, state_path = os.path.join(tmp, "text"), os.path.join(tmp, "state")
    with open(text_path, "w", encoding="utf-8", newline="") as f:
        f.write(data)
    with open(state_path, "w") as f:
        f.write("files")
    env = dict(os.environ, FZC_TEXT=text_path, FZC_STATE=state_path, FZC_CWD=os.getcwd())
    env.pop("FZF_DEFAULT_OPTS", None)
    env.pop("FZF_DEFAULT_COMMAND", None)
    P = py()
    binds = [f"{k}:transform:{P} switch {p}" for k, p in JUMP.items()]
    binds += [
        f"start:transform:{P} switch files",
        f"ctrl-t:transform:{P} switch next",
        f"ctrl-r:transform:{P} switch same",
        f"ctrl-o:execute({P} open {{}})",
        f"ctrl-y:execute-silent({P} copy {{+}})",
        "ctrl-/:toggle-preview",
    ]
    cmd = ["fzf", "--ansi", "--multi", "--layout=reverse", "--height=100%", "--info=inline", "--cycle",
           "--prompt", "files> ", "--header", HEADER,
           "--preview", f"{P} preview {{}}",
           "--preview-window", "right,45%,border-left,<90(down,40%,border-top)",
           *theme_colors()]
    for b in binds:
        cmd += ["--bind", b]
    try:
        r = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           text=True, env=env)
    finally:
        provider = read_state() if os.path.exists(state_path) else "files"
        if "FZC_STATE" not in os.environ:
            os.environ["FZC_STATE"] = state_path
        provider = read_state()
        shutil.rmtree(tmp, ignore_errors=True)
    if r.returncode not in (0, 1, 130):          # 1 = no match, 130 = aborted; anything else is a real failure
        _log(f"fzf exited {r.returncode}: {r.stderr.strip()[-500:] if r.stderr else ''}")
        return ""
    if r.returncode != 0:
        return ""
    picks = [to_insert(provider, l) for l in r.stdout.splitlines() if l.strip()]
    return " ".join(p for p in picks if p)


main.allow_remote_control = True   # lets the overlay rescrape the screen with `kitten @ get-text`

try:
    from kittens.tui.handler import result_handler

    @result_handler(type_of_input="screen-history")
    def handle_result(args, answer, target_window_id, boss):
        """Runs inside kitty: paste the pick into the window the kitten was opened on."""
        if not answer:
            return
        w = boss.window_id_map.get(target_window_id)
        if w is not None:
            w.paste_text(answer)
except ImportError:
    pass


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit("usage: fzf_complete.py scrape|switch|preview|open|copy ...")
    if a[0] == "scrape":
        sys.stdout.write("\n".join(scrape(a[1] if len(a) > 1 else "paths")) + "\n")
    elif a[0] == "switch":
        cmd_switch(a[1] if len(a) > 1 else "next")
    elif a[0] == "preview":
        cmd_preview(a[1] if len(a) > 1 else "")
    elif a[0] == "open":
        cmd_open(a[1] if len(a) > 1 else "")
    elif a[0] == "copy":
        cmd_copy(a[1:])
