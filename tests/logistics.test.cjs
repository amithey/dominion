const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const THREE = require('three');

function harness() {
  const G = { buildings: [], nations: [{ money: 1000 }, { money: 1000 }], res: { money: 1000, iron: 1000 } };
  const c = vm.createContext({ THREE, G, scene: new THREE.Scene(), HALF_MAP: 200,
    terrainH: () => 2, territoryOwnerAt: () => -1, territoryIsContested: () => false,
    document: { getElementById: () => null }, notify() {}, settlementDisplayName: b => b.key,
    treesNear: () => [], removeTree() {},
    settlementBuildings: owner => G.buildings.filter(b => b.owner === owner && b.built && !b.dead && b.def.settlement),
    settlementBuildZoneAt: (x, z, owner) => {
      const b = G.buildings.find(b => b.owner === owner && b.def.settlement && Math.hypot(b.x - x, b.z - z) < 30 && !b.dead && b.built);
      return b ? { settlement: b } : null;
    },
  });
  vm.runInContext(fs.readFileSync('js/logistics.js', 'utf8'), c);
  c.run = code => vm.runInContext(code, c);
  return c;
}

test('hex centres round-trip across negative coordinates and have six adjacent neighbours', () => {
  const c = harness();
  assert.equal(c.run(`(() => { for(let q=-20;q<=20;q++) for(let r=-20;r<=20;r++) {
    const p=hexCenter({q,r}), h=worldHex(p.x,p.z); if(h.q!==q||h.r!==r)return false;
  } return HEX_DIRECTIONS.every(([q,r])=>hexDistance({q:0,r:0},{q,r})===1); })()`), true);
});

test('supply supports branching, bypasses, destruction and repair without connecting enemy roads', () => {
  const c = harness();
  c.run(`var a={q:0,r:0},b={q:1,r:0},d={q:2,r:0},alt={q:1,r:-1};
    var edges=[{a,b,hp:100,owner:0},{a:b,b:d,hp:100,owner:0},{a,b:alt,hp:100,owner:0},{a:alt,b:b,hp:100,owner:0}];`);
  assert.equal(c.run('supplyReachable(edges,[a],0).has(hexKey(d))'), true);
  c.run('edges[0].hp=0');
  assert.equal(c.run('supplyReachable(edges,[a],0).has(hexKey(d))'), true);
  c.run('edges[2].hp=0');
  assert.equal(c.run('supplyReachable(edges,[a],0).has(hexKey(d))'), false);
  c.run('edges[0].hp=100; edges[0].owner=1');
  assert.equal(c.run('supplyReachable(edges,[a],0).has(hexKey(d))'), false);
  c.run('edges[0].owner=0');
  assert.equal(c.run('supplyReachable(edges,[a],0).has(hexKey(d))'), true);
});

test('route planner rejects water crossings and foreign land, and stays on adjacent hexes', () => {
  const c = harness();
  assert.equal(c.run('planTransport({q:0,r:0},{q:4,r:0}).length'), 5);
  c.terrainH = x => x > 7 && x < 32 ? -4 : 2;
  assert.equal(c.run('planTransport({q:0,r:0},{q:4,r:0})'), null);
  c.terrainH = () => 2; c.territoryOwnerAt = () => 1;
  assert.equal(c.run('planTransport({q:0,r:0},{q:4,r:0})'), null);
});

test('construction charges once, rejects unaffordable/invalid plans atomically, and repairs rail without downgrading it', () => {
  const c = harness();
  c.run('var route=[{q:0,r:0},{q:1,r:0},{q:2,r:0}]');
  assert.equal(c.run('buildTransport(route,"rail")'), true);
  assert.equal(c.G.res.money, 956); assert.equal(c.G.res.iron, 994);
  assert.equal(c.run('buildTransport(route,"road")'), true);
  assert.equal(c.G.res.money, 956);
  c.run('LOGISTICS.edges.values().next().value.hp=0; LOGISTICS.edges.values().next().value.tileHp=[0,0]');
  assert.equal(c.run('buildTransport(route,"road")'), true);
  assert.equal(c.G.res.money, 945); assert.equal(c.run('LOGISTICS.edges.values().next().value.kind'), 'rail');
  c.G.res.money = 0;
  assert.equal(c.run('buildTransport([{q:2,r:0},{q:3,r:0}],"road")'), false);
  assert.equal(c.run('LOGISTICS.edges.size'), 2);
  c.G.res.money = 100;
  assert.equal(c.run('buildTransport([{q:0,r:0},{q:5,r:0}],"road")'), false);
  assert.equal(c.G.res.money, 100);
});

