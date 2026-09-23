# Intelligence and shadow competition

Research and implementation: 23 September 2026. The active implementation is
Godot (`scripts/espionage.gd` and the Intelligence panel in `hud.gd`). The browser
prototype is unchanged. Operations remain abstract strategy choices; this is
not a recreation of operational methods used by a real service.

## Research basis

- [US Intelligence Community: how intelligence works](https://www.intel.gov/how-the-ic-works): collection, processing, analysis and dissemination are different stages. In the game, an assignment takes time and produces a dated assessment rather than unlocking a live treasury feed.
- [ODNI ICD 203, analytic standards](https://www.dni.gov/files/documents/ICD/ICD-203.pdf): distinguish evidence, judgments and uncertainty. Reports show source category, confidence, collection age and estimate ranges. These ranges are game abstractions, not statistically calibrated intelligence estimates.
- [Office of the Historian: Bay of Pigs and its aftermath](https://history.state.gov/milestones/1961-1968/bay-of-pigs): covert action can have consequences well beyond its immediate objective. Success and attribution therefore resolve separately; a successful operation can still damage the sponsor's position.
- [CNA: The Cheapest Insurance in the World?](https://www.cna.org/analyses/2019/07/proxy-warfare): proxy relationships involve delegation, costs, risks and potentially divergent interests. Game partners require upkeep, lose capacity without funding and can break away rather than acting as perfectly obedient extra armies.
- [Mossad official home](https://www.mossad.gov.il/en) and [Shin Bet institutional history](https://www.shabak.gov.il/about/statement): foreign intelligence and domestic security have distinct institutional functions. The game separates foreign assignments from a domestic counter-intelligence review; assigning agents abroad has an opportunity cost in home defence.
- [2025 US Annual Threat Assessment](https://www.dni.gov/files/ODNI/documents/assessments/ATA-2025-Unclassified-Report.pdf): used as an explicitly US-government assessment of state competition, intelligence collection, cyber activity and Iran's partner relationships. Its claims are not treated as neutral proof of every allegation. China/Iran/Israel/US are inspirations for broad strategic roles, not selectable national stereotypes or attributed historical scenarios.

## Playable rules

Build an Intelligence Agency, recruit agents, choose a foreign target and select
a program in Intelligence (I). The panel shows price, preparation, cooldown,
intelligence requirements, estimated success and attribution risk. A ready agent
is assigned; deployed/recovering/captured agents cannot immediately be reused.
Recall is available, but committed funds and cooldowns are not refunded/reset.
Only one assignment can be pending against a nation at a time.

All seconds below are compressed **simulation time**, paused with the game.
Numbers are design choices, not historical findings. Cooldown starts when
preparation is due to end, including failure or cancellation.

| Program | Prepare / cooldown (s) | Principal consequence |
|---|---:|---|
| Build network | 45 / 30 | More access; small exposure risk |
| Public-source assessment | 25 / 25 | Dated low-confidence estimate; no attribution risk |
| Recon dossier | 35 / 30 | Field estimate; confidence improves with access |
| Domestic security review | 50 / 120 | Interception +25 percentage points for 180s |
| Stand down network | 30 / 60 | Heat -35, network -10 |
| Influence campaign | 100 / 180 | Stability -20 and income -15% for 150s, or rally-around-government backfire |
| Cyber disruption | 90 / 180 | Production paused for 90s |
| Steal funds | 60 / 120 | Finite transfer from target treasury |
| Steal research | 90 / 180 | Research points transferred into sponsor's programme; rival tech setback |
| Sabotage | 100 / 180 | Existing building damage mechanic |
| Establish proxy partner | 120 / 240 | Up to 300s mandate, $3/s upkeep, income pressure proportional to strength |
| Support unrest | 150 / 300 | Requires partner; 120s income penalty, stability loss and increased partner autonomy |
| Diplomatic provocation | 150 / 300 | Relations between rivals worsen; no automatic foreign war |
| Leadership strike | 180 / 600 | $1,400, network/intel 55, field dossier no older than 180s; temporary role-specific disruption, permanent succession record |

Every completed assignment adds 30s agent recovery; ransomed agents recover for
45s. Leadership cooldown is shared across all roles in that country. Killing
a scientist no longer magically grants the attacker their research. Removing
a head of state no longer automatically loots their treasury or costs the
victim its relations with other nations. Successors take office; institutions
recover as temporary effects expire. Legacy saves with active leadership
effects acquire succession and a 600s security window on load.

Reports never refresh their figures from hidden live state. At 180s they are
marked stale; intelligence-based early warning also requires a recent report
(satellite research remains its separate capability). Diplomacy now refers
players to intelligence estimates instead of exposing exact live army strength.

Partners start with 70 strength and 15 autonomy. Funding shortages erode
strength, time and escalation increase autonomy, and 70 autonomy triggers
breakaway and sponsor exposure. Ending funding stops income pressure immediately.
Stability recovers gradually toward 75 and contributes a small income penalty
while below that baseline. Stacked covert income penalties have a 40% floor.

Attribution damages bilateral and third-party relations, revokes the target's
trade pact, burns some network access, raises security alert and creates a
90–180s domestic scandal costing $2/s. Leadership strikes can escalate to war.
The target's heightened security reduces further success chances. Hostile
services retain their existing theft/sabotage actions, now with a 150s minimum
interval; domestic security reviews and agents kept at home help intercept them.

## Validation and limits

`tools/espionage-check.gd` exercises pending jobs, five-second spam, another-agent
and another-role bypasses, JSON save/load mid-operation, succession, recall,
dated reports, partner prerequisites/upkeep/breakaway, attribution and expiry.
The normal runner includes it. Existing systems, research, UI and save suites
also cover integration; their callers now advance actual preparation time.

This stage does not simulate individual clandestine tradecraft, detailed public
opinion factions, real people or real-world targeting. Rival services do not yet
use the player's full planning catalog. Proxy effects are strategic economic
pressure, not new map-controlled units. Extended multiplayer-style balance and
long-campaign tuning remain playtesting work.

Final verification: lifecycle, UI, systems, research and save suites passed with the matching committed territory, minimap and terrain resources loaded for QA (final spies-matched logs have no SCRIPT ERROR). During the final run, the parallel territory rewrite still referenced a removed draw_borders() function; the working territory file was not changed by this task. Earlier shared-tree runs and visual intelligence-panel capture passed before that rewrite. Engine shutdown resource warnings were present; no intelligence script errors occurred in successful runs.
