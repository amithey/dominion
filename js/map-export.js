'use strict';

/* Engine-neutral map export. The browser generates the world (seeded with
   ?seed=N), so another engine can load exactly the same island instead of an
   approximation: terrain heights on a regular grid, trees, deposits,
   buildings, units and start positions.

   ?export=http://localhost:PORT/name  starts the visual-review scene, waits
   for it to settle and posts the JSON to a local collector. Heights are
   stored in centimetres as integers, row by row (z outer, x inner). */
function exportMapData(step = 2.5) {
  const extent = HALF_MAP * 1.1; // include the seabed beyond the coast
  const size = Math.round(extent * 2 / step) + 1;
  const heights = new Array(size * size);
  for (let row = 0; row < size; row++) {
    const z = -extent + row * step;
    for (let col = 0; col < size; col++) heights[row * size + col] = Math.round(terrainH(-extent + col * step, z) * 100);
  }
  const round = v => Math.round(v * 100) / 100;
  return {
    format: 'dominion-map', version: 1,
    seed: new URLSearchParams(location.search).get('seed') ?? null,
    style: MAP_STYLE, mapSize: MAP_SIZE, seaLevel: SEA_LEVEL,
    grid: { origin: [-extent, -extent], step, size, heightsCm: heights },
    startPositions: START_POS.map(([x, z]) => [round(x), round(z)]),
    nations: G.nations.map(n => ({ name: n.name, color: '#' + new THREE.Color(n.color).getHexString(), player: !!n.isPlayer })),
    trees: TREES.list.filter(t => !t.removed).map(t => ({
      x: round(t.x), z: round(t.z), scale: round(t.s), kind: t.kind, grove: t.grove ?? -1,
    })),
    deposits: G.deposits.map(d => ({ type: d.type, x: round(d.x), z: round(d.z) })),
    buildings: G.buildings.filter(b => !b.dead).map(b => ({ key: b.key, owner: b.owner, x: round(b.x), z: round(b.z), built: !!b.built })),
    units: G.units.filter(u => !u.dead).map(u => ({ key: u.key, owner: u.owner, x: round(u.x), z: round(u.z) })),
  };
}

(() => {
  const target = new URLSearchParams(location.search).get('export');
  if (!target || !/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//.test(target)) return;
  G.reviewMode = true;
  if (!G.started && !G.loading) startGame();
  const wait = setInterval(() => {
    if (!G.started || !document.getElementById('review-drill')) return;
    clearInterval(wait);
    fetch(target, { method: 'POST', body: JSON.stringify(exportMapData()) })
      .then(() => notify('Map exported.', 'good'))
      .catch(error => notify(`Map export failed: ${error.message}`, 'warn'));
  }, 300);
})();
