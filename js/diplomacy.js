'use strict';
/* ============================================================
   Diplomacy: relations, treaties, trade, espionage
   ============================================================ */

function initDiplomacy() {
  const n = G.nations.length;
  G.diplo = {
    score: Array.from({ length: n }, () => new Array(n).fill(0)),
    war: Array.from({ length: n }, () => new Array(n).fill(false)),
    alliance: Array.from({ length: n }, () => new Array(n).fill(false)),
    defensePact: Array.from({ length: n }, () => new Array(n).fill(false)),
    pact: Array.from({ length: n }, () => new Array(n).fill(false)),
    embassy: Array.from({ length: n }, () => new Array(n).fill(false)),
    nap: Array.from({ length: n }, () => new Array(n).fill(false)),
    sanction: Array.from({ length: n }, () => new Array(n).fill(false)),
  };
  // seed some starting flavor between AI nations
  for (let a = 0; a < n; a++) for (let b = a + 1; b < n; b++) {
    const s = Math.floor((Math.random() - 0.4) * 50);
    G.diplo.score[a][b] = G.diplo.score[b][a] = s;
  }
  G.spy.network = new Array(n).fill(0);
  G.spy.heat = new Array(n).fill(0);
  G.spy.lastReport = new Array(n).fill(null);
}

function relScore(a, b) { return G.diplo.score[a][b]; }
function isAtWar(a, b) { return a !== b && G.diplo.war[a][b]; }
function isAllied(a, b) { return a !== b && G.diplo.alliance[a][b]; }
function hasDefensePact(a, b) { return a !== b && G.diplo.defensePact[a][b]; }
function hasPact(a, b) { return a !== b && G.diplo.pact[a][b]; }
function hasEmbassy(a, b) { return a !== b && G.diplo.embassy[a][b]; }
function hasNap(a, b) { return a !== b && G.diplo.nap[a][b]; }
function hasSanction(a, b) { return a !== b && G.diplo.sanction[a][b]; }

function changeRel(a, b, delta) {
  const s = clamp(G.diplo.score[a][b] + delta, -100, 100);
  G.diplo.score[a][b] = G.diplo.score[b][a] = s;
}

function refreshStateWindows(...ids) {
  refreshWindows();
  if (typeof renderWindow !== 'function') return;
  for (const id of ids) {
    const win = document.getElementById(id);
    if (win && win.classList.contains('open')) renderWindow(id);
  }
}

function ensureWar(a, b) {
  if (a === b || G.diplo.war[a][b]) return;
  declareWar(a, b, true);
}

function declareWar(a, b, silent = false) {
  if (a === b || G.diplo.war[a][b]) return;
  const brokeNap = hasNap(a, b);
  G.diplo.war[a][b] = G.diplo.war[b][a] = true;
  G.diplo.alliance[a][b] = G.diplo.alliance[b][a] = false;
  G.diplo.defensePact[a][b] = G.diplo.defensePact[b][a] = false;
  G.diplo.pact[a][b] = G.diplo.pact[b][a] = false;
  G.diplo.nap[a][b] = G.diplo.nap[b][a] = false;
  G.diplo.sanction[a][b] = G.diplo.sanction[b][a] = false;
  G.diplo.score[a][b] = G.diplo.score[b][a] = -100;
  const A = G.nations[a].name, B = G.nations[b].name;
  if (brokeNap && (a === 0 || b === 0)) {
    notify('A non-aggression pact was broken. Neutral nations lose trust in the betrayer.', 'bad', 7);
    const betrayer = a;
    for (let i = 1; i < G.nations.length; i++) {
      if (i !== betrayer && !G.nations[i].defeated) changeRel(betrayer, i, -8);
    }
  }
  if (a === 0 || b === 0) {
    notify(`⚔️ WAR! ${A} and ${B} are now at war!`, 'bad', 8);
    // allies may join
    for (let i = 1; i < G.nations.length; i++) {
      const enemy = a === 0 ? b : a;
      if (i !== enemy && isAllied(enemy, i) && !isAtWar(0, i) && Math.random() < 0.5) {
        setTimeout(() => declareWar(0, i), 3000);
      }
      const aggressor = a;
      const defender = b;
      if (i !== aggressor && i !== defender && hasDefensePact(defender, i) && !isAtWar(i, aggressor)) {
        setTimeout(() => declareWar(i, aggressor), 1500);
      }
    }
  } else if (!silent) {
    notify(`🌍 World news: ${A} declared war on ${B}.`, 'warn', 7);
  }
}

function offerPeace(other) {
  // AI accepts peace more readily if it is losing or naturally passive
  const nat = G.nations[other];
  const theirArmy = G.units.filter(u => u.owner === other && !u.dead).length;
  const myArmy = G.units.filter(u => u.owner === 0 && !u.dead && u.def.dmg > 0).length;
  const chance = clamp(0.35 + (myArmy - theirArmy) * 0.04 + (1 - DIFF().aggression) * 0.3, 0.05, 0.9);
  if (Math.random() < chance) {
    G.diplo.war[0][other] = G.diplo.war[other][0] = false;
    G.diplo.score[0][other] = G.diplo.score[other][0] = -30;
    notify(`🕊️ ${nat.name} accepted your peace offer. The guns fall silent.`, 'good', 7);
  } else {
    notify(`${nat.name} rejected your peace offer. The war continues.`, 'warn');
  }
  refreshStateWindows('win-diplomacy');
}

function proposeAlliance(other) {
  if (relScore(0, other) < 55) { notify('They need a relation of at least +55 to consider an alliance.', 'warn'); return; }
  if (Math.random() < 0.75) {
    G.diplo.alliance[0][other] = G.diplo.alliance[other][0] = true;
    changeRel(0, other, 15);
    notify(`🤝 Alliance formed with ${G.nations[other].name}! They may join your wars.`, 'good', 7);
  } else notify(`${G.nations[other].name} politely declined the alliance — for now.`, 'warn');
  refreshStateWindows('win-diplomacy');
}

function openEmbassy(other) {
  if (isAtWar(0, other)) { notify('You cannot open an embassy during war.', 'warn'); return; }
  if (hasEmbassy(0, other)) return;
  if (relScore(0, other) < -30) { notify('Relations are too hostile for an embassy.', 'warn'); return; }
  if (G.res.money < 500) { notify('Opening an embassy costs $500.', 'warn'); return; }
  G.res.money -= 500;
  G.diplo.embassy[0][other] = G.diplo.embassy[other][0] = true;
  changeRel(0, other, 7);
  notify(`Embassy opened with ${G.nations[other].name}. Relations will warm over time and intelligence improves.`, 'good', 8);
  refreshStateWindows('win-diplomacy', 'win-espionage');
}

