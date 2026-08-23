'use strict';
/* ============================================================
   DOMINION — game data & balance configuration
   ============================================================ */

/* ---------------- map configuration (set from the menu) ---------------- */
let MAP_SIZE = 640;
let HALF_MAP = MAP_SIZE / 2;
let MAP_STYLE = 'island';
let START_POS = [];

const MAP_SIZES = {
  medium:   { name: 'Medium',   size: 480 },
  large:    { name: 'Large',    size: 640 },
  huge:     { name: 'Huge',     size: 820 },
  gigantic: { name: 'Gigantic', size: 1080 },
};
const MAP_STYLES = {
  island:      { name: 'Island',      desc: 'One landmass ringed by ocean. Navies rule the coast.' },
  continent:   { name: 'Continent',   desc: 'A vast dry interior with mountain ranges. Almost no water.' },
  archipelago: { name: 'Archipelago', desc: 'Scattered islands and sea lanes. Ships are life.' },
  highlands:   { name: 'Highlands',   desc: 'Rugged mountain country dotted with deep lakes. No ocean.' },
  twin:        { name: 'Twin Continents', desc: 'Two landmasses split by a strait. Control the crossing.' },
};
function setMapConfig(sizeKey, styleKey) {
  MAP_SIZE = MAP_SIZES[sizeKey].size;
  HALF_MAP = MAP_SIZE / 2;
  MAP_STYLE = styleKey;
  const o = HALF_MAP - 85;
  START_POS = [[-o, o], [o, o], [o, -o], [-o, -o]];
}
setMapConfig('large', 'island');

const SEA_LEVEL = 0;           // terrain below this is ocean
const YEAR_SECONDS = 60;       // one in-game year
const TERRITORY_CELL = 40;     // world units per territory cell
const PLANE_FUEL = 34;         // seconds of flight before a plane must return to base
const AIRBASE_SLOTS = 4;       // jets/bombers per airfield

const RES_KEYS = ['money', 'food', 'oil', 'iron', 'silicon', 'uranium'];
const RES_META = {
  money:   { icon: '💰', name: 'Money' },
  food:    { icon: '🌾', name: 'Food' },
  oil:     { icon: '🛢️', name: 'Oil' },
  iron:    { icon: '⛏️', name: 'Iron' },
  silicon: { icon: '🔷', name: 'Silicon' },
  uranium: { icon: '☢️', name: 'Uranium' },
};
// relative trade value of one unit of each resource (for AI deal evaluation)
const RES_VALUE = { money: 1, food: 1.5, oil: 4, iron: 2.5, silicon: 5, uranium: 8 };
// storage caps: base + warehouse bonus per Warehouse (money is uncapped, food capped by Food Warehouses)
const BASE_CAP = { oil: 500, iron: 500, silicon: 400, uranium: 300 };
const WAREHOUSE_CAP_BONUS = 400;

/* Map deposits: what can be mined where. gold/diamond pay out as money.
   water:true deposits spawn at sea — exploit them with the Offshore Rig
   (sea oil) or fish them from a nearby Fishing Wharf. */
const DEPOSIT_TYPES = {
  oil:     { name: 'Oil Field',      color: 0x1a1a1a, res: 'oil',     rate: 2.0, count: 8 },
  iron:    { name: 'Iron Deposit',   color: 0x8a6f5c, res: 'iron',    rate: 2.0, count: 9 },
  gold:    { name: 'Gold Vein',      color: 0xffd24d, res: 'money',   rate: 4.0, count: 6 },
  silicon: { name: 'Silicon Field',  color: 0x9fd7ff, res: 'silicon', rate: 1.5, count: 6 },
  uranium: { name: 'Uranium Lode',   color: 0x7dff5d, res: 'uranium', rate: 0.8, count: 5 },
  diamond: { name: 'Diamond Mine',   color: 0xd7f0ff, res: 'money',   rate: 6.0, count: 4 },
  seaOil:  { name: 'Offshore Oil Field', color: 0x25303a, res: 'oil', rate: 3.0, count: 6, water: true },
  fish:    { name: 'Fish School',    color: 0x8fd7e8, res: 'food',    rate: 2.0, count: 8, water: true },
};

