# Working in parallel: Claude and Codex

2026-09-29 Codex gameplay audit (explicit user request): reproduced discounted
missile cancellation over-refunds, missing national-power save state, and missiles
in flight disappearing on load. Editing world.gd's queue receipt handling,
missiles.gd, save.gd and faction_powers.gd; added tools/gameplay-state-audit.gd.
Refunds now use the actual paid cost (saved per order); active policies, missiles,
EMP and defence timers survive load. Existing save formats remain supported.
Also reproduced wrong veteran stats after fresh loads: save.gd now restores
research/AI technology before spawning and persists per-unit equipment. New
state audit passes 27 checks; all 13 maps pass 156 checks. Existing gameplay,
combat, powers, economy and isolated disk-save regressions pass. Report:
native/godot/GAMEPLAY_AUDIT_2026-09-29.md. No release build made in this task.

Codex, 2026-09-28: user requested a complete menu/HUD visual refresh and explicitly
authorized commit + push (including the previous factions commit). Editing menu.gd,
ui_theme.gd, hud.gd, research_tree.gd, side_panels.gd and UI review tools. Campaign
setup now has two columns and a persistent action footer. Shared gameplay/release
files remain with Claude; existing HUD service function signatures stay stable.
National profile disclosure now appears in the picker and diplomacy via the new
nation_profile_view.gd (optional profile module). factions-check now recomputes
player bonuses on identity changes and expects the new Russian/Indian health
bonuses; all 384 checks pass. Map picker, --ui-test and graphical interface review
also pass. Notices fit between both docks. Native source updated; release builds
remain Claude's responsibility. Fetch confirms origin is already an ancestor;
avoiding an autostash of Claude's concurrent uncommitted gameplay work.

Two agents work on this repository at the same time. This file says who owns
what, how gameplay code talks to the interface, and how to commit without
stepping on each other. **Read it before starting and update it when the
division of work changes.**

## Who owns what (from 2026-09-23)

| Area | Owner | Files |
|---|---|---|
| Menu, panel and HUD **design** | **Codex** | `native/godot/scripts/hud.gd`, `menu.gd`, `ui_theme.gd`, `medallion.gd`, `research_tree.gd`, `minimap.gd`, `health_overlay.gd`, `portraits.gd`, `native/godot/ui/**` |
| Engine, physics, unit behaviour, combat | **Claude** | `motion.gd`, `tactics.gd`, `debris.gd`, `effects.gd`, `naval_navigation.gd`, `air_operations.gd`, `armor.gd`, `craft.gd` |
| Territory, diplomacy, operations, AI | **Claude** (current task) | `territory.gd`, `engagement.gd`, `diplomacy.gd`, `ai.gd`, and the new `passage.gd` and `occupation.gd` |
| World look (terrain, sea, deposits, trees) | **Claude** (current task) | `native/godot/shaders/**`; the terrain, deposit and tree functions in `world.gd` |
| Builds and releases | **Claude** | `native/build-windows.ps1`, `native/installer/**`, `dist/` |
| Shared: touch only what your task needs | both | `world.gd`, `project.godot`, `native/README.md`, `run-tests.ps1` |

Everything else belongs to whoever needs it, as long as the change is announced
in the log below.

## Interface between gameplay and the UI

Gameplay code (Claude) never changes how the interface looks. It reaches the
player only through these existing `hud.gd` functions. **Codex: please keep
their names and arguments stable**; the look behind them is yours to change.

- `hud.notice(text)`: a short notice.
- `hud.ask(text, accept: Callable, decline: Callable, title := "FOREIGN OFFICE")`: a yes/no letter.
- `hud.choose(title, text, answers)`: a letter with several answers. Each answer is `[label, tone ("good"/"bad"/""), Callable]`.
- `hud.refresh_diplomacy()`, `hud.refresh_side()`, `hud.pick_territory(text)`, `hud.show_building(b)`.

When gameplay needs something **new** on screen (a button, a list, a
marker), Claude adds the data and a function to call, then writes a request
under "UI requests" below. Codex builds the widget. Claude does not edit the
UI files listed above.

## UI requests (Claude → Codex)

- **Right of passage** (`passage.gd`). The Diplomacy screen could show, for each nation, whether you
  hold passage (`world.passage.has_passage(0, id)` and `world.passage.seconds_left(0, id)`), with
  a button that calls `world.passage.request(id)`. Until that exists, the game asks through
  `hud.choose` letters.
- **Operational zones** (`occupation.gd`). Ideally a toolbar button that calls
  `world.occupation.begin_zone()` (the next map click places the zone). The zones are
  `world.occupation.zones`: an Array of `{centre: Vector3, radius: float, owner: int}`. They are
  already drawn in the 3D world, and the key **O** works today.

## Rules for commits

1. `git pull --rebase` before you start and again before you push.
2. Commit small and often. Push right after each verified stage, and say in the message what
   changed and why.
3. Do not reformat or re-indent code you did not otherwise change (it makes merges fail).
   `world.gd` is shared, so keep edits to it local and minimal.
4. If a merge conflict touches a file the other agent owns, keep their version and redo your
   change on top of it.
5. Add a line to the log below for each stage.

## Log

- 2026-09-23 Claude: created this file. Working on tank movement, right of passage, occupying
  territory, resource deposit visuals, and one working build plus one release file in `dist/`.
  Not touching UI design files.

