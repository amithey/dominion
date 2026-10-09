# DOMINION desktop game

The chosen product target is an installed PC game, with Steam as a future goal.
The active game is in `native/godot`. The browser implementation in `js/` is a
reference for rules and exported data. Run `prepare-desktop.ps1` before changing
or testing the native game; copied art and the engine are local-only.

> Continuing development? Read [HANDOFF.md](HANDOFF.md) first: where the 0.9.4–0.9.5 code lives and the traps to avoid.

## In development: ten additional nations

The native source now offers 19 factions: the existing nine plus the United Kingdom,
South Korea, Saudi Arabia, Brazil, Indonesia, Ukraine, North Korea, Egypt, Australia
and Pakistan. Each addition has a researched leader identity, economic strengths and
weaknesses, an exclusive unit or worker specialty, and a national power with costs,
prerequisites and cooldown. Select them for yourself or as rivals in New Game; use
national powers from Diplomacy. Map capacity still limits each match to 2–10 nations.

The additions integrate with production, research, combat, trade, AI and saves.
Their cards and diplomatic meetings use illustrated leader portraits generated with
built-in ImageGen; national emblems remain as fallback. Unit art reuses existing procedural models.
Research sources and precise gameplay rules are in
[the research and integration report](FACTIONS-RESEARCH-2026-10-02.md).
The ten portraits are included in the subsequent 0.9.49 local release.

## Version 0.9.82: the third unhappy-customer round

A playthrough from the main menu as a critical customer, 100 checks (tools/customer-round3-100.gd). Report:
native/CUSTOMER-REVIEW-ROUND-3-2026-10-09.md.

- **Letters from abroad lapse** after 60 s of game time instead of covering the battlefield all game. A yes-or-no
  letter is refused; a letter with several answers is set aside. Your own decisions wait for you.
- **Declare war asks first**, naming the nation and its allies.
- **Quitting a campaign asks for a second click**, because unsaved progress is lost.
- **Music and interface sound:**
  - A quiet theme generated in code (tools/make-music.gd), and a soft click on every button.
  - Music and Interface clicks sliders.
- **Frame counter** off by default.
- **One British spelling** everywhere (Centre, Armour, Defence): scripts/house_style.gd.
- **Smaller damage tags** coloured by health.
- **Unit names on hover:** the unit, whose it is, and its health.
- **Idle workers button** beside the minimap.
- **The season in the era cartouche.**
- **Friendlier menus:** save times in words, saves that say whose campaign they hold, and an icon for Quit.
- **Rivals defend their capital:** when nothing at home can hurt the threat, they raise an anti-armour unit.
- **Selection panel:** army orders only for an army, "2 Soldiers", accuracy at most 100%, and speed in m/s.

## Version 0.9.76: automated early warning, and the race to general intelligence

- **Automated early warning** (Defence > AI > Doctrine; for a nuclear power at AI level 3):
  - An AI watches for launches and readies the answer. Rivals believe a launch on warning and are a third
    less likely to strike you first; interception +5%.
  - The machine sometimes reports an attack that is not there: your alert rises, and the world's nuclear
    tension with it, worse when a rival's system answers yours.
  - A nation bound by the declaration on human control of nuclear weapons (the United States at the start)
    must withdraw from it first.
  - Rival nuclear powers outside the declaration automate theirs in a crisis.
- **The AGI project** (research after Frontier Models, AI level 4; Defence > AI > AGI):
  - Three stages paid in compute: **automated research** (research +25%), **recursive
    self-improvement** (production +15% and a far stronger cyber defence), and **general intelligence**:
    AI level 5 and a **Technological Supremacy victory**.
  - **Safety:** compute given to alignment slows the project. With too little, the system can run out of
    control: the stage's work is halved, drones freeze, intrusions hit every nation, markets fall 10%, and an
    unrestricted model may help someone make a pathogen. The Security Council takes it up.
  - **Rivals race too**, and sabotage the leader; you can sabotage theirs (Operations page).
  - The race appears among the Cabinet's paths to victory.
- The AI tab has five pages: Compute, Doctrine, Operations, AGI and Rivals.

Checks: tools/ai3-check.gd (28), tools/ai2-check.gd (43), tools/ai-check.gd (53).

## Version 0.9.75: the AI economy, chips, deepfakes, model theft, loyal wingmen and AI treaties

- **The AI economy:**
  - Compute given to the Economy raises research, income and production.
  - It also automates jobs. Without a **retraining programme** (Compute page, paid by the second), the
    people put out of work are unhappy.
  - Rivals' AI economies raise their income too.
- **Chips:**
  - The chip-supply nations (the United States, the European Union, Japan, South Korea and the United
    Kingdom) can put **export controls** on a rival: its data centres run at half for 10 minutes.
  - **Smuggling** wins most of it back, but if found out the controls run longer. Rivals impose controls on
    you, and smuggle when you impose them.
  - A **global chip shortage** (a world event) comes when eight AI data centres buy up the world's chips, or
    when South Korea or Japan is at war: silicon dearer, and data centres at 80%.
- **AI analysis:** intelligence grows faster, satellite passes reveal more for longer, and attacks are
  foreseen.
- **Synthetic influence:** deepfake campaigns lower a rival's war support and stability. A campaign traced to
  you is a scandal. Rivals run them against you.
- **Model theft:** steal a stronger rival's model weights and close half the gap. If exposed, a chip-supply
  rival puts controls on you. Rivals steal yours.
- **Collaborative Combat Aircraft** (research): every fighter you train takes off with a loyal wingman. A lost
  wingman costs no lives and is replaced while the fighter rearms.
- **AI air-defence battle management:** batteries share targets (no two missiles at one aircraft) and
  intercept more often; rivals' batteries too.
- **AI treaties:**
  - The **Treaty on Autonomous Weapons**, whose signatories keep a human in or on the loop.
  - The **Declaration on Human Control of Nuclear Weapons**.
  - Each nation starts with its real stance; you may sign or withdraw. Fighting with no human in the loop
    costs standing with the treaty's signatories.
  - A rival that signed breaks the treaty only when fighting for its survival, and the Security Council
    takes it up.
- The AI tab now has four small pages: Compute, Doctrine, Operations and Rivals.

Checks: tools/ai2-check.gd (43), tools/ai-check.gd (53).

## Version 0.9.74: artificial intelligence, and Codex's researched arsenals and UN

- **AI as a national resource** (Defence window, new **AI** tab; native/AI-RESEARCH-2026-10-06.md):
  - **Compute** comes from your industry once you research **Machine Learning**, and from the new
    **AI Data Center**. A data centre burns silicon and money, runs better beside a power plant or reactor,
    and is a target.
  - Split the compute four ways: **Military AI**, **Economy** (research and income), **Intelligence**
    (the operations reserve and cyber defence) and **Training runs**.
  - Training runs raise your **AI level** from 0 to 4, as far as research allows: Machine Learning, then
    **Military AI**, then **Frontier Models**.
  - Every nation has a real AI profile: compute, models, autonomy and cyber. The United States leads,
    China is close, Russia and Ukraine field autonomy beyond their compute, and Saudi Arabia buys compute.
- **Autonomy doctrine:**
  - **Human in the loop:** safe.
  - **On the loop:** drones a third harder to jam and stronger with each level.
  - **Out of the loop:** drones almost unjammable and every unit deadlier. In exchange, incidents: your own
    units struck, or civilians, which costs war support and goes to the Security Council.
  - At AI level 3, loitering munitions and interceptor drones pick their own targets: air defences first,
    then artillery, then armour.
- **Targeting Fusion Cell** (Military AI): artillery hits harder and closer, and guided weapons stray less.
- **AI cyber campaigns:**
  - They need no agent, only compute, and reach several hostile nations at once, stopping their production.
  - They can be traced back to you.
  - Rivals with AI run campaigns against your factories; your cyber defence stops some.
- **Rivals play by the same rules:** they build data centres and a fusion cell, train their AI with their
  technology, and choose a doctrine by their nation's lean (and out of the loop when fighting for survival).
- **Included from Codex:**
  - The researched national arsenals: arsenal_catalog.gd, native/ARSENAL-RESEARCH-2026-10-06.md.
  - The reworked UN: un_activity.gd, native/UN-RESEARCH-2026-10-05.md.
- A building that needs research now says so in the build list.

Checks: tools/ai-check.gd (53), tools/un-check.gd and tools/arsenal-check.gd (Codex).

## Version 0.9.73: rivals need their weapons facilities, and three new conventional missiles

- **Rivals need the facilities too** (wmd.armed):
  - Without a **Strategic Weapons Complex** a rival cannot use a nuclear weapon first, test one, or burst one
    in orbit. Without a **Special Weapons Laboratory** it cannot use chemical or biological weapons.
  - A nuclear rival builds a complex once its technology allows (a second one in a war), and a rival with
    such programmes builds a laboratory.
  - **Destroying the facility disarms it.** A nuclear submarine at sea still guarantees a second strike.
  - A destroyed complex scatters a little fissile material; a destroyed laboratory releases its agents.
  - Your own complex or laboratory destroyed takes the weapons it held with it.
  - A nuclear test now needs a complex: the device is assembled there.
- **Three new conventional missiles** at the silo (now ten), any nation:
  - **Bunker-Buster Missile:** buildings, bunkers and silos take three times the damage, and bunkers shelter no
    one.
  - **Thermobaric Missile:** a wide fuel-air blast that kills infantry, dug in or not.
  - **Anti-Radiation Missile:** homes on the nearest air-defence radar within 40 m of its aim; triple damage,
    and the radar falls silent for 30 s.
  - Rivals fire the bunker-buster at your strongholds and the anti-radiation missile at the SAM sites they
    know of.
Checks: tools/nuclear-tests-check.gd (37).

## Version 0.9.72: weapons of mass destruction get facilities of their own

- **Where each weapon is made:** the Missile Silo had more unconventional weapons in its list than
  conventional ones. Now:
  - the **Missile Silo** builds only conventional missiles;
  - a new **Strategic Weapons Complex** assembles nuclear warheads; only a nuclear-armed nation (or one
    hosting shared bombs) sees it;
  - a new **Special Weapons Laboratory** makes chemical, biological and radiological weapons; only a nation
    with such a programme sees it. The US, the UK, France, China and most others never do.
- **Storage:** each kind has its own. Two weapons per complex or laboratory, so warheads no longer take the
  conventional missiles' room in the Ammo Depots. A large nuclear arsenal now needs several complexes: a cost
  and a target.
- **Launching:** everything still launches from a silo or a missile ship. The silo's launch list shows every
  weapon you hold.
- Both buildings have models of their own (an assembly hall with earth-banked bays and a vent stack; a sealed
  laboratory with filtered vents).

Checks: tools/nuclear-tests-check.gd (27).

## Version 0.9.71: nuclear tests, a clear nuclear release, a smaller interface, and text without dates

- **Nuclear tests** (scripts/nuclear_tests.gd; the Defence window, Nuclear alert tab):
  - Underground or atmospheric, on your land or the wilderness beyond it.
  - For 15 minutes rivals believe your deterrent: those that merely dislike you will not start a war, and
    nuclear strikes on you are weighed twice.
  - Your scientists learn from it. The world condemns it and the Security Council takes it up.
  - An atmospheric test leaves drifting fallout. A state that has just broken out tests its bomb.
- **Nuclear release:** arming a nuclear weapon now asks for the order and states its price (your forces to
  DEFCON 2, relations), then arms it. It no longer sends you to another window. Your own alert reads as a
  DEFCON level.
- **Satellite jammers** (the US, Russia, China): silence a nation's satellites for 2 minutes, reversibly and
  without war.
- **The US loyal wingman** is now the FQ-42A Dark Merlin.
- **Interface size** (Settings, Graphics: Small / Medium / Large / Original): the panels had grown with large
  screens. Medium, the new default, is 20% smaller than before.
- **No dates or one-off events in the game's text:** weapon, unit and research descriptions, world events and
  UN records now say what things do and who has them. A check enforces it.
- Research: native/CBRN-UN-RESEARCH-2026-10-05.md, section 4.

Checks: tools/nuclear-tests-check.gd (18).

## Version 0.9.70: the US arsenal as it is

- **The US no longer gets chlorine bombs or a dirty bomb**, a mistake of 0.9.69's rules: it destroyed its last
  chemical weapon on 7 July 2023, and no state has ever used a dirty bomb.
  - Chlorine is now only for states already outside or in breach of the chemical weapons ban.
  - The dirty bomb is only for North Korea and Iran (with a reactor), or for a state that has broken out.
