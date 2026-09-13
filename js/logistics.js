'use strict';

const HEX_RADIUS = 12;
const HEX_DIRECTIONS = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
const LOGISTICS = { edges: new Map(), dirty: true, reachable: new Map(), railReachable: new Map(), mesh: null, grid: null,
  mode: null, start: null, preview: null, plan: null, hover: '', showGrid: false };
const TRANSPORT = { road: { money: 12, iron: 0, hp: 100 }, rail: { money: 22, iron: 3, hp: 160 } };
const hexKey = h => `${h.q},${h.r}`;
function hexCenter(h) { return { x: HEX_RADIUS * Math.sqrt(3) * (h.q + h.r / 2), z: HEX_RADIUS * 1.5 * h.r }; }
function worldHex(x, z) {
  const q = (Math.sqrt(3) * x / 3 - z / 3) / HEX_RADIUS, r = z * 2 / (3 * HEX_RADIUS);
  let a = Math.round(q), b = Math.round(r), c = Math.round(-q - r);
  const da = Math.abs(a - q), db = Math.abs(b - r), dc = Math.abs(c + q + r);
  if (da > db && da > dc) a = -b - c;
  else if (db > dc) b = -a - c;
  return { q: a, r: b };
}
function hexDistance(a, b) { return (Math.abs(a.q - b.q) + Math.abs(a.r - b.r) + Math.abs(a.q + a.r - b.q - b.r)) / 2; }
function transportKey(a, b, owner) { return `${owner}:${[hexKey(a), hexKey(b)].sort().join('|')}`; }
function transportPassable(a, b, owner, kind) {
  const p = hexCenter(a), t = hexCenter(b);
  let previous = terrainH(p.x, p.z);
  for (let i = 0; i <= 6; i++) {
    const x = p.x + (t.x - p.x) * i / 6, z = p.z + (t.z - p.z) * i / 6;
    const y = terrainH(x, z), landOwner = territoryOwnerAt(x, z);
    if (Math.abs(x) > HALF_MAP - HEX_RADIUS || Math.abs(z) > HALF_MAP - HEX_RADIUS || y < .3
      || (landOwner >= 0 && landOwner !== owner) || territoryIsContested(x, z)
      || Math.abs(y - previous) > (kind === 'rail' ? 1.4 : 2.5)) return false;
    previous = y;
  }
  return true;
}
// Bounded A*: road planning runs on clicks/hex changes, never on every frame.
function planTransport(start, goal, owner = 0, kind = 'road') {
  if (hexDistance(start, goal) > 70) return null;
  const open = [{ ...start, g: 0, f: hexDistance(start, goal) }], best = new Map([[hexKey(start), 0]]), parent = new Map();
  for (let count = 0; open.length && count < 4500; count++) {
    open.sort((a, b) => b.f - a.f);
    const cur = open.pop(), key = hexKey(cur);
    if (cur.g !== best.get(key)) continue;
    if (key === hexKey(goal)) {
      const route = [{ q: cur.q, r: cur.r }];
      while (parent.has(hexKey(route[0]))) route.unshift(parent.get(hexKey(route[0])));
      return route;
    }
    for (const [dq, dr] of HEX_DIRECTIONS) {
      const next = { q: cur.q + dq, r: cur.r + dr }, nk = hexKey(next);
      if (!transportPassable(cur, next, owner, kind)) continue;
      const g = cur.g + 1;
      if (g >= (best.get(nk) ?? Infinity)) continue;
      best.set(nk, g); parent.set(nk, { q: cur.q, r: cur.r });
      open.push({ ...next, g, f: g + hexDistance(next, goal) });
    }
  }
  return null;
}
function transportQuote(route, kind, owner = 0) {
  const cost = { money: 0, iron: 0 }, def = TRANSPORT[kind];
  if (!route || !def) return cost;
  for (let i = 1; i < route.length; i++) {
    const e = LOGISTICS.edges.get(transportKey(route[i - 1], route[i], owner));
    if (e && e.hp === e.maxHp && (e.kind === kind || e.kind === 'rail')) continue;
    const repair = e && (e.kind === kind || e.kind === 'rail');
    const health = repair ? ((e.tileHp || [e.hp, e.hp]).reduce((a, b) => a + b, 0) / 2) : 0;
    const rate = repair ? .5 * (1 - health / e.maxHp) : 1;
    cost.money += Math.ceil((repair ? TRANSPORT[e.kind] : def).money * rate);
    cost.iron += Math.ceil((repair ? TRANSPORT[e.kind] : def).iron * rate);
  }
  return cost;
}
function buildTransport(route, kind, owner = 0) {
  if (!route || route.length < 2 || !TRANSPORT[kind]) return false;
  for (let i = 1; i < route.length; i++) if (hexDistance(route[i - 1], route[i]) !== 1
    || !transportPassable(route[i - 1], route[i], owner, kind)) return false;
  const cost = transportQuote(route, kind, owner), funds = owner === 0 ? G.res : G.nations[owner];
  if (funds.money < cost.money || (owner === 0 && funds.iron < cost.iron)) return false;
  funds.money -= cost.money; if (owner === 0) funds.iron -= cost.iron;
  for (let i = 1; i < route.length; i++) {
    const a = route[i - 1], b = route[i], key = transportKey(a, b, owner), old = LOGISTICS.edges.get(key);
    const nextKind = old?.kind === 'rail' ? 'rail' : kind;
    const hp = TRANSPORT[nextKind].hp;
    LOGISTICS.edges.set(key, { a, b, owner, kind: nextKind, hp, maxHp: hp, tileHp: [hp, hp] });
    const p = hexCenter(a), t = hexCenter(b);
    for (let j = 0; j <= 8; j++) treesNear(p.x + (t.x - p.x) * j / 8, p.z + (t.z - p.z) * j / 8, 2.2).forEach(removeTree);
  }
  LOGISTICS.dirty = true;
  rebuildTransportMesh(); updateLogistics();
  return true;
}
function supplyReachable(edges, roots, owner) {
  const graph = new Map();
  for (const e of edges) {
    if (e.owner !== owner || e.hp <= 0) continue;
    const a = hexKey(e.a), b = hexKey(e.b);
    if (!graph.has(a)) graph.set(a, []); if (!graph.has(b)) graph.set(b, []);
    graph.get(a).push(b); graph.get(b).push(a);
  }
  const reached = new Set(roots.map(hexKey)), queue = [...reached];
  for (let i = 0; i < queue.length; i++) for (const n of graph.get(queue[i]) || [])
    if (!reached.has(n)) { reached.add(n); queue.push(n); }
  return reached;
}
function updateLogistics() {
  // Settlement completion/destruction can change connectivity even with no road edits.
  const signature = G.buildings.filter(b => !b.dead && b.built && b.def.settlement).map(b => `${b.id}:${b.owner}:${b.x}:${b.z}`).join(',');
  if (signature !== LOGISTICS.signature) { LOGISTICS.signature = signature; LOGISTICS.dirty = true; }
  if (LOGISTICS.dirty) {
    for (let owner = 0; owner < G.nations.length; owner++) {
      const roots = settlementBuildings(owner).filter(b => b.key === 'hq').map(b => worldHex(b.x, b.z));
      LOGISTICS.reachable.set(owner, supplyReachable(LOGISTICS.edges.values(), roots, owner));
      LOGISTICS.railReachable.set(owner, supplyReachable([...LOGISTICS.edges.values()].filter(e => e.kind === 'rail'), roots, owner));
    }
    LOGISTICS.dirty = false;
  }
  for (const b of G.buildings) {
    if (b.dead) continue;
    const s = b.def.settlement ? b : settlementBuildZoneAt(b.x, b.z, b.owner)?.settlement;
    const supplied = !!(s && LOGISTICS.reachable.get(b.owner)?.has(hexKey(worldHex(s.x, s.z))));
    if (b.owner === 0 && b.built && b.def.settlement && b.supplied !== undefined && b.supplied !== supplied)
      notify(`${settlementDisplayName(b)}: ${supplied ? 'supply restored' : 'supply cut — reconnect roads or rails'}.`, supplied ? 'good' : 'warn');
    b.supplied = supplied;
    b.railSupplied = !!(s && s.key !== 'hq' && LOGISTICS.railReachable.get(b.owner)?.has(hexKey(worldHex(s.x, s.z))));
  }
  const total = settlementBuildings(0), connected = total.filter(b => b.supplied).length;
  const status = document.getElementById('logistics-status');
  if (status) status.textContent = `${connected}/${total.length} supplied`;
}
// Each half-edge belongs to its endpoint hex. Destroying one tile must not
// erase the intact half of the road in the neighbouring tile.
function damageTransportHex(x, z, damage) {
  const key = hexKey(worldHex(x, z));
  return applyTransportDamage((e, side) => hexKey(side ? e.b : e.a) === key ? damage : 0);
}
function applyTransportDamage(amount) {
  let hit = 0;
  for (const e of LOGISTICS.edges.values()) {
    if (!e.tileHp) e.tileHp = [e.hp, e.hp];
    for (let side = 0; side < 2; side++) {
      const damage = amount(e, side);
      if (damage <= 0 || e.tileHp[side] <= 0) continue;
      e.tileHp[side] = Math.max(0, e.tileHp[side] - damage); hit++;
    }
    e.hp = Math.min(...e.tileHp);
  }
  if (hit) { LOGISTICS.dirty = true; rebuildTransportMesh(); updateLogistics(); }
  return hit;
}
function damageTransport(x, z, radius, damage) {
  return applyTransportDamage((e, side) => {
    const a = hexCenter(e.a), b = hexCenter(e.b), dx = b.x - a.x, dz = b.z - a.z;
    const t = Math.max(side * .5, Math.min((side + 1) * .5, ((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz)));
    const d = Math.hypot(x - a.x - t * dx, z - a.z - t * dz);
    return d > radius ? 0 : damage * (1 - .5 * d / Math.max(radius, .01));
  });
}
function clearTransportObject(name) {
  const obj = LOGISTICS[name]; if (!obj) return;
  scene.remove(obj); obj.traverse(o => { o.geometry?.dispose(); if (o.material) o.material.dispose(); }); LOGISTICS[name] = null;
}
function rebuildTransportMesh() {
  clearTransportObject('mesh');
  const group = new THREE.Group(); group.name = 'roads-and-railways';
  const positions = [], colors = [];
  const strip = (a, b, width, offset, color, lift = .09) => {
    const dx = b.x - a.x, dz = b.z - a.z, len = Math.hypot(dx, dz), nx = -dz / len, nz = dx / len;
    const point = (t, side) => {
      const x = a.x + dx * t + nx * (offset + side * width / 2), z = a.z + dz * t + nz * (offset + side * width / 2);
      return [x, terrainH(x, z) + lift, z];
    };
    for (let i = 0; i < 8; i++) {
      const v = [point(i / 8, -1), point(i / 8, 1), point((i + 1) / 8, -1), point((i + 1) / 8, 1)];
      for (const j of [0, 1, 2, 2, 1, 3]) { positions.push(...v[j]); colors.push(color.r, color.g, color.b); }
    }
  };
  const asphalt = new THREE.Color(0x66665d), gravel = new THREE.Color(0x79766a), steel = new THREE.Color(0xb5b4a7), paint = new THREE.Color(0xd5c9a1), broken = new THREE.Color(0x884b35);
  for (const edge of LOGISTICS.edges.values()) for (let side = 0; side < 2; side++) {
    const e = { ...edge, hp: edge.tileHp?.[side] ?? edge.hp };
    const from = hexCenter(e.a), to = hexCenter(e.b), mid = { x: (from.x + to.x) / 2, z: (from.z + to.z) / 2 };
    const a = side ? mid : from, b = side ? to : mid;
    if (e.hp <= 0) {
      for (const [lo, hi] of [[0, .32], [.68, 1]]) strip({ x: a.x + (b.x - a.x) * lo, z: a.z + (b.z - a.z) * lo }, { x: a.x + (b.x - a.x) * hi, z: a.z + (b.z - a.z) * hi }, 2.4, 0, broken);
      continue;
    }
    strip(a, b, e.kind === 'rail' ? 2 : 2.8, 0, e.kind === 'rail' ? gravel : asphalt);
    if (e.kind === 'rail') {
      for (const side of [-.55, .55]) strip(a, b, .12, side, steel, .15);
      for (let i = 1; i < 16; i++) {
        const t = i / 16, dx = b.x - a.x, dz = b.z - a.z, len = Math.hypot(dx, dz);
        const x = a.x + dx * t, z = a.z + dz * t;
        strip({ x: x - dz / len * .85, z: z + dx / len * .85 }, { x: x + dz / len * .85, z: z - dx / len * .85 }, .19, 0, asphalt, .12);
      }
    } else strip(a, b, .09, 0, paint, .11);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3)); geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: .92, side: THREE.DoubleSide })); mesh.receiveShadow = true; group.add(mesh);
  scene.add(group); LOGISTICS.mesh = group;
}
function showHexGrid(show) {
  if (!LOGISTICS.grid && show) {
    const vertices = [], limit = Math.ceil(HALF_MAP / (HEX_RADIUS * 1.5)) + 2;
    for (let q = -limit * 2; q <= limit * 2; q++) for (let r = -limit; r <= limit; r++) {
      const p = hexCenter({ q, r });
      if (Math.abs(p.x) > HALF_MAP - HEX_RADIUS || Math.abs(p.z) > HALF_MAP - HEX_RADIUS || terrainH(p.x, p.z) < .3) continue;
      for (let i = 0; i < 6; i++) for (const corner of [i, i + 1]) {
        const angle = (corner * 60 + 30) * Math.PI / 180, x = p.x + Math.cos(angle) * HEX_RADIUS, z = p.z + Math.sin(angle) * HEX_RADIUS;
        vertices.push(x, terrainH(x, z) + .12, z);
      }
    }
    const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    LOGISTICS.grid = new THREE.LineSegments(geo, new THREE.LineBasicMaterial({ color: 0xd3c591, transparent: true, opacity: .27, depthWrite: false })); scene.add(LOGISTICS.grid);
  }
  if (LOGISTICS.grid) LOGISTICS.grid.visible = show;
}
function cancelTransport() {
  LOGISTICS.mode = null; LOGISTICS.start = null; LOGISTICS.plan = null; LOGISTICS.hover = '';
  clearTransportObject('preview'); showHexGrid(LOGISTICS.showGrid);
  document.getElementById('transport-panel').hidden = true;
  document.getElementById('transport-build').disabled = true;
}
function beginTransport(kind) {
  cancelPlacement(); G.targeting = null; cancelTransport(); LOGISTICS.mode = kind;
  showHexGrid(true); document.getElementById('transport-panel').hidden = false;
  document.getElementById('transport-hint').textContent = `${kind === 'rail' ? 'Railway' : 'Road'}: select the starting settlement or hex.`;
}
function transportClick(x, z) {
  const h = worldHex(x, z);
  if (!LOGISTICS.start) { LOGISTICS.start = h; document.getElementById('transport-hint').textContent = 'Select the destination. Review the route and cost, then Build.'; return; }
  LOGISTICS.plan = planTransport(LOGISTICS.start, h, 0, LOGISTICS.mode);
  clearTransportObject('preview');
  const route = LOGISTICS.plan, hint = document.getElementById('transport-hint'), button = document.getElementById('transport-build');
  button.disabled = !route || route.length < 2;
  if (button.disabled) { hint.textContent = 'No land route. Roads cannot cross sea, steep cliffs or foreign territory.'; return; }
  const vertices = [];
  for (const hex of route) { const p = hexCenter(hex); vertices.push(p.x, terrainH(p.x, p.z) + .25, p.z); }
  const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  LOGISTICS.preview = new THREE.Line(geo, new THREE.LineBasicMaterial({ color: 0xffd57d, depthTest: false })); scene.add(LOGISTICS.preview);
  const cost = transportQuote(route, LOGISTICS.mode);
  hint.textContent = `${route.length - 1} segments · $${cost.money} · ${cost.iron} iron. Existing intact segments are free; damaged ones will be repaired.`;
}
function initLogisticsUI() {
  const bar = document.getElementById('command-strip');
  bar.insertAdjacentHTML('beforeend', '<button id="btn-roads">Roads</button><button id="btn-rails">Rails</button><button id="btn-hexes">Hex grid</button><span id="logistics-status"></span>');
  const panel = document.createElement('div'); panel.id = 'transport-panel'; panel.hidden = true;
  panel.innerHTML = '<span id="transport-hint"></span><button id="transport-build" disabled>Build / repair</button><button id="transport-cancel">Cancel</button>';
  document.getElementById('game-container').appendChild(panel);
  document.getElementById('btn-roads').onclick = () => beginTransport('road');
  document.getElementById('btn-rails').onclick = () => beginTransport('rail');
  document.getElementById('btn-hexes').onclick = () => { LOGISTICS.showGrid = !LOGISTICS.showGrid; showHexGrid(LOGISTICS.showGrid || !!LOGISTICS.mode); };
  document.getElementById('transport-cancel').onclick = cancelTransport;
  document.getElementById('transport-build').onclick = () => {
    if (buildTransport(LOGISTICS.plan, LOGISTICS.mode)) { notify('Route ready. Supply network updated.', 'good'); cancelTransport(); }
    else notify('Route could not be built. Check resources and territorial access.', 'warn');
  };
}
function updateAILogistics(nat, dt) {
  nat.logisticsTimer = (nat.logisticsTimer || 0) - dt;
  if (nat.logisticsTimer > 0) return; nat.logisticsTimer = 20;
  const cities = settlementBuildings(nat.ai.id), hq = cities.find(b => b.key === 'hq');
  const isolated = cities.find(b => !b.supplied && b !== hq);
  if (hq && isolated) buildTransport(planTransport(worldHex(hq.x, hq.z), worldHex(isolated.x, isolated.z), nat.ai.id), 'road', nat.ai.id);
}
