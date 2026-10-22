# Unit roster for Codex: every vehicle, aircraft and ship, as each nation fields it

Generated from the game's own data (31 nations) by native/tools/roster/make_roster.py. Read `native/CODEX-ART-REQUEST.md` (Tier 7) first for the file conventions; this file says **which models**.

**One model per row.** The model name is the designation the nation fields; build that real vehicle's general look, generic and without national marks. Where several nations share a name, build it once. Where you do not know the real vehicle, build a plausible generic one of its class and mark `"approximate": true` in the manifest.

**File name:** `native/godot/assets/art/<vehicles|aircraft|ships>/<key>__<slug>.glb`. The game finds a model by the nation's own name for the unit, and a variant name finds its base vehicle's file ("Leclerc XLR" finds `leclerc`), so a variant needs a file of its own only if it looks different.

The last column says whether the file already exists.

## P1 Main battle tanks

Tracked, turreted. Nodes as Tier 7: Hull, Turret, Gun, Muzzle, Wheel_L0.., Wheel_R0.., Sprocket_*, Idler_*, Roller_*, Track_L/R, Wreck.

### `tank` (M1A2 SEPv3 Abrams): 30 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Altay | turkiye | `tank__altay` | done |
| 2 | Ariete | italy | `tank__ariete` | TO DO |
| 3 | Arjun Mk1 | india | `tank__arjun_mk1` | done |
| 4 | Challenger 2 | uk | `tank__challenger_2` | done |
| 5 | Chonma-216 | north_korea | `tank__chonma_216` | done |
| 6 | K2 Black Panther | south_korea | `tank__k2_black_panther` | done |
| 7 | Karrar | iran | `tank__karrar` | done |
| 8 | Leclerc XLR | france | `tank__leclerc_xlr` | done |
| 9 | Leopard 1A5BR | brazil | `tank__leopard_1a5br` | done |
| 10 | Leopard 2A4 | indonesia | `tank__leopard_2a4` | done |
| 11 | Leopard 2A6 | netherlands | `tank__leopard_2a6` | TO DO |
| 12 | Leopard 2A7V | germany | `tank__leopard_2a7v` | done |
| 13 | M1A1 Abrams | egypt | `tank__m1a1_abrams` | done |
| 14 | M1A1M Abrams | iraq | `tank__m1a1m_abrams` | done |
| 15 | M1A2 SEPv3 Abrams | australia, usa | `tank__m1a2_sepv3_abrams` | done |
| 16 | M1A2S Abrams | saudi | `tank__m1a2s_abrams` | done |
| 17 | Merkava Mk 4 | israel | `tank__merkava_mk_4` | done |
| 18 | T-55 / T-62 | yemen | `tank__t_55_t_62` | done |
| 19 | T-62 (captured) | afghanistan | `tank__t_62_captured` | done |
| 20 | T-62 / T-72 (captured) | houthis | `tank__t_62_t_72_captured` | done |
| 21 | T-64BV | ukraine | `tank__t_64bv` | done |
| 22 | T-72 | syria | `tank__t_72` | done |
| 23 | T-72 / Al-Bashir | sudan | `tank__t_72_al_bashir` | done |
| 24 | T-72AV | south_sudan | `tank__t_72av` | done |
| 25 | T-72UA1 / T-72B | ethiopia | `tank__t_72ua1_t_72b` | done |
| 26 | T-90M Proryv | russia | `tank__t_90m_proryv` | done |
| 27 | Type 10 | japan | `tank__type_10` | done |
| 28 | Type 99A | china | `tank__type_99a` | done |
| 29 | VT-4 / Vickers Mk 3 | nigeria | `tank__vt_4_vickers_mk_3` | done |
| 30 | VT-4 Haider | pakistan | `tank__vt_4_haider` | done |

## P2 Armoured personnel carriers, infantry fighting vehicles and other armour

Tracked or wheeled. Turret and Gun only where the real vehicle has them; a recovery vehicle names its boom Boom and its spade Spade.

### `apc` (Stryker): 29 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Anoa | indonesia | `apc__anoa` | done |
| 2 | BMP-1 | syria | `apc__bmp_1` | done |
| 3 | BMP-2 / BTR-80 (captured) | houthis | `apc__bmp_2_btr_80_captured` | done |
| 4 | Boxer | germany, netherlands, uk | `apc__boxer` | done |
| 5 | Boxer CRV | australia | `apc__boxer_crv` | done |
| 6 | BTR-3UN / Proforce Ara | nigeria | `apc__btr_3un_proforce_ara` | done |
| 7 | BTR-4 | ukraine | `apc__btr_4` | done |
| 8 | BTR-4 / M113 | iraq | `apc__btr_4_m113` | done |
| 9 | BTR-60 / BMP-1 | ethiopia | `apc__btr_60_bmp_1` | done |
| 10 | BTR-60 / MRAP | yemen | `apc__btr_60_mrap` | done |
| 11 | BTR-80 / Typhoon MRAP | south_sudan | `apc__btr_80_typhoon_mrap` | done |
| 12 | BTR-80A / BTR-70 | sudan | `apc__btr_80a_btr_70` | done |
| 13 | BTR-82A | russia | `apc__btr_82a` | done |
| 14 | Eitan | israel | `apc__eitan` | done |
| 15 | Griffon | france | `apc__griffon` | TO DO |
| 16 | Humvee (captured) | afghanistan | `apc__humvee_captured` | done |
| 17 | K808 APC | south_korea | `apc__k808_apc` | done |
| 18 | LAV 700 | saudi | `apc__lav_700` | done |
| 19 | M-2010 | north_korea | `apc__m_2010` | done |
| 20 | M113 / Fahd | egypt | `apc__m113_fahd` | done |
| 21 | Pars | turkiye | `apc__pars` | done |
| 22 | Rakhsh | iran | `apc__rakhsh` | done |
| 23 | Saad / M113 | pakistan | `apc__saad_m113` | done |
| 24 | Stryker | usa | `apc__stryker` | done |
| 25 | Type 96 APC | japan | `apc__type_96_apc` | done |
| 26 | VBM Freccia | italy | `apc__vbm_freccia` | TO DO |
| 27 | VBTP Guarani | brazil | `apc__vbtp_guarani` | done |
| 28 | WhAP | india | `apc__whap` | done |
| 29 | ZBL-08 | china | `apc__zbl_08` | done |

### `ifv` (M2A4 Bradley): 15 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | ACV-15 | turkiye | `ifv__acv_15` | done |
| 2 | BMP-2 | iran | `ifv__bmp_2` | done |
| 3 | BMP-2 Sarath | india | `ifv__bmp_2_sarath` | done |
| 4 | BMP-3 | russia | `ifv__bmp_3` | done |
| 5 | CV9035NL | netherlands | `ifv__cv9035nl` | TO DO |
| 6 | Dardo IFV | italy | `ifv__dardo_ifv` | TO DO |
| 7 | K21 IFV | south_korea | `ifv__k21_ifv` | done |
| 8 | M2A2 Bradley | saudi, ukraine | `ifv__m2a2_bradley` | done |
| 9 | M2A4 Bradley | usa | `ifv__m2a4_bradley` | done |
| 10 | Pandur II IFV | indonesia | `ifv__pandur_ii_ifv` | done |
| 11 | Puma IFV | germany | `ifv__puma_ifv` | done |
| 12 | Type 89 IFV | japan | `ifv__type_89_ifv` | done |
| 13 | VBCI | france | `ifv__vbci` | TO DO |
| 14 | Warrior | uk | `ifv__warrior` | done |
| 15 | ZBD-04A | china | `ifv__zbd_04a` | done |

