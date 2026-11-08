"""Resource and farm buildings, modelled in Blender.   blender -b -P build_resources.py -- <out.glb> <variant>

Variants (each fills a hex): farm, oil, iron, gold, silicon, uranium, diamond, oilRefinery, chipFab, nuclearReactor, solarFarm.
The six deposit variants are what an Extractor becomes on each kind of deposit. Front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_kit import Model, P, hexc
from bl_parts import truck, fan, fence_poly, slats, lattice, vent_stack, crate, drum, container
from bl_civic import lamp, flagpole, tree, gable_roof, bench

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "resource.glb"
VAR = args[1] if len(args) > 1 else "oil"
m = Model("res_" + VAR)
rng = random.Random(abs(hash(VAR)) % 1000 + 11)
CONC, CLAD, METAL, DARK, GLASS = "wall_concrete", "cladding", "metal", "steel_dark", "glass"
ORANGE = hexc("c8902a")
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def heap(x, z, rx, rz, h, tint, role="earth"):
    def f(xx, zz):
        d = ((xx - x) / rx) ** 2 + ((zz - z) / rz) ** 2
        return -0.03 if d >= 1.0 else h * (1.0 - d) ** 0.8 + 0.12 * noise(xx * 2, zz * 2) * (1.0 - d)
    m.grid(role, x - rx, x + rx, z - rz, z + rz, f, max(6, int(rx * 5)), max(6, int(rz * 5)), base=0.1, tint=tint)


def tank(x, z, r, h, tint=hexc("e8ecee"), dome=True):
    m.cyl("paint", (x, 0.1, z), r, h, 20, tint=tint)
    if dome:
        m.dome("paint", (x, 0.1 + h, z), r, 0.3, 20, 4, tint=tint)
    for y in (h * 0.3, h * 0.65):
        m.tube("paint", (x, 0.1 + y, z), r + 0.03, r - 0.02, 0.06, 20, tint=hexc("8a949a"))


def headframe(x, z, h, tint):
    """A mine headframe: an A-frame of lattice legs, two sheave wheels, a winding house, a skip and a rope."""
    for sx in (-1, 1):
        m.pipe("paint", (x + sx * 1.6, 0.1, z - 1.0), (x + sx * 0.3, h, z), 0.12, 8, tint=tint)
        m.pipe("paint", (x + sx * 1.6, 0.1, z + 1.0), (x + sx * 0.3, h, z), 0.12, 8, tint=tint)
    for y in (2.5, 5.0, 7.5):
        t = 1.0 - y / h
        for sz in (-1, 1):
            m.pipe("paint", (x - 1.6 * t - 0.3 * (1 - t), y, z + sz * t), (x + 1.6 * t + 0.3 * (1 - t), y, z + sz * t), 0.04, 4, tint=tint)
    with m.frame((x, h, z), pitch=math.pi / 2):
        for sz in (-0.4, 0.4):
            m.tube(METAL, (0, 0.2 + sz * 0.0, sz), 0.55, 0.45, 0.1, 18)
    m.wire(METAL, [(x + 0.0, h - 0.5, z), (x + 0.0, 1.0, z)], 0.025, 4)
    m.box(DARK, (x - 0.5, 0.1, z - 0.5), (x + 0.5, 1.2, z + 0.5), bevel=0.04, seg=1)                 # the skip
    m.box(CLAD, (x + 2.6, 0.1, z - 1.2), (x + 5.0, 2.8, z + 1.2), bevel=0.04, seg=1, tint=hexc("c8cdd0"))     # the winding house
    m.hull(CLAD, [(x + 2.4, 2.8, z - 1.4), (x + 5.2, 2.8, z - 1.4), (x + 2.4, 2.8, z + 1.4), (x + 5.2, 2.8, z + 1.4), (x + 3.8, 3.5, z - 1.4), (x + 3.8, 3.5, z + 1.4)], tint=(0.7, 0.72, 0.75))
    m.cyl("glow_red", (x, h + 0.2, z), 0.08, 0.2, 8)


def conveyor(a, b, w=0.5):
    m.pipe(METAL, a, b, 0.0 + w / 2, 4)
    m.pipe("dark", (a[0], a[1] + 0.3, a[2]), (b[0], b[1] + 0.3, b[2]), 0.12, 8)
    n = 6
    for k in range(n + 1):
        t = k / n
        px, py, pz = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        m.pipe(METAL, (px, 0.1, pz - 0.2), (px, py, pz - 0.05), 0.03, 5)
        m.pipe(METAL, (px, 0.1, pz + 0.2), (px, py, pz + 0.05), 0.03, 5)


def shed(x0, z0, x1, z1, h, wall, roof_t=0.8):
    m.box(CLAD, (x0, 0.1, z0), (x1, h, z1), bevel=0.04, seg=1, tint=wall)
    m.hull(CLAD, [(x0 - 0.2, h, z0 - 0.2), (x1 + 0.2, h, z0 - 0.2), (x0 - 0.2, h, z1 + 0.2), (x1 + 0.2, h, z1 + 0.2), (x0 - 0.2, h + roof_t, (z0 + z1) / 2), (x1 + 0.2, h + roof_t, (z0 + z1) / 2)], tint=(0.7, 0.72, 0.75))


def fenced(h=1.7, gate=(-1.6, 1.6)):
    fence_poly(m, 11.0, gate=gate, hazard_every=5, h=h)
    for p in ((-9.0, 3.0), (9.0, 3.0), (-9.0, -8.0), (9.0, -8.2), (0.0, 8.6)):
        m.pipe(METAL, (p[0], 0.1, p[1]), (p[0], 5.0, p[1]), 0.05, 8)
        m.box(DARK, (p[0] - 0.4, 5.0, p[1] - 0.16), (p[0] + 0.4, 5.1, p[1] + 0.16), bevel=0.02, seg=1)
        m.box("glow_warm", (p[0] - 0.36, 4.97, p[1] - 0.13), (p[0] + 0.36, 5.0, p[1] + 0.13))


def gate_house(x=-0.0, z=7.2):
    m.box(CLAD, (x - 0.9, 0.1, z - 0.6), (x + 0.9, 2.4, z + 0.6), bevel=0.04, seg=1, tint=hexc("d8d4c0"))
    m.box(CONC, (x - 1.0, 2.4, z - 0.7), (x + 1.0, 2.55, z + 0.7), bevel=0.03, seg=1)
    m.box(GLASS, (x - 0.8, 1.1, z + 0.58), (x + 0.8, 2.2, z + 0.64), tint=(1.6, 1.8, 2.0))
    m.pipe(METAL, (x + 1.0, 1.0, z), (x + 2.6, 1.0, z), 0.05, 6)


m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.15, 8.2))

# ------------------------------------------------------------------ the variants
if VAR == "farm":
    m.box("turf", (-9.4, 0.1, -9.2), (9.4, 0.14, 8.2), tint=hexc("7aa050"))
    # Farm lane handled by district.gdshader
    # the barn: red, gambrel roof, white trim, a loft door and a cupola
    BX0, BX1, BZ0, BZ1 = -3.8, 3.8, -9.0, -3.4
    m.box("stone", (BX0 - 0.2, 0.1, BZ0 - 0.2), (BX1 + 0.2, 0.7, BZ1 + 0.2), bevel=0.03, seg=1)
    m.box("wood", (BX0, 0.7, BZ0), (BX1, 4.4, BZ1), bevel=0.02, seg=1, tint=hexc("a8432f"))
    for k in range(int((BX1 - BX0) / 0.3)):
        m.box("wood", (BX0 + k * 0.3, 0.7, BZ1), (BX0 + k * 0.3 + 0.03, 4.4, BZ1 + 0.03), tint=hexc("8f3a2a"))
    m.box("paint", (-1.6, 0.7, BZ1), (1.6, 3.8, BZ1 + 0.1), tint=hexc("8f3a2a"))
    m.box("paint", (-1.7, 3.8, BZ1), (1.7, 3.95, BZ1 + 0.14), tint=hexc("efe9dc"))
    for dx in (-0.8, 0.8):
        m.box("paint", (dx - 0.7, 1.7, BZ1 + 0.1), (dx + 0.7, 1.85, BZ1 + 0.15), tint=hexc("efe9dc"))
    m.box("paint", (-0.05, 0.7, BZ1 + 0.1), (0.05, 3.8, BZ1 + 0.15), tint=hexc("efe9dc"))
    for sx in (BX0, BX1):
        for sz in (BZ0, BZ1):
            m.box("paint", (sx - 0.14, 0.7, sz - 0.14), (sx + 0.14, 4.5, sz + 0.14), tint=hexc("efe9dc"))
    m.hull("roof_slate", [(BX0 - 0.4, 4.4, BZ0 - 0.3), (BX1 + 0.4, 4.4, BZ0 - 0.3), (BX0 - 0.4, 4.4, BZ1 + 0.3), (BX1 + 0.4, 4.4, BZ1 + 0.3), (BX0 + 0.8, 6.0, BZ0 + 0.6), (BX1 - 0.8, 6.0, BZ0 + 0.6), (BX0 + 0.8, 6.0, BZ1 - 0.6), (BX1 - 0.8, 6.0, BZ1 - 0.6)])
    m.box("paint", (-0.6, 6.0, (BZ0 + BZ1) / 2 - 0.6), (0.6, 7.0, (BZ0 + BZ1) / 2 + 0.6), tint=hexc("efe9dc"))
    m.hull("roof_slate", [(-0.8, 7.0, (BZ0 + BZ1) / 2 - 0.8), (0.8, 7.0, (BZ0 + BZ1) / 2 - 0.8), (-0.8, 7.0, (BZ0 + BZ1) / 2 + 0.8), (0.8, 7.0, (BZ0 + BZ1) / 2 + 0.8), (0.0, 7.8, (BZ0 + BZ1) / 2)])
    m.box("paint", (-0.6, 4.5, BZ1 - 0.05), (0.6, 5.5, BZ1 + 0.08), tint=hexc("8f3a2a"))
    # the farmhouse
    FX, FZ = -7.0, -2.0
    m.box("plaster", (FX - 2.0, 0.1, FZ - 1.6), (FX + 2.0, 3.2, FZ + 1.6), bevel=0.03, seg=1, tint=hexc("efe4cc"))
    gable_roof(m, FX - 2.0, FX + 2.0, FZ - 1.6, FZ + 1.6, 3.2, 1.9, overhang=0.35, role="roof_tile")
    m.box("brick", (FX + 1.0, 3.3, FZ - 0.3), (FX + 1.7, 5.0, FZ + 0.3), bevel=0.02, seg=1)
    m.marker("Smoke_Home_0", (FX + 1.35, 5.2, FZ))
    for k in range(3):
        m.box("dark", (FX - 1.4 + k * 1.2, 1.4, FZ + 1.58), (FX - 0.7 + k * 1.2, 2.5, FZ + 1.62))
        m.box(GLASS, (FX - 1.4 + k * 1.2, 1.4, FZ + 1.6), (FX - 0.7 + k * 1.2, 2.5, FZ + 1.64), tint=(1.6, 1.8, 2.0))
    m.box("wood", (FX - 0.9, 0.1, FZ + 1.6), (FX + 0.9, 0.3, FZ + 3.0), tint=hexc("c8b8a0"))                 # a porch
    for sx in (-0.85, 0.85):
        m.pipe("paint", (FX + sx, 0.3, FZ + 2.9), (FX + sx, 2.4, FZ + 2.9), 0.05, 6, tint=hexc("efe9dc"))
    m.box("wood", (FX - 1.0, 2.4, FZ + 1.5), (FX + 1.0, 2.5, FZ + 3.1), tint=hexc("6a5a3a"))
    # a silo, a windmill, hay bales, a tractor, a pond, fences, crop rows
    for i, (sx, sz) in enumerate(((4.6, -6.6), (6.6, -6.6))):
        m.cyl("cladding", (sx, 0.1, sz), 1.0, 7.0 - i * 1.0, 20, tint=hexc("c9ced0"))
        m.cyl("cladding", (sx, 7.1 - i * 1.0, sz), 1.1, 1.0, 20, r2=0.2, tint=hexc("b9c0c4"))
        for k in range(8):
            m.tube("cladding", (sx, 0.5 + k * 0.85, sz), 1.04, 0.98, 0.08, 20, tint=hexc("aab2b6"))
    WX, WZ = 7.2, -1.8
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        m.pipe("paint", (WX + math.cos(a) * 0.9, 0.1, WZ + math.sin(a) * 0.9), (WX, 5.0, WZ), 0.06, 6, tint=hexc("b8bcbe"))
    m.box("paint", (WX - 0.4, 5.0, WZ - 0.4), (WX + 0.4, 5.6, WZ + 0.4), tint=hexc("b8bcbe"))
    for k in range(6):
        a = math.tau * k / 6
        m.hull("paint", [(WX, 5.3, WZ + 0.5), (WX + math.cos(a) * 0.15, 5.3 + math.sin(a) * 0.15, WZ + 0.5), (WX + math.cos(a) * 2.0, 5.3 + math.sin(a) * 2.0, WZ + 0.5), (WX + math.cos(a + 0.3) * 1.9, 5.3 + math.sin(a + 0.3) * 1.9, WZ + 0.5),
                                (WX, 5.3, WZ + 0.54), (WX + math.cos(a) * 2.0, 5.3 + math.sin(a) * 2.0, WZ + 0.54)], tint=hexc("efe9dc"))
    for k in range(5):
        with m.frame((-7.4 + k * 1.3, 0.1, 3.0 + (k % 2) * 0.4), yaw=rng.uniform(-0.3, 0.3)):
            m.pipe("paint", (-0.6, 0.55, 0), (0.6, 0.55, 0), 0.55, 14, tint=hexc("d8c470"))
    # Toy tractor and micro-strip removed; district.gdshader renders full-hex ploughed soil & crops
    for k in range(18):                                                                                       # a post fence
        m.pipe("wood", (-9.2 + k * 1.1, 0.1, 8.0), (-9.2 + k * 1.1, 1.0, 8.0), 0.04, 5)
    m.box("wood", (-9.2, 0.5, 7.98), (10.0, 0.55, 8.02))
    m.box("wood", (-9.2, 0.85, 7.98), (10.0, 0.9, 8.02))
    for p in ((-9.0, -8.0), (9.0, 0.0), (-3.0, 3.0)):
        tree(m, p[0], p[1], 2.5, 1.2)
elif VAR == "oil":
    for sx in (-1, 1):                                                                                        # a drilling derrick
        for sz in (-1, 1):
            m.pipe("paint", (-4.0 + sx * 1.6, 0.1, -2.0 + sz * 1.6), (-4.0 + sx * 0.4, 12.0, -2.0 + sz * 0.4), 0.1, 6, tint=ORANGE)
    for y in (2.0, 4.5, 7.0, 9.5):
        t = 1.0 - y / 12.5
        pts = [(-4.0 + sx * (0.4 + 1.2 * t), y, -2.0 + sz * (0.4 + 1.2 * t)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1), (-1, -1))]
        for a_, b_ in zip(pts, pts[1:]):
            m.pipe("paint", a_, b_, 0.04, 4, tint=ORANGE)
        for a_, b_ in zip(pts, pts[1:]):
            m.pipe("paint", (a_[0], y, a_[2]), (b_[0], y + 2.0, b_[2]), 0.03, 4, tint=ORANGE)
    m.box(DARK, (-4.4, 12.0, -2.4), (-3.6, 12.6, -1.6), bevel=0.03, seg=1)
    m.pipe(METAL, (-4.0, 12.0, -2.0), (-4.0, 0.1, -2.0), 0.08, 6)
    m.box(DARK, (-5.6, 0.1, -3.6), (-2.4, 0.9, -0.4), bevel=0.04, seg=1)                                       # the rig floor
    m.box(CLAD, (-8.8, 0.1, -3.4), (-6.2, 2.4, -0.6), bevel=0.04, seg=1, tint=hexc("d8d4c0"))                 # a doghouse
    m.cyl("glow_red", (-4.0, 12.7, -2.0), 0.08, 0.2, 8)
    for i in range(3):
        tank(3.6, -6.6 + i * 3.0, 1.2, 3.0, hexc("e8ecee"))
    m.pipe(METAL, (-2.4, 1.0, -0.8), (2.4, 1.0, -5.0), 0.1, 10)
    m.cyl("paint", (0.2, 0.1, 4.2), 0.6, 2.8, 14, tint=hexc("d8d4c8"))                                         # the separator
    # a pumpjack
    with m.frame((5.0, 0.1, 3.4)):
        m.box(DARK, (-0.8, 0.0, -0.5), (0.8, 0.3, 0.5), bevel=0.03, seg=1)
        m.pipe("paint", (-0.5, 0.3, 0), (0.0, 2.2, 0), 0.08, 6, tint=ORANGE)
        m.pipe("paint", (0.5, 0.3, 0), (0.0, 2.2, 0), 0.08, 6, tint=ORANGE)
        m.pipe("paint", (-1.8, 2.4, 0), (1.2, 2.0, 0), 0.12, 8, tint=ORANGE)
        m.hull("paint", [(-2.1, 2.1, -0.1), (-1.6, 2.1, -0.1), (-2.1, 2.7, -0.1), (-1.6, 2.7, -0.1), (-2.1, 2.1, 0.1), (-1.6, 2.7, 0.1)], tint=ORANGE)
        m.pipe(METAL, (1.2, 2.0, 0), (1.2, 0.3, 0), 0.03, 5)
        m.cyl("paint", (-1.0, 0.3, 0.0), 0.6, 0.1, 14, tint=ORANGE)
    for k in range(5):                                                                                          # barrels
        drum(m, -8.6 + k * 0.9, 5.4)
    for k in range(4):
        m.hull("hazard" if k % 2 == 0 else "dark", [(-1.5 + k * 0.7, 0.1, 6.0), (-0.9 + k * 0.7, 0.1, 6.0), (-1.5 + k * 0.7, 0.9, 6.0), (-0.9 + k * 0.7, 0.9, 6.0), (-1.5 + k * 0.7, 0.1, 6.05), (-0.9 + k * 0.7, 0.9, 6.05)])
    m.marker("Smoke_Industry_0", (-4.0, 12.8, -2.0))
    gate_house()
    fenced()
elif VAR in ("iron", "gold", "uranium", "diamond"):
    hf = {"iron": hexc("7a3a2e"), "gold": hexc("8a949a"), "uranium": hexc("8a949a"), "diamond": hexc("5a6a9a")}[VAR]
    headframe(-2.5, -3.0, 11.0 if VAR == "iron" else 9.5, hf)
    if VAR == "iron":
        heap(5.2, -3.4, 3.0, 2.4, 3.0, hexc("8a4a30"), "earth")
        conveyor((1.0, 1.0, -3.0), (4.6, 3.0, -3.0))
        for i in range(3):
            m.box("paint", (2.6 + i * 1.8, 0.1, 3.4), (4.2 + i * 1.8, 1.4, 5.2), bevel=0.05, seg=1, tint=hexc("7a4a3a"))
            m.box(DARK, (2.6 + i * 1.8, 1.4, 3.4), (4.2 + i * 1.8, 1.55, 5.2), bevel=0.02, seg=1)
        truck(m, -6.0, 3.6, yaw=math.pi / 2, canvas=False, bed=4.0, body=hexc("c9972a"))
    elif VAR == "gold":
        shed(3.0, -2.0, 7.4, 3.4, 4.4, hexc("8a6a48"), 1.6)                                                     # the stamp mill
        for k in range(6):
            m.box("wood", (3.0, 0.5 + k * 0.7, 3.4), (7.4, 0.55 + k * 0.7, 3.45), tint=(0.7, 0.6, 0.45))
        for k in range(3):
            m.pipe("wood", (3.4 + k * 1.6, 4.4, 3.4), (3.4 + k * 1.6, 2.6, 4.4), 0.1, 6)
        heap(0.0, 5.4, 2.0, 1.2, 1.2, hexc("d0b060"), "earth")
        m.box("hazard", (-8.0, 0.1, 6.4), (-5.4, 0.9, 7.6), bevel=0.04, seg=1, tint=(0.9, 0.7, 0.2))
        for k in range(4):
            m.box("dark", (-7.8 + k * 0.6, 0.9, 6.6), (-7.4 + k * 0.6, 1.4, 7.4))
    elif VAR == "uranium":
        m.box(CLAD, (1.6, 3.0, 0.8), (6.0, 3.15, 5.2), bevel=0.02, seg=1, tint=hexc("8a949a"))
        for x in (1.8, 5.8):
            for z in (1.0, 5.0):
                m.pipe(METAL, (x, 0.1, z), (x, 3.0, z), 0.08, 6)
        for i in range(9):
            m.cyl("paint", (2.4 + (i % 3) * 1.4, 0.1, 1.6 + (i // 3) * 1.4), 0.45, 1.1, 12, tint=hexc("e0c030"))
            m.box("hazard", (2.4 + (i % 3) * 1.4 - 0.1, 0.6, 1.6 + (i // 3) * 1.4 + 0.44), (2.4 + (i % 3) * 1.4 + 0.1, 0.8, 1.6 + (i // 3) * 1.4 + 0.47))
        for k in range(8):
            m.box("hazard" if k % 2 == 0 else "dark", (-1.0 + k * 1.0, 0.1, -0.3), (-0.5 + k * 1.0, 0.7, -0.2))
        m.box("hazard", (-0.4, 1.2, 0.0), (0.4, 1.9, 0.05), tint=(0.9, 0.7, 0.1))
    else:   # diamond: an open pit with terraces and a loading ramp
        for r_, h_ in ((4.4, 0.0), (3.4, -0.4), (2.4, -0.8)):
            m.cyl("earth", (4.0, 0.12 + h_, 2.0), r_, 0.08, 28, tint=(0.85, 0.8, 0.75))
        m.cyl("dark", (4.0, -0.6, 2.0), 1.6, 0.05, 20)
        m.box(CLAD, (-8.0, 0.1, 1.0), (-4.6, 2.8, 4.2), bevel=0.04, seg=1, tint=hexc("c8cdd0"))
        m.box("glow_cyan", (-7.6, 1.4, 4.18), (-5.0, 2.2, 4.2), tint=(0.8, 0.9, 1.0))
        for k in range(3):
            m.dome("paint", (-2.0 + k * 0.9, 0.1, 6.4), 0.3, 0.35, 8, 3, tint=hexc("dbe8f8"))
    gate_house()
    fenced()
elif VAR == "silicon":
    heap(-3.0, 1.0, 3.6, 1.8, 1.4, hexc("ded8c8"), "earth")
    heap(-1.0, -3.8, 2.4, 1.2, 1.1, hexc("e8e2d2"), "earth")
    lattice(m, 2.4, -3.5, 7.0, 1.4, 0.1, 0.06)
    m.pipe("paint", (2.4, 7.0, -3.5), (-3.0, 6.0, 0.5), 0.12, 8, tint=hexc("e0b030"))
    m.box(DARK, (2.0, 7.0, -3.9), (2.8, 7.5, -3.1), bevel=0.03, seg=1)
    shed(2.2, 0.5, 6.4, 4.1, 3.6, hexc("c8d0d4"), 1.0)                                                             # the washing plant
    m.box(GLASS, (2.4, 1.4, 4.08), (6.2, 3.0, 4.14), tint=(1.4, 1.7, 1.9))
    for k in range(3):
        m.cyl("paint", (-6.4 + k * 1.4, 0.1, 5.8), 0.6, 2.4, 16, tint=hexc("e8ecee"))
        m.dome("paint", (-6.4 + k * 1.4, 2.5, 5.8), 0.6, 0.3, 16, 3, tint=hexc("e8ecee"))
    for k in range(3):
        m.pipe("paint", (-3.0, 0.9 + k * 0.0, 3.4 + k * 0.5), (2.2, 1.2, 2.4), 0.1, 8, tint=hexc("2f6f7e"))
    truck(m, -5.0, -6.0, yaw=0.3, canvas=False, bed=3.4, body=hexc("e0b030"))
    gate_house()
    fenced()
elif VAR == "oilRefinery":
    for i in range(3):                                                                                           # distillation columns with bands and ladders
        cx = -4.0 + i * 1.9
        m.cyl("paint", (cx, 0.1, -3.5), 0.75 - i * 0.1, 8.0 + i * 2.0, 18, tint=hexc("c8ccc8"))
        for b in range(4):
            m.tube("paint", (cx, 2.0 + b * 2.0, -3.5), 0.82 - i * 0.1, 0.7 - i * 0.1, 0.16, 18, tint=hexc("8a8c88"))
        m.dome("paint", (cx, 8.1 + i * 2.0, -3.5), 0.75 - i * 0.1, 0.4, 18, 3, tint=hexc("c8ccc8"))
        for y in range(1, int(8 + i * 2)):
            m.pipe(METAL, (cx + 0.75 - i * 0.1, y, -3.5 - 0.06), (cx + 0.75 - i * 0.1, y, -3.5 + 0.06), 0.015, 4)
    for i in range(2):                                                                                           # spherical storage tanks on legs
        c = (3.0, 0.0, -4.2 + i * 4.2)
        m.dome("paint", (c[0], 2.0, c[2]), 1.6, 1.6, 22, 7, tint=hexc("e4e6e2"))
        with m.frame((c[0], 2.0, c[2]), pitch=math.pi):
            m.dome("paint", (0, 0, 0), 1.6, 1.6, 22, 7, tint=hexc("d8dad6"))
        for leg in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            m.pipe(METAL, (c[0] + leg[0] * 0.9, 0.1, c[2] + leg[1] * 0.9), (c[0] + leg[0] * 0.9, 2.0, c[2] + leg[1] * 0.9), 0.07, 6)
    for y in (1.8, 2.3):
        m.pipe("paint", (-4.0, y, 0.5), (4.5, y, 0.5), 0.12, 10, tint=hexc("7a6a4a"))
    for x in (-3.5, 0.0, 3.5):
        m.pipe(METAL, (x, 0.1, 0.5), (x, 2.4, 0.5), 0.08, 6)
    for k in range(4):                                                                                           # pipe racks across
        m.pipe("paint", (-4.0, 1.4 + k * 0.0, 1.0 + k * 0.3), (4.5, 1.4, 1.0 + k * 0.3), 0.1, 8, tint=[hexc("c0392b"), hexc("2f6f7e"), hexc("e0b020"), hexc("8a949a")][k])
    m.pipe(METAL, (-5.5, 0.1, 4.5), (-5.5, 13.0, 4.5), 0.25, 10)                                                 # the flare stack
    m.cyl("glow_warm", (-5.5, 13.0, 4.5), 0.35, 0.9, 10, r2=0.05, tint=(1.0, 0.8, 0.4))
    m.marker("Smoke_Industry_0", (-5.5, 14.0, 4.5))
    shed(-8.0, 6.0, -3.0, 8.0, 3.0, hexc("c8ccc8"), 0.8)
    for k in range(3):
        m.cyl("paint", (5.0 + k * 1.4, 0.1, 5.5), 0.5, 1.8, 14, tint=hexc("e8ecee"))
    truck(m, 2.0, 6.4, yaw=math.pi, canvas=False, bed=3.6, body=hexc("c9972a"))
    gate_house(0.0, 7.4)
    fenced()
elif VAR == "chipFab":
    W, D = 10.0, 6.6
    m.box(CONC, (-W / 2 - 0.2, 0.1, -D - 0.4), (W / 2 + 0.2, 0.5, 0.2), bevel=0.03, seg=1)
    m.box(CLAD, (-W / 2, 0.5, -D - 0.2), (W / 2, 5.4, 0.0), bevel=0.04, seg=1, tint=hexc("eceee8"))
    for k in range(int(W / 0.5)):
        m.box(CLAD, (-W / 2 + k * 0.5, 0.5, 0.0), (-W / 2 + k * 0.5 + 0.04, 5.4, 0.04), tint=hexc("d4d8d4"))
    m.box(GLASS, (-W * 0.45, 0.8, 0.0), (W * 0.45, 3.6, 0.06), tint=(1.2, 1.8, 2.4))
    for k in range(9):
        m.box(METAL, (-W * 0.45 + k * W * 0.9 / 8 - 0.04, 0.5, 0.0), (-W * 0.45 + k * W * 0.9 / 8 + 0.04, 3.8, 0.1), bevel=0.01, seg=1)
    for y in (0.8, 2.2, 3.6):
        m.box(METAL, (-W * 0.45, y - 0.03, 0.0), (W * 0.45, y + 0.03, 0.1))
    m.box("glow_cyan", (-W * 0.4, 1.0, -0.4), (W * 0.4, 3.4, -0.35), tint=(0.7, 0.85, 1.0))                  # a lit clean-room beyond
    m.box(CONC, (-W / 2 - 0.2, 5.4, -D - 0.4), (W / 2 + 0.2, 5.65, 0.2), bevel=0.03, seg=1)
    for i in range(4):                                                                                           # roof air handlers
        m.box(DARK, (-4.0 + i * 2.2, 5.65, -4.2), (-2.4 + i * 2.2, 6.9, -2.2), bevel=0.04, seg=1, tint=(1.4, 1.4, 1.4))
        fan(m, (-3.2 + i * 2.2, 6.9, -3.2), 0.6)
    for i in range(2):
        m.cyl(METAL, (3.0 + i * 1.3, 5.65, 0.0 - 1.0), 0.32, 3.0, 12)
        m.cyl(DARK, (3.0 + i * 1.3, 8.65, -1.0), 0.4, 0.08, 12)
    m.box("paint", (-W / 2, 4.5, 0.02), (-W / 2 + 3.0, 5.1, 0.07), tint=hexc("2f6f9e"))
    m.box("glow_warm", (-W / 2 + 0.2, 4.6, 0.07), (-W / 2 + 2.8, 5.0, 0.1), tint=(0.9, 0.9, 0.8))
    m.box(CLAD, (-8.8, 0.1, 3.2), (-5.6, 2.6, 6.2), bevel=0.04, seg=1, tint=hexc("dfe3e5"))                    # utilities
    for k in range(3):
        tank(-3.6 + k * 1.4, 4.8, 0.6, 2.2, hexc("e8ecee"))
    for k in range(5):
        m.box(DARK, (2.0 + k * 0.9, 0.1, 3.6), (2.7 + k * 0.9, 0.7, 4.6), bevel=0.03, seg=1)
        m.box("paint", (2.0 + k * 0.9, 0.7, 3.6), (2.7 + k * 0.9, 0.8, 4.6), tint=hexc("2f6f9e"))
    m.pipe("paint", (-5.6, 1.4, 4.0), (-W / 2, 1.4, 0.2), 0.12, 10, tint=hexc("2f6f7e"))
    truck(m, 6.2, 5.0, yaw=math.pi, canvas=False, bed=2.6, body=hexc("e8ecee"))
    gate_house()
    fenced()
elif VAR == "nuclearReactor":
    m.box(CONC, (-8.0, 0.1, -8.4), (8.0, 0.6, 1.4), bevel=0.03, seg=1)
    m.lathe(CONC, (-3.2, 0.6, -3.0), [(0.0, 0.0), (2.6, 0.0), (2.6, 5.6), (2.45, 5.9), (1.8, 7.0), (0.9, 7.7), (0.0, 7.95)], 32, tint=(1.15, 1.13, 1.1))    # the containment dome
    m.tube(CONC, (-3.2, 3.8, -3.0), 2.66, 2.56, 0.2, 32, tint=(0.9, 0.9, 0.92))
    m.box(DARK, (-3.9, 0.6, -0.45), (-2.5, 2.2, -0.35), bevel=0.02, seg=1)                                       # the airlock
    m.lathe(CONC, (4.2, 0.6, -5.2), [(0.0, 0.0), (2.9, 0.0), (2.5, 2.6), (1.9, 5.2), (1.7, 7.0), (1.8, 9.0), (2.1, 11.0), (1.95, 11.1), (0.0, 11.1)], 32, tint=(1.18, 1.16, 1.12))   # a cooling tower
    m.tube("dark", (4.2, 11.7, -5.2), 2.1, 1.9, 0.1, 32)
    m.cyl("glass", (4.2, 0.62, -5.2), 2.8, 0.1, 28, tint=(0.8, 0.9, 1.0))
    m.marker("Smoke_Industry_0", (4.2, 11.9, -5.2))
    m.box(CLAD, (0.2, 0.6, -3.6), (3.0, 4.6, 0.4), bevel=0.04, seg=1, tint=hexc("b8c0c4"))                         # the turbine hall
    m.hull(CLAD, [(0.0, 4.6, -3.8), (3.2, 4.6, -3.8), (0.0, 4.6, 0.6), (3.2, 4.6, 0.6), (0.0, 5.6, -1.6), (3.2, 5.6, -1.6)], tint=(0.7, 0.72, 0.75))
    for k in range(4):
        m.box(GLASS, (0.4 + k * 0.6, 2.4, 0.38), (0.9 + k * 0.6, 3.6, 0.44), tint=(1.4, 1.7, 1.9))
    vent_stack(m, -7.0, -7.0, 10.0, 0.6)
    m.marker("Smoke_Industry_1", (-7.0, 10.4, -7.0))
    for k in range(3):                                                                                           # transformers and the switchyard
        m.box(METAL, (-7.2 + k * 2.0, 0.1, 3.2), (-6.0 + k * 2.0, 1.6, 4.4), bevel=0.05, seg=2, tint=(0.85, 0.95, 0.9))
        for q in range(3):
            m.pipe("paint", (-6.9 + k * 2.0 + q * 0.4, 1.6, 3.8), (-6.9 + k * 2.0 + q * 0.4, 2.5, 3.8), 0.08, 8, tint=hexc("d9c9a8"))
    lattice(m, 2.0, 4.0, 6.0, 0.8, 0.1, 0.04)
    lattice(m, 6.6, 4.0, 6.0, 0.8, 0.1, 0.04)
    m.pipe(DARK, (2.0, 6.0, 4.0), (6.6, 6.0, 4.0), 0.05, 5)
    m.box(CLAD, (5.0, 0.1, 5.4), (8.4, 3.0, 7.4), bevel=0.04, seg=1, tint=hexc("e0e2dc"))
    m.box("glow_cyan", (5.4, 1.6, 7.38), (8.0, 2.6, 7.42), tint=(0.5, 0.7, 0.9))
    gate_house(0.0, 7.4)
    fenced(2.0)
else:   # solarFarm
    m.box("turf", (-9.4, 0.1, -9.2), (9.4, 0.14, 8.2), tint=hexc("7aa050"))
    for r_ in range(5):
        half = 7.0 - abs(r_ - 2) * 1.2
        z = -7.0 + r_ * 3.0
        for c in range(int(half / 1.1)):
            for sgn in (-1, 1):
                px = sgn * (0.8 + c * 1.1)
                if abs(px) > half:
                    continue
                with m.frame((px, 0.1, z), pitch=-0.5):
                    m.box("solar", (-0.5, 0.9, 0.0), (0.5, 0.95, 1.7), bevel=0.01, seg=1)
                    for q in range(3):
                        m.box(METAL, (-0.5, 0.95, q * 0.57), (0.5, 0.97, q * 0.57 + 0.03))
                    m.box(METAL, (-0.01, 0.95, 0.0), (0.01, 0.97, 1.7))
                m.pipe(METAL, (px - 0.4, 0.1, z + 0.4), (px - 0.4, 1.0, z + 0.1), 0.03, 4)
                m.pipe(METAL, (px + 0.4, 0.1, z + 0.4), (px + 0.4, 1.0, z + 0.1), 0.03, 4)
    m.box(CLAD, (6.2, 0.1, 4.4), (8.8, 2.6, 7.0), bevel=0.04, seg=1, tint=hexc("e0e2dc"))                        # the inverter house
    m.box(CONC, (6.1, 2.6, 4.3), (8.9, 2.75, 7.1), bevel=0.03, seg=1)
    slats(m, 6.6, 8.4, 0.5, 2.0, 7.0, tint=hexc("dfe4e6"))
    m.box(METAL, (4.6, 0.1, 5.0), (5.8, 1.6, 6.2), bevel=0.04, seg=1, tint=(0.85, 0.95, 0.9))                    # a transformer
    for q in range(3):
        m.pipe("paint", (4.8 + q * 0.4, 1.6, 5.6), (4.8 + q * 0.4, 2.4, 5.6), 0.07, 8, tint=hexc("d9c9a8"))
    for k in range(4):
        lamp(m, -6.0 + k * 4.0, 7.4)
    fenced(1.6)
m.finish(out)
