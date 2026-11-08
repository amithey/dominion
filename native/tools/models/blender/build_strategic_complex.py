"""The Strategic Weapons Complex, modelled in Blender.   blender -b -P build_strategic_complex.py -- <out.glb>

A hardened assembly hall (precast panels, a dark band, a sawtooth roof with lit clerestory glazing, a tall sliding door under a
lit canopy, radiation signs), side wings with louvres, HEPA filter boxes ducted to a tall banded vent stack, three
earth-covered storage bays, a transporter with a canister on the apron, a gantry crane over a loading bay, a gate house, four
watch towers and a double perimeter fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import slats, lattice, fan, truck, watch_tower, trefoil, vent_stack, fence_poly, magazine, crate, hazard_ring

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "strategic_complex.glb"
m = Model("strategic_complex")
rng = random.Random(31)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
GOLD = hexc("c8902a")

slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.2, 0.1, -9.0), (9.2, 0.15, -4.0))
m.box("asphalt", (-9.2, 0.1, -4.0), (9.2, 0.16, 2.2))
m.box("pavers", (-9.0, 0.1, 2.2), (9.0, 0.14, 7.4))
m.box(CONC, (-9.2, 0.165, -1.0), (9.2, 0.175, -0.94), tint=(1.0, 0.9, 0.3))
for k in range(9):
    m.box(CONC, (-8.4 + k * 2.1, 0.165, 1.2), (-7.8 + k * 2.1, 0.175, 1.26), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the assembly hall, 11 x 4.6, 5.4 high
HX, HZ, W, D, H = 0.0, -6.5, 11.0, 4.6, 5.4
FZ = HZ + D / 2
m.box(CONC, (HX - W / 2, 0.1, HZ - D / 2), (HX + W / 2, H, FZ - 0.05), bevel=0.04, seg=1, tint=(0.62, 0.62, 0.65))                         # the core; panels hang on it
for side in (-1, 1):                                                                                 # precast panels on the front, door in the middle
    xa, xb = (2.4, W / 2) if side > 0 else (-W / 2, -2.4)
    for k in range(3):
        x0 = xa + (xb - xa) * k / 3 + 0.02
        x1 = xa + (xb - xa) * (k + 1) / 3 - 0.02
        t = 0.93 + rng.random() * 0.12
        m.box(CONC, (x0, 0.1, FZ - 0.08), (x1, 3.1, FZ), bevel=0.02, seg=1, tint=(t, t, t))
        for r_ in range(3):
            for q in (0.25, 0.75):
                m.cyl("dark", (x0 + (x1 - x0) * q, 0.6 + r_ * 0.9, FZ - 0.002), 0.03, 0.03, 6)
m.box(CONC, (-W / 2, 4.4, FZ - 0.08), (W / 2, H, FZ), bevel=0.02, seg=1)                          # above the door
for xa, xb in ((-W / 2, -2.2), (2.2, W / 2)):
    m.box(CONC, (xa, 3.1, FZ - 0.08), (xb, 4.4, FZ), bevel=0.02, seg=1)
m.box("dark", (-W / 2 - 0.05, 3.1, HZ - D / 2 - 0.05), (W / 2 + 0.05, 3.3, FZ + 0.05))
m.box(CONC, (-W / 2 - 0.2, H, HZ - D / 2 - 0.2), (W / 2 + 0.2, H + 0.35, FZ + 0.2), bevel=0.05, seg=1)  # the roof edge
for k in range(3):                                                                                   # sawtooth roof: slope up, lit glazing on the high side
    z0 = HZ - D / 2 + k * D / 3
    z1 = z0 + D / 3
    m.hull(CLAD, [(-W / 2, H + 0.35, z0), (W / 2, H + 0.35, z0), (-W / 2, H + 0.35, z1), (W / 2, H + 0.35, z1), (-W / 2, H + 1.2, z1 - 0.05), (W / 2, H + 1.2, z1 - 0.05)], tint=(1.05, 1.05, 1.1))
    m.box("glow_cyan", (-W / 2 + 0.3, H + 0.4, z1 - 0.05), (W / 2 - 0.3, H + 1.15, z1 - 0.03))
    for j in range(12):                                                                              # standing seams
        xs = -W / 2 + 0.4 + j * (W - 0.8) / 11
        m.pipe(METAL, (xs, H + 0.37, z0 + 0.05), (xs, H + 1.22, z1 - 0.1), 0.02, 4)
    for j in range(7):                                                                               # glazing bars
        xs = -W / 2 + 0.3 + j * (W - 0.6) / 6
        m.box(DARK, (xs - 0.04, H + 0.38, z1 - 0.07), (xs + 0.04, H + 1.17, z1 - 0.02))
for k in range(3):
    fan(m, (-3.6 + k * 3.6, H + 0.4, HZ - 1.0), 0.45)
# the sliding door: a recess with a tall leaf, hazard stripes, a rail, a lit canopy
m.box("dark", (-2.2, 0.1, FZ - 0.02), (2.2, 4.4, FZ + 0.06))
m.box(DARK, (-2.1, 0.1, FZ + 0.06), (0.1, 4.3, FZ + 0.16), bevel=0.03, seg=1)
for k in range(6):
    m.hull("hazard" if k % 2 == 0 else "dark", [(-2.0 + k * 0.35, 0.15, FZ + 0.17), (-1.85 + k * 0.35, 0.15, FZ + 0.17), (-1.85 + k * 0.35 + 0.4, 1.8, FZ + 0.17), (-2.0 + k * 0.35 + 0.4, 1.8, FZ + 0.17),
                                                (-2.0 + k * 0.35, 0.15, FZ + 0.19), (-1.85 + k * 0.35, 0.15, FZ + 0.19), (-1.85 + k * 0.35 + 0.4, 1.8, FZ + 0.19), (-2.0 + k * 0.35 + 0.4, 1.8, FZ + 0.19)])
m.pipe(METAL, (-2.4, 4.5, FZ + 0.2), (2.8, 4.5, FZ + 0.2), 0.06, 6)
m.box(CONC, (-2.6, 4.5, FZ), (2.6, 4.7, FZ + 1.2), bevel=0.04, seg=1)
m.box("glow_warm", (-2.3, 4.45, FZ + 0.3), (2.3, 4.5, FZ + 0.4))
for sx in (-2.2, 2.2):
    m.pipe(METAL, (sx, 0.1, FZ + 1.1), (sx, 4.5, FZ + 1.1), 0.08, 8)
trefoil(m, (4.0, 3.9, FZ + 0.03), 0.65)
trefoil(m, (-4.0, 3.9, FZ + 0.03), 0.65)
for sx in (-1, 1):                                                                                   # side wings with louvres and filter boxes
    m.box(CLAD, (sx * 6.4 - 0.9, 0.1, HZ - 1.4), (sx * 6.4 + 0.9, 3.2, HZ + 1.4), bevel=0.04, seg=1)
    m.box(CONC, (sx * 6.4 - 1.0, 3.2, HZ - 1.5), (sx * 6.4 + 1.0, 3.35, HZ + 1.5), bevel=0.03, seg=1)
    slats(m, sx * 6.4 - 0.7, sx * 6.4 + 0.7, 0.6, 2.6, HZ + 1.4, tint=hexc("dfe4e6"))
vent_stack(m, 7.8, -8.4, 12.5, 0.75)
for k in range(3):                                                                                   # HEPA filter boxes on the roof, ducted to the stack
    fx = 5.8 + k * 0.9
    m.box(DARK, (fx - 0.4, H + 0.35, HZ - 1.9), (fx + 0.4, H + 1.6, HZ - 0.9), bevel=0.03, seg=1)
    for q in range(5):
        m.box("dark", (fx - 0.35, H + 0.6 + q * 0.2, HZ - 0.9), (fx + 0.35, H + 0.66 + q * 0.2, HZ - 0.88))
m.pipe(DARK, (5.8, H + 1.2, HZ - 1.4), (7.8, 9.0, -8.4), 0.12, 8)
m.pipe(DARK, (6.7, H + 1.2, HZ - 1.4), (7.8, 8.6, -8.4), 0.1, 8)

# ------------------------------------------------------------------ three earth-covered storage bays
for i in range(3):
    magazine(m, -6.4 + i * 6.4, i + 1, hw=1.9, hl=1.7, front=0.2)

# ------------------------------------------------------------------ a gantry crane over a loading bay on the right
for gz in (3.0, 5.2):
    for gx in (3.2, 7.6):
        m.box("paint", (gx - 0.1, 0.14, gz - 0.1), (gx + 0.1, 4.4, gz + 0.1), bevel=0.015, seg=1, tint=GOLD)
    m.box("paint", (3.1, 4.4, gz - 0.12), (7.7, 4.65, gz + 0.12), bevel=0.02, seg=1, tint=GOLD)
for gx in (3.2, 7.6):
    m.box("paint", (gx - 0.1, 4.4, 2.9), (gx + 0.1, 4.62, 5.3), bevel=0.015, seg=1, tint=GOLD)
m.box(DARK, (5.0, 4.1, 3.6), (5.8, 4.4, 4.6), bevel=0.03, seg=1)
m.pipe(DARK, (5.4, 4.1, 4.1), (5.4, 2.0, 4.1), 0.02, 4)
m.box(DARK, (5.1, 1.8, 3.9), (5.7, 2.0, 4.3), bevel=0.02, seg=1)
for k in range(2):
    crate(m, 4.2 + k * 2.2, 0.14, 3.6, 1.0, 0.76, 1.0, hexc("6f7a58"))

# ------------------------------------------------------------------ the gate house, watch towers, floodlights, fences
m.box(CLAD, (-0.9, 0.1, 6.6), (0.9, 2.5, 7.8), bevel=0.04, seg=1)
m.box(CONC, (-1.0, 2.5, 6.5), (1.0, 2.62, 7.9), bevel=0.03, seg=1)
m.box(GLASS, (-0.8, 1.1, 7.78), (0.8, 2.3, 7.84))
m.pipe(METAL, (1.0, 1.0, 7.2), (3.2, 1.0, 7.2), 0.05, 6)
for k in range(4):
    m.box("paint", (1.0 + k * 0.55, 0.95, 7.15), (1.28 + k * 0.55, 1.05, 7.25), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
trefoil(m, (0.0, 2.9, 7.85), 0.4)
for p in ((-8.8, -5.0), (8.8, -5.0), (-8.0, 6.0), (8.0, 6.0)):
    watch_tower(m, p[0], p[1], 5.2)
for p in ((-3.6, 2.0), (3.6, 2.0), (-9.0, 0.0), (9.0, 0.0)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
fence_poly(m, 10.2, gate=(-3.6, 3.6), hazard_every=5, h=1.6)
fence_poly(m, 11.4, gate=(-3.6, 3.6), hazard_every=0, h=2.0)
m.pipe(METAL, (-9.0, 0.1, 6.6), (-9.0, 6.6, 6.6), 0.05, 6)
m.box("banner", (-8.98, 5.2, 6.6), (-8.96, 6.3, 7.6))
m.finish(out)