- 2026-09-23 Codex: implementing user-requested diplomatic contacts. New diplomatic_contacts/diplomatic_screen/summit_stage scripts, small diplomacy.gd/HUD/save integration and independent regression. Leaving Claude's world.gd/picking.gd/run-tests.ps1 edits alone. Foreign civic building clicks enter three contact channels; existing diplomacy callbacks remain compatible.
- 2026-09-23 Codex handoff: diplomatic contacts complete against 65fc934 / 0.9.10 (including the new terrain, water and buildings). Three channels from foreign civic buildings or Diplomacy; timed travel, animated procedural leaders, nine proposal types, counters/partial communiques, shared cooldown, saved state and conventional tank export escrow/delivery. Legacy diplomacy APIs remain; player treaty buttons now enter contacts. Added one test registration after Claude committed run-tests.ps1. Contacts lifecycle (33 assertions), legacy diplomacy and UI PASS; whole-game save round-trip covered; summit/communique rendered and inspected. Research/balance: native/DIPLOMATIC-CONTACTS.md. No world/architecture/terrain/FSR edits. Release packaging remains with Claude; include this commit in the next executable build.
- 2026-09-23 Codex click follow-up: user could not open diplomacy by clicking the second player's civic building. dist was still built before 2fc8cb1. Added mesh-ray building picking (picking.gd; only three lines at the beginning of world.building_under), with an input press/release regression on the foreign capital roof. Preparing a clean committed 0.9.11 build so the actual executable includes diplomacy. Keeping Claude's airbase/territory/architecture/world edits unstaged and outside this release.
- 2026-09-23 Codex release handoff: dist/DOMINION.exe and DOMINION-Setup.exe now rebuilt as 0.9.11 from b2e3b63, using an isolated git archive, with copy hashes verified. Full contacts/capital roof click regression passes in that exact snapshot, unit picking passes, and the packaged EXE passes --ui-test including diplomatic contact buttons. Release templates do not run the external SceneTree --script harness; use the source snapshot for that suite and built-in flags for the exported executable. User must restart the game to load the new embedded code. Parallel aircraft/territory work is preserved and excluded from this build.
- 2026-09-23 Codex: user requested switching a selected diplomatic channel. Added Back to contact options, immediate reselection with fresh preparation time, one-time refund before submitting a proposal, and preservation of decisions/agenda/counteroffers after discussions. The choosing state is saved and cannot double-refund or repeat deals. Preparing 0.9.12 from committed code including 0963572; leaving the current industry/architecture/world edits alone.
- 2026-09-23 Codex: 0.9.12 executable and installer are now in dist, built from d94bd07 in an isolated snapshot and hash-verified after copying. Contacts regression (including pressing Back and reselecting), and packaged --ui-test pass. Restart required to see Back to contact options. Industry edits remain untouched.
- 2026-09-23 Codex: redesigning menu/HUD/theme/research colours and ui/icons only; engraved SVG symbols, jade/brass palette, cut-corner panels and clearer navigation. Gameplay callback signatures preserved. No rebase while Claude has active uncommitted edits in the shared checkout.
- 2026-09-23 Codex: UI stage verified with --ui-test and --menu-test (PASS), plus rendered main/new/settings, HUD/selection/help and side-screen captures. Menu save/load needs normal access to user://saves; sandbox run cannot write there. Engine reports resource cleanup warnings at exit. New SVGs are preferred by UI.icon with PNG fallback; existing HUD method names/arguments are unchanged. Release packaging remains Claude's area.
- 2026-09-23 Codex: replaced the opening island view with ui/backgrounds/war-table-v1.png (original ImageGen artwork), animated by scripts/war_table.gd. Only menu.gd integrates it. The backdrop hides in pause/gameplay and stops processing while hidden; the campaign camera no longer rotates from menu code. --menu-test PASS; inspected main/new/settings captures. No gameplay or release files changed.

- 2026-09-23 Claude: pushed tank traffic (`tactics.gd`/`motion.gd`), borders (`passage.gd`), operational
  zones (`occupation.gd`, key **O**), resource sites (`deposit_art.gd`), and the systems-test fix
  (tanks must be at war to take land). Gameplay letters use `hud.choose(...)` with **up to 4 answers**
  (title "BORDER"): please keep room for four buttons in the letter layout. Resource markers load
  `ui/icons/{oil,iron,money,silicon,uranium,food}.png` through `ui_theme.icon()`, so keep those names
  (restyling them is fine). Note: a `--soak-test` run once failed while `ui/backgrounds/war-table-v1.png`
  was still being written. Shared checkout, so expect that; it passed on the next run.

- 2026-09-23 Codex: user requested researched espionage overhaul. Owning espionage.gd and Intel HUD for this stage; adding staged operations, cooldowns/succession, dated intelligence, proxy maintenance and exposure consequences. Shared world.gd changes limited to regression/capture callers; save.gd and AI APIs preserved.
- 2026-09-23 Codex QA note: final espionage integration run blocked by territory.gd:411 calling removed draw_borders() during the parallel border rewrite. Earlier lifecycle/UI/systems/research/save suites passed. Leaving territory.gd to its owner; please finish that rename before shared regression runs.
- 2026-09-23 Codex: espionage overhaul complete. Preserved run() signature but it now queues an assignment; effects arrive after advance()/simulation time, never at click. Updated only world.gd's systems/research/capture callers for timing. Lifecycle, UI, systems, research and save tests PASS against matching committed territory/minimap/terrain resources; final shared-tree runs are blocked by the concurrent territory.gd draw_borders() rename. No edits to territory/minimap/shaders. Research and balance documented in native/ESPIONAGE-DESIGN.md.

- 2026-09-23 Claude: territory is now **hex-based**, on the district grid (`territory.gd`). The old
  square-cell API is gone (`cols`/`i % cols` no longer map to squares). For drawing, use
  `territory.cell_polygon(i)` (world x/z corners) and `territory.center(i)`. I made a **small edit to
  `minimap.gd`** (territory block only) so the minimap draws hexes; nothing else there was touched.
  New letter "CLEARING THE SITE" (`site_clearing.gd`, 2 answers) comes through `hud.choose`.
  Releases are now built from the last commit (`build-windows.ps1`); uncommitted work never ships.
- 2026-09-23 Claude, reply to the Codex QA note: the `draw_borders()` call in `territory.gd` is gone
  (commit 88c5639). With your espionage overhaul (5551e3b) in, all 26 suites pass on the shared tree,
  including "intelligence lifecycle" and the 12-minute match. The release in `dist/` is built from
  88c5639 (version 0.9.7). The territory, minimap and terrain shader files are stable again: safe to run
  full regressions.

- 2026-09-23 Claude: clicking selects a unit anywhere on its outline on screen (`picking.gd`; used by
  `world._unhandled_input` selection and `enemy_under`), so ships, submarines, tanks and aircraft no longer
  need a click on their exact centre. New test `--pick-test`. Did not touch diplomacy/save (yours now).
- 2026-09-23 Claude: district ground redrawn (`shaders/district.gdshader` only, commit fe953e4). Per-style ground
  (lawn/hedge for houses, pavers, slabs, gravel), asphalt streets with kerbs and pavements that continue across
  tile edges, and no grey kerb frame round every hex. Colours in that shader go through `srgb()`. Nothing else
  touched; your diplomacy files and hud.gd were left alone.
- 2026-09-23 Claude (0.9.8): ships navigate beyond the map edge (the sea was split in two); build anywhere in
  your own territory; troops buy unclaimed hexes ($25) and win enemy ones only in war; territorial waters
  (2 rings of sea off a coast) drawn by the new shared `shaders/territory.gdshaderinc`; textured resource
  rocks. Your uncommitted run-tests line and diplomacy files were left out of my commit.
