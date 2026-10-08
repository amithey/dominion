const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function campaign() {
  const nodes = new Map();
  const $ = key => {
    if (!nodes.has(key)) {
      const classes = new Set(['hidden']);
      nodes.set(key, { style: {}, classList: {
        add: x => classes.add(x), remove: x => classes.delete(x),
        contains: x => classes.has(x),
        toggle: (x, on) => on ? classes.add(x) : classes.delete(x),
      } });
    }
    return nodes.get(key);
  };
  const G = { started: true, paused: false, gameOver: false, continuingAfterEnd: false,
    nations: [{}, { defeated: false }], units: [], buildings: [] };
  const c = vm.createContext({ G, $, notify() {}, killEntity() {} });
  const ui = fs.readFileSync('js/ui.js', 'utf8');
  vm.runInContext(ui.slice(ui.indexOf('function togglePause(')), c);
  return { G, $, c };
}

for (const victory of [true, false]) {
  test(`${victory ? 'victory' : 'defeat'} can continue, pause, resume and preserve the first result`, () => {
    const { G, $, c } = campaign();
    vm.runInContext(`showEnd(${victory}, 'Original campaign result')`, c);
    assert.equal(G.paused, true);
    vm.runInContext('togglePause(false)', c);
    assert.equal(G.paused, true, 'the result waits for an explicit decision');
    vm.runInContext('continueAfterEnd()', c);
    assert.equal(G.paused, false);
    assert.equal(G.continuingAfterEnd, true);
    assert.equal(G.gameOver, true);
    assert.equal($('#end-overlay').classList.contains('hidden'), true);
    vm.runInContext('togglePause(true); togglePause(false)', c);
    assert.equal(G.paused, false, 'pause remains reversible after the result');
    vm.runInContext(`showEnd(${!victory}, 'Another result')`, c);
    assert.equal($('#end-text').textContent, 'Original campaign result');
    assert.equal(G.paused, false, 'subsequent capital losses cannot stop the continued match');
  });
}

test('destroying the final rival capital finishes once and allows continued simulation', () => {
  const { G, c } = campaign();
  vm.runInContext('onHQDestroyed(1)', c);
  assert.equal(G.nations[1].defeated, true);
  assert.equal(G.gameOver, true);
  vm.runInContext('continueAfterEnd(); onHQDestroyed(1)', c);
  assert.equal(G.paused, false);
});

test('Escape closes ministries before pausing, and exits text fields without a shortcut', () => {
  const handlers = {};
  let open = true, blurred = false, pauses = 0, overlay = true;
  const c = vm.createContext({
    G: { started: true, placing: null, targeting: null }, LOGISTICS: {}, keys: {},
    document: { getElementById: () => ({}) },
    window: { addEventListener: (name, fn) => handlers[name] = fn },
    handleControlGroup: () => false,
    $$: () => open ? [{ classList: { remove: () => open = false } }] : [],
    setTerritoryOverlay: v => overlay = v, togglePause: () => pauses++,
  });
  const main = fs.readFileSync('js/main.js', 'utf8');
  const start = main.indexOf("window.addEventListener('keydown'");
  const end = main.indexOf("window.addEventListener('keyup'", start);
  vm.runInContext(main.slice(start, end), c);
  const event = { key: 'Escape', preventDefault() {}, target: { closest: () => false } };
  handlers.keydown(event);
  assert.equal(open, false);
  assert.equal(overlay, false);
  assert.equal(pauses, 0);
  handlers.keydown(event);
  assert.equal(pauses, 1);
  handlers.keydown({ ...event, target: { closest: () => true, blur: () => blurred = true } });
  assert.equal(blurred, true);
  assert.equal(pauses, 1);
});