/* ---------------- Buildings ---------------- */
const BUILDINGS = {
  hq: {
    name: 'Headquarters', icon: '🏛️', cat: 'military', size: 10, hp: 3500,
    cost: {}, buildTime: 0, trains: ['worker'], provides: { pop: 10 }, unique: true, unbuildable: true,
    settlement: 'capital', buildRadius: 72,
    mw: 12, // emergency generators keep a young nation running
    desc: 'Your capital. If it falls, you lose. Trains workers.',
  },
  /* ----- economy ----- */
  villageCenter: {
    name: 'Village Center', icon: '🏡', cat: 'economy', size: 7, hp: 900,
    cost: { money: 280, food: 40 }, buildTime: 18, settlement: 'village', buildRadius: 40,
    provides: { civCap: 90, happiness: 2 },
    desc: 'Founds a village and opens a 40-range construction district. Villages extend control and support rural growth.',
  },
  cityCenter: {
    name: 'City Center', icon: '🏙️', cat: 'economy', size: 10, hp: 1800,
    cost: { money: 850, iron: 70 }, buildTime: 32, settlement: 'city', buildRadius: 62,
    needsDiscovery: 'urbanPlanning', provides: { civCap: 260, happiness: 4, incomePct: 0.06 },
    desc: 'Founds a major city and opens a 62-range construction district. Requires Urban Planning.',
  },
  workerHouse: {
    name: 'Worker Lodge', icon: '🏠', cat: 'economy', size: 5, hp: 600,
    cost: { money: 150 }, buildTime: 12, trains: ['worker'],
    desc: 'Trains workers who construct buildings and mine deposits.',
  },
  housing: {
    name: 'Housing Block', icon: '🏢', cat: 'economy', size: 5, hp: 700,
    cost: { money: 200 }, buildTime: 14, provides: { pop: 8 },
    desc: '+8 army capacity. Soldiers need somewhere to sleep.',
  },
  residential: {
    name: 'Residential District', icon: '🏘️', cat: 'economy', size: 7, hp: 800,
    cost: { money: 350 }, buildTime: 18, provides: { civCap: 150, happiness: 2 },
    desc: '+150 civilian capacity. More citizens = more taxpayers.',
  },
  farm: {
    name: 'Farm', icon: '🌻', cat: 'economy', size: 6, hp: 450,
    cost: { money: 200 }, buildTime: 12, provides: { foodRate: 2.0 },
    desc: '+2 food/s. Feeds citizens and the army.',
  },
  foodDepot: {
    name: 'Food Warehouse', icon: '🏬', cat: 'economy', size: 5, hp: 650,
    cost: { money: 250 }, buildTime: 14, provides: { happiness: 5, foodCap: 500 },
    desc: '+5 happiness, +500 food storage. Hungry citizens riot.',
  },
  warehouse: {
    name: 'Storage Warehouse', icon: '📦', cat: 'economy', size: 6, hp: 700,
    cost: { money: 300 }, buildTime: 15, provides: { matCap: WAREHOUSE_CAP_BONUS },
    desc: `+${WAREHOUSE_CAP_BONUS} storage for oil, iron, silicon & uranium.`,
  },
  extractor: {
    name: 'Extractor (Mine / Rig)', icon: '⛽', cat: 'economy', size: 5, hp: 550,
    cost: { money: 300, iron: 20 }, buildTime: 16, onDeposit: true,
    desc: 'Build on a resource deposit to extract it automatically.',
  },
  powerPlant: {
    name: 'Power Plant', icon: '⚡', cat: 'economy', size: 7, hp: 900,
    cost: { money: 550, oil: 20 }, buildTime: 20, provides: { prodPct: 0.15 }, mw: 20,
    desc: '+20 MW, +15% production & construction speed (stacks up to +30%).',
  },
  nuclearReactor: {
    name: 'Nuclear Reactor', icon: '☢️', cat: 'economy', size: 8, hp: 1000,
    cost: { money: 1200, iron: 100, silicon: 50 }, buildTime: 35, mw: 40,
    desc: '+40 MW & +20% production & +$5/s while fueled (0.04 uranium/s). MELTDOWN if destroyed. Required for the Nuclear Program.',
  },
  market: {
    name: 'Market', icon: '🛒', cat: 'economy', size: 6, hp: 550,
    cost: { money: 350 }, buildTime: 15, provides: { incomePct: 0.08, happiness: 3 },
    desc: '+8% income, +3 happiness. Enables instant buy/sell on the World Market and +1 commercial contract.',
  },
  port: {
    name: 'Commercial Port', icon: '🚢', cat: 'economy', size: 9, hp: 900, coastal: true,
    cost: { money: 650, iron: 55 }, buildTime: 24, mw: -2,
    provides: { incomePct: 0.04 },
    desc: 'Required for overseas trade. Handles 2 shipping routes; cargo takes time to arrive and can be lost at sea. Must touch the coast.',
  },
  /* ----- housing variety: each home type opens different options ----- */
  cottage: {
    name: 'Cottage Row', icon: '🏡', cat: 'economy', size: 4, hp: 400,
    cost: { money: 120 }, buildTime: 9, provides: { civCap: 80, happiness: 2 },
    desc: '+80 civilian capacity, +2 happiness. Cozy starter homes for a young nation.',
  },
  apartments: {
    name: 'Apartment Tower', icon: '🏨', cat: 'economy', size: 6, hp: 900,
    cost: { money: 500, iron: 30 }, buildTime: 20, provides: { civCap: 280, happiness: -1 },
    desc: '+280 civilian capacity, -1 happiness. Mass housing = mass taxpayers.',
  },
  luxuryVillas: {
    name: 'Luxury Villas', icon: '🌇', cat: 'economy', size: 6, hp: 550,
    cost: { money: 650 }, buildTime: 18, provides: { civCap: 60, happiness: 5, incomePct: 0.04 },
    desc: '+60 capacity, +5 happiness, +4% income (max +16%). The wealthy pay well.',
  },
  /* ----- high-tech: who controls technology controls the future ----- */
  techPark: {
    name: 'Tech Park', icon: '💻', cat: 'economy', size: 7, hp: 700,
    cost: { money: 600, silicon: 30 }, buildTime: 22, provides: { researchRate: 0.8, incomePct: 0.05 }, mw: -2,
    desc: '+0.8 research/s, +5% income. Unlocks the Microchip Fabrication discovery.',
  },
  chipFab: {
    name: 'Chip Fab', icon: '🔬', cat: 'economy', size: 8, hp: 900,
    cost: { money: 900, silicon: 60, iron: 40 }, buildTime: 30, needsDiscovery: 'microchips', mw: -4,
    desc: 'Consumes 0.05 silicon/s → +$6/s and +0.4 research/s. Requires Microchip Fabrication.',
  },
  /* ----- civic ----- */
  bank: {
    name: 'Bank', icon: '🏦', cat: 'civic', size: 5, hp: 600,
    cost: { money: 500 }, buildTime: 18, provides: { incomePct: 0.15 },
    desc: '+15% national income (stacks up to +60%).',
  },
  cityHall: {
    name: 'City Hall', icon: '🏛️', cat: 'civic', size: 6, hp: 800,
    cost: { money: 400 }, buildTime: 18, provides: { incomePct: 0.10, happiness: 6 }, unique: true,
    desc: '+10% income, +6 happiness. The seat of local government.',
  },
  school: {
    name: 'School', icon: '🏫', cat: 'civic', size: 5, hp: 500,
    cost: { money: 300 }, buildTime: 15, provides: { education: 8, researchRate: 0.2 },
    desc: '+8 education → smarter citizens earn more, research faster.',
  },
  library: {
    name: 'Library', icon: '📚', cat: 'civic', size: 4, hp: 450,
    cost: { money: 250 }, buildTime: 13, provides: { education: 3, researchRate: 0.5 },
    desc: '+0.5 research/s, +3 education.',
  },
  university: {
    name: 'University', icon: '🎓', cat: 'civic', size: 8, hp: 900,
    cost: { money: 600 }, buildTime: 24, provides: { education: 10, researchRate: 1.0 },
    desc: '+1 research/s, +10 education. Gateway to great discoveries.',
  },
  hospital: {
    name: 'Hospital', icon: '🏥', cat: 'civic', size: 6, hp: 700,
    cost: { money: 400 }, buildTime: 18, provides: { health: 10 }, healRadius: 40, healRate: 2,
    desc: '+10 health → productive citizens; heals nearby units.',
  },
  policeStation: {
    name: 'Police Station', icon: '🚓', cat: 'civic', size: 5, hp: 700,
    cost: { money: 300 }, buildTime: 15, provides: { order: 10 },
    desc: '+10 public order. Low order breeds crime and lost income.',
  },
  park: {
    name: 'City Park', icon: '🌳', cat: 'civic', size: 6, hp: 300,
    cost: { money: 150 }, buildTime: 10, provides: { happiness: 6, culture: 2 },
    desc: '+6 happiness, +2 culture. Everyone loves a picnic.',
  },
  stadium: {
    name: 'Stadium', icon: '🏟️', cat: 'civic', size: 9, hp: 1000,
    cost: { money: 700 }, buildTime: 26, provides: { happiness: 8, culture: 5, incomePct: 0.03 }, unique: true,
    desc: '+8 happiness, +5 culture, +3% income. Bread and games.',
  },
  tvStation: {
    name: 'TV Station', icon: '📺', cat: 'civic', size: 5, hp: 600,
    cost: { money: 500 }, buildTime: 18, provides: { approval: 8, culture: 3 }, unique: true,
    desc: '+8 government approval, +3 culture. Controls the narrative.',
  },
  intelAgency: {
    name: 'Intelligence Agency', icon: '🕵️', cat: 'civic', size: 6, hp: 900,
    cost: { money: 900 }, buildTime: 24, provides: { spyPct: 0.10 }, unique: true,
    desc: 'Unlocks covert operations. Recruit agents here. +10% op success.',
  },
  /* ----- military ----- */
  ammoDepot: {
    name: 'Ammo Depot', icon: '🧨', cat: 'military', size: 5, hp: 600,
    cost: { money: 350, iron: 30 }, buildTime: 15, provides: { dmgPct: 0.05, missileCap: 4 },
    desc: '+5% unit damage (max +25%), -6% reload time for ALL units (max -18%), stores +4 missiles.',
  },
  barracks: {
    name: 'Barracks', icon: '🎖️', cat: 'military', size: 6, hp: 900,
    cost: { money: 300, iron: 20 }, buildTime: 18, trains: ['soldier', 'rocketSoldier', 'sniper', 'commando'],
    desc: 'Trains infantry: riflemen, rocket squads, snipers and commandos.',
  },
  tankFactory: {
    name: 'Tank Factory', icon: '🏭', cat: 'military', size: 8, hp: 1200,
    cost: { money: 600, iron: 80 }, buildTime: 25, mw: -3,
    trains: ['tank', 'apc', 'artillery', 'mlrs', 'aaVehicle', 'samLauncher'],
    desc: 'Produces tanks, APCs, artillery, MLRS, anti-air vehicles and SAM launchers.',
  },
  helipad: {
    name: 'Helipad', icon: '🚁', cat: 'military', size: 7, hp: 800,
    cost: { money: 700, iron: 60, oil: 20 }, buildTime: 25, trains: ['helicopter', 'gunship'], mw: -2,
    desc: 'Builds attack helicopters and heavy gunships.',
  },
  airfield: {
    name: 'Airfield', icon: '✈️', cat: 'military', size: 12, hp: 1000,
    cost: { money: 1000, iron: 100, oil: 40 }, buildTime: 32, trains: ['drone', 'jet', 'bomber'],
    planeSlots: AIRBASE_SLOTS, mw: -3,
    desc: `Air base with ${AIRBASE_SLOTS} plane slots. Jets & bombers fly missions from here and return to rearm.`,
  },
  shipyard: {
    name: 'Shipyard', icon: '⚓', cat: 'military', size: 9, hp: 1100, coastal: true,
    cost: { money: 700, iron: 80 }, buildTime: 28, trains: ['gunboat', 'corvette', 'submarine', 'destroyer', 'nuclearSub'],
    mw: -2,
    desc: 'Builds warships. Must be built on the coastline.',
  },
  missileSilo: {
    name: 'Missile Silo', icon: '🚀', cat: 'military', size: 7, hp: 1300,
    cost: { money: 900, iron: 100 }, buildTime: 30, mw: -3,
    missiles: ['tactical', 'cruise', 'cluster', 'emp', 'antiShip', 'ballistic', 'hypersonic', 'nuke'],
    desc: 'Produces tactical, cruise, cluster, EMP, anti-ship, strategic and nuclear missiles (stored in Ammo Depots).',
  },
  commandCenter: {
    name: 'Command & Control', icon: '📡', cat: 'military', size: 6, hp: 1000,
    cost: { money: 800, iron: 50 }, buildTime: 22, provides: { morale: 10, hpPct: 0.10 }, unique: true, mw: -3,
    desc: '+10 army morale, +10% unit HP. Coordinates the war effort.',
  },
  /* ----- defense line ----- */
  samSite: {
    name: 'SAM Site', icon: '🛡️', cat: 'military', size: 5, hp: 950,
    cost: { money: 450, iron: 60, silicon: 15 }, buildTime: 18, mw: -2,
    aaRange: 42, aaDmg: 60, aaCooldown: 1.4,
    desc: 'Automated anti-air battery: shoots down enemy planes, helicopters and drones in range.',
  },
  bunker: {
    name: 'Bunker', icon: '🧱', cat: 'military', size: 4, hp: 1800,
    cost: { money: 350, iron: 50 }, buildTime: 16,
    auraRadius: 15,
    desc: 'Hardened strongpoint: friendly infantry within 15 range take 30% less damage.',
  },
  /* ----- the power grid ----- */
  solarFarm: {
    name: 'Solar Farm', icon: '🔆', cat: 'economy', size: 7, hp: 400,
    cost: { money: 420, silicon: 20 }, buildTime: 16, mw: 8,
    desc: '+8 MW of clean power. The grid feeds every factory, lab and radar.',
  },
  oilRefinery: {
    name: 'Oil Refinery', icon: '🏭', cat: 'economy', size: 8, hp: 850,
    cost: { money: 550, iron: 40 }, buildTime: 22, mw: -3,
    desc: 'Consumes 0.06 oil/s → +$7/s. Industry runs on crude.',
  },
  /* ----- exploiting land & sea (terrain-gated construction) ----- */
  offshoreRig: {
    name: 'Offshore Rig', icon: '🛢️', cat: 'economy', size: 6, hp: 700,
    cost: { money: 650, iron: 60 }, buildTime: 26, onDeposit: true, depositTypes: ['seaOil'],
    needsDiscovery: 'offshoreDrilling', selfBuild: true, mw: -2,
    desc: 'Sea platform built on an Offshore Oil Field (builds itself — no worker needed). Requires Offshore Drilling.',
  },
  fishingWharf: {
    name: 'Fishing Wharf', icon: '🎣', cat: 'economy', size: 5, hp: 500,
    cost: { money: 320 }, buildTime: 15, coastal: true, needsDiscovery: 'aquaculture',
    provides: { foodRate: 2.0 },
    desc: '+2 food/s from the sea, +2 more per Fish School within 60 range (max +4). Must touch the coast.',
  },
  mountainMine: {
    name: 'Mountain Mine', icon: '⛰️', cat: 'economy', size: 5, hp: 650,
    cost: { money: 420, iron: 20 }, buildTime: 20, terrain: 'mountain', mw: -1,
    desc: 'Dig iron straight out of the high rock: +0.8 iron/s. Must be built on mountainous ground (elevation).',
  },
  /* ----- more civic life ----- */
  waterTreatment: {
    name: 'Water Treatment', icon: '💧', cat: 'civic', size: 6, hp: 600,
    cost: { money: 380 }, buildTime: 16, provides: { health: 6, civCap: 100 }, mw: -2,
    desc: '+6 health, +100 civilian capacity. Clean water, healthy city.',
  },
  museum: {
    name: 'National Museum', icon: '🏺', cat: 'civic', size: 6, hp: 550,
    cost: { money: 450 }, buildTime: 18, provides: { culture: 6, happiness: 4 }, unique: true, mw: -1,
    desc: '+6 culture, +4 happiness. A nation with a story fights for it.',
  },
  courthouse: {
    name: 'Courthouse', icon: '⚖️', cat: 'civic', size: 5, hp: 650,
    cost: { money: 420 }, buildTime: 18, provides: { order: 8, incomePct: 0.05 }, unique: true, mw: -1,
    desc: '+8 public order, +5% income. Rule of law pays dividends.',
  },
};

