"""The Offshore Rig, modelled in Blender.   blender -b -P build_offshore_rig.py -- <out.glb>

A fixed steel jacket platform standing in the sea (sea level is y 0, the deck at y 4.2): four braced legs with cross-bracing and
boat landings, a main deck with a drilling derrick and drill floor, a crane, an accommodation block with a helideck on top, a
flare boom with a burning flame, pipe racks, tanks, lifeboats, railings and lights. About 7.5 m square like the old one.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import fan

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "offshore_rig.glb"
m = Model("offshore_rig")
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
ORANGE = hexc("c96a2b")
STEEL = hexc("8a949a")
DECK_Y = 4.2


def beam(a, b, r=0.05, tint=STEEL):
    m.pipe("paint", a, b, r, 6, tint=tint)


# ------------------------------------------------------------------ the jacket: four legs, braced, with a boat landing
LEGS = [(-2.6, -2.6), (2.6, -2.6), (-2.6, 2.6), (2.6, 2.6)]
for lx, lz in LEGS:
    m.pipe("paint", (lx * 1.12, -4.0, lz * 1.12), (lx, DECK_Y, lz), 0.4, 14, tint=hexc("5d6166"))
    m.tube("paint", (lx * 1.12, -0.35, lz * 1.12), 0.46, 0.38, 0.5, 14, tint=hexc("c0392b"))       # a splash-zone band
for (a, b) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
    for (y0, y1) in ((-3.2, 0.6), (0.6, 3.6)):
        sc0, sc1 = 1.12 - (y0 + 4.0) / 8.2 * 0.12, 1.12 - (y1 + 4.0) / 8.2 * 0.12
        beam((a[0] * 2.6 * sc0, y0, a[1] * 2.6 * sc0), (b[0] * 2.6 * sc1, y1, b[1] * 2.6 * sc1), 0.07)
        beam((b[0] * 2.6 * sc0, y0, b[1] * 2.6 * sc0), (a[0] * 2.6 * sc1, y1, a[1] * 2.6 * sc1), 0.07)
    m.pipe("paint", (a[0] * 2.6 * 1.06, 0.6, a[1] * 2.6 * 1.06), (b[0] * 2.6 * 1.06, 0.6, b[1] * 2.6 * 1.06), 0.1, 8, tint=STEEL)
m.box("wood", (-2.0, 1.0, 2.9), (2.0, 1.08, 3.6), bevel=0.01, seg=1, tint=hexc("a08060"))                 # the boat landing
for k in range(3):
    m.pipe(METAL, (-1.6 + k * 1.6, 1.0, 3.3), (-1.6 + k * 1.6, -0.6, 3.3), 0.04, 6)
for y in range(1, 4):                                                                                      # a ladder up to the deck
    m.pipe(METAL, (-2.8, 0.2 + y * 1.0, -2.9), (-2.4, 0.2 + y * 1.0, -2.9), 0.02, 4)
for sx in (-2.8, -2.4):
    m.pipe(METAL, (sx, 0.2, -2.9), (sx, DECK_Y, -2.9), 0.025, 5)

# ------------------------------------------------------------------ the main deck: plating, rails, the drill floor, pipe racks
m.box(DARK, (-3.9, DECK_Y - 0.2, -3.9), (3.9, DECK_Y + 0.4, 3.9), bevel=0.04, seg=1, tint=hexc("8c8f86"))
m.box("metal", (-3.8, DECK_Y + 0.4, -3.8), (3.8, DECK_Y + 0.43, 3.8), tint=(0.9, 0.9, 0.9))
for k in range(8):
    m.box("dark", (-3.8, DECK_Y + 0.43, -3.5 + k * 1.0), (3.8, DECK_Y + 0.44, -3.46 + k * 1.0))
RY = DECK_Y + 0.43
for k in range(17):                                                                                        # a railing round the deck
    t = -3.8 + k * 0.475
    for (x, z) in ((t, -3.8), (t, 3.8), (-3.8, t), (3.8, t)):
        m.pipe(METAL, (x, RY, z), (x, RY + 0.95, z), 0.02, 4)
for (a, b) in (((-3.8, -3.8), (3.8, -3.8)), ((-3.8, 3.8), (3.8, 3.8)), ((-3.8, -3.8), (-3.8, 3.8)), ((3.8, -3.8), (3.8, 3.8))):
    for y in (0.5, 0.95):
        m.pipe(METAL, (a[0], RY + y, a[1]), (b[0], RY + y, b[1]), 0.02, 4)
# the derrick: a four-legged lattice mast over the drill floor
DX, DZ = 1.6, -1.2
m.box(DARK, (DX - 1.0, RY, DZ - 1.0), (DX + 1.0, RY + 0.5, DZ + 1.0), bevel=0.03, seg=1)
for sx in (-1, 1):
    for sz in (-1, 1):
        beam((DX + sx * 1.0, RY + 0.5, DZ + sz * 1.0), (DX + sx * 0.25, RY + 9.0, DZ + sz * 0.25), 0.09, ORANGE)
for y in (2.0, 4.0, 6.0, 8.0):
    t = 1.0 - (y - 0.5) / 8.5 * 0.75
    pts = [(DX + sx * t, RY + y, DZ + sz * t) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1), (-1, -1))]
    for a_, b_ in zip(pts, pts[1:]):
        beam(a_, b_, 0.03, ORANGE)
    for a_, b_ in zip(pts, pts[1:]):
        beam((a_[0], RY + y, a_[2]), (b_[0], RY + y + 2.0, b_[2]), 0.025, ORANGE)
m.box(DARK, (DX - 0.4, RY + 9.0, DZ - 0.4), (DX + 0.4, RY + 9.5, DZ + 0.4), bevel=0.03, seg=1)                # the crown block
m.pipe(METAL, (DX, RY + 9.0, DZ), (DX, RY + 0.5, DZ), 0.06, 6)                                           # the drill string
m.cyl("glow_red", (DX, RY + 9.5, DZ), 0.08, 0.2, 8)
# pipe racks, tanks, a generator package, a mud pump
for k in range(4):
    m.pipe("paint", (-3.4, RY + 0.35 + (k % 2) * 0.3, 0.4 + k * 0.0 - 0.0 + k * 0.28), (0.0, RY + 0.35 + (k % 2) * 0.3, 0.4 + k * 0.28), 0.12, 10, tint=hexc("c9972a") if k % 2 == 0 else hexc("8e999e"))
for k in range(2):
    m.cyl("paint", (-0.4 + k * 1.2, RY, 2.8), 0.5, 1.2, 14, tint=hexc("e8ecee"))
    m.dome("paint", (-0.4 + k * 1.2, RY + 1.2, 2.8), 0.5, 0.2, 14, 3, tint=hexc("e8ecee"))
m.box(CLAD, (2.0, RY, 1.4), (3.5, RY + 1.2, 3.4), bevel=0.04, seg=1, tint=hexc("c8cdd0"))
fan(m, (2.75, RY + 1.2, 2.4), 0.45)
m.box("glow_green", (3.5, RY + 0.7, 2.2), (3.54, RY + 0.9, 2.4))

# ------------------------------------------------------------------ the accommodation block with a helideck on top
AX, AZ = -2.0, 1.6
m.box(CLAD, (AX - 1.5, RY, AZ - 1.3), (AX + 1.5, RY + 2.2, AZ + 1.3), bevel=0.04, seg=1, tint=hexc("d2c7a4"))
m.box(CLAD, (AX - 1.4, RY + 2.2, AZ - 1.2), (AX + 1.4, RY + 3.4, AZ + 1.2), bevel=0.04, seg=1, tint=hexc("d8cfb0"))
for k in range(4):
    for lv in range(2):
        m.box(GLASS, (AX - 1.2 + k * 0.65, RY + 0.8 + lv * 1.2, AZ + 1.28), (AX - 0.7 + k * 0.65, RY + 1.5 + lv * 1.2, AZ + 1.33), tint=(1.4, 1.7, 1.9))
m.box("dark", (AX + 1.0, RY + 0.0, AZ + 1.28), (AX + 1.45, RY + 1.9, AZ + 1.32))
HD = (AX, RY + 3.4, AZ)
for sx in (-1, 1):                                                                                          # helideck on legs
    for sz in (-1, 1):
        m.pipe(METAL, (AX + sx * 1.3, RY + 3.4, AZ + sz * 1.2), (AX + sx * 1.9, RY + 3.4, AZ + sz * 1.7), 0.05, 5)
m.cyl("paint", (AX, RY + 3.4, AZ), 2.1, 0.12, 24, tint=hexc("3a4a40"))
m.tube("paint", (AX, RY + 3.52, AZ), 1.9, 1.8, 0.02, 24, tint=hexc("f0eee4"))
for sx in (-0.4, 0.4):
    m.box("paint", (AX + sx - 0.07, RY + 3.52, AZ - 0.55), (AX + sx + 0.07, RY + 3.54, AZ + 0.55), tint=hexc("f0eee4"))
m.box("paint", (AX - 0.4, RY + 3.52, AZ - 0.07), (AX + 0.4, RY + 3.54, AZ + 0.07), tint=hexc("f0eee4"))
for k in range(16):
    a = math.tau * k / 16
    m.cyl("glow_green", (AX + math.cos(a) * 2.1, RY + 3.5, AZ + math.sin(a) * 2.1), 0.05, 0.1, 6)
m.pipe(METAL, (AX + 1.4, RY + 3.4, AZ - 1.2), (AX + 1.4, RY + 5.0, AZ - 1.2), 0.03, 5)                  # a radio mast
m.cyl("glow_red", (AX + 1.4, RY + 5.0, AZ - 1.2), 0.06, 0.12, 8)
for k in range(2):                                                                                          # lifeboats
    m.hull("paint", [(-3.7, RY + 0.4, -3.2 + k * 1.2), (-3.7, RY + 0.4, -2.4 + k * 1.2), (-4.3, RY + 0.4, -3.2 + k * 1.2), (-4.3, RY + 0.4, -2.4 + k * 1.2),
                     (-3.7, RY + 1.0, -3.0 + k * 1.2), (-4.3, RY + 1.0, -3.0 + k * 1.2)], tint=hexc("e0701a"))

# ------------------------------------------------------------------ the crane and the flare boom
CX, CZ = 3.2, 3.2
m.cyl(DARK, (CX, RY, CZ), 0.4, 1.4, 12)
m.box("paint", (CX - 0.3, RY + 1.4, CZ - 0.3), (CX + 0.3, RY + 2.0, CZ + 0.3), bevel=0.03, seg=1, tint=hexc("e0b020"))
beam((CX, RY + 1.9, CZ), (CX - 3.4, RY + 5.0, CZ - 1.2), 0.08, hexc("e0b020"))
beam((CX, RY + 1.9, CZ), (CX - 3.4, RY + 5.2, CZ - 1.2), 0.04, hexc("e0b020"))
m.wire(METAL, [(CX - 3.4, RY + 5.0, CZ - 1.2), (CX - 3.4, RY + 2.4, CZ - 1.2)], 0.015, 4)
m.box(DARK, (CX - 3.55, RY + 2.1, CZ - 1.35), (CX - 3.25, RY + 2.4, CZ - 1.05), bevel=0.02, seg=1)
beam((-2.5, RY + 0.3, -3.6), (-2.6, RY + 3.4, -6.3), 0.1, STEEL)                                           # the flare boom
beam((-2.2, RY + 0.3, -3.6), (-2.6, RY + 3.4, -6.3), 0.05, STEEL)
beam((-2.8, RY + 0.3, -3.6), (-2.6, RY + 3.4, -6.3), 0.05, STEEL)
m.cyl("glow_warm", (-2.6, RY + 3.4, -6.3), 0.4, 1.1, 10, r2=0.05, tint=(1.0, 0.7, 0.3))
m.cyl("glow_red", (-2.6, RY + 3.4, -6.3), 0.2, 0.5, 8, r2=0.02, tint=(1.0, 0.4, 0.2))
m.marker("Smoke_Industry_0", (-2.6, RY + 4.8, -6.3))
for p in ((-3.6, 3.6), (3.6, -3.6), (3.6, 3.6), (-3.6, -3.6)):
    m.pipe(METAL, (p[0], RY, p[1]), (p[0], RY + 2.2, p[1]), 0.03, 5)
    m.box("glow_warm", (p[0] - 0.15, RY + 2.2, p[1] - 0.1), (p[0] + 0.15, RY + 2.3, p[1] + 0.1))
m.finish(out)
