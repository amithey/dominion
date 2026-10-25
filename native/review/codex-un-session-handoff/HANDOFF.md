# Native UN sessions — final delivery

The user requested actionable UN messages, a separate attended conference and
clear voting choices, plus visual improvements. Source is already applied in
the shared workspace. Do not apply the patch twice.

## Integration order and scope

Integrate the completed VISUAL FINISH handoff, then RESOURCE USE, then this UN
delta. The baseline here is AFTER those two changes and after Claude's 0.9.93
save-test/source-title fixes. Preserve Claude's concurrent work, including war
tools, web changes and AI. This patch does not alter those files or UN rules.

Six files: hud.gd, side_panels.gd, new un_session_screen.gd and its UID, new
tools/un-session-check.gd, and one runner entry. HUD changes instantiate the
session controller, make it a modal input surface, add an entry method and
route UN navigation/U to a pending message. The side panel adds two chamber
entry buttons. All ballot validation, timing, enforcement and saves stay in
un.gd; no save-schema or balance changes.

## Behavior

- A persistent UN invitation with a countdown and an Attend session action;
  the UN navigation also shows a message count. An uncast live ballot has
  priority over an old result or a ballot submitted in the other chamber.
- A separate full-screen Council/Assembly chamber with proposal, subject,
  sponsor, practical effects, voting rules, delegations, timer and fixed ballot.
- Explicit Yes/support, No/oppose, Abstain, formal Veto or statement Objection;
  confirmed choice can change until the authoritative deadline.
- Clear attendance-only explanations for no Council seat, observer status,
  unpaid Assembly dues and mandatory Chapter VI abstention. Consultations
  cannot accept ballots. Expired sessions cannot accept a vote.
- A session transitions to its recorded result. The latest unread decision in
  each chamber remains available even if the player missed the session.
- Return/Escape restores map controls. Campaign time continues and the screen
  explicitly says so. Opening/closing never votes, pauses or spends resources.
- Both chambers remain accessible when sessions overlap; UN affairs & records
  returns to the existing management hub for dues, drafting, lobbying and history.
- Open sessions rebind to authoritative draft dictionaries after JSON restore.
  Assembly activity uses the live chamber pointer, because Assembly drafts
  inherit a vetoed Council record's `result` field before their own vote closes.

The read/unread presentation is session-local; reloading can offer the latest
decision again. All actual ballots and results persist through existing saves.
The notification surfaces the latest decision per chamber; older decisions stay
in the existing UN record. No new real-world claims or date text were added.

## Validation

- New UN_SESSION: 42 checks, headless and default Vulkan graphics PASS.
- Existing UN_CHECK: 68 checks PASS.
- MENUS: 52 checks PASS.
- WINDOWS_PORTRAITS: 66 checks PASS.
- Six graphical captures: native/godot/build/un-session-*.png, including a
  1280x800 conference and compact 1024x720 view. Invitation, Council, Assembly,
  outcome and compact ballot visually inspected; ballot remains on screen.
- Final logs contain no SCRIPT ERROR or shader compile errors.
- Windows preview export exit 0: build/regional-preview/DOMINION.exe.
- Patch reverse dry-run with --ignore-space-change passes (CRLF workspace).

Official distribution/installer was not modified. Please integrate this delta
with the final visual and resource handoffs, run merged/exported checks and
publish the official game update; record receipt and release here. The local
preview includes all three completed changes.
