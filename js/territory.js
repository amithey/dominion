'use strict';
/* ============================================================
   Territory control - separate gradual occupation model.
   Cells have an owner, control strength, contested state and
   front-line pressure. Buildings project authority; combat
   units occupy and contest. Land flips only after control is
   worn down, so conquest feels like a campaign, not a light
   switch.
   ============================================================ */

const TERRITORY = {
  cols: 0, rows: 0, owner: null, control: null, contested: null,
  pressure: null, fronts: 0, dirty: true, lastSummary: [], borderMesh: null,
};

/* terrain classes for Civ-style cell yields */
const TERRAIN_CLASS = { WATER: 0, PLAINS: 1, FOREST: 2, MOUNTAIN: 3, COAST: 4 };
const TERRAIN_META = {
  1: { name: 'Plains',   icon: '🌾', yield: 'food' },
  2: { name: 'Forest',   icon: '🌲', yield: 'lumber money' },
  3: { name: 'Mountain', icon: '⛰️', yield: 'iron' },
  4: { name: 'Coast',    icon: '🌊', yield: 'trade money' },
};

function initTerritory() {
  TERRITORY.cols = Math.ceil(MAP_SIZE / TERRITORY_CELL);
  TERRITORY.rows = TERRITORY.cols;
  const n = TERRITORY.cols * TERRITORY.rows;
  TERRITORY.owner = new Int8Array(n).fill(-1);
  TERRITORY.control = new Float32Array(n).fill(0);
  TERRITORY.contested = new Uint8Array(n).fill(0);
  TERRITORY.pressure = new Float32Array(n).fill(0);
  TERRITORY.fronts = 0;
  TERRITORY.lastSummary = [];
  TERRITORY.dirty = true;
  // classify every cell's terrain once — the land itself decides what it yields
  TERRITORY.terrain = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    const c = cellCenter(i);
    const h = terrainH(c.x, c.z);
    if (h < 0.05) { TERRITORY.terrain[i] = TERRAIN_CLASS.WATER; continue; }
    // a land cell touching water is a coast cell
    let coast = false;
    for (const [dx, dz] of [[TERRITORY_CELL, 0], [-TERRITORY_CELL, 0], [0, TERRITORY_CELL], [0, -TERRITORY_CELL]]) {
      if (terrainH(c.x + dx, c.z + dz) < 0) { coast = true; break; }
    }
    if (coast) TERRITORY.terrain[i] = TERRAIN_CLASS.COAST;
    else if (h > 6) TERRITORY.terrain[i] = TERRAIN_CLASS.MOUNTAIN;
    else if (vnoise(c.x * 0.015 + 91, c.z * 0.015 + 43) > 0.55) TERRITORY.terrain[i] = TERRAIN_CLASS.FOREST;
    else TERRITORY.terrain[i] = TERRAIN_CLASS.PLAINS;
  }
}

/* integration status of a held cell: how firmly it belongs to its owner */
function cellStatus(i) {
  if (TERRITORY.contested[i]) return 'contested';
  const ctl = TERRITORY.control[i];
  if (ctl >= 70) return 'sovereign';
  if (ctl >= 40) return 'integrated';
  return 'occupied';
}
const STATUS_YIELD_MULT = { sovereign: 1.0, integrated: 0.75, occupied: 0.4, contested: 0.15 };

/* per-second yields of all land a nation holds, scaled by integration */
function territoryYields(nationId) {
  const out = { money: 0, food: 0, iron: 0, sovereign: 0, integrated: 0, occupied: 0, contested: 0 };
  if (!TERRITORY.owner || !TERRITORY.terrain) return out;
  for (let i = 0; i < TERRITORY.owner.length; i++) {
    if (TERRITORY.owner[i] !== nationId) continue;
    const status = cellStatus(i);
    out[status]++;
    const m = STATUS_YIELD_MULT[status];
    out.money += 0.10 * m; // base tribute from every held cell
    switch (TERRITORY.terrain[i]) {
      case TERRAIN_CLASS.PLAINS:   out.food += 0.020 * m; break;
      case TERRAIN_CLASS.FOREST:   out.money += 0.030 * m; break;
      case TERRAIN_CLASS.MOUNTAIN: out.iron += 0.008 * m; break;
      case TERRAIN_CLASS.COAST:    out.money += 0.040 * m; break;
    }
  }
  return out;
}

