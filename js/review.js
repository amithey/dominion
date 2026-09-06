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
  camDist = camZoomTarget = 115;
  camFocus.set(x, 0, z + 1);
  document.querySelector('.campaign-status').textContent = 'VISUAL REVIEW';
  const controls = document.createElement('div');
  controls.id = 'review-controls';
  controls.innerHTML = '<span>VISUAL REVIEW</span><button data-view="base">Base</button><button data-view="infantry">Infantry</button><button data-view="armor">Armor</button><button id="review-exit">New campaign</button>';
  document.getElementById('game-container').appendChild(controls);
  const showView = kind => {
    camFocus.set(x + (kind === 'armor' ? 18 : kind === 'infantry' ? -4 : 0), 0, z + (kind === 'base' ? 1 : 21));
    camZoomTarget = kind === 'base' ? 115 : kind === 'armor' ? 35 : 24;
    camPitch = kind === 'base' ? .95 : .5;
    camYaw = Math.PI * .25;
    controls.querySelectorAll('[data-view]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.view === kind)));
  };
  controls.querySelectorAll('[data-view]').forEach(button => button.onclick = () => showView(button.dataset.view));
  const initialView = new URLSearchParams(location.search).get('view');
  showView(['infantry', 'armor'].includes(initialView) ? initialView : 'base');
  controls.querySelector('#review-exit').onclick = () => location.assign('index.html');
}
