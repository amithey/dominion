"""The School, modelled in Blender.   blender -b -P build_school.py -- <out.glb>

A red-brick schoolhouse in an L: a two-storey main range with a rhythm of tall sash windows, stone quoins and string courses, a
projecting entrance bay with a gabled pediment, a bell cupola on a hipped slate roof with chimneys, and a single-storey gym wing
with a vaulted roof; in front a playground with a basketball court, hopscotch, a climbing frame and a slide, a bike rack, a
bus, a flagpole, trees, lawn, a low fence and lamps on a hex plaza. Front is +z.
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

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "school.glb"
m = Model("school")
apply_style(m)
rng = random.Random(27)
ground(m, lawns=False, pave=hexc("cfcac0"))
WH = (1.5, 1.5, 1.45)


def sash(x, y, z, w=1.0, h=1.9, face=1):
    """A sash window on a brick wall facing +z: reveal, glass in two sashes, glazing bars, stone sill and lintel."""
    m.box("dark", (x - w / 2, y, z - 0.03), (x + w / 2, y + h, z))
    m.box(GLASS, (x - w / 2, y, z), (x + w / 2, y + h, z + 0.03), tint=(1.6, 1.8, 2.0))
    for k in (-1, 0, 1):
        m.box("wall_concrete", (x + k * w / 4 - 0.015, y, z), (x + k * w / 4 + 0.015, y + h, z + 0.07), tint=WH)
    for fy in (0.0, 0.33, 0.5, 0.66, 1.0):
        yy = y + h * fy
        m.box("wall_concrete", (x - w / 2, yy - 0.02, z), (x + w / 2, yy + 0.02, z + 0.07), tint=WH)
    m.box(STONE, (x - w / 2 - 0.12, y - 0.1, z), (x + w / 2 + 0.12, y, z + 0.2), bevel=0.02, seg=1)
    m.box(STONE, (x - w / 2 - 0.12, y + h, z), (x + w / 2 + 0.12, y + h + 0.2, z + 0.12), bevel=0.02, seg=1)


def wall_windows(x0, x1, z, ys, step=2.0, skip=()):
    n = int((x1 - x0) / step)
    for i in range(n):
        x = x0 + step / 2 + i * step
        if any(abs(x - s) < 1.2 for s in skip):
            continue
        for y in ys:
            sash(x, y, z)


# ------------------------------------------------------------------ the main range: x -7 .. 3, z -9 .. -4.5, two storeys
X0, X1, Z0, Z1 = -7.0, 3.0, -9.0, -4.5
m.box(STONE, (X0 - 0.15, 0.1, Z0 - 0.15), (X1 + 0.15, 1.0, Z1 + 0.15), bevel=0.03, seg=1)
m.box(BRICK, (X0, 1.0, Z0), (X1, 7.2, Z1), bevel=0.02, seg=1)
for k in range(30):
    m.box("dark", (X0, 1.1 + k * 0.2, Z1 - 0.005), (X1, 1.12 + k * 0.2, Z1 + 0.015), tint=(0.35, 0.3, 0.28))                 # brick coursing
m.box(STONE, (X0 - 0.1, 3.95, Z0 - 0.1), (X1 + 0.1, 4.15, Z1 + 0.15), bevel=0.02, seg=1)                                     # string course
m.box(STONE, (X0 - 0.3, 7.2, Z0 - 0.4), (X1 + 0.3, 7.5, Z1 + 0.4), bevel=0.03, seg=2)                                         # eaves
for sx in (X0, X1 - 0.5):                                                                                                    # quoins
    for k in range(12):
        m.box(STONE, (sx, 1.0 + k * 0.52, Z1 - 0.02), (sx + 0.5 + (0.12 if k % 2 else 0.0), 1.0 + k * 0.52 + 0.46, Z1 + 0.06), bevel=0.01, seg=1)
wall_windows(X0, X1, Z1, (1.5, 4.5), 2.0, skip=(-2.0,))
for z in (-7.8, -5.6):
    for y in (1.5, 4.5):
        with m.frame((X0, 0, z), yaw=-math.pi / 2):
            sash(0.0, y, 0.0)
for bx in (-5.5, -3.0, -0.5, 2.0):
    for y in (1.5, 4.5):
        with m.frame((bx, 0, Z0), yaw=math.pi):
            sash(0.0, y, 0.0)
# the entrance bay: a projecting pavilion with a pediment, double doors, a fanlight and steps
EX0, EX1, EZ = -3.2, -0.8, Z1 + 1.0
m.box(BRICK, (EX0, 1.0, Z1), (EX1, 7.8, EZ), bevel=0.02, seg=1)
m.box(STONE, (EX0 - 0.1, 0.1, Z1), (EX1 + 0.1, 1.0, EZ + 0.1), bevel=0.03, seg=1)
for sx in (EX0, EX1 - 0.4):
    for k in range(13):
        m.box(STONE, (sx, 1.0 + k * 0.5, EZ - 0.02), (sx + 0.4 + (0.1 if k % 2 else 0.0), 1.0 + k * 0.5 + 0.44, EZ + 0.06), bevel=0.01, seg=1)
pediment(m, EX0 - 0.2, EX1 + 0.2, 7.8, EZ + 0.1, 1.2, 0.5, role=STONE)
m.box("dark", (-1.7, 1.0, EZ - 0.02), (-0.3 - 0.5, 3.6, EZ + 0.02))
for sx in (-2.2, -1.4):
    m.box("wood", (sx - 0.4, 1.0, EZ), (sx + 0.4, 3.2, EZ + 0.1), bevel=0.03, seg=1, tint=(0.5, 0.35, 0.25))
    m.box(GLASS, (sx - 0.28, 1.9, EZ + 0.1), (sx + 0.28, 3.0, EZ + 0.12))
m.hull(GLASS, [(-2.6 + math.cos(math.pi * k / 8) * 1.0 + 0.2 - 0.2, 3.3 + math.sin(math.pi * k / 8) * 0.55, EZ + z_) for k in range(9) for z_ in (0.0, 0.05)])
m.box(STONE, (-2.7, 3.2, EZ), (-0.7, 3.35, EZ + 0.2), bevel=0.02, seg=1)
sash(-2.0, 4.8, EZ, 1.3, 1.8)
m.box("paint", (-2.8, 6.4, EZ + 0.02), (-1.2, 7.2, EZ + 0.06), tint=hexc("2f6f9e"))
m.box("gold", (-2.6, 6.55, EZ + 0.06), (-1.4, 7.05, EZ + 0.08), tint=(1, 1, 1))
steps(m, -2.7, -0.7, EZ + 0.1, 4, 0.22, 0.4, role=STONE)
for k in range(2):
    m.box("glow_warm", (-3.0 + k * 2.6 - 0.1, 3.4, EZ + 0.0), (-3.0 + k * 2.6 + 0.1, 3.7, EZ + 0.2))
# the hipped slate roof, the bell cupola, chimneys
hip_roof(m, X0, X1, Z0, Z1, 7.5, 1.8, overhang=0.0)
CX, CZ = -2.0, -6.8
m.box(PLASTER, (CX - 0.8, 8.8, CZ - 0.8), (CX + 0.8, 10.0, CZ + 0.8), bevel=0.03, seg=1, tint=(1.4, 1.4, 1.35))
for f in range(4):
    with m.frame((CX, 0, CZ), yaw=f * math.pi / 2):
        m.box("dark", (-0.3, 9.1, 0.78), (0.3, 9.9, 0.84))
        m.hull("dark", [(-0.3, 9.9, 0.78), (0.3, 9.9, 0.78), (0.0, 10.2, 0.78), (-0.3, 9.9, 0.84), (0.3, 9.9, 0.84), (0.0, 10.2, 0.84)])
m.box(STONE, (CX - 0.95, 10.0, CZ - 0.95), (CX + 0.95, 10.15, CZ + 0.95), bevel=0.02, seg=1)
m.cyl("gold", (CX, 9.4, CZ), 0.2, 0.3, 10)
m.hull(SLATE, [(CX - 0.9, 10.15, CZ - 0.9), (CX + 0.9, 10.15, CZ - 0.9), (CX - 0.9, 10.15, CZ + 0.9), (CX + 0.9, 10.15, CZ + 0.9), (CX, 11.4, CZ)])
m.pipe("gold", (CX, 11.4, CZ), (CX, 12.1, CZ), 0.04, 6, r2=0.015)
m.cyl("gold", (CX, 11.7, CZ), 0.1, 0.1, 8)
for dx in (-5.0, 1.5):
    m.box(BRICK, (dx - 0.4, 7.5, -7.6), (dx + 0.4, 10.2, -6.8), bevel=0.03, seg=1)
    m.box(STONE, (dx - 0.5, 10.2, -7.7), (dx + 0.5, 10.35, -6.7), bevel=0.02, seg=1)
    for q in (-0.2, 0.2):
        m.cyl("dark", (dx + q, 10.35, -7.2), 0.12, 0.25, 8)

# ------------------------------------------------------------------ the gym wing: vaulted, with a clerestory
GX0, GX1, GZ0, GZ1 = 3.4, 9.0, -9.2, -3.8
m.box(BRICK, (GX0, 0.1, GZ0), (GX1, 4.2, GZ1), bevel=0.02, seg=1)
m.box(STONE, (GX0 - 0.1, 0.1, GZ0 - 0.1), (GX1 + 0.1, 0.9, GZ1 + 0.1), bevel=0.03, seg=1)
m.vault(CONC, (GX0 + GX1) / 2, GZ0 - 0.2, GZ1 + 0.2, (GX1 - GX0) / 2 + 0.2, 4.2, 1.5, 14, thick=0.12, tint=hexc("9aa3a8"))
for k in range(6):
    z = GZ0 + 0.5 + k * (GZ1 - GZ0 - 1.0) / 5
    pts = [((GX0 + GX1) / 2 + math.sin(-math.pi / 2 + math.pi * j / 14) * ((GX1 - GX0) / 2 + 0.24), 4.2 + 1.54 * math.cos(-math.pi / 2 + math.pi * j / 14), z) for j in range(15)]
    for a, b in zip(pts, pts[1:]):
        m.pipe(METAL, a, b, 0.035, 4)
for k in range(5):
    m.box(GLASS, (GX0 + 0.4 + k * 1.1, 2.4, GZ1 - 0.02), (GX0 + 1.3 + k * 1.1, 3.8, GZ1 + 0.03), tint=(1.6, 1.8, 2.0))
    m.box(STONE, (GX0 + 0.35 + k * 1.1, 2.3, GZ1), (GX0 + 1.35 + k * 1.1, 2.4, GZ1 + 0.15), bevel=0.01, seg=1)
for sx in (GX1,):
    m.box(GLASS, (sx - 0.02, 2.4, GZ0 + 1.0), (sx + 0.03, 3.6, GZ1 - 1.0), tint=(1.6, 1.8, 2.0))
m.box("paint", (GX0 + 1.2, 4.3, GZ1 + 0.01), (GX1 - 1.2, 5.3, GZ1 + 0.05), tint=hexc("c0392b"))

# ------------------------------------------------------------------ the playground
m.box("asphalt", (3.6, 0.13, -2.6), (9.4, 0.15, 3.6))                                                     # the court
for k, (a, b) in enumerate(((3.8, 9.2), )):
    m.box("paint", (a, 0.15, -2.4), (b, 0.16, -2.3), tint=hexc("f0eee4"))
    m.box("paint", (a, 0.15, 3.4), (b, 0.16, 3.5), tint=hexc("f0eee4"))
    m.box("paint", (a, 0.15, 0.45), (b, 0.16, 0.55), tint=hexc("f0eee4"))
m.box("paint", (3.8, 0.15, -2.4), (3.9, 0.16, 3.5), tint=hexc("f0eee4"))
m.box("paint", (9.1, 0.15, -2.4), (9.2, 0.16, 3.5), tint=hexc("f0eee4"))
m.tube("paint", (6.5, 0.15, 0.5), 1.0, 0.93, 0.01, 24, tint=hexc("f0eee4"))
for gz in (-2.3, 3.4):                                                                                    # two hoops
    m.pipe(METAL, (6.5, 0.13, gz), (6.5, 3.0, gz), 0.06, 8)
    m.box("paint", (6.0, 2.9, gz - 0.03), (7.0, 3.5, gz + 0.03), tint=hexc("f0eee4"))
    m.tube("paint", (6.5, 2.95, gz + (0.35 if gz < 0 else -0.35)), 0.22, 0.19, 0.03, 14, tint=hexc("d85a2a"))
# hopscotch
for k in range(8):
    m.box("paint", (-5.4 + (0.45 if k in (3, 6) else 0.0), 0.15, 0.6 + k * 0.5), (-4.9 + (0.45 if k in (3, 6) else 0.0) + (0.5 if k in (3, 6) else 0.0), 0.152, 1.0 + k * 0.5), tint=hexc(["e0b020", "c0392b", "2f6f9e", "5a8a46"][k % 4]))
# a climbing frame and a slide
for sx, sz in ((-1.2, -1.0), (1.2, -1.0), (-1.2, 1.0), (1.2, 1.0)):
    m.pipe("paint", (-7.0 + sx, 0.13, 3.2 + sz), (-7.0 + sx, 2.4, 3.2 + sz), 0.06, 8, tint=hexc("c0392b"))
for y in (0.9, 1.6, 2.3):
    for sx in (-1.2, 1.2):
        m.pipe("paint", (-7.0 + sx, y, 2.2), (-7.0 + sx, y, 4.2), 0.04, 6, tint=hexc("2f6f9e"))
    for sz in (-1.0, 1.0):
        m.pipe("paint", (-8.2, y, 3.2 + sz), (-5.8, y, 3.2 + sz), 0.04, 6, tint=hexc("2f6f9e"))
m.box("wood", (-8.2, 2.3, 2.2), (-5.8, 2.38, 4.2), bevel=0.01, seg=1)
m.hull("paint", [(-5.8, 2.3, 3.0), (-5.8, 2.3, 3.5), (-3.6, 0.2, 3.0), (-3.6, 0.2, 3.5), (-5.8, 2.38, 3.0), (-5.8, 2.38, 3.5), (-3.6, 0.28, 3.0), (-3.6, 0.28, 3.5)], tint=hexc("e0b020"))
for sz in (3.0, 3.5):
    m.hull("paint", [(-5.8, 2.3, sz - 0.03), (-5.8, 2.7, sz - 0.03), (-3.6, 0.2, sz - 0.03), (-3.6, 0.6, sz - 0.03), (-5.8, 2.3, sz + 0.03), (-5.8, 2.7, sz + 0.03), (-3.6, 0.2, sz + 0.03), (-3.6, 0.6, sz + 0.03)], tint=hexc("c0392b")) if sz == 3.0 else None
# a bike rack, a bus, benches
for k in range(6):
    x = -3.0 + k * 0.5
    m.pipe(METAL, (x, 0.13, 6.4), (x, 0.8, 6.4), 0.025, 5)
    m.pipe(METAL, (x, 0.8, 6.4), (x, 0.8, 7.2), 0.025, 5)
    m.pipe(METAL, (x, 0.8, 7.2), (x, 0.13, 7.2), 0.025, 5)
with m.frame((-4.2, 0, -1.0)):                                                                            # a yellow school bus
    m.box("paint", (-1.25, 0.5, -3.2), (1.25, 2.5, 3.0), bevel=0.2, seg=3, tint=hexc("e8b020"))
    m.box("paint", (-1.2, 0.5, 3.0), (1.2, 1.5, 4.1), bevel=0.15, seg=2, tint=hexc("e8b020"))
    for sz in (-2.4, -1.2, 0.0, 1.2, 2.4):
        m.box(GLASS, (-1.27, 1.5, sz - 0.4), (-1.23, 2.2, sz + 0.4), tint=(1.6, 1.8, 2.0))
        m.box(GLASS, (1.23, 1.5, sz - 0.4), (1.27, 2.2, sz + 0.4), tint=(1.6, 1.8, 2.0))
    m.box(GLASS, (-1.1, 1.5, 3.02), (1.1, 2.4, 3.06), tint=(1.6, 1.8, 2.0))
    m.box("dark", (-1.27, 1.0, -3.0), (-1.23, 1.15, 3.0))
    m.box("dark", (1.23, 1.0, -3.0), (1.27, 1.15, 3.0))
    m.box("dark", (-1.2, 0.35, 3.9), (1.2, 0.7, 4.2), bevel=0.05, seg=1)
    for ax in (-2.0, 2.3):
        for sx in (-1, 1):
            m.pipe("dark", (sx * 1.0, 0.5, ax), (sx * 1.3, 0.5, ax), 0.5, 14)
    m.box("glow_red", (-1.0, 2.2, -3.22), (-0.7, 2.4, -3.2))
    m.box("glow_red", (0.7, 2.2, -3.22), (1.0, 2.4, -3.2))
    m.box("glow_warm", (-1.0, 0.65, 4.2), (-0.7, 0.8, 4.23))
    m.box("glow_warm", (0.7, 0.65, 4.2), (1.0, 0.8, 4.23))
    m.box("dark", (-1.27, 1.45, 3.0), (-1.23, 2.5, 3.5))
for p in ((-8.8, 4.0), (-8.0, -3.5), (0.5, 8.5), (3.0, 8.0), (9.5, -9.0), (-9.4, -1.0)):
    tree(m, p[0], p[1], 2.4, 1.1)
for sx in (-1, 1):
    lamp(m, sx * 4.8, 4.8)
bench(m, -1.5, 3.2, 0.0)
bench(m, 1.5, 3.2, 0.0)
flagpole(m, 0.8, 5.4, 8.5)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
if STYLE != "euro":
    crown(m, -2.0, 7.5, -6.75, 10.0, 4.5, corners_only=True)
    forecourt(m, 9.4)
m.finish(out)