/* ---------------- Units ----------------
   fly>0 = air unit · naval = water only · dmgVsAir/dmgVsNaval = damage multipliers
   splash = AoE radius on hit */
const UNITS = {
  worker: {
    name: 'Worker', icon: '👷', hp: 60, dmg: 0, range: 0, cooldown: 0,
    speed: 9, fly: 0, pop: 1, trainTime: 8, cost: { money: 50 }, aggro: 0,
    desc: 'Builds structures, mines deposits, clears forests.',
  },
  soldier: {
    name: 'Soldier', icon: '🪖', hp: 100, dmg: 10, range: 13, cooldown: 1.0,
    speed: 9, fly: 0, pop: 1, trainTime: 8, cost: { money: 80, iron: 10 }, aggro: 24,
    desc: 'Basic infantry. Cheap and versatile.',
  },
  rocketSoldier: {
    name: 'Rocket Squad', icon: '🧨', hp: 90, dmg: 32, range: 16, cooldown: 2.2,
    speed: 8.5, fly: 0, pop: 1, trainTime: 10, cost: { money: 140, iron: 20 }, aggro: 26,
    dmgVsAir: 1.5,
    desc: 'Anti-armor infantry. Shreds tanks; can reach helicopters.',
  },
  sniper: {
    name: 'Sniper', icon: '🎯', hp: 70, dmg: 48, range: 24, cooldown: 3.0,
    speed: 8, fly: 0, pop: 1, trainTime: 12, cost: { money: 200, iron: 15 }, aggro: 28,
    desc: 'Extreme range, devastating single shots. Keep out of sight.',
  },
  commando: {
    name: 'Commando', icon: 'C', hp: 135, dmg: 28, range: 18, cooldown: 1.1,
    speed: 11, fly: 0, pop: 2, trainTime: 14, cost: { money: 260, iron: 30, silicon: 5 }, aggro: 32,
    desc: 'Elite infantry. Expensive, fast and deadly in small squads.',
  },
  tank: {
    name: 'Tank', icon: '🛡️', hp: 420, dmg: 42, range: 18, cooldown: 2.0,
    speed: 11, fly: 0, pop: 2, trainTime: 16, cost: { money: 250, iron: 60, oil: 20 }, aggro: 26,
    desc: 'Heavy armor, heavy punch.',
  },
  artillery: {
    name: 'Artillery', icon: '💥', hp: 200, dmg: 58, range: 34, cooldown: 4.0,
    speed: 7, fly: 0, pop: 2, trainTime: 18, cost: { money: 400, iron: 80, oil: 15 }, aggro: 32,
    splash: 5,
    desc: 'Longest ground range in the game, splash damage. Escort it.',
  },
  aaVehicle: {
    name: 'AA Vehicle', icon: '🎆', hp: 260, dmg: 16, range: 24, cooldown: 0.8,
    speed: 12, fly: 0, pop: 2, trainTime: 14, cost: { money: 300, iron: 50, oil: 10 }, aggro: 30,
    dmgVsAir: 3.5,
    desc: 'Rapid flak cannons — melts helicopters, jets and bombers.',
  },
  samLauncher: {
    name: 'SAM Launcher', icon: 'SAM', hp: 310, dmg: 22, range: 32, cooldown: 1.6,
    speed: 10, fly: 0, pop: 2, trainTime: 16, cost: { money: 380, iron: 65, oil: 10, silicon: 10 }, aggro: 38,
    dmgVsAir: 4.5,
    desc: 'Long-range missile vehicle. Builds a serious no-fly zone.',
  },
  helicopter: {
    name: 'Helicopter', icon: '🚁', hp: 260, dmg: 26, range: 20, cooldown: 1.2,
    speed: 19, fly: 13, pop: 2, trainTime: 18, cost: { money: 350, iron: 40, oil: 30 }, aggro: 30,
    desc: 'Fast air support, ignores terrain.',
  },
  jet: {
    name: 'Strike Jet', icon: '✈️', hp: 200, dmg: 75, range: 25, cooldown: 2.4,
    speed: 28, fly: 20, pop: 2, trainTime: 22, cost: { money: 500, iron: 50, oil: 50, silicon: 10 }, aggro: 34,
    dmgVsAir: 1.4,
    desc: 'Devastating strikes, good in dogfights. Glass cannon.',
  },
  bomber: {
    name: 'Heavy Bomber', icon: '🛩️', hp: 320, dmg: 95, range: 18, cooldown: 3.5,
    speed: 18, fly: 24, pop: 3, trainTime: 26, cost: { money: 700, iron: 80, oil: 60, silicon: 15 }, aggro: 30,
    splash: 9,
    desc: 'Carpet bombing with wide splash. Slow — bring escorts.',
  },
  drone: {
    name: 'Combat Drone', icon: 'DR', hp: 95, dmg: 14, range: 21, cooldown: 0.8,
    speed: 24, fly: 16, pop: 1, trainTime: 12, cost: { money: 220, oil: 8, silicon: 15 }, aggro: 34,
    desc: 'Cheap airborne scout-striker. Fragile, fast, excellent for harassment.',
  },
  gunboat: {
    name: 'Gunboat', icon: '🚤', hp: 320, dmg: 30, range: 22, cooldown: 1.5,
    speed: 14, fly: 0, naval: true, pop: 2, trainTime: 16, cost: { money: 300, iron: 50, oil: 20 }, aggro: 30,
    dmgVsAir: 1.5,
    desc: 'Fast coastal patrol boat with AA guns. Water only.',
  },
  submarine: {
    name: 'Submarine', icon: '🌊', hp: 380, dmg: 65, range: 20, cooldown: 2.2,
    speed: 12, fly: 0, naval: true, pop: 2, trainTime: 20, cost: { money: 500, iron: 90, oil: 40 }, aggro: 30,
    dmgVsNaval: 1.8, needsDiscovery: 'navalEngineering',
    desc: 'Torpedo attacks tear ships apart. Requires Naval Engineering.',
  },
  destroyer: {
    name: 'Destroyer', icon: '🚢', hp: 750, dmg: 70, range: 30, cooldown: 2.5,
    speed: 11, fly: 0, naval: true, pop: 3, trainTime: 26, cost: { money: 700, iron: 120, oil: 50 }, aggro: 36,
    dmgVsAir: 1.3, splash: 4, needsDiscovery: 'navalEngineering',
    desc: 'Heavy warship with long-range guns. Requires Naval Engineering.',
  },
  /* ----- expansion roster ----- */
  apc: {
    name: 'APC', icon: '🚙', hp: 300, dmg: 15, range: 15, cooldown: 0.5,
    speed: 14, fly: 0, pop: 2, trainTime: 12, cost: { money: 220, iron: 40, oil: 10 }, aggro: 26,
    desc: 'Fast armored car with a chain gun — chews through infantry, screens your tanks.',
  },
  mlrs: {
    name: 'MLRS', icon: '🎇', hp: 240, dmg: 72, range: 42, cooldown: 5.5,
    speed: 8, fly: 0, pop: 3, trainTime: 20, cost: { money: 520, iron: 90, oil: 25, silicon: 10 }, aggro: 40,
    splash: 8,
    desc: 'Rocket barrage across a wide area from extreme range. Fragile — keep it behind the line.',
  },
  gunship: {
    name: 'Gunship', icon: '🛸', hp: 400, dmg: 36, range: 21, cooldown: 0.7,
    speed: 16, fly: 12, pop: 3, trainTime: 22, cost: { money: 550, iron: 60, oil: 40, silicon: 10 }, aggro: 32,
    desc: 'Heavy attack helicopter: armored, sustained fire. The battlefield bully.',
  },
  corvette: {
    name: 'Missile Corvette', icon: '⛵', hp: 340, dmg: 44, range: 28, cooldown: 2.0,
    speed: 15, fly: 0, naval: true, pop: 2, trainTime: 18, cost: { money: 420, iron: 70, oil: 25, silicon: 12 }, aggro: 34,
    dmgVsAir: 1.6, dmgVsNaval: 1.3,
    desc: 'Fast missile boat — punches far above its weight against ships and aircraft.',
  },
  nuclearSub: {
    name: 'Nuclear Submarine', icon: '☢️', hp: 620, dmg: 75, range: 24, cooldown: 2.4,
    speed: 11, fly: 0, naval: true, pop: 4, trainTime: 34, cost: { money: 1200, iron: 150, oil: 60, uranium: 20 }, aggro: 32,
    dmgVsNaval: 1.9, needsDiscovery: 'nuclearProgram', canLaunchMissiles: true,
    desc: 'Strategic missile submarine: torpedoes ships AND launches cruise/ballistic/nuclear missiles from your stockpile. Requires the Nuclear Program.',
  },
};

