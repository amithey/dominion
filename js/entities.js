'use strict';
/* ============================================================
   Entities: buildings, units, missiles, combat, effects,
   city simulation, government & policies
   ============================================================ */

let ENT_ID = 1;

/* ---------------- mesh factories ---------------- */
function makeProceduralTexture(color, kind = 'concrete') {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 64;
  const ctx = cv.getContext('2d');
  const base = new THREE.Color(color);
  ctx.fillStyle = `rgb(${Math.floor(base.r * 255)},${Math.floor(base.g * 255)},${Math.floor(base.b * 255)})`;
  ctx.fillRect(0, 0, 64, 64);
  for (let i = 0; i < 260; i++) {
    const v = kind === 'metal' ? 18 : kind === 'grass' ? 24 : 30;
    const a = 0.035 + Math.random() * 0.08;
    const shade = Math.random() < 0.5 ? -v : v;
    ctx.fillStyle = `rgba(${clamp(Math.floor(base.r * 255 + shade), 0, 255)},${clamp(Math.floor(base.g * 255 + shade), 0, 255)},${clamp(Math.floor(base.b * 255 + shade), 0, 255)},${a})`;
    ctx.fillRect(Math.random() * 64, Math.random() * 64, 1 + Math.random() * 3, 1 + Math.random() * 3);
  }
  if (kind === 'concrete' || kind === 'wall') {
    ctx.strokeStyle = 'rgba(255,255,255,.07)';
    for (let y = 16; y < 64; y += 16) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(64, y); ctx.stroke(); }
    for (let x = 16; x < 64; x += 16) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 64); ctx.stroke(); }
  }
  if (kind === 'metal') {
    ctx.strokeStyle = 'rgba(255,255,255,.08)';
    for (let y = 4; y < 64; y += 8) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(64, y + 2); ctx.stroke(); }
  }
  const tex = new THREE.CanvasTexture(cv);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(2, 2);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
function realisticMat(color, kind = 'concrete', opts = {}) {
  return new THREE.MeshStandardMaterial({
    color,
    map: makeProceduralTexture(color, kind),
    roughness: opts.roughness ?? (kind === 'metal' ? 0.42 : 0.82),
    metalness: opts.metalness ?? (kind === 'metal' ? 0.65 : 0.04),
  });
}
function teamMat(color) { return new THREE.MeshStandardMaterial({ color, roughness: 0.58, metalness: 0.08 }); }
const MAT = {
  wall: realisticMat(0xcfc9bd, 'wall'),
  wallDark: realisticMat(0x9a958a, 'wall'),
  concrete: realisticMat(0x8d8f94, 'concrete'),
  dark: realisticMat(0x4b535c, 'metal', { roughness: 0.58, metalness: 0.3 }),
  glass: new THREE.MeshPhysicalMaterial({ color: 0x9fd3e8, emissive: 0x224455, emissiveIntensity: 0.18, roughness: 0.08, metalness: 0, transparent: true, opacity: 0.72 }),
  metal: realisticMat(0x7d8894, 'metal'),
  green: realisticMat(0x4e8f45, 'grass', { roughness: 0.9, metalness: 0 }),
  red: realisticMat(0xb54040, 'wall'),
  grass: realisticMat(0x4d8f3a, 'grass', { roughness: 0.95, metalness: 0 }),
  navy: realisticMat(0x53606b, 'metal', { roughness: 0.62, metalness: 0.28 }),
  // haze-grey warship plating — no texture map: extruded hull UVs are in world
  // units, so a mapped texture would tile microscopically and muddy to black
  hull: new THREE.MeshStandardMaterial({ color: 0x8a96a2, roughness: 0.5, metalness: 0.35 }),
  pad: realisticMat(0x6f7166, 'concrete'),
};

/* Local CC0 PBR architecture library. The game waits for these compact 1K
   maps before spawning a city, so every material clone inherits real diffuse,
   normal and roughness information and never depends on a runtime CDN. */
const ARCH_PBR = {
  brick: { diffuse: null, normal: null, roughness: null },
  concrete: { diffuse: null, normal: null, roughness: null },
  roof: { diffuse: null, normal: null, roughness: null },
};
const UNIT_PBR = { diffuse: null, normal: null, roughness: null, metalness: null };
function preloadArchitectureMaterials() {
  const loader = new THREE.TextureLoader();
  const root = 'assets/textures/architecture/';
  const files = [
    ['brick', 'diffuse', 'brick_diffuse.jpg', true],
    ['brick', 'normal', 'brick_normal.jpg', false],
    ['brick', 'roughness', 'brick_roughness.jpg', false],
    ['concrete', 'diffuse', 'concrete_diffuse.jpg', true],
    ['concrete', 'normal', 'concrete_normal.jpg', false],
    ['concrete', 'roughness', 'concrete_roughness.jpg', false],
    ['roof', 'diffuse', 'roof_diffuse.jpg', true],
    ['roof', 'normal', 'roof_normal.jpg', false],
    ['roof', 'roughness', 'roof_roughness.jpg', false],
  ];
  const jobs = files.map(([family, slot, file, srgb]) => new Promise(resolve => {
    loader.load(root + file, tex => {
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      tex.repeat.set(family === 'roof' ? 2.4 : 2, family === 'roof' ? 1.5 : 2);
      if (srgb) tex.colorSpace = THREE.SRGBColorSpace;
      ARCH_PBR[family][slot] = tex;
      resolve(true);
    }, undefined, () => resolve(false));
  }));
  const unitRoot = 'assets/textures/units/';
  const unitFiles = [
    ['diffuse', 'armor_diffuse.jpg', true],
    ['normal', 'armor_normal.jpg', false],
    ['roughness', 'armor_roughness.jpg', false],
    ['metalness', 'armor_metalness.jpg', false],
  ];
  for (const [slot, file, srgb] of unitFiles) jobs.push(new Promise(resolve => {
    loader.load(unitRoot + file, tex => {
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      tex.repeat.set(2.2, 2.2);
      if (srgb) tex.colorSpace = THREE.SRGBColorSpace;
      UNIT_PBR[slot] = tex;
      resolve(true);
    }, undefined, () => resolve(false));
  }));
  return Promise.all(jobs).then(() => {
    const apply = (material, family, color, normalScale = 0.45) => {
      const maps = ARCH_PBR[family];
      material.color.setHex(color);
      if (maps.diffuse) material.map = maps.diffuse;
      if (maps.normal) {
        material.normalMap = maps.normal;
        material.normalScale = new THREE.Vector2(normalScale, normalScale);
      }
      if (maps.roughness) material.roughnessMap = maps.roughness;
      material.roughness = family === 'brick' ? 0.82 : 0.86;
      material.metalness = 0;
      material.needsUpdate = true;
    };
    apply(MAT.wall, 'concrete', 0xeee9df, 0.32);
    apply(MAT.concrete, 'concrete', 0xc8c9c6, 0.52);
    apply(MAT.pad, 'concrete', 0x9a9c97, 0.45);
    apply(MAT.wallDark, 'brick', 0xd6bea2, 0.52);
    apply(MAT.red, 'brick', 0xc88d75, 0.58);
    // Extruded naval hull UVs use world units, so image maps would turn into
    // visual noise. Keep clean naval paint but retain physically based values.
    MAT.hull.color.setHex(0xaab4bc);
    MAT.hull.roughness = 0.58;
    MAT.hull.metalness = 0.42;
    MAT.hull.needsUpdate = true;
    return true;
  });
}
/* a proper gabled roof: triangular prism with its flat underside at yBase.
   Real houses have ridgelines, not pyramid points. */
function gableRoof(len, width, peakH, mat, x, yBase, z) {
  const r = width / Math.sqrt(3);
  const geo = new THREE.CylinderGeometry(r, r, len, 3, 1);
  geo.scale(peakH / r, 1, 1); // squash the vertical so the pitch looks right
  const m = new THREE.Mesh(geo, mat);
  m.rotation.z = Math.PI / 2;
  m.position.set(x, yBase + peakH / 2, z);
  m.castShadow = true;
  return m;
}

function box(w, h, d, mat, x = 0, y = 0, z = 0) {
  const smallest = Math.min(w, h, d);
  const radius = Math.min(0.16, smallest * 0.13);
  const geometry = THREE.RoundedBoxGeometry && smallest > 0.055
    ? new THREE.RoundedBoxGeometry(w, h, d, 2, radius)
    : new THREE.BoxGeometry(w, h, d);
  const m = new THREE.Mesh(geometry, mat);
  m.position.set(x, y, z); m.castShadow = true; m.receiveShadow = true;
  return m;
}
function cyl(rt, rb, h, mat, x = 0, y = 0, z = 0, seg = 10) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
  m.position.set(x, y, z); m.castShadow = true;
  return m;
}
function addFlag(g, color, x, y, z) {
  const pole = cyl(0.08, 0.08, 4, MAT.metal, x, y + 2, z, 5);
  const cloth = box(1.6, 0.9, 0.08, teamMat(color), x + 0.85, y + 3.5, z);
  pole.userData.ignoreArchitectureBounds = true;
  cloth.userData.ignoreArchitectureBounds = true;
  g.add(pole, cloth);
}

/* real ship hull: a deck-plan outline (pointed bow, rounded transom) extruded
   downward with a bevel so the sides flare like plating — no more box boats.
   Deck surface sits at the mesh's local y = 0; the hull hangs below it. */
const MAT_ANTIFOUL = new THREE.MeshStandardMaterial({ color: 0x6e3a30, roughness: 0.75, metalness: 0.15 });
function shipHull(len, width, height, mat) {
  const hl = len / 2, hw = width / 2;
  const s = new THREE.Shape();
  s.moveTo(-hl, -hw * 0.62);
  s.lineTo(hl * 0.35, -hw);                              // straight side run
  s.quadraticCurveTo(hl * 0.8, -hw * 0.75, hl, 0);       // bow curve to the stem
  s.quadraticCurveTo(hl * 0.8, hw * 0.75, hl * 0.35, hw);
  s.lineTo(-hl, hw * 0.62);
  s.quadraticCurveTo(-hl - width * 0.2, 0, -hl, -hw * 0.62); // rounded transom
  const g = new THREE.Group();
  // upper hull: haze-grey topsides
  const upper = new THREE.Mesh(new THREE.ExtrudeGeometry(s, {
    depth: height * 0.65, bevelEnabled: true,
    bevelThickness: height * 0.25, bevelSize: width * 0.06, bevelSegments: 2,
  }), mat);
  upper.geometry.rotateX(Math.PI / 2); // shape XY → world XZ, extrusion pointing down
  upper.castShadow = true; upper.receiveShadow = true;
  g.add(upper);
  // lower hull: dark-red anti-fouling paint that shows right at the waterline
  // as the ship bobs — the two-tone line real ships carry
  const lower = new THREE.Mesh(new THREE.ExtrudeGeometry(s, {
    depth: height * 0.55, bevelEnabled: true,
    bevelThickness: height * 0.3, bevelSize: width * 0.09, bevelSegments: 2,
  }), MAT_ANTIFOUL);
  lower.geometry.rotateX(Math.PI / 2);
  lower.geometry.scale(0.995, 1, 0.995);
  lower.position.y = -height * 0.6;
  lower.castShadow = true;
  g.add(lower);
  return g;
}

/* thin flat aerodynamic surface cut from a 2D outline —
   points are [x forward, z spanwise]; lies level at local y = 0 */
function finMesh(points, thickness, mat) {
  const s = new THREE.Shape();
  s.moveTo(points[0][0], points[0][1]);
  for (let i = 1; i < points.length; i++) s.lineTo(points[i][0], points[i][1]);
  const geo = new THREE.ExtrudeGeometry(s, { depth: thickness, bevelEnabled: false });
  geo.rotateX(Math.PI / 2);
  geo.translate(0, thickness / 2, 0);
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = true;
  return m;
}

/* warm lit windows, shared across all buildings */
const WINDOW_MAT = new THREE.MeshStandardMaterial({
  color: 0x294657, roughness: 0.12, metalness: 0.18,
  emissive: 0x172e3b, emissiveIntensity: 0.16,
});
const _winDummy = new THREE.Object3D();
/* wraps a box facade (center cx,cy,cz, dims w,h,d) with a grid of lit
   windows on all four sides — one InstancedMesh = one draw call */
function addWindows(g, w, h, d, cx, cy, cz, floors, cols) {
  const colsD = Math.max(1, Math.round(cols * d / w));
  const total = floors * (cols + colsD) * 2;
  const im = new THREE.InstancedMesh(new THREE.BoxGeometry(0.5, 0.62, 0.07), WINDOW_MAT, total);
  const fh = h / (floors + 0.6);
  let i = 0;
  for (let f = 0; f < floors; f++) {
    const wy = cy - h / 2 + fh * (f + 0.75);
    for (let c = 0; c < cols; c++) { // front & back
      const wx = cx - w / 2 + (w / (cols + 1)) * (c + 1);
      for (const side of [1, -1]) {
        _winDummy.position.set(wx, wy, cz + side * (d / 2 + 0.01));
        _winDummy.rotation.set(0, 0, 0);
        _winDummy.updateMatrix();
        im.setMatrixAt(i++, _winDummy.matrix);
      }
    }
    for (let c = 0; c < colsD; c++) { // left & right
      const wz = cz - d / 2 + (d / (colsD + 1)) * (c + 1);
      for (const side of [1, -1]) {
        _winDummy.position.set(cx + side * (w / 2 + 0.01), wy, wz);
        _winDummy.rotation.set(0, Math.PI / 2, 0);
        _winDummy.updateMatrix();
        im.setMatrixAt(i++, _winDummy.matrix);
      }
    }
  }
  im.count = i;
  g.add(im);
}
/* rooftop clutter — AC unit, vent drum, antenna. Flat roofs are never empty. */
function addRoofClutter(g, cx, roofY, cz, w, d) {
  g.add(box(0.95, 0.5, 0.7, MAT.metal, cx + w * 0.24, roofY + 0.25, cz - d * 0.2)); // AC unit
  g.add(box(0.8, 0.06, 0.55, MAT.dark, cx + w * 0.24, roofY + 0.53, cz - d * 0.2)); // AC grille
  g.add(cyl(0.26, 0.3, 0.45, MAT.wallDark, cx - w * 0.24, roofY + 0.22, cz + d * 0.22, 8)); // vent drum
  g.add(box(0.5, 0.07, 0.5, MAT.dark, cx - w * 0.24, roofY + 0.47, cz + d * 0.22)); // vent cap
  g.add(cyl(0.035, 0.035, 1.15, MAT.metal, cx + w * 0.3, roofY + 0.57, cz + d * 0.28, 4)); // antenna
  g.add(box(0.35, 0.18, 0.06, MAT.metal, cx + w * 0.3, roofY + 1.0, cz + d * 0.28)); // antenna panel
}

const ARCH_OPEN_STRUCTURES = new Set([
  'park', 'farm', 'airfield', 'helipad', 'shipyard', 'port', 'offshoreRig',
  'fishingWharf', 'solarFarm', 'extractor', 'samSite',
]);
const ARCH_RESIDENTIAL = new Set([
  'workerHouse', 'housing', 'residential', 'cottage', 'apartments', 'luxuryVillas',
]);
const ARCH_INDUSTRIAL = new Set([
  'foodDepot', 'warehouse', 'powerPlant', 'nuclearReactor', 'chipFab',
  'tankFactory', 'ammoDepot', 'oilRefinery', 'waterTreatment', 'mountainMine',
]);
const ARCH_MILITARY = new Set([
  'hq', 'barracks', 'missileSilo', 'commandCenter', 'bunker', 'intelAgency',
]);
const ARCH_PALETTES = {
  residential: [
    { wall: 0xf0e4d2, brick: 0xd5b69a, concrete: 0xc9c2b7 },
    { wall: 0xdde6e4, brick: 0xb9aaa0, concrete: 0xbec6c5 },
    { wall: 0xead9cd, brick: 0xc9947e, concrete: 0xc7b8aa },
    { wall: 0xe6e1cf, brick: 0xbca88d, concrete: 0xc7c3b7 },
  ],
  civic: [
    { wall: 0xe9e4d8, brick: 0xcbb99f, concrete: 0xc9c7c0 },
    { wall: 0xd9e2e5, brick: 0xb6a999, concrete: 0xb9c2c5 },
    { wall: 0xeee1c8, brick: 0xc7aa83, concrete: 0xc9c0b0 },
  ],
  industrial: [
    { wall: 0xc9ced0, brick: 0xb28e78, concrete: 0x9fa7aa },
    { wall: 0xbfc8c3, brick: 0xa98772, concrete: 0x929b98 },
    { wall: 0xd0c9bb, brick: 0xad8973, concrete: 0xa7a39a },
  ],
  military: [
    { wall: 0xbfc2b4, brick: 0xa58f79, concrete: 0x8f9489 },
    { wall: 0xb7bec0, brick: 0x9c8674, concrete: 0x878f91 },
    { wall: 0xc5baa6, brick: 0xa98b72, concrete: 0x999387 },
  ],
};
function architectureStyle(key) {
  if (ARCH_RESIDENTIAL.has(key)) return 'residential';
  if (ARCH_INDUSTRIAL.has(key)) return 'industrial';
  if (ARCH_MILITARY.has(key)) return 'military';
  return 'civic';
}
function architectureRand(seed, n) {
  const x = Math.sin(seed * 91.17 + n * 47.23) * 43758.5453;
  return x - Math.floor(x);
}
function architectureBounds(g) {
  const ignored = [];
  g.traverse(o => {
    if (o.userData.ignoreArchitectureBounds && o.visible) {
      ignored.push(o); o.visible = false;
    }
  });
  g.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(g);
  for (const o of ignored) o.visible = true;
  return bounds;
}
function architectureRoofY(g, bounds) {
  const total = bounds.getSize(new THREE.Vector3());
  let roofY = bounds.min.y + total.y * 0.72;
  g.updateMatrixWorld(true);
  g.traverse(o => {
    if (!o.isMesh || o.userData.ignoreArchitectureBounds) return;
    const b = new THREE.Box3().setFromObject(o);
    const s = b.getSize(new THREE.Vector3());
    if (s.x < Math.max(0.8, total.x * 0.45) || s.z < Math.max(0.8, total.z * 0.45)) return;
    roofY = Math.max(roofY, b.max.y);
  });
  return roofY;
}
function applyArchitecturePalette(g, key, seed) {
  const style = architectureStyle(key);
  const palettes = ARCH_PALETTES[style];
  const palette = palettes[Math.abs(seed) % palettes.length];
  const roles = new Map([
    [MAT.wall, palette.wall], [MAT.wallDark, palette.brick], [MAT.red, palette.brick],
    [MAT.concrete, palette.concrete], [MAT.pad, palette.concrete],
  ]);
  const clones = new Map();
  const variant = material => {
    if (!roles.has(material)) return material;
    if (clones.has(material)) return clones.get(material);
    const m = material.clone();
    m.color.setHex(roles.get(material));
    m.color.offsetHSL((architectureRand(seed, 71) - 0.5) * 0.025, -0.025, (architectureRand(seed, 72) - 0.5) * 0.055);
    clones.set(material, m);
    return m;
  };
  g.traverse(o => {
    if (!o.isMesh) return;
    o.material = Array.isArray(o.material) ? o.material.map(variant) : variant(o.material);
  });
}
function addEntranceArchitecture(g, bounds, style, color, seed) {
  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const groundY = bounds.min.y;
  const doorW = clamp(size.x * 0.17, 0.85, style === 'industrial' ? 1.8 : 1.35);
  const doorH = clamp(size.y * 0.34, 1.45, style === 'industrial' ? 2.7 : 2.15);
  const frontZ = bounds.max.z + 0.045;
  const doorMat = new THREE.MeshPhysicalMaterial({
    color: style === 'residential' ? 0x49382e : 0x24323b,
    roughness: style === 'residential' ? 0.52 : 0.16,
    metalness: style === 'residential' ? 0.05 : 0.38,
    clearcoat: 0.18,
  });
  g.add(box(doorW, doorH, 0.12, doorMat, center.x, groundY + doorH * 0.5 + 0.08, frontZ));
  const frameMat = style === 'residential' ? MAT.wallDark : MAT.metal;
  g.add(box(0.12, doorH + 0.24, 0.18, frameMat, center.x - doorW * 0.56, groundY + doorH * 0.5 + 0.08, frontZ + 0.01));
  g.add(box(0.12, doorH + 0.24, 0.18, frameMat, center.x + doorW * 0.56, groundY + doorH * 0.5 + 0.08, frontZ + 0.01));
  g.add(box(doorW + 0.28, 0.14, 0.18, frameMat, center.x, groundY + doorH + 0.16, frontZ + 0.01));
  const canopyDepth = 0.5 + architectureRand(seed, 12) * 0.35;
  const canopy = box(doorW * 1.65, 0.12, canopyDepth, style === 'residential' ? shingleMat(0x7b4937) : MAT.metal,
    center.x, groundY + doorH + 0.38, frontZ + canopyDepth * 0.4);
  canopy.rotation.x = style === 'residential' ? -0.08 : 0;
  g.add(canopy);
  g.add(box(doorW * 1.9, 0.12, 0.72, MAT.concrete, center.x, groundY + 0.06, frontZ + 0.31));

  const lampMat = new THREE.MeshStandardMaterial({
    color: 0xffdfaa, emissive: 0xffa94d, emissiveIntensity: 1.05, roughness: 0.35,
  });
  for (const side of [-1, 1])
    g.add(box(0.16, 0.22, 0.08, lampMat, center.x + side * doorW * 0.78, groundY + doorH * 0.72, frontZ + 0.1));
  const accent = new THREE.MeshStandardMaterial({ color, roughness: 0.56, metalness: 0.12 });
  g.add(box(Math.min(size.x * 0.5, 3.2), 0.16, 0.1, accent,
    center.x, Math.min(bounds.max.y - 0.3, groundY + doorH + 0.8), frontZ + 0.07));
}
function addResidentialBalconies(g, bounds, seed) {
  const size = bounds.getSize(new THREE.Vector3());
  if (size.y < 4.3) return;
  const center = bounds.getCenter(new THREE.Vector3());
  const count = Math.min(3, Math.max(1, Math.floor(size.y / 3.2) - 1));
  const width = Math.min(size.x * (0.44 + architectureRand(seed, 18) * 0.18), 3.8);
  for (let i = 0; i < count; i++) {
    const y = bounds.min.y + 2.7 + i * Math.min(2.4, (size.y - 3) / Math.max(count, 1));
    const z = bounds.max.z + 0.34;
    g.add(box(width, 0.12, 0.72, MAT.concrete, center.x, y, z));
    g.add(box(width, 0.08, 0.06, MAT.metal, center.x, y + 0.62, z + 0.32));
    for (const side of [-1, 1])
      g.add(box(0.06, 0.62, 0.06, MAT.metal, center.x + side * width * 0.46, y + 0.32, z + 0.32));
  }
}
function addRoofArchitecture(g, bounds, key, style, seed) {
  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const roofY = architectureRoofY(g, bounds) + 0.04;
  const units = style === 'industrial' ? 3 : 1 + Math.floor(architectureRand(seed, 1) * 3);
  for (let i = 0; i < units; i++) {
    const w = 0.55 + architectureRand(seed, i + 3) * 0.65;
    const d = 0.45 + architectureRand(seed, i + 8) * 0.55;
    const px = center.x + (architectureRand(seed, i + 14) - 0.5) * Math.max(0.5, size.x * 0.46);
    const pz = center.z + (architectureRand(seed, i + 22) - 0.5) * Math.max(0.5, size.z * 0.4);
    g.add(box(w, 0.32 + architectureRand(seed, i + 30) * 0.28, d, i % 2 ? MAT.metal : MAT.wallDark, px, roofY + 0.2, pz));
  }
  if (seed % 3 === 0 && !['bunker', 'mountainMine', 'extractor'].includes(key)) {
    const solar = new THREE.MeshStandardMaterial({ color: 0x244a67, roughness: 0.22, metalness: 0.38 });
    for (let i = 0; i < 2; i++) {
      const panel = box(Math.min(1.5, size.x * 0.24), 0.07, 0.75, solar,
        center.x + (i ? 0.85 : -0.85), roofY + 0.35, center.z);
      panel.rotation.x = -0.28;
      g.add(panel);
    }
  }
  // Real facades need rainwater management: subtle downpipes at two corners.
  if (size.y > 2.2) for (const side of [-1, 1]) {
    const pipe = cyl(0.035, 0.035, size.y * 0.78, MAT.metal,
      center.x + side * size.x * 0.43, bounds.min.y + size.y * 0.39, bounds.max.z + 0.055, 6);
    g.add(pipe);
  }
}
function personalizeArchitecture(g, key, color, seed, authored = false) {
  if (!seed) return;
  const bounds = architectureBounds(g);
  const size = bounds.getSize(new THREE.Vector3());
  if (!Number.isFinite(bounds.max.y) || size.x < 1 || size.y < 0.5) return;
  const style = architectureStyle(key);
  if (!ARCH_OPEN_STRUCTURES.has(key)) {
    addEntranceArchitecture(g, bounds, style, color, seed);
    if (authored) {
      const floors = clamp(Math.floor(size.y / 2.15), 1, 4);
      const cols = clamp(Math.floor(size.x / 1.45), 2, 5);
      addWindows(g, size.x * 0.88, size.y * 0.78, size.z * 0.88,
        bounds.getCenter(new THREE.Vector3()).x,
        bounds.min.y + size.y * 0.45,
        bounds.getCenter(new THREE.Vector3()).z,
        floors, cols);
    }
    if (style === 'residential') addResidentialBalconies(g, bounds, seed);
    addRoofArchitecture(g, bounds, key, style, seed);
  }
  applyArchitecturePalette(g, key, seed);
}

/* ============================================================
   Rebuilt architecture system. These are complete buildings, not decorative
   layers placed over the old low-poly city models. Dimensions are in game
   metres and every facade element belongs to the same local coordinate frame.
   ============================================================ */