function expelEmbassy(other) {
  if (!hasEmbassy(0, other)) return;
  G.diplo.embassy[0][other] = G.diplo.embassy[other][0] = false;
  changeRel(0, other, -12);
  notify(`You expelled ${G.nations[other].name}'s diplomats. Relations suffer.`, 'warn', 7);
  refreshStateWindows('win-diplomacy', 'win-espionage');
}

function sendAid(other) {
  if (isAtWar(0, other)) { notify('Aid cannot be sent during war.', 'warn'); return; }
  if (G.res.money < 300 || G.res.food < 80) { notify('Aid package costs $300 and 80 food.', 'warn'); return; }
  G.res.money -= 300; G.res.food -= 80;
  G.nations[other].money += 420;
  changeRel(0, other, hasEmbassy(0, other) ? 16 : 10);
  notify(`Aid package delivered to ${G.nations[other].name}. They remember who helped them.`, 'good', 7);
  refreshStateWindows('win-diplomacy');
}

function proposeDefensePact(other) {
  if (isAtWar(0, other)) { notify('You cannot sign a defense pact during war.', 'warn'); return; }
  if (hasDefensePact(0, other)) return;
  if (relScore(0, other) < 35) { notify('Relations need to be at least +35 for a defense pact.', 'warn'); return; }
  const chance = clamp(0.35 + relScore(0, other) / 130 + (hasEmbassy(0, other) ? 0.1 : 0), 0.15, 0.9);
  if (Math.random() < chance) {
    G.diplo.defensePact[0][other] = G.diplo.defensePact[other][0] = true;
    changeRel(0, other, 10);
    notify(`Defense pact signed with ${G.nations[other].name}. If either side is attacked, the other may join.`, 'good', 8);
  } else {
    changeRel(0, other, -5);
    notify(`${G.nations[other].name} declines the defense pact.`, 'warn', 6);
  }
  refreshStateWindows('win-diplomacy');
}

function breakDefensePact(other) {
  if (!hasDefensePact(0, other)) return;
  G.diplo.defensePact[0][other] = G.diplo.defensePact[other][0] = false;
  changeRel(0, other, -18);
  notify(`Defense pact with ${G.nations[other].name} cancelled.`, 'warn', 7);
  refreshStateWindows('win-diplomacy');
}

function proposePact(other) {
  if (relScore(0, other) < 20) { notify('Relations too cold for a trade pact (+20 needed).', 'warn'); return; }
  G.diplo.pact[0][other] = G.diplo.pact[other][0] = true;
  changeRel(0, other, 10);
  notify(`📜 Trade pact signed with ${G.nations[other].name}: +$4/s for both sides.`, 'good', 6);
  refreshStateWindows('win-diplomacy');
}

function proposeNap(other) {
  if (isAtWar(0, other)) { notify('You cannot sign a non-aggression pact during war.', 'warn'); return; }
  if (hasNap(0, other)) { notify('A non-aggression pact is already active.', 'warn'); return; }
  if (relScore(0, other) < 10) { notify('Relations need to be at least +10 for a non-aggression pact.', 'warn'); return; }
  const chance = clamp(0.45 + relScore(0, other) / 120, 0.25, 0.9);
  if (Math.random() < chance) {
    G.diplo.nap[0][other] = G.diplo.nap[other][0] = true;
    changeRel(0, other, 8);
    notify(`Non-aggression pact signed with ${G.nations[other].name}. Both sides promise not to start a war.`, 'good', 7);
  } else {
    changeRel(0, other, -3);
    notify(`${G.nations[other].name} refuses the non-aggression pact.`, 'warn', 6);
  }
  refreshStateWindows('win-diplomacy');
}

function breakNap(other) {
  if (!hasNap(0, other)) return;
  G.diplo.nap[0][other] = G.diplo.nap[other][0] = false;
  changeRel(0, other, -15);
  notify(`You cancelled the non-aggression pact with ${G.nations[other].name}.`, 'warn', 6);
  refreshStateWindows('win-diplomacy');
}

function imposeSanctions(other) {
  if (isAtWar(0, other)) { notify('Sanctions are pointless during open war.', 'warn'); return; }
  if (hasSanction(0, other)) return;
  G.diplo.sanction[0][other] = true;
  G.diplo.pact[0][other] = G.diplo.pact[other][0] = false;
  changeRel(0, other, -20);
  notify(`Sanctions imposed on ${G.nations[other].name}: their economy weakens, but relations suffer.`, 'warn', 7);
  refreshStateWindows('win-diplomacy');
}

function liftSanctions(other) {
  if (!hasSanction(0, other)) return;
  G.diplo.sanction[0][other] = false;
  changeRel(0, other, 8);
  notify(`Sanctions lifted from ${G.nations[other].name}.`, 'good', 6);
  refreshStateWindows('win-diplomacy');
}

function sendGift(other) {
  if (G.res.money < 250) { notify('A meaningful gift costs $250.', 'warn'); return; }
  G.res.money -= 250;
  G.nations[other].money += 250;
  const diplomatBonus = (LEADER_TRAITS[G.gov.leader.trait].diplo || fxv('warmRelations')) ? 2 : 1;
  changeRel(0, other, 9 * diplomatBonus);
  notify(`🎁 Gift sent to ${G.nations[other].name}. Relations improved${diplomatBonus > 1 ? ' (Diplomat leader: double effect)' : ''}.`, 'good');
  refreshStateWindows('win-diplomacy');
}

/* ---------------- power diplomacy ---------------- */
function armyStrength(id) {
  return G.units.filter(u => u.owner === id && !u.dead && u.def.dmg > 0)
    .reduce((s, u) => s + u.def.hp * 0.01 + u.def.dmg, 0);
}

/* Demand Tribute: intimidate a weaker nation into paying — or make an enemy */
function demandTribute(other) {
  if (isAtWar(0, other)) { notify('You are already at war — take it by force.', 'warn'); return; }
  const nat = G.nations[other];
  const mine = armyStrength(0), theirs = armyStrength(other) + 10;
  const ratio = mine / theirs;
  const chance = clamp(0.15 + (ratio - 1) * 0.35 - relScore(0, other) / 400, 0.05, 0.85);
  if (Math.random() < chance) {
    const amt = Math.min(nat.money, 300 + Math.floor(Math.random() * 400));
    nat.money -= amt; G.res.money += amt;
    changeRel(0, other, -15);
    notify(`😤 ${nat.name} pays $${amt} in tribute — and will remember this humiliation.`, 'good', 7);
  } else {
    changeRel(0, other, -25);
    notify(`🔥 ${nat.name} REFUSES your demand! Relations crash.`, 'bad', 7);
    if (Math.random() < 0.3) declareWar(0, other);
  }
  refreshStateWindows('win-diplomacy');
}

