"""Leisure districts, modelled in Blender.   blender -b -P build_leisure.py -- <out.glb> <variant>

Variants (each fills a hex): stadium, park, wharf (fishing wharf). Front is +z. The wharf has its water on +z (the game turns it).
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan
from bl_civic import lamp, flagpole, tree, bench, gable_roof, ground

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "leisure.glb"
VAR = args[1] if len(args) > 1 else "stadium"
m = Model("leisure_" + VAR)
rng = random.Random(abs(hash(VAR)) % 1000 + 3)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
SEATS = [hexc("c0392b"), hexc("2f6f9e"), hexc("e0b020")]
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)


def ring(role, rx, rz, y0, y1, n=40, tint=(1, 1, 1), skip=None):
    """An elliptical wall ring from y0 to y1 (thin quads)."""
    for k in range(n):
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        if skip and skip(a0):
            continue
        p0 = (math.cos(a0) * rx, math.sin(a0) * rz)
        p1 = (math.cos(a1) * rx, math.sin(a1) * rz)
        m.hull(role, [(p0[0], y0, p0[1]), (p1[0], y0, p1[1]), (p0[0] * 0.97, y0, p0[1] * 0.97), (p1[0] * 0.97, y0, p1[1] * 0.97),
                      (p0[0], y1, p0[1]), (p1[0], y1, p1[1]), (p0[0] * 0.97, y1, p0[1] * 0.97), (p1[0] * 0.97, y1, p1[1] * 0.97)], tint)


if VAR == "stadium":
    m.polygon("turf", [(math.cos(math.radians(30 + 60 * k)) * 11.6, math.sin(math.radians(30 + 60 * k)) * 11.6) for k in range(6)], 0.1, 0.03, tint=hexc("a8a89a"))
    RX, RZ = 9.0, 7.0
    # the pitch with mown stripes, white lines, goals, a centre circle
    m.box("turf", (-4.6, 0.13, -2.9), (4.6, 0.16, 2.9), tint=hexc("4f8a3a"))
    for k in range(8):
        m.box("turf", (-4.6 + k * 1.15, 0.16, -2.9), (-4.6 + k * 1.15 + 0.575, 0.165, 2.9), tint=hexc("5a9a44"))
    for (a, b, c, d) in ((-4.6, -2.9, 4.6, -2.8), (-4.6, 2.8, 4.6, 2.9), (-4.6, -2.9, -4.5, 2.9), (4.5, -2.9, 4.6, 2.9), (-0.05, -2.9, 0.05, 2.9)):
        m.box("paint", (a, 0.165, b), (c, 0.17, d), tint=hexc("f0eee4"))
    m.tube("paint", (0.0, 0.165, 0.0), 0.8, 0.75, 0.005, 24, tint=hexc("f0eee4"))
    for sx in (-1, 1):
        for sz in (-0.5, 0.5):
            m.pipe(METAL, (sx * 4.6, 0.16, sz), (sx * 4.6, 1.0, sz), 0.03, 5)
        m.pipe(METAL, (sx * 4.6, 1.0, -0.5), (sx * 4.6, 1.0, 0.5), 0.03, 5)
        m.pipe(METAL, (sx * 4.6, 1.0, -0.5), (sx * 4.9, 0.16, -0.5), 0.015, 4)
        m.pipe(METAL, (sx * 4.6, 1.0, 0.5), (sx * 4.9, 0.16, 0.5), 0.015, 4)
    # the stands: three raked tiers round an oval, in alternating seat colours, with a concourse wall and aisles
    for tier in range(3):
        f = 1.0 - tier * 0.1
        for k in range(36):
            a0, a1 = math.tau * k / 36, math.tau * (k + 1) / 36
            y0 = 0.15 + tier * 1.2
            ro, ri = f, f - 0.1
            pts = []
            for a in (a0, a1):
                for rr, yy in ((ro, y0), (ri, y0 + 1.2)):
                    pts.append((math.cos(a) * RX * rr, yy, math.sin(a) * RZ * rr))
                    pts.append((math.cos(a) * RX * rr, 0.13, math.sin(a) * RZ * rr))
            m.hull("paint", pts, tint=SEATS[(k + tier) % 3] if (k // 3) % 2 == 0 else hexc("d8d4c8"))
    ring(CONC, RX + 0.1, RZ + 0.1, 0.13, 4.0, 40, tint=(1.1, 1.1, 1.12))                                   # the outer concourse wall
    ring("dark", RX + 0.12, RZ + 0.12, 3.2, 3.5, 40)
    for k in range(20):                                                                                      # arched openings in the wall
        a = math.tau * (k + 0.5) / 20
        if abs(a - math.pi / 2) < 0.2:
            continue
        x, z = math.cos(a) * (RX + 0.12), math.sin(a) * (RZ + 0.12)
        m.box("dark", (x - 0.35, 0.13, z - 0.35), (x + 0.35, 1.8, z + 0.35), yaw=-a + math.pi / 2, about=(x, 0, z))
    # a roofed grandstand on the long side with a lit scoreboard and floodlight masts
    m.box(CLAD, (-6.0, 4.0, -7.4), (6.0, 4.3, -3.6), bevel=0.03, seg=1, tint=hexc("c8ced0"))
    for sx in (-5.6, -1.9, 1.9, 5.6):
        m.pipe(METAL, (sx, 0.13, -7.2), (sx, 4.0, -7.2), 0.1, 8)
    m.box("paint", (-2.0, 4.4, -7.4), (2.0, 5.6, -7.3), tint=hexc("1d252a"))
    m.box("glow_cyan", (-1.8, 4.6, -7.3), (1.8, 5.4, -7.25), tint=(0.5, 0.8, 1.0))
    for k in range(4):
        m.box("glow_warm", (-1.4 + k * 0.7, 4.9, -7.25), (-1.0 + k * 0.7, 5.1, -7.22), tint=(1.0, 0.9, 0.5))
    for (px, pz) in ((-8.2, -6.2), (8.2, -6.2), (-8.2, 6.2), (8.2, 6.2)):
        m.pipe(METAL, (px, 0.13, pz), (px, 10.0, pz), 0.1, 8, r2=0.07)
        m.box(DARK, (px - 0.8, 10.0, pz - 0.3), (px + 0.8, 10.7, pz + 0.3), bevel=0.03, seg=1)
        for q in range(4):
            m.box("glow_warm", (px - 0.7 + q * 0.4, 10.1, pz - 0.28), (px - 0.4 + q * 0.4, 10.6, pz - 0.26), tint=(1.0, 1.0, 0.9))
    for k in range(5):                                                                                       # ticket booths and a flag
        m.box(CLAD, (-4.0 + k * 2.0, 0.13, 8.0), (-3.2 + k * 2.0, 2.2, 8.8), bevel=0.03, seg=1, tint=hexc("d8d4c0"))
        m.box("paint", (-4.0 + k * 2.0, 2.2, 8.0), (-3.2 + k * 2.0, 2.45, 8.9), tint=SEATS[k % 3])
    flagpole(m, 9.4, 4.0, 9.0)
elif VAR == "park":
    ground(m, lawns=False, pave=hexc("b8b6a2"))
    m.polygon("turf", [(math.cos(math.radians(30 + 60 * k)) * 11.4, math.sin(math.radians(30 + 60 * k)) * 11.4) for k in range(6)], 0.13, 0.03, tint=hexc("6a9a50"))
    for k in range(6):                                                                                       # paths radiating from a fountain
        a = math.radians(30 + 60 * k + 30)
        for s in range(7):
            m.box("gravel", (math.cos(a) * (2.6 + s * 1.3) - 0.5, 0.15, math.sin(a) * (2.6 + s * 1.3) - 0.5), (math.cos(a) * (2.6 + s * 1.3) + 0.5, 0.17, math.sin(a) * (2.6 + s * 1.3) + 0.5), yaw=-a)
    m.cyl("stone", (0.0, 0.13, 0.0), 2.4, 0.5, 28)
    m.tube("stone", (0.0, 0.63, 0.0), 2.5, 2.2, 0.1, 28, tint=(1.1, 1.1, 1.1))
    m.cyl("glass", (0.0, 0.6, 0.0), 2.2, 0.03, 28, tint=(0.7, 1.1, 1.5))
    m.cyl("stone", (0.0, 0.64, 0.0), 0.5, 0.5, 12)
    m.cyl("stone", (0.0, 1.14, 0.0), 0.2, 1.3, 10)
    m.lathe("stone", (0.0, 2.4, 0.0), [(0.0, 0.0), (0.8, 0.0), (0.9, 0.12), (0.4, 0.26), (0.0, 0.26)], 16)
    for k in range(8):
        a = math.tau * k / 8
        m.pipe("glass", (math.cos(a) * 0.3, 2.65, math.sin(a) * 0.3), (math.cos(a) * 1.4, 0.7, math.sin(a) * 1.4), 0.015, 4)
    # a bandstand
    BX, BZ = 6.0, -5.0
    m.cyl("stone", (BX, 0.13, BZ), 2.2, 0.5, 8)
    for k in range(8):
        a = math.tau * k / 8
        m.pipe("wood", (BX + math.cos(a) * 1.9, 0.63, BZ + math.sin(a) * 1.9), (BX + math.cos(a) * 1.9, 3.1, BZ + math.sin(a) * 1.9), 0.07, 6)
    m.cyl("roof_slate", (BX, 3.1, BZ), 2.4, 1.3, 8, r2=0.0)
    m.pipe("gold", (BX, 4.4, BZ), (BX, 5.0, BZ), 0.04, 6, r2=0.012)
    m.tube("wood", (BX, 0.63, BZ), 1.95, 1.9, 0.9, 8, tint=(0.9, 0.85, 0.75))
    # a pond with a bridge and ducks
    m.cyl("glass", (-5.8, 0.13, 4.6), 2.8, 0.05, 28, tint=(0.7, 1.1, 1.5))
    m.tube("stone", (-5.8, 0.1, 4.6), 2.95, 2.75, 0.12, 28)
    for sx in (-1, 1):
        m.wire("wood", [(-7.9 + 0.0, 0.5, 4.6 + sx * 0.5), (-5.8, 1.1, 4.6 + sx * 0.5), (-3.7, 0.5, 4.6 + sx * 0.5)], 0.04, 6)
    m.box("wood", (-7.9, 0.45, 4.2), (-3.7, 0.52, 5.0), bevel=0.01, seg=1)
    for k in range(4):
        m.dome("paint", (-6.4 + k * 0.9, 0.18, 3.2 + (k % 2) * 1.4), 0.18, 0.12, 8, 2, tint=hexc("f0eee4"))
    for k in range(5):
        m.dome("leaf", (-7.0 + k * 1.1, 0.18, 6.8), 0.3, 0.05, 8, 2, tint=hexc("3f7a3c"))
    # a playground, benches, flower beds, trees and lamps
    m.box("sandbag", (2.8, 0.13, 5.0), (5.6, 0.28, 7.6), tint=hexc("e0d0a0"))
    for sx in (3.4, 5.0):
        m.pipe("paint", (sx, 0.13, 6.0), (sx, 2.4, 6.0), 0.05, 6, tint=hexc("c0392b"))
    m.pipe("paint", (3.4, 2.4, 6.0), (5.0, 2.4, 6.0), 0.04, 6, tint=hexc("c0392b"))
    for sx in (3.7, 4.7):
        m.wire("paint", [(sx, 2.4, 6.0), (sx, 0.7, 6.0)], 0.01, 4, tint=hexc("2f6f9e"))
        m.box("wood", (sx - 0.2, 0.6, 5.9), (sx + 0.2, 0.7, 6.1), tint=hexc("2f6f9e"))
    for (fx, fz, c) in ((-2.4, -6.4, "c0392b"), (2.4, -7.4, "e0b020"), (-7.6, -2.6, "8a3a5a"), (7.6, 1.4, "e8ecee")):
        m.cyl("stone", (fx, 0.13, fz), 1.0, 0.3, 14)
        for k in range(10):
            a = math.tau * k / 10
            m.dome("leaf", (fx + math.cos(a) * 0.55, 0.43, fz + math.sin(a) * 0.55), 0.18, 0.22, 6, 2, tint=hexc(c))
    for k in range(6):
        a = math.radians(30 + 60 * k + 30)
        bench(m, math.cos(a) * 4.4, math.sin(a) * 4.4, -a + math.pi / 2)
    for p in ((-8.8, -6.4), (8.8, -3.0), (8.6, 7.0), (-3.0, -9.2), (0.0, 9.4), (-9.2, 0.4), (3.4, -9.0)):
        tree(m, p[0], p[1], 3.0, 1.3)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
else:   # wharf
    m.box("wood", (-1.6, 0.1, -2.0), (1.6, 0.4, 11.0), bevel=0.01, seg=1, tint=hexc("a08060"))
    for k in range(24):
        m.box("wood", (-1.6, 0.4, -1.9 + k * 0.55), (1.6, 0.43, -1.9 + k * 0.55 + 0.46), tint=hexc("8a6a48") if k % 2 else hexc("9a7a58"))
    for z in range(-1, 11, 2):
        for sx in (-1.5, 1.5):
            m.cyl("wood", (sx, -1.5, z), 0.15, 2.0, 8, tint=hexc("5a4232"))
            m.cyl("wood", (sx, 0.4, z), 0.19, 0.5, 8, tint=hexc("4a3222"))
    m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, -1.0))
    # the net shed
    m.box("wood", (-8.0, 0.15, -8.0), (-2.6, 3.0, -3.0), bevel=0.03, seg=1, tint=hexc("8a6a48"))
    gable_roof(m, -8.0, -2.6, -8.0, -3.0, 3.0, 1.8, overhang=0.4, role="roof_tile")
    m.box("dark", (-6.4, 0.15, -3.02), (-4.2, 2.4, -2.98))
    for k in range(5):
        m.box("wood", (-7.6 + k * 1.0, 1.2, -3.02), (-7.1 + k * 1.0, 2.2, -2.98), tint=hexc("c8b890"))
    m.wire("paint", [(-7.5, 3.0, -2.9), (-6.5, 2.2, -2.9), (-5.5, 2.9, -2.9), (-4.5, 2.2, -2.9), (-3.5, 3.0, -2.9)], 0.02, 4, tint=hexc("c8b890"))
    # boats alongside: hulls lofted
    for bi, (bx, bz, bl, col) in enumerate(((-3.0, 4.0, 3.6, "2f6f9e"), (3.0, 7.0, 3.0, "c0392b"))):
        N = 14
        secs = []
        for i in range(N + 1):
            s = i / N
            hw = 0.55 * (0.75 + 0.25 * math.sin(math.pi * min(1.0, s * 1.4))) * (1.0 - max(0.0, s - 0.6) ** 1.6 * 3.0) if s < 1.0 else 0.02
            hw = max(hw, 0.04)
            z = bz - bl / 2 + bl * s
            secs.append([(bx - hw, 0.65 + 0.15 * s, z), (bx - hw * 0.85, 0.35, z), (bx, 0.18, z), (bx + hw * 0.85, 0.35, z), (bx + hw, 0.65 + 0.15 * s, z)])
        m.loft("paint", secs, outward_from=(bx, 0.45, bz), tint=hexc(col))
        m.loft("wood", [[secs[i][0], secs[i][4]] for i in range(N + 1)], outward_from=(bx, 0.2, bz), tint=hexc("c8b890"))
        m.box("paint", (bx - 0.4, 0.7, bz - 0.6), (bx + 0.4, 1.6, bz + 0.2), bevel=0.04, seg=1, tint=hexc("efe9dc"))
        m.pipe(METAL, (bx, 1.6, bz - 0.2), (bx, 3.2, bz - 0.2), 0.03, 5)
    for k in range(6):                                                                                       # crates, barrels, nets
        m.box("wood", (3.0 + (k % 3) * 0.7, 0.15, -5.0 + (k // 3) * 0.7), (3.6 + (k % 3) * 0.7, 0.75, -4.4 + (k // 3) * 0.7), bevel=0.02, seg=1, tint=hexc("b89868"))
    for k in range(3):
        m.cyl("wood", (6.0 + k * 0.8, 0.15, -6.0), 0.35, 0.9, 12, tint=(0.8, 0.65, 0.5))
    for k in range(4):
        m.pipe("wood", (-1.6 + 0.0, 0.4, 1.0 + k * 2.4), (-1.6, 1.8, 1.0 + k * 2.4), 0.05, 5)
        m.box("glow_warm", (-1.75, 1.8, 0.9 + k * 2.4), (-1.45, 1.9, 1.1 + k * 2.4))
    tree(m, 7.6, -8.0, 2.2, 1.0)
    flagpole(m, -8.6, -1.4, 7.0)
m.finish(out)
