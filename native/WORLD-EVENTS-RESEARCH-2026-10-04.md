# World events with causes: research, 2026-10-04

The player asked for world events that are not random: each one caused by what the nations do, and felt across the
world (Iran closing the Strait of Hormuz, for example). scripts/world_events.gd checks every 5 s what the wars and
blockades in the match have caused; an event lasts while its cause lasts and 45 s more, moves the world market
(a jump at once, then the fair price held up while it lasts) and every nation's income by its exposure.

## The events

| Event | Its cause in the game | The record | Who pays, who gains (income) |
|---|---|---|---|
| The Strait of Hormuz is closed | Iran at war with the United States, Israel or Saudi Arabia, or Iran's own "Close the Strait" power | About 20% of the world's oil and 20% of its LNG pass the strait; 69% of that oil goes to China, India, Japan and South Korea. It was effectively closed from late February 2026 after the US-Israeli strikes on Iran; Brent passed $100 and the IEA called it the largest supply shock in history; Asian LNG prices more than doubled. | Oil +80%, gas +60%. Saudi Arabia and Iraq -25% (no outlet), Iran -15%, Japan and South Korea -12%, India -10%, China and Pakistan -8%, Europe -5%; Russia +8%, the United States and Brazil +4%, Australia +3%. Happiness down in Japan, South Korea, India. |
| Black Sea grain stops | Russia or Ukraine at war | Russia and Ukraine grow about a third of the world's wheat; Ukraine's sea exports stopped in February 2022 and wheat rose 58% (grains 34%); the Black Sea Grain Initiative later eased it. | Food +50%. Egypt -8% (and unrest), Syria -5%, Pakistan and Iraq -4%, Indonesia -3%; Brazil +5%, Australia +4%, the United States +3%. |
| Europe's gas crisis | Russia at war with Europe, the UK or Ukraine, or Russia cutting Europe's gas (its power) | Russia sent the EU 70 bcm less gas in 2022 than in 2021 (of 150); wholesale gas passed 300 EUR/MWh in August 2022. | Gas +100%. Europe -10%, the UK -5%, Turkiye -3%, Russia -4% (lost buyers); the United States +5% (LNG), Australia +3%. |
| Rare-earth shock | China at war with the United States, Japan, Europe, India, South Korea, the UK or Australia, or China's export controls in force | China mines about 70% of the world's rare earths and refines about 90%; its export controls of April and October 2025 hit chip and magnet makers. | Silicon +70%. Research -10% in Japan and South Korea, -8% in the United States and Europe, -5% in India and the UK; small income losses there; China +3%, Australia +4%. |
| Global recession | Two of the five largest economies (the United States, China, Europe, Japan, India) at war with each other | A war between the largest trading partners breaks the trade that binds them. | Every nation -6%; oil and iron -20%, silicon -10% (less demand). |
| Arms boom | Three wars being fought at once | Wartime demand fills the order books of the arms exporters (the United States, Russia, Europe, Israel, South Korea, Turkiye, China). | Those exporters +2% to +4%; iron +15%. |
| Refugees | A town (village, city or capital) destroyed | People flee war to the nearest safe neighbours. | The two nearest nations take in 20-60 people each for 4 minutes; the player gains citizens but loses 3 happiness. |

Events add up: a war of the United States against China and Iran at once closes Hormuz, starts a recession and a
rare-earth shock. Each is announced in the news feed with its cause and its effect on the player, and the Cabinet's
"World News" tile lists those in force.

## Sources

- Hormuz: Brookings, "From chokepoint to crisis: The Strait of Hormuz and global oil markets"; CNBC, 3 March 2026,
  "The Strait of Hormuz is facing a blockade. These countries will be most impacted"; US EIA, "International LNG
  prices rise amid Strait of Hormuz closure"; Oxford Institute for Energy Studies, "Closing the Strait of Hormuz:
  impact on the global gas market"; Congressional Research Service R45281; Kpler.
- Grain: Choices Magazine, "Russia-Ukraine Conflict and the Global Food Grain Price Analysis"; Nature
  Communications Earth & Environment (2024) on stabilising wheat prices; Wikipedia, Black Sea Grain Initiative.
- Gas: European Commission quarterly gas market reports (Q3 2022); CNBC, 22 August 2022, Nord Stream 1 shutdown;
  Brookings, "Europe's messy Russian gas divorce".
- Rare earths: China's export controls of April and October 2025 (native/godot/scripts/faction_powers.gd).