const REALISTIC_BUILDING_PROFILES = {
  hq:            { w: 10.5, d: 7.8, floors: 3, fh: 2.65, style: 'civic', roof: 'flat', wing: true },
  villageCenter: { w: 6.2,  d: 4.8, floors: 1, fh: 2.7,  style: 'house', roof: 'gable', wing: true },
  cityCenter:    { w: 9.4,  d: 7.0, floors: 3, fh: 2.55, style: 'civic', roof: 'hip', wing: true },
  workerHouse:   { w: 5.8,  d: 4.6, floors: 1, fh: 2.7,  style: 'house', roof: 'gable', wing: true },
  housing:       { w: 6.8,  d: 5.8, floors: 4, fh: 2.25, style: 'apartment', roof: 'flat', balconies: true },
  residential:   { w: 9.0,  d: 6.3, floors: 3, fh: 2.35, style: 'apartment', roof: 'flat', balconies: true, wing: true },
  foodDepot:     { w: 7.0,  d: 5.4, floors: 1, fh: 3.5,  style: 'industrial', roof: 'saw' },
  warehouse:     { w: 8.5,  d: 6.0, floors: 1, fh: 4.0,  style: 'industrial', roof: 'saw' },
  market:        { w: 7.4,  d: 5.5, floors: 2, fh: 2.3,  style: 'retail', roof: 'gable' },
  cottage:       { w: 4.5,  d: 3.8, floors: 1, fh: 2.55, style: 'house', roof: 'gable', wing: true },
  apartments:    { w: 6.2,  d: 5.6, floors: 5, fh: 2.15, style: 'apartment', roof: 'flat', balconies: true },
  luxuryVillas:  { w: 8.0,  d: 5.8, floors: 2, fh: 2.55, style: 'modern', roof: 'flat', balconies: true, wing: true },
  techPark:      { w: 7.4,  d: 6.0, floors: 3, fh: 2.45, style: 'modern', roof: 'flat', wing: true },
  chipFab:       { w: 8.6,  d: 6.6, floors: 2, fh: 2.8,  style: 'industrial', roof: 'flat' },
  bank:          { w: 6.0,  d: 5.0, floors: 2, fh: 2.45, style: 'civic', roof: 'flat' },
  cityHall:      { w: 8.4,  d: 6.2, floors: 2, fh: 2.6,  style: 'civic', roof: 'hip', wing: true },
  school:        { w: 7.4,  d: 5.2, floors: 2, fh: 2.4,  style: 'civic', roof: 'gable', wing: true },
  library:       { w: 6.0,  d: 4.7, floors: 2, fh: 2.45, style: 'civic', roof: 'flat' },
  university:    { w: 9.2,  d: 6.8, floors: 3, fh: 2.45, style: 'civic', roof: 'hip', wing: true },
  hospital:      { w: 7.8,  d: 6.0, floors: 3, fh: 2.45, style: 'modern', roof: 'flat', wing: true },
  policeStation: { w: 6.0,  d: 4.8, floors: 2, fh: 2.4,  style: 'civic', roof: 'flat' },
  stadium:       { w: 9.5,  d: 8.0, floors: 2, fh: 2.8,  style: 'civic', roof: 'flat' },
  tvStation:     { w: 5.6,  d: 4.6, floors: 3, fh: 2.35, style: 'modern', roof: 'flat' },
  intelAgency:   { w: 6.0,  d: 5.6, floors: 4, fh: 2.3,  style: 'military', roof: 'flat' },
  ammoDepot:     { w: 5.4,  d: 4.8, floors: 1, fh: 3.1,  style: 'military', roof: 'gable' },
  barracks:      { w: 7.5,  d: 5.2, floors: 2, fh: 2.35, style: 'military', roof: 'gable', wing: true },
  tankFactory:   { w: 9.4,  d: 7.0, floors: 1, fh: 4.3,  style: 'industrial', roof: 'saw' },
  missileSilo:   { w: 6.5,  d: 5.8, floors: 2, fh: 2.55, style: 'military', roof: 'flat' },
  commandCenter: { w: 6.5,  d: 5.8, floors: 3, fh: 2.35, style: 'military', roof: 'flat' },
  bunker:        { w: 4.8,  d: 4.5, floors: 1, fh: 2.2,  style: 'military', roof: 'flat' },
  oilRefinery:   { w: 7.5,  d: 6.5, floors: 1, fh: 3.5,  style: 'industrial', roof: 'flat' },
  mountainMine:  { w: 5.2,  d: 4.8, floors: 1, fh: 3.2,  style: 'industrial', roof: 'gable' },
  waterTreatment:{ w: 6.5,  d: 5.5, floors: 2, fh: 2.35, style: 'industrial', roof: 'flat' },
  museum:        { w: 7.0,  d: 5.6, floors: 2, fh: 2.6,  style: 'civic', roof: 'hip' },
  courthouse:    { w: 6.5,  d: 5.2, floors: 2, fh: 2.6,  style: 'civic', roof: 'hip' },
};
const REALISTIC_PALETTES = {
  house: [
    [0xf6f0e7, 0xffeee7, 0xe8e5de], [0xe9f0ef, 0xf5eee3, 0xdce3e2],
    [0xf1e6d8, 0xffe4d7, 0xe2d8cc], [0xe8e6dc, 0xf1e6d8, 0xd8d7d0],
  ],
  apartment: [[0xf2f1ec, 0xffeee7, 0xd9dcdb], [0xe7edee, 0xf4e7dc, 0xd3d9da], [0xeee8df, 0xffe5dc, 0xd8d0c7]],
  civic: [[0xf4f0e5, 0xffeee5, 0xddd8cc], [0xe9ecec, 0xf9e9df, 0xd4d9d8], [0xf0e6d5, 0xffeadf, 0xd8cdbd]],
  modern: [[0xe8eef0, 0xf3ebe4, 0xcdd5d8], [0xf1f1ec, 0xffe8df, 0xd6d5cf], [0xe1e9e8, 0xf5e6de, 0xc9d3d1]],
  retail: [[0xf1e7d7, 0xffe6d8, 0xd8c8b5], [0xe8ece5, 0xf8e7dd, 0xcbd2c9]],
  industrial: [[0xdfe2df, 0xffe4d8, 0xbfc5c3], [0xe4ded2, 0xffe9df, 0xc7c2b8], [0xd7dedf, 0xf5e3da, 0xb9c2c4]],
  military: [[0xd8ddd2, 0xf1ded5, 0xb8beb3], [0xd4dadb, 0xeadbd4, 0xb4bcbd], [0xded7ca, 0xf0ddd3, 0xc0bbb0]],
};
function realisticBuildingMaterial(family, tint, normalStrength = 0.32) {
  const maps = ARCH_PBR[family === 'brick' ? 'brick' : 'concrete'];
  const m = new THREE.MeshStandardMaterial({
    color: tint,
    map: maps.diffuse,
    normalMap: maps.normal,
    roughnessMap: maps.roughness,
    roughness: family === 'brick' ? 0.84 : 0.78,
    metalness: 0,
  });
  m.normalScale = new THREE.Vector2(normalStrength, normalStrength);
  return m;
}
function addRealisticWindows(g, w, h, d, floors, style, seed) {
  const cols = clamp(Math.round(w / (style === 'industrial' ? 2.3 : 1.45)), 2, 7);
  const sideCols = clamp(Math.round(d / 1.65), 1, 5);
  const paneW = style === 'modern' ? 0.82 : style === 'military' ? 0.48 : 0.68;
  const paneH = style === 'industrial' ? 0.72 : 0.82;
  const transforms = [];
  const dummy = new THREE.Object3D();
  const add = (x, y, z, ry) => {
    dummy.position.set(x, y, z); dummy.rotation.set(0, ry, 0); dummy.scale.set(1, 1, 1); dummy.updateMatrix();
    transforms.push(dummy.matrix.clone());
  };
  for (let f = 0; f < floors; f++) {
    const y = 0.85 + f * (h / floors) + Math.min(0.55, h / floors * 0.22);
    for (let c = 0; c < cols; c++) {
      const x = -w * 0.5 + (w / (cols + 1)) * (c + 1);
      if (!(f === 0 && Math.abs(x) < 0.85)) add(x, y, d * 0.5 + 0.055, 0);
      add(x, y, -d * 0.5 - 0.055, Math.PI);
    }
    for (let c = 0; c < sideCols; c++) {
      const z = -d * 0.5 + (d / (sideCols + 1)) * (c + 1);
      add(w * 0.5 + 0.055, y, z, Math.PI / 2);
      add(-w * 0.5 - 0.055, y, z, -Math.PI / 2);
    }
  }
  const glass = new THREE.MeshPhysicalMaterial({
    color: style === 'modern' ? 0x6e91a5 : 0x294354,
    emissive: 0x172a36, emissiveIntensity: 0.18,
    roughness: 0.12, metalness: 0.18, clearcoat: 0.6,
  });
  const frame = new THREE.MeshStandardMaterial({ color: style === 'industrial' ? 0x5f676a : 0xd9dcda, roughness: 0.38, metalness: 0.18 });
  const frameMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(paneW + 0.16, paneH + 0.16, 0.065), frame, transforms.length);
  const paneMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(paneW, paneH, 0.085), glass, transforms.length);
  transforms.forEach((matrix, i) => { frameMesh.setMatrixAt(i, matrix); paneMesh.setMatrixAt(i, matrix); });
  frameMesh.castShadow = true; paneMesh.castShadow = true;
  g.add(frameMesh, paneMesh);
}
function addRealisticEntrance(g, w, d, style, color) {
  const industrial = style === 'industrial';
  const doorW = industrial ? 1.55 : 1.05;
  const doorH = industrial ? 2.5 : 1.95;
  const z = d * 0.5 + 0.075;
  const door = new THREE.MeshPhysicalMaterial({ color: industrial ? 0x3d474b : 0x4e392d, roughness: 0.42, metalness: industrial ? 0.35 : 0.04, clearcoat: 0.22 });
  const trim = new THREE.MeshStandardMaterial({ color: 0xd9d8d1, roughness: 0.5, metalness: 0.04 });
  g.add(box(doorW + 0.2, doorH + 0.22, 0.12, trim, 0, doorH * 0.5 + 0.08, z));
  g.add(box(doorW, doorH, 0.15, door, 0, doorH * 0.5 + 0.08, z + 0.035));
  const canopyMat = new THREE.MeshStandardMaterial({ color: 0x596166, roughness: 0.42, metalness: 0.45 });
  g.add(box(doorW * 1.7, 0.12, 0.72, canopyMat, 0, doorH + 0.42, z + 0.29));
  g.add(box(doorW * 2.0, 0.12, 0.7, MAT.concrete, 0, 0.06, z + 0.28));
  const plaque = new THREE.MeshStandardMaterial({ color: new THREE.Color(color).lerp(new THREE.Color(0x48525a), 0.68), roughness: 0.52, metalness: 0.16 });
  g.add(box(Math.min(2.4, w * 0.38), 0.15, 0.08, plaque, 0, doorH + 0.72, z + 0.03));
}
function addFlatRoof(g, w, d, y, wallMat, seed) {
  const slab = new THREE.MeshStandardMaterial({ color: 0x777d7e, roughness: 0.82, metalness: 0.04 });
  g.add(box(w + 0.16, 0.16, d + 0.16, slab, 0, y + 0.08, 0));
  const parapetH = 0.34;
  g.add(box(w + 0.28, parapetH, 0.18, wallMat, 0, y + parapetH * 0.5, d * 0.5));
  g.add(box(w + 0.28, parapetH, 0.18, wallMat, 0, y + parapetH * 0.5, -d * 0.5));
  g.add(box(0.18, parapetH, d, wallMat, w * 0.5, y + parapetH * 0.5, 0));
  g.add(box(0.18, parapetH, d, wallMat, -w * 0.5, y + parapetH * 0.5, 0));
  const hvac = new THREE.MeshStandardMaterial({ color: 0x8b9294, roughness: 0.62, metalness: 0.48 });
  const off = architectureRand(seed, 91) * 0.8 - 0.4;
  g.add(box(1.05, 0.55, 0.75, hvac, w * 0.22 + off, y + 0.36, -d * 0.18));
  g.add(box(0.86, 0.06, 0.58, MAT.dark, w * 0.22 + off, y + 0.66, -d * 0.18));
}
function addRealisticRoof(g, p, h, wallMat, seed) {
  const roofTints = [0x8a4433, 0x6e4a3d, 0x54575b, 0x76645a];
  const roofMat = shingleMat(roofTints[Math.abs(seed) % roofTints.length]);
  if (p.roof === 'gable') {
    g.add(gableRoof(p.w + 0.34, p.d + 0.48, Math.min(1.65, p.d * 0.28), roofMat, 0, h, 0));
  } else if (p.roof === 'hip') {
    const roof = new THREE.Mesh(new THREE.ConeGeometry(1, 1.45, 4), roofMat);
    roof.rotation.y = Math.PI / 4; roof.scale.set(p.w * 0.72, 1, p.d * 0.72);
    roof.position.y = h + 0.72; roof.castShadow = true; g.add(roof);
  } else if (p.roof === 'saw') {
    const bays = 3;
    for (let i = 0; i < bays; i++) {
      const bay = gableRoof(p.w / bays + 0.18, p.d + 0.32, 0.75, roofMat,
        -p.w * 0.5 + (i + 0.5) * (p.w / bays), h, 0);
      g.add(bay);
    }
  } else addFlatRoof(g, p.w, p.d, h, wallMat, seed);
}
function addStyleDetails(g, p, h, wallMat, trimMat, color, seed) {
  if (p.wing) {
    const side = seed % 2 ? 1 : -1;
    const wingW = p.w * 0.34, wingD = p.d * 0.58, wingH = Math.min(h * 0.68, p.fh * Math.max(1, p.floors - 1));
    g.add(box(wingW, wingH, wingD, wallMat, side * (p.w * 0.5 + wingW * 0.32), wingH * 0.5, -p.d * 0.08));
    if (p.roof === 'gable') g.add(gableRoof(wingW + 0.24, wingD + 0.3, 0.72, shingleMat(0x70463a), side * (p.w * 0.5 + wingW * 0.32), wingH, -p.d * 0.08));
  }
  if (p.style === 'civic') {
    const porticoW = Math.min(p.w * 0.52, 4.5), z = p.d * 0.5 + 0.5;
    g.add(box(porticoW, 0.2, 1.0, trimMat, 0, 2.8, z - 0.12));
    for (const x of [-porticoW * 0.38, 0, porticoW * 0.38]) g.add(cyl(0.13, 0.16, 2.7, trimMat, x, 1.35, z, 12));
  }
  if (p.balconies) {
    const count = Math.min(3, p.floors - 1);
    for (let i = 0; i < count; i++) {
      const y = p.fh * (i + 1) + 0.35;
      const bw = Math.min(p.w * 0.48, 3.6), z = p.d * 0.5 + 0.36;
      g.add(box(bw, 0.12, 0.7, trimMat, 0, y, z));
      const rail = new THREE.MeshStandardMaterial({ color: 0x596268, roughness: 0.36, metalness: 0.55 });
      g.add(box(bw, 0.07, 0.06, rail, 0, y + 0.62, z + 0.3));
      for (const x of [-bw * 0.45, -bw * 0.15, bw * 0.15, bw * 0.45]) g.add(box(0.045, 0.6, 0.045, rail, x, y + 0.32, z + 0.3));
    }
  }
  if (p.style === 'industrial') {
    const shutter = new THREE.MeshStandardMaterial({ color: 0x626a6d, roughness: 0.58, metalness: 0.5 });
    for (const x of [-p.w * 0.24, p.w * 0.24]) {
      g.add(box(Math.min(2.0, p.w * 0.22), 2.45, 0.14, shutter, x, 1.25, p.d * 0.5 + 0.08));
      for (let y = 0.35; y < 2.35; y += 0.32) g.add(box(Math.min(1.85, p.w * 0.2), 0.035, 0.16, MAT.dark, x, y, p.d * 0.5 + 0.17));
    }
  }
  if (p.style === 'military') {
    const reinforced = new THREE.MeshStandardMaterial({ color: 0x6f776f, roughness: 0.82, metalness: 0.08 });
    g.add(box(p.w + 0.18, 0.38, p.d + 0.18, reinforced, 0, 0.19, 0));
    g.add(cyl(0.035, 0.04, 2.4, MAT.dark, p.w * 0.35, h + 1.2, -p.d * 0.25, 6));
  }
}
function buildRealisticStadium(color, seed) {
  const g = new THREE.Group();
  const concrete = realisticBuildingMaterial('concrete', 0xe1e2de, 0.28);
  const seats = new THREE.MeshStandardMaterial({ color: 0x67747c, roughness: 0.72, metalness: 0.08 });
  const field = new THREE.MeshStandardMaterial({ color: 0x477746, roughness: 0.96 });
  const accent = new THREE.MeshStandardMaterial({ color: new THREE.Color(color).lerp(new THREE.Color(0x687178), 0.72), roughness: 0.56, metalness: 0.1 });
  const pitch = new THREE.Mesh(new THREE.CapsuleGeometry(2.35, 4.2, 8, 20), field);
  pitch.rotation.x = Math.PI / 2; pitch.scale.z = 0.78; pitch.position.y = 0.13; pitch.receiveShadow = true; g.add(pitch);
  for (let level = 0; level < 3; level++) {
    const bowl = new THREE.Mesh(new THREE.TorusGeometry(3.55 + level * 0.42, 0.34, 8, 52), level === 2 ? concrete : seats);
    bowl.rotation.x = Math.PI / 2; bowl.scale.x = 1.32; bowl.position.y = 0.48 + level * 0.48;
    bowl.castShadow = bowl.receiveShadow = true; g.add(bowl);
  }
  for (const [x, z] of [[-5.0, -3.2], [5.0, -3.2], [-5.0, 3.2], [5.0, 3.2]]) {
    g.add(cyl(0.07, 0.1, 5.2, MAT.metal, x, 2.6, z, 8));
    const lamps = box(1.05, 0.5, 0.1, accent, x, 5.05, z); lamps.rotation.z = x < 0 ? -0.12 : 0.12; g.add(lamps);
  }
  g.add(box(2.7, 1.7, 1.1, concrete, 0, 0.85, 4.75));
  g.add(box(1.3, 1.25, 0.09, MAT.glass, 0, 0.75, 5.32));
  g.userData.rebuiltArchitecture = true;
  return g;
}
function addBuildingIdentity(g, key, p, h, wallMat, trimMat, color, seed) {
  const metal = new THREE.MeshStandardMaterial({ color: 0x687277, roughness: 0.48, metalness: 0.58 });
  const darkMetal = new THREE.MeshStandardMaterial({ color: 0x414a4f, roughness: 0.52, metalness: 0.6 });
  const glass = new THREE.MeshPhysicalMaterial({ color: 0x547b90, roughness: 0.1, metalness: 0.16, clearcoat: 0.65 });
  const accent = new THREE.MeshStandardMaterial({ color: new THREE.Color(color).lerp(new THREE.Color(0x697279), 0.7), roughness: 0.5, metalness: 0.12 });
  const front = p.d * 0.5;
  switch (key) {
    case 'hq':
      g.add(box(3.8, 1.7, 0.12, glass, 0, 1.0, front + 0.09));
      addFlag(g, color, -p.w * 0.28, h + 0.2, 0);
      break;
    case 'workerHouse': case 'cottage': {
      const chimney = realisticBuildingMaterial('brick', 0xd7b6a1, 0.35);
      g.add(box(0.48, 1.45, 0.48, chimney, p.w * 0.28, h + 0.6, -p.d * 0.18));
      g.add(box(1.45, 0.08, 0.62, trimMat, -p.w * 0.23, 0.12, front + 0.3));
      break;
    }
    case 'market':
      for (const x of [-p.w * 0.3, 0, p.w * 0.3]) {
        const awning = box(1.55, 0.12, 0.85, accent, x, 2.05, front + 0.35); awning.rotation.x = -0.18; g.add(awning);
      }
      break;
    case 'luxuryVillas':
      g.add(box(2.8, 1.65, 0.12, glass, -p.w * 0.21, 1.15, front + 0.08));
      g.add(box(2.5, 0.09, 1.3, trimMat, p.w * 0.23, 0.12, front + 0.55));
      break;
    case 'techPark':
      g.add(box(1.45, h - 0.55, 0.11, glass, p.w * 0.28, h * 0.5, front + 0.08));
      g.add(box(0.12, h + 0.15, 0.18, metal, p.w * 0.28, h * 0.5, front + 0.14));
      break;
    case 'bank':
      g.add(box(p.w * 0.62, 0.28, 0.7, trimMat, 0, h + 0.28, front - 0.3));
      break;
    case 'cityHall': {
      g.add(box(2.05, 2.1, 1.9, wallMat, 0, h + 0.95, 0));
      const clock = cyl(0.48, 0.48, 0.08, new THREE.MeshStandardMaterial({ color: 0xe8e4d8, roughness: 0.62 }), 0, h + 1.15, front + 0.03, 24);
      clock.rotation.x = Math.PI / 2; g.add(clock);
      addFlag(g, color, 0, h + 1.9, 0);
      break;
    }
    case 'library':
      g.add(box(2.4, 2.6, 0.14, glass, 0, 1.4, front + 0.1));
      break;
    case 'university': {
      g.add(cyl(0.9, 1.15, 0.75, wallMat, 0, h + 0.38, 0, 16));
      const cupola = new THREE.Mesh(new THREE.ConeGeometry(1.15, 1.1, 16), shingleMat(0x6b5549)); cupola.position.y = h + 1.28; cupola.castShadow = true; g.add(cupola);
      break;
    }
    case 'hospital': {
      const red = new THREE.MeshStandardMaterial({ color: 0xb84a46, roughness: 0.52 });
      g.add(box(0.32, 1.45, 0.1, red, p.w * 0.32, h - 1.25, front + 0.1));
      g.add(box(1.45, 0.32, 0.1, red, p.w * 0.32, h - 1.25, front + 0.11));
      g.add(box(3.1, 0.15, 1.1, trimMat, 0, 2.42, front + 0.52));
      break;
    }
    case 'policeStation':
      for (const x of [-1.55, 1.55]) g.add(box(2.0, 1.65, 0.12, darkMetal, x, 0.92, front + 0.09));
      g.add(cyl(0.04, 0.05, 2.5, metal, p.w * 0.3, h + 1.25, -p.d * 0.2, 6));
      break;
    case 'tvStation':
      g.add(cyl(0.09, 0.12, 4.8, metal, 0, h + 2.4, 0, 8));
      for (let y = h + 1.0; y < h + 4.3; y += 0.75) g.add(box(1.25, 0.05, 0.05, darkMetal, 0, y, 0));
      break;
    case 'intelAgency': case 'commandCenter': {
      const dish = new THREE.Mesh(new THREE.SphereGeometry(0.8, 18, 9, 0, Math.PI * 2, 0, Math.PI / 2), metal);
      dish.scale.z = 0.22; dish.rotation.x = -0.55; dish.position.set(p.w * 0.2, h + 0.8, -p.d * 0.14); dish.castShadow = true; g.add(dish);
      break;
    }
    case 'foodDepot': case 'warehouse': case 'tankFactory':
      g.add(box(p.w * 0.72, 0.28, 1.15, trimMat, 0, 0.22, front + 0.55));
      for (const x of [-p.w * 0.28, p.w * 0.28]) g.add(cyl(0.22, 0.22, 1.15, metal, x, h + 0.6, -p.d * 0.18, 12));
      break;
    case 'chipFab':
      for (const x of [-2.2, 0, 2.2]) {
        g.add(box(1.35, 0.65, 1.15, metal, x, h + 0.38, -p.d * 0.15));
        g.add(cyl(0.18, 0.18, 1.4, metal, x, h + 1.3, -p.d * 0.15, 12));
      }
      break;
    case 'missileSilo': {
      const hatch = cyl(1.45, 1.45, 0.24, darkMetal, p.w * 0.18, h + 0.22, 0, 28); g.add(hatch);
      g.add(box(2.7, 0.12, 0.1, accent, p.w * 0.18, h + 0.35, 0));
      break;
    }
    case 'bunker': {
      const earth = new THREE.MeshStandardMaterial({ color: 0x65725b, roughness: 0.98 });
      const berm = new THREE.Mesh(new THREE.SphereGeometry(3.7, 24, 10, 0, Math.PI * 2, 0, Math.PI / 2), earth);
      berm.scale.set(1.3, 0.58, 1.15); berm.position.y = -0.05; berm.receiveShadow = true; g.add(berm);
      g.add(box(2.0, 1.3, 0.14, darkMetal, 0, 0.75, front + 0.1));
      break;
    }
    case 'oilRefinery':
      for (const [x, z, s] of [[-3.8, -1.8, 1.0], [3.8, 1.7, 0.82], [3.5, -2.0, 0.7]]) {
        g.add(cyl(0.92 * s, 0.92 * s, 3.3 * s, metal, x, 1.65 * s, z, 20));
        g.add(cyl(0.96 * s, 0.96 * s, 0.1, darkMetal, x, 3.33 * s, z, 20));
      }
      g.add(box(8.5, 0.14, 0.14, accent, 0, 1.2, -p.d * 0.65));
      break;
    case 'mountainMine': {
      const rock = new THREE.MeshStandardMaterial({ color: 0x77736b, roughness: 0.96 });
      for (const [x, y, s] of [[-2.2, 1.2, 1.8], [0, 1.55, 2.1], [2.2, 1.15, 1.65]]) {
        const boulder = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 1), rock); boulder.scale.y = 0.8; boulder.position.set(x, y, -front * 0.9); boulder.castShadow = true; g.add(boulder);
      }
      g.add(box(2.5, 2.1, 0.18, darkMetal, 0, 1.08, front + 0.1));
      break;
    }
    case 'waterTreatment':
      for (const x of [-3.7, 3.7]) {
        g.add(cyl(1.55, 1.7, 0.55, trimMat, x, 0.28, -0.5, 24));
        g.add(cyl(1.38, 1.38, 0.06, glass, x, 0.59, -0.5, 24));
        g.add(box(2.45, 0.08, 0.08, metal, x, 0.69, -0.5));
      }
      break;
  }
}
function buildRealisticBuilding(key, color, seed) {
  const p = REALISTIC_BUILDING_PROFILES[key];
  if (!p) return null;
  if (key === 'stadium') return buildRealisticStadium(color, seed);
  const g = new THREE.Group();
  const palettes = REALISTIC_PALETTES[p.style] || REALISTIC_PALETTES.civic;
  const palette = palettes[Math.abs(seed) % palettes.length];
  const wallFamily = ['house', 'retail'].includes(p.style) && seed % 3 === 0 ? 'brick' : 'concrete';
  const wallMat = realisticBuildingMaterial(wallFamily, palette[0], wallFamily === 'brick' ? 0.38 : 0.22);
  const trimMat = realisticBuildingMaterial('concrete', palette[2], 0.18);
  const h = p.floors * p.fh;
  g.add(box(p.w, h, p.d, wallMat, 0, h * 0.5, 0));
  g.add(box(p.w + 0.14, 0.42, p.d + 0.14, trimMat, 0, 0.21, 0));
  for (let f = 1; f < p.floors; f++) g.add(box(p.w + 0.07, 0.1, p.d + 0.07, trimMat, 0, f * p.fh, 0));
  if (p.style !== 'industrial' || p.floors > 1) addRealisticWindows(g, p.w, h, p.d, p.floors, p.style, seed);
  addRealisticEntrance(g, p.w, p.d, p.style, color);
  addRealisticRoof(g, p, h, wallMat, seed);
  addStyleDetails(g, p, h, wallMat, trimMat, color, seed);
  addBuildingIdentity(g, key, p, h, wallMat, trimMat, color, seed);
  g.userData.rebuiltArchitecture = true;
  return g;
}
function buildRealisticInfrastructure(key, color, seed) {
  const supported = new Set(['farm', 'extractor', 'powerPlant', 'nuclearReactor', 'park', 'helipad', 'airfield', 'shipyard', 'port', 'samSite', 'solarFarm', 'offshoreRig', 'fishingWharf']);
  if (!supported.has(key)) return null;
  const g = new THREE.Group();
  const concrete = realisticBuildingMaterial('concrete', 0xe4e5e1, 0.28);
  const brick = realisticBuildingMaterial('brick', 0xffeee6, 0.4);
  const steel = new THREE.MeshStandardMaterial({ color: 0x697379, roughness: 0.48, metalness: 0.58 });
  const darkSteel = new THREE.MeshStandardMaterial({ color: 0x3e474d, roughness: 0.5, metalness: 0.62 });
  const roofMat = shingleMat(seed % 2 ? 0x764b3f : 0x555b60);
  const glass = new THREE.MeshPhysicalMaterial({ color: 0x53778a, roughness: 0.12, metalness: 0.16, clearcoat: 0.5 });
  const teamAccent = new THREE.MeshStandardMaterial({ color: new THREE.Color(color).lerp(new THREE.Color(0x59636a), 0.66), roughness: 0.5, metalness: 0.12 });
  const solar = new THREE.MeshPhysicalMaterial({ color: 0x18384f, roughness: 0.16, metalness: 0.46, clearcoat: 0.72 });

  const addPanelArray = (cols, rows, spacingX, spacingZ, y, ox = 0, oz = 0) => {
    for (let rz = 0; rz < rows; rz++) for (let cx = 0; cx < cols; cx++) {
      const panel = box(1.65, 0.07, 0.92, solar,
        ox + (cx - (cols - 1) / 2) * spacingX, y, oz + (rz - (rows - 1) / 2) * spacingZ);
      panel.rotation.x = -0.28;
      g.add(panel);
      g.add(cyl(0.035, 0.035, 0.65, steel, panel.position.x, y - 0.3, panel.position.z, 5));
    }
  };
  switch (key) {
    case 'farm': {
      const soil = new THREE.MeshStandardMaterial({ color: 0x674b32, roughness: 0.98 });
      for (let r = -3; r <= 3; r++) g.add(box(9.0, 0.08, 0.62, soil, 0, 0.04, r * 0.88));
      g.add(box(4.2, 2.8, 3.5, brick, -2.8, 1.4, -2.2));
      g.add(gableRoof(4.55, 3.9, 1.2, roofMat, -2.8, 2.8, -2.2));
      g.add(box(1.65, 2.25, 0.13, darkSteel, -2.8, 1.14, -0.4));
      const silo = cyl(1.05, 1.05, 3.8, steel, 3.3, 1.9, -2.3, 18);
      g.add(silo);
      const cap = new THREE.Mesh(new THREE.ConeGeometry(1.12, 0.85, 18), roofMat); cap.position.set(3.3, 4.23, -2.3); cap.castShadow = true; g.add(cap);
      break;
    }
    case 'extractor': {
      g.add(cyl(3.0, 3.35, 0.42, concrete, 0, 0.21, 0, 24));
      g.add(box(3.2, 1.6, 2.5, brick, -1.25, 1.02, 0));
      g.add(box(1.2, 1.15, 0.1, darkSteel, -1.25, 0.75, 1.3));
      for (const side of [-1, 1]) {
        const leg = box(0.16, 4.8, 0.16, steel, 1.25 + side * 0.7, 2.55, side * 0.7); leg.rotation.z = side * 0.18; g.add(leg);
      }
      g.add(box(1.8, 0.2, 1.6, steel, 1.25, 4.65, 0));
      g.add(cyl(0.22, 0.22, 4.2, darkSteel, 1.25, 2.35, 0, 10));
      break;
    }
    case 'powerPlant': {
      g.add(box(7.4, 3.8, 5.6, brick, -0.8, 1.9, 0));
      for (const x of [-2.6, -0.8, 1.0]) g.add(box(1.15, 1.5, 0.1, glass, x, 1.9, 2.85));
      g.add(gableRoof(7.75, 6.0, 1.15, roofMat, -0.8, 3.8, 0));
      for (const z of [-1.55, 1.55]) {
        const stack = cyl(0.48, 0.64, 6.2, brick, 3.5, 3.1, z, 18); g.add(stack);
        g.add(cyl(0.53, 0.53, 0.22, darkSteel, 3.5, 6.25, z, 18));
      }
      g.add(box(2.6, 0.16, 0.12, teamAccent, -0.8, 3.25, 2.92));
      break;
    }
    case 'nuclearReactor': {
      g.add(cyl(3.4, 3.75, 1.0, concrete, -1.0, 0.5, 0, 28));
      g.add(cyl(2.75, 3.05, 4.6, concrete, -1.0, 2.8, 0, 28));
      const dome = new THREE.Mesh(new THREE.SphereGeometry(2.75, 28, 14, 0, Math.PI * 2, 0, Math.PI / 2), concrete);
      dome.position.set(-1.0, 5.08, 0); dome.castShadow = true; g.add(dome);
      for (const z of [-1.7, 1.7]) {
        const tower = new THREE.Mesh(new THREE.CylinderGeometry(1.15, 1.65, 4.8, 22, 1, true), concrete);
        tower.position.set(3.4, 2.4, z); tower.castShadow = true; g.add(tower);
        g.add(new THREE.Mesh(new THREE.TorusGeometry(1.15, 0.12, 8, 24), steel));
        g.children[g.children.length - 1].position.set(3.4, 4.78, z);
        g.children[g.children.length - 1].rotation.x = Math.PI / 2;
      }
      g.add(box(2.8, 0.16, 0.1, teamAccent, -1.0, 3.45, 3.08));
      break;
    }
    case 'park': {
      const lawn = new THREE.MeshStandardMaterial({ color: 0x527b47, roughness: 0.96 });
      g.add(cyl(5.2, 5.2, 0.12, lawn, 0, 0.06, 0, 32));
      g.add(box(0.9, 0.08, 9.2, concrete, 0, 0.13, 0));
      g.add(box(9.2, 0.08, 0.9, concrete, 0, 0.13, 0));
      const waterMat = new THREE.MeshPhysicalMaterial({ color: 0x5f9eb0, roughness: 0.08, metalness: 0.05, transparent: true, opacity: 0.82 });
      g.add(cyl(1.25, 1.45, 0.42, concrete, 0, 0.24, 0, 24));
      g.add(cyl(1.08, 1.08, 0.08, waterMat, 0, 0.49, 0, 24));
      for (const a of [0.8, 2.35, 3.9, 5.45]) {
        const x = Math.cos(a) * 3.3, z = Math.sin(a) * 3.3;
        g.add(box(1.45, 0.12, 0.48, new THREE.MeshStandardMaterial({ color: 0x79583c, roughness: 0.8 }), x, 0.5, z));
        g.add(cyl(0.06, 0.06, 0.8, darkSteel, x - 0.55, 0.4, z, 6));
        g.add(cyl(0.06, 0.06, 0.8, darkSteel, x + 0.55, 0.4, z, 6));
      }
      break;
    }
    case 'helipad': {
      g.add(cyl(4.4, 4.65, 0.36, concrete, 0, 0.18, 0, 32));
      g.add(new THREE.Mesh(new THREE.RingGeometry(3.25, 3.45, 48), new THREE.MeshBasicMaterial({ color: 0xe4e7e8, side: THREE.DoubleSide })));
      const ring = g.children[g.children.length - 1]; ring.rotation.x = -Math.PI / 2; ring.position.y = 0.38;
      g.add(box(0.42, 0.07, 2.6, teamAccent, -0.75, 0.4, 0));
      g.add(box(0.42, 0.07, 2.6, teamAccent, 0.75, 0.4, 0));
      g.add(box(1.15, 0.07, 0.42, teamAccent, 0, 0.4, 0));
      g.add(box(3.4, 2.6, 2.8, brick, -4.2, 1.3, -2.5));
      g.add(gableRoof(3.7, 3.2, 0.9, roofMat, -4.2, 2.6, -2.5));
      break;
    }
    case 'airfield': {
      g.add(box(19.5, 0.2, 4.8, concrete, 0, 0.1, 0));
      for (let x = -8; x <= 8; x += 2) g.add(box(0.9, 0.03, 0.12, new THREE.MeshBasicMaterial({ color: 0xf1eee0 }), x, 0.22, 0));
      g.add(box(6.5, 3.4, 5.8, brick, -6.2, 1.7, -5.0));
      g.add(gableRoof(6.85, 6.2, 1.1, roofMat, -6.2, 3.4, -5.0));
      g.add(box(4.8, 2.65, 0.14, darkSteel, -6.2, 1.4, -2.05));
      g.add(box(2.4, 5.5, 2.4, concrete, 7.3, 2.75, -4.2));
      g.add(box(2.2, 1.0, 2.2, glass, 7.3, 5.35, -4.2));
      break;
    }
    case 'port':
    case 'shipyard': {
      g.add(box(11.5, 0.42, 7.2, concrete, 0, 0.2, 0));
      for (const z of [-2.8, 2.8]) for (let x = -5; x <= 5; x += 1.5) g.add(cyl(0.09, 0.11, 3.2, steel, x, -1.35, z, 8));
      g.add(box(6.8, 3.8, 4.8, brick, -2.4, 1.9, -0.8));
      g.add(gableRoof(7.15, 5.2, 1.0, roofMat, -2.4, 3.8, -0.8));
      g.add(box(4.8, 2.8, 0.15, darkSteel, -2.4, 1.45, 1.65));
      g.add(box(0.3, 5.8, 0.3, steel, 4.4, 2.9, -2.4));
      g.add(box(4.2, 0.28, 0.28, steel, 2.5, 5.6, -2.4));
      if (key === 'port') {
        const cargoMats = [0xb84a3b, 0x315f78, 0xc69038].map(c => new THREE.MeshStandardMaterial({ color: c, roughness: 0.72, metalness: 0.2 }));
        for (let i = 0; i < 7; i++) g.add(box(1.8, 0.72, 0.82, cargoMats[i % cargoMats.length], -4.2 + (i % 3) * 2, 0.8 + Math.floor(i / 3) * 0.75, 2.5));
      }
      break;
    }
    case 'samSite': {
      g.add(cyl(4.1, 4.4, 0.42, concrete, 0, 0.21, 0, 28));
      const launcher = new THREE.Group(); launcher.position.y = 0.75; launcher.rotation.y = architectureRand(seed, 5) * Math.PI * 2;
      launcher.add(cyl(1.0, 1.15, 0.52, darkSteel, 0, 0, 0, 14));
      for (const z of [-0.55, -0.18, 0.18, 0.55]) {
        const tube = cyl(0.15, 0.17, 3.1, steel, 0.7, 1.0, z, 12); tube.rotation.z = Math.PI / 2 - 0.62; launcher.add(tube);
      }
      g.add(launcher);
      g.add(cyl(0.08, 0.1, 3.6, steel, -2.6, 2.0, -1.8, 8));
      const radar = box(1.3, 0.12, 0.18, darkSteel, -2.6, 3.8, -1.8); g.add(radar); g.userData.spin = radar;
      break;
    }
    case 'solarFarm': {
      g.add(box(9.5, 0.18, 7.5, concrete, 0, 0.09, 0));
      addPanelArray(4, 3, 2.05, 1.72, 1.0, -0.7, 0);
      g.add(box(1.8, 1.7, 1.5, brick, 4.2, 0.85, 2.8));
      g.add(gableRoof(2.05, 1.8, 0.45, roofMat, 4.2, 1.7, 2.8));
      break;
    }
    case 'offshoreRig': {
      for (const x of [-2.7, 2.7]) for (const z of [-2.7, 2.7]) {
        g.add(cyl(0.2, 0.28, 7.0, darkSteel, x, 0.7, z, 10));
        const brace = box(0.15, 0.15, 5.6, steel, x, 1.8, 0); brace.rotation.x = x * z > 0 ? 0.55 : -0.55; g.add(brace);
      }
      g.add(box(6.8, 0.55, 6.8, steel, 0, 4.0, 0));
      g.add(box(3.4, 2.2, 2.5, brick, -1.2, 5.35, -1.4));
      g.add(gableRoof(3.7, 2.85, 0.65, roofMat, -1.2, 6.45, -1.4));
      g.add(box(0.28, 5.2, 0.28, darkSteel, 2.3, 6.8, 1.9));
      g.add(box(2.8, 0.25, 0.25, steel, 1.05, 9.2, 1.9));
      g.add(cyl(0.35, 0.42, 3.6, steel, 1.3, 6.0, -1.5, 12));
      break;
    }
    case 'fishingWharf': {
      g.add(box(8.8, 0.32, 3.8, new THREE.MeshStandardMaterial({ color: 0x76583d, roughness: 0.9 }), 0, 0.15, 0));
      for (const x of [-4, -2, 0, 2, 4]) for (const z of [-1.5, 1.5]) g.add(cyl(0.11, 0.14, 3.2, darkSteel, x, -1.4, z, 8));
      g.add(box(4.0, 2.6, 3.0, brick, -1.5, 1.6, -0.2));
      g.add(gableRoof(4.35, 3.4, 0.9, roofMat, -1.5, 2.9, -0.2));
      g.add(box(1.5, 2.0, 0.12, darkSteel, -1.5, 1.05, 1.35));
      for (const x of [1.8, 3.2]) g.add(box(1.0, 0.7, 0.8, brick, x, 0.5, 0.7));
      break;
    }
  }
  g.userData.rebuiltArchitecture = true;
  return g;
}
/* [cx, roofY, cz, w, d] for buildings with useful flat roofs */
const ROOF_SPECS = {
  bank:          [0, 4.85, 0.3, 3, 2],
  hospital:      [0, 5.05, 0, 3.5, 2.4],
  policeStation: [0, 3.45, 0, 3, 2],
  library:       [0, 4.15, 0, 2.4, 2],
  intelAgency:   [0, 6.05, 0, 3, 3],
  barracks:      [0, 3.2, 0, 4, 2.4],
  tvStation:     [1, 4.65, 1, 2.2, 1.8],
  chipFab:       [-2, 3.3, 1, 2.2, 1.6],
  apartments:    [0, 9.15, 0, 1.6, 1.6],
};

