"""Ground cover, modelled in Blender.   blender -b -P build_ground.py -- <out_dir>

Shrubs (ground_shrub_N: stems with ragged tufts of leaves, one with pale flowers), ferns (ground_fern_N: arching fronds with leaflets),
reeds and cattails (ground_reed_N), fallen logs (ground_log_N) and stumps (ground_stump_N) for the woods, and shore pebbles
(ground_pebbles_N) for the beaches. Metres, standing on the origin, flat bottoms sunk a little so they sit on any slope. Roles:
wood, leaf (tinted by vertex colour, dressed with shaders/tree_blender.gdshader) and rock (the stone material of env_rocks.gd).
Scattered by scripts/env_ground.gd.
"""
import math
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from mathutils import Matrix, Vector
from bl_kit import Model, P, hexc

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out_dir, exist_ok=True)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(hexc(a), hexc(b)))


def tuft(m, rng, c, r, lo, hi, n=4, flat=0.75):
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(0.0, 0.7)
        p = (c[0] + math.cos(a) * d, c[1] + rng.uniform(-0.2, 0.2) * r, c[2] + math.sin(a) * d)
        col = mix(lo, hi, rng.random())
        rr = r * rng.uniform(0.55, 0.95)
        m.geodome("leaf", p, rr, rr * flat, 2, tint=col, jitter=0.1)
        m.cyl("leaf", (p[0], p[1] - rr * 0.2, p[2]), rr * 0.9, rr * 0.25, 7, r2=rr * 0.4, tint=tuple(x * 0.5 for x in col))


def shrub(m, rng, flowers=False):
    lo, hi = ("3a5a24", "6a8a38") if not flowers else ("44682c", "74923e")
    for k in range(rng.randint(5, 8)):                                      # thin stems fanning out of the ground
        a = rng.uniform(0, math.tau)
        L = rng.uniform(0.7, 1.3)
        top = (math.cos(a) * L * 0.45, L, math.sin(a) * L * 0.45)
        m.pipe("wood", (0, -0.05, 0), top, 0.035, 5, tint=hexc("4a3c2e"), r2=0.015)
        tuft(m, rng, (top[0], top[1] + 0.1, top[2]), rng.uniform(0.35, 0.6), lo, hi, 3)
    tuft(m, rng, (0, 0.55, 0), 0.7, lo, hi, 3, 0.6)
    if flowers:
        for k in range(14):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0.2, 0.9)
            m.geodome("leaf", (math.cos(a) * d, rng.uniform(0.5, 1.3), math.sin(a) * d), 0.07, 0.07, 1, tint=hexc(rng.choice(["f4efe4", "f0d8e0", "f4e49a"])))


def fern(m, rng):
    n = rng.randint(8, 11)
    for k in range(n):
        a = math.tau * k / n + rng.uniform(-0.2, 0.2)
        L = rng.uniform(0.9, 1.4)
        col = mix("2e5a26", "5a8a38", rng.random())
        pts = [(0, 0.0, 0)]
        for s in range(1, 5):
            f = s / 4
            rr = L * f
            pts.append((math.cos(a) * rr, 0.25 + 0.55 * math.sin(f * 2.2) * L * 0.55 - 0.1 * f * f * L, math.sin(a) * rr))
        for i in range(4):
            m.pipe("leaf", pts[i], pts[i + 1], 0.02, 4, tint=col, r2=0.012)
        for i in range(1, 5):                                              # leaflets: thin flat blades either side
            f = i / 4
            w = 0.28 * (1.0 - 0.6 * f)
            px, py, pz = pts[i]
            sx, sz = -math.sin(a), math.cos(a)
            m.hull("leaf", [(px - sx * w, py, pz - sz * w), (px + sx * w, py, pz + sz * w), (px - sx * w * 0.8 + math.cos(a) * 0.12, py - 0.04, pz - sz * w * 0.8 + math.sin(a) * 0.12),
                            (px + sx * w * 0.8 + math.cos(a) * 0.12, py - 0.04, pz + sz * w * 0.8 + math.sin(a) * 0.12), (px, py + 0.02, pz)], tint=col)


