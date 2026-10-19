# The UN as a working organisation (2026-10-19)

**The request (player):** the UN should be more in the messages and more "part of the game"; research how it works and implement it.

The Council, Assembly, sanctions, peacekeeping and dues were already in (UN-RESEARCH-2026-10-05.md); what was missing was the rest of the organisation and its steady rhythm.

## What the sources say

- **IAEA.** The Board of Governors determines non-compliance with a safeguards agreement and, under Article XII.C of the Statute, calls on the state to remedy it and **reports it to the Security Council and the General Assembly**; a resolution of the Board needs two-thirds of its 35 members; the Council then decides what to do (a two-step: Vienna refers, New York acts). Past referrals include Iraq, North Korea, Libya and Iran. (https://www.armscontrol.org/node/1900, https://www.armscontrolwonk.com/2548/the-npt-two-step)
- **WHO** declares a public health emergency of international concern and the **Secretary-General's** office and agencies (WFP, UNHCR) issue funded appeals; appeals are met only in part. (https://www.who.int/news/item/17-05-2026-epidemic-of-ebola-disease-in-the-democratic-republic-of-the-congo-and-uganda-determined-a-public-health-emergency-of-international-concern)
- The WFP and UNHCR funding figures were not retrieved by the search; the appeal sums in the game are balance figures.

## In the game (`scripts/un_agencies.gd`; window U, tab Agencies)

| | |
|---|---|
| **Secretary-General** | A briefing every 5 minutes (wars, sanctions, appeals open) and the General Assembly's general debate as each 12-minute year begins. |
| **IAEA** | Every 3.5 minutes an inspection round. Power reactors are inspected and routine findings published. A country with a strategic weapons complex that is not a recognised or known weapon state (the United States, China, Russia, the United Kingdom, the EU's France, India, Pakistan, Israel, North Korea) is found in breach by the Board (about 24 to 29 of 35), reported to the Council, which tables a **breakout** draft (the existing mechanism). This includes you. |
| **WFP and UNHCR** | An appeal when a nation has been at war for over 200 seconds, or when you are hungry or without winter heating. $500 to $800. Other nations give small sums; you can give $150 or $400 (goodwill with the nation helped). A funded appeal for you brings food in proportion; an appeal that closes short says so. |
| **Messages** | Everything above is a message that starts with "UN", "IAEA", "WFP" or "UNHCR"; the situation report files it under *Diplomacy and war*. |

Saves keep the news, the appeals and the schedule. Test: `tools/fixes-1019-check.gd`.
