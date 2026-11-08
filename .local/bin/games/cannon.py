#!/usr/bin/env python3
# Cannon Blaster -- physics-based cannon shooting game
# Usage: python3 cannon.py

import curses
import math
import random
import time
from dataclasses import dataclass, field

# ============================================================
#                         CONSTANTS
# ============================================================

GRAVITY = 9.81
PHYSICS_DT = 0.015
DRAG = 0.003
MIN_ANGLE, MAX_ANGLE = 5.0, 85.0
MIN_POWER, MAX_POWER = 10.0, 100.0

# ground bounce
GROUND_BOUNCE = 0.55
GROUND_FRICTION = 0.85
MIN_BOUNCE_SPEED = 2.0
MAX_BOUNCES = 30

# objects
TRAMPOLINE_BOUNCE = 1.15
TRAMPOLINE_WIDTH = 10.0
EXPLOSION_FORCE = 55.0
EXPLOSION_RADIUS = 7.0
MINE_FORCE = 45.0
MINE_RADIUS = 6.0
SPEED_MULT = 2.5
SPEED_GATE_XTOL = 4.0
PORTAL_RADIUS = 5.0
WORLD_LENGTH = 2000
MAX_TRAIL = 4000


# ============================================================
#                       GAME OBJECTS
# ============================================================

@dataclass
class Cannonball:
    x: float = 5.0
    y: float = 2.5
    vx: float = 0.0
    vy: float = 0.0
    active: bool = True
    trail: list = field(default_factory=list)
    max_height: float = 0.0
    max_x: float = 0.0
    bounces: int = 0
    _tick: int = 0

    def step(self, dt, wind=0.0, gravity=GRAVITY):
        if not self.active:
            return
        self._tick += 1
        if self._tick % 2 == 0:
            self.trail.append((self.x, self.y))
            if len(self.trail) > MAX_TRAIL:
                self.trail = self.trail[::2]
        # forces
        self.vx += wind * dt
        self.vy -= gravity * dt
        # air resistance (velocity-dependent)
        speed = math.hypot(self.vx, self.vy)
        if speed > 0:
            df = max(0.0, 1.0 - DRAG * speed * dt)
            self.vx *= df
            self.vy *= df
        # position
        self.x += self.vx * dt
        self.y += self.vy * dt
        if self.y > self.max_height:
            self.max_height = self.y
        if self.x > self.max_x:
            self.max_x = self.x
        # ground bounce
        if self.y <= 0 and self.vy < 0:
            self.bounces += 1
            self.vy = abs(self.vy) * GROUND_BOUNCE
            self.vx *= GROUND_FRICTION
            self.y = 0.1
            if (math.hypot(self.vx, self.vy) < MIN_BOUNCE_SPEED
                    or self.bounces > MAX_BOUNCES):
                self.active = False
                self.y = 0


@dataclass
class Trampoline:
    x: float
    width: float = TRAMPOLINE_WIDTH
    triggered: bool = False

    def check(self, b):
        return b.vy < 0 and b.y <= 3.5 and abs(b.x - self.x) < self.width / 2

    def apply(self, b):
        b.vy = abs(b.vy) * TRAMPOLINE_BOUNCE
        b.y = 3.0
        self.triggered = True


@dataclass
class Explosive:
    x: float
    y: float = 1.5
    radius: float = EXPLOSION_RADIUS
    triggered: bool = False

    def check(self, b):
        return math.hypot(b.x - self.x, b.y - self.y) < self.radius

    def apply(self, b):
        dx, dy = b.x - self.x, b.y - self.y
        d = max(math.hypot(dx, dy), 0.3)
        b.vx += EXPLOSION_FORCE * dx / d
        b.vy += EXPLOSION_FORCE * dy / d
        self.triggered = True


@dataclass
class FloatingMine:
    x: float
    y: float
    radius: float = MINE_RADIUS
    triggered: bool = False

    def check(self, b):
        return math.hypot(b.x - self.x, b.y - self.y) < self.radius

    def apply(self, b):
        dx, dy = b.x - self.x, b.y - self.y
        d = max(math.hypot(dx, dy), 0.3)
        b.vx += MINE_FORCE * dx / d
        b.vy += MINE_FORCE * dy / d
        self.triggered = True


