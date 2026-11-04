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
SKIN = hexc("c9a07e")


def body(m, kind):
    k = KIND[kind]
    uni = k.get("uniform", "uniform")
    pants = k.get("pants", "pants")
    m.bone = "hips"
    m.box(pants, (-0.18, 0.86, -0.12), (0.18, 1.07, 0.12), bevel=0.04, seg=1)
    m.box("gear", (-0.19, 1.02, -0.125), (0.19, 1.07, 0.125), bevel=0.01, seg=1)             # the belt
    m.bone = "spine"
    m.box(uni, (-0.185, 1.05, -0.115), (0.185, 1.34, 0.115), bevel=0.04, seg=1)
    m.bone = "chest"
    m.box(uni, (-0.21, 1.3, -0.135), (0.21, 1.55, 0.135), bevel=0.05, seg=1)
    if k.get("vest", True):
        m.box(k.get("vest_role", "gear"), (-0.22, 1.31, 0.07), (0.22, 1.54, 0.16), bevel=0.03, seg=1)    # plate carrier
        for sx in (-0.13, 0.0, 0.13):
            m.box("gear", (sx - 0.05, 1.33, 0.16), (sx + 0.05, 1.45, 0.205), bevel=0.01, seg=1, tint=(0.8, 0.8, 0.8))   # magazine pouches
        m.box("gear", (-0.22, 1.31, -0.16), (0.22, 1.54, -0.07), bevel=0.03, seg=1)                  # back plate
    if k.get("pack", True):
        m.box(k.get("pack_role", "gear"), (-0.17, 1.28, -0.34), (0.17, 1.6, -0.15), bevel=0.04, seg=1, tint=(0.9, 0.9, 0.9))
        m.box("gear", (-0.14, 1.52, -0.36), (0.14, 1.62, -0.2), bevel=0.03, seg=1)                  # a rolled mat on top
    m.bone = "neck"
    m.cyl("skin", (0, 1.52, 0), 0.052, 0.13, 8, tint=SKIN)
    m.bone = "head"
    m.cyl("skin", (0, 1.63, 0), 0.093, 0.14, 10, r2=0.088, tint=SKIN)
    sphere(m, "skin", (0, 1.77, 0.0), 0.093, SKIN, 0.9)
    m.box("dark", (-0.045, 1.725, 0.082), (-0.02, 1.745, 0.1))                                      # eyes
    m.box("dark", (0.02, 1.725, 0.082), (0.045, 1.745, 0.1))
    for side, sx in (("R", -1), ("L", 1)):
        m.bone = "upperarm_" + side
        sphere(m, uni, (sx * 0.21, 1.46, 0), 0.07)
        limb(m, uni, (sx * 0.21, 1.46, 0), (sx * 0.23, 1.18, 0), 0.058, 0.05)
        m.box("banner", (sx * 0.27 - 0.012, 1.34, -0.045), (sx * 0.27 + 0.012, 1.44, 0.045))      # the nation's patch on the sleeve
        m.bone = "forearm_" + side
        sphere(m, uni, (sx * 0.23, 1.18, 0), 0.053)
        limb(m, uni, (sx * 0.23, 1.18, 0), (sx * 0.23, 0.93, 0), 0.05, 0.042)
        m.bone = "hand_" + side
        m.box(k.get("glove", "glove"), (sx * 0.23 - 0.035, 0.84, -0.035), (sx * 0.23 + 0.035, 0.95, 0.04), bevel=0.012, seg=1)
        m.bone = "thigh_" + side
        sphere(m, pants, (sx * 0.1, 0.95, 0), 0.085)
        limb(m, pants, (sx * 0.1, 0.95, 0), (sx * 0.1, 0.53, 0), 0.084, 0.066)
        m.box("gear", (sx * 0.1 - 0.075, 0.66, 0.0), (sx * 0.1 + 0.075, 0.82, 0.08), bevel=0.02, seg=1, tint=(0.9, 0.9, 0.9)) if side == "R" else None   # a leg pouch
        m.bone = "shin_" + side
        sphere(m, pants, (sx * 0.1, 0.53, 0), 0.068)
        limb(m, pants, (sx * 0.1, 0.53, 0), (sx * 0.1, 0.1, 0), 0.066, 0.052)
        m.box("gear", (sx * 0.1 - 0.065, 0.5, -0.07), (sx * 0.1 + 0.065, 0.6, 0.075), bevel=0.02, seg=1)   # knee pad
        m.bone = "foot_" + side
        m.box("boot", (sx * 0.1 - 0.058, 0.0, -0.07), (sx * 0.1 + 0.058, 0.12, 0.2), bevel=0.025, seg=1)
        m.box("dark", (sx * 0.1 - 0.06, 0.0, -0.07), (sx * 0.1 + 0.06, 0.025, 0.205))              # the sole


