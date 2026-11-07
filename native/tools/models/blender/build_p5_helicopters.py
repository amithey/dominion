"""Blender 5.2 LTS generator for Tier P5 — All 91 Rotorcraft (`native/godot/assets/art/aircraft/`).

Covers utility/assault (`helicopter__*`), attack gunships (`gunship__*`), naval ASW/ASuW (`navalHelicopter__*`),
heavy-lift transports (`heavyLift__*`), armed scouts (`scoutHelicopter__*`), rotary carrier UAVs (`s100`, `vsr700`),
and AEW rotorcraft (`aewc__merlin_hm2_crowsnest`).
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


def _build_heli_lod(s, lod=0):
    rig = bv.VehicleRig(lod=lod)
    slug = s["slug"]
    fam = s["family"]
    d = s.get("details", {})
    L = float(s["length"])
    W = float(s["width"])
    H = float(s["body_height"])
    b = float(s["belly"])
    cy = b + H * 0.5
    is_ch53 = "ch_53" in slug
    is_crowsnest = "crowsnest" in slug
    is_saraf = "saraf" in slug
    attack = bool(s.get("attack", False)) or fam == "oh1"
    naval = bool(s.get("naval", False))
    broad = fam in ("mi8", "mi17", "mi26", "chinook", "ka27", "z8") or is_ch53

    fuse = bc.CraftPart("Fuselage", seed=hash(slug) & 0xFFFF)
    seg = 12 if lod else 32
    sub = 1 if lod else 3
    ao = (b * 0.6, b + H * 1.25, 0.74)

    # ------------------------------------------------------------ 1. Main Fuselage Shell
    if "profile" in d:
        sections = [(z * L, cy + dy * H, max(0.03, wx * W), max(0.03, hy * H)) for z, dy, wx, hy in d["profile"]]
    elif fam == "chinook":
        sections = [
            (-L * 0.49, cy + 0.22, W * 0.24, H * 0.30),
            (-L * 0.40, cy + 0.04, W * 0.47, H * 0.48),
            (-L * 0.12, cy, W * 0.50, H * 0.50),
            (L * 0.18, cy, W * 0.50, H * 0.50),
            (L * 0.36, cy - 0.02, W * 0.46, H * 0.48),
            (L * 0.46, cy - H * 0.10, W * 0.28, H * 0.34),
            (L * 0.50, cy - H * 0.18, W * 0.08, H * 0.12),
        ]
    elif fam == "s100":
        sections = [
            (-L * 0.46, cy + 0.04, W * 0.08, H * 0.09),
            (-L * 0.15, cy + 0.02, W * 0.24, H * 0.26),
            (L * 0.08, cy, W * 0.50, H * 0.50),
            (L * 0.30, cy - 0.03, W * 0.38, H * 0.40),
            (L * 0.48, cy - 0.08, W * 0.08, H * 0.10),
        ]
    elif fam in ("littlebird", "md500d"):
        # Iconic Hughes/MD500 teardrop egg cabin
        sections = [
            (-L * 0.10, cy + 0.06, W * 0.20, H * 0.24),
            (L * 0.04, cy + 0.02, W * 0.46, H * 0.48),
            (L * 0.20, cy, W * 0.50, H * 0.50),
            (L * 0.36, cy - 0.05, W * 0.40, H * 0.42),
            (L * 0.47, cy - 0.14, W * 0.18, H * 0.22),
            (L * 0.50, cy - 0.18, W * 0.06, H * 0.08),
        ]
    elif attack:
        end_z = -0.24 if fam == "mi24" else -0.14
        sections = [
            (L * end_z, cy + 0.04, W * 0.24, H * 0.32),
            (-L * 0.04, cy + 0.02, W * 0.48, H * 0.46),
            (L * 0.11, cy + 0.11, W * 0.50, H * 0.52),
            (L * 0.23, cy + 0.03, W * 0.44, H * 0.48),
            (L * 0.34, cy - 0.11, W * 0.38, H * 0.41),
            (L * 0.45, cy - 0.19, W * 0.23, H * 0.26),
            (L * 0.50, cy - 0.25, W * 0.06, H * 0.08),
        ]
    else:
        end_z = -0.18 if broad else -0.12
        nose_z = 0.40 if fam in ("blackhawk", "z20", "surion", "nh90") else 0.43
        sections = [
            (L * end_z, cy + 0.08, W * 0.24, H * 0.30),
            (-L * 0.09, cy, W * 0.45, H * 0.47),
            (L * 0.05, cy, W * 0.50, H * 0.50),
            (L * 0.24, cy, W * 0.50, H * 0.50),
            (L * nose_z, cy - 0.05, W * 0.32, H * 0.38),
            (L * 0.485, cy - H * 0.15, W * 0.12, H * 0.16),
            (L * 0.50, cy - H * 0.18, W * 0.04, H * 0.06),
        ]

    def role_window(z, th):
        if fam == "s100":
            return "radome" if z > L * 0.38 else "paint"
        upper = math.cos(th) > 0.08
        # Nose radome cap on transport/naval helis
        if not attack and fam not in ("littlebird", "md500d", "chinook") and z > L * 0.465:
            return "radome"
        # Mi-24 Hind side troop cabin windows + double bubble canopies
        if fam == "mi24":
            if abs(math.sin(th)) > 0.90 and -0.05 < math.cos(th) < 0.52:
                if any(abs(z - q * L) < L * 0.022 for q in (-0.10, -0.03, 0.04)):
                    return "glass"
            if (L * 0.14 < z < L * 0.24 or L * 0.27 < z < L * 0.38) and math.cos(th) > 0.22 and 0.30 < th < math.tau - 0.30:
                return "glass"
            return "paint"
        # Ka-52 side-by-side armoured canopy
        if fam == "ka52":
            if L * 0.17 < z < L * 0.39 and upper and 0.28 < th < math.tau - 0.28 and abs(math.sin(th)) > 0.08:
                return "glass"
            return "radome" if z > L * 0.43 else "paint"
        # Tandem stepped gunships (Apache, Cobra, Mi-28, Tiger, T129, Z-10, LCH)
        if attack:
            if L * 0.09 < z < L * 0.35 and math.cos(th) > 0.16 and 0.32 < th < math.tau - 0.32:
                if abs(z - L * 0.22) > L * 0.015:
                    return "glass"
            return "paint"
        # Utility / Naval / Heavy-lift windscreens & side windows
        if L * 0.29 < z < L * 0.455 and upper and 0.16 < th < math.tau - 0.16:
            # Central windscreen mullion bar
            if abs(math.sin(th)) < 0.09:
                return "paint"
            return "glass"
        # Lower chin observation windows on Blackhawk / Chinook / Bell
        if fam in ("blackhawk", "chinook", "bell412", "bell205", "littlebird", "md500d") and L * 0.34 < z < L * 0.45:
            if -0.65 < math.cos(th) < -0.15 and abs(math.sin(th)) > 0.38:
                return "glass"
        if fam not in ("mi8", "mi17", "mi26", "chinook"):
            side_w = abs(math.sin(th)) > 0.89 and 0.02 < math.cos(th) < 0.65
            win_zs = d.get("window_z", (-0.055, 0.045, 0.14, 0.22))
            if side_w and any(abs(z - q * L) < L * 0.028 for q in win_zs):
                return "glass"
        return "paint"

    cpow = float(d.get("cross_section_power", 0.86 if fam in ("nh90", "ch53", "blackhawk", "z20", "merlin") or is_ch53 else 1.0))
    chine_val = 0.18 if fam in ("nh90", "apache", "z10", "tiger", "t129", "lch") else 0.0
    fuse.loft_shell("paint", sections, seg=seg, subdiv=sub, cross_power=cpow, chine=chine_val, role_fn=role_window, ao_y=ao)

    # Round porthole windows on Mi-8/17/26 & Chinook
    if not lod and fam in ("mi8", "mi17", "mi26", "chinook"):
        n_port = 6 if fam == "chinook" else (8 if fam == "mi26" else 5)
        z0 = -L * 0.28 if fam == "chinook" else L * 0.06
        z1 = L * 0.28 if fam == "chinook" else L * 0.30
        prad = 0.22 if fam == "mi26" else 0.17
        for sgn in (-1, 1):
            for i in range(n_port):
                pz = z0 + (z1 - z0) * (i / max(1, n_port - 1))
                px = sgn * (W * 0.485)
                fuse.cyl("metal_dark", (px - sgn * 0.02, cy + 0.12, pz), prad + 0.035, sgn * 0.045, seg=14, axis="x")
                fuse.cyl("glass", (px + sgn * 0.015, cy + 0.12, pz), prad, sgn * 0.025, seg=14, axis="x")

    # Sliding cabin door rail & panel seam on utility/naval helis
    if not lod and not attack and fam not in ("s100", "vsr700", "littlebird", "md500d"):
        for sgn in (-1, 1):
            fuse.box("metal_dark", (sgn * W * 0.495, cy + H * 0.30, -L * 0.08),
                     (sgn * W * 0.518, cy + H * 0.34, L * 0.22), bevel=0.008)
            fuse.box("metal_dark", (sgn * W * 0.495, b + 0.08, -L * 0.06),
                     (sgn * W * 0.535, b + 0.13, L * 0.20), bevel=0.01)

    # Apache / Saraf cheek avionics EFABs + Saraf spine SATCOM pods
    if fam == "apache":
        for sgn in (-1, 1):
            fuse.loft_shell("paint", [
                (-L * 0.02, cy - 0.20, 0.08, 0.12),
                (L * 0.08, cy - 0.18, 0.24, 0.26),
                (L * 0.28, cy - 0.22, 0.22, 0.24),
                (L * 0.38, cy - 0.26, 0.06, 0.10),
            ], seg=8 if lod else 14, subdiv=1) if False else fuse.box(
                "paint", (sgn * W * 0.38, b + 0.22, L * 0.02), (sgn * W * 0.64, b + 0.72, L * 0.34), bevel=0.06, ao_y=ao
            )
        if is_saraf and not lod:
            fuse.dome("radome", (0.0, b + H + 0.04, -L * 0.16), 0.34, 0.24, seg=14, rings=3)
            for sgn in (-1, 1):
                fuse.box("paint", (sgn * W * 0.58, b + 0.36, L * 0.08), (sgn * W * 0.74, b + 0.62, L * 0.26), bevel=0.04)

    # ------------------------------------------------------------ 2. Tail Boom, Empennage & Sponsons
    ty = float(d.get("tail_y", s["hub_y"] - 0.35))
    tz = -L * 0.465
    if fam != "chinook":
        b_start = L * float(d.get("boom_start", -0.10))
        sy = cy + H * 0.22
        by = float(d.get("boom_y", ty))
        btz = tz + (float(s["tail_diameter"]) * 0.52 if d.get("fenestron") else 0.0)
        if d.get("fenestron"):
            by = ty - float(s["tail_diameter"]) * 0.32
        fuse.loft_shell("paint", [
            (btz, by, W * 0.068, H * 0.078),
            (-L * 0.33, 0.5 * (by + sy), W * 0.135, H * 0.155),
            (b_start, sy, W * 0.31, H * 0.29),
        ], seg=10 if lod else 22, subdiv=1 if lod else 2, ao_y=ao)

        # Tailboom UHF/HF strakes & chaff/flare dispensers
        if not lod and L > 10.0:
            for sgn in (-1, 1):
                fuse.box("metal_dark", (sgn * W * 0.13, 0.5 * (by + sy), -L * 0.29),
                         (sgn * (W * 0.13 + 0.06), 0.5 * (by + sy) + 0.16, -L * 0.23), bevel=0.01)

        if fam in ("ka27", "ka52"):
            # Twin endplate vertical fins on horizontal tailplane
            fuse.airfoil_wing("paint", [(0.04, by - 0.12, tz + 1.25, tz + 0.15), (W * 0.75, by - 0.12, tz + 1.05, tz + 0.22)],
                              chord_steps=5, span_steps=1)
            fuse.airfoil_wing("paint", [(0.04, by - 0.12, tz + 1.25, tz + 0.15), (W * 0.75, by - 0.12, tz + 1.05, tz + 0.22)],
                              chord_steps=5, span_steps=1, mirror_x=True)
            for sgn in (-1, 1):
                fuse.box("paint", (sgn * W * 0.72, by - 0.55, tz + 0.05),
                         (sgn * W * 0.80, by + 0.65, tz + 1.18), yaw=sgn * 0.06, bevel=0.02)
        elif not d.get("fenestron"):
            fin_h = max(0.72, float(s["tail_diameter"]) * 0.52)
            fy = by - 0.28
            cant_deg = float(s.get("tail_cant", 0.0))
            fuse.airfoil_wing("paint", [
                (0.0, 0.0, tz + 0.85, tz - 0.45),
                (fin_h + (ty - fy), 0.0, tz - 0.08, tz - 0.62),
            ], chord_steps=5, span_steps=1, thickness=0.10, vertical_cant_deg=-cant_deg) if False else None
            # Sculpted swept vertical fin + horizontal stabilator
            with fuse.frame((0.0, fy, 0.0), roll=math.radians(cant_deg)):
                fuse.prism_x("paint", [
                    (0.0, tz + 0.88), (0.04, tz - 0.46),
                    (ty - fy + fin_h * 0.88, tz - 0.62), (ty - fy + fin_h, tz - 0.10),
                ], -0.065, 0.065, bevel=0.02 if not lod else 0.0)
            if is_ch53:
                # Iconic CH-53 starboard gull-wing horizontal stabilizer high on tail pylon
                fuse.airfoil_wing("paint", [(0.06, ty + fin_h * 0.72, tz + 0.15, tz - 0.55),
                                            (W * 0.95, ty + fin_h * 0.80, tz - 0.05, tz - 0.60)], chord_steps=5, span_steps=1)
            else:
                stab_y = ty + fin_h * 0.78 if fam in ("apache",) and False else (by - 0.20 if fam not in ("blackhawk", "z20") else fy + 0.08)
                stab_span = W * (0.95 if fam in ("blackhawk", "z20") else 0.78)
                for m_x in (False, True):
                    fuse.airfoil_wing("paint", [(0.05, stab_y, tz + 0.55, tz - 0.12),
                                                (stab_span, stab_y, tz + 0.38, tz - 0.16)],
                                      chord_steps=5, span_steps=1, mirror_x=m_x)
    else:
        # Chinook raised aft rotor pylon
        ay = float(d.get("aft_hub_y", s["hub_y"] + 1.12))
        fuse.loft_shell("paint", [
            (-L * 0.48, cy + H * 0.35, W * 0.26, H * 0.34),
            (-L * 0.42, ay - 0.28, W * 0.21, H * 0.32),
            (-L * 0.30, ay - 0.30, W * 0.22, H * 0.34),
            (-L * 0.22, cy + H * 0.36, W * 0.32, H * 0.30),
        ], seg=10 if lod else 18, subdiv=1, ao_y=ao)

    # Fuel sponsons on Chinook, CH-53 Yasur/Pereh, Mi-8/17, Z-8, Merlin, NH90, S-92/H225
    if fam in ("chinook", "mi8", "mi17", "z8", "merlin", "nh90", "h225") or is_ch53:
        rr = float(d.get("fuel_sponson_radius", W * (0.24 if is_ch53 else 0.19)))
        for sgn in (-1, 1):
            z_lo = -L * 0.35 if fam == "chinook" else (-L * 0.14 if is_ch53 else -L * 0.16)
            z_hi = L * 0.32 if fam == "chinook" else (L * 0.16 if is_ch53 else L * 0.14)
            py = b + H * 0.20
            with fuse.frame((sgn * W * 0.50, 0.0, 0.0)):
                fuse.loft_shell("paint", [
                    (z_lo, py, rr * 0.45, H * 0.10),
                    (z_lo + L * 0.05, py, rr, H * 0.18),
                    (z_hi - L * 0.05, py, rr, H * 0.18),
                    (z_hi, py, rr * 0.45, H * 0.10),
                ], seg=8 if lod else 16, subdiv=1, ao_y=ao)
            if is_ch53:
                # CH-53 external drop tanks on sponson stub wings!
                tx = sgn * (W * 0.50 + rr + 0.62)
                fuse.box("paint", (sgn * W * 0.52, py + 0.08, -L * 0.04), (tx, py + 0.22, L * 0.08), bevel=0.02)
                with fuse.frame((tx, py - 0.08, L * 0.02)):
                    fuse.loft_shell("paint", [
                        (-2.1, 0, 0.10, 0.10), (-1.2, 0, 0.34, 0.34),
                        (1.2, 0, 0.34, 0.34), (2.2, 0, 0.08, 0.08),
                    ], seg=8 if lod else 14, subdiv=1)

    # Aerial refuelling probe on special-ops / heavy-lift variants (CH-53, MH-60M, HH-60W, MH-47G)
    if not lod and (is_ch53 or any(k in slug for k in ("mh_60", "hh_60", "mh_47", "h_47er", "yasur", "pereh", "jolly_green"))):
        px = W * 0.42
        py = b + H * 0.28
        fuse.pipe("metal_dark", (px, py, L * 0.32), (px + 0.12, py - 0.04, L * 0.60), 0.055, seg=8)
        fuse.pipe("metal", (px + 0.12, py - 0.04, L * 0.60), (px + 0.13, py - 0.04, L * 0.64), 0.075, seg=8, r2=0.04)

    # National markings roundel / tactical flash on cabin sides
    mz = L * float(d.get("mark_z", 0.14))
    for sgn in (-1, 1):
        fuse.box("markings", (sgn * (W * 0.502), cy - H * 0.09, mz - L * 0.025),
                 (sgn * (W * 0.522), cy + H * 0.09, mz + L * 0.025))

    # Nose FLIR / TADS electro-optical turret on nose/chin
    if not lod and fam != "s100":
        flir_z = L * (0.495 if fam == "apache" else 0.455)
        flir_y = cy - H * 0.22 if fam == "apache" else b + 0.18
        if attack or naval or d.get("chin_sensor") or is_ch53 or fam in ("blackhawk", "nh90", "merlin", "z20"):
            flir_r = 0.23 if fam == "apache" else 0.18
            fuse.dome("metal_dark", (0.0, flir_y - flir_r * 0.5, flir_z), flir_r, flir_r * 1.1, seg=12, rings=3)
            fuse.cyl("glass", (0.0, flir_y, flir_z + flir_r * 0.65), flir_r * 0.62, 0.06, seg=12, axis="z")

    rig.add("Fuselage", rig.root_name, (0.0, 0.0, 0.0), fuse)

    # ------------------------------------------------------------ 3. Turboshaft Engine Nacelles & Exhausts
    eng_part = bc.CraftPart("Engines", seed=(hash(slug) + 3) & 0xFFFF)
    n_eng = int(s.get("engines", 2))
    if is_ch53 and "ch_53k" in slug:
        n_eng = 3
    for i in range(n_eng):
        ex = (i - (n_eng - 1) * 0.5) * W * 0.46
        ez = -L * 0.34 if fam == "chinook" else L * 0.04
        ey = cy + H * 0.48 if fam != "chinook" else float(s["hub_y"]) + 0.18
        el = L * 0.17
        er = W * 0.19
        if (attack and n_eng == 2 and fam != "mi24") or fam == "seasprite":
            ex = (i - 0.5) * W * 1.16
            ey = cy + H * 0.34
            er = W * 0.22
            el = L * 0.155
        elif fam == "chinook":
            ex = (i - 0.5) * W * 0.92
            ey = float(d.get("aft_hub_y", s["hub_y"] + 1.12)) - 1.08
        elif n_eng == 3:
            ex = (-W * 0.32, W * 0.32, 0.0)[i]
            ez = L * (0.05 if i < 2 else -0.11)
            er = W * 0.17
        with eng_part.frame((ex, 0.0, 0.0)):
            eng_part.loft_shell("paint", [
                (ez - el * 0.54, ey, er * 0.58, er * 0.62),
                (ez - el * 0.32, ey, er, er * 0.96),
                (ez + el * 0.36, ey, er, er * 0.96),
                (ez + el * 0.54, ey, er * 0.72, er * 0.72),
            ], seg=8 if lod else 16, subdiv=1, ao_y=ao)
        # Intake dust separator / compressor screen & upturned IR-suppressed exhaust
        eng_part.cyl("metal_dark", (ex, ey, ez + el * 0.50), er * 0.66, 0.08, seg=8 if lod else 14, axis="z")
        eng_part.pipe("metal_dark", (ex, ey, ez - el * 0.50), (ex + (0.08 if ex > 0 else (-0.08 if ex < 0 else 0.0)), ey + er * 0.32, ez - el * 0.68), er * 0.42, seg=8 if lod else 12)
    rig.add("Engines", "Fuselage", (0.0, cy + H * 0.45, 0.0), eng_part)

    # ------------------------------------------------------------ 4. Articulated Main & Tail Rotors
    hub_y = float(s["hub_y"])
    hub_z = float(s["hub_z"])
    rot_r = float(s["rotor_diameter"]) * 0.5
    n_blades = int(s["blades"])
    b_chord = d.get("main_blade_chord")

    # Mast fairing
    mast_p = bc.CraftPart("Rotor_Mast", seed=7)
    mast_p.cyl("metal_dark", (0.0, hub_y - 0.60, hub_z), max(0.10, W * 0.055), 0.52, seg=8 if lod else 14)
    if d.get("mast_radar") or (fam == "mi28" and not lod):
        # Longbow / Arbalet mast-mounted fire-control radar dome
        mast_p.cyl("metal_dark", (0.0, hub_y + 0.14, hub_z), 0.10, 0.28, seg=8 if lod else 12)
        mast_p.loft_shell("radome", [
            (hub_z - 0.52, hub_y + 0.54, 0.12, 0.06),
            (hub_z - 0.32, hub_y + 0.54, 0.48, 0.16),
            (hub_z, hub_y + 0.54, 0.56, 0.20),
            (hub_z + 0.32, hub_y + 0.54, 0.48, 0.16),
            (hub_z + 0.52, hub_y + 0.54, 0.12, 0.06),
        ], seg=10 if lod else 18, subdiv=1)
    rig.add("Rotor_Mast", "Fuselage", (0.0, hub_y - 0.55, hub_z), mast_p)

    # Primary Rotor_Main (pivots at exact hub so Godot rotate_y spins cleanly!)
    rm1 = bc.CraftPart("Rotor_Main", seed=11)
    with rm1.frame((0.0, hub_y, hub_z)):
        rm1.rotor_hub_and_blades(rot_r, n_blades, lod=lod, chord=b_chord, phase=0.0)
    rig.add("Rotor_Main", "Fuselage", (0.0, hub_y, hub_z), rm1)

    # Secondary Rotor_Main_2 for Chinook tandem OR Kamov Ka-27/Ka-52 coaxial!
    if fam == "chinook":
        ay = float(d.get("aft_hub_y", hub_y + 1.12))
        az = float(d.get("aft_hub_z", -L * 0.36))
        rm2 = bc.CraftPart("Rotor_Main_2", seed=12)
        with rm2.frame((0.0, ay, az)):
            rm2.rotor_hub_and_blades(rot_r, n_blades, lod=lod, chord=b_chord, phase=math.pi / n_blades)
        rig.add("Rotor_Main_2", "Fuselage", (0.0, ay, az), rm2)
    elif fam in ("ka27", "ka52"):
        uy = hub_y + 0.76
        rm2 = bc.CraftPart("Rotor_Main_2", seed=12)
        rm2.cyl("metal_dark", (0.0, hub_y + 0.08, hub_z), max(0.08, W * 0.04), 0.68, seg=8 if lod else 12)
        with rm2.frame((0.0, uy, hub_z)):
            rm2.rotor_hub_and_blades(rot_r, n_blades, lod=lod, chord=b_chord, phase=math.pi / n_blades)
        rig.add("Rotor_Main_2", "Fuselage", (0.0, uy, hub_z), rm2)

    # Tail Rotor or Shrouded Fenestron
    t_blades = int(s.get("tail_blades", 0))
    if t_blades > 0 and fam not in ("chinook", "ka27", "ka52"):
        t_rad = float(s["tail_diameter"]) * 0.5
        ducted = bool(d.get("fenestron", False))
        t_side = int(s.get("tail_side", 1))
        tx = 0.0 if ducted else t_side * (W * 0.13 + 0.08)
        rt = bc.CraftPart("Rotor_Tail", seed=13)
        with rt.frame((tx, ty, tz), roll=-math.pi * 0.5):
            rt.rotor_hub_and_blades(t_rad * (0.94 if ducted else 1.0), t_blades, lod=lod,
                                    chord=max(0.07, t_rad * 0.11), root_frac=0.22 if ducted else 0.14, yellow_tips=not ducted)
        rig.add("Rotor_Tail", "Fuselage", (tx, ty, tz), rt)
        if ducted:
            fen = bc.CraftPart("Fenestron", seed=14)
            fen.tube_axis("paint", (-0.12, ty, tz), (0.12, ty, tz), t_rad * 1.26, t_rad * 1.02, seg=12 if lod else 26)
            fen.prism_x("paint", [(ty + t_rad * 1.18, tz + 0.45), (ty + t_rad * 1.18, tz - 0.35),
                                  (ty + t_rad * 2.05, tz - 0.52), (ty + t_rad * 2.05, tz - 0.08)], -0.07, 0.07, bevel=0.02 if not lod else 0.0)
            rig.add("Fenestron", "Fuselage", (0.0, ty, tz), fen)

    # ------------------------------------------------------------ 5. Landing Gear (Skid / Tailwheel / Tricycle / Quad)
    gear_p = bc.CraftPart("Landing_Gear", seed=15)
    gear_type = s.get("gear", "tricycle")
    if gear_type in ("skid", "tripod"):
        sx = W * (0.76 if fam == "s100" else 0.64)
        for sgn in (-1, 1):
            for gz in (-L * 0.04 if fam == "s100" else L * 0.02, L * 0.23):
                gear_p.pipe("metal_dark", (sgn * W * 0.34, b + 0.16, gz), (sgn * sx, 0.08, gz), 0.045 if L < 8 else 0.065, seg=6 if lod else 10)
            gear_p.pipe("metal_dark", (sgn * sx, 0.055, -L * 0.14), (sgn * sx, 0.055, L * 0.29), 0.048 if L < 8 else 0.068, seg=6 if lod else 10)
            gear_p.pipe("metal_dark", (sgn * sx, 0.055, L * 0.29), (sgn * sx, 0.24, L * 0.35), 0.045 if L < 8 else 0.062, seg=6 if lod else 8)
    else:
        wr = float(d.get("wheel_radius", 0.27 if L < 18 else 0.39))
        if fam == "mi26":
            wr = 0.62
        if gear_type == "tailwheel":
            tz_g = min(float(d.get("tail_gear_z", -0.41)), -0.39)
            pts = [("L", -W * 0.66, wr, L * 0.13), ("R", W * 0.66, wr, L * 0.13), ("T", 0.0, wr * 0.66, L * tz_g)]
        elif gear_type == "four":
            sp = float(d.get("gear_spread", 0.56))
            pts = [("FL", -W * sp, wr, L * 0.28), ("FR", W * sp, wr, L * 0.28),
                   ("RL", -W * sp, wr, -L * 0.30), ("RR", W * sp, wr, -L * 0.30)]
        else:
            mz = L * float(d.get("main_gear_z", -0.08))
            sp = float(d.get("gear_spread", 0.64))
            pts = [("L", -W * sp, wr, mz), ("R", W * sp, wr, mz), ("N", 0.0, wr * 0.78, L * 0.36)]
        for lbl, gx, gr, gz in pts:
            ay = (by - 0.08) if lbl == "T" else (b + H * 0.20)
            ax0 = gx * 0.62
            gear_p.pipe("metal_dark", (ax0, ay, gz + (0.12 if lbl != "T" else 0.18)), (gx, gr, gz), max(0.045, gr * 0.20), seg=6 if lod else 10)
            gear_p.wheel_aircraft((gx, gr, gz), gr, lod=lod, dual=(L >= 19.0 and lbl != "T"))
    rig.add("Landing_Gear", "Fuselage", (0.0, b * 0.5, 0.0), gear_p)

    # ------------------------------------------------------------ 6. Gunship / Naval / AEW Armament & Mission Sensors
    if attack and "wing_span" in d:
        wspan = float(d["wing_span"])
        wy = b + H * 0.40
        drop = -0.22 if fam == "mi24" else -0.04
        st_part = bc.CraftPart("Stub_Wings_Stores", seed=17)
        stations = int(d.get("stations_per_wing", 2))
        for sgn in (-1, 1):
            st_part.airfoil_wing("paint", [
                (W * 0.36, wy, L * 0.16, L * 0.02),
                (wspan * 0.5, wy + drop, L * 0.11, L * 0.01),
            ], chord_steps=5, span_steps=1, thickness=0.12, mirror_x=(sgn < 0))
            # Wingtip countermeasures / AAM rails on Apache/Tiger/Z-10/Ka-52
            if not lod:
                st_part.cyl("paint", (sgn * wspan * 0.51, wy + drop, L * 0.00), 0.075, 0.95, seg=8, axis="z")
            for j in range(stations):
                f = (j + 1) / (stations + 0.18)
                px = sgn * (W * 0.52 + (wspan * 0.5 - W * 0.52) * f)
                py = wy + drop * f - 0.28
                pz = L * 0.07
                st_part.box("paint", (px - 0.05, py + 0.04, pz - 0.28), (px + 0.05, wy + drop * f, pz + 0.24), bevel=0.01)
                if j == 0 and not d.get("scout_aam"):
                    # 19-tube Hydra-70 / B-8V20 rocket pod
                    st_part.cyl("paint", (px, py, pz - 0.65), 0.23, 1.38, seg=8 if lod else 16, axis="z")
                    st_part.cyl("metal_dark", (px, py, pz + 0.72), 0.22, 0.05, seg=8 if lod else 16, r2=0.18, axis="z")
                else:
                    # Quad Hellfire / Spike / Vikhr ATGM rack + missiles
                    n_m = int(d.get("missiles_per_bank", 4))
                    mlen = 1.65
                    st_part.box("metal_dark", (px - 0.20, py - 0.04, pz - 0.30), (px + 0.20, py + 0.06, pz + 0.30))
                    for m_i in range(min(n_m, 4 if not lod else 2)):
                        dx = (-0.12 if m_i % 2 == 0 else 0.12)
                        dy = (-0.11 if m_i < 2 else 0.09)
                        st_part.cyl("paint", (px + dx, py + dy, pz - mlen * 0.45), 0.078, mlen, seg=6 if lod else 10, axis="z")
                        st_part.cyl("radome", (px + dx, py + dy, pz + mlen * 0.55), 0.078, 0.10, seg=6 if lod else 10, r2=0.02, axis="z")
        rig.add("Stub_Wings_Stores", "Fuselage", (0.0, wy, L * 0.08), st_part)

        # Articulated Chin Gun Turret (or fixed side autocannon on Ka-52 / Mi-35P)
        if d.get("gun", True):
            fixed = bool(d.get("fixed_gun", False))
            g_side = float(d.get("gun_side", 0.0))
            if not fixed:
                tp = (g_side * W * 0.45, max(0.32, b - 0.04), L * 0.34)
                tur = bc.CraftPart("Turret", seed=19)
                tur.cyl("metal_dark", (tp[0], tp[1] - 0.14, tp[2]), 0.22, 0.26, seg=8 if lod else 14)
                tur.box("paint", (tp[0] - 0.16, tp[1] - 0.18, tp[2] - 0.22), (tp[0] + 0.16, tp[1] + 0.04, tp[2] + 0.24), bevel=0.03)
                rig.add("Turret", "Fuselage", tp, tur)

                gp = (tp[0], tp[1] - 0.11, tp[2] + 0.18)
                gun = bc.CraftPart("Gun", seed=20)
                glen = 1.28
                n_bar = int(d.get("gun_barrels", 1))
                if n_bar > 1:
                    for bi in range(n_bar):
                        ba = math.tau * bi / n_bar
                        gun.pipe("metal_dark", (gp[0] + 0.04 * math.cos(ba), gp[1] + 0.04 * math.sin(ba), gp[2]),
                                 (gp[0] + 0.04 * math.cos(ba), gp[1] + 0.04 * math.sin(ba), gp[2] + glen), 0.024, seg=6)
                    gun.cyl("metal_dark", (gp[0], gp[1], gp[2] + glen * 0.72), 0.068, 0.08, seg=8, axis="z")
                else:
                    gun.tube_axis("metal_dark", gp, (gp[0], gp[1], gp[2] + glen), 0.042, 0.022, seg=8 if lod else 12)
                    gun.cyl("metal_dark", (gp[0], gp[1], gp[2] + glen - 0.14), 0.062, 0.14, seg=8, axis="z")
                rig.add("Gun", "Turret", gp, gun)
                rig.add("Muzzle", "Gun", (gp[0], gp[1], gp[2] + glen), None)
            else:
                fp = (W * 0.54, b + H * 0.36, L * 0.14)
                fgun = bc.CraftPart("Gun", seed=20)
                fgun.box("paint", (fp[0] - 0.14, fp[1] - 0.16, fp[2] - 0.45), (fp[0] + 0.14, fp[1] + 0.16, fp[2] + 0.40), bevel=0.03)
                fgun.tube_axis("metal_dark", (fp[0], fp[1], fp[2] + 0.35), (fp[0], fp[1], fp[2] + 2.05), 0.046, 0.024, seg=8 if lod else 12)
                rig.add("Gun", "Fuselage", fp, fgun)
                rig.add("Muzzle", "Gun", (fp[0], fp[1], fp[2] + 2.05), None)

    if naval:
        nav_p = bc.CraftPart("Naval_Mission_Kit", seed=21)
        # Starboard rescue hoist
        hx, hy, hz = W * 0.48, b + H * 0.84, L * 0.04
        nav_p.pipe("paint", (hx, hy, hz), (hx + 0.32, hy, hz + 0.14), 0.055, seg=6)
        nav_p.cyl("metal_dark", (hx + 0.32, hy - 0.08, hz + 0.14), 0.09, 0.16, seg=8)
        # Lightweight ASW torpedoes / anti-ship missiles on stub pylons
        store = d.get("naval_store", "torpedo")
        if store not in ("none", "internal"):
            tlen = 2.75 if store == "torpedo" else 2.45
            trad = 0.162 if store == "torpedo" else 0.13
            for sgn in (-1, 1):
                sx, sy, sz = sgn * (W * 0.66), b + H * 0.24, L * 0.10
                nav_p.pipe("paint", (sgn * W * 0.46, sy + 0.22, sz), (sx, sy, sz), 0.075, seg=6)
                nav_p.cyl("metal_dark", (sx, sy, sz - tlen * 0.45), trad, tlen * 0.88, seg=8 if lod else 14, axis="z")
                nav_p.cyl("markings", (sx, sy, sz + tlen * 0.43), trad, tlen * 0.12, seg=8 if lod else 14, r2=trad * 0.35, axis="z")
        rig.add("Naval_Mission_Kit", "Fuselage", (0.0, b + H * 0.3, L * 0.10), nav_p)

        if d.get("naval_radar", True):
            rad_p = bc.CraftPart("Radar", seed=22)
            rz = L * 0.26
            rr = W * 0.28
            rad_p.cyl("radome", (0.0, b - 0.14, rz), rr, 0.22, seg=10 if lod else 22, r2=rr * 0.86)
            rig.add("Radar", "Fuselage", (0.0, b - 0.04, rz), rad_p)

    if is_crowsnest:
        # Merlin HM2 Crowsnest port-side deployed AEW radar dome (rotates via `Radar` node!)
        cn = bc.CraftPart("Radar", seed=23)
        cx, cy_cn, cz = -W * 0.72, b + 0.18, L * 0.06
        cn.pipe("metal_dark", (-W * 0.46, cy + 0.05, cz), (cx, cy_cn + 0.35, cz), 0.08, seg=8)
        cn.dome("radome", (cx, cy_cn + 0.35, cz), 0.92, -0.78, seg=12 if lod else 22, rings=4)
        cn.dome("radome", (cx, cy_cn + 0.35, cz), 0.92, 0.32, seg=12 if lod else 22, rings=3)
        rig.add("Radar", "Fuselage", (cx, cy_cn, cz), cn)

    return rig


def build_one(spec):
    slug = spec["slug"]
    out_path = os.path.join(OUT_DIR, f"{slug}.glb")
    lod0 = _build_heli_lod(spec, lod=0)
    lod1 = _build_heli_lod(spec, lod=1)
    bc.export_craft(out_path, lod0, lod1, wreck_roll=14.0)


def main():
    bv.init_scene()
    specs = bc.load_specs()["P5"]
    only = [a for a in sys.argv[sys.argv.index("--") + 1:] if not a.startswith("-")] if "--" in sys.argv else []
    keys = [k for k in sorted(specs) if not only or any(o in k for o in only)]
    print(f"Building {len(keys)} P5 rotorcraft models in Blender 5.2 LTS...")
    for idx, k in enumerate(keys, 1):
        build_one(specs[k])
    print(f"P5 COMPLETE: {len(keys)} / {len(specs)} rotorcraft exported to {OUT_DIR}")


if __name__ == "__main__":
    main()
