"""The housing districts, modelled in Blender.   blender -b -P build_homes.py -- <out.glb> <variant>

Variants (each fills a hex):
  cottage       three stone-and-timber cottages in gardens with hedges, wells, veg plots and a lane
  residential   a street of townhouses in a terrace with a shared square, trees and a fountain
  workerHouse   two rows of small brick workers' houses with chimneys, back yards and a shared wash-house
  luxuryVillas  two hip-roofed villas with pools, garages, terraces, pergolas and clipped hedges
  housing       a four-storey terrace of flats with a stair core, shops below, balconies and a play area
  apartments    a modern apartment block with balconies, a roof terrace, a car park and a courtyard
  villageCenter a village green with a chapel and bell tower, a well, a market cross, an inn and cottages
Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck
from bl_civic import *
from bl_style import crown

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "homes.glb"
VAR = args[1] if len(args) > 1 else "cottage"
STYLE = args[2] if len(args) > 2 else "euro"          # euro, med, asia, arab, us, india, africa
m = Model("homes_" + VAR + "_" + STYLE)
rng = random.Random(abs(hash(VAR)) % 1000 + 7)
ground(m, lawns=False, pave=hexc("b8b6a2") if VAR in ("cottage", "villageCenter") else hexc("c8c6bc"))
m.polygon("turf", [(math.cos(math.radians(30 + 60 * k)) * 11.3, math.sin(math.radians(30 + 60 * k)) * 11.3) for k in range(6)], 0.13, 0.03, tint=hexc("6a9a50")) if VAR in ("cottage", "luxuryVillas", "villageCenter") else None
WH = (1.5, 1.5, 1.45)
PALETTES = {
    "euro": [hexc("ece0c4"), hexc("e2cfb0"), hexc("d8c4a8"), hexc("e8dcc8"), hexc("c9d8c4"), hexc("d8c8d0")],
    "med": [hexc("f6f2ea"), hexc("f2e8d4"), hexc("efe0c0"), hexc("f4ead8"), hexc("f0d9b8"), hexc("f8f4ec")],            # whitewash and warm lime
    "asia": [hexc("f2efe6"), hexc("ece6d6"), hexc("f4f0e8"), hexc("e8e2d0"), hexc("f0ece0"), hexc("eae4d4")],           # pale plaster between dark timber
    "arab": [hexc("e8d4a8"), hexc("dcc494"), hexc("e4cfa0"), hexc("d4b888"), hexc("ecdcb4"), hexc("d8c098")],           # sand and ochre
    "us": [hexc("e8e4d8"), hexc("c8d8e4"), hexc("e8d8c0"), hexc("d4e0cc"), hexc("e4c8c0"), hexc("f0eee4")],             # painted siding
    "india": [hexc("f0b8c8"), hexc("f4d878"), hexc("90d0d0"), hexc("f0a878"), hexc("c8d890"), hexc("e8c8e8")],           # bright limewash
    "africa": [hexc("c8845a"), hexc("d49a68"), hexc("b87850"), hexc("dcb078"), hexc("c0906a"), hexc("d8a070")],          # rammed earth
}
PLASTERS = PALETTES[STYLE]
SHUTTER = {"euro": (0.45, 0.62, 0.5), "med": (0.2, 0.42, 0.72), "asia": (0.3, 0.2, 0.15), "arab": (0.35, 0.25, 0.18), "us": (0.25, 0.3, 0.36), "india": (0.1, 0.45, 0.5), "africa": (0.3, 0.2, 0.14)}[STYLE]
FLAT = STYLE in ("arab", "india")
LOW = STYLE == "med"


def roofrole(r):
    return {"euro": r, "med": "roof_tile", "asia": "roof_slate", "arab": r, "us": "roof_slate", "india": r, "africa": "wood"}[STYLE]
ROOFS = ["roof_tile", "roof_slate", "roof_tile"]


def win(x, y, z, w=0.7, h=0.9, shutters=True, tint=WH):
    m.box("dark", (x - w / 2, y, z - 0.03), (x + w / 2, y + h, z))
    m.box(GLASS, (x - w / 2, y, z), (x + w / 2, y + h, z + 0.03), tint=(1.6, 1.8, 2.0))
    m.box("wall_concrete", (x - 0.02, y, z), (x + 0.02, y + h, z + 0.06), tint=tint)
    m.box("wall_concrete", (x - w / 2 - 0.06, y - 0.06, z), (x + w / 2 + 0.06, y, z + 0.12), bevel=0.01, seg=1, tint=tint)
    if shutters:
        for sx in (-1, 1):
            m.box("wood", (x + sx * (w / 2 + 0.2) - 0.14, y, z), (x + sx * (w / 2 + 0.2) + 0.14, y + h, z + 0.05), tint=SHUTTER)


def door(x, z, w=0.9, h=2.0, tint=(0.45, 0.3, 0.2)):
    m.box("dark", (x - w / 2, 0.13, z - 0.03), (x + w / 2, 0.13 + h, z))
    m.box("wood", (x - w / 2 + 0.05, 0.13, z), (x + w / 2 - 0.05, 0.13 + h - 0.05, z + 0.08), bevel=0.02, seg=1, tint=tint)
    m.cyl("gold", (x + 0.25, 1.0, z + 0.1), 0.03, 0.04, 6)
    m.box("wall_concrete", (x - w / 2 - 0.1, 0.13, z), (x + w / 2 + 0.1, 0.2, z + 0.4), bevel=0.01, seg=1, tint=WH)


def chimney(x, y, z, h=1.4):
    m.box("brick", (x - 0.25, y, z - 0.25), (x + 0.25, y + h, z + 0.25), bevel=0.02, seg=1)
    m.box("wall_concrete", (x - 0.32, y + h, z - 0.32), (x + 0.32, y + h + 0.1, z + 0.32), bevel=0.01, seg=1)
    m.marker("Smoke_Home_%d" % len(m.markers), (x, y + h + 0.15, z))


def house(x, z, yaw, w=4.4, d=3.6, floors=2, wall=None, roof="roof_tile", chim=True, porch=True, flh=2.7):
    """A gabled house: plinth, rendered walls, a window per bay and floor, a door, a gable roof with eaves and a chimney."""
    wall = wall or rng.choice(PLASTERS)
    with m.frame((x, 0, z), yaw=yaw):
        H = 0.13 + floors * flh
        m.box(STONE, (-w / 2 - 0.08, 0.13, -d / 2 - 0.08), (w / 2 + 0.08, 0.6, d / 2 + 0.08), bevel=0.02, seg=1)
        m.box("wood" if STYLE == "us" else "plaster", (-w / 2, 0.6, -d / 2), (w / 2, H, d / 2), bevel=0.02, seg=1, tint=wall if STYLE != "us" else tuple(c * 1.35 for c in wall))
        for fl in range(floors):
            n = max(2, int(w / 1.5))
            for i in range(n):
                wx = -w / 2 + (i + 0.5) * w / n
                if fl == 0 and i == n // 2:
                    door(wx, d / 2)
                else:
                    win(wx, 0.13 + fl * flh + 0.9, d / 2)
            for sx in (-1, 1):
                with m.frame((sx * w / 2, 0, 0), yaw=sx * math.pi / 2):
                    win(0.0, 0.13 + fl * flh + 0.9, 0.0, shutters=False)
        m.box("wall_concrete", (-w / 2 - 0.05, H - 0.1, -d / 2 - 0.05), (w / 2 + 0.05, H + 0.1, d / 2 + 0.05), bevel=0.02, seg=1, tint=WH)
        rise = d * (0.4 if LOW else 0.62)
        if FLAT:                                                                            # a flat roof behind a parapet, a water tank
            m.box("plaster", (-w / 2 - 0.05, H, -d / 2 - 0.05), (w / 2 + 0.05, H + 0.45, d / 2 + 0.05), bevel=0.02, seg=1, tint=wall)
            m.box("plaster", (-w / 2 + 0.2, H + 0.05, -d / 2 + 0.2), (w / 2 - 0.2, H + 0.5, d / 2 - 0.2), tint=tuple(c * 0.9 for c in wall))
            m.cyl("paint", (w * 0.25, H + 0.4, -d * 0.1), 0.35, 0.6, 12, tint=hexc("2a2f33"))
            for k in range(3):
                m.box("plaster", (-w / 2 + 0.3 + k * 0.5, H + 0.45, d / 2 - 0.25), (-w / 2 + 0.55 + k * 0.5, H + 0.9, d / 2 - 0.2), tint=wall)
        elif STYLE == "asia":                                                               # a hipped roof with deep eaves and dark timber
            hip_roof(m, -w / 2, w / 2, -d / 2, d / 2, H + 0.1, rise * 0.75, overhang=0.7, role=roofrole(roof))
            for k in range(int(w / 0.9) + 1):
                m.box("wood", (-w / 2 + k * w / max(1, int(w / 0.9)) - 0.06, 0.6, d / 2), (-w / 2 + k * w / max(1, int(w / 0.9)) + 0.06, H, d / 2 + 0.05), tint=(0.28, 0.18, 0.12))
            m.box("wood", (-w / 2, H - 0.15, d / 2), (w / 2, H, d / 2 + 0.06), tint=(0.28, 0.18, 0.12))
            m.box("wood", (-w / 2, 0.6, d / 2), (w / 2, 0.75, d / 2 + 0.06), tint=(0.28, 0.18, 0.12))
        else:
            gable_roof(m, -w / 2, w / 2, -d / 2, d / 2, H + 0.1, rise, overhang=0.35, role=roofrole(roof))
        if chim and not FLAT:
            chimney(w * 0.28, H + 0.2, -d * 0.1, rise * 0.9)
        if porch and not FLAT:
            m.box("wood", (-0.8, 2.5, d / 2), (0.8, 2.6, d / 2 + 0.9), bevel=0.01, seg=1, tint=(0.5, 0.38, 0.28))
            for sx in (-0.75, 0.75):
                m.pipe("wood", (sx, 0.13, d / 2 + 0.85), (sx, 2.5, d / 2 + 0.85), 0.05, 6)
            if STYLE == "us":                                                               # a deck with a rail, and a garage door on the side
                m.box("wood", (-w / 2, 0.13, d / 2), (w / 2, 0.3, d / 2 + 1.0), tint=(0.85, 0.78, 0.66))
                m.pipe("wood", (-w / 2, 0.9, d / 2 + 0.98), (w / 2, 0.9, d / 2 + 0.98), 0.03, 5)


def hedge_fence(x0, x1, z, role="leaf", h=0.6):
    n = int((x1 - x0) / 0.8)
    for k in range(n):
        m.dome(role, (x0 + 0.4 + k * 0.8, 0.13, z), 0.5, h, 8, 2, tint=hexc("3f6e3c"))


def picket(x0, x1, z, gap=None):
    for k in range(int((x1 - x0) / 0.35)):
        xx = x0 + k * 0.35
        if gap and gap[0] < xx < gap[1]:
            continue
        m.box("wood", (xx - 0.04, 0.13, z - 0.02), (xx + 0.04, 0.95, z + 0.02), tint=hexc("f0ebe0"))
    m.box("wood", (x0, 0.4, z - 0.02), (x1, 0.46, z + 0.02), tint=hexc("f0ebe0"))
    m.box("wood", (x0, 0.8, z - 0.02), (x1, 0.86, z + 0.02), tint=hexc("f0ebe0"))


def veg_plot(x, z, w=2.0, d=1.4):
    m.box("earth", (x, 0.13, z), (x + w, 0.2, z + d), tint=(0.8, 0.7, 0.6))
    for r in range(4):
        for k in range(5):
            m.dome("leaf", (x + 0.2 + k * 0.4, 0.2, z + 0.2 + r * 0.32), 0.12, 0.18, 6, 2, tint=hexc(["5a8a46", "7aa850", "8a6a30", "b05a3a"][r % 4]))


# ------------------------------------------------------------------ the variants
if VAR == "cottage":
    for (x, z, yaw, w, d) in ((-5.6, -5.8, 0.3, 4.4, 3.4), (3.2, -6.2, -0.4, 4.6, 3.6), (-4.4, 3.4, math.pi - 0.2, 4.2, 3.4)):
        if STYLE == "africa" and z > 0:                                                                  # a compound of round thatched huts instead
            for (hx, hz, hr) in ((-5.2, 3.6, 1.6), (-2.6, 6.2, 1.3), (-7.4, 5.8, 1.2)):
                m.cyl("plaster", (hx, 0.13, hz), hr, 2.1, 14, tint=hexc("c8845a"))
                m.box("dark", (hx - 0.4, 0.13, hz + hr - 0.05), (hx + 0.4, 1.7, hz + hr + 0.02))
                m.cyl("wood", (hx, 2.2, hz), hr + 0.55, 1.7, 14, r2=0.05, tint=hexc("b89a50"))
            continue
        house(x, z, yaw, w, d, 2 if w > 4.4 else 1, roof="roof_tile", flh=2.8)
    m.box("gravel", (-1.0, 0.13, -9.0), (1.0, 0.14, 9.0), tint=(1.1, 1.0, 0.9))                       # a lane
    veg_plot(-8.6, -0.8)
    veg_plot(5.8, 1.6)
    m.cyl(STONE, (6.4, 0.13, -1.8), 0.6, 0.7, 14)                                                         # a well
    for sx in (-0.6, 0.6):
        m.pipe("wood", (6.4 + sx, 0.83, -1.8), (6.4 + sx, 2.0, -1.8), 0.05, 6)
    m.hull(roofrole("roof_tile"), [(5.6, 2.0, -2.2), (7.2, 2.0, -2.2), (5.6, 2.0, -1.4), (7.2, 2.0, -1.4), (6.4, 2.5, -2.2), (6.4, 2.5, -1.4)])
    for p in ((-8.2, -8.0), (8.0, -2.2), (8.6, 6.0), (-8.4, 7.0), (0.0, 9.2)):
        tree(m, p[0], p[1], 2.4, 1.1)
    for k in range(6):
        hedge_fence(-8.0 + k * 3.0, -5.0 + k * 3.0, 8.4) if k in (0, 4) else None
    for sx in (-1, 1):
        bench(m, sx * 2.0, 6.6, 0.0)
elif VAR == "residential":
    for k in range(5):                                                                                    # a terrace of townhouses along the back
        house(-8.0 + k * 3.9, -6.6, 0.0, 3.7, 4.2, 3, wall=PLASTERS[k % len(PLASTERS)], roof="roof_slate", chim=True, flh=2.6)
    for k in range(3):                                                                                    # and a short row on the left
        house(-7.2, -1.2 + k * 3.4, math.pi / 2, 3.1, 3.4, 2, wall=PLASTERS[(k + 2) % len(PLASTERS)], roof="roof_tile", chim=True)
    if STYLE in ("asia", "arab", "india"):                                                                # a pavilion on the square: slate eaves, or a dome
        m.cyl(STONE, (3.0, 0.13, 3.6), 2.3, 0.3, 16)
        for qx, qz in ((-1.7, -1.7), (1.7, -1.7), (1.7, 1.7), (-1.7, 1.7)):
            if STYLE == "asia":
                m.pipe("paint", (3.0 + qx, 0.43, 3.6 + qz), (3.0 + qx, 3.2, 3.6 + qz), 0.13, 8, tint=hexc("a8322a"))
            else:
                m.pipe(STONE, (3.0 + qx, 0.43, 3.6 + qz), (3.0 + qx, 3.2, 3.6 + qz), 0.13, 8)
        if STYLE == "asia":
            hip_roof(m, 0.7, 5.3, 1.3, 5.9, 3.2, 1.3, overhang=0.6, role="roof_slate")
        else:
            m.lathe("copper" if STYLE == "arab" else "plaster", (3.0, 3.2, 3.6), [(0.0, 0.0), (2.2, 0.0), (2.1, 0.5), (1.4, 1.2), (0.5, 1.7), (0.0, 1.9)], 20)
    elif STYLE == "africa":                                                                               # a great shade tree with a bench round it
        m.cyl("wood", (3.0, 0.13, 3.6), 0.9, 3.0, 10, r2=0.6, tint=(0.7, 0.6, 0.5))
        m.dome("leaf", (3.0, 2.8, 3.6), 2.8, 1.8, 12, 3, tint=hexc("5a8a46"))
    else:
        m.cyl(STONE, (3.0, 0.13, 3.6), 2.0, 0.5, 24)                                                      # a square with a fountain
        m.cyl("glass", (3.0, 0.62, 3.6), 1.8, 0.03, 24, tint=(0.7, 1.1, 1.5))
        m.cyl(STONE, (3.0, 0.62, 3.6), 0.3, 1.2, 10)
        m.lathe(STONE, (3.0, 1.8, 3.6), [(0.0, 0.0), (0.6, 0.0), (0.7, 0.12), (0.3, 0.22), (0.0, 0.22)], 14)
    for p in ((-3.0, 7.0), (8.0, 6.4), (8.4, -1.6), (-8.4, 6.8)):
        tree(m, p[0], p[1], 2.3, 1.05)
    for sx in (-1, 1):
        bench(m, 3.0 + sx * 3.2, 3.6, math.pi / 2)
    for k in range(4):
        lamp(m, -6.0 + k * 4.0, 2.2)
elif VAR == "workerHouse":
    for row, zz in enumerate((-6.6, -1.0)):
        for k in range(4):
            house(-7.2 + k * 4.3, zz, 0.0, 3.9, 3.8, 2, wall=hexc("b86a4a") if STYLE == "euro" else PLASTERS[(k + row) % len(PLASTERS)], roof="roof_slate", flh=2.6, porch=False, chim=True)
    m.box("brick", (4.4, 0.13, 3.4), (8.4, 3.0, 6.4), bevel=0.03, seg=1, tint=(0.9, 0.82, 0.78))               # the shared wash-house
    gable_roof(m, 4.4, 8.4, 3.4, 6.4, 3.0, 1.3, overhang=0.3, role=roofrole("roof_slate"))
    chimney(7.6, 3.1, 4.0, 2.4)
    door(5.6, 6.4)
    for k in range(5):                                                                                     # washing lines
        m.wire("paint", [(-8.0, 2.4, 3.6 + k * 0.0), (-3.0, 2.4, 3.6)], 0.01, 4) if k == 0 else None
    for q in range(6):
        m.box("paint", (-7.8 + q * 0.8, 1.7, 3.55), (-7.4 + q * 0.8, 2.4, 3.65), tint=hexc(["f0eee4", "c0392b", "2f6f9e", "f0eee4", "e0b020", "f0eee4"][q]))
    m.pipe("wood", (-8.2, 0.13, 3.6), (-8.2, 2.5, 3.6), 0.05, 6)
    m.pipe("wood", (-2.8, 0.13, 3.6), (-2.8, 2.5, 3.6), 0.05, 6)
    for p in ((8.4, -8.0), (-8.8, 7.0), (0.0, 8.8)):
        tree(m, p[0], p[1], 2.0, 0.9)
elif VAR == "luxuryVillas":
    for vi, (x, z, yaw) in enumerate(((-5.6, -5.4, 0.2), (5.4, -5.0, -0.2))):
        with m.frame((x, 0, z), yaw=yaw):
            w, d = 6.4, 4.8
            wall = hexc("f0e8d8") if STYLE == "euro" else PLASTERS[vi + 1]
            m.box(STONE, (-w / 2 - 0.1, 0.13, -d / 2 - 0.1), (w / 2 + 0.1, 0.7, d / 2 + 0.1), bevel=0.03, seg=1)
            m.box("plaster", (-w / 2, 0.7, -d / 2), (w / 2, 6.6, d / 2), bevel=0.03, seg=1, tint=wall)
            for fl in range(2):
                for i in range(4):
                    wx = -w / 2 + (i + 0.5) * w / 4
                    if fl == 0 and i == 2:
                        door(wx, d / 2, 1.2, 2.4)
                    else:
                        win(wx, 0.7 + fl * 3.0 + 0.7, d / 2, 0.9, 1.6, shutters=False)
            m.box("wall_concrete", (-w / 2 - 0.2, 6.6, -d / 2 - 0.2), (w / 2 + 0.2, 6.85, d / 2 + 0.2), bevel=0.03, seg=1, tint=WH)
            if FLAT or STYLE == "africa":                                                                  # a flat roof behind a parapet, crowned in the regional way
                m.box("plaster", (-w / 2 - 0.05, 6.85, -d / 2 - 0.05), (w / 2 + 0.05, 7.45, d / 2 + 0.05), bevel=0.03, seg=1, tint=wall)
                m.box("plaster", (-w / 2 + 0.25, 6.9, -d / 2 + 0.25), (w / 2 - 0.25, 7.5, d / 2 - 0.25), tint=tuple(c * 0.9 for c in wall))
                crown(m, 0.0, 7.5, 0.0, w - 0.4, d - 0.4)
            elif STYLE == "asia":                                                                          # deep eaves and a dark timber band
                hip_roof(m, -w / 2, w / 2, -d / 2, d / 2, 6.85, 2.2, overhang=1.1, role=roofrole("roof_tile"))
                m.box("wood", (-w / 2 - 0.02, 3.55, d / 2), (w / 2 + 0.02, 3.75, d / 2 + 0.06), tint=(0.28, 0.18, 0.12))
                m.box("wood", (-w / 2 - 0.02, 6.4, d / 2), (w / 2 + 0.02, 6.6, d / 2 + 0.06), tint=(0.28, 0.18, 0.12))
            elif STYLE == "us":                                                                            # a big gable over the front, a chimney
                gable_roof(m, -w / 2, w / 2, -d / 2, d / 2, 6.85, 2.4, overhang=0.5, role="roof_slate")
                chimney(w * 0.3, 7.0, 0.0, 2.4)
            else:
                hip_roof(m, -w / 2, w / 2, -d / 2, d / 2, 6.85, 2.0, overhang=0.4, role=roofrole("roof_tile"))
                chimney(w * 0.3, 7.0, 0.0, 1.8)
            m.box(STONE, (-1.2, 0.13, d / 2), (1.2, 2.9, d / 2 + 0.6), bevel=0.03, seg=1)                        # a portico
            for sx in (-0.9, 0.9):
                column(m, sx, d / 2 + 0.5, 0.7, 2.9, 0.16, STONE)
            m.box(STONE, (-1.3, 2.9, d / 2 - 0.1), (1.3, 3.1, d / 2 + 0.7), bevel=0.02, seg=1)
            m.box("cladding", (w / 2, 0.7, -d / 2 + 0.3), (w / 2 + 3.0, 3.0, d / 2 - 0.5), bevel=0.03, seg=1, tint=hexc("e8e0d0"))    # a garage
            m.box("dark", (w / 2 + 0.3, 0.7, d / 2 - 0.52), (w / 2 + 2.7, 2.6, d / 2 - 0.48))
            if FLAT or STYLE == "africa":
                m.box("plaster", (w / 2 - 0.2, 3.0, -d / 2 + 0.1), (w / 2 + 3.2, 3.4, d / 2 - 0.3), bevel=0.02, seg=1, tint=wall)
            else:
                m.hull(roofrole("roof_tile"), [(w / 2 - 0.2, 3.0, -d / 2 + 0.1), (w / 2 + 3.2, 3.0, -d / 2 + 0.1), (w / 2 - 0.2, 3.0, d / 2 - 0.3), (w / 2 + 3.2, 3.0, d / 2 - 0.3), (w / 2 - 0.2, 3.6, 0.0), (w / 2 + 3.2, 3.6, 0.0)])
    if STYLE == "asia":                                                                                   # a koi pond with a red bridge and a stone lantern
        m.cyl(STONE, (-2.0, 0.13, 3.2), 2.6, 0.3, 20)
        m.cyl("glass", (-2.0, 0.4, 3.2), 2.35, 0.03, 20, tint=(0.5, 1.0, 1.4))
        m.box("paint", (-3.8, 0.5, 2.95), (-0.2, 0.62, 3.45), bevel=0.02, seg=1, tint=hexc("a8322a"))
        for sx in (-3.7, -0.3):
            m.pipe("paint", (sx, 0.4, 2.95), (sx, 1.1, 2.95), 0.05, 6, tint=hexc("a8322a"))
            m.pipe("paint", (sx, 0.4, 3.45), (sx, 1.1, 3.45), 0.05, 6, tint=hexc("a8322a"))
        m.cyl(STONE, (-4.6, 0.13, 5.2), 0.18, 0.8, 8)
        m.cyl(STONE, (-4.6, 0.93, 5.2), 0.3, 0.32, 8)
        m.cyl(STONE, (-4.6, 1.25, 5.2), 0.45, 0.12, 8, r2=0.05)
    elif STYLE == "africa":                                                                               # round huts with thatched cones in the compound
        for (hx, hz, hr) in ((-3.8, 3.0, 1.5), (-0.4, 5.0, 1.2)):
            m.cyl("plaster", (hx, 0.13, hz), hr, 2.1, 14, tint=hexc("c8845a"))
            m.box("dark", (hx - 0.4, 0.13, hz + hr - 0.05), (hx + 0.4, 1.7, hz + hr + 0.02))
            m.cyl("wood", (hx, 2.2, hz), hr + 0.55, 1.7, 14, r2=0.05, tint=hexc("b89a50"))
    else:
        m.box(STONE, (-4.4, 0.13, 1.2), (0.6, 0.4, 5.2), bevel=0.03, seg=1)                               # a swimming pool
        m.box("glass", (-4.1, 0.38, 1.5), (0.3, 0.42, 4.9), tint=(0.6, 1.2, 1.6))
        for k in range(3):
            m.box("wood", (-4.8, 0.13, 1.4 + k * 1.2), (-4.5, 0.55, 1.9 + k * 1.2), tint=(0.9, 0.85, 0.7))  # loungers
    m.box("wood", (1.4, 0.13, 1.8), (4.8, 0.2, 5.4), bevel=0.01, seg=1, tint=(0.9, 0.8, 0.65))              # a timber terrace with a pergola
    for sx in (1.5, 4.7):
        for sz in (1.9, 5.3):
            m.pipe("wood", (sx, 0.2, sz), (sx, 2.6, sz), 0.07, 6)
    for k in range(7):
        m.box("wood", (1.4 + k * 0.5, 2.6, 1.8), (1.5 + k * 0.5, 2.7, 5.4))
    for k in range(10):
        m.dome("leaf", (-8.8 + k * 1.8, 0.13, 8.6), 0.55, 0.9, 8, 2, tint=hexc("3f6e3c"))
    for p in ((-8.8, 3.0), (8.8, 2.0), (8.4, 7.0), (0.0, -9.2)):
        tree(m, p[0], p[1], 2.8, 1.2)
elif VAR == "housing":
    for k in range(3):                                                                                    # a terrace of four-storey flats with shops below
        x0 = -8.0 + k * 5.4
        m.box("plaster", (x0, 0.13, -8.6), (x0 + 5.2, 12.5, -2.4), bevel=0.03, seg=1, tint=PLASTERS[k + 1])
        m.box(STONE, (x0 - 0.05, 0.13, -2.5), (x0 + 5.25, 3.4, -2.35), bevel=0.02, seg=1)
        m.box("glass", (x0 + 0.4, 0.5, -2.36), (x0 + 3.4, 2.8, -2.32), tint=(1.6, 1.8, 2.0))                   # a shopfront
        m.box("paint", (x0 + 0.3, 2.9, -2.4), (x0 + 3.5, 3.3, -2.3), tint=hexc(["c0392b", "2f6f9e", "5a8a46"][k]))
        door(x0 + 4.2, -2.4, 0.9, 2.0)
        for fl in range(1, 4):
            for i in range(3):
                wx = x0 + 0.9 + i * 1.7
                win(wx, 3.4 + (fl - 1) * 2.9 + 0.6, -2.4, 0.9, 1.4, shutters=False)
                m.box(METAL, (wx - 0.5, 3.4 + (fl - 1) * 2.9, -2.4), (wx + 0.5, 3.4 + (fl - 1) * 2.9 + 0.08, -1.9), bevel=0.01, seg=1)       # balconies
                m.pipe(METAL, (wx - 0.5, 3.4 + (fl - 1) * 2.9 + 0.95, -1.9), (wx + 0.5, 3.4 + (fl - 1) * 2.9 + 0.95, -1.9), 0.02, 4)
        m.box("wall_concrete", (x0 - 0.1, 12.5, -8.7), (x0 + 5.3, 12.7, -2.3), bevel=0.02, seg=1, tint=WH)
        m.hull(roofrole("roof_slate"), [(x0 - 0.2, 12.7, -8.7), (x0 + 5.4, 12.7, -8.7), (x0 - 0.2, 12.7, -2.2), (x0 + 5.4, 12.7, -2.2), (x0 - 0.2, 13.5, -5.4), (x0 + 5.4, 13.5, -5.4)])
        chimney(x0 + 2.6, 13.0, -5.0, 1.2)
    m.box("asphalt", (-9.0, 0.13, 0.4), (9.0, 0.15, 2.0))
    m.box("sandbag", (4.0, 0.13, 4.0), (6.8, 0.3, 6.6), tint=hexc("e0d0a0"))
    for sx in (4.6, 6.2):
        m.pipe("paint", (sx, 0.13, 5.0), (sx, 2.4, 5.0), 0.05, 6, tint=hexc("c0392b"))
    m.pipe("paint", (4.6, 2.4, 5.0), (6.2, 2.4, 5.0), 0.04, 6, tint=hexc("c0392b"))
    for sx in (4.9, 5.9):
        m.wire("paint", [(sx, 2.4, 5.0), (sx, 0.7, 5.0)], 0.01, 4, tint=hexc("2f6f9e"))
        m.box("wood", (sx - 0.2, 0.6, 4.9), (sx + 0.2, 0.7, 5.1), tint=hexc("2f6f9e"))
    for p in ((-8.4, 5.6), (-5.0, 7.4), (8.4, 7.6), (0.0, 8.6)):
        tree(m, p[0], p[1], 2.2, 1.0)
    for k in range(3):
        lamp(m, -6.0 + k * 6.0, 3.2)
    bench(m, -2.0, 5.4, 0.0)
elif VAR == "apartments":
    X0, X1, Z0, Z1, FL = -6.0, 6.0, -8.6, -3.2, 3.0
    NF = 5
    m.box(CONC, (X0 - 0.2, 0.13, Z0 - 0.2), (X1 + 0.2, 0.5, Z1 + 0.2), bevel=0.03, seg=1)
    body = hexc("e8e4da") if STYLE == "euro" else PLASTERS[0]
    m.box("brick" if STYLE == "us" else "plaster", (X0, 0.5, Z0), (X1, 0.5 + NF * FL, Z1), bevel=0.03, seg=1, tint=(1.0, 0.95, 0.92) if STYLE == "us" else body)
    m.box("paint", (X0 - 0.02, 0.5, Z0 - 0.02), (X0 + 2.0, 0.5 + NF * FL, Z1 + 0.02), tint=hexc("c0aa88") if STYLE == "euro" else PLASTERS[2])      # a coloured stair core
    for fl in range(NF):
        for i in range(6):
            wx = X0 + 2.6 + i * 1.6
            y = 0.5 + fl * FL
            m.box("dark", (wx - 0.55, y + 0.7, Z1 - 0.03), (wx + 0.55, y + 2.1, Z1))
            m.box(GLASS, (wx - 0.55, y + 0.7, Z1), (wx + 0.55, y + 2.1, Z1 + 0.03), tint=(1.6, 1.8, 2.0))
            m.box("wall_concrete", (wx - 0.02, y + 0.7, Z1), (wx + 0.02, y + 2.1, Z1 + 0.06), tint=WH)
            if STYLE in ("arab", "india", "africa"):                                                   # arched heads over the windows
                m.hull("dark", [(wx + math.cos(math.pi * j / 8) * 0.55, y + 2.1 + math.sin(math.pi * j / 8) * 0.4, Z1 - 0.03) for j in range(9)] + [(wx + math.cos(math.pi * j / 8) * 0.55, y + 2.1 + math.sin(math.pi * j / 8) * 0.4, Z1) for j in range(9)])
            if STYLE == "med":                                                                           # shutters either side
                for sx in (-1, 1):
                    m.box("wood", (wx + sx * 0.8 - 0.2, y + 0.7, Z1), (wx + sx * 0.8 + 0.2, y + 2.1, Z1 + 0.05), tint=SHUTTER)
            if i % 2 == 0:                                                                               # a balcony
                m.box(CONC if STYLE != "asia" else "wood", (wx - 0.9, y + 0.05, Z1), (wx + 0.9, y + 0.2, Z1 + 1.1), bevel=0.02, seg=1)
                if STYLE in ("euro", "us"):
                    m.box("glass", (wx - 0.9, y + 0.2, Z1 + 1.06), (wx + 0.9, y + 1.1, Z1 + 1.1), tint=(1.4, 1.8, 2.0))
                elif STYLE in ("arab", "india", "africa"):
                    m.box("plaster", (wx - 0.9, y + 0.2, Z1 + 1.0), (wx + 0.9, y + 0.95, Z1 + 1.1), tint=body)
                else:
                    for q in range(7):
                        m.pipe("wood" if STYLE == "asia" else METAL, (wx - 0.85 + q * 0.28, y + 0.2, Z1 + 1.06), (wx - 0.85 + q * 0.28, y + 1.0, Z1 + 1.06), 0.02, 4)
                m.pipe("wood" if STYLE == "asia" else METAL, (wx - 0.9, y + 1.1, Z1 + 1.08), (wx + 0.9, y + 1.1, Z1 + 1.08), 0.03 if STYLE == "asia" else 0.02, 4)
        m.box("glass", (X0 + 0.3, 0.5 + fl * FL + 0.5, Z1 - 0.02), (X0 + 1.7, 0.5 + fl * FL + 2.2, Z1 + 0.02), tint=(1.6, 1.8, 2.0))
    door(X0 + 1.0, Z1, 1.2, 2.2)
    m.box(CONC, (X0 - 0.3, 0.5 + NF * FL, Z0 - 0.3), (X1 + 0.3, 0.5 + NF * FL + 0.3, Z1 + 0.3), bevel=0.03, seg=1)
    m.box("gravel", (X0, 0.8 + NF * FL, Z0), (X1, 0.84 + NF * FL, Z1))
    RT = 0.84 + NF * FL
    if STYLE == "asia":                                                                                   # a hipped roof with deep eaves over the whole block
        hip_roof(m, X0, X1, Z0, Z1, RT - 0.04, 1.8, overhang=0.9, role="roof_slate")
    elif STYLE == "med":
        hip_roof(m, X0, X1, Z0, Z1, RT - 0.04, 1.4, overhang=0.5, role="roof_tile")
    elif STYLE in ("arab", "india", "africa"):
        m.box("plaster", (X0 - 0.1, RT, Z0 - 0.1), (X1 + 0.1, RT + 0.7, Z1 + 0.1), bevel=0.02, seg=1, tint=body)
        m.box("plaster", (X0 + 0.15, RT + 0.04, Z0 + 0.15), (X1 - 0.15, RT + 0.74, Z1 - 0.15), tint=tuple(c * 0.9 for c in body))
        for k in range(11):
            m.box("plaster", (X0 + 0.3 + k * 1.05, RT + 0.7, Z1 - 0.1), (X0 + 0.7 + k * 1.05, RT + 1.1, Z1 + 0.05), tint=body)
    elif STYLE == "us":                                                                                   # a fire escape zig-zagging up the front
        for fl in range(NF):
            y = 0.5 + fl * FL
            m.box(METAL, (X1 - 2.2, y + 0.05, Z1), (X1 - 0.6, y + 0.1, Z1 + 0.9), tint=(0.8, 0.8, 0.85))
            m.pipe(METAL, (X1 - 2.2, y + 1.0, Z1 + 0.9), (X1 - 0.6, y + 1.0, Z1 + 0.9), 0.02, 4)
            m.pipe(METAL, (X1 - 2.2 if fl % 2 else X1 - 0.6, y + 0.1, Z1 + 0.7), (X1 - 0.6 if fl % 2 else X1 - 2.2, y - FL + 0.1, Z1 + 0.7), 0.03, 4)
    m.box("plaster", (X0 + 0.5, RT, Z0 + 0.5), (X0 + 2.4, RT + 2.6, Z0 + 2.4), bevel=0.03, seg=1, tint=hexc("e8e4da"))     # a stair head
    for k in range(5):                                                                                    # a roof terrace with planters and solar panels
        m.box(CONC, (X1 - 4.5 + k * 0.9, RT, Z1 - 1.4), (X1 - 3.8 + k * 0.9, RT + 0.5, Z1 - 0.8), bevel=0.02, seg=1)
        m.dome("leaf", (X1 - 4.15 + k * 0.9, RT + 0.5, Z1 - 1.1), 0.3, 0.3, 6, 2, tint=hexc("4f8046"))
    for k in range(4):
        m.hull("solar", [(0.0 + k * 1.5, RT, Z0 + 1.4), (1.3 + k * 1.5, RT, Z0 + 1.4), (0.0 + k * 1.5, RT, Z0 + 2.4), (1.3 + k * 1.5, RT, Z0 + 2.4), (0.0 + k * 1.5, RT + 0.6, Z0 + 1.4), (1.3 + k * 1.5, RT + 0.6, Z0 + 1.4)])
    for k in range(6):                                                                                    # a car park
        m.box(CONC, (-8.0 + k * 2.6, 0.13, 3.0), (-7.9 + k * 2.6, 0.135, 6.6), tint=(1.8, 1.8, 1.7))
    for i, c in enumerate((hexc("e8ecee"), hexc("26384e"), hexc("a8322a"))):
        with m.frame((-6.7 + i * 2.6, 0, 4.8), yaw=math.pi):
            m.box("paint", (-0.85, 0.3, -1.9), (0.85, 0.9, 1.9), bevel=0.15, seg=3, tint=c)
            m.box(GLASS, (-0.74, 0.9, -1.0), (0.74, 1.4, 0.9), bevel=0.12, seg=2)
            for sx in (-1, 1):
                for sz in (-1.2, 1.2):
                    m.pipe("dark", (sx * 0.78, 0.33, sz), (sx * 0.96, 0.33, sz), 0.33, 12)
    m.box("asphalt", (-9.0, 0.13, 1.4), (9.0, 0.15, 2.8))
    for p in ((7.8, 4.4), (-8.4, 8.0), (3.0, 8.6), (8.6, -2.0)):
        tree(m, p[0], p[1], 2.2, 1.0)
    for k in range(3):
        lamp(m, 1.0 + k * 3.0, 3.2)
else:   # villageCenter
    m.cyl("turf", (0.0, 0.13, 2.0), 5.0, 0.04, 28, tint=hexc("6a9a50"))                                    # the village green
    if STYLE in ("euro", "med", "us"):
        # the chapel with a bell tower
        m.box(STONE, (-3.4, 0.13, -8.4), (1.6, 4.0, -3.4), bevel=0.03, seg=1)
        gable_roof(m, -3.4, 1.6, -8.4, -3.4, 4.0, 2.2, overhang=0.35, role=roofrole("roof_slate"))
        for k in range(3):
            pts = [(math.cos(math.pi * j / 8) * 0.4, 2.1 + math.sin(math.pi * j / 8) * 0.4) for j in range(9)]
            wx = -2.8 + k * 1.5
            m.box("dark", (wx - 0.4, 1.0, -3.43), (wx + 0.4, 2.1, -3.4))
            m.hull("dark", [(wx + a, b, -3.43) for a, b in pts] + [(wx + a, b, -3.4) for a, b in pts])
            m.box(GLASS, (wx - 0.4, 1.0, -3.4), (wx + 0.4, 2.1, -3.37), tint=(1.8, 1.6, 1.2))
        door(-0.9, -3.4, 1.2, 2.2)
        m.box(STONE, (1.6, 0.13, -8.4), (3.6, 7.0, -6.4), bevel=0.03, seg=1)                                 # the tower
        for f in range(2):
            m.box("dark", (2.2, 5.0 + f * 0.0, -6.43), (3.0, 6.4, -6.4))
        m.hull(roofrole("roof_slate"), [(1.4, 7.0, -8.6), (3.8, 7.0, -8.6), (1.4, 7.0, -6.2), (3.8, 7.0, -6.2), (2.6, 9.4, -7.4)])
        m.pipe("gold", (2.6, 9.4, -7.4), (2.6, 10.2, -7.4), 0.04, 6)
        m.pipe("gold", (2.3, 10.0, -7.4), (2.9, 10.0, -7.4), 0.03, 5)
    elif STYLE == "asia":                                                                                       # a shrine with a torii gate and a stone lantern
        m.box(STONE, (-3.2, 0.13, -8.2), (1.2, 0.9, -3.8), bevel=0.03, seg=1)
        m.box("plaster", (-2.6, 0.9, -7.6), (0.6, 3.6, -4.4), bevel=0.03, seg=1, tint=hexc("f0ece0"))
        hip_roof(m, -2.6, 0.6, -7.6, -4.4, 3.6, 1.8, overhang=0.9, role="roof_slate")
        for k in range(4):
            m.pipe("paint", (-2.5 + k * 1.05, 0.9, -4.45), (-2.5 + k * 1.05, 3.5, -4.45), 0.09, 8, tint=hexc("a8322a"))
        m.box("dark", (-1.2, 0.9, -4.42), (-0.2, 2.6, -4.38))
        for sx in (-1, 1):
            m.pipe("paint", (-1.0 + sx * 1.6, 0.13, -2.4), (-1.0 + sx * 1.6, 3.0, -2.4), 0.14, 10, tint=hexc("a8322a"))
        m.box("paint", (-3.0, 3.0, -2.55), (1.0, 3.3, -2.25), tint=hexc("a8322a"))
        m.box("paint", (-3.3, 3.3, -2.6), (1.3, 3.5, -2.2), tint=hexc("1d252a"))
        m.cyl(STONE, (2.6, 0.13, -3.0), 0.2, 1.0, 8)
        m.box(STONE, (2.35, 1.13, -3.25), (2.85, 1.55, -2.75), bevel=0.03, seg=1)
        m.box("glow_warm", (2.45, 1.2, -3.15), (2.75, 1.5, -2.85))
        hip_roof(m, 2.3, 2.9, -3.3, -2.7, 1.55, 0.35, overhang=0.15, role="roof_slate")
    else:                                                                                                         # a small mosque: a dome and a minaret
        m.box("plaster", (-3.4, 0.13, -8.4), (1.2, 3.8, -4.2), bevel=0.03, seg=1, tint=hexc("f0e8d8"))
        m.lathe("copper", (-1.1, 3.8, -6.3), [(0.0, 0.0), (2.0, 0.0), (1.9, 0.7), (1.3, 1.5), (0.6, 2.0), (0.0, 2.2)], 24)
        m.pipe("gold", (-1.1, 6.0, -6.3), (-1.1, 6.7, -6.3), 0.04, 6, r2=0.012)
        m.box("dark", (-1.6, 0.13, -4.22), (-0.6, 2.6, -4.18))
        for k in range(3):
            m.box("dark", (-3.0 + k * 1.6 - 0.35, 1.2, -4.22), (-3.0 + k * 1.6 + 0.35, 2.6, -4.18))
        m.cyl("plaster", (2.4, 0.13, -4.6), 0.55, 6.0, 14, tint=hexc("f0e8d8"), r2=0.45)
        m.tube(STONE, (2.4, 6.1, -4.6), 0.8, 0.45, 0.2, 14)
        m.cyl("copper", (2.4, 6.3, -4.6), 0.5, 1.8, 14, r2=0.0)
        m.pipe("gold", (2.4, 8.1, -4.6), (2.4, 8.7, -4.6), 0.03, 5, r2=0.01)
    # the inn
    house(6.0, -4.6, -0.3, 5.0, 3.8, 2, wall=hexc("d8c4a8"), roof="roof_tile", flh=2.8)
    m.box("paint", (4.4, 2.8, -2.5), (6.6, 3.5, -2.45), tint=hexc("c0392b"))
    for p in ((-7.2, -1.0, 0.5), (-6.6, 4.2, math.pi / 2 + 0.2)):
        house(p[0], p[1], p[2], 4.0, 3.4, 1, roof="roof_tile")
    house(7.0, 3.6, -math.pi / 2 - 0.2, 4.0, 3.4, 2, roof="roof_tile")
    m.cyl(STONE, (0.0, 0.13, 1.6), 0.7, 0.7, 14)                                                          # the well
    for sx in (-0.6, 0.6):
        m.pipe("wood", (sx, 0.83, 1.6), (sx, 2.0, 1.6), 0.05, 6)
    m.hull(roofrole("roof_tile"), [(-0.9, 2.0, 1.1), (0.9, 2.0, 1.1), (-0.9, 2.0, 2.1), (0.9, 2.0, 2.1), (0.0, 2.6, 1.1), (0.0, 2.6, 2.1)])
    if STYLE in ("euro", "med", "us"):
        m.box(STONE, (-0.5, 0.13, 4.6), (0.5, 0.4, 5.6), bevel=0.02, seg=1)                                  # a market cross
        m.box(STONE, (-0.35, 0.4, 4.75), (0.35, 0.7, 5.45), bevel=0.02, seg=1)
        m.pipe(STONE, (0.0, 0.7, 5.1), (0.0, 2.4, 5.1), 0.12, 8)
        m.box(STONE, (-0.5, 1.7, 5.02), (0.5, 1.9, 5.18), bevel=0.02, seg=1)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lamp(m, math.cos(a) * 9.6, math.sin(a) * 9.6)
    for p in ((-3.4, 7.6), (3.4, 7.8), (-8.4, 8.0), (8.8, 8.0), (-8.8, -6.4)):
        tree(m, p[0], p[1], 2.4, 1.1)
    for sx in (-1, 1):
        bench(m, sx * 3.0, 2.0, math.pi / 2)
    flagpole(m, 4.6, 3.4, 8.0)
m.finish(out)
