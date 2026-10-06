# UN research and gameplay implementation — 5 October 2026

This report supersedes the UN gameplay descriptions in CBRN-UN-RESEARCH-2026-10-05.md where they differ. Weapon research remains with that document and Claude's current work. Implementation preserves the existing `world.un` hooks and isolates new widgets in `un_activity.gd`.

## Research findings

The UN addresses peace and security, humanitarian assistance, development, human rights and international cooperation. It is not a world government or an army that automatically stops combat. The relevant playable roles are international deliberation, diplomacy, recommendations, restrictions, consented monitoring and relief.

| Institution / rule | Verified basis | Gameplay treatment |
|---|---|---|
| Security Council | Five permanent members and ten elected members; substantive decisions require nine affirmative votes without a permanent-member negative vote. An abstention is not a veto. [Official voting rules](https://main.un.org/securitycouncil/en/content/voting-system). | Council membership comes from active campaign identities. A full Council uses 9/15. Smaller campaigns scale the affirmative threshold to 60% of seats; abstaining parties do not lower it. |
| General Assembly | All members are represented. The Assembly discusses international issues, makes recommendations, approves budgets and elects members of UN bodies. [Functions and powers](https://www.un.org/en/ga/about/background.shtml). | Separate Assembly ballots, including proposals from members outside the Council. Peace/security recommendations need two-thirds of yes plus no; abstentions are excluded. No Assembly veto. |
| Council procedure | Member states outside the Council may participate in relevant discussions under the Council's rules, without a Council vote. [Provisional rules](https://main.un.org/securitycouncil/en/content/repertoire/provisional-rules-procedure). | Any member may submit a crisis proposal. Council membership is required to cast the Council ballot. This simplifies invitation and formal sponsorship procedure. |
| Veto accountability | Resolution 76/262 mandates an Assembly debate following a veto. It does not itself adopt a resolution or compel sanctions. [UN text](https://digitallibrary.un.org/record/3971417?ln=en), [UNU explanation](https://assemblyforpeace.unu.edu/summaries/veto-initiative/). | A veto queues a separate Assembly recommendation process. The player's previous Council choice never becomes their Assembly choice. Automatically offering a recommendation ballot is a gameplay simplification beyond the mandated debate. |
| Peacekeeping | Consent of the main parties, impartiality, and limited use of force are core principles. Peace enforcement is a different activity. [UN peacekeeping principles](https://peacekeeping.un.org/en/principles-of-peacekeeping). | A Chapter VI ceasefire proposal awaits both parties' acceptance. A peace observation mandate starts only after consent. It monitors breaches and refers the actual breaker back to the Council; it has no spawned combat army. |
| Sanctions | Measures have specific regimes and designation criteria; comprehensive restrictions differ from targeted freezes and arms restrictions. Civilian relief exemptions exist. [Consolidated list](https://main.un.org/securitycouncil/en/content/un-sc-consolidated-list), [humanitarian exemptions](https://main.un.org/securitycouncil/en/sanctions/1718/exemptions-measures/humanitarian-exemption-requests). | Targeted, military-production and comprehensive economic penalties remain distinct. Food is a simplified humanitarian channel. Renewing a regime extends its duration instead of multiplying its penalty. Routes pause under restrictions and resume after expiry/lifting. |
| Iran standing restrictions | The Council's published fact sheet records reapplication of earlier Iran measures through the snapback process. [Official fact sheet](https://main.un.org/securitycouncil/sites/default/files/2026/2025_Fact_Sheet_digital.pdf). | Existing starting targeted/arms restrictions retained. DPRK starting restrictions no longer pretend to close all civilian commerce. These are simplified regime representations, not complete lists of sanctioned persons or sectors. |
| ICC referral | A Security Council referral concerns a situation; prosecutors and judges retain independent functions. Referral does not automatically constitute an indictment, arrest warrant or conviction. [How the Court works](https://www.icc-cpi.int/about/how-the-court-works). | Existing saved referral registry remains compatible (`indicted` is the legacy code name), while notices describe referral for investigation accurately. |

## Implemented player loop

Open the existing UN window with **U**. Council shows seats, presidency, consultations, the forecast and open ballots. Draft lets any member submit a crisis proposal, including an Assembly recommendation. Consultations allow valid amendments and paid lobbying; the vote opens afterward. Invalid choices, unavailable targets and out-of-phase actions are rejected before payment.

Assembly has its own open ballot, deadline and history. Adopting a recommendation applies diplomatic pressure. Nations may then implement economic restrictions voluntarily. An affirmative Assembly ballot never automatically enrolls the player. Join/leave controls manage participation, and the bilateral market follows that decision. Council lifting cannot cancel another country's voluntary measures.

Council also shows pending compliance/consent proposals with Accept and Decline. The war continues until both sides consent. An unanswered proposal expires. Rejection of a Chapter VI proposal does not automatically trigger Chapter VII sanctions. Existing binding withdrawal deadlines can still generate a new Council case; the Council must deliberate again.

The Secretary-General's good offices provide mediation without a Council vote. Requests cannot stack or ignore proposal cooldowns. AI consent considers war support and military strength; this is a game heuristic, not a geopolitical prediction.

Civilian food relief uses real economy resources. Arranging player relief costs $250 logistics and delivers up to 80 food within storage capacity. Sending relief costs $250 plus 80 food, adds food to the recipient's persistent national stock and improves relations/support. A 120-second shared cooldown and atomic payment prevent duplicate/free deliveries. It is a subsidized game mechanic, not a UN funding model or a physical convoy simulation.

## Future countries and deliberate abstractions

- Identity uses `Factions.identity`, not fixed map slot numbers. Every active country defaults to membership, including unknown future identities. `un: "observer"` excludes ballots and electoral seats.
- `un_region` accepts one of the five keys in `un_data.SEATS`; an unspecified/invalid region is `Unassigned`. An unknown country does not automatically acquire a real-world region or NAM affiliation. `nam` explicitly overrides affiliation.
- `un_seat` can represent one of the existing five permanent identities. It cannot create a sixth veto. Duplicate representations of one permanent seat are deduplicated in the Council.
- The existing EU faction represents France's permanent seat as an explicit inherited game abstraction. The real EU has no national permanent seat of its own. When France becomes a separate faction, data should give the seat to France and make EU representation explicit.
- Council seats cap at five permanent plus ten elected. Full regional allocation is 3 Africa, 2 Asia-Pacific, 2 Latin America/Caribbean, 2 Western Europe/Others and 1 Eastern Europe. Smaller campaigns scale elected seats to available members.
- Elections rank regional candidates by diplomatic standing and campaign effort rather than simulating every national electoral ballot. Departing members cannot be immediately re-elected. Insufficient candidates can leave a small campaign's seat vacant.
- Real calendar periods are compressed: a Council term is ten game minutes, presidency one minute, consultations fifteen seconds, votes twenty seconds. These are balance decisions.
- Economic percentages and whole-country effects stand in for complex legal enforcement. An arms embargo affects production as a game abstraction, rather than modeling every foreign transfer. Standing targeted restrictions do not imply that every citizen or all commerce is sanctioned.
- Off-map countries, UN appointment elections, development programmes, specialized agencies, physical peacekeeper units and judicial trials are not simulated. The UI states when peacekeeping is monitoring rather than combat deployment.

## State, compatibility and validation

Existing hooks remain: `war_declared`, `wmd_used`, `table`, `production_mult`, `bonuses`, `capture`, `restore`. `market_closed` accepts an optional commodity so the food exception reaches actual buy/sell actions. New `trade_blocked` applies Council and voluntary bilateral restrictions to routes without destroying already-paid cargo.

Whole-world JSON saves preserve separate ballots/queues/history, consent responses, actual ceasefire breaker, aid cooldown, incident deduplication, long-war start times, election campaign spending and previous dues assessments. Legacy Council ballots and dues saves migrate. Article 19 uses the sum of recorded previous assessments instead of doubling the latest assessment when income has changed.

Validation on the shared source:

- `tools/un-check.gd`: **68 passed, 0 failed**, including real diplomacy/economy/market/UI/save integration and a 35-country electoral fixture.
- `tools/wmd-un-check.gd`: **59 passed, 0 failed**, preserving current weapon hooks and updating only UN expectations for the corrected procedure.
- New regression is registered in `native/run-tests.ps1`.
- UI captures: `tools/un-views.gd`, saved under ignored `native/godot/build/un-*.png` for visual review.
- Five captures were visually inspected at 1280x800; `UN_VIEWS PASS` with no script errors.
- General `--ui-test` has one failure outside the UN: `world.gd:3666` still expects every one of the 27 missile types in the silo, while the current national-capability interface filters that list. The other UI assertions passed. This was recorded for Claude's parallel weapons work; weapon rules and that assertion were left untouched.

The shared menu, HUD, weapon data and combat scripts remain with Claude. One duplicate local-variable name in the shared DEFCON widget was renamed to allow that file to compile; its behavior was preserved. No reset, rebase or overwrite of the public installer was performed.
