# DOMINION 1.0.0 ALPHA: the report for approval (2026-10-21)

**Status: nothing in this report has been committed or pushed.** It is all in the working tree. After you read it and
approve, the next steps are (section 9): commit and push, build 1.0.0, run the packaged tests, smoke-test the installer,
publish `v1.0.0-alpha` as a pre-release.

## 1. What was asked

Release the game as version 1.0 (an alpha for testers). Try every function, button, text and capability and see that it
works; improve everything across the visual, practical, real-world, physical, influence and intelligence lenses, from the
grass (a unit's step, a shell) to the politics (UN, sanctions, crises); run a series of tests proving each area; write a
detailed document before any commit; then commit, push and rebuild so that it can be sent to testers.

Decisions you made when I asked: the version is **1.0.0 with the label ALPHA** (the build pipeline needs a clean number);
the **cheats stay available** to the alpha's testers (you changed this at approval: the Testing tools switch remains in Settings, Game, off by default); physics and realism get **targeted
corrections**, not a re-scaling of the world (a hex is about 21 m, artillery about 62 m).

## 2. The result in numbers

| Area | What was done | ok | warnings | failures |
|---|---|---|---|---|
| Every control | surfaces and tabs opened, every enabled button pressed | 949 | 91 | 0 |
| Every unit | definition, plausibility, training, nations, model, combat, friendly fire, orders | 379 | 3 | 0 |
| The attack order, every armed unit | hurts the enemy in reach; closes in or stands off by design | 130 | 4 | 0 |
| Every building | site, finish, what it provides, what it trains, demolish, save | 302 | 1 | 0 |
| Every weapon | launcher, launch, flight, effect, who may field it | 60 | 2 | 0 |
| Every discovery | definition, tree walk, stated effects, effects seen in play, researched for real | 199 | 0 | 0 |
| The world | 28 national powers, 16 espionage operations, UN measures, events, crises, victory, diplomacy | 107 | 9 | 0 |
| Every text | years, spelling, leaked placeholders, lengths; definitions, reasons, messages | 1146 | 4 | 0 |
| What can exist physically and logically | rules, order of classes, terrain orders, ten-minute soak | 150 | 0 | 0 |
| Every nation and every map | 28 matches of two game minutes, saved and checked | 29 | 0 | 0 |
| How every surface looks (a window) | 64 surfaces at four window sizes | 260 | 0 | 0 |
| Every picture (a window) | portraits of units, buildings, weapons | 171 | 8 | 0 |
| **Total** | | **3882** | **122** | **0** |

Elements covered: **96 units, 53 buildings, 30 weapon types, 95 discoveries,
28 national powers, 16 espionage operations, 12 UN measures, 8 world events, 10 crises, 4 victory paths, 24 maps x 28 nations
(28 matches), 87 surfaces and tabs with 862 button presses, 1150 texts.**

The whole regression of the game's own suites (`run-tests.ps1`, in a copy of the tree, one suite after another):
**138 of 144 suites passed in the one full run** (about 5 hours on this computer, which went to sleep twice).

Six suites did not pass in the one full run; each was investigated and passes now:

| Suite | What happened in the full run | What it is, and the re-run |
|---|---|---|
| Every map loads (`maps-check`) | Failed, and fails on the published 0.9.101 too | **A real defect** (item 13 in section 3.1): a nation could start without oil. Fixed; passes on all 22 maps |
| Audit of every weapon (`audit-missiles`) | The AGM-88 showed "no effect" | The enemy's SAM shot it down (a random interception, by design). The audit now fires again, up to five more times, and says so. 60 ok, 0 failures |
| Weapons in live combat (`weapons-live-100`) | "both batteries take part" failed | The dice: missiles that got through destroyed the capital and ended the match. The test keeps the capital alive and waits for slow cruise missiles. 10 of 10 runs pass (it failed 3 of 8 before) |
| Nations and maps matrix (`audit-matrix`) | Stopped after 17 matches | The computer went to sleep and the wall-clock budget ran out; the old audit reported that as a pass, the new one reports it as a failure. Complete re-run: 28 of 28 matches, 0 warnings |
| Action wording (`action-copy-check`) | Timeout at 180 s | Passes alone in 14 s: the computer was busy or asleep |
| A hundred more, every map at full strength (`gameplay-campaign-100`) | Finished with one script error that I could not read (the log is deleted after a run) | Not reproduced: the systems half (35 checks) and all 24 maps (four shares side by side, 120 checks) pass with no script error. Likely the same missing-oil defect, but unproven |


A warning is not a defect: it is something the audit could not decide by itself (a fixture that could not place an enemy in
reach, a design abstraction written down as such). They are listed in section 7.

## 3. What was found and fixed

### 3.1 Real defects (all fixed, each with a test that fails without the fix)

| # | Defect | Cause and fix |
|---|---|---|
| 1 | **An error on every screen refresh while a spy mission was running**, so the mission's progress bar never moved | The meter's bar and label were taken in the wrong order (`side_panels.gd`) |
| 2 | **An error on pressing your nation's power on a nation card** (Dollar Sanctions, Rare-Earth Controls...) | The button's callback returned nothing where the button expects a message (`side_panels.gd`) |
| 3 | **A vehicle without a turret that dies aborted its own death** | `world.kill()` touched the turret unconditionally |
| 4 | **The UN session screen failed when the last record was a standing sanction** (every game with sanctions in force) | The screen looked the sanction up as a Council measure; it is not one (`un_session_screen.gd`) |
| 5 | **Four national units had no picture** (Houthi coastal drone, Iraqi Golden Division, Syrian Shaheen team, Afghan squad) | The picture path did not know a national variant looks like the unit it is built on (`world.display_model`) |
| 6 | **A damaged or cut-short save raised script errors instead of saying it was damaged**, and could be overwritten by the next autosave | Saves are now validated before they are touched; a bad file is refused with a message and kept as `.bad.json` (`save.gd`) |
| 7 | **A save lost the carrier's air wing** (the deck refilled; aircraft in the air had no carrier) | The wing and each aircraft's carrier are saved (`save.gd`) |
| 8 | A rival's economy kept more than half its real-world size however much of it was destroyed (found by you, fixed in 0.9.101, kept under test) | GDP follows what stands |
| 9 | The TOS-1A's salvo scattered so widely it left most of a squad standing (a test that was already failing on 0.9.100) | Rockets land within 4 m instead of 6 m |
| 10 | The Help window's new button broke an existing test | Order of the buttons restored |
| 11 | "Recall all assigned aircraft" with none said "0 aircraft returning" | It now says there are none |
| 12 | The main menu cut off text and the last entry | The About link moved under the menu; the Continue line is shorter |
| 13 | **A nation could start with no oil at all** (12 of the 22 generated maps; on the small map the nearest field was 164 m from one capital) | Since 0.9.100 every third oil field became natural gas, including the one each map promises a capital. Oil within 112 m of a capital now stays oil (`gameplay_rules.gd`). The map check had been failing since then and the regression caught it |

### 3.2 Logic that could not exist in the real world (the physical and logical audit)

The audit (`audit-physics.gd`) tries what can exist and what can happen. It found **no impossibility**: a ten-minute match
with every unit and building looked at every half second never had a land unit in deep water, a ship on dry land, an aircraft
under the ground, a building in the sea, an unmoving unit "teleporting" beyond its speed, or a unit inside a building; a tank
and a squad sent into the sea stopped at the shore; a destroyer sent inland stopped at the coast; every building refuses a
site where it cannot stand (sea, cliff, inland for a harbour); what each building trains matches its kind; no helicopter
lifts a tank; a rifle cannot hurt a warship or a tank; a SAM cannot hit the ground.

It did find **orders of class the real world does not have**, now corrected:

| Before | Now | Why |
|---|---|---|
| Destroyer 11, carrier 14, landing ship 15, submarine 12, gunboat 14 | Destroyer **14**, carrier **12**, landing ship **11**, submarine **11**, gunboat **17** | A destroyer is faster than a carrier, an amphibious ship and a submerged submarine; a patrol boat is faster than all |
| Bomber 18, helicopter 19 | Bomber **21** | A heavy bomber is faster than a helicopter |
| Cruise missile 75, ballistic 55, intercontinental 50 | Cruise **48** | A cruise missile is subsonic: the slowest, and air defence has time to stop it |
| MLRS reach = howitzer reach | MLRS **three and a half hexes**, howitzer three, HIMARS four | A rocket launcher outreaches a howitzer |
| Japanese Aegis destroyer 10 | **13** | Follows the destroyer |

### 3.3 The aircraft carrier (you reported it twice: "the range and how to use the aircraft are not clear")

| Before | Now |
|---|---|
| The panel said RANGE 24 m (the guns, which only defend); the real reach of the wing was a hidden 125 m | **One number, 240 m**: the panel's RANGE and ATTACK are the wing's, the brief and description say it, a **blue ring** on the map shows it |
| Nothing showed the aircraft | An **AIR WING** row: on deck, flying, rearming, lost, held down, with how to use it |
| The wing launched at anything; an attack order sailed the carrier up to its target | **Launch: automatic / orders only**; **Recall wing** (and an automatic wing stays down 30 s after it); the carrier stays where it is when the target is in reach, and never closes to its guns' range |
| A lost aircraft was never replaced | A replacement every 45 s for $400 (and it says so, also when the money is short) |
| A Bombard button on a carrier | Gone: the wing strikes what you right-click |

Reach rings are drawn for every far-shooting unit you select (artillery, rocket launchers, air defence).

### 3.4 Clarity: "every text is unclear, you get lost in the words"

Every unit and building card is a role line and two or three points (`brief.gd`), the full text on hover; the
selection panel shows the brief and one line of controls; troops aboard a transport are a large green badge with a figure
per soldier; a weapon that cannot be launched says what launches it; sanctions are shown on the target's card; the
Cabinet lists your crises. The text audit found **no year, no American spelling and no leaked placeholder** in 1150
texts (definitions, the reasons a player is told, and every literal message in the scripts).

### 3.5 The economy, statistics and crises (0.9.101, included)

GDP follows what stands (no floor); the statistics now publish growth, inflation, unemployment, public debt, credit rating,
defence spending, fragility, displaced and energy, and an overview of every nation; destroyed power, farms, homes and
industry bring recession, blackouts, currency crisis, default, displacement, protest and the fall of a government; striking
civilian infrastructure is condemned. A rival's crises and rating are published a release late (they follow intelligence like
the rest of the statistics).