/* Joint War: ask an ally to join you against a target */
function requestJointWar(ally, target) {
  if (!isAllied(0, ally)) { notify('Only allies join joint wars.', 'warn'); return; }
  if (ally === target || G.nations[target].defeated) return;
  const chance = clamp(relScore(0, ally) / 120 + (relScore(ally, target) < 0 ? 0.3 : -0.2), 0.1, 0.9);
  if (Math.random() < chance) {
    declareWar(ally, target);
    if (!isAtWar(0, target)) declareWar(0, target);
    notify(`⚔️ ${G.nations[ally].name} honours the alliance and declares war on ${G.nations[target].name}!`, 'good', 8);
  } else {
    changeRel(0, ally, -8);
    notify(`${G.nations[ally].name} declines to join your war. The alliance strains.`, 'warn', 6);
  }
  refreshStateWindows('win-diplomacy');
}

function breakAlliance(other) {
  if (!isAllied(0, other)) return;
  G.diplo.alliance[0][other] = G.diplo.alliance[other][0] = false;
  changeRel(0, other, -30);
  notify(`💔 You broke the alliance with ${G.nations[other].name}. They are furious.`, 'warn', 7);
  refreshStateWindows('win-diplomacy');
}

function diplomacyFactors(other) {
  const out = [];
  const s = relScore(0, other);
  out.push(`Base relation: ${s > 0 ? '+' : ''}${Math.round(s)}`);
  if (hasEmbassy(0, other)) out.push('Embassy: relations warm over time, spy success +5%.');
  if (hasPact(0, other)) out.push('Trade pact: both economies profit every 10 seconds.');
  if (hasNap(0, other)) out.push('Non-aggression pact: AI avoids starting wars against this nation.');
  if (hasDefensePact(0, other)) out.push('Defense pact: may join if either side is attacked.');
  if (hasSanction(0, other)) out.push('Sanctions: their economy -15%, relations damaged.');
  if (isAllied(0, other)) out.push('Alliance: high trust, may join wars.');
  const ratio = armyStrength(0) / Math.max(10, armyStrength(other));
  out.push(`Power balance: ${ratio >= 1 ? 'you look stronger' : 'they look stronger'} (x${ratio.toFixed(2)}).`);
  return out;
}

/* ---------------- trade deals ---------------- */
function evaluateTrade(other, giveRes, giveAmt, getRes, getAmt) {
  const giveVal = giveAmt * RES_VALUE[giveRes];
  const getVal = getAmt * RES_VALUE[getRes];
  if (getVal <= 0) return 1;
  const fairness = giveVal / getVal; // >1 means good for them
  const relBonus = relScore(0, other) / 200; // -0.5..+0.5
  return clamp(fairness - 1 + relBonus + 0.15, 0, 1);
}

function proposeTrade(other, giveRes, giveAmt, getRes, getAmt) {
  if (isAtWar(0, other)) { notify('You cannot trade with a nation you are at war with.', 'warn'); return; }
  if (G.res[giveRes] < giveAmt) { notify(`You do not have ${giveAmt} ${RES_META[giveRes].name}.`, 'warn'); return; }
  const nat = G.nations[other];
  const accept = Math.random() < evaluateTrade(other, giveRes, giveAmt, getRes, getAmt);
  if (accept) {
    G.res[giveRes] -= giveAmt;
    G.res[getRes] += getAmt;
    changeRel(0, other, 5);
    notify(`✅ ${nat.name} accepted: you sent ${giveAmt} ${RES_META[giveRes].name} for ${getAmt} ${RES_META[getRes].name}.`, 'good', 6);
  } else {
    changeRel(0, other, -2);
    notify(`❌ ${nat.name} rejected the deal. Sweeten the pot or improve relations.`, 'warn');
  }
}

/* AI sometimes offers the player a trade */
function maybeAIOffer() {
  const candidates = G.nations.filter((n, i) => i !== 0 && !n.defeated && !isAtWar(0, i) && relScore(0, i) > -20);
  if (!candidates.length) return;
  const nat = candidates[Math.floor(Math.random() * candidates.length)];
  const i = G.nations.indexOf(nat);
  if (!canAIContact(i)) return;
  // they offer a resource for money, slightly favorable to the player — and in
  // a quantity worth stopping for, since these now arrive rarely
  const resPool = ['oil', 'iron', 'silicon', 'uranium', 'food'];
  const r = resPool[Math.floor(Math.random() * resPool.length)];
  const amt = 60 + Math.floor(Math.random() * 90);
  const price = Math.floor(amt * RES_VALUE[r] * (0.75 + Math.random() * 0.3));
  markAIContact(i);
  notifyAction(
    `📨 ${nat.name} offers you ${amt} ${RES_META[r].icon}${RES_META[r].name} for 💰${price}.`,
    [
      { label: 'Accept', fn: () => {
          if (G.res.money < price) { notify('You cannot afford this deal.', 'warn'); return; }
          G.res.money -= price; G.res[r] += amt; changeRel(0, i, 4);
          notify(`Deal closed with ${nat.name}.`, 'good');
        } },
      { label: 'Decline', fn: () => { changeRel(0, i, -1); } },
    ], 20);
}

/* ============================================================
   WORLD TRADE ENGINE — drifting market prices, standing
   import/export routes, instant market deals. A nation that
   neither imports nor exports withers (autarky penalty).
   ============================================================ */
function tradePrice(res) {
  return TRADE_PRICE[res] * ((G.market.mult && G.market.mult[res]) || 1);
}
function routeCap() {
  const pacts = G.nations.filter((n, i) => i > 0 && !n.defeated && hasPact(0, i)).length;
  const contracts = pacts + Math.min(playerBuildingCount('market'), 2) + fxv('tradeRoutes');
  const berths = playerBuildingCount('port') * TRADE_ROUTES_PER_PORT;
  return Math.max(0, Math.min(contracts, berths));
}
function tradeRouteRisk() {
  const escorts = G.units.filter(u => u.owner === 0 && !u.dead && u.def.naval && u.def.dmg > 0).length;
  return clamp(0.08 - escorts * 0.015, 0.015, 0.08);
}
let TRADE_ROUTE_ID = 1;

