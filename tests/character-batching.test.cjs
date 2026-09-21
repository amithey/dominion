const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
test('character batching folds skinned and bone-mounted parts into one mesh that still follows the bones',async()=>{
  const THREE=await import('three');const {mergeGeometries}=await import('three/addons/utils/BufferGeometryUtils.js');
  const c=vm.createContext({THREE:{...THREE,mergeGeometries}});vm.runInContext(fs.readFileSync('js/models.js','utf8'),c);
  const root=new THREE.Group(),hips=new THREE.Bone(),hand=new THREE.Bone();
  hand.position.set(0,1,0);hips.add(hand);root.add(hips);root.updateMatrixWorld(true);
  const skeleton=new THREE.Skeleton([hips,hand]);
  const bodyGeo=new THREE.BoxGeometry(1,1,1),n=bodyGeo.attributes.position.count;
  bodyGeo.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(new Array(n*4).fill(0),4));
  bodyGeo.setAttribute('skinWeight',new THREE.Float32BufferAttribute(Array.from({length:n*4},(_,i)=>i%4?0:1),4));
  const body=new THREE.SkinnedMesh(bodyGeo,new THREE.MeshStandardMaterial({color:0x335522}));
  root.add(body);body.bind(skeleton);
  const weapon=new THREE.Mesh(new THREE.BoxGeometry(.2,.2,1),new THREE.MeshStandardMaterial({color:0x222222}));
  weapon.position.set(.3,0,.4);hand.add(weapon);
  const hidden=new THREE.Mesh(new THREE.BoxGeometry(1,1,1),weapon.material);hidden.visible=false;hand.add(hidden);
  root.updateMatrixWorld(true);
  const tip=weapon.localToWorld(new THREE.Vector3(.1,.1,.5)),tipInHand=hand.worldToLocal(tip.clone());

  c.consolidateCharacter(root,'test');
  const meshes=[];root.traverse(o=>{if(o.isMesh)meshes.push(o);});
  assert.equal(meshes.length,1);assert.ok(meshes[0].isSkinnedMesh);
  const merged=meshes[0];assert.equal(merged.geometry.attributes.position.count,n+weapon.geometry.attributes.position.count);

  // Swing the hand: the merged weapon vertices must move with it, not stay put.
  hand.rotation.z=1.1;root.updateMatrixWorld(true);skeleton.update();
  const expected=hand.localToWorld(tipInHand.clone());
  let best=Infinity;const v=new THREE.Vector3();
  for(let i=0;i<merged.geometry.attributes.position.count;i++){
    merged.getVertexPosition(i,v);merged.localToWorld(v);best=Math.min(best,v.distanceTo(expected));
  }
  assert.ok(best<1e-4,`weapon tip drifted ${best}`);
});
