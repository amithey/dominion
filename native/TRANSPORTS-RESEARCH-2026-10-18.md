# Troop transports: landing ships and a loading that works (2026-10-18)

**The report (player):** loading troops onto transports and putting them ashore does not work, and ships should carry troops.

## What was wrong

- Only helicopters could carry troops, and nothing could carry them by sea: there was **no landing ship**.
- A helicopter took the whole selection to its position in one formation. The rear ranks stopped short of the 9 m boarding reach and never boarded.
- Unloading was a hidden key (J) with no button, and no way to say *where* to land.

## What it is now (0.9.99)

| | |
|---|---|
| **Amphibious Landing Ship** (new, shipyard, Naval Engineering) | 36 places. A soldier or an engineer takes one place; a vehicle takes its army capacity (2 to 6). Armed only for self-defence. Named by nation (San Antonio-class, Albion-class, Mistral-class, Type 071, Ivan Gren-class, Osumi-class, Dokdo-class and others); not issued to nations without one. |
| **Loading** | Select troops and right-click the transport, or press **Board the ...** on the unit card. Each unit walks to the meeting point on its own. A ship already at a shore stays; a ship at sea sails to the water nearest the troops first, and the troops wait on the shore for it. |
| **Putting ashore** | **Unload (J)** or the button: a ship at a coast lands everyone on the nearest dry ground; a ship out at sea (or a helicopter over water) goes to the nearest place where it can and unloads on arrival. **Land at...** takes a chosen place on the map: the ship stands off the beach there. |
| **The card** | The selected transport shows what is aboard ("Aboard 14 of 36 places: ...") and the buttons. |
| **Losses** | A transport that sinks takes everyone aboard with it. Saves keep the cargo. |

## Capacities (game scale)

The ship's 36 places stand for a large amphibious ship's company of marines and vehicles. Reference figures from open sources:

- Type 071: 600 to 800 troops, up to about 20 armoured vehicles (https://en.wikipedia.org/wiki/Type_071_amphibious_transport_dock).
- Ivan Gren class: about 300 troops and 13 tanks or 36 to 40 armoured vehicles (https://en.wikipedia.org/wiki/Ivan_Gren-class_landing_ship).
- The San Antonio, Mistral and Albion figures were not confirmed by the searches; the game's number is a balance figure, not a specification.

## Test

`tools/transports-check.gd`: real movement (troops walk, a ship sails, they board, are landed from the coast and from open water, the helicopter takes a crowd), places by unit, the model, the role, the loss with the ship, the save round trip.
