extends RefCounted
## Short, action-oriented help. Context is taken from the button's own card,
## never from a different screen. Costs and blocking reasons remain authoritative.
const TEXT := {
	"Build":"Choose a building, then a site on the map.",
	"Cabinet":"Your nation at a glance: economy, people, army, research.",
	"Research":"Open the research tree.",
	"Diplomacy":"Talk to other nations, sign deals or declare war.",
	"Market":"Buy and sell resources, or set up trade routes.",
	"Intel":"Agents, operations and what you know about rivals.",
	"Defence":"Generals, alert level and nuclear weapons.",
	"Territory":"Your land and its borders. Buy more land here.",
	"Log":"Earlier messages from this match.", "Menu":"Pause, settings, save and load.",
	"UN":"UN votes, invitations and affairs.",
	"New Game":"Set up a new campaign. Your current match stays until you begin.",
	"Begin campaign":"Start with the nation, map and rules you picked.",
	"Resume":"Back to the game.", "Settings":"Display, sound and controls.",
	"Load Game":"Pick a saved campaign.", "Save Game":"Pick a slot and save.",
	"Main menu":"Back to the main menu. Save first to keep your progress.",
	"Quit":"Exit the game. Unsaved progress is lost.", "Back":"Go back to the previous screen.",
	"Close":"Close this window.",
	"✕":"Close this window.", "×":"Close this window.",
	"Contact":"Ways to contact this nation, with price and speed.",
	"Declare war":"Start a war. Your forces may fight, and others will react.",
	"Authorize operation":"Pay the cost and send the agent. It can fail.",
	"Recall the agent":"End the mission and bring the agent home.",
	"End partner funding":"Stop funding this partner.",
	"Recruit agent":"Pay to hire one agent. No mission starts.",
	"Close trade route":"End this trade route.",
	"Open route":"Start this trade route. Goods and money follow its schedule.",
	"Assign general":"Put this general in command of the selected unit.",
	"Dismiss general":"Remove this general.",
	"Appoint general":"Pay to add this general to your staff.",
	"Go to":"Move the camera here. The unit does not move.",
	"Raise the alert":"One step higher. Check the costs first.",
	"Stand down":"One step lower. The alert's effects ease.",
	"Pay arrears":"Pay your UN dues and get your Assembly vote back.",
	"Yes":"Vote for it.", "No":"Vote against it.",
	"Veto":"Vote No as a permanent member: it cannot pass.",
	"Abstain":"Do not vote either way.",
	"Toward yes":"Pay to move this member one step toward Yes.",
	"Toward no":"Pay to move this member one step toward No.",
	"Join restrictions":"Join the recommended economic limits.",
	"Leave restrictions":"Stop taking part in the economic limits.",
	"Request mediation":"Ask the Secretary-General to help. It does not end the war by itself.",
	"Suspend":"Switch this AI application off. Its progress is kept.",
	"Pause trials":"Pause the trials. Progress is kept.",
	"Resume trials":"Continue the trials. It does not switch the application on.",
	"Open research":"Open the research this application needs.",
	"Sign":"Sign this agreement and accept its terms.",
	"Withdraw":"Leave this agreement. Others will notice.",
	"Produce weapons":"See what this site can build. Building costs resources.",
	"Stockpile / target":"See stored weapons. Pick one to aim it.",
	"Attack-move":"Pick a spot. Units go there and fight what they meet.",
	"Bombard":"Pick a spot to fire on.",
	"Repair":"Repair a damaged vehicle or building. $0.25 per HP, stops in combat.",
	"Buy land":"Buy a neighbouring hex: $1000 each, up to four per settlement.",
	"End this contact":"Finish this contact and see the result.",
	"Skip the guide":"Close the introduction.",
	"Show first steps":"Show the first steps again.",
	"Pause":"Pause the game.",
	"1x":"Normal speed.", "2x":"Double speed.",
	"4x":"Four times speed.",
	"Research now":"Start this discovery. Its three stages run in order.",
	"Add to queue":"Add it after the current projects.",
	"Remove from queue":"Take it off the queue. Finished stages stay.",
	"Defaults":"Reset the options on this screen.",
	"Quit to Main Menu":"Leave the campaign. Unsaved progress is lost. Click twice to confirm.",
	"Quit to Desktop":"Exit the game. Unsaved progress is lost. Click twice to confirm.",
	"Propose Assembly recommendation":"Put a non-binding recommendation to all members.",
	"Read decision":"See how the vote ended.",
	"Attend session":"Go to the vote and cast yours.",
	"Accept":"Accept this offer.",
	"Decline":"Turn this offer down.",
}
const TABS := {
	"Vote now":"The Council vote: who votes how, and your vote.",
	"Propose":"Pick a country and a measure, and put it to the Council.",
	"Assembly":"Assembly votes. No veto.",
	"Dues & members":"Membership, elections, your dues and treaties.", "History":"Earlier UN votes and results.",
	"Overview":"Status and key facts.", "Agents":"Hire agents and give them missions.",
	"Operations":"Pick an operation; see its target, price and risk.",
	"Trade":"Trade routes.", "Economy":"Resources, food, homes and trade.",
	"Military":"Training, defences and weapon sites.", "Civic & research":"Schools, research and public services.",
	"Graphics":"Quality and window.", "Sound":"Music and effects volume.",
	"Controls":"Mouse, camera and interface.", "Game":"Campaign options.",
	"Generals":"Appoint commanders and give them units.", "Veterans":"Ranks your units have earned.",
	"Nuclear alert":"Readiness and nuclear release.", "AI":"Compute, applications and AI choices.",
	"Arsenal":"Your weapons and where they are made.",
	"Compute":"AI training and shared compute.", "Applications":"Test and start AI programmes.",
	"Programmes":"Test and start AI programmes.", "Rules":"Human control, autonomy and AI treaties.",
	"AGI race":"Advanced AI, safety and risk.",
	"Doctrine":"Human control, autonomy and AI treaties.", "AGI":"Advanced AI, safety and risk.",
	"Rivals":"What other nations are doing with AI.",
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
	return "\n".join(PackedStringArray(parts)).left(70)

## What a button does when nothing says so: its own name and the nearest label, on one short line.
static func _with_context(words: String, ctx: String) -> String:
	var near := ctx.replace("
", " · ")
	return (words + ". " if words != "" else "") + near

static func meaning(b: BaseButton, original := "") -> String:
	if b.has_meta("action_help"): return str(b.get_meta("action_help"))
	var words: String = b.text.strip_edges() if b is Button else ""
	var ctx := context(b)
	if words == "Resume" and ("compute" in ctx.to_lower() or "Validated" in ctx): return "Switch this AI application back on. It uses compute and money again."
	if words in ["+", "-", "−"]:
		var direction := "Increase" if words == "+" else "Decrease"
		if "safety" in ctx.to_lower(): return direction + " the share of work on safety by 10 points."
		if "Compute allocation" in ctx or "compute" in ctx.to_lower(): return direction + " this pool's compute by 10 points."
		return direction + " the value."
	if TEXT.has(words): return TEXT[words]
	if words.begins_with("UN ("): return TEXT.UN
	if TABS.has(words) and b.toggle_mode: return TABS[words]
	if b is OptionButton: return "Choose from the list."
	if b is CheckButton or b is CheckBox: return "Turn this on or off."
	for prefix in ["Recruit (", "Recruit agent (", "Ransom ", "Commission ", "Validate ", "Second generation ", "Sell to ", "Consult ", "Buy ", "Sell ", "Jam (", "Anti-satellite missile", "Nuclear detonation in orbit", "Start retraining", "End retraining", "Campaign for a seat", "Arrange food relief", "Send food relief"]:
		if words.begins_with(prefix): return _prefix(prefix)
	if words.begins_with("Enter ") and "chamber" in words: return "Go into this chamber to see the vote and cast yours."
	if words.begins_with("Return to game"): return "Back to the map. The game keeps running. You have not voted."
	if words.begins_with("Close "): return TEXT.Close
	if words.begins_with("Target:"): return "Pick it, then click the map to launch one. Esc cancels."
	if words.begins_with("Place "): return "Pick a site on the map. You need the resources shown."
	if words.begins_with("Open "): return "Open " + words.trim_prefix("Open ").trim_suffix(".") + "."
	# Existing purpose text is more precise than inferred nearby context. A
	# gate-only tooltip still needs the action description above, when known.
	for gate in ["Needs ", "Research ", "Unavailable", "Requires ", "Not fielded", "Not enough", "Already "]:
		if original.begins_with(gate): return _with_context(words, ctx)
	if original.strip_edges() != "": return ""
	if b.toggle_mode: return _with_context("Select " + words, ctx)
	return _with_context(words, ctx)

static func _prefix(prefix: String) -> String:
	return {
		"Recruit (":TEXT["Recruit agent"], "Recruit agent (":TEXT["Recruit agent"], "Ransom ":"Pay the ransom to get this agent back.",
		"Commission ":"Pay to start this tested AI application. It then uses compute and money.",
		"Validate ":"Pay to test it first. Research alone does not start it.",
		"Second generation ":"Pay to upgrade this tested application.",
		"Sell to ":"Sell an AI package to this nation for income. It improves their models.",
		"Consult ":"$250 and 40 intelligence: better relations. It does not force a deal.",
		"Buy ":"Buy this amount now, if you have storage.",
		"Sell ":"Sell this amount now for money.",
		"Jam (":"Pay to disrupt this satellite for a while.",
		"Anti-satellite missile":"Pay to destroy this satellite. The world will react.",
		"Nuclear detonation in orbit":"Blow up a nuclear weapon in orbit. It hits satellites and raises the nuclear alert.",
		"Start retraining":"Pay to retrain workers who lost jobs to AI.",
		"End retraining":"Stop paying for retraining.",
		"Campaign for a seat":"$1500 for a chance at a Council seat.",
		"Arrange food relief":"$250 for a food delivery to you. Cooldown applies.",
		"Send food relief":"$250 to send food here. Cooldown applies.",
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
