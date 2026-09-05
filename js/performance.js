'use strict';

// Frame statistics include every pass, including water reflections and shadows.
const FRAME_STATS = { elapsed: 0, frames: 0, samples: [], cpu: 0, calls: 0, triangles: 0 };
function recordFrameStats(seconds, cpuMs) {
  const s = FRAME_STATS;
  if (document.hidden || seconds > 1) return;
  s.elapsed += seconds; s.frames++; s.samples.push(seconds * 1000);
  s.cpu += cpuMs; s.calls += renderer.info.render.calls;
  s.triangles += renderer.info.render.triangles;
  if (s.elapsed < 2) return;
  const sorted = s.samples.sort((a, b) => a - b);
  const report = {
    fps: Math.round(s.frames / s.elapsed),
    p95: Math.round(sorted[Math.floor(sorted.length * .95)]),
    cpu: +(s.cpu / s.frames).toFixed(1),
    calls: Math.round(s.calls / s.frames),
    triangles: Math.round(s.triangles / s.frames),
    resolution: `${renderer.domElement.width} × ${renderer.domElement.height}`,
    units: G.units.filter(u => !u.dead).length,
  };
  document.documentElement.dataset.performance = JSON.stringify(report);
  if (new URLSearchParams(location.search).has('qa')) {
    const hq = G.buildings.find(b => b.owner === 0 && b.key === 'hq');
    const materials = [];
    hq?.mesh.traverse(o => {
      if (!o.isMesh) return;
      for (const m of Array.isArray(o.material) ? o.material : [o.material]) {
        if (materials.some(x => x.name === m.name)) continue;
        materials.push({ name: m.name, color: m.color?.getHexString(),
          maps: ['map', 'normalMap', 'roughnessMap'].map(k => ({ key: k, exists: !!m[k], image: !!m[k]?.image, width: m[k]?.image?.width, type: m[k]?.image?.constructor?.name })) });
      }
    });
    document.documentElement.dataset.materialCheck = JSON.stringify(materials);
  }
  const label = document.getElementById('performance-readout');
  if (label) label.textContent = `${report.fps} FPS · ${report.resolution}`;
  const detail = document.getElementById('performance-detail');
  if (detail) detail.textContent = `Frame p95 ${report.p95} ms · CPU submission ${report.cpu} ms · ${report.calls} draw calls · ${(report.triangles / 1e6).toFixed(2)}M triangles · ${report.units} units`;
  s.elapsed = s.frames = s.cpu = s.calls = s.triangles = 0; s.samples = [];
}
