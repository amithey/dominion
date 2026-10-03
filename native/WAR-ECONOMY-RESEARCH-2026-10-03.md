# Operational war costs: research and implementation

## Evidence

- [US Army Safety, Spring 2021](https://safety.army.mil/Portals/0/Documents/MEDIA/RISKMANAGEMENTMAGAZINE/Standard/RM_Spring_2021.pdf): Abrams fuel consumption varies with terrain and operating state; it reports 1.67 gallons per mile cross-country and 10 gallons per hour at idle. This establishes a recurring mobility cost; it is not a conversion factor for the game's oil.
- [Army sustainment doctrine overview](https://www.army.mil/article/282480/operations_change_the_armys_approach_to_sustainment): high-intensity operations increase consumption of fuel, ammunition and repair parts. Buying a platform does not fund its subsequent combat.
- [Army contested logistics programme](https://www.army.mil/article/284116/army_futures_commands_contested_logistics_cross_functional_team_transforming_for_future_sustainment): sustainment must deliver consumables and support readiness across land, sea and air.
- [FY2026 Army missile procurement budget](https://www.asafm.army.mil/Portals/72/Documents/BudgetMaterial/2026/Discretionary%20Budget/Procurement/Missile%20Procurement%20Army.pdf): interceptor programmes purchase missiles as well as supporting equipment and services. Programme totals are not treated as the price of a single round.
- [Royal Navy DragonFire trials](https://www.royalnavy.mod.uk/news/2025/november/20/20251120-dragonfire-trials): reported marginal laser firing cost is £10, compared with over £1m for a Sea Viper missile. This supports cheaper marginal energy-weapon shots; equipment, cooling and power infrastructure are separate costs.

## Translation into DOMINION

All numerical prices below are **game balance**, not real dollars, litres or exchange rates. The research informs which actions consume resources and the relative price hierarchy. A shared module, scripts/war_costs.gd, handles atomic payments for player and rival nations.

New games receive an initial 60-oil operational reserve for their starting garrison.
The previous zero-oil opening assumed free movement; retaining it would strand
the starting armour before the player could establish fuel production.

| Action | Game cost |
|---|---:|
| Tank travel | 3.5 oil per 100 map metres |
| APC / AA vehicle travel | 1.8 oil per 100 metres |
| Other motorised ground travel | 2.5 oil per 100 metres |
| Conventional warship travel | 4.5 oil per 100 metres |
| Tank shell | $1.20 |
| APC / AA cannon burst | $0.25 |
| Infantry firing burst | $0.08 |
| Artillery shell / MLRS six-rocket salvo | $2 / $6 |
| Guided salvo / BrahMos / hypersonic attack | $8 / $12 / $14 |
| SAM / IRIS-T defensive attempt | $5 / $6 |
| ABM / THAAD defensive attempt | $18 |
| Aegis / Type 45 defensive attempt | $12 / $10 |
| Laser or microwave engagement | $0.35 |
| Active-protection attempt | $0.75 |
| Aircraft sortie fuel | 4–12 oil, up to 90 seconds before returning |

Bomb sticks, helicopter rocket bursts, FPVs, torpedoes and other weapons have corresponding salvo prices in the module. Every repeated firing action is paid once before the projectile or beam appears, regardless of a miss, jamming or interception. A tank firing twenty rounds spends $24. Six tanks travelling 200 metres consume 42 oil; production and oil purchases now matter to campaigning.

Defence charges are made before rolling interception success. Without funding, the launcher cannot engage, no phantom projectile or cooldown is created, and the incoming missile can be engaged later if money becomes available. Golden Dome retains its existing $150 charge, through the same accounting path.

Only actual accepted powered displacement is charged. Blocked paths, stationary units, knocked-back wrecks, and infantry walking consume no oil. Dry tanks retain their orders and resume when fuel becomes available. Conventional ships stop if their next step cannot be funded. Nuclear submarines and battery/expendable sea drones do not consume the oil pool.

Aircraft prepay fuel before taxiing out; the first airborne starting-garrison load is part of initial equipment. Crewed aircraft and reusable drones return when their sortie endurance expires or ammunition is spent. They remain grounded when the next sortie cannot be funded. Return/landing uses the reserved fuel margin, preventing a treasury shortage from freezing a plane in mid-air. Existing one-way drone purchase and endurance rules remain; the expendable vehicle is not charged again as ammunition.

The existing military food consumption, repair fees and strategic missile production bills remain in place. This change does not charge stored strategic missiles a second time on launch. Oil abstracts refined operational fuel; ammunition purchases are automatic from the national treasury, rather than a new magazine-management interface. National shortages affect execution, not hit probabilities or weapon damage.

Rival economies already price oil at three money per oil unit (AI.price); operating movement and sortie fuel use that same conversion. Both sides pay identical ammunition/interception prices. No rival may overdraw its budget.

## Player information, persistence and boundaries

The World market shows cumulative military cash/fuel spending, firing/defensive attempt counts, and the operating rules with a cost tooltip. Resource flow displays subtract recent operating consumption from income, while the actual event deduction happens only once. Shortage messages are limited per reason to avoid flooding the HUD.

Spending totals and aircraft endurance survive JSON saves. Old saves default to zero spending history and an initial 90-second airborne fuel load. Existing aircraft rearming and supply-base requirements still apply.

Physical ammunition convoys, per-platform ammunition magazines and idle-engine fuel consumption are intentionally abstracted in this iteration. It adds the requested economic tradeoffs without forcing the player to manually refuel each vehicle. Real costs vary by platform, ammunition type, contracts and logistics conditions; this is an evidence-informed game model.

## Verification

Dedicated war-cost checks cover atomic/exact-boundary payments, failed launches, no overdrafts, distance/frame partition invariance, real tank firing and movement, real interception attempts and resupply recovery, grounded/paid aircraft departures, fuel endurance, no double charging, player/rival symmetry and save/legacy compatibility.
Additional existing economy, save, modern-weapons, UI and live-combat regressions are run before committing. Results are recorded in the coordination note.

The existing battle/motion/air-sea fixtures spawn synthetic armies and do not
simulate their normal supply economy. They now explicitly provision both sides
so a resource shortage is not reported as a physics failure. The dedicated new
checks independently verify that unfunded live units and launchers cannot act.
