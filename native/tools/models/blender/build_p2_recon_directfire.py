"""Tier P2.4 — Direct-Fire Tank Destroyers, Light Tanks & Armoured Reconnaissance (19 vehicles), modelled in Blender 5.2.

Run all 19 variants:
    blender -b -P native/tools/models/blender/build_p2_recon_directfire.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  Wheeled Tank Destroyers & Fire Support (6):
    1. reconVehicle__centauro_ii.glb  (Italian Centauro II 8x8 MGS w/ 120mm L/45 & slotted muzzle brake)
    2. directFire__type_16_mcv.glb    (JGSDF Type 16 MCV 8x8 w/ stealth bustle turret & 105mm pepperpot brake)
    3. directFire__amx_10_rc.glb      (French AMX-10 RC 6x6 amphibious w/ TK 105 turret & double-baffle brake)
    4. directFire__badak.glb          (Indonesian Pindad Badak 6x6 w/ Cockerill CSE 90LP 90mm turret)
    5. directFire__ee_9_cascavel.glb  (Brazilian Engesa EE-9 Cascavel 6x6 w/ sloped bow & 90mm Cockerill)
    6. reconVehicle__ebrc_jaguar.glb  (French EBRC Jaguar 6x6 w/ faceted 40mm CTA turret, PASEO & Akeron pod)
  Tracked Medium Tank & Heavy Cavalry Recon (3):
    7. directFire__harimau.glb        (FNSS/Pindad Kaplan MT / Harimau tracked medium tank w/ Cockerill 3105 105mm)
    8. reconVehicle__ajax.glb         (British Ajax 7-wheel tracked recon IFV w/ 40mm CTA turret & Orion sight)
    9. reconVehicle__m3_bradley_scout.glb (US M3A3 Cavalry Bradley w/ 25mm, twin TOW & elevated LRAS3 scout pod)
  Wheeled Armoured Scout Cars (6):
   10. reconVehicle__type_87_rcv.glb  (JGSDF Type 87 6x6 RCV w/ offset 25mm KBA turret)
   11. reconVehicle__argus.glb        (8x8 Battlefield Reconnaissance Vehicle w/ telescopic EO/radar mast & RWS)
   12. reconVehicle__fennek.glb       (German/Dutch Fennek 4x4 low-profile stealth scout w/ BAA sensor mast & RWS)
   13. reconVehicle__komatsu_lav.glb  (JGSDF Komatsu LAV 4x4 faceted scout car w/ shielded roof mount)
   14. reconVehicle__hawkei.glb       (Australian Thales Hawkei 4x4 PMV-L crew-cab scout w/ RWS)
   15. reconVehicle__komodo_scout.glb (Indonesian Pindad Komodo 4x4 sloped-nose tactical scout w/ RWS)
  Special Operations Open-Top Roll-Cage Raider Buggies (4):
   16. reconVehicle__zmag.glb         (IDF IAI ZMAG 4x4 Special Forces tubular roll-cage desert buggy w/ .50 cal)
   17. reconVehicle__flyer72_beeri.glb(IDF 'Be'eri' / Flyer 72 4x4 SOF wide spaceframe tactical vehicle w/ .50 cal)
   18. reconVehicle__jackal.glb       (British Supacat Jackal 2 4x4 open-top MWMIK weapons platform w/ .50 cal)
   19. reconVehicle__jackal_3e.glb    (British Supacat Jackal 3e 6x6 open-top high-mobility platform w/ .50 cal)
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
    build_west_ifv_rig,
    add_nato_diamond,
)
from build_p2_apc_tracked_mrap import build_mrap_4x4_rig, _add_apc_rws_or_t50

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.32, 1.10, 1.40)
GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# 1–6 & 10–11. WHEELED TANK DESTROYERS & MULTI-AXLE SCOUTS
# =============================================================================

WHEELED_TD_SPECS = {
    "reconVehicle__centauro_ii": {
        "axles": [-2.42, -0.88, 0.88, 2.42], "tr": 0.58, "tw": 0.39, "wx": 1.28,
        "hl": 7.90, "hw": 3.02, "hh": 2.02, "tur_z": -0.22, "tur_h": 0.64,
        "gun_len": 4.25, "gun_cal": 0.062, "brake": "slotted", "rws_top": True,
    },
    "directFire__type_16_mcv": {
        "axles": [-2.38, -0.86, 0.86, 2.38], "tr": 0.56, "tw": 0.38, "wx": 1.26,
        "hl": 7.85, "hw": 2.98, "hh": 1.98, "tur_z": -0.30, "tur_h": 0.64,
        "gun_len": 3.85, "gun_cal": 0.056, "brake": "pepperpot",
    },
    "directFire__amx_10_rc": {
        "axles": [-1.95, 0.0, 1.95], "tr": 0.54, "tw": 0.37, "wx": 1.18,
        "hl": 6.35, "hw": 2.78, "hh": 1.82, "tur_z": -0.10, "tur_h": 0.60,
        "gun_len": 3.55, "gun_cal": 0.054, "brake": "baffle", "waterjets": True,
    },
    "directFire__badak": {
        "axles": [-1.92, -0.12, 1.92], "tr": 0.54, "tw": 0.36, "wx": 1.12,
        "hl": 6.15, "hw": 2.54, "hh": 1.98, "tur_z": -0.25, "tur_h": 0.58,
        "gun_len": 2.95, "gun_cal": 0.048, "brake": "baffle",
    },
    "directFire__ee_9_cascavel": {
        "axles": [-1.85, -0.58, 1.88], "tr": 0.52, "tw": 0.34, "wx": 1.08,
        "hl": 5.45, "hw": 2.48, "hh": 1.78, "tur_z": 0.05, "tur_h": 0.56,
        "gun_len": 2.85, "gun_cal": 0.048, "brake": "baffle",
    },
    "reconVehicle__ebrc_jaguar": {
        "axles": [-2.05, -0.45, 2.05], "tr": 0.58, "tw": 0.39, "wx": 1.16,
        "hl": 7.15, "hw": 2.68, "hh": 2.12, "tur_z": -0.10, "tur_h": 0.72,
        "gun_len": 2.15, "gun_cal": 0.042, "brake": "cta40", "atgm_pod": True,
    },
    "reconVehicle__type_87_rcv": {
        "axles": [-1.88, -0.45, 1.88], "tr": 0.52, "tw": 0.35, "wx": 1.08,
        "hl": 5.98, "hw": 2.48, "hh": 1.85, "tur_z": 0.12, "tur_h": 0.54,
        "gun_len": 2.05, "gun_cal": 0.032, "brake": "slotted",
    },
    "reconVehicle__argus": {
        "axles": [-2.25, -0.82, 0.82, 2.25], "tr": 0.55, "tw": 0.38, "wx": 1.20,
        "hl": 7.35, "hw": 2.76, "hh": 2.08, "tur_z": 0.35, "tur_h": 0.44,
        "gun_len": 1.25, "gun_cal": 0.022, "brake": "rws", "mast": True,
    },
}


def build_wheeled_td_rig(slug, lod=0):
    s = WHEELED_TD_SPECS[slug]
    rig = VehicleRig(lod=lod)
    tr, tw, wx = s["tr"], s["tw"], s["wx"]
    hl, hw, hh = s["hl"] * 0.5, s["hw"] * 0.5, s["hh"]

    hull = Part("Hull")
    tub_w = wx - tw * 0.56 - 0.05
    belly_prof = [(-hl + 0.22, 1.18), (-hl + 0.60, 0.56), (hl - 1.00, 0.56), (hl + 0.06, 1.38), (hl - 0.80, 1.18)]
    hull.profile_x("paint", belly_prof, -tub_w, tub_w, bevel=0.016 if not lod else 0.0, tint=(0.82, 0.83, 0.80))
    for az in s["axles"]:
        hull.cyl("metal_dark", (-wx, tr, az), 0.08, wx * 2.0, axis="x", seg=8)

    prof = [
        (-hl, 1.20), (-hl + 0.16, 1.14), (hl - 0.88, 1.14),
        (hl + 0.20, 1.44), (hl + 0.08, 1.60), (hl - 1.35, hh), (-hl + 0.06, hh),
    ]
    hull.profile_x("paint", prof, -hw * 0.82, hw * 0.82, bevel=0.020 if not lod else 0.0, ao_y=(0.56, hh + 0.3))
    for sx in (-1, 1):
        hull.wedge("paint", (sx * hw, 1.20, -hl + 0.08), (sx * (hw * 0.82), hh, hl - 0.25),
                   axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.014 if not lod else 0.0)
        if not lod:
            add_nato_diamond(hull, sx * (hw - 0.01), 1.48, 0.0, sx, size=0.13)
            hull.cyl("glass", (sx * (hw * 0.72), 1.46, hl + 0.05), 0.048, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.box("glass", (sx * (hw * 0.72), 1.34, -hl - 0.02), (sx * (hw * 0.86), 1.44, -hl + 0.02), tint=TAIL_RED)
            if s.get("waterjets"):
                hull.tube_axis("dark", (sx * 0.72, 0.94, -hl - 0.04), (sx * 0.72, 0.94, -hl + 0.05), 0.12, 0.09, seg=10)

    if not lod:
        hull.box("dark", (0.16, hh - 0.06, hl - 1.30), (hw * 0.72, hh + 0.01, hl - 0.45))
        hull.cyl("paint", (-0.45, hh, hl - 1.15), 0.24, 0.05, seg=14, bevel=0.006)
        if s.get("mast"):
            # Telescopic battlefield surveillance radar + EO/FLIR mast on Argus!
            hull.box("paint", (-0.42, hh, -hl + 0.55), (0.42, hh + 0.32, -hl + 1.45), bevel=0.010)
            hull.cyl("metal_dark", (0.0, hh + 0.32, -hl + 0.95), 0.08, 0.95, seg=12)
            hull.box("paint", (-0.28, hh + 1.25, -hl + 0.75), (0.28, hh + 1.56, -hl + 1.15), bevel=0.010)
            hull.box("glass", (-0.22, hh + 1.30, -hl + 1.14), (0.22, hh + 1.50, -hl + 1.17), tint=OPTIC_FLIR)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(s["axles"]):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style="western"))

    if s["brake"] == "rws":
        _add_apc_rws_or_t50(rig, "rws_50", 0.0, hh, s["tur_z"], lod)
        return rig

    tz, th = s["tur_z"], s["tur_h"]
    t_piv = (0.0, hh + 0.02, tz)
    ring = Part("Turret_Ring")
    ring.cyl("metal_dark", (0.0, hh - 0.02, tz), 0.88, 0.06, seg=18 if not lod else 10)
    rig.add("Turret_Ring", "Hull", t_piv, ring)

    turret = Part("Turret")
    tw_b = 1.02 if s["gun_cal"] > 0.05 else 0.86
    tl_f, tl_r = (1.28, -1.68) if s["gun_cal"] > 0.05 else (1.02, -1.25)
    b_pts = [(-0.52 * tw_b, tl_f), (0.52 * tw_b, tl_f), (tw_b, 0.28), (0.92 * tw_b, tl_r * 0.65),
             (0.72 * tw_b, tl_r), (-0.72 * tw_b, tl_r), (-0.92 * tw_b, tl_r * 0.65), (-tw_b, 0.28)]
    turret.frustum_xz("paint", [(x, z + tz) for x, z in b_pts], [(x * 0.78, z * 0.86 + tz) for x, z in b_pts],
                      hh + 0.04, hh + 0.04 + th, bevel=0.018 if not lod else 0.0)
    ty_top = hh + 0.04 + th
    if not lod:
        turret.box("paint", (-0.52, ty_top, tz + 0.18), (-0.20, ty_top + 0.24, tz + 0.56), bevel=0.008)
        turret.box("glass", (-0.48, ty_top + 0.04, tz + 0.555), (-0.24, ty_top + 0.19, tz + 0.57), tint=OPTIC_FLIR)
        paseo_h = 0.42 if s.get("atgm_pod") else 0.22
        turret.cyl("paint", (0.28, ty_top, tz - 0.22), 0.14, paseo_h, seg=12)
        turret.box("paint", (0.12, ty_top + paseo_h, tz - 0.36), (0.44, ty_top + paseo_h + 0.22, tz - 0.08), bevel=0.008)
        turret.box("glass", (0.16, ty_top + paseo_h + 0.04, tz - 0.085), (0.40, ty_top + paseo_h + 0.18, tz - 0.07), tint=OPTIC_COOL)
        if s.get("atgm_pod"):
            turret.box("paint", (tw_b - 0.05, hh + 0.24, tz - 0.58), (tw_b + 0.28, ty_top + 0.06, tz + 0.45), bevel=0.010)
        if s.get("rws_top"):
            turret.box("metal_dark", (-0.32, ty_top + 0.04, tz - 0.68), (-0.12, ty_top + 0.28, tz - 0.42), bevel=0.006)
            turret.cyl("metal_dark", (-0.22, ty_top + 0.22, tz - 0.42), 0.016, 0.55, axis="z", seg=8)
        for sx in (-1, 1):
            for k in range(4):
                with turret.frame((sx * tw_b * 0.78, hh + 0.28, tz + 0.48 - k * 0.08), yaw=sx * 0.32, pitch=-0.38):
                    turret.cyl("metal_dark", (0, 0, 0), 0.032, 0.17, axis="z", seg=8)
            turret.cyl("dark", (sx * 0.56, ty_top, tz + tl_r + 0.15), 0.011, 1.05, seg=6)
    rig.add("Turret", "Hull", t_piv, turret)

    g_piv = (0.0, hh + 0.04 + th * 0.48, tz + tl_f * 0.86)
    gy, gz = g_piv[1], g_piv[2]
    cal, glen = s["gun_cal"], s["gun_len"]
    gun = Part("Gun")
    gun.box("paint", (-0.24, gy - 0.16, gz - 0.22), (0.24, gy + 0.16, gz + 0.22), bevel=0.012 if not lod else 0.0)
    gun.cyl("paint", (0.0, gy, gz + 0.20), cal * 1.35, glen * 0.38, axis="z", seg=14)
    if s["gun_cal"] > 0.05:
        # Bore evacuator on 105mm / 120mm tank-destroyer barrels!
        gun.cyl("paint", (0.0, gy, gz + 0.20 + glen * 0.38), cal * 1.95, 0.52, axis="z", seg=14, bevel=0.010 if not lod else 0.0)
        gun.cyl("paint", (0.0, gy, gz + 0.72 + glen * 0.38), cal, glen * 0.62 - 0.52, axis="z", seg=14)
    else:
        gun.cyl("metal_dark", (0.0, gy, gz + 0.20 + glen * 0.38), cal, glen * 0.62, axis="z", seg=12)
    muz_z = gz + 0.20 + glen
    if s["brake"] == "baffle":
        gun.box("metal_dark", (-cal * 2.2, gy - cal * 1.5, muz_z - 0.05), (cal * 2.2, gy + cal * 1.5, muz_z + 0.24), bevel=0.008)
        muz_pt = (0.0, gy, muz_z + 0.24)
    else:
        gun.tube_axis("metal_dark", (0.0, gy, muz_z - 0.04), (0.0, gy, muz_z + 0.22), cal * 1.65, cal * 0.75, seg=14)
        muz_pt = (0.0, gy, muz_z + 0.22)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 7–9. HARIMAU MEDIUM TANK, AJAX RECON & M3A3 CAVALRY BRADLEY
# =============================================================================

def build_harimau_rig(lod=0):
    """FNSS/Pindad Kaplan MT / Harimau Medium Tank: 6-wheel rear-engine tracked hull + Cockerill 3105 105mm turret!"""
    rig = VehicleRig(lod=lod)
    ts, tx, tw, wr = 0.90, 1.40, 0.50, 0.34
    hl, hw, hh = 3.48, 1.18, 1.56
    hull = Part("Hull")
    prof = [(-hl, 0.54), (-hl + 0.22, 0.34), (hl - 0.85, 0.34), (hl + 0.16, 1.02), (hl - 1.35, hh), (-hl + 0.08, hh)]
    hull.profile_x("paint", prof, -hw, hw, bevel=0.018 if not lod else 0.0, ao_y=(0.34, hh + 0.4))
    sk_xi = tx + tw * 0.515 + 0.025
    sk_xo = sk_xi + 0.09
    for sx in (-1, 1):
        hull.box("paint", (sx * hw, hh - 0.24, -hl + 0.06), (sx * sk_xi, hh, hl - 0.08), bevel=0.012 if not lod else 0.0)
        hull.box("paint", (sx * sk_xi, 0.58, -hl + 0.08), (sx * sk_xo, hh - 0.02, hl - 0.08), bevel=0.010 if not lod else 0.0)
        if not lod:
            add_nato_diamond(hull, sx * (sk_xo + 0.004), 1.05, 0.15, sx, size=0.13)
    if not lod:
        hull.box("dark", (-0.82, hh - 0.01, -hl + 0.35), (0.82, hh + 0.02, -hl + 1.55))
        hull.cyl("paint", (0.0, hh, hl - 1.25), 0.25, 0.05, seg=14, bevel=0.006)
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))
        sp_p = (sx * tx, 0.65 * ts, -3.24 * ts)
        id_p = (sx * tx, 0.68 * ts, 3.22 * ts)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_ifv_sprocket(sp_p, lod, sx, r=wr * 1.04))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_ifv_idler(id_p, lod, sx, r=wr * 0.98))
        for i, wz in enumerate((-2.25, -1.35, -0.45, 0.45, 1.35, 2.25)):
            wp = (sx * tx, wr, wz)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_ifv_road_wheel(wp, lod, sx, r=wr))
        if not lod:
            for r_i, rz in enumerate((-1.25, 0.0, 1.25)):
                rp = (sx * tx, 1.05 * ts, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx))

    # Cockerill 3105 faceted turret + 105mm gun
    tz, th = 0.12, 0.66
    t_piv = (0.0, hh + 0.02, tz)
    turret = Part("Turret")
    b_pts = [(-0.56, 1.25), (0.56, 1.25), (1.06, 0.30), (0.98, -1.10), (0.76, -1.72), (-0.76, -1.72), (-0.98, -1.10), (-1.06, 0.30)]
    turret.frustum_xz("paint", [(x, z + tz) for x, z in b_pts], [(x * 0.78, z * 0.88 + tz) for x, z in b_pts],
                      hh + 0.04, hh + 0.04 + th, bevel=0.018 if not lod else 0.0)
    if not lod:
        ty = hh + 0.04 + th
        turret.cyl("paint", (-0.30, ty, tz - 0.18), 0.14, 0.22, seg=12)
        turret.box("paint", (-0.46, ty + 0.22, tz - 0.34), (-0.14, ty + 0.42, tz - 0.02), bevel=0.008)
        turret.box("glass", (-0.42, ty + 0.26, tz - 0.025), (-0.18, ty + 0.38, tz - 0.01), tint=OPTIC_FLIR)
        turret.cyl("dark", (0.56, ty, tz - 1.45), 0.011, 1.05, seg=6)
    rig.add("Turret", "Hull", t_piv, turret)

    g_piv = (0.0, hh + 0.38, tz + 1.12)
    gy, gz = g_piv[1], g_piv[2]
    gun = Part("Gun")
    gun.box("paint", (-0.26, gy - 0.16, gz - 0.22), (0.26, gy + 0.16, gz + 0.22), bevel=0.012 if not lod else 0.0)
    gun.cyl("paint", (0.0, gy, gz + 0.20), 0.075, 1.55, axis="z", seg=14)
    gun.cyl("paint", (0.0, gy, gz + 1.75), 0.115, 0.52, axis="z", seg=14, bevel=0.010 if not lod else 0.0)
    gun.cyl("paint", (0.0, gy, gz + 2.27), 0.058, 1.65, axis="z", seg=14)
    muz_pt = (0.0, gy, gz + 4.14)
    gun.tube_axis("metal_dark", (0.0, gy, gz + 3.90), muz_pt, 0.095, 0.046, seg=14)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


def build_ajax_recon_rig(lod=0):
    """British Ajax 7-road-wheel Tracked Recon IFV w/ 40mm CTA turret & Orion panoramic sight."""
    rig = build_west_ifv_rig("ifv__cv9035nl", lod=lod)
    if not lod:
        for n in rig.nodes:
            if n["name"] == "Turret":
                n["part"].cyl("metal_dark", (0.28, 2.14, -0.45), 0.08, 0.36, seg=10)
                n["part"].box("paint", (0.10, 2.50, -0.62), (0.46, 2.76, -0.28), bevel=0.008)
                n["part"].box("glass", (0.14, 2.55, -0.285), (0.42, 2.71, -0.27), tint=OPTIC_FLIR)
    return rig


def build_m3_scout_rig(lod=0):
    """US M3A3 CFV Cavalry Scout Bradley w/ elevated LRAS3 long-range scout FLIR pod."""
    rig = build_west_ifv_rig("ifv__m2a4_bradley", lod=lod)
    if not lod:
        for n in rig.nodes:
            if n["name"] == "Turret":
                n["part"].cyl("metal_dark", (0.58, 2.30, -0.68), 0.065, 0.42, seg=10)
                n["part"].box("paint", (0.38, 2.72, -0.92), (0.78, 2.98, -0.44), bevel=0.008)
                n["part"].box("glass", (0.42, 2.76, -0.445), (0.74, 2.94, -0.43), tint=OPTIC_FLIR)
    return rig


# =============================================================================
# 12–15. 4x4 ARMOURED SCOUT CARS (`fennek`, `komatsu_lav`, `hawkei`, `komodo_scout`)
# =============================================================================

def build_fennek_rig(lod=0):
    """German/Dutch Fennek 4x4 Low-Profile Stealth Recon Vehicle w/ retractable BAA sensor mast & RWS."""
    rig = VehicleRig(lod=lod)
    wb_h, wx, tr, tw = 1.76, 1.02, 0.48, 0.33
    hl, hw, hh = 2.79, 1.24, 1.72

    hull = Part("Hull")
    tub_w = wx - tw * 0.58 - 0.04
    hull.profile_x("paint", [(-hl + 0.20, 1.00), (-wb_h + 0.20, 0.50), (wb_h - 0.20, 0.50), (hl - 0.15, 1.00)],
                   -tub_w, tub_w, bevel=0.014 if not lod else 0.0, tint=(0.82, 0.83, 0.80))
    for az in (-wb_h, wb_h):
        hull.cyl("metal_dark", (-wx, tr, az), 0.07, wx * 2.0, axis="x", seg=8)

    # Signature Fennek ultra-low faceted stealth wedge hull!
    prof = [(-hl, 1.06), (hl - 0.90, 1.06), (hl + 0.10, 1.26), (hl - 0.72, hh), (-hl + 0.10, hh)]
    hull.profile_x("paint", prof, -hw * 0.80, hw * 0.80, bevel=0.018 if not lod else 0.0, ao_y=(0.55, hh))
    for sx in (-1, 1):
        hull.wedge("paint", (sx * hw, 1.08, -hl + 0.12), (sx * (hw * 0.80), hh, hl - 0.55),
                   axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.012 if not lod else 0.0)
        if not lod:
            hull.box("glass", (sx * (hw * 0.78), 1.38, 0.55), (sx * (hw * 0.86), hh - 0.08, 1.12), tint=GLASS_ARMOUR)
            add_nato_diamond(hull, sx * (hw - 0.01), 1.28, -0.45, sx, size=0.11)
    if not lod:
        hull.box("glass", (-0.36, 1.36, 1.22), (0.36, hh - 0.08, 1.38), tint=GLASS_ARMOUR)
        # Signature Fennek elevated BAA electro-optical reconnaissance sensor head on telescopic mast (brings height to 2.62m!)
        hull.cyl("metal_dark", (-0.38, hh, -0.68), 0.055, 0.62, seg=10)
        hull.box("paint", (-0.60, hh + 0.62, -0.88), (-0.16, hh + 0.90, -0.48), bevel=0.010)
        hull.box("glass", (-0.56, hh + 0.66, -0.485), (-0.20, hh + 0.86, -0.47), tint=OPTIC_FLIR)
        hull.cyl("dark", (0.48, hh, -hl + 0.35), 0.011, 0.95, seg=6)
    else:
        hull.cyl("metal_dark", (-0.38, hh, -0.68), 0.06, 0.78, seg=8)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate((-wb_h, wb_h)):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style="western"))
    _add_apc_rws_or_t50(rig, "rws_50", 0.24, hh, -0.10, lod)
    return rig


# =============================================================================
# 16–19. SPECIAL OPERATIONS OPEN-TOP ROLL-CAGE RAIDER BUGGIES (`zmag`, `flyer72_beeri`, `jackal`, `jackal_3e`)
# =============================================================================

BUGGY_SPECS = {
    "reconVehicle__zmag": {"axles": [-1.72, 1.72], "wx": 0.98, "tr": 0.50, "tw": 0.34, "hl": 5.05, "hw": 2.12, "idf": True},
    "reconVehicle__flyer72_beeri": {"axles": [-1.75, 1.75], "wx": 1.00, "tr": 0.49, "tw": 0.34, "hl": 5.10, "hw": 2.18, "idf": True},
    "reconVehicle__jackal": {"axles": [-1.80, 1.80], "wx": 0.96, "tr": 0.50, "tw": 0.34, "hl": 5.38, "hw": 2.04, "boat_nose": True},
    "reconVehicle__jackal_3e": {"axles": [-2.18, -0.88, 1.92], "wx": 0.98, "tr": 0.50, "tw": 0.34, "hl": 6.15, "hw": 2.08, "boat_nose": True},
}


def build_sof_buggy_rig(slug, lod=0):
    """Sculpted Special Forces open-top tubular roll-cage tactical vehicle w/ crew seats, spare wheel & ring M2HB!"""
    s = BUGGY_SPECS[slug]
    rig = VehicleRig(lod=lod)
    wx, tr, tw = s["wx"], s["tr"], s["tw"]
    hl, hw = s["hl"] * 0.5, s["hw"] * 0.5

    hull = Part("Hull")
    # 1. Armoured V-hull lower tub + sloped hood + open fighting bay floor + rear cargo deck
    tub_w = wx - tw * 0.58 - 0.04
    hull.profile_x("paint", [(-hl + 0.15, 1.04), (-hl + 0.55, 0.54), (hl - 0.65, 0.54), (hl + 0.08, 1.18), (hl - 0.55, 1.04)],
                   -tub_w, tub_w, bevel=0.014 if not lod else 0.0)
    for az in s["axles"]:
        hull.cyl("metal_dark", (-wx, tr, az), 0.072, wx * 2.0, axis="x", seg=8)

    # Sloped armoured front hood + half-height ballistic side doors + rear cargo bed
    hull.box("paint", (-hw * 0.84, 0.98, hl - 1.38), (hw * 0.84, 1.44, hl), bevel=0.018 if not lod else 0.0)
    hull.box("paint", (-hw * 0.92, 0.92, -hl), (hw * 0.92, 1.12, hl - 1.34), bevel=0.012 if not lod else 0.0)
    hull.box("paint", (-hw * 0.92, 1.10, -hl), (hw * 0.92, 1.48, -hl + 1.15), bevel=0.014 if not lod else 0.0)
    for sx in (-1, 1):
        hull.box("paint", (sx * (hw * 0.86), 1.10, -hl + 1.12), (sx * (hw * 0.94), 1.44, hl - 1.34), bevel=0.010 if not lod else 0.0)

    # 2. Heavy tubular SOF spaceframe roll-cage & weapon ring stanchions (`y = 1.44 .. 2.12`)!
    cage_top = 2.10
    z_a, z_b, z_c = hl - 1.36, -0.05, -hl + 1.12
    for sx in (-1, 1):
        cx = sx * (hw * 0.84)
        hull.pipe("metal_dark", (cx, 1.42, z_a), (sx * (hw * 0.76), cage_top, z_a - 0.34), 0.030, seg=8)
        hull.pipe("metal_dark", (cx, 1.42, z_b), (sx * (hw * 0.76), cage_top, z_b), 0.030, seg=8)
        hull.pipe("metal_dark", (cx, 1.44, z_c), (sx * (hw * 0.76), cage_top, z_c), 0.030, seg=8)
        hull.pipe("metal_dark", (sx * (hw * 0.76), cage_top, z_c), (sx * (hw * 0.76), cage_top, z_a - 0.34), 0.030, seg=8)
    for cz in (z_a - 0.34, z_b, z_c):
        hull.pipe("metal_dark", (-hw * 0.76, cage_top, cz), (hw * 0.76, cage_top, cz), 0.030, seg=8)

    if not lod:
        # Front bullbar + winch + crew bucket seats + dashboard + side spare tyre + jerrycans!
        hull.pipe("metal_dark", (-hw * 0.74, 1.18, hl + 0.12), (hw * 0.74, 1.18, hl + 0.12), 0.028, seg=8)
        hull.box("metal_dark", (-0.22, 1.02, hl - 0.02), (0.22, 1.18, hl + 0.14), bevel=0.006)
        for sx in (-1, 1):
            # Crew bucket seats in open fighting compartment!
            hull.box("canvas", (sx * 0.38 - 0.18, 1.12, 0.18), (sx * 0.38 + 0.18, 1.24, 0.58), bevel=0.010)
            hull.box("canvas", (sx * 0.38 - 0.17, 1.22, 0.14), (sx * 0.38 + 0.17, 1.68, 0.24), bevel=0.010)
            hull.cyl("glass", (sx * (hw * 0.64), 1.28, hl + 0.02), 0.048, 0.02, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            if s.get("idf"):
                add_idf_chevron_x(hull, sx * (hw * 0.945), 1.27, 0.10, sx, arm_len=0.13, mode="down")
            else:
                add_nato_diamond(hull, sx * (hw * 0.945), 1.27, 0.10, sx, size=0.10)
        # Rear spare wheel + whip antenna (ensures height ~2.65 m > 2.0 m!)
        hull.cyl("rubber", (0.0, 1.56, -hl - 0.16), tr * 0.88, 0.26, axis="z", seg=14)
        hull.cyl("paint", (0.0, 1.56, -hl - 0.18), tr * 0.45, 0.28, axis="z", seg=10)
        hull.cyl("dark", (-hw * 0.76, cage_top, z_c), 0.011, 0.65, seg=6)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hull)

    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(s["axles"]):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style="western"))

    # Roof Ring-Mounted .50 cal M2HB (`Turret` -> `Gun` -> `Muzzle`)
    _add_apc_rws_or_t50(rig, "cupola_50", 0.0, cage_top, -0.15, lod)
    return rig


def export_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for slug in WHEELED_TD_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_wheeled_td_rig(slug, 0),
            build_wheeled_td_rig(slug, 1),
            turret_offset=(4.1, 0.0, -0.2),
            ring_radius=0.72 if slug != "reconVehicle__argus" else 0.28,
        )
    specials = [
        ("directFire__harimau", build_harimau_rig, 0.80),
        ("reconVehicle__ajax", build_ajax_recon_rig, 0.76),
        ("reconVehicle__m3_bradley_scout", build_m3_scout_rig, 0.76),
        ("reconVehicle__fennek", build_fennek_rig, 0.26),
    ]
    for slug, fn, rr in specials:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(os.path.join(out_dir, f"{slug}.glb"), fn(0), fn(1), turret_offset=(3.9, 0.0, -0.2), ring_radius=rr)

    # 3 Tactical 4x4 Scout Cars reusing customized MRAP_4X4 builder specs
    from build_p2_apc_tracked_mrap import MRAP_4X4_SPECS
    scout_4x4 = {
        "reconVehicle__komatsu_lav": {"style": "sandcat", "wb": 2.95, "wx": 0.94, "tr": 0.46, "tw": 0.31, "hl": 4.82, "hw": 2.08, "hh": 1.96, "rws": "ogpk"},
        "reconVehicle__hawkei": {"style": "jltv", "wb": 3.55, "wx": 1.02, "tr": 0.52, "tw": 0.35, "hl": 5.78, "hw": 2.38, "hh": 2.22, "rws": "rws_50"},
        "reconVehicle__komodo_scout": {"style": "humvee", "wb": 3.40, "wx": 0.98, "tr": 0.49, "tw": 0.33, "hl": 5.55, "hw": 2.26, "hh": 2.08, "rws": "rws_50"},
    }
    MRAP_4X4_SPECS.update(scout_4x4)
    for slug in scout_4x4:
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

    for slug in BUGGY_SPECS:
        if only and slug != only:
            continue
        init_scene()
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_sof_buggy_rig(slug, 0),
            build_sof_buggy_rig(slug, 1),
            turret_offset=(3.0, 0.0, 0.1),
            ring_radius=0.24,
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
