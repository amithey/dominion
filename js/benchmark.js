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
  let phase = -1, elapsed = 0, frames = [], cpu = [], calls = 0, tris = 0, sawHidden = false;

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
    phase++; elapsed = 0; frames = []; cpu = []; calls = tris = 0;
    if (phase < phases.length) { holdCamera(); return; }
    BENCHMARK.sample = null; report();
  };

  BENCHMARK.sample = (seconds, cpuMs) => {
    if (phase < 0 || phase >= phases.length) return;
    holdCamera();
    sawHidden ||= document.hidden;
    elapsed += seconds;
    if (elapsed < WARMUP) return;
    frames.push(seconds * 1000); cpu.push(cpuMs);
    calls += renderer.info.render.calls; tris += renderer.info.render.triangles;
    if (elapsed < WARMUP + DURATION) return;
    const sorted = [...frames].sort((a, b) => a - b), n = frames.length;
    results.push({
      phase: phases[phase].name,
      fps: +(n / (frames.reduce((a, b) => a + b, 0) / 1000)).toFixed(1),
      p50: +pct(sorted, .5).toFixed(1), p95: +pct(sorted, .95).toFixed(1),
      p99: +pct(sorted, .99).toFixed(1), worst: +sorted[n - 1].toFixed(1),
      hitches: frames.filter(f => f > 33.4).length,
      cpu: +(cpu.reduce((a, b) => a + b, 0) / n).toFixed(1),
      calls: Math.round(calls / n), triangles: Math.round(tris / n), frames: n,
    });
    nextPhase();
  };

  function report() {
    const data = {
      version: 1, seed: params.get('seed') ?? '1', date: new Date().toISOString(),
      units: G.units.filter(u => !u.dead).length,
      resolution: `${renderer.domElement.width}×${renderer.domElement.height}`,
      pixelRatio: renderer.getPixelRatio(), graphics: G.graphics, gpu: gpu(),
      valid: !sawHidden && results.every(r => r.frames >= 120), phases: results,
    };
    document.documentElement.dataset.benchmark = JSON.stringify(data);
    console.log('DOMINION benchmark', JSON.stringify(data));
    const panel = document.createElement('section');
    panel.id = 'benchmark-report';
    panel.innerHTML = `<h3>Benchmark · ${data.units} units · ${data.resolution}</h3>
      <p>${data.gpu}${data.valid ? '' : ' · <b>INVALID: the window was hidden or throttled (too few frames). Keep it visible and focused.</b>'}</p>
      <table><tr><th>Phase</th><th>FPS</th><th>p50</th><th>p95</th><th>p99</th><th>Worst</th><th>&gt;33 ms</th><th>CPU</th><th>Calls</th><th>Tris</th></tr>
      ${results.map(r => `<tr><td>${r.phase}</td><td>${r.fps}</td><td>${r.p50}</td><td>${r.p95}</td><td>${r.p99}</td><td>${r.worst}</td><td>${r.hitches}</td><td>${r.cpu}</td><td>${r.calls}</td><td>${(r.triangles / 1e6).toFixed(2)}M</td></tr>`).join('')}
      </table><p class="bench-note">Frame times in ms. CPU = JS simulation + render submission per frame.</p>
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
