"""Tier P3.1 — Tracked Self-Propelled Howitzers (155mm / 152mm / 170mm / 122mm) & Tracked Mortars (26 vehicles).

Run all 26 variants:
    blender -b --python-exit-code 1 -P native/tools/models/blender/build_p3_sph_tracked.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  M109 Paladin / Doher Family (7):
    1.  artillery__m109a7_paladin.glb        (US M109A7 PIM on Bradley 7-wheel hull w/ extended bustle & travel lock)
    2.  artillery__m109_doher.glb            (IDF 'Doher' M109A5 w/ roof stowage baskets, generator, chevrons & M2HB)
    3.  artillery__m109a5.glb                (Standard M109A5 155mm/39 tracked SPH w/ double-baffle brake & spades)
    4.  artillery__m109a5_br.glb             (Brazilian M109A5+ BR w/ muzzle-velocity Doppler radar above mantlet)
    5.  artillery__m109a5_sh_15.glb          (Upgraded M109A5 export SPH w/ bustle climate unit)
    6.  artillery__d_30_m109a5.glb           (Mixed-fleet M109A5 155mm SPH)
    7.  artillery__k55a1.glb                 (ROK K55A1 upgraded M109 w/ bustle APU & MV radar)

  K9 Thunder / PzH 2000 / Modern Western 52-Caliber SPH Family (10):
    8.  k9__k9_thunder.glb                   (ROK Hanwha K9 Thunder 155mm/52 SPH w/ faceted welded turret & pepperpot brake)
    9.  artillery__k9a1_thunder.glb          (ROK K9A1 Thunder w/ rear-left APU pod & panoramic sight)
   10.  artillery__k9_vajra_t.glb            (Indian K9 Vajra-T desert SPH w/ dust filters & MV radar)
   11.  artillery__as9_huntsman.glb          (Australian AS9 Huntsman up-armoured K9 w/ spaced side skirts & roof RWS)
   12.  artillery__t_155_firtina.glb         (Turkish T-155 Fırtına 155mm/52 SPH w/ stepped turret roof)
   13.  artillery__pzh_2000.glb              (German PzH 2000 7-wheel SPH w/ long sloped Igelpanzerung roof & slotted brake)
   14.  artillery__2s3_pzh_2000_krab.glb     (Polish AHS Krab — K9 chassis + angular Braveheart 155mm/52 turret)
   15.  artillery__as_90_archer.glb          (British AS-90 155mm SPH w/ angular welded turret & double-baffle brake)
   16.  artillery__type_99_sph.glb           (JGSDF Type 99 7-wheel 155mm/52 SPH w/ tall boxy welded turret)
   17.  artillery__sh_5_palmaria.glb         (OTO Melara Palmaria 155mm export SPH w/ sloped turret)

  Soviet / Chinese / Iranian / DPRK SPH & Tracked Mortars (9):
   18.  artillery__2s19_msta_s.glb           (Russian 2S19 Msta-S 152mm SPH on T-80/T-72 hull w/ triple-baffle brake)
   19.  artillery__plz_05.glb                (Chinese PLZ-05 155mm/52 SPH w/ elongated bustle turret & dual roof sights)
   20.  artillery__2s1_gvozdika_d_30.glb     (Soviet 2S1 Gvozdika 7-wheel amphibious 122mm SPH)
   21.  artillery__d_30_2s1.glb              (2S1 Gvozdika 122mm SPH export variant)
   22.  artillery__d_30_2s1_captured.glb     (Captured field-marked 2S1 Gvozdika 122mm SPH)
   23.  artillery__raad_2.glb                (Iranian Raad-2 155mm tracked SPH w/ sloped hull & M109-style turret)
   24.  artillery__m1989_koksan.glb          (DPRK M1989 Koksan open-top 170mm long-range cannon w/ massive rear spades)
   25.  artillery__k242a1.glb                (ROK K242A1 tracked 107mm mortar carrier w/ openable roof bay & M2HB)
   26.  artillery__k281a1.glb                (ROK K281A1 tracked 81mm mortar carrier w/ roof mortar turntable)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bl_vehicle import Part, VehicleRig, init_scene, export_vehicle
from build_merkava import add_idf_chevron_x
from build_p2_ifv_west import (
    build_ifv_road_wheel,
    build_ifv_sprocket,
    build_ifv_idler,
    build_ifv_roller,
    add_nato_diamond,
)

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.32, 1.10, 1.40)
TAIL_RED = (2.8, 0.25, 0.20)


def rect_xz(x0, x1, z0, z1):
    xa, xb = (x0, x1) if x0 <= x1 else (x1, x0)
    za, zb = (z0, z1) if z0 <= z1 else (z1, z0)
    return [(xa, za), (xb, za), (xb, zb), (xa, zb)]


def add_sph_running_gear(rig: VehicleRig, lod: int, tx: float, tw: float, wr: float, wheels: list, rollers: list, ts: float, front_drive: bool = True):
    z_sp = 3.22 * ts if front_drive else -3.24 * ts
    z_id = -3.24 * ts if front_drive else 3.22 * ts
    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))

        sp_p = (sx * tx, 0.66 * ts, z_sp)
        id_p = (sx * tx, 0.65 * ts, z_id)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_ifv_sprocket(sp_p, lod, sx, r=wr * 0.96))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_ifv_idler(id_p, lod, sx, r=wr * 0.92))
        for i, wz in enumerate(wheels):
            wp = (sx * tx, wr, wz)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_ifv_road_wheel(wp, lod, sx, r=wr))
        if not lod:
            for r_i, rz in enumerate(rollers):
                rp = (sx * tx, 1.05 * ts, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx, r=0.11))


def add_howitzer_barrel(
    gp: Part, g_piv: tuple, muz_z: float, cal_r: float, brake_style: str, lod: int, mv_radar: bool = False
) -> tuple:
    """Sculpted 155mm/152mm/122mm howitzer ordnance with recoil cradle, fume extractor & multi-baffle muzzle brake."""
    gx, gy, gz = g_piv
    bv = 0.012 if not lod else 0.0
    L = muz_z - gz
    # Heavy armoured recoil cradle / recuperator housing
    gp.box("paint", (gx - 0.30, gy - 0.20, gz - 0.35), (gx + 0.30, gy + 0.24, gz + 0.95), bevel=bv)
    if mv_radar:
        # Muzzle-velocity Doppler radar unit mounted above recoil cradle!
        gp.box("paint", (gx - 0.16, gy + 0.24, gz + 0.20), (gx + 0.16, gy + 0.46, gz + 0.62), bevel=bv)
        if not lod:
            gp.box("metal_dark", (gx - 0.13, gy + 0.27, gz + 0.61), (gx + 0.13, gy + 0.43, gz + 0.64))

    # Stepped main barrel + central bore evacuator (fume extractor)
    b0 = gz + 0.90
    fe_z = gz + L * 0.46
    b_brake = muz_z - 0.56
    gp.cyl("paint", (gx, gy, b0), cal_r * 1.18, fe_z - b0, seg=16 if not lod else 10, r2=cal_r * 1.06, axis="z")
    gp.cyl("paint", (gx, gy, fe_z - 0.05), cal_r * 1.58, 0.78, seg=16 if not lod else 10, bevel=0.01 if not lod else 0.0, axis="z")
    gp.cyl("paint", (gx, gy, fe_z + 0.70), cal_r * 0.98, b_brake - (fe_z + 0.70), seg=16 if not lod else 10, r2=cal_r * 0.90, axis="z")

    # Signature Artillery Muzzle Brake (`double_baffle`, `slotted_pzh`, `pepperpot_k9`, `triple_msta`)
    if brake_style == "slotted_pzh":
        gp.cyl("metal_dark", (gx, gy, b_brake), cal_r * 1.48, 0.50, seg=16 if not lod else 10, r2=cal_r * 1.32, axis="z")
        if not lod:
            for sz in (0.08, 0.22, 0.36):
                gp.box("dark", (gx - cal_r * 1.52, gy - 0.04, b_brake + sz), (gx + cal_r * 1.52, gy + 0.04, b_brake + sz + 0.07))
    elif brake_style == "triple_msta":
        gp.box("metal_dark", (gx - 0.22, gy - 0.15, b_brake), (gx + 0.22, gy + 0.15, muz_z - 0.06), bevel=bv)
        if not lod:
            for sz in (0.06, 0.21, 0.36):
                gp.box("dark", (gx - 0.24, gy - 0.10, b_brake + sz), (gx + 0.24, gy + 0.10, b_brake + sz + 0.08))
    else:
        # Classic wide double-baffle artillery muzzle brake (M109 / K9 / AS-90 / PLZ-05)
        gp.box("metal_dark", (gx - 0.25, gy - 0.15, b_brake), (gx + 0.25, gy + 0.15, muz_z - 0.06), bevel=bv)
        if not lod:
            gp.box("dark", (gx - 0.27, gy - 0.10, b_brake + 0.08), (gx + 0.27, gy + 0.10, b_brake + 0.20))
            gp.box("dark", (gx - 0.27, gy - 0.10, b_brake + 0.28), (gx + 0.27, gy + 0.10, b_brake + 0.40))

    muz_pt = (gx, gy, muz_z)
    gp.tube_axis("metal_dark", (gx, gy, muz_z - 0.08), muz_pt, cal_r * 1.15, cal_r * 0.72, seg=14 if not lod else 8)
    return muz_pt


def add_travel_lock_and_spades(hp: Part, z0: float, z1: float, hh: float, lod: int, big_spades: bool = True):
    """Folding A-frame barrel travel lock on front glacis + rear hydraulic recoil spades."""
    bv = 0.012 if not lod else 0.0
    # Front folding A-frame barrel travel lock
    for sx in (-1, 1):
        hp.pipe("metal_dark", (sx * 0.34, hh - 0.02, z1 - 0.52), (sx * 0.14, hh + 0.56, z1 - 0.12), 0.036, seg=8)
    hp.box("metal_dark", (-0.22, hh + 0.50, z1 - 0.18), (0.22, hh + 0.64, z1 - 0.04), bevel=bv)

    if big_spades:
        for sx in (-1, 1):
            hp.box("metal_dark", (sx * 0.78 - 0.34, 0.36, z0 - 0.22), (sx * 0.78 + 0.34, 1.18, z0 + 0.06), bevel=bv)
            if not lod:
                hp.pipe("metal", (sx * 0.78, 1.12, z0 + 0.04), (sx * 0.78, 0.72, z0 - 0.20), 0.038, seg=8)


# =============================================================================
# 1–7. M109 PALADIN / DOHER FAMILY (`m109*`, `k55a1`)
# =============================================================================

def build_m109_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    is_a7 = slug == "artillery__m109a7_paladin"
    is_doher = slug == "artillery__m109_doher"
    has_radar = slug in ("artillery__m109a7_paladin", "artillery__m109a5_br", "artillery__k55a1")

    tx, tw, wr, ts = 1.38, 0.48, 0.33, 0.88
    wheels = [-2.28, -1.52, -0.76, 0.0, 0.76, 1.52, 2.28]
    rollers = [-1.45, 0.0, 1.45] if is_a7 else []
    hl, hw, hh = 6.75, 2.34, 1.56
    z0, z1 = -hl * 0.5, hl * 0.5
    hx = hw * 0.5
    ow = tx + tw * 0.5 + 0.06
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [
            (z0 + 0.16, 0.42),
            (z1 - 0.65, 0.42),
            (z1, 1.04),
            (z1 - 0.92, hh),
            (z0 + 0.10, hh),
            (z0, 1.06),
        ],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 1.1),
    )
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.88, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
        if is_a7:
            # M109A7 Bradley PIM stepped ballistic side skirts
            hp.box("paint", (sx * (ow - 0.04), 0.52, z0 + 0.14), (sx * (ow + 0.05), 0.94, z1 - 0.20), bevel=bv)
        if not lod:
            if is_doher:
                add_idf_chevron_x(hp, sx * (ow + 0.012), 1.14, 0.25, sx)
            else:
                add_nato_diamond(hp, sx * (ow + 0.056 if is_a7 else ow + 0.012), 1.12, 0.25, sx, size=0.12)

    if not lod:
        # Starboard front engine grille + port driver hatch
        hp.box("dark", (0.14, hh - 0.08, z1 - 1.55), (hx - 0.12, hh + 0.01, z1 - 0.55))
        hp.cyl("paint", (-0.56, hh, z1 - 1.15), 0.25, 0.06, seg=14, bevel=0.006)
    add_travel_lock_and_spades(hp, z0, z1, hh, lod, big_spades=True)
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=True)

    # Wide angular M109 turret set rearward with massive ammunition bustle
    tz = -0.68
    t_piv = (0.0, hh + 0.02, tz)
    tp = Part("Turret")
    bustle_back = -2.65 if is_a7 else -2.35
    bot = [(-1.38, bustle_back), (1.38, bustle_back), (1.46, tz + 0.72), (0.98, tz + 1.48), (-0.98, tz + 1.48), (-1.46, tz + 0.72)]
    top = [(-1.24, bustle_back + 0.12), (1.24, bustle_back + 0.12), (1.26, tz + 0.64), (0.82, tz + 1.26), (-0.82, tz + 1.26), (-1.26, tz + 0.64)]
    tp.frustum_xz("paint", bot, top, hh + 0.02, hh + 0.96, bevel=bv)
    # Bustle stowage rack / climate / APU unit + .50 cal commander cupola
    tp.box("metal_dark", (-1.12, hh + 0.24, bustle_back - 0.42), (1.12, hh + 0.88, bustle_back + 0.04), bevel=bv)
    if not lod:
        tp.cyl("paint", (0.62, hh + 0.96, tz + 0.18), 0.28, 0.16, seg=14, bevel=0.006)
        tp.cyl("metal_dark", (0.62, hh + 1.14, tz + 0.42), 0.018, 0.82, seg=8, axis="z")
        tp.box("paint", (-0.72, hh + 0.96, tz + 0.45), (-0.38, hh + 1.24, tz + 0.82), bevel=0.01)
        tp.box("glass", (-0.68, hh + 1.02, tz + 0.81), (-0.42, hh + 1.18, tz + 0.835), tint=OPTIC_FLIR)
        for sx in (-1, 1):
            tp.cyl("dark", (sx * 1.10, hh + 0.96, bustle_back + 0.30), 0.012, 1.35, seg=6)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, hh + 0.54, tz + 1.32)
    gp = Part("Gun")
    muz_pt = add_howitzer_barrel(gp, g_piv, muz_z=5.55, cal_r=0.095, brake_style="double_baffle", lod=lod, mv_radar=has_radar)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 8–19, 23. 52-CALIBER & HEAVY TRACKED SPHs (`K9`, `PzH 2000`, `2S19`, `PLZ-05`, `AS-90`, `Raad-2`)
# =============================================================================

SPH_52_SPECS = {
    "k9__k9_thunder": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": False},
    "artillery__k9a1_thunder": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": True},
    "artillery__k9_vajra_t": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": True},
    "artillery__as9_huntsman": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": True, "spaced": True},
    "artillery__t_155_firtina": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": True},
    "artillery__pzh_2000": {"wheels": 7, "brake": "slotted_pzh", "radar": True, "pzh": True},
    "artillery__2s3_pzh_2000_krab": {"wheels": 6, "brake": "double_baffle", "radar": True, "apu": False},
    "artillery__as_90_archer": {"wheels": 6, "brake": "double_baffle", "radar": True, "short_barrel": True},
    "artillery__type_99_sph": {"wheels": 7, "brake": "double_baffle", "radar": False, "boxy": True},
    "artillery__sh_5_palmaria": {"wheels": 6, "brake": "double_baffle", "radar": False, "short_barrel": True},
    "artillery__2s19_msta_s": {"wheels": 6, "brake": "triple_msta", "radar": False, "east": True},
    "artillery__plz_05": {"wheels": 6, "brake": "double_baffle", "radar": True, "east": True},
    "artillery__raad_2": {"wheels": 6, "brake": "double_baffle", "radar": False, "east": True, "short_barrel": True},
}


def build_heavy_sph_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = SPH_52_SPECS[slug]
    seven_w = cfg["wheels"] == 7
    is_pzh = cfg.get("pzh", False)
    is_east = cfg.get("east", False)

    tx, tw, wr, ts = 1.46, 0.56, 0.35, (0.96 if seven_w else 0.92)
    wheels = [-2.52, -1.68, -0.84, 0.0, 0.84, 1.68, 2.52] if seven_w else [-2.35, -1.41, -0.47, 0.47, 1.41, 2.35]
    rollers = [-1.65, -0.55, 0.55, 1.65] if seven_w else [-1.45, 0.0, 1.45]
    hl, hw, hh = (7.85 if seven_w else 7.45), 2.40, 1.50
    z0, z1 = -hl * 0.5, hl * 0.5
    hx = hw * 0.5
    ow = tx + tw * 0.5 + 0.06
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [
            (z0 + 0.18, 0.42),
            (z1 - 0.68, 0.42),
            (z1, 0.96),
            (z1 - 0.98, hh),
            (z0 + 0.12, hh),
            (z0, 1.02),
        ],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 1.15),
    )
    sk_out = ow + (0.06 if cfg.get("spaced") else 0.01)
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.88, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
        hp.box("paint", (sx * (ow - 0.05), 0.48, z0 + 0.14), (sx * sk_out, 0.92, z1 - 0.18), bevel=bv * 0.7)
        if not lod:
            add_nato_diamond(hp, sx * (sk_out + 0.008), 0.74, 0.10, sx, size=0.12)

    if not lod:
        hp.box("dark", (0.12, hh - 0.06, z1 - 1.85), (hx - 0.14, hh + 0.01, z1 - 0.70))
        hp.cyl("paint", (-0.58, hh, z1 - 1.30), 0.25, 0.06, seg=14, bevel=0.006)
    add_travel_lock_and_spades(hp, z0, z1, hh, lod, big_spades=not is_pzh)
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_sph_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, front_drive=not is_east)

    # Rear-set elongated 52-caliber SPH turret (`tz = -0.95`, keeps `muzzle < 8.05 m` & `size.z < 11.4 m`!)
    tz = -0.95
    t_piv = (0.0, hh + 0.02, tz)
    tp = Part("Turret")
    if is_pzh:
        bot = [(-1.38, -3.55), (1.38, -3.55), (1.42, tz + 0.95), (0.86, tz + 2.05), (-0.86, tz + 2.05), (-1.42, tz + 0.95)]
        top = [(-1.12, -3.40), (1.12, -3.40), (1.14, tz + 0.80), (0.68, tz + 1.65), (-0.68, tz + 1.65), (-1.14, tz + 0.80)]
        tp.frustum_xz("paint", bot, top, hh + 0.02, hh + 1.08, bevel=bv)
        if not lod:
            # PzH 2000 signature dark rubber 'Igelpanzerung' roof bomblet-protection mat!
            tp.box("rubber", (-0.98, hh + 1.07, -3.20), (0.98, hh + 1.15, tz + 0.70), bevel=0.01)
    else:
        t_h = 1.12 if cfg.get("boxy") else 1.02
        bot = [(-1.42, -3.35), (1.42, -3.35), (1.46, tz + 0.85), (0.94, tz + 1.68), (-0.94, tz + 1.68), (-1.46, tz + 0.85)]
        top = [(-1.24, -3.20), (1.24, -3.20), (1.26, tz + 0.75), (0.78, tz + 1.42), (-0.78, tz + 1.42), (-1.26, tz + 0.75)]
        tp.frustum_xz("paint", bot, top, hh + 0.02, hh + t_h, bevel=bv)
        if cfg.get("apu"):
            tp.box("metal_dark", (-1.38, hh + 0.34, -3.65), (-0.52, hh + 0.92, -3.25), bevel=bv)

    if not lod:
        r_y = hh + (1.08 if is_pzh else (1.12 if cfg.get("boxy") else 1.02))
        tp.cyl("paint", (0.58, r_y, tz - 0.15), 0.28, 0.14, seg=14, bevel=0.006)
        tp.cyl("metal_dark", (0.58, r_y + 0.16, tz + 0.10), 0.018, 0.85, seg=8, axis="z")
        tp.box("paint", (-0.68, r_y, tz + 0.25), (-0.34, r_y + 0.28, tz + 0.64), bevel=0.01)
        tp.box("glass", (-0.64, r_y + 0.06, tz + 0.63), (-0.38, r_y + 0.22, tz + 0.66), tint=OPTIC_FLIR)
        for sx in (-1, 1):
            tp.cyl("dark", (sx * 1.06, r_y, -3.05), 0.012, 1.35, seg=6)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, hh + 0.58, tz + 1.50)
    gp = Part("Gun")
    muz_z = 5.85 if cfg.get("short_barrel") else 6.82
    muz_pt = add_howitzer_barrel(gp, g_piv, muz_z=muz_z, cal_r=0.096, brake_style=cfg["brake"], lod=lod, mv_radar=cfg["radar"])
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


# =============================================================================
# 20–22, 24–26. 2S1 GVOZDIKA, M1989 KOKSAN 170MM & K242/K281 TRACKED MORTARS
# =============================================================================

def build_special_sph_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0

    # 20–22. Soviet 2S1 Gvozdika 122mm Amphibious SPH
    if slug in ("artillery__2s1_gvozdika_d_30", "artillery__d_30_2s1", "artillery__d_30_2s1_captured"):
        tx, tw, wr, ts = 1.28, 0.42, 0.29, 0.88
        wheels = [-2.28, -1.52, -0.76, 0.0, 0.76, 1.52, 2.28]
        hl, hw, hh = 7.10, 2.22, 1.38
        z0, z1 = -hl * 0.5, hl * 0.5
        hx, ow = hw * 0.5, tx + tw * 0.5 + 0.04
        hp = Part("Hull")
        hp.profile_x(
            "paint",
            [(z0 + 0.20, 0.38), (z1 - 0.75, 0.38), (z1, 0.98), (z1 - 0.95, hh), (z0 + 0.12, hh), (z0, 0.98)],
            -hx, hx, bevel=bv, ao_y=(0.32, hh + 0.7),
        )
        for sx in (-1, 1):
            hp.box("paint", (sx * hx, 0.82, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_sph_running_gear(rig, lod, tx, tw, wr, wheels, [], ts, front_drive=True)

        tz = -1.05
        t_piv = (0.0, hh + 0.02, tz)
        tp = Part("Turret")
        bot = [(-1.12, -2.95), (1.12, -2.95), (1.18, tz + 0.65), (0.76, tz + 1.28), (-0.76, tz + 1.28), (-1.18, tz + 0.65)]
        top = [(-0.86, -2.75), (0.86, -2.75), (0.90, tz + 0.52), (0.56, tz + 1.02), (-0.56, tz + 1.02), (-0.90, tz + 0.52)]
        tp.frustum_xz("paint", bot, top, hh + 0.02, hh + 0.66, bevel=bv)
        if not lod:
            tp.cyl("paint", (-0.42, hh + 0.66, tz + 0.15), 0.24, 0.12, seg=14)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.38, tz + 1.15)
        gp = Part("Gun")
        muz_pt = add_howitzer_barrel(gp, g_piv, muz_z=4.45, cal_r=0.078, brake_style="double_baffle", lod=lod, mv_radar=False)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # 24. DPRK M1989 Koksan Open-Top 170mm Long-Range Self-Propelled Gun!
    if slug == "artillery__m1989_koksan":
        tx, tw, wr, ts = 1.40, 0.52, 0.36, 0.90
        wheels = [-2.20, -1.25, -0.35, 0.55, 1.45]
        hl, hw, hh = 7.15, 2.30, 1.46
        z0, z1 = -hl * 0.5, hl * 0.5
        hx, ow = hw * 0.5, tx + tw * 0.5 + 0.05
        hp = Part("Hull")
        hp.profile_x(
            "paint",
            [(z0 + 0.18, 0.42), (z1 - 0.65, 0.42), (z1, 0.96), (z1 - 0.90, hh), (z0 + 0.10, hh), (z0, 1.00)],
            -hx, hx, bevel=bv, ao_y=(0.35, hh + 1.0),
        )
        # Forward armored crew cab (`z = 0.75..z1 - 0.65`)
        hp.frustum_xz("paint", rect_xz(-hx, hx, 0.65, z1 - 0.65), rect_xz(-hx + 0.16, hx - 0.16, 0.80, z1 - 1.10), hh, hh + 0.48, bevel=bv)
        for sx in (-1, 1):
            hp.box("paint", (sx * hx, 0.86, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.14), bevel=bv)
        add_travel_lock_and_spades(hp, z0, z1, hh + 0.20, lod, big_spades=True)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_sph_running_gear(rig, lod, tx, tw, wr, wheels, [], ts, front_drive=False)

        # Open-top heavy trunnion pedestal (`Turret`) + massive twin-cylinder 170mm recoil cradle (`Gun`)
        tz = -1.35
        t_piv = (0.0, hh + 0.02, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, hh, tz), 0.96, 0.22, seg=18 if not lod else 10)
        for sx in (-1, 1):
            tp.box("paint", (sx * 0.52 - 0.16, hh + 0.20, tz - 0.65), (sx * 0.52 + 0.16, hh + 1.12, tz + 0.55), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.96, tz + 0.10)
        gp = Part("Gun")
        # Twin upper hydro-pneumatic recoil cylinders iconic to Koksan
        for sx in (-1, 1):
            gp.cyl("metal_dark", (sx * 0.22, g_piv[1] + 0.22, tz - 0.75), 0.085, 2.05, seg=10, axis="z")
        muz_pt = add_howitzer_barrel(gp, g_piv, muz_z=6.48, cal_r=0.105, brake_style="slotted_pzh", lod=lod, mv_radar=False)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # 25 & 26. ROK K242A1 (107mm) & K281A1 (81mm) Tracked Mortar Carriers on K200 Hull
    tx, tw, wr, ts = 1.18, 0.38, 0.30, 0.74
    wheels = [-1.64, -0.82, 0.0, 0.82, 1.64]
    hl, hw, hh = 5.45, 2.18, 1.84
    z0, z1 = -hl * 0.5, hl * 0.5
    hx, ow = hw * 0.5, tx + tw * 0.5 + 0.05
    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [(z0 + 0.16, 0.38), (z1 - 0.65, 0.38), (z1, 1.05), (z1 - 0.78, hh), (z0 + 0.06, hh), (z0, 0.72)],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 0.4),
    )
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.82, z0 + 0.06), (sx * ow, hh - 0.02, z1 - 0.10), bevel=bv)
        # Open folded-out split roof mortar bay doors!
        hp.box("paint", (sx * (hx + 0.06) - 0.18, hh + 0.02, -1.95), (sx * (hx + 0.06) + 0.18, hh + 0.12, -0.15), bevel=0.01)
    if not lod:
        hp.cyl("paint", (0.48, hh, 0.55), 0.28, 0.16, seg=14)
        hp.cyl("metal_dark", (0.48, hh + 0.20, 0.75), 0.018, 0.75, seg=8, axis="z")
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_sph_running_gear(rig, lod, tx, tw, wr, wheels, [], ts, front_drive=True)

    # Roof/interior mortar turntable (`Turret`) + elevated heavy mortar barrel (`Gun`)
    tz = -1.05
    t_piv = (0.0, hh - 0.18, tz)
    tp = Part("Turret")
    tp.cyl("metal_dark", (0.0, hh - 0.20, tz), 0.58, 0.18, seg=16 if not lod else 10)
    tp.box("metal_dark", (-0.28, hh - 0.02, tz - 0.24), (0.28, hh + 0.32, tz + 0.24), bevel=bv)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (0.0, hh + 0.24, tz)
    gp = Part("Gun")
    m_rad = 0.082 if slug == "artillery__k242a1" else 0.065
    muz_pt = (0.0, hh + 0.98, tz + 0.92)
    gp.pipe("metal_dark", (0.0, hh + 0.16, tz - 0.10), (0.0, hh + 0.92, tz + 0.84), m_rad, seg=14 if not lod else 8)
    gp.tube_axis("metal", (0.0, hh + 0.90, tz + 0.82), muz_pt, m_rad * 1.12, m_rad * 0.78, seg=12 if not lod else 8)
    # Bipod shock struts
    if not lod:
        for sx in (-1, 1):
            gp.pipe("metal", (sx * 0.24, hh + 0.08, tz + 0.20), (sx * 0.06, hh + 0.68, tz + 0.56), 0.026, seg=8)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)
    return rig


ALL_SLUGS = [
    "artillery__m109a7_paladin",
    "artillery__m109_doher",
    "artillery__m109a5",
    "artillery__m109a5_br",
    "artillery__m109a5_sh_15",
    "artillery__d_30_m109a5",
    "artillery__k55a1",
    *list(SPH_52_SPECS.keys()),
    "artillery__2s1_gvozdika_d_30",
    "artillery__d_30_2s1",
    "artillery__d_30_2s1_captured",
    "artillery__m1989_koksan",
    "artillery__k242a1",
    "artillery__k281a1",
]


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in SPH_52_SPECS:
        return build_heavy_sph_rig(slug, lod)
    if slug.startswith("artillery__m109") or slug in ("artillery__d_30_m109a5", "artillery__k55a1"):
        return build_m109_rig(slug, lod)
    return build_special_sph_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    is_mortar = slug in ("artillery__k242a1", "artillery__k281a1")
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(3.6, 0.0, -0.2) if is_mortar else (4.4, 0.0, -0.6),
        ring_radius=0.52 if is_mortar else 1.02,
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
