# Unit roster for Codex: every vehicle, aircraft and ship, as each nation fields it
Generated from the game's own data (28 nations). Read `native/CODEX-ART-REQUEST.md` (Tier 7) first for the file conventions; this file says **which models**.
**One model per row below.** The *model name* is the real-world designation the nation fields; build the real vehicle's **general look** (layout, turret and gun type, number of road wheels or axles, size class, hull shape), generic and without national marks or numbers. Where several nations share a name, build it once. Where the real vehicle is not well known to you, build a plausible generic vehicle of its class and say so in the manifest (`"approximate": true`).
**File name:** `native/godot/assets/art/<vehicles|aircraft|ships>/<key>__<slug>.glb` (for example `tank__m1a2_sepv3_abrams.glb`). The slug is in the last column. Two or three nations with the same class but no distinct row use the model of the nearest row (Claude does that mapping, you do not).
**Order:** P1 first, one priority at a time, committing after each; **P1 starts with a pilot of ONE tank** (see Tier 7) and waits for the user's approval before the rest.

## P1 Main battle tanks

Tracked, turreted. Nodes as Tier 7: Hull, Turret, Gun, Muzzle, Wheel_L0.., Wheel_R0.., Sprocket_*, Idler_*, Roller_*, Track_L/R, Wreck.

### `tank` (M1A2 SEPv3 Abrams): 27 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Altay | turkiye | `tank__altay` |
| 2 | Arjun Mk1 | india | `tank__arjun_mk1` |
| 3 | Challenger 2 | uk | `tank__challenger_2` |
| 4 | Chonma-216 | north_korea | `tank__chonma_216` |
| 5 | K2 Black Panther | south_korea | `tank__k2_black_panther` |
| 6 | Karrar | iran | `tank__karrar` |
| 7 | Leopard 1A5BR | brazil | `tank__leopard_1a5br` |
| 8 | Leopard 2A4 | indonesia | `tank__leopard_2a4` |
| 9 | Leopard 2A7V | eu | `tank__leopard_2a7v` |
| 10 | M1A1 Abrams | egypt | `tank__m1a1_abrams` |
| 11 | M1A1M Abrams | iraq | `tank__m1a1m_abrams` |
| 12 | M1A2 SEPv3 Abrams | australia, usa | `tank__m1a2_sepv3_abrams` |
| 13 | M1A2S Abrams | saudi | `tank__m1a2s_abrams` |
| 14 | Merkava Mk 4 | israel | `tank__merkava_mk_4` |
| 15 | T-55 / T-62 | yemen | `tank__t_55_t_62` |
| 16 | T-62 (captured) | afghanistan | `tank__t_62_captured` |
| 17 | T-62 / T-72 (captured) | houthis | `tank__t_62_t_72_captured` |
| 18 | T-64BV | ukraine | `tank__t_64bv` |
| 19 | T-72 | syria | `tank__t_72` |
| 20 | T-72 / Al-Bashir | sudan | `tank__t_72_al_bashir` |
| 21 | T-72AV | south_sudan | `tank__t_72av` |
| 22 | T-72UA1 / T-72B | ethiopia | `tank__t_72ua1_t_72b` |
| 23 | T-90M Proryv | russia | `tank__t_90m_proryv` |
| 24 | Type 10 | japan | `tank__type_10` |
| 25 | Type 99A | china | `tank__type_99a` |
| 26 | VT-4 / Vickers Mk 3 | nigeria | `tank__vt_4_vickers_mk_3` |
| 27 | VT-4 Haider | pakistan | `tank__vt_4_haider` |

## P2 Armoured personnel carriers, infantry fighting vehicles and other armour

Tracked or wheeled (count the real axles). Turret and Gun only where the real vehicle has them (an APC may have a remote weapon station; a recovery vehicle has a boom and a spade: name those nodes Boom and Spade, pivots at the hinge).

### `apc` (Stryker): 27 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Anoa | indonesia | `apc__anoa` |
| 2 | BMP-1 | syria | `apc__bmp_1` |
| 3 | BMP-2 / BTR-80 (captured) | houthis | `apc__bmp_2_btr_80_captured` |
| 4 | Boxer | eu, uk | `apc__boxer` |
| 5 | Boxer CRV | australia | `apc__boxer_crv` |
| 6 | BTR-3UN / Proforce Ara | nigeria | `apc__btr_3un_proforce_ara` |
| 7 | BTR-4 | ukraine | `apc__btr_4` |
| 8 | BTR-4 / M113 | iraq | `apc__btr_4_m113` |
| 9 | BTR-60 / BMP-1 | ethiopia | `apc__btr_60_bmp_1` |
| 10 | BTR-60 / MRAP | yemen | `apc__btr_60_mrap` |
| 11 | BTR-80 / Typhoon MRAP | south_sudan | `apc__btr_80_typhoon_mrap` |
| 12 | BTR-80A / BTR-70 | sudan | `apc__btr_80a_btr_70` |
| 13 | BTR-82A | russia | `apc__btr_82a` |
| 14 | Eitan | israel | `apc__eitan` |
| 15 | Humvee (captured) | afghanistan | `apc__humvee_captured` |
| 16 | K808 APC | south_korea | `apc__k808_apc` |
| 17 | LAV 700 | saudi | `apc__lav_700` |
| 18 | M-2010 | north_korea | `apc__m_2010` |
| 19 | M113 / Fahd | egypt | `apc__m113_fahd` |
| 20 | Pars | turkiye | `apc__pars` |
| 21 | Rakhsh | iran | `apc__rakhsh` |
| 22 | Saad / M113 | pakistan | `apc__saad_m113` |
| 23 | Stryker | usa | `apc__stryker` |
| 24 | Type 96 APC | japan | `apc__type_96_apc` |
| 25 | VBTP Guarani | brazil | `apc__vbtp_guarani` |
| 26 | WhAP | india | `apc__whap` |
| 27 | ZBL-08 | china | `apc__zbl_08` |

### `ifv` (M2A4 Bradley): 12 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | ACV-15 | turkiye | `ifv__acv_15` |
| 2 | BMP-2 | iran | `ifv__bmp_2` |
| 3 | BMP-2 Sarath | india | `ifv__bmp_2_sarath` |
| 4 | BMP-3 | russia | `ifv__bmp_3` |
| 5 | K21 IFV | south_korea | `ifv__k21_ifv` |
| 6 | M2A2 Bradley | saudi, ukraine | `ifv__m2a2_bradley` |
| 7 | M2A4 Bradley | usa | `ifv__m2a4_bradley` |
| 8 | Pandur II IFV | indonesia | `ifv__pandur_ii_ifv` |
| 9 | Puma IFV | eu | `ifv__puma_ifv` |
| 10 | Type 89 IFV | japan | `ifv__type_89_ifv` |
| 11 | Warrior | uk | `ifv__warrior` |
| 12 | ZBD-04A | china | `ifv__zbd_04a` |

