extends RefCounted
## Who uses AI for what: the documented record behind the strategic applications
## (ai_applications_data.gd: targeting, counterDrone, undersea, surveillance,
## infoShield, revenue, export, deadHand, biosecurity) and the synthetic
## influence operations of ai_directorate.gd. Research, sources and the limits
## of the public record: native/AI-STRATEGIC-USE-RESEARCH-2026-10-11.md.
##
## A status per nation and domain:
##   fielded     documented use: validation needs half the compute, and a rival
##               that has it puts it first
##   developing  documented programmes or trials: validation needs 80%
##   barred      the nation's own law forbids it: it cannot be commissioned
##   (absent)    no public evidence; it may still be developed, at full cost
## A pledge (the nuclear declaration, ai_data.gd "signs") is not a bar: a nation
## that withdraws from it may automate retaliation, at the price of withdrawing.
## Text shown in the game names no years or events; the dates are in the doc.

const DOMAINS := ["targeting", "counterDrone", "undersea", "surveillance", "infoShield", "influence", "revenue", "export", "deadHand", "biosecurity"]
const DOMAIN_NAMES := {"targeting": "Targeting support", "counterDrone": "Counter-drone", "undersea": "Undersea sensing",
	"surveillance": "Mass surveillance", "infoShield": "Counter-disinformation", "influence": "Synthetic influence operations",
	"revenue": "Tax and fraud analytics", "export": "AI exports", "deadHand": "Automated retaliation", "biosecurity": "Biosecurity screening"}
const WORK := {"fielded": 0.5, "developing": 0.8}

