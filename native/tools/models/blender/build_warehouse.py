"""The Warehouse, modelled in Blender.   blender -b -P build_warehouse.py -- <out.glb>

A logistics warehouse: a long steel-framed shed in corrugated cladding with a brick base, a low-pitched gable roof with skylights
and roof vents, a row of loading-dock doors with bumpers, canopies and dock levellers, a high-bay side with a mezzanine office
and a lit sign, forklifts, pallets of boxes, containers on the apron, a truck at a bay, a gate house and a fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, slats, crate, container
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "warehouse.glb"
m = Model("warehouse")
rng = random.Random(101)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
TEAL = hexc("2f6f7e")
ORANGE = hexc("c8902a")
BOXES = [hexc("b89868"), hexc("a8845a"), hexc("c9a878"), hexc("98784a")]


def pallet_stack(x, z, rows=2, cols=2, high=2, yaw=0.0):
    with m.frame((x, 0, z), yaw=yaw):
        m.box("wood", (-0.62, 0.13, -0.5), (0.62, 0.27, 0.5), bevel=0.01, seg=1, tint=(0.9, 0.8, 0.65))
        for h in range(high):
            for r in range(rows):
                for c in range(cols):
                    t = BOXES[(r + c + h) % 4]
                    m.box("wood", (-0.6 + c * 0.6, 0.27 + h * 0.5, -0.48 + r * 0.48), (-0.02 + c * 0.6, 0.27 + h * 0.5 + 0.48, 0.0 + r * 0.48), bevel=0.02, seg=1, tint=t)


def forklift(x, z, yaw, load=True):
    return
    with m.frame((x, 0, z), yaw=yaw):
        m.box("paint", (-0.5, 0.25, -1.1), (0.5, 0.95, 0.6), bevel=0.08, seg=2, tint=hexc("e0b020"))
        m.box("paint", (-0.52, 0.3, -1.3), (0.52, 1.1, -0.6), bevel=0.1, seg=2, tint=hexc("b98a14"))
        for sx in (-0.45, 0.45):
            m.pipe(DARK, (sx, 0.25, 0.75), (sx, 1.9, 0.75), 0.04, 6)
            m.pipe(DARK, (sx, 0.95, -0.5), (sx, 2.0, -0.5), 0.03, 5)
            m.pipe(DARK, (sx, 1.0, 0.45), (sx, 2.0, 0.45), 0.03, 5)
            m.box(DARK, (sx - 0.05, 0.12, 0.8), (sx + 0.05, 0.2, 1.9), bevel=0.01, seg=1)
        m.box(DARK, (-0.5, 1.9, 0.7), (0.5, 1.96, 0.8))
        for k in range(5):
            m.box(DARK, (-0.5, 2.0, -0.5 + k * 0.24), (0.5, 2.03, -0.4 + k * 0.24))
        m.box(DARK, (-0.3, 0.95, -0.8), (0.3, 1.2, -0.3), bevel=0.03, seg=1)
        for sx in (-1, 1):
            m.pipe("dark", (sx * 0.4, 0.3, 0.3), (sx * 0.62, 0.3, 0.3), 0.3, 12)
            m.pipe("dark", (sx * 0.4, 0.22, -0.8), (sx * 0.58, 0.22, -0.8), 0.22, 12)
        m.cyl("glow_warm", (0, 2.03, -0.3), 0.07, 0.1, 8)
        if load:
            m.box("wood", (-0.55, 0.2, 0.85), (0.55, 0.32, 1.85), bevel=0.01, seg=1)
            for r in range(2):
                for c in range(2):
                    m.box("wood", (-0.5 + c * 0.5, 0.32, 0.9 + r * 0.45), (-0.02 + c * 0.5, 0.82, 1.32 + r * 0.45), bevel=0.02, seg=1, tint=BOXES[(r + c) % 4])


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-9.0, 0.15, -1.2), (9.0, 0.16, 4.6))
m.box("asphalt", (-1.2, 0.15, 4.6), (1.2, 0.16, 9.4))
for k in range(9):
    m.box(CONC, (-8.4 + k * 2.1, 0.165, 1.8), (-7.8 + k * 2.1, 0.175, 1.86), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the shed: x +-8.4, z -9.2 .. -2.0
X, Z0, Z1 = 8.4, -9.2, -2.0
m.box(CONC, (-X - 0.15, 0.1, Z0 - 0.15), (X + 0.15, 1.2, Z1 + 0.15), bevel=0.03, seg=1)
m.box("brick", (-X, 0.1, Z0), (X, 1.4, Z1), bevel=0.02, seg=1, tint=(0.95, 0.88, 0.85))                              # brick base
m.box(CLAD, (-X, 1.4, Z0), (X, 6.0, Z1), bevel=0.02, seg=1, tint=hexc("c8cdd0"))
for k in range(int(2 * X / 0.3)):                                                                                   # corrugations
    xx = -X + 0.15 + k * 0.3
    m.box(CLAD, (xx - 0.05, 1.4, Z1), (xx + 0.05, 6.0, Z1 + 0.045), tint=hexc("a8b0b4"))
    m.box(CLAD, (xx - 0.05, 1.4, Z0 - 0.045), (xx + 0.05, 6.0, Z0), tint=hexc("a8b0b4"))
for k in range(5):                                                                                                  # side bays
    for sx in (-1, 1):
        m.box(DARK, (sx * X - 0.05 if sx < 0 else sx * X, 1.4, Z0 + 0.3 + k * 1.3), (sx * X if sx < 0 else sx * X + 0.05, 6.0, Z0 + 0.4 + k * 1.3), tint=(0.8, 0.8, 0.8))
for k in range(9):                                                                                                  # steel columns on the front
    px = -X + k * (2 * X) / 8
    m.box("paint", (px - 0.14, 1.2, Z1), (px + 0.14, 6.2, Z1 + 0.18), bevel=0.01, seg=1, tint=hexc("5f6a70"))
m.box("paint", (-X - 0.1, 5.9, Z1), (X + 0.1, 6.15, Z1 + 0.25), bevel=0.02, seg=1, tint=hexc("5f6a70"))
m.box(CONC, (-X - 0.2, 6.15, Z0 - 0.2), (X + 0.2, 6.3, Z1 + 0.3), bevel=0.02, seg=1)
m.hull(CLAD, [(-X - 0.3, 6.3, Z0 - 0.3), (X + 0.3, 6.3, Z0 - 0.3), (-X - 0.3, 6.3, Z1 + 0.4), (X + 0.3, 6.3, Z1 + 0.4), (-X - 0.3, 7.6, (Z0 + Z1) / 2), (X + 0.3, 7.6, (Z0 + Z1) / 2)], tint=(0.72, 0.75, 0.78))
for k in range(int(2 * X / 0.6)):
    xx = -X + 0.15 + k * 0.6
    m.pipe(METAL, (xx, 6.3, Z0 - 0.3), (xx, 7.6, (Z0 + Z1) / 2), 0.02, 4)
    m.pipe(METAL, (xx, 6.3, Z1 + 0.4), (xx, 7.6, (Z0 + Z1) / 2), 0.02, 4)
m.pipe(METAL, (-X - 0.3, 7.6, (Z0 + Z1) / 2), (X + 0.3, 7.6, (Z0 + Z1) / 2), 0.07, 6)
for k in range(5):                                                                                                  # skylights
    sx0 = -6.5 + k * 3.0
    m.hull(GLASS, [(sx0, 6.55, Z1 - 1.2), (sx0 + 1.6, 6.55, Z1 - 1.2), (sx0, 6.55, Z1 - 0.2), (sx0 + 1.6, 6.55, Z1 - 0.2), (sx0, 6.95, Z1 - 1.2), (sx0 + 1.6, 6.95, Z1 - 1.2)], tint=(1.6, 1.9, 2.1))
    m.box(DARK, (sx0 - 0.04, 6.5, Z1 - 1.25), (sx0 + 1.64, 6.58, Z1 - 0.15), bevel=0.01, seg=1)
for k in range(6):                                                                                                  # roof vents
    vx = -7.0 + k * 2.8
    m.cyl(METAL, (vx, 6.6, -6.4), 0.3, 0.45, 10)
    m.cyl(DARK, (vx, 7.05, -6.4), 0.38, 0.06, 10)
for k in range(3):
    fan(m, (-5.0 + k * 5.0, 7.0, -8.0), 0.5)

# ------------------------------------------------------------------ the dock doors: eight bays with bumpers, canopies, levellers
for k in range(8):
    dx = -7.2 + k * 1.95
    m.box("dark", (dx - 0.8, 1.2, Z1 - 0.02), (dx + 0.8, 4.2, Z1 + 0.02))
    m.box(DARK, (dx - 0.85, 4.2, Z1), (dx + 0.85, 4.35, Z1 + 0.12), bevel=0.02, seg=1)
    for q in range(11):
        m.box(METAL, (dx - 0.75, 1.25 + q * 0.27, Z1 + 0.02), (dx + 0.75, 1.25 + q * 0.27 + 0.1, Z1 + 0.06))
    for sx in (-1, 1):
        m.box("dark", (dx + sx * 0.95 - 0.12, 0.7, Z1 + 0.0), (dx + sx * 0.95 + 0.12, 1.5, Z1 + 0.28), bevel=0.04, seg=1)           # bumpers
    m.box(DARK, (dx - 0.8, 1.15, Z1), (dx + 0.8, 1.25, Z1 + 0.35), bevel=0.01, seg=1)                                         # dock leveller
    m.box("paint", (dx - 0.85, 4.4, Z1), (dx + 0.85, 4.5, Z1 + 0.15), tint=ORANGE if k % 2 == 0 else TEAL)
    m.box("glow_warm" if k % 3 == 0 else "glow_green", (dx - 0.15, 4.6, Z1), (dx + 0.15, 4.75, Z1 + 0.1))
    m.box("paint", (dx - 0.18, 4.8, Z1), (dx + 0.18, 5.4, Z1 + 0.05), tint=hexc("f0eee4"))
m.box(CONC, (-8.4, 1.15, Z1), (8.4, 1.25, Z1 + 0.9), bevel=0.02, seg=1)                                                       # the loading platform
m.box(CONC, (-8.4, 0.15, Z1 + 0.0), (8.4, 1.15, Z1 + 0.9), bevel=0.03, seg=1, tint=(0.95, 0.95, 0.95))
# the lit sign over the left bays
m.box("paint", (-6.5, 5.5, Z1 + 0.25), (-1.5, 6.1, Z1 + 0.3), tint=TEAL)
m.box("glow_warm", (-6.3, 5.62, Z1 + 0.3), (-1.7, 5.98, Z1 + 0.34), tint=(0.9, 0.85, 0.7))

# ------------------------------------------------------------------ the apron: a truck at a bay, forklifts, pallets, containers
truck(m, -3.3, 4.0, yaw=math.pi, canvas=False, bed=5.2, body=hexc("a8322a"))
# Parked semi-trailer removed for clean dock apron
forklift(0.0, 2.6, 2.4)
forklift(4.4, 3.2, -0.9, load=False)
for p in ((-7.8, 0.2), (-6.8, 0.4), (-7.4, 1.4), (5.2, 0.2), (6.2, 0.4), (7.2, 0.3)):
    pallet_stack(p[0], p[1], 2, 2, 2, yaw=rng.uniform(-0.2, 0.2))
container(m, 7.6, 6.2, 0.0, hexc("2f5a78"), 2.6, 1.25, 1.25, y0=0.13)
container(m, 7.6, 7.6, 0.0, hexc("8a3a2e"), 2.6, 1.25, 1.25, y0=0.13)
container(m, 7.6, 6.9, 0.0, hexc("a8782a"), 2.6, 1.25, 1.25, y0=1.38)
# the gate house and fence
m.box(CLAD, (-0.9, 0.1, 6.6), (0.9, 2.5, 7.8), bevel=0.04, seg=1, tint=hexc("d8d4c0"))
m.box(CONC, (-1.0, 2.5, 6.5), (1.0, 2.65, 7.9), bevel=0.03, seg=1)
m.box(GLASS, (-0.8, 1.1, 7.78), (0.8, 2.3, 7.84), tint=(1.6, 1.8, 2.0))
m.pipe(METAL, (1.0, 1.0, 7.2), (2.4, 1.0, 7.2), 0.05, 6)
for k in range(3):
    m.box("paint", (1.0 + k * 0.45, 0.95, 7.15), (1.25 + k * 0.45, 1.05, 7.25), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
for p in ((-9.0, 3.0), (9.0, 3.0), (-9.0, -9.0), (9.0, -9.2), (0.0, 8.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 11.0, gate=(-1.6, 1.6), hazard_every=5, h=1.8)
flagpole(m, 3.2, 8.4, 8.0)
m.finish(out)