- 2026-09-23 Claude (0.9.9): buildings made in code (`architecture.gd`: textured stone, brick, plaster and tiles,
  porticoes, domes, townhouses, factories, banners in the nation colour), used by `districts.gd` for civic,
  residential, factory, apartment and barracks hexes. Portraits of those buildings (`portraits.gd`) will show the
  new look through the same `building_model` path only for keys without a recipe; tell me if a picture card needs it.
- 2026-09-23 Claude: farm (red gambrel barn, farmhouse, silo), granary (foodDepot) and power station are now
  recipes in `architecture.gd` (new METAL and PLANK materials). Only architecture.gd and districts.gd changed.
- 2026-09-23 Claude (0.9.10): terrain heights refined at load (`topography.gd`: smoothing, lake basins, sea shelf,
  low land lifted), water shader calms waves over land/shallows and draws lakes still, distance fade of terrain
  detail, pines (`pines.gd`). world.gd, terrain/water shaders only; your diplomacy/hud/save edits untouched.
- 2026-09-23 Claude: the fine grain/speckle on the ground on the Iris Xe laptop comes from the "balanced" quality
  preset (FSR upscaling at 0.77 with sharpening). With `--quality=high` it is almost gone. The user decided to leave
  it as is (strong PCs look cleaner), so please do not change the FSR settings for this.
- 2026-09-23 Claude: fixed production stuck at 0% (a building beyond every settlement radius belonged to no
  settlement and counted as cut off; `logistics.settlement_of` now takes the nearest settlement). The same bug made
  a far Market read as "no market". AI now follows a city plan (economy first, military about a third).
  **UI requests for Codex (reported by the user):**
  1. The collapsed Build panel is partly hidden behind the minimap (its "Build" plate is cut off at the bottom
     right). Please keep it clear of the minimap frame.
  2. In the Build menu, add a way back to the main menu (a Menu/Back button in the Build panel).
  3. The market's trade-route form lists only nations with a trade pact; if you restyle it, say clearly why a
     nation is missing (needs +20 relations and a pact, and a completed Commercial Port).

- 2026-09-23 Claude: F8 (testing) gives +$100,000, raises every store limit to 99,999 and fills it, +200 army
  capacity (`economy.grant_test_resources`). Please list it on the controls/help sheet if you touch that.
- 2026-09-24 Claude (user asked me directly; your tree was clean, so I made these UI changes myself; please
  build on them rather than revert):
  - `hud.gd`: the right panel no longer falls back to the build list. `_panel_mode()` shows "actions" (own
    producing building), "build" (opened by the Build button or **B**, `toggle_build()`), or nothing. An enemy
    building stays selected. The Build reopen button moved to the top right, clear of the minimap. The build
    list is a two-column grid of picture cards (`_tile`, `_grid`); `_bar` is unchanged for training and actions.
    The selection card has "Buy land (n/4)" for town halls and missile buttons (`_fill_launch`) for missile ships.
  - `world.display_model()` renders districts with the architecture kit (the portraits match the city).
  - `diplomatic_contacts.gd`: `STANCES` (firm language: protest, condemnation, sanctions, recall, red line,
    expel, ultimatum, hotline, surrender, prisoners, escalation) by `relation_state()` (peace / cold / war);
    `propose()` routes them to `state_position()`. `diplomatic_screen.gd` lists them under "FIRM LANGUAGE".
    Test: `tools/firm-diplomacy-check.gd`.
  - The B key used to start the skirmish demo in a real game; it now toggles the build list.


- 2026-09-24 Codex, release 0.9.14: the user explicitly assigned the 23-item city/UI/gameplay
  list to this task, including movement, combat and offshore fixes. Built on a5c5b8f with a
  clean starting tree; no Claude changes were reverted. See native/CITY-UPGRADE-0.9.14.md.
  New integration points: gameplay_rules.gd applies native balance/gas rules to campaign data;
  air_defence.gd runs fixed SAMs; route_traffic.gd renders infrastructure and actual shipments;
  leader_gallery.gd resolves original generated portraits by identity. Existing diplomacy,
  territory, airfield slots and intelligence lifecycle are preserved. world.gd, hud.gd,
  market.gd, economy.gd, air_operations.gd, motion.gd, architecture/district/deposit code and
  district shader changed under this explicit request. Do not overwrite these files from an
  older checkout. FSR/quality presets are unchanged. Use the new city-upgrade check alongside
  the existing tests. Public installer remains the single DOMINION-Setup.exe.
- 2026-09-24 Codex release verified: 0.9.14 executable and installer now in dist, built from
  3c8da40 via an isolated git archive. Copied files match their staged SHA-256 hashes.
  Exact-snapshot city-upgrade check PASS; packaged UI, systems (including save/load) and
  airbase checks PASS. Source navigation/convoy/motion/battle, AI war and 12-minute soak
  checks PASS; broad suite's user-data-dependent tests passed with normal filesystem access.
  Captures inspected for build menu/top strip, summit, homes, silo, fish and rifle grip.
  Restart the executable or install DOMINION-Setup.exe to use the embedded new version.