### `heavyAPC` (Heavy Armoured Carrier): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Namer | israel | `heavyAPC__namer` |

### `bushmaster` (Bushmaster): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Bushmaster | australia | `bushmaster__bushmaster` |

### `reconVehicle` (M3 Bradley Scout): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Fennek | eu | `reconVehicle__fennek` |
| 2 | Hawkei | australia | `reconVehicle__hawkei` |
| 3 | Jackal | uk | `reconVehicle__jackal` |
| 4 | Komodo Scout | indonesia | `reconVehicle__komodo_scout` |
| 5 | M3 Bradley Scout | usa | `reconVehicle__m3_bradley_scout` |

### `recoveryVehicle` (M88A2 Hercules): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Armoured Recovery Vehicle | afghanistan, australia, brazil, china, egypt, indonesia, iran, iraq, israel, north_korea, pakistan, saudi, syria, turkiye | `recoveryVehicle__armoured_recovery_vehicle` |
| 2 | Bergepanzer 3 Buffel | eu | `recoveryVehicle__bergepanzer_3_buffel` |
| 3 | BREM-1 | russia, ukraine | `recoveryVehicle__brem_1` |
| 4 | Challenger ARRV | uk | `recoveryVehicle__challenger_arrv` |
| 5 | K1 ARV | south_korea | `recoveryVehicle__k1_arv` |
| 6 | M88A2 Hercules | usa | `recoveryVehicle__m88a2_hercules` |
| 7 | Type 90 ARV | japan | `recoveryVehicle__type_90_arv` |
| 8 | WZT-3 | india | `recoveryVehicle__wzt_3` |

### `mineClearer` (M1150 Assault Breacher): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Keiler | eu | `mineClearer__keiler` |
| 2 | M1150 Assault Breacher | usa | `mineClearer__m1150_assault_breacher` |
| 3 | Mine-clearing Vehicle | afghanistan, australia, brazil, china, egypt, india, indonesia, iran, iraq, israel, japan, north_korea, pakistan, saudi, south_korea, syria, turkiye | `mineClearer__mine_clearing_vehicle` |
| 4 | Trojan AVRE | uk | `mineClearer__trojan_avre` |
| 5 | UR-77 Meteorit | russia, ukraine | `mineClearer__ur_77_meteorit` |

### `mineLayer` (M139 Volcano): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Engineer Minelayer | afghanistan, australia, brazil, china, egypt, india, indonesia, iran, iraq, israel, japan, north_korea, pakistan, saudi, south_korea, syria, turkiye, uk | `mineLayer__engineer_minelayer` |
| 2 | GMZ-3 | ukraine | `mineLayer__gmz_3` |
| 3 | ISDM Zemledelie | russia | `mineLayer__isdm_zemledelie` |
| 4 | M139 Volcano | usa | `mineLayer__m139_volcano` |
| 5 | Skorpion Mine Dispenser | eu | `mineLayer__skorpion_mine_dispenser` |

### `ewVehicle` (EW Vehicle): 5 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Elbit EW truck | israel | `ewVehicle__elbit_ew_truck` |
| 2 | EW Vehicle | afghanistan, australia, brazil, egypt, eu, india, indonesia, iran, iraq, japan, north_korea, pakistan, saudi, south_korea, syria, uk, ukraine, usa | `ewVehicle__ew_vehicle` |
| 3 | KORAL | turkiye | `ewVehicle__koral` |
| 4 | Krasukha-4 | russia | `ewVehicle__krasukha_4` |
| 5 | Type 2 EW truck | china | `ewVehicle__type_2_ew_truck` |

## P3 Artillery and rocket launchers

Self-propelled: Hull, Turret, Gun (elevates) with Muzzle. Rocket launchers: Hull, Launcher (the pod or rack: axis X to elevate, axis Y turntable if it traverses), Muzzle marker at the pod's front. Towed guns: Carriage, Gun (elevates), Trail_L/R (the legs), Wheel_L0/R0.

### `artillery` (M109A7 Paladin): 26 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | 2S1 Gvozdika / D-30 | syria | `artillery__2s1_gvozdika_d_30` |
| 2 | 2S19 Msta-S | russia | `artillery__2s19_msta_s` |
| 3 | 2S3 / PzH 2000 / Krab | ukraine | `artillery__2s3_pzh_2000_krab` |
| 4 | AS-90 / Archer | uk | `artillery__as_90_archer` |
| 5 | AS9 Huntsman | australia | `artillery__as9_huntsman` |
| 6 | CAESAR | indonesia, saudi | `artillery__caesar` |
| 7 | D-30 (towed) | afghanistan | `artillery__d_30_towed` |
| 8 | D-30 / 2S1 | south_sudan | `artillery__d_30_2s1` |
| 9 | D-30 / 2S1 (captured) | houthis | `artillery__d_30_2s1_captured` |
| 10 | D-30 / Khalifa | sudan | `artillery__d_30_khalifa` |
| 11 | D-30 / M109A5 | yemen | `artillery__d_30_m109a5` |
| 12 | K9 Vajra-T | india | `artillery__k9_vajra_t` |
| 13 | K9A1 Thunder | south_korea | `artillery__k9a1_thunder` |
| 14 | M109A5 | egypt, iraq | `artillery__m109a5` |
| 15 | M109A5 / SH-15 | pakistan | `artillery__m109a5_sh_15` |
| 16 | M109A5+ BR | brazil | `artillery__m109a5_br` |
| 17 | M109A7 Paladin | usa | `artillery__m109a7_paladin` |
| 18 | M1989 Koksan | north_korea | `artillery__m1989_koksan` |
| 19 | PLZ-05 | china | `artillery__plz_05` |
| 20 | PzH 2000 | eu | `artillery__pzh_2000` |
| 21 | Raad-2 | iran | `artillery__raad_2` |
| 22 | Roem | israel | `artillery__roem` |
| 23 | SH-15 / D-30 | ethiopia | `artillery__sh_15_d_30` |
| 24 | SH-5 / Palmaria | nigeria | `artillery__sh_5_palmaria` |
| 25 | T-155 Firtina | turkiye | `artillery__t_155_firtina` |
| 26 | Type 99 SPH | japan | `artillery__type_99_sph` |

