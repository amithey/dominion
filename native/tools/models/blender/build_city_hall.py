"""The City Hall, modelled in Blender.   blender -b -P build_city_hall.py -- <out.glb>

A neoclassical civic building on its own hex plaza: a rusticated stone base, plastered upper storey with a window in every bay,
a giant-order portico of six fluted columns under a pediment, a grand stair, a hipped slate roof with dormers and chimneys, a
clock tower with a belfry and a copper dome, flags, a fountain, lawns, trees, benches and lamps. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "city_hall.glb"
m = Model("city_hall")
rng = random.Random(8)
ground(m)

# ------------------------------------------------------------------ the building: x +-6, z -8 .. -1
X, Z0, Z1 = 6.0, -8.0, -1.0
m.box(STONE, (-X - 0.3, 0.1, Z0 - 0.3), (X + 0.3, 1.5, Z1 + 0.3), bevel=0.05, seg=1, tint=(0.9, 0.9, 0.9))                 # the podium
m.box(STONE, (-X, 1.5, Z0), (X, 4.5, Z1), bevel=0.03, seg=1)                                                             # the rusticated ground storey
for k in range(10):
    m.box("dark", (-X, 1.6 + k * 0.3, Z1 - 0.01), (X, 1.62 + k * 0.3, Z1 + 0.02), tint=(0.5, 0.5, 0.5))                  # rustication joints
m.box(PLASTER, (-X, 4.5, Z0), (X, 7.5, Z1), bevel=0.03, seg=1)                                                           # the upper storey
m.box(STONE, (-X - 0.15, 4.4, Z0 - 0.15), (X + 0.15, 4.6, Z1 + 0.15), bevel=0.03, seg=1)                                  # string course
m.box(STONE, (-X - 0.45, 7.5, Z0 - 0.45), (X + 0.45, 8.0, Z1 + 0.45), bevel=0.05, seg=2)                                   # cornice
m.box(STONE, (-X - 0.3, 8.0, Z0 - 0.3), (X + 0.3, 8.5, Z1 + 0.3), bevel=0.03, seg=1)                                       # parapet band
for k in range(0, 13):                                                                                                       # balustrade
    x = -X - 0.2 + k * (2 * X + 0.4) / 12
    m.cyl(STONE, (x, 8.5, Z1 + 0.25), 0.07, 0.4, 8)
m.box(STONE, (-X - 0.3, 8.9, Z1 + 0.15), (X + 0.3, 9.0, Z1 + 0.35), bevel=0.02, seg=1)
hip_roof(m, -X + 0.3, X - 0.3, Z0 + 0.3, Z1 - 0.3, 8.5, 2.0, overhang=0.0)
for dx in (-4.2, 4.2):                                                                                                       # chimneys and dormers
    m.box(BRICK, (dx - 0.4, 8.5, Z0 + 1.2), (dx + 0.4, 11.2, Z0 + 2.0), bevel=0.03, seg=1)
    m.box(STONE, (dx - 0.5, 11.2, Z0 + 1.1), (dx + 0.5, 11.35, Z0 + 2.1), bevel=0.02, seg=1)

# windows: two storeys, bays of the front beyond the portico, and the side walls
for side in (-1, 1):
    for bx in (3.9, 5.1):
        for y in (2.0, 5.2):
            window(m, side * bx, y, Z1, 0.9, 1.7 if y < 4 else 1.9, 1)
for z in (-6.8, -5.0, -3.2):
    for y in (2.0, 5.2):
        for sx in (-1, 1):
            with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
                window(m, 0.0, y, 0.0, 0.9, 1.7 if y < 4 else 1.9, 1)
for bx in (-4.5, -1.5, 1.5, 4.5):
    for y in (2.0, 5.2):
        with m.frame((bx, 0, Z0), yaw=math.pi):
            window(m, 0.0, y, 0.0, 0.9, 1.7 if y < 4 else 1.9, 1)

# ------------------------------------------------------------------ the portico and the stair
PZ = Z1 + 2.2
m.box(STONE, (-3.3, 1.5, Z1), (3.3, 1.7, PZ + 0.5), bevel=0.04, seg=1)                                                  # the portico floor
for i in range(6):
    column(m, -2.5 + i, PZ, 1.7, 7.3, 0.3)
m.box(STONE, (-3.2, 7.3, Z1), (3.2, 7.75, PZ + 0.35), bevel=0.04, seg=1)
pediment(m, -3.4, 3.4, 7.75, PZ + 0.35, 1.5, 0.5)
m.box("gold", (-0.8, 8.3, PZ + 0.38), (0.8, 8.65, PZ + 0.42), tint=(1.0, 1.0, 1.0))
steps(m, -3.0, 3.0, PZ + 0.5, 8, 0.175, 0.32)
for sx in (-1, 1):
    m.box(STONE, (sx * 3.6 - 0.3, 0.1, PZ + 0.5), (sx * 3.6 + 0.3, 1.9, PZ + 3.2), bevel=0.04, seg=1)                  # the stair cheeks
    m.dome(STONE, (sx * 3.6, 1.9, PZ + 2.9), 0.3, 0.2, 8, 2)
m.box("wood", (-1.0, 1.7, Z1 - 0.02), (0.0, 4.1, Z1 + 0.12), bevel=0.03, seg=1, tint=(0.55, 0.4, 0.3))
m.box("wood", (0.0, 1.7, Z1 - 0.02), (1.0, 4.1, Z1 + 0.12), bevel=0.03, seg=1, tint=(0.55, 0.4, 0.3))
m.box("wood", (-1.0, 4.1, Z1 - 0.02), (1.0, 4.45, Z1 + 0.1), bevel=0.03, seg=1, tint=(0.5, 0.38, 0.3))
m.box("glass", (-0.9, 4.15, Z1 + 0.1), (0.9, 4.4, Z1 + 0.13))
for k in range(2):
    m.pipe("gold", (-0.15 + k * 0.3, 2.7, Z1 + 0.15), (-0.15 + k * 0.3, 3.2, Z1 + 0.15), 0.025, 5)
for sx in (-1, 1):
    m.box("glow_warm", (sx * 1.4 - 0.1, 3.3, Z1 + 0.0), (sx * 1.4 + 0.1, 3.6, Z1 + 0.2))

# ------------------------------------------------------------------ the clock tower over the portico
TY = 9.0
m.box(STONE, (-1.7, 8.4, Z0 + 2.0), (1.7, TY + 2.5, Z0 + 5.4), bevel=0.04, seg=1)
m.box(PLASTER, (-1.5, TY + 2.5, Z0 + 2.2), (1.5, TY + 4.2, Z0 + 5.2), bevel=0.03, seg=1)
for face in range(4):
    with m.frame((0, TY + 1.4, Z0 + 3.7), yaw=face * math.pi / 2, pitch=math.pi / 2):                                      # the clock faces
        m.cyl("paint", (0, 1.73, 0), 0.85, 0.05, 28, tint=hexc("f4f0e4"))
        m.tube("gold", (0, 1.73, 0), 0.9, 0.82, 0.07, 28)
        for k in range(12):
            a = math.tau * k / 12
for face in range(4):
    with m.frame((0, 0, Z0 + 3.7), yaw=face * math.pi / 2):
        m.box("dark", (-0.03, TY + 1.4, 1.78), (0.03, TY + 2.1, 1.82))                                                      # clock hands
        m.box("dark", (-0.03, TY + 1.37, 1.78), (0.5, TY + 1.43, 1.82))
        for k in range(12):
            a = math.tau * k / 12
            m.box("dark", (math.cos(a) * 0.72 - 0.03, TY + 1.4 + math.sin(a) * 0.72 - 0.03, 1.775), (math.cos(a) * 0.72 + 0.03, TY + 1.4 + math.sin(a) * 0.72 + 0.03, 1.8))
for face in range(4):                                                                                                        # belfry arches
    with m.frame((0, 0, Z0 + 3.7), yaw=face * math.pi / 2):
        m.box("dark", (-0.5, TY + 2.7, 1.45), (0.5, TY + 3.9, 1.52))
        m.hull("dark", [(-0.5, TY + 3.9, 1.45), (0.5, TY + 3.9, 1.45), (0.0, TY + 4.15, 1.45), (-0.5, TY + 3.9, 1.5), (0.5, TY + 3.9, 1.5), (0.0, TY + 4.15, 1.5)])
        m.box(STONE, (-0.7, TY + 2.7, 1.5), (-0.55, TY + 3.9, 1.6), bevel=0.02, seg=1)
        m.box(STONE, (0.55, TY + 2.7, 1.5), (0.7, TY + 3.9, 1.6), bevel=0.02, seg=1)
m.box(STONE, (-1.8, TY + 4.2, Z0 + 1.9), (1.8, TY + 4.5, Z0 + 5.5), bevel=0.04, seg=2)
m.lathe("copper", (0.0, TY + 4.5, Z0 + 3.7), [(0.0, 0.0), (1.6, 0.0), (1.7, 0.25), (1.35, 0.55), (0.9, 1.3), (0.55, 1.9), (0.5, 2.2), (0.0, 2.5)], 20)
m.pipe("gold", (0.0, TY + 7.0, Z0 + 3.7), (0.0, TY + 8.0, Z0 + 3.7), 0.05, 6, r2=0.015)
m.cyl("gold", (0.0, TY + 7.0, Z0 + 3.7), 0.12, 0.12, 10)
m.cyl("gold", (0.0, TY + 6.95, Z0 + 3.7), 0.2, 0.05, 10)
for sx in (-1, 1):                                                                                                           # corner finials
    for sz in (-1, 1):
        m.cyl("copper", (sx * 1.6, TY + 4.5, Z0 + 3.7 + sz * 1.6), 0.12, 0.5, 8, r2=0.02)

# ------------------------------------------------------------------ the plaza: a fountain, lawns, trees, benches, lamps, flags
m.cyl(STONE, (0, 0.13, 5.4), 2.2, 0.6, 28)
m.tube(STONE, (0, 0.73, 5.4), 2.3, 2.0, 0.1, 28, tint=(1.1, 1.1, 1.1))
m.cyl("glass", (0, 0.7, 5.4), 2.0, 0.04, 28)
m.cyl(STONE, (0, 0.74, 5.4), 0.5, 0.4, 12)
m.cyl(STONE, (0, 1.14, 5.4), 0.2, 1.2, 10)
m.lathe(STONE, (0, 2.3, 5.4), [(0.0, 0.0), (0.7, 0.0), (0.8, 0.12), (0.4, 0.25), (0.0, 0.25)], 16)
for k in range(8):                                                                                                           # water jets
    a = math.tau * k / 8
    m.pipe("glass", (math.cos(a) * 0.3, 2.55, 5.4 + math.sin(a) * 0.3), (math.cos(a) * 1.1, 1.0, 5.4 + math.sin(a) * 1.1), 0.02, 4)
for sx in (-1, 1):
    flagpole(m, sx * 5.8, 0.4, 8.0)
for p in ((-6.5, 6.0), (6.5, 6.0), (-6.0, -9.5), (6.0, -9.5), (-8.5, 2.0), (8.5, 2.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-1, 1):
    bench(m, sx * 4.0, 7.5, 0.0)
    bench(m, sx * 7.0, 4.0, math.pi / 2)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
for sx in (-1, 1):
    lamp(m, sx * 3.2, 0.9)
    lamp(m, sx * 2.4, 3.0)
m.finish(out)
