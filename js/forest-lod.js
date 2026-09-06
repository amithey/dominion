'use strict';

const FOREST_CELLS = [];

// Bake the actual textured tree once. Distant trees retain their silhouette
// and colours while costing two triangles instead of thousands of leaf faces.
function bakeTreeImpostor(parts) {
  const stage = new THREE.Scene();
  const tree = new THREE.Group();
  const materials = [];
  for (const part of parts) {
    const cloned = (Array.isArray(part.material) ? part.material : [part.material]).map(m => {
      const copy = m.clone(); materials.push(copy); return copy;
    });
    tree.add(new THREE.Mesh(part.geometry, Array.isArray(part.material) ? cloned : cloned[0]));
  }
  stage.add(tree);
  stage.add(new THREE.HemisphereLight(0xc7dbec, 0x636848, 1.1));
  const light = new THREE.DirectionalLight(0xfff1d5, 1.7);
  light.position.set(8, 15, 10); stage.add(light);
  const bounds = new THREE.Box3().setFromObject(tree);
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const span = Math.max(size.y, Math.hypot(size.x, size.z)) * 1.1;
  const cam = new THREE.OrthographicCamera(-span / 2, span / 2, span / 2, -span / 2, .01, span * 8);
  cam.position.copy(center).add(new THREE.Vector3(0, span * 1.7, span * 2.4));
  cam.lookAt(center);
  const target = new THREE.WebGLRenderTarget(256, 256, { generateMipmaps: true, minFilter: THREE.LinearMipmapLinearFilter });
  const previous = renderer.getRenderTarget();
  const clearColor = renderer.getClearColor(new THREE.Color());
  const clearAlpha = renderer.getClearAlpha();
  try {
    renderer.setRenderTarget(target);
    renderer.setClearColor(0x000000, 0);
    renderer.clear(); renderer.render(stage, cam);
  } finally {
    renderer.setRenderTarget(previous);
    renderer.setClearColor(clearColor, clearAlpha);
    materials.forEach(m => m.dispose());
  }
  const geometry = new THREE.PlaneGeometry(span, span);
  geometry.translate(center.x, center.y, center.z);
  const material = new THREE.MeshBasicMaterial({ map: target.texture, alphaTest: .25, side: THREE.DoubleSide });
  material.onBeforeCompile = shader => {
    shader.uniforms.treeCenter = { value: center };
    shader.vertexShader = shader.vertexShader.replace('#include <common>', '#include <common>\nuniform vec3 treeCenter;');
    shader.vertexShader = shader.vertexShader.replace('#include <project_vertex>', `
      vec4 mvPosition = viewMatrix * modelMatrix * instanceMatrix * vec4(treeCenter, 1.0);
      mvPosition.xy += (position.xy - treeCenter.xy) * vec2(length(instanceMatrix[0].xyz), length(instanceMatrix[1].xyz));
      gl_Position = projectionMatrix * mvPosition;
    `);
  };
  material.customProgramCacheKey = () => 'forest-impostor';
  return { geometry, material, target };
}

function updateForestLOD(cam) {
  const limit = G.graphics === 'cinematic' ? 230 : G.graphics === 'fast' ? 120 : 170;
  for (const cell of FOREST_CELLS) {
    const distance = cam.position.distanceTo(cell.bounds.center) - cell.bounds.radius;
    const detailed = distance < limit + (cell.detailed ? 12 : -12);
    if (detailed === cell.detailed) continue;
    cell.detailed = detailed;
    cell.parts.forEach(part => part.visible = detailed);
    cell.impostor.visible = !detailed;
    renderer.shadowMap.needsUpdate = true;
  }
}
