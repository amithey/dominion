# DOMINION desktop engine evaluation

The chosen product target is an installed PC game, with Steam as a future goal.
This separate Godot prototype evaluates native rendering and navigation before
committing to a full migration. It is not the complete game or a release build.

## Launch on this computer

Double-click `Start-Desktop.cmd`. It copies existing repository assets, imports
them, and launches the portable Godot runtime from `.local-tools/godot`.
No web server is required. The engine and generated asset copies are ignored by Git.

On another computer, download Godot 4.7.2 from
https://godotengine.org/download/windows/, run `prepare-desktop.ps1`, then open
`godot/project.godot` in the editor and press F6 with main.tscn open (or F5).
Godot is MIT licensed: https://godotengine.org/license/.

## Controls and scope

- Click or drag to select; Shift adds to selection. Right-click orders movement.
- WASD pans, Q/E rotates, and the mouse wheel zooms.
- Select army selects all units; Add 24 units increases the scene to at most 96.
- Three hex districts reuse existing Kenney models. Soldiers reuse the existing
  Quaternius model, with idle/run animation blending and smooth turning.
- Navigation routes around districts; the short roads are visual only.
- The HUD samples FPS and frame p95 over two-second windows, including startup.
  These samples are not a controlled benchmark against the browser game.

Compatibility rendering is the initial baseline. Visual assets remain stylized;
realistic art, combat, economy, logistics, saving, collision avoidance, Steam
integration and standalone export packaging are not implemented here.

## Validation

Run the Godot executable with:

```text
--headless --path native/godot -- --smoke-test
--path native/godot -- --capture-preview
```

The smoke test requires 24 models, a route around a district, and actual unit
movement. The graphical command saves `godot/build/preview.png` and exits.
The preview was rendered on Intel Iris Xe; this does not establish full-game
performance. Interactive input still needs user playtesting.

Assets are copied from the repository's Kenney city/suburban, Quaternius character,
and terrain folders. Preserve their original credits and notices; complete the
per-asset license audit before distribution. No new third-party art was acquired.

Next gate: one polished district and a small combat encounter, validated at
1080p with repeatable 24/48/96-unit measurements before deciding on full migration.
