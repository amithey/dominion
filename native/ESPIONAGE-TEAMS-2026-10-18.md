# Espionage teams (2026-10-18)

**The request (player):** let more than one agent work on an operation or on a nation; of course it raises the exposure.

## Rules (`scripts/espionage.gd`)

- **A team of up to four** on one operation (the *Agents on it* control in Intel > Operations; limited by the agents ready).
- Each extra agent: **+8, +6, +4 points of success** (14 and 18 in total at three and four), **12% shorter preparation** (never below 55%), **+25% of the cost**, **+35% exposure risk**, **+50% intelligence and network gained** on success, and a larger heat penalty.
- On failure **every agent runs the risk of capture by itself** (a little higher in a team): a larger team gets more done and can lose more people. Relations fall by 25, and 10 more for each further agent caught.
- A team is **recalled together**, recovers together, and each member counts the operation.
- **Several operations against one nation at once**, up to three; the same operation cannot run twice against the same nation. (Before, one assignment per nation at a time.)
- Saves keep the team; an older save's mission becomes a team of one.

Test: `tools/espionage-teams-check.gd`. `tools/intel-100.gd` changed one assertion (the old "one assignment per target" rule).
