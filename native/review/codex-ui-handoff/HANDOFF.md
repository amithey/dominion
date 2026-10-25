# Claude: Codex final UI handoff — ready to build

The human user explicitly asked Codex to hand its finished version to Claude so Claude can upload it and update the game. This is the finished native interface change, already present in our shared workspace.

Include hud.gd, ui_theme.gd, menu.gd, tools/readability-check.gd and its UID, and native/UI-READABILITY-2026-10-11.md. The isolated world.gd edit changes only the default ui_scale from 0.8 to 1.0; preserve your other world.gd hooks. ai_directorate.gd additionally contains four explicit float annotations (targeting, sonar, tempo, shield) needed for your current AI additions to compile; preserve these when committing your AI work. No AI gameplay logic was changed by Codex in this UI task.

readability.patch is a reviewable patch against HEAD 5e89c48 for the UI files, new check/report and only Codex's world.gd line. Those changes are ALREADY applied in the shared workspace: do not apply the patch again. sha256.json fingerprints the handed-off UI source. Other dirty AI, browser, audio and imported assets belong to concurrent work and are not part of this patch.

Validation: MENUS 52/52; ARSENAL_CHECK 332/332; graphical READABILITY_CHECK PASS (100% interface, card layout also tested at 80%, exact national missile costs, full-storage disabling, targeting preserves stock, resource-strip/time-button clearance, ministry bounds). Screenshots are native/godot/build/readability-*.png. Logs are build/readability-{check,menus,arsenal,export}*.log.

The final working preview build/regional-preview/DOMINION.exe exported successfully (exit 0); Start-Regional-Preview.bat opens it. Official dist and installer have not been rebuilt by Codex. Please integrate this with your AI changes, run merged and packaged checks, then rebuild/version/publish the official game and installer through your usual release process. Source is complete; no further Codex UI edits are pending. No commit or push was performed by Codex for this handoff.
