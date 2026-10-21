# Adding a nation to DOMINION: what the tests demand

Found on 2026-10-21 by registering a trial nation (France) and running the identity,
AI, arsenal and force suites. Each row is a test that failed until the nation had it.

| Needs | Where it lives today | Test that fails without it |
|---|---|---|
| A file in `scripts/nations/<id>.gd` and a line in `nation_registry.gd` (append only) | `nation_registry.gd` | `nation-registry-check` |
| A leader portrait: `ui/leaders/<portrait>-v2.png`, or an `-emblem.svg` fallback | `ui/leaders/` | `nation-registry-check`, `factions-check`, `regional-portraits-check` |
| A national profile (income, research, trade, costs, strengths, weaknesses) | `national_profile.gd` / `additional_factions.gd` `PROFILES` | `national-profile-check` |
| Operator choices for every role (which of 354 role slots it fields) | `force_catalog.gd` | `force-roster-check` |
| AI evidence, ceiling and reason | `ai_data.gd`, `ai_applications_data.gd`, `ai_use_data.gd` | `ai-applications-check`, `national-realism-check`, `ai-strategic-check` |
| An arsenal dossier: sources, uncertainty and six substantive domains | `arsenal_diversity_data.gd` | `arsenal-diversity-check` |

Tables that tolerated a missing nation (they fall back to a default): crisis, national
industry, UN. A new nation should still get a row in each so its numbers are chosen, not
inherited by accident: `crisis.gd`, `world_stats.gd` (`BASE_GDP`), `un_data.gd` (region),
`war_support.gd` (`REGIME`), `generals.gd`, `unit_quality.gd`, `space.gd`, `cbrn_data.gd`.

## Direction

A nation's data should live in its own file. The nation file already carries identity;
profile, AI evidence and the dossier move into the same `DATA` as each seam is opened,
and the tables above read the registry instead of growing a row per nation. The six
tables above are the seams, in the order they will be opened.