function cellOf(x, z) {
  const cx = clamp(Math.floor((x + HALF_MAP) / TERRITORY_CELL), 0, TERRITORY.cols - 1);
  const cz = clamp(Math.floor((z + HALF_MAP) / TERRITORY_CELL), 0, TERRITORY.rows - 1);
  return cz * TERRITORY.cols + cx;
}
function cellCenter(i) {
  const cx = i % TERRITORY.cols, cz = Math.floor(i / TERRITORY.cols);
  return {
    x: (cx + 0.5) * TERRITORY_CELL - HALF_MAP,
    z: (cz + 0.5) * TERRITORY_CELL - HALF_MAP,
  };
}
function territoryOwnerAt(x, z) {
  return TERRITORY.owner ? TERRITORY.owner[cellOf(x, z)] : -1;
}
function territoryIsContested(x, z) {
  return TERRITORY.contested ? TERRITORY.contested[cellOf(x, z)] > 0 : false;
}

/* ---------------- settlements & construction districts ----------------
   The HQ is the capital. Village/City Centers are expansion anchors. Other
   structures must belong to one of these districts, so the map develops as
   recognizable settlements instead of one continuous carpet of buildings. */
const SETTLEMENT_NAMES = ['Haven', 'Riverside', 'New Dawn', 'Ironvale', 'Greenfield', 'Northgate', 'Seabrook', 'Highcrest', 'Oakridge', 'Westhaven'];
function isSettlementBuilding(b) { return !!(b && b.def && b.def.settlement); }
function settlementBuildings(owner = 0, builtOnly = true) {
  return G.buildings.filter(b => b.owner === owner && !b.dead && isSettlementBuilding(b) && (!builtOnly || b.built));
}
function settlementDisplayName(b) {
  if (!b) return 'Unassigned';
  if (b.settlementName) return b.settlementName;
  if (b.key === 'hq') return b.owner === 0 ? 'Capital' : `${G.nations[b.owner].name} Capital`;
  const peers = G.buildings.filter(x => x.owner === b.owner && !x.dead && x.key === b.key && x.id <= b.id).length;
  const base = SETTLEMENT_NAMES[(b.id + b.owner * 3) % SETTLEMENT_NAMES.length];
  return b.key === 'cityCenter' ? `${base} City ${peers > 1 ? peers : ''}`.trim() : `${base} Village ${peers > 1 ? peers : ''}`.trim();
}
function nearestSettlement(x, z, owner = 0, builtOnly = true) {
  let best = null, bestD = Infinity;
  for (const s of settlementBuildings(owner, builtOnly)) {
    const d = dist2d(x, z, s.x, s.z);
    if (d < bestD) { best = s; bestD = d; }
  }
  return best ? { settlement: best, distance: bestD, radius: best.def.buildRadius || 40 } : null;
}
function settlementBuildZoneAt(x, z, owner = 0) {
  const near = nearestSettlement(x, z, owner, true);
  return near && near.distance <= near.radius ? near : null;
}
function settlementCounts(owner = 0) {
  const all = settlementBuildings(owner, true);
  return {
    capitals: all.filter(s => s.key === 'hq').length,
    cities: all.filter(s => s.key === 'cityCenter').length,
    villages: all.filter(s => s.key === 'villageCenter').length,
    total: all.length,
  };
}
function settlementCanBeFounded(def, x, z, owner = 0) {
  if (!def.settlement || def.settlement === 'capital') return true;
  const nearest = nearestSettlement(x, z, owner, false);
  const minDistance = def.settlement === 'city' ? 95 : 65;
  return !nearest || nearest.distance >= minDistance;
}

