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

### Still to do for France (next steps)

- Capability lists in `national_variants.gd`: nuclear submarine, sixth-generation fighter,
  destroyer, missile defence, laser, active protection, nuclear programme, nuclear weapons.
- Unit names (`national_variants.NAMES`, `arsenal_catalog.UNIT_NAMES`): Leclerc, Rafale, Triomphant.
- Nuclear: `cbrn_data.gd` (the nine nuclear-armed states hold `eu` today; France is the Union's
  nuclear power), `un_agencies.NUCLEAR_STATES`.
- UN: `un_data.PROXY` maps `eu` to `france`; the real `france` nation makes the proxy unnecessary
  at the cut-over.
- Tables keyed by nation with a default today: crisis, GDP, regime, generals, unit quality,
  space (launchers), chip fabs, carrier air wing and style, missile tables (SCALP/MdCN, Exocet).
- A portrait: `macron-emblem.svg` stands in until an illustration exists.

## Open questions to verify before release

- France's scientific articles a million people (research +5% rests on the UK tier, not on a fresh figure).
- The nuclear warhead count (an estimate only; the game models capability, not a count).
- Whether the Mirage 2000-5F is still in front-line service at release.
