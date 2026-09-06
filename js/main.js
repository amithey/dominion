'use strict';
/* ============================================================
   Main: renderer, camera, input, game loop
   ============================================================ */

/* ---- global game state ---- */
const G = {
  started: false, paused: true, gameOver: false,
  reviewMode: false,
  time: 0, speed: 1, frame: 0,
  difficulty: 'easy', gfxHigh: true, graphics: 'balanced', resolutionMode: 'native',
  mapStyle: 'island', mapSize: 'large',
  res: { money: 1200, food: 250, oil: 0, iron: 120, silicon: 0, uranium: 0 },
  nations: [], units: [], buildings: [], deposits: [], effects: [],
  selection: [], placing: null, targeting: null,
  city: { civilians: 120, happiness: 60, health: 55, education: 35, morale: 60, research: 0, researchRate: 0, income: 0, foodRate: 0, popCap: 10, popUsed: 0, order: 50, culture: 20, approval: 50, civCap: 200, caps: {}, power: { supply: 0, demand: 0, factor: 1 }, compute: 0 },
  tech: { economy: 0, military: 0, espionage: 0, hightech: 0 },
  discovered: {},
  munitions: { tactical: 0, cruise: 0, cluster: 0, emp: 0, antiShip: 0, ballistic: 0, hypersonic: 0, nuke: 0 },
  missilesInFlight: [],
  gov: { form: 'democracy', leader: null, nextEvent: Infinity, instabilityUntil: 0 },
  civic: { leader: null, nextElection: Infinity, lastAppointment: -Infinity },
  policies: { tax: 'normal', rationing: false, propaganda: false, freeHealthcare: false },
  agentRoster: [],
  spy: { network: [], heat: [], lastReport: [], intel: [], types: [], reports: [] },
  market: { mult: { food: 1, oil: 1, iron: 1, silicon: 1, uranium: 1 } },
  trade: { routes: [], delivered: 0, lost: 0 },
  development: { era: 0 },
  startCorner: -1, // -1 = random
  warWeariness: 0,
};

let scene, camera, renderer, sunLight, terrainMesh;
const camFocus = new THREE.Vector3(START_POS[0][0], 0, START_POS[0][1]);
let camDist = 78, camZoomTarget = 78, camYaw = Math.PI * 0.25;
let camPitch = 0.95; // radians above horizon — R/F tilt toward top-down / cinematic
const keys = {};
let mouse = { x: 0, y: 0, down: false, sx: 0, sy: 0, dragging: false, onCanvas: false, midPan: false };
const raycaster = new THREE.Raycaster();
let composer = null, bloomPass = null, fxaaPass = null, smaaPass = null, gtaoPass = null;
let renderPixelRatio = 1;
let qualitySampleTime = 0, qualityFrameTime = 0, qualityFrames = 0;

/* ---------------- init ---------------- */
function initEngine() {
  const canvas = document.getElementById('game-canvas');
  renderer = new THREE.WebGLRenderer({
    canvas, antialias: true, powerPreference: 'high-performance',
    alpha: false, stencil: false,
  });
  renderer.setSize(innerWidth, innerHeight);
  // a crisp image is most of what separates "real game" from "browser demo";
  // the dynamic-resolution governor below only trims this when frames slip
  renderPixelRatio = displayPixelRatio();
  renderer.setPixelRatio(renderPixelRatio);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.shadowMap.enabled = G.gfxHigh;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.shadowMap.autoUpdate = false;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.10;

  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(48, innerWidth / innerHeight, 1, 2600);
  updateCameraViewport();

  sunLight = buildLights(scene, G.gfxHigh);
  // image-based lighting captured from THIS sky, not a generic studio room:
  // ground, metal, glass and water all pick up the real sky gradient and sun
  try {
    const pmrem = new THREE.PMREMGenerator(renderer);
    pmrem.compileEquirectangularShader();
    scene.environment = pmrem.fromScene(scene, 0.04).texture;
    // authored building textures are fairly dark; a healthy sky bounce keeps
    // their facades readable instead of collapsing them into black blocks
    scene.environmentIntensity = 0.9;
    pmrem.dispose();
  } catch (e) { console.warn('Environment reflections unavailable.', e); }
  terrainMesh = buildTerrain(scene);
  buildWater(scene);
  buildShoreline(scene);
  buildClouds(scene);
  G.deposits = placeDeposits(scene);
  decorate(scene);
  initTerritory();
  initComposer();

  window.addEventListener('resize', () => {
    camera.aspect = innerWidth / innerHeight;
    updateCameraViewport();
    renderPixelRatio = displayPixelRatio();
    renderer.setPixelRatio(renderPixelRatio);
    renderer.setSize(innerWidth, innerHeight);
    if (composer) {
      composer.setPixelRatio(renderPixelRatio);
      composer.setSize(innerWidth, innerHeight);
      setFxaaResolution();
      if (smaaPass) smaaPass.setSize(innerWidth * renderer.getPixelRatio(), innerHeight * renderer.getPixelRatio());
    }
  });
}

