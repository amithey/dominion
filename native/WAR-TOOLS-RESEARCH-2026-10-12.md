# The tools of war beyond the fighting units (2026-10-12)

**The question (player):** add more units, means and tools; research them and add more instruments of war.

**What the game had:** about 80 units. Codex's arsenal-diversity pass had just added recoilless teams, wheeled howitzers and short-range air defence.

**What was missing:** whole classes of military tools that modern wars turn on, but that are not "a gun on a hull":
- engineers and mines;
- recovery and repair;
- deception;
- the sensors that find targets for others;
- the shore against the sea;
- the aircraft that see, jam and hunt for the rest;
- the carrier, and the escort that hunts submarines.

Eleven roles were added (`scripts/force_catalog.gd` ROLES, logic in `scripts/war_tools.gd`), each with its own model and a national name only where the system is documented. All figures are game balance. The game's text names no years or events.

## The roles, what they do in the game, and the evidence

| Role | In the game | Who (names shown in the game) | Evidence and limits |
|---|---|---|---|
| **Engineer minelayer** | Halted for six seconds, it lays an anti-vehicle minefield: up to twelve a nation, four strikes each. Enemy vehicles that enter are struck, and infantry is not. The enemy cannot see the field. | Every army. Russia ISDM Zemledelie; Ukraine GMZ-3; USA M139 Volcano; EU Skorpion. | Zemledelie: a rocket-scattered mining system on a KamAZ, which maps its own fields; destroyed by Ukrainian drones on the Zaporizhzhia front (2025). Minefields shaped the 2023 counteroffensive. Anti-**vehicle** only: anti-personnel mines are banned for Ottawa Convention parties. |
| **Mine-clearing vehicle** | A line charge clears enemy fields within 22 m in three seconds and reveals them. Also a crude weapon against infantry and buildings. | Every army. Russia and Ukraine UR-77 Meteorit; USA M1150 Assault Breacher; UK Trojan AVRE; EU Keiler. | UR-77: a rocket-towed line charge that clears a lane about 6 × 90 m. Both sides used it for clearing, and also as an urban weapon (TWZ). |
| **Armoured recovery vehicle** | Repairs the most damaged friendly vehicle within 18 m, 16 health a second. | Every army. USA M88A2; Russia and Ukraine BREM-1; EU Bergepanzer 3; UK Challenger ARRV; India WZT-3; South Korea K1 ARV; Japan Type 90 ARV. | Well-documented service types. Battlefield recovery and repair returns damaged armour to the fight. |
| **Decoys** | Cost 90, no weapon, 160 health. Each looks exactly like the nation's tank: it draws fire and loitering munitions. | Russia (inflatable); Ukraine (inflatable and wooden). | Rusbal makes inflatable T-80, MiG-31 and S-300 copies for Russia's defence ministry, and Russia has a deception regiment. Ukraine fields Czech Inflatech decoys (a HIMARS copy among them) and wooden HIMARS and Leopard 2 copies that baited Lancets. The supplier's "30–40% of claimed HIMARS kills were decoys" is unverified, and not used. |
| **Counter-battery radar** | Enemy guns and rocket launchers within 110 m are revealed (fog), and your fire on them hits +25%. Unarmed. Infantry is not detected. | USA AN/TPQ-53; Russia Zoopark-1M; Ukraine COBRA / AN/TPQ-37; EU COBRA (Hensoldt); India Swathi WLR; Pakistan and China SLC-2. | TPQ-53 replaces TPQ-36/37 in the US Army. Russia relies on the Zoopark-1M (several lost in Ukraine). Ukraine received TPQ-37 and COBRA. Pakistan's SLC-2 is Chinese-made, and India's Swathi was built by DRDO/BEL. |
| **Coastal anti-ship battery** | Strikes only ships, at a range of 80. | Russia K-300P Bastion-P; Ukraine RK-360MC Neptune; Japan Type 12 SSM; USA NMESIS; EU NSM Coastal Defence System; China YJ-62 coastal battery; Iran Ghader coastal battery. | Bastion in the Kurils and Crimea (CSIS). NSM CDS with Poland, Romania and the US. Type 12 upgraded and deployed (Janes). NMESIS deployed to the Luzon Strait (exercises). Neptune is Ukraine's. The YJ-62 and Ghader coastal deployments are widely reported but were not independently confirmed in this pass. |
| **Airborne early warning aircraft** | While airborne, reveals enemy aircraft and ships within 150 m, and your aircraft near it hit +10%. On the ground at its airfield it gives nothing. Unarmed. | USA E-3G; China KJ-500; Russia A-50U; India Netra; Japan E-767; UK E-7 Wedgetail; Australia E-7A; Türkiye E-7T; South Korea E-7 Peace Eye; Saudi Arabia E-3A; Pakistan Saab 2000 Erieye; EU (France) E-3F; Israel G550 Eitam; Brazil E-99; Egypt E-2C. | Wedgetail: Australia 6, Türkiye (Peace Eagle), Korea (Peace Eye), UK (first delivered to Lossiemouth). Japan: E-2C and E-767. The US E-7 programme was cancelled, then funded again, so the game keeps the E-3. |
| **Electronic attack aircraft** | Enemy air defences within 60 m of it lose 40% of their effect. Light anti-radiation missiles. | USA and Australia EA-18G Growler; China J-16D; EU (Germany) Tornado ECR. | RAAF: twelve Growlers in No. 6 Squadron. J-16D: China's electronic-warfare variant. The Tornado ECR's replacement is undecided. |
| **Maritime patrol aircraft** | Reveals enemy submarines within 90 m and strikes them ×1.8, as well as surface ships. It cannot engage targets on land. | USA, Australia and South Korea P-8A; UK Poseidon MRA1; India P-8I; Japan Kawasaki P-1; China Y-8Q; Russia Il-38N; EU (France) Atlantique 2; Türkiye P-72; Pakistan P-3C; Brazil P-3AM; Indonesia CN-235 MPA. | P-8 ordered by the US, India, UK, Australia, Norway, New Zealand, South Korea and Germany. Japan: the P-1. The Russian and Chinese types come from standard references. |
| **Aircraft carrier** | 2,400 health. Its air wing strikes at a range of 75 against ships, armour, aircraft and towns. It cannot hunt submarines. Costs 4,200 and 90 seconds to build. | USA Gerald R. Ford-class; China Fujian; UK Queen Elizabeth-class; India INS Vikrant; EU Charles de Gaulle; Japan Kaga (F-35B); Türkiye TCG Anadolu (drone carrier); Iran Shahid Bagheri (drone carrier). | Fujian commissioned November 2025 (EMALS, J-35, KJ-600). Japan's Kaga is converted for F-35B (US Marine trials, June 2026). Iran's Shahid Bagheri is a converted drone carrier (February 2025). **Russia is excluded:** the Admiral Kuznetsov has been in refit for years, with no confirmed return. |
| **Anti-submarine frigate** | ×1.8 against submarines, and anti-ship and air-defence fire. | China Type 054A; EU FREMM; UK Type 23; Russia Admiral Gorshkov; India Talwar; Japan Mogami; Türkiye Istanbul; South Korea Daegu; Egypt FREMM (Tahya Misr); Pakistan Tughril; Indonesia Martadinata; Australia Anzac; Brazil Niterói; Saudi Arabia Al Riyadh; Iran Moudge. | All are well-documented classes in service. **The USA is excluded:** its Constellation-class frigate is not delivered, and its anti-submarine escort is the destroyer it already has. |

