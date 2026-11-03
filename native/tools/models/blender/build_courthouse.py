"""The Courthouse, modelled in Blender.   blender -b -P build_courthouse.py -- <out.glb>

A neoclassical courthouse: a rusticated stone podium with a grand stair guarded by two lions, a four-column portico with a
pediment holding the scales of justice, tall pilastered windows, a copper-roofed central tower with a lantern, side wings, a
steps-and-plinth forecourt with a statue of Justice, a prison van at a side door, lamps, benches, trees and a flag. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck
from bl_civic import *

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "courthouse.glb"
m = Model("courthouse")
rng = random.Random(141)
ground(m, lawns=True)
GR = (1.0, 1.0, 1.03)


def tall_window(x, y0, z, w=1.0, h=3.2):
    """A tall window with a pediment hood and pilasters on a wall facing +z."""
    m.box("dark", (x - w / 2, y0, z - 0.03), (x + w / 2, y0 + h, z))
    m.box(GLASS, (x - w / 2, y0, z), (x + w / 2, y0 + h, z + 0.03), tint=(1.6, 1.8, 2.0))
    m.box("wall_concrete", (x - 0.02, y0, z), (x + 0.02, y0 + h, z + 0.07), tint=(1.6, 1.6, 1.55))
    for fy in (0.35, 0.7):
        m.box("wall_concrete", (x - w / 2, y0 + h * fy, z), (x + w / 2, y0 + h * fy + 0.04, z + 0.07), tint=(1.6, 1.6, 1.55))
    for sx in (-1, 1):
        m.box(STONE, (x + sx * (w / 2 + 0.14) - 0.1, y0 - 0.1, z), (x + sx * (w / 2 + 0.14) + 0.1, y0 + h + 0.1, z + 0.18), bevel=0.02, seg=1)
    m.box(STONE, (x - w / 2 - 0.3, y0 + h + 0.1, z), (x + w / 2 + 0.3, y0 + h + 0.3, z + 0.3), bevel=0.02, seg=1)
    m.hull(STONE, [(x - w / 2 - 0.3, y0 + h + 0.3, z), (x + w / 2 + 0.3, y0 + h + 0.3, z), (x, y0 + h + 0.65, z), (x - w / 2 - 0.3, y0 + h + 0.3, z + 0.3), (x + w / 2 + 0.3, y0 + h + 0.3, z + 0.3), (x, y0 + h + 0.65, z + 0.3)])
    m.box(STONE, (x - w / 2 - 0.25, y0 - 0.14, z), (x + w / 2 + 0.25, y0, z + 0.26), bevel=0.02, seg=1)


def lion(x, z, yaw):
    """A crouching stone lion on a plinth: body, haunch, chest, head with a mane, a tail."""
    m.box(STONE, (x - 0.55, 0.13, z - 0.8), (x + 0.55, 0.9, z + 0.8), bevel=0.04, seg=1, yaw=yaw, about=(x, 0, z))
    with m.frame((x, 0.9, z), yaw=yaw):
        m.hull(STONE, [(-0.35, 0.0, -0.6), (0.35, 0.0, -0.6), (-0.3, 0.0, 0.4), (0.3, 0.0, 0.4), (-0.28, 0.6, -0.5), (0.28, 0.6, -0.5), (-0.25, 0.7, 0.3), (0.25, 0.7, 0.3)])
        m.hull(STONE, [(-0.22, 0.4, 0.2), (0.22, 0.4, 0.2), (-0.2, 0.4, 0.55), (0.2, 0.4, 0.55), (-0.2, 1.0, 0.25), (0.2, 1.0, 0.25), (-0.18, 1.0, 0.45), (0.18, 1.0, 0.45)])
        m.dome(STONE, (0.0, 0.95, 0.5), 0.3, 0.3, 10, 3)
        m.dome(STONE, (0.0, 0.85, 0.42), 0.38, 0.32, 10, 3, tint=(0.9, 0.9, 0.9))
        m.box(STONE, (-0.12, 0.8, 0.7), (0.12, 0.98, 0.9), bevel=0.04, seg=1)
        m.pipe(STONE, (0.0, 0.4, -0.55), (0.1, 0.2, -0.8), 0.05, 6)
        for sx in (-1, 1):
            m.box(STONE, (sx * 0.2 - 0.06, 0.0, 0.5), (sx * 0.2 + 0.06, 0.45, 0.75), bevel=0.02, seg=1)


# ------------------------------------------------------------------ the podium, stair, lions
X, Z0, Z1 = 5.2, -9.2, -2.4
m.box(STONE, (-6.8, 0.1, Z0 - 0.3), (6.8, 1.6, 0.4), bevel=0.05, seg=2, tint=GR)
for k in range(5):
    m.box("dark", (-6.8, 0.3 + k * 0.3, 0.38), (6.8, 0.32 + k * 0.3, 0.42), tint=(0.5, 0.5, 0.5))
steps(m, -3.2, 3.2, 0.4, 8, 0.19, 0.34, role=STONE)
for sx in (-1, 1):
    m.box(STONE, (sx * 3.7 - 0.35, 0.1, 0.4), (sx * 3.7 + 0.35, 1.9, 3.1), bevel=0.04, seg=1, tint=GR)
    m.dome(STONE, (sx * 3.7, 1.9, 2.8), 0.35, 0.25, 8, 2)
    lion(sx * 4.8, 3.2, 0.0)
m.box(STONE, (-X, 1.6, Z0), (X, 8.0, Z1), bevel=0.04, seg=1, tint=GR)
for k in range(9):
    m.box("dark", (-X, 2.0 + k * 0.62, Z1 - 0.01), (X, 2.02 + k * 0.62, Z1 + 0.02), tint=(0.5, 0.5, 0.5))
m.box(STONE, (-X - 0.3, 8.0, Z0 - 0.3), (X + 0.3, 8.6, Z1 + 0.15), bevel=0.04, seg=2, tint=GR)
m.box(STONE, (-X - 0.1, 8.6, Z0 - 0.1), (X + 0.1, 9.1, Z1 + 0.05), bevel=0.03, seg=1, tint=GR)
for k in range(13):
    m.cyl(STONE, (-X + 0.2 + k * (2 * X - 0.4) / 12, 8.6, Z1 + 0.1), 0.08, 0.5, 8)
hip_roof(m, -X, X, Z0, Z1, 9.1, 1.6, overhang=0.2)

# ------------------------------------------------------------------ the portico: four columns, a pediment with the scales
PZ = 0.0
m.box(STONE, (-3.6, 1.6, Z1), (3.6, 1.8, PZ + 0.6), bevel=0.03, seg=1, tint=GR)
for i in range(4):
    column(m, -2.7 + i * 1.8, PZ, 1.8, 7.9, 0.4, STONE)
m.box(STONE, (-3.6, 7.9, Z1), (3.6, 8.5, PZ + 0.5), bevel=0.04, seg=1, tint=GR)
m.box("gold", (-3.1, 8.05, PZ + 0.51), (3.1, 8.4, PZ + 0.53))
for k in range(8):
    m.box("dark", (-2.9 + k * 0.82, 8.12, PZ + 0.53), (-2.85 + k * 0.82, 8.34, PZ + 0.55))
pediment(m, -3.9, 3.9, 8.5, PZ + 0.5, 1.7, 0.5, role=STONE)
# the scales of justice in the tympanum
sy = 9.55
m.pipe("gold", (0.0, 8.7, PZ + 0.1), (0.0, sy + 0.4, PZ + 0.1), 0.05, 8)
m.pipe("gold", (-0.9, sy + 0.2, PZ + 0.1), (0.9, sy + 0.2, PZ + 0.1), 0.04, 8)
for sx in (-0.9, 0.9):
    m.wire("gold", [(sx, sy + 0.2, PZ + 0.1), (sx - 0.25, sy - 0.3, PZ + 0.1), (sx + 0.25, sy - 0.3, PZ + 0.1), (sx, sy + 0.2, PZ + 0.1)], 0.012, 4)
    m.cyl("gold", (sx, sy - 0.38, PZ + 0.1), 0.3, 0.06, 14, r2=0.2)
m.cyl("gold", (0.0, sy + 0.4, PZ + 0.1), 0.1, 0.12, 8)
# doors
m.box("dark", (-1.3, 1.8, Z1 - 0.02), (1.3, 5.6, Z1 + 0.02))
for sx in (-1, 1):
    m.box("wood", (sx * 0.62 - 0.6, 1.8, Z1), (sx * 0.62 + 0.6, 4.6, Z1 + 0.14), bevel=0.03, seg=2, tint=(0.38, 0.26, 0.18))
    for yy in (2.2, 3.4):
        m.box("gold", (sx * 0.62 - 0.42, yy, Z1 + 0.14), (sx * 0.62 + 0.42, yy + 0.9, Z1 + 0.17), bevel=0.02, seg=1, tint=(0.5, 0.4, 0.2))
m.hull(GLASS, [(-1.2, 4.7, Z1), (1.2, 4.7, Z1), (-1.2, 4.7, Z1 + 0.05), (1.2, 4.7, Z1 + 0.05), (-0.6, 5.5, Z1), (0.6, 5.5, Z1), (-0.6, 5.5, Z1 + 0.05), (0.6, 5.5, Z1 + 0.05)], tint=(1.6, 1.8, 2.0))
for sx in (-1, 1):
    m.box("glow_warm", (sx * 2.2 - 0.12, 3.6, Z1), (sx * 2.2 + 0.12, 4.0, Z1 + 0.25))
# windows on the faces
for x in (-4.3, 4.3):
    tall_window(x, 3.2, Z1, 1.0, 3.4)
for z in (-8.0, -6.0, -4.0):
    for sx in (-1, 1):
        with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
            tall_window(0.0, 3.2, 0.0, 1.0, 3.4)
for x in (-3.5, -1.2, 1.2, 3.5):
    with m.frame((x, 0, Z0), yaw=math.pi):
        tall_window(0.0, 3.2, 0.0, 1.0, 3.4)

# ------------------------------------------------------------------ the central tower with a lantern and a copper roof
TX, TZ = 0.0, -6.0
m.box(STONE, (TX - 1.8, 9.1, TZ - 1.8), (TX + 1.8, 11.4, TZ + 1.8), bevel=0.04, seg=1, tint=GR)
for f in range(4):
    with m.frame((TX, 0, TZ), yaw=f * math.pi / 2):
        pts = [(math.cos(math.pi * k / 8) * 0.5, 9.9 + math.sin(math.pi * k / 8) * 0.5) for k in range(9)]
        m.box("dark", (-0.5, 9.5, 1.78), (0.5, 9.9, 1.83))
        m.hull("dark", [(a, b, 1.78) for a, b in pts] + [(a, b, 1.83) for a, b in pts])
        m.box(GLASS, (-0.5, 9.5, 1.8), (0.5, 9.9, 1.84), tint=(1.6, 1.8, 2.0))
m.box(STONE, (TX - 2.0, 11.4, TZ - 2.0), (TX + 2.0, 11.7, TZ + 2.0), bevel=0.04, seg=2)
m.cyl(STONE, (TX, 11.7, TZ), 1.35, 1.2, 20, tint=GR)
for k in range(8):
    a = math.tau * k / 8
    m.cyl(STONE, (TX + math.cos(a) * 1.3, 11.7, TZ + math.sin(a) * 1.3), 0.1, 1.2, 8)
m.lathe("copper", (TX, 12.9, TZ), [(0.0, 0.0), (1.6, 0.0), (1.7, 0.2), (1.2, 0.8), (0.7, 1.6), (0.35, 2.3), (0.0, 2.6)], 20)
m.pipe("gold", (TX, 15.4, TZ), (TX, 16.4, TZ), 0.04, 6, r2=0.012)
m.cyl("gold", (TX, 15.7, TZ), 0.12, 0.12, 8)
for sx in (-1, 1):
    for sz in (-1, 1):
        m.cyl("copper", (TX + sx * 1.75, 11.7, TZ + sz * 1.75), 0.14, 0.7, 8, r2=0.02)

# ------------------------------------------------------------------ the forecourt: a statue of Justice, a prison van, benches, lamps
m.box(STONE, (-0.8, 0.13, 6.2), (0.8, 1.5, 7.8), bevel=0.04, seg=1, tint=GR)
m.box(STONE, (-0.6, 1.5, 6.4), (0.6, 1.8, 7.6), bevel=0.03, seg=1)
m.lathe("copper", (0.0, 1.8, 7.0), [(0.0, 0.0), (0.35, 0.0), (0.38, 0.5), (0.25, 1.1), (0.28, 1.5), (0.18, 1.7), (0.1, 1.9), (0.0, 2.0)], 12)
m.pipe("copper", (0.25, 3.0, 7.0), (0.7, 3.9, 7.0), 0.05, 6)
m.wire("copper", [(0.45, 3.9, 7.0), (0.7, 3.4, 7.0), (0.95, 3.9, 7.0), (0.45, 3.9, 7.0)], 0.012, 4)
truck(m, 7.2, 3.8, yaw=-math.pi / 2, canvas=False, bed=3.4, body=hexc("2f6f9e"))
with m.frame((7.2, 0, 3.8), yaw=-math.pi / 2):
    m.box("paint", (-1.08, 1.1, -1.2), (1.08, 2.45, 2.15), bevel=0.1, seg=2, tint=hexc("e8ecee"))
    m.box("paint", (-1.1, 1.5, -1.18), (1.1, 1.7, 2.1), tint=hexc("1f3f7a"))
    for sx in (-1, 1):
        m.box("dark", (sx * 1.1 - 0.02, 1.8, 0.0), (sx * 1.1 + 0.02, 2.2, 0.5))
    m.box("glow_red", (-0.6, 2.45, 1.5), (-0.05, 2.58, 1.9))
    m.box("glow_cyan", (0.05, 2.45, 1.5), (0.6, 2.58, 1.9), tint=(0.3, 0.5, 1.0))
for sx in (-1, 1):
    bench(m, sx * 3.8, 7.6, 0.0)
    lamp(m, sx * 2.4, 4.6)
    lamp(m, sx * 6.0, 8.0)
for p in ((-8.8, 6.0), (8.8, 7.5), (-9.4, -2.0), (-3.0, 9.2), (3.0, 9.2), (9.5, -6.0)):
    tree(m, p[0], p[1], 2.3, 1.05)
flagpole(m, -7.4, 0.8, 8.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
