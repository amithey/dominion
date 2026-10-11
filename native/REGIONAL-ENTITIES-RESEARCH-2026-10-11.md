# The six regional entities, given everything the game gives a nation (2026-10-11)

**The question (player):** research each of the entities that joined, and give each its own buildings, weapons, politics and everything else the game offers a nation.

Codex's first implementation is described in native/REGIONAL-FACTIONS-IMPLEMENTATION-2026-10-11.md, with its research in docs/planning/SEVEN-ENTITIES-GAME-PROFILES-2026-10-10.md. It gave each entity:
- an economy and research;
- a national power;
- an AI ceiling;
- a roster restriction;
- an emblem.

It deliberately named no weapon systems until they were verified, and left out the per-nation systems every other nation has. **The gaps:**
- **Unit quality:** every unit was rated 1.0, so a Yemeni T-55 fought like a modern Type 99A.
- **National names:** none for their systems.
- **The Houthis' missiles:** removed entirely.
- **Missing per-nation data:**
  - regime type (war support);
  - town plan;
  - officer corps;
  - treaties;
  - the Houthi and Darfur sanctions.
- **South Sudan's helicopters:** absent, though they kept flying under the embargo.

The game's text never cites dates or events. Those appear only here.

## Per entity

The *Systems (names in the game)* column lists the names the game now shows. The *Quality* column is health/damage relative to the shared class:
- tank 1.0 = Type 99A;
- 0.55–0.72 = Cold-War tanks with little upkeep.

