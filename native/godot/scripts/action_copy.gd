extends RefCounted
## Short, action-oriented help. Context is taken from the button's own card,
## never from a different screen. Costs and blocking reasons remain authoritative.
const TEXT := {
	"Build":"Open construction choices. Select a building, then choose a legal site on the map.",
	"Cabinet":"Open the national overview: economy, population, army, research and government actions.",
	"Research":"Open the research tree. Choose a discovery to inspect its effects and requirements before queuing it.",
	"Diplomacy":"View relations and contact other nations to negotiate, make agreements or declare war.",
	"Market":"Buy or sell resources immediately, or arrange recurring international trade routes.",
	"Intel":"Manage agents and select intelligence operations, targets, cost and risk.",
	"Defence":"Manage generals, military readiness and nuclear release conditions.",
	"Territory":"Inspect land ownership and settlement districts; manage territory purchases.",
	"Log":"Read earlier messages from this match.", "Menu":"Open the pause menu, settings and save/load controls.",
	"UN":"Read UN invitations, attend Council or Assembly sessions, or manage UN affairs.",
	"New Game":"Configure a new campaign before starting. This does not immediately replace the current match.",
	"Begin campaign":"Start a new campaign using the selected country, map, rivals and rules.",
	"Resume":"Continue the paused campaign.", "Settings":"Change display, sound and interface settings.",
	"Load Game":"Choose a saved campaign to restore.", "Save Game":"Choose a slot and save the current campaign.",
	"Main menu":"Return to the main menu. Save first if you want to keep your current progress.",
	"Quit":"Exit the game. Unsaved progress is lost.", "Back":"Return to the previous screen.",
	"Close":"Close this window and return to the game.",
	"✕":"Close this window and return to the game.", "×":"Close this window and return to the game.",
	"Contact":"Open contact options for this nation, including each channel's fee and response time.",
	"Declare war":"Start a war with this nation. Your forces may attack each other; diplomatic consequences apply.",
	"Authorize operation":"Pay the displayed operation cost and send the selected agent against the chosen target. Success is not guaranteed.",
	"Recall the agent":"Cancel this agent's current mission and bring them back.",
	"End partner funding":"Stop funding the selected proxy partner.",
	"Recruit agent":"Pay the recruitment cost to add one intelligence agent. This does not start a mission.",
	"Close trade route":"Stop this recurring trade route. This closes a commercial agreement, not the window.",
	"Open route":"Start the selected recurring import or export route. Shipments and payments follow the route's schedule.",
	"Assign general":"Give this general command of the selected eligible unit.",
	"Dismiss general":"Remove this general from your command roster.",
	"Appoint general":"Pay the appointment cost to add this general to your command roster.",
	"Go to":"Move the camera to this unit or location; does not order the unit to move.",
	"Raise the alert":"Increase military readiness by one step. Read the production, income and diplomatic effects before escalating.",
	"Stand down":"Lower military readiness by one step and reduce the alert's ongoing effects.",
	"Pay arrears":"Pay your outstanding UN dues from the treasury and restore Assembly voting eligibility when applicable.",
	"Yes":"Vote in favour of the proposal in this chamber.", "No":"Vote against the proposal in this chamber.",
	"Veto":"Cast a permanent Council member's No vote, blocking adoption of this resolution.",
	"Abstain":"Record an abstention. Council abstentions do not lower its Yes threshold; Assembly abstentions are excluded from Yes + No.",
	"Toward yes":"Pay the lobbying cost to move this Council member's leaning one step toward Yes during consultations.",
	"Toward no":"Pay the lobbying cost to move this Council member's leaning one step toward No during consultations.",
	"Join restrictions":"Voluntarily join economic restrictions following this Assembly recommendation.",
	"Leave restrictions":"Withdraw your participation in the voluntary economic restrictions.",
	"Request mediation":"Ask the Secretary-General to seek a negotiated settlement. A request alone does not end the war.",
	"Suspend":"Stop this AI application's operation and ongoing benefits while preserving its completed development.",
	"Pause trials":"Pause local AI validation. Completed trial work is retained.",
	"Resume trials":"Continue local AI validation using compute. This does not yet activate the application.",
	"Open research":"Open the research tree for the discovery this application needs.",
	"Sign":"Sign the agreement described in this card and accept its conditions.",
	"Withdraw":"Withdraw from the agreement described in this card; its diplomatic consequences apply.",
	"Produce weapons":"Show weapons this facility can manufacture. Production spends resources and adds one item to its queue.",
	"Stockpile / target":"Show completed weapons in storage. Choosing one starts target selection; it does not produce a new weapon.",
	"Attack-move":"Choose a destination on the map. Selected units move there and engage suitable targets along the way.",
	"Bombard":"Choose a ground position or infrastructure to fire on with a suitable weapon.",
	"Repair":"Order repairs on a friendly damaged vehicle or completed building. Repairs cost $0.25 per HP and pause in combat.",
	"Buy land":"Select an adjacent unclaimed hex to buy for this settlement. Each hex costs $1000; up to four purchases per settlement.",
	"End this contact":"Finish this diplomatic contact and read the final result.",
	"Skip the guide":"Dismiss the introductory walkthrough and continue playing.",
	"Show first steps":"Show the introductory steps for construction, research and army control.",
	"Pause":"Pause campaign time. Resume to continue production, movement and deadlines.",
	"1x":"Set campaign time to normal speed.", "2x":"Run campaign time at double speed, including production and voting deadlines.",
	"4x":"Run campaign time at four times normal speed, including production and voting deadlines.",
	"Research now":"Queue this discovery. Its three stages develop in order, using research points and each stage's resources when its requirements are met.",
	"Add to queue":"Add this discovery after the current projects. Research goes to the first eligible project; blocked projects wait for their requirements.",
	"Remove from queue":"Remove this discovery from the research queue. This does not remove stages already completed.",
	"Defaults":"Restore the default settings for the options in this screen.",
	"Quit to Main Menu":"Leave the campaign for the main menu. Unsaved progress is lost; a second click confirms.",
	"Quit to Desktop":"Exit the game. Unsaved progress is lost; a second click confirms.",
	"Propose Assembly recommendation":"Submit a separate non-binding recommendation to the Assembly. All eligible members vote; it does not automatically impose Council sanctions.",
	"Read decision":"Open the UN conference result and read the final vote count.",
	"Attend session":"Enter the pending UN conference to read the proposal and cast your ballot if eligible.",
	"Accept":"Accept the offer or consent request described in this card.",
	"Decline":"Reject the offer or consent request described in this card.",
}
const TABS := {
	"Council":"Council seats, draft resolutions, consultations, lobbying and ballots.",
	"Draft":"Choose a proposed UN measure, its subject and the requirements to sponsor it.",
	"Assembly":"General Assembly recommendations and ballots; no permanent-member veto.",
	"Organisation":"UN leadership, membership, dues and voting eligibility.", "Record":"Earlier UN resolutions and recorded outcomes.",
	"Overview":"The current status and key facts for this department.", "Agents":"Recruitment, active agents and their assignments.",
	"Operations":"Choose an intelligence operation and inspect its target, price and risk.",
	"Trade":"Recurring international import and export routes.", "Economy":"Buildings for resources, food, homes and trade.",
	"Military":"Training buildings, military defences and weapon facilities.", "Civic & research":"Education, research and public-service buildings.",
	"Graphics":"Display quality, window and rendering settings.", "Sound":"Music and sound-effect volume controls.",
	"Controls":"Mouse, camera and interface control settings.", "Game":"Campaign preferences and gameplay display options.",
	"Generals":"Appoint commanders and assign them to units.", "Veterans":"Experience and ranks earned by your units.",
	"Nuclear alert":"Military readiness, nuclear release and escalation effects.", "AI":"Compute, applications, autonomy and strategic AI choices.",
	"Arsenal":"Your country's weapon roles, operators and production facilities.",
	"Compute":"AI training progress and the allocation of shared compute.", "Applications":"Validate and activate practical AI programmes, with compute demand and upkeep.",
	"Doctrine":"Human oversight, weapons autonomy and AI agreements.", "AGI":"Advanced AI development, safety work and runaway risk.",
	"Rivals":"Other nations' AI progress and observed activity.",
}

