"""The Food Depot (grain silo complex), modelled in Blender.   blender -b -P build_food_depot.py -- <out.glb>

A grain store: a row of corrugated steel silos with conical roofs, ladders, catwalks and aeration fans on a concrete base,
a tall concrete elevator tower with a conveyor gantry, a flat store barn with loading doors, a weighbridge with a cabin, a
grain truck being loaded, a tractor with a trailer, hay bales, sacks, a small dryer with stack, tanks, trees, gate and fence.
Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, slats, lattice
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "food_depot.glb"
m = Model("food_depot")
rng = random.Random(121)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
SILO = hexc("c9ced0")
GREEN = hexc("5a8a46")


def silo(x, z, r, h, cone=1.6, ladder=True):
    """A corrugated grain silo: a ring base, ribbed wall, a conical roof with a vent, a ladder with a cage, a door and an aeration fan."""
    m.cyl(CONC, (x, 0.1, z), r + 0.25, 0.4, 28, tint=(1.1, 1.1, 1.1))
    m.cyl("cladding", (x, 0.5, z), r, h, 28, tint=SILO)
    for k in range(int(h / 0.45)):                                           # corrugation ribs
        m.tube("cladding", (x, 0.6 + k * 0.45, z), r + 0.04, r - 0.01, 0.1, 28, tint=hexc("aab2b6"))
    for k in range(12):                                                      # vertical stiffeners
        a = math.tau * k / 12
        m.box("cladding", (x + math.cos(a) * r - 0.05, 0.5, z + math.sin(a) * r - 0.05), (x + math.cos(a) * r + 0.05, 0.5 + h, z + math.sin(a) * r + 0.05),
              yaw=-a, about=(x + math.cos(a) * r, 0, z + math.sin(a) * r), tint=hexc("b4bcc0"))
    m.cyl("cladding", (x, 0.5 + h, z), r + 0.1, cone, 28, r2=0.28, tint=hexc("b9c0c4"))                    # the cone roof
    m.cyl(METAL, (x, 0.5 + h + cone, z), 0.32, 0.25, 10)
    m.dome(METAL, (x, 0.5 + h + cone + 0.25, z), 0.34, 0.2, 10, 3)
    m.tube(DARK, (x, 0.5 + h - 0.05, z), r + 0.1, r - 0.02, 0.1, 28)                                       # the eaves ring
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        m.pipe("cladding", (x + math.cos(a) * 0.4, 0.5 + h + cone * 0.8, z + math.sin(a) * 0.4), (x + math.cos(a) * (r + 0.1), 0.5 + h, z + math.sin(a) * (r + 0.1)), 0.025, 4)
    if ladder:
        lx, lz = x + r * 0.7071 + 0.12, z + r * 0.7071 + 0.12
        for sx in (-0.2, 0.2):
            m.pipe(METAL, (lx + sx * 0.7, 0.5, lz - sx * 0.7), (lx + sx * 0.7, 0.5 + h, lz - sx * 0.7), 0.025, 5)
        for k in range(int(h / 0.35)):
            m.pipe(METAL, (lx - 0.14, 0.6 + k * 0.35, lz + 0.14), (lx + 0.14, 0.6 + k * 0.35, lz - 0.14), 0.015, 4)
        for k in range(1, int(h / 1.2)):                                       # cage hoops
            m.tube(METAL, (lx, 1.2 + k * 1.2, lz), 0.35, 0.33, 0.03, 10)
    a = -math.pi / 2 + 0.6                                                    # a hatch door and an aeration fan low on the wall
    m.box(DARK, (x + math.cos(a) * r - 0.3, 0.6, z + math.sin(a) * r - 0.3), (x + math.cos(a) * r + 0.3, 1.8, z + math.sin(a) * r + 0.3), yaw=-a, about=(x + math.cos(a) * r, 0, z + math.sin(a) * r))
    a2 = math.pi / 2 - 0.5
    m.cyl(METAL, (x + math.cos(a2) * (r + 0.4), 0.7, z + math.sin(a2) * (r + 0.4)), 0.35, 0.5, 12)
    m.pipe(METAL, (x + math.cos(a2) * (r + 0.4), 1.0, z + math.sin(a2) * (r + 0.4)), (x + math.cos(a2) * r, 1.4, z + math.sin(a2) * r), 0.1, 8)


def bale(x, z, yaw=0.0, y=0.13, tint=hexc("d8c470")):
    with m.frame((x, y, z), yaw=yaw):
        m.pipe("paint", (-0.6, 0.55, 0), (0.6, 0.55, 0), 0.55, 14, tint=tint)


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-9.0, 0.15, 1.6), (9.0, 0.16, 4.8))
m.box("asphalt", (-1.2, 0.15, 4.8), (1.2, 0.16, 9.4))

# ------------------------------------------------------------------ the silo row and the elevator tower
for i in range(4):
    silo(-7.0 + i * 3.0, -6.6, 1.35, 6.8 - (i % 2) * 0.6, ladder=(i % 2 == 0))
for i in range(2):
    silo(-5.5 + i * 3.0, -3.0, 1.0, 5.0, 1.2, ladder=False)
# the elevator tower: a tall concrete block with a cap and a conveyor gantry down to the store
TX, TZ = 4.0, -6.4
m.box(CONC, (TX - 1.2, 0.1, TZ - 1.2), (TX + 1.2, 11.0, TZ + 1.2), bevel=0.05, seg=1, tint=(0.95, 0.95, 0.98))
for k in range(8):
    m.box("dark", (TX - 1.2, 1.0 + k * 1.2, TZ + 1.19), (TX + 1.2, 1.03 + k * 1.2, TZ + 1.22), tint=(0.5, 0.5, 0.5))
for y in (3.0, 6.0, 9.0):
    m.box("dark", (TX - 0.35, y, TZ + 1.18), (TX + 0.35, y + 0.9, TZ + 1.24))
m.box(CONC, (TX - 1.4, 11.0, TZ - 1.4), (TX + 1.4, 11.3, TZ + 1.4), bevel=0.04, seg=1)
m.box(CLAD, (TX - 1.0, 11.3, TZ - 1.0), (TX + 1.0, 12.6, TZ + 1.0), bevel=0.04, seg=1, tint=hexc("b4bcc0"))
m.hull(CLAD, [(TX - 1.2, 12.6, TZ - 1.2), (TX + 1.2, 12.6, TZ - 1.2), (TX - 1.2, 12.6, TZ + 1.2), (TX + 1.2, 12.6, TZ + 1.2), (TX, 13.5, TZ)], tint=(0.7, 0.72, 0.75))
m.cyl("glow_red", (TX, 13.5, TZ), 0.07, 0.15, 8)
m.pipe(METAL, (TX, 13.6, TZ), (TX, 14.6, TZ), 0.03, 5)
m.box(CLAD, (-7.0, 8.4, -7.0), (TX - 1.2, 8.8, -6.2), bevel=0.02, seg=1, tint=hexc("c8ced0"))
for k in range(5):
    m.pipe(METAL, (-7.0 + k * 2.6, 8.4, -7.0), (-7.0 + k * 2.6, 6.6, -7.0), 0.04, 5)
    m.pipe(METAL, (-7.0 + k * 2.6, 8.4, -6.2), (-7.0 + k * 2.6, 6.6, -6.2), 0.04, 5)
m.box(METAL, (-7.0, 8.8, -6.9), (TX - 1.2, 8.86, -6.3))

# ------------------------------------------------------------------ the store barn on the right and the dryer
m.box(CONC, (6.0, 0.1, -8.8), (9.4, 0.7, -2.0), bevel=0.03, seg=1)
m.box(CLAD, (6.2, 0.7, -8.6), (9.2, 5.0, -2.2), bevel=0.03, seg=1, tint=hexc("c8cdd0"))
m.hull(CLAD, [(6.0, 5.0, -8.8), (9.4, 5.0, -8.8), (6.0, 5.0, -2.0), (9.4, 5.0, -2.0), (6.0, 6.2, -5.4), (9.4, 6.2, -5.4)], tint=(0.72, 0.75, 0.78))
for k in range(6):
    m.box(CLAD, (6.3 + k * 0.5, 0.7, -2.2), (6.36 + k * 0.5, 5.0, -2.16), tint=hexc("a8b0b4"))
m.box("dark", (6.6, 0.7, -2.22), (9.0, 3.8, -2.16))
for q in range(10):
    m.box(METAL, (6.65, 0.8 + q * 0.3, -2.16), (8.95, 0.88 + q * 0.3, -2.12))
m.box("paint", (6.6, 3.9, -2.22), (9.0, 4.2, -2.12), tint=GREEN)
m.box(CLAD, (-9.0, 0.1, 0.2), (-6.6, 3.6, 1.4), bevel=0.03, seg=1, tint=hexc("c8cdd0"))                          # a grain dryer
m.pipe(METAL, (-8.2, 3.6, 0.8), (-8.2, 6.2, 0.8), 0.18, 10)
m.cyl(DARK, (-8.2, 6.2, 0.8), 0.28, 0.1, 10)
m.marker("Smoke_Industry_0", (-8.2, 6.4, 0.8))
m.box("glow_green", (-6.6, 1.6, 0.6), (-6.56, 1.8, 0.8))

# ------------------------------------------------------------------ the weighbridge, a grain truck, a tractor, bales and sacks
m.box(CONC, (-1.6, 0.15, 2.4), (1.6, 0.25, 6.8), bevel=0.02, seg=1)
for k in range(8):
    m.box(METAL, (-1.5, 0.25, 2.5 + k * 0.5), (1.5, 0.28, 2.7 + k * 0.5))
m.box(CLAD, (2.2, 0.1, 5.2), (3.6, 2.4, 6.6), bevel=0.04, seg=1, tint=hexc("d8d4c0"))                              # the weighbridge cabin
m.box(CONC, (2.1, 2.4, 5.1), (3.7, 2.55, 6.7), bevel=0.03, seg=1)
m.box(GLASS, (2.3, 1.1, 6.58), (3.5, 2.2, 6.64), tint=(1.6, 1.8, 2.0))
for k in range(5):
    bale(-7.4 + k * 1.2, 7.0 if k % 2 == 0 else 6.6, rng.uniform(-0.3, 0.3))
for k in range(3):
    bale(6.4 + k * 1.2, 5.0, rng.uniform(-0.2, 0.2))
bale(7.0, 5.0, 0.2, y=1.2)
for r_ in range(3):
    for c in range(4 - r_):
        m.box("wood", (3.4 + c * 0.55 + r_ * 0.28, 0.13 + r_ * 0.32, 2.4), (3.9 + c * 0.55 + r_ * 0.28, 0.43 + r_ * 0.32, 3.1), bevel=0.06, seg=2, tint=hexc("d8c8a0"))
for i in range(2):                                                                                                  # two water/fuel tanks
    m.cyl("paint", (7.4 + i * 1.7, 0.1, 6.4), 0.7, 2.2, 18, tint=hexc("e8ecee"))
    m.dome("paint", (7.4 + i * 1.7, 2.3, 6.4), 0.7, 0.3, 18, 4, tint=hexc("e8ecee"))
# gate, lamps, trees, fence
for p in ((-9.0, 3.0), (9.0, 3.0), (-9.0, -9.0), (9.0, -9.2), (0.0, 8.6), (-4.0, -0.8), (4.0, -0.8)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
for p in ((-9.2, 5.0), (9.4, 8.0), (3.0, 8.6)):
    tree(m, p[0], p[1], 2.2, 1.0)
fence_poly(m, 11.0, gate=(-1.6, 1.6), hazard_every=5, h=1.6)
flagpole(m, 2.4, 8.2, 8.0)
m.finish(out)
