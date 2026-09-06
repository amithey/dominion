const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function navigation(buildings = []) {
  const context = vm.createContext({ console, Math, Uint8Array, Uint16Array, Int32Array, Float32Array });
  vm.runInContext(fs.readFileSync('js/config.js', 'utf8'), context);
  vm.runInContext('MAP_SIZE = 96; HALF_MAP = 48; const G = { buildings: [], time: 0, frame: 1 }; function terrainH() { return 2; }', context);
  context.buildings = buildings;
  vm.runInContext('G.buildings = buildings;', context);
  vm.runInContext(fs.readFileSync('js/path.js', 'utf8'), context);
  const entities = fs.readFileSync('js/entities.js', 'utf8');
  vm.runInContext(entities.slice(entities.indexOf('function canStandAt('), entities.indexOf('function updateUnit(')), context);
  return source => vm.runInContext(source, context);
}

test('initial navigation masks buildings and routes around their footprint', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }]);
  assert.equal(run('navRebuild(); NAV.land[navIndex(0, 0)]'), 0);
  assert.equal(run('navLOS(-30, 0, 30, 0, false)'), false);
  assert.ok(run('findPath(-30, 0, 30, 0, false).length') >= 2);
});

test('units can walk out of newly occupied ground but cannot enter from outside', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }]);
  assert.equal(run(`navRebuild(); const u = {x:2,z:2,def:{}};
    const escape = pathNext(u,30,0); const d = dist2d(u.x,u.z,escape.x,escape.z);
    canStandAt(u,u.x+(escape.x-u.x)/d*.4,u.z+(escape.z-u.z)/d*.4)`), true);
  assert.equal(run('canStandAt({x:-30,z:0,def:{}},0,0)'), false);
});

test('a moving unit follows the route around a building without cutting its corners', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }]);
  assert.ok(run(`navRebuild(); const u = {x:-30,z:0,def:{},state:'move',tx:30,tz:0};
    for(let i=0;i<400 && dist2d(u.x,u.z,u.tx,u.tz)>1;i++) {
      G.frame++; G.time+=.05;
      const p = pathNext(u,u.tx,u.tz) || {x:u.tx,z:u.tz};
      const d = dist2d(u.x,u.z,p.x,p.z); const step = Math.min(.4,d);
      if(d===0) continue;
      const x=u.x+(p.x-u.x)/d*step,z=u.z+(p.z-u.z)/d*step;
      if(canStandAt(u,x,z)) {u.x=x;u.z=z;}
    }
    dist2d(u.x,u.z,u.tx,u.tz)`) < 1.5);
});

test('demolishing an overlapping structure does not clear its neighbour', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }, { x: 4, z: 0, def: { size: 12 } }]);
  assert.equal(run('navRebuild(); navBlockBuilding(G.buildings[0], false); NAV.land[navIndex(4, 0)]'), 0);
  assert.equal(run('navBlockBuilding(G.buildings[1], false); NAV.land[navIndex(4, 0)]'), 1);
});

test('blocked goals terminate at a reachable cell, never inside the building', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }]);
  assert.equal(run('const path = findPath(-30, 0, 0, 0, false); const end = path.at(-1); NAV.land[navIndex(end.x, end.z)]'), 1);
  assert.equal(run('const unit = {x:-30,z:0,def:{},state:"move",tx:0,tz:0}; pathNext(unit,0,0); NAV.land[navIndex(unit.tx,unit.tz)]'), 1);
});

test('formation requests are bounded per frame and deferred units resume', () => {
  const run = navigation([{ x: 0, z: 0, def: { size: 12 } }]);
  assert.equal(run('const units = Array.from({length:8}, () => ({x:-30,z:0,def:{},state:"move",tx:30,tz:0})); for(const u of units) pathNext(u,30,0); NAV.requests'), 3);
  assert.equal(run('units.filter(u=>u.path).length'), 3);
  assert.equal(run('G.frame++; for(const u of units) pathNext(u,30,0); units.filter(u=>u.path).length'), 6);
  assert.equal(run('G.frame++; for(const u of units) pathNext(u,30,0); units.filter(u=>u.path).length'), 8);
});
