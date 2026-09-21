'use strict';

// Optional visual-review scenario, separate from normal campaign balance.
function setupVisualReview() {
  if (new URLSearchParams(location.search).has('logistics')) { setupLogisticsReview(); return; }
  const [x, z] = START_POS[0];
  G.res.money = 5000; G.res.iron = 500; G.res.food = 1000; G.res.oil = 300;
  for (const [key, dx, dz] of [
    ['barracks', -21, -17], ['tankFactory', 0, -25], ['farm', 23, -18],
    ['cottage', -25, 7], ['warehouse', 24, 5],
  ]) spawnBuilding(key, 0, x + dx, z + dz, { instant: true });
  for (const [key, dx, dz] of [
    ['soldier', -10, 21], ['soldier', -6, 21], ['sniper', -2, 21], ['commando', 2, 21],
    ['tank', 13, 19], ['tank', 20, 19], ['apc', 27, 20], ['helicopter', -28, 15],
  ]) spawnUnit(key, 0, x + dx, z + dz);
  spawnUnit('jet', 0, x - 12, z + 42);
  spawnUnit('bomber', 0, x + 8, z + 42);
  let sea = findWaterNear(x, z);
  if (!sea) {
    let best = Infinity;
    for (let sx = -HALF_MAP + 20; sx < HALF_MAP - 20; sx += 24)
      for (let sz = -HALF_MAP + 20; sz < HALF_MAP - 20; sz += 24) {
        const distance = dist2d(x, z, sx, sz);
        if (distance < best && isNavigable(sx, sz)) { sea = [sx, sz]; best = distance; }
      }
  }
  if (sea) {
    spawnUnit('destroyer', 0, sea[0], sea[1]);
    const second = findWaterNear(sea[0] + 16, sea[1] + 16);
    if (second) spawnUnit('corvette', 0, second[0], second[1]);
  }
  let subReview = null;
  if (sea) for (const [dx,dz] of [[-16,0],[0,-16],[16,0],[0,16]]) {
    if (!isNavigable(sea[0]+dx,sea[1]+dz)) continue;
    subReview = spawnUnit('nuclearSub',0,sea[0]+dx,sea[1]+dz); break;
  }
  camDist = camZoomTarget = 115;
  camFocus.set(x, 0, z + 1);
  document.querySelector('.campaign-status').textContent = 'VISUAL REVIEW';
  const controls = document.createElement('div');
  controls.id = 'review-controls';
  controls.innerHTML = '<span>VISUAL REVIEW</span><button data-view="base">Base</button><button data-view="infantry">Infantry</button><button data-view="armor">Armor</button><button data-view="air">Air</button><button data-view="sea">Sea</button><button data-view="effects">Missile & blast</button><button id="review-exit">New campaign</button>';
  controls.querySelector('[data-view="sea"]').disabled = !sea;
  const subButton=document.createElement('button');subButton.dataset.view='sub';subButton.textContent='Submarine';subButton.disabled=!subReview;
  controls.insertBefore(subButton,controls.querySelector('#review-exit'));
  const drillButton=document.createElement('button');drillButton.id='review-drill';drillButton.textContent='Army drill';
  drillButton.title='Create up to 64 units (?bench=N sets N) and move them as a formation. Click again to reverse the destination.';
  controls.insertBefore(drillButton,controls.querySelector('#review-exit'));
  let drillUnits=null,drillSide=1;
  // ?bench=N sizes the drill for repeatable performance runs (default 64).
  const drillMax=Math.min(240,Number(new URLSearchParams(location.search).get('bench'))||64);
  drillButton.onclick=()=>{
    if(!drillUnits) {
      drillUnits=[];
      for(let row=-8;row<=8&&drillUnits.length<drillMax;row++) for(let col=-8;col<=8&&drillUnits.length<drillMax;col++) {
        const px=x+col*4,pz=z+row*4;
        if(Math.abs(px)>HALF_MAP-8||Math.abs(pz)>HALF_MAP-8||terrainH(px,pz)<.5)continue;
        if(NAV.land&&!NAV.land[navIndex(px,pz)])continue;
        if(G.units.some(u=>!u.dead&&dist2d(u.x,u.z,px,pz)<3))continue;
        drillUnits.push(spawnUnit(drillUnits.length%4===0?'apc':'soldier',0,px,pz));
      }
    }
    const survivors=drillUnits.filter(u=>!u.dead);
    if(!survivors.length) {notify('No clear land for the army drill.','warn');return;}
    select(survivors);commandMove(survivors,x+drillSide*28,z+24);drillSide*=-1;
    camFocus.set(x,0,z+12);camZoomTarget=85;camPitch=.8;
    drillButton.textContent=`Move army (${survivors.length})`;
  };
  document.getElementById('game-container').appendChild(controls);
  const showView = kind => {
    G.reviewEffectLoop = kind === 'effects';
    G.reviewEffectDelay = 0;
    camFocus.set(x + (kind === 'armor' ? 18 : kind === 'infantry' ? -4 : 0), 0, z + (kind === 'base' ? 1 : 21));
    camZoomTarget = kind === 'base' ? 115 : kind === 'armor' ? 35 : 24;
    camPitch = kind === 'base' ? .95 : .5;
    camYaw = Math.PI * .25;
    if (kind === 'air') { camFocus.set(x - 12, 20, z + 42); camZoomTarget = 24; camPitch = .65; }
    if (kind === 'sea' && sea) { camFocus.set(sea[0], 0, sea[1]); camZoomTarget = 30; camPitch = .65; }
    if (kind === 'sub' && subReview) { camFocus.set(subReview.x,0,subReview.z);camZoomTarget=22;camPitch=.6; }
    if (kind === 'effects') {
      camFocus.set(x + 15, 0, z + 36); camZoomTarget = 85; camPitch = .8;
      if (G.reviewStrike) {
        scene.remove(G.reviewStrike.mesh);
        G.reviewStrike.mesh.traverse(o => { if (o.geometry) o.geometry.dispose(); });
      }
      G.reviewStrike = { type: 'cruise', sx: x - 30, sz: z + 36, tx: x + 25, tz: z + 36, t: 0, mesh: makeMissileMesh('cruise', 0x819180) };
      scene.add(G.reviewStrike.mesh);
    }
    controls.querySelectorAll('[data-view]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.view === kind)));
  };
  controls.querySelectorAll('[data-view]').forEach(button => button.onclick = () => showView(button.dataset.view));
  const initialView = new URLSearchParams(location.search).get('view');
  showView(['infantry', 'armor', 'air', 'sea', 'sub', 'effects'].includes(initialView) ? initialView : 'base');
  controls.querySelector('#review-exit').onclick = () => location.assign('index.html');
}

function setupLogisticsReview() {
  const capital = settlementBuildings(0)[0], start = worldHex(capital.x, capital.z);
  G.res.money = 8000; G.res.iron = 1000; G.res.food = 1000;
  const routes = [], towns = [capital];
  for (const [kind, key, distance] of [['road', 'villageCenter', 4], ['rail', 'cityCenter', 7]]) {
    for (let i = 0; i < 12; i++) {
      const angle = Math.atan2(-capital.z, -capital.x) + (i % 2 ? -1 : 1) * Math.ceil(i / 2) * .38;
      const goal = worldHex(capital.x + Math.cos(angle) * distance * 20.8, capital.z + Math.sin(angle) * distance * 20.8);
      const p = hexCenter(goal);
      const height = terrainH(p.x, p.z);
      if (height < .8 || [[8,0],[-8,0],[0,8],[0,-8]].some(([dx,dz]) => Math.abs(terrainH(p.x+dx,p.z+dz)-height)>1.6)) continue;
      if (!settlementCanBeFounded(BUILDINGS[key], p.x, p.z, 0)) continue;
      const route = planTransport(start, goal, 0, kind);
      if (!route || !buildTransport(route, kind)) continue;
      const town = spawnBuilding(key, 0, p.x, p.z, { instant: true }); towns.push(town); routes.push({ kind, route });
      const farmHex = { q: goal.q + 1, r: goal.r }, farm = hexCenter(farmHex);
      if (terrainH(farm.x, farm.z) > .5) spawnBuilding('farm', 0, farm.x, farm.z, { instant: true });
      break;
    }
  }
  updateLogistics(); LOGISTICS.showGrid = true; showHexGrid(true);
  const center = towns.reduce((p, t) => ({ x: p.x + t.x / towns.length, z: p.z + t.z / towns.length }), { x: 0, z: 0 });
  const focus = () => { camFocus.set(center.x, 0, center.z); camZoomTarget = camDist = 200; camPitch = .95; };
  focus(); document.querySelector('.campaign-status').textContent = 'SETTLEMENT REVIEW';
  const panel = document.createElement('div'); panel.id = 'review-controls';
  panel.innerHTML = '<span>SUPPLY DEMO</span><button id="review-network">Network view</button><button id="review-cut">Demo: missile strike</button><button id="review-repair">Repair routes</button><button id="review-exit">New campaign</button>';
  document.getElementById('game-container').appendChild(panel);
  for (const town of towns) {
    const button = document.createElement('button');
    button.textContent = town.key === 'hq' ? 'Capital close-up' : town.key === 'cityCenter' ? 'City close-up' : 'Village close-up';
    button.onclick = () => { camFocus.set(town.x, 0, town.z); camZoomTarget = 38; camPitch = .65; select([town]); };
    panel.insertBefore(button, document.getElementById('review-exit'));
  }
  document.getElementById('review-network').onclick = focus;
  document.getElementById('review-cut').disabled = !routes.length;
  document.getElementById('review-cut').onclick = () => {
    const entry = routes[routes.length - 1], route = entry.route, i = Math.max(1, Math.floor(route.length / 2));
    const a = hexCenter(route[i - 1]), b = hexCenter(route[i]);
    launchMissile('cruise', capital.x, capital.z, (a.x + b.x) / 2, (a.z + b.z) / 2);
    notify('Demo strike inbound. Watch the supplied settlement counter after impact.', 'warn');
  };
  document.getElementById('review-repair').onclick = () => { for (const entry of routes) buildTransport(entry.route, entry.kind); };
  document.getElementById('review-exit').onclick = () => location.assign('index.html');
}

function updateReviewStrike(dt) {
  const m = G.reviewStrike;
  if (!m) {
    if (G.reviewEffectLoop) {
      G.reviewEffectDelay = (G.reviewEffectDelay || 0) + dt;
      if (G.reviewEffectDelay >= 3.5) {
        const [x, z] = START_POS[0];
        G.reviewEffectDelay = 0;
        G.reviewStrike = { type: 'cruise', sx: x - 30, sz: z + 36, tx: x + 25, tz: z + 36, t: 0, mesh: makeMissileMesh('cruise', 0x819180) };
        scene.add(G.reviewStrike.mesh);
      }
    }
    return;
  }
  m.t += dt;
  poseMissile(m, Math.min(1, m.t / 2.5));
  const p = m.mesh.position;
  m.trailTime = (m.trailTime || 0) + dt;
  if (m.trailTime >= .045) {
    m.trailTime %= .045;
    battleParticle(p.x, p.y, p.z, .55, 1.4, .1, .2, 0, 'steam');
  }
  if (m.t >= 2.5) {
    emitBlast(p.x, p.y, p.z, 14);
    scene.remove(m.mesh); m.mesh.traverse(o => { if (o.geometry) o.geometry.dispose(); });
    G.reviewStrike = null;
  }
}
