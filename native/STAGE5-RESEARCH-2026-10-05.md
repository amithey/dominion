# Stage 5: veterancy, generals, the nuclear ladder (0.9.67)

Stage 5 of the roadmap the player set: unit veterancy, generals with traits, and a DEFCON-style nuclear
escalation ladder. Code: scripts/veterancy.gd, scripts/generals.gd, scripts/defcon.gd.

## Veterancy

Combat experience is real: crews and units that survive their first engagements fight markedly better.
Strategy games model it as ranks:
- Company of Heroes: three veterancy levels.
- C&C Generals: Veteran, Elite, Heroic.
- Total War: chevrons.

Here a unit earns experience from the damage it deals, and from kills (half the victim's health). Its
rank is measured against its own health, so an infantry squad and a tank both rank up after "paying for
themselves".

| Rank | Experience | Damage | Damage taken | Other |
|---|---|---|---|---|
| Regular | 0 | — | — | — |
| Veteran | 1x health | +10% | -7% | aim +0.02 |
| Elite | 3x | +20% | -14% | aim +0.05 |
| Heroic | 6x | +30% | -20% | aim +0.08; repairs itself out of combat |

Rivals' units rank up the same way. The experience is saved. Rank shows as gold chevrons over the unit
and on its card.

## Generals

Commanders matter in different ways, and the traits are built from well-known styles:
- armoured thrusts (Guderian, Patton);
- artillery doctrine (the Soviet and Russian "god of war");
- the defence in depth of Model or Kutuzov;
- logistics (Eisenhower's staff, Gus Pagonis in 1991);
- the inspiring field commander;
- the reckless or the cautious one;
- drone warfare (Ukraine, Azerbaijan 2020);
- air power (the US and Israeli emphasis);
- admirals.

Each nation's officer corps leans toward its own doctrine. For example, Russia's favours artillery, the
reckless commander and the armoured spearhead; Israel's favours air power, the inspiring commander and the
spearhead. The names are invented surnames, not real officers.

**How generals work:**
- A general commands from a ground or naval unit. Units within 50 m fight under the traits; Air Power covers
  the whole air force.
- A general rises with the kills made under their command: level 2 at 8 kills, level 3 at 20, and each
  level adds 25% to the traits.
- When their command unit dies, a general is killed half the time and is otherwise wounded for 2 minutes.
- A general's death costs war support.
- The espionage "general" assassination now also kills the target nation's most senior general.

## DEFCON

The real scale, set by the US Joint Chiefs:

| Level | Meaning |
|---|---|
| 5 | Normal peacetime readiness |
| 4 | Increased intelligence watch |
| 3 | Air force ready to mobilise in 15 minutes |
| 2 | Armed forces ready to deploy in 6 hours |
| 1 | Nuclear war imminent |

DEFCON 3 was set in October 1973 and on 11 September 2001. DEFCON 2 was set for Strategic Air Command in
the Cuban missile crisis, 1962.

**Nuclear powers** (the game's existing list): the United States, Russia, China, the United Kingdom, France
(the EU), India, Pakistan, North Korea and Israel.

**Doctrines behind the AI:**
- Russia's 2020 and 2024 doctrine allows first use when the state's existence is threatened, and is read
  in the West as "escalate to de-escalate". In the game, Russia uses a nuclear weapon twice as readily as
  other nuclear powers.
- Deterrence by a survivable second strike: missiles in stock, or a nuclear submarine at sea. When the
  player has one, the AI's chance of first use falls to a third.
- A nuclear power struck by nuclear weapons answers in kind (80%) within 20-40 seconds. A second strike
  survives the first: it launches from a submarine or the field if its silos are gone.

**How the ladder works:**
- World tension sets the level:
  - a war with a nuclear power: DEFCON 4;
  - two nuclear powers at war: DEFCON 3;
  - a nuclear power fighting for its survival (half its towns lost, or its capital under half health):
    DEFCON 2;
  - nuclear use: DEFCON 1, for 5 minutes.
- Missiles that land on a nuclear power raise the tension.
- The player's own posture runs from 5 to 2:
  - posture 3: production +10%, income -4%;
  - posture 2: production +20%, damage +5%, income -10%, and -8 relations with everyone.
- A nuclear missile can be released only at posture 2.
- At world DEFCON 2 and 1, the "Nuclear crisis" world event shakes the markets: oil, food and iron rise,
  income falls 5% and happiness falls 4 everywhere. This follows the market shocks of October 1962 and
  February 2022.
