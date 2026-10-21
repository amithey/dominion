# The European Union, split into its members: the ledger

The playable `eu` identity (index 2, arsenal colour `green`) mixes the rows of several
states. Each member state is added as its own nation, in one file under
`native/godot/scripts/nations/`, taking the rows that belong to it. When every member is in,
`eu` is removed (Germany takes index 2, so saves stay valid) and the union returns later as a
bloc, not a player.

Order: France, Germany, Italy, Netherlands, Greece; then Spain and Sweden once their
governments are settled (an election is called in Spain; Sweden's prime minister is
resigning). Poland comes with its own wave.

## France (this entry)

Leader checked 2026-10-21: President Emmanuel Macron. Source of each claim is in the nation
file's comments or the dossier; figures are game balance.

| `eu` row | Where | France takes it? |
|---|---|---|
| Identity: leader, colour, portrait, signature, doctrine | `nations/eu.gd` | A new identity. The Union's own (von der Leyen) goes at the cut-over. |
| National profile (+5 income, +5 research, trade, welfare) | `national_profile.gd` | Not copied: France gets its own (+10 / +5, oil and gas halved). The single-market effects stay with the bloc. |
| AI standing (ceiling 4) | `ai_data.gd` | Own row, same ceiling. Models 4 for the French laboratory. |
| AI evidence | `ai_applications_data.gd` | Own row (ministry agency, framework supplier). |
| AI use: deadHand "pledged" | `ai_use_data.gd` | **France.** The row's text already says France. |
| AI use: surveillance "barred" (AI Act) | `ai_use_data.gd` | Stays with the bloc; France's own law allows video analysis. |
| AI use: infoShield, revenue | `ai_use_data.gd` | France (VIGINUM, tax administration). |
| Roster: carrier Charles de Gaulle | `force_catalog.gd` | **France only.** |
| Roster: E-3F Sentry, Atlantique 2, Mistral-class | `force_catalog.gd` | **France only.** |
| Roster: Mirage 2000D | `force_catalog.gd` | **France.** |
| Roster: FREMM, NH90 NFH, COBRA | `force_catalog.gd` | France; Italy shares FREMM, Germany shares NH90 and COBRA. |
| Roster: Puma, Fennek, Keiler, Bergepanzer, Skorpion, Tornado ECR, MG5, NSM coastal | `force_catalog.gd` | Not France: Germany (Puma, Keiler, Bergepanzer, MG5), Germany with the Netherlands (Fennek), Germany (Skorpion, NSM), Germany and Italy (Tornado ECR). |
| Roster: Gripen C | `force_catalog.gd` | Sweden. |
| Roster: CH-47F Chinook | `force_catalog.gd` | Germany (an order); France does not operate it. |

### Done for France (commit edb71d4)

- Capabilities (`national_variants.table()`): sixth-generation fighter, nuclear submarine, destroyer, laser,
  missile defence; research (sixth generation, nuclear programme, directed energy, missile defence); the
  nuclear weapon; no diesel `submarine` (all hers are nuclear); sixteen unit names (Leclerc XLR, Rafale...).
- Nuclear and missile rows the Union held for her: `cbrn_data` (all `eu` lists and the treaty row),
  `arsenal_catalog` (SCALP / MdCN, Exocet, SCALP penetrator, ASMP-A, sea-launched nuke, M51, laser, FCAS,
  wingman, Leclerc), `un_agencies.NUCLEAR_STATES`, `un_data` (region, western group).
- National power: Forward Deterrence (see the research in the conversation: the March speech at Ile Longue).
- Left with the Union on purpose: `antiRadar` (the HARM is German and Italian), `stealthFighter` and
  `activeProtection` (German orders), the German and Dutch roster rows.

### Still to do for France (stage 3)

- Rows in tables that fall back to a default today: crisis, GDP (`world_stats.BASE_GDP`), regime
  (`war_support.REGIME`), generals (style and names), unit quality (SAMP/T NG, NH90, Tiger, Rafale,
  Horizon, MMP, Mistral 3), space (`LAUNCHERS`: Ariane), chip fabs (`national_industry.CHIP_FAB`),
  carrier style and air wing (`force_models`, `war_tools`), city style, world-event deltas, diplomacy ties
  (`TIES`), `ai_data.CONTROLLERS`.
- A portrait illustration: `macron-emblem.svg` stands in.
- `un_data.PROXY` maps `eu` to `france`: remove it at the cut-over, when `eu` goes.

## Open questions to verify before release

- France's scientific articles a million people (research +5% rests on the UK tier, not on a fresh figure).
- The nuclear warhead count (an estimate only; the game models capability, not a count).
- Whether the Mirage 2000-5F is still in front-line service at release.
