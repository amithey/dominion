"""The Power Plant, modelled in Blender.   blender -b -P build_power_plant.py -- <out.glb>

A thermal station: a long turbine hall in brick with arched windows and a ribbed roof, a tall boiler house in steel cladding with
exposed ducting, two banded stacks that emit smoke (Smoke_Industry markers), two hyperbolic cooling towers on a basin with
steam, a coal heap with a conveyor gallery, a switchyard with a lattice gantry, transformers and insulators, a control building,
fuel tanks, pipes and walkways, a gate house and a double fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import fan, lattice, fence_poly, slats, vent_stack
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "power_plant.glb"
m = Model("power_plant")
rng = random.Random(97)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
STEEL = hexc("aeb6ba")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def cooling_tower(x, z, h=11.0):
    """A hyperbolic natural-draught cooling tower: a lathe of the hyperboloid profile, a lattice of inlets at the foot, a rim and steam."""
    prof = [(0.0, 0.0)]
    n = 14
    for i in range(n + 1):
        t = i / n
        r = 2.9 - 1.1 * math.sin(t * math.pi * 0.78) + 0.0
        prof.append((r, 0.8 + t * h))
    prof.append((2.1, 0.8 + h))
    for i in range(n, -1, -1):
        t = i / n
        r = 2.9 - 1.1 * math.sin(t * math.pi * 0.78) - 0.12
        prof.append((max(r, 0.05), 0.8 + t * h))
    prof.append((0.0, 0.8))
    m.lathe(CONC, (x, 0.1, z), prof, 28, tint=(1.15, 1.13, 1.1))
    for k in range(16):                                              # the inlet louvres round the foot
        a = math.tau * k / 16
        r0 = 2.9
        m.box("dark", (x + math.cos(a) * r0 - 0.25, 0.1, z + math.sin(a) * r0 - 0.25), (x + math.cos(a) * r0 + 0.25, 0.85, z + math.sin(a) * r0 + 0.25), yaw=-a, about=(x + math.cos(a) * r0, 0, z + math.sin(a) * r0))
    for k in range(3):                                               # horizontal ribs
        t = (k + 1) / 4
        r = 2.9 - 1.1 * math.sin(t * math.pi * 0.78)
        m.tube(CONC, (x, 0.9 + t * h, z), r + 0.03, r - 0.05, 0.12, 28, tint=(0.9, 0.9, 0.9))
    m.tube("dark", (x, 0.8 + h + 0.1, z), 2.15, 1.95, 0.1, 28)
    m.cyl("glow_red", (x + 2.05, 0.8 + h + 0.15, z), 0.07, 0.15, 8)
    m.cyl("glass", (x, 0.12, z), 2.85, 0.15, 28, tint=(0.8, 0.9, 1.0))          # the basin
    m.marker("Smoke_Industry_%d" % int(x * 3 + 20), (x, 0.8 + h + 0.2, z))


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-1.2, 0.15, 3.0), (1.2, 0.16, 9.4))
m.box("asphalt", (-9.0, 0.15, 3.0), (9.0, 0.16, 4.4))

# ------------------------------------------------------------------ the turbine hall: x -8.8 .. 1.2, z -8.4 .. -2.6
X0, X1, Z0, Z1 = -8.8, 1.2, -8.4, -2.6
m.box(CONC, (X0 - 0.15, 0.1, Z0 - 0.15), (X1 + 0.15, 0.9, Z1 + 0.15), bevel=0.03, seg=1)
m.box("brick", (X0, 0.9, Z0), (X1, 5.6, Z1), bevel=0.02, seg=1, tint=(0.95, 0.88, 0.85))
for k in range(22):
    m.box("dark", (X0, 1.0 + k * 0.2, Z1 - 0.005), (X1, 1.02 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))
for k in range(7):
    px = X0 + k * (X1 - X0) / 6
    m.box("brick", (px - 0.22, 0.9, Z1), (px + 0.22, 5.8, Z1 + 0.2), bevel=0.02, seg=1, tint=(1.0, 0.92, 0.9))
for i in range(6):
    wx = X0 + (i + 0.5) * (X1 - X0) / 6
    pts = [(math.cos(math.pi * k / 8) * 0.55, 3.4 + math.sin(math.pi * k / 8) * 0.55) for k in range(9)]
    m.box("dark", (wx - 0.55, 1.8, Z1 - 0.02), (wx + 0.55, 3.4, Z1 + 0.02))
    m.hull("dark", [(wx + a, b, Z1 - 0.02) for a, b in pts] + [(wx + a, b, Z1 + 0.02) for a, b in pts])
    m.box(GLASS, (wx - 0.55, 1.8, Z1), (wx + 0.55, 3.4, Z1 + 0.05), tint=(1.4, 1.7, 1.9))
    m.hull(GLASS, [(wx + a, b, Z1) for a, b in pts] + [(wx + a, b, Z1 + 0.05) for a, b in pts], tint=(1.4, 1.7, 1.9))
    m.box(CONC, (wx - 0.7, 1.7, Z1), (wx + 0.7, 1.8, Z1 + 0.25), bevel=0.02, seg=1)
    m.box("dark", (wx - 0.04, 1.8, Z1 + 0.05), (wx + 0.04, 4.0, Z1 + 0.08))
m.box(CONC, (X0 - 0.2, 5.6, Z0 - 0.2), (X1 + 0.2, 5.85, Z1 + 0.25), bevel=0.03, seg=1)
m.hull(CLAD, [(X0 - 0.3, 5.85, Z0 - 0.3), (X1 + 0.3, 5.85, Z0 - 0.3), (X0 - 0.3, 5.85, Z1 + 0.35), (X1 + 0.3, 5.85, Z1 + 0.35), (X0 - 0.3, 7.3, (Z0 + Z1) / 2), (X1 + 0.3, 7.3, (Z0 + Z1) / 2)], tint=(0.75, 0.78, 0.8))
for k in range(12):
    xx = X0 + 0.2 + k * (X1 - X0 - 0.4) / 11
    m.pipe(METAL, (xx, 5.85, Z0 - 0.3), (xx, 7.3, (Z0 + Z1) / 2), 0.02, 4)
    m.pipe(METAL, (xx, 5.85, Z1 + 0.35), (xx, 7.3, (Z0 + Z1) / 2), 0.02, 4)
m.box(DARK, (X0, 7.3, (Z0 + Z1) / 2 - 0.4), (X1, 7.6, (Z0 + Z1) / 2 + 0.4), bevel=0.03, seg=1)                  # a ridge vent
for k in range(10):
    m.box("dark", (X0 + 0.3 + k * 0.95, 7.3, (Z0 + Z1) / 2 + 0.4), (X0 + 0.6 + k * 0.95, 7.55, (Z0 + Z1) / 2 + 0.43))
# the boiler house behind: a tall steel-clad block with ducting and a walkway
BX0, BX1, BZ0, BZ1 = 1.6, 6.8, -9.2, -3.2
m.box(CLAD, (BX0, 0.9, BZ0), (BX1, 12.0, BZ1), bevel=0.04, seg=1, tint=hexc("aeb6ba"))
m.box(CONC, (BX0 - 0.15, 0.1, BZ0 - 0.15), (BX1 + 0.15, 0.9, BZ1 + 0.15), bevel=0.03, seg=1)
for k in range(10):
    m.box(CLAD, (BX0 + 0.2 + k * 0.5, 0.9, BZ1), (BX0 + 0.26 + k * 0.5, 12.0, BZ1 + 0.1), tint=hexc("c8ced0"))
for y in (3.0, 6.0, 9.0):
    m.box(DARK, (BX0 - 0.05, y, BZ1 - 0.02), (BX1 + 0.05, y + 0.12, BZ1 + 0.4), bevel=0.01, seg=1)
    for k in range(9):
        m.pipe(METAL, (BX0 + 0.2 + k * 0.6, y, BZ1 + 0.4), (BX0 + 0.2 + k * 0.6, y + 0.9, BZ1 + 0.4), 0.015, 4)
    m.pipe(METAL, (BX0 + 0.2, y + 0.9, BZ1 + 0.4), (BX1 - 0.2, y + 0.9, BZ1 + 0.4), 0.02, 4)
for sx in (BX0, BX1):
    m.box(CLAD, (sx - 0.05, 12.0, BZ0 - 0.1), (sx + 0.05, 12.4, BZ1 + 0.1), bevel=0.01, seg=1)
m.box(CONC, (BX0 - 0.2, 12.0, BZ0 - 0.2), (BX1 + 0.2, 12.3, BZ1 + 0.2), bevel=0.03, seg=1)
for q in range(4):
    m.box("glass", (BX0 + 0.4 + q * 1.2, 4.0, BZ1 - 0.02), (BX0 + 1.3 + q * 1.2, 4.9, BZ1 + 0.02), tint=(1.4, 1.7, 1.9))
m.pipe("paint", (BX0 + 0.8, 12.3, -6.2), (BX0 + 0.8, 14.4, -6.2), 0.5, 14, tint=hexc("aeb6ba"))                # flue breeching to the stacks
m.pipe("paint", (BX0 + 0.8, 14.4, -6.2), (BX0 - 2.8, 14.4, -9.4), 0.5, 14, tint=hexc("aeb6ba"))
# two banded stacks with smoke markers
for i, (sx, h, r) in enumerate(((-3.2, 18.0, 0.8), (-0.6, 15.5, 0.7))):
    sz = -9.6
    vent_stack(m, sx, sz, h, r)
    m.marker("Smoke_Industry_%d" % i, (sx, h + 0.4, sz))
# ------------------------------------------------------------------ cooling towers on the right
cooling_tower(6.9, -1.6, 11.0)
cooling_tower(6.9, -7.6, 9.5)

# ------------------------------------------------------------------ the coal yard and conveyor gallery
def heap(x, z, rx, rz, h):
    def f(xx, zz):
        d = ((xx - x) / rx) ** 2 + ((zz - z) / rz) ** 2
        return -0.03 if d >= 1.0 else h * (1.0 - d) ** 0.8 + 0.12 * noise(xx * 2, zz * 2) * (1.0 - d)
    m.grid("dark", x - rx, x + rx, z - rz, z + rz, f, int(rx * 5), int(rz * 5), base=0.1)
heap(-6.4, 1.4, 2.6, 2.0, 2.2)
heap(-3.2, 2.0, 1.6, 1.4, 1.2)
for k in range(8):                                                                                  # the conveyor gallery rising to the boiler house
    t = k / 7
    x = -6.4 + t * 8.0
    y = 2.6 + t * 4.8
    m.box(CLAD, (x - 0.5, y, -1.9), (x + 0.5, y + 0.9, -1.3), bevel=0.02, seg=1, tint=hexc("c8ced0"))
    m.pipe(METAL, (x, 0.1, -1.9), (x, y, -1.9), 0.04, 5)
    m.pipe(METAL, (x, 0.1, -1.3), (x, y, -1.3), 0.04, 5)
# ------------------------------------------------------------------ the switchyard with a gantry and transformers
for sx in (-9.0, -7.0, -5.0):
    m.box(CONC, (sx - 0.9, 0.1, 5.5), (sx + 0.9, 0.3, 7.5), bevel=0.02, seg=1)
    m.box(METAL, (sx - 0.7, 0.3, 5.7), (sx + 0.7, 1.7, 7.3), bevel=0.05, seg=2, tint=(0.8, 0.9, 0.85))
    for k in range(6):
        m.box(METAL, (sx - 0.6 + k * 0.24, 0.4, 7.3), (sx - 0.54 + k * 0.24, 1.5, 7.5), bevel=0.01, seg=1, tint=(0.75, 0.85, 0.8))
    for q in range(3):
        bx = sx - 0.4 + q * 0.4
        m.pipe("paint", (bx, 1.7, 6.2), (bx, 2.7, 6.2), 0.08, 8, tint=hexc("d9c9a8"))
        for s in range(4):
            m.cyl("paint", (bx, 1.9 + s * 0.22, 6.2), 0.14, 0.06, 10, tint=hexc("c8b890"))
for sx in (-9.4, -4.6):
    lattice(m, sx, 5.0, 6.0, 0.8, 0.1, 0.04)
m.pipe(DARK, (-9.4, 6.0, 5.0), (-4.6, 6.0, 5.0), 0.05, 5)
for k in range(4):
    m.pipe("paint", (-9.0 + k * 1.4, 5.9, 5.0), (-9.0 + k * 1.4, 5.2, 5.0), 0.05, 6, tint=hexc("d9c9a8"))
m.wire(METAL, [(-9.4, 6.2, 5.0), (-12.0, 4.5, 5.0)], 0.01, 4)
# ------------------------------------------------------------------ the control building, tanks, gate
m.box(CLAD, (2.4, 0.1, 4.8), (6.0, 3.6, 7.8), bevel=0.04, seg=1, tint=hexc("e0e2dc"))
m.box(CONC, (2.3, 3.6, 4.7), (6.1, 3.8, 7.9), bevel=0.03, seg=1)
for k in range(4):
    m.box(GLASS, (2.7 + k * 0.85, 1.4, 7.78), (3.4 + k * 0.85, 2.8, 7.84), tint=(1.4, 1.7, 1.9))
m.box("glow_cyan", (2.7, 3.0, 7.78), (5.9, 3.3, 7.8), tint=(0.5, 0.7, 0.9))
for i in range(2):
    m.cyl("paint", (7.4 + i * 1.8, 0.1, 5.8), 0.8, 2.6, 20, tint=hexc("e8ecee"))
    m.dome("paint", (7.4 + i * 1.8, 2.7, 5.8), 0.8, 0.35, 20, 4, tint=hexc("e8ecee"))
m.box(CLAD, (-0.9, 0.1, 6.6), (0.9, 2.5, 7.8), bevel=0.04, seg=1, tint=hexc("d8d4c0"))
m.box(CONC, (-1.0, 2.5, 6.5), (1.0, 2.65, 7.9), bevel=0.03, seg=1)
m.box(GLASS, (-0.8, 1.1, 7.78), (0.8, 2.3, 7.84), tint=(1.6, 1.8, 2.0))
m.pipe(METAL, (1.0, 1.0, 7.2), (2.2, 1.0, 7.2), 0.05, 6)
for k in range(3):
    m.box("paint", (1.0 + k * 0.4, 0.95, 7.15), (1.2 + k * 0.4, 1.05, 7.25), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
for p in ((-9.0, 2.5), (9.0, 4.0), (-9.0, -9.0), (9.0, -9.2), (0.0, 8.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 11.0, gate=(-1.6, 1.6), hazard_every=5, h=1.8)
flagpole(m, 3.0, 8.4, 8.0)
m.finish(out)
