# AI in war, the state, the economy and the "doomsday" chain: who uses what (2026-10-11)

**The question (player).** The game already has AI and ways to use it. Research more deeply how AI is used:
- militarily;
- politically and by the state;
- economically;
- in "doomsday weapons".

Note which nation uses what, and make development and use more practical, with a next stage of research.

**What the game had.** Codex's practical applications built the pipeline: research, then local validation, then paid commissioning, then compute-limited service. That covered twelve civil, military and state programmes (see native/AI-APPLICATIONS-RESEARCH-2026-10-11.md). The AI directorate already had:
- compute, AI levels and autonomy doctrine;
- cyber campaigns, synthetic influence and model theft;
- chip export controls;
- automated early warning and the AGI project.

**What this adds** (0.9.92):
- nine strategic applications in the same pipeline;
- a per-nation record of who fields what (`scripts/ai_use_data.gd`), with mechanical consequences;
- a dead-hand doomsday mechanic;
- AI exports;
- a "second generation", the next research stage: systems in service gather the field data that trains their successors.

The game's text never cites years or events; they appear only here.

## What the public record shows

### Military

**Targeting decision support** is the most consequential military use now in service.
- **United States.** The Maven Smart System fuses sensor feeds into target nominations for commanders. It is shared with allies (NATO bought a version) and was used against targets in Iraq, Syria and Yemen.
- **Israel.** +972 Magazine and Local Call reported "The Gospel" (buildings) and "Lavender" (people) generating target recommendations in Gaza. They reported a permissive review process; the IDF says every strike is reviewed by humans. The reporting and the denial disagree, and the game says only "reported".
- **Ukraine.** Its battlefield-awareness systems (Delta, Kropyva) turn drone video into fire missions.

**In the game,** artillery, rockets and strike aircraft deal +8% damage. The lesson of the reporting is that speed outruns review. Targeting support therefore raises the civilian-strike rate even under "human in the loop": half the risk, never zero.

**Counter-drone.**
- The US Replicator initiative's second line of effort is countering small drones.
- Ukraine's acoustic network (Sky Fortress) and interceptor drones, Israel's layered defence with its Iron Beam laser, and Russia's mass electronic warfare are all fielded.
- In the game: interception +6%.

