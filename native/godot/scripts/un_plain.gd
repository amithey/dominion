extends RefCounted
## The United Nations in plain words: what each measure is called and what it does, in a line a player can read
## once. The formal names (un.gd MEASURES, "Chapter VI", "Art. 99") stay in the rules; the screens speak this.
const NAMES := {"statement": "Statement", "condemn": "Condemn", "ceasefire": "Call a ceasefire", "peacekeeping": "Send peacekeepers",
	"withdraw": "Order the war to stop", "targeted": "Sanction the leaders", "embargo": "Arms embargo", "icc": "Send to the court",
	"economic": "Full sanctions", "nonproliferation": "Weapons sanctions", "force": "Allow force", "lift": "Lift sanctions"}
const WHAT := {
	"statement": "Words only. Council members like the target a little less.",
	"condemn": "Members like the target less, and so do its own people.",
	"ceasefire": "Asks both sides to stop. It works only if both agree.",
	"peacekeeping": "Observers watch a ceasefire. Both sides must agree.",
	"withdraw": "Stop the war within 2 minutes, or face sanctions.",
	"targeted": "The target earns 10% less for 6 minutes.",
	"embargo": "The target builds 40% less military for 6 minutes.",
	"economic": "The target earns 30% less and loses trade for 6 minutes. Food aid still arrives.",
	"nonproliferation": "An arms embargo and full sanctions together.",
	"icc": "The court investigates. This is not a conviction.",
	"force": "Other nations may join a war on the target for 10 minutes.",
	"lift": "Ends the Council's sanctions on the target.",
}
static func name_of(measure) -> String:
	return str(NAMES.get(str(measure), str(measure)))
static func what(measure) -> String:
	return str(WHAT.get(str(measure), ""))
## Seconds as the shortest honest phrase: "45 s", "3 min".
static func span(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d s" % s if s < 90 else "%d min" % ceili(s / 60.0)