## How it fits the game

- **Production.**
  - Ground tools come from the tank factory; decoys come from the barracks.
  - Aircraft come from the airfield, where they use its parking and sorties.
  - Ships come from the shipyard.
  - Research gates:
    - minelayer and recovery vehicle: Advanced Logistics;
    - clearer: Composite Armour;
    - radar, AEW and EW aircraft: Electronic Warfare;
    - coastal battery and frigate: Guided Munitions;
    - patrol aircraft: Jet Propulsion;
    - carrier: Naval Engineering.
- **Rivals** train them like any other role. A rival's halted engineer lays fields too.
- **Fog of war.** The radar, the AEW aircraft and the patrol aircraft reveal only what their sensor finds (`war_tools.sensed`): guns, air and sea contacts, and submarines respectively.
- **Saves** keep the minefields.

## Sources

- **Mines and clearing:**
  - https://euromaidanpress.com/2026/07/16/ukraines-412th-nemesis-brigade-destroyed-rare-russian-zemledeliye-system-with-fpv-drones/
  - https://english.nv.ua/nation/ukraine-destroys-russian-zemledeliye-mining-system-video-50528805.html
  - https://en.wikipedia.org/wiki/UR-77_Meteorit
  - https://www.twz.com/mine-clearing-system-seen-being-used-as-devastating-urban-artillery-in-ukraine
- **Decoys:**
  - https://theins.press/en/politics/260755
  - https://euromaidanpress.com/2025/03/04/forbes-ukraines-decoy-tanks-trick-russian-forces-next-active-dummies-will-spy-on-them/
  - https://san.com/cc/ukraine-is-using-inflatable-tanks-and-himars-against-russia/
  - https://en.wikipedia.org/wiki/Military_dummy
- **Counter-battery radar:**
  - https://en.wikipedia.com/wiki/AN/TPQ-53
  - https://en.wikipedia.com/wiki/Zoopark-1
  - https://www.newsweek.com/russia-will-struggle-replace-zoopark-radars-obliterated-strikes-uk-1791942
  - https://idrw.org/pakistans-chinese-slc-2-radar-vs-indias-swathi-wlr-a-counter-battery-radar-arms-race-on-the-subcontinent/