### `heavyAPC` (Heavy Armoured Carrier): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Namer | israel | `heavyAPC__namer` | done |

### `bushmaster` (Bushmaster): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Bushmaster | australia | `bushmaster__bushmaster` | done |

### `reconVehicle` (M3 Bradley Scout): 7 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Centauro II | italy | `reconVehicle__centauro_ii` | TO DO |
| 2 | EBRC Jaguar | france | `reconVehicle__ebrc_jaguar` | TO DO |
| 3 | Fennek | germany, netherlands | `reconVehicle__fennek` | done |
| 4 | Hawkei | australia | `reconVehicle__hawkei` | done |
| 5 | Jackal | uk | `reconVehicle__jackal` | done |
| 6 | Komodo Scout | indonesia | `reconVehicle__komodo_scout` | done |
| 7 | M3 Bradley Scout | usa | `reconVehicle__m3_bradley_scout` | done |

### `recoveryVehicle` (M88A2 Hercules): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Armoured Recovery Vehicle | afghanistan, australia, brazil, china, egypt, france, indonesia, iran, iraq, israel, italy, netherlands, north_korea, pakistan, saudi, syria, turkiye | `recoveryVehicle__armoured_recovery_vehicle` | done |
| 2 | Bergepanzer 3 Buffel | germany | `recoveryVehicle__bergepanzer_3_buffel` | done |
| 3 | BREM-1 | russia, ukraine | `recoveryVehicle__brem_1` | done |
| 4 | Challenger ARRV | uk | `recoveryVehicle__challenger_arrv` | done |
| 5 | K1 ARV | south_korea | `recoveryVehicle__k1_arv` | done |
| 6 | M88A2 Hercules | usa | `recoveryVehicle__m88a2_hercules` | done |
| 7 | Type 90 ARV | japan | `recoveryVehicle__type_90_arv` | done |
| 8 | WZT-3 | india | `recoveryVehicle__wzt_3` | done |

### `mineClearer` (M1150 Assault Breacher): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Keiler | germany | `mineClearer__keiler` | done |
| 2 | M1150 Assault Breacher | usa | `mineClearer__m1150_assault_breacher` | done |
| 3 | Mine-clearing Vehicle | afghanistan, australia, brazil, china, egypt, france, india, indonesia, iran, iraq, israel, italy, japan, netherlands, north_korea, pakistan, saudi, south_korea, syria, turkiye | `mineClearer__mine_clearing_vehicle` | done |
| 4 | Trojan AVRE | uk | `mineClearer__trojan_avre` | done |
| 5 | UR-77 Meteorit | russia, ukraine | `mineClearer__ur_77_meteorit` | done |

### `mineLayer` (M139 Volcano): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Engineer Minelayer | afghanistan, australia, brazil, china, egypt, france, india, indonesia, iran, iraq, israel, italy, japan, netherlands, north_korea, pakistan, saudi, south_korea, syria, turkiye, uk | `mineLayer__engineer_minelayer` | done |
| 2 | GMZ-3 | ukraine | `mineLayer__gmz_3` | done |
| 3 | ISDM Zemledelie | russia | `mineLayer__isdm_zemledelie` | done |
| 4 | M139 Volcano | usa | `mineLayer__m139_volcano` | done |
| 5 | Skorpion Mine Dispenser | germany | `mineLayer__skorpion_mine_dispenser` | done |

### `ewVehicle` (EW Vehicle): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Elbit EW truck | israel | `ewVehicle__elbit_ew_truck` | done |
| 2 | EW Vehicle | france, germany, india, japan, north_korea, uk, ukraine, usa | `ewVehicle__ew_vehicle` | done |
| 3 | KORAL | turkiye | `ewVehicle__koral` | done |
| 4 | Krasukha-4 | russia | `ewVehicle__krasukha_4` | done |
| 5 | Type 2 EW truck | china | `ewVehicle__type_2_ew_truck` | done |

## P3 Artillery and rocket launchers

Self-propelled: Hull, Turret, Gun (elevates) with Muzzle. Rocket launchers: Hull, Launcher (pod or rack: axis X to elevate, axis Y turntable if it traverses), Muzzle marker at the front of the pod. Towed guns: Carriage, Gun (elevates), Trail_L/R (the legs), Wheel_L0/R0.

### `artillery` (M109A7 Paladin): 26 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | 2S1 Gvozdika / D-30 | syria | `artillery__2s1_gvozdika_d_30` | TO DO |
| 2 | 2S19 Msta-S | russia | `artillery__2s19_msta_s` | TO DO |
| 3 | 2S3 / PzH 2000 / Krab | ukraine | `artillery__2s3_pzh_2000_krab` | TO DO |
| 4 | AS-90 / Archer | uk | `artillery__as_90_archer` | TO DO |
| 5 | AS9 Huntsman | australia | `artillery__as9_huntsman` | TO DO |
| 6 | CAESAR | france, indonesia, saudi | `artillery__caesar` | TO DO |
| 7 | D-30 (towed) | afghanistan | `artillery__d_30_towed` | TO DO |
| 8 | D-30 / 2S1 | south_sudan | `artillery__d_30_2s1` | TO DO |
| 9 | D-30 / 2S1 (captured) | houthis | `artillery__d_30_2s1_captured` | TO DO |
| 10 | D-30 / Khalifa | sudan | `artillery__d_30_khalifa` | TO DO |
| 11 | D-30 / M109A5 | yemen | `artillery__d_30_m109a5` | TO DO |
| 12 | K9 Vajra-T | india | `artillery__k9_vajra_t` | TO DO |
| 13 | K9A1 Thunder | south_korea | `artillery__k9a1_thunder` | TO DO |
| 14 | M109A5 | egypt, iraq | `artillery__m109a5` | TO DO |
| 15 | M109A5 / SH-15 | pakistan | `artillery__m109a5_sh_15` | TO DO |
| 16 | M109A5+ BR | brazil | `artillery__m109a5_br` | TO DO |
| 17 | M109A7 Paladin | usa | `artillery__m109a7_paladin` | TO DO |
| 18 | M1989 Koksan | north_korea | `artillery__m1989_koksan` | TO DO |
| 19 | PLZ-05 | china | `artillery__plz_05` | TO DO |
| 20 | PzH 2000 | germany, italy, netherlands | `artillery__pzh_2000` | TO DO |
| 21 | Raad-2 | iran | `artillery__raad_2` | TO DO |
| 22 | Roem | israel | `artillery__roem` | TO DO |
| 23 | SH-15 / D-30 | ethiopia | `artillery__sh_15_d_30` | TO DO |
| 24 | SH-5 / Palmaria | nigeria | `artillery__sh_5_palmaria` | TO DO |
| 25 | T-155 Firtina | turkiye | `artillery__t_155_firtina` | TO DO |
| 26 | Type 99 SPH | japan | `artillery__type_99_sph` | TO DO |

### `towedHowitzer` (M777): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | FH70 | japan | `towedHowitzer__fh70` | TO DO |
| 2 | L118 Light Gun | uk | `towedHowitzer__l118_light_gun` | TO DO |
| 3 | M777 | australia, india, ukraine, usa | `towedHowitzer__m777` | TO DO |

### `wheeledHowitzer` (Wheeled Self-propelled Howitzer): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | 2S43 Malva | russia | `wheeledHowitzer__2s43_malva` | TO DO |
| 2 | Archer | uk | `wheeledHowitzer__archer` | TO DO |
| 3 | CAESAR | france, indonesia, ukraine | `wheeledHowitzer__caesar` | TO DO |
| 4 | PCL-181 | china | `wheeledHowitzer__pcl_181` | TO DO |
| 5 | SH-15 | ethiopia, pakistan | `wheeledHowitzer__sh_15` | TO DO |
| 6 | Type 19 Howitzer | japan | `wheeledHowitzer__type_19_howitzer` | TO DO |

