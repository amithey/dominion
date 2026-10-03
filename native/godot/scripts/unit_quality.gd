extends RefCounted
## How good each nation's own system in a shared unit class is (2026): its
## protection (health), firepower (damage), accuracy (fire control and guidance),
## mobility (speed) and reach (range), as multipliers of the shared unit. A
## third-generation-plus tank (M1A2 SEPv3, Leopard 2A8, Merkava 4, K2) is above 1, a
## Cold War one (T-64BV, T-72, Karrar) well below, a 1960s one (T-62, Leopard 1)
## lower still. Generations and the research behind every figure:
## native/UNIT-QUALITY-RESEARCH-2026-10-03.md. The national doctrines
## (factions.gd) come on top of these.

## Units that take another class's figures.
const CLASS_OF := {"himars": "mlrs", "nuclearSub": "submarine", "bomber": "jet", "loiterer": "drone",
	"soldier": "infantry", "rocketSoldier": "infantry", "sniper": "infantry", "commando": "infantry"}

## class -> nation -> [health, damage, accuracy, speed, range]
const QUALITY := {
	"tank": {
		"usa": [1.24, 1.15, 1.12, 0.95, 1.0],   # M1A2 SEPv3 Abrams
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 99A
		"eu": [1.12, 1.08, 1.12, 1.03, 1.0],   # Leopard 2A8
		"iran": [0.76, 0.78, 0.68, 0.95, 1.0],   # Karrar
		"russia": [1.0, 1.0, 0.96, 1.0, 1.0],   # T-90M Proryv
		"india": [0.93, 0.95, 0.92, 0.95, 1.0],   # Arjun Mk1A
		"japan": [1.12, 1.08, 1.16, 1.05, 1.0],   # Type 10
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Altay
		"israel": [1.2, 1.08, 1.15, 0.92, 1.0],   # Merkava Mk 4 Barak
		"uk": [1.05, 1.0, 1.0, 0.92, 1.0],   # Challenger 2
		"south_korea": [1.12, 1.08, 1.12, 1.06, 1.0],   # K2 Black Panther
		"saudi": [1.0, 1.0, 1.0, 1.0, 1.0],   # M1A2S Abrams
		"brazil": [0.62, 0.7, 0.82, 1.02, 1.0],   # Leopard 1A5BR
		"indonesia": [0.86, 0.9, 0.84, 1.0, 1.0],   # Leopard 2A4
		"ukraine": [0.7, 0.78, 0.72, 0.95, 1.0],   # T-64BV
		"north_korea": [0.7, 0.78, 0.62, 0.95, 1.0],   # Chonma-216
		"egypt": [0.86, 0.9, 0.88, 1.0, 1.0],   # M1A1 Abrams
		"australia": [1.24, 1.15, 1.12, 0.95, 1.0],   # M1A2 SEPv3 Abrams
		"pakistan": [0.93, 0.95, 0.92, 1.0, 1.0],   # VT-4 Haider
		"iraq": [0.82, 0.9, 0.84, 0.97, 1.0],   # M1A1M Abrams
		"syria": [0.65, 0.78, 0.68, 0.9, 1.0],   # T-72
		"afghanistan": [0.5, 0.62, 0.55, 0.9, 1.0],   # T-62 (captured)
	},
	"apc": {
		"usa": [1.0, 1.0, 1.0, 1.0, 1.0],   # Stryker
		"china": [0.86, 0.9, 0.84, 1.0, 1.0],   # ZBL-08
		"eu": [1.12, 1.08, 1.12, 1.0, 1.0],   # Boxer
		"iran": [0.62, 0.7, 0.62, 0.92, 1.0],   # Rakhsh
		"russia": [0.78, 0.84, 0.76, 0.97, 1.0],   # BTR-82A
		"india": [0.86, 0.9, 0.84, 1.0, 1.0],   # WhAP
		"japan": [0.78, 0.84, 0.76, 0.97, 1.0],   # Type 96 APC
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Pars
		"israel": [1.16, 1.08, 1.12, 1.0, 1.0],   # Eitan
		"uk": [1.12, 1.08, 1.12, 1.0, 1.0],   # Boxer
		"south_korea": [1.0, 1.0, 1.0, 1.05, 1.0],   # K21
		"saudi": [0.86, 0.9, 0.84, 1.0, 1.0],   # LAV 700
		"brazil": [0.86, 0.9, 0.84, 1.0, 1.0],   # VBTP Guarani
		"indonesia": [0.7, 0.78, 0.68, 0.95, 1.0],   # Anoa
		"ukraine": [0.86, 0.9, 0.84, 1.0, 1.0],   # BTR-4
		"north_korea": [0.7, 0.78, 0.63, 0.95, 1.0],   # M-2010
		"egypt": [0.62, 0.7, 0.62, 0.92, 1.0],   # M113 / Fahd
		"australia": [1.12, 1.08, 1.12, 1.0, 1.0],   # Boxer CRV
		"pakistan": [0.7, 0.78, 0.68, 0.95, 1.0],   # Saad / M113
		"iraq": [0.7, 0.78, 0.68, 0.95, 1.0],   # BTR-4 / M113
		"syria": [0.57, 0.7, 0.62, 0.92, 1.0],   # BMP-1
		"afghanistan": [0.47, 0.62, 0.55, 0.95, 1.0],   # Humvee (captured)
	},
	"artillery": {
		"usa": [1.0, 1.0, 1.0, 1.0, 0.95],   # M109A7 Paladin
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # PLZ-05
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # PzH 2000
		"iran": [0.7, 0.78, 0.68, 0.95, 0.89],   # Raad-2
		"russia": [0.93, 0.95, 0.92, 1.0, 0.97],   # 2S19M2 Msta-S
		"india": [1.0, 1.0, 1.0, 1.0, 1.0],   # K9 Vajra-T
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 99 SPH
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # T-155 Firtina
		"israel": [1.0, 1.0, 1.04, 1.0, 1.0],   # Roem (ATMOS)
		"uk": [0.86, 0.9, 0.84, 1.0, 0.95],   # AS-90 / Archer
		"south_korea": [1.12, 1.08, 1.12, 1.0, 1.04],   # K9A1 Thunder
		"saudi": [1.0, 1.0, 1.0, 1.05, 1.0],   # CAESAR
		"brazil": [0.78, 0.84, 0.76, 0.97, 0.92],   # M109A5+ BR
		"indonesia": [1.0, 1.0, 1.0, 1.05, 1.0],   # CAESAR
		"ukraine": [0.93, 0.95, 0.96, 1.0, 0.97],   # 2S3 / PzH 2000 / Krab
		"north_korea": [0.7, 0.78, 0.68, 0.85, 1.04],   # M1989 Koksan
		"egypt": [0.78, 0.84, 0.76, 0.97, 0.92],   # M109A5
		"australia": [1.12, 1.08, 1.12, 1.0, 1.04],   # AS9 Huntsman
		"pakistan": [0.86, 0.9, 0.84, 1.0, 0.95],   # M109A5 / SH-15
		"iraq": [0.78, 0.84, 0.76, 0.97, 0.92],   # M109A5
		"syria": [0.62, 0.7, 0.62, 0.92, 0.85],   # 2S1 Gvozdika / D-30
		"afghanistan": [0.55, 0.62, 0.55, 0.65, 0.81],   # D-30 (towed)
	},
	"mlrs": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # M270A2 MLRS
		"china": [0.93, 0.95, 0.92, 1.0, 0.97],   # PHL-03
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # MARS II
		"iran": [0.7, 0.78, 0.68, 0.95, 0.89],   # Fajr-5
		"russia": [0.93, 0.95, 0.92, 1.0, 0.97],   # BM-30 Smerch
		"india": [1.0, 1.0, 1.0, 1.0, 1.0],   # Pinaka
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # M270 (JGSDF)
		"turkiye": [0.86, 0.9, 0.84, 1.0, 0.95],   # T-122 Sakarya
		"israel": [1.0, 1.0, 1.05, 1.0, 1.0],   # Lynx / PULS
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # M270A2 MLRS
		"south_korea": [1.12, 1.08, 1.12, 1.0, 1.04],   # K239 Chunmoo
		"saudi": [0.86, 0.9, 0.84, 1.0, 0.95],   # ASTROS II
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # ASTROS II Mk6
		"indonesia": [0.86, 0.9, 0.84, 1.0, 0.95],   # ASTROS II / RM-70
		"ukraine": [0.93, 0.95, 0.97, 1.0, 0.97],   # BM-27 / HIMARS
		"north_korea": [0.78, 0.84, 0.68, 0.97, 1.07],   # KN-25 / M1991
		"egypt": [0.7, 0.78, 0.68, 0.95, 0.89],   # BM-21 Sakr
		"australia": [1.12, 1.08, 1.12, 1.0, 1.04],   # M142 HIMARS
		"pakistan": [0.93, 0.95, 0.92, 1.0, 0.97],   # A-100 / Fatah-1
		"iraq": [0.7, 0.78, 0.68, 0.95, 0.89],   # BM-21 Grad
		"syria": [0.62, 0.7, 0.62, 0.92, 0.85],   # BM-21 Grad
		"afghanistan": [0.55, 0.62, 0.55, 0.9, 0.81],   # BM-21 Grad
	},
	"aaVehicle": {
		"usa": [1.0, 1.0, 1.0, 1.0, 1.0],   # M-SHORAD
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # PGZ-09
		"eu": [1.12, 1.08, 1.12, 1.0, 1.0],   # Skyranger 30
		"iran": [0.55, 0.62, 0.55, 0.9, 1.0],   # ZSU-23-4 Shilka
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Pantsir-S1
		"india": [0.86, 0.9, 0.84, 1.0, 1.0],   # 2K22 Tunguska
		"japan": [0.78, 0.84, 0.76, 0.97, 1.0],   # Type 87 SPAAG
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Korkut
		"israel": [1.12, 1.08, 1.12, 1.0, 1.0],   # Iron Dome battery
		"uk": [0.78, 0.84, 0.76, 0.97, 1.0],   # Stormer HVM
		"south_korea": [0.93, 0.95, 0.92, 1.0, 1.0],   # K30 Biho II
		"saudi": [0.86, 0.9, 0.84, 1.0, 1.0],   # Avenger / Shahine
		"brazil": [0.86, 0.9, 0.84, 1.0, 1.0],   # Gepard 1A2
		"indonesia": [0.78, 0.84, 0.76, 0.97, 1.0],   # Skyshield / RBS 70
		"ukraine": [0.86, 0.9, 0.89, 1.0, 1.0],   # Gepard / Strela-10
		"north_korea": [0.62, 0.7, 0.62, 0.92, 1.0],   # M1992 30 mm
		"egypt": [0.7, 0.78, 0.68, 0.95, 1.0],   # Avenger / Sinai-23
		"australia": [0.86, 0.9, 0.84, 1.0, 1.0],   # RBS 70 (vehicle)
		"pakistan": [0.86, 0.9, 0.84, 1.0, 1.0],   # LY-80 / Oerlikon
		"iraq": [0.93, 0.95, 0.92, 1.0, 1.0],   # Pantsir-S1
		"syria": [0.62, 0.7, 0.62, 0.92, 1.0],   # 35 mm air defence gun
		"afghanistan": [0.55, 0.62, 0.55, 0.9, 1.0],   # ZU-23-2
	},
	"samLauncher": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # Patriot PAC-3
		"china": [1.06, 1.04, 1.06, 1.0, 1.02],   # HQ-9B
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # SAMP/T NG
		"iran": [0.86, 0.9, 0.84, 1.0, 0.95],   # Bavar-373
		"russia": [1.12, 1.08, 1.12, 1.0, 1.14],   # S-400
		"india": [1.0, 1.0, 1.0, 1.0, 1.0],   # Akash-NG
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 03 Chu-SAM
		"turkiye": [0.86, 0.9, 0.84, 1.0, 0.8],   # Hisar-O
		"israel": [1.12, 1.08, 1.12, 1.0, 1.04],   # David's Sling
		"uk": [1.0, 1.0, 1.0, 1.0, 0.85],   # Sky Sabre (CAMM)
		"south_korea": [1.0, 1.0, 1.0, 1.0, 1.0],   # Cheongung II
		"saudi": [1.12, 1.08, 1.12, 1.0, 1.04],   # Patriot PAC-3
		"brazil": [0.7, 0.78, 0.68, 0.95, 0.59],   # RBS 70 NG battery
		"indonesia": [1.0, 1.0, 1.0, 1.0, 0.8],   # NASAMS
		"ukraine": [1.0, 1.0, 1.05, 1.0, 1.0],   # Patriot / IRIS-T / NASAMS
		"north_korea": [0.78, 0.84, 0.76, 0.97, 0.92],   # KN-06 (Pongae-5)
		"egypt": [1.0, 1.0, 1.0, 1.0, 1.0],   # S-300VM / IRIS-T SLM
		"australia": [1.0, 1.0, 1.0, 1.0, 0.8],   # NASAMS
		"pakistan": [1.0, 1.0, 1.0, 1.0, 1.0],   # HQ-9/P
		"iraq": [1.0, 1.0, 1.0, 1.0, 1.0],   # Cheongung II (KM-SAM)
	},
	"helicopter": {
		"usa": [1.0, 1.0, 1.0, 1.0, 1.0],   # UH-60M Black Hawk
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # Z-20
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # NH90
		"iran": [0.62, 0.7, 0.62, 0.92, 1.0],   # Shabaviz 2-75
		"russia": [0.86, 0.9, 0.84, 1.0, 1.0],   # Mi-8AMTSh
		"india": [0.86, 0.9, 0.84, 1.0, 1.0],   # Dhruv ALH
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # UH-60JA
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # T70 Black Hawk
		"israel": [1.0, 1.0, 1.0, 1.0, 1.0],   # UH-60 Yanshuf
		"uk": [1.0, 1.0, 1.0, 1.0, 1.0],   # Merlin HC4
		"south_korea": [0.93, 0.95, 0.92, 1.0, 1.0],   # KUH-1 Surion
		"saudi": [1.0, 1.0, 1.0, 1.0, 1.0],   # UH-60M
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # H225M
		"indonesia": [0.86, 0.9, 0.84, 1.0, 1.0],   # Bell 412EPI
		"ukraine": [0.78, 0.84, 0.76, 0.97, 1.0],   # Mi-8
		"north_korea": [0.62, 0.7, 0.62, 0.92, 1.0],   # Mi-8
		"egypt": [0.86, 0.9, 0.84, 1.0, 1.0],   # UH-60 / Mi-17
		"australia": [1.0, 1.0, 1.0, 1.0, 1.0],   # UH-60M
		"pakistan": [0.86, 0.9, 0.84, 1.0, 1.0],   # Mi-17
		"iraq": [0.78, 0.84, 0.76, 0.97, 1.0],   # Mi-17
		"syria": [0.62, 0.7, 0.62, 0.92, 1.0],   # Mi-17
		"afghanistan": [0.57, 0.7, 0.62, 0.92, 1.0],   # UH-60 (captured)
	},
	"gunship": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"china": [0.93, 0.95, 0.92, 1.0, 1.0],   # Z-10ME
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # Tiger
		"iran": [0.55, 0.62, 0.55, 0.9, 1.0],   # Toufan
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Ka-52M
		"india": [0.93, 0.95, 0.92, 1.0, 1.0],   # LCH Prachand
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # AH-64DJP
		"turkiye": [0.86, 0.9, 0.84, 1.0, 1.0],   # T129 ATAK
		"israel": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64 Saraf
		"uk": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"south_korea": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"saudi": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"brazil": [0.78, 0.84, 0.76, 0.97, 1.0],   # AH-2 Sabre (Mi-35)
		"indonesia": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"ukraine": [0.7, 0.78, 0.68, 0.95, 1.0],   # Mi-24
		"north_korea": [0.62, 0.7, 0.62, 0.92, 1.0],   # Mi-24
		"egypt": [1.0, 1.0, 1.0, 1.0, 1.0],   # AH-64D / Ka-52
		"australia": [1.12, 1.08, 1.12, 1.0, 1.0],   # AH-64E Apache
		"pakistan": [0.86, 0.9, 0.84, 1.0, 1.0],   # AH-1F Cobra / Z-10ME
		"iraq": [0.93, 0.95, 0.92, 1.0, 1.0],   # Mi-28NE
	},
	"jet": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-15EX Eagle II
		"china": [1.06, 1.04, 1.06, 1.0, 1.02],   # J-16
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # Rafale / Typhoon
		"iran": [0.7, 0.78, 0.68, 0.95, 0.89],   # MiG-29
		"russia": [1.06, 1.04, 1.06, 1.0, 1.02],   # Su-35S
		"india": [1.0, 1.0, 1.0, 1.0, 1.0],   # Su-30MKI
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # F-15J
		"turkiye": [0.93, 0.95, 0.92, 1.0, 0.97],   # F-16 Block 50
		"israel": [1.12, 1.08, 1.16, 1.0, 1.04],   # F-15I Ra'am
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # Typhoon FGR4
		"south_korea": [1.06, 1.04, 1.06, 1.0, 1.02],   # KF-21 Boramae / F-15K
		"saudi": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-15SA
		"brazil": [1.06, 1.04, 1.06, 1.0, 1.02],   # Gripen E
		"indonesia": [0.93, 0.95, 0.92, 1.0, 0.97],   # F-16 Block 52ID
		"ukraine": [0.86, 0.9, 0.84, 1.0, 0.95],   # F-16 / MiG-29
		"north_korea": [0.62, 0.7, 0.62, 0.92, 0.85],   # MiG-29 / MiG-21
		"egypt": [1.0, 1.0, 1.0, 1.0, 1.0],   # Rafale / F-16
		"australia": [1.06, 1.04, 1.06, 1.0, 1.02],   # F/A-18F Super Hornet
		"pakistan": [0.93, 0.95, 0.92, 1.0, 0.97],   # JF-17 Block III / F-16
		"iraq": [0.82, 0.9, 0.84, 1.0, 0.95],   # F-16IQ Fighting Falcon
	},
	"drone": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.0],   # MQ-9 Reaper
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # Wing Loong II
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # Heron TP
		"iran": [0.86, 0.9, 0.84, 1.0, 1.0],   # Mohajer-6
		"russia": [0.86, 0.9, 0.84, 1.0, 1.0],   # Orion
		"india": [0.86, 0.9, 0.84, 1.0, 1.0],   # TAPAS-BH / MQ-9B
		"japan": [1.12, 1.08, 1.12, 1.0, 1.0],   # MQ-9B SeaGuardian
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Bayraktar TB2
		"israel": [1.12, 1.08, 1.12, 1.0, 1.0],   # Hermes 900
		"uk": [1.12, 1.08, 1.12, 1.0, 1.0],   # MQ-9B Protector
		"south_korea": [0.93, 0.95, 0.92, 1.0, 1.0],   # KUS-FS
		"saudi": [1.0, 1.0, 1.0, 1.0, 1.0],   # Wing Loong II / Akinci
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # Hermes 900
		"indonesia": [0.86, 0.9, 0.84, 1.0, 1.0],   # CH-4B / Anka
		"ukraine": [0.93, 0.95, 0.92, 1.0, 1.0],   # Bayraktar TB2 / domestic
		"north_korea": [0.7, 0.78, 0.68, 0.95, 1.0],   # Saetbyol-4/9
		"egypt": [0.86, 0.9, 0.84, 1.0, 1.0],   # Wing Loong I / CH-4
		"australia": [1.12, 1.08, 1.12, 1.0, 1.0],   # MQ-9B
		"pakistan": [0.93, 0.95, 0.92, 1.0, 1.0],   # Shahpar III / Burraq
		"iraq": [0.86, 0.9, 0.84, 1.0, 1.0],   # CH-4B
		"syria": [0.7, 0.78, 0.68, 0.95, 1.0],   # Shaheen
		"afghanistan": [0.55, 0.62, 0.55, 0.9, 1.0],   # Taliban-built drone
	},
	"corvette": {
		"usa": [0.86, 0.82, 0.84, 1.08, 0.95],   # Freedom-class LCS
		"china": [0.93, 0.95, 0.92, 1.0, 0.97],   # Type 056A
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # K130 Braunschweig
		"iran": [0.78, 0.84, 0.76, 0.97, 0.92],   # Shahid Soleimani-class
		"russia": [1.0, 1.06, 1.0, 1.0, 1.0],   # Karakurt-class
		"india": [0.93, 0.95, 0.92, 1.0, 0.97],   # Kamorta-class
		"japan": [1.06, 1.04, 1.06, 1.0, 1.02],   # Mogami-class
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Ada-class
		"israel": [1.12, 1.08, 1.12, 1.0, 1.04],   # Sa'ar 6
		"uk": [0.86, 0.9, 0.84, 1.0, 0.95],   # Type 31 / River OPV
		"south_korea": [1.0, 1.0, 1.0, 1.0, 1.0],   # Daegu-class
		"saudi": [1.0, 1.0, 1.0, 1.0, 1.0],   # Al Jubail-class
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # Tamandare-class
		"indonesia": [0.93, 0.95, 0.92, 1.0, 0.97],   # Martadinata-class
		"ukraine": [0.62, 0.7, 0.62, 0.92, 0.85],   # Island-class patrol boat
		"north_korea": [0.7, 0.78, 0.68, 0.95, 0.89],   # Amnok-class
		"egypt": [1.0, 1.0, 1.0, 1.0, 1.0],   # Gowind 2500
		"australia": [0.93, 0.95, 0.92, 1.0, 0.97],   # Anzac-class
		"pakistan": [1.0, 1.0, 1.0, 1.0, 1.0],   # Babur-class (MILGEM)
		"iraq": [0.7, 0.78, 0.68, 0.95, 0.89],   # Musa Ben Nussair-class
	},
	"destroyer": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # Arleigh Burke-class
		"china": [1.12, 1.08, 1.12, 1.0, 1.04],   # Type 055
		"eu": [1.06, 1.04, 1.06, 1.0, 1.02],   # Horizon-class
		"iran": [0.7, 0.78, 0.68, 0.95, 0.89],   # Moudge-class
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Admiral Gorshkov-class
		"india": [1.06, 1.04, 1.06, 1.0, 1.02],   # Visakhapatnam-class
		"japan": [1.12, 1.08, 1.12, 1.0, 1.04],   # Maya-class
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Istanbul-class
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # Type 45
		"south_korea": [1.12, 1.08, 1.12, 1.0, 1.04],   # Sejong the Great-class
		"australia": [1.06, 1.04, 1.06, 1.0, 1.02],   # Hobart-class
	},
	"submarine": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # Virginia-class
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 039C
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # Type 212CD
		"iran": [0.7, 0.78, 0.68, 0.95, 0.89],   # Fateh-class
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Improved Kilo
		"india": [1.0, 1.0, 1.0, 1.0, 1.0],   # Kalvari-class
		"japan": [1.12, 1.08, 1.12, 1.0, 1.04],   # Taigei-class
		"turkiye": [1.06, 1.04, 1.06, 1.0, 1.02],   # Reis-class
		"israel": [1.12, 1.08, 1.12, 1.0, 1.04],   # Dolphin II
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # Astute-class
		"south_korea": [1.06, 1.04, 1.06, 1.0, 1.02],   # Dosan Ahn Changho-class
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # Riachuelo-class
		"indonesia": [0.93, 0.95, 0.92, 1.0, 0.97],   # Nagapasa-class
		"north_korea": [0.62, 0.7, 0.62, 0.92, 0.85],   # Romeo-class
		"egypt": [0.93, 0.95, 0.92, 1.0, 0.97],   # Type 209/1400
		"australia": [0.93, 0.95, 0.92, 1.0, 0.97],   # Collins-class
		"pakistan": [0.86, 0.9, 0.84, 1.0, 0.95],   # Agosta 90B
	},
	"stealthFighter": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-35A Lightning II
		"china": [1.06, 1.04, 1.06, 1.0, 1.02],   # J-20
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-35A
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Su-57
		"india": [0.86, 0.9, 0.84, 1.0, 0.95],   # AMCA
		"japan": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-35A
		"turkiye": [0.93, 0.95, 0.92, 1.0, 0.97],   # KAAN
		"israel": [1.12, 1.08, 1.16, 1.0, 1.04],   # F-35I Adir
		"uk": [1.12, 1.08, 1.12, 0.95, 1.04],   # F-35B Lightning
		"south_korea": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-35A
		"australia": [1.12, 1.08, 1.12, 1.0, 1.04],   # F-35A
	},
	"atgmTeam": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # Javelin team
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # HJ-12 team
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # MMP team
		"iran": [0.86, 0.9, 0.84, 1.0, 0.95],   # Dehlavieh team
		"russia": [1.0, 1.0, 1.0, 1.0, 1.0],   # Kornet team
		"india": [0.93, 0.95, 0.92, 1.0, 0.97],   # MPATGM team
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 01 LMAT team
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # OMTAS team
		"israel": [1.12, 1.08, 1.12, 1.0, 1.04],   # Spike team
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # Javelin / NLAW team
		"south_korea": [1.06, 1.04, 1.06, 1.0, 1.02],   # Raybolt team
		"saudi": [1.0, 1.0, 1.0, 1.0, 1.0],   # TOW-2 / Javelin team
		"brazil": [0.86, 0.9, 0.84, 1.0, 0.95],   # MSS-1.2 team
		"indonesia": [1.06, 1.04, 1.06, 1.0, 1.02],   # Javelin team
		"ukraine": [1.06, 1.04, 1.11, 1.0, 1.02],   # Stugna-P / Javelin team
		"north_korea": [0.86, 0.9, 0.84, 1.0, 0.95],   # Bulsae-4 team
		"egypt": [0.93, 0.95, 0.92, 1.0, 0.97],   # TOW / Kornet team
		"australia": [1.12, 1.08, 1.12, 1.0, 1.04],   # Javelin team
		"pakistan": [0.78, 0.84, 0.76, 0.97, 0.92],   # Baktar-Shikan team
		"iraq": [0.93, 0.95, 0.92, 1.0, 0.97],   # Kornet team
		"syria": [0.86, 0.9, 0.84, 1.0, 0.95],   # Kornet team
		"afghanistan": [0.7, 0.78, 0.68, 0.95, 0.89],   # RPG-29 team
	},
	"manpads": {
		"usa": [1.12, 1.08, 1.12, 1.0, 1.04],   # Stinger team
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # FN-16 team
		"eu": [1.12, 1.08, 1.12, 1.0, 1.04],   # Mistral 3 team
		"iran": [0.86, 0.9, 0.84, 1.0, 0.95],   # Misagh-3 team
		"russia": [1.06, 1.04, 1.06, 1.0, 1.02],   # Verba team
		"india": [0.93, 0.95, 0.92, 1.0, 0.97],   # Igla-S / VSHORADS team
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # Type 91 Kin-SAM team
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # Sungur team
		"israel": [1.12, 1.08, 1.12, 1.0, 1.04],   # Stinger team
		"uk": [1.12, 1.08, 1.12, 1.0, 1.04],   # Starstreak / Martlet team
		"south_korea": [1.0, 1.0, 1.0, 1.0, 1.0],   # Chiron team
		"saudi": [1.06, 1.04, 1.06, 1.0, 1.02],   # Stinger / Mistral team
		"brazil": [1.0, 1.0, 1.0, 1.0, 1.0],   # RBS 70 NG / Igla-S team
		"indonesia": [0.93, 0.95, 0.92, 1.0, 0.97],   # QW-3 / Mistral team
		"ukraine": [1.06, 1.04, 1.06, 1.0, 1.02],   # Stinger / Piorun team
		"north_korea": [0.86, 0.9, 0.84, 1.0, 0.95],   # HT-16PGJ team
		"egypt": [0.86, 0.9, 0.84, 1.0, 0.95],   # Ain Sakr / Stinger team
		"australia": [1.0, 1.0, 1.0, 1.0, 1.0],   # RBS 70 team
		"pakistan": [0.93, 0.95, 0.92, 1.0, 0.97],   # Anza Mk-III team
		"iraq": [0.86, 0.9, 0.84, 1.0, 0.95],   # Igla team
		"syria": [0.78, 0.84, 0.76, 0.97, 0.92],   # Igla / Strela team
		"afghanistan": [0.62, 0.7, 0.62, 0.92, 0.85],   # Strela-2 team
	},
	"infantry": {
		"usa": [1.06, 1.04, 1.06, 1.0, 1.0],   # infantry
		"china": [1.0, 1.0, 1.0, 1.0, 1.0],   # infantry
		"eu": [1.0, 1.0, 1.0, 1.0, 1.0],   # infantry
		"iran": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"russia": [0.97, 0.97, 0.96, 1.0, 1.0],   # infantry
		"india": [0.97, 0.97, 0.96, 1.0, 1.0],   # infantry
		"japan": [1.0, 1.0, 1.0, 1.0, 1.0],   # infantry
		"turkiye": [1.0, 1.0, 1.0, 1.0, 1.0],   # infantry
		"israel": [1.06, 1.04, 1.06, 1.0, 1.0],   # infantry
		"uk": [1.06, 1.04, 1.06, 1.0, 1.0],   # infantry
		"south_korea": [1.03, 1.02, 1.03, 1.0, 1.0],   # infantry
		"saudi": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"brazil": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"indonesia": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"ukraine": [1.03, 1.02, 1.03, 1.0, 1.0],   # infantry
		"north_korea": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"egypt": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"australia": [1.06, 1.04, 1.06, 1.0, 1.0],   # infantry
		"pakistan": [0.97, 0.97, 0.96, 1.0, 1.0],   # infantry
		"iraq": [0.93, 0.95, 0.92, 1.0, 1.0],   # infantry
		"syria": [1.0, 0.95, 0.92, 1.0, 1.0],   # infantry
		"afghanistan": [1.0, 0.95, 0.92, 1.0, 1.0],   # infantry
	},
}