/* cinematic post-processing: bloom makes fire, tracers and windows glow;
   FXAA restores the anti-aliasing the composer pipeline bypasses.
   Degrades gracefully to a plain render if the CDN scripts didn't load. */
function initComposer() {
  if (G.graphics !== 'cinematic' || !THREE.EffectComposer || !THREE.UnrealBloomPass || !THREE.ShaderPass) return;
  try {
    composer = new THREE.EffectComposer(renderer);
    if (composer.setPixelRatio) composer.setPixelRatio(renderer.getPixelRatio());
    composer.addPass(new THREE.RenderPass(scene, camera));

    // Ambient occlusion: the darkening in creases and where objects meet the
    // ground. Without it every building looks pasted onto the terrain rather
    // than standing on it — this is the single biggest "real engine" cue.
    if (THREE.GTAOPass) {
      try {
        gtaoPass = new THREE.GTAOPass(scene, camera, innerWidth, innerHeight);
        gtaoPass.output = THREE.GTAOPass.OUTPUT.Default;
        gtaoPass.blendIntensity = 0.85;
        if (gtaoPass.updateGtaoMaterial) {
          gtaoPass.updateGtaoMaterial({
            // 8 samples reads the same as 12 at RTS camera distance and is
            // meaningfully cheaper — AO is the most expensive pass here
            radius: 0.55, distanceExponent: 1.2, thickness: 1.0,
            scale: 1.0, samples: 8, screenSpaceRadius: false,
          });
        }
        composer.addPass(gtaoPass);
      } catch (e) {
        console.warn('Ambient occlusion pass failed to initialise.', e);
        gtaoPass = null;
      }
    }

    // threshold 0.9 in tone-mapped space: only genuinely hot pixels bloom —
    // muzzle flashes, afterburners, lit windows, the sun. Never the sky.
    bloomPass = new THREE.UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.32, 0.5, 0.9);
    composer.addPass(bloomPass);

    // SMAA resolves edges far more cleanly than FXAA, which just blurs them —
    // part of why the picture read as soft.
    if (THREE.SMAAPass) {
      const pr = renderer.getPixelRatio();
      smaaPass = new THREE.SMAAPass(innerWidth * pr, innerHeight * pr);
      composer.addPass(smaaPass);
    } else {
      fxaaPass = new THREE.ShaderPass(THREE.FXAAShader);
      setFxaaResolution();
      composer.addPass(fxaaPass);
    }

    // Mandatory final pass: applies ACES tone mapping and the sRGB transfer.
    // Without it the composer hands the canvas raw linear colour, which is
    // exactly the washed-out, low-contrast look of an unfinished web build.
    if (THREE.OutputPass) composer.addPass(new THREE.OutputPass());

    composer.setSize(innerWidth, innerHeight);
  } catch (e) {
    console.warn('Post-processing unavailable, falling back to direct rendering.', e);
    composer = null;
  }
}
function setFxaaResolution() {
  if (!fxaaPass) return;
  const pr = renderer.getPixelRatio();
  fxaaPass.material.uniforms.resolution.value.set(1 / (innerWidth * pr), 1 / (innerHeight * pr));
}

/* Hold close to 60 FPS on high-DPI screens by changing only internal render
   resolution. Simulation speed and UI scale stay untouched. */
function updateDynamicResolution(dt) {
  if (G.resolutionMode !== 'auto' || document.hidden || dt > .25) return;
  qualitySampleTime += dt;
  qualityFrameTime += dt;
  qualityFrames++;
  if (qualitySampleTime < 2) return;

  const average = qualityFrameTime / Math.max(qualityFrames, 1);
  const maxRatio = Math.min(devicePixelRatio, 2);
  let next = renderPixelRatio;

  // Ambient occlusion is by far the most expensive pass, so it is the first
  // thing sacrificed when frames slip — dropping it costs some contact shading
  // but keeps the image sharp, whereas cutting resolution makes everything soft.
  if (gtaoPass) {
    if (average > 1 / 45 && gtaoPass.enabled) {
      gtaoPass.enabled = false;
      qualitySampleTime = qualityFrameTime = 0; qualityFrames = 0;
      return;
    }
    if (average < 1 / 75 && !gtaoPass.enabled && renderPixelRatio >= maxRatio - 0.01) {
      gtaoPass.enabled = true;
      qualitySampleTime = qualityFrameTime = 0; qualityFrames = 0;
      return;
    }
  }

  // never fall below 0.9: a soft, upscaled image costs more perceived quality
  // than the handful of frames it buys back
  if (average > 1 / 50) next = Math.max(1, renderPixelRatio - 0.1);
  else if (average < 1 / 59) next = Math.min(maxRatio, renderPixelRatio + 0.05);

  if (Math.abs(next - renderPixelRatio) > 0.001) {
    renderPixelRatio = next;
    renderer.setPixelRatio(renderPixelRatio);
    renderer.setSize(innerWidth, innerHeight, false);
    if (composer) {
      if (composer.setPixelRatio) composer.setPixelRatio(renderPixelRatio);
      composer.setSize(innerWidth, innerHeight);
      setFxaaResolution();
      if (smaaPass) smaaPass.setSize(innerWidth * renderer.getPixelRatio(), innerHeight * renderer.getPixelRatio());
    }
  }
  qualitySampleTime = qualityFrameTime = 0;
  qualityFrames = 0;
}