### `k9` (K9 Thunder): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | K9 Thunder | south_korea | `k9__k9_thunder` | TO DO |

### `mlrs` (M270 MLRS): 24 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | A-100 / Fatah-1 | pakistan | `mlrs__a_100_fatah_1` | TO DO |
| 2 | ASTROS II | saudi | `mlrs__astros_ii` | TO DO |
| 3 | ASTROS II / RM-70 | indonesia | `mlrs__astros_ii_rm_70` | TO DO |
| 4 | ASTROS II Mk6 | brazil | `mlrs__astros_ii_mk6` | TO DO |
| 5 | BM-21 / Badr rockets | houthis | `mlrs__bm_21_badr_rockets` | TO DO |
| 6 | BM-21 / Taka | sudan | `mlrs__bm_21_taka` | TO DO |
| 7 | BM-21 Grad | afghanistan, ethiopia, iraq, syria | `mlrs__bm_21_grad` | TO DO |
| 8 | BM-21 Sakr | egypt | `mlrs__bm_21_sakr` | TO DO |
| 9 | BM-27 / HIMARS | ukraine | `mlrs__bm_27_himars` | TO DO |
| 10 | BM-30 Smerch | russia | `mlrs__bm_30_smerch` | TO DO |
| 11 | Fajr-5 | iran | `mlrs__fajr_5` | TO DO |
| 12 | K239 Chunmoo | south_korea | `mlrs__k239_chunmoo` | TO DO |
| 13 | KN-25 / M1991 | north_korea | `mlrs__kn_25_m1991` | TO DO |
| 14 | LRU | france | `mlrs__lru` | TO DO |
| 15 | Lynx | israel | `mlrs__lynx` | TO DO |
| 16 | M142 HIMARS | australia | `mlrs__m142_himars` | TO DO |
| 17 | M270 (JGSDF) | japan | `mlrs__m270_jgsdf` | TO DO |
| 18 | M270 MLRS | italy, usa | `mlrs__m270_mlrs` | TO DO |
| 19 | M270A2 MLRS | uk | `mlrs__m270a2_mlrs` | TO DO |
| 20 | MARS II | germany | `mlrs__mars_ii` | TO DO |
| 21 | PHL-03 | china | `mlrs__phl_03` | TO DO |
| 22 | Pinaka | india | `mlrs__pinaka` | TO DO |
| 23 | PULS | netherlands | `mlrs__puls` | TO DO |
| 24 | T-122 Sakarya | turkiye | `mlrs__t_122_sakarya` | TO DO |

### `himars` (HIMARS): 16 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Chunmoo (guided CGR-080) | south_korea | `himars__chunmoo_guided_cgr_080` | TO DO |
| 2 | EuroPULS | germany | `himars__europuls` | TO DO |
| 3 | Fatah-II | pakistan | `himars__fatah_ii` | TO DO |
| 4 | Fath-360 launcher | iran | `himars__fath_360_launcher` | TO DO |
| 5 | Guided Pinaka | india | `himars__guided_pinaka` | TO DO |
| 6 | Guided Rocket Launcher | italy, netherlands | `himars__guided_rocket_launcher` | TO DO |
| 7 | HIMARS | usa | `himars__himars` | TO DO |
| 8 | KN-25 (600 mm guided) | north_korea | `himars__kn_25_600_mm_guided` | TO DO |
| 9 | LRU (GMLRS) | france | `himars__lru_gmlrs` | TO DO |
| 10 | M142 HIMARS | australia, ukraine | `himars__m142_himars` | TO DO |
| 11 | M270 GMLRS | japan | `himars__m270_gmlrs` | TO DO |
| 12 | M270A2 (GMLRS) | uk | `himars__m270a2_gmlrs` | TO DO |
| 13 | PCH-191 | china | `himars__pch_191` | TO DO |
| 14 | PULS | israel | `himars__puls` | TO DO |
| 15 | Tornado-S | russia | `himars__tornado_s` | TO DO |
| 16 | TRLG-230 | turkiye | `himars__trlg_230` | TO DO |

### `heavyRocket` (Heavy Rocket Launcher): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Heavy Rocket Launcher | north_korea | `heavyRocket__heavy_rocket_launcher` | TO DO |

### `tos1a` (TOS-1A Solntsepyok): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | TOS-1A Solntsepyok | iraq, russia | `tos1a__tos_1a_solntsepyok` | TO DO |

### `directFire` (Mobile Direct-fire Gun): 4 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | AMX-10 RC | ukraine | `directFire__amx_10_rc` | TO DO |
| 2 | EE-9 Cascavel | brazil | `directFire__ee_9_cascavel` | TO DO |
| 3 | Harimau | indonesia | `directFire__harimau` | TO DO |
| 4 | Type 16 MCV | japan | `directFire__type_16_mcv` | TO DO |

### `coastalASM` (NMESIS): 7 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Ghader Coastal Battery | iran | `coastalASM__ghader_coastal_battery` | TO DO |
| 2 | K-300P Bastion-P | russia | `coastalASM__k_300p_bastion_p` | TO DO |
| 3 | NMESIS | usa | `coastalASM__nmesis` | TO DO |
| 4 | NSM Coastal Defence System | germany | `coastalASM__nsm_coastal_defence_system` | TO DO |
| 5 | RK-360MC Neptune | ukraine | `coastalASM__rk_360mc_neptune` | TO DO |
| 6 | Type 12 SSM | japan | `coastalASM__type_12_ssm` | TO DO |
| 7 | YJ-62 Coastal Battery | china | `coastalASM__yj_62_coastal_battery` | TO DO |

### `brahmos` (BrahMos Battery): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | BrahMos Battery | india | `brahmos__brahmos_battery` | TO DO |

### `df17` (DF-17 Launcher): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | DF-17 Launcher | china | `df17__df_17_launcher` | TO DO |

### `shahedLauncher` (Shahed Launcher): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Geran-2 Launcher | russia | `shahedLauncher__geran_2_launcher` | TO DO |
| 2 | Shahed Launcher | iran | `shahedLauncher__shahed_launcher` | TO DO |

## P4 Air defence and radars

Hull or truck, Launcher (elevates about X, turntable about Y), Radar (spins about Y), Muzzle markers at each missile tube or barrel (Muzzle_0, Muzzle_1, ...).