## The figures for unit `key` of nation `id` (all 1.0 for a unit or nation not in the table).
static func of(id: String, key: String) -> Dictionary:
	var row: Array = QUALITY.get(CLASS_OF.get(key, key), {}).get(id, [1.0, 1.0, 1.0, 1.0, 1.0])
	return {"hp": float(row[0]), "damage": float(row[1]), "accuracy": float(row[2]), "speed": float(row[3]), "range": float(row[4])}

## A nation's next system for a class, in service once it is researched: the
## M1E3 Abrams (prototype unveiled January 2026, operational tests from summer
## 2026, a production decision around 2027): 60 t instead of the SEPv3's 78
## (+12% speed), an autoloader (20% faster reloads), an uncrewed turret with the
## crew of three in an armoured capsule and the Iron Fist (XM251) active
## protection built in (half the missiles, rockets and kamikaze drones fired at
## it stopped, without the Active Protection discovery), new sights. Rivals
## field it once their technology reaches its era. Russia's from the war in
## Ukraine (national_capabilities.gd): the Su-34 with UMPK glide bombs (+50%
## range, +20% damage) and fibre-optic FPV drones (no jammer stops them, +30%
## range). "flags" are set on each unit built.
const UPGRADES := {
	"tank": {"usa": {"research": "nextGenAbrams", "name": "M1E3 Abrams", "figures": [1.3, 1.15, 1.2, 1.06, 1.0], "cooldown": 0.8, "flags": {"aps_builtin": true}}},
	"jet": {"russia": {"research": "glideBombs", "name": "Su-34 (UMPK glide bombs)", "figures": [1.06, 1.2, 1.06, 0.95, 1.5]}},
	"fpvTeam": {"russia": {"research": "fibreOpticDrones", "name": "Fibre-optic FPV team", "figures": [1.0, 1.0, 1.05, 1.0, 1.3], "flags": {"fibre_optic": true}}},
}
const DISCOVERIES := {
	"nextGenAbrams": {"name": "M1E3 Abrams", "cost": 750, "branch": "army", "era": 4, "nation": "blue",
		"reqDiscovery": "activeProtection", "reqBuilding": "tankFactory", "fx": {"nextGenAbrams": 1.0},
		"desc": "United States only. The next Abrams: 60 t instead of 78 (+12% speed), an autoloader (20% faster reloads), the crew in an armoured capsule under an uncrewed turret, Iron Fist active protection built in (stops half the missiles and drones fired at it) and new sights. Every tank built afterwards is an M1E3."},
}

