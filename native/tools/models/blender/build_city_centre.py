"""The City Centre, modelled in Blender.   blender -b -P build_city_centre.py -- <out.glb> [style]

A city's heart: a stepped civic tower of stone and glass at the back, two mid-rise mixed-use blocks with shopfronts and awnings
either side, a round plaza with a fountain and an obelisk, a bus shelter, a news kiosk, a clock on a pole, benches, lamps and
trees. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "city_centre.glb"
m = Model("city_centre")
rng = random.Random(12)
apply_style(m)
ground(m, lawns=False)

# ------------------------------------------------------------------ the civic tower: three setbacks, glass bands, a crown
m.box(STONE, (-4.6, 0.1, -9.0), (4.6, 5.0, -3.4), bevel=0.04, seg=1)                                           # the base with an arcade
for i in range(5):
    px = -3.6 + i * 1.8
    m.box(STONE, (px - 0.25, 0.1, -3.4), (px + 0.25, 4.0, -2.9), bevel=0.03, seg=1, tint=(1.05, 1.05, 1.05))
m.box(STONE, (-4.8, 4.0, -3.5), (4.8, 4.4, -2.7), bevel=0.03, seg=1)
for i in range(4):
    m.box("dark", (-3.0 + i * 1.8 - 0.55, 0.1, -3.42), (-3.0 + i * 1.8 + 0.55, 3.2, -3.4))
    m.box("glass", (-3.0 + i * 1.8 - 0.5, 0.2, -3.4), (-3.0 + i * 1.8 + 0.5, 3.1, -3.36))
m.box("gold", (-0.7, 3.4, -3.34), (0.7, 3.7, -3.3))
for (x0, x1, z0, z1, y0, y1) in ((-3.8, 3.8, -8.4, -4.0, 5.0, 11.0), (-2.8, 2.8, -7.6, -4.8, 11.0, 16.0), (-1.8, 1.8, -6.8, -5.4, 16.0, 19.5)):
    m.box("cladding", (x0, y0, z0), (x1, y1, z1), bevel=0.03, seg=1, tint=(0.95, 0.97, 1.0))
    ny = int((y1 - y0) / 1.5)
    for k in range(ny):                                                                                        # glass bands
        m.box("glass", (x0 + 0.15, y0 + 0.5 + k * 1.5, z1 - 0.02), (x1 - 0.15, y0 + 1.3 + k * 1.5, z1 + 0.03))
        for sx in (-1, 1):
            m.box("glass", ((x1 if sx > 0 else x0) - 0.02 * sx - 0.03, y0 + 0.5 + k * 1.5, z0 + 0.5), ((x1 if sx > 0 else x0) + 0.03, y0 + 1.3 + k * 1.5, z1 - 0.5))
    m.box(STONE, (x0 - 0.2, y1, z0 - 0.2), (x1 + 0.2, y1 + 0.3, z1 + 0.2), bevel=0.03, seg=1)               # the setback ledge
m.pipe(METAL, (0.0, 19.8, -6.1), (0.0, 24.0, -6.1), 0.08, 8, r2=0.03)
m.cyl("glow_red", (0.0, 24.0, -6.1), 0.1, 0.16, 8)
with m.frame((0.0, 17.8, -5.35), pitch=math.pi / 2):
    m.cyl("paint", (0, 0, 0), 0.8, 0.08, 24, tint=hexc("f4f0e4"))
    m.tube("gold", (0, 0, 0), 0.85, 0.76, 0.1, 24)
m.box("dark", (-0.03, 17.8, -5.3), (0.03, 18.4, -5.26))
m.box("dark", (-0.03, 17.77, -5.3), (0.4, 17.83, -5.26))

# ------------------------------------------------------------------ the mixed-use blocks either side: shops below, flats above
for sx in (-1, 1):
    x0, x1 = (4.4, 8.4) if sx > 0 else (-8.4, -4.4)
    m.box(PLASTER, (x0, 0.1, -6.8), (x1, 8.6, -1.6), bevel=0.03, seg=1, tint=hexc("e8dcc4") if sx > 0 else hexc("d8c4a8"))
    m.box(STONE, (x0 - 0.1, 0.1, -1.7), (x1 + 0.1, 3.0, -1.5), bevel=0.02, seg=1)
    m.box("glass", (x0 + 0.3, 0.5, -1.52), (x1 - 0.3, 2.5, -1.48))
    m.box("paint", (x0 + 0.2, 2.6, -1.55), (x1 - 0.2, 3.0, -1.35), tint=hexc("c0392b") if sx > 0 else hexc("2f6f9e"))
    for k in range(4):                                                                                         # an awning stripe
        m.box("paint", (x0 + 0.3 + k * 0.9, 2.2, -1.55), (x0 + 0.8 + k * 0.9, 2.55, -0.9), tint=hexc("f4f0e4") if k % 2 == 0 else (hexc("c0392b") if sx > 0 else hexc("2f6f9e")))
    for fl in range(3):
        for i in range(3):
            window(m, x0 + 0.7 + i * 1.3, 3.5 + fl * 1.7, -1.6, 0.8, 1.2, 1)
    m.box(STONE, (x0 - 0.2, 8.6, -7.0), (x1 + 0.2, 8.9, -1.4), bevel=0.04, seg=1)
    if STYLE in ("euro", "us"):
        m.box("cladding", (x0 + 1.0, 8.9, -5.8), (x1 - 1.0, 10.0, -3.4), bevel=0.02, seg=1)                      # a lift core on the roof
        m.cyl("cladding", (sx * 7.4, 8.9, -2.6), 0.3, 0.7, 8)
    else:
        crown(m, sx * 6.4, 8.9, -4.3, 4.0, 5.2, corners_only=True)

# ------------------------------------------------------------------ the plaza: a ring fountain, an obelisk, a bus shelter, a kiosk
m.tube(STONE, (0.0, 0.13, 4.0), 3.6, 3.3, 0.5, 32)
m.cyl("glass", (0.0, 0.5, 4.0), 3.3, 0.04, 32, tint=(0.7, 1.1, 1.5))
m.cyl(STONE, (0.0, 0.5, 4.0), 0.9, 0.5, 14)
m.hull(STONE, [(-0.35, 1.0, 3.65), (0.35, 1.0, 3.65), (-0.35, 1.0, 4.35), (0.35, 1.0, 4.35), (-0.12, 6.4, 3.88), (0.12, 6.4, 3.88), (-0.12, 6.4, 4.12), (0.12, 6.4, 4.12)])
m.hull("gold", [(-0.12, 6.4, 3.88), (0.12, 6.4, 3.88), (-0.12, 6.4, 4.12), (0.12, 6.4, 4.12), (0.0, 7.0, 4.0)])
for k in range(8):
    a = math.tau * k / 8
    m.pipe("glass", (math.cos(a) * 2.6, 0.6, 4.0 + math.sin(a) * 2.6), (math.cos(a) * 1.6, 1.6, 4.0 + math.sin(a) * 1.6), 0.02, 4)
# a bus shelter
m.box("glass", (-9.0, 0.9, 1.0), (-6.6, 2.7, 1.05))
m.box("cladding", (-9.2, 2.7, 0.6), (-6.4, 2.85, 1.9), bevel=0.02, seg=1)
for sx in (-9.0, -6.6):
    m.pipe(DARK, (sx, 0.13, 1.0), (sx, 2.7, 1.0), 0.04, 6)
m.box("wood", (-8.6, 0.5, 1.2), (-7.0, 0.58, 1.7))
m.box("glow_cyan", (-8.0, 1.2, 0.96), (-7.2, 1.9, 1.0))
# a news kiosk
m.box("paint", (5.6, 0.13, 6.0), (7.2, 2.4, 7.2), bevel=0.04, seg=1, tint=hexc("2f6f9e"))
m.box("glass", (5.8, 1.0, 7.18), (7.0, 2.0, 7.24))
m.hull("paint", [(5.4, 2.4, 5.8), (7.4, 2.4, 5.8), (5.4, 2.4, 7.4), (7.4, 2.4, 7.4), (6.4, 2.9, 6.6)], tint=hexc("c0392b"))
# a clock on a pole
m.pipe(DARK, (-5.2, 0.13, 6.8), (-5.2, 4.2, 6.8), 0.07, 8)
m.cyl("paint", (-5.2, 4.2, 6.8), 0.45, 0.1, 18, tint=hexc("f4f0e4"))
for p in ((-9.4, 5.0), (9.4, 4.0), (-8.0, 7.0), (7.8, 2.4), (-3.2, 9.6)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-1, 1):
    bench(m, sx * 5.0, 4.2, math.pi / 2)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    forecourt(m, 9.4)
m.finish(out)