### `towedHowitzer` (M777): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | FH70 | japan | `towedHowitzer__fh70` |
| 2 | L118 Light Gun | uk | `towedHowitzer__l118_light_gun` |
| 3 | M777 | australia, india, ukraine, usa | `towedHowitzer__m777` |

### `wheeledHowitzer` (Wheeled Self-propelled Howitzer): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | 2S43 Malva | russia | `wheeledHowitzer__2s43_malva` |
| 2 | Archer | uk | `wheeledHowitzer__archer` |
| 3 | CAESAR | eu, indonesia, ukraine | `wheeledHowitzer__caesar` |
| 4 | PCL-181 | china | `wheeledHowitzer__pcl_181` |
| 5 | SH-15 | ethiopia, pakistan | `wheeledHowitzer__sh_15` |
| 6 | Type 19 Howitzer | japan | `wheeledHowitzer__type_19_howitzer` |

### `k9` (K9 Thunder): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | K9 Thunder | south_korea | `k9__k9_thunder` |

### `mlrs` (M270 MLRS): 22 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | A-100 / Fatah-1 | pakistan | `mlrs__a_100_fatah_1` |
| 2 | ASTROS II | saudi | `mlrs__astros_ii` |
| 3 | ASTROS II / RM-70 | indonesia | `mlrs__astros_ii_rm_70` |
| 4 | ASTROS II Mk6 | brazil | `mlrs__astros_ii_mk6` |
| 5 | BM-21 / Badr rockets | houthis | `mlrs__bm_21_badr_rockets` |
| 6 | BM-21 / Taka | sudan | `mlrs__bm_21_taka` |
| 7 | BM-21 Grad | afghanistan, ethiopia, iraq, syria | `mlrs__bm_21_grad` |
| 8 | BM-21 Sakr | egypt | `mlrs__bm_21_sakr` |
| 9 | BM-27 / HIMARS | ukraine | `mlrs__bm_27_himars` |
| 10 | BM-30 Smerch | russia | `mlrs__bm_30_smerch` |
| 11 | Fajr-5 | iran | `mlrs__fajr_5` |
| 12 | K239 Chunmoo | south_korea | `mlrs__k239_chunmoo` |
| 13 | KN-25 / M1991 | north_korea | `mlrs__kn_25_m1991` |
| 14 | Lynx | israel | `mlrs__lynx` |
| 15 | M142 HIMARS | australia | `mlrs__m142_himars` |
| 16 | M270 (JGSDF) | japan | `mlrs__m270_jgsdf` |
| 17 | M270 MLRS | usa | `mlrs__m270_mlrs` |
| 18 | M270A2 MLRS | uk | `mlrs__m270a2_mlrs` |
| 19 | MARS II | eu | `mlrs__mars_ii` |
| 20 | PHL-03 | china | `mlrs__phl_03` |
| 21 | Pinaka | india | `mlrs__pinaka` |
| 22 | T-122 Sakarya | turkiye | `mlrs__t_122_sakarya` |

### `himars` (HIMARS): 10 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | EuroPULS | eu | `himars__europuls` |
| 2 | Fath-360 launcher | iran | `himars__fath_360_launcher` |
| 3 | Guided Pinaka | india | `himars__guided_pinaka` |
| 4 | Guided Rocket Launcher | australia, brazil, egypt, indonesia, north_korea, pakistan, saudi, south_korea, uk, ukraine | `himars__guided_rocket_launcher` |
| 5 | HIMARS | usa | `himars__himars` |
| 6 | M270 GMLRS | japan | `himars__m270_gmlrs` |
| 7 | PCH-191 | china | `himars__pch_191` |
| 8 | PULS | israel | `himars__puls` |
| 9 | Tornado-S | russia | `himars__tornado_s` |
| 10 | TRLG-230 | turkiye | `himars__trlg_230` |

### `heavyRocket` (Heavy Rocket Launcher): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Heavy Rocket Launcher | north_korea | `heavyRocket__heavy_rocket_launcher` |

### `tos1a` (TOS-1A Solntsepyok): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | TOS-1A Solntsepyok | iraq, russia | `tos1a__tos_1a_solntsepyok` |

### `directFire` (Mobile Direct-fire Gun): 4 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | AMX-10 RC | ukraine | `directFire__amx_10_rc` |
| 2 | EE-9 Cascavel | brazil | `directFire__ee_9_cascavel` |
| 3 | Harimau | indonesia | `directFire__harimau` |
| 4 | Type 16 MCV | japan | `directFire__type_16_mcv` |

### `coastalASM` (NMESIS): 7 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Ghader Coastal Battery | iran | `coastalASM__ghader_coastal_battery` |
| 2 | K-300P Bastion-P | russia | `coastalASM__k_300p_bastion_p` |
| 3 | NMESIS | usa | `coastalASM__nmesis` |
| 4 | NSM Coastal Defence System | eu | `coastalASM__nsm_coastal_defence_system` |
| 5 | RK-360MC Neptune | ukraine | `coastalASM__rk_360mc_neptune` |
| 6 | Type 12 SSM | japan | `coastalASM__type_12_ssm` |
| 7 | YJ-62 Coastal Battery | china | `coastalASM__yj_62_coastal_battery` |

### `brahmos` (BrahMos Battery): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | BrahMos Battery | india | `brahmos__brahmos_battery` |

### `df17` (DF-17 Launcher): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | DF-17 Launcher | china | `df17__df_17_launcher` |

### `shahedLauncher` (Shahed Launcher): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Geran-2 Launcher | russia | `shahedLauncher__geran_2_launcher` |
| 2 | Shahed Launcher | iran | `shahedLauncher__shahed_launcher` |

## P4 Air defence and radars

Hull or truck, Launcher (elevates about X, turntable about Y), Radar (spins about Y; a dish or an array), Muzzle markers at each missile tube or barrel (Muzzle_0, Muzzle_1, ...).

