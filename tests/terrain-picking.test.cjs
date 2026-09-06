const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('heightfield picking matches Three.js triangle raycasting across slopes, edges and misses', async () => {
  const THREE = await import('three');
  const context = vm.createContext({ THREE, Math });
  vm.runInContext(fs.readFileSync('js/terrain-picking.js', 'utf8'), context);
  const geometry = new THREE.PlaneGeometry(96, 96, 48, 48);
  geometry.rotateX(-Math.PI / 2);
  const pos = geometry.attributes.position;
  for (let i = 0; i < pos.count; i++) pos.setY(i, Math.sin(pos.getX(i) / 8) * 4 + Math.cos(pos.getZ(i) / 13) * 6);
  geometry.computeVertexNormals();
  const reference = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
  const optimized = new THREE.Mesh(geometry, reference.material);
  context.mesh = optimized;
  vm.runInContext('installTerrainPicking(mesh, 96, 48)', context);
  let seed = 721;
  const random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  for (let i = 0; i < 400; i++) {
    const origin = new THREE.Vector3((random() - .5) * 140, 15 + random() * 80, (random() - .5) * 140);
    const aim = new THREE.Vector3((random() - .5) * 140, -20, (random() - .5) * 140);
    const raycaster = new THREE.Raycaster(origin, aim.sub(origin).normalize());
    const expected = raycaster.intersectObject(reference);
    const actual = raycaster.intersectObject(optimized);
    assert.equal(actual.length > 0, expected.length > 0, `hit mismatch at ray ${i}`);
    if (expected.length) assert.ok(actual[0].point.distanceTo(expected[0].point) < 1e-5, `intersection mismatch at ray ${i}`);
  }
  for (const x of [-48, 0, 48]) {
    const raycaster = new THREE.Raycaster(new THREE.Vector3(x, 50, 0), new THREE.Vector3(0, -1, 0));
    assert.ok(raycaster.intersectObject(optimized)[0].point.distanceTo(raycaster.intersectObject(reference)[0].point) < 1e-5);
  }
});