@dataclass
class SpeedGate:
    x: float
    y_lo: float
    y_hi: float
    multiplier: float = SPEED_MULT
    triggered: bool = False

    def check(self, b):
        return abs(b.x - self.x) < SPEED_GATE_XTOL and self.y_lo <= b.y <= self.y_hi

    def apply(self, b):
        b.vx *= self.multiplier
        self.triggered = True


@dataclass
class GravityWell:
    x: float
    y: float
    radius: float = 18.0
    factor: float = 0.12
    triggered: bool = False

    def in_range(self, b):
        return math.hypot(b.x - self.x, b.y - self.y) < self.radius

    def check(self, b):
        return False

    def apply(self, b):
        pass


@dataclass
class Portal:
    x1: float
    y1: float
    x2: float
    y2: float
    label: str = 'A'
    radius: float = PORTAL_RADIUS
    triggered: bool = False

    def check(self, b):
        d1 = math.hypot(b.x - self.x1, b.y - self.y1)
        d2 = math.hypot(b.x - self.x2, b.y - self.y2)
        return d1 < self.radius or d2 < self.radius

    def apply(self, b):
        if math.hypot(b.x - self.x1, b.y - self.y1) < self.radius:
            b.x, b.y = self.x2, self.y2
        else:
            b.x, b.y = self.x1, self.y1
        self.triggered = True


# ============================================================
#                     WORLD GENERATION
# ============================================================

def spawn_objects():
    objs = []
    x = 25.0
    plabel = ord('A')
    while x < WORLD_LENGTH:
        x += random.uniform(12, 40)
        r = random.random()
        if r < 0.20:
            objs.append(Trampoline(x=x))
        elif r < 0.35:
            objs.append(Explosive(x=x))
        elif r < 0.48:
            objs.append(FloatingMine(x=x, y=random.uniform(6, 25)))
        elif r < 0.60:
            y_lo = random.uniform(2, 12)
            objs.append(SpeedGate(x=x, y_lo=y_lo,
                                  y_hi=y_lo + random.uniform(8, 18)))
        elif r < 0.78:
            if random.random() < 0.3:
                fac = random.uniform(-0.2, -0.08)
            else:
                fac = random.uniform(0.05, 0.2)
            objs.append(GravityWell(
                x=x, y=random.uniform(10, 35),
                radius=random.uniform(15, 25), factor=fac,
            ))
        else:
            x2 = x + random.uniform(40, 100)
            y1 = random.uniform(5, 25)
            y2 = random.uniform(3, 20)
            objs.append(Portal(
                x1=x, y1=y1, x2=x2, y2=y2,
                label=chr(plabel),
            ))
            plabel = plabel + 1 if plabel < ord('Z') else ord('A')
            x = x2 + 10
    return objs


# ============================================================
#                     EXPLOSION EFFECT
# ============================================================

@dataclass
class Boom:
    x: float
    y: float
    frame: int = 0
    life: int = 8


# ============================================================
#                           GAME
# ============================================================

