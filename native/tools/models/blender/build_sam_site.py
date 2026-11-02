"""The SAM Site, modelled in Blender.   blender -b -P build_sam_site.py -- <out.glb> [vls]

A battery of four launchers on concrete pads behind sandbag walls: road-mobile transporter-erector trucks with raised canister
launchers (default) or vertical-launch modules with hinged hatches (vls, for the nations that field them), a phased-array radar
on a trailer, a lattice surveillance radar with a mesh antenna, a command post under camouflage netting, a generator, a guard
post and a fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import lattice, container, fence_poly, slats

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "sam_site.glb"
VLS = "vls" in args[1:]
m = Model("sam_site")
rng = random.Random(17)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
OLIVE = hexc("55633f")
OLIVE_D = hexc("3a4630")


def bag_wall(cx, z, n=7, courses=3):
    for c in range(courses):
        off = 0.0 if c % 2 == 0 else 0.2
        for k in range(n - (c % 2)):
            x = cx - (n * 0.42) / 2 + off + k * 0.42 + 0.2
            t = rng.choice([(1.0, 0.95, 0.8), (0.92, 0.88, 0.72), (1.05, 1.0, 0.85)])
            m.box("sandbag", (x - 0.2, 0.2 + c * 0.2, z - 0.15), (x + 0.2, 0.2 + c * 0.2 + 0.2, z + 0.15), bevel=0.06, seg=2, yaw=rng.uniform(-0.05, 0.05), tint=t)


def launcher_truck(cx, cz, raised):
    """An 8x8 transporter-erector: ladder chassis, cab, four axles, deployed stabilisers, a launch beam with four canisters."""
    with m.frame((cx, 0.2, cz)):
        m.box("dark", (-1.0, 0.75, -4.0), (1.0, 1.1, 2.6), bevel=0.04, seg=1)
        m.box("paint", (-1.15, 1.1, -3.4), (1.15, 1.3, 1.8), bevel=0.04, seg=1, tint=OLIVE)
        m.box("paint", (-1.1, 0.8, 2.6), (1.1, 2.55, 4.0), bevel=0.12, seg=2, tint=OLIVE)
        m.box(GLASS, (-0.95, 1.7, 3.98), (0.95, 2.4, 4.04))
        m.box(GLASS, (-1.12, 1.7, 2.9), (-1.08, 2.4, 3.8))
        m.box(GLASS, (1.08, 1.7, 2.9), (1.12, 2.4, 3.8))
        m.box("dark", (-1.15, 0.5, 3.95), (1.15, 0.9, 4.15), bevel=0.04, seg=1)
        for ax in (-3.2, -1.7, 1.0, 3.2):
            for sx in (-1, 1):
                m.pipe("dark", (sx * 0.78, 0.5, ax), (sx * 1.12, 0.5, ax), 0.5, 14)
                m.pipe(METAL, (sx * 0.78, 0.5, ax), (sx * 1.14, 0.5, ax), 0.2, 10)
        for sz in (-3.6, 1.9):                                                              # stabilisers, jacks down
            for sx in (-1, 1):
                m.box(DARK, (sx * 1.1 - (0.0 if sx > 0 else 0.55), 0.75, sz - 0.12), (sx * 1.1 + (0.55 if sx > 0 else 0.0), 0.95, sz + 0.12), bevel=0.02, seg=1)
                m.pipe(METAL, (sx * 1.65, 0.78, sz), (sx * 1.65, 0.0, sz), 0.06, 6)
                m.box(DARK, (sx * 1.65 - 0.25, 0.0, sz - 0.25), (sx * 1.65 + 0.25, 0.06, sz + 0.25))
        m.box("glow_warm", (-0.9, 0.6, 4.15), (-0.6, 0.72, 4.18))
        m.box("glow_warm", (0.6, 0.6, 4.15), (0.9, 0.72, 4.18))
        tilt = -1.2 if raised else -0.05
        with m.frame((0, 1.45, -2.6), pitch=tilt):                                          # the launch beam
            m.box("dark", (-1.0, -0.15, -0.3), (1.0, 0.0, 1.8), bevel=0.02, seg=1)
            for rx in (-0.95, 0.95):
                m.box(DARK, (rx - 0.06, -0.1, -0.3), (rx + 0.06, 0.12, 4.6), bevel=0.01, seg=1)
            for ix in range(2):
                for iy in range(2):
                    x0, y0 = -0.9 + ix * 0.9, 0.1 + iy * 0.9
                    m.box("paint", (x0 + 0.02, y0, 0.0), (x0 + 0.78, y0 + 0.78, 4.4), bevel=0.04, seg=1, tint=hexc("a8b090"))
                    m.box("paint", (x0 + 0.1, y0 + 0.08, 4.4), (x0 + 0.7, y0 + 0.7, 4.45), tint=hexc("c9702a"))                # the orange cap
                    for bz in (0.8, 2.4, 3.9):
                        m.box("dark", (x0, y0 + 0.34, bz), (x0 + 0.8, y0 + 0.44, bz + 0.14))


def vls_block(cx, cz):
    """A vertical-launch module: a low armoured block, a grid of hatches on the roof, two of them open with a missile tip showing."""
    with m.frame((cx, 0.2, cz)):
        m.box(CONC, (-1.9, 0.0, -2.2), (1.9, 0.35, 2.2), bevel=0.04, seg=1)
        m.box("paint", (-1.7, 0.35, -2.0), (1.7, 1.9, 2.0), bevel=0.06, seg=2, tint=hexc("6f7a58"))
        for k in range(5):
            m.box("dark", (-1.7, 0.6 + k * 0.28, 2.0), (1.7, 0.63 + k * 0.28, 2.02))
        m.box(DARK, (-1.8, 1.9, -2.1), (1.8, 2.0, 2.1), bevel=0.03, seg=1)
        for ix in range(3):
            for iz in range(4):
                hx, hz = -1.15 + ix * 1.15, -1.5 + iz * 1.0
                open_ = (ix == 1 and iz == 1) or (ix == 0 and iz == 3)
                m.box("dark", (hx - 0.42, 2.0, hz - 0.42), (hx + 0.42, 2.04, hz + 0.42))
                if open_:
                    m.pipe("paint", (hx, 2.0, hz), (hx, 3.1, hz), 0.2, 14, tint=hexc("e8ecee"))
                    m.pipe("paint", (hx, 3.1, hz), (hx, 3.35, hz), 0.2, 14, tint=hexc("5d6468"), r2=0.12)
                    m.pipe("paint", (hx, 3.35, hz), (hx, 3.6, hz), 0.12, 14, tint=hexc("5d6468"), r2=0.02)
                    with m.frame((hx - 0.4, 2.04, hz), pitch=0.0):                                 # the lid, hinged up and back
                        with m.frame((0, 0, 0)):
                            m.hull(DARK, [(0, 0, -0.38), (0.0, 0.0, 0.38), (-0.05, 0.75, -0.38), (-0.05, 0.75, 0.38), (0.04, 0.0, -0.38), (0.04, 0.0, 0.38), (-0.01, 0.75, -0.38), (-0.01, 0.75, 0.38)])
                else:
                    m.box(METAL, (hx - 0.38, 2.04, hz - 0.38), (hx + 0.38, 2.08, hz + 0.38), bevel=0.01, seg=1)
                    m.box("dark", (hx - 0.3, 2.08, hz - 0.02), (hx + 0.3, 2.09, hz + 0.02))
        m.box("glow_cyan", (-1.2, 1.1, 2.02), (1.2, 1.5, 2.06))


def phased_array(cx, cz, size):
    """A phased-array radar on a tower trailer facing +z: a square array tilted back, a mast and outriggers."""
    with m.frame((cx, 0.1, cz)):
        m.box("paint", (-1.4, 0.4, -2.0), (1.4, 0.8, 2.0), bevel=0.04, seg=1, tint=OLIVE)
        for sz in (-1.7, 1.7):
            for sx in (-1, 1):
                m.pipe("dark", (sx * 1.2, 0.35, sz), (sx * 1.55, 0.35, sz), 0.35, 12)
        for sx in (-1, 1):
            m.pipe(METAL, (sx * 1.6, 0.5, 2.0), (sx * 1.6, 0.0, 2.0), 0.05, 6)
        m.box("paint", (-0.5, 0.8, -0.6), (0.5, 3.0, 0.6), bevel=0.04, seg=1, tint=hexc("6f7a58"))
        with m.frame((0, 3.0, 0.2), pitch=0.22):
            m.box(DARK, (-size / 2, 0.0, 0.0), (size / 2, size, 0.3), bevel=0.03, seg=1)
            m.box("dark", (-size / 2 + 0.12, 0.12, 0.3), (size / 2 - 0.12, size - 0.12, 0.33))
            n = 8
            for gx in range(n):
                for gy in range(n):
                    if (gx + gy) % 2 == 0:
                        pitch_ = (size - 0.5) / n
                        m.box(DARK, (-size / 2 + 0.25 + gx * pitch_, 0.25 + gy * pitch_, 0.33), (-size / 2 + 0.25 + (gx + 0.8) * pitch_, 0.25 + (gy + 0.8) * pitch_, 0.36), tint=(1.3, 1.5, 1.6))
        m.cyl("glow_red", (0.0, 3.0 + size + 0.2, 0.2), 0.08, 0.2, 8)


def search_radar(cx, cz):
    """A lattice tower with a rotating mesh antenna on a pedestal."""
    lattice(m, cx, cz, 6.0, 1.3, 0.1, 0.05)
    m.box(DARK, (cx - 0.6, 6.0, cz - 0.6), (cx + 0.6, 6.4, cz + 0.6), bevel=0.04, seg=1)
    m.cyl(METAL, (cx, 6.4, cz), 0.3, 0.3, 12)
    m.box(DARK, (cx - 2.2, 6.7, cz - 0.08), (cx + 2.2, 6.8, cz + 0.08))
    m.box(DARK, (cx - 2.2, 8.0, cz - 0.08), (cx + 2.2, 8.1, cz + 0.08))
    for k in range(13):
        m.box(METAL, (cx - 2.2 + k * 0.34 - 0.02, 6.7, cz - 0.05), (cx - 2.2 + k * 0.34 + 0.02, 8.1, cz + 0.05))
    for k in range(7):
        m.box(METAL, (cx - 2.2, 6.7 + k * 0.2, cz - 0.04), (cx + 2.2, 6.72 + k * 0.2, cz + 0.04))
    m.box(DARK, (cx - 0.15, 6.7, cz - 0.4), (cx + 0.15, 7.5, cz - 0.1), bevel=0.02, seg=1)
    m.pipe(METAL, (cx, 8.1, cz), (cx, 8.9, cz), 0.03, 5)
    m.cyl("glow_red", (cx, 8.9, cz), 0.06, 0.12, 8)


# ------------------------------------------------------------------ the ground and the battery
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.2, 0.1, -9.0), (9.2, 0.15, 8.0))
m.box("asphalt", (-1.2, 0.15, 1.0), (1.2, 0.16, 9.4))
m.box("asphalt", (-9.0, 0.15, 0.4), (9.0, 0.16, 1.6))
for k in range(8):
    m.box(CONC, (-0.05, 0.16, 1.8 + k * 1.0), (0.05, 0.17, 2.3 + k * 1.0), tint=(1.8, 1.8, 1.7))
for i in range(4):
    lx = -6.0 + i * 4.0
    m.box(CONC, (lx - 1.8, 0.1, -6.6), (lx + 1.8, 0.2, -0.2), bevel=0.03, seg=1, tint=(1.15, 1.15, 1.15))
    if VLS:
        vls_block(lx, -3.4)
    else:
        launcher_truck(lx, -3.6, i < 3)
    bag_wall(lx, -6.95)
phased_array(0.0, 5.4, 2.8)
search_radar(7.0, 5.2)
m.box(CONC, (-1.8, 0.1, 3.2), (1.8, 0.14, 7.2), bevel=0.02, seg=1)

# ------------------------------------------------------------------ the command post under camouflage netting
container(m, -6.7, 3.7, 0.0, hexc("6f7a58"), 3.0, 1.4, 1.9)
m.box("glow_cyan", (-7.6, 1.2, 4.4), (-5.8, 1.7, 4.43))
m.pipe(METAL, (-7.4, 2.0, 3.6), (-7.4, 4.4, 3.6), 0.03, 5)
m.pipe(DARK, (-7.9, 4.4, 3.6), (-6.9, 4.4, 3.6), 0.03, 4)
for k in range(4):
    m.pipe(METAL, (-8.8 + (k % 2) * 4.2, 0.1, 2.0 + (k // 2) * 3.4), (-8.8 + (k % 2) * 4.2, 3.0, 2.0 + (k // 2) * 3.4), 0.05, 6)
net = []
for j in range(9):
    z = 2.0 + j * (5.4 - 2.0) / 8
    net.append([(-8.8 + i * 4.2 / 10, 3.0 - 0.18 * math.sin(math.pi * i / 10) * math.sin(math.pi * j / 8) - 0.04 * math.sin(i * 1.7 + j * 1.3), z) for i in range(11)])
m.loft("net", net, outward_from=(-6.7, 0.0, 3.7), tint=(1, 1, 1))
m.loft("net", [[(x, y - 0.015, z) for x, y, z in row] for row in net], outward_from=(-6.7, 0.0, 3.7), inward=True, tint=(0.8, 0.8, 0.8))
m.loft("net", [[(-8.8 + i * 4.2 / 10, 3.0 - 0.7 * (1 - j / 3) - 0.0, 2.0 - 0.6 * (j / 3)) for i in range(11)] for j in range(4)][::-1], outward_from=(-6.7, 0.0, 3.7), tint=(0.9, 0.9, 0.9))   # the drooping front edge
m.box(CLAD, (-4.0, 0.1, 6.2), (-2.4, 1.6, 7.6), bevel=0.04, seg=1)                                  # a generator
m.box(CONC, (-4.1, 1.6, 6.1), (-2.3, 1.72, 7.7), bevel=0.03, seg=1)
m.pipe(DARK, (-3.4, 1.72, 6.6), (-3.4, 2.8, 6.6), 0.1, 8)
m.box("glow_green", (-2.4, 1.0, 6.8), (-2.36, 1.2, 7.0))
slats(m, -3.8, -2.6, 0.3, 1.3, 7.6, tint=hexc("dfe4e6"))

# ------------------------------------------------------------------ guard post, floodlights, fence
m.box(CLAD, (2.2, 0.1, 8.0), (3.6, 2.3, 9.2), bevel=0.04, seg=1)
m.box(CONC, (2.1, 2.3, 7.9), (3.7, 2.42, 9.3), bevel=0.03, seg=1)
m.box(GLASS, (2.3, 1.0, 9.18), (3.5, 2.1, 9.24))
m.pipe(METAL, (1.2, 1.0, 8.4), (-0.2, 1.0, 8.4), 0.05, 6)
for k in range(3):
    m.box("paint", (1.0 - k * 0.46, 0.95, 8.35), (1.2 - k * 0.46, 1.05, 8.45), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
for p in ((-9.0, 5.0), (9.0, 3.0), (9.0, -6.0), (-9.0, -7.0), (0.0, -8.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.2, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.2, p[1] - 0.17), (p[0] + 0.45, 5.3, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.17, p[1] - 0.14), (p[0] + 0.4, 5.2, p[1] + 0.14))
fence_poly(m, 10.6, gate=(-1.6, 1.6), hazard_every=5, h=1.8)
m.pipe(METAL, (-9.0, 0.1, 7.0), (-9.0, 6.4, 7.0), 0.05, 6)
m.box("banner", (-8.98, 5.1, 7.0), (-8.96, 6.2, 8.0))
m.finish(out)