function developmentSnapshot() {
  const settlements = settlementCounts(0);
  return {
    ...settlements,
    buildings: G.buildings.filter(b => b.owner === 0 && b.built && !b.dead).length,
    civilians: Math.floor(G.city.civilians || 0),
    discoveries: Object.keys(DISCOVERIES).filter(k => G.discovered[k]).length,
    power: (G.city.power && G.city.power.supply) || 0,
    routes: (G.trade && G.trade.routes.length) || 0,
    compute: G.city.compute || 0,
    landShare: G.landShare || 0,
  };
}
function developmentRequirementStatus(era) {
  const snap = developmentSnapshot();
  const labels = { villages: 'Villages', cities: 'Cities', buildings: 'Buildings', civilians: 'Citizens', discoveries: 'Discoveries', power: 'Power MW', routes: 'Trade routes', compute: 'Chip fabs', landShare: 'World land' };
  return Object.entries((era && era.req) || {}).map(([key, need]) => ({
    key, label: labels[key] || key, need,
    value: snap[key] || 0,
    met: (snap[key] || 0) >= need,
    displayValue: key === 'landShare' ? `${Math.round((snap[key] || 0) * 100)}%` : Math.floor(snap[key] || 0),
    displayNeed: key === 'landShare' ? `${Math.round(need * 100)}%` : need,
  }));
}
function territoryCellCount(nationId) {
  let n = 0;
  for (let i = 0; i < TERRITORY.owner.length; i++) if (TERRITORY.owner[i] === nationId) n++;
  return n;
}
function territorySummary(nationId) {
  let held = 0, contested = 0, control = 0, fronts = 0;
  for (let i = 0; i < TERRITORY.owner.length; i++) {
    if (TERRITORY.owner[i] !== nationId) continue;
    held++;
    control += TERRITORY.control[i];
    if (TERRITORY.contested[i]) contested++;
    if (isFrontCell(i)) fronts++;
  }
  return {
    held, contested, fronts,
    avgControl: held ? control / held : 0,
    tribute: held * 0.15,
  };
}

function addTerritoryPresence(presence, x, z, owner, w, spread, nNations) {
  if (owner < 0 || G.nations[owner].defeated) return;
  const cx = Math.floor((x + HALF_MAP) / TERRITORY_CELL);
  const cz = Math.floor((z + HALF_MAP) / TERRITORY_CELL);
  for (let dz = -spread; dz <= spread; dz++) {
    for (let dx = -spread; dx <= spread; dx++) {
      const nx = cx + dx, nz = cz + dz;
      if (nx < 0 || nz < 0 || nx >= TERRITORY.cols || nz >= TERRITORY.rows) continue;
      const i = nz * TERRITORY.cols + nx;
      const c = cellCenter(i);
      if (terrainH(c.x, c.z) < 0.05) continue;
      const falloff = 1 + Math.abs(dx) + Math.abs(dz);
      presence[i * nNations + owner] += w / falloff;
    }
  }
}

function territoryTick() {
  const cols = TERRITORY.cols, rows = TERRITORY.rows;
  const nNations = G.nations.length;
  const presence = new Float32Array(cols * rows * nNations);

  for (const b of G.buildings) {
    if (b.dead || !b.built) continue;
    const w = b.key === 'hq' ? 30 : b.key === 'cityCenter' ? 26 : b.key === 'villageCenter' ? 18 : b.key === 'commandCenter' ? 22 : 14;
    const spread = (b.key === 'hq' || b.key === 'cityCenter') ? 2 : 1;
    addTerritoryPresence(presence, b.x, b.z, b.owner, w, spread, nNations);
  }
  for (const u of G.units) {
    if (u.dead || u.def.dmg <= 0) continue;
    const stanceBonus = u.state === 'guard' ? 1.35 : u.state === 'attackMove' ? 1.2 : 1;
    const w = (1.1 + (u.def.pop || 1) * 0.55) * stanceBonus;
    addTerritoryPresence(presence, u.x, u.z, u.owner, w, 0, nNations);
  }

  let changed = false;
  for (let i = 0; i < cols * rows; i++) {
    const c = cellCenter(i);
    if (terrainH(c.x, c.z) < 0.05) {
      if (TERRITORY.owner[i] !== -1 || TERRITORY.control[i] !== 0) changed = true;
      TERRITORY.owner[i] = -1; TERRITORY.control[i] = 0; TERRITORY.contested[i] = 0; TERRITORY.pressure[i] = 0;
      continue;
    }

    const current = TERRITORY.owner[i];
    if (current >= 0 && G.nations[current].defeated) {
      TERRITORY.owner[i] = -1; TERRITORY.control[i] = 0; changed = true;
    }

    let bestOwner = -1, bestW = 0, secondW = 0;
    for (let n = 0; n < nNations; n++) {
      const w = presence[i * nNations + n];
      if (w > bestW) { secondW = bestW; bestW = w; bestOwner = n; }
      else if (w > secondW) secondW = w;
    }

    const contested = bestW > 0.6 && secondW > 0.45 && bestW < secondW * 1.75;
    TERRITORY.contested[i] = contested ? 1 : 0;
    TERRITORY.pressure[i] = bestW - secondW;

    if (bestOwner < 0 || bestW <= 0.35) {
      if (TERRITORY.owner[i] >= 0) TERRITORY.control[i] = Math.max(12, TERRITORY.control[i] - 0.15);
      continue;
    }

    if (TERRITORY.owner[i] === -1) {
      TERRITORY.owner[i] = bestOwner;
      TERRITORY.control[i] = clamp(bestW * 9, 18, 45);
      changed = true;
      continue;
    }

    if (TERRITORY.owner[i] === bestOwner) {
      TERRITORY.control[i] = clamp(TERRITORY.control[i] + bestW * (contested ? 0.08 : 0.28), 0, 100);
    } else if (contested) {
      TERRITORY.control[i] = clamp(TERRITORY.control[i] - Math.max(0.5, (bestW - secondW * 0.45) * 0.18), 0, 100);
    } else {
      TERRITORY.control[i] = clamp(TERRITORY.control[i] - Math.max(1.2, bestW * 0.5), 0, 100);
      if (TERRITORY.control[i] <= 1) {
        TERRITORY.owner[i] = bestOwner;
        TERRITORY.control[i] = clamp(bestW * 8, 20, 55);
        changed = true;
      }
    }
  }

  TERRITORY.fronts = countFrontCells();
  TERRITORY.lastSummary = G.nations.map((_, i) => territorySummary(i));
  if (changed) TERRITORY.dirty = true;
  // Repainting rewrites and re-uploads the whole terrain colour buffer (~1.7 MB),
  // which shows up as a visible hitch. Only do it when ownership actually
  // changed — front-line counts flicker constantly during any skirmish and were
  // triggering a full repaint every couple of seconds for no visible gain.
  if (TERRITORY.dirty) paintTerritory();
  TERRITORY.lastFronts = TERRITORY.fronts;
}

