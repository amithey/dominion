"""The University, modelled in Blender.   blender -b -P build_university.py -- <out.glb> [style]

A campus round a quadrangle: a brick main hall with a stone portico and a copper-domed rotunda, two gabled wings enclosing a lawn
with crossing paths and a statue, a bell tower, an arcade, a lecture hall with a glass front, bicycle racks, benches, trees, lamps
and a banner. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "university.glb"
m = Model("university")
rng = random.Random(33)
apply_style(m)
ground(m, lawns=False)

# ------------------------------------------------------------------ the main hall: x +-5.6, z -8.2 .. -3.6
X, Z0, Z1 = 5.6, -8.2, -3.6
m.box(STONE, (-X - 0.15, 0.1, Z0 - 0.15), (X + 0.15, 1.1, Z1 + 0.15), bevel=0.04, seg=1)
m.box(BRICK, (-X, 1.1, Z0), (X, 7.6, Z1), bevel=0.03, seg=1)
for k in range(2):
    for i in range(8):
        x = -4.9 + i * 1.4
        if abs(x) < 1.8:
            continue
        window(m, x, 2.0 + k * 3.0, Z1, 0.9, 1.7, 1)
m.box(STONE, (-X - 0.3, 7.6, Z0 - 0.3), (X + 0.3, 8.0, Z1 + 0.3), bevel=0.04, seg=1)
hip_roof(m, -X, X, Z0, Z1, 8.0, 2.0, overhang=0.2)
for dx in (-3.6, 3.6):
    m.box(BRICK, (dx - 0.35, 8.0, Z0 + 1.0), (dx + 0.35, 10.6, Z0 + 1.7), bevel=0.03, seg=1)
# the portico: four columns under a pediment, a stair
PZ = Z1 + 1.8
m.box(STONE, (-2.8, 1.1, Z1), (2.8, 1.3, PZ + 0.4), bevel=0.04, seg=1)
for i in range(4):
    column(m, -2.1 + i * 1.4, PZ, 1.3, 7.2, 0.26)
m.box(STONE, (-2.9, 7.2, Z1), (2.9, 7.6, PZ + 0.3), bevel=0.04, seg=1)
pediment(m, -3.0, 3.0, 7.6, PZ + 0.3, 1.3, 0.45)
steps(m, -2.5, 2.5, PZ + 0.4, 6, 0.18, 0.34)
m.box("wood", (-0.9, 1.3, Z1 - 0.02), (0.9, 4.0, Z1 + 0.1), bevel=0.03, seg=1, tint=(0.5, 0.36, 0.28))
m.box("glass", (-0.8, 4.0, Z1 + 0.0), (0.8, 4.5, Z1 + 0.05))
# the rotunda over the middle of the hall
m.cyl(STONE, (0.0, 8.0, -5.9), 2.1, 1.0, 24)
m.cyl(PLASTER, (0.0, 9.0, -5.9), 1.9, 1.4, 24)
for k in range(8):
    a = math.tau * k / 8
    m.box("glass", (math.cos(a) * 1.9 - 0.3, 9.4, -5.9 + math.sin(a) * 1.9 - 0.3), (math.cos(a) * 1.9 + 0.3, 10.2, -5.9 + math.sin(a) * 1.9 + 0.3), yaw=-a, about=(math.cos(a) * 1.9, 0, -5.9 + math.sin(a) * 1.9))
m.tube(STONE, (0.0, 10.4, -5.9), 2.15, 1.7, 0.25, 24)
m.lathe("copper", (0.0, 10.65, -5.9), [(0.0, 0.0), (1.95, 0.0), (1.9, 0.5), (1.5, 1.4), (0.8, 2.0), (0.3, 2.4), (0.0, 2.5)], 24)
m.pipe("gold", (0.0, 13.1, -5.9), (0.0, 14.0, -5.9), 0.05, 6, r2=0.015)

# ------------------------------------------------------------------ the two wings, gabled, brick, forming the quad
for sx in (-1, 1):
    x0, x1 = (-9.4, -6.2) if sx < 0 else (6.2, 9.4)
    m.box(BRICK, (x0, 0.1, -3.6), (x1, 6.2, 3.4), bevel=0.03, seg=1, tint=(1.0, 0.97, 0.93))
    m.box(STONE, (x0 - 0.1, 0.1, -3.7), (x1 + 0.1, 0.8, 3.5), bevel=0.03, seg=1)
    for k in range(2):
        for z in (-2.4, -0.8, 0.8, 2.4):
            with m.frame((x1 if sx < 0 else x0, 0, z), yaw=-sx * math.pi / 2):
                window(m, 0.0, 1.6 + k * 2.4, 0.0, 0.9, 1.5, 1)
    gable_roof(m, x0, x1, -3.6, 3.4, 6.2, 1.5, overhang=0.25)
    m.box(BRICK, (x0 + 1.0, 6.2, -2.4) if sx < 0 else (x0 + 1.0, 6.2, 0.8), (x0 + 1.5, 8.4, -1.9) if sx < 0 else (x0 + 1.5, 8.4, 1.3), bevel=0.02, seg=1)
# an arcade joining each wing to the portico
for sx in (-1, 1):
    for k in range(3):
        px = sx * (3.0 + k * 1.1)
        m.pipe(STONE, (px, 0.1, -2.9), (px, 3.2, -2.9), 0.15, 8)
    m.box(STONE, (min(sx * 3.0, sx * 5.4) - 0.2, 3.2, -3.1), (max(sx * 3.0, sx * 5.4) + 0.2, 3.5, -2.7), bevel=0.02, seg=1)

# ------------------------------------------------------------------ the quad: a lawn, crossing paths, a statue, the bell tower
m.box(CONC, (-5.8, 0.13, -2.6), (5.8, 0.18, 3.0), bevel=0.01, seg=1)
m.box("turf", (-5.6, 0.18, -2.4), (5.6, 0.22, 2.8), tint=hexc("5a8a46"))
m.box("pavers", (-0.6, 0.22, -2.4), (0.6, 0.24, 2.8), tint=(1.1, 1.1, 1.1))
m.box("pavers", (-5.6, 0.22, 0.0), (5.6, 0.24, 1.0), tint=(1.1, 1.1, 1.1))
m.cyl(STONE, (0.0, 0.24, 0.5), 1.5, 0.2, 20)
m.box(STONE, (-0.45, 0.4, 0.05), (0.45, 1.8, 0.95), bevel=0.04, seg=1)                                          # the founder's statue
m.cyl("gold", (0.0, 1.8, 0.5), 0.3, 0.9, 8, r2=0.2)
m.dome("gold", (0.0, 2.6, 0.5), 0.22, 0.3, 8, 3)
# the bell tower beside the east wing
m.box(BRICK, (6.0, 0.1, 4.0), (8.0, 9.0, 6.0), bevel=0.03, seg=1)
for k in range(4):
    m.box("dark", (6.5, 2.0 + k * 1.8, 6.0), (7.5, 2.9 + k * 1.8, 6.04))
m.box(STONE, (5.9, 9.0, 3.9), (8.1, 9.3, 6.1), bevel=0.03, seg=1)
for sx in (6.2, 7.8):
    for sz in (4.2, 5.8):
        m.pipe(STONE, (sx, 9.3, sz), (sx, 11.0, sz), 0.1, 8)
m.hull(SLATE, [(5.9, 11.0, 3.9), (8.1, 11.0, 3.9), (5.9, 11.0, 6.1), (8.1, 11.0, 6.1), (7.0, 13.0, 5.0)])
m.cyl("gold", (7.0, 9.3, 5.0), 0.25, 0.5, 10, r2=0.05)
# a lecture hall with a glass front on the west
m.box("cladding", (-9.2, 0.1, 4.0), (-5.0, 3.8, 6.6), bevel=0.04, seg=1, tint=(0.95, 0.95, 1.0))
m.box("glass", (-8.9, 0.4, 6.58), (-5.3, 3.3, 6.64))
m.box("cladding", (-9.4, 3.8, 3.8), (-4.8, 4.1, 6.8), bevel=0.03, seg=1)
# bicycle racks, benches, trees, lamps, a banner
for k in range(5):
    m.pipe(DARK, (-2.8 + k * 0.5, 0.13, 8.0), (-2.8 + k * 0.5, 0.8, 8.0), 0.03, 5)
    m.tube(DARK, (-2.8 + k * 0.5, 0.45, 8.0), 0.32, 0.29, 0.02, 12)
m.box("wood", (-3.0, 0.8, 7.9), (-0.5, 0.84, 8.1))
for sx in (-1, 1):
    bench(m, sx * 3.0, 3.4, 0.0)
for p in ((-4.4, 9.0), (4.4, 9.0), (-10.0, 0.5), (10.0, 0.5), (3.0, 6.4), (-3.0, 6.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
flagpole(m, 0.0, 6.6, 6.5)
if STYLE != "euro":
    crown(m, 0.0, 8.0, -5.9, 11.2, 4.6, corners_only=True)
    forecourt(m, 9.8)
m.finish(out)
