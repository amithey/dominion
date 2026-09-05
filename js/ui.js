'use strict';
/* ============================================================
   UI: HUD, floating windows (drag fixed via pointer capture),
   minimap, notifications, menus
   ============================================================ */

const $ = sel => document.querySelector(sel);
const $$ = sel => [...document.querySelectorAll(sel)];

/* ---------------- notifications ---------------- */
function notify(text, kind = '', seconds = 5) {
  const el = document.createElement('div');
  el.className = 'notif ' + kind;
  el.textContent = text;
  $('#notifications').appendChild(el);
  const kill = () => { el.classList.add('fadeout'); setTimeout(() => el.remove(), 600); };
  setTimeout(kill, seconds * 1000);
  trimNotifs();
}
function notifyAction(text, actions, seconds = 15) {
  const el = document.createElement('div');
  el.className = 'notif warn';
  el.textContent = text;
  const row = document.createElement('div');
  row.className = 'n-actions';
  const kill = () => { el.classList.add('fadeout'); setTimeout(() => el.remove(), 600); };
  for (const a of actions) {
    const b = document.createElement('button');
    b.textContent = a.label;
    b.onclick = () => { a.fn(); kill(); };
    row.appendChild(b);
  }
  el.appendChild(row);
  $('#notifications').appendChild(el);
  setTimeout(kill, seconds * 1000);
  trimNotifs();
}
function trimNotifs() {
  const feed = $('#notifications');
  while (feed.children.length > 6) feed.firstChild.remove();
}

/* ---------------- decision modal ---------------- */
function closeDecision() {
  const el = document.querySelector('.decision-overlay');
  if (el) el.remove();
}
function openDecision(title, summary, choices) {
  closeDecision();
  const wrap = document.createElement('div');
  wrap.className = 'decision-overlay';
  const cardHtml = choices.map((c, idx) => `
    <div class="decision-card">
      <h3>${c.title}</h3>
      ${c.note ? `<div class="decision-summary">${c.note}</div>` : ''}
      <div class="decision-columns">
        <div>
          <div class="decision-mini-title good">Advantages</div>
          <ul>${(c.pros || ['No clear upside.']).map(x => `<li class="good">${x}</li>`).join('')}</ul>
        </div>
        <div>
          <div class="decision-mini-title bad">Disadvantages</div>
          <ul>${(c.cons || ['No major downside.']).map(x => `<li class="bad">${x}</li>`).join('')}</ul>
        </div>
      </div>
      <button class="dip-btn ${c.danger ? 'danger' : ''}" data-decision="${idx}" ${c.disabled ? 'disabled' : ''}>${c.actionLabel || 'Confirm'}</button>
    </div>`).join('');
  wrap.innerHTML = `<div class="decision-box">
    <div class="decision-head"><h2>${title}</h2><button class="decision-close">Close</button></div>
    <div class="decision-summary">${summary}</div>
    <div class="decision-grid">${cardHtml}</div>
  </div>`;
  wrap.querySelector('.decision-close').onclick = closeDecision;
  wrap.querySelectorAll('[data-decision]').forEach(btn => {
    btn.onclick = () => {
      const choice = choices[+btn.dataset.decision];
      closeDecision();
      choice.fn && choice.fn();
    };
  });
  $('#game-container').appendChild(wrap);
}

/* ---------------- draggable windows ----------------
   Fix for the "window snaps back" bug: on first drag we convert the
   window's centering transform into absolute px coordinates, then use
   pointer capture so fast drags never lose the handle. Positions are
   never touched by re-renders (content refresh only replaces .win-body). */
function makeDraggable(win) {
  const handle = win.querySelector('.win-title');
  let dragging = false, sx = 0, sy = 0, ox = 0, oy = 0;
  handle.addEventListener('pointerdown', e => {
    if (e.target.classList.contains('win-close')) return;
    dragging = true;
    const r = win.getBoundingClientRect();
    // lock current visual position in px and drop the centering transform
    win.style.left = r.left + 'px';
    win.style.top = r.top + 'px';
    win.style.transform = 'none';
    sx = e.clientX; sy = e.clientY; ox = r.left; oy = r.top;
    handle.setPointerCapture(e.pointerId);
    e.preventDefault();
  });
  handle.addEventListener('pointermove', e => {
    if (!dragging) return;
    const nx = clamp(ox + e.clientX - sx, -win.offsetWidth + 80, innerWidth - 60);
    const ny = clamp(oy + e.clientY - sy, 0, innerHeight - 40);
    win.style.left = nx + 'px';
    win.style.top = ny + 'px';
  });
  const stop = e => { dragging = false; try { handle.releasePointerCapture(e.pointerId); } catch (_) {} };
  handle.addEventListener('pointerup', stop);
  handle.addEventListener('pointercancel', stop);
}

function toggleWindow(id) {
  const win = document.getElementById(id);
  const opening = !win.classList.contains('open');
  win.classList.toggle('open');
  if (opening) renderWindow(id);
}
function refreshWindows() {
  for (const win of $$('.window.open')) {
    // don't rebuild a window the user is actively interacting with (kills open dropdowns)
    if (win.contains(document.activeElement) && document.activeElement !== document.body) continue;
    renderWindow(win.id);
  }
}

/* preserve select/input values across re-render */
function renderWindow(id) {
  const body = document.querySelector('#' + id + ' .win-body');
  const saved = {};
  body.querySelectorAll('select[data-keep], input[data-keep]').forEach(el => saved[el.dataset.keep] = el.value);
  switch (id) {
    case 'win-city': renderCity(body); break;
    case 'win-territory': renderTerritory(body); break;
    case 'win-diplomacy': renderDiplomacy(body); break;
    case 'win-espionage': renderEspionage(body, saved); break;
    case 'win-trade': renderTrade(body, saved); break;
    case 'win-tech': renderTech(body); break;
  }
  body.querySelectorAll('select[data-keep], input[data-keep]').forEach(el => {
    if (saved[el.dataset.keep] !== undefined) el.value = saved[el.dataset.keep];
  });
}