function setupNations() {
  G.nations = NATION_DEFS.map((d, i) => ({
    ...d, id: i, money: 800, defeated: false,
    debuffPresident: 0, debuffGeneral: 0, debuffProxy: 0, debuffSpymaster: 0,
  }));
  initDiplomacy();
  for (let i = 0; i < G.nations.length; i++) {
    const [x, z] = START_POS[i];
    spawnBuilding('hq', i, x, z, { instant: true });
    if (i === 0) {
      for (let w = 0; w < 3; w++) spawnUnit('worker', 0, x + 12 + w * 3, z + 10);
      spawnUnit('soldier', 0, x - 12, z + 12);
      spawnUnit('soldier', 0, x - 9, z + 14);
    } else {
      initAIState(G.nations[i], i);
      for (let s = 0; s < 2; s++) spawnUnit('soldier', i, x + 10 + s * 3, z - 10);
    }
  }
}

function startGame() {
  if (G.started || G.loading) return;
  G.loading = true;
  // stream the real character models first (fast; skips itself offline)
  const startBtn = document.getElementById('btn-start');
  const reviewBtn = document.getElementById('btn-review');
  if (reviewBtn) reviewBtn.disabled = true;
  if (startBtn) { startBtn.disabled = true; startBtn.textContent = 'Loading models…'; }
  Promise.all([preloadModels(), preloadArchitectureMaterials()]).then(startGameNow).catch(err => {
    G.loading = false;
    console.error(err);
    if (reviewBtn) reviewBtn.disabled = false;
    if (startBtn) { startBtn.disabled = false; startBtn.textContent = 'Retry campaign'; }
  });
}
function startGameNow() {
  document.getElementById('main-menu').classList.add('hidden');
  setMapConfig(G.mapSize, G.mapStyle);
  // chosen start corner: swap the player's slot into position 0
  const corner = G.startCorner >= 0 ? G.startCorner : Math.floor(Math.random() * 4);
  if (corner > 0) {
    const t = START_POS[0]; START_POS[0] = START_POS[corner]; START_POS[corner] = t;
  }
  camFocus.set(START_POS[0][0], 0, START_POS[0][1]);
  initEngine();
  setupNations();
  if (G.reviewMode) setupVisualReview();
  buildMinimapTerrain();
  drawMinimap();
  updateTopBar();
  renderBuildPanel();
  // government: first leader takes office
  G.gov.leader = newLeader();
  G.civic.leader = newCivicLeader();
  G.agentRoster.push(newAgent()); // one field agent to start with
  G.civic.nextElection = LOCAL_ELECTION_EVERY * YEAR_SECONDS;
  const firstEvent = { democracy: 5, dictatorship: 5, monarchy: 10, technocracy: 8 }[G.gov.form];
  G.gov.nextEvent = G.reviewMode ? Infinity : firstEvent * YEAR_SECONDS;
  G.started = true;
  G.paused = false;
  document.documentElement.dataset.gameReady = 'true';
  const gov = GOVERNMENTS[G.gov.form];
  notify(`${gov.icon} ${gov.name} established. ${leaderLabel(G.gov.leader)} takes office.`, 'good', 10);
  notify(`${civicTitle()} ${civicLabel(G.civic.leader)} now manages the capital.`, '', 8);
  notify('Welcome, Commander. Your HQ is the capital. Build inside its district, then found Villages and Cities to expand across the map.', 'good', 12);
  notify('Open 🏙️ City to manage policies & government, 🕊️ Diplomacy and 🕵️ Intel for statecraft.', '', 12);
  requestAnimationFrame(loop);
}