### `aaVehicle` (M-SHORAD): 25 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | 2K22 Tunguska | india | `aaVehicle__2k22_tunguska` | TO DO |
| 2 | 35 mm air defence gun | syria | `aaVehicle__35_mm_air_defence_gun` | TO DO |
| 3 | Avenger / Shahine | saudi | `aaVehicle__avenger_shahine` | TO DO |
| 4 | Avenger / Sinai-23 | egypt | `aaVehicle__avenger_sinai_23` | TO DO |
| 5 | Crotale NG | france | `aaVehicle__crotale_ng` | TO DO |
| 6 | Gepard / Strela-10 | ukraine | `aaVehicle__gepard_strela_10` | TO DO |
| 7 | Gepard 1A2 | brazil | `aaVehicle__gepard_1a2` | TO DO |
| 8 | Iron Dome battery | israel | `aaVehicle__iron_dome_battery` | TO DO |
| 9 | K30 Biho II | south_korea | `aaVehicle__k30_biho_ii` | TO DO |
| 10 | Korkut | turkiye | `aaVehicle__korkut` | TO DO |
| 11 | LY-80 / Oerlikon | pakistan | `aaVehicle__ly_80_oerlikon` | TO DO |
| 12 | M-SHORAD | usa | `aaVehicle__m_shorad` | TO DO |
| 13 | M1992 30 mm | north_korea | `aaVehicle__m1992_30_mm` | TO DO |
| 14 | Pantsir-S1 | ethiopia, iraq, russia | `aaVehicle__pantsir_s1` | TO DO |
| 15 | PGZ-09 | china | `aaVehicle__pgz_09` | TO DO |
| 16 | RBS 70 (vehicle) | australia | `aaVehicle__rbs_70_vehicle` | TO DO |
| 17 | SIDAM 25 | italy | `aaVehicle__sidam_25` | TO DO |
| 18 | Skyranger 30 | germany, netherlands | `aaVehicle__skyranger_30` | TO DO |
| 19 | Skyshield / RBS 70 | indonesia | `aaVehicle__skyshield_rbs_70` | TO DO |
| 20 | Stormer HVM | uk | `aaVehicle__stormer_hvm` | TO DO |
| 21 | Type 87 SPAAG | japan | `aaVehicle__type_87_spaag` | TO DO |
| 22 | ZSU-23-4 Shilka | iran, nigeria | `aaVehicle__zsu_23_4_shilka` | TO DO |
| 23 | ZU-23-2 | afghanistan, south_sudan, sudan | `aaVehicle__zu_23_2` | TO DO |
| 24 | ZU-23-2 (technical) | yemen | `aaVehicle__zu_23_2_technical` | TO DO |
| 25 | ZU-23-2 / Saqr (358) | houthis | `aaVehicle__zu_23_2_saqr_358` | TO DO |

### `samLauncher` (Patriot PAC-3): 19 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Akash | india | `samLauncher__akash` | TO DO |
| 2 | Bavar-373 | iran | `samLauncher__bavar_373` | TO DO |
| 3 | Cheongung II | south_korea | `samLauncher__cheongung_ii` | TO DO |
| 4 | David's Sling | israel | `samLauncher__david_s_sling` | TO DO |
| 5 | Hisar-O | turkiye | `samLauncher__hisar_o` | TO DO |
| 6 | HQ-9/P | pakistan | `samLauncher__hq_9_p` | TO DO |
| 7 | HQ-9B | china | `samLauncher__hq_9b` | TO DO |
| 8 | KN-06 (Pongae-5) | north_korea | `samLauncher__kn_06_pongae_5` | TO DO |
| 9 | NASAMS | australia, indonesia | `samLauncher__nasams` | TO DO |
| 10 | Patriot / IRIS-T / NASAMS | ukraine | `samLauncher__patriot_iris_t_nasams` | TO DO |
| 11 | Patriot PAC-3 | netherlands, saudi, usa | `samLauncher__patriot_pac_3` | TO DO |
| 12 | Patriot PAC-3 MSE | germany | `samLauncher__patriot_pac_3_mse` | TO DO |
| 13 | RBS 70 NG battery | brazil | `samLauncher__rbs_70_ng_battery` | TO DO |
| 14 | S-300VM / IRIS-T SLM | egypt | `samLauncher__s_300vm_iris_t_slm` | TO DO |
| 15 | S-400 | russia | `samLauncher__s_400` | TO DO |
| 16 | SAMP/T NG | france, italy | `samLauncher__samp_t_ng` | TO DO |
| 17 | Sky Sabre (CAMM) | uk | `samLauncher__sky_sabre_camm` | TO DO |
| 18 | Spyder / S-125 | ethiopia | `samLauncher__spyder_s_125` | TO DO |
| 19 | Type 03 Chu-SAM | japan | `samLauncher__type_03_chu_sam` | TO DO |

### `abmLauncher` (THAAD): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Arrow 3 | germany, israel | `abmLauncher__arrow_3` | TO DO |
| 2 | HQ-19 | china | `abmLauncher__hq_19` | TO DO |
| 3 | Missile Defence Battery | saudi | `abmLauncher__missile_defence_battery` | TO DO |
| 4 | Patriot PAC-3 | netherlands, south_korea | `abmLauncher__patriot_pac_3` | TO DO |
| 5 | S-500 | russia | `abmLauncher__s_500` | TO DO |
| 6 | SAMP/T NG (Aster 30 B1NT) | france, italy | `abmLauncher__samp_t_ng_aster_30_b1nt` | TO DO |
| 7 | SM-3 / PAC-3 MSE | japan | `abmLauncher__sm_3_pac_3_mse` | TO DO |
| 8 | THAAD | usa | `abmLauncher__thaad` | TO DO |

### `saudiThaad` (Saudi THAAD): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Saudi THAAD | saudi | `saudiThaad__saudi_thaad` | TO DO |

### `irisT` (IRIS-T SLM): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | IRIS-T SLM | germany | `irisT__iris_t_slm` | TO DO |

### `laserAD` (DE M-SHORAD): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Iron Beam | israel | `laserAD__iron_beam` | TO DO |

### `shortRangeSAM` (AN/TWQ-1 Avenger): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | AN/TWQ-1 Avenger | usa | `shortRangeSAM__an_twq_1_avenger` | TO DO |
| 2 | HISAR-A | turkiye | `shortRangeSAM__hisar_a` | TO DO |
| 3 | IRIS-T SLS | ukraine | `shortRangeSAM__iris_t_sls` | TO DO |
| 4 | Pantsir-S | russia | `shortRangeSAM__pantsir_s` | TO DO |
| 5 | Stormer HVM | uk | `shortRangeSAM__stormer_hvm` | TO DO |
| 6 | Type 11 SAM | japan | `shortRangeSAM__type_11_sam` | TO DO |

### `hpmVehicle` (Leonidas): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Leonidas | usa | `hpmVehicle__leonidas` | TO DO |

### `counterBatteryRadar` (AN/TPQ-53): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | AN/TPQ-53 | usa | `counterBatteryRadar__an_tpq_53` | TO DO |
| 2 | COBRA | france, germany | `counterBatteryRadar__cobra` | TO DO |
| 3 | COBRA / AN/TPQ-37 | ukraine | `counterBatteryRadar__cobra_an_tpq_37` | TO DO |
| 4 | SLC-2 | china, pakistan | `counterBatteryRadar__slc_2` | TO DO |
| 5 | Swathi WLR | india | `counterBatteryRadar__swathi_wlr` | TO DO |
| 6 | Zoopark-1M | russia | `counterBatteryRadar__zoopark_1m` | TO DO |

## P5 Helicopters

Fuselage, Rotor_Main (axis Y, hub pivot), Rotor_Tail (axis X), Skid or Gear, Muzzle markers for the gun and the stub wings.

