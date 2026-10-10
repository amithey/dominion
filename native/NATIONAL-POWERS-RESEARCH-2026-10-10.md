# National powers: each nation's real lever on another state (2026-10-10)

**The question (player report):** each nation has a "special option" on the Diplomacy screen. Research every nation in depth: how can it really change another state's situation? Keep, change, add or remove each power accordingly.

**Code:**
- `scripts/faction_powers.gd`: the original nine nations.
- `scripts/additional_powers.gd`: the thirteen later nations.

The game's text never cites dates or events. Those appear only here.

## What was wrong

- **Eight of 22 powers did not act on another state at all.** They were domestic buffs:
  - the UK's Trade Shield;
  - South Korea's Industrial Mobilization;
  - Saudi Arabia's Vision Investment;
  - Indonesia's National Nutrition;
  - Ukraine's Emergency Reconstruction;
  - North Korea's Artillery Readiness;
  - Egypt's Logistics Hub;
  - Australia's Mining Boom.
- **Pakistan's power was joint research**, not the lever Pakistan actually pulled.
- **Russia's gas lever is mostly gone.** Russia's share of EU pipeline gas imports fell from about 40% to about 6%, and the EU is banning the rest.
- **Iran could close Hormuz in peacetime.** In reality it closed the strait under attack.
- **A bug: covert operations started wars.** Any damage the player dealt to a nation at peace declared war. So the deniable Mossad operation ("never traced") opened a war, and so did insurgent attacks. Covert damage is now marked `covert` and starts no war (`world.gd` damage).

## Every nation

| Nation | Power now | Change | What it does | Why (evidence) |
|---|---|---|---|---|
| United States | Dollar Sanctions | kept | the target's income -30%, 3 min | secondary sanctions through the dollar system (Iran's oil, Russia's oil majors) |
| China | Rare-Earth Export Controls | kept | the target's military factories stop, 90 s | April and October 2025 controls; a truce with the US paused only the October layer; still used on the US and Japan in 2026; heavy rare-earth exports down ~50% (RSIS; Reuters via Engineering News) |
| European Union | Sanctions Package | kept | the target's income -20%, and partners turn against it | the 18th and 19th packages; a ban on Russian gas imports |
| Iran | Close the Strait of Hormuz | now only at war | everyone else's sea trade stops, 2 min | the IRGC declared Hormuz closed after the strikes of 28 Feb 2026; tanker traffic stopped; Brent +14% (CRS report; NPR) |
| Russia | **Hybrid Sabotage** (was Energy Leverage) | changed | one building burned (30%); income -12%, 150 s; a trade shipment lost if the target is the player; deniable (-8 relations, no war); not on an ally | cables cut by shadow-fleet anchors; rail sabotage and arson through proxies recruited on Telegram; 30 airspace violations Sep 2025–Jan 2026 (Recorded Future; IISS dataset; Atlantic Council) |
| India | Strategic Autonomy | kept | relations +12 with every nation | Quad and BRICS, Russian oil and US markets at once. Its coercive levers (the Indus Waters Treaty "in abeyance", rice export bans) bind only Pakistan and food importers, so they are left out of a general power. |
| Japan | Development Aid | kept | relations +25 and a non-aggression pact | ODA, and since 2023 Official Security Assistance (Philippines, Malaysia, Bangladesh, Fiji) |
| Türkiye | Istanbul Talks | kept | ends a war | Russia–Ukraine talks and prisoner exchanges in Istanbul (2025); a co-mediator of the Afghanistan–Pakistan ceasefire (Oct 2025) and the Gaza deal |
| Israel | Mossad Operation | kept (and now really deniable) | sabotage, a dossier, stolen research | the pager operation; Rising Lion |
| United Kingdom | **Maritime Insurance Ban** (was Trade Shield) | changed | the rival's sea trade stops and its income falls 15%, 150 s; not on an ally | London writes about 60% of P&I cover; the maritime-services ban underlies the G7 oil price cap (S&P Global; OFSI guidance) |
| South Korea | **Arms Export Deal** (was Industrial Mobilization) | changed | a partner gets 2 tanks and an artillery piece; Korea earns $900 | Poland: 672 K2, 648 K9 and 48 FA-50 on export credit, with deliveries in months; Korea 10th in SIPRI arms revenues |
| Saudi Arabia | **OPEC+ Output Cut** (was Vision Investment) | changed | the world oil price +35% for 3 min; Saudi income +15%; Washington -8 | OPEC+ cuts of about 2 mb/d; the cut that angered Washington; a budget-balancing price near $81 |
| Brazil | Food Diplomacy | kept | food to a partner | a leading exporter of soy, beef and chicken |
| Indonesia | **Export Ban** (was National Nutrition) | changed | the rival's military factories stop 45 s; its income -10%, 2 min; not on an ally | the palm oil export ban (Apr–May 2022): India got no Indonesian crude palm oil that May and Pakistan's purchases fell 90%; the nickel ore bans (Indonesia now dominant in mined nickel) |
| Ukraine | **Long-Range Drone Strikes** (was Emergency Reconstruction) | changed | at war only: two refineries, plants or factories -35%; income -12%, 2 min | 17–20% of Russian refining capacity offline in Aug–Oct 2025; crude runs at a two-decade low (Reuters via Kyiv Post; Kpler) |
| North Korea | **Crypto Heist** (was Artillery Readiness) | changed | takes a quarter of a rival's treasury, up to $900; traced half the time (-15); no war; not on an ally | Lazarus/TraderTraitor: about $1.5 bn from Bybit; more than $2 bn in 2025; it funds the weapons programmes (FBI; Elliptic; the US threat assessment) |
| Egypt | **Suez Canal** (was Logistics Hub) | changed | a friend: its voyages 30% shorter for 2 min and +12 relations; an enemy at war: its sea trade stops for 2 min | the canal; Egypt closed it to shipping at war in the past; a mediator in Gaza and keeper of Rafah |
| Australia | **Critical Minerals Pact** (was Mining Boom) | changed | ore (80 iron, 20 uranium) delivered to a partner; Australia earns $700 | the US–Australia framework (Oct 2025): $1 bn from each side, an $8.5 bn pipeline; largest economic reserves of iron ore and uranium (Geoscience Australia) |
| Pakistan | **Mutual Defence Pact** (was Defence Partnership) | changed | with a friend (+20): an alliance, "an attack on one is an attack on both" | the Saudi–Pakistan Strategic Mutual Defense Agreement, 17 Sep 2025 (AP; Belfer Center) |
| Iraq | Popular Mobilization | kept | six militia fighters; Washington -6, Tehran +4 | PMF; the attacks on US sites in 2026 |
| Syria | Reconstruction Aid | kept | donors pay; buildings repaired | sanctions relief and donor conferences after the fall of Assad |
| Afghanistan | Insurgent Attacks | kept (now a covert act) | attacks deep inside an enemy | Pakistan blames the Taliban for TTP attacks (23 killed on 10 Oct 2025); border war, then a ceasefire; the Kunar dam ordered as pressure |

