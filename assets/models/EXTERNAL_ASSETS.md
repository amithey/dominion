# External 3D assets

The following game-ready assets are distributed under Creative Commons Zero
(CC0 / Public Domain) by their respective creators:

- Quaternius, **Ultimate Modular Men Pack** — `quaternius-characters/Worker.glb`
  - https://quaternius.com/packs/ultimatemodularcharacters.html
  - https://poly.pizza/bundle/Ultimate-Modular-Men-Pack-ZiH8muWqwQ
- Quaternius, **Toon Shooter Game Kit** — `quaternius-characters/CharacterSoldier.glb`
  - https://poly.pizza/bundle/Toon-Shooter-Game-Kit-qraiSXoAru
- Quaternius, **Downtown City MegaKit (Standard)** — `quaternius-downtown/`
  - https://quaternius.com/packs/downtowncitymegakit.html
- Kenney, **Suburban Houses Pack** — `kenney-suburban/`
  - https://poly.pizza/bundle/Suburban-Houses-Pack-dZQwy8vcDv
- Quaternius, **Farm Buildings Bundle** — `quaternius-farm/`
  - https://poly.pizza/bundle/Farm-Buildings-Bundle-ppbnhEfNEt

The downloaded materials were integrated and, where appropriate, optimized or
restyled for the game's RTS camera and physically based rendering pipeline.

`infantry/` is an unpacked copy of the existing `three/Soldier.glb` character
already distributed with this project (Three.js Soldier example / Mixamo
Vanguard). `scripts/unpack-infantry.cjs` extracts its embedded JPEGs without
changing pixels, geometry or animation. Weapons reuse the existing Quaternius
Toon Shooter kit above.

The missing city and watercraft palettes were restored from Kenney's official
CC0 releases: https://kenney.nl/assets/city-kit-commercial and
https://kenney.nl/assets/watercraft-kit (`Textures/colormap.png` in each pack).
