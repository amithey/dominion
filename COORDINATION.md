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

- 2026-09-23 Codex: redesigning menu/HUD/theme/research colours and ui/icons only; engraved SVG symbols, jade/brass palette, cut-corner panels and clearer navigation. Gameplay callback signatures preserved. No rebase while Claude has active uncommitted edits in the shared checkout.
- 2026-09-23 Codex: UI stage verified with --ui-test and --menu-test (PASS), plus rendered main/new/settings, HUD/selection/help and side-screen captures. Menu save/load needs normal access to user://saves; sandbox run cannot write there. Engine reports resource cleanup warnings at exit. New SVGs are preferred by UI.icon with PNG fallback; existing HUD method names/arguments are unchanged. Release packaging remains Claude's area.
- 2026-09-23 Codex: replaced the opening island view with ui/backgrounds/war-table-v1.png (original ImageGen artwork), animated by scripts/war_table.gd. Only menu.gd integrates it. The backdrop hides in pause/gameplay and stops processing while hidden; the campaign camera no longer rotates from menu code. --menu-test PASS; inspected main/new/settings captures. No gameplay or release files changed.