**How rivals use them:**
- A hostile lever goes only at an enemy: at war first, otherwise at -30 relations or worse (`additional_powers.ai_target`).
- A friendly lever goes to the nation's closest partner.

## Sources

- **UK insurance:**
  - https://www.spglobal.com/commodityinsights/en/market-insights/latest-news/oil/110422-uk-shipping-insurance-ban-for-russian-oil-paves-way-for-g7-price-cap
  - https://www.gov.uk/government/publications/uk-maritime-services-ban-and-oil-price-cap-industry-guidance/uk-maritime-services-ban-and-oil-price-cap-industry-guidance
- **Korean arms:**
  - https://www.koreaherald.com/article/10554365
  - https://www.seoulz.com/korea-defense-industry-2026/
- **Saudi Arabia / OPEC+:**
  - https://fortune.com/2024/06/02/opec-meeting-oil-production-cuts-2025-crude-prices-saudi-arabia
  - https://aa.com.tr/en/world/sarabia-deposits-3b-each-in-egyptian-pakistani-central-banks/2408554
- **Indonesia:**
  - https://www.mining.com/indonesia-ban-rocks-nickel-market-29788/
  - https://databoks.katadata.co.id/en/trade/statistics/c4ac9bf6eff5237/despite-being-a-regular-buyer-india-did-not-receive-indonesian-cpo-in-may-2022
- **Ukraine:**
  - https://www.kyivpost.com/post/64235
  - https://euromaidanpress.com/2025/08/19/three-week-ukrainian-drone-blitz-cuts-13-5-of-russian-oil-capacity-triggers-price-crisis/
- **North Korea:**
  - https://www.aljazeera.com/news/2025/3/27/north-koreas-kim-jong-un-oversees-tests-of-new-ai-equipped-suicide-drones
  - https://www.reed.senate.gov/news/releases/warren-reed-press-treasury-and-doj-on-north-koreas-15-billion-crypto-heist
  - https://www.upi.com/Top_News/World-News/2025/10/08/9621759897376/
- **Pakistan:**
  - https://www.wsls.com/news/world/2025/09/17/pakistan-saudi-arabia-sign-defense-agreement-to-treat-an-attack-on-one-as-attack-on-both/
  - https://www.belfercenter.org/research-analysis/beyond-hype-pakistan-saudi-defense-pact-not-saudi-nuclear-umbrella-0
- **Russia:**
  - https://www.recordedfuture.com/blog/russia-new-generation-warfare
  - https://www.atlanticcouncil.org/blogs/ukrainealert/russia-intensifies-shadow-war-to-undermine-support-for-ukraine/
  - https://consilium.europa.eu/en/infographics/where-does-the-eu-s-gas-come-from
- **Iran (Hormuz):**
  - https://news.usni.org/2026/03/13/report-to-congress-on-the-iran-conflict-and-strait-of-hormuz
  - https://www.marineinsight.com/shipping-news/irans-irgc-declares-strait-of-hormuz-closed-warns-it-will-set-ships-ablaze-if-they-attempt-transit/
- **China:**
  - https://rsis.edu.sg/rsis-publication/idss/ip26004-chinas-strategic-design-and-cautious-calibration-of-rare-earth-leverage/
  - https://www.mining.com/?p=1191831
- **India:**
  - https://asiatimes.com/2026/06/water-wars-washing-away-south-asias-fragile-peace/
  - https://www.ers.usda.gov/data-products/charts-of-note/107638
- **Egypt:** https://arab.news/gepg3
- **Australia:**
  - https://magneticsmag.com/usa-australia-critical-minerals-framework-signed-by-president-trump-and-prime-minister-albanese/
  - https://ga.gov.au/digital-publication/aimr2022/world-rankings
- **Japan:** https://www.isdp.eu/publication/japans-official-security-assistance-to-the-philippines-legitimizing-a-new-strategic-tool/
- **Türkiye:** https://arab.news/5e7f7
- **Afghanistan:**
  - https://v1.afintl.com/en/202510240194
  - https://worldview.ranenetwork.com/content/analysis/2025-10-14/deadly-border-clashes-sharply-escalate-afghanistan-pakistan-tensions
- **Iraq:** https://www.rudaw.net/english/middleeast/iraq/190320262
