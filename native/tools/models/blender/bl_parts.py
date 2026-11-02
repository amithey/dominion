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
    m.dome("paint", (x, y + 0.5, z), r, r * 0.95, 20, 7, tint=(1.0, 1.0, 1.02))


def container(m, x, z, yaw, tint, length=2.6, width=1.25, height=1.8):
    """A shipping-container shelter: corrugated sides, corner posts, a door end with locking bars."""
    with m.frame((x, 0, z), yaw=yaw):
        hl, hw = length / 2, width / 2
        m.box("paint", (-hl, 0.1, -hw), (hl, 0.1 + height, hw), bevel=0.03, seg=1, tint=tint)
        for sgn in (-1, 1):
            for k in range(int(length / 0.22)):
                xx = -hl + 0.15 + k * 0.22
                m.box("paint", (xx - 0.04, 0.2, sgn * hw), (xx + 0.04, 0.1 + height - 0.1, sgn * hw + sgn * 0.035), tint=tuple(t * 0.85 for t in tint))
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.box(DARK, (sx * hl - 0.05, 0.1, sz * hw - 0.05), (sx * hl + 0.05, 0.1 + height, sz * hw + 0.05))
        for q in (-0.35, 0.35):
            m.pipe(METAL, (hl + 0.03, 0.25, q), (hl + 0.03, 0.1 + height - 0.15, q), 0.02, 5)
        m.box(DARK, (-hl, 0.1 + height, -hw), (hl, 0.15 + height, hw))


def truck(m, x, z, yaw=0.0, canvas=True, bed=5.1):
    """A military support truck: ladder chassis, cab, canvas bed on arches, six wheels."""
    olive = hexc("55633f")
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
