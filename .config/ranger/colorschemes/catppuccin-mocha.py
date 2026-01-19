from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import default_colors, reverse, bold, normal, default

class CatppuccinMocha(ColorScheme):
    progress_bar_color = 183  # lavender

    def use(self, context):
        fg, bg, attr = default_colors

        if context.reset:
            return default_colors

        elif context.in_browser:
            if context.selected:
                attr = reverse
            else:
                attr = normal

            if context.empty or context.error:
                fg = 210  # red
                bg = default

            if context.border:
                fg = 60  # surface2

            if context.document:
                fg = 195  # text

            if context.media:
                if context.image:
                    fg = 183  # lavender
                elif context.video:
                    fg = 216  # peach
                elif context.audio:
                    fg = 222  # yellow
                else:
                    fg = 183  # lavender

            if context.container:
                fg = 210  # red

            if context.directory:
                fg = 111  # blue
                attr |= bold

            elif context.executable and not any((context.media, context.container, context.fifo, context.socket)):
                fg = 114  # green
                attr |= bold

            if context.socket:
                fg = 183  # lavender
                attr |= bold

            if context.fifo or context.device:
                fg = 222  # yellow
                if context.device:
                    attr |= bold

            if context.link:
                fg = 153  # sky
                if context.good:
                    attr |= bold

            if context.tag_marker and not context.selected:
                attr |= bold
                if fg in (210, 183):  # red, lavender
                    fg = 195  # text
                else:
                    fg = 210  # red

            if not context.selected and (context.cut or context.copied):
                fg = 60  # surface2
                attr |= bold

            if context.main_column:
                if context.selected:
                    attr |= bold
                if context.marked:
                    attr |= bold
                    fg = 222  # yellow

            if context.badinfo:
                if attr & reverse:
                    bg = 210  # red
                else:
                    fg = 210  # red

            if context.inactive_pane:
                fg = 102  # overlay0

        elif context.in_titlebar:
            attr |= bold
            if context.hostname:
                fg = 114  # green if good else red
                if context.bad:
                    fg = 210  # red
            elif context.directory:
                fg = 111  # blue
            elif context.tab:
                if context.good:
                    bg = 60  # surface2
            elif context.link:
                fg = 153  # sky

        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = 114  # green
                elif context.bad:
                    fg = 210  # red

            if context.marked:
                attr |= bold | reverse
                fg = 222  # yellow

            if context.frozen:
                attr |= bold | reverse
                fg = 153  # sky

            if context.message:
                if context.bad:
                    attr |= bold
                    fg = 210  # red

            if context.loaded:
                bg = self.progress_bar_color

            if context.vcsinfo:
                fg = 111  # blue
                attr &= ~bold

            if context.vcscommit:
                fg = 222  # yellow
                attr &= ~bold

            if context.vcsdate:
                fg = 153  # sky
                attr &= ~bold

        if context.text:
            if context.highlight:
                attr |= reverse

        if context.in_taskview:
            if context.title:
                fg = 111  # blue

            if context.selected:
                attr |= reverse

            if context.loaded:
                if context.selected:
                    fg = self.progress_bar_color
                else:
                    bg = self.progress_bar_color

        if context.vcsfile and not context.selected:
            attr &= ~bold
            if context.vcsconflict:
                fg = 210  # red
            elif context.vcsuntracked:
                fg = 153  # sky
            elif context.vcschanged:
                fg = 210  # red
            elif context.vcsunknown:
                fg = 210  # red
            elif context.vcsstaged:
                fg = 114  # green
            elif context.vcssync:
                fg = 114  # green
            elif context.vcsignored:
                fg = default

        elif context.vcsremote and not context.selected:
            attr &= ~bold
            if context.vcssync or context.vcsnone:
                fg = 114  # green
            elif context.vcsbehind:
                fg = 210  # red
            elif context.vcsahead:
                fg = 111  # blue
            elif context.vcsdiverged:
                fg = 210  # red
            elif context.vcsunknown:
                fg = 210  # red

        return fg, bg, attr
