# Diplomatic contacts

Click a foreign completed HQ, City Hall or City Center, or use **Diplomacy → Contact this government**. The contact survives closing the screen. Arrival produces a notice; reopen that government's contact to negotiate. Time follows the running simulation and pauses with the game.

## Channels and outcomes

| Channel | Preparation | Cost | Agenda | Purpose |
| --- | --- | --- | --- | --- |
| Third-party message | 30 seconds | $60 | 2 topics | A mutually non-hostile nation relays messages; otherwise a fictional international secretariat. Extra willingness for peace negotiations. |
| Secure telephone | 5 seconds | $25 | 2 topics | Quick direct contact, including conventional arms licensing. |
| State visit | 60–180 seconds, depending on capital distance | $180 | 4 topics | Requires peace and relations of at least −25. Two original procedural 3D leaders appear at the table, with alternating conversation gestures. Strongest general influence; required for a defence alliance. |

Preparation fees are non-refundable, including cancellation. One contact can be active at once; contacts with the same government have a shared 120-second cooldown after conclusion. A discussion expires five minutes after its scheduled start. A change of either leader or a defeated host interrupts it; war also interrupts a visit.

The offer list includes peace, trade access, configured import/export routes (resource and 10/25/50-unit quantity), non-aggression, military transit, development assistance, conventional arms exports, defence alliance and compensation demands. Read the terms before submitting. These use existing treaties, route capacity, border permissions, treasury and unit systems rather than cosmetic flags.

The response is **accepted**, **rejected**, or a **counteroffer** requiring a $200 government-to-government concession. Declining or leaving a counteroffer unsigned records **no agreement**. Decisions use relations, channel and (for peace/demands) military balance. They are deterministic and saved: reopening cannot reroll a result. A topic can be raised once per contact. Accepted items take effect immediately and are listed in the final communique; rejected/unsigned items do not. This permits partial agreements. Peace does not redraw borders or withdraw armies automatically.

Arms exports require a domestic Tank Factory, sufficient actual tank production resources, +20 relations and a buyer able to pay $800. Exports to an enemy of your ally are refused. One export production slot exists. Materials are deducted and buyer funds escrowed at signature; after 60 seconds a tank is delivered near the buyer's capital and payment released. War or defeat before delivery cancels the order and refunds both parties. This is an abstract production/delivery contract, not a simulated convoy. Selling arms strengthens the buyer's actual army. Compensation requires military superiority, worsens relations by 12 if accepted and by 8 if refused.

Saved data includes travel, agenda, decisions, pending counteroffer, cooldowns, escrowed exports and up to twelve concluded contacts. Older saves start with no contact. Existing low-level diplomacy methods remain compatible with AI and regression callers.

## Research and deliberate abstractions

Sources accessed 23 September 2026. The channel bonuses, thresholds, dollar amounts, agenda limits and compressed seconds are **game balance choices**, not claims about real diplomatic decision-making. The office/leader models are fictional and original. Travel uses capital distance, not an actual transport route. A phone call is presented as a modern secure call, not a claim that the original Washington–Moscow hotline was a voice telephone.

- [UN Guidance for Effective Mediation (2012)](https://peacemaker.un.org/en/documents/united-nations-guidance-effective-mediation) emphasizes consent, preparation and impartiality. In the game, mediation offers a distinct peace channel and uses a non-hostile intermediary; the secretariat fallback is fictional. This does not model the entire UN process.
- [US Office of the Historian: direct communications link, 1963](https://history.state.gov/historicaldocuments/frus1961-63v05/d333) describes rapid crisis communication as a way to reduce war risk. This informs the faster direct-contact option, while a message alone never guarantees agreement.
- [US Office of the Historian: Camp David Accords](https://history.state.gov/milestones/1977-1980/camp-david) describes consent to the summit, extended negotiations, separate mediated exchanges and frameworks preceding a formal peace treaty. This informs preparation, multiple agenda items, counteroffers and partial outcomes. The game's immediate peace flag compresses subsequent treaty implementation.
- [European Council: EU–Canada summit outcome documents, 23 June 2025](https://www.consilium.europa.eu/en/press/press-releases/2025/06/23/eu-canada-summit-outcome-documents/) illustrates a joint statement and security partnership across economic and security priorities. This informs a broad summit agenda and an itemized concluding communique.

## Development and verification

`scripts/diplomatic_contacts.gd` owns state and mutations; `diplomatic_screen.gd` presents it; `summit_stage.gd` renders a small independent 3D room. `diplomacy.gd` owns the service; `save.gd` persists it. HUD intercepts completed foreign civic buildings; engine picking is unchanged.

Run `Godot --headless --path native/godot --script res://tools/diplomatic-contacts-check.gd`. Add `-- --capture-contacts` without `--headless` to capture the summit and communique to the ignored build folder. The suite is registered in `native/run-tests.ps1`.
