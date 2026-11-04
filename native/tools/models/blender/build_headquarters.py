"""The Headquarters, modelled in Blender.   blender -b -P build_headquarters.py -- <out.glb> [style]

The seat of the capital: a long stone government block with a taller central house, a colonnade of square piers, a flag tower and a
roof of masts and dishes, a wing with a helipad, a gatehouse with a barrier and guard booths, bollards along the front, a circular
drive round a flag plaza, black limousines, lawns, trees and lamps. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *
from bl_parts import dish, lattice
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "headquarters.glb"
m = Model("headquarters")
rng = random.Random(21)
apply_style(m)
ground(m, lawns=False)
for sx in (-1, 1):                                                                                            # lawns beside the drive
    m.box("turf", (sx * 6.4 - 1.6, 0.13, 1.0), (sx * 6.4 + 1.6, 0.2, 5.4), tint=hexc("5a8a46"))

# ------------------------------------------------------------------ the main block: x +-6.6, z -7.8 .. -3
X, Z0, Z1 = 6.6, -7.8, -3.0
m.box(STONE, (-X - 0.15, 0.1, Z0 - 0.15), (X + 0.15, 0.9, Z1 + 0.15), bevel=0.04, seg=1, tint=(0.9, 0.9, 0.9))   # the plinth
m.box(STONE, (-X, 0.9, Z0), (X, 8.4, Z1), bevel=0.03, seg=1)
m.box(STONE, (-X - 0.35, 8.4, Z0 - 0.35), (X + 0.35, 8.8, Z1 + 0.35), bevel=0.04, seg=1, tint=(1.1, 1.1, 1.1))   # the cornice
for k in range(3):                                                                                            # ribbon windows, three storeys
    y = 1.6 + k * 2.4
    for i in range(7):
        x = -5.4 + i * 1.8
        if abs(x) < 2.3:
            continue
        window(m, x, y, Z1, 1.1, 1.5, 1)
for z in (-6.8, -5.2, -3.8):
    for k in range(3):
        for sx in (-1, 1):
            with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
                window(m, 0.0, 1.6 + k * 2.4, 0.0, 0.9, 1.5, 1)
# the central house: taller, with the great door
m.box(STONE, (-3.2, 8.8, Z0 + 0.4), (3.2, 12.8, Z1 - 0.2), bevel=0.04, seg=1)
m.box(STONE, (-3.5, 12.8, Z0 + 0.2), (3.5, 13.2, Z1), bevel=0.04, seg=1, tint=(1.1, 1.1, 1.1))
for i in range(4):
    window(m, -2.25 + i * 1.5, 9.6, Z1 - 0.2, 1.0, 2.2, 1)
for k in range(5):                                                                                            # the colonnade: square piers across the front
    px = -3.6 + k * 1.8
    m.box(STONE, (px - 0.3, 0.9, Z1 + 0.5), (px + 0.3, 6.6, Z1 + 1.1), bevel=0.03, seg=1, tint=(1.05, 1.05, 1.05))
m.box(STONE, (-4.3, 6.6, Z1 + 0.35), (4.3, 7.2, Z1 + 1.25), bevel=0.04, seg=1)
m.box("dark", (-1.0, 0.9, Z1 + 0.0), (1.0, 4.2, Z1 + 0.04))                                                   # the great door
m.box("glass", (-0.9, 1.0, Z1 + 0.04), (0.9, 4.1, Z1 + 0.08))
m.box("gold", (-0.04, 1.0, Z1 + 0.08), (0.04, 4.1, Z1 + 0.11))
steps(m, -3.0, 3.0, Z1 + 1.25, 6, 0.15, 0.38)
m.box("gold", (-1.6, 12.2, Z1 - 0.22), (1.6, 12.6, Z1 - 0.16))                                                # the seal, high on the central house

# ------------------------------------------------------------------ the roof: a flag tower, masts and dishes
m.pipe(METAL, (0.0, 13.2, -5.4), (0.0, 22.0, -5.4), 0.1, 8, r2=0.05)
m.cyl("gold", (0.0, 22.0, -5.4), 0.14, 0.18, 8)
m.box("banner", (0.03, 17.6, -5.4), (0.07, 21.4, -3.0))
lattice(m, 4.4, -6.6, 6.5, 0.8, y0=8.8)
m.pipe(METAL, (-5.0, 8.8, -6.8), (-5.0, 12.6, -6.8), 0.05, 6)
dish(m, (5.0, 11.0, -6.6), 0.9, math.radians(40), math.radians(30))
dish(m, (-4.0, 9.6, -6.8), 0.6, math.radians(-30), math.radians(25))
for k in range(3):
    m.box("cladding", (-5.8 + k * 1.2, 8.8, -7.4), (-5.0 + k * 1.2, 9.6, -6.4), bevel=0.02, seg=1)           # plant on the roof

# ------------------------------------------------------------------ the east wing with the helipad, the west wing with the annexe
m.box(STONE, (6.6, 0.9, -6.2), (9.8, 6.4, -3.6), bevel=0.03, seg=1)
m.box(STONE, (6.5, 6.4, -6.3), (9.9, 6.7, -3.5), bevel=0.04, seg=1, tint=(1.1, 1.1, 1.1))
m.cyl(CONC, (8.3, 6.7, -4.9), 1.6, 0.12, 28, tint=(0.85, 0.85, 0.85))
m.tube("paint", (8.3, 6.82, -4.9), 1.4, 1.3, 0.02, 28, tint=hexc("f4f0e4"))
for hx in (-0.4, 0.4):
    m.box("paint", (8.3 + hx - 0.06, 6.84, -5.4), (8.3 + hx + 0.06, 6.86, -4.4), tint=hexc("f4f0e4"))
m.box("paint", (7.9, 6.84, -4.96), (8.7, 6.86, -4.84), tint=hexc("f4f0e4"))
for k in range(8):
    a = math.tau * k / 8
    m.cyl("glow_green", (8.3 + math.cos(a) * 1.7, 6.7, -4.9 + math.sin(a) * 1.7), 0.06, 0.1, 6)
for z in (-5.5, -4.3):
    for k in range(2):
        with m.frame((9.8, 0, z), yaw=math.pi / 2):
            window(m, 0.0, 1.8 + k * 2.4, 0.0, 0.9, 1.5, 1)
m.box(STONE, (-9.8, 0.9, -6.0), (-6.6, 5.2, -3.8), bevel=0.03, seg=1)
m.box(STONE, (-9.9, 5.2, -6.1), (-6.5, 5.5, -3.7), bevel=0.04, seg=1, tint=(1.1, 1.1, 1.1))
for i in range(3):
    window(m, -9.0 + i * 1.1, 2.0, -3.8, 0.7, 1.6, 1)
for k in range(3):
    m.cyl("cladding", (-9.0 + k * 1.1, 5.5, -4.9), 0.42, 0.8, 12)

# ------------------------------------------------------------------ the circular drive, the flag plaza and the cars
m.tube("asphalt", (0.0, 0.1, 3.4), 4.6, 2.6, 0.05, 36)
m.cyl("pavers", (0.0, 0.1, 3.4), 2.6, 0.06, 28, tint=(1.1, 1.1, 1.1))
m.tube(STONE, (0.0, 0.16, 3.4), 2.7, 2.5, 0.12, 28)
m.pipe(METAL, (0.0, 0.16, 3.4), (0.0, 9.5, 3.4), 0.07, 8, r2=0.04)
m.cyl("gold", (0.0, 9.5, 3.4), 0.1, 0.12, 8)
m.box("banner", (0.03, 8.0, 3.4), (0.06, 9.3, 5.2))
m.box("asphalt", (-1.5, 0.1, 7.7), (1.5, 0.14, 11.0))                                                         # the way in
for sx in (-1, 1):
    m.box("asphalt", (sx * 1.0 - 0.5, 0.1, -2.9), (sx * 1.0 + 0.5, 0.14, 0.0))
for (cx, cz, yaw) in ((3.4, 5.4, 0.5), (-3.2, 1.6, math.pi + 0.4)):                                           # black limousines
    with m.frame((cx, 0, cz), yaw=yaw):
        m.box("paint", (-0.9, 0.3, -2.2), (0.9, 1.15, 2.2), bevel=0.15, seg=2, tint=hexc("15181c"))
        m.box("glass", (-0.8, 1.1, -1.2), (0.8, 1.7, 1.0), bevel=0.1, seg=2)
        for wx in (-0.95, 0.95):
            for wz in (-1.4, 1.4):
                m.cyl("dark", (wx, 0.35, wz), 0.34, 0.2, 10)

# ------------------------------------------------------------------ the gate and its guards
for sx in (-1, 1):
    m.box(STONE, (sx * 2.0 - 0.5, 0.1, 8.7), (sx * 2.0 + 0.5, 3.2, 9.7), bevel=0.03, seg=1)
    m.box(STONE, (sx * 2.0 - 0.65, 3.2, 8.55), (sx * 2.0 + 0.65, 3.45, 9.85), bevel=0.03, seg=1)
    m.box("wall_concrete", (sx * 3.9 - 0.8, 0.1, 8.0), (sx * 3.9 + 0.8, 2.6, 9.2), bevel=0.04, seg=1)        # the guard booths
    m.box("glass", (sx * 3.9 - 0.7, 1.1, 9.18), (sx * 3.9 + 0.7, 2.3, 9.26))
    m.box("wall_concrete", (sx * 3.9 - 1.0, 2.6, 7.8), (sx * 3.9 + 1.0, 2.8, 9.4), bevel=0.03, seg=1)
m.box("paint", (-1.5, 1.5, 9.1), (0.4, 1.65, 9.3), tint=hexc("e8e4da"))                                       # the barrier arm
m.box("hazard", (0.4, 1.5, 9.1), (1.5, 1.65, 9.3))
for k in range(9):                                                                                            # bollards along the front
    bx = -9.0 + k * 2.25
    if abs(bx) < 4.5:
        continue
    m.cyl("metal", (bx, 0.1, 6.9), 0.14, 0.9, 8)
    m.cyl("hazard", (bx, 0.75, 6.9), 0.145, 0.12, 8)

# ------------------------------------------------------------------ trees and lamps
for p in ((-9.4, 3.2), (9.4, 3.2), (-6.4, 6.2), (6.4, 6.2), (-9.0, -1.0), (9.0, -1.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, 0.0, 8.8, -5.4, 12.6, 4.4, corners_only=True)
m.finish(out)