**Undersea sensing (ocean transparency).**
- AI applied to passive sonar, seabed sensor networks and uncrewed vessels could erode submarine stealth.
- The peer-reviewed assessment (Sanchez, *International Security*, Summer 2026) finds the gains evolutionary. A threat to ballistic-missile submarines is judged highly unlikely for decades.
- Policy analysts (CSR, City St George's, AIIA) worry that even incremental gains, or the belief in them, raise crisis instability.
- Australia's Ghost Shark is in production. China's claimed AI anti-submarine system rests on simulations.
- In the game:
  - weapons hit submarines +20% harder;
  - a rival's second strike against the player is less certain (×0.75 at full coverage);
  - while you hunt a nuclear power's submarines in war, world nuclear tension rises +3 every 30 s. That is the destabilisation.

**Autonomous terminal guidance.** Codex's "resilient drone integration" and the existing doctrine cover this. Ukrainian intelligence reports that Russia's V2U loitering munition selects targets with an NVIDIA Jetson Orin board and navigates by terrain matching.

### The state and politics

**Mass surveillance.**
- **China:** nationwide facial-recognition camera networks (Skynet, Sharp Eyes), most intense in Xinjiang.
- **Russia:** Moscow's metro facial recognition was used to detain protesters (Amnesty; OVD-Info: 43 of 67 detentions on one day).
- **Iran:** a UN fact-finding mission (March 2025) found cameras, drones and the "Nazer" app used to enforce the hijab law.
- **Israel:** Amnesty documents facial recognition at West Bank checkpoints (Red Wolf).
- **EU:** the AI Act (Art. 5(1)(h), applied from 2 February 2025) prohibits real-time remote biometric identification in public spaces for law enforcement, with three narrow, judicially authorised exceptions. In the game the EU is **barred** from this application.
- **In the game:**
  - war-weariness turns into protest a third more slowly, because repression suppresses visible dissent;
  - enemy agents are caught more often;
  - happiness falls by 3;
  - every democracy's relations fall by 6 when it is commissioned.

**Influence operations.** OpenAI's threat reports (May 2024 – June 2025) removed networks from:
- Russia: Doppelgänger, Bad Grammar and "Helgoland Bite" on the German election;
- China: Spamouflage, "Sneer Review";
- Iran: Storm-2035;
- a commercial Israeli firm (STOIC).

OpenAI judged their reach small (no higher than 2 of 6 on the Breakout Scale).

In the game, the existing synthetic-influence operation now follows the record. Russia, China and Iran (status "fielded") start campaigns against the player sooner, and already at relations below −20 rather than only at −40 or war. They do not run any other operation at that level.

**Counter-disinformation.**
- The EU (the EEAS's foreign-manipulation tracking; the Digital Services Act) and Ukraine (its Centre for Countering Disinformation) field it.
- China, Russia and Iran field the authoritarian version, censorship.
- In the game: rival influence campaigns succeed 30 points less often and do half the harm.

### The economy

**Tax and fraud analytics** is the least glamorous and most widely fielded state AI:
- UK HMRC's Connect;
- India's Project Insight and GST analytics;
- Brazil's Receita Federal machine-learning selection;
- the US IRS audit selection;
- China's Golden Tax IV;
- EU VAT-fraud analytics.

In the game: income +5%.

**AI exports.** Two models compete:
- **China's Digital Silk Road.** Huawei "safe city" packages are in more than 50 Belt and Road countries (Feldstein, Carnegie), or 80+ by Recorded Future's count.
- **The US American AI Exports Program** (EO 14320, 23 July 2025): full-stack packages of chips, cloud, models and security for partners.

In the game, an AI-export service lets you sell a package to a nation at peace with you:
- you receive $900, or $1,350 for a second-generation package;
- relations +10;
- the buyer's models train faster;
- your espionage network in it grows +15, the data-access concern every buyer has.

Rivals that run it sell to their friends.

### The "doomsday" chain

**Automated retaliation (a "dead hand").**
- **Russia:** the Soviet Perimeter system is semi-automatic. In a crisis officers activate it; it can then launch command rockets if it detects nuclear detonations and loses contact with the leadership. A former Strategic Rocket Forces commander (Yesin) said it was maintained and improved. That is unverified, and Russia confirms nothing.
- **North Korea:** its September 2022 law on nuclear forces says that if its command and control "is placed in danger owing to an attack by hostile forces, a nuclear strike shall be launched automatically and immediately".
- **US, UK and France:** they committed to human control of nuclear employment decisions (their NPT RevCon working paper, 2022).
- **China:** its leader agreed with President Biden in Lima (16 November 2024) that humans, not AI, should control the decision to use nuclear weapons. In the game China now signs the existing "Declaration on Human Control of Nuclear Weapons" (`ai_data.gd`).

**In the game**, automated retaliation is a level-2 application. It is automation, not frontier AI, so North Korea's ceiling of 2 suffices. It is open to a nuclear power not bound by the declaration, and it needs a missile silo. Its effects:
- a nuclear detonation on your territory is answered with a stored warhead, by the machine, with no order;
- rivals are half as likely to use nuclear weapons on you;
- a rival that has it always strikes back (second strike 100%).

The price is the doomsday logic itself:
- the machine hears the same sensors as automated early warning, so it rolls false alarms even without early warning;
- each false alarm has a 12% chance of firing, less with strategic warning verification (×(1 − 0.6·coverage)). It never reaches zero.

A rival's machine fires on a false warning only at an enemy it is already fighting.

**Biosecurity.**
- Frontier laboratories now apply biological safeguards. Anthropic applies ASL-3 to its strongest models; OpenAI and Google DeepMind classify their models at or near "High" or alert thresholds for biology.
- The evidence on uplift is mixed. RAND (2024) found no significant uplift. The Virology Capabilities Test put o3 at the 95th percentile of virologists on tacit knowledge, yet a 2025 wet-lab RCT found little novice uplift.
- DNA-synthesis screening (the US framework; UK guidance) is the defensive layer.
- In the game, biosecurity screening:
  - stops most of an epidemic's spread between towns (spread chance ×(1 − 0.7·coverage));
  - shortens and weakens a runaway model's pathogen outbreak;
  - adds health +2.

It is defensive only. No application designs a pathogen.

## Who uses what (the game's record, `ai_use_data.gd`)

Statuses:
- **fielded:** documented use. Trials need half the compute, and a rival starts with it.
- **developing:** documented programmes. Trials need 80%.
- **barred:** forbidden by the nation's law. It cannot be commissioned.
- **pledged:** a declared commitment against it (the nuclear declaration); a nation may withdraw, at a price.
- **absent:** no public evidence. That is not proof of absence; full cost.

| Nation | Fielded | Barred / pledged |
|---|---|---|
| USA | targeting, counter-drone, revenue, exports, biosecurity | pledged: dead hand |
| China | surveillance, counter-disinformation (censorship), influence, revenue, exports | pledged: dead hand |
| EU | counter-disinformation, revenue | barred: surveillance; pledged: dead hand |
| UK | revenue | pledged: dead hand |
| Israel | targeting (reported), counter-drone, surveillance (West Bank) | — |
| Russia | counter-drone, surveillance, counter-disinformation, influence, **dead hand** | — |
| Ukraine | targeting, counter-drone, counter-disinformation | — |
| India | revenue | — |
| Australia | undersea (Ghost Shark), revenue | — |
| Brazil | revenue | — |
| Iran | surveillance, counter-disinformation (filtering), influence | — |
| North Korea | **dead hand** (its nuclear-forces law) | — |

All others have only "developing" entries or none. See the data file for each line of evidence.

## The next stage: the second generation

The user asked that development and use be "more practical, with a next stage of research". Codex's pipeline makes the first generation practical. The next stage follows how fielded AI really improves: the system's own service data trains its successor (the data flywheel).
- Every running application gathers field experience: one point a second at full coverage, up to twice its trial work.
- The new discovery **Fielded AI: the second generation** (era 4, needs Machine Learning and a university) opens the upgrade.
- The upgrade costs half the programme's capital. The application's effect is then half again as strong (×1.5). That applies to its bonuses, and to its risk reductions such as verification and audit.
- Rivals upgrade when they can.

## Files

- `scripts/ai_use_data.gd`: the record (28 nations × 10 domains) and its effects on trials and rival priorities.
- `scripts/ai_strategic.gd`: the dead hand (answer, accident, second strike), undersea tension and AI exports.
- `scripts/ai_applications_data.gd`: the nine applications, the second-generation discovery and GEN2. (Codex's file, extended.)
- `scripts/ai_applications.gd`, in Codex's file:
  - legal bars and the declaration on human control;
  - trial pace from the record;
  - field experience and the upgrade;
  - exports;
  - saves;
  - rival priorities.
- `scripts/ai_applications_panel.gd`: the tabs Civil economy, Military, Politics & state, Doomsday and Who uses what; "Your nation" lines; the experience bar and upgrade button; the export card.
- `scripts/ai_directorate.gd`:
  - damage (targeting, undersea);
  - the civilian-strike tempo risk;
  - interception;
  - counter-disinformation;
  - false alarms for a dead hand;
  - the biosecure pathogen;
  - practised influence actors.
- `scripts/defcon.gd` (the dead hand answers; second strike; first-use deterrence), `war_support.gd` (surveillance), `espionage.gd` (surveillance counter-intelligence), `wmd.gd` (biosecure spread), `world.gd` (damage gets its target), `ai_data.gd` (China signs the nuclear declaration).
- `tools/ai-strategic-check.gd`.

## Sources

- **Targeting:**
  - +972 Magazine, "'Lavender': The AI machine directing Israel's bombing spree in Gaza": https://www.972mag.com/lavender-ai-israeli-army-gaza/
  - Wikipedia, "AI warfare" (Maven use): https://en.wikipedia.org/wiki/AI_warfare
- **Replicator:**
  - CRS IF12611 (via everycrsreport)
  - USNI News: https://news.usni.org/2025/01/28/first-replicator-initiative-capability-on-track-for-august-officials-say
  - Shephard: https://www.shephardmedia.com/news/uv-online/us-replicator-programme-approaches-the-second-year-with-uncertainties-and-challenges-ahead/
- **Jiu Tian:**
  - OECD AI incidents: https://oecd.ai/en/incidents/2025-10-20-1d14
  - Grey Dynamics: https://greydynamics.com/jiu-tian-defence-game-changer-or-state-propaganda/
- **V2U:** https://www.longwarjournal.org/archives/2025/06/ukrainian-intelligence-details-russias-new-v2u-autonomous-loitering-munition.php
- **Ocean transparency:**
  - Belfer/International Security: https://www.belfercenter.org/research-analysis/seeing-through-transparent-oceans-emerging-technology-submarine-vulnerability-0
  - CSR: https://councilonstrategicrisks.org/2026/08/10/ai-and-the-hunt-for-ballistic-missile-submarines/
  - City St George's: https://www.citystgeorges.ac.uk/news-and-events/news/2025/september/ai-drone-ships-new-sensors-could-leave-submarines-few-places-hide-ocean
  - AIIA: https://www.internationalaffairs.org.au/australianoutlook/ocean-transparency-and-australias-impact-on-nuclear-stability/
- **Surveillance:**
  - Iran (UN): https://www.tribuneindia.com/news/world/iran-using-drones-facial-recognition-apps-to-enforce-hijab-laws-un-report/amp
  - Iran (Article 19): https://www.article19.org/resources/iran-tech-enabled-hijab-and-chastity-law-will-further-punish-women/
  - Russia (Amnesty): https://www.amnesty.org/en/latest/news/2021/04/russia-police-target-peaceful-protesters-identified-using-facial-recognition-technology/
  - Russia (RFE/RL): https://www.rferl.org/a/moscow-police-detain-dozens-using-facial-recognition-system/31896070.html
  - China exports: https://www.recordedfuture.com/research/china-digital-colonialism-espionage-silk-road
  - China exports: https://www.context.news/surveillance/activists-say-chinas-new-silk-road-equips-autocrats-with-spy-tech
- **EU AI Act:**
  - FPF: https://fpf.org/blog/red-lines-under-the-eu-ai-act-restricting-real-time-remote-biometric-identification-systems-for-law-enforcement-purposes/
  - eucrim: https://eucrim.eu/news/guidelines-on-prohibited-ai-practices/
- **Influence:**
  - https://therecord.media/openai-report-china-russia-iran-influence-operations
  - https://openai.com/global-affairs/disrupting-malicious-uses-of-ai-june-2025
- **AI exports:**
  - EO 14320: https://www.whitehouse.gov/presidential-actions/2025/07/promoting-the-export-of-the-american-ai-technology-stack/
- **Dead hand:**
  - IEEE Spectrum: https://spectrum.ieee.org/russias-doomday-device-supposedly-still-active-and-being-upgraded
  - CND (Yesin): https://cnduk.org/how-scrapping-the-inf-could-escalate-the-nuclear-arms-race/
- **North Korea's law:**
  - https://www.armscontrol.org/act/2022-10/news/north-korea-passes-nuclear-law
  - https://foreignpolicy.com/2022/09/16/north-korea-nuclear-weapons-law-kim-jong-un
  - https://www.heritage.org/china/report/the-troubling-new-changes-north-koreas-nuclear-doctrine
- **Human control of nuclear decisions:**
  - Biden–Xi, Lima: https://bangkokpost.com/world/2903556/biden-xi-agreed-that-humans-not-ai-should-control-nuclear-weapons-white-house-says
  - REAIM Seoul Blueprint (about 60 endorsers; China did not endorse): https://stratnewsglobal.com/general/blueprint-for-ai-use-in-military-endorsed-by-60-countries-china-opts-out/
- **Biosecurity:**
  - BioTIER: https://arxiv.org/pdf/2607.14479
  - uplift summary: https://www.longtermwiki.com/wiki/bioweapons-ai-uplift

## Judgement calls (open to revision)

- **Percentages, costs and timings** are game balance, not estimates.
- **Contested reporting** (Gospel/Lavender; Perimeter's status; Jiu Tian's flights) is shown in the game as "reported", and the counter-claims are recorded here.
- **North Korea's dead hand** is a legal provision, not a verified system. The game treats the law as the nation's intent.
- **"Pledged"** follows declared policy, not verified practice. The player may withdraw from the declaration, as before, at the existing diplomatic price.
- **The EU** stands for the Union. Member-state exceptions under the AI Act are not modelled, so "barred" is a simplification.
