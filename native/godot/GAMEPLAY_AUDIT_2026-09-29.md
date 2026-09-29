# Gameplay audit — 29 September 2026

Audited source baseline: `48df48a` (0.9.40). These changes are source fixes;
the existing Windows executable/installer has not been rebuilt in this task.

## Reproduced and fixed

1. **Production cancellation refunds the wrong amount.** Iran pays a discounted
   missile cost, but cancellation refunded the full list price. Repeating this
   created resources. Unit refunds also depended on the discount at cancellation
   rather than purchase. Each queued order now retains its actual payment;
   cancellation, completion and save/load keep those receipts aligned. Old saves
   without receipts fall back to the current discounted price.
2. **National powers do not survive save/load correctly.** A fresh load forgot
   sanctions, cooldowns and usage history. Loading in-place could instead retain
   policies from after the save. Saves now replace all policy state and normalize
   nation keys after JSON decoding. Expiration remains tied to saved game time.
3. **Saving during a missile strike changes combat.** In-flight missiles vanished
   on load even though their ammunition had already been spent. Missile trajectories,
   elapsed flight and prior interception attempts now survive. Defender references
   are remapped to recreated entities; launch effects and ammunition expenditure
   are not replayed. EMP and interception/reload timers are also retained.
4. **Fresh loads use the wrong equipment stats.** Units were spawned before loading
   research and rival technology. Upgraded units could return with base maximum
   health, range or speed. Research and AI technology now load first; individual
   equipment stats are saved too, so older units do not silently gain later upgrades.

The focused regression suite initially reproduced seven failing assertions. A
second probe reproduced both player and rival equipment failures. The completed
`tools/gameplay-state-audit.gd` passes 27 checks, including fresh-scene loading,
mixed-price queues, completed orders, policy expiration and legacy save defaults.

## Verification

| Suite | Result |
| --- | --- |
| New gameplay state audit | 27 checks pass |
| Gameplay on all 13 maps | 156 checks pass |
| Faction identity, doctrines and saves | 384 checks pass |
| Gameplay over time | 95 checks pass |
| Existing edge-case bug hunt | 30 checks pass |
| National powers | 55 checks pass |
| National technology availability | 72 checks pass |
| Campaign systems (air, sea, supply, economy, diplomacy) | 35 checks pass |
| Battle dynamics, combat regression, naval construction, economy | Pass |
| Disk saves and combined market/spy/missile/territory persistence | Pass |

The original disk-save test cannot write its normal `user://` slots in this
sandbox. `tools/save-location-check.gd` reruns the same game tests with disposable
slots under `build/audit-saves`, preserving the player's saves. Use `-- --systems`
for the combined systems case. Those reruns passed.

Logs are under `build/audit-*.log`. The engine still prints its existing certificate
store warning, and some older harnesses report resources retained at shutdown.
These are not counted as gameplay failures or silently claimed to be fixed.
