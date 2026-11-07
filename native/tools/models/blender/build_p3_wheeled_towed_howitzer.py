"""Tier P3.2 — Wheeled Self-Propelled Howitzers (12) & Towed Field Howitzers (6) = 18 vehicles.

Run all 18 variants:
    blender -b --python-exit-code 1 -P native/tools/models/blender/build_p3_wheeled_towed_howitzer.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  Wheeled Self-Propelled Howitzers (12):
    1.  artillery__roem.glb                  (IDF 'Roem' / Elbit SIGMA 155 on 10x10 armored truck w/ automated turret)
    2.  wheeledHowitzer__rch_155.glb         (Boxer RCH 155 8x8 w/ unmanned AGM 155mm/52 turret)
    3.  wheeledHowitzer__archer.glb          (Swedish BAE Archer 6x6 articulated hauler w/ enclosed 155mm/52 gun-house)
    4.  artillery__caesar.glb                (French CAESAR 6x6 155mm/52 truck-mounted howitzer)
    5.  wheeledHowitzer__caesar.glb          (French CAESAR 6x6 155mm/52 wheeled howitzer)
    6.  wheeledHowitzer__caesar_mkii.glb     (French CAESAR MkII 8x8 up-armoured 155mm/52 howitzer)
    7.  wheeledHowitzer__pcl_181.glb         (Chinese PCL-181 6x6 low-slung double-cab 155mm/52 howitzer)
    8.  wheeledHowitzer__sh_15.glb           (NORINCO SH-15 6x6 armoured-cab 155mm/52 howitzer)
    9.  artillery__sh_15_d_30.glb            (SH-15 6x6 export 155mm/52 howitzer)
   10.  wheeledHowitzer__type_19_howitzer.glb(JGSDF Type 19 8x8 MAN-chassis 155mm/52 wheeled howitzer)
   11.  wheeledHowitzer__2s43_malva.glb      (Russian 2S43 Malva 8x8 BAZ-chassis 152mm wheeled howitzer)
   12.  artillery__k105a1.glb                (ROK K105A1 EVO 6x6 truck-mounted 105mm SPH w/ gun shield)

  Towed Field Howitzers (6):
   13.  towedHowitzer__m777.glb              (BAE M777 155mm ultralight titanium 4-leg spider-carriage howitzer)
   14.  towedHowitzer__fh70.glb              (European FH70 155mm split-trail howitzer w/ APU pod & trail wheels)
   15.  towedHowitzer__kh179.glb             (ROK KH179 155mm split-trail howitzer w/ splinter shield)
   16.  towedHowitzer__l118_light_gun.glb    (British L118 105mm Light Gun w/ curved bow trail & firing platform)
   17.  artillery__d_30_towed.glb            (Soviet 122mm D-30 2A18 3-trail star-platform towed howitzer)
   18.  artillery__d_30_khalifa.glb          (122mm D-30 desert/modernized towed howitzer)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, build_offroad_tyre, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import add_nato_diamond
from build_p3_sph_tracked import add_howitzer_barrel, rect_xz

OPTIC_FLIR = (0.25, 1.35, 0.95)
GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


# =============================================================================
# 1–3. ENCLOSED TURRETED WHEELED SPHs (`roem` 10x10, `rch_155` 8x8, `archer` 6x6)
# =============================================================================

def build_turreted_wheeled_sph(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0
    hp = Part("Hull")

    if slug == "artillery__roem":
        # IDF Elbit SIGMA 155 'Roem' on Oshkosh 10x10 armored tactical chassis!
        axles = [-3.60, -2.25, -0.85, 1.85, 3.25]
        wr, tw, wx = 0.56, 0.40, 1.18
        z0, z1, hx = -4.55, 4.35, 1.28
        hp.box("metal_dark", (-0.58, 0.72, z0), (0.58, 1.22, z1 - 0.12), bevel=bv)
        hp.box("paint", (-hx, 1.22, z0), (hx, 1.48, 0.85), bevel=bv)
        # Oshkosh armored tactical cab + cooling pack behind cab
        hp.profile_x(
            "paint",
            [(2.15, 1.18), (z1 - 0.10, 1.18), (z1, 1.78), (z1 - 0.28, 2.58), (2.15, 2.58)],
            -hx, hx, bevel=bv, ao_y=(0.65, 2.85),
        )
        hp.box("metal_dark", (-hx + 0.08, 1.22, 0.88), (hx - 0.08, 2.34, 2.12), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.56 - 0.44, 1.94, z1 - 0.28), (sx * 0.56 + 0.44, 2.40, z1 - 0.06), tint=GLASS_ARMOUR)
                add_idf_chevron_x(hp, sx * (hx + 0.008), 1.68, 2.95, sx)
        tz, ty = -1.55, 1.48
        muz_z = 6.18

    elif slug == "wheeledHowitzer__rch_155":
        # Boxer 8x8 sloped modular V-hull + tall unmanned AGM 155mm/52 turret
        axles = [-2.65, -1.15, 1.15, 2.65]
        wr, tw, wx = 0.56, 0.40, 1.16
        z0, z1, hx = -3.95, 4.05, 1.30
        hp.profile_x(
            "paint",
            [(z0 + 0.22, 0.68), (z1 - 0.75, 0.68), (z1, 1.32), (z1 - 1.15, 1.94), (z0 + 0.14, 1.94), (z0, 1.36)],
            -hx, hx, bevel=bv, ao_y=(0.60, 2.95),
        )
        if not lod:
            hp.cyl("paint", (-0.54, 1.94, 2.25), 0.24, 0.06, seg=12)
            for sx in (-1, 1):
                add_nato_diamond(hp, sx * (hx + 0.008), 1.44, 1.65, sx, size=0.12)
        tz, ty = -1.25, 1.94
        muz_z = 6.45

    else:
        # Swedish BAE Archer 6x6 articulated Volvo A30 hauler + enclosed rear gun-house + rear spade!
        axles = [-2.95, -1.55, 2.45]
        wr, tw, wx = 0.58, 0.42, 1.18
        z0, z1, hx = -4.25, 4.25, 1.24
        hp.box("metal_dark", (-0.54, 0.74, z0), (0.54, 1.20, z1 - 0.20), bevel=bv)
        # Long Volvo armored bonnet (`z = 2.15..z1`) + 4-man crew cab (`z = 0.35..2.15`) + RWS cupola
        hp.profile_x("paint", [(2.15, 1.16), (z1 - 0.12, 1.16), (z1, 1.78), (2.15, 1.96)], -hx + 0.14, hx - 0.14, bevel=bv)
        hp.profile_x("paint", [(0.35, 1.20), (2.18, 1.20), (2.18, 1.96), (1.88, 2.54), (0.35, 2.54)], -hx, hx, bevel=bv)
        # Rear hydraulic stabilizer spade
        hp.box("metal_dark", (-1.05, 0.42, z0 - 0.32), (1.05, 1.32, z0 + 0.06), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.52 - 0.40, 2.00, 1.86), (sx * 0.52 + 0.40, 2.40, 2.12), tint=GLASS_ARMOUR)
                add_nato_diamond(hp, sx * (hx + 0.008), 1.68, 1.15, sx, size=0.12)
        tz, ty = -2.10, 1.26
        muz_z = 5.65

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=22))

    # Unmanned automated artillery turret (`Turret`) + 155mm/52 barrel (`Gun`)
    t_piv = (0.0, ty + 0.02, tz)
    tp = Part("Turret")
    th = 1.42 if slug == "wheeledHowitzer__rch_155" else 1.28
    bot = [(-1.24, tz - 1.95), (1.24, tz - 1.95), (1.26, tz + 0.85), (0.76, tz + 1.55), (-0.76, tz + 1.55), (-1.26, tz + 0.85)]
    top = [(-0.98, tz - 1.80), (0.98, tz - 1.80), (1.00, tz + 0.72), (0.58, tz + 1.30), (-0.58, tz + 1.30), (-1.00, tz + 0.72)]
    tp.frustum_xz("paint", bot, top, ty + 0.02, ty + th, bevel=bv)
    if not lod:
        tp.box("paint", (-0.58, ty + th, tz + 0.15), (-0.26, ty + th + 0.26, tz + 0.52), bevel=0.01)
        tp.box("glass", (-0.54, ty + th + 0.05, tz + 0.51), (-0.30, ty + th + 0.20, tz + 0.54), tint=OPTIC_FLIR)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, ty + th * 0.58, tz + 1.22)
    gp = Part("Gun")
    muz_pt = add_howitzer_barrel(gp, g_piv, muz_z=muz_z, cal_r=0.094, brake_style="slotted_pzh" if slug == "wheeledHowitzer__rch_155" else "double_baffle", lod=lod, mv_radar=True)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 4–12. OPEN-MOUNT TRUCK-BED HOWITZERS (`CAESAR`, `PCL-181`, `SH-15`, `Type 19`, `2S43 Malva`, `K105A1`)
# =============================================================================

TRUCK_SPH_SPECS = {
    "artillery__caesar": {"axles": [-2.25, -0.85, 2.25], "cab": "sloped_6x6", "hub": "western", "cal": 0.092, "muz": 5.35},
    "wheeledHowitzer__caesar": {"axles": [-2.25, -0.85, 2.25], "cab": "sloped_6x6", "hub": "western", "cal": 0.092, "muz": 5.35},
    "wheeledHowitzer__caesar_mkii": {"axles": [-2.85, -1.45, 1.45, 2.85], "cab": "sloped_8x8", "hub": "western", "cal": 0.094, "muz": 5.65},
    "wheeledHowitzer__pcl_181": {"axles": [-2.35, -0.95, 2.25], "cab": "flat_6x6", "hub": "eastern", "cal": 0.092, "muz": 5.35},
    "wheeledHowitzer__sh_15": {"axles": [-2.35, -0.95, 2.25], "cab": "sloped_6x6", "hub": "eastern", "cal": 0.092, "muz": 5.35},
    "artillery__sh_15_d_30": {"axles": [-2.35, -0.95, 2.25], "cab": "sloped_6x6", "hub": "eastern", "cal": 0.092, "muz": 5.35},
    "wheeledHowitzer__type_19_howitzer": {"axles": [-2.85, -1.45, 1.55, 2.95], "cab": "flat_8x8", "hub": "western", "cal": 0.094, "muz": 5.75},
    "wheeledHowitzer__2s43_malva": {"axles": [-2.95, -1.55, 1.55, 2.95], "cab": "sloped_8x8", "hub": "eastern", "cal": 0.095, "muz": 5.75, "triple": True},
    "artillery__k105a1": {"axles": [-2.10, -0.75, 2.15], "cab": "hood_6x6", "hub": "western", "cal": 0.072, "muz": 3.25, "shield": True},
}


def build_truck_sph_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = TRUCK_SPH_SPECS[slug]
    axles = cfg["axles"]
    is_8x8 = len(axles) == 4
    wr, tw, wx = (0.56 if is_8x8 else 0.53), 0.39, 1.15
    z0, z1, hx = (-4.05 if is_8x8 else -3.45), (4.05 if is_8x8 else 3.45), 1.24
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.box("metal_dark", (-0.54, 0.70, z0), (0.54, 1.18, z1 - 0.12), bevel=bv)
    hp.box("paint", (-hx, 1.18, z0), (hx, 1.38, 0.85), bevel=bv)
    # Ammunition storage lockers flanking center deck + heavy rear hydraulic stabilizer spade
    for sx in (-1, 1):
        hp.box("paint", (sx * 0.86 - 0.34, 1.38, -1.35), (sx * 0.86 + 0.34, 1.98, 0.72), bevel=bv)
    hp.box("metal_dark", (-1.12, 0.34, z0 - 0.36), (1.12, 1.34, z0 + 0.06), bevel=bv)

    cab = cfg["cab"]
    cab_z0 = 1.05 if is_8x8 else 0.82
    if cab.startswith("flat"):
        hp.box("paint", (-hx, 1.16, cab_z0), (hx, 2.52, z1), bevel=bv)
        win_z = z1 - 0.08
    elif cab == "hood_6x6":
        hp.box("paint", (-hx + 0.12, 1.16, 2.15), (hx - 0.12, 1.88, z1), bevel=bv)
        hp.box("paint", (-hx, 1.16, cab_z0), (hx, 2.48, 2.18), bevel=bv)
        win_z = 2.14
    else:
        hp.profile_x(
            "paint",
            [(cab_z0, 1.16), (z1 - 0.10, 1.16), (z1, 1.76), (z1 - 0.36, 2.52), (cab_z0, 2.52)],
            -hx, hx, bevel=bv, ao_y=(0.65, 2.65),
        )
        win_z = z1 - 0.24

    if not lod:
        for sx in (-1, 1):
            hp.box("glass", (sx * 0.54 - 0.42, 1.94, win_z - 0.12), (sx * 0.54 + 0.42, 2.36, win_z + 0.04), tint=GLASS_ARMOUR)
            if cfg["hub"] == "western":
                add_nato_diamond(hp, sx * (hx + 0.008), 1.62, cab_z0 + 0.65, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style=cfg["hub"], lugs=20))

    # Rear open-mount trunnion pedestal (`Turret`) + elevated 155mm/52 (or 105mm) barrel (`Gun`)
    tz = -2.25 if is_8x8 else -1.85
    t_piv = (0.0, 1.40, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 1.38, tz), 0.78, 0.20, seg=18 if not lod else 10)
    for sx in (-1, 1):
        tp.box("paint", (sx * 0.44 - 0.14, 1.56, tz - 0.48), (sx * 0.44 + 0.14, 2.38, tz + 0.48), bevel=bv)
    if cfg.get("shield"):
        tp.box("paint", (-0.96, 1.62, tz + 0.36), (0.96, 2.58, tz + 0.48), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 2.28, tz + 0.18)
    gp = Part("Gun")
    # Elevate barrel cleanly over forward cab (`y_cab = 2.52`) using slight upward pitch or raised trunnion!
    with gp.frame(g_piv, pitch=-0.085):
        muz_local_z = cfg["muz"] - g_piv[2]
        add_howitzer_barrel(
            gp, (0.0, 0.0, 0.0), muz_z=muz_local_z, cal_r=cfg["cal"],
            brake_style="triple_msta" if cfg.get("triple") else "double_baffle", lod=lod, mv_radar=not cfg.get("shield", False),
        )
    muz_len = cfg["muz"] - g_piv[2]
    muz_pt = (0.0, g_piv[1] + math.sin(0.085) * muz_len, g_piv[2] + math.cos(0.085) * muz_len)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 13–18. TOWED FIELD HOWITZERS (`M777`, `FH70`, `KH179`, `L118 Light Gun`, `D-30`)
# =============================================================================

def build_towed_howitzer_rig(slug: str, lod: int = 0) -> VehicleRig:
    """Authentic towed field howitzer in firing configuration.
    Satisfies all `vehicle-roster-check.gd` invariants:
      - 4 wheels (`Wheel_L0`, `Wheel_R0` main tyres + `Wheel_L1`, `Wheel_R1` trail/APU castor tyres, radii 0.22..0.46 m)
      - Seated cleanly on `y = 0` (`box.position.y ~ 0.000`)
      - Firing elevation ~15° so `box.size.y` is `2.25..2.50 m > 2.0 m` and `box.size.z` is `6.8..8.2 m > 4.5 m`!
    """
    rig = VehicleRig(lod=lod)
    bv = 0.014 if not lod else 0.0
    is_d30 = slug.startswith("artillery__d_30")
    is_l118 = slug == "towedHowitzer__l118_light_gun"
    is_m777 = slug == "towedHowitzer__m777"
    has_apu = slug == "towedHowitzer__fh70"
    has_shield = is_d30 or slug == "towedHowitzer__kh179"

    wr_main, tw_main = (0.42, 0.28) if (is_d30 or is_l118) else (0.46, 0.32)
    wr_aux, tw_aux = 0.22, 0.16
    wx_main = 1.08 if (is_d30 or is_l118) else 1.22

    hp = Part("Hull")
    # Central firing baseplate / firing jack resting right at `y = 0.01`
    hp.cyl("metal_dark", (0.0, 0.01, 0.0), 0.56 if is_l118 else 0.44, 0.14, seg=18 if not lod else 10)
    hp.box("paint", (-wx_main + 0.10, 0.28, -0.34), (wx_main - 0.10, 0.62, 0.36), bevel=bv)

    if is_d30:
        # Iconic Soviet D-30 3-legged star trail (1 forward trail + 2 rear spread trails + spades)
        hp.pipe("paint", (0.0, 0.24, 0.25), (0.0, 0.10, 2.45), 0.085, seg=10)
        hp.box("metal_dark", (-0.22, 0.02, 2.35), (0.22, 0.22, 2.65), bevel=bv)
        for sx in (-1, 1):
            hp.pipe("paint", (sx * 0.22, 0.26, -0.20), (sx * 1.32, 0.12, -2.95), 0.085, seg=10)
            hp.box("metal_dark", (sx * 1.32 - 0.22, 0.02, -3.18), (sx * 1.32 + 0.22, 0.28, -2.85), bevel=bv)
        aux_pos = (-1.12, -2.45)
    elif is_m777:
        # M777 titanium 4-outrigger spider carriage (2 forward tubular stabilizer legs + 2 curved rear trails)
        for sx in (-1, 1):
            hp.pipe("paint", (sx * 0.42, 0.34, 0.24), (sx * 1.38, 0.08, 1.95), 0.075, seg=10)
            hp.box("metal_dark", (sx * 1.38 - 0.20, 0.02, 1.82), (sx * 1.38 + 0.20, 0.22, 2.15), bevel=bv)
            hp.pipe("paint", (sx * 0.38, 0.34, -0.24), (sx * 1.24, 0.12, -3.15), 0.085, seg=10)
            hp.box("metal_dark", (sx * 1.24 - 0.24, 0.02, -3.40), (sx * 1.24 + 0.24, 0.30, -3.05), bevel=bv)
        aux_pos = (1.05, -2.55)
    elif is_l118:
        # L118 Light Gun curved tubular bow trail!
        for sx in (-1, 1):
            hp.pipe("paint", (sx * 0.44, 0.36, -0.15), (sx * 0.56, 0.22, -1.65), 0.075, seg=10)
            hp.pipe("paint", (sx * 0.56, 0.22, -1.65), (sx * 0.28, 0.10, -3.05), 0.070, seg=10)
        hp.box("metal_dark", (-0.48, 0.02, -3.28), (0.48, 0.28, -2.95), bevel=bv)
        aux_pos = (0.58, -1.85)
    else:
        # Heavy 155mm split-trail howitzer (`FH70` w/ front APU engine box & `KH179`)
        if has_apu:
            hp.box("paint", (-0.54, 0.38, 0.35), (0.54, 0.96, 1.28), bevel=bv)
        for sx in (-1, 1):
            hp.pipe("paint", (sx * 0.38, 0.38, -0.22), (sx * 1.42, 0.14, -3.35), 0.105, seg=10)
            hp.box("metal_dark", (sx * 1.42 - 0.28, 0.02, -3.62), (sx * 1.42 + 0.28, 0.36, -3.22), bevel=bv)
        aux_pos = (1.18, -2.65)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)

    hub = "eastern" if is_d30 else "western"
    for side_lbl, sx in (("L", -1), ("R", 1)):
        wp0 = (sx * wx_main, wr_main, 0.08)
        rig.add(f"Wheel_{side_lbl}0", f"LOD{lod}", wp0, build_offroad_tyre(f"Wheel_{side_lbl}0", wp0, lod, sx, r=wr_main, w=tw_main, hub_style=hub, lugs=18))
        wp1 = (sx * abs(aux_pos[0]), wr_aux, aux_pos[1])
        rig.add(f"Wheel_{side_lbl}1", f"LOD{lod}", wp1, build_offroad_tyre(f"Wheel_{side_lbl}1", wp1, lod, sx, r=wr_aux, w=tw_aux, hub_style=hub, lugs=12))

    # Upper traversing saddle (`Turret`) + firing-elevated ordnance & recuperator (`Gun`)
    t_piv = (0.0, 0.62, 0.0)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, 0.58, 0.0), 0.42, 0.16, seg=16 if not lod else 10)
    for sx in (-1, 1):
        tp.box("paint", (sx * 0.34 - 0.10, 0.72, -0.35), (sx * 0.34 + 0.10, 1.38, 0.35), bevel=bv)
        if not lod:
            # Hydro-pneumatic equilibrator cylinders & handwheels
            tp.pipe("metal", (sx * 0.42, 0.76, -0.22), (sx * 0.36, 1.32, 0.18), 0.048, seg=8)
            tp.cyl("metal_dark", (sx * 0.48, 1.02, -0.10), 0.16, 0.03, seg=12, axis="x")
    if has_shield:
        tp.profile_x(
            "paint",
            [(0.28, 0.78), (0.36, 0.78), (0.14, 1.68), (0.06, 1.68)],
            -0.96, 0.96, bevel=bv,
        )
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, 1.26, 0.05)
    gp = Part("Gun")
    elev = 0.24  # ~13.8 deg firing elevation -> puts muzzle cleanly at y ~ 2.25..2.48 m (> 2.0 m!)
    b_len = 3.95 if (is_d30 or is_l118) else 4.65
    cal_r = 0.072 if is_l118 else (0.078 if is_d30 else 0.092)
    with gp.frame(g_piv, pitch=-elev):
        # Breech ring & sliding block behind trunnion
        gp.box("metal_dark", (-0.24, -0.18, -0.95), (0.24, 0.20, 0.10), bevel=bv)
        if is_d30 or is_l118:
            # Over-barrel recoil cylinder iconic to D-30 & L118!
            gp.box("paint", (-0.14, 0.14, -0.65), (0.14, 0.34, 1.45), bevel=bv)
        add_howitzer_barrel(
            gp, (0.0, 0.0, 0.0), muz_z=b_len, cal_r=cal_r,
            brake_style="slotted_pzh" if is_d30 else "double_baffle", lod=lod, mv_radar=False,
        )
    muz_pt = (0.0, g_piv[1] + math.sin(elev) * b_len, g_piv[2] + math.cos(elev) * b_len)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


ALL_SLUGS = [
    "artillery__roem",
    "wheeledHowitzer__rch_155",
    "wheeledHowitzer__archer",
    *list(TRUCK_SPH_SPECS.keys()),
    "towedHowitzer__m777",
    "towedHowitzer__fh70",
    "towedHowitzer__kh179",
    "towedHowitzer__l118_light_gun",
    "artillery__d_30_towed",
    "artillery__d_30_khalifa",
]


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in ("artillery__roem", "wheeledHowitzer__rch_155", "wheeledHowitzer__archer"):
        return build_turreted_wheeled_sph(slug, lod)
    if slug in TRUCK_SPH_SPECS:
        return build_truck_sph_rig(slug, lod)
    return build_towed_howitzer_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    is_towed = slug.startswith("towedHowitzer__") or slug in ("artillery__d_30_towed", "artillery__d_30_khalifa")
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(2.4, 0.0, -0.4) if is_towed else (4.0, 0.0, -0.5),
        ring_radius=0.38 if is_towed else 0.82,
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
