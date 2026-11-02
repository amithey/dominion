"""The Bunker, modelled in Blender.   blender -b -P build_bunker.py -- <out.glb>

A hardened pillbox (camouflage-painted concrete on a plinth, stepped roof slab with an earth cap, corner buttresses,
three splayed firing ports behind a stepped glacis, armoured cupola, searchlight, radio mast, vents, rear entrance and an
ammunition door), a revetted trench with earth banks and sandbag machine-gun nests, dragon's teeth, concertina wire and
camouflage netting over stores. Stands on a hex slab of radius 12.3 and fills the district; front is +z.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bl_kit
from bl_kit import Model, P
from mathutils import Matrix

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "bunker.glb"
m = Model("bunker")
rng = random.Random(11)

CONC = "wall_concrete"
BZ = -2.4          # centre of the pillbox in z
FZ = BZ + 2.6      # the front wall
BACK = BZ - 2.6    # the back wall


def noise(x, z, seed=0.0):
    return (math.sin(x * 1.7 + seed) * math.cos(z * 2.3 - seed) + math.sin(x * 3.9 + z * 3.1 + seed * 2.0) * 0.5) / 1.5


# ------------------------------------------------------------------ ground: the hex slab, gravel yard, road
slab = [(math.cos(math.radians(30 + 60 * k)) * 12.3, math.sin(math.radians(30 + 60 * k)) * 12.3) for k in range(6)]
m.polygon(CONC, slab, -1.6, 1.7)
m.box("gravel", (-9.4, 0.1, -9.2), (9.4, 0.16, 8.2), bevel=0.03, seg=1)
m.box("asphalt", (-1.0, 0.16, 4.2), (1.0, 0.2, 10.4))
for k in range(7):
    m.box("wall_concrete", (-0.05, 0.2, 4.7 + k * 0.8), (0.05, 0.215, 5.2 + k * 0.8), tint=(1.6, 1.6, 1.5))

# ------------------------------------------------------------------ the pillbox
m.box(CONC, (-4.6, 0.1, BACK - 0.2), (4.6, 0.8, FZ + 0.15), bevel=0.07)                               # plinth
# ports are splayed frusta: wide at the outer face, narrow inside
ports = [-2.6, 0.0, 2.6]
cutters = []
for x in ports:
    cutters.append([(x - 0.78, 1.55, FZ + 0.3), (x + 0.78, 1.55, FZ + 0.3), (x - 0.78, 2.5, FZ + 0.3), (x + 0.78, 2.5, FZ + 0.3),
                    (x - 0.78, 1.55, FZ), (x + 0.78, 1.55, FZ), (x - 0.78, 2.5, FZ), (x + 0.78, 2.5, FZ),
                    (x - 0.42, 1.85, FZ - 1.15), (x + 0.42, 1.85, FZ - 1.15), (x - 0.42, 2.2, FZ - 1.15), (x + 0.42, 2.2, FZ - 1.15)])
for sx in (-1.0, 1.0):     # side loopholes
    cutters.append([(sx * 4.2, 1.8, BZ - 0.5), (sx * 4.2, 2.25, BZ - 0.5), (sx * 4.2, 1.8, BZ + 0.5), (sx * 4.2, 2.25, BZ + 0.5),
                    (sx * 4.7, 1.55, BZ - 0.9), (sx * 4.7, 2.5, BZ - 0.9), (sx * 4.7, 1.55, BZ + 0.9), (sx * 4.7, 2.5, BZ + 0.9)])
m.cut_box("camo", (-4.4, 0.8, BACK), (4.4, 3.25, FZ), cutters, bevel=0.06, seg=2)
for x in ports:                                                          # the dark of each port, a mantlet and the gun
    m.box("dark", (x - 0.4, 1.87, FZ - 1.13), (x + 0.4, 2.18, FZ - 1.1))
    m.box("steel_dark", (x - 0.34, 1.84, FZ - 1.0), (x + 0.34, 2.2, FZ - 0.88), bevel=0.04)
    m.pipe("metal", (x, 2.02, FZ - 0.9), (x, 2.02, FZ + 0.95), 0.06, 10)
    m.pipe("steel_dark", (x, 2.02, FZ + 0.9), (x, 2.02, FZ + 1.1), 0.1, 10)
    for dx in (-1.0, 1.0):                                               # concrete frame, outward-splayed jambs
        m.hull(CONC, [(x + dx * 0.78, 1.5, FZ), (x + dx * 1.02, 1.5, FZ + 0.3), (x + dx * 1.02, 2.62, FZ + 0.3), (x + dx * 0.78, 2.62, FZ),
                      (x + dx * 0.78, 1.5, FZ + 0.01), (x + dx * 0.78, 2.62, FZ + 0.01)])
    m.box(CONC, (x - 1.05, 2.48, FZ - 0.02), (x + 1.05, 2.72, FZ + 0.42), bevel=0.05)
    m.box(CONC, (x - 1.05, 1.38, FZ - 0.02), (x + 1.05, 1.58, FZ + 0.34), bevel=0.05)
for sx in (-1.0, 1.0):
    m.box("dark", (sx * 4.2 - 0.04, 1.85, BZ - 0.4), (sx * 4.2 + 0.04, 2.2, BZ + 0.4))
# the roof: a stepped slab, a low parapet and the earth cap
m.box(CONC, (-4.7, 3.25, BACK - 0.3), (4.7, 3.68, FZ + 0.5), bevel=0.07)
m.box(CONC, (-4.45, 3.68, BACK - 0.05), (4.45, 3.95, FZ + 0.25), bevel=0.06)


def cap(x, z):
    ex = max(0.0, 1.0 - ((x - 1.8) / 2.6) ** 2 - ((z - (BZ - 0.2)) / 2.6) ** 2)
    return (0.1 + ex * (0.65 + 0.12 * noise(x * 2, z * 2))) if ex > 0 else -0.04


m.grid("turf", -0.9, 4.5, BZ - 2.8, BZ + 2.4, cap, 22, 20, base=3.95)
for x, z in [(-0.6, BZ + 1.7), (3.8, BZ - 2.0), (0.4, BZ - 2.3)]:       # a few sandbags and a tarp patch on the roof edge
    m.box("sandbag", (x - 0.35, 3.95, z - 0.2), (x + 0.35, 4.15, z + 0.2), bevel=0.06, yaw=rng.uniform(-0.4, 0.4), tint=(1.0, 0.95, 0.8))
for sx in (-1.0, 1.0):                                                   # corner buttresses, stepped
    for cz in (FZ, BACK):
        cx = sx * 4.4
        m.box(CONC, (cx - 0.5, 0.1, cz - 0.5), (cx + 0.5, 2.2, cz + 0.5), bevel=0.07)
        m.box(CONC, (cx - 0.35, 2.2, cz - 0.35), (cx + 0.35, 3.25, cz + 0.35), bevel=0.06)
for ix in range(8):                                                      # tie-bolt holes in the formwork
    for iy in range(2):
        m.cyl("dark", (-3.7 + ix * 1.05, 0.95 + iy * 1.2, FZ - 0.03), 0.045, 0.05, 6)
# the stepped glacis in front of the ports
for s in range(5):
    m.box(CONC, (-4.3, 0.1, FZ + 0.3 + s * 0.34), (4.3, 0.75 - s * 0.14, FZ + 0.64 + s * 0.34), bevel=0.04, seg=1)

# ------------------------------------------------------------------ the cupola, searchlight, mast, vents
cu = (-2.8, 3.95, BZ - 0.4)
cutters = [[(cu[0] + math.cos(a) * 0.7 - 0.18, cu[1] + 0.25, cu[2] + math.sin(a) * 0.7 - 0.18),
            (cu[0] + math.cos(a) * 1.2 + 0.18, cu[1] + 0.25, cu[2] + math.sin(a) * 1.2 + 0.18),
            (cu[0] + math.cos(a) * 0.7 - 0.18, cu[1] + 0.45, cu[2] + math.sin(a) * 0.7 - 0.18),
            (cu[0] + math.cos(a) * 1.2 + 0.18, cu[1] + 0.45, cu[2] + math.sin(a) * 1.2 + 0.18)] for a in [math.pi / 4 + k * math.pi / 2 for k in range(4)]]
m.cyl("metal", cu, 1.0, 0.7, 20)
m.dome("metal", (cu[0], cu[1] + 0.7, cu[2]), 0.85, 0.3, 20, 3)
for a in [math.pi / 4 + k * math.pi / 2 for k in range(4)]:
    m.box("dark", (cu[0] + math.cos(a) * 0.98 - 0.16, cu[1] + 0.27, cu[2] + math.sin(a) * 0.98 - 0.16),
          (cu[0] + math.cos(a) * 0.98 + 0.16, cu[1] + 0.43, cu[2] + math.sin(a) * 0.98 + 0.16))
m.pipe("steel_dark", (cu[0] + 0.3, cu[1] + 0.95, cu[2] + 0.2), (cu[0] + 0.3, cu[1] + 1.55, cu[2] + 0.2), 0.06, 8)
m.box("steel_dark", (cu[0] + 0.2, cu[1] + 1.55, cu[2] + 0.1), (cu[0] + 0.4, cu[1] + 1.67, cu[2] + 0.3), bevel=0.02, seg=1)
m.pipe("metal", (0.7, 3.95, BZ + 1.6), (0.7, 4.5, BZ + 1.6), 0.07, 8)                  # the searchlight
m.cyl("steel_dark", (0.7, 4.45, BZ + 1.6), 0.3, 0.45, 14)
m.cyl("glow_warm", (0.7, 4.45, BZ + 1.6 + 0.27), 0.25, 0.05, 14)
m.pipe("metal", (-1.4, 3.95, BZ - 1.9), (-1.4, 7.1, BZ - 1.9), 0.035, 6)                # radio mast with cross-arms and guys
for y in (5.0, 6.0):
    m.pipe("metal", (-1.9, y, BZ - 1.9), (-0.9, y, BZ - 1.9), 0.02, 4)
for gx, gz in [(-3.6, BZ - 2.6), (0.5, BZ - 2.6), (-1.4, BZ - 3.5)]:
    m.wire("metal", [(-1.4, 6.1, BZ - 1.9), (gx, 3.95, gz)], 0.008)
m.cyl("glow_red", (-1.4, 7.1, BZ - 1.9), 0.06, 0.1, 8)
for x, h in [(1.4, 1.0), (2.4, 0.6)]:                                                    # vent stacks
    m.cyl("steel_dark", (x, 3.95, BZ - 1.4), 0.1, h, 10)
    m.cyl("steel_dark", (x, 3.95 + h, BZ - 1.4), 0.17, 0.07, 10, r2=0.06)

# ------------------------------------------------------------------ the rear entrance and the ammunition door
m.box(CONC, (-1.4, 0.1, BACK - 0.9), (1.4, 2.5, BACK + 0.05), bevel=0.07)
m.box("steel_dark", (-0.5, 0.2, BACK - 0.97), (0.5, 2.0, BACK - 0.9), bevel=0.03, seg=1)
m.box("hazard", (-0.5, 1.0, BACK - 1.0), (0.5, 1.12, BACK - 0.97))
m.box(CONC, (-1.55, 2.5, BACK - 1.3), (1.55, 2.68, BACK - 0.1), bevel=0.05)
m.box("glow_warm", (-0.2, 2.42, BACK - 1.2), (0.2, 2.5, BACK - 0.9))
m.box("steel_dark", (-4.5, 0.2, BZ + 0.7), (-4.4, 2.0, BZ + 1.9), bevel=0.03, seg=1)
m.box("hazard", (-4.55, 1.0, BZ + 0.7), (-4.5, 1.12, BZ + 1.9))
m.box("glow_warm", (-4.62, 2.25, BZ + 1.1), (-4.5, 2.35, BZ + 1.5))

# ------------------------------------------------------------------ the trench: earth banks, plank revetment, bridge, ladder
TZ0, TZ1 = 3.0, 4.2
m.box("wood", (-6.8, 0.12, TZ0), (6.8, 0.17, TZ1))
for bank_z, face in ((TZ0 - 1.0, TZ0), (TZ1 + 1.0, TZ1)):
    for xa, xb in ((-6.9, -0.9), (0.9, 6.9)):
        sgn = 1.0 if face == TZ0 else -1.0     # slope away from the trench

        def prof(x, z, face=face, sgn=sgn):
            d = (face - z) if face == TZ0 else (z - face)          # distance behind the revetment
            if d < 0 or d > 1.0:
                return -0.02
            top = 0.9 + 0.1 * noise(x * 2.3, z * 2.0)
            return top * min(1.0, 0.25 + 0.75 * math.sin(min(1.0, (1.0 - d) * 1.5) * math.pi / 2))
        z0, z1 = (TZ0 - 1.0, TZ0) if face == TZ0 else (TZ1, TZ1 + 1.0)
        m.grid("earth", xa, xb, z0, z1, prof, int((xb - xa) * 2), 8, base=0.1)
for sz in (TZ0 - 0.03, TZ1 + 0.03):                                       # plank revetment on both inner faces
    for k in range(27):
        m.box("wood", (-6.75 + k * 0.5, 0.17, sz - 0.03), (-6.5 + k * 0.5, 0.82, sz + 0.03), tint=(0.9 + 0.1 * (k % 2), 0.9, 0.9))
m.box("wood", (-0.9, 0.8, TZ0 - 1.0), (0.9, 0.86, TZ1 + 1.0), bevel=0.01, seg=1)   # the plank bridge for the road
for z in (TZ0 + 0.1, TZ1 - 0.1):
    pass
for k in range(5):                                                                  # a ladder up from the trench
    m.pipe("metal", (5.8, 0.15 + k * 0.17, TZ0 + 0.05), (5.8, 0.15 + k * 0.17, TZ0 + 0.55), 0.015, 4)
m.pipe("metal", (5.8, 0.15, TZ0 + 0.05), (5.8, 1.0, TZ0 + 0.05), 0.02, 5)
m.pipe("metal", (5.8, 0.15, TZ0 + 0.55), (5.8, 1.0, TZ0 + 0.55), 0.02, 5)
for k in range(3):                                                                  # ammunition boxes on the floor
    m.box("camo", (-3.4 + k * 0.5, 0.17, TZ0 + 0.3), (-3.0 + k * 0.5, 0.45, TZ0 + 0.7), bevel=0.02, seg=1)


def sandbag_course(y, pts, yaw0=0.0):
    for i, (x, z, yaw) in enumerate(pts):
        j = rng.uniform(-0.03, 0.03)
        t = rng.choice([(1.0, 0.95, 0.8), (0.92, 0.88, 0.72), (1.05, 1.0, 0.85)])
        m.box("sandbag", (x - 0.2, y, z - 0.12), (x + 0.2, y + 0.2 + j, z + 0.12), bevel=0.06, seg=2, yaw=yaw + yaw0 + rng.uniform(-0.06, 0.06), tint=t)


# a parapet of sandbags along the outer bank
for course in range(2):
    pts = []
    xs = -6.7
    while xs < 6.6:
        if abs(xs) > 1.1:
            pts.append((xs + (0.2 if course % 2 else 0.0), TZ1 + 0.5, 0.0))
        xs += 0.42
    sandbag_course(1.0 + course * 0.2, pts)


def nest(cx, cz, face):
    """A horseshoe of sandbags 5 courses high, open towards +z, with a machine gun on a tripod and an ammunition box."""
    for course in range(5):
        y = 1.0 + course * 0.2
        off = 0.0 if course % 2 == 0 else 0.5
        pts = []
        for a in [math.radians(a) for a in range(-100, 101, 25)]:
            pts.append((cx + math.sin(a + off * 0.3) * 1.35, cz - math.cos(a + off * 0.3) * 1.2 + 1.0, -a))
        sandbag_course(y, pts)
    for k in range(3):                                                      # tripod, gun, shield
        ang = math.tau * k / 3
        m.pipe("steel_dark", (cx, 1.65, cz), (cx + math.cos(ang) * 0.45, 1.0, cz + math.sin(ang) * 0.45), 0.022, 5)
    m.box("steel_dark", (cx - 0.1, 1.6, cz - 0.3), (cx + 0.1, 1.82, cz + 0.35), bevel=0.02, seg=1)
    m.pipe("metal", (cx, 1.72, cz + 0.3), (cx, 1.72, cz + 1.2), 0.04, 8)
    m.cyl("steel_dark", (cx, 1.72, cz + 1.2), 0.07, 0.0, 8)
    m.box("steel_dark", (cx - 0.32, 1.5, cz + 0.55), (cx + 0.32, 1.95, cz + 0.6), bevel=0.01, seg=1)   # gun shield
    m.box("camo", (cx + 0.45, 1.0, cz - 0.3), (cx + 0.85, 1.25, cz + 0.1), bevel=0.02, seg=1)


nest(-5.2, TZ1 - 0.9, 0)
nest(5.2, TZ1 - 0.9, 0)

# ------------------------------------------------------------------ dragon's teeth, then concertina wire
def teeth(x0, x1, z):
    m.box(CONC, (x0 - 0.3, 0.1, z - 0.5), (x1 + 0.3, 0.22, z + 1.4), bevel=0.03, seg=1)
    n = int((x1 - x0) / 0.9)
    for k in range(n):
        for row in range(2):
            x = x0 + 0.45 + k * 0.9 + row * 0.45
            zz = z + row * 0.8
            m.hull(CONC, [(x - 0.42, 0.22, zz - 0.42), (x + 0.42, 0.22, zz - 0.42), (x - 0.42, 0.22, zz + 0.42), (x + 0.42, 0.22, zz + 0.42),
                          (x - 0.12, 1.05, zz - 0.12), (x + 0.12, 1.05, zz - 0.12), (x - 0.12, 1.05, zz + 0.12), (x + 0.12, 1.05, zz + 0.12)])


teeth(-8.8, -2.2, 6.0)
teeth(2.2, 8.8, 6.0)


def concertina(x0, x1, z):
    """Coils of razor wire: a helix of rings along x, three deep, held by pickets with strands between them."""
    for tier, (cy, dz) in enumerate(((0.36, -0.28), (0.36, 0.28), (0.8, 0.0))):
        pts = []
        steps = int((x1 - x0) / 0.12) * 8
        for i in range(steps + 1):
            t = i / 8.0
            x = x0 + t * 0.12
            a = i * math.tau / 8.0
            pts.append((x, cy + math.sin(a) * 0.34, z + dz + math.cos(a) * 0.34))
        m.wire("metal", pts, 0.012, 4, tint=(1.2, 1.2, 1.25))
    for x in [x0 + 0.5 + k * 1.5 for k in range(int((x1 - x0) / 1.5))]:
        for dz in (-0.55, 0.55):
            m.pipe("metal", (x, 0.1, z + dz), (x, 1.4, z + dz), 0.03, 5)
    for y in (0.5, 0.95, 1.35):
        m.wire("metal", [(x0, y, z - 0.55), (x1, y, z - 0.55)], 0.011, 4)


concertina(-8.8, -1.6, 8.0)
concertina(1.6, 8.8, 8.0)

# ------------------------------------------------------------------ camouflage net over stores, behind the pillbox
for px, pz in [(-3.6, -8.4), (3.6, -8.4), (-3.6, -6.6), (3.6, -6.6)]:
    m.pipe("metal", (px, 0.1, pz), (px, 2.6, pz), 0.05, 6)
m.grid("net", -4.2, 4.2, -8.8, -6.2, lambda x, z: 2.55 - 0.2 * math.sin((x + 4.2) * 0.9) * (1 - (z + 6.2) / -2.6 * 0.0) - 0.12 * (math.cos((z + 6.2) * 1.4)) + 0.05 * noise(x * 3, z * 3), 30, 10)
m.grid("net", -4.2, 4.2, -6.2, -5.8, lambda x, z: 2.3 + (z + 5.8) / -0.4 * -0.3 - 0.0, 30, 2, tint=(1.1, 1.1, 1.0))
for k in range(4):                                                                  # crates and barrels under it
    m.box("wood", (-3.0 + k * 1.5, 0.1, -8.4), (-1.9 + k * 1.5, 0.8 + (k % 2) * 0.5, -7.3), bevel=0.03, seg=1, tint=(0.9, 0.85, 0.7))
m.box("camo", (5.4, 0.1, -7.4), (7.6, 1.5, -6.2), bevel=0.05)                                 # a generator
m.box("steel_dark", (5.3, 1.5, -7.5), (7.7, 1.62, -6.1), bevel=0.02, seg=1)
m.box("glow_green", (7.6, 1.0, -6.9), (7.66, 1.2, -6.7))
# ------------------------------------------------------------------ floodlights and perimeter posts
for px, pz in [(-8.0, 5.0), (8.0, 5.0), (-8.6, -6.0), (8.6, -6.0)]:
    m.pipe("metal", (px, 0.1, pz), (px, 5.0, pz), 0.05, 6)
    m.box("steel_dark", (px - 0.45, 5.0, pz - 0.18), (px + 0.45, 5.14, pz + 0.18), bevel=0.02, seg=1)
    m.box("glow_warm", (px - 0.4, 4.97, pz - 0.15), (px + 0.4, 5.0, pz + 0.15))
for i in range(30):
    a = math.tau * i / 30.0
    fx, fz = math.cos(a) * 11.2, math.sin(a) * 11.2
    if abs(fx) < 10.1 and abs(fz) < 11.4 - abs(fx) * 0.577 and not (fz > 6.0 and abs(fx) < 1.6):
        m.pipe("metal", (fx, 0.1, fz), (fx, 1.7, fz), 0.03, 5)
        if i % 6 == 0:
            m.box("hazard", (fx - 0.3, 0.9, fz - 0.02), (fx + 0.3, 1.4, fz + 0.02))
# the flag hung from the mast, coloured in the game with the owner's colour
m.box("banner", (-1.38, 5.9, BZ - 1.93), (-1.36, 6.95, BZ - 1.93 + 1.5 * 0.8), bevel=0.0)

m.finish(out)