/* ---------------- Missiles (munitions, not units) ---------------- */
const MISSILES = {
  tactical: {
    name: 'Tactical Missile', icon: 'TAC', buildTime: 14,
    cost: { money: 240, iron: 18, silicon: 4 },
    dmg: 280, radius: 9, speed: 85,
    desc: 'Cheap battlefield missile. Small blast, quick to produce.',
  },
  cruise: {
    name: 'Cruise Missile', icon: '🛩️', buildTime: 20,
    cost: { money: 400, iron: 30, silicon: 10 },
    dmg: 550, radius: 13, speed: 75,
    desc: 'Precision strike. Flies low and fast to the target.',
  },
  cluster: {
    name: 'Cluster Missile', icon: 'CL', buildTime: 26,
    cost: { money: 560, iron: 45, silicon: 14 },
    dmg: 380, radius: 24, speed: 68, special: 'cluster',
    desc: 'Wide anti-unit spread. Weak against hardened buildings.',
  },
  emp: {
    name: 'EMP Missile', icon: 'EMP', buildTime: 30,
    cost: { money: 620, iron: 25, silicon: 35 },
    dmg: 90, radius: 26, speed: 70, special: 'emp',
    desc: 'Disables vehicles, aircraft, ships and buildings in the blast for 35s.',
  },
  antiShip: {
    name: 'Anti-Ship Missile', icon: 'AS', buildTime: 24,
    cost: { money: 520, iron: 35, oil: 20, silicon: 12 },
    dmg: 520, radius: 11, speed: 95, special: 'antiShip', needsDiscovery: 'navalEngineering',
    desc: 'Sea-skimming missile. Devastating against naval targets.',
  },
  ballistic: {
    name: 'Ballistic Missile', icon: '🚀', buildTime: 40,
    cost: { money: 900, iron: 60, silicon: 25, oil: 20 },
    dmg: 1700, radius: 22, speed: 55, arc: true,
    needsDiscovery: 'ballisticTech',
    desc: 'Massive warhead on a high arc. Requires Ballistic Technology.',
  },
  hypersonic: {
    name: 'Hypersonic Missile', icon: 'HYP', buildTime: 46,
    cost: { money: 1150, iron: 70, silicon: 45, oil: 35 },
    dmg: 1200, radius: 14, speed: 150, needsDiscovery: 'ballisticTech',
    desc: 'Very fast precision strategic missile. Smaller blast than ballistic, harder to react to.',
  },
  nuke: {
    name: 'Nuclear Missile', icon: '☢️', buildTime: 60,
    cost: { money: 2000, iron: 80, silicon: 60, uranium: 25 },
    dmg: 4500, radius: 38, speed: 50, arc: true, needsDiscovery: 'nuclearProgram',
    desc: 'City-killer. Massive blast; the entire world will condemn its use.',
  },
};
const BASE_MISSILE_CAP = 2;
const NUKE_URANIUM_COST = 25; // uranium in every nuclear warhead

