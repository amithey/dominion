'use strict';

/* Repeatable performance run: ?bench=N (N = extra drill units, default 64).
   Seeded map (see bootstrap.js), visual-review base, fixed cameras, the army
   marching in formation. Each phase warms up, then records every frame. The
   result is shown on screen, stored in data-benchmark and logged as JSON so
   runs on different machines, builds or engines can be compared directly. */
const BENCHMARK = { sample: null };
(() => {
  const params = new URLSearchParams(location.search);
  if (!params.has('bench')) return;
  const WARMUP = 2, DURATION = 8;
  const phases = [
    { name: 'Army close-up', dist: 85, pitch: .8, dx: 14, dz: 18 },
    { name: 'Base overview', dist: 200, pitch: .95, dx: 0, dz: 10 },
    // Moving the camera forces shadows and water reflections to redraw every frame.
    { name: 'Camera pan', dist: 110, pitch: .85, dx: 0, dz: 18, pan: 45 },
  ];
  const results = [];
  // Warm-up needs time AND frames: the first frames after spawning an army
  // compile shaders and can take seconds each.
  const WARMUP_FRAMES = 60;
  let phase = -1, elapsed = 0, warm = 0, measuring = false, frames = [], cpu = [], render = [], calls = 0, tris = 0, sawHidden = false;

  const gpu = () => {
    const gl = renderer.getContext(), ext = gl.getExtension('WEBGL_debug_renderer_info');
    return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
  };
  const pct = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))];
  const holdCamera = () => {
    const [x, z] = START_POS[0], p = phases[phase];
    mouse.onCanvas = false; camYaw = Math.PI * .25;
    const a = p.pan ? elapsed * .6 : 0, r = p.pan || 0;
    camFocus.set(x + p.dx + Math.cos(a) * r, 0, z + p.dz + Math.sin(a) * r); camDist = camZoomTarget = p.dist; camPitch = p.pitch;
  };
  const nextPhase = () => {
    phase++; elapsed = 0; warm = 0; measuring = false; frames = []; cpu = []; render = []; calls = tris = 0;
    if (phase < phases.length) { holdCamera(); return; }
    BENCHMARK.sample = null; report();
  };

  BENCHMARK.sample = (seconds, cpuMs, renderMs) => {
    if (phase < 0 || phase >= phases.length) return;
    holdCamera();
    sawHidden ||= document.hidden;
    elapsed += seconds;
    if (!measuring) {
      if (elapsed < WARMUP || ++warm < WARMUP_FRAMES) return;
      measuring = true; elapsed = 0; return;
    }
    frames.push(seconds * 1000); cpu.push(cpuMs); render.push(renderMs);
    calls += renderer.info.render.calls; tris += renderer.info.render.triangles;
    if (elapsed < DURATION) return;
    const sorted = [...frames].sort((a, b) => a - b), n = frames.length;
    results.push({
      phase: phases[phase].name,
      fps: +(n / (frames.reduce((a, b) => a + b, 0) / 1000)).toFixed(1),
      p50: +pct(sorted, .5).toFixed(1), p95: +pct(sorted, .95).toFixed(1),
      p99: +pct(sorted, .99).toFixed(1), worst: +sorted[n - 1].toFixed(1),
      hitches: frames.filter(f => f > 33.4).length,
      cpu: +(cpu.reduce((a, b) => a + b, 0) / n).toFixed(1),
      render: +(render.reduce((a, b) => a + b, 0) / n).toFixed(1),
      calls: Math.round(calls / n), triangles: Math.round(tris / n), frames: n,
    });
    nextPhase();
  };

  // &probe: after the run, time the pieces of one render in isolation (army
  // close-up camera). "submit" is CPU time of renderer.render(); "gpu" adds a
  // gl.finish(), so the difference is time the GPU needed beyond submission.
  function probe() {
    phase = 0; holdCamera(); updateCamera(0);
    const gl = renderer.getContext();
    // Each measurement warms up first; nothing here changes shader programs
    // (switching the light's castShadow would recompile every material).
    const time = (fn, runs = 20) => {
      for (let i = 0; i < 5; i++) fn();
      const t0 = performance.now();
      for (let i = 0; i < runs; i++) fn();
      return +((performance.now() - t0) / runs).toFixed(2);
    };
    let shadows = true;
    const frame = (finish) => () => {
      renderer.shadowMap.needsUpdate = shadows;
      renderer.render(scene, camera);
      if (finish) gl.finish();
    };
    let nodes = 0, meshes = 0, bones = 0, skinned = 0;
    scene.traverse(o => { nodes++; if (o.isMesh) meshes++; if (o.isBone) bones++; if (o.isSkinnedMesh) skinned++; });
    const out = { nodes, meshes, bones, skinned };
    out.matrixUpdate = time(() => scene.updateMatrixWorld());
    const measure = () => ({ submit: time(frame(false)), gpu: time(frame(true)) });
    out.base = measure();
    const toggle = (label, hide, show) => { hide(); out[label] = measure(); show(); };
    toggle('noShadowPass', () => { shadows = false; }, () => { shadows = true; });
    const water = []; scene.traverse(o => { if (o.material?.uniforms?.mirrorSampler) water.push(o); });
    toggle('noReflection', () => water.forEach(w => { w.visible = false; }), () => water.forEach(w => { w.visible = true; }));
    toggle('noUnits', () => G.units.forEach(u => { u.mesh.visible = false; }), () => G.units.forEach(u => { u.mesh.visible = !u.dead; }));
    const batches = [...(BUILDING_BATCH?.batches.values() || [])].map(b => b.mesh);
    toggle('noBuildings', () => { G.buildings.forEach(b => { b.mesh.visible = false; }); batches.forEach(m => { m.visible = false; }); },
      () => { G.buildings.forEach(b => { b.mesh.visible = true; }); batches.forEach(m => { m.visible = true; }); });
    const entityRoots = new Set([...G.units, ...G.buildings].map(e => e.mesh).concat(batches, water));
    const instanced = []; scene.traverse(o => { if (o.isInstancedMesh && o.visible && !entityRoots.has(o)) instanced.push(o); });
    toggle('noInstanced', () => instanced.forEach(t => { t.visible = false; }), () => instanced.forEach(t => { t.visible = true; }));
    // Everything else at the top of the scene, heaviest first, one at a time.
    const others = scene.children.filter(o => o.visible && !entityRoots.has(o) && !instanced.includes(o) && o !== terrainMesh)
      .map(o => { let n = 0; o.traverse(x => { if (x.isMesh || x.isLine || x.isPoints) n++; }); return { o, n }; })
      .filter(x => x.n > 0).sort((a, b) => b.n - a.n);
    out.otherGroups = others.slice(0, 6).map(({ o, n }) => {
      o.visible = false; const r = measure(); o.visible = true;
      return { name: o.name || o.type, drawables: n, ...r };
    });
    out.otherDrawables = others.reduce((s, x) => s + x.n, 0);
    toggle('noTerrain', () => { terrainMesh.visible = false; }, () => { terrainMesh.visible = true; });
    out.baseAgain = measure();
    const mixers = G.units.map(u => u.mesh.userData.mixer).filter(Boolean);
    out.animation = time(() => mixers.forEach(m => m.update(1 / 60)));
    out.simulation = time(() => { for (const u of G.units) if (!u.dead) updateUnit(u, 1 / 60); }, 5);
    return out;
  }

  function report() {
    const data = {
      version: 1, seed: params.get('seed') ?? '1', date: new Date().toISOString(),
      units: G.units.filter(u => !u.dead).length,
      resolution: `${renderer.domElement.width}×${renderer.domElement.height}`,
      pixelRatio: renderer.getPixelRatio(), graphics: G.graphics, gpu: gpu(),
      valid: !sawHidden && results.every(r => r.frames >= 120), phases: results,
    };
    if (params.has('probe')) { G.paused = true; data.probe = probe(); }
    document.documentElement.dataset.benchmark = JSON.stringify(data);
    console.log('DOMINION benchmark', JSON.stringify(data));
    // &report=http://localhost:PORT/name posts the result to a local collector
    // (used to run browser and Godot benchmarks back to back on one machine).
    const target = params.get('report');
    if (target && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//.test(target))
      fetch(target, { method: 'POST', body: JSON.stringify(data) }).catch(() => {});
    const panel = document.createElement('section');
    panel.id = 'benchmark-report';
    panel.innerHTML = `<h3>Benchmark · ${data.units} units · ${data.resolution}</h3>
      <p>${data.gpu}${data.valid ? '' : ' · <b>INVALID: the window was hidden or throttled (too few frames). Keep it visible and focused.</b>'}</p>
      <table><tr><th>Phase</th><th>FPS</th><th>p50</th><th>p95</th><th>p99</th><th>Worst</th><th>&gt;33 ms</th><th>CPU</th><th>of which render</th><th>Calls</th><th>Tris</th></tr>
      ${results.map(r => `<tr><td>${r.phase}</td><td>${r.fps}</td><td>${r.p50}</td><td>${r.p95}</td><td>${r.p99}</td><td>${r.worst}</td><td>${r.hitches}</td><td>${r.cpu}</td><td>${r.render}</td><td>${r.calls}</td><td>${(r.triangles / 1e6).toFixed(2)}M</td></tr>`).join('')}
      </table><p class="bench-note">Frame times in ms. CPU = JS simulation + render submission per frame; render = the render call alone.</p>
      <button id="bench-copy">Copy JSON</button> <button id="bench-rerun">Run again</button> <button id="bench-close">Close</button>`;
    document.body.appendChild(panel);
    panel.querySelector('#bench-copy').onclick = () => navigator.clipboard?.writeText(JSON.stringify(data, null, 2));
    panel.querySelector('#bench-rerun').onclick = () => location.reload();
    panel.querySelector('#bench-close').onclick = () => panel.remove();
  }

  G.reviewMode = true;
  if (!G.started && !G.loading) startGame();
  const waitForScene = setInterval(() => {
    const drill = document.getElementById('review-drill');
    if (!G.started || !drill) return;
    clearInterval(waitForScene);
    drill.click();
    nextPhase();
  }, 200);
})();
