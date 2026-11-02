"""Parts shared by the Blender-made buildings: louvre panels, lattice masts, fans, trucks, fences, hazard stripes."""
import math
from bl_kit import hexc

METAL, DARK = "metal", "steel_dark"


def slats(m, x0, x1, y0, y1, z, step=0.13, tint=(1, 1, 1)):
    """A louvre panel on a wall facing +z at z: a dark recess with angled slats in a frame."""
    m.box(DARK, (x0 - 0.05, y0 - 0.05, z - 0.02), (x1 + 0.05, y1 + 0.05, z + 0.06), bevel=0.02, seg=1)
    m.box("dark", (x0, y0, z + 0.05), (x1, y1, z + 0.07))
    for i in range(int((y1 - y0) / step)):
        y = y0 + 0.03 + i * step
        m.hull(METAL, [(x0 + 0.02, y, z + 0.07), (x1 - 0.02, y, z + 0.07), (x0 + 0.02, y + 0.03, z + 0.07), (x1 - 0.02, y + 0.03, z + 0.07),
                       (x0 + 0.02, y + 0.07, z + 0.2), (x1 - 0.02, y + 0.07, z + 0.2), (x0 + 0.02, y + 0.1, z + 0.2), (x1 - 0.02, y + 0.1, z + 0.2)], tint)


def lattice(m, x, z, h, w=0.9, y0=0.17, leg=0.035):
    """A four-legged lattice mast with diagonal bracing."""
    legs = [(x - w / 2, z - w / 2), (x + w / 2, z - w / 2), (x - w / 2, z + w / 2), (x + w / 2, z + w / 2)]
    for lx, lz in legs:
        m.pipe(DARK, (lx, y0, lz), (lx, y0 + h, lz), leg, 5)
    n = max(1, int(h / 0.9))
    for i in range(n):
        a, b = y0 + i * h / n, y0 + (i + 1) * h / n
        for (ax, az), (bx, bz) in ((legs[0], legs[1]), (legs[1], legs[3]), (legs[3], legs[2]), (legs[2], legs[0])):
            m.pipe(DARK, (ax, a, az), (bx, b, bz), leg * 0.45, 4)


def hazard_ring(m, c, r0, r1, y0, y1, n=24):
    """A ring of alternating yellow and black wedges (a painted kerb or door rim)."""
    for k in range(n):
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        pts = []
        for a in (a0, a1):
            for r in (r0, r1):
                for y in (y0, y1):
                    pts.append((c[0] + math.cos(a) * r, c[1] + y, c[2] + math.sin(a) * r))
        m.hull("hazard" if k % 2 == 0 else "dark", pts)


def fence(m, x0, x1, z0, z1, gap=None, post=1.4, h=1.7):
    """A security fence round a rectangle: posts leaning out at the top, three wires, and a strand of razor wire on top."""
    def line(ax, az, bx, bz, out):
        length = math.hypot(bx - ax, bz - az)
        n = max(1, int(length / post))
        for i in range(n + 1):
            t = i / n
            px, pz = ax + (bx - ax) * t, az + (bz - az) * t
            if gap and gap[0] < px < gap[1] and abs(pz - gap[2]) < 0.2:
                continue
            m.pipe(METAL, (px, 0.1, pz), (px, h, pz), 0.03, 5)
            m.pipe(METAL, (px, h, pz), (px + out[0] * 0.3, h + 0.28, pz + out[1] * 0.3), 0.022, 4)
        for y in (0.5, 1.0, h):
            if gap and abs(az - gap[2]) < 0.2 and abs(bz - gap[2]) < 0.2:
                m.wire(METAL, [(ax, y, az), (gap[0], y, az)], 0.01, 4)
                m.wire(METAL, [(gap[1], y, az), (bx, y, az)], 0.01, 4)
            else:
                m.wire(METAL, [(ax, y, az), (bx, y, bz)], 0.01, 4)
    line(x0, z0, x1, z0, (0, -1))
    line(x0, z1, x1, z1, (0, 1))
    line(x0, z0, x0, z1, (-1, 0))
    line(x1, z0, x1, z1, (1, 0))