/* ---------------- Nations ---------------- */
const NATION_DEFS = [
  { name: 'Atlantic Federation', color: 0x3b82f6, css: '#3b82f6', isPlayer: true,
    people: { president: 'President E. Hale', general: 'Gen. M. Ross', scientist: 'Dr. A. Klein', spymaster: 'Dir. V. Cole' } },
  { name: 'Crimson Empire', color: 0xe0483e, css: '#e0483e',
    people: { president: 'Premier K. Volkov', general: 'Gen. D. Orlov', scientist: 'Dr. I. Petrova', spymaster: 'Col. Y. Draken' } },
  { name: 'Verdant Union', color: 0x33b86e, css: '#33b86e',
    people: { president: 'Chancellor L. Moreau', general: 'Gen. P. Okafor', scientist: 'Dr. S. Vance', spymaster: 'Agent-Chief N. Idris' } },
  { name: 'Golden Dominion', color: 0xe8a83a, css: '#e8a83a',
    people: { president: 'Sultan R. Qadir', general: 'Marshal T. Aziz', scientist: 'Dr. F. Haddad', spymaster: 'Vizier O. Nasir' } },
];

/* ---------------- Government & leaders ---------------- */
const GOVERNMENTS = {
  democracy: {
    name: 'Democracy', icon: '🗳️',
    incomePct: 0.10, happiness: 5, electionEvery: 5, // years
    desc: '+10% income, +5 happiness. Elections every 5 years — back a candidate and hope the voters agree.',
  },
  dictatorship: {
    name: 'Dictatorship', icon: '👊',
    dmgPct: 0.10, prodPct: 0.10, happiness: -8, coupEvery: 5,
    desc: '+10% army damage & production, -8 happiness. No elections… but low approval invites a coup.',
  },
  monarchy: {
    name: 'Monarchy', icon: '👑',
    incomePct: 0.05, culture: 10, happiness: 3,
    desc: '+5% income, +10 culture, +3 happiness. Stable succession, few surprises.',
  },
  technocracy: {
    name: 'Technocracy', icon: '🧪',
    researchPct: 0.25, happiness: -3,
    desc: '+25% research, -3 happiness. Rule of the experts.',
  },
};
const GOV_SWITCH_COST = 1200;         // money cost of constitutional reform
const GOV_SWITCH_COOLDOWN = 5 * 60;   // seconds between reforms
const GOV_SWITCH_INSTABILITY = 90;    // seconds of transition chaos

const LEADER_TRAITS = {
  economist:  { name: 'The Economist', icon: '📈', desc: '+12% national income',       incomePct: 0.12 },
  warmonger:  { name: 'The Warmonger', icon: '⚔️', desc: '+10% army damage',           dmgPct: 0.10 },
  diplomat:   { name: 'The Diplomat',  icon: '🤝', desc: 'Gifts twice as effective, relations warm faster', diplo: true },
  spymaster:  { name: 'The Spymaster', icon: '🗝️', desc: '+10% covert op success',     spyPct: 0.10 },
  scholar:    { name: 'The Scholar',   icon: '📖', desc: '+20% research output',       researchPct: 0.20 },
  builder:    { name: 'The Builder',   icon: '🏗️', desc: '+20% construction & production speed', prodPct: 0.20 },
};
/* every head of state also carries a flaw — real leaders are trade-offs */
const LEADER_FLAWS = {
  spender:    { name: 'Big Spender',    icon: '💸', desc: '-6% national income',            incomePct: -0.06 },
  hawkish:    { name: 'Hawkish',        icon: '🦅', desc: 'Relations decay faster; -4 approval', approval: -4, hawk: true },
  timid:      { name: 'Timid',          icon: '🐢', desc: '-8% army damage',                dmgPct: -0.08 },
  luddite:    { name: 'Technophobe',    icon: '🔌', desc: '-10% research output',           researchPct: -0.10 },
  cronyist:   { name: 'Cronyist',       icon: '🪙', desc: '-6 public order',                order: -6 },
  aloof:      { name: 'Aloof',          icon: '🗿', desc: '-5 happiness',                   happiness: -5 },
};
const LEADER_NAMES = ['A. Hale', 'M. Verona', 'J. Castellan', 'R. Novak', 'S. Whitmore', 'D. Ferro',
  'K. Ashford', 'L. Mercer', 'T. Solano', 'V. Reiner', 'N. Calloway', 'E. Marlow'];
const LEADER_TITLES = { democracy: 'President', dictatorship: 'Supreme Leader', monarchy: 'Monarch', technocracy: 'Director' };

