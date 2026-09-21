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