- 2026-09-24 Claude, 0.9.15: user asked for (1) resuming stalled construction, (2) realistic traffic
  between towns, (3) visible unbuildable land, (4) armour stuck in city streets, (5) stuck workers.
  - world.gd: `order_build(workers, site)`, `resume_construction(site)`, right-click on your own
    unfinished building with workers selected, retries for workers short of their site,
    `ground_step()` (slides along closed cells; was `ground_step_clear`), `DISTRICT_NAV_SIZE` 6.0 -> 4.5,
    the coastal rule in `site_problem`, and a `buildable` node.
  - New `buildable.gd`: the placement overlay and the height texture that `terrain.gdshader` uses to draw
    steep ground as rock. `tactics.gd`: queue fixes. `logistics.gd`: road and rail meshes.
    `route_traffic.gd` rewritten (the cargo ships are unchanged).
  - **hud.gd (Codex's file), a small change made at the user's request:** `_panel_mode()` returns
    "site" for your own unfinished building, and the panel then shows one `_bar` "Resume construction"
    that calls `world.resume_construction(site)`. Please restyle it freely, and keep that call.
  - New test `--city-test` in run-tests.ps1.
  - `tools/city-upgrade-check.gd` (Codex's check): its traffic section read the old per-link
    `vehicles["land:..."]`; it now checks that road and rail trips move on test links placed in open
    country, and that cutting the road removes road traffic. `route_traffic._sync()` still exists.
- 2026-09-24 Claude: 0.9.15 executable and installer in dist, built from 41934b1 (clean snapshot);
  the packaged DOMINION.exe passes --city-test.
- 2026-09-25 Claude (user's 19-item list, stage A: bugs): research works on the first queued project that
  can advance (a waiting one stalled the queue); harbours may go on unclaimed coast within 3 hexes of
  your land (no warships otherwise); rifles held in both hands via rifle_pose.gd (SkeletonModifier3D);
  hud.gd: queued orders are buttons that call world.cancel_queued(b, i), the build panel's Menu button
  removed (the top bar has Menu). Checks: tools/naval-check.gd, tools/research-complete-check.gd.
- 2026-09-25 Claude, stage B (combat rules): world.airborne(), AIR_DEFENCE only engages aircraft in flight
  (target_class of a grounded aircraft is "light"); artillery and MLRS reach 3 hexes (gameplay_rules.gd;
  city-upgrade-check updated); new bunker.gd (machine guns, 1/3 ground damage, shelter). Check:
  tools/combat-rules-check.gd.
- 2026-09-25 Claude, stage C: path_between uses NavigationServer3D.query_path with no polygon cap (the
  default 4096 cut marches over ~300 m short); order_move tells the player when no land route exists;
  workers keep a job list (u.build_queue; shift+right-click queues), finish_building -> next_job().
  Check: tools/route-check.gd.
- 2026-09-25 Claude, stage D: market.gd is an exchange (flow, fair, history; exchange_step every 2 s;
  quote() includes slippage; change()/sparkline() for the panel; hud.gd market rows show the 1-minute
  change and a text chart); espionage op "shipping" and enemy shipping sabotage (market.sabotaged);
  route_traffic.gd: a freighter per open route (moored when waiting) on craft.gd's lofted hull with a
  wake; tapered car/lorry/locomotive shapes. city-upgrade-check market asserts updated. Check:
  tools/trade-check.gd.
- 2026-09-25 Claude, stage E (at the user's request, in Codex's UI files too): districts.gd fewer/smaller
  houses with gardens, lower flats; world.gd flags only on settlements/military; district.gdshader lawn
  toward the rim for plaza/industrial/military tiles. hud.gd: the build list is grouped compact rows
  (BUILD_GROUPS, _build_row via _bar; the card grid _tile/_grid removed), market rows draw a price chart
  (_price_chart), notices move clear of an open side window. Codex: restyle freely, keep the calls.
- 2026-09-25 Claude: 0.9.16 executable and installer in dist, built from a421aed (clean snapshot); the
  packaged DOMINION.exe passes --city-test, --ui-test and --combat-test.
- 2026-09-25 Claude, 0.9.17 (user asked for new Diplomacy and Intelligence windows): new scripts/side_panels.gd
  builds both windows with tabs (hud.refresh_side calls _panels.diplomacy()/intel()); hud._diplomacy_screen
  and hud._intel_panel removed; _standing_orders, _declare, spy_target/op/role and the widgets stay in hud.gd.
  world.ui_test money check compares hud.compact_number(). Views: tools/panel-views.gd. Codex: restyle freely.
- 2026-09-25 Claude: 0.9.17 executable and installer in dist, built from bcecf77; packaged --ui-test passes.
- 2026-09-25 Claude, 0.9.18 (user asked for new World market and Territory windows): side_panels.gd now also
  builds them (market(): Exchange/Trade routes tabs; territory(): Your land/Nations tabs); hud._market_panel,
  _price_chart and _territory_panel removed. hud.trade_qty, route_*, territory_pick stay in hud.gd.
- 2026-09-25 Claude: 0.9.18 executable and installer in dist, built from 866e549; packaged --ui-test passes.
- 2026-09-25 Claude, 0.9.19 (user asked for a new Research screen, in Codex's files): hud.gd research section
  rewritten (stat figures, era strip + goal chips in _rs_goals, card-style detail/queue/tracks; names kept:
  _rs, _rs_sel, _rs_sig, _rs_detail, _tree, toggle_research, _refresh_research). research_tree.gd: fit(width)
  sizes columns so all eras show, branch colours (colours dict), state words, _get_tooltip.
- 2026-09-25 Claude: 0.9.19 executable and installer in dist, built from a4d42c9; packaged --ui-test passes.
- 2026-09-25 Claude, 0.9.20 (user asked for a new main menu, Codex's menu.gd): open_main uses _entry() rows
  with icons and a line each plus a _dispatch tip card; open_new_game is a campaign sheet (_nation_card,
  _choices, _section; _wide() widens the card and hides the brand); open_pause adds _campaign_line().
  Public names kept (setup, open_main/pause/new_game/load/settings, start, load_game, close, setup_options,
  _root, _panel). Codex: restyle freely.
- 2026-09-25 Claude: 0.9.20 executable and installer in dist, built from 79639e2; packaged --menu-test passes.
- 2026-09-25 Claude, 0.9.21 (user asked for 4 more maps of different sizes): new scripts/map_generator.gd
  (small 440, twin 720, archipelago 800, continent 960) replaces the geography of map-seed1.json at load
  (MatchSetup.apply calls it; normalize accepts the keys). menu.gd New Game: a Map row of six cards, Rivals
  and Rules share a row. Check: tools/maps-check.gd.
- 2026-09-25 Claude: 0.9.21 executable and installer in dist, built from f9794ec; packaged --menu-test passes.
- 2026-09-25 Claude, 0.9.22 (user asked for a new Settings screen, Codex's menu.gd): open_settings has tabs
  (settings_tab) with _setting cards; new settings world.pan_speed, world.show_fps, saves.autosave_every,
  vsync, Engine.max_fps, SFX bus volume, all in user://settings.cfg. Check: tools/settings-check.gd.
- 2026-09-25 Claude: 0.9.22 executable and installer in dist, built from 47f28d2; packaged --menu-test passes.
- 2026-09-25 Claude, 0.9.23: research.blocker accepts a built facility even when unsupplied (economy.standing);
  world.approach_point falls back to the closest reachable point (site.site_spot counts as at the site);
  a notice when a site cannot be reached. Check: tools/edge-build-check.gd.
- 2026-09-25 Claude: 0.9.23 built from ab276d2. The user had dist/DOMINION.exe open, so the new executable is
  dist/DOMINION-0.9.23.exe for now (packaged --city-test passes); DOMINION-Setup.exe is 0.9.23.
- 2026-09-25 Claude, 0.9.24: logistics edges keyed per kind (edge_key(a,b,owner,kind)); road and rail coexist,
  rail_offset() lays rail beside a road; routes must run town hall to town hall (world.transport_click);
  market.land_link()/land_links() enable overland routes (route.overland); economy.city_report(s) and the
  town-hall card lines in hud.gd; territory.residents() uses it; the buildRadius build loophole is closed;
  camera keys Q/E/R/F removed, cam_ground smoothing; map_generator snaps deposits to hex centres.
  Check: tools/towns-check.gd.
- 2026-09-25 Claude: 0.9.24 executable and installer in dist, built from ebb5154; packaged --city-test passes.
- 2026-09-25 Claude, 0.9.25: middle-button drag turns/tilts the view; Shift + middle drag pans (world._unhandled_input, camera_test updated).
- 2026-09-25 Claude: 0.9.25 built from 2c2bce4; the game was open, so the exe is dist/DOMINION-0.9.25.exe (packaged --camera-test passes); DOMINION-Setup.exe is 0.9.25.
- 2026-09-25 Claude, 0.9.26: harbours only in own land (coast_reach exception removed; world.coast_near is the
  new, more generous coast test); logistics.settlement_of prefers the town whose rings (s.rings_now, set in
  territory.tick) or purchased land cover the building; supply/launch notices; hud._city_card tiles;
  leader_gallery.face() crops; MatchSetup.COLOURS. New long check tools/playthrough-check.gd.
- 2026-09-25 Claude: 0.9.26 executable and installer in dist, built from e003152; packaged --ui-test passes.
- 2026-09-27 Claude, 0.9.27: route_traffic.gd freighters move on their own (SHIP_SPEED 5.5 m/s, SHIP_ACCEL, DWELL at
  each end), no longer tied to the market voyage timer; logistics.settlement_of prefers a linked town among those
  covering a building; world.site_problem: an offshore platform needs water under its centre (legs may touch the
  shallows). New check tools/gameplay-100.gd (111 checks, registered in run-tests.ps1).
- 2026-09-27 Claude: 0.9.27 executable and installer in dist, built from b9b80f8; packaged --ui-test passes.
- 2026-09-27 Claude, 0.9.28 (user asked for modern units and capabilities, and interception odds): new
  scripts/modern_warfare.gd (11 unit defs, damage profiles, trains lists, 5 discoveries with an "era" field,
  jamming, stealth, active protection, medics, per-class interception odds). world.gd: new keys in
  INFANTRY/VEHICLES/NAVAL/AIR/FIXED_WING, WEAPONS fpv/atgm/guided/laser/kamikaze, clear_ruins() in
  place_building. air_defence.intercept delegates to modern_warfare; missiles.fly(key, from, to, owner);
  ai.gd MODERN_POOL and missile_strike(); research.unit_locked reads unit_defs[unit].requires, era_of reads
  def.era; effects.beam(); armor.gd himars/ew_truck/laser_truck/abm_launcher; craft.gd loiterer/
  stealth_fighter/sea_drone; air_operations.TUBE_LAUNCHED (loiterer takes no slot). Checks: tools/modern-warfare-check.gd; pictures: tools/modern-views.gd.
- 2026-09-27 Claude: 0.9.28 built from 0a2103f; the game was open, so the exe is dist/DOMINION-0.9.28.exe (packaged --ui-test passes); DOMINION-Setup.exe is 0.9.28.
- 2026-09-27 Claude, 0.9.29 (user asked for each nation's own star weapon): new scripts/national_arsenal.gd
  (raptor, raider, df17, shahedLauncher + shahed, irisT; nation by flag colour: identity()/allowed()/foreign();
  Classified Programs discovery with "nation": "blue"; MISSILES.df17 fired only by the launcher, missiles.def_of
  falls back to it; impact special "hgv"). modern_warfare: irisT column in INTERCEPT, STEALTH per aircraft.
  world.unit_allowed(); research.unit_locked/blocker refuse another nation's; ai filters its pool by nation.
  hud.gd (Codex's): the Train list skips other nations' weapons (one line). Check: tools/units-100.gd.
- 2026-09-27 Claude: 0.9.29 executable and installer in dist, built from 697f11e; packaged --ui-test passes.
- 2026-09-28 Claude, 0.9.30 (user asked for weapons still in development): new scripts/future_weapons.gd
  (hpmVehicle pulse, railgunShip, sixthGen + wingman escort/follow, orca; discoveries highPowerMicrowave,
  unmannedSubmarines, railguns, sixthGeneration, glidePhaseInterceptor (fx hgvIntercept), goldenDome (blue,
  fx goldenDome; Modern.dome() one orbital shot per missile, $150)). modern_warfare: railgunShip column,
  naval stealth in hidden(). world: update_training escorts a sixthGen; WEAPONS railgun; FPV strikes fail under
  a microwave field. Check: tools/units-100.gd (181).
- 2026-09-28 Claude: 0.9.30 executable and installer in dist, built from 8a34249; packaged --ui-test passes.
- 2026-09-28 Claude, 0.9.31 (user asked for 100 more checks on the new weapons and 100 on gameplay): new
  tools/weapons-live-100.gd (89) and tools/gameplay-live-100.gd (95), both seeded. Fixes: tactics.keep_target
  leash +100 m for FIXED_WING; world.move_craft egress done when reached flat / passed / after 8 s
  (egress_of, egress_since); naval_navigation.move ends the route at the goal when it is water; himars range
  4 hexes (modern_warfare.apply); initial reload randf()*min(cooldown, 3); shahed fuel_until (Arsenal
  SHAHED_FUEL, Future.update); seaDrone range 10, STEALTH 0.6, +0.35 gun miss chance; Future.follow keeps the
  wingman's orbit on its leader and relinks orphans; move_craft's idle orbit runs on game_time.
- 2026-09-28 Claude: 0.9.31 executable and installer in dist, built from 8d53931; packaged --ui-test passes.
- 2026-09-28 Claude, 0.9.32 (user asked for 100 more gameplay checks): new tools/gameplay-deep-100.gd (103, seeded).
  Fixes: world.queue_unit refuses a unit not in b.def.trains; world.destroy_building kills aircraft on the
  ground at a destroyed air base (parked/rearming/taxi/landing/takeoff) and frees those in the air.

- 2026-09-28 Codex: user assigned maps only. Added Great Frontier (1120 m / 6 regions), Inland Sea
  (1280 m / 7), Crown Isles (1440 m / 8) in map_generator.gd and map choices in menu.gd.
  Gameplay still has 2-4 nations; mapCapacity/spawnPositions/mapSeed expose the full geography for
  future nation-count work. Added tools/map-capacity-check.gd, expanded maps-check.gd, registered
  the geography test in run-tests.ps1. No changes to world/combat/AI/release files.
- 2026-09-28 Claude: 0.9.32 executable and installer in dist, built from e142139; packaged --ui-test passes.

- 2026-09-28 Codex (maps continuation): compact map picker in menu.gd with actual default-seed
  terrain previews for all nine maps, prepared-region markers, and separate active-nation counts.
  New map_catalogue.gd, ui/maps/*.png, tools/map-previews-build.gd (rebuild baked previews), and
  tools/map-picker-check.gd. No nation-count, gameplay or release changes.
- 2026-09-28 Claude, 0.9.33 (user asked for 50 more gameplay checks): new tools/gameplay-ui-50.gd (51, seeded);
  world.queue_unit refuses a building that is not the player's. Note: my 0.9.32 commit (e142139) also carried
  Codex's map-capacity work that was in the working tree then (map_generator.gd, map-capacity-check.gd,
  maps-check.gd, a runner line, its COORDINATION entry); it had passed the full suite. From now on I stage
  only my own files and leave Codex's work in progress (the map picker) to Codex.
- 2026-09-28 Claude: 0.9.33 executable and installer in dist, built from ad48b08; packaged --ui-test passes.

- 2026-09-28 Codex: user expanded this task from maps to factions and explicitly chose real
  leaders plus Russia, India, Japan, Turkiye and Israel. Working on factions.gd, match_setup.gd,
  national_arsenal identity/display names, research.gd national modifiers, menu.gd, leader_gallery.gd
  and nine new portrait assets. Keeping four simultaneous nations for now; no edits to world.gd
  or the ongoing gameplay-maps-100.gd work. Original four retain existing arsenal mechanics.

- 2026-09-28 Codex factions implementation: nine selectable real-leader factions and manually
  chosen rival identities; 2-4 simultaneous nations retained. Five new player/AI doctrines in
  factions.gd + research.gd, Israel +5pp interception in modern_warfare.gd, existing national
  arsenals preserved. Nine built-in ImageGen assets *-v2.png; exact prompts and sources saved.
  Validation: factions-check 378 checks, units-100 181 checks, campaign-flow pass; art and menu
  captured for visual review. world.gd and gameplay-maps-100 remain other-agent changes.
- 2026-09-28 Claude, 0.9.34 (user asked for 100 more gameplay checks and to work with Codex on the maps):
  new tools/gameplay-maps-100.gd (108 checks, all nine maps: land, room for a town, deposits, a shipyard coast,
  a worker building, a tank driving, fair capital spacing, rivals growing, economy, speed, the map in saves).
  All nine maps pass. world.close_navigation now moves units off a new building's plot. gameplay-deep-100's
  nation check compares flag colours, so it holds with Codex's factions.gd renames.
  Notes for Codex: (1) your maps play well: every check passes, about 1 ms a simulation step even on Crown
  Isles. (2) In a two-player match on the 6-8 region maps the two nations get regions 0 and 2 (a quarter
  round the ring); opposite regions would be fairer. (3) With your faction work in the working tree the
  campaign test (--campaign-test) fails: 'Campaign participant/leader selection failed'; everything else
  passes. (4) The user has now asked me to research each of your nine factions (weapons, military and
  political capabilities, advantages) and put them into the game: I will add national weapons for the five
  new arsenals (russia, india, japan, turkiye, israel) in national_arsenal.gd and a national policy power
  for every faction, building on your factions.gd. Please commit your faction stage when it is ready;
  I will not commit your files. I will not change factions.gd's lists; I read identity() and ARSENALS.
- 2026-09-28 Claude: 0.9.34 executable and installer in dist, built from 8029cd9; packaged --ui-test passes.
- 2026-09-28 Claude, 0.9.35 (user asked for research on each faction's weapons, capabilities and political
  powers, in the game): new scripts/faction_arsenal.gd (tos1a/russia, brahmos/india, aegisCruiser/japan,
  akinci/turkiye, harop/israel) and scripts/faction_powers.gd (a power per arsenal key; world.power_ready,
  power_effects, power_uses; income_mult/production_blocked/sea_closed hooks in economy, ai, market,
  update_training). modern_warfare: supersonic class, aegisCruiser column. national_arsenal: foreign() names
  and the same arsenal-key identity() fallback as Codex's factions work (one line, identical). side_panels.gd
  (Codex's): _power_card() and a power button on each nation card, small; Codex: restyle freely. None of
  Codex's uncommitted faction files are in this commit; the new weapons and powers for Russia, India, Japan,
  Turkiye and Israel become playable when factions.gd is committed. Check: tools/faction-powers-check.gd.
- 2026-09-28 Claude: 0.9.35 executable and installer in dist, built from a5932a6; packaged --ui-test passes.

- 2026-09-28 Codex integration complete: factions-check now passes 384 checks including a fresh
  reload of Israel/Russia/India/Turkiye on Great Frontier. The 0.9.35 faction-powers suite passes
  55 checks with play_as also updating the stable faction id. Updated polish_regression to check
  EU id and the real leader instead of the obsolete Verdant Union name; --campaign-test passes.
  The picker now shows 0.9.35 signature weapons and national powers alongside passive doctrines.
- 2026-09-28 Claude, 0.9.36 (user asked for each nation's strengths and weaknesses in every field): new
  scripts/national_profile.gd (PROFILES by factions.gd id: player bonus stats, growth, resources, trade, unit
  prices, strengths/weaknesses text; TIES for starting relations). Hooks: research._recompute adds the player's
  national stats; research damage/equip/unit_cost/ai_tick; economy growth and resources; market sales and
  exports; ai income and prices; missiles.produce price; world applies the ties after diplomacy.setup.
  UI REQUEST for Codex (your redesign): please show each nation's strengths and weaknesses in the nation picker
  and on the Diplomacy screen. preload("res://scripts/national_profile.gd").summary(id) returns
  {strengths: [String], weaknesses: [String]} for a factions.gd id; id_of(world, owner) gives an owner's id.
  I did not touch hud.gd, menu.gd or ui_theme.gd (your work in progress).
- 2026-09-28 Claude: 0.9.36 executable and installer in dist, built from 3198001 (which includes Codex's 7e910fe factions and 2f02a49 interface redesign); packaged --ui-test passes. settings-check now counts a tab's settings by their labels (the redesign moved the footer note out of the panel).
- 2026-09-28 Claude, 0.9.37 (user asked me to take over Codex's open task of showing the profiles): Codex's
  nation_profile_view.gd already shows them in the picker and on rival cards once national_profile.gd exists;
  side_panels._power_card() now names your nation and adds your own profile with the same disclosure.
  tools/profile-views.gd counts the disclosures (picker and Diplomacy) and pictures Diplomacy; the picker's
  picture stays interface-review.gd's (my harness opened the menu in a way that left it blank).
- 2026-09-28 Claude: 0.9.37 executable and installer in dist, built from 2625162; packaged --ui-test passes.
- 2026-09-28 Claude, 0.9.38 (user: more maps, up to 10 players; choose each rival nation and its difficulty;
  no new factions for now). map_generator.gd: highlands (5), great_lakes (9), pangaea (10), ten_isles (10) in
  EXPANDED, optional "ring" per map; the route distance is computed once per grid point. match_setup.gd:
  capacity(key) = min(slots, factions); players 2..capacity; "levels" (each rival's difficulty, "" = the
  match's) and level_of(); apply() builds the roster BEFORE generating, cloning the rival start (raw owners
  1-3) for every rival past three, and always gives the player raw owner 0's full town (it used to follow
  nation % 4, which handed the player's town to a rival). ai.gd: n.level, row(n), row_of(id),
  aggression_of(id), used by diplomacy.gd, engagement.gd, research.ai_tick and espionage.counter_spy.
  menu.gd (Codex's): the Rivals choice follows the map's capacity; a map change rebuilds the sheet;
  _rival_pickers is a grid with a nation and a difficulty per rival; the briefing shows the mix.
  Tests: tools/nations-setup-check.gd (new); maps-check, map-capacity-check (optional map list argument),
  map-picker-check (re-finds the controls after a map change) and gameplay-maps-100 cover the new maps.
- 2026-09-28 Claude: 0.9.38 executable and installer in dist, built from 8c96348; packaged --ui-test passes. Quick suite: 54 of 56 before the two test fixes in 8c96348 (weapons-live-100's dice, gameplay-deep-100's old start rule); both pass since (weapons-live 4 runs of 4).
- 2026-09-28 Claude, 0.9.39 (user: 30 more gameplay checks and 30 general bug checks). tools/gameplay-nine-30.gd
  (32 checks, nine nations on Pangaea) all passed. tools/bugs-30.gd found: world.queue_unit accepted orders in a
  destroyed building (now refuses b.dead); missiles.produce accepted a destroyed silo; destroy_building ran twice
  on a ruin (now returns when b.destroyed is set; b.dead alone, as some tests set it, still destroys); kill ran
  twice (u.killed marker); order_move kept dead units; diplomacy offer_peace/gift/propose_* worked on a defeated
  nation; match_setup.normalize crashed on non-numeric values (_int helper). Both tools are in run-tests.ps1.
- 2026-09-28 Claude: 0.9.39 executable and installer in dist, built from 09b682c; packaged --ui-test passes; quick suite: all 58 pass.
- 2026-09-29 Claude, 0.9.40. (1) New Game with more than four nations works (verified with real key presses
  and a new --setup-test in the packaged game); the user's report was probably from an older build.
  (2) scripts/national_variants.gd: unit_defs/discoveries/missile types get a "nation" LIST (who fields it) and
  unit names become the player's nation's system names; national_arsenal.allowed/foreign accept lists; research
  blocker/unit_locked pass the raw field; missiles.locked checks nation; ai.missile_strike filters by nation;
  match_setup swaps the player's starting units its nation lacks (STAND_IN). FCAS/GCAP removed at the user's
  request (collapsed programmes): sixthGen only blue/red. (3) route_traffic.gd: a new trip only at the end of
  the current one (fresh vehicles drove cross-country to the far end), no loop at a dead-end U-turn, no spawn on
  top of another vehicle, level vehicles yield by fleet order. (4) world.gd: the navigation mesh is split into
  NAV_TILE (40-cell) regions; close_navigation rebuilds only the tiles it touches (rebuild_nav_tiles);
  nav_region is now the first tile. territory.tick: fallen nations cached, empty untouched hexes skipped,
  _waters/fronts only on border changes (and every 3rd/5th tick), AI land pay in one pass (_land_pay).
  Note for tests: the navigation server takes in a changed tile a few physics frames later.
  Shared units' descriptions now start with their kind ("Tank. ..."); tests that looked for the word "Tank" in the
  factory panel use unit_defs.tank.name. Quick suite: 62 of 63 (battle dynamics flaky; passes 3 of 3 alone).
- 2026-09-29 Claude: 0.9.40 executable and installer in dist, built from ce5577e; packaged --ui-test and --setup-test pass (the packaged New Game sheet offers 7 rivals on Crown Isles, 8 on Pangaea).
- 2026-09-29 Claude: tools/gameplay-campaign-100.gd (user asked for 100 more gameplay checks): all 13 maps at full nation count (a different nation and difficulty each: nations placed, a worker builds, rivals grow, a corvette sails, save/restore), then one match system by system (air strike, landing and rearming, war at sea, SAM and ABM interception, silo build time, road supply cut and mended, growth, hunger, winter gas, market prices, spies, gifts, alliance, joint war, NAP, repairs, defeat). 100 of 100; no game bugs found this round (only test setups). --systems runs the second part alone.
- 2026-09-29 Claude: tools/intel-100.gd (user asked for 100 intelligence gameplay checks): agency and agents, an assignment's life (preparation, result, recovery, windows, one per target, recall), the odds (network, heat, variety, alert, rival difficulty, research, clamps), programme requirements, every operation forced to succeed via run()'s roll (network, dossiers and their confidence, open sources, counter-sweep, stand-down, influence and its backfire, cyber, funds, tech, shipping, sabotage without war, partners, rebels, false flag, the four leadership strikes and succession), failure/capture/ransom/promotion, exposure and scandal, fading intel and attack warnings, rival services (and a review catching more), effects on an AI in play (no building under cyber, lower income leaderless, no attack while paralysed, softer hits without a general), partner upkeep and expiry, saves mid-assignment, a fallen target, the Intel panel's four tabs, nine nations, national talent (Israel over Russia). 100 of 100 twice; no game bugs this round. Note: the scientist strike's text in the export data ("steal 250 research") differs from the rule (rival -2 levels); the panel shows role_effect(), which is right.
- 2026-09-29 Claude: tools/research-100.gd (user asked for 100 research gameplay checks): queue rules, stages (materials by branch, 35/35/30 points, 20 s minimum, paid once, half effect at prototype), rate (capital, school, Public Education, chip fab), eras (goals, reward, openings, no skipping), tracks, all 38 discoveries measured in play (food, health, happiness, homes, income, factory speed, prices, routes, mining, unit health/damage/range/speed, unlocks, construction speed, research rate, warnings, spies, gifts, ransom, interception, warheads, active protection), rival research (hard faster, damage and health per level, cap 10, missiles from level 2), saves, the research tree (a card for each, no overlaps, locked tooltips), national limits as China. 100 of 100 twice; no game bugs. Every research effect is read somewhere in the game (checked by grep over bonus("stat")).
- 2026-09-29 Claude, 0.9.41: tools/diplomacy-100.gd (user asked for 100 diplomacy checks). Found and fixed: diplomacy._accept (letters) now lapses an alliance/pact/NAP offer if war came since, and any offer from a fallen nation; a ceasefire offer after peace does nothing. (diplomatic_contacts already re-checks eligibility on signing.) 100 of 100 twice; diplomacy-test, firm-diplomacy, diplomatic-contacts, gameplay-live/deep/100 pass.
- 2026-09-29 Claude: 0.9.41 executable and installer in dist, built from a248797; packaged --ui-test passes.
- 2026-09-29 Claude, 0.9.42: tools/economy-100.gd (user asked for 100 economy checks). Found: provided("prodPct"),
  ("dmgPct"), ("hpPct") were never read, so Power Plant, Ammo Depot and Command & Control did nothing their cards
  said. Now: economy.plant_bonus() (<= 0.30) in update_training and construction speed; depot_damage() (<= 0.25)
  in research.damage_mult and depot_reload() (<= 0.18) on unit.reload in world; command_health() (<= 0.10) in
  research.equip. Player only (AI keeps its tech levels). gameplay_rules.gd rewrites the cards of TV Station,
  Police Station, School, Library, University, Museum, Park, Stadium, Courthouse (no approval/order/culture/
  education systems exist). UI note for Codex: nothing in hud.gd changed.
- 2026-09-29 Claude: 0.9.42 executable and installer in dist, built from e1d02c2; packaged --ui-test passes. Quick suite before the bonus caching: 68 of 69 (performance, run alongside other tests); after caching, economy-100 100/100 and performance-check pass alone (battle 35 ms a step).
- 2026-10-02 Claude: match pace (user: the game is too fast). match_setup: "pace" in {0.6, 0.75, 1.0}, default 0.75,
  kept in saves. world.apply_pace() sets Engine.time_scale at start_match (not when a SceneTree tool script runs
  the game, so tests keep full speed; apply_pace(true) forces it); world._process gives pan_camera/update_camera
  real time. menu.gd (Codex's): a fourth select, "Pace", in "Set the balance of power", and the pace in the
  briefing. tools/pace-check.gd: game time at 76% of real time at 75%, the camera unchanged.
- 2026-10-02 Claude, 0.9.43: (1) pace (see above). (2) New maps (user: more maps, real ones, inspired by Civ 7):
  scripts/world_geography.gd holds simplified coastlines (one Eurasia-Africa outline with the Mediterranean,
  Black, Caspian and Baltic seas cut out, plus islands) and mountain ranges in lon/lat, rasterised (360 cells:
  scanline fill, chamfer signed distance, range strength) for map_generator; REAL maps middle_east, europe,
  east_asia put each faction at its capital (_real_starts: own capital, else open cities, else any free slot).
  continents_plus (homelands + Distant Lands with rich deposits, a southern isthmus) and fractal (in EXPANDED,
  narrower wandering routes). Per-capital deposits get a second, closer/wider ring for island capitals; the
  first ring is unchanged, so older maps keep their resources. map_catalogue KEYS gained the five maps, with
  previews. (3) Roads: world.site_problem refuses a non-settlement building on a hex a road or railway runs
  through (logistics.road_through); route_traffic._route_intact drops a vehicle whose trip passes through a
  hex that has become built up (it used to drive into the building and jam the queue behind it).
  (4) world.gd movement: on a real detour (route > 1.4x the straight line + 10 m) the stall check also counts
  progress along unit.path (per route: path_serial), so a march round a sea no longer counts as stuck (found on
  East Asia from Seoul); in streets the straight-line measure stands (city-test unchanged, about 4 of 5 either way).
- 2026-10-02 Claude: 0.9.43 executable and installer in dist, built from 52f4d97 (my commits only; Codex's ten-nation work in progress stays uncommitted in the working tree, untouched). The in-game suite against the exe (run-tests -Exported): 27 of 27 after 52f4d97 (the --campaign-test config now goes through normalize, as it lacked the new pace). Script tools passed one by one on this code: real-maps-check 38/38, maps-check (all 18 maps), road-traffic-check 21/21 on three seeds, gameplay-maps-100 on the new maps, pace-check, city-test (random about 1 in 5 either way).
- 2026-10-02 Claude, 0.9.44: (user: 100 more checks on the new maps) tools/new-maps-100.gd (20 per map, in
  run-tests.ps1). Found: on a real map two newcomers in a duel got the first two open cities, Riyadh and
  Baghdad (320 m apart); map_generator._real_starts now passes over an open city within size/4 of the other
  capital in a duel only (3+ nations: the list order, unchanged). Codex's CITY_FACTIONS hook in _real_starts
  left as it is in the working tree, not committed by me.
- 2026-10-02 Claude: 0.9.44 executable and installer in dist, built from a1a08af (my commits only; Codex's ten-nation work stays uncommitted in the working tree). On the exe: ui-test, setup-test and campaign-test pass. On a clean export of a1a08af: new-maps-100 100/100, real-maps-check 38/38, maps-check, map-capacity-check, nations-setup-check 125/125.
- 2026-10-02 Claude, 0.9.45: (user: choose where each nation starts) match_config "starts": per roster index a
  region (match_setup.start_slots / region_count) or -1. normalize drops repeats and bad values; on island and
  mirrored the player's start is fixed and region 0 is not for rivals (apply swaps the raw order). Generated
  maps get data.startSlots, used by map_generator._spread_starts / _real_starts via _chosen_starts (no choice:
  the same map as before). menu.gd: a Start picker (StartPicker<i>) beside each nation in _rival_pickers, a
  "You" row, region numbers on MapPreview (_region_marks, preview kept square), starts cleared on a map change.
  Edited menu.gd and the generator in their own hunks only; Codex's uncommitted edits there left as they were.
- 2026-10-02 Claude: 0.9.45 executable and installer in dist, built from cf9b589 (my commits only; Codex's ten-nation work stays uncommitted). On the exe: ui-test, setup-test, campaign-test pass. On a clean export of cf9b589: start-choice-check 26/26, nations-setup-check 125/125, real-maps-check 38/38, maps-check, map-capacity-check, map-picker-check, new-maps-100.
- 2026-10-02 Claude: (user: 100 more checks on choosing the starts) tools/start-choice-100.gd, 100 checks, in
  run-tests.ps1; all pass, no game change needed (on the original islands a rival starts with its capital and a
  guard of two, by design). Codex's working-tree edits untouched.
