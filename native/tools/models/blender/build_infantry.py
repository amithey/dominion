"""The foot soldiers and the workers, modelled and animated in Blender.   blender -b -P build_infantry.py -- <out_dir> [kind ...]

One humanoid rig (bl_rig.py), ten people built on it: rifleman, sniper, commando, rocket (RPG), atgm, manpads, medic, worker, fpv (drone
operator) and scout. Each is one skinned mesh in a few roles (uniform, pants, gear, boot, glove, skin, metal, wood, banner = the nation's
colour on the shoulder patches, hivis, red, glass...) that the game dresses per nation, and five baked clips: idle_gun, run_gun, idle_shoot,
death and interact. Metres, facing +z, standing on y 0, 1.85 m tall; the game scales them to its own readable size.

The soldiers hold their weapon in both hands in every clip: the hands are solved onto the grips of the weapon bone, which swings between
the low ready (moving, idle) and the shoulder (firing).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion
from bl_kit import P, hexc
from bl_rig import Rig, BONES, ORDER, gdir

out_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
kinds_wanted = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
os.makedirs(out_dir, exist_ok=True)
W = BONES["weapon"][1]                        # the weapon bone's head: where the stock meets the shoulder
FPS = 30


def rx(deg):
    """A rotation about the left-right axis: positive tips the top (and a muzzle) forward/down, the front of the body toward the ground."""
    return Quaternion((1, 0, 0), math.radians(deg))


def rz(deg):
    return Quaternion((0, 0, 1), math.radians(deg))


def ry(deg):
    return Quaternion((0, 1, 0), math.radians(deg))


def sphere(m, role, c, r, tint=(1, 1, 1), sy=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        v.co.z *= sy
    m.add(role, bm, Matrix.Translation(P(*c)), tint)
    bm.free()


def limb(m, role, a, b, r0, r1=None, tint=(1, 1, 1)):
    m.pipe(role, a, b, r0, 8, tint=tint, r2=r1 if r1 is not None else r0 * 0.88)


# ------------------------------------------------------------------ the body
SKIN = (1.0, 1.0, 1.0)


def ellipsoid(m, role, c, rx_, ry_, rz_, tint=(1, 1, 1), seg=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=seg, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * rx_, v.co.y * rz_, v.co.z * ry_))      # game x, z(front) = blender -y, y = blender z
    m.add(role, bm, Matrix.Translation(P(*c)), tint)
    bm.free()


def body(m, kind):
    k = KIND[kind]
    uni = k.get("uniform", "uniform")
    pants = k.get("pants", "pants")
    m.bone = "hips"
    m.hull(pants, [(-0.165, 0.9, -0.105), (0.165, 0.9, -0.105), (-0.165, 0.9, 0.105), (0.165, 0.9, 0.105),
                   (-0.17, 1.08, -0.11), (0.17, 1.08, -0.11), (-0.17, 1.08, 0.11), (0.17, 1.08, 0.11)])
    m.box("gear", (-0.18, 1.0, -0.12), (0.18, 1.06, 0.12), bevel=0.012, seg=1)                          # the belt
    m.box("metal", (-0.025, 1.005, 0.118), (0.025, 1.055, 0.128))                                       # the buckle
    m.bone = "spine"
    m.hull(uni, [(-0.165, 1.05, -0.105), (0.165, 1.05, -0.105), (-0.165, 1.05, 0.105), (0.165, 1.05, 0.105),
                 (-0.185, 1.33, -0.115), (0.185, 1.33, -0.115), (-0.185, 1.33, 0.115), (0.185, 1.33, 0.115)])
    m.bone = "chest"
    m.hull(uni, [(-0.185, 1.3, -0.115), (0.185, 1.3, -0.115), (-0.185, 1.3, 0.115), (0.185, 1.3, 0.115),
                 (-0.225, 1.5, -0.12), (0.225, 1.5, -0.12), (-0.225, 1.5, 0.12), (0.225, 1.5, 0.12),
                 (-0.15, 1.555, -0.09), (0.15, 1.555, -0.09), (-0.15, 1.555, 0.1), (0.15, 1.555, 0.1)])
    if k.get("vest", True):
        m.hull(k.get("vest_role", "gear"), [(-0.2, 1.31, 0.1), (0.2, 1.31, 0.1), (-0.2, 1.31, 0.165), (0.2, 1.31, 0.165),
                                            (-0.23, 1.5, 0.11), (0.23, 1.5, 0.11), (-0.22, 1.5, 0.165), (0.22, 1.5, 0.165)])   # plate carrier
        for sx in (-0.12, 0.0, 0.12):
            m.box("gear", (sx - 0.045, 1.33, 0.16), (sx + 0.045, 1.45, 0.205), bevel=0.012, seg=1, tint=(0.8, 0.8, 0.8))   # magazine pouches
        m.hull("gear", [(-0.2, 1.31, -0.165), (0.2, 1.31, -0.165), (-0.2, 1.31, -0.1), (0.2, 1.31, -0.1),
                        (-0.22, 1.5, -0.165), (0.22, 1.5, -0.165), (-0.22, 1.5, -0.1), (0.22, 1.5, -0.1)])                     # back plate
    if k.get("pack", True):
        m.box(k.get("pack_role", "gear"), (-0.17, 1.28, -0.35), (0.17, 1.6, -0.16), bevel=0.05, seg=2, tint=(0.9, 0.9, 0.9))
        m.box("gear", (-0.14, 1.52, -0.37), (0.14, 1.63, -0.21), bevel=0.04, seg=2)                      # a rolled mat on top
    m.bone = "neck"
    m.cyl("skin", (0, 1.52, 0), 0.05, 0.14, 10, r2=0.044, tint=SKIN)
    m.box(uni, (-0.07, 1.5, -0.06), (0.07, 1.56, 0.07), bevel=0.02, seg=1)                               # the collar
    m.bone = "head"
    ellipsoid(m, "skin", (0, 1.745, 0.0), 0.083, 0.11, 0.095, SKIN)                                      # the skull
    ellipsoid(m, "skin", (0, 1.69, 0.03), 0.07, 0.06, 0.07, SKIN)                                        # the jaw and chin
    ellipsoid(m, "hair", (0, 1.775, -0.015), 0.087, 0.09, 0.09, tint=(1, 1, 1))                           # hair, under whatever the head wears
    ellipsoid(m, "skin", (-0.085, 1.735, 0.0), 0.018, 0.034, 0.022, SKIN, 1)                              # ears
    ellipsoid(m, "skin", (0.085, 1.735, 0.0), 0.018, 0.034, 0.022, SKIN, 1)
    m.hull("skin", [(-0.011, 1.735, 0.09), (0.011, 1.735, 0.09), (-0.016, 1.7, 0.09), (0.016, 1.7, 0.09), (0.0, 1.705, 0.122)], tint=(1.0, 0.9, 0.85))   # the nose
    for sx in (-1, 1):
        m.box("paint", (sx * 0.04 - 0.017, 1.737, 0.088), (sx * 0.04 + 0.017, 1.755, 0.097))             # the whites of the eyes
        m.box("dark", (sx * 0.04 - 0.007, 1.739, 0.094), (sx * 0.04 + 0.007, 1.753, 0.1))                # the pupils
        m.box("hair", (sx * 0.04 - 0.024, 1.763, 0.088), (sx * 0.04 + 0.024, 1.772, 0.1), tint=(1, 1, 1)) # the brows
    m.box("skin", (-0.024, 1.68, 0.1), (0.024, 1.69, 0.106), tint=(0.62, 0.34, 0.32))                    # the mouth
    for side, sx in (("R", -1), ("L", 1)):
        m.bone = "upperarm_" + side
        ellipsoid(m, uni, (sx * 0.215, 1.46, 0), 0.075, 0.07, 0.07)                                      # the shoulder
        limb(m, uni, (sx * 0.215, 1.455, 0), (sx * 0.235, 1.18, 0), 0.056, 0.044)
        m.box("banner", (sx * 0.27 - 0.012, 1.34, -0.045), (sx * 0.27 + 0.012, 1.44, 0.045))              # the nation's patch on the sleeve
        m.bone = "forearm_" + side
        sphere(m, uni, (sx * 0.235, 1.18, 0), 0.046)
        limb(m, uni, (sx * 0.235, 1.18, 0), (sx * 0.235, 0.93, 0), 0.045, 0.034)
        m.bone = "hand_" + side
        gl = k.get("glove", "glove")
        m.box(gl, (sx * 0.235 - 0.035, 0.87, -0.03), (sx * 0.235 + 0.035, 0.94, 0.035), bevel=0.012, seg=1)   # the palm
        m.box(gl, (sx * 0.235 - 0.034, 0.8, -0.028), (sx * 0.235 + 0.03, 0.87, 0.05), bevel=0.01, seg=1)       # the fingers, curled forward
        m.box(gl, (sx * 0.235 - sx * 0.035 - 0.012, 0.85, 0.0), (sx * 0.235 - sx * 0.035 + 0.012, 0.9, 0.05), bevel=0.006, seg=1)   # the thumb
        m.bone = "thigh_" + side
        ellipsoid(m, pants, (sx * 0.1, 0.95, 0), 0.085, 0.075, 0.085)
        limb(m, pants, (sx * 0.1, 0.95, 0), (sx * 0.1, 0.53, 0), 0.08, 0.056)
        if side == "R":
            m.box("gear", (sx * 0.1 - 0.075, 0.66, 0.0), (sx * 0.1 + 0.075, 0.82, 0.08), bevel=0.02, seg=1, tint=(0.9, 0.9, 0.9))   # a leg pouch
        m.bone = "shin_" + side
        sphere(m, pants, (sx * 0.1, 0.53, 0), 0.06)
        limb(m, pants, (sx * 0.1, 0.53, 0), (sx * 0.1, 0.1, 0), 0.058, 0.044)
        ellipsoid(m, pants, (sx * 0.1, 0.4, -0.03), 0.052, 0.09, 0.05)                                   # the calf
        m.box("gear", (sx * 0.1 - 0.06, 0.5, -0.06), (sx * 0.1 + 0.06, 0.6, 0.07), bevel=0.02, seg=1)    # knee pad
        m.bone = "foot_" + side
        m.hull("boot", [(sx * 0.1 - 0.045, 0.0, -0.06), (sx * 0.1 + 0.045, 0.0, -0.06), (sx * 0.1 - 0.05, 0.0, 0.2), (sx * 0.1 + 0.05, 0.0, 0.2),
                        (sx * 0.1 - 0.045, 0.13, -0.06), (sx * 0.1 + 0.045, 0.13, -0.06), (sx * 0.1 - 0.042, 0.08, 0.14), (sx * 0.1 + 0.042, 0.08, 0.14)])
        m.box("dark", (sx * 0.1 - 0.052, 0.0, -0.065), (sx * 0.1 + 0.052, 0.028, 0.205))                 # the sole


def helmet(m, role="uniform", cover=False):
    m.bone = "head"
    ellipsoid(m, role, (0, 1.79, -0.005), 0.108, 0.085, 0.12, tint=(1, 1, 1))
    m.cyl(role, (0, 1.75, -0.005), 0.115, 0.032, 14, r2=0.112)
    m.box("gear", (-0.03, 1.845, 0.09), (0.03, 1.87, 0.125), bevel=0.006, seg=1)                          # night-vision mount
    for sx in (-1, 1):
        m.pipe("gear", (sx * 0.1, 1.76, 0.03), (sx * 0.04, 1.66, 0.075), 0.006, 4)                      # chin strap


def headgear(m, kind):
    k = KIND[kind]
    h = k.get("head", "helmet")
    m.bone = "head"
    if h == "helmet":
        helmet(m)
    elif h == "hardhat":
        ellipsoid(m, "hivis_yellow", (0, 1.79, 0.0), 0.11, 0.085, 0.12)
        m.cyl("hivis_yellow", (0, 1.76, 0.0), 0.125, 0.025, 14)
        m.box("hivis_yellow", (-0.09, 1.76, 0.1), (0.09, 1.78, 0.2), bevel=0.01, seg=1)                  # the peak
        m.box("hivis_yellow", (-0.012, 1.84, -0.1), (0.012, 1.88, 0.1))                                  # the ridge
    elif h == "boonie":
        ellipsoid(m, "camo", (0, 1.815, 0.0), 0.1, 0.07, 0.11)
        m.cyl("camo", (0, 1.775, 0.0), 0.19, 0.02, 16)
        for sx in (-1, 1):
            m.pipe("camo", (sx * 0.1, 1.82, 0.03), (sx * 0.14, 1.73, 0.04), 0.012, 4)
        m.box("dark", (-0.1, 1.795, -0.01), (0.1, 1.81, 0.09), tint=(0.8, 0.8, 0.8))
    elif h == "balaclava":
        ellipsoid(m, "dark", (0, 1.77, 0.0), 0.09, 0.1, 0.098)
        ellipsoid(m, "dark", (0, 1.69, 0.03), 0.075, 0.063, 0.08)                                        # the lower face covered
        m.box("glass", (-0.065, 1.738, 0.092), (0.065, 1.768, 0.112), bevel=0.006, seg=1, tint=(0.5, 1.2, 0.6))   # night-vision goggles
        helmet(m, "dark")
    elif h == "cap":
        ellipsoid(m, "uniform", (0, 1.8, -0.005), 0.095, 0.065, 0.11)
        m.box("uniform", (-0.08, 1.77, 0.08), (0.08, 1.785, 0.19), bevel=0.008, seg=1)
    elif h == "medic":
        helmet(m)
        m.box("paint", (-0.05, 1.8, 0.118), (0.05, 1.86, 0.13))
        m.box("red", (-0.012, 1.805, 0.13), (0.012, 1.855, 0.135))
        m.box("red", (-0.04, 1.822, 0.13), (0.04, 1.838, 0.135))
    elif h == "goggles":
        helmet(m)
        m.box("glass", (-0.068, 1.738, 0.092), (0.068, 1.768, 0.112), bevel=0.006, seg=1, tint=(0.6, 0.9, 1.4))


def rifle(m, kind="rifle"):
    """The weapon bone's geometry, built round W (the stock at the shoulder, the muzzle at +z)."""
    m.bone = "weapon"
    x, y, z = W
    L = {"rifle": 0.95, "smg": 0.62, "sniper": 1.22}[kind]
    m.box("metal", (x - 0.025, y - 0.05, z + 0.02), (x + 0.025, y + 0.035, z + 0.38), bevel=0.008, seg=1)           # receiver
    m.box("wood" if kind != "smg" else "gear", (x - 0.03, y - 0.075, z + 0.38), (x + 0.03, y + 0.015, z + 0.62), bevel=0.01, seg=1)   # handguard
    m.pipe("metal", (x, y - 0.01, z + 0.5), (x, y - 0.01, z + L), 0.014, 6)
    m.box("wood" if kind != "smg" else "gear", (x - 0.025, y - 0.08, z - 0.28), (x + 0.025, y + 0.03, z + 0.03), bevel=0.012, seg=1)   # stock
    m.box("gear", (x - 0.022, y - 0.19, z + 0.14), (x + 0.022, y - 0.045, z + 0.23), bevel=0.01, seg=1)             # magazine
    m.box("gear", (x - 0.02, y - 0.12, z + 0.05), (x + 0.02, y - 0.05, z + 0.09))                                    # grip
    m.box("metal", (x - 0.012, y + 0.035, z + 0.12), (x + 0.012, y + 0.07, z + 0.15))                                # rear sight
    if kind == "sniper":
        m.pipe("metal", (x, y + 0.075, z + 0.1), (x, y + 0.075, z + 0.42), 0.026, 8)
        m.pipe("glass", (x, y + 0.075, z + 0.42), (x, y + 0.075, z + 0.43), 0.03, 8)
        m.pipe("metal", (x - 0.04, y - 0.06, z + 0.6), (x - 0.06, y - 0.2, z + 0.64), 0.008, 4)         # a bipod folded
        m.pipe("metal", (x + 0.04, y - 0.06, z + 0.6), (x + 0.06, y - 0.2, z + 0.64), 0.008, 4)
    if kind == "smg":
        m.pipe("metal", (x, y - 0.01, z + L), (x, y - 0.01, z + L + 0.12), 0.022, 6)                    # a suppressor