/* ---------------- City window ---------------- */
function statBar(label, val, color) {
  return `<div class="stat-row"><span>${label}</span><span class="bar"><div style="width:${val}%;background:${color}"></div></span><b>${Math.round(val)}</b></div>`;
}
function renderCity(body) {
  const c = G.city;
  const gv = G.gov;
  const gov = GOVERNMENTS[gv.form];
  const trait = LEADER_TRAITS[gv.leader.trait];
  const yearsToEvent = Math.max(0, (gv.nextEvent - G.time) / YEAR_SECONDS);
  const eventLabel = gv.form === 'democracy' ? 'Next election' :
    gv.form === 'dictatorship' ? 'Next loyalty check' :
    gv.form === 'monarchy' ? 'Succession review' : 'Board review';
  const unstable = gv.instabilityUntil > G.time;
  const caps = c.caps || {};
  const civicLeader = G.civic && G.civic.leader;
  const civicTrait = civicLeader ? CIVIC_LEADERS[civicLeader.trait] : null;
  const localYears = Math.max(0, ((G.civic && G.civic.nextElection) || 0) - G.time) / YEAR_SECONDS;
  const appointReady = G.time >= ((G.civic && G.civic.lastAppointment) || -Infinity) + CIVIC_APPOINT_COOLDOWN;
  const eraIndex = (G.development && G.development.era) || 0;
  const era = DEVELOPMENT_ERAS[eraIndex];
  const nextEra = DEVELOPMENT_ERAS[eraIndex + 1] || null;
  const nextReqs = nextEra ? developmentRequirementStatus(nextEra) : [];
  const settlements = settlementBuildings(0, true);

  body.innerHTML = `
    <div class="section-h">${era.icon} National Development — ${era.name}</div>
    <div class="fx-list" style="margin-bottom:6px">${era.desc}<br>
      Permanent era bonus: <b>+${eraIndex * 5}% income & research, +${eraIndex * 3}% production</b>
    </div>
    ${nextEra ? `<div class="tech-track"><div class="tech-head"><span>Next goal: ${nextEra.icon} ${nextEra.name}</span><span>${nextReqs.filter(r => r.met).length}/${nextReqs.length}</span></div>
      <div class="tech-desc">${nextEra.desc}</div>
      <div class="fx-list">${nextReqs.map(r => `<span style="color:${r.met ? 'var(--ok)' : 'var(--gold)'}">${r.met ? '✓' : '○'} ${r.label}: ${r.displayValue}/${r.displayNeed}</span>`).join(' · ')}</div>
      <div class="fx-list" style="font-size:11px">Reward: +$${nextEra.reward.money}, +${nextEra.reward.research} research</div></div>`
      : '<div class="fx-list" style="color:var(--ok)">Maximum era reached. Pursue conquest, hegemony or technological victory.</div>'}

    <div class="section-h">🏘️ Settlement Network — ${settlements.length}</div>
    <div class="stat-grid">${settlements.map(s => `<div class="stat-row"><span>${s.key === 'hq' ? '🏛️' : s.key === 'cityCenter' ? '🏙️' : '🏡'} ${settlementDisplayName(s)}</span><b>${s.def.buildRadius} build radius</b></div>`).join('')}</div>
    <div class="fx-list" style="font-size:11px;margin-bottom:8px">Normal buildings must be placed inside a settlement district. Found villages and cities to create new construction zones and claim distant resources.</div>

    <div class="stat-grid">
      <div>${statBar('😊 Happiness', c.happiness, '#5dff8f')}</div>
      <div>${statBar('❤️ Health', c.health, '#ff8f8f')}</div>
      <div>${statBar('🎓 Education', c.education, '#4da3ff')}</div>
      <div>${statBar('🎖️ Army Morale', c.morale, '#ffd24d')}</div>
      <div>${statBar('🚓 Public Order', c.order || 0, '#8fb7ff')}</div>
      <div>${statBar('🎭 Culture', c.culture || 0, '#d78fff')}</div>
    </div>

    <div class="section-h">Government — ${gov.icon} ${gov.name}${unstable ? ' <b style="color:var(--danger)">⚠ UNSTABLE</b>' : ''}</div>
    <div class="fx-list">
      Leader: <b>${leaderTitle()} ${gv.leader.name}</b> ${trait.icon} <b>"${trait.name}"</b> — ${trait.desc}<br>
      ${gov.desc}<br>
      ${statBar('🏛️ Approval', c.approval || 0, (c.approval || 0) > 45 ? '#5dff8f' : '#ff5d5d')}
      ${eventLabel}: <b>${yearsToEvent.toFixed(1)} years</b>
    </div>
    <div class="form-row" style="margin-top:8px"><label>⚖️ Reform</label>
      ${Object.entries(GOVERNMENTS).map(([k, g2]) =>
        `<button class="dip-btn ${gv.form === k ? 'active-pol' : ''}" ${gv.form === k ? 'disabled' : ''}
          title="${g2.desc}" onclick="switchGovernment('${k}')">${g2.icon} ${g2.name}</button>`).join('')}
    </div>
    <div class="fx-list" style="margin-bottom:4px;font-size:11px">
      Constitutional reform costs $${GOV_SWITCH_COST}, causes ${GOV_SWITCH_INSTABILITY}s of instability, ${Math.round(GOV_SWITCH_COOLDOWN / 60)} min cooldown.
    </div>

    <div class="section-h">City Administration - ${civicTitle()}</div>
    <div class="fx-list">
      Local office: <b>${civicTitle()} ${civicLeader ? civicLeader.name : 'Vacant'}</b>
      ${civicTrait ? `${civicTrait.icon} <b>"${civicTrait.name}"</b> - ${civicTrait.desc}` : ''}<br>
      Only the head of state stands for election — the ${civicTitle()} is an appointed office. Pick the profile the city needs right now.
    </div>
    <div class="form-row"><label>Appoint</label>
      ${Object.entries(CIVIC_LEADERS).map(([k, l]) =>
        `<button class="dip-btn" title="${l.desc}" ${appointReady && G.res.money >= CIVIC_APPOINT_COST ? '' : 'disabled'}
          onclick="appointCivicLeader('${k}')">${l.icon} ${l.name}</button>`).join('')}
    </div>
    <div class="fx-list" style="margin-bottom:4px;font-size:11px">
      Appointment costs $${CIVIC_APPOINT_COST}, causes 15s local instability, ${Math.round(CIVIC_APPOINT_COOLDOWN / 60)} min cooldown.
    </div>

    <div class="section-h">Policies</div>
    <div class="form-row"><label>${POLICIES.tax.icon} Taxation</label>
      ${Object.entries(POLICIES.tax.options).map(([k, o]) =>
        `<button class="dip-btn ${G.policies.tax === k ? 'active-pol' : ''}" onclick="setPolicy('tax','${k}')">${o.label}</button>`).join('')}
    </div>
    ${['rationing', 'propaganda', 'freeHealthcare'].map(p => {
      const pol = POLICIES[p];
      return `<div class="form-row"><label>${pol.icon} ${pol.name}</label>
        <button class="dip-btn ${G.policies[p] ? 'active-pol' : ''}" onclick="setPolicy('${p}',${!G.policies[p]})">${G.policies[p] ? 'ON' : 'OFF'}</button>
        <span style="font-size:11px;color:var(--text-dim)">${pol.desc}</span></div>`;
    }).join('')}

    <div class="section-h">National ledger</div>
    <div class="fx-list">
      Citizens: <b>${Math.floor(c.civilians)}/${c.civCap || 200}</b> (build Residential Districts for more)<br>
      Tax income: <b>$${c.income.toFixed(1)}/s</b> · Research: <b>+${c.researchRate.toFixed(2)}/s</b><br>
      ⚡ Power grid: <b style="color:${c.power && c.power.factor < 1 ? 'var(--danger)' : 'var(--ok)'}">${c.power ? c.power.supply : 0} MW supply / ${c.power ? c.power.demand : 0} MW demand</b>
      ${c.power && c.power.factor < 1 ? `<b style="color:var(--danger)">— BLACKOUTS! output at ${Math.round(c.power.factor * 100)}% (build Power Plants / Solar Farms)</b>` : '(surplus — everything runs at full speed)'}<br>
      💻 Chip fabs online: <b>${c.compute || 0}</b> → +${((c.compute || 0) * 5)}% research, +${((c.compute || 0) * 2)}% income <span style="color:var(--text-dim)">(technological supremacy)</span><br>
      Food flow: <b>${c.foodRate >= 0 ? '+' : ''}${c.foodRate.toFixed(2)}/s</b> (storage ${Math.floor(G.res.food)}/${caps.food || 300})<br>
      Materials storage: oil <b>${Math.floor(G.res.oil)}/${caps.oil || 500}</b> · iron <b>${Math.floor(G.res.iron)}/${caps.iron || 500}</b> ·
      silicon <b>${Math.floor(G.res.silicon)}/${caps.silicon || 400}</b> · uranium <b>${Math.floor(G.res.uranium)}/${caps.uranium || 300}</b><br>
      Missile stockpile: <b>${missileStock()}/${missileCap()}</b> (Ammo Depots add +4 each)<br>
      Army: <b>${c.popUsed}/${c.popCap}</b> capacity · Damage multiplier: <b>x${(0.7 + c.morale / 200).toFixed(2)}</b><br>
      🗺️ Territory: <b>${c.territory || 0} zones</b> held → tribute <b>+$${(c.territoryIncome || 0).toFixed(1)}/s</b>
      <span style="color:var(--text-dim)">(buildings & troops claim the land they stand on)</span>
    </div>`;
}
function policyDecisionDetails(key, value) {
  if (key === 'tax') {
    const o = POLICIES.tax.options[value];
    const pros = [];
    const cons = [];
    const incomePct = Math.round((o.incomeMult - 1) * 100);
    if (incomePct > 0) pros.push(`Tax income +${incomePct}%`);
    else if (incomePct < 0) cons.push(`Tax income ${incomePct}%`);
    else pros.push('No tax-income penalty.');
    if (o.approval > 0) pros.push(`Approval +${o.approval}`);
    else if (o.approval < 0) cons.push(`Approval ${o.approval}`);
    if (o.happiness > 0) pros.push(`Happiness +${o.happiness}`);
    else if (o.happiness < 0) cons.push(`Happiness ${o.happiness}`);
    if (!cons.length) cons.push('No major downside.');
    return {
      title: `Taxation: ${o.label}`,
      pros,
      cons,
    };
  }
  const p = POLICIES[key];
  const turningOn = !!value;
  return {
    title: `${p.name}: ${turningOn ? 'ON' : 'OFF'}`,
    pros: [turningOn ? p.desc : 'Removes upkeep and side effects.'],
    cons: [turningOn && p.costPerSec ? `Upkeep: $${p.costPerSec}/s` : 'Loses the policy bonus.'],
  };
}
function setPolicy(key, value, confirmed = false) {
  if (!confirmed) {
    const d = policyDecisionDetails(key, value);
    openDecision('Policy Vote', 'Review the policy effect before passing it into law.', [{
      title: d.title, pros: d.pros, cons: d.cons,
      actionLabel: 'Pass law',
      fn: () => setPolicy(key, value, true),
    }]);
    return;
  }
  if (key === 'tax') G.policies.tax = value;
  else G.policies[key] = value;
  updateCity();
  renderWindow('win-city');
}