### `helicopter` (UH-60M Black Hawk): 20 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Bell 412EPI | indonesia | `helicopter__bell_412epi` | TO DO |
| 2 | Dhruv ALH | india | `helicopter__dhruv_alh` | TO DO |
| 3 | H225M | brazil | `helicopter__h225m` | TO DO |
| 4 | KUH-1 Surion | south_korea | `helicopter__kuh_1_surion` | TO DO |
| 5 | Merlin HC4 | uk | `helicopter__merlin_hc4` | TO DO |
| 6 | Mi-17 | ethiopia, iraq, pakistan, south_sudan, sudan, syria | `helicopter__mi_17` | TO DO |
| 7 | Mi-17 / AW109 | nigeria | `helicopter__mi_17_aw109` | TO DO |
| 8 | Mi-8 | north_korea, ukraine | `helicopter__mi_8` | TO DO |
| 9 | Mi-8AMTSh | russia | `helicopter__mi_8amtsh` | TO DO |
| 10 | NH90 | germany, italy, netherlands | `helicopter__nh90` | TO DO |
| 11 | NH90 Caiman | france | `helicopter__nh90_caiman` | TO DO |
| 12 | Shabaviz 2-75 | iran | `helicopter__shabaviz_2_75` | TO DO |
| 13 | T70 Black Hawk | turkiye | `helicopter__t70_black_hawk` | TO DO |
| 14 | UH-60 (captured) | afghanistan | `helicopter__uh_60_captured` | TO DO |
| 15 | UH-60 / Mi-17 | egypt | `helicopter__uh_60_mi_17` | TO DO |
| 16 | UH-60 Yanshuf | israel | `helicopter__uh_60_yanshuf` | TO DO |
| 17 | UH-60JA | japan | `helicopter__uh_60ja` | TO DO |
| 18 | UH-60M | australia, saudi | `helicopter__uh_60m` | TO DO |
| 19 | UH-60M Black Hawk | usa | `helicopter__uh_60m_black_hawk` | TO DO |
| 20 | Z-20 | china | `helicopter__z_20` | TO DO |

### `gunship` (AH-64E Apache): 18 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | AH-1F Cobra / Z-10ME | pakistan | `gunship__ah_1f_cobra_z_10me` | TO DO |
| 2 | AH-64 Saraf | israel | `gunship__ah_64_saraf` | TO DO |
| 3 | AH-64D / Ka-52 | egypt | `gunship__ah_64d_ka_52` | TO DO |
| 4 | AH-64DJP | japan | `gunship__ah_64djp` | TO DO |
| 5 | AH-64E Apache | australia, netherlands, saudi, south_korea, uk, usa | `gunship__ah_64e_apache` | TO DO |
| 6 | AW129 Mangusta | italy | `gunship__aw129_mangusta` | TO DO |
| 7 | Ka-52M | russia | `gunship__ka_52m` | TO DO |
| 8 | LCH Prachand | india | `gunship__lch_prachand` | TO DO |
| 9 | Mi-24 | north_korea, ukraine | `gunship__mi_24` | TO DO |
| 10 | Mi-24V | south_sudan | `gunship__mi_24v` | TO DO |
| 11 | Mi-24V / Mi-35 | sudan | `gunship__mi_24v_mi_35` | TO DO |
| 12 | Mi-28NE | iraq | `gunship__mi_28ne` | TO DO |
| 13 | Mi-35P | indonesia | `gunship__mi_35p` | TO DO |
| 14 | T129 ATAK | turkiye | `gunship__t129_atak` | TO DO |
| 15 | T129 ATAK / Mi-35M | nigeria | `gunship__t129_atak_mi_35m` | TO DO |
| 16 | Tiger | france, germany | `gunship__tiger` | TO DO |
| 17 | Toufan | iran | `gunship__toufan` | TO DO |
| 18 | Z-10 | china | `gunship__z_10` | TO DO |

### `navalHelicopter` (MH-60R Seahawk): 10 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | AS565 Panther | indonesia | `navalHelicopter__as565_panther` | TO DO |
| 2 | Ka-27PL | russia | `navalHelicopter__ka_27pl` | TO DO |
| 3 | MH-60R Seahawk | australia, india, saudi, south_korea, usa | `navalHelicopter__mh_60r_seahawk` | TO DO |
| 4 | NH90 NFH | france, italy, netherlands | `navalHelicopter__nh90_nfh` | TO DO |
| 5 | NH90 Sea Lion | germany | `navalHelicopter__nh90_sea_lion` | TO DO |
| 6 | S-70B Seahawk | turkiye | `navalHelicopter__s_70b_seahawk` | TO DO |
| 7 | SH-2G Super Seasprite | egypt | `navalHelicopter__sh_2g_super_seasprite` | TO DO |
| 8 | SH-60K | japan | `navalHelicopter__sh_60k` | TO DO |
| 9 | Wildcat HMA2 | uk | `navalHelicopter__wildcat_hma2` | TO DO |
| 10 | Z-20F | china | `navalHelicopter__z_20f` | TO DO |

### `heavyLift` (CH-47F Chinook): 7 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | CH-47D Chinook | egypt, south_korea | `heavyLift__ch_47d_chinook` | TO DO |
| 2 | CH-47F Chinook | australia, germany, italy, netherlands, turkiye, usa | `heavyLift__ch_47f_chinook` | TO DO |
| 3 | CH-47F(I) Chinook | india | `heavyLift__ch_47f_i_chinook` | TO DO |
| 4 | CH-47JA Chinook | japan | `heavyLift__ch_47ja_chinook` | TO DO |
| 5 | Chinook HC6 | uk | `heavyLift__chinook_hc6` | TO DO |
| 6 | Mi-26 | russia | `heavyLift__mi_26` | TO DO |
| 7 | Z-8L | china | `heavyLift__z_8l` | TO DO |

### `scoutHelicopter` (Reconnaissance Helicopter): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | OH-1 | japan | `scoutHelicopter__oh_1` | TO DO |
| 2 | Wildcat Mk1 | uk | `scoutHelicopter__wildcat_mk1` | TO DO |

## P6 Aircraft (fixed wing and drones)

Fuselage, Gear_Nose, Gear_Left, Gear_Right (retract about their hinge), Flap_L/R, Aileron_L/R, Rudder, Canopy, Afterburner (marker), Propeller (axis Z, only where it has one), Rotodome (spins about Y, only for AEW).

### `jet` (F-15EX Eagle II): 24 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Eurofighter Typhoon | germany, italy | `jet__eurofighter_typhoon` | TO DO |
| 2 | F-15EX Eagle II | usa | `jet__f_15ex_eagle_ii` | TO DO |
| 3 | F-15I Ra'am | israel | `jet__f_15i_ra_am` | TO DO |
| 4 | F-15J | japan | `jet__f_15j` | TO DO |
| 5 | F-15SA | saudi | `jet__f_15sa` | TO DO |
| 6 | F-16 / MiG-29 | ukraine | `jet__f_16_mig_29` | TO DO |
| 7 | F-16 Block 50 | turkiye | `jet__f_16_block_50` | TO DO |
| 8 | F-16IQ Fighting Falcon | iraq | `jet__f_16iq_fighting_falcon` | TO DO |
| 9 | F-35A | netherlands | `jet__f_35a` | TO DO |
| 10 | F-7NI | nigeria | `jet__f_7ni` | TO DO |
| 11 | F/A-18F Super Hornet | australia | `jet__f_a_18f_super_hornet` | TO DO |
| 12 | Gripen E | brazil | `jet__gripen_e` | TO DO |
| 13 | J-10C / JF-17 / F-16 | pakistan | `jet__j_10c_jf_17_f_16` | TO DO |
| 14 | J-16 | china | `jet__j_16` | TO DO |
| 15 | KF-21 Boramae / F-15K | south_korea | `jet__kf_21_boramae_f_15k` | TO DO |
| 16 | MiG-29 | iran | `jet__mig_29` | TO DO |
| 17 | MiG-29 / MiG-21 | north_korea | `jet__mig_29_mig_21` | TO DO |
| 18 | Rafale | france | `jet__rafale` | TO DO |
| 19 | Rafale / F-16 | egypt, indonesia | `jet__rafale_f_16` | TO DO |
| 20 | Su-25 / MiG-29SE | sudan | `jet__su_25_mig_29se` | TO DO |
| 21 | Su-30K / Su-27 | ethiopia | `jet__su_30k_su_27` | TO DO |
| 22 | Su-30MKI | india | `jet__su_30mki` | TO DO |
| 23 | Su-35S | russia | `jet__su_35s` | TO DO |
| 24 | Typhoon FGR4 | uk | `jet__typhoon_fgr4` | TO DO |

