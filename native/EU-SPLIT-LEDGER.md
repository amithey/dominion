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

### Done for France, stage 3 (commit e38f5ad)

GDP, crisis baselines, regime, generals, space launchers, chip fabs, city style, carrier style and air wing,
the Union's world-event shocks (copied, to be split among members), starting ties (copied from the Union's),
and unit-quality figures for every class she fields (judgements on the table's own scale, not measurements).

### Still open for France

- No "Paris" capital slot on any map (`world_geography`, `additional_factions.CITY_FACTIONS`): she starts from a free
  slot. Adding one is map work.
- Figures to check against sources: inflation 1.2, unemployment 7.6, debt 116, Fragile States Index 33, GDP 3,400.
- Unit-quality judgements (Leclerc 1.06, Crotale NG older, Suffren 1.06...) and her generals' traits.
- A portrait illustration: `macron-emblem.svg` stands in.
- `un_data.PROXY` maps `eu` to `france`: remove it at the cut-over, when `eu` goes.
- `unit-quality-check`, `world-events-check`, `war-support-check` and `space-check` are not in `run-tests.ps1`:
  run them by hand until they are added.

## Germany takes the Union's index (commit 2c15c77)

`nations/germany.gd` replaced `nations/eu.gd` at index 2 (arsenal `green`, as the colour nations keep theirs).
A save made with the Union loads as Germany (saves hold the index); the old leader's name resolves to the
present one. The Union is no longer a player; it returns later as a bloc.

| `eu` row | Became |
|---|---|
| Nuclear weapons, MIRV, hydrogen bomb, EMP, nuclear cruise, tactical nuclear, neutron programme; NPT "weapon state" | **Dropped** (France holds them). Germany: NPT "party". |
| Carrier Charles de Gaulle, E-3F Sentry, Mistral-class | **Dropped** (France). |
| SCALP / MdCN, Exocet, SCALP penetrator | Germany: Taurus KEPD 350, RBS15 Mk3, Taurus penetrator. |
| Rafale / Typhoon, Horizon-class, MMP, Mistral 3, SAMP/T NG, Triomphant-class | Germany: Eurofighter Typhoon, F124 Sachsen-class, Spike LR, Stinger, Patriot PAC-3 MSE; no nuclear submarine. |
| Atlantique 2, FREMM, NH90 NFH, Mirage 2000D, Gripen C | Germany: P-8A Poseidon, F125-class, NH90 Sea Lion, Tornado IDS, Eurofighter Typhoon. (Gripen goes to Sweden later.) |
| Puma, Fennek, Keiler, Bergepanzer, Skorpion, Tornado ECR, MG5, NSM coastal, THeMIS, CH-47F, COBRA | Germany (Fennek also Netherlands; Tornado ECR also Italy). |
| CAESAR roster row | France's dossier. |
| Chip-controller list (`ai_data.CONTROLLERS`) | **Dropped**: it belongs to the Netherlands (ASML) when that nation joins. |
| Launchers (`space.LAUNCHERS`) | **Dropped**: France launches (Ariane). Galileo stays with Germany. |
| Carrier style, air wing and navy factor | Carrier style and wing **dropped**; navy factor Germany 0.4 (a judgement, default would be 0.1). |
| World-event shocks, ties, GDP, crisis baselines, regime, generals, city style, chip fabs | Renamed or rewritten for Germany (GDP 4,900; crisis 2.2 / 3.8 / 63 / 2.4 / 27). |
| Capital slots Brussels and Athens (`world_geography`) | Freed to any nation; there is no Berlin slot. |
| National power (Sanctions Package, arsenal `green`) | **Kept for Germany as a placeholder**: design a German lever (export licences) later. |

Figures to check before release: Germany's GDP, inflation, unemployment, debt, spending, Fragile States Index; the
navy factor; the Sanctions Package as a German power.

Tests that were not in `run-tests.ps1` and failed after France (found only by running them by hand):
`unit-quality-check`, `regional-factions-check` (counted exactly 28 nations) and `leader-badge-check` (wanted a PNG
portrait for every nation). Add them to the runner with `world-events-check`, `war-support-check` and `space-check`.

## Open questions to verify before release

- France's scientific articles a million people (research +5% rests on the UK tier, not on a fresh figure).
- The nuclear warhead count (an estimate only; the game models capability, not a count).
- Whether the Mirage 2000-5F is still in front-line service at release.