function isFrontCell(i) {
  const owner = TERRITORY.owner[i];
  if (owner < 0) return false;
  const x = i % TERRITORY.cols, z = Math.floor(i / TERRITORY.cols);
  const nbs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  for (const [dx, dz] of nbs) {
    const nx = x + dx, nz = z + dz;
    if (nx < 0 || nz < 0 || nx >= TERRITORY.cols || nz >= TERRITORY.rows) continue;
    const no = TERRITORY.owner[nz * TERRITORY.cols + nx];
    if (no >= 0 && no !== owner) return true;
  }
  return TERRITORY.contested[i] > 0;
}
function countFrontCells() {
  let n = 0;
  for (let i = 0; i < TERRITORY.owner.length; i++) if (isFrontCell(i)) n++;
  return n;
}

/* Territory is communicated by a clean frontier line. The terrain itself is
   never recoloured, so grass, soil and topography keep their natural values. */
function paintTerritory() {
  TERRITORY.dirty = false;
  if (!terrainMesh) return;
  const geo = terrainMesh.geometry;
  const base = geo.userData.baseColors;
  const colors = geo.attributes.color;
  // Border-only display: unchanged terrain colors need no GPU upload.

  if (TERRITORY.borderMesh) {
    TERRITORY.borderMesh.parent?.remove(TERRITORY.borderMesh);
    TERRITORY.borderMesh.geometry.dispose();
    TERRITORY.borderMesh.material.dispose();
    TERRITORY.borderMesh = null;
  }

  const positions = [], vertexColors = [];
  const cols = TERRITORY.cols, rows = TERRITORY.rows;
  const gold = new THREE.Color(0xffd66b);
  const nationColors = G.nations.map(n => new THREE.Color(n.color).offsetHSL(0, 0.06, 0.13));
  const ownerAt = (x, z) => (x < 0 || z < 0 || x >= cols || z >= rows)
    ? -1 : TERRITORY.owner[z * cols + x];

  const addEdge = (x0, z0, x1, z1, owner, neighbour, contested) => {
    const color = contested ? gold.clone() : nationColors[owner].clone();
    if (neighbour >= 0 && neighbour !== owner && !contested) color.lerp(nationColors[neighbour], 0.35);
    const pieces = 5;
    let previous = null;
    for (let s = 0; s <= pieces; s++) {
      const t = s / pieces;
      let x = lerp(x0, x1, t), z = lerp(z0, z1, t);
      const organic = Math.sin(t * Math.PI) * (vnoise(x * 0.08 + owner * 11, z * 0.08 + 7) - 0.5) * 1.3;
      const dx = x1 - x0, dz = z1 - z0, len = Math.max(Math.hypot(dx, dz), 0.001);
      x += (-dz / len) * organic;
      z += (dx / len) * organic;
      const point = [x, Math.max(terrainH(x, z), SEA_LEVEL) + 0.24, z];
      if (previous) {
        positions.push(...previous, ...point);
        vertexColors.push(color.r, color.g, color.b, color.r, color.g, color.b);
      }
      previous = point;
    }
  };

  for (let z = 0; z < rows; z++) {
    for (let x = 0; x < cols; x++) {
      const i = z * cols + x, owner = TERRITORY.owner[i];
      if (owner < 0) continue;
      const x0 = x * TERRITORY_CELL - HALF_MAP;
      const z0 = z * TERRITORY_CELL - HALF_MAP;
      const x1 = x0 + TERRITORY_CELL, z1 = z0 + TERRITORY_CELL;
      const isContested = TERRITORY.contested[i] > 0;
      const left = ownerAt(x - 1, z);
      const top = ownerAt(x, z - 1);
      const right = ownerAt(x + 1, z);
      const bottom = ownerAt(x, z + 1);
      if (right !== owner) addEdge(x1, z0, x1, z1, owner, right, isContested || (right >= 0 && TERRITORY.contested[i + 1] > 0));
      if (bottom !== owner) addEdge(x0, z1, x1, z1, owner, bottom, isContested || (bottom >= 0 && TERRITORY.contested[i + cols] > 0));
      // Right/bottom own inter-nation seams; left/top are needed wherever the
      // neighbouring cell is neutral, otherwise half an enclave outline vanishes.
      if (left < 0) addEdge(x0, z0, x0, z1, owner, -1, isContested);
      if (top < 0) addEdge(x0, z0, x1, z0, owner, -1, isContested);
    }
  }
  if (!positions.length) return;
  const borderGeo = new THREE.BufferGeometry();
  borderGeo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  borderGeo.setAttribute('color', new THREE.Float32BufferAttribute(vertexColors, 3));
  const borderMat = new THREE.LineBasicMaterial({
    vertexColors: true, transparent: true, opacity: 0.92,
    depthWrite: false, toneMapped: false,
  });
  TERRITORY.borderMesh = new THREE.LineSegments(borderGeo, borderMat);
  TERRITORY.borderMesh.renderOrder = 4;
  terrainMesh.parent.add(TERRITORY.borderMesh);
}