def helmet(m, role="uniform", cover=False):
    m.bone = "head"
    sphere(m, role, (0, 1.78, 0), 0.118, sy=0.82)
    m.cyl(role, (0, 1.75, 0), 0.122, 0.03, 12)
    if cover:
        m.box("gear", (-0.09, 1.82, -0.09), (0.09, 1.86, 0.09), bevel=0.01, seg=1)
    m.box("gear", (-0.05, 1.835, 0.11), (0.05, 1.87, 0.15))                                         # night-vision mount


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
        m.cyl("dark", (x, y + 0.04, z + 0.42), 0.0, 0.0, 3) if False else None
        m.pipe("glass", (x, y + 0.075, z + 0.42), (x, y + 0.075, z + 0.43), 0.03, 8)
        m.pipe("metal", (x - 0.04, y - 0.06, z + 0.6), (x - 0.06, y - 0.2, z + 0.64), 0.008, 4)         # a bipod folded
        m.pipe("metal", (x + 0.04, y - 0.06, z + 0.6), (x + 0.06, y - 0.2, z + 0.64), 0.008, 4)
    if kind == "smg":
        m.pipe("metal", (x, y - 0.01, z + L), (x, y - 0.01, z + L + 0.12), 0.022, 6)                    # a suppressor


def launcher(m, kind):
    m.bone = "weapon"
    x, y, z = W
    if kind == "rocket":
        m.pipe("metal", (x, y + 0.02, z - 0.2), (x, y + 0.02, z + 0.75), 0.04, 8)
        m.pipe("metal", (x, y + 0.02, z + 0.75), (x, y + 0.02, z + 0.9), 0.06, 8, r2=0.075)
        m.cyl("wood", (x, y + 0.02, z + 0.1), 0.0, 0.0, 3) if False else None
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


def headgear(m, kind):
    k = KIND[kind]
    h = k.get("head", "helmet")
    m.bone = "head"
    if h == "helmet":
        helmet(m)
    elif h == "hardhat":
        sphere(m, "hivis_yellow", (0, 1.78, 0), 0.12, sy=0.8)
        m.cyl("hivis_yellow", (0, 1.76, 0), 0.13, 0.025, 12)
        m.box("hivis_yellow", (-0.09, 1.76, 0.1), (0.09, 1.78, 0.2), bevel=0.01, seg=1)             # the peak
    elif h == "boonie":
        sphere(m, "camo", (0, 1.8, 0), 0.105, sy=0.7)
        m.cyl("camo", (0, 1.775, 0), 0.19, 0.02, 14)
        for sx in (-1, 1):
            m.pipe("camo", (sx * 0.1, 1.8, 0.03), (sx * 0.14, 1.72, 0.04), 0.012, 4)
    elif h == "balaclava":
        sphere(m, "dark", (0, 1.77, 0), 0.098, sy=0.92)
        m.cyl("dark", (0, 1.63, 0), 0.096, 0.1, 10)
        m.box("glass", (-0.07, 1.72, 0.085), (0.07, 1.76, 0.115), tint=(0.5, 1.2, 0.6))             # night-vision goggles
        helmet(m, "dark")
    elif h == "cap":
        sphere(m, "uniform", (0, 1.79, 0), 0.1, sy=0.7)
        m.box("uniform", (-0.08, 1.755, 0.07), (0.08, 1.77, 0.18), bevel=0.008, seg=1)
    elif h == "medic":
        helmet(m)
        m.box("paint", (-0.05, 1.82, 0.105), (0.05, 1.87, 0.12), tint=hexc("f4f0e4"))
        m.box("red", (-0.012, 1.825, 0.12), (0.012, 1.865, 0.125))
        m.box("red", (-0.035, 1.837, 0.12), (0.035, 1.853, 0.125))
    elif h == "goggles":
        helmet(m)
        m.box("glass", (-0.08, 1.725, 0.085), (0.08, 1.765, 0.118), tint=(0.6, 0.9, 1.4))
    if k.get("vest_role") == "hivis":
        pass


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
}
GRIPS = {   # weapon-bone-local grip points: (right hand, left hand)
    "rifle": ((0, -0.1, 0.07), (0, -0.045, 0.44)),
    "smg": ((0, -0.1, 0.07), (0, -0.045, 0.38)),
    "sniper": ((0, -0.1, 0.07), (0, -0.07, 0.46)),
    "rocket": ((0, -0.1, 0.22), (0, 0.0, 0.5)),
    "atgm": ((0, -0.12, 0.3), (0, 0.04, 0.62)),
    "manpads": ((0, -0.1, 0.2), (0, 0.0, 0.5)),
    "scout": ((-0.04, 0.0, 0.17), (0.04, 0.0, 0.17)),
}
LOW_PITCH = {"rifle": 30.0, "smg": 32.0, "sniper": 28.0, "rocket": -22.0, "atgm": -18.0, "manpads": -22.0}


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
            pitch = -2.5 * kick if w in ("rifle", "smg", "sniper") else 0.0
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
    rig.bone = "hips"
    clip_idle(rig, kind)
    clip_run(rig, kind)
    clip_shoot(rig, kind)
    clip_interact(rig, kind)
    clip_death(rig, kind)
    rig.export(os.path.join(out_dir, "inf_%s.glb" % kind))


for kind in (kinds_wanted or list(KIND.keys())):
    build(kind)
