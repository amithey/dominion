# Working in parallel: Claude and Codex

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