def fan(m, c, r):
    """A fan under a housing ring: grille bars, a hub and five blades."""
    x, y, z = c
    m.tube(DARK, (x, y, z), r + 0.1, r, 0.16, 24)
    m.cyl("dark", (x, y - 0.02, z), r, 0.02, 24)
    for k in range(5):
        a = math.tau * k / 5.0
        ca, sa = math.cos(a), math.sin(a)
        pa, pb = (-sa, ca), (ca, sa)
        pts = []
        for rr, w, dy in ((0.12, 0.05, 0.0), (r * 0.92, 0.13, 0.04)):
            for sgn in (-1, 1):
                for h in (0.0, 0.018):
                    pts.append((x + ca * rr + pa[0] * w * sgn, y + 0.05 + dy + h, z + sa * rr + pa[1] * w * sgn))
        m.hull(METAL, pts)
    m.cyl(DARK, (x, y + 0.02, z), 0.14, 0.12, 10)


def dish(m, c, r, yaw, tilt):
    """A parabolic dish on a pedestal: a true concave bowl (a lathe), a dark rim, a feed horn on three struts."""
    x, y, z = c
    m.pipe(METAL, (x, y, z), (x, y + 1.0, z), 0.14, 10)
    m.box(DARK, (x - 0.3, y, z - 0.3), (x + 0.3, y + 0.15, z + 0.3), bevel=0.03, seg=1)
    with m.frame((x, y + 1.0, z), yaw=yaw, pitch=-tilt):
        m.cyl(METAL, (0, 0, 0), 0.22, 0.3, 10)
        k = 0.5 * r * 0.55 / (r * r)
        prof = [(0.0, 0.3)]
        n = 8
        for i in range(1, n + 1):
            rr = r * i / n
            prof.append((rr, 0.3 + k * rr * rr * 1.6))
        prof.append((r, 0.3 + k * r * r * 1.6 + 0.05))
        for i in range(n - 1, -1, -1):
            rr = r * i / n
            prof.append((rr, 0.35 + k * rr * rr * 1.6))
        prof.append((0.0, 0.35))
        m.lathe("paint", (0, 0, 0), prof, 24)
        m.tube("dark", (0, 0.3 + k * r * r * 1.6, 0), r, r - 0.05, 0.06, 24)
        top = 0.3 + r * 0.9
        for q in range(3):
            a = math.tau * q / 3 + 0.5
            m.pipe(METAL, (math.cos(a) * r * 0.9, 0.3 + k * r * r * 1.6, math.sin(a) * r * 0.9), (0, top, 0), 0.02, 4)
        m.cyl(METAL, (0, top - 0.05, 0), 0.07, 0.18, 8)


def radome(m, c, r):
    """A radome: a drum, a lit seam and a white sphere cap."""
    x, y, z = c
    m.cyl("paint", (x, y, z), r * 0.92, 0.45, 20, tint=hexc("dfe4e6"))
    m.cyl("glow_cyan", (x, y + 0.45, z), r * 0.94, 0.05, 20)
    m.geodome("paint", (x, y + 0.5, z), r, r * 0.95, 2, tint=(1.0, 1.0, 1.02), jitter=0.07)
    m.tube("dark", (x, y + 0.5, z), r * 1.0, r * 0.97, 0.04, 20)


def container(m, x, z, yaw, tint, length=2.6, width=1.25, height=1.8, y0=0.1):
    """A shipping-container shelter: corrugated sides, corner posts, a door end with locking bars."""
    with m.frame((x, 0, z), yaw=yaw):
        hl, hw = length / 2, width / 2
        m.box("paint", (-hl, y0, -hw), (hl, y0 + height, hw), bevel=0.03, seg=1, tint=tint)
        for sgn in (-1, 1):
            for k in range(int(length / 0.22)):
                xx = -hl + 0.15 + k * 0.22
                m.box("paint", (xx - 0.04, y0 + 0.1, sgn * hw), (xx + 0.04, y0 + height - 0.1, sgn * hw + sgn * 0.035), tint=tuple(t * 0.85 for t in tint))
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.box(DARK, (sx * hl - 0.05, y0, sz * hw - 0.05), (sx * hl + 0.05, y0 + height, sz * hw + 0.05))
        for q in (-0.35, 0.35):
            m.pipe(METAL, (hl + 0.03, y0 + 0.15, q), (hl + 0.03, y0 + height - 0.15, q), 0.02, 5)
        m.box(DARK, (-hl, y0 + height, -hw), (hl, y0 + 0.05 + height, hw))


