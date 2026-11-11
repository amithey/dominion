# Firepower physics: one template for everything that hits

What a weapon does where it lands used to be written out weapon by weapon: seventeen calls of
`blast(unit, at, dmg, radius, size)` with hand-picked numbers, a separate `shell_hit`, a separate
strategic `missiles.impact`, and a table in `building_fires.gd` that decided what starts fires by the
*unit's name*. A new weapon meant touching four files and guessing numbers.

Now there is one template, `native/godot/scripts/firepower.gd`. Every weapon names a **munition**; the
munition's **profile** says what happens physically when it goes off. A grenade and a nuclear warhead
use the same template and share nothing else: each profile switches on only the parts it has.

## The profile

Every field is optional; what is left out takes the default and what is `0` is switched off.

| Field | Meaning | Grenade | Tank shell | 155 mm shell | Thermobaric | Nuclear |
|---|---|---|---|---|---|---|
| `kind` | family: `kinetic`, `he`, `heat`, `thermobaric`, `torpedo`, `beam`, `nuclear` | he | he | he | thermobaric | nuclear |
| `radius` | lethal blast radius, m | 2.5 | 3.5 | 4.5 | 5.5 | from the missile |
| `core` | share of the radius at full effect | 0.35 | 0.35 | 0.35 | 0.7 | 0.3 |
| `edge` | effect left at the rim (the fall-off between is smooth) | 0.25 | 0.25 | 0.25 | 0.5 | 0.5 |
| `frag` | fragments reach this many radii, against men in the open | 2.0 | 0 | 1.6 | 0 | 0 |
| `frag_share` | their share of the damage | 0.15 | 0 | 0.12 | 0 | 0 |
| `shock` | how hard it throws what is near | 0.6 | 1.0 | 1.5 | 1.4 | 3.0 |
| `fx` | size of the explosion shown and heard (0: none) | 0.5 | 1.0 | 1.5 | 1.4 | by yield |
| `crater` | leaves a crater when it bursts on the ground | no | yes | yes | no | yes |
| `fire` | what it sets alight (0 nothing .. 1.35 firestorm; -1: by the firing unit, the old table) | 0.2 | -1 | 0.52 | 1.3 | 1.35 |
| `structures` | reach into a building beyond its walls, as a share of the radius | 0.5 | 0 | 0.5 | 0.5 | - |
| `roads` | damage to roads and rails as a multiple of the damage (0: none) | 0 | 1.5 | 1.5 | 1.5 | - |
| `airburst` | it bursts in the air by design: no crater, nothing to the roads below | - | - | - | - | - |

`Firepower.detonate(world, shooter, munition, at, damage)` is the one place a burst is resolved:
the explosion shown, the crater, roads and rails, buildings, units (blast, then fragments), the shove,
and what it leaves burning.

## Strategic warheads

A strategic missile is far larger than a tactical burst and plays by its own rules (it strikes friend and foe,
its radius comes from the missile, it is aimed at kinds of target), so it has a profile of its own: the missile's
`special` names a row of `Firepower.WARHEADS`, and `missiles.impact` resolves its burst with
`Firepower.strategic(world, key, def, at, owner)`. What it leaves behind (a gas cloud, fallout, an outbreak,
a blackout, the escalation) stays with `wmd.gd` and `defcon.gd`.

| Field | Meaning | Plain | Cluster | Penetrator | Thermobaric | Anti-radiation | Neutron | Pulse |
|---|---|---|---|---|---|---|---|---|
| `blast` | it does something on the ground | yes | yes | yes | yes | yes | yes | no |
| `edge` | effect left at the rim (even fall-off from the centre) | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | - |
| `vs` | damage by what is struck: `emitter`, `building`, `naval`, `vehicle`, `unit` | all 1 | building 0.35, unit 1.75 | building 3, unit 0.35 | building 0.7, armour and ships 0.8, men 1.8 | radar 3, the rest 0.3 | building 0.2, vehicle 1.2 | - |
| `vs_nuclear` | the same for a nuclear warhead of this kind | - | - | building 3, unit 1 | - | - | - | - |
| `structure_reach` | buildings suffer only within this share of the radius | 1 | 1 | 1 | 1 | 1 | 0.35 | - |
| `pierce` | it reaches troops under cover | no | no | yes | yes | no | no | - |
| `fire` | what it sets alight | 0.85 | 0.55 | 0.85 | 1.35 | 0 | 0.12 | 0 |
| `shock` | how hard its blast wave throws what is near | 2 | 1 | 1 | 2 | 1 | 0.5 | 0 |
| `road_reach` | how far its damage to roads reaches, as a share of the radius | 0.4 | 0.4 | 0.4 | 0.4 | 0.4 | 0.4 | - |
| `silence` | seconds it silences the radars it strikes | 0 | 0 | 0 | 0 | 30 | 0 | 0 |

