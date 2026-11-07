"""Tier P2.1B — Amphibious Eastern Tracked IFVs & 8x8 Wheeled IFVs (6 vehicles), modelled in Blender 5.2.

Run all 6 variants:
    blender -b -P native/tools/models/blender/build_p2_ifv_east_wheeled.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  1. ifv__bmp_3.glb         (Russian BMP-3 rear-engine amphibious IFV w/ dual 100mm 2A70 + 30mm 2A72 & bow PKTs)
  2. ifv__bmp_2.glb         (Soviet BMP-2 w/ ribbed boat glacis, flat conical turret, 30mm 2A42 & roof Konkurs ATGM)
  3. ifv__bmp_2_sarath.glb  (Indian BMP-2 Sarath w/ amphibious trim shrouds, thermal gunner hood & roof Konkurs)
  4. ifv__zbd_04a.glb       (Chinese ZBD-04A w/ add-on ceramic armor, welded Bakhcha turret, 100mm+30mm & bustle cage)
  5. ifv__vbci.glb          (French Nexter VBCI 8x8 wheeled IFV w/ Michelin XZL tyres, V-hull & Tarask 25mm turret)
  6. ifv__pandur_ii_ifv.glb (GDELS Pandur II 8x8 amphibious wheeled IFV w/ surf-beak bow, waterjets & SP30/Samson 30mm)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_p2_ifv_west import (
    build_ifv_road_wheel,
    build_ifv_sprocket,
    build_ifv_idler,
    build_ifv_roller,
    add_nato_diamond,
)

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.35, 1.15, 1.45)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# 1–4. AMPHIBIOUS EASTERN TRACKED IFVs (`bmp_3`, `bmp_2`, `bmp_2_sarath`, `zbd_04a`)
# =============================================================================

EAST_IFV_SPECS = {
    "ifv__bmp_3": {
        "style": "bmp3",
        "track_scale": 0.88, "track_x": 1.38, "track_w": 0.38,
        "wheel_r": 0.31, "wheels": [-2.18, -1.31, -0.44, 0.44, 1.31, 2.18], "rollers": [-1.25, 0.0, 1.25],
        "hull_l": 6.75, "hull_w": 2.34, "hull_h": 1.44,
        "rear_drive": True, "dual_gun": True, "turret_z": 0.18,
    },
    "ifv__bmp_2": {
        "style": "bmp2",
        "track_scale": 0.86, "track_x": 1.32, "track_w": 0.38,
        "wheel_r": 0.31, "wheels": [-2.12, -1.27, -0.42, 0.42, 1.27, 2.12], "rollers": [-1.20, 0.0, 1.20],
        "hull_l": 6.68, "hull_w": 2.20, "hull_h": 1.38,
        "rear_drive": False, "dual_gun": False, "turret_z": -0.22,
    },
    "ifv__bmp_2_sarath": {
        "style": "sarath",
        "track_scale": 0.86, "track_x": 1.32, "track_w": 0.38,
        "wheel_r": 0.31, "wheels": [-2.12, -1.27, -0.42, 0.42, 1.27, 2.12], "rollers": [-1.20, 0.0, 1.20],
        "hull_l": 6.68, "hull_w": 2.20, "hull_h": 1.38,
        "rear_drive": False, "dual_gun": False, "turret_z": -0.22,
    },
    "ifv__zbd_04a": {
        "style": "zbd04a",
        "track_scale": 0.92, "track_x": 1.42, "track_w": 0.42,
        "wheel_r": 0.32, "wheels": [-2.30, -1.38, -0.46, 0.46, 1.38, 2.30], "rollers": [-1.30, 0.0, 1.30],
        "hull_l": 7.15, "hull_w": 2.36, "hull_h": 1.50,
        "rear_drive": False, "dual_gun": True, "turret_z": -0.10,
    },
}


def build_east_ifv_rig(slug, lod=0):
    s = EAST_IFV_SPECS[slug]
    rig = VehicleRig(lod=lod)
    ts, tx, tw = s["track_scale"], s["track_x"], s["track_w"]
    hl, hw, hh = s["hull_l"] * 0.5, s["hull_w"] * 0.5, s["hull_h"]
    style = s["style"]

    hull = Part("Hull")
    # Razor-sharp amphibious boat bow & sloped upper hull!
    hull_prof = [
        (-hl, 0.52),
        (-hl + 0.25, 0.34),
        (hl - 0.95, 0.34),
        (hl + 0.22, 0.96),
        (hl + 0.14, 1.08),
        (hl - 1.65, hh),
        (-hl + 0.06, hh),
        (-hl - 0.08, hh - 0.26),
    ]
    hull.profile_x("paint", hull_prof, -hw, hw, bevel=0.016 if not lod else 0.0, ao_y=(0.34, hh + 0.4))

    # Hydrodynamic amphibious track-shroud fenders + ceramic/skirt panels
    sk_xi = tx + tw * 0.515 + 0.025
    sk_xo = sk_xi + (0.09 if style == "zbd04a" else 0.06)
    for sx in (-1, 1):
        hull.box("paint", (sx * hw, hh - 0.20, -hl + 0.06), (sx * sk_xi, hh, hl - 0.05), bevel=0.012 if not lod else 0.0)
        if not lod:
            # Characteristic corrugated BMP hydrodynamic upper fender skirt!
            for idx in range(6):
                z0 = -hl + 0.08 + idx * ((2 * hl - 0.16) / 6.0) + 0.012
                z1 = -hl + 0.08 + (idx + 1) * ((2 * hl - 0.16) / 6.0) - 0.012
                y_bot = 0.72 if style in ("bmp2", "sarath") else 0.62
                hull.box("paint", (sx * sk_xi, y_bot, z0), (sx * sk_xo, hh - 0.01, z1),
                         bevel=0.008, tint=(0.97 + 0.02 * (idx % 2),) * 3)
            if style == "sarath":
                # Indian BMP-2 Sarath enlarged amphibious fender float boxes at front & rear!
                hull.box("paint", (sx * sk_xi, 0.68, hl - 0.65), (sx * (sk_xo + 0.06), hh + 0.04, hl + 0.08), bevel=0.012)
            add_nato_diamond(hull, sx * (sk_xo + 0.004), 1.02, 0.15, sx, size=0.11)
        else:
            hull.box("paint", (sx * sk_xi, 0.66, -hl + 0.08), (sx * sk_xo, hh - 0.01, hl - 0.08))

    if not lod:
        # Ribbed BMP-1/BMP-2 aluminum engine glacis OR BMP-3 bow wave vane + twin PKT blisters!
        glacis_pitch = math.atan2(hh - 1.08, (hl - 1.65) - (hl + 0.14))
        if style in ("bmp2", "sarath"):
            with hull.frame((0.28, (hh + 1.08) * 0.5, hl - 0.78), pitch=glacis_pitch):
                for r_i in range(6):
                    rx = -0.35 + r_i * 0.14
                    hull.box("paint", (rx - 0.018, 0.0, -0.68), (rx + 0.018, 0.026, 0.68), bevel=0.004, tint=(1.04, 1.04, 1.02))
                for l_i in range(6):
                    hull.box("dark", (-0.32, 0.016, -0.52 + l_i * 0.14), (0.38, 0.030, -0.45 + l_i * 0.14))
        elif style == "bmp3":
            # BMP-3 bow wave-breaker vane + central driver + flanking bow gunner hatches + twin bow 7.62mm PKTs!
            hull.box("paint", (-hw * 0.88, 1.04, hl + 0.04), (hw * 0.88, 1.20, hl + 0.16), bevel=0.008)
            for sx in (-1, 1):
                hull.cyl("metal_dark", (sx * 0.68, 1.16, hl - 0.15), 0.016, 0.34, axis="z", seg=8)
                hull.cyl("paint", (sx * 0.62, hh, hl - 1.28), 0.22, 0.045, seg=12, bevel=0.006)
            hull.cyl("paint", (0.0, hh, hl - 1.35), 0.24, 0.05, seg=14, bevel=0.006)
        else:
            # ZBD-04A bow trim vane + right engine louvers
            hull.box("paint", (-hw * 0.90, 1.04, hl + 0.02), (hw * 0.90, 1.22, hl + 0.14), bevel=0.008)
            hull.box("dark", (0.18, hh - 0.01, hl - 1.45), (0.88, hh + 0.02, hl - 0.55))

        # Driver hatch on left for front-engine BMP-2 / ZBD-04A
        if style != "bmp3":
            hull.cyl("paint", (-0.54, hh, hl - 1.32), 0.24, 0.05, seg=14, bevel=0.006)
            for dx in (-0.11, 0.0, 0.11):
                hull.box("glass", (-0.54 + dx - 0.035, hh + 0.02, hl - 1.06), (-0.54 + dx + 0.035, hh + 0.07, hl - 1.02), tint=OPTIC_COOL)

        # Rear fuel-filled double BMP troop doors OR BMP-3 rear deck + twin waterjet ports!
        for sx in (-1, 1):
            if style == "bmp3":
                hull.tube_axis("dark", (sx * 0.68, 0.62, -hl - 0.06), (sx * 0.68, 0.62, -hl + 0.04), 0.13, 0.10, axis="z", seg=12)
                hull.box("paint", (sx * 0.06, 0.72, -hl - 0.10), (sx * 0.74, hh - 0.04, -hl + 0.02), bevel=0.010)
            else:
                # Iconic hollow fuel-tank curved BMP rear troop doors with firing ports!
                hull.box("paint", (sx * 0.05, 0.56, -hl - 0.15), (sx * 0.78, hh - 0.06, -hl + 0.02), bevel=0.016, tint=(0.94, 0.95, 0.92))
                hull.cyl("metal_dark", (sx * 0.42, 1.02, -hl - 0.17), 0.055, 0.03, axis="z", seg=10)
            hull.box("glass", (sx * (hw + 0.08), hh - 0.18, -hl - 0.02), (sx * (hw + 0.20), hh - 0.10, -hl + 0.02), tint=TAIL_RED)
            hull.cyl("glass", (sx * (hw - 0.12), 1.14, hl + 0.08), 0.055, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    # Tracks & Sprocket/Idler (BMP-3 rear drive; BMP-2 / ZBD-04A front drive!)
    wr = s["wheel_r"]
    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))
        if s["rear_drive"]:
            sp_p = (sx * tx, 0.65 * ts, -3.24 * ts)
            id_p = (sx * tx, 0.68 * ts, 3.22 * ts)
        else:
            sp_p = (sx * tx, 0.68 * ts, 3.22 * ts)
            id_p = (sx * tx, 0.65 * ts, -3.24 * ts)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_ifv_sprocket(sp_p, lod, sx, r=wr * 1.02))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_ifv_idler(id_p, lod, sx, r=wr * 0.96))
        for i, wz in enumerate(s["wheels"]):
            wp = (sx * tx, wr, wz)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_ifv_road_wheel(wp, lod, sx, r=wr))
        if not lod:
            for r_i, rz in enumerate(s["rollers"]):
                rp = (sx * tx, 1.05 * ts, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx, r=0.11))

    # Turret + Gun
    tz = s["turret_z"]
    t_piv = (0.0, hh + 0.02, tz)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, hh - 0.02, tz), 0.92, 0.06, seg=20 if not lod else 10)
    rig.add("Turret_Ring", "Hull", t_piv, ring)

    turret = Part("Turret")
    th = 0.56 if style == "zbd04a" else 0.48
    if style == "zbd04a":
        # Welded angular Chinese Bakhcha-derived turret w/ rear bustle cage
        b_pts = [(-0.62, 1.08), (0.62, 1.08), (1.02, 0.35), (0.98, -0.78), (0.76, -1.24), (-0.76, -1.24), (-0.98, -0.78), (-1.02, 0.35)]
        t_pts = [(x * 0.78, z * 0.85 + tz) for x, z in b_pts]
        turret.frustum_xz("paint", [(x, z + tz) for x, z in b_pts], t_pts, hh + 0.04, hh + 0.04 + th, bevel=0.016 if not lod else 0.0)
    else:
        # Wide low-profile conical circular Soviet BMP-2 / BMP-3 saucer turret!
        seg_t = 12 if lod else 24
        b_pts = [(1.04 * math.sin(math.tau * i / seg_t), tz + 1.06 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
        t_pts = [(0.74 * math.sin(math.tau * i / seg_t), tz + 0.76 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
        turret.frustum_xz("paint", b_pts, t_pts, hh + 0.04, hh + 0.04 + th, bevel=0.014 if not lod else 0.0)

    ty_top = hh + 0.04 + th
    if not lod:
        # Commander & gunner hatches + sights
        for sx in (-1, 1):
            turret.cyl("paint", (sx * 0.34, ty_top, tz - 0.16), 0.24, 0.05, seg=14, bevel=0.006)
        # Gunner thermal / IR sight box
        turret.box("paint", (-0.54, ty_top, tz + 0.14), (-0.24, ty_top + 0.22, tz + 0.48), bevel=0.008)
        turret.box("glass", (-0.50, ty_top + 0.04, tz + 0.475), (-0.28, ty_top + 0.18, tz + 0.49), tint=OPTIC_FLIR)
        # Commander panoramic / OU-3GA2 searchlight
        turret.cyl("paint", (0.36, ty_top + 0.05, tz + 0.12), 0.12, 0.18, seg=12)
        turret.box("glass", (0.28, ty_top + 0.10, tz + 0.23), (0.44, ty_top + 0.20, tz + 0.25), tint=OPTIC_COOL)

        if style in ("bmp2", "sarath"):
            # Iconic roof-mounted 9P135M Konkurs / Fagotto ATGM launcher tube on central pintle!
            turret.cyl("metal_dark", (0.0, ty_top, tz - 0.05), 0.045, 0.22, seg=8)
            turret.tube_axis("paint", (0.0, ty_top + 0.24, tz - 0.48), (0.0, ty_top + 0.24, tz + 0.56), 0.082, 0.068, axis="z", seg=12)
        elif style == "zbd04a":
            turret.box("metal_dark", (-0.68, hh + 0.14, tz - 1.56), (0.68, ty_top - 0.06, tz - 1.22), bevel=0.008, tint=(0.65, 0.65, 0.65))

        # 902V Tucha 3-tube smoke grenade clusters on cheeks + whip antenna (ensures height > 2.45 m!)
        for sx in (-1, 1):
            for k in range(3):
                with turret.frame((sx * 0.88, hh + 0.24 + 0.03 * k, tz + 0.22 - 0.08 * k), yaw=sx * 0.36, pitch=-0.38):
                    turret.cyl("metal_dark", (0, 0, 0), 0.034, 0.18, axis="z", seg=8)
        turret.cyl("metal_dark", (-0.58, ty_top, tz - 0.48), 0.030, 0.12, seg=8)
        turret.cyl("dark", (-0.58, ty_top + 0.12, tz - 0.48), 0.011, 1.15, seg=6)

    rig.add("Turret", "Hull", t_piv, turret)

    # Gun (`100mm 2A70 + 30mm 2A72` dual mount OR `30mm 2A42` autocannon)
    g_piv = (0.0, hh + 0.04 + th * 0.48, tz + 0.88)
    gy, gz = g_piv[1], g_piv[2]
    gun = Part("Gun")
    gun.box("paint", (-0.24, gy - 0.14, gz - 0.22), (0.24, gy + 0.14, gz + 0.20), bevel=0.010 if not lod else 0.0)
    if s["dual_gun"]:
        # Unmistakable BMP-3 / ZBD-04A side-by-side 100mm 2A70 rifled launcher + 30mm 2A72 autocannon braced together!
        gun.cyl("paint", (-0.065, gy, gz + 0.18), 0.072, 2.15, axis="z", seg=14)
        gun.tube_axis("metal_dark", (-0.065, gy, gz + 2.28), (-0.065, gy, gz + 2.38), 0.080, 0.052, axis="z", seg=14)
        gun.cyl("metal_dark", (0.085, gy, gz + 0.18), 0.028, 2.32, axis="z", seg=10)
        if not lod:
            for bz in (0.95, 1.75):
                gun.box("metal_dark", (-0.11, gy - 0.045, gz + bz), (0.12, gy + 0.045, gz + bz + 0.06), bevel=0.004)
        muz_pt = (-0.065, gy, gz + 2.38)
    else:
        # BMP-2 30mm 2A42 ribbed barrel + double-baffle slotted muzzle brake
        gun.cyl("paint", (0.0, gy, gz + 0.18), 0.055, 0.55, axis="z", seg=12)
        gun.cyl("metal_dark", (0.0, gy, gz + 0.73), 0.028, 1.55, axis="z", seg=10)
        gun.box("metal_dark", (-0.045, gy - 0.04, gz + 2.26), (0.045, gy + 0.04, gz + 2.40), bevel=0.005)
        muz_pt = (0.0, gy, gz + 2.40)

    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 5–6. 8x8 WHEELED IFVs (`ifv__vbci`, `ifv__pandur_ii_ifv`)
# =============================================================================

WHEELED_IFV_SPECS = {
    "ifv__vbci": {
        "style": "vbci",
        "tyre_r": 0.58, "tyre_w": 0.39, "wheel_x": 1.28,
        "axles_z": [-2.35, -0.88, 0.88, 2.35],
        "hull_l": 7.65, "hull_w": 2.98, "hull_h": 2.18,
        "turret_x": 0.18, "turret_z": 0.15, "turret_h": 0.56,
        "gun_len": 1.95, "gun_cal": 0.032, "atgm": None,
    },
    "ifv__pandur_ii_ifv": {
        "style": "pandur",
        "tyre_r": 0.54, "tyre_w": 0.37, "wheel_x": 1.18,
        "axles_z": [-2.22, -0.82, 0.82, 2.22],
        "hull_l": 7.35, "hull_w": 2.68, "hull_h": 1.98,
        "turret_x": 0.0, "turret_z": -0.05, "turret_h": 0.52,
        "gun_len": 2.15, "gun_cal": 0.036, "atgm": "spike_right",
    },
}


def build_wheeled_ifv_rig(slug, lod=0):
    s = WHEELED_IFV_SPECS[slug]
    rig = VehicleRig(lod=lod)
    tr, tw, wx = s["tyre_r"], s["tyre_w"], s["wheel_x"]
    hl, hw, hh = s["hull_l"] * 0.5, s["hull_w"] * 0.5, s["hull_h"]
    style = s["style"]

    hull = Part("Hull")
    # 1. Mine-resistant sloped V-bottom lower hull tub (narrow between wheels, sweeping up flush into bow!)
    tub_w = wx - tw * 0.55 - 0.06
    belly_prof = [
        (-hl + 0.20, 1.22),
        (-hl + 0.55, 0.56),
        (hl - 1.05, 0.56),
        (hl + 0.12, 1.46 if style == "pandur" else 1.54),
        (hl - 0.85, 1.22),
    ]
    hull.profile_x("paint", belly_prof, -tub_w, tub_w, bevel=0.016 if not lod else 0.0, tint=(0.82, 0.83, 0.80))
    # Differential axle housings connecting left/right wheel hubs
    for az in s["axles_z"]:
        hull.cyl("metal_dark", (-wx, tr, az), 0.085, wx * 2.0, axis="x", seg=8)

    # 2. Upper armored 8x8 casemate body above wheel arches + surf-beak bow!
    upper_prof = [
        (-hl, 1.24),
        (-hl + 0.15, 1.18),
        (hl - 0.85, 1.18),
        (hl + 0.18, 1.48 if style == "pandur" else 1.56),
        (hl + 0.06, 1.66 if style == "pandur" else 1.74),
        (hl - 1.35, hh),
        (-hl + 0.08, hh),
    ]
    hull.profile_x("paint", upper_prof, -hw * 0.82, hw * 0.82, bevel=0.020 if not lod else 0.0, ao_y=(0.55, hh + 0.3))
    # Sloped modular ballistic side armor modules above the 4 wheel wells!
    for sx in (-1, 1):
        hull.wedge("paint", (sx * hw, 1.24, -hl + 0.08), (sx * (hw * 0.82), hh, hl - 0.25),
                   axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.014 if not lod else 0.0)
        # Lower armored skirts between axles (leaving clean wheel-arch cutouts around each tyre!)
        z_segs = [(-hl + 0.05, s["axles_z"][0] - tr - 0.10),
                  (s["axles_z"][1] + tr + 0.10, s["axles_z"][2] - tr - 0.10),
                  (s["axles_z"][3] + tr + 0.10, hl - 0.15)]
        for z0, z1 in z_segs:
            if z1 > z0 + 0.08:
                hull.box("paint", (sx * (hw - 0.12), 0.78, z0), (sx * hw, 1.26, z1), bevel=0.010 if not lod else 0.0)

        if not lod:
            # Modular bolt-on armor tiles onVBCI / Pandur flanks + NATO diamond
            for m_i in range(5):
                mz0 = -hl + 0.20 + m_i * ((2 * hl - 0.65) / 5.0)
                mz1 = mz0 + ((2 * hl - 0.65) / 5.0) - 0.04
                hull.box("paint", (sx * (hw - 0.02), 1.30, mz0), (sx * (hw + 0.035), hh - 0.18, mz1),
                         bevel=0.008, tint=(0.97 + 0.02 * (m_i % 2),) * 3)
            add_nato_diamond(hull, sx * (hw + 0.039), 1.62, 0.0, sx, size=0.13)

            # Pandur II twin rear amphibious waterjets!
            if style == "pandur":
                hull.tube_axis("dark", (sx * 0.78, 0.92, -hl - 0.04), (sx * 0.78, 0.92, -hl + 0.06), 0.12, 0.09, axis="z", seg=10)

            # Headlight clusters + mirrors + taillights
            hull.box("paint", (sx * (hw * 0.68), 1.48, hl - 0.02), (sx * (hw * 0.86), 1.66, hl + 0.12), bevel=0.008)
            hull.cyl("glass", (sx * (hw * 0.77), 1.57, hl + 0.12), 0.048, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.box("glass", (sx * (hw * 0.76), hh - 0.24, -hl - 0.02), (sx * (hw * 0.90), hh - 0.14, -hl + 0.02), tint=TAIL_RED)

    if not lod:
        # Right front engine louvers + left driver hatch w/ 3 periscopes + rear hydraulic infantry ramp
        hull.box("dark", (0.16, hh - 0.08, hl - 1.32), (hw * 0.72, hh + 0.01, hl - 0.42))
        hull.cyl("paint", (-0.48, hh, hl - 1.18), 0.25, 0.055, seg=14, bevel=0.008)
        for dx in (-0.12, 0.0, 0.12):
            hull.box("glass", (-0.48 + dx - 0.035, hh + 0.02, hl - 0.92), (-0.48 + dx + 0.035, hh + 0.075, hl - 0.88), tint=OPTIC_COOL)
        hull.box("paint", (-hw * 0.64, 0.82, -hl - 0.08), (hw * 0.64, hh - 0.12, -hl + 0.02), bevel=0.014, tint=(0.92, 0.92, 0.90))
        hull.box("paint", (-0.52, hh, -hl + 0.35), (0.52, hh + 0.05, -hl + 1.45), bevel=0.008, tint=(0.94, 0.94, 0.92))

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    # 3. 8x8 Sculpted Off-Road Tyres (`Wheel_L0..L3`, `Wheel_R0..R3` — NO Track_L/R!)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(s["axles_z"]):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style="western"))

    # 4. Compact 1-Man / Unmanned RWS IFV Turret (`Turret` + `Gun` + `Muzzle`)
    tur_x, tur_z, th = s["turret_x"], s["turret_z"], s["turret_h"]
    t_piv = (tur_x, hh + 0.02, tur_z)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (tur_x, hh - 0.02, tur_z), 0.64, 0.06, seg=18 if not lod else 10)
    rig.add("Turret_Ring", "Hull", t_piv, ring)

    turret = Part("Turret")
    b_pts = [(-0.46, 0.82), (0.46, 0.82), (0.74, 0.20), (0.68, -0.82), (-0.68, -0.82), (-0.74, 0.20)]
    turret.frustum_xz(
        "paint",
        [(x + tur_x, z + tur_z) for x, z in b_pts],
        [(x * 0.76 + tur_x, z * 0.82 + tur_z) for x, z in b_pts],
        hh + 0.04, hh + 0.04 + th, bevel=0.016 if not lod else 0.0,
    )
    ty_top = hh + 0.04 + th
    if not lod:
        turret.box("paint", (tur_x - 0.44, ty_top, tur_z + 0.08), (tur_x - 0.14, ty_top + 0.24, tur_z + 0.44), bevel=0.008)
        turret.box("glass", (tur_x - 0.40, ty_top + 0.04, tur_z + 0.435), (tur_x - 0.18, ty_top + 0.19, tur_z + 0.45), tint=OPTIC_FLIR)
        turret.cyl("paint", (tur_x + 0.22, ty_top, tur_z - 0.20), 0.12, 0.12, seg=12)
        turret.box("paint", (tur_x + 0.08, ty_top + 0.12, tur_z - 0.34), (tur_x + 0.36, ty_top + 0.32, tur_z - 0.06), bevel=0.008)
        turret.box("glass", (tur_x + 0.12, ty_top + 0.16, tur_z - 0.065), (tur_x + 0.32, ty_top + 0.28, tur_z - 0.05), tint=OPTIC_COOL)
        if s.get("atgm") == "spike_right":
            turret.box("paint", (tur_x + 0.72, hh + 0.18, tur_z - 0.48), (tur_x + 1.00, ty_top - 0.04, tur_z + 0.42), bevel=0.010)
            for dy in (-0.06, 0.06):
                turret.cyl("metal_dark", (tur_x + 0.86, hh + 0.34 + dy, tur_z + 0.40), 0.05, 0.10, axis="z", seg=8)
        for sx in (-1, 1):
            for k in range(3):
                with turret.frame((tur_x + sx * 0.62, hh + 0.24, tur_z + 0.38 - k * 0.08), yaw=sx * 0.30, pitch=-0.38):
                    turret.cyl("metal_dark", (0, 0, 0), 0.030, 0.16, axis="z", seg=8)
        turret.cyl("dark", (tur_x - 0.45, ty_top, tur_z - 0.58), 0.011, 0.95, seg=6)

    rig.add("Turret", "Hull", t_piv, turret)

    g_piv = (tur_x, hh + 0.04 + th * 0.48, tur_z + 0.68)
    gy, gz = g_piv[1], g_piv[2]
    gun = Part("Gun")
    cal, glen = s["gun_cal"], s["gun_len"]
    gun.box("paint", (tur_x - 0.18, gy - 0.13, gz - 0.18), (tur_x + 0.18, gy + 0.13, gz + 0.18), bevel=0.010 if not lod else 0.0)
    gun.cyl("paint", (tur_x, gy, gz + 0.16), cal * 1.75, glen * 0.30, axis="z", seg=12)
    gun.cyl("metal_dark", (tur_x, gy, gz + 0.16 + glen * 0.30), cal, glen * 0.70, axis="z", seg=10)
    muz_z = gz + 0.16 + glen
    gun.tube_axis("metal_dark", (tur_x, gy, muz_z - 0.03), (tur_x, gy, muz_z + 0.10), cal * 1.5, cal * 0.75, axis="z", seg=10)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", (tur_x, gy, muz_z + 0.10), None)
    return rig


def export_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for slug in EAST_IFV_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_east_ifv_rig(slug, 0),
            build_east_ifv_rig(slug, 1),
            turret_offset=(3.9, 0.0, -0.2),
            ring_radius=0.80,
        )
    for slug in WHEELED_IFV_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_wheeled_ifv_rig(slug, 0),
            build_wheeled_ifv_rig(slug, 1),
            turret_offset=(4.0, 0.0, 0.1),
            ring_radius=0.56,
        )


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    out_dir = os.path.join(repo_root, "native", "godot", "assets", "art", "vehicles")
    only = None
    for i, a in enumerate(argv):
        if a == "--only" and i + 1 < len(argv):
            only = argv[i + 1]
    export_all(out_dir, only=only)


if __name__ == "__main__":
    main()
