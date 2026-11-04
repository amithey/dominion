"""The National Museum, modelled in Blender.   blender -b -P build_museum.py -- <out.glb> [style]

A temple of culture: a pale stone building on a high podium with a grand stair, a portico of eight fluted columns under a
sculpted pediment, hanging exhibition banners between the columns, two low flanking galleries, a glass pyramid annexe behind, and
a sculpture garden with plinths, statues, an obelisk, a reflecting pool, benches, trees and lamps. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "museum.glb"
m = Model("museum")
rng = random.Random(44)
apply_style(m)
ground(m, lawns=False)

# ------------------------------------------------------------------ the main hall on its podium: x +-5.4, z -7.4 .. -2.6
X, Z0, Z1 = 5.4, -7.4, -2.6
m.box(STONE, (-X - 0.5, 0.1, Z0 - 0.4), (X + 0.5, 1.8, Z1 + 0.4), bevel=0.05, seg=1, tint=(0.95, 0.95, 0.95))   # the podium
m.box(STONE, (-X, 1.8, Z0), (X, 8.6, Z1), bevel=0.03, seg=1)
m.box(PLASTER, (-X + 0.1, 3.0, Z1 - 0.05), (X - 0.1, 7.2, Z1 + 0.01), tint=(0.95, 0.93, 0.88))                  # a recessed wall behind the columns
m.box(STONE, (-X - 0.3, 8.6, Z0 - 0.3), (X + 0.3, 9.1, Z1 + 0.3), bevel=0.04, seg=2)                              # the cornice
m.box("dark", (-1.0, 1.8, Z1 + 0.0), (1.0, 5.2, Z1 + 0.05))
m.box("glass", (-0.9, 1.9, Z1 + 0.05), (0.9, 5.1, Z1 + 0.1))
m.box("gold", (-0.04, 1.9, Z1 + 0.1), (0.04, 5.1, Z1 + 0.13))
for sx in (-1, 1):
    for bx in (3.4, 4.4):
        window(m, sx * bx, 3.4, Z1, 0.8, 2.6, 1, arch=True)
for z in (-6.4, -4.6, -3.2):
    for sx in (-1, 1):
        with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
            window(m, 0.0, 3.4, 0.0, 0.8, 2.6, 1)
# the portico: eight columns, the entablature, the pediment with a sculpted group
PZ = Z1 + 2.0
m.box(STONE, (-4.6, 1.8, Z1), (4.6, 2.0, PZ + 0.5), bevel=0.04, seg=1)
for i in range(8):
    column(m, -4.2 + i * 1.2, PZ, 2.0, 8.2, 0.3)
m.box(STONE, (-4.7, 8.2, Z1), (4.7, 8.7, PZ + 0.4), bevel=0.04, seg=1)
pediment(m, -4.8, 4.8, 8.7, PZ + 0.4, 1.9, 0.5)
m.box("gold", (-1.4, 9.3, PZ + 0.44), (1.4, 9.7, PZ + 0.48))
for fx in (-3.0, -1.8, 0.0, 1.8, 3.0):                                                                          # figures in the tympanum
    m.cyl(STONE, (fx, 9.15 if abs(fx) < 2 else 9.0, PZ + 0.1), 0.16, 0.5, 6, tint=(0.9, 0.9, 0.9))
    m.dome(STONE, (fx, 9.65 if abs(fx) < 2 else 9.5, PZ + 0.1), 0.15, 0.17, 8, 3)
for i in range(7):                                                                                              # banners between the columns
    cx = -3.6 + i * 1.2
    m.box("banner", (cx - 0.35, 3.0, PZ + 0.12), (cx + 0.35, 6.4, PZ + 0.16))
steps(m, -4.2, 4.2, PZ + 0.5, 9, 0.17, 0.36)
for sx in (-1, 1):
    m.box(STONE, (sx * 4.9 - 0.3, 0.1, PZ + 0.5), (sx * 4.9 + 0.3, 1.9, PZ + 3.5), bevel=0.04, seg=1)

# ------------------------------------------------------------------ the low flanking galleries
for sx in (-1, 1):
    x0, x1 = (-9.6, -5.6) if sx < 0 else (5.6, 9.6)
    m.box(STONE, (x0, 0.1, -6.2), (x1, 4.6, -2.8), bevel=0.03, seg=1, tint=(1.0, 0.98, 0.94))
    m.box(STONE, (x0 - 0.15, 4.6, -6.35), (x1 + 0.15, 4.9, -2.65), bevel=0.04, seg=1)
    for i in range(3):
        px = x0 + 0.8 + i * 1.2
        window(m, px, 1.4, -2.8, 0.8, 2.0, 1)
    m.hull("glass", [(x0 + 0.3, 4.9, -5.8), (x1 - 0.3, 4.9, -5.8), (x0 + 0.3, 4.9, -3.2), (x1 - 0.3, 4.9, -3.2), (x0 + 0.9, 5.6, -5.2), (x1 - 0.9, 5.6, -5.2), (x0 + 0.9, 5.6, -3.8), (x1 - 0.9, 5.6, -3.8)])   # a roof lantern

# ------------------------------------------------------------------ a glass pyramid annexe in the garden
m.box(STONE, (5.0, 0.1, 4.0), (8.4, 0.5, 7.2), bevel=0.03, seg=1)
APEX = (6.7, 4.6, 5.6)
BASE = [(5.2, 0.5, 4.2), (8.2, 0.5, 4.2), (5.2, 0.5, 7.0), (8.2, 0.5, 7.0)]
m.hull("glass", BASE + [APEX])
for (bx, bz) in ((5.2, 4.2), (8.2, 4.2), (5.2, 7.0), (8.2, 7.0)):
    m.pipe(METAL, (bx, 0.5, bz), APEX, 0.04, 6)
for (a, b) in ((BASE[0], BASE[1]), (BASE[1], BASE[3]), (BASE[3], BASE[2]), (BASE[2], BASE[0])):
    m.pipe(METAL, a, b, 0.04, 6)

# ------------------------------------------------------------------ the sculpture garden and a reflecting pool
m.box(STONE, (-3.0, 0.13, 3.0), (3.0, 0.45, 8.0), bevel=0.03, seg=1)
m.box("glass", (-2.8, 0.43, 3.2), (2.8, 0.47, 7.8), tint=(0.6, 1.1, 1.5))
for sx in (-1, 1):
    if sx > 0:
        continue
    m.box(STONE, (-6.8, 0.13, 3.0), (-5.6, 1.6, 4.2), bevel=0.04, seg=1)                                           # plinths with figures
    m.cyl(STONE, (-6.2, 1.6, 3.6), 0.28, 1.1, 8, r2=0.2, tint=(0.88, 0.88, 0.88))
    m.dome(STONE, (-6.2, 2.65, 3.6), 0.24, 0.3, 8, 3, tint=(0.88, 0.88, 0.88))
    m.box(STONE, (-7.8, 0.13, 6.0), (-6.6, 1.2, 7.2), bevel=0.04, seg=1)
    m.dome("gold", (-7.2, 1.2, 6.6), 0.55, 0.9, 10, 4)
m.hull(STONE, [(-0.3, 0.45, 8.6), (0.3, 0.45, 8.6), (-0.3, 0.45, 9.2), (0.3, 0.45, 9.2), (-0.1, 5.4, 8.8), (0.1, 5.4, 8.8), (-0.1, 5.4, 9.0), (0.1, 5.4, 9.0)])   # an obelisk
m.hull("gold", [(-0.1, 5.4, 8.8), (0.1, 5.4, 8.8), (-0.1, 5.4, 9.0), (0.1, 5.4, 9.0), (0.0, 5.8, 8.9)])
bench(m, -4.4, 5.6, math.pi / 2)
for p in ((-9.8, 3.4), (9.8, 2.0), (-8.4, 7.0), (4.4, 9.2), (-4.4, 9.2), (9.2, -1.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, 0.0, 9.1, -5.0, 10.4, 4.8, corners_only=True)
    forecourt(m, 10.6)
m.finish(out)