/* which facades get window grids: [w,h,d, cx,cy,cz, floors, cols] */
const WINDOW_SPECS = {
  hq:           [[11, 3.2, 8, 0, 1.6, -1.5, 1, 5], [7, 3, 6.5, -1, 4.7, -1.5, 1, 3], [4.5, 2.6, 4.5, -1.5, 7.4, -1.5, 1, 2]],
  workerHouse:  [[6, 2.6, 5, 0, 1.3, 0, 1, 3]],
  housing:      [[4.5, 7, 4.5, -1.6, 3.5, 0, 3, 2], [4.5, 5, 4.5, 2.2, 2.5, 1, 2, 2]],
  foodDepot:    [[7, 3.4, 5.5, 0, 1.7, 0, 1, 3]],
  bank:         [[6, 4, 5, 0, 2, 0, 2, 3]],
  cityHall:     [[8, 3.5, 6, 0, 1.75, 0, 1, 4]],
  school:       [[3, 4.4, 3, 3.4, 2.2, 0.5, 2, 2]],
  university:   [[9, 3.2, 5.5, 0, 1.6, 0, 1, 4], [4, 5, 4, 0, 2.5, -0.5, 2, 2]],
  hospital:     [[7, 5, 5.5, 0, 2.5, 0, 2, 3]],
  policeStation:[[6, 3, 4.5, 0, 1.5, 0, 1, 3]],
  tvStation:    [[5.5, 4.2, 4.5, 0, 2.1, 0, 2, 3]],
  barracks:     [[8, 2.8, 5, 0, 1.4, 0, 1, 4]],
  tankFactory:  [[10, 4, 7, 0, 2, 0, 1, 4]],
  market:       [],
  apartments:   [], // has its own lit bands
  techPark:     [], // all-glass already
  chipFab:      [[6.2, 3, 4.4, 0, 1.5, 0, 1, 4]],
  powerPlant:   [[6.5, 3.2, 5, -1, 1.6, 0, 1, 3]],
  commandCenter:[[6.5, 3.5, 6.5, 0, 1.75, 0, 1, 3]],
  intelAgency:  [[6, 5.5, 6, 0, 2.75, 0, 2, 3]],
  cottage:      [],
  luxuryVillas: [],
  residential:  [],
  museum:       [[7, 2.6, 5, 0, 1.3, 0, 1, 4]],
  courthouse:   [[6.5, 3, 5, 0, 1.5, 0, 1, 4]],
  waterTreatment: [],
  oilRefinery:  [],
  solarFarm:    [],
  samSite:      [],
  bunker:       [],
};

function buildingMesh(key, color, seed = 0) {
  // Complete authored glTF architecture takes priority. The procedural system
  // remains as an offline/error fallback and for infrastructure whose function
  // cannot be represented by a city building (farm, rig, runway, reactor...).
  const downtown = makeDowntownBuilding(key, color, seed);
  if (downtown) return downtown;
  const rebuilt = buildRealisticBuilding(key, color, seed)
    || buildRealisticInfrastructure(key, color, seed);
  if (rebuilt) return rebuilt;

  // Open infrastructure (farms, pads, rigs, parks and extractors) keeps its
  // dedicated functional geometry below. Enclosed buildings never reach the
  // legacy switch and no longer use the old Kenney city models.
  const g = new THREE.Group();
  const tm = teamMat(color);
  switch (key) {
    case 'hq': {
      // government command complex: stepped tower, portico entrance,
      // rooftop helipad, antenna farm with a blinking beacon
      g.add(box(11, 3.2, 8, MAT.wall, 0, 1.6, -1.5));
      g.add(box(7, 3, 6.5, MAT.wallDark, -1, 4.7, -1.5));
      g.add(box(4.5, 2.6, 4.5, tm, -1.5, 7.4, -1.5));
      g.add(box(4.9, 0.3, 4.9, MAT.dark, -1.5, 8.85, -1.5)); // tower roof lip
      // columned entrance with steps and glass doors
      g.add(box(4.6, 0.35, 2.4, MAT.wallDark, 2, 3.1, 3.6));
      for (const cx of [0.4, 2, 3.6]) g.add(box(0.38, 2.9, 0.38, MAT.wall, cx, 1.45, 4.4));
      g.add(box(5.4, 0.28, 3.2, MAT.pad, 2, 0.14, 4.2));
      g.add(box(4.6, 0.26, 2.4, MAT.pad, 2, 0.4, 3.9));
      g.add(box(2.4, 2.0, 0.15, MAT.glass, 2, 1.35, 2.6));
      // rooftop helipad with an H marking
      g.add(box(4.8, 0.18, 4.8, MAT.dark, 3, 3.3, -3));
      const padMark = new THREE.MeshStandardMaterial({ color: 0xf2c230, emissive: 0x8a6b12, emissiveIntensity: 0.35 });
      g.add(box(0.4, 0.06, 2.6, padMark, 2.2, 3.42, -3));
      g.add(box(0.4, 0.06, 2.6, padMark, 3.8, 3.42, -3));
      g.add(box(1.2, 0.06, 0.4, padMark, 3, 3.42, -3));
      // antenna farm + red air-traffic beacon that blinks
      g.add(cyl(0.12, 0.17, 4.4, MAT.metal, -2.4, 10.9, -2.6, 6));
      g.add(cyl(0.05, 0.05, 3.2, MAT.metal, -0.4, 10.2, -0.4, 4));
      g.add(box(0.85, 0.5, 0.07, MAT.metal, -2.4, 12.3, -2.6));
      const beacon = new THREE.Mesh(new THREE.SphereGeometry(0.19, 7, 6),
        new THREE.MeshStandardMaterial({ color: 0xff4444, emissive: 0xff2222, emissiveIntensity: 1.2 }));
      beacon.position.set(-2.4, 13.25, -2.6); g.add(beacon);
      g.userData.beacon = beacon;
      addFlag(g, color, 5.4, 0, 0.8);
      break;
    }
    case 'workerHouse': {
      g.add(box(6, 2.6, 5, MAT.wall, 0, 1.3, 0));
      g.add(gableRoof(6.6, 5.5, 1.5, shingleMat(color), 0, 2.6, 0));
      g.add(box(0.4, 0.5, 0.4, MAT.wallDark, 1.8, 3.6, 1)); // chimney
      g.add(box(1.2, 1.6, 0.2, MAT.dark, 0, 0.8, 2.55));    // door
      break;
    }
    case 'housing': {
      g.add(box(4.5, 7, 4.5, MAT.wall, -1.6, 3.5, 0));
      g.add(box(4.5, 5, 4.5, MAT.wallDark, 2.2, 2.5, 1));
      for (let f = 0; f < 3; f++) for (let c = -1; c <= 1; c++)
        g.add(box(0.8, 0.8, 0.1, MAT.glass, -1.6 + c * 1.4, 1.6 + f * 2, 2.3));
      g.add(box(4.7, 0.4, 4.7, tm, -1.6, 7.2, 0));
      break;
    }
    case 'residential': {
      // little suburb: three gabled houses + hedges
      for (const [hx, hz, rot] of [[-3.5, -2.5, 0.3], [2.8, -2.8, -0.4], [0.2, 2.8, 0.1]]) {
        const house = new THREE.Group();
        house.add(box(3.4, 2, 2.8, MAT.wall, 0, 1, 0));
        house.add(gableRoof(3.8, 3.1, 1.1, shingleMat(0xa03c2e), 0, 2, 0));
        house.add(box(0.3, 0.45, 0.3, MAT.wallDark, 1.1, 2.9, 0.6)); // chimney
        house.add(box(0.7, 1.1, 0.12, MAT.dark, 0.6, 0.55, 1.45));   // door
        house.position.set(hx, 0, hz); house.rotation.y = rot;
        g.add(house);
      }
      g.add(box(9, 0.3, 0.6, MAT.grass, 0, 0.15, 0.2));
      addFlag(g, color, 5.2, 0, 4.2);
      break;
    }
    case 'farm': {
      // red barn with a proper gable + crop rows + a spinning wind turbine
      g.add(box(4, 2.4, 3, MAT.red, -3, 1.2, -2.5));
      g.add(gableRoof(4.4, 3.3, 1.2, MAT.wallDark, -3, 2.4, -2.5));
      g.add(box(1.1, 1.5, 0.15, MAT.dark, -3, 0.75, -0.95)); // barn door
      for (let r = 0; r < 3; r++) {
        g.add(box(7, 0.4, 1.2, MAT.green, 1.5, 0.2, -1.5 + r * 2));
        // furrow lines between crops
        g.add(box(7, 0.12, 0.35, new THREE.MeshLambertMaterial({ color: 0x6b5236 }), 1.5, 0.06, -0.5 + r * 2));
      }
      const pole = cyl(0.09, 0.15, 5.4, MAT.wall, 4.6, 2.7, -2.8, 7);
      g.add(pole);
      const hub = new THREE.Group();
      hub.position.set(4.6, 5.4, -2.55);
      hub.add(box(0.45, 0.3, 0.4, MAT.metal, 0, 0, -0.15));
      for (let b2 = 0; b2 < 3; b2++) {
        const arm = new THREE.Group();
        arm.rotation.z = (b2 / 3) * Math.PI * 2;
        arm.add(box(0.22, 2.0, 0.06, MAT.wall, 0, 1.0, 0.08));
        hub.add(arm);
      }
      g.add(hub);
      g.userData.turbine = hub;
      break;
    }
    case 'foodDepot': {
      g.add(box(7, 3.4, 5.5, MAT.wallDark, 0, 1.7, 0));
      const roofC = new THREE.Mesh(new THREE.CylinderGeometry(2.8, 2.8, 7.2, 12, 1, false, 0, Math.PI), tm);
      roofC.rotation.z = Math.PI / 2; roofC.rotation.y = Math.PI / 2; roofC.position.y = 3.4; g.add(roofC);
      g.add(box(2.4, 2.2, 0.2, MAT.dark, 0, 1.1, 2.85));
      break;
    }
    case 'warehouse': {
      g.add(box(8.5, 3.6, 6, MAT.metal, 0, 1.8, 0));
      g.add(box(8.7, 0.4, 6.2, MAT.dark, 0, 3.8, 0));
      // roll-up doors + crates
      for (let d = -1; d <= 1; d++) g.add(box(1.8, 2.4, 0.15, MAT.wallDark, d * 2.6, 1.2, 3.05));
      g.add(box(1.2, 1.2, 1.2, teamMat(0xc9924a), 5.2, 0.6, 1.4));
      g.add(box(1, 1, 1, teamMat(0xc9924a), 5.4, 0.5, -0.6));
      g.add(box(1, 1, 1, teamMat(0xc9924a), 5.3, 1.6, 0.9));
      g.add(box(8.5, 0.3, 0.3, tm, 0, 3.4, 3.1));
      break;
    }
    case 'extractor': {
      g.add(box(4.5, 2, 4.5, MAT.metal, 0, 1, 0));
      g.add(cyl(1, 1.2, 5, MAT.dark, 0, 3.5, 0, 8));
      g.add(cyl(1.4, 0.2, 1.6, tm, 0, 6.4, 0, 8));
      const arm = box(0.4, 4.5, 0.4, MAT.metal, 2.4, 3.4, 0);
      arm.rotation.z = 0.5; g.add(arm); g.userData.pump = arm;
      break;
    }
    case 'powerPlant': {
      g.add(box(6.5, 3.2, 5, MAT.concrete, -1, 1.6, 0));
      // twin cooling towers
      for (const tx of [2.8, 5]) {
        const tower = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 2, 4.6, 10), MAT.wall);
        tower.position.set(tx, 2.3, -1); tower.castShadow = true; g.add(tower);
      }
      g.add(box(3, 1.5, 3, MAT.dark, -2, 4, 0));
      g.add(cyl(0.25, 0.25, 3.5, MAT.metal, -4, 4.5, 1.5, 6));
      g.add(box(6.5, 0.3, 0.3, tm, -1, 3.4, 2.6));
      break;
    }
    case 'nuclearReactor': {
      // containment dome + cooling tower + glow
      const dome = new THREE.Mesh(new THREE.SphereGeometry(3, 14, 10, 0, Math.PI * 2, 0, Math.PI / 2), MAT.concrete);
      dome.position.set(-1.5, 1.2, 0); dome.castShadow = true; g.add(dome);
      g.add(cyl(3.1, 3.3, 1.4, MAT.wallDark, -1.5, 0.7, 0, 14));
      const tower = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 2.3, 5.2, 12), MAT.wall);
      tower.position.set(3.6, 2.6, -1.5); tower.castShadow = true; g.add(tower);
      // steam puff (static white blob)
      const steam = new THREE.Mesh(new THREE.SphereGeometry(1.2, 7, 5),
        new THREE.MeshLambertMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 }));
      steam.position.set(3.6, 5.8, -1.5); g.add(steam);
      g.add(box(2.6, 1.6, 2, MAT.dark, 3, 0.8, 2.4)); // control block
      g.add(box(0.8, 0.8, 0.1, new THREE.MeshLambertMaterial({ color: 0x7dff5d, emissive: 0x44ff44, emissiveIntensity: 0.6 }), 3, 1, 3.45)); // glowing status window
      g.add(box(0.5, 1.2, 0.1, MAT.dark, -1.5, 0.6, 3.1));
      // hazard stripes
      g.add(box(6.5, 0.25, 0.25, teamMat(0xf2c230), 0.5, 0.3, 3.6));
      addFlag(g, color, -4.6, 0, -3);
      break;
    }
    case 'market': {
      // stalls with awnings
      for (const [mx, mz, cM] of [[-2.5, -1, MAT.red], [0.5, 1, MAT.green], [3, -1.2, tm]]) {
        g.add(box(2.4, 1.2, 2, MAT.wallDark, mx, 0.6, mz));
        const awn = new THREE.Mesh(new THREE.BoxGeometry(2.8, 0.15, 2.4), cM);
        awn.position.set(mx, 1.9, mz); awn.rotation.x = 0.15; awn.castShadow = true; g.add(awn);
        g.add(cyl(0.08, 0.08, 1.6, MAT.metal, mx - 1.2, 1.2, mz + 1, 4));
        g.add(cyl(0.08, 0.08, 1.6, MAT.metal, mx + 1.2, 1.2, mz + 1, 4));
      }
      break;
    }
    case 'bank': {
      g.add(box(6, 4, 5, MAT.wall, 0, 2, 0));
      for (let c = -1; c <= 1; c++) g.add(cyl(0.35, 0.35, 4, MAT.wall, c * 1.8, 2, 2.7, 8));
      g.add(box(6.6, 0.8, 6, MAT.wallDark, 0, 4.4, 0.3));
      const ped = new THREE.Mesh(new THREE.ConeGeometry(3.4, 1.6, 4), tm);
      ped.rotation.y = Math.PI / 4; ped.position.y = 5.6; g.add(ped);
      break;
    }
    case 'cityHall': {
      g.add(box(8, 3.5, 6, MAT.wall, 0, 1.75, 0));
      const dome = new THREE.Mesh(new THREE.SphereGeometry(2.2, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), tm);
      dome.position.y = 3.5; dome.castShadow = true; g.add(dome);
      for (let c = -2; c <= 2; c++) g.add(cyl(0.3, 0.3, 3.4, MAT.wall, c * 1.5, 1.7, 3.2, 8));
      addFlag(g, color, 3.6, 3.5, 2.6);
      break;
    }
    case 'school': {
      g.add(box(7, 3, 4, MAT.red, 0, 1.5, 0));
      g.add(box(3, 4.4, 3, MAT.wall, 3.4, 2.2, 0.5));
      g.add(box(3.2, 0.5, 3.2, tm, 3.4, 4.6, 0.5));
      for (let c = -2; c <= 1; c++) g.add(box(0.9, 1, 0.1, MAT.glass, c * 1.5 - 0.3, 1.8, 2.05));
      break;
    }
    case 'library': {
      g.add(box(5, 3.6, 4.5, MAT.wallDark, 0, 1.8, 0));
      g.add(box(5.4, 0.5, 4.9, tm, 0, 3.85, 0));
      for (let c = -1; c <= 1; c++) g.add(box(0.7, 2, 0.12, MAT.glass, c * 1.5, 1.6, 2.3));
      break;
    }
    case 'university': {
      g.add(box(9, 3.2, 5.5, MAT.wall, 0, 1.6, 0));
      g.add(box(4, 5, 4, MAT.wallDark, 0, 2.5, -0.5));
      const clock = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 0.3, 12), MAT.wall);
      clock.rotation.x = Math.PI / 2; clock.position.set(0, 4, 1.6); g.add(clock);
      const spire = new THREE.Mesh(new THREE.ConeGeometry(2.4, 2, 4), tm);
      spire.rotation.y = Math.PI / 4; spire.position.y = 6; spire.castShadow = true; g.add(spire);
      for (let c = -2; c <= 2; c++) g.add(cyl(0.28, 0.28, 3, MAT.wall, c * 1.6, 1.5, 2.9, 8));
      g.add(box(9, 0.3, 6, MAT.grass, 0, 0.05, 0.3));
      break;
    }
    case 'hospital': {
      g.add(box(7, 5, 5.5, MAT.wall, 0, 2.5, 0));
      g.add(box(3, 3, 5.7, MAT.wallDark, -3.5, 1.5, 0));
      g.add(box(0.6, 2.2, 0.15, MAT.red, 0, 3.6, 2.85));
      g.add(box(2.2, 0.6, 0.15, MAT.red, 0, 3.6, 2.85));
      g.add(box(7.2, 0.4, 5.7, tm, 0, 5.2, 0));
      break;
    }
    case 'policeStation': {
      g.add(box(6, 3, 4.5, MAT.navy, 0, 1.5, 0));
      g.add(box(6.3, 0.4, 4.8, MAT.dark, 0, 3.2, 0));
      // light bar
      g.add(box(0.6, 0.35, 0.35, new THREE.MeshLambertMaterial({ color: 0x3b6cff, emissive: 0x2244ff, emissiveIntensity: 0.7 }), -0.5, 3.55, 0));
      g.add(box(0.6, 0.35, 0.35, new THREE.MeshLambertMaterial({ color: 0xff4444, emissive: 0xff2222, emissiveIntensity: 0.7 }), 0.5, 3.55, 0));
      g.add(box(1.4, 1.7, 0.2, MAT.dark, 0, 0.85, 2.3));
      g.add(box(0.9, 0.9, 0.1, MAT.glass, -1.9, 1.9, 2.3));
      g.add(box(0.9, 0.9, 0.1, MAT.glass, 1.9, 1.9, 2.3));
      break;
    }
    case 'park': {
      g.add(cyl(5.5, 5.8, 0.3, MAT.grass, 0, 0.15, 0, 16));
      // pond
      g.add(cyl(1.6, 1.8, 0.2, new THREE.MeshLambertMaterial({ color: 0x3f87b5 }), 2, 0.32, 1.5, 12));
      // trees
      for (const [tx, tz] of [[-2.5, -2], [-3, 1.5], [0.5, -3], [1.5, 3.2]]) {
        g.add(cyl(0.18, 0.25, 1.4, new THREE.MeshLambertMaterial({ color: 0x6d4c33 }), tx, 0.9, tz, 5));
        const can = new THREE.Mesh(new THREE.SphereGeometry(1.1, 7, 5), MAT.green);
        can.position.set(tx, 2.2, tz); can.castShadow = true; g.add(can);
      }
      // benches
      g.add(box(1.2, 0.3, 0.4, MAT.wallDark, -0.5, 0.5, 0.5));
      g.add(box(1.2, 0.3, 0.4, MAT.wallDark, 3.5, 0.5, -1.5));
      break;
    }
    case 'stadium': {
      // oval bowl
      const bowl = new THREE.Mesh(new THREE.CylinderGeometry(6.5, 5.2, 2.6, 18, 1, true), MAT.wall);
      bowl.castShadow = true; bowl.position.y = 1.3; bowl.scale.z = 0.75; g.add(bowl);
      const rim = new THREE.Mesh(new THREE.TorusGeometry(6.4, 0.35, 6, 18), tm);
      rim.rotation.x = Math.PI / 2; rim.position.y = 2.7; rim.scale.z = 0.75; g.add(rim);
      const field = new THREE.Mesh(new THREE.CylinderGeometry(4.6, 4.6, 0.3, 16), MAT.grass);
      field.position.y = 0.4; field.scale.z = 0.72; g.add(field);
      // floodlights
      for (const [lx, lz] of [[-6, -3.4], [6, -3.4], [-6, 3.4], [6, 3.4]])
        g.add(cyl(0.12, 0.16, 5.5, MAT.metal, lx, 2.7, lz, 5));
      break;
    }
    case 'tvStation': {
      g.add(box(5.5, 4.2, 4.5, MAT.concrete, 0, 2.1, 0));
      g.add(box(5.8, 0.4, 4.8, MAT.dark, 0, 4.4, 0));
      // broadcast mast + dish
      g.add(cyl(0.12, 0.2, 7, MAT.metal, -1.5, 7.5, -1, 6));
      g.add(box(1.4, 0.12, 0.12, MAT.metal, -1.5, 9.5, -1));
      g.add(box(0.12, 0.12, 1.4, MAT.metal, -1.5, 8.6, -1));
      const dish = new THREE.Mesh(new THREE.SphereGeometry(1.1, 10, 8, 0, Math.PI * 2, 0, Math.PI / 3), MAT.wall);
      dish.rotation.x = -Math.PI / 2.6; dish.position.set(1.6, 5, 1.2); g.add(dish);
      g.add(box(2.6, 1, 0.15, tm, 0, 3, 2.3)); // logo band
      break;
    }
    case 'intelAgency': {
      g.add(box(6, 5.5, 6, MAT.dark, 0, 2.75, 0));
      g.add(box(6.4, 0.5, 6.4, tm, 0, 5.75, 0));
      for (let f = 0; f < 2; f++) for (let c = -1; c <= 1; c++)
        g.add(box(0.9, 0.9, 0.1, MAT.glass, c * 1.7, 1.8 + f * 2.2, 3.05));
      g.add(cyl(0.08, 0.08, 3.5, MAT.metal, 2.2, 7.2, 2.2, 4));
      break;
    }
    case 'ammoDepot': {
      const roofC = new THREE.Mesh(new THREE.CylinderGeometry(2.6, 2.6, 7, 12, 1, false, 0, Math.PI), MAT.metal);
      roofC.rotation.z = Math.PI / 2; roofC.rotation.y = Math.PI / 2; roofC.position.y = 1.2; roofC.castShadow = true; g.add(roofC);
      g.add(box(1.2, 1.2, 1.2, MAT.dark, 3, 0.6, 2.6));
      g.add(box(1.2, 1.2, 1.2, MAT.dark, 4, 0.6, 1.2));
      g.add(box(6.8, 0.3, 0.3, tm, 0, 2.6, 0));
      break;
    }
    case 'barracks': {
      g.add(box(8, 2.8, 5, MAT.green, 0, 1.4, 0));
      g.add(box(8.4, 0.5, 5.4, MAT.dark, 0, 2.9, 0));
      g.add(box(1.4, 1.8, 0.2, MAT.dark, -2.5, 0.9, 2.55));
      addFlag(g, color, 3.5, 2.8, 2);
      break;
    }
    case 'tankFactory': {
      g.add(box(10, 4, 7, MAT.concrete, 0, 2, 0));
      for (let i = -1; i <= 1; i++) {
        const seg = new THREE.Mesh(new THREE.CylinderGeometry(1.8, 1.8, 3.4, 10, 1, false, 0, Math.PI), MAT.metal);
        seg.rotation.z = Math.PI / 2; seg.rotation.y = Math.PI / 2;
        seg.position.set(i * 3.4, 4, 0); g.add(seg);
      }
      g.add(cyl(0.5, 0.7, 4, MAT.dark, -4, 5.5, -2.5, 8));
      g.add(box(3.4, 2.6, 0.2, MAT.dark, 2, 1.3, 3.55));
      g.add(box(10.2, 0.4, 0.4, tm, 0, 4.2, 3.5));
      break;
    }
    case 'helipad': {
      g.add(cyl(5.5, 6, 0.6, MAT.concrete, 0, 0.3, 0, 16));
      g.add(box(3.6, 0.5, 0.9, tm, 0, 0.65, 0));
      g.add(box(0.9, 0.5, 3.6, tm, 0, 0.65, 0));
      g.add(box(2.6, 2.2, 2.6, MAT.metal, -4.5, 1.1, -4));
      break;
    }
    case 'airfield': {
      g.add(box(20, 0.5, 7, MAT.dark, 0, 0.25, 0));
      for (let i = -2; i <= 2; i++) g.add(box(1.6, 0.55, 0.4, MAT.wall, i * 4, 0.3, 0));
      g.add(box(4, 3, 4, MAT.wall, -8, 1.5, -5));
      g.add(box(4.4, 0.4, 4.4, tm, -8, 3.2, -5));
      g.add(cyl(0.9, 1.2, 5, MAT.metal, 8, 2.5, -5, 8));
      g.add(box(2.4, 1.4, 2.4, MAT.glass, 8, 5.4, -5));
      break;
    }
    case 'port':
    case 'shipyard': {
      // dry dock frame + crane over water-side
      g.add(box(9, 1.2, 6.5, MAT.concrete, 0, 0.6, 0));
      g.add(box(1, 3.5, 6.5, MAT.metal, -4, 2.4, 0));
      g.add(box(1, 3.5, 6.5, MAT.metal, 4, 2.4, 0));
      g.add(box(9, 0.6, 1, MAT.metal, 0, 4.4, -2.4));
      g.add(box(9, 0.6, 1, MAT.metal, 0, 4.4, 2.4));
      // crane
      g.add(cyl(0.35, 0.45, 7, tm, 2.5, 3.5, 4, 6));
      const jib = box(6, 0.4, 0.4, tm, 0.5, 7, 4);
      g.add(jib);
      g.add(box(0.2, 2.2, 0.2, MAT.dark, -2, 5.9, 4));
      if (key === 'port') {
        for (let i = 0; i < 6; i++) g.add(box(1.7, 0.7, 0.85, i % 2 ? MAT.red : MAT.navy, -3.1 + (i % 3) * 2.1, 1.3 + Math.floor(i / 3) * 0.72, 0));
      } else {
        // small hull under construction
        const hull = box(5.5, 1, 1.8, MAT.navy, 0, 1.6, 0);
        g.add(hull);
      }
      addFlag(g, color, -4.2, 1.2, 3);
      break;
    }
    case 'missileSilo': {
      g.add(cyl(4.2, 4.6, 1.2, MAT.concrete, 0, 0.6, 0, 12));
      // blast doors (two half-discs)
      const doorMat = MAT.metal;
      const d1 = new THREE.Mesh(new THREE.CylinderGeometry(2.6, 2.6, 0.3, 12, 1, false, 0, Math.PI), doorMat);
      d1.position.set(0, 1.3, 0); g.add(d1);
      const d2 = new THREE.Mesh(new THREE.CylinderGeometry(2.6, 2.6, 0.3, 12, 1, false, Math.PI, Math.PI), doorMat);
      d2.position.set(0, 1.3, 0); g.add(d2);
      // missile tip peeking out
      const tip = new THREE.Mesh(new THREE.ConeGeometry(0.7, 1.6, 8), tm);
      tip.position.y = 2; tip.castShadow = true; g.add(tip);
      g.add(box(2.6, 1.8, 2.2, MAT.dark, 3.4, 0.9, -2.6)); // control bunker
      g.add(box(0.6, 0.6, 0.1, MAT.glass, 3.4, 1.2, -1.45));
      for (const a of [0.6, 2.2, 3.9, 5.5]) // warning posts
        g.add(cyl(0.07, 0.07, 1.2, MAT.red, Math.cos(a) * 4.4, 0.6, Math.sin(a) * 4.4, 4));
      break;
    }
    case 'commandCenter': {
      g.add(box(6.5, 3.5, 6.5, MAT.concrete, 0, 1.75, 0));
      g.add(cyl(0.3, 0.4, 2.4, MAT.metal, 1.8, 4.5, 1.8, 6));
      // radar dish on a rotating mount — scans the horizon
      const radar = new THREE.Group();
      radar.position.set(1.8, 6, 1.8);
      const dish = new THREE.Mesh(new THREE.SphereGeometry(1.9, 12, 8, 0, Math.PI * 2, 0, Math.PI / 3), MAT.wall);
      dish.rotation.x = -Math.PI / 3; dish.position.set(0.4, 0, 0); dish.castShadow = true;
      radar.add(dish); g.add(radar);
      g.userData.spin = radar;
      g.add(box(3, 1.2, 0.2, tm, -1.6, 3.8, 3.3));
      g.add(cyl(0.1, 0.1, 4.5, MAT.metal, -2.4, 5.2, -2.4, 4));
      break;
    }
    case 'cottage': {
      // a row of three cozy homes with pitched roofs
      for (const [hx, hz, rot] of [[-1.9, 0.8, 0.3], [0.2, -0.9, -0.2], [2, 0.7, 0.1]]) {
        const house = new THREE.Group();
        house.add(box(1.7, 1.3, 1.5, new THREE.MeshLambertMaterial({ color: 0xcdb693 }), 0, 0.65, 0));
        house.add(gableRoof(2.0, 1.75, 0.6, shingleMat(0x8a4b32), 0, 1.3, 0));
        house.add(box(0.35, 0.55, 0.08, MAT.dark, 0.3, 0.28, 0.78)); // door
        house.position.set(hx, 0, hz); house.rotation.y = rot;
        house.traverse(o => { if (o.isMesh) o.castShadow = true; });
        g.add(house);
      }
      break;
    }
    case 'apartments': {
      // one tall tower with lit window bands
      g.add(box(3.4, 8.5, 3.4, MAT.concrete, 0, 4.25, 0));
      const winMat = new THREE.MeshLambertMaterial({ color: 0x9fd7ff, emissive: 0x2a4a66 });
      for (let f = 0; f < 6; f++) g.add(box(3.5, 0.45, 3.5, winMat, 0, 1.2 + f * 1.3, 0));
      g.add(box(2, 0.6, 2, MAT.dark, 0, 8.8, 0)); // roof machinery
      g.add(cyl(0.06, 0.06, 1.6, MAT.metal, 0.7, 9.6, 0.7, 4));
      break;
    }
    case 'luxuryVillas': {
      // two white villas, a pool and a lawn
      const lawn = new THREE.Mesh(new THREE.CylinderGeometry(5.2, 5.4, 0.22, 16), new THREE.MeshLambertMaterial({ color: 0x4d8a3f }));
      lawn.position.y = 0.1; lawn.receiveShadow = true; g.add(lawn);
      for (const [hx, hz] of [[-1.9, -1.4], [1.8, 1.3]]) {
        g.add(box(2.2, 1.5, 1.9, new THREE.MeshLambertMaterial({ color: 0xf2ede0 }), hx, 0.95, hz));
        g.add(box(2.4, 0.25, 2.1, new THREE.MeshLambertMaterial({ color: 0xb0623b }), hx, 1.8, hz));
      }
      const pool = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.12, 1.5), new THREE.MeshLambertMaterial({ color: 0x3fb8d8 }));
      pool.position.set(-1.4, 0.28, 1.9); g.add(pool);
      break;
    }
    case 'techPark': {
      // sleek glass campus with a data antenna
      g.add(box(4.6, 2.4, 3.2, MAT.glass, -0.7, 1.2, 0));
      g.add(box(2.6, 3.6, 2.6, MAT.glass, 2, 1.8, 0.4));
      g.add(box(5, 0.25, 3.6, MAT.metal, -0.7, 2.55, 0));
      g.add(cyl(0.07, 0.07, 2.6, MAT.metal, 2, 5, 0.4, 4)); // antenna
      const dot = new THREE.Mesh(new THREE.SphereGeometry(0.16, 6, 5), new THREE.MeshLambertMaterial({ color: 0x7dffb0, emissive: 0x2a6644 }));
      dot.position.set(2, 6.3, 0.4); g.add(dot);
      break;
    }
    case 'chipFab': {
      // clean-room fab: long hall, filtered stacks, silicon intake
      g.add(box(6.2, 3, 4.4, MAT.wall, 0, 1.5, 0));
      g.add(box(6.4, 0.3, 4.6, MAT.metal, 0, 3.1, 0));
      for (const sx of [-1.8, 0, 1.8]) g.add(cyl(0.3, 0.35, 1.6, MAT.metal, sx, 3.9, -1.2, 8));
      g.add(box(2.6, 1.4, 0.15, MAT.glass, -1, 1.6, 2.25)); // observation window
      const intake = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.8, 1.2), new THREE.MeshLambertMaterial({ color: 0x9fd7ff }));
      intake.position.set(2.4, 0.5, 1.9); intake.castShadow = true; g.add(intake);
      break;
    }
    case 'samSite': {
      // sandbag revetment + rotating launcher with angled missile tubes
      g.add(cyl(3, 3.3, 0.7, new THREE.MeshStandardMaterial({ color: 0x8a8256, roughness: 1 }), 0, 0.35, 0, 12));
      g.add(box(2, 0.7, 2, MAT.dark, 0, 0.85, 0));
      const launcher = new THREE.Group();
      launcher.position.set(0, 1.5, 0);
      launcher.add(box(1.4, 0.5, 1.4, MAT.metal, 0, 0, 0));
      for (const zc of [-0.4, 0, 0.4]) {
        const tube = cyl(0.14, 0.16, 2.6, MAT.wallDark, 0.7, 0.9, zc, 6);
        tube.rotation.z = Math.PI / 2 - 0.7; launcher.add(tube);
      }
      launcher.add(cyl(0.09, 0.09, 1.3, MAT.metal, -0.8, 0.9, 0, 5)); // search radar post
      g.add(launcher); g.userData.spin = launcher;
      break;
    }
    case 'bunker': {
      // low reinforced dome with firing slits and sandbags
      const dome = new THREE.Mesh(new THREE.SphereGeometry(2.4, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2.3),
        new THREE.MeshStandardMaterial({ color: 0x6f6a58, roughness: 1 }));
      dome.position.y = 0.3; dome.castShadow = true; g.add(dome);
      g.add(cyl(2.6, 3, 0.6, MAT.concrete, 0, 0.3, 0, 10));
      for (const a of [0, Math.PI * 0.66, Math.PI * 1.33]) // firing slits
        g.add(box(0.9, 0.25, 0.2, MAT.dark, Math.cos(a) * 2.3, 1.1, Math.sin(a) * 2.3));
      // sandbag ring
      for (let a = 0; a < Math.PI * 2; a += 0.5)
        g.add(box(0.5, 0.3, 0.3, new THREE.MeshStandardMaterial({ color: 0x8a8256, roughness: 1 }), Math.cos(a) * 3, 0.15, Math.sin(a) * 3));
      addFlag(g, color, 0, 2.4, 0);
      break;
    }
    case 'solarFarm': {
      // rows of blue tilted PV panels + an inverter shed
      const panelMat = new THREE.MeshStandardMaterial({ color: 0x1b3a6b, roughness: 0.25, metalness: 0.4, emissive: 0x0c2140, emissiveIntensity: 0.3 });
      for (let row = -1; row <= 1; row++) {
        for (let col = -1; col <= 1; col++) {
          const p = box(2.4, 0.1, 1.6, panelMat, col * 3, 0.9, row * 2.4);
          p.rotation.x = -0.5; g.add(p);
          g.add(cyl(0.05, 0.05, 0.9, MAT.metal, col * 3, 0.45, row * 2.4, 4));
        }
      }
      g.add(box(1.4, 1.2, 1.2, MAT.wall, 4.2, 0.6, 3.4)); // inverter shed
      break;
    }
    case 'oilRefinery': {
      // distillation towers, storage tanks, flare stack with a live flame
      g.add(box(5, 1, 6, MAT.concrete, 0, 0.5, 0));
      for (const [tx, tz, h] of [[-1.5, -1, 5], [0.3, 1, 6.5], [1.8, -1.5, 4]]) {
        g.add(cyl(0.55, 0.6, h, MAT.metal, tx, h / 2 + 0.6, tz, 10));
        g.add(cyl(0.62, 0.62, 0.2, tm, tx, h + 0.6, tz, 10));
      }
      // connecting pipe
      const pipe = cyl(0.12, 0.12, 3, MAT.dark, 0, 1.4, 0, 5);
      pipe.rotation.x = Math.PI / 2; g.add(pipe);
      for (const [sx, sz] of [[-3.5, 2], [3.5, 2]]) { // squat storage tanks with domed lids
        g.add(cyl(1.3, 1.3, 1.6, MAT.wall, sx, 0.8, sz, 12));
        const lid = new THREE.Mesh(new THREE.SphereGeometry(1.3, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2), MAT.metal);
        lid.position.set(sx, 1.6, sz); lid.castShadow = true; g.add(lid);
      }
      // flare stack + flame (bloom-friendly)
      g.add(cyl(0.16, 0.2, 6.5, MAT.dark, -3.5, 3.25, -2.5, 6));
      const flame = new THREE.Mesh(new THREE.ConeGeometry(0.4, 1.2, 7),
        new THREE.MeshStandardMaterial({ color: 0xff9030, emissive: 0xff6a1f, emissiveIntensity: 1.5 }));
      flame.position.set(-3.5, 7.1, -2.5); g.add(flame); g.userData.flame = flame;
      break;
    }
    case 'waterTreatment': {
      // circular clarifier basins with rotating rake arms
      for (const [bx, bz, r] of [[-1.6, 0, 2.1], [2.2, 0.5, 1.6]]) {
        g.add(cyl(r, r + 0.1, 0.8, MAT.concrete, bx, 0.4, bz, 16));
        const water = cyl(r - 0.15, r - 0.15, 0.1, new THREE.MeshStandardMaterial({ color: 0x2f6f8c, roughness: 0.2 }), bx, 0.82, bz, 16);
        g.add(water);
        const arm = box(r * 1.8, 0.12, 0.2, MAT.metal, bx, 0.95, bz);
        g.add(arm);
      }
      g.add(box(1.6, 1.4, 1.4, MAT.wall, 3.8, 0.7, -2)); // pump house
      break;
    }
    case 'museum': {
      // neoclassical: colonnade, pediment, dome
      g.add(box(7, 2.6, 5, MAT.wall, 0, 1.3, 0));
      for (let c = -3; c <= 3; c++) g.add(cyl(0.28, 0.28, 2.6, MAT.wall, c * 1.05, 1.3, 2.6, 8));
      const ped = new THREE.Mesh(new THREE.ConeGeometry(4, 1, 3), tm);
      ped.rotation.y = Math.PI / 2; ped.scale.z = 0.35; ped.position.set(0, 3.3, 2.6); g.add(ped);
      g.add(box(7.4, 0.5, 5.4, MAT.wallDark, 0, 2.75, 0));
      const dome = new THREE.Mesh(new THREE.SphereGeometry(1.6, 14, 10, 0, Math.PI * 2, 0, Math.PI / 2), tm);
      dome.position.set(0, 3, -0.5); dome.castShadow = true; g.add(dome);
      g.add(box(6, 0.3, 0.5, MAT.pad, 0, 0.15, 3.4)); // steps
      break;
    }
    case 'courthouse': {
      g.add(box(6.5, 3, 5, MAT.wall, 0, 1.5, 0));
      for (let c = -2; c <= 2; c++) g.add(cyl(0.3, 0.3, 3, MAT.wall, c * 1.3, 1.5, 2.7, 8));
      const ped = new THREE.Mesh(new THREE.ConeGeometry(3.9, 1.1, 3), MAT.wallDark);
      ped.rotation.y = Math.PI / 2; ped.scale.z = 0.35; ped.position.set(0, 3.6, 2.7); g.add(ped);
      // scales-of-justice hint: a gold orb on the ridge
      const orb = new THREE.Mesh(new THREE.SphereGeometry(0.4, 10, 8),
        new THREE.MeshStandardMaterial({ color: 0xffd24d, metalness: 1, roughness: 0.3, emissive: 0x6a5210, emissiveIntensity: 0.3 }));
      orb.position.set(0, 4.4, 0); g.add(orb);
      g.add(box(5.5, 0.3, 0.5, MAT.pad, 0, 0.15, 3.3));
      break;
    }
    case 'offshoreRig': {
      // steel jacket platform: 4 legs into the sea, deck, derrick and flare stack
      const legMat = new THREE.MeshStandardMaterial({ color: 0xc9a227, roughness: 0.6, metalness: 0.5 });
      for (const [lx, lz] of [[-2.2, -2.2], [2.2, -2.2], [-2.2, 2.2], [2.2, 2.2]]) {
        g.add(cyl(0.3, 0.38, 7, legMat, lx, 0.2, lz, 8)); // legs run below the waterline
        const brace = box(0.14, 0.14, 4.2, MAT.metal, lx, 1.6, 0);
        brace.rotation.x = 0.35; g.add(brace);
      }
      g.add(box(6.4, 0.5, 6.4, MAT.metal, 0, 3.8, 0));            // main deck
      g.add(box(3.2, 1.6, 2.2, MAT.wall, -1.2, 4.9, -1.4));       // quarters block
      g.add(box(3.3, 0.15, 2.3, teamMat(0xe86a1e), -1.2, 5.75, -1.4));
      // derrick: tapering lattice tower
      for (const [dx, dz] of [[-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7], [0.7, 0.7]]) {
        const strut = cyl(0.07, 0.1, 4.6, MAT.dark, 1.4 + dx * 0.6, 6.3, 1.2 + dz * 0.6, 5);
        strut.rotation.set(dz * 0.12, 0, -dx * 0.12); g.add(strut);
      }
      g.add(box(0.5, 0.5, 0.5, MAT.dark, 1.4, 8.6, 1.2));
      // flare stack with a live flame (updateBuilding animates userData.flame)
      g.add(cyl(0.1, 0.13, 3.4, MAT.metal, 2.9, 5.6, -2.6, 6));
      const flame = new THREE.Mesh(new THREE.ConeGeometry(0.35, 1.1, 7),
        new THREE.MeshStandardMaterial({ color: 0xffa63d, emissive: 0xff7a1f, emissiveIntensity: 1.4 }));
      flame.position.set(2.9, 7.8, -2.6); g.add(flame);
      g.userData.flame = flame;
      // helipad
      g.add(cyl(1.4, 1.4, 0.12, MAT.pad, -2, 4.1, 2, 12));
      g.add(box(1.6, 0.05, 0.3, teamMat(0xf2f4f6), -2, 4.2, 2));
      break;
    }
    case 'fishingWharf': {
      // timber pier on piles, gear hut, boom crane and a moored skiff
      const wood = new THREE.MeshStandardMaterial({ color: 0x8a6a44, roughness: 0.9 });
      const woodDark = new THREE.MeshStandardMaterial({ color: 0x6d5236, roughness: 0.95 });
      g.add(box(3.2, 0.3, 7.5, wood, 1.4, 1.15, 0)); // pier deck running seaward
      for (const pz of [-3.2, -1.1, 1.1, 3.2]) {
        g.add(cyl(0.16, 0.2, 2.6, woodDark, 0.3, 0, pz, 6));
        g.add(cyl(0.16, 0.2, 2.6, woodDark, 2.5, 0, pz, 6));
      }
      g.add(box(2.6, 1.8, 2.2, wood, -1.6, 1.2, -1.4));  // gear hut
      g.add(gableRoof(2.4, 2.7, 1.0, shingleMat(0x9a4a30), -1.6, 2.1, -1.4));
      // boom crane with hanging net
      const boom = cyl(0.08, 0.1, 2.8, woodDark, 1.6, 2.4, 2.4, 6);
      boom.rotation.z = -0.7; g.add(boom);
      g.add(cyl(0.02, 0.02, 1.1, MAT.dark, 2.7, 1.7, 2.4, 4));
      // moored fishing skiff
      const skiff = box(2.0, 0.4, 0.8, teamMat(0x3e5c74), 3.4, 0.35, -1.8);
      g.add(skiff);
      g.add(box(0.1, 0.9, 0.1, woodDark, 3.4, 1.0, -1.8)); // mast
      // stacked crates & barrels
      g.add(box(0.5, 0.5, 0.5, wood, -0.4, 1.55, 0.9));
      g.add(cyl(0.26, 0.26, 0.55, woodDark, 0.3, 1.6, 1.2, 8));
      break;
    }
    case 'mountainMine': {
      // timber-framed mine portal driven into a rock face, headframe and ore cart
      const rock = new THREE.Mesh(new THREE.DodecahedronGeometry(3.2, 0),
        new THREE.MeshStandardMaterial({ color: 0x76736a, roughness: 0.95 }));
      rock.scale.set(1.3, 0.9, 1); rock.position.set(-0.8, 1.4, -0.8);
      rock.castShadow = true; g.add(rock);
      const timber = new THREE.MeshStandardMaterial({ color: 0x6d5236, roughness: 0.9 });
      g.add(box(0.35, 2.0, 0.35, timber, 0.6, 1.0, 1.6));
      g.add(box(0.35, 2.0, 0.35, timber, 2.0, 1.0, 1.6));
      g.add(box(2.1, 0.35, 0.4, timber, 1.3, 2.1, 1.6));
      const mouth = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.7),
        new THREE.MeshBasicMaterial({ color: 0x0a0a0c }));
      mouth.position.set(1.3, 1.0, 1.55); g.add(mouth);
      // headframe hoist tower
      for (const [dx, dz] of [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]) {
        const leg = cyl(0.08, 0.11, 3.4, MAT.metal, 2.9 + dx, 1.9, -1.5 + dz, 5);
        leg.rotation.set(dz * 0.18, 0, -dx * 0.18); g.add(leg);
      }
      g.add(box(1.1, 0.5, 1.1, MAT.dark, 2.9, 3.7, -1.5));
      const wheel = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.07, 6, 12), MAT.metal);
      wheel.position.set(2.9, 4.3, -1.5); wheel.castShadow = true; g.add(wheel);
      g.userData.spin = wheel;
      // ore cart on a short rail
      g.add(box(2.6, 0.08, 0.5, MAT.dark, 1.8, 0.28, 2.6));
      const cart = box(0.8, 0.5, 0.6, MAT.metal, 1.2, 0.6, 2.6);
      g.add(cart);
      g.add(box(0.7, 0.2, 0.5, new THREE.MeshStandardMaterial({ color: 0x9a6248, roughness: 0.9 }), 1.2, 0.9, 2.6));
      break;
    }
    default:
      g.add(box(5, 3, 5, MAT.wall, 0, 1.5, 0));
  }
  // lit window grids on every architectural facade
  for (const spec of WINDOW_SPECS[key] || []) addWindows(g, ...spec);
  // rooftop machinery on flat roofs
  if (ROOF_SPECS[key]) addRoofClutter(g, ...ROOF_SPECS[key]);
  return g;
}

