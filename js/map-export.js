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
    nations: G.nations.map((n, i) => ({
      name: n.name, color: '#' + new THREE.Color(n.color).getHexString(), player: !!n.isPlayer,
      people: (NATION_DEFS[i] && NATION_DEFS[i].people) || {},
    })),
    trees: TREES.list.filter(t => !t.removed).map(t => ({
      x: round(t.x), z: round(t.z), scale: round(t.s), kind: t.kind, grove: t.grove ?? -1,
    })),
    deposits: G.deposits.map(d => ({ type: d.type, x: round(d.x), z: round(d.z) })),
    buildings: G.buildings.filter(b => !b.dead).map(b => ({ key: b.key, owner: b.owner, x: round(b.x), z: round(b.z), built: !!b.built })),
    units: G.units.filter(u => !u.dead).map(u => ({ key: u.key, owner: u.owner, x: round(u.x), z: round(u.z) })),
    // Combat stats straight from config.js, so both engines share one balance.
    unitDefs: Object.fromEntries(Object.entries(UNITS).map(([key, d]) => [key, {
      name: d.name, hp: d.hp, dmg: d.dmg, range: d.range, cooldown: d.cooldown,
      aggro: d.aggro ?? d.range, speed: d.speed, fly: !!d.fly, naval: !!d.naval,
      cost: d.cost || {}, trainTime: d.trainTime || 10, pop: d.pop ?? 1, desc: d.desc || '',
    }])),
    // Economy data, so buildings, prices and rates match config.js exactly.
    buildingDefs: Object.fromEntries(Object.entries(BUILDINGS).map(([key, d]) => [key, {
      name: d.name, cat: d.cat, size: d.size, hp: d.hp, cost: d.cost || {}, buildTime: d.buildTime || 0,
      trains: d.trains || [], provides: d.provides || {}, onDeposit: !!d.onDeposit,
      depositTypes: d.depositTypes || null, unique: !!d.unique, unbuildable: !!d.unbuildable,
      buildRadius: d.buildRadius || 0, settlement: d.settlement || null, coastal: !!d.coastal, desc: d.desc || '',
    }])),
    depositTypes: Object.fromEntries(Object.entries(DEPOSIT_TYPES).map(([key, d]) => [key, {
      name: d.name, res: d.res, rate: d.rate, water: !!d.water, color: '#' + d.color.toString(16).padStart(6, '0'),
    }])),
    economy: {
      startResources: { money: 1200, food: 250, oil: 0, iron: 120, silicon: 0, uranium: 0 },
      baseCap: BASE_CAP, warehouseBonus: WAREHOUSE_CAP_BONUS, foodCapBase: 300, foodDepotBonus: 500,
      baseCivCap: 200, startCivilians: 120, taxPerCivilian: 0.035, baseAdmin: 0.28,
      foodPerCivilian: 0.008, foodPerSoldier: 0.05, farmFood: 2.0,
    },
    // AI opponents: difficulty table, opening build order and training pool (ai.js).
    ai: { difficulty: DIFFICULTY, buildOrder: AI_BUILD_ORDER, trainPool: AI_TRAIN_POOL },
    // Supply network (logistics.js): hex size and road/rail prices and toughness.
    // Who can hurt what, and how much (entities.js DAMAGE_PROFILE / targetClass).
    combat: { damageProfile: DAMAGE_PROFILE, infantry: [...INFANTRY_KEYS], armor: [...ARMOR_KEYS] },
    logistics: { hexRadius: HEX_RADIUS, transport: TRANSPORT, railProductionBonus: 0.25 },
    // Munitions built at a Missile Silo and stored in Ammo Depots (entities.js).
    missiles: { types: MISSILES, baseCap: BASE_MISSILE_CAP, capPerDepot: 4 },
    // Covert operations and named field agents (diplomacy.js).
    espionage: {
      ops: SPY_OPS, targets: ASSASSIN_TARGETS, agentNames: AGENT_NAMES, xpLevels: AGENT_XP_LEVELS,
      skillBonus: AGENT_SKILL_BONUS, ransom: AGENT_RANSOM, ranks: AGENT_RANKS, recruitBase: 400, recruitStep: 120,
    },
    // World market prices and overseas trade routes (diplomacy.js).
    trade: {
      price: TRADE_PRICE, qty: TRADE_QTY, importMarkup: TRADE_IMPORT_MARKUP, instantSell: TRADE_INSTANT_SELL,
      instantBuy: TRADE_INSTANT_BUY, voyage: TRADE_VOYAGE_SECONDS, routesPerPort: TRADE_ROUTES_PER_PORT,
    },
    // Gradual territory control (territory.js).
    territory: { cell: TERRITORY_CELL, halfMap: HALF_MAP },
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
