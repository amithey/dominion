"""The Helipad, modelled in Blender.   blender -b -P build_helipad.py -- <out.glb>

A hex apron whose top is at y 0.18 (the game stands helicopters at y 0.18 on the two pads at x = -3.5 and +3.5, z = 0): two
marked and lit pads, an arched hangar with its doors open and lit, an office annex, a control cabin with glass cab and
radar, a fuel point on saddles in a bund, a crash tender, a windsock, floodlights and a front fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import lattice, truck, fan, hazard_ring

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "helipad.glb"
m = Model("helipad")
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
TOP = 0.18
WHITE = (1.7, 1.7, 1.6)

slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.6 + TOP)
m.box("pavers", (-8.2, TOP, -4.2), (8.2, TOP + 0.02, 6.4))
m.box("asphalt", (-8.2, TOP, -10.0), (8.2, TOP + 0.02, -4.2))

# ------------------------------------------------------------------ the two pads
for px in (-3.5, 3.5):
    c = (px, TOP, 0.0)
    m.cyl(CONC, c, 2.9, 0.08, 36, tint=(1.15, 1.15, 1.15))
    m.tube("paint", (px, TOP + 0.08, 0.0), 2.6, 2.45, 0.025, 36, tint=hexc("f0eee4"))
    hazard_ring(m, c, 2.1, 2.3, 0.08, 0.095, 20)
    for sx in (-0.65, 0.65):                                                           # the H
        m.box("paint", (px + sx - 0.14, TOP + 0.08, -0.95), (px + sx + 0.14, TOP + 0.105, 0.95), tint=hexc("f0eee4"))
    m.box("paint", (px - 0.5, TOP + 0.08, -0.14), (px + 0.5, TOP + 0.105, 0.14), tint=hexc("f0eee4"))
    for k in range(16):                                                                # edge lights
        a = math.tau * k / 16.0
        m.cyl("glow_warm", (px + math.cos(a) * 2.78, TOP, math.sin(a) * 2.78), 0.07, 0.1, 8)
    for k in range(4):                                                                 # tie-down rings
        a = math.tau * k / 4.0 + math.pi / 4
        m.tube(METAL, (px + math.cos(a) * 1.5, TOP + 0.08, math.sin(a) * 1.5), 0.1, 0.07, 0.02, 10)
    m.box(CONC, (px - 0.05, TOP + 0.02, -4.2), (px + 0.05, TOP + 0.03, -2.9), tint=(1.0, 0.9, 0.3))   # the taxi line to the hangar

# ------------------------------------------------------------------ the hangar: arched, doors open and lit
HZ0, HZ1, HW = -10.8, -3.2, 4.2
m.cut_box(CLAD, (-HW, TOP, HZ0), (HW, 3.73, HZ1), [[(-3.0, TOP - 0.1, HZ1 + 0.2), (3.0, TOP - 0.1, HZ1 + 0.2), (-3.0, 3.4, HZ1 + 0.2), (3.0, 3.4, HZ1 + 0.2),
                                                       (-3.0, TOP - 0.1, HZ1 - 0.5), (3.0, TOP - 0.1, HZ1 - 0.5), (-3.0, 3.4, HZ1 - 0.5), (3.0, 3.4, HZ1 - 0.5)]], bevel=0.03, seg=1)
m.vault(CLAD, 0.0, HZ0, HZ1, HW, 3.73, 1.7, 16, thick=0.14)
for k in range(9):                                                                     # roof ribs
    z = HZ0 + 0.4 + k * (HZ1 - HZ0 - 0.8) / 8
    pts = [(math.sin(-math.pi / 2 + math.pi * j / 16) * (HW + 0.04), 3.73 + (1.7 + 0.04) * math.cos(-math.pi / 2 + math.pi * j / 16), z) for j in range(17)]
    for a, b in zip(pts, pts[1:]):
        m.pipe(METAL, a, b, 0.04, 4)
m.box(CONC, (-HW - 0.06, TOP, HZ1 - 0.02), (HW + 0.06, 0.75, HZ1 + 0.07), bevel=0.03, seg=1)
for sx in (-1, 1):                                                                     # the sliding doors stacked either side
    m.box(DARK, (sx * 3.0 - (0.0 if sx > 0 else 1.2), TOP + 0.05, HZ1 + 0.02), (sx * 3.0 + (1.2 if sx > 0 else 0.0), 3.4, HZ1 + 0.12), bevel=0.02, seg=1)
    for k in range(5):
        m.box(METAL, (sx * 3.0 + (0.1 + k * 0.22 if sx > 0 else -1.1 + k * 0.22), TOP + 0.1, HZ1 + 0.12), (sx * 3.0 + (0.16 + k * 0.22 if sx > 0 else -1.04 + k * 0.22), 3.35, HZ1 + 0.14))
m.box("hazard", (-3.1, 3.4, HZ1), (3.1, 3.55, HZ1 + 0.2))
m.box("dark", (-3.0, TOP, HZ1 - 0.5), (3.0, 3.4, HZ1 - 0.45))
m.box("glow_warm", (-2.7, 3.2, HZ1 - 0.6), (2.7, 3.28, HZ1 - 0.1))
for k in range(3):
    m.box("glow_warm", (-2.0 + k * 2.0, 2.2, HZ1 + 0.0), (-1.6 + k * 2.0, 2.3, HZ1 + 0.04))
m.box("glow_warm", (-3.5, 5.0, HZ0 + 1.0), (3.5, 5.06, HZ1 - 1.0))                    # the lit ridge strip inside
for k in range(2):
    fan(m, (-1.6 + k * 3.2, 5.43, -7.0), 0.5)
m.box(CLAD, (HW, TOP, -8.4), (HW + 2.2, 2.7, -5.4), bevel=0.03, seg=1)                  # the office annex
m.box(CONC, (HW - 0.1, 2.7, -8.5), (HW + 2.3, 2.85, -5.3), bevel=0.03, seg=1)
for k in range(2):
    m.box(GLASS, (HW + 0.2 + k * 1.0, 1.0, -5.42), (HW + 1.0 + k * 1.0, 2.1, -5.36))
m.pipe(METAL, (-HW + 0.8, TOP, HZ1 + 0.4), (-HW + 0.8, 6.0, HZ1 + 0.4), 0.04, 6)         # the flag
m.box("banner", (-HW + 0.82, 4.9, HZ1 + 0.4), (-HW + 0.84, 5.9, HZ1 + 1.4))

# ------------------------------------------------------------------ the control cabin
m.box(CONC, (6.4, TOP, -5.2), (7.6, 4.4, -4.0), bevel=0.05, seg=1)
m.box(CONC, (6.1, 4.4, -5.5), (7.9, 4.55, -3.7), bevel=0.03, seg=1)
m.hull(GLASS, [(6.2, 4.55, -5.4), (7.8, 4.55, -5.4), (6.2, 4.55, -3.8), (7.8, 4.55, -3.8), (6.0, 5.7, -5.6), (8.0, 5.7, -5.6), (6.0, 5.7, -3.6), (8.0, 5.7, -3.6)])
for cx in (6.1, 6.7, 7.3, 7.9):
    m.pipe(METAL, (cx, 4.55, -5.5), (cx - 0.05 * (cx < 7), 5.7, -5.6), 0.025, 4)
m.box(CONC, (5.9, 5.7, -5.7), (8.1, 5.85, -3.5), bevel=0.03, seg=1)
m.pipe(METAL, (7.0, 5.85, -4.6), (7.0, 6.9, -4.6), 0.04, 6)
m.box(DARK, (6.2, 6.9, -4.65), (7.8, 6.97, -4.55), bevel=0.01, seg=1)                  # the radar bar
m.box("glow_red", (6.9, 7.0, -4.7), (7.1, 7.2, -4.5))
for k in range(4):
    m.box("dark", (6.5 + k * 0.28, 1.0, -4.0), (6.58 + k * 0.28, 3.8, -3.98))          # cladding joints on the shaft

# ------------------------------------------------------------------ fuel point: a tank on saddles in a bund, a dispenser
m.box(CONC, (5.4, TOP, -0.9), (7.9, 0.55, 3.0), bevel=0.03, seg=1)                      # the bund
m.box("asphalt", (5.55, 0.5, -0.75), (7.75, 0.52, 2.85))
m.pipe("paint", (6.6, 1.05, -0.3), (6.6, 1.05, 2.4), 0.7, 20, tint=hexc("dfe4e6"))
for zz, pit in ((-0.3, -math.pi / 2), (2.4, math.pi / 2)):
    with m.frame((6.6, 1.05, zz), pitch=pit):
        m.dome("paint", (0, 0, 0), 0.7, 0.25, 20, 4, tint=hexc("dfe4e6"))
for z in (0.0, 2.0):
    m.box(CONC, (5.9, 0.5, z - 0.15), (7.3, 0.82, z + 0.15), bevel=0.03, seg=1)
m.pipe(METAL, (6.6, 1.75, 1.0), (6.6, 2.2, 1.0), 0.06, 6)
m.cyl(DARK, (6.6, 2.2, 1.0), 0.14, 0.06, 8)
m.box("paint", (8.0, TOP, 0.6), (8.5, 1.6, 1.1), bevel=0.04, seg=1, tint=hexc("c83a2e"))   # the dispenser
m.box("glow_green", (8.05, 1.2, 1.1), (8.45, 1.4, 1.14))
m.wire("dark", [(8.5, 1.1, 0.85), (8.9, 0.8, 0.85), (8.9, 0.35, 1.2), (8.5, 0.3, 1.4)], 0.025, 6)

# ------------------------------------------------------------------ the crash tender
truck(m, -6.0, -2.1, yaw=math.pi / 2, canvas=False, bed=3.4, body=hexc("c0392b"))
m.box("paint", (-7.4, 1.05, -3.15), (-4.8, 1.2, -3.12), tint=hexc("f0eee4"))
m.box("glow_red", (-5.0, 2.05, -2.5), (-4.4, 2.17, -1.7))
m.pipe(METAL, (-7.3, 1.3, -2.1), (-4.9, 1.3, -2.1), 0.06, 6)                              # a monitor nozzle on the roof
m.box("paint", (-6.8, 1.1, -3.2), (-5.6, 1.35, -3.12), tint=hexc("1d252a"))

# ------------------------------------------------------------------ a windsock, floodlights, a low fence, a hydrant
m.pipe(METAL, (-7.4, TOP, 3.6), (-7.4, 5.2, 3.6), 0.05, 8)
for k in range(4):
    m.pipe("paint", (-7.4 + k * 0.62, 5.2 - k * 0.05, 3.6), (-7.4 + (k + 1) * 0.62, 5.15 - k * 0.07 - 0.05, 3.6), 0.34 - k * 0.06, 12, tint=hexc("f08030") if k % 2 == 0 else hexc("f0eee4"), r2=0.34 - (k + 1) * 0.06)
for p in ((-8.0, 5.8), (8.0, 5.8), (8.0, -8.6), (-8.0, -8.6)):
    m.pipe(METAL, (p[0], TOP, p[1]), (p[0], 5.2, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.4, 5.2, p[1] - 0.17), (p[0] + 0.4, 5.3, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.36, 5.17, p[1] - 0.14), (p[0] + 0.36, 5.2, p[1] + 0.14))
for i in range(14):
    fx = -8.1 + i * 1.25
    m.pipe(METAL, (fx, TOP, 6.2), (fx, 1.3, 6.2), 0.03, 6)
for y in (0.5, 1.0):
    m.pipe(DARK, (-8.1, y, 6.2), (8.1, y, 6.2), 0.025, 5)
m.cyl("paint", (3.0, TOP, 3.4), 0.12, 0.6, 8, tint=hexc("c83a2e"))
m.cyl("paint", (3.0, TOP + 0.6, 3.4), 0.16, 0.1, 8, tint=hexc("c83a2e"))
m.finish(out)