/* shingled roof material — overlapping tile rows drawn to a canvas (cached) */
const _shingleCache = {};
function shingleMat(baseHex) {
  const key = String(baseHex);
  if (_shingleCache[key]) return _shingleCache[key];
  if (ARCH_PBR.roof.diffuse) {
    const tint = new THREE.Color(0xffffff).lerp(new THREE.Color(baseHex), 0.2);
    const pbr = new THREE.MeshStandardMaterial({
      color: tint,
      map: ARCH_PBR.roof.diffuse,
      normalMap: ARCH_PBR.roof.normal,
      roughnessMap: ARCH_PBR.roof.roughness,
      roughness: 0.88,
      metalness: 0,
    });
    pbr.normalScale = new THREE.Vector2(0.55, 0.55);
    _shingleCache[key] = pbr;
    return pbr;
  }
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const ctx = c.getContext('2d');
  const base = new THREE.Color(baseHex);
  ctx.fillStyle = '#' + base.getHexString();
  ctx.fillRect(0, 0, 128, 128);
  const dark = '#' + base.clone().multiplyScalar(0.62).getHexString();
  const lite = '#' + base.clone().multiplyScalar(1.18).getHexString();
  for (let row = 0; row < 8; row++) {
    const y = row * 16;
    ctx.fillStyle = dark;
    ctx.fillRect(0, y + 13, 128, 3); // shadow under each course
    // staggered tile joints
    for (let xj = (row % 2) * 10; xj < 128; xj += 21) {
      ctx.fillRect(xj, y + 2, 2, 12);
    }
    ctx.fillStyle = lite;
    ctx.fillRect(0, y, 128, 2); // sunlit tile edge
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(2, 1);
  const m = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.85, metalness: 0.02 });
  _shingleCache[key] = m;
  return m;
}

/* per-team military camouflage texture (cached per colour) */
const _camoCache = {};
const _unitMarkCache = {};
function unitMarkMat(teamColor) {
  const key = String(teamColor);
  if (_unitMarkCache[key]) return _unitMarkCache[key];
  const color = new THREE.Color(teamColor).lerp(new THREE.Color(0x5e686d), 0.58);
  return (_unitMarkCache[key] = new THREE.MeshPhysicalMaterial({
    color, roughness: 0.48, metalness: 0.22, clearcoat: 0.18,
  }));
}
function camoMat(teamColor) {
  const key = String(teamColor);
  if (_camoCache[key]) return _camoCache[key];
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const ctx = c.getContext('2d');
  // mostly military olive drab — the team colour only tints it slightly, so
  // vehicles read as real armour while the cupola/stripes carry team identity
  const base = new THREE.Color(teamColor).lerp(new THREE.Color(0x4a5240), 0.78);
  ctx.fillStyle = '#' + base.getHexString();
  ctx.fillRect(0, 0, 128, 128);
  const tones = [
    base.clone().multiplyScalar(0.72),
    base.clone().multiplyScalar(1.22),
    new THREE.Color(0x33392c),
  ];
  for (let i = 0; i < 26; i++) {
    ctx.fillStyle = '#' + tones[i % 3].getHexString();
    ctx.beginPath();
    ctx.ellipse(Math.random() * 128, Math.random() * 128,
      8 + Math.random() * 18, 6 + Math.random() * 12, Math.random() * 3, 0, Math.PI * 2);
    ctx.fill();
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  const m = new THREE.MeshStandardMaterial({
    map: tex,
    normalMap: UNIT_PBR.normal,
    roughnessMap: UNIT_PBR.roughness,
    metalnessMap: UNIT_PBR.metalness,
    roughness: 0.68,
    metalness: 0.24,
    envMapIntensity: 0.72,
  });
  if (UNIT_PBR.normal) m.normalScale = new THREE.Vector2(0.25, 0.25);
  _camoCache[key] = m;
  return m;
}

/* ============================================================
   Humanoid figure builder — real little people with limbs,
   gear and weapons. Limb groups are stored in userData.limbs
   so updateUnit can swing them while walking.
   ============================================================ */
function humanoidMesh(teamColor, opts = {}) {
  const g = new THREE.Group();
  const skinMat = new THREE.MeshStandardMaterial({ color: opts.skin || 0xe0b088, roughness: 0.58, metalness: 0 });
  const uniformMat = new THREE.MeshStandardMaterial({ color: opts.uniform || 0x4e6b3d, roughness: 0.9, metalness: 0 });
  const pantsMat = new THREE.MeshStandardMaterial({ color: opts.pants || (opts.uniform ? opts.uniform : 0x3e5531), roughness: 0.93, metalness: 0 });
  const bootMat = new THREE.MeshStandardMaterial({ color: 0x2b2620, roughness: 0.65, metalness: 0.02 });
  const tMat = unitMarkMat(teamColor);

  // ---- legs (groups pivot at the hip so they can swing) ----
  const mkLeg = side => {
    const leg = new THREE.Group();
    leg.position.set(side * 0.17, 1.06, 0);
    const thigh = new THREE.Mesh(new THREE.CapsuleGeometry(0.125, 0.72, 4, 8), pantsMat);
    thigh.position.y = -0.5; thigh.castShadow = true;
    leg.add(thigh);
    leg.add(box(0.27, 0.16, 0.4, bootMat, 0, -1.02, 0.05)); // boot
    g.add(leg);
    return leg;
  };
  const lLeg = mkLeg(-1), rLeg = mkLeg(1);

  // ---- torso + tactical vest ----
  g.add(box(0.64, 0.88, 0.38, uniformMat, 0, 1.52, 0));
  if (opts.vest) {
    const vestMat = new THREE.MeshStandardMaterial({ color: opts.vest, roughness: 0.86, metalness: 0 });
    g.add(box(0.56, 0.56, 0.46, vestMat, 0, 1.5, 0));
    g.add(box(0.16, 0.14, 0.1, MAT.dark, -0.14, 1.6, 0.26)); // pouches
    g.add(box(0.16, 0.14, 0.1, MAT.dark, 0.12, 1.38, 0.26));
  }
  if (opts.reflective) {
    // hi-vis safety stripes that catch the light — construction crew realism
    const stripeMat = new THREE.MeshStandardMaterial({
      color: 0xf7f14a, emissive: 0xb0a820, emissiveIntensity: 0.55, roughness: 0.4 });
    g.add(box(0.58, 0.09, 0.48, stripeMat, 0, 1.62, 0));
    g.add(box(0.58, 0.09, 0.48, stripeMat, 0, 1.36, 0));
    g.add(box(0.1, 0.4, 0.47, stripeMat, -0.18, 1.5, 0)); // suspender stripes
    g.add(box(0.1, 0.4, 0.47, stripeMat, 0.18, 1.5, 0));
    g.add(box(0.66, 0.14, 0.4, new THREE.MeshStandardMaterial({ color: 0x4a4438, roughness: 0.82 }), 0, 1.02, 0)); // tool belt
    g.add(box(0.14, 0.18, 0.12, MAT.metal, 0.3, 0.98, 0.22)); // holstered tools
    g.add(box(0.12, 0.16, 0.1, MAT.dark, -0.3, 0.98, 0.22));
  }
  g.add(box(0.66, 0.1, 0.4, tMat, 0, 1.94, 0)); // team shoulder band
  if (opts.pack) g.add(box(0.42, 0.5, 0.22, new THREE.MeshStandardMaterial({ color: 0x54503f, roughness: 0.9 }), 0, 1.55, -0.3));

  // ---- arms (pivot at the shoulder) ----
  const mkArm = (side, baseRotX) => {
    const arm = new THREE.Group();
    arm.position.set(side * 0.41, 1.86, 0);
    const sleeve = new THREE.Mesh(new THREE.CapsuleGeometry(0.09, 0.5, 4, 8), uniformMat);
    sleeve.position.y = -0.35; sleeve.castShadow = true; arm.add(sleeve);
    arm.add(box(0.15, 0.16, 0.17, skinMat, 0, -0.76, 0)); // hand
    arm.rotation.x = baseRotX;
    g.add(arm);
    return arm;
  };
  // weapon-bearing pose: both hands forward; workers swing free
  const armPose = opts.armPose !== undefined ? opts.armPose : -1.15;
  const lArm = mkArm(-1, opts.weapon === 'none' ? 0 : armPose);
  const rArm = mkArm(1, opts.weapon === 'none' ? 0 : armPose);

  // ---- head + neck + headgear ----
  g.add(cyl(0.09, 0.11, 0.16, skinMat, 0, 1.99, 0, 6)); // neck
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.245, 10, 8), skinMat);
  head.position.y = 2.16; head.castShadow = true; g.add(head);
  // shoulder pads ground the silhouette
  g.add(box(0.2, 0.12, 0.26, uniformMat, -0.44, 1.94, 0));
  g.add(box(0.2, 0.12, 0.26, uniformMat, 0.44, 1.94, 0));
  switch (opts.helmet) {
    case 'hardhat': {
      const hardhat = new THREE.MeshPhysicalMaterial({ color: 0xf2c230, roughness: 0.34, metalness: 0.02, clearcoat: 0.28 });
      g.add(cyl(0.28, 0.3, 0.18, hardhat, 0, 2.33, 0, 12));
      g.add(cyl(0.4, 0.42, 0.05, hardhat, 0, 2.26, 0, 12)); // brim
      break;
    }
    case 'hood': {
      g.add(cyl(0.24, 0.34, 0.34, new THREE.MeshStandardMaterial({ color: opts.uniform || 0x3a4234, roughness: 0.94 }), 0, 2.28, 0, 10));
      break;
    }
    case 'beret': {
      const beret = new THREE.Mesh(new THREE.SphereGeometry(0.26, 8, 6), tMat);
      beret.scale.y = 0.45; beret.position.set(0.05, 2.34, 0); beret.castShadow = true; g.add(beret);
      break;
    }
    default: { // combat helmet in team colour, with a dark tactical visor
      g.add(cyl(0.29, 0.32, 0.24, tMat, 0, 2.31, 0, 10));
      const visor = box(0.34, 0.1, 0.05, new THREE.MeshStandardMaterial({ color: 0x141a20, roughness: 0.15, metalness: 0.4 }), 0, 2.2, 0.22);
      g.add(visor);
      g.add(box(0.08, 0.06, 0.34, MAT.dark, 0.24, 2.24, 0)); // chin strap hint
    }
  }

  // ---- weapon, held by the right arm so it moves with it ----
  const wpn = new THREE.Group();
  switch (opts.weapon) {
    case 'rifle': {
      wpn.add(box(0.09, 0.09, 1.05, MAT.dark, 0, -0.74, 0.35));
      wpn.add(box(0.07, 0.18, 0.22, MAT.dark, 0, -0.83, 0.12)); // magazine
      wpn.add(box(0.08, 0.14, 0.3, new THREE.MeshStandardMaterial({ color: 0x5b4a33, roughness: 0.78 }), 0, -0.72, -0.18)); // stock
      break;
    }
    case 'longRifle': {
      wpn.add(box(0.08, 0.08, 1.65, MAT.dark, 0, -0.74, 0.55));
      wpn.add(cyl(0.06, 0.06, 0.26, tMat, 0, -0.62, 0.35, 6)); // scope
      wpn.add(box(0.06, 0.16, 0.24, MAT.dark, 0, -0.85, 0.05));
      break;
    }
    case 'launcher': {
      const tube = cyl(0.14, 0.16, 1.5, new THREE.MeshStandardMaterial({ color: 0x556655, roughness: 0.7, metalness: 0.18 }), 0, 0, 0, 10);
      tube.rotation.x = Math.PI / 2 - 0.25;
      tube.position.set(0, 2.05, -0.1);
      g.add(tube); // shoulder-mounted, not hand-held
      wpn.add(box(0.08, 0.08, 0.5, MAT.dark, 0, -0.74, 0.25)); // sidearm
      break;
    }
    case 'tool': {
      wpn.add(cyl(0.05, 0.05, 0.7, new THREE.MeshStandardMaterial({ color: 0x8a6f4d, roughness: 0.78 }), 0, -0.85, 0.25, 8));
      wpn.add(box(0.3, 0.12, 0.12, MAT.metal, 0, -0.85, 0.6)); // hammer head
      break;
    }
  }
  if (wpn.children.length) rArm.add(wpn);
  wpn.traverse(o => { if (o.isMesh) o.castShadow = true; });

  g.userData.limbs = { lLeg, rLeg, lArm, rArm, armBase: opts.weapon === 'none' ? 0 : armPose };
  return g;
}

function rememberRollingPart(group, mesh) {
  (group.userData.rollingParts ||= []).push(mesh);
  return mesh;
}