A nuclear warhead of any kind lays `Firepower.NUCLEAR` over its row: a firestorm (1.35, unless the kind names its
own fire, as a neutron warhead does), a blast wave of 3, roads torn up across the whole radius, and the mushroom cloud.
A warhead with something of its own registers `on_impact` with `Firepower.register_warhead(special, profile)`.

## Adding a weapon

1. Give the unit a weapon in `world.WEAPONS` (or `war_tools.WEAPON`), or the missile a definition.
2. If it behaves like an existing munition, name that one. Otherwise add a row to
   `Firepower.MUNITIONS`, or call `Firepower.register(key, profile)` from the file that owns the weapon.
   A strategic missile names its warhead with `special`; a new kind of warhead is a row of `Firepower.WARHEADS`.
3. A weapon that needs something of its own gives its profile an `on_detonate` callable: it runs first
   and may replace the standard burst (return `true`) or add to it (return `false`).

A weapon without a profile is refused: `tools/firepower-check.gd` (in `run-tests.ps1`) walks every unit
of every nation and every missile and fails on a weapon with no profile, a profile with a field it does
not know, or numbers out of range. It also checks the physics: the fall-off never rises with distance,
full effect at the centre, fragments reach farther than blast, a nuclear burst is bigger than a shell.

## What changed in play (stage 1)

- **Fall-off.** Damage no longer steps from 100% to 45% at half the radius: it falls smoothly from the
  core to the rim. The total over the burst is about what it was (0.62 against 0.59 of full damage,
  area-weighted), so the balance stands.
- **Fragments.** High-explosive shells, mortar bombs, aircraft bombs and rocket salvos throw fragments
  past the blast radius. They hurt only men in the open: not vehicles, not troops in a building.
- **Air bursts.** A missile that goes off high in the air (a SAM at an aircraft) no longer wears down
  the road underneath it or leaves a crater.
- **Fire by munition.** What sets a building alight is the warhead (its `fire`), not the name of the
  unit that fired it; the strategic missiles' table moved here too.
- **Shove by warhead.** How far a burst throws a soldier or rocks a hull comes from `shock`.

## Stages

1. **The template and the tactical weapons** (done): `firepower.gd`, every `blast()` and `shell_hit()`
   through `detonate()`, fire by munition, the check.
2. **Strategic missiles through the template** (done): `missiles.impact` resolves its burst with
   `Firepower.strategic()`; cluster, penetrator, neutron, anti-ship, thermobaric and anti-radiation are rows of
   `WARHEADS`, not a `match`; what a missile sets alight is its warhead's `fire`. New in play: a strategic burst
   has a blast wave (`shock`) that throws soldiers down and rocks vehicles, hardest near the centre, and a nuclear
   one hardest of all. The damage numbers are unchanged.
3. **Flight**: each profile carries how its round flies (muzzle speed, drop, time of flight, arc), so a
   mortar bomb, a tank shot and a bomb each fall the way they should; a bomb keeps the bomber's speed.
4. **Armour and angle**: where a shot strikes a hull (front, side, rear, roof) for `kinetic` and `heat`.
5. **Cover from the blast**: a building or a ridge between the burst and a man shields him.
6. **Secondary explosions**: an ammunition depot, a fuel store or a loaded vehicle that is destroyed
   goes off through the template (`cookoff`), and can set off its neighbours.
