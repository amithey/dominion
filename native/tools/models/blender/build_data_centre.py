"""The AI Data Centre, modelled in Blender.   blender -b -P build_data_centre.py -- <out.glb>

A long server hall in pale composite cladding (panel joints, a shadow gap, a concrete parapet, lit slits, louvred plant
doors with real slats) with a roof of dry coolers under fan rings, a glass lobby with a curtain wall and a cantilevered
canopy, a row of cooling towers on a basin, backup generators and a fuel tank, a two-transformer substation under a
lattice gantry, a solar car port, a gatehouse with a barrier, lamp posts, fence and trees. Fills the hex; front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from mathutils import Matrix

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "data_centre.glb"
m = Model("data_centre")
rng = random.Random(5)

CONC, CLAD, METAL, DARK, GLASS, GLOWC, GLOWW, GLOWG = "wall_concrete", "cladding", "metal", "steel_dark", "glass", "glow_cyan", "glow_warm", "glow_green"
TEAL, GOLD, INK = hexc("2f6f7e"), hexc("d9b45f"), hexc("1d252a")
PALE = (1.0, 1.0, 1.02)
WHITE = hexc("e8ecee")


def slats(x0, x1, y0, y1, z, step=0.13, tint=(1, 1, 1)):
    """A louvre panel on a wall facing +z at z: a dark recess with angled slats in a frame."""
    m.box(DARK, (x0 - 0.05, y0 - 0.05, z - 0.02), (x1 + 0.05, y1 + 0.05, z + 0.06), bevel=0.02, seg=1)
    m.box("dark", (x0, y0, z + 0.05), (x1, y1, z + 0.07))
    n = int((y1 - y0) / step)
    for i in range(n):
        y = y0 + 0.03 + i * step
        m.hull(METAL, [(x0 + 0.02, y, z + 0.07), (x1 - 0.02, y, z + 0.07), (x0 + 0.02, y + 0.03, z + 0.07), (x1 - 0.02, y + 0.03, z + 0.07),
                       (x0 + 0.02, y + 0.07, z + 0.2), (x1 - 0.02, y + 0.07, z + 0.2), (x0 + 0.02, y + 0.1, z + 0.2), (x1 - 0.02, y + 0.1, z + 0.2)], tint)


def fan(c, r, up=0.0):
    """A fan under a housing ring: grille bars, a hub and five blades."""
    x, y, z = c
    m.tube(DARK, (x, y, z), r + 0.1, r, 0.16, 24)
    m.cyl("dark", (x, y - 0.02, z), r, 0.02, 24)
    for k in range(5):
        a = math.tau * k / 5.0
        ca, sa = math.cos(a), math.sin(a)
        pa, pb = (-sa, ca), (ca, sa)
        pts = []
        for rr, w, dy in ((0.12, 0.05, 0.0), (r * 0.92, 0.13, 0.04)):
            for sgn in (-1, 1):
                for h in (0.0, 0.018):
                    pts.append((x + ca * rr + pa[0] * w * sgn, y + 0.05 + dy + h, z + sa * rr + pa[1] * w * sgn))
        m.hull(METAL, pts)
    m.cyl(DARK, (x, y + 0.02, z), 0.14, 0.12, 10)
    for k in range(2):
        a = math.pi * k / 2.0
        m.pipe(DARK, (x - math.cos(a) * r, y + 0.15, z - math.sin(a) * r), (x + math.cos(a) * r, y + 0.15, z + math.sin(a) * r), 0.012, 4)


def lattice(x, z, h, w=0.9, y0=0.17):
    legs = [(x - w / 2, z - w / 2), (x + w / 2, z - w / 2), (x - w / 2, z + w / 2), (x + w / 2, z + w / 2)]
    for lx, lz in legs:
        m.pipe(DARK, (lx, y0, lz), (lx, y0 + h, lz), 0.035, 5)
    n = int(h / 0.9)
    for i in range(n):
        a, b = y0 + i * h / n, y0 + (i + 1) * h / n
        for (ax, az), (bx, bz) in ((legs[0], legs[1]), (legs[1], legs[3]), (legs[3], legs[2]), (legs[2], legs[0])):
            m.pipe(DARK, (ax, a, az), (bx, b, bz), 0.015, 4)


def car(x, z, tint):
    m.box("paint", (x - 0.85, 0.35, z - 1.6), (x + 0.85, 0.85, z + 1.6), bevel=0.15, seg=3, tint=tint)
    m.box(GLASS, (x - 0.74, 0.85, z - 0.95), (x + 0.74, 1.35, z + 0.85), bevel=0.12, seg=2)
    m.box("paint", (x - 0.7, 1.33, z - 0.8), (x + 0.7, 1.38, z + 0.7), bevel=0.02, seg=1, tint=tint)
    for sx in (-1, 1):
        for sz in (-1.0, 1.0):
            m.pipe("dark", (x + sx * 0.78, 0.33, z + sz), (x + sx * 0.96, 0.33, z + sz), 0.33, 12)


def tree(x, z, h=1.6):
    m.cyl("wood", (x, 0.12, z), 0.18, h, 7, r2=0.11)
    m.dome("leaf", (x, 0.12 + h - 0.3, z), 1.15, 1.1, 10, 4, tint=hexc("3f6e3c"))
    m.dome("leaf", (x + 0.35, 0.12 + h + 0.5, z + 0.15), 0.8, 0.85, 8, 3, tint=hexc("4f8046"))


# ------------------------------------------------------------------ ground: hex slab, the site slab, forecourt, yard, asphalt
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
with m.frame((-0.4, 0, 0.6)):
    m.box(CONC, (-9.0, -1.6, -9.6), (9.8, 0.12, 6.4), bevel=0.04, seg=1)
    m.box("pavers", (-0.2, 0.12, 3.8), (7.0, 0.16, 6.2))
    m.box("asphalt", (-9.0, 0.12, 2.0), (-0.4, 0.16, 6.2))
    m.box("gravel", (4.6, 0.12, -9.6), (9.8, 0.18, 2.2))
    for i in range(4):
        m.box(CONC, (-8.6 + i * 2.3, 0.16, 2.3), (-8.5 + i * 2.3, 0.17, 5.7), tint=(1.8, 1.8, 1.7))

    # ------------------------------------------------------------------ the server hall, 10.4 x 6.8, 5.6 high
    W, D, H = 10.4, 6.8, 5.6
    with m.frame((-1.8, 0, -3.0)):
        m.box(CONC, (-W / 2 - 0.08, 0.12, -D / 2 - 0.08), (W / 2 + 0.08, 0.75, D / 2 + 0.08), bevel=0.05, seg=1)       # plinth
        m.box(CLAD, (-W / 2, 0.75, -D / 2), (W / 2, H - 0.6, D / 2), bevel=0.03, seg=1)                                 # the cladding
        m.box("dark", (-W / 2 + 0.05, H - 0.6, -D / 2 + 0.05), (W / 2 - 0.05, H - 0.4, D / 2 - 0.05))                   # the shadow gap
        for x0, x1, z0, z1 in ((-W / 2 - 0.12, W / 2 + 0.12, D / 2 - 0.12, D / 2 + 0.12), (-W / 2 - 0.12, W / 2 + 0.12, -D / 2 - 0.12, -D / 2 + 0.12),
                               (-W / 2 - 0.12, -W / 2 + 0.12, -D / 2, D / 2), (W / 2 - 0.12, W / 2 + 0.12, -D / 2, D / 2)):
            m.box(CONC, (x0, H - 0.4, z0), (x1, H + 0.4, z1), bevel=0.04, seg=1)                                         # the parapet
        m.box("gravel", (-W / 2, H, -D / 2), (W / 2, H + 0.07, D / 2), tint=(0.9, 0.9, 0.9))
        for s in range(4):                                                                                              # panel joints
            with m.frame((0, 0, 0), yaw=s * math.pi / 2):
                span, depth = (W, D) if s % 2 == 0 else (D, W)
                n = int(span / 1.3)
                for i in range(1, n):
                    x = -span / 2 + i * span / n
                    m.box("dark", (x - 0.025, 0.75, depth / 2), (x + 0.025, H - 0.6, depth / 2 + 0.03))
        for i in range(6):                                                                                              # lit slits, side walls
            z = -D / 2 + 0.7 + i * 1.08
            for side in (-1.0, 1.0):
                xs = side * W / 2
                m.box("dark", (min(xs, xs + side * 0.04), 3.55, z - 0.06), (max(xs, xs + side * 0.04), 4.45, z + 0.66))
                m.box(GLOWC, (min(xs + side * 0.03, xs + side * 0.08), 3.65, z), (max(xs + side * 0.03, xs + side * 0.08), 4.35, z + 0.6))
        for i in range(3):                                                                                              # and the front
            x = -4.5 + i * 1.5
            m.box("dark", (x - 0.06, 3.55, D / 2), (x + 1.26, 4.45, D / 2 + 0.04))
            m.box(GLOWC, (x, 3.65, D / 2 + 0.03), (x + 1.2, 4.35, D / 2 + 0.08))
        slats(-4.7, -2.6, 0.95, 3.2, D / 2, tint=hexc("dfe4e6"))
        slats(-2.3, -0.2, 0.95, 3.2, D / 2, tint=hexc("dfe4e6"))
        with m.frame((3.0, 4.35, D / 2 + 0.02), pitch=math.pi / 2):                                                      # the emblem
            m.cyl(GLOWC, (0, 0, 0), 0.55, 0.06, 6)
            m.cyl("dark", (0, 0, 0.0), 0.34, 0.075, 6)
            m.cyl(GLOWC, (0, 0, 0.0), 0.26, 0.09, 6)
        with m.frame((0, 0, 0), yaw=math.pi):                                                                           # the back: grilles
            for i in range(3):
                slats(-4.2 + i * 2.9, -2.4 + i * 2.9, 0.95, 3.0, D / 2, tint=hexc("dfe4e6"))
        roof = H + 0.4
        for row in range(2):                                                                                            # dry coolers
            for i in range(4):
                cx, cz = -3.9 + i * 2.6, -1.6 + row * 3.0
                m.box(METAL, (cx - 0.95, roof, cz - 0.85), (cx + 0.95, roof + 1.0, cz + 0.85), bevel=0.04, seg=1)
                m.box(DARK, (cx - 0.97, roof + 0.55, cz - 0.87), (cx + 0.97, roof + 0.62, cz + 0.87))
                for k in range(3):
                    m.box("dark", (cx - 0.8 + k * 0.8, roof, cz + 0.85), (cx - 0.5 + k * 0.8, roof + 0.5, cz + 0.88))
                fan((cx, roof + 1.0, cz), 0.66)
        m.pipe("paint", (-4.8, roof + 0.3, 0.0), (4.8, roof + 0.3, 0.0), 0.1, 10, tint=hexc("dfe4e6"))
        m.pipe("paint", (-4.8, roof + 0.55, 0.0), (4.8, roof + 0.55, 0.0), 0.07, 10, tint=TEAL)
        for i in range(8):
            m.box("dark", (-4.6 + i * 1.3, roof, -0.05), (-4.5 + i * 1.3, roof + 0.3, 0.05))
        m.box(CLAD, (-4.9, roof, 1.4), (-3.3, roof + 2.2, 3.0), bevel=0.03, seg=1)                                       # stair bulkhead
        m.box(CONC, (-5.0, roof + 2.2, 1.3), (-3.2, roof + 2.35, 3.1), bevel=0.03, seg=1)
        m.box("dark", (-4.4, roof, 3.0), (-3.8, roof + 1.9, 3.04))
        m.pipe(DARK, (4.4, roof, -2.6), (4.4, roof + 2.6, -2.6), 0.04, 6)                                                # lightning mast
        m.cyl(METAL, (4.4, roof + 2.6, -2.6), 0.1, 0.1, 8)
        m.pipe(METAL, (3.6, roof, 2.7), (3.6, roof + 1.2, 2.7), 0.05, 6)                                                  # radome
        m.dome("paint", (3.6, roof + 1.2, 2.7), 0.62, 0.5, 16, 5)

    # ------------------------------------------------------------------ the lobby: curtain wall, canopy, doors, planters
    lx0, lx1, lz0, lz1 = 0.4, 5.8, 0.4, 4.0
    m.box(CONC, (lx0, 0.12, lz0), (lx1, 0.32, lz1), bevel=0.03, seg=1)
    m.box(CLAD, (lx0, 0.32, lz0), (lx0 + 0.1, 4.4, lz1))
    for gx in range(5):
        for gy in range(3):
            x0 = lx0 + 0.1 + gx * (lx1 - lx0 - 0.1) / 5.0
            x1 = x0 + (lx1 - lx0 - 0.1) / 5.0
            y0 = 0.32 + gy * 1.36
            t = 0.7 + rng.random() * 0.7
            m.box(GLASS, (x0 + 0.04, y0 + 0.04, lz1 - 0.02), (x1 - 0.04, y0 + 1.32, lz1 + 0.02), tint=(t, t, t))
    for gz in range(3):
        for gy in range(3):
            z0 = lz0 + gz * (lz1 - lz0) / 3.0
            z1 = z0 + (lz1 - lz0) / 3.0
            y0 = 0.32 + gy * 1.36
            t = 0.7 + rng.random() * 0.7
            m.box(GLASS, (lx1 - 0.02, y0 + 0.04, z0 + 0.04), (lx1 + 0.02, y0 + 1.32, z1 - 0.04), tint=(t, t, t))
    for gx in range(6):
        mx = lx0 + 0.1 + gx * (lx1 - lx0 - 0.1) / 5.0
        m.box(METAL, (mx - 0.05, 0.32, lz1 - 0.04), (mx + 0.05, 4.4, lz1 + 0.1), bevel=0.01, seg=1)
    for gz in range(4):
        mz = lz0 + gz * (lz1 - lz0) / 3.0
        m.box(METAL, (lx1 - 0.04, 0.32, mz - 0.05), (lx1 + 0.1, 4.4, mz + 0.05), bevel=0.01, seg=1)
    for gy in range(4):
        my = 0.32 + gy * 1.36
        m.box(METAL, (lx0, my - 0.04, lz1 - 0.04), (lx1 + 0.1, my + 0.04, lz1 + 0.1), bevel=0.01, seg=1)
    m.box("dark", (2.5, 0.32, lz1 + 0.0), (4.1, 2.4, lz1 + 0.05))                                                        # the double door
    m.box(METAL, (3.27, 0.32, lz1 + 0.05), (3.33, 2.4, lz1 + 0.11))
    for hx in (3.05, 3.45):
        m.pipe(METAL, (hx, 1.0, lz1 + 0.15), (hx, 1.5, lz1 + 0.15), 0.025, 6)
    m.box(CONC, (lx0 - 0.7, 4.4, lz0), (lx1 + 0.8, 4.78, lz1 + 1.1), bevel=0.05, seg=2)                                  # the canopy
    m.box("hazard", (lx0 - 0.7, 4.4, lz1 + 1.02), (lx1 + 0.8, 4.78, lz1 + 1.12), tint=(0.95, 0.75, 0.5))
    m.box("paint", (lx0 - 0.7, 4.33, lz1 + 0.55), (lx1 + 0.8, 4.4, lz1 + 1.1), tint=TEAL)
    m.box(GLOWW, (lx0 - 0.5, 4.29, lz1 + 0.4), (lx1 + 0.6, 4.33, lz1 + 0.6))
    for cx in (lx0 - 0.5, 2.6, lx1 + 0.6):
        m.pipe(METAL, (cx, 0.15, lz1 + 0.9), (cx, 4.4, lz1 + 0.9), 0.1, 10)
    m.box(CONC, (2.2, 0.12, lz1 + 0.08), (4.4, 0.2, lz1 + 1.4), bevel=0.02, seg=1)
    for px in (lx0 + 0.2, lx1 - 1.0):
        m.box(CONC, (px, 0.12, lz1 + 0.3), (px + 1.2, 0.7, lz1 + 0.95), bevel=0.04, seg=1)
        m.dome("leaf", (px + 0.6, 0.7, lz1 + 0.62), 0.5, 0.45, 10, 3, tint=hexc("4f7f46"))
    for k in range(4):
        m.cyl(METAL, (1.2 + k * 1.6, 0.12, lz1 + 1.7), 0.07, 0.7, 8)
    m.pipe(METAL, (6.9, 0.12, lz1 + 1.5), (6.9, 7.0, lz1 + 1.5), 0.05, 6)                                                 # the flagpole
    m.box("banner", (6.92, 5.6, lz1 + 1.5), (6.94, 6.8, lz1 + 2.5))

    # ------------------------------------------------------------------ the cooling plant: three towers on a basin, piped to the hall
    m.box(CONC, (5.0, 0.12, -7.6), (9.4, 0.45, 1.8), bevel=0.04, seg=1)
    for i in range(3):
        tz, tx = -6.2 + i * 2.9, 7.2
        m.box(CLAD, (tx - 1.3, 0.45, tz - 1.2), (tx + 1.3, 3.2, tz + 1.2), bevel=0.04, seg=1)
        for sgn in (-1, 1):
            with m.frame((tx, 0, tz), yaw=sgn * math.pi / 2):
                slats(-1.05, 1.05, 0.75, 3.0, 1.3, tint=hexc("dfe4e6"))
        m.cyl(METAL, (tx, 3.2, tz), 1.1, 0.8, 24, r2=0.96)
        m.cyl("dark", (tx, 4.0, tz), 0.9, 0.02, 24)
        fan((tx, 4.0, tz), 0.86)
        m.box(GLOWG, (tx + 1.3, 2.6, tz - 0.15), (tx + 1.36, 2.85, tz + 0.15))
    for y, r, t in ((0.9, 0.2, hexc("dfe4e6")), (1.3, 0.15, TEAL)):
        m.pipe("paint", (5.6, y, -6.4), (5.6, y, 0.2), r, 12, tint=t)
        m.pipe("paint", (5.6, y, -3.4 if y < 1 else -2.6), (3.3, y, -3.4 if y < 1 else -2.6), r, 12, tint=t)
    for z in (-5.2, -2.0, 0.0):
        m.box("dark", (5.5, 0.45, z - 0.06), (5.7, 0.7, z + 0.06))

    # ------------------------------------------------------------------ backup power behind the hall: generators and a fuel tank
    for i in range(3):
        gx = -6.0 + i * 3.0
        m.box(METAL, (gx - 1.3, 0.12, -8.3), (gx + 1.3, 2.3, -7.1), bevel=0.04, seg=1, tint=(0.85, 0.9, 0.95))
        m.box(DARK, (gx - 1.34, 2.3, -8.34), (gx + 1.34, 2.42, -7.06), bevel=0.02, seg=1)
        for k in range(4):
            m.box("dark", (gx - 1.0 + k * 0.62, 0.3, -7.1), (gx - 0.95 + k * 0.62, 2.1, -7.07))
        m.box(GLOWG, (gx + 1.0, 1.6, -7.1), (gx + 1.2, 1.8, -7.06))
        m.pipe(DARK, (gx + 0.7, 2.42, -7.9), (gx + 0.7, 3.8, -7.9), 0.12, 8)
        m.cyl(DARK, (gx + 0.7, 3.8, -7.9), 0.17, 0.08, 8)
    m.pipe("paint", (2.3, 0.95, -8.0), (4.3, 0.95, -8.0), 0.75, 20, tint=hexc("dfe4e6"))                                     # the fuel tank
    for x in (2.7, 3.9):
        m.box(CONC, (x - 0.15, 0.12, -8.6), (x + 0.15, 0.55, -7.4), bevel=0.03, seg=1)
    m.box(DARK, (3.2, 1.7, -8.12), (3.4, 1.9, -7.88), bevel=0.02, seg=1)

    # ------------------------------------------------------------------ the substation: transformers under a lattice gantry
    for i in range(2):
        ex, ez = 5.8 + i * 2.8, -8.4
        m.box(METAL, (ex - 0.9, 0.17, ez - 0.7), (ex + 0.9, 1.7, ez + 0.7), bevel=0.05, seg=2, tint=(0.85, 0.95, 0.9))
        for k in range(6):
            m.box(METAL, (ex - 0.8 + k * 0.32, 0.3, ez + 0.7), (ex - 0.72 + k * 0.32, 1.5, ez + 0.95), bevel=0.01, seg=1, tint=(0.8, 0.9, 0.85))
        m.pipe(METAL, (ex - 0.6, 1.7, ez), (ex + 0.6, 1.7, ez), 0.2, 12)
        for k in range(3):
            bx = ex - 0.5 + k * 0.5
            m.pipe("paint", (bx, 1.7, ez - 0.35), (bx, 2.7, ez - 0.35), 0.09, 8, tint=hexc("d9c9a8"))
            for s in range(3):
                m.cyl("paint", (bx, 1.95 + s * 0.25, ez - 0.35), 0.15, 0.06, 10, tint=hexc("c8b890"))
    lattice(5.0, -9.2, 5.0, 0.4)
    lattice(9.4, -9.2, 5.0, 0.4)
    m.pipe(DARK, (5.0, 5.0, -9.2), (9.4, 5.0, -9.2), 0.06, 6)
    for x in (5.0, 7.2, 9.4):
        m.pipe("paint", (x, 4.8, -9.2), (x, 4.1, -9.2), 0.04, 6, tint=hexc("d9c9a8"))

    # ------------------------------------------------------------------ a solar car port over the parking, with three cars
    for i in range(3):
        px = -8.6 + i * 2.3
        with m.frame((px + 1.15, 3.5, 2.2), pitch=0.16):
            m.box("solar", (-1.1, 0.0, 0.0), (1.1, 0.04, 3.6), bevel=0.01, seg=1)
            for k in range(1, 4):
                m.box(METAL, (-1.1, 0.04, k * 0.9 - 0.02), (1.1, 0.05, k * 0.9 + 0.02))
            m.box(METAL, (-0.02, 0.04, 0), (0.02, 0.05, 3.6))
            m.box(DARK, (-1.1, -0.1, 0), (1.1, 0.0, 3.6))
    for x in (-8.6, -4.0, -1.7):
        m.pipe(METAL, (x, 0.15, 2.5), (x, 3.6, 2.5), 0.09, 8)
        m.pipe(METAL, (x, 0.15, 5.7), (x, 3.0, 5.7), 0.09, 8)
    for x, c in ((-7.45, hexc("e8ecee")), (-5.15, hexc("26384e")), (-2.85, hexc("a8322a"))):
        car(x, 3.0, c)

    # ------------------------------------------------------------------ a gatehouse with a barrier, lamps, fence, trees, a hedge
    m.box(CLAD, (7.6, 0.12, 4.0), (9.4, 2.6, 5.6), bevel=0.03, seg=1)
    m.box(GLASS, (7.7, 1.0, 5.58), (9.3, 2.2, 5.64))
    m.box(CONC, (7.4, 2.6, 3.8), (9.6, 2.78, 5.8), bevel=0.04, seg=1)
    m.pipe(DARK, (6.9, 1.0, 5.0), (7.6, 1.0, 5.0), 0.05, 6)
    for k in range(4):
        m.box("paint", (5.2 + k * 0.425, 0.9, 4.94), (5.2 + k * 0.425 + 0.21, 1.05, 5.06), tint=hexc("c83a2e") if k % 2 == 0 else hexc("e8e8e0"))
    m.box(DARK, (5.0, 0.12, 4.9), (5.2, 1.15, 5.1), bevel=0.02, seg=1)
    for p in [(-0.8, 6.0), (3.4, 6.0), (8.8, 2.4), (-9.0, -1.0), (-9.0, -6.0)]:
        m.pipe(METAL, (p[0], 0.15, p[1]), (p[0], 4.4, p[1]), 0.05, 8)
        m.pipe(METAL, (p[0], 4.4, p[1]), (p[0] + 0.45, 4.5, p[1]), 0.04, 6)
        m.box(GLOWW, (p[0] + 0.3, 4.36, p[1] - 0.14), (p[0] + 0.75, 4.42, p[1] + 0.14))
    for i in range(15):
        fx = -9.0 + i * 1.28
        if 4.6 < fx < 6.5:
            continue
        m.pipe(METAL, (fx, 0.12, 6.3), (fx, 1.5, 6.3), 0.035, 6)
    for a, b in ((-9.0, 4.6), (6.5, 9.8)):
        for y in (0.5, 1.2):
            m.pipe(DARK, (a, y, 6.3), (b, y, 6.3), 0.025, 5)
    for t in ((-8.6, -6.0), (-8.2, 0.4), (9.2, 6.2)):
        tree(t[0], t[1])
    for i in range(4):
        m.dome("leaf", (0.6 + i * 1.4, 0.0, 6.9), 0.7, 0.6, 10, 3, tint=hexc("3f6e3c"))

m.finish(out)
