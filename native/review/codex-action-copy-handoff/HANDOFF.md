# Action wording and weapon explanations — final delivery

User request: every button and missile should clearly and concisely say what it
means and what it does. Source is already applied; do not apply the patch twice.

## Integration

Apply after VISUAL FINISH, RESOURCE USE and UN SESSION. Baseline snapshots here
are AFTER those completed changes, with Claude's war-tools work present. The
patch isolates this wording change and preserves the existing 0.9.94 gameplay,
AI, save and web work. Official distribution/installer was not modified.

Changed: HUD, side panels, menu and tooltip font size; one existing readability
assertion follows the more explicit targeting label; one new runner entry.
New: action_copy.gd (semantic help), button_hints.gd (coverage/lifecycle),
weapon_copy.gd (shared weapon explanations), action-copy-check.gd and their UIDs.

## What changed

- Buttons across the native UI receive concise help on hover/focus, including
  buttons created later by menus, diplomatic conversations, AI and UN screens.
  Common actions have written explanations; existing curated descriptions are
  retained. Other controls use their own setting/card context. Original costs,
  requirements and dynamic blocking reasons survive alongside the explanation.
- Help never invokes a button's click callback. Repeated hover does not duplicate
  text. Missing construction/production resources appear in the explanation
  and clear when affordable. Tooltip text wraps and uses a readable 15px font.
- Clear action labels: Recruit agent, Close trade route, Assign general,
  Appoint general and Dismiss general. Closing a route is explicitly distinguished
  from closing a window. Campaign-country and save-load choices have direct help.
- AI allocation and safety +/- controls disclose their 10-percentage-point step;
  resuming an AI application explains compute/upkeep rather than resuming a game.
- UN draft/amend controls describe the actual proposed effect and clarify that
  submission/amendment precedes adoption and enforcement.
- Weapon production, stockpile and naval targeting share one explanation of
  role, compatible platform, impact/effect area and key consequence. Production
  says it queues ONE weapon into storage; targeting says the map click launches
  ONE stored weapon, and how to cancel. Friendly damage and escalation are stated.
- Same national-family names are distinguished by tactical/ballistic/cruise/
  anti-ship etc. in card titles. EMP/HEMP explicitly have no blast damage.
- Visible damage is the game's base centre impact (definition dmg * 1.75), before
  target modifiers/defences, rather than the previous raw catalogue number.
  Help explains falloff and interception. Numbers are game mechanics, not
  real-world performance claims. No balance or gameplay rule was changed.
- Unit/building descriptions are no longer clipped to two visible lines;
  production cards resize to fit. Missile role distinctions include anti-ship,
  anti-unit, bunker penetration, radar suppression, EMP, nuclear and hazardous
  payloads. Future/assessed programme status remains disclosed.

## Evidence

- ACTION_COPY: 102 checks PASS in headless and default Vulkan/Forward+ graphics.
  Audits all visible buttons in 37 native screen/tab views and all 30 payload
  definitions installed in the campaign, including national variants.
  Exercises real production (one queued item), targeting (inventory retained),
  unchanged state on hover, late-created buttons, dynamic gate text, affordability,
  repeated help and different national-family variants.
- READABILITY_CHECK PASS, including card fit and 80% UI scale.
- MENUS: 52 PASS; RESEARCH_100: 101 PASS; UN_SESSION: 42 PASS.
  Total counted checks: 297, plus the readability assertions.
- Three captures under native/godot/build/action-copy-*.png: production,
  actual native weapon tooltip and stockpile; visually inspected at 1280x800.
- Button wording audit: native/godot/build/action-copy-audit.txt (37 views).
- No SCRIPT ERROR/parse errors in final verification logs.
- Native Windows preview export exit 0: build/regional-preview/DOMINION.exe.
- Isolated patch reverse dry-run passes with --ignore-space-change (CRLF).

Please integrate this delta after the prior final handoffs, run the merged and
exported checks, and publish the official game/installer. Record receipt and
publication in COORDINATION.md. No further Codex wording changes are pending.