### `aaVehicle` (M-SHORAD): 23 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | 2K22 Tunguska | india | `aaVehicle__2k22_tunguska` |
| 2 | 35 mm air defence gun | syria | `aaVehicle__35_mm_air_defence_gun` |
| 3 | Avenger / Shahine | saudi | `aaVehicle__avenger_shahine` |
| 4 | Avenger / Sinai-23 | egypt | `aaVehicle__avenger_sinai_23` |
| 5 | Gepard / Strela-10 | ukraine | `aaVehicle__gepard_strela_10` |
| 6 | Gepard 1A2 | brazil | `aaVehicle__gepard_1a2` |
| 7 | Iron Dome battery | israel | `aaVehicle__iron_dome_battery` |
| 8 | K30 Biho II | south_korea | `aaVehicle__k30_biho_ii` |
| 9 | Korkut | turkiye | `aaVehicle__korkut` |
| 10 | LY-80 / Oerlikon | pakistan | `aaVehicle__ly_80_oerlikon` |
| 11 | M-SHORAD | usa | `aaVehicle__m_shorad` |
| 12 | M1992 30 mm | north_korea | `aaVehicle__m1992_30_mm` |
| 13 | Pantsir-S1 | ethiopia, iraq, russia | `aaVehicle__pantsir_s1` |
| 14 | PGZ-09 | china | `aaVehicle__pgz_09` |
| 15 | RBS 70 (vehicle) | australia | `aaVehicle__rbs_70_vehicle` |
| 16 | Skyranger 30 | eu | `aaVehicle__skyranger_30` |
| 17 | Skyshield / RBS 70 | indonesia | `aaVehicle__skyshield_rbs_70` |
| 18 | Stormer HVM | uk | `aaVehicle__stormer_hvm` |
| 19 | Type 87 SPAAG | japan | `aaVehicle__type_87_spaag` |
| 20 | ZSU-23-4 Shilka | iran, nigeria | `aaVehicle__zsu_23_4_shilka` |
| 21 | ZU-23-2 | afghanistan, south_sudan, sudan | `aaVehicle__zu_23_2` |
| 22 | ZU-23-2 (technical) | yemen | `aaVehicle__zu_23_2_technical` |
| 23 | ZU-23-2 / Saqr (358) | houthis | `aaVehicle__zu_23_2_saqr_358` |

### `samLauncher` (Patriot PAC-3): 18 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Akash | india | `samLauncher__akash` |
| 2 | Bavar-373 | iran | `samLauncher__bavar_373` |
| 3 | Cheongung II | south_korea | `samLauncher__cheongung_ii` |
| 4 | David's Sling | israel | `samLauncher__david_s_sling` |
| 5 | Hisar-O | turkiye | `samLauncher__hisar_o` |
| 6 | HQ-9/P | pakistan | `samLauncher__hq_9_p` |
| 7 | HQ-9B | china | `samLauncher__hq_9b` |
| 8 | KN-06 (Pongae-5) | north_korea | `samLauncher__kn_06_pongae_5` |
| 9 | NASAMS | australia, indonesia | `samLauncher__nasams` |
| 10 | Patriot / IRIS-T / NASAMS | ukraine | `samLauncher__patriot_iris_t_nasams` |
| 11 | Patriot PAC-3 | saudi, usa | `samLauncher__patriot_pac_3` |
| 12 | RBS 70 NG battery | brazil | `samLauncher__rbs_70_ng_battery` |
| 13 | S-300VM / IRIS-T SLM | egypt | `samLauncher__s_300vm_iris_t_slm` |
| 14 | S-400 | russia | `samLauncher__s_400` |
| 15 | SAMP/T NG | eu | `samLauncher__samp_t_ng` |
| 16 | Sky Sabre (CAMM) | uk | `samLauncher__sky_sabre_camm` |
| 17 | Spyder / S-125 | ethiopia | `samLauncher__spyder_s_125` |
| 18 | Type 03 Chu-SAM | japan | `samLauncher__type_03_chu_sam` |

### `abmLauncher` (THAAD): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Arrow 3 | israel | `abmLauncher__arrow_3` |
| 2 | HQ-19 | china | `abmLauncher__hq_19` |
| 3 | Missile Defence Battery | saudi | `abmLauncher__missile_defence_battery` |
| 4 | Patriot PAC-3 | south_korea | `abmLauncher__patriot_pac_3` |
| 5 | S-500 | russia | `abmLauncher__s_500` |
| 6 | SAMP/T NG (Aster 30 B1NT) | eu | `abmLauncher__samp_t_ng_aster_30_b1nt` |
| 7 | SM-3 / PAC-3 MSE | japan | `abmLauncher__sm_3_pac_3_mse` |
| 8 | THAAD | usa | `abmLauncher__thaad` |

### `saudiThaad` (Saudi THAAD): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Saudi THAAD | saudi | `saudiThaad__saudi_thaad` |

### `irisT` (IRIS-T SLM): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | IRIS-T SLM | eu | `irisT__iris_t_slm` |

### `laserAD` (DE M-SHORAD): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Iron Beam | israel | `laserAD__iron_beam` |

### `shortRangeSAM` (AN/TWQ-1 Avenger): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | AN/TWQ-1 Avenger | usa | `shortRangeSAM__an_twq_1_avenger` |
| 2 | HISAR-A | turkiye | `shortRangeSAM__hisar_a` |
| 3 | IRIS-T SLS | ukraine | `shortRangeSAM__iris_t_sls` |
| 4 | Pantsir-S | russia | `shortRangeSAM__pantsir_s` |
| 5 | Stormer HVM | uk | `shortRangeSAM__stormer_hvm` |
| 6 | Type 11 SAM | japan | `shortRangeSAM__type_11_sam` |

### `hpmVehicle` (Leonidas): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Leonidas | usa | `hpmVehicle__leonidas` |

### `counterBatteryRadar` (AN/TPQ-53): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | AN/TPQ-53 | usa | `counterBatteryRadar__an_tpq_53` |
| 2 | COBRA | eu | `counterBatteryRadar__cobra` |
| 3 | COBRA / AN/TPQ-37 | ukraine | `counterBatteryRadar__cobra_an_tpq_37` |
| 4 | SLC-2 | china, pakistan | `counterBatteryRadar__slc_2` |
| 5 | Swathi WLR | india | `counterBatteryRadar__swathi_wlr` |
| 6 | Zoopark-1M | russia | `counterBatteryRadar__zoopark_1m` |

## P5 Helicopters

Fuselage, Rotor_Main (axis Y, hub pivot), Rotor_Tail (axis X), Skid or Gear, Muzzle markers for the gun and the stub wings.

