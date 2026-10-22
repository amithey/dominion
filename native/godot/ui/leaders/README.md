# Real-leader portraits

## Six regional leaders (11 October 2026)

`yemen-v2.png` (Rashad al-Alimi), `houthis-v2.png` (Abdul-Malik al-Houthi),
`ethiopia-v2.png` (Abiy Ahmed), `nigeria-v2.png` (Bola Tinubu),
`sudan-v2.png` (Abdel Fattah al-Burhan), and `south-sudan-v2.png` (Salva Kiir)
were generated separately with built-in ImageGen to match the existing art.
They are interpretive game illustrations, not official photographs.
Exact prompts and leadership-verification sources: `regional-leaders-prompts.json`.
The six PNGs are preferred automatically over the existing country badges;
the early regional authority labels remain portrait aliases for older saves.
Egypt retains its existing `sisi-v2.png` artwork.

Validation: `tools/regional-portraits-check.gd` checks distinct assets, crop
geometry, HUD badges, identities and legacy aliases. `tools/regional-portrait-gallery.gd`
renders the complete portraits and actual UI crops together for visual review.

## Three remaining leaders (3 October 2026)

`zaidi-v2.png` (Iraq, Ali al-Zaidi), `sharaa-v2.png` (Syria, Ahmed al-Sharaa),
and `akhundzada-v2.png` (Afghanistan, Hibatullah Akhundzada) were separately
generated with built-in ImageGen. Exact prompts: `three-leaders-prompts.json`.
These interpretive game illustrations share the same framing and crop handling;
Akhundzada's public photographic likeness is limited. Emblems remain as fallback.

## Ten additional leaders (3 October 2026)

Ten separate built-in ImageGen illustrations match the original diplomatic-office
style. Exact prompts and identities are in `additional-leaders-prompts.json`.
New portraits: `burnham-v2.png`, `lee-v2.png`, `bin-salman-v2.png`, `lula-v2.png`,
`prabowo-v2.png`, `zelenskyy-v2.png`, `kim-v2.png`, `sisi-v2.png`,
`albanese-v2.png`, and `sharif-v2.png`.

LeaderGallery automatically prefers these PNGs for the faction picker, side-panel
portraits and diplomacy. Existing vector emblems remain as fallback assets.
All images were visually reviewed for identity, composition and matching style.

## Original nine leaders (28 September 2026)

Nine separately generated built-in ImageGen illustrations, used by the playable
faction picker and diplomatic portraits. `*-v2.png` replaces the corresponding
fictional incumbent in new games; these are illustrated game assets, not official
photographs. The full exact prompt set is in `real-leaders-prompts.json`.

- `trump-v2.png`: United States — Donald Trump.
- `xi-v2.png`: China — Xi Jinping.
- `vonderleyen-v2.png`: European Union — Ursula von der Leyen.
- `pezeshkian-v2.png`: Iran — President Masoud Pezeshkian.
- `putin-v2.png`: Russia — Vladimir Putin.
- `modi-v2.png`: India — Narendra Modi.
- `takaichi-v2.png`: Japan — Sanae Takaichi.
- `erdogan-v2.png`: Turkiye — Recep Tayyip Erdogan.
- `netanyahu-v2.png`: Israel — Benjamin Netanyahu.

All use a matching warm diplomatic-office composition with national flags,
upper body and hands at a table. The game crops the face for compact cards.
Role verification sources and gameplay details: `../../../FACTIONS.md`.

## Legacy art

# Original diplomatic leader artwork

Generated with the built-in ImageGen tool on 24 September 2026. All four files
are original fictional characters, not portraits of real politicians. Art is
resolved by leader identity so selecting another playable nation works.
Successor identities retain the procedural 3D fallback rather than incorrectly
showing the previous incumbent.

Prompt set (each generated separately): realistic painterly premium 4X diplomatic
portraits; seated at a polished negotiating table, upper body and hands visible,
cinematic warm light, deep teal ceremonial office, brass accents, vertical 3:4,
no text, logos, watermarks or likeness of real political figures.

- Hale: salt-and-pepper hair, navy suit and blue tie, thoughtful, facing right.
- Volkov: silver hair and grey mustache, charcoal suit and burgundy tie, facing left.
- Moreau: chestnut hair with silver strands, forest-green jacket and ivory blouse, facing right.
- Qadir: dark beard with silver strands, charcoal jacket with restrained gold embroidery, facing left.

The artworks are static illustrations, not lip-synced video or 3D meshes.

## European roster portraits — 2026-10-22
Generated separately with built-in ImageGen, matching the existing diplomatic-office style:
- `macron-v2.png`: France — Emmanuel Macron.
- `merz-v2.png`: Germany — Friedrich Merz.
- `meloni-v2.png`: Italy — Giorgia Meloni.
- `jetten-v2.png`: Netherlands — Rob Jetten.

Illustrative likenesses, not official photographs. Identities follow the game roster.
Prompts: `expansion-leaders-prompts.json`. The existing leader_gallery resolver selects
these PNGs before emblem fallbacks. Existing art and emblems remain available.
Validation: `tools/roster-portraits-check.gd` (374 checks, zero failures across 31 nations),
plus `tools/expansion-portrait-gallery.gd` for full/card/badge visual review.