static func context(b: BaseButton) -> String:
	var parts: Array[String] = []
	var parent: Node = b.get_parent()
	for depth in range(4):
		if parent == null or parent is CanvasLayer: break
		for child in parent.get_children():
			if child is Label:
				var words: String = child.text.strip_edges()
				if words.length() > 2 and not words in parts:
					parts.append(words)
		if not parts.is_empty(): break
		parent = parent.get_parent()
	return "\n".join(PackedStringArray(parts)).left(360)

static func meaning(b: BaseButton, original := "") -> String:
	if b.has_meta("action_help"): return str(b.get_meta("action_help"))
	var words: String = b.text.strip_edges() if b is Button else ""
	var ctx := context(b)
	if words == "Resume" and ("compute" in ctx.to_lower() or "Validated" in ctx): return "Restart this commissioned AI application. Its compute demand and running cost resume."
	if words in ["+", "-", "−"]:
		var direction := "Increase" if words == "+" else "Decrease"
		if "safety" in ctx.to_lower(): return direction + " the share of AGI work devoted to safety by 10 percentage points."
		if "Compute allocation" in ctx or "compute" in ctx.to_lower(): return direction + " this pool's compute allocation by 10 percentage points; the available compute remains shared."
		return direction + " the value shown beside this control.\n" + ctx
	if TEXT.has(words): return TEXT[words]
	if words.begins_with("UN ("): return TEXT.UN
	if TABS.has(words) and b.toggle_mode: return "Open this section: " + TABS[words]
	if b is OptionButton: return "Choose a value from this list.\n" + ctx
	if b is CheckButton or b is CheckBox: return "Enable or disable the setting shown beside this switch.\n" + ctx
	for prefix in ["Recruit (", "Recruit agent (", "Ransom ", "Commission ", "Validate ", "Second generation ", "Sell to ", "Consult ", "Buy ", "Sell ", "Jam (", "Anti-satellite missile", "Nuclear detonation in orbit", "Start retraining", "End retraining", "Campaign for a seat", "Arrange food relief", "Send food relief"]:
		if words.begins_with(prefix): return _prefix(prefix)
	if words.begins_with("Enter ") and "chamber" in words: return "Enter this UN conference to read the proposal, voting rules and your delegation's choices."
	if words.begins_with("Return to game"): return "Close this conference and return to the map. Campaign time continues; closing does not cast a ballot."
	if words.begins_with("Close "): return TEXT.Close
	if words.begins_with("Target:"): return "Select this stored weapon, then click the map to launch one. Escape or right click cancels."
	if words.begins_with("Place "): return "Select a legal map location for this building. Placement requires the displayed resources and a valid site."
	if words.begins_with("Open "): return "Open " + words.trim_prefix("Open ").trim_suffix(".") + ".\n" + ctx
	# Existing purpose text is more precise than inferred nearby context. A
	# gate-only tooltip still needs the action description above, when known.
	for gate in ["Needs ", "Research ", "Unavailable", "Requires ", "Not fielded", "Not enough", "Already "]:
		if original.begins_with(gate): return (words + ".\n" if words != "" else "") + ctx
	if original.strip_edges() != "": return ""
	if b.toggle_mode: return "Select " + words + ".\n" + ctx
	return (words + ".\n" if words != "" else "") + ctx

