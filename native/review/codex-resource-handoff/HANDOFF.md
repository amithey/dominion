# Fish / gold usability fix — Codex → Claude

User reported fish and gold could not be used. The native economy already turns a supplied gold extractor into treasury income and a supplied Fishing Wharf into food. The missing pieces were a discoverable interaction and the coastal placement exception documented in world.gd but not used by site_problem.

Already applied in the shared working tree:

- Click a visible resource marker (or its ground site) to inspect output, the correct building, price, placement instructions and status. Gold explicitly pays money; fish explicitly require a dry coastal wharf within 60 m. The action starts normal placement, with no payment until confirmation.
- Unclaimed coastal hexes within three hexes of owned land admit coastal buildings. Rival-owned land remains protected. Inland placement, terrain, occupied sites and supply rules remain enforced.
- Fog gates resource selection and details. The resource window closes for ministry navigation, cabinet, research, building/unit selection or its Close button.
- A new headless regression is registered in native/run-tests.ps1.

No new resource currency, save schema, mining rate or fishing bonus was introduced. Gold fields outside your territory still require acquiring land; fishing still requires completing the wharf and supplying it. The three-hex coastal exception does not guarantee every inland starting capital has an immediately accessible shore.

The visual handoff should be integrated before this resource delta. `resource-use.patch` is relative to the completed visual tree, excluding all earlier visual/arsenal/AI changes. In world.gd it contains only the coastal exception and click routing; in hud.gd only resource panel setup and visibility hooks. Do not apply a patch twice.

Validation logs: build/resource-*-console.log. Targeted resource input, costs, real food/treasury income, supply gating and hostile-coast checks; existing resource-marker, offshore, economy and menu suites. Screenshots: native/godot/build/resource-gold.png and resource-fish.png. The graphical check uses the default Vulkan/Forward+ renderer for the final views.

Final results: resource-use 20 checks, resource-marker 39, offshore 8, economy 100 and menus 52 — 219 checks passed. Default Vulkan graphical resource-use check also passed (19 checks before the additional headless fog case); both screenshots inspected. No SCRIPT ERROR in the final suite logs. Windows preview export exit 0; reverse patch dry-run passed with `--ignore-space-change` for CRLF. Test scripts are excluded from the export; the last fog-only test addition does not change the preview game binary.

Local preview: build/regional-preview/DOMINION.exe via Start-Regional-Preview.bat. Official dist/installer remain for Claude to rebuild, verify and publish together with the visual changes.
