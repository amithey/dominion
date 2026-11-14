"""Blender 5.2 LTS generator for Tier P6 — All 160 Fixed-Wing Aircraft & Drones (`native/godot/assets/art/aircraft/`).

Covers 5th-gen stealth fighters, 4th/4.5-gen fighters, strike/CAS jets, EW aircraft, strategic bombers,
AEW&C radar aircraft, maritime patrol aircraft, MALE/HALE UAVs, loitering munitions, and tactical multirotors.
"""
import math
import os
import sys

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if THIS_DIR not in sys.path:
    sys.path.insert(0, THIS_DIR)

import bl_vehicle as bv
import bl_craft as bc

OUT_DIR = os.path.abspath(os.path.join(THIS_DIR, "..", "..", "..", "godot", "assets", "art", "aircraft"))


def _interp_station(stations, x_target):
    xs = [float(s[0]) for s in stations]
    if x_target <= xs[0]:
        return [float(x_target), float(stations[0][1]), float(stations[0][2]), float(stations[0][3])]
    if x_target >= xs[-1]:
        return [float(x_target), float(stations[-1][1]), float(stations[-1][2]), float(stations[-1][3])]
    for i in range(len(xs) - 1):
        if xs[i] <= x_target <= xs[i + 1]:
            t = (x_target - xs[i]) / max(1e-6, xs[i + 1] - xs[i])
            return [
                float(x_target),
                stations[i][1] * (1 - t) + stations[i + 1][1] * t,
                stations[i][2] * (1 - t) + stations[i + 1][2] * t,
                stations[i][3] * (1 - t) + stations[i + 1][3] * t,
            ]
    return list(stations[0])


def _build_multirotor_lod(s, lod=0):
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    d = s.get("details", {})
    L = max(0.28, float(s["length"]))
    W = max(0.10, float(s["body_width"]))
    H = max(0.10, float(s["body_height"]))
    b = max(0.03, float(s["belly"]))
    cy = b + H * 0.5
    fuse = bc.CraftPart("Fuselage", seed=hash(slug) & 0xFFFF)

    if s["family"] == "firefly_coaxial":
        # Rafael SPIKE Firefly ('Maoz') vertical canister coaxial loitering munition
        r_body = 0.055
        fuse.cyl("paint", (0, 0.03, 0), r_body, 0.30, seg=10 if lod else 18, bevel=0.006)
        fuse.dome("glass", (0, 0.03, 0), r_body * 0.85, -0.028, seg=10, rings=2)
        fuse.box("markings", (-r_body * 1.04, 0.14, -0.02), (r_body * 1.04, 0.19, 0.02))
        for leg in range(3):
            la = math.tau * leg / 3.0
            fuse.pipe("metal_dark", (0.04 * math.cos(la), 0.06, 0.04 * math.sin(la)),
                      (0.09 * math.cos(la), 0.005, 0.09 * math.sin(la)), 0.007, seg=5)
        rig.add("Fuselage", rig.root_name, (0, 0, 0), fuse)
        for ri, ry in enumerate((0.35, 0.40)):
            rp = bc.CraftPart("Rotor_Main" if ri == 0 else "Rotor_Main_2", seed=30 + ri)
            with rp.frame((0, ry, 0)):
                rp.rotor_hub_and_blades(0.20, 2, lod=lod, chord=0.028, phase=ri * 1.57, yellow_tips=False)
            rig.add("Rotor_Main" if ri == 0 else "Rotor_Main_2", "Fuselage", (0, ry, 0), rp)
        return rig

    # Quadcopter / Hexacopter (Baba Yaga / Vampire / Kargu-2 / Nagastra / Shaheen / Interceptor)
    fuse.box("paint", (-W * 0.5, b, -L * 0.20), (W * 0.5, b + H, L * 0.20), bevel=min(0.03, H * 0.2))
    fuse.box("metal_dark", (-W * 0.36, b + H, -L * 0.14), (W * 0.36, b + H + H * 0.22, L * 0.14), bevel=0.01)
    fuse.box("markings", (W * 0.502, cy - H * 0.2, -L * 0.08), (W * 0.52, cy + H * 0.2, L * 0.08))
    # Gimbal EO/thermal camera ball
    fuse.dome("metal_dark", (0, b + 0.02, L * 0.18), W * 0.22, -W * 0.22, seg=10, rings=2)
    fuse.cyl("glass", (0, b - W * 0.06, L * 0.18 + W * 0.14), W * 0.11, 0.03, seg=10, axis="z")

    props = d.get("propellers", [[-0.35, cy + 0.05, 0.35], [0.35, cy + 0.05, 0.35], [-0.35, cy + 0.05, -0.35], [0.35, cy + 0.05, -0.35]])
    prad = float(d.get("prop_radius", 0.20))
    pblades = int(d.get("prop_blades", 2))
    arm_r = max(0.014, W * 0.065)
    for i, pt in enumerate(props):
        px, py, pz = float(pt[0]), float(pt[1]), float(pt[2])
        fuse.pipe("metal_dark", (0, cy, 0), (px, py - 0.03, pz), arm_r, seg=6 if lod else 8)
        fuse.cyl("metal_dark", (px, py - 0.05, pz), arm_r * 1.65, 0.055, seg=8 if lod else 12)

    # Slung munitions / mortar bombs under bomber drones
    p_cnt = int(d.get("payload_count", 1))
    for j in range(p_cnt):
        bx = (j - (p_cnt - 1) * 0.5) * W * 0.32
        if d.get("bomber"):
            fuse.cyl("paint", (bx, max(0.03, b - 0.18), 0.0), 0.055, 0.20, seg=8 if lod else 12, r2=0.02)
        else:
            fuse.cyl("paint", (bx, max(0.04, b - 0.06), -L * 0.10), W * 0.18, L * 0.24, seg=8 if lod else 12, axis="z")

    # Landing skids
    sx = W * 0.78
    for sgn in (-1, 1):
        for sz in (-L * 0.16, L * 0.16):
            fuse.pipe("metal_dark", (sgn * W * 0.35, b + 0.02, sz), (sgn * sx, 0.022, sz), arm_r * 0.75, seg=6)
        fuse.pipe("rubber", (sgn * sx, 0.022, -L * 0.26), (sgn * sx, 0.022, L * 0.26), arm_r * 0.85, seg=6)

    rig.add("Fuselage", rig.root_name, (0, 0, 0), fuse)

    # Each rotor spins around its own motor hub (Rotor_Main, Rotor_Main_2, ...).
    for i, pt in enumerate(props):
        px, py, pz = float(pt[0]), float(pt[1]), float(pt[2])
        r_name = "Rotor_Main" if i == 0 else "Rotor_Main_%d" % (i + 1)
        r_part = bc.CraftPart(r_name, seed=41 + i)
        with r_part.frame((px, py, pz)):
            r_part.rotor_hub_and_blades(prad, pblades, lod=lod, chord=max(0.022, prad * 0.14), yellow_tips=False)
        rig.add(r_name, "Fuselage", (px, py, pz), r_part)
    return rig


