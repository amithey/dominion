# Who can really use AI and nuclear weapons: research per nation (2026-10-10)

**The question (player report):** "Iran and Afghanistan should not be warning about nuclear use or taking up AI." For each of the game's 22 nations, this document checks:
- whether it can field military AI, and how far it can go;
- whether it has nuclear weapons to threaten with.

**Code:**
- `scripts/ai_data.gd`: the ceiling and the reason per nation.
- `scripts/defcon.gd`: nuclear tension and the player's alert.
- `scripts/diplomatic_contacts.gd`: the escalation warning.
- `scripts/cbrn_data.gd`: who holds which weapon (unchanged; see ARSENAL-RESEARCH-2026-10-06.md).

The game's text never cites dates or events. Those appear only here.

## What was wrong

1. **Nuclear release for nations without the bomb.** The Defence window showed "Nuclear release: authorised" to any nation at DEFCON 2, Afghanistan included.
2. **Nuclear tension from nations without the bomb.** A non-nuclear player who raised the alert set the *world's nuclear* tension to that level. Its own fight for survival did the same.
3. **Empty escalation threats.** Any nation could send an "Escalation warning" beyond conventional arms, and 30% of the time it was heeded with no bomb behind it.
4. **AI had no national limit.** Every nation could research and train AI up to frontier models. Brazil, Indonesia, Egypt, Pakistan and Iraq had no AI profile at all.

## The rules now

- **Nuclear status decides the nuclear ladder.** Only a nation with nuclear weapons moves the world's nuclear tension through its alert or its survival. A breakout counts: a threshold state that builds the bomb becomes one.
- **Mobilising without the bomb.** A non-nuclear nation still mobilises with the same production and damage effects. The text says it is a conventional mobilisation, and neighbours take it less badly (-4 instead of -8).
- **The escalation warning depends on what backs it:**
  - **Nuclear powers:** as before.
  - **A threshold state** (Iran; Saudi Arabia only once Iran has broken out): it can only threaten to leave the NPT and build the bomb. This is weaker than a real threat: heeded about 35% of the time, otherwise relations -6.
  - **Everyone else:** the warning is not offered ("would not be believed").
- **Each nation has an AI ceiling (0–5)**, the highest AI level it can reach at all, whatever it researches or builds:
  - Research beyond the ceiling is refused, and the reason is shown.
  - Rivals never train past their ceiling.
  - A rival with ceiling 0 builds no AI data centres.
  - What each discovery needs: Machine Learning 1; Military AI and Collaborative Combat Aircraft 3; Frontier Models and the AGI Project 4.
- **What the levels mean:** 5 frontier; 4 near-frontier; 3 military AI at scale; 2 applied machine learning; 1 little more than imported software; 0 none.

## Per nation

**Nuclear status** in the table means:
- **Armed:** SIPRI 2025 estimates of warheads.
- **Threshold:** could build a bomb quickly.
- **Latent:** enrichment or reprocessing know-how, or a security guarantee, but no programme.
- **None.**

