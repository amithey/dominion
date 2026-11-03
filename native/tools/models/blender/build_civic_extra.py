"""More civic buildings, modelled in Blender.   blender -b -P build_civic_extra.py -- <out.glb> <variant>

Variants: lighthouse (water on +z), prison, embassy, stockExchange. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fence_poly, watch_tower, fan, hazard_ring
from bl_civic import *

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "extra.glb"
VAR = args[1] if len(args) > 1 else "lighthouse"
m = Model("extra_" + VAR)
rng = random.Random(abs(hash(VAR)) % 1000 + 9)
CLAD, DARK = "cladding", "steel_dark"


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def window(x, y, z, w=0.9, h=1.4, tint=(1.6, 1.8, 2.0)):
    m.box("dark", (x - w / 2, y, z - 0.03), (x + w / 2, y + h, z))
    m.box(GLASS, (x - w / 2, y, z), (x + w / 2, y + h, z + 0.03), tint=tint)
    m.box("wall_concrete", (x - 0.02, y, z), (x + 0.02, y + h, z + 0.06), tint=(1.5, 1.5, 1.45))
    m.box(STONE, (x - w / 2 - 0.1, y - 0.1, z), (x + w / 2 + 0.1, y, z + 0.2), bevel=0.01, seg=1)


if VAR == "lighthouse":
    slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
    m.polygon("wall_concrete", slab, -1.6, 1.7)
    m.polygon("gravel", [(math.cos(math.radians(30 + 60 * k)) * 11.5, math.sin(math.radians(30 + 60 * k)) * 11.5) for k in range(6)], 0.1, 0.04)

    def rocks(cx, cz, r, h):
        def f(x, z):
            d = ((x - cx) / r) ** 2 + ((z - cz) / r) ** 2
            return -0.03 if d >= 1.0 else h * (1.0 - d) ** 0.6 + 0.3 * noise(x * 2, z * 2) * (1.0 - d)
        m.grid("stone", cx - r, cx + r, cz - r, cz + r, f, 18, 18, base=0.1, tint=(0.8, 0.78, 0.74))
    rocks(0.0, -2.4, 5.4, 1.6)
    # the tower: a tapering lathe with red and white bands, a gallery, a lantern room and a cap
    TX, TZ = 0.0, -2.4
    for b in range(6):
        r0 = 2.3 - b * 0.22
        r1 = 2.3 - (b + 1) * 0.22
        m.cyl("paint", (TX, 1.7 + b * 2.6, TZ), r0, 2.6, 24, r2=r1, tint=hexc("f0eee4") if b % 2 == 0 else hexc("c0392b"))
    for k in range(5):
        a = k * 1.2 + 0.4
    for k in range(5):
        a = k * 1.2 + 0.4
        rr = 2.3 - (1.2 + k * 2.4) / 15.6 * 1.32
        x, z = TX + math.cos(a) * rr, TZ + math.sin(a) * rr
        m.box("dark", (x - 0.15, 3.0 + k * 2.6, z - 0.15), (x + 0.15, 3.7 + k * 2.6, z + 0.15), yaw=-a, about=(x, 0, z))
    GY = 17.3
    m.tube(CONC, (TX, GY, TZ), 2.1, 1.1, 0.3, 24)                                                                 # the gallery deck
    m.cyl(CONC, (TX, GY - 0.4, TZ), 1.5, 0.4, 24, r2=1.2)
    for k in range(24):
        a = math.tau * k / 24
        m.pipe(METAL, (TX + math.cos(a) * 2.05, GY + 0.3, TZ + math.sin(a) * 2.05), (TX + math.cos(a) * 2.05, GY + 1.3, TZ + math.sin(a) * 2.05), 0.025, 4)
    m.tube(METAL, (TX, GY + 1.3, TZ), 2.08, 2.02, 0.04, 24)
    m.tube(METAL, (TX, GY + 0.8, TZ), 2.06, 2.02, 0.03, 24)
    for k in range(8):                                                                                           # the lantern room: glass between mullions
        a0, a1 = math.tau * k / 8, math.tau * (k + 1) / 8
        pts = []
        for a in (a0, a1):
            pts += [(TX + math.cos(a) * 1.1, GY + 0.3, TZ + math.sin(a) * 1.1), (TX + math.cos(a) * 1.1, GY + 2.4, TZ + math.sin(a) * 1.1)]
        m.hull(GLASS, pts, tint=(1.6, 1.8, 2.0))
        m.pipe(METAL, (TX + math.cos(a0) * 1.1, GY + 0.3, TZ + math.sin(a0) * 1.1), (TX + math.cos(a0) * 1.1, GY + 2.4, TZ + math.sin(a0) * 1.1), 0.05, 5)
    m.cyl("glow_warm", (TX, GY + 0.5, TZ), 0.45, 1.5, 14, tint=(1.0, 0.9, 0.55))
    m.cyl("paint", (TX, GY + 0.35, TZ), 0.5, 0.15, 14, tint=hexc("2a2f33"))
    m.cyl("paint", (TX, GY + 2.4, TZ), 1.25, 0.2, 24, tint=hexc("c0392b"))
    m.cyl("paint", (TX, GY + 2.6, TZ), 1.2, 0.7, 24, r2=0.15, tint=hexc("2a2f33"))
    m.pipe("gold", (TX, GY + 3.3, TZ), (TX, GY + 4.1, TZ), 0.05, 6, r2=0.015)
    m.lathe("gold", (TX, GY + 3.3, TZ), [(0.0, 0.0), (0.18, 0.0), (0.2, 0.2), (0.0, 0.4)], 8)
    # the door, the keeper's cottage, the fog horn, a jetty and a boat
    m.box("dark", (-0.5, 1.7, TZ + 2.1), (0.5, 3.4, TZ + 2.3))
    m.box("wood", (-0.45, 1.7, TZ + 2.18), (0.45, 3.3, TZ + 2.3), bevel=0.02, seg=1, tint=(0.4, 0.28, 0.2))
    steps(m, -1.0, 1.0, TZ + 2.2, 4, 0.16, 0.3, role=STONE)
    m.box("plaster", (3.4, 1.6, 2.0), (7.4, 4.0, 5.2), bevel=0.04, seg=1, tint=hexc("f0e8d8"))
    gable_roof(m, 3.4, 7.4, 2.0, 5.2, 4.0, 1.6, overhang=0.3, role="roof_tile")
    m.box("brick", (6.4, 4.0, 2.6), (7.0, 5.8, 3.2), bevel=0.03, seg=1)
    m.marker("Smoke_Home_0", (6.7, 6.0, 2.9))
    for k in range(2):
        window(3.9 + k * 2.4, 2.4, 5.2, 0.8, 1.1)
    m.box("wood", (5.0, 1.6, 5.2), (5.9, 2.9, 5.24), tint=(0.4, 0.28, 0.2))
    m.box("wood", (-1.0, 0.6, 5.8), (1.0, 0.7, 12.0), bevel=0.01, seg=1, tint=hexc("a08060"))                    # a jetty toward the water
    for k in range(5):
        for sx in (-1, 1):
            m.cyl("wood", (sx * 0.95, -1.0, 6.2 + k * 1.3), 0.12, 1.6, 8, tint=hexc("5a4232"))
    m.pipe(METAL, (0.0, 0.7, 11.8), (0.0, 2.0, 11.8), 0.03, 5)
    m.box("glow_red", (-0.1, 2.0, 11.7), (0.1, 2.2, 11.9))
    m.cyl("paint", (-4.4, 1.7, 1.2), 0.4, 0.6, 12, tint=hexc("2a2f33"))                                          # the fog horn
    m.cyl("paint", (-4.4, 2.3, 1.2), 0.5, 0.4, 12, r2=0.15, tint=hexc("c0392b"))
    for k in range(3):
        m.hull("paint", [(-6.4 + k * 0.7, 0.2, 5.6), (-5.8 + k * 0.7, 0.2, 5.6), (-6.4 + k * 0.7, 0.2, 6.9), (-5.8 + k * 0.7, 0.2, 6.9), (-6.1 + k * 0.7, 0.6, 5.8), (-6.1 + k * 0.7, 0.6, 6.7)], tint=hexc("2f6f9e") if k == 0 else hexc("c0392b"))
    flagpole(m, 5.9, 5.6, 6.0)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lamp(m, math.cos(a) * 10.0, math.sin(a) * 10.0, 2.4)
elif VAR == "prison":
    ground(m, lawns=False, pave=hexc("b8b8b4"))
    m.polygon("gravel", [(math.cos(math.radians(30 + 60 * k)) * 11.4, math.sin(math.radians(30 + 60 * k)) * 11.4) for k in range(6)], 0.13, 0.03)
    # the cell block: a long concrete hall with rows of barred windows, a gatehouse tower, an admin wing
    X0, X1, Z0, Z1 = -6.2, 6.2, -8.6, -3.6
    m.box("wall_concrete", (X0 - 0.2, 0.1, Z0 - 0.2), (X1 + 0.2, 0.7, Z1 + 0.2), bevel=0.03, seg=1)
    m.box("wall_concrete", (X0, 0.7, Z0), (X1, 7.4, Z1), bevel=0.04, seg=1, tint=(0.82, 0.82, 0.84))
    for r_ in range(3):
        for k in range(11):
            wx = X0 + 0.9 + k * 1.04
            y = 1.4 + r_ * 1.9
            m.box("dark", (wx - 0.25, y, Z1 - 0.03), (wx + 0.25, y + 0.9, Z1))
            m.box(GLASS, (wx - 0.25, y, Z1), (wx + 0.25, y + 0.9, Z1 + 0.02), tint=(1.2, 1.4, 1.5))
            for q in range(3):
                m.box(METAL, (wx - 0.2 + q * 0.2, y, Z1 + 0.02), (wx - 0.18 + q * 0.2, y + 0.9, Z1 + 0.05))
    m.box("wall_concrete", (X0 - 0.3, 7.4, Z0 - 0.3), (X1 + 0.3, 7.7, Z1 + 0.3), bevel=0.03, seg=1)
    for k in range(5):
        fan(m, (X0 + 1.5 + k * 2.4, 7.7, -6.0), 0.45)
    m.box(CLAD, (-1.8, 7.7, -7.4), (1.8, 9.0, -4.8), bevel=0.04, seg=1, tint=hexc("a8b0b4"))
    for k in range(3):
        m.box("dark", (-1.6 + k * 1.1, 8.0, -4.82), (-0.8 + k * 1.1, 8.8, -4.78))
    # the gate: a sally port with two heavy leaves and a lit sign, flanked by guard towers
    m.box("wall_concrete", (-2.2, 0.7, Z1), (2.2, 5.0, Z1 + 1.0), bevel=0.05, seg=1, tint=(0.95, 0.95, 0.98))
    m.box("dark", (-1.4, 0.7, Z1 + 0.98), (1.4, 3.2, Z1 + 1.02))
    for sx in (-1, 1):
        m.box(DARK, (sx * 0.7 - 0.66, 0.72, Z1 + 1.02), (sx * 0.7 + 0.66, 3.1, Z1 + 1.12), bevel=0.03, seg=1)
        for q in range(7):
            m.pipe(METAL, (sx * 0.7 - 0.55 + q * 0.18, 0.8, Z1 + 1.14), (sx * 0.7 - 0.55 + q * 0.18, 3.0, Z1 + 1.14), 0.025, 4)
    m.box("hazard", (-1.4, 3.3, Z1 + 1.0), (1.4, 3.5, Z1 + 1.1))
    m.box("glow_warm", (-0.8, 4.0, Z1 + 1.0), (0.8, 4.4, Z1 + 1.06), tint=(0.9, 0.85, 0.6))
    # the walled yard in front: a high wall with razor wire and corner towers, an exercise yard with a basketball hoop
    m.box("wall_concrete", (-9.2, 0.1, -3.4), (-9.0, 4.2, 6.6), bevel=0.02, seg=1)
    m.box("wall_concrete", (9.0, 0.1, -3.4), (9.2, 4.2, 6.6), bevel=0.02, seg=1)
    m.box("wall_concrete", (-9.2, 0.1, 6.4), (-2.6, 4.2, 6.6), bevel=0.02, seg=1)
    m.box("wall_concrete", (2.6, 0.1, 6.4), (9.2, 4.2, 6.6), bevel=0.02, seg=1)
    for (x0, z0, x1, z1) in ((-9.1, -3.4, -9.1, 6.5), (9.1, -3.4, 9.1, 6.5), (-9.2, 6.5, -2.6, 6.5), (2.6, 6.5, 9.2, 6.5)):
        m.wire(METAL, [(x0, 4.3, z0), (x1, 4.3, z1)], 0.03, 5)
    for p in ((-9.0, 6.4), (9.0, 6.4), (-9.0, -3.4), (9.0, -3.4)):
        watch_tower(m, p[0] * 0.9, p[1] * 0.9, 5.6)
    m.box("asphalt", (-6.0, 0.13, 0.4), (-0.4, 0.15, 5.4))
    m.pipe(METAL, (-3.2, 0.13, 0.9), (-3.2, 3.0, 0.9), 0.05, 6)
    m.box("paint", (-3.7, 2.7, 0.85), (-2.7, 3.3, 0.95), tint=hexc("f0eee4"))
    m.tube("paint", (-3.2, 2.7, 1.2), 0.2, 0.17, 0.03, 12, tint=hexc("d85a2a"))
    truck(m, 5.6, 2.4, yaw=-math.pi / 2, canvas=False, bed=3.2, body=hexc("2f5a78"))
    for p in ((-3.0, 8.6), (3.0, 8.6)):
        lamp(m, p[0], p[1], 4.0)
    m.pipe(METAL, (0.0, 0.1, 8.0), (0.0, 6.0, 8.0), 0.05, 6)
    m.box("banner", (0.02, 4.8, 8.0), (0.04, 5.9, 9.0))
elif VAR == "embassy":
    ground(m, lawns=True, pave=hexc("d0ccc0"))
    # a formal mansion: a rusticated base, columned portico, wings with balustrades, a hip roof with dormers, flags before it
    X0, X1, Z0, Z1 = -7.0, 7.0, -8.6, -3.6
    m.box(STONE, (X0 - 0.2, 0.1, Z0 - 0.2), (X1 + 0.2, 1.2, Z1 + 0.2), bevel=0.03, seg=1)
    m.box("plaster", (X0, 1.2, Z0), (X1, 7.4, Z1), bevel=0.03, seg=1, tint=hexc("f0e8d8"))
    for fl in range(2):
        for k in range(8):
            wx = X0 + 1.0 + k * 1.72
            if abs(wx) < 1.7:
                continue
            window(wx, 1.9 + fl * 2.9, Z1, 0.9, 1.8)
    m.box(STONE, (X0 - 0.3, 7.4, Z0 - 0.3), (X1 + 0.3, 7.8, Z1 + 0.35), bevel=0.04, seg=2)
    for k in range(25):
        m.cyl(STONE, (X0 - 0.2 + k * (X1 - X0 + 0.4) / 24, 7.8, Z1 + 0.15), 0.07, 0.5, 8)
    m.box(STONE, (X0 - 0.3, 8.3, Z1 + 0.05), (X1 + 0.3, 8.4, Z1 + 0.25), bevel=0.02, seg=1)
    hip_roof(m, X0, X1, Z0, Z1, 7.8, 1.9, overhang=0.0, role="roof_slate")
    for k in range(4):
        dx = -4.5 + k * 3.0
        m.box("plaster", (dx - 0.6, 8.4, Z1 - 1.2), (dx + 0.6, 9.5, Z1 - 0.2), bevel=0.03, seg=1, tint=hexc("f0e8d8"))
        m.hull("roof_slate", [(dx - 0.8, 9.5, Z1 - 1.3), (dx + 0.8, 9.5, Z1 - 1.3), (dx - 0.8, 9.5, Z1 - 0.1), (dx + 0.8, 9.5, Z1 - 0.1), (dx, 10.3, Z1 - 0.7)])
        m.box("dark", (dx - 0.35, 8.7, Z1 - 0.22), (dx + 0.35, 9.4, Z1 - 0.18))
    for i in range(4):
        column(m, -1.9 + i * 1.27, Z1 + 0.5, 1.2, 6.8, 0.28, STONE)
    m.box(STONE, (-2.6, 6.8, Z1), (2.6, 7.3, Z1 + 0.9), bevel=0.03, seg=1)
    pediment(m, -2.8, 2.8, 7.3, Z1 + 0.9, 1.4, 0.4, role=STONE)
    m.cyl("gold", (0.0, 8.3, Z1 + 0.92), 0.4, 0.05, 20)
    m.box("dark", (-1.0, 1.2, Z1 - 0.02), (1.0, 4.4, Z1 + 0.02))
    for sx in (-1, 1):
        m.box("wood", (sx * 0.5 - 0.48, 1.2, Z1), (sx * 0.5 + 0.48, 4.3, Z1 + 0.1), bevel=0.02, seg=1, tint=(0.38, 0.26, 0.18))
    steps(m, -2.2, 2.2, Z1 + 0.9, 6, 0.2, 0.34, role=STONE)
    # the gate: two stone piers with iron railings, a guard booth, five flagpoles and a driveway circle
    for sx in (-1, 1):
        m.box(STONE, (sx * 2.2 - 0.4, 0.13, 8.4), (sx * 2.2 + 0.4, 2.6, 9.2), bevel=0.03, seg=1)
        m.dome("gold", (sx * 2.2, 2.6, 8.8), 0.35, 0.3, 8, 3)
        for k in range(9):
            m.pipe(METAL, (sx * (2.8 + k * 0.7), 0.13, 8.8), (sx * (2.8 + k * 0.7), 1.8, 8.8), 0.03, 5)
            m.pipe(METAL, (sx * (2.8 + k * 0.7), 1.8, 8.8), (sx * (2.8 + k * 0.7), 2.0, 8.8), 0.01, 3)
        m.pipe(METAL, (sx * 2.8, 1.5, 8.8), (sx * 9.0, 1.5, 8.8), 0.03, 5)
    for k in range(5):
        fx = -4.0 + k * 2.0
        m.pipe(METAL, (fx, 0.13, 4.0), (fx, 8.0, 4.0), 0.05, 6)
        m.cyl("gold", (fx, 8.0, 4.0), 0.1, 0.1, 8)
        m.box("banner" if k == 2 else "paint", (fx + 0.02, 6.5, 4.0), (fx + 0.04, 7.8, 5.2), tint=[hexc("c0392b"), hexc("2f6f9e"), (1, 1, 1), hexc("5a8a46"), hexc("e0b020")][k])
    m.cyl("pavers", (0.0, 0.16, 0.8), 3.2, 0.02, 28, tint=hexc("c8c2b2"))
    m.cyl("turf", (0.0, 0.18, 0.8), 1.6, 0.04, 20, tint=hexc("5a8a46"))
    m.cyl("stone", (0.0, 0.18, 0.8), 0.5, 0.5, 12)
    m.box(CLAD, (4.0, 0.1, 7.6), (5.6, 2.4, 8.6), bevel=0.04, seg=1, tint=hexc("d8d4c0"))
    for k in range(2):
        with m.frame((-5.4 + k * 0.0, 0, 3.0 + k * 2.6), yaw=math.pi / 2):
            m.box("paint", (-0.85, 0.3, -1.9), (0.85, 0.9, 1.9), bevel=0.15, seg=3, tint=hexc("1d252a"))
            m.box(GLASS, (-0.74, 0.9, -1.0), (0.74, 1.4, 0.9), bevel=0.1, seg=2)
            for sx in (-1, 1):
                for sz in (-1.2, 1.2):
                    m.pipe("dark", (sx * 0.78, 0.33, sz), (sx * 0.96, 0.33, sz), 0.33, 12)
    for p in ((-9.0, 5.0), (9.0, 5.0), (-9.4, -2.0), (9.4, -2.0)):
        tree(m, p[0], p[1], 2.6, 1.15)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
else:   # stockExchange
    ground(m, lawns=False, pave=hexc("c8c8c4"))
    X0, X1, Z0, Z1 = -6.0, 6.0, -8.6, -3.0
    m.box(STONE, (X0 - 0.3, 0.1, Z0 - 0.3), (X1 + 0.3, 1.4, 0.8), bevel=0.04, seg=2, tint=(1.0, 1.0, 1.03))
    steps(m, -3.4, 3.4, 0.8, 6, 0.22, 0.4, role=STONE)
    m.box(STONE, (X0, 1.4, Z0), (X1, 8.4, Z1), bevel=0.04, seg=1, tint=(1.0, 1.0, 1.03))
    for k in range(9):
        m.box("dark", (X0, 1.8 + k * 0.7, Z1 - 0.01), (X1, 1.82 + k * 0.7, Z1 + 0.02), tint=(0.5, 0.5, 0.5))
    for i in range(6):
        column(m, -4.2 + i * 1.68, -1.0, 1.4, 8.0, 0.36, STONE)
    m.box(STONE, (-5.0, 8.0, Z1), (5.0, 8.6, -0.3), bevel=0.04, seg=1, tint=(1.0, 1.0, 1.03))
    m.box("gold", (-4.5, 8.15, -0.28), (4.5, 8.55, -0.24))
    for k in range(10):
        m.box("dark", (-4.2 + k * 0.85, 8.25, -0.24), (-4.1 + k * 0.85, 8.45, -0.22))
    pediment(m, -5.2, 5.2, 8.6, -0.3, 1.9, 0.5, role=STONE)
    for k in range(5):                                                                                           # a frieze of bas-relief figures as pale blocks
        m.box(STONE, (-3.0 + k * 1.3, 9.2, -0.5), (-2.4 + k * 1.3, 10.0, -0.3), bevel=0.04, seg=2, tint=(0.9, 0.9, 0.9))
    m.box(STONE, (X0 - 0.1, 8.4, Z0 - 0.1), (X1 + 0.1, 8.8, Z1 + 0.1), bevel=0.03, seg=1)
    m.box("dark", (-1.4, 1.4, Z1 - 0.02), (1.4, 5.4, Z1 + 0.02))
    for sx in (-1, 1):
        m.box(DARK, (sx * 0.7 - 0.66, 1.4, Z1), (sx * 0.7 + 0.66, 5.2, Z1 + 0.1), bevel=0.03, seg=1)
        m.box("gold", (sx * 0.7 - 0.5, 2.0, Z1 + 0.1), (sx * 0.7 + 0.5, 4.4, Z1 + 0.13), bevel=0.02, seg=1, tint=(0.5, 0.4, 0.2))
    # a rooftop glass dome over the trading floor and a ticker display on the front
    m.lathe(GLASS, (0.0, 8.8, -6.0), [(0.0, 0.0), (3.2, 0.0), (3.0, 0.8), (2.2, 1.7), (1.1, 2.3), (0.0, 2.5)], 24, tint=(1.4, 1.7, 1.9))
    for k in range(12):
        a = math.tau * k / 12
        m.pipe(METAL, (math.cos(a) * 3.2, 8.8, -6.0 + math.sin(a) * 3.2), (0.0, 11.3, -6.0), 0.04, 5)
    m.cyl("glow_cyan", (0.0, 11.2, -6.0), 0.2, 0.15, 8)
    m.box("paint", (-3.0, 5.7, Z1 + 0.0), (3.0, 7.0, Z1 + 0.08), tint=hexc("1d252a"))
    for k in range(10):
        m.box("glow_green" if k % 3 else "glow_red", (-2.8 + k * 0.58, 6.1 + (k % 3) * 0.2, Z1 + 0.08), (-2.4 + k * 0.58, 6.5 + (k % 3) * 0.2, Z1 + 0.11))
    # the forecourt: the bull and the bear on plinths, armoured van, lamps, trees, flags
    for sx, tintc, nm in ((-1, hexc("5a3a2a"), "bull"), (1, hexc("3a3a3a"), "bear")):
        m.box(STONE, (sx * 5.4 - 0.9, 0.13, 3.0), (sx * 5.4 + 0.9, 0.9, 4.4), bevel=0.04, seg=1)
        with m.frame((sx * 5.4, 0.9, 3.7), yaw=-sx * 0.4):
            m.hull("paint", [(-0.4, 0.0, -0.7), (0.4, 0.0, -0.7), (-0.4, 0.0, 0.5), (0.4, 0.0, 0.5), (-0.35, 0.9, -0.6), (0.35, 0.9, -0.6), (-0.3, 0.9, 0.3), (0.3, 0.9, 0.3)], tint=tintc)
            m.hull("paint", [(-0.25, 0.4, 0.4), (0.25, 0.4, 0.4), (-0.2, 0.4, 0.9), (0.2, 0.4, 0.9), (-0.2, 1.0, 0.4), (0.2, 1.0, 0.4), (-0.15, 0.9, 0.9), (0.15, 0.9, 0.9)], tint=tintc)
            if nm == "bull":
                for hx in (-1, 1):
                    m.pipe("paint", (hx * 0.15, 1.0, 0.85), (hx * 0.4, 1.3, 0.8), 0.04, 5, tint=hexc("f0eee4"))
            for lx in (-0.3, 0.3):
                for lz in (-0.5, 0.4):
                    m.box("paint", (lx - 0.07, 0.0, lz - 0.07), (lx + 0.07, 0.4, lz + 0.07), tint=tintc)
    for sx in (-1, 1):
        for k in range(3):
            lamp(m, sx * (2.4 + k * 2.4), 4.6)
    for k in range(4):
        fx = -4.5 + k * 3.0
        m.pipe(METAL, (fx, 0.13, 6.4), (fx, 6.0, 6.4), 0.05, 6)
        m.box("paint", (fx + 0.02, 4.8, 6.4), (fx + 0.04, 5.9, 7.4), tint=[hexc("c0392b"), hexc("2f6f9e"), hexc("5a8a46"), hexc("e0b020")][k])
    for p in ((-9.0, 7.0), (9.0, 7.0), (-9.4, -3.0), (9.4, -3.0)):
        tree(m, p[0], p[1], 2.4, 1.05)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
