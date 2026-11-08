#!/usr/bin/env python3
# Snake Chase -- collect $, lay traps, outrun the pursuing snake
# Usage: python3 snake_chase.py

import curses
import random
import time
from collections import deque

# ============================================================
# CONSTANTS
# ============================================================

TICK_S = 0.10
POLL_MS = 40
TRAP_COST = 3
TRAP_FREEZE = 25
INIT_SNAKE_LEN = 4
GROW_INTERVAL = 20
MONEY_INTERVAL = 30
MAX_MONEY = 10
BASE_CHASE = 0.78
INTERCEPT_CHANCE = 0.25

# ---- Directions ----

UP    = (-1, 0)
DOWN  = ( 1, 0)
LEFT  = ( 0,-1)
RIGHT = ( 0, 1)
ALL_DIRS = [UP, DOWN, LEFT, RIGHT]

# ---- Snake characters (Legacy Computing Supplement U+1CC70) ----

HEAD_OPEN = {
    LEFT:  '\U0001CC70',  # 𜱰  left-facing snake head, open mouth
    UP:    '\U0001CC71',  # 𜱱  up-facing snake head, open mouth
    RIGHT: '\U0001CC72',  # 𜱲  right-facing snake head, open mouth
    DOWN:  '\U0001CC73',  # 𜱳  down-facing snake head, open mouth
}

HEAD_CLOSED = {
    LEFT:  '\U0001CC74',  # 𜱴  left-facing snake head, closed mouth
    UP:    '\U0001CC75',  # 𜱵  up-facing snake head, closed mouth
    RIGHT: '\U0001CC76',  # 𜱶  right-facing snake head, closed mouth
    DOWN:  '\U0001CC77',  # 𜱷  down-facing snake head, closed mouth
}

# body segments: key = frozenset of two neighbor directions
BODY_CH = {
    frozenset([LEFT, RIGHT]): '\u2501',  # ━  horizontal
    frozenset([UP, DOWN]):    '\u2503',  # ┃  vertical
    frozenset([RIGHT, DOWN]): '\u256d',  # ╭  top-left curve
    frozenset([LEFT, DOWN]):  '\u256e',  # ╮  top-right curve
    frozenset([RIGHT, UP]):   '\u2570',  # ╰  bottom-left curve
    frozenset([LEFT, UP]):    '\u256f',  # ╯  bottom-right curve
}

# tail tip: heavy stubs connecting toward body
TAIL_CH = {
    UP:    '\u2579',  # ╹  heavy up stub
    DOWN:  '\u257b',  # ╻  heavy down stub
    LEFT:  '\u2578',  # ╸  heavy left stub
    RIGHT: '\u257a',  # ╺  heavy right stub
}


# ============================================================
# GAME
# ============================================================