def _build_cruciform_lod(s, lod=0):
    """Cruciform X-wing loitering munitions (Hero-120, Lancet-3, HX-2)."""
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    d = s.get("details", {})
    L = float(s["length"])
    S = float(s["span"])
    W = float(s["body_width"])
    H = float(s["body_height"])
    # Ensure X-wings sit >= 0 on ground
    wing_r = S / math.sqrt(2.0)
    cy = max(float(s["belly"]) + H * 0.5, wing_r * 0.72 + 0.03)

    fuse = bc.CraftPart("Fuselage", seed=hash(slug) & 0xFFFF)
    prof = d.get("profile", [(-0.48, 0, 0.28, 0.28), (-0.30, 0, 0.48, 0.48), (0.25, 0, 0.50, 0.50), (0.46, 0, 0.34, 0.34), (0.50, 0, 0.12, 0.12)])
    fuse.loft_shell("paint", [(z * L, cy + dy * H, max(0.015, rx * W), max(0.015, ry * H)) for z, dy, rx, ry in prof],
                    seg=10 if lod else 22, subdiv=1 if lod else 2)
    # Electro-optical glass nose seeker
    fuse.dome("glass", (0, cy, L * 0.48), W * 0.34, W * 0.20, seg=10 if lod else 16, rings=2) if False else None
    fuse.cyl("glass", (0, cy, L * 0.485), W * 0.32, 0.035, seg=10 if lod else 16, r2=W * 0.18, axis="z")
    fuse.box("markings", (-W * 0.52, cy - H * 0.18, -L * 0.08), (W * 0.52, cy + H * 0.18, -L * 0.02))

    # Front & rear X-wing banks at 45/135/225/315 deg
    for bank in (0, 1):
        rad = wing_r * (1.0 if bank == 0 else float(d.get("rear_span_ratio", 0.65)))
        zc = L * (float(d.get("front_bank", 0.12)) if bank == 0 else -0.31)
        ch = L * (0.16 if bank == 0 else 0.11)
        for j in range(4):
            ang = math.radians(45.0 + 90.0 * j)
            with fuse.frame((0, cy, 0), roll=ang):
                fuse.airfoil_wing("paint", [
                    (W * 0.34, 0.0, zc + ch * 0.5, zc - ch * 0.5),
                    (rad, 0.0, zc + ch * 0.32, zc - ch * 0.62),
                ], chord_steps=5, span_steps=1, thickness=0.08)

    # Pusher propeller at tail
    fuse.cyl("metal_dark", (0, cy, -L * 0.51), W * 0.20, 0.06, seg=8 if lod else 12, r2=0.02, axis="z")
    rig.add("Fuselage", rig.root_name, (0, 0, 0), fuse)
    prop = bc.CraftPart("Propeller", seed=51)
    pr = float(d.get("prop_radius", max(0.14, W * 1.1)))
    with prop.frame((0, cy, -L * 0.50), pitch=math.pi * 0.5):
        prop.rotor_hub_and_blades(pr, int(d.get("prop_blades", 2)), lod=lod, chord=pr * 0.15, yellow_tips=False)
    rig.add("Propeller", "Fuselage", (0, cy, -L * 0.50), prop)
    return rig


