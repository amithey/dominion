'use strict';

const UI_PATHS = {
  money: '<circle cx="12" cy="12" r="8"/><path d="M15 8H10a2 2 0 0 0 0 4h4a2 2 0 0 1 0 4H9m3-10v12"/>',
  food: '<path d="M12 21V5m0 4C5 9 5 3 5 3s7 0 7 6Zm0 5c7 0 7-6 7-6s-7 0-7 6Zm0 5c-7 0-7-6-7-6s7 0 7 6Z"/>',
  oil: '<path d="M12 2S5 10 5 15a7 7 0 0 0 14 0c0-5-7-13-7-13Z"/>',
  iron: '<path d="m4 10 5-6h9l3 6-5 9H7L4 10Zm0 0h17M9 4l-2 15M18 4l-2 15"/>',
  silicon: '<path d="m12 2 9 10-9 10L3 12 12 2Zm0 0v20M3 12h18"/>',
  uranium: '<circle cx="12" cy="12" r="2"/><path d="M10 8 7 3a10 10 0 0 0-5 9h6m6-4 3-5a10 10 0 0 1 5 9h-6m-6 3-3 5a10 10 0 0 0 10 0l-3-5"/>',
  army: '<path d="M4 13v-2a8 8 0 0 1 16 0v2M2 13h20M7 14v4l5 4 5-4v-4M12 3v6"/>',
  citizens: '<circle cx="9" cy="7" r="3"/><path d="M3 21v-5a6 6 0 0 1 12 0v5m1-17a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 4v4"/>',
  research: '<path d="M9 2h6m-5 0v7L4 19q-1 3 3 3h10q4 0 3-3L14 9V2M7 15h10"/>',
  city: '<path d="M3 21h18M5 21V9h14v12M3 9l9-7 9 7M8 12v6m4-6v6m4-6v6"/>',
  map: '<path d="m2 5 7-3 6 3 7-3v17l-7 3-6-3-7 3V5Zm7-3v17m6-14v17"/>',
  diplomacy: '<path d="m2 10 5-6 5 3 5-3 5 6-8 10h-4L2 10Zm5-6 5 3-4 5 3 2 5-4 4 3M4 13l5 6"/>',
  trade: '<path d="m3 7 9-5 9 5v11l-9 4-9-4V7Zm0 0 9 5 9-5M12 12v10M7 5l9 5"/>',
  intel: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  military: '<path d="m12 2 9 4v7c0 4-9 9-9 9s-9-5-9-9V6l9-4Zm-4 8 8 6m0-6-8 6"/>',
  housing: '<path d="m2 11 10-9 10 9M5 9v13h14V9M9 22v-8h6v8"/>',
  industry: '<path d="M3 22V11l6-4v4l6-4v4h6v11H3Zm14-11V2h4v9M7 15v3m5-3v3m5-3v3"/>',
  power: '<path d="m14 1-11 13h8l-1 9 11-14h-8l1-8Z"/>',
  health: '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6V3Z"/>',
  settings: '<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="8" cy="6" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="10" cy="18" r="2"/>',
};
function uiIcon(name) {
  return `<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${UI_PATHS[name] || UI_PATHS.city}</svg>`;
}
function buildIcon(key, def) {
  if (/farm|fishing|food/i.test(key)) return 'food';
  if (/power|solar|nuclear/i.test(key)) return 'power';
  if (/house|housing|cottage|residential|apartment|villa/i.test(key)) return 'housing';
  if (/school|library|university|tech|chip/i.test(key)) return 'research';
  if (/hospital|waterTreatment|park/i.test(key)) return 'health';
  if (/market|port|warehouse|bank/i.test(key)) return 'trade';
  if (/mine|extractor|refinery|rig/i.test(key)) return 'industry';
  return def.cat === 'military' ? 'military' : 'city';
}
function stableHTML(el, html) {
  if (el._lastHTML === html) return;
  el._lastHTML = html;
  el.innerHTML = html;
}
function displayPixelRatio() {
  if (G.resolutionMode === 'supersample') return Math.min(2, Math.max(1.5, devicePixelRatio));
  return Math.max(1, Math.min(devicePixelRatio, 2));
}
function disposeComposer() {
  if (!composer) return;
  for (const pass of composer.passes) pass.dispose?.();
  composer.dispose();
  composer = bloomPass = gtaoPass = fxaaPass = smaaPass = null;
}
function applyDisplaySettings() {
  G.graphics = document.getElementById('display-quality').value;
  G.gfxHigh = G.graphics !== 'low';
  G.resolutionMode = document.getElementById('display-resolution').value;
  if (!renderer) return;
  disposeComposer();
  renderer.shadowMap.enabled = G.gfxHigh;
  sunLight.castShadow = G.gfxHigh;
  renderer.shadowMap.needsUpdate = true;
  scene.traverse(o => {
    if (!o.material) return;
    for (const m of Array.isArray(o.material) ? o.material : [o.material]) m.needsUpdate = true;
  });
  renderPixelRatio = displayPixelRatio();
  renderer.setPixelRatio(renderPixelRatio);
  renderer.setSize(innerWidth, innerHeight, false);
  qualitySampleTime = qualityFrameTime = qualityFrames = 0;
  initComposer();
}
function toggleDisplayPanel() {
  const panel = document.getElementById('display-panel');
  panel.hidden = !panel.hidden;
  document.getElementById('display-quality').value = G.graphics;
  document.getElementById('display-resolution').value = G.resolutionMode;
}
function focusCapital() {
  const capital = G.buildings.find(b => b.owner === 0 && b.key === 'hq' && !b.dead);
  if (!capital) return;
  camFocus.set(capital.x, 0, capital.z);
  select([capital]);
}
function initPresentation() {
  const names = ['city', 'map', 'diplomacy', 'trade', 'intel', 'research'];
  document.querySelectorAll('.side-btn').forEach((button, i) => {
    const label = button.querySelector('span').textContent;
    button.innerHTML = `${uiIcon(names[i])}<span>${label}</span>`;
    button.setAttribute('aria-label', button.title);
  });
  document.getElementById('btn-display').innerHTML = uiIcon('settings');
  document.getElementById('btn-display').onclick = toggleDisplayPanel;
  document.getElementById('display-close').onclick = toggleDisplayPanel;
  document.getElementById('display-quality').onchange = applyDisplaySettings;
  document.getElementById('display-resolution').onchange = applyDisplaySettings;
  document.getElementById('btn-capital').onclick = focusCapital;
  document.getElementById('btn-idle').onclick = () => {
    const idle = G.units.filter(u => !u.dead && u.owner === 0 && u.key === 'worker' && u.state === 'idle');
    if (!idle.length) return notify('All workers are assigned.', '', 3);
    select(idle); camFocus.set(idle[0].x, 0, idle[0].z);
  };
  document.getElementById('build-search').oninput = renderBuildPanel;
}