def truck(m, x, z, yaw=0.0, canvas=True, bed=5.1, body=None):
    """A military support truck: ladder chassis, cab, canvas bed on arches, six wheels."""
    olive = body or hexc("55633f")
    with m.frame((x, 0, z), yaw=yaw):
        rear = 2.2 - bed
        m.box("dark", (-1.0, 0.45, rear), (1.0, 0.8, 2.2), bevel=0.04, seg=1)
        m.box("paint", (-1.05, 0.8, 2.2), (1.05, 2.0, 3.4), bevel=0.1, seg=2, tint=olive)
        m.box("glass", (-0.95, 1.3, 3.38), (0.95, 1.85, 3.44), bevel=0.04, seg=1)
        m.box("dark", (-1.1, 0.5, 3.4), (1.1, 0.85, 3.6), bevel=0.04, seg=1)
        m.box("paint", (-1.05, 0.8, rear), (1.05, 1.1, 2.1), bevel=0.03, seg=1, tint=olive)
        if canvas:
            for k in range(max(2, int(bed / 1.2))):
                zz = rear + 0.3 + k * 1.2
                m.pipe("paint", (-0.95, 1.1, zz), (-0.95, 2.0, zz), 0.03, 5, tint=olive)
                m.pipe("paint", (0.95, 1.1, zz), (0.95, 2.0, zz), 0.03, 5, tint=olive)
                m.pipe("paint", (-0.95, 2.0, zz), (0.95, 2.0, zz), 0.03, 5, tint=olive)
            m.box("paint", (-0.99, 1.1, rear), (0.99, 2.05, 2.1), bevel=0.2, seg=3, tint=hexc("4c5a38"))
        for az in ((rear + 0.6, 2.8) if bed < 3.5 else (rear + 0.6, rear + 2.1, 2.8)):
            for sx in (-1, 1):
                m.pipe("dark", (x * 0 + sx * 0.78, 0.45, az), (sx * 1.1, 0.45, az), 0.45, 14)
        m.box("glow_warm", (-0.9, 0.55, 3.6), (-0.6, 0.7, 3.64))
        m.box("glow_warm", (0.6, 0.55, 3.6), (0.9, 0.7, 3.64))


def watch_tower(m, x, z, h):
    """A watch tower: a lattice, a glass cab under a deep roof, a searchlight and a ladder."""
    lattice(m, x, z, h, 1.1, 0.1, 0.04)
    m.box("cladding", (x - 0.9, 0.1 + h, z - 0.9), (x + 0.9, 0.1 + h + 1.3, z + 0.9), bevel=0.04, seg=1)
    m.box("glass", (x - 0.85, h + 0.4, z + 0.88), (x + 0.85, h + 1.2, z + 0.94))
    m.box("glass", (x + 0.88, h + 0.4, z - 0.85), (x + 0.94, h + 1.2, z + 0.85))
    m.box("wall_concrete", (x - 1.2, h + 1.4, z - 1.2), (x + 1.2, h + 1.55, z + 1.2), bevel=0.03, seg=1)
    m.box("glow_warm", (x - 0.2, h + 1.25, z + 1.2), (x + 0.2, h + 1.38, z + 1.4))
    m.pipe(METAL, (x, h + 1.55, z), (x, h + 2.4, z), 0.03, 5)
    for k in range(int(h / 0.9)):
        m.pipe(METAL, (x + 0.35, 0.3 + k * 0.9, z + 0.55), (x + 0.35, 0.3 + k * 0.9, z + 0.95), 0.015, 4)


def trefoil(m, c, r):
    """A radiation sign on a wall facing +z: a yellow disc, three dark blades, a dark hub."""
    with m.frame(c, pitch=math.pi / 2):
        m.cyl("hazard", (0, 0, 0), r, 0.03, 24)
        for k in range(3):
            a = math.tau * k / 3.0 + math.pi / 6
            pts = []
            for da in (-math.pi / 6, math.pi / 6):
                for rr in (r * 0.22, r * 0.85):
                    for yy in (0.03, 0.045):
                        pts.append((math.cos(a + da) * rr, yy, math.sin(a + da) * rr))
            m.hull("dark", pts)
        m.cyl("dark", (0, 0.03, 0), r * 0.13, 0.02, 10)


def vent_stack(m, x, z, h, r):
    """A tall concrete stack, red and white bands, a beacon, a ladder cage."""
    rings = 8
    for i in range(rings):
        f0, f1 = i / rings, (i + 1) / rings
        r0, r1 = r * (1 - 0.3 * f0), r * (1 - 0.3 * f1)
        red = i % 2 == 1 and i > 2
        m.cyl("paint" if red else "wall_concrete", (x, 0.1 + f0 * h, z), r0, h / rings, 16, r2=r1, tint=hexc("c0392b") if red else (1.1, 1.1, 1.12))
    m.tube("dark", (x, 0.1 + h, z), r * 0.74, r * 0.62, 0.12, 16)
    m.cyl("glow_red", (x, 0.1 + h + 0.12, z), 0.12, 0.2, 8)
    for y in (h * 0.2, h * 0.45, h * 0.7):
        m.tube(METAL, (x, y, z), r * 0.95, r * 0.92, 0.05, 16)
    m.pipe(METAL, (x + r * 0.9, 0.3, z), (x + r * 0.9, h * 0.9, z), 0.02, 4)