/* ---------------- Territory window — the occupation war room ---------------- */
function renderTerritory(body) {
  const mine = territorySummary(0);
  const totalLand = TERRITORY.owner ? Array.from(TERRITORY.owner).filter((o, i) => {
    const c = cellCenter(i); return terrainH(c.x, c.z) >= 0.05;
  }).length : 1;
  const rivalsLeft = G.nations.filter((n, i) => i > 0 && !n.defeated).length;
  const discDone = Object.keys(DISCOVERIES).filter(k => G.discovered[k]).length;
  const discTotal = Object.keys(DISCOVERIES).length;
  const share = Math.round((G.landShare || 0) * 100);
  const hegT = (G.hegemony && G.hegemony.t) || 0;
  let html = `
    <div class="section-h">🏆 Paths to Victory</div>
    <div class="stat-grid">
      <div class="stat-row"><span>⚔️ Conquest — destroy every rival HQ</span><b>${3 - rivalsLeft}/3 eliminated</b></div>
      <div class="stat-row"><span>👑 Hegemony — hold 60% of the world for 5 min</span><b style="color:${share >= 60 ? 'var(--gold)' : 'var(--text)'}">${share}%${hegT > 0 ? ` · ${Math.max(0, 300 - hegT)}s left` : ''}</b></div>
      <div class="stat-row"><span>🔬 Technology — complete the research tree</span><b>${discDone}/${discTotal}</b></div>
    </div>
    <div class="fx-list" style="font-size:11px;margin:2px 0 8px">Grow past 45% of the world and the surviving powers will form a coalition against you.</div>
    <div class="section-h">Strategic map <span style="color:var(--text-dim)">(click to move the camera)</span></div>
    <canvas id="terr-map" width="272" height="272" style="width:100%;border:1px solid rgba(255,255,255,.15);border-radius:6px;cursor:crosshair;image-rendering:pixelated"></canvas>
    <div class="fx-list" style="font-size:11px;margin:4px 0 8px">
      <span style="color:#ffe08a">■</span> contested front · brighter tint = stronger control · dark = no man's land / water
    </div>
    <div class="stat-grid">
      <div class="stat-row"><span>Held zones</span><b>${mine.held} <span style="color:var(--text-dim)">(${Math.round(mine.held / Math.max(totalLand, 1) * 100)}% of all land)</span></b></div>
      <div class="stat-row"><span>Contested zones</span><b style="color:${mine.contested ? 'var(--gold)' : 'var(--text)'}">${mine.contested}</b></div>
      <div>${statBar('Average control', mine.avgControl, mine.avgControl > 65 ? '#5dff8f' : mine.avgControl > 35 ? '#ffd24d' : '#ff5d5d')}</div>
      <div class="stat-row"><span>Front-line zones</span><b>${mine.fronts}</b></div>
      <div class="stat-row"><span>Territory tribute</span><b>+$${mine.tribute.toFixed(1)}/s</b></div>
    </div>
    <div class="section-h">Integration of your land</div>
    ${(() => {
      const y = territoryYields(0);
      return `<div class="stat-grid">
      <div class="stat-row"><span>🏛️ Sovereign (control ≥70)</span><b style="color:#5dff8f">${y.sovereign} zones · full yield</b></div>
      <div class="stat-row"><span>🏘️ Integrated (40–70)</span><b style="color:#b9d98a">${y.integrated} zones · 75% yield</b></div>
      <div class="stat-row"><span>🪖 Occupied (&lt;40)</span><b style="color:#e8a83a">${y.occupied} zones · 40% yield</b></div>
      <div class="stat-row"><span>⚔️ Contested front</span><b style="color:#ffe08a">${y.contested} zones · 15% yield</b></div>
      <div class="stat-row"><span>Terrain yields</span><b>+$${y.money.toFixed(1)}/s · +${y.food.toFixed(2)} 🌾/s · +${y.iron.toFixed(2)} ⛏️/s</b></div>
      </div>
      <div class="fx-list" style="font-size:11px;margin:4px 0 8px">
        🌾 Plains feed your people · 🌲 Forests sell lumber · ⛰️ Mountains yield iron · 🌊 Coasts earn trade money.
        Newly conquered land is <b>occupied</b> — garrison it until control rises and it integrates into the homeland.
      </div>`;
    })()}
    <div class="section-h">Doctrine of occupation</div>
    <div class="fx-list">
      1. Capitals, cities and villages anchor your territory; other buildings fill their construction districts.<br>
      2. Combat units occupy the cell they stand on; guarding troops apply extra pressure and stabilize a frontier.<br>
      3. Enemy land flips gradually: wear control down → contest (gold) → capture. Freshly taken land has weak control — garrison it or it slips back.<br>
      4. Contested land blocks construction. Every held zone pays tribute.
    </div>
    <div class="section-h">Nation control</div>`;
  for (let i = 0; i < G.nations.length; i++) {
    const n = G.nations[i];
    const s = territorySummary(i);
    const share = Math.round(s.held / Math.max(totalLand, 1) * 100);
    html += `<div class="nation-card" style="${n.defeated ? 'opacity:.5' : ''}">
      <div class="nation-head">
        <span class="nation-dot" style="background:${n.css}"></span>
        <span class="nation-name">${n.name}</span>
        <span class="rel-status" style="color:${n.css};border-color:${n.css}">${s.held} zones · ${share}%</span>
      </div>
      <div class="fx-list">
        Control: <b>${Math.round(s.avgControl)}%</b> · Contested: <b>${s.contested}</b> · Fronts: <b>${s.fronts}</b> · Tribute value: <b>$${s.tribute.toFixed(1)}/s</b>
      </div>
    </div>`;
  }
  body.innerHTML = html;
  drawTerritoryMap();
}

