"""Tier P4.2 — Strategic SAM / ABM Batteries (32), Laser / HPM (3), Drone Launchers (2), Radars (8) & EW (6) = 51 vehicles.

Completes 100% of all 337 ground vehicles in `native/godot/assets/art/vehicles/`!
Run all 51 variants:
    blender -b --python-exit-code 1 -P native/tools/models/blender/build_p4_sam_radar_ew.py -- --all
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import add_nato_diamond
from build_p3_sph_tracked import add_sph_running_gear, rect_xz

OPTIC_LASER = (0.28, 1.45, 1.55)
GLASS_ARMOUR = (0.24, 0.58, 0.52)


def add_tel_truck_chassis(hp: Part, rig: VehicleRig, lod: int, n_axles: int, hub: str = "western", idf: bool = False, outriggers: bool = True):
    """Shared high-detail 6x6 / 8x8 / 10x10 tactical TEL / Radar / EW truck chassis seated on `y = 0`."""
    bv = 0.016 if not lod else 0.0
    if n_axles == 5:
        axles = [-3.60, -2.20, -0.80, 1.85, 3.25]
        z0, z1, hx = -4.60, 4.45, 1.30
    elif n_axles == 4:
        axles = [-3.05, -1.60, 1.60, 3.05]
        z0, z1, hx = -4.30, 4.20, 1.28
    else:
        axles = [-2.20, -0.85, 2.15]
        z0, z1, hx = -3.45, 3.45, 1.22

    wr, tw, wx = 0.56 if n_axles >= 4 else 0.53, 0.40, 1.16
    hp.box("metal_dark", (-0.56, 0.72, z0), (0.56, 1.18, z1 - 0.12), bevel=bv)
    hp.box("paint", (-hx, 1.18, z0), (hx, 1.42, 1.05), bevel=bv)
    # Forward armored tactical cab + electronics / generator shelter behind cab
    cab_z0 = 2.15 if n_axles >= 4 else 1.10
    hp.profile_x(
        "paint",
        [(cab_z0, 1.18), (z1 - 0.08, 1.18), (z1, 1.80), (z1 - 0.30, 2.58), (cab_z0, 2.58)],
        -hx, hx, bevel=bv, ao_y=(0.65, 2.80),
    )
    if n_axles >= 4:
        hp.box("paint", (-hx + 0.06, 1.42, 0.95), (hx - 0.06, 2.44, 2.10), bevel=bv)
    if outriggers:
        for sx in (-1, 1):
            for oz in (z0 + 0.35, 0.75):
                hp.box("metal_dark", (sx * (hx + 0.22) - 0.16, 0.03, oz - 0.16), (sx * (hx + 0.22) + 0.16, 1.26, oz + 0.16), bevel=bv)
    if not lod:
        for sx in (-1, 1):
            hp.box("glass", (sx * 0.58 - 0.42, 1.96, z1 - 0.30), (sx * 0.58 + 0.42, 2.40, z1 - 0.06), tint=GLASS_ARMOUR)
            if idf:
                add_idf_chevron_x(hp, sx * (hx + 0.008), 1.66, cab_z0 + 0.65, sx)
            elif hub == "western":
                add_nato_diamond(hp, sx * (hx + 0.008), 1.66, cab_z0 + 0.65, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=hub, lugs=20))
    return z0, z1, hx


# =============================================================================
# 1–32. STRATEGIC SAM & BALLISTIC MISSILE INTERCEPTOR BATTERIES
# =============================================================================

SAM_ABM_SPECS = {
    # Israeli Multi-Tier Defense (4)
    "abmLauncher__arrow_3": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 3, "idf": True, "cyl": True},
    "samLauncher__david_s_sling": {"kind": "box_grid", "axles": 4, "rows": 3, "cols": 4, "idf": True},
    "samLauncher__davids_sling_trailer": {"kind": "box_grid", "axles": 4, "rows": 3, "cols": 4, "idf": True},
    "samLauncher__spyder_s_125": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 2, "idf": True},

    # US / Western Patriot, THAAD, IRIS-T SLM, SAMP/T, NASAMS, Sky Sabre (13)
    "abmLauncher__patriot_pac_3": {"kind": "patriot", "axles": 4},
    "samLauncher__patriot_pac_3": {"kind": "patriot", "axles": 4},
    "samLauncher__patriot_pac_3_mse": {"kind": "patriot", "axles": 4},
    "abmLauncher__sm_3_pac_3_mse": {"kind": "patriot", "axles": 4},
    "samLauncher__patriot_iris_t_nasams": {"kind": "patriot", "axles": 4},
    "abmLauncher__missile_defence_battery": {"kind": "patriot", "axles": 4},
    "abmLauncher__thaad": {"kind": "box_grid", "axles": 5, "rows": 2, "cols": 4},
    "saudiThaad__saudi_thaad": {"kind": "box_grid", "axles": 5, "rows": 2, "cols": 4},
    "irisT__iris_t_slm": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4},
    "samLauncher__samp_t_ng": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4},
    "abmLauncher__samp_t_ng_aster_30_b1nt": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4},
    "samLauncher__sky_sabre_camm": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4},
    "samLauncher__nasams": {"kind": "box_grid", "axles": 3, "rows": 2, "cols": 3},
    "samLauncher__rbs_70_ng_battery": {"kind": "box_grid", "axles": 3, "rows": 2, "cols": 2},

    # Russian / Chinese / Korean / Turkish / Indian / Iranian Heavy SAMs (14 — wait: 4+14+14 = 32!)
    "samLauncher__s_400": {"kind": "cold_tubes", "axles": 4, "east": True},
    "abmLauncher__s_500": {"kind": "cold_tubes", "axles": 5, "east": True},
    "samLauncher__hq_9b": {"kind": "cold_tubes", "axles": 4, "east": True},
    "samLauncher__hq_9_p": {"kind": "cold_tubes", "axles": 4, "east": True},
    "abmLauncher__hq_19": {"kind": "cold_tubes", "axles": 4, "east": True},
    "samLauncher__bavar_373": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 2, "east": True},
    "samLauncher__kn_06_pongae_5": {"kind": "cold_tubes", "axles": 4, "east": True},
    "samLauncher__s_300vm_iris_t_slm": {"kind": "tracked_s300v"},
    "samLauncher__cheongung_ii": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4, "cyl": True},
    "samLauncher__cheongung_ii_korean": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 4, "cyl": True},
    "abmLauncher__l_sam_trailer": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 3, "cyl": True},
    "samLauncher__type_03_chu_sam": {"kind": "box_grid", "axles": 4, "rows": 2, "cols": 3},
    "samLauncher__hisar_o": {"kind": "box_grid", "axles": 3, "rows": 2, "cols": 3},
    "samLauncher__akash": {"kind": "akash_rails", "axles": 4, "east": True},
}


def build_sam_abm_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = SAM_ABM_SPECS[slug]
    kind = cfg["kind"]
    bv = 0.016 if not lod else 0.0
    hp = Part("Hull")

    if kind == "tracked_s300v":
        # Tracked 7-wheel S-300VM Antey-2500 heavy ABM TEL!
        tx, tw, wr, ts = 1.48, 0.56, 0.35, 0.96
        wheels = [-2.52, -1.68, -0.84, 0.0, 0.84, 1.68, 2.52]
        rollers = [-1.65, 0.0, 1.65]
        hl, hw, hh = 7.90, 2.42, 1.50
        z0, z1, hx = -hl * 0.5, hl * 0.5, hw * 0.5
        ow = tx + tw * 0.5 + 0.06
        hp.box("paint", (-ow, 0.44, z0), (ow, hh, z1 - 0.14), bevel=bv)
        hp.profile_x("paint", [(1.45, hh), (z1 - 0.14, hh), (z1, hh + 0.45), (z1 - 0.40, 2.48), (1.45, 2.48)], -ow + 0.04, ow - 0.04, bevel=bv)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=False)
        ty, tz = hh, -1.55
    else:
        hub = "eastern" if cfg.get("east") else "western"
        add_tel_truck_chassis(hp, rig, lod, cfg["axles"], hub=hub, idf=cfg.get("idf", False), outriggers=True)
        ty = 1.42
        tz = -1.95 if cfg["axles"] >= 4 else -1.45

    t_piv = (0.0, ty + 0.02, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, ty, tz), 0.96, 0.24, seg=18 if not lod else 10)
    tp.box("paint", (-1.06, ty + 0.22, tz - 1.25), (1.06, ty + 0.56, tz + 1.05), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, ty + 0.56, tz - 1.15)
    gp = Part("Gun")

    if kind in ("cold_tubes", "tracked_s300v"):
        # S-400 / S-500 / HQ-9B / HQ-19 / S-300VM: 4 massive cylindrical cold-launch tubes angled at 30° (`size.y ~ 5.45 m < 6.0 m`!)
        elev = 0.52
        t_len = 4.45
        with gp.frame(g_piv, pitch=-elev):
            gp.box("metal_dark", (-1.12, -0.05, -0.25), (1.12, 0.22, t_len - 0.35), bevel=bv)
            for ry in (0.44, 1.08):
                for sx in (-1, 1):
                    gp.cyl("paint", (sx * 0.52, ry, -0.20), 0.34, t_len, seg=16 if not lod else 10, axis="z")
                    gp.cyl("metal_dark", (sx * 0.52, ry, t_len - 0.24), 0.36, 0.16, seg=16 if not lod else 10, axis="z")
        muz_pt = (0.0, g_piv[1] + math.sin(elev) * t_len, g_piv[2] + math.cos(elev) * t_len)

    elif kind == "patriot":
        # M903 Patriot PAC-3 MSE: 4 rectangular ribbed canisters elevated at 38° (`2x2` wide stack)
        elev = 0.66
        t_len = 4.35
        with gp.frame(g_piv, pitch=-elev):
            gp.box("metal_dark", (-1.14, -0.04, -0.25), (1.14, 0.24, t_len - 0.45), bevel=bv)
            for ry in (0.52, 1.22):
                for sx in (-1, 1):
                    gp.box("paint", (sx * 0.56 - 0.46, ry - 0.32, -0.20), (sx * 0.56 + 0.46, ry + 0.32, t_len), bevel=bv)
                    gp.box("metal_dark", (sx * 0.56 - 0.42, ry - 0.28, t_len - 0.06), (sx * 0.56 + 0.42, ry + 0.28, t_len + 0.04))
        muz_pt = (0.0, g_piv[1] + math.sin(elev) * t_len, g_piv[2] + math.cos(elev) * t_len)

    elif kind == "akash_rails":
        # Indian Akash: 3 open-rail finned supersonic SAM missiles side-by-side!
        elev = 0.52
        t_len = 4.15
        with gp.frame(g_piv, pitch=-elev):
            gp.box("paint", (-1.16, -0.05, -0.20), (1.16, 0.28, 3.45), bevel=bv)
            for cx in (-0.72, 0.0, 0.72):
                gp.cyl("paint", (cx, 0.56, -0.10), 0.18, 3.65, seg=14 if not lod else 8, axis="z")
                gp.cyl("metal_dark", (cx, 0.56, 3.55), 0.18, 0.60, seg=12, r2=0.02, axis="z")
        muz_pt = (0.0, g_piv[1] + math.sin(elev) * t_len, g_piv[2] + math.cos(elev) * t_len)

    else:
        # `box_grid`: Arrow-3, David's Sling, THAAD, IRIS-T SLM, SAMP/T, Cheongung-II, NASAMS (`size.y ~ 5.10 m < 6.0 m`!)
        elev = 0.74
        t_len = 4.10
        rows, cols = cfg["rows"], cfg["cols"]
        use_cyl = cfg.get("cyl", False)
        with gp.frame(g_piv, pitch=-elev):
            gp.box("metal_dark", (-1.12, -0.05, -0.25), (1.12, 0.22, t_len - 0.35), bevel=bv)
            w_cell = 1.96 / cols
            h_cell = 1.24 / rows
            for r_i in range(rows):
                cy = 0.28 + (r_i + 0.5) * h_cell
                for c_i in range(cols):
                    cx = -0.98 + (c_i + 0.5) * w_cell
                    if use_cyl:
                        rad = min(w_cell, h_cell) * 0.44
                        gp.cyl("paint", (cx, cy, -0.20), rad, t_len, seg=12 if not lod else 8, axis="z")
                        gp.cyl("metal_dark", (cx, cy, t_len - 0.22), rad * 1.04, 0.10, seg=12 if not lod else 8, axis="z")
                    else:
                        gp.box("paint", (cx - w_cell * 0.44, cy - h_cell * 0.44, -0.20), (cx + w_cell * 0.44, cy + h_cell * 0.44, t_len), bevel=bv * 0.7)
                        gp.box("metal_dark", (cx - w_cell * 0.40, cy - h_cell * 0.40, t_len - 0.05), (cx + w_cell * 0.40, cy + h_cell * 0.40, t_len + 0.03))
        muz_pt = (0.0, g_piv[1] + math.sin(elev) * t_len, g_piv[2] + math.cos(elev) * t_len)

    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 33–51. DIRECTED ENERGY (`IRON BEAM` / `LEONIDAS`), SHAHED, RADARS & EW VEHICLES
# =============================================================================

SPECIAL_P4_SLUGS = [
    "laserAD__iron_beam",
    "laserAD__iron_beam_or_eitan",
    "hpmVehicle__leonidas",
    "shahedLauncher__shahed_launcher",
    "shahedLauncher__geran_2_launcher",
    "counterBatteryRadar__elm_2084_mmr",
    "counterBatteryRadar__an_tpq_53",
    "counterBatteryRadar__cheongyeong_ii",
    "counterBatteryRadar__cobra",
    "counterBatteryRadar__cobra_an_tpq_37",
    "counterBatteryRadar__slc_2",
    "counterBatteryRadar__swathi_wlr",
    "counterBatteryRadar__zoopark_1m",
    "ewVehicle__elbit_ew_truck",
    "ewVehicle__ew_vehicle",
    "ewVehicle__fuchs_cg20_suas",
    "ewVehicle__koral",
    "ewVehicle__krasukha_4",
    "ewVehicle__type_2_ew_truck",
]


def build_special_p4_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0
    hp = Part("Hull")

    # 1. Tracked Zoopark-1M Counter-Battery Radar
    if slug == "counterBatteryRadar__zoopark_1m":
        tx, tw, wr, ts = 1.28, 0.42, 0.29, 0.88
        wheels = [-2.28, -1.52, -0.76, 0.0, 0.76, 1.52, 2.28]
        hl, hw, hh = 7.15, 2.24, 1.62
        z0, z1, hx = -hl * 0.5, hl * 0.5, hw * 0.5
        ow = tx + tw * 0.5 + 0.04
        hp.profile_x("paint", [(z0 + 0.20, 0.40), (z1 - 0.75, 0.40), (z1, 1.02), (z1 - 0.95, hh), (z0 + 0.12, hh), (z0, 1.04)], -hx, hx, bevel=bv)
        for sx in (-1, 1):
            hp.box("paint", (sx * hx, 0.84, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_sph_running_gear(rig, lod, tx, tw, wr, wheels, [], ts, front_drive=True)
        ty, tz = hh, -0.95
    # 2. Wheeled Armored V-Hull APC Chassis (`Or Eitan` 8x8 & `Fuchs CG20` 6x6)
    elif slug in ("laserAD__iron_beam_or_eitan", "ewVehicle__fuchs_cg20_suas"):
        is_eitan = slug == "laserAD__iron_beam_or_eitan"
        axles = [-2.55, -1.05, 1.05, 2.55] if is_eitan else [-2.05, 0.0, 2.05]
        wr, tw, wx = (0.58 if is_eitan else 0.52), 0.40, 1.16
        z0, z1, hx, hh = (-3.85 if is_eitan else -3.35), (3.95 if is_eitan else 3.45), 1.28, 2.04
        hp.profile_x("paint", [(z0 + 0.22, 0.66), (z1 - 0.75, 0.66), (z1, 1.34), (z1 - 1.10, hh), (z0 + 0.14, hh), (z0, 1.38)], -hx, hx, bevel=bv)
        if not lod:
            for sx in (-1, 1):
                if is_eitan:
                    add_idf_chevron_x(hp, sx * (hx + 0.008), 1.48, 0.20, sx)
                else:
                    add_nato_diamond(hp, sx * (hx + 0.008), 1.48, 0.20, sx, size=0.12)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        for side_lbl, sx in (("L", -1), ("R", 1)):
            for i, az in enumerate(axles):
                wp = (sx * wx, wr, az)
                rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=20))
        ty, tz = hh, -0.65
    else:
        # 3. 8x8 / 6x6 Tactical Radar / Laser / Shahed / EW Truck Chassis
        is_idf = slug in ("laserAD__iron_beam", "counterBatteryRadar__elm_2084_mmr", "ewVehicle__elbit_ew_truck")
        is_east = slug in ("shahedLauncher__shahed_launcher", "shahedLauncher__geran_2_launcher", "counterBatteryRadar__slc_2", "counterBatteryRadar__swathi_wlr", "ewVehicle__krasukha_4")
        n_ax = 3 if slug.startswith("shahedLauncher__") or slug == "hpmVehicle__leonidas" else 4
        has_shelter = slug in ("laserAD__iron_beam", "ewVehicle__elbit_ew_truck", "ewVehicle__krasukha_4", "ewVehicle__koral", "ewVehicle__type_2_ew_truck", "ewVehicle__ew_vehicle")
        if has_shelter:
            # Rear armored C2 / cooling / EW electronics container shelter (+ louvered cooling grilles)!
            hp.box("paint", (-1.22, 1.42, -4.15), (1.22, 2.52, 0.85), bevel=bv)
            if not lod:
                for sx in (-1, 1):
                    for gz in (-3.45, -2.35, -1.25):
                        hp.box("metal_dark", (sx * 1.21, 1.68, gz - 0.34), (sx * 1.23, 2.28, gz + 0.34))
            ty, tz = 2.52, -1.65
        else:
            ty, tz = 1.42, (-1.95 if n_ax == 4 else -1.45)
        add_tel_truck_chassis(hp, rig, lod, n_ax, hub="eastern" if is_east else "western", idf=is_idf, outriggers=not slug.startswith("shahedLauncher__"))

    t_piv = (0.0, ty + 0.02, tz)
    tp = Part("Turret")
    gp = Part("Gun")

    if slug.startswith("laserAD__"):
        # High-Energy Laser Beam-Director Gimbal Turret (`Iron Beam` / `Or Eitan`)!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.72, 0.20, seg=18 if not lod else 10)
        tp.box("paint", (-0.68, ty + 0.18, tz - 0.62), (0.68, ty + 1.08, tz + 0.58), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.78, tz + 0.10)
        gp.cyl("paint", (0.0, g_piv[1], g_piv[2] - 0.25), 0.44, 1.12, seg=18 if not lod else 10, axis="z")
        gp.tube_axis("metal_dark", (0.0, g_piv[1], g_piv[2] + 0.82), (0.0, g_piv[1], g_piv[2] + 0.96), 0.45, 0.34, seg=18 if not lod else 10)
        if not lod:
            gp.cyl("glass", (0.0, g_piv[1], g_piv[2] + 0.84), 0.34, 0.04, seg=16, axis="z", tint=OPTIC_LASER)
            # Auxiliary FLIR / target-tracking EO pods flanking primary mirror
            for sx in (-1, 1):
                gp.box("metal_dark", (sx * 0.56 - 0.12, g_piv[1] - 0.14, g_piv[2] + 0.15), (sx * 0.56 + 0.12, g_piv[1] + 0.16, g_piv[2] + 0.68), bevel=0.01)
        muz_pt = (0.0, g_piv[1], g_piv[2] + 0.98)

    elif slug.startswith("shahedLauncher__"):
        # Multi-cell angled box rack launching 5 delta-wing Shahed-136 / Geran-2 loitering munitions!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.76, 0.18, seg=16 if not lod else 10)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.20, tz - 0.85)
        with gp.frame(g_piv, pitch=-0.34):
            gp.box("paint", (-1.16, 0.0, -0.25), (1.16, 1.24, 3.15), bevel=bv)
            gp.box("metal_dark", (-1.08, 0.08, 3.10), (1.08, 1.16, 3.22))
            if not lod:
                # Visible nosecones + delta-wing tips inside launch cells!
                for cx in (-0.68, 0.0, 0.68):
                    gp.cyl("paint", (cx, 0.62, 2.85), 0.14, 0.58, seg=10, r2=0.02, axis="z")
        muz_pt = (0.0, g_piv[1] + 1.38, g_piv[2] + 3.05)

    elif slug.startswith("counterBatteryRadar__") or slug == "hpmVehicle__leonidas":
        # Large Slewing + Tilting Planar AESA Radar / Leonidas HPM Array (`EL/M-2084 MMR`, `AN/TPQ-53`, `COBRA`, `Zoopark`)!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.88, 0.24, seg=18 if not lod else 10)
        tp.box("paint", (-0.82, ty + 0.22, tz - 0.78), (0.82, ty + 1.06, tz + 0.68), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 1.02, tz + 0.10)
        with gp.frame(g_piv, pitch=-0.22):
            # Massive flat AESA phased-array face + rear cooling/TRM spine (`size.y ~ 4.35 m < 6.0 m`!)
            gp.box("paint", (-1.34, -0.15, 0.10), (1.34, 2.25, 0.42), bevel=bv)
            gp.box("metal_dark", (-1.22, -0.05, 0.40), (1.22, 2.15, 0.48), bevel=bv * 0.5)
            gp.box("metal_dark", (-0.58, 0.15, -0.42), (0.58, 1.65, 0.12), bevel=bv)
        muz_pt = (0.0, g_piv[1] + 1.05, g_piv[2] + 0.92)

    else:
        # Electronic Warfare & C-UAS Jammer (`Krasukha-4`, `KORAL`, `Elbit EW`, `Fuchs CG20`, `Type 2 EW`)!
        # Keep mast + dishes comfortably below `y = 5.4 m` (`< 6.0 m`)!
        tp.cyl("metal_dark", (0.0, ty, tz), 0.74, 0.22, seg=16 if not lod else 10)
        tp.box("paint", (-0.68, ty + 0.20, tz - 0.65), (0.68, ty + 1.18, tz + 0.65), bevel=bv)
        # Roof omni C-UAS radome masts
        if not lod:
            for sx in (-1, 1):
                tp.cyl("metal_dark", (sx * 0.52, ty + 1.18, tz - 0.35), 0.04, 1.25, seg=8)
                tp.cyl("paint", (sx * 0.52, ty + 2.25, tz - 0.35), 0.14, 0.36, seg=10)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, ty + 0.92, tz + 0.25)
        # Twin high-gain parabolic / planar EW jamming dishes pointing forward (`muzzle ~ 1.15 m > 0.7 m`)!
        for sx in (-1, 1):
            gp.cyl("paint", (sx * 0.58, g_piv[1], g_piv[2] + 0.35), 0.48, 0.18, seg=16 if not lod else 10, r2=0.18, axis="z")
            gp.cyl("metal_dark", (sx * 0.58, g_piv[1], g_piv[2] + 0.52), 0.06, 0.42, seg=8, axis="z")
        muz_pt = (0.0, g_piv[1], g_piv[2] + 1.05)

    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


ALL_SLUGS = list(SAM_ABM_SPECS.keys()) + SPECIAL_P4_SLUGS


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in SAM_ABM_SPECS:
        return build_sam_abm_rig(slug, lod)
    return build_special_p4_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(4.0, 0.0, -0.5),
        ring_radius=0.80,
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
