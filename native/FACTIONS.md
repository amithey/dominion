# Nine playable factions

Implemented in the native game. The player and each rival can be chosen from
nine factions; a campaign still contains 2–4 active nations. Geographic slot
capacity is independent of the selectable faction roster.

| Faction | Leader used in game | Implemented identity |
|---|---|---|
| United States | Donald Trump | Existing exclusive F-22, B-21 and Golden Dome |
| China | Xi Jinping | Existing exclusive DF-17 launcher |
| European Union | Ursula von der Leyen | Existing exclusive IRIS-T SLM |
| Iran | Masoud Pezeshkian | Existing exclusive Shahed launcher |
| Russia | Vladimir Putin | Artillery/MLRS/HIMARS: +20% damage, +10% range, −15% speed |
| India | Narendra Modi | Combat infantry: +15% health; rocket/ATGM teams: +15% damage; crewed aircraft: −10% health |
| Japan | Sanae Takaichi | Naval units: +15% range, +10% speed; tanks: −10% health |
| Turkiye | Recep Tayyip Erdogan | Combat drones/loitering munitions/FPV teams: +20% speed, +10% damage, −15% health |
| Israel | Benjamin Netanyahu | Mobile SAM/MANPADS/laser: +10% range, −15% reload duration; commandos: +15% damage; those specialists: −10% health. Working missile interceptors: +5 percentage points, capped at 97%, before enemy evasion. |

The new national modifiers are gameplay balancing choices, not factual claims
about military effectiveness. They apply to player and AI units, including the
initial garrison. The new doctrines combine with the separate 0.9.35 faction arsenal and political
powers: Russia gets TOS-1A / Energy Leverage; India gets BrahMos / Strategic
Autonomy; Japan gets Aegis Cruiser / Development Aid; Turkiye gets Akinci /
Istanbul Talks; Israel gets Harop / Mossad Operation. Their names are displayed
in the faction picker. These weapons and powers were implemented in the parallel
gameplay task; this stage integrates the roster, leaders and passive modifiers.

The old four names were replaced with the countries/bloc their arsenals represent.
The EU is a playable bloc, represented by its Commission President. Iran is
represented by its President, not its Supreme Leader. Other staff slots use
role titles instead of invented real officials. Old fictional portraits remain
available for legacy identity references; new campaigns use the nine new images.

## Code and validation

- `scripts/factions.gd`: roster, leader names, colours and gameplay modifiers.
- `scripts/match_setup.gd`: maps remain four tested town layouts; selected
  identities are assigned independently. Optional `rivals` indices are sanitized
  and included in `match_config`, so chosen opponents survive saving/loading.
- `scripts/research.gd`: applies national stats to the initial garrison and new
  recruits; national damage combines with research and AI technology.
- `scripts/modern_warfare.gd`: Israeli interceptor bonus, retaining immunity
  against classes a given interceptor cannot engage and the existing 97% cap.
- `scripts/leader_gallery.gd`: real portraits resolve by complete leader identity;
  successors use the existing fallback rather than an incorrect incumbent image.
- `tools/factions-check.gd`: roster/ownership at 2, 3 and 4 players for all nine
  choices, portraits, UI signals, duplicate-rival repair, player/AI modifiers,
  exclusivity, interception, JSON and in-memory save restoration, plus a fresh-world
  reload of four selected factions on Great Frontier (384 checks).
- `tools/faction-powers-check.gd`: 55 weapon/power integration checks, with the
  faction-switch helper updating the stable identity.
- Existing `--campaign-test`, campaign flow and 181 weapon checks also pass.
- `tools/faction-gallery.gd`: renders the nine in-game portrait crops to
  `build/faction-leaders.png` for art review.

## Leader references (checked 28 September 2026)

These sources establish the names and roles, not the game's numerical bonuses.

- United States: [White House presidential biography](https://www.whitehouse.gov/administration/donald-j-trump/).
- China: [Chinese government, September 2026 presidential visit](https://english.www.gov.cn/news/202609/25/content_WS6ab54e0bc6d00ca5f9a0d719.html).
- EU: [European Commission leadership, 2024–2029](https://ec.europa.eu/stories/2024-2029-commission/college-2024-2029/).
- Iran: [India's official account of President Pezeshkian's September 2026 visit](https://www.pib.gov.in/PressReleseDetailm.aspx?PRID=2309472&lang=1&reg=3).
- Russia: [Kremlin presidential profiles](https://kremlin.ru/structure/president/presidents).
- India: [Prime Minister's Office](https://www.pmindia.gov.in/en/).
- Japan: [Prime Minister's Office](https://japan.kantei.go.jp/).
- Turkiye: [Presidency, September 2026](https://www.tccb.tr/en/news/542/166080/-those-concerned-by-turkiye-s-growing-strength-cannot-deter-us-).
- Israel: [Prime Minister's Office](https://www.gov.il/he/departments/prime_ministers_office/govil-landing-page?lang=he).
