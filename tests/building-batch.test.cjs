const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
test('finished buildings share one batch per material, keep animated parts, and leave the batch when destroyed',async()=>{
  const THREE=await import('three');
  const scene=new THREE.Scene(),G={buildings:[]};
  const c=vm.createContext({THREE,G,scene});vm.runInContext(fs.readFileSync('js/building-batch.js','utf8')+';this.BUILDING_BATCH=BUILDING_BATCH;',c);
  const wall=new THREE.MeshStandardMaterial({color:0xcccccc}),roof=new THREE.MeshStandardMaterial({color:0x884422});
  const box=new THREE.BoxGeometry(1,1,1); // shared geometry: stored once per batch
  const makeBuilding=(x,built)=>{
    const mesh=new THREE.Group();mesh.position.set(x,0,0);
    const body=new THREE.Mesh(box,wall),top=new THREE.Mesh(new THREE.ConeGeometry(1,1,4),roof);top.position.y=1;
    const radar=new THREE.Mesh(box,wall);mesh.userData.spin=radar;
    mesh.add(body,top,radar);scene.add(mesh);
    const b={mesh,built,dead:false,body,top,radar};G.buildings.push(b);return b;
  };
  const a=makeBuilding(0,true),b=makeBuilding(20,true),site=makeBuilding(40,false);
  c.updateBuildingBatches();
  const batches=[...c.BUILDING_BATCH.batches.values()];
  assert.equal(batches.length,2,'one batch per material, not per building');
  const walls=batches.find(x=>x.mesh.material===wall);
  assert.equal(walls.mesh.instanceCount,2);assert.equal(walls.geometries.size,1);
  assert.equal(a.body.visible,false);assert.equal(a.radar.visible,true,'animated radar is not batched');
  assert.equal(site.body.visible,true,'construction sites stay unbatched');
  const m=new THREE.Matrix4();walls.mesh.getMatrixAt(c.BUILDING_BATCH.members.get(b)[0].instance,m);
  assert.equal(new THREE.Vector3().setFromMatrixPosition(m).x,20,'instance sits where the building stands');

  b.dead=true;site.built=true;c.updateBuildingBatches();
  assert.equal(walls.mesh.instanceCount,2,'destroyed building left, finished site joined');
  assert.equal(c.BUILDING_BATCH.members.has(b),false);assert.equal(site.body.visible,false);
});