### 3.6 What makes it a tester's build

The version (1.0.0) and label ALPHA on the opening screen, in the window title and in every save; an **About** screen;
**Report a problem** (About, the Esc menu, F1): writes the version, the machine, the match and the last messages to a
file, copies it and opens the folder with the engine's own log (kept for five runs); the Testing tools switch kept for testers; saves validated and
versioned (saves from 0.9.x load; a newer save warns); a first-run check in a clean user folder; the installer shows the
alpha notes (`ALPHA-README.txt`: what to expect, known issues, where files are, how to report).

## 4. How it was tried (so you can repeat any of it)

Each audit is a tool in `native/godot/tools/` that plays the real game and prints `ok`, `WARN` or `FAIL` for each element
into `native/godot/build/audit/<area>.txt`; all of them are in `run-tests.ps1`. A window is needed only for the layout and
picture audits.

| Tool | What it does |
|---|---|
| `audit-ui` | Opens every surface and tab (main menu, pause, settings, About, load, new game, the build list, the research tree, the Cabinet, the log, help, every tab of Diplomacy, Intel, Market, Territory, Defence, UN, letters, the end screen, the UN session, a diplomatic contact, a selection of each kind of building and unit) and presses **every enabled button once on a fresh copy**; fails on any engine or script error; warns when nothing visible changed |
| `audit-units` | Each unit: definition, plausibility against its class, where it is trained, which of the 28 nations fields it, spawns with a model in its element, hurts the class it is made for, never hurts its own side, goes where it is sent |
| `audit-orders` | The player's **attack order** for every armed unit, through the real order pipeline |
| `audit-buildings` | Each building: definition, a valid site, finishing, what it provides (seen in the economy), what it trains, demolish, save |
| `audit-missiles` | Each weapon: launcher, launch, flight, effect at the target, who may field it, the message when no launcher is ready |
| `audit-research` | Each discovery: definition, the whole tree in order, stated effects, effects seen in play, three researched for real |
| `audit-world` | 28 national powers, 16 espionage operations, 12 UN measures (voted and enforced), 8 world events, 10 crises, the victory paths, diplomacy |
| `audit-text` | Years, spelling, placeholders, lengths: every definition, every reason a player is told, every message in the scripts |
| `audit-physics` | What can exist (section 3.2) |
| `audit-matrix` | All 28 nations on 24 maps (each map and each nation at least once), two game minutes each, saved and checked |
| `audit-layout`, `audit-portraits` (a window) | 64 surfaces at 1280x720, 1600x900, 1920x1080 and at 80% UI scale; every picture |
| `alpha-check`, `carrier-check`, `crisis-check`, `fixes-1020-check` | The alpha infrastructure, the carrier, the crises, the previous report's fixes |