/* ---------------- camera ---------------- */
function updateCamera(dt) {
  camDist += (camZoomTarget - camDist) * (1 - Math.exp(-dt * 12));
  const panSpeed = camDist * 0.9 * dt;
  const fwdX = -Math.sin(camYaw), fwdZ = -Math.cos(camYaw);
  const rightX = Math.cos(camYaw), rightZ = -Math.sin(camYaw);
  // classic RTS edge scrolling — push the pointer against a screen edge to pan
  if (mouse.onCanvas && G.started && !G.paused && !mouse.midPan) {
    const M = 16;
    if (mouse.y < M) { camFocus.x += fwdX * panSpeed; camFocus.z += fwdZ * panSpeed; }
    if (mouse.y > innerHeight - M) { camFocus.x -= fwdX * panSpeed; camFocus.z -= fwdZ * panSpeed; }
    if (mouse.x > innerWidth - M) { camFocus.x += rightX * panSpeed; camFocus.z += rightZ * panSpeed; }
    if (mouse.x < M) { camFocus.x -= rightX * panSpeed; camFocus.z -= rightZ * panSpeed; }
  }
  if (keys['w'] || keys['arrowup']) { camFocus.x += fwdX * panSpeed; camFocus.z += fwdZ * panSpeed; }
  if (keys['s'] || keys['arrowdown']) { camFocus.x -= fwdX * panSpeed; camFocus.z -= fwdZ * panSpeed; }
  if (keys['d'] || keys['arrowright']) { camFocus.x += rightX * panSpeed; camFocus.z += rightZ * panSpeed; }
  // 'A' is also the attack-move modifier — only pan with it when no combat units are selected
  const aPans = keys['a'] && !G.selection.some(u => u.type === 'unit' && u.def.dmg > 0);
  if (aPans || keys['arrowleft']) { camFocus.x -= rightX * panSpeed; camFocus.z -= rightZ * panSpeed; }
  if (keys['q']) camYaw += dt * 1.6;
  if (keys['e']) camYaw -= dt * 1.6;
  camFocus.x = clamp(camFocus.x, -HALF_MAP, HALF_MAP);
  camFocus.z = clamp(camFocus.z, -HALF_MAP, HALF_MAP);

  // R/F tilt the camera between top-down command view and low cinematic view
  if (keys['r']) camPitch = Math.min(1.25, camPitch + dt * 1.1);
  if (keys['f']) camPitch = Math.max(0.38, camPitch - dt * 1.1);

  const fy = terrainH(camFocus.x, camFocus.z);
  const cx = camFocus.x + Math.sin(camYaw) * camDist * Math.cos(camPitch);
  const cz = camFocus.z + Math.cos(camYaw) * camDist * Math.cos(camPitch);
  const cy = fy + camDist * Math.sin(camPitch);
  camera.position.set(cx, cy, cz);
  camera.lookAt(camFocus.x, fy, camFocus.z);

  // keep the shadow camera centered on view, and no wider than the view needs
  if (sunLight && sunLight.castShadow) {
    sunLight.position.set(camFocus.x + 120, 180, camFocus.z + 60);
    sunLight.target.position.set(camFocus.x, 0, camFocus.z);
    setShadowExtent(sunLight, clamp(camDist * 1.15, 55, 260));
  }
}

/* ---------------- picking helpers ---------------- */
function groundPoint(clientX, clientY) {
  const ndc = new THREE.Vector2((clientX / innerWidth) * 2 - 1, -(clientY / innerHeight) * 2 + 1);
  raycaster.setFromCamera(ndc, camera);
  const hits = raycaster.intersectObject(terrainMesh);
  return hits.length ? hits[0].point : null;
}
function pickEntity(clientX, clientY) {
  const ndc = new THREE.Vector2((clientX / innerWidth) * 2 - 1, -(clientY / innerHeight) * 2 + 1);
  raycaster.setFromCamera(ndc, camera);
  const meshes = [];
  for (const e of G.units) if (!e.dead) meshes.push(e.mesh);
  for (const e of G.buildings) if (!e.dead) meshes.push(e.mesh);
  for (const d of G.deposits) meshes.push(d.mesh);
  const hits = raycaster.intersectObjects(meshes, true);
  for (const h of hits) {
    let o = h.object;
    while (o) {
      if (o.userData.entity) return { entity: o.userData.entity };
      if (o.userData.deposit) return { deposit: o.userData.deposit };
      o = o.parent;
    }
  }
  return null;
}

/* ---------------- selection ---------------- */
function clearSelection() {
  for (const e of G.selection) {
    e.selected = false;
    if (e.ring) e.ring.visible = false;
    if (e.districtRing) e.districtRing.visible = false;
  }
  G.selection.length = 0;
}
function select(ents) {
  clearSelection();
  for (const e of ents) {
    e.selected = true;
    if (e.ring) { e.ring.visible = true; e.ring.material.color.setHex(e.owner === 0 ? 0x7dff8f : 0xff7d7d); }
    if (e.districtRing) e.districtRing.visible = true;
    G.selection.push(e);
  }
  renderSelection();
}
function boxSelect(x1, y1, x2, y2) {
  const minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
  const minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
  const v = new THREE.Vector3();
  const picked = [];
  for (const u of G.units) {
    if (u.dead || u.owner !== 0) continue;
    v.copy(u.mesh.position).project(camera);
    const sx = (v.x + 1) / 2 * innerWidth, sy = (-v.y + 1) / 2 * innerHeight;
    if (sx >= minX && sx <= maxX && sy >= minY && sy <= maxY) picked.push(u);
  }
  if (picked.length) {
    // prefer combat units when mixed
    const combat = picked.filter(u => u.def.dmg > 0);
    select(combat.length ? combat : picked);
  } else clearSelection(), renderSelection();
}

