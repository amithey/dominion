"""The Ammunition Depot, modelled in Blender.   blender -b -P build_ammo_depot.py -- <out.glb>

Three earth-covered igloo magazines in a row (a planted mound over the vault, a concrete headwall with an arched
recess, a steel blast door with hazard stripes, number plate, vents and a doorstep), a loading apron with a flatbed
carrying a crate, a forklift with a pallet, crates and drums, an orange gantry crane over pallets, an open shed with
three missiles on cradles, lightning masts, a guard tower, a gate with a barrier and a fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import lattice, fence, truck, fan

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "ammo_depot.glb"
m = Model("ammo_depot")
rng = random.Random(21)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
GREEN = hexc("5a8a46")
ORANGE = hexc("c8902a")
OLIVE = hexc("5d6a4a")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def magazine(cx, number, hw=2.3, hl=2.8, front=-2.4):
    """An igloo: an earth mound over a barrel vault with a concrete headwall and a blast door facing +z."""
    h0, rise = 1.2, hw * 0.85
    top = h0 + rise + 0.45
    wide = hw + 0.7
    zb = front - hl * 2.0

    def mound(x, z):
        u = (x - cx) / wide
        if abs(u) >= 1.0 or z > front - 0.25 or z < zb:
            return -0.03
        t = (z - zb) / (front - 0.25 - zb)                          # 0 at the back, 1 at the headwall
        back = min(1.0, t / 0.3) ** 0.6
        prof = (1.0 - u * u) ** 0.55 * (top - 0.3) + 0.3
        return prof * back * (1.0 + 0.04 * noise(x, z)) + 0.07 * noise(x * 2, z * 2) * back
    m.grid("turf", cx - wide, cx + wide, zb, front - 0.25, mound, 22, 22, base=0.1, tint=GREEN)
    # the headwall: a concrete face with an arched recess cut into it, wing walls running into the mound
    dw = hw - 0.55
    arch = []
    for k in range(9):
        a = math.pi * k / 8
        arch.append((cx + math.cos(a) * dw, 1.2 + math.sin(a) * dw))
    cut = [(x, y, front - 0.0 + 0.2) for x, y in [(cx - dw, 0.0), (cx + dw, 0.0)] + arch] + [(x, y, front - 0.35) for x, y in [(cx - dw, 0.0), (cx + dw, 0.0)] + arch]
    m.cut_box(CONC, (cx - hw - 0.5, 0.1, front - 0.35), (cx + hw + 0.5, 3.2, front + 0.12), [cut], bevel=0.04, seg=1)
    for sgn in (-1, 1):                                                                       # wing walls
        xa = cx + sgn * (hw + 0.5)
        m.hull(CONC, [(xa, 0.1, front + 0.12), (xa, 3.2, front + 0.12), (xa + sgn * 0.5, 0.1, front + 0.12), (xa, 0.1, front - 0.9), (xa, 2.0, front - 0.9), (xa + sgn * 0.5, 0.1, front - 0.9)])
    # the blast door in the recess: two leaves of dark steel, diagonal hazard stripes, a lock bar, lamps
    dz = front - 0.3
    m.box("dark", (cx - dw, 0.1, dz - 0.02), (cx + dw, 2.45, dz + 0.0))
    for sgn in (-1, 1):
        x0, x1 = (cx - dw + 0.08, cx - 0.03) if sgn < 0 else (cx + 0.03, cx + dw - 0.08)
        m.box(DARK, (x0, 0.12, dz), (x1, 2.3, dz + 0.12), bevel=0.03, seg=1)
        for k in range(4):
            xs = x0 + (x1 - x0) * (k + 0.5) / 4
            m.hull("hazard" if k % 2 == 0 else "dark", [(xs - 0.12, 0.2, dz + 0.125), (xs + 0.12, 0.2, dz + 0.125), (xs + 0.12 + 0.5, 1.0, dz + 0.125), (xs - 0.12 + 0.5, 1.0, dz + 0.125),
                                                      (xs - 0.12, 0.2, dz + 0.135), (xs + 0.12, 0.2, dz + 0.135), (xs + 0.12 + 0.5, 1.0, dz + 0.135), (xs - 0.12 + 0.5, 1.0, dz + 0.135)])
        for hy in (0.5, 1.6):
            m.box(METAL, (x0 + 0.1, hy, dz + 0.12), (x1 - 0.1, hy + 0.06, dz + 0.16), bevel=0.01, seg=1)
    m.pipe(METAL, (cx, 0.3, dz + 0.17), (cx, 1.9, dz + 0.17), 0.04, 6)
    for sy in (0.6, 1.5):
        m.cyl(METAL, (cx, sy, dz + 0.19), 0.09, 0.05, 8)
    m.box("paint", (cx - 0.4, 3.35, front - 0.1), (cx + 0.4, 3.75, front + 0.08), bevel=0.02, seg=1, tint=hexc("e8e4d6"))      # the number plate
    for k in range(number):
        m.box("dark", (cx - 0.28 + k * 0.22, 3.43, front + 0.08), (cx - 0.2 + k * 0.22, 3.68, front + 0.1))
    m.box("glow_warm", (cx - 0.2, 2.9, front + 0.12), (cx + 0.2, 3.0, front + 0.2))
    m.box("paint", (cx - hw - 0.3, 1.2, front + 0.12), (cx - hw - 0.1, 1.9, front + 0.17), tint=hexc("c83a2e"))               # warning placards
    m.box("paint", (cx + hw + 0.1, 1.2, front + 0.12), (cx + hw + 0.3, 1.9, front + 0.17), tint=hexc("c83a2e"))
    for k in range(2):                                                                         # vents on the crown
        vx, vz = cx - 0.8 + k * 1.6, front - hl * 1.1
        m.pipe(METAL, (vx, top - 0.2, vz), (vx, top + 0.5, vz), 0.11, 8)
        m.cyl(DARK, (vx, top + 0.5, vz), 0.2, 0.07, 8)
    m.box(CONC, (cx - hw + 0.3, 0.1, front + 0.1), (cx + hw - 0.3, 0.2, front + 1.3), bevel=0.02, seg=1)                     # the doorstep
    m.box(DARK, (cx - 0.5, 0.2, front + 1.3), (cx + 0.5, 0.22, front + 1.5))                                                   # a drain grate


def crate(x, y, z, w, h, d, tint=hexc("7a6a42"), yaw=0.0):
    m.box("wood", (x, y, z), (x + w, y + h, z + d), bevel=0.015, seg=1, tint=tint, yaw=yaw)
    for q in (0.04, w - 0.08):
        m.box("wood", (x + q, y, z - 0.012), (x + q + 0.04, y + h, z + d + 0.012), tint=tuple(t * 0.8 for t in tint), yaw=yaw)
    m.box("hazard", (x + w * 0.15, y + h * 0.4, z + d), (x + w * 0.85, y + h * 0.55, z + d + 0.012), yaw=yaw)


def drum(x, z, tint=OLIVE):
    m.cyl("paint", (x, 0.15, z), 0.32, 0.9, 12, tint=tint)
    for y in (0.35, 0.6, 0.85):
        m.tube("paint", (x, 0.15 + y - 0.1, z), 0.335, 0.31, 0.03, 12, tint=tuple(t * 0.8 for t in tint))
    m.cyl(DARK, (x, 1.05, z), 0.33, 0.04, 12)


def missile_lying(a, length, r):
    x, y, z = a
    m.pipe("paint", (x, y, z), (x + length, y, z), r, 16, tint=hexc("e8ecee"))
    m.pipe("paint", (x + length * 0.55, y, z), (x + length * 0.55 + 0.35, y, z), r * 1.02, 16, tint=hexc("1d252a"))
    m.pipe("paint", (x + length * 0.3, y, z), (x + length * 0.3 + 0.15, y, z), r * 1.02, 16, tint=hexc("c0392b"))
    nx = x + length
    for (r0, r1, dx) in ((r, r * 0.8, 0.35), (r * 0.8, r * 0.5, 0.35), (r * 0.5, r * 0.15, 0.3)):
        m.pipe("paint", (nx, y, z), (nx + dx, y, z), r0, 16, tint=hexc("5d6468"), r2=r1)
        nx += dx
    for k in range(3):                                                                         # tail fins
        a_ = math.tau * k / 3.0 + math.pi / 2
        c, s_ = math.cos(a_), math.sin(a_)
        m.hull("paint", [(x + 0.05, y + c * r, z + s_ * r), (x + 0.75, y + c * r, z + s_ * r), (x + 0.05, y + c * (r + 0.3), z + s_ * (r + 0.3)), (x + 0.5, y + c * (r + 0.3), z + s_ * (r + 0.3)),
                                (x + 0.05, y + c * r + 0.02, z + s_ * r + 0.02), (x + 0.75, y + c * r + 0.02, z + s_ * r + 0.02), (x + 0.05, y + c * (r + 0.3) + 0.02, z + s_ * (r + 0.3) + 0.02), (x + 0.5, y + c * (r + 0.3) + 0.02, z + s_ * (r + 0.3) + 0.02)],
               tint=hexc("5d6468"))


def forklift(x, z, yaw):
    return
    with m.frame((x, 0, z), yaw=yaw):
        m.box("paint", (-0.5, 0.25, -1.1), (0.5, 0.95, 0.6), bevel=0.08, seg=2, tint=hexc("c9972a"))          # body
        m.box("paint", (-0.52, 0.3, -1.3), (0.52, 1.1, -0.6), bevel=0.1, seg=2, tint=hexc("a87a1f"))          # counterweight
        for sx in (-0.45, 0.45):
            m.pipe(DARK, (sx, 0.25, 0.75), (sx, 1.9, 0.75), 0.04, 6)                                           # mast
            m.pipe(DARK, (sx, 0.95, -0.5), (sx, 2.0, -0.5), 0.03, 5)                                           # guard posts
            m.pipe(DARK, (sx, 1.0, 0.45), (sx, 2.0, 0.45), 0.03, 5)
            m.box(DARK, (sx - 0.05, 0.12, 0.8), (sx + 0.05, 0.2, 1.9), bevel=0.01, seg=1)                      # forks
        m.box(DARK, (-0.5, 1.9, 0.7), (0.5, 1.96, 0.8))
        for k in range(5):
            m.box(DARK, (-0.5, 2.0, -0.5 + k * 0.24), (0.5, 2.03, -0.4 + k * 0.24))                            # guard roof slats
        m.box(DARK, (-0.3, 0.95, -0.8), (0.3, 1.2, -0.3), bevel=0.03, seg=1)                                  # seat
        for sx in (-1, 1):
            m.pipe("dark", (sx * 0.4, 0.3, 0.3), (sx * 0.62, 0.3, 0.3), 0.3, 12)
            m.pipe("dark", (sx * 0.4, 0.22, -0.8), (sx * 0.58, 0.22, -0.8), 0.22, 12)
        m.cyl("glow_warm", (0, 2.03, -0.3), 0.07, 0.1, 8)
        m.box("wood", (-0.55, 0.2, 0.85), (0.55, 0.32, 1.85), bevel=0.01, seg=1)                                # the pallet
        crate(-0.45, 0.32, 0.9, 0.9, 0.6, 0.9, hexc("6f7a58"))


# ------------------------------------------------------------------ the ground
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box(CONC, (-9.4, -1.6, -9.2), (9.4, 0.1, 7.4), bevel=0.04, seg=1)
m.box("gravel", (-9.2, 0.1, -9.0), (9.2, 0.15, -2.2))
m.box("asphalt", (-9.2, 0.1, -2.2), (9.2, 0.16, 1.2))
m.box("pavers", (-9.0, 0.1, 1.2), (9.0, 0.14, 7.2))
m.box(CONC, (-9.2, 0.165, -0.5), (9.2, 0.175, -0.4), tint=(1.0, 0.9, 0.3))
for k in range(9):
    m.box(CONC, (-8.4 + k * 2.1, 0.165, 0.7), (-7.8 + k * 2.1, 0.175, 0.76), tint=(1.8, 1.8, 1.7))

# ------------------------------------------------------------------ the magazines
for i in range(3):
    magazine(-6.4 + i * 6.4, i + 1)

# ------------------------------------------------------------------ the loading apron
for k in range(3):                                                                              # stacks of crates and a row of drums
    sx = -8.2 + k * 1.6
    for layer in range(2 - k % 2):
        crate(sx, 0.14 + layer * 0.7, 3.0, 1.3, 0.65, 1.0, hexc("7a6a42") if (k + layer) % 2 == 0 else hexc("6f7a58"))
for k in range(3):
    drum(-2.4 + k * 1.1, 3.0)
crate(3.0, 0.14, 3.2, 0.9, 0.7, 0.9, hexc("6f7a58"))
crate(4.1, 0.14, 3.4, 0.9, 0.7, 0.8, hexc("7a6a42"))
crate(3.5, 0.84, 3.3, 0.9, 0.6, 0.8, hexc("7a6a42"))

# ------------------------------------------------------------------ a portal gantry crane over a pallet row
for gz in (4.6, 6.2):
    for gx in (-8.8, -4.4):
        m.box("paint", (gx - 0.1, 0.14, gz - 0.1), (gx + 0.1, 4.2, gz + 0.1), bevel=0.015, seg=1, tint=ORANGE)
    m.box("paint", (-8.9, 4.2, gz - 0.12), (-4.3, 4.45, gz + 0.12), bevel=0.02, seg=1, tint=ORANGE)
for gx in (-8.8, -4.4):
    m.box("paint", (gx - 0.1, 4.2, 4.5), (gx + 0.1, 4.4, 6.3), bevel=0.015, seg=1, tint=ORANGE)
    m.pipe("paint", (gx, 0.14, 4.6), (gx, 4.2, 6.2), 0.03, 5, tint=ORANGE)
m.box(DARK, (-7.1, 3.95, 5.0), (-6.1, 4.2, 5.8), bevel=0.03, seg=1)                              # the trolley and hoist
m.pipe(DARK, (-6.6, 3.95, 5.4), (-6.6, 2.0, 5.4), 0.025, 5)
m.box(DARK, (-6.9, 1.75, 5.2), (-6.3, 2.0, 5.6), bevel=0.02, seg=1)
for k in range(3):
    crate(-8.2 + k * 1.4, 0.14, 5.1, 1.0, 0.87, 0.6, hexc("7a6a42") if k != 1 else hexc("6f7a58"))

# ------------------------------------------------------------------ the open missile shed
m.box(CLAD, (2.8, 3.4, 4.0), (8.8, 3.6, 7.0), bevel=0.03, seg=1)
m.box(CONC, (2.7, 3.6, 3.9), (8.9, 3.7, 7.1), bevel=0.03, seg=1)
for px in (3.0, 5.8, 8.6):
    for pz in (4.2, 6.8):
        m.box(DARK, (px - 0.08, 0.14, pz - 0.08), (px + 0.08, 3.4, pz + 0.08), bevel=0.01, seg=1)
for k in range(3):
    mz = 4.7 + k * 0.9
    for cx in (3.8, 7.6):
        m.hull(DARK, [(cx - 0.12, 0.14, mz - 0.4), (cx + 0.12, 0.14, mz - 0.4), (cx - 0.12, 0.14, mz + 0.4), (cx + 0.12, 0.14, mz + 0.4),
                      (cx - 0.12, 0.7, mz - 0.25), (cx + 0.12, 0.7, mz - 0.25), (cx - 0.12, 0.7, mz + 0.25), (cx + 0.12, 0.7, mz + 0.25)])
    missile_lying((3.2, 0.9, mz), 5.2 - (0.4 if k == 1 else 0.0), 0.28)
m.box("glow_warm", (3.2, 3.35, 5.0), (8.4, 3.4, 5.1))
m.box("glow_warm", (3.2, 3.35, 6.5), (8.4, 3.4, 6.6))

# ------------------------------------------------------------------ lightning masts, guard tower, gate, fence, floodlights
for mx, mz in ((-3.2, -8.6), (3.2, -8.6), (-9.0, -2.0), (9.0, -2.0)):
    m.pipe(METAL, (mx, 0.1, mz), (mx, 6.0, mz), 0.08, 6, r2=0.05)
    m.pipe(METAL, (mx, 6.0, mz), (mx, 9.0, mz), 0.05, 6, r2=0.02)
    m.cyl("glow_red", (mx, 9.0, mz), 0.05, 0.1, 6)
    for gx, gz in ((1.5, 1.5), (-1.5, 1.5), (0.0, -1.7)):
        m.wire(METAL, [(mx, 5.5, mz), (mx + gx, 0.1, mz + gz)], 0.007)
lattice(m, 8.4, -3.4, 5.0, 1.0, 0.1, 0.045)
m.box(CLAD, (7.7, 5.0, -4.1), (9.1, 6.3, -2.7), bevel=0.04, seg=1)
m.box(GLASS, (7.75, 5.3, -2.72), (9.05, 6.1, -2.66))
m.box(CONC, (7.5, 6.3, -4.3), (9.3, 6.45, -2.5), bevel=0.03, seg=1)
m.box("glow_warm", (8.2, 6.1, -2.5), (8.6, 6.2, -2.4))
m.box(CLAD, (-0.8, 0.1, 7.6), (0.8, 2.4, 8.8), bevel=0.04, seg=1)                                # the gate booth, barrier and signs
m.box(CONC, (-0.9, 2.4, 7.5), (0.9, 2.52, 8.9), bevel=0.03, seg=1)
m.box(GLASS, (-0.7, 1.1, 8.78), (0.7, 2.2, 8.84))
m.pipe(METAL, (0.9, 1.0, 8.2), (2.8, 1.0, 8.2), 0.05, 6)
for k in range(4):
    m.box("paint", (0.9 + k * 0.48, 0.95, 8.15), (1.15 + k * 0.48, 1.05, 8.25), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
fence(m, -9.2, 9.2, -8.8, 7.2, gap=(-0.8, 2.8, 7.2))
for k, fx in enumerate((-6.0, -2.0, 4.0, 8.0)):
    m.box("paint", (fx - 0.3, 1.0, 7.17), (fx + 0.3, 1.5, 7.2), tint=hexc("c83a2e"))
for p in ((-9.0, 6.0), (9.0, 5.4), (-9.0, -4.8), (9.0, -7.0), (-3.2, -8.6), (3.2, -8.6)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.4, p[1]), 0.05, 8)
    m.box(DARK, (p[0] - 0.45, 5.4, p[1] - 0.17), (p[0] + 0.45, 5.52, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.37, p[1] - 0.14), (p[0] + 0.4, 5.4, p[1] + 0.14))
m.pipe(METAL, (-9.0, 0.1, 6.6), (-9.0, 6.6, 6.6), 0.05, 6)
m.box("banner", (-8.98, 5.2, 6.6), (-8.96, 6.3, 7.6))

m.finish(out)
