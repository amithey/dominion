'use strict';
/* ============================================================
   Navigation & pathfinding — coarse walkability grids (land /
   sea) plus A* with string-pulling. Units request the next
   waypoint via pathNext(); straight-line moves skip A* whenever
   line-of-sight is clear, so the common case stays cheap.
   ============================================================ */

const NAV = {
  cell: 4, cols: 0,
  land: null, sea: null,
  dirty: true,
  // reusable A* buffers (allocated once per map)
  gCost: null, parent: null, stamp: null, gen: 0,
};

function navIndex(x, z) {
  const cx = clamp(Math.floor((x + HALF_MAP) / NAV.cell), 0, NAV.cols - 1);
  const cz = clamp(Math.floor((z + HALF_MAP) / NAV.cell), 0, NAV.cols - 1);
  return cz * NAV.cols + cx;
}
function navCenter(i) {
  return {
    x: (i % NAV.cols + 0.5) * NAV.cell - HALF_MAP,
    z: (Math.floor(i / NAV.cols) + 0.5) * NAV.cell - HALF_MAP,
  };
}

function navRebuild() {
  NAV.cols = Math.ceil(MAP_SIZE / NAV.cell);
  const n = NAV.cols * NAV.cols;
  NAV.land = new Uint8Array(n);
  NAV.sea = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    const c = navCenter(i);
    const h = terrainH(c.x, c.z);
    NAV.land[i] = h > 0.05 ? 1 : 0;
    NAV.sea[i] = h < -0.5 ? 1 : 0;
  }
  for (const b of G.buildings) if (!b.dead) navBlockBuilding(b, true);
  NAV.gCost = new Float32Array(n);
  NAV.parent = new Int32Array(n);
  NAV.stamp = new Int32Array(n);
  NAV.gen = 0;
  NAV.dirty = false;
}

/* buildings block the land grid so units path around bases */
function navBlockBuilding(b, block) {
  if (!NAV.land || NAV.dirty) return;
  const r = Math.max(1, Math.ceil(b.def.size * 0.52 / NAV.cell));
  const cx = Math.floor((b.x + HALF_MAP) / NAV.cell);
  const cz = Math.floor((b.z + HALF_MAP) / NAV.cell);
  for (let dz = -r; dz <= r; dz++) {
    for (let dx = -r; dx <= r; dx++) {
      if (Math.hypot(dx, dz) > r + 0.25) continue;
      const nx = cx + dx, nz = cz + dz;
      if (nx < 0 || nz < 0 || nx >= NAV.cols || nz >= NAV.cols) continue;
      const i = nz * NAV.cols + nx;
      if (block) NAV.land[i] = 0;
      else {
        // restore from terrain (another building may still overlap; territoryTick era rebuild fixes rare cases)
        const c = navCenter(i);
        NAV.land[i] = terrainH(c.x, c.z) > 0.05 ? 1 : 0;
      }
    }
  }
}

/* straight line walkable? sampled every half-cell */
function navLOS(x0, z0, x1, z1, naval) {
  if (NAV.dirty) navRebuild();
  const grid = naval ? NAV.sea : NAV.land;
  const d = Math.hypot(x1 - x0, z1 - z0);
  const steps = Math.max(1, Math.ceil(d / (NAV.cell * 0.5)));
  for (let s = 1; s <= steps; s++) {
    const t = s / steps;
    if (!grid[navIndex(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t)]) return false;
  }
  return true;
}

function navNearestOpen(i, grid, maxR) {
  if (grid[i]) return i;
  const cx = i % NAV.cols, cz = Math.floor(i / NAV.cols);
  for (let r = 1; r <= maxR; r++) {
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        if (Math.max(Math.abs(dx), Math.abs(dz)) !== r) continue;
        const nx = cx + dx, nz = cz + dz;
        if (nx < 0 || nz < 0 || nx >= NAV.cols || nz >= NAV.cols) continue;
        const j = nz * NAV.cols + nx;
        if (grid[j]) return j;
      }
    }
  }
  return -1;
}

