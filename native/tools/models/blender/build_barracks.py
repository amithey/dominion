"""The Barracks, modelled in Blender.   blender -b -P build_barracks.py -- <out.glb>

A garrison on a hex: two long two-storey dormitory blocks (rendered concrete, ribbed lean-to roofs, a window per bay, entrance
porches with numbers), a mess hall with a stack and a flagpole parade ground between them, a guard house with a barrier and
sandbag post, a watch tower, a row of vehicles (trucks, a jeep), canvas tents, an obstacle course (wall, rope frame, tyres),
a stack of ammunition crates under a tarp, a fuel bowser, floodlights and a double fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, watch_tower, fence_poly, crate, drum, container, fan
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "barracks.glb"
m = Model("barracks")
rng = random.Random(81)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
OLIVE = hexc("55633f")
SAND = hexc("c8b88a")

slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-3.0, 0.15, -2.0), (3.0, 0.16, 4.5))                                              # the parade ground
for k in range(5):
    m.box(CONC, (-2.6 + k * 1.3, 0.16, -1.6), (-2.5 + k * 1.3, 0.165, 4.1), tint=(1.8, 1.8, 1.7))
m.box("asphalt", (-1.2, 0.15, 4.5), (1.2, 0.16, 9.4))


def dorm(cx, z0, z1, hw=2.4, number=1):
    """A long two-storey dormitory: plinth, rendered walls, a window in every bay, a porch with a number, a ribbed lean-to roof."""
    x0, x1 = cx - hw, cx + hw
    m.box(CONC, (x0 - 0.12, 0.1, z0 - 0.12), (x1 + 0.12, 0.7, z1 + 0.12), bevel=0.03, seg=1)
    m.box("plaster", (x0, 0.7, z0), (x1, 6.4, z1), bevel=0.03, seg=1, tint=(1.05, 1.0, 0.88))
    m.box("paint", (x0 - 0.04, 3.4, z0 - 0.04), (x1 + 0.04, 3.55, z1 + 0.04), tint=OLIVE)                   # a band between the floors
    n = int((z1 - z0) / 1.5)
    for sx, face in ((x0, -1), (x1, 1)):
        for i in range(n):
            zc = z0 + 0.75 + i * (z1 - z0 - 1.5) / max(1, n - 1) if n > 1 else (z0 + z1) / 2
            for y in (1.4, 4.2):
                m.box("dark", (min(sx, sx + face * 0.04), y, zc - 0.5), (max(sx, sx + face * 0.04), y + 1.4, zc + 0.5))
                m.box(GLASS, (min(sx, sx + face * 0.05), y + 0.05, zc - 0.45), (max(sx, sx + face * 0.05), y + 1.35, zc + 0.45), tint=(1.6, 1.8, 2.0))
                m.box(CONC, (min(sx, sx + face * 0.14), y - 0.1, zc - 0.62), (max(sx, sx + face * 0.14), y, zc + 0.62), bevel=0.01, seg=1, tint=(1.5, 1.5, 1.45))
                m.box(CONC, (min(sx, sx + face * 0.03), y, zc - 0.02), (max(sx, sx + face * 0.05), y + 1.4, zc + 0.02), tint=(1.6, 1.6, 1.55))
    # the roof: a lean-to with ribs, high on the parade side
    m.hull(CLAD, [(x0 - 0.4, 6.4, z0 - 0.4), (x1 + 0.4, 6.4, z0 - 0.4), (x0 - 0.4, 6.4, z1 + 0.4), (x1 + 0.4, 6.4, z1 + 0.4), (x0 - 0.4, 7.0, z0 - 0.4), (x0 - 0.4, 7.0, z1 + 0.4)], tint=(0.75, 0.78, 0.8))
    m.box(CONC, (x0 - 0.45, 6.4, z0 - 0.45), (x1 + 0.45, 6.55, z1 + 0.45), bevel=0.03, seg=1)
    # the porch at the south end
    pz = z1
    m.box(CONC, (cx - 1.2, 0.1, pz), (cx + 1.2, 3.2, pz + 1.0), bevel=0.04, seg=1, tint=(1.15, 1.15, 1.2))
    m.box("dark", (cx - 0.6, 0.7, pz + 0.98), (cx + 0.6, 2.7, pz + 1.02))
    for sx in (-1, 1):
        m.box("wood", (cx + sx * 0.3 - 0.28, 0.7, pz + 1.02), (cx + sx * 0.3 + 0.28, 2.6, pz + 1.1), bevel=0.02, seg=1, tint=(0.4, 0.3, 0.22))
    m.box(CONC, (cx - 1.3, 3.2, pz - 0.1), (cx + 1.3, 3.4, pz + 1.2), bevel=0.03, seg=1)
    m.box("paint", (cx - 0.35, 3.7, pz + 0.02), (cx + 0.35, 4.5, pz + 0.07), tint=hexc("f0eee4"))
    for k in range(number):
        m.box("dark", (cx - 0.2 + k * 0.2, 3.85, pz + 0.07), (cx - 0.1 + k * 0.2, 4.35, pz + 0.09))
    m.box("glow_warm", (cx - 0.15, 2.9, pz + 0.9), (cx + 0.15, 3.0, pz + 1.15))
    for sx in (-1, 1):
        m.pipe(METAL, (cx + sx * 1.1, 0.1, pz + 1.1), (cx + sx * 1.1, 3.2, pz + 1.1), 0.05, 6)
    m.box(CONC, (cx - 1.0, 0.1, pz + 1.0), (cx + 1.0, 0.3, pz + 1.7), bevel=0.02, seg=1)


dorm(-6.0, -8.4, -1.4, 2.4, 1)
dorm(6.0, -8.4, -1.4, 2.4, 2)
# the mess hall across the back with a stack and a flat roof of fans
m.box(CONC, (-3.6, 0.1, -9.4), (3.6, 0.6, -6.2), bevel=0.03, seg=1)
m.box("plaster", (-3.4, 0.6, -9.3), (3.4, 4.0, -6.3), bevel=0.03, seg=1, tint=(1.05, 1.0, 0.88))
for i in range(5):
    m.box("dark", (-2.8 + i * 1.4, 1.4, -6.32), (-1.8 + i * 1.4, 2.8, -6.28))
    m.box(GLASS, (-2.75 + i * 1.4, 1.45, -6.3), (-1.85 + i * 1.4, 2.75, -6.26), tint=(1.6, 1.8, 2.0))
m.box(CONC, (-3.6, 4.0, -9.5), (3.6, 4.2, -6.1), bevel=0.03, seg=1)
for k in range(2):
    fan(m, (-1.2 + k * 2.4, 4.2, -8.0), 0.5)
m.cyl(CONC, (2.6, 4.2, -9.0), 0.4, 3.2, 12)
m.cyl("dark", (2.6, 7.4, -9.0), 0.45, 0.1, 12)

# ------------------------------------------------------------------ the parade ground, flag, drill markings
flagpole(m, 0.0, 1.0, 11.0)
m.cyl(CONC, (0.0, 0.16, 1.0), 0.8, 0.25, 16)
m.box("paint", (-2.6, 0.165, -1.6), (2.6, 0.17, -1.4), tint=hexc("f0eee4"))
m.box("paint", (-2.6, 0.165, 3.9), (2.6, 0.17, 4.1), tint=hexc("f0eee4"))

# ------------------------------------------------------------------ the guard house, barrier, sandbag post
m.box(CLAD, (2.0, 0.1, 6.4), (4.0, 2.6, 8.2), bevel=0.04, seg=1, tint=hexc("c8c0a8"))
m.box(CONC, (1.9, 2.6, 6.3), (4.1, 2.75, 8.3), bevel=0.03, seg=1)
m.box(GLASS, (2.2, 1.1, 8.18), (3.8, 2.4, 8.24), tint=(1.6, 1.8, 2.0))
m.pipe(METAL, (2.0, 1.0, 7.4), (-0.2, 1.0, 7.4), 0.05, 6)
for k in range(4):
    m.box("paint", (1.8 - k * 0.55, 0.95, 7.35), (1.5 - k * 0.55, 1.05, 7.45), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
for row in range(3):
    for k in range(5 - row):
        m.box("sandbag", (-4.6 + k * 0.42 + row * 0.2, 0.15 + row * 0.2, 6.6), (-4.2 + k * 0.42 + row * 0.2, 0.35 + row * 0.2, 6.9), bevel=0.06, seg=2, tint=hexc("d8c9a0"))
m.box("dark", (-3.9, 0.55, 6.2), (-3.5, 0.65, 6.4))
watch_tower(m, 8.0, 5.4, 5.2)
watch_tower(m, -8.2, 5.4, 5.2)

# ------------------------------------------------------------------ vehicles, tents, the obstacle course, supplies
truck(m, -7.4, 0.8, yaw=0.0, canvas=True, bed=4.2, body=OLIVE)
truck(m, -4.6, 1.2, yaw=0.0, canvas=True, bed=4.2, body=OLIVE)
with m.frame((6.2, 0, 1.8), yaw=2.9):                                                                # a jeep
    m.box("paint", (-0.9, 0.35, -1.7), (0.9, 1.0, 1.7), bevel=0.1, seg=2, tint=OLIVE)
    m.box("dark", (-0.85, 1.0, -1.0), (0.85, 1.05, 0.5))
    for sx in (-0.85, 0.85):
        m.pipe(METAL, (sx, 1.0, -0.3), (sx, 1.7, -0.3), 0.03, 5)
    m.pipe(METAL, (-0.85, 1.7, -0.3), (0.85, 1.7, -0.3), 0.03, 5)
    for sx in (-1, 1):
        for sz in (-1.1, 1.1):
            m.pipe("dark", (sx * 0.78, 0.38, sz), (sx * 1.0, 0.38, sz), 0.38, 12)
    m.box("dark", (-0.5, 0.45, 1.7), (0.5, 0.75, 1.76))
for k, (tx, tz) in enumerate(((-8.6, -7.8), (-8.6, -9.0), (8.6, -9.0))):                              # canvas tents
    m.hull("paint", [(tx - 1.3, 0.13, tz - 0.8), (tx + 1.3, 0.13, tz - 0.8), (tx - 1.3, 0.13, tz + 0.8), (tx + 1.3, 0.13, tz + 0.8), (tx - 1.3, 1.7, tz), (tx + 1.3, 1.7, tz)], tint=hexc("6f7a58"))
    m.hull("dark", [(tx - 0.35, 0.13, tz + 0.79), (tx + 0.35, 0.13, tz + 0.79), (tx - 0.35, 0.13, tz + 0.82), (tx + 0.35, 0.13, tz + 0.82), (tx, 1.2, tz + 0.8)])
    m.pipe("wood", (tx - 1.3, 1.7, tz), (tx + 1.3, 1.7, tz), 0.04, 5)
# the obstacle course
for sx in (-1.0, 1.0):
    m.pipe("wood", (-6.4 + sx * 1.2, 0.13, 7.4), (-6.4 + sx * 1.2, 2.8, 7.4), 0.08, 6)
m.pipe("wood", (-7.6, 2.8, 7.4), (-5.2, 2.8, 7.4), 0.07, 6)
for k in range(4):
    m.wire("paint", [(-7.2 + k * 0.7, 2.8, 7.4), (-7.2 + k * 0.7, 0.4, 7.4)], 0.03, 6, tint=hexc("c8b88a"))
for k in range(5):
    m.tube("dark", (-8.6 + k * 0.7, 0.13, 8.4), 0.4, 0.22, 0.25, 12)
m.box("wood", (-8.8, 0.13, 6.0), (-6.0, 1.7, 6.3), bevel=0.02, seg=1, tint=(0.8, 0.7, 0.6))
for k in range(4):
    crate(m, 5.0 + k * 0.9, 0.14, -9.2, 0.8, 0.75, 0.9, hexc("6f7a58") if k % 2 else hexc("7a6a42"))
m.hull("paint", [(4.8, 0.9, -9.3), (8.6, 0.9, -9.3), (4.8, 0.9, -8.1), (8.6, 0.9, -8.1), (4.8, 1.5, -8.7), (8.6, 1.5, -8.7)], tint=hexc("4c5a38"))
for k in range(3):
    drum(m, -9.0 + k * 0.9, -4.0)
m.pipe("paint", (7.6, 1.15, -6.0), (7.6, 1.15, -3.8), 0.55, 18, tint=OLIVE)                          # a fuel bowser tank
for z in (-5.6, -4.2):
    m.box(DARK, (7.0, 0.13, z - 0.1), (8.2, 0.7, z + 0.1), bevel=0.02, seg=1)
for p in ((-9.0, 0.0), (9.0, -1.0), (-3.0, 8.6), (3.0, 8.6), (0.0, -9.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 10.4, gate=(-3.0, 3.0), hazard_every=5, h=1.7)
fence_poly(m, 11.5, gate=(-3.0, 3.0), hazard_every=0, h=2.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.6, math.sin(a) * 9.6)
m.finish(out)