function createTradeRoute(nationId, res, dir, qty) {
  const nat = G.nations[nationId];
  if (!nat || nat.defeated) return;
  if (!playerBuildingCount('port')) { notify('Overseas trade requires a completed Commercial Port.', 'warn'); return; }
  if (!hasPact(0, nationId)) { notify('Trade routes require a Trade Pact with that nation.', 'warn'); return; }
  if (isAtWar(0, nationId)) { notify('You cannot trade with a nation you are at war with.', 'warn'); return; }
  if (G.trade.routes.length >= routeCap()) {
    notify(`Route limit reached (${routeCap()}). Ports provide 2 berths each; Trade Pacts and Markets provide commercial contracts.`, 'warn');
    return;
  }
  G.trade.routes.push({ id: TRADE_ROUTE_ID++, nation: nationId, res, dir, qty: +qty, flow: 0, total: 0, shipment: null, status: 'Awaiting cargo' });
  notify(`📦 Trade route opened: ${dir === 'export' ? 'exporting' : 'importing'} ${RES_META[res].icon} ${RES_META[res].name} ${dir === 'export' ? 'to' : 'from'} ${nat.name}.`, 'good', 6);
  refreshStateWindows('win-trade');
}
function cancelTradeRoute(id) {
  const i = G.trade.routes.findIndex(r => r.id === id);
  if (i >= 0) {
    const r = G.trade.routes[i];
    G.trade.routes.splice(i, 1);
    if (r.shipment) G.trade.lost = (G.trade.lost || 0) + 1;
    notify(`Trade route with ${G.nations[r.nation].name} closed${r.shipment ? '; cargo already at sea was forfeited' : ''}.`, '', 5);
    refreshStateWindows('win-trade');
  }
}

/* instant world-market deal (requires a Market building) */
function instantTrade(res, qty, dir) {
  if (!playerBuildingCount('market')) { notify('Instant market deals require a Market building.', 'warn'); return; }
  const price = tradePrice(res);
  if (dir === 'sell') {
    if (G.res[res] < qty) { notify(`Not enough ${RES_META[res].name} to sell.`, 'warn'); return; }
    G.res[res] -= qty;
    G.res.money += Math.round(qty * price * TRADE_INSTANT_SELL);
  } else {
    const cost = Math.round(qty * price * TRADE_INSTANT_BUY);
    if (G.res.money < cost) { notify(`Buying ${qty} ${RES_META[res].name} costs $${cost}.`, 'warn'); return; }
    const cap = (G.city.caps && G.city.caps[res]) || Infinity;
    if (G.res[res] + qty > cap) { notify(`Not enough ${RES_META[res].name} storage for this purchase.`, 'warn'); return; }
    G.res.money -= cost;
    G.res[res] += qty;
  }
  refreshStateWindows('win-trade');
}

/* runs inside diploTick (every 10s): prices drift, routes flow */
function marketTick() {
  for (const res of Object.keys(TRADE_PRICE)) {
    const m = G.market.mult[res] || 1;
    G.market.mult[res] = clamp(m * (0.97 + Math.random() * 0.06), 0.55, 1.9);
  }
  while (G.trade.routes.length > routeCap()) {
    const r = G.trade.routes.pop();
    if (r.shipment) G.trade.lost = (G.trade.lost || 0) + 1;
    notify(`⚓ The ${G.nations[r.nation].name} route closed because your port network lost capacity${r.shipment ? '; its cargo was lost' : ''}.`, 'bad', 8);
  }
  for (let i = G.trade.routes.length - 1; i >= 0; i--) {
    const r = G.trade.routes[i];
    const nat = G.nations[r.nation];
    if (!nat || nat.defeated || isAtWar(0, r.nation) || hasSanction(0, r.nation) || hasSanction(r.nation, 0) || !hasPact(0, r.nation)) {
      if (r.shipment) G.trade.lost = (G.trade.lost || 0) + 1;
      G.trade.routes.splice(i, 1);
      notify(`🚫 Trade route with ${nat ? nat.name : '?'} collapsed${r.shipment ? ' — the cargo at sea was lost' : ''}.`, 'warn', 6);
      continue;
    }
    if (r.shipment) {
      r.shipment.eta -= 10;
      r.status = `At sea — ${Math.max(0, r.shipment.eta)}s`;
      if (r.shipment.eta <= 0) {
        const cargo = r.shipment;
        r.shipment = null;
        if (Math.random() < tradeRouteRisk()) {
          G.trade.lost = (G.trade.lost || 0) + 1;
          r.flow = 0;
          r.status = 'Shipment lost — reloading';
          notify(`🏴‍☠️ A ${RES_META[r.res].name} shipment on the ${nat.name} route was lost at sea. Naval escorts reduce this risk.`, 'bad', 8);
        } else {
          if (r.dir === 'export') {
            G.res.money += cargo.value;
            nat.money = Math.max(0, nat.money - cargo.value * 0.5);
            r.flow = cargo.value;
          } else {
            const cap = (G.city.caps && G.city.caps[r.res]) || Infinity;
            G.res[r.res] = Math.min(cap, G.res[r.res] + cargo.qty);
            nat.money += cargo.value * 0.5;
            r.flow = -cargo.value;
          }
          r.total += cargo.value;
          G.trade.delivered = (G.trade.delivered || 0) + 1;
          r.status = 'Delivered — reloading';
          changeRel(0, r.nation, 0.8);
        }
      }
      continue;
    }

    const price = tradePrice(r.res);
    const value = Math.round(r.qty * price * (r.dir === 'import' ? TRADE_IMPORT_MARKUP : 1));
    if (r.dir === 'export' && G.res[r.res] >= r.qty) {
      G.res[r.res] -= r.qty;
      r.shipment = { qty: r.qty, value, eta: TRADE_VOYAGE_SECONDS };
      r.status = `Outbound — ${TRADE_VOYAGE_SECONDS}s`;
    } else if (r.dir === 'import' && G.res.money >= value) {
      const cap = (G.city.caps && G.city.caps[r.res]) || Infinity;
      if (G.res[r.res] + r.qty <= cap) {
        G.res.money -= value;
        r.shipment = { qty: r.qty, value, eta: TRADE_VOYAGE_SECONDS };
        r.status = `Inbound — ${TRADE_VOYAGE_SECONDS}s`;
      } else {
        r.flow = 0;
        r.status = 'Stalled — insufficient storage';
      }
    } else {
      r.flow = 0;
      r.status = r.dir === 'export' ? 'Stalled — insufficient stock' : 'Stalled — insufficient funds';
    }
  }
}