/* A* over the walkability grid. Returns array of {x,z} or null. */
function findPath(sx, sz, gx, gz, naval) {
  if (NAV.dirty) navRebuild();
  const grid = naval ? NAV.sea : NAV.land;
  let start = navIndex(sx, sz), goal = navIndex(gx, gz);
  start = navNearestOpen(start, grid, 4);
  goal = navNearestOpen(goal, grid, 8);
  if (start < 0 || goal < 0) return null;
  if (start === goal) return [{ x: gx, z: gz }];

  const cols = NAV.cols;
  NAV.gen++;
  const { gCost, parent, stamp } = NAV;
  const gxc = goal % cols, gzc = Math.floor(goal / cols);

  // simple binary heap of [f, index]
  const heap = [];
  const push = (f, i) => {
    heap.push([f, i]);
    let c = heap.length - 1;
    while (c > 0) {
      const p = (c - 1) >> 1;
      if (heap[p][0] <= heap[c][0]) break;
      [heap[p], heap[c]] = [heap[c], heap[p]]; c = p;
    }
  };
  const pop = () => {
    const top = heap[0], last = heap.pop();
    if (heap.length) {
      heap[0] = last;
      let p = 0;
      for (;;) {
        const l = p * 2 + 1, r = l + 1;
        let m = p;
        if (l < heap.length && heap[l][0] < heap[m][0]) m = l;
        if (r < heap.length && heap[r][0] < heap[m][0]) m = r;
        if (m === p) break;
        [heap[p], heap[m]] = [heap[m], heap[p]]; p = m;
      }
    }
    return top;
  };
  const hDist = i => {
    const dx = Math.abs(i % cols - gxc), dz = Math.abs(Math.floor(i / cols) - gzc);
    return (dx + dz) + (Math.SQRT2 - 2) * Math.min(dx, dz);
  };

  stamp[start] = NAV.gen; gCost[start] = 0; parent[start] = -1;
  push(hDist(start), start);
  let expansions = 0, found = false;

  const expansionLimit = Math.min(cols * cols, 28000);
  while (heap.length && expansions++ < expansionLimit) {
    const [, cur] = pop();
    if (cur === goal) { found = true; break; }
    const cx = cur % cols, cz = Math.floor(cur / cols);
    for (let dz = -1; dz <= 1; dz++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dz) continue;
        const nx = cx + dx, nz = cz + dz;
        if (nx < 0 || nz < 0 || nx >= cols || nz >= cols) continue;
        const ni = nz * cols + nx;
        if (!grid[ni]) continue;
        // no cutting corners diagonally through blocked cells
        if (dx && dz && (!grid[cz * cols + nx] || !grid[nz * cols + cx])) continue;
        const step = dx && dz ? Math.SQRT2 : 1;
        const ng = gCost[cur] + step;
        if (stamp[ni] === NAV.gen && gCost[ni] <= ng) continue;
        stamp[ni] = NAV.gen; gCost[ni] = ng; parent[ni] = cur;
        push(ng + hDist(ni), ni);
      }
    }
  }
  if (!found) return null;

  // reconstruct, then string-pull with line-of-sight
  const cells = [];
  for (let i = goal; i !== -1; i = parent[i]) cells.push(i);
  cells.reverse();
  const pts = cells.map(navCenter);
  pts[pts.length - 1] = { x: gx, z: gz };
  const out = [];
  let a = { x: sx, z: sz };
  let k = 0;
  while (k < pts.length - 1) {
    // furthest point still visible from `a`
    let far = k;
    for (let j = pts.length - 1; j > k; j--) {
      if (navLOS(a.x, a.z, pts[j].x, pts[j].z, naval)) { far = j; break; }
    }
    if (far === k) far = k + 1; // always progress
    out.push(pts[far]);
    a = pts[far];
    k = far;
  }
  if (!out.length) out.push(pts[pts.length - 1]);
  return out;
}

/* per-unit waypoint steering: returns the point to head toward, or null for direct */
function pathNext(u, gx, gz) {
  if (u.def.fly) return null; // aircraft fly straight
  const naval = !!u.def.naval;
  const now = G.time;
  const goalMoved = !u.pathGoal || dist2d(u.pathGoal.x, u.pathGoal.z, gx, gz) > 6;
  if ((goalMoved || u.forceRepath) && now >= (u.nextPathAt || 0)) {
    u.nextPathAt = now + 0.8;
    u.forceRepath = false;
    u.pathGoal = { x: gx, z: gz };
    if (navLOS(u.x, u.z, gx, gz, naval)) u.path = null;
    else { u.path = findPath(u.x, u.z, gx, gz, naval); u.pathI = 0; }
  }
  if (u.path && u.pathI < u.path.length) {
    const wp = u.path[u.pathI];
    if (dist2d(u.x, u.z, wp.x, wp.z) < 3.2) {
      u.pathI++;
      return u.pathI < u.path.length ? u.path[u.pathI] : null;
    }
    return wp;
  }
  return null;
}
