// sudo password prompt drawn with hyprtoolkit, laid out like hyprpolkitagent's dialog
// Usage: sudo-askpass-hypr "<prompt>"   (run by ~/.local/bin/sudo-askpass; prints the password on stdout, exit 1 on cancel)
//        sudo-askpass-hypr [--title T] [--subtitle S] [--heading H] [--body B] [--error E]
//                          [--placeholder P] [--class C] ["<prompt>"]
//   The flags reuse the dialog for other prompts (~/.local/bin/pinentry-hypr for gpg). --body replaces
//   the sudo command box with free text (newlines kept); with no flags it behaves exactly as for sudo.
//
// Layout and sizes follow hyprpolkitagent v0.2.0 src/ui/Dialog.cpp (BSD-3-Clause, Hypr Development).

#include <hyprtoolkit/core/Backend.hpp>
#include <hyprtoolkit/core/Input.hpp>
#include <hyprtoolkit/element/Button.hpp>
#include <hyprtoolkit/element/ColumnLayout.hpp>
#include <hyprtoolkit/element/Rectangle.hpp>
#include <hyprtoolkit/element/RowLayout.hpp>
#include <hyprtoolkit/element/Text.hpp>
#include <hyprtoolkit/palette/Color.hpp>
#include <hyprtoolkit/types/FontTypes.hpp>
#include <hyprtoolkit/types/SizeType.hpp>
#include <hyprtoolkit/window/Window.hpp>

#include <xkbcommon/xkbcommon-keysyms.h>

#include <algorithm>
#include <array>
#include <cstdio>
#include <cstdlib>
#include <sstream>
#include <vector>
#include <fcntl.h>
#include <cmath>
#include <fstream>
#include <pwd.h>
#include <string>
#include <unistd.h>

using namespace Hyprutils::Memory;
using namespace Hyprtoolkit;

// -------------------- Settings --------------------

constexpr double WINDOW_W   = 520;
constexpr double WINDOW_H   = 360;     // height with a one-line command
constexpr double LINE_H     = 21;      // extra height per additional command line
constexpr double FIELD_W    = 340;
constexpr size_t WRAP_COLS  = 40;      // monospace columns per command line
constexpr size_t MAX_LINES  = 8;
constexpr size_t MAX_BODY_LINES = 10;

// overrides from the command line; empty means "use the sudo default"
struct SOptions {
    std::string title, subtitle, heading, body, error, placeholder, appClass;
};

static SOptions parseArgs(int argc, char* argv[]) {
    SOptions o;
    for (int i = 1; i < argc; ++i) {
        const std::string a = argv[i];
        auto              next = [&](std::string& dst) {
            if (i + 1 < argc)
                dst = argv[++i];
        };
        if (a == "--title")
            next(o.title);
        else if (a == "--subtitle")
            next(o.subtitle);
        else if (a == "--heading")
            next(o.heading);
        else if (a == "--body")
            next(o.body);
        else if (a == "--error")
            next(o.error);
        else if (a == "--placeholder")
            next(o.placeholder);
        else if (a == "--class")
            next(o.appClass);
        // anything else is the prompt sudo passes; the dialog doesn't show it
    }
    return o;
}

static CSharedPointer<IBackend> g_backend;
static std::string              g_password;
static size_t                   g_passLen = 0;    // characters (not bytes) in g_password
static bool                     g_reveal  = false; // eye toggle: show the typed text instead of symbols
static int                      g_outFd = -1;     // the real stdout, reserved for the password

// -------------------- Helpers --------------------

[[noreturn]] static void finish(bool ok) {
    if (ok) {
        const std::string line = g_password + "\n";
        for (size_t off = 0; off < line.size();) {
            const ssize_t n = write(g_outFd, line.data() + off, line.size() - off);
            if (n <= 0)
                _exit(2);
            off += (size_t)n;
        }
    }
    _exit(ok ? 0 : 1);
}