/* ---------------- building placement ---------------- */
let ghost = null;
function startPlacement(key) {
  cancelPlacement();
  const def = BUILDINGS[key];
  if (!canAfford(G.res, def.cost)) return;
  if (def.needsDiscovery && !G.discovered[def.needsDiscovery]) {
    notify(`${def.name} requires the "${DISCOVERIES[def.needsDiscovery].name}" discovery.`, 'warn');
    return;
  }
  const hasWorker = G.units.some(u => u.owner === 0 && !u.dead && u.key === 'worker');
  if (!def.selfBuild && !hasWorker) { notify('You need a worker to construct buildings. Train one at the HQ.', 'warn'); return; }
  G.placing = key;
  ghost = buildingMesh(key, G.nations[0].color);
  ghost.traverse(o => { if (o.material) { o.material = o.material.clone(); o.material.transparent = true; o.material.opacity = 0.55; } });
  scene.add(ghost);
}
function cancelPlacement() {
  if (ghost) { scene.remove(ghost); ghost = null; }
  G.placing = null;
}
function placementValid(x, z) {
  const def = BUILDINGS[G.placing];
  if (def.onDeposit) {
    // extractors go on land deposits; offshore rigs only on their sea fields
    const dep = G.deposits.find(d => !d.hasExtractor && dist2d(d.x, d.z, x, z) < 8
      && (def.depositTypes ? def.depositTypes.includes(d.type) : !d.def.water));
    if (!dep) return { ok: false };
    const settlementOk = !!settlementBuildZoneAt(dep.x, dep.z, 0);
    const tOwner = territoryOwnerAt(dep.x, dep.z);
    const blockedByTerritory = tOwner > 0 || territoryIsContested(dep.x, dep.z);
    return { ok: settlementOk && !blockedByTerritory, dep, x: dep.x, z: dep.z, outsideSettlement: !settlementOk, blockedByTerritory };
  }
  // mountain-only structures need genuinely high ground
  if (def.terrain === 'mountain' && terrainH(x, z) < 5) return { ok: false, needsMountain: true };
  const clearB = G.buildings.every(b => b.dead || dist2d(b.x, b.z, x, z) > b.def.size + def.size + 1.5);
  const clearD = G.deposits.every(d => dist2d(d.x, d.z, x, z) > def.size + 5);
  const h0 = terrainH(x, z);
  const onLand = h0 > 0.5;
  // coastal buildings (shipyard) must touch the water line
  const coastOk = def.coastal ? nearCoast(x, z) : true;
  // forests must be cleared before building on them
  const blockedByTrees = treesNear(x, z, def.size + 1).length > 0;
  // you can only build on your own or unclaimed territory
  const tOwner = territoryOwnerAt(x, z);
  const blockedByTerritory = tOwner > 0 || territoryIsContested(x, z); // 0 = player, -1 = neutral
  const settlementOk = def.settlement ? settlementCanBeFounded(def, x, z, 0) : !!settlementBuildZoneAt(x, z, 0);
  // slope check
  const slopeOk = [[4, 0], [-4, 0], [0, 4], [0, -4]].every(([dx, dz]) => Math.abs(terrainH(x + dx, z + dz) - h0) < 3);
  return {
    ok: clearB && clearD && slopeOk && onLand && coastOk && settlementOk && !blockedByTrees && !blockedByTerritory
      && Math.abs(x) < HALF_MAP - 10 && Math.abs(z) < HALF_MAP - 10,
    x, z, blockedByTrees, blockedByTerritory, outsideSettlement: !settlementOk,
  };
}
function tryPlace(clientX, clientY) {
  const p = groundPoint(clientX, clientY);
  if (!p) return;
  const v = placementValid(p.x, p.z);
  if (!v.ok) {
    let why = 'Cannot build here.';
    const pdef = BUILDINGS[G.placing];
    if (v.outsideSettlement) why = pdef.settlement
      ? `🏘️ Settlements need room to grow. Place this ${pdef.settlement} farther from your existing capital, cities and villages.`
      : '🏙️ Construction is limited to a settlement district. Build a Village Center or City Center to expand.';
    else if (pdef.onDeposit) why += pdef.depositTypes
      ? ` Must be placed on a free ${pdef.depositTypes.map(t => DEPOSIT_TYPES[t].name).join(' / ')}.`
      : ' Extractors must be placed on a free land deposit.';
    else if (v.needsMountain) why = '⛰️ This must be built on high mountainous ground.';
    else if (v.blockedByTrees) why = '🌲 The forest is in the way — send a worker to clear it first (right-click the trees).';
    else if (v.blockedByTerritory) why = '🗺️ This land belongs to another nation. Capture it with troops first.';
    notify(why, 'warn');
    return;
  }
  const def = BUILDINGS[G.placing];
  payCost(G.res, def.cost);
  const b = spawnBuilding(G.placing, 0, v.x, v.z, { deposit: v.dep || null });
  if (!def.selfBuild) {
    // send nearest idle-ish worker (self-building structures need no crew)
    const workers = G.units.filter(u => u.owner === 0 && !u.dead && u.key === 'worker')
      .sort((a, b2) => dist2d(a.x, a.z, v.x, v.z) - dist2d(b2.x, b2.z, v.x, v.z));
    const w = workers.find(u => u.state === 'idle') || workers[0];
    if (w) {
      clearHarvest(w);
      w.buildTarget = b; w.state = 'toBuild';
      w.tx = v.x; w.tz = v.z;
    }
  }
  renderBuildPanel();
  cancelPlacement();
}

