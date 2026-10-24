# National inventory and model identity audit

Evidence date: 24 October 2026. Scope: all 31 playable national/faction identities,
823 nation–model assignments in the 565-row Tier 7 roster, plus documented missing
platforms that fit existing game categories, including equipment on confirmed order
at the user's explicit request. Counts describe audit coverage, not
national stockpiles. This is an ongoing evidence ledger; `progress.json` explicitly
counts unreviewed assignments. Earlier art-delivery completion is separate.

## Evidence rules

- A GLB on disk and a roster row do not establish ownership, delivery or service.
- Check operator publications, delivered-equipment records, parliamentary reports,
  original manufacturer delivery statements and authoritative independent research.
  An export authorization, order, trial or parade does not prove operational service.
- Record source date, event date, service branch, exact variant and what the source
  actually establishes. Historical delivery does not prove present serviceability.
- Distinguish ownership from shared/leased operation; a country's personnel using
  allied equipment does not mean that country owns the vehicles.
- Separate land-based aircraft from carrier-capable naval variants, transport from
  armed aircraft, sensor vehicles from launch vehicles, and individual ship classes.
- A slash-separated roster name may hide several different vehicles. One model can
  represent its declared selected vehicle, not all unrelated names in the label.
- For civil war/captured fleets, identify actor and evidence date. Historical national
  holdings do not establish the present faction's access or readiness. Absence of
  public evidence is **unverified**, not proof of non-possession.
- Check each saved GLB's declared representative, dimensions and distinctive shape
  against its designation. A geometrically valid file may still be the wrong model.
- Create a missing model only after recording sufficient evidence and checking for
  an existing exact/base model. Preserve Tier 7 axes, pivots, material roles and LODs;
  independently reload and render each new asset. Do not invent a real inventory.
- Active/current equipment and confirmed orders are included. Ordered/future,
  retired and experimental equipment retain separate statuses. A research-unlock game mechanic does not change
  the real-world status. No game scripts/project files are modified by this audit.

`evidence.json` holds source metadata, reviewed roster assignments and additional
inventory candidates. `countries/*.json` joins that evidence to actual saved GLB
metadata. `audit_national_inventory.py` rebuilds the country ledgers and progress.
Pending means pending; a source cited for one model does not validate a whole nation.

Existing repository research is a set of leads, not independent evidence. In particular,
the 22 October audit's claim that Indonesia never completed its Apache purchase is
contradicted by official 2018 delivery records and 2026 operator activity. See the
explicit sources and correction in `evidence.json`.
