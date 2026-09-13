'use strict';
/* ============================================================
   AI nation controllers — simplified economies, build orders,
   defense and timed attack waves scaled by difficulty.
   ============================================================ */

function DIFF() { return DIFFICULTY[G.difficulty]; }

// opening build order — after this, the AI builds adaptively from needs
const AI_BUILD_ORDER = [
  'workerHouse', 'farm', 'barracks', 'housing', 'villageCenter', 'powerPlant', 'extractor', 'bank',
  'tankFactory', 'housing', 'ammoDepot', 'farm', 'commandCenter',
];
const AI_TRAIN_POOL = ['soldier', 'soldier', 'soldier', 'rocketSoldier', 'commando', 'tank', 'tank', 'apc', 'artillery', 'samLauncher', 'helicopter', 'drone', 'jet'];

function initAIState(nat, id) {
  nat.ai = {
    id,
    buildIdx: 0,
    nextBuild: 14 + Math.random() * 14,
    nextTrain: 22 + Math.random() * 12,
    nextAttack: DIFF().firstAttack * (0.9 + Math.random() * 0.4),
    nextDefendCheck: 5,
    nextExpand: 40 + Math.random() * 30,
    nextResearch: 30,
    nextRally: 50 + Math.random() * 20,
    attacking: false,
    outposts: 0,
  };
}

/* Adaptive build choice — the AI reads its own economy and picks what it
   most needs next, so it keeps growing all game instead of stopping. */
function aiPickBuilding(nat) {
  const id = nat.ai.id;
  const count = key => G.buildings.filter(b => b.owner === id && b.key === key && !b.dead).length;
  const total = G.buildings.filter(b => b.owner === id && !b.dead).length;
  const army = G.units.filter(u => u.owner === id && !u.dead && u.def.dmg > 0).length;
  const wants = [];
  // economy backbone scales with size
  if (count('powerPlant') + count('solarFarm') < Math.ceil(total / 6)) wants.push('powerPlant');
  if (count('farm') < 2 + Math.floor(total / 7)) wants.push('farm');
  if (count('housing') < 2 + Math.floor(army / 4)) wants.push('housing');
  if (count('bank') < 3) wants.push('bank');
  // grab free resource deposits aggressively — the map's wealth decides wars
  if (count('extractor') < 6 && G.deposits.some(dp => !dp.hasExtractor && !dp.def.water)) wants.push('extractor');
  if (count('residential') + count('apartments') < 2 + Math.floor(total / 8)) wants.push('apartments');
  // tech advantage — the AI races for chips too
  if (count('techPark') < 1 && total > 8) wants.push('techPark');
  if (count('market') < 2) wants.push('market');
  if (count('villageCenter') < 2 && total > 7) wants.push('villageCenter');
  if (count('cityCenter') < Math.max(1, Math.floor(total / 14)) && total > 12) wants.push('cityCenter');
  // military production & defense
  if (count('tankFactory') < 2 && total > 6) wants.push('tankFactory');
  if (count('samSite') < Math.floor(total / 9)) wants.push('samSite');
  if (count('bunker') < Math.floor(total / 10)) wants.push('bunker');
  if (count('airfield') < 1 && total > 12) wants.push('airfield');
  if (count('helipad') < 1 && total > 10) wants.push('helipad');
  if (count('ammoDepot') < 2 && army > 6) wants.push('ammoDepot');
  if (count('hospital') < 1 && total > 9) wants.push('hospital');
  // fallback: keep expanding housing/economy so the base never stalls
  if (!wants.length) wants.push(Math.random() < 0.5 ? 'housing' : 'bank');
  return wants[Math.floor(Math.random() * Math.min(wants.length, 3))];
}