def team_weapon(m, kind):
    """The crew-served weapons a man carries: a light machine gun, a mortar tube (its baseplate on his back), a recoilless rifle."""
    m.bone = "weapon"
    x, y, z = W
    if kind == "mg":
        m.box("metal", (x - 0.03, y - 0.06, z + 0.0), (x + 0.03, y + 0.045, z + 0.45), bevel=0.01, seg=1)                 # the receiver
        m.pipe("metal", (x, y + 0.0, z + 0.45), (x, y + 0.0, z + 1.05), 0.022, 8)                                           # the heavy barrel
        m.pipe("metal", (x, y + 0.0, z + 0.62), (x, y + 0.0, z + 0.95), 0.036, 8, tint=(0.7, 0.7, 0.7))                  # its perforated jacket
        m.box("wood", (x - 0.028, y - 0.09, z - 0.3), (x + 0.028, y + 0.035, z + 0.02), bevel=0.012, seg=1)               # the stock
        m.box("gear", (x - 0.06, y - 0.2, z + 0.12), (x + 0.06, y - 0.06, z + 0.3), bevel=0.012, seg=1)                  # the ammunition box
        m.pipe("metal", (x - 0.03, y - 0.13, z + 0.3), (x - 0.12, y + 0.05, z - 0.02), 0.012, 4, tint=(1.3, 1.1, 0.7))     # the belt of rounds draped over
        m.box("metal", (x - 0.015, y + 0.045, z + 0.1), (x + 0.015, y + 0.1, z + 0.3))                                     # the carrying handle
        m.box("gear", (x - 0.02, y - 0.14, z + 0.05), (x + 0.02, y - 0.06, z + 0.1))                                        # the grip
        m.pipe("metal", (x - 0.04, y - 0.04, z + 0.8), (x - 0.1, y - 0.24, z + 0.9), 0.009, 4)                            # the bipod, folded forward
        m.pipe("metal", (x + 0.04, y - 0.04, z + 0.8), (x + 0.1, y - 0.24, z + 0.9), 0.009, 4)
    elif kind == "mortar":
        m.pipe("metal", (x, y + 0.03, z - 0.05), (x, y + 0.03, z + 0.95), 0.052, 12)                                        # the tube
        m.pipe("metal", (x, y + 0.03, z + 0.9), (x, y + 0.03, z + 0.97), 0.06, 12, tint=(0.6, 0.6, 0.6))
        m.box("gear", (x - 0.03, y - 0.03, z - 0.09), (x + 0.03, y + 0.09, z - 0.04))                                       # the breech cap
        m.pipe("metal", (x - 0.03, y - 0.02, z + 0.55), (x - 0.12, y - 0.3, z + 0.6), 0.01, 4)                            # the bipod legs
        m.pipe("metal", (x + 0.03, y - 0.02, z + 0.55), (x + 0.12, y - 0.3, z + 0.6), 0.01, 4)
        m.box("gear", (x - 0.03, y + 0.08, z + 0.4), (x + 0.03, y + 0.14, z + 0.5))                                         # the sight
    else:                                                                                                                    # rcl
        m.pipe("metal", (x, y + 0.03, z - 0.12), (x, y + 0.03, z + 1.1), 0.058, 12)
        m.pipe("metal", (x, y + 0.03, z - 0.12), (x, y + 0.03, z - 0.3), 0.058, 12, r2=0.1)                                 # the venturi at the breech
        m.pipe("gear", (x, y + 0.03, z + 1.05), (x, y + 0.03, z + 1.14), 0.065, 12)
        m.box("gear", (x - 0.03, y - 0.1, z + 0.18), (x + 0.03, y + 0.0, z + 0.26), bevel=0.01, seg=1)                     # the firing grip
        m.box("gear", (x - 0.025, y - 0.1, z + 0.5), (x + 0.025, y + 0.0, z + 0.56))
        m.box("glass", (x - 0.03, y + 0.1, z + 0.45), (x + 0.03, y + 0.15, z + 0.5))                                        # the optical sight
        m.box("gear", (x - 0.03, y + 0.085, z + 0.38), (x + 0.03, y + 0.1, z + 0.52))
        m.box("gear", (x - 0.06, y - 0.07, z - 0.12), (x + 0.06, y - 0.03, z + 0.05), bevel=0.01, seg=1)                  # the shoulder pad