function paintTerritoryTintLegacy() {
  TERRITORY.dirty = false;
  if (!terrainMesh) return;
  const geo = terrainMesh.geometry;
  const base = geo.userData.baseColors;
  const colAttr = geo.attributes.color;
  const pos = geo.attributes.position;
  // one-time cache: each vertex's territory cell and land flag — the mesh is
  // static, so recomputing these 148k lookups every repaint was pure waste
  if (!geo.userData.vertCell) {
    const vc = new Int32Array(pos.count);
    const vl = new Uint8Array(pos.count);
    for (let i = 0; i < pos.count; i++) {
      vc[i] = cellOf(pos.getX(i), pos.getZ(i));
      vl[i] = pos.getY(i) > 0.25 ? 1 : 0;
    }
    geo.userData.vertCell = vc;
    geo.userData.vertLand = vl;
  }
  const vertCell = geo.userData.vertCell, vertLand = geo.userData.vertLand;
  // per-cell tint resolved once per paint instead of once per vertex
  const nCells = TERRITORY.owner.length;
  const cellR = new Float32Array(nCells), cellG = new Float32Array(nCells),
        cellB = new Float32Array(nCells), cellT = new Float32Array(nCells);
  const natCol = G.nations.map(n => new THREE.Color(n.color));
  const frontCol = new THREE.Color(0xffe08a);
  for (let ci = 0; ci < nCells; ci++) {
    const owner = TERRITORY.owner[ci];
    if (owner < 0) { cellT[ci] = 0; continue; }
    const c = TERRITORY.contested[ci] ? frontCol : natCol[owner];
    cellT[ci] = TERRITORY.contested[ci] ? 0.32 : 0.10 + clamp(TERRITORY.control[ci] / 100, 0, 1) * 0.22;
    cellR[ci] = c.r; cellG[ci] = c.g; cellB[ci] = c.b;
  }
  const arr = colAttr.array;
  for (let i = 0; i < pos.count; i++) {
    const bi = i * 3;
    let r = base[bi], g = base[bi + 1], b = base[bi + 2];
    if (vertLand[i]) {
      const ci = vertCell[i], t = cellT[ci];
      if (t > 0) {
        r += (cellR[ci] - r) * t;
        g += (cellG[ci] - g) * t;
        b += (cellB[ci] - b) * t;
      }
    }
    arr[bi] = r; arr[bi + 1] = g; arr[bi + 2] = b;
  }
  colAttr.needsUpdate = true;
}
