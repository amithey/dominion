# Regional factions — playable first implementation

Research: [seven entity profiles](../docs/planning/SEVEN-ENTITIES-GAME-PROFILES-2026-10-10.md).

Launch the local working preview with `Start-Regional-Preview.bat` at the repository root. It opens `build/regional-preview/DOMINION.exe`; if that build is absent it opens the native source project with the bundled Godot runtime. The existing release launcher and installer remain separate.

The roster now has 28 selectable identities. Existing indices 0–21 stay unchanged. Appended IDs are `yemen`, `houthis`, `ethiopia`, `nigeria`, `sudan`, `south_sudan`. Yemen's recognized government and Ansar Allah are separate playable authorities within Yemen, not two sovereign states. Sudan and South Sudan are distinct states; neither side represents the RSF. Skirmish positions do not claim to depict real territorial control.

| Identity | Implemented gameplay |
|---|---|
| Egypt | Existing canal and engineering retained; Nile Water Management research improves farm output. |
| Yemen government | Cheaper civilian construction, faster reconstruction workers, institution research, donor-funded reconstruction escrow. No inherited jet fleet. |
| Ansar Allah | Cheaper drone categories, dispersed workshop research, coastal drone team and bounded shipping pressure. Requires war, supplied ports and a live battery; escorts mitigate it. No UN seat. |
| Ethiopia | Agriculture and population growth, hydropower distribution research and paid grid exports. No ports or navy; imported air categories can be researched. |
| Nigeria | Oil/gas production, grid limitations, gas-to-power research and paid stabilization. Shares A-29 with Brazil and JF-17 with Pakistan. |
| Sudan | Agricultural recovery, cheaper route repairs, timed paid repair of actual damaged buildings near its capital. |
| South Sudan | Oil production, public revenue research and actual stocked-oil sales through Sudan. Landlocked, limited forces, standing UN arms embargo in this scenario snapshot. |

All numerical modifiers and AI ceilings are balance choices. Generic military categories are abstractions, not force inventory or readiness claims. No new state inherits nuclear weapons, advanced submarines, stealth aircraft or a strategic missile programme. New identities use country badges or an authority monogram instead of invented leader portraits.

Contracts charge both parties before service begins. Ethiopian revenue is earned only for elapsed service; interrupted contracts refund unused escrow. South Sudan's 100 oil is reserved, Sudan reserves $500, and successful delivery transfers $400 to the seller while Sudan retains $100 transit fees. Lost infrastructure, war or destination capacity failure cancels delivery. Resource refunds respect storage caps. Paid administration/connection costs are not refunded. All contract timers, escrow, effects and cooldowns use the existing JSON campaign save state.

Coastal pressure slows sea cargo progress for the player and the existing AI cargo system. It never closes all global trade, affects land freight or damages cargo directly. It ceases on peace, expiry, defeat, lost ports or loss of the battery. The existing Egyptian Suez ability remains the game's older abstract canal mechanic.

Implementation centres on `scripts/regional_factions.gd` and `scripts/regional_powers.gd`, exposed through the established faction/profile/power registries. Roster restrictions run after all equipment extensions to prevent later registration from restoring unavailable advanced units. `tools/regional-factions-check.gd` is registered in `native/run-tests.ps1`; legacy power suites retain their original scenario coverage and the shared operator suite now covers 28 identities.

Deferred from the research plan: detailed civil-war control maps, separate RSF gameplay, STC politics, real electricity routing, additional named weapon families, full national event chains and photographic leader art. This is a playable foundation, not a claim that the entire research backlog is implemented.

## Validation

Source checks passed: regional integration 104, faction selection/save 954, force roster/combat 558, legacy faction integration 238, resource-boundary/cargo 127, UN 68, national AI/nuclear realism 57: 2,106 checks, zero failures across those seven suites. The new-game menu was rendered and inspected at 1920×1080; `native/godot/build/regional-picker.png` records the view. Windows working-preview export completed successfully. This is targeted validation, not the entire long-running regression runner.

The exported executable was launched under normal Windows permissions and reached a ready navigation world. The bundled release template disables command-line scene/script overrides, so the alternate-scene smoke tool cannot run against that binary; the seven detailed suites above ran against source. The headless verification process was closed after launch verification.
