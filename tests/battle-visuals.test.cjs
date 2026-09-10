const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const THREE = require('three');

function context() {
  const c = vm.createContext({ THREE, scene: new THREE.Scene(), renderer: { domElement: { height: 900 } },
    MISSILES: { cruise: { arc: false }, ballistic: { arc: true } }, SEA_LEVEL: 0,
    terrainH: x => x * .1, lerp: (a, b, f) => a + (b - a) * f });
  vm.runInContext(fs.readFileSync('js/battle-visuals.js', 'utf8'), c);
  return c;
}

test('heavy combat reuses one bounded particle buffer and expires every particle', () => {
  const c = context();
  vm.runInContext('for(let i=0;i<100;i++) emitBlast(0,2,0,14); updateBattleVisuals(.016)', c);
  assert.equal(c.scene.children.length, 1);
  assert.equal(vm.runInContext('BATTLE_FX.particles.length', c), 1200);
  vm.runInContext('updateBattleVisuals(4)', c);
  const attrs = c.scene.children[0].geometry.attributes;
  for (const a of Object.values(attrs)) assert.ok(a.array.every(Number.isFinite));
  assert.ok(attrs.alpha.array.every(a => a === 0));
});

test('missile noses follow ascent and descent and meet elevated target terrain', () => {
  for (const type of ['ballistic', 'cruise']) {
    const c = context();
    c.m = { type, sx: 0, sz: 0, tx: 100, tz: 20, mesh: new THREE.Group() };
    const nose = type === 'ballistic' ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0);
    for (const f of [.2, .7, .95]) {
      vm.runInContext(`poseMissile(m, ${f - .0001})`, c);
      const before = c.m.mesh.position.clone();
      vm.runInContext(`poseMissile(m, ${f + .0001})`, c);
      const tangent = c.m.mesh.position.clone().sub(before).normalize();
      vm.runInContext(`poseMissile(m, ${f})`, c);
      assert.ok(nose.clone().applyQuaternion(c.m.mesh.quaternion).dot(tangent) > .999);
    }
    vm.runInContext('poseMissile(m, 1)', c);
    assert.ok(Math.abs(c.m.mesh.position.y - 10.3) < 1e-6);
  }
});

test('zero-distance missile keeps a finite orientation', () => {
  const c = context();
  c.m = { type: 'cruise', sx: 0, sz: 0, tx: 0, tz: 0, mesh: new THREE.Group() };
  vm.runInContext('poseMissile(m, 0); poseMissile(m, 1)', c);
  assert.ok(c.m.mesh.quaternion.toArray().every(Number.isFinite));
});