def fence_poly(m, R, gate=None, hazard_every=5, h=1.7, post=1.4):
    """A security fence round the hex at radius R: leaning posts, three wires and a razor strand on top; gate=(x0, x1) leaves the front open."""
    pts = [(math.cos(math.radians(30 + 60 * k)) * R, math.sin(math.radians(30 + 60 * k)) * R) for k in range(7)]
    idx = 0
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        length = math.hypot(bx - ax, bz - az)
        n = max(1, int(length / post))
        ox, oz = ((ax + bx) / 2, (az + bz) / 2)
        nl = math.hypot(ox, oz)
        ox, oz = ox / nl, oz / nl
        run = []
        for i in range(n + 1):
            t = i / n
            px, pz = ax + (bx - ax) * t, az + (bz - az) * t
            if gate and pz > 5.0 and gate[0] < px < gate[1]:
                if len(run) > 1:
                    for y in (0.5, 1.0, h):
                        m.wire(METAL, [(q[0], y, q[1]) for q in run], 0.01, 4)
                run = []
                continue
            m.pipe(METAL, (px, 0.1, pz), (px, h, pz), 0.03, 5)
            m.pipe(METAL, (px, h, pz), (px + ox * 0.3, h + 0.28, pz + oz * 0.3), 0.022, 4)
            run.append((px, pz))
            idx += 1
            if hazard_every and idx % hazard_every == 0:
                m.box("hazard", (px - 0.3, 1.0, pz - 0.02), (px + 0.3, 1.5, pz + 0.02))
        if len(run) > 1:
            for y in (0.5, 1.0, h):
                m.wire(METAL, [(q[0], y, q[1]) for q in run], 0.01, 4)


CONC, CLAD, GLASS = "wall_concrete", "cladding", "glass"
GREEN = hexc("5a8a46")
OLIVE = hexc("5d6a4a")


def noise(x, z):
    return (math.sin(x * 1.9) * math.cos(z * 2.4) + math.sin(x * 3.7 + z * 3.3) * 0.5) / 1.5


