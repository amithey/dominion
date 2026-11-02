"""The Special Weapons Laboratory, modelled in Blender.   blender -b -P build_special_lab.py -- <out.glb>

A sealed, windowless containment block in pale precast panels with a teal band and a lit slit course, a glass-walled
observation corridor, an airlock with double hazard doors, keypad and camera; on the roof HEPA bag-in/bag-out filter housings
with fans, an air handler and exhaust stacks; a tall banded vent stack; effluent decontamination tanks with domed tops, flanges,
caged ladders and gauges on a bund; cold-storage containers with cooling units; a decontamination trailer with a shower awning;
a generator, a gate house with a barrier and a double fence round the hex. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import slats, fan, container, vent_stack, fence_poly, lattice

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "special_lab.glb"
m = Model("special_lab")
rng = random.Random(41)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
TEAL = hexc("2f6f7e")
LIGHT = hexc("dfe4e6")


def biohazard(c, r):
    """A biohazard sign on a wall facing +z: a yellow disc, three dark rings round a hub."""
    with m.frame(c, pitch=math.pi / 2):
        m.cyl("hazard", (0, 0, 0), r, 0.03, 28)
        for k in range(3):
            a = math.tau * k / 3.0 + math.pi / 2
            x, z = math.cos(a) * r * 0.5, math.sin(a) * r * 0.5
            m.tube("dark", (x, 0.03, z), r * 0.36, r * 0.24, 0.015, 20)
            m.cyl("dark", (x, 0.03, z), r * 0.08, 0.015, 8)
        m.cyl("dark", (0, 0.03, 0), r * 0.14, 0.02, 12)
        m.tube("dark", (0, 0.03, 0), r * 0.95, r * 0.88, 0.012, 28)


slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("pavers", (-9.2, 0.1, -9.0), (9.2, 0.14, 7.6))
m.box("asphalt", (-1.4, 0.14, 1.5), (1.4, 0.15, 9.4))
for k in range(6):
    m.box(CONC, (-0.05, 0.15, 1.9 + k * 1.2), (0.05, 0.155, 2.4 + k * 1.2), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the containment block, 10.4 x 5, 4.4 high
HX, HZ, W, D, H = -0.4, -5.6, 10.4, 5.0, 4.4
FZ = HZ + D / 2
m.box(CONC, (HX - W / 2 - 0.1, 0.14, HZ - D / 2 - 0.1), (HX + W / 2 + 0.1, 0.7, FZ + 0.1), bevel=0.04, seg=1)           # plinth
m.box(CONC, (HX - W / 2, 0.7, HZ - D / 2), (HX + W / 2, H, FZ - 0.06), bevel=0.03, seg=1, tint=(0.6, 0.6, 0.63))     # core
for k in range(8):                                                                                                     # panelised front
    x0 = HX - W / 2 + k * W / 8 + 0.02
    x1 = HX - W / 2 + (k + 1) * W / 8 - 0.02
    t = 0.95 + rng.random() * 0.1
    m.box(CLAD, (x0, 0.7, FZ - 0.08), (x1, H, FZ), bevel=0.02, seg=1, tint=(t, t, t * 1.02))
    for r_ in range(3):
        for q in (0.22, 0.78):
            m.cyl("dark", (x0 + (x1 - x0) * q, 1.0 + r_ * 1.0, FZ - 0.002), 0.025, 0.025, 6)
for side in (-1, 1):                                                                                                   # and the sides and back
    for k in range(4):
        z0 = HZ - D / 2 + k * D / 4 + 0.02
        z1 = HZ - D / 2 + (k + 1) * D / 4 - 0.02
        xs = HX + side * W / 2
        t = 0.95 + rng.random() * 0.1
        m.box(CLAD, (min(xs, xs + side * 0.08), 0.7, z0), (max(xs, xs + side * 0.08), H, z1), bevel=0.02, seg=1, tint=(t, t, t * 1.02))
for k in range(8):
    x0 = HX - W / 2 + k * W / 8 + 0.02
    x1 = HX - W / 2 + (k + 1) * W / 8 - 0.02
    m.box(CLAD, (x0, 0.7, HZ - D / 2 - 0.08), (x1, H, HZ - D / 2), bevel=0.02, seg=1, tint=(0.97, 0.97, 1.0))
m.box("paint", (HX - W / 2 - 0.04, 2.5, HZ - D / 2 - 0.1), (HX + W / 2 + 0.04, 2.9, FZ + 0.01), bevel=0.02, seg=1, tint=TEAL)     # the teal band
m.box(CONC, (HX - W / 2 - 0.15, H, HZ - D / 2 - 0.15), (HX + W / 2 + 0.15, H + 0.4, FZ + 0.15), bevel=0.05, seg=1)                   # parapet
m.box("gravel", (HX - W / 2, H + 0.4, HZ - D / 2), (HX + W / 2, H + 0.45, FZ), tint=(0.9, 0.9, 0.9))
for k in range(6):                                                                                                     # the lit slits
    m.box("dark", (HX - W / 2 + 0.65 + k * 1.6, 3.15, FZ), (HX - W / 2 + 1.85 + k * 1.6, 3.55, FZ + 0.04))
    m.box("glow_cyan", (HX - W / 2 + 0.7 + k * 1.6, 3.2, FZ + 0.03), (HX - W / 2 + 1.8 + k * 1.6, 3.5, FZ + 0.07))
for k in range(4):                                                                                                     # wall lights and a camera
    m.box(DARK, (HX - 4.6 + k * 3.0, 3.8, FZ), (HX - 4.2 + k * 3.0, 3.95, FZ + 0.25), bevel=0.02, seg=1)
    m.box("glow_warm", (HX - 4.55 + k * 3.0, 3.78, FZ + 0.05), (HX - 4.25 + k * 3.0, 3.8, FZ + 0.22))
for cx, cz in ((HX + W / 2 + 0.2, FZ - 0.4), (HX - W / 2 - 0.2, HZ - D / 2 + 0.4)):
    m.pipe(METAL, (cx, 3.9, cz), (cx + (0.3 if cx > 0 else -0.3), 4.0, cz), 0.02, 4)
    m.cyl(DARK, (cx + (0.3 if cx > 0 else -0.3), 3.85, cz), 0.1, 0.12, 10)
for k in range(5):                                                                                                     # conduits up the back wall
    m.pipe("paint", (HX - 4.0 + k * 0.28, 0.7, HZ - D / 2 - 0.12), (HX - 4.0 + k * 0.28, H + 0.4, HZ - D / 2 - 0.12), 0.04, 6, tint=TEAL if k % 2 == 0 else hexc("c83a2e"))

# ------------------------------------------------------------------ the glass observation corridor, front-left
m.box(CONC, (-6.4, 0.14, FZ), (-1.2, 0.3, FZ + 1.9), bevel=0.03, seg=1)
m.box(GLASS, (-6.3, 0.3, FZ + 1.78), (-1.3, 2.4, FZ + 1.84))
m.box(GLASS, (-6.3, 0.3, FZ), (-6.24, 2.4, FZ + 1.8))
for k in range(6):
    m.box(METAL, (-6.3 + k - 0.04, 0.3, FZ + 1.76), (-6.3 + k + 0.04, 2.4, FZ + 1.9), bevel=0.01, seg=1)
for y in (0.3, 1.35, 2.38):
    m.box(METAL, (-6.3, y, FZ + 1.78), (-1.3, y + 0.05, FZ + 1.9))
m.box(CONC, (-6.45, 2.4, FZ - 0.05), (-1.15, 2.55, FZ + 2.0), bevel=0.03, seg=1)
m.box("glow_warm", (-6.0, 2.3, FZ + 0.2), (-1.6, 2.36, FZ + 1.7))
for k in range(4):                                                                                                     # benches and chairs seen through the glass
    m.box(DARK, (-5.8 + k * 1.2, 0.3, FZ + 0.3), (-4.8 + k * 1.2, 0.95, FZ + 0.9), bevel=0.02, seg=1)
    m.box("glow_cyan", (-5.6 + k * 1.2, 0.95, FZ + 0.4), (-5.0 + k * 1.2, 1.35, FZ + 0.42))

# ------------------------------------------------------------------ the airlock: double hazard doors, keypad, canopy, signs
m.box(CLAD, (0.6, 0.14, FZ), (3.8, 3.0, FZ + 1.9), bevel=0.04, seg=1)
m.box("paint", (0.5, 3.0, FZ - 0.05), (3.9, 3.15, FZ + 2.0), bevel=0.03, seg=1, tint=TEAL)
m.box("dark", (1.4, 0.14, FZ + 1.86), (3.0, 2.5, FZ + 1.92))
for sx in (1.5, 2.25):
    m.box(DARK, (sx, 0.14, FZ + 1.92), (sx + 0.65, 2.4, FZ + 2.02), bevel=0.03, seg=1)
    m.box(GLASS, (sx + 0.15, 1.5, FZ + 2.02), (sx + 0.5, 2.1, FZ + 2.04))                                              # a porthole window
for k in range(4):
    m.hull("hazard" if k % 2 == 0 else "dark", [(1.55 + k * 0.33, 0.15, FZ + 2.03), (1.65 + k * 0.33, 0.15, FZ + 2.03), (1.65 + k * 0.33 + 0.3, 1.2, FZ + 2.03), (1.55 + k * 0.33 + 0.3, 1.2, FZ + 2.03),
                                                (1.55 + k * 0.33, 0.15, FZ + 2.05), (1.65 + k * 0.33, 0.15, FZ + 2.05), (1.65 + k * 0.33 + 0.3, 1.2, FZ + 2.05), (1.55 + k * 0.33 + 0.3, 1.2, FZ + 2.05)])
m.box(DARK, (3.1, 1.1, FZ + 1.92), (3.3, 1.5, FZ + 2.0), bevel=0.02, seg=1)                                              # the keypad
m.box("glow_green", (3.15, 1.4, FZ + 2.0), (3.25, 1.45, FZ + 2.02))
m.box("glow_warm", (2.0, 2.6, FZ + 1.9), (2.4, 2.7, FZ + 2.1))
biohazard((2.2, 2.85, FZ + 1.93), 0.28)
biohazard((5.2, 3.3, FZ + 0.03), 0.7)

# ------------------------------------------------------------------ the roof: HEPA housings, an air handler, stacks, pipe run
R = H + 0.45
for k in range(3):
    x = -3.6 + k * 2.5
    m.box(CLAD, (x, R, HZ - 1.7), (x + 1.6, R + 1.26, HZ - 0.3), bevel=0.04, seg=1, tint=(1.0, 1.0, 1.05))
    m.box(CONC, (x - 0.05, R + 1.26, HZ - 1.75), (x + 1.65, R + 1.36, HZ - 0.25), bevel=0.03, seg=1)
    fan(m, (x + 0.8, R + 1.36, HZ - 1.0), 0.5)
    m.box(DARK, (x + 0.2, R + 0.2, HZ - 0.3), (x + 1.4, R + 1.0, HZ - 0.26), bevel=0.01, seg=1)                          # the bag-out door
    for hx_ in (0.3, 1.3):
        m.box(METAL, (x + hx_, R + 0.5, HZ - 0.27), (x + hx_ + 0.08, R + 0.7, HZ - 0.22), bevel=0.01, seg=1)
m.box(CLAD, (3.6, R, HZ - 1.8), (6.6, R + 1.76, HZ + 0.2), bevel=0.04, seg=1, tint=(0.95, 0.97, 1.0))
m.box(CONC, (3.5, R + 1.76, HZ - 1.9), (6.7, R + 1.86, HZ + 0.3), bevel=0.03, seg=1)
slats(m, 3.9, 6.3, R + 0.25, R + 1.55, HZ + 0.2, tint=LIGHT)
for k in range(2):
    m.pipe(METAL, (-4.2, R, HZ + 1.4 - k * 0.4), (-4.2, R + 2.2, HZ + 1.4 - k * 0.4), 0.14, 10)
    m.cyl(DARK, (-4.2, R + 2.2, HZ + 1.4 - k * 0.4), 0.22, 0.1, 10)
m.pipe("paint", (-3.8, R + 0.35, HZ + 0.6), (3.5, R + 0.35, HZ + 0.6), 0.12, 12, tint=TEAL)
for k in range(8):
    m.box(DARK, (-3.6 + k * 1.0, R, HZ + 0.55), (-3.55 + k * 1.0, R + 0.3, HZ + 0.65))
vent_stack(m, -8.4, -7.6, 9.0, 0.55)

# ------------------------------------------------------------------ effluent decontamination tanks on a bund
m.box(CONC, (5.2, 0.14, -9.0), (9.2, 0.55, -3.6), bevel=0.04, seg=1)
m.box("pavers", (5.4, 0.55, -8.8), (9.0, 0.58, -3.8))
for k in range(2):
    tz = -7.3 + k * 2.4
    m.cyl(METAL, (7.2, 0.58, tz), 0.95, 3.0, 20, tint=(0.95, 0.97, 1.0))
    m.dome(METAL, (7.2, 3.58, tz), 0.95, 0.45, 20, 4, tint=(0.95, 0.97, 1.0))
    for y in (1.2, 2.2):
        m.tube("paint", (7.2, y, tz), 0.98, 0.93, 0.06, 20, tint=hexc("8a949a"))                                        # weld flanges
    m.cyl("dark", (7.2, 3.98, tz), 0.3, 0.14, 10)
    m.tube("paint", (7.2, 3.98, tz), 0.4, 0.3, 0.06, 10, tint=hexc("8a949a"))
    m.pipe(METAL, (8.25, 0.58, tz), (8.25, 3.4, tz), 0.03, 5)                                                              # a caged ladder
    for y in (1.0, 1.8, 2.6):
        m.pipe(METAL, (8.25, y, tz - 0.2), (8.25, y, tz + 0.2), 0.02, 4)
    for k2 in range(8):
        m.pipe(METAL, (8.25 - 0.3, 0.9 + k2 * 0.3, tz), (8.25, 0.9 + k2 * 0.3, tz), 0.012, 4)
    m.pipe("glow_green", (6.3, 0.9, tz - 0.9), (6.3, 3.0, tz - 0.9), 0.04, 6)                                           # a level gauge
m.pipe("paint", (5.6, 1.0, -7.3), (5.6, 1.0, -4.8), 0.1, 8, tint=hexc("c83a2e"))
m.pipe("paint", (5.6, 1.4, -7.3), (5.6, 1.4, -4.8), 0.08, 8, tint=TEAL)
m.box(CLAD, (5.2, 0.58, -4.5), (6.4, 1.8, -3.9), bevel=0.03, seg=1)
m.box("glow_green", (6.4, 1.3, -4.3), (6.44, 1.5, -4.1))

# ------------------------------------------------------------------ cold-storage containers with cooling units
for k in range(2):
    cz = -8.4 + k * 1.6
    container(m, -7.6, cz + 0.7, 0.0, hexc("e0e4e6"), 2.8, 1.4, 1.9)
    m.box("glow_green", (-6.22, 1.4, cz + 0.5), (-6.18, 1.55, cz + 0.7))
    for fx in (-8.2, -7.0):
        fan(m, (fx, 2.05, cz + 0.7), 0.4)

# ------------------------------------------------------------------ the decontamination trailer
m.box(DARK, (4.4, 0.45, 2.2), (8.0, 0.65, 3.6), bevel=0.03, seg=1)
m.box(CLAD, (4.5, 0.65, 2.2), (7.9, 2.5, 3.6), bevel=0.05, seg=2, tint=(1.05, 1.05, 1.08))
m.box(CONC, (4.4, 2.5, 2.1), (8.0, 2.62, 3.7), bevel=0.03, seg=1)
m.box("dark", (7.0, 0.65, 3.58), (7.6, 2.2, 3.64))
m.hull("paint", [(6.6, 2.2, 3.6), (8.0, 2.2, 3.6), (6.6, 2.3, 3.6), (8.0, 2.3, 3.6), (6.6, 2.0, 4.7), (8.0, 2.0, 4.7), (6.6, 2.1, 4.7), (8.0, 2.1, 4.7)], tint=TEAL)   # the shower awning
for px in (6.7, 7.9):
    m.pipe(METAL, (px, 0.1, 4.6), (px, 2.05, 4.6), 0.04, 6)
for k in range(3):                                                                                                     # shower heads under the awning
    m.pipe(METAL, (6.9 + k * 0.4, 2.0, 4.0), (6.9 + k * 0.4, 1.85, 4.0), 0.02, 4)
biohazard((5.5, 1.6, 3.62), 0.3)
for wx in (5.0, 7.2):
    for wz in (2.1, 3.7):
        m.pipe("dark", (wx, 0.3, wz), (wx + 0.2, 0.3, wz), 0.28, 12)

# ------------------------------------------------------------------ generator, fuel tank, gate house, floodlights, fences
m.box(CLAD, (-9.0, 0.14, 3.4), (-6.4, 1.9, 5.0), bevel=0.04, seg=1)
m.box(CONC, (-9.1, 1.9, 3.3), (-6.3, 2.02, 5.1), bevel=0.03, seg=1)
slats(m, -8.6, -6.9, 0.4, 1.7, 5.0, tint=LIGHT)
m.pipe(DARK, (-8.5, 2.02, 4.0), (-8.5, 3.4, 4.0), 0.12, 8)
m.box(CLAD, (-4.2, 0.14, 6.6), (-2.6, 2.4, 7.8), bevel=0.04, seg=1)
m.box(CONC, (-4.3, 2.4, 6.5), (-2.5, 2.52, 7.9), bevel=0.03, seg=1)
m.box(GLASS, (-4.1, 1.1, 7.78), (-2.7, 2.2, 7.84))
m.pipe(METAL, (-2.6, 1.0, 7.2), (-1.4, 1.0, 7.2), 0.05, 6)
for k in range(3):
    m.box("paint", (-2.6 + k * 0.4, 0.95, 7.15), (-2.4 + k * 0.4, 1.05, 7.25), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
biohazard((-3.4, 2.9, 7.88), 0.3)
for p in ((-9.0, 1.0), (9.0, 1.0), (9.0, -9.0), (-3.0, 8.4), (3.0, 8.4)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.2, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.2, p[1] - 0.17), (p[0] + 0.45, 5.3, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.17, p[1] - 0.14), (p[0] + 0.4, 5.2, p[1] + 0.14))
fence_poly(m, 10.2, gate=(-3.4, 3.4), hazard_every=5, h=1.6)
fence_poly(m, 11.4, gate=(-3.4, 3.4), hazard_every=0, h=2.0)
m.pipe(METAL, (-9.0, 0.1, 6.4), (-9.0, 6.4, 6.4), 0.05, 6)
m.box("banner", (-8.98, 5.1, 6.4), (-8.96, 6.2, 7.4))
m.finish(out)
