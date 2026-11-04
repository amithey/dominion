"""The Bank, modelled in Blender.   blender -b -P build_bank.py -- <out.glb>

A granite temple-front bank on a high podium: six fluted columns, an entablature with a gilded frieze, a pediment, a broad stair,
bronze doors under a transom, tall barred arched windows along the sides, a slate gable roof with a skylight lantern, security
bollards, an ATM kiosk, an armoured van, planters, lamps, a flag and a hex plaza. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "bank.glb"
m = Model("bank")
rng = random.Random(14)
apply_style(m)
ground(m)
GRANITE = (0.82, 0.82, 0.86)


def arched_window(x, y0, z, w=1.2, h=3.2, facing=1):
    """A tall arched window on a wall facing +z: stone surround, glass, iron bars, a keystone."""
    with m.frame((x, 0, z), yaw=0.0 if facing > 0 else math.pi):
        m.box("dark", (-w / 2, y0, -0.02), (w / 2, y0 + h, 0.0))
        pts = [(math.cos(math.pi * k / 8) * w / 2, y0 + h + math.sin(math.pi * k / 8) * w / 2) for k in range(9)]
        m.hull("dark", [(px, py, -0.02) for px, py in pts] + [(px, py, 0.0) for px, py in pts])
        m.box(GLASS, (-w / 2, y0, 0.0), (w / 2, y0 + h, 0.03))
        m.hull(GLASS, [(px, py, 0.0) for px, py in pts] + [(px, py, 0.03) for px, py in pts])
        for k in range(1, 5):
            xx = -w / 2 + w * k / 5
            m.pipe("gold", (xx, y0 - 0.02, 0.1), (xx, y0 + h + math.sqrt(max(0, (w / 2) ** 2 - xx ** 2)), 0.1), 0.018, 5)
        for yy in (y0 + 0.9, y0 + 2.0):
            m.pipe("gold", (-w / 2, yy, 0.1), (w / 2, yy, 0.1), 0.015, 5)
        for sx in (-1, 1):
            m.box(STONE, (sx * (w / 2 + 0.1) - 0.1, y0 - 0.1, 0.0), (sx * (w / 2 + 0.1) + 0.1, y0 + h + 0.1, 0.18), bevel=0.02, seg=1)
        for a0 in range(8):
            m.hull(STONE, [(math.cos(math.pi * a0 / 8) * (w / 2 + 0.1), y0 + h + math.sin(math.pi * a0 / 8) * (w / 2 + 0.1), 0.18), (math.cos(math.pi * (a0 + 1) / 8) * (w / 2 + 0.1), y0 + h + math.sin(math.pi * (a0 + 1) / 8) * (w / 2 + 0.1), 0.18),
                           (math.cos(math.pi * a0 / 8) * (w / 2 + 0.3), y0 + h + math.sin(math.pi * a0 / 8) * (w / 2 + 0.3), 0.18), (math.cos(math.pi * (a0 + 1) / 8) * (w / 2 + 0.3), y0 + h + math.sin(math.pi * (a0 + 1) / 8) * (w / 2 + 0.3), 0.18),
                           (math.cos(math.pi * a0 / 8) * (w / 2 + 0.1), y0 + h + math.sin(math.pi * a0 / 8) * (w / 2 + 0.1), 0.0), (math.cos(math.pi * (a0 + 1) / 8) * (w / 2 + 0.1), y0 + h + math.sin(math.pi * (a0 + 1) / 8) * (w / 2 + 0.1), 0.0),
                           (math.cos(math.pi * a0 / 8) * (w / 2 + 0.3), y0 + h + math.sin(math.pi * a0 / 8) * (w / 2 + 0.3), 0.0), (math.cos(math.pi * (a0 + 1) / 8) * (w / 2 + 0.3), y0 + h + math.sin(math.pi * (a0 + 1) / 8) * (w / 2 + 0.3), 0.0)])
        m.box(STONE, (-0.15, y0 + h + w / 2 + 0.05, 0.0), (0.15, y0 + h + w / 2 + 0.45, 0.24), bevel=0.02, seg=1)
        m.box(STONE, (-w / 2 - 0.25, y0 - 0.12, 0.0), (w / 2 + 0.25, y0, 0.3), bevel=0.02, seg=1)


# ------------------------------------------------------------------ podium, walls, stair
X, Z0, Z1 = 4.4, -9.4, -1.2
m.box(STONE, (-5.6, 0.1, Z0 - 0.4), (5.6, 1.3, 0.8), bevel=0.05, seg=2, tint=GRANITE)
steps(m, -3.7, 3.7, 0.8, 7, 0.17, 0.34, role=STONE)
for sx in (-1, 1):
    m.box(STONE, (sx * 4.3 - 0.35, 0.1, 0.8), (sx * 4.3 + 0.35, 1.7, 3.3), bevel=0.04, seg=1, tint=GRANITE)
    m.dome(STONE, (sx * 4.3, 1.7, 3.0), 0.35, 0.25, 8, 2)
    m.cyl("gold", (sx * 4.3, 1.95, 3.0), 0.08, 0.35, 8, r2=0.03)
m.box(STONE, (-X, 1.3, Z0), (X, 7.0, Z1), bevel=0.04, seg=1, tint=GRANITE)
for k in range(7):
    m.box("dark", (-X, 1.8 + k * 0.78, Z1 - 0.01), (X, 1.82 + k * 0.78, Z1 + 0.02), tint=(0.5, 0.5, 0.5))    # ashlar joints on the cella
m.box(STONE, (-X - 0.25, 7.0, Z0 - 0.25), (X + 0.25, 7.5, Z1 + 0.15), bevel=0.04, seg=2, tint=GRANITE)         # cornice

# ------------------------------------------------------------------ the portico, entablature, pediment
PZ = 0.1
m.box(STONE, (-4.2, 1.3, Z1), (4.2, 1.45, PZ + 0.6), bevel=0.03, seg=1, tint=GRANITE)
for i in range(6):
    column(m, -3.2 + i * 1.28, PZ, 1.45, 6.9, 0.34, STONE)
m.box(STONE, (-4.1, 6.9, Z1), (4.1, 7.6, PZ + 0.45), bevel=0.04, seg=1, tint=GRANITE)
m.box("gold", (-3.6, 7.05, PZ + 0.46), (3.6, 7.45, PZ + 0.49))                                                  # the gilded frieze
for k in range(9):
    m.box("dark", (-3.4 + k * 0.85, 7.15, PZ + 0.49), (-3.35 + k * 0.85, 7.35, PZ + 0.5))
pediment(m, -4.4, 4.4, 7.6, PZ + 0.45, 1.8, 0.5, role=STONE)
m.cyl("gold", (0.0, 8.55, PZ + 0.1), 0.55, 0.05, 24)
m.tube("gold", (0.0, 8.55, PZ + 0.1), 0.7, 0.6, 0.06, 24)
m.hull(SLATE, [(-4.7, 7.5, Z0 - 0.3), (4.7, 7.5, Z0 - 0.3), (-4.7, 7.5, PZ + 0.4), (4.7, 7.5, PZ + 0.4), (0.0, 9.3, Z0 - 0.3), (0.0, 9.3, PZ + 0.4)], tint=(0.95, 0.95, 1.0))
m.pipe(METAL, (0.0, 9.3, Z0 - 0.3), (0.0, 9.3, PZ + 0.4), 0.07, 6)
for z in (Z0 - 0.2, PZ + 0.35):
    m.cyl("gold", (0.0, 9.28, z), 0.14, 0.3, 8, r2=0.02)
m.box(STONE, (-1.2, 9.0, Z0 + 2.5), (1.2, 9.9, Z0 + 5.5), bevel=0.04, seg=1, tint=GRANITE)                       # the skylight lantern
m.hull(GLASS, [(-1.1, 9.9, Z0 + 2.6), (1.1, 9.9, Z0 + 2.6), (-1.1, 9.9, Z0 + 5.4), (1.1, 9.9, Z0 + 5.4), (-0.4, 10.6, Z0 + 3.4), (0.4, 10.6, Z0 + 3.4), (-0.4, 10.6, Z0 + 4.6), (0.4, 10.6, Z0 + 4.6)])

# ------------------------------------------------------------------ the doors and windows
m.box("dark", (-1.25, 1.45, Z1 - 0.02), (1.25, 5.0, Z1 + 0.02))
for sx in (-1, 1):
    m.box("gold", (sx * 0.62 - 0.6, 1.45, Z1), (sx * 0.62 + 0.6, 4.1, Z1 + 0.14), bevel=0.03, seg=2, tint=(0.42, 0.28, 0.14))     # bronze leaves
    for yy in (1.9, 2.9):
        m.box("gold", (sx * 0.62 - 0.45, yy, Z1 + 0.14), (sx * 0.62 + 0.45, yy + 0.8, Z1 + 0.17), bevel=0.02, seg=1, tint=(0.9, 0.8, 0.5))
    m.pipe("gold", (sx * 0.12 * 1.0, 2.3, Z1 + 0.2), (sx * 0.12, 3.0, Z1 + 0.2), 0.03, 6)
m.hull(GLASS, [(-1.2, 4.2, Z1), (1.2, 4.2, Z1), (-1.2, 4.2, Z1 + 0.05), (1.2, 4.2, Z1 + 0.05), (-1.2, 4.9, Z1), (1.2, 4.9, Z1), (-1.2, 4.9, Z1 + 0.05), (1.2, 4.9, Z1 + 0.05)])
for k in range(5):
    m.pipe("gold", (-1.0 + k * 0.5, 4.2, Z1 + 0.08), (-1.0 + k * 0.5, 4.9, Z1 + 0.08), 0.015, 5)
m.box(STONE, (-1.5, 5.0, Z1), (1.5, 5.3, Z1 + 0.3), bevel=0.03, seg=1)
for sx in (-1, 1):
    m.box("glow_warm", (sx * 2.1 - 0.15, 3.6, Z1), (sx * 2.1 + 0.15, 4.0, Z1 + 0.22))
for z in (-3.0, -5.2, -7.4):
    for sx in (-1, 1):
        with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
            arched_window(0.0, 2.2, 0.0, 1.2, 3.0, 1)

# ------------------------------------------------------------------ the forecourt
for sx in (-1, 1):
    for k in range(5):
        bx = sx * (3.5 + k * 1.4)
        m.cyl(METAL, (bx, 0.13, 4.6), 0.1, 0.8, 10)
        m.cyl("gold", (bx, 0.93, 4.6), 0.105, 0.05, 10)
        m.cyl("glow_warm", (bx, 0.98, 4.6), 0.06, 0.02, 8)
m.box(CONC, (6.6, 0.13, 3.0), (8.0, 2.4, 4.0), bevel=0.04, seg=1, tint=(1.2, 1.2, 1.2))                          # an ATM kiosk
m.box("glow_cyan", (6.8, 1.3, 4.0), (7.8, 1.9, 4.03))
m.box("dark", (6.9, 0.9, 4.0), (7.7, 1.2, 4.04))
m.box("glow_warm", (6.6, 2.4, 3.0), (8.0, 2.5, 4.0))
truck(m, 7.0, 7.4, yaw=math.pi / 2, canvas=False, bed=3.0, body=hexc("e8ecee"))                                  # an armoured van
m.box("paint", (4.9, 1.1, 6.35), (7.2, 2.5, 8.45), bevel=0.1, seg=2, tint=hexc("c8ced0"))
for k in range(2):
    m.box("dark", (5.2 + k * 1.2, 1.9, 8.45), (5.8 + k * 1.2, 2.2, 8.48))
m.box("paint", (4.95, 1.4, 6.3), (7.15, 1.55, 6.33), tint=hexc("2f6f7e"))
for p in ((-6.5, 7.0), (-4.0, -10.0), (4.0, -10.0), (-8.5, 0.0), (9.0, -2.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-5.8, -4.6):
    m.box(STONE, (sx - 0.5, 0.13, 6.4), (sx + 0.5, 0.75, 7.4), bevel=0.04, seg=1)
    m.dome("leaf", (sx, 0.75, 6.9), 0.5, 0.45, 10, 3, tint=hexc("3f6e3c"))
for sx in (-1, 1):
    lamp(m, sx * 5.0, 1.8)
    bench(m, sx * 7.0, 2.0, math.pi / 2)
flagpole(m, -6.8, 3.0, 7.5)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, 0.0, 9.3, -4.6, 9.4, 9.8)
    forecourt(m, 9.0)
m.finish(out)
