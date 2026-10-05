# Weapons of mass destruction and the United Nations (0.9.68)

The player asked for four things:
- restrict the EMP missile to the nations that really have one, and rethink how it works;
- radioactive ground after a nuclear strike;
- warheads by yield (the hydrogen bomb, Russia's Tsar Bomba, the US neutron bomb);
- dirty, chemical and biological weapons, only for the nations that have them.

Their use should bring condemnation at the UN, which led to building the UN itself.

Code:
- scripts/wmd.gd: the weapons, contamination zones and the incident record.
- scripts/un.gd: the Security Council, the General Assembly and sanctions.
- scripts/missiles.gd: the impact.
- scripts/defcon.gd: nuclear release and second strikes.

## EMP

- **Non-nuclear HPM missile.** The only one actually flight-tested is American: CHAMP (Boeing and AFRL,
  2012), which hit seven targets in one flight. Its successor, HiJENKS, was tested in 2022. Both damage
  electronics without deaths or visible damage. China and Russia have high-power microwave programmes.
  - In the game, the EMP missile becomes the "HPM Cruise Missile":
    - only the United States, China and Russia can build it;
    - no blast and no casualties;
    - three microwave pulses along the last stretch of its flight;
    - vehicles, aircraft, ships and buildings are knocked out for 45 s, and drones fall;
    - the firer's own units are spared.
- **High-altitude nuclear EMP.** Starfish Prime (1962) was a 1.4 Mt burst at 400 km. It knocked out
  streetlights in Hawaii, 1,445 km away, and damaged about a third of the satellites then in low orbit. The
  US congressional EMP Commission said EMP is part of Russian, Chinese and North Korean (and Iranian)
  doctrine.
  - In the game, the "High-Altitude Nuclear EMP" is available to the US, China, Russia and North Korea:
    - no ground blast;
    - a 110 m blackout for 90 s;
    - aircraft aloft are crippled and drones fall;
    - each satellite in orbit has a 30% chance of being lost;
    - it is still a nuclear detonation (DEFCON 1, UN).

## Nuclear yields

| Weapon | Real basis | Who |
|---|---|---|
| Tactical Nuclear Missile | 5–10 kt: US W76-2 (5–7 kt), B61 low settings (0.3 kt and up), Russia's Iskander warheads | all nine nuclear powers |
| Nuclear Missile | strategic warhead, ~100–300 kt (W76-1 ~100 kt) | all nine |
| Thermonuclear Missile | ~1 Mt, the US B83 (1.2 Mt). Thermonuclear powers: the US 1952, USSR 1955, UK 1957, China 1967, France 1968 | US, Russia, China, UK, France (EU) |
| Tsar Bomba | 50 Mt, 30 October 1961: the largest explosion ever, 3,300× Hiroshima. Lead tamper in place of uranium, so ~97% fusion and relatively "clean" | Russia only |
| Neutron Warhead | enhanced radiation: US W70-3 (380 built) and W79 (deployed 1981, retired 1992). France tested one in 1980, China in 1988 | US, Russia, China, France |

The new discoveries are Thermonuclear Weapons and Enhanced Radiation Weapons (era 4; they need the Nuclear
Program and a Nuclear Reactor).

## Fallout

The Chernobyl exclusion zone still covers about 2,600 km². Fallout dose rates fall by the "7-10 rule":
every sevenfold increase in time cuts the dose rate tenfold. In the game, fallout follows a curve of the
form `strength × (1 + t/30)^-0.6`. The fallout zone also drifts downwind for its first two minutes.

| Warhead | Fallout radius | Lasts | Strength |
|---|---|---|---|
| Tactical | 0.8 × blast | 150 s | 0.6 |
| Strategic | 0.8 × blast | 300 s | 1.0 |
| Thermonuclear | 0.9 × blast | 420 s | 1.3 |
| Tsar | 0.85 × blast | 480 s | 1.0 (clean) |
| Neutron | 0.75 × blast | 60 s | 1.6 (intense, short) |
| Dirty bomb | 26 m | 360 s | 0.45 |

Inside a fallout zone:
- infantry loses 3% of its health a second, vehicles 1% (their crews) and ships 0.5%;
- buildings are shut down and lose 0.4% a second;
- nothing may be built;
- the player's towns lose people.
- Each of the player's towns in a zone costs 5 happiness and 5% income.

## Chemical, biological, radiological

All declared chemical stockpiles were destroyed under the OPCW by July 2023. Who still has or uses them:
- **Russia:** chloropicrin, CS and CN munitions in Ukraine, with more than 13,300 recorded uses by 2026.
  Novichok was used on Skripal (2018) and Navalny (2020).
- **North Korea:** an estimated 2,500–5,000 t of agents, including sarin and VX (VX killed Kim Jong-nam in
  2017).
- **Iran:** pharmaceutical-based agents. The US assessed this a CWC violation in 2024.
- **Syria:** the post-Assad government (December 2024) is cooperating with the OPCW to dismantle what
  remains, so Syria is excluded.

In the game, the Chemical Warhead (Russia, North Korea, Iran) releases a cloud for 90 s that drifts with
the wind:
- infantry loses 6% of its health a second;
- armour crews, behind NBC protection, lose 0.4%;
- buildings are untouched.

Biological weapons are banned by the BWC (1972). The US compliance reports say Russia and North Korea
maintain offensive programmes, and they raise concerns about China and Iran. The Soviet Biopreparat
programme and the 1979 Sverdlovsk anthrax leak are the history behind this.
- In the game, the Biological Warhead (Russia, North Korea) starts an outbreak at a town.
- Every 40 s the outbreak has a 40% chance to jump to the nearest uninfected town within 170 m, whoever
  holds it. The attacker's own towns can be hit too.

No state has ever used a radiological "dirty" bomb. In 1995, Chechen fighters hid a caesium-137 device in
Moscow's Izmailovsky Park and revealed it to the press. In 2022, Russia falsely accused Ukraine of planning
one.
- In the game, the dirty bomb is available to the nine nuclear powers and Iran.
- It is a denial weapon: a small blast, then six minutes of contaminated ground.

**Condemnation:** every use brings a relations penalty with every nation: chemical -20, biological -30,
radiological -15, nuclear -30 (as before). It is also recorded for the UN.

**AI use:**
- Rivals that have chemical weapons fire them at the player's infantry in a war: tech 3+, about 6% every
  15 s, at most every 3 minutes.
- A rival that has biological weapons uses them only when fighting for survival.
- A Russian rival that resorts to nuclear weapons uses a tactical warhead first ("escalate to de-escalate").

## The United Nations

- **Security Council:** 15 members, five permanent with a veto (the US, Russia, China, the UK and France).
  A substantive resolution needs 9 votes and no permanent member voting no. Abstention has not counted as
  a veto since 1946.
  - The elected members for 2026–27 are Bahrain, Colombia, the DR Congo, Latvia and Liberia, alongside
    those elected for 2025–26.
- **Veto use:** 2024 saw eight vetoes, the most since 1986. In 2025 there were four: two by the US on Gaza
  and two by Russia on amendments on Ukraine.
- **Veto initiative:** resolution 76/262 (April 2022) makes the General Assembly meet within 10 working
  days of any veto. The Assembly's resolutions are not binding but carry weight, as in March 2022, when it
  condemned Russia's invasion of Ukraine 141-5-35.
- **Precedents:**
  - Resolution 2118 (2013) on Syria's chemical weapons;
  - resolution 1718 (2006), sanctions after North Korea's first nuclear test;
  - Chapter VII, which allows binding sanctions.

**In the game:**
- **The Council:**
  - every permanent member present, plus up to 10 elected members (the best-liked nations, re-elected
    every 10 minutes);
  - a draft passes with three-fifths voting yes and no veto.
- **What comes before it:**
  - any use of a weapon of mass destruction: condemnation and Chapter VII sanctions, income -25% for 6
    minutes;
  - a war of aggression involving the player: a demand to withdraw, with sanctions after 2 minutes if the
    war goes on (allies joining a war count as collective self-defence, Article 51);
  - the player's own drafts: sanctions with a cause, or a ceasefire.
- **How members vote:** by interest. The target and its allies or patron vote no; its victims and enemies
  vote yes; the rest vote by their relations with the target. Nearly everyone condemns weapons of mass
  destruction.
- **The player's vote:** when on the Council, the player votes within 25 s and may veto as a permanent
  member.
- **After a veto, the General Assembly votes:**
  - two-thirds condemn the target: relations -8 with each yes vote and its war support -6;
  - the vetoing member loses 4 relations with each yes vote.
