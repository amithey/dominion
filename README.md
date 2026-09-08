# DOMINION — Real-Time Nation Strategy

A 3D real-time strategy game in the spirit of **Civilization × Command & Conquer: Red Alert 2**.
Runs entirely in the browser on Three.js r184, with local GLB gameplay assets.

## How to run
On Windows, double-click `Start-Game.bat`. It always serves this project folder, avoiding the directory-listing/404 problem.

Open a terminal in this folder and run any static server, e.g.:

```
npx http-server
```

then open the printed localhost URL. A local server is required because the modern Three.js build uses ES modules.

Gameplay models live under `assets/models`. City and watercraft models are from Kenney's CC0 kits; the animated
Soldier is from the Three.js examples. Existing procedural meshes remain automatic fallbacks if a model is missing.

## How to play
- **Local review:** `npm start` serves fresh assets at `http://127.0.0.1:8771/index.html`.
  Choose **Visual review** for a developed base with Infantry / Armor close-ups.
  Opponent AI is paused in this separate review scenario; **New campaign** returns to normal play.
- **Display:** `F3` opens quality and resolution settings; `F10` hides/restores the HUD.
  `Home` returns to the capital. The construction search filters buildings without resetting the list during play.
- **Validation:** `npm install` then `npm test` checks terrain picking, building avoidance,
  reachable move destinations, formation path budgets, and tank assembly.
- **Goal:** destroy every rival Headquarters. Lose yours and it's over.
- **Controls:** left-click / drag = select · right-click = move / attack / mine / construct ·
  `A`+click = attack-move · `WASD` pan · `Q/E` rotate · wheel zoom · `Space` pause · `Esc` menu/abort.
- **The map is an island** — the coast matters: Shipyards must touch water, warships patrol the ocean ring.

### Settlements & development
Your Headquarters is the **capital**. Normal buildings must be placed inside the construction district of a capital,
**City Center**, or **Village Center**. Found villages to reach rural resources, then research Urban Planning and found
full cities with larger districts. Selecting a settlement displays its build radius. National eras provide persistent
income, research and production bonuses, with visible requirements and milestone rewards in the City window.

### Economy & storage
Workers construct buildings and mine deposits (oil, iron, gold, silicon, uranium, diamonds).
Build an **Extractor** on a deposit for full rate. **Storage Warehouses** raise material caps,
**Food Warehouses** store food, **Ammo Depots** store missiles. **Power Plants** speed up all production.
Build a coastal **Commercial Port** to open shipping routes: cargo is committed before departure, takes time to arrive,
and can be lost if the route collapses or piracy strikes. Combat ships reduce voyage risk.

### Civilian life
Farms feed people — and *only* farms and fishing do. Every citizen and every soldier eats from the same stores,
so if your food runs out the population starts dying and the army starts deserting in the field; burning an
enemy's farms is a real way to win a war. Tax income scales with your **tax administration** (City Hall, Markets,
Banks, settlement centres): a state with nothing built collects almost nothing, so the economy has to be grown.
Schools/Libraries/**Universities** drive research; Hospitals heal; **Police Stations** keep
public order (crime eats income); **Parks & Stadiums** raise happiness & culture; **Markets & Banks** multiply
income; **Residential Districts** grow your tax base; the **TV Station** props up approval.

### Government (chosen at game start)
**Democracy · Dictatorship · Monarchy · Technocracy** — each with unique bonuses and events:
elections every 12 years (lose them and your leader is replaced — set `electionEvery: 0` in `js/config.js`
to remove elections entirely), coups against unpopular dictators,
royal successions. Every leader has a trait (Economist, Warmonger, Diplomat, Spymaster, Scholar, Builder)
that actively buffs your nation. Manage **policies**: taxation, rationing, propaganda, free healthcare.

### Military
Barracks → soldiers & rocket squads · Tank Factory → tanks & artillery · Helipad → helicopters ·
Airfield → jets · **Shipyard** → gunboats & destroyers · **Missile Silo** → cruise & ballistic missiles
(launch them at any point on the map; the Nuclear Program makes them apocalyptic — at a diplomatic price).

### Diplomacy & espionage
Gifts, trade deals, pacts, alliances, war & peace, world relations matrix. Build the Intelligence Agency to
steal funds/research, sabotage, fund proxy cells or assassinate leaders — choose the op, nation and person.

### Research
3 upgrade tracks + one-time **Discoveries**: Fertilizers, Stock Exchange, Advanced Medicine,
Satellite Recon (see enemy movement), Naval Engineering, Ballistic Tech, Nuclear Program.

## Files
```
index.html      shell + HUD layout
css/style.css   UI theme
js/config.js    all game data & balance
js/world.js     island terrain, ocean, deposits, clouds, lighting
js/entities.js  buildings, units, missiles, combat, city & government sim
js/diplomacy.js relations, trade, espionage
js/ai.js        AI nations (Easy / Normal / Hard)
js/ui.js        windows, minimap, notifications
js/main.js      engine, camera, input, game loop
```