/* ---------------- input ---------------- */
function initInput() {
  const canvas = document.getElementById('game-canvas');
  window.addEventListener('keydown', e => {
    const k = e.key.toLowerCase();
    if (e.target.closest('input, select, textarea') || e.target.isContentEditable) return;
    if (!G.started) return;
    if (k === 'home') { e.preventDefault(); focusCapital(); return; }
    if (k === 'f3') { e.preventDefault(); toggleDisplayPanel(); return; }
    if (k === 'f10') { e.preventDefault(); toggleGameHUD(); return; }
    if (e.repeat && [' ', 'escape'].includes(k)) return;
    keys[k] = true;
    if (k === ' ') { e.preventDefault(); togglePause(); }
    if (k === 'escape') {
      if (G.targeting) { G.targeting = null; notify('Launch aborted.', 'warn'); }
      else if (G.placing) cancelPlacement();
      else togglePause();
    }
  });
  window.addEventListener('keyup', e => keys[e.key.toLowerCase()] = false);
  window.addEventListener('blur', () => { for (const k in keys) keys[k] = false; mouse.onCanvas = mouse.midPan = mouse.down = false; hideDragBox(); });

  canvas.addEventListener('wheel', e => {
    // bigger maps allow a wider command view
    camZoomTarget = clamp(camZoomTarget + e.deltaY * 0.06, 24, Math.max(220, MAP_SIZE * 0.3));
  }, { passive: true });

  canvas.addEventListener('contextmenu', e => e.preventDefault());

  canvas.addEventListener('pointerdown', e => {
    if (!G.started || G.paused) return;
    if (e.button === 1) { // middle mouse: grab-pan
      e.preventDefault();
      mouse.midPan = true;
      return;
    }
    if (e.button === 0) {
      if (G.targeting) {
        const p = groundPoint(e.clientX, e.clientY);
        if (p && G.munitions[G.targeting.kind] > 0) {
          G.munitions[G.targeting.kind]--;
          const silo = G.targeting.silo;
          launchMissile(G.targeting.kind, silo.x, silo.z, p.x, p.z);
        }
        G.targeting = null;
        return;
      }
      if (G.placing) { tryPlace(e.clientX, e.clientY); return; }
      mouse.down = true; mouse.sx = e.clientX; mouse.sy = e.clientY; mouse.dragging = false;
    } else if (e.button === 2) {
      if (G.targeting) { G.targeting = null; notify('Launch aborted.', 'warn'); return; }
      if (G.placing) { cancelPlacement(); return; }
      handleCommand(e.clientX, e.clientY);
    }
  });
  canvas.addEventListener('pointermove', e => {
    // middle-drag pans the map like grabbing the ground
    if (mouse.midPan) {
      const scale = camDist * 0.0022;
      const dx = e.clientX - mouse.x, dy = e.clientY - mouse.y;
      const fwdX = -Math.sin(camYaw), fwdZ = -Math.cos(camYaw);
      const rightX = Math.cos(camYaw), rightZ = -Math.sin(camYaw);
      camFocus.x -= (rightX * dx - fwdX * dy) * scale;
      camFocus.z -= (rightZ * dx - fwdZ * dy) * scale;
    }
    mouse.x = e.clientX; mouse.y = e.clientY;
    mouse.onCanvas = true;
    if (mouse.down && dist2d(e.clientX, e.clientY, mouse.sx, mouse.sy) > 6) mouse.dragging = true;
    updateDragBox();
  });
  canvas.addEventListener('pointerleave', () => { mouse.onCanvas = false; });
  // double-click a unit: select every unit of that type on screen
  canvas.addEventListener('dblclick', e => {
    if (!G.started || G.paused) return;
    const hit = pickEntity(e.clientX, e.clientY);
    if (!hit || !hit.entity || hit.entity.type !== 'unit' || hit.entity.owner !== 0) return;
    const key = hit.entity.key;
    const v = new THREE.Vector3();
    const same = G.units.filter(u => {
      if (u.dead || u.owner !== 0 || u.key !== key) return false;
      v.copy(u.mesh.position).project(camera);
      return v.x > -1 && v.x < 1 && v.y > -1 && v.y < 1 && v.z < 1;
    });
    if (same.length) {
      select(same);
      notify(`Selected all ${same.length} ${UNITS[key].name}${same.length > 1 ? 's' : ''} on screen.`, '', 4);
    }
  });
  canvas.addEventListener('pointerup', e => {
    if (e.button === 1) { mouse.midPan = false; return; }
    if (e.button !== 0 || !mouse.down) return;
    mouse.down = false;
    hideDragBox();
    if (!G.started || G.paused) return;
    if (mouse.dragging) {
      boxSelect(mouse.sx, mouse.sy, e.clientX, e.clientY);
    } else {
      // single click: attack-move if A held with military selection
      if (keys['a'] && G.selection.some(u => u.type === 'unit' && u.def.dmg > 0)) {
        const p = groundPoint(e.clientX, e.clientY);
        if (p) commandMove(G.selection.filter(u => u.type === 'unit' && u.def.dmg > 0), p.x, p.z, true);
        return;
      }
      const hit = pickEntity(e.clientX, e.clientY);
      if (hit && hit.entity) select([hit.entity]);
      else { clearSelection(); renderSelection(); }
    }
  });
}