class Game:
    def __init__(self, stdscr):
        self.scr = stdscr
        curses.curs_set(0)
        curses.start_color()
        curses.use_default_colors()

        curses.init_pair(1, curses.COLOR_GREEN,   -1)  # player
        curses.init_pair(2, curses.COLOR_RED,     -1)  # snake head
        curses.init_pair(3, curses.COLOR_RED,     -1)  # snake body
        curses.init_pair(4, curses.COLOR_YELLOW,  -1)  # money
        curses.init_pair(5, curses.COLOR_CYAN,    -1)  # traps
        curses.init_pair(6, curses.COLOR_WHITE,   -1)  # border / ui
        curses.init_pair(7, curses.COLOR_MAGENTA, -1)  # frozen snake
        curses.init_pair(8, curses.COLOR_WHITE, curses.COLOR_RED)  # death

        self.high_score = 0
        self._calc_dims()

    # ---- Dimensions ----

    def _calc_dims(self):
        max_h, max_w = self.scr.getmaxyx()
        self.ph = min(max_h - 4, 28)  # play area height (with border)
        self.pw = min(max_w - 2, 78)  # play area width  (with border)
        self.oy = 2                    # y offset (HUD above)
        self.ox = 1                    # x offset

    # ---- Reset ----

    def reset(self):
        self._calc_dims()
        self.player = [self.ph // 2, self.pw // 2]
        self.player_dir = None
        self.wallet = 0
        self.score = 0

        self.snake = deque()
        for i in range(INIT_SNAKE_LEN):
            self.snake.append((2, 2 + INIT_SNAKE_LEN - 1 - i))
        self.snake_len = INIT_SNAKE_LEN
        self.snake_frozen = 0

        self.money = set()
        self.traps = set()
        self.tick = 0
        self.alive = True

        for _ in range(3):
            self._spawn_money()

    # ---- Spawning ----

    def _spawn_money(self):
        if len(self.money) >= MAX_MONEY:
            return
        body = set(self.snake)
        for _ in range(200):
            y = random.randint(1, self.ph - 2)
            x = random.randint(1, self.pw - 2)
            p = (y, x)
            if (p != tuple(self.player) and p not in body
                    and p not in self.money and p not in self.traps):
                self.money.add(p)
                return

    # ---- Snake AI ----

    def _snake_ai(self):
        hy, hx = self.snake[0]
        ty, tx = self.player

        # occasionally predict where the player is heading
        if self.player_dir and random.random() < INTERCEPT_CHANCE:
            steps = random.randint(2, 5)
            ty = max(1, min(self.ph - 2, ty + self.player_dir[0] * steps))
            tx = max(1, min(self.pw - 2, tx + self.player_dir[1] * steps))

        # score every direction: filter walls/body, rank by distance
        body = set(list(self.snake)[:-1])
        candidates = []
        for d in ALL_DIRS:
            ny, nx = hy + d[0], hx + d[1]
            if ny < 1 or ny > self.ph - 2 or nx < 1 or nx > self.pw - 2:
                continue
            if (ny, nx) in body:
                continue
            dist = abs(ny - ty) + abs(nx - tx)
            candidates.append((d, dist))

        if not candidates:
            return random.choice(ALL_DIRS)

        candidates.sort(key=lambda c: c[1])

        # chase probability ramps up over time
        chase = min(0.95, BASE_CHASE + self.tick * 0.00008)
        if random.random() < chase:
            best = candidates[0][1]
            tied = [c for c in candidates if c[1] == best]
            return random.choice(tied)[0]
        else:
            return random.choice(candidates)[0]

    # ---- Snake visuals ----

    def _snake_char(self, idx):
        """Return the display character for the snake segment at idx."""
        seg = self.snake[idx]

        # head: open mouth when chasing, closed when frozen
        if idx == 0:
            if len(self.snake) > 1:
                nxt = self.snake[1]
                facing = (seg[0] - nxt[0], seg[1] - nxt[1])
                heads = HEAD_CLOSED if self.snake_frozen > 0 else HEAD_OPEN
                return heads.get(facing, 'S')
            return 'S'

        # direction toward head
        prev = self.snake[idx - 1]
        d_prev = (prev[0] - seg[0], prev[1] - seg[1])

        # tail tip: stub in direction of body
        if idx == len(self.snake) - 1:
            return TAIL_CH.get(d_prev, '\u00b7')

        # body: connect toward-head and toward-tail neighbors
        nxt = self.snake[idx + 1]
        d_next = (nxt[0] - seg[0], nxt[1] - seg[1])
        key = frozenset([d_prev, d_next])
        return BODY_CH.get(key, '\u2501')

    # ---- Movement ----

    def _move_snake(self):
        if self.snake_frozen > 0:
            self.snake_frozen -= 1
            return

        d = self._snake_ai()
        hy, hx = self.snake[0]
        nh = (max(1, min(self.ph - 2, hy + d[0])),
              max(1, min(self.pw - 2, hx + d[1])))

        self.snake.appendleft(nh)
        while len(self.snake) > self.snake_len:
            self.snake.pop()

        # trap check
        if nh in self.traps:
            self.traps.discard(nh)
            self.snake_frozen = TRAP_FREEZE

    def _move_player(self):
        if not self.player_dir:
            return
        ny = self.player[0] + self.player_dir[0]
        nx = self.player[1] + self.player_dir[1]
        self.player[0] = max(1, min(self.ph - 2, ny))
        self.player[1] = max(1, min(self.pw - 2, nx))

    # ---- Collisions ----

    def _check_collisions(self):
        pos = tuple(self.player)
        if pos in self.money:
            self.money.discard(pos)
            self.wallet += 1
            self.score += 10

        if pos in set(self.snake):
            self.alive = False
            self.high_score = max(self.high_score, self.score)

    def _place_trap(self):
        if self.wallet < TRAP_COST:
            return
        pos = tuple(self.player)
        if pos not in self.traps and pos not in set(self.snake):
            self.traps.add(pos)
            self.wallet -= TRAP_COST

    # ---- Update ----

    def update(self):
        self._move_player()
        self._move_snake()
        self._check_collisions()

        self.tick += 1
        if self.tick % GROW_INTERVAL == 0:
            self.snake_len += 1
        if self.tick % MONEY_INTERVAL == 0:
            self._spawn_money()

    # ---- Drawing helpers ----

    def _put(self, y, x, ch, attr=0):
        try:
            self.scr.addstr(y, x, ch, attr)
        except curses.error:
            pass

    # ---- Draw ----

    def draw(self):
        self.scr.erase()
        oy, ox = self.oy, self.ox

        # HUD
        hud = (f" $:{self.wallet}  Score:{self.score}  Hi:{self.high_score}"
               f"  Traps:{len(self.traps)}  [T]=${TRAP_COST}")
        self._put(0, 1, hud, curses.A_BOLD | curses.color_pair(6))

        if self.snake_frozen > 0:
            self._put(1, 1, f" <<< SNAKE FROZEN {self.snake_frozen} >>>",
                      curses.color_pair(7) | curses.A_BOLD)

        # border
        bd = curses.color_pair(6) | curses.A_DIM
        for x in range(self.pw):
            t = "\u2554" if x == 0 else "\u2557" if x == self.pw - 1 else "\u2550"
            b = "\u255a" if x == 0 else "\u255d" if x == self.pw - 1 else "\u2550"
            self._put(oy, ox + x, t, bd)
            self._put(oy + self.ph - 1, ox + x, b, bd)
        for y in range(1, self.ph - 1):
            self._put(oy + y, ox, "\u2551", bd)
            self._put(oy + y, ox + self.pw - 1, "\u2551", bd)

        # traps
        for ty, tx in self.traps:
            self._put(oy + ty, ox + tx, "\u25b2",
                      curses.color_pair(5) | curses.A_BOLD)

        # money
        for my, mx in self.money:
            self._put(oy + my, ox + mx, "$",
                      curses.color_pair(4) | curses.A_BOLD)

        # snake
        frozen = self.snake_frozen > 0
        for i, (sy, sx) in enumerate(self.snake):
            ch = self._snake_char(i)
            if i == 0:
                attr = curses.A_BOLD | curses.color_pair(7 if frozen else 2)
            else:
                attr = curses.color_pair(7 if frozen else 3)
            self._put(oy + sy, ox + sx, ch, attr)

        # player (drawn last so it's always visible)
        self._put(oy + self.player[0], ox + self.player[1], "@",
                  curses.color_pair(1) | curses.A_BOLD)

        # controls
        self._put(oy + self.ph, 1,
                  " WASD/Arrows:move  T:trap  Space:stop  Q:quit",
                  curses.A_DIM)

        self.scr.refresh()

    # ---- Screens ----

    def draw_title(self):
        self.scr.erase()
        lines = [
            "",
            "S N A K E   C H A S E",
            "",
            "You: @    Snake: \U0001CC72\u2501\u2501\u2501\u2578",
            "Money: $    Trap: \u25b2 ($3)",
            "",
            "WASD / Arrows  :  Move",
            "T              :  Place trap ($3)",
            "Space          :  Stop moving",
            "Q              :  Quit",
            "",
            "Collect $ while avoiding the snake.",
            "Spend $ on traps to freeze it.",
            "The snake NEVER stops -- even when you do!",
            "",
            "Press any key to start...",
        ]
        max_h, max_w = self.scr.getmaxyx()
        start_y = max(0, (max_h - len(lines)) // 2)
        for i, line in enumerate(lines):
            x = max(0, (max_w - len(line)) // 2)
            attr = curses.A_BOLD if i == 1 else curses.A_DIM if i == len(lines) - 1 else 0
            if i == 1:
                attr |= curses.color_pair(2)
            self._put(start_y + i, x, line, attr)
        self.scr.refresh()

    def draw_game_over(self):
        oy, ox = self.oy, self.ox

        # mark death spot
        self._put(oy + self.player[0], ox + self.player[1], "X",
                  curses.color_pair(8) | curses.A_BOLD)

        cy = oy + self.ph // 2
        msg1 = f"  GAME OVER  --  Score: {self.score}  "
        msg2 = "  [R]estart  [Q]uit  "
        cx1 = ox + max(0, (self.pw - len(msg1)) // 2)
        cx2 = ox + max(0, (self.pw - len(msg2)) // 2)
        self._put(cy,     cx1, msg1, curses.color_pair(8) | curses.A_BOLD)
        self._put(cy + 1, cx2, msg2, curses.color_pair(8) | curses.A_BOLD)
        self.scr.refresh()

    # ---- Input ----

    def _process_key(self, key):
        """Returns 'quit' or 'trap' or None."""
        if key in (ord('q'), ord('Q')):
            return 'quit'
        elif key in (curses.KEY_UP, ord('w'), ord('W')):
            self.player_dir = UP
        elif key in (curses.KEY_DOWN, ord('s'), ord('S')):
            self.player_dir = DOWN
        elif key in (curses.KEY_LEFT, ord('a'), ord('A')):
            self.player_dir = LEFT
        elif key in (curses.KEY_RIGHT, ord('d'), ord('D')):
            self.player_dir = RIGHT
        elif key == ord(' '):
            self.player_dir = None
        elif key in (ord('t'), ord('T')):
            return 'trap'
        return None

    # ---- Main loop ----

    def run(self):
        self.draw_title()
        self.scr.nodelay(False)
        self.scr.getch()

        while True:
            self.reset()

            # countdown
            for n in (3, 2, 1):
                self.draw()
                cy = self.oy + self.ph // 2
                cx = self.ox + self.pw // 2
                self._put(cy, cx - 1, f" {n} ",
                          curses.color_pair(6) | curses.A_BOLD)
                self.scr.refresh()
                time.sleep(0.6)

            # game loop with fixed timestep
            self.scr.nodelay(True)
            last = time.monotonic()

            while self.alive:
                # drain input
                while True:
                    key = self.scr.getch()
                    if key == -1:
                        break
                    action = self._process_key(key)
                    if action == 'quit':
                        return
                    if action == 'trap':
                        self._place_trap()

                now = time.monotonic()
                if now - last >= TICK_S:
                    last += TICK_S
                    # prevent spiral if system hiccups
                    if now - last > TICK_S * 3:
                        last = now
                    self.update()
                    self.draw()

                time.sleep(0.006)

            # death
            self.draw_game_over()
            self.scr.nodelay(False)
            while True:
                key = self.scr.getch()
                if key in (ord('q'), ord('Q')):
                    return
                if key in (ord('r'), ord('R')):
                    break


# ============================================================
# ENTRY
# ============================================================

def main(stdscr):
    h, w = stdscr.getmaxyx()
    if h < 14 or w < 30:
        stdscr.addstr(0, 0, "Terminal too small (need 30x14+)")
        stdscr.getch()
        return
    Game(stdscr).run()


if __name__ == '__main__':
    curses.wrapper(main)