def _build_fixed_wing_lod(s, lod=0):
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    fam = s["family"]
    d = s.get("details", {})
    L = float(s["length"])
    S = float(s["span"])
    W = float(s["body_width"])
    H = float(s["body_height"])
    b = float(s["belly"])
    if d.get("oneway"):
        b = max(0.12, b)
    cy = b + H * 0.5
    stealth = bool(s.get("stealth", False)) or fam in ("f35", "f22", "j20", "su57", "kf21", "carrier_ucav")
    unmanned = bool(d.get("unmanned", False)) or int(s.get("seats", 1)) == 0
    transport = bool(d.get("transport", False))
    is_sufa = "sufa" in slug
    is_shahed = slug.startswith("shahed__")

    fuse = bc.CraftPart("Fuselage", seed=hash(slug) & 0xFFFF)
    seg = 12 if lod else (28 if transport else 32)
    sub = 1 if lod else 3
    ao = (b * 0.5, b + H * 1.35, 0.76)

    # ------------------------------------------------------------ 1. Lofted Fuselage & Radome
    default_prof = [
        (-0.46, 0.0, 0.28, 0.30), (-0.40, 0.0, 0.46, 0.46), (-0.20, 0.0, 0.50, 0.50),
        (0.05, 0.01, 0.50, 0.50), (0.18, 0.03, 0.38, 0.43), (0.32, 0.04, 0.25, 0.31),
        (0.43, 0.01, 0.14, 0.17), (0.50, -0.01, 0.015, 0.020),
    ]
    prof = d.get("profile", default_prof)
    sections = [(z * L, cy + dy * H, max(0.008, rx * W), max(0.008, ry * H)) for z, dy, rx, ry in prof]

    def fuse_role(z, th):
        if d.get("glazed_nose") and z > L * 0.43 and math.cos(th) < 0.45:
            return "glass"
        if transport:
            if L * 0.33 < z < L * 0.425 and 0.32 < math.cos(th) < 0.90 and abs(math.sin(th)) > 0.07:
                return "glass"
            if z > L * 0.455:
                return "radome"
            return "paint"
        # Dielectric nose radome cone on combat jets & patrol aircraft
        if not unmanned and not d.get("nose_intake") and fam not in ("a10", "tucano") and z > L * 0.405:
            return "radome"
        return "paint"

    chine_v = 0.28 if stealth else (0.14 if fam in ("f16", "hornet", "rafale", "flanker", "j10") else 0.0)
    fuse.loft_shell("paint", sections, seg=seg, subdiv=sub,
                    cross_power=float(d.get("cross_power", 1.0)), chine=chine_v,
                    cap_start=(int(s.get("engines", 1)) != 1 or bool(d.get("propellers"))),
                    cap_end=not bool(d.get("nose_intake")),
                    role_fn=fuse_role, ao_y=ao)

    # Framed Bubble Canopy on manned combat/trainer aircraft
    if not transport and not unmanned:
        top_y = b + H
        cf = L * float(d.get("canopy_front", 0.385))
        cr = L * float(d.get("canopy_rear", 0.075 if int(s.get("seats", 1)) == 2 else 0.155))
        cm = 0.5 * (cf + cr)
        seats = int(s.get("seats", 1))

        def can_role(z, th):
            if z < cr + 0.08 or z > cf - 0.07:
                return "paint"
            if abs(z - (cf - (cf - cr) * 0.26)) < 0.035:
                return "metal_dark"  # windscreen bow arch
            if seats == 2 and not d.get("side_by_side") and abs(z - cm) < 0.045:
                return "metal_dark"  # tandem frame arch
            return "glass" if (math.cos(th) > -0.15 and 0.16 < th < math.tau - 0.16) else "paint"

        fuse.loft_shell("paint", [
            (cr, top_y - 0.10, W * 0.14, 0.09),
            (cr + (cf - cr) * 0.20, top_y + 0.18, W * 0.27, 0.42),
            (cm, top_y + 0.21, W * 0.28, 0.48),
            (cf - (cf - cr) * 0.18, top_y + 0.11, W * 0.22, 0.36),
            (cf, top_y - 0.05, W * 0.05, 0.07),
        ], seg=10 if lod else 22, subdiv=1 if lod else 2, role_fn=can_role)

    # Conformal Fuel Tanks (F-15I Ra'am / F-15EX / F-15SA & Israeli F-16I Sufa dorsal spine + shoulder CFTs!)
    if d.get("cft"):
        for sgn in (-1, 1):
            with fuse.frame((sgn * W * 0.52, 0, 0)):
                fuse.loft_shell("paint", [
                    (-L * 0.27, cy - 0.22, 0.16, 0.26), (-L * 0.18, cy - 0.20, 0.36, 0.48),
                    (L * 0.02, cy - 0.18, 0.36, 0.48), (L * 0.09, cy - 0.16, 0.15, 0.24),
                ], seg=8 if lod else 14, subdiv=1, cross_power=0.82, ao_y=ao)
    if is_sufa or (fam == "f16" and int(s.get("seats", 1)) == 2 and "barak" not in slug):
        # Iconic Israeli F-16I Sufa dorsal avionics spine + upper shoulder CFTs
        fuse.box("paint", (-0.22, b + H - 0.08, -L * 0.34), (0.22, b + H + 0.24, L * 0.08), bevel=0.06)
        if is_sufa:
            for sgn in (-1, 1):
                with fuse.frame((sgn * W * 0.44, b + H - 0.14, 0.0)):
                    fuse.loft_shell("paint", [
                        (-L * 0.22, 0, 0.12, 0.10), (-L * 0.12, 0.04, 0.28, 0.22),
                        (L * 0.06, 0.04, 0.26, 0.20), (L * 0.14, 0, 0.10, 0.08),
                    ], seg=8 if lod else 14, subdiv=1)

    # F-35 EOTS electro-optical faceted prism under nose
    if fam == "f35" and not lod:
        fuse.box("glass", (-0.11, b + 0.06, L * 0.30), (0.11, b + 0.22, L * 0.35), bevel=0.02)

    #LEX strakes on F-16 / Hornet / Flanker / MiG-29 / FA-50
    if fam in ("f16", "hornet", "flanker", "mig29", "fa50") or d.get("lex"):
        wy_lex = b + H * 0.56
        for m_x in (False, True):
            fuse.airfoil_wing("paint", [
                (W * 0.34, wy_lex, L * 0.22, -L * 0.10),
                (W * 0.92, wy_lex, L * 0.02, -L * 0.12),
            ], chord_steps=5, span_steps=1, thickness=0.05, mirror_x=m_x)

    # UAV bulbous SATCOM nose hump & chin EO/IR gimbal turret
    if unmanned:
        if d.get("nose_hump") or fam in ("hermes900", "herontp", "mq9a", "mq9b", "wingloong1", "wingloong2", "ch4", "akinci", "orion", "kusfs", "rq4", "saetbyol9"):
            fuse.loft_shell("paint", [
                (L * 0.10, b + H * 0.85, W * 0.18, 0.08),
                (L * 0.22, b + H * 0.98, W * 0.44, H * 0.32),
                (L * 0.35, b + H * 0.94, W * 0.38, H * 0.28),
                (L * 0.44, b + H * 0.72, W * 0.12, 0.06),
            ], seg=8 if lod else 16, subdiv=1)
        if not d.get("oneway") and d.get("sensor_turret", True):
            sz = L * 0.28
            sr = min(W * 0.26, 0.22)
            fuse.dome("metal_dark", (0, b + 0.04, sz), sr, -sr * 1.15, seg=10 if lod else 14, rings=3)
            fuse.cyl("glass", (0, b - sr * 0.55, sz + sr * 0.65), sr * 0.55, 0.04, seg=10, axis="z")

    # Twin tail booms (Bayraktar TB2, Heron, Heron TP, Mohajer-6)
    if d.get("twin_boom"):
        bx = float(d["boom_x"])
        by_b = float(d["boom_y"])
        for sgn in (-1, 1):
            fuse.pipe("paint", (sgn * bx, by_b, L * 0.02), (sgn * bx, by_b, -L * 0.46), max(0.06, W * 0.10), seg=8 if lod else 12)

    # MPA magnetic anomaly detector (MAD) tail sting (P-3C, P-1, Il-38N, Atlantique 2, Y-8Q)
    if d.get("tail_sting"):
        fuse.pipe("radome", (0, cy + H * 0.08, -L * 0.45), (0, cy + H * 0.10, -L * 0.56), 0.14, seg=8, r2=0.04)

    # ------------------------------------------------------------ 2. Main Wings, Winglets, Canards & Empennage
    wing_sts = d.get("wing")
    if wing_sts:
        c_steps = 5 if lod else 9
        s_steps = 1 if lod else 2
        for m_x in (False, True):
            fuse.airfoil_wing("paint", wing_sts, chord_steps=c_steps, span_steps=s_steps,
                              thickness=0.072 if stealth or not transport else 0.105, mirror_x=m_x, ao_y=ao)
            # Wing roundels (`markings`) on upper wing surface
            st_m = _interp_station(wing_sts, S * 0.30)
            mx = (-1.0 if m_x else 1.0) * st_m[0]
            mz_w = 0.5 * (st_m[2] + st_m[3])
            rw = max(0.14, (st_m[2] - st_m[3]) * 0.18)
            fuse.cyl("markings", (mx, st_m[1] + 0.04, mz_w), rw, 0.035, seg=8 if lod else 14)

        # Winglets (G550, GlobalEye, P-8A, E-7A) OR Shahed wingtip stabilizers OR Wingtip AAM rails
        tip = wing_sts[-1]
        if is_shahed:
            for sgn in (-1, 1):
                fuse.box("paint", (sgn * tip[0] - 0.02, tip[1] - 0.16, tip[3] - 0.05),
                         (sgn * tip[0] + 0.02, tip[1] + 0.38, tip[2] + 0.02), bevel=0.008)
        elif d.get("winglets"):
            for sgn in (-1, 1):
                with fuse.frame((0.0, tip[1], 0.0)):
                    fuse.airfoil_wing("paint", [
                        (0.0, sgn * tip[0], tip[2], tip[3]),
                        (1.45, sgn * tip[0], tip[2] - 0.45, tip[3] - 0.35),
                    ], chord_steps=4, span_steps=1, vertical_cant_deg=sgn * 14.0)
        elif d.get("wingtip_pods") or fam in ("f16", "hornet", "gripen", "jf17", "fa50", "j16d"):
            for sgn in (-1, 1):
                zc_t = 0.5 * (tip[2] + tip[3])
                pr_t = 0.16 if "j_16d" in slug or d.get("ew_pods") else 0.075
                fuse.cyl("paint", (sgn * tip[0], tip[1], zc_t - 0.75), pr_t, 1.55, seg=8 if lod else 12, r2=pr_t * 0.65, axis="z")

    # Vertical Fins, Stabilators & Canards
    for fin in d.get("fins", []):
        fx, y0, y1, le0, te0, le1, te1 = [float(v) for v in fin]
        cant = float(d.get("fin_cant", 0.0)) * (1.0 if fx >= 0 else -1.0)
        with fuse.frame((0.0, y0, 0.0)):
            fuse.airfoil_wing("paint", [
                (0.0, fx, le0, te0),
                (y1 - y0, fx, le1, te1),
            ], chord_steps=5 if lod else 7, span_steps=1, thickness=0.075, vertical_cant_deg=cant)
        # Fin flash marking
        if not lod and abs(y1 - y0) > 0.6:
            ym = y0 + (y1 - y0) * 0.55
            xm = fx + (ym - y0) * math.sin(math.radians(cant))
            zm = 0.5 * ((le0 + le1) * 0.5 + (te0 + te1) * 0.5)
            fuse.box("markings", (xm - 0.055, ym - 0.14, zm - 0.18), (xm + 0.055, ym + 0.14, zm + 0.18))

    for h_key in ("stabilator", "canard"):
        if h_key in d:
            for m_x in (False, True):
                fuse.airfoil_wing("paint", d[h_key], chord_steps=4 if lod else 7, span_steps=1, thickness=0.07, mirror_x=m_x)

    # ------------------------------------------------------------ 3. Jet Intakes, Nacelles, Afterburners & Propellers
    if d.get("turbofans"):
        fr = float(d["fan_radius"])
        fl = float(d["fan_length"])
        for pt in d["turbofans"]:
            tx, ty_f, tz_f = float(pt[0]), float(pt[1]), float(pt[2])
            if d.get("supersonic_pods"):
                fuse.intake_duct(tx, ty_f, tz_f + fl * 0.5, tx, ty_f, tz_f - fl * 0.45, fr * 1.75, fr * 1.55)
                fuse.exhaust_nozzle(tx, ty_f, tz_f - fl * 0.42, tz_f - fl * 0.58, fr * 0.72, fr * 0.58, seg=10 if lod else 16, petals=not lod)
            else:
                with fuse.frame((tx, 0, 0)):
                    fuse.loft_shell("paint", [
                        (tz_f - fl * 0.50, ty_f, fr * 0.68, fr * 0.68),
                        (tz_f - fl * 0.22, ty_f, fr * 0.94, fr * 0.94),
                        (tz_f + fl * 0.28, ty_f, fr, fr),
                        (tz_f + fl * 0.50, ty_f, fr * 0.92, fr * 0.92),
                    ], seg=10 if lod else 20, subdiv=1, cap_start=False, cap_end=False)
                fuse.tube_axis("metal", (tx, ty_f, tz_f + fl * 0.42), (tx, ty_f, tz_f + fl * 0.51), fr * 0.94, fr * 0.80, seg=10 if lod else 20)
                fuse.cyl("metal_dark", (tx, ty_f, tz_f + fl * 0.25), fr * 0.80, 0.08, seg=10 if lod else 16, axis="z")
                fuse.exhaust_nozzle(tx, ty_f, tz_f - fl * 0.44, tz_f - fl * 0.58, fr * 0.68, fr * 0.52, seg=10 if lod else 16, petals=False)
                # Pylon to wing or rear fuselage
                if d.get("rear_engines"):
                    fuse.box("paint", (math.copysign(W * 0.40, tx), ty_f - 0.08, tz_f - fl * 0.28),
                             (tx, ty_f + 0.08, tz_f + fl * 0.22), bevel=0.02)
                elif wing_sts:
                    st_e = _interp_station(wing_sts, abs(tx))
                    fuse.box("paint", (tx - 0.09, ty_f + fr * 0.65, tz_f - fl * 0.42),
                             (tx + 0.09, st_e[1] + 0.04, tz_f + fl * 0.12), bevel=0.02)
    elif not d.get("propellers"):
        n_eng = int(s.get("engines", 1))
        esp = float(d.get("engine_spacing", W * 0.62))
        er = float(d.get("engine_radius", 0.43 if n_eng == 2 else 0.50))
        aft = L * (0.50 - float(d.get("engine_aft_fraction", 0.50)))
        for i in range(n_eng):
            ex = (i - (n_eng - 1) * 0.5) * esp
            if n_eng == 2 and not d.get("square_nozzle"):
                with fuse.frame((ex, 0, aft)):
                    fuse.loft_shell("paint", [
                        (-L * 0.45, cy, er * 0.98, er * 0.98),
                        (-L * 0.38, cy, er * 1.12, er * 1.12),
                        (-L * 0.12, cy, er * 1.14, er * 1.14),
                        (L * 0.04, cy, er * 0.88, er * 0.88),
                    ], seg=10 if lod else 18, subdiv=1, cap_start=False)
            if d.get("square_nozzle"):
                # F-22 Raptor 2D thrust-vectoring rectangular stealth nozzles
                fuse.intake_duct(ex, cy, -L * 0.50, ex, cy, -L * 0.43, 1.18, 0.46, role="metal_dark")
            else:
                fuse.exhaust_nozzle(ex, cy, -L * 0.445 + aft, -L * 0.502 + aft, er, er * 0.82, seg=10 if lod else 20, petals=not lod)

        # Air Intakes per fighter family
        if fam == "f15":
            for sgn in (-1, 1):
                fuse.intake_duct(sgn * 1.24, cy + 0.02, L * 0.16, sgn * 0.82, cy, -L * 0.18, 1.04, 1.02)
        elif fam == "typhoon":
            for sgn in (-1, 1):
                fuse.intake_duct(sgn * 0.42, b + 0.24, L * 0.16, sgn * 0.46, cy - 0.08, -L * 0.08, 0.78, 0.72)
        elif d.get("nose_intake"):
            nr = float(d.get("nose_radius", 0.45))
            fuse.tube_axis("metal_dark", (0, cy, L * 0.44), (0, cy, L * 0.495), nr, nr * 0.84, seg=10 if lod else 20)
            fuse.cyl("radome", (0, cy, L * 0.41), nr * 0.48, L * 0.10, seg=8 if lod else 16, r2=0.02, axis="z")
        elif d.get("dorsal_intake"):
            fuse.intake_duct(0.0, b + H + 0.16, L * 0.22, 0.0, cy, -L * 0.04, 0.96, 0.44, roundness=0.5)
        elif d.get("side_intakes") or stealth:
            ix = float(d.get("intake_x", W * 0.54))
            iz = L * float(d.get("intake_z", 0.18))
            iw = float(d.get("intake_width", 0.72))
            ih = float(d.get("intake_height", 0.74))
            rnd = 0.6 if d.get("intake_round") else 0.0
            for sgn in (-1, 1):
                fuse.intake_duct(sgn * ix, cy - 0.08, iz, sgn * ix * 0.80, cy, -L * 0.08, iw, ih, roundness=rnd)
        else:
            # F-16 / J-10C / JF-17 underslung chin intake
            fuse.intake_duct(0.0, b + 0.16, L * 0.20, 0.0, cy - 0.10, -L * 0.06, 1.16, 0.66, roundness=0.7)

    # Turboprop nacelles on wing
    if d.get("propellers") and d.get("prop_nacelle"):
        plen = float(d["prop_nacelle"])
        pr_n = float(d["prop_radius"]) * 0.34
        for pt in d["propellers"]:
            px, py_p, pz_p = float(pt[0]), float(pt[1]), float(pt[2])
            with fuse.frame((px, 0, 0)):
                fuse.loft_shell("paint", [
                    (pz_p - plen, py_p, pr_n * 0.38, pr_n * 0.38),
                    (pz_p - plen * 0.65, py_p, pr_n, pr_n * 1.05),
                    (pz_p - plen * 0.18, py_p, pr_n, pr_n),
                    (pz_p - 0.08, py_p, pr_n * 0.48, pr_n * 0.48),
                ], seg=8 if lod else 16, subdiv=1)

    # ------------------------------------------------------------ 4. Landing Gear, Weapons & Fixed AEW Radars
    if not d.get("landing_none") and not d.get("oneway"):
        if d.get("gear_layout"):
            for gs in d["gear_layout"]:
                gx, gz = float(gs["x"]), float(gs["z"])
                gr = float(gs.get("radius", 0.46))
                hy = float(gs.get("hinge_y", b + 0.30))
                fuse.pipe("metal_dark", (gx, hy, gz + 0.18), (gx, gr, gz), 0.085, seg=6 if lod else 10)
                fuse.wheel_aircraft((gx, gr, gz), gr, lod=lod, dual=(int(gs.get("pairs", 2)) >= 2))
        else:
            gtrack = float(d.get("gear_track", S * 0.24))
            wr = float(d.get("wheel_radius", 0.34))
            for gname, gx, gz in (("N", 0.0, L * 0.27), ("L", -gtrack * 0.5, -L * 0.075), ("R", gtrack * 0.5, -L * 0.075)):
                gr = wr * (0.76 if gname == "N" else 1.0)
                hx = gx * 0.72
                if unmanned:
                    hx = math.copysign(min(abs(hx), W * 0.38), gx) if gx != 0 else 0.0
                fuse.pipe("metal_dark", (hx, b + 0.30, gz + 0.16), (gx, gr, gz), max(0.04, gr * 0.17), seg=6 if lod else 10)
                fuse.wheel_aircraft((gx, gr, gz), gr, lod=lod, dual=(transport and gname != "N"))

    # Underwing Pylons & Ordnance (or Internal Stealth Weapon Bay Doors + A-10 GAU-8 Gatling)
    if d.get("gatling") or fam == "a10":
        fuse.cyl("metal_dark", (0.0, b + H * 0.34, L * 0.46), 0.15, 0.42, seg=8 if lod else 14, axis="z")
        if not lod:
            for bi in range(7):
                ba = math.tau * bi / 7.0
                fuse.pipe("metal", (0.07 * math.cos(ba), b + H * 0.34 + 0.07 * math.sin(ba), L * 0.48),
                          (0.07 * math.cos(ba), b + H * 0.34 + 0.07 * math.sin(ba), L * 0.54), 0.022, seg=6)

    if stealth or d.get("internal_bomber"):
        for sgn in (-1, 1):
            fuse.box("metal_dark", (sgn * W * 0.04, b - 0.01, -L * 0.09),
                     (sgn * W * 0.44, b + 0.05, L * 0.09), bevel=0.01)
    elif wing_sts and not transport and not d.get("oneway"):
        stations_f = d.get("stations", (0.40, 0.66, 0.88))
        slen = float(d.get("store_length", 1.95))
        srad = float(d.get("store_radius", 0.105))
        for sgn in (-1, 1):
            for j, sf in enumerate(stations_f):
                st_w = _interp_station(wing_sts, S * 0.5 * float(sf))
                wx_p = sgn * st_w[0]
                wy_p = st_w[1] - 0.20
                wz_p = 0.5 * (st_w[2] + st_w[3])
                fuse.box("paint", (wx_p - 0.045, wy_p - 0.04, wz_p - 0.32), (wx_p + 0.045, st_w[1] + 0.02, wz_p + 0.32), bevel=0.01)
                my_s = wy_p - 0.16
                if j == 0 and not unmanned and L > 13.0 and not d.get("ew_pods"):
                    # Inboard external drop tank / heavy standoff store
                    with fuse.frame((wx_p, my_s - 0.06, wz_p)):
                        fuse.loft_shell("paint", [
                            (-slen * 0.62, 0, 0.06, 0.06), (-slen * 0.30, 0, srad * 2.1, srad * 2.1),
                            (slen * 0.32, 0, srad * 2.1, srad * 2.1), (slen * 0.66, 0, 0.05, 0.05),
                        ], seg=8 if lod else 14, subdiv=1)
                else:
                    # Air-to-air / precision-guided missile with seeker head & cruciform fins
                    fuse.cyl("white" if not unmanned else "paint", (wx_p, my_s, wz_p - slen * 0.48), srad, slen * 0.88, seg=6 if lod else 12, axis="z")
                    fuse.cyl("radome", (wx_p, my_s, wz_p + slen * 0.40), srad, slen * 0.14, seg=6 if lod else 12, r2=0.02, axis="z")
                    if not lod:
                        fuse.box("metal_dark", (wx_p - srad * 2.2, my_s - 0.015, wz_p - slen * 0.42),
                                 (wx_p + srad * 2.2, my_s + 0.015, wz_p - slen * 0.26))
                        fuse.box("metal_dark", (wx_p - 0.015, my_s - srad * 2.2, wz_p - slen * 0.42),
                                 (wx_p + 0.015, my_s + srad * 2.2, wz_p - slen * 0.26))
        if d.get("ew_pods"):
            for sgn in (-1, 1):
                st_ew = _interp_station(wing_sts, S * 0.22)
                ex_w, ey_w, ez_w = sgn * st_ew[0], st_ew[1] - 0.56, 0.5 * (st_ew[2] + st_ew[3])
                fuse.box("paint", (ex_w - 0.05, ey_w + 0.14, ez_w - 0.35), (ex_w + 0.05, st_ew[1], ez_w + 0.35))
                fuse.cyl("radome", (ex_w, ey_w, ez_w - 1.35), 0.22, 2.70, seg=8 if lod else 14, r2=0.14, axis="z")

    # Static AEW&C / ISR Radar Fairings (Wedgetail MESA top-hat, Erieye/GlobalEye dorsal bar, G550 Eitam conformal cheeks)
    if d.get("aesa_bar"):
        ab = d["aesa_bar"]
        ay_r, az_r = float(ab["y"]), float(ab["z"])
        alen, awid, aht = float(ab["length"]), float(ab["width"]), float(ab["height"])
        fuse.box("paint", (-0.28, b + H - 0.10, az_r - alen * 0.36), (0.28, ay_r, az_r + alen * 0.36), bevel=0.04)
        fuse.box("radome", (-awid * 0.5, ay_r - aht * 0.5, az_r - alen * 0.5),
                 (awid * 0.5, ay_r + aht * 0.5, az_r + alen * 0.5), bevel=min(0.12, aht * 0.3))
    if d.get("conformal_radar"):
        for sgn in (-1, 1):
            with fuse.frame((sgn * W * 0.46, 0, 0)):
                fuse.loft_shell("radome", [
                    (-L * 0.22, cy, 0.10, 0.16), (-L * 0.15, cy, 0.30, 0.46),
                    (L * 0.12, cy, 0.30, 0.46), (L * 0.20, cy, 0.10, 0.16),
                ], seg=8 if lod else 16, subdiv=1)
    if d.get("belly_radar"):
        bx_r, by_r, bz_r, brx, bry, bhalf = [float(v) for v in d["belly_radar"]]
        with fuse.frame((bx_r, 0, 0)):
            fuse.loft_shell("radome", [
                (bz_r - bhalf, by_r, brx * 0.15, bry * 0.15),
                (bz_r, by_r, brx, bry),
                (bz_r + bhalf, by_r, brx * 0.15, bry * 0.15),
            ], seg=8 if lod else 18, subdiv=1)
    if d.get("radome"):
        rx_d, ry_d, rz_d, rrx, rrz, rh = [float(v) for v in d["radome"]]
        # Twin aerodynamic support struts under rotodome
        for sgn in (-1, 1):
            fuse.box("paint", (sgn * 0.58 - 0.12, b + H - 0.18, rz_d - 0.85),
                     (sgn * 0.58 + 0.12, ry_d - rh * 0.32, rz_d + 0.85), bevel=0.03)

    rig.add("Fuselage", rig.root_name, (0, 0, 0), fuse)

    # ------------------------------------------------------------ 5. Articulated Propellers & Rotating AEW Rotodome (`Radar`)
    if d.get("propellers"):
        prad = float(d["prop_radius"])
        pblades = int(d["prop_blades"])
        pusher = bool(d.get("prop_pusher", False))
        for i, pt in enumerate(d["propellers"]):
            px, py_p, pz_p = float(pt[0]), float(pt[1]), float(pt[2])
            pname = "Propeller" if i == 0 else f"Propeller_{i}"
            pp = bc.CraftPart(pname, seed=60 + i)
            sgn_p = -1.0 if pusher else 1.0
            pp.cyl("paint", (px, py_p, pz_p - 0.08 * sgn_p), prad * 0.15, 0.30 * sgn_p, seg=8 if lod else 14, r2=0.02, axis="z")
            with pp.frame((px, py_p, pz_p), pitch=math.pi * 0.5):
                pp.rotor_hub_and_blades(prad, pblades, lod=lod, chord=max(0.05, prad * 0.11), yellow_tips=not unmanned)
            rig.add(pname, "Fuselage", (px, py_p, pz_p), pp)

    if d.get("radome"):
        rx_d, ry_d, rz_d, rrx, rrz, rh = [float(v) for v in d["radome"]]
        rname = "Radar_Disc" if d.get("radome_static") else "Radar"
        rd_p = bc.CraftPart(rname, seed=70)
        rd_p.loft_shell("radome", [
            (rz_d - rrz, ry_d, rrx * 0.15, rh * 0.12),
            (rz_d - rrz * 0.72, ry_d, rrx * 0.72, rh * 0.42),
            (rz_d, ry_d, rrx, rh * 0.52),
            (rz_d + rrz * 0.72, ry_d, rrx * 0.72, rh * 0.42),
            (rz_d + rrz, ry_d, rrx * 0.15, rh * 0.12),
        ], seg=12 if lod else 28, subdiv=1)
        # Characteristic white/dark IFF stripe across rotodome top
        rd_p.box("white", (rx_d - rrx * 0.86, ry_d + rh * 0.46, rz_d - 0.25),
                 (rx_d + rrx * 0.86, ry_d + rh * 0.54, rz_d + 0.25))
        rig.add(rname, "Fuselage", (rx_d, ry_d, rz_d), rd_p)

    return rig