function unitMesh(key, color, seed = 0) {
  const g = new THREE.Group();
  const tm = unitMarkMat(color);

  // Tanks carry their own modelled turret + barrel (Quaternius Animated
  // Tanks Pack), so they bypass the generic authored path below — that path
  // always bolts on a plain decorative gun, which would double up here.
  if (key === 'tank') {
    const tankModel = makeTankModel(color, seed);
    if (tankModel) {
      g.add(tankModel);
      Object.assign(g.userData, tankModel.userData);
      return g;
    }
  }

  const authored = makeAssetModel(`unit:${key}`, color, seed);
  if (authored) {
    dressHullIfUntextured(authored, seed); // fixes the Kenney watercraft hulls, no-ops otherwise
    g.add(authored);
    const deckY = key === 'destroyer' ? 2.35 : key === 'corvette' ? 1.75 : 1.35;
    const turret = new THREE.Group();
    turret.position.set(0, deckY, 0.45);
    turret.add(cyl(0.24, 0.3, 0.35, tm, 0, 0, 0, 10));
    const gun = cyl(0.055, 0.075, key === 'destroyer' ? 1.5 : 1.05, MAT.dark, 0, 0.18, 0.55, 7);
    gun.rotation.x = Math.PI / 2;
    turret.add(gun);
    g.add(turret);
    g.userData.turret = turret;
    g.userData.assetModel = true;
    return g;
  }
  switch (key) {
    case 'worker': {
      const rig = makeWorkerRig(color, { weapon: 'tool' });
      if (rig) { g.add(rig); Object.assign(g.userData, rig.userData); break; }
      // Offline fallback if the external character asset cannot be loaded.
      const man = humanoidMesh(color, {
        uniform: 0xc47f3a, pants: 0x5a5040, vest: 0xe8842a, reflective: true,
        helmet: 'hardhat', weapon: 'tool', armPose: -0.5,
      });
      g.add(man);
      Object.assign(g.userData, man.userData);
      break;
    }
    case 'soldier': {
      const rig = makeSoldierRig(color, { weapon: 'rifle' });
      if (rig) { g.add(rig); Object.assign(g.userData, rig.userData); break; }
      const man = humanoidMesh(color, {
        uniform: 0x4e6b3d, vest: 0x3c4a33, helmet: 'combat', weapon: 'rifle', pack: true,
      });
      g.add(man);
      Object.assign(g.userData, man.userData);
      break;
    }
    case 'rocketSoldier': {
      const rig = makeSoldierRig(color, { weapon: 'launcher' });
      if (rig) {
        g.add(rig); Object.assign(g.userData, rig.userData); break;
      }
      const man = humanoidMesh(color, {
        uniform: 0x44503c, pants: 0x3a4234, vest: 0x2e3830, helmet: 'combat', weapon: 'launcher', pack: true,
      });
      g.add(man);
      Object.assign(g.userData, man.userData);
      break;
    }
    case 'sniper': {
      const rig = makeSoldierRig(color, { weapon: 'sniper' });
      if (rig) {
        g.add(rig); Object.assign(g.userData, rig.userData); break;
      }
      const man = humanoidMesh(color, {
        uniform: 0x4a5240, pants: 0x424a3a, helmet: 'hood', weapon: 'longRifle', armPose: -1.3,
      });
      g.add(man);
      Object.assign(g.userData, man.userData);
      break;
    }
    case 'commando': {
      const rig = makeSoldierRig(color, { weapon: 'rifle' });
      if (rig) {
        g.add(rig); Object.assign(g.userData, rig.userData); break;
      }
      const man = humanoidMesh(color, {
        uniform: 0x29333a, pants: 0x232c33, vest: 0x1c2429, helmet: 'beret', weapon: 'rifle', pack: true,
      });
      g.add(man);
      Object.assign(g.userData, man.userData);
      break;
    }
    case 'aaVehicle': {
      const camo = camoMat(color);
      g.add(box(2.8, 0.9, 2, camo, 0, 0.75, 0));
      const nose = box(0.85, 0.64, 1.9, camo, 1.55, 0.72, 0); nose.rotation.z = -0.36; g.add(nose);
      g.add(box(1.4, 0.08, 2.05, tm, -0.6, 1.22, 0)); // team roof stripe
      g.add(box(3, 0.5, 0.5, MAT.dark, 0, 0.3, 0.9));
      g.add(box(3, 0.5, 0.5, MAT.dark, 0, 0.3, -0.9));
      for (const side of [1, -1]) for (const wx of [-1.15, -0.38, 0.38, 1.15]) {
        const wheel = cyl(0.22, 0.22, 0.13, MAT.metal, wx, 0.3, side * 1.04, 10);
        wheel.rotation.x = Math.PI / 2;
        g.add(wheel); rememberRollingPart(g, wheel);
      }
      const turret = new THREE.Group(); turret.position.set(0, 1.32, 0);
      turret.add(cyl(0.8, 0.9, 0.6, MAT.metal, 0, 0.3, 0, 12));
      // quad flak barrels angled up
      for (const bz of [-0.3, -0.1, 0.1, 0.3]) {
        const b2 = cyl(0.055, 0.07, 1.75, MAT.dark, 0.62, 0.9, bz, 8);
        b2.rotation.z = Math.PI / 2 - 0.9; turret.add(b2);
      }
      turret.add(box(0.5, 0.46, 0.16, MAT.glass, -0.7, 0.72, 0));
      g.add(turret); g.userData.turret = turret;
      break;
    }
    case 'samLauncher': {
      const camo = camoMat(color);
      g.add(box(3.2, 0.9, 2, camo, 0, 0.75, 0));
      const cab = box(1.05, 0.75, 1.9, camo, 1.45, 1.15, 0); cab.rotation.z = -0.2; g.add(cab);
      g.add(box(0.1, 0.42, 1.35, MAT.glass, 2.0, 1.28, 0));
      g.add(box(3.4, 0.5, 0.5, MAT.dark, 0, 0.3, 0.95));
      g.add(box(3.4, 0.5, 0.5, MAT.dark, 0, 0.3, -0.95));
      for (const side of [1, -1]) for (const wx of [-1.25, -0.42, 0.42, 1.25]) {
        const wheel = cyl(0.22, 0.22, 0.13, MAT.metal, wx, 0.3, side * 1.08, 10);
        wheel.rotation.x = Math.PI / 2;
        g.add(wheel); rememberRollingPart(g, wheel);
      }
      const launcher = new THREE.Group(); launcher.position.set(-0.35, 1.25, 0);
      const rack = box(1.4, 0.45, 1.4, tm, 0.25, 0.3, 0);
      rack.rotation.z = -0.35; launcher.add(rack);
      for (const zc of [-0.45, 0, 0.45]) {
        const tube = cyl(0.12, 0.14, 2.4, MAT.dark, 0.9, 0.8, zc, 10);
        tube.rotation.z = Math.PI / 2 - 0.5; launcher.add(tube);
      }
      g.add(launcher); g.userData.turret = launcher;
      g.add(cyl(0.08, 0.08, 1.4, MAT.metal, -0.95, 1.9, 0, 5));
      break;
    }
    case 'bomber': {
      const camo = camoMat(color);
      const body = cyl(0.5, 0.68, 4.6, camo, 0, 1.2, 0, 12);
      body.rotation.z = Math.PI / 2; g.add(body);
      const noseCap = new THREE.Mesh(new THREE.SphereGeometry(0.5, 9, 7), camo);
      noseCap.scale.x = 1.4; noseCap.position.set(2.3, 1.2, 0); noseCap.castShadow = true; g.add(noseCap);
      // one-piece swept wing planform — tapered chord, raked tips
      const bWings = finMesh([
        [1.0, 0.5], [-0.6, 3.4], [-1.25, 3.5], [-0.85, 0.55],
        [-0.85, -0.55], [-1.25, -3.5], [-0.6, -3.4], [1.0, -0.5],
      ], 0.13, camo);
      bWings.position.set(0.2, 1.15, 0); g.add(bWings);
      // four podded engines slung under the wing sweep, glowing exhausts
      for (const wz of [-2.5, -1.25, 1.25, 2.5]) {
        const eng = cyl(0.2, 0.24, 1.0, MAT.metal, 0.15 - Math.abs(wz) * 0.5, 0.98, wz, 8);
        eng.rotation.z = Math.PI / 2; g.add(eng);
        const glow = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.16, 0.1, 8),
          new THREE.MeshStandardMaterial({ color: 0xffa050, emissive: 0xff7a30, emissiveIntensity: 1.2 }));
        glow.rotation.z = Math.PI / 2;
        glow.position.set(-0.4 - Math.abs(wz) * 0.5, 0.98, wz); g.add(glow);
      }
      // tail: vertical fin + horizontal stabilizers, team-coloured
      g.add(box(1.0, 1.15, 0.13, tm, -2.15, 1.9, 0));
      g.add(box(0.9, 0.1, 2.2, camo, -2.15, 1.35, 0));
      // cockpit window strip
      g.add(box(0.55, 0.32, 0.74, MAT.glass, 1.75, 1.42, 0));
      g.add(box(2.2, 0.1, 0.1, tm, 0.6, 1.55, 0)); // spine stripe
      break;
    }
    case 'submarine': {
      const hull = cyl(0.7, 0.7, 4.6, MAT.dark, 0, 0.3, 0, 12);
      hull.rotation.z = Math.PI / 2; g.add(hull);
      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.7, 10, 8), MAT.dark);
      nose.scale.x = 1.3; nose.position.set(2.3, 0.3, 0); nose.castShadow = true; g.add(nose);
      const tail = new THREE.Mesh(new THREE.ConeGeometry(0.7, 1.6, 10), MAT.dark);
      tail.rotation.z = Math.PI / 2; tail.position.set(-3, 0.3, 0); tail.castShadow = true; g.add(tail);
      // streamlined sail with dive planes + team band
      const sail = box(1.1, 0.85, 0.45, MAT.dark, 0.4, 1.05, 0);
      g.add(sail);
      g.add(box(1.15, 0.12, 0.5, tm, 0.4, 1.5, 0));            // team cap
      g.add(box(0.12, 0.06, 1.5, MAT.dark, 0.55, 1.15, 0));    // sail dive planes
      g.add(cyl(0.035, 0.035, 0.75, MAT.metal, 0.25, 1.95, 0, 4)); // periscope
      g.add(cyl(0.025, 0.025, 0.6, MAT.metal, 0.55, 1.85, 0, 4)); // snorkel
      // bow planes + cruciform tail fins
      g.add(box(0.12, 0.05, 1.7, MAT.dark, 1.7, 0.35, 0));
      g.add(box(0.1, 0.55, 1.7, MAT.dark, -2.75, 0.3, 0));
      g.add(box(0.1, 1.4, 0.09, MAT.dark, -2.75, 0.3, 0));
      // propeller behind the tail cone
      const prop = new THREE.Group();
      prop.position.set(-3.85, 0.3, 0);
      for (let b = 0; b < 5; b++) {
        const blade = box(0.06, 0.5, 0.14, MAT.metal, 0, 0.22, 0);
        const arm = new THREE.Group();
        arm.rotation.x = (b / 5) * Math.PI * 2;
        arm.add(blade); prop.add(arm);
      }
      g.add(prop); g.userData.prop = prop;
      break;
    }
    case 'tank': {
      const camo = camoMat(color);
      // hull with sloped front glacis
      g.add(box(3.3, 0.8, 2.0, camo, -0.1, 0.95, 0));
      const glacis = box(1.0, 0.6, 1.95, camo, 1.7, 0.85, 0);
      glacis.rotation.z = -0.45; g.add(glacis);
      // tracks, fenders and road wheels on both sides
      for (const side of [1, -1]) {
        g.add(box(3.6, 0.55, 0.5, MAT.dark, 0, 0.42, side * 1.05));       // track run
        g.add(box(3.7, 0.1, 0.62, camo, 0, 0.76, side * 1.05));           // fender skirt
        for (let w = -1.3; w <= 1.31; w += 0.65) {
          const wheel = cyl(0.27, 0.27, 0.14, MAT.metal, w, 0.3, side * 1.1, 9);
          wheel.rotation.x = Math.PI / 2; g.add(wheel); rememberRollingPart(g, wheel);
        }
      }
      // turret on a rotating mount — it tracks targets in combat
      const tur = new THREE.Group();
      tur.position.set(0.05, 1.42, 0);
      tur.add(box(1.5, 0.5, 1.25, camo, 0, 0.25, 0));
      tur.add(box(0.65, 0.28, 0.65, tm, -0.45, 0.62, 0)); // commander cupola in team colour
      const barrel = cyl(0.09, 0.12, 2.5, MAT.dark, 1.5, 0.28, 0, 8);
      barrel.rotation.z = Math.PI / 2; tur.add(barrel);
      const sleeve = cyl(0.14, 0.14, 0.8, camo, 1.25, 0.28, 0, 8);   // thermal sleeve
      sleeve.rotation.z = Math.PI / 2; tur.add(sleeve);
      tur.add(box(0.32, 0.2, 0.2, MAT.dark, 2.62, 0.28, 0));       // muzzle brake
      tur.add(box(1.0, 0.3, 0.35, MAT.dark, -0.85, 0.3, 0));        // bustle stowage rack
      // smoke grenade launchers angled off each turret cheek
      for (const side of [1, -1]) {
        for (const off of [0, 0.16]) {
          const tube = cyl(0.045, 0.045, 0.3, MAT.metal, 0.55 + off, 0.42, side * (0.68 + off * 0.4), 5);
          tube.rotation.set(side * 0.5, 0, -0.7); tur.add(tube);
        }
      }
      tur.add(cyl(0.015, 0.015, 0.9, MAT.dark, -0.55, 0.95, 0.35, 4)); // antenna
      g.add(tur);
      g.userData.turret = tur;
      break;
    }
    case 'artillery': {
      const camo = camoMat(color);
      g.add(box(3, 0.85, 1.95, camo, 0, 0.78, 0));
      // tracks + road wheels like a real SPG
      for (const side of [1, -1]) {
        g.add(box(3.3, 0.5, 0.45, MAT.dark, 0, 0.38, side * 1.0));
        for (let w = -1.15; w <= 1.16; w += 0.575) {
          const wheel = cyl(0.24, 0.24, 0.12, MAT.metal, w, 0.28, side * 1.03, 9);
          wheel.rotation.x = Math.PI / 2; g.add(wheel); rememberRollingPart(g, wheel);
        }
      }
      // gun house with team panel
      g.add(box(1.5, 0.75, 1.5, camo, -0.6, 1.55, 0));
      g.add(box(0.9, 0.2, 1.52, tm, -0.85, 2.0, 0));
      // howitzer: cradle, twin recoil cylinders, barrel + muzzle brake
      const cradle = box(0.9, 0.3, 0.6, MAT.metal, 0.4, 1.75, 0);
      cradle.rotation.z = -0.5; g.add(cradle);
      for (const side of [0.16, -0.16]) {
        const rec = cyl(0.06, 0.06, 1.1, MAT.metal, 0.75, 2.05, side, 6);
        rec.rotation.z = Math.PI / 2 - 0.5; g.add(rec);
      }
      const gun = cyl(0.13, 0.17, 3.3, MAT.dark, 1.15, 2.35, 0, 8);
      gun.rotation.z = Math.PI / 2 - 0.5; g.add(gun);
      const brake = cyl(0.2, 0.2, 0.35, MAT.dark, 2.52, 3.05, 0, 8);
      brake.rotation.z = Math.PI / 2 - 0.5; g.add(brake);
      break;
    }
    case 'helicopter': {
      const camo = camoMat(color);
      // fuselage with a rounded glass nose
      g.add(box(2.3, 1.05, 1.15, camo, 0.1, 1.05, 0));
      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.6, 10, 8), MAT.glass);
      nose.scale.set(1.25, 0.85, 0.95); nose.position.set(1.35, 1.15, 0);
      nose.castShadow = true; g.add(nose);
      g.add(box(0.8, 0.12, 1.2, tm, 0.1, 1.62, 0)); // team roof stripe
      // tail boom, fin and a real spinning tail rotor
      const boom = cyl(0.13, 0.26, 2.3, camo, -2.15, 1.3, 0, 7);
      boom.rotation.z = Math.PI / 2; g.add(boom);
      g.add(box(0.28, 0.95, 0.1, camo, -3.2, 1.75, 0)); // vertical fin
      const tailRotor = box(0.07, 1.05, 0.07, MAT.dark, -3.2, 1.85, 0.14);
      g.add(tailRotor); g.userData.tailRotor = tailRotor;
      // rotor mast + main blades
      g.add(cyl(0.08, 0.11, 0.4, MAT.dark, 0.1, 1.85, 0, 6));
      const rotor = new THREE.Group();
      rotor.position.set(0.1, 2.02, 0);
      rotor.add(box(4.8, 0.06, 0.28, MAT.dark, 0, 0, 0));
      rotor.add(box(0.28, 0.06, 4.8, MAT.dark, 0, 0, 0));
      g.add(rotor); g.userData.rotor = rotor;
      const rotorDisc = new THREE.Mesh(new THREE.CircleGeometry(2.45, 48),
        new THREE.MeshBasicMaterial({ color: 0xb9c7ce, transparent: true, opacity: 0.11, depthWrite: false, side: THREE.DoubleSide }));
      rotorDisc.rotation.x = -Math.PI / 2;
      rotorDisc.position.set(0.1, 2.04, 0);
      g.add(rotorDisc); g.userData.rotorDisc = rotorDisc;
      // landing skids on struts
      for (const side of [1, -1]) {
        g.add(box(2.5, 0.08, 0.08, MAT.metal, 0.1, 0.32, side * 0.58));
        g.add(cyl(0.04, 0.04, 0.45, MAT.metal, -0.5, 0.6, side * 0.55, 4));
        g.add(cyl(0.04, 0.04, 0.45, MAT.metal, 0.7, 0.6, side * 0.55, 4));
      }
      // stub wings with rocket pods
      for (const side of [1, -1]) {
        g.add(box(0.5, 0.1, 0.9, camo, 0.2, 0.95, side * 0.95));
        const pod = cyl(0.14, 0.14, 0.8, MAT.metal, 0.2, 0.78, side * 1.15, 7);
        pod.rotation.z = Math.PI / 2; g.add(pod);
      }
      break;
    }
    case 'jet': {
      const camo = camoMat(color);
      // fuselage + nose cone
      const body = cyl(0.34, 0.52, 3.4, camo, 0, 1, 0, 9);
      body.rotation.z = Math.PI / 2; g.add(body);
      const noseCone = new THREE.Mesh(new THREE.ConeGeometry(0.34, 1.1, 9), MAT.dark);
      noseCone.rotation.z = -Math.PI / 2; noseCone.position.set(2.2, 1, 0);
      noseCone.castShadow = true; g.add(noseCone);
      // bubble canopy
      const canopy = new THREE.Mesh(new THREE.SphereGeometry(0.4, 9, 7), MAT.glass);
      canopy.scale.set(1.7, 0.75, 0.8); canopy.position.set(0.9, 1.4, 0);
      canopy.castShadow = true; g.add(canopy);
      // real swept delta planform cut as one piece — leading edge raked back,
      // straight tips, forward-swept trailing edge like an actual fighter
      const wings = finMesh([
        [1.3, 0.3], [-0.45, 1.75], [-1.0, 1.8], [-0.75, 0.4],
        [-0.75, -0.4], [-1.0, -1.8], [-0.45, -1.75], [1.3, -0.3],
      ], 0.1, camo);
      wings.position.set(-0.3, 1, 0); g.add(wings);
      // team roundels on the outer wings
      for (const side of [1, -1]) {
        const mark = cyl(0.22, 0.22, 0.13, tm, -0.45, 1, side * 1.25, 10);
        g.add(mark);
      }
      // swept horizontal stabilizers, one piece
      const stabs = finMesh([
        [0.35, 0.2], [-0.5, 0.95], [-0.85, 0.98], [-0.6, 0.22],
        [-0.6, -0.22], [-0.85, -0.98], [-0.5, -0.95], [0.35, -0.2],
      ], 0.08, camo);
      stabs.position.set(-1.6, 1.05, 0); g.add(stabs);
      // twin canted fins
      for (const side of [1, -1]) {
        const fin = box(0.75, 0.85, 0.08, camo, -1.55, 1.6, side * 0.35);
        fin.rotation.x = side * -0.25; g.add(fin);
      }
      // afterburner: dark nozzle + glowing exhaust (bloom catches it)
      const nozzle = cyl(0.3, 0.24, 0.35, MAT.dark, -1.85, 1, 0, 9);
      nozzle.rotation.z = Math.PI / 2; g.add(nozzle);
      const burner = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.26, 0.16, 9),
        new THREE.MeshStandardMaterial({ color: 0xff8a3d, emissive: 0xff6a1f, emissiveIntensity: 1.4 }));
      burner.rotation.z = Math.PI / 2; burner.position.set(-2.02, 1, 0); g.add(burner);
      g.userData.afterburner = burner;
      break;
    }
    case 'drone': {
      const bodyMat = camoMat(color);
      const body = new THREE.Mesh(new THREE.SphereGeometry(0.62, 16, 10), bodyMat);
      body.scale.set(1.45, 0.5, 0.82); body.position.set(0, 1.2, 0); body.castShadow = true; g.add(body);
      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.34, 14, 9), MAT.glass);
      nose.scale.set(1.15, 0.55, 0.78); nose.position.set(0.72, 1.23, 0); nose.castShadow = true; g.add(nose);
      // X-frame arms meet the motors; the previous disconnected plus-sign
      // silhouette made the drone impossible to read from the RTS camera.
      for (const angle of [Math.PI / 4, -Math.PI / 4]) {
        const arm = box(3.15, 0.09, 0.13, MAT.dark, 0, 1.27, 0);
        arm.rotation.y = angle; g.add(arm);
      }
      const droneRotors = [];
      for (const [dx, dz] of [[-1.12, -1.12], [1.12, -1.12], [-1.12, 1.12], [1.12, 1.12]]) {
        const rotor = new THREE.Group();
        rotor.position.set(dx, 1.38, dz);
        rotor.add(cyl(0.15, 0.18, 0.18, MAT.metal, 0, -0.09, 0, 12));
        const ring = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.025, 6, 24), MAT.metal);
        ring.rotation.x = Math.PI / 2; ring.castShadow = true; rotor.add(ring);
        rotor.add(box(0.94, 0.025, 0.065, MAT.dark));
        rotor.add(box(0.065, 0.025, 0.94, MAT.dark));
        g.add(rotor); droneRotors.push(rotor);
      }
      g.userData.droneRotors = droneRotors;
      g.add(cyl(0.2, 0.24, 0.28, MAT.dark, 0.45, 0.8, 0, 12));
      const camera = new THREE.Mesh(new THREE.SphereGeometry(0.16, 12, 8), MAT.glass);
      camera.position.set(0.55, 0.68, 0); camera.castShadow = true; g.add(camera);
      for (const z of [-0.55, 0.55]) g.add(box(1.25, 0.06, 0.06, MAT.metal, -0.15, 0.58, z));
      break;
    }
    case 'gunboat': {
      // planing hull with a real curved bow, extruded from a deck plan
      const hull = shipHull(5.2, 1.8, 0.55, MAT.hull);
      hull.position.y = 0.95; g.add(hull);
      g.add(box(2.4, 0.35, 1.2, MAT.wall, -0.4, 1.12, 0)); // deck house
      g.add(box(1.05, 0.75, 0.95, tm, -0.7, 1.62, 0));     // bridge in team colour
      g.add(box(0.9, 0.3, 0.1, MAT.glass, -0.24, 1.72, 0)); // bridge glass
      // bow autocannon on a mount
      g.add(cyl(0.22, 0.28, 0.4, MAT.metal, 1.2, 1.18, 0, 7));
      const gun = cyl(0.07, 0.09, 1.35, MAT.dark, 1.85, 1.3, 0, 5);
      gun.rotation.z = Math.PI / 2; g.add(gun);
      g.add(cyl(0.03, 0.03, 1.1, MAT.metal, -1.3, 2.2, 0, 4)); // whip antenna
      const radar = new THREE.Group(); radar.position.set(-0.55, 2.35, 0);
      radar.add(box(0.75, 0.08, 0.12, MAT.metal, 0, 0, 0)); g.add(radar); g.userData.spin = radar;
      // side rails
      g.add(box(2.6, 0.05, 0.04, MAT.metal, -0.3, 1.4, 0.62));
      g.add(box(2.6, 0.05, 0.04, MAT.metal, -0.3, 1.4, -0.62));
      break;
    }
    case 'apc': {
      const camo = camoMat(color);
      // 6-wheeled armored car with a sloped hull and a small chain-gun turret
      g.add(box(3.4, 0.9, 1.7, camo, 0, 0.95, 0));
      const front = box(1.0, 0.7, 1.65, camo, 1.9, 0.85, 0);
      front.rotation.z = -0.4; g.add(front);
      for (const side of [1, -1]) {
        for (const wx of [-1.1, 0, 1.1]) {
          const wheel = cyl(0.34, 0.34, 0.25, MAT.dark, wx, 0.34, side * 0.92, 10);
          wheel.rotation.x = Math.PI / 2; g.add(wheel); rememberRollingPart(g, wheel);
        }
      }
      const tur = new THREE.Group();
      tur.position.set(-0.3, 1.5, 0);
      tur.add(box(0.8, 0.5, 0.9, camo, 0, 0.1, 0));
      tur.add(box(0.6, 0.12, 0.12, tm, 0.2, 0.35, 0)); // team marker
      const gun = cyl(0.05, 0.06, 1.2, MAT.dark, 0.7, 0.2, 0, 5);
      gun.rotation.z = Math.PI / 2; tur.add(gun);
      g.add(tur); g.userData.turret = tur;
      break;
    }
    case 'mlrs': {
      const camo = camoMat(color);
      g.add(box(3.2, 0.85, 1.9, camo, 0, 0.78, 0));
      for (const side of [1, -1]) {
        g.add(box(3.4, 0.5, 0.45, MAT.dark, 0, 0.38, side * 1.0));
        for (let w = -1.15; w <= 1.16; w += 0.575) {
          const wheel = cyl(0.24, 0.24, 0.12, MAT.metal, w, 0.28, side * 1.03, 9);
          wheel.rotation.x = Math.PI / 2; g.add(wheel); rememberRollingPart(g, wheel);
        }
      }
      g.add(box(1.1, 0.7, 1.4, camo, 1.0, 1.3, 0)); // cab
      g.add(box(0.9, 0.5, 0.1, MAT.glass, 1.5, 1.4, 0));
      // elevated rocket pod: a 4x2 grid of tubes
      const pod = new THREE.Group();
      pod.position.set(-0.8, 1.5, 0);
      pod.rotation.z = -0.35;
      for (let r2 = 0; r2 < 2; r2++) for (let c = 0; c < 4; c++) {
        const tube = cyl(0.11, 0.11, 1.7, MAT.wallDark, 0, 0, -0.42 + c * 0.28, 6);
        tube.rotation.x = Math.PI / 2;
        tube.position.y = 0.15 + r2 * 0.26;
        pod.add(tube);
      }
      pod.add(box(1.4, 0.7, 0.14, tm, 0, 0.13, -0.62)); // team backing plate
      g.add(pod); g.userData.turret = pod;
      break;
    }
    case 'gunship': {
      const camo = camoMat(color);
      // heavier, more armored attack helicopter with stub wing weapon pylons
      g.add(box(2.9, 1.1, 1.05, camo, 0.1, 1.1, 0));
      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.62, 10, 8), MAT.glass);
      nose.scale.set(1.3, 0.9, 0.9); nose.position.set(1.7, 1.15, 0); nose.castShadow = true; g.add(nose);
      g.add(box(0.5, 0.35, 0.5, MAT.dark, 1.9, 0.75, 0)); // chin cannon turret
      const chinGun = cyl(0.05, 0.05, 0.9, MAT.dark, 2.4, 0.7, 0, 5);
      chinGun.rotation.z = Math.PI / 2; g.add(chinGun);
      g.add(box(0.9, 0.14, 1.3, tm, 0.1, 1.68, 0));
      const boom = cyl(0.16, 0.3, 2.6, camo, -2.4, 1.35, 0, 7);
      boom.rotation.z = Math.PI / 2; g.add(boom);
      g.add(box(0.32, 1.1, 0.12, camo, -3.6, 1.85, 0));
      const tailRotor = box(0.08, 1.2, 0.08, MAT.dark, -3.6, 1.9, 0.16);
      g.add(tailRotor); g.userData.tailRotor = tailRotor;
      g.add(cyl(0.09, 0.12, 0.45, MAT.dark, 0.1, 1.9, 0, 6));
      const rotor = new THREE.Group();
      rotor.position.set(0.1, 2.12, 0);
      for (let b2 = 0; b2 < 4; b2++) {
        const blade = box(3.0, 0.06, 0.24, MAT.dark, 1.5, 0, 0);
        const arm = new THREE.Group(); arm.rotation.y = (b2 / 4) * Math.PI * 2;
        arm.add(blade); rotor.add(arm);
      }
      g.add(rotor); g.userData.rotor = rotor;
      // stub wings heavy with rocket pods & missiles
      for (const side of [1, -1]) {
        g.add(box(0.6, 0.12, 1.5, camo, 0.1, 0.9, side * 1.0));
        for (const px of [-0.3, 0.5]) {
          const pod = cyl(0.16, 0.16, 0.9, MAT.metal, px, 0.72, side * 1.35, 7);
          pod.rotation.z = Math.PI / 2; g.add(pod);
        }
      }
      // skids
      for (const side of [1, -1]) {
        g.add(box(2.4, 0.08, 0.09, MAT.metal, 0.1, 0.28, side * 0.62));
        g.add(cyl(0.045, 0.045, 0.5, MAT.metal, -0.6, 0.55, side * 0.6, 4));
        g.add(cyl(0.045, 0.045, 0.5, MAT.metal, 0.8, 0.55, side * 0.6, 4));
      }
      break;
    }
    case 'corvette': {
      // small fast missile boat: real knife-bow hull, single gun, angled missile cells, radar
      const hull = shipHull(6.6, 1.7, 0.6, MAT.hull);
      hull.position.y = 1.0; g.add(hull);
      g.add(box(2.2, 0.4, 1.1, MAT.metal, -0.4, 1.2, 0));  // low superstructure
      g.add(box(1.0, 0.75, 0.9, tm, -0.5, 1.75, 0));       // bridge in team colour
      g.add(box(0.85, 0.28, 0.1, MAT.glass, -0.05, 1.85, 0));
      g.add(cyl(0.22, 0.28, 0.35, MAT.metal, 1.7, 1.22, 0, 7)); // bow gun mount
      const gun = cyl(0.06, 0.08, 1.1, MAT.dark, 2.3, 1.32, 0, 5);
      gun.rotation.z = Math.PI / 2; g.add(gun);
      // angled missile canisters aft
      for (const zc of [-0.3, 0.3]) {
        const cell = box(1.1, 0.4, 0.4, MAT.wallDark, -1.7, 1.3, zc);
        cell.rotation.z = 0.4; g.add(cell);
      }
      const mast = cyl(0.05, 0.08, 1.3, MAT.metal, -0.5, 2.45, 0, 5);
      g.add(mast);
      const radar = box(0.7, 0.06, 0.12, MAT.metal, -0.5, 3.1, 0);
      g.add(radar); g.userData.spin = radar;
      break;
    }
    case 'nuclearSub': {
      // long black boat, larger sail, missile deck hump, cruciform tail, prop
      const hull = cyl(0.85, 0.85, 6.0, MAT.dark, 0, 0.3, 0, 14);
      hull.rotation.z = Math.PI / 2; g.add(hull);
      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.85, 12, 9), MAT.dark);
      nose.scale.x = 1.3; nose.position.set(3.0, 0.3, 0); nose.castShadow = true; g.add(nose);
      const tail = new THREE.Mesh(new THREE.ConeGeometry(0.85, 1.8, 12), MAT.dark);
      tail.rotation.z = Math.PI / 2; tail.position.set(-3.9, 0.3, 0); tail.castShadow = true; g.add(tail);
      // missile deck: raised hump with hatch circles
      const deck = box(3.2, 0.5, 1.3, MAT.dark, -0.3, 0.95, 0);
      g.add(deck);
      for (let i = 0; i < 5; i++)
        g.add(cyl(0.22, 0.22, 0.08, MAT.metal, -1.5 + i * 0.65, 1.22, 0, 10));
      // sail with team band, planes, periscope
      g.add(box(1.3, 1.1, 0.55, MAT.dark, 1.1, 1.2, 0));
      g.add(box(1.35, 0.14, 0.6, tm, 1.1, 1.75, 0));
      g.add(box(0.14, 0.06, 1.7, MAT.dark, 1.25, 1.35, 0));
      g.add(cyl(0.04, 0.04, 0.85, MAT.metal, 0.95, 2.2, 0, 4));
      // cruciform tail fins
      g.add(box(0.12, 0.06, 2.0, MAT.dark, -3.5, 0.3, 0));
      g.add(box(0.12, 1.7, 0.09, MAT.dark, -3.5, 0.3, 0));
      const prop = new THREE.Group();
      prop.position.set(-4.9, 0.3, 0);
      for (let b2 = 0; b2 < 7; b2++) {
        const blade = box(0.06, 0.55, 0.18, MAT.metal, 0, 0.24, 0);
        const arm = new THREE.Group(); arm.rotation.x = (b2 / 7) * Math.PI * 2;
        arm.add(blade); prop.add(arm);
      }
      g.add(prop); g.userData.prop = prop;
      break;
    }
    case 'destroyer': {
      // long grey warship on a real flared hull: layered superstructure, radar mast, VLS
      const hull = shipHull(9.4, 2.4, 0.8, MAT.hull);
      hull.position.y = 1.3; g.add(hull);
      g.add(box(4.6, 0.45, 1.7, MAT.metal, -0.5, 1.52, 0));  // main deck block
      g.add(box(2.2, 1.2, 1.4, MAT.wall, -0.6, 2.35, 0));    // superstructure block
      g.add(box(1.2, 0.8, 1.1, tm, -0.4, 3.35, 0));          // bridge in team colour
      g.add(box(1.0, 0.28, 0.1, MAT.glass, 0.2, 3.45, 0));   // bridge windows
      // angled radar mast + rotating bars
      const mast = cyl(0.09, 0.16, 1.9, MAT.dark, -1.5, 4.35, 0, 6);
      mast.rotation.z = 0.18; g.add(mast);
      const radar = box(1.1, 0.09, 0.16, MAT.metal, -1.65, 5.3, 0);
      g.add(radar); g.userData.spin = radar;
      // funnel with team band
      g.add(cyl(0.34, 0.42, 1.0, MAT.dark, -2.3, 2.55, 0, 8));
      g.add(cyl(0.36, 0.36, 0.2, tm, -2.3, 3.1, 0, 8));
      // enclosed fore & aft turrets
      for (const tx of [2.6, -3.4]) {
        g.add(box(0.95, 0.45, 0.9, MAT.metal, tx, 1.55, 0));
        g.add(box(0.5, 0.32, 0.5, MAT.wallDark, tx, 1.9, 0));
        const b = cyl(0.08, 0.11, 1.7, MAT.dark, tx + 0.95, 1.68, 0, 6);
        b.rotation.z = Math.PI / 2; g.add(b);
      }
      // VLS cell grid forward of the bridge
      g.add(box(1.0, 0.14, 1.2, MAT.dark, 1.2, 1.8, 0));
      // rails
      g.add(box(5.6, 0.05, 0.04, MAT.metal, -0.5, 1.84, 0.83));
      g.add(box(5.6, 0.05, 0.04, MAT.metal, -0.5, 1.84, -0.83));
      // rescue boat
      g.add(box(0.8, 0.25, 0.35, teamMat(0xc9622e), -2.9, 1.92, 0.6));
      break;
    }
  }
  // infantry are modelled facing +Z, vehicles/ships/aircraft nose-along +X —
  // faceOffset aligns each with its heading so nothing drives sideways.
  // (GLTF rigs set their own probed offset — don't overwrite it.)
  if (g.userData.faceOffset === undefined) {
    const infantryKeys = ['worker', 'soldier', 'rocketSoldier', 'sniper', 'commando'];
    g.userData.faceOffset = infantryKeys.includes(key) ? 0 : -Math.PI / 2;
  }
  // Small functional details keep silhouettes readable without neon team paint.
  if (['tank', 'artillery', 'apc', 'aaVehicle', 'samLauncher', 'mlrs'].includes(key)) {
    const headlightMat = new THREE.MeshStandardMaterial({
      color: 0xffe7b0, emissive: 0xffc46a, emissiveIntensity: 0.72, roughness: 0.25,
    });
    for (const z of [-0.55, 0.55]) g.add(box(0.08, 0.18, 0.22, headlightMat, 1.72, 0.78, z));
    const antenna = cyl(0.018, 0.024, 1.05 + (seed % 4) * 0.1, MAT.dark, -0.9, 1.85, 0.55, 5);
    antenna.rotation.z = (seed % 2 ? 1 : -1) * 0.08;
    g.add(antenna);
  }
  return g;
}

