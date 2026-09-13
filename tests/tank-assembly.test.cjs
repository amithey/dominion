const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('all four authored tanks keep their gun above the hull after placement', async () => {
  const THREE = await import('three');
  const SkeletonUtils = await import('three/addons/utils/SkeletonUtils.js');
  const { FBXLoader } = await import('three/addons/loaders/FBXLoader.js');
  // Geometry test: embedded images are decoded by the browser, not Node.
  global.window = { URL };
  const manager = new THREE.LoadingManager();
  manager.addHandler(/.*/, { load: () => new THREE.Texture(), setPath() {} });
  try {
    for (let i = 0; i < 4; i++) {
      const bytes = fs.readFileSync(`assets/models/quaternius-tanks/Tank${i ? i + 1 : ''}.fbx`);
      const source = new FBXLoader(manager).parse(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
      const context = vm.createContext({ THREE: { ...THREE, SkeletonUtils }, source, i });
      vm.runInContext(fs.readFileSync('js/models.js', 'utf8'), context);
      const tank = vm.runInContext("MODELS.loaded.set('unit:tank' + i, {scene:source}); makeTankModel(0x557799, i)", context);
      tank.position.set(35, 2, -60);
      tank.rotation.y = .8;
      tank.updateMatrixWorld(true);
      const hull = tank.getObjectByName('Tank_body') || tank.getObjectByName('Tank_body001');
      hull.skeleton.update(); hull.computeBoundingBox();
      const hullBox = new THREE.Box3().setFromObject(hull);
      const barrel = new THREE.Box3().setFromObject(tank.getObjectByName('Tank_Gun'));
      assert.ok(barrel.getCenter(new THREE.Vector3()).y > hullBox.max.y, `variant ${i}: barrel must clear hull roof`);
      assert.ok(new THREE.Box3().setFromObject(tank).getSize(new THREE.Vector3()).length() < 8, `variant ${i}: assembled scale`);
      assert.ok(tank.userData.vehicleMixer, `variant ${i}: authored track animation available`);
      const track = hull.skeleton.bones.find(b => b.name.startsWith('TankTrack'));
      const start = track.getWorldPosition(new THREE.Vector3());
      const orientation = track.getWorldQuaternion(new THREE.Quaternion());
      const belts = [];
      tank.traverse(mesh => { if (mesh.isSkinnedMesh && mesh.name.startsWith('TrackMesh'))
        belts.push(mesh.skeleton.bones.map(b => ({ bone: b, position: b.getWorldPosition(new THREE.Vector3()), rotation: b.getWorldQuaternion(new THREE.Quaternion()) })));
      });
      tank.userData.vehicleMixer.update(.17);
      tank.updateMatrixWorld(true);
      assert.ok(track.getWorldPosition(new THREE.Vector3()).distanceTo(start) > .001 || track.getWorldQuaternion(new THREE.Quaternion()).angleTo(orientation) > .001, `variant ${i}: track moves`);
      assert.equal(belts.length, 2);
      for (const bones of belts) assert.ok(bones.some(({bone,position,rotation}) => bone.getWorldPosition(new THREE.Vector3()).distanceTo(position) > .001 || bone.getWorldQuaternion(new THREE.Quaternion()).angleTo(rotation) > .001), `variant ${i}: both belts must animate despite duplicate FBX bone names`);
      const turretPosition = tank.userData.turret.position.clone();
      tank.userData.vehicleMixer.update(.13);
      assert.ok(turretPosition.equals(tank.userData.turret.position), `variant ${i}: animation leaves turret placement intact`);
    }
  } finally { delete global.window; }
});
