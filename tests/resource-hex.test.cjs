const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const THREE = require('three');

test('land and sea deposits validate their final hex centre and preserve spacing', () => {
  let seed = 29;
  const random = Object.create(Math); random.random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  const height = x => x < 0 ? 2 : -2;
  const c = vm.createContext({ THREE, Math: random, HALF_MAP: 200, MAP_SIZE: 400, SEA_LEVEL: 0,
    START_POS: [[-150,-150], [-150,150], [150,-150], [150,150]],
    DEPOSIT_TYPES: { iron: { count: 8 }, fish: { count: 8, water: true } },
    areaScale: () => 1, terrainH: height, isNavigable: x => height(x) < 0,
    dist2d: (x,z,a,b) => Math.hypot(x-a,z-b), clamp: (x,a,b) => Math.max(a,Math.min(b,x)),
    makeDepositMesh: () => new THREE.Group(),
  });
  vm.runInContext(fs.readFileSync('js/logistics.js','utf8'), c);
  const source = fs.readFileSync('js/world.js','utf8');
  vm.runInContext(source.slice(source.indexOf('function placeDeposits('), source.indexOf('/*',source.indexOf('function placeDeposits('))), c);
  const deposits = c.placeDeposits(new THREE.Scene());
  assert.ok(deposits.some(d => d.type === 'iron') && deposits.some(d => d.type === 'fish'));
  for (const d of deposits) {
    const p = c.hexCenter(c.worldHex(d.x,d.z));
    assert.ok(Math.hypot(p.x-d.x,p.z-d.z) < 1e-8);
    assert.equal(height(d.x) < 0, !!d.def.water);
    assert.equal(d.mesh.position.x,d.x); assert.equal(d.mesh.position.z,d.z);
    for (const other of deposits) if (d !== other) assert.ok(Math.hypot(d.x-other.x,d.z-other.z) >= 26);
  }
});
