const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const main = fs.readFileSync('js/main.js', 'utf8');
const ui = fs.readFileSync('js/ui.js', 'utf8');
function keyboardContext(ended = false) {
  const handlers = {}, calls = [];
  const c = vm.createContext({
    G: { started: true, gameOver: ended, continuingAfterEnd: false, paused: false },
    keys: {}, LOGISTICS: {}, window: { addEventListener: (name, fn) => handlers[name] = fn },
    handleControlGroup: () => { calls.push('group'); return false; },
    focusCapital: () => calls.push('capital'), toggleDisplayPanel: () => calls.push('display'),
    toggleGameHUD: () => calls.push('hud'), togglePause: () => calls.push('pause'),
    $$: () => [],
  });
  const start = main.indexOf("window.addEventListener('keydown'");
  vm.runInContext(main.slice(start, main.indexOf("window.addEventListener('keyup'", start)), c);
  return { c, handlers, calls };
}
function event(key, button = false) {
  return { key, repeat: false, preventDefault() {}, target: {
    closest: selector => button && selector.includes('button'),
  } };
}
for (const key of ['Home', 'F3', 'F10', ' ', 'Escape', '1', 'w']) {
  test(`pending result blocks background keyboard action ${JSON.stringify(key)}`, () => {
    const { c, handlers, calls } = keyboardContext(true);
    handlers.keydown(event(key));
    assert.equal(calls.length, 0);
    assert.equal(Object.keys(c.keys).length, 0);
  });
}
for (const key of [' ', 'Enter']) {
  test(`focused button owns ${JSON.stringify(key)} instead of pausing`, () => {
    const { handlers, calls } = keyboardContext();
    handlers.keydown(event(key, true));
    assert.equal(calls.length, 0);
  });
}
test('Space on the game surface still pauses normally', () => {
  const { handlers, calls } = keyboardContext(); handlers.keydown(event(' '));
  assert.ok(calls.includes('pause'));
});
test('continued campaign restores Home and control group shortcuts', () => {
  const { c, handlers, calls } = keyboardContext(true);
  c.G.continuingAfterEnd = true; handlers.keydown(event('Home'));
  assert.deepEqual(calls, ['group', 'capital']);
});
test('Home cannot move the map underneath the pause menu', () => {
  const { c, handlers, calls } = keyboardContext(); c.G.paused = true;
  handlers.keydown(event('Home')); assert.equal(calls.length, 0);
});
for (const [time, renders] of [[100, false], [600, true]]) {
  test(`paused world ${renders ? 'refreshes after' : 'skips rendering before'} half a second`, () => {
    const c = vm.createContext({ G: {started:true, paused:true}, requestAnimationFrame() {},
      clock: {getDelta:()=>0.016}, performance:{now:()=>time},
      renderer:{info:{reset(){throw new Error('render pipeline reached');}}},
    });
    vm.runInContext(main.slice(main.indexOf('function loop('),main.indexOf('/* ---------------- boot',main.indexOf('function loop('))),c);
    c.loop._pausedRenderTime = 0;
    if (renders) assert.throws(()=>c.loop(), /render pipeline reached/);
    else assert.doesNotThrow(()=>c.loop());
  });
}
function floating(width = 600, height = 400) {
  const win = { style: {}, getBoundingClientRect: () => ({left: 150, top: 100, width, height}) };
  const c = vm.createContext({ innerWidth: 1280, innerHeight: 720,
    clamp: (v, low, high) => Math.max(low, Math.min(high, v)), win });
  vm.runInContext(ui.slice(ui.indexOf('function fitFloatingWindow('), ui.indexOf('function makeDraggable(')), c);
  return { c, win };
}
for (const [left, top, expectedX, expectedY] of [
  [-900, 20, 0, 20], [1500, 20, 680, 20], [100, -800, 100, 0],
  [100, 900, 100, 320], [640, 260, 640, 260],
]) {
  test(`floating ministry remains visible after drag to ${left},${top}`, () => {
    const { c, win } = floating(); vm.runInContext(`fitFloatingWindow(win, ${left}, ${top})`, c);
    assert.equal(win.style.left, expectedX + 'px'); assert.equal(win.style.top, expectedY + 'px');
    assert.equal(win.style.transform, 'none');
  });
}
test('window is clamped again after shrinking the viewport', () => {
  const { c, win } = floating(); c.innerWidth = 800; c.innerHeight = 500;
  vm.runInContext('fitFloatingWindow(win, 1000, 1000)', c);
  assert.equal(win.style.left, '200px'); assert.equal(win.style.top, '100px');
});
test('oversized window keeps its title at the top left', () => {
  const { c, win } = floating(1600, 900); vm.runInContext('fitFloatingWindow(win)', c);
  assert.equal(win.style.left, '0px'); assert.equal(win.style.top, '0px');
});
test('showing a result clears a held movement key and unfinished map drag', () => {
  const nodes = {}, keys = { w: true, a: true }, mouse = { down: true, midPan: true, dragging: true };
  let focused = '', hidden = 0;
  const $ = id => nodes[id] ||= { style: {}, classList: { remove() {} }, focus: () => focused = id };
  const c = vm.createContext({G: {}, $, keys, mouse, hideDragBox: () => hidden++});
  vm.runInContext(ui.slice(ui.indexOf('function showEnd('), ui.indexOf('function continueAfterEnd(')), c);
  vm.runInContext("showEnd(true, 'Result')", c);
  assert.deepEqual(keys, {w: false, a: false});
  assert.deepEqual(mouse, {down: false, midPan: false, dragging: false});
  assert.equal(hidden, 1); assert.equal(focused, '#btn-continue');
});

for (const [action, field, threshold] of [
  ['proposePact', 'pact', 20], ['proposeAlliance', 'alliance', 55],
  ['proposeNap', 'nap', 10], ['proposeDefensePact', 'defensePact', 35], ['openEmbassy', 'embassy', -30],
]) for (const eligible of [false, true]) {
  test(`${action} ${eligible ? 'works at' : 'explains failure below'} its disclosed relation threshold`, () => {
    const fields = ['pact', 'alliance', 'nap', 'defensePact', 'embassy'];
    const diplo = Object.fromEntries(fields.map(f => [f, [[false, false], [false, false]]]));
    diplo.war = [[false, false], [false, false]];
    diplo.score = [[0, threshold - (eligible ? 0 : 1)], [threshold - (eligible ? 0 : 1), 0]];
    const notices = [];
    const c = vm.createContext({ G: { diplo, res: {money: 1000}, nations: [{}, {name:'Partner'}] },
      relScore: () => threshold - (eligible ? 0 : 1), notify: msg => notices.push(msg),
      isAtWar: () => false, hasEmbassy: () => false, hasNap: () => false, hasDefensePact: () => false,
      changeRel() {}, refreshStateWindows() {}, Math: {...Math, random: () => 0},
      clamp: (v,l,h) => Math.max(l, Math.min(h,v)),
    });
    vm.runInContext(fs.readFileSync('js/diplomacy.js','utf8'),c);
	c.refreshStateWindows = () => {};
    // The game's own queries use the fixture matrices above.
    vm.runInContext(`${action}(1)`,c);
    assert.equal(c.G.diplo[field][0][1], eligible);
    assert.equal(c.G.diplo[field][1][0], eligible);
    assert.ok(notices.length > 0);
    if (!eligible) assert.equal(c.G.res.money, 1000);
  });
}
