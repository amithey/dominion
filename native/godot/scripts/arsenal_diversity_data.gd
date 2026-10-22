extends RefCounted
## Evidence snapshot 2026-10-11. These are representative systems, not stock counts.
## Source dates and acquisition status matter: an order never grants a playable unit.
const SOURCES := {
	"us_rr": ["US Army: M3A1 fielding completed (2024)", "https://www.army.mil/article-amp/280535/army_completes_fielding_of_the_m3a1_multi_role_anti_armor_anti_personnel_weapon_system_maaws"],
	"us_aa": ["US Army: Avenger role", "https://www.army.mil/article/3215/avenger"],
	"booker": ["US Army: M10 procurement terminated (2025)", "https://www.army.mil/article-amp/286271/army_to_cease_procurement_of_m10_booker_combat_vehicles"],
	"china": ["Chinese MoD: PCL-181 live-fire (2026)", "https://eng.mod.gov.cn/2025xb/D/P_251753/16466631_3.html"],
	"france": ["French MoD: equipment delivered to Ukraine", "https://www.defense.gouv.fr/sites/default/files/ministere-armees/Liste%20des%20%C3%A9quipements%20livr%C3%A9s%20%C3%A0%20l%27Ukraine_0.pdf"],
	"iran": ["DIA: Iran Military Power (2019; legacy assessment)", "https://www.dia.mil/Portals/110/Images/News/Military_Powers_Publications/Iran_Military_Power_LR.pdf"],
	"malva": ["Rostec: first Malva delivery (2023; supplier statement)", "https://rostec.ru/media/news/rostekh-peredal-minoborony-pervuyu-partiyu-samokhodnykh-kolesnykh-gaubits-malva/"],
	"pantsir": ["Rostec: Pantsir-S delivery (2025; supplier statement)", "https://rostec.ru/media/pressrelease/rostekh-postavil-v-voyska-boevye-mashiny-pantsir-s/"],
	"india": ["Saab: Indian Army Carl-Gustaf service", "https://www.saab.com/markets/india/stories/2016/a-40-year-history-in-india"],
	"japan": ["JGSDF: infantry weapons and air defence", "https://www.mod.go.jp/gsdf/equipment/fire/"],
	"type19": ["JGSDF: Type 19 deployment ceremony (2023)", "https://www.mod.go.jp/pco/kumamoto/topics/2023_8/20230804/index.html"],
	"turkiye": ["SSB: HISAR-A in service; layered air defence", "https://www.ssb.gov.tr/haber/siper-urun-1-ve-hisar-projelerinde-seri-uretim-icin-imzalar-atildi-LPq5Os"],
	"israel": ["Israeli MoD: first Eitan APC delivery", "https://mod.gov.il/en/press-releases/press-room/delivery-of-first-eitan-armored-personnel-carriers-apc-to-the-israel-defense-forces-nahal-infantry-brigade"],
	"archer": ["British Army: gunners fire Archer", "https://www.army.mod.uk/news/british-gunners-take-aim-and-fire-swedish-archer-for-the-first-time/"],
	"stormer": ["British Army: Starstreak and Stormer", "https://www.army.mod.uk/learn-and-explore/equipment/artillery-and-air-defence/starstreak-high-velocity-missile/"],
	"korea": ["Hanwha: 2024 sustainability report; domestic systems", "https://www.hanwhaaerospace.com/assets/content/esg/sustainBusiness/download/en/HanwhaAerospace_SustainabilityReport_2024_ENG.pdf"],
	"saudi": ["US Army imagery: Saudi Bradley equipment (2025)", "https://www.dvidshub.net/image/9380249/rslf-equipment-arrives-ntc-rotation"],
	"brazil": ["Saab: Carl-Gustaf M3 in Brazilian Army", "https://www.saab.com/pt-br/markets/brasil/historias/2017/carl-gustaf-no-exercito-brasileiro"],
	"indonesia": ["Indonesian MoD: TNI equipment parade (2017)", "https://www.kemhan.go.id/2017/10/05/menhan-hadiri-upacara-hut-tni-ke-72-di-cilegon.html"],
	"indo_caesar": ["Indonesian MoD: CAESAR handover (2014)", "https://www.kemhan.go.id/baloghan/2014/06/26/penyerahan-secara-simbolis-empat-unit-caesar-155.html"],
	"ukraine": ["German government: delivered vs planned aid", "https://www.bundesregierung.de/breg-de/service/archiv-bundesregierung/waffenlieferungen-ukraine-2054514"],
	"nk": ["DIA: North Korea Military Power (2021)", "https://www.dia.mil/Portals/110/Documents/News/North_Korea_Military_Power.pdf"],
	"egypt": ["Hanwha: K9A1EGY delivery schedule; not arrival confirmation", "https://www.hanwhaaerospace.com/eng/media/newsroom/view.do?seq=480"],
	"australia": ["Australian Defence: Carl-Gustaf service / modernization", "https://www.saab.com/markets/australia/news/press/2018/saab-receives-australian-order-for-carl-gustaf-m4"],
	"as9": ["Australian Defence: first AS9 battery (August 2026)", "https://news.defence.gov.au/army/capability/2026-08-12/parade-marks-major-advance-artillery-capability"],
	"redback": ["Australian Defence: Redback sea trials (September 2026)", "https://news.defence.gov.au/army/capability/2026-09-03/new-fighting-vehicles-tested-sea"],
	"pakistan": ["Janes: SH-15 delivered to Pakistan (reported)", "https://www.janes.com/defence-intelligence-insights/defence-news/defence/chinas-norinco-delivers-sh-15-howitzers-to-pakistan"],
	"iraq": ["Aero: Iraqi L-159 delivery", "https://www.aero.cz/en/l-159/"],
	"syria": ["UK Home Office: Syrian military reorganization (2025)", "https://assets.publishing.service.gov.uk/media/6874e05eb1b4ebc2c2e46547/SYR%2BCPIN%2BMilitary%2BService.pdf"],
	"yemen": ["UN Panel of Experts: Yemen (2025)", "https://documents.un.org/api/symbol/access?l=en&s=S%2F2025%2F650&t=pdf"],
	"nigeria": ["Nigerian Air Force: T129 inducted (2024)", "https://airforce.mil.ng/news/president-tinubu-reaffirms-commitment-to-ending-insecurity-inducts-new-combat-helicopters-into-naf-inventory775984965"],
	"naf29": ["Nigerian Air Force: A-29 operational support (2023)", "https://www.airforce.mil.ng/news/a-29st-program-naf-commissions-operations-support-facilities-wings-additional-6-pilots376732102"],
	"nafjf": ["Nigerian Air Force: JF-17 induction (2021)", "https://www.airforce.mil.ng/news/naf-day-2021-ends-with-induction-of-jf-17-multi-role-thunder-aircraft1424548808"],
	"sudan": ["Amnesty: visually identified weapons in Sudan (2024)", "https://www.amnesty.org/en/latest/research/2024/07/new-weapons-fuelling-the-sudan-conflict/"],
	"rsf": ["Amnesty: AH-4 and GB50 evidence; actor attribution (2025)", "https://www.amnesty.org/en/latest/news/2025/05/sudan-advanced-chinese-weaponry-provided-by-uae-identified-in-breach-of-arms-embargo-new-investigation/"],
	"south_sudan": ["UN Panel of Experts: South Sudan (2025)", "https://digitallibrary.un.org/record/4085042/files/S_2025_442-EN.pdf"],
	"sipri": ["SIPRI: transfers database; not a readiness inventory", "https://www.sipri.org/databases/armstransfers"]
}
## [model, source, evidence status]. Only these positively attributed entries
## grant new production choices; country essays and watch lists grant nothing.
const ROSTER := {
	"recoillessTeam": {
		"usa": ["M3A1 MAAWS Team", "us_rr", "Fielding documented"],
		"india": ["Carl-Gustaf Team", "india", "Established service"],
		"japan": ["84 mm Recoilless Team", "japan", "Official equipment list"],
		"brazil": ["Carl-Gustaf M3 Team", "brazil", "Established service"],
		"australia": ["Carl-Gustaf Team", "australia", "Established service; variant abstracted"]},
	"wheeledHowitzer": {
		"china": ["PCL-181", "china", "Live-fire documented"],
		"russia": ["2S43 Malva", "malva", "Supplier-reported delivery"],
		"japan": ["Type 19 Howitzer", "type19", "Deployment documented"],
		"uk": ["Archer", "archer", "Army firing documented"],
		"indonesia": ["CAESAR", "indo_caesar", "Handover documented"],
		"ukraine": ["CAESAR", "france", "Delivery documented"],
		"pakistan": ["SH-15", "pakistan", "Reported delivery"]},
	"shortRangeSAM": {
		"usa": ["AN/TWQ-1 Avenger", "us_aa", "Established service"],
		"russia": ["Pantsir-S", "pantsir", "Supplier-reported delivery"],
		"japan": ["Type 11 SAM", "japan", "Official equipment list"],
		"turkiye": ["HISAR-A", "turkiye", "In-service statement"],
		"uk": ["Stormer HVM", "stormer", "Official equipment list"],
		"ukraine": ["IRIS-T SLS", "ukraine", "Delivery documented"]}
}
## Each dossier covers land, air, maritime, fires/defence, sustainment and
## an explicit evidence boundary. Existing national unit lists remain separate.
const PROFILES := {
	"usa": {"land": "Abrams and Bradley cover heavy armour and infantry support; MAAWS adds a cheaper close-range support team.", "air": "F-16 / A-10 and the existing F-22 / B-21 roles separate multirole, close support and high-cost advanced aircraft.", "sea": "Ocean-going surface forces and submarines need different missions; a carrier is not a coastal missile boat.", "fires": "M777 / tracked artillery offer fires; Avenger adds local air escort below strategic missile defence.", "support": "Fuel, ammunition, airfield capacity and expensive electronics constrain the advanced roster.", "limits": "M10 Booker procurement was terminated. M1E3 remains a research scenario, not an established operational fleet.", "watch": ["M10 Booker: cancelled procurement; no production choice added"], "sources": ["us_rr", "us_aa", "booker"]},
	"china": {"land": "ZBD-04A infantry support complements the existing heavy tank; PCL-181 adds wheeled artillery rather than another tank.", "air": "J-10C is a light multirole choice alongside heavier fighters; unmanned aircraft have separate costs and vulnerabilities.", "sea": "Type 022 is coastal surface warfare; it does not inherit submarine hunting or strategic nuclear launch.", "fires": "Wheeled PCL-181 trades protection for relocation. Existing DF-17 / missile research remains separately gated.", "support": "Reconnaissance must expose targets beyond the gun's sight; artillery needs protected logistics.", "limits": "Manufacturer range claims are not map distances. No extra hypersonic inventory follows from a parade.", "watch": ["New parade systems require separate delivery evidence"], "sources": ["china", "sipri"]},
	"iran": {"land": "BMP-2 and legacy armoured platforms support a mixed fleet; local names do not prove entirely new designs.", "air": "F-5E and Su-24 represent documented legacy aircraft; spare parts and current serviceability are uncertain.", "sea": "Coastal craft and shore-based threats differ from a modern blue-water escort fleet.", "fires": "Drones, rockets and ballistic / cruise missiles are separate roles; one-way drones are not reusable fighters.", "support": "Imported components, sanctions, repairs and dispersed production constrain sophisticated systems.", "limits": "The DIA baseline is from 2019. Conflict losses and 2026 readiness are not verified here; no new advanced fleet is granted.", "watch": ["New fighter or air-defence announcements: confirmation needed"], "sources": ["iran", "sipri"]},
	"russia": {"land": "BMP-3 and tanks supply protected manoeuvre; Malva supplies less protected, faster wheeled gun support.", "air": "Su-25 is ground attack, not a dogfighter; the existing strike and fighter classes retain separate missions.", "sea": "Surface ships and submarines are separate platforms, with theatre and maintenance limits.", "fires": "Malva complements tracked guns and rockets. Pantsir-S adds local anti-aircraft escort, not strategic ABM in this expansion.", "support": "Gun crews need reconnaissance, ammunition and protection; moving faster does not make them more heavily armoured.", "limits": "Rostec confirms claimed deliveries, not independent fleet readiness or combat success. Losses are not estimated.", "watch": ["Supplier success claims are not used as hit probabilities"], "sources": ["malva", "pantsir", "sipri"]},
	"india": {"land": "BMP-2 Sarath and heavy tanks gain close support from Carl-Gustaf crews; a support launcher is not an ATGM replacement.", "air": "Jaguar and Tejas separate ground attack and lighter fighter roles; imported and domestic platforms coexist.", "sea": "A substantial maritime roster needs port and research investment; ground missile ownership does not grant every naval launcher.", "fires": "M777 complements tracked artillery; BrahMos and air-defence projects remain separate capabilities.", "support": "Multiple suppliers complicate ammunition and spares. Cheap infantry support remains useful before expensive missile research.", "limits": "Carl-Gustaf service is documented; the dossier does not assert a delivered number of the newest M4 variant.", "watch": ["Zorawar and new gun contracts: trials / orders need delivery confirmation"], "sources": ["india", "sipri"]},
	"japan": {"land": "Type 89 IFV, Type 16 wheeled gun and heavy tanks serve different protection / mobility needs; 84 mm crews add portable support.", "air": "Fighter defence and OH-1 reconnaissance are separate; the game reconnaissance sortie carries no attack load.", "sea": "Aegis and surface escorts emphasize maritime defence; an Aegis hull is not automatically nuclear armed.", "fires": "FH70, Type 19 and Type 11 separate cheap towed fires, mobile fires and local air defence.", "support": "Type 19 uses existing artillery research and spotting; Type 11 requires guided-munition research.", "limits": "Type 19 deployment is documented. Procurement budgets alone are not delivery counts; Type 12 upgrades remain separately assessed.", "watch": ["Extended-range missile upgrades: distinguish trials from units in service"], "sources": ["japan", "type19"]},
	"turkiye": {"land": "ACV-15 and conventional armour support ground forces; new domestic tank deliveries do not instantly replace the mixed fleet.", "air": "F-16 and Akinci separate crewed multirole and unmanned strike roles.", "sea": "Coastal and larger surface combatants need different weapons and support; local construction is not limitless availability.", "fires": "HISAR-A adds local air defence below longer-range layers; it cannot bombard ground targets.", "support": "Electronics, radar and protection consume resources; drones remain vulnerable to air defence and electronic warfare.", "limits": "KAAN and future aircraft remain research projects. The source distinguishes HISAR service from then-testing Siper.", "watch": ["KAAN: development aircraft, not a newly granted operational fleet"], "sources": ["turkiye", "sipri"]},
	"israel": {"land": "Merkava, Namer and Eitan separate heavy tank, heavily protected carrier and wheeled carrier; passengers are abstracted.", "air": "Crewed aircraft and Harop have distinct sortie / expendable-weapon economics.", "sea": "Sa'ar 4.5 supplies coastal missile warfare; no nuclear weapon is inferred from a missile boat.", "fires": "Layered interception and local anti-aircraft defence must be distinguished; the game retains its existing missile-defence systems.", "support": "Advanced protection costs electronics and research; heavy protection cannot replace reconnaissance or logistics.", "limits": "Eitan APC is distinct from the Eitan UAV. No extra strategic capability or new Ro'em fleet is inferred from announcements.", "watch": ["New artillery and interceptor variants need actual delivery evidence"], "sources": ["israel", "sipri"]},
	"uk": {"land": "Warrior, Jackal and the existing tank fill infantry support, reconnaissance and heavy armour roles.", "air": "Wildcat reconnaissance is abstracted without weapons; fighter sorties use limited parking and ammunition.", "sea": "Type 45, other surface forces and submarines have separate escort and strike roles.", "fires": "L118 is cheap and slow to relocate; Archer is more mobile. Stormer HVM escorts ground forces against aircraft.", "support": "An interim Archer capability does not imply unlimited systems; keep scouts and supplies with mobile guns.", "limits": "Challenger 3 is a modernization programme. No retired Tornado fleet is reintroduced from historical lists.", "watch": ["New Carl-Gustaf purchase: variant / fielding requires a separate check"], "sources": ["archer", "stormer"]},
	"south_korea": {"land": "K21 IFV and K808 carrier remain separate from K2 heavy armour; they are not interchangeable labels.", "air": "FA-50 is a lighter fighter; advanced aircraft and future programmes keep independent gates.", "sea": "Surface escorts and submarines require maritime infrastructure and separate weapons.", "fires": "K9 tracked artillery, Chunmoo rockets and close air defence belong to different layers and mobility classes.", "support": "Tracked gun protection costs more than exposed towed crews; domestic manufacturing does not remove supply needs.", "limits": "Hanwha's export catalogue is not an operator list. Export-specific variants are not automatically granted to Korea.", "watch": ["L-SAM and new aircraft variants: assess delivered configuration individually"], "sources": ["korea", "sipri"]},
	"saudi": {"land": "Bradley is documented in Saudi service; heavy armour and infantry support remain separate choices.", "air": "Tornado IDS serves ground attack beside multirole aircraft; sustainment depends heavily on foreign partners.", "sea": "Coastal and escort capability is represented separately from any presumed submarine fleet.", "fires": "Existing Patriot / THAAD roles cover different threats; an ammunition-sale notice is not a new battery delivery.", "support": "Imported spares, training and contractor support are consequential despite strong purchasing power.", "limits": "CAESAR and additional air-defence variants are research candidates here; no fresh unit grant relies on an unconfirmed sale.", "watch": ["Proposed FMS approvals are not proof of delivered equipment"], "sources": ["saudi", "sipri"]},
	"brazil": {"land": "Guarani and Cascavel emphasize wheeled mobility; Carl-Gustaf M3 crews provide cheaper portable fire support.", "air": "F-5M and existing Gripen / A-29 choices separate fighter and close-support tasks; retired types need retirement checks.", "sea": "Coastal and ocean-going missions differ; submarine projects must be separated from delivered boats.", "fires": "ASTROS rockets differ from towed guns and portable launchers; new cruise-missile projects are not automatically operational.", "support": "Affordable infantry support consumes less industrial material than armour but needs protection in close combat.", "limits": "The M3 service source does not prove a universal M4 conversion. AMX and AH-2 are not newly granted from older lists.", "watch": ["MTC-300 and guided ASTROS development: no operational grant in this update"], "sources": ["brazil", "sipri"]},
	"indonesia": {"land": "Harimau medium tank, Pandur II and Komodo distinguish direct fire, infantry support and reconnaissance.", "air": "A mixed imported fleet complicates maintenance; fighters and support aircraft remain distinct roles.", "sea": "An archipelago needs coastal missile craft and escorts; a small craft does not gain submarine-hunting weapons by default.", "fires": "Delivered CAESAR adds mobile artillery alongside tracked M109 and rockets; Starstreak / Mistral are a different role.", "support": "Protect mobile guns with scouts and infantry; faster relocation trades against tank-like protection.", "limits": "A 2017 parade is historical evidence, not a 2026 readiness census. Harimau production evidence is tracked in the earlier roster report.", "watch": ["New fighter contracts: orders and operational squadrons stay distinct"], "sources": ["indonesia", "indo_caesar", "sipri"]},
	"ukraine": {"land": "Bradley, AMX-10 RC and donated tanks form a mixed fleet with different ammunition and spares.", "air": "Su-25 ground attack needs fighter cover; aid announcements do not prove an entire operational squadron.", "sea": "Coastal weapons and unmanned maritime activity do not recreate the pre-war surface fleet.", "fires": "Delivered CAESAR adds wheeled fires; IRIS-T SLS gives local air defence, distinct from SLM and Patriot.", "support": "Donor supply, repairs and ammunition are central. Long-range guns still need target visibility in the game.", "limits": "German aid records explicitly separate delivered and planned systems; only delivered examples grant new production here.", "watch": ["Pending aid is shown as a plan, never counted as on-hand stock"], "sources": ["ukraine", "france"]},
	"north_korea": {"land": "Legacy armour and massed guns coexist with displayed newer designs; a parade alone does not prove fleet scale.", "air": "Su-25 and older fighters are legacy assessments, with uncertain current serviceability.", "sea": "Small surface vessels and submarines have coastal roles; modern escort capability is not assumed.", "fires": "Artillery, rockets and strategic missiles are separate systems; missile imagery does not establish stock counts.", "support": "Ammunition volume cannot substitute for electronics, maintenance or reconnaissance.", "limits": "The DIA assessment is from 2021. No new advanced SAM, tank or reconnaissance helicopter is granted from unverified displays.", "watch": ["Recent parade systems: operational status and configuration remain uncertain"], "sources": ["nk", "sipri"]},
	"egypt": {"land": "Existing heavy armour and carriers retain a mixed-supplier legacy; modernization orders do not instantly replace them.", "air": "A varied imported fleet has distinct fighter, support and maintenance needs.", "sea": "Ambassador Mk III represents fast coastal missile combat; larger escorts and submarines remain separate classes.", "fires": "Conventional artillery and air defence remain available through the established roster; K9A1EGY is a procurement watch item.", "support": "Spare parts from multiple suppliers, ammunition and trained crews limit availability.", "limits": "A schedule for first K9 deliveries by early 2026 is not proof they arrived. No unverified K9 production choice is added.", "watch": ["K9A1EGY: delivery schedule documented; actual arrival needs confirmation"], "sources": ["egypt", "sipri"]},
	"australia": {"land": "Hawkei reconnaissance, protected mobility and heavy armour coexist; Carl-Gustaf service adds portable support.", "air": "Modern fighters require fuel and airfield support; unmanned development is separately gated.", "sea": "Long-distance maritime operations require escorts and sustainment; future submarines are not current inventory.", "fires": "M777 and the first documented AS9 battery separate towed and tracked fires; NASAMS is a different defence layer.", "support": "Small high-value fleets depend on training, imported components and support vehicles.", "limits": "AS9 first battery was documented in August 2026. Redback sea trials do not prove a fully operational IFV fleet.", "watch": ["AS21 Redback: trials / procurement; no fielded IFV grant", "AS9: first battery documented; no claim of fleet-wide conversion"], "sources": ["australia", "as9", "redback"]},
	"pakistan": {"land": "Heavy armour and MG3 support coexist; wheeled SH-15 adds a distinct artillery mobility choice.", "air": "Mirage 5 attack and F-16 / JF-17 fighter roles differ; maintenance and imported parts constrain availability.", "sea": "Azmat-class is coastal surface warfare, not a submarine hunter or strategic nuclear launcher in this expansion.", "fires": "SH-15 deliveries are reported; its game shells are conventional. Ownership does not prove a nuclear artillery role.", "support": "Multiple suppliers require spares and ammunition; mobile artillery still needs escorts and spotting.", "limits": "The new howitzer attribution is a Janes report, not an independently audited readiness count.", "watch": ["Nuclear-capable SH-15 speculation does not grant a nuclear firing mode"], "sources": ["pakistan", "sipri"]},
	"iraq": {"land": "Mixed-origin heavy armour and infantry equipment need common training and sustainment; no unsupported new IFV is granted.", "air": "Delivered L-159 fills ground attack; T-50IQ is a separate light aircraft choice in the established roster.", "sea": "Coastal security is limited; it is not an ocean-going combat fleet.", "fires": "Conventional guns and local air defence remain distinct from future long-range air-defence procurement.", "support": "Repairs, foreign support and spare parts are essential to a mixed fleet.", "limits": "A proposed sale or a denial from 2015 cannot establish a new operational BMP-3 fleet in 2026.", "watch": ["New long-range SAM contracts need delivered-battery confirmation"], "sources": ["iraq", "sipri"]},
	"syria": {"land": "Fragmented inherited and captured ground equipment does not establish a standardized new army inventory.", "air": "An inherited paper list does not establish an operational fighter or gunship force after the change of government.", "sea": "No new combat fleet is inferred from the former government's navy.", "fires": "Portable support, guns and drones require actor attribution; former stocks do not prove current launch capability.", "support": "Reorganization, damage, ammunition and repair infrastructure constrain the ground roster.", "limits": "The 2025 institutional assessment is not a verified 2026 inventory. No new advanced system is granted without evidence.", "watch": ["Former regime aircraft, SAMs and ships are not treated as new operational stock"], "sources": ["syria", "sipri"]},
	"yemen": {"land": "The recognized government's forces are fragmented; support weapons and vehicles require specific actor attribution.", "air": "No new operational fighter fleet is inferred from the pre-war Yemeni air force.", "sea": "Limited coastal security differs from the Houthis' shore-based shipping threats.", "fires": "Conventional support and reported UAV activity do not grant Ansar Allah's missile families to the government.", "support": "Reconstruction, partner support, imported parts and divided command constrain readiness.", "limits": "Yemen is the internationally recognized state; it is not interchangeable with Ansar Allah-controlled territory.", "watch": ["Pre-war inventories and Houthi seizures cannot be assigned wholesale to the PLC"], "sources": ["yemen", "sipri"]},
	"houthis": {"land": "Ansar Allah relies on dispersed ground forces, support weapons and captured or externally sourced materiel.", "air": "One-way attack UAVs and reconnaissance drones do not constitute a conventional fighter air force.", "sea": "Coastal missiles and drones threaten shipping; they do not imply an advanced navy or submarine fleet.", "fires": "Ballistic, cruise and anti-ship weapons are distinct; reported attacks provide stronger evidence of use than parade labels.", "support": "Imported electronics, repairs and component access constrain replenishment; the game models this through resources.", "limits": "An armed authority inside Yemen, not a separate UN member. Claimed weapon performance and stock counts are not accepted as verified.", "watch": ["Paraded new missile labels: configuration and stocks may be unverified"], "sources": ["yemen", "sipri"]},
	"nigeria": {"land": "Ground forces emphasize protected mobility and counterinsurgency; an export catalogue is not proof of a delivered tank model.", "air": "NAF confirms A-29 support facilities, JF-17 induction and T129 induction: attack aircraft, fighter and attack helicopter are distinct.", "sea": "Coastal patrol and maritime security do not imply an attack-submarine capability.", "fires": "Ground artillery and local anti-aircraft weapons remain separate from strategic missile and nuclear capabilities.", "support": "Pilots, maintenance facilities, electricity and foreign parts are essential alongside aircraft procurement.", "limits": "The established A-29 / JF-17 / gunship choices already cover these roles; no duplicate attack-jet label is added just to enlarge the list.", "watch": ["New aircraft orders do not bypass research or create a ready fleet"], "sources": ["nigeria", "naf29", "nafjf"]},
	"sudan": {"land": "The game state represents SAF-aligned Sudan, not the RSF. Mixed legacy equipment requires actor-specific attribution.", "air": "Documented use and legacy aircraft do not establish the number currently serviceable after war damage.", "sea": "Red Sea coastal access does not imply a sophisticated ocean-going combat fleet.", "fires": "Mortars, small arms and electronic equipment are documented; AH-4 / GB50 findings must be attributed to the correct actor.", "support": "Damaged bases, supply routes, maintenance and imported ammunition dominate sustainment.", "limits": "RSF weapons and isolated captured examples are not granted as a standard SAF production line.", "watch": ["AH-4 / GB50: RSF-related investigation; no automatic Sudan arsenal grant"], "sources": ["sudan", "rsf"]},
	"south_sudan": {"land": "A limited legacy ground roster reflects weak procurement and maintenance capacity, not Sudan's inventory.", "air": "UN reporting supports Mi-24 activity; it does not establish a modern fighter force or a large ready helicopter fleet.", "sea": "Landlocked: river security is not a seagoing navy, and no naval production is granted.", "fires": "Small arms and basic support differ from advanced SAMs, precision rockets and strategic missiles.", "support": "Restricted arms access, oil revenue and transit dependence shape affordable force development.", "limits": "South Sudan is an independent state. Reported plans to obtain Stinger or Javelin are not evidence of possession.", "watch": ["Coup allegations and attempted purchases do not grant operational weapons"], "sources": ["south_sudan", "sipri"]}
}