- **Coastal anti-ship:**
  - https://missilethreat.csis.org/?p=5785
  - https://www.edrmagazine.eu/denmark-acquires-coastal-defence-system-from-kongsberg
  - https://www.janes.com/osint-insights/defence-news/defence/japan-accelerates-type-12-deployment
  - https://www.navalnews.com/page/3/?s=NMESIS
- **AEW&C:**
  - https://en.wikipedia.org/wiki/Boeing_E-7_Wedgetail
  - https://thedefensepost.com/2026/05/26/uk-e7-wedgetail-aircraft-delivery/amp/
  - https://www.airandspaceforces.com/pacaf-australian-e-7s-japanese-e-2s-battle-management/
- **Electronic attack:**
  - https://www.airforce.gov.au/aircraft/ea-18g-growler
  - https://www.globalsecurity.org/military/world/china/j-16d.htm
  - https://www.janes.com/defence-intelligence-insights/defence-news/revised-rfi-anticipated-for-german-tornado-replacement-to-accommodate-electronic-attack-mission
- **Maritime patrol:**
  - https://www.australiandefence.com.au/defence/sea/indo-pacific-poseidon-fleet-expands
  - https://quwa.org/2023/04/03/new-mpa-solutions-look-to-take-on-boeing-p-8a-poseidon-2
- **Carriers:**
  - https://en.wikipedia.org/wiki/List_of_aircraft_carriers_in_service
  - https://www.wionews.com/world/japan-unveils-partially-upgraded-aircraft-carrier-js-kaga-it-will-be-base-for-f-35bs-709782/amp

## Judgement calls (open to revision)

- **Universal roles.** Every army has engineers and recovery vehicles. National names appear only where the system is documented; the rest show the generic role.
- **Decoys** are limited to Russia and Ukraine, the two armies documented using them at scale. Others surely use camouflage and dummies, and could be added with evidence.
- **The carrier is abstracted.** Its air wing is one long-range strike, and the carrier is not a floating airfield for the player's own aircraft.
- **Not modelled:**
  - anti-personnel mines;
  - naval mines and minesweepers;
  - aerial refuelling;
  - airborne and amphibious landings.

  These are candidates for a later pass.

## Carriers rebuilt, their air wings, and rival navies (0.9.95)

**The question (player):** improve the aircraft carriers. They should hold aircraft that take off to strike, and they should look like carriers. Rivals should build fleets too.

**What carriers look like** (official imagery and standard references):

| Class | In the game | Main features drawn |
|---|---|---|
| Gerald R. Ford (USA), Fujian (China), Charles de Gaulle (France) | `super` | A catapult (CATOBAR) deck: an **angled landing deck** to port with arrestor wires, **two bow catapults**, the island to starboard (Ford's set well aft), deck-edge lifts, a dark non-skid deck with white lines. The Fujian has electromagnetic catapults (EMALS), commissioned November 2025. |
| Queen Elizabeth (UK) | `twin` | A STOVL carrier with a **ski-jump bow** and **two islands**: navigation forward, flying control aft. |
| Vikrant (India), Anadolu (Türkiye) | `ski` | A ski-jump bow and one island. The Anadolu is an amphibious assault ship with a **stern dock**, operating drones (TB3). |
| Kaga (Japan) | `flat` | A straight flat deck (a converted helicopter destroyer) for F-35B. |
| Shahid Bagheri (Iran) | `box` | A **converted container ship**: the bridge and funnel block aft, and a flight deck with a ramp forward (February 2025). |

**The air wing.** A carrier holds its aircraft on deck. They are drawn there, and disappear as they take off.
- When an enemy is visible within reach (125), they launch one every three seconds, strike, and fly back.
- They land aboard with no wreck, and are rearmed below deck for 14 seconds.
- The ship's own guns only defend it.
- Wing sizes are game balance, by class:
  - five aircraft for the big catapult carriers;
  - four for the STOVL and drone carriers;
  - three for Iran's conversion.
- Aircraft by nation:
  - F/A-18E Super Hornet (USA);
  - J-15T (China);
  - Rafale M (France);
  - F-35B (UK, Japan);
  - MiG-29K (India);
  - Bayraktar TB3 (Türkiye);
  - a Shahed-129-class combat drone (Iran).

**Rival navies.** Rivals used to pick a unit at random, so warships were rare. Now a rival with a shipyard keeps a fleet proportional to its real navy (`war_tools.NAVY`):
- blue-water navies (USA, China) ≈ 12 ships;
- the UK, EU and Japan ≈ 9;
- Russia, India and South Korea ≈ 8;
- coastal forces 3–4.

While it is short of that fleet, it chooses warships first, and capital ships half of the time.
