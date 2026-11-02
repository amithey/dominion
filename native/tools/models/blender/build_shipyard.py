"""The Shipyard, modelled in Blender.   blender -b -P build_shipyard.py -- <out.glb>

A vaulted building hall with its lit end towards the slip, an office wing, a slipway running down into the water with rails
and a lofted hull on keel blocks (red below the waterline, grey above, a deckhouse so far, scaffolding along both sides),
a goliath gantry crane, a material yard (steel plates, pipe racks, a welding cabin) and mast lights. Water is on the +z side.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import fan, truck
from bl_harbour import quay, mast_lights, beam, Q, CONC, CLAD, METAL, DARK, GLASS

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "shipyard.glb"
m = Model("shipyard")
GOLD = hexc("c8902a")


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


quay(m, False)

# ------------------------------------------------------------------ the building hall
HX, HZ, HW, HD = -4.6, -2.4, 3.4, 5.6
m.cut_box(CLAD, (HX - HW, Q, HZ - HD), (HX + HW, 6.43, HZ + HD), [[(HX - 2.7, Q - 0.1, HZ + HD + 0.2), (HX + 2.7, Q - 0.1, HZ + HD + 0.2), (HX - 2.7, 5.4, HZ + HD + 0.2), (HX + 2.7, 5.4, HZ + HD + 0.2),
                                                                   (HX - 2.7, Q - 0.1, HZ + HD - 0.5), (HX + 2.7, Q - 0.1, HZ + HD - 0.5), (HX - 2.7, 5.4, HZ + HD - 0.5), (HX + 2.7, 5.4, HZ + HD - 0.5)]], bevel=0.04, seg=1)
m.vault(CLAD, HX, HZ - HD, HZ + HD, HW, 6.43, 1.9, 14, thick=0.14)
for k in range(11):
    z = HZ - HD + 0.4 + k * (2 * HD - 0.8) / 10
    pts = [(HX + math.sin(-math.pi / 2 + math.pi * j / 14) * (HW + 0.04), 6.43 + 1.94 * math.cos(-math.pi / 2 + math.pi * j / 14), z) for j in range(15)]
    for a, b in zip(pts, pts[1:]):
        m.pipe(METAL, a, b, 0.04, 4)
m.box("dark", (HX - 2.7, Q, HZ + HD - 0.55), (HX + 2.7, 5.4, HZ + HD - 0.5))
m.box("glow_warm", (HX - 2.4, 5.0, HZ + HD - 0.6), (HX + 2.4, 5.12, HZ + HD - 0.1))
for k in range(3):
    m.box("glow_warm", (HX - 1.8 + k * 1.8, 3.6, HZ + HD - 0.05), (HX - 1.4 + k * 1.8, 3.7, HZ + HD + 0.0))
m.box("glow_warm", (HX - 3.0, 6.0, HZ - HD + 1), (HX + 3.0, 6.06, HZ + HD - 1))
for sx in (-1, 1):
    m.box(METAL, (HX + sx * 2.8 - 0.1, Q, HZ + HD + 0.0), (HX + sx * 2.8 + 0.1, 5.4, HZ + HD + 0.12), bevel=0.01, seg=1)
m.box("hazard", (HX - 2.8, 5.4, HZ + HD), (HX + 2.8, 5.55, HZ + HD + 0.2))
for i in range(6):                                                                           # clerestory windows both sides
    for sx in (-1, 1):
        m.box(GLASS, (HX + sx * HW - (0.0 if sx > 0 else 0.04), 4.4, HZ - HD + 0.8 + i * 1.8), (HX + sx * HW + (0.04 if sx > 0 else 0.0), 5.4, HZ - HD + 2.2 + i * 1.8))
for k in range(8):
    m.box(CLAD, (HX - HW + 0.4 + k * 0.78, Q + 0.2, HZ + HD - 0.01), (HX - HW + 0.45 + k * 0.78, 4.3, HZ + HD + 0.02), tint=(0.88, 0.88, 0.9))
m.box(CLAD, (HX + HW, Q, HZ - HD), (HX + HW + 2.0, 3.0, HZ - HD + 3.4), bevel=0.03, seg=1)           # the office wing
m.box(CONC, (HX + HW - 0.1, 3.0, HZ - HD - 0.1), (HX + HW + 2.1, 3.15, HZ - HD + 3.5), bevel=0.03, seg=1)
for k in range(2):
    m.box(GLASS, (HX + HW + 1.98, 1.0, HZ - HD + 0.5 + k * 1.4), (HX + HW + 2.04, 2.2, HZ - HD + 1.5 + k * 1.4))
m.pipe(METAL, (HX - HW + 0.8, 6.3, HZ + HD + 0.3), (HX - HW + 0.8, 8.3, HZ + HD + 0.3), 0.04, 6)
m.box("banner", (HX - HW + 0.82, 7.1, HZ + HD + 0.3), (HX - HW + 0.84, 8.2, HZ + HD + 1.5))

# ------------------------------------------------------------------ the slipway: paving sloping into the water, rails, the hull
m.hull("asphalt", [(0.0, Q + 0.002, 6.0), (8.0, Q + 0.002, 6.0), (0.0, -0.8, 9.6), (8.0, -0.8, 9.6), (0.0, -1.6, 6.0), (8.0, -1.6, 6.0), (0.0, -1.6, 9.6), (8.0, -1.6, 9.6)])
for rx in (2.4, 6.4):
    m.box(METAL, (rx - 0.08, Q, -6.0), (rx + 0.08, Q + 0.1, 6.0), bevel=0.01, seg=1)
    m.hull(METAL, [(rx - 0.08, Q, 6.0), (rx + 0.08, Q, 6.0), (rx - 0.08, Q + 0.1, 6.0), (rx + 0.08, Q + 0.1, 6.0),
                   (rx - 0.08, -0.8, 9.6), (rx + 0.08, -0.8, 9.6), (rx - 0.08, -0.7, 9.6), (rx + 0.08, -0.7, 9.6)])
    for k in range(13):
        m.box(CONC, (rx - 0.3, Q, -5.8 + k * 0.95), (rx + 0.3, Q + 0.05, -5.6 + k * 0.95))

# the hull, lofted: a station every half metre, a U-shaped section at each
X, Z0, Z1 = 4.4, -5.0, 6.6
N = 24
sections = []
for i in range(N + 1):
    s = i / N
    hw = 1.8 * (0.78 + 0.22 * smoothstep(0.0, 0.2, s))
    if s > 0.62:
        hw *= math.sqrt(max(0.0, 1.0 - ((s - 0.62) / 0.38) ** 2))
    hw = max(hw, 0.12)
    z = Z0 + (Z1 - Z0) * s
    prof = [(1.0, 3.2), (1.0, 2.1), (0.93, 1.5), (0.6, 1.0), (0.0, 0.9), (-0.6, 1.0), (-0.93, 1.5), (-1.0, 2.1), (-1.0, 3.2)]
    sections.append([(X + f * hw, y, z) for f, y in prof])
zm = (Z0 + Z1) / 2
m.loft("paint", [[r[k] for k in range(1, 8)] for r in sections], outward_from=(X, 2.2, zm), tint=hexc("8a3a2e"))          # red below
m.loft("paint", [[r[0], r[1]] for r in sections], outward_from=(X, 2.2, zm), tint=hexc("9aa3a8"))                            # grey above
m.loft("paint", [[r[8], r[7]] for r in sections], outward_from=(X, 2.2, zm), tint=hexc("9aa3a8"))
m.loft("paint", [[r[0], r[8]] for r in sections], outward_from=(X, 0.0, zm), tint=hexc("6d777c"))                              # the deck
m.hull("paint", [(x, y, Z0) for x, y, _ in sections[0]] + [(x, y, Z0 + 0.03) for x, y, _ in sections[0]], tint=hexc("8a3a2e"))   # the transom
for k in range(0, N, 3):                                                                     # keel blocks
    z = Z0 + (Z1 - Z0) * k / N
    m.box(CONC, (X - 0.5, 0.4, z), (X + 0.5, 0.9, z + 0.5), bevel=0.03, seg=1)
m.box("paint", (X - 0.9, 3.2, Z0 + 1.0), (X + 0.9, 4.4, Z0 + 3.4), bevel=0.05, seg=1, tint=hexc("c9d0d2"))            # the deckhouse so far
m.box(GLASS, (X - 0.8, 3.7, Z0 + 3.38), (X + 0.8, 4.2, Z0 + 3.44))
m.cyl("paint", (X, 4.4, Z0 + 1.8), 0.4, 1.0, 12, tint=hexc("8a3a2e"))                                                       # a funnel stub
for i in range(8):                                                                           # scaffolding along both sides
    sz = Z0 + 0.8 + i * 1.35
    for side in (-1, 1):
        sx = X + side * 2.45
        m.pipe(METAL, (sx, 0.4, sz), (sx, 4.4, sz), 0.04, 6)
        if i < 7:
            for y in (2.2, 3.5):
                m.box("wood", (sx - 0.25, y, sz), (sx + 0.25, y + 0.05, sz + 1.35), tint=hexc("d9b45f"))
            m.pipe(METAL, (sx, 2.2, sz), (sx, 3.5, sz + 1.35), 0.02, 4)
for p in ((X - 2.0, 3.3, Z0 + 5.0), (X + 2.0, 2.3, Z0 + 7.5), (X + 1.8, 3.3, Z0 + 3.0)):
    m.box("glow_warm", p, (p[0] + 0.18, p[1] + 0.18, p[2] + 0.18))

# ------------------------------------------------------------------ the goliath gantry crane
for gx in (2.0, 6.8):
    for gz in (-5.6, 5.2):
        m.box("paint", (gx - 0.18, Q + 0.4, gz - 0.18), (gx + 0.18, 11.0, gz + 0.18), bevel=0.02, seg=1, tint=GOLD)
        m.box("dark", (gx - 0.5, Q, gz - 0.4), (gx + 0.5, Q + 0.5, gz + 0.4), bevel=0.04, seg=1)
    m.box("paint", (gx - 0.2, 10.8, -5.8), (gx + 0.2, 11.2, 5.4), bevel=0.02, seg=1, tint=GOLD)
    beam(m, (gx, 3.0, -5.6), (gx, 10.0, 5.2), 0.05, "paint", GOLD)
    beam(m, (gx, 3.0, 5.2), (gx, 10.0, -5.6), 0.05, "paint", GOLD)
for gz in (-5.6, 5.2):
    m.box("paint", (1.8, 10.8, gz - 0.2), (7.0, 11.2, gz + 0.2), bevel=0.02, seg=1, tint=GOLD)
m.box("paint", (2.0, 11.2, -0.2), (6.8, 11.6, 0.2), bevel=0.02, seg=1, tint=GOLD)
m.box(DARK, (3.7, 10.6, -0.8), (5.1, 11.2, 0.8), bevel=0.03, seg=1)
for cx in (-0.35, 0.35):
    m.pipe(DARK, (4.4 + cx, 10.6, 0.0), (4.4 + cx, 6.0, 0.0), 0.02, 4)
m.box(DARK, (4.2, 5.7, -0.2), (4.6, 6.0, 0.2), bevel=0.02, seg=1)
m.cyl("glow_red", (2.0, 11.2, -5.6), 0.12, 0.3, 8)

# ------------------------------------------------------------------ the material yard
for i in range(3):
    m.box("metal", (-8.0 + i * 1.9, Q, 4.4), (-6.4 + i * 1.9, Q + 0.5 + i * 0.35, 6.0), bevel=0.02, seg=1, tint=(0.9, 0.85, 0.8))
    for k in range(int((0.5 + i * 0.35) / 0.08)):
        m.box("dark", (-8.0 + i * 1.9, Q + 0.08 * (k + 1) - 0.005, 4.4), (-6.4 + i * 1.9, Q + 0.08 * (k + 1) + 0.005, 6.0 + 0.01))
for k in range(4):
    m.pipe("paint", (-7.8, 0.75 + (k % 2) * 0.35, 7.0 + k * 0.4), (-3.4, 0.75 + (k % 2) * 0.35, 7.0 + k * 0.4), 0.16, 12, tint=hexc("c9972a") if k % 2 == 0 else hexc("8e999e"))
for x in (-7.5, -5.5, -3.5):
    m.box(DARK, (x - 0.08, Q, 6.9), (x + 0.08, 1.2, 8.7), bevel=0.01, seg=1)
m.box(CLAD, (-3.0, Q, 6.4), (-0.8, 2.4, 8.0), bevel=0.03, seg=1)                                # the welding cabin
m.box(CONC, (-3.1, 2.4, 6.3), (-0.7, 2.52, 8.1), bevel=0.03, seg=1)
m.box(GLASS, (-2.6, 1.1, 7.98), (-1.2, 2.0, 8.04))
m.box("glow_green", (-0.82, 1.5, 7.2), (-0.78, 1.7, 7.4))
for p in ((-8.0, 0.0), (0.4, -7.6), (8.0, -7.6)):
    m.pipe(METAL, (p[0], Q, p[1]), (p[0], 6.2, p[1]), 0.06, 8)
    m.box(DARK, (p[0] - 0.6, 6.2, p[1] - 0.17), (p[0] + 0.6, 6.3, p[1] + 0.17), bevel=0.02, seg=1)
    for k in range(2):
        m.box("glow_warm", (p[0] - 0.5 + k * 0.6, 6.17, p[1] - 0.14), (p[0] - 0.2 + k * 0.6, 6.2, p[1] + 0.14))
m.finish(out)