/* ============================================================
   INTELLIGENCE ENGINE — every operation produces knowledge.
   Intel per nation (0-100) unlocks deeper information in the
   Diplomacy window, gives advance warning of attacks, and each
   unique report type permanently sharpens future ops.
   ============================================================ */
function addIntelReport(nation, type, text, amt) {
  G.spy.intel[nation] = clamp((G.spy.intel[nation] || 0) + amt, 0, 100);
  if (!G.spy.types[nation]) G.spy.types[nation] = {};
  G.spy.types[nation][type] = true;
  G.spy.reports.unshift({ t: G.time, nation, text });
  if (G.spy.reports.length > 25) G.spy.reports.pop();
}
function intelLevel(nation) { return Math.round(G.spy.intel[nation] || 0); }
/* what each intel threshold reveals */
const INTEL_TIERS = [
  { at: 10, label: 'Treasury & building count' },
  { at: 25, label: 'Army strength estimate' },
  { at: 40, label: 'Their wars, allies & pacts' },
  { at: 60, label: 'Advance warning of attacks on you' },
];

/* ---------------- espionage: named field agents ---------------- */
let AGENT_ID = 1;
function newAgent() {
  const used = new Set(G.agentRoster.map(a => a.name));
  const free = AGENT_NAMES.filter(n => !used.has(n));
  const name = free.length ? free[Math.floor(Math.random() * free.length)]
    : AGENT_NAMES[Math.floor(Math.random() * AGENT_NAMES.length)] + '-' + AGENT_ID;
  return { id: AGENT_ID++, name, skill: 1, xp: 0, ops: 0, status: 'ready', capturedBy: null };
}
function readyAgents() { return G.agentRoster.filter(a => a.status === 'ready'); }
function agentRank(a) { return AGENT_RANKS[a.skill - 1] || AGENT_RANKS[0]; }
function agentGainXp(agent) {
  agent.xp++; agent.ops++;
  const newSkill = 1 + AGENT_XP_LEVELS.filter(t => agent.xp >= t).length;
  if (newSkill > agent.skill) {
    agent.skill = newSkill;
    notify(`🎖️ Agent "${agent.name}" promoted to ${agentRank(agent)} (skill ${agent.skill}/5 — +${Math.round((agent.skill - 1) * AGENT_SKILL_BONUS * 100)}% op success).`, 'good', 7);
  }
}

function recruitAgent() {
  if (!playerBuildingCount('intelAgency')) { notify('Build an Intelligence Agency first.', 'warn'); return; }
  const cost = agentRecruitCost();
  if (G.res.money < cost) { notify(`Recruiting the next agent costs $${cost}.`, 'warn'); return; }
  G.res.money -= cost;
  const a = newAgent();
  G.agentRoster.push(a);
  notify(`🕵️ Agent "${a.name}" joins the service. Ready agents: ${readyAgents().length}.`, 'good');
  refreshStateWindows('win-espionage');
}

function ransomAgent(agentId) {
  const a = G.agentRoster.find(x => x.id === agentId);
  if (!a || a.status !== 'captured') return;
  if (G.res.money < AGENT_RANSOM) { notify(`Buying back "${a.name}" costs $${AGENT_RANSOM}.`, 'warn'); return; }
  G.res.money -= AGENT_RANSOM;
  const captor = G.nations[a.capturedBy];
  if (captor) captor.money += AGENT_RANSOM;
  a.status = 'ready'; a.capturedBy = null;
  notify(`🔓 Agent "${a.name}" ransomed home. They remember everything — experience intact.`, 'good', 6);
  refreshStateWindows('win-espionage');
}

/* enemy intelligence services strike back — your agency & idle agents defend */
function enemySpyAttempt() {
  const hostiles = G.nations.map((n, i) => i).filter(i =>
    i > 0 && !G.nations[i].defeated && (isAtWar(0, i) || relScore(0, i) < -25));
  if (!hostiles.length) return;
  const attacker = hostiles[Math.floor(Math.random() * hostiles.length)];
  const nat = G.nations[attacker];
  let defense = 0.25 + (playerBuildingCount('intelAgency') ? 0.18 : 0)
    + readyAgents().length * 0.05 + G.tech.espionage * 0.06 + govMod('spyPct');
  if (Math.random() < clamp(defense, 0.1, 0.9)) {
    changeRel(0, attacker, -8);
    G.city.research += 40;
    addIntelReport(attacker, 'counterintel', `🛡️ Enemy agent from ${nat.name} captured and interrogated`, 8);
    notify(`🛡️ COUNTER-INTEL: an enemy agent from ${nat.name} was caught! Interrogation yields +40 research and intel.`, 'good', 7);
  } else {
    const roll = Math.random();
    if (roll < 0.4) {
      const amt = Math.min(G.res.money, 200 + Math.floor(Math.random() * 300));
      G.res.money -= amt; nat.money += amt;
      notify(`🚨 ${nat.name} agents siphoned $${amt} from your treasury! Build up counter-intelligence.`, 'bad', 7);
    } else if (roll < 0.7) {
      G.city.research = Math.max(0, G.city.research - 70);
      notify(`🚨 ${nat.name} stole your research data (-70 research)!`, 'bad', 7);
    } else {
      const targets = G.buildings.filter(b => b.owner === 0 && !b.dead && b.built && b.key !== 'hq');
      if (targets.length) {
        const t = targets[Math.floor(Math.random() * targets.length)];
        dealDamage(t, t.maxHp * 0.4, null);
        spawnExplosion(t.x, t.mesh.position.y + 2, t.z, t.def.size * 0.8);
        notify(`🚨 SABOTAGE! ${nat.name} operatives bombed your ${t.def.name}!`, 'bad', 7);
      }
    }
  }
  refreshStateWindows('win-espionage');
}

function opSuccessChance(opKey, targetId) {
  const op = SPY_OPS[opKey];
  let p = op.base;
  p += G.tech.espionage * 0.08;
  p += govMod('spyPct'); // leader trait bonus
  p += fxv('spyPct');    // cyber warfare & similar discoveries
  if (playerBuildingCount('intelAgency')) p += 0.10;
  if (hasEmbassy(0, targetId)) p += 0.05;
  p += (G.spy.network[targetId] || 0) * 0.006;
  p -= (G.spy.heat[targetId] || 0) * 0.004;
  // every unique kind of report you've filed on them makes the next op sharper
  p += Math.min(Object.keys(G.spy.types[targetId] || {}).length * 0.02, 0.10);
  const nat = G.nations[targetId];
  let counter = DIFF().counterSpy;
  if (nat.debuffSpymaster > G.time) counter = 0;
  p -= counter;
  return clamp(p, 0.05, 0.95);
}