def launcher(m, kind):
    m.bone = "weapon"
    x, y, z = W
    if kind == "rocket":
        m.pipe("metal", (x, y + 0.02, z - 0.2), (x, y + 0.02, z + 0.75), 0.04, 8)
        m.pipe("metal", (x, y + 0.02, z + 0.75), (x, y + 0.02, z + 0.9), 0.06, 8, r2=0.075)
        m.box("wood", (x - 0.03, y - 0.05, z + 0.12), (x + 0.03, y + 0.07, z + 0.34), bevel=0.01, seg=1)
        m.box("gear", (x - 0.02, y - 0.14, z + 0.28), (x + 0.02, y - 0.04, z + 0.33))
        warhead = hexc("7a7a50")
        m.pipe("metal", (x, y + 0.02, z + 0.9), (x, y + 0.02, z + 1.02), 0.075, 8, tint=warhead, r2=0.02)
    elif kind == "atgm":
        m.pipe("metal", (x, y + 0.03, z - 0.25), (x, y + 0.03, z + 0.95), 0.06, 10)
        m.box("gear", (x - 0.06, y - 0.06, z + 0.05), (x + 0.06, y + 0.1, z + 0.28), bevel=0.02, seg=1)   # the sight and battery
        m.box("glass", (x - 0.04, y + 0.03, z + 0.28), (x + 0.04, y + 0.09, z + 0.3))
        m.box("gear", (x - 0.025, y - 0.16, z + 0.3), (x + 0.025, y - 0.05, z + 0.36))
        m.pipe("gear", (x, y + 0.03, z + 0.95), (x, y + 0.03, z + 1.05), 0.06, 10)
    else:                                                                                          # manpads
        m.pipe("metal", (x, y + 0.03, z - 0.3), (x, y + 0.03, z + 1.1), 0.045, 10)
        m.pipe("metal", (x, y + 0.03, z + 1.1), (x, y + 0.03, z + 1.18), 0.055, 10, tint=hexc("7a7a50"))
        m.box("gear", (x - 0.04, y - 0.08, z + 0.1), (x + 0.04, y + 0.1, z + 0.3), bevel=0.015, seg=1)   # the gripstock and battery
        m.box("gear", (x - 0.02, y - 0.17, z + 0.18), (x + 0.02, y - 0.06, z + 0.25))
        m.box("metal", (x - 0.03, y + 0.05, z + 0.55), (x + 0.03, y + 0.13, z + 0.6))                 # the folded sight


