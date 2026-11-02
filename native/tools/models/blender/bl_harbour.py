"""Quay parts shared by the Port and the Shipyard: the quay itself with fenders and bollards, rails, mast lights, a harbour
tower, yard tractors. Game coordinates; the quay top is y 0.43 and its water edge z 9.6."""
import math
from bl_kit import hexc
from bl_parts import truck

CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
Q = 0.43


def beam(m, a, b, w, role=METAL, tint=(1, 1, 1)):
    m.pipe(role, a, b, w, 4, tint=tint)


def quay(m, paved):
    """A deep concrete slab, a paved or asphalt yard, a coping, rubber fenders on chains, mushroom bollards, rings and drains."""
    m.box(CONC, (-8.2, -1.6, -8.6), (8.2, 0.4, 9.6), bevel=0.05, seg=2)
    m.box("pavers" if paved else "asphalt", (-8.0, 0.4, -8.4), (8.0, Q, 9.4))
    m.box(CONC, (-8.2, 0.4, 9.3), (8.2, 0.5, 9.6), bevel=0.02, seg=1)                     # the coping
    m.box("hazard", (-8.0, Q, 8.7), (8.0, Q + 0.012, 8.85))
    for i in range(11):
        fx = -7.5 + i * 1.5
        m.cyl("dark", (fx, -0.6, 9.78), 0.22, 0.95, 12)                                   # a rubber fender
        m.tube("dark", (fx, -0.1, 9.78), 0.24, 0.2, 0.06, 12)
        m.pipe(METAL, (fx, 0.35, 9.6), (fx, 0.3, 9.72), 0.015, 4)
    for i in range(8):
        bx = -7.0 + i * 2.0
        m.lathe("metal", (bx, Q, 9.15), [(0.0, 0.0), (0.2, 0.0), (0.2, 0.22), (0.3, 0.3), (0.3, 0.44), (0.0, 0.44)], 12)   # a mushroom bollard
        m.tube(METAL, (bx + 0.5, Q, 8.8), 0.1, 0.07, 0.02, 10)                              # a mooring ring
    for gx in (-6.0, -2.0, 2.0, 6.0):                                                       # drain grates
        m.box("dark", (gx - 0.5, Q, 7.9), (gx + 0.5, Q + 0.015, 8.1))
        for k in range(6):
            m.box(METAL, (gx - 0.45 + k * 0.18, Q + 0.015, 7.9), (gx - 0.42 + k * 0.18, Q + 0.025, 8.1))


def tower(m, x, z):
    """The harbour master's tower: a concrete shaft, a glass cab under a roof, a radar bar, a flag."""
    m.box(CONC, (x - 0.6, Q, z - 0.6), (x + 0.6, 6.0, z + 0.6), bevel=0.05, seg=1)
    m.box(CONC, (x - 0.9, 6.0, z - 0.9), (x + 0.9, 6.15, z + 0.9), bevel=0.03, seg=1)
    m.hull(GLASS, [(x - 0.8, 6.15, z - 0.8), (x + 0.8, 6.15, z - 0.8), (x - 0.8, 6.15, z + 0.8), (x + 0.8, 6.15, z + 0.8),
                   (x - 1.0, 7.3, z - 1.0), (x + 1.0, 7.3, z - 1.0), (x - 1.0, 7.3, z + 1.0), (x + 1.0, 7.3, z + 1.0)])
    m.box(CONC, (x - 1.1, 7.3, z - 1.1), (x + 1.1, 7.45, z + 1.1), bevel=0.03, seg=1)
    m.pipe(METAL, (x, 7.45, z), (x, 8.4, z), 0.04, 6)
    m.box(DARK, (x - 0.7, 8.4, z - 0.04), (x + 0.7, 8.46, z + 0.04))
    m.box("glow_red", (x - 0.1, 8.5, z - 0.1), (x + 0.1, 8.7, z + 0.1))
    for k in range(6):
        m.box("dark", (x - 0.45 + k * 0.18, 1.0, z + 0.6), (x - 0.4 + k * 0.18, 5.4, z + 0.62))
    m.pipe(METAL, (x + 1.1, 6.0, z + 0.9), (x + 1.1, 8.0, z + 0.9), 0.03, 5)
    m.box("banner", (x + 1.12, 6.4, z + 0.9), (x + 1.14, 7.5, z + 1.9))


def mast_lights(m, pts, h=7.0):
    for p in pts:
        m.pipe(METAL, (p[0], Q, p[1]), (p[0], h, p[1]), 0.07, 8)
        m.box(DARK, (p[0] - 0.7, h, p[1] - 0.18), (p[0] + 0.7, h + 0.1, p[1] + 0.18), bevel=0.02, seg=1)
        for k in range(3):
            m.box("glow_warm", (p[0] - 0.6 + k * 0.45, h - 0.04, p[1] - 0.15), (p[0] - 0.3 + k * 0.45, h, p[1] + 0.15))


def tractor(m, x, z, yaw):
    """A yard tractor with a trailer deck."""
    truck(m, x, z, yaw=yaw, canvas=False, bed=1.2, body=hexc("c9972a"))
    with m.frame((x, 0, z), yaw=yaw):
        m.box("hazard", (-1.0, Q + 0.1, -4.5), (1.0, Q + 0.35, -1.2), bevel=0.03, seg=1, tint=(0.9, 0.8, 0.5))
        for sx in (-1, 1):
            m.pipe("dark", (sx * 0.8, 0.45, -3.8), (sx * 1.1, 0.45, -3.8), 0.4, 12)