def reeds(m, rng, cattails=True):
    for k in range(rng.randint(14, 20)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.7)
        x, z = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(1.4, 2.3)
        lean = (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25))
        top = (x + lean[0], h, z + lean[1])
        col = mix("5a7a30", "9aa456", rng.random())
        m.pipe("leaf", (x, -0.1, z), top, 0.028, 4, tint=col, r2=0.01)
        if cattails and k % 4 == 0:
            m.pipe("wood", (top[0] - lean[0] * 0.12, h * 0.72, top[2] - lean[1] * 0.12), (top[0], h * 0.86, top[2]), 0.05, 6, tint=hexc("4a3322"), r2=0.045)
    for k in range(6):                                                      # long blades arching out
        a = rng.uniform(0, math.tau)
        L = rng.uniform(0.9, 1.5)
        x, z = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        m.pipe("leaf", (x, 0.0, z), (x + math.cos(a) * L * 0.5, L * 0.9, z + math.sin(a) * L * 0.5), 0.03, 4, tint=mix("5a7a30", "8a9a48", rng.random()), r2=0.008)


def log(m, rng):
    L = rng.uniform(3.2, 5.0)
    r = rng.uniform(0.22, 0.34)
    tilt = rng.uniform(-0.05, 0.08)
    bark = hexc(rng.choice(["5a4838", "645040", "4e4136"]))
    a, b = (-L / 2, r * 0.8, 0), (L / 2, r * 0.8 + tilt * L, 0)
    m.pipe("wood", a, b, r, 9, tint=bark, r2=r * 0.78)
    for k in range(rng.randint(2, 4)):                                      # broken branch stubs
        x = rng.uniform(-L * 0.4, L * 0.4)
        an = rng.uniform(0.3, 2.8)
        m.pipe("wood", (x, r * 1.0, 0), (x + rng.uniform(-0.2, 0.2), r * 1.0 + math.sin(an) * 0.5, math.cos(an) * 0.5), 0.05, 5, tint=bark, r2=0.03)
    for k in range(3):                                                      # moss along the top
        x = rng.uniform(-L * 0.4, L * 0.4)
        m.geodome("leaf", (x, r * 1.55, rng.uniform(-0.05, 0.05)), rng.uniform(0.35, 0.6), 0.14, 1, tint=mix("3a5a24", "5a7a30", rng.random()), jitter=0.08)


def stump(m, rng):
    h = rng.uniform(0.45, 0.85)
    r = rng.uniform(0.3, 0.45)
    bark = hexc("5a4838")
    m.cyl("wood", (0, -0.1, 0), r, h + 0.1, 9, r2=r * 0.9, tint=bark)
    m.cyl("wood", (0, h - 0.02, 0), r * 0.88, 0.04, 9, tint=hexc("c8a878"))   # the cut face
    for k in range(5):
        a = math.tau * k / 5 + rng.uniform(-0.3, 0.3)
        m.pipe("wood", (math.cos(a) * r * 0.8, h * 0.4, math.sin(a) * r * 0.8), (math.cos(a) * r * 1.9, -0.05, math.sin(a) * r * 1.9), 0.09, 5, tint=bark, r2=0.03)


def pebbles(m, rng):
    for k in range(rng.randint(7, 11)):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        s = rng.uniform(0.1, 0.38)
        push = {}
        for v in bm.verts:
            kk = (round(v.co.x * 50), round(v.co.y * 50), round(v.co.z * 50))
            push.setdefault(kk, rng.uniform(0.8, 1.15))
            f = push[kk]
            v.co = Vector((v.co.x * s * f, v.co.y * s * f * 1.2, max(v.co.z * s * 0.55 * f, -0.04)))
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 1.6)
        col = mix("b8b0a4", "8a847a", rng.random())
        m.add("rock", bm, Matrix.Translation(P(math.cos(a) * d, 0.0, math.sin(a) * d)) @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"), col)
        bm.free()


MAKERS = [("ground_shrub", lambda m, r: shrub(m, r, False), 3), ("ground_shrub_flower", lambda m, r: shrub(m, r, True), 1), ("ground_fern", fern, 2),
          ("ground_reed", reeds, 2), ("ground_log", log, 3), ("ground_stump", stump, 2), ("ground_pebbles", pebbles, 3)]
for prefix, fn, count in MAKERS:
    for v in range(1, count + 1):
        name = "%s_%d" % (prefix, v)
        m = Model(name)
        rng = random.Random(sum(map(ord, prefix)) * 13 + v)
        fn(m, rng)
        m.finish(os.path.join(out_dir, name + ".glb"), smooth_angle=30.0)