/* ---------------- City administration ---------------- */
const CIVIC_LEADERS = {
  planner:      { name: 'Urban Planner',     icon: 'UP', desc: '+10% construction speed, +5 public order.', prodPct: 0.10, order: 5 },
  agrarian:     { name: 'Agrarian Mayor',    icon: 'AG', desc: '+20% food production, +3 happiness.', foodPct: 0.20, happiness: 3 },
  industrialist:{ name: 'Industrial Boss',   icon: 'IN', desc: '+8% income, -3 happiness.', incomePct: 0.08, happiness: -3 },
  marshal:      { name: 'Security Marshal',  icon: 'SM', desc: '+12 public order, -4 approval.', order: 12, approval: -4 },
  professor:    { name: 'City Professor',    icon: 'PR', desc: '+15% research, +5 education.', researchPct: 0.15, education: 5 },
  populist:     { name: 'People Champion',   icon: 'PC', desc: '+6 happiness, +6 approval, -5% income.', happiness: 6, approval: 6, incomePct: -0.05 },
};
const CIVIC_NAMES = ['N. Alder', 'P. Moran', 'I. Vale', 'C. Sato', 'R. Benet', 'M. Arendt', 'L. Stern', 'O. Karim'];
const CIVIC_TITLES = { democracy: 'Mayor', dictatorship: 'Governor', monarchy: 'Royal Prefect', technocracy: 'Civic Director' };
const LOCAL_ELECTION_EVERY = 3;       // years between democratic city elections
const CIVIC_APPOINT_COST = 400;       // non-democratic appointment cost
const CIVIC_APPOINT_COOLDOWN = 120;   // seconds between appointments

/* ---------------- Policies ---------------- */
const POLICIES = {
  tax: {
    name: 'Taxation', icon: '🧾', options: {
      low:    { label: 'Low',    incomeMult: 0.75, happiness: 6,  approval: 5 },
      normal: { label: 'Normal', incomeMult: 1.0,  happiness: 0,  approval: 0 },
      high:   { label: 'High',   incomeMult: 1.3,  happiness: -8, approval: -8 },
    },
  },
  rationing:     { name: 'Food Rationing', icon: '🥫', desc: 'Food consumption -45%, happiness -6.', happiness: -6 },
  propaganda:    { name: 'State Propaganda', icon: '📢', desc: '+10 approval, costs $3/s.', approval: 10, costPerSec: 3 },
  freeHealthcare:{ name: 'Free Healthcare', icon: '💊', desc: '+8 health, costs $2/s.', health: 8, costPerSec: 2 },
};

/* ---------------- Discoveries: the research tree ----------------
   Every discovery belongs to a branch and may carry an `fx` object of
   standardized modifiers that the game reads generically:
   incomePct researchPct prodPct foodPct civCapPct spyPct extractPct
   happiness health education order approval culture tradeRoutes
   dmgInfantry dmgVehicle dmgAir dmgNaval dmgArty dmgDrone dmgAll
   hpInfantry hpVehicle spdGround spdAir spdNaval rangeNaval rangeArty
   costVehiclePct costInfantryPct costDronePct reformDiscount warmRelations */
