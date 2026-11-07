"""Tier P2.2 — Multi-Axle Wheeled APCs & Heavy MRAPs (26 vehicles: 8x8, 6x6 & 4x4), modelled in Blender 5.2.

Run all 26 variants:
    blender -b -P native/tools/models/blender/build_p2_apc_wheeled.py -- --all

Covers all 26 multi-axle wheeled `apc__*` vehicles across 3 distinct hull & suspension architectures:
  A. Modern Modular V-Hull 8x8 / 6x6 APCs (`eitan`, `eitan_series_2023`, `boxer`, `boxer_crv`, `stryker`,
     `amv_xp_japan`, `lav_700`, `vbm_freccia`, `k808_apc`, `type_96_apc`, `whap`, `zbl_08`, `vbtp_guarani`).
  B. Armoured Ballistic-Windshield Cab APCs & Heavy MRAPs (`pars`, `griffon`, `anoa`, `btr_80_typhoon_mrap`, `rakhsh`).
  C. Soviet / Ukrainian / DPRK BTR 8x8 Boat-Hull Family (`btr_82a`, `btr_80a_btr_70`, `btr_60_bmp_1`,
     `btr_60_mrap`, `btr_4`, `btr_4_m113`, `btr_3un_proforce_ara`, `m_2010`).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import add_nato_diamond

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.32, 1.10, 1.40)
GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# VEHICLE SPECIFICATION TABLE (26 WHEELED APCs)
# =============================================================================

APC_SPECS = {
    # --- A. Modern Modular V-Hull 8x8 / 6x6 ---
    "apc__eitan": {
        "arch": "modular", "axles": [-2.50, -0.92, 0.92, 2.50], "tyre_r": 0.60, "tyre_w": 0.40, "wx": 1.30,
        "hull_l": 7.95, "hull_w": 2.98, "hull_h": 2.26, "aps": True, "idf": True,
        "weapon": "rws_50", "tur_x": 0.30, "tur_z": 0.65,
    },
    "apc__eitan_series_2023": {
        "arch": "modular", "axles": [-2.50, -0.92, 0.92, 2.50], "tyre_r": 0.60, "tyre_w": 0.40, "wx": 1.30,
        "hull_l": 7.95, "hull_w": 2.98, "hull_h": 2.26, "aps": True, "idf": True,
        "weapon": "turret_30_unmanned", "tur_x": 0.0, "tur_z": 0.15, "atgm": "spike",
    },
    "apc__boxer": {
        "arch": "modular", "axles": [-2.45, -0.95, 0.90, 2.45], "tyre_r": 0.58, "tyre_w": 0.40, "wx": 1.30,
        "hull_l": 7.92, "hull_w": 2.99, "hull_h": 2.24, "boxer_step": True,
        "weapon": "rws_50", "tur_x": 0.34, "tur_z": 0.55,
    },
    "apc__boxer_crv": {
        "arch": "modular", "axles": [-2.45, -0.95, 0.90, 2.45], "tyre_r": 0.58, "tyre_w": 0.40, "wx": 1.30,
        "hull_l": 7.92, "hull_w": 2.99, "hull_h": 2.22, "boxer_step": True,
        "weapon": "turret_30_manned", "tur_x": 0.0, "tur_z": -0.10, "atgm": "spike",
    },
    "apc__stryker": {
        "arch": "modular", "axles": [-2.12, -0.78, 0.78, 2.12], "tyre_r": 0.52, "tyre_w": 0.36, "wx": 1.16,
        "hull_l": 6.98, "hull_w": 2.72, "hull_h": 2.02, "stowage_rails": True,
        "weapon": "rws_50", "tur_x": 0.28, "tur_z": 0.45,
    },
    "apc__amv_xp_japan": {
        "arch": "modular", "axles": [-2.42, -0.88, 0.88, 2.42], "tyre_r": 0.58, "tyre_w": 0.39, "wx": 1.26,
        "hull_l": 7.90, "hull_w": 2.90, "hull_h": 2.18, "trim_vane": True,
        "weapon": "rws_50", "tur_x": 0.26, "tur_z": 0.48,
    },
    "apc__lav_700": {
        "arch": "modular", "axles": [-2.46, -0.90, 0.90, 2.46], "tyre_r": 0.58, "tyre_w": 0.39, "wx": 1.28,
        "hull_l": 8.05, "hull_w": 2.96, "hull_h": 2.20,
        "weapon": "turret_30_unmanned", "tur_x": 0.0, "tur_z": 0.10,
    },
    "apc__vbm_freccia": {
        "arch": "modular", "axles": [-2.35, -0.86, 0.86, 2.35], "tyre_r": 0.56, "tyre_w": 0.38, "wx": 1.26,
        "hull_l": 7.85, "hull_w": 2.92, "hull_h": 2.06,
        "weapon": "turret_30_manned", "tur_x": 0.0, "tur_z": -0.08, "atgm": "spike_dual",
    },
    "apc__k808_apc": {
        "arch": "modular", "axles": [-2.25, -0.82, 0.82, 2.25], "tyre_r": 0.55, "tyre_w": 0.38, "wx": 1.20,
        "hull_l": 7.40, "hull_w": 2.76, "hull_h": 2.08, "waterjets": True, "trim_vane": True,
        "weapon": "cupola_50", "tur_x": 0.28, "tur_z": 0.35,
    },
    "apc__type_96_apc": {
        "arch": "modular", "axles": [-2.08, -0.76, 0.76, 2.08], "tyre_r": 0.50, "tyre_w": 0.35, "wx": 1.08,
        "hull_l": 6.84, "hull_w": 2.48, "hull_h": 1.86,
        "weapon": "cupola_50", "tur_x": 0.32, "tur_z": 0.42,
    },
    "apc__whap": {
        "arch": "modular", "axles": [-2.38, -0.86, 0.86, 2.38], "tyre_r": 0.56, "tyre_w": 0.39, "wx": 1.26,
        "hull_l": 7.75, "hull_w": 2.92, "hull_h": 2.14, "waterjets": True, "trim_vane": True,
        "weapon": "turret_30_unmanned", "tur_x": 0.0, "tur_z": 0.05,
    },
    "apc__zbl_08": {
        "arch": "modular", "axles": [-2.38, -0.86, 0.86, 2.38], "tyre_r": 0.55, "tyre_w": 0.38, "wx": 1.28,
        "hull_l": 7.95, "hull_w": 2.96, "hull_h": 2.04, "waterjets": True, "trim_vane": True,
        "weapon": "turret_30_manned", "tur_x": 0.0, "tur_z": -0.05, "atgm": "cheek_rails",
    },
    "apc__vbtp_guarani": {
        "arch": "modular", "axles": [-2.05, 0.0, 2.05], "tyre_r": 0.56, "tyre_w": 0.38, "wx": 1.18,
        "hull_l": 6.92, "hull_w": 2.70, "hull_h": 2.18, "waterjets": True,
        "weapon": "rws_50", "tur_x": 0.0, "tur_z": 0.25,
    },

    # --- B. Armoured Ballistic-Windshield Cab APCs & Heavy MRAPs ---
    "apc__pars": {
        "arch": "cab_nose", "axles": [-2.38, -0.86, 0.86, 2.38], "tyre_r": 0.56, "tyre_w": 0.39, "wx": 1.24,
        "hull_l": 7.96, "hull_w": 2.86, "hull_h": 2.16,
        "weapon": "turret_30_unmanned", "tur_x": 0.0, "tur_z": 0.10,
    },
    "apc__griffon": {
        "arch": "mrap_cab", "axles": [-2.25, -0.68, 2.15], "tyre_r": 0.58, "tyre_w": 0.39, "wx": 1.14,
        "hull_l": 7.58, "hull_w": 2.56, "hull_h": 2.56,
        "weapon": "rws_50", "tur_x": 0.0, "tur_z": 0.18,
    },
    "apc__anoa": {
        "arch": "cab_nose", "axles": [-1.92, -0.15, 1.92], "tyre_r": 0.52, "tyre_w": 0.36, "wx": 1.08,
        "hull_l": 6.05, "hull_w": 2.50, "hull_h": 2.08,
        "weapon": "cupola_50", "tur_x": 0.28, "tur_z": 0.35,
    },
    "apc__btr_80_typhoon_mrap": {
        "arch": "typhoon_cab", "axles": [-2.42, -0.82, 2.25], "tyre_r": 0.58, "tyre_w": 0.40, "wx": 1.16,
        "hull_l": 7.95, "hull_w": 2.58, "hull_h": 2.68, "east_hub": True,
        "weapon": "rws_50", "tur_x": 0.0, "tur_z": -0.35,
    },
    "apc__rakhsh": {
        "arch": "cab_nose", "axles": [-1.85, 1.85], "tyre_r": 0.52, "tyre_w": 0.35, "wx": 1.08,
        "hull_l": 6.06, "hull_w": 2.50, "hull_h": 2.06, "east_hub": True,
        "weapon": "cupola_50", "tur_x": 0.0, "tur_z": 0.05,
    },

    # --- C. Soviet / Ukrainian / DPRK BTR 8x8 Boat-Hull Family ---
    "apc__btr_82a": {
        "arch": "btr_boat", "axles": [-2.35, -1.05, 0.95, 2.25], "tyre_r": 0.54, "tyre_w": 0.37, "wx": 1.24,
        "hull_l": 7.65, "hull_w": 2.90, "hull_h": 1.92, "east_hub": True,
        "weapon": "bppu_30", "tur_x": 0.0, "tur_z": 0.72,
    },
    "apc__btr_80a_btr_70": {
        "arch": "btr_boat", "axles": [-2.35, -1.05, 0.95, 2.25], "tyre_r": 0.54, "tyre_w": 0.37, "wx": 1.24,
        "hull_l": 7.65, "hull_w": 2.90, "hull_h": 1.90, "east_hub": True,
        "weapon": "bpu_145", "tur_x": 0.0, "tur_z": 0.72,
    },
    "apc__btr_60_bmp_1": {
        "arch": "btr_boat", "axles": [-2.28, -1.02, 0.92, 2.18], "tyre_r": 0.52, "tyre_w": 0.36, "wx": 1.22,
        "hull_l": 7.50, "hull_w": 2.84, "hull_h": 1.86, "east_hub": True, "flat_rear": True,
        "weapon": "bpu_145", "tur_x": 0.0, "tur_z": 0.68,
    },
    "apc__btr_60_mrap": {
        "arch": "btr_boat", "axles": [-2.28, -1.02, 0.92, 2.18], "tyre_r": 0.52, "tyre_w": 0.36, "wx": 1.22,
        "hull_l": 7.50, "hull_w": 2.84, "hull_h": 1.90, "east_hub": True, "slat_cage": True,
        "weapon": "cupola_50", "tur_x": 0.0, "tur_z": 0.65,
    },
    "apc__btr_4": {
        "arch": "cab_nose", "axles": [-2.38, -0.88, 0.88, 2.38], "tyre_r": 0.55, "tyre_w": 0.38, "wx": 1.24,
        "hull_l": 7.76, "hull_w": 2.90, "hull_h": 2.12, "east_hub": True, "waterjets": True,
        "weapon": "parus_30", "tur_x": 0.0, "tur_z": 0.12,
    },
    "apc__btr_4_m113": {
        "arch": "modular", "axles": [-2.38, -0.88, 0.88, 2.38], "tyre_r": 0.55, "tyre_w": 0.38, "wx": 1.24,
        "hull_l": 7.82, "hull_w": 2.92, "hull_h": 2.14, "east_hub": True, "waterjets": True,
        "weapon": "parus_30", "tur_x": 0.0, "tur_z": 0.12,
    },
    "apc__btr_3un_proforce_ara": {
        "arch": "btr_boat", "axles": [-2.35, -1.05, 0.95, 2.25], "tyre_r": 0.54, "tyre_w": 0.37, "wx": 1.24,
        "hull_l": 7.65, "hull_w": 2.90, "hull_h": 1.96, "east_hub": True,
        "weapon": "parus_30", "tur_x": 0.0, "tur_z": 0.55,
    },
    "apc__m_2010": {
        "arch": "btr_boat", "axles": [-2.35, -1.05, 0.95, 2.25], "tyre_r": 0.54, "tyre_w": 0.37, "wx": 1.24,
        "hull_l": 7.65, "hull_w": 2.90, "hull_h": 1.92, "east_hub": True,
        "weapon": "dprk_dual_145", "tur_x": 0.0, "tur_z": 0.68,
    },
}


# =============================================================================
# HULL ARCHITECTURES
# =============================================================================

def _add_lower_chassis(hull, s, lod):
    tr, tw, wx = s["tyre_r"], s["tyre_w"], s["wx"]
    hl = s["hull_l"] * 0.5
    tub_w = wx - tw * 0.56 - 0.05
    belly_prof = [
        (-hl + 0.22, 1.22),
        (-hl + 0.60, 0.56),
        (hl - 1.05, 0.56),
        (hl + 0.05, 1.38),
        (hl - 0.85, 1.22),
    ]
    hull.profile_x("paint", belly_prof, -tub_w, tub_w, bevel=0.016 if not lod else 0.0, tint=(0.82, 0.83, 0.80))
    for az in s["axles"]:
        hull.cyl("metal_dark", (-wx, tr, az), 0.08, wx * 2.0, axis="x", seg=8)


def _build_hull(slug, s, lod):
    hull = Part("Hull")
    _add_lower_chassis(hull, s, lod)
    tr, wx = s["tyre_r"], s["wx"]
    hl, hw, hh = s["hull_l"] * 0.5, s["hull_w"] * 0.5, s["hull_h"]
    arch = s["arch"]

    if arch == "modular":
        # High mine-resistant NATO / IDF 8x8 or 6x6 modular sloped V-hull!
        prof = [
            (-hl, 1.24),
            (-hl + 0.18, 1.18),
            (hl - 0.90, 1.18),
            (hl + 0.18, 1.54),
            (hl + 0.06, 1.72),
            (hl - 1.38, hh),
            (-hl + 0.08, hh),
        ]
        hull.profile_x("paint", prof, -hw * 0.82, hw * 0.82, bevel=0.020 if not lod else 0.0, ao_y=(0.55, hh + 0.3))
        if s.get("boxer_step"):
            hull.box("paint", (-hw * 0.80, hh, -hl + 0.12), (hw * 0.80, hh + 0.16, 0.42), bevel=0.014 if not lod else 0.0)
        for sx in (-1, 1):
            hull.wedge("paint", (sx * hw, 1.24, -hl + 0.08), (sx * (hw * 0.82), hh, hl - 0.28),
                       axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.014 if not lod else 0.0)
            if not lod:
                for m_i in range(5):
                    mz0 = -hl + 0.18 + m_i * ((2 * hl - 0.65) / 5.0)
                    mz1 = mz0 + ((2 * hl - 0.65) / 5.0) - 0.04
                    hull.box("paint", (sx * (hw - 0.02), 1.30, mz0), (sx * (hw + 0.04), hh - 0.18, mz1),
                             bevel=0.008, tint=(0.97 + 0.02 * (m_i % 2),) * 3)
                if s.get("stowage_rails"):
                    for ry in (1.42, 1.76):
                        hull.cyl("metal_dark", (sx * (hw + 0.07), ry, -hl + 0.35), 0.018, 2 * hl - 1.15, axis="z", seg=6)
                if s.get("aps"):
                    # IDF Iron Fist APS radars & twin interceptor launchers on Eitan!
                    hull.box("paint", (sx * (hw * 0.84), hh - 0.08, -1.65), (sx * (hw * 1.02), hh + 0.18, -1.05), bevel=0.008)
                    for dz in (-0.12, 0.12):
                        hull.cyl("metal_dark", (sx * (hw * 0.94), hh + 0.24, -1.35 + dz), 0.052, 0.26, axis="z", seg=8)
                if s.get("idf"):
                    add_idf_chevron_x(hull, sx * (hw + 0.044), 1.56, 0.0, sx, arm_len=0.19, mode="down")
                else:
                    add_nato_diamond(hull, sx * (hw + 0.044), 1.58, 0.0, sx, size=0.13)

        if not lod:
            hull.box("dark", (0.16, hh - 0.06, hl - 1.35), (hw * 0.72, hh + 0.02, hl - 0.45))
            hull.cyl("paint", (-0.48, hh, hl - 1.18), 0.25, 0.055, seg=14, bevel=0.008)
            for dx in (-0.12, 0.0, 0.12):
                hull.box("glass", (-0.48 + dx - 0.035, hh + 0.02, hl - 0.92), (-0.48 + dx + 0.035, hh + 0.075, hl - 0.88), tint=OPTIC_COOL)
            if s.get("trim_vane"):
                hull.box("paint", (-hw * 0.82, 1.52, hl + 0.04), (hw * 0.82, 1.72, hl + 0.16), bevel=0.008)
            hull.box("paint", (-hw * 0.65, 0.84, -hl - 0.08), (hw * 0.65, hh - 0.12, -hl + 0.02), bevel=0.014, tint=(0.92, 0.92, 0.90))

    elif arch in ("cab_nose", "mrap_cab", "typhoon_cab"):
        # Ballistic-windshield armoured cab nose (Pars / BTR-4E / Anoa / Griffon / Typhoon-K)!
        cab_h = hh
        if arch == "mrap_cab":
            # Griffon 6x6: armored engine hood in front + tall 3-pane ballistic windshield cab + troop box!
            hull.box("paint", (-hw * 0.82, 1.20, hl - 1.55), (hw * 0.82, 1.88, hl + 0.05), bevel=0.02 if not lod else 0.0)
            prof = [(-hl, 1.26), (hl - 1.55, 1.26), (hl - 1.55, 1.88), (hl - 1.95, cab_h), (-hl + 0.06, cab_h)]
            hull.profile_x("paint", prof, -hw * 0.92, hw * 0.92, bevel=0.022 if not lod else 0.0, ao_y=(0.6, cab_h))
            if not lod:
                hull.box("dark", (-hw * 0.62, 1.32, hl + 0.02), (hw * 0.62, 1.76, hl + 0.07))
                ws_pitch = math.atan2(cab_h - 1.88, -0.40)
                for wx_c in (-0.54, 0.0, 0.54):
                    hull.box("glass", (wx_c - 0.23, 1.98, hl - 1.78), (wx_c + 0.23, cab_h - 0.10, hl - 1.66), tint=GLASS_ARMOUR)
        elif arch == "typhoon_cab":
            # KamAZ Typhoon-K 6x6: massive cab-over-engine flat sloped ballistic windshield + slightly raised rear troop module!
            prof = [(-hl, 1.28), (hl - 0.05, 1.28), (hl + 0.08, 1.82), (hl - 0.38, cab_h - 0.08), (-hl + 0.05, cab_h - 0.08)]
            hull.profile_x("paint", prof, -hw * 0.94, hw * 0.94, bevel=0.022 if not lod else 0.0, ao_y=(0.6, cab_h))
            hull.box("paint", (-hw * 0.96, cab_h - 0.12, -hl + 0.06), (hw * 0.96, cab_h + 0.06, hl - 2.15), bevel=0.018 if not lod else 0.0)
            if not lod:
                for sx in (-1, 1):
                    hull.box("glass", (sx * 0.10, 1.92, hl - 0.26), (sx * (hw * 0.80), cab_h - 0.18, hl - 0.10), tint=GLASS_ARMOUR)
                    hull.box("glass", (sx * (hw * 0.92), 1.92, hl - 1.55), (sx * (hw * 0.96), cab_h - 0.20, hl - 0.55), tint=GLASS_ARMOUR)
        else:
            # Pars III / BTR-4E / Anoa / Rakhsh: sleek sloped APC hull with twin armoured driver/commander ballistic windshields!
            prof = [(-hl, 1.22), (hl - 0.75, 1.22), (hl + 0.15, 1.52), (hl - 0.55, cab_h), (-hl + 0.06, cab_h)]
            hull.profile_x("paint", prof, -hw * 0.88, hw * 0.88, bevel=0.020 if not lod else 0.0, ao_y=(0.55, cab_h))
            for sx in (-1, 1):
                hull.wedge("paint", (sx * hw, 1.22, -hl + 0.08), (sx * (hw * 0.88), cab_h, hl - 0.60),
                           axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.012 if not lod else 0.0)
                if not lod:
                    hull.box("glass", (sx * 0.12, 1.62, hl - 0.35), (sx * (hw * 0.74), cab_h - 0.12, hl - 0.15), tint=GLASS_ARMOUR)
                    hull.box("glass", (sx * (hw * 0.87), 1.62, hl - 1.05), (sx * (hw * 0.93), cab_h - 0.14, hl - 0.52), tint=GLASS_ARMOUR)

        if not lod:
            for sx in (-1, 1):
                add_nato_diamond(hull, sx * (hw * 0.96), 1.58, -0.45, sx, size=0.13)
            hull.box("paint", (-hw * 0.64, 0.90, -hl - 0.08), (hw * 0.64, cab_h - 0.18, -hl + 0.02), bevel=0.014, tint=(0.92, 0.92, 0.90))

    else:
        # C. Soviet / Ukrainian / DPRK BTR-60 / BTR-70 / BTR-80 / BTR-82A 8x8 Amphibious Boat Hull!
        rear_top = hh - (0.14 if s.get("flat_rear") else 0.02)
        prof = [
            (-hl, 1.18),
            (-hl + 0.35, 1.08),
            (hl - 0.95, 1.08),
            (hl + 0.22, 1.44),
            (hl + 0.08, 1.58),
            (hl - 1.10, hh),
            (-0.65, hh),
            (-hl + 0.12, rear_top),
        ]
        hull.profile_x("paint", prof, -hw * 0.78, hw * 0.78, bevel=0.018 if not lod else 0.0, ao_y=(0.55, hh + 0.3))
        # Characteristic inward-sloped upper tumblehome & outward lower chine of BTR boat hull!
        for sx in (-1, 1):
            hull.wedge("paint", (sx * hw, 1.36, -hl + 0.14), (sx * (hw * 0.78), hh, hl - 0.35),
                       axis="y", slope_dir="-x" if sx < 0 else "+x", bevel=0.012 if not lod else 0.0)
            hull.box("paint", (sx * (hw * 0.78), 1.14, -hl + 0.14), (sx * hw, 1.38, hl - 0.20), bevel=0.010 if not lod else 0.0)
            if not lod:
                # Signature BTR split upper/lower side troop hatch in the wide gap between axles 2 and 3!
                hull.box("paint", (sx * (hw - 0.02), 1.12, -0.45), (sx * (hw + 0.03), hh - 0.14, 0.32), bevel=0.008, tint=(0.92, 0.93, 0.90))
                # 3 side infantry firing ports
                for fz in (-1.35, 0.55, 1.45):
                    hull.cyl("metal_dark", (sx * (hw - 0.04), 1.54, fz), 0.045, 0.06, axis="x", seg=8)
                # Twin rear raised exhaust pipes on BTR-80 / BTR-82A!
                if not s.get("flat_rear"):
                    hull.pipe("metal_dark", (sx * 0.82, rear_top - 0.04, -hl + 0.55), (sx * 0.92, rear_top + 0.16, -hl - 0.08), 0.065, seg=10)
                if s.get("slat_cage"):
                    for by in (1.18, 1.42, 1.66):
                        hull.box("metal_dark", (sx * (hw + 0.12), by, -hl + 0.25), (sx * (hw + 0.14), by + 0.025, hl - 0.35))
                add_nato_diamond(hull, sx * (hw + 0.005), 1.30, -1.65, sx, size=0.11)

        if not lod:
            # Bow wave-breaker vane + twin armoured driver/commander windshield hatches + central waterjet!
            hull.box("paint", (-hw * 0.72, 1.48, hl + 0.06), (hw * 0.72, 1.66, hl + 0.18), bevel=0.008)
            for sx in (-1, 1):
                hull.box("paint", (sx * 0.12, 1.64, hl - 0.72), (sx * 0.68, hh - 0.04, hl - 0.38), bevel=0.008, tint=(0.93, 0.94, 0.91))
                hull.box("glass", (sx * 0.18, 1.68, hl - 0.40), (sx * 0.62, hh - 0.08, hl - 0.36), tint=OPTIC_COOL)
            hull.cyl("dark", (0.0, 1.28, -hl - 0.03), 0.22, 0.05, axis="z", seg=14)
            hull.box("dark", (-0.65, rear_top - 0.01, -hl + 0.45), (0.65, rear_top + 0.02, -1.15))

    # Common headlights, taillights & rear whip antennas
    if not lod:
        for sx in (-1, 1):
            hull.cyl("glass", (sx * (hw * 0.74), 1.50, hl + 0.04), 0.048, 0.03, axis="z", seg=10, tint=(1.8, 1.8, 1.6))
            hull.box("glass", (sx * (hw * 0.74), 1.38, -hl - 0.02), (sx * (hw * 0.88), 1.48, -hl + 0.02), tint=TAIL_RED)
            if s.get("waterjets"):
                hull.tube_axis("dark", (sx * 0.74, 0.96, -hl - 0.04), (sx * 0.74, 0.96, -hl + 0.05), 0.12, 0.09, seg=10)
        hull.cyl("metal_dark", (-hw * 0.72, hh, -hl + 0.42), 0.030, 0.12, seg=8)
        hull.cyl("dark", (-hw * 0.72, hh + 0.12, -hl + 0.42), 0.011, 1.05, seg=6)
    return hull


# =============================================================================
# WEAPON STATIONS (`Turret` + `Gun` + `Muzzle`, all with 0.7 < muzzle < 8.5 m!)
# =============================================================================

def _attach_weapon(rig, s, lod):
    wtype = s["weapon"]
    tx, tz = s["tur_x"], s["tur_z"]
    hh = s["hull_h"] + (0.16 if s.get("boxer_step") and tz < 0.42 else 0.0)
    t_piv = (tx, hh + 0.02, tz)

    turret = Part("Turret")
    gun = Part("Gun")

    if wtype in ("rws_50", "cupola_50"):
        # Samson / CROWS / FLW 200 / Hornet RWS or Shielded .50 cal Cupola
        turret.cyl("metal_dark", (tx, hh, tz), 0.28, 0.08, seg=14, bevel=0.006)
        if wtype == "cupola_50":
            # Armoured gun-shield cupola around gunner hatch
            for sx in (-1, 1):
                turret.box("paint", (tx + sx * 0.24, hh + 0.08, tz - 0.24), (tx + sx * 0.30, hh + 0.44, tz + 0.28), bevel=0.006)
            turret.box("paint", (tx - 0.28, hh + 0.08, tz + 0.24), (tx + 0.28, hh + 0.46, tz + 0.30), bevel=0.006)
        else:
            turret.box("paint", (tx - 0.18, hh + 0.08, tz - 0.18), (tx + 0.18, hh + 0.44, tz + 0.20), bevel=0.010 if not lod else 0.0)
            turret.box("paint", (tx + 0.18, hh + 0.14, tz - 0.12), (tx + 0.42, hh + 0.40, tz + 0.22), bevel=0.008 if not lod else 0.0)
            if not lod:
                turret.box("glass", (tx + 0.21, hh + 0.18, tz + 0.215), (tx + 0.39, hh + 0.36, tz + 0.23), tint=OPTIC_FLIR)
                turret.box("paint", (tx - 0.42, hh + 0.16, tz - 0.16), (tx - 0.18, hh + 0.40, tz + 0.16), bevel=0.008)

        g_piv = (tx, hh + 0.36, tz + 0.14)
        gy, gz = g_piv[1], g_piv[2]
        gun.box("metal_dark", (tx - 0.08, gy - 0.08, gz - 0.18), (tx + 0.08, gy + 0.08, gz + 0.28), bevel=0.006 if not lod else 0.0)
        gun.cyl("metal_dark", (tx, gy, gz + 0.28), 0.034, 0.34, axis="z", seg=10)
        gun.cyl("metal_dark", (tx, gy, gz + 0.62), 0.018, 0.56, axis="z", seg=10)
        muz_pt = (tx, gy, gz + 1.22)  # dist from t_piv = hypot(0.34, 1.36) = 1.40 m (> 0.7 m!)
        gun.tube_axis("metal_dark", (tx, gy, gz + 1.14), muz_pt, 0.028, 0.014, seg=8)

    elif wtype in ("bpu_145", "dprk_dual_145"):
        # Classic Soviet Conical BPU-1 Turret (`14.5mm KPVT + 7.62mm PKT`)
        seg_t = 10 if lod else 20
        b_pts = [(tx + 0.72 * math.sin(math.tau * i / seg_t), tz + 0.74 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
        t_pts = [(tx + 0.48 * math.sin(math.tau * i / seg_t), tz + 0.50 * math.cos(math.tau * i / seg_t)) for i in range(seg_t)]
        turret.frustum_xz("paint", b_pts, t_pts, hh + 0.02, hh + 0.48, bevel=0.012 if not lod else 0.0)
        if not lod:
            for k in range(6):
                turret.cyl("metal_dark", (tx - 0.30 + k * 0.12, hh + 0.22, tz - 0.72), 0.030, 0.18, axis="z", seg=8)
            turret.cyl("paint", (tx - 0.28, hh + 0.48, tz + 0.10), 0.09, 0.14, seg=10)
            if wtype == "dprk_dual_145":
                turret.cyl("paint", (tx + 0.36, hh + 0.56, tz - 0.25), 0.055, 0.85, axis="z", seg=10)

        g_piv = (tx, hh + 0.28, tz + 0.56)
        gy, gz = g_piv[1], g_piv[2]
        gun.box("paint", (tx - 0.18, gy - 0.10, gz - 0.15), (tx + 0.18, gy + 0.10, gz + 0.16), bevel=0.008 if not lod else 0.0)
        if wtype == "dprk_dual_145":
            for sx in (-1, 1):
                gun.cyl("metal_dark", (tx + sx * 0.07, gy, gz + 0.14), 0.024, 1.35, axis="z", seg=10)
        else:
            gun.cyl("metal_dark", (tx, gy, gz + 0.14), 0.026, 1.38, axis="z", seg=10)
            gun.cyl("metal_dark", (tx + 0.11, gy, gz + 0.14), 0.015, 0.72, axis="z", seg=8)
        muz_pt = (tx, gy, gz + 1.54)
        gun.tube_axis("metal_dark", (tx, gy, gz + 1.46), muz_pt, 0.036, 0.018, seg=10)

    elif wtype in ("bppu_30", "parus_30"):
        # Russian BTR-82A BPPU-1 OR Ukrainian BTR-4 Parus / Shturm Overhead 30mm Module!
        turret.cyl("paint", (tx, hh, tz), 0.62, 0.34, seg=18 if not lod else 10, r2=0.52, bevel=0.012 if not lod else 0.0)
        turret.box("paint", (tx - 0.34, hh + 0.34, tz - 0.42), (tx + 0.34, hh + 0.72, tz + 0.32), bevel=0.010 if not lod else 0.0)
        if not lod:
            turret.box("glass", (tx - 0.30, hh + 0.44, tz + 0.315), (tx - 0.12, hh + 0.62, tz + 0.33), tint=OPTIC_FLIR)
            for sx in (-1, 1):
                for k in range(3):
                    turret.cyl("metal_dark", (tx + sx * 0.44, hh + 0.22, tz + 0.18 - k * 0.09), 0.030, 0.17, axis="z", seg=8)
            if wtype == "parus_30":
                # Twin Ukrainian Barrier ATGM launch tubes on right side of Parus/Shturm module!
                for dy in (0.44, 0.62):
                    turret.tube_axis("paint", (tx + 0.44, hh + dy, tz - 0.52), (tx + 0.44, hh + dy, tz + 0.56), 0.075, 0.060, seg=10)

        g_piv = (tx, hh + 0.56, tz + 0.24)
        gy, gz = g_piv[1], g_piv[2]
        gun.box("metal_dark", (tx - 0.14, gy - 0.10, gz - 0.16), (tx + 0.14, gy + 0.10, gz + 0.22), bevel=0.008 if not lod else 0.0)
        gun.cyl("metal_dark", (tx, gy, gz + 0.22), 0.030, 1.92, axis="z", seg=10)
        if not lod:
            # Signature BPPU / ZTM-1 dual-strut barrel stabilization cage!
            gun.pipe("metal_dark", (tx, gy + 0.12, gz + 0.18), (tx, gy + 0.04, gz + 1.35), 0.016, seg=6)
        muz_pt = (tx, gy, gz + 2.22)
        gun.tube_axis("metal_dark", (tx, gy, gz + 2.12), muz_pt, 0.045, 0.022, seg=10)

    else:
        # Modern 30mm Unmanned or Manned Turret (`eitan_series_2023`, `boxer_crv`, `vbm_freccia`, `zbl_08`, `whap`, `pars`, `lav_700`)
        manned = wtype == "turret_30_manned"
        tw_b = 0.88 if manned else 0.72
        th = 0.58 if manned else 0.50
        b_pts = [(-0.52 * tw_b, 0.92), (0.52 * tw_b, 0.92), (tw_b, 0.22), (0.88 * tw_b, -0.98), (-0.88 * tw_b, -0.98), (-tw_b, 0.22)]
        turret.frustum_xz("paint", [(x + tx, z + tz) for x, z in b_pts], [(x * 0.78 + tx, z * 0.84 + tz) for x, z in b_pts],
                          hh + 0.02, hh + 0.02 + th, bevel=0.016 if not lod else 0.0)
        ty_top = hh + 0.02 + th
        if not lod:
            turret.box("paint", (tx - 0.42, ty_top, tz + 0.10), (tx - 0.14, ty_top + 0.22, tz + 0.46), bevel=0.008)
            turret.box("glass", (tx - 0.38, ty_top + 0.04, tz + 0.455), (tx - 0.18, ty_top + 0.18, tz + 0.47), tint=OPTIC_FLIR)
            turret.cyl("paint", (tx + 0.24, ty_top, tz - 0.22), 0.12, 0.12, seg=12)
            turret.box("paint", (tx + 0.10, ty_top + 0.12, tz - 0.35), (tx + 0.38, ty_top + 0.32, tz - 0.08), bevel=0.008)
            turret.box("glass", (tx + 0.14, ty_top + 0.16, tz - 0.085), (tx + 0.34, ty_top + 0.28, tz - 0.07), tint=OPTIC_COOL)
            atgm = s.get("atgm")
            if atgm == "spike":
                turret.box("paint", (tx - tw_b - 0.26, hh + 0.16, tz - 0.48), (tx - tw_b + 0.02, ty_top - 0.04, tz + 0.42), bevel=0.010)
            elif atgm == "spike_dual":
                for sx in (-1, 1):
                    turret.box("paint", (tx + sx * tw_b, hh + 0.18, tz - 0.48), (tx + sx * (tw_b + 0.24), ty_top - 0.06, tz + 0.42), bevel=0.010)
            elif atgm == "cheek_rails":
                for sx in (-1, 1):
                    turret.cyl("paint", (tx + sx * (tw_b + 0.14), hh + 0.36, tz - 0.42), 0.07, 0.92, axis="z", seg=10)

        g_piv = (tx, hh + 0.02 + th * 0.48, tz + 0.76)
        gy, gz = g_piv[1], g_piv[2]
        gun.box("paint", (tx - 0.18, gy - 0.13, gz - 0.18), (tx + 0.18, gy + 0.13, gz + 0.18), bevel=0.010 if not lod else 0.0)
        gun.cyl("paint", (tx, gy, gz + 0.16), 0.062, 0.58, axis="z", seg=12)
        gun.cyl("metal_dark", (tx, gy, gz + 0.74), 0.034, 1.48, axis="z", seg=10)
        muz_pt = (tx, gy, gz + 2.30)
        gun.tube_axis("metal_dark", (tx, gy, gz + 2.20), muz_pt, 0.052, 0.026, seg=10)

    rig.add("Turret", "Hull", t_piv, turret)
    rig.add("Gun", "Turret", g_piv, gun)
    rig.add("Muzzle", "Gun", muz_pt, None)


def build_wheeled_apc_rig(slug, lod=0):
    s = APC_SPECS[slug]
    rig = VehicleRig(lod=lod)
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), _build_hull(slug, s, lod))

    tr, tw, wx = s["tyre_r"], s["tyre_w"], s["wx"]
    hub = "eastern" if s.get("east_hub") else "western"
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(s["axles"]):
            wp = (sx * wx, tr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp,
                    build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=tr, w=tw, hub_style=hub))

    _attach_weapon(rig, s, lod)
    return rig


def export_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for slug, spec in APC_SPECS.items():
        if only and slug != only:
            continue
        init_scene()
        ring_r = 0.28 if spec["weapon"] in ("rws_50", "cupola_50") else 0.56
        export_vehicle(
            os.path.join(out_dir, f"{slug}.glb"),
            build_wheeled_apc_rig(slug, 0),
            build_wheeled_apc_rig(slug, 1),
            turret_offset=(3.9, 0.0, 0.1),
            ring_radius=ring_r,
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
