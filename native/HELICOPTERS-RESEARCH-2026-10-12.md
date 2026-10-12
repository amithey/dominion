# Helicopters: more types, carrying troops and equipment (2026-10-12)

**The question (player):** add more helicopters, and let a helicopter take soldiers and equipment with it.

**What the game had:**
- a utility helicopter (national names already: UH-60M, Mi-8AMTSh, Z-20, NH90, Merlin, Surion, Dhruv...);
- a gunship (Apache, Ka-52, Z-10, Tiger, T129...);
- a reconnaissance helicopter.

**The gaps:**
- none could carry anyone;
- the utility helicopter wore the attack helicopter's mesh, with stub wings and missiles;
- there was no heavy-lift or naval helicopter.

## What changed (0.9.95)

- **Air assault** (`scripts/airlift.gd`).
  - **Boarding and landing.** Select troops and right-click your transport helicopter: they board. Select it and press **J** to land them on dry ground (`U` is the UN window). Over water it refuses.
  - **Loads.** Those aboard are kept as they were, with their health and experience, and are saved with the helicopter. They are lost with it.
  - **Utility helicopter:** 6 places, infantry only. A Black Hawk carries an 11-soldier squad; the game's soldier is a fire team.
  - **Heavy-lift helicopter:** 12 places. Light vehicles and towed guns take 6 places each:
    - the Chinook slings an M777 or an L118 light gun, and carries a light patrol vehicle;
    - the Mi-26 (20 tonnes internal) alone lifts an armoured carrier (12 places).
- **Heavy-lift helicopter** (new role):
  - the CH-47F Chinook: USA, Australia, India, the Netherlands for the EU, Türkiye;
  - Chinook HC6 (UK); CH-47JA (Japan); CH-47D (South Korea, Egypt);
  - the **Mi-26** (Russia);
  - the **Z-8L** (China).

  Iran's Chinooks are pre-revolution CH-47Cs, with readiness unverified, so none is granted.
- **Naval helicopter** (new role): a ship's helicopter with dipping sonar and torpedoes.
  - It reveals submarines within 60 and strikes them ×1.8, as the other submarine hunters do.
  - It cannot engage targets on land.
  - It wears the navy's grey.
  - By nation:
    - **MH-60R Seahawk:** USA, Australia, India, South Korea, Saudi Arabia;
    - **NH90 NFH:** EU (France's Caïman, Italy's SH-90A, Germany's Sea Lion);
    - **Wildcat HMA2:** UK;
    - **SH-60K:** Japan;
    - **Ka-27PL:** Russia;
    - **Z-20F:** China, the navalised Z-20;
    - **S-70B Seahawk:** Türkiye;
    - **SH-2G Super Seasprite:** Egypt;
    - **AS565 Panther:** Indonesia.
- **Models** (`craft.utility_helicopter`, `force_models.heavy_lift`):
  - **Utility helicopter:** a cabin with sliding doors and windows, a wide glazed cockpit, engines over the cabin, a tail boom with stabiliser and tail rotor, and a door gun.
  - **Chinook:** a long box fuselage, two counter-rotating three-blade rotors (both turn in the game), fuel sponsons and a rear ramp.
  - **Mi-26 and Z-8:** larger single-rotor airframes with more blades and a rear clamshell.
  - **Naval helicopter:** a sonar housing, a torpedo and a chin radar.

## Sources

- **Chinook:**
  - https://military-history.fandom.com/wiki/List_of_Boeing_CH-47_Chinook_operators
  - https://www.australiandefence.com.au/defence/air/south-korea-selects-ch-47f-as-next-heavy-lift-helicopter
  - https://www.avionews.com/en/item/1247929-20th-ch-47f-helicopter-delivered-to-the-royal-netherlands-air-force.html
- **Mi-26:** https://en.wikipedia.org/wiki/Mil_Mi-26
- **Z-8 and Z-20:**
  - https://aviationweek.com/defense/aircraft-propulsion/china-publicly-debuts-z-8l-heavy-lift-helicopter
  - https://www.nbcnews.com/news/world/china-military-displays-upgraded-z-20-helicopter-zhuhai-air-show-rcna179728
  - https://marineforum.online/en/chinas-new-helicopters-for-on-board-use/
- **MH-60R:**
  - https://janes.com/defence-news/spain-approved-for-mh-60r-purchase
  - https://www.janes.com/osint-insights/defence-news/defence/south-koreas-navy-begins-operational-deployment-of-mh-60r-seahawks
  - https://shephardmedia.com/news/air-warfare/norway-joins-the-mh-60-seahawk-fraternity
- **NH90 NFH:** https://en.wikipedia.org/wiki/Operators_of_the_NHIndustries_NH-90
- **Ka-27 and Ka-28:** https://en.wikipedia.com/wiki/Ka-27
- **Wildcat:** https://en.wikipedia.org/wiki/AgustaWestland_AW159_Wildcat

## Judgement calls

- **Capacities are abstracted.** One game soldier is a fire team, and one place is one game infantry unit. Sling loads count as carried.
- **Rivals do not mount air assaults yet.** They train these helicopters and fight with them.
- **Naval helicopters fly from helipads.** Basing them on frigates and carriers is a later step.