def build_one(spec):
    slug = spec["slug"]
    out_path = os.path.join(OUT_DIR, f"{slug}.glb")
    d = spec.get("details", {})
    if d.get("multirotor") or spec["family"] == "firefly_coaxial":
        lod0 = _build_multirotor_lod(spec, lod=0)
        lod1 = _build_multirotor_lod(spec, lod=1)
    elif d.get("cruciform"):
        lod0 = _build_cruciform_lod(spec, lod=0)
        lod1 = _build_cruciform_lod(spec, lod=1)
    else:
        lod0 = _build_fixed_wing_lod(spec, lod=0)
        lod1 = _build_fixed_wing_lod(spec, lod=1)
    bc.export_craft(out_path, lod0, lod1, wreck_roll=12.0)


def main():
    bv.init_scene()
    specs = bc.load_specs()["P6"]
    only = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("-")] if "--" in sys.argv else []
    keys = [k for k in sorted(specs) if not only or any(o in k for o in only)]
    print(f"Building {len(keys)} P6 fixed-wing & drone models in Blender 5.2 LTS...")
    for k in keys:
        build_one(specs[k])
    print(f"P6 COMPLETE: {len(keys)} / {len(specs)} fixed-wing & drone models exported to {OUT_DIR}")


if __name__ == "__main__":
    main()