const USE := {
	"usa": {
		"targeting": ["fielded", "A national targeting decision-support system fuses sensor data for commanders and is shared with allies."],
		"counterDrone": ["fielded", "A drone-mass programme's second line of effort is countering small drones."],
		"undersea": ["developing", "Autonomous undersea vehicles and AI sonar processing; experts judge the gains evolutionary."],
		"surveillance": ["developing", "Police use of facial recognition is local and contested; no national system."],
		"infoShield": ["developing", "Platform takedowns of foreign influence operations; government efforts have shrunk."],
		"influence": ["developing", "Military information operations exist; no documented AI deepfake campaign by the state."],
		"revenue": ["fielded", "The tax service uses machine learning to select audits."],
		"export": ["fielded", "A national programme exports full American AI packages to partners: chips, cloud, models."],
		"deadHand": ["pledged", "Declared policy keeps a human in the decision to use nuclear weapons."],
		"biosecurity": ["fielded", "Federal guidance asks DNA synthesis providers to screen orders and customers."]},
	"china": {
		"targeting": ["developing", "Doctrine of 'intelligentized' war; fielded details are not public."],
		"counterDrone": ["developing", "Shipborne and land counter-drone systems shown at exhibitions."],
		"undersea": ["developing", "Seabed sensor networks and uncrewed submarines; claims of AI submarine hunting come from simulations."],
		"surveillance": ["fielded", "Nationwide camera networks with facial recognition, most intense in Xinjiang."],
		"infoShield": ["fielded", "A censorship apparatus filters the domestic internet."],
		"influence": ["fielded", "AI companies have removed accounts of a Chinese network producing fake comments and articles."],
		"revenue": ["fielded", "The tax system's newest phase cross-checks invoices with big-data analytics."],
		"export": ["fielded", "Chinese firms have sold 'safe city' surveillance in dozens of partner countries."],
		"deadHand": ["pledged", "Its leader agreed with the American president that humans, not AI, decide on nuclear use."],
		"biosecurity": ["developing", "Biosecurity law and research on screening; little public detail."]},
	"eu": {
		"targeting": ["developing", "NATO bought a commercial targeting decision-support system for allied headquarters."],
		"counterDrone": ["developing", "National counter-drone programmes after drones crossed eastern borders."],
		"undersea": ["developing", "Seabed infrastructure protection with uncrewed vessels and sensors."],
		"surveillance": ["barred", "The EU AI Act forbids real-time facial recognition in public spaces, with narrow judicial exceptions."],
		"infoShield": ["fielded", "The external action service tracks foreign manipulation; the Digital Services Act obliges platforms to act."],
		"revenue": ["fielded", "Tax administrations use analytics against VAT fraud."],
		"export": ["developing", "AI factories open to partners; no package export programme."],
		"deadHand": ["pledged", "France, its nuclear power, has committed to human control of nuclear decisions."],
		"biosecurity": ["developing", "Research and guidance on screening synthetic DNA."]},
	"uk": {
		"targeting": ["developing", "An army programme fuses sensors to speed up targeting; allied decision-support systems."],
		"counterDrone": ["developing", "Directed-energy and drone-interceptor trials."],
		"undersea": ["developing", "Uncrewed undersea vehicles and allied work on advanced capabilities."],
		"surveillance": ["developing", "Police vans with live facial recognition at selected events; not a national system."],
		"infoShield": ["developing", "A government unit monitors foreign disinformation."],
		"revenue": ["fielded", "The tax authority's data-matching system has run for many years."],
		"deadHand": ["pledged", "Committed with the United States and France to human control of nuclear decisions."],
		"biosecurity": ["developing", "Screening guidance for synthetic nucleic acids."]},
	"israel": {
		"targeting": ["fielded", "Reported AI systems generate target recommendations for buildings and people; the army says humans review every strike."],
		"counterDrone": ["fielded", "Layered air defence against drones, with a high-power laser entering service."],
		"surveillance": ["fielded", "Human-rights groups document facial recognition at checkpoints in the West Bank."],
		"infoShield": ["developing", "National cyber and information units."],
		"influence": ["developing", "AI firms removed a commercial operation that targeted foreign audiences on Israel's behalf."],
		"revenue": ["developing", "The tax authority is introducing analytics."],
		"biosecurity": ["developing", "Biodefence research institutions."]},
	"russia": {
		"targeting": ["developing", "Reconnaissance-strike loops built around drones; little public detail."],
		"counterDrone": ["fielded", "Mass electronic warfare and interceptor drones at the front."],
		"undersea": ["developing", "Seabed sensing and an autonomous nuclear torpedo programme."],
		"surveillance": ["fielded", "City camera networks with facial recognition are used to detain protesters in the metro."],
		"infoShield": ["fielded", "Blocks foreign platforms and filters the internet."],
		"influence": ["fielded", "AI companies have removed Russian networks producing fake articles and comments in several languages."],
		"revenue": ["developing", "The tax service runs a large data analytics system."],
		"export": ["developing", "Sells surveillance and security systems to a few partners."],
		"deadHand": ["fielded", "A semi-automatic retaliation system from the Soviet era is reported maintained and modernised."],
		"biosecurity": ["developing", "State research institutes; little public detail."]},
	"ukraine": {
		"targeting": ["fielded", "Battlefield awareness systems turn drone video into targets for artillery and drones."],
		"counterDrone": ["fielded", "An acoustic sensor network and interceptor drones defend against long-range drones."],
		"infoShield": ["fielded", "A national centre counters disinformation."],
		"revenue": ["developing", "Digital state services are being extended to the tax service."]},
	"india": {
		"targeting": ["developing", "A defence AI council and projects; little on fielded targeting."],
		"counterDrone": ["developing", "Domestic counter-drone systems at airbases and borders."],
		"undersea": ["developing", "Ocean surveillance and uncrewed vessels in the Indian Ocean."],
		"surveillance": ["developing", "Police facial recognition systems in large cities."],
		"revenue": ["fielded", "The income-tax and GST services match returns with analytics."],
		"export": ["developing", "Offers its digital public infrastructure to developing countries."],
		"biosecurity": ["developing", "Biosafety rules; screening is at an early stage."]},
	"japan": {
		"targeting": ["developing", "Defence AI policy keeps humans responsible; trials of decision support."],
		"counterDrone": ["developing", "High-power microwave and laser counter-drone research."],
		"undersea": ["developing", "Long-endurance uncrewed submarines in development."],
		"revenue": ["developing", "The tax agency uses AI to select audits."],
		"biosecurity": ["developing", "Research on screening; little public detail."]},
	"south_korea": {
		"targeting": ["developing", "Manned-unmanned teaming and AI command systems in development."],
		"counterDrone": ["developing", "Laser counter-drone weapons introduced against small drones."],
		"revenue": ["developing", "The tax service uses analytics to target evasion."],
		"export": ["developing", "Promotes sovereign AI and data-centre exports."],
		"biosecurity": ["developing", "Biosecurity research institutes."]},
	"turkiye": {
		"targeting": ["developing", "Armed drones with onboard image recognition; targeting support little documented."],
		"counterDrone": ["developing", "Domestic counter-drone systems."],
		"surveillance": ["developing", "City camera networks; facial recognition use reported."]},
	"australia": {
		"targeting": ["developing", "Allied decision-support systems and trials."],
		"counterDrone": ["developing", "Counter-drone trials and purchases."],
		"undersea": ["fielded", "An autonomous extra-large submarine is in production, with allied undersea AI work."],
		"infoShield": ["developing", "A foreign interference task force."],
		"revenue": ["fielded", "The tax office uses data matching and analytics."],
		"biosecurity": ["developing", "Biosecurity screening at the border and in research."]},
	"saudi": {
		"counterDrone": ["developing", "Buys counter-drone and air-defence systems against drone attacks."],
		"surveillance": ["developing", "'Smart city' projects with camera networks."],
		"revenue": ["developing", "The tax and customs authority applies e-invoicing analytics."],
		"export": ["developing", "A state AI company plans to sell compute and models abroad."]},
	"brazil": {"revenue": ["fielded", "The federal revenue service uses machine learning to flag fraud and select inspections."]},
	"indonesia": {"revenue": ["developing", "Tax core-system modernisation with analytics."]},
	"egypt": {"surveillance": ["developing", "Camera networks in new cities."], "revenue": ["developing", "E-invoicing across the economy."]},
	"pakistan": {"surveillance": ["developing", "'Safe city' camera projects in large cities with foreign suppliers."], "revenue": ["developing", "The revenue board is digitising audits."]},
	"iran": {
		"surveillance": ["fielded", "A UN fact-finding mission found cameras, drones and an app used to enforce the dress code."],
		"infoShield": ["fielded", "A national intranet and filtering cut off foreign platforms."],
		"influence": ["fielded", "AI companies have banned Iranian networks producing articles and posts for foreign audiences."]},
	"north_korea": {
		"surveillance": ["developing", "Total state surveillance, but little evidence of AI behind it."],
		"influence": ["developing", "Its hackers use AI tools to pose as job applicants abroad."],
		"deadHand": ["fielded", "Its nuclear law orders an automatic nuclear strike if its command and control is attacked."]},
	"iraq": {},
	"syria": {},
	"afghanistan": {},
	"yemen": {},
	"houthis": {"counterDrone": ["developing", "Fires missiles at drones; no AI evidence."]},
	"ethiopia": {"surveillance": ["developing", "Telecom monitoring by the state; little evidence of AI."]},
	"nigeria": {"surveillance": ["developing", "A capital-city camera project with foreign suppliers."], "revenue": ["developing", "The tax service is automating assessment."]},
	"sudan": {},
	"south_sudan": {},
}

## [status, evidence] for `id` and `domain`; ["", "No public evidence."] if none.
static func of(id: String, domain: String) -> Array:
	return USE.get(id, {}).get(domain, ["", "No public evidence."])

static func status(id: String, domain: String) -> String:
	return str(of(id, domain)[0])

## The share of validation compute a nation needs for `domain`.
static func work_factor(id: String, domain: String) -> float:
	return float(WORK.get(status(id, domain), 1.0))

## The domains `id` fields: a rival's first priorities.
static func fielded(id: String) -> Array:
	return DOMAINS.filter(func(k): return status(id, k) == "fielded")

static func label(s: String) -> String:
	return {"fielded": "Fielded", "developing": "Developing", "barred": "Barred by law", "pledged": "Pledged against"}.get(s, "No public evidence")