## 5. What the audits are not

An audit proves a thing works as written and is not absurd; it does not prove it is fun or balanced. Things only people
can judge: balance across 28 nations, the first hour's feel, whether the guide teaches enough. That is what the alpha is for.

## 6. Known issues for testers (also in `ALPHA-README.txt`)

- **Performance in the biggest battles** (about 130 units fighting): 16, 19 and 20 frames a second on this laptop's
  integrated graphics (Intel Iris Xe, 1920x1080, Balanced), against a goal of 25. The cost is the CPU (the simulation
  about 17 ms a step, about 1,700 draw calls), not the GPU. Not solved in this pass; the quality setting and fewer units help.
- Riflemen cannot hurt tanks (by design) and, with no anti-tank team, stand and die under tank fire instead of retreating.
- Tanks can stall for a moment in narrow gaps between buildings.
- The installer is **not signed**: Windows will warn.
- The infantry model is a Mixamo character: its terms of use should be checked before wide distribution.
- Chlorine bombs and the dirty bomb exist but **no nation fields them** by design (the research found no evidence of an inventory);
  a custom scenario can list them.
- UI scale above 100% on a 1280-pixel screen is not offered (the top bar would not fit).
- English only; Windows only; not tested on other graphics cards.
- The test suites measure wall-clock time: when the computer is busy or goes to sleep during a run, a suite can time out
  (`ux-fixes-check` in the first full run, `action-copy-check` and the nation/map matrix in the second) and then passes alone in seconds.
  They are listed in section 2 with what happened on the re-run.