static func _prefix(prefix: String) -> String:
	return {
		"Recruit (":TEXT["Recruit agent"], "Recruit agent (":TEXT["Recruit agent"], "Ransom ":"Pay the displayed ransom to recover this captured agent.",
		"Commission ":"Pay the commissioning cost and activate this validated AI application. It then consumes compute and running funds.",
		"Validate ":"Pay to start local engineering and field trials. Research alone does not activate this application.",
		"Second generation ":"Pay to upgrade this field-tested AI application after meeting its research and experience requirements.",
		"Sell to ":"Export an AI package to this nation for the listed income and diplomatic effects; it also improves their models.",
		"Consult ":"Pay $250 and 40 intelligence reserve for AI-assisted diplomatic consultation. Improves relations; does not force a treaty or ceasefire.",
		"Buy ":"Buy the displayed quantity now: pay money and receive the selected resource, subject to storage and market restrictions.",
		"Sell ":"Sell the displayed quantity now: remove the selected resource from storage and receive money.",
		"Jam (":"Pay to temporarily disrupt this rival satellite.",
		"Anti-satellite missile":"Pay to attack this satellite; the strike has diplomatic consequences.",
		"Nuclear detonation in orbit":"Detonate a nuclear weapon in orbit. It can damage satellites indiscriminately and causes nuclear escalation.",
		"Start retraining":"Fund worker retraining at the displayed ongoing cost to address AI-related unemployment.",
		"End retraining":"Stop funding worker retraining and its ongoing cost.",
		"Campaign for a seat":"Pay $1500 to campaign for an elected Council seat. A campaign does not guarantee election.",
		"Arrange food relief":"Pay $250 logistics for a humanitarian food delivery to your country, subject to the relief cooldown.",
		"Send food relief":"Pay $250 logistics to send humanitarian food relief to this country, subject to the relief cooldown.",
	}.get(prefix, "")

static func tooltip(b: BaseButton, original: String) -> String:
	var help := meaning(b, original)
	var out := original.strip_edges()
	if help != "" and not help in out: out = help + ("\n\n" + out if out != "" else "")
	return wrap_lines(out)

static func wrap_lines(words: String) -> String:
	var lines: Array[String] = []
	for paragraph in words.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			if line.length() + word.length() > 68:
				lines.append(line); line = ""
			line += (" " if line != "" else "") + word
		lines.append(line)
	return "\n".join(PackedStringArray(lines))