| Entity | Systems (names in the game) | Quality | Politics | Evidence |
|---|---|---|---|---|
| **Yemen (recognised government)** | T-55/T-62; BTR-60/MRAP; D-30/M109A5; ZU-23-2 technicals; Konkurs; Strela-2 | tanks 0.55; artillery 0.8 | hybrid (the Presidential Leadership Council, Saudi- and UAE-backed forces that never fully merged); not an ICC party | ACLED actor profiles; M109 in the south; the PLC–UAE rupture (Dec 2025) |
| **Houthis (Ansar Allah)** | captured T-62/T-72, BMP-2/BTR-80, D-30/2S1; BM-21/Badr rockets; ZU-23-2 and the Saqr (358) loitering SAM; Kornet/Dehlavieh; Misagh-2; Qasef-2K/Samad drones | tanks 0.6; ATGM 0.95; drones 0.7 | autocracy (movement rule); UN Yemen sanctions: embargo and targeted measures | DIA (Feb 2024): Iranian missiles and drones; Conflict Armament Research seizures (at least 10 missile types) |
| **Ethiopia** | T-72UA1/T-72B; SH-15 howitzers; BM-21; **Pantsir-S1**; Spyder/S-125; Mi-17; **Su-30K/Su-27**; **Akinci/Wing Loong** | tank 0.72; Pantsir 1.0; drones 0.95 | hybrid; not an ICC party | Janes (Jan 2024): Su-30 and Akinci; Pantsir-S1 delivered (2019) and filmed in service; SH-15 bought |
| **Nigeria** | **VT-4**/Vickers Mk 3; BTR-3UN/Proforce Ara; SH-5/Palmaria; ZSU-23-4; Mi-17/AW109; **T129 ATAK/Mi-35M**; F-7NI (and the JF-17 and A-29, already in the roster); **Wing Loong II**; **OPV-76**/NNS Aradu | tank 0.82; gunships 0.9 | hybrid (an elected president, weak institutions); **ICC party** | Nigerian Air Force (T129 inducted Feb 2024); equipment lists; Dearsan OPV-76 (2025) |
| **Sudan (the army's authorities)** | T-72/Al-Bashir (Type 85); BTR-80A; D-30/Khalifa; BM-21/Taka; Mi-17; Mi-24V/Mi-35; **Su-25/MiG-29SE**; **Bayraktar TB2/Mohajer-6** | tank 0.7; drones 0.88 | autocracy (military); Darfur sanctions (targeted); not an ICC party | TB2s (8 by Oct 2025) and Mohajer-6 drones in the war; legacy Su-24/MiG-29 |
| **South Sudan** | **T-72AV**; BTR-80/Typhoon MRAP; D-30/2S1; ZU-23-2; **Mi-17 and Mi-24V** | tank 0.68; gunships 0.74 | autocracy; UN arms embargo (Codex's scenario); acceded to the BWC (2023); CWC accession still pending | the UN Panel of Experts and Amnesty (Mi-24s at Juba, 2025); Ugandan forces; T-72s bought from Ukraine |

## The Houthis' missiles

The Houthis are the only one of the six with a missile arsenal: Iranian designs, smuggled in kit form and assembled locally (CSIS 2020; the IISS; the DIA).

| Type in the game | Houthi name | Basis |
|---|---|---|
| tactical | Burkan / Zulfiqar | Burkan-3 up to ~1,200 km (Qiam/Rezvan lineage); Zulfiqar from the Fateh-110 family |
| ballistic | Toufan / Palestine-2 | Toufan ~1,350–1,900 km (Ghadr lineage). The Palestine-2 was fired repeatedly at Israel (Dec 2024 – Aug 2025) and usually intercepted; its "hypersonic" claim is unproven. |
| cruise | Quds-4 | Iranian Project 351/Paveh family, up to ~2,000 km |
| antiShip | Asef / Tankil | anti-ship ballistic missiles (Fateh-313 / Raad-500 / Zohayr based, ~450–500 km) |

- **Launch sites:** the Houthis may build the missile silo, which stands in for their tunnel and dispersed launch sites.
- **Nuclear:** nothing, as before. No reactor, and no nuclear programme.
- **The other five:** field no ballistic or cruise missiles. Ethiopia's long-range rockets are not established well enough to name.

## Generals

Officer corps doctrines:

| Entity | Doctrines | Why |
|---|---|---|
| Yemen | infantry, fortress, logistician | |
| Houthis | drones, infantry, fortress | |
| Ethiopia | drones, infantry, airpower | it fought the Tigray war with drones |
| Nigeria | infantry, airpower, logistician | it relies on air support against insurgents |
| Sudan | drones, gunner, infantry | the army's drone war |
| South Sudan | infantry, reckless, fortress | |

General surnames are invented, in each country's naming tradition.

## Town plans

- **Grid:** Sudan (Khartoum was laid out on a planned grid).
- **Organic:** the rest.

## Sources

- **Houthis:**
  - https://www.dia.mil/News-Features/Articles/Article-View/Article/3662325/
  - https://missilethreat.csis.org/wp-content/uploads/2020/06/The-Missile-War-in-Yemen_June-2020.pdf
  - https://www.wilsoncenter.org/article/houthi-arsenal
  - https://www.haaretz.com/israel-news/security-aviation/2023-12-12/ty-article-magazine/houthis-threaten-red-sea-shipping-with-groundbreaking-iranian-missile/0000018c-5aa4-df2f-adac-feadd7220000
  - https://mei.edu/publication/houthis-red-sea-missile-and-drone-attack-drivers-and-implications/
  - https://www.aljazeera.com/news/2025/3/20/houthis-claim-missile-launch-at-israel-amid-renewed-fighting-in-gaza
  - https://www.thenationalnews.com/news/mena/2026/05/11/houthis-expanding-weapons-cache-with-drones-and-missiles-from-iran/
- **Yemen government:**
  - https://acleddata.com/yemen-conflict-observatory/actor-profiles/southern-giants-brigades
  - https://defence-blog.com/m109-howitzer-emerged-in-southern-yemen/
  - https://english.alarabiya.net/News/middle-east/2025/12/30/presidential-leadership-council-demands-uae-forces-withdraw-from-yemen-within-24-hours
- **Ethiopia:**
  - https://www.janes.com/osint-insights/defence-news/air/ethiopia-inducts-new-su-30-fighters-akinci-uavs
  - https://armyrecognition.com/archives/archives-land-defense/land-defense-2023/new-pictures-released-of-ethiopia-s-pantsir-s1-and-st-68um-radar-systems
  - https://military.africa/2023/01/ethiopia-buys-chinese-sh-15-pcl-181-artillery
- **Nigeria:**
  - https://en.wikipedia.org/wiki/List_of_equipment_of_the_Nigerian_Air_Force
  - https://en.wikipedia.org/wiki/List_of_equipment_of_the_Nigerian_Army
  - https://www.armyrecognition.com/news/navy-news/2025/nigerias-second-turkish-made-opv-76-offshore-patrol-vessel-completes-sea-trials
  - https://defensetalks.com/nigeria-to-receive-three-wing-loong-ii-ucavs-and-six-t-129-helicopters/
- **Sudan:**
  - https://www.military.africa/2025/04/turkish-bayraktar-tb2-drone-instrumental-in-sudans-advances/
  - https://thesoufancenter.org/intelbrief-2025-october-24/
  - https://www.criticalthreats.org/wp-content/uploads/An-Inventory-of-Foreign-Drones-in-Sudan%E2%80%99s-Civil-War-1.pdf
- **South Sudan:**
  - https://www.radiotamazuj.org/en/news/article/un-experts-question-airworthiness-of-sspdf-attack-helicopters
  - https://www.amnesty.org/en/latest/news/2025/05/south-sudan-un-security-council-must-renew-and-enforce-arms-embargo-to-protect-civilians/
- **Treaties:**
  - https://www.pgaction.org/news/south-sudan-bwc-accession.html
  - https://www.opcw.org/media-centre/news/2023/11/south-sudan-announces-new-step-accession-procedure-chemical-weapons
  - https://asp.icc-cpi.int/

## Judgement calls (open to revision)

- **Quality figures:** game balance by generation and upkeep, as in UNIT-QUALITY-RESEARCH. They are not readiness claims.
- **Names left uncertain:** several Sudanese and Ethiopian names (Khalifa, Taka, Al-Bashir, BTR-60/BMP-1) are the documented legacy and local-industry systems. Exact current inventories are unpublished.
- **Sudan:** stands for the army's authorities. The RSF is not represented, as in Codex's design.