/* selection ring + hp bar attached to every entity */
function attachOverlays(ent, radius) {
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(radius * 0.9, radius * 1.08, 24),
    new THREE.MeshBasicMaterial({ color: 0x7dff8f, transparent: true, opacity: 0.85, side: THREE.DoubleSide, depthWrite: false })
  );
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = 0.15;
  ring.visible = false;
  ent.mesh.add(ring);
  ent.ring = ring;

  const barY = ent.type === 'building' ? radius * 1.3 + 3 : (UNITS[ent.key] && UNITS[ent.key].fly ? 3.2 : 3);
  const w = ent.type === 'building' ? radius * 1.2 : 1.6;
  const bg = new THREE.Mesh(new THREE.BoxGeometry(w, 0.22, 0.22), new THREE.MeshBasicMaterial({ color: 0x111111 }));
  bg.position.y = barY;
  const fg = new THREE.Mesh(new THREE.BoxGeometry(w, 0.26, 0.26), new THREE.MeshBasicMaterial({ color: 0x4dff6a }));
  fg.position.y = barY;
  bg.visible = fg.visible = false;
  ent.mesh.add(bg); ent.mesh.add(fg);
  ent.hpBg = bg; ent.hpFg = fg; ent.hpW = w;
}

function updateHpBar(ent) {
  const frac = clamp(ent.hp / ent.maxHp, 0, 1);
  const show = frac < 1 || ent.selected;
  ent.hpBg.visible = ent.hpFg.visible = show;
  if (show) {
    ent.hpFg.scale.x = Math.max(frac, 0.001);
    ent.hpFg.position.x = -ent.hpW * (1 - frac) / 2;
    ent.hpFg.material.color.setHex(frac > 0.55 ? 0x4dff6a : frac > 0.25 ? 0xffd24d : 0xff5d5d);
  }
}

/* ---------------- spawning ---------------- */
function spawnBuilding(key, owner, x, z, opts = {}) {
  const def = BUILDINGS[key];
  const nat = G.nations[owner];
  const ent = {
    id: ENT_ID++, type: 'building', key, def, owner,
    x, z, hp: opts.instant ? def.hp : 1, maxHp: def.hp,
    built: !!opts.instant, progress: opts.instant ? 1 : 0,
    queue: [], queueProg: 0, selected: false, dead: false,
    deposit: opts.deposit || null,
  };
  ent.mesh = buildingMesh(key, nat.color, ent.id);
  const atSea = ent.deposit && ent.deposit.def.water;
  ent.mesh.position.set(x, atSea ? SEA_LEVEL : terrainH(x, z), z);
  ent.mesh.userData.entity = ent;
  if (!atSea) {
    // Only uneven ground needs a buried plinth. Flat sites no longer get the
    // conspicuous square/circular "game piece" base seen under old buildings.
    const probe = def.size * 0.38;
    const samples = [
      terrainH(x - probe, z - probe), terrainH(x + probe, z - probe),
      terrainH(x - probe, z + probe), terrainH(x + probe, z + probe),
    ];
    const relief = Math.max(...samples) - Math.min(...samples);
    if (relief > 0.24) {
      const depth = Math.min(1.35, relief + 0.28);
    const foundation = new THREE.Mesh(
        new THREE.CylinderGeometry(def.size * 0.52, def.size * 0.58, depth, 24),
      MAT.concrete);
      foundation.position.y = 0.04 - depth * 0.5;
    foundation.receiveShadow = true;
    ent.mesh.add(foundation);
    }
  }
  // construction clears whatever forest is left in the footprint (AI builds this way; players clear first)
  treesNear(x, z, def.size + 1).forEach(removeTree);
  navBlockBuilding(ent, true); // units must path around the construction site
  if (!ent.built) ent.mesh.scale.y = 0.15;
  attachOverlays(ent, def.size);
  if (def.settlement && def.buildRadius) {
    const zone = new THREE.Mesh(
      new THREE.RingGeometry(def.buildRadius - 0.45, def.buildRadius, 96),
      new THREE.MeshBasicMaterial({ color: owner === 0 ? 0x63bfff : nat.color, transparent: true, opacity: 0.55, side: THREE.DoubleSide, depthWrite: false })
    );
    zone.rotation.x = -Math.PI / 2;
    zone.position.y = 0.18;
    zone.visible = false;
    ent.mesh.add(zone);
    ent.districtRing = zone;
  }
  scene.add(ent.mesh);
  G.buildings.push(ent);
  if (def.settlement) ent.settlementName = settlementDisplayName(ent);
  if (ent.deposit) ent.deposit.hasExtractor = true;
  return ent;
}

function spawnUnit(key, owner, x, z) {
  const def = UNITS[key];
  const nat = G.nations[owner];
  const ent = {
    id: ENT_ID++, type: 'unit', key, def, owner,
    x, z,
    hp: def.hp * statHpMult(owner) * (owner === 0 ? unitTechHpMult(key) : 1),
    maxHp: def.hp * statHpMult(owner) * (owner === 0 ? unitTechHpMult(key) : 1),
    state: 'idle', tx: x, tz: z, target: null, cool: 0,
    buildTarget: null, harvestDep: null, retarget: Math.random() * 0.5,
    selected: false, dead: false,
  };
  ent.mesh = unitMesh(key, nat.color, ent.id);
  ent.mesh.position.set(x, def.naval ? SEA_LEVEL + 0.15 : terrainH(x, z) + def.fly, z);
  ent.mesh.userData.entity = ent;
  attachOverlays(ent, def.naval ? 2.4 : 1.3);
  scene.add(ent.mesh);
  G.units.push(ent);
  return ent;
}

/* ---------------- stat modifiers ---------------- */
/* aggregate all fx modifiers from the player's completed discoveries.
   Recomputed once per city tick (and on purchase) into G.fx. */
function recalcDiscoveryFx() {
  const fx = {};
  for (const [k, d] of Object.entries(DISCOVERIES)) {
    if (!G.discovered[k] || !d.fx) continue;
    for (const [key, v] of Object.entries(d.fx)) fx[key] = (fx[key] || 0) + v;
  }
  G.fx = fx;
  return fx;
}
function fxv(key) { return (G.fx && G.fx[key]) || 0; }

/* broad unit class for tech bonuses */
function unitClassOf(key) {
  const def = UNITS[key];
  if (!def) return 'other';
  if (def.naval) return 'naval';
  if (def.fly) return 'air';
  if (['soldier', 'rocketSoldier', 'sniper', 'commando'].includes(key)) return 'infantry';
  if (['tank', 'apc', 'artillery', 'mlrs', 'aaVehicle', 'samLauncher'].includes(key)) return 'vehicle';
  return 'other';
}
function unitTechDmgMult(u) {
  if (u.owner !== 0) return 1;
  const cls = unitClassOf(u.key);
  let m = 1 + fxv('dmgAll');
  if (cls === 'infantry') m += fxv('dmgInfantry');
  else if (cls === 'air') m += fxv('dmgAir');
  else if (cls === 'naval') m += fxv('dmgNaval');
  if (u.key === 'artillery' || u.key === 'mlrs') m += fxv('dmgArty');
  if (u.key === 'drone') m += fxv('dmgDrone');
  return m;
}
function unitTechHpMult(key) {
  const cls = unitClassOf(key);
  if (cls === 'infantry') return 1 + fxv('hpInfantry');
  if (cls === 'vehicle') return 1 + fxv('hpVehicle');
  return 1;
}
function unitTechSpeedMult(u) {
  if (u.owner !== 0) return 1;
  const cls = unitClassOf(u.key);
  if (cls === 'air') return 1 + fxv('spdAir');
  if (cls === 'naval') return 1 + fxv('spdNaval');
  return 1 + fxv('spdGround');
}
function unitTechRangeMult(u) {
  if (u.owner !== 0) return 1;
  if (u.key === 'artillery' || u.key === 'mlrs') return 1 + fxv('rangeArty');
  if (unitClassOf(u.key) === 'naval') return 1 + fxv('rangeNaval');
  return 1;
}
function unitTechCost(key) {
  const def = UNITS[key];
  const cls = unitClassOf(key);
  let mult = 1;
  if (cls === 'vehicle' || cls === 'naval') mult += fxv('costVehiclePct');
  if (key === 'drone') mult += fxv('costDronePct');
  if (mult === 1) return def.cost;
  const c = {};
  for (const [k, v] of Object.entries(def.cost)) c[k] = Math.round(v * mult);
  return c;
}

function govMod(key) {
  let m = 0;
  const gov = GOVERNMENTS[G.gov.form];
  if (gov[key]) m += gov[key];
  const tr = LEADER_TRAITS[G.gov.leader.trait];
  if (tr[key]) m += tr[key];
  // the leader's flaw pulls the other way
  if (G.gov.leader.flaw) {
    const fl = LEADER_FLAWS[G.gov.leader.flaw];
    if (fl && fl[key]) m += fl[key];
  }
  return m;
}
function statHpMult(owner) {
  if (owner !== 0) return 1;
  let m = 1 + G.tech.military * 0.08;
  if (G.buildings.some(b => b.owner === 0 && b.built && b.key === 'commandCenter' && !b.dead)) m += 0.10;
  return m;
}
function statDmgMult(owner) {
  if (owner !== 0) {
    const nat = G.nations[owner];
    // AI military tech makes its army hit harder; a purged general weakens it
    return (nat.debuffGeneral > G.time ? 0.7 : 1) * (1 + (nat.aiTech || 0) * 0.03);
  }
  let m = 1 + G.tech.military * 0.08 + govMod('dmgPct');
  const depots = G.buildings.filter(b => b.owner === 0 && b.built && b.key === 'ammoDepot' && !b.dead).length;
  m += Math.min(depots * 0.05, 0.25);
  let morale = G.city.morale;
  if (G.gov.instabilityUntil > G.time) morale = Math.max(0, morale - 10);
  m *= 0.7 + morale / 200; // morale 0..100 → x0.7..x1.2
  return m;
}
/* production & construction speed (player only) */
function prodSpeedMult(owner) {
  if (owner !== 0) return 1;
  const plants = Math.min(playerBuildingCount('powerPlant'), 2);
  const fueledReactors = G.buildings.filter(b =>
    b.owner === 0 && b.built && !b.dead && b.key === 'nuclearReactor' && b.fueled).length;
  const powerFactor = (G.city.power && G.city.power.factor) || 1;
  const eraBonus = ((G.development && G.development.era) || 0) * 0.03;
  return (1 + plants * 0.15 + Math.min(fueledReactors, 2) * 0.20 + eraBonus + govMod('prodPct') + civicMod('prodPct') + fxv('prodPct')) * powerFactor;
}

/* ---------------- damage & death ---------------- */
function dealDamage(target, amount, attacker) {
  if (target.dead) return;
  // stealth coating: your aircraft shrug off 30% of incoming fire
  if (target.type === 'unit' && target.def.fly && target.owner === 0 && G.discovered.stealthTech) amount *= 0.7;
  // bunkers shelter nearby friendly infantry
  if (target.type === 'unit' && targetClass(target) === 'infantry') {
    const sheltered = G.buildings.some(b => !b.dead && b.built && b.key === 'bunker'
      && b.owner === target.owner && dist2d(b.x, b.z, target.x, target.z) < b.def.auraRadius);
    if (sheltered) amount *= 0.7;
  }
  target.hp -= amount;
  // auto war declaration when someone actually shoots someone
  if (attacker && attacker.owner !== undefined && attacker.owner !== target.owner) ensureWar(attacker.owner, target.owner);
  if (target.hp <= 0) killEntity(target);
}

function killEntity(ent) {
  if (ent.dead) return;
  ent.dead = true;
  spawnExplosion(ent.mesh.position.x, ent.mesh.position.y + 1, ent.mesh.position.z,
    ent.type === 'building' ? ent.def.size * 0.9 : 2.2);
  // reactor MELTDOWN — a destroyed reactor is a small nuke (Fusion Power makes yours safe)
  if (ent.type === 'building' && ent.key === 'nuclearReactor' && ent.built
      && !(ent.owner === 0 && G.discovered.fusionPower)) {
    spawnExplosion(ent.x, ent.mesh.position.y + 6, ent.z, 26);
    notify('☢️ REACTOR MELTDOWN! The blast devastates everything nearby.', 'bad', 8);
    for (const o of [...G.units, ...G.buildings]) {
      if (o.dead || o === ent) continue;
      const d = dist2d(o.x, o.z, ent.x, ent.z);
      if (d < 30) dealDamage(o, 1200 * (1 - 0.5 * d / 30), null);
    }
  }
  if (ent.type === 'unit') {
    // death animation: troops & vehicles keel over, aircraft fall out of the sky, ships sink
    if (ent.ring) ent.ring.visible = false;
    if (ent.hpBar) ent.hpBar.visible = false;
    if (ent.bar) ent.bar.visible = false;
    G.effects.push({ obj: ent.mesh, ttl: 1.6, max: 1.6, kind: 'corpse', fly: !!ent.def.fly, naval: !!ent.def.naval });
  } else {
    scene.remove(ent.mesh);
  }
  const idx = G.selection.indexOf(ent);
  if (idx >= 0) G.selection.splice(idx, 1);
  if (ent.type === 'building') {
    navBlockBuilding(ent, false); // free the nav grid so units path through the ruins
    if (ent.deposit) ent.deposit.hasExtractor = false;
    if (ent.key === 'hq') onHQDestroyed(ent.owner);
    else if (ent.owner === 0) notify(`Your ${ent.def.name} was destroyed!`, 'bad');
  }
  if (ent.harvestDep) {
    const wi = ent.harvestDep.workers.indexOf(ent);
    if (wi >= 0) ent.harvestDep.workers.splice(wi, 1);
  }
}

/* ---------------- effects (tracers, explosions) ---------------- */
function spawnTracer(ax, ay, az, bx, by, bz, color = 0xfff2aa) {
  const geo = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(ax, ay, az), new THREE.Vector3(bx, by, bz)]);
  const line = new THREE.Line(geo, new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.9 }));
  scene.add(line);
  G.effects.push({ obj: line, ttl: 0.1, kind: 'tracer' });
}
function spawnExplosion(x, y, z, size) {
  const mat = new THREE.MeshBasicMaterial({ color: 0xff8a32, transparent: true, opacity: 0.78, depthWrite: false });
  const s = new THREE.Mesh(new THREE.SphereGeometry(size * 0.5, 12, 9), mat);
  s.position.set(x, y, z);
  s.scale.setScalar(0.28);
  scene.add(s);
  G.effects.push({ obj: s, ttl: 0.52, max: 0.52, kind: 'boom', finalScale: size > 12 ? 2.15 : 1.65 });
  // rising smoke puffs give the blast some weight
  const puffs = size > 6 ? 3 : 2;
  for (let i = 0; i < puffs; i++) {
    const smoke = new THREE.Mesh(new THREE.SphereGeometry(size * 0.3, 7, 5),
      new THREE.MeshLambertMaterial({ color: 0x39352f, transparent: true, opacity: 0.55 }));
    smoke.position.set(x + (Math.random() - 0.5) * size * 0.5, y + size * 0.2, z + (Math.random() - 0.5) * size * 0.5);
    scene.add(smoke);
    G.effects.push({ obj: smoke, ttl: 1.1 + Math.random() * 0.4, max: 1.5, kind: 'smoke', rise: size * 0.8 });
  }
}
/* white wake discs behind ships / contrail puffs behind aircraft.
   Meshes and materials are POOLED — ships shed several per second, and
   allocating fresh GPU objects each time caused steady GC hitches. */
const _wakeGeo = new THREE.PlaneGeometry(1, 1);
const _puffGeo = new THREE.SphereGeometry(0.5, 6, 5);
const _wakePool = [], _puffPool = [], _dustPool = [];
function _pooledEffect(pool, geo, color, baseOpacity) {
  let m = pool.pop();
  if (!m) {
    m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({
      color, transparent: true, opacity: baseOpacity, depthWrite: false }));
    m.userData.pooled = pool;
  }
  m.material.opacity = baseOpacity;
  m.visible = true;
  return m;
}
function spawnWake(x, y, z, isSea, heading) {
  if (isSea) {
    const m = _pooledEffect(_wakePool, _wakeGeo, 0xdff2f6, 0.4);
    // stretch the foam quad along the ship's course so wakes trail as a V
    m.rotation.set(-Math.PI / 2, 0, heading !== undefined ? heading : 0);
    m.position.set(x, y, z);
    m.scale.set(heading !== undefined ? 2.4 : 1.1, 1.0, 1);
    scene.add(m);
    G.effects.push({ obj: m, ttl: 2.2, max: 2.2, kind: 'wake', keepGeo: true, pooled: true });
  } else {
    const m = _pooledEffect(_puffPool, _puffGeo, 0xffffff, 0.32);
    m.position.set(x, y, z);
    m.scale.setScalar(0.5);
    scene.add(m);
    G.effects.push({ obj: m, ttl: 1.4, max: 1.4, kind: 'puff', keepGeo: true, pooled: true });
  }
}

function spawnDust(x, y, z) {
  const m = _pooledEffect(_dustPool, _puffGeo, 0xb79b74, 0.2);
  m.position.set(x, y, z);
  m.scale.set(0.42, 0.24, 0.42);
  scene.add(m);
  G.effects.push({ obj: m, ttl: 0.9, max: 0.9, kind: 'dust', keepGeo: true, pooled: true });
}

