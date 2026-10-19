# National statistics over time (2026-10-18)

**The request (player):** a graph, for example of GDP, showing the progress of a rival or neighbouring state, like the economic and military figures published in the real world.

**Diplomacy > Statistics** (`scripts/world_stats.gd`, `scripts/stats_view.gd`). Every 20 seconds of game time the statistics office "publishes" every nation's figures:

| Chart | Measure |
|---|---|
| Economy | GDP in billions of dollars: the nation's real starting output (round figures from World Bank and IMF tables) scaled by the output of its finished civil buildings, so it grows as the nation builds and falls when it is bombed |
| Military | the value of the forces under arms, weighted by their health |
| Land | hexes held |
| Technology | level from 0 to 10 |
| Infrastructure | finished buildings |

You see **published** figures, not the truth: land and technology a release behind, GDP rounded, and **military and infrastructure as estimates** whose error is 35% with no intelligence on that nation and 5% with a full network (`espionage.intel`). The error is a fixed draw per nation and release, so a chart does not jitter. Your own figures are exact.

The tab has a metric selector, a chart with a line per nation (yours thicker), and a ranking with the change over the last two minutes, the figure and its error; click *hide* to take a nation's line away. When a published figure of another nation moves by 12% or more in two minutes a headline says so (at most one in two minutes). Series are saved.

Test: `tools/stats-check.gd`.