const DISC_BRANCHES = {
  society:   { name: 'Society & Culture',  icon: '🏙️' },
  economy:   { name: 'Economy & Industry', icon: '💰' },
  army:      { name: 'Ground Forces',      icon: '⚔️' },
  air:       { name: 'Air Power',          icon: '✈️' },
  navy:      { name: 'Naval Power',        icon: '⚓' },
  hightech:  { name: 'High Technology',    icon: '💻' },
  strategic: { name: 'Strategic Weapons',  icon: '☢️' },
  politics:  { name: 'Statecraft',         icon: '🏛️' },
};
const DISCOVERIES = {
  /* ======== SOCIETY & CULTURE ======== */
  fertilizers: {
    name: 'Synthetic Fertilizers', icon: '🧪', cost: 150, branch: 'society',
    desc: 'Farms produce +50% food.',
  },
  irrigation: {
    name: 'Modern Irrigation', icon: '💦', cost: 260, branch: 'society', reqDiscovery: 'fertilizers',
    desc: 'Farms produce a further +40% food.', fx: { foodPct: 0.4 },
  },
  forestry: {
    name: 'Industrial Forestry', icon: '🪓', cost: 120, branch: 'society',
    desc: 'Workers clear forests twice as fast and earn double lumber money.',
  },
  publicEducation: {
    name: 'Public Education', icon: '🎒', cost: 220, branch: 'society', reqBuilding: 'school',
    desc: '+6 education, +10% research output. Requires a School.',
    fx: { education: 6, researchPct: 0.10 },
  },
  advancedMedicine: {
    name: 'Advanced Medicine', icon: '🧬', cost: 250, branch: 'society', reqBuilding: 'hospital',
    desc: '+10 health, hospitals heal twice as fast. Requires a Hospital.',
  },
  nationalHealth: {
    name: 'National Health Service', icon: '🩺', cost: 420, branch: 'society', reqDiscovery: 'advancedMedicine',
    desc: '+8 health, +3 happiness. Healthcare for every citizen.',
    fx: { health: 8, happiness: 3 },
  },
  urbanPlanning: {
    name: 'Urban Planning', icon: '📐', cost: 300, branch: 'society', reqBuilding: 'cityHall',
    desc: 'All housing holds +25% more civilians. Requires a City Hall.',
    fx: { civCapPct: 0.25 },
  },
  welfareState: {
    name: 'Welfare State', icon: '🤲', cost: 380, branch: 'society', reqDiscovery: 'publicEducation',
    desc: '+8 happiness, +4 approval, but -6% income.',
    fx: { happiness: 8, approval: 4, incomePct: -0.06 },
  },
  /* ======== ECONOMY & INDUSTRY ======== */
  stockExchange: {
    name: 'Stock Exchange', icon: '💹', cost: 250, branch: 'economy', reqBuilding: 'bank',
    desc: '+15% national income. Requires a Bank.',
  },
  taxAdministration: {
    name: 'Tax Administration', icon: '🧾', cost: 200, branch: 'economy', reqBuilding: 'bank',
    desc: '+8% national income. An efficient state collects what it is owed.',
    fx: { incomePct: 0.08 },
  },
  industrialization: {
    name: 'Industrialization', icon: '🏗️', cost: 320, branch: 'economy', reqBuilding: 'oilRefinery',
    desc: '+12% production & construction speed. Requires an Oil Refinery.',
    fx: { prodPct: 0.12 },
  },
  heavyIndustry: {
    name: 'Heavy Industry', icon: '⚙️', cost: 480, branch: 'economy', reqDiscovery: 'industrialization',
    desc: 'Vehicles and ships cost 15% less to produce.',
    fx: { costVehiclePct: -0.15 },
  },
  globalLogistics: {
    name: 'Global Logistics', icon: '🚢', cost: 350, branch: 'economy', reqBuilding: 'market',
    desc: '+1 trade route and better world-market prices. Requires a Market.',
    fx: { tradeRoutes: 1 },
  },
  advancedMining: {
    name: 'Advanced Mining', icon: '⛏️', cost: 400, branch: 'economy', reqDiscovery: 'industrialization',
    desc: 'Extractors and rigs produce +40% resources.',
    fx: { extractPct: 0.4 },
  },
  /* ======== GROUND FORCES ======== */
  eliteTraining: {
    name: 'Elite Training Program', icon: '🥇', cost: 280, branch: 'army', reqBuilding: 'barracks',
    desc: 'Infantry deal +20% damage and gain +15% HP. Requires a Barracks.',
    fx: { dmgInfantry: 0.2, hpInfantry: 0.15 },
  },
  compositeArmor: {
    name: 'Composite Armor', icon: '🛡️', cost: 350, branch: 'army', reqBuilding: 'tankFactory',
    desc: 'Vehicles gain +20% HP. Requires a Tank Factory.',
    fx: { hpVehicle: 0.2 },
  },
  guidedMunitions: {
    name: 'Guided Munitions', icon: '🎯', cost: 420, branch: 'army', reqDiscovery: 'compositeArmor',
    desc: 'Artillery & MLRS deal +20% damage and reach +10% further.',
    fx: { dmgArty: 0.2, rangeArty: 0.10 },
  },
  advancedLogistics: {
    name: 'Advanced Logistics', icon: '🚛', cost: 380, branch: 'army', reqDiscovery: 'eliteTraining',
    desc: 'All ground units move +15% faster. Speed wins wars.',
    fx: { spdGround: 0.15 },
  },
  combinedArms: {
    name: 'Combined Arms Doctrine', icon: '🎖️', cost: 600, branch: 'army',
    reqDiscovery: 'compositeArmor',
    desc: 'The whole army deals +8% damage when infantry, armor and air fight together.',
    fx: { dmgAll: 0.08 },
  },
  /* ======== AIR POWER ======== */
  jetPropulsion: {
    name: 'Advanced Jet Propulsion', icon: '🌀', cost: 320, branch: 'air', reqBuilding: 'airfield',
    desc: 'Aircraft fly +20% faster. Requires an Airfield.',
    fx: { spdAir: 0.2 },
  },
  precisionStrikes: {
    name: 'Precision Airstrikes', icon: '🎯', cost: 450, branch: 'air', reqDiscovery: 'jetPropulsion',
    desc: 'Aircraft deal +15% damage.',
    fx: { dmgAir: 0.15 },
  },
  droneSwarms: {
    name: 'Drone Swarms', icon: '🛸', cost: 380, branch: 'air', reqDiscovery: 'microchips',
    desc: 'Drones deal +40% damage and cost 30% less.',
    fx: { dmgDrone: 0.4, costDronePct: -0.3 },
  },
  stealthTech: {
    name: 'Stealth Technology', icon: '🌑', cost: 500, branch: 'air', reqBuilding: 'airfield',
    desc: 'Your aircraft take 30% less damage. They never see you coming.',
  },
  /* ======== NAVAL POWER ======== */
  navalEngineering: {
    name: 'Naval Engineering', icon: '⚓', cost: 300, branch: 'navy', reqBuilding: 'shipyard',
    desc: 'Unlocks the Destroyer and Submarine. Requires a Shipyard.',
  },
  sonarSystems: {
    name: 'Sonar Systems', icon: '📡', cost: 380, branch: 'navy', reqDiscovery: 'navalEngineering',
    desc: 'Warships deal +15% damage and fire +10% further.',
    fx: { dmgNaval: 0.15, rangeNaval: 0.10 },
  },
  offshoreDrilling: {
    name: 'Offshore Drilling', icon: '🛢️', cost: 420, branch: 'navy', reqBuilding: 'shipyard',
    desc: 'Unlocks the Offshore Rig — extract oil fields found at sea.',
  },
  aquaculture: {
    name: 'Aquaculture', icon: '🐟', cost: 260, branch: 'navy', reqBuilding: 'shipyard',
    desc: 'Unlocks the Fishing Wharf — coastal food from the sea, more near fish schools.',
  },
  /* ======== HIGH TECHNOLOGY ======== */
  microchips: {
    name: 'Microchip Fabrication', icon: '💾', cost: 300, branch: 'hightech', reqBuilding: 'techPark',
    desc: 'Unlocks the Chip Fab: turns silicon into money and research. Requires a Tech Park.',
  },
  robotics: {
    name: 'Robotics', icon: '🤖', cost: 450, branch: 'hightech', reqDiscovery: 'microchips',
    desc: 'Workers build and mine 50% faster. The machines work the mines.',
  },
  aiRevolution: {
    name: 'AI Revolution', icon: '🧠', cost: 700, branch: 'hightech', reqDiscovery: 'microchips', reqBuilding: 'chipFab',
    desc: '+20% research speed, +10% income. Who controls technology controls the future.',
  },
  quantumComputing: {
    name: 'Quantum Computing', icon: '🔮', cost: 950, branch: 'hightech', reqDiscovery: 'aiRevolution',
    desc: '+25% research output. Problems that took years now take minutes.',
    fx: { researchPct: 0.25 },
  },
  satelliteRecon: {
    name: 'Satellite Recon', icon: '🛰️', cost: 350, branch: 'hightech',
    desc: 'Enemy units become visible on the minimap; incoming attacks are flagged.',
  },
  cyberWarfare: {
    name: 'Cyber Warfare', icon: '🖥️', cost: 520, branch: 'hightech', reqDiscovery: 'microchips', reqBuilding: 'intelAgency',
    desc: '+12% covert operation success. Wars are won in the wires.',
    fx: { spyPct: 0.12 },
  },
  /* ======== STRATEGIC WEAPONS ======== */
  ballisticTech: {
    name: 'Ballistic Technology', icon: '🚀', cost: 400, branch: 'strategic', reqBuilding: 'missileSilo',
    desc: 'Unlocks Ballistic Missiles. Requires a Missile Silo.',
  },
  nuclearProgram: {
    name: 'Nuclear Program', icon: '☢️', cost: 800, branch: 'strategic', reqDiscovery: 'ballisticTech', reqBuilding: 'nuclearReactor',
    desc: 'Unlocks the Nuclear Missile and the Nuclear Submarine. Requires a Nuclear Reactor. The world will fear — and hate — you.',
  },
  fusionPower: {
    name: 'Fusion Power', icon: '⚛️', cost: 900, branch: 'strategic', reqDiscovery: 'nuclearProgram',
    desc: 'Reactors burn half the uranium and can no longer melt down.',
  },
  /* ======== STATECRAFT ======== */
  diplomaticCorps: {
    name: 'Diplomatic Corps', icon: '🤝', cost: 260, branch: 'politics',
    desc: 'Gifts are twice as effective and relations warm faster — like having a Diplomat in charge, permanently.',
    fx: { warmRelations: 1 },
  },
  massMedia: {
    name: 'Mass Media', icon: '📡', cost: 300, branch: 'politics', reqBuilding: 'tvStation',
    desc: '+6 approval, +3 culture. Requires a TV Station.',
    fx: { approval: 6, culture: 3 },
  },
  secretPolice: {
    name: 'Internal Security Service', icon: '🕶️', cost: 340, branch: 'politics', reqBuilding: 'policeStation',
    desc: '+10 public order, -3 happiness. Order has a price.',
    fx: { order: 10, happiness: -3 },
  },
  constitutionalReform: {
    name: 'Constitutional Framework', icon: '📜', cost: 400, branch: 'politics', reqBuilding: 'courthouse',
    desc: 'Changing government form costs half and causes half the instability.',
    fx: { reformDiscount: 1 },
  },
};

/* ---------------- Difficulty ---------------- */
const DIFFICULTY = {
  easy:   { income: 9,  buildEvery: 38, trainEvery: 26, maxArmy: 14, firstAttack: 780, squad: 5,  counterSpy: 0.00, aggression: 0.35 },
  normal: { income: 14, buildEvery: 28, trainEvery: 20, maxArmy: 22, firstAttack: 600, squad: 7,  counterSpy: 0.10, aggression: 0.5 },
  hard:   { income: 24, buildEvery: 16, trainEvery: 12, maxArmy: 36, firstAttack: 420, squad: 11, counterSpy: 0.20, aggression: 0.9 },
};

