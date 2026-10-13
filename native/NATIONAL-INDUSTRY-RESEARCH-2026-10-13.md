# What each nation can really build and field: industry and rosters (2026-10-13)

**The question (player):** go over the buildings each nation has. It makes no sense that the Houthis have AI or a chip factory ... or HIMARS.

**What was wrong.** The build menu offered every nation nearly every building:
- the Houthis, Yemen, Sudan and South Sudan could build a **Chip Fab**, an **AI Data Centre**, a **Technology Park** and a **Targeting Fusion Cell**;
- every regional entity could **train HIMARS and a Virginia-class submarine**, and landlocked Ethiopia and South Sudan a submarine and a sea drone.

The unit bug had a cause: a nation's dictionary carries the island's default army list, and the roster gate (`national_arsenal.allowed`) trusted it before looking at the entity's own documented roster.

## The rules (0.9.98)

| Building | Rule | Who | Evidence |
|---|---|---|---|
| **Chip Fab** | Front-end wafer fabrication | USA, China, EU, UK, Japan, South Korea, Israel, India, Russia | US, Japan, Korea, China, the EU (Germany, the Netherlands, France, Italy, Ireland) and Israel (Intel's Kiryat Gat) run fabs; India has the state SCL fab and a flagship Tata–PSMC fab planned at Dholera (Micron's Sanand plant is assembly and test, not a wafer fab); Russia's Mikron fabs make older nodes; the UK's Newport fab makes compound semiconductors. **Not** Türkiye, Iran, Saudi Arabia, Brazil, Indonesia, Egypt, Pakistan, Australia, Ukraine, North Korea or the regional entities: they import their chips. |
| **AI Data Centre**, **Technology Park** | A domestic technology sector: AI ceiling 2 or more (ai_data.gd) | Not Iraq, Syria, Afghanistan, Yemen, the Houthis, Sudan or South Sudan | The AI ceilings were researched per nation in 0.9.86 (power, connectivity, chips, institutions). |
| **Targeting Fusion Cell** | A military AI programme: AI ceiling 3 or more | Not nations at 2 or below | Military AI needs ceiling 3 to research at all. |
| **Nuclear Reactor** | A civil nuclear programme: operating, commissioning or under construction | Not Australia or Indonesia (research reactors only); Iraq, Syria, Afghanistan and the regional entities were already barred | Operating: Iran (Bushehr), Pakistan (Chashma 1–4, unit 5 under construction), Brazil, Ukraine and the great powers. Türkiye (Akkuyu 1 in commissioning, first power expected late 2026) and Egypt (El Dabaa, first reactor due 2028) are building. Saudi Arabia is left as before: its nuclear path is handled by the game's threshold-state rules. |

A nation that cannot build a Chip Fab gets the era's **compute goal as Universities** instead of Chip Fabs, so no era is ever blocked.

## Rosters

The six regional entities now field **only** their documented rosters (`regional_factions.COMMON` plus `EQUIPMENT`):
- no HIMARS, no submarine and no nuclear submarine for any of them;
- no sea drone for landlocked Ethiopia or South Sudan.

The Houthis gain one real system: **the sea drone** (explosive unmanned surface boats used against shipping in the Red Sea).

## Sources

- Nuclear status:
  - Akkuyu: https://world-nuclear-news.org/Articles/Russia-and-Turkey-plan-grid-connection-for-Akkuyu
  - El Dabaa: https://world-nuclear.org/Information-Library/Country-Profiles/countries-A-F/Egypt
  - Chashma: https://world-nuclear-news.org/Articles/Agreement-reached-for-Chashma-unit-5
  - Bushehr: https://gem.wiki/Bushehr_nuclear_power_plant
  - Operators in general: https://www.grs.de/en/news/nuclear-energy-worldwide-2026
- Semiconductors:
  - India: https://swarajyamag.com/amp/story/business/indias-semiconductor-journey-gains-pace-here-are-six-fabs-and-testing-units-coming-up
  - Fab landscape: https://siliconanalysts.com/fab-site-explorer/

## Judgement calls (open to revision)

- Israel's, Russia's and the UK's fabs, and the absence of one in Türkiye or Brazil, rest on general knowledge; the searches did not confirm them.
- **Saudi Arabia keeps its reactor.** The game's threshold-state rules need it.
- **Research buildings stay open to everyone** (school, library, university): only the technology-sector buildings are gated.