## The three tables above hold the earlier nations. A later nation keeps its dossier, its own
## sources and its roster rows in the "dossier" of scripts/nations/<id>.gd; these read both.
static var _own := {}
static var _own_loaded := false
static var _merged := {}
static func _dossiers() -> Dictionary:
	if not _own_loaded:
		_own_loaded = true
		for script in preload("res://scripts/nation_registry.gd").ORDER:
			if script.DATA.has("dossier"): _own[script.DATA.id] = script.DATA.dossier
	return _own

static func has_profile(id: String) -> bool:
	return PROFILES.has(id) or _dossiers().has(id)

## The six-domain dossier of nation `id`: {} if it has none.
static func profile(id: String) -> Dictionary:
	if PROFILES.has(id): return PROFILES[id]
	return _dossiers().get(id, {}).get("profile", {})

## Who fields role `key`: id -> [model, source, evidence status], the table and the nation files together.
static func roster(key: String) -> Dictionary:
	if not _merged.has(key):
		var rows: Dictionary = ROSTER.get(key, {}).duplicate()
		var own := _dossiers()
		for id in own:
			if own[id].roster.has(key): rows[id] = own[id].roster[key]
		_merged[key] = rows
	return _merged[key]

## [label, link] of source `id`, from the table or from a nation's own sources.
static func source(id: String) -> Array:
	if SOURCES.has(id): return SOURCES[id]
	var own := _dossiers()
	for nation in own:
		if own[nation].sources.has(id): return own[nation].sources[id]
	return []

static func source_ids() -> Array:
	var out: Array = SOURCES.keys()
	var own := _dossiers()
	for nation in own: out.append_array(own[nation].sources.keys())
	return out

static func names(key: String) -> Dictionary:
	var out := {}
	var rows := roster(key)
	for id in rows: out[id] = rows[id][0]
	return out

static func evidence(key: String, id: String) -> String:
	var row: Array = roster(key).get(id, [])
	# (the game's text names no years: the dates stay in the source links and the research doc)
	return "" if row.is_empty() else "%s. %s. Public evidence; no stock or readiness count implied." % [row[2], undated(str(source(row[1])[0]))]

## "Rostec: first Malva delivery (2023; supplier statement)" -> "... (supplier statement)".
static func undated(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\s*\\((?:[A-Z][a-z]+ )?(?:19|20)\\d{2}(?:;\\s*([^)]*))?\\)")
	var out := text
	for m in re.search_all(text):
		out = out.replace(m.get_string(), (" (%s)" % m.get_string(1)) if m.get_string(1) != "" else "")
	var year := RegEx.new()
	year.compile("\\b(?:19|20)\\d{2}\\s+")
	return year.sub(out, "", true).strip_edges()
