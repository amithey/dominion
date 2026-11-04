"""The Market, modelled in Blender.   blender -b -P build_market.py -- <out.glb>

A covered market hall: a long brick hall with a high gabled roof of tile, a lit clerestory, a clock gable over the arched main
entrance and a loading dock at the back; in front a square of striped-awning stalls with crates of produce, barrows, barrels, a
well-head, a delivery cart with a horse-less shafts, a fountain-pump, benches, bunting between lamp posts, trees and a flag on a hex plaza.
Front is +z.
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

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "market.glb"
m = Model("market")
apply_style(m)
rng = random.Random(61)
ground(m, lawns=False, pave=hexc("c9c2b2"))
WH = (1.5, 1.5, 1.45)
AWN = [hexc("c0392b"), hexc("2f6f9e"), hexc("e0b020"), hexc("5a8a46"), hexc("c0392b"), hexc("2f6f9e")]
PRODUCE = [hexc("c0392b"), hexc("e0a020"), hexc("5a8a46"), hexc("8a3a5a"), hexc("d8782a"), hexc("e8d878")]


def stall(x, z, k, yaw=0.0):
    """A market stall: four posts, a sloped striped awning with a scalloped valance, a counter and crates of produce."""
    with m.frame((x, 0, z), yaw=yaw):
        for sx in (-1.2, 1.2):
            m.pipe("wood", (sx, 0.13, -0.9), (sx, 2.7, -0.9), 0.05, 6)
            m.pipe("wood", (sx, 0.13, 0.9), (sx, 2.2, 0.9), 0.05, 6)
        for i in range(8):                                           # awning stripes, alternating colour and cream
            x0 = -1.5 + i * 0.375
            c = AWN[k % len(AWN)] if i % 2 == 0 else hexc("efe9d8")
            m.hull("paint", [(x0, 2.7, -0.95), (x0 + 0.375, 2.7, -0.95), (x0, 2.2, 1.2), (x0 + 0.375, 2.2, 1.2),
                              (x0, 2.74, -0.95), (x0 + 0.375, 2.74, -0.95), (x0, 2.24, 1.2), (x0 + 0.375, 2.24, 1.2)], tint=c)
            m.hull("paint", [(x0, 2.2, 1.2), (x0 + 0.375, 2.2, 1.2), (x0 + 0.19, 1.95, 1.2), (x0, 2.24, 1.2), (x0 + 0.375, 2.24, 1.2), (x0 + 0.19, 1.99, 1.2)], tint=c)
        m.box("wood", (-1.3, 0.13, 0.35), (1.3, 0.95, 0.9), bevel=0.02, seg=1)                  # the counter
        m.box("wood", (-1.35, 0.95, 0.3), (1.35, 1.0, 0.95), bevel=0.01, seg=1, tint=(1.2, 1.1, 1.0))
        for q in range(4):
            cx = -1.0 + q * 0.62
            m.box("wood", (cx - 0.26, 1.0, 0.45), (cx + 0.26, 1.2, 0.85), bevel=0.01, seg=1, tint=(0.9, 0.8, 0.65))
            for u in range(5):                                       # heaped produce
                px = cx - 0.15 + (u % 3) * 0.15
                pz = 0.55 + (u // 3) * 0.2
                m.dome("paint", (px, 1.2, pz), 0.11, 0.1, 8, 2, tint=PRODUCE[(k + q + u) % len(PRODUCE)])
        m.box("wood", (-1.2, 0.13, -0.9), (1.2, 0.2, -0.3), tint=(0.9, 0.8, 0.7))
        for q in range(3):
            m.box("wood", (-1.1 + q * 0.75, 0.2, -0.8), (-0.5 + q * 0.75, 0.7, -0.3), bevel=0.02, seg=1, tint=(0.9, 0.8, 0.65))
        m.box("paint", (-0.8, 1.55, 0.88), (0.8, 1.9, 0.92), tint=hexc("f4efe0"))              # a price board


def barrow(x, z, yaw):
    with m.frame((x, 0, z), yaw=yaw):
        m.box("wood", (-0.4, 0.45, -0.6), (0.4, 0.8, 0.5), bevel=0.04, seg=1)
        m.pipe("dark", (-0.45, 0.3, 0.6), (0.45, 0.3, 0.6), 0.3, 12)
        for sx in (-0.3, 0.3):
            m.pipe("wood", (sx, 0.5, -0.5), (sx, 0.55, -1.4), 0.025, 5)
            m.pipe("wood", (sx, 0.4, 0.5), (sx, 0.13, 0.55), 0.025, 5)
        for u in range(6):
            m.dome("paint", (-0.25 + (u % 3) * 0.25, 0.8, -0.3 + (u // 3) * 0.3), 0.12, 0.1, 8, 2, tint=PRODUCE[u % len(PRODUCE)])


def barrel(x, z, h=0.9):
    m.cyl("wood", (x, 0.13, z), 0.38, h, 14, tint=(0.8, 0.65, 0.5))
    for y in (0.2, h - 0.15):
        m.tube("dark", (x, 0.13 + y, z), 0.4, 0.37, 0.06, 14)


# ------------------------------------------------------------------ the market hall: x +-6.8, z -9.4 .. -3.6
X, Z0, Z1 = 6.8, -9.4, -3.6
m.box(STONE, (-X - 0.2, 0.1, Z0 - 0.2), (X + 0.2, 1.0, Z1 + 0.2), bevel=0.03, seg=1)
m.box(BRICK, (-X, 1.0, Z0), (X, 5.0, Z1), bevel=0.02, seg=1)
for k in range(20):
    m.box("dark", (-X, 1.1 + k * 0.2, Z1 - 0.005), (X, 1.12 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))
for sx in (-X, X - 0.6):
    for k in range(8):
        m.box(STONE, (sx, 1.0 + k * 0.5, Z1 - 0.02), (sx + 0.6 + (0.12 if k % 2 else 0.0), 1.0 + k * 0.5 + 0.44, Z1 + 0.06), bevel=0.01, seg=1)
m.box(STONE, (-X - 0.1, 4.6, Z0 - 0.1), (X + 0.1, 4.8, Z1 + 0.2), bevel=0.02, seg=1)
# the roof: a tiled gable with a lit clerestory ridge
m.hull(TILE, [(-X - 0.5, 5.0, Z0 - 0.5), (X + 0.5, 5.0, Z0 - 0.5), (-X - 0.5, 5.0, Z1 + 0.6), (X + 0.5, 5.0, Z1 + 0.6), (-X - 0.5, 7.4, (Z0 + Z1) / 2), (X + 0.5, 7.4, (Z0 + Z1) / 2)])
m.box(STONE, (-X - 0.55, 4.85, Z0 - 0.55), (X + 0.55, 5.05, Z1 + 0.65), bevel=0.03, seg=1)
for k in range(15):
    xx = -X + 0.4 + k * (2 * X - 0.8) / 14
    m.pipe("metal", (xx, 5.0, Z0 - 0.5), (xx, 7.4, (Z0 + Z1) / 2), 0.02, 4)
    m.pipe("metal", (xx, 5.0, Z1 + 0.6), (xx, 7.4, (Z0 + Z1) / 2), 0.02, 4)
m.box(BRICK, (-X * 0.65, 7.3, (Z0 + Z1) / 2 - 0.9), (X * 0.65, 8.4, (Z0 + Z1) / 2 + 0.9), bevel=0.03, seg=1)    # the clerestory
m.hull(TILE, [(-X * 0.65 - 0.3, 8.4, (Z0 + Z1) / 2 - 1.1), (X * 0.65 + 0.3, 8.4, (Z0 + Z1) / 2 - 1.1), (-X * 0.65 - 0.3, 8.4, (Z0 + Z1) / 2 + 1.1), (X * 0.65 + 0.3, 8.4, (Z0 + Z1) / 2 + 1.1),
                (-X * 0.65 - 0.3, 9.1, (Z0 + Z1) / 2), (X * 0.65 + 0.3, 9.1, (Z0 + Z1) / 2)])
for k in range(8):
    m.box(GLASS, (-X * 0.65 + 0.3 + k * 1.0, 7.6, (Z0 + Z1) / 2 + 0.88), (-X * 0.65 + 1.1 + k * 1.0, 8.2, (Z0 + Z1) / 2 + 0.93), tint=(1.6, 1.8, 2.0))
    m.box("glow_warm", (-X * 0.65 + 0.35 + k * 1.0, 7.7, (Z0 + Z1) / 2 + 0.85), (-X * 0.65 + 1.05 + k * 1.0, 8.1, (Z0 + Z1) / 2 + 0.88), tint=(0.8, 0.7, 0.5))
# the arched main entrance with a clock gable
EZ = Z1
m.box(STONE, (-2.2, 1.0, EZ), (2.2, 6.2, EZ + 0.5), bevel=0.04, seg=1)
pts = [(math.cos(math.pi * k / 10) * 1.6, 3.6 + math.sin(math.pi * k / 10) * 1.6) for k in range(11)]
m.box("dark", (-1.6, 1.0, EZ + 0.48), (1.6, 3.6, EZ + 0.52))
m.hull("dark", [(px, py, EZ + 0.48) for px, py in pts] + [(px, py, EZ + 0.52) for px, py in pts])
for sx in (-1, 1):
    m.box("wood", (sx * 0.8 - 0.78, 1.0, EZ + 0.5), (sx * 0.8 + 0.78, 3.4, EZ + 0.62), bevel=0.03, seg=2, tint=(0.42, 0.28, 0.18))
m.hull(GLASS, [(px * 0.95, py - 0.0, EZ + 0.55) for px, py in pts if py >= 3.6] + [(px * 0.95, py, EZ + 0.6) for px, py in pts if py >= 3.6], tint=(1.6, 1.8, 2.0))
for a0 in range(10):
    ro, ri = 1.9, 1.62
    pp = [(math.cos(math.pi * a0 / 10) * r, 3.6 + math.sin(math.pi * a0 / 10) * r) for r in (ri, ro)] + [(math.cos(math.pi * (a0 + 1) / 10) * r, 3.6 + math.sin(math.pi * (a0 + 1) / 10) * r) for r in (ri, ro)]
    m.hull(STONE, [(px, py, EZ + 0.5) for px, py in pp] + [(px, py, EZ + 0.7) for px, py in pp], tint=(1.1, 1.1, 1.1))
m.box(STONE, (-0.18, 5.4, EZ + 0.5), (0.18, 5.9, EZ + 0.8), bevel=0.02, seg=1)
pediment(m, -2.3, 2.3, 6.2, EZ + 0.5, 1.6, 0.5, role=STONE)
m.cyl("paint", (0.0, 7.0, EZ + 0.55), 0.55, 0.05, 24, tint=hexc("f4f0e4"))
m.box("dark", (-0.03, 6.75, EZ + 0.6), (0.03, 7.4, EZ + 0.64))
m.box("dark", (-0.03, 6.97, EZ + 0.6), (0.4, 7.03, EZ + 0.64))
m.tube("gold", (0.0, 7.0, EZ + 0.56), 0.6, 0.55, 0.08, 24)
for sx in (-1, 1):
    m.box("glow_warm", (sx * 2.5 - 0.1, 2.8, EZ), (sx * 2.5 + 0.1, 3.2, EZ + 0.22))
    for z, fs in ((EZ, 1),):
        for wx in (4.0, 5.6):
            w = sx * wx
            m.box("dark", (w - 0.5, 1.8, EZ - 0.03), (w + 0.5, 3.8, EZ))
            m.hull("dark", [(w + math.cos(math.pi * k / 8) * 0.5, 3.8 + math.sin(math.pi * k / 8) * 0.5, EZ - 0.03) for k in range(9)] + [(w + math.cos(math.pi * k / 8) * 0.5, 3.8 + math.sin(math.pi * k / 8) * 0.5, EZ) for k in range(9)])
            m.box(GLASS, (w - 0.5, 1.8, EZ), (w + 0.5, 3.8, EZ + 0.03), tint=(1.6, 1.8, 2.0))
            m.box(STONE, (w - 0.65, 1.7, EZ), (w + 0.65, 1.8, EZ + 0.25), bevel=0.02, seg=1)
# side windows and a loading dock at the back
for z in (-8.0, -6.2, -4.5):
    for sx in (-1, 1):
        with m.frame((sx * X, 0, z), yaw=sx * math.pi / 2):
            m.box("dark", (-0.5, 1.8, -0.03), (0.5, 3.8, 0.0))
            m.box(GLASS, (-0.5, 1.8, 0.0), (0.5, 3.8, 0.03), tint=(1.6, 1.8, 2.0))
            m.box(STONE, (-0.65, 1.7, 0.0), (0.65, 1.8, 0.25), bevel=0.02, seg=1)
m.box(CONC, (-3.0, 0.1, Z0 - 2.0), (3.0, 1.2, Z0), bevel=0.03, seg=1)
for k in range(3):
    m.box("dark", (-2.5 + k * 1.8, 1.2, Z0 - 0.02), (-1.4 + k * 1.8, 3.4, Z0 + 0.02))
    for q in range(8):
        m.box(METAL, (-2.45 + k * 1.8, 1.25 + q * 0.27, Z0 - 0.04), (-1.45 + k * 1.8, 1.25 + q * 0.27 + 0.1, Z0 - 0.02))

# ------------------------------------------------------------------ the market square
k = 0
for row, z in enumerate((-0.6, 3.0, 6.4)):
    for col, x in enumerate((-6.3, -2.1, 2.1, 6.3) if row != 1 else (-4.2, 0.0, 4.2)):
        stall(x, z, k, yaw=0.0 if row != 1 else math.pi)
        k += 1
barrow(-8.4, 1.2, 0.8)
barrow(8.2, 4.8, -0.6)
for p in ((-8.3, 7.4), (-8.0, 8.1), (8.4, -1.6), (8.0, 8.0)):
    barrel(*p)
# a well-head with a roof in the middle of the square
m.cyl(STONE, (0.0, 0.13, 1.4), 0.7, 0.8, 16)
m.tube(STONE, (0.0, 0.93, 1.4), 0.78, 0.6, 0.1, 16, tint=(1.1, 1.1, 1.1))
m.cyl("glass", (0.0, 0.9, 1.4), 0.6, 0.02, 16)
for sx in (-0.65, 0.65):
    m.pipe("wood", (sx, 0.93, 1.4), (sx, 2.4, 1.4), 0.06, 6)
m.pipe("wood", (-0.65, 2.4, 1.4), (0.65, 2.4, 1.4), 0.06, 6)
m.hull(TILE, [(-0.9, 2.3, 0.9), (0.9, 2.3, 0.9), (-0.9, 2.3, 1.9), (0.9, 2.3, 1.9), (0.0, 2.9, 0.9), (0.0, 2.9, 1.9)])
m.pipe(METAL, (0.0, 2.4, 1.4), (0.0, 1.5, 1.4), 0.012, 3)
m.cyl("wood", (0.0, 1.35, 1.4), 0.12, 0.16, 8)
# bunting between lamp posts
posts = [(-8.6, -1.5), (-4.2, 1.2), (4.2, 1.2), (8.6, -1.5), (-8.6, 8.8), (8.6, 8.8)]
for p in posts:
    lamp(m, p[0], p[1], 4.0)
def bunting(a, b, n=10):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((a[0] + (b[0] - a[0]) * t, 3.9 - 0.45 * math.sin(math.pi * t), a[1] + (b[1] - a[1]) * t))
    m.wire("metal", pts, 0.012, 4)
    for i in range(n):
        t = (i + 0.5) / n
        x, y, z = pts[i][0] * (1 - 0.5) + pts[i + 1][0] * 0.5, (pts[i][1] + pts[i + 1][1]) / 2, pts[i][2] * 0.5 + pts[i + 1][2] * 0.5
        m.hull("paint", [(x - 0.14, y, z - 0.01), (x + 0.14, y, z + 0.01), (x - 0.14, y, z + 0.01), (x + 0.14, y, z - 0.01), (x, y - 0.3, z)], tint=AWN[i % len(AWN)])
bunting(posts[0], posts[1])
bunting(posts[1], posts[2])
bunting(posts[2], posts[3])
bunting(posts[4], posts[5])
for p in ((-9.2, 4.0), (9.2, 1.0), (-9.4, -5.0), (9.5, -7.0), (-3.0, 9.6), (3.0, 9.6)):
    tree(m, p[0], p[1], 2.3, 1.05)
flagpole(m, 8.8, -4.0, 8.0)
if STYLE != "euro":
    crown(m, 0.0, 5.0, -6.5, 13.6, 5.8, corners_only=True)
    forecourt(m, 9.4)
m.finish(out)
