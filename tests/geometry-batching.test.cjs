const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
test('vehicle batching reduces static meshes while preserving wheels, limbs and bone-mounted equipment',async()=>{
  const THREE=await import('three');const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const c=vm.createContext({THREE:{...THREE,mergeGeometries}});vm.runInContext(fs.readFileSync('js/models.js','utf8'),c);
  const root=new THREE.Group(),mat=new THREE.MeshStandardMaterial();
  const piece=()=>new THREE.Mesh(new THREE.BoxGeometry(1,1,1),mat);
  for(let i=0;i<20;i++){const m=piece();m.position.x=i*.1;root.add(m);}
  const wheel=piece(),limb=new THREE.Group(),bone=new THREE.Bone(),weapon=piece();
  root.add(wheel,limb,bone);limb.add(piece());bone.add(weapon);
  root.userData.rollingParts=[wheel];root.userData.limbs={arm:limb};
  const before=new THREE.Box3().setFromObject(root);
  c.batchBuildingGeometry(root);
  assert.equal(wheel.parent,root);assert.equal(weapon.parent,bone);assert.equal(limb.children.length,1);
  const meshes=[];root.traverse(o=>{if(o.isMesh)meshes.push(o);});assert.equal(meshes.length,4);
  const after=new THREE.Box3().setFromObject(root);assert.ok(before.min.distanceTo(after.min)<1e-5&&before.max.distanceTo(after.max)<1e-5);
});
test('colour-only material differences merge through vertex colours, and a district core is not treated as animated',async()=>{
  const THREE=await import('three');const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const c=vm.createContext({THREE:{...THREE,mergeGeometries}});vm.runInContext(fs.readFileSync('js/models.js','utf8'),c);
  const root=new THREE.Group(),core=new THREE.Group();root.add(core);root.userData.core=core;
  const red=new THREE.MeshStandardMaterial({color:0xff0000,roughness:.94}),blue=new THREE.MeshStandardMaterial({color:0x0000ff,roughness:.95});
  const glass=new THREE.MeshPhysicalMaterial({color:0x88aaff,transmission:.5});
  const a=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),red),b=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),blue);b.position.x=3;
  const inCore=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),red);inCore.position.z=3;core.add(inCore);
  const radar=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),red);core.add(radar);core.userData.spin=radar;
  const pane=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),glass),pane2=pane.clone();
  root.add(a,b,pane,pane2);
  c.batchBuildingGeometry(root);
  const meshes=[];root.traverse(o=>{if(o.isMesh)meshes.push(o);});
  assert.equal(radar.parent,core,'animated radar stays in the core');
  assert.equal(inCore.parent,null,'static core parts join the district batch');
  const batch=meshes.find(m=>m.material.name==='batched-colors');
  assert.ok(batch&&batch.material.vertexColors);
  const colors=batch.geometry.attributes.color;const seen=new Set();
  for(let i=0;i<colors.count;i++)seen.add(`${colors.getX(i).toFixed(2)},${colors.getZ(i).toFixed(2)}`);
  assert.ok(seen.has('1.00,0.00')&&seen.has('0.00,1.00'),'both colours survive in the vertices');
  assert.equal(meshes.length,3,'one colour batch, the radar, and one merged glass mesh');
});