### `lightFighter` (F-16C): 10 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Eurofighter Typhoon | germany | `lightFighter__eurofighter_typhoon` | TO DO |
| 2 | F-16 | pakistan | `lightFighter__f_16` | TO DO |
| 3 | F-16C | turkiye, usa | `lightFighter__f_16c` | TO DO |
| 4 | F-5E | iran | `lightFighter__f_5e` | TO DO |
| 5 | F-5M | brazil | `lightFighter__f_5m` | TO DO |
| 6 | FA-50 | south_korea | `lightFighter__fa_50` | TO DO |
| 7 | J-10C | china | `lightFighter__j_10c` | TO DO |
| 8 | Mirage 2000-5F | france | `lightFighter__mirage_2000_5f` | TO DO |
| 9 | T-50IQ | iraq | `lightFighter__t_50iq` | TO DO |
| 10 | Tejas Mk1 | india | `lightFighter__tejas_mk1` | TO DO |

### `stealthFighter` (F-35A Lightning II): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | F-35A | australia, germany, italy, japan, netherlands, south_korea | `stealthFighter__f_35a` | TO DO |
| 2 | F-35A Lightning II | usa | `stealthFighter__f_35a_lightning_ii` | TO DO |
| 3 | F-35B Lightning | uk | `stealthFighter__f_35b_lightning` | TO DO |
| 4 | F-35I Adir | israel | `stealthFighter__f_35i_adir` | TO DO |
| 5 | J-20 | china | `stealthFighter__j_20` | TO DO |
| 6 | Su-57 | russia | `stealthFighter__su_57` | TO DO |

### `attackJet` (A-10C Thunderbolt II): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | A-10C Thunderbolt II | usa | `attackJet__a_10c_thunderbolt_ii` | TO DO |
| 2 | Jaguar | india | `attackJet__jaguar` | TO DO |
| 3 | L-159 ALCA | iraq | `attackJet__l_159_alca` | TO DO |
| 4 | Mirage 2000D | france | `attackJet__mirage_2000d` | TO DO |
| 5 | Mirage 5 | pakistan | `attackJet__mirage_5` | TO DO |
| 6 | Su-24MK | iran | `attackJet__su_24mk` | TO DO |
| 7 | Su-25 | north_korea, russia, ukraine | `attackJet__su_25` | TO DO |
| 8 | Tornado IDS | germany, saudi | `attackJet__tornado_ids` | TO DO |

### `raptor` (F-22 Raptor): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | F-22 Raptor | usa | `raptor__f_22_raptor` | TO DO |

### `jf17` (JF-17 Thunder): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | JF-17 Thunder | nigeria, pakistan | `jf17__jf_17_thunder` | TO DO |

### `superTucano` (A-29 Super Tucano): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | A-29 Super Tucano | brazil, nigeria | `superTucano__a_29_super_tucano` | TO DO |

### `carrierJet` (F/A-18E Super Hornet): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Carrier Fighter | afghanistan, australia, brazil, china, egypt, france, germany, india, indonesia, iran, iraq, israel, italy, japan, netherlands, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `carrierJet__carrier_fighter` | TO DO |

### `ewJet` (EA-18G Growler): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | EA-18G Growler | australia, usa | `ewJet__ea_18g_growler` | TO DO |
| 2 | J-16D | china | `ewJet__j_16d` | TO DO |
| 3 | Tornado ECR | germany, italy | `ewJet__tornado_ecr` | TO DO |

### `bomber` (B-52H Stratofortress): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | B-52H Stratofortress | usa | `bomber__b_52h_stratofortress` | TO DO |
| 2 | H-6K | china | `bomber__h_6k` | TO DO |
| 3 | Tu-160M | russia | `bomber__tu_160m` | TO DO |

### `aewc` (E-3G Sentry): 16 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | A-50U | russia | `aewc__a_50u` | TO DO |
| 2 | E-2C Hawkeye | egypt | `aewc__e_2c_hawkeye` | TO DO |
| 3 | E-3A Sentry | saudi | `aewc__e_3a_sentry` | TO DO |
| 4 | E-3F Sentry | france | `aewc__e_3f_sentry` | TO DO |
| 5 | E-3G Sentry | usa | `aewc__e_3g_sentry` | TO DO |
| 6 | E-7 Peace Eye | south_korea | `aewc__e_7_peace_eye` | TO DO |
| 7 | E-7 Wedgetail AEW1 | uk | `aewc__e_7_wedgetail_aew1` | TO DO |
| 8 | E-767 | japan | `aewc__e_767` | TO DO |
| 9 | E-7A Wedgetail | australia | `aewc__e_7a_wedgetail` | TO DO |
| 10 | E-7T Peace Eagle | turkiye | `aewc__e_7t_peace_eagle` | TO DO |
| 11 | E-99 | brazil | `aewc__e_99` | TO DO |
| 12 | G550 CAEW | italy | `aewc__g550_caew` | TO DO |
| 13 | G550 Eitam | israel | `aewc__g550_eitam` | TO DO |
| 14 | KJ-500 | china | `aewc__kj_500` | TO DO |
| 15 | Netra AEW&C | india | `aewc__netra_aew_c` | TO DO |
| 16 | Saab 2000 Erieye | pakistan | `aewc__saab_2000_erieye` | TO DO |

### `maritimePatrol` (P-8A Poseidon): 12 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Atlantique 2 | france | `maritimePatrol__atlantique_2` | TO DO |
| 2 | CN-235 MPA | indonesia | `maritimePatrol__cn_235_mpa` | TO DO |
| 3 | Il-38N | russia | `maritimePatrol__il_38n` | TO DO |
| 4 | Kawasaki P-1 | japan | `maritimePatrol__kawasaki_p_1` | TO DO |
| 5 | P-3AM Orion | brazil | `maritimePatrol__p_3am_orion` | TO DO |
| 6 | P-3C Orion | pakistan | `maritimePatrol__p_3c_orion` | TO DO |
| 7 | P-72 | turkiye | `maritimePatrol__p_72` | TO DO |
| 8 | P-72A | italy | `maritimePatrol__p_72a` | TO DO |
| 9 | P-8A Poseidon | australia, germany, south_korea, usa | `maritimePatrol__p_8a_poseidon` | TO DO |
| 10 | P-8I Neptune | india | `maritimePatrol__p_8i_neptune` | TO DO |
| 11 | Poseidon MRA1 | uk | `maritimePatrol__poseidon_mra1` | TO DO |
| 12 | Y-8Q | china | `maritimePatrol__y_8q` | TO DO |

