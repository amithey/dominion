'use strict';

// Exact grid traversal for the regular terrain heightfield. Picking visits
// intersected cells rather than testing every triangle in a large map.
function installTerrainPicking(mesh, mapSize, segments) {
  const inverse = new THREE.Matrix4();
  const ray = new THREE.Ray();
  const start = new THREE.Vector3(), hit = new THREE.Vector3();
  const a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3();
  const worldHit = new THREE.Vector3();
  mesh.geometry.computeBoundingBox();
  mesh.raycast = function(raycaster, intersects) {
    inverse.copy(this.matrixWorld).invert();
    ray.copy(raycaster.ray).applyMatrix4(inverse);
    if (!ray.intersectBox(this.geometry.boundingBox, start)) return;
    if (this.geometry.boundingBox.containsPoint(ray.origin)) start.copy(ray.origin);
    const half = mapSize / 2, cell = mapSize / segments;
    const dx = ray.direction.x, dz = ray.direction.z;
    const stepX = Math.sign(dx), stepZ = Math.sign(dz);
    let x = Math.max(0, Math.min(segments - 1, Math.floor((start.x + half + dx * 1e-6) / cell)));
    let z = Math.max(0, Math.min(segments - 1, Math.floor((start.z + half + dz * 1e-6) / cell)));
    const originT = start.clone().sub(ray.origin).dot(ray.direction);
    let nextX = stepX ? originT + ((x + (stepX > 0 ? 1 : 0)) * cell - half - start.x) / dx : Infinity;
    let nextZ = stepZ ? originT + ((z + (stepZ > 0 ? 1 : 0)) * cell - half - start.z) / dz : Infinity;
    const deltaX = stepX ? cell / Math.abs(dx) : Infinity;
    const deltaZ = stepZ ? cell / Math.abs(dz) : Infinity;
    const positions = this.geometry.attributes.position;
    const indices = this.geometry.index.array;
    for (let visited = 0; visited <= segments * 2 + 2; visited++) {
      const offset = (z * segments + x) * 6;
      let closest = Infinity, faceIndex = -1;
      for (let triangle = 0; triangle < 2; triangle++) {
        const i = offset + triangle * 3;
        a.fromBufferAttribute(positions, indices[i]);
        b.fromBufferAttribute(positions, indices[i + 1]);
        c.fromBufferAttribute(positions, indices[i + 2]);
        if (ray.intersectTriangle(a, b, c, this.material.side !== THREE.DoubleSide, hit)) {
          worldHit.copy(hit).applyMatrix4(this.matrixWorld);
          const distance = raycaster.ray.origin.distanceTo(worldHit);
          if (distance >= raycaster.near && distance <= raycaster.far && distance < closest) {
            closest = distance; faceIndex = i / 3;
          }
        }
      }
      if (faceIndex >= 0) {
        intersects.push({ distance: closest, point: raycaster.ray.at(closest, new THREE.Vector3()), object: this, faceIndex });
        return;
      }
      if (nextX === Infinity && nextZ === Infinity) return;
      if (nextX < nextZ) { x += stepX; nextX += deltaX; }
      else { z += stepZ; nextZ += deltaZ; }
      if (x < 0 || z < 0 || x >= segments || z >= segments) return;
    }
  };
}
