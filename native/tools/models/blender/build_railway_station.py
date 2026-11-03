"""The Railway Station, modelled in Blender.   blender -b -P build_railway_station.py -- <out.glb>

A terminus: a stone station hall with a clock tower and a big arched window, a glazed canopy over two platforms and three
tracks (sleepers, ballast, twin rails, buffers), a diesel locomotive with a rake of carriages at one platform and goods wagons
on a siding beside a freight shed with a loading crane, overhead-line masts and a signal gantry, a footbridge, a forecourt with
a taxi rank and bus, lamps, benches and a flag. Tracks run along x, the hall faces +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fence_poly, crate, container
from bl_civic import *

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "railway_station.glb"
m = Model("railway_station")
rng = random.Random(171)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
ground(m, lawns=False, pave=hexc("c4c2b8"))
WH = (1.5, 1.5, 1.45)
RAIL_Y = 0.4


def track(z, x0, x1, buffers=True):
    """A track along x at z: a ballast bed, sleepers every 0.5, two rails with a head, and buffer stops at the +x end."""
    m.box("gravel", (x0, 0.1, z - 0.9), (x1, 0.3, z + 0.9), bevel=0.04, seg=1, tint=(0.9, 0.88, 0.85))
    n = int((x1 - x0) / 0.5)
    for k in range(n):
        m.box("wood", (x0 + 0.1 + k * 0.5, 0.3, z - 0.75), (x0 + 0.3 + k * 0.5, 0.38, z + 0.75), tint=(0.6, 0.5, 0.4))
    for sz in (-0.5, 0.5):
        m.box(METAL, (x0, 0.38, z + sz - 0.05), (x1, RAIL_Y + 0.12, z + sz + 0.05), tint=(1.2, 1.2, 1.25))
        m.box(METAL, (x0, RAIL_Y + 0.12, z + sz - 0.09), (x1, RAIL_Y + 0.18, z + sz + 0.09), tint=(1.4, 1.4, 1.45))
    if buffers:
        for sz in (-0.5, 0.5):
            m.box(DARK, (x1 - 0.5, 0.4, z + sz - 0.15), (x1 - 0.2, 0.9, z + sz + 0.15), bevel=0.03, seg=1)
            m.pipe(METAL, (x1 - 0.2, 0.65, z + sz), (x1, 0.65, z + sz), 0.08, 8)


def carriage(x, z, tint, length=4.2, winc=6):
    """A passenger carriage along x: a bogie chassis, a rounded body with a window row and a roof with vents."""
    with m.frame((x, 0, z)):
        m.box("dark", (-length / 2, 0.45, -0.7), (length / 2, 0.8, 0.7), bevel=0.03, seg=1)
        m.box("paint", (-length / 2, 0.8, -0.85), (length / 2, 2.6, 0.85), bevel=0.12, seg=2, tint=tint)
        m.box("paint", (-length / 2 + 0.02, 1.35, -0.86), (length / 2 - 0.02, 1.5, 0.86), tint=hexc("e8e4d8"))
        for k in range(winc):
            wx = -length / 2 + 0.5 + k * (length - 1.0) / (winc - 1)
            for sz in (-1, 1):
                m.box(GLASS, (wx - 0.28, 1.65, sz * 0.86 - 0.01), (wx + 0.28, 2.25, sz * 0.86 + 0.01), tint=(1.6, 1.8, 2.0))
        m.hull("paint", [(-length / 2, 2.6, -0.8), (length / 2, 2.6, -0.8), (-length / 2, 2.6, 0.8), (length / 2, 2.6, 0.8), (-length / 2 + 0.1, 2.9, -0.4), (length / 2 - 0.1, 2.9, -0.4),
                         (-length / 2 + 0.1, 2.9, 0.4), (length / 2 - 0.1, 2.9, 0.4)], tint=hexc("8a949a"))
        for sx in (-1, 1):                                                                                      # bogies
            for ax in (-0.5, 0.5):
                for sz in (-0.5, 0.5):
                    m.pipe("dark", (sx * (length / 2 - 0.9) + ax, 0.4, sz - 0.04), (sx * (length / 2 - 0.9) + ax, 0.4, sz + 0.04), 0.36, 12)
        m.box("dark", (-length / 2 - 0.15, 0.5, -0.3), (-length / 2, 0.65, 0.3))
        m.box("dark", (length / 2, 0.5, -0.3), (length / 2 + 0.15, 0.65, 0.3))


def loco(x, z, tint=hexc("2f5a78")):
    """A diesel locomotive along x with the cab at the -x end: nose, long hood, cab windows, roof fans, headlamps and bogies."""
    with m.frame((x, 0, z)):
        L = 5.4
        m.box("dark", (-L / 2, 0.45, -0.75), (L / 2, 0.85, 0.75), bevel=0.04, seg=1)
        m.box("paint", (-L / 2 + 1.4, 0.85, -0.9), (L / 2, 2.2, 0.9), bevel=0.1, seg=2, tint=tint)               # the hood
        m.box("paint", (-L / 2, 0.85, -0.9), (-L / 2 + 1.6, 3.0, 0.9), bevel=0.1, seg=2, tint=tint)               # the cab
        for sz in (-1, 1):
            m.box(GLASS, (-L / 2 + 0.2, 2.0, sz * 0.9 - 0.01), (-L / 2 + 1.4, 2.8, sz * 0.9 + 0.01), tint=(1.6, 1.8, 2.0))
        m.box(GLASS, (-L / 2 - 0.01, 2.0, -0.7), (-L / 2 + 0.03, 2.8, 0.7), tint=(1.6, 1.8, 2.0))
        m.box("paint", (-L / 2 + 0.0, 1.0, -0.91), (L / 2, 1.2, 0.91), tint=hexc("e0b020"))                       # a livery stripe
        for k in range(3):
            m.cyl("dark", (-L / 2 + 2.4 + k * 0.9, 2.2, 0.0), 0.34, 0.1, 12)
        for sx in (-1, 1):
            for ax in (-0.5, 0.5):
                for sz in (-0.5, 0.5):
                    m.pipe("dark", (sx * (L / 2 - 1.0) + ax, 0.4, sz - 0.04), (sx * (L / 2 - 1.0) + ax, 0.4, sz + 0.04), 0.38, 12)
        m.box("glow_warm", (-L / 2 - 0.05, 0.95, -0.7), (-L / 2, 1.15, -0.45))
        m.box("glow_warm", (-L / 2 - 0.05, 0.95, 0.45), (-L / 2, 1.15, 0.7))
        m.box("glow_red", (L / 2, 0.95, -0.7), (L / 2 + 0.05, 1.15, -0.45))
        m.box("dark", (-L / 2 - 0.2, 0.55, -0.35), (-L / 2, 0.7, 0.35))
        m.pipe(METAL, (-L / 2 + 0.8, 3.0, 0.0), (-L / 2 + 0.8, 3.5, 0.0), 0.03, 5)                             # a horn


def wagon(x, z, tint, kind="box"):
    with m.frame((x, 0, z)):
        m.box("dark", (-1.7, 0.45, -0.6), (1.7, 0.7, 0.6), bevel=0.03, seg=1)
        if kind == "box":
            m.box("paint", (-1.7, 0.7, -0.85), (1.7, 2.3, 0.85), bevel=0.05, seg=1, tint=tint)
            m.box("dark", (-0.5, 0.9, 0.85), (0.5, 2.1, 0.88))
            m.hull("paint", [(-1.75, 2.3, -0.9), (1.75, 2.3, -0.9), (-1.75, 2.3, 0.9), (1.75, 2.3, 0.9), (-1.6, 2.55, -0.4), (1.6, 2.55, -0.4), (-1.6, 2.55, 0.4), (1.6, 2.55, 0.4)], tint=(0.6, 0.6, 0.6))
        else:
            m.box("paint", (-1.7, 0.7, -0.85), (1.7, 1.5, 0.85), bevel=0.04, seg=1, tint=tint)
            for k in range(3):
                m.dome("dark", (-1.0 + k * 1.0, 1.5, 0.0), 0.5, 0.4, 10, 3)
        for sx in (-1, 1):
            for sz in (-0.5, 0.5):
                m.pipe("dark", (sx * 1.0, 0.4, sz - 0.04), (sx * 1.0, 0.4, sz + 0.04), 0.36, 12)


# ------------------------------------------------------------------ the tracks and platforms
TRACKS = (-2.4, 0.6, 3.6)
X0, X1 = -10.0, 10.0
for tz in TRACKS:
    track(tz, X0, X1)
m.box(CONC, (-10.0, 0.1, -1.6), (9.6, 0.75, -0.9), bevel=0.02, seg=1)
m.box("pavers", (-10.0, 0.75, -1.6), (9.6, 0.78, -0.9))
m.box("hazard", (-10.0, 0.78, -1.0), (9.6, 0.79, -0.92), tint=(0.9, 0.8, 0.3))
m.box(CONC, (-10.0, 0.1, 1.5), (9.6, 0.75, 2.7), bevel=0.02, seg=1)
m.box("pavers", (-10.0, 0.75, 1.5), (9.6, 0.78, 2.7))
m.box("hazard", (-10.0, 0.78, 1.5), (9.6, 0.79, 1.58), tint=(0.9, 0.8, 0.3))

# ------------------------------------------------------------------ the station hall at the back (z -9 .. -3.6): stone, clock tower, big arch
HX0, HX1, HZ0, HZ1 = -6.2, 4.6, -8.0, -3.8
m.box(STONE, (HX0 - 0.15, 0.1, HZ0 - 0.15), (HX1 + 0.15, 1.0, HZ1 + 0.15), bevel=0.03, seg=1)
m.box(STONE, (HX0, 1.0, HZ0), (HX1, 6.6, HZ1), bevel=0.03, seg=1)
for k in range(10):
    m.box("dark", (HX0, 1.3 + k * 0.55, HZ1 - 0.01), (HX1, 1.32 + k * 0.55, HZ1 + 0.02), tint=(0.5, 0.5, 0.5))
m.box(STONE, (HX0 - 0.3, 6.6, HZ0 - 0.3), (HX1 + 0.3, 7.0, HZ1 + 0.3), bevel=0.04, seg=2)
hip_roof(m, HX0, HX1, HZ0, HZ1, 7.0, 2.2, overhang=0.2, role="roof_slate")
# the great arched window over the concourse door
pts = [(math.cos(math.pi * k / 12) * 2.0, 3.6 + math.sin(math.pi * k / 12) * 2.0) for k in range(13)]
CXH = -1.2
m.box("dark", (CXH - 2.0, 1.0, HZ1 - 0.03), (CXH + 2.0, 3.6, HZ1))
m.hull("dark", [(CXH + a, b, HZ1 - 0.03) for a, b in pts] + [(CXH + a, b, HZ1) for a, b in pts])
m.box(GLASS, (CXH - 2.0, 1.0, HZ1), (CXH + 2.0, 3.6, HZ1 + 0.03), tint=(1.6, 1.8, 2.0))
m.hull(GLASS, [(CXH + a, b, HZ1) for a, b in pts] + [(CXH + a, b, HZ1 + 0.03) for a, b in pts], tint=(1.6, 1.8, 2.0))
for k in range(1, 5):
    m.box(METAL, (CXH - 2.0 + k * 0.8 - 0.03, 1.0, HZ1), (CXH - 2.0 + k * 0.8 + 0.03, 3.6 + math.sqrt(max(0.0, 4.0 - (k * 0.8 - 2.0) ** 2)), HZ1 + 0.07))
for a0 in range(12):
    ro, ri = 2.25, 2.0
    pp = [(math.cos(math.pi * a0 / 12) * r, 3.6 + math.sin(math.pi * a0 / 12) * r) for r in (ri, ro)] + [(math.cos(math.pi * (a0 + 1) / 12) * r, 3.6 + math.sin(math.pi * (a0 + 1) / 12) * r) for r in (ri, ro)]
    m.hull(STONE, [(CXH + px, py, HZ1) for px, py in pp] + [(CXH + px, py, HZ1 + 0.18) for px, py in pp], tint=(1.1, 1.1, 1.1))
for sx in (-1, 1):
    m.box(STONE, (CXH + sx * 2.1 - 0.15, 1.0, HZ1), (CXH + sx * 2.1 + 0.15, 3.6, HZ1 + 0.2), bevel=0.02, seg=1)
for k in range(2):                                                                                          # the doors under the window
    m.box("wood", (CXH - 1.0 + k * 1.0, 1.0, HZ1), (CXH + k * 1.0, 2.4, HZ1 + 0.1), bevel=0.02, seg=1, tint=(0.4, 0.28, 0.2))
for sx in (-1, 1):
    for wx in (-4.6, 2.4):
        w = wx
        m.box("dark", (w - 0.5, 2.2, HZ1 - 0.03), (w + 0.5, 4.4, HZ1))
        m.box(GLASS, (w - 0.5, 2.2, HZ1), (w + 0.5, 4.4, HZ1 + 0.03), tint=(1.6, 1.8, 2.0))
        m.box(STONE, (w - 0.65, 2.1, HZ1), (w + 0.65, 2.2, HZ1 + 0.25), bevel=0.01, seg=1)
    break
# the clock tower
TX, TZ = 3.0, -5.9
m.box(STONE, (TX - 1.3, 6.6, TZ - 1.3), (TX + 1.3, 11.4, TZ + 1.3), bevel=0.04, seg=1)
for f in range(4):
    with m.frame((TX, 0, TZ), yaw=f * math.pi / 2):
        m.box("paint", (-0.55, 8.85, 1.3), (0.55, 9.95, 1.34), tint=hexc("f4f0e4"))
        m.box("dark", (-0.03, 9.0, 1.34), (0.03, 9.7, 1.37))
        m.box("dark", (-0.03, 9.37, 1.34), (0.4, 9.43, 1.37))
        m.box("dark", (-0.4, 10.4, 1.3), (0.4, 11.0, 1.34))
m.box(STONE, (TX - 1.5, 11.4, TZ - 1.5), (TX + 1.5, 11.7, TZ + 1.5), bevel=0.04, seg=2)
m.hull("copper", [(TX - 1.5, 11.7, TZ - 1.5), (TX + 1.5, 11.7, TZ - 1.5), (TX - 1.5, 11.7, TZ + 1.5), (TX + 1.5, 11.7, TZ + 1.5), (TX, 13.9, TZ)])
m.pipe("gold", (TX, 13.9, TZ), (TX, 14.8, TZ), 0.04, 6, r2=0.012)

# ------------------------------------------------------------------ the canopy over the platforms: a glazed barrel roof on columns
CZ0, CZ1 = -2.0, 3.0
for k in range(8):
    cx = -9.0 + k * 2.6
    for cz in (-1.2, 2.1):
        m.pipe(METAL, (cx, 0.78, cz), (cx, 4.2, cz), 0.1, 8)
    arc = [(cx, 4.2 + math.sin(math.pi * j / 10) * 1.0, CZ0 + (CZ1 - CZ0) * j / 10) for j in range(11)]
    for a_, b_ in zip(arc, arc[1:]):
        m.pipe(METAL, a_, b_, 0.05, 5)
for j in range(10):
    z0 = CZ0 + (CZ1 - CZ0) * j / 10
    z1 = CZ0 + (CZ1 - CZ0) * (j + 1) / 10
    y0 = 4.2 + math.sin(math.pi * j / 10) * 1.0
    y1 = 4.2 + math.sin(math.pi * (j + 1) / 10) * 1.0
    m.hull(GLASS, [(-9.7, y0, z0), (8.4, y0, z0), (-9.7, y1, z1), (8.4, y1, z1), (-9.7, y0 + 0.03, z0), (8.4, y0 + 0.03, z0), (-9.7, y1 + 0.03, z1), (8.4, y1 + 0.03, z1)], tint=(1.3, 1.6, 1.8))
m.box(METAL, (-9.7, 4.2, CZ0 - 0.05), (8.4, 4.3, CZ0 + 0.05))
m.box(METAL, (-9.7, 4.2, CZ1 - 0.05), (8.4, 4.3, CZ1 + 0.05))
for k in range(4):
    m.box(DARK, (-8.0 + k * 4.4, 3.4, 0.4), (-6.0 + k * 4.4, 3.7, 0.5), bevel=0.01, seg=1)                  # platform signs
    m.box("glow_cyan", (-7.9 + k * 4.4, 3.45, 0.5), (-6.1 + k * 4.4, 3.65, 0.52), tint=(0.7, 0.9, 1.0))
for k in range(5):
    bench(m, -7.0 + k * 3.8, 2.1, 0.0)

# ------------------------------------------------------------------ trains: a loco and carriages on the middle track, wagons on a siding
loco(-6.9, TRACKS[1], hexc("2f5a78"))
for k in range(3):
    carriage(-2.4 + k * 4.5, TRACKS[1], [hexc("a8322a"), hexc("2f5a78"), hexc("a8322a")][k])
for k in range(3):
    wagon(-8.0 + k * 3.7, TRACKS[2], [hexc("8a3a2e"), hexc("5a6a3a"), hexc("8a6a2a")][k], "box" if k != 1 else "hopper")
carriage(5.4, TRACKS[0], hexc("e8e4d8"), 3.2, 4)
# overhead masts with a catenary wire, a signal gantry and a footbridge
for k in range(7):
    mx = -9.5 + k * 3.3
    m.pipe(METAL, (mx, 0.1, 4.6), (mx, 5.2, 4.6), 0.07, 8)
    m.pipe(METAL, (mx, 5.2, 4.6), (mx, 5.2, -3.4), 0.04, 6)
    for tz in TRACKS:
        m.pipe(METAL, (mx, 5.0, tz), (mx, 4.6, tz), 0.015, 4)
for tz in TRACKS:
    m.wire(METAL, [(-10.0, 4.6, tz), (10.0, 4.6, tz)], 0.012, 4)
sgx = 7.0
m.pipe(METAL, (sgx, 0.1, 4.6), (sgx, 4.4, 4.6), 0.06, 6)
m.pipe(METAL, (sgx, 4.4, 4.6), (sgx, 4.4, -3.2), 0.05, 6)
for k, tz in enumerate(TRACKS):
    m.box(DARK, (sgx - 0.15, 3.3, tz - 0.12), (sgx + 0.15, 4.4, tz + 0.12), bevel=0.02, seg=1)
    m.cyl("glow_green" if k != 1 else "glow_red", (sgx - 0.16, 4.1, tz), 0.07, 0.04, 8)
    m.cyl("glow_red" if k == 1 else "glow_warm", (sgx - 0.16, 3.7, tz), 0.07, 0.04, 8)

# ------------------------------------------------------------------ the goods yard: a freight shed, a loading crane, crates and containers
m.box(CLAD, (3.6, 0.1, 5.2), (8.0, 3.2, 7.6), bevel=0.04, seg=1, tint=hexc("c8cdd0"))
m.hull(CLAD, [(3.4, 3.2, 5.0), (8.2, 3.2, 5.0), (3.4, 3.2, 7.8), (8.2, 3.2, 7.8), (3.4, 4.2, 6.4), (8.2, 4.2, 6.4)], tint=(0.72, 0.75, 0.78))
for k in range(2):
    m.box("dark", (4.0 + k * 2.0, 0.1, 5.18), (5.8 + k * 2.0, 2.6, 5.22))
    for q in range(8):
        m.box(METAL, (4.05 + k * 2.0, 0.2 + q * 0.3, 5.16), (5.75 + k * 2.0, 0.28 + q * 0.3, 5.18))
for k in range(3):
    crate(m, -8.4 + k * 1.4, 0.14, 5.4, 1.0, 0.8, 1.0, hexc("7a6a42") if k % 2 else hexc("6f7a58"))
container(m, -4.0, 6.2, 0.0, hexc("2f5a78"), 2.6, 1.25, 1.25, y0=0.14)
container(m, -4.0, 7.6, 0.0, hexc("8a3a2e"), 2.6, 1.25, 1.25, y0=0.14)
container(m, -4.0, 6.9, 0.0, hexc("a8782a"), 2.6, 1.25, 1.25, y0=1.39)

# ------------------------------------------------------------------ the forecourt: a taxi rank, a bus, lamps, trees, a flag
for k in range(3):
    with m.frame((-1.0 + k * 2.2, 0, 7.6), yaw=math.pi / 2):
        m.box("paint", (-0.85, 0.3, -1.9), (0.85, 0.9, 1.9), bevel=0.15, seg=3, tint=hexc("e8b020"))
        m.box(GLASS, (-0.74, 0.9, -1.0), (0.74, 1.4, 0.9), bevel=0.1, seg=2)
        m.box("glow_warm", (-0.2, 1.4, -0.3), (0.2, 1.55, 0.3))
        for sx in (-1, 1):
            for sz in (-1.2, 1.2):
                m.pipe("dark", (sx * 0.78, 0.33, sz), (sx * 0.96, 0.33, sz), 0.33, 12)
for p in ((-7.8, 7.4), (8.8, 2.6), (-9.6, 4.6), (0.0, 9.6)):
    tree(m, p[0], p[1], 2.3, 1.0)
for sx in (-1, 1):
    lamp(m, sx * 3.0, 9.0)
flagpole(m, -3.4, -3.0, 8.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