### `helicopter` (UH-60M Black Hawk): 19 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Bell 412EPI | indonesia | `helicopter__bell_412epi` |
| 2 | Dhruv ALH | india | `helicopter__dhruv_alh` |
| 3 | H225M | brazil | `helicopter__h225m` |
| 4 | KUH-1 Surion | south_korea | `helicopter__kuh_1_surion` |
| 5 | Merlin HC4 | uk | `helicopter__merlin_hc4` |
| 6 | Mi-17 | ethiopia, iraq, pakistan, south_sudan, sudan, syria | `helicopter__mi_17` |
| 7 | Mi-17 / AW109 | nigeria | `helicopter__mi_17_aw109` |
| 8 | Mi-8 | north_korea, ukraine | `helicopter__mi_8` |
| 9 | Mi-8AMTSh | russia | `helicopter__mi_8amtsh` |
| 10 | NH90 | eu | `helicopter__nh90` |
| 11 | Shabaviz 2-75 | iran | `helicopter__shabaviz_2_75` |
| 12 | T70 Black Hawk | turkiye | `helicopter__t70_black_hawk` |
| 13 | UH-60 (captured) | afghanistan | `helicopter__uh_60_captured` |
| 14 | UH-60 / Mi-17 | egypt | `helicopter__uh_60_mi_17` |
| 15 | UH-60 Yanshuf | israel | `helicopter__uh_60_yanshuf` |
| 16 | UH-60JA | japan | `helicopter__uh_60ja` |
| 17 | UH-60M | australia, saudi | `helicopter__uh_60m` |
| 18 | UH-60M Black Hawk | usa | `helicopter__uh_60m_black_hawk` |
| 19 | Z-20 | china | `helicopter__z_20` |

### `gunship` (AH-64E Apache): 16 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | AH-1F Cobra / Z-10ME | pakistan | `gunship__ah_1f_cobra_z_10me` |
| 2 | AH-64 Saraf | israel | `gunship__ah_64_saraf` |
| 3 | AH-64D / Ka-52 | egypt | `gunship__ah_64d_ka_52` |
| 4 | AH-64DJP | japan | `gunship__ah_64djp` |
| 5 | AH-64E Apache | australia, indonesia, saudi, south_korea, uk, usa | `gunship__ah_64e_apache` |
| 6 | Ka-52M | russia | `gunship__ka_52m` |
| 7 | LCH Prachand | india | `gunship__lch_prachand` |
| 8 | Mi-24 | north_korea, ukraine | `gunship__mi_24` |
| 9 | Mi-24V | south_sudan | `gunship__mi_24v` |
| 10 | Mi-24V / Mi-35 | sudan | `gunship__mi_24v_mi_35` |
| 11 | Mi-28NE | iraq | `gunship__mi_28ne` |
| 12 | T129 ATAK | turkiye | `gunship__t129_atak` |
| 13 | T129 ATAK / Mi-35M | nigeria | `gunship__t129_atak_mi_35m` |
| 14 | Tiger | eu | `gunship__tiger` |
| 15 | Toufan | iran | `gunship__toufan` |
| 16 | Z-10 | china | `gunship__z_10` |

### `navalHelicopter` (MH-60R Seahawk): 9 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | AS565 Panther | indonesia | `navalHelicopter__as565_panther` |
| 2 | Ka-27PL | russia | `navalHelicopter__ka_27pl` |
| 3 | MH-60R Seahawk | australia, india, saudi, south_korea, usa | `navalHelicopter__mh_60r_seahawk` |
| 4 | NH90 NFH | eu | `navalHelicopter__nh90_nfh` |
| 5 | S-70B Seahawk | turkiye | `navalHelicopter__s_70b_seahawk` |
| 6 | SH-2G Super Seasprite | egypt | `navalHelicopter__sh_2g_super_seasprite` |
| 7 | SH-60K | japan | `navalHelicopter__sh_60k` |
| 8 | Wildcat HMA2 | uk | `navalHelicopter__wildcat_hma2` |
| 9 | Z-20F | china | `navalHelicopter__z_20f` |

### `heavyLift` (CH-47F Chinook): 7 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | CH-47D Chinook | egypt, south_korea | `heavyLift__ch_47d_chinook` |
| 2 | CH-47F Chinook | australia, eu, turkiye, usa | `heavyLift__ch_47f_chinook` |
| 3 | CH-47F(I) Chinook | india | `heavyLift__ch_47f_i_chinook` |
| 4 | CH-47JA Chinook | japan | `heavyLift__ch_47ja_chinook` |
| 5 | Chinook HC6 | uk | `heavyLift__chinook_hc6` |
| 6 | Mi-26 | russia | `heavyLift__mi_26` |
| 7 | Z-8L | china | `heavyLift__z_8l` |

### `scoutHelicopter` (Reconnaissance Helicopter): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | OH-1 | japan | `scoutHelicopter__oh_1` |
| 2 | Wildcat Mk1 | uk | `scoutHelicopter__wildcat_mk1` |

## P6 Aircraft (fixed wing and drones)

Fuselage, Gear_Nose, Gear_Left, Gear_Right (retract about their hinge), Flap_L/R, Aileron_L/R, Rudder, Canopy, Afterburner (marker), Propeller (axis Z, only where the aircraft has one), Rotodome (spins about Y, only for the AEW aircraft).

### `jet` (F-15EX Eagle II): 22 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | F-15EX Eagle II | usa | `jet__f_15ex_eagle_ii` |
| 2 | F-15I Ra'am | israel | `jet__f_15i_ra_am` |
| 3 | F-15J | japan | `jet__f_15j` |
| 4 | F-15SA | saudi | `jet__f_15sa` |
| 5 | F-16 / MiG-29 | ukraine | `jet__f_16_mig_29` |
| 6 | F-16 Block 50 | turkiye | `jet__f_16_block_50` |
| 7 | F-16IQ Fighting Falcon | iraq | `jet__f_16iq_fighting_falcon` |
| 8 | F-7NI | nigeria | `jet__f_7ni` |
| 9 | F/A-18F Super Hornet | australia | `jet__f_a_18f_super_hornet` |
| 10 | Gripen E | brazil | `jet__gripen_e` |
| 11 | J-10C / JF-17 / F-16 | pakistan | `jet__j_10c_jf_17_f_16` |
| 12 | J-16 | china | `jet__j_16` |
| 13 | KF-21 Boramae / F-15K | south_korea | `jet__kf_21_boramae_f_15k` |
| 14 | MiG-29 | iran | `jet__mig_29` |
| 15 | MiG-29 / MiG-21 | north_korea | `jet__mig_29_mig_21` |
| 16 | Rafale / F-16 | egypt, indonesia | `jet__rafale_f_16` |
| 17 | Rafale / Typhoon | eu | `jet__rafale_typhoon` |
| 18 | Su-25 / MiG-29SE | sudan | `jet__su_25_mig_29se` |
| 19 | Su-30K / Su-27 | ethiopia | `jet__su_30k_su_27` |
| 20 | Su-30MKI | india | `jet__su_30mki` |
| 21 | Su-35S | russia | `jet__su_35s` |
| 22 | Typhoon FGR4 | uk | `jet__typhoon_fgr4` |