function drawTerritoryMap() {
  const cv = $('#terr-map');
  if (!cv || !TERRITORY.owner) return;
  const ctx = cv.getContext('2d');
  const W = cv.width, H = cv.height;
  ctx.fillStyle = '#0a141d';
  ctx.fillRect(0, 0, W, H);
  const cw = W / TERRITORY.cols, ch = H / TERRITORY.rows;
  for (let cz = 0; cz < TERRITORY.rows; cz++) {
    for (let cx = 0; cx < TERRITORY.cols; cx++) {
      const i = cz * TERRITORY.cols + cx;
      const c = cellCenter(i);
      const h = terrainH(c.x, c.z);
      if (h < 0.05) { ctx.fillStyle = '#12283a'; ctx.fillRect(cx * cw, cz * ch, cw + 0.5, ch + 0.5); continue; }
      const owner = TERRITORY.owner[i];
      if (owner < 0) { ctx.fillStyle = '#25301f'; ctx.fillRect(cx * cw, cz * ch, cw + 0.5, ch + 0.5); continue; }
      if (TERRITORY.contested[i]) ctx.fillStyle = '#ffe08a';
      else {
        ctx.fillStyle = G.nations[owner].css;
        ctx.globalAlpha = 0.35 + (TERRITORY.control[i] / 100) * 0.6;
      }
      ctx.fillRect(cx * cw, cz * ch, cw + 0.5, ch + 0.5);
      ctx.globalAlpha = 1;
    }
  }
  // Civilization markers: capitals are largest, cities medium, villages small.
  for (const b of G.buildings) {
    if (b.dead || !b.built || !isSettlementBuilding(b)) continue;
    const px = (b.x + HALF_MAP) / MAP_SIZE * W, pz = (b.z + HALF_MAP) / MAP_SIZE * H;
    const size = b.key === 'hq' ? 4.2 : b.key === 'cityCenter' ? 3.4 : 2.5;
    ctx.fillStyle = '#fff';
    ctx.beginPath(); ctx.arc(px, pz, size, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = G.nations[b.owner].css;
    ctx.beginPath(); ctx.arc(px, pz, Math.max(1.5, size - 1.2), 0, Math.PI * 2); ctx.fill();
  }
  // camera marker
  ctx.strokeStyle = '#ffffff';
  ctx.strokeRect((camFocus.x + HALF_MAP) / MAP_SIZE * W - 5, (camFocus.z + HALF_MAP) / MAP_SIZE * H - 5, 10, 10);
  cv.onclick = ev => {
    const r = cv.getBoundingClientRect();
    camFocus.x = ((ev.clientX - r.left) / r.width) * MAP_SIZE - HALF_MAP;
    camFocus.z = ((ev.clientY - r.top) / r.height) * MAP_SIZE - HALF_MAP;
  };
}

/* ---------------- Diplomacy window ---------------- */
function renderDiplomacy(body) {
  let html = '';
  for (let i = 1; i < G.nations.length; i++) {
    const nat = G.nations[i];
    if (nat.defeated) {
      html += `<div class="nation-card" style="opacity:.5"><div class="nation-head">
        <span class="nation-dot" style="background:${nat.css}"></span>
        <span class="nation-name">${nat.name}</span><span class="rel-status" style="color:#888;border-color:#555">DEFEATED</span></div></div>`;
      continue;
    }
    const s = relScore(0, i);
    const st = relationStatus(s, isAtWar(0, i), isAllied(0, i));
    const pct = (s + 100) / 2;
    html += `
    <div class="nation-card">
      <div class="nation-head">
        <span class="nation-dot" style="background:${nat.css}"></span>
        <span class="nation-name">${nat.name}</span>
        ${hasEmbassy(0, i) ? '<span style="font-size:10px;color:#8fb7ff">embassy</span>' : ''}
        ${hasPact(0, i) ? '<span style="font-size:10px;color:#8fe388">📜 pact</span>' : ''}
        ${hasNap(0, i) ? '<span style="font-size:10px;color:#8fb7ff">NAP</span>' : ''}
        ${hasDefensePact(0, i) ? '<span style="font-size:10px;color:#5dff8f">defense</span>' : ''}
        ${hasSanction(0, i) ? '<span style="font-size:10px;color:#ff9b5d">sanctioned</span>' : ''}
        <span class="rel-status" style="color:${st.color};border-color:${st.color}">${st.label} (${s > 0 ? '+' : ''}${Math.round(s)})</span>
      </div>
      <div class="rel-bar-wrap"><div class="mid"></div><div style="height:100%;width:${pct}%;background:linear-gradient(90deg,#ff5d5d,#c9c9c9 50%,#5dff8f)"></div></div>
      <div class="fx-list">${diplomacyFactors(i).map(x => `- ${x}`).join('<br>')}</div>
      ${(() => {
        // what you know about them depends on your intelligence picture
        const il = intelLevel(i);
        if (il < 10) return `<div class="fx-list" style="font-size:11px;color:var(--text-dim)">🧩 Intel ${il}/100 — run espionage ops to reveal their treasury, army and plans.</div>`;
        let info = `<div class="fx-list" style="font-size:11px">🧩 Intel <b>${il}</b>/100`;
        info += ` · 💰 Treasury: <b>$${Math.floor(nat.money)}</b> · 🏗️ Buildings: <b>${G.buildings.filter(b => b.owner === i && !b.dead).length}</b>`;
        if (il >= 25) info += ` · ⚔️ Army strength: <b>${armyStrength(i).toFixed(0)}</b>`;
        if (il >= 40) {
          const wars = G.nations.map((n2, j) => j !== i && !n2.defeated && isAtWar(i, j) ? n2.name : null).filter(Boolean);
          const allies = G.nations.map((n2, j) => j !== i && !n2.defeated && isAllied(i, j) ? n2.name : null).filter(Boolean);
          info += `<br>🗡️ At war with: <b>${wars.join(', ') || 'no one'}</b> · 🤝 Allied with: <b>${allies.join(', ') || 'no one'}</b>`;
        }
        if (il >= 60) info += `<br>🛰️ <b>Deep coverage:</b> you will get advance warning if they mass forces against you.`;
        return info + '</div>';
      })()}
      <div class="dip-actions">
        ${isAtWar(0, i)
          ? `<button class="dip-btn" onclick="offerPeace(${i})">🕊️ Offer Peace</button>`
          : `<button class="dip-btn" onclick="sendGift(${i})">🎁 Gift ($250)</button>
             <button class="dip-btn" onclick="sendAid(${i})">Aid ($300 + 80 food)</button>
             ${hasEmbassy(0, i)
               ? `<button class="dip-btn danger" onclick="expelEmbassy(${i})">Expel Embassy</button>`
               : `<button class="dip-btn" onclick="openEmbassy(${i})">Open Embassy</button>`}
             <button class="dip-btn" onclick="proposePact(${i})" ${hasPact(0, i) || hasSanction(0, i) ? 'disabled' : ''}>📜 Trade Pact</button>
             ${hasNap(0, i)
               ? `<button class="dip-btn" onclick="breakNap(${i})">Cancel NAP</button>`
               : `<button class="dip-btn" onclick="proposeNap(${i})">Non-Aggression</button>`}
             ${hasSanction(0, i)
               ? `<button class="dip-btn" onclick="liftSanctions(${i})">Lift Sanctions</button>`
               : `<button class="dip-btn danger" onclick="imposeSanctions(${i})">Sanctions</button>`}
             ${isAllied(0, i)
               ? `<button class="dip-btn" onclick="breakAlliance(${i})">💔 Break Alliance</button>
                  ${G.nations.map((t, ti) => ti !== 0 && ti !== i && !t.defeated && isAtWar(0, ti)
                    ? `<button class="dip-btn danger" onclick="requestJointWar(${i},${ti})">⚔️ Join war vs ${t.name.split(' ')[0]}</button>` : '').join('')}`
               : `<button class="dip-btn" onclick="proposeAlliance(${i})">🤝 Alliance</button>`}
             ${hasDefensePact(0, i)
               ? `<button class="dip-btn" onclick="breakDefensePact(${i})">Cancel Defense Pact</button>`
               : `<button class="dip-btn" onclick="proposeDefensePact(${i})">Defense Pact</button>`}
             <button class="dip-btn" onclick="demandTribute(${i})">😤 Demand Tribute</button>
             <button class="dip-btn danger" onclick="declareWar(0,${i});refreshWindows()">⚔️ Declare War</button>`}
      </div>
    </div>`;
  }
  // trade deal form
  const natOpts = G.nations.map((n, i) => i > 0 && !n.defeated && !isAtWar(0, i) ? `<option value="${i}">${n.name}</option>` : '').join('');
  const resOpts = RES_KEYS.map(k => `<option value="${k}">${RES_META[k].icon} ${RES_META[k].name}</option>`).join('');
  html += `
    <div class="section-h">Propose a trade deal</div>
    <div class="form-row"><label>Partner</label><select id="tr-nation" data-keep="tr-nation">${natOpts}</select></div>
    <div class="form-row"><label>You give</label><select id="tr-give" data-keep="tr-give">${resOpts}</select>
      <input id="tr-give-amt" data-keep="tr-give-amt" type="number" value="100" min="1" style="width:80px"></div>
    <div class="form-row"><label>You receive</label><select id="tr-get" data-keep="tr-get">${resOpts}</select>
      <input id="tr-get-amt" data-keep="tr-get-amt" type="number" value="50" min="1" style="width:80px"></div>
    <button class="dip-btn" onclick="uiProposeTrade()">📨 Send Offer</button>
    <div class="section-h">World relations matrix</div>
    ${relationsMatrix()}`;
  body.innerHTML = html;
}
function relationsMatrix() {
  const ns = G.nations;
  let t = '<table class="matrix-table"><tr><th></th>' +
    ns.map(n => `<th style="color:${n.css}">${n.name.split(' ')[0]}</th>`).join('') + '</tr>';
  for (let a = 0; a < ns.length; a++) {
    t += `<tr><th style="color:${ns[a].css}">${ns[a].name.split(' ')[0]}</th>`;
    for (let b = 0; b < ns.length; b++) {
      if (a === b) { t += '<td style="background:rgba(255,255,255,.05)">—</td>'; continue; }
      if (ns[a].defeated || ns[b].defeated) { t += '<td style="color:#666">✝</td>'; continue; }
      const st = relationStatus(relScore(a, b), isAtWar(a, b), isAllied(a, b));
      t += `<td style="color:${st.color}">${st.label}</td>`;
    }
    t += '</tr>';
  }
  return t + '</table>';
}
function uiProposeTrade() {
  const sel = $('#tr-nation');
  if (!sel || !sel.value) { notify('No nation available to trade with.', 'warn'); return; }
  proposeTrade(+sel.value, $('#tr-give').value, Math.max(1, +$('#tr-give-amt').value),
    $('#tr-get').value, Math.max(1, +$('#tr-get-amt').value));
}

/* ---------------- Espionage window ---------------- */
function renderEspionage(body, saved) {
  const hasAgency = playerBuildingCount('intelAgency') > 0;
  const natOpts = G.nations.map((n, i) => i > 0 && !n.defeated ? `<option value="${i}">${n.name}</option>` : '').join('');
  const opOpts = Object.entries(SPY_OPS).map(([k, o]) => `<option value="${k}">${o.icon} ${o.name} ($${o.cost})</option>`).join('');
  const selOp = saved['sp-op'] || 'stealFunds';
  const selNat = +(saved['sp-nation'] || 1);
  const ready = readyAgents();
  const selAgent = ready.find(a => a.id === +(saved['sp-agent'] || 0)) || ready[0];
  const agentBonus = selAgent ? (selAgent.skill - 1) * AGENT_SKILL_BONUS : 0;
  const chance = hasAgency ? Math.round(clamp(opSuccessChance(selOp, selNat) + agentBonus, 0.05, 0.97) * 100) : 0;
  const network = Math.round((G.spy.network && G.spy.network[selNat]) || 0);
  const heat = Math.round((G.spy.heat && G.spy.heat[selNat]) || 0);
  const opNeed = (SPY_OPS[selOp] && SPY_OPS[selOp].minNetwork) || 0;
  const report = G.spy.lastReport && G.spy.lastReport[selNat];
  const agentOpts = ready.map(a =>
    `<option value="${a.id}">🕵️ "${a.name}" — ${agentRank(a)} (skill ${a.skill}/5)</option>`).join('');
  const personRow = SPY_OPS[selOp] && SPY_OPS[selOp].needsPerson ? `
    <div class="form-row"><label>Target person</label>
      <select id="sp-person" data-keep="sp-person">
        ${Object.entries(ASSASSIN_TARGETS).map(([k, t]) =>
          `<option value="${k}">${t.label} — ${G.nations[selNat] ? G.nations[selNat].people[k] : ''}</option>`).join('')}
      </select></div>
    <div class="fx-list" style="margin-bottom:8px">${Object.entries(ASSASSIN_TARGETS).map(([k, t]) => `<b>${t.label}:</b> ${t.effect}`).join('<br>')}</div>` : '';
  // roster: every agent with status, xp progress and ransom action for captured ones
  const rosterRows = G.agentRoster.map(a => {
    const nextLvl = AGENT_XP_LEVELS[a.skill - 1];
    const xpTxt = a.skill >= 5 ? 'MAX' : `${a.xp}/${nextLvl} xp`;
    const status = a.status === 'ready'
      ? '<b style="color:var(--ok)">READY</b>'
      : `<b style="color:var(--danger)">CAPTURED by ${G.nations[a.capturedBy] ? G.nations[a.capturedBy].name : '?'}</b>
         <button class="dip-btn" style="margin-left:6px" onclick="ransomAgent(${a.id})">🔓 Ransom ($${AGENT_RANSOM})</button>`;
    return `<div class="stat-row" style="margin-bottom:4px">
      <span>🕵️ <b>"${a.name}"</b> · ${agentRank(a)} ${'★'.repeat(a.skill)}${'☆'.repeat(5 - a.skill)} <span style="color:var(--text-dim)">(${xpTxt}, ${a.ops} ops)</span></span>
      <span>${status}</span></div>`;
  }).join('') || '<div class="fx-list">No agents. Recruit your first operative.</div>';
  body.innerHTML = `
    ${hasAgency ? '' : '<div class="fx-list" style="color:var(--danger);margin-bottom:8px">⚠️ Build an <b>Intelligence Agency</b> to unlock covert operations.</div>'}
    <div class="stat-grid">
      <div class="stat-row"><span>🕵️ Ready agents</span><b>${ready.length}/${G.agentRoster.length}</b></div>
      <div class="stat-row"><span>🗝️ Covert Ops tech</span><b>Lv ${G.tech.espionage}</b></div>
      <div class="stat-row"><span>Network in target</span><b>${network}/100</b></div>
      <div class="stat-row"><span>Heat</span><b style="color:${heat > 65 ? 'var(--danger)' : heat > 35 ? 'var(--gold)' : 'var(--ok)'}">${heat}/100</b></div>
    </div>
    <div class="section-h">Intelligence picture: ${G.nations[selNat] ? G.nations[selNat].name : ''}</div>
    ${statBar('🧩 Intel level', intelLevel(selNat), intelLevel(selNat) > 60 ? '#5dff8f' : intelLevel(selNat) > 25 ? '#ffd24d' : '#8899aa')}
    <div class="fx-list" style="font-size:11px;margin-bottom:6px">
      ${INTEL_TIERS.map(t => `<span style="color:${intelLevel(selNat) >= t.at ? 'var(--ok)' : 'var(--text-dim)'}">${intelLevel(selNat) >= t.at ? '🔓' : '🔒'} ${t.at}: ${t.label}</span>`).join('<br>')}
      <br><span style="color:var(--text-dim)">Every successful op adds intel (recon adds the most). Intel decays — keep the picture fresh. Each unique report type: +2% op success (max +10%). Findings appear in the Diplomacy window.</span>
    </div>
    <div class="section-h">Agent roster</div>
    ${rosterRows}
    <button class="dip-btn" style="margin-top:6px" onclick="recruitAgent()" ${hasAgency ? '' : 'disabled'}>➕ Recruit Agent ($${agentRecruitCost()})</button>
    <div class="fx-list" style="font-size:11px;margin-top:4px">Agents earn XP on successful ops and level up (+${Math.round(AGENT_SKILL_BONUS * 100)}% success per skill level). Veterans escape capture more often. Idle agents also defend you against <b>enemy spy attacks</b>.</div>
    <div class="section-h">Launch operation</div>
    <div class="form-row"><label>Agent</label><select id="sp-agent" data-keep="sp-agent" onchange="renderWindow('win-espionage')">${agentOpts || '<option>—</option>'}</select></div>
    <div class="form-row"><label>Operation</label><select id="sp-op" data-keep="sp-op" onchange="renderWindow('win-espionage')">${opOpts}</select></div>
    <div class="form-row"><label>Target nation</label><select id="sp-nation" data-keep="sp-nation" onchange="renderWindow('win-espionage')">${natOpts}</select></div>
    ${personRow}
    ${opNeed ? `<div class="fx-list" style="color:${network >= opNeed ? 'var(--ok)' : 'var(--gold)'}">Required network: <b>${opNeed}</b> · current: <b>${network}</b></div>` : ''}
    <div class="fx-list" style="margin:6px 0">${SPY_OPS[selOp].desc}<br>
      Success chance${selAgent ? ` with "${selAgent.name}"` : ''}: <b style="color:${chance > 55 ? 'var(--ok)' : chance > 35 ? 'var(--gold)' : 'var(--danger)'}">${chance}%</b>
      · On failure the agent may be <b>captured</b> (ransom to recover them).</div>
    ${report ? `<div class="fx-list" style="margin:6px 0"><b>Last dossier:</b> army ${report.army}, treasury $${report.money}, buildings ${report.buildings}, relation ${report.relation}</div>` : ''}
    <button class="dip-btn danger" ${hasAgency && ready.length > 0 && network >= opNeed ? '' : 'disabled'}
      onclick="runSpyOp($('#sp-op').value, +$('#sp-nation').value, $('#sp-person') ? $('#sp-person').value : null, $('#sp-agent') ? $('#sp-agent').value : null)">🚀 Execute Operation</button>
    <div class="section-h">Intelligence archive</div>
    ${G.spy.reports.length ? G.spy.reports.slice(0, 8).map(r =>
      `<div class="fx-list" style="margin-bottom:3px;font-size:11px"><span style="color:var(--text-dim)">[${Math.floor(r.t / 60)}:${String(Math.floor(r.t % 60)).padStart(2, '0')}]</span> ${r.text}</div>`).join('')
      : '<div class="fx-list" style="font-size:11px">No reports filed yet. Run operations to build the archive.</div>'}`;
  for (const k of ['sp-op', 'sp-nation', 'sp-agent']) {
    if (saved[k]) { const el = $('#' + k); if (el) el.value = saved[k]; }
  }
}

/* ---------------- World Trade window ---------------- */
function renderTrade(body, saved) {
  const hasMarket = playerBuildingCount('market') > 0;
  const portCount = playerBuildingCount('port');
  const partners = G.nations.map((n, i) =>
    i > 0 && !n.defeated && hasPact(0, i) && !isAtWar(0, i) ? `<option value="${i}">${n.name}</option>` : '').join('');
  const resOpts = Object.keys(TRADE_PRICE).map(r =>
    `<option value="${r}">${RES_META[r].icon} ${RES_META[r].name}</option>`).join('');
  // market prices with trend indicator
  let priceRows = '';
  for (const r of Object.keys(TRADE_PRICE)) {
    const mult = G.market.mult[r] || 1;
    const p = tradePrice(r);
    const trend = mult > 1.15 ? '📈' : mult < 0.85 ? '📉' : '➖';
    priceRows += `<div class="stat-row"><span>${RES_META[r].icon} ${RES_META[r].name} ${trend}</span>
      <b style="color:${mult > 1.15 ? 'var(--ok)' : mult < 0.85 ? 'var(--danger)' : 'var(--text)'}">$${p.toFixed(1)}/unit</b></div>`;
  }
  // active routes
  const routeRows = G.trade.routes.map(r => {
    const nat = G.nations[r.nation];
    return `<div class="stat-row" style="margin-bottom:4px">
      <span>${r.dir === 'export' ? '📤' : '📥'} ${RES_META[r.res].icon} ${r.qty} cargo ${r.dir === 'export' ? '→' : '←'} <b>${nat.name}</b>
        <span style="color:var(--text-dim)">(${r.status || 'Awaiting cargo'} · last ${r.flow > 0 ? '+$' + r.flow : r.flow < 0 ? '-$' + (-r.flow) : '$0'} · total $${Math.round(r.total)})</span></span>
      <button class="dip-btn danger" onclick="cancelTradeRoute(${r.id})">✕</button></div>`;
  }).join('') || '<div class="fx-list">No active routes. A nation without trade withers — open one below.</div>';
  const iso = G.city.isolated;
  body.innerHTML = `
    ${iso ? '<div class="fx-list" style="color:var(--danger);margin-bottom:8px">⚠️ <b>AUTARKY:</b> you have no trade links — income -12%, happiness -5. Sign a Trade Pact and open routes!</div>' : ''}
    ${!portCount ? '<div class="fx-list" style="color:var(--gold);margin-bottom:8px">⚓ Build a <b>Commercial Port</b> on the coast before opening shipping routes.</div>' : ''}
    <div class="stat-grid"><div class="stat-row"><span>⚓ Port berths</span><b>${portCount * TRADE_ROUTES_PER_PORT}</b></div>
      <div class="stat-row"><span>🛡️ Loss risk / voyage</span><b>${Math.round(tradeRouteRisk() * 100)}%</b></div>
      <div class="stat-row"><span>✅ Delivered / lost</span><b>${G.trade.delivered || 0} / ${G.trade.lost || 0}</b></div></div>
    <div class="section-h">World market prices (drift with supply & demand)</div>
    <div class="stat-grid">${priceRows}</div>
    <div class="section-h">Instant deals ${hasMarket ? '' : '— <span style="color:var(--gold)">requires a Market building</span>'}</div>
    <div class="form-row"><label>Resource</label><select id="tr-ires" data-keep="tr-ires">${resOpts}</select></div>
    <div style="display:flex;gap:6px;margin-bottom:8px">
      <button class="dip-btn" ${hasMarket ? '' : 'disabled'} onclick="instantTrade($('#tr-ires').value, 50, 'sell')">📤 Sell 50 (${Math.round(TRADE_INSTANT_SELL * 100)}% price)</button>
      <button class="dip-btn" ${hasMarket ? '' : 'disabled'} onclick="instantTrade($('#tr-ires').value, 50, 'buy')">📥 Buy 50 (${Math.round(TRADE_INSTANT_BUY * 100)}% price)</button>
    </div>
    <div class="section-h">Shipping routes — ${G.trade.routes.length}/${routeCap()} <span style="color:var(--text-dim)">(2 berths per Port; contracts from pacts and Markets)</span></div>
    ${routeRows}
    <div class="section-h">Open a new route</div>
    ${partners ? `
    <div class="form-row"><label>Partner</label><select id="tr-nation" data-keep="tr-nation">${partners}</select></div>
    <div class="form-row"><label>Resource</label><select id="tr-res" data-keep="tr-res">${resOpts}</select></div>
    <div class="form-row"><label>Direction</label><select id="tr-dir" data-keep="tr-dir">
      <option value="export">📤 Export (sell for money)</option>
      <option value="import">📥 Import (buy with money, +${Math.round((TRADE_IMPORT_MARKUP - 1) * 100)}% markup)</option></select></div>
    <div class="form-row"><label>Volume</label><select id="tr-qty" data-keep="tr-qty">
      ${TRADE_QTY.map(q => `<option value="${q}">${q} units / shipment</option>`).join('')}</select></div>
    <button class="dip-btn" ${portCount ? '' : 'disabled'} onclick="createTradeRoute(+$('#tr-nation').value, $('#tr-res').value, $('#tr-dir').value, $('#tr-qty').value)">🚢 Open Route</button>
    <div class="fx-list" style="font-size:11px;margin-top:6px">Cargo is reserved when loaded and pays out on arrival after ${TRADE_VOYAGE_SECONDS}s. War, sanctions and piracy can destroy cargo at sea. Combat ships reduce piracy risk.</div>`
    : '<div class="fx-list" style="color:var(--gold)">No eligible partners. Sign a 📜 Trade Pact in the Diplomacy window first.</div>'}`;
  for (const k of ['tr-ires', 'tr-nation', 'tr-res', 'tr-dir', 'tr-qty']) {
    if (saved[k]) { const el = $('#' + k); if (el) el.value = saved[k]; }
  }
}

/* ---------------- Tech window ---------------- */
function renderTech(body) {
  let html = `<div class="fx-list" style="margin-bottom:10px">Research points: <b>${Math.floor(G.city.research)}</b> (+${G.city.researchRate.toFixed(2)}/s from schools, libraries & universities)</div>`;
  for (const [k, t] of Object.entries(TECH_TRACKS)) {
    const lvl = G.tech[k];
    const cost = t.baseCost * (lvl + 1);
    const maxed = lvl >= t.max;
    html += `
    <div class="tech-track">
      <div class="tech-head"><span>${t.icon} ${t.name}</span><span>Lv ${lvl}/${t.max}</span></div>
      <div class="tech-pips">${Array.from({ length: t.max }, (_, i) => `<span class="pip ${i < lvl ? 'on' : ''}"></span>`).join('')}</div>
      <div class="tech-desc">${t.desc}</div>
      <button class="dip-btn" style="margin-top:6px" ${maxed || G.city.research < cost ? 'disabled' : ''}
        onclick="buyTech('${k}')">${maxed ? 'MAXED' : `Research (${cost} pts)`}</button>
    </div>`;
  }
  // ---- the discovery tree, grouped by branch ----
  const doneCount = Object.keys(DISCOVERIES).filter(k => G.discovered[k]).length;
  html += `<div class="section-h">Research Tree — ${doneCount}/${Object.keys(DISCOVERIES).length} discoveries</div>`;
  for (const [bk, br] of Object.entries(DISC_BRANCHES)) {
    const entries = Object.entries(DISCOVERIES).filter(([, d]) => (d.branch || 'society') === bk);
    if (!entries.length) continue;
    const branchDone = entries.filter(([k]) => G.discovered[k]).length;
    html += `<div class="tech-head" style="margin:10px 2px 4px"><span>${br.icon} <b>${br.name}</b></span><span>${branchDone}/${entries.length}</span></div>`;
    for (const [k, d] of entries) {
      const done = G.discovered[k];
      let blocked = '';
      if (d.reqBuilding && !playerBuildingCount(d.reqBuilding)) blocked = `Requires a ${BUILDINGS[d.reqBuilding].name}`;
      if (d.reqDiscovery && !G.discovered[d.reqDiscovery]) blocked = `Requires "${DISCOVERIES[d.reqDiscovery].name}"`;
      const chain = d.reqDiscovery ? `↳ after ${DISCOVERIES[d.reqDiscovery].name} · ` : '';
      html += `
      <div class="tech-track" style="${done ? 'opacity:.65;border-color:rgba(93,255,143,.4)' : blocked ? 'opacity:.8' : ''}">
        <div class="tech-head"><span>${d.icon} ${d.name}</span><span>${done ? '✅ DISCOVERED' : d.cost + ' pts'}</span></div>
        <div class="tech-desc">${chain}${d.desc}${blocked ? `<br><b style="color:var(--gold)">🔒 ${blocked}</b>` : ''}</div>
        ${done ? '' : `<button class="dip-btn" style="margin-top:6px" ${blocked || G.city.research < d.cost ? 'disabled' : ''}
          onclick="buyDiscovery('${k}')">Discover (${d.cost} pts)</button>`}
      </div>`;
    }
  }
  body.innerHTML = html;
}
function buyDiscovery(k) {
  const d = DISCOVERIES[k];
  if (G.discovered[k] || G.city.research < d.cost) return;
  if (d.reqBuilding && !playerBuildingCount(d.reqBuilding)) return;
  if (d.reqDiscovery && !G.discovered[d.reqDiscovery]) return;
  G.city.research -= d.cost;
  G.discovered[k] = true;
  recalcDiscoveryFx(); // apply the new bonuses immediately
  notify(`${d.icon} DISCOVERY: ${d.name}! ${d.desc}`, 'good', 8);
  renderWindow('win-tech');
  renderBuildPanel();
}
function buyTech(k) {
  const t = TECH_TRACKS[k];
  const cost = t.baseCost * (G.tech[k] + 1);
  if (G.tech[k] >= t.max || G.city.research < cost) return;
  G.city.research -= cost;
  G.tech[k]++;
  notify(`🔬 ${t.name} advanced to level ${G.tech[k]}!`, 'good');
  renderWindow('win-tech');
}

/* ---------------- top bar ---------------- */
function updateTopBar() {
  const caps = G.city.caps || {};
  const parts = RES_KEYS.map(k => {
    let delta = '';
    if (k === 'money') delta = `<span class="delta pos">+${G.city.income.toFixed(1)}/s</span>`;
    if (k === 'food') {
      const r = G.city.foodRate || 0;
      delta = `<span class="delta ${r >= 0 ? 'pos' : 'neg'}">${r >= 0 ? '+' : ''}${r.toFixed(1)}/s</span>`;
    }
    const cap = caps[k] ? ` / ${caps[k]}` : '';
    return `<span class="res-item" title="${RES_META[k].name}${cap}"><span class="ico">${uiIcon(k)}</span><span class="res-value"><small>${RES_META[k].name}</small>${fmtNum(G.res[k])}</span>${delta}</span>`;
  });
  parts.push(`<span class="res-item" title="Army / capacity"><span class="ico">${uiIcon("army")}</span>${G.city.popUsed}/${G.city.popCap}</span>`);
  parts.push(`<span class="res-item" title="Citizens / capacity"><span class="ico">${uiIcon("citizens")}</span>${fmtNum(G.city.civilians)}</span>`);
  parts.push(`<span class="res-item" title="Research points"><span class="ico">${uiIcon("research")}</span>${fmtNum(G.city.research)}</span>`);
  const stock = missileStock();
  if (stock > 0 || playerBuildingCount('missileSilo') > 0)
    parts.push(`<span class="res-item" title="Missile stockpile / capacity"><span class="ico">🚀</span>${stock}/${missileCap()}</span>`);
  stableHTML($('#res-bar'), parts.join(''));
  const m = Math.floor(G.time / 60), s = Math.floor(G.time % 60);
  $('#clock').textContent = `Year ${Math.floor(G.time / YEAR_SECONDS) + 1} · ${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/* ---------------- build panel ---------------- */
let buildCat = 'economy';
/* buildings grouped where they belong — the panel reads like a real ministry */
const BUILD_GROUPS = {
  military: [
    ['🏭 Production', ['barracks', 'tankFactory', 'helipad', 'airfield', 'shipyard', 'missileSilo']],
    ['🛡️ Defense', ['samSite', 'bunker']],
    ['📡 Support', ['ammoDepot', 'commandCenter']],
  ],
  economy: [
    ['🏛️ Settlements', ['villageCenter', 'cityCenter']],
    ['🌾 Food', ['farm', 'foodDepot', 'fishingWharf']],
    ['🏘️ Housing', ['workerHouse', 'housing', 'cottage', 'residential', 'apartments', 'luxuryVillas']],
    ['⛏️ Industry & Resources', ['extractor', 'offshoreRig', 'mountainMine', 'warehouse', 'oilRefinery', 'market', 'port']],
    ['⚡ Power', ['powerPlant', 'solarFarm', 'nuclearReactor']],
    ['💻 High-Tech', ['techPark', 'chipFab']],
  ],
  civic: [
    ['🏛️ Governance', ['cityHall', 'courthouse', 'policeStation', 'intelAgency', 'tvStation']],
    ['🎓 Knowledge', ['school', 'library', 'university']],
    ['❤️ Wellbeing', ['hospital', 'waterTreatment', 'park', 'stadium', 'museum']],
    ['💰 Finance', ['bank']],
  ],
};
function renderBuildPanel() {
  const grid = $('#build-grid');
  const state = Object.entries(BUILDINGS).filter(([, d]) => d.cat === buildCat && !d.unbuildable)
    .map(([key, d]) => `${key}:${!!(d.unique && playerBuildingCount(key))}:${!!(d.needsDiscovery && !G.discovered[d.needsDiscovery])}:${canAfford(G.res, d.cost)}`).join('|');
  const query = ($('#build-search')?.value || '').trim().toLowerCase();
  const signature = `${buildCat}:${query}:${state}`;
  if (grid.dataset.signature === signature) return;
  grid.dataset.signature = signature;
  const scrollTop = grid.scrollTop;
  grid.innerHTML = '';
  const groups = BUILD_GROUPS[buildCat] || [];
  const grouped = new Set(groups.flatMap(([, ks]) => ks));
  const order = [];
  for (const [gname, ks] of groups) {
    const present = ks.filter(k => BUILDINGS[k] && !BUILDINGS[k].unbuildable && BUILDINGS[k].cat === buildCat && (!query || (BUILDINGS[k].name + ' ' + BUILDINGS[k].desc).toLowerCase().includes(query)));
    if (present.length) order.push([gname, present]);
  }
  // anything not explicitly grouped still shows up at the end
  const rest = Object.keys(BUILDINGS).filter(k =>
    !BUILDINGS[k].unbuildable && BUILDINGS[k].cat === buildCat && !grouped.has(k) && (!query || BUILDINGS[k].name.toLowerCase().includes(query)));
  if (rest.length) order.push(['Other', rest]);
  for (const [gname, ks] of order) {
    const h = document.createElement('div');
    h.className = 'build-group-h';
    h.textContent = gname.replace(/^[^A-Za-z]+/, '');
    grid.appendChild(h);
    for (const key of ks) buildPanelButton(grid, key, BUILDINGS[key]);
  }
  if (!order.length) grid.innerHTML = '<div class=build-empty>No matching structures in this category.</div>';
  grid.scrollTop = scrollTop;
}
function buildPanelButton(grid, key, def) {
  {
    const unique = def.unique && playerBuildingCount(key) > 0;
    const locked = def.needsDiscovery && !G.discovered[def.needsDiscovery];
    const afford = canAfford(G.res, def.cost);
    const btn = document.createElement('button');
    btn.className = 'build-btn';
    btn.disabled = unique || locked || !afford;
    btn.title = def.desc + (def.onDeposit ? ' (place ON a resource deposit)' : '');
    btn.innerHTML = `<span class="bico">${uiIcon(buildIcon(key, def))}</span><span class="bname">${def.name}</span><span class="bcost">${
      unique ? 'built' : locked ? '🔒 ' + DISCOVERIES[def.needsDiscovery].name : costText(def.cost)}</span>`;
    btn.dataset.build = key;
    btn.onclick = () => startPlacement(key);
    grid.appendChild(btn);
  }
}

/* ---------------- selection panel ---------------- */
function renderSelection() {
  const el = $('#sel-info');
  const sel = G.selection.filter(e => !e.dead);
  if (!sel.length) {
    stableHTML(el, `<div class="hud-empty-title">NO UNIT SELECTED</div>
      <div class="hud-empty-sub">Select a unit or structure to open its tactical controls.</div>
      <div class="hud-hotkeys"><span><kbd>LMB</kbd> Select</span><span><kbd>RMB</kbd> Command</span><span><kbd>A</kbd> Attack-move</span><span><kbd>WASD</kbd> Camera</span></div>`);
    return;
  }
  if (sel.length === 1) {
    const e = sel[0];
    const frac = clamp(e.hp / e.maxHp, 0, 1);
    let html = `<div class="sel-title">${e.def.icon || ''} ${isSettlementBuilding(e) ? settlementDisplayName(e) : e.def.name} ${e.owner !== 0 ? `<span style="color:${G.nations[e.owner].css}">(${G.nations[e.owner].name})</span>` : ''}</div>
      <div class="sel-sub">${e.def.desc || ''}</div>
      <div class="hp-bar"><div style="width:${frac * 100}%;background:${frac > 0.5 ? 'var(--ok)' : frac > 0.25 ? 'var(--gold)' : 'var(--danger)'}"></div></div>
      HP ${Math.ceil(e.hp)}/${Math.ceil(e.maxHp)}`;
    if (e.type === 'building' && e.owner === 0) {
      if (!e.built) html += `<div class="sel-sub" style="margin-top:6px">🚧 Under construction — ${Math.round(e.progress * 100)}% (needs a worker)</div>`;
      else {
        if (e.def.trains) {
          html += '<div class="prod-row">';
          for (const uk of e.def.trains) {
            const u = UNITS[uk];
            const locked = u.needsDiscovery && !G.discovered[u.needsDiscovery];
            html += `<button class="prod-btn" ${locked ? 'disabled' : ''} onclick="uiTrain(${e.id},'${uk}')">${u.icon} Train ${u.name}<span class="cost">${locked ? '🔒 ' + DISCOVERIES[u.needsDiscovery].name : costText(u.cost) + ' · ' + u.pop + ' pop · ' + u.trainTime + 's'}</span></button>`;
          }
          html += '</div>';
        }
        if (e.def.planeSlots) {
          // hangar roster: every based aircraft with its own select/scramble control
          const based = G.units.filter(u => !u.dead && u.homeBase === e);
          const slots = e.def.planeSlots;
          html += `<div class="sel-sub" style="margin-top:6px">🛩️ Hangar — ${based.length}/${slots} slots ` +
            Array.from({ length: slots }, (_, i) => i < based.length ? '🟩' : '⬜').join('') + '</div>';
          if (based.length) {
            html += '<div class="prod-row">';
            for (const p of based) {
              const hpPct = Math.round(p.hp / p.maxHp * 100);
              const fuelPct = Math.round(clamp((p.fuel || 0) / PLANE_FUEL, 0, 1) * 100);
              const parked = p.state === 'landed';
              html += `<button class="prod-btn" onclick="uiSelectPlane(${p.id})">${p.def.icon} ${p.def.name} #${p.id}
                <span class="cost">${parked ? '🛬 parked' : '✈️ airborne'} · HP ${hpPct}% · fuel ${fuelPct}% — click to select, then right-click a target</span></button>`;
            }
            html += '</div>';
          }
        }
        if (e.def.missiles) {
          html += '<div class="prod-row">';
          for (const mk of e.def.missiles) {
            const md = MISSILES[mk];
            const locked = md.needsDiscovery && !G.discovered[md.needsDiscovery];
            html += `<button class="prod-btn" ${locked ? 'disabled' : ''} onclick="uiProduceMissile(${e.id},'${mk}')">${md.icon} Build ${md.name}<span class="cost">${locked ? '🔒 ' + DISCOVERIES[md.needsDiscovery].name : costText(md.cost) + ' · ' + md.buildTime + 's'}</span></button>`;
          }
          html += '</div><div class="prod-row">';
          for (const mk of e.def.missiles) {
            const md = MISSILES[mk];
            const stock = G.munitions[mk];
            html += `<button class="prod-btn" style="border-color:${stock > 0 ? 'var(--danger)' : 'var(--border)'}" ${stock > 0 ? '' : 'disabled'} onclick="uiLaunchMissile(${e.id},'${mk}')">🎯 LAUNCH ${md.name}<span class="cost">In stock: ${stock} — click, then click the target on the map</span></button>`;
          }
          html += '</div>';
        }
        if (e.queue.length) {
          const qLabel = q => q.startsWith('missile:') ? MISSILES[q.slice(8)].icon : UNITS[q].icon;
          html += `<div class="queue-row"><span class="prog-bar"><div style="width:${e.queueProg * 100}%"></div></span>` +
            e.queue.map((q, i) => `<span class="queue-item">${qLabel(q)}${i === 0 ? ' ' + Math.round(e.queueProg * 100) + '%' : ''}</span>`).join('') + '</div>';
        }
      }
    }
    if (e.type === 'unit' && e.key === 'worker' && e.owner === 0) {
      html += `<div class="sel-sub" style="margin-top:6px">Right-click: a deposit to mine · an unfinished building to construct · a forest to clear it for building space (sells lumber).</div>`;
    }
    // strategic missile submarine: launch stored missiles from the sub's position
    if (e.type === 'unit' && e.def.canLaunchMissiles && e.owner === 0) {
      const subMissiles = ['cruise', 'ballistic', 'nuke'].filter(mk => !MISSILES[mk].needsDiscovery || G.discovered[MISSILES[mk].needsDiscovery]);
      html += '<div class="sel-sub" style="margin-top:6px">🌊 Missile boat — launch from the stockpile at the sub\'s position:</div><div class="prod-row">';
      for (const mk of subMissiles) {
        const stock = G.munitions[mk];
        html += `<button class="prod-btn" style="border-color:${stock > 0 ? 'var(--danger)' : 'var(--border)'}" ${stock > 0 ? '' : 'disabled'} onclick="uiLaunchFromSub(${e.id},'${mk}')">🎯 ${MISSILES[mk].name}<span class="cost">In stock: ${stock}</span></button>`;
      }
      html += '</div>';
    }
    if (e.type === 'unit' && e.state === 'landed' && e.owner === 0) {
      html += `<div class="sel-sub" style="margin-top:6px">🛬 Based at airfield · fuel ${Math.round((e.fuel || 0) / PLANE_FUEL * 100)}% — right-click a target or location to launch a sortie.</div>`;
    }
    stableHTML(el, html);
  } else {
    const byKey = {};
    for (const e of sel) byKey[e.def.name] = (byKey[e.def.name] || 0) + 1;
    stableHTML(el, `<div class="sel-title">${sel.length} selected</div>
      <div class="sel-sub">${Object.entries(byKey).map(([k, v]) => `${v}× ${k}`).join(' · ')}</div>
      <div class="hint">Right-click to move/attack · A+click = attack-move</div>`);
  }
}
function uiTrain(bid, key) {
  const b = G.buildings.find(x => x.id === bid);
  if (b && !b.dead) tryTrain(b, key);
  renderSelection();
}
function uiProduceMissile(bid, mType) {
  const b = G.buildings.find(x => x.id === bid);
  if (b && !b.dead) tryProduceMissile(b, mType);
  renderSelection();
}
function uiSelectPlane(uid) {
  const u = G.units.find(x => x.id === uid && !x.dead);
  if (!u) return;
  select([u]);
  notify(`${u.def.icon} ${u.def.name} #${u.id} selected — right-click a target or location to launch its sortie.`, '', 5);
}
function uiLaunchMissile(bid, mType) {
  const b = G.buildings.find(x => x.id === bid);
  if (!b || b.dead || G.munitions[mType] <= 0) return;
  G.targeting = { kind: mType, silo: b };
  notify(`🎯 Targeting mode: left-click anywhere on the map to launch the ${MISSILES[mType].name}. Right-click / Esc to abort.`, 'warn', 8);
}
function uiLaunchFromSub(uid, mType) {
  const u = G.units.find(x => x.id === uid);
  if (!u || u.dead || G.munitions[mType] <= 0) return;
  G.targeting = { kind: mType, silo: { x: u.x, z: u.z } };
  notify(`🎯 ${MISSILES[mType].name} from ${u.def.name}: left-click the target on the map. Right-click / Esc to abort.`, 'warn', 8);
}

/* ---------------- minimap ---------------- */
let mmTerrain = null;
function buildMinimapTerrain() {
  mmTerrain = document.createElement('canvas');
  mmTerrain.width = mmTerrain.height = 320;
  const ctx = mmTerrain.getContext('2d');
  const img = ctx.createImageData(320, 320);
  for (let py = 0; py < 320; py++) for (let px = 0; px < 320; px++) {
    const x = (px / 320 - 0.5) * MAP_SIZE, z = (py / 320 - 0.5) * MAP_SIZE;
    const h = terrainH(x, z);
    let r, g, b, v = 1;
    if (h < 0.05) { // ocean threshold matches navigation, so visible land is traversable
      const deep = clamp(-h / 7, 0, 1);
      r = 63 - 45 * deep; g = 169 - 105 * deep; b = 184 - 115 * deep;
      if (h > -0.45) { r = 232; g = 242; b = 246; } // crisp coastline highlight
    } else if (h < 1.2) { r = 200; g = 180; b = 125; }        // beach
    else if (h > 8.5) { r = 150; g = 150; b = 148; v = 0.85 + vnoise(x * 0.05, z * 0.05) * 0.3; }
    else if (h > 6) { r = 90; g = 115; b = 75; v = 0.85 + vnoise(x * 0.05, z * 0.05) * 0.3; }
    else { r = 100; g = 135; b = 80; v = 0.85 + vnoise(x * 0.05, z * 0.05) * 0.3; }
    const i = (py * 320 + px) * 4;
    img.data[i] = r * v; img.data[i + 1] = g * v; img.data[i + 2] = b * v; img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
}
function drawMinimap() {
  const cv = $('#minimap');
  const ctx = cv.getContext('2d');
  const W = cv.width, H = cv.height;
  if (!mmTerrain) buildMinimapTerrain();
  ctx.drawImage(mmTerrain, 0, 0, W, H);
  const toPx = (x, z) => [(x / MAP_SIZE + 0.5) * W, (z / MAP_SIZE + 0.5) * H];
  // deposits
  for (const d of G.deposits) {
    const [px, py] = toPx(d.x, d.z);
    ctx.fillStyle = '#' + d.def.color.toString(16).padStart(6, '0');
    ctx.fillRect(px - 1.5, py - 1.5, 3, 3);
  }
  // buildings
  for (const b of G.buildings) {
    if (b.dead) continue;
    const [px, py] = toPx(b.x, b.z);
    ctx.fillStyle = G.nations[b.owner].css;
    const s = b.key === 'hq' ? 6 : b.key === 'cityCenter' ? 5 : b.key === 'villageCenter' ? 4 : 3.5;
    ctx.fillRect(px - s / 2, py - s / 2, s, s);
  }
  // units — enemy units only visible with Satellite Recon
  for (const u of G.units) {
    if (u.dead) continue;
    if (u.owner !== 0 && !G.discovered.satelliteRecon) continue;
    const [px, py] = toPx(u.x, u.z);
    ctx.fillStyle = G.nations[u.owner].css;
    ctx.fillRect(px - 1, py - 1, 2.2, 2.2);
  }
  // territory tint
  if (TERRITORY.owner) {
    ctx.globalAlpha = 0.3;
    const cw = W / TERRITORY.cols, ch = H / TERRITORY.rows;
    for (let cz = 0; cz < TERRITORY.rows; cz++) {
      for (let cx2 = 0; cx2 < TERRITORY.cols; cx2++) {
        const idx = cz * TERRITORY.cols + cx2;
        const o = TERRITORY.owner[idx];
        if (o < 0) continue;
        ctx.fillStyle = TERRITORY.contested && TERRITORY.contested[idx] ? '#ffe08a' : G.nations[o].css;
        ctx.globalAlpha = TERRITORY.contested && TERRITORY.contested[idx]
          ? 0.48
          : 0.16 + clamp((TERRITORY.control ? TERRITORY.control[idx] : 45) / 100, 0, 1) * 0.22;
        ctx.fillRect(cx2 * cw, cz * ch, cw + 0.5, ch + 0.5);
      }
    }
    ctx.globalAlpha = 1;
  }
  // camera frustum box (approx)
  const [cx, cy] = toPx(camFocus.x, camFocus.z);
  ctx.strokeStyle = 'rgba(255,255,255,.8)';
  const vw = camDist * 1.1 / MAP_SIZE * W, vh = camDist * 0.8 / MAP_SIZE * H;
  ctx.strokeRect(cx - vw / 2, cy - vh / 2, vw, vh);
}

/* ---------------- window & HUD wiring ---------------- */
function initUI() {
  $$('.window').forEach(makeDraggable);
  $$('.win-close').forEach(b => b.onclick = () => b.closest('.window').classList.remove('open'));
  $$('.side-btn').forEach(b => b.onclick = () => toggleWindow(b.dataset.win));
  $$('.btab').forEach(b => b.onclick = () => {
    $$('.btab').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    buildCat = b.dataset.cat;
    renderBuildPanel();
  });
  $('#btn-pause').onclick = () => togglePause();
  $('#btn-menu').onclick = () => togglePause(true);
  $('#btn-speed').onclick = () => {
    // 0.5x lets slow-burn empire builders savor the campaign
    const steps = [0.5, 1, 2, 3];
    G.speed = steps[(steps.indexOf(G.speed) + 1) % steps.length];
    $('#btn-speed').textContent = G.speed + 'x';
  };
  $('#btn-resume').onclick = () => togglePause(false);
  $('#btn-restart').onclick = () => location.reload();
  $('#btn-again').onclick = () => location.reload();

  // menu setup
  $$('.diff-btn').forEach(b => b.onclick = () => {
    $$('.diff-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.difficulty = b.dataset.diff;
  });
  $$('.gfx-btn').forEach(b => b.onclick = () => {
    $$('.gfx-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.graphics = b.dataset.gfx;
    G.gfxHigh = G.graphics !== 'low';
  });
  $$('.gov-btn').forEach(b => b.onclick = () => {
    $$('.gov-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.gov.form = b.dataset.gov;
    const d = $('#gov-desc');
    if (d) d.textContent = GOVERNMENTS[b.dataset.gov].desc;
  });
  $$('.map-btn').forEach(b => b.onclick = () => {
    $$('.map-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.mapStyle = b.dataset.map;
    const d = $('#map-desc');
    if (d) d.textContent = MAP_STYLES[b.dataset.map].desc;
  });
  $$('.size-btn').forEach(b => b.onclick = () => {
    $$('.size-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.mapSize = b.dataset.size;
  });
  $$('.corner-btn').forEach(b => b.onclick = () => {
    $$('.corner-btn').forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    G.startCorner = +b.dataset.corner;
  });
  $('#btn-start').onclick = startGame;

  // minimap navigation
  const mm = $('#minimap');
  const mmNav = e => {
    const r = mm.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width - 0.5) * MAP_SIZE;
    const z = ((e.clientY - r.top) / r.height - 0.5) * MAP_SIZE;
    camFocus.x = clamp(x, -HALF_MAP, HALF_MAP);
    camFocus.z = clamp(z, -HALF_MAP, HALF_MAP);
  };
  mm.addEventListener('pointerdown', e => { mmNav(e); mm.setPointerCapture(e.pointerId); mm._drag = true; });
  mm.addEventListener('pointermove', e => { if (mm._drag) mmNav(e); });
  mm.addEventListener('pointerup', e => { mm._drag = false; try { mm.releasePointerCapture(e.pointerId); } catch (_) {} });
}

function togglePause(force) {
  const want = force !== undefined ? force : !G.paused;
  if (G.gameOver || !G.started) return;
  G.paused = want;
  $('#pause-overlay').classList.toggle('hidden', !want);
}

function showEnd(victory, text) {
  G.gameOver = true; G.paused = true;
  $('#end-title').textContent = victory ? '🏆 VICTORY' : '💀 DEFEAT';
  $('#end-title').style.color = victory ? 'var(--gold)' : 'var(--danger)';
  $('#end-text').textContent = text || (victory
    ? 'Every rival capital lies in ruins. The world is yours — history will remember your dominion.'
    : 'Your Headquarters has fallen. Your nation dissolves into the pages of history.');
  $('#end-overlay').classList.remove('hidden');
}

function onHQDestroyed(owner) {
  const nat = G.nations[owner];
  nat.defeated = true;
  // remove all their stuff
  for (const u of G.units) if (u.owner === owner && !u.dead) killEntity(u);
  for (const b of G.buildings) if (b.owner === owner && !b.dead && b.key !== 'hq') killEntity(b);
  if (owner === 0) { showEnd(false); return; }
  notify(`🏳️ ${nat.name} has been ELIMINATED!`, 'good', 8);
  if (G.nations.every((n, i) => i === 0 || n.defeated)) showEnd(true);
}