## Registers the discoveries (modern_warfare.apply, after national_variants).
static func apply(w: Node) -> void:
	var discoveries: Dictionary = w.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)

## The upgrade nation `id`'s unit `key` of `owner` has in service, or {}.
static func upgrade(w: Node, owner: int, id: String, key: String) -> Dictionary:
	var up: Dictionary = UPGRADES.get(key, {}).get(id, {})   # (the unit itself: a bomber is not a jet here)
	if up.is_empty() or w.get("research") == null or w.research == null:
		return {}
	if owner == 0:
		return up if w.research.bonus(up.research) >= 1.0 else {}
	return up if w.research.ai_tech(owner) >= float(w.research.era_of(up.research)) * 2.0 else {}

## The figures for one unit as it enters service: the nation's system, or the
## system that replaces it once researched (with its reload and flags).
static func of_unit(w: Node, owner: int, id: String, key: String) -> Dictionary:
	var up := upgrade(w, owner, id, key)
	if up.is_empty():
		return of(id, key)
	var row: Array = up.figures
	return {"hp": float(row[0]), "damage": float(row[1]), "accuracy": float(row[2]), "speed": float(row[3]), "range": float(row[4]),
		"cooldown": float(up.get("cooldown", 1.0)), "flags": up.get("flags", {}), "name": str(up.name)}

## The player's unit card and build list name the system in service (research._recompute).
static func rename(w: Node) -> void:
	var id: String = load("res://scripts/factions.gd").identity(w, 0)   # (load: factions.gd preloads this file)
	for cls in UPGRADES:
		if UPGRADES[cls].has(id) and w.unit_defs.has(cls):
			var up := upgrade(w, 0, id, cls)
			if not up.is_empty() and w.unit_defs[cls].name != up.name:
				w.unit_defs[cls].name = up.name
