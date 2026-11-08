"""The Tank Factory, modelled in Blender.   blender -b -P build_tank_factory.py -- <out.glb>

A heavy-vehicle works: a long brick assembly hall with a sawtooth roof of glazed north lights, a tall clerestory bay with a
gantry crane, big roller doors, chimney stacks with smoke, a loading apron where finished tanks wait (modelled hull, track,
road wheels, turret and gun), a test ramp and obstacle mound, a welding shop, a steel stockyard with plates and girders, fuel
and coolant tanks, a gate house and a double fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, lattice, slats, crate
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "tank_factory.glb"
m = Model("tank_factory")
rng = random.Random(91)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
BRICKC = (0.95, 0.88, 0.85)
OLIVE = hexc("55633f")
ORANGE = hexc("c8902a")


def tank(x, z, yaw, paint=OLIVE, gun_yaw=0.0):
    """Static apron tanks suppressed so real spawned ARM combat units remain 100% distinct."""
    return
    with m.frame((x, 0, z), yaw=yaw):
        for sx in (-1, 1):                                                    # tracks
            m.box("dark", (sx * 1.45 - 0.35, 0.3, -2.6), (sx * 1.45 + 0.35, 1.05, 2.6), bevel=0.15, seg=3)
            m.box("paint", (sx * 1.45 - 0.37, 1.0, -2.55), (sx * 1.45 + 0.37, 1.18, 2.55), bevel=0.04, seg=1, tint=paint)   # side skirt
            for k in range(6):
                m.pipe("dark", (sx * 1.45 - 0.3, 0.5, -2.1 + k * 0.84), (sx * 1.45 + 0.3, 0.5, -2.1 + k * 0.84), 0.33, 14)
                m.pipe(METAL, (sx * 1.45 - 0.31, 0.5, -2.1 + k * 0.84), (sx * 1.45 + 0.31, 0.5, -2.1 + k * 0.84), 0.15, 10)
            m.pipe("dark", (sx * 1.45 - 0.3, 0.8, 2.6), (sx * 1.45 + 0.3, 0.8, 2.6), 0.3, 14)
            m.pipe("dark", (sx * 1.45 - 0.3, 0.75, -2.7), (sx * 1.45 + 0.3, 0.75, -2.7), 0.3, 14)
        m.hull("paint", [(-1.3, 0.7, -2.9), (1.3, 0.7, -2.9), (-1.3, 0.7, 3.1), (1.3, 0.7, 3.1), (-1.15, 1.45, -2.8), (1.15, 1.45, -2.8),
                         (-1.15, 1.3, 1.6), (1.15, 1.3, 1.6), (-1.0, 1.0, 3.3), (1.0, 1.0, 3.3)], tint=paint)       # the hull with a sloped glacis
        m.box("paint", (-1.25, 1.2, -2.9), (1.25, 1.5, -1.4), bevel=0.05, seg=1, tint=paint)                          # engine deck
        for k in range(5):
            m.box("dark", (-0.8, 1.5, -2.7 + k * 0.28), (0.8, 1.53, -2.55 + k * 0.28))
        m.pipe("dark", (-0.9, 1.5, -2.95), (-0.9, 1.5, -2.85), 0.1, 8)
        with m.frame((0, 1.5, -0.2), yaw=gun_yaw):                                                                    # the turret
            m.hull("paint", [(-1.0, 0.0, -1.1), (1.0, 0.0, -1.1), (-1.0, 0.0, 1.1), (1.0, 0.0, 1.1), (-0.8, 0.75, -1.0), (0.8, 0.75, -1.0),
                             (-0.7, 0.75, 0.8), (0.7, 0.75, 0.8), (-0.5, 0.45, 1.5), (0.5, 0.45, 1.5)], tint=paint)
            m.box("paint", (-0.75, 0.2, 1.4), (0.75, 0.65, 1.7), bevel=0.06, seg=2, tint=paint)                       # the mantlet
            m.pipe("metal", (0.0, 0.45, 1.6), (0.0, 0.5, 4.8), 0.1, 12)
            m.pipe("dark", (0.0, 0.5, 4.5), (0.0, 0.5, 4.95), 0.13, 12)
            m.pipe("dark", (0.0, 0.5, 2.9), (0.0, 0.5, 3.4), 0.14, 12)
            m.cyl("dark", (0.45, 0.75, -0.4), 0.28, 0.12, 12)
            m.cyl("paint", (0.45, 0.87, -0.4), 0.3, 0.05, 12, tint=paint)
            m.pipe("dark", (-0.5, 0.75, 0.0), (-0.5, 1.3, 0.0), 0.02, 4)
            m.box("dark", (-0.6, 0.78, -0.3), (-0.4, 0.95, 0.1), bevel=0.02, seg=1)
            m.pipe("metal", (-0.4, 0.8, -0.9), (-0.4, 1.9, -0.9), 0.015, 4)
            for sx in (-1, 1):                                                                                          # stowage boxes on the turret sides
                m.box("dark", (sx * 1.0 - 0.1, 0.2, -1.0), (sx * 1.0 + 0.1, 0.6, -0.2), bevel=0.02, seg=1)


def stack(x, z, h, r, smoke=True):
    m.cyl("brick", (x, 0.1, z), r, h, 14, r2=r * 0.78, tint=(0.9, 0.82, 0.78))
    for y in (h * 0.4, h * 0.7, h * 0.95):
        m.tube(CONC, (x, y, z), r * (1.0 - 0.22 * y / h) + 0.04, r * (1.0 - 0.22 * y / h) - 0.02, 0.1, 14, tint=(0.6, 0.55, 0.5))
    m.tube("dark", (x, 0.1 + h, z), r * 0.78 + 0.06, r * 0.62, 0.15, 14)


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-9.0, 0.15, -0.5), (9.0, 0.16, 5.0))
m.box("asphalt", (-1.2, 0.15, 5.0), (1.2, 0.16, 9.4))
for k in range(9):
    m.box(CONC, (-8.4 + k * 2.1, 0.165, 2.0), (-7.8 + k * 2.1, 0.175, 2.06), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the assembly hall: x -8.6 .. 4.4, z -9.2 .. -2.2
X0, X1, Z0, Z1 = -8.6, 4.4, -9.2, -2.2
m.box(CONC, (X0 - 0.15, 0.1, Z0 - 0.15), (X1 + 0.15, 0.9, Z1 + 0.15), bevel=0.03, seg=1)
m.box("brick", (X0, 0.9, Z0), (X1, 6.0, Z1), bevel=0.02, seg=1, tint=BRICKC)
for k in range(24):
    m.box("dark", (X0, 1.0 + k * 0.2, Z1 - 0.005), (X1, 1.02 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))
for k in range(8):                                                                       # pilaster piers between bays
    px = X0 + k * (X1 - X0) / 7
    m.box("brick", (px - 0.25, 0.9, Z1), (px + 0.25, 6.2, Z1 + 0.22), bevel=0.02, seg=1, tint=(1.0, 0.92, 0.9))
m.box(CONC, (X0 - 0.2, 6.0, Z0 - 0.2), (X1 + 0.2, 6.25, Z1 + 0.25), bevel=0.03, seg=1)
# tall arched factory windows between the piers
for i in range(7):
    px = X0 + i * (X1 - X0) / 7
    wx = px + (X1 - X0) / 14
    pts = [(math.cos(math.pi * k / 8) * 0.55, 3.8 + math.sin(math.pi * k / 8) * 0.55) for k in range(9)]
    m.box("dark", (wx - 0.55, 2.2, Z1 - 0.02), (wx + 0.55, 3.8, Z1 + 0.02))
    m.hull("dark", [(wx + a, b, Z1 - 0.02) for a, b in pts] + [(wx + a, b, Z1 + 0.02) for a, b in pts])
    m.box(GLASS, (wx - 0.55, 2.2, Z1), (wx + 0.55, 3.8, Z1 + 0.05), tint=(1.4, 1.7, 1.9))
    m.hull(GLASS, [(wx + a, b, Z1) for a, b in pts] + [(wx + a, b, Z1 + 0.05) for a, b in pts], tint=(1.4, 1.7, 1.9))
    for q in (-0.25, 0.25):
        m.box("dark", (wx + q - 0.015, 2.2, Z1 + 0.05), (wx + q + 0.015, 4.2, Z1 + 0.08))
    m.box("dark", (wx - 0.55, 3.0, Z1 + 0.05), (wx + 0.55, 3.03, Z1 + 0.08))
    m.box(CONC, (wx - 0.7, 2.1, Z1), (wx + 0.7, 2.2, Z1 + 0.25), bevel=0.02, seg=1)
# the sawtooth roof: slopes rising along z, glazed north lights facing -z
NT = 5
for k in range(NT):
    zt0 = Z0 + k * (Z1 - Z0) / NT
    zt1 = zt0 + (Z1 - Z0) / NT
    m.hull(CLAD, [(X0 - 0.2, 6.25, zt0), (X1 + 0.2, 6.25, zt0), (X0 - 0.2, 6.25, zt1), (X1 + 0.2, 6.25, zt1), (X0 - 0.2, 7.5, zt0), (X1 + 0.2, 7.5, zt0)], tint=(0.7, 0.72, 0.75))
    m.box(GLASS, (X0 + 0.2, 6.3, zt0 + 0.0), (X1 - 0.2, 7.5, zt0 + 0.05), tint=(1.6, 1.8, 2.0))
    for j in range(9):
        xs = X0 + 0.2 + j * (X1 - X0 - 0.4) / 8
        m.box(DARK, (xs - 0.03, 6.3, zt0 - 0.01), (xs + 0.03, 7.5, zt0 + 0.07))
    m.pipe(METAL, (X0 - 0.2, 7.5, zt0), (X1 + 0.2, 7.5, zt0), 0.04, 5)
m.box("brick", (X0 - 0.1, 6.25, Z0 - 0.1), (X0 + 0.3, 7.6, Z1 + 0.1), bevel=0.02, seg=1, tint=BRICKC)      # gable ends
m.box("brick", (X1 - 0.3, 6.25, Z0 - 0.1), (X1 + 0.1, 7.6, Z1 + 0.1), bevel=0.02, seg=1, tint=BRICKC)
for k in range(3):
    fan(m, (X0 + 2.5 + k * 4.0, 7.55, Z0 + 1.3), 0.6)
stack(-6.5, -9.8, 14.0, 0.7)
stack(-4.4, -9.8, 12.0, 0.6)
# the clerestory bay on the right: taller, with a gantry crane
BX0, BX1 = 4.7, 9.2
m.box("brick", (BX0, 0.9, -9.2), (BX1, 9.0, -2.4), bevel=0.02, seg=1, tint=BRICKC)
m.box(CONC, (BX0 - 0.15, 0.1, -9.35), (BX1 + 0.15, 0.9, -2.25), bevel=0.03, seg=1)
m.box(CONC, (BX0 - 0.2, 9.0, -9.4), (BX1 + 0.2, 9.25, -2.2), bevel=0.03, seg=1)
for k in range(5):
    m.box(GLASS, (BX0 + 0.3 + k * 0.85, 6.0, -2.42), (BX0 + 1.0 + k * 0.85, 8.4, -2.38), tint=(1.4, 1.7, 1.9))
    m.box(CONC, (BX0 + 0.25 + k * 0.85, 5.9, -2.4), (BX0 + 1.05 + k * 0.85, 6.0, -2.3), bevel=0.01, seg=1)
m.box("dark", (BX0 + 0.5, 0.9, -2.42), (BX1 - 0.5, 5.2, -2.38))                                          # the big door
m.box(DARK, (BX0 + 0.55, 0.95, -2.38), (BX1 - 0.55, 5.15, -2.3), bevel=0.03, seg=1)
for q in range(14):
    m.box(METAL, (BX0 + 0.6, 1.1 + q * 0.29, -2.3), (BX1 - 0.6, 1.1 + q * 0.29 + 0.1, -2.26))
m.box("paint", (BX0 + 0.5, 5.3, -2.42), (BX1 - 0.5, 5.5, -2.2), tint=hexc("e0b020"))
m.box(CONC, (BX0 + 0.4, 5.5, -2.4), (BX1 - 0.4, 5.6, -2.3), bevel=0.01, seg=1)
for gx in (BX0 + 0.1, BX1 - 0.1):                                                                          # the crane rails and bridge
    m.box("paint", (gx - 0.08, 8.0, -9.0), (gx + 0.08, 8.1, -2.6), tint=ORANGE)
m.box("paint", (BX0, 8.1, -6.4), (BX1, 8.45, -5.8), bevel=0.03, seg=1, tint=ORANGE)
m.box(DARK, (6.2, 7.6, -6.5), (7.4, 8.1, -5.7), bevel=0.03, seg=1)
m.pipe(DARK, (6.8, 7.6, -6.1), (6.8, 5.5, -6.1), 0.02, 4)

# ------------------------------------------------------------------ finished tanks on the apron, a test ramp and mound
tank(-5.2, 1.6, 0.4)
tank(-1.4, 0.8, -0.3)
tank(3.2, 2.0, 0.9, gun_yaw=0.3)
m.hull(CONC, [(5.6, 0.15, -1.0), (9.0, 0.15, -1.0), (5.6, 0.15, 4.2), (9.0, 0.15, 4.2), (5.6, 1.6, -1.0), (9.0, 1.6, -1.0)], tint=(0.9, 0.85, 0.8))   # a test ramp
for k in range(6):
    m.box("hazard" if k % 2 == 0 else "dark", (5.6 + k * 0.57, 1.6 - 0.0, -1.0), (6.1 + k * 0.57, 1.64, -0.95))
def mound(x, z, rx, rz, h):
    def f(xx, zz):
        d = ((xx - x) / rx) ** 2 + ((zz - z) / rz) ** 2
        return -0.03 if d >= 1.0 else h * (1.0 - d) ** 0.7 + 0.07 * math.sin(xx * 3.0 + zz * 2.0) * (1.0 - d)
    m.grid("earth", x - rx, x + rx, z - rz, z + rz, f, int(rx * 5), int(rz * 5), base=0.1)
mound(-7.6, 5.8, 1.8, 2.4, 1.1)
mound(-4.6, 6.8, 1.5, 1.6, 0.7)

# ------------------------------------------------------------------ the welding shop, stockyard, tanks, offices
for k in range(6):                                                                                          # steel plates and girders
    m.box("metal", (5.6, 0.15 + k * 0.1, 6.0), (8.8, 0.25 + k * 0.1, 7.4), bevel=0.01, seg=1, tint=(0.9, 0.9, 0.95))
for k in range(4):
    m.box("paint", (5.6, 0.15, 7.6 + k * 0.4), (8.8, 0.45, 7.8 + k * 0.4), bevel=0.02, seg=1, tint=ORANGE if k % 2 == 0 else hexc("8a949a"))
for i in range(2):                                                                                          # fuel and coolant tanks on a bund
    m.cyl("paint", (-8.6 + i * 1.9, 0.5, 8.2), 0.8, 2.4, 20, tint=hexc("e8ecee") if i == 0 else hexc("8aa0b0"))
    m.dome("paint", (-8.6 + i * 1.9, 2.9, 8.2), 0.8, 0.35, 20, 4, tint=hexc("e8ecee") if i == 0 else hexc("8aa0b0"))
m.box(CLAD, (-0.9, 0.1, 6.2), (0.9, 2.5, 7.4), bevel=0.04, seg=1, tint=hexc("d8d4c0"))                       # the gate house
m.box(CONC, (-1.0, 2.5, 6.1), (1.0, 2.65, 7.5), bevel=0.03, seg=1)
m.box(GLASS, (-0.8, 1.1, 7.38), (0.8, 2.3, 7.44), tint=(1.6, 1.8, 2.0))
m.pipe(METAL, (1.0, 1.0, 6.8), (2.8, 1.0, 6.8), 0.05, 6)
for k in range(4):
    m.box("paint", (1.0 + k * 0.45, 0.95, 6.75), (1.25 + k * 0.45, 1.05, 6.85), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
truck(m, 2.6, 6.2, yaw=0.0, canvas=False, bed=3.4, body=hexc("2f6f9e"))                                  # a low-loader that moves the tanks
for p in ((-9.0, 3.0), (9.0, 3.0), (-9.0, -6.0), (9.0, -9.0), (0.0, 8.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 11.0, gate=(-3.0, 3.0), hazard_every=5, h=1.8)
flagpole(m, 2.0, 7.8, 8.0)
m.finish(out)