function aiUpdate(nat, dt) {
  if (nat.defeated || nat.isPlayer) return;
  const ai = nat.ai;
  const d = DIFF();
  updateAILogistics(nat, dt);

  // passive income (their whole economy abstracted), hurt by player ops
  nat.money += d.income * dt * economyMult(ai.id);

  ai.nextBuild -= dt;
  ai.nextTrain -= dt;
  ai.nextAttack -= dt;
  ai.nextDefendCheck -= dt;
  ai.nextExpand -= dt;
  ai.nextResearch -= dt;
  ai.nextRally -= dt;

  /* ----- rally: idle troops never just stand around — they regroup, patrol
     the frontier, and stuck detachments get fresh orders ----- */
  if (ai.nextRally <= 0) {
    ai.nextRally = 45 + Math.random() * 25;
    const hq = aiHQ(ai.id);
    if (hq) {
      const idle = G.units.filter(u => u.owner === ai.id && !u.dead && u.def.dmg > 0
        && (u.state === 'idle' || u.state === 'guard'));
      if (idle.length >= 3) {
        // half patrol out to the frontier, half consolidate at home
        const front = [];
        if (TERRITORY.owner) {
          for (let ci = 0; ci < TERRITORY.owner.length; ci++) {
            if (TERRITORY.owner[ci] === ai.id && isFrontCell(ci)) front.push(cellCenter(ci));
          }
        }
        const spot = front.length
          ? front[Math.floor(Math.random() * front.length)]
          : { x: hq.x + (Math.random() - 0.5) * 60, z: hq.z + (Math.random() - 0.5) * 60 };
        const patrol = idle.slice(0, Math.ceil(idle.length / 2));
        commandMove(patrol, spot.x, spot.z, true);
        patrol.forEach(u => { u.guardX = spot.x; u.guardZ = spot.z; });
        const home = idle.slice(Math.ceil(idle.length / 2));
        if (home.length) commandMove(home, hq.x + 20, hq.z + 20, true);
      }
    }
  }

  // once shots are flying, the AI doesn't sit on its first-attack timer
  if (ai.nextAttack > 120 && G.nations.some((n, i) => i !== ai.id && !n.defeated && isAtWar(ai.id, i))) {
    ai.nextAttack = 60 + Math.random() * 60;
  }

  // good intelligence buys you advance warning of the coming storm
  if (!ai.warned && ai.nextAttack < 40 && ai.nextAttack > 0 && isAtWar(ai.id, 0)
      && (intelLevel(ai.id) >= 60 || G.discovered.satelliteRecon)) {
    ai.warned = true;
    notify(`🛰️ INTEL WARNING: ${nat.name} is massing forces — expect an attack within ~40 seconds!`, 'warn', 10);
  }
  if (ai.nextAttack > 60) ai.warned = false;

  /* ----- construction: fixed opening, then adaptive growth forever ----- */
  if (ai.nextBuild <= 0) {
    const key = ai.buildIdx < AI_BUILD_ORDER.length ? AI_BUILD_ORDER[ai.buildIdx] : aiPickBuilding(nat);
    const def = BUILDINGS[key];
    if (def) {
      const cost = (def.cost.money || 0) + (def.cost.iron || 0) * 2 + (def.cost.oil || 0) * 3 + (def.cost.silicon || 0) * 4;
      if (nat.money >= cost) {
        nat.money -= cost;
        const spot = aiFindSpot(nat, def);
        if (spot) {
          const b = spawnBuilding(key, ai.id, spot[0], spot[1], spot[2] ? { deposit: spot[2] } : {});
          b.progress = 0.01; b.aiSelfBuild = true;
          if (ai.buildIdx < AI_BUILD_ORDER.length) ai.buildIdx++;
        }
      }
    }
    // build faster as the economy matures
    const total = G.buildings.filter(b => b.owner === ai.id && !b.dead).length;
    ai.nextBuild = Math.max(6, d.buildEvery * (0.7 + Math.random() * 0.4) - total * 0.3);
  }

  /* ----- research: the AI advances its own tech (chips = power) ----- */
  if (ai.nextResearch <= 0) {
    ai.nextResearch = 28 + Math.random() * 20;
    nat.aiTech = (nat.aiTech || 0);
    const techCost = 200 + nat.aiTech * 140;
    if (nat.money > techCost + 400 && nat.aiTech < 8) {
      nat.money -= techCost;
      nat.aiTech++;
    }
  }

  // AI self-building construction progress
  for (const b of G.buildings) {
    if (b.owner === ai.id && !b.built && !b.dead && b.aiSelfBuild) {
      b.progress += dt / Math.max(b.def.buildTime, 8);
      b.hp = Math.min(b.maxHp, b.maxHp * b.progress + 1);
      b.mesh.scale.y = 0.15 + 0.85 * Math.min(b.progress, 1);
      if (b.progress >= 1) { b.built = true; b.hp = b.maxHp; b.mesh.scale.y = 1; }
    }
  }

  /* ----- training ----- */
  if (ai.nextTrain <= 0) {
    const army = G.units.filter(u => u.owner === ai.id && !u.dead);
    if (army.length < d.maxArmy) {
      const options = AI_TRAIN_POOL.filter(k => {
        const need = { soldier: 'barracks', rocketSoldier: 'barracks', tank: 'tankFactory',
          commando: 'barracks', artillery: 'tankFactory', samLauncher: 'tankFactory',
          helicopter: 'helipad', drone: 'airfield', jet: 'airfield' }[k];
        return G.buildings.some(b => b.owner === ai.id && b.built && !b.dead && b.key === need);
      });
      if (options.length) {
        const key = options[Math.floor(Math.random() * options.length)];
        const cost = (UNITS[key].cost.money || 0) + (UNITS[key].cost.iron || 0) * 2 + (UNITS[key].cost.oil || 0) * 3;
        if (nat.money >= cost) {
          nat.money -= cost;
          const hq = aiHQ(ai.id);
          if (hq) {
            const ang = Math.random() * Math.PI * 2;
            spawnUnit(key, ai.id, hq.x + Math.cos(ang) * 16, hq.z + Math.sin(ang) * 16);
          }
        }
      }
    }
    // a nation at war drafts around the clock
    const atWar = G.nations.some((n, i) => i !== ai.id && !n.defeated && isAtWar(ai.id, i));
    ai.nextTrain = d.trainEvery * (0.8 + Math.random() * 0.4) * (atWar ? 0.55 : 1);
  }

  /* ----- defense: units near base auto-fight via aggro; rally home if base under attack ----- */
  if (ai.nextDefendCheck <= 0) {
    ai.nextDefendCheck = 4;
    const hq = aiHQ(ai.id);
    if (hq) {
      const threat = G.units.find(u => !u.dead && isAtWar(ai.id, u.owner) && dist2d(u.x, u.z, hq.x, hq.z) < 70);
      if (threat) {
        // everything comes home to defend the capital — even attackers turn back
        for (const u of G.units) {
          if (u.owner !== ai.id || u.dead || u.def.dmg <= 0) continue;
          if (u.state === 'idle' || u.state === 'move' || u.state === 'attackMove' || u.state === 'guard') {
            u.tx = threat.x; u.tz = threat.z; u.state = 'attackMove';
          }
        }
      }
    }
  }

  /* ----- attack waves ----- */
  if (ai.nextAttack <= 0 && !(nat.aiParalyzedUntil > G.time)) {
    ai.nextAttack = d.firstAttack * (0.55 + Math.random() * 0.5);
    // pick an enemy: prefer whoever it's at war with; easy AI only attacks if already at war
    let targetNation = -1;
    for (let i = 0; i < G.nations.length; i++) {
      if (i !== ai.id && !G.nations[i].defeated && isAtWar(ai.id, i)) { targetNation = i; break; }
    }
    if (targetNation < 0 && Math.random() < d.aggression) {
      // aggressive AI may start a war with its most hated neighbor
      let worst = -1, worstScore = -35;
      for (let i = 0; i < G.nations.length; i++) {
        if (i === ai.id || G.nations[i].defeated || isAllied(ai.id, i) || hasNap(ai.id, i)) continue;
        if (relScore(ai.id, i) < worstScore) { worstScore = relScore(ai.id, i); worst = i; }
      }
      if (worst >= 0) { declareWar(ai.id, worst); targetNation = worst; }
    }
    if (targetNation >= 0) {
      const army = G.units.filter(u => u.owner === ai.id && !u.dead && u.def.dmg > 0);
      // keep a home guard, send the rest — bigger armies mount bigger offensives
      const guardCount = Math.min(3, Math.floor(army.length / 4));
      const squad = army.slice(guardCount, guardCount + Math.max(d.squad, Math.floor(army.length * 0.6)));
      // strike the nearest enemy asset first and roll up the map from there —
      // fighting through the frontier instead of suiciding into the capital
      const hq = aiHQ(ai.id);
      const enemyAssets = G.buildings.filter(b => b.owner === targetNation && !b.dead)
        .sort((a2, b2) => dist2d(a2.x, a2.z, hq ? hq.x : 0, hq ? hq.z : 0) - dist2d(b2.x, b2.z, hq ? hq.x : 0, hq ? hq.z : 0));
      const target = enemyAssets[0];
      if (squad.length >= Math.max(3, d.squad - 2) && target) {
        commandMove(squad, target.x, target.z, true);
        ai.attacking = true;
        // early warning only with Satellite Recon — otherwise you find out the hard way
        if (targetNation === 0 && G.discovered.satelliteRecon)
          notify(`🛰️ SATELLITE WARNING: ${nat.name} forces are moving on your ${target.def.name}!`, 'bad', 8);
      }
      // while at war, waves come noticeably faster
      if (isAtWar(ai.id, targetNation)) ai.nextAttack = Math.min(ai.nextAttack, d.firstAttack * 0.35);
    }
  }

  /* ----- territorial expansion: push idle troops onto unclaimed land ----- */
  if (ai.nextExpand <= 0) {
    ai.nextExpand = 30 + Math.random() * 25;
    const hq = aiHQ(ai.id);
    if (hq && TERRITORY.owner) {
      // find the nearest neutral (or weakly-held enemy) land cell to expand into
      let best = null, bestD = Infinity;
      const step = 3;
      for (let ci = 0; ci < TERRITORY.owner.length; ci += 1) {
        const owner = TERRITORY.owner[ci];
        if (owner === ai.id) continue;
        const c = cellCenter(ci);
        if (terrainH(c.x, c.z) < 0.5) continue;
        const dHQ = dist2d(c.x, c.z, hq.x, hq.z);
        if (dHQ > 220) continue; // only expand into reach
        // prefer neutral land; contest enemy land only when at war
        if (owner >= 0 && !(isAtWar(ai.id, owner))) continue;
        // bias toward closest frontier
        const score = dHQ + (owner < 0 ? 0 : 40);
        if (score < bestD) { bestD = score; best = c; }
      }
      if (best) {
        // send a spare detachment to occupy it (claims territory via territoryTick)
        const spare = G.units.filter(u => u.owner === ai.id && !u.dead && u.def.dmg > 0
          && (u.state === 'idle' || u.state === 'guard')).slice(0, 4);
        if (spare.length >= 2) {
          for (const u of spare) { u.guardX = best.x; u.guardZ = best.z; }
          commandMove(spare, best.x, best.z, true);
          spare.forEach(u => { u.state = 'attackMove'; });
        }
        // occasionally plant a forward building to cement the claim
        if (nat.money > 900 && ai.outposts < 4 && Math.random() < 0.5) {
          const key = Math.random() < 0.65 ? 'villageCenter' : 'bunker';
          const def = BUILDINGS[key];
          const jx = best.x + (Math.random() - 0.5) * 10, jz = best.z + (Math.random() - 0.5) * 10;
          if (terrainH(jx, jz) > 0.8 && Math.abs(jx) < HALF_MAP - 12 && Math.abs(jz) < HALF_MAP - 12) {
            const clear = G.buildings.every(b => b.dead || dist2d(b.x, b.z, jx, jz) > b.def.size + def.size + 2);
            if (clear) {
              nat.money -= 700;
              const b = spawnBuilding(key, ai.id, jx, jz, {});
              b.progress = 0.01; b.aiSelfBuild = true;
              ai.outposts++;
            }
          }
        }
      }
    }
  }
}