def extras(m, kind):
    if kind == "worker":
        m.bone = "chest"
        m.box("hivis_orange", (-0.225, 1.3, -0.14), (0.225, 1.56, 0.14), bevel=0.03, seg=1)             # the hi-vis vest
        m.box("reflect", (-0.226, 1.37, -0.141), (0.226, 1.4, 0.141))
        m.box("reflect", (-0.226, 1.46, -0.141), (0.226, 1.49, 0.141))
        m.bone = "hand_R"                                                                              # a hammer
        m.pipe("wood", (-0.23, 0.9, 0.0), (-0.23, 0.9, 0.34), 0.017, 6)
        m.box("metal", (-0.27, 0.87, 0.3), (-0.19, 0.95, 0.38), bevel=0.01, seg=1)
        m.bone = "thigh_L"
        m.box("gear", (0.14, 0.7, -0.05), (0.2, 0.85, 0.07), bevel=0.01, seg=1)                          # a tool pouch
    elif kind == "medic":
        m.bone = "chest"
        m.box("paint", (-0.24, 1.32, -0.34), (-0.05, 1.56, -0.15), bevel=0.03, seg=1, tint=hexc("e8e8e0"))   # the medical pack
        m.box("red", (-0.17, 1.4, -0.345), (-0.13, 1.5, -0.34))
        m.box("red", (-0.2, 1.43, -0.345), (-0.1, 1.47, -0.34))
        m.bone = "upperarm_L"
        m.box("paint", (0.255, 1.33, -0.05), (0.285, 1.45, 0.05), tint=hexc("f4f0e4"))                  # the armband
        m.box("red", (0.285, 1.375, -0.012), (0.295, 1.41, 0.012))
        m.bone = "thigh_L"
        m.box("gear", (0.14, 0.62, -0.1), (0.21, 0.86, 0.1), bevel=0.02, seg=1)                          # a trauma pouch
    elif kind == "fpv":
        m.bone = "chest"
        m.box("gear", (-0.12, 1.38, 0.17), (0.12, 1.46, 0.3), bevel=0.01, seg=1)                          # the controller
        m.pipe("metal", (-0.1, 1.46, 0.28), (-0.12, 1.62, 0.3), 0.007, 4)
        m.pipe("metal", (0.1, 1.46, 0.28), (0.12, 1.62, 0.3), 0.007, 4)
        m.box("glow_cyan", (-0.05, 1.455, 0.2), (0.05, 1.462, 0.26))
        m.bone = "chest"
        m.box("gear", (-0.2, 1.3, -0.5), (0.2, 1.5, -0.35), bevel=0.02, seg=1)                            # the drone case
        m.pipe("metal", (0.0, 1.5, -0.45), (0.0, 1.75, -0.45), 0.008, 4)
    elif kind == "scout":
        m.bone = "weapon"
        x, y, z = W
        m.box("dark", (x - 0.07, y - 0.03, z + 0.03), (x + 0.07, y + 0.03, z + 0.14), bevel=0.01, seg=1)   # binoculars
        m.pipe("metal", (x - 0.04, y, z + 0.14), (x - 0.04, y, z + 0.2), 0.026, 8)
        m.pipe("metal", (x + 0.04, y, z + 0.14), (x + 0.04, y, z + 0.2), 0.026, 8)
        m.bone = "chest"
        m.pipe("metal", (0.17, 1.45, -0.34), (0.17, 1.95, -0.34), 0.008, 4)                              # a whip antenna
        m.box("gear", (0.1, 1.3, -0.4), (0.24, 1.46, -0.3))
    elif kind == "mortar":
        m.bone = "chest"
        m.box("metal", (-0.2, 1.3, -0.4), (0.2, 1.62, -0.37), bevel=0.01, seg=1, tint=(0.8, 0.8, 0.85))                  # the baseplate strapped to the pack
        m.box("gear", (-0.16, 1.3, -0.37), (0.16, 1.62, -0.35))
        m.pipe("metal", (-0.12, 1.62, -0.38), (-0.12, 1.95, -0.34), 0.012, 4)                                                # the bipod, strapped on top
        m.pipe("metal", (0.12, 1.62, -0.38), (0.12, 1.95, -0.34), 0.012, 4)
    elif kind == "mg":
        m.bone = "chest"
        for k in range(3):
            m.box("gear", (-0.2 + k * 0.14, 1.3, 0.165), (-0.12 + k * 0.14, 1.46, 0.2), bevel=0.01, seg=1, tint=(1.0, 0.8, 0.5))   # spare ammunition cans
    elif kind == "sniper":
        m.bone = "chest"
        m.box("camo", (-0.215, 1.3, -0.14), (0.215, 1.55, 0.14), bevel=0.03, seg=1)                      # a camouflage smock
        for k in range(9):
            sphere(m, "camo", (-0.16 + (k % 3) * 0.16, 1.34 + (k // 3) * 0.09, 0.14), 0.045)             # ghillie tufts


# ------------------------------------------------------------------ the kinds
# weapon: rifle | smg | sniper | rocket | atgm | manpads | none; hold: how the hands take it
KIND = {
    "rifleman": {"weapon": "rifle", "head": "helmet"},
    "sniper": {"weapon": "sniper", "head": "boonie", "uniform": "camo", "pants": "camo", "pack": True},
    "commando": {"weapon": "smg", "head": "balaclava", "uniform": "dark_uniform", "pants": "dark_uniform", "vest_role": "gear"},
    "rocket": {"weapon": "rocket", "head": "helmet"},
    "atgm": {"weapon": "atgm", "head": "helmet"},
    "manpads": {"weapon": "manpads", "head": "helmet"},
    "medic": {"weapon": "none", "head": "medic"},
    "worker": {"weapon": "none", "head": "hardhat", "vest": False, "pack": False, "uniform": "work_uniform", "pants": "work_uniform"},
    "fpv": {"weapon": "none", "head": "goggles", "vest": True},
    "scout": {"weapon": "scout", "head": "cap", "pack": True},
    "mg": {"weapon": "mg", "head": "helmet"},
    "mortar": {"weapon": "mortar", "head": "helmet", "pack": True},
    "rcl": {"weapon": "rcl", "head": "helmet"},
}
GRIPS = {   # weapon-bone-local grip points: (right hand, left hand)
    "rifle": ((0, -0.1, 0.07), (0, -0.045, 0.44)),
    "smg": ((0, -0.1, 0.07), (0, -0.045, 0.38)),
    "sniper": ((0, -0.1, 0.07), (0, -0.07, 0.46)),
    "rocket": ((0, -0.1, 0.22), (0, 0.0, 0.5)),
    "atgm": ((0, -0.12, 0.3), (0, 0.04, 0.62)),
    "manpads": ((0, -0.1, 0.2), (0, 0.0, 0.5)),
    "scout": ((-0.04, 0.0, 0.17), (0.04, 0.0, 0.17)),
    "mg": ((0, -0.12, 0.07), (0, -0.05, 0.45)),
    "mortar": ((0, -0.04, 0.2), (0, -0.04, 0.62)),
    "rcl": ((0, -0.12, 0.22), (0, -0.05, 0.53)),
}
LOW_PITCH = {"rifle": 30.0, "smg": 32.0, "sniper": 28.0, "rocket": -22.0, "atgm": -18.0, "manpads": -22.0, "mg": 26.0, "mortar": -38.0, "rcl": -20.0}
AIM_PITCH = {"mortar": -62.0}          # while firing: the mortar man holds his tube up at an angle instead of shouldering it


# ------------------------------------------------------------------ the poses
def legs(D, phase, amp=38.0, knee=48.0, walk=True):
    for side, off in (("L", 0.0), ("R", math.pi)):
        s = math.sin(phase + off)
        c = math.cos(phase + off)
        theta = amp * s                                    # positive: the foot swings forward
        flex = 10.0 + knee * max(0.0, c) ** 1.4
        D["thigh_" + side] = rx(-theta)
        D["shin_" + side] = rx(-theta + flex)
        D["foot_" + side] = rx(0.25 * (-theta + flex) - 6.0 * c * 0)
    return D


def hold_pose(rig, kind, D, off, pitch, woff=(0, 0, 0), ys=0.0):
    """The weapon at `pitch` degrees (positive: the muzzle down) and offset, both hands on its grips."""
    w = KIND[kind]["weapon"]
    D["weapon"] = rx(pitch)
    heads = rig.fk(D, off)
    heads["weapon"] = heads["weapon"] + Vector(P(*woff))
    gr, gl = GRIPS[w]
    targets = {}
    for side, g in (("R", gr), ("L", gl)):
        p = (W[0] + g[0], W[1] + g[1], W[2] + g[2])
        q = D["weapon"].to_matrix() @ (Vector(P(*p)) - rig.restpos["weapon"])
        tp = heads["weapon"] + q
        targets[side] = (tp.x, tp.z, -tp.y)
    for side in ("R", "L"):
        D.update(rig.solve_arm(side, targets[side], shoulder=heads["upperarm_" + side]))
        D["hand_" + side] = D["forearm_" + side]
    return D


def free_arms(rig, D, off, swing, lift=0.0, lean=0.0):
    """Arms hanging and swinging (no weapon): the wrists reach points beside the hips, swung forward and back."""
    heads = rig.fk(D, off)
    for side, sx, s in (("R", -1, swing), ("L", 1, -swing)):
        T = rig.attach(heads, D, "chest", (sx * 0.27, 1.05 + lift * max(0.0, s), 0.28 * s + 0.02))
        D.update(rig.solve_arm(side, T, shoulder=heads["upperarm_" + side], pole_out=0.3))
        D["hand_" + side] = D["forearm_" + side]
    return D


def woff_for(kind, aim):
    return (0, 0, 0)


def clip_idle(rig, kind, frames=48):
    w = KIND[kind]["weapon"]
    for f in range(frames + 1):
        t = f / frames * math.tau
        D = {"hips": rx(0.4 * math.sin(t)), "spine": rx(0.6 * math.sin(t)), "chest": rx(0.8 * math.sin(t)), "head": rx(-0.6 * math.sin(t))}
        D["thigh_L"] = D["thigh_R"] = Quaternion()
        D["thigh_L"] = rz(-3.0)
        D["thigh_R"] = rz(3.0)
        off = (0, 0.004 * math.sin(t), 0)
        if w in LOW_PITCH or w == "scout":
            pitch = LOW_PITCH.get(w, -70.0) + 0.8 * math.sin(t)
            if w == "scout":
                hold_pose(rig, kind, D, off, 0.0, (0, 0.0, 0.0))
            else:
                hold_pose(rig, kind, D, off, pitch)
        else:
            free_arms(rig, D, off, 0.0)
            if kind == "fpv":
                heads = rig.fk(D, off)
                for side, sx in (("R", -1), ("L", 1)):
                    T = rig.attach(heads, D, "chest", (sx * 0.1, 1.4, 0.28))
                    D.update(rig.solve_arm(side, T, shoulder=heads["upperarm_" + side]))
                    D["hand_" + side] = D["forearm_" + side]
        rig.key_pose("idle_gun", f, D, off)


def clip_run(rig, kind, frames=24):
    w = KIND[kind]["weapon"]
    for f in range(frames + 1):
        phase = f / frames * math.tau
        D = {"hips": rx(8.0 + 1.5 * math.cos(2 * phase)), "spine": rx(3.0), "chest": rx(2.0 * math.sin(phase)), "head": rx(-6.0)}
        legs(D, phase)
        off = (0, -0.02 - 0.045 * abs(math.sin(phase)) * 1.0 + 0.0, 0.0)
        off = (0.012 * math.sin(phase), -0.01 - 0.05 * (1 - abs(math.cos(phase))) * 0.0 + 0.04 * math.cos(2 * phase), 0.0)
        if w in LOW_PITCH:
            hold_pose(rig, kind, D, off, LOW_PITCH[w] + 3.0 * math.sin(2 * phase))
        elif w == "scout":
            hold_pose(rig, kind, D, off, 55.0)
        elif kind == "fpv":
            free_arms(rig, D, off, 0.0)
            heads = rig.fk(D, off)
            for side, sx in (("R", -1), ("L", 1)):
                T = rig.attach(heads, D, "chest", (sx * 0.1, 1.35, 0.3))
                D.update(rig.solve_arm(side, T, shoulder=heads["upperarm_" + side]))
                D["hand_" + side] = D["forearm_" + side]
        else:
            free_arms(rig, D, off, math.sin(phase) * 1.0, 0.25)
        rig.key_pose("run_gun", f, D, off)


def clip_shoot(rig, kind, frames=12):
    w = KIND[kind]["weapon"]
    for f in range(frames + 1):
        kick = max(0.0, 1.0 - f / 4.0) if f < 5 else 0.0
        D = {"hips": rx(2.0), "spine": rx(1.0 - 1.5 * kick), "chest": rx(1.0 - 2.0 * kick), "head": rx(-1.0)}
        D["thigh_L"] = rz(-4.0) * rx(-4.0)
        D["thigh_R"] = rz(4.0) * rx(8.0)
        D["shin_L"] = rx(-2.0)
        D["shin_R"] = rx(14.0)
        off = (0, 0.0, -0.012 * kick)
        if w in LOW_PITCH:
            pitch = AIM_PITCH.get(w, 0.0) - (2.5 * kick if w in ("rifle", "smg", "sniper", "mg") else (6.0 * kick if w == "mortar" else 0.0))
            hold_pose(rig, kind, D, off, pitch, (0, 0.0, -0.03 * kick))
        elif w == "scout":
            hold_pose(rig, kind, D, off, 0.0, (0, 0.2, 0.0))
        else:
            free_arms(rig, D, off, 0.0)
        rig.key_pose("idle_shoot", f, D, off)


def clip_interact(rig, kind, frames=20):
    for f in range(frames + 1):
        t = f / frames
        s = math.sin(t * math.tau)
        strike = max(0.0, -math.sin(t * math.tau))          # 0..1 as the hammer comes down
        D = {"hips": rx(6.0 + 4.0 * strike), "spine": rx(6.0), "chest": rx(4.0 + 3.0 * strike), "head": rx(-8.0)}
        D["thigh_L"] = rz(-4.0)
        D["thigh_R"] = rz(4.0)
        D["shin_L"] = rx(6.0)
        D["shin_R"] = rx(10.0)
        off = (0, -0.03 - 0.02 * strike, 0.0)
        heads = rig.fk(D, off)
        up = 0.5 * max(0.0, s)
        TR = rig.attach(heads, D, "chest", (-0.15, 0.92 + 0.5 * up + 0.12 * (1 - strike) * 0, 0.34 + 0.02 * strike))
        TL = rig.attach(heads, D, "chest", (0.12, 1.12, 0.3))
        D.update(rig.solve_arm("R", TR, shoulder=heads["upperarm_R"]))
        D.update(rig.solve_arm("L", TL, shoulder=heads["upperarm_L"]))
        D["hand_R"] = D["forearm_R"]
        D["hand_L"] = D["forearm_L"]
        rig.key_pose("interact", f, D, off)


def clip_death(rig, kind, frames=36):
    for f in range(frames + 1):
        t = min(1.0, f / (frames * 0.78))
        e = t * t * (3 - 2 * t)                         # ease
        fall = -88.0 * e                                # every bone's global tilt: the whole body goes over backwards
        D = {"hips": rx(fall), "spine": rx(fall - 3.0 * e), "chest": rx(fall - 6.0 * e), "head": rx(fall - 16.0 * e)}
        off = (0, -0.72 * e, -0.05 * e)
        D["thigh_L"] = rx(fall) * rz(-6.0 * e)
        D["thigh_R"] = rx(fall + 6.0 * e) * rz(8.0 * e)
        D["shin_L"] = rx(fall + 10.0 * e)
        D["shin_R"] = rx(fall + 24.0 * e)
        D["foot_L"] = rx(fall + 20.0 * e)
        D["foot_R"] = rx(fall + 30.0 * e)
        heads = rig.fk(D, off)
        for side, sx in (("R", -1), ("L", 1)):
            tgt = rig.attach(heads, D, "chest", (sx * (0.3 + 0.28 * e), 1.46 - 0.35 * e, 0.0 + 0.1 * e))
            D.update(rig.solve_arm(side, tgt, shoulder=heads["upperarm_" + side]))
            D["hand_" + side] = D["forearm_" + side]
        rig.key_pose("death", f, D, off)


# ------------------------------------------------------------------ build
def build(kind):
    rig = Rig("inf_" + kind)
    k = KIND[kind]
    body(rig, kind)
    headgear(rig, kind)
    extras(rig, kind)
    w = k["weapon"]
    if w in ("rifle", "smg", "sniper"):
        rifle(rig, w)
    elif w in ("rocket", "atgm", "manpads"):
        launcher(rig, w)
    elif w in ("mg", "mortar", "rcl"):
        team_weapon(rig, w)
    rig.bone = "hips"
    clip_idle(rig, kind)
    clip_run(rig, kind)
    clip_shoot(rig, kind)
    clip_interact(rig, kind)
    clip_death(rig, kind)
    rig.export(os.path.join(out_dir, "inf_%s.glb" % kind))


for kind in (kinds_wanted or list(KIND.keys())):
    build(kind)
