"""The House of Worship, modelled in Blender in five faiths.   blender -b -P build_worship.py -- <out.glb> <variant>

Variants: church, mosque, synagogue, pagoda, mandir. The game picks the one that fits the owning nation. Each stands in a walled
courtyard on a hex plaza with paths, trees and lamps. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_civic import *

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "worship.glb"
VAR = args[1] if len(args) > 1 else "church"
m = Model("worship_" + VAR)
rng = random.Random(abs(hash(VAR)) % 1000 + 5)
ground(m, lawns=False, pave=hexc("c8c2b2"))
m.polygon("turf", [(math.cos(math.radians(30 + 60 * k)) * 11.2, math.sin(math.radians(30 + 60 * k)) * 11.2) for k in range(6)], 0.13, 0.03, tint=hexc("6a9a50"))
m.box("pavers", (-1.6, 0.16, -3.0), (1.6, 0.18, 9.4))
GR = (1.0, 1.0, 1.03)
LIGHTCOL = hexc("f0e8d0")


def arch_win(x, y0, z, w=0.9, h=2.2, facing=1, tint=(1.6, 1.8, 2.0), stained=False):
    pts = [(math.cos(math.pi * k / 8) * w / 2, y0 + h + math.sin(math.pi * k / 8) * w / 2) for k in range(9)]
    zz = z
    m.box("dark", (x - w / 2, y0, zz - 0.03), (x + w / 2, y0 + h, zz))
    m.hull("dark", [(x + a, b, zz - 0.03) for a, b in pts] + [(x + a, b, zz) for a, b in pts])
    col = (1.6, 0.7, 0.5) if stained else tint
    m.box(GLASS, (x - w / 2, y0, zz), (x + w / 2, y0 + h, zz + 0.03), tint=col)
    m.hull(GLASS, [(x + a, b, zz) for a, b in pts] + [(x + a, b, zz + 0.03) for a, b in pts], tint=col)
    m.box("wall_concrete", (x - 0.02, y0, zz), (x + 0.02, y0 + h + w / 2, zz + 0.06), tint=(1.6, 1.6, 1.55))
    for sx in (-1, 1):
        m.box(STONE, (x + sx * (w / 2 + 0.1) - 0.08, y0 - 0.05, zz), (x + sx * (w / 2 + 0.1) + 0.08, y0 + h, zz + 0.14), bevel=0.02, seg=1)
    for a0 in range(8):
        ro, ri = w / 2 + 0.26, w / 2 + 0.04
        pp = [(math.cos(math.pi * a0 / 8) * r, y0 + h + math.sin(math.pi * a0 / 8) * r) for r in (ri, ro)] + [(math.cos(math.pi * (a0 + 1) / 8) * r, y0 + h + math.sin(math.pi * (a0 + 1) / 8) * r) for r in (ri, ro)]
        m.hull(STONE, [(x + px, py, zz) for px, py in pp] + [(x + px, py, zz + 0.12) for px, py in pp])


def spire(x, y, z, w, h, role="roof_slate"):
    m.hull(role, [(x - w, y, z - w), (x + w, y, z - w), (x - w, y, z + w), (x + w, y, z + w), (x, y + h, z)])


def hexagram(c, r, role="gold"):
    """A six-pointed star on a wall facing +z: two triangles."""
    x, y, z = c
    for sgn in (1, -1):
        pts = [(x + math.cos(math.pi / 2 * sgn + math.tau * k / 3) * r, y + math.sin(math.pi / 2 * sgn + math.tau * k / 3) * r) for k in range(3)]
        m.hull(role, [(px, py, z) for px, py in pts] + [(px, py, z + 0.05) for px, py in pts])


def cemetery(x0, z0, n=6):
    for k in range(n):
        xx, zz = x0 + (k % 3) * 1.1, z0 + (k // 3) * 1.1
        m.box(STONE, (xx - 0.25, 0.13, zz - 0.06), (xx + 0.25, 0.9, zz + 0.06), bevel=0.02, seg=1, tint=(0.9, 0.9, 0.9))
        m.box(STONE, (xx - 0.18, 0.62, zz - 0.07), (xx + 0.18, 0.7, zz + 0.07))
        m.box(STONE, (xx - 0.04, 0.4, zz - 0.07), (xx + 0.04, 0.9, zz + 0.07))


if VAR == "church":
    NX0, NX1, NZ0, NZ1 = -2.6, 2.6, -9.2, -1.2
    m.box(STONE, (NX0 - 0.15, 0.1, NZ0 - 0.15), (NX1 + 0.15, 0.7, NZ1 + 0.15), bevel=0.03, seg=1)
    m.box(STONE, (NX0, 0.7, NZ0), (NX1, 5.2, NZ1), bevel=0.03, seg=1, tint=GR)
    gable_roof(m, NX0, NX1, NZ0, NZ1, 5.2, 2.4, overhang=0.35, role="roof_slate")
    for k in range(4):
        for sx in (-1, 1):
            with m.frame((sx * NX1, 0, -7.6 + k * 1.9), yaw=sx * math.pi / 2):
                arch_win(0.0, 1.8, 0.0, 0.8, 2.0, stained=(k % 2 == 0))
            m.box(STONE, (sx * NX1 - 0.15 + sx * 0.15, 0.7, -8.3 + k * 1.9), (sx * NX1 + 0.15 + sx * 0.35, 4.0, -8.0 + k * 1.9), bevel=0.02, seg=1)        # buttresses
    # the west front with a great door and a rose window
    m.box("dark", (-0.8, 0.7, NZ1 - 0.02), (0.8, 3.0, NZ1 + 0.02))
    pts = [(math.cos(math.pi * k / 10) * 0.8, 3.0 + math.sin(math.pi * k / 10) * 0.8) for k in range(11)]
    m.hull("dark", [(a, b, NZ1 - 0.02) for a, b in pts] + [(a, b, NZ1 + 0.02) for a, b in pts])
    for sx in (-1, 1):
        m.box("wood", (sx * 0.4 - 0.38, 0.7, NZ1), (sx * 0.4 + 0.38, 2.9, NZ1 + 0.1), bevel=0.02, seg=1, tint=(0.4, 0.28, 0.2))
    for a0 in range(10):
        ro, ri = 1.05, 0.8
        pp = [(math.cos(math.pi * a0 / 10) * r, 3.0 + math.sin(math.pi * a0 / 10) * r) for r in (ri, ro)] + [(math.cos(math.pi * (a0 + 1) / 10) * r, 3.0 + math.sin(math.pi * (a0 + 1) / 10) * r) for r in (ri, ro)]
        m.hull(STONE, [(px, py, NZ1) for px, py in pp] + [(px, py, NZ1 + 0.14) for px, py in pp])
    with m.frame((0.0, 4.4, NZ1 + 0.01), pitch=math.pi / 2):
        m.cyl(GLASS, (0, 0, 0), 0.7, 0.04, 20, tint=(1.4, 0.8, 0.6))
        m.tube(STONE, (0, 0, 0), 0.8, 0.68, 0.1, 20)
        for k in range(8):
            a = math.tau * k / 8
            m.pipe(STONE, (0, 0.03, 0), (math.cos(a) * 0.7, 0.03, math.sin(a) * 0.7), 0.025, 4)
    # the bell tower with a spire
    TX, TZ = -2.6, -1.0
    m.box(STONE, (TX - 1.2, 0.1, TZ - 1.2), (TX + 1.2, 8.0, TZ + 1.2), bevel=0.03, seg=1, tint=GR)
    for y in (3.0, 5.4):
        m.box("dark", (TX - 0.3, y, TZ + 1.19), (TX + 0.3, y + 1.4, TZ + 1.22))
    for f in range(4):
        with m.frame((TX, 0, TZ), yaw=f * math.pi / 2):
            arch_win(0.0, 6.2, 1.2, 0.9, 1.4, tint=(0.05, 0.05, 0.06))
    m.box(STONE, (TX - 1.35, 8.0, TZ - 1.35), (TX + 1.35, 8.3, TZ + 1.35), bevel=0.03, seg=2)
    spire(TX, 8.3, TZ, 1.3, 5.6)
    m.pipe("gold", (TX, 13.9, TZ), (TX, 14.9, TZ), 0.04, 6)
    m.pipe("gold", (TX - 0.25, 14.4, TZ), (TX + 0.25, 14.4, TZ), 0.03, 5)
    for sx in (-1, 1):
        for sz in (-1, 1):
            spire(TX + sx * 1.15, 8.3, TZ + sz * 1.15, 0.2, 1.3)
    # the apse at the east end, a porch, steps, and a churchyard
    m.cyl(STONE, (0.0, 0.1, NZ0), 1.7, 4.0, 12)
    m.cyl("roof_slate", (0.0, 4.1, NZ0), 1.9, 1.3, 12, r2=0.0)
    steps(m, -1.4, 1.4, NZ1 + 0.1, 3, 0.18, 0.35, role=STONE)
    cemetery(5.0, -5.0, 6)
    cemetery(-8.0, 1.0, 3)
elif VAR == "mosque":
    HX0, HX1, HZ0, HZ1 = -3.8, 3.8, -8.6, -1.6
    m.box(STONE, (HX0 - 0.15, 0.1, HZ0 - 0.15), (HX1 + 0.15, 0.7, HZ1 + 0.15), bevel=0.03, seg=1)
    m.box("plaster", (HX0, 0.7, HZ0), (HX1, 5.2, HZ1), bevel=0.03, seg=1, tint=hexc("f0e8d8"))
    m.box(STONE, (HX0 - 0.1, 5.2, HZ0 - 0.1), (HX1 + 0.1, 5.5, HZ1 + 0.1), bevel=0.03, seg=1)
    DX, DZ = 0.0, -5.1
    m.cyl("plaster", (DX, 5.5, DZ), 3.0, 1.0, 28, tint=hexc("f0e8d8"))                                             # the drum and main dome
    for k in range(12):
        a = math.tau * k / 12
        m.box("dark", (DX + math.cos(a) * 3.0 - 0.2, 5.8, DZ + math.sin(a) * 3.0 - 0.2), (DX + math.cos(a) * 3.0 + 0.2, 6.4, DZ + math.sin(a) * 3.0 + 0.2), yaw=-a, about=(DX + math.cos(a) * 3.0, 0, DZ + math.sin(a) * 3.0))
    m.lathe("copper", (DX, 6.5, DZ), [(0.0, 0.0), (3.05, 0.0), (3.0, 0.8), (2.6, 1.8), (1.9, 2.7), (1.0, 3.3), (0.3, 3.55), (0.0, 3.6)], 32)
    m.pipe("gold", (DX, 10.1, DZ), (DX, 11.2, DZ), 0.05, 6, r2=0.015)
    m.lathe("gold", (DX, 10.5, DZ), [(0.0, 0.0), (0.15, 0.0), (0.2, 0.2), (0.12, 0.4), (0.0, 0.5)], 10)
    for sx in (-1, 1):                                                                                             # semi-domes
        m.lathe("copper", (DX + sx * 3.4, 5.5, DZ), [(0.0, 0.0), (1.4, 0.0), (1.3, 0.7), (0.7, 1.4), (0.0, 1.7)], 20)
    m.lathe("copper", (DX, 5.5, HZ1 + 0.3), [(0.0, 0.0), (1.8, 0.0), (1.6, 0.8), (0.9, 1.6), (0.0, 1.9)], 20)
    # the arched portico along the front
    for k in range(5):
        px = -3.2 + k * 1.6
        m.pipe(STONE, (px, 0.7, HZ1 + 1.0), (px, 3.6, HZ1 + 1.0), 0.14, 10)
        m.box(STONE, (px - 0.2, 3.6, HZ1 + 0.8), (px + 0.2, 3.8, HZ1 + 1.2), bevel=0.02, seg=1)
    for k in range(4):
        px = -2.4 + k * 1.6
        pts = [(px + math.cos(math.pi * j / 8) * 0.8, 3.6 + math.sin(math.pi * j / 8) * 0.55) for j in range(9)]
        m.hull(STONE, [(a, b, HZ1 + 1.0) for a, b in pts] + [(a, b + 0.0, HZ1 + 1.05) for a, b in pts])
    m.box(STONE, (-3.5, 3.9, HZ1 + 0.8), (3.5, 4.2, HZ1 + 1.2), bevel=0.02, seg=1)
    for k in range(7):
        m.cyl("copper", (-3.2 + k * 1.07, 4.2, HZ1 + 1.0), 0.28, 0.5, 10, r2=0.0)
    m.box(STONE, (-3.5, 0.13, HZ1), (3.5, 0.26, HZ1 + 2.4), bevel=0.02, seg=1)
    m.box("dark", (-0.8, 0.7, HZ1 - 0.02), (0.8, 3.0, HZ1 + 0.02))
    for k in range(4):
        for sx in (-1, 1):
            with m.frame((sx * HX1, 0, -7.4 + k * 1.6), yaw=sx * math.pi / 2):
                arch_win(0.0, 1.4, 0.0, 0.8, 2.4, stained=True)
    # two minarets with balconies and pencil caps
    for sx in (-1, 1):
        MXx, MZz = sx * 5.2, -1.2
        m.cyl("plaster", (MXx, 0.1, MZz), 0.65, 3.0, 16, tint=hexc("f0e8d8"))
        m.tube(STONE, (MXx, 3.1, MZz), 0.95, 0.6, 0.2, 16)
        m.cyl("plaster", (MXx, 3.3, MZz), 0.5, 4.6, 16, tint=hexc("f0e8d8"), r2=0.45)
        m.tube(STONE, (MXx, 7.9, MZz), 0.85, 0.5, 0.2, 16)
        for k in range(16):
            a = math.tau * k / 16
            m.pipe(METAL, (MXx + math.cos(a) * 0.82, 7.9, MZz + math.sin(a) * 0.82), (MXx + math.cos(a) * 0.82, 8.5, MZz + math.sin(a) * 0.82), 0.02, 4)
        m.cyl("plaster", (MXx, 8.1, MZz), 0.42, 1.8, 16, tint=hexc("f0e8d8"), r2=0.4)
        m.cyl("copper", (MXx, 9.9, MZz), 0.55, 1.8, 16, r2=0.0)
        m.pipe("gold", (MXx, 11.7, MZz), (MXx, 12.4, MZz), 0.03, 5, r2=0.01)
        m.lathe("gold", (MXx, 12.0, MZz), [(0.0, 0.0), (0.12, 0.0), (0.16, 0.18), (0.0, 0.35)], 8)
        for y in (2.0, 5.2):
            m.box("dark", (MXx - 0.1, y, MZz + 0.5), (MXx + 0.1, y + 0.8, MZz + 0.7))
    # the courtyard fountain for washing, with an arcade
    m.cyl("stone", (0.0, 0.13, 4.6), 1.6, 0.5, 8)
    m.cyl("glass", (0.0, 0.6, 4.6), 1.4, 0.03, 8, tint=(0.7, 1.1, 1.5))
    m.cyl("stone", (0.0, 0.63, 4.6), 0.3, 1.1, 8)
    m.lathe("copper", (0.0, 1.7, 4.6), [(0.0, 0.0), (1.4, 0.0), (1.2, 0.5), (0.0, 1.1)], 8)
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        m.pipe(STONE, (math.cos(a) * 1.35, 0.63, 4.6 + math.sin(a) * 1.35), (math.cos(a) * 1.35, 1.7, 4.6 + math.sin(a) * 1.35), 0.07, 6)
elif VAR == "synagogue":
    HX0, HX1, HZ0, HZ1 = -3.6, 3.6, -8.4, -2.0
    m.box(STONE, (HX0 - 0.15, 0.1, HZ0 - 0.15), (HX1 + 0.15, 0.8, HZ1 + 0.15), bevel=0.03, seg=1)
    m.box(STONE, (HX0, 0.8, HZ0), (HX1, 6.0, HZ1), bevel=0.03, seg=1, tint=(1.05, 1.0, 0.92))
    for k in range(9):
        m.box("dark", (HX0, 1.1 + k * 0.55, HZ1 - 0.01), (HX1, 1.12 + k * 0.55, HZ1 + 0.02), tint=(0.5, 0.5, 0.5))
    m.box(STONE, (HX0 - 0.25, 6.0, HZ0 - 0.25), (HX1 + 0.25, 6.4, HZ1 + 0.3), bevel=0.04, seg=2)
    gable_roof(m, HX0, HX1, HZ0, HZ1, 6.4, 1.8, overhang=0.2, role="roof_slate")
    for i in range(4):                                                                                             # four columns under a pediment
        column(m, -2.4 + i * 1.6, HZ1 + 0.4, 0.8, 5.4, 0.3, STONE)
    m.box(STONE, (-3.2, 5.4, HZ1), (3.2, 5.9, HZ1 + 0.8), bevel=0.03, seg=1)
    pediment(m, -3.4, 3.4, 5.9, HZ1 + 0.8, 1.3, 0.4, role=STONE)
    hexagram((0.0, 7.1, HZ1 + 0.82), 0.5)
    m.box("dark", (-1.0, 0.8, HZ1 - 0.02), (1.0, 3.6, HZ1 + 0.02))
    for sx in (-1, 1):
        m.box("wood", (sx * 0.5 - 0.48, 0.8, HZ1), (sx * 0.5 + 0.48, 3.5, HZ1 + 0.1), bevel=0.02, seg=1, tint=(0.38, 0.26, 0.18))
    for x in (-3.0, 3.0):
        arch_win(x, 2.0, HZ1, 0.9, 2.6, stained=True)
    for k in range(4):
        for sx in (-1, 1):
            with m.frame((sx * HX1, 0, -7.2 + k * 1.5), yaw=sx * math.pi / 2):
                arch_win(0.0, 1.8, 0.0, 0.8, 3.0, stained=(k % 2 == 0))
                hexagram((0.0, 5.3, 0.0), 0.28)
    # a menorah standing before the hall and a courtyard with a canopy (sukkah) of branches
    m.pipe("gold", (-3.0, 0.13, 1.0), (-3.0, 1.8, 1.0), 0.06, 6)
    for k in range(-3, 4):
        m.wire("gold", [(-3.0, 0.9, 1.0), (-3.0 + k * 0.28, 1.1, 1.0), (-3.0 + k * 0.28, 1.9, 1.0)], 0.02, 4)
        m.cyl("glow_warm", (-3.0 + k * 0.28, 1.9, 1.0), 0.05, 0.12, 6)
    m.box("gold", (-3.5, 0.13, 0.8), (-2.5, 0.2, 1.2))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.pipe("wood", (4.4 + sx * 1.3, 0.13, 3.4 + sz * 1.3), (4.4 + sx * 1.3, 2.4, 3.4 + sz * 1.3), 0.05, 6)
    for k in range(9):
        m.pipe("leaf", (3.0, 2.45, 2.1 + k * 0.33), (5.8, 2.45, 2.1 + k * 0.33), 0.04, 5, tint=hexc("3f7a3c"))
    steps(m, -1.2, 1.2, HZ1 + 0.8, 4, 0.2, 0.33, role=STONE)
elif VAR == "pagoda":
    PX, PZ = 0.0, -5.4
    m.box(STONE, (PX - 3.2, 0.1, PZ - 3.2), (PX + 3.2, 0.9, PZ + 3.2), bevel=0.04, seg=1)
    m.box(STONE, (PX - 2.8, 0.9, PZ - 2.8), (PX + 2.8, 1.4, PZ + 2.8), bevel=0.04, seg=1)
    steps(m, -1.2, 1.2, PZ + 2.8, 4, 0.12, 0.3, role=STONE)
    y = 1.4
    for t in range(5):
        w = 2.2 - t * 0.3
        h = 1.7 - t * 0.12
        m.box("paint", (PX - w, y, PZ - w), (PX + w, y + h, PZ + w), bevel=0.02, seg=1, tint=hexc("a8322a"))
        for k in range(3):                                                                                         # lit lattice windows
            m.box("dark", (PX - w * 0.6 + k * w * 0.6, y + 0.35, PZ + w - 0.02), (PX - w * 0.6 + k * w * 0.6 + w * 0.4, y + h - 0.25, PZ + w + 0.02))
            m.box("glow_warm", (PX - w * 0.6 + k * w * 0.6 + 0.04, y + 0.4, PZ + w), (PX - w * 0.6 + k * w * 0.6 + w * 0.4 - 0.04, y + h - 0.3, PZ + w + 0.03), tint=(0.7, 0.55, 0.3))
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.pipe("paint", (PX + sx * w, y, PZ + sz * w), (PX + sx * w, y + h, PZ + sz * w), 0.1, 8, tint=hexc("8a2a20"))
        e = w + 0.9                                                                                                # the upturned eaves
        m.hull("roof_tile", [(PX - e, y + h, PZ - e), (PX + e, y + h, PZ - e), (PX - e, y + h, PZ + e), (PX + e, y + h, PZ + e),
                             (PX - e - 0.5, y + h + 0.45, PZ - e - 0.5), (PX + e + 0.5, y + h + 0.45, PZ - e - 0.5), (PX - e - 0.5, y + h + 0.45, PZ + e + 0.5), (PX + e + 0.5, y + h + 0.45, PZ + e + 0.5),
                             (PX, y + h + 0.9, PZ)], tint=(0.7, 0.75, 0.7))
        m.box(DARK, (PX - e - 0.2, y + h - 0.12, PZ - e - 0.2), (PX + e + 0.2, y + h, PZ + e + 0.2), bevel=0.02, seg=1)
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.cyl("gold", (PX + sx * (e + 0.5), y + h + 0.0, PZ + sz * (e + 0.5)), 0.06, 0.12, 6)
        y += h + 0.5
    m.pipe("gold", (PX, y, PZ), (PX, y + 2.4, PZ), 0.06, 8, r2=0.02)
    for k in range(5):
        m.tube("gold", (PX, y + 0.3 + k * 0.38, PZ), 0.32 - k * 0.05, 0.1, 0.06, 12)
    # a paifang gate, lanterns, a pond with an arched bridge
    for sx in (-1, 1):
        m.pipe("paint", (sx * 2.2, 0.13, 3.4), (sx * 2.2, 3.4, 3.4), 0.18, 10, tint=hexc("a8322a"))
    m.box("paint", (-2.8, 3.4, 3.25), (2.8, 3.8, 3.55), bevel=0.03, seg=1, tint=hexc("a8322a"))
    m.hull("roof_tile", [(-3.2, 3.8, 3.0), (3.2, 3.8, 3.0), (-3.2, 3.8, 3.8), (3.2, 3.8, 3.8), (-3.5, 4.2, 2.8), (3.5, 4.2, 2.8), (-3.5, 4.2, 4.0), (3.5, 4.2, 4.0), (0.0, 4.5, 3.4)], tint=(0.7, 0.75, 0.7))
    m.box("gold", (-1.0, 3.45, 3.56), (1.0, 3.75, 3.6))
    for k in range(4):
        lz = 5.6 + k * 0.8
        for sx in (-1, 1):
            m.cyl(STONE, (sx * 1.8, 0.13, lz), 0.2, 1.0, 6)
            m.box(STONE, (sx * 1.8 - 0.3, 1.13, lz - 0.3), (sx * 1.8 + 0.3, 1.5, lz + 0.3), bevel=0.04, seg=1)
            m.box("glow_warm", (sx * 1.8 - 0.18, 1.2, lz - 0.18), (sx * 1.8 + 0.18, 1.45, lz + 0.18))
    m.cyl("glass", (-6.4, 0.13, 3.0), 2.4, 0.05, 24, tint=(0.7, 1.1, 1.5))
    m.tube("stone", (-6.4, 0.1, 3.0), 2.55, 2.35, 0.14, 24)
    m.wire("stone", [(-8.2, 0.3, 3.0), (-7.2, 0.9, 3.0), (-6.4, 1.1, 3.0), (-5.6, 0.9, 3.0), (-4.6, 0.3, 3.0)], 0.12, 6)
    for k in range(5):
        m.dome("leaf", (-7.0 + k * 0.7, 0.18, 2.0 + (k % 2) * 1.8), 0.28, 0.05, 8, 2, tint=hexc("e0a0a8"))
elif VAR == "mandir":
    MX, MZ = 0.0, -5.2
    m.box(STONE, (MX - 3.6, 0.1, MZ - 3.4), (MX + 3.6, 1.0, MZ + 3.4), bevel=0.04, seg=1, tint=(1.05, 0.95, 0.85))
    steps(m, -1.6, 1.6, MZ + 3.4, 5, 0.18, 0.34, role=STONE)
    m.box("stone", (MX - 3.0, 1.0, MZ - 1.4), (MX + 3.0, 3.6, MZ + 3.0), bevel=0.03, seg=1, tint=(1.1, 0.95, 0.8))              # the mandapa hall
    for k in range(5):
        m.pipe(STONE, (MX - 2.4 + k * 1.2, 1.0, MZ + 3.0), (MX - 2.4 + k * 1.2, 3.4, MZ + 3.0), 0.16, 10)
    m.box("dark", (MX - 0.9, 1.0, MZ + 3.0 - 0.02), (MX + 0.9, 3.0, MZ + 3.02))
    m.box(STONE, (MX - 3.2, 3.6, MZ - 1.5), (MX + 3.2, 3.9, MZ + 3.2), bevel=0.03, seg=2)
    for t in range(4):                                                                                             # a stepped pyramidal roof
        w = 2.8 - t * 0.55
        m.box(STONE, (MX - w, 3.9 + t * 0.5, MZ - 1.0 - w * 0.4), (MX + w, 4.4 + t * 0.5, MZ + 2.8 - t * 0.3), bevel=0.03, seg=1, tint=(1.1, 0.95, 0.8))
    for k in range(5):
        m.dome("gold", (MX - 2.0 + k, 5.9, MZ + 0.8), 0.18, 0.3, 8, 2)
    # the shikhara tower over the sanctum: curved tiers rising to an amalaka and a golden kalasha
    SZ = MZ - 2.2
    m.box(STONE, (MX - 2.0, 1.0, SZ - 2.0), (MX + 2.0, 3.8, SZ + 2.0), bevel=0.04, seg=1, tint=(1.1, 0.95, 0.8))
    y = 3.8
    for t in range(14):
        f = t / 14.0
        w = 2.0 * (1.0 - f) ** 0.8 + 0.25
        h = 0.55
        m.box(STONE, (MX - w, y, SZ - w), (MX + w, y + h, SZ + w), bevel=0.03, seg=1, tint=(1.1 - 0.05 * (t % 2), 0.95, 0.8))
        for sx in (-1, 1):
            if t % 3 == 0:
                m.box("dark", (MX + sx * w - 0.03, y + 0.1, SZ - w * 0.3), (MX + sx * w + 0.03, y + h - 0.1, SZ + w * 0.3))
        y += h
    m.tube(STONE, (MX, y, SZ), 0.55, 0.2, 0.3, 14)
    m.dome(STONE, (MX, y + 0.3, SZ), 0.55, 0.3, 14, 3)
    m.pipe("gold", (MX, y + 0.5, SZ), (MX, y + 1.6, SZ), 0.07, 8, r2=0.02)
    m.lathe("gold", (MX, y + 0.5, SZ), [(0.0, 0.0), (0.3, 0.0), (0.38, 0.3), (0.2, 0.6), (0.0, 0.7)], 12)
    m.pipe("gold", (MX, y + 1.2, SZ), (MX + 0.6, y + 1.0, SZ), 0.01, 4)
    m.box("banner", (MX + 0.02, y + 1.0, SZ), (MX + 0.04, y + 1.5, SZ + 0.9))
    # a flagstaff, a bell, a square tank (kund) with steps and lamps
    m.pipe("gold", (3.8, 0.13, 3.0), (3.8, 4.6, 3.0), 0.06, 6)
    m.box("paint", (3.82, 3.6, 3.0), (3.84, 4.5, 4.0), tint=hexc("e8751a"))
    m.box(STONE, (-9.0, 0.1, 1.4), (-4.6, 0.6, 6.4), bevel=0.03, seg=1)
    m.box("glass", (-8.6, 0.55, 1.8), (-5.0, 0.58, 6.0), tint=(0.7, 1.1, 1.5))
    for k in range(4):
        for sx in (-1, 1):
            m.cyl(STONE, (sx * 2.2, 0.13, 3.8 + k * 1.2), 0.16, 1.2, 6)
            m.dome("gold", (sx * 2.2, 1.33, 3.8 + k * 1.2), 0.2, 0.2, 8, 2)
            m.cyl("glow_warm", (sx * 2.2, 1.45, 3.8 + k * 1.2), 0.1, 0.12, 6)
for p in ((-8.8, -6.4), (8.4, -4.0), (8.6, 6.4), (-3.4, 9.2), (3.4, 9.2), (-9.4, 6.4)):
    tree(m, p[0], p[1], 2.4, 1.1)
for sx in (-1, 1):
    lamp(m, sx * 2.2, 8.2)
    bench(m, sx * 4.2, 6.6, 0.0)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