class Game:
    def __init__(self, scr):
        self.scr = scr
        self.h, self.w = scr.getmaxyx()
        curses.curs_set(0)
        scr.keypad(True)
        curses.start_color()
        curses.use_default_colors()
        for i, c in enumerate([
            curses.COLOR_YELLOW, curses.COLOR_GREEN,
            curses.COLOR_RED, curses.COLOR_CYAN,
            curses.COLOR_WHITE, curses.COLOR_MAGENTA,
            curses.COLOR_BLUE,
        ], 1):
            curses.init_pair(i, c, -1)
        self.best = 0.0
        self.sx = 1.8
        self.sy = 2.5
        self.hud = 4
        self.gh = self.h - self.hud
        self.gr = self.gh - 1

    # -------------------- Drawing --------------------

    def put(self, r, c, s, a=0):
        if r < 0 or r >= self.h:
            return
        if c < 0:
            s = s[-c:]
            c = 0
        if c + len(s) > self.w:
            s = s[:self.w - c]
        if s and 0 <= c < self.w:
            try:
                self.scr.addstr(r, c, s, a)
            except curses.error:
                pass

    def pch(self, r, c, ch, a=0):
        if 0 <= r < self.h - 1 and 0 <= c < self.w - 1:
            try:
                self.scr.addch(r, c, ch, a)
            except curses.error:
                pass

    def w2s(self, wx, wy, cx):
        return self.gr - int(wy / self.sy), int((wx - cx) / self.sx)

    def recalc(self):
        self.h, self.w = self.scr.getmaxyx()
        self.gh = self.h - self.hud
        self.gr = self.gh - 1

    # -------------------- Draw Components --------------------

    def draw_ground(self, cx):
        for c in range(self.w):
            self.pch(self.gr, c, '=', curses.color_pair(2) | curses.A_DIM)
        m0 = max(0, int(cx / 50) * 50)
        for m in range(m0, m0 + int(self.w * self.sx) + 100, 50):
            if m <= 0:
                continue
            _, c = self.w2s(m, 0, cx)
            lbl = f"{m}m"
            if 0 < c < self.w - len(lbl):
                self.put(self.gr, c, lbl, curses.color_pair(5) | curses.A_DIM)

    def draw_objects(self, objs, cx):
        for o in objs:
            if isinstance(o, Trampoline):
                _, c = self.w2s(o.x, 0, cx)
                if c < -8 or c > self.w + 8:
                    continue
                r = self.gr - 1
                if o.triggered:
                    self.put(r, c - 3, '/vvvvv\\',
                             curses.color_pair(2) | curses.A_DIM)
                else:
                    self.put(r, c - 3, '/^^^^^\\',
                             curses.color_pair(2) | curses.A_BOLD)

            elif isinstance(o, Explosive):
                _, c = self.w2s(o.x, 0, cx)
                if c < -8 or c > self.w + 8:
                    continue
                r = self.gr - 1
                if o.triggered:
                    self.put(r, c - 3, ' ***** ',
                             curses.color_pair(6))
                else:
                    self.put(r, c - 3, '[=TNT=]',
                             curses.color_pair(3) | curses.A_BOLD)

            elif isinstance(o, FloatingMine):
                r, c = self.w2s(o.x, o.y, cx)
                if c < -5 or c > self.w + 5:
                    continue
                if o.triggered:
                    self.put(r, c - 2, '*!!*',
                             curses.color_pair(6))
                else:
                    self.put(r, c - 2, '{!!}',
                             curses.color_pair(3))
                    # tether line to ground
                    gr_r = self.gr - 1
                    for dr in range(r + 1, gr_r):
                        if dr % 2 == 0:
                            self.pch(dr, c, ':',
                                     curses.color_pair(5) | curses.A_DIM)

            elif isinstance(o, SpeedGate):
                _, col = self.w2s(o.x, 0, cx)
                if col < -3 or col > self.w + 3:
                    continue
                r_lo, _ = self.w2s(o.x, o.y_lo, cx)
                r_hi, _ = self.w2s(o.x, o.y_hi, cx)
                attr = curses.A_DIM if o.triggered else curses.A_BOLD
                cp = curses.color_pair(4)
                top = max(0, r_hi)
                bot = min(self.gh, r_lo + 1)
                for r in range(top, bot):
                    self.pch(r, col, '>', cp | attr)
                    if col + 1 < self.w:
                        self.pch(r, col + 1, '>', cp | attr)
                self.put(r_hi, col - 1, 'v>>v', cp | attr)
                self.put(r_lo, col - 1, '^>>^', cp | attr)

            elif isinstance(o, GravityWell):
                cr, cc = self.w2s(o.x, o.y, cx)
                if cc < -25 or cc > self.w + 25:
                    continue
                lbl = '~^g~' if o.factor < 0 else '~0g~'
                self.put(cr, cc - 2, lbl,
                         curses.color_pair(6) | curses.A_BOLD)
                for ad in range(0, 360, 12):
                    a = math.radians(ad)
                    rr, rc = self.w2s(
                        o.x + o.radius * math.cos(a),
                        o.y + o.radius * math.sin(a), cx)
                    if 0 <= rr < self.gh and 0 <= rc < self.w:
                        self.pch(rr, rc, '~',
                                 curses.color_pair(6) | curses.A_DIM)

            elif isinstance(o, Portal):
                for px, py in [(o.x1, o.y1), (o.x2, o.y2)]:
                    r, c = self.w2s(px, py, cx)
                    if c < -4 or c > self.w + 4:
                        continue
                    dim = curses.A_DIM if o.triggered else curses.A_BOLD
                    self.put(r, c - 2, f'(@{o.label}@)',
                             curses.color_pair(7) | dim)

    def draw_booms(self, booms, cx):
        alive = []
        sparks = ['*', '+', '.', 'x', '#', '@']
        for b in booms:
            if b.frame >= b.life:
                continue
            r, c = self.w2s(b.x, b.y + b.frame * 0.4, cx)
            rad = b.frame // 2 + 2
            cp = curses.color_pair(3 if b.frame < b.life // 2 else 1)
            for dx in range(-rad, rad + 1):
                for dy in range(-rad, rad + 1):
                    if random.random() < 0.5:
                        self.pch(r + dy, c + dx,
                                 random.choice(sparks), cp | curses.A_BOLD)
            b.frame += 1
            alive.append(b)
        return alive

    def draw_trail(self, trail, cx):
        n = len(trail)
        if n == 0:
            return
        max_wx = cx + self.w * self.sx
        skip = max(1, n // 2000)
        for i in range(0, n, skip):
            tx, ty = trail[i]
            if tx < cx or tx > max_wx:
                continue
            r, c = self.w2s(tx, ty, cx)
            if 0 <= r < self.gh and 0 <= c < self.w:
                dim = curses.A_DIM if i < n - 30 else 0
                self.pch(r, c, '.', curses.color_pair(4) | dim)

    def draw_ball(self, ball, cx):
        r, c = self.w2s(ball.x, ball.y, cx)
        if 0 <= r < self.gh and 0 <= c < self.w:
            self.pch(r, c, 'O', curses.color_pair(1) | curses.A_BOLD)
        elif r < 0 and 0 <= c < self.w:
            alt = f" ^ {ball.y:.0f}m "
            self.put(0, max(0, c - len(alt) // 2), alt,
                     curses.color_pair(1) | curses.A_BOLD)

    def draw_trajectory(self, ang, pwr, wind, cx):
        rad = math.radians(ang)
        px, py = 5.0, 2.5
        pvx = pwr * math.cos(rad)
        pvy = pwr * math.sin(rad)
        dt = 0.05
        for i in range(1000):
            pvx += wind * dt
            pvy -= GRAVITY * dt
            spd = math.hypot(pvx, pvy)
            if spd > 0:
                df = max(0.0, 1.0 - DRAG * spd * dt)
                pvx *= df
                pvy *= df
            px += pvx * dt
            py += pvy * dt
            if py < 0:
                pvy = abs(pvy) * GROUND_BOUNCE
                pvx *= GROUND_FRICTION
                py = 0.1
                if math.hypot(pvx, pvy) < MIN_BOUNCE_SPEED:
                    break
            if i % 3 == 0:
                r, c = self.w2s(px, py, cx)
                if 0 <= r < self.gh and 0 <= c < self.w:
                    self.pch(r, c, '.', curses.color_pair(4) | curses.A_DIM)

    # -------------------- Aim Phase --------------------

    def aim(self, objs):
        ang = 45.0
        pwr = 50.0
        wind = random.uniform(-3.0, 3.0)
        aim_cx = 0.0
        scroll_speed = 10.0

        while True:
            self.scr.erase()

            self.draw_ground(aim_cx)
            self.draw_objects(objs, aim_cx)
            self.draw_trajectory(ang, pwr, wind, aim_cx)

            # cannon (world x=4)
            _, cannon_sc = self.w2s(4, 0, aim_cx)
            if -2 < cannon_sc < self.w + 4:
                bx, by = cannon_sc, self.gr - 1
                self.put(by, bx - 1, '[#]',
                         curses.color_pair(5) | curses.A_BOLD)
                if by + 1 <= self.gr:
                    self.put(by + 1, bx - 2, '/===\\',
                             curses.color_pair(5))
                rad = math.radians(ang)
                bch = '-' if ang < 25 else ('/' if ang < 65 else '|')
                for i in range(1, 8):
                    px = bx + round(i * math.cos(rad))
                    py = by - round(i * math.sin(rad) * 0.5)
                    ch = '*' if i == 7 else bch
                    attr = (curses.color_pair(1) if i == 7
                            else curses.color_pair(5) | curses.A_BOLD)
                    self.pch(py, px, ch, attr)

            title = ">>> CANNON BLASTER <<<"
            self.put(0, (self.w - len(title)) // 2, title,
                     curses.A_BOLD | curses.color_pair(1))

            # info panel
            pc, pr = 2, 2
            self.put(pr, pc, f"Angle:  {ang:5.1f} deg", curses.A_BOLD)
            self.put(pr + 1, pc, f"Power:  {pwr:5.1f} m/s", curses.A_BOLD)
            wa = ">>>" if wind > 0 else "<<<"
            self.put(pr + 2, pc, f"Wind:   {abs(wind):.1f} m/s {wa}",
                     curses.color_pair(4))
            bw = 20
            fill = int((pwr - MIN_POWER) / (MAX_POWER - MIN_POWER) * bw)
            self.put(pr + 3, pc, f"[{'#' * fill}{'-' * (bw - fill)}]",
                     curses.color_pair(3))
            if self.best > 0:
                self.put(pr + 4, pc, f"Best:   {self.best:.1f}m",
                         curses.color_pair(1))

            # legend
            lr = self.h - self.hud
            self.put(lr, 2,
                     '/^^^^^\\Tramp  [=TNT=]Bomb  {!!}Mine  '
                     '>>Gate  ~0g~Low-g  ~^g~Rev-g  (@A@)Portal',
                     curses.color_pair(5) | curses.A_DIM)
            cr = self.h - 2
            self.put(cr, 2,
                     "UP/DOWN: Angle   LEFT/RIGHT: Power   "
                     "[/]: Scroll   SPACE: Fire   Q: Quit",
                     curses.color_pair(5))

            self.scr.refresh()
            self.scr.nodelay(False)
            k = self.scr.getch()

            if k == curses.KEY_UP:
                ang = min(MAX_ANGLE, ang + 1)
            elif k == curses.KEY_DOWN:
                ang = max(MIN_ANGLE, ang - 1)
            elif k == curses.KEY_RIGHT:
                pwr = min(MAX_POWER, pwr + 1)
            elif k == curses.KEY_LEFT:
                pwr = max(MIN_POWER, pwr - 1)
            elif k == ord(']'):
                aim_cx += scroll_speed
            elif k == ord('['):
                aim_cx = max(0, aim_cx - scroll_speed)
            elif k == ord(' '):
                return ang, pwr, wind
            elif k in (ord('q'), ord('Q')):
                return None, None, None
            elif k == curses.KEY_RESIZE:
                self.recalc()

    # -------------------- Countdown --------------------

    def countdown(self):
        for txt in ['3', '2', '1', 'FIRE!']:
            self.scr.erase()
            self.put(self.h // 2, self.w // 2 - len(txt) // 2,
                     txt, curses.A_BOLD | curses.color_pair(3))
            self.scr.refresh()
            time.sleep(0.25)

    # -------------------- Flight Phase --------------------

    def fly(self, ang, pwr, wind, objs):
        self.countdown()

        rad = math.radians(ang)
        ball = Cannonball(
            x=5.0, y=2.5,
            vx=pwr * math.cos(rad),
            vy=pwr * math.sin(rad),
        )
        hits, booms = [], []
        cx = 0.0
        speed = 1.0
        paused = False

        self.scr.nodelay(True)
        fdt = 1.0 / 60

        while ball.active:
            t0 = time.time()

            k = self.scr.getch()
            if k in (ord('q'), ord('Q')):
                break
            elif k in (ord('+'), ord('=')):
                speed = min(5.0, speed + 0.5)
            elif k == ord('-'):
                speed = max(0.5, speed - 0.5)
            elif k == ord('p'):
                paused = not paused
            elif k == curses.KEY_RESIZE:
                self.recalc()

            if paused:
                self.put(0, self.w // 2 - 4, ' PAUSED ',
                         curses.A_REVERSE | curses.A_BOLD)
                self.scr.refresh()
                time.sleep(0.05)
                continue

            # physics
            steps = max(1, int(speed * 3))
            for _ in range(steps):
                if not ball.active:
                    break
                grav = GRAVITY
                for o in objs:
                    if isinstance(o, GravityWell) and o.in_range(ball):
                        grav *= o.factor
                ball.step(PHYSICS_DT, wind, grav)
                for o in objs:
                    if isinstance(o, GravityWell):
                        continue
                    if not o.triggered and o.check(ball):
                        o.apply(ball)
                        hits.append(o)
                        if isinstance(o, (Explosive, FloatingMine)):
                            booms.append(Boom(o.x, getattr(o, 'y', 1.5)))

            # camera
            target = ball.x - self.w * self.sx * 0.3
            cx += (target - cx) * 0.12

            # render
            self.scr.erase()
            self.draw_ground(cx)
            self.draw_objects(objs, cx)
            booms = self.draw_booms(booms, cx)
            self.draw_trail(ball.trail, cx)
            self.draw_ball(ball, cx)

            hr = self.h - self.hud
            v = math.hypot(ball.vx, ball.vy)
            self.put(hr, 1,
                     f"Dist: {ball.x:.0f}m  Height: {ball.y:.0f}m  "
                     f"Speed: {v:.0f}m/s  Max: {ball.max_height:.0f}m  "
                     f"Bounces: {ball.bounces}",
                     curses.A_BOLD)
            self.put(hr + 1, 1,
                     f"Hits: {len(hits)}  Sim: {speed:.1f}x  "
                     f"[+/-] speed  [P] pause  [Q] end",
                     curses.color_pair(5) | curses.A_DIM)

            self.scr.refresh()

            dt = time.time() - t0
            if dt < fdt:
                time.sleep(fdt - dt)

        # landing
        if not ball.active:
            self.scr.erase()
            self.draw_ground(cx)
            self.draw_objects(objs, cx)
            self.draw_trail(ball.trail, cx)
            r, c = self.w2s(ball.x, 0, cx)
            self.put(max(0, r - 1), max(0, c - 1), 'vXv',
                     curses.color_pair(3) | curses.A_BOLD)
            hr = self.h - self.hud
            self.put(hr, 1, f"LANDED -- max distance {ball.max_x:.0f}m!",
                     curses.A_BOLD | curses.color_pair(1))
            self.scr.refresh()
            time.sleep(1.2)

        self.scr.nodelay(False)
        return ball, hits

    # -------------------- Results --------------------

    def results(self, ball, hits):
        d = ball.max_x
        nr = d > self.best
        if nr:
            self.best = d

        self.scr.erase()
        mid = self.w // 2
        r = 3

        t = "=== SHOT RESULTS ==="
        self.put(r, mid - len(t) // 2, t,
                 curses.A_BOLD | curses.color_pair(1))
        r += 2

        if nr:
            s = "** NEW HIGH SCORE! **"
            self.put(r, mid - len(s) // 2, s,
                     curses.A_BOLD | curses.A_BLINK | curses.color_pair(1))
            r += 2

        tramps = sum(isinstance(h, Trampoline) for h in hits)
        explos = sum(isinstance(h, Explosive) for h in hits)
        mines = sum(isinstance(h, FloatingMine) for h in hits)
        gates = sum(isinstance(h, SpeedGate) for h in hits)
        ports = sum(isinstance(h, Portal) for h in hits)

        lines = [
            f"Distance:     {d:.1f} m",
            f"Max Height:   {ball.max_height:.1f} m",
            f"Bounces:      {ball.bounces}",
            f"Objects Hit:  {len(hits)}",
        ]
        if tramps:
            lines.append(f"  Trampolines:  {tramps}")
        if explos:
            lines.append(f"  Explosives:   {explos}")
        if mines:
            lines.append(f"  Mines:        {mines}")
        if gates:
            lines.append(f"  Speed Gates:  {gates}")
        if ports:
            lines.append(f"  Portals:      {ports}")
        lines += ["", f"High Score:   {self.best:.1f} m"]

        for ln in lines:
            self.put(r, mid - 15, ln, curses.A_BOLD)
            r += 1

        r += 2
        p = "SPACE: play again    Q: quit"
        self.put(r, mid - len(p) // 2, p, curses.color_pair(5))
        self.scr.refresh()

        while True:
            k = self.scr.getch()
            if k == ord(' '):
                return True
            if k in (ord('q'), ord('Q')):
                return False

    # -------------------- Main Loop --------------------

    def run(self):
        if self.h < 15 or self.w < 60:
            self.put(0, 0, "Terminal too small! Need 60x15 minimum.",
                     curses.A_BOLD)
            self.scr.refresh()
            self.scr.getch()
            return

        while True:
            objs = spawn_objects()
            a, p, w = self.aim(objs)
            if a is None:
                break
            ball, hits = self.fly(a, p, w, objs)
            if not self.results(ball, hits):
                break


# ============================================================
#                        ENTRY POINT
# ============================================================

def main(stdscr):
    Game(stdscr).run()


if __name__ == '__main__':
    curses.wrapper(main)