function runSpyOp(opKey, targetId, person, agentId) {
  const op = SPY_OPS[opKey];
  if (!playerBuildingCount('intelAgency')) { notify('Covert operations require an Intelligence Agency.', 'warn'); return; }
  const agent = agentId ? G.agentRoster.find(a => a.id === +agentId && a.status === 'ready') : readyAgents()[0];
  if (!agent) { notify('No available agents. Recruit one at the Intelligence Agency.', 'warn'); return; }
  if (G.res.money < op.cost) { notify(`Operation requires $${op.cost}.`, 'warn'); return; }
  const nat = G.nations[targetId];
  if (nat.defeated) { notify('That nation no longer exists.', 'warn'); return; }
  if ((G.spy.network[targetId] || 0) < (op.minNetwork || 0)) {
    notify(`${op.name} requires network ${op.minNetwork}. Build your network first.`, 'warn');
    return;
  }

  G.res.money -= op.cost;
  const p = clamp(opSuccessChance(opKey, targetId) + (agent.skill - 1) * AGENT_SKILL_BONUS, 0.05, 0.97);
  const roll = Math.random();

  if (roll < p) {
    G.spy.network[targetId] = clamp((G.spy.network[targetId] || 0) + (opKey === 'buildNetwork' ? 16 : 3), 0, 100);
    G.spy.heat[targetId] = clamp((G.spy.heat[targetId] || 0) + (opKey === 'reconDossier' ? 2 : 8), 0, 100);
    // SUCCESS
    switch (opKey) {
      case 'buildNetwork': {
        notify(`Network expanded inside ${nat.name}. Infiltration is now ${Math.round(G.spy.network[targetId])}/100.`, 'good', 6);
        break;
      }
      case 'reconDossier': {
        const report = {
          time: G.time,
          army: armyStrength(targetId).toFixed(1),
          money: Math.floor(nat.money),
          buildings: G.buildings.filter(b => b.owner === targetId && !b.dead).length,
          relation: Math.round(relScore(0, targetId)),
        };
        G.spy.lastReport[targetId] = report;
        notify(`Recon dossier complete: army ${report.army}, treasury $${report.money}, buildings ${report.buildings}, relation ${report.relation}.`, 'good', 9);
        break;
      }
      case 'cyberAttack': {
        nat.debuffCyber = G.time + 90;
        for (const b of G.buildings) if (b.owner === targetId && !b.dead && b.built) b.disabledUntil = Math.max(b.disabledUntil || 0, G.time + 25);
        notify(`Cyber attack successful: ${nat.name}'s production grid is disrupted for 90 seconds.`, 'good', 7);
        break;
      }
      case 'stealFunds': {
        const amt = Math.min(nat.money, 400 + Math.floor(Math.random() * 400));
        nat.money -= amt; G.res.money += amt;
        notify(`💸 Operation success: your agent siphoned $${amt} from ${nat.name}.`, 'good', 6);
        break;
      }
      case 'stealTech': {
        G.city.research += 120;
        notify(`📁 Operation success: stolen research from ${nat.name} (+120 research).`, 'good', 6);
        break;
      }
      case 'sabotage': {
        const targets = G.buildings.filter(b => b.owner === targetId && !b.dead && b.built && b.key !== 'hq');
        if (targets.length) {
          const t = targets[Math.floor(Math.random() * targets.length)];
          dealDamage(t, t.maxHp * 0.7, null);
          spawnExplosion(t.x, t.mesh.position.y + 2, t.z, t.def.size);
          notify(`💣 Sabotage success: ${nat.name}'s ${t.def.name} is burning.`, 'good', 6);
        } else notify('Sabotage succeeded but found no valuable target.', 'warn');
        break;
      }
      case 'proxyCell': {
        nat.debuffProxy = G.time + 180;
        notify(`🎭 Proxy cell active inside ${nat.name}: their economy is disrupted for 3 minutes.`, 'good', 6);
        break;
      }
      case 'armRebels': {
        nat.debuffUnrest = G.time + 180;
        const targets = G.buildings.filter(b => b.owner === targetId && !b.dead && b.built && b.key !== 'hq');
        for (let i = 0; i < Math.min(2, targets.length); i++) {
          const t = targets[Math.floor(Math.random() * targets.length)];
          dealDamage(t, t.maxHp * 0.35, null);
          spawnExplosion(t.x, t.mesh.position.y + 2, t.z, t.def.size * 0.7);
        }
        notify(`Rebel cells armed inside ${nat.name}. Their economy and public order are shaken for 3 minutes.`, 'good', 7);
        break;
      }
      case 'falseFlag': {
        const rivals = G.nations.map((n, i) => i).filter(i => i > 0 && i !== targetId && !G.nations[i].defeated);
        const rival = rivals[Math.floor(Math.random() * rivals.length)];
        if (rival !== undefined) {
          changeRelAI(targetId, rival, -45);
          notify(`False flag planted: ${nat.name} and ${G.nations[rival].name} blame each other for the incident.`, 'good', 8);
          if (relScore(targetId, rival) < -70 && Math.random() < 0.45) declareWar(targetId, rival);
        }
        break;
      }
      case 'assassinate': {
        const name = nat.people[person];
        switch (person) {
          case 'president': {
            // decapitation: economy craters, succession chaos, forces paralyzed
            nat.debuffPresident = G.time + 240;
            nat.aiParalyzedUntil = G.time + 90;   // no attacks while leaderless
            if (nat.ai) { nat.ai.nextAttack = Math.max(nat.ai.nextAttack, 90); nat.ai.nextExpand = 90; }
            nat.money = Math.floor(nat.money * 0.6); // treasury looted in the turmoil
            // succession crisis can drag rivals in
            for (let j = 1; j < G.nations.length; j++) {
              if (j !== targetId && !G.nations[j].defeated) changeRelAI(targetId, j, -12);
            }
            notify(`💀 Head of State ${name} of ${nat.name} ASSASSINATED! Their economy collapses, forces are paralyzed for 90s, and the succession throws the nation into chaos.`, 'good', 10);
            break;
          }
          case 'general': {
            nat.debuffGeneral = G.time + 240;
            nat.aiParalyzedUntil = G.time + 60;
            // recall any in-progress attack wave — command has broken down
            for (const u of G.units) {
              if (u.owner === targetId && !u.dead && u.state === 'attackMove') { u.state = 'idle'; u.target = null; }
            }
            notify(`💀 Gen. ${name} of ${nat.name} eliminated! Their army deals -30% damage for 4 min and their offensive collapses.`, 'good', 9);
            break;
          }
          case 'scientist': {
            G.city.research += 250;
            nat.aiTech = Math.max(0, (nat.aiTech || 0) - 2); // their tech program set back
            notify(`💀 Dr. ${name} of ${nat.name} eliminated! You seize 250 research and set back their tech program.`, 'good', 9);
            break;
          }
          case 'spymaster': {
            nat.debuffSpymaster = G.time + 300;
            G.spy.network[targetId] = clamp((G.spy.network[targetId] || 0) + 20, 0, 100); // their nets go dark, yours flourish
            notify(`💀 Spymaster ${name} of ${nat.name} eliminated! Their counter-intelligence collapses for 5 min and your network deepens.`, 'good', 9);
            break;
          }
        }
        // traced?
        if (Math.random() < 0.4) {
          changeRel(0, targetId, -50);
          notify(`🔍 The assassination was traced back to you! ${nat.name} is furious.`, 'bad', 7);
          if (Math.random() < 0.5) declareWar(0, targetId);
        }
        break;
      }
    }
  } else {
    G.spy.heat[targetId] = clamp((G.spy.heat[targetId] || 0) + 14, 0, 100);
    G.spy.network[targetId] = clamp((G.spy.network[targetId] || 0) - 5, 0, 100);
    // FAILURE — the agent may be captured (skilled agents slip away more often)
    if (Math.random() < clamp(0.55 - (agent.skill - 1) * 0.07, 0.15, 0.6)) {
      agent.status = 'captured'; agent.capturedBy = targetId;
      changeRel(0, targetId, -25);
      notify(`🚨 Operation failed — Agent "${agent.name}" was CAPTURED by ${nat.name}! Pay $${AGENT_RANSOM} ransom in the Intel window, or leave them.`, 'bad', 9);
      if (opKey === 'assassinate' && Math.random() < 0.35) declareWar(0, targetId);
    } else {
      notify(`Operation failed, but Agent "${agent.name}" escaped cleanly.`, 'warn');
    }
  }
  if (roll < p) {
    agentGainXp(agent);
    // every success feeds the intelligence picture
    const intelGain = { buildNetwork: 6, reconDossier: 18, cyberAttack: 8, stealFunds: 5, stealTech: 10, sabotage: 6, proxyCell: 8, armRebels: 8, falseFlag: 6, assassinate: 12 };
    addIntelReport(targetId, opKey,
      `${op.icon || '📄'} ${op.name} in ${nat.name} — success (Agent "${agent.name}")`,
      intelGain[opKey] || 5);
  }
  refreshStateWindows('win-espionage', 'win-diplomacy');
}