### `lightFighter` (F-16C): 9 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | F-16 | pakistan | `lightFighter__f_16` |
| 2 | F-16C | turkiye, usa | `lightFighter__f_16c` |
| 3 | F-5E | iran | `lightFighter__f_5e` |
| 4 | F-5M | brazil | `lightFighter__f_5m` |
| 5 | FA-50 | south_korea | `lightFighter__fa_50` |
| 6 | J-10C | china | `lightFighter__j_10c` |
| 7 | JAS 39 Gripen C | eu | `lightFighter__jas_39_gripen_c` |
| 8 | T-50IQ | iraq | `lightFighter__t_50iq` |
| 9 | Tejas Mk1 | india | `lightFighter__tejas_mk1` |

### `stealthFighter` (F-35A Lightning II): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | F-35A | australia, eu, japan, south_korea | `stealthFighter__f_35a` |
| 2 | F-35A Lightning II | usa | `stealthFighter__f_35a_lightning_ii` |
| 3 | F-35B Lightning | uk | `stealthFighter__f_35b_lightning` |
| 4 | F-35I Adir | israel | `stealthFighter__f_35i_adir` |
| 5 | J-20 | china | `stealthFighter__j_20` |
| 6 | Su-57 | russia | `stealthFighter__su_57` |

### `attackJet` (A-10C Thunderbolt II): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | A-10C Thunderbolt II | usa | `attackJet__a_10c_thunderbolt_ii` |
| 2 | Jaguar | india | `attackJet__jaguar` |
| 3 | L-159 ALCA | iraq | `attackJet__l_159_alca` |
| 4 | Mirage 2000D | eu | `attackJet__mirage_2000d` |
| 5 | Mirage 5 | pakistan | `attackJet__mirage_5` |
| 6 | Su-24MK | iran | `attackJet__su_24mk` |
| 7 | Su-25 | north_korea, russia, ukraine | `attackJet__su_25` |
| 8 | Tornado IDS | saudi | `attackJet__tornado_ids` |

### `raptor` (F-22 Raptor): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | F-22 Raptor | usa | `raptor__f_22_raptor` |

### `jf17` (JF-17 Thunder): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | JF-17 Thunder | nigeria, pakistan | `jf17__jf_17_thunder` |

### `superTucano` (A-29 Super Tucano): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | A-29 Super Tucano | brazil, nigeria | `superTucano__a_29_super_tucano` |

### `carrierJet` (F/A-18E Super Hornet): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Carrier Fighter | afghanistan, australia, brazil, china, egypt, eu, india, indonesia, iran, iraq, israel, japan, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `carrierJet__carrier_fighter` |

### `ewJet` (EA-18G Growler): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | EA-18G Growler | australia, usa | `ewJet__ea_18g_growler` |
| 2 | J-16D | china | `ewJet__j_16d` |
| 3 | Tornado ECR | eu | `ewJet__tornado_ecr` |

### `bomber` (B-52H Stratofortress): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | B-52H Stratofortress | usa | `bomber__b_52h_stratofortress` |
| 2 | H-6K | china | `bomber__h_6k` |
| 3 | Tu-160M | russia | `bomber__tu_160m` |

### `aewc` (E-3G Sentry): 15 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | A-50U | russia | `aewc__a_50u` |
| 2 | E-2C Hawkeye | egypt | `aewc__e_2c_hawkeye` |
| 3 | E-3A Sentry | saudi | `aewc__e_3a_sentry` |
| 4 | E-3F Sentry | eu | `aewc__e_3f_sentry` |
| 5 | E-3G Sentry | usa | `aewc__e_3g_sentry` |
| 6 | E-7 Peace Eye | south_korea | `aewc__e_7_peace_eye` |
| 7 | E-7 Wedgetail AEW1 | uk | `aewc__e_7_wedgetail_aew1` |
| 8 | E-767 | japan | `aewc__e_767` |
| 9 | E-7A Wedgetail | australia | `aewc__e_7a_wedgetail` |
| 10 | E-7T Peace Eagle | turkiye | `aewc__e_7t_peace_eagle` |
| 11 | E-99 | brazil | `aewc__e_99` |
| 12 | G550 Eitam | israel | `aewc__g550_eitam` |
| 13 | KJ-500 | china | `aewc__kj_500` |
| 14 | Netra AEW&C | india | `aewc__netra_aew_c` |
| 15 | Saab 2000 Erieye | pakistan | `aewc__saab_2000_erieye` |

### `maritimePatrol` (P-8A Poseidon): 11 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Atlantique 2 | eu | `maritimePatrol__atlantique_2` |
| 2 | CN-235 MPA | indonesia | `maritimePatrol__cn_235_mpa` |
| 3 | Il-38N | russia | `maritimePatrol__il_38n` |
| 4 | Kawasaki P-1 | japan | `maritimePatrol__kawasaki_p_1` |
| 5 | P-3AM Orion | brazil | `maritimePatrol__p_3am_orion` |
| 6 | P-3C Orion | pakistan | `maritimePatrol__p_3c_orion` |
| 7 | P-72 | turkiye | `maritimePatrol__p_72` |
| 8 | P-8A Poseidon | australia, south_korea, usa | `maritimePatrol__p_8a_poseidon` |
| 9 | P-8I Neptune | india | `maritimePatrol__p_8i_neptune` |
| 10 | Poseidon MRA1 | uk | `maritimePatrol__poseidon_mra1` |
| 11 | Y-8Q | china | `maritimePatrol__y_8q` |

