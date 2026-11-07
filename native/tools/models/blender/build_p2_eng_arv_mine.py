"""Tier P2.5 — Armoured Recovery Vehicles (14), Combat Breachers / Mine-Clearers (11) & Minelayers (7) = 32 vehicles.

Run all 32 variants:
    blender -b -P native/tools/models/blender/build_p2_eng_arv_mine.py -- --all

Vehicles produced (`native/godot/assets/art/vehicles/`):
  Armoured Recovery Vehicles — `recoveryVehicle__*` (14):
    1.  recoveryVehicle__m88a2_hercules.glb           (US M88A2 Hercules heavy casemate ARV w/ A-frame boom & front spade)
    2.  recoveryVehicle__bergepanzer_3_buffel.glb     (German BPz 3 Büffel on Leopard 2 hull w/ starboard slewing crane & dozer)
    3.  recoveryVehicle__brem_1.glb                   (Soviet/Russian BREM-1 on T-72 hull w/ port crane, roof cargo rack & dozer)
    4.  recoveryVehicle__wzt_3.glb                    (Polish/Indian WZT-3M on T-72M hull w/ crane, snorkel & front dozer)
    5.  recoveryVehicle__challenger_arrv.glb          (British CRARRV on Challenger hull w/ port Atlas crane & front dozer)
    6.  recoveryVehicle__leclerc_dcl.glb              (French Leclerc DCL stretched ARV w/ heavy starboard crane & dozer)
    7.  recoveryVehicle__k1_arv.glb                   (ROK K1 ARV w/ starboard hydraulic crane & front stabilizer blade)
    8.  recoveryVehicle__k1_arv_korean.glb            (ROK K1A1 upgraded ARV w/ crane, powerpack cradle & K6 RWS)
    9.  recoveryVehicle__type_90_arv.glb              (JGSDF Type 90 ARV w/ front-right boom crane & front dozer)
   10.  recoveryVehicle__type_11_arv.glb              (JGSDF Type 11 ARV on Type 10 5-wheel hull w/ crane & dozer)
   11.  recoveryVehicle__apollo.glb                   (British Ajax-family Apollo repair vehicle w/ roof A-frame crane)
   12.  recoveryVehicle__atlas.glb                    (British Ajax-family Atlas recovery vehicle w/ winch & earth anchor)
   13.  recoveryVehicle__k288a1.glb                   (ROK K288A1 light tracked ARV on K200 hull w/ roof crane)
   14.  recoveryVehicle__armoured_recovery_vehicle.glb(Standard NATO heavy tracked ARV w/ slewing crane & front spade)

  Combat Engineering & Mine-Clearing Vehicles — `mineClearer__*` (11):
   15.  mineClearer__namer_engineering.glb            (IDF Namer CEV w/ front V-plough/dozer, Trophy APS & Katlanit RWS)
   16.  mineClearer__puma.glb                         (IDF Puma CEV w/ Nochri mine rollers, Toghat skirts & Carpet rack)
   17.  mineClearer__m1150_assault_breacher.glb       (US M1150 ABV on Abrams hull w/ Pearson V-plough & twin MICLIC turret)
   18.  mineClearer__kodiak.glb                       (AEV 3 Kodiak on Leopard 2 hull w/ center excavator arm & split plough)
   19.  mineClearer__keiler.glb                       (German Keiler mine flail w/ twin lift arms & rotating flail rotor)
   20.  mineClearer__trojan_avre.glb                  (British Trojan AVRE w/ starboard excavator, V-plough & fascine rack)
   21.  mineClearer__k600_rhino.glb                   (ROK K600 Rhino w/ V-mine plough, magnetic dogbone & excavator arm)
   22.  mineClearer__ur_77_meteorit.glb               (Soviet UR-77 'Zmey Gorynych' w/ twin line-charge rocket turret)
   23.  mineClearer__type_92_mbrs.glb                 (JGSDF Type 92 tracked mine-clearing twin rocket launcher)
   24.  mineClearer__sdpmac.glb                       (French SDPMAC 6x6 armoured mine-clearer w/ front rollers & RWS)
   25.  mineClearer__mine_clearing_vehicle.glb        (Tracked armoured breacher w/ twin front steel mine-roller gangs)

  Scatterable & Mechanical Minelayers — `mineLayer__*` (7):
   26.  mineLayer__isdm_zemledelie.glb                (Russian ISDM Zemledelie 8x8 armoured truck w/ twin 25-tube mine pods)
   27.  mineLayer__gmz_3.glb                          (Soviet GMZ-3 7-wheel tracked armoured minelayer w/ rear burial plough)
   28.  mineLayer__m139_volcano.glb                   (US M977 HEMTT 8x8 truck w/ 4 angled M139 Volcano mine racks & CROWS)
   29.  mineLayer__skorpion_mine_dispenser.glb        (German M548GA1 Skorpion tracked minelayer w/ 6 rear AT2 launcher boxes)
   30.  mineLayer__type_94_amphibious.glb             (JGSDF Type 94 6x6 amphibious beach minelayer w/ rear mine chutes)
   31.  mineLayer__km138_truck.glb                    (ROK KM138 6x6 tactical truck w/ Volcano scatterable mine dispensers)
   32.  mineLayer__engineer_minelayer.glb             (Armoured 6x6 scatterable mine dispenser vehicle w/ RWS)
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

OPTIC_FLIR = (0.25, 1.35, 0.95)
OPTIC_COOL = (0.32, 1.10, 1.40)
GLASS_ARMOUR = (0.24, 0.58, 0.52)
TAIL_RED = (2.8, 0.25, 0.20)


def rect_xz(x0, x1, z0, z1):
    xa, xb = (x0, x1) if x0 <= x1 else (x1, x0)
    za, zb = (z0, z1) if z0 <= z1 else (z1, z0)
    return [(xa, za), (xb, za), (xb, zb), (xa, zb)]


# =============================================================================
# SHARED ATTACHMENTS: RWS .50 CAL, DOZER BLADES, MINE PLOUGHS, ROLLERS & CRANES
# =============================================================================

def add_rws_50cal(rig: VehicleRig, tx: float, ty: float, tz: float, lod: int, style: str = "crows"):
    """Compact roof Remote Weapon Station / shielded .50 cal (`Turret` + `Gun` + `Muzzle` at ~1.22 m)."""
    t_piv = (tx, ty + 0.02, tz)
    tp = Part("Turret")
    bv = 0.012 if not lod else 0.0
    tp.cyl("metal_dark", (tx, ty - 0.02, tz), 0.26, 0.07, seg=16 if not lod else 10)
    if style == "cupola_east":
        tp.cyl("paint", (tx, ty + 0.05, tz), 0.25, 0.18, seg=16 if not lod else 10, bevel=0.006)
        tp.box("paint", (tx - 0.18, ty + 0.18, tz - 0.08), (tx + 0.18, ty + 0.36, tz + 0.14), bevel=bv)
        tp.box("metal_dark", (tx + 0.10, ty + 0.20, tz + 0.14), (tx + 0.25, ty + 0.35, tz + 0.26), bevel=bv)
        if not lod:
            tp.box("glass", (tx + 0.12, ty + 0.23, tz + 0.255), (tx + 0.23, ty + 0.32, tz + 0.27), tint=OPTIC_FLIR)
    elif style == "katlanit":
        tp.box("paint", (tx - 0.18, ty + 0.05, tz - 0.22), (tx + 0.18, ty + 0.36, tz + 0.16), bevel=bv)
        tp.box("paint", (tx + 0.18, ty + 0.10, tz - 0.14), (tx + 0.35, ty + 0.32, tz + 0.18), bevel=bv)
        if not lod:
            tp.box("glass", (tx + 0.20, ty + 0.14, tz + 0.175), (tx + 0.33, ty + 0.28, tz + 0.19), tint=OPTIC_COOL)
    else:
        tp.box("metal_dark", (tx - 0.16, ty + 0.05, tz - 0.20), (tx + 0.16, ty + 0.34, tz + 0.14), bevel=bv)
        tp.box("paint", (tx - 0.31, ty + 0.09, tz - 0.10), (tx - 0.16, ty + 0.31, tz + 0.18), bevel=bv)
        tp.box("paint", (tx + 0.16, ty + 0.09, tz - 0.14), (tx + 0.28, ty + 0.29, tz + 0.12), bevel=bv)
        if not lod:
            tp.box("glass", (tx - 0.29, ty + 0.13, tz + 0.175), (tx - 0.18, ty + 0.27, tz + 0.19), tint=OPTIC_FLIR)
    rig.add("Turret", "Hull", t_piv, tp)

    g_piv = (tx, ty + 0.26, tz + 0.14)
    gy, gz = g_piv[1], g_piv[2]
    gp = Part("Gun")
    gp.box("metal_dark", (tx - 0.06, gy - 0.06, gz - 0.12), (tx + 0.06, gy + 0.06, gz + 0.26), bevel=0.006 if not lod else 0.0)
    gp.cyl("metal_dark", (tx, gy, gz + 0.25), 0.028, 0.36, axis="z", seg=10)
    gp.cyl("metal", (tx, gy, gz + 0.60), 0.017, 0.44, axis="z", seg=10)
    muz_pt = (tx, gy, gz + 1.12)
    gp.tube_axis("metal_dark", (tx, gy, gz + 1.03), muz_pt, 0.025, 0.013, seg=8)
    rig.add("Gun", "Turret", g_piv, gp)
    rig.add("Muzzle", "Gun", muz_pt, None)


def add_dozer_blade(hp: Part, z_front: float, width: float, lod: int):
    """Curved hydraulic stabilizer / earthmoving dozer blade on front lower glacis."""
    hw = min(width * 0.5, 2.02)
    bz = z_front + 0.44
    bv = 0.012 if not lod else 0.0
    hp.profile_x(
        "paint",
        [
            (bz - 0.16, 0.14),
            (bz + 0.14, 0.14),
            (bz + 0.04, 0.46),
            (bz + 0.06, 0.84),
            (bz + 0.18, 1.08),
            (bz - 0.02, 1.12),
            (bz - 0.14, 0.78),
            (bz - 0.18, 0.36),
        ],
        -hw, hw, bevel=bv,
    )
    hp.box("metal_dark", (-hw, 0.11, bz + 0.10), (hw, 0.22, bz + 0.18), bevel=bv)
    for sx in (-1, 1):
        hp.box("metal_dark", (sx * (hw * 0.58) - 0.08, 0.34, z_front - 0.15), (sx * (hw * 0.58) + 0.08, 0.50, bz - 0.04), bevel=bv)
        if not lod:
            hp.pipe("metal_dark", (sx * (hw * 0.42), 0.76, z_front - 0.10), (sx * (hw * 0.42), 0.84, bz + 0.02), 0.055, seg=10)
            hp.pipe("metal", (sx * (hw * 0.42), 0.80, z_front + 0.08), (sx * (hw * 0.42), 0.88, bz + 0.06), 0.032, seg=8)
            for rx in (-0.75, -0.25, 0.25, 0.75):
                hp.box("metal_dark", (rx * hw - 0.03, 0.20, bz - 0.20), (rx * hw + 0.03, 1.04, bz - 0.04))


def add_v_mine_plough(hp: Part, z_front: float, width: float, lod: int, split_center: bool = False):
    """Full-width Pearson V-shaped mine-clearing plough with scarifier teeth & surface skis (`width <= 4.08 m`)."""
    hw = min(width * 0.5, 2.04)
    z_apex = z_front + 1.15
    z_wing = z_front + 0.36
    bv = 0.012 if not lod else 0.0
    hp.box("metal_dark", (-0.56, 0.36, z_front - 0.15), (0.56, 0.64, z_front + 0.58), bevel=bv)
    segs = 5 if not lod else 3
    for sx in (-1, 1):
        x_in = sx * (0.14 if split_center else 0.02)
        x_out = sx * hw
        for s in range(segs):
            t0, t1 = s / segs, (s + 1) / segs
            xa = x_in + (x_out - x_in) * t0
            xb = x_in + (x_out - x_in) * t1
            zm = z_apex + (z_wing - z_apex) * ((t0 + t1) * 0.5)
            hp.box("paint", (min(xa, xb) - 0.04, 0.16, zm - 0.14), (max(xa, xb) + 0.04, 0.96, zm + 0.10), bevel=bv)
            hp.box("metal_dark", (min(xa, xb) - 0.02, 0.07, zm + 0.04), (max(xa, xb) + 0.02, 0.25, zm + 0.22), bevel=bv * 0.5)
        hp.box("metal", (sx * 0.88 - 0.10, 0.09, z_front + 0.55), (sx * 0.88 + 0.10, 0.20, z_front + 1.08), bevel=bv)
        if not lod:
            hp.pipe("metal_dark", (sx * 0.52, 0.78, z_front - 0.10), (sx * 0.52, 0.64, z_front + 0.68), 0.055, seg=10)


def add_mine_rollers(hp: Part, z_front: float, lod: int):
    """Heavy twin-gang steel toothed mine-roller assembly (Nochri / KMT style)."""
    z_roller = z_front + 1.02
    bv = 0.012 if not lod else 0.0
    for sx in (-1, 1):
        cx = sx * 1.16
        hp.box("metal_dark", (cx - 0.16, 0.44, z_front - 0.12), (cx + 0.16, 0.62, z_roller + 0.08), bevel=bv)
        hp.box("metal_dark", (cx - 0.50, 0.42, z_roller - 0.12), (cx + 0.50, 0.58, z_roller + 0.12), bevel=bv)
        discs = (-0.38, -0.14, 0.14, 0.38) if not lod else (-0.28, 0.28)
        for dx in discs:
            hp.cyl("metal_dark", (cx + dx - 0.045, 0.48, z_roller), 0.45, 0.09, seg=18 if not lod else 10, axis="x")
            hp.cyl("metal", (cx + dx - 0.055, 0.48, z_roller), 0.20, 0.11, seg=12 if not lod else 8, axis="x")
    hp.box("metal_dark", (-0.98, 0.50, z_front + 0.38), (0.98, 0.62, z_front + 0.52), bevel=bv)


def add_side_crane(hp: Part, side_x: float, y_deck: float, z0: float, z1: float, lod: int):
    """Stowed heavy hydraulic recovery crane jib with slewing base, lift cylinder & hook block."""
    bv = 0.016 if not lod else 0.0
    hp.cyl("metal_dark", (side_x, y_deck - 0.04, z1), 0.34, 0.42, seg=16 if not lod else 10)
    hp.box("paint", (side_x - 0.18, y_deck + 0.34, z0), (side_x + 0.18, y_deck + 0.68, z1 + 0.24), bevel=bv)
    hp.box("metal_dark", (side_x - 0.13, y_deck + 0.39, z0 - 0.34), (side_x + 0.13, y_deck + 0.62, z0 + 0.06), bevel=bv)
    hp.box("metal_dark", (side_x - 0.22, y_deck, z0 + 0.12), (side_x + 0.22, y_deck + 0.36, z0 + 0.34), bevel=bv)
    if not lod:
        hp.pipe("metal_dark", (side_x, y_deck + 0.14, z1 - 0.12), (side_x, y_deck + 0.38, z1 - 1.20), 0.065, seg=10)
        hp.box("metal_dark", (side_x - 0.11, y_deck + 0.14, z0 - 0.42), (side_x + 0.11, y_deck + 0.38, z0 - 0.20), bevel=0.01)


def add_excavator_arm(hp: Part, arm_x: float, y_deck: float, z_mount: float, lod: int):
    """Articulated combat engineering excavator arm with armored bucket stowed rearward."""
    bv = 0.016 if not lod else 0.0
    hp.cyl("metal_dark", (arm_x, y_deck - 0.04, z_mount), 0.32, 0.38, seg=14 if not lod else 8)
    hp.box("paint", (arm_x - 0.16, y_deck + 0.32, z_mount - 2.35), (arm_x + 0.16, y_deck + 0.88, z_mount + 0.18), bevel=bv)
    hp.box("paint", (arm_x - 0.14, y_deck + 0.18, z_mount - 3.30), (arm_x + 0.14, y_deck + 0.56, z_mount - 2.15), bevel=bv)
    hp.box("metal_dark", (arm_x - 0.36, y_deck + 0.04, z_mount - 3.72), (arm_x + 0.36, y_deck + 0.44, z_mount - 3.16), bevel=bv)
    if not lod:
        hp.pipe("metal_dark", (arm_x, y_deck + 0.92, z_mount - 0.30), (arm_x, y_deck + 0.90, z_mount - 1.95), 0.055, seg=10)


def add_tracked_running_gear(rig: VehicleRig, lod: int, tx: float, tw: float, wr: float, wheels: list, rollers: list, ts: float, rear_drive: bool = True):
    """Canonical tracked running gear with world-offset `Track_L/R` and `mesh_scale=(1.0, ts, ts)`."""
    z_sp = -3.24 * ts if rear_drive else 3.22 * ts
    z_id = 3.22 * ts if rear_drive else -3.24 * ts
    y_sp = 0.66 * ts
    y_id = 0.65 * ts
    for side_lbl, sx in (("L", -1), ("R", 1)):
        tp = Part(f"Track_{side_lbl}")
        tp.build_track(sx * tx, lod=lod, width=tw)
        rig.add(f"Track_{side_lbl}", f"LOD{lod}", (sx * tx, 0.0, 0.0), tp, mesh_scale=(1.0, ts, ts))

        sp_p = (sx * tx, y_sp, z_sp)
        id_p = (sx * tx, y_id, z_id)
        rig.add(f"Sprocket_{side_lbl}", f"LOD{lod}", sp_p, build_ifv_sprocket(sp_p, lod, sx, r=wr * 0.96))
        rig.add(f"Idler_{side_lbl}", f"LOD{lod}", id_p, build_ifv_idler(id_p, lod, sx, r=wr * 0.92))
        for i, wz in enumerate(wheels):
            wp = (sx * tx, wr, wz)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_ifv_road_wheel(wp, lod, sx, r=wr))
        if not lod:
            for r_i, rz in enumerate(rollers):
                rp = (sx * tx, 1.05 * ts, rz)
                rig.add(f"Roller_{side_lbl}{r_i}", f"LOD{lod}", rp, build_ifv_roller(rp, lod, sx, r=0.11))


# =============================================================================
# 1–14. ARMOURED RECOVERY VEHICLES (`recoveryVehicle__*`)
# =============================================================================

ARV_SPECS = {
    "recoveryVehicle__m88a2_hercules": {
        "style": "m88", "tx": 1.44, "tw": 0.56, "wr": 0.35, "ts": 0.92,
        "wheels": [-2.30, -1.38, -0.46, 0.46, 1.38, 2.30], "rollers": [-1.50, 0.0, 1.50],
        "hl": 7.60, "hw": 2.36, "hh": 1.58,
    },
    "recoveryVehicle__bergepanzer_3_buffel": {
        "style": "nato_crane", "tx": 1.50, "tw": 0.58, "wr": 0.35, "ts": 0.96,
        "wheels": [-2.52, -1.68, -0.84, 0.0, 0.84, 1.68, 2.52], "rollers": [-1.80, -0.60, 0.60, 1.80],
        "hl": 7.80, "hw": 2.42, "hh": 1.52, "crane_side": 1.0,
    },
    "recoveryVehicle__brem_1": {
        "style": "soviet_arv", "tx": 1.44, "tw": 0.54, "wr": 0.36, "ts": 0.90,
        "wheels": [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.10, "hw": 2.32, "hh": 1.44, "crane_side": -1.0, "cargo_rack": True,
    },
    "recoveryVehicle__wzt_3": {
        "style": "soviet_arv", "tx": 1.44, "tw": 0.54, "wr": 0.36, "ts": 0.90,
        "wheels": [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.15, "hw": 2.34, "hh": 1.46, "crane_side": -1.0, "snorkel": True,
    },
    "recoveryVehicle__challenger_arrv": {
        "style": "nato_crane", "tx": 1.52, "tw": 0.58, "wr": 0.36, "ts": 0.96,
        "wheels": [-2.45, -1.47, -0.49, 0.49, 1.47, 2.45], "rollers": [-1.45, 0.0, 1.45],
        "hl": 7.90, "hw": 2.46, "hh": 1.56, "crane_side": -1.0,
    },
    "recoveryVehicle__leclerc_dcl": {
        "style": "nato_crane", "tx": 1.50, "tw": 0.58, "wr": 0.35, "ts": 0.98,
        "wheels": [-2.64, -1.76, -0.88, 0.0, 0.88, 1.76, 2.64], "rollers": [-1.75, 0.0, 1.75],
        "hl": 8.10, "hw": 2.44, "hh": 1.54, "crane_side": 1.0,
    },
    "recoveryVehicle__k1_arv": {
        "style": "nato_crane", "tx": 1.46, "tw": 0.56, "wr": 0.35, "ts": 0.92,
        "wheels": [-2.30, -1.38, -0.46, 0.46, 1.38, 2.30], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.45, "hw": 2.38, "hh": 1.50, "crane_side": 1.0,
    },
    "recoveryVehicle__k1_arv_korean": {
        "style": "nato_crane", "tx": 1.46, "tw": 0.56, "wr": 0.35, "ts": 0.92,
        "wheels": [-2.30, -1.38, -0.46, 0.46, 1.38, 2.30], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.48, "hw": 2.38, "hh": 1.52, "crane_side": 1.0, "spare_pack": True,
    },
    "recoveryVehicle__type_90_arv": {
        "style": "nato_crane", "tx": 1.46, "tw": 0.56, "wr": 0.35, "ts": 0.92,
        "wheels": [-2.35, -1.41, -0.47, 0.47, 1.41, 2.35], "rollers": [-1.45, 0.0, 1.45],
        "hl": 7.55, "hw": 2.38, "hh": 1.50, "crane_side": 1.0,
    },
    "recoveryVehicle__type_11_arv": {
        "style": "nato_crane", "tx": 1.40, "tw": 0.52, "wr": 0.34, "ts": 0.88,
        "wheels": [-2.12, -1.06, 0.0, 1.06, 2.12], "rollers": [-1.10, 1.10],
        "hl": 7.10, "hw": 2.28, "hh": 1.48, "crane_side": 1.0,
    },
    "recoveryVehicle__apollo": {
        "style": "ajax_arv", "tx": 1.44, "tw": 0.50, "wr": 0.34, "ts": 0.92,
        "wheels": [-2.34, -1.56, -0.78, 0.0, 0.78, 1.56, 2.34], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.25, "hw": 2.36, "hh": 1.76, "a_frame": True,
    },
    "recoveryVehicle__atlas": {
        "style": "ajax_arv", "tx": 1.44, "tw": 0.50, "wr": 0.34, "ts": 0.92,
        "wheels": [-2.34, -1.56, -0.78, 0.0, 0.78, 1.56, 2.34], "rollers": [-1.40, 0.0, 1.40],
        "hl": 7.25, "hw": 2.36, "hh": 1.74, "a_frame": False,
    },
    "recoveryVehicle__k288a1": {
        "style": "k288", "tx": 1.18, "tw": 0.38, "wr": 0.30, "ts": 0.74,
        "wheels": [-1.64, -0.82, 0.0, 0.82, 1.64], "rollers": [],
        "hl": 5.45, "hw": 2.18, "hh": 1.88,
    },
    "recoveryVehicle__armoured_recovery_vehicle": {
        "style": "nato_crane", "tx": 1.48, "tw": 0.56, "wr": 0.35, "ts": 0.94,
        "wheels": [-2.35, -1.41, -0.47, 0.47, 1.41, 2.35], "rollers": [-1.45, 0.0, 1.45],
        "hl": 7.60, "hw": 2.40, "hh": 1.52, "crane_side": 1.0,
    },
}


def build_arv_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    cfg = ARV_SPECS[slug]
    hl, hw, hh = cfg["hl"], cfg["hw"], cfg["hh"]
    tx, tw, wr = cfg["tx"], cfg["tw"], cfg["wr"]
    z0, z1 = -hl * 0.5, hl * 0.5
    hx = hw * 0.5
    ow = tx + tw * 0.5 + 0.06
    bv = 0.016 if not lod else 0.0

    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [
            (z0 + 0.20, 0.44),
            (z1 - 0.58, 0.44),
            (z1, 0.98),
            (z1 - 0.72, hh),
            (z0 + 0.14, hh),
            (z0, 1.04),
        ],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 0.9),
    )
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.90, z0 + 0.06), (sx * ow, hh - 0.04, z1 - 0.14), bevel=bv)
        hp.box("paint", (sx * (ow - 0.05), 0.46, z0 + 0.14), (sx * (ow + 0.02), 0.94, z1 - 0.18), bevel=bv * 0.7)

    style = cfg["style"]
    if style == "m88":
        hp.frustum_xz(
            "paint",
            rect_xz(-hx - 0.10, hx + 0.10, -0.45, z1 - 0.55),
            rect_xz(-hx + 0.14, hx - 0.14, -0.35, z1 - 1.15),
            hh, hh + 0.98, bevel=bv,
        )
        for sx in (-1, 1):
            hp.box("paint", (sx * 0.72 - 0.10, hh + 0.24, z0 + 0.22), (sx * 0.72 + 0.10, hh + 0.44, z1 - 0.70), bevel=bv)
        hp.box("metal_dark", (-0.82, hh + 0.26, z0 + 0.18), (0.82, hh + 0.50, z0 + 0.56), bevel=bv)
        add_dozer_blade(hp, z1, ow * 1.92, lod)
        tur_pos = (0.48, hh + 0.98, 0.55)
        rws_style = "crows"
    elif style == "soviet_arv":
        c_side = cfg["crane_side"]
        hp.frustum_xz(
            "paint",
            rect_xz(-hx, hx, 0.15, z1 - 0.65),
            rect_xz(-hx + 0.16, hx - 0.16, 0.25, z1 - 1.15),
            hh, hh + 0.64, bevel=bv,
        )
        add_side_crane(hp, c_side * (hx + 0.14), hh, z0 + 0.35, z1 - 1.05, lod)
        add_dozer_blade(hp, z1, ow * 1.88, lod)
        if cfg.get("cargo_rack"):
            hp.box("metal_dark", (-hx + 0.10, hh + 0.16, z0 + 0.35), (hx - 0.30, hh + 0.54, 0.05), bevel=bv)
        if cfg.get("snorkel") and not lod:
            hp.cyl("paint", (-hx - 0.08, hh + 0.24, z0 + 0.45), 0.15, 2.60, seg=12, axis="z")
        tur_pos = (-0.42, hh + 0.64, 0.95)
        rws_style = "cupola_east"
    elif style == "ajax_arv":
        hp.frustum_xz(
            "paint",
            rect_xz(-hx - 0.08, hx + 0.08, z0 + 0.35, z1 - 0.95),
            rect_xz(-hx + 0.12, hx - 0.12, z0 + 0.48, z1 - 1.35),
            hh, hh + 0.68, bevel=bv,
        )
        if cfg.get("a_frame"):
            for sx in (-1, 1):
                hp.box("metal_dark", (sx * 0.68 - 0.09, hh + 0.68, z0 + 0.45), (sx * 0.68 + 0.09, hh + 0.86, z1 - 1.10), bevel=bv)
            hp.box("metal_dark", (-0.78, hh + 0.70, z0 + 0.40), (0.78, hh + 0.90, z0 + 0.72), bevel=bv)
        else:
            add_dozer_blade(hp, z1, ow * 1.85, lod)
            hp.box("metal_dark", (-0.62, hh + 0.02, z0 + 0.04), (0.62, hh + 0.56, z0 + 0.42), bevel=bv)
        tur_pos = (0.44, hh + 0.68, 0.75)
        rws_style = "crows"
    elif style == "k288":
        hp.box("paint", (-hx - 0.04, hh, z0 + 0.20), (hx + 0.04, hh + 0.42, z1 - 0.85), bevel=bv)
        add_side_crane(hp, hx - 0.18, hh + 0.42, z0 + 0.35, z1 - 1.05, lod)
        tur_pos = (-0.46, hh + 0.42, 0.55)
        rws_style = "crows"
    else:
        c_side = cfg["crane_side"]
        crew_side = -c_side
        hp.frustum_xz(
            "paint",
            rect_xz(min(0.0, crew_side * (hx + 0.14)) - 0.24, max(0.0, crew_side * (hx + 0.14)) + 0.24, -0.25, z1 - 0.68),
            rect_xz(min(0.0, crew_side * (hx - 0.04)) - 0.16, max(0.0, crew_side * (hx - 0.04)) + 0.16, -0.15, z1 - 1.18),
            hh, hh + 0.76, bevel=bv,
        )
        add_side_crane(hp, c_side * (hx + 0.10), hh, z0 + 0.35, z1 - 0.95, lod)
        add_dozer_blade(hp, z1, ow * 1.90, lod)
        if cfg.get("spare_pack"):
            hp.box("metal_dark", (-0.72, hh, z0 + 0.45), (0.58, hh + 0.52, -0.55), bevel=bv)
        tur_pos = (crew_side * 0.52, hh + 0.76, 0.78)
        rws_style = "crows"

    if not lod:
        hp.box("metal_dark", (-0.85, hh + 0.005, z0 + 0.45), (0.85, hh + 0.045, -0.55))
        for sx in (-1, 1):
            hp.cyl("metal_dark", (sx * 0.55, 0.72, z0 - 0.08), 0.045, 0.12, seg=8, axis="z")
            hp.box("glass", (sx * (ow - 0.18), hh - 0.20, z0 - 0.02), (sx * (ow - 0.06), hh - 0.08, z0 + 0.02), tint=TAIL_RED)
            add_nato_diamond(hp, sx * (ow + 0.024), 0.72, -0.10, sx, size=0.12)

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_tracked_running_gear(rig, lod, tx, tw, wr, cfg["wheels"], cfg["rollers"], cfg["ts"], rear_drive=(style != "ajax_arv"))
    add_rws_50cal(rig, tur_pos[0], tur_pos[1], tur_pos[2], lod, style=rws_style)
    return rig


# =============================================================================
# 15–25. COMBAT BREACHERS & MINE-CLEARING VEHICLES (`mineClearer__*`)
# =============================================================================

def build_breacher_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0

    # Special Case 24: French SDPMAC 6x6 wheeled mine-clearing vehicle
    if slug == "mineClearer__sdpmac":
        axles = [-1.85, 0.05, 1.95]
        wr, tw, wx = 0.54, 0.39, 1.12
        z0, z1 = -3.15, 3.05
        hx, hh = 1.24, 2.24
        hp = Part("Hull")
        hp.profile_x(
            "paint",
            [
                (z0 + 0.28, 0.62),
                (z1 - 0.38, 0.62),
                (z1, 1.24),
                (z1 - 0.18, 1.68),
                (z1 - 0.68, hh),
                (z0 + 0.16, hh),
                (z0, 1.40),
            ],
            -hx, hx, bevel=bv, ao_y=(0.55, hh + 0.3),
        )
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.54 - 0.42, 1.66, z1 - 0.56), (sx * 0.54 + 0.42, 2.08, z1 - 0.22), tint=GLASS_ARMOUR)
                add_nato_diamond(hp, sx * (hx + 0.008), 1.48, -0.20, sx, size=0.12)
        add_mine_rollers(hp, z1 - 0.05, lod)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        for side_lbl, sx in (("L", -1), ("R", 1)):
            for i, az in enumerate(axles):
                wp = (sx * wx, wr, az)
                rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=20))
        add_rws_50cal(rig, 0.0, hh, 0.65, lod, style="crows")
        return rig

    if slug == "mineClearer__namer_engineering":
        tx, tw, wr, ts = 1.48, 0.60, 0.36, 0.96
        wheels = [-2.40, -1.44, -0.48, 0.48, 1.44, 2.40]
        rollers = [-1.50, 0.0, 1.50]
        hl, hw, hh = 7.65, 2.42, 1.72
        rear_drive = False
    elif slug == "mineClearer__puma":
        tx, tw, wr, ts = 1.44, 0.56, 0.35, 0.92
        wheels = [-2.25, -1.35, -0.45, 0.45, 1.35, 2.25]
        rollers = [-1.40, 0.0, 1.40]
        hl, hw, hh = 7.10, 2.34, 1.68
        rear_drive = True
    elif slug == "mineClearer__m1150_assault_breacher":
        tx, tw, wr, ts = 1.52, 0.60, 0.34, 0.98
        wheels = [-2.52, -1.68, -0.84, 0.0, 0.84, 1.68, 2.52]
        rollers = [-1.75, 0.0, 1.75]
        hl, hw, hh = 7.85, 2.46, 1.52
        rear_drive = True
    elif slug == "mineClearer__ur_77_meteorit":
        tx, tw, wr, ts = 1.28, 0.42, 0.29, 0.88
        wheels = [-2.28, -1.52, -0.76, 0.0, 0.76, 1.52, 2.28]
        rollers = []
        hl, hw, hh = 6.95, 2.18, 1.46
        rear_drive = False
    elif slug == "mineClearer__type_92_mbrs":
        tx, tw, wr, ts = 1.24, 0.44, 0.31, 0.82
        wheels = [-1.95, -0.98, 0.0, 0.98, 1.95]
        rollers = [-1.05, 1.05]
        hl, hw, hh = 6.40, 2.18, 1.56
        rear_drive = False
    else:
        seven_w = slug == "mineClearer__kodiak"
        tx, tw, wr, ts = 1.48, 0.58, 0.35, (0.96 if seven_w else 0.92)
        wheels = [-2.52, -1.68, -0.84, 0.0, 0.84, 1.68, 2.52] if seven_w else [-2.30, -1.38, -0.46, 0.46, 1.38, 2.30]
        rollers = [-1.50, 0.0, 1.50]
        hl, hw, hh = (7.75 if seven_w else 7.35), 2.40, 1.54
        rear_drive = True

    z0, z1 = -hl * 0.5, hl * 0.5
    hx = hw * 0.5
    ow = tx + tw * 0.5 + 0.06
    hp = Part("Hull")
    hp.profile_x(
        "paint",
        [
            (z0 + 0.20, 0.42),
            (z1 - 0.62, 0.42),
            (z1, 0.96),
            (z1 - 0.85, hh),
            (z0 + 0.14, hh),
            (z0, 1.02),
        ],
        -hx, hx, bevel=bv, ao_y=(0.35, hh + 0.9),
    )
    for sx in (-1, 1):
        hp.box("paint", (sx * hx, 0.88, z0 + 0.06), (sx * ow, hh - 0.04, z1 - 0.16), bevel=bv)
        hp.box("paint", (sx * (ow - 0.06), 0.46, z0 + 0.14), (sx * (ow + 0.02), 0.94, z1 - 0.22), bevel=bv * 0.7)

    if slug == "mineClearer__namer_engineering":
        hp.frustum_xz("paint", rect_xz(-hx - 0.10, hx + 0.10, z0 + 0.22, 1.35), rect_xz(-hx + 0.12, hx - 0.12, z0 + 0.36, 0.85), hh, hh + 0.54, bevel=bv)
        for sx in (-1, 1):
            hp.box("paint", (sx * (hx + 0.08) - 0.14, hh + 0.24, 0.35), (sx * (hx + 0.08) + 0.14, hh + 0.58, 0.88), bevel=bv)
            hp.cyl("metal_dark", (sx * (hx + 0.10), hh + 0.58, 0.62), 0.14, 0.18, seg=12)
            if not lod:
                add_idf_chevron_x(hp, sx * (ow + 0.024), 0.72, -0.15, sx)
        hp.box("metal_dark", (-0.74, hh + 0.54, z0 + 0.38), (0.74, hh + 1.04, z0 + 1.45), bevel=bv)
        add_v_mine_plough(hp, z1, 3.88, lod)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=False)
        add_rws_50cal(rig, 0.48, hh + 0.54, 0.35, lod, style="katlanit")
        return rig

    if slug == "mineClearer__puma":
        hp.frustum_xz("paint", rect_xz(-hx - 0.06, hx + 0.06, -1.65, 1.55), rect_xz(-hx + 0.14, hx - 0.14, -1.45, 1.15), hh, hh + 0.52, bevel=bv)
        hp.box("metal_dark", (-0.68, hh + 0.04, z0 + 0.18), (0.68, hh + 0.72, z0 + 1.25), bevel=bv)
        if not lod:
            for sx in (-1, 1):
                add_idf_chevron_x(hp, sx * (ow + 0.024), 0.72, 0.0, sx)
        add_mine_rollers(hp, z1, lod)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=True)
        add_rws_50cal(rig, 0.44, hh + 0.52, 0.68, lod, style="katlanit")
        return rig

    if slug == "mineClearer__m1150_assault_breacher":
        add_v_mine_plough(hp, z1, 4.04, lod)
        if not lod:
            for sx in (-1, 1):
                hp.box("metal_dark", (sx * (ow - 0.18), hh, z0 - 0.18), (sx * (ow + 0.04), hh + 0.42, z0 + 0.48), bevel=bv)
                add_nato_diamond(hp, sx * (ow + 0.024), 0.72, -0.30, sx, size=0.12)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=True)

        t_piv = (0.0, hh + 0.02, 0.30)
        tp = Part("Turret")
        tp.frustum_xz("paint", rect_xz(-1.32, 1.32, -1.80, 1.68), rect_xz(-1.04, 1.04, -1.60, 1.22), hh + 0.02, hh + 0.86, bevel=bv)
        for sx in (-1, 1):
            tp.box("metal_dark", (sx * 0.56 - 0.36, hh + 0.64, -1.85), (sx * 0.56 + 0.36, hh + 1.20, 0.15), bevel=bv)
            if not lod:
                for ez in (-0.05, 0.55, 1.15):
                    tp.box("paint", (sx * 1.24, hh + 0.18, ez - 0.26), (sx * 1.38, hh + 0.70, ez + 0.26), bevel=0.01)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.42, hh + 0.94, 1.15)
        gp = Part("Gun")
        gp.box("metal_dark", (0.34, g_piv[1] - 0.06, g_piv[2] - 0.12), (0.50, g_piv[1] + 0.08, g_piv[2] + 0.28), bevel=0.008 if not lod else 0.0)
        gp.cyl("metal_dark", (0.42, g_piv[1], g_piv[2] + 0.26), 0.022, 0.92, seg=10, axis="z")
        muz_pt = (0.42, g_piv[1], g_piv[2] + 1.22)
        gp.tube_axis("metal_dark", (0.42, g_piv[1], g_piv[2] + 1.14), muz_pt, 0.028, 0.014, seg=8)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    if slug in ("mineClearer__ur_77_meteorit", "mineClearer__type_92_mbrs"):
        hp.frustum_xz("paint", rect_xz(-hx, hx, 0.55, z1 - 0.55), rect_xz(-hx + 0.16, hx - 0.16, 0.68, z1 - 1.05), hh, hh + 0.48, bevel=bv)
        if slug == "mineClearer__type_92_mbrs" and not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.48 - 0.34, hh + 0.12, z1 - 1.02), (sx * 0.48 + 0.34, hh + 0.40, z1 - 0.72), tint=GLASS_ARMOUR)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=False)

        tz = -1.05
        t_piv = (0.0, hh + 0.02, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, hh, tz), 0.78, 0.16, seg=18 if not lod else 10)
        tp.frustum_xz("paint", rect_xz(-0.92, 0.92, tz - 0.85, tz + 0.75), rect_xz(-0.76, 0.76, tz - 0.75, tz + 0.55), hh + 0.16, hh + 0.64, bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, hh + 0.64, tz + 0.05)
        gp = Part("Gun")
        gp.box("paint", (-0.78, g_piv[1] - 0.08, tz - 0.80), (0.78, g_piv[1] + 0.50, tz + 1.32), bevel=bv)
        muz_pt = (0.0, g_piv[1] + 0.22, tz + 1.54)
        for sx in (-1, 1):
            gp.tube_axis("metal_dark", (sx * 0.38, g_piv[1] + 0.22, tz + 0.55), (sx * 0.38, g_piv[1] + 0.22, tz + 1.54), 0.18, 0.13, seg=14 if not lod else 8)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # `kodiak`, `keiler`, `trojan_avre`, `k600_rhino`, `mine_clearing_vehicle`
    hp.frustum_xz("paint", rect_xz(-hx, hx, -0.35, z1 - 0.70), rect_xz(-hx + 0.16, hx - 0.16, -0.25, z1 - 1.18), hh, hh + 0.58, bevel=bv)
    if slug == "mineClearer__keiler":
        z_flail = z1 + 1.12
        for sx in (-1, 1):
            hp.box("paint", (sx * 1.32 - 0.12, 0.72, z1 - 0.55), (sx * 1.32 + 0.12, 0.98, z_flail + 0.10), bevel=bv)
        hp.cyl("metal_dark", (-1.46, 0.78, z_flail), 0.18, 2.92, seg=16 if not lod else 10, axis="x")
        if not lod:
            for fx in (-1.15, -0.70, -0.25, 0.25, 0.70, 1.15):
                hp.cyl("metal", (fx - 0.04, 0.78, z_flail), 0.54, 0.08, seg=12, axis="x")
    elif slug == "mineClearer__mine_clearing_vehicle":
        add_mine_rollers(hp, z1, lod)
    elif slug == "mineClearer__kodiak":
        add_v_mine_plough(hp, z1, 3.92, lod, split_center=True)
        add_excavator_arm(hp, 0.0, hh + 0.58, 1.10, lod)
    else:
        add_v_mine_plough(hp, z1, 3.96, lod)
        add_excavator_arm(hp, 0.82, hh, 1.15, lod)
        if slug == "mineClearer__trojan_avre":
            hp.cyl("metal_dark", (-0.95, hh + 0.42, z0 + 0.52), 0.36, 1.90, seg=14 if not lod else 8, axis="x")

    if not lod:
        for sx in (-1, 1):
            add_nato_diamond(hp, sx * (ow + 0.024), 0.72, -0.20, sx, size=0.12)
    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=rear_drive)
    add_rws_50cal(rig, -0.52, hh + 0.58, 0.55, lod, style="crows")
    return rig


# =============================================================================
# 26–32. SCATTERABLE & MECHANICAL MINELAYERS (`mineLayer__*`)
# =============================================================================

def add_mine_dispenser_racks(hp: Part, y_bed: float, z0: float, z1: float, count_per_side: int, lod: int):
    """Outward-angled multi-canister scatterable mine dispenser racks (Volcano / Skorpion style)."""
    span = (z1 - z0) / max(count_per_side, 1)
    bv = 0.015 if not lod else 0.0
    for sx in (-1, 1):
        hp.box("metal_dark", (sx * 0.72 - 0.14, y_bed, z0), (sx * 0.72 + 0.14, y_bed + 0.24, z1), bevel=bv)
        for i in range(count_per_side):
            zc = z0 + (i + 0.5) * span
            hp.box(
                "paint",
                (min(sx * 0.48, sx * 1.22), y_bed + 0.22, zc - span * 0.40),
                (max(sx * 0.48, sx * 1.22), y_bed + 0.94, zc + span * 0.40),
                bevel=bv,
            )
            if not lod:
                hp.box(
                    "metal_dark",
                    (sx * 1.20, y_bed + 0.28, zc - span * 0.34),
                    (sx * 1.25, y_bed + 0.88, zc + span * 0.34),
                )


def build_minelayer_rig(slug: str, lod: int = 0) -> VehicleRig:
    rig = VehicleRig(lod=lod)
    bv = 0.016 if not lod else 0.0

    # 26. Russian ISDM Zemledelie 8x8 armoured KamAZ truck + rotating twin 25-tube rocket mine pods!
    if slug == "mineLayer__isdm_zemledelie":
        axles = [-3.05, -1.65, 1.55, 2.95]
        wr, tw, wx = 0.56, 0.40, 1.16
        z0, z1, hx = -4.25, 4.15, 1.26
        hp = Part("Hull")
        hp.box("metal_dark", (-0.56, 0.72, z0), (0.56, 1.18, z1 - 0.15), bevel=bv)
        hp.box("paint", (-hx, 1.18, z0), (hx, 1.38, 0.85), bevel=bv)
        hp.profile_x(
            "paint",
            [
                (0.92, 1.18),
                (z1 - 0.15, 1.18),
                (z1, 1.72),
                (z1 - 0.38, 2.58),
                (1.65, 2.62),
                (1.65, 2.10),
                (0.92, 2.10),
            ],
            -hx, hx, bevel=bv, ao_y=(0.65, 2.75),
        )
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.56 - 0.44, 1.98, z1 - 0.36), (sx * 0.56 + 0.44, 2.42, z1 - 0.12), tint=GLASS_ARMOUR)
                hp.box("glass", (sx * (hx - 0.10), 1.88, 2.25), (sx * (hx + 0.01), 2.30, 2.95), tint=GLASS_ARMOUR)
        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        for side_lbl, sx in (("L", -1), ("R", 1)):
            for i, az in enumerate(axles):
                wp = (sx * wx, wr, az)
                rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="eastern", lugs=22))

        tz = -2.05
        t_piv = (0.0, 1.40, tz)
        tp = Part("Turret")
        tp.cyl("metal_dark", (0.0, 1.38, tz), 0.92, 0.24, seg=20 if not lod else 10)
        tp.box("paint", (-0.98, 1.60, tz - 0.68), (0.98, 2.06, tz + 0.68), bevel=bv)
        rig.add("Turret", "Hull", t_piv, tp)

        g_piv = (0.0, 2.06, tz)
        gp = Part("Gun")
        for sx in (-1, 1):
            gp.box("paint", (sx * 0.58 - 0.46, 1.98, tz - 1.35), (sx * 0.58 + 0.46, 2.92, tz + 1.45), bevel=bv)
            gp.box("metal_dark", (sx * 0.58 - 0.42, 2.04, tz + 1.42), (sx * 0.58 + 0.42, 2.86, tz + 1.50))
        muz_pt = (0.0, 2.45, tz + 1.52)
        rig.add("Gun", "Turret", g_piv, gp)
        rig.add("Muzzle", "Gun", muz_pt, None)
        return rig

    # 27 & 29. Tracked Minelayers (`gmz_3` & `skorpion_mine_dispenser`)
    if slug in ("mineLayer__gmz_3", "mineLayer__skorpion_mine_dispenser"):
        is_gmz = slug == "mineLayer__gmz_3"
        tx, tw, wr, ts = (1.36, 0.48, 0.33, 0.92) if is_gmz else (1.18, 0.38, 0.30, 0.76)
        wheels = [-2.40, -1.60, -0.80, 0.0, 0.80, 1.60, 2.40] if is_gmz else [-1.68, -0.84, 0.0, 0.84, 1.68]
        rollers = [-1.50, 0.0, 1.50] if is_gmz else []
        hl, hw, hh = (7.45, 2.28, 1.88) if is_gmz else (5.75, 2.18, 1.42)
        z0, z1 = -hl * 0.5, hl * 0.5
        hx = hw * 0.5
        ow = tx + tw * 0.5 + 0.05

        hp = Part("Hull")
        if is_gmz:
            hp.profile_x(
                "paint",
                [
                    (z0 + 0.18, 0.44),
                    (z1 - 0.62, 0.44),
                    (z1, 1.04),
                    (z1 - 0.88, hh),
                    (z0 + 0.12, hh),
                    (z0, 1.12),
                ],
                -hx, hx, bevel=bv, ao_y=(0.35, hh + 0.4),
            )
            for sx in (-1, 1):
                hp.box("paint", (sx * hx, 0.90, z0 + 0.06), (sx * ow, hh - 0.12, z1 - 0.18), bevel=bv)
            hp.box("metal_dark", (-0.48, 0.32, z0 - 1.05), (0.48, 1.18, z0 + 0.08), bevel=bv)
            hp.box("metal", (-0.62, 0.12, z0 - 1.18), (0.62, 0.52, z0 - 0.78), bevel=bv)
            tur_pos = (-0.52, hh, 1.65)
            rws_style = "cupola_east"
        else:
            hp.box("paint", (-ow, 0.52, z0), (ow, hh, z1 - 0.18), bevel=bv)
            hp.profile_x(
                "paint",
                [
                    (0.75, hh),
                    (z1 - 0.06, hh),
                    (z1, hh + 0.38),
                    (z1 - 0.32, hh + 1.06),
                    (0.75, hh + 1.06),
                ],
                -ow + 0.04, ow - 0.04, bevel=bv,
            )
            if not lod:
                for sx in (-1, 1):
                    hp.box("glass", (sx * 0.54 - 0.42, hh + 0.52, z1 - 0.30), (sx * 0.54 + 0.42, hh + 0.92, z1 - 0.08), tint=GLASS_ARMOUR)
                    add_nato_diamond(hp, sx * (ow + 0.008), 1.05, 1.45, sx, size=0.12)
            add_mine_dispenser_racks(hp, hh, z0 + 0.18, 0.55, 3, lod)
            tur_pos = (0.48, hh + 1.06, 1.55)
            rws_style = "crows"

        rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
        add_tracked_running_gear(rig, lod, tx, tw, wr, wheels, rollers, ts, rear_drive=False)
        add_rws_50cal(rig, tur_pos[0], tur_pos[1], tur_pos[2], lod, style=rws_style)
        return rig

    # 28, 30, 31, 32. Wheeled Tactical & Amphibious Minelayers (`m139_volcano`, `type_94_amphibious`, `km138_truck`, `engineer_minelayer`)
    if slug == "mineLayer__m139_volcano":
        axles = [-3.15, -1.75, 1.65, 3.05]
        wr, tw, wx = 0.58, 0.42, 1.18
        z0, z1, hx = -4.35, 4.30, 1.28
    elif slug == "mineLayer__type_94_amphibious":
        axles = [-2.15, 0.0, 2.15]
        wr, tw, wx = 0.54, 0.40, 1.18
        z0, z1, hx = -3.65, 3.75, 1.32
    else:
        axles = [-2.25, -0.85, 2.15]
        wr, tw, wx = 0.54, 0.38, 1.12
        z0, z1, hx = -3.45, 3.45, 1.22

    hp = Part("Hull")
    if slug == "mineLayer__type_94_amphibious":
        hp.profile_x(
            "paint",
            [
                (z0 + 0.24, 0.68),
                (z1 - 0.85, 0.68),
                (z1, 1.54),
                (z1 - 0.55, 2.38),
                (0.65, 2.38),
                (0.55, 1.68),
                (z0, 1.68),
            ],
            -hx, hx, bevel=bv, ao_y=(0.60, 2.50),
        )
        add_mine_dispenser_racks(hp, 1.68, z0 + 0.22, 0.42, 2, lod)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.54 - 0.42, 1.84, z1 - 0.58), (sx * 0.54 + 0.42, 2.24, z1 - 0.28), tint=GLASS_ARMOUR)
                hp.box("metal_dark", (sx * 0.64 - 0.26, 0.88, z0 - 0.38), (sx * 0.64 + 0.26, 1.58, z0 + 0.08), bevel=bv)
        cab_top, cab_z = 2.38, 1.85
    elif slug == "mineLayer__m139_volcano":
        hp.box("metal_dark", (-0.56, 0.74, z0), (0.56, 1.22, z1 - 0.12), bevel=bv)
        hp.box("paint", (-hx, 1.22, z0), (hx, 1.42, 0.75), bevel=bv)
        hp.box("paint", (-hx, 1.16, 2.05), (hx, 2.52, z1), bevel=bv)
        hp.box("metal_dark", (-hx + 0.08, 1.22, 0.78), (hx - 0.08, 2.28, 2.02), bevel=bv)
        add_mine_dispenser_racks(hp, 1.42, z0 + 0.24, 0.58, 2, lod)
        if not lod:
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.58 - 0.46, 1.88, z1 - 0.12), (sx * 0.58 + 0.46, 2.36, z1 + 0.01), tint=GLASS_ARMOUR)
                add_nato_diamond(hp, sx * (hx + 0.008), 1.62, 2.85, sx, size=0.12)
        cab_top, cab_z = 2.52, 2.95
    else:
        hp.box("metal_dark", (-0.52, 0.70, z0), (0.52, 1.16, z1 - 0.12), bevel=bv)
        hp.box("paint", (-hx, 1.16, z0), (hx, 1.38, 0.75), bevel=bv)
        if slug == "mineLayer__km138_truck":
            hp.box("paint", (-hx + 0.12, 1.16, 2.15), (hx - 0.12, 1.88, z1), bevel=bv)
            hp.box("paint", (-hx, 1.16, 0.82), (hx, 2.48, 2.18), bevel=bv)
            win_z = 2.18
        else:
            hp.profile_x("paint", [(0.82, 1.16), (z1 - 0.10, 1.16), (z1, 1.72), (z1 - 0.34, 2.50), (0.82, 2.50)], -hx, hx, bevel=bv)
            win_z = z1 - 0.24
        add_mine_dispenser_racks(hp, 1.38, z0 + 0.20, 0.58, 2, lod)
        if not lod:
            hp.box("metal_dark", (-0.88, 1.20, z1 - 0.02), (0.88, 1.72, z1 + 0.02))
            for sx in (-1, 1):
                hp.box("glass", (sx * 0.52 - 0.40, 1.92, win_z - 0.12), (sx * 0.52 + 0.40, 2.34, win_z + 0.03), tint=GLASS_ARMOUR)
        cab_top, cab_z = 2.50, 1.52

    rig.add("Hull", f"LOD{lod}", (0.0, 0.0, 0.0), hp)
    for side_lbl, sx in (("L", -1), ("R", 1)):
        for i, az in enumerate(axles):
            wp = (sx * wx, wr, az)
            rig.add(f"Wheel_{side_lbl}{i}", f"LOD{lod}", wp, build_offroad_tyre(f"Wheel_{side_lbl}{i}", wp, lod, sx, r=wr, w=tw, hub_style="western", lugs=20))
    add_rws_50cal(rig, 0.42, cab_top, cab_z, lod, style="crows")
    return rig


# =============================================================================
# DISPATCH & EXPORT ALL 32 TIER P2.5 VEHICLES
# =============================================================================

ALL_SLUGS = (
    list(ARV_SPECS.keys())
    + [
        "mineClearer__namer_engineering",
        "mineClearer__puma",
        "mineClearer__m1150_assault_breacher",
        "mineClearer__kodiak",
        "mineClearer__keiler",
        "mineClearer__trojan_avre",
        "mineClearer__k600_rhino",
        "mineClearer__ur_77_meteorit",
        "mineClearer__type_92_mbrs",
        "mineClearer__sdpmac",
        "mineClearer__mine_clearing_vehicle",
        "mineLayer__isdm_zemledelie",
        "mineLayer__gmz_3",
        "mineLayer__m139_volcano",
        "mineLayer__skorpion_mine_dispenser",
        "mineLayer__type_94_amphibious",
        "mineLayer__km138_truck",
        "mineLayer__engineer_minelayer",
    ]
)


def build_rig(slug: str, lod: int) -> VehicleRig:
    if slug in ARV_SPECS:
        return build_arv_rig(slug, lod)
    if slug.startswith("mineClearer__"):
        return build_breacher_rig(slug, lod)
    return build_minelayer_rig(slug, lod)


def export_one(slug: str, out_dir: str):
    init_scene()
    is_big_turret = slug in ("mineClearer__m1150_assault_breacher", "mineClearer__ur_77_meteorit", "mineClearer__type_92_mbrs", "mineLayer__isdm_zemledelie")
    export_vehicle(
        os.path.join(out_dir, f"{slug}.glb"),
        build_rig(slug, 0),
        build_rig(slug, 1),
        turret_offset=(4.0, 0.0, -0.3) if is_big_turret else (3.5, 0.0, 0.1),
        ring_radius=0.82 if is_big_turret else 0.30,
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