## 7. Warnings the audits left (not defects)

**Every control** (91):
- Diplomacy / world [1] World map: nothing visible changed
- Diplomacy / stats [2] Statistics: nothing visible changed
- Diplomacy / orders [3] Orders: nothing visible changed
- Statistics / overview [2] Statistics: nothing visible changed
- Statistics / overview [4] Overview: nothing visible changed
- Statistics / gdp [5] GDP: nothing visible changed
- Statistics / growth [2] Statistics: nothing visible changed
- Statistics / inflation [2] Statistics: nothing visible changed
- Statistics / unemployment [2] Statistics: nothing visible changed
- Statistics / debt [9] Public debt: nothing visible changed
- ... and 81 more (in `native/godot/build/audit/ui.txt`)
**Every unit** (3):
- seaDrone: hp 60 vs class median 620 | sea, Sea Drone: speed 24.0 hp 60 dmg 240 range 10, cost 477; trained at shipyard; fielded by usa,china,eu,iran,russia,india...
- shahed: hp 35 vs class median 220 | air, Shahed Drone: speed 14.0 hp 35 dmg 110 range 8, cost 0; trained at -; fielded by iran,russia
- towedHowitzer: speed 2.3 vs class median 8.5 | foot, M777: speed 2.3 hp 160 dmg 62 range 62, cost 480; trained at tankFactory; fielded by usa,india,japan,uk,ukraine,australia
**The attack order, every armed unit** (4):
- corvette: the fixture put the air 49 m away, beyond its reach (28 m): not a finding
- destroyer: the fixture put the air 48 m away, beyond its reach (30 m): not a finding
- gunboat: the fixture put the air 56 m away, beyond its reach (22 m): not a finding
- landingShip: the fixture put the infantry 56 m away, beyond its reach (24 m): not a finding
**Every building** (1):
- specialLab: no valid site found round the capital (Not built by United States at the capital)
**Every weapon** (2):
- chlorine: no nation fields it by design (no evidence of a national inventory): only a scenario that lists it | Chlorine Bombs, dmg 20 radius 4 speed 70, cost { "money": 150, "iron"
- dirtyBomb: no nation fields it by design (no evidence of a national inventory): only a scenario that lists it | Radiological (Dirty) Bomb, dmg 300 radius 8 speed 70, cost { "money":
**The world** (9):
- brazil: Food Diplomacy: not usable in this setup (Needs a trade partner at peace)
- ukraine: Long-Range Drone Strikes: not usable in this setup (No buildings to strike there)
- afghanistan: Insurgent Attacks: not usable in this setup (No buildings to strike there)
- houthis: Coastal Shipping Pressure: not usable in this setup (Needs a live coastal drone battery)
- south_sudan: Oil Transit Agreement: not usable in this setup (Requires Sudan as transit partner)
- decapitationRaid: not open in this setup (Only against a nation at war with you, or relations below -50.): the leadership raid is for the United States against a weak government
- peacekeeping: adopted but no visible effect on the target
- ceasefire: adopted but no visible effect on the target
- default: needs a long depression and a ruined rating: not reached by this shortcut (see crisis-check)
**Every text** (4):
- hormuz: starts with a lower-case letter | about a fifth of the world's oil and of its LNG passes the strait; 69% of that oil goes to China, India, Japan
- recession: starts with a lower-case letter | a war between two of the world's largest economies breaks the trade that binds them
- nuclear: starts with a lower-case letter | the threat of nuclear war shakes the markets, and a nuclear explosion would stop the world's trade
- arms_boom: starts with a lower-case letter | three wars at once: the arms exporters' order books fill
**Every picture (a window)** (8):
- akinci: very small in its frame: 4.5%
- atgmTeam: very small in its frame: 2.7%
- carrierDrone: very small in its frame: 4.5%
- drone: very small in its frame: 5.5%
- fpvTeam: very small in its frame: 1.7%
- scoutHelicopter: very small in its frame: 5.6%
- solarFarm: very small in its frame: 4.1%
- towedHowitzer: very small in its frame: 5.4%

## 8. What changed in the tree

New: `build_info.gd`, `diagnostics.gd` (the alpha infrastructure); `tools/audit_kit.gd` and the 13 `audit-*.gd` tools;
`alpha-check.gd`, `carrier-check.gd`; `installer/ALPHA-README.txt`.
Changed (game): `war_tools.gd` (the air wing), `hud.gd` (wing row, stats, Help, briefs), `unit_overlay.gd` (reach rings, cargo badge),
`save.gd` (validation, version, wing), `menu.gd` (About, version link, settings), `world.gd` (display model, turretless death, carrier
stand-off, bombard), `world_stats.gd` and `stats_view.gd` (rating, published crises), `cabinet.gd` (your crises), `side_panels.gd`,
`un_session_screen.gd`, `brief.gd`, `force_catalog.gd`, `faction_arsenal.gd`, `gameplay_rules.gd`,
`data/map-seed1.json` (the speeds above), `gameplay_rules.gd` (oil kept at the capitals), `regime_change.gd` (the leadership-raid text, 424 to 395 characters).
Changed (tests): `weapons-live-100.gd` (the capital is kept alive; slow cruise missiles are waited for), `gameplay-campaign-100.gd` (`--from/--to` to run shares of the maps side by side), `audit_kit.gd` (a timeout is a failure), `audit-missiles.gd` (re-fires after an interception).
Changed (build): `project.godot` (1.0.0, label, file logging), `export_presets.cfg` (1.0.0.0, "DOMINION Alpha"),
`installer/dominion.iss` (label, alpha notes), `build-windows.ps1` (passes the label), `run-tests.ps1` (the new tests).
Docs: `README.md`, `FIXES-2026-10-20.md`, `COORDINATION.md`, this report.
**Not touched and not staged:** the browser build (`js/`, `css/`, `index.html`), `.uid` files, `audio/*.import`,
`quit.svg.import`, `territory.gd`, `tools/_*.gd` (development probes), the other tool's review folders.

## 9. After you approve

1. Stage only the files above (by name), pull first, commit, push to `origin/main`.
2. `build-windows.ps1 -Version 1.0.0` (the label ALPHA is read from `project.godot`); `verify-release.ps1`.
3. `run-tests.ps1 -Exported` (the 29 suites that run in the packaged game).
4. Install the installer silently into a temporary folder, start the game once, check the version and the logs folder,
   uninstall: the installer's own smoke test.
5. `gh release create v1.0.0-alpha --prerelease`, upload `DOMINION-Setup.exe`, `DOMINION.exe` and `release-manifest.json`
   (with checksums); `ALPHA-README.txt` is inside the installer and in the release notes.

If you want something changed first (a different name, hiding the version link), say so
before approving.
