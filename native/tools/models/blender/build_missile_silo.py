"""The Missile Silo, modelled in Blender.   blender -b -P build_missile_silo.py -- <out.glb>

Two launch cells (one open with its missile raised against a service tower, one closed under its sliding blast door),
a hardened control centre banked with earth, cable trenches, fuel and oxidiser tanks with a pump house, a generator
shed and transformer, a support truck, a guard tower and a double-wire security fence with a gate. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import slats, lattice, hazard_ring, fence, truck

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "missile_silo.glb"
m = Model("missile_silo")
rng = random.Random(3)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
WHITE = hexc("e8ecee")
LIGHT = hexc("dfe4e6")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def silo_cell(cx, cz, open_):
    c = (cx, 0, cz)
    m.tube(CONC, (cx, 0.1, cz), 3.1, 2.3, 0.6, 32)                                   # the concrete collar round the well
    m.cyl("dark", (cx, 0.1, cz), 2.3, 0.02, 32)                                       # the shaft, dark
    m.tube(METAL, (cx, 0.7, cz), 2.6, 2.3, 0.1, 32)                                   # steel coaming
    hazard_ring(m, c, 2.62, 2.78, 0.7, 0.76, 28)
    for k in range(8):                                                                # inset lamps round the rim
        a = math.tau * k / 8.0 + 0.2
        m.box("glow_warm", (cx + math.cos(a) * 2.95 - 0.09, 0.58, cz + math.sin(a) * 2.95 - 0.09), (cx + math.cos(a) * 2.95 + 0.09, 0.66, cz + math.sin(a) * 2.95 + 0.09))
    for sz in (-1.55, 1.55):                                                          # the rails the door slides on
        m.pipe(METAL, (cx - 6.4, 0.9, cz + sz), (cx + 2.4, 0.9, cz + sz), 0.09, 8)
        m.box(CONC, (cx - 6.4, 0.1, cz + sz - 0.2), (cx - 6.0, 0.8, cz + sz + 0.2), bevel=0.04, seg=1)
        for px in (-6.0, -3.0, 0.0, 2.0):
            m.box(CONC, (cx + px - 0.12, 0.1, cz + sz - 0.12), (cx + px + 0.12, 0.82, cz + sz + 0.12), bevel=0.03, seg=1)
    dx = cx - 3.1 if open_ else cx
    m.cyl(METAL, (dx, 0.92, cz), 2.55, 0.3, 32, tint=(0.9, 0.9, 0.95))                  # the blast door, a thick steel disc
    m.tube(DARK, (dx, 1.2, cz), 2.55, 2.3, 0.06, 32)
    hazard_ring(m, (dx, 0, cz), 2.3, 2.5, 1.22, 1.27, 24)
    for k in range(6):                                                                # ribs across the door
        a = math.pi * k / 6.0
        d = (math.cos(a), math.sin(a))
        m.pipe(METAL, (dx - d[0] * 2.25, 1.27, cz - d[1] * 2.25), (dx + d[0] * 2.25, 1.27, cz + d[1] * 2.25), 0.06, 6)
    m.cyl(DARK, (dx, 1.2, cz), 0.38, 0.2, 12)
    m.cyl(METAL, (dx, 1.4, cz), 0.2, 0.06, 10)
    for sz in (-1.55, 1.55):                                                          # rollers under the door
        m.box(DARK, (dx - 0.4, 0.8, cz + sz - 0.25), (dx + 0.4, 0.95, cz + sz + 0.25), bevel=0.03, seg=1)
    if not open_:
        return
    # the missile: white first stage, interstage bands, second stage, an ogive nose with a red tip
    base = 0.72
    m.tube(DARK, (cx, base, cz), 1.0, 0.8, 0.5, 24)                                   # the launch collar
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        m.pipe(DARK, (cx + math.cos(a) * 1.3, base + 0.05, cz + math.sin(a) * 1.3), (cx + math.cos(a) * 0.85, base + 0.5, cz + math.sin(a) * 0.85), 0.07, 6)
    m.cyl("paint", (cx, base, cz), 0.78, 3.9, 24, tint=WHITE)
    for y, h, t in ((1.0, 0.18, hexc("1d252a")), (2.45, 0.3, hexc("c0392b")), (3.7, 0.3, hexc("1d252a"))):
        m.cyl("paint", (cx, base + y, cz), 0.8, h, 24, tint=t)
    m.cyl("paint", (cx, base + 3.9, cz), 0.8, 0.5, 24, r2=0.7, tint=hexc("5d6468"))
    m.cyl("paint", (cx, base + 4.4, cz), 0.7, 1.7, 24, tint=WHITE)
    m.cyl("paint", (cx, base + 6.1, cz), 0.7, 0.35, 24, tint=hexc("1d252a"))
    for i, (r0, r1, h) in enumerate(((0.7, 0.58, 0.55), (0.58, 0.4, 0.5), (0.4, 0.2, 0.4), (0.2, 0.0, 0.25))):
        y = base + 6.45 + sum(s[2] for s in ((0.7, 0.58, 0.55), (0.58, 0.4, 0.5), (0.4, 0.2, 0.4), (0.2, 0.0, 0.25))[:i])
        m.cyl("paint", (cx, y, cz), r0, h, 24, r2=max(r1, 0.01), tint=hexc("5d6468") if i < 3 else hexc("c0392b"))
    m.pipe("dark", (cx + 0.82, base + 0.6, cz), (cx + 0.82, base + 6.5, cz), 0.04, 5)   # an umbilical line up the side
    # the service tower, two swing arms and a beacon
    tx = cx + 2.4
    lattice(m, tx, cz, 7.8, 1.0, 0.1)
    for y in (3.0, 5.4):
        m.box(DARK, (tx - 0.7, y - 0.05, cz - 0.7), (tx + 0.7, y + 0.05, cz + 0.7), bevel=0.01, seg=1)
        for sx in (-0.7, 0.7):
            m.pipe(DARK, (tx - 0.7, y + 0.5, cz + sx), (tx + 0.7, y + 0.5, cz + sx), 0.02, 4)
        m.pipe(METAL, (tx - 0.5, y, cz), (cx + 0.85, y, cz), 0.07, 6)
        m.box(DARK, (cx + 0.78, y - 0.1, cz - 0.3), (cx + 0.95, y + 0.1, cz + 0.3), bevel=0.02, seg=1)
    m.box("glow_red", (tx - 0.15, 7.9, cz - 0.15), (tx + 0.15, 8.2, cz + 0.15))


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box(CONC, (-8.6, -1.6, -8.2), (8.6, 0.1, 8.2), bevel=0.04, seg=1)
m.box("pavers", (-8.4, 0.1, 0.9), (8.4, 0.14, 8.0))
m.box("gravel", (-8.4, 0.1, -8.0), (8.4, 0.16, -6.0))
m.box(CONC, (-8.0, 0.14, 1.0), (8.0, 0.15, 1.12), tint=(1.0, 0.9, 0.3))
silo_cell(-3.5, -2.4, True)
silo_cell(3.9, -2.4, False)
for x in (-2.3, 2.7):                                                                   # cable trenches with cover plates
    m.box(CONC, (x - 0.3, 0.1, 0.5), (x + 0.3, 0.3, 3.4), bevel=0.02, seg=1)
    m.box(DARK, (x - 0.26, 0.3, 0.5), (x + 0.26, 0.34, 3.4))
    for k in range(5):
        m.box(METAL, (x - 0.26, 0.34, 0.6 + k * 0.58), (x + 0.26, 0.36, 0.7 + k * 0.58))

# ------------------------------------------------------------------ the control centre: a hardened block banked with earth
with m.frame((0, 0, 5.5)):
    m.box(CONC, (-4.3, 0.1, -1.8), (4.3, 2.6, 1.8), bevel=0.06)
    m.box(CONC, (-4.55, 2.6, -2.0), (4.55, 3.0, 2.0), bevel=0.06)
    m.box("gravel", (-4.2, 3.0, -1.6), (4.2, 3.05, 1.6))
    for sx in (-1.0,):                                                                   # earth banked against the left end
        cxm = sx * 4.7

        def mound(x, z, cxm=cxm):
            d = ((x - cxm) / 1.8) ** 2 + (z / 2.4) ** 2
            return -0.03 if d >= 1.0 else (1.9 * (1.0 - d) ** 0.7 + 0.12 * noise(x, z) * (1.0 - d)) + 0.0
        m.grid("turf", cxm - 1.8, cxm + 1.8, -2.4, 2.4, mound, 22, 22, base=0.1, tint=hexc("5f8d4a"))
    m.box("dark", (-1.5, 0.1, 1.76), (1.5, 2.55, 1.84))                                  # the blast door in its recess
    m.box(DARK, (-1.25, 0.1, 1.84), (1.25, 2.25, 1.98), bevel=0.04, seg=1)
    for k in range(6):
        m.hull("hazard" if k % 2 == 0 else "dark", [(-1.2 + k * 0.4, 0.2, 1.99), (-1.0 + k * 0.4, 0.2, 1.99), (-1.0 + k * 0.4, 2.2, 1.99), (-1.2 + k * 0.4, 2.2, 1.99),
                                                    (-1.2 + k * 0.4, 0.2, 2.01), (-1.0 + k * 0.4, 0.2, 2.01), (-1.0 + k * 0.4, 2.2, 2.01), (-1.2 + k * 0.4, 2.2, 2.01)])
    with m.frame((0, 1.2, 2.0), pitch=math.pi / 2):
        m.cyl(METAL, (0, 0, 0), 0.3, 0.12, 12)
    for sx in (-1.9, 1.9):
        m.box("glow_warm", (sx - 0.15, 2.3, 1.82), (sx + 0.15, 2.45, 1.9))
    m.box("hazard", (-0.6, 2.7, 1.98), (0.6, 2.95, 2.02))
    for i in range(3):
        m.pipe(DARK, (-3.3 + i * 0.7, 3.05, -0.8), (-3.3 + i * 0.7, 4.0, -0.8), 0.15, 8)
        m.cyl(DARK, (-3.3 + i * 0.7, 4.0, -0.8), 0.22, 0.08, 8)
    m.pipe(METAL, (3.0, 3.05, -0.6), (3.0, 8.0, -0.6), 0.05, 6)                           # antenna mast with cross-arms and guys
    for y in (5.0, 6.4, 7.6):
        m.pipe(METAL, (2.4, y, -0.6), (3.6, y, -0.6), 0.035, 4)
    for gx, gz in ((1.4, -1.8), (4.4, -1.8), (3.0, 1.2)):
        m.wire(METAL, [(3.0, 6.8, -0.6), (gx, 3.05, gz)], 0.007)
    m.cyl("glow_red", (3.0, 8.0, -0.6), 0.07, 0.12, 8)
    m.pipe(METAL, (1.5, 3.05, -1.0), (1.5, 4.6, -1.0), 0.05, 6)
    m.dome("paint", (1.5, 4.6, -1.0), 0.7, 0.45, 16, 5)

# ------------------------------------------------------------------ tanks, pump house, generator shed, transformer, truck, tower
for i in range(2):
    tx, r = 5.8 + i * 1.7, 0.8 - i * 0.1
    m.pipe("paint", (tx, 1.15, 1.9), (tx, 1.15, 5.7), r, 24, tint=LIGHT)
    for zz, pit in ((1.9, -math.pi / 2), (5.7, math.pi / 2)):
        with m.frame((tx, 1.15, zz), pitch=pit):
            m.dome("paint", (0, 0, 0), r, 0.3, 24, 4, tint=LIGHT)
    for z in (2.4, 5.2):
        m.box(CONC, (tx - 0.8, 0.1, z - 0.2), (tx + 0.8, 0.85, z + 0.2), bevel=0.04, seg=1)
    m.box(DARK, (tx - 0.12, 1.9 - i * 0.1, 3.6), (tx + 0.12, 2.0 - i * 0.1, 4.0), bevel=0.02, seg=1)
m.box(CLAD, (5.6, 0.1, 6.4), (8.2, 2.3, 7.9), bevel=0.04, seg=1)                          # the pump house
m.box(CONC, (5.5, 2.3, 6.3), (8.3, 2.46, 8.0), bevel=0.04, seg=1)
m.box("dark", (6.4, 0.1, 7.88), (7.4, 1.8, 7.94))
m.box(DARK, (6.5, 0.1, 7.92), (7.3, 1.75, 7.98), bevel=0.02, seg=1)
m.pipe("paint", (6.2, 0.5, 5.8), (6.2, 0.5, 6.4), 0.12, 8, tint=hexc("c83a2e"))
m.box(CLAD, (-8.2, 0.1, 3.4), (-6.0, 2.4, 6.4), bevel=0.04, seg=1)                         # the generator shed
m.box(CONC, (-8.3, 2.4, 3.3), (-5.9, 2.55, 6.5), bevel=0.04, seg=1)
slats(m, -7.9, -6.3, 0.5, 2.0, 6.4, tint=LIGHT)
m.pipe(DARK, (-7.4, 2.55, 4.0), (-7.4, 4.0, 4.0), 0.13, 8)
m.cyl(DARK, (-7.4, 4.0, 4.0), 0.2, 0.08, 8)
m.box("glow_green", (-6.0, 1.5, 4.7), (-5.94, 1.7, 4.9))
m.box(METAL, (-8.0, 0.1, 7.0), (-6.4, 1.6, 8.0), bevel=0.05, seg=2, tint=(0.85, 0.95, 0.9))   # the transformer
for k in range(5):
    m.box(METAL, (-7.9 + k * 0.32, 0.25, 8.0), (-7.82 + k * 0.32, 1.4, 8.22), bevel=0.01, seg=1)
for k in range(3):
    m.pipe("paint", (-7.7 + k * 0.5, 1.6, 7.5), (-7.7 + k * 0.5, 2.4, 7.5), 0.08, 8, tint=hexc("d9c9a8"))
    for s in range(3):
        m.cyl("paint", (-7.7 + k * 0.5, 1.8 + s * 0.2, 7.5), 0.13, 0.05, 10, tint=hexc("c8b890"))
truck(m, 0.5, 2.0, yaw=math.pi / 2)
lattice(m, -7.4, -7.2, 6.0, 1.3, 0.1, 0.045)                                                # the guard tower
m.box(CLAD, (-8.2, 6.0, -8.0), (-6.6, 7.5, -6.4), bevel=0.04, seg=1)
m.box(GLASS, (-8.15, 6.4, -6.43), (-6.65, 7.2, -6.37))
m.box(GLASS, (-6.63, 6.4, -7.95), (-6.57, 7.2, -6.45))
m.box(CONC, (-8.4, 7.5, -8.2), (-6.4, 7.65, -6.2), bevel=0.03, seg=1)
m.box("glow_warm", (-7.6, 7.3, -6.2), (-7.0, 7.4, -6.1))
m.pipe(METAL, (-7.4, 7.65, -7.2), (-7.4, 8.4, -7.2), 0.03, 5)
for k in range(5):                                                                         # the ladder up the tower
    m.pipe(METAL, (-6.9, 0.3 + k * 1.15, -6.5), (-6.9, 0.3 + k * 1.15, -6.1), 0.02, 4)

# ------------------------------------------------------------------ fence with a gate, floodlights, the flag
fence(m, -8.4, 8.4, -8.0, 8.0, gap=(3.0, 5.6, 8.0))
for gx in (3.0, 5.6):
    m.box(CONC, (gx - 0.15, 0.1, 7.85), (gx + 0.15, 2.0, 8.15), bevel=0.03, seg=1)
m.box(DARK, (3.15, 0.2, 7.95), (5.45, 1.7, 8.05), bevel=0.02, seg=1)                       # the sliding gate
for k in range(6):
    m.box("hazard" if k % 2 == 0 else "dark", (3.2 + k * 0.38, 0.9, 8.06), (3.2 + k * 0.38 + 0.19, 1.6, 8.09))
for p in [(-8.0, 7.6), (8.0, 7.6), (8.0, -7.4), (0.0, -7.4)]:
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.0, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.4, 5.0, p[1] - 0.16), (p[0] + 0.4, 5.12, p[1] + 0.16), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.36, 4.97, p[1] - 0.13), (p[0] + 0.36, 5.0, p[1] + 0.13))
m.pipe(METAL, (2.4, 0.1, 7.4), (2.4, 6.6, 7.4), 0.05, 6)
m.box("banner", (2.42, 5.3, 7.4), (2.44, 6.4, 8.3))

m.finish(out)