/* short bright flash at a shooter's muzzle */
function spawnMuzzleFlash(x, y, z) {
  const flash = new THREE.Mesh(new THREE.SphereGeometry(0.35, 6, 5),
    new THREE.MeshBasicMaterial({ color: 0xfff3b0, transparent: true, opacity: 1 }));
  flash.position.set(x, y, z);
  scene.add(flash);
  G.effects.push({ obj: flash, ttl: 0.07, kind: 'tracer' });
}
function updateEffects(dt) {
  for (let i = G.effects.length - 1; i >= 0; i--) {
    const e = G.effects[i];
    e.ttl -= dt;
    if (e.kind === 'boom') {
      const progress = clamp(1 - e.ttl / e.max, 0, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      e.obj.scale.setScalar(0.28 + eased * (e.finalScale - 0.28));
      e.obj.material.opacity = 0.78 * Math.pow(1 - progress, 1.6);
    } else if (e.kind === 'tracer') {
      e.obj.material.opacity = Math.max(0, e.ttl / 0.1);
    } else if (e.kind === 'smoke') {
      e.obj.position.y += e.rise * dt;
      e.obj.scale.multiplyScalar(1 + dt * 1.6);
      e.obj.material.opacity = Math.max(0, 0.55 * (e.ttl / e.max));
    } else if (e.kind === 'wake') {
      e.obj.scale.multiplyScalar(1 + dt * 1.4);
      e.obj.material.opacity = 0.4 * (e.ttl / e.max);
    } else if (e.kind === 'puff') {
      e.obj.scale.multiplyScalar(1 + dt * 0.8);
      e.obj.material.opacity = 0.32 * (e.ttl / e.max);
    } else if (e.kind === 'dust') {
      e.obj.position.y += dt * 0.18;
      e.obj.scale.multiplyScalar(1 + dt * 1.15);
      e.obj.material.opacity = 0.2 * Math.pow(e.ttl / e.max, 1.35);
    } else if (e.kind === 'mushStem') {
      e.obj.position.y += e.rise * dt * 0.4;
      e.obj.scale.x = e.obj.scale.z = 1 + (1 - e.ttl / e.max) * 0.6;
      e.obj.material.opacity = 0.85 * Math.min(1, e.ttl / 2.5);
    } else if (e.kind === 'mushCap') {
      e.obj.position.y += e.rise * dt * 0.55;
      e.obj.scale.x = e.obj.scale.z = 1 + (1 - e.ttl / e.max) * 1.4;
      e.obj.material.opacity = 0.9 * Math.min(1, e.ttl / 2.5);
    } else if (e.kind === 'corpse') {
      if (e.fly) { // shot-down aircraft spiral into the ground
        e.obj.position.y = Math.max(terrainH(e.obj.position.x, e.obj.position.z) + 0.3, e.obj.position.y - 26 * dt);
        e.obj.rotation.z += dt * 4;
      } else if (e.naval) { // ships slip under the waves
        e.obj.position.y -= dt * 1.8;
        e.obj.rotation.z += dt * 0.5;
      } else { // soldiers & vehicles keel over and sink into the earth
        e.obj.rotation.z = Math.min(e.obj.rotation.z + dt * 2.6, 1.4);
        e.obj.position.y -= dt * 0.8;
      }
    }
    if (e.ttl <= 0) {
      scene.remove(e.obj);
      if (e.pooled && e.obj.userData.pooled) {
        e.obj.userData.pooled.push(e.obj); // recycle wakes/puffs — no dispose, no realloc
      } else {
        if (!e.keepGeo && e.obj.geometry) e.obj.geometry.dispose();
        e.obj.material && e.obj.material.dispose();
      }
      G.effects.splice(i, 1);
    }
  }
}

/* ---------------- missiles ---------------- */
function missileCap() {
  return BASE_MISSILE_CAP + playerBuildingCount('ammoDepot') * 4;
}
function missileStock() {
  return Object.values(G.munitions).reduce((s, v) => s + (v || 0), 0);
}

function makeMissileMesh(type, color) {
  const g = new THREE.Group();
  if (!MISSILES[type].arc) {
    const body = cyl(0.25, 0.3, 2.6, teamMat(0xd8dde2), 0, 0, 0, 8);
    body.rotation.z = Math.PI / 2; g.add(body);
    g.add(box(0.1, 0.1, 1.6, teamMat(color), -0.4, 0, 0)); // wings
    g.add(box(0.5, 0.5, 0.1, teamMat(color), -1.2, 0.2, 0));
  } else if (type === 'nuke') {
    // unmistakably nuclear: fat white body, hazard-red nose & bands
    const body = cyl(0.6, 0.7, 4.6, teamMat(0xf2f4f6), 0, 0, 0, 12);
    g.add(body);
    const nose = new THREE.Mesh(new THREE.ConeGeometry(0.6, 1.5, 12), teamMat(0xd12b2b));
    nose.position.y = 3.0; g.add(nose);
    g.add(cyl(0.72, 0.72, 0.3, teamMat(0xd12b2b), 0, 1.2, 0, 12));   // warning band
    g.add(cyl(0.74, 0.74, 0.3, teamMat(0x1c1f24), 0, -1.6, 0, 12));  // dark band
    for (const a of [0, Math.PI / 2, Math.PI, Math.PI * 1.5])
      g.add(box(0.14, 1.2, 0.9, teamMat(0xd12b2b), Math.cos(a) * 0.6, -2.0, Math.sin(a) * 0.6));
  } else {
    const body = cyl(0.45, 0.55, 4.2, teamMat(0xb9c2cc), 0, 0, 0, 10);
    g.add(body);
    const nose = new THREE.Mesh(new THREE.ConeGeometry(0.45, 1.2, 10), teamMat(color));
    nose.position.y = 2.7; g.add(nose);
    for (const a of [0, Math.PI / 2, Math.PI, Math.PI * 1.5])
      g.add(box(0.12, 1, 0.7, teamMat(color), Math.cos(a) * 0.5, -1.8, Math.sin(a) * 0.5));
  }
  // exhaust glow
  const glow = new THREE.Mesh(new THREE.SphereGeometry(0.5, 6, 5),
    new THREE.MeshBasicMaterial({ color: 0xffb347, transparent: true, opacity: 0.85 }));
  glow.position.set(type === 'cruise' ? 1.5 : 0, type === 'cruise' ? 0 : -2.4, 0);
  g.add(glow);
  return g;
}

function launchMissile(type, fromX, fromZ, tx, tz) {
  const def = MISSILES[type];
  const nuclear = type === 'nuke'; // nukes are their own weapon now — ballistics stay conventional
  const dist = dist2d(fromX, fromZ, tx, tz);
  const m = {
    type, nuclear, owner: 0,
    x: fromX, z: fromZ, tx, tz,
    sx: fromX, sz: fromZ,
    t: 0, dur: def.arc ? clamp(dist / def.speed, 2.5, 9) : dist / def.speed,
    dmg: nuclear ? 4500 : def.dmg,
    radius: nuclear ? 38 : def.radius,
    special: def.special || null,
    mesh: makeMissileMesh(type, G.nations[0].color),
  };
  m.mesh.position.set(fromX, terrainH(fromX, fromZ) + 3, fromZ);
  scene.add(m.mesh);
  G.missilesInFlight.push(m);
  notify(nuclear
    ? `☢️ NUCLEAR ${def.name} launched — 1 nuke removed from stockpile (${G.munitions.nuke} left).`
    : `${def.icon} ${def.name} launched (conventional warhead).`, 'warn', 5);
}

function updateMissiles(dt) {
  for (let i = G.missilesInFlight.length - 1; i >= 0; i--) {
    const m = G.missilesInFlight[i];
    m.t += dt;
    const f = clamp(m.t / m.dur, 0, 1);
    const x = lerp(m.sx, m.tx, f);
    const z = lerp(m.sz, m.tz, f);
    let y;
    if (MISSILES[m.type].arc) {
      const apex = 130;
      y = terrainH(m.sx, m.sz) + 3 + Math.sin(f * Math.PI) * apex;
      m.mesh.rotation.z = lerp(0, -Math.PI, f); // tips over
    } else {
      y = Math.max(terrainH(x, z), SEA_LEVEL) + 9;
      m.mesh.rotation.y = Math.atan2(m.tx - m.sx, m.tz - m.sz) - Math.PI / 2;
    }
    m.mesh.position.set(x, y, z);
    if (f >= 1) {
      scene.remove(m.mesh);
      G.missilesInFlight.splice(i, 1);
      missileImpact(m);
    }
  }
}

/* nuclear-only: rising fireball column topped by a spreading mushroom cap */
function spawnMushroomCloud(x, y, z, size) {
  const stem = new THREE.Mesh(new THREE.CylinderGeometry(size * 0.16, size * 0.24, size * 0.9, 10),
    new THREE.MeshLambertMaterial({ color: 0x4a4238, transparent: true, opacity: 0.85 }));
  stem.position.set(x, y + size * 0.45, z);
  scene.add(stem);
  G.effects.push({ obj: stem, ttl: 6, max: 6, kind: 'mushStem', rise: size * 0.4 });
  const cap = new THREE.Mesh(new THREE.SphereGeometry(size * 0.42, 12, 9),
    new THREE.MeshLambertMaterial({ color: 0x5a4f42, emissive: 0x7a3a12, transparent: true, opacity: 0.9 }));
  cap.scale.y = 0.55;
  cap.position.set(x, y + size * 0.95, z);
  scene.add(cap);
  G.effects.push({ obj: cap, ttl: 6, max: 6, kind: 'mushCap', rise: size * 0.5 });
}

function missileImpact(m) {
  const def = MISSILES[m.type];
  const iy = Math.max(terrainH(m.tx, m.tz), SEA_LEVEL);
  spawnExplosion(m.tx, iy + 2, m.tz, m.radius * 0.8);
  if (m.nuclear) {
    spawnExplosion(m.tx, iy + m.radius * 0.5, m.tz, m.radius * 1.3);
    spawnMushroomCloud(m.tx, iy, m.tz, m.radius);
  }
  const hitOwners = new Set();
  const applyAoe = ent => {
    const d = dist2d(ent.x, ent.z, m.tx, m.tz);
    if (d > m.radius) return;
    hitOwners.add(ent.owner);
    let mult = 1;
    if (def.special === 'cluster') mult = ent.type === 'building' ? 0.35 : 1.75;
    if (def.special === 'antiShip') mult = ent.type === 'unit' && ent.def.naval ? 3.0 : 0.25;
    if (def.special === 'emp') {
      if (ent.type === 'building' || ent.def.fly || ent.def.naval || targetClass(ent) === 'armor' || targetClass(ent) === 'light') {
        ent.disabledUntil = Math.max(ent.disabledUntil || 0, G.time + 35);
      }
      mult = ent.type === 'building' ? 0.25 : 0.45;
    }
    dealDamage(ent, m.dmg * mult * (1 - 0.5 * (d / m.radius)), { owner: m.owner });
  };
  [...G.units].forEach(u => { if (!u.dead) applyAoe(u); });
  [...G.buildings].forEach(b => { if (!b.dead) applyAoe(b); });
  if (m.nuclear) {
    // the whole world condemns nuclear strikes
    for (let i = 1; i < G.nations.length; i++) {
      if (!G.nations[i].defeated) changeRel(0, i, -30);
    }
    notify('☢️ The world condemns your nuclear strike. Relations with ALL nations damaged.', 'bad', 8);
  }
}

/* ---------------- unit brain ---------------- */
function commandMove(units, x, z, attackMove = false) {
  const n = Math.ceil(Math.sqrt(units.length));
  units.forEach((u, i) => {
    if (u.dead) return;
    if (u.state === 'landed' && !launchPlane(u)) return; // scramble from the apron
    u.returning = false;
    const ox = (i % n - (n - 1) / 2) * 3.2;
    const oz = (Math.floor(i / n) - (n - 1) / 2) * 3.2;
    u.tx = clamp(x + ox, -HALF_MAP + 5, HALF_MAP - 5);
    u.tz = clamp(z + oz, -HALF_MAP + 5, HALF_MAP - 5);
    u.state = attackMove ? 'attackMove' : 'move';
    u.target = null; u.buildTarget = null;
    u.guardX = null; u.guardZ = null;
    u.path = null; u.pathGoal = null; u.nextPathAt = 0; u.stuckT = 0; u.repathFails = 0;
    clearHarvest(u);
  });
}
function commandAttack(units, target) {
  units.forEach(u => {
    if (u.dead || u.def.dmg <= 0) return;
    if (u.state === 'landed' && !launchPlane(u)) return;
    u.returning = false;
    u.target = target; u.state = 'attack';
    u.guardX = null; u.guardZ = null;
    u.buildTarget = null; clearHarvest(u);
  });
}
function commandHarvest(worker, dep) {
  clearHarvest(worker);
  worker.guardX = null; worker.guardZ = null;
  worker.harvestDep = dep;
  worker.state = 'toHarvest';
  worker.tx = dep.x + (Math.random() - 0.5) * 6;
  worker.tz = dep.z + (Math.random() - 0.5) * 6;
  worker.target = null; worker.buildTarget = null;
}
function clearHarvest(u) {
  if (u.harvestDep) {
    const i = u.harvestDep.workers.indexOf(u);
    if (i >= 0) u.harvestDep.workers.splice(i, 1);
    u.harvestDep = null;
  }
  u.chopTarget = null;
  u.path = null; u.pathGoal = null; u.nextPathAt = 0; u.stuckT = 0;
}

/* send a worker to clear a patch of forest (frees land, sells lumber) */
function commandChop(worker, tree) {
  clearHarvest(worker);
  worker.guardX = null; worker.guardZ = null;
  worker.chopTarget = tree;
  worker.chopProg = 0;
  worker.state = 'toChop';
  worker.tx = tree.x; worker.tz = tree.z;
  worker.target = null; worker.buildTarget = null;
}

/* ---------------- air base operations (jets & bombers) ---------------- */
function landPlane(u) {
  u.state = 'landed';
  u.target = null; u.path = null;
  if (u.homeBase && !u.homeBase.dead) {
    u.x = u.homeBase.x; u.z = u.homeBase.z;
  }
  u.mesh.visible = true;
}
function launchPlane(u) {
  if (u.state !== 'landed') return true;
  if ((u.fuel || 0) < PLANE_FUEL * 0.25) {
    if (u.owner === 0) notify(`${u.def.name} is still refueling.`, 'warn');
    return false;
  }
  u.state = 'idle';
  return true;
}
/* send an out-of-fuel or idle plane home; land it when it arrives */
function planeReturnHome(u) {
  if (!u.homeBase || u.homeBase.dead) {
    // base gone — find another friendly airfield, else the plane is grounded-in-place
    u.homeBase = G.buildings.find(b => !b.dead && b.built && b.key === 'airfield' && b.owner === u.owner) || null;
    if (!u.homeBase) return;
  }
  u.returning = true;
  u.tx = u.homeBase.x; u.tz = u.homeBase.z;
  u.state = 'move';
  u.target = null;
}

/* combat realism: every weapon has sensible target classes.
   This prevents riflemen from destroying tanks/aircraft by attrition. */
const DAMAGE_PROFILE = {
  worker:        { infantry: 0,    light: 0,    armor: 0,    air: 0,   naval: 0,   building: 0 },
  soldier:       { infantry: 1.0,  light: 0.45, armor: 0.15, air: 0,   naval: 0,   building: 0.25 },
  rocketSoldier: { infantry: 0.55, light: 1.0,  armor: 1.65, air: 0.7, naval: 0.45, building: 0.75 },
  sniper:        { infantry: 1.8,  light: 0.22, armor: 0.05, air: 0,   naval: 0,   building: 0.05 },
  commando:      { infantry: 1.25, light: 0.75, armor: 0.35, air: 0,   naval: 0.15, building: 0.65 },
  tank:          { infantry: 0.9,  light: 1.1,  armor: 1.0,  air: 0,   naval: 0.2, building: 1.15 },
  artillery:     { infantry: 1.15, light: 1.05, armor: 0.85, air: 0,   naval: 0.45, building: 1.6 },
  aaVehicle:     { infantry: 0.45, light: 0.4,  armor: 0.18, air: 3.4, naval: 0.1, building: 0.18 },
  samLauncher:   { infantry: 0.08, light: 0.12, armor: 0.08, air: 5.2, naval: 0.05, building: 0.05 },
  helicopter:    { infantry: 1.2,  light: 1.0,  armor: 0.75, air: 0,   naval: 0.45, building: 0.75 },
  jet:           { infantry: 0.9,  light: 1.1,  armor: 1.05, air: 1.4, naval: 0.75, building: 0.9 },
  bomber:        { infantry: 1.5,  light: 1.25, armor: 1.0,  air: 0,   naval: 0.8, building: 1.8 },
  drone:         { infantry: 0.95, light: 0.75, armor: 0.2,  air: 0.45, naval: 0.2, building: 0.35 },
  gunboat:       { infantry: 0.65, light: 0.8,  armor: 0.45, air: 1.5, naval: 0.9, building: 0.85 },
  submarine:     { infantry: 0,    light: 0,    armor: 0,    air: 0,   naval: 2.0, building: 0 },
  destroyer:     { infantry: 1.0,  light: 1.0,  armor: 0.8,  air: 1.25, naval: 1.25, building: 1.25 },
  apc:           { infantry: 1.6,  light: 0.8,  armor: 0.25, air: 0.3, naval: 0.1, building: 0.3 },
  mlrs:          { infantry: 1.3,  light: 1.1,  armor: 0.8,  air: 0,   naval: 0.5, building: 1.5 },
  gunship:       { infantry: 1.5,  light: 1.1,  armor: 0.85, air: 0.4, naval: 0.5, building: 0.8 },
  corvette:      { infantry: 0.7,  light: 0.85, armor: 0.5,  air: 1.6, naval: 1.4, building: 0.9 },
  nuclearSub:    { infantry: 0,    light: 0,    armor: 0,    air: 0,   naval: 2.0, building: 0 },
};

function targetClass(ent) {
  if (ent.type === 'building') return 'building';
  if (ent.def.fly) return 'air';
  if (ent.def.naval) return 'naval';
  if (['soldier', 'rocketSoldier', 'sniper', 'commando', 'worker'].includes(ent.key)) return 'infantry';
  if (['tank', 'artillery'].includes(ent.key)) return 'armor';
  return 'light';
}

function damageProfileValue(attacker, target) {
  const prof = DAMAGE_PROFILE[attacker.key] || {};
  return prof[targetClass(target)] ?? 0;
}

function canEngageTarget(attacker, target) {
  if (!attacker || !target || attacker.dead || target.dead || attacker.def.dmg <= 0) return false;
  if (attacker.key === 'submarine' && targetClass(target) !== 'naval') return false;
  return damageProfileValue(attacker, target) > 0.01;
}

function nearestEnemy(u, radius) {
  let best = null, bd = radius * radius;
  for (const e of G.units) {
    if (e.dead || e.owner === u.owner || !isAtWar(u.owner, e.owner)) continue;
    if (!canEngageTarget(u, e)) continue;
    // naval units can't shoot far inland targets and vice versa is fine (range check covers it)
    const d = (e.x - u.x) ** 2 + (e.z - u.z) ** 2;
    if (d < bd) { bd = d; best = e; }
  }
  for (const b of G.buildings) {
    if (b.dead || b.owner === u.owner || !isAtWar(u.owner, b.owner)) continue;
    if (!canEngageTarget(u, b)) continue;
    const d = (b.x - u.x) ** 2 + (b.z - u.z) ** 2;
    if (d < bd) { bd = d; best = b; }
  }
  return best;
}

/* shortest-arc angle steering */
function turnToward(cur, target, maxStep) {
  let d = ((target - cur + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
  if (Math.abs(d) <= maxStep) return target;
  return cur + Math.sign(d) * maxStep;
}

/* Ammo Depots speed up every unit's reload (up to 3 count) */
function reloadMult(owner) {
  if (owner !== 0) return 1;
  return 1 - 0.06 * Math.min(playerBuildingCount('ammoDepot'), 3);
}

/* movement legality per unit domain */
function canStandAt(u, x, z) {
  if (u.def.fly) return true;
  const h = terrainH(x, z);
  return u.def.naval ? h < -0.5 : h > 0.05;
}

function updateUnit(u, dt) {
  const def = u.def;
  if (u.disabledUntil > G.time) {
    updateHpBar(u);
    return;
  }
  u.cool = Math.max(0, u.cool - dt);
  u.retarget -= dt;

  // --- parked aircraft: refuel, scramble if the base is threatened ---
  if (u.state === 'landed') {
    u.fuel = Math.min(PLANE_FUEL, (u.fuel || 0) + dt * 6); // refuel fast
    if (u.homeBase && !u.homeBase.dead) { u.x = u.homeBase.x; u.z = u.homeBase.z; }
    // scramble to defend against nearby enemies
    if ((u.frame = (u.frame || 0) + 1) % 20 === 0 && u.fuel > PLANE_FUEL * 0.4) {
      const foe = nearestEnemy(u, def.aggro * 2.2);
      if (foe) { u.state = 'attack'; u.target = foe; u.prevState = 'idle'; }
    }
    // sit low on the apron
    if (u.homeBase && !u.homeBase.dead) {
      u.mesh.position.set(u.x, terrainH(u.x, u.z) + 0.6, u.z);
    }
    updateHpBar(u);
    return;
  }

  // --- airborne aircraft burn fuel and must return to base ---
  if (u.homeBase !== undefined && def.fly && isPlaneKey(u.key)) {
    u.fuel = (u.fuel ?? PLANE_FUEL) - dt;
    if (u.returning) {
      if (u.homeBase && !u.homeBase.dead && dist2d(u.x, u.z, u.homeBase.x, u.homeBase.z) < 6) {
        u.returning = false;
        landPlane(u);
        updateHpBar(u);
        return;
      }
    } else if (u.fuel <= 0 && u.state !== 'attack') {
      planeReturnHome(u);
    } else if (u.fuel <= 0 && u.state === 'attack' && (!u.target || u.target.dead)) {
      planeReturnHome(u);
    } else if ((u.state === 'idle') && u.homeBase && !u.homeBase.dead) {
      // mission complete, nothing to do → RTB
      planeReturnHome(u);
    }
  }

  // acquire targets when idle / attack-moving (throttled)
  if (def.dmg > 0 && u.retarget <= 0 && (u.state === 'idle' || u.state === 'attackMove' || u.state === 'guard')) {
    u.retarget = 0.4 + Math.random() * 0.3;
    const foe = nearestEnemy(u, def.aggro);
    if (foe) { u.target = foe; u.prevState = u.state; u.state = 'attack'; }
  }

  let mvx = 0, mvz = 0, moving = false;

  if (u.state === 'guard') {
    const gx = u.guardX ?? u.x, gz = u.guardZ ?? u.z;
    const d = dist2d(u.x, u.z, gx, gz);
    if (d > 2) {
      const wp = pathNext(u, gx, gz);
      const ax = wp ? wp.x : gx, az = wp ? wp.z : gz;
      const ad = Math.max(dist2d(u.x, u.z, ax, az), 0.001);
      mvx = (ax - u.x) / ad; mvz = (az - u.z) / ad; moving = true;
    }
  }
  else if (u.state === 'move' || u.state === 'attackMove' || u.state === 'toHarvest' || u.state === 'toBuild' || u.state === 'toChop') {
    const dx = u.tx - u.x, dz = u.tz - u.z;
    const d = Math.hypot(dx, dz);
    const arrive = u.state === 'toBuild' ? (u.buildTarget ? u.buildTarget.def.size + 2 : 2) : u.state === 'toChop' ? 2.5 : 1.5;
    if (d < arrive) {
      if (u.state === 'toHarvest' && u.harvestDep) {
        u.state = 'harvest';
        if (!u.harvestDep.workers.includes(u)) u.harvestDep.workers.push(u);
      } else if (u.state === 'toBuild' && u.buildTarget && !u.buildTarget.dead) {
        u.state = 'build';
      } else if (u.state === 'toChop' && u.chopTarget && !u.chopTarget.removed) {
        u.state = 'chop';
      } else u.state = 'idle';
    } else {
      // steer along the computed path (A* around water, buildings, coastline)
      const wp = pathNext(u, u.tx, u.tz);
      const ax = wp ? wp.x : u.tx, az = wp ? wp.z : u.tz;
      const ad = Math.max(dist2d(u.x, u.z, ax, az), 0.001);
      mvx = (ax - u.x) / ad; mvz = (az - u.z) / ad; moving = true;
    }
    if (u.state === 'toBuild' && (!u.buildTarget || u.buildTarget.dead)) u.state = 'idle';
    if (u.state === 'toChop' && (!u.chopTarget || u.chopTarget.removed)) u.state = 'idle';
  }
  else if (u.state === 'chop') {
    const tree = u.chopTarget;
    if (!tree || tree.removed) { u.state = 'idle'; u.chopTarget = null; }
    else {
      const speed = G.discovered.forestry ? 2 : 1;
      u.chopProg = (u.chopProg || 0) + dt * speed / 3; // 3s per tree
      if (u.chopProg >= 1) {
        removeTree(tree);
        if (u.owner === 0) G.res.money += G.discovered.forestry ? 24 : 12; // sell the lumber
        // keep clearing the surrounding grove automatically
        const next = treesNear(tree.x, tree.z, 14)[0];
        if (next) commandChop(u, next);
        else { u.state = 'idle'; u.chopTarget = null; }
      }
    }
  }
  else if (u.state === 'attack') {
    const t = u.target;
    if (!t || t.dead) { u.state = u.prevState === 'attackMove' ? 'attackMove' : u.prevState === 'guard' ? 'guard' : 'idle'; u.target = null; }
    else if (!canEngageTarget(u, t)) {
      u.state = u.prevState === 'attackMove' ? 'attackMove' : u.prevState === 'guard' ? 'guard' : 'idle';
      u.target = null;
    }
    else {
      const d = dist2d(u.x, u.z, t.x, t.z);
      const range = def.range * unitTechRangeMult(u) + (t.type === 'building' ? t.def.size * 0.7 : 0);
      if (d > range) {
        const wp = pathNext(u, t.x, t.z);
        const ax = wp ? wp.x : t.x, az = wp ? wp.z : t.z;
        const ad = Math.max(dist2d(u.x, u.z, ax, az), 0.001);
        mvx = (ax - u.x) / ad; mvz = (az - u.z) / ad; moving = true;
      }
      else if (u.cool <= 0) {
        u.cool = def.cooldown * reloadMult(u.owner);
        let dmg = def.dmg * statDmgMult(u.owner) * unitTechDmgMult(u) * damageProfileValue(u, t);
        const y1 = u.mesh.position.y + 1.4;
        const y2 = t.type === 'unit' ? t.mesh.position.y + 1 : t.mesh.position.y + 2;
        const heavy = ['tank', 'jet', 'artillery', 'destroyer', 'rocketSoldier', 'bomber', 'submarine', 'sniper', 'commando', 'samLauncher', 'drone'].includes(u.key);
        spawnTracer(u.x, y1, u.z, t.x, y2, t.z, heavy ? 0xffcc66 : 0xfff2aa);
        // muzzle flash slightly toward the target
        const fd = Math.max(dist2d(u.x, u.z, t.x, t.z), 0.01);
        spawnMuzzleFlash(u.x + (t.x - u.x) / fd * 1.2, y1, u.z + (t.z - u.z) / fd * 1.2);
        u.attackAnimUntil = G.time + Math.min(0.5, Math.max(0.22, def.cooldown * 0.32));
        if (u.mesh.userData.turret) u.visualRecoil = 1;
        if (heavy) spawnExplosion(t.x, y2, t.z, def.splash ? def.splash * 0.5 : 1.2);
        dealDamage(t, dmg, u);
        // splash damage around the target (artillery / bombers / destroyers)
        if (def.splash) {
          for (const o of [...G.units, ...G.buildings]) {
            if (o.dead || o === t || o.owner === u.owner) continue;
            if (!isAtWar(u.owner, o.owner)) continue;
            const sd = dist2d(o.x, o.z, t.x, t.z);
            if (sd < def.splash) dealDamage(o, dmg * 0.45 * (1 - sd / def.splash), u);
          }
        }
      }
      if (t && !moving) {
        const aimYaw = Math.atan2(t.x - u.x, t.z - u.z) + (u.mesh.userData.faceOffset || 0);
        u.mesh.rotation.y = turnToward(u.mesh.rotation.y, aimYaw, dt * 10);
      }
    }
  }
  else if (u.state === 'harvest') {
    const dep = u.harvestDep;
    if (!dep) { u.state = 'idle'; }
    else if (u.owner === 0) {
      const robo = G.discovered.robotics ? 1.5 : 1;
      G.res[dep.def.res] += dep.def.rate * 0.5 * robo * dt; // worker mining: half rate of extractor
    }
  }
  else if (u.state === 'build') {
    const b = u.buildTarget;
    if (!b || b.dead || b.built) { u.state = 'idle'; u.buildTarget = null; }
    else {
      const robo = u.owner === 0 && G.discovered.robotics ? 1.5 : 1;
      b.progress += dt * prodSpeedMult(b.owner) * robo / b.def.buildTime;
      b.hp = Math.min(b.maxHp, b.maxHp * b.progress + 1);
      b.mesh.scale.y = 0.15 + 0.85 * Math.min(b.progress, 1);
      if (b.progress >= 1) {
        b.built = true; b.hp = b.maxHp; b.mesh.scale.y = 1;
        if (b.owner === 0) notify(`${b.def.name} construction complete.`, 'good');
        u.state = 'idle'; u.buildTarget = null;
      }
    }
  }

  if (moving) {
    const sp = def.speed * unitTechSpeedMult(u) * dt;
    const px = u.x, pz = u.z;
    const nx = u.x + mvx * sp, nz = u.z + mvz * sp;
    if (canStandAt(u, nx, nz)) {
      u.x = nx; u.z = nz;
    } else if (canStandAt(u, nx, u.z)) {   // slide along the coast
      u.x = nx;
    } else if (canStandAt(u, u.x, nz)) {
      u.z = nz;
    } else {
      // hard-blocked: replan around the obstacle instead of freezing
      u.forceRepath = true; u.nextPathAt = 0;
    }
    // stuck detection: barely moving for a while → recompute the path
    if (dist2d(u.x, u.z, px, pz) < sp * 0.25) {
      u.stuckT = (u.stuckT || 0) + dt;
      if (u.stuckT > 1.2) {
        u.forceRepath = true; u.nextPathAt = 0; u.stuckT = 0;
        u.repathFails = (u.repathFails || 0) + 1;
        if (u.repathFails > 4 && (u.state === 'move' || u.state === 'attackMove')) {
          u.state = 'idle'; u.repathFails = 0; // truly unreachable — give up
        }
      }
    } else { u.stuckT = 0; u.repathFails = 0; }
    // smooth shortest-arc turning toward the heading (ships turn slower)
    const targetYaw = Math.atan2(mvx, mvz) + (u.mesh.userData.faceOffset || 0);
    u.mesh.rotation.y = turnToward(u.mesh.rotation.y, targetYaw, dt * (def.naval ? 2.4 : 9));
    // ships carve foaming wakes; fast aircraft leave contrails
    if (def.naval || u.key === 'jet' || u.key === 'bomber') {
      u.wakeAcc = (u.wakeAcc || 0) + dt;
      if (u.wakeAcc > (def.naval ? 0.14 : 0.1)) {
        u.wakeAcc = 0;
        if (def.naval) spawnWake(u.x - mvx * 1.8, SEA_LEVEL + 0.08, u.z - mvz * 1.8, true, Math.atan2(-mvz, mvx));
        else spawnWake(u.x - mvx * 2.2, u.mesh.position.y - 0.2, u.z - mvz * 2.2, false);
      }
    } else if (!def.fly && !u.mesh.userData.mixer && !u.mesh.userData.limbs) {
      u.dustAcc = (u.dustAcc || 0) + dt;
      if (u.dustAcc > 0.16) {
        u.dustAcc = 0;
        spawnDust(u.x - mvx * 1.05, terrainH(u.x, u.z) + 0.14, u.z - mvz * 1.05);
      }
    }
  }

  // gentle separation from nearby friendly units (same-domain only)
  if (!def.fly && (u.id + G.frame) % 3 === 0) {
    for (const o of G.units) {
      if (o === u || o.dead || o.def.fly || !!o.def.naval !== !!def.naval) continue;
      const dx = u.x - o.x, dz = u.z - o.z;
      const d2 = dx * dx + dz * dz;
      if (d2 < 4 && d2 > 0.0001) {
        const d = Math.sqrt(d2);
        const push = (dx / d) * (2 - d) * 0.5 * dt * 10;
        const pushZ = (dz / d) * (2 - d) * 0.5 * dt * 10;
        if (canStandAt(u, u.x + push, u.z + pushZ)) { u.x += push; u.z += pushZ; }
      }
    }
  }

  u.x = clamp(u.x, -HALF_MAP + 3, HALF_MAP - 3);
  u.z = clamp(u.z, -HALF_MAP + 3, HALF_MAP - 3);
  if (def.naval) {
    u.mesh.position.set(u.x, SEA_LEVEL + 0.15 + Math.sin(G.time * 1.5 + u.id) * 0.12, u.z);
    u.mesh.rotation.z = Math.sin(G.time * 1.2 + u.id) * 0.03; // gentle roll
  } else {
    const groundY = terrainH(u.x, u.z);
    u.mesh.position.set(u.x, groundY + def.fly + (def.fly ? Math.sin(G.time * 2 + u.id) * 0.4 : 0), u.z);
  }

  // Aircraft bank into turns and settle smoothly instead of rotating like a
  // rigid board. Ground vehicles get subtle suspension travel over terrain.
  if (def.fly) {
    const lateral = moving
      ? mvx * Math.cos(u.mesh.rotation.y) - mvz * Math.sin(u.mesh.rotation.y)
      : 0;
    const desiredBank = clamp(-lateral * 0.34, -0.34, 0.34);
    u.visualBank = (u.visualBank || 0) + (desiredBank - (u.visualBank || 0)) * Math.min(1, dt * 4.5);
    u.mesh.rotation.z = u.visualBank;
    u.mesh.position.y += Math.sin(G.time * 1.7 + u.id * 0.7) * (u.key === 'helicopter' ? 0.13 : 0.05);
  } else if (!def.naval && !u.mesh.userData.mixer && !u.mesh.userData.limbs) {
    const slope = terrainH(u.x + 1.2, u.z) - terrainH(u.x - 1.2, u.z);
    const desiredRoll = clamp(-slope * 0.028, -0.08, 0.08);
    u.visualBank = (u.visualBank || 0) + (desiredRoll - (u.visualBank || 0)) * Math.min(1, dt * 5);
    u.mesh.rotation.z = u.visualBank;
    if (moving) u.mesh.position.y += Math.sin(G.time * def.speed * 2.2 + u.id) * 0.035;
  }

  // rotor spin (main + tail) and submarine propellers
  const rotor = u.mesh.userData.rotor;
  if (rotor) rotor.rotation.y += dt * (moving ? 28 : 22);
  const rotorDisc = u.mesh.userData.rotorDisc;
  if (rotorDisc) rotorDisc.material.opacity = 0.09 + Math.sin(G.time * 19 + u.id) * 0.025;
  const tailRotor = u.mesh.userData.tailRotor;
  if (tailRotor) tailRotor.rotation.z += dt * 28;
  const prop = u.mesh.userData.prop;
  if (prop) prop.rotation.x += dt * 9;
  const afterburner = u.mesh.userData.afterburner;
  if (afterburner) {
    afterburner.scale.y = 0.8 + Math.sin(G.time * 23 + u.id) * 0.18;
    afterburner.material.emissiveIntensity = moving ? 1.65 : 0.65;
  }
  const rollingParts = u.mesh.userData.rollingParts;
  if (rollingParts && moving) {
    const turn = dt * def.speed * 2.4;
    for (const wheel of rollingParts) wheel.rotateY(turn);
  }
  const droneRotors = u.mesh.userData.droneRotors;
  if (droneRotors) {
    for (let i = 0; i < droneRotors.length; i++)
      droneRotors[i].rotation.y += dt * (i % 2 ? -32 : 32);
  }
  const sensor = u.mesh.userData.spin;
  if (sensor) sensor.rotation.y += dt * 1.8;

  // tank turrets swing toward their target, then settle forward
  const tur = u.mesh.userData.turret;
  if (tur) {
    if (!tur.userData.restPosition) tur.userData.restPosition = tur.position.clone();
    if (u.state === 'attack' && u.target && !u.target.dead) {
      const want = Math.atan2(-(u.target.z - u.z), u.target.x - u.x) - u.mesh.rotation.y;
      tur.rotation.y = turnToward(tur.rotation.y, want, dt * 5);
    } else {
      tur.rotation.y = turnToward(tur.rotation.y, 0, dt * 2.5);
    }
    u.visualRecoil = Math.max(0, (u.visualRecoil || 0) - dt * 5.2);
    tur.position.x = tur.userData.restPosition.x - Math.sin(u.visualRecoil * Math.PI) * 0.16;
  }

  // Skeletal characters: blend locomotion, weapon fire and authored worker
  // interaction clips. This replaces the rigid bobbing of the old figures.
  const mixer = u.mesh.userData.mixer;
  if (mixer) {
    const acts = u.mesh.userData.actions;
    const isWorking = ['build', 'chop', 'harvest'].includes(u.state);
    let target = isWorking && acts.work ? 'work'
      : (u.attackAnimUntil || 0) > G.time && acts.shoot ? 'shoot'
        : !moving ? 'idle' : (def.speed >= 5 ? 'run' : 'walk');
    if (!acts[target]) target = moving && acts.run ? 'run' : 'idle';
    for (const name of Object.keys(acts)) {
      const a = acts[name];
      if (!a) continue;
      const w = a.getEffectiveWeight();
      const goal = name === target ? 1 : 0;
      a.setEffectiveWeight(w + (goal - w) * Math.min(1, dt * 7));
    }
    mixer.update(dt);
  }

  // humanoid walk cycle — swing legs & arms while moving, settle when standing
  const limbs = u.mesh.userData.limbs;
  if (limbs) {
    if (moving) {
      u.walkT = (u.walkT || 0) + dt * def.speed * 1.15;
      const swing = Math.sin(u.walkT) * 0.6;
      limbs.lLeg.rotation.x = swing;
      limbs.rLeg.rotation.x = -swing;
      // weapon-bearing arms sway subtly around their pose; free arms swing wide
      const armSwing = limbs.armBase === 0 ? swing * 0.8 : Math.sin(u.walkT) * 0.12;
      limbs.lArm.rotation.x = limbs.armBase - armSwing;
      limbs.rArm.rotation.x = limbs.armBase + armSwing;
      u.mesh.position.y += Math.abs(Math.sin(u.walkT)) * 0.06; // step bounce
    } else {
      limbs.lLeg.rotation.x *= 0.8;
      limbs.rLeg.rotation.x *= 0.8;
      limbs.lArm.rotation.x += (limbs.armBase - limbs.lArm.rotation.x) * 0.2;
      limbs.rArm.rotation.x += (limbs.armBase - limbs.rArm.rotation.x) * 0.2;
    }
    // chopping / building — hammer with the right arm
    if (u.state === 'chop' || u.state === 'build' || u.state === 'harvest') {
      u.workT = (u.workT || 0) + dt * 7;
      limbs.rArm.rotation.x = -0.4 - Math.abs(Math.sin(u.workT)) * 1.1;
    }
  }
  updateHpBar(u);
}

/* ---------------- building update (production, extractors) ---------------- */
function updateBuilding(b, dt) {
  if (b.dead) return;
  if (b.disabledUntil > G.time) {
    updateHpBar(b);
    return;
  }
  if (b.built && b.queue.length > 0) {
    const item = b.queue[0]; // unit key or 'missile:type'
    const isMissile = item.startsWith('missile:');
    const buildTime = isMissile ? MISSILES[item.slice(8)].buildTime : UNITS[item].trainTime;
    b.queueProg += dt * prodSpeedMult(b.owner) / buildTime;
    if (b.queueProg >= 1) {
      b.queue.shift(); b.queueProg = 0;
      if (isMissile) {
        const mType = item.slice(8);
        G.munitions[mType]++;
        notify(`${MISSILES[mType].icon} ${MISSILES[mType].name} ready in storage (${missileStock()}/${missileCap()}).`, 'good');
      } else {
        let sx, sz;
        if (UNITS[item].naval) {
          const w = findWaterNear(b.x, b.z);
          [sx, sz] = w || [b.x, b.z];
        } else {
          const ang = Math.random() * Math.PI * 2;
          const r = b.def.size + 3;
          sx = b.x + Math.cos(ang) * r; sz = b.z + Math.sin(ang) * r;
        }
        const u = spawnUnit(item, b.owner, sx, sz);
        if (isPlaneKey(item) && b.key === 'airfield') {
          // aircraft are based here: park on the apron until they fly a mission
          u.homeBase = b;
          u.fuel = PLANE_FUEL;
          landPlane(u);
        } else if (!UNITS[item].naval) {
          const ang2 = Math.atan2(sz - b.z, sx - b.x);
          u.tx = b.x + Math.cos(ang2) * (b.def.size + 8); u.tz = b.z + Math.sin(ang2) * (b.def.size + 8);
          u.state = 'move';
        }
        if (b.owner === 0) notify(`${UNITS[item].name} ready.`, 'good');
      }
    }
  }
  // rotating radar dishes / animated fixtures
  if (b.mesh.userData.spin) b.mesh.userData.spin.rotation.y += dt * 0.9;
  if (b.mesh.userData.turbine) b.mesh.userData.turbine.rotation.z += dt * 1.7;
  const beacon = b.mesh.userData.beacon;
  if (beacon) beacon.material.emissiveIntensity = 0.55 + Math.max(0, Math.sin(G.time * 3.2)) * 1.1;
  const flame = b.mesh.userData.flame;
  if (flame) {
    flame.material.emissiveIntensity = 1.2 + Math.sin(G.time * 11 + b.x) * 0.4;
    flame.scale.y = 1 + Math.sin(G.time * 9 + b.z) * 0.2;
  }
  // nuclear reactor: burns uranium for production speed & income (Fusion halves the burn)
  if (b.built && b.key === 'nuclearReactor' && b.owner === 0) {
    const burn = G.discovered.fusionPower ? 0.02 : 0.04;
    if (G.res.uranium > burn * dt) {
      G.res.uranium -= burn * dt;
      G.res.money += 5 * dt;
      b.fueled = true;
    } else if (b.fueled) {
      b.fueled = false;
      notify('☢️ Reactor out of uranium — production bonus offline.', 'warn');
    }
  }
  // SAM sites auto-engage enemy aircraft in range
  if (b.built && b.key === 'samSite') {
    b.cool = Math.max(0, (b.cool || 0) - dt);
    if (b.cool <= 0) {
      let tgt = null, bd = b.def.aaRange * b.def.aaRange;
      for (const u of G.units) {
        if (u.dead || !u.def.fly || u.state === 'landed') continue;
        if (u.owner === b.owner || !isAtWar(b.owner, u.owner)) continue;
        const d2 = (u.x - b.x) ** 2 + (u.z - b.z) ** 2;
        if (d2 < bd) { bd = d2; tgt = u; }
      }
      if (tgt) {
        b.cool = b.def.aaCooldown;
        spawnTracer(b.x, b.mesh.position.y + 4, b.z, tgt.x, tgt.mesh.position.y, tgt.z, 0xff9060);
        spawnExplosion(tgt.x, tgt.mesh.position.y, tgt.z, 1.5);
        dealDamage(tgt, b.def.aaDmg, { owner: b.owner });
      }
    }
  }
  // oil refinery: crude in, money out
  if (b.built && b.key === 'oilRefinery' && b.owner === 0) {
    if (G.res.oil > 0.06 * dt) {
      G.res.oil -= 0.06 * dt;
      G.res.money += 7 * dt;
      b.fueled = true;
    } else b.fueled = false;
  }
  // chip fab: silicon in, money & research out — the high-tech economy
  if (b.built && b.key === 'chipFab' && b.owner === 0) {
    if (G.res.silicon > 0.05 * dt) {
      G.res.silicon -= 0.05 * dt;
      G.res.money += 6 * dt;
      G.city.research += 0.4 * dt;
      b.fueled = true;
    } else if (b.fueled) {
      b.fueled = false;
      notify('🔬 Chip Fab starved of silicon — production halted.', 'warn');
    }
  }
  // extractor income
  // structures that build themselves (offshore rigs — no worker can swim out)
  if (!b.built && b.def.selfBuild && !b.aiSelfBuild) {
    b.progress += dt * prodSpeedMult(b.owner) / Math.max(b.def.buildTime, 6);
    b.hp = Math.min(b.maxHp, b.maxHp * b.progress + 1);
    b.mesh.scale.y = 0.15 + 0.85 * Math.min(b.progress, 1);
    if (b.progress >= 1) {
      b.built = true; b.hp = b.maxHp; b.mesh.scale.y = 1;
      if (b.owner === 0) notify(`${b.def.name} construction complete.`, 'good');
    }
  }
  // mountain mines dig ore straight from the rock — no deposit needed
  if (b.built && b.key === 'mountainMine' && b.owner === 0) {
    G.res.iron = Math.min(G.res.iron + 0.8 * (1 + fxv('extractPct')) * dt * economyMult(0),
      (G.city.caps && G.city.caps.iron) || 900);
  }
  if (b.built && (b.key === 'extractor' || b.key === 'offshoreRig') && b.deposit) {
    const rate = b.deposit.def.rate * (b.owner === 0 ? 1 + fxv('extractPct') : 1);
    if (b.owner === 0) G.res[b.deposit.def.res] += rate * dt * economyMult(0);
    else G.nations[b.owner].money += rate * RES_VALUE[b.deposit.def.res] * dt;
    const pump = b.mesh.userData.pump;
    if (pump) pump.rotation.z = 0.5 + Math.sin(G.time * 3) * 0.25;
  }
  // hospital heals nearby friendly units
  if (b.built && b.key === 'hospital' && (G.frame % 30 === 0)) {
    const healMult = G.discovered.advancedMedicine ? 2 : 1;
    for (const u of G.units) {
      if (u.dead || u.owner !== b.owner || u.hp >= u.maxHp) continue;
      if (dist2d(u.x, u.z, b.x, b.z) < b.def.healRadius) u.hp = Math.min(u.maxHp, u.hp + b.def.healRate * healMult);
    }
  }
  updateHpBar(b);
}

function economyMult(owner) {
  const nat = G.nations[owner];
  let m = 1;
  if (nat.debuffPresident > G.time) m *= 0.65;
  if (nat.debuffProxy > G.time) m *= 0.75;
  if (nat.debuffUnrest > G.time) m *= 0.78;
  if (nat.debuffCyber > G.time) m *= 0.80;
  if (owner !== 0 && G.diplo && hasSanction(0, owner)) m *= 0.85;
  // AI tech investment compounds its economy — advanced rivals pull ahead
  if (owner !== 0 && nat.aiTech) m *= 1 + nat.aiTech * 0.05;
  return m;
}

/* ---------------- player city simulation (1s tick) ---------------- */
function playerBuildingCount(key) {
  return G.buildings.filter(b => b.owner === 0 && b.built && !b.dead && b.key === key).length;
}
function updateDevelopment() {
  if (!G.development) G.development = { era: 0 };
  let nextIndex = G.development.era + 1;
  while (nextIndex < DEVELOPMENT_ERAS.length) {
    const next = DEVELOPMENT_ERAS[nextIndex];
    const status = developmentRequirementStatus(next);
    if (!status.length || !status.every(r => r.met)) break;
    G.development.era = nextIndex;
    const reward = next.reward || {};
    G.res.money += reward.money || 0;
    G.city.research += reward.research || 0;
    notify(`${next.icon} ${next.name} reached! National reward: +$${reward.money || 0}, +${reward.research || 0} research. New era bonuses improve income, research and production.`, 'good', 12);
    nextIndex++;
  }
}
function updateCity() {
  const c = G.city;
  const has = playerBuildingCount;
  const gov = GOVERNMENTS[G.gov.form];
  const taxPolicy = POLICIES.tax.options[G.policies.tax];
  recalcDiscoveryFx(); // discovery bonuses feed every stat below

  // ---- food ----
  const farms = has('farm');
  const armyCount = G.units.filter(u => u.owner === 0 && !u.dead).length;
  const foodCap = 300 + has('foodDepot') * 500;
  const farmMult = (G.discovered.fertilizers ? 1.5 : 1) * (1 + fxv('foodPct'));
  let foodIn = farms * 2.0 * farmMult * (1 + civicMod('foodPct'));
  // fishing wharves: base catch plus a bonus per fish school within reach
  for (const b of G.buildings) {
    if (b.owner !== 0 || b.dead || !b.built || b.key !== 'fishingWharf') continue;
    const schools = G.deposits.filter(d => d.type === 'fish' && dist2d(d.x, d.z, b.x, b.z) < 60).length;
    foodIn += 2.0 + Math.min(schools, 2) * 2.0;
  }
  let foodOut = c.civilians * 0.008 + armyCount * 0.05;
  if (G.policies.rationing) foodOut *= 0.55;
  G.res.food = clamp(G.res.food + foodIn - foodOut, 0, foodCap);
  const starving = G.res.food <= 0.5;
  c.foodRate = foodIn - foodOut;

  // ---- material storage caps ----
  const matBonus = has('warehouse') * WAREHOUSE_CAP_BONUS;
  c.caps = {};
  for (const k of ['oil', 'iron', 'silicon', 'uranium']) {
    c.caps[k] = BASE_CAP[k] + matBonus;
    G.res[k] = Math.min(G.res[k], c.caps[k]);
  }
  c.caps.food = foodCap;

  // ---- civic stats ----
  c.education = clamp(30 + has('school') * 8 + has('library') * 3 + has('university') * 10
    + civicMod('education') + fxv('education'), 0, 100);
  c.health = clamp(40 + has('hospital') * 10 + (G.discovered.advancedMedicine ? 10 : 0)
    + (G.policies.freeHealthcare ? 8 : 0) + fxv('health') + (starving ? -25 : 8), 0, 100);
  c.order = clamp(50 + has('policeStation') * 10 + civicMod('order') + fxv('order') + govMod('order')
    - (starving ? 15 : 0)
    - (c.happiness < 30 ? 12 : 0) - (G.warWeariness || 0) * 0.5, 0, 100);
  c.culture = clamp(20 + has('park') * 2 + has('stadium') * 5 + has('tvStation') * 3
    + has('library') * 2 + (gov.culture || 0) + fxv('culture'), 0, 100);
  // autarky: a nation that neither imports nor exports withers
  const tradeLinks = ((G.trade && G.trade.routes.length) || 0)
    + G.nations.filter((n, i) => i > 0 && !n.defeated && hasPact(0, i)).length;
  c.isolated = tradeLinks === 0 && G.time > 240;
  let happiness = 55 + has('foodDepot') * 5 + has('cityHall') * 6 + has('hospital') * 2
    + has('park') * 6 + has('market') * 3 + has('stadium') * 8 + has('residential') * 2
    + has('villageCenter') * 2 + has('cityCenter') * 4
    + has('cottage') * 2 + has('luxuryVillas') * 5 - has('apartments') * 1
    + (gov.happiness || 0) + civicMod('happiness') + govMod('happiness') + fxv('happiness') + taxPolicy.happiness
    + (G.policies.rationing ? POLICIES.rationing.happiness : 0)
    + (starving ? -35 : 0) - (G.warWeariness || 0)
    + (c.order < 35 ? -10 : 0)
    + (c.isolated ? -5 : 0)
    + (G.gov.purgePenaltyUntil > G.time ? -12 : 0);
  c.happiness = clamp(happiness, 0, 100);
  c.morale = clamp(50 + has('commandCenter') * 10 + (c.happiness - 50) * 0.4 + (starving ? -20 : 0), 0, 100);

  // ---- approval of the government ----
  c.approval = clamp(45 + (c.happiness - 50) * 0.55 + (c.order - 50) * 0.2 + c.culture * 0.15
    + has('tvStation') * 8 + civicMod('approval') + govMod('approval') + fxv('approval')
    + (G.policies.propaganda ? POLICIES.propaganda.approval : 0)
    + taxPolicy.approval - (G.warWeariness || 0) * 1.2, 0, 100);

  // ---- population ----
  const civCap = Math.round((200 + has('villageCenter') * 90 + has('cityCenter') * 260
    + has('residential') * 150 + has('cottage') * 80
    + has('apartments') * 280 + has('luxuryVillas') * 60 + has('waterTreatment') * 100)
    * (1 + fxv('civCapPct')));
  let growth = c.civilians * ((c.happiness - 45) / 50) * (c.health / 100) * 0.0025;
  // famine: people don't just stop growing — they die or flee
  if (starving) growth -= c.civilians * 0.004;
  c.civilians = clamp(c.civilians + growth, 20, civCap);
  c.civCap = civCap;

  // ---- THE POWER GRID: generation vs. demand drives the whole economy ----
  let mwSupply = 0, mwDemand = 0;
  for (const b of G.buildings) {
    if (b.owner !== 0 || b.dead || !b.built) continue;
    const mw = b.def.mw || 0;
    if (mw > 0) {
      if (b.key === 'nuclearReactor' && !b.fueled) continue; // dry reactor = no power
      mwSupply += mw;
    } else if (mw < 0) mwDemand += -mw;
    else if (b.def.cat === 'economy' || b.def.cat === 'civic') mwDemand += 1; // baseline draw
  }
  c.power = { supply: mwSupply, demand: mwDemand, factor: mwDemand > 0 ? clamp(mwSupply / mwDemand, 0.55, 1) : 1 };
  if (c.power.factor < 1 && G.frame % 1800 === 0) {
    notify(`⚡ POWER SHORTAGE: ${mwDemand} MW demanded, ${mwSupply} MW supplied. Production, research and income are throttled — build Power Plants or Solar Farms.`, 'warn', 9);
  }

  // ---- compute: who controls the chips controls the future ----
  c.compute = Math.min(G.buildings.filter(b => b.owner === 0 && b.built && !b.dead && b.key === 'chipFab' && b.fueled).length, 5);

  // ---- income ----
  const eraPct = ((G.development && G.development.era) || 0) * 0.05;
  const bankPct = Math.min(has('bank') * 0.15, 0.60) + has('cityHall') * 0.10 + has('cityCenter') * 0.06
    + has('market') * 0.08 + has('stadium') * 0.03
    + Math.min(has('luxuryVillas') * 0.04, 0.16) + has('techPark') * 0.05
    + c.compute * 0.02;
  const techPct = G.tech.economy * 0.12 + (G.discovered.stockExchange ? 0.15 : 0)
    + (G.tech.hightech || 0) * 0.04 + (G.discovered.aiRevolution ? 0.10 : 0) + fxv('incomePct');
  const eduPct = c.education / 250;
  const healthPct = (c.health - 50) / 300;
  const orderPct = c.order < 40 ? -(40 - c.order) / 100 : 0; // crime eats income
  let incomeMult = (1 + bankPct + techPct + eraPct + eduPct + healthPct + orderPct + govMod('incomePct') + civicMod('incomePct')) * economyMult(0);
  incomeMult *= taxPolicy.incomeMult;
  if (G.gov.instabilityUntil > G.time) incomeMult *= 0.75;
  if (c.isolated) incomeMult *= 0.88; // no imports, no exports, no growth
  incomeMult *= lerp(0.8, 1, c.power.factor); // blackouts strangle commerce
  // controlled territory pays tribute — and every terrain type yields its own
  // bounty (Civ-style): plains feed, forests sell lumber, mountains hold ore,
  // coasts trade & fish. Occupied land (recently conquered, low control)
  // produces at reduced rate until it integrates.
  c.territory = territoryCellCount(0);
  const yields = territoryYields(0);
  c.territoryIncome = yields.money;
  c.terrainYields = yields;
  G.res.food = Math.min(G.res.food + yields.food, foodCap);
  G.res.iron = Math.min(G.res.iron + yields.iron, c.caps.iron);
  c.income = c.civilians * 0.035 * incomeMult + c.territoryIncome;
  G.res.money += c.income;

  // policy upkeep
  if (G.policies.propaganda) G.res.money -= POLICIES.propaganda.costPerSec;
  if (G.policies.freeHealthcare) G.res.money -= POLICIES.freeHealthcare.costPerSec;
  if (G.res.money < 0) G.res.money = 0;

  // ---- research ----
  c.researchRate = (has('library') * 0.5 + has('school') * 0.2 + has('university') * 1.0 + has('techPark') * 0.8)
    * (1 + c.education / 100) * (1 + govMod('researchPct') + civicMod('researchPct'))
    * (1 + eraPct + (G.tech.hightech || 0) * 0.06 + (G.discovered.aiRevolution ? 0.20 : 0)
       + c.compute * 0.05 + fxv('researchPct'))
    * c.power.factor; // labs go dark without electricity
  c.research += c.researchRate;

  // ---- army capacity ----
  c.popCap = G.buildings.filter(b => b.owner === 0 && b.built && !b.dead)
    .reduce((s, b) => s + ((b.def.provides && b.def.provides.pop) || 0), 0);
  c.popUsed = G.units.filter(u => u.owner === 0 && !u.dead).reduce((s, u) => s + u.def.pop, 0);

  // ---- war weariness ----
  const atWarCount = G.nations.filter((n, i) => i !== 0 && isAtWar(0, i)).length;
  G.warWeariness = clamp((G.warWeariness || 0) + (atWarCount > 0 ? 0.05 : -0.15), 0, 25);

  if (starving && G.frame % 600 === 0) notify('Your citizens are starving! People are dying or fleeing the country. Build farms NOW.', 'bad');

  // ---- unrest: sustained misery boils over into strikes and riots ----
  if (c.happiness < 25 || c.order < 25 || starving) {
    c.unrestT = (c.unrestT || 0) + 1;
    if (c.unrestT === 20) notify('⚠️ UNREST is building — protests in the streets. Raise happiness and order before it explodes.', 'warn', 8);
    if (c.unrestT >= 45) {
      c.unrestT = 0;
      const roll = Math.random();
      if (roll < 0.45) { // general strike
        G.gov.instabilityUntil = Math.max(G.gov.instabilityUntil, G.time + 45);
        notify('✊ GENERAL STRIKE! Income and production crippled for 45s. The people demand change.', 'bad', 10);
      } else if (roll < 0.8) { // riot damages a building
        const targets = G.buildings.filter(b => b.owner === 0 && b.built && !b.dead && b.key !== 'hq');
        if (targets.length) {
          const t = targets[Math.floor(Math.random() * targets.length)];
          dealDamage(t, t.maxHp * 0.35, null);
          spawnExplosion(t.x, t.mesh.position.y + 2, t.z, 4);
          notify(`🔥 RIOTS! An angry mob torched your ${t.def.name}.`, 'bad', 10);
        }
      } else { // mass emigration
        c.civilians = Math.max(20, c.civilians * 0.85);
        notify('🧳 MASS EMIGRATION! 15% of your citizens fled the country.', 'bad', 10);
      }
    }
  } else {
    c.unrestT = Math.max(0, (c.unrestT || 0) - 2);
  }

  govTick();
  civicTick();
  updateDevelopment();
  endgameTick();
}

/* ---------------- the endgame: dominance has consequences and a finish line ----------------
   Three paths to victory: Conquest (destroy every rival HQ), Hegemony (hold
   60% of all land for 5 minutes), Technology (complete the entire research
   tree). Grow too strong and the surviving powers form a coalition. */
function endgameTick() {
  if (G.gameOver || !TERRITORY.owner) return;
  const hg = G.hegemony || (G.hegemony = { t: 0, coalition: false, warned: false });
  let land = 0;
  for (let i = 0; i < TERRITORY.owner.length; i++) {
    if (TERRITORY.terrain && TERRITORY.terrain[i] !== 0) land++;
  }
  const share = land ? territoryCellCount(0) / land : 0;
  G.landShare = share;

  // --- world coalition: the powers unite against a would-be hegemon ---
  if (!hg.coalition && share > 0.45) {
    hg.coalition = true;
    const alive = G.nations.filter((n, i) => i > 0 && !n.defeated);
    if (alive.length >= 2) {
      for (let i = 1; i < G.nations.length; i++) {
        if (G.nations[i].defeated) continue;
        for (let j = i + 1; j < G.nations.length; j++) {
          if (G.nations[j].defeated) continue;
          G.diplo.alliance[i][j] = G.diplo.alliance[j][i] = true;
          G.diplo.war[i][j] = G.diplo.war[j][i] = false;
        }
        G.nations[i].aiTech = (G.nations[i].aiTech || 0) + 2; // desperation surge
        if (!isAtWar(0, i)) declareWar(i, 0);
      }
      notify('🌍 WORLD COALITION! Your dominance terrifies the remaining powers — they have allied AGAINST YOU and mobilized their economies. Finish the job or hold what you have.', 'bad', 14);
    }
  }

  // --- hegemony victory: hold 60% of the world for 5 minutes ---
  if (share >= 0.6) {
    hg.t += 1;
    if (!hg.warned) { hg.warned = true; notify('👑 HEGEMONY IN SIGHT: you hold 60% of the world. Keep it for 5 minutes and the remaining powers must submit.', 'good', 12); }
    if (hg.t % 60 === 0 && hg.t < 300) notify(`👑 Hegemony countdown: ${Math.ceil((300 - hg.t) / 60)} minute(s) of control remaining.`, 'good', 6);
    if (hg.t >= 300) {
      showEnd(true, 'No shot fired could stop what your flags already say: three-fifths of the earth answers to your capital. The remaining powers sign the Act of Submission. Victory by HEGEMONY.');
      return;
    }
  } else {
    if (hg.t > 0 && share < 0.55) { hg.t = 0; hg.warned = false; }
  }

  // --- technology victory: master the entire research tree ---
  if (!hg.techDone && Object.keys(DISCOVERIES).every(k => G.discovered[k])) {
    hg.techDone = true;
    showEnd(true, 'Fusion cores hum, quantum lattices think, and every science known to man bears your seal. Rivals with rifles face a nation from the future. Victory by TECHNOLOGY.');
  }
}

/* ---------------- government events (elections, coups, succession) ---------------- */
function newLeader() {
  const name = LEADER_NAMES[Math.floor(Math.random() * LEADER_NAMES.length)];
  const traits = Object.keys(LEADER_TRAITS);
  const trait = traits[Math.floor(Math.random() * traits.length)];
  // every leader is a trade-off: one strength, one flaw
  const flaws = Object.keys(LEADER_FLAWS);
  const flaw = flaws[Math.floor(Math.random() * flaws.length)];
  return { name, trait, flaw };
}
function leaderTitle() { return LEADER_TITLES[G.gov.form]; }
function leaderLabel(l) {
  const t = LEADER_TRAITS[l.trait];
  const f = l.flaw ? LEADER_FLAWS[l.flaw] : null;
  return `${leaderTitle()} ${l.name} ${t.icon} "${t.name}"${f ? ` / ${f.icon} ${f.name}` : ''}`;
}

/* ---------------- city administration (local elections / appointments) ---------------- */
function newCivicLeader(forcedTrait) {
  const name = CIVIC_NAMES[Math.floor(Math.random() * CIVIC_NAMES.length)];
  const traits = Object.keys(CIVIC_LEADERS);
  const trait = forcedTrait || traits[Math.floor(Math.random() * traits.length)];
  return { name, trait };
}
function civicTitle() { return CIVIC_TITLES[G.gov.form]; }
function civicLabel(l) {
  if (!l) return 'Vacant office';
  const t = CIVIC_LEADERS[l.trait];
  return `${l.name} ${t.icon} "${t.name}"`;
}
function civicMod(key) {
  if (!G.civic || !G.civic.leader) return 0;
  const tr = CIVIC_LEADERS[G.civic.leader.trait];
  return (tr && tr[key]) || 0;
}

function civicTick() {
  // National elections are the only elections — the city administrator is an
  // appointed office in every form of government (see the City window).
  // Kept as a hook for future civic events.
}

function startLocalElection() {
  const candidates = [
    { ...G.civic.leader, incumbent: true },
    newCivicLeader(), newCivicLeader(),
  ];
  while (candidates[1].trait === candidates[0].trait) candidates[1] = newCivicLeader();
  while (candidates[2].trait === candidates[0].trait || candidates[2].trait === candidates[1].trait) candidates[2] = newCivicLeader();

  const label = cd => {
    const t = CIVIC_LEADERS[cd.trait];
    return `${cd.incumbent ? 'Incumbent' : 'Challenger'} ${cd.name} - ${t.name}`;
  };
  const backCandidate = idx => {
    const cd = candidates[idx];
    const baseChance = cd.incumbent
      ? clamp(G.city.approval / 100 + G.city.happiness / 300, 0.15, 0.95)
      : clamp(0.35 + (G.city.approval - 45) / 180 + (G.city.happiness - 50) / 260, 0.12, 0.82);
    if (Math.random() < baseChance) {
      G.civic.leader = { name: cd.name, trait: cd.trait };
      notify(`City election won: ${civicTitle()} ${civicLabel(G.civic.leader)} takes office.`, 'good', 8);
    } else {
      const others = candidates.filter((_, i) => i !== idx);
      const winner = others[Math.floor(Math.random() * others.length)];
      G.civic.leader = { name: winner.name, trait: winner.trait };
      G.gov.instabilityUntil = Math.max(G.gov.instabilityUntil, G.time + 20);
      notify(`City election lost. ${civicTitle()} ${civicLabel(G.civic.leader)} wins instead. Brief local instability.`, 'warn', 8);
    }
    refreshWindows();
  };

  openDecision(
    'Local Election',
    `Approval ${Math.round(G.city.approval)}%, happiness ${Math.round(G.city.happiness)}%. Choose which city candidate your political machine will back.`,
    candidates.map((cd, i) => {
      const t = CIVIC_LEADERS[cd.trait];
      const chance = cd.incumbent
        ? clamp(G.city.approval / 100 + G.city.happiness / 300, 0.15, 0.95)
        : clamp(0.35 + (G.city.approval - 45) / 180 + (G.city.happiness - 50) / 260, 0.12, 0.82);
      return {
        title: label(cd),
        pros: [t.desc, `Estimated win chance: ${Math.round(chance * 100)}%`],
        cons: cd.incumbent ? ['Keeping the same office may preserve current weaknesses.'] : ['If your candidate loses, the city suffers brief instability.'],
        actionLabel: 'Back candidate',
        fn: () => backCandidate(i),
      };
    }));
}

function appointCivicLeader(trait) {
  // the city administrator is appointed under every form of government —
  // only the head of state faces the voters
  if (G.time < G.civic.lastAppointment + CIVIC_APPOINT_COOLDOWN) {
    notify(`The administration needs ${Math.ceil((G.civic.lastAppointment + CIVIC_APPOINT_COOLDOWN - G.time) / 60)} more minutes before another appointment.`, 'warn');
    return;
  }
  if (G.res.money < CIVIC_APPOINT_COST) {
    notify(`Appointment costs $${CIVIC_APPOINT_COST}.`, 'warn');
    return;
  }
  G.res.money -= CIVIC_APPOINT_COST;
  G.civic.leader = newCivicLeader(trait);
  G.civic.lastAppointment = G.time;
  G.gov.instabilityUntil = Math.max(G.gov.instabilityUntil, G.time + 15);
  notify(`${civicTitle()} appointed: ${civicLabel(G.civic.leader)}. Local transition instability for 15s.`, 'good', 8);
  refreshWindows();
}

function govTick() {
  const gv = G.gov;
  if (G.time < gv.nextEvent) return;
  const c = G.city;
  switch (gv.form) {
    case 'democracy': {
      gv.nextEvent = G.time + GOVERNMENTS.democracy.electionEvery * YEAR_SECONDS;
      startElection();
      break;
    }
    case 'dictatorship': {
      gv.nextEvent = G.time + GOVERNMENTS.dictatorship.coupEvery * YEAR_SECONDS;
      if (c.approval < 30) {
        // the player decides how to answer unrest — each answer has a price
        notifyAction(`👊 UNREST! Approval is at ${Math.round(c.approval)}%. The officer corps whispers of a coup. Your move, ${leaderTitle()}:`, [
          { label: '🔪 Purge plotters', fn: () => {
              gv.purgePenaltyUntil = G.time + 120;
              notify('The purge restores order — and spreads fear. Happiness suffers for 2 min, but the coup is averted.', 'warn', 8);
            } },
          { label: '💰 Buy loyalty ($800)', fn: () => {
              if (G.res.money < 800) { notify('You cannot afford it — the plot proceeds!', 'bad'); resolveCoup(); return; }
              G.res.money -= 800;
              notify('Generals paid, palaces quiet. Loyalty (temporarily) secured.', 'good', 6);
            } },
          { label: '🎲 Ignore them', fn: () => resolveCoup() },
        ], 25);
      }
      break;
    }
    case 'monarchy': {
      gv.nextEvent = G.time + 10 * YEAR_SECONDS;
      if (Math.random() < 0.4) {
        const old = gv.leader;
        gv.leader = newLeader();
        notify(`👑 Royal succession: ${leaderTitle()} ${old.name} abdicates. Long live ${leaderLabel(gv.leader)}!`, '', 8);
      }
      break;
    }
    case 'technocracy': {
      gv.nextEvent = G.time + 8 * YEAR_SECONDS;
      if (c.approval < 25) {
        gv.leader = newLeader();
        gv.instabilityUntil = G.time + 30;
        notify(`🧪 The Board replaces its Director. ${leaderLabel(gv.leader)} now leads the technate.`, 'warn', 8);
      }
      break;
    }
  }
  refreshWindows();
}

function resolveCoup() {
  const gv = G.gov;
  if (Math.random() < 0.5) {
    gv.instabilityUntil = G.time + 45;
    notify(`👊 COUP ATTEMPT crushed! ${leaderLabel(gv.leader)} survives. Brief instability.`, 'warn', 8);
  } else {
    const old = gv.leader;
    gv.leader = newLeader();
    gv.instabilityUntil = G.time + 90;
    notify(`👊 COUP! ${leaderTitle()} ${old.name} was overthrown. ${leaderLabel(gv.leader)} seizes power. -25% income for 90s.`, 'bad', 10);
  }
}

/* Democratic elections: the player backs a candidate — each brings a
   different trait to the table. Backing the favourite is safer. */
function startElection() {
  const gv = G.gov;
  const candidates = [
    { ...gv.leader, incumbent: true },
    newLeader(), newLeader(),
  ];
  // make sure the challengers differ from each other and the incumbent
  while (candidates[1].trait === candidates[0].trait) candidates[1] = newLeader();
  while (candidates[2].trait === candidates[0].trait || candidates[2].trait === candidates[1].trait) candidates[2] = newLeader();

  const label = cd => {
    const t = LEADER_TRAITS[cd.trait];
    return `${cd.incumbent ? '⭐' : t.icon} ${cd.name} — "${t.name}"`;
  };
  const backCandidate = idx => {
    const cd = candidates[idx];
    // your machine helps, but the voters judge your record (approval)
    const baseChance = cd.incumbent ? clamp(G.city.approval / 100 + 0.15, 0.1, 0.95)
                                    : clamp(0.35 + (G.city.approval - 50) / 200, 0.1, 0.8);
    if (Math.random() < baseChance) {
      gv.leader = { name: cd.name, trait: cd.trait, flaw: cd.flaw };
      notify(`🗳️ Your candidate WON! ${leaderLabel(gv.leader)} takes office.`, 'good', 9);
      if (!cd.incumbent) gv.instabilityUntil = G.time + 30; // short transition
    } else {
      const others = candidates.filter((_, i) => i !== idx);
      const winner = others[Math.floor(Math.random() * others.length)];
      gv.leader = { name: winner.name, trait: winner.trait, flaw: winner.flaw };
      gv.instabilityUntil = G.time + 60;
      notify(`🗳️ Your candidate LOST. ${leaderLabel(gv.leader)} wins the election. Transition instability: -25% income for 60s.`, 'warn', 10);
    }
    refreshWindows();
  };
  openDecision(
    'National Election',
    `Approval ${Math.round(G.city.approval)}%. Back a candidate; the voters still decide based on approval and stability. Every candidate is a trade-off — weigh the strength against the flaw.`,
    candidates.map((cd, i) => {
      const t = LEADER_TRAITS[cd.trait];
      const f = cd.flaw ? LEADER_FLAWS[cd.flaw] : null;
      const chance = cd.incumbent ? clamp(G.city.approval / 100 + 0.15, 0.1, 0.95)
                                  : clamp(0.35 + (G.city.approval - 50) / 200, 0.1, 0.8);
      return {
        title: label(cd),
        pros: [t.desc, `Estimated win chance: ${Math.round(chance * 100)}%`],
        cons: [
          ...(f ? [`${f.icon} ${f.name}: ${f.desc}`] : []),
          cd.incumbent ? 'Incumbent keeps current strengths and weaknesses.' : 'If your candidate loses, transition instability lasts 60s.',
        ],
        actionLabel: 'Back candidate',
        fn: () => backCandidate(i),
      };
    }));
}

/* Constitutional reform — switch government mid-game */
function switchGovernment(newForm, confirmed = false) {
  const gv = G.gov;
  if (newForm === gv.form) return;
  // a constitutional framework makes reform cheaper and smoother
  const discount = fxv('reformDiscount') ? 0.5 : 1;
  const cost = Math.round(GOV_SWITCH_COST * discount);
  const instab = Math.round(GOV_SWITCH_INSTABILITY * discount);
  if (G.time < (gv.lastSwitch || -Infinity) + GOV_SWITCH_COOLDOWN) {
    notify(`The nation needs ${Math.ceil(((gv.lastSwitch + GOV_SWITCH_COOLDOWN) - G.time) / 60)} more minutes before another reform.`, 'warn');
    return;
  }
  if (G.res.money < cost) {
    notify(`Constitutional reform costs $${cost}.`, 'warn');
    return;
  }
  if (!confirmed) {
    const oldGov = GOVERNMENTS[gv.form], newGov = GOVERNMENTS[newForm];
    openDecision('Constitutional Reform',
      `You are changing the state from ${oldGov.name} to ${newGov.name}. This is a major political move.`,
      [{
        title: `${newGov.icon} ${newGov.name}`,
        pros: [newGov.desc],
        cons: [`Cost: $${cost}`, `${instab}s instability`, `${Math.round(GOV_SWITCH_COOLDOWN / 60)} min cooldown`],
        actionLabel: 'Pass reform',
        danger: true,
        fn: () => switchGovernment(newForm, true),
      }]);
    return;
  }
  G.res.money -= cost;
  gv.form = newForm;
  gv.lastSwitch = G.time;
  gv.leader = newLeader();
  gv.instabilityUntil = G.time + instab;
  const firstEvent = { democracy: 5, dictatorship: 5, monarchy: 10, technocracy: 8 }[newForm];
  gv.nextEvent = G.time + firstEvent * YEAR_SECONDS;
  G.civic.nextElection = G.time + LOCAL_ELECTION_EVERY * YEAR_SECONDS;
  const gov = GOVERNMENTS[newForm];
  notify(`${gov.icon} CONSTITUTIONAL REFORM! The nation is now a ${gov.name}. ${leaderLabel(gv.leader)} takes power. Transition instability for ${GOV_SWITCH_INSTABILITY}s.`, 'warn', 10);
  refreshWindows();
}

/* ---------------- production API (player) ---------------- */
function tryTrain(building, unitKey) {
  const def = UNITS[unitKey];
  if (def.needsDiscovery && !G.discovered[def.needsDiscovery]) {
    notify(`${def.name} requires the "${DISCOVERIES[def.needsDiscovery].name}" discovery (Research window).`, 'warn');
    return false;
  }
  if (G.city.popUsed + def.pop > G.city.popCap) {
    notify('Not enough housing! Build Housing Blocks to raise army capacity.', 'warn');
    return false;
  }
  // air bases have a limited number of plane slots
  if (isPlaneKey(unitKey)) {
    const slots = building.def.planeSlots || 0;
    const based = planesBasedAt(building) + building.queue.filter(q => isPlaneKey(q)).length;
    if (based >= slots) {
      notify(`Air base is full (${slots} plane slots). Build another Airfield or scrap a plane.`, 'warn');
      return false;
    }
  }
  const cost = unitTechCost(unitKey); // heavy industry / drone swarms cut costs
  if (!canAfford(G.res, cost)) { notify('Cannot afford ' + def.name + '.', 'warn'); return false; }
  payCost(G.res, cost);
  building.queue.push(unitKey);
  return true;
}

/* jets & bombers are runway aircraft — they live at an airfield.
   Drones and helicopters are not (they loiter freely). */
function isPlaneKey(key) { return key === 'jet' || key === 'bomber'; }
function planesBasedAt(airfield) {
  return G.units.filter(u => !u.dead && u.homeBase === airfield).length;
}

function tryProduceMissile(building, mType) {
  const def = MISSILES[mType];
  if (def.needsDiscovery && !G.discovered[def.needsDiscovery]) {
    notify(`${def.name} requires the "${DISCOVERIES[def.needsDiscovery].name}" discovery.`, 'warn');
    return false;
  }
  const queuedMissiles = G.buildings.filter(b => b.owner === 0 && !b.dead)
    .reduce((s, b) => s + b.queue.filter(q => q.startsWith('missile:')).length, 0);
  if (missileStock() + queuedMissiles >= missileCap()) {
    notify(`Missile storage full (${missileCap()}). Build more Ammo Depots.`, 'warn');
    return false;
  }
  const cost = { ...def.cost };
  if (!canAfford(G.res, cost)) { notify('Cannot afford ' + def.name + ` (${costText(cost)}).`, 'warn'); return false; }
  payCost(G.res, cost);
  building.queue.push('missile:' + mType);
  return true;
}
