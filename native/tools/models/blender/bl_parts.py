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


def truck(m, x, z, yaw=0.0, canvas=True):
    """A military support truck: ladder chassis, cab, canvas bed on arches, six wheels."""
    olive = hexc("55633f")
    with m.frame((x, 0, z), yaw=yaw):
        m.box("dark", (-1.0, 0.45, -3.0), (1.0, 0.8, 2.2), bevel=0.04, seg=1)
        m.box("paint", (-1.05, 0.8, 2.2), (1.05, 2.0, 3.4), bevel=0.1, seg=2, tint=olive)
        m.box("glass", (-0.95, 1.3, 3.38), (0.95, 1.85, 3.44), bevel=0.04, seg=1)
        m.box("dark", (-1.1, 0.5, 3.4), (1.1, 0.85, 3.6), bevel=0.04, seg=1)
        m.box("paint", (-1.05, 0.8, -3.0), (1.05, 1.1, 2.1), bevel=0.03, seg=1, tint=olive)
        if canvas:
            for k in range(5):
                zz = -2.7 + k * 1.2
                m.pipe("paint", (-0.95, 1.1, zz), (-0.95, 2.0, zz), 0.03, 5, tint=olive)
                m.pipe("paint", (0.95, 1.1, zz), (0.95, 2.0, zz), 0.03, 5, tint=olive)
                m.pipe("paint", (-0.95, 2.0, zz), (0.95, 2.0, zz), 0.03, 5, tint=olive)
            m.box("paint", (-0.99, 1.1, -3.0), (0.99, 2.05, 2.1), bevel=0.2, seg=3, tint=hexc("4c5a38"))
        for az in (-2.4, -0.9, 2.8):
            for sx in (-1, 1):
                m.pipe("dark", (x * 0 + sx * 0.78, 0.45, az), (sx * 1.1, 0.45, az), 0.45, 14)
        m.box("glow_warm", (-0.9, 0.55, 3.6), (-0.6, 0.7, 3.64))
        m.box("glow_warm", (0.6, 0.55, 3.6), (0.9, 0.7, 3.64))
