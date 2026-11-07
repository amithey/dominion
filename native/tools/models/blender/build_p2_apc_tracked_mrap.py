"""Tier P2.3 — Tracked APCs (M113 / FV432 / Ajax / BMP-1) & Tactical 4x4 MRAPs (16 vehicles), modelled in Blender 5.2.

Run all 16 variants:
    blender -b -P native/tools/models/blender/build_p2_apc_tracked_mrap.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  Tracked APCs (11):
    1. apc__m113as4.glb              (Australian stretched 6-wheel M113AS4 w/ external fuel panniers & T50 turret)
    2. apc__m113_fahd.glb            (M113A2 / Fahd 5-wheel boxy aluminum APC w/ trim board & shielded M2HB)
    3. apc__saad_m113.glb            (Pakistani Saad 6-wheel up-armoured M113 w/ spaced bow & shielded 12.7mm)
    4. apc__k200a1.glb               (ROK K200A1 5-wheel KIFV w/ spaced-laminate bow & shielded K6 cupola)
    5. apc__bulldog_fv432.glb        (British FV432 Mk 3 Bulldog w/ side ERA blocks, right exhaust & Enforcer RWS)
    6. apc__type_73.glb              (JGSDF Type 73 5-wheel APC w/ bow MG blister & shielded M2HB cupola)
    7. apc__kaplan_harimau_apc.glb   (FNSS/Pindad Kaplan 6-wheel modern tracked APC w/ RWS)
    8. apc__ares.glb                 (British Ajax-family Ares 7-wheel tracked recon APC w/ Protector RWS)
    9. apc__athena.glb               (British Ajax-family Athena 7-wheel C2 command post APC w/ raised roof & masts)
   10. apc__bmp_1.glb                (Soviet BMP-1 w/ ribbed boat hull, 73mm 2A28 Grom & Malyutka ATGM rail)
   11. apc__bmp_2_btr_80_captured.glb(Captured field-modified BMP-2 w/ stowage cage, tactical chevrons & 30mm 2A42)
  Tactical 4x4 Protected Vehicles & MRAPs (5):
   12. apc__serval.glb               (French VBMR-L Serval 4x4 multi-role armoured APC w/ Hornet RWS)
   13. apc__humvee_captured.glb      (Up-armoured M1151 HMMWV 4x4 w/ 7-slot grille, slant-back & OGPK .50 cal turret)
   14. bushmaster__bushmaster.glb    (Australian Thales Bushmaster PMV 4x4 MRAP w/ V-hull, side bins & R400 RWS)
   15. bushmaster__jltv_pera.glb     (Oshkosh JLTV / 'Pera' 4x4 tactical vehicle w/ sculpted hood & CROWS/Katlanit)
   16. bushmaster__sandcat_tigris.glb(Plasan SandCat / Tigris 4x4 faceted composite patrol MRAP w/ RWS)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import (
    build_ifv_road_wheel,
    build_ifv_sprocket,
    build_ifv_idler,
    build_ifv_roller,
    add_nato_diamond,
)
from build_p2_ifv_east_wheeled import build_east_ifv_rig

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.32, 1.10, 1.40)
GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# 1–9. TRACKED APC BUILDER (M113 / FV432 / K200A1 / KAPLAN / AJAX ARES & ATHENA)
# =============================================================================

TRACKED_APC_SPECS = {
    "apc__m113as4": {
        "style": "m113_stretch", "ts": 0.78, "tx": 1.16, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.85, -1.11, -0.37, 0.37, 1.11, 1.85], "rollers": [],
        "hl": 5.66, "hw": 2.12, "hh": 1.84, "turret": "t50", "rear_fuel": True,
    },
    "apc__m113_fahd": {
        "style": "m113_box", "ts": 0.70, "tx": 1.14, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.56, -0.78, 0.0, 0.78, 1.56], "rollers": [],
        "hl": 4.92, "hw": 2.10, "hh": 1.82, "turret": "cupola_50", "trim_vane": True,
    },
    "apc__saad_m113": {
        "style": "spaced_m113", "ts": 0.78, "tx": 1.18, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.85, -1.11, -0.37, 0.37, 1.11, 1.85], "rollers": [],
        "hl": 5.62, "hw": 2.16, "hh": 1.84, "turret": "rws_50",
    },
    "apc__k200a1": {
        "style": "spaced_m113", "ts": 0.72, "tx": 1.18, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.62, -0.81, 0.0, 0.81, 1.62], "rollers": [],
        "hl": 5.38, "hw": 2.18, "hh": 1.82, "turret": "cupola_50", "trim_vane": True,
    },
    "apc__bulldog_fv432": {
        "style": "fv432", "ts": 0.72, "tx": 1.18, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.60, -0.80, 0.0, 0.80, 1.60], "rollers": [-0.85, 0.85],
        "hl": 5.25, "hw": 2.18, "hh": 1.88, "turret": "rws_50", "era": True,
    },
    "apc__type_73": {
        "style": "type73", "ts": 0.72, "tx": 1.20, "tw": 0.38, "wr": 0.30,
        "wheels": [-1.64, -0.82, 0.0, 0.82, 1.64], "rollers": [],
        "hl": 5.50, "hw": 2.22, "hh": 1.78, "turret": "cupola_50",
    },
    "apc__kaplan_harimau_apc": {
        "style": "modern_apc", "ts": 0.86, "tx": 1.34, "tw": 0.45, "wr": 0.32,
        "wheels": [-2.10, -1.26, -0.42, 0.42, 1.26, 2.10], "rollers": [-1.15, 0.0, 1.15],
        "hl": 6.60, "hw": 2.24, "hh": 1.72, "turret": "rws_50",
    },
    "apc__ares": {
        "style": "ajax", "ts": 0.94, "tx": 1.46, "tw": 0.50, "wr": 0.34,
        "wheels": [-2.40, -1.60, -0.80, 0.0, 0.80, 1.60, 2.40], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.30, "hw": 2.42, "hh": 1.82, "turret": "rws_50",
    },
    "apc__athena": {
        "style": "ajax", "ts": 0.94, "tx": 1.46, "tw": 0.50, "wr": 0.34,
        "wheels": [-2.40, -1.60, -0.80, 0.0, 0.80, 1.60, 2.40], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.30, "hw": 2.42, "hh": 1.82, "turret": "rws_50", "c2_roof": True,
    },
}


def _add_apc_rws_or_t50(rig, ttype, tx, hh, tz, lod):
    t_piv = (tx, hh + 0.02, tz)
    turret = Part("Turret")
    gun = Part("Gun")
    if ttype == "t50":
        seg = 10 if lod else 18
        b_pts = [(tx + 0.52 * math.sin(math.tau * i / seg), tz + 0.54 * math.cos(math.tau * i / seg)) for i in range(seg)]
        t_pts = [(tx + 0.40 * math.sin(math.tau * i / seg), tz + 0.42 * math.cos(math.tau * i / seg)) for i in range(seg)]
        turret.frustum_xz("paint", b_pts, t_pts, hh + 0.02, hh + 0.44, bevel=0.010 if not lod else 0.0)
        g_piv = (tx, hh + 0.26, tz + 0.44)
    elif ttype == "cupola_50":
        turret.cyl("paint", (tx, hh, tz), 0.32, 0.10, seg=14, bevel=0.006)
        for sx in (-1, 1):
            turret.box("paint", (tx + sx * 0.22, hh + 0.10, tz - 0.20), (tx + sx * 0.28, hh + 0.44, tz + 0.26), bevel=0.006)
        turret.box("paint", (tx - 0.26, hh + 0.10, tz + 0.22), (tx + 0.26, hh + 0.46, tz + 0.28), bevel=0.006)
        g_piv = (tx, hh + 0.34, tz + 0.18)
    else:
        turret.cyl("metal_dark", (tx, hh, tz), 0.28, 0.08, seg=14)
        turret.box("paint", (tx - 0.18, hh + 0.08, tz - 0.18), (tx + 0.18, hh + 0.44, tz + 0.20), bevel=0.010 if not lod else 0.0)
        turret.box("paint", (tx + 0.18, hh + 0.14, tz - 0.12), (tx + 0.40, hh + 0.38, tz + 0.22), bevel=0.008 if not lod else 0.0)
        if not lod:
            turret.box("glass", (tx + 0.21, hh + 0.18, tz + 0.215), (tx + 0.37, hh + 0.34, tz + 0.23), tint=OPTIC_FLIR)
        g_piv = (tx, hh + 0.34, tz + 0.14)

    gy, gz = g_piv[1], g_piv[2]
    gun.box("metal_dark", (tx - 0.07, gy - 0.07, gz - 0.16), (tx + 0.07, gy + 0.07, gz + 0.26), bevel=0.005 if not lod else 0.0)
    gun.cyl("metal_dark", (tx, gy, gz + 0.26), 0.032, 0.32, axis="z", seg=10)
    gun.cyl("metal_dark", (tx, gy, gz + 0.58), 0.018, 0.56, axis="z", seg=10)
    muz_pt = (tx, gy, gz + 1.20)
    gun.tube_axis("metal_dark", (tx, gy, gz + 1.12), muz_pt, 0.026, 0.014, seg=8)

    rig.add("Turret", "Hull", t_piv, turret)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)


def build_tracked_apc_rig(slug, lod=0):
    s = TRACKED_APC_SPECS[slug]
    rig = VehicleRig(lod=lod)
    ts, tx, tw, wr = s["ts"], s["tx"], s["tw"], s["wr"]
    hl, hw, hh = s["hl"] * 0.5, s["hw"] * 0.5, s["hh"]
    style = s["style"]

    hull = Part("Hull")
    # Classic boxy flat-sided M113/FV432 OR sloped modern Ajax/Kaplan hull!
    if style in ("m113_box", "m113_stretch", "fv432"):
        prof = [
            (-hl, 0.52), (-hl + 0.18, 0.36), (hl - 0.65, 0.36),
            (hl + 0.08, 1.05), (hl - 0.72, hh), (-hl + 0.04, hh), (-hl - 0.04, 0.62),
        ]
    else:
        prof = [
            (-hl, 0.54), (-hl + 0.22, 0.36), (hl - 0.82, 0.36),
            (hl + 0.14, 1.04), (hl - 1.25, hh), (-hl + 0.06, hh), (-hl - 0.06, hh - 0.26),
        ]
    hull.profile_x("paint", prof, -hw, hw, bevel=0.018 if not lod else 0.0, ao_y=(0.36, hh + 0.3))

    sk_xi = tx + tw * 0.515 + 0.025
    sk_xo = sk_xi + (0.12 if s.get("era") else 0.065)
    for sx in (-1, 1):
        hull.box("paint", (sx * hw, hh - 0.32, -hl + 0.04), (sx * sk_xi, hh, hl - 0.08), bevel=0.012 if not lod else 0.0)
        if not lod:
            y_bot = 0.82 if style in ("m113_box", "m113_stretch", "type73") else 0.58
            for idx in range(5):
                z0 = -hl + 0.08 + idx * ((2 * hl - 0.16) / 5.0) + 0.012
                z1 = z0 + ((2 * hl - 0.16) / 5.0) - 0.024
                hull.box("paint", (sx * sk_xi, y_bot, z0), (sx * sk_xo, hh - 0.02, z1), bevel=0.008)
                if s.get("era"):
                    hull.box("paint", (sx * sk_xo, y_bot + 0.08, z0 + 0.02), (sx * (sk_xo + 0.07), hh - 0.12, z1 - 0.02),
                             bevel=0.008, tint=(0.92, 0.94, 0.90))
            add_nato_diamond(hull, sx * ((sk_xo + 0.074) if s.get("era") else (sk_xo + 0.004)), 1.20, 0.0, sx, size=0.12)
        else:
            hull.box("paint", (sx * sk_xi, 0.72, -hl + 0.08), (sx * sk_xo, hh - 0.02, hl - 0.08))

    if s.get("c2_roof"):
        # Athena C2 raised command-post superstructure at rear!
        hull.box("paint", (-hw * 0.94, hh, -hl + 0.12), (hw * 0.94, hh + 0.38, 0.25), bevel=0.018 if not lod else 0.0)

    if not lod:
        if style == "fv432":
            # Signature British FV432 Bulldog large cylindrical silencer/exhaust pipe along right roof edge!
            hull.pipe("metal_dark", (sk_xi - 0.08, hh + 0.12, -0.45), (sk_xi - 0.08, hh + 0.12, 1.35), 0.11, seg=12)
        if s.get("rear_fuel"):
            # M113A3 / M113AS4 twin external armored rear fuel panniers flanking ramp!
            for sx in (-1, 1):
                hull.box("paint", (sx * 0.68, 0.85, -hl - 0.28), (sx * (hw - 0.04), hh - 0.08, -hl + 0.02), bevel=0.012)
        if s.get("trim_vane"):
            hull.box("paint", (-hw * 0.86, 1.10, hl - 0.04), (hw * 0.86, 1.48, hl + 0.08), bevel=0.008, tint=(0.92, 0.93, 0.90))
        if style == "type73":
            hull.dome("paint", (-0.52, 1.36, hl - 0.32), 0.16, 0.10, seg=10)
            hull.cyl("metal_dark", (-0.52, 1.40, hl - 0.24), 0.015, 0.28, axis="z", seg=8)

        # Right front engine grille + left driver hatch + rear ramp + antennas
        hull.box("dark", (0.14, hh - 0.12, hl - 1.10), (hw * 0.82, hh + 0.01, hl - 0.35))
        hull.cyl("paint", (-0.50, hh, hl - 1.05), 0.24, 0.05, seg=14, bevel=0.006)
        hull.box("paint", (-0.64, 0.56, -hl - 0.08), (0.64, hh - 0.12, -hl + 0.02), bevel=0.012, tint=(0.92, 0.92, 0.90))
        roof_y = hh + (0.38 if s.get("c2_roof") else 0.0)
        for sx in (-1, 1):
            hull.cyl("glass", (sx * (hw - 0.14), 1.36, hl + 0.04), 0.048, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.cyl("dark", (sx * (hw - 0.15), roof_y, -hl + 0.35), 0.011, 1.15, seg=6)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))
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

    tur_x = 0.24 if style not in ("ajax", "modern_apc") else 0.28
    tur_z = 0.45 if s.get("c2_roof") else 0.12
    _add_apc_rws_or_t50(rig, s["turret"], tur_x, hh, tur_z, lod)
    return rig


# =============================================================================
# 10. SOVIET BMP-1 (`apc__bmp_1`)
# =============================================================================

def build_bmp1_rig(lod=0):
    """Authentic Soviet BMP-1: ribbed boat hull + low conical 1-man turret + 73mm 2A28 Grom + Malyutka ATGM rail!"""
    rig = build_east_ifv_rig("ifv__bmp_2", lod=lod)
    # Replace Turret & Gun with the smaller 1-man BMP-1 turret + short thick 73mm Grom + 9M14 Malyutka missile!
    hh = 1.38
    tz = -0.15
    rig.nodes = [n for n in rig.nodes if n["name"] not in ("Turret_Ring", "Turret", "Gun", "Muzzle")]
    for k in ("Turret_Ring", "Turret", "Gun", "Muzzle"):
        rig.pivots.pop(k, None)

    t_piv = (0.0, hh + 0.02, tz)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, hh - 0.02, tz), 0.72, 0.05, seg=18 if not lod else 10)
    rig.add("Turret_Ring", "Hull", t_piv, ring)

    turret = Part("Turret")
    seg_t = 12 if lod else 22
    b_pts = [(0.80 * math.sin(math.tau * i / seg_t), tz + 0.82 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
    t_pts = [(0.54 * math.sin(math.tau * i / seg_t), tz + 0.56 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
    turret.frustum_xz("paint", b_pts, t_pts, hh + 0.03, hh + 0.45, bevel=0.012 if not lod else 0.0)
    if not lod:
        turret.cyl("paint", (0.0, hh + 0.45, tz - 0.10), 0.25, 0.05, seg=14, bevel=0.006)
        turret.cyl("paint", (0.28, hh + 0.45, tz + 0.16), 0.09, 0.14, seg=10)
        turret.cyl("dark", (-0.42, hh + 0.45, tz - 0.38), 0.011, 1.15, seg=6)
    rig.add("Turret", "Hull", t_piv, turret)

    g_piv = (0.0, hh + 0.24, tz + 0.68)
    gy, gz = g_piv[1], g_piv[2]
    gun = Part("Gun")
    gun.box("paint", (-0.18, gy - 0.10, gz - 0.15), (0.18, gy + 0.10, gz + 0.15), bevel=0.008 if not lod else 0.0)
    gun.cyl("paint", (0.0, gy, gz + 0.14), 0.062, 1.28, axis="z", seg=12, r2=0.048)
    muz_pt = (0.0, gy, gz + 1.48)
    gun.tube_axis("metal_dark", (0.0, gy, gz + 1.38), muz_pt, 0.052, 0.036, seg=12)
    if not lod:
        # Unmistakable 9M14 Malyutka ('Sagger') wire-guided ATGM mounted on launch rail above 73mm barrel!
        gun.box("metal_dark", (-0.02, gy + 0.06, gz + 0.25), (0.02, gy + 0.13, gz + 0.85))
        gun.cyl("paint", (0.0, gy + 0.16, gz + 0.28), 0.062, 0.56, axis="z", seg=10)
        gun.cyl("paint", (0.0, gy + 0.16, gz + 0.84), 0.062, 0.22, axis="z", seg=10, r2=0.012)
        for a_f in (0.0, math.pi * 0.5):
            with gun.frame((0.0, gy + 0.16, gz + 0.36), roll=a_f):
                gun.box("paint", (-0.14, -0.008, -0.08), (0.14, 0.008, 0.08))
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 12–16. TACTICAL 4x4 PROTECTED VEHICLES & MRAPs (5 vehicles)
# =============================================================================

MRAP_4X4_SPECS = {
    "apc__serval": {
        "style": "serval", "wb": 3.55, "wx": 1.06, "tr": 0.54, "tw": 0.36,
        "hl": 6.45, "hw": 2.48, "hh": 2.38, "rws": "rws_50",
    },
    "apc__humvee_captured": {
        "style": "humvee", "wb": 3.30, "wx": 0.96, "tr": 0.47, "tw": 0.32,
        "hl": 4.92, "hw": 2.18, "hh": 1.88, "rws": "ogpk",
    },
    "bushmaster__bushmaster": {
        "style": "bushmaster", "wb": 3.90, "wx": 1.06, "tr": 0.55, "tw": 0.37,
        "hl": 7.15, "hw": 2.48, "hh": 2.46, "rws": "rws_50",
    },
    "bushmaster__jltv_pera": {
        "style": "jltv", "wb": 3.60, "wx": 1.04, "tr": 0.53, "tw": 0.36,
        "hl": 5.45, "hw": 2.46, "hh": 2.18, "rws": "rws_50", "idf": True,
    },
    "bushmaster__sandcat_tigris": {
        "style": "sandcat", "wb": 3.25, "wx": 0.98, "tr": 0.48, "tw": 0.33,
        "hl": 5.35, "hw": 2.26, "hh": 2.16, "rws": "rws_50", "idf": True,
    },
}


def build_mrap_4x4_rig(slug, lod=0):
    s = MRAP_4X4_SPECS[slug]
    rig = VehicleRig(lod=lod)
    wb_h = s["wb"] * 0.5
    wx, tr, tw = s["wx"], s["tr"], s["tw"]
    hl, hw, hh = s["hl"] * 0.5, s["hw"] * 0.5, s["hh"]
    style = s["style"]

    hull = Part("Hull")
    # V-hull armoured belly & axle housings
    tub_w = wx - tw * 0.58 - 0.04
    belly_prof = [(-hl + 0.25, 1.06), (-wb_h + 0.20, 0.54), (wb_h - 0.20, 0.54), (hl - 0.15, 1.06)]
    hull.profile_x("paint", belly_prof, -tub_w, tub_w, bevel=0.014 if not lod else 0.0, tint=(0.82, 0.83, 0.80))
    for az in (-wb_h, wb_h):
        hull.cyl("metal_dark", (-wx, tr, az), 0.075, wx * 2.0, axis="x", seg=8)

    if style == "humvee":
        # Iconic Up-Armoured M1151 HMMWV: wide flat hood, vertical 7-slot grille, 4 armored doors & slant-back hatch!
        hull.box("paint", (-hw, 0.98, 0.45), (hw, 1.38, hl), bevel=0.018 if not lod else 0.0)
        cab_prof = [(-hl, 1.02), (0.48, 1.02), (0.48, 1.38), (0.20, hh), (-1.15, hh), (-hl, 1.36)]
        hull.profile_x("paint", cab_prof, -hw, hw, bevel=0.018 if not lod else 0.0, ao_y=(0.6, hh))
        if not lod:
            for k in range(7):
                gx = -0.36 + k * 0.12
                hull.box("dark", (gx - 0.03, 1.06, hl - 0.02), (gx + 0.03, 1.32, hl + 0.02))
            hull.box("dark", (-0.52, 1.37, 0.85), (0.52, 1.40, 1.65))
            for sx in (-1, 1):
                hull.box("glass", (sx * 0.08, 1.44, 0.28), (sx * (hw - 0.14), hh - 0.08, 0.42), tint=GLASS_ARMOUR)
                for dz in (-0.35, -1.02):
                    hull.box("glass", (sx * (hw - 0.02), 1.44, dz - 0.22), (sx * (hw + 0.02), hh - 0.10, dz + 0.22), tint=GLASS_ARMOUR)
                add_idf_chevron_x(hull, sx * (hw + 0.004), 1.22, -0.35, sx, arm_len=0.15, mode="down")
    elif style == "bushmaster":
        # Thales Bushmaster PMV: long monocoque V-hull troop body w/ angled external side stowage bins!
        hood_z = hl - 1.35
        hull.box("paint", (-hw * 0.88, 1.12, hood_z), (hw * 0.88, 1.76, hl), bevel=0.020 if not lod else 0.0)
        cab_prof = [(-hl, 1.18), (hood_z, 1.18), (hood_z, 1.76), (hood_z - 0.38, hh), (-hl + 0.08, hh)]
        hull.profile_x("paint", cab_prof, -hw * 0.88, hw * 0.88, bevel=0.022 if not lod else 0.0, ao_y=(0.6, hh))
        for sx in (-1, 1):
            hull.wedge("paint", (sx * hw, 1.18, -hl + 0.10), (sx * (hw * 0.88), 1.78, hood_z),
                       axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.012 if not lod else 0.0)
            if not lod:
                hull.box("glass", (sx * 0.08, 1.84, hood_z - 0.26), (sx * (hw * 0.78), hh - 0.10, hood_z - 0.08), tint=GLASS_ARMOUR)
                for w_i in range(4):
                    wz = -hl + 0.65 + w_i * 0.95
                    hull.box("glass", (sx * (hw * 0.87), 1.92, wz - 0.18), (sx * (hw * 0.90), hh - 0.18, wz + 0.18), tint=GLASS_ARMOUR)
                add_nato_diamond(hull, sx * (hw + 0.004), 1.48, -0.5, sx, size=0.13)
    else:
        # Oshkosh JLTV ('Pera') / Plasan SandCat ('Tigris') / Arquus Serval 4x4!
        hood_z = hl - 1.35
        hull.box("paint", (-hw * 0.86, 1.08, hood_z), (hw * 0.86, 1.66, hl), bevel=0.020 if not lod else 0.0)
        rear_bed = style == "jltv"
        cab_end = -hl + 1.05 if rear_bed else -hl + 0.06
        cab_prof = [(cab_end, 1.12), (hood_z, 1.12), (hood_z, 1.66), (hood_z - 0.36, hh), (cab_end, hh)]
        hull.profile_x("paint", cab_prof, -hw * 0.94, hw * 0.94, bevel=0.022 if not lod else 0.0, ao_y=(0.6, hh))
        if rear_bed:
            hull.box("paint", (-hw * 0.92, 1.12, -hl), (hw * 0.92, 1.68, cab_end + 0.04), bevel=0.016 if not lod else 0.0)
        if not lod:
            hull.box("dark", (-hw * 0.58, 1.18, hl - 0.02), (hw * 0.58, 1.56, hl + 0.03))
            for sx in (-1, 1):
                hull.box("glass", (sx * 0.08, 1.72, hood_z - 0.25), (sx * (hw * 0.82), hh - 0.10, hood_z - 0.08), tint=GLASS_ARMOUR)
                for dz in (hood_z - 0.72, hood_z - 1.55):
                    if dz > cab_end + 0.25:
                        hull.box("glass", (sx * (hw * 0.93), 1.72, dz - 0.22), (sx * (hw * 0.96), hh - 0.14, dz + 0.22), tint=GLASS_ARMOUR)
                if s.get("idf"):
                    add_idf_chevron_x(hull, sx * (hw * 0.95), 1.40, -0.20, sx, arm_len=0.16, mode="down")
                else:
                    add_nato_diamond(hull, sx * (hw * 0.95), 1.40, -0.20, sx, size=0.12)

    if not lod:
        for sx in (-1, 1):
            hull.cyl("glass", (sx * (hw * 0.68), 1.32, hl + 0.02), 0.052, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.box("glass", (sx * (hw * 0.72), 1.24, -hl - 0.02), (sx * (hw * 0.86), 1.34, -hl + 0.02), tint=TAIL_RED)
        # Rear spare wheel + tall whip antenna!
        hull.cyl("rubber", (0.0, 1.52, -hl - 0.18), tr * 0.88, 0.26, axis="z", seg=14)
        hull.cyl("paint", (0.0, 1.52, -hl - 0.20), tr * 0.46, 0.28, axis="z", seg=12)
        hull.cyl("dark", (-hw * 0.82, hh, -0.55), 0.011, 1.05, seg=6)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate((-wb_h, wb_h)):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style="western"))

    # Roof OGPK Octagonal Gunner Turret (Humvee) or RWS (.50 cal)
    tur_z = -0.35 if style == "humvee" else 0.05
    if s["rws"] == "ogpk":
        t_piv = (0.0, hh + 0.02, tur_z)
        turret = Part("Turret")
        seg_o = 8
        pts = [(0.48 * math.sin(math.tau * i / seg_o), tur_z + 0.48 * math.cos(math.tau * i / seg_o)) for i in range(seg_o)]
        turret.frustum_xz("paint", pts, pts, hh + 0.02, hh + 0.46, bevel=0.008 if not lod else 0.0)
        if not lod:
            for k in range(3):
                ka = (k - 1) * 0.65
                with turret.frame((0.48 * math.sin(ka), hh + 0.30, tur_z + 0.48 * math.cos(ka)), yaw=ka):
                    turret.box("glass", (-0.10, -0.06, -0.02), (0.10, 0.08, 0.03), tint=GLASS_ARMOUR)
        rig.add("Turret", "Hull", t_piv, turret)
        g_piv = (0.0, hh + 0.50, tur_z + 0.38)
        gun = Part("Gun")
        gun.box("metal_dark", (-0.07, g_piv[1] - 0.06, g_piv[2] - 0.16), (0.07, g_piv[1] + 0.07, g_piv[2] + 0.24))
        gun.cyl("metal_dark", (0.0, g_piv[1], g_piv[2] + 0.24), 0.020, 0.78, axis="z", seg=10)
        muz_pt = (0.0, g_piv[1], g_piv[2] + 1.08)
        gun.tube_axis("metal_dark", (0.0, g_piv[1], g_piv[2] + 1.00), muz_pt, 0.028, 0.014, seg=8)
        rig.add("Gun", "Turret", g_piv, gun)
        rig.add("Muzzle", "Gun", muz_pt, None)
    else:
        _add_apc_rws_or_t50(rig, "rws_50", 0.0, hh, tur_z, lod)
    return rig


def export_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for slug in TRACKED_APC_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_tracked_apc_rig(slug, 0),
            build_tracked_apc_rig(slug, 1),
            turret_offset=(3.6, 0.0, 0.1),
            ring_radius=0.32,
        )
    if only is None or only == "apc__bmp_1":
        init_scene()
        export_vehicle(
            os.path.join(out_dir, "apc__bmp_1.glb"),
            build_bmp1_rig(0),
            build_bmp1_rig(1),
            turret_offset=(3.8, 0.0, -0.2),
            ring_radius=0.68,
        )
    if only is None or only == "apc__bmp_2_btr_80_captured":
        init_scene()
        export_vehicle(
            os.path.join(out_dir, "apc__bmp_2_btr_80_captured.glb"),
            build_east_ifv_rig("ifv__bmp_2", 0),
            build_east_ifv_rig("ifv__bmp_2", 1),
            turret_offset=(3.8, 0.0, -0.2),
            ring_radius=0.80,
        )
    for slug in MRAP_4X4_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_mrap_4x4_rig(slug, 0),
            build_mrap_4x4_rig(slug, 1),
            turret_offset=(3.2, 0.0, 0.1),
            ring_radius=0.28,
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
