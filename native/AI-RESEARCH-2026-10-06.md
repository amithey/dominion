# Artificial intelligence in Dominion: research notes (2026-10-06)

This file holds the sources for the AI system: ai_directorate.gd, ai_data.gd and ai_panel.gd. Per the project rule, the game's own text never cites years, events or "as X did". The sources stay here and in code comments.

The user approved the proposal at https://claude.ai/artifact/RTo2gGH4wHZfoPTXYLjcYL: every idea except preventive strikes on data centres.

## What the rules rest on

### Compute is concentrated
- The United States holds about 75% of frontier AI compute and China about 12–15%; about 70% of new AI data-centre power goes to the US (Epoch AI).
- Export controls on advanced chips moved to case-by-case licensing. China works around them through data centres in Southeast Asia, smuggling and domestic chips.
- Rule: national compute = profile × 0.1/s. The AI Data Center gives 1/s.

### Data centres are big physical and energy assets
- Stargate in the US is a $500B venture: https://defenseone.com/business/2025/01/industry-launches-100b-ai-infrastructure-effort-keep-ahead-china/402396
- Stargate UAE: a 1 GW cluster on a campus of up to 5 GW: https://www.khaleejtimes.com/business/innovation-city/inside-the-uaes-30-bn-ai-bet-where-stargate-innovation-city-and-the-gccs-compute-map-intersect
- Saudi Humain plans up to 500 MW.
- Rule: a data centre burns silicon and money, gets a bonus with a power plant, and is a target.

### National standing
- The Stanford AI Index 2026 ranks the US first, China second and the UK third. The model gap between the US and China has nearly closed, while US private investment is about 23 times China's: https://starkinsider.com/2026/04/stanford-2026-ai-index-report.html
- Other national rankings: https://etcjournal.com/2026/07/10/top-10-countries-in-ai-rd-july-2026/
- China's "AI+" plan sets adoption targets of over 70%, then over 90%: https://www.striderintel.com/blog/the-prcs-15th-five-year-plan-inside-the-ai-agenda/
- Rule: the ai_data.gd PROFILE table.

### Battlefield autonomy
- Russia's V2U selects its targets autonomously, using a Jetson Orin computer and terrain maps, with code updated weekly: https://euromaidanpress.com/2025/06/09/russias-v2u-drone-uses-ai-for-autonomous-strikes-in-ukraines-sumy-oblast/
- Russia has overtaken Ukraine in the large-scale use of onboard AI: https://www.pravda.com.ua/eng/news/2026/09/04/8051922/
- Ukrainian interceptors automate about 95% of an interception: https://threatcluster.io/cluster/ukrainian-ai-drones-achieve-autonomous-interception-of-russi-71ea7468
- SkyFall's P1-SUN interceptor carries an AI module: https://www.pravda.com.ua/eng/news/2026/07/21/8045166/
- Fibre shortages push both sides toward onboard autonomy: https://www.imeche.org/news/news-article/what-will-come-next-in-ukraine-s-drone-war
- Rules: the autonomy doctrine reduces jamming, and seekers choose high-value targets at level 3.

### AI targeting at scale
- Maven makes about 1,000 targeting recommendations an hour, and about 20 people match a 2,000-person cell. NATO bought it.
- Reported Israeli targeting systems operate with minimal human review: https://www.972mag.com/lavender-ai-israeli-army-gaza/
- Rule: the Targeting Fusion Cell. In out-of-the-loop mode it sometimes marks civilian buildings.

### Automation bias and incidents
- Automation bias reduces humans to rubber stamps: https://cset.georgetown.edu/publication/ai-safety-and-automation-bias/
- Rule: incidents are rare "on the loop" and frequent "out of the loop". Better models make fewer mistakes.

### Governance
- The UNGA First Committee resolution on lethal autonomous weapons passed 156–5–8.
- The CCW talks produced a non-binding framework.
- The REAIM Blueprint on human control of nuclear weapons was signed by about 60 states; China did not sign: https://www.computing.co.uk/news/2024/ai/china-rejects-ai-nuclear-deal
- The leaders of the US and China agreed that humans keep control of nuclear decisions: https://www.brookings.edu/articles/advancing-human-control-of-military-ai/
- Rule: civilian incidents are tabled at the Security Council. UN AI treaties come in package 2.

### AI cyber operations
- A state-sponsored AI agent did 80–90% of an intrusion campaign against about 30 targets: https://assets.anthropic.com/m/ec212e6566a0d47/original/Disrupting-the-first-reported-AI-orchestrated-cyber-espionage-campaign.pdf
- The UK AISI estimates that frontier cyber-offence capability doubles about every four months: https://ai2.work/blog/ai-cyber-offense-capability-now-doubles-every-four-months-aisi-warns
- Rule: AI cyber campaigns spend compute instead of an agent, reach several targets, and rivals run them too.

### Influence operations, escalation and bio risk (packages 2 and 3)
- Deepfake campaigns: https://www.fdd.org/analysis/2025/10/07/lawmakers-bullseye-and-bait-in-ai-driven-deepfake-campaigns/
- Escalation by LLMs in wargames: https://hai.stanford.edu/policy/policy-brief-escalation-risks-llms-military-and-diplomatic-contexts and https://euronews.com/2026/02/27/ai-chatbots-chose-nuclear-escalation-in-95-of-simulated-war-games-study-finds
- Biosecurity risk from frontier models: https://www.belfercenter.org/research-analysis/dual-use-frontier-ai-enabled-biotechnology-civilian-opportunities-national

## Packages

1. **0.9.74:** F1 compute and data centres, F2 research chain and levels, F3 profiles, U1 AI tab, M1 doctrine, M2 fusion cell, M3 seekers and jam-resistant drones, I2 AI cyber.
2. **Next:** E1 AI economy and automation, E2 chips and export controls, I1 imagery analysis, I3 synthetic influence, I4 model theft, M4 collaborative combat aircraft, M5 air-defence battle management, S2 UN AI treaties.
3. **Then:** S1 automated early warning, S3 the AGI project with alignment and a Technological Supremacy victory.
