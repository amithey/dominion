'use strict';

/* Completed buildings draw through one BatchedMesh per material instead of
   ~25 meshes each, so a growing city stops adding draw calls per building.
   batchBuildingGeometry() already moved most surfaces onto shared materials;
   here the static parts of every finished building join the batch for their
   material and the originals are hidden. They stay in the building's group,
   so picking (raycasts ignore visibility), selection and destruction work as
   before. Animated parts, glass, windows and overlays are never batched.
   Buildings under construction are left alone until they finish. */
// ?nobuildbatch draws every building separately, for A/B performance checks.
const BUILDING_BATCH = {
  batches: new Map(), members: new Map(),
  enabled: typeof location === 'undefined' || !new URLSearchParams(location.search).has('nobuildbatch'),
};

function staticBuildingParts(b) {
  const animated = new Set([b.districtRing].filter(Boolean));
  b.mesh.traverse(node => {
    for (const [name, v] of Object.entries(node.userData)) {
      if (name === 'core' || name === 'entity') continue;
      const found = v?.isObject3D ? [v] : Array.isArray(v) ? v.filter(o => o?.isObject3D)
        : v && typeof v === 'object' ? Object.values(v).filter(o => o?.isObject3D) : [];
      for (const o of found) animated.add(o);
    }
  });
  const parts = [];
  b.mesh.traverse(o => {
    if (!o.isMesh || o.isSkinnedMesh || o.isInstancedMesh || o.isBatchedMesh || Array.isArray(o.material) ||
        o.material.transparent || o.children.length || !o.geometry.attributes.position) return;
    for (let p = o; p && p !== b.mesh; p = p.parent) if (animated.has(p) || !p.visible) return;
    parts.push(o);
  });
  return parts;
}

// BatchedMesh needs identical attribute layouts, so every geometry is
// normalised to indexed Float32 attributes before it joins a batch.
function batchAttributeSignature(geometry) {
  return Object.keys(geometry.attributes).sort()
    .map(name => `${name}${geometry.attributes[name].itemSize}`).join(',');
}
function normalisedBatchGeometry(source) {
  const geometry = new THREE.BufferGeometry();
  for (const [name, attribute] of Object.entries(source.attributes)) {
    const size = attribute.itemSize, array = new Float32Array(attribute.count * size);
    for (let i = 0; i < attribute.count; i++) for (let k = 0; k < size; k++) array[i * size + k] = attribute.getComponent(i, k);
    geometry.setAttribute(name, new THREE.BufferAttribute(array, size));
  }
  const count = geometry.attributes.position.count;
  geometry.setIndex(source.index ? Array.from(source.index.array) : [...Array(count).keys()]);
  return geometry;
}

function buildingBatchFor(part, vertices) {
  const key = `${part.material.uuid}:${part.castShadow}:${part.receiveShadow}:${batchAttributeSignature(part.geometry)}`;
  let batch = BUILDING_BATCH.batches.get(key);
  if (!batch) {
    const size = Math.max(16384, vertices * 4);
    const mesh = new THREE.BatchedMesh(64, size, size * 2, part.material);
    mesh.castShadow = part.castShadow; mesh.receiveShadow = part.receiveShadow;
    mesh.frustumCulled = false; // spans the map; instances are culled individually
    mesh.name = 'building-batch';
    batch = { mesh, geometries: new Map() };
    BUILDING_BATCH.batches.set(key, batch);
  }
  if (batch.mesh.parent !== scene) scene.add(batch.mesh);
  return batch;
}

function reserveBatchSpace(batch, vertices, indices) {
  const m = batch.mesh;
  if (!m.geometry.index) return; // still empty: sized for its first geometry on creation
  if (m.unusedVertexCount < vertices || m.unusedIndexCount < indices) m.optimize();
  if (m.unusedVertexCount < vertices || m.unusedIndexCount < indices) {
    const usedV = m.geometry.attributes.position.count - m.unusedVertexCount;
    const usedI = m.geometry.index.count - m.unusedIndexCount;
    m.setGeometrySize(Math.max(usedV * 2, usedV + vertices * 2), Math.max(usedI * 2, usedI + indices * 2));
  }
  if (m.instanceCount >= m.maxInstanceCount) m.setInstanceCount(m.maxInstanceCount * 2);
}

function addBuildingToBatches(b) {
  b.mesh.updateMatrixWorld(true);
  const entries = [];
  for (const part of staticBuildingParts(b)) {
    const batch = buildingBatchFor(part, part.geometry.attributes.position.count);
    let shared = batch.geometries.get(part.geometry.uuid);
    if (!shared) {
      const geometry = normalisedBatchGeometry(part.geometry);
      reserveBatchSpace(batch, geometry.attributes.position.count, geometry.index.count);
      shared = { id: batch.mesh.addGeometry(geometry), refs: 0 };
      geometry.dispose();
      batch.geometries.set(part.geometry.uuid, shared);
    }
    reserveBatchSpace(batch, 0, 0);
    const instance = batch.mesh.addInstance(shared.id);
    batch.mesh.setMatrixAt(instance, part.matrixWorld);
    shared.refs++;
    part.visible = false;
    entries.push({ batch, geometryUuid: part.geometry.uuid, instance, part });
  }
  BUILDING_BATCH.members.set(b, entries);
}

function removeBuildingFromBatches(b) {
  for (const { batch, geometryUuid, instance, part } of BUILDING_BATCH.members.get(b) || []) {
    batch.mesh.deleteInstance(instance);
    const shared = batch.geometries.get(geometryUuid);
    if (shared && --shared.refs === 0) {
      batch.mesh.deleteGeometry(shared.id);
      batch.geometries.delete(geometryUuid);
    }
    part.visible = true;
  }
  BUILDING_BATCH.members.delete(b);
}

// Runs every frame before rendering, so a destroyed building disappears from
// its batches in the same frame it is removed from the scene.
function updateBuildingBatches() {
  if (!THREE.BatchedMesh || !BUILDING_BATCH.enabled) return;
  for (const b of BUILDING_BATCH.members.keys()) if (b.dead || !b.built) removeBuildingFromBatches(b);
  for (const b of G.buildings) if (b.built && !b.dead && !BUILDING_BATCH.members.has(b)) addBuildingToBatches(b);
}