/* ---------------- the diplomatic inbox ----------------
   Trade offers, foreign proposals and hostile operations each used to roll
   their own die on every 10-second tick. Independently that is one interrupting
   pop-up roughly every 25 seconds — the player spends the game dismissing
   cards instead of playing, and because every offer looks the same none of
   them register as an event.
   Everything the AI initiates now competes for ONE channel:
     · a hard cooldown between any two approaches;
     · a much longer per-nation cooldown, so one rival cannot monopolise it;
     · silence during the opening minutes, while the player is still building.
   The result is a handful of approaches per game, each of which lands. */
const AI_CONTACT_COOLDOWN = 150;   // seconds between any two AI-initiated pop-ups
const AI_NATION_COOLDOWN = 420;    // seconds before the same nation writes again
const AI_CONTACT_GRACE = 240;      // no foreign mail at all before this

function aiInbox() {
  if (!G.diplo.inbox) G.diplo.inbox = { last: -Infinity, byNation: {} };
  return G.diplo.inbox;
}
function canAIContact(nationId) {
  if (G.time < AI_CONTACT_GRACE) return false;
  const inbox = aiInbox();
  if (G.time - inbox.last < AI_CONTACT_COOLDOWN) return false;
  if (nationId !== undefined && G.time - (inbox.byNation[nationId] ?? -Infinity) < AI_NATION_COOLDOWN) return false;
  return true;
}
function markAIContact(nationId) {
  const inbox = aiInbox();
  inbox.last = G.time;
  if (nationId !== undefined) inbox.byNation[nationId] = G.time;
}

/* ---------------- periodic world diplomacy tick (every ~10s) ---------------- */
function diploTick() {
  const n = G.nations.length;
  // relation drift between AI nations + occasional AI wars/peace (world flavor)
  for (let a = 1; a < n; a++) {
    if (G.nations[a].defeated) continue;
    for (let b = a + 1; b < n; b++) {
      if (G.nations[b].defeated) continue;
      changeRelAI(a, b, (Math.random() - 0.5) * 4);
      if (!G.diplo.war[a][b] && G.diplo.score[a][b] < -75 && Math.random() < 0.05) declareWar(a, b);
      if (G.diplo.war[a][b] && Math.random() < 0.04) {
        G.diplo.war[a][b] = G.diplo.war[b][a] = false;
        G.diplo.score[a][b] = G.diplo.score[b][a] = -40;
        notify(`🌍 World news: ${G.nations[a].name} and ${G.nations[b].name} signed a ceasefire.`, 'warn', 6);
      }
    }
    // player relations drift slowly toward 0 in peacetime (Diplomat leaders warm faster)
    if (!isAtWar(0, a)) {
      const s = G.diplo.score[0][a];
      const warm = ((LEADER_TRAITS[G.gov.leader.trait].diplo || fxv('warmRelations')) ? 1.2 : 0.5)
        + (hasEmbassy(0, a) ? 0.6 : 0);
      changeRel(0, a, s > 0 ? -0.3 : warm);
    }
  }
  // pact income
  for (let a = 1; a < n; a++) {
    G.spy.heat[a] = Math.max(0, (G.spy.heat[a] || 0) - 1.5);
    if (hasPact(0, a) && !G.nations[a].defeated && !hasSanction(0, a) && !hasSanction(a, 0)) {
      G.res.money += 40; G.nations[a].money += 40;
    }
  }
  // Foreign approaches: at most one at a time, and the substantive kind (a
  // pact, an alliance, an ultimatum) is favoured over yet another "I will sell
  // you 30 oil" contract.
  if (canAIContact()) {
    const roll = Math.random();
    if (roll < 0.11) aiDiplomaticProposal();
    else if (roll < 0.17) maybeAIOffer();
  }
  // hostile intelligence services may move against you (~every 6 min on average)
  if (G.time > AI_CONTACT_GRACE && Math.random() < 0.028) enemySpyAttempt();
  // world market: prices drift, standing trade routes flow
  marketTick();
  // intelligence decays — yesterday's picture goes stale
  for (let i = 1; i < G.nations.length; i++) {
    if (G.spy.intel[i]) G.spy.intel[i] = Math.max(0, G.spy.intel[i] - 0.35);
  }
}
function changeRelAI(a, b, delta) {
  const s = clamp(G.diplo.score[a][b] + delta, -100, 100);
  G.diplo.score[a][b] = G.diplo.score[b][a] = s;
}

