'use strict';

// Optional visual-review scenario, separate from normal campaign balance.
function setupVisualReview() {
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
  camDist = camZoomTarget = 115;
  camFocus.set(x, 0, z + 1);
  document.querySelector('.campaign-status').textContent = 'VISUAL REVIEW';
  const controls = document.createElement('div');
  controls.id = 'review-controls';
  controls.innerHTML = '<span>VISUAL REVIEW</span><button data-view="base">Base</button><button data-view="infantry">Infantry</button><button data-view="armor">Armor</button><button data-view="air">Air</button><button data-view="sea">Sea</button><button data-view="effects">Missile & blast</button><button id="review-exit">New campaign</button>';
  controls.querySelector('[data-view="sea"]').disabled = !sea;
  document.getElementById('game-container').appendChild(controls);
  const showView = kind => {
    camFocus.set(x + (kind === 'armor' ? 18 : kind === 'infantry' ? -4 : 0), 0, z + (kind === 'base' ? 1 : 21));
    camZoomTarget = kind === 'base' ? 115 : kind === 'armor' ? 35 : 24;
    camPitch = kind === 'base' ? .95 : .5;
    camYaw = Math.PI * .25;
    if (kind === 'air') { camFocus.set(x, 16, z + 42); camZoomTarget = 50; camPitch = .65; }
    if (kind === 'sea' && sea) { camFocus.set(sea[0], 0, sea[1]); camZoomTarget = 45; camPitch = .65; }
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
  showView(['infantry', 'armor', 'air', 'sea', 'effects'].includes(initialView) ? initialView : 'base');
  controls.querySelector('#review-exit').onclick = () => location.assign('index.html');
}

function updateReviewStrike(dt) {
  const m = G.reviewStrike;
  if (!m) return;
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
