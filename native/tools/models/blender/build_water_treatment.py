"""The Water Treatment works, modelled in Blender.   blender -b -P build_water_treatment.py -- <out.glb>

A municipal works: an elevated water tower on a concrete tripod with a lit cap, two round clarifier tanks with walkways and a
rotating bridge, two rectangular filter beds with water, an aeration pond with fountains, a pump house in brick with an arched
door, chemical dosing tanks with bunds, pipe galleries in teal and red, a settling lagoon, a lab and control building, a van, a
gate house and a fence. Front is +z. Water is blue glass so the game's water role stays out of it.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, slats
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "water_treatment.glb"
m = Model("water_treatment")
rng = random.Random(131)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
TEAL = hexc("2f6f7e")
RED = hexc("c0392b")
WATER = (0.7, 1.1, 1.5)


def pipe_run(a, b, r, tint=TEAL):
    m.pipe("paint", a, b, r, 12, tint=tint)


def clarifier(x, z, r):
    """A round settling tank: a concrete wall, a water surface, a radial bridge with a drive, a centre column, a weir ring."""
    m.tube(CONC, (x, 0.1, z), r + 0.3, r, 1.4, 32, tint=(1.1, 1.1, 1.12))
    m.cyl("glass", (x, 1.15, z), r - 0.02, 0.05, 32, tint=WATER)
    m.tube(CONC, (x, 1.35, z), r - 0.3, r - 0.4, 0.12, 32, tint=(0.9, 0.9, 0.92))
    m.cyl(CONC, (x, 0.1, z), 0.5, 1.7, 16)
    m.box(METAL, (x - r + 0.1, 1.55, z - 0.12), (x + r - 0.1, 1.62, z + 0.12), bevel=0.01, seg=1)           # the bridge
    for sy in (-1, 1):
        m.pipe(METAL, (x - r + 0.1, 1.62, z + sy * 0.12), (x + r - 0.1, 1.62, z + sy * 0.12), 0.02, 4)
        m.pipe(METAL, (x - r + 0.1, 2.1, z + sy * 0.12), (x + r - 0.1, 2.1, z + sy * 0.12), 0.02, 4)
    for k in range(7):
        xx = x - r + 0.4 + k * (2 * r - 0.8) / 6
        m.pipe(METAL, (xx, 1.6, z + 0.12), (xx, 2.1, z + 0.12), 0.015, 4)
        m.pipe(METAL, (xx, 1.6, z - 0.12), (xx, 2.1, z - 0.12), 0.015, 4)
    m.box(DARK, (x + r - 0.6, 1.5, z - 0.3), (x + r - 0.1, 1.9, z + 0.3), bevel=0.03, seg=1)               # the drive motor
    m.cyl(METAL, (x, 1.8, z), 0.35, 0.3, 12)


def filter_bed(x, z, w, d):
    """A rectangular filter bed: a concrete trough, a water surface, a gallery along one side with valves."""
    m.box(CONC, (x - w / 2 - 0.25, 0.1, z - d / 2 - 0.25), (x + w / 2 + 0.25, 1.2, z + d / 2 + 0.25), bevel=0.04, seg=1)
    m.box("glass", (x - w / 2, 1.1, z - d / 2), (x + w / 2, 1.18, z + d / 2), tint=WATER)
    for k in range(5):
        m.box(METAL, (x - w / 2, 1.18, z - d / 2 + 0.3 + k * (d - 0.6) / 4), (x + w / 2, 1.2, z - d / 2 + 0.36 + k * (d - 0.6) / 4), tint=(0.8, 0.8, 0.8))
    m.box(CONC, (x - 0.4, 1.2, z - d / 2 - 0.25), (x + 0.4, 1.5, z + d / 2 + 0.25), bevel=0.02, seg=1)   # a trough across
    for k in range(3):
        wx = x - w / 2 + 0.6 + k * (w - 1.2) / 2
        m.pipe("paint", (wx, 1.2, z + d / 2 + 0.3), (wx, 2.0, z + d / 2 + 0.3), 0.06, 8, tint=RED)
        m.cyl("paint", (wx, 2.0, z + d / 2 + 0.3), 0.14, 0.05, 10, tint=RED)


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))
m.box("asphalt", (-1.2, 0.15, 3.4), (1.2, 0.16, 9.4))
m.box("pavers", (-9.0, 0.15, 2.2), (9.0, 0.18, 3.6))

# ------------------------------------------------------------------ the water tower: a tripod, a tank, a lit cap
WX, WZ = 6.6, -6.4
for k in range(3):
    a = math.tau * k / 3 + 0.5
    m.pipe("paint", (WX + math.cos(a) * 1.7, 0.1, WZ + math.sin(a) * 1.7), (WX + math.cos(a) * 1.1, 11.0, WZ + math.sin(a) * 1.1), 0.22, 10, tint=hexc("b8bcbe"))
for y in (3.5, 7.0, 10.0):
    pts = [(WX + math.cos(math.tau * k / 3 + 0.5) * (1.7 - 0.6 * (y - 0.1) / 11.0), y, WZ + math.sin(math.tau * k / 3 + 0.5) * (1.7 - 0.6 * (y - 0.1) / 11.0)) for k in range(4)]
    for a_, b_ in zip(pts, pts[1:]):
        m.pipe(METAL, a_, b_, 0.05, 5)
m.pipe(METAL, (WX, 0.1, WZ), (WX, 11.0, WZ), 0.22, 10)                                      # the riser
m.lathe("paint", (WX, 11.0, WZ), [(0.0, 0.0), (1.9, 0.0), (2.2, 0.5), (2.35, 1.4), (2.2, 2.4), (1.5, 3.1), (0.5, 3.4), (0.0, 3.5)], 28, tint=hexc("e8ecee"))
m.tube("paint", (WX, 12.4, WZ), 2.38, 2.3, 0.1, 28, tint=TEAL)
m.pipe(METAL, (WX, 14.5, WZ), (WX, 15.6, WZ), 0.04, 5)
m.cyl("glow_red", (WX, 15.6, WZ), 0.09, 0.2, 8)
for y in range(1, 11):
    m.pipe(METAL, (WX + 1.5, y, WZ - 0.05), (WX + 1.5, y, WZ + 0.05), 0.015, 4)

# ------------------------------------------------------------------ clarifiers, filter beds, the aeration pond
clarifier(-5.4, -5.6, 2.9)
filter_bed(0.6, -5.6, 3.4, 2.6)
filter_bed(0.6, -1.6, 3.4, 2.4)
filter_bed(-5.4, -0.2, 2.8, 2.0)
# the aeration pond with fountains (rounded shallow basin)
m.cyl(CONC, (7.0, 0.1, 0.0), 2.6, 0.5, 26, tint=(1.1, 1.1, 1.12))
m.cyl("glass", (7.0, 0.55, 0.0), 2.45, 0.05, 26, tint=WATER)
for k in range(5):
    a = math.tau * k / 5
    m.pipe(METAL, (7.0 + math.cos(a) * 1.3, 0.55, math.sin(a) * 1.3), (7.0 + math.cos(a) * 1.3, 0.9, math.sin(a) * 1.3), 0.05, 6)
    for j in range(5):
        b = math.tau * j / 5
        m.pipe("glass", (7.0 + math.cos(a) * 1.3, 0.9, math.sin(a) * 1.3), (7.0 + math.cos(a) * 1.3 + math.cos(b) * 0.4, 0.5, math.sin(a) * 1.3 + math.sin(b) * 0.4), 0.015, 4, tint=(1.3, 1.5, 1.7))
# pipe gallery connecting them
pipe_run((-2.7, 1.4, -5.6), (-1.1, 1.4, -5.6), 0.14, TEAL)
pipe_run((-2.7, 1.1, -5.9), (-1.1, 1.1, -5.9), 0.1, RED)
pipe_run((2.3, 1.4, -5.6), (4.4, 1.4, -5.6), 0.14, TEAL)
pipe_run((2.3, 1.4, -1.6), (4.4, 1.4, -1.0), 0.14, TEAL)
pipe_run((-3.0, 1.2, -0.2), (-1.1, 1.2, -0.2), 0.12, TEAL)

# ------------------------------------------------------------------ the pump house (brick), dosing tanks on a bund, the lab building
m.box("brick", (-9.0, 0.1, 3.8), (-6.0, 3.6, 7.0), bevel=0.02, seg=1, tint=(0.95, 0.88, 0.85))
for k in range(16):
    m.box("dark", (-9.0, 0.3 + k * 0.2, 7.0 - 0.005), (-6.0, 0.32 + k * 0.2, 7.012), tint=(0.35, 0.3, 0.28))
m.hull(CLAD, [(-9.2, 3.6, 3.6), (-5.8, 3.6, 3.6), (-9.2, 3.6, 7.2), (-5.8, 3.6, 7.2), (-9.2, 4.6, 5.4), (-5.8, 4.6, 5.4)], tint=(0.7, 0.72, 0.75))
pts = [(math.cos(math.pi * k / 8) * 0.7, 2.3 + math.sin(math.pi * k / 8) * 0.7) for k in range(9)]
m.box("dark", (-8.2, 0.1, 7.0 - 0.02), (-6.8, 2.3, 7.0 + 0.02))
m.hull("dark", [(-7.5 + a, b, 7.0 - 0.02) for a, b in pts] + [(-7.5 + a, b, 7.0 + 0.02) for a, b in pts])
for sx in (-1, 1):
    m.box("wood", (-7.5 + sx * 0.35 - 0.33, 0.1, 7.0), (-7.5 + sx * 0.35 + 0.33, 2.2, 7.08), bevel=0.02, seg=1, tint=(0.4, 0.3, 0.22))
for i in range(3):                                                                          # dosing tanks on a bund
    m.cyl("paint", (-3.2 + i * 1.3, 0.3, 6.0), 0.55, 1.8, 16, tint=[hexc("e8ecee"), hexc("e0b020"), hexc("5a8a46")][i])
    m.dome("paint", (-3.2 + i * 1.3, 2.1, 6.0), 0.55, 0.25, 16, 3, tint=[hexc("e8ecee"), hexc("e0b020"), hexc("5a8a46")][i])
m.box(CONC, (-4.1, 0.1, 5.1), (0.6, 0.35, 6.9), bevel=0.03, seg=1)
for i in range(3):
    m.pipe(METAL, (-3.2 + i * 1.3, 2.3, 6.0), (-3.2 + i * 1.3, 2.9, 6.0), 0.04, 5)
m.box(CLAD, (2.4, 0.1, 4.2), (6.0, 3.4, 7.2), bevel=0.04, seg=1, tint=hexc("e0e2dc"))                  # the lab and control building
m.box(CONC, (2.3, 3.4, 4.1), (6.1, 3.6, 7.3), bevel=0.03, seg=1)
for k in range(4):
    m.box(GLASS, (2.7 + k * 0.85, 1.3, 7.18), (3.4 + k * 0.85, 2.7, 7.24), tint=(1.4, 1.7, 1.9))
m.box("glow_cyan", (2.7, 2.9, 7.18), (5.9, 3.2, 7.2), tint=(0.5, 0.7, 0.9))
truck(m, 4.2, 1.6, yaw=0.0, canvas=False, bed=1.8, body=hexc("2f6f9e"))
for p in ((-9.0, 2.5), (9.0, 2.5), (-9.0, -9.0), (9.0, -9.2), (0.0, 8.6), (-1.8, -3.5)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
for p in ((-9.2, 0.8), (9.4, 5.0)):
    tree(m, p[0], p[1], 2.2, 1.0)
fence_poly(m, 11.0, gate=(-1.6, 1.6), hazard_every=5, h=1.7)
flagpole(m, 2.0, 8.2, 8.0)
m.finish(out)