| Nation | Nuclear | AI ceiling | Why (the reason shown in the game, condensed) |
|---|---|---|---|
| United States | armed (~5,177) | 5 | About 75% of frontier compute; the leading laboratories (Epoch AI; Stanford AI Index) |
| China | armed (~600) | 5 | Frontier models of its own; second in compute despite chip controls |
| United Kingdom | armed (~225) | 4 | Third in the Stanford Global AI Vibrancy ranking (2024 edition); DeepMind; the AI Security Institute; little compute |
| European Union (France's deterrent) | armed (~290) | 4 | Strong research; EuroHPC AI factories; few frontier laboratories |
| Japan | latent; US umbrella | 4 | Public supercomputers (ABCI); chip-making tools; models trail the leaders |
| South Korea | latent; US umbrella; a debate at home over nuclear latency | 4 | Memory chips for AI (HBM); a national GPU build-out |
| India | armed (~180) | 4 | Third in the Stanford Global AI Vibrancy Tool, 2025 edition; the IndiaAI GPU mission |
| Israel | armed (~90, undeclared) | 4 | Dense AI industry; targeting systems used at scale; little sovereign compute |
| Russia | armed (~5,459) | 3 | GigaChat and YandexGPT; onboard-AI drones (V2U); cut off from advanced chips by export controls |
| Saudi Arabia | threshold only if Iran breaks out (its leaders have said so) | 3 | Humain buys compute at scale; few researchers; no leading models; top of MENA in Oxford Insights' readiness index (2025 edition) |
| Türkiye | NATO sharing host (US B61s at Incirlik, released only by the US) | 3 | Autonomous drones from Baykar and STM; modest compute |
| Australia | none; US umbrella; nuclear-powered (conventionally armed) submarines under AUKUS | 3 | MQ-28 Ghost Bat loyal wingman; modest compute |
| Ukraine | none | 3 | The most battle-tested drone autonomy (autonomous interceptors, onboard AI); almost no compute |
| Brazil | latent (enrichment; naval reactor programme) | 3 | PBIA plan, R$23 bn; upgraded Santos Dumont supercomputer; a top-10 machine tendered; 22nd in Oxford Insights' 2025 readiness index |
| Indonesia | none | 2 | An AI Center of Excellence with Nvidia, Cisco and Indosat; a national AI roadmap; capacity mostly planned, not built |
| Iran | threshold (about 440 kg of 60% HEU before the strikes, now unverified) | 2 | Officials' AI-guided drone and missile claims; sanctions bar advanced chips; a $115 M national plan |
| Pakistan | armed (~170) | 2 | First National AI Policy; a few thousand GPUs (Data Vault, Sky47); power and connectivity gaps |
| Egypt | none (El Dabaa civil reactor being built) | 2 | National AI Strategy 2025–2030 with no plan for compute; no hyperscaler; a data-centre strategy still being drafted |
| North Korea | armed (~50) | 2 | Kim watched tests of drones described as "AI-equipped" (KCNA, March 2025; unverified); no modern chips; strong cyber |
| Iraq | none | 1 | 107th in Oxford Insights' 2024 readiness index; its first Tier III data centre still being built; summer grid failures |
| Syria | none | 1 | The grid supplies under a third of demand (only a few hours of power a day in 2025); rebuilding is targeted for 2030 |
| Afghanistan | none | 0 | No data centres; a total internet blackout in Sep–Oct 2025; women barred from study |

**Rivals at war with a nuclear power** still raise the world's alert as before (a nuclear power at war: DEFCON 4). That is about the nuclear power, not the rival.

## Sources

- **SIPRI Yearbook 2025** (warhead estimates): already cited in `cbrn_data.gd`.
- **AI indices:**
  - Oxford Insights, Government AI Readiness Index 2025: https://oxfordinsights.com/ai-readiness/government-ai-readiness-index-2025/
  - Stanford HAI, Global AI Vibrancy Tool: https://hai.stanford.edu/research/the-global-ai-vibrancy-tool-2024 and https://hai.stanford.edu/news/global-ai-power-rankings-stanford-hai-tool-ranks-36-countries-in-ai
- **Pakistan:**
  - https://babl.ai/pakistan-approves-landmark-ai-policy-2025-to-drive-digital-transformation/
  - https://profit.pakistantoday.com.pk/2025/12/01/pakistan-gets-its-first-home-grown-ai-ready-cloud-as-gpu-access-goes-local/
  - https://digitalrightsmonitor.pk/pakistan-inaugurates-its-largest-data-centre-in-islamabad/
- **Iran, AI:**
  - https://thenational-the-national-prod.cdn.arcpublishing.com/news/mena/2025/12/05/iran-ai-revolution-drones-chips-tech-race
  - https://www.specialeurasia.com/2025/03/24/iran-ai-silicon-persia/
  - https://www.atlanticcouncil.org/blogs/iransource/sanctions-propel-iran-in-the-global-race-for-terminator-like-ai
- **Iran, nuclear:**
  - https://www.usnews.com/news/world/articles/2026-03-18/irans-nuclear-doctrine-not-likely-to-change-foreign-minister-says
  - https://english.news.cn/20260709/0903bf97d4de4a0cb85e88e05a42282d/c.html
  - https://www.aljazeera.com/news/2026/5/22/irans-enriched-uranium-stockpile-can-it-be-safely-transferred
  - https://isis-online.org/isis-reports/analysis-of-iaea-iran-verification-and-monitoring-and-npt-safeguards-reports-june-2026
  - https://carnegieendowment.org/research/2026/07/demystifying-the-nuclear-threshold
- **North Korea:** https://www.aljazeera.com/news/2025/3/27/north-koreas-kim-jong-un-oversees-tests-of-new-ai-equipped-suicide-drones
- **Egypt:**
  - https://meobserver.news/technology/2026/08/26/egypts-ai-ambition-has-a-compute-problem/
  - https://www.middleeastainews.com/p/egypt-to-draft-national-data-centre
- **Indonesia:**
  - https://blogs.nvidia.com/blog/indonesia-ai-center-of-excellence
  - https://futurumgroup.com/insights/from-blaize-to-nvidia-why-is-ai-infrastructure-converging-on-indonesia/
- **Brazil:**
  - https://camposthomaz.com/en/conhecimento-ct/brazil-unveils-final-version-of-national-ai-plan-with-r-23-billion-investment/
  - https://www.aljazeera.com/economy/2026/8/21/brazil-launches-ai-supercomputer-push-while-balancing-us-and-chinese-tech
- **Iraq:**
  - https://www.shafaq.com/en/Economy/Power-grid-will-decide-Middle-East-s-AI-future-US-expert-warns
  - https://meatechwatch.com/2026/07/13/schneider-electric-to-power-iraqs-first-tier-iii-data-center/
- **Syria:**
  - https://english.enabbaladi.net/archives/2025/08/syrias-energy-ministry-says-electricity-supply-to-rise-as-azerbaijani-gas-deliveries-stabilize/
  - https://www.aljazeera.com/features/2026/7/13/its-expensive-syrias-electricity-has-improved-but-challenges-remain
- **Afghanistan:**
  - https://www.amnesty.org/en/latest/news/2025/09/afghanistan-taliban-de-facto-authorities-must-immediately-restore-internet-access/
  - https://cadeproject.org/updates/internet-restored-in-afghanistan-after-48-hour-shutdown/
- **Latency (Japan, South Korea, Brazil, Saudi Arabia):**
  - https://rsis.edu.sg/rsis-publication/rsis/nuclear-latency-is-not-nuclear-proliferation/
  - https://tnsr.org/2026/06/what-good-is-a-nuclear-threshold-capability-lessons-from-irans-nuclear-program-and-recent-regional-conflict/
- **Other sources:** the AI basis (compute shares, battlefield autonomy, REAIM) is in AI-RESEARCH-2026-10-06.md; nuclear arsenals and treaties are in ARSENAL-RESEARCH-2026-10-06.md and CBRN-UN-RESEARCH-2026-10-05.md.

## Judgement calls (open to revision)

- **Russia (3, not 4):** chip sanctions keep it from frontier scale even though its battlefield autonomy is advanced (autonomy rating 4).
- **Saudi Arabia (3):** it can buy compute but has few researchers. Its compute rating stays 3.
- **Israel (4):** world-class applied military AI, but not a frontier compute holder.
- **Indonesia (2):** its large projects are plans. Raise it if they are built.
- **Iran (2):** its military AI claims are mostly the government's own and unverified. Sanctions keep it from training at scale.