### `drone` (MQ-9 Reaper): 23 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Akinci / Wing Loong | ethiopia | `drone__akinci_wing_loong` | TO DO |
| 2 | Bayraktar TB2 | turkiye | `drone__bayraktar_tb2` | TO DO |
| 3 | Bayraktar TB2 / domestic | ukraine | `drone__bayraktar_tb2_domestic` | TO DO |
| 4 | Bayraktar TB2 / Mohajer-6 | sudan | `drone__bayraktar_tb2_mohajer_6` | TO DO |
| 5 | CH-4B | iraq | `drone__ch_4b` | TO DO |
| 6 | CH-4B / Anka | indonesia | `drone__ch_4b_anka` | TO DO |
| 7 | Hermes 900 | brazil, israel | `drone__hermes_900` | TO DO |
| 8 | Heron ISR | india | `drone__heron_isr` | TO DO |
| 9 | Heron TP | germany | `drone__heron_tp` | TO DO |
| 10 | KUS-FS | south_korea | `drone__kus_fs` | TO DO |
| 11 | Mohajer-6 | iran | `drone__mohajer_6` | TO DO |
| 12 | MQ-9 Reaper | france, usa | `drone__mq_9_reaper` | TO DO |
| 13 | MQ-9A Reaper | italy, netherlands | `drone__mq_9a_reaper` | TO DO |
| 14 | MQ-9B Protector | uk | `drone__mq_9b_protector` | TO DO |
| 15 | MQ-9B SeaGuardian | japan | `drone__mq_9b_seaguardian` | TO DO |
| 16 | Orion | russia | `drone__orion` | TO DO |
| 17 | Saetbyol-4/9 | north_korea | `drone__saetbyol_4_9` | TO DO |
| 18 | Shaheen | syria | `drone__shaheen` | TO DO |
| 19 | Shahpar II / Burraq | pakistan | `drone__shahpar_ii_burraq` | TO DO |
| 20 | Taliban-built drone | afghanistan | `drone__taliban_built_drone` | TO DO |
| 21 | Wing Loong I / CH-4 | egypt | `drone__wing_loong_i_ch_4` | TO DO |
| 22 | Wing Loong II | china, nigeria | `drone__wing_loong_ii` | TO DO |
| 23 | Wing Loong II / Akinci | saudi | `drone__wing_loong_ii_akinci` | TO DO |

### `akinci` (Bayraktar Akinci): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Bayraktar Akinci | ethiopia, turkiye | `akinci__bayraktar_akinci` | TO DO |

### `heavyBomberDrone` (Heavy Bomber Drone): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Heavy hexacopter | russia | `heavyBomberDrone__heavy_hexacopter` | TO DO |
| 2 | Vampire (Baba Yaga) | ukraine | `heavyBomberDrone__vampire_baba_yaga` | TO DO |

### `carrierDrone` (Carrier Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Carrier Drone | afghanistan, australia, brazil, china, egypt, france, germany, india, indonesia, iran, iraq, israel, italy, japan, netherlands, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `carrierDrone__carrier_drone` | TO DO |

### `interceptorDrone` (Interceptor Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Interceptor Drone | ukraine | `interceptorDrone__interceptor_drone` | TO DO |

### `shahed` (Shahed Drone): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Geran-2 | russia | `shahed__geran_2` | TO DO |
| 2 | Shahed Drone | iran | `shahed__shahed_drone` | TO DO |

### `loiterer` (Switchblade 600): 11 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Arash | iran | `loiterer__arash` | TO DO |
| 2 | CH-901 | china | `loiterer__ch_901` | TO DO |
| 3 | Hero-120 | israel | `loiterer__hero_120` | TO DO |
| 4 | HX-2 | germany | `loiterer__hx_2` | TO DO |
| 5 | Kargu-2 | turkiye | `loiterer__kargu_2` | TO DO |
| 6 | Lancet-3 | russia | `loiterer__lancet_3` | TO DO |
| 7 | Loitering Munition | france, north_korea, pakistan, south_korea, uk, ukraine | `loiterer__loitering_munition` | TO DO |
| 8 | Loitering munition | japan | `loiterer__loitering_munition` | TO DO |
| 9 | Nagastra-1 | india | `loiterer__nagastra_1` | TO DO |
| 10 | Qasef-2K / Samad | houthis | `loiterer__qasef_2k_samad` | TO DO |
| 11 | Switchblade 600 | usa | `loiterer__switchblade_600` | TO DO |

### `harop` (Harop): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Harop | israel | `harop__harop` | TO DO |

## P7 Ships and submarines

Hull, Turret_Main (axis Y) with Gun, Radar (axis Y), Wake_Bow and Wake_Stern markers, Propeller (submarines). The carrier: a flat deck with an island and Catapult_0.. markers; a landing ship: Ramp (pivot at the hinge).

### `destroyer` (Arleigh Burke-class): 14 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Arleigh Burke-class | usa | `destroyer__arleigh_burke_class` | TO DO |
| 2 | Choe Hyon-class | north_korea | `destroyer__choe_hyon_class` | TO DO |
| 3 | De Zeven Provincien-class | netherlands | `destroyer__de_zeven_provincien_class` | TO DO |
| 4 | F124 Sachsen-class | germany | `destroyer__f124_sachsen_class` | TO DO |
| 5 | Hobart-class | australia | `destroyer__hobart_class` | TO DO |
| 6 | Horizon-class | france, italy | `destroyer__horizon_class` | TO DO |
| 7 | Istanbul-class | turkiye | `destroyer__istanbul_class` | TO DO |
| 8 | Maya-class | japan | `destroyer__maya_class` | TO DO |
| 9 | Moudge-class | iran | `destroyer__moudge_class` | TO DO |
| 10 | Sejong the Great-class | south_korea | `destroyer__sejong_the_great_class` | TO DO |
| 11 | Type 055 | china | `destroyer__type_055` | TO DO |
| 12 | Type 45 | uk | `destroyer__type_45` | TO DO |
| 13 | Udaloy-class | russia | `destroyer__udaloy_class` | TO DO |
| 14 | Visakhapatnam-class | india | `destroyer__visakhapatnam_class` | TO DO |

### `aegisCruiser` (Maya-class Aegis destroyer): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Maya-class Aegis destroyer | japan | `aegisCruiser__maya_class_aegis_destroyer` | TO DO |

### `type45` (Type 45 Destroyer): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Type 45 Destroyer | uk | `type45__type_45_destroyer` | TO DO |

### `corvette` (Freedom-class LCS): 22 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Ada-class | turkiye | `corvette__ada_class` | TO DO |
| 2 | Al Jubail-class | saudi | `corvette__al_jubail_class` | TO DO |
| 3 | Amnok-class | north_korea | `corvette__amnok_class` | TO DO |
| 4 | Anzac-class | australia | `corvette__anzac_class` | TO DO |
| 5 | Babur-class (MILGEM) | pakistan | `corvette__babur_class_milgem` | TO DO |
| 6 | Daegu-class | south_korea | `corvette__daegu_class` | TO DO |
| 7 | Freedom-class LCS | usa | `corvette__freedom_class_lcs` | TO DO |
| 8 | Gowind 2500 | egypt | `corvette__gowind_2500` | TO DO |
| 9 | Holland-class | netherlands | `corvette__holland_class` | TO DO |
| 10 | K130 Braunschweig | germany | `corvette__k130_braunschweig` | TO DO |
| 11 | Kamorta-class | india | `corvette__kamorta_class` | TO DO |
| 12 | Karakurt-class | russia | `corvette__karakurt_class` | TO DO |
| 13 | La Fayette-class | france | `corvette__la_fayette_class` | TO DO |
| 14 | Martadinata-class | indonesia | `corvette__martadinata_class` | TO DO |
| 15 | Minerva-class | italy | `corvette__minerva_class` | TO DO |
| 16 | Mogami-class | japan | `corvette__mogami_class` | TO DO |
| 17 | OPV-76 / NNS Aradu | nigeria | `corvette__opv_76_nns_aradu` | TO DO |
| 18 | Sa'ar 6 | israel | `corvette__sa_ar_6` | TO DO |
| 19 | Shahid Soleimani-class | iran | `corvette__shahid_soleimani_class` | TO DO |
| 20 | Tamandare frigate | brazil | `corvette__tamandare_frigate` | TO DO |
| 21 | Type 056A | china | `corvette__type_056a` | TO DO |
| 22 | Type 23 frigate | uk | `corvette__type_23_frigate` | TO DO |

