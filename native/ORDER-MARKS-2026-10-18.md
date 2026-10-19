# Order marks: where your units are going (2026-10-18)

**The request (player):** when you tell a unit to move there is a green mark on the map showing where; improve it.

Before: a ring that opened for a moment at the click.

Now (`scripts/order_marks.gd`), for the selected units:

- a **flag** (pole, pennant, pulsing ring) where you clicked, which stays until the last unit arrives and then fades;
- **one bold dashed line** per group, marching toward the mark, from the first unit of each destination and kind of movement (land, air, sea); with a small selection the other units get faint lines, with a large one none (forty identical lines hide the map);
- each unit's own **slot** as a small diamond, and "×12" over a flag that twelve units go to;
- **green** to move, **red** to attack or attack-move (and a target ring on the enemy a unit is chasing), **amber** for boarding and landings;
- the click's own ring and radio acknowledgement are kept (ambience.gd).

Test: `tools/order-marks-check.gd`. Pictures: `tools/_order-marks-views.gd`.