### `drone` (MQ-9 Reaper): 22 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Akinci / Wing Loong | ethiopia | `drone__akinci_wing_loong` |
| 2 | Bayraktar TB2 | turkiye | `drone__bayraktar_tb2` |
| 3 | Bayraktar TB2 / domestic | ukraine | `drone__bayraktar_tb2_domestic` |
| 4 | Bayraktar TB2 / Mohajer-6 | sudan | `drone__bayraktar_tb2_mohajer_6` |
| 5 | CH-4B | iraq | `drone__ch_4b` |
| 6 | CH-4B / Anka | indonesia | `drone__ch_4b_anka` |
| 7 | Hermes 900 | brazil, israel | `drone__hermes_900` |
| 8 | Heron ISR | india | `drone__heron_isr` |
| 9 | Heron TP | eu | `drone__heron_tp` |
| 10 | KUS-FS | south_korea | `drone__kus_fs` |
| 11 | Mohajer-6 | iran | `drone__mohajer_6` |
| 12 | MQ-9 Reaper | usa | `drone__mq_9_reaper` |
| 13 | MQ-9B Protector | uk | `drone__mq_9b_protector` |
| 14 | MQ-9B SeaGuardian | japan | `drone__mq_9b_seaguardian` |
| 15 | Orion | russia | `drone__orion` |
| 16 | Saetbyol-4/9 | north_korea | `drone__saetbyol_4_9` |
| 17 | Shaheen | syria | `drone__shaheen` |
| 18 | Shahpar II / Burraq | pakistan | `drone__shahpar_ii_burraq` |
| 19 | Taliban-built drone | afghanistan | `drone__taliban_built_drone` |
| 20 | Wing Loong I / CH-4 | egypt | `drone__wing_loong_i_ch_4` |
| 21 | Wing Loong II | china, nigeria | `drone__wing_loong_ii` |
| 22 | Wing Loong II / Akinci | saudi | `drone__wing_loong_ii_akinci` |

### `akinci` (Bayraktar Akinci): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Bayraktar Akinci | ethiopia, turkiye | `akinci__bayraktar_akinci` |

### `heavyBomberDrone` (Heavy Bomber Drone): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Heavy hexacopter | russia | `heavyBomberDrone__heavy_hexacopter` |
| 2 | Vampire (Baba Yaga) | ukraine | `heavyBomberDrone__vampire_baba_yaga` |

### `carrierDrone` (Carrier Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Carrier Drone | afghanistan, australia, brazil, china, egypt, eu, india, indonesia, iran, iraq, israel, japan, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `carrierDrone__carrier_drone` |

### `interceptorDrone` (Interceptor Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Interceptor Drone | ukraine | `interceptorDrone__interceptor_drone` |

### `shahed` (Shahed Drone): 2 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Geran-2 | russia | `shahed__geran_2` |
| 2 | Shahed Drone | iran | `shahed__shahed_drone` |

### `loiterer` (Switchblade 600): 11 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Arash | iran | `loiterer__arash` |
| 2 | CH-901 | china | `loiterer__ch_901` |
| 3 | Hero-120 | israel | `loiterer__hero_120` |
| 4 | HX-2 | eu | `loiterer__hx_2` |
| 5 | Kargu-2 | turkiye | `loiterer__kargu_2` |
| 6 | Lancet-3 | russia | `loiterer__lancet_3` |
| 7 | Loitering Munition | afghanistan, australia, brazil, egypt, indonesia, iraq, north_korea, pakistan, saudi, south_korea, syria, uk, ukraine | `loiterer__loitering_munition` |
| 8 | Loitering munition | japan | `loiterer__loitering_munition` |
| 9 | Nagastra-1 | india | `loiterer__nagastra_1` |
| 10 | Qasef-2K / Samad | houthis | `loiterer__qasef_2k_samad` |
| 11 | Switchblade 600 | usa | `loiterer__switchblade_600` |

### `harop` (Harop): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Harop | israel | `harop__harop` |

## P7 Ships and submarines

Hull, Turret_Main (axis Y) with Gun, Radar (axis Y), Wake_Bow and Wake_Stern markers, Propeller (submarines). The carrier: a flat deck with an island and the Deck markers Catapult_0..; a landing ship: Ramp (pivot at the hinge).

### `destroyer` (Arleigh Burke-class): 12 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Arleigh Burke-class | usa | `destroyer__arleigh_burke_class` |
| 2 | Choe Hyon-class | north_korea | `destroyer__choe_hyon_class` |
| 3 | Hobart-class | australia | `destroyer__hobart_class` |
| 4 | Horizon-class | eu | `destroyer__horizon_class` |
| 5 | Istanbul-class | turkiye | `destroyer__istanbul_class` |
| 6 | Maya-class | japan | `destroyer__maya_class` |
| 7 | Moudge-class | iran | `destroyer__moudge_class` |
| 8 | Sejong the Great-class | south_korea | `destroyer__sejong_the_great_class` |
| 9 | Type 055 | china | `destroyer__type_055` |
| 10 | Type 45 | uk | `destroyer__type_45` |
| 11 | Udaloy-class | russia | `destroyer__udaloy_class` |
| 12 | Visakhapatnam-class | india | `destroyer__visakhapatnam_class` |

### `aegisCruiser` (Maya-class Aegis destroyer): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Maya-class Aegis destroyer | japan | `aegisCruiser__maya_class_aegis_destroyer` |

### `type45` (Type 45 Destroyer): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Type 45 Destroyer | uk | `type45__type_45_destroyer` |

### `corvette` (Freedom-class LCS): 19 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Ada-class | turkiye | `corvette__ada_class` |
| 2 | Al Jubail-class | saudi | `corvette__al_jubail_class` |
| 3 | Amnok-class | north_korea | `corvette__amnok_class` |
| 4 | Anzac-class | australia | `corvette__anzac_class` |
| 5 | Babur-class (MILGEM) | pakistan | `corvette__babur_class_milgem` |
| 6 | Daegu-class | south_korea | `corvette__daegu_class` |
| 7 | Freedom-class LCS | usa | `corvette__freedom_class_lcs` |
| 8 | Gowind 2500 | egypt | `corvette__gowind_2500` |
| 9 | K130 Braunschweig | eu | `corvette__k130_braunschweig` |
| 10 | Kamorta-class | india | `corvette__kamorta_class` |
| 11 | Karakurt-class | russia | `corvette__karakurt_class` |
| 12 | Martadinata-class | indonesia | `corvette__martadinata_class` |
| 13 | Mogami-class | japan | `corvette__mogami_class` |
| 14 | OPV-76 / NNS Aradu | nigeria | `corvette__opv_76_nns_aradu` |
| 15 | Sa'ar 6 | israel | `corvette__sa_ar_6` |
| 16 | Shahid Soleimani-class | iran | `corvette__shahid_soleimani_class` |
| 17 | Tamandare frigate | brazil | `corvette__tamandare_frigate` |
| 18 | Type 056A | china | `corvette__type_056a` |
| 19 | Type 23 frigate | uk | `corvette__type_23_frigate` |

