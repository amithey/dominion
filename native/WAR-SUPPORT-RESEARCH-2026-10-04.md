# The home front: war support, research 2026-10-04

## What the research says

- **Casualties wear support down, democracies most.** The empirical literature on war-weariness finds that support
  falls with the accumulation of human and material losses; democracies show far lower tolerance for casualties
  than autocracies, and their leaders, answerable to the public, are more willing to bargain as a war drags on.
- **A just cause and success soften it.** Experimental work (Gelpi, Feaver and Reifler; the APSR study on the
  multiple effects of casualties) finds the public tolerates losses more when it believes the cause right and
  victory likely; the morality of the cause weighs even more than success.
- **Autocrats are not immune.** "Dictators Cry Too" (Popovic) finds war hurts public support for authoritarian
  leaders as well, if less directly.
- **Being attacked rallies a people** round its government (the rally-round-the-flag effect).
- **In the genre:** Hearts of Iron IV splits stability and war support; war support buffs troops and recruitment,
  and low war support at war caps stability, which governs output.

## In the game (0.9.62), scripts/war_support.gd

| | Democracy | Hybrid regime | Autocracy |
|---|---|---|---|
| Nations | United States, European Union, Japan, Israel, India, United Kingdom, South Korea, Brazil, Indonesia, Australia, Ukraine | Turkiye, Pakistan, Iraq | China, Russia, Iran, North Korea, Saudi Arabia, Egypt, Syria, Afghanistan |
| Support in peace | 60 | 65 | 70 |
| Sensitivity | 1.0 | 0.7 | 0.45 |

- Each minute of war costs about 1.1 points per war x sensitivity (half in a war of defence); a soldier lost 0.25,
  a vehicle 0.5, an aircraft or ship 0.9, a building 0.6, a town 8 (x sensitivity); shortages a little more.
  Drones and hired foreign recruits do not count.
- Being attacked: +12 once per war. A democracy that starts a war unprovoked: -6. Victories: a sixth of the
  enemy's loss per unit, +4 for each enemy town taken. In peace it returns to its level at 1.8 points a minute.
- Levels and effects (the player's as research bonuses, a rival's on its income):

| Level | Support | Effects |
|---|---|---|
| Rallied | 75+ | production +10%, damage +5%, happiness +4 (a rival's income +5%) |
| Steady | 50-75 | none |
| Weary | 30-50 | income -8%, happiness -4 (rival income -8%) |
| Protests | 15-30 | income -15%, production -10%, damage -5%, happiness -8 (rival -15%) |
| Collapse | under 15 | income -25%, production -20%, damage -10%, happiness -12 (rival -25%); a democracy's parliament forces a ceasefire after two minutes |

- A rival below 35 will not start a new war; weary rivals make peace with each other sooner and accept the player's
  peace offers more readily.
- The strip shows war support (a flag), coloured by level, with its effects in the tooltip.

## Sources

- War-weariness (summary of the empirical literature): https://grokipedia.com/page/War-weariness
- "Democracies at War": https://www.academia.edu/85843974/Democracies_at_War
- "Casualty Sensitivity in Wartime: Success Matters, But Less Than A Just Cause": https://arxiv.org/pdf/math/0608034
- "The Multiple Effects of Casualties on Public Support for War", APSR: https://www.cambridge.org/core/journals/american-political-science-review/article/abs/multiple-effects-of-casualties-on-public-support-for-war-an-experimental-approach/89238C8602066D3E42D7BAEFCFEEE0E7
- Popovic, "Dictators Cry Too": https://www.siwps.org/wp-content/uploads/Popovic-Dictators-Cry-Too.pdf
- Hearts of Iron IV developer diary, stability and war support: https://forum.paradoxplaza.com/forum/threads/hoi4-dev-diary-stability-and-war-support.1044766/
