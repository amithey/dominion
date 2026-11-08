"""The Hospital, modelled in Blender.   blender -b -P build_hospital.py -- <out.glb>

A modern four-storey hospital: ribbon windows between white spandrels and vertical fins, a glass atrium entrance under a canopy
with a red cross, an emergency wing with an ambulance bay (canopy, two ambulances with light bars) and a helipad on its roof, a
mechanical penthouse with fans and chillers on the main roof, an oxygen tank, a generator, a car park, trees and lamps, on a hex
plaza. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, slats
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "hospital.glb"
m = Model("hospital")
apply_style(m)
rng = random.Random(23)
ground(m, lawns=False, pave=hexc("cfd2d0"))
CLAD, W_ = "cladding", hexc("f2f2ee")
RED = hexc("c0392b")


def cross(c, s, role="glow_red", facing=0.0):
    """A medical cross: two bars, on a wall facing +z."""
    x, y, z = c
    with m.frame((0, 0, 0), yaw=facing):
        m.box(role, (x - s * 0.16, y - s * 0.5, z), (x + s * 0.16, y + s * 0.5, z + 0.1))
        m.box(role, (x - s * 0.5, y - s * 0.16, z), (x + s * 0.5, y + s * 0.16, z + 0.1))


def car(x, z, tint, yaw=0.0):
    return
    with m.frame((x, 0, z), yaw=yaw):
        m.box("paint", (-0.85, 0.25, -1.9), (0.85, 0.85, 1.9), bevel=0.15, seg=3, tint=tint)
        m.box(GLASS, (-0.74, 0.85, -1.0), (0.74, 1.35, 0.9), bevel=0.12, seg=2)
        m.box("paint", (-0.7, 1.33, -0.9), (0.7, 1.38, 0.8), tint=tint)
        for sx in (-1, 1):
            for sz in (-1.2, 1.2):
                m.pipe("dark", (sx * 0.78, 0.33, sz), (sx * 0.96, 0.33, sz), 0.33, 12)
        m.box("glow_warm", (-0.7, 0.45, 1.9), (-0.4, 0.58, 1.93))
        m.box("glow_warm", (0.4, 0.45, 1.9), (0.7, 0.58, 1.93))


def ambulance(x, z, yaw):
    return
    truck(m, x, z, yaw=yaw, canvas=False, bed=2.6, body=hexc("f4f4f0"))
    with m.frame((x, 0, z), yaw=yaw):
        m.box("paint", (-1.08, 1.1, -0.4), (1.08, 2.45, 2.15), bevel=0.1, seg=2, tint=hexc("f4f4f0"))
        m.box("paint", (-1.1, 1.45, -0.38), (1.1, 1.65, 2.1), tint=RED)
        m.box("glow_red", (-0.7, 2.45, 1.4), (0.7, 2.58, 1.7))
        m.box("glow_cyan", (-0.7, 2.45, 0.0), (0.7, 2.58, 0.3))
    with m.frame((x, 0, z), yaw=yaw + math.pi / 2):
        m.box("glow_red", (-0.12, 1.75, 1.08), (0.12, 2.25, 1.12))
        m.box("glow_red", (-0.4, 1.95, 1.08), (0.4, 2.05, 1.12))


# ------------------------------------------------------------------ the main block: x +-6.5, z -9 .. -3.5, four storeys
X, Z0, Z1, FLOOR = 6.5, -9.0, -3.5, 3.0
BASE = 0.6
TOP = BASE + 4 * FLOOR
m.box(CONC, (-X - 0.2, 0.1, Z0 - 0.2), (X + 0.2, BASE, Z1 + 0.2), bevel=0.04, seg=1)
m.box(CLAD, (-X, BASE, Z0), (X, TOP, Z1), bevel=0.04, seg=1, tint=W_)
for fl in range(4):                                                                                 # ribbon windows, front and back
    y0 = BASE + fl * FLOOR + 0.8
    for face, zz in ((1, Z1), (-1, Z0)):
        m.box(GLASS, (-X + 0.3, y0, zz + (0.0 if face > 0 else -0.03)), (X - 0.3, y0 + 1.5, zz + (0.03 if face > 0 else 0.0)), tint=(2.4, 2.7, 3.0))
        for k in range(12):
            mx = -X + 0.3 + k * (2 * X - 0.6) / 11
            m.box(CLAD, (mx - 0.05, y0, zz - (0 if face > 0 else 0.06)), (mx + 0.05, y0 + 1.5, zz + (0.06 if face > 0 else 0.0)), tint=hexc("c8ced0"))
        m.box(CONC, (-X + 0.25, y0 - 0.1, zz), (X - 0.25, y0, zz + 0.2 * face), bevel=0.02, seg=1, tint=(1.4, 1.4, 1.4))
    for sx in (-1, 1):                                                                              # side windows
        m.box(GLASS, (sx * X - (0.0 if sx > 0 else 0.03), y0, Z0 + 1.0), (sx * X + (0.03 if sx > 0 else 0.0), y0 + 1.5, Z1 - 1.0))
for k in range(9):                                                                                  # vertical fins on the front
    fx = -X + 0.8 + k * (2 * X - 1.6) / 8
    m.box(CLAD, (fx - 0.06, BASE, Z1), (fx + 0.06, TOP, Z1 + 0.35), bevel=0.01, seg=1, tint=(1.05, 1.05, 1.05))
m.box(CONC, (-X - 0.3, TOP, Z0 - 0.3), (X + 0.3, TOP + 0.35, Z1 + 0.3), bevel=0.05, seg=1)           # roof parapet
m.box("gravel", (-X, TOP + 0.35, Z0), (X, TOP + 0.4, Z1), tint=(0.9, 0.9, 0.9))
# the mechanical penthouse: louvres, fans, chillers, a stack and a mast
m.box(CLAD, (-4.5, TOP + 0.4, Z0 + 0.6), (-0.5, TOP + 2.6, Z1 - 1.5), bevel=0.04, seg=1, tint=hexc("dfe4e6"))
slats(m, -4.1, -0.9, TOP + 0.8, TOP + 2.2, Z1 - 1.5, tint=hexc("dfe4e6"))
for k in range(3):
    m.box("dark", (1.0 + k * 1.7, TOP + 0.4, Z0 + 0.8), (2.5 + k * 1.7, TOP + 1.4, Z0 + 2.4), bevel=0.03, seg=1)
    fan(m, (1.75 + k * 1.7, TOP + 1.4, Z0 + 1.6), 0.5)
m.pipe("dark", (-3.5, TOP + 2.6, Z0 + 1.5), (-3.5, TOP + 4.2, Z0 + 1.5), 0.15, 10)
m.cyl("dark", (-3.5, TOP + 4.2, Z0 + 1.5), 0.22, 0.1, 10)
m.pipe(METAL, (5.0, TOP + 0.4, Z0 + 1.0), (5.0, TOP + 4.5, Z0 + 1.0), 0.04, 6)
m.cyl("glow_red", (5.0, TOP + 4.5, Z0 + 1.0), 0.07, 0.15, 8)
cross((0.0, TOP - 1.4, Z1 + 0.36), 1.6)                                                              # the roof-top red cross, lit

# ------------------------------------------------------------------ the glass atrium and the entrance canopy
m.box(CONC, (-2.6, 0.1, Z1), (2.6, 0.35, Z1 + 3.2), bevel=0.03, seg=1)
for gx in range(5):
    for gy in range(3):
        x0 = -2.6 + gx * 1.04
        y0 = 0.35 + gy * 1.6
        t = 0.75 + rng.random() * 0.5
        m.box(GLASS, (x0 + 0.04, y0, Z1 + 3.18), (x0 + 1.0, y0 + 1.56, Z1 + 3.22), tint=(t, t, t))
for sx in (-1, 1):
    for gz in range(3):
        m.box(GLASS, (sx * 2.6 - 0.02, 0.35, Z1 + 0.1 + gz * 1.0), (sx * 2.6 + 0.02, 4.9, Z1 + 1.05 + gz * 1.0))
for k in range(6):
    mx = -2.6 + k * 1.04
    m.box(METAL, (mx - 0.04, 0.35, Z1 + 3.12), (mx + 0.04, 5.2, Z1 + 3.28), bevel=0.01, seg=1)
for y in (0.35, 1.95, 3.55, 5.15):
    m.box(METAL, (-2.6, y, Z1 + 3.12), (2.6, y + 0.06, Z1 + 3.28))
m.box(DARK, (-0.9, 0.35, Z1 + 3.16), (0.9, 2.5, Z1 + 3.22))                                           # the sliding doors
m.box("glow_cyan", (-0.8, 0.4, Z1 + 3.22), (0.8, 2.45, Z1 + 3.24), tint=(0.5, 0.7, 0.8))
m.box(CLAD, (-3.2, 5.2, Z1), (3.2, 5.5, Z1 + 4.6), bevel=0.04, seg=1, tint=W_)                         # the canopy
m.box("paint", (-3.2, 5.2, Z1 + 4.35), (3.2, 5.5, Z1 + 4.6), tint=RED)
for sx in (-1, 1):
    m.pipe(METAL, (sx * 3.0, 0.1, Z1 + 4.2), (sx * 3.0, 5.2, Z1 + 4.2), 0.1, 10)
cross((0.0, 5.35, Z1 + 4.62), 0.28)
m.box("glow_cyan", (-2.8, 5.15, Z1 + 3.4), (2.8, 5.2, Z1 + 4.2))
m.box("paint", (-0.6, 5.6, Z1 + 0.4), (0.6, 6.4, Z1 + 0.45), tint=hexc("2f6f9e"))                       # the hospital sign
m.box("glow_cyan", (-0.12, 5.7, Z1 + 0.45), (0.12, 6.3, Z1 + 0.48))
m.box("glow_cyan", (-0.4, 5.9, Z1 + 0.45), (0.4, 6.1, Z1 + 0.48))
# a ramp and rails
m.hull(CONC, [(3.2, 0.1, Z1 + 3.2), (5.2, 0.1, Z1 + 3.2), (3.2, 0.1, Z1 + 5.2), (5.2, 0.1, Z1 + 5.2), (3.2, 0.35, Z1 + 3.2), (5.2, 0.35, Z1 + 3.2)])

# ------------------------------------------------------------------ the emergency wing with the ambulance bay and the roof helipad
EX0, EX1, EZ0, EZ1 = 6.7, 10.0, -6.5, 0.5
m.box(CLAD, (EX0, BASE, EZ0), (EX1 - 0.3, 4.3, EZ1), bevel=0.04, seg=1, tint=W_)
m.box(GLASS, (EX0, BASE + 0.8, EZ1 - 0.02), (EX1 - 0.3, 3.4, EZ1 + 0.03))
for k in range(5):
    m.box(CLAD, (EX0 + 0.2 + k * 0.62, BASE + 0.8, EZ1 - 0.03), (EX0 + 0.26 + k * 0.62, 3.4, EZ1 + 0.06), tint=hexc("c8ced0"))
m.box("paint", (EX0, 3.5, EZ1 - 0.02), (EX1 - 0.3, 3.8, EZ1 + 0.06), tint=RED)
m.box(CONC, (EX0 - 0.1, 4.3, EZ0 - 0.1), (EX1 - 0.2, 4.55, EZ1 + 0.1), bevel=0.03, seg=1)
HC = (8.2, 4.55, -3.0)
m.cyl("paint", HC, 2.0, 0.08, 32, tint=hexc("5d6468"))                                                  # the helipad
m.tube("paint", (HC[0], HC[1] + 0.08, HC[2]), 1.85, 1.72, 0.02, 32, tint=hexc("f0eee4"))
for sx in (-0.4, 0.4):
    m.box("paint", (HC[0] + sx - 0.09, HC[1] + 0.08, HC[2] - 0.6), (HC[0] + sx + 0.09, HC[1] + 0.1, HC[2] + 0.6), tint=hexc("f0eee4"))
m.box("paint", (HC[0] - 0.4, HC[1] + 0.08, HC[2] - 0.09), (HC[0] + 0.4, HC[1] + 0.1, HC[2] + 0.09), tint=hexc("f0eee4"))
for k in range(12):
    a = math.tau * k / 12
    m.cyl("glow_warm", (HC[0] + math.cos(a) * 2.05, HC[1], HC[2] + math.sin(a) * 2.05), 0.06, 0.12, 8)
BZ = EZ1
m.box(CLAD, (EX0 - 0.6, 3.7, BZ), (EX1, 4.0, BZ + 4.2), bevel=0.04, seg=1, tint=W_)                    # the ambulance bay canopy
m.box("paint", (EX0 - 0.6, 3.7, BZ + 3.95), (EX1, 4.0, BZ + 4.2), tint=RED)
for px, pz in ((EX0 - 0.5, BZ + 4.0), (EX1 - 0.2, BZ + 4.0)):
    m.pipe(METAL, (px, 0.1, pz), (px, 3.7, pz), 0.09, 8)
m.box("glow_cyan", (EX0 - 0.4, 3.65, BZ + 0.2), (EX1 - 0.2, 3.7, BZ + 3.8))
m.box("paint", (EX0 - 0.1, 3.0, BZ + 4.22), (EX0 + 2.0, 3.6, BZ + 4.25), tint=hexc("2f6f9e"))
cross((EX0 + 1.0, 3.3, BZ + 4.25), 0.4, "glow_red")
ambulance(7.8, 2.6, math.pi)

# ------------------------------------------------------------------ left: a pharmacy/cafe pavilion, oxygen tank, generator
m.box(CLAD, (-9.4, 0.1, -6.0), (-6.7, 3.4, -2.0), bevel=0.04, seg=1, tint=W_)
m.box(GLASS, (-9.4, 0.8, -2.03), (-6.7, 2.8, -1.97))
for k in range(5):
    m.box(CLAD, (-9.4 + k * 0.7, 0.8, -2.04), (-9.35 + k * 0.7, 2.8, -1.96), tint=hexc("c8ced0"))
m.box("paint", (-9.5, 3.4, -6.1), (-6.6, 3.6, -1.8), bevel=0.03, seg=1, tint=hexc("2f6f9e"))
m.cyl("paint", (-8.5, 0.1, -9.5), 0.8, 3.0, 20, tint=hexc("e8ecee"))                                      # a cryogenic oxygen tank
m.dome("paint", (-8.5, 3.1, -9.5), 0.8, 0.4, 20, 4, tint=hexc("e8ecee"))
for y in (0.8, 1.8, 2.6):
    m.tube("paint", (-8.5, y, -9.5), 0.83, 0.78, 0.05, 20, tint=hexc("8a949a"))
m.box(CLAD, (-9.6, 0.1, -9.2), (-9.0, 1.2, -8.2), bevel=0.03, seg=1)

# ------------------------------------------------------------------ the car park, trees, lamps, flag
for i, c in enumerate((hexc("e8ecee"), hexc("26384e"), hexc("a8322a"))):
    car(-6.0 + i * 2.4, 5.4, c, yaw=math.pi)
for k in range(4):
    m.box(CONC, (-7.1 + k * 2.4, 0.115, 3.6), (-7.0 + k * 2.4, 0.125, 7.2), tint=(1.8, 1.8, 1.7))
for p in ((-9.0, 1.0), (3.0, 8.5), (5.0, 8.5), (-2.0, 9.0), (9.0, 6.0), (-9.4, 7.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-1, 1):
    lamp(m, sx * 3.8, Z1 + 3.0)
bench(m, 4.0, 3.2, 0.0)
bench(m, -3.0, 3.2, 0.0)
flagpole(m, 1.0, 6.5, 7.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, 0.0, 13.0, -6.25, 13.0, 5.5, corners_only=True)
    forecourt(m, 9.4)
m.finish(out)
