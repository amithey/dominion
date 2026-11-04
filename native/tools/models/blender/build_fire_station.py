"""The Fire Station, modelled in Blender.   blender -b -P build_fire_station.py -- <out.glb>

A two-storey brick station: three arched appliance bays with roller doors and red engines (a pumper, an aerial ladder and a
rescue truck) drawn up on the apron, a hose-drying tower with a clock and a red beacon, a lit sign, a training yard with a
practice tower and a hydrant, a staff car park, a flagpole and a lawn on a hex plaza. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck
from bl_civic import *
from bl_style import STYLE, apply_style, crown, forecourt

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "fire_station.glb"
m = Model("fire_station")
apply_style(m)
rng = random.Random(161)
ground(m, lawns=False, pave=hexc("c4c4c0"))
RED = hexc("c0392b")
WH = (1.5, 1.5, 1.45)


def engine(x, z, kind, yaw=math.pi):
    """A fire appliance facing the viewer: a red cab and body, chrome and a light bar, a pump panel, ladders or a boom."""
    with m.frame((x, 0, z), yaw=yaw):
        m.box("dark", (-1.0, 0.45, -3.6), (1.0, 0.8, 2.6), bevel=0.04, seg=1)
        m.box("paint", (-1.12, 0.8, 1.0), (1.12, 2.7, 3.0), bevel=0.12, seg=2, tint=RED)                      # the cab
        m.box(GLASS, (-0.95, 1.6, 2.98), (0.95, 2.5, 3.04), tint=(1.4, 1.7, 1.9))
        m.box("glow_red", (-0.8, 2.7, 1.8), (-0.05, 2.82, 2.2))
        m.box("glow_cyan", (0.05, 2.7, 1.8), (0.8, 2.82, 2.2), tint=(0.3, 0.5, 1.0))
        m.box("dark", (-1.15, 0.5, 2.95), (1.15, 0.9, 3.2), bevel=0.04, seg=1)
        m.box("paint", (-1.12, 0.8, -3.4), (1.12, 2.3, 1.0), bevel=0.06, seg=2, tint=RED)                      # the body
        m.box("paint", (-1.14, 1.3, -3.4), (1.14, 1.45, 1.0), tint=hexc("f0eee4"))                              # a white stripe
        for sx in (-1, 1):
            m.box(METAL, (sx * 1.14 - 0.02, 0.9, -3.0), (sx * 1.14 + 0.02, 2.0, -1.4), bevel=0.01, seg=1)       # roller lockers
            for q in range(7):
                m.box("dark", (sx * 1.14 - 0.03, 0.95 + q * 0.15, -2.95), (sx * 1.14 + 0.03, 1.0 + q * 0.15, -1.45))
        for ax in (-2.6, -1.0, 2.2):
            for sx in (-1, 1):
                m.pipe("dark", (sx * 0.78, 0.5, ax), (sx * 1.12, 0.5, ax), 0.5, 14)
                m.pipe(METAL, (sx * 0.78, 0.5, ax), (sx * 1.14, 0.5, ax), 0.22, 10)
        if kind == "ladder":                                                                                   # an aerial ladder lying along the body
            for sx in (-0.4, 0.4):
                m.pipe(METAL, (sx, 2.4, -3.4), (sx, 2.6, 1.6), 0.04, 5)
            for q in range(18):
                m.pipe(METAL, (-0.4, 2.45 + q * 0.01, -3.3 + q * 0.28), (0.4, 2.45 + q * 0.01, -3.3 + q * 0.28), 0.015, 4)
            m.box("dark", (-0.5, 2.3, -3.6), (0.5, 2.5, -3.0), bevel=0.02, seg=1)
        elif kind == "pump":
            m.box("paint", (-0.8, 2.3, -3.2), (0.8, 2.7, 0.6), bevel=0.04, seg=1, tint=hexc("d8d8d0"))
            for q in range(3):
                m.cyl(METAL, (-0.5 + q * 0.5, 2.7, -1.0), 0.12, 0.25, 8)
        else:
            m.box("paint", (-0.9, 2.3, -3.0), (0.9, 3.0, 0.4), bevel=0.05, seg=1, tint=hexc("e8e4d8"))
            m.pipe(METAL, (0.0, 3.0, -2.6), (0.0, 3.5, -0.4), 0.05, 6)
        m.box("glow_warm", (-0.9, 0.55, 3.2), (-0.55, 0.7, 3.24))
        m.box("glow_warm", (0.55, 0.55, 3.2), (0.9, 0.7, 3.24))


# ------------------------------------------------------------------ the station: x -6.5 .. 5.5, z -9 .. -3, two storeys
X0, X1, Z0, Z1 = -6.5, 5.5, -9.0, -3.2
m.box(STONE, (X0 - 0.15, 0.1, Z0 - 0.15), (X1 + 0.15, 0.9, Z1 + 0.15), bevel=0.03, seg=1)
m.box(BRICK, (X0, 0.9, Z0), (X1, 7.0, Z1), bevel=0.02, seg=1)
for k in range(30):
    m.box("dark", (X0, 1.0 + k * 0.2, Z1 - 0.005), (X1, 1.02 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))
m.box(STONE, (X0 - 0.1, 4.3, Z0 - 0.1), (X1 + 0.1, 4.5, Z1 + 0.15), bevel=0.02, seg=1)
m.box(STONE, (X0 - 0.3, 7.0, Z0 - 0.3), (X1 + 0.3, 7.3, Z1 + 0.35), bevel=0.03, seg=2)
m.box("gravel", (X0, 7.3, Z0), (X1, 7.34, Z1), tint=(0.9, 0.9, 0.9))
m.box(STONE, (X0 - 0.2, 7.3, Z1 + 0.1), (X1 + 0.2, 7.9, Z1 + 0.35), bevel=0.03, seg=1)
# three arched bays with roller doors
for k in range(3):
    bx = -4.4 + k * 3.9
    pts = [(math.cos(math.pi * j / 10) * 1.5, 2.6 + math.sin(math.pi * j / 10) * 1.5) for j in range(11)]
    m.box("dark", (bx - 1.5, 0.9, Z1 - 0.02), (bx + 1.5, 2.6, Z1 + 0.02))
    m.hull("dark", [(bx + a, b, Z1 - 0.02) for a, b in pts] + [(bx + a, b, Z1 + 0.02) for a, b in pts])
    m.box("glow_warm", (bx - 1.3, 0.95, Z1 - 0.1), (bx + 1.3, 3.8, Z1 - 0.05), tint=(0.8, 0.75, 0.6))        # the bay lit inside
    for q in range(6):                                                                                          # the door half raised
        m.box(METAL, (bx - 1.4, 3.0 + q * 0.2, Z1), (bx + 1.4, 3.1 + q * 0.2, Z1 + 0.05))
    for a0 in range(10):
        ro, ri = 1.75, 1.5
        pp = [(math.cos(math.pi * a0 / 10) * r, 2.6 + math.sin(math.pi * a0 / 10) * r) for r in (ri, ro)] + [(math.cos(math.pi * (a0 + 1) / 10) * r, 2.6 + math.sin(math.pi * (a0 + 1) / 10) * r) for r in (ri, ro)]
        m.hull(STONE, [(bx + px, py, Z1) for px, py in pp] + [(bx + px, py, Z1 + 0.14) for px, py in pp], tint=(1.1, 1.1, 1.1))
    for sx in (-1, 1):
        m.box(STONE, (bx + sx * 1.65 - 0.12, 0.9, Z1), (bx + sx * 1.65 + 0.12, 2.6, Z1 + 0.16), bevel=0.02, seg=1)
    m.box("hazard", (bx - 1.5, 0.9, Z1 + 0.05), (bx + 1.5, 1.0, Z1 + 0.1))
# upper-storey windows and the lit sign
for k in range(6):
    wx = -5.6 + k * 2.2
    m.box("dark", (wx - 0.45, 5.0, Z1 - 0.03), (wx + 0.45, 6.4, Z1))
    m.box(GLASS, (wx - 0.45, 5.0, Z1), (wx + 0.45, 6.4, Z1 + 0.03), tint=(1.6, 1.8, 2.0))
    m.box("wall_concrete", (wx - 0.02, 5.0, Z1), (wx + 0.02, 6.4, Z1 + 0.06), tint=WH)
    m.box(STONE, (wx - 0.6, 4.9, Z1), (wx + 0.6, 5.0, Z1 + 0.2), bevel=0.01, seg=1)
for sx in (-1, 1):
    for z in (-7.8, -6.0, -4.4):
        with m.frame((X0 if sx < 0 else X1, 0, z), yaw=sx * math.pi / 2):
            m.box("dark", (-0.45, 5.0, -0.03), (0.45, 6.4, 0.0))
            m.box(GLASS, (-0.45, 5.0, 0.0), (0.45, 6.4, 0.03), tint=(1.6, 1.8, 2.0))
m.box("paint", (-1.8, 4.55, Z1 + 0.0), (1.8, 4.95, Z1 + 0.06), tint=RED)
for k in range(11):                                                                                           # "FIRE" as a lit strip of blocks
    m.box("glow_warm", (-1.65 + k * 0.3, 4.62, Z1 + 0.06), (-1.5 + k * 0.3, 4.88, Z1 + 0.09), tint=(1.0, 0.9, 0.7))
# a flat roof with a stair head, vents and an antenna
m.box(BRICK, (3.2, 7.34, Z0 + 0.6), (4.6, 8.6, Z0 + 2.0), bevel=0.03, seg=1)
for k in range(2):
    m.cyl(METAL, (-5.0 + k * 1.4, 7.34, Z0 + 1.2), 0.3, 0.5, 10)
    m.cyl(DARK, (-5.0 + k * 1.4, 7.84, Z0 + 1.2), 0.38, 0.06, 10)
m.pipe(METAL, (-2.0, 7.34, Z0 + 1.2), (-2.0, 10.0, Z0 + 1.2), 0.04, 6)
m.cyl("glow_red", (-2.0, 10.0, Z0 + 1.2), 0.07, 0.15, 8)

# ------------------------------------------------------------------ the hose-drying tower with a clock and a beacon, at the right
TX, TZ = 7.6, -5.4
m.box(BRICK, (TX - 1.4, 0.1, TZ - 1.4), (TX + 1.4, 12.0, TZ + 1.4), bevel=0.03, seg=1)
for k in range(24):
    m.box("dark", (TX - 1.4, 0.4 + k * 0.5, TZ + 1.395), (TX + 1.4, 0.42 + k * 0.5, TZ + 1.42), tint=(0.35, 0.3, 0.28))
for y in (3.0, 6.5, 10.0):
    m.box("dark", (TX - 0.35, y, TZ + 1.39), (TX + 0.35, y + 1.0, TZ + 1.42))
m.box(STONE, (TX - 1.6, 12.0, TZ - 1.6), (TX + 1.6, 12.3, TZ + 1.6), bevel=0.03, seg=2)
m.hull("roof_slate", [(TX - 1.7, 12.3, TZ - 1.7), (TX + 1.7, 12.3, TZ - 1.7), (TX - 1.7, 12.3, TZ + 1.7), (TX + 1.7, 12.3, TZ + 1.7), (TX, 14.0, TZ)])
m.cyl("paint", (TX, 8.2, TZ + 1.4), 0.55, 0.06, 24, tint=hexc("f4f0e4"))
m.pipe(METAL, (TX, 14.0, TZ), (TX, 15.0, TZ), 0.03, 5)
m.cyl("glow_red", (TX, 15.0, TZ), 0.1, 0.2, 8)

# ------------------------------------------------------------------ three engines on the apron, a staff car park, a training yard
engine(-4.4, 1.2, "pump")
engine(-0.5, 0.8, "ladder")
engine(3.4, 1.4, "rescue")
for k in range(5):
    m.box(CONC, (-7.0 + k * 3.7, 0.115, 3.8), (-6.9 + k * 3.7, 0.12, 5.6), tint=(1.8, 1.8, 1.7))
for i, c in enumerate((hexc("e8ecee"), hexc("26384e"))):
    with m.frame((7.0 + i * 0.0, 0, 3.4 + i * 2.8), yaw=math.pi / 2):
        m.box("paint", (-0.85, 0.3, -1.9), (0.85, 0.9, 1.9), bevel=0.15, seg=3, tint=c)
        m.box(GLASS, (-0.74, 0.9, -1.0), (0.74, 1.4, 0.9), bevel=0.1, seg=2)
        for sx in (-1, 1):
            for sz in (-1.2, 1.2):
                m.pipe("dark", (sx * 0.78, 0.33, sz), (sx * 0.96, 0.33, sz), 0.33, 12)
m.box(STONE, (-9.0, 0.1, 1.0), (-6.8, 5.0, 3.0), bevel=0.04, seg=1, tint=(0.95, 0.9, 0.85))                  # a practice tower
for y in (1.6, 3.0, 4.2):
    m.box("dark", (-8.4, y, 3.0), (-7.4, y + 0.8, 3.04))
m.pipe("paint", (-6.8, 0.1, 3.0), (-6.8, 5.0, 3.0), 0.02, 4, tint=hexc("c0392b"))
for k in range(6):
    m.pipe(METAL, (-6.7, 0.6 + k * 0.75, 2.95), (-6.7, 0.6 + k * 0.75, 3.15), 0.015, 4)
for (hx_, hz_) in ((-1.4, 6.4), (5.0, 6.6)):                                                                 # hydrants
    m.cyl("paint", (hx_, 0.13, hz_), 0.15, 0.5, 8, tint=hexc("e0b020"))
    m.dome("paint", (hx_, 0.63, hz_), 0.17, 0.12, 8, 2, tint=hexc("e0b020"))
    m.pipe("paint", (hx_ - 0.2, 0.4, hz_), (hx_ + 0.2, 0.4, hz_), 0.05, 6, tint=hexc("e0b020"))
for p in ((8.8, 8.0), (-8.4, 7.4), (-3.0, 9.2), (3.0, 9.2)):
    tree(m, p[0], p[1], 2.3, 1.0)
for sx in (-1, 1):
    lamp(m, sx * 6.0, 6.4)
flagpole(m, 0.0, 6.8, 8.0)
bench(m, 3.0, 6.4, 0.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, -0.5, 7.34, -6.1, 12.0, 5.8, corners_only=True)
    forecourt(m, 9.4)
m.finish(out)
