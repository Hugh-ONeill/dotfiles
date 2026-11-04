// sudo password prompt drawn with hyprtoolkit, laid out like hyprpolkitagent's dialog
// Usage: sudo-askpass-hypr "<prompt>"   (run by ~/.local/bin/sudo-askpass; prints the password on stdout, exit 1 on cancel)
//
// Layout and sizes follow hyprpolkitagent v0.2.0 src/ui/Dialog.cpp (BSD-3-Clause, Hypr Development).

#include <hyprtoolkit/core/Backend.hpp>
#include <hyprtoolkit/core/Input.hpp>
#include <hyprtoolkit/element/Button.hpp>
#include <hyprtoolkit/element/ColumnLayout.hpp>
#include <hyprtoolkit/element/Rectangle.hpp>
#include <hyprtoolkit/element/RowLayout.hpp>
#include <hyprtoolkit/element/Text.hpp>
#include <hyprtoolkit/element/Textbox.hpp>
#include <hyprtoolkit/palette/Color.hpp>
#include <hyprtoolkit/types/FontTypes.hpp>
#include <hyprtoolkit/types/SizeType.hpp>
#include <hyprtoolkit/window/Window.hpp>

#include <xkbcommon/xkbcommon-keysyms.h>

#include <cstdio>
#include <fcntl.h>
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

static CSharedPointer<IBackend> g_backend;
static std::string              g_password;
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

static CSharedPointer<IElement> centered(CSharedPointer<IElement> child) {
    auto wrap = CRowLayoutBuilder::begin()->commence();
    wrap->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    wrap->setPositionFlag(IElement::HT_POSITION_FLAG_HCENTER, true);
    wrap->addChild(child);
    return wrap;
}

// -------------------- Dialog --------------------

int main(int, char*[]) {
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

    const std::string cmd      = sudoCommand();
    const auto        cmdLines = wrapCommand(cmd);
    const double      height   = WINDOW_H + (cmdLines.size() > 1 ? (double)(cmdLines.size() - 1) * LINE_H : 0.0);

    auto window = CWindowBuilder::begin()
                      ->preferredSize({WINDOW_W, height})
                      ->minSize({460.0, height})
                      ->maxSize({600.0, height})
                      ->appTitle("Authentication Required")
                      ->appClass("sudo-askpass")
                      ->commence();

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
        if (!ev.down || ev.repeat)
            return;
        if ((ev.xkbKeysym == XKB_KEY_Return || ev.xkbKeysym == XKB_KEY_KP_Enter) && !g_password.empty())
            finish(true);
        else if (ev.xkbKeysym == XKB_KEY_Escape)
            finish(false);
    });

    window->m_rootElement->addChild(CRectangleBuilder::begin()->color([] { return g_backend->getPalette()->m_colors.background; })->commence());

    auto outer = CColumnLayoutBuilder::begin()->size({CDynamicSize::HT_SIZE_PERCENT, CDynamicSize::HT_SIZE_AUTO, {0.88F, 0.0F}})->gap(12)->commence();
    outer->setMargin(20);
    outer->setPositionMode(IElement::HT_POSITION_ABSOLUTE);
    outer->setPositionFlag(IElement::HT_POSITION_FLAG_CENTER, true);
    window->m_rootElement->addChild(outer);

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text(std::string{"Authentication Required"})
                                 ->fontSize({CFontSize::HT_FONT_H2})
                                 ->color([] { return g_backend->getPalette()->m_colors.text; })
                                 ->commence()));

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text("sudo for " + user)
                                 ->fontSize({CFontSize::HT_FONT_SMALL})
                                 ->color([] { return g_backend->getPalette()->m_colors.text.darken(0.3); })
                                 ->commence()));

    outer->addChild(centered(CTextBuilder::begin()
                                 ->text(std::string{cmd.empty() ? "Authentication is needed for sudo." : "Allow this command?"})
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

    auto field = CTextboxBuilder::begin()
                     ->placeholder(std::string{"Password"})
                     ->password(true)
                     ->eyeIcon(true)
                     ->multiline(false)
                     ->size({CDynamicSize::HT_SIZE_ABSOLUTE, CDynamicSize::HT_SIZE_ABSOLUTE, {FIELD_W, 36.0}})
                     ->onTextEdited([&](CSharedPointer<CTextboxElement>, const std::string& s) {
                         g_password = s;
                         if (authButton)
                             authButton->setEnabled(!s.empty());
                     })
                     ->commence();
    outer->addChild(centered(field));

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
    field->focus();
    g_backend->enterLoop();
    return 1;
}
