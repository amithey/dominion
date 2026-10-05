# Unconventional weapons and the United Nations: a deeper pass (0.9.69)

The player asked for three things:
- check again which nations really have which unconventional weapon (some of 0.9.68's choices were wrong);
- add the missing weapon types;
- research how the UN actually works and build it into the game, so that it does not depend on the
  nations in the game today, because more will be added.

This document replaces WMD-RESEARCH-2026-10-05.md where the two differ. Code:
- scripts/cbrn_data.gd and scripts/wmd.gd: who has what, and the weapons;
- scripts/un_data.gd and scripts/un.gd: the UN's facts, and the UN itself.

## 1. Who really has what (cbrn_data.gd)

### Corrections to 0.9.68

| Weapon | 0.9.68 | Now | Why |
|---|---|---|---|
| Thermonuclear | US, Russia, China, UK, France | + **North Korea** | Its 3 September 2017 test (~250 kt) is judged likely thermonuclear. India's 1998 claim is disputed (12–25 kt measured against the 43 kt claimed), and Israel's is unproven, so both are left out. |
| Nerve agents | Russia, North Korea, **Iran** | Russia, North Korea, **Egypt, Israel** | Only Egypt, North Korea and South Sudan never joined the CWC, and Israel signed but never ratified it. The Arms Control Association: all four non-parties are suspected of holding chemical weapons. Iran's assessed violation (US, 2024) is **pharmaceutical-based agents**, a different weapon (below). Russia: Novichok (Skripal 2018, Navalny 2020) and an undeclared programme. |
| High-altitude EMP | US, China, Russia, North Korea | **all nine** nuclear-armed states | Any of them can burst a warhead at altitude. Doctrine (Russia, China, North Korea) is a matter of intent, not ability. |
| Dirty bomb | nuclear powers + Iran (a fixed list) | **any nation with a Nuclear Reactor** (a rule) | It needs radioactive material, not a weapons programme. |
| Biological | Russia, North Korea | unchanged | The US compliance reports assess offensive programmes only there. For China and Iran they raise "concerns", so they are not included. |
| Syria | — | **no** chemical weapons | Its post-Assad government is destroying the remnants with the OPCW: the first 42 aerial bombs in 2026, and an undeclared cache found the same year. |

Tactical nuclear weapons: all nine nuclear-armed states field weapons for battlefield or "pre-strategic" use:
- the US B61 (about 200, half in Europe) and the W76-2;
- Russia, about 2,000 non-strategic warheads;
- Pakistan's Nasr;
- North Korea's Hwasan-31;
- France's ASMPA;
- the UK's low-yield Trident.

Arsenals (SIPRI 2025): Russia 5,459, US 5,177, China 600, France 290, UK 225, India 180, Pakistan 170, Israel 90,
North Korea 50.

### The weapon types added

| Weapon | Who | Evidence | In the game |
|---|---|---|---|
| **MIRV missile** | US, Russia, China, UK, France; tested by India and Pakistan | US Trident II; Russia Yars, Bulava, Sarmat; China DF-41 and DF-5B; France M51. India's Agni-V "Divyastra" flew in March 2024 and May 2026, Pakistan's Ababeel in 2017 and 2023. North Korea's is aspirational. | Three ~100 kt warheads fall around the target; one incident is recorded. |
| **Nuclear glide vehicle** | Russia, China | Avangard (in service since 2019); China's orbital glide vehicle (August 2021, a fractional orbital bombardment system) | Missile defence stops 10% at most. |
| **Burevestnik** | Russia | Nuclear-powered cruise missile: a 14,000 km, 15-hour test claimed on 21 October 2025 | It leaves three patches of radiation along its path. |
| **Poseidon** | Russia | Nuclear-powered torpedo: its first powered test claimed on 28 October 2025 | Fired only from a nuclear submarine, only at a coast. The biggest fallout in the game; nothing can intercept it. |
| **Nuclear detonation in orbit** | Russia | US intelligence (February 2024) on a nuclear anti-satellite weapon; Cosmos 2553 (2022) tested its components and was tumbling by 2024 | 70% of all satellites are lost (everyone's) and debris +40. Counts as nuclear use and as a breach of the Outer Space Treaty. |
| **Chlorine** | anyone | A toxic industrial chemical. The OPCW attributed Syrian government chlorine attacks in 2014–2018. | A weaker, shorter cloud. |
| **Riot agents** | Russia | CS, CN and chloropicrin dropped on trenches in Ukraine: more than 13,300 recorded uses by 2026. Legal for police; banned as a method of warfare. | Few deaths, but no bunker shelters the troops. |
| **Incapacitants** | Iran, Russia | Iran's pharmaceutical-based agents (a CWC violation in the US assessment, 2024); Russia's Kolokol-1 (130 hostages died in Moscow, 2002) | Infantry falls unconscious, and some die. |
| **Anthrax** | Russia, North Korea | The Soviet Biopreparat programme; the Sverdlovsk leak of 1979 (about 66 dead) | Spores hold the ground for 8 minutes; not contagious. |
| **Reactor strike** | (anyone who destroys one) | Chernobyl's zone still covers 2,600 km². Attacks on nuclear plants are prohibited by Additional Protocol I, Art. 56; Zaporizhzhia has been on the front line since 2022. | 48 m of fallout for 10 minutes; the attacker is recorded. |
| **Nuclear breakout** | Iran (Saudi Arabia after Iran) | Iran had over 400 kg enriched to 60% before the June 2025 strikes. Saudi leaders said they would match an Iranian bomb. | A discovery: the bomb at once. The IAEA reports it to the Security Council. |

**Attribution:** a chemical or biological attack is blamed only after an investigation. In reality this is
the OPCW's fact-finding and attribution teams, or the Secretary-General's Mechanism for biological weapons.
In the game it takes 60 s.

**AI use:**
- Russia uses riot agents at the front.
- Nerve agents are used at the front by their non-democratic holders, more readily when the state is
  fighting for survival.
- Iran uses incapacitants.
- Anthrax and engineered disease are used only when fighting for survival.
- Chlorine is improvised only by a non-democracy that is desperate and has nothing else.
- A threshold state at war may break out.

### Nations added later

Every table is keyed by faction id. A new nation can be covered in three ways:
- by an entry in cbrn_data.gd;
- by fields on its nation data: `"cbrn": [...]`, `"npt"`, `"cwc"`, `"bwc"`, `"icc"`, `"un_region"`, `"nam"`,
  `"un"`;
- by the rules (chlorine for anyone, a dirty bomb with a reactor, nuclear weapons after a breakout).

Without any of these, it is an NPT, CWC and BWC party with no unconventional weapons, and a UN member of the
Asia-Pacific group.

## 2. How the UN works, and how the game does it (un_data.gd, un.gd)

| Rule (real) | In the game |
|---|---|
| 15 Council members: 5 permanent (US, Russia, China, UK, France) with a veto, and 10 elected for two years, 5 each year, by two-thirds of the General Assembly. Seats by region (GA resolution 1991 A (XVIII), 1963): Africa 3, Asia-Pacific 2, Latin America & Caribbean 2, Western Europe & Others 2, Eastern Europe 1. No immediate re-election. In 2026 the elected members include Bahrain, Colombia, the DR Congo, Latvia and Liberia. | The permanent members present, plus elected seats (half the other nations, at most 10) filled region by region in the same proportions. Terms last 10 minutes, half renewed every 5 minutes; those leaving cannot stand at once. You can **campaign** for a seat. |
| The presidency rotates monthly in English alphabetical order. | Every minute; the president's drafts are taken first. |
| Substantive decisions need 9 votes and no permanent member's "no". Abstention is not a veto (practice since 1946). Under Chapter VI a party to a dispute must abstain (Art. 27(3)). | Three-fifths and no veto; parties abstain on statements, ceasefires and peacekeeping. In a small Council the parties are left out of the count, an adaptation without which a ceasefire between two of four members could never pass. |
| Presidential statements need consensus. | One objection sinks one. |
| Drafts are negotiated in consultations, and the penholder weakens a text to avoid a veto, or forces a vote to expose it. | 15 s of consultations with a live whip count. An AI sponsor picks the strongest measure that would pass; if none would, it forces the vote. You can amend your own draft, and you can **lobby** a member with aid to move its vote one step. A member shielding the target cannot be moved. |
| Chapter VII: Art. 39 (threat to peace), Art. 41 (sanctions: asset freezes, travel bans, arms embargoes, comprehensive sanctions such as Res. 661 on Iraq), Art. 42 (force: Res. 678, 1973). Also ICC referrals (Res. 1593, 1970) and peacekeeping (about 50,000 personnel in 9 missions, cut by a quarter in 2025–26). | Measures: presidential statement, condemnation, ceasefire, demand to withdraw, ceasefire with peacekeepers, targeted sanctions (income -10%), arms embargo (military production -40%), comprehensive sanctions (income -30%, world market shut), ICC referral, authorisation of force (members may join without aggression), non-proliferation sanctions, lifting. |
| Vetoes: 8 in 2024 (the most since 1986), 4 in 2025 (2 by the US on Gaza, 2 by Russia on Ukraine). Russia vetoed resolutions on Syria's chemical attacks, and in 2024 it ended the North Korea panel of experts. | A permanent member shields its clients from everything: the US shields Israel; Russia shields Iran and North Korea; China shields North Korea, Pakistan, Russia and Iran. Allies and puppets are shielded too. Russia and China put sovereignty first. Non-aligned members shy away from coercing one another. |
| Veto initiative (Res. 76/262, 2022): the General Assembly meets within 10 working days of any veto. Uniting for Peace (Res. 377 A, 1950): the Assembly may recommend collective measures, as in ES-11 on Ukraine (141-5-35 in March 2022). | Every veto goes to the Assembly. Two-thirds condemn: yes-voters' relations -8, the target's war support -6, and the vetoing member -4 with the yes-voters. On a threat to peace, the yes-voters cut their trade with the target: income -1.5% for each, at most -25%. |
| Art. 19: a member whose arrears equal two years of dues loses its General Assembly vote. The US owed about $1.5 billion in January 2026 and then paid $725 million. | Dues are assessed every 4 minutes by your income. You may withhold them; with two periods unpaid you lose your Assembly vote until you pay. |
| Art. 99: the Secretary-General may bring any threat to the Council. 2026 is a selection year, run by straw polls ("encourage / discourage / no opinion"; a permanent member's discourage acts as a veto) among eight candidates, in what is informally Latin America's turn. | The Secretary-General (from Latin America) brings any war of 5 minutes to the Council. |
| Sanctions in force in 2026: Iran (2231 snapback, restored 27 September 2025); North Korea (1718 and successors); the Taliban (1988). Syria's president was delisted by Res. 2799 (November 2025, 14-0-1, China abstaining). | These regimes are in force from the first minute, so playing Iran starts under an arms embargo and targeted sanctions. A **lift** resolution can end them. |

**What goes before the Council:**
- every use of a weapon of mass destruction, once attributed;
- an attack on a reactor;
- a breakout;
- a nuclear detonation in orbit;
- a war of aggression involving you (collective self-defence and authorised coalitions excepted);
- a defied demand;
- a broken peacekeeping ceasefire;
- a long war (Art. 99);
- your own drafts, which need a seat on the Council and, for sanctions, a cause on record.

## 3. A closer look at the United States, and a second check of everyone (0.9.70)

The player said the US list did not look right, and it wasn't. Two rules from 0.9.69 had given the US (and every
other state) chlorine bombs ("anyone can improvise it") and a dirty bomb ("any nation with a reactor"). The US
destroyed its last chemical weapon, an M55 sarin rocket at Blue Grass, Kentucky, on 7 July 2023. No state has
ever used a dirty bomb. Meanwhile real US weapons were missing.

### The US arsenal, as it is (FAS Nuclear Notebook 2025, CRS, NNSA)

- **Totals:** about 3,700 warheads in the stockpile, about 1,700 of them deployed; 5,177 including those awaiting
  dismantlement.
- **ICBMs:** Minuteman III, now with a single warhead each (W87, 300 kt, or W78, 335 kt) since 2014. The Sentinel
  replacement is over budget.
- **SLBMs:** Trident II D5 on Ohio-class submarines, MIRVed with the W76-1 (90 kt) and the W88 (475 kt). Columbia
  class under construction.
- **Low yield:** the W76-2 (about 8 kt) on Trident since 2019.
- **Bombs:** the B61-12 (variable yield, 0.3-50 kt; about 100 in Europe under NATO sharing); the B61-13 (higher
  yield, first unit May 2025, a year early); the B61-11 earth penetrator (~400 kt), which was not retired; the
  B83-1 (1.2 Mt), which is being retired.
- **Cruise missiles:** the AGM-86B ALCM with the W80-1 on the B-52, to be replaced by the AGM-181 LRSO with the
  W80-4. The SLCM-N, a nuclear sea-launched cruise missile, was made a program of record by Congress and is to
  be operational by 2034.
- **New programmes:** a nuclear bunker-buster prototype funded by Congress (2026); the W93 for Trident; the B-21
  bomber.
- **Not held:** no chemical weapons (destroyed in 2023; tear gas is allowed in war only in defensive modes, under
  Executive Order 11850 of 1975); no biological weapons; no neutron weapon (retired in 1992); no nuclear glide
  vehicle (US hypersonic missiles, Dark Eagle and CPS, are conventional); nothing like Poseidon or Burevestnik.
- **Conventional but controversial:** depleted-uranium rounds (M829 tank rounds and A-10 ammunition; sent to
  Ukraine in 2023); cluster munitions (sent to Ukraine in 2023; the US is not a party to the 2008 convention);
  white phosphorus for smoke.

### What changed in the game

- **US weapons now:** tactical (W76-2 / B61-12), strategic, thermonuclear (B83, retiring; B61-13), MIRV (Trident
  II), high-altitude EMP, the HPM microwave missile, the **Nuclear Bunker Buster** (new: B61-11/-13) and the
  **Nuclear Cruise Missile** (new: AGM-86B, then LRSO). The neutron warhead is shown as a research programme to
  build one again, not a weapon in service anywhere.
- **Chlorine:** now only for a state already outside or in breach of the chemical weapons ban (Egypt, North Korea,
  Israel's unratified signature, or any state with chemical, riot or incapacitating agents). Never the US, the UK,
  France, China, India or Japan.
- **Dirty bomb:** only North Korea and Iran (with a reactor), or a state that has broken out of the NPT. Nuclear
  powers have no use for one.
- **Nuclear Cruise Missile:** the US (AGM-86B), Russia (Kh-102), France (ASMPA-R), Pakistan (Ra'ad, Babur) and
  Israel (believed carried by its Dolphin submarines).
- **Nuclear torpedo:** North Korea's Haeil "tsunami" drone (tests claimed 2023-2024, readiness doubted) joins
  Russia's Poseidon. It can be fired from a nuclear submarine or a coastal silo.
- **NATO nuclear sharing:** US B61s are hosted at Kleine Brogel, Büchel, Aviano, Ghedi, Volkel and Incirlik, and
  again in the UK since 2025, when the UK announced 12 F-35As for the NATO mission. In the game **Turkey** may use
  the tactical bomb only while allied with the United States.

### The second check of everyone

- **Russia:** about 5,459 warheads and some 1,000-2,000 non-strategic ones. Iskander, the nuclear-capable
  Kinzhal, Kh-102, Avangard, Sarmat (at least two failed tests and a silo crater at Plesetsk in September 2024),
  Oreshnik (an intermediate-range MIRV missile fired conventionally at Dnipro in November 2024 and deployed in
  Belarus in December 2025), Burevestnik and Poseidon. Nuclear warheads in Belarus. Unchanged.
- **China:** about 600 warheads. DF-41 with up to three warheads, DF-26 dual-capable (about 500 missiles), JL-3 on
  six Type 094 submarines, the H-6N with an air-launched ballistic missile, an orbital glide vehicle (2021). No
  publicly confirmed nuclear cruise missile, so none is given.
- **UK:** about 225 warheads. Trident (MIRV), the sub-strategic low-yield option, the F-35A nuclear role from 2025.
  Unchanged.
- **France:** about 290 warheads. M51 (MIRV), ASMPA-R (nuclear cruise, now in the game). Unchanged otherwise.
- **India:** about 180 warheads. Agni-V MIRV tests (2024, 2026), K-4 from INS Arighaat (2025). Thermonuclear
  claim still disputed.
- **Pakistan:** about 170 warheads. Nasr (tactical), Ra'ad and Babur (now nuclear cruise missiles), Ababeel
  (MIRV, tested).
- **Israel:** about 90 warheads. Jericho III, Dolphin submarines (nuclear cruise, believed), about 50 aircraft with
  a possible nuclear role. Thermonuclear unproven.
- **North Korea:** about 50 warheads (some estimates 150). Hwasong-19 (October 2024), the Hwasan-31 tactical
  warhead (4-10 kt), the Haeil torpedo; a seventh test possible at any time (DIA 2025).
- **Turkey:** hosts US B61s at Incirlik (NATO sharing).
- **Not modelled (conventional, if controversial):** depleted uranium, cluster munitions (Lithuania became the
  first state to leave the convention, in March 2025), white phosphorus.