// the command sudo was asked to run: sudo is our parent's parent (sudo -> sudo-askpass -> us)
static std::string sudoCommand() {
    for (pid_t pid = getppid(); pid > 1;) {
        std::ifstream f("/proc/" + std::to_string(pid) + "/cmdline", std::ios::binary);
        std::string   raw((std::istreambuf_iterator<char>(f)), {});
        std::vector<std::string> args;
        for (size_t s = 0, e; s < raw.size(); s = e + 1) {
            e = raw.find('\0', s);
            if (e == std::string::npos)
                e = raw.size();
            args.emplace_back(raw.substr(s, e - s));
        }
        if (!args.empty() && (args[0] == "sudo" || args[0].ends_with("/sudo"))) {
            std::string cmd;
            size_t      i = 1;
            while (i < args.size() && args[i].starts_with("-"))      // skip sudo's own flags
                ++i;
            for (; i < args.size(); ++i)
                cmd += (cmd.empty() ? "" : " ") + args[i];
            return cmd;
        }
        std::ifstream st("/proc/" + std::to_string(pid) + "/stat");
        std::string   line;
        std::getline(st, line);
        auto rp = line.rfind(')');
        if (rp == std::string::npos)
            break;
        int ppid = 0;
        std::sscanf(line.c_str() + rp + 2, "%*c %d", &ppid);
        pid = ppid;
    }
    return "";
}

// word-wrap the command to WRAP_COLS, hard-breaking long paths; the full command is always shown
// unless it exceeds MAX_LINES, in which case the last line ends in "..."
static std::vector<std::string> wrapCommand(const std::string& cmd) {
    std::vector<std::string> lines;
    std::string              cur;
    size_t                   i = 0;
    while (i < cmd.size()) {
        size_t      sp   = cmd.find(' ', i);
        std::string word = cmd.substr(i, sp == std::string::npos ? std::string::npos : sp - i);
        i                = sp == std::string::npos ? cmd.size() : sp + 1;
        while (!word.empty()) {
            const size_t room = WRAP_COLS - cur.size() - (cur.empty() ? 0 : 1);
            if (word.size() <= room) {
                cur += (cur.empty() ? "" : " ") + word;
                word.clear();
            } else if (cur.empty()) {
                lines.push_back(word.substr(0, WRAP_COLS));
                word = word.substr(WRAP_COLS);
            } else {
                lines.push_back(cur);
                cur.clear();
            }
        }
    }
    if (!cur.empty())
        lines.push_back(cur);
    if (lines.size() > MAX_LINES) {
        lines.resize(MAX_LINES);
        lines.back() = lines.back().substr(0, WRAP_COLS - 3) + "...";
    }
    return lines;
}

// wrap free text paragraph by paragraph (newlines kept), capped at MAX_BODY_LINES
static std::vector<std::string> wrapBody(const std::string& body) {
    std::vector<std::string> lines;
    std::stringstream        ss(body);
    std::string              para;
    while (std::getline(ss, para)) {
        if (para.empty()) {
            if (!lines.empty() && !lines.back().empty())
                lines.emplace_back();
            continue;
        }
        for (auto& l : wrapCommand(para))
            lines.push_back(l);
    }
    while (!lines.empty() && lines.back().empty())
        lines.pop_back();
    if (lines.size() > MAX_BODY_LINES) {
        lines.resize(MAX_BODY_LINES);
        lines.back() = lines.back().substr(0, WRAP_COLS - 3) + "...";
    }
    return lines;
}

// -------------------- Password mask --------------------

// symbols and gradient stops from the theme (~/.config/themes/current/password-mask.conf)
struct SMask {
    std::vector<std::string>                  symbols  = {"\u25CF"};
    std::vector<std::array<double, 3>>        gradient = {{1.0, 1.0, 1.0}};
};

constexpr double MASK_STEP = 0.5;   // gradient stops advanced per typed character
constexpr size_t REVEAL_MAX = 30;   // plain characters shown when revealed; older ones scroll off the left
constexpr double EYE_W     = 36;
constexpr size_t MASK_MAX  = 20;    // symbols that fit the field; older ones scroll off the left

static std::vector<std::string> splitWords(const std::string& s) {
    std::vector<std::string> out;
    std::istringstream       in(s);
    for (std::string w; in >> w;)
        out.push_back(w);
    return out;
}