- **New US weapons, as fielded:**
  - **Nuclear Bunker Buster** (the B61-11 earth penetrator; the B61-13, first built in May 2025): a small
    surface circle, but buildings and bunkers in it take three times the damage, and a dirty ground-burst
    fallout.
  - **Nuclear Cruise Missile:** the AGM-86B (the LRSO to follow). It is also held by Russia (Kh-102), France
    (ASMPA-R), Pakistan (Ra'ad, Babur) and Israel (believed).
- **The neutron warhead** is described as what it is: no one fields one today, and researching it means
  building one again.
- **Nuclear torpedo:** North Korea's Haeil joins Russia's Poseidon; it can be fired from a nuclear submarine
  or a coastal silo.
- **NATO nuclear sharing:** Turkey may use the US B61s at Incirlik while allied with the United States.
- **Research** (the US arsenal 2025, and a second check of all nine nuclear states): native/CBRN-UN-RESEARCH-2026-10-05.md, section 3.

Checks: tools/wmd-un-check.gd (59).

## Version 0.9.69: who really has what, more unconventional weapons, and a real UN

- **Who has what, corrected** (scripts/cbrn_data.gd, one table for every nation, with rules for nations
  added later):
  - North Korea gains the thermonuclear missile (its 2017 test).
  - Nerve agents now belong to Russia, North Korea, Egypt and Israel (the states outside the CWC, plus
    Russia's undeclared programme), and no longer to Iran. Iran's weapon is now the incapacitating agent the
    US found in violation in 2024.
  - All nine nuclear powers can burst a high-altitude EMP.
  - A dirty bomb now needs only a Nuclear Reactor.
- **New weapons:**
  - MIRV missile (three warheads), nuclear glide vehicle (Russia, China; almost unstoppable), Burevestnik
    and Poseidon (Russia; Poseidon only from a nuclear submarine at a coast);
  - a nuclear detonation in orbit (Russia; most satellites lost, everyone's);
  - chlorine (anyone), riot agents (Russia; they drive troops out of bunkers), incapacitants (Iran,
    Russia), anthrax (Russia, North Korea);
  - destroying a Nuclear Reactor spreads its core over the land around it, and the attacker is blamed;
  - Nuclear Breakout lets Iran build the bomb (and Saudi Arabia after it), and the IAEA reports it.
- **Investigations:** chemical and biological attacks are attributed only after 60 s (OPCW, the UN
  Secretary-General's Mechanism).
- **The United Nations, rebuilt** (scripts/un_data.gd, scripts/un.gd; the UN window has five tabs):
  - **Seats and presidency:** permanent seats with vetoes, and elected seats by region (3:2:2:2:1) won in
    General Assembly elections; you can campaign for one. The presidency rotates.
  - **Drafts:** each is negotiated in consultations with a live whip count. Sponsors weaken drafts to
    escape vetoes, or force a vote to expose one. You can amend your own draft and lobby members with aid.
    A permanent member shields its clients.
  - **Measures:** presidential statements (consensus), condemnations, ceasefires (the parties abstain,
    Art. 27(3)), demands to withdraw, peacekeepers, targeted sanctions, arms embargoes (military production
    -40%), comprehensive sanctions (the world market shut), ICC referrals, and authorisation of force
    (joining the coalition is no aggression).
  - **The General Assembly:** it meets on every veto and condemns. Under Uniting for Peace its yes-voters
    cut trade.
  - **Dues:** withhold them and you lose your Assembly vote (Art. 19).
  - **The Secretary-General** brings long wars to the Council (Art. 99).
  - **Sanctions already in force in 2026** (Iran's snapback, North Korea, the Taliban) apply from the
    start.
- Research and sources: native/CBRN-UN-RESEARCH-2026-10-05.md.

Checks: tools/wmd-un-check.gd (56).

## Version 0.9.68: weapons of mass destruction, and the United Nations

- **The EMP missile, rethought** (scripts/wmd.gd): now the HPM Cruise Missile, as tested in the US
  (CHAMP 2012, HiJENKS 2022), for the United States, China and Russia only.
  - It kills no one.
  - Three microwave pulses along the end of its flight knock out vehicles, aircraft, ships and buildings
    for 45 s and bring drones down; your own units are spared.
- **High-Altitude Nuclear EMP** (US, China, Russia, North Korea):
  - no blast on the ground;
  - a wide blackout for 90 s, crippled aircraft, falling drones;
  - satellites knocked out of orbit (Starfish Prime, 1962).
- **Nuclear warheads by yield:**
  - Tactical (5-10 kt);
  - Nuclear (strategic);
  - Thermonuclear (about 1 Mt, the US B83; new discovery Thermonuclear Weapons);
  - Tsar Bomba (50 Mt, Russia only);
  - Neutron Warhead (enhanced radiation, US, Russia, China, France; new discovery Enhanced Radiation
    Weapons): it kills crews and infantry and spares buildings beyond its small blast.
- **Fallout:** every nuclear detonation leaves radioactive ground.
  - It drifts downwind and decays by the 7-10 rule.
  - Inside it infantry dies, crews sicken and buildings shut down and crumble; nothing may be built.
  - Your towns in it empty and grieve: happiness -5 and income -5% each.
  - It shows as a glowing stain on the ground.
- **Chemical Warhead** (Russia, North Korea, Iran): a drifting cloud that kills infantry; tank crews are
  protected.
- **Biological Warhead** (Russia, North Korea): an outbreak that spreads from town to town, the
  attacker's own included.
- **Radiological (dirty) bomb** (the nuclear powers and Iran): a small blast and six minutes of poisoned
  ground.
- **Who builds what:** the silo lists only your nation's weapons.
- **How rivals use them:** a rival with chemical weapons uses them at the front in a war; biological
  weapons only when fighting for survival; Russia's first nuclear use is tactical.
- **The United Nations** (scripts/un.gd; the new UN window, U):
  - **The Security Council:** the permanent members present, each with a veto, and elected members.
  - **Drafts before it:** every use of a weapon of mass destruction (condemnation and sanctions, income
    -25% for 6 minutes), every war of aggression involving you (withdraw within 2 minutes or be
    sanctioned), and your own drafts (sanctions with a cause, or a ceasefire).
  - **Your vote:** you vote when on the Council and may veto as a permanent member.
  - **The General Assembly:** a veto sends the matter there, as resolution 76/262 requires. Two thirds
    condemn the target and isolate it, and the veto costs its user some standing.
- **Saved** with the game: contamination, incidents, the UN's record, and now also every power effect
  (sanctions, export controls, a closed strait), which used to be lost on loading.
- Research and sources: native/WMD-RESEARCH-2026-10-05.md.

- **Tests**: tools/test_kit.gd can now also switch off the UN, the WMD zones, the generals and DEFCON.
  - weapons-live-100 picks a seeded battlefield with room for its longest ranges. Its DF-17 and stealth
    targets stand exactly at their distances: the random field used to shift whenever a new system drew
    a random number at start-up.
  - faction-powers-check clears the survivors of the TOS-1A salvo before the next scenario.

Checks: tools/wmd-un-check.gd (40).

## Version 0.9.67: veterans, generals, and the nuclear ladder

- **Veterancy** (scripts/veterancy.gd): units earn experience from the damage they deal and the kills they
  make, and rise from Regular to Veteran (+10% damage, -7% damage taken), Elite (+20%, -14%, steadier aim)
  and Heroic (+30%, -20%; repairs itself out of combat). Rivals' units do the same.
  - Gold chevrons over the unit show its rank, and its card shows its experience.
  - A promotion is announced.
  - Experience is saved.
- **Generals** (scripts/generals.gd; the new Defence window, K, Generals tab): appoint up to three from
  three candidates, each with two traits, such as Armoured Spearhead, Master Gunner, Defensive Genius,
  Air Power, Infantry Commander, Logistician, Inspiring, Reckless, Cautious, Drone Warfare and Admiral.
  - A general commands from a ground or naval unit (a star over it). Your units within 50 m fight under
    their traits; Air Power covers the whole air force.
  - Generals rise with the kills made under their command: level 2 at 8 kills, level 3 at 20.
  - If their unit is destroyed, a general is killed or wounded, and a death costs war support.
  - Every rival keeps two generals with its doctrine's traits. A CIA assassination of a rival's general
    now kills its most senior one.
- **DEFCON** (scripts/defcon.gd; the DEFCON chip on the top bar and the Nuclear alert tab): the world's
  nuclear alert follows its wars:
  - a nuclear power at war: DEFCON 4;
  - two at war with each other: 3;
  - one fighting for its survival: 2;
  - a nuclear weapon used: 1.
- **Your posture:**
  - Raise it for production (and, at 2, damage), at the cost of income and relations.
  - Only at posture 2 may a nuclear missile be released.
- **DEFCON 2 and 1** bring the Nuclear crisis world event.
- **Rival nuclear powers:**
  - They mobilise as their wars grow.
  - One fighting for its survival may use a nuclear weapon (Russia most readily, all of them less readily
    when you can strike back).
  - A nuclear power you strike with nuclear weapons strikes back most of the time.
- **Fix**: minus signs and hyphens were invisible in small interface text (LCD antialiasing with hinting
  dropped them at 12-13 px, so "income -10%" read "income  10%"); the interface fonts now use grayscale
  antialiasing.
- Research and sources: native/STAGE5-RESEARCH-2026-10-05.md.

Checks: tools/stage5-check.gd (37).

## Version 0.9.66: space

- **Satellites** (scripts/space.gd, the new Space tab in the Intel window): once Satellite Recon is researched,
  launch them from a Missile Silo. Nations without launchers of their own buy launches abroad at +50%;
  Syria and Afghanistan have no space programme.
  - **Reconnaissance**: an imaging pass every 40 s over the nation you choose to watch. The land round its
    towns is seen through the fog for 12 s, its buildings go on your map, and your intelligence on it grows.
  - **Navigation** (two or more): guided weapons +10% accuracy. A nation that relies on GPS loses 10% at war
    with the United States.
  - **Communications** (two or more): your drones are half as easily jammed.
  - **Early warning**: +5% missile interception each, up to two.
- **Anti-Satellite Weapons** (a new era-4 discovery for the United States, China, Russia and India): a missile
  that destroys a rival's satellite 85% of the time. Firing it is an act of war, the world thinks less of you,
  and its debris can destroy anyone's satellites, yours too, until it falls back.
- **Rivals in orbit**: rivals launch satellites as their technology grows. Their reconnaissance satellites
  find your buildings, and the four with anti-satellite weapons may shoot yours down in a war.
- Research and sources: native/SPACE-RESEARCH-2026-10-04.md.

Checks: tools/space-check.gd (25).

## Version 0.9.65: from the player's review

- **Why a unit stands idle**: a unit with no fuel or no ammunition money carries a red "NO FUEL" / "NO AMMUNITION"
  marker over its health bar (scripts/unit_overlay.gd), and its card says "HALTED: no fuel. Buy it on the World
  market or restore your income."
- **Message log**: every message of the match, newest first, with its time: the new Log button beside Menu, or L;
  Esc closes it.
- **The fog of war, fair both ways**: resource deposits on land never seen are hidden; a rival knows only those of
  your buildings its forces have seen (your capital excepted), so its attack waves and missiles go for what it has
  found; its artillery needs a spotter to fire on your units, as yours does. Health bars are no longer drawn over
  enemies the fog hides (they gave them away). What the rivals know is saved.
- **Paths to victory** (scripts/victory.gd), besides conquest: Dominance (hold 40% of the land for 3 minutes) and
  Technology (reach the Future era and complete four of its discoveries; a rival: technology at its height for 5
  minutes). Each countdown is announced, and the Cabinet's new "Paths to Victory" tile shows where you and the
  leading rival stand. A diplomatic victory comes with the blocs and alliances.
- **Tests**: tools/test_kit.gd switches off the systems a check does not test (fog, home front, world events,
  victory, operating costs), so a new system cannot break an old check again; weapons-live-100 uses it.

Checks: tools/review-fixes-check.gd (13).

## Version 0.9.64: a real take-off, easier intelligence, planned cities

- **Take-off**: an aircraft slid down the runway sideways, frozen in the pose it taxied in (its position moved, its
  model never turned), and a sixth-generation fighter's wingmen only launch once it is airborne, so its battle group
  looked stuck. Now it turns onto the runway, rolls, gathers speed, lifts its nose after 22 m and climbs away.
- **Intelligence without a click a minute** (measured: one agent needed some 8 minutes of clicks every 45-75 s per
  nation for the big operations): the Intelligence Agency now opens with its first agent; "Standing orders" on a
  nation (Intel, Operations) keep agents growing the network to 60 and refreshing the dossier on their own (one
  agent: network 70 and intelligence 52 in 7.3 minutes, no clicks); intelligence fades half as fast.
- **Rival towns are planned** (scripts/city_planner.gd): by zones round each town centre (the civic heart on rings
  1-2, homes on 1-3, industry 2-4 and heavy plant further, farms on the outskirts, the army facing the nearest rival)
  and in each nation's style: a grid of rows with streets between them (the United States, Australia), compact rings
  (Europe, the UK, Japan, South Korea, Israel, Turkiye), a monumental avenue (China, Russia, North Korea, Ukraine,
  Iran, Egypt), a linear city (Saudi Arabia) or organic growth (South and Southeast Asia, Brazil, Iraq, Syria,
  Afghanistan). Measured: 82-83% of a rival's districts in their zone (47-61% before); avenue towns drawn out along it.
- **Letters from other governments** open on the right edge under the Build button, not over the battlefield.
- The war-support flag icon is imported (it showed as a blank).
- **Every capital is on the map from the start** (every government knows where the others' capitals are), so it
  can be clicked to open contact; the land round it stays under the fog.

Checks: tools/intel-standing-check.gd (6), ai-expansion-check (10).

## Version 0.9.63: world events with causes

Stage 3 of the roadmap. Nothing happens by chance: each event is caused by what the nations do, lasts while its
cause lasts (and 45 s more), and reaches every nation through the world market and its income, by how exposed it is
(scripts/world_events.gd; research and figures in native/WORLD-EVENTS-RESEARCH-2026-10-04.md):
- **The Strait of Hormuz is closed** when Iran is at war with the United States, Israel or Saudi Arabia, or closes
  it itself: oil +80%, gas +60%; the Gulf exporters lose their outlet, Japan, South Korea, India, China and Europe
  pay, other producers (Russia, the United States, Brazil) profit. (As in February-March 2026.)
- **Black Sea grain stops** when Russia or Ukraine is at war: food +50%; Egypt and the grain importers go hungry.
- **Europe's gas crisis** when Russia fights in Europe or cuts its gas: gas +100%, Europe -10%.
- **A rare-earth shock** when China fights an industrial power or its export controls are in force: silicon +70%,
  the chip makers' research slower.
- **A global recession** when two of the five largest economies fight each other: every nation -6%.
- **An arms boom** when three wars are fought at once: the arms exporters sell more.
- **Refugees** when a town is destroyed: its people flee to the two nearest nations.
Each is announced in the news feed with its cause and its effect on you; the Cabinet's new "World News" tile lists
those in force, and "The People" now shows war support.

Checks: tools/world-events-check.gd (17).

## Version 0.9.62: the home front (war support)

Stage 2 of the roadmap. Every nation's people back its wars more or less (0-100, scripts/war_support.gd; research
in native/WAR-SUPPORT-RESEARCH-2026-10-04.md):
- **By regime**: democracies (the United States, Europe, Japan, Israel, India, the UK, South Korea, Brazil,
  Indonesia, Australia, Ukraine) start at 60 and feel every loss in full; hybrid regimes (Turkiye, Pakistan, Iraq)
  at 65, 70% as sensitive; autocracies (China, Russia, Iran, North Korea, Saudi Arabia, Egypt, Syria, Afghanistan)
  at 70, 45% as sensitive.
- **What wears it down**: every minute of war (half in a war of defence), every soldier, vehicle, aircraft and ship
  lost, towns lost, shortages, and, for a democracy, starting a war unprovoked (-6).
- **What lifts it**: being attacked (+12, rally round the flag), victories, and peace.
- **What it does**: Rallied (75+) production +10% and damage +5%; Weary (30-50) income -8%; Protests (15-30)
  income -15%, production -10%, damage -5%; Collapse (under 15) income -25%, production -20%, damage -10%, and a
  democracy's parliament forces a ceasefire after two minutes. Rivals: their income follows their support; a weary
  rival will not start a war and makes peace sooner.
- **On the strip**: a flag with the figure, coloured by level; its tooltip says what it does.

Checks: tools/war-support-check.gd (13).

## Version 0.9.61: the fog of war

The first stage of the roadmap the player set (fog of war, then public war support, world events with causes,
space, veterancy / generals / DEFCON, blocs). As in Conflict of Nations or any RTS, the player now sees only what
its side sees (scripts/fog_of_war.gd):
- **Sight**: every unit and building watches the land round it (a soldier 32 m, a tank 38, an APC 44, a SAM
  launcher 75, a jet 60, a recon drone 85, a capital 85, an air defence radar 90). Allies and client states share
  what they see. Land never seen is dark, land seen before but not watched now grey: on the ground, the sea, the
  trees and the grass (one fog texture, global shader uniforms) and on the minimap.
- **The enemy**: an enemy unit shows only where it is watched; an enemy building, once seen, stays on the map where
  it was seen. What cannot be seen cannot be clicked, and the player's units fire only on what their side sees or
  what is within their own sight.
- **Reconnaissance matters**: artillery, rocket launchers and missile batteries see only 32 m of their own: they
  need a spotter (in the check, a gun would not fire at a tank 55 m off until a soldier saw it). Drones and radars
  see far. A CIA network with intelligence of 10 in a nation puts its buildings on the map.
- **Saved**: the explored land and the buildings seen are part of a save.
- **Optional**: "Fog of war: On / Off" on the New Game screen; sandbox matches start without it. Rival governments
  are not played under the fog.
- **Cost**: a refresh (four a second) takes under 1 ms.

Checks: tools/fog-of-war-check.gd (16).

## Version 0.9.60: messages along the bottom, wingmen aboard, helicopters on helipads

- **Messages no longer cover the battlefield**: they were large boxes stacked under the strip in the middle of the
  play area. Now they are a feed along the bottom edge, in the lane between the unit card and the minimap: slim,
  see-through lines (13 pt, a blue rule on the left), newest at the bottom, three at most, each gone after 5 s,
  and clear of any window that reaches down that far. Every message of the match is kept in hud.notice_log.
- **Loyal wingmen appear only when their fighter flies**: while an F-47 or J-36 stands on its airfield its two
  wingmen are aboard, off the map (wingmen_stowed); they are launched beside it as it takes off and recovered with
  no wreck as it lands, and a lost one is replaced while it rearms. A hangar of sixth-generation fighters no longer
  puts a swarm of circling drones on the map.
- **Helicopters keep to helipads**: a helicopter or gunship could take one of an airfield's jet slots; airfields
  now take fixed-wing aircraft only, helipads rotorcraft only, and a new aircraft is never parked on the wrong one.

Checks: tools/battle-group-check.gd (12).

## Version 0.9.59: rival nations found towns

The player noticed that a rival only ever had its capital and one village. Measured over fifteen minutes of a
standard match (tools/ai-expansion-check.gd): every rival had 1 capital, 0 cities and 1 village (the village from
its fixed opening), with some 23 buildings packed round the capital. Three causes in ai.gd:
- the city plan had no village at all and a city only at "0.15 per 10 buildings" (one, until 67 buildings), and it
  builds the first goals still short (farms, cottages), so it never reached either;
- a new town was only sought 75-120 m from the capital, a ring that fills;
- a building it had no room for was chosen again every time, holding up the rest.
Now a rival founds a new town for every 7 buildings it owns (a city for every two villages) before anything else,
looks for the site 75-130 m out from any of its towns so the state spreads, and sets aside for 90 s a building it
has no room for. After fifteen minutes each rival has its capital, a city and two villages, and keeps growing.

Checks: tools/ai-expansion-check.gd (6, island and pangaea).

## Version 0.9.58: the leadership raid (Operation Absolute Resolve)

A United States-only Intel operation after the capture of Nicolas Maduro (3 January 2026): a CIA network and a
fresh dossier on the leader, a cyber blackout of the capital, a strike on its air defences, and a Delta Force raid
by helicopter. On success the regime falls to a **puppet ruler**: the nation becomes a US client state (it allies
with the United States, pays tribute, joins its wars and never turns on it), and **the world fears the United
States** for 15 minutes (no government dares start a war with it, its peace offers and pacts go through more
easily, weaker enemies sue for peace at once). On failure: special forces and a helicopter lost, war, a scandal.
A rival United States raids too (era 3, $4,000, against nations it is at war with): a rival it takes becomes its
client state; a raid on you seizes your leader, a quarter of the treasury and a ceasefire (your agency usually warns
you, and a counter-intelligence review makes it likelier to fail).
See native/RUSSIA-WAR-CAPABILITIES-2026-10-04.md (3b).

Checks: tools/regime-change-check.gd (29).

## Version 0.9.57: Russia's war capabilities, and the sixth-generation battle group

- **Russia, from the war in Ukraine** (three Russia-only discoveries, scripts/national_capabilities.gd):
  Foreign Recruitment (North Korea's corps and contract recruits from abroad: while at war, 4 foreign soldiers join
  at the capital every 2.5 minutes, $60 each), UMPK Glide Bombs (every jet built afterwards is a Su-34 with glide
  bombs: +50% range, +20% damage) and Fibre-Optic Drones (FPV teams that no jammer can stop, +30% range). Russia
  also builds the Shahed, as the Geran-2.
- **The F-47 / J-36 battle group**: the fighter and its two loyal wingmen stay separate units but fly in formation
  (a slot 12 m off each wing), strike the fighter's target, meet whatever attacks any of them, and draw the enemy's
  fire away from the fighter; a click on one selects all three; a lost wingman is replaced while the fighter
  rearms ($200).
- **A unit keeps the system it was built as**: a Su-35S (or an M1A2 SEPv3) built before its successor was
  researched stays what it was.
- The Maduro raid (Operation Absolute Resolve) is researched, with a design for a United States strategic
  operation, in native/RUSSIA-WAR-CAPABILITIES-2026-10-04.md; not in the game yet.

Checks: tools/russia-capabilities-check.gd (12), tools/battle-group-check.gd (8), unit-quality (23).

## Version 0.9.56: the CIA, and AbramsX

- **United States intelligence, checked**: $115.5 billion requested for 2026 (NIP $81.9 billion, MIP $33.6 billion),
  the world's largest; the CIA's worldwide human intelligence and covert action (the Special Activities Center, armed
  MQ-9s: a strike on a Venezuelan dock in December 2025), the NSA and the NRO. The United States had +10% covert
  success, below Israel's +15%; it now has **+20% covert success** (the most of the 22) and **+10%
  counter-intelligence**.
- **Every nation's service now works as a rival too**: its counter-intelligence makes it harder to spy on (a rival
  United States 10 points harder than Brazil), and its spy service makes its agents harder to catch when it spies on
  you (China, Israel, Russia, the United Kingdom, Iran as well).
- **AbramsX**: General Dynamics' own demonstrator (AUSA, October 2022), never ordered; its ideas went into the
  Army's M1E3, which the game already models (0.9.55). No separate tank.

Checks: tools/unit-quality-check.gd (23); espionage, intel-100, national-profile, factions and three-nations checks.

## Version 0.9.55: the American tank, and the next one

The player pointed out the American tank was underrated. Checked again:
- **The M1A2 SEPv3 now leads the tanks in service**: the only tank armoured with depleted uranium, with Trophy active
  protection, firing the M829A4 (the most powerful kinetic round in service): +24% health and +15% firepower over
  the shared tank (the Leopard 2A8 and K2 +12% and +8%, the Merkava 4 +20% and +8%), 5% slower at 78 t. Australia's
  SEPv3s too. Its name in the game is now "M1A2 SEPv3 Abrams".
- **The M1E3 Abrams, a United States-only discovery** (era 4, after Active Protection, with a tank factory): unveiled
  in January 2026 and in operational tests since the summer, with production decided around 2027. Every tank built
  afterwards is an M1E3: +30% health, +15% firepower, +20% accuracy, 12% faster than the SEPv3 (60 t, hybrid drive),
  reloads 20% faster (autoloader), and the Iron Fist active protection built in (half the missiles and drones fired
  at it stopped, without the Active Protection discovery). A rival United States fields it at era 4.

Checks: tools/unit-quality-check.gd (21).

## Version 0.9.54: every nation's own tanks, jets and missiles

A T-64BV no longer fights like an M1A2 SEPv3 or a Merkava 4. Every shared unit class (tanks, carriers, artillery,
rockets, air defence, helicopters, jets, drones, warships, submarines, stealth fighters, missile teams, infantry)
now takes, for each of the 22 nations, its own real system of 2025-26 and that system's generation
(scripts/unit_quality.gd; the research in native/UNIT-QUALITY-RESEARCH-2026-10-03.md):
- **Protection, firepower, accuracy, speed and range** by generation: from a captured T-62 (-50% health, -38%
  firepower, -45% accuracy) through the T-64BV, T-72 and Karrar (-24 to -35%), the export M1A1 and Leopard 2A4
  (-14%), the shared unit's own figures (T-90M, Type 99A, Altay, M1A2S), up to the M1A2 SEPv3, Leopard 2A8, K2 and
  Merkava 4 (+12 to +20%). Infantry varies half as much. Traits on top: the heavy Merkava and Challenger 2 are
  slower, Brazil's old Leopard 1 has a modern fire-control system, North Korea's 170 mm Koksan outranges all.
- **Accuracy is a new figure**: tank guns miss more or less often, shells and rockets scatter wider or tighter, an
  older guided missile sometimes goes astray. The unit card shows it, and an attack after research and nation.
- **Every nation's system by name**: 152 names added (the K2 Black Panther, the VT-4 Haider, the Chonma-216...).
- Saudi Arabia and Ukraine no longer field submarines (they have none).

Checks: tools/unit-quality-check.gd (14): four Merkava 4s beat four T-64BVs 5 of 5, four T-64BVs beat four captured
T-62s 5 of 5, and two equal armies each win some (the stronger side always takes the slot that shoots second).
nation-tech, factions (the doctrine checks now include each nation's system), additional-factions, combat-rules,
menus, three-nations, national-profile and assist checks pass. Syria's and Afghanistan's battle-hardened infantry
keep their profile's extra health; only their firepower and accuracy reflect the lighter kit.

## Version 0.9.53: the situation room

The player chose, from three directions (imperial, war room, situation room), the situation room for every menu:
- **One look for the whole game** (ui_theme.gd): dark slate glass, hairline rules, flat surfaces with soft corners,
  clear type for headings and figures alike, headings in sentence case instead of letterspaced capitals, signal blue
  for the active state; the old bevelled brass plates are gone. Every panel, button, tab, list row, bar and menu,
  the pause menu and the New Game screen included, takes it from the shared theme.
- **Each ministry's window**: a title band with a bar of the ministry's colour, the ministry's name beneath the title
  ("Ministry of Foreign Affairs", "Intelligence Directorate"...), a **briefing** down the left with the ministry's key
  figures in large type (wars, allies and the warmest and coldest nations; the treasury, income, routes and the
  dearest goods; agents, operations and the deepest network; land held, settlements and the largest rival), and tabs
  that light in the ministry's colour. On a narrow screen with the build list open too, the briefing folds away.
- **The strip**: your leader's portrait at its head, in your nation's colour; a click opens the Cabinet.
- **The Cabinet**: charts of the treasury, the citizens, the army and the discoveries over the last minutes.
- **A window never runs off the screen**: Afghanistan's long power text stretched the diplomacy window past the right
  edge; long lines now wrap and a window is never wider than the screen.

Checks: tools/menus-check.gd (52); interface-review, gameplay-ui-50, settings, pick and ui tests pass.

## Version 0.9.52: the Cabinet, ministries in colour, double click, Esc

- **The Cabinet (Tab, or the new first screen button):** the whole state at a glance, as a head of government sees it
  at the morning briefing: your leader, nation, era and season, the treasury, income, approval and army in large
  figures, and a large tile for each ministry in its own colour: the Treasury (stores against their limits), the
  People (approval, health, housing), the Armed Forces (manpower, units by kind, wars), Research (the project, the
  way to the next era), Foreign Affairs (every nation's standing with you), Territory (your share of the land against
  the largest rivals), Intelligence (agents, operations, networks) and the National Power. Each tile's button opens
  that ministry. (scripts/cabinet.gd)
- **Ministries in colour:** the Treasury gold, Research turquoise, Foreign Affairs emerald, Intelligence violet,
  Territory orange, the Armed Forces red, the People rose. The screen buttons are larger and wear their ministry's
  colour; each window's title band, device and title take its colour; the resources on the strip have theirs.
  (ui_theme.gd MINISTRY, RESOURCE_TINT, ministry_button, ministry_band)
- **Double click** on one of your units: every unit of its kind on screen (Shift adds them to the selection).
- **Esc** closes an open window (or the Cabinet) first; it used to pause the game over it.

Checks: tools/menus-check.gd (45): the strip, every screen button and key, every tab of every window, the build list,
selections, help, the pause menu, Esc, the Cabinet and its tiles, the colours, the double click.

## Version 0.9.51: idle troops answer a fight beside them

A bug found by gameplay-nations-100 ("your troops take on the invaders"): on Pangaea a rival's tanks fought the army
by your capital 50 m out, and six of your tanks parked 32 m from the fight never joined it. A unit only looked for
enemies within its own sight (26 m for a tank). Now an idle unit, one with no order, also turns on an enemy that is
fighting its side, out to the distance it would chase an enemy anyway (1.6 times its sight, about 41 m for a tank).
A unit on a move order still ignores the enemy, an enemy fighting no one is left alone as before, and nothing farther
off draws it away. (world.update_combat; Tactics.pick_target engaged_with.) The guard now joins in about 35 s.

Checks: tools/assist-check.gd (6); gameplay-nations-100 passes in full again; battle, city, combat, combat-regression,
combat-rules, weapons-live-100 and the performance budgets pass.

## Version 0.9.50: every nation's income and research from one world scale

All 22 nations now take their income and research from one scale (native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md,
"All 22"): 15 points for every tenfold above or below the world's level, rounded to 5. Income from GDP a head (World Bank
2024; North Korea, Bank of Korea), less the oil rents where the game already pays oil (Saudi Arabia, Iraq); research from
scientific articles per million people (World Bank 2023), Afghanistan's after the ban on women's study.
- Income: USA, Israel, UK, Australia +10%; EU, Japan, South Korea, Saudi Arabia +5%; China, Russia, Turkiye, Brazil 0;
  Iran, Indonesia, Ukraine -5%; India, Egypt, Iraq -10%; North Korea, Pakistan, Syria -15%; Afghanistan -25%.
- Research: Israel, UK, South Korea, Australia +10%; USA, China, EU, Iran, Russia, Japan, Saudi Arabia +5%; Turkiye,
  Brazil, Ukraine, Iraq 0; India, Indonesia, Egypt -5%; Pakistan -10%; Syria -20%; North Korea -25%; Afghanistan -50%.
- The leaders' texts say the new numbers. Nothing else about the nations changed.

## Version 0.9.49: Syria and Iraq on the same scales as Afghanistan

One method for all three (native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md, "Syria and Iraq"): income from GDP a head
on the scale between Pakistan (-10%) and Egypt (0%); research from scientific articles per million people (World Bank,
2022) on the scale between North Korea (-20%, 9.4) and Egypt (-10%, 200); farms at half the fall of the 2025 wheat harvest.
- **Iraq:** research -10% (was -15%; 280 articles a million); income unchanged (its wealth is the oil, already +50%);
  farms -20% confirmed (the 2025 drought: river-irrigated wheat halved).
- **Syria:** income -15% (was -25%; $847 a head), research -15% (was -20%; 26 a million), farms -20% (new: wheat -40%
  in 2025, the worst drought in 36 years).
- **Afghanistan:** research -45% (was -40%; 3.9 a million, less the students barred), the rest as in 0.9.48.

Checks: tools/three-nations-check.gd (37), including that the three keep the order their data gives.

## Version 0.9.48: Afghanistan and the suicide squad calibrated against real data

The first numbers were estimates; each is now drawn from a real figure and anchored to values the game already
gives other nations (native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md, "Calibration"):
- **Income -25%** (was -30%): $417 a head (2024), on the scale between Pakistan (-10%, $1,485) and Egypt (0%, ~$3,400).
- **Research -40%** (was -35%): output as low as North Korea's (-20%), times the 28% of students the ban on women removed.
- **Trade -40%** (confirmed): trade with Pakistan fell 40% in 2025; the border has been shut since October 2025.
- **Happiness -8** (was -5): last in the World Happiness Report six years running; the game's largest single effect.
- **Suicide Attack Squad:** one blast is 3.9 rocket-team shots (124), the toll of a Taliban suicide attack (4.4 killed
  on average) over an attack by other means (1.14): deadlier to infantry (124, was 75); against armour (75) and buildings (149) about as before.

Checks: tools/three-nations-check.gd (35).

## Version 0.9.47: Iraq, Syria and Afghanistan

Three more nations, 22 in all, each researched as it stands in 2026 (native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md):
- **Iraq**, Prime Minister Ali al-Zaidi: oil +50%; F-16IQs, M1A1M Abrams and the Cheongung II; its own unit the
  *Golden Division (CTS)*, elite assault infantry hard on buildings; its power *Popular Mobilization*, six militia
  fighters at the capital at a price in Washington (relations with the United States -6, Iran +4). Research -15%,
  harvests -20% (drought). Starts at Baghdad on the Middle East map.
- **Syria**, President Ahmed al-Sharaa: battle-hardened, cheap infantry; *Shaheen Drone Teams*; its power
  *Reconstruction Aid*, money from its partners and repairs at home. No jets, attack helicopters, warships but
  gunboats, or strategic air defence (lost in December 2024); income -25%, research -20%.
- **Afghanistan**, Supreme Leader Hibatullah Akhundzada (the Taliban): cheap, fast-raised, hardy infantry; its own
  unit the *Suicide Attack Squad*, which closes in and detonates; its power *Insurgent Attacks*, three buildings
  struck deep inside an enemy country and its income cut, condemned by every other nation. No air force but
  captured helicopters, no navy, no strategic air defence or missiles, and no nuclear reactor; income -30%,
  research -35%, trade -40% (sanctions). Starts hostile to Pakistan (the 2026 war).
- New national rules: a shared unit, a discovery or a **building** a nation does not have (national_variants.gd
  EXCEPT, RESEARCH_EXCEPT, BUILD_EXCEPT). No nuclear reactor or missile silo for any of the three, no shipyard for
  landlocked Afghanistan: the build menu leaves them out, placing one is refused ("Not built by ..."), and the
  rivals never build them. A starting army holds only what its nation fields. Even F10 does not open them.
- Illustrated leader portraits added on 3 October 2026; national emblems remain as fallback.

Checks: tools/three-nations-check.gd (33); additional-factions-check now also covers the three new units.

## Version 0.9.46: a testing cheat for everything

- **F10, or "Testing: everything (F10)" in the pause menu (Esc):** for testing the game. Every era reached,
  every discovery your nation fields complete, every research track at its last level, $1,000,000 more, every
  store filled with the limits raised to 99,999 (as F8 does), every home filled and 200 more army capacity.
  Every unit and missile your nation fields is unlocked; what is trained next has the research's bonuses
  (units already in the field keep their stats). A discovery or weapon only another nation fields stays
  theirs: Iran still gets no F-35. F8 is unchanged (money and stores only). Kept in saves.
  (scripts/cheats.gd; checks: tools/cheat-check.gd, 17.)

## Version 0.9.45: choose where each nation starts

- **Start**, on the New Game screen beside each nation (yours and every rival's): *Auto* (the map's own choice;
  on the real-world maps, a nation's own capital), or one of the map's regions, numbered as on the map
  preview and named by its city on the real-world maps (Ankara, Riyadh, Seoul...) or by its quarter of the map
  elsewhere (North-east, South...). A region taken by choice shows in that nation's colour on the preview;
  choosing a region another nation holds swaps the two; another map clears the choices. The nations left on
  Auto go where they would have, or, when a chosen nation took that place, to the free region farthest from
  the others; on the real maps a nation whose capital was taken goes to an open city. On the two original
  islands your prepared town is fixed; the rivals may be placed at the other three starts. Kept in saves.
  (match_setup.gd "starts", start_slots; map_generator.gd _spread_starts, _chosen_starts, slot_positions.)

Checks: tools/start-choice-check.gd (26), and tools/start-choice-100.gd: every region of all 18 maps as
yours (a rival's on the original islands) with the town and army, a full house shuffled, half placed and half
left to the map; the options' rules; real capitals given away; duels; oil, iron and gold by every chosen
capital; the New Game pickers (swaps, Auto, colours, more and fewer rivals); matches begun with choices,
saved and reloaded, and begun from the screen.

## Version 0.9.44: a hundred checks on the new maps; duels across the map

- **A duel on a real-world map faces across it:** when two nations new to the region met on the Middle East,
  they took the first two open cities on the list, Riyadh and Baghdad, 320 m apart on a 1600 m map. In a
  duel an open city within a quarter of the map of the other capital is now passed over (Riyadh and Kyiv);
  with three nations or more the open cities are taken in the map's order as before.
- **tools/new-maps-100.gd**, twenty checks on each of the five newest maps. As generated: the same seed
  makes the same map; land and sea in proportion; every deposit on sound ground (sea oil and fish at sea);
  whichever of the nine nations you lead, a capital on land, at your real capital where the map shows it;
  two nations far apart; five nations each in their own place; the map picker entry and preview. Played at
  the map's full count of nations: every capital on land in its own territory; land for every nation; no unit
  starts in the sea; a worker builds; no building in the sea; a tank sent into the sea stops on the shore;
  a corvette sails; the map's own geography (Ankara reaches Tehran, Kyiv to Ankara round the Black Sea,
  Brussels reaches Moscow, Madrid to Rome round the sea, Tokyo cut off from Beijing by sea, Beijing reaches
  Hanoi, the other continent only by the isthmus, the Distant Lands out of reach by land, Fractal linked by
  land and twice as ragged a coast as Continents); rivals grow and keep their land forces ashore; the economy
  runs and the simulation keeps up (1 to 3 ms a step at 8 or 9 nations); a save comes back as it was.

## Version 0.9.43: a calmer pace, real-world maps, and roads kept clear

- **Pace:** a new choice on the New Game screen, beside the difficulty: Slow (60%), Relaxed (75%, the default)
  or Standard (100%). The whole world runs at that share of its old speed together (movement, building,
  training, research, the economy, the seasons, the rivals), so nothing changes in its balance; the camera and
  the interface keep their own speed. Kept in saves.
- **Real-world maps**, in the spirit of Civilization's "true start location" Earth maps: each nation whose
  capital lies on the map starts at it, the others at open great cities of the region.
  - *Middle East* (8): Ankara, Jerusalem, Tehran, Moscow, Athens for Europe; open: Riyadh, Baghdad, Kyiv.
  - *Europe* (9): Brussels, Moscow, Ankara, Jerusalem; open: Madrid, Rome, Stockholm, Warsaw, Kyiv.
  - *East Asia* (9): Beijing, Tokyo, New Delhi; open: Seoul, Ulaanbaatar, Hanoi, Taipei, Manila, Jakarta.
  Real coastlines, the Mediterranean, Black, Caspian, Red and Baltic seas, the Persian Gulf, and the great
  ranges: Alps, Pyrenees, Carpathians, Caucasus, Taurus, Zagros, Alborz, Urals, Himalaya, the Tibetan plateau,
  Tian Shan, Hindu Kush, Atlas and more (scripts/world_geography.gd). Island nations need a navy.
- **Two maps after Civilization VII:** *Continents and Distant Lands* (8): two homeland continents, joined only
  by a far southern isthmus, and between them rich islands no one starts on (gold, diamonds, uranium, oil);
  *Fractal* (6): ragged land of peninsulas and inlets, every region different, a land route still linking each
  capital to the next.
- **Units no longer give up on a winding road:** a unit judged its progress by the straight line to its
  destination, so a route that first leads away from it (round a bay, a lake or a sea) looked like no progress
  and the unit stopped after some seconds. On such a detour it now counts the way still to go along the route.
- **Roads kept clear:** a building may no longer be put on a hex a road or railway runs through ("build beside
  it"; a town hall may, as roads lead to it); and a car whose road has a building standing on it (an old save)
  leaves the road instead of driving into the building and holding up the cars behind it.

Checks: tools/pace-check.gd, tools/real-maps-check.gd (38), and the map tests now cover the five new maps;
road-traffic-check.gd adds the building-on-a-road cases.

## Version 0.9.42: buildings do what their cards say

A hundred economy checks (tools/economy-100.gd) found buildings whose cards promised effects the native game
never applied:
- **Power Plant** now gives +15% production and construction speed (up to +30% from several).
- **Ammo Depot** now gives +5% damage (up to +25%) and 6% faster reloading (up to 18%) to all your units,
  besides storing missiles.
- **Command & Control** now gives +10% health to the units trained while it stands.
- Cards that promised approval, public order, culture or education (TV Station, Police Station, School,
  Library, University, Museum, Park, Stadium, Courthouse), which this game does not have, now say what the
  building really does: research, happiness, income, or the research it is needed for.

The checks cover the stores and caps, citizens (growth, housing, health, hunger, fuel, chips, winter gas),
food, taxes and administration, mines and offshore rigs, the world market, trade routes (exports, imports,
losses, war, lost ports, escorts, overland trade, sabotage), rival economies, army capacity and prices, the
towns' accounts (they house the whole nation), saves and the resource bar.

## Version 0.9.41: a lapsed offer stays lapsed

A foreign government's letter (an alliance, a trade pact, a non-aggression pact) waits for your answer, but
the world does not: accepting it after war had broken out left you allied with, or trading with, the nation
at war with you, and a fallen nation could still sign. Such an offer now lapses, with a notice. Found by
tools/diplomacy-100.gd, a hundred diplomacy checks (relations, war and peace, treaties, letters, leader
contacts, firm language, limited operations, passage, saves, the screen); tools/intel-100.gd and
tools/research-100.gd add a hundred each for intelligence and research.

## Version 0.9.40: every nation's own technology, smoother big maps, traffic fixes

- **Each nation fields what it really has (2025-26)** (national_variants.gd). Shared units carry the name of
  your own nation's system: China's stealth fighter is the J-20, Russia's the Su-57, Turkiye's the KAAN,
  Israel's the F-35I Adir; tanks, jets, helicopters, air defence, anti-tank and anti-aircraft teams, rocket
  artillery, drones, warships and submarines likewise. What a nation lacks is shut to it and to rivals of that
  nation: heavy bombers only for the United States (B-52), China (H-6K) and Russia (Tu-160); no stealth fighter
  for Iran; sixth-generation fighters only for the United States (F-47) and China (J-36), as FCAS and GCAP have
  collapsed; nuclear weapons for the nuclear powers and Israel, nuclear submarines only for those that sail
  them; no missile defence or combat lasers for Iran; no hypersonic missiles for Europe or Israel; railguns,
  microwave weapons and uncrewed submarines only where they are tested. Your starting army holds only what your
  nation fields, and rival missile strikes use only missiles that nation has.
- **Smoother large maps:** the walk grid is drawn in tiles, so a new building updates only its own tile
  (1 ms instead of 50-60 ms on Pangaea: every nation's construction used to stutter the game). The land update
  skips empty hexes and recomputes fronts and waters only when borders move.
- **Road traffic fixed:** a new car no longer drives across the fields to the far end of its road; at the end
  of a line cars turn back without cutting into the lane behind them; two cars never start on the same spot.
- The New Game sheet's rival count checked on every map, in the packaged game too (--setup-test).
- New checks: nation-tech-check (72), road-traffic-check (18), performance-check (budgets for loading, steps,
  AI, routes, battles, saves, memory and, with a window, frame rate), gameplay-nations-100 (100).

## Version 0.9.39: sixty more checks, and the bugs they found

Thirty gameplay checks on a full nine-nation match on Pangaea (tools/gameplay-nine-30.gd): starting
relations among nine, the Diplomacy screen and minimap with nine nations, rivals growing at their own
difficulty, a war between two rivals, an attack wave marching across the continent, peace, a trade pact,
trade, spies, a national power and a summit with the ninth nation, missiles both ways, buying land, a
rival's fall, a save to disk and back, and victory. All passed.

Thirty bug hunts at the edges of the rules (tools/bugs-30.gd) found and fixed:
- A destroyed barracks or factory still took orders and money, and a destroyed missile silo still built
  missiles.
- A building destroyed twice (two hits at once) was crushed, burnt and announced twice; a unit killed twice
  exploded twice and threw its turret again.
- Orders given to dead units were kept.
- Trade pacts, non-aggression pacts, alliances, gifts and peace could be made with a nation that had fallen.
- A damaged or hand-edited save with odd match settings (text where a number belongs) stopped the load.

## Version 0.9.38: up to nine nations, each rival at its own difficulty

- **Four new maps** (map_generator.gd): Highlands (1040 m, 5 regions, a mountainous plateau), Great Lakes
  (1520 m, 9 regions, a continent full of lakes), Pangaea (1680 m, 10 regions, one supercontinent split by a
  range with passes) and Ten Isles (1760 m, 10 islands round an ocean, a lone isle in the middle). Every
  capital has flat land, oil, iron and gold, a land route to the next capital and a coast for a harbour.
  The 10-region maps are ready for a tenth nation; today a match has at most the nine factions.
- **Matches of two to nine nations:** the Rivals choice offers as many rivals as the chosen map has regions.
  Every rival starts with its capital and guard; the nations spread evenly round the map's regions, and two
  nations on a four-start map face each other across it.
- **Choose each rival and its difficulty:** under "Opponents: nation and difficulty" every rival has a nation
  and an Easy / Normal / Hard choice (the Difficulty above sets them all). A rival's difficulty sets its
  income, build and training pace, army and wave size, first attack, aggression in diplomacy, its research
  pace and its counter-intelligence. The briefing tells the mix ("1 easy 5 normal 2 hard"); saves keep it.
- **Fix:** leading any nation other than the United States, Russia or Israel gave a rival your starting town
  (workers, factories, tanks, aircraft, warships) and left you an HQ and two soldiers. You now always start
  with the full town, whichever nation you lead.
- Generating the ring maps is faster (Crown Isles 4.4 s to 2.5 s).

Checks: tools/nations-setup-check.gd (125 checks: options, 2 to 9 nation matches on seven maps, every
nation's start, each rival's difficulty in play, saves, the picker), maps-check, map-capacity-check,
map-picker-check and gameplay-maps-100 now cover the new maps.

## Version 0.9.37: strengths and weaknesses on screen

Each nation's strengths and weaknesses (0.9.36) now show where you choose and meet nations: on the New Game
screen under the chosen nation, on every rival's card in Diplomacy (Codex's nation_profile_view.gd, which
waited for the profile data), and now also for your own nation at the top of Diplomacy, beside its national
power. Check: tools/profile-views.gd (with a window).

## Version 0.9.36: each nation's strengths and weaknesses

Researched for all nine factions from 2024-2025 figures (R&D spending: Israel 6.3% of GDP, the US 3.5%, Japan
3.3%, China 2.6%, Russia 0.9%, India 0.6%; SIPRI 2024 military spending; IMF 2025 growth and inflation;
sanctions; energy exporters and importers; ageing and young populations) and put into the rules
(national_profile.gd), for the player and for rival nations alike:
- **United States:** +15% income, +20% research, +10% covert success, aircraft 10% cheaper and +10% air damage,
  +20% oil and gas; tanks and artillery 10% dearer.
- **China:** +15% production and construction, +10% income, +15% research, warships 15% cheaper, +30% silicon,
  +15% trade; an ageing population, -20% oil.
- **European Union:** +10% income, +15% trade, +10% research, +4 happiness, +5 health, air defence 10% cheaper;
  imported energy (-30% oil, -40% gas), -5% combat damage, a population growing a third slower.
- **Iran:** +40% oil and gas, drones and missiles 25% cheaper, +5% covert success; sanctions (-20% income,
  -25% trade), -6 happiness, -10% research.
- **Russia:** +50% oil, +60% gas, +20% iron, armour and artillery 15% cheaper, +5% health, +10% covert success;
  sanctions (-10% income, -25% trade), -10% research, a shrinking population.
- **India:** the fastest-growing population (+40%), +5% income, +10% construction, infantry 10% cheaper and +10%
  health, +15% iron; -5% research, -2 happiness.
- **Japan:** +20% research, +10% production, +5 happiness, +8 health, warships 10% cheaper; no resources of its
  own (-40% oil and gas), the oldest population (half the growth), infantry 10% dearer.
- **Turkiye:** drones 20% cheaper, +10% trade, +10% industry and construction; inflation (-5% income, -4 happiness).
- **Israel:** +30% research, +15% covert success and counter-intelligence, +20% gas, +5% income; a small country
  (15% less room for citizens), -2 happiness.
**Starting relations** follow real alliances and enmities: the US close to the EU, Japan and Israel; China and
Russia partners; Iran hostile to the US and Israel; India friendly with both camps.
**Checks:** tools/national-profile-check.gd (65), each nation measured against a neutral one.

## Version 0.9.35: every nation's weapons and political power

Researched for each of the nine factions (Codex's factions.gd): its signature weapons, what it fields, its
political levers and its strengths, and put into the game.
**Five new national weapons** (faction_arsenal.gd), each only for its nation:
- **Russia: TOS-1A Solntsepyok** (tank factory): 24 thermobaric rockets 40 m out; deadly to infantry and
  buildings, and no bunker or cover protects from it.
- **India: BrahMos battery** (tank factory): a Mach 3 cruise missile six hexes out; a SAM site stops only one
  in four (none of the 15-19 fired in Operation Sindoor, May 2025, was reported intercepted); twice as deadly
  to ships.
- **Japan: Aegis cruiser** (shipyard): the Aegis System Equipped Vessel (laid down July 2025), SM-3 Block IIA
  and SM-6: missile defence at sea, 80% of ballistic and 40% of hypersonic missiles within 250 m.
- **Turkiye: Bayraktar Akinci** (airfield): a heavy armed drone, eight strikes a sortie, too big for jammers.
- **Israel: Harop** (airfield): a loitering munition that hunts radars and air defence (three times the damage),
  as against Iran's air defences in June 2025.
**A political power for every nation** (faction_powers.gd), on the Diplomacy screen; rival nations use theirs too:
United States, Dollar Sanctions (income -30%); China, Rare-Earth Export Controls (military factories stop);
European Union, Sanctions Package (income -20%, partners join); Iran, Close the Strait of Hormuz (everyone
else's sea trade stops); Russia, Energy Leverage (income -25%); India, Strategic Autonomy (relations +12 with
all); Japan, Development Aid ($800: +25 and a non-aggression pact); Turkiye, Istanbul Talks (ends a war);
Israel, Mossad Operation (sabotage, a dossier and stolen research). Each recharges over minutes.
**Checks:** tools/faction-powers-check.gd (55); units-100 now covers the five new weapons too (205).

## Version 0.9.34: playing on every map

**tools/gameplay-maps-100.gd** (108 checks) plays on each of the nine maps, Codex's three new large maps
(Great Frontier, Inland Sea, Crown Isles) included: land of the capital's own; room for a farm, homes, a
barracks, a warehouse and a market in it; deposits within reach; a coast for a shipyard with open water;
a worker who builds; a tank that drives 110 m across open country; capitals a fair distance apart; every
rival building up; the economy running; the simulation fast enough (about 1 ms a step on every map); and the
map recorded in a save. It found and this version fixes:
- **Units standing where a building went up were shut inside its plot.** The site check only keeps units
  off its middle; soldiers near the edge stayed on ground that closed under them, could no longer move, and
  blocked the way (a tank behind three of them by a new farm waited there until it gave up). Anyone on a new
  plot now steps off it onto the nearest open ground.
Known and still open: now and then a tank pressing through a narrow gap between new buildings stalls there;
the march tests show the movement varying from run to run (the lake crossing passes two runs in three, as
it did before this version).

## Version 0.9.33: fifty checks on playing the game

**tools/gameplay-ui-50.gd** (51 checks) plays through the interface rather than the rules: laying out a
building with the placement ghost (refused on the sea with the reason shown, paid for on good ground, a worker
sent, Shift to keep placing, no ghost without the money), selecting buildings and units and what the command
bar allows (workers cannot attack-move, a SAM launcher cannot bombard, Repair only for the damaged, Buy land
only at a town hall), each factory's own training list, the side panels and the research tree, notices, the
pause menu, the road tool, workers working through a build queue and finishing leftover sites on their own,
groups of soldiers and tanks arriving without standing on each other, attack-move, and the defeat screen.
It found and this version fixes:
- **An order could be slipped into a rival's building**: the training command did not check whose building
  it was, so a unit ordered at a rival's barracks would be paid for by you and join their army. The interface
  never offered it, but the command now accepts orders only for your own buildings.

## Version 0.9.32: a third hundred gameplay checks

**tools/gameplay-deep-100.gd** (103 checks) covers what the other batteries did not: rival nations playing on
their own for five minutes (they build, train within their army limit, advance in technology, keep the peace,
rush home to defend their capital, launch attack waves at war, fire missiles only at war and pay for them,
never attack in a sandbox match); match settings (bounds, two-player matches, playing another nation with its
flag and weapons, the mirrored and generated maps); every missile type's effect (tactical, cluster against men,
EMP against machines, anti-ship, the world's anger at a nuclear strike), silo capacity and ammunition depots,
launching from a submarine; every spy operation; trade routes (port, pact, berths, earnings, war closing them);
bunkers; air bases; occupation zones and wearing down a rival's hold on its land; saving to and loading from
disk, and refusing damaged saves. It found and this version fixes:
- **A building could be told to train any unit**: the command did not check the building's own list, so a
  helipad would take a jet and a barracks a tank. Now each building trains only its own units.
- **Aircraft parked on a destroyed airfield stayed tied to it**, sitting on the ruin for ever. Aircraft caught
  on the ground now go up with their base; those in the air lose it and look for another.

## Nine factions and real-leader portraits

New Campaign lets you choose the United States, China, European Union, Iran,
Russia, India, Japan, Turkiye or Israel, and choose each opponent independently.
All nine have new illustrated portraits of real leaders. Campaigns still contain
2–4 nations. The original four retain their exclusive arsenals; the five new
factions add distinct unit strengths and weaknesses for player and AI alike.
See [FACTIONS.md](FACTIONS.md) for the exact bonuses, leader references and checks.

## Expanded map geography (6–8 starting regions)

New Campaign now has a compact map selector with an actual terrain preview for
all nine maps. Gold dots mark prepared capital regions. The description shows
both the region capacity and the number of active nations in the chosen campaign.
Previews are baked from the default-seed height grids, so browsing does not
regenerate terrain or stall the menu. Rebuild after terrain changes with
`--script res://tools/map-previews-build.gd`, then run an editor import.

Three expanded maps are selectable:

| Map | Width | Prepared capital regions | Geography |
|---|---:|---:|---|
| Great Frontier | 1,120 m | 6 | Broad continent with room to expand inland |
| Inland Sea | 1,280 m | 7 | A continuous land belt around a central sea |
| Crown Isles | 1,440 m | 8 | Large islands connected by land bridges around a lagoon |

This change covers maps only. Campaign setup still supports 2–4 active nations.
The extra regions are unoccupied, ready for the separate nation-count expansion.
Existing armies and towns are spread around the new maps. Each prepared region
has flat building ground, nearby oil/iron/gold, and a traversable land passage to
its neighbours. Terrain, trees and resources are deterministic for a given seed.

Integration contract: generated map data exposes `mapCapacity`, `mapSeed`, and
`spawnPositions` (all capital centres in world x/z coordinates). `startPositions`
continues to contain only the existing nations' camera/spawn anchors. Future
6–8 nation setup must populate towns/armies and update match setup independently.

Validation: `tools/map-picker-check.gd` checks all nine selections, preview assets,
capacity labels and the campaign summary. `tools/map-capacity-check.gd` checks every prepared slot at seeds 7,
42 and 109 and writes overview PNGs under `build/map-layout-*.png`.
`tools/maps-check.gd` also loads all three maps in the actual world and checks
navigation, active capitals, nearby resources, land units and ships.

## Version 0.9.31: two hundred more checks, and what they found

Two new batteries: **tools/weapons-live-100.gd** (89 checks: every new weapon in live combat on the game's own
loop, nothing fired on command) and **tools/gameplay-live-100.gd** (95 checks over time: the economy tick by tick,
workers building, factories training, research, land, supply and roads, diplomacy and war, the market, spies,
combat and repair, and a full save and load). They found and this version fixes:
- **Jets forgot their target half way through a turn.** A jet pulls out about 80 m to line up a new pass, but
  dropped its target past 1.6 times its range (about 74 m), so an idle fighter that spotted an enemy flew off
  and never came back. It now keeps its target through the turn.
- **A fast jet could circle its pull-out point for ever.** The point had to be reached within 12 m in three
  dimensions (the ground's height counted) and a fast jet's turn is wider than that. It is now done with when
  reached on the map, when it slips behind the wing, or after 8 s.
- **Ships stopped up to 11 m short of where they were sent** (the end of the route was the nearest point of the
  sea grid). Sea drones therefore never reached a ship at all. The last leg now goes to the goal itself.
- **HIMARS reached only 34 m**, though its card says four hexes. It now reaches four hexes.
- **A new unit could wait its whole reload before its first shot**: 45 s for a Shahed launcher, 30 s for a
  DF-17. The first shot now comes within 3 s.
- **Shaheds whose target was gone circled for ever.** They now carry 90 s of fuel and come down.
- **Sea drones:** guns miss a small, low, fast boat far more often, radar sees it at 60% of the range, and it
  strikes from 10 m.
- **Idle aircraft circled by the computer's clock**, not the game's: their circles ignored pause and game
  speed. They now follow game time.
- **Wingmen** circle their fighter wherever it flies (they drifted off round their launch point), and after
  loading a save they rejoin the nearest fighter.

## Version 0.9.30: weapons still in development (Global and Future eras)

From programmes in development or just entering service in 2025-2026:
- **Microwave Weapon** (tank factory; High-Power Microwave, Global era; after Epirus Leonidas, 61 of 61 drones in
  a 2025 test, 49 with one pulse): every 6 s one pulse destroys every enemy drone within 45 m (Shaheds,
  loitering munitions, sea drones), and no FPV drone gets through its field, fibre-optic ones included. Crewed
  aircraft and large drones are untouched.
- **Uncrewed Submarine** (shipyard; Uncrewed Submarines, Global era; after Boeing's Orca): cheap and quiet,
  torpedoes ships, found only at half the range.
- **Railgun Cruiser** (shipyard; Electromagnetic Railgun, Future era; after Japan's 2025 test ship, Mach 6.5):
  its guns reach 70 m inland, and its cheap shots stop 45% of hypersonic and 70-80% of cruise missiles.
- **Sixth-generation fighter** (airfield; Future era): the F-47 for the Atlantic Federation, the J-36 for the
  Crimson Empire (a quarter cheaper to research: China's has flown since December 2024), the GCAP Tempest for
  the Verdant Union. The stealthiest aircraft (seen at a fifth of the range); it takes off with two **loyal
  wingman** drones (after the FQ-42 / FQ-44, in production from June 2026) that attack what it attacks and,
  not being stealthy, draw the enemy's fire.
- **Glide Phase Interceptor** (Future era): missile defence batteries stop 60% of hypersonic missiles, not 30%.
- **Golden Dome** (Atlantic Federation only, Future era): interceptors in orbit take one shot at every missile
  fired at you, anywhere on the map (60% ballistic, 35% hypersonic, 20% cruise), at $150 an interceptor; an
  empty treasury launches none.

**Checks:** tools/units-100.gd now runs 181 checks, the new weapons included.

## Version 0.9.29: each nation's own weapons

Every nation now fields a "star" weapon of its own, which no other nation can build (the AI plays it too).
A nation is known by its flag, so the arsenal follows the nation the player picks.
- **Atlantic Federation (blue, after the United States):** the **F-22 Raptor** (airfield, Stealth Technology):
  air superiority, supercruise, seen by air defence only at a quarter of its range, and a SEAD mission: its
  missiles hit air defences 2.5 times as hard. And the **B-21 Raider** from a new discovery only it can
  research, **Classified Programs**: a flying-wing bomber still largely secret in 2025, seen only at 15% of
  the range, heavy precision bombs, two sorties before it rearms.
- **Crimson Empire (red, after China):** the **DF-17 Launcher** (tank factory, Ballistic Technology): a
  hypersonic glide vehicle six hexes out that a SAM site stops 8% of the time and a missile defence battery
  30%, and 2.5 times as deadly to ships (the DF-21D / DF-26 "carrier killer" role).
- **Golden Dominion (gold, after Iran):** the **Shahed Launcher** (tank factory, Microchips): a swarm of five
  Shahed-136 one-way attack drones five hexes out; each slow and easy to shoot down, together they saturate
  air defence (up to 15 in the air at once).
- **Verdant Union (green, after Europe):** **IRIS-T SLM** (tank factory, Guided Munitions): the air defence
  Ukraine reported hitting ~99% of what it engaged; shoots aircraft and drones 90 m out, stops 95% of cruise
  missiles, 45% of ballistic and 12% of hypersonic ones.

Other nations' weapons are not listed in your factories. **Checks:** tools/units-100.gd, 135 checks on every
modern and national unit (model, element, building, research, nation, target, friendly fire, abilities,
interception odds, movement, saving).

## Version 0.9.28: modern warfare, missile interception odds, rival missile strikes

From the wars of 2022-2026 (Ukraine, Israel and Iran, the Red Sea). Eleven new units:
- **Barracks:** FPV Drone Team (kamikaze first-person drones, deadly to vehicles), ATGM Team
  (Javelin-style top attack), MANPADS Team (Stinger-style: infantry that shoot down aircraft), Combat Medic
  (heals the infantry around it).
- **Tank factory:** HIMARS (two GPS-guided rockets, four hexes; Guided Munitions), EW Vehicle (jams drones:
  7 in 10 drone strikes near it fail; Electronic Warfare), Laser Air Defence (Iron Beam-style: burns drones,
  stops half the cruise missiles; Directed Energy), Missile Defence Battery (Arrow / THAAD; Missile Defence).
- **Airfield:** Loitering Munition (Switchblade / Lancet-style, dives into its target, one use; launched from a
  canister, so it takes no parking slot; Drone Swarms),
  Stealth Fighter (F-35-style: air defence sees it only at 40% of its range; Stealth Technology).
- **Shipyard:** Sea Drone (Magura-style explosive boat that rams warships and harbours, one use).

New research: Electronic Warfare, Active Protection (Trophy-style: half the missiles, rockets and kamikaze
drones fired at your armour are blown up short, one every 4 s), Missile Defence (+10% to every interceptor),
Manoeuvring Warheads (your ballistic and hypersonic missiles 40% harder to intercept), Directed Energy.

**Missile interception** is no longer all-or-nothing. Each air defence the missile passes gets one shot:

| | SAM site | mobile SAM | Missile Defence Battery | laser |
|---|---|---|---|---|
| cruise, cluster, EMP | 75% | 55% | 80% | 50% |
| anti-ship (sea-skimming) | 60% | 45% | 70% | 40% |
| tactical (short-range ballistic) | 35% | 20% | 80% | - |
| ballistic | 25% | 10% | 86% | - |
| hypersonic | 8% | 3% | 30% | - |
| nuclear (ICBM) | 3% | - | 55% | - |

Two batteries make two layers (86% becomes about 98%). Sources: Israel's reported 86% against Iran's ballistic
missiles in June 2025; Ukraine's Patriots, 24% of Iskanders and Kinzhals from 2022 to 2025 and 6-37% a month
once the warheads manoeuvred; Ukraine's 80-97% against cruise missiles and Shahed drones. Each missile card
shows its odds.

**Rival missile strikes:** a nation at full war with you, once its technology allows, fires tactical and
cruise missiles at your towns and bases every few minutes (later ballistic, then hypersonic ones).

**Ruins:** building on the site of a destroyed building clears its charred rubble first.

## Version 0.9.27: freighters at a ship's pace, towns keep their supply, offshore fields that can be worked

- **Trade ships** sail at a merchant ship's pace (about 5 m/s, easing away from the quay and into it, and
  lying alongside for a few seconds at each end). They used to race to cover the whole route within the
  market's delivery timer.
- **Supply:** a building in land covered by both a linked town and a new, unlinked one belongs to the
  linked town. A new village near the capital used to cut off the airfields, silos and homes around it
  (queues stopped, citizen capacity fell) until a road reached it.
- **Offshore rigs:** the water must be open under the platform, but its legs may reach the shallows. Six of
  the eleven sea oil and gas fields, the nearest ones to the player's capital among them, lie a few metres
  off a beach and could never take a rig.
- **Checks:** a battery of 111 gameplay checks in one match (tools/gameplay-100.gd): every building in the
  build menu placed and supplied, every unit trained where it belongs, research, taxes, the market,
  diplomacy, spies, missiles, combat, land, roads and saves.

## Version 0.9.26: harbours in your land, warships that get built, town tiles, leader portraits

- **Harbours** (shipyard, port, fishing wharf) must stand inside your own land, as other buildings do. But
  "on the coast" is far more generous: any sea within about a hex and a half, shallows included (ships
  launch into the nearest deep water). A notice says if a harbour has no water deep enough.
- **Warships:** a building belongs to the town whose land it stands in (or where its land was bought), not
  simply the nearest town. A shipyard next to an unlinked village used to count as cut off, so its queue
  never moved. A notice now says when a building's orders wait for supply.
- **Town hall card:** tiles with icons for residents (and a housing bar), happiness (with a mood word),
  food, taxes, land rings, and supply.
- **Leaders:** New Game portraits are framed on the face (a centred crop cut through the heads), and each
  nation's card carries its own flag colour (they were shifted when you picked another nation).
- **Checks:** a playthrough test plays 12 minutes as a player (town, workers, army, village and road,
  research, market) and looks for anything stuck; the naval test covers harbours outside your land and
  a shipyard beside an unlinked village.

## Version 0.9.25: turn the view with the middle mouse button

- Hold the middle mouse button and drag: left and right turn the view, up and down tilt it.
- Shift + middle drag drags the map, as the middle button alone did before. The keyboard still does not turn
  or tilt the view.

## Version 0.9.24: towns with accounts, land from people, roads between town halls, overland trade

- **Roads and railways** run from one of your town halls (capital, city, village centre) to another town
  hall: yours, or another nation's. A railway laid on a road's link runs beside the road instead of
  replacing it, and trains use it.
- **Overland trade:** a road or railway to another nation's town opens trade without a port (a trade pact
  is still needed). Goods travel faster than by sea (fastest by rail) and are rarely lost.
- **Land is not free.** Building on a hex no longer claims it: you may only build in your own land.
  A town's land grows with its **actual residents**, one ring at a time, with a notice when it happens.
  More land can still be bought at a town hall or won in war. (A harbour may still go on free coast next to
  your land, or there would be no shipyard.)
- **Town accounts:** a town hall's card shows residents and housing, happiness and local amenities, the
  food balance, the taxes it pays, and its land (rings, and how many more residents the next one needs).
- **Urban Era:** a standing City Center counts, linked by road or not. The citizens goal says how many
  homes you have, and how many towns are cut off.
- **Resources:** on the new maps every resource sits at a hex centre. A building on a resource hides its
  map marker.
- **Camera:** the keyboard no longer turns or tilts the view (Q/E/R/F sat next to W), and the camera glides
  over hills instead of bobbing.
- New check: `tools/towns-check.gd`.

## Version 0.9.23: research sees your shipyard; hard-to-reach sites get built

- A research facility counts once it is built, even if its town is cut off from the capital (supply
  still matters for production). The stage names the building when one is only under construction,
  with its progress.
- A worker who cannot reach the spot beside a site (water, a cliff, other buildings round it) goes to the
  closest point he can walk to and builds from there. If a site truly cannot be reached, a notice says so.
- New check: `tools/edge-build-check.gd` (coastal, outermost and hemmed-in sites; the shipyard counts).

## Version 0.9.22: a new Settings screen

- Four tabs, each setting a card with a line saying what it does; changes apply at once and are saved.
  **Defaults** puts everything back.
  - **Graphics:** quality (High / Balanced / Low, with what each means), window or full screen, and three
    new settings: vertical sync, a frame limit (30 / 60 / 120 / none), and the frame counter on or off.
  - **Sound:** master volume, and a new volume for battle and world sounds (100% is the designed mix).
  - **Controls:** scrolling at the screen edge, a new camera speed, and a list of every key and mouse action.
  - **Game:** a new autosave interval (1, 3 or 5 minutes, or off).
- In the pause menu the settings open in a wide card over the game.
- New check: `tools/settings-check.gd` (every setting is saved and restored).

## Version 0.9.21: four new maps, from small to large

Choose them under **Map** in New Game:

| Map | Size | What it is |
|---|---|---|
| Small Isle | 440 m | One compact island; the capitals are close and fights come early. |
| The Island | 640 m | The original map (and its mirrored version). |
| Twin Lands | 720 m | Two large islands joined by a narrow isthmus. |
| Archipelago | 800 m | Four islands in a ring, linked by land bridges, with islets holding resources. |
| Continent | 960 m | A great landmass: a mountain range with passes, lakes and long coasts. |

- The new maps are built by `scripts/map_generator.gd` from a fixed seed, so a map is the same every time
  and a saved game reopens on the same map.
- Every capital stands on flat ground, can be reached by land from every other capital, and has oil,
  iron and gold nearby. Trees and resources scale with the land, warships start at sea, and the
  minimap, camera limits, territory and navigation follow the map's size.
- New check: `tools/maps-check.gd` (with a window it also saves `build/map-<name>.png`).

## Version 0.9.20: a new main menu

- **Opening screen:** each entry has an icon and a line saying what it does. Continue names the campaign it
  resumes and when it was saved; Load Game says how many campaigns are saved. A "Dispatch from the front"
  card on the right gives a gameplay tip.
- **New Game is a campaign sheet** that fits on one screen:
  - the four nations as cards with the leader's portrait, flag colour, name and title;
  - rivals, island, rules and difficulty as choice cards, each with a line of explanation;
  - a summary of the choices beside Back and Begin campaign.
- **Pause menu:** a line under the title names your nation, era, difficulty and year.

## Version 0.9.19: a new Research screen

- **Title band:** points stored, research rate, discoveries completed and research buildings, as figures.
- **Eras:** the six eras as a strip (done, current, still ahead). Below it, each goal for the next era is a
  chip with its own progress bar, and the era's reward.
- **The tree** now fits beside the details, so all six eras show at once. Each card has its branch's colour
  down the edge and a state (Done, Locked, stage n/3). Hover a card for its full name and state.
- **Details:** the chosen discovery in a card with branch, era and cost tags, what it does, its
  requirements ticked or crossed, and the Research / Add to queue button. Its three stages are cards, each
  with its cost and effect, and a progress bar on the stage in development.
- **Queue:** numbered, each project with its live status and a progress bar.
- **Research tracks** (Economics, Military Science, Covert Ops, High-Tech Industry): cards along the bottom
  with level pips and a Develop button.

## Version 0.9.18: new World market and Territory windows

- **World market** has two tabs:
  - **Exchange:** a trading desk for the chosen commodity. It shows the price, its move over one and three
    minutes, a large price chart, what you hold (and your storage), the quantity choice, the price per unit
    for selling and buying, and big Sell and Buy buttons. Below it, every commodity is a row with its own
    small chart, your stock, its price and its move; click one to trade it.
  - **Trade routes:** figures along the top (ports, routes in use, loss at sea, delivered, lost). Each
    route is a card in the partner's colour, with the voyage's progress and the cargo's worth. The form
    for a new route shows what a voyage carries and is worth.
- **Territory** has two tabs:
  - **Your land:** how firmly you hold it (sovereign, integrated, occupied, contested) as one bar; the kinds
    of land you hold (plains, forest, mountain, coast); what the land yields per second; how much land each
    of your town halls may still buy; and the hex you last clicked.
  - **Nations:** one bar of the whole island split between the nations and the free land, and a row per
    nation with how firmly it holds its land.

## Version 0.9.17: new Diplomacy and Intelligence windows

- **Diplomacy** has three tabs:
  - **Nations:** a compact card per nation with the leader's portrait and title, status tags (war,
    alliance, trade pact, non-aggression, peace), a relation gauge, whom they fight and whom they stand
    with, and the Contact / Declare war buttons.
  - **World map:** a chart of every nation against every other (war, alliance, trade pact,
    non-aggression; otherwise relations from red to green).
  - **Orders:** the cabinet's standing orders.
- **Intelligence** has four tabs:
  - **Operations:** choose the target nation from coloured tabs (with your network strength there),
    then an operation from a list grouped by kind (Intelligence, Economic warfare, Sabotage and
    subversion, Leadership), each showing its odds and cost. The chosen one opens in a briefing card
    with the Authorize button.
  - **Agents:** your agents and the missions under way.
  - **Dossiers:** what the service knows of each nation, with the leader's portrait and the
    intelligence levels already reached.
  - **Reports:** the latest reports.
- The interface test's top-bar money check now compares the same compact number format the bar shows.

## Version 0.9.16: an exchange, sea-lane sabotage, armies that plan whole marches, a greener city

- **Bugs fixed**
  - Research no longer stalls: a project waiting for a building, an era or materials used to stop the
    whole queue. The projects behind it now carry on, and the whole tree (40 discoveries) can be completed.
  - Warships: a shipyard (or port, or fishing wharf) may be built on unclaimed coast up to three hexes
    from your land. The starting land never reaches deep water, so before this no shipyard could be built.
  - Soldiers hold their rifles in both hands, pointing forward, and shoulder them to fire. The animations
    are unarmed, so the rifle used to follow a hanging hand and point at the ground or backwards.
  - Armies plan whole marches. The engine's path search gave up after 4096 polygons, so any order longer
    than about 300 m stopped halfway. A notice now says when a spot cannot be reached by land at all.
  - The build marks (green, red, grey) appear only while placing a district.
- **Production:** click an order in a building's queue to cancel it with a full refund. The build panel's
  extra Menu button is gone (the top bar has one).
- **Workers keep a list of jobs:** shift + right-click adds a site to it. A worker who finishes a site takes
  the next one, or helps at the nearest unfinished site.
- **Combat rules**
  - Air defence (SAM sites, mobile SAMs, anti-aircraft vehicles) engages only aircraft in flight: not
    ground forces, and not aircraft parked on a base.
  - Artillery and MLRS reach three hexes.
  - Bunkers fire machine guns at enemy ground forces within two hexes, take a third of the damage from
    ground fire, and shelter troops beside them (half damage).
- **The market is an exchange.** A deal fills at once, and a big block pays more per unit, but the listed
  price moves over the following seconds as the order flow is absorbed. A few dozen units barely register;
  a sudden block of hundreds moves the price hard. Other traders answer: some buy dips, some chase moves,
  some ignore them. War lifts oil, gas and iron. Each price shows its move over the last minute and a chart.
- **Espionage:** "Sabotage shipping lanes" sinks a rival's cargo. Hostile agents can sink your next one.
- **Trade ships:** every open route shows its freighter, moored off your port while it waits and sailing
  out and back with a cargo. The freighters have real hulls, deck containers, a bridge, a funnel and a wake.
  Cars, lorries and locomotives have sloped windscreens, bonnets and cabs.
- **A greener, Civilization-style city:**
  - Fewer and smaller houses, with gardens and trees in every block. Blocks of flats are 2-4 floors.
  - Flags stand only on town halls and military sites.
  - Paving and concrete cover only each district's core, turning to lawn toward the hex edge.
- **Build menu:** compact rows under headings (Settlements, Homes, Food and resources, Trade and industry,
  Transport...), each with its picture, a one-line summary, cost and build time. The full description
  shows on hover.
- **Panels:** market prices have a drawn chart, and notices stand clear of an open panel.
- New checks: `tools/naval-check.gd`, `research-complete-check.gd`, `combat-rules-check.gd`,
  `route-check.gd`, `trade-check.gd`. Views: `tools/soldier-views.gd`, `tools/town-views.gd`.

## Version 0.9.15: construction you can resume, armour that gets through town, land that shows where you can build, real traffic

- **Construction never stalls.**
  - An unfinished building has a **Resume construction** button, and you can also select workers and
    **right-click the site**. Both send workers to finish it, even a site left half-built.
  - A worker that stopped short of its site (a blocked street, a crowd) tries again from another side.
    After five tries it hands the site back, and another worker is called.
  - Workers used to freeze for good at the edge of a building's plot. Routes run along the edges of blocked
    ground, and one step off that line counted as blocked. Units now slide along the edge instead.
  - If there is no free worker, a notice says so once, and the building card says "waiting for a worker".
- **Armour gets through your city.**
  - Two neighbouring districts used to leave a single 4 m walk cell between them, and tanks jammed there.
    The blocked area round a district's centre is now 5.8 m (it was 6.7 m), which leaves at least two cells.
  - Two tanks converging on one gap each waited behind the other forever. A tank now only queues behind a
    hull that is really in front of it, and one held at a standstill for two seconds edges round instead.
- **You can see where you can build**, as in Civilization.
  - While placing a district, every hex near the view is marked: green where it can go, red hatching where
    the land forbids it (too steep, too close to the water), and grey where something else does (outside
    your land, already built on, inland for a harbour).
  - Hillsides too steep to build on are now drawn as grey rock at all times, measured the way the
    building rules measure them. Before, some of them looked like meadow.
  - Coastal hexes are buildable when the ground across the hex is dry. Before, a beach at the edge ruled
    out the whole hex.
- **Traffic between towns** (`route_traffic.gd`).
  - Cars, lorries, buses and trains make whole trips from town to town along the roads and railways.
    Road vehicles keep to the right-hand lane and take bends on a curve.
  - They speed up and brake gradually, slow for bends and climbs, keep their distance in queues, and show
    brake lights. At the edge of a town they stop, wait, and turn back; a train reverses out of the station.
  - Trains are a locomotive and up to three wagons (containers, tank wagons, vans), sized to fit their line.
  - Roads now have two lanes, verges, edge lines and a dashed centre line. Railways have a ballast bed,
    dense sleepers and two rails.
  - Each kind of vehicle is one baked mesh drawn by one MultiMesh, so the traffic costs a few draw calls.
- New test: `--city-test` (armour through a crowded city, idle and stuck workers, resuming a half-built
  site). Views: `--capture-build`, `--capture-traffic`.

## Version 0.9.13: land bought at the town hall, a calmer build menu, missiles from ships, firm diplomacy

- **Buying land.** Select a capital, city or village centre and press "Buy land". The unclaimed hexes
  next to your land are outlined in gold; click one to buy it for $1,000. Each settlement may buy four.
  Troops no longer claim unclaimed land; enemy land is still won in war. AI nations buy land the same way
  when they have money to spare.
- **Build menu.**
  - It opens only when asked (the Build button at the top right, or **B**). It no longer jumps up when
    you click a soldier, the ground or a building that produces nothing.
  - A building that produces shows its orders in the same panel.
  - An enemy building stays selected and shows its card.
  - The build list is a grid of cards with pictures of the buildings as they now stand in the city.
- **Missiles from the sea.** A strategic submarine or a destroyer fires missiles from the national
  stockpile, even with no silo. Select one and use the launch buttons on its card.
- **Airfields and whole-hex buildings** no longer have district streets running through them.
- **Firm diplomacy.** In a leader contact, the "Firm language" statements fit the situation:
  - Peacetime: a formal protest, public condemnation, threatened sanctions, recalling the ambassador,
    a red-line warning.
  - Cold war: a red-line warning, expelling diplomats, an ultimatum to withdraw, a de-escalation
    hotline.
  - War: demanding surrender, a prisoner exchange, an escalation warning.

  The other government answers for itself, and each statement has consequences.
- Keyboard: **B** build list, **Tab** the Cabinet, **F8** testing resources, **F10** testing: everything (all research too). Double click a unit: every unit of its kind on screen.

## Version 0.9.12: a building for every resource, and the rest of the industry

- **One Extractor, a different site for each resource** (`architecture.extractor`):
  - oil: a drilling derrick with tanks and a separator
  - iron: a mine headframe with its winding house, an ore heap on a conveyor and ore bins
  - gold: a headframe and a timber stamp mill
  - silicon: a sand quarry with a crane and a washing plant
  - uranium: a headframe, yellow drums under a shelter and a hazard fence
  - diamond: a stepped open pit and a sorting plant

  The Mountain Mine uses the iron mine.
- **Built in code:**
  - an oil refinery (distillation columns, spherical tanks, pipe racks, a flare stack)
  - a chip fab (a white clean-room hall with a glass front and roof plant)
  - a nuclear plant (a hyperbolic cooling tower, the containment dome and the turbine hall)
  - a solar farm
  - a shipyard (a building shed and a gantry crane) and a port (container stacks, cranes and a
    warehouse), both turned to face the water
  - a fishing wharf
  - an ammo depot (earth-covered magazines with blast doors and a missile rack)
  - a missile silo (magazines, a rack and launch hatches)
  - a bunker and a SAM site
  - a park (a fountain and a bandstand) and a stadium
- `--capture-industry` photographs each (`build/industry-*.png`).

## Version 0.9.11: fixes, land that grows with its people, air bases with slots

- **Fixes.**
  - Production no longer stalls at 0%. A building beyond every settlement's radius belonged to no
    settlement and counted as cut off; it now belongs to its owner's nearest settlement.
  - A far Market no longer reads as "no market".
  - The AI builds a city (farms, cottages, markets, warehouses, schools...), with military buildings
    about a third, and keeps money back for its next building.
- **Buying land.** When your troops stand on unclaimed hexes, the game asks whether to buy them
  ($1,000 a hex). Declined land is offered again after two minutes. AI nations pay from their
  treasury. Another nation's land is won only in war.
- **Settlements grow.** A settlement's land reaches as many rings round its centre as its people
  fill (about 110 people a ring): the capital and cities reach at most four rings, villages three.
  Other buildings hold the hex they stand on.
- **Consumption grows with population.**
  - Food per head rises as a city grows.
  - Oil is burned from about 150 people.
  - Chips (silicon) are used from 400 people.
  - A shortage of oil or chips costs happiness.
- **Airfields.** A real military airfield on its hex: a marked runway with lights, a taxiway, an apron
  with four numbered slots, an arched hangar, a control tower, fuel tanks and a windsock. A helipad
  has two marked pads and a hangar.
  - New aircraft park on a free slot; a base with every slot taken trains no more.
  - An aircraft ordered out taxis to the runway and takes off.
  - Right-click one of your air bases with aircraft selected, and they land, taxi to a slot, rearm and
    stay.
  - Aircraft out of ammunition come back to their own slot.
- New tests: `--state-test`, `--airbase-test`.

## Version 0.9.10: land, lakes and forests

- **No more "lakes by water level".** The sea's waves rose up to about 1.5 m. Flat land just above
  sea level was therefore washed by a film of water with surf, and hollows showed the sea surface
  through them. Now:
  - The swell dies down over land and shallows (a depth map in the water shader).
  - Land lower than 0.5 m above the sea is lifted clear.
  - Inland water not reached by the open sea is a real lake (`topography.gd`), with a basin deepening
    from its shore, a clear bank, darker still water and hardly any surf.
  - The sea shelves steadily away from its own shore.
- **Smoother land.** Two smoothing passes over the height grid (the shoreline never moves).
- **No speckle from above.** The fine grass photo repeats every 6 m and broke into dots at strategy
  height; the terrain now fades to its coarse scale with distance.
- **Pines.** Conifers made in code (`pines.gd`, `shaders/pine.gdshader`): a trunk and five jagged
  tiers, each tree with its own size, lean and shade, swaying in the wind. Pines grow mostly on
  higher ground, and half of them have a smaller companion. Birches are a less lime green.
- `--capture-terrain` renders the island from above, a field and the lakes.

## Version 0.9.9: architecture in the manner of a modern 4X city

The generic, toy-bright models on the city hexes are replaced by buildings made in code
(`scripts/architecture.gd`), with nothing downloaded:
- **Materials** generated at start-up, each with a relief map from its own height field: plaster,
  brick in courses, cut limestone blocks and overlapping roof tiles. UVs are in metres, so bricks and
  tiles keep their size on every wall and roof.
- **Details:**
  - framed windows with sills and mullions, some lit warm
  - painted shutters and panelled front doors with canopies and stone steps
  - cornices and string courses, eaves and ridge tiles
  - brick chimneys
  - classical porticoes with columns and pediments
  - domes and clock towers
  - crenellations
  - banners in the nation's colour
- **Recipes:**
  - Seat of government: honey limestone, a portico and a green dome.
  - Courthouse and bank: colonnades.
  - University and library: a clock tower or a dome.
  - School, police station and hospital.
  - Market: an open market hall.
  - Village centre: a timber-framed hall with a bell turret.
  - Factories: saw-tooth roofs with glass and a stack.
  - Apartment blocks: balconies and parapets.
  - Barracks: crenellations.
- **Residential quarters:** four to six townhouses and cottages round a small square, in varied
  colours, heights and roofs; they grow taller as the city grows.
- **Draw calls:** each district's buildings are merged into one mesh per material.
- `--capture-city` renders the capital overview and close views (`build/city-*.png`).

## Version 0.9.8: ships sail round the island, land is bought or won, waters are held

- **Ships go anywhere at sea.** The ships' water grid stopped at the map's edge, where the island runs
  up to it, so the sea split in two (396 and 250 cells) and a ship could not sail round. The grid now
  reaches 240 m past the edge (open sea there), and the sea is one body. `--sea-test` sends destroyers
  from 8 points round the island to the far side; all arrive.
- **Build anywhere in your land.** A building could stand only within a fixed radius of a settlement
  centre, so hexes you held further out were refused. Now any hex you hold is buildable; another
  nation's land is not ("Inside ...'s land").
- **Unclaimed land is bought, enemy land is won.** Troops standing on unclaimed land claim a hex only
  when their nation pays for it ($25; AI nations pay from their treasury); without money they claim
  nothing. Buildings still claim their own hex and ring free. Another nation's land is taken only in
  war (or a military operation).
- **Territorial waters.** Sea hexes within two rings of a nation's coast are its own. They are
  buildable (an Offshore Rig in your waters) and drawn on the sea with the same border line and colour
  band (`shaders/territory.gdshaderinc`, shared by the terrain and the sea). Waters do not pay yields.
- **Resource sites.** Boulders now carry the mountains' photographed rock with its relief (tinted per
  kind), each site is larger with more boulders, the site's ground is real soil, an oil field has a
  storage tank and flowline, and the markers are larger. Borders are drawn in each nation's own colour.
- New tests: `--land-test`, `--sea-test`.

## Version 0.9.7: land held hex by hex, and asking before clearing a site

- **Territory by hexes** (`territory.gd`), as in a 4X game. Land is the same 12 m hex grid the
  districts sit on. Every hex you build on is yours, with a ring of hexes around it. The capital
  claims three rings; city and village centres and Command & Control claim two. Units still
  hold the hex they stand on, and conquest wears a hex's control down as before.
  - Borders are always on the map: a line along the hex edges in each nation's colour, with a
    soft band of colour inside it.
  - The territory view (T) also washes the land in its owner's colour and hatches contested
    hexes in gold. The minimap draws the same hexes.
  - Land yields are scaled to the smaller cells, so the economy keeps its balance.
- **Clearing a site** (`site_clearing.gd`). Building where trees grow or on a natural resource asks
  first: "Clear the site and build" or "Cancel".
  - Felled trees give a little timber money ($4 each).
  - A deposit destroyed this way can never be mined again.
  - An extractor or an offshore rig does not count its own deposit.
  - Rival nations and the buildings a map starts with clear trees without asking.
  - Trees no longer grow through buildings.
- The release is built from the last commit, never from uncommitted work in the folder.
- New test: `--site-test`.

## Version 0.9.6: armour that drives like traffic, borders, conquest and resource sites

- **Armoured columns** (`--convoy-test`). Tanks used to weave from side to side and bump each other.
  Four fixes:
  - **Proportional steering** instead of all-or-nothing turns.
  - **Straight routes:** the 4 m nav-grid zigzag is straightened into straight legs wherever the
    ground allows.
  - **Pure pursuit:** each vehicle steers at a point 7 m ahead on its route.
  - **Traffic rules:** a vehicle follows the one ahead at its pace, steers smoothly round a
    stopped or crossing one, and is never shoved sideways; only real hull overlap is pushed apart.

  Formation slots are 8.5 m apart. A tank waiting in line no longer "gives up" far from its mark.
  Climbing costs at most 40% of speed. Measured on 8 vehicles over 130 m: 150–700 left/right
  reversals before, 9–18 after; hulls never closer than 5.2 m.
- **Borders and passage** (`passage.gd`). Armed forces may enter another nation's land only with a
  grant of passage, as its ally, or at war or in a limited operation.
  - **Your orders:** a move order into closed land brings a BORDER letter. Its answers: request
    passage (the other government decides by how it regards you; +50 or better always says yes), a
    military operation under the standing orders, cross anyway, or cancel.
  - **Trespass:** relations fall, and after 25 s their government answers as it would any
    incident: a protest, a strike in kind, or war.
  - **Their forces:** an AI force entering your land without leave brings a letter: grant passage,
    demand withdrawal, or open fire.
  - **Guests take no land:** only hostile forces wear down another nation's hold on a cell.
- **Operational zones** (`occupation.gd`). Press **O** and click the ground: a 60 m dashed ring marked
  OPERATIONAL ZONE appears, and the selected forces spread over the cells still to be taken.
  - Troops inside their own zone count double toward holding the land.
  - A zone in the land of a nation you are not fighting asks the cabinet first (standing orders).
  - When all the land in it is yours, the zone is secured and lifted.
  - Zones and passage grants persist in saves.
- **Natural resources** (`deposit_art.gd`). Every deposit is now a site built in code, about 10 m
  across on its own coloured ground and following the slope, with a fixed-size resource marker over it:
  - oil: a black pool and a nodding pumpjack
  - iron: rust boulders
  - gold: veined granite
  - silicon: blue quartz
  - uranium: glowing green crystals
  - diamonds: a kimberlite pit
  - offshore oil: a platform with a flare
  - fish: a shoal with ripples

  Sea deposits now exist in the game, so the Offshore Rig can be built on offshore oil. Land
  extractors and the AI never pick a sea deposit.
- `dist/` holds exactly `DOMINION.exe` (play) and `DOMINION-Setup.exe` (the release).

## Version 0.9.5: how battles are fought, and the minimap turned with the camera

Problems reported in play: armies ran together into one knot where few
could shoot, a unit sometimes stuck after an attack, and the minimap's view
frame sat crooked. `scripts/tactics.gd` changes how units fight and march:

- **Firing positions.** A unit closing on an enemy heads for a spot inside
  its own weapon range, on its own bearing, rather than to the enemy's
  position, so a squad spreads into a firing line. It stops and fires as
  soon as the target is in range, and a unit holding at the edge of range
  still has its shot.
- **Target choice.** Units prefer targets already in range, those their
  weapon hurts most and those already wounded. Every unit searches as far as
  its weapon reaches (artillery and rocket launchers used to look nearer than
  they could shoot) and swaps to a better target in range now and then.
- **Never stuck.** A target that stops being hostile (a limited operation
  ends) is dropped; ground troops do not chase ships or aircraft out of reach
  and do not "return fire" at an attacker they cannot hurt or reach; a chase
  that makes no progress for 12 s is abandoned (aircraft excepted, they make
  passes); a unit whose slot is occupied counts as arrived when close, or
  re-routes. Blocked units step round each other, and a unit jammed while
  closing in takes a new bearing.
- **Formations.** A group move forms ranks across the line of march: armour
  in front, infantry behind, artillery and air defence at the back. Slots are
  handed out in the order units already stand, and the body marches at the
  pace of its slowest member. Standing units that overlap step apart; hulls
  keep 6.5 m from each other.
- **Accuracy.** Long shots and moving targets miss more, point-blank shots
  rarely do. A 16 against 16 fight now lasts about 40 s of contact, not 10.
- **Blast physics.** Explosions shove soldiers back, jolt vehicle hulls on
  their springs, and throw a soldier killed by the blast through the air.
- **Minimap.** The map turns with the camera, so the top of the screen is the
  top of the map and the view frame always points straight up; a gold needle
  on the rim marks north. The island is scaled so no land is cut off.
- **Engine.** Decisions (target upkeep, firing positions) run ten times a
  second per unit, staggered, while movement stays at 60 Hz; standing units
  use a walk-grid lookup instead of scanning every building; a vehicle
  resamples the ground slope only after moving half a metre. In the 48-a-side
  battle benchmark this took standing units from 4.3 to 1.0 ms and placement
  from 2.5 to 0.3 ms per physics step.
- `--battle-test` fights two equal mixed forces and fails on any unit that sits
  loaded with a target in range for a second, units piling on one spot, a unit
  frozen with an enemy, a squad that will not move after an attack, or ground
  troops chasing a ship. `--capture-tactics` renders the march, the firefight
  and the turned minimap.

## Version 0.9.4: movement physics, debris and a 4X unit card

- **Momentum.** Ground units build up speed and brake onto their mark
  instead of switching between standing and full speed in one frame
  (`scripts/motion.gd`). Vehicles drive along their hull: a tank ordered
  behind itself pivots in place first rather than sliding sideways, slows
  for corners, and climbs slower than it descends.
- **Sprung hulls.** Every vehicle rides a damped spring on pitch and roll: it
  squats when it pulls away, dips its nose when it brakes, leans out of a
  turn, rocks back when its gun fires and follows the ground smoothly.
- **Debris.** Explosions throw clods, armour and masonry that fly under
  gravity, bounce off the slope, tumble, rest and fade (`scripts/debris.gd`,
  one pooled MultiMesh, one draw call). Pieces in the sea sink. Tank shells
  follow a gravity arc, blasts send a shock ring along the ground, a
  destroyed tank may cook off and throw its turret, and buildings burst.
- **Look.** AgX tonemapping, more aerial haze, deeper summer greens for
  meadows, tufts and trees; each tree crown has its own shade and is darker
  inside; leaf edges are anti-aliased.
- **Interface.** The selection card shows a round bronze-and-gold portrait
  medallion on the owner's colour, with ATTACK / RANGE / SPEED / HEALTH
  plaques. The era cartouche counts the years of the reign. Notices run in
  the lane between the side screens and the production list. Health bars
  on the battlefield carry the owner's colour and step clear of each other.
- `--motion-test` checks pivoting, acceleration, stopping, suspension,
  debris landing and the turret toss; it is part of `run-tests.ps1`.

## War is decided by the state, not by the soldier

- A soldier ordered to fire carries out the order. What the shot *means* is
  settled at the level of the state, so the choice between a limited operation
  and a full war left the unit panel: it is now the cabinet's standing orders,
  set in the Diplomacy screen (G) under STANDING ORDERS, and every first strike
  at a nation you are not at war with still goes to the cabinet for
  authorization.
- The struck government then answers for itself: it may contain the incident (a
  protest and colder relations), answer in kind (a limited operation of its own
  and a punitive column sent at your nearest holding), or call it war. The
  choice weighs how far relations had sunk, how many incidents it has already
  swallowed, how its army compares to yours and how aggressive it is — and a
  first incident is never called a war.
- AI governments now hold the same instrument. Unless relations have collapsed,
  one that wants to move against you strikes across the border and calls it a
  limited operation rather than declaring war, and your cabinet puts the three
  answers to you in a letter: contain, answer in kind, or declare war. Answering
  in kind puts another grievance on their books, and a government that runs out
  of patience declares war itself.
- The minimap wedge shows where the camera is really looking: rays through the
  top of the screen pass above the horizon and never meet the ground, so they
  are stopped at a sensible distance instead of folding the wedge into the
  corner of the map. The wedge is filled, carries an arrow at its far edge for
  the direction of view and a dot at the centre of the view, and is clipped at
  the frame.

## Panel and menu redesign

- Every panel, menu and dialog is now built from drawn plates rather than flat
  boxes: a navy body that catches the light along its top edge and sinks into
  shadow at the bottom, a double frame (near black outside, bronze inside) and a
  soft drop shadow, in the manner of the classic 4X interfaces. The plates are
  small textures generated once at startup in `ui_theme.gd` and stretched as
  nine patches, so nothing is downloaded and nothing is loaded from disk.
- Each panel wears a title band: letterspaced serif capitals on a lit strip
  closed by a gold rule. The production list, the selection panel, the screens
  window, the research screen, the controls sheet, the foreign office letters
  and the pause menu all share it.
- The build tabs are a strip of plates, the open one struck in gold with dark
  letters. The list below sits in a sunken trough, and every entry is a plate of
  its own with the picture in a bronze-lipped frame, the name in cream, the cost
  as resource chips and the build time in a small brass tally.
- The resource strip is a lit band with hairline dividers between the yields and
  the era in a brass cartouche at its end; the screen buttons sit in a mounted
  rack below it. Menu entries are plates with a gold edge that widens and
  brightens under the cursor, and the pause card is cut to the height of
  whatever screen is in it.

## September combat and interface update

- Shared navy/gold panels and serif headings, a cartographic menu ornament, and
  visible keyboard focus. Original presentation inspired by classic strategy UI.
- Explicit attacks establish hostility before the first shell's splash filtering.
  Damaged buildings briefly show their remaining health above the model.
- Alt + right click orders armed ground/air vehicles to bombard terrain or roads.
  A move or direct attack cancels the ground order. Conventional infrastructure
  damage is confined to the impacted hex; nuclear blasts retain radius damage.
- Aircraft carry a limited number of firing salvos (jet 4, bomber 3, drone 6,
  helicopters 8). Fixed-wing craft fire forward and continue through waypoints.
  Empty aircraft return to a friendly, supplied, completed airfield (helicopters
  can also use a helipad), descend, rearm for 12 seconds and take off. If no base
  is available they cannot refill; fixed-wing aircraft keep circling.
  Landing is a simplified approach, not a runway reservation or collision system.
- Ammunition, service state and ground bombardment orders persist in saves; old
  saves receive default full loads. Aircraft selection shows ammunition and status.
- `--combat-regression` checks first-strike damage, hex/radius damage, movement,
  ammunition, service, unavailable bases, save/load and the aircraft HUD. Add
  `--capture-operations` for `build/aircraft-ammunition.png`.
- The full test runner now includes 20 suites and also rejects nonzero exits
  and explicit FAIL reports even if a PASS marker was printed.

## Campaign, command and balance update

- New Game now offers the original island or its mirrored western layout,
  2–4 total participants (one human plus AI), four nation/leader pairs, difficulty,
  and Standard or Sandbox (no AI attack waves). The second layout mirrors the
  existing terrain and asset positions; it is not a newly authored continent.
  Setup persists in saves; loading a different setup rebuilds the correct scene.
- Ctrl + right click has priority over direct enemy selection and replaces an old
  bombardment order. Alt + right click bombards. The selection panel also provides
  Attack-move and Bombard buttons: press one, then left-click a destination; Esc or
  right-click cancels the pending mode.
- Ships use a deep-water A* grid, safe coastal destinations and heading recovery,
  including a permitted escape toward deeper water from old shallow-water saves.
- Selected/damaged units and damaged buildings have segmented on-map HP bars.
  The selection panel shows percent and HP; Repair orders vehicle/building repair
  at 2.5% max HP per second for $0.25 per HP. Movement, combat, recent hits (6 s),
  EMP and lost building supply pause work. Rebuild road/rail links to repair them.
- Aircraft salvos deal 2.5x their former damage; silo missiles deal 1.75x. This is
  an initial balance pass, not a claim of competitive balance. Rifle infantry,
  snipers and commandos cannot penetrate armour or attack aircraft/ships; rocket
  infantry and dedicated anti-air retain their appropriate damage profiles.
- The minimap projects actual viewport corner rays onto the ground, so the view
  outline follows camera rotation and zoom.
- Choose Limited operation or Full war in the selection panel. An attack on a
  peaceful nation requires an Authorize/Cancel warning. Limited operations last
  90 s, cost 18 relation points, break treaties and allow local defence without an
  automatic full war. Hostile repeated operations can escalate, and normal AI
  diplomacy can still choose war. Orders against that nation stop at expiration.
  Map/leader choices and operation/repair state persist in saves.
- `--polish-test` checks modifiers, cancellation, repairs, weapon roles, coastal
  navigation, minimap rotation and operation expiry. `--campaign-test` loads the
  mirrored map with two participants and a different leader, checks remapping and
  save identity. `--capture-polish` saves the strike warning for visual inspection.

## Interface and unit behaviour refinement

- Campaign choices show a live briefing with the selected leader, rival count and
  difficulty or sandbox rules. Menu pages fade in, scroll when necessary and support
  keyboard focus. Settings show a numeric volume readout and graphics guidance.
- Shared slate/brass styling covers dropdowns, sliders, text fields and focus states.
  Selection commands disable unavailable actions, indicate active targeting modes,
  explain their controls on hover and restore the saved engagement policy correctly.
  Health colour changes with damage; construction uses a separate blue fill.
- Ships accelerate gradually, reduce speed in turns and slow near their destination.
  Existing coastal collision checks and recovery remain authoritative; this is an
  improved kinematic movement model, not a rigid-body fluid simulation.
- AI production requires an operational, supplied facility and spawns at that
  facility; ships launch in water. Defenders must be able to damage their target.
  Aircraft returning/rearming or out of ammunition are excluded from new missions,
  and ships are excluded from land assault waves.
- The polish regression suite checks contextual commands, AI water launches,
  supply restrictions and aircraft availability alongside coastal navigation.

## Launch on this computer

Double-click `Start-Desktop.cmd`. It copies existing repository assets, imports
them, and launches the portable Godot runtime from `.local-tools/godot`.
No web server is required. The engine and generated asset copies are ignored by Git.

On another computer, download Godot 4.7.2 from
https://godotengine.org/download/windows/, run `prepare-desktop.ps1`, then open
`godot/project.godot` in the editor and press F5.
Godot is MIT licensed: https://godotengine.org/license/.

## World scene (main scene)

`world.tscn` loads `godot/data/map-seed1.json`, a map exported from the browser game
(`index.html?seed=1&export=http://localhost:PORT/name`, see `js/map-export.js`), so both
engines show the same island: 2.5 m height grid, 863 trees, buildings and units.
It uses the Forward+ renderer:

- Terrain shader: grass, dirt, sand and rock (CC0, ambientCG) blended by height,
  slope and noise, two texture scales, triplanar rock, wet band at the waterline.
- Sea shader: Gerstner swell, depth-based colour (seabed visible in shallows),
  refraction, sky reflection through Fresnel specular, shore foam.
- Procedural sky, ACES tone mapping, SSAO, shadows, light fog and glow.
- Birch trees as MultiMeshes in 96 m cells, swaying with per-tree wind; grass tufts
  (real blade triangles) drawn near the camera; drifting cloud shadows.
- Buildings on concrete plinths sunk into the slope.
- Soldiers: the realistic, photo-textured Mixamo soldier already in the repository
  (`assets/models/three/Soldier.glb`, also used by the browser game), its suit tinted to each
  nation's field colour (olive, tan, grey, brown), with a shoulder patch in the flag's
  colour. Rifles, sniper rifles and SMGs from the Quaternius kit are held in the right
  hand; rocket launchers are slung across the back. The body topples when killed (the
  model has no death clip). Terrain following, run speed matched to the clip.
  `-- --toon-infantry` restores the stylised soldiers; `-- --capture-infantry` saves
  close-ups to `build/infantry-*.png`. 64-unit benchmark: 21-23 FPS either way on Iris Xe.
- Ground vehicles (armor.gd) are built from code, nothing downloaded: a main battle tank
  (sloped glacis, tracks with link plates, seven road wheels, side skirts, wedge turret,
  long gun with fume extractor, cupola, hatches, machine gun, smoke launchers, antennas),
  an 8x8 APC with a 30 mm turret, a self-propelled howitzer, a Gepard-style anti-aircraft
  tank with a spinning radar, an MLRS and a SAM truck. Weathered army paint in each
  nation's colour with road dust low on the hull (vehicle.gdshader, finish per vertex:
  paint shade, bare metal, markings in the flag's colour, glass), a traversing turret,
  wheels that roll while driving, dust trails, and pitch and roll with the ground. Each
  vehicle is 2-6 meshes; the 64-unit benchmark draws fewer calls than the old Quaternius
  tank. `-- --stylised-vehicles` restores it; `-- --capture-vehicles` saves close-ups.
- Combat (effects.gd + world.gd): stats come from config.js through the map export.
  Units acquire the nearest enemy within their detection range, chase into range and
  fire; tank turrets must swing onto the target first. Rifles fire tracers that can
  miss; tank shells fly, explode (fireball, smoke, sparks, light flash, scorch decal)
  and splash nearby units. Soldiers play a death animation and later sink away; tanks
  explode into charred, smoking wrecks with the turret knocked askew. Units steer
  around each other. Explosions shake the camera when close.
- Pathfinding: a 4 m walk grid over the island (no water, steep slopes or building
  footprints plus room for a tank) feeds Godot's NavigationServer. Units follow the
  route's waypoints and re-plan every 0.8 s while chasing a moving enemy.
- Economy (economy.gd, hud.gd): prices, build times, what buildings provide, deposit
  rates and the economy constants all come from config.js through the map export.
  Once a second citizens grow toward housing capacity, taxes are collected through the
  administration level, farms feed citizens and soldiers, and extractors fill material
  stores up to warehouse caps; army size is limited by housing. Buildings are placed
  with a preview inside the capital's district (checks for water, slope, spacing and a
  free deposit for extractors); construction sites call the nearest free worker and
  rise as they are built; barracks and factories train a queue of up to five units.
  New buildings close the walk grid under them.
- AI nations (ai.gd), ported from ai.js with its difficulty table, opening build
  order and training pool: abstracted income, self-built construction, training
  from what their buildings allow, every unit home when the capital is threatened,
  and attack waves at the nearest player building once at war (easy: first wave
  after about 13 minutes). Without diplomacy, an AI declares war when its attack
  timer and aggression roll say so, or at once if the player strikes it. Buildings
  are targets too (units shoot at the walls; shells hit them) and collapse into
  burning rubble; losing every headquarters decides victory or defeat. Every
  building flies its nation's flag.
- Districts (districts.gd, district.gdshader), Civilization-style: every building
  owns a whole 12 m hex. The hex tile is paved, planted, ploughed or gravelled by type
  (plaza, residential, industrial, farm, military), eased onto the terrain with a
  kerb at the edge, and dressed with props that say what the place is: houses with
  hedges and gardens, container stacks and fuel tanks, a silo and hay bales,
  sandbags and a watchtower, planters and street lamps. Streets inside a hex run
  toward neighbouring districts of the same owner and toward entering roads, which
  hand over to them at the hex edge. Placement snaps to hexes (one district each);
  AI cities grow hex by hex next to their own districts.
- Diplomacy (diplomacy.gd), core of diplomacy.js: relation scores and war, alliance,
  trade pact and non-aggression treaties between every pair of nations. The
  Diplomacy panel (G) offers peace, gifts ($250), trade pacts (+20 needed; $40 every
  10 s for both), non-aggression pacts (+10), alliances (+55), declaring war and
  calling allies into a war. AI nations feud, fight and sign ceasefires with each
  other; an AI starts a war on the player only when relations are bad enough (and
  never through a pact), and aggressive difficulties sour faster. Allies of an
  attacked nation may join. Foreign governments write with proposals (ceasefire,
  pact, alliance, tribute) to accept or decline. Attack waves target any enemy.
- Supply (logistics.gd), ported from logistics.js: roads ($12 per hex) and railways
  ($22 + 3 iron, tougher) join neighbouring 12 m hexes, planned by A* around sea,
  steep grades and rival districts. A settlement (capital, village, city) is supplied
  when an intact route links it to the capital; buildings in its district share that
  status. Cut-off districts stop training and no longer count for the economy, and
  taxes shrink with supply coverage; railways add 25% production. Explosions wear
  down each half-link, and rebuilding a damaged link is a cheap repair. A Village
  Center founds a new district (70 m from other settlements). AI nations found
  villages and connect them to their capital by road.
- Aircraft and ships (craft.gd), built from code with armor.gd's geometry and the vehicle
  shader: warships have lofted hulls (flared bow rising to a raked stem, transom stern,
  red antifouling below the waterline), sloped superstructures with bridge windows,
  masts with a turning radar, a funnel banded in the nation's colour and a traversing
  gun; the destroyer adds vertical launch cells, a CIWS and a helicopter deck, the
  corvette missile canisters. Submarines have teardrop hulls, sails with planes, a
  cruciform tail and propeller; the nuclear boat a missile deck. Aircraft have lofted
  fuselages and glass canopies: a twin-tail fighter with wing missiles, a four-engine
  bomber, a long-winged drone with a V-tail, an attack helicopter with rocket pods and
  a five-bladed gunship; rotors turn and roundels carry the nation's colour.
  `-- --capture-craft` saves close-ups. Ships sail open water only (they look ahead and turn along the
  coast), ride the swell and leave a foam wake; aircraft hold their altitude and bank
  into turns, and jets circle rather than hover. Built at a Shipyard (on the coast;
  ships launch at sea), Helipad or Airfield. The browser's damage table
  (DAMAGE_PROFILE) decides who can hurt what: rifles and tanks cannot hit aircraft.
  Shot-down aircraft spiral in and burn; ships sink.
- Menus (menu.gd): a normal launch opens the main menu over the island, which turns
  slowly behind it: New Game (Easy, Normal or Hard), Continue (newest save), Load
  Game, Settings (graphics quality, full screen, volume; kept in
  user://settings.cfg) and Quit. In a match Esc pauses (after cancelling anything in
  progress): Resume, Save, Load, Settings, Quit to Main Menu, Quit to Desktop. Any
  test or benchmark flag skips the menu.
- Saving (save.gd): F5 or the Save button writes a JSON save to user://saves
  (%APPDATA%/DOMINION/saves; saves from the prototype's old folder are copied over once), F9 or Load
  restores it, and the game autosaves every three minutes. A save holds the economy,
  every building and unit with health, orders, construction and training progress,
  the road and rail network with damage, diplomacy, AI state and the camera; the
  terrain comes from the map file it names. Loading rebuilds streets and the walk grid.
- Sound (audio.gd): positional rifle shots, cannon, explosions and bullet impacts
  from a pool of 3D players; each tank has a looping engine that rises while driving;
  wind everywhere and surf from the nearest shore. The listener stands on the ground
  at the camera focus; distant sounds are quieter and muffled; an SFX bus adds light
  open-air reverb and a limiter prevents clipping. The WAVs in `godot/audio` are
  synthesised by `tools/make-sounds.gd` (filtered noise, swept sines, envelopes), so
  there is nothing to license; a recording can replace any file under the same name.
- World market (market.gd), ported from the trade engine in diplomacy.js: prices from
  config.js drift every 10 s. A Market allows instant deals (sell at 90%, buy at 115%).
  A Commercial Port opens trade routes to nations with a trade pact: each cargo sails
  30 s and is delivered or lost at sea (8%, less with armed warships). Routes collapse on
  war or when a pact ends, and cargo at sea is then lost. Market (M).
- Espionage (espionage.gd): an Intelligence Agency recruits named agents who gain rank
  with successful operations (the ten SPY_OPS of config.js, including assassinating a
  named head of state, general, scientist or spymaster). The odds depend on the agency,
  the network built in that nation, heat, gathered intelligence and difficulty. The
  effects are real: money changes hands, cyber attacks stop the rival's factories, proxy
  cells and rebels cut its income, a false flag sets two rivals on each other, and a dead
  general costs his army 30% of its damage. Stolen research speeds up your training
  (there is no research tree yet). Failed agents can be captured and ransomed, and a
  traced assassination can start a war. Intelligence reveals the rival's treasury, army
  and treaties, and at 60+ warns of attacks 30 s ahead. Hostile services steal and
  sabotage in turn. Intel (I).
- Missiles (missiles.gd): a Missile Silo builds the eight MISSILES types in its queue,
  stored up to 2 plus 4 per Ammo Depot. Pick one on the silo's panel and click a target:
  cruise types fly low and dive, ballistic types arc high. Blast damage falls off to half
  at the edge. Cluster missiles shred units, anti-ship missiles hit ships three times as
  hard, and an EMP disables vehicles, aircraft, ships and buildings for 35 s. Hitting a
  nation at peace is an act of war. A nuke leaves a mushroom cloud and costs 30 relation
  with every nation. The browser's discoveries are replaced by buildings: anti-ship
  missiles need a Shipyard, strategic missiles an Ammo Depot.
- Territory (territory.gd), ported from territory.js: 40 m cells are claimed by
  buildings and occupied by armed units. Land changes hands only once control is worn
  down, and cells where two nations are close in strength are contested. Held land
  yields money, food (plains) and iron (mountains), more where the hold is firm.
  Territory (T) shows the borders on the map.
- Research (research.gd, research_tree.gd): the 40 discoveries, four research tracks and
  six development eras of config.js. The nation advances from the Founding to the Future
  Era by meeting goals (villages, cities, citizens, discoveries, trade routes, research
  buildings, land); each era pays a reward and opens its discoveries. Every discovery is
  developed in three stages named for its branch (design, prototype, field trials for
  weapons; study, pilot programme, national rollout for society...). Each stage needs
  research points and at least 20 s; the prototype needs the facility (reqBuilding) and
  materials, the last stage money. A finished prototype gives half the effect, the last
  stage all of it and the unlocks (Destroyer and Submarine, anti-ship, ballistic,
  hypersonic and nuclear missiles, the Nuclear Submarine). Research is a queue of up to
  four projects fed by the capital, schools, libraries, universities, tech parks and chip
  fabs. Effects are real: food, income, citizens' health and happiness, housing, mining,
  production and construction speed, trade routes, unit health, damage, range and speed,
  cheaper vehicles and drones, stealth, spy odds and counter-intelligence, diplomacy.
  Rival nations research too (income, damage and armour per level); agents steal research
  and a dead chief scientist sets a rival back. The Research screen (Y) draws the tree
  with eras as columns and branches as rows, three stage pips per discovery, and a
  details pane with each stage's cost and progress. The build menu has Economy, Civic &
  research and Military tabs, with schools, universities, hospitals, a reactor and more.
- Interface (hud.gd, ui_theme.gd, portraits.gd, minimap.gd), laid out like a 4X game: a
  top bar of resources with icons (stock, and the rate in green or red; storage caps show
  when a store is nearly full), round screen buttons under it (research, diplomacy,
  market, intelligence, territory, menu), a production list on the right with a bar per
  building or unit: its picture, rendered from the game's own 3D model in an off-screen
  studio, name, what it does, cost in resource icons and time; a selection panel bottom
  left with a large picture, health, status and the training queue as small pictures;
  a minimap bottom right (click or drag to move the camera) and notices as small cards.
  One theme styles every panel, button, tooltip and menu: navy plates in a bronze
  frame with gold rules and title bands, in Windows' Bahnschrift with Palatino headings. The icons are drawn by `tools/make-icons.py` (Pillow) into
  `ui/icons/`. F1 shows the controls.
- Weapons: aircraft, artillery, rocket launchers, SAMs, rocket infantry and submarines fire
  projectiles that are seen to fly and explode where they land: bombers line up over the
  target and drop a stick of four bombs, jets and drones fire guided missiles, helicopters
  and gunships rocket salvos, the MLRS six-rocket barrages, artillery shells on a high arc,
  submarines torpedoes that run under the water. Splash hurts only enemies.
- Territory view (T): each nation's land is painted into the terrain in its colour (deeper
  where control is firm), with bright borders between nations, gold hatching on contested
  fronts and each nation's name over its land; the minimap shows the same. Clicking the map
  while the view is open tells who holds that land, its terrain, control and yield.
- Screens: diplomacy, market, intelligence and territory share one window of cards (a
  relation meter per nation with treaty tags, prices with trends and buy/sell buttons,
  agents with rank stars and a success meter per operation, land shares); the main menu,
  pause menu, foreign letters and the end screen follow the same style.
- The army a nation starts with is its garrison and does not use up housing, so a new
  game can train soldiers at once.
- Camera: WASD or the arrow keys (by key position, so any keyboard layout), the screen
  edge, a middle-button drag, Q/E to turn, R/F or PageUp/PageDown to tilt, and the wheel,
  which zooms toward the cursor. The view stays over the island. `-- --camera-test`.
- Quality: integrated GPUs start on `balanced` (no SSAO, two shadow cascades, FSR
  at 77%); dedicated GPUs on `high`. Override with `-- --quality=high|balanced|low`.

Options: `-- --difficulty=easy|normal|hard` (default easy), `-- --ai-speed=N`.
Controls (F1 in game): click/drag select units, click a building to open its training list,
build menu at the bottom left (Road / Railway: click a start hex, then the
destination; left click places buildings, Shift+click keeps placing, right
click or Esc cancels), right-click move or attack an enemy, Ctrl+right-click
attack-move, B battle demo, WASD pan, Q/E rotate, R/F tilt, wheel zoom.
Diagnostics: `--script res://tools/inspect.gd -- <model>` prints a model's nodes, materials and
clips; `-- --capture-views` writes `build/view-*.png`; `-- --feature-probe --no-vsync`
prints the frame cost of each expensive feature; `-- --capture-battle` saves five
frames of the battle demo to `build/battle-*.png` and records its soundtrack to
`build/battle-audio.wav`. `-- --menu-test` walks main menu, new game, pause, save and load from the menu
(`--capture-menu` saves screenshots). `-- --save-test` saves a match, changes money, buildings, roads, diplomacy and units,
loads, and checks that everything came back and routes still work.
`-- --air-sea-test` checks that ships stay at sea, aircraft keep altitude, the damage
table blocks rifles and tanks against aircraft, and both kinds of craft win their
fights (`--capture-air-sea`). `-- --research-test` checks that labs raise research, stages take their time, a prototype waits for its
facility, effects arrive half then whole, an era is reached and paid, warships unlock, tracks level,
rivals research, agents steal research and all of it is saved (`--capture-research` saves the Research
screen to `build/research-tree.png`). `-- --systems-test` builds a Market, Port, Intelligence Agency, Ammo Depot and Missile Silo, then checks
instant deals, a trade route, espionage effects, a captured agent, missile production and
strikes (war, EMP, nuclear condemnation), territory capture by an army, and that all four
survive a save and load (`--capture-systems` saves `build/systems-*.png`). `-- --diplomacy-test` checks gifts, pact income, pacts blocking war, allies joining
and peace (`--capture-diplomacy`). `-- --logistics-test` checks that a new village is cut off, supplied by a road,
cut by shelling, repaired at a discount and rail-boosted (`--capture-logistics`).
`-- --ai-test` runs hard AI in fast time and requires it to build, train, go to war
and reach the player's base, then checks the victory screen (`--capture-ai` saves
screenshots). `-- --economy-test` places a farm, barracks and housing, lets workers build them and
trains a soldier in fast time (`--capture-economy` does it in real time with
screenshots). `-- --nav-test` checks that routes across the base go around every building and
never through water. Regenerate sounds with
`--headless --path native/godot --script res://tools/make-sounds.gd`.

The earlier three-district prototype is still available: pass `res://main.tscn`.

Not yet ported: Steam integration.

## Performance

Measured on an Intel Iris Xe laptop at 1920x1080 with the seeded benchmark
(`-- --bench=N --no-vsync --quit-after-bench`), which drills the same army over the same
three camera phases every run. `-- --no-perf` puts the old behaviour back, so the two can
be measured against each other in one sitting (the laptop throttles, so only compare runs
taken minutes apart):

| Scene | Before | After |
|---|---|---|
| 128 units, three phases | 7.5 FPS, 2,337 draw calls | 20.1 FPS, 1,456 draw calls |
| 64 units, three phases | 20.6 FPS, 1,448 draw calls | 25.6 FPS, 931 draw calls |
| 120-unit battle (`--battle-bench=60`) | 12.8 FPS, median 60 ms, 165 stalls over 100 ms | 17.1 FPS, median 47 ms, 60 stalls |

What was slow, and what changed:
- **Every unit looked at every other unit** to keep clear and to find a target. Ground
  units are now bucketed into 8 m cells once a frame and read only the buckets around
  them; crowd pressure is worked out every other frame and held in between, and distances
  are compared squared so the square root only runs on a real overlap. Keeping clear fell
  from 11.5 ms to 3.4 ms a frame with 128 units.
- **Animation is the most expensive thing per figure.** Units more than 110 m from the
  camera hold their pose; they pick the animation up again as the camera comes near.
- **Shadows reached the horizon.** The sun's shadow distance is now 220 m on high, 140 m
  on balanced and 95 m on low, with a fade at the edge, and units beyond 75 m stop casting
  a shadow. This is most of the draw-call saving.
- **Health bars** are drawn only for what is hurt or selected, in front of the camera, on
  screen and within 130 m, with the tick marks on selected units only.
- **Vehicles told their shader the ground height every frame**, for every mesh; they now
  only do it when they have actually moved up or down.

`-- --profile` during any benchmark prints where each frame went, by system
(`move`, `combat`, `keeping clear`, `placing`, `steering`, `ai`, `hud`, `effects`...).
`-- --feature-probe --probe-units=N` measures the frame cost of each feature (shadows,
SSAO, grass, trees, animation, health bars) by turning them off one at a time.

## Testing everything

`powershell -ExecutionPolicy Bypass -File native/run-tests.ps1` runs every automated test in turn
(about 25 minutes) and prints a table; `-Quick` skips the AI war and the 12-minute match, and
`-Exported` runs them against the built `dist/DOMINION.exe`. A test fails if it reports FAIL,
times out, or prints any SCRIPT ERROR on the way. The suites:

| Flag | What it checks |
|---|---|
| `--smoke-test` (main.tscn) | models load, a route around a district, units move |
| `--nav-test` | routes never cross buildings or water |
| `--camera-test` | WASD, arrow keys and a middle-button drag move the view; it stays over the island |
| `--economy-test` | workers build, a soldier trains, money and food move |
| `--combat-test` | 19 duels: every armed unit fires its own weapon (bombs, missiles, rockets, torpedoes, arcing shells, bullets) and hurts its target, never its own side |
| `--combat-regression` | first-strike building damage, visible hit feedback, hex-only infrastructure damage, aircraft service, save/load ammunition and HUD |
| `--polish-test` | Alt/Ctrl input, strike cancellation, naval recovery, repairs, weapon roles, limited operations and minimap orientation |
| `--campaign-test` | mirrored terrain, two participants, chosen nation/leader, save configuration |
| `--script res://tools/campaign-flow-check.gd` | real menu start, scene reload and pending-save reload for a custom campaign |
| `--air-sea-test` | ships stay at sea, aircraft at altitude, the damage table holds |
| `--diplomacy-test` | gifts, pacts, allies joining, peace |
| `--logistics-test` | supply cut and restored by roads and rail |
| `--systems-test` | market, trade routes, espionage, missiles (EMP, nuke), territory capture, saving them |
| `--research-test` | stages, facilities, eras, unlocks, tracks, rival research |
| `--ui-test` | every screen opens and every button in it is pressed; build and train from the production list; research, help, minimap, pause and settings |
| `--save-test`, `--menu-test` | save and load, the menu flow |
| `--ai-test` | a hard AI builds, trains, goes to war and reaches the player |
| `--battle-bench=N` | a measured battle: frame times, stalls over 100 ms and draw calls |
| `--soak-test` | 12 minutes of game time against three hard rivals at 4x speed; every few seconds no unit or building has broken numbers, leaves the map or sinks, and no treasury goes negative |

Screenshot flags for looking at the result: `--capture-screens` (every screen), `--capture-ui`,
`--capture-combat` (each weapon in flight), `--capture-vehicles`, `--capture-craft`,
`--capture-infantry`, `--capture-research`, `--capture-systems`.

## Windows installer

`powershell -ExecutionPolicy Bypass -File native/build-windows.ps1 [-Version 0.9.0]` builds the
release: it copies the art into the project, exports `dist/DOMINION.exe` (a single file with the
game packed inside) and wraps it in `dist/DOMINION-Setup-<version>.exe` (about 70 MB). The version
defaults to `config/version` in `project.godot`. `dist/` is not committed.

The installer (Inno Setup script `installer/dominion.iss`) installs per user without an
administrator prompt (or for all users, if chosen), adds a Start menu entry and an optional
desktop shortcut, registers in Apps & features with an uninstaller, and ships `LICENSE.txt` and
`THIRD-PARTY-NOTICES.txt`. Saved games and settings live in `%APPDATA%/DOMINION` and survive
uninstalling and upgrading. It needs Windows 10 or later, 64-bit.

Requirements on the build machine: the Godot 4.7.2 Windows release export template (for the
portable Godot, in `.local-tools/godot/editor_data/export_templates/4.7.2.stable/`; only
`windows_release_x86_64.exe` and `version.txt` from the official
`Godot_v4.7.2-stable_export_templates.tpz` are needed) and Inno Setup 6
(`winget install JRSoftware.InnoSetup`). The build is not code-signed yet, so Windows SmartScreen
warns on first run; signing is part of the Steam release work. The exported game runs the same
test flags as the editor: `dist/DOMINION.exe --headless -- --systems-test`.

## Refreshing the map data

`powershell -ExecutionPolicy Bypass -File native/export-map.ps1 [-Seed N]` opens the
browser game in a hidden Edge window and rewrites `godot/data/map-seedN.json`, so
changes to config.js (units, buildings, economy, AI, combat, logistics) reach Godot.

## Validation

Run the Godot executable with:

```text
--headless --path native/godot res://main.tscn -- --smoke-test
--path native/godot res://main.tscn -- --capture-preview
```

Benchmark matching the browser's `?bench=N` (same three camera phases, orbit
formula, marching army and JSON fields):

```text
--path native/godot --resolution 1920x1080 -- --bench=64 --no-vsync --quit-after-bench
```

This runs in the world scene, on the same seeded map and drill as the browser.
The result prints as `DOMINION benchmark {...}` and is saved to
`godot/build/world-bench-<renderer>-<units>.json`, with GPU time and render CPU
time per frame from the engine. Add `res://main.tscn` before `--` to benchmark the
old three-district scene instead.

The smoke test requires 24 models, a route around a district, and actual unit
movement. The graphical command saves `godot/build/preview.png` and exits.
The preview was rendered on Intel Iris Xe; this does not establish full-game
performance. Interactive input still needs user playtesting.

Assets are copied from the repository's Kenney city/suburban, Quaternius character,
and terrain folders. Preserve their original credits and notices; complete the
per-asset license audit before distribution. No new third-party art was acquired.

Next art/performance gate: repeatable 1080p measurements with 24/48/96 units,
plus further refinement of building materials and aircraft landing approaches.
