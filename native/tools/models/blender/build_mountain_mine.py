"""The Mountain Mine, modelled in Blender.   blender -b -P build_mountain_mine.py -- <out.glb>

An adit driven into a rock face: a jagged massif at the back with a timbered portal and a dark gallery, a narrow-gauge track with
ore carts running out over sleepers, a loading hopper on legs above a truck, a timber shed with a corrugated roof, ore stockpiles,
a ventilation shaft with a fan on the ridge, a water tank, barrels, lamps and warning signs. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import ground, lamp, tree
from bl_parts import truck

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "mountain_mine.glb"
m = Model("mountain_mine")
rng = random.Random(55)
ground(m, lawns=False, pave=hexc("8a8478"))
HEX = [(math.cos(math.radians(30 + 60 * k)) * 11.4, math.sin(math.radians(30 + 60 * k)) * 11.4) for k in range(6)]
m.polygon("earth", HEX, 0.13, 0.03, tint=(0.78, 0.7, 0.6))

# ------------------------------------------------------------------ the massif
ROCK = (0.72, 0.68, 0.64)
m.hull("gravel", [(-9.5, 0.1, -4.2), (9.5, 0.1, -4.2), (-6.0, 0.1, -9.0), (6.0, 0.1, -9.0),
                 (-8.0, 5.5, -5.0), (8.0, 5.5, -5.0), (-4.0, 6.5, -8.2), (4.0, 6.5, -8.2)], tint=ROCK)
m.hull("gravel", [(-6.5, 5.0, -5.4), (3.0, 5.0, -5.4), (-5.0, 5.2, -8.0), (2.0, 5.2, -8.0), (-2.0, 9.6, -7.0), (0.5, 8.6, -6.2)], tint=(0.62, 0.58, 0.56))
m.hull("gravel", [(1.0, 5.0, -5.6), (8.0, 5.0, -5.0), (2.0, 5.2, -8.0), (5.0, 5.2, -7.6), (5.0, 8.0, -6.8), (7.0, 6.8, -6.0)], tint=(0.78, 0.72, 0.66))
m.hull("gravel", [(-9.2, 0.1, -3.6), (-5.0, 0.1, -3.4), (-9.0, 0.1, -5.6), (-6.0, 0.1, -5.8), (-8.0, 2.6, -4.6), (-6.4, 2.2, -4.4)], tint=(0.5, 0.46, 0.42))   # scree
m.hull("gravel", [(4.6, 0.1, -3.4), (9.0, 0.1, -3.8), (5.0, 0.1, -5.2), (8.6, 0.1, -5.4), (5.4, 2.0, -4.4), (8.0, 2.6, -4.6)], tint=(0.52, 0.48, 0.45))
for k in range(9):                                                                                             # rock strata streaks
    y = 1.2 + k * 0.5
for (sx, sz, r) in ((-7.4, -3.0, 0.7), (7.6, -3.2, 0.6), (-4.8, -3.2, 0.45), (5.0, -3.0, 0.5), (-8.2, -1.0, 0.5)):   # boulders
    m.dome("gravel", (sx, 0.13, sz), r, r * 0.8, 8, 3, tint=(0.58, 0.54, 0.5))

# ------------------------------------------------------------------ the portal and the gallery
m.box("dark", (-1.5, 0.1, -5.4), (1.5, 3.2, -4.0))
for sx in (-1, 1):
    m.box("wood", (sx * 1.7 - 0.22, 0.1, -4.55), (sx * 1.7 + 0.22, 3.5, -3.95), bevel=0.02, seg=1, tint=(0.8, 0.7, 0.6))
    m.pipe("wood", (sx * 1.7, 0.6, -3.9), (sx * 1.2, 3.1, -3.9), 0.1, 6, tint=(0.8, 0.7, 0.6))
m.box("wood", (-1.95, 3.2, -4.55), (1.95, 3.6, -3.95), bevel=0.02, seg=1, tint=(0.85, 0.74, 0.62))
m.box("wood", (-2.1, 3.6, -4.7), (2.1, 3.8, -3.85), bevel=0.02, seg=1, tint=(0.7, 0.6, 0.5))
for k in range(5):                                                                                             # timber sets inside
    m.box("wood", (-1.45, 0.1, -4.4 - k * 0.2), (-1.25, 3.0, -4.3 - k * 0.2), tint=(0.5, 0.42, 0.34))
m.box("hazard", (-0.6, 3.85, -3.9), (0.6, 4.2, -3.84))                                                         # a warning board over the portal
m.box("dark", (-0.5, 3.9, -3.85), (0.5, 4.15, -3.82))
m.box("glow_warm", (-0.12, 2.9, -4.1), (0.12, 3.1, -3.95))

# ------------------------------------------------------------------ the track and the carts
for sx in (-0.42, 0.42):
    m.pipe("metal", (sx, 0.2, -4.0), (sx, 0.2, 7.6), 0.05, 6)
for k in range(21):
    m.box("wood", (-0.75, 0.13, -3.8 + k * 0.56), (0.75, 0.2, -3.6 + k * 0.56), tint=(0.7, 0.6, 0.5))
for (cz, load) in ((-1.4, True), (0.4, True), (2.2, False)):
    m.box("metal", (-0.62, 0.55, cz - 0.7), (0.62, 1.35, cz + 0.7), bevel=0.05, seg=1, tint=(1.0, 0.75, 0.6))
    if load:
        m.dome("gravel", (0.0, 1.3, cz), 0.6, 0.45, 8, 3, tint=(0.45, 0.38, 0.34))
    for sx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            m.cyl("dark", (sx, 0.28, cz + dz), 0.17, 0.12, 10)
m.box("metal", (-0.12, 0.8, 7.0), (0.12, 1.1, 7.4), bevel=0.02, seg=1)                                         # the buffer stop

# ------------------------------------------------------------------ the loading hopper over a truck
for sx in (4.6, 7.0):
    for sz in (1.6, 3.4):
        m.pipe("metal", (sx, 0.13, sz), (sx, 3.6, sz), 0.12, 8)
m.box("metal", (4.4, 3.4, 1.4), (7.2, 3.6, 3.6), bevel=0.03, seg=1)
m.hull("metal", [(4.2, 4.8, 1.2), (7.4, 4.8, 1.2), (4.2, 4.8, 3.8), (7.4, 4.8, 3.8), (5.0, 3.6, 2.0), (6.6, 3.6, 2.0), (5.0, 3.6, 3.0), (6.6, 3.6, 3.0)], tint=(1.0, 0.8, 0.65))
m.box("hazard", (4.2, 4.78, 3.78), (7.4, 4.9, 3.84))
m.pipe("metal", (4.0, 4.9, 2.6), (1.4, 1.5, 0.0), 0.04, 6)                                                       # a ramp for the carts' load
m.box("metal", (5.5, 3.1, 3.6), (6.1, 3.5, 4.4), bevel=0.02, seg=1)                                              # the chute
truck(m, 5.8, 6.0, 0.0, canvas=False, bed=4.2)
m.dome("gravel", (5.8, 1.8, 5.2), 0.8, 0.55, 8, 3, tint=(0.45, 0.38, 0.34))

# ------------------------------------------------------------------ the shed, the stockpiles, the tank, the ventilation shaft
m.box("wood", (-9.0, 0.13, -3.0), (-5.0, 3.0, 0.4), bevel=0.03, seg=1, tint=(0.75, 0.6, 0.45))
m.hull("metal", [(-9.3, 3.0, -3.3), (-4.7, 3.0, -3.3), (-9.3, 3.0, 0.7), (-4.7, 3.0, 0.7), (-9.3, 3.7, -3.3), (-4.7, 3.7, -3.3)], tint=(1.3, 1.1, 0.9))
for z in (-2.0, -0.6):
    m.box("glass", (-5.02, 1.2, z - 0.4), (-4.98, 2.2, z + 0.4))
m.box("dark", (-7.4, 0.13, 0.38), (-6.4, 2.3, 0.44))
m.cyl("metal", (-6.0, 3.7, -2.0), 0.18, 1.0, 8)                                                                  # the stove pipe
m.marker("Smoke_Industry_0", (-6.0, 4.8, -2.0))
m.dome("gravel", (-6.4, 0.13, 3.2), 2.4, 1.8, 12, 4, tint=(0.5, 0.42, 0.38))                                     # ore stockpiles
m.dome("gravel", (-3.6, 0.13, 4.6), 1.5, 1.2, 10, 3, tint=(0.42, 0.36, 0.34))
m.dome("gravel", (-8.4, 0.13, 4.2), 1.2, 0.9, 8, 3, tint=(0.55, 0.48, 0.42))
for sx in (-1, 1):                                                                                               # a water tank on legs
    m.pipe("metal", (8.0 + sx * 0.6, 0.13, -2.4), (8.0 + sx * 0.6, 2.2, -2.4), 0.07, 6)
m.cyl("metal", (8.0, 2.2, -2.4), 0.9, 1.4, 14, tint=(1.0, 0.9, 0.8))
m.dome("metal", (8.0, 3.6, -2.4), 0.9, 0.35, 12, 3)
# the ventilation shaft on the ridge
m.cyl("metal", (-1.8, 9.2, -7.2), 0.55, 1.0, 12)
m.tube("metal", (-1.8, 10.2, -7.2), 0.62, 0.5, 0.2, 12)
m.cyl("dark", (-1.8, 10.3, -7.2), 0.5, 0.05, 12)
for k in range(4):
    a = math.tau * k / 4 + 0.4

# ------------------------------------------------------------------ barrels, lamps and a few tough trees
for (bx, bz) in ((2.6, -3.2), (3.3, -3.4), (3.0, -2.6)):
    m.cyl("hazard" if bx < 3.0 else "metal", (bx, 0.13, bz), 0.28, 0.8, 10)
lamp(m, -2.4, -3.4, 4.0)
lamp(m, 2.4, -3.4, 4.0)
lamp(m, 2.8, 5.8, 3.6)
for p in ((9.2, 1.0), (-9.8, 3.0), (-2.0, 8.8), (8.6, 4.8)):
    tree(m, p[0], p[1], 1.6, 0.8)
m.finish(out)
