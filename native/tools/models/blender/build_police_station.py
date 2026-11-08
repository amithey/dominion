"""The Police Station, modelled in Blender.   blender -b -P build_police_station.py -- <out.glb>

A two-storey precinct in pale stone and brick with a blue band: a centre entrance under a canopy with a lit POLICE sign and
steps, windows with brick surrounds, a flat roof with a radio mast, dish and AC units, a garage wing with roller doors, three
patrol cars with light bars, a motorcycle, a holding-van, bollards, a flag and lamps on a hex plaza. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, dish, slats
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "police_station.glb"
m = Model("police_station")
apply_style(m)
rng = random.Random(33)
ground(m, lawns=False, pave=hexc("cdcdc8"))
BLUE = hexc("1f3f7a")
WH = (1.5, 1.5, 1.45)
CLAD = "cladding"


def win(x, y, z, w=1.1, h=1.5):
    m.box("dark", (x - w / 2, y, z - 0.03), (x + w / 2, y + h, z))
    m.box(GLASS, (x - w / 2, y, z), (x + w / 2, y + h, z + 0.03), tint=(1.6, 1.8, 2.0))
    m.box("wall_concrete", (x - 0.02, y, z), (x + 0.02, y + h, z + 0.07), tint=WH)
    m.box("wall_concrete", (x - w / 2, y + h / 2 - 0.02, z), (x + w / 2, y + h / 2 + 0.02, z + 0.07), tint=WH)
    m.box(BRICK, (x - w / 2 - 0.15, y - 0.12, z), (x + w / 2 + 0.15, y, z + 0.18), bevel=0.02, seg=1)
    m.box(BRICK, (x - w / 2 - 0.15, y + h, z), (x + w / 2 + 0.15, y + h + 0.18, z + 0.1), bevel=0.02, seg=1)
    for sx in (-1, 1):
        m.box(BRICK, (x + sx * (w / 2 + 0.1) - 0.05, y, z), (x + sx * (w / 2 + 0.1) + 0.05, y + h, z + 0.08), bevel=0.01, seg=1)


def patrol_car(x, z, yaw):
    return
    with m.frame((x, 0, z), yaw=yaw):
        m.box("paint", (-0.9, 0.3, -2.2), (0.9, 0.95, 2.2), bevel=0.15, seg=3, tint=hexc("eceae6"))
        m.box("paint", (-0.91, 0.3, -2.2), (0.91, 0.62, 2.2), bevel=0.1, seg=2, tint=hexc("1f3f7a"))
        m.box(GLASS, (-0.78, 0.95, -1.0), (0.78, 1.45, 1.0), bevel=0.12, seg=2)
        m.box("paint", (-0.74, 1.43, -0.9), (0.74, 1.48, 0.9), tint=hexc("eceae6"))
        m.box("glow_red", (-0.6, 1.48, -0.2), (-0.05, 1.6, 0.2))
        m.box("glow_cyan", (0.05, 1.48, -0.2), (0.6, 1.6, 0.2), tint=(0.3, 0.5, 1.0))
        for sx in (-1, 1):
            for sz in (-1.35, 1.35):
                m.pipe("dark", (sx * 0.82, 0.34, sz), (sx * 1.0, 0.34, sz), 0.34, 12)
        m.box("glow_warm", (-0.75, 0.55, 2.2), (-0.45, 0.68, 2.23))
        m.box("glow_warm", (0.45, 0.55, 2.2), (0.75, 0.68, 2.23))
        m.box("glow_red", (-0.75, 0.6, -2.23), (-0.45, 0.72, -2.2))
        m.box("glow_red", (0.45, 0.6, -2.23), (0.75, 0.72, -2.2))
        m.box("dark", (-0.5, 0.35, 2.2), (0.5, 0.55, 2.28))


# ------------------------------------------------------------------ the precinct: x -7 .. 5, z -9 .. -4.5
X0, X1, Z0, Z1 = -7.0, 5.0, -9.0, -4.5
m.box(STONE, (X0 - 0.15, 0.1, Z0 - 0.15), (X1 + 0.15, 0.9, Z1 + 0.15), bevel=0.03, seg=1)
m.box(STONE, (X0, 0.9, Z0), (X1, 3.9, Z1), bevel=0.02, seg=1, tint=(1.05, 1.05, 1.1))
m.box(BRICK, (X0, 3.9, Z0), (X1, 7.0, Z1), bevel=0.02, seg=1)
for k in range(15):
    m.box("dark", (X0, 4.0 + k * 0.2, Z1 - 0.005), (X1, 4.02 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))
for k in range(9):
    m.box("dark", (X0, 1.0 + k * 0.32, Z1 - 0.005), (X1, 1.02 + k * 0.32, Z1 + 0.015), tint=(0.55, 0.55, 0.55))
m.box("paint", (X0 - 0.05, 3.7, Z0 - 0.05), (X1 + 0.05, 4.0, Z1 + 0.1), bevel=0.02, seg=1, tint=BLUE)                    # the blue band
m.box(STONE, (X0 - 0.3, 7.0, Z0 - 0.3), (X1 + 0.3, 7.5, Z1 + 0.35), bevel=0.04, seg=2)                                  # cornice
m.box(STONE, (X0 - 0.2, 7.5, Z1 + 0.1), (X1 + 0.2, 8.1, Z1 + 0.35), bevel=0.03, seg=1)                                   # parapet
for z in (Z0 - 0.1,):
    m.box(STONE, (X0 - 0.2, 7.5, z), (X1 + 0.2, 8.1, z + 0.25), bevel=0.03, seg=1)
for sx in (X0 - 0.1, X1 - 0.15):
    m.box(STONE, (sx, 7.5, Z0), (sx + 0.25, 8.1, Z1 + 0.35), bevel=0.03, seg=1)
m.box("gravel", (X0, 7.5, Z0), (X1, 7.55, Z1), tint=(0.9, 0.9, 0.9))
for x in (-5.8, -4.2, -2.6, 2.0, 3.6):
    win(x, 1.5, Z1, 1.1, 1.7)
    win(x, 4.5, Z1, 1.1, 1.8)
for z in (-8.0, -6.5):
    for y in (1.5, 4.5):
        for sx in (-1, 1):
            with m.frame((X0 if sx < 0 else X1, 0, z), yaw=sx * math.pi / 2):
                win(0.0, y, 0.0, 1.1, 1.7)
for x in (-5.0, -2.5, 0.0, 2.5, 4.0):
    for y in (1.5, 4.5):
        with m.frame((x, 0, Z0), yaw=math.pi):
            win(0.0, y, 0.0, 1.1, 1.7)

# ------------------------------------------------------------------ the entrance: a canopy, glass doors, a lit sign, steps
CX = -0.3
m.box(STONE, (CX - 1.6, 0.9, Z1), (CX + 1.6, 4.0, Z1 + 0.5), bevel=0.03, seg=1, tint=(1.15, 1.15, 1.2))
m.box("dark", (CX - 1.0, 0.9, Z1 + 0.48), (CX + 1.0, 3.0, Z1 + 0.52))
for sx in (-1, 1):
    m.box(DARK, (CX + sx * 0.5 - 0.46, 0.92, Z1 + 0.5), (CX + sx * 0.5 + 0.46, 2.9, Z1 + 0.58), bevel=0.02, seg=1)
    m.box(GLASS, (CX + sx * 0.5 - 0.38, 1.0, Z1 + 0.58), (CX + sx * 0.5 + 0.38, 2.8, Z1 + 0.6), tint=(1.6, 1.8, 2.0))
    m.pipe(METAL, (CX + sx * 0.08, 1.7, Z1 + 0.66), (CX + sx * 0.08, 2.2, Z1 + 0.66), 0.02, 5)
m.box(CLAD, (CX - 2.0, 3.1, Z1 + 0.4), (CX + 2.0, 3.35, Z1 + 2.3), bevel=0.03, seg=1, tint=(1.1, 1.1, 1.15))             # the canopy
m.box("paint", (CX - 2.0, 3.1, Z1 + 2.1), (CX + 2.0, 3.35, Z1 + 2.3), tint=BLUE)
for sx in (-1, 1):
    m.pipe(METAL, (CX + sx * 1.9, 0.1, Z1 + 2.1), (CX + sx * 1.9, 3.1, Z1 + 2.1), 0.08, 8)
m.box("glow_cyan", (CX - 1.8, 3.05, Z1 + 0.6), (CX + 1.8, 3.1, Z1 + 2.0), tint=(0.8, 0.9, 1.0))
m.box("paint", (CX - 1.6, 5.4, Z1 + 0.5), (CX + 1.6, 6.6, Z1 + 0.58), bevel=0.02, seg=1, tint=BLUE)                        # the sign board
for k, (a, b) in enumerate(((-1.35, -1.1), (-1.0, -0.78), (-0.68, -0.5), (-0.4, -0.2), (-0.1, 0.1), (0.2, 0.4), (0.5, 0.7), (0.8, 1.0), (1.1, 1.3))):
    m.box("glow_warm", (CX + a, 5.7, Z1 + 0.58), (CX + b, 6.3, Z1 + 0.62), tint=(1.0, 1.0, 1.0))
m.box("glow_warm", (CX - 1.45, 5.55, Z1 + 0.58), (CX + 1.45, 5.6, Z1 + 0.6))
m.box("glow_warm", (CX - 1.45, 6.4, Z1 + 0.58), (CX + 1.45, 6.45, Z1 + 0.6))
steps(m, CX - 1.4, CX + 1.4, Z1 + 0.5, 4, 0.2, 0.4, role=STONE)
for sx in (-1, 1):
    m.pipe(METAL, (CX + sx * 1.7, 0.95, Z1 + 0.5), (CX + sx * 1.7, 0.95, Z1 + 2.0), 0.03, 6)
for sx in (-1, 1):                                                                                                         # blue lamps either side of the door
    m.cyl("glow_cyan", (CX + sx * 2.0 - 0.0, 2.2, Z1 + 0.0), 0.12, 0.35, 10, tint=(0.35, 0.55, 1.0))

# ------------------------------------------------------------------ the roof: a mast, dish, AC units, a stair bulkhead
RY = 7.55
m.pipe(METAL, (-4.5, RY, Z0 + 1.0), (-4.5, RY + 6.0, Z0 + 1.0), 0.06, 8)
for y in (RY + 3.0, RY + 4.5, RY + 5.5):
    m.pipe(METAL, (-5.1, y, Z0 + 1.0), (-3.9, y, Z0 + 1.0), 0.03, 5)
for gx, gz in ((-6.5, Z0 + 2.6), (-2.5, Z0 + 2.6), (-4.5, Z0 + 3.4)):
    m.wire(METAL, [(-4.5, RY + 4.0, Z0 + 1.0), (gx, RY, gz)], 0.008)
m.cyl("glow_red", (-4.5, RY + 6.0, Z0 + 1.0), 0.07, 0.15, 8)
dish(m, (-1.0, RY, Z0 + 1.6), 0.7, 0.5, 0.7)
for k in range(3):
    m.box(DARK, (1.0 + k * 1.3, RY, Z0 + 0.8), (2.1 + k * 1.3, RY + 0.9, Z0 + 2.2), bevel=0.03, seg=1)
    fan(m, (1.55 + k * 1.3, RY + 0.9, Z0 + 1.5), 0.4)
m.box(BRICK, (3.5, RY, Z1 - 2.0), (4.8, RY + 2.2, Z1 - 0.5), bevel=0.03, seg=1)
m.box(STONE, (3.4, RY + 2.2, Z1 - 2.1), (4.9, RY + 2.35, Z1 - 0.4), bevel=0.02, seg=1)
m.box("dark", (3.7, RY, Z1 - 0.5), (4.5, RY + 1.9, Z1 - 0.46))

# ------------------------------------------------------------------ the garage wing with roller doors
GX0, GX1 = 5.3, 10.0
m.box(BRICK, (GX0, 0.1, -8.2), (GX1, 4.2, -3.2), bevel=0.02, seg=1)
m.box(STONE, (GX0 - 0.1, 0.1, -8.3), (GX1 + 0.1, 0.9, -3.1), bevel=0.03, seg=1)
for k in range(14):
    m.box("dark", (GX0, 1.0 + k * 0.22, -3.205), (GX1, 1.02 + k * 0.22, -3.185), tint=(0.35, 0.3, 0.28))
m.box(STONE, (GX0 - 0.2, 4.2, -8.4), (GX1 + 0.2, 4.5, -3.0), bevel=0.03, seg=2)
m.box("gravel", (GX0, 4.5, -8.2), (GX1, 4.55, -3.2), tint=(0.9, 0.9, 0.9))
for k in range(2):
    x0 = GX0 + 0.4 + k * 2.2
    m.box("dark", (x0, 0.9, -3.22), (x0 + 1.9, 3.2, -3.16))
    for q in range(12):
        m.box(METAL, (x0 + 0.04, 0.95 + q * 0.19, -3.16), (x0 + 1.86, 0.95 + q * 0.19 + 0.1, -3.13))
    m.box(DARK, (x0 - 0.05, 3.2, -3.22), (x0 + 1.95, 3.35, -3.1), bevel=0.02, seg=1)
    m.box("paint", (x0 + 0.3, 3.45, -3.1), (x0 + 1.6, 3.9, -3.07), tint=BLUE)

# ------------------------------------------------------------------ the forecourt
patrol_car(-5.2, 3.0, math.pi)
patrol_car(-2.6, 3.4, math.pi * 0.95)
patrol_car(0.6, 2.8, math.pi * 1.04)
for k in range(6):
    m.cyl(METAL, (-8.5 + k * 1.0, 0.13, 6.5), 0.1, 0.8, 10)
    m.cyl("glow_cyan", (-8.5 + k * 1.0, 0.93, 6.5), 0.1, 0.03, 8, tint=(0.3, 0.5, 1.0))
for p in ((-8.8, 3.0), (-8.5, -3.5), (9.0, 6.5), (2.0, 8.8), (-4.0, 8.6)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-1, 1):
    lamp(m, sx * 5.0, 6.0)
bench(m, -1.0, 6.0, 0.0)
flagpole(m, 2.8, 6.2, 8.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, -1.0, 7.55, -6.75, 12.0, 4.5, corners_only=True)
    forecourt(m, 9.4)
m.finish(out)