/* ---------------- AI-initiated diplomacy: a real two-way channel ----------------
   Foreign powers reach out to YOU with proposals you accept or decline.
   Each choice shifts relations, resources or the balance of power. */
function aiDiplomaticProposal() {
  const cands = G.nations.map((nn, i) => i).filter(i =>
    i > 0 && !G.nations[i].defeated && canAIContact(i));
  if (!cands.length) return;
  const id = cands[Math.floor(Math.random() * cands.length)];
  const nat = G.nations[id];
  const rel = relScore(0, id);
  const mine = armyStrength(0), theirs = armyStrength(id) + 10;

  // choose a proposal that fits the current relationship
  const options = [];
  if (isAtWar(0, id)) {
    options.push('peace');
  } else {
    if (rel > 40 && !isAllied(0, id)) options.push('alliance');
    if (rel > 10 && !hasPact(0, id)) options.push('tradePact');
    if (rel < -20 && theirs > mine * 1.25) options.push('ultimatum');
    // a rival asks you to gang up on a third nation
    const commonEnemy = G.nations.map((_, j) => j).find(j =>
      j > 0 && j !== id && !G.nations[j].defeated && relScore(id, j) < -40 && relScore(0, j) < 0);
    if (rel > 0 && commonEnemy !== undefined) options.push('jointWar:' + commonEnemy);
    if (rel > -10) options.push('research'); // scientific exchange
  }
  if (!options.length) return;
  const choice = options[Math.floor(Math.random() * options.length)];
  markAIContact(id);

  if (choice === 'peace') {
    notifyAction(`🕊️ ${nat.name} proposes a CEASEFIRE. "Enough blood. Shall we lay down arms?"`, [
      { label: '✅ Accept peace', fn: () => {
          G.diplo.war[0][id] = G.diplo.war[id][0] = false;
          changeRel(0, id, 25); notify(`Peace signed with ${nat.name}.`, 'good', 6); refreshWindows();
        } },
      { label: '⚔️ Fight on', fn: () => { changeRel(0, id, -10); notify(`You reject ${nat.name}'s peace. The war continues.`, 'warn', 6); } },
    ], 30);
  } else if (choice === 'alliance') {
    notifyAction(`🤝 ${nat.name} offers a full MILITARY ALLIANCE. Their armies would answer your call — and you theirs.`, [
      { label: '✅ Sign alliance', fn: () => {
          G.diplo.alliance[0][id] = G.diplo.alliance[id][0] = true;
          G.diplo.pact[0][id] = G.diplo.pact[id][0] = true;
          changeRel(0, id, 20); notify(`⭐ Alliance forged with ${nat.name}!`, 'good', 7); refreshWindows();
        } },
      { label: '❌ Decline', fn: () => { changeRel(0, id, -6); } },
    ], 30);
  } else if (choice === 'tradePact') {
    notifyAction(`📜 ${nat.name} proposes a TRADE PACT — open borders for commerce (+$40/s each, enables trade routes).`, [
      { label: '✅ Sign pact', fn: () => {
          G.diplo.pact[0][id] = G.diplo.pact[id][0] = true;
          changeRel(0, id, 12); notify(`Trade pact with ${nat.name} signed. Open routes in the Trade window.`, 'good', 6); refreshWindows();
        } },
      { label: '❌ Decline', fn: () => { changeRel(0, id, -4); } },
    ], 28);
  } else if (choice === 'ultimatum') {
    const demand = 400 + Math.floor(Math.random() * 500);
    notifyAction(`😠 ${nat.name} issues an ULTIMATUM: "$${demand} in tribute, or we consider it an act of hostility."`, [
      { label: `💰 Pay $${demand}`, fn: () => {
          if (G.res.money < demand) { notify('You cannot pay — they are insulted!', 'bad'); changeRel(0, id, -15); return; }
          G.res.money -= demand; nat.money += demand; changeRel(0, id, 15);
          notify(`You pay ${nat.name}'s tribute. Tensions ease — for now.`, 'warn', 6); refreshWindows();
        } },
      { label: '✊ Refuse', fn: () => {
          changeRel(0, id, -30);
          notify(`You defy ${nat.name}. Relations crash${Math.random() < 0.4 ? ' — and they DECLARE WAR!' : '.'}`, 'bad', 7);
          if (Math.random() < 0.4) declareWar(0, id);
          refreshWindows();
        } },
    ], 30);
  } else if (choice === 'research') {
    notifyAction(`🔬 ${nat.name} proposes a SCIENTIFIC EXCHANGE: share research for mutual progress.`, [
      { label: '✅ Exchange (+150 research)', fn: () => {
          G.city.research += 150; nat.aiTech = (nat.aiTech || 0) + 1;
          changeRel(0, id, 8); notify(`Knowledge shared with ${nat.name}: +150 research.`, 'good', 6); refreshWindows();
        } },
      { label: '🔒 Keep our secrets', fn: () => { changeRel(0, id, -3); } },
    ], 28);
  } else if (choice.startsWith('jointWar:')) {
    const tid = +choice.split(':')[1];
    const tnat = G.nations[tid];
    if (!tnat || tnat.defeated) return;
    notifyAction(`⚔️ ${nat.name} proposes a JOINT WAR against ${tnat.name}. "Together we can break them."`, [
      { label: `🗡️ Join the war on ${tnat.name}`, fn: () => {
          declareWar(0, tid); if (!isAtWar(id, tid)) declareWar(id, tid);
          changeRel(0, id, 15); notify(`You and ${nat.name} march against ${tnat.name}!`, 'warn', 7); refreshWindows();
        } },
      { label: '🕊️ Stay out of it', fn: () => { changeRel(0, id, -6); } },
    ], 30);
  }
}
