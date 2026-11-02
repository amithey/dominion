"""The Fusion Cell (targeting fusion centre), modelled in Blender.   blender -b -P build_fusion_cell.py -- <out.glb>

A hardened, earth-bermed operations block whose long front is a wall of lit screens, a roof of radomes and true concave
dishes round a sensor mast, a park of corrugated communications containers with antennas, a generator, a command
vehicle at the door, a guard booth with a barrier and a perimeter fence leaning outward. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import lattice, fence, truck, fan, dish, radome, container

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "fusion_cell.glb"
m = Model("fusion_cell")
rng = random.Random(9)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
GREEN = hexc("5f8d4a")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def mound(cx, cz, rx, rz, h):
    def f(x, z):
        d = ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2
        return -0.03 if d >= 1.0 else h * (1.0 - d) ** 0.7 + 0.1 * noise(x, z) * (1.0 - d)
    m.grid("turf", cx - rx, cx + rx, cz - rz, cz + rz, f, int(rx * 5), int(rz * 5), base=0.1, tint=GREEN)


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("pavers", (-9.0, 0.1, 0.4), (9.0, 0.14, 7.0))
m.box("gravel", (-9.0, 0.1, -8.0), (9.0, 0.16, -4.6))

# ------------------------------------------------------------------ the operations block, 11 x 5 x 4, a lit screen wall in front
BZ, W, D = -2.0, 11.0, 5.0
z0 = BZ + D / 2
m.box(CONC, (-W / 2, 0.1, BZ - D / 2), (W / 2, 4.0, z0), bevel=0.05)
m.box(CONC, (-W / 2 - 0.15, 4.0, BZ - D / 2 - 0.15), (W / 2 + 0.15, 4.3, z0 + 0.15), bevel=0.06)
m.box("gravel", (-W / 2, 4.3, BZ - D / 2), (W / 2, 4.35, z0))
for k in range(7):                                                                       # panel joints on the front
    m.box("dark", (-W / 2 + 0.7 + k * 1.6 - 0.03, 0.4, z0), (-W / 2 + 0.7 + k * 1.6 + 0.03, 2.95, z0 + 0.03))
m.box("dark", (-W / 2, 3.0, z0), (W / 2, 3.15, z0 + 0.06))
for k in range(8):                                                                       # the screen wall: panels of varied brightness
    x0 = -W / 2 + 0.4 + k * 1.3
    m.box("glow_cyan" if rng.random() > 0.4 else "glow_dim", (x0, 3.2, z0 + 0.02), (x0 + 1.1, 3.9, z0 + 0.07))
    m.box("dark", (x0 + 0.1, 3.3, z0 + 0.065), (x0 + 1.0, 3.32, z0 + 0.085))             # a scan line
for k in range(9):
    m.box(METAL, (-W / 2 + 0.35 + k * 1.3, 3.15, z0), (-W / 2 + 0.45 + k * 1.3, 3.95, z0 + 0.1), bevel=0.01, seg=1)
m.box("dark", (-1.1, 0.1, z0 - 0.02), (1.1, 2.6, z0 + 0.06))                            # the blast door in a recess
m.box(DARK, (-0.95, 0.1, z0 + 0.06), (0.95, 2.4, z0 + 0.14), bevel=0.04, seg=1)
for k in range(5):
    m.hull("hazard" if k % 2 == 0 else "dark", [(-0.85 + k * 0.38, 0.15, z0 + 0.15), (-0.7 + k * 0.38, 0.15, z0 + 0.15), (-0.7 + k * 0.38, 2.3, z0 + 0.15), (-0.85 + k * 0.38, 2.3, z0 + 0.15),
                                                (-0.85 + k * 0.38, 0.15, z0 + 0.17), (-0.7 + k * 0.38, 0.15, z0 + 0.17), (-0.7 + k * 0.38, 2.3, z0 + 0.17), (-0.85 + k * 0.38, 2.3, z0 + 0.17)])
m.box("glow_warm", (-0.2, 2.7, z0 + 0.0), (0.2, 2.8, z0 + 0.1))
m.box(CONC, (-1.4, 0.1, z0 + 0.1), (1.4, 0.22, z0 + 1.1), bevel=0.02, seg=1)
mound(-W / 2 - 0.1, BZ, 2.3, 2.5, 2.2)                                                    # earth banked against the sides and back
mound(W / 2 + 0.1, BZ, 2.3, 2.5, 2.2)
mound(0.0, BZ - D / 2 - 0.3, 4.6, 2.2, 2.2)

# ------------------------------------------------------------------ the roof: radomes, dishes, a sensor mast, a cable tray, fans
R = 4.35
radome(m, (-3.6, R, BZ + 0.2), 1.35)
radome(m, (-0.6, R, BZ - 1.2), 0.8)
radome(m, (1.0, R, BZ + 1.4), 0.7)
dish(m, (3.4, R, BZ - 0.9), 1.1, 0.5, 0.9)
dish(m, (4.9, R, BZ + 1.3), 0.8, -0.7, 0.8)
dish(m, (-5.0, R, BZ - 1.6), 0.7, 2.4, 0.7)
lattice(m, 1.8, BZ - 1.9, 6.5, 0.7, R, 0.04)
for y in (7.2, 8.4, 9.6):
    m.pipe(METAL, (1.0, R + y - 3.4, BZ - 1.9), (2.6, R + y - 3.4, BZ - 1.9), 0.03, 4)
m.pipe(METAL, (1.8, R + 6.5, BZ - 1.9), (1.8, R + 7.8, BZ - 1.9), 0.025, 5)
m.cyl("glow_red", (1.8, R + 7.8, BZ - 1.9), 0.08, 0.2, 8)
for gx, gz in ((0.3, BZ - 3.0), (3.3, BZ - 3.0), (1.8, BZ - 0.6)):
    m.wire(METAL, [(1.8, R + 5.5, BZ - 1.9), (gx, R, gz)], 0.007)
m.box(METAL, (-2.0, R, BZ + 1.6), (0.2, R + 0.5, BZ + 2.2), bevel=0.03, seg=1)             # the cable tray
for k in range(6):
    m.box("dark", (-1.9 + k * 0.35, R + 0.5, BZ + 1.6), (-1.85 + k * 0.35, R + 0.55, BZ + 2.2))
for k in range(2):
    fan(m, (5.2 - k * 1.5, R + 0.55, BZ - 1.4), 0.35)
    m.box(DARK, (5.2 - k * 1.5 - 0.5, R, BZ - 1.9), (5.2 - k * 1.5 + 0.5, R + 0.55, BZ - 0.9), bevel=0.03, seg=1)

# ------------------------------------------------------------------ the communications yard: containers with antennas, a feeder
for i in range(3):
    z = 2.4 + i * 1.5
    container(m, -6.9, z + 0.6, 0.0, hexc("c8ccce") if i != 1 else hexc("6f7a58"), 2.6, 1.25, 1.8)
    m.box("glow_green", (-5.62, 1.4, z + 0.5), (-5.58, 1.55, z + 0.7))
    m.pipe(METAL, (-7.4, 2.0, z + 0.6), (-7.4, 3.6, z + 0.6), 0.03, 5)
    m.pipe(DARK, (-7.7, 3.6, z + 0.6), (-7.1, 3.6, z + 0.6), 0.03, 4)
m.wire("paint", [(-5.5, 0.4, 3.0), (-3.0, 0.3, 2.0), (-2.2, 0.3, 0.8)], 0.07, 8)
m.box(CLAD, (5.4, 0.1, 3.0), (8.2, 2.1, 4.8), bevel=0.04, seg=1)                          # the generator
m.box(CONC, (5.3, 2.1, 2.9), (8.3, 2.22, 4.9), bevel=0.03, seg=1)
for k in range(4):
    m.box("dark", (5.6 + k * 0.65, 0.4, 2.97), (5.66 + k * 0.65, 1.9, 3.0))
m.pipe(DARK, (7.7, 2.22, 3.6), (7.7, 3.6, 3.6), 0.12, 8)
m.cyl(DARK, (7.7, 3.6, 3.6), 0.17, 0.08, 8)
m.box("glow_green", (5.3, 1.4, 3.8), (5.34, 1.6, 4.0))
truck(m, 3.6, 5.2, yaw=math.pi / 2, canvas=False, bed=2.8)                                # the command vehicle
m.box("paint", (2.1, 1.1, 4.3), (4.7, 2.3, 6.1), bevel=0.08, seg=2, tint=hexc("4c5a38"))
m.pipe(METAL, (3.4, 2.3, 5.2), (3.4, 3.1, 5.2), 0.03, 5)
dish(m, (2.6, 2.3, 5.2), 0.35, 0.3, 0.7)

# ------------------------------------------------------------------ guard booth and barrier, floodlights, fence, trees
m.box(CLAD, (-3.6, 0.1, 6.0), (-2.2, 2.4, 7.2), bevel=0.04, seg=1)
m.box(CONC, (-3.7, 2.4, 5.9), (-2.1, 2.52, 7.3), bevel=0.03, seg=1)
m.box(GLASS, (-3.5, 1.1, 7.18), (-2.3, 2.2, 7.24))
m.pipe(METAL, (-2.2, 1.0, 6.6), (-0.2, 1.0, 6.6), 0.05, 6)
for k in range(4):
    m.box("paint", (-2.2 + k * 0.5, 0.95, 6.55), (-1.95 + k * 0.5, 1.05, 6.65), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
for p in ((-8.6, 5.4), (8.6, 5.4), (8.6, -4.4), (-8.6, -4.4), (0.0, 8.4)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.2, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.2, p[1] - 0.17), (p[0] + 0.45, 5.3, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.17, p[1] - 0.14), (p[0] + 0.4, 5.2, p[1] + 0.14))
fence(m, -9.0, 9.0, -7.0, 7.0, gap=(-2.5, 2.5, 7.0))
for t in ((-9.2, -6.2), (9.2, -6.0)):
    m.cyl("wood", (t[0], 0.1, t[1]), 0.2, 1.5, 7, r2=0.13)
    m.dome("leaf", (t[0], 1.4, t[1]), 1.1, 1.1, 10, 4, tint=hexc("3f6e3c"))
m.pipe(METAL, (-1.0, 0.1, 7.6), (-1.0, 6.6, 7.6), 0.05, 6)                                # the flag
m.box("banner", (-0.98, 5.3, 7.6), (-0.96, 6.4, 8.5))

m.finish(out)
