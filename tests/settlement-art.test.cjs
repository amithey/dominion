const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const THREE = require('three');

test('the complete building footprint fits all six hex edges, including offset annexes',()=>{
  const c=vm.createContext({THREE});vm.runInContext(fs.readFileSync('js/settlement-art.js','utf8'),c);
  for(const angle of [0,.4,1.2]) {
    const root=new THREE.Group();
    const annex=new THREE.Mesh(new THREE.BoxGeometry(28,8,18));annex.position.x=7;annex.rotation.y=angle;root.add(annex);
    c.fitBuildingToHex(root);root.updateMatrixWorld(true);
    const pos=annex.geometry.attributes.position;
    for(let i=0;i<pos.count;i++) {
      const p=new THREE.Vector3().fromBufferAttribute(pos,i).applyMatrix4(annex.matrixWorld);
      for(let j=0;j<6;j++) assert.ok(p.x*Math.cos(j*Math.PI/3)+p.z*Math.sin(j*Math.PI/3)<=12*Math.sqrt(3)/2-.54);
    }
  }
});

test('neighbourhood art preserves the authored architecture material factory', () => {
  const context = vm.createContext({ THREE });
  vm.runInContext(fs.readFileSync('js/models.js', 'utf8'), context);
  const original = context.architectureMaterials;
  vm.runInContext(fs.readFileSync('js/settlement-art.js', 'utf8'), context);
  assert.equal(context.architectureMaterials, original);
  assert.equal(typeof context.neighborhoodPalette, 'function');
});

test('districts retain their landmark and activity, with distinct urban and industrial silhouettes', () => {
  const context = vm.createContext({ THREE, BUILDINGS: {
    apartments: { size: 8 }, tankFactory: { size: 8 }, hospital: { size: 8 },
  }, document: { createElement: () => ({ getContext: () => ({ fillRect() {} }) }) } });
  vm.runInContext(fs.readFileSync('js/settlement-art.js', 'utf8'), context);
  for (const key of ['apartments', 'tankFactory', 'hospital']) {
    const core = new THREE.Group(); core.add(new THREE.Mesh(new THREE.BoxGeometry(6, 4, 6), new THREE.MeshStandardMaterial()));
    const district = context.settlementCluster(core, key, 0x778899, 2);
    assert.equal(district.userData.core, core);
    assert.ok(district.userData.districtActivity.userData.flag.geometry.attributes.position.count > 4);
    assert.ok(new THREE.Box3().setFromObject(district).getSize(new THREE.Vector3()).x < 24);
  }
  assert.equal(context.districtStyle('apartments'), 'urban');
  assert.equal(context.districtStyle('tankFactory'), 'industrial');
  assert.equal(context.districtStyle('hospital'), 'civic');
});

test('district service traffic stops without supply but wind animation continues', () => {
  const G = { time: 1 }, context = vm.createContext({ THREE, G, battleParticle() {} });
  const src = fs.readFileSync('js/battle-visuals.js', 'utf8');
  vm.runInContext(src.slice(src.indexOf('function animateBuildingSite('), src.indexOf('const MISSILE_NOSE_X')), context);
  const mesh = new THREE.Group(), activity = new THREE.Group();
  activity.userData.flag = new THREE.Mesh(new THREE.PlaneGeometry(.65, .36, 5, 1));
  activity.userData.traffic = new THREE.Group(); activity.userData.radius = 3;
  mesh.userData.districtActivity = activity;
  const b = { id: 1, built: true, mesh };
  context.animateBuildingSite(b, .5);
  const before = activity.userData.traffic.position.clone();
  b.supplied = false; G.time = 2; context.animateBuildingSite(b, .5);
  assert.ok(before.equals(activity.userData.traffic.position));
  assert.ok(activity.userData.flag.geometry.attributes.position.array.every(Number.isFinite));
  b.supplied = true; context.animateBuildingSite(b, .5);
  assert.ok(!before.equals(activity.userData.traffic.position));
});