/* ---------------- Espionage operations ---------------- */
const SPY_OPS = {
  buildNetwork: { name: 'Build Network', icon: 'NET', cost: 180, base: 0.85,
    desc: 'Recruit assets and build a long-term infiltration network in the target nation.' },
  reconDossier:{ name: 'Recon Dossier', icon: 'REC', cost: 160, base: 0.75, minNetwork: 8,
    desc: 'Produce a detailed target report: army strength, money, buildings and diplomatic state.' },
  cyberAttack: { name: 'Cyber Attack', icon: 'CYB', cost: 450, base: 0.48, minNetwork: 18,
    desc: 'Disable production and power systems for 90 seconds.' },
  stealFunds:  { name: 'Steal Funds', icon: '💸', cost: 200, base: 0.60,
    desc: 'Siphon money from the target treasury.' },
  stealTech:   { name: 'Steal Research', icon: '📁', cost: 300, base: 0.50,
    desc: 'Exfiltrate research data (+120 research points).' },
  sabotage:    { name: 'Sabotage', icon: '💣', cost: 400, base: 0.45,
    desc: 'Cripple a random enemy structure (heavy damage).' },
  proxyCell:   { name: 'Fund Proxy Cell', icon: '🎭', cost: 500, base: 0.55,
    desc: 'A proxy cell disrupts their economy for 3 minutes.' },
  armRebels:   { name: 'Arm Rebels', icon: 'REB', cost: 650, base: 0.42, minNetwork: 25,
    desc: 'Create internal unrest: economy suffers and random facilities take damage.' },
  falseFlag:   { name: 'False Flag', icon: 'FF', cost: 700, base: 0.35, minNetwork: 35,
    desc: 'Frame the target for aggression. Damages their relations and may start a foreign crisis.' },
  assassinate: { name: 'Assassination', icon: '🎯', cost: 800, base: 0.30, needsPerson: true,
    desc: 'Eliminate a key figure. Massive fallout if traced.' },
};
/* effect of assassinating each role */
const ASSASSIN_TARGETS = {
  president: { label: 'Head of State', effect: 'Their entire economy -35% for 4 min. May trigger war.' },
  general:   { label: 'Top General',   effect: 'Their units deal -30% damage for 4 min.' },
  scientist: { label: 'Chief Scientist', effect: 'You steal 250 research points.' },
  spymaster: { label: 'Spymaster',     effect: 'Their counter-intelligence collapses for 5 min.' },
};

/* ---------------- Research tracks ---------------- */
const TECH_TRACKS = {
  economy:   { name: 'Economics', icon: '📈', max: 5, baseCost: 120,
    desc: '+12% national income per level.' },
  military:  { name: 'Military Science', icon: '⚔️', max: 5, baseCost: 150,
    desc: '+8% unit damage and HP per level.' },
  espionage: { name: 'Covert Ops', icon: '🗝️', max: 5, baseCost: 130,
    desc: '+8% operation success per level.' },
  hightech: { name: 'High-Tech Industry', icon: '💻', max: 5, baseCost: 150,
    desc: '+6% research speed and +4% income per level. Silicon is the oil of the future.' },
};

/* ---------------- World trade ---------------- */
// base world price (money per unit) — actual prices drift with the market
const TRADE_PRICE = { food: 2.5, oil: 7, iron: 5, silicon: 10, uranium: 16 };
const TRADE_QTY = [10, 25, 50];       // cargo units loaded into each shipment
const TRADE_IMPORT_MARKUP = 1.15;     // importers pay over market
const TRADE_INSTANT_SELL = 0.9;       // instant market sale gets 90% of price
const TRADE_INSTANT_BUY = 1.15;       // instant market purchase pays 115%
const TRADE_VOYAGE_SECONDS = 30;       // one-way voyage; trade is delayed, not an instant resource stream
const TRADE_ROUTES_PER_PORT = 2;

/* ---------------- National development eras ----------------
   The next era is a visible mid-game objective rather than a passive timer.
   Requirements are evaluated in order; reaching one grants a permanent reward. */
const DEVELOPMENT_ERAS = [
  { name: 'Founding Era', icon: '🌱', desc: 'Secure the capital and establish a durable homeland.', reward: {} },
  { name: 'Regional Era', icon: '🛤️', desc: 'Found a village and grow beyond the capital.',
    req: { villages: 1, buildings: 8 }, reward: { money: 500, research: 100 } },
  { name: 'Urban Era', icon: '🏙️', desc: 'Build a true city and educate a larger population.',
    req: { cities: 1, civilians: 450, discoveries: 5 }, reward: { money: 900, research: 220 } },
  { name: 'Industrial Era', icon: '⚙️', desc: 'Create a multi-city industrial state with a strong power grid.',
    req: { cities: 2, discoveries: 12, power: 45 }, reward: { money: 1400, research: 400 } },
  { name: 'Global Era', icon: '🌐', desc: 'Connect several cities to the world economy.',
    req: { cities: 3, routes: 2, discoveries: 20 }, reward: { money: 2200, research: 650 } },
  { name: 'Future Era', icon: '🚀', desc: 'Lead a continental, high-technology civilization.',
    req: { cities: 4, discoveries: 30, compute: 3, landShare: 0.35 }, reward: { money: 3500, research: 1000 } },
];

/* ---------------- Named field agents ---------------- */
const AGENT_NAMES = ['Viper', 'Nightingale', 'Cobalt', 'Mirage', 'Falcon', 'Wraith', 'Onyx',
  'Tempest', 'Cipher', 'Ghost', 'Saffron', 'Raven', 'Drift', 'Lynx', 'Echo', 'Vesper'];
const AGENT_XP_LEVELS = [2, 5, 9, 14];     // successful ops needed for skill 2,3,4,5
const AGENT_SKILL_BONUS = 0.04;            // op success bonus per skill level above 1
const AGENT_RANSOM = 600;                  // cost to buy back a captured agent
function agentRecruitCost() { return 400 + (G.agentRoster ? G.agentRoster.length : 0) * 120; }
const AGENT_RANKS = ['Rookie', 'Field Agent', 'Operative', 'Veteran', 'Master Spy'];

/* ---------------- Relations thresholds ---------------- */
function relationStatus(score, war, alliance) {
  if (war) return { label: 'AT WAR', color: '#ff5d5d' };
  if (alliance) return { label: 'Allied', color: '#5dff8f' };
  if (score >= 60) return { label: 'Friend', color: '#8fe388' };
  if (score >= 25) return { label: 'Cordial', color: '#b9d98a' };
  if (score > -25) return { label: 'Neutral', color: '#c9c9c9' };
  if (score > -60) return { label: 'Disliked', color: '#e8a83a' };
  return { label: 'Hostile / Cold War', color: '#ff9b5d' };
}

/* ---------------- small helpers ---------------- */
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const dist2d = (ax, az, bx, bz) => Math.hypot(ax - bx, az - bz);
const fmtNum = n => n >= 10000 ? (n / 1000).toFixed(1) + 'k' : Math.floor(n).toString();
function costText(cost) {
  return Object.entries(cost).map(([k, v]) => `${RES_META[k].icon}${v}`).join(' ') || 'Free';
}
function canAfford(res, cost) {
  return Object.entries(cost).every(([k, v]) => res[k] >= v);
}
function payCost(res, cost) {
  for (const [k, v] of Object.entries(cost)) res[k] -= v;
}
