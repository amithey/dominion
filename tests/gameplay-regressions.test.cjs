const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const THREE = require('three');
const entities = fs.readFileSync('js/entities.js', 'utf8');

function loadFunction(context, name, nextName) {
  vm.runInContext(entities.slice(entities.indexOf(`function ${name}(`), entities.indexOf(`function ${nextName}(`)), context);
}

test('fast aircraft arrive instead of oscillating across a nearby destination at 3x speed', () => {
  const G = { time: 0, frame: 0, units: [] };
  const context = vm.createContext({
    G, THREE, HALF_MAP: 100, terrainH: () => 2,
    clamp: (x, a, b) => Math.max(a, Math.min(b, x)),
    dist2d: (x, z, a, b) => Math.hypot(x - a, z - b),
    pathNext: () => null, canStandAt: () => true,
    unitTechSpeedMult: () => 1, updateHpBar() {},
  });
  loadFunction(context, 'turnToward', 'reloadMult');
  loadFunction(context, 'updateUnit', 'updateBuilding');
  const unit = { id: 1, key: 'drone', def: { speed: 24, fly: 16, dmg: 0 },
    x: 0, z: 0, tx: 1.8, tz: 0, state: 'move', cool: 0, retarget: 1, mesh: new THREE.Group() };
  context.unit = unit; G.units.push(unit);
  for (let i = 0; i < 20; i++) {
    G.time += .15; G.frame++;
    vm.runInContext('updateUnit(unit, .15)', context);
  }
  assert.equal(unit.state, 'idle');
  assert.ok(Math.hypot(unit.x - unit.tx, unit.z - unit.tz) < 1.5);
});

test('death hides both meshes of a selected unit health bar', () => {
  const G = { effects: [], selection: [], discovered: {} };
  const context = vm.createContext({ G, spawnExplosion() {} });
  loadFunction(context, 'killEntity', 'spawnTracer');
  const unit = { type: 'unit', def: {}, mesh: new THREE.Group(),
    ring: { visible: true }, hpBg: { visible: true }, hpFg: { visible: true } };
  context.unit = unit; G.selection.push(unit);
  vm.runInContext('killEntity(unit)', context);
  assert.equal(G.effects.length, 1);
  assert.equal(unit.hpBg.visible, false);
  assert.equal(unit.hpFg.visible, false);
});

test('vehicle suspension follows the slope in local axes and settles consistently across frame rates', () => {
  function pose(yaw, dt) {
    const G = { time: 0, frame: 1, units: [] };
    const context = vm.createContext({ G, THREE, HALF_MAP: 100,
      terrainH: x => x * .1, updateHpBar() {},
      clamp: (x, a, b) => Math.max(a, Math.min(b, x)),
    });
    loadFunction(context, 'turnToward', 'reloadMult');
    loadFunction(context, 'updateUnit', 'updateBuilding');
    const unit = { id: 1, key: 'testVehicle', def: { speed: 5, fly: 0, dmg: 0 },
      x: 0, z: 0, state: 'idle', cool: 0, retarget: 10, mesh: new THREE.Group() };
    unit.mesh.rotation.y = yaw; context.unit = unit;
    for (let t = 0; t < 60; t++) vm.runInContext(`updateUnit(unit, ${dt})`, context);
    return unit.mesh.rotation;
  }
  const north = pose(0, 1 / 60), east = pose(Math.PI / 2, 1 / 60);
  assert.ok(north.z > .09 && Math.abs(north.x) < .001);
  assert.ok(east.x < -.09 && Math.abs(east.z) < .001);
  const slow = pose(0, 1 / 30);
  assert.ok(Math.abs(slow.z - north.z) < .001);
});

test('Fast display option actually switches distant forest to its cheaper level', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  const graphics = html.match(/<option value="([^"]+)">Fast<\/option>/)[1];
  const context = vm.createContext({ THREE, G: { graphics }, renderer: { shadowMap: {} } });
  vm.runInContext(fs.readFileSync('js/forest-lod.js', 'utf8'), context);
  const cell = { bounds: new THREE.Sphere(new THREE.Vector3(), 0), detailed: true,
    parts: [{ visible: true }], impostor: { visible: false } };
  context.cell = cell;
  vm.runInContext('FOREST_CELLS.push(cell); updateForestLOD({position:new THREE.Vector3(150,0,0)})', context);
  assert.equal(cell.parts[0].visible, false);
  assert.equal(cell.impostor.visible, true);
});

test('blocked skeletal units stay idle and blend into running only after moving', () => {
  const G = { time: 0, frame: 1, units: [] };
  const context = vm.createContext({ G, THREE, HALF_MAP: 100, WORK_STATES: new Set(), terrainH: () => 2,
    clamp: (x,a,b) => Math.max(a,Math.min(b,x)), dist2d: (x,z,a,b) => Math.hypot(x-a,z-b),
    pathNext: () => null, canStandAt: () => false, unitTechSpeedMult: () => 1,
    updateHpBar() {}, animationDue: () => true,
  });
  loadFunction(context, 'turnToward', 'reloadMult'); loadFunction(context, 'updateUnit', 'updateBuilding');
  const root = new THREE.Group(), mixer = new THREE.AnimationMixer(root), actions = {};
  for (const name of ['idle','walk','run']) {
    const action = mixer.clipAction(new THREE.AnimationClip(name, 1, []));
    action.setEffectiveWeight(name === 'idle' ? 1 : 0); action.play(); actions[name] = action;
  }
  root.userData.mixer = mixer; root.userData.actions = actions;
  const unit = { id: 1, key: 'soldier', def: { speed: 5.5, fly: 0, dmg: 0 }, x: 0, z: 0, tx: 40, tz: 0,
    state: 'move', retarget: 10, cool: 0, mesh: root };
  context.unit = unit;
  vm.runInContext('updateUnit(unit,.1)', context);
  assert.equal(actions.run.getEffectiveWeight(), 0); assert.equal(actions.idle.getEffectiveWeight(), 1);
  context.canStandAt = () => true;
  vm.runInContext('updateUnit(unit,.1)', context);
  assert.ok(actions.run.getEffectiveWeight() > .5);
  assert.ok(actions.run.getEffectiveTimeScale() > 1);
});