function handleCommand(cx, cy) {
  const myUnits = G.selection.filter(u => u.type === 'unit' && u.owner === 0 && !u.dead);
  if (!myUnits.length) return;
  const hit = pickEntity(cx, cy);
  // workers clear forests: right-click on/near trees
  const workersSel = myUnits.filter(u => u.key === 'worker');
  if (workersSel.length && !(hit && (hit.entity || hit.deposit))) {
    const p0 = groundPoint(cx, cy);
    if (p0) {
      const nearTrees = treesNear(p0.x, p0.z, 6);
      if (nearTrees.length) {
        workersSel.forEach((w, i) => commandChop(w, nearTrees[i % nearTrees.length]));
        notify(`🪓 Clearing the forest — workers will keep chopping the grove (${G.discovered.forestry ? '$24' : '$12'}/tree).`, '', 5);
        const fighters = myUnits.filter(u => u.key !== 'worker');
        if (fighters.length) commandMove(fighters, p0.x, p0.z);
        return;
      }
    }
  }
  if (hit && hit.deposit) {
    if (hit.deposit.def.water) {
      notify(hit.deposit.type === 'fish'
        ? '🐟 Fish schools are harvested by a coastal Fishing Wharf (requires the Aquaculture discovery).'
        : '🛢️ Sea oil needs an Offshore Rig built on the field (requires the Offshore Drilling discovery).', 'warn', 7);
      return;
    }
    const workers = myUnits.filter(u => u.key === 'worker');
    if (workers.length) {
      workers.forEach(w => commandHarvest(w, hit.deposit));
      notify(`Mining ${hit.deposit.def.name} (${RES_META[hit.deposit.def.res].icon} ${hit.deposit.def.rate / 2}/s per worker). Build an Extractor on it for full rate.`, '', 6);
      const fighters = myUnits.filter(u => u.key !== 'worker');
      if (fighters.length) commandMove(fighters, hit.deposit.x, hit.deposit.z);
      return;
    }
  }
  if (hit && hit.entity) {
    const t = hit.entity;
    if (t.owner === 0) {
      if (t.type === 'building' && !t.built) {
        // send workers to construct
        const workers = myUnits.filter(u => u.key === 'worker');
        workers.forEach(w => { clearHarvest(w); w.buildTarget = t; w.state = 'toBuild'; w.tx = t.x; w.tz = t.z; });
        if (workers.length) return;
      }
      commandMove(myUnits, t.x, t.z);
      return;
    }
    // enemy: attack (auto-declares war on first shot)
    if (!isAtWar(0, t.owner)) {
      notifyAction(`Attack ${G.nations[t.owner].name}? This means WAR.`, [
        { label: '⚔️ Attack!', fn: () => { declareWar(0, t.owner); commandAttack(myUnits, t); } },
        { label: 'Stand down', fn: () => {} },
      ], 10);
      return;
    }
    commandAttack(myUnits, t);
    return;
  }
  const p = groundPoint(cx, cy);
  if (p) commandMove(myUnits, p.x, p.z);
}

/* drag selection box visual */
let dragBox = null;
function updateDragBox() {
  if (!mouse.down || !mouse.dragging) return hideDragBox();
  if (!dragBox) {
    dragBox = document.createElement('div');
    dragBox.style.cssText = 'position:absolute;border:1px solid #7dff8f;background:rgba(125,255,143,.08);pointer-events:none;z-index:15';
    document.getElementById('game-container').appendChild(dragBox);
  }
  dragBox.style.left = Math.min(mouse.sx, mouse.x) + 'px';
  dragBox.style.top = Math.min(mouse.sy, mouse.y) + 'px';
  dragBox.style.width = Math.abs(mouse.x - mouse.sx) + 'px';
  dragBox.style.height = Math.abs(mouse.y - mouse.sy) + 'px';
  dragBox.style.display = 'block';
}
function hideDragBox() { if (dragBox) dragBox.style.display = 'none'; }

/* ---------------- ghost follow ---------------- */
function updateGhost() {
  if (!ghost || !G.placing) return;
  const p = groundPoint(mouse.x, mouse.y);
  if (!p) return;
  const v = placementValid(p.x, p.z);
  const gx = v.dep ? v.x : p.x, gz = v.dep ? v.z : p.z;
  ghost.position.set(gx, Math.max(terrainH(gx, gz), SEA_LEVEL), gz);
  const col = v.ok ? 0x66ff88 : 0xff5555;
  ghost.traverse(o => { if (o.material && o.material.emissive) { o.material.emissive.setHex(col); o.material.emissiveIntensity = 0.35; } });
}

/* ---------------- main loop ---------------- */
const clock = new THREE.Clock();
let uiTimer = 0, cityTimer = 0, diploTimer = 0, mmTimer = 0, buildBtnTimer = 0, territoryTimer = 0;
let worldVisualTimer = 0, vegetationTimer = 0;

