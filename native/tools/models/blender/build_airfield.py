"""The Airfield, modelled in Blender.   blender -b -P build_airfield.py -- <out.glb>

Layout fixed by the game (air_operations.gd): the runway runs along z at x = -3.2 (4 m wide with shoulders), a taxiway joins it to
an apron at x 3.2 .. 9.6 whose four parking slots are at x = 5.6, z = -7.2 / -2.4 / 2.4 / 7.2; the slab top is y 0.1.
Runway with threshold bars, numbers, aiming points, centreline, edge lights green-white-red and PAPI; apron with taxi lines and
tie-downs; a vaulted hangar with open lit doors; a control tower with a glass cab; an operations building; a fuel farm; a fire
station with a crash tender; ground-support vehicles; a windsock, ILS antenna, approach lights and a fence. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, slats, radome, lattice
from bl_civic import lamp, flagpole, tree

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "airfield.glb"
m = Model("airfield")
rng = random.Random(151)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
RX = -3.2
TEAL = hexc("2f6f7e")
LINE = hexc("f0eee4")
YEL = hexc("e8c020")

slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("turf", (-9.4, 0.1, -9.6), (9.4, 0.14, 9.6), tint=hexc("8a9a60"))
m.box("gravel", (3.0, 0.14, -9.0), (9.8, 0.15, 9.0), tint=(1.0, 1.0, 1.0))


def paint(x0, z0, x1, z1, y=0.16, tint=LINE, h=0.012):
    m.box("paint", (x0, y, z0), (x1, y + h, z1), tint=tint)


# ------------------------------------------------------------------ the runway
m.box("asphalt", (RX - 2.0, 0.1, -10.2), (RX + 2.0, 0.17, 10.2))
for side in (-1, 1):
    m.box(CONC, (RX + side * 2.0 - (0.35 if side > 0 else 0.0), 0.1, -10.2), (RX + side * 2.0 + (0.35 if side < 0 else 0.0), 0.172, 10.2), tint=(1.25, 1.25, 1.25))
    paint(RX + side * 1.8 - 0.04, -9.9, RX + side * 1.8 + 0.04, 9.9)
for z in range(-8, 8, 2):                                                      # the centreline dashes
    paint(RX - 0.06, z + 0.2, RX + 0.06, z + 1.2)
for end in (-1, 1):
    for k in range(5):                                                         # the threshold bars
        x = RX - 1.5 + k * 0.75
        paint(x, end * 9.4 - 0.5, x + 0.35, end * 9.4 + 0.5)
    for k in range(2):                                                         # the touchdown marks
        for sx in (-0.8, 0.8):
            paint(RX + sx - 0.18, end * (6.6 - k * 1.2) - 0.35, RX + sx + 0.18, end * (6.6 - k * 1.2) + 0.35)
    paint(RX - 0.5, end * 4.2 - 0.5, RX - 0.3, end * 4.2 + 0.5)                # the aiming points
    paint(RX + 0.3, end * 4.2 - 0.5, RX + 0.5, end * 4.2 + 0.5)
for z, w in ((-8.6, "09"), (8.6, "27")):                                       # runway numbers as painted bars
    for q in range(2):
        xx = RX - 0.5 + q * 0.7
        paint(xx, z - 0.35, xx + 0.1, z + 0.35)
        paint(xx, z - 0.35, xx + 0.4, z - 0.25)
        paint(xx + 0.3, z - 0.35, xx + 0.4, z + 0.35)
        paint(xx, z + 0.25, xx + 0.4, z + 0.35)
for i in range(11):                                                            # edge lights: green at the near end, red at the far
    z = -9.5 + i * 1.9
    for side in (-1, 1):
        role = "glow_green" if z < -7.0 else ("glow_red" if z > 7.0 else "glow_warm")
        m.cyl(role, (RX + side * 2.45, 0.1, z), 0.07, 0.2, 8)
for i in range(4):                                                             # PAPI lights beside the near threshold
    m.box("glow_red" if i < 2 else "glow_warm", (RX - 3.4 - i * 0.55, 0.1, -6.0), (RX - 3.0 - i * 0.55, 0.45, -5.6))
for i in range(8):                                                             # the approach light bar
    m.cyl("glow_warm", (RX - 1.8 + i * 0.5, 0.1, -10.6), 0.07, 0.15, 8)

# ------------------------------------------------------------------ taxiway and apron with slots and tie-downs
m.box("asphalt", (RX + 2.0, 0.1, -1.4), (3.2, 0.16, 1.4), tint=(1.1, 1.1, 1.1))
paint(RX + 2.0, -0.04, 3.2, 0.04, tint=YEL)
for side in (-1, 1):
    paint(RX + 2.0, side * 1.3 - 0.03, 3.2, side * 1.3 + 0.03, tint=YEL)
m.box(CONC, (3.2, 0.1, -8.6), (9.6, 0.16, 8.6), tint=(1.3, 1.3, 1.3))
for k in range(9):                                                             # slab joints
    m.box("dark", (3.2, 0.16, -8.4 + k * 2.1), (9.6, 0.162, -8.38 + k * 2.1), tint=(0.5, 0.5, 0.5))
for sz in (-7.2, -2.4, 2.4, 7.2):
    for side in (-1, 1):
        paint(4.0, sz + side * 1.9 - 0.05, 8.0, sz + side * 1.9 + 0.05, y=0.165, tint=YEL)
    paint(7.95, sz - 1.9, 8.05, sz + 1.9, y=0.165, tint=YEL)
    paint(3.2, sz - 0.05, 4.0, sz + 0.05, y=0.165, tint=YEL)
    for side in (-1, 1):
        m.tube(METAL, (5.6 - 0.2, 0.165, sz + side * 1.2), 0.1, 0.07, 0.02, 10)
# ------------------------------------------------------------------ the hangar, left of the runway's far side: x -8.2, z -4
HX, HZ, HW, HL = -8.2, -4.0, 2.3, 3.7
m.box(CONC, (HX - HW - 2.2, 0.1, HZ + HL), (HX + HW + 2.4, 0.16, HZ + HL + 3.8), bevel=0.01, seg=1, tint=(1.3, 1.3, 1.3))
m.cut_box(CLAD, (HX - HW, 0.1, HZ - HL), (HX + HW, 2.6, HZ + HL), [[(HX - 1.9, 0.0, HZ + HL + 0.2), (HX + 1.9, 0.0, HZ + HL + 0.2), (HX - 1.9, 3.3, HZ + HL + 0.2), (HX + 1.9, 3.3, HZ + HL + 0.2),
                                                                  (HX - 1.9, 0.0, HZ + HL - 0.6), (HX + 1.9, 0.0, HZ + HL - 0.6), (HX - 1.9, 3.3, HZ + HL - 0.6), (HX + 1.9, 3.3, HZ + HL - 0.6)]], bevel=0.02, seg=1, tint=(1.1, 1.1, 1.1))
m.vault(CLAD, HX, HZ - HL, HZ + HL, HW, 2.6, 1.7, 14, thick=0.1, tint=(1.1, 1.1, 1.1))
for k in range(8):
    z = HZ - HL + 0.4 + k * (2 * HL - 0.8) / 7
    pts = [(HX + math.sin(-math.pi / 2 + math.pi * j / 14) * (HW + 0.03), 2.6 + 1.73 * math.cos(-math.pi / 2 + math.pi * j / 14), z) for j in range(15)]
    for a, b in zip(pts, pts[1:]):
        m.pipe(METAL, a, b, 0.03, 4)
m.box("dark", (HX - 1.9, 0.1, HZ + HL - 0.65), (HX + 1.9, 3.3, HZ + HL - 0.6))
m.box("glow_warm", (HX - 1.7, 3.0, HZ + HL - 0.7), (HX + 1.7, 3.08, HZ + HL - 0.1))
for k in range(3):
    m.box("glow_warm", (HX - 1.3 + k * 1.1, 2.6, HZ + HL), (HX - 0.9 + k * 1.1, 2.7, HZ + HL + 0.05))
for sx in (-1, 1):
    m.box(METAL, (HX + sx * 2.1 - 0.08, 0.1, HZ + HL + 0.0), (HX + sx * 2.1 + 0.08, 3.3, HZ + HL + 0.1), bevel=0.01, seg=1)
m.box("hazard", (HX - 2.2, 3.3, HZ + HL), (HX + 2.2, 3.45, HZ + HL + 0.2))
m.box("paint", (HX - 1.5, 3.7, HZ + HL + 0.02), (HX + 1.5, 4.3, HZ + HL + 0.07), tint=TEAL)
for k in range(2):
    m.cyl(METAL, (HX, 4.2, HZ - 2.0 + k * 3.0), 0.3, 0.3, 10)
m.pipe(METAL, (HX - 1.6, 0.1, HZ + HL + 3.0), (HX - 1.6, 5.2, HZ + HL + 3.0), 0.04, 6)
m.box("banner", (HX - 1.58, 4.0, HZ + HL + 3.0), (HX - 1.56, 5.1, HZ + HL + 4.0))

# ------------------------------------------------------------------ the control tower
TX, TZ = -8.2, 5.5
m.box(CONC, (TX - 0.8, 0.1, TZ - 0.8), (TX + 0.8, 5.6, TZ + 0.8), bevel=0.05, seg=1, tint=(1.3, 1.3, 1.3))
for k in range(5):
    m.box(GLASS, (TX - 0.12, 0.8 + k * 0.9, TZ + 0.78), (TX + 0.12, 1.3 + k * 0.9, TZ + 0.84), tint=(1.4, 1.7, 1.9))
m.box(CONC, (TX - 1.0, 5.6, TZ - 1.0), (TX + 1.0, 5.76, TZ + 1.0), bevel=0.02, seg=1)
m.hull(GLASS, [(TX - 1.0, 5.76, TZ - 1.0), (TX + 1.0, 5.76, TZ - 1.0), (TX - 1.0, 5.76, TZ + 1.0), (TX + 1.0, 5.76, TZ + 1.0),
               (TX - 1.55, 7.2, TZ - 1.55), (TX + 1.55, 7.2, TZ - 1.55), (TX - 1.55, 7.2, TZ + 1.55), (TX + 1.55, 7.2, TZ + 1.55)], tint=(0.9, 1.3, 1.6))
for k in range(5):
    cx = TX - 1.55 + k * 0.775
    m.pipe(METAL, (cx, 5.9, TZ + 1.5), (cx, 7.2, TZ + 1.55), 0.03, 5)
    m.pipe(METAL, (cx, 5.9, TZ - 1.5), (cx, 7.2, TZ - 1.55), 0.03, 5)
m.box(DARK, (TX - 2.0, 7.2, TZ - 2.0), (TX + 2.0, 7.4, TZ + 2.0), bevel=0.03, seg=1)
m.box("hazard", (TX - 2.04, 7.25, TZ - 2.0), (TX - 1.98, 7.4, TZ + 2.0))
m.box("hazard", (TX + 1.98, 7.25, TZ - 2.0), (TX + 2.04, 7.4, TZ + 2.0))
m.pipe(METAL, (TX, 7.4, TZ), (TX, 8.6, TZ), 0.04, 6)
m.box(DARK, (TX - 0.8, 8.6, TZ - 0.05), (TX + 0.8, 8.66, TZ + 0.05))
m.cyl("glow_red", (TX, 8.66, TZ), 0.1, 0.2, 8)
for sx in (-1, 1):
    m.pipe(METAL, (TX + sx * 1.9, 7.4, TZ - 1.9), (TX + sx * 1.9, 7.4, TZ + 1.9), 0.02, 4)
    m.pipe(METAL, (TX + sx * 1.9, 7.4, TZ - 1.9), (TX + sx * 1.9, 7.9, TZ - 1.9), 0.02, 4)
    m.pipe(METAL, (TX + sx * 1.9, 7.4, TZ + 1.9), (TX + sx * 1.9, 7.9, TZ + 1.9), 0.02, 4)

# ------------------------------------------------------------------ the operations building and a fire station with a crash tender
m.box(CLAD, (-0.6, 0.1, 4.4), (3.0, 2.8, 8.4), bevel=0.04, seg=1, tint=(1.1, 1.1, 1.1))
m.box(CONC, (-0.7, 2.8, 4.3), (3.1, 2.95, 8.5), bevel=0.03, seg=1)
m.box(GLASS, (-0.3, 0.8, 4.36), (2.7, 2.3, 4.4), tint=(1.4, 1.7, 1.9))
for gx in range(5):
    m.box(METAL, (-0.3 + gx * 0.75 - 0.03, 0.8, 4.3), (-0.3 + gx * 0.75 + 0.03, 2.3, 4.42), bevel=0.01, seg=1)
m.box("paint", (-0.8, 2.5, 3.2), (3.2, 2.62, 4.5), tint=TEAL)
for px in (-0.6, 3.0):
    m.pipe(METAL, (px, 0.1, 3.3), (px, 2.5, 3.3), 0.05, 8)
for k in range(2):
    fan(m, (0.4 + k * 1.8, 2.95, 6.4), 0.4)
m.pipe(METAL, (3.6, 0.1, 3.4), (3.6, 5.6, 3.4), 0.04, 6)
m.box("banner", (3.62, 4.4, 3.4), (3.64, 5.5, 4.4))
m.box(CLAD, (-9.4, 0.1, 6.6), (-5.2, 3.4, 8.8), bevel=0.04, seg=1, tint=hexc("d8d4c0"))                      # the fire station
m.box("dark", (-8.9, 0.1, 8.78), (-5.7, 2.7, 8.82))
for q in range(2):
    m.box("paint", (-8.8 + q * 1.7, 0.2, 8.82), (-7.4 + q * 1.7, 2.6, 8.86), tint=hexc("c0392b"))
m.box(CONC, (-9.5, 3.4, 6.5), (-5.1, 3.55, 8.9), bevel=0.03, seg=1)
truck(m, -7.4, 5.2, yaw=math.pi, canvas=False, bed=3.4, body=hexc("c0392b"))

# ------------------------------------------------------------------ the fuel farm, behind the apron on the far side
m.box(CONC, (-1.0, 0.1, -9.0), (2.6, 0.5, -3.8), bevel=0.03, seg=1, tint=(1.25, 1.25, 1.25))
for i in range(2):
    cz = -7.4 + i * 2.6
    m.cyl("paint", (0.9, 0.5, cz), 0.95, 2.0, 20, tint=hexc("dfe4e6"))
    m.dome("paint", (0.9, 2.5, cz), 0.95, 0.3, 20, 4, tint=hexc("dfe4e6"))
    m.tube("paint", (0.9, 1.4, cz), 0.98, 0.93, 0.06, 20, tint=hexc("8a949a"))
    m.pipe(METAL, (1.85, 0.5, cz), (1.85, 2.4, cz), 0.03, 5)
m.box(CLAD, (-0.7, 0.5, -4.3), (0.7, 1.7, -3.9), bevel=0.03, seg=1)
m.pipe("paint", (0.0, 0.8, -7.4), (0.0, 0.8, -4.3), 0.1, 10, tint=hexc("c83a2e"))
truck(m, 3.9, -8.4, yaw=math.pi / 2, canvas=False, bed=3.0, body=hexc("e8ecee"))                                # a bowser

# ------------------------------------------------------------------ ground support on the apron: a tug, steps, a generator cart
with m.frame((9.2, 0, 0.0), yaw=math.pi / 2):
    m.box("paint", (-0.5, 0.3, -0.7), (0.5, 0.9, 0.7), bevel=0.06, seg=2, tint=hexc("e0b020"))
    m.box(GLASS, (-0.4, 0.9, -0.3), (0.4, 1.4, 0.3), bevel=0.03, seg=1)
    for sx in (-1, 1):
        m.pipe("dark", (sx * 0.45, 0.3, -0.45), (sx * 0.6, 0.3, -0.45), 0.3, 10)
        m.pipe("dark", (sx * 0.45, 0.3, 0.45), (sx * 0.6, 0.3, 0.45), 0.3, 10)
with m.frame((9.2, 0, 4.8), yaw=-0.3):
    for k in range(5):
        m.box(METAL, (-0.5, 0.2 + k * 0.28, -0.5 + k * 0.2), (0.5, 0.26 + k * 0.28, 0.0 + k * 0.2 + 0.5), bevel=0.01, seg=1)
    m.box("paint", (-0.55, 0.2, -0.6), (-0.5, 1.7, 1.0), tint=hexc("e0b020"))
    m.box("paint", (0.5, 0.2, -0.6), (0.55, 1.7, 1.0), tint=hexc("e0b020"))
m.box("paint", (9.3, 0.16, -5.4), (9.9, 1.0, -4.6), bevel=0.04, seg=1, tint=hexc("5d6a4a"))
m.cyl(METAL, (9.6, 1.0, -5.0), 0.12, 0.3, 8)

# ------------------------------------------------------------------ windsock, ILS antenna, lighting masts, fence
m.pipe(METAL, (1.2, 0.1, 9.6), (1.2, 4.0, 9.6), 0.05, 8)
for k in range(4):
    m.pipe("paint", (1.2 + k * 0.5, 4.0 - k * 0.04, 9.6), (1.2 + (k + 1) * 0.5, 3.96 - k * 0.04, 9.6), 0.26 - k * 0.04, 10, tint=hexc("f08030") if k % 2 == 0 else hexc("f0eee4"), r2=0.22 - k * 0.04)
lattice(m, RX - 0.0, 9.9, 3.4, 0.5, 0.1, 0.03)
for k in range(5):                                                                                               # a localizer array
    m.box(METAL, (RX - 1.4 + k * 0.7, 3.3, 9.85), (RX - 1.3 + k * 0.7, 3.5, 9.95))
m.box(DARK, (RX - 1.6, 3.2, 9.8), (RX + 1.6, 3.28, 10.0), bevel=0.01, seg=1)
for p in ((-9.0, -4.2), (9.4, 3.0), (9.4, -4.0), (-6.4, 8.4)):
    m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 6.0, p[1]), 0.06, 8)
    m.box(DARK, (p[0] - 0.45, 6.0, p[1] - 0.17), (p[0] + 0.45, 6.12, p[1] + 0.17), bevel=0.02, seg=1)
    m.box("glow_warm", (p[0] - 0.4, 5.97, p[1] - 0.14), (p[0] + 0.4, 6.0, p[1] + 0.14))
fence_poly(m, 11.4, gate=(-1.6, 1.6), hazard_every=6, h=1.5)
for t in ((-9.8, -7.4), (-6.2, 7.0), (9.8, 6.4)):
    tree(m, t[0], t[1], 2.0, 1.0)
m.finish(out)
