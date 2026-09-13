const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
test('service models keep bounded geometry and functional animated fittings after batching',async()=>{
  const THREE=await import('three');
  const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const c=vm.createContext({THREE:{...THREE,mergeGeometries}});
  vm.runInContext(fs.readFileSync('js/models.js','utf8'),c);
  const src=fs.readFileSync('js/entities.js','utf8');
  vm.runInContext(src.slice(src.indexOf('const MAT_ANTIFOUL'),src.indexOf('const WINDOW_MAT')),c);
  vm.runInContext(fs.readFileSync('js/vehicle-art.js','utf8'),c);
  for(const key of ['jet','bomber','submarine','nuclearSub','destroyer','corvette','gunboat']) {
    const model=c.makeServiceVehicle(key,0x526853);
    const size=new THREE.Box3().setFromObject(model).getSize(new THREE.Vector3());
    assert.ok(size.x>4&&size.x<12&&size.z<12,key);
    let meshCount=0;
    model.traverse(o=>{if(o.isMesh){meshCount++;assert.ok(o.geometry.attributes.position.array.every(Number.isFinite),key);}});
    assert.ok(meshCount<24,`${key}: batch static detail (${meshCount})`);
    for(const name of ['prop','spin','turret']) if(model.userData[name]) assert.ok(model.userData[name].parent,`${key}: ${name} retained`);
  }
});
