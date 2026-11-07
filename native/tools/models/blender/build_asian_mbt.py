"""Chinese, Pakistani, Japanese & Indian Main Battle Tanks (6 variants), modelled in Blender.

Variants built (`--all`):
  - tank__type_99a.glb          (China ZTZ-99A — 6 wheels, FY-4 arrow ERA turret & glacis, JD-3 laser dazzler box, 125 mm L/50, rear drums)
  - tank__vt_4_haider.glb       (Pakistan HIT Haider — 6 wheels, angular VT-4 wedge ERA turret, bustle flank bins, UW4A RWS, 125 mm)
  - tank__vt_4_vickers_mk_3.glb (Export VT-4 — 6 wheels, angular VT-4 wedge ERA turret, left-hull APU/AC pack, UW4A RWS, 125 mm)
  - tank__type_10.glb           (Japan Hitomaru — Compact 5-wheel hull!, sharp stealth diamond modular cheeks, bustle autoloader, 120 mm L/44)
  - tank__type_90.glb           (Japan Kyu-maru — 6 wheels, flat vertical slab-box turret w/ left sight notch, deep bustle, 120 mm L/44)
  - tank__arjun_mk1.glb         (India DRDO Arjun Mk1 — 7 wheels, wide boxy Kanchan turret w/ deep sight recess, 120 mm rifled gun)

Run:
    blender -b -P native/tools/models/blender/build_asian_mbt.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_t72_t90 import build_uvz_wheel, build_uvz_sprocket, build_uvz_idler, build_uvz_roller, build_rear_fuel_drums_and_log
from build_leopard import build_leo_wheel, build_sprocket, build_idler, build_roller

OPTIC_FLIR = (2.1, 1.32, 0.50)
OPTIC_COOL = (0.75, 1.38, 1.48)
LASER_LENS = (0.45, 1.65, 1.35)


def add_asian_emblem_x(part, x_plane, cy, cz, sx_out, size=0.14):
    """Crisp tactical diamond / emblem in `markings` role flush on side armor."""
    out = (sx_out, 0.0, 0.0)
    part.decal_quad("markings",
                    (x_plane, cy, cz - size),
                    (x_plane, cy - size * 0.85, cz),
                    (x_plane, cy, cz + size),
                    (x_plane, cy + size * 0.85, cz),
                    outward=out)


# ==============================================================================
# 1. CHINESE PLA TYPE 99A & NORINCO VT-4 / HAIDER (6 wheels, 125 mm smoothbore)
# ==============================================================================
def build_chinese_mbt_rig(lod=0, variant="type_99a"):
    rig = VehicleRig(lod=lod)
    is_99a = variant == "type_99a"
    is_haider = variant == "vt_4_haider"
    k = 0.96 if is_99a else 0.89
    bev = 0.015 if lod else 0.025
    wheel_zs = [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]
    z_front = 3.78 if is_99a else 3.55
    z_rear = -3.80 if is_99a else -3.55
    y_deck = 1.42 if is_99a else 1.40

    h = Part("Hull", seed=47)
    hull_yz = [
        (0.42, z_front - 0.58),
        (0.88, z_front),
        (1.02, z_front - 0.05),
        (y_deck, 1.85),
        (y_deck, -1.70),
        (y_deck + (0.10 if is_99a else 0.04), z_rear + 0.14),
        (1.20, z_rear),
        (0.50, z_rear + 0.14),
        (0.42, z_rear + 0.54),
    ]
    h.prism_x("paint", hull_yz, -1.12, 1.12, bevel=bev, seg=1, ao_y=(0.42, y_deck, 0.68))

    # Central driver hatch & V-angled FY-4 heavy ERA glacis modules!
    glacis_pitch = math.atan2(y_deck - 0.94, (z_front - 0.10) - 1.85)
    h.box("paint", (-0.30, y_deck - 0.02, 1.65), (0.30, y_deck + 0.09, 2.18), bevel=0.014)
    h.box("glass", (-0.18, y_deck + 0.04, 2.15), (0.18, y_deck + 0.10, 2.22), tint=OPTIC_COOL)
    for sx in (-1, 1):
        with h.frame((sx * 0.62, 1.16, 2.75 if is_99a else 2.60), pitch=glacis_pitch):
            h.box("paint", (-0.45, 0.0, -0.68), (0.45, 0.11, 0.68), bevel=0.015, tint=(1.03, 1.03, 1.01))
    with h.frame((0.0, 1.02, 3.22 if is_99a else 3.04), pitch=glacis_pitch):
        h.box("paint", (-0.22, 0.0, -0.28), (0.22, 0.10, 0.28), bevel=0.012, tint=(1.02, 1.02, 1.0))

    for sx in (-1, 1):
        h.box("paint", (sx * 0.94 - 0.14, 1.08, z_front - 0.34), (sx * 0.94 + 0.14, 1.24, z_front - 0.12), bevel=0.010)
        h.box("glass", (sx * 0.94 - 0.09, 1.12, z_front - 0.14), (sx * 0.94 + 0.09, 1.20, z_front - 0.10), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.12 - 0.03, 0.42, z_rear + 0.35), (sx * 1.12 + 0.03, y_deck - 0.06, z_front - 0.35))

        x_in, x_out = (1.10, 1.74) if sx > 0 else (-1.74, -1.10)
        h.box("paint", (x_in, y_deck - 0.10, z_rear + 0.06), (x_out, y_deck, z_front - 0.25), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.48, z_rear - 0.04), (max(x_in, x_out) - 0.02, 1.26, z_rear + 0.02), bevel=0.008)

        # Scalloped Chinese side skirts (`xo = 1.82..1.85`)
        for idx in range(6):
            zf = (z_front - 0.36) - idx * 1.08
            zr = zf - 1.03
            xo = 1.85 if idx < 3 else 1.80
            x0, x1 = (1.73, xo) if sx > 0 else (-xo, -1.73)
            h.box("paint", (x0, 0.74 if idx < 3 else 0.82, zr), (x1, y_deck - 0.01, zf), bevel=0.010, tint=(1.0, 1.0, 0.98))
        add_asian_emblem_x(h, sx * 1.858, 1.06, 1.35, sx, size=0.14)

    if variant == "vt_4_vickers_mk_3":
        # Export VT-4 signature left-rear fender APU / tropical AC unit!
        h.box("paint", (-1.68, y_deck - 0.01, -2.72), (-1.18, y_deck + 0.34, -1.96), bevel=0.016, tint=(0.96, 0.97, 0.94))

    h.box("dark", (-0.92, y_deck + (0.07 if is_99a else 0.02), z_rear + 0.28), (0.92, y_deck + (0.12 if is_99a else 0.06), -1.88))
    if not lod:
        for i in range(9):
            gz = z_rear + 0.38 + i * 0.16
            h.box("metal_dark", (-0.88, y_deck + (0.09 if is_99a else 0.04), gz - 0.02),
                  (0.88, y_deck + (0.13 if is_99a else 0.07), gz + 0.02))

    if is_99a:
        build_rear_fuel_drums_and_log(h, lod, z_rear=z_rear, y_deck=y_deck, with_drums=True, with_log=False)

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.10), 1.06, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.03, 0.10), ring)

    # Turret: Sharp Arrowhead FY-4 ERA Cheeks + Long Bustle (+ JD-3 Laser Dazzler on Type 99A!)
    t = Part("Turret", seed=58)
    y0, y_top = y_deck + 0.05, 2.38 if is_99a else 2.34
    bot_xz = [(-0.38, 1.56), (0.38, 1.56), (1.52, 0.68), (1.44, -1.50), (1.08, -1.94), (-1.08, -1.94), (-1.44, -1.50), (-1.52, 0.68)]
    top_xz = [(-0.34, 0.88), (0.34, 0.88), (1.18, 0.42), (1.18, -1.46), (0.94, -1.84), (-0.94, -1.84), (-1.18, -1.46), (-1.18, 0.42)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    # Sharp arrowhead FY-4 wedge ERA cheek blocks!
    for sx in (-1, 1):
        w_bot = [(sx * 0.38, 1.72), (sx * 1.58, 0.78), (sx * 1.50, 0.12), (sx * 0.40, 0.95)]
        w_top = [(sx * 0.36, 1.08), (sx * 1.26, 0.48), (sx * 1.22, 0.10), (sx * 0.38, 0.70)]
        if sx < 0:
            w_bot, w_top = list(reversed(w_bot)), list(reversed(w_top))
        t.prism_y("paint", w_bot, y0 + 0.06, y_top - 0.02, top_xz=w_top, bevel=0.018, seg=1, tint=(1.04, 1.04, 1.02))

        if is_haider:
            # HIT Haider distinct bustle-side enclosed armor stowage pods!
            x0, x1 = (1.18, 1.42) if sx > 0 else (-1.42, -1.18)
            t.box("paint", (x0, y0 + 0.20, -1.78), (x1, y_top - 0.08, -0.58), bevel=0.016, tint=(0.98, 0.98, 0.96))
            add_asian_emblem_x(t, sx * 1.428, (y0 + y_top) * 0.52, -1.18, sx, size=0.13)
        else:
            t.box("paint", (sx * 1.32 - 0.06, y0 + 0.24, -1.36), (sx * 1.32 + 0.06, y_top - 0.14, -0.62), bevel=0.012)
            add_asian_emblem_x(t, sx * 1.388, (y0 + y_top) * 0.52, -0.98, sx, size=0.12)

    t.box("paint", (-1.06, y0 + 0.22, -2.38), (1.06, y_top - 0.02, -1.56), bevel=0.018, tint=(0.99, 0.99, 0.97))

    if is_99a:
        # SIGNATURE ZTZ-99A JD-3 Active Laser Defence / Dazzler Box behind commander cupola!
        t.cyl("paint", (0.76, y_top, -0.78), 0.15, 0.18, seg=10)
        t.box("paint", (0.54, y_top + 0.16, -0.98), (0.98, y_top + 0.54, -0.56), bevel=0.018, tint=(1.02, 1.02, 1.0))
        t.box("glass", (0.60, y_top + 0.24, -0.58), (0.92, y_top + 0.46, -0.54), tint=LASER_LENS)

    if not lod:
        for ry in (y0 + 0.26, y_top - 0.10):
            t.pipe("metal_dark", (-1.14, ry, -2.58), (1.14, ry, -2.58), 0.015, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.14, ry, -2.58), (sx * 1.36, ry, -1.35), 0.015, seg=6)

    rig.add("Turret", "Hull", (0.0, y0, 0.10), t)

    # 125 mm ZPT-98 Smoothbore Gun
    gp = (0.0, y0 + 0.46, 1.34)
    g = Part("Gun", seed=91)
    seg = 10 if lod else 20
    z_tip = gp[2] + (5.16 if is_99a else 4.92)
    g.box("paint", (-0.32, gp[1] - 0.22, gp[2] - 0.10), (0.32, gp[1] + 0.22, gp[2] + 0.42), bevel=0.022)
    g.pipe("paint", (0, gp[1], gp[2] + 0.38), (0, gp[1], gp[2] + 1.92), 0.110, seg=seg, r2=0.100)
    g.pipe("paint", (0, gp[1] + 0.018, gp[2] + 1.90), (0, gp[1] + 0.018, gp[2] + 2.52), 0.156, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.50), (0, gp[1], z_tip - 0.16), 0.092, seg=seg, r2=0.084)
    if not lod:
        g.box("metal_dark", (-0.025, gp[1] + 0.082, z_tip - 0.22), (0.025, gp[1] + 0.15, z_tip - 0.08), bevel=0.005)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.090, 0.0625, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.063, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    # Sights, Hatches & QJC-88 / UW4A 12.7 mm RWS
    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.76, y_top - 0.02, 0.22), (-0.38, y_top + 0.26, 0.68), bevel=0.016)
    gs.box("glass", (-0.70, y_top + 0.05, 0.66), (-0.44, y_top + 0.20, 0.70), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (-0.57, y_top, 0.45), gs)

    citv = Part("CITV")
    cx, cz = (-0.58, -0.58) if not is_99a else (0.52, -0.18)
    citv.cyl("paint", (cx, y_top, cz), 0.16, 0.24, seg=10 if lod else 14)
    citv.box("paint", (cx - 0.19, y_top + 0.22, cz - 0.19), (cx + 0.19, y_top + 0.46, cz + 0.19), bevel=0.016)
    citv.box("glass", (cx - 0.13, y_top + 0.28, cz + 0.17), (cx + 0.13, y_top + 0.40, cz + 0.21), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (cx, y_top, cz), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.52, -0.46 if is_99a else -0.32), ("Hatch_Loader", -0.52, -0.24)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.28, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.26), hp)

    wep_name = "Commander_MG" if is_99a else "CROWS"
    wep = Part(wep_name)
    wx_m, wz_m = (0.52, -0.32) if is_99a else (0.56, -0.82)
    wep.cyl("metal_dark", (wx_m, y_top + 0.04, wz_m), 0.09, 0.24, seg=8)
    wep.box("metal_dark", (wx_m - 0.12, y_top + 0.26, wz_m - 0.20), (wx_m + 0.12, y_top + 0.44, wz_m + 0.20), bevel=0.010)
    wep.pipe("metal_dark", (wx_m, y_top + 0.36, wz_m + 0.18), (wx_m, y_top + 0.36, wz_m + 0.96), 0.022, seg=8)
    rig.add(wep_name, "Turret", (wx_m, y_top + 0.04, wz_m), wep)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * 1.38, y0 + 0.52, -0.32
        sm.box("paint", (sx_p - 0.07, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.07, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(6):
                sm.pipe("metal_dark", (sx_p, sy_p + (0.04 if j >= 3 else -0.03), sz_p + ((j % 3) - 1) * 0.09),
                        (sx_p + side * 0.09, sy_p + (0.11 if j >= 3 else 0.04), sz_p + ((j % 3) - 1) * 0.09 + 0.14), 0.032, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    ant = Part("Antenna_1")
    ant.cyl("metal_dark", (-0.92, y_top, -1.96), 0.036, 0.11, seg=8)
    ant.pipe("metal_dark", (-0.92, y_top + 0.11, -1.96), (-0.94, y_top + 1.45, -2.02), 0.010, seg=6, r2=0.004)
    rig.add("Antenna_1", "Turret", (-0.92, y_top, -1.96), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.42
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.44, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_uvz_wheel(wp, lod, side, r=0.37))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_uvz_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_uvz_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.02 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_uvz_roller(rp, lod, side, scale=k))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.59)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.72, 1.22, -2.85), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + 0.08, -2.65), None)
    return rig


# ==============================================================================
# 2. JAPANESE JGSDF TYPE 10 (5 wheels, diamond stealth cheeks) & TYPE 90 (6 wheels, box turret)
# ==============================================================================
def build_japanese_mbt_rig(lod=0, is_type10=True):
    rig = VehicleRig(lod=lod)
    k = 0.84 if is_type10 else 0.94
    bev = 0.014 if lod else 0.024
    wheel_zs = [-2.40, -1.20, 0.00, 1.20, 2.40] if is_type10 else [-2.44, -1.46, -0.49, 0.49, 1.46, 2.44]
    z_front = 3.40 if is_type10 else 3.76
    z_rear = -3.40 if is_type10 else -3.76
    y_deck = 1.28 if is_type10 else 1.43

    h = Part("Hull", seed=79)
    hw_hull = 1.02 if is_type10 else 1.10
    hull_yz = [
        (0.40, z_front - 0.54),
        (0.86, z_front),
        (1.00, z_front - 0.05),
        (y_deck, 1.72 if is_type10 else 1.95),
        (y_deck, -1.65),
        (y_deck + 0.05, z_rear + 0.12),
        (1.16, z_rear),
        (0.48, z_rear + 0.12),
        (0.40, z_rear + 0.50),
    ]
    h.prism_x("paint", hull_yz, -hw_hull, hw_hull, bevel=bev, seg=1, ao_y=(0.40, y_deck, 0.68))

    dx = 0.42 if is_type10 else -0.48
    h.box("paint", (dx - 0.26, y_deck - 0.02, 1.65), (dx + 0.26, y_deck + 0.09, 2.22), bevel=0.014)
    h.box("glass", (dx - 0.16, y_deck + 0.04, 2.19), (dx + 0.16, y_deck + 0.10, 2.26), tint=OPTIC_COOL)

    wx_abs = 1.28 if is_type10 else 1.38
    xo_skirt = 1.66 if is_type10 else 1.76
    for sx in (-1, 1):
        h.box("paint", (sx * (hw_hull - 0.12) - 0.13, 1.04, z_front - 0.30), (sx * (hw_hull - 0.12) + 0.13, 1.20, z_front - 0.10), bevel=0.010)
        h.box("glass", (sx * (hw_hull - 0.12) - 0.08, 1.08, z_front - 0.12), (sx * (hw_hull - 0.12) + 0.08, 1.16, z_front - 0.08), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * hw_hull - 0.03, 0.42, z_rear + 0.35), (sx * hw_hull + 0.03, y_deck - 0.06, z_front - 0.35))

        x_in, x_out = (hw_hull - 0.02, xo_skirt - 0.06) if sx > 0 else (-(xo_skirt - 0.06), -(hw_hull - 0.02))
        h.box("paint", (x_in, y_deck - 0.09, z_rear + 0.05), (x_out, y_deck, z_front - 0.22), bevel=0.012, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.48, z_rear - 0.05), (max(x_in, x_out) - 0.02, y_deck - 0.08, z_rear + 0.02), bevel=0.008)

        n_sk = 5 if is_type10 else 4
        step = (z_front - z_rear - 0.72) / n_sk
        for idx in range(n_sk):
            zf = (z_front - 0.34) - idx * step
            zr = zf - (step - 0.04)
            x0, x1 = (xo_skirt - 0.07, xo_skirt) if sx > 0 else (-xo_skirt, -(xo_skirt - 0.07))
            h.box("paint", (x0, 0.72 if is_type10 else 0.78, zr), (x1, y_deck - 0.01, zf), bevel=0.010, tint=(1.0, 1.0, 0.98))
        add_asian_emblem_x(h, sx * (xo_skirt + 0.008), 1.02, 0.38, sx, size=0.13)

    h.box("dark", (-0.82, y_deck + 0.02, z_rear + 0.24), (0.82, y_deck + 0.06, -1.85))
    if not lod:
        for i in range(8):
            gz = z_rear + 0.34 + i * 0.16
            h.box("metal_dark", (-0.78, y_deck + 0.04, gz - 0.02), (0.78, y_deck + 0.07, gz + 0.02))

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.0), 0.98 if is_type10 else 1.04, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.03, 0.0), ring)

    # Turret: Type 10 Sharp Stealth Diamond Modular Cheeks vs Type 90 Vertical Slab-Box!
    t = Part("Turret", seed=84)
    y0, y_top = y_deck + 0.05, 2.22 if is_type10 else 2.28
    if is_type10:
        bot_xz = [(-0.32, 1.44), (0.32, 1.44), (1.36, 0.48), (1.28, -1.24), (0.94, -1.72), (-0.94, -1.72), (-1.28, -1.24), (-1.36, 0.48)]
        top_xz = [(-0.28, 0.82), (0.28, 0.82), (1.04, 0.28), (1.04, -1.22), (0.84, -1.60), (-0.84, -1.60), (-1.04, -1.22), (-1.04, 0.28)]
        t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))
        # Stealthy wrap-around side modular skirts & bustle autoloader!
        t.box("paint", (-0.94, y0 + 0.24, -2.14), (0.94, y_top + 0.02, -1.42), bevel=0.018, tint=(0.99, 0.99, 0.97))
        for sx in (-1, 1):
            w_bot = [(sx * 0.32, 1.56), (sx * 1.42, 0.52), (sx * 1.34, -0.98), (sx * 0.98, -1.42)]
            w_top = [(sx * 0.30, 0.90), (sx * 1.10, 0.30), (sx * 1.10, -0.96), (sx * 0.88, -1.36)]
            if sx < 0:
                w_bot, w_top = list(reversed(w_bot)), list(reversed(w_top))
            t.prism_y("paint", w_bot, y0 + 0.12, y_top - 0.04, top_xz=w_top, bevel=0.016, seg=1, tint=(1.03, 1.03, 1.01))
            add_asian_emblem_x(t, sx * 1.35, (y0 + y_top) * 0.52, -0.45, sx, size=0.11)
    else:
        # Type 90: Unmistakable flat vertical slab-fronted box turret + deep rear bustle!
        bot_xz = [(-0.40, 1.56), (0.40, 1.56), (1.44, 1.46), (1.46, -1.66), (1.18, -2.04), (-1.18, -2.04), (-1.46, -1.66), (-1.44, 1.46)]
        top_xz = [(-0.40, 1.38), (0.40, 1.38), (1.38, 1.30), (1.36, -1.62), (1.12, -1.94), (-1.12, -1.94), (-1.36, -1.62), (-1.38, 1.30)]
        t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))
        for sx in (-1, 1):
            t.box("paint", (sx * 0.92 - 0.42, y0 + 0.08, 1.36), (sx * 0.92 + 0.42, y_top - 0.04, 1.62), bevel=0.018, tint=(1.03, 1.03, 1.01))
            add_asian_emblem_x(t, sx * 1.468, (y0 + y_top) * 0.52, -0.45, sx, size=0.13)
        if not lod:
            for ry in (y0 + 0.24, y_top - 0.12):
                t.pipe("metal_dark", (-1.18, ry, -2.44), (1.18, ry, -2.44), 0.016, seg=6)
                for sx in (-1, 1):
                    t.pipe("metal_dark", (sx * 1.18, ry, -2.44), (sx * 1.18, ry, -1.96), 0.016, seg=6)

    rig.add("Turret", "Hull", (0.0, y0, 0.0), t)

    # JSW 120 mm L/44 Smoothbore Gun
    gp = (0.0, 1.84 if is_type10 else 1.87, 1.16 if is_type10 else 1.34)
    g = Part("Gun", seed=93)
    seg = 10 if lod else 20
    z_tip = gp[2] + (4.50 if is_type10 else 4.46)
    g.box("paint", (-0.30, gp[1] - 0.22, gp[2] - 0.10), (0.30, gp[1] + 0.22, gp[2] + 0.40), bevel=0.022)
    g.pipe("paint", (0, gp[1], gp[2] + 0.36), (0, gp[1], gp[2] + 1.86), 0.108, seg=seg, r2=0.098)
    g.pipe("paint", (0, gp[1] + 0.015, gp[2] + 1.84), (0, gp[1] + 0.015, gp[2] + 2.42), 0.148, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.40), (0, gp[1], z_tip - 0.16), 0.090, seg=seg, r2=0.082)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.088, 0.060, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.061, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    gs = Part("Gunner_Sight")
    gs.box("paint", (-0.76, y_top - 0.02, 0.38 if is_type10 else 0.56), (-0.38, y_top + 0.24, 0.80 if is_type10 else 0.98), bevel=0.016)
    gs.box("glass", (-0.70, y_top + 0.04, 0.78 if is_type10 else 0.96), (-0.44, y_top + 0.18, 0.82 if is_type10 else 1.00), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (-0.57, y_top, 0.60 if is_type10 else 0.77), gs)

    citv = Part("CITV")
    citv.cyl("paint", (0.52, y_top, -0.10), 0.15, 0.24, seg=10 if lod else 14)
    citv.box("paint", (0.34, y_top + 0.22, -0.28), (0.70, y_top + 0.44, 0.08), bevel=0.014)
    citv.box("glass", (0.40, y_top + 0.28, 0.06), (0.64, y_top + 0.38, 0.10), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (0.52, y_top, -0.10), citv)

    for hname, hx, hz in (("Hatch_Commander", 0.50, -0.58), ("Hatch_Loader", -0.50, -0.58)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.27, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.25), hp)

    mg = Part("Commander_MG")
    mg.cyl("metal_dark", (0.50, y_top + 0.04, -0.38), 0.065, 0.22, seg=8)
    mg.box("metal_dark", (0.42, y_top + 0.24, -0.54), (0.58, y_top + 0.36, -0.16), bevel=0.008)
    mg.pipe("metal_dark", (0.50, y_top + 0.30, -0.18), (0.50, y_top + 0.30, 0.58), 0.022, seg=8)
    rig.add("Commander_MG", "Turret", (0.50, y_top + 0.04, -0.38), mg)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * (1.22 if is_type10 else 1.44), y0 + 0.48, -0.35
        sm.box("paint", (sx_p - 0.06, sy_p - 0.08, sz_p - 0.16), (sx_p + 0.06, sy_p + 0.08, sz_p + 0.16), bevel=0.008)
        if not lod:
            for j in range(4):
                sm.pipe("metal_dark", (sx_p, sy_p + 0.02, sz_p - 0.12 + j * 0.08),
                        (sx_p + side * 0.09, sy_p + 0.09, sz_p + 0.02 + j * 0.08), 0.032, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -0.84), (2, 0.84)):
        ant = Part(f"Antenna_{idx}")
        az = -1.96 if is_type10 else -1.86
        ant.cyl("metal_dark", (ax, y_top, az), 0.035, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, az), (ax, y_top + 1.42, az - 0.04), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, az), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * wx_abs
        w_r = 0.37 if is_type10 else 0.355
        for i, wz in enumerate(wheel_zs):
            wp = (wx, w_r + 0.075, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=w_r))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.00 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.55 if is_type10 else 0.59)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (0.0, 1.12, z_rear), None)
    rig.add("Engine_Deck", "Hull", (0.0, y_deck + 0.04, -2.55), None)
    return rig


# ==============================================================================
# 3. INDIAN DRDO ARJUN MK1 (7 wheels, wide boxy Kanchan turret, 120 mm rifled gun)
# ==============================================================================
def build_arjun_rig(lod=0):
    rig = VehicleRig(lod=lod)
    k = 1.00
    bev = 0.015 if lod else 0.025
    wheel_zs = [-2.46, -1.64, -0.82, 0.00, 0.82, 1.64, 2.46]
    y_deck = 1.52

    h = Part("Hull", seed=95)
    hull_yz = [
        (0.44, 3.26),
        (0.96, 3.92),
        (1.12, 3.88),
        (y_deck, 2.02),
        (y_deck, -1.78),
        (1.56, -3.82),
        (1.34, -3.92),
        (0.54, -3.84),
        (0.44, -3.36),
    ]
    h.prism_x("paint", hull_yz, -1.16, 1.16, bevel=bev, seg=1, ao_y=(0.44, y_deck, 0.68))

    # Right-side Arjun driver hatch
    h.box("paint", (0.32, y_deck - 0.02, 1.92), (0.88, y_deck + 0.09, 2.52), bevel=0.014)
    h.box("glass", (0.42, y_deck + 0.04, 2.49), (0.78, y_deck + 0.10, 2.56), tint=OPTIC_COOL)

    for sx in (-1, 1):
        h.box("paint", (sx * 0.96 - 0.15, 1.14, 3.56), (sx * 0.96 + 0.15, 1.30, 3.78), bevel=0.010)
        h.box("glass", (sx * 0.96 - 0.10, 1.18, 3.76), (sx * 0.96 + 0.10, 1.26, 3.80), tint=(1.7, 1.7, 1.5))
        h.box("dark", (sx * 1.16 - 0.03, 0.44, -3.50), (sx * 1.16 + 0.03, y_deck - 0.06, 3.48))

        x_in, x_out = (1.14, 1.80) if sx > 0 else (-1.80, -1.14)
        h.box("paint", (x_in, y_deck - 0.10, -3.86), (x_out, y_deck, 3.60), bevel=0.014, tint=(0.98, 0.98, 0.96))
        h.box("rubber", (min(x_in, x_out) + 0.02, 0.50, -3.92), (max(x_in, x_out) - 0.02, 1.36, -3.85), bevel=0.008)

        for idx in range(7):
            zf = 3.48 - idx * 1.02
            zr = zf - 0.97
            xo = 1.90 if idx < 4 else 1.85
            x0, x1 = (1.79, xo) if sx > 0 else (-xo, -1.79)
            h.box("paint", (x0, 0.72, zr), (x1, y_deck - 0.01, zf), bevel=0.012, tint=(1.0, 1.0, 0.98))
        add_asian_emblem_x(h, sx * 1.908, 1.08, 0.52, sx, size=0.14)

    h.box("dark", (-0.96, 1.54, -3.65), (0.96, 1.59, -2.05))
    if not lod:
        for i in range(10):
            gz = -3.56 + i * 0.15
            h.box("metal_dark", (-0.90, 1.56, gz - 0.02), (0.90, 1.60, gz + 0.02))

    rig.add("Hull", rig.root_name, (0.0, 0.0, 0.0), h)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, y_deck - 0.01, 0.12), 1.08, 0.08, seg=14 if lod else 24)
    rig.add("Turret_Ring", "Hull", (0.0, y_deck + 0.03, 0.12), ring)

    # Boxy Kanchan Composite Turret with prominent stepped front cheeks & rear stowage basket!
    t = Part("Turret", seed=98)
    y0, y_top = y_deck + 0.05, 2.48
    bot_xz = [(-0.44, 1.44), (0.44, 1.44), (1.58, 1.12), (1.56, -1.48), (1.22, -1.88), (-1.22, -1.88), (-1.56, -1.48), (-1.58, 1.12)]
    top_xz = [(-0.40, 1.16), (0.40, 1.16), (1.40, 0.92), (1.42, -1.46), (1.10, -1.80), (-1.10, -1.80), (-1.42, -1.46), (-1.40, 0.92)]
    t.prism_y("paint", bot_xz, y0, y_top, top_xz=top_xz, bevel=bev, seg=1, ao_y=(y0, y_top, 0.78))

    # Distinct thick Kanchan cheek blocks (with right-cheek GMS sight notch!)
    t.box("paint", (-1.52, y0 + 0.06, 0.68), (-0.48, y_top - 0.04, 1.38), bevel=0.020, tint=(1.03, 1.03, 1.01))
    t.box("paint", (0.48, y0 + 0.06, 0.68), (1.52, y0 + 0.56, 1.38), bevel=0.020, tint=(1.03, 1.03, 1.01))
    t.box("dark", (0.62, y0 + 0.55, 0.82), (1.26, y_top - 0.06, 1.34))
    for sx in (-1, 1):
        add_asian_emblem_x(t, sx * 1.568, (y0 + y_top) * 0.52, -0.58, sx, size=0.14)

    if not lod:
        for ry in (y0 + 0.24, y_top - 0.12):
            t.pipe("metal_dark", (-1.28, ry, -2.28), (1.28, ry, -2.28), 0.016, seg=6)
            for sx in (-1, 1):
                t.pipe("metal_dark", (sx * 1.28, ry, -2.28), (sx * 1.28, ry, -1.82), 0.016, seg=6)

    rig.add("Turret", "Hull", (0.0, y0, 0.12), t)

    # 120 mm Rifled Arjun Gun with thermal sleeve, fume extractor & muzzle reference bar
    gp = (0.0, 2.02, 1.46)
    g = Part("Gun", seed=103)
    seg = 10 if lod else 20
    z_tip = gp[2] + 4.78
    g.box("paint", (-0.34, gp[1] - 0.22, gp[2] - 0.10), (0.34, gp[1] + 0.22, gp[2] + 0.42), bevel=0.022)
    g.pipe("paint", (0, gp[1], gp[2] + 0.38), (0, gp[1], gp[2] + 1.95), 0.110, seg=seg, r2=0.100)
    g.pipe("paint", (0, gp[1] + 0.016, gp[2] + 1.92), (0, gp[1] + 0.016, gp[2] + 2.52), 0.156, seg=seg, bevel=0.012, tint=(1.02, 1.02, 1.0))
    g.pipe("paint", (0, gp[1], gp[2] + 2.50), (0, gp[1], z_tip - 0.16), 0.092, seg=seg, r2=0.084)
    g.tube_axis("metal_dark", (0, gp[1], z_tip - 0.18), (0, gp[1], z_tip), 0.088, 0.060, seg=seg)
    g.cyl("dark", (0, gp[1], z_tip - 0.19), 0.061, 0.02, seg=10)
    rig.add("Gun", "Turret", gp, g)
    rig.add("Muzzle", "Gun", (0.0, gp[1], z_tip), None)

    gs = Part("Gunner_Sight")
    gs.box("paint", (0.64, y0 + 0.56, 0.72), (1.22, y_top + 0.18, 1.24), bevel=0.016)
    gs.box("glass", (0.72, y0 + 0.66, 1.22), (1.14, y_top + 0.10, 1.26), tint=OPTIC_FLIR)
    rig.add("Gunner_Sight", "Turret", (0.93, y_top - 0.10, 0.98), gs)

    citv = Part("CITV")
    citv.cyl("paint", (-0.58, y_top, 0.02), 0.16, 0.24, seg=10 if lod else 14)
    citv.box("paint", (-0.78, y_top + 0.22, -0.18), (-0.38, y_top + 0.46, 0.20), bevel=0.016)
    citv.box("glass", (-0.70, y_top + 0.28, 0.18), (-0.46, y_top + 0.40, 0.22), tint=OPTIC_FLIR)
    rig.add("CITV", "Turret", (-0.58, y_top, 0.02), citv)

    for hname, hx, hz in (("Hatch_Commander", -0.58, -0.56), ("Hatch_Loader", 0.58, -0.56)):
        hp = Part(hname)
        hp.cyl("paint", (hx, y_top - 0.02, hz), 0.29, 0.09, seg=10 if lod else 16, bevel=0.012)
        rig.add(hname, "Turret", (hx, y_top + 0.02, hz - 0.27), hp)

    mg = Part("Commander_MG")
    mg.cyl("metal_dark", (-0.58, y_top + 0.04, -0.34), 0.065, 0.22, seg=8)
    mg.box("metal_dark", (-0.66, y_top + 0.24, -0.52), (-0.50, y_top + 0.36, -0.14), bevel=0.008)
    mg.pipe("metal_dark", (-0.58, y_top + 0.30, -0.16), (-0.58, y_top + 0.30, 0.62), 0.022, seg=8)
    rig.add("Commander_MG", "Turret", (-0.58, y_top + 0.04, -0.34), mg)

    for label, side in (("L", -1), ("R", 1)):
        sm = Part(f"Smoke_Launcher_{label}")
        sx_p, sy_p, sz_p = side * 1.50, y0 + 0.48, 0.20
        sm.box("paint", (sx_p - 0.07, sy_p - 0.08, sz_p - 0.18), (sx_p + 0.07, sy_p + 0.08, sz_p + 0.18), bevel=0.008)
        if not lod:
            for j in range(6):
                sm.pipe("metal_dark", (sx_p, sy_p + (0.04 if j >= 3 else -0.03), sz_p + ((j % 3) - 1) * 0.09),
                        (sx_p + side * 0.09, sy_p + (0.11 if j >= 3 else 0.04), sz_p + ((j % 3) - 1) * 0.09 + 0.14), 0.032, seg=6)
        rig.add(f"Smoke_Launcher_{label}", "Turret", (sx_p, sy_p, sz_p), sm)

    for idx, ax in ((1, -1.04), (2, 1.04)):
        ant = Part(f"Antenna_{idx}")
        ant.cyl("metal_dark", (ax, y_top, -1.72), 0.036, 0.11, seg=8)
        ant.pipe("metal_dark", (ax, y_top + 0.11, -1.72), (ax, y_top + 1.45, -1.76), 0.010, seg=6, r2=0.004)
        rig.add(f"Antenna_{idx}", "Turret", (ax, y_top, -1.72), ant)

    for label, side in (("L", -1), ("R", 1)):
        wx = side * 1.48
        for i, wz in enumerate(wheel_zs):
            wp = (wx, 0.46, wz * k)
            rig.add(f"Wheel_{label}{i}", "Hull", wp, build_leo_wheel(wp, lod, side, r=0.355))
        sp_piv = (wx, 0.65 * k, -3.23 * k)
        rig.add(f"Sprocket_{label}", "Hull", sp_piv, build_sprocket(sp_piv, lod, side, scale=k))
        id_piv = (wx, 0.65 * k, 3.23 * k)
        rig.add(f"Idler_{label}", "Hull", id_piv, build_idler(id_piv, lod, side, scale=k))
        for i, rz in enumerate((-1.75 * k, 0.0, 1.75 * k)):
            rp = (wx, 1.02 * k, rz)
            rig.add(f"Roller_{label}{i}", "Hull", rp, build_roller(rp, lod, side))
        trk = Part(f"Track_{label}")
        trk.build_track(wx, lod=lod, width=0.635)
        rig.add(f"Track_{label}", "Hull", (wx, 0.0, 0.0), trk, mesh_scale=(1.0, k, k))

    rig.add("Exhaust", "Hull", (-1.78, 1.32, -3.45), None)
    rig.add("Engine_Deck", "Hull", (0.0, 1.58, -2.85), None)
    return rig


def build_asian_mbt_rig(lod=0, variant="type_99a"):
    if variant in ("type_99a", "vt_4_haider", "vt_4_vickers_mk_3"):
        return build_chinese_mbt_rig(lod, variant)
    if variant in ("type_10", "type_90"):
        return build_japanese_mbt_rig(lod, is_type10=(variant == "type_10"))
    return build_arjun_rig(lod)


ASIAN_MBT_VARIANTS = (
    "type_99a",
    "vt_4_haider",
    "vt_4_vickers_mk_3",
    "type_10",
    "type_90",
    "arjun_mk1",
)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    veh_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../godot/assets/art/vehicles"))
    os.makedirs(veh_dir, exist_ok=True)
    targets = ASIAN_MBT_VARIANTS if ("--all" in argv or not argv) else [v for v in argv if not v.startswith("-")]
    for var in targets:
        init_scene()
        out_p = os.path.join(veh_dir, f"tank__{var}.glb")
        export_vehicle(out_p, build_asian_mbt_rig(0, var), build_asian_mbt_rig(1, var))
