# Space: research behind scripts/space.gd (0.9.66)

Stage 4 of the roadmap the player set (fog of war, home front, world events, **space**, veterancy and
generals and DEFCON, blocs).

## What the real world looks like (late 2026)

- About 17,100 active satellites. The United States operates about 12,900 of them, most of them Starlink
  (9,900+). China operates about 1,550 and Russia about 385.
- Military satellites: the United States has about 247, China about 157, Russia about 110.
- Orbital launch of its own: the United States, China, Russia, Europe (Ariane/Vega), India, Japan, Israel
  (Shavit), Iran (Simorgh/Qaem-100), North Korea (Chollima-1) and South Korea (Nuri). Every other nation buys
  launches abroad.
- Satellite navigation: GPS (US), BeiDou (China), GLONASS (Russia), Galileo (EU), and the regional NavIC
  (India) and QZSS (Japan). Everyone else relies on GPS.
- Destructive anti-satellite tests:
  - China, 2007: the FY-1C weather satellite. It made the largest debris cloud on record.
  - United States, 2008: Burnt Frost (USA-193).
  - India, 2019: Mission Shakti.
  - Russia, November 2021: Cosmos 1408. It left more than 1,500 trackable fragments and sent the ISS crew to
    their shelters.
- Jamming: Russian GPS jamming hit about 123,000 flights over the Baltic in four months of 2025, and Sweden
  logged 733 incidents that year. Ukraine showed that drones linked through Starlink keep flying where radio
  links are jammed.

## What the game makes of it

| Satellite | Effect | Why |
|---|---|---|
| Reconnaissance | Each pass (every 40 s, shared among the satellites) shows the land round the watched nation's towns through the fog for 12 s, puts its buildings on your map and adds 3 to your intelligence on it. | Imaging satellites revisit a site on a schedule. They don't watch it constantly. |
| Navigation (2+) | Guided weapons are 10% more accurate. A nation without its own system, at war with the US, loses 10%. | GPS can be denied to an enemy of the United States. |
| Communications (2+) | Jamming brings down your drones half as often. | Starlink in Ukraine. |
| Early warning | +5% missile interception each, up to two. | Systems like SBIRS cue the defending batteries. |

**Launch rules:**
- A launch requires Satellite Recon and, for a nation with its own launchers, a Missile Silo as the pad.
- Nations without launchers pay 50% more.
- Syria and Afghanistan have no space programme.

**Anti-Satellite Weapons:**
- A new discovery (era 4), available to the United States, China, Russia and India only.
- Each shot costs $1,500 and has an 85% chance to kill. Firing is an act of war, and every other nation's view
  of you drops.
- Each kill adds 12 debris (out of 100). Each 30 seconds, every satellite in orbit, the shooter's included, is
  struck with a chance of debris/10 %. The debris falls back at 0.5 a tick (Kessler syndrome, in miniature).

**Rivals:**
- Rivals launch satellites according to their technology: recon from tech 6, navigation at 7 if they have
  their own system, communications and early warning at 8.
- Their recon satellites find the player's buildings, which feeds the fair fog of 0.9.65.
- The four nations with anti-satellite weapons may fire them at a player they are at war with.