function loop() {
  requestAnimationFrame(loop);
  const measuredDt = clock.getDelta();
  const rawDt = Math.min(measuredDt, 0.05);
  if (!G.started) return;
  const frameStart = performance.now();
  renderer.info.autoReset = false;
  renderer.info.reset();

  if (!G.paused) {
    const dt = rawDt * G.speed;
    G.time += dt;
    G.frame++;

    // simulation
    for (const u of G.units) if (!u.dead) updateUnit(u, dt);
    for (const b of G.buildings) if (!b.dead) updateBuilding(b, dt);
    if (!G.reviewMode) for (const nat of G.nations) if (!nat.isPlayer) aiUpdate(nat, dt);
    updateMissiles(dt);
    updateEffects(dt);
    // Decorative world animation is intentionally capped. Updating thousands
    // of water/vegetation/deposit vertices every render frame caused late-game stutter.
    worldVisualTimer += dt;
    vegetationTimer += dt;
    if (worldVisualTimer >= 0.05) {
      updateClouds(worldVisualTimer);
      updateWater(G.time);
      updateDeposits(G.time);
      worldVisualTimer = 0;
    }
    if (vegetationTimer >= 0.15) {
      updateVegetation(G.time);
      vegetationTimer = 0;
    }

    // periodic ticks
    cityTimer += dt;
    if (cityTimer >= 1) { cityTimer -= 1; updateCity(); }
    diploTimer += dt;
    if (diploTimer >= 10) { diploTimer -= 10; if (!G.reviewMode) diploTick(); }
    territoryTimer += dt;
    if (territoryTimer >= 2) { territoryTimer -= 2; territoryTick(); }

    // cleanup dead
    if (G.frame % 120 === 0) {
      G.units = G.units.filter(u => !u.dead);
      G.buildings = G.buildings.filter(b => !b.dead);
    }
  }

  updateCamera(rawDt);
  updateForestLOD(camera);
  updateDynamicResolution(measuredDt);
  if (!loop._ghostTime || performance.now() - loop._ghostTime >= 33) {
    updateGhost(); loop._ghostTime = performance.now();
  }
  // pointer communicates intent: crosshair when targeting a strike, copy when
  // placing a building, grab while panning
  const wantCursor = G.targeting ? 'crosshair' : G.placing ? 'copy' : mouse.midPan ? 'grabbing' : 'default';
  if (wantCursor !== loop._cursor) {
    loop._cursor = wantCursor;
    renderer.domElement.style.cursor = wantCursor;
  }

  // UI refresh (throttled)
  uiTimer += rawDt;
  if (uiTimer >= 0.4) {
    uiTimer = 0;
    updateTopBar();
    renderSelection();
  }
  buildBtnTimer += rawDt;
  if (buildBtnTimer >= 1.5) { buildBtnTimer = 0; renderBuildPanel(); refreshWindows(); }
  mmTimer += rawDt;
  if (mmTimer >= 0.65) { mmTimer = 0; drawMinimap(); }

  // the sun's shadow box follows the camera so shadows stay crisp everywhere on the map
  if (sunLight) {
    sunLight.position.set(camFocus.x + 120, 180, camFocus.z + 60);
    sunLight.target.position.set(camFocus.x, 0, camFocus.z);
  }
  // selection rings pulse gently
  const ringPulse = 0.7 + Math.sin(performance.now() * 0.004) * 0.25;
  for (const e of G.selection) {
    if (e.ring && !e.dead) e.ring.material.opacity = ringPulse;
  }

  // Reuse the shadow atlas between lighting updates. Camera movement refreshes
  // immediately; stationary views update moving-unit shadows at 15 Hz (30 in Cinematic).
  const shadowNow = performance.now();
  const shadowMoved = !loop._shadowFocus || loop._shadowFocus.distanceToSquared(camFocus) > .04 || Math.abs((loop._shadowDist || 0) - camDist) > .1;
  if (shadowMoved || shadowNow - (loop._shadowTime || 0) >= 1000 / (G.graphics === 'cinematic' ? 30 : 15)) {
    renderer.shadowMap.needsUpdate = true;
    (loop._shadowFocus ||= new THREE.Vector3()).copy(camFocus);
    loop._shadowDist = camDist; loop._shadowTime = shadowNow;
  }
  if (composer) composer.render();
  else renderer.render(scene, camera);
  recordFrameStats(measuredDt, performance.now() - frameStart);
}

/* ---------------- boot ---------------- */
let gameUiBooted = false;
function bootGameUI() {
  if (gameUiBooted) return;
  gameUiBooted = true;
  initUI();
  initPresentation();
  initInput();
}
if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', bootGameUI, { once: true });
else bootGameUI();

// Automated visual QA hook. It is completely inert for normal players.
if (new URLSearchParams(location.search).get('autostart') === '1') {
  G.reviewMode = new URLSearchParams(location.search).get('review') === '1';
  setTimeout(() => { if (!G.started) startGame(); }, 0);
}
