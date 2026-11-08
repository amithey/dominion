"""The office towers, modelled in Blender.   blender -b -P build_office_tower.py -- <out.glb> [tv|tech|intel]

One curtain-wall tower on a two-storey podium with a glazed lobby, a recessed crown with a mechanical plant, window-cleaning
gantry, a plaza with a planter, flag and lamps; three variants share it:
  tv    - the television station: a broadcast mast with a red-and-white lattice and a satellite-truck bay with dishes and a studio box
  tech  - the technology park: a green roof with solar panels, a sun-shade fin facade, bike racks and an electric-car charging row
  intel - the intelligence agency: a dark glass tower with a security gate house, a fenced yard, antennas and a radome
Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, dish, radome, lattice, fence_poly, slats
from bl_civic import *

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "office_tower.glb"
VAR = args[1] if len(args) > 1 else "tv"
m = Model("office_tower_" + VAR)
rng = random.Random({"tv": 71, "tech": 72, "intel": 73}.get(VAR, 70))
ground(m, lawns=False, pave=hexc("c8cacb"))
CLAD, METAL, DARK = "cladding", "metal", "steel_dark"
GL = {"tv": (1.5, 1.9, 2.3), "tech": (1.2, 2.0, 1.6), "intel": (0.55, 0.65, 0.75)}[VAR]
FRAME = {"tv": hexc("d8dcde"), "tech": hexc("e4e8e2"), "intel": hexc("5b6268")}[VAR]
ACC = {"tv": hexc("c0392b"), "tech": hexc("5a8a46"), "intel": hexc("2f6f9e")}[VAR]


def curtain(x0, x1, z, y0, y1, face=1, cols=None, rows=None):
    """A curtain-wall face: glass panes with a mullion grid, spandrels at each floor, on a wall facing `face` along z at z."""
    cols = cols or int((x1 - x0) / 1.1)
    rows = rows or int((y1 - y0) / 2.8)
    cw, rh = (x1 - x0) / cols, (y1 - y0) / rows
    for r in range(rows):
        for c in range(cols):
            t = 0.8 + rng.random() * 0.4
            xa, ya = x0 + c * cw, y0 + r * rh
            zz = z + 0.02 * face
            m.box(GLASS, (xa + 0.03, ya + 0.55, min(z, zz)), (xa + cw - 0.03, ya + rh - 0.05, max(z, zz) + 0.0), tint=(GL[0] * t, GL[1] * t, GL[2] * t))
        m.box("cladding", (x0, ya, min(z, z + 0.08 * face)), (x1, ya + 0.55, max(z, z + 0.08 * face)), tint=FRAME)       # spandrel band
    for c in range(cols + 1):
        xm = x0 + c * cw
        m.box("cladding", (xm - 0.03, y0, min(z, z + 0.1 * face)), (xm + 0.03, y1, max(z, z + 0.1 * face)), tint=FRAME)


# ------------------------------------------------------------------ the podium and the tower
PX, PZ0, PZ1, PH = 8.0, -8.0, -1.4, 4.4
m.box(CONC, (-PX - 0.2, 0.1, PZ0 - 0.2), (PX + 0.2, 0.5, PZ1 + 0.2), bevel=0.03, seg=1)
m.box(CLAD, (-PX, 0.5, PZ0), (PX, PH, PZ1), bevel=0.04, seg=1, tint=FRAME)
curtain(-PX + 0.3, PX - 0.3, PZ1, 1.6, PH - 0.4, 1, cols=12, rows=1)
for sx in (-1, 1):
    for z in (-6.8, -4.6, -2.8):
        m.box(GLASS, (sx * PX - (0.0 if sx > 0 else 0.03), 1.6, z - 0.6), (sx * PX + (0.03 if sx > 0 else 0.0), PH - 0.4, z + 0.6), tint=GL)
m.box(CONC, (-PX - 0.3, PH, PZ0 - 0.3), (PX + 0.3, PH + 0.3, PZ1 + 0.3), bevel=0.04, seg=1)
m.box("gravel", (-PX, PH + 0.3, PZ0), (PX, PH + 0.34, PZ1), tint=(0.9, 0.9, 0.9))
# the lobby: a glazed entrance under a deep canopy
m.box(CONC, (-2.6, 0.1, PZ1), (2.6, 0.5, PZ1 + 3.4), bevel=0.03, seg=1)
for gx in range(5):
    for gy in range(3):
        t = 0.8 + rng.random() * 0.4
        m.box(GLASS, (-2.6 + gx * 1.04 + 0.04, 0.5 + gy * 1.3, PZ1 + 3.38), (-2.6 + gx * 1.04 + 1.0, 0.5 + gy * 1.3 + 1.26, PZ1 + 3.42), tint=(GL[0] * t, GL[1] * t, GL[2] * t))
for k in range(6):
    m.box(METAL, (-2.6 + k * 1.04 - 0.04, 0.5, PZ1 + 3.32), (-2.6 + k * 1.04 + 0.04, 4.4, PZ1 + 3.46), bevel=0.01, seg=1)
m.box(CLAD, (-3.2, 4.0, PZ1), (3.2, 4.3, PZ1 + 4.6), bevel=0.04, seg=1, tint=FRAME)
m.box("paint", (-3.2, 4.0, PZ1 + 4.35), (3.2, 4.3, PZ1 + 4.6), tint=ACC)
for sx in (-1, 1):
    m.pipe(METAL, (sx * 3.0, 0.1, PZ1 + 4.3), (sx * 3.0, 4.0, PZ1 + 4.3), 0.09, 8)
m.box("glow_cyan", (-2.8, 3.95, PZ1 + 3.5), (2.8, 4.0, PZ1 + 4.2))
m.box(DARK, (-0.9, 0.5, PZ1 + 3.4), (0.9, 2.4, PZ1 + 3.44))
steps(m, -2.6, 2.6, PZ1 + 3.5, 2, 0.12, 0.35, role=CONC)
TX, TZ0, TZ1, FL = 5.2, -7.4, -2.2, 2.8
TB, NF = PH + 0.3, 5
TT = TB + NF * FL
m.box(CLAD, (-TX, TB, TZ0), (TX, TT, TZ1), bevel=0.04, seg=1, tint=FRAME)
curtain(-TX + 0.15, TX - 0.15, TZ1, TB, TT, 1, cols=9, rows=NF)
curtain(-TX + 0.15, TX - 0.15, TZ0, TB, TT, -1, cols=9, rows=NF)
for sx in (-1, 1):
    for r in range(NF):
        for z in (-6.2, -4.7, -3.2):
            t = 0.8 + rng.random() * 0.4
            m.box(GLASS, (sx * TX - (0.0 if sx > 0 else 0.03), TB + r * FL + 0.55, z - 0.5), (sx * TX + (0.03 if sx > 0 else 0.0), TB + r * FL + FL - 0.05, z + 0.5), tint=(GL[0] * t, GL[1] * t, GL[2] * t))
m.box(CONC, (-TX - 0.2, TT, TZ0 - 0.2), (TX + 0.2, TT + 0.5, TZ1 + 0.2), bevel=0.04, seg=1)                  # the crown
m.box(CLAD, (-3.4, TT + 0.5, TZ0 + 0.8), (3.4, TT + 2.4, TZ1 - 0.8), bevel=0.04, seg=1, tint=FRAME)          # recessed plant room
slats(m, -3.0, 3.0, TT + 0.9, TT + 2.0, TZ1 - 0.8, tint=hexc("dfe4e6"))
for k in range(3):
    fan(m, (-1.8 + k * 1.8, TT + 2.4, (TZ0 + TZ1) / 2), 0.55)
m.pipe(METAL, (-4.2, TT + 0.5, TZ1 - 0.4), (4.2, TT + 0.5, TZ1 - 0.4), 0.03, 5)                              # a cleaning-gantry rail
m.box(DARK, (-0.8, TT + 0.5, TZ1 - 0.8), (0.8, TT + 1.1, TZ1 - 0.2), bevel=0.03, seg=1)
for q in (-0.5, 0.5):
    m.pipe(METAL, (q, TT + 0.5, TZ1 - 0.2), (q, TT - 3.0, TZ1 - 0.02), 0.012, 4)
m.box(DARK, (-0.9, TT - 3.1, TZ1 - 0.1), (0.9, TT - 2.9, TZ1 + 0.2), bevel=0.02, seg=1)
# a name band over the lobby, lit
m.box("paint", (-3.4, PH + 0.4, PZ1 + 0.0), (3.4, PH + 1.3, PZ1 + 0.1), bevel=0.02, seg=1, tint=ACC)
m.box("glow_warm", (-3.0, PH + 0.6, PZ1 + 0.1), (3.0, PH + 1.1, PZ1 + 0.14), tint=(0.9, 0.85, 0.7))

# ------------------------------------------------------------------ the variants
if VAR == "tv":
    MX, MZ = 6.2, -6.0                                                      # a 12 m lattice mast with red and white bands
    lattice(m, MX, MZ, 22.0, 1.4, 0.5, 0.05)
    for k in range(0, 11, 2):
        for sx in (-0.7, 0.7):
            for sz in (-0.7, 0.7):
                m.pipe("paint", (MX + sx, 0.5 + k * 2.0, MZ + sz), (MX + sx * 0.9, 0.5 + (k + 1) * 2.0, MZ + sz * 0.9), 0.06, 5, tint=ACC)
    m.pipe(METAL, (MX, 22.5, MZ), (MX, 26.0, MZ), 0.05, 6, r2=0.015)
    m.cyl("glow_red", (MX, 26.0, MZ), 0.1, 0.2, 8)
    for y, a in ((10.0, 0.6), (16.0, 2.4), (20.0, 4.2)):
        m.pipe(METAL, (MX + math.cos(a) * 0.7, y, MZ + math.sin(a) * 0.7), (MX + math.cos(a) * 1.5, y, MZ + math.sin(a) * 1.5), 0.04, 5)
        m.cyl("paint", (MX + math.cos(a) * 1.6, y - 0.4, MZ + math.sin(a) * 1.6), 0.4, 0.5, 14, tint=hexc("e8ecee"))
    for gx, gz in ((-3.0, 3.0), (3.0, 3.0), (0.0, -3.5)):
        m.wire(METAL, [(MX, 18.0, MZ), (MX + gx, 0.5, MZ + gz)], 0.01, 4)
    m.box(CLAD, (-9.4, 0.1, -5.5), (-6.4, 3.4, -1.5), bevel=0.04, seg=1, tint=hexc("2a2f33"))                   # a black-box studio
    m.box("glow_red", (-9.0, 3.1, -1.45), (-8.4, 3.35, -1.42))
    m.box("paint", (-9.4, 3.4, -5.6), (-6.3, 3.6, -1.4), bevel=0.03, seg=1, tint=ACC)
    for k in range(3):
        m.box("glow_warm", (-9.0 + k * 0.9, 1.6, -1.46), (-8.6 + k * 0.9, 1.9, -1.44))
elif VAR == "tech":
    for k in range(3):                                                      # solar panels on the podium roof
        for j in range(5):
            with m.frame((-6.0 + j * 2.4, PH + 0.34, -4.6 + k * 1.8), pitch=0.0):
                m.hull("solar", [(0, 0.0, 0), (2.0, 0.0, 0), (0, 0.0, 1.4), (2.0, 0.0, 1.4), (0, 0.5, 0), (2.0, 0.5, 0)], tint=(1, 1, 1))
                m.box(DARK, (0.0, 0.0, 0.0), (2.0, 0.04, 0.05))
    for r in range(NF):                                                     # sun-shade fins on the facade
        for c in range(10):
            xx = -TX + 0.4 + c * (2 * TX - 0.8) / 9
            m.box(CLAD, (xx - 0.03, TB + r * FL + 0.2, TZ1), (xx + 0.03, TB + r * FL + FL - 0.2, TZ1 + 0.55), tint=hexc("e8efe4"))
        m.box(CLAD, (-TX, TB + r * FL + FL - 0.2, TZ1), (TX, TB + r * FL + FL - 0.12, TZ1 + 0.6), tint=hexc("e8efe4"))
    for c in range(8):
        m.dome("leaf", (-TX + 0.9 + c * 1.3, TT + 0.5, (TZ0 + TZ1) / 2 + 1.5), 0.55, 0.45, 8, 3, tint=hexc("4f8046"))
    for k in range(6):                                                      # a bike rack and EV chargers
        m.pipe(METAL, (-8.8 + k * 0.5, 0.13, 6.5), (-8.8 + k * 0.5, 0.8, 6.5), 0.025, 5)
        m.pipe(METAL, (-8.8 + k * 0.5, 0.8, 6.5), (-8.8 + k * 0.5, 0.8, 7.3), 0.025, 5)
        m.pipe(METAL, (-8.8 + k * 0.5, 0.8, 7.3), (-8.8 + k * 0.5, 0.13, 7.3), 0.025, 5)
    for k in range(3):
        m.box("paint", (3.2 + k * 2.2, 0.13, 6.4), (3.7 + k * 2.2, 1.4, 6.8), bevel=0.04, seg=1, tint=hexc("e8ecee"))
        m.box("glow_green", (3.3 + k * 2.2, 1.0, 6.8), (3.6 + k * 2.2, 1.2, 6.83))
else:   # intel
    fence_poly(m, 11.0, gate=(-1.6, 1.6), hazard_every=4, h=2.0)
    m.box(CLAD, (4.0, 0.1, 6.0), (6.2, 2.5, 8.0), bevel=0.04, seg=1, tint=hexc("3a4046"))               # a gate house
    m.box(CONC, (3.9, 2.5, 5.9), (6.3, 2.65, 8.1), bevel=0.03, seg=1)
    m.box(GLASS, (4.2, 1.1, 8.0), (6.0, 2.3, 8.04), tint=(0.6, 0.8, 1.0))
    m.pipe(METAL, (3.9, 1.0, 7.4), (1.6, 1.0, 7.4), 0.05, 6)
    for k in range(4):
        m.box("paint", (3.8 - k * 0.55, 0.95, 7.35), (3.5 - k * 0.55, 1.05, 7.45), tint=hexc("c83a2e") if k % 2 == 0 else hexc("f0eee4"))
    for sx in (-1, 1):
        for k in range(4):
            m.cyl(METAL, (sx * (2.2 + k * 0.9), 0.13, 5.6), 0.11, 0.9, 10)
    radome(m, (-3.0, TT + 2.4, (TZ0 + TZ1) / 2 - 0.5), 1.1)
    for k, (ax, az) in enumerate(((3.0, -4.2), (3.6, -4.8), (2.4, -5.0), (-3.6, -4.0))):
        m.pipe(METAL, (ax, TT + 2.4, az), (ax, TT + 2.4 + 3.0 + k * 0.7, az), 0.03, 5)
    m.pipe(METAL, (0.0, TT + 2.4, -5.0), (0.0, TT + 11.0, -5.0), 0.05, 6, r2=0.02)
    m.cyl("glow_red", (0.0, TT + 11.0, -5.0), 0.08, 0.18, 8)
    for a in (0.5, 2.6, 4.7):
        m.wire(METAL, [(0.0, TT + 9.0, -5.0), (math.cos(a) * 3.0, TT + 2.4, -5.0 + math.sin(a) * 3.0)], 0.008)
    m.box(CLAD, (-9.4, 0.1, -5.5), (-6.4, 2.6, -1.5), bevel=0.04, seg=1, tint=hexc("3a4046"))               # a generator block
    slats(m, -9.0, -6.8, 0.5, 2.0, -1.5, tint=hexc("dfe4e6"))
for p in ((-8.8, 3.0), (9.0, 8.0), (-9.0, 8.5), (-5.0, 9.4), (5.0, 9.6)):
    tree(m, p[0], p[1], 2.2, 1.0)
for sx in (-1, 1):
    lamp(m, sx * 4.0, 6.0)
bench(m, -1.0, 6.2, 0.0)
bench(m, 1.2, 6.2, 0.0)
m.box(CONC, (-0.8, 0.13, 8.2), (0.8, 0.8, 9.2), bevel=0.04, seg=1)
m.dome("leaf", (0.0, 0.8, 8.7), 0.6, 0.5, 10, 3, tint=hexc("3f6e3c"))
flagpole(m, -3.4, 5.4, 7.5)
for k in range(6):
    a = math.radians(30 + 60 * k)
    lamp(m, math.cos(a) * 9.8, math.sin(a) * 9.8)
m.finish(out)
