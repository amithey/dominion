"""The Library (also the University and the Museum), modelled in Blender.   blender -b -P build_library.py -- <out.glb>

A neoclassical reading hall: a stone podium and broad stair, a six-column portico with a frieze and pediment, tall arched
windows along both sides with keystones, a central drum with a copper dome and lantern, flanking pavilions with hipped roofs,
statues on plinths, a reading garden with a pond and benches, book-return box, lamps, flag and trees on a hex plaza. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "library.glb"
m = Model("library")
rng = random.Random(51)
ground(m, lawns=True)
GR = (1.0, 1.0, 1.03)


def arch_win(x, y0, z, w=1.1, h=2.6):
    """A tall arched window on a wall facing +z."""
    pts = [(math.cos(math.pi * k / 8) * w / 2, y0 + h + math.sin(math.pi * k / 8) * w / 2) for k in range(9)]
    m.box("dark", (x - w / 2, y0, z - 0.03), (x + w / 2, y0 + h, z))
    m.hull("dark", [(x + px, py, z - 0.03) for px, py in pts] + [(x + px, py, z) for px, py in pts])
    m.box(GLASS, (x - w / 2, y0, z), (x + w / 2, y0 + h, z + 0.03), tint=(1.6, 1.8, 2.0))
    m.hull(GLASS, [(x + px, py, z) for px, py in pts] + [(x + px, py, z + 0.03) for px, py in pts], tint=(1.6, 1.8, 2.0))
    m.box("wall_concrete", (x - 0.02, y0, z), (x + 0.02, y0 + h + w / 2, z + 0.07), tint=(1.6, 1.6, 1.55))
    m.box("wall_concrete", (x - w / 2, y0 + h * 0.6, z), (x + w / 2, y0 + h * 0.6 + 0.04, z + 0.07), tint=(1.6, 1.6, 1.55))
    for sx in (-1, 1):
        m.box(STONE, (x + sx * (w / 2 + 0.12) - 0.1, y0 - 0.1, z), (x + sx * (w / 2 + 0.12) + 0.1, y0 + h, z + 0.16), bevel=0.02, seg=1)
    for a0 in range(8):
        a1 = a0 + 1
        ro, ri = w / 2 + 0.3, w / 2 + 0.05
        pp = [(x + math.cos(math.pi * a0 / 8) * r, y0 + h + math.sin(math.pi * a0 / 8) * r) for r in (ri, ro)] + [(x + math.cos(math.pi * a1 / 8) * r, y0 + h + math.sin(math.pi * a1 / 8) * r) for r in (ri, ro)]
        m.hull(STONE, [(px, py, z) for px, py in pp] + [(px, py, z + 0.14) for px, py in pp])
    m.box(STONE, (x - 0.14, y0 + h + w / 2 + 0.05, z), (x + 0.14, y0 + h + w / 2 + 0.45, z + 0.2), bevel=0.02, seg=1)
    m.box(STONE, (x - w / 2 - 0.25, y0 - 0.12, z), (x + w / 2 + 0.25, y0, z + 0.26), bevel=0.02, seg=1)


def statue(x, z, h=1.6):
    m.box(STONE, (x - 0.5, 0.13, z - 0.5), (x + 0.5, 0.9, z + 0.5), bevel=0.04, seg=1)
    m.box(STONE, (x - 0.4, 0.9, z - 0.4), (x + 0.4, 1.1, z + 0.4), bevel=0.03, seg=1)
    m.lathe("copper", (x, 1.1, z), [(0.0, 0.0), (0.28, 0.0), (0.3, 0.5), (0.18, 0.95), (0.2, 1.1), (0.15, 1.3), (0.0, 1.45)], 12)
    m.pipe("copper", (x + 0.25, 1.4, z), (x + 0.45, 2.0, z), 0.05, 6)


# ------------------------------------------------------------------ the main hall: x +-4.5, z -9.2 .. -2.5
X, Z0, Z1 = 4.6, -9.2, -2.6
m.box(STONE, (-6.4, 0.1, Z0 - 0.3), (6.4, 1.2, 0.6), bevel=0.05, seg=2, tint=GR)
steps(m, -3.4, 3.4, 0.6, 6, 0.18, 0.36, role=STONE)
m.box(STONE, (-X, 1.2, Z0), (X, 6.6, Z1), bevel=0.04, seg=1, tint=GR)
for k in range(9):
    m.box("dark", (-X, 1.5 + k * 0.58, Z1 - 0.01), (X, 1.52 + k * 0.58, Z1 + 0.02), tint=(0.5, 0.5, 0.5))
m.box(STONE, (-X - 0.25, 6.6, Z0 - 0.25), (X + 0.25, 7.1, Z1 + 0.15), bevel=0.04, seg=2, tint=GR)
m.box(STONE, (-X - 0.1, 7.1, Z0 - 0.1), (X + 0.1, 7.6, Z1 + 0.05), bevel=0.03, seg=1, tint=GR)
for k in range(15):
    x = -X + k * (2 * X) / 14
    m.cyl(STONE, (x, 7.1, Z1 + 0.12), 0.08, 0.5, 8)
# windows on the sides and back
for z in (-8.0, -6.2, -4.4):
    for sx in (-1, 1):
        with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
            arch_win(0.0, 2.2, 0.0, 1.0, 2.8)
for x in (-3.4, -1.1, 1.1, 3.4):
    with m.frame((x, 0, Z0), yaw=math.pi):
        arch_win(0.0, 2.2, 0.0, 1.0, 2.8)

# ------------------------------------------------------------------ the portico
PZ = 0.0
m.box(STONE, (-4.0, 1.2, Z1), (4.0, 1.4, PZ + 0.6), bevel=0.03, seg=1, tint=GR)
for i in range(6):
    column(m, -3.2 + i * 1.28, PZ, 1.4, 6.5, 0.32, STONE)
m.box(STONE, (-4.0, 6.5, Z1), (4.0, 7.1, PZ + 0.45), bevel=0.04, seg=1, tint=GR)
m.box("gold", (-3.5, 6.65, PZ + 0.46), (3.5, 6.95, PZ + 0.48))
for k in range(9):
    m.box("dark", (-3.3 + k * 0.82, 6.72, PZ + 0.48), (-3.25 + k * 0.82, 6.9, PZ + 0.5))
pediment(m, -4.3, 4.3, 7.1, PZ + 0.45, 1.6, 0.5, role=STONE)
m.cyl("gold", (0.0, 7.95, PZ + 0.0), 0.5, 0.05, 24)
# the doors, cut into the cella behind the portico
m.box("dark", (-1.3, 1.4, Z1 - 0.02), (1.3, 4.9, Z1 + 0.02))
for sx in (-1, 1):
    m.box("wood", (sx * 0.6 - 0.58, 1.4, Z1), (sx * 0.6 + 0.58, 3.9, Z1 + 0.14), bevel=0.03, seg=2, tint=(0.42, 0.28, 0.18))
    m.box("gold", (sx * 0.6 - 0.4, 1.9, Z1 + 0.14), (sx * 0.6 + 0.4, 3.4, Z1 + 0.17), bevel=0.02, seg=1, tint=(0.5, 0.4, 0.2))
m.hull(GLASS, [(-1.2, 4.0, Z1), (1.2, 4.0, Z1), (-1.2, 4.0, Z1 + 0.05), (1.2, 4.0, Z1 + 0.05), (-0.6, 4.8, Z1), (0.6, 4.8, Z1), (-0.6, 4.8, Z1 + 0.05), (0.6, 4.8, Z1 + 0.05)], tint=(1.6, 1.8, 2.0))
for k in range(2):
    arch_win(-3.0 + k * 6.0, 2.4, Z1, 1.1, 2.6)

# ------------------------------------------------------------------ the dome on a drum
DX, DZ = 0.0, -6.0
m.cyl(STONE, (DX, 7.6, DZ), 3.0, 1.0, 32, tint=GR)
m.cyl(STONE, (DX, 8.6, DZ), 3.3, 0.35, 32, tint=GR)
for k in range(8):
    a = math.tau * k / 8 + math.pi / 8
    with m.frame((DX, 0, DZ), yaw=-a + math.pi / 2):
        m.box("dark", (-0.3, 7.8, 2.98), (0.3, 8.5, 3.03))
        m.box(GLASS, (-0.3, 7.8, 3.0), (0.3, 8.5, 3.04), tint=(1.6, 1.8, 2.0))
m.lathe("copper", (DX, 8.95, DZ), [(0.0, 0.0), (3.1, 0.0), (3.2, 0.2), (2.9, 0.9), (2.3, 1.7), (1.5, 2.3), (0.9, 2.55), (0.7, 2.6), (0.0, 2.6)], 32)
for k in range(12):
    a = math.tau * k / 12
    m.pipe("gold", (DX + math.cos(a) * 3.1, 9.1, DZ + math.sin(a) * 3.1), (DX + math.cos(a) * 0.8, 11.5, DZ + math.sin(a) * 0.8), 0.025, 4)
m.cyl(STONE, (DX, 11.5, DZ), 0.8, 0.9, 16, tint=GR)
for k in range(8):
    a = math.tau * k / 8
    m.cyl(STONE, (DX + math.cos(a) * 0.7, 11.5, DZ + math.sin(a) * 0.7), 0.07, 0.9, 6)
m.lathe("copper", (DX, 12.4, DZ), [(0.0, 0.0), (0.95, 0.0), (0.8, 0.25), (0.4, 0.6), (0.2, 0.8), (0.0, 0.9)], 16)
m.pipe("gold", (DX, 13.3, DZ), (DX, 14.2, DZ), 0.04, 6, r2=0.012)
m.cyl("gold", (DX, 13.6, DZ), 0.12, 0.12, 8)

# ------------------------------------------------------------------ flanking pavilions with hipped roofs
for sx in (-1, 1):
    px0, px1 = (sx * 4.6, sx * 8.6) if sx > 0 else (sx * 8.6, sx * 4.6)
    m.box(STONE, (px0 - 0.1, 0.1, -8.6), (px1 + 0.1, 0.8, -3.0), bevel=0.03, seg=1, tint=GR)
    m.box(STONE, (px0, 0.8, -8.5), (px1, 4.4, -3.1), bevel=0.03, seg=1, tint=(0.95, 0.93, 0.9))
    m.box(STONE, (px0 - 0.2, 4.4, -8.7), (px1 + 0.2, 4.7, -2.9), bevel=0.03, seg=2, tint=GR)
    hip_roof(m, px0 - 0.1, px1 + 0.1, -8.5, -3.1, 4.7, 1.4, overhang=0.0)
    xc = (px0 + px1) / 2
    for dz in (-7.4, -5.8, -4.2):
        with m.frame((px1 if sx > 0 else px0, 0, dz), yaw=sx * math.pi / 2):
            arch_win(0.0, 1.4, 0.0, 0.9, 2.0)
    with m.frame((xc, 0, -3.1)):
        arch_win(0.0, 1.4, 0.0, 0.9, 2.0)
    m.box(BRICK, (xc - 0.4, 4.7, -8.0), (xc + 0.4, 7.0, -7.2), bevel=0.03, seg=1)
    m.box(STONE, (xc - 0.5, 7.0, -8.1), (xc + 0.5, 7.15, -7.1), bevel=0.02, seg=1)

# ------------------------------------------------------------------ the forecourt: statues, a pond, benches, a book-return box
for sx in (-1, 1):
    statue(sx * 4.8, 3.0)
m.cyl(STONE, (0, 0.13, 6.2), 1.9, 0.3, 28)
m.cyl("glass", (0, 0.4, 6.2), 1.6, 0.03, 28)
for k in range(5):
    a = math.tau * k / 5
    m.dome("leaf", (math.cos(a) * 0.8, 0.4, 6.2 + math.sin(a) * 0.8), 0.22, 0.04, 8, 2, tint=hexc("3f7a3c"))
for sx in (-1, 1):
    bench(m, sx * 6.2, 5.0, math.pi / 2)
    bench(m, sx * 3.6, 7.6, 0.0)
m.box("paint", (7.4, 0.13, 7.4), (8.2, 1.4, 8.1), bevel=0.04, seg=1, tint=hexc("2f6f9e"))                  # a book-return box
m.box("dark", (7.5, 1.0, 8.1), (8.1, 1.15, 8.14))
for p in ((-8.8, 6.0), (8.8, 5.0), (-9.4, -2.0), (-3.0, 9.0), (3.0, 9.0), (9.5, -6.0)):
    tree(m, p[0], p[1], 2.3, 1.05)
for sx in (-1, 1):
    lamp(m, sx * 3.0, 2.0)
    lamp(m, sx * 5.8, 8.0)
flagpole(m, -8.0, 0.8, 8.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