test('blast hits the segment body, isolates its city and factory, and repair restores supply', () => {
  const c = harness();
  c.run(`var route=[{q:0,r:0},{q:1,r:0},{q:2,r:0}];
    var p=hexCenter(route[2]);
    G.buildings.push({id:1,key:'hq',x:0,z:0,owner:0,built:true,def:{settlement:'capital'}},
      {id:2,key:'cityCenter',x:p.x,z:p.z,owner:0,built:true,def:{settlement:'city'}},
      {id:3,key:'tankFactory',x:p.x+2,z:p.z,owner:0,built:true,def:{}});
    buildTransport(route,'rail');`);
  assert.equal(c.G.buildings[1].supplied, true); assert.equal(c.G.buildings[2].railSupplied, true);
  c.run('damageTransport(10,0,2,1000)');
  assert.equal(c.G.buildings[0].supplied, true);
  assert.equal(c.G.buildings[1].supplied, false); assert.equal(c.G.buildings[2].supplied, false);
  c.run('buildTransport(route,"rail")');
  assert.equal(c.G.buildings[2].supplied, true);
  c.G.buildings[0].dead = true; c.run('updateLogistics()');
  assert.equal(c.G.buildings[1].supplied, false);
});

test('isolated recruitment retains its queue and resources; rail supply resumes it with its bonus', () => {
  const c = harness(), source = fs.readFileSync('js/entities.js', 'utf8');
  c.animateBuildingSite = () => {}; c.updateHpBar = () => {}; c.prodSpeedMult = () => 1;
  c.UNITS = { soldier: { trainTime: 10 } }; c.G.time = 0;
  vm.runInContext(source.slice(source.indexOf('function updateBuilding('), source.indexOf('function economyMult(')), c);
  c.run("var factory={key:'tankFactory',owner:0,built:true,supplied:false,queue:['soldier'],queueProg:.2,def:{},mesh:new THREE.Group()}; updateBuilding(factory,1)");
  assert.equal(c.run('factory.queueProg'), .2); assert.equal(c.G.res.money, 1000);
  c.run('factory.supplied=true; updateBuilding(factory,1)');
  assert.ok(Math.abs(c.run('factory.queueProg') - .3) < 1e-9);
  c.run('factory.railSupplied=true; updateBuilding(factory,1)');
  assert.ok(Math.abs(c.run('factory.queueProg') - .425) < 1e-9);
  assert.equal(c.run('factory.queue.length'), 1);
});

test('conventional impact is confined to one hex including every junction branch', () => {
  const c = harness();
  c.run(`buildTransport([{q:0,r:0},{q:1,r:0},{q:2,r:0}],'rail');
    buildTransport([{q:1,r:0},{q:1,r:1}],'road');
    var impact=hexCenter({q:1,r:0}); damageTransportHex(impact.x,impact.z,1000);`);
  assert.equal(c.run(`(() => { for(const e of LOGISTICS.edges.values()) for(let i=0;i<2;i++) {
    const target=hexKey(i?e.b:e.a)==='1,0'; if(e.tileHp[i] !== (target ? 0 : e.maxHp))return false;
  } return true; })()`), true);
  assert.equal(c.run('transportQuote([{q:0,r:0},{q:1,r:0},{q:2,r:0}],"rail").money'), 12);
  c.run('buildTransport([{q:0,r:0},{q:1,r:0},{q:2,r:0}],"rail")');
  assert.equal(c.run('LOGISTICS.edges.values().next().value.hp'), 160);
});

test('nuclear radius can damage neighbouring hexes while leaving distant ones intact', () => {
  const c = harness();
  c.run(`buildTransport([{q:0,r:0},{q:1,r:0},{q:2,r:0},{q:3,r:0},{q:4,r:0}],'rail');
    var impact=hexCenter({q:1,r:0}); damageTransport(impact.x,impact.z,24,1000);`);
  assert.equal(c.run(`LOGISTICS.edges.get(transportKey({q:1,r:0},{q:2,r:0},0)).tileHp[1]`), 0);
  assert.equal(c.run(`LOGISTICS.edges.get(transportKey({q:3,r:0},{q:4,r:0},0)).hp`), 160);
});