def magazine(m, cx, number, hw=2.3, hl=2.8, front=-2.4):
    """An igloo: an earth mound over a barrel vault with a concrete headwall and a blast door facing +z."""
    h0, rise = 1.2, hw * 0.85
    top = h0 + rise + 0.45
    wide = hw + 0.7
    zb = front - hl * 2.0

    def mound(x, z):
        u = (x - cx) / wide
        if abs(u) >= 1.0 or z > front - 0.25 or z < zb:
            return -0.03
        t = (z - zb) / (front - 0.25 - zb)                          # 0 at the back, 1 at the headwall
        back = min(1.0, t / 0.3) ** 0.6
        prof = (1.0 - u * u) ** 0.55 * (top - 0.3) + 0.3
        return prof * back * (1.0 + 0.04 * noise(x, z)) + 0.07 * noise(x * 2, z * 2) * back
    m.grid("turf", cx - wide, cx + wide, zb, front - 0.25, mound, 22, 22, base=0.1, tint=GREEN)
    # the headwall: a concrete face with an arched recess cut into it, wing walls running into the mound
    dw = hw - 0.55
    arch = []
    for k in range(9):
        a = math.pi * k / 8
        arch.append((cx + math.cos(a) * dw, 1.2 + math.sin(a) * dw))
    cut = [(x, y, front - 0.0 + 0.2) for x, y in [(cx - dw, 0.0), (cx + dw, 0.0)] + arch] + [(x, y, front - 0.35) for x, y in [(cx - dw, 0.0), (cx + dw, 0.0)] + arch]
    m.cut_box(CONC, (cx - hw - 0.5, 0.1, front - 0.35), (cx + hw + 0.5, 3.2, front + 0.12), [cut], bevel=0.04, seg=1)
    for sgn in (-1, 1):                                                                       # wing walls
        xa = cx + sgn * (hw + 0.5)
        m.hull(CONC, [(xa, 0.1, front + 0.12), (xa, 3.2, front + 0.12), (xa + sgn * 0.5, 0.1, front + 0.12), (xa, 0.1, front - 0.9), (xa, 2.0, front - 0.9), (xa + sgn * 0.5, 0.1, front - 0.9)])
    # the blast door in the recess: two leaves of dark steel, diagonal hazard stripes, a lock bar, lamps
    dz = front - 0.3
    m.box("dark", (cx - dw, 0.1, dz - 0.02), (cx + dw, 2.45, dz + 0.0))
    for sgn in (-1, 1):
        x0, x1 = (cx - dw + 0.08, cx - 0.03) if sgn < 0 else (cx + 0.03, cx + dw - 0.08)
        m.box(DARK, (x0, 0.12, dz), (x1, 2.3, dz + 0.12), bevel=0.03, seg=1)
        for k in range(4):
            xs = x0 + (x1 - x0) * (k + 0.5) / 4
            m.hull("hazard" if k % 2 == 0 else "dark", [(xs - 0.12, 0.2, dz + 0.125), (xs + 0.12, 0.2, dz + 0.125), (xs + 0.12 + 0.5, 1.0, dz + 0.125), (xs - 0.12 + 0.5, 1.0, dz + 0.125),
                                                      (xs - 0.12, 0.2, dz + 0.135), (xs + 0.12, 0.2, dz + 0.135), (xs + 0.12 + 0.5, 1.0, dz + 0.135), (xs - 0.12 + 0.5, 1.0, dz + 0.135)])
        for hy in (0.5, 1.6):
            m.box(METAL, (x0 + 0.1, hy, dz + 0.12), (x1 - 0.1, hy + 0.06, dz + 0.16), bevel=0.01, seg=1)
    m.pipe(METAL, (cx, 0.3, dz + 0.17), (cx, 1.9, dz + 0.17), 0.04, 6)
    for sy in (0.6, 1.5):
        m.cyl(METAL, (cx, sy, dz + 0.19), 0.09, 0.05, 8)
    m.box("paint", (cx - 0.4, 3.35, front - 0.1), (cx + 0.4, 3.75, front + 0.08), bevel=0.02, seg=1, tint=hexc("e8e4d6"))      # the number plate
    for k in range(number):
        m.box("dark", (cx - 0.28 + k * 0.22, 3.43, front + 0.08), (cx - 0.2 + k * 0.22, 3.68, front + 0.1))
    m.box("glow_warm", (cx - 0.2, 2.9, front + 0.12), (cx + 0.2, 3.0, front + 0.2))
    m.box("paint", (cx - hw - 0.3, 1.2, front + 0.12), (cx - hw - 0.1, 1.9, front + 0.17), tint=hexc("c83a2e"))               # warning placards
    m.box("paint", (cx + hw + 0.1, 1.2, front + 0.12), (cx + hw + 0.3, 1.9, front + 0.17), tint=hexc("c83a2e"))
    for k in range(2):                                                                         # vents on the crown
        vx, vz = cx - 0.8 + k * 1.6, front - hl * 1.1
        m.pipe(METAL, (vx, top - 0.2, vz), (vx, top + 0.5, vz), 0.11, 8)
        m.cyl(DARK, (vx, top + 0.5, vz), 0.2, 0.07, 8)
    m.box(CONC, (cx - hw + 0.3, 0.1, front + 0.1), (cx + hw - 0.3, 0.2, front + 1.3), bevel=0.02, seg=1)                     # the doorstep
    m.box(DARK, (cx - 0.5, 0.2, front + 1.3), (cx + 0.5, 0.22, front + 1.5))                                                   # a drain grate


def crate(m, x, y, z, w, h, d, tint=hexc("7a6a42"), yaw=0.0):
    m.box("wood", (x, y, z), (x + w, y + h, z + d), bevel=0.015, seg=1, tint=tint, yaw=yaw)
    for q in (0.04, w - 0.08):
        m.box("wood", (x + q, y, z - 0.012), (x + q + 0.04, y + h, z + d + 0.012), tint=tuple(t * 0.8 for t in tint), yaw=yaw)
    m.box("hazard", (x + w * 0.15, y + h * 0.4, z + d), (x + w * 0.85, y + h * 0.55, z + d + 0.012), yaw=yaw)


def drum(m, x, z, tint=OLIVE):
    m.cyl("paint", (x, 0.15, z), 0.32, 0.9, 12, tint=tint)
    for y in (0.35, 0.6, 0.85):
        m.tube("paint", (x, 0.15 + y - 0.1, z), 0.335, 0.31, 0.03, 12, tint=tuple(t * 0.8 for t in tint))
    m.cyl(DARK, (x, 1.05, z), 0.33, 0.04, 12)
