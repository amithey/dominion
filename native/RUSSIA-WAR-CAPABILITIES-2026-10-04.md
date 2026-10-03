# Russia's war capabilities, the sixth-generation battle group, and the Maduro raid: research, 2026-10-04

## 1. Russia: what the war in Ukraine showed (in the game from 0.9.57)

| Capability | The record | In the game |
|---|---|---|
| Foreign recruitment | North Korea sent more than 10,000 troops to Kursk (about 11,000 there at the start of 2026; some 4,700 killed by South Korea's count) and confirmed it in April 2025. Russia recruits contract soldiers from Nepal (at least 603), Cuba, Sri Lanka, Cameroon, Yemen and dozens more countries, often by deception: over 1,500 foreigners from 48 countries identified by name. | Russia-only discovery, era 2, needs barracks: while at war, 4 foreign soldiers join at the capital every 2.5 minutes, $60 each. A rival Russia raises them at era 2. |
| UMPK glide bombs | Wing-and-guidance kits on old FAB bombs: some 3,500 a month by early 2025, over 100 a day; 120,000 planned for 2025; dropped 40-70 km out (new versions 100-200 km), beyond most air defence, by Su-34s. | Russia-only discovery, era 3, after Guided Munitions, needs an airfield: every jet built afterwards is a Su-34 with glide bombs, +50% range and +20% damage (heavy bombers unchanged). |
| Fibre-optic FPV drones | Steered down a fibre-optic cable, no radio link to jam; Russia makes some 50,000 a month (Ukraine 20,000); the Rubikon centre's crews reach 20-30 km with spools of about 10 km. | Russia-only discovery, era 4, after Drone Swarms: FPV teams trained afterwards cannot be jammed (an enemy EW vehicle stopped 25 of 40 radio drones in the check, 0 of 40 fibre-optic ones) and reach 30% further. A microwave weapon still burns them. |
| Geran-2 | The Shahed-136, built in Russia at Alabuga as the Geran-2; some 70,000 long-range drones planned for 2025. | Russia fields the Shahed launcher as the "Geran-2 Launcher" (until now it was Iran's alone; Iran keeps it). |

Each unit keeps the system it was built as: a Su-35S in service before the glide-bomb research stays a Su-35S
(this also holds for the M1A2 SEPv3 when the M1E3 arrives).

Left out for now: the Oreshnik missile (one combat use, November 2024), the strikes on Ukraine's power grid
(the game already has Russia's Energy Leverage), and the costly mass assaults (a doctrine, not a technology).

## 2. The sixth-generation battle group (0.9.57)

The F-47 or J-36 takes off with two loyal wingmen (the Air Force's Collaborative Combat Aircraft). Each is still
a unit of its own (its own health, missiles and place on the map), but the three fly, defend and attack as one:
- **Formation**: on a straight leg each wingman holds a slot 12 m off the fighter's wing; it steers for a point
  40 m beyond its slot and matches the fighter's speed (faster when behind, slower when ahead), so it never turns
  back on an overshoot. In the check they close from 53 m and 27 m to 12 m and 12 m in nine seconds. Circling,
  they share the fighter's circle a little ahead and behind.
- **Attack**: the wingmen take the fighter's target.
- **Defence**: whatever shoots at one of the group is met by all of it: the wingmen first, the fighter too when
  it has nothing else to do.
- **Drawing fire**: an escorted fighter is the enemy's last choice of target; enemy fighters go for the wingmen.
- **Together**: a click on any of the three selects the group; the unit card says how many wingmen are with it.
  While the fighter is on the ground the wingmen circle over it, and a lost wingman is replaced while it rearms
  ($200, one every 20 s; a CCA costs about a tenth of the fighter).

## 3. The Maduro raid (Operation Absolute Resolve, 3 January 2026): should it be in the game?

What happened:
- A small CIA team was on the ground from August 2025 and learnt Maduro's pattern of life; the NSA, the National
  Geospatial-Intelligence Agency, Space Command and Cyber Command took part.
- Cyber Command and the NSA blacked out Caracas's power grid and blinded the Russian-built air defences and their
  command network; electronic warfare jammed the radios the commanders fell back on; more than 150 aircraft struck
  air defences across northern Venezuela.
- Delta Force (with an FBI unit) flew in low by helicopter, reached the compound about 1 a.m., came under fire,
  took Maduro and his wife from their bedroom and flew out at 3:29 a.m. No Americans were killed; a handful were
  wounded.

Recommendation: yes, as a rare United States strategic operation, not an "I win" button. A sketch:
- **Needs**: a deep CIA network in the target (the game's espionage network, 60+), a recent dossier, a special
  forces unit and an airfield; war, or relations below -50; very expensive; one use every 20 minutes or so.
- **Phases** (shown as they happen): the cyber blackout (the target's air defences and power down for a minute),
  the strike on its air defences, the helicopter raid.
- **Success** (chance from the network, the dossier and the target's counter-intelligence): the target's leader is
  captured: its government falls into a succession crisis (the espionage system already has succession), its
  income and research fall for some minutes, its army is briefly leaderless.
- **The cost of success**: every other nation's relations with the United States fall (international law), and
  the captured nation's people turn hostile.
- **Failure**: helicopters and special forces lost, a diplomatic scandal, and the target's guard raised for a long
  time.

The game has the parts already: the espionage network and dossiers, succession, the cyber attack, special forces
and helicopters.

## Sources

- North Korean troops: NPR, 28 April 2025; RFA, 28 April 2025; Yahoo/Yonhap, "Nearly 11,000 North Korean troops
  stationed in Russia's Kursk Oblast at start of 2026".
- Foreign recruits: CNN, 25 November 2025; FIDH, "Russia's exploitation of foreign fighters"; DIIS, "Russia's
  shadow fighters"; Yahoo, "over 1,500 foreign mercenaries from 48 countries".
- Glide bombs: Wikipedia, UMPK; European Security & Defence, July 2025; Militaer Aktuell; Long War Journal,
  October 2025; JAPCC.
- Fibre-optic drones and Rubikon: CNN, 22 November 2025; Lowy Institute; CSIS, "From Shahed to Geran".
- The CCA and the sixth-generation fighters: native/godot/scripts/future_weapons.gd (sources there).
- The Maduro raid: CNN, 3 January 2026 ("From order to extraction"); Air & Space Forces Magazine; Defense One;
  Wikipedia, 2026 United States intervention in Venezuela; SecurityWeek and RUSI on the cyber operation;
  Jerusalem Post on the CIA's role.
