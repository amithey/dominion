# Dominion interface

The menu and in-match interface share a midnight-blue, ivory and muted-gold
palette. Serif headings establish hierarchy; sans-serif text carries figures,
controls and descriptions. Colourful nation flags and gameplay status colours
remain distinct from navigation state.

- Main menu: cinematic council-table artwork, a stronger contrast veil, a clear
  primary action and quieter secondary navigation.
- Campaign setup: leader and doctrine on the left; map preview, rules and rival
  selectors on the right. Begin and Back live outside the scrolling body.
- Settings: persistent navigation footer, readable inset setting rows and
  high-contrast selected controls, including from the pause menu.
- Gameplay: a unified command dock with the active screen highlighted; shared
  frames across construction, selection, diplomacy, market and intelligence.
- Research: taller discovery cards with two-line names and brighter locked text.
- National profiles: expandable strengths and weaknesses in the nation picker
  and diplomacy cards, using the gameplay profile module when available.

Run `tools/interface-review.gd` with Godot to inspect all menu tabs and gameplay
panels. It checks campaign/footer bounds, expanded profile layout and active
navigation. With a graphical renderer it also writes `build/interface-*.png`.
The existing `--ui-test`, `tools/map-picker-check.gd` and
`tools/factions-check.gd` cover interaction and campaign selection behavior.