static SMask loadMask() {
    SMask         mask;
    std::ifstream f(std::string{getenv("HOME") ? getenv("HOME") : ""} + "/.config/themes/current/password-mask.conf");
    for (std::string line; std::getline(f, line);) {
        const auto eq = line.find('=');
        if (eq == std::string::npos || line.starts_with("#"))
            continue;
        std::string key = line.substr(0, eq);
        key.erase(key.find_last_not_of(' ') + 1);
        auto words = splitWords(line.substr(eq + 1));
        if (words.empty())
            continue;
        if (key == "symbols")
            mask.symbols = words;
        else if (key == "gradient") {
            mask.gradient.clear();
            for (const auto& h : words) {
                if (h.size() != 7 || h[0] != '#')
                    continue;
                const unsigned v = std::stoul(h.substr(1), nullptr, 16);
                mask.gradient.push_back({((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0});
            }
            if (mask.gradient.empty())
                mask.gradient = {{1.0, 1.0, 1.0}};
        }
    }
    return mask;
}

// Pango markup for the mask: one symbol per typed character, colored along the wrapping gradient
static std::string maskMarkup(const SMask& mask, size_t count) {
    std::string  out;
    const size_t n = mask.gradient.size();
    for (size_t i = count > MASK_MAX ? count - MASK_MAX : 0; i < count; ++i) {
        const double pos = std::fmod((double)i * MASK_STEP, (double)n);
        const size_t lo  = (size_t)pos;
        const double t   = pos - (double)lo;
        const auto&  a   = mask.gradient[lo];
        const auto&  b   = mask.gradient[(lo + 1) % n];
        char         hex[8];
        std::snprintf(hex, sizeof(hex), "#%02x%02x%02x", (int)std::lround((a[0] + (b[0] - a[0]) * t) * 255),
                      (int)std::lround((a[1] + (b[1] - a[1]) * t) * 255), (int)std::lround((a[2] + (b[2] - a[2]) * t) * 255));
        out += std::string{"<span size=\"large\" foreground=\""} + hex + "\">" + mask.symbols[i % mask.symbols.size()] + "</span>" + (i + 1 < count ? "\u202F" : "");
    }
    return out;
}

// the last REVEAL_MAX characters of the password, escaped for Pango markup
static std::string revealMarkup() {
    size_t start = g_password.size(), seen = 0;
    while (start > 0 && seen < REVEAL_MAX) {
        --start;
        if ((g_password[start] & 0xC0) != 0x80)
            ++seen;
    }
    std::string out;
    for (char c : g_password.substr(start)) {
        switch (c) {
            case '&': out += "&amp;"; break;
            case '<': out += "&lt;"; break;
            case '>': out += "&gt;"; break;
            default: out += c;
        }
    }
    return out;
}

// drop the last UTF-8 character
static void popChar(std::string& s) {
    while (!s.empty() && (s.back() & 0xC0) == 0x80)
        s.pop_back();
    if (!s.empty())
        s.pop_back();
}

// clipboard text via wl-paste (hyprtoolkit's native backend keeps its clipboard private);
// only the first line, without control characters, since sudo reads one line
static std::string clipboardText() {
    FILE* f = popen("timeout 2 wl-paste --no-newline --type text/plain </dev/null 2>/dev/null", "r");
    if (!f)
        return "";
    std::string out;
    char        buf[256];
    for (size_t n; (n = fread(buf, 1, sizeof(buf), f)) > 0 && out.size() < 4096;)
        out.append(buf, n);
    pclose(f);
    out = out.substr(0, out.find_first_of("\r\n"));
    std::erase_if(out, [](char c) { return (unsigned char)c < 0x20 || c == 0x7F; });
    return out;
}

static size_t utf8Length(const std::string& s) {
    return (size_t)std::count_if(s.begin(), s.end(), [](char c) { return (c & 0xC0) != 0x80; });
}

static CSharedPointer<IElement> centered(CSharedPointer<IElement> child) {
    auto wrap = CRowLayoutBuilder::begin()->commence();
    wrap->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    wrap->setPositionFlag(IElement::HT_POSITION_FLAG_HCENTER, true);
    wrap->addChild(child);
    return wrap;
}

// -------------------- Dialog --------------------

int main(int argc, char* argv[]) {
    const SOptions opts = parseArgs(argc, argv);

    // sudo reads the first stdout line as the password, and hyprtoolkit logs to stdout:
    // keep the real stdout for the password only and point fd 1 at /dev/null
    g_outFd       = dup(STDOUT_FILENO);
    const int nul = open("/dev/null", O_WRONLY);
    if (g_outFd < 0 || nul < 0 || dup2(nul, STDOUT_FILENO) < 0)
        return 2;
    close(nul);

    g_backend = IBackend::create();
    if (!g_backend) {
        std::fputs("sudo-askpass-hypr: failed to create hyprtoolkit backend\n", stderr);
        return 2;
    }
    g_backend->setLogFn([](eLogLevel, const std::string&) {});
    const auto palette = g_backend->getPalette();

    const passwd* pw   = getpwuid(getuid());
    const std::string user = pw ? pw->pw_name : "you";

    const bool        bodyMode = !opts.body.empty();
    const std::string cmd      = bodyMode ? opts.body : sudoCommand();
    const auto        cmdLines = bodyMode ? wrapBody(cmd) : wrapCommand(cmd);
    const double      height   = WINDOW_H + (cmdLines.size() > 1 ? (double)(cmdLines.size() - 1) * LINE_H : 0.0) +
        (opts.error.empty() ? 0.0 : LINE_H);
    const std::string title = opts.title.empty() ? std::string{"Authentication Required"} : opts.title;

    auto window = CWindowBuilder::begin()
                      ->preferredSize({WINDOW_W, height})
                      ->minSize({460.0, height})
                      ->maxSize({600.0, height})
                      ->appTitle(std::string{title})
                      ->appClass(std::string{opts.appClass.empty() ? std::string{"sudo-askpass"} : opts.appClass})
                      ->commence();

    const SMask                     mask = loadMask();
    CSharedPointer<CTextElement>    fieldText;
    CSharedPointer<IElement>        fieldBox;
    std::function<void()>           updateField;
    CSharedPointer<CButtonElement>  authButton;
    CSharedPointer<CTextElement>    capsLabel;
    CSharedPointer<IElement>        capsWrap, statusCol;
    bool                            capsOn = false, capsShown = false;

    auto closeListener = window->m_events.closeRequest.listen([] { finish(false); });

    auto keyListener = window->m_events.keyboardKey.listen([&](const Input::SKeyboardKeyEvent& ev) {
        const bool caps = ev.modMask & Input::HT_MODIFIER_CAPS;
        if (caps != capsOn) {
            capsOn = caps;
            if (caps && !capsShown) {
                statusCol->addChild(capsWrap);
                capsShown = true;
            } else if (!caps && capsShown) {
                statusCol->removeChild(capsWrap);
                capsShown = false;
            }
        }
        if (!ev.down)
            return;
        const bool ctrl = ev.modMask & Input::HT_MODIFIER_CTRL;
        if (ev.xkbKeysym == XKB_KEY_Return || ev.xkbKeysym == XKB_KEY_KP_Enter) {
            if (!ev.repeat && !g_password.empty())
                finish(true);
            return;
        }
        if (ev.xkbKeysym == XKB_KEY_Escape) {
            if (!ev.repeat)
                finish(false);
            return;
        }
        if (ev.xkbKeysym == XKB_KEY_BackSpace) {
            if (ctrl) {
                g_password.clear();
                g_passLen = 0;
            } else if (g_passLen) {
                popChar(g_password);
                --g_passLen;
            }
        } else if ((ctrl && (ev.xkbKeysym == XKB_KEY_v || ev.xkbKeysym == XKB_KEY_V)) ||
                   (ev.xkbKeysym == XKB_KEY_Insert && (ev.modMask & Input::HT_MODIFIER_SHIFT))) {
            if (ev.repeat)
                return;
            const std::string pasted = clipboardText();
            if (pasted.empty())
                return;
            g_password += pasted;
            g_passLen += utf8Length(pasted);
        } else if (ctrl && (ev.xkbKeysym == XKB_KEY_u || ev.xkbKeysym == XKB_KEY_U)) {
            g_password.clear();
            g_passLen = 0;
        } else if (!ctrl && !(ev.modMask & Input::HT_MODIFIER_ALT) && !ev.utf8.empty() && (unsigned char)ev.utf8[0] >= 0x20 &&
                   ev.utf8[0] != 0x7F) {
            g_password += ev.utf8;
            ++g_passLen;
        } else
            return;
        updateField();
    });

    window->m_rootElement->addChild(CRectangleBuilder::begin()->color([] { return g_backend->getPalette()->m_colors.background; })->commence());

    auto outer = CColumnLayoutBuilder::begin()->size({CDynamicSize::HT_SIZE_PERCENT, CDynamicSize::HT_SIZE_AUTO, {0.88F, 0.0F}})->gap(12)->commence();
    outer->setMargin(20);
    outer->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    outer->setPositionFlag(IElement::HT_POSITION_FLAG_CENTER, true);
    window->m_rootElement->addChild(outer);

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text(std::string{title})
                                 ->fontSize({CFontSize::HT_FONT_H2})
                                 ->color([] { return g_backend->getPalette()->m_colors.text; })
                                 ->commence()));

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text(std::string{opts.subtitle.empty() ? "sudo for " + user : opts.subtitle})
                                 ->fontSize({CFontSize::HT_FONT_SMALL})
                                 ->color([] { return g_backend->getPalette()->m_colors.text.darken(0.3); })
                                 ->commence()));

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text(std::string{!opts.heading.empty() ? opts.heading
                                                       : cmd.empty()       ? std::string{"Authentication is needed for sudo."}
                                                                           : std::string{"Allow this command?"}})
                                 ->fontSize({CFontSize::HT_FONT_H3})
                                 ->color([] { return g_backend->getPalette()->m_colors.text; })
                                 ->commence()));

    if (!cmd.empty()) {
        auto box = CRectangleBuilder::begin()
                       ->color([] { return g_backend->getPalette()->m_colors.alternateBase; })
                       ->rounding(palette->m_vars.bigRounding)
                       ->size(CDynamicSize{CDynamicSize::HT_SIZE_AUTO, CDynamicSize::HT_SIZE_AUTO, {}})
                       ->commence();
        // continuation lines are indented under the first so the command reads as one block
        std::string body;
        std::string gutter;
        for (size_t i = 0; i < cmdLines.size(); ++i) {
            body += (i ? "\n" : "") + cmdLines[i];
            gutter += i ? "\n " : "#";
        }
        auto inner = CRowLayoutBuilder::begin()->gap(8)->commence();
        inner->setMargin(12);
        if (!bodyMode)
            inner->addChild(CTextBuilder::begin()
                            ->text(std::string{gutter})
                            ->fontFamily(std::string{palette->m_vars.fontFamilyMonospace})
                            ->align(HT_FONT_ALIGN_LEFT)
                            ->color([] { return g_backend->getPalette()->m_colors.accent; })
                            ->commence());
        inner->addChild(CTextBuilder::begin()
                            ->text(std::string{body})
                            ->fontFamily(std::string{palette->m_vars.fontFamilyMonospace})
                            ->align(HT_FONT_ALIGN_LEFT)
                            ->color([] { return g_backend->getPalette()->m_colors.text; })
                            ->commence());
        box->addChild(inner);
        outer->addChild(centered(box));
    }

    // the password field: drawn here rather than a password Textbox so the mask can be theme symbols
    fieldBox = CRectangleBuilder::begin()
                   ->color([] { return g_backend->getPalette()->m_colors.base; })
                   ->borderColor([] { return g_backend->getPalette()->m_colors.accent; })
                   ->borderThickness(1)
                   ->rounding(palette->m_vars.smallRounding)
                   ->size({CDynamicSize::HT_SIZE_ABSOLUTE, CDynamicSize::HT_SIZE_ABSOLUTE, {FIELD_W, 36.0}})
                   ->commence();
    auto fieldRow = CRowLayoutBuilder::begin()->commence();
    fieldRow->setMargin(9);
    fieldRow->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    fieldRow->setPositionFlag(IElement::HT_POSITION_FLAG_VCENTER, true);
    fieldText = CTextBuilder::begin()
                    ->text(std::string{opts.placeholder.empty() ? std::string{"Password"} : opts.placeholder})
                    ->fontFamily(std::string{palette->m_vars.fontFamilyMonospace})
                    ->align(HT_FONT_ALIGN_LEFT)
                    ->noEllipsize(true)
                    // fixed width: measured from the "Password" placeholder, live updates wrap one glyph per line
                    ->size({CDynamicSize::HT_SIZE_ABSOLUTE, CDynamicSize::HT_SIZE_ABSOLUTE, {FIELD_W - 18.0 - EYE_W, 22.0}})
                    // white once filled, in case the text color tints the rendered spans
                    ->color([] {
                        if (!g_passLen)
                            return g_backend->getPalette()->m_colors.text.darken(0.5);
                        return g_reveal ? g_backend->getPalette()->m_colors.text : CHyprColor{1.F, 1.F, 1.F, 1.F};
                    })
                    ->commence();
    fieldRow->addChild(fieldText);
    fieldBox->addChild(fieldRow);

    // eye toggle at the field's right edge: nf-fa-eye / nf-fa-eye_slash, padded with a
    // no-break space because the Nerd Font glyph draws wider than its measured width
    CSharedPointer<CButtonElement> eyeButton = CButtonBuilder::begin()
                                                   ->label(std::string{"\uF06E\u00A0"})
                                                   ->noBorder(true)
                                                   ->noBg(true)
                                                   ->size({CDynamicSize::HT_SIZE_ABSOLUTE, CDynamicSize::HT_SIZE_ABSOLUTE, {EYE_W, 30.0}})
                                                   ->onMainClick([&](CSharedPointer<CButtonElement> self) {
                                                       g_reveal = !g_reveal;
                                                       self->setLabel(g_reveal ? "\uF070\u00A0" : "\uF06E\u00A0");
                                                       updateField();
                                                   })
                                                   ->commence();
    auto eyeWrap = CRowLayoutBuilder::begin()->commence();
    eyeWrap->setMargin(3);    // keep clear of the border and rounding
    eyeWrap->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    eyeWrap->setPositionFlag(IElement::HT_POSITION_FLAG_RIGHT, true);
    eyeWrap->setPositionFlag(IElement::HT_POSITION_FLAG_VCENTER, true);
    eyeWrap->addChild(eyeButton);
    fieldBox->addChild(eyeWrap);
    outer->addChild(centered(fieldBox));

    updateField = [&] {
        fieldText->setText(!g_passLen ? (opts.placeholder.empty() ? std::string{"Password"} : opts.placeholder) : g_reveal ? revealMarkup() : maskMarkup(mask, g_passLen));
        if (authButton)
            authButton->setEnabled(g_passLen > 0);
    };

    statusCol = CColumnLayoutBuilder::begin()->gap(4)->commence();
    statusCol->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    statusCol->setPositionFlag(IElement::HT_POSITION_FLAG_HCENTER, true);
    outer->addChild(statusCol);
    capsLabel = CTextBuilder::begin()
                    ->text(std::string{"Caps Lock is on"})
                    ->fontSize({CFontSize::HT_FONT_SMALL})
                    ->color([] { return CHyprColor{1.0F, 0.75F, 0.2F, 1.F}; })
                    ->commence();
    capsWrap = centered(capsLabel);
    // e.g. gpg's "Bad Passphrase (try 2 of 3)"
    if (!opts.error.empty())
        statusCol->addChild(centered(CTextBuilder::begin()
                                         ->text(std::string{opts.error})
                                         ->fontSize({CFontSize::HT_FONT_SMALL})
                                         ->color([] { return CHyprColor{1.0F, 0.42F, 0.42F, 1.F}; })
                                         ->commence()));

    auto btnRow = CRowLayoutBuilder::begin()->gap(10)->commence();
    btnRow->setMargin(8);
    btnRow->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    btnRow->setPositionFlag(IElement::HT_POSITION_FLAG_HCENTER, true);
    btnRow->addChild(CButtonBuilder::begin()
                         ->label(std::string{"Cancel"})
                         ->noBorder(true)
                         ->noBg(true)
                         ->onMainClick([](CSharedPointer<CButtonElement>) { finish(false); })
                         ->commence());
    authButton = CButtonBuilder::begin()
                     ->label(std::string{"Authenticate"})
                     ->enabled(false)
                     ->onMainClick([](CSharedPointer<CButtonElement>) {
                         if (!g_password.empty())
                             finish(true);
                     })
                     ->commence();
    btnRow->addChild(authButton);
    outer->addChild(btnRow);

    window->open();
    g_backend->enterLoop();
    return 1;
}
