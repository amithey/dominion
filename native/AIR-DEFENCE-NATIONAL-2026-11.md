# National air defence (2026-11-02)

Each nation fields its own ground-based air-defence system (`scripts/air_defence_systems.gd`). The SAM site a nation builds carries that system's name, its chances of stopping each missile class, its reach, its reload and its damage against aircraft. A nation with no battery in service has no SAM site to build (`national_industry.gd`).

The odds are game balance, anchored to the generic SAM site (cruise 75%, ballistic 25%, hypersonic 8%, reach 140 m): raised for modern long-range systems (Patriot, S-400, HQ-9B, SAMP/T, David's Sling), lowered for short-range and older ones (Pantsir, Pechora, Mistral, KN-06). Published results used as anchors are in `modern_warfare.gd` (Patriot against Iskander and Kinzhal, Israel's layers against Iran's ballistic missiles, cruise missiles and drones).

| Nation | System | Cruise | Ballistic | Hypersonic | Reach (m) |
|---|---|---|---|---|---|
| usa | Patriot PAC-3 | 85% | 50% | 10% | 165 |
| china | HQ-9B | 78% | 35% | 10% | 170 |
| russia | S-400 | 80% | 35% | 10% | 185 |
| iran | Bavar-373 and Khordad-15 | 60% | 20% | 5% | 130 |
| india | Akash-NG and S-400 | 75% | 30% | 6% | 160 |
| japan | Patriot PAC-3 and Type 03 | 82% | 50% | 8% | 150 |
| turkiye | Hisar-O and S-400 | 70% | 25% | 6% | 150 |
| israel | Iron Dome and David's Sling | 92% | 60% | 12% | 135 |
| germany | IRIS-T SLM | 95% | 30% | 8% | 120 |
| france | SAMP/T NG | 85% | 50% | 8% | 160 |
| italy | SAMP/T | 80% | 40% | 6% | 155 |
| netherlands | Patriot PAC-3 | 85% | 50% | 10% | 160 |
| uk | Sky Sabre | 90% | 10% | 4% | 110 |
| south_korea | KM-SAM II and Patriot | 82% | 50% | 8% | 150 |
| saudi | Patriot PAC-3 | 75% | 45% | 7% | 160 |
| brazil | Mistral and RBS 70 | 45% | 0% | 0% | 70 |
| indonesia | NASAMS and Starstreak | 60% | 0% | 0% | 100 |
| ukraine | Patriot, IRIS-T and NASAMS | 82% | 25% | 6% | 130 |
| north_korea | KN-06 and S-200 | 45% | 10% | 0% | 120 |
| egypt | S-300VM and HQ-9B | 70% | 30% | 6% | 150 |
| australia | NASAMS | 80% | 5% | 3% | 110 |
| pakistan | HQ-9/P and LY-80 | 65% | 20% | 5% | 140 |
| iraq | Pantsir-S1 | 50% | 0% | 0% | 80 |
| ethiopia | Pantsir-S1 and Pechora-2M | 40% | 0% | 0% | 90 |
| sudan | Pechora-2M | 30% | 0% | 0% | 80 |
| houthis | 358 loitering SAM | 20% | 0% | 0% | 70 |

No SAM site: Afghanistan, Nigeria, South Sudan, Yemen (government), Syria. They rely on fighters, anti-aircraft vehicles and shoulder-launched missiles.
