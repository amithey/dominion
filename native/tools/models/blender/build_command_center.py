"""The Command Centre (command bunker), modelled in Blender.   blender -b -P build_command_center.py -- <out.glb>

A hardened headquarters: a low reinforced-concrete operations block half buried under an earth berm, with a stepped blast-door
entrance and a lit slit window band, a roof of antennas, a satellite dish, a radar mast and ventilation hoods, a communications
trailer, generators and fuel tanks behind a blast wall, a vehicle shelter with command vehicles, a helicopter pad, an armoured
gate with a guard bunker and sandbag posts, razor wire and a double fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, dish, radome, lattice, fence_poly, slats, watch_tower, hazard_ring
from bl_civic import lamp, flagpole

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "command_center.glb"
m = Model("command_center")
rng = random.Random(111)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
OLIVE = hexc("55633f")
GREEN = hexc("5a8a46")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def berm(x0, x1, z0, z1, h, fx=0.0):
    """An earth berm banked against a wall: a height field sloping away from the wall at the +z side."""
    def f(x, z):
        u = (x - (x0 + x1) / 2) / ((x1 - x0) / 2)
        v = (z - z0) / (z1 - z0)
        if abs(u) >= 1.0 or v <= 0.0 or v >= 1.0:
            return -0.03
        prof = (1.0 - u * u) ** 0.5 * min(1.0, (1.0 - v) * 1.6) ** 0.8
        return h * prof + 0.1 * noise(x * 2, z * 2) * prof
    m.grid("turf", x0, x1, z0, z1, f, int((x1 - x0) * 4), int((z1 - z0) * 4), base=0.1, tint=GREEN)


def bag_row(x0, x1, z, courses=3):
    n = int((x1 - x0) / 0.42)
    for c in range(courses):
        off = 0.0 if c % 2 == 0 else 0.2
        for k in range(n - (c % 2)):
            x = x0 + 0.2 + off + k * 0.42
            t = rng.choice([(1.0, 0.95, 0.8), (0.92, 0.88, 0.72), (1.05, 1.0, 0.85)])
            m.box("sandbag", (x - 0.2, 0.15 + c * 0.2, z - 0.15), (x + 0.2, 0.15 + c * 0.2 + 0.2, z + 0.15), bevel=0.06, seg=2, yaw=rng.uniform(-0.05, 0.05), tint=t)


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-2.2, 0.15, -1.5), (2.2, 0.16, 9.4))
m.box("asphalt", (-9.0, 0.15, 1.5), (9.0, 0.16, 3.6))
for k in range(8):
    m.box(CONC, (-0.05, 0.165, 4.4 + k * 0.6), (0.05, 0.17, 4.7 + k * 0.6), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the operations block: x +-5.4, z -8.8 .. -2.4, 4 high
X, Z0, Z1, H = 5.4, -8.8, -2.4, 4.0
m.box(CONC, (-X - 0.2, 0.1, Z0 - 0.2), (X + 0.2, 0.7, Z1 + 0.2), bevel=0.04, seg=1)
m.box(CONC, (-X, 0.7, Z0), (X, H, Z1), bevel=0.05, seg=1, tint=(0.82, 0.82, 0.86))
for k in range(9):                                                                          # formwork seams and tie holes
    m.box("dark", (-X, 1.0 + k * 0.33, Z1 - 0.005), (X, 1.012 + k * 0.33, Z1 + 0.012), tint=(0.5, 0.5, 0.5))
for k in range(9):
    for r_ in range(3):
        m.cyl("dark", (-X + 0.7 + k * 1.15, 1.2 + r_ * 0.9, Z1 - 0.002), 0.03, 0.03, 6)
m.box(CONC, (-X - 0.3, H, Z0 - 0.3), (X + 0.3, H + 0.45, Z1 + 0.3), bevel=0.06, seg=2)                 # a heavy roof slab
m.box(CONC, (-X - 0.1, H + 0.45, Z0 - 0.1), (X + 0.1, H + 0.7, Z1 + 0.1), bevel=0.04, seg=1, tint=(0.9, 0.9, 0.92))
m.box("gravel", (-X, H + 0.7, Z0), (X, H + 0.74, Z1), tint=(0.9, 0.9, 0.9))
for k in range(9):                                                                          # the lit slit band
    m.box("dark", (-X + 0.5 + k * 1.1, 3.0, Z1 - 0.01), (-X + 1.4 + k * 1.1, 3.4, Z1 + 0.05))
    m.box("glow_cyan", (-X + 0.55 + k * 1.1, 3.05, Z1 + 0.03), (-X + 1.35 + k * 1.1, 3.35, Z1 + 0.07), tint=(0.6, 0.8, 0.9))
# side and rear earth berms
berm(-X - 3.4, -X + 0.4, -9.6, -1.2, 3.3)
berm(X - 0.4, X + 3.4, -9.6, -1.2, 3.3)
def rear(x, z):
    u = x / (X + 3.0)
    if abs(u) >= 1.0 or z < -9.8 or z > Z0 + 0.2:
        return -0.03
    return 3.4 * (1.0 - u * u) ** 0.5 * min(1.0, (z + 9.8) / 1.4 if z < -8.4 else 1.0) + 0.1 * noise(x * 2, z * 2)
m.grid("turf", -X - 3.0, X + 3.0, -9.8, Z0 + 0.2, rear, int((2 * X + 6) * 3.5), 6, base=0.1, tint=GREEN)

# ------------------------------------------------------------------ the stepped blast-door entrance
EX = 0.0
m.box(CONC, (EX - 2.3, 0.1, Z1), (EX + 2.3, 3.4, Z1 + 1.2), bevel=0.05, seg=1, tint=(1.0, 1.0, 1.04))
m.box("dark", (EX - 1.4, 0.1, Z1 + 0.5), (EX + 1.4, 2.8, Z1 + 1.22))
m.box(DARK, (EX - 1.3, 0.12, Z1 + 0.9), (EX - 0.03, 2.6, Z1 + 1.1), bevel=0.04, seg=1)               # two heavy leaves
m.box(DARK, (EX + 0.03, 0.12, Z1 + 0.9), (EX + 1.3, 2.6, Z1 + 1.1), bevel=0.04, seg=1)
for sx in (-1, 1):
    for y in (0.6, 1.4, 2.2):
        m.box(METAL, (EX + sx * 0.65 - 0.5, y, Z1 + 1.1), (EX + sx * 0.65 + 0.5, y + 0.07, Z1 + 1.14), bevel=0.01, seg=1)
    m.cyl(METAL, (EX + sx * 0.18, 1.3, Z1 + 1.1), 0.12, 0.05, 10)
m.box("hazard", (EX - 1.3, 2.7, Z1 + 1.1), (EX + 1.3, 2.85, Z1 + 1.15))
m.box("glow_warm", (EX - 0.25, 3.0, Z1 + 1.1), (EX + 0.25, 3.12, Z1 + 1.3))
m.box("paint", (EX - 0.6, 3.5, Z1 + 0.02), (EX + 0.6, 3.9, Z1 + 0.06), tint=hexc("f0eee4"))
for sx in (-1, 1):
    m.box(CONC, (EX + sx * 2.5 - 0.5, 0.1, Z1 + 0.0), (EX + sx * 2.5 + 0.5, 1.6, Z1 + 2.8), bevel=0.04, seg=1)   # blast walls either side of the approach
steps_z = Z1 + 1.2
for k in range(3):
    m.box(CONC, (EX - 1.6 - k * 0.1, 0.1, steps_z + k * 0.35), (EX + 1.6 + k * 0.1, 0.1 + 0.2 * (3 - k), steps_z + (k + 1) * 0.35), bevel=0.02, seg=1)

# ------------------------------------------------------------------ the roof: antennas, a dish, a radar mast, hoods
RY = H + 0.74
dish(m, (-3.4, RY, -5.5), 1.0, 0.6, 0.9)
radome(m, (3.2, RY, -5.2), 1.0)
lattice(m, 0.0, -6.8, 9.0, 0.9, RY, 0.04)
for y, w in ((RY + 3.0, 1.6), (RY + 5.0, 1.2), (RY + 7.0, 0.8)):
    m.pipe(METAL, (-w, y, -6.8), (w, y, -6.8), 0.03, 4)
m.pipe(METAL, (0.0, RY + 9.0, -6.8), (0.0, RY + 11.0, -6.8), 0.03, 5, r2=0.012)
m.cyl("glow_red", (0.0, RY + 11.0, -6.8), 0.08, 0.18, 8)
for gx, gz in ((-3.0, -4.2), (3.0, -4.2), (0.0, -9.0)):
    m.wire(METAL, [(0.0, RY + 8.0, -6.8), (gx, RY, gz)], 0.008, 4)
for k in range(4):                                                                          # whip antennas
    m.pipe(METAL, (-1.5 + k * 0.4, RY, -4.4), (-1.5 + k * 0.4, RY + 2.0 + 0.5 * (k % 2), -4.4), 0.012, 4)
for k in range(3):                                                                          # ventilation hoods
    m.box(CONC, (-4.4 + k * 1.2, RY, -3.4), (-3.5 + k * 1.2, RY + 0.9, -2.8), bevel=0.04, seg=1)
    m.box("dark", (-4.3 + k * 1.2, RY + 0.2, -2.82), (-3.6 + k * 1.2, RY + 0.7, -2.78))
    m.box(DARK, (-4.5 + k * 1.2, RY + 0.9, -3.5), (-3.4 + k * 1.2, RY + 1.0, -2.7), bevel=0.02, seg=1)
for k in range(2):
    fan(m, (2.4 + k * 1.3, RY + 0.4, -3.2), 0.4)
    m.box(DARK, (2.0 + k * 1.3, RY, -3.6), (2.8 + k * 1.3, RY + 0.4, -2.8), bevel=0.02, seg=1)

# ------------------------------------------------------------------ behind a blast wall: generators and tanks (left), a vehicle shelter (right)
m.box(CONC, (-9.0, 0.1, 3.8), (-3.4, 1.8, 4.1), bevel=0.04, seg=1)
for k in range(6):
    m.box(CONC, (-9.0 + k * 0.95, 1.8, 3.8), (-8.4 + k * 0.95, 2.0, 4.1), bevel=0.02, seg=1)
for i in range(2):
    m.box(CLAD, (-8.8 + i * 2.7, 0.1, 4.6), (-6.6 + i * 2.7, 2.1, 6.4), bevel=0.04, seg=1, tint=OLIVE)
    slats(m, -8.5 + i * 2.7, -6.9 + i * 2.7, 0.4, 1.7, 6.4, tint=hexc("dfe4e6"))
    m.pipe(DARK, (-7.7 + i * 2.7, 2.1, 5.2), (-7.7 + i * 2.7, 3.4, 5.2), 0.1, 8)
    m.cyl(DARK, (-7.7 + i * 2.7, 3.4, 5.2), 0.15, 0.07, 8)
for i in range(2):
    m.pipe("paint", (-7.2, 0.65, 6.7 + i * 0.8), (-5.0, 0.65, 6.7 + i * 0.8), 0.45, 18, tint=OLIVE)
m.box(CLAD, (4.0, 3.0, 4.6), (9.0, 3.2, 8.4), bevel=0.03, seg=1, tint=OLIVE)                    # a vehicle shelter, a roof on posts
for px in (4.2, 8.8):
    for pz in (4.8, 8.2):
        m.pipe(METAL, (px, 0.13, pz), (px, 3.0, pz), 0.07, 8)
# ------------------------------------------------------------------ the guard bunker, sandbag posts, gate, razor wire, fence
m.box(CONC, (2.6, 0.1, 7.0), (4.4, 2.0, 8.6), bevel=0.05, seg=1)
m.box(CONC, (2.5, 2.0, 6.9), (4.5, 2.25, 8.7), bevel=0.04, seg=1)
m.box("dark", (2.8, 1.1, 8.58), (4.2, 1.5, 8.64))
m.box("glow_warm", (3.2, 1.9, 8.6), (3.8, 1.97, 8.7))
bag_row(-5.2, -1.4, 6.9)
bag_row(1.4, 2.4, 6.9, 2)
m.pipe(METAL, (2.4, 1.0, 7.8), (0.2, 1.0, 7.8), 0.05, 6)
for k in range(4):
    m.box("paint", (2.2 - k * 0.5, 0.95, 7.75), (1.95 - k * 0.5, 1.05, 7.85), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
watch_tower(m, 8.4, -6.0, 5.2)
watch_tower(m, -8.4, -6.0, 5.2)
for p in ((-9.0, 2.5), (9.0, 2.5), (-3.2, 8.8), (3.2, 8.8), (0.0, -9.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 10.4, gate=(-2.4, 2.4), hazard_every=5, h=1.7)
fence_poly(m, 11.5, gate=(-2.4, 2.4), hazard_every=0, h=2.0)
flagpole(m, -2.0, 7.4, 8.0)
m.finish(out)