function aiHQ(id) {
  return G.buildings.find(b => b.owner === id && b.key === 'hq' && !b.dead);
}

function aiFindSpot(nat, def) {
  const hq = aiHQ(nat.ai.id);
  if (!hq) return null;
  for (let t = 0; t < 24; t++) {
    const ang = Math.random() * Math.PI * 2;
    const r = def.settlement && def.settlement !== 'capital'
      ? (def.settlement === 'city' ? 90 : 65) + Math.random() * 45
      : 16 + Math.random() * 38;
    const x = hq.x + Math.cos(ang) * r;
    const z = hq.z + Math.sin(ang) * r;
    if (Math.abs(x) > HALF_MAP - 12 || Math.abs(z) > HALF_MAP - 12) continue;
    if (terrainH(x, z) < 0.8) continue; // stay on dry land
    const owner = territoryOwnerAt(x, z);
    if ((owner >= 0 && owner !== nat.ai.id) || territoryIsContested(x, z)) continue;
    if (def.onDeposit) {
      // claim the nearest free land deposit anywhere within operating range —
      // extractors are worth building far from home
      const free = G.deposits
        .filter(dp => !dp.hasExtractor && !dp.def.water && dist2d(dp.x, dp.z, hq.x, hq.z) < 300)
        .sort((a2, b2) => dist2d(a2.x, a2.z, hq.x, hq.z) - dist2d(b2.x, b2.z, hq.x, hq.z));
      if (free.length) return [free[0].x, free[0].z, free[0]];
      continue;
    }
    const clear = G.buildings.every(b => b.dead || dist2d(b.x, b.z, x, z) > b.def.size + def.size + 2);
    const depClear = G.deposits.every(dp => dist2d(dp.x, dp.z, x, z) > def.size + 6);
    if (clear && depClear) return [x, z];
  }
  return null;
}
