"""Tier P4.1 — Mobile SPAAGs, Gun-Missile SHORAD & Iron Dome Batteries (`aaVehicle` 30 + `shortRangeSAM` 8 = 38 vehicles).

Run all 38 variants:
    blender -b --python-exit-code 1 -P native/tools/models/blender/build_p4_shorad_spaag.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import add_nato_diamond
from build_p3_sph_tracked import add_sph_running_gear, rect_xz

OPTIC_FLIR = (0.25, 1.35, 0.95)
GLASS_ARMOUR = (0.24, 0.58, 0.52)


# =============================================================================
# 1–16. TRACKED SPAAGs & TRACKED SHORAD (`Gepard`, `Tunguska`, `Shilka`, `PGZ-09`, `Korkut`, `Stormer`, `HISAR-A`, `Chunma`)
# =============================================================================

TRACKED_AA_SPECS = {
    "aaVehicle__gepard_1a2": {"kind": "gepard", "wheels": 7, "east": False},
    "aaVehicle__gepard_strela_10": {"kind": "gepard", "wheels": 7, "east": False, "pods": True},
    "aaVehicle__pgz_09": {"kind": "gepard", "wheels": 6, "east": True},
    "aaVehicle__type_87_spaag": {"kind": "gepard", "wheels": 7, "east": False},
    "aaVehicle__2k22_tunguska": {"kind": "tunguska", "wheels": 6, "east": True},
    "aaVehicle__zsu_23_4_shilka": {"kind": "shilka", "wheels": 6, "east": True},
    "aaVehicle__korkut": {"kind": "korkut", "wheels": 6, "east": False},
    "aaVehicle__k263a3_vulcan": {"kind": "vulcan", "wheels": 5, "east": False},
    "aaVehicle__sidam_25": {"kind": "sidam", "wheels": 5, "east": False},
    "aaVehicle__skyranger_30_acsv": {"kind": "skyranger", "wheels": 6, "east": False},
    "aaVehicle__stormer_hvm": {"kind": "stormer", "wheels": 6, "east": False},
    "shortRangeSAM__stormer_hvm": {"kind": "stormer", "wheels": 6, "east": False},
    "shortRangeSAM__hisar_a": {"kind": "hisar_a", "wheels": 6, "east": False},
    "shortRangeSAM__iris_t_sls": {"kind": "nomads", "wheels": 6, "east": False},
    "shortRangeSAM__nomads": {"kind": "nomads", "wheels": 6, "east": False},
    "shortRangeSAM__k31_chunma": {"kind": "chunma", "wheels": 6, "east": False},
}


def build_tracked_aa_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = TRACKED_AA_SPECS[slug]
    nw = cfg["wheels"]
    kind = cfg["kind"]
    bv = 0.016 if not lod else 0.0

    if nw == 5:
        tx, tw, wr, ts = 1.18, 0.38, 0.30, 0.74
        wheels, rollers = [-1.64, -0.82, 0.0, 0.82, 1.64], []
        hl, hw, hh = 5.35, 2.16, 1.76
    elif nw == 7:
        tx, tw, wr, ts = 1.44, 0.54, 0.35, 0.94
        wheels, rollers = [-2.46, -1.64, -0.82, 0.0, 0.82, 1.64, 2.46], [-1.60, 0.0, 1.60]
        hl, hw, hh = 7.50, 2.38, 1.52
    else:
        tx, tw, wr, ts = 1.34, 0.48, 0.33, 0.88
        wheels, rollers = [-2.20, -1.32, -0.44, 0.44, 1.32, 2.20], [-1.35, 0.0, 1.35]
        hl, hw, hh = 6.85, 2.28, 1.54

    z0, z1 = -hl * 0.5, hl * 0.5
    hx, ow = hw * 0.5, tx + tw * 0.5 + 0.05
    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [(z0 + 0.18, 0.40), (z1 - 0.65, 0.40), (z1, 0.98), (z1 - 0.90, hh), (z0 + 0.12, hh), (z0, 1.02)],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 1.1),
    )
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.86, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.12), bevel=bv)
        hp.box("paint", (sx * (ow - 0.05), 0.50, z0 + 0.14), (sx * (ow + 0.02), 0.92, z1 - 0.18), bevel=bv * 0.7)
        if not lod and not cfg["east"]:
            add_nato_diamond(hp, sx * (ow + 0.024), 0.74, 0.10, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=(nw == 5 or kind in ("korkut", "skyranger", "stormer", "hisar_a", "nomads")))

    tz = -0.15 if nw >= 6 else -0.25
    t_piv = (0.0, hh + 0.02, tz)
    tp = Part("Turret")
    gp = Part("Gun")

    if kind == "gepard":
        # Gepard / PGZ-09 / Type 87: rounded armored turret + rear planar search radar + front tracking radar + side 35mm pods!
        bot = rect_xz(-1.08, 1.08, tz - 1.35, tz + 1.10)
        top = rect_xz(-0.84, 0.84, tz - 1.15, tz + 0.85)
        tp.frustum_xz("paint", bot, top, hh + 0.02, hh + 0.96, bevel=bv)
        # Rear elevated planar search radar + front tracking radar dome
        tp.box("metal_dark", (-0.12, hh + 0.96, tz - 1.25), (0.12, hh + 1.56, tz - 0.95), bevel=bv)
        tp.box("paint", (-0.92, hh + 1.42, tz - 1.30), (0.92, hh + 1.82, tz - 1.12), bevel=bv)
        tp.cyl("paint", (0.0, hh + 0.52, tz + 0.98), 0.36, 0.24, seg=14 if not lod else 8, axis="z")
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.62, tz + 0.15)
        for sx in (-1, 1):
            # External side-mounted 35mm Oerlikon KDA gun pods + long fluted barrels!
            gp.box("paint", (sx * 1.18 - 0.22, g_piv[1] - 0.24, g_piv[2] - 0.65), (sx * 1.18 + 0.22, g_piv[1] + 0.24, g_piv[2] + 0.55), bevel=bv)
            gp.cyl("metal_dark", (sx * 1.18, g_piv[1], g_piv[2] + 0.52), 0.048, 2.35, seg=12 if not lod else 8, axis="z")
            gp.tube_axis("metal", (sx * 1.18, g_piv[1], g_piv[2] + 2.82), (sx * 1.18, g_piv[1], g_piv[2] + 3.02), 0.058, 0.032, seg=10)
            if cfg.get("pods"):
                gp.box("metal_dark", (sx * 1.42 - 0.14, g_piv[1] + 0.18, g_piv[2] - 0.45), (sx * 1.42 + 0.14, g_piv[1] + 0.46, g_piv[2] + 0.65), bevel=bv)
        muz_pt = (0.0, g_piv[1], g_piv[2] + 3.02)

    elif kind == "tunguska":
        # 2K22 Tunguska: wide angular turret + rear search radar + twin 30mm + 8x 9M311 SAM tubes!
        tp.frustum_xz("paint", rect_xz(-1.28, 1.28, tz - 1.45, tz + 1.15), rect_xz(-1.02, 1.02, tz - 1.25, tz + 0.90), hh + 0.02, hh + 0.92, bevel=bv)
        tp.box("paint", (-0.88, hh + 1.24, tz - 1.38), (0.88, hh + 1.66, tz - 1.16), bevel=bv)
        tp.cyl("paint", (0.0, hh + 0.64, tz + 1.02), 0.34, 0.22, seg=14 if not lod else 8, axis="z")
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.56, tz + 0.25)
        for sx in (-1, 1):
            gp.cyl("metal_dark", (sx * 1.06, g_piv[1], g_piv[2] + 0.35), 0.042, 1.95, seg=10, axis="z")
            # Quad (2x2) 9M311 missile tubes outboard of 30mm guns!
            for ry in (-0.12, 0.16):
                for rx in (-0.12, 0.12):
                    gp.cyl("paint", (sx * 1.36 + rx, g_piv[1] + ry, g_piv[2] - 0.65), 0.095, 1.85, seg=10, axis="z")
        muz_pt = (0.0, g_piv[1], g_piv[2] + 2.32)

    elif kind == "shilka":
        # ZSU-23-4 Shilka: wide low dish turret + RPK-2 Gun Dish radar + quad 23mm AZP-23!
        tp.frustum_xz("paint", rect_xz(-1.26, 1.26, tz - 1.25, tz + 1.05), rect_xz(-1.04, 1.04, tz - 1.05, tz + 0.82), hh + 0.02, hh + 0.74, bevel=bv)
        tp.cyl("paint", (0.0, hh + 1.08, tz - 0.98), 0.48, 0.16, seg=16 if not lod else 10, axis="z")
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.44, tz + 0.78)
        gp.box("paint", (-0.52, g_piv[1] - 0.22, g_piv[2] - 0.25), (0.52, g_piv[1] + 0.22, g_piv[2] + 0.42), bevel=bv)
        for sx in (-1, 1):
            for dy in (-0.10, 0.10):
                gp.cyl("metal_dark", (sx * 0.24, g_piv[1] + dy, g_piv[2] + 0.38), 0.032, 1.65, seg=8, axis="z")
        muz_pt = (0.0, g_piv[1], g_piv[2] + 2.06)

    elif kind in ("stormer", "chunma", "hisar_a", "nomads"):
        # Tracked Short-Range SAM Turrets (8-round Starstreak / Chunma / Quad HISAR-A / NOMADS + roof radar!)
        tp.cyl("metal_dark", (0.0, hh, tz), 0.76, 0.20, seg=16 if not lod else 10)
        tp.box("paint", (-0.64, hh + 0.18, tz - 0.68), (0.64, hh + 0.92, tz + 0.58), bevel=bv)
        tp.box("metal_dark", (-0.72, hh + 0.92, tz - 0.52), (0.72, hh + 1.38, tz - 0.30), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.68, tz)
        with gp.frame(g_piv, pitch=-0.20):
            for sx in (-1, 1):
                gp.box("paint", (sx * 0.92 - 0.34, -0.22, -0.95), (sx * 0.92 + 0.34, 0.42, 1.35), bevel=bv)
                gp.box("metal_dark", (sx * 0.92 - 0.30, -0.18, 1.30), (sx * 0.92 + 0.30, 0.38, 1.38))
        muz_pt = (0.0, g_piv[1] + 0.42, tz + 1.42)

    else:
        # `korkut`, `skyranger`, `vulcan`, `sidam`: faceted stealth / unmanned autocannon SPAAG turret!
        tp.frustum_xz("paint", rect_xz(-0.98, 0.98, tz - 1.05, tz + 0.95), rect_xz(-0.68, 0.68, tz - 0.85, tz + 0.72), hh + 0.02, hh + 0.82, bevel=bv)
        tp.cyl("paint", (0.0, hh + 0.82, tz - 0.45), 0.28, 0.36, seg=12)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.48, tz + 0.70)
        gp.box("paint", (-0.28, g_piv[1] - 0.18, g_piv[2] - 0.20), (0.28, g_piv[1] + 0.18, g_piv[2] + 0.52), bevel=bv)
        if kind == "vulcan":
            # 20mm M61 6-barrel Gatling cluster!
            gp.cyl("metal_dark", (0.0, g_piv[1], g_piv[2] + 0.48), 0.11, 1.38, seg=12, axis="z")
        elif kind == "sidam":
            for sx in (-1, 1):
                for dy in (-0.08, 0.08):
                    gp.cyl("metal_dark", (sx * 0.16, g_piv[1] + dy, g_piv[2] + 0.48), 0.028, 1.55, seg=8, axis="z")
        else:
            # Skyranger 30 shrouded triangular barrel / Korkut twin 35mm
            gp.box("paint", (-0.14, g_piv[1] - 0.12, g_piv[2] + 0.48), (0.14, g_piv[1] + 0.12, g_piv[2] + 1.85), bevel=bv)
            gp.cyl("metal_dark", (0.0, g_piv[1], g_piv[2] + 1.80), 0.055, 0.42, seg=12, axis="z")
        muz_pt = (0.0, g_piv[1], g_piv[2] + 2.25)

    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 17–30. WHEELED 8x8 / 6x6 / 4x4 MOBILE SHORAD (`Pantsir`, `Skyranger 30`, `M-SHORAD`, `Avenger`, `ZU-23 Technical`)
# =============================================================================

WHEELED_AA_SPECS = {
    "aaVehicle__pantsir_s1": "pantsir_8x8",
    "shortRangeSAM__pantsir_s": "pantsir_8x8",
    "aaVehicle__skyranger_30": "boxer_8x8",
    "aaVehicle__k30_biho_ii": "boxer_8x8",
    "aaVehicle__k30w_chunho": "boxer_8x8",
    "aaVehicle__m_shorad": "boxer_8x8",
    "aaVehicle__crotale_ng": "crotale_6x6",
    "aaVehicle__avenger_shahine": "avenger_4x4",
    "aaVehicle__avenger_sinai_23": "avenger_4x4",
    "shortRangeSAM__an_twq_1_avenger": "avenger_4x4",
    "shortRangeSAM__type_11_sam": "avenger_4x4",
    "aaVehicle__fennek_swp": "avenger_4x4",
    "aaVehicle__rbs_70_vehicle": "avenger_4x4",
    "aaVehicle__zu_23_2_technical": "technical_4x4",
    "aaVehicle__m1992_30_mm": "crotale_6x6",
}


def build_wheeled_aa_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    kind = WHEELED_AA_SPECS[slug]
    bv = 0.016 if not lod else 0.0
    hp = Part("Hull")

    if kind == "pantsir_8x8":
        # KamAZ-6560 8x8 armored truck + central raised module + Pantsir 12-missile + twin 30mm + radar turret!
        axles = [-3.05, -1.65, 1.55, 2.95]
        wr, tw, wx = 0.56, 0.40, 1.16
        z0, z1, hx = -4.25, 4.15, 1.26
        hp.box("metal_dark", (-0.56, 0.72, z0), (0.56, 1.18, z1 - 0.12), bevel=bv)
        hp.box("paint", (-hx, 1.18, z0), (hx, 1.98, 1.10), bevel=bv)
        hp.box("paint", (-hx, 1.16, 1.20), (hx, 2.58, z1), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.56 - 0.42, 1.96, z1 - 0.10), (sx * 0.56 + 0.42, 2.38, z1 + 0.02), tint=GLASS_ARMOUR)
        hub = "eastern"
        tz, ty = -1.65, 1.98
    elif kind == "boxer_8x8":
        axles = [-2.55, -1.05, 1.05, 2.55]
        wr, tw, wx = 0.56, 0.40, 1.16
        z0, z1, hx = -3.85, 3.95, 1.28
        hp.profile_x("paint", [(z0 + 0.22, 0.68), (z1 - 0.75, 0.68), (z1, 1.32), (z1 - 1.10, 1.94), (z0 + 0.14, 1.94), (z0, 1.36)], -hx, hx, bevel=bv)
        hub = "western"
        tz, ty = -0.55, 1.94
    elif kind == "crotale_6x6":
        axles = [-2.05, 0.0, 2.05]
        wr, tw, wx = 0.54, 0.38, 1.14
        z0, z1, hx = -3.35, 3.45, 1.24
        hp.profile_x("paint", [(z0 + 0.22, 0.64), (z1 - 0.65, 0.64), (z1, 1.28), (z1 - 0.95, 1.92), (z0 + 0.14, 1.92), (z0, 1.32)], -hx, hx, bevel=bv)
        hub = "western"
        tz, ty = -0.65, 1.92
    else:
        # 4x4 Avenger HMMWV / Fennek SWP / ZU-23-2 Tactical Pickup (`size.z ~ 5.10 m > 4.5 m`!)
        axles = [-1.72, 1.72]
        wr, tw, wx = 0.48, 0.33, 0.98
        z0, z1, hx = -2.58, 2.58, 1.08
        hp.box("metal_dark", (-0.48, 0.56, z0), (0.48, 0.92, z1 - 0.08), bevel=bv)
        hp.box("paint", (-hx, 0.88, z0), (hx, 1.34, 0.35), bevel=bv)
        hp.profile_x("paint", [(0.32, 0.88), (z1 - 0.06, 0.88), (z1, 1.38), (1.55, 1.44), (1.22, 1.96), (0.32, 1.96)], -hx, hx, bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.46 - 0.36, 1.48, 1.22), (sx * 0.46 + 0.36, 1.84, 1.52), tint=GLASS_ARMOUR)
        hub = "western"
        tz, ty = -1.15, 1.34

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=hub, lugs=18))

    t_piv = (0.0, ty + 0.02, tz)
    tp = Part("Turret")
    gp = Part("Gun")

    if kind == "pantsir_8x8":
        tp.cyl("metal_dark", (0.0, ty, tz), 0.78, 0.24, seg=16 if not lod else 10)
        tp.box("paint", (-0.54, ty + 0.22, tz - 0.75), (0.54, ty + 1.24, tz + 0.65), bevel=bv)
        tp.box("paint", (-0.82, ty + 1.24, tz - 0.55), (0.82, ty + 1.72, tz - 0.28), bevel=bv)  # SOTS S-band radar!
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.78, tz + 0.10)
        for sx in (-1, 1):
            gp.cyl("metal_dark", (sx * 0.64, g_piv[1] - 0.14, g_piv[2] + 0.25), 0.042, 2.05, seg=10, axis="z")
            # 6x 57E6 missile tubes per side (`2x3` cluster)
            for ry in (0.02, 0.24, 0.46):
                for rx in (-0.12, 0.12):
                    gp.cyl("paint", (sx * 0.96 + rx, g_piv[1] + ry, g_piv[2] - 0.85), 0.095, 2.15, seg=10, axis="z")
        muz_pt = (0.0, g_piv[1] - 0.14, g_piv[2] + 2.34)

    elif kind == "boxer_8x8":
        # Faceted Skyranger 30 / M-SHORAD RIwP / Biho II turret (30mm cannon + SAM pod!)
        tp.frustum_xz("paint", rect_xz(-1.04, 1.04, tz - 1.08, tz + 0.98), rect_xz(-0.72, 0.72, tz - 0.85, tz + 0.75), ty + 0.02, ty + 0.82, bevel=bv)
        tp.box("paint", (0.74, ty + 0.28, tz - 0.65), (1.22, ty + 0.76, tz + 0.65), bevel=bv)  # Side Stinger pod
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.46, tz + 0.72)
        gp.box("paint", (-0.16, g_piv[1] - 0.14, g_piv[2] - 0.10), (0.16, g_piv[1] + 0.14, g_piv[2] + 1.65), bevel=bv)
        gp.cyl("metal_dark", (0.0, g_piv[1], g_piv[2] + 1.62), 0.052, 0.56, seg=12, axis="z")
        muz_pt = (0.0, g_piv[1], g_piv[2] + 2.20)

    elif kind == "technical_4x4":
        # ZU-23-2 twin 23mm AA cannon on pickup bed (`size.y > 2.15 m`)!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.48, 0.22, seg=14)
        tp.box("paint", (-0.42, ty + 0.20, tz - 0.38), (0.42, ty + 0.76, tz + 0.32), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.66, tz + 0.10)
        with gp.frame(g_piv, pitch=-0.18):
            for sx in (-1, 1):
                gp.cyl("metal_dark", (sx * 0.16, 0.0, -0.35), 0.036, 2.05, seg=10, axis="z")
                gp.tube_axis("metal", (sx * 0.16, 0.0, 1.66), (sx * 0.16, 0.0, 1.82), 0.052, 0.026, seg=8)
        muz_pt = (0.0, g_piv[1] + 0.34, g_piv[2] + 1.80)

    else:
        # Avenger / Crotale NG / Type 11 gyro-stabilized SAM turret (`size.y > 2.45 m`)!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.62, 0.18, seg=16 if not lod else 10)
        tp.box("paint", (-0.44, ty + 0.16, tz - 0.55), (0.44, ty + 0.96, tz + 0.48), bevel=bv)
        if not lod:
            tp.box("glass", (-0.30, ty + 0.44, tz + 0.46), (0.30, ty + 0.82, tz + 0.51), tint=GLASS_ARMOUR)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.72, tz)
        with gp.frame(g_piv, pitch=-0.22):
            for sx in (-1, 1):
                gp.box("paint", (sx * 0.74 - 0.28, -0.18, -0.82), (sx * 0.74 + 0.28, 0.42, 1.15), bevel=bv)
                gp.box("metal_dark", (sx * 0.74 - 0.24, -0.14, 1.10), (sx * 0.74 + 0.24, 0.38, 1.18))
            # Coaxial .50 cal M3P machine gun under starboard pod!
            gp.cyl("metal_dark", (0.74, -0.28, 0.10), 0.022, 1.25, seg=8, axis="z")
        muz_pt = (0.0, g_piv[1] + 0.36, tz + 1.35)

    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 31–38. IRON DOME BATTERIES & TOWED / SEMI-MOBILE AA PLATFORMS
# =============================================================================

STATIONARY_AA_SLUGS = [
    "aaVehicle__iron_dome_battery",
    "aaVehicle__iron_dome_mfu",
    "aaVehicle__skyshield_rbs_70",
    "aaVehicle__35_mm_air_defence_gun",
    "aaVehicle__ly_80_oerlikon",
    "aaVehicle__zu_23_2",
    "aaVehicle__zu_23_2_saqr_358",
]


def build_stationary_or_irondome_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0
    hp = Part("Hull")

    if slug in ("aaVehicle__iron_dome_battery", "aaVehicle__iron_dome_mfu"):
        # Iconic Israeli Rafael Iron Dome MFU on heavy 3-axle mobilized flatbed/trailer w/ outriggers + 20-cell Tamir pod!
        axles = [-2.25, -0.95, 2.05]
        wr, tw, wx = 0.52, 0.38, 1.14
        z0, z1, hx = -3.45, 3.35, 1.24
        hp.box("metal_dark", (-0.56, 0.64, z0), (0.56, 1.12, z1), bevel=bv)
        hp.box("paint", (-hx, 1.12, z0), (hx, 1.36, z1), bevel=bv)
        # Forward generator & BMC electronics module + 4 deployed hydraulic outrigger pads touching y = 0.02!
        hp.box("paint", (-hx + 0.08, 1.36, 1.05), (hx - 0.08, 2.36, z1 - 0.18), bevel=bv)
        for sx in (-1, 1):
            for oz in (-2.95, 1.45):
                hp.box("metal_dark", (sx * (hx + 0.28) - 0.18, 0.02, oz - 0.18), (sx * (hx + 0.28) + 0.18, 1.22, oz + 0.18), bevel=bv)
            if not lod:
                add_idf_chevron_x(hp, sx * (hx - 0.072), 1.84, 2.15, sx)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        for side_lbl, sx in (("L", -1), ("R", 1)):
            for i, az in enumerate(axles):
                wp = (sx * wx, wr, az)
                rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=20))

        tz = -1.15
        t_piv = (0.0, 1.38, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, 1.36, tz), 0.92, 0.22, seg=18 if not lod else 10)
        for sx in (-1, 1):
            tp.box("paint", (sx * 0.88 - 0.16, 1.56, tz - 0.85), (sx * 0.88 + 0.16, 2.48, tz + 0.85), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        # Signature steep-angled 20-cell (`4x5`) Tamir interceptor box frame!
        g_piv = (0.0, 2.25, tz - 0.45)
        gp = Part("Gun")
        with gp.frame(g_piv, pitch=-0.68):
            gp.box("paint", (-0.86, -0.25, -0.65), (0.86, 1.12, 2.85), bevel=bv)
            gp.box("metal_dark", (-0.78, -0.18, 2.80), (0.78, 1.04, 2.90))
            if not lod:
                for ry in (-0.02, 0.28, 0.58, 0.88):
                    for ci in range(5):
                        cx = -0.58 + ci * 0.29
                        gp.box("dark", (cx - 0.10, ry - 0.10, 2.86), (cx + 0.10, ry + 0.10, 2.93))
        muz_pt = (0.0, g_piv[1] + 2.05, g_piv[2] + 2.15)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # Towed 4-wheel cruciform AA Gun Carriage (`Skyshield`, `Oerlikon GDF 35mm`, `ZU-23-2`)
    # Span `z = -2.65..+2.65` (`5.30 m > 4.5 m`) & elevated unmanned/crewed AA turret (`size.y ~ 2.45 m > 2.0 m`)!
    axles = [-1.95, 1.95]
    wr, tw, wx = 0.42, 0.28, 1.04
    hp.box("metal_dark", (-0.46, 0.34, -2.55), (0.46, 0.64, 2.55), bevel=bv)
    hp.box("paint", (-1.55, 0.28, -0.55), (1.55, 0.68, 0.55), bevel=bv)
    for sx in (-1, 1):
        hp.box("metal_dark", (sx * 1.55 - 0.20, 0.02, -0.24), (sx * 1.55 + 0.20, 0.42, 0.24), bevel=bv)
    hp.box("paint", (-0.68, 0.64, -2.35), (0.68, 1.38, -1.25), bevel=bv)  # Generator / ammo module
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)

    hub = "eastern" if "zu_23" in slug else "western"
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=hub, lugs=16))

    t_piv = (0.0, 0.70, 0.15)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 0.68, 0.15), 0.64, 0.20, seg=16 if not lod else 10)
    if slug == "aaVehicle__skyshield_rbs_70":
        # Faceted unmanned Skyshield Revolver Gun Mk3 stealth cupola!
        tp.frustum_xz("paint", rect_xz(-0.78, 0.78, -0.65, 0.95), rect_xz(-0.52, 0.52, -0.45, 0.72), 0.88, 1.88, bevel=bv)
        tp.cyl("paint", (0.0, 1.88, 0.0), 0.24, 0.42, seg=12)
    else:
        tp.box("paint", (-0.64, 0.88, -0.55), (0.64, 1.78, 0.65), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 1.48, 0.45)
    gp = Part("Gun")
    with gp.frame(g_piv, pitch=-0.26):
        if slug == "aaVehicle__skyshield_rbs_70":
            gp.box("paint", (-0.16, -0.14, 0.0), (0.16, 0.16, 1.85), bevel=bv)
            gp.cyl("metal_dark", (0.0, 0.0, 1.80), 0.055, 0.48, seg=12, axis="z")
        else:
            for sx in (-1, 1):
                gp.cyl("metal_dark", (sx * 0.24, 0.0, -0.15), 0.042, 2.45, seg=10, axis="z")
                gp.tube_axis("metal", (sx * 0.24, 0.0, 2.25), (sx * 0.24, 0.0, 2.42), 0.056, 0.030, seg=8)
    muz_pt = (0.0, g_piv[1] + 0.65, g_piv[2] + 2.35)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


ALL_SLUGS = (
    list(TRACKED_AA_SPECS.keys())
    + list(WHEELED_AA_SPECS.keys())
    + STATIONARY_AA_SLUGS
)


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in TRACKED_AA_SPECS:
        return build_tracked_aa_rig(slug, lod)
    if slug in WHEELED_AA_SPECS:
        return build_wheeled_aa_rig(slug, lod)
    return build_stationary_or_irondome_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(3.6, 0.0, -0.3),
        ring_radius=0.72,
    )


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    out_dir = os.path.join(repo_root, "native", "godot", "assets", "art", "vehicles")
    os.makedirs(out_dir, exist_ok=True)
    targets = ALL_SLUGS if ("--all" in argv or not argv) else [s for s in argv if not s.startswith("--")]
    for slug in targets:
        export_one(slug, out_dir)


if __name__ == "__main__":
    main()