### `asFrigate` (Anti-submarine Frigate): 15 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Admiral Gorshkov-class | russia | `asFrigate__admiral_gorshkov_class` |
| 2 | Al Riyadh-class | saudi | `asFrigate__al_riyadh_class` |
| 3 | Anzac-class | australia | `asFrigate__anzac_class` |
| 4 | Daegu-class | south_korea | `asFrigate__daegu_class` |
| 5 | FREMM | eu | `asFrigate__fremm` |
| 6 | FREMM (Tahya Misr) | egypt | `asFrigate__fremm_tahya_misr` |
| 7 | Istanbul-class | turkiye | `asFrigate__istanbul_class` |
| 8 | Martadinata-class | indonesia | `asFrigate__martadinata_class` |
| 9 | Mogami-class | japan | `asFrigate__mogami_class` |
| 10 | Moudge-class | iran | `asFrigate__moudge_class` |
| 11 | Niteroi-class | brazil | `asFrigate__niteroi_class` |
| 12 | Talwar-class | india | `asFrigate__talwar_class` |
| 13 | Tughril-class | pakistan | `asFrigate__tughril_class` |
| 14 | Type 054A | china | `asFrigate__type_054a` |
| 15 | Type 23 | uk | `asFrigate__type_23` |

### `kcr60` (KCR-60): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | KCR-60 | indonesia | `kcr60__kcr_60` |

### `missileBoat` (Fast Missile Boat): 4 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Ambassador Mk III | egypt | `missileBoat__ambassador_mk_iii` |
| 2 | Azmat-class | pakistan | `missileBoat__azmat_class` |
| 3 | Sa'ar 4.5 | israel | `missileBoat__sa_ar_4_5` |
| 4 | Type 022 | china | `missileBoat__type_022` |

### `gunboat` (Gunboat): 3 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Gunboat | australia, brazil, china, egypt, eu, houthis, india, indonesia, iran, israel, japan, nigeria, north_korea, pakistan, russia, saudi, south_korea, sudan, syria, turkiye, uk, usa, yemen | `gunboat__gunboat` |
| 2 | Island-class patrol boat | ukraine | `gunboat__island_class_patrol_boat` |
| 3 | Patrol boat | iraq | `gunboat__patrol_boat` |

### `landingShip` (San Antonio-class): 13 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Albion-class | uk | `landingShip__albion_class` |
| 2 | Bahia | brazil | `landingShip__bahia` |
| 3 | Bayraktar-class | turkiye | `landingShip__bayraktar_class` |
| 4 | Canberra-class | australia | `landingShip__canberra_class` |
| 5 | Dokdo-class | south_korea | `landingShip__dokdo_class` |
| 6 | Hengam-class | iran | `landingShip__hengam_class` |
| 7 | INS Jalashwa | india | `landingShip__ins_jalashwa` |
| 8 | Ivan Gren-class | russia | `landingShip__ivan_gren_class` |
| 9 | Makassar-class | indonesia | `landingShip__makassar_class` |
| 10 | Mistral-class | egypt, eu | `landingShip__mistral_class` |
| 11 | Osumi-class | japan | `landingShip__osumi_class` |
| 12 | San Antonio-class | usa | `landingShip__san_antonio_class` |
| 13 | Type 071 | china | `landingShip__type_071` |

### `carrier` (Gerald R. Ford-class): 8 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Charles de Gaulle | eu | `carrier__charles_de_gaulle` |
| 2 | Fujian | china | `carrier__fujian` |
| 3 | Gerald R. Ford-class | usa | `carrier__gerald_r_ford_class` |
| 4 | INS Vikrant | india | `carrier__ins_vikrant` |
| 5 | Kaga (F-35B) | japan | `carrier__kaga_f_35b` |
| 6 | Queen Elizabeth-class | uk | `carrier__queen_elizabeth_class` |
| 7 | Shahid Bagheri (drone carrier) | iran | `carrier__shahid_bagheri_drone_carrier` |
| 8 | TCG Anadolu (drone carrier) | turkiye | `carrier__tcg_anadolu_drone_carrier` |

### `submarine` (Virginia-class): 17 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Agosta 90B | pakistan | `submarine__agosta_90b` |
| 2 | Astute-class | uk | `submarine__astute_class` |
| 3 | Collins-class | australia | `submarine__collins_class` |
| 4 | Dolphin II | israel | `submarine__dolphin_ii` |
| 5 | Dosan Ahn Changho-class | south_korea | `submarine__dosan_ahn_changho_class` |
| 6 | Fateh-class | iran | `submarine__fateh_class` |
| 7 | Improved Kilo | russia | `submarine__improved_kilo` |
| 8 | Kalvari-class | india | `submarine__kalvari_class` |
| 9 | Nagapasa-class | indonesia | `submarine__nagapasa_class` |
| 10 | Reis-class | turkiye | `submarine__reis_class` |
| 11 | Riachuelo-class | brazil | `submarine__riachuelo_class` |
| 12 | Romeo-class | north_korea | `submarine__romeo_class` |
| 13 | Taigei-class | japan | `submarine__taigei_class` |
| 14 | Type 039C | china | `submarine__type_039c` |
| 15 | Type 209/1400 | egypt | `submarine__type_209_1400` |
| 16 | Type 212A | eu | `submarine__type_212a` |
| 17 | Virginia-class | usa | `submarine__virginia_class` |

### `nuclearSub` (Ohio-class): 6 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Arihant-class | india | `nuclearSub__arihant_class` |
| 2 | Borei-A | russia | `nuclearSub__borei_a` |
| 3 | Ohio-class | usa | `nuclearSub__ohio_class` |
| 4 | Triomphant-class | eu | `nuclearSub__triomphant_class` |
| 5 | Type 094 | china | `nuclearSub__type_094` |
| 6 | Vanguard-class | uk | `nuclearSub__vanguard_class` |

### `seaDrone` (Sea Drone): 1 model(s)

| # | Model name (as the nation calls it) | Nations | File slug |
|---|---|---|---|
| 1 | Sea Drone | australia, brazil, china, egypt, eu, houthis, india, indonesia, iran, iraq, israel, japan, north_korea, pakistan, russia, saudi, south_korea, syria, turkiye, uk, ukraine, usa | `seaDrone__sea_drone` |

Total: 522 models. (Soldiers, teams, squads and single-man units are not in this list: they need a skeleton and are agreed separately.)
