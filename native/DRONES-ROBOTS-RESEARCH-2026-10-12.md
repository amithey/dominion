# Drones and robots entering armies (2026-10-12)

**The question (player):** add more drones and the robotic systems that are starting to enter armies. Research them, and give each nation what it really has.

**What the game had:**
- **Drones.**
  - MALE drones with national names: MQ-9, Wing Loong II, TB2, Orion, Heron TP, Mohajer-6, Hermes 900 and others.
  - Loitering munitions: Switchblade 600, CH-901, HX-2, Lancet-3, Kargu-2, Hero-120, Nagastra-1 and others.
  - FPV teams, with a researched **fibre-optic upgrade** for Russia and Ukraine (unjammable).
  - Interceptor drones, Shahed, Harop, Akinci, loyal wingmen and sea drones.
  - An uncrewed submarine (Orca).
- **Robots:** none.

## What was added (0.9.96)

| Role | In the game | Who | Evidence |
|---|---|---|---|
| **Armed ground robot** | A tracked chassis with a remote weapon station (heavy machine gun). Cheap; its loss costs **no war support**. A human operator fires it. | Ukraine Droid TW 12.7; Russia Uran-9; EU THeMIS (armed); UK THeMIS; Israel Jaguar UGV; China Sharp Claw | Ukraine's 5th Assault Brigade used a Droid TW 12.7 against an MT-LB from over a kilometre away. A machine-gun UGV reportedly held a position for about 45 days, and Russian soldiers surrendered to one near Lyman (Lowy). THeMIS is in service with 16 countries, including Estonia, France, Germany, the Netherlands, Norway, Spain and the UK. Russia's Uran-9 was combat-tested in Syria. China's Sharp Claw has been displayed. Israel's Jaguar patrols the Gaza border. **The USA is excluded:** its armed UGVs are trials only. |
| **Logistics robot** | Unarmed. The most-hurt infantry within 14 recovers 6 health a second (casualty evacuation and resupply). No war support lost. | Ukraine Termit / Gimli; Russia Kurier; USA S-MET; EU and UK THeMIS Cargo | Ukraine's MoD adopted the Gimli line (Feb 2025) for evacuation and ammunition; a 42nd Brigade UGV carried two wounded about 8 km. Ukraine reports 7,000+ UGV missions in a month and targets 50,000 robots in 2026. Russia fields Courier/Kurier, Depesha and Impuls (Bendett). The US Army fields the S-MET. |
| **Armed robot dog** | A small four-legged robot with a rifle, for scouting and street fighting. Fragile; no war support lost. | China | China showed a weapon-carrying robot dog in its Golden Dragon exercise with Cambodia (2024), and researchers proposed heavier armament. **Not included:** the US (Vision 60 with a rifle: trials only), South Korea (a six-month counter-terror trial), and Ukraine (its robot dogs reportedly failed field tests). |
| **Heavy bomber drone** | A large hexacopter that loiters low and drops bombs (mostly at night). It holds no parking slot and stays aloft until shot down. No war support lost. | Ukraine Vampire ("Baba Yaga"); Russia (heavy hexacopter copies) | The Vampire carries up to 15 kg over 20 km, with thermal imaging for night missions. Ukraine's MoD bought more than 2,000 in one year at about $20,000 each. Russian copies have been shot down by the 81st Brigade (2026). |

**Not duplicated.** The fibre-optic FPV (Russia's KVN, Ukraine's equivalents) already exists in the game as a researched upgrade of the FPV team (`unit_quality.UPGRADES`, flag `fibre_optic`). A separate unit was drafted and then removed.

## Sources

- **Ground robots:**
  - https://www.army-technology.com/news/ukraine-will-deploy-gimli-a-new-line-of-logistical-ugvs/
  - https://www.lowyinstitute.org/the-interpreter/ukraine-ground-robots-are-increasingly-going-offensive
  - https://euromaidanpress.com/2026/04/28/ukraine-plans-50000-ground-robots/
  - https://asiatimes.com/2026/07/ukraines-robot-army-advancing-on-the-wars-front-lines/
  - https://armyrecognition.com/archives/archives-land-defense/defense-news-army-2025/ukraine-fields-combat-ready-ugvs-as-russia-counters-with-its-own-robotic-breaching-units
  - https://www.defensenews.com/global/europe/2020/11/06/estonian-robotics-company-makes-inroads-with-european-armies/
- **Robot dogs:**
  - https://thedefensepost.com/2024/08/12/us-rifle-robot-dogs
  - https://thedefensepost.com/2024/08/13/south-korea-robot-dog/amp/
  - https://euromaidanpress.com/2025/04/18/forbes-ukraines-robot-dogs-failed-the-war-test-they-couldnt-hide-from-russians-humanoid-robots-are-up-next/
- **Fibre-optic FPV:**
  - https://en.wikipedia.org/wiki/Ushkuynik_KVN
  - https://tass.com/defense/2064423/amp
- **Heavy bomber drones:**
  - https://mod.gov.ua/en/news/the-vampire-a-drone-that-terrifies-enemies-and-assists-ukrainians
  - https://euromaidanpress.com/?p=395450
- **Loitering munitions:**
  - https://www.czdefence.com/article/loitering-munition-for-the-army-of-the-czech-republic-the-israeli-system-was-also-chosen-by-the-us-marine-corps
  - https://thedefensepost.com/2025/10/10/rheinmetall-loitering-munitions-sardinia/amp/

## Judgement calls

- **Robots and war support.** A robot's loss costs no war support, because no soldier dies. It still costs money and production.
- **Human control.** The armed robot is remote-controlled; Milrem states "pulling the trigger is always done by the human". AI-autonomous firing remains the AI directorate's doctrine choice.
- **No national names without a documented system.** Nations without a documented system get no robot.