### `asFrigate` (Anti-submarine Frigate): 17 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Admiral Gorshkov-class | russia | `asFrigate__admiral_gorshkov_class` | TO DO |
| 2 | Al Riyadh-class | saudi | `asFrigate__al_riyadh_class` | TO DO |
| 3 | Anzac-class | australia | `asFrigate__anzac_class` | TO DO |
| 4 | Daegu-class | south_korea | `asFrigate__daegu_class` | TO DO |
| 5 | De Zeven Provincien-class | netherlands | `asFrigate__de_zeven_provincien_class` | TO DO |
| 6 | F125-class | germany | `asFrigate__f125_class` | TO DO |
| 7 | FREMM | france, italy | `asFrigate__fremm` | TO DO |
| 8 | FREMM (Tahya Misr) | egypt | `asFrigate__fremm_tahya_misr` | TO DO |
| 9 | Istanbul-class | turkiye | `asFrigate__istanbul_class` | TO DO |
| 10 | Martadinata-class | indonesia | `asFrigate__martadinata_class` | TO DO |
| 11 | Mogami-class | japan | `asFrigate__mogami_class` | TO DO |
| 12 | Moudge-class | iran | `asFrigate__moudge_class` | TO DO |
| 13 | Niteroi-class | brazil | `asFrigate__niteroi_class` | TO DO |
| 14 | Talwar-class | india | `asFrigate__talwar_class` | TO DO |
| 15 | Tughril-class | pakistan | `asFrigate__tughril_class` | TO DO |
| 16 | Type 054A | china | `asFrigate__type_054a` | TO DO |
| 17 | Type 23 | uk | `asFrigate__type_23` | TO DO |

### `kcr60` (KCR-60): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | KCR-60 | indonesia | `kcr60__kcr_60` | TO DO |

### `missileBoat` (Fast Missile Boat): 4 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Ambassador Mk III | egypt | `missileBoat__ambassador_mk_iii` | TO DO |
| 2 | Azmat-class | pakistan | `missileBoat__azmat_class` | TO DO |
| 3 | Sa'ar 4.5 | israel | `missileBoat__sa_ar_4_5` | TO DO |
| 4 | Type 022 | china | `missileBoat__type_022` | TO DO |

### `gunboat` (Gunboat): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Gunboat | australia, brazil, china, egypt, france, germany, houthis, india, indonesia, iran, israel, italy, japan, netherlands, nigeria, north_korea, pakistan, russia, saudi, south_korea, sudan, syria, turkiye, uk, usa, yemen | `gunboat__gunboat` | TO DO |
| 2 | Island-class patrol boat | ukraine | `gunboat__island_class_patrol_boat` | TO DO |
| 3 | Patrol boat | iraq | `gunboat__patrol_boat` | TO DO |

### `landingShip` (San Antonio-class): 15 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Albion-class | uk | `landingShip__albion_class` | TO DO |
| 2 | Bahia | brazil | `landingShip__bahia` | TO DO |
| 3 | Bayraktar-class | turkiye | `landingShip__bayraktar_class` | TO DO |
| 4 | Canberra-class | australia | `landingShip__canberra_class` | TO DO |
| 5 | Dokdo-class | south_korea | `landingShip__dokdo_class` | TO DO |
| 6 | Hengam-class | iran | `landingShip__hengam_class` | TO DO |
| 7 | INS Jalashwa | india | `landingShip__ins_jalashwa` | TO DO |
| 8 | Ivan Gren-class | russia | `landingShip__ivan_gren_class` | TO DO |
| 9 | Makassar-class | indonesia | `landingShip__makassar_class` | TO DO |
| 10 | Mistral-class | egypt, france | `landingShip__mistral_class` | TO DO |
| 11 | Osumi-class | japan | `landingShip__osumi_class` | TO DO |
| 12 | Rotterdam-class | netherlands | `landingShip__rotterdam_class` | TO DO |
| 13 | San Antonio-class | usa | `landingShip__san_antonio_class` | TO DO |
| 14 | San Giorgio-class | italy | `landingShip__san_giorgio_class` | TO DO |
| 15 | Type 071 | china | `landingShip__type_071` | TO DO |

### `carrier` (Gerald R. Ford-class): 9 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Cavour | italy | `carrier__cavour` | TO DO |
| 2 | Charles de Gaulle | france | `carrier__charles_de_gaulle` | TO DO |
| 3 | Fujian | china | `carrier__fujian` | TO DO |
| 4 | Gerald R. Ford-class | usa | `carrier__gerald_r_ford_class` | TO DO |
| 5 | INS Vikrant | india | `carrier__ins_vikrant` | TO DO |
| 6 | Kaga (F-35B) | japan | `carrier__kaga_f_35b` | TO DO |
| 7 | Queen Elizabeth-class | uk | `carrier__queen_elizabeth_class` | TO DO |
| 8 | Shahid Bagheri (drone carrier) | iran | `carrier__shahid_bagheri_drone_carrier` | TO DO |
| 9 | TCG Anadolu (drone carrier) | turkiye | `carrier__tcg_anadolu_drone_carrier` | TO DO |

### `submarine` (Virginia-class): 19 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Agosta 90B | pakistan | `submarine__agosta_90b` | TO DO |
| 2 | Astute-class | uk | `submarine__astute_class` | TO DO |
| 3 | Collins-class | australia | `submarine__collins_class` | TO DO |
| 4 | Dolphin II | israel | `submarine__dolphin_ii` | TO DO |
| 5 | Dosan Ahn Changho-class | south_korea | `submarine__dosan_ahn_changho_class` | TO DO |
| 6 | Fateh-class | iran | `submarine__fateh_class` | TO DO |
| 7 | Improved Kilo | russia | `submarine__improved_kilo` | TO DO |
| 8 | Kalvari-class | india | `submarine__kalvari_class` | TO DO |
| 9 | Nagapasa-class | indonesia | `submarine__nagapasa_class` | TO DO |
| 10 | Reis-class | turkiye | `submarine__reis_class` | TO DO |
| 11 | Riachuelo-class | brazil | `submarine__riachuelo_class` | TO DO |
| 12 | Romeo-class | north_korea | `submarine__romeo_class` | TO DO |
| 13 | Taigei-class | japan | `submarine__taigei_class` | TO DO |
| 14 | Todaro-class (Type 212A) | italy | `submarine__todaro_class_type_212a` | TO DO |
| 15 | Type 039C | china | `submarine__type_039c` | TO DO |
| 16 | Type 209/1400 | egypt | `submarine__type_209_1400` | TO DO |
| 17 | Type 212A | germany | `submarine__type_212a` | TO DO |
| 18 | Virginia-class | usa | `submarine__virginia_class` | TO DO |
| 19 | Walrus-class | netherlands | `submarine__walrus_class` | TO DO |

### `nuclearSub` (Ohio-class): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Arihant-class | india | `nuclearSub__arihant_class` | TO DO |
| 2 | Borei-A | russia | `nuclearSub__borei_a` | TO DO |
| 3 | Ohio-class | usa | `nuclearSub__ohio_class` | TO DO |
| 4 | Triomphant-class | france | `nuclearSub__triomphant_class` | TO DO |
| 5 | Type 094 | china | `nuclearSub__type_094` | TO DO |
| 6 | Vanguard-class | uk | `nuclearSub__vanguard_class` | TO DO |

### `seaDrone` (Sea Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug | |
|---|---|---|---|---|
| 1 | Sea Drone | australia, brazil, china, egypt, france, germany, houthis, india, indonesia, iran, iraq, israel, italy, japan, netherlands, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `seaDrone__sea_drone` | TO DO |

Total: 565 models, 468 still to do.
