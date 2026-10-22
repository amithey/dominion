"""Original designation-specific P5 helicopters, NumPy/stdlib, no Blender."""
from dataclasses import asdict
from pathlib import Path
import argparse,json
from helicopter_parts import HelicopterSpec,build,burnt_wreck
from vehicle_parts import Mesh,write_glb

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={
 'bell':'https://www.bellflight.com/products/-/media/site-specific/bell-flight/documents/products/412/bell-412epi-fact-sheet.pdf',
 'dhruv':'https://hal-india.co.in/backend/wp-content/uploads/2023/05/297_Download_ALH-DHRUV-UPGRADED-CIVIL.pdf',
 'h225':'https://www.airbus.com/en/products-services/helicopters/military-helicopters/h225m/h225m-technical-information',
 'surion':'https://www.koreaaero.com/KO/Business/KUH1.aspx',
 'merlin':'https://www.leonardo.com/documents/15646808/16756390/BROCHURE_AW101_Mk517.pdf',
 'mi':'https://rdl.train.army.mil/catalog-ws/view/100.ATSC/9132D7F5-95A6-4723-A29E-B1D4B6F8E3CE-1456490341914/tc3_01x80.pdf',
 'blackhawk':'https://www.lockheedmartin.com/content/dam/lockheed-martin/rms/documents/black-hawk/9221_S-70_Brochure_2024_web.pdf',
 'nh90':'https://www.nhindustries.com/wp-content/uploads/2025/06/NH90_Brochure_NHI_2024.pdf',
 'chinook':'https://www.boeing.com/defense/military-rotorcraft/h-47-chinook',
 'apache':'https://www.boeing.com/content/theboeingcompany/us/en/defense/military-rotorcraft/ah-64-apache.html',
 'wildcat':'https://www.leonardo.com/documents/16114711/0/AW159_LDO_UK24_00856_1024.pdf',
 'z20':'https://odin.t2com.army.mil/WEG/Asset/Z-20',
 'tiger':'https://www.airbus.com/en/products-services/helicopters/military-helicopters/tiger',
 'lch':'https://www.ddpmod.gov.in/en/resources/products/light-combat-helicopter-lch',
 'panther':'https://www.eeas.europa.eu/sites/default/files/fr_-_as-565_panther_update_01_2017.pdf',
 'seasprite':'https://www.nzdf.mil.nz/nzdf/our-equipment/aircraft/sh-2gi-seasprite-helicopter/',
 'oh1':'https://www.mod.go.jp/en/jdf/no111/equipment.html',
 'mi26':'https://www.rhc.ru/upload/iblock/97a/h0ix2juo2ve12ga2sd7aaeop3io6r943.pdf',
}
# Body length/width/height, belly clearance, hub Y/Z, main diameter/blades,
# tail diameter/blades, landing gear, source. Body length excludes rotor sweep.
FAMILIES={
 'bell412':(12.92,2.50,2.20,.62,3.85,2.55,14.02,4,2.60,2,'skid','bell'),
 'dhruv':(12.89,2.05,2.20,.72,3.89,2.72,13.20,4,2.55,4,'skid','dhruv'),
 'h225':(16.79,2.80,2.80,.75,4.43,2.95,16.20,5,3.15,4,'tricycle','h225'),
 'surion':(15.00,2.45,2.55,.78,4.00,2.60,15.80,4,3.10,4,'tricycle','surion'),
 'merlin':(19.53,3.20,3.20,.90,5.15,3.65,18.60,5,4.00,4,'tricycle','merlin'),
 'mi17':(18.17,2.50,3.25,.85,5.05,3.65,21.29,5,3.91,3,'tricycle','mi'),
 'mi8':(18.17,2.50,3.25,.85,5.05,3.65,21.29,5,3.91,3,'tricycle','mi'),
 'bell205':(12.69,2.50,2.20,.62,3.85,2.55,14.64,2,2.60,2,'skid','mi'),
 'nh90':(16.13,2.60,2.90,.70,4.30,3.20,16.30,4,3.20,4,'tricycle','nh90'),
 'blackhawk':(15.27,2.36,2.45,.65,3.80,2.81,16.36,4,3.35,4,'tailwheel','blackhawk'),
 'z20':(16.00,2.40,2.55,.70,4.00,3.10,16.00,5,3.20,4,'tailwheel','z20'),
 'cobra':(13.87,1.00,2.05,.70,3.40,2.70,13.40,2,2.60,2,'skid','mi'),
 'toufan':(13.87,1.10,2.10,.70,3.45,2.70,13.40,2,2.60,2,'skid','mi'),
 'apache':(14.68,1.70,2.45,.75,3.80,2.20,14.63,4,2.79,4,'tailwheel','apache'),
 'mangusta':(12.28,1.05,2.15,.70,3.35,2.35,11.90,5,2.30,2,'tailwheel','mi'),
 'ka52':(15.85,2.20,2.45,.80,4.00,2.95,14.50,3,0,0,'tricycle','mi'),
 'lch':(12.10,1.25,2.40,.75,3.70,2.35,13.20,4,2.55,4,'skid','lch'),
 'mi24':(17.51,1.80,2.95,1.00,4.60,3.00,17.30,5,3.90,3,'tricycle','mi'),
 'mi28':(16.85,1.80,2.65,.95,4.35,2.80,17.20,5,3.85,4,'tailwheel','mi'),
 't129':(12.28,1.10,2.20,.70,3.40,2.35,11.90,5,2.30,2,'tailwheel','mi'),
 'tiger':(13.85,1.10,2.30,.80,3.65,2.65,13.00,4,2.70,3,'tailwheel','tiger'),
 'z10':(14.15,1.20,2.35,.75,3.70,2.70,13.00,5,2.80,4,'tailwheel','mi'),
 'panther':(11.63,2.00,2.00,.60,3.30,2.00,11.94,4,1.10,11,'tricycle','panther'),
 'ka27':(11.30,3.50,3.10,.70,4.55,.65,15.90,3,0,0,'four','mi'),
 'seasprite':(12.30,2.40,2.40,.65,3.55,2.30,13.50,4,2.48,4,'tricycle','seasprite'),
 'wildcat':(12.00,2.00,2.10,.55,3.35,2.10,12.80,4,2.21,4,'tricycle','wildcat'),
 'chinook':(15.56,2.85,2.70,.85,3.80,5.90,18.30,3,0,0,'four','chinook'),
 'mi26':(33.73,4.40,4.50,1.10,7.36,6.50,32.00,8,7.60,5,'tricycle','mi26'),
 'z8':(20.90,3.20,4.20,1.00,6.30,3.90,18.90,6,4.00,5,'tricycle','mi'),
 'oh1':(12.00,1.00,2.10,.55,3.20,1.05,11.60,4,1.60,8,'tailwheel','oh1'),
}

# z/body length, centre offset/body height, half-width/body width,
# half-height/body height: cabin shapes differ independently of size.
PROFILES={
 'bell412':[(.00,.13,.18,.23),(.045,0,.43,.46),(.14,0,.50,.50),(.31,0,.50,.50),(.405,-.02,.42,.43),(.475,-.15,.24,.27),(.50,-.18,.055,.09)],
 'dhruv':[(-.035,.12,.20,.24),(.025,0,.42,.44),(.13,0,.50,.50),(.29,0,.50,.50),(.40,-.04,.43,.43),(.475,-.17,.20,.24),(.50,-.19,.045,.065)],
 'h225':[(-.045,.16,.17,.22),(.015,.03,.40,.43),(.12,0,.50,.50),(.27,0,.50,.50),(.38,-.025,.44,.45),(.475,-.20,.20,.25),(.50,-.22,.04,.06)],
 'surion':[(-.03,.15,.20,.25),(.03,.02,.45,.46),(.14,0,.50,.50),(.30,0,.50,.50),(.405,-.01,.46,.46),(.475,-.13,.26,.30),(.50,-.16,.08,.10)],
 'merlin':[(-.17,0,.35,.43),(-.12,.01,.46,.45),(.02,0,.50,.50),(.26,0,.50,.50),(.39,-.025,.47,.47),(.475,-.13,.26,.29),(.50,-.18,.055,.09)],
 'mi17':[(.00,.15,.26,.27),(.055,0,.46,.47),(.17,0,.50,.50),(.34,0,.50,.49),(.445,-.015,.43,.44),(.485,-.11,.22,.28),(.50,-.16,.065,.12)],
 'nh90':[(-.17,0,.33,.43),(-.11,0,.46,.46),(.04,0,.50,.50),(.28,0,.50,.50),(.40,-.02,.43,.46),(.475,-.15,.22,.28),(.50,-.16,.055,.09)],
 'blackhawk':[(-.24,.10,.18,.18),(-.13,0,.43,.38),(.04,0,.50,.50),(.27,0,.50,.50),(.40,-.03,.43,.46),(.475,-.14,.22,.25),(.50,-.17,.07,.09)],
}
PROFILES['mi8']=PROFILES['mi17'];PROFILES['bell205']=PROFILES['bell412'];PROFILES['z20']=PROFILES['blackhawk']
PROFILES.update({
 'cobra':[(-.12,.05,.20,.25),(.01,0,.43,.43),(.13,.10,.50,.53),(.22,.02,.46,.46),(.34,-.10,.40,.42),(.45,-.25,.22,.24),(.50,-.29,.045,.055)],
 'apache':[(-.18,.03,.23,.28),(-.03,0,.46,.44),(.12,.04,.50,.50),(.24,-.04,.44,.45),(.36,-.16,.39,.39),(.46,-.27,.27,.27),(.50,-.28,.08,.10)],
 'mangusta':[(-.14,0,.20,.25),(.0,0,.43,.43),(.14,.08,.50,.52),(.25,-.01,.44,.45),(.36,-.12,.38,.40),(.46,-.24,.20,.22),(.50,-.27,.045,.06)],
 'ka52':[(-.16,.03,.22,.25),(-.02,0,.45,.44),(.13,0,.50,.50),(.30,0,.50,.50),(.42,-.05,.43,.44),(.48,-.18,.24,.27),(.50,-.20,.075,.08)],
 'mi24':[(-.24,.10,.20,.24),(-.13,0,.44,.44),(.01,0,.50,.50),(.14,.08,.46,.55),(.24,0,.40,.46),(.34,-.09,.38,.48),(.45,-.22,.26,.30),(.50,-.25,.055,.07)],
 'mi28':[(-.20,.06,.20,.25),(-.03,0,.45,.44),(.12,.10,.49,.53),(.24,0,.43,.46),(.35,-.12,.38,.41),(.45,-.21,.27,.29),(.50,-.25,.065,.08)],
 'tiger':[(-.16,.05,.20,.24),(-.02,0,.42,.43),(.13,.10,.50,.53),(.25,-.02,.45,.44),(.37,-.13,.38,.40),(.46,-.26,.21,.23),(.50,-.29,.05,.055)],
 'lch':[(-.15,.04,.20,.23),(-.01,0,.42,.43),(.12,.08,.50,.52),(.24,-.01,.43,.45),(.36,-.12,.36,.40),(.46,-.24,.22,.24),(.50,-.27,.05,.065)],
 'z10':[(-.17,.05,.22,.25),(-.02,0,.43,.44),(.13,.07,.50,.52),(.24,-.02,.44,.46),(.36,-.13,.37,.41),(.46,-.25,.23,.25),(.50,-.28,.05,.07)],
})
PROFILES['toufan']=PROFILES['cobra'];PROFILES['t129']=PROFILES['mangusta']
PROFILES.update({
 'panther':[(-.06,.10,.19,.24),(.01,0,.41,.44),(.13,0,.50,.50),(.31,0,.50,.50),(.42,-.02,.41,.43),(.48,-.15,.20,.23),(.50,-.18,.045,.06)],
 'ka27':[(-.36,0,.35,.40),(-.29,0,.48,.48),(-.04,0,.50,.50),(.25,0,.50,.50),(.41,-.03,.44,.46),(.48,-.11,.25,.30),(.50,-.14,.08,.13)],
 'seasprite':[(-.12,.08,.22,.28),(-.05,0,.43,.44),(.12,0,.50,.50),(.31,0,.50,.50),(.42,-.03,.44,.45),(.48,-.16,.21,.25),(.50,-.19,.06,.07)],
 'wildcat':[(-.14,.04,.25,.30),(-.08,0,.46,.46),(.10,0,.50,.50),(.30,0,.50,.50),(.41,-.02,.45,.45),(.48,-.12,.25,.28),(.50,-.16,.08,.10)],
 'mi26':[(-.15,0,.35,.43),(-.10,0,.49,.49),(.04,0,.50,.50),(.26,0,.50,.50),(.39,-.02,.46,.46),(.48,-.12,.23,.29),(.50,-.16,.06,.10)],
 'z8':[(-.14,.06,.25,.32),(-.08,0,.46,.46),(.05,0,.50,.50),(.27,0,.50,.50),(.40,-.03,.44,.46),(.48,-.14,.24,.30),(.50,-.18,.08,.12)],
})
PROFILES['oh1']=PROFILES['tiger']

def model(slug,name,lod,family,representative='',**overrides):
    L,W,H,b,hy,hz,D,N,td,tn,gear,ref=FAMILIES[family]
    s=HelicopterSpec(slug,name,family,L,W,H,b,hy,hz,D,N,td,tn,gear,REF[ref])
    if family in ('merlin','z8'):s.engines=3
    if family=='mi17':s.tail_side=-1
    if family=='blackhawk':s.tail_cant=20
    s.details['tail_y']={'bell412':3.00,'bell205':3.00,'dhruv':3.70,'h225':3.40,'surion':3.10,'merlin':4.66,'mi17':3.70,'mi8':3.70,'blackhawk':3.50,'nh90':3.70,'z20':3.50,
        'panther':2.80,'ka27':2.50,'seasprite':2.85,'wildcat':2.63,'mi26':4.35,'z8':4.60,'oh1':2.60}.get(family,hy-.35)
    if family in PROFILES:
        s.details.update(profile=PROFILES[family],boom_start=(-.10 if family=='merlin' else .08),
            window_z=((-.07,.04,.15,.26) if family=='merlin' else (.08,.18,.27)),
            main_gear_z=(.04 if family in ('mi17','mi8') else .0 if family in ('surion','h225') else -.08))
    if family in ('blackhawk','z20'):
        s.details.update(cross_section_power=.76,boom_start=-.13,boom_y=2.45,tail_gear_z=-.22,tail_gear_anchor_y=1.56,window_z=(-.03,.10,.23))
    if family=='nh90':s.details.update(cross_section_power=.72,boom_start=-.10)
    if family in ('panther','oh1'):s.details.update(fenestron=True,boom_start=.06)
    if family=='ka27':s.details.update(cross_section_power=.65,boom_start=-.30,gear_spread=.48)
    if family=='wildcat':s.details.update(cross_section_power=.70,boom_start=-.07)
    if family=='chinook':s.details.update(aft_hub_y=5.45,aft_hub_z=-5.90)
    if family=='mi26':s.details.update(main_gear_z=.08,gear_spread=.87)
    attack={'cobra':(3.28,2,3),'toufan':(3.28,2,3),'apache':(5.23,2,1),'mangusta':(3.20,2,3),
        'ka52':(7.30,3,1),'lch':(4.60,2,1),'mi24':(6.54,3,1),'mi28':(4.88,2,1),
        't129':(3.20,2,3),'tiger':(4.50,2,1),'z10':(4.20,2,1)}
    if family in attack:
        s.attack=True;span,stations,barrels=attack[family]
        s.details.update(wing_span=span,stations_per_wing=stations,gun_barrels=barrels,
            tail_y={'cobra':2.90,'toufan':2.90,'apache':3.35,'ka52':2.50,'mi24':3.10,'mi28':3.35}.get(family,hy-.30),
            tail_gear_z=-.25,tail_gear_anchor_y=1.50)
        if family=='cobra':s.engines=1
        if family in ('apache','mi28'):s.details['mast_radar']=True
        if family=='ka52':s.details.update(fixed_gun=True,gun_side=1,missiles_per_bank=6)
        if family not in ('mi24','ka52'):s.details['cross_section_power']=.80
    if family=='oh1':
        s.attack=True;s.details.update(gun=False,scout_aam=True,roof_sensor=True,wing_span=3.30,
            stations_per_wing=1,missiles_per_bank=2,tail_gear_z=-.40,tail_gear_anchor_y=1.70)
    for key,value in overrides.items():
        if key=='details':s.details.update(value)
        else:setattr(s,key,value)
    s.representative=representative;s.approximate=True
    s.features=[family+' fuselage and tail profile',str(s.blades)+'-blade '+str(s.rotor_diameter)+' m main rotor',
        str(tn)+'-blade tail rotor',gear+' landing gear',str(s.engines)+' separate turbine nacelles',
        'published rotor size; small fittings and fuselage cross-sections approximated']
    if s.attack:s.features += [str(s.details['wing_span'])+' m stub-wing span',
        str(s.details['stations_per_wing'])+' weapon stations per wing',
        'roof observation sight and four AAMs' if not s.details.get('gun',True) else 'fixed side cannon' if s.details.get('fixed_gun') else 'chin turret with separate gun trunnion']
    if family in ('ka27','ka52'):s.features.append('two counterrotating coaxial main rotors; no tail rotor')
    if family=='chinook':s.features.append('two tandem three-blade main rotors, raised aft pylon and rear engine pods')
    if s.naval:s.features.append('naval radar/hoist and the selected real mission stores')
    return build(s,lod)

def helicopter__bell_412epi(lod=0):
    return model('helicopter__bell_412epi','Bell 412EPi',lod,'bell412')

def helicopter__dhruv_alh(lod=0):
    return model('helicopter__dhruv_alh','Dhruv ALH',lod,'dhruv')

def helicopter__h225m(lod=0):
    return model('helicopter__h225m','H225M',lod,'h225')

def helicopter__kuh_1_surion(lod=0):
    return model('helicopter__kuh_1_surion','KUH-1 Surion',lod,'surion')

def helicopter__merlin_hc4(lod=0):
    return model('helicopter__merlin_hc4','Merlin HC4',lod,'merlin')

def helicopter__mi_17(lod=0):
    return model('helicopter__mi_17','Mi-17',lod,'mi17')

def helicopter__mi_17_aw109(lod=0):
    return model('helicopter__mi_17_aw109','Mi-17 / AW109',lod,'mi17','Mi-17')

def helicopter__mi_8(lod=0):
    return model('helicopter__mi_8','Mi-8',lod,'mi8')

def helicopter__mi_8amtsh(lod=0):
    return model('helicopter__mi_8amtsh','Mi-8AMTSh',lod,'mi17',details={'armoured_transport':True})

def helicopter__nh90(lod=0):
    return model('helicopter__nh90','NH90',lod,'nh90')

def helicopter__nh90_caiman(lod=0):
    return model('helicopter__nh90_caiman','NH90 Caiman',lod,'nh90')

def helicopter__shabaviz_2_75(lod=0):
    return model('helicopter__shabaviz_2_75','Shabaviz 2-75',lod,'bell205','Shabaviz 2-75, Bell 205-derived exterior',engines=1)

def helicopter__t70_black_hawk(lod=0):
    return model('helicopter__t70_black_hawk','T70 Black Hawk',lod,'blackhawk')

def helicopter__uh_60_captured(lod=0):
    return model('helicopter__uh_60_captured','UH-60 (captured)',lod,'blackhawk','UH-60A transport exterior',details={'main_blade_chord':.42})

def helicopter__uh_60_mi_17(lod=0):
    return model('helicopter__uh_60_mi_17','UH-60 / Mi-17',lod,'blackhawk','UH-60M')

def helicopter__uh_60_yanshuf(lod=0):
    return model('helicopter__uh_60_yanshuf','UH-60 Yanshuf',lod,'blackhawk',details={'main_blade_chord':.42})

def helicopter__uh_60ja(lod=0):
    return model('helicopter__uh_60ja','UH-60JA',lod,'blackhawk',details={'main_blade_chord':.42,'chin_sensor':True})

def helicopter__uh_60m(lod=0):
    return model('helicopter__uh_60m','UH-60M',lod,'blackhawk')

def helicopter__uh_60m_black_hawk(lod=0):
    return model('helicopter__uh_60m_black_hawk','UH-60M Black Hawk',lod,'blackhawk')

def helicopter__z_20(lod=0):
    return model('helicopter__z_20','Z-20',lod,'z20')

def gunship__ah_1f_cobra_z_10me(lod=0):
    return model('gunship__ah_1f_cobra_z_10me','AH-1F Cobra / Z-10ME',lod,'cobra','AH-1F Cobra')

def gunship__ah_64_saraf(lod=0):
    return model('gunship__ah_64_saraf','AH-64 Saraf',lod,'apache')

def gunship__ah_64d_ka_52(lod=0):
    return model('gunship__ah_64d_ka_52','AH-64D / Ka-52',lod,'apache','AH-64D Apache Longbow')

def gunship__ah_64djp(lod=0):
    return model('gunship__ah_64djp','AH-64DJP',lod,'apache')

def gunship__ah_64e_apache(lod=0):
    return model('gunship__ah_64e_apache','AH-64E Apache',lod,'apache')

def gunship__aw129_mangusta(lod=0):
    return model('gunship__aw129_mangusta','AW129 Mangusta',lod,'mangusta','A129 CBT upgraded five-blade gunship')

def gunship__ka_52m(lod=0):
    return model('gunship__ka_52m','Ka-52M',lod,'ka52')

def gunship__lch_prachand(lod=0):
    return model('gunship__lch_prachand','LCH Prachand',lod,'lch')

def gunship__mi_24(lod=0):
    return model('gunship__mi_24','Mi-24',lod,'mi24','Mi-24V',details={'gun_barrels':4})

def gunship__mi_24v(lod=0):
    return model('gunship__mi_24v','Mi-24V',lod,'mi24',details={'gun_barrels':4})

def gunship__mi_24v_mi_35(lod=0):
    return model('gunship__mi_24v_mi_35','Mi-24V / Mi-35',lod,'mi24','Mi-24V',details={'gun_barrels':4})

def gunship__mi_28ne(lod=0):
    return model('gunship__mi_28ne','Mi-28NE',lod,'mi28')

def gunship__mi_35p(lod=0):
    return model('gunship__mi_35p','Mi-35P',lod,'mi24',details={'fixed_gun':True,'gun_side':1,'gun_barrels':2})

def gunship__t129_atak(lod=0):
    return model('gunship__t129_atak','T129 ATAK',lod,'t129')

def gunship__t129_atak_mi_35m(lod=0):
    return model('gunship__t129_atak_mi_35m','T129 ATAK / Mi-35M',lod,'t129','T129 ATAK')

def gunship__tiger(lod=0):
    return model('gunship__tiger','Tiger',lod,'tiger','Tiger HAD gun-armed exterior')

def gunship__toufan(lod=0):
    return model('gunship__toufan','Toufan',lod,'toufan')

def gunship__z_10(lod=0):
    return model('gunship__z_10','Z-10',lod,'z10')

def navalHelicopter__as565_panther(lod=0):
    return model('navalHelicopter__as565_panther','AS565 Panther',lod,'panther','AS565 SA/MB naval exterior with eleven-blade Fenestron',naval=True)

def navalHelicopter__ka_27pl(lod=0):
    return model('navalHelicopter__ka_27pl','Ka-27PL',lod,'ka27',naval=True,details={'naval_store':'internal'})

def navalHelicopter__mh_60r_seahawk(lod=0):
    return model('navalHelicopter__mh_60r_seahawk','MH-60R Seahawk',lod,'blackhawk',naval=True,
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'chin_sensor':True})

def navalHelicopter__nh90_nfh(lod=0):
    return model('navalHelicopter__nh90_nfh','NH90 NFH',lod,'nh90',naval=True)

def navalHelicopter__nh90_sea_lion(lod=0):
    return model('navalHelicopter__nh90_sea_lion','NH90 Sea Lion',lod,'nh90',naval=True,details={'naval_store':'none'})

def navalHelicopter__s_70b_seahawk(lod=0):
    return model('navalHelicopter__s_70b_seahawk','S-70B Seahawk',lod,'blackhawk',naval=True,
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'main_blade_chord':.42})

def navalHelicopter__sh_2g_super_seasprite(lod=0):
    return model('navalHelicopter__sh_2g_super_seasprite','SH-2G Super Seasprite',lod,'seasprite',naval=True)

def navalHelicopter__sh_60k(lod=0):
    return model('navalHelicopter__sh_60k','SH-60K',lod,'blackhawk',naval=True,length=16.40,width=2.45,
        body_height=2.60,hub_y=4.00,rotor_diameter=16.40,
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'main_blade_chord':.50,'chin_sensor':True})

def navalHelicopter__wildcat_hma2(lod=0):
    return model('navalHelicopter__wildcat_hma2','Wildcat HMA2',lod,'wildcat',naval=True,
        details={'naval_store':'missile','chin_sensor':True})

def navalHelicopter__z_20f(lod=0):
    return model('navalHelicopter__z_20f','Z-20F',lod,'z20',naval=True,
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'chin_sensor':True})

def heavyLift__ch_47d_chinook(lod=0):
    return model('heavyLift__ch_47d_chinook','CH-47D Chinook',lod,'chinook')

def heavyLift__ch_47f_chinook(lod=0):
    return model('heavyLift__ch_47f_chinook','CH-47F Chinook',lod,'chinook')

def heavyLift__ch_47f_i_chinook(lod=0):
    return model('heavyLift__ch_47f_i_chinook','CH-47F(I) Chinook',lod,'chinook')

def heavyLift__ch_47ja_chinook(lod=0):
    return model('heavyLift__ch_47ja_chinook','CH-47JA Chinook',lod,'chinook')

def heavyLift__chinook_hc6(lod=0):
    return model('heavyLift__chinook_hc6','Chinook HC6',lod,'chinook')

def heavyLift__mi_26(lod=0):
    return model('heavyLift__mi_26','Mi-26',lod,'mi26')

def heavyLift__z_8l(lod=0):
    return model('heavyLift__z_8l','Z-8L',lod,'z8')

def scoutHelicopter__oh_1(lod=0):
    return model('scoutHelicopter__oh_1','OH-1',lod,'oh1')

def scoutHelicopter__wildcat_mk1(lod=0):
    return model('scoutHelicopter__wildcat_mk1','Wildcat Mk1',lod,'wildcat',details={'chin_sensor':True})

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and n.split('__')[0] in ('helicopter','gunship','navalHelicopter','heavyLift','scoutHelicopter') and callable(f)}
assert len(BUILDERS)==57

def save(slug,output_dir=None,tree_dir=None,print_tree=True):
    from validate_aircraft import validate
    a,s=BUILDERS[slug](0);b,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
    out=Path(output_dir) if output_dir else ART/'aircraft';out.mkdir(exist_ok=True)
    path=out/(slug+'.glb');collision=Mesh();top=s.belly+s.body_height
    collision.box('metal_dark',(0,top/2,0),(s.width,top,s.length))
    write_glb(path,[a,b],burnt_wreck(b,s),collision,{'scene_name':s.name,'vehicle':slug,'priority':'P5','spec':asdict(s),
         'units':'metres','up':'+Y','front':'+Z','detached_turret':False})
    entry,tree=validate(path)
    treepath=(Path(tree_dir) if tree_dir else Path(__file__).parent/'reports')/(slug+'.node-tree.txt')
    treepath.write_text(tree,encoding='utf-8')
    if print_tree:print(tree)
    print('PASS',slug,entry['triangles'],flush=True);return entry

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    path=ART/'MANIFEST.json';old=json.loads(path.read_text());updates={e['file']:e for e in entries}
    path.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n')
    a.report.write_text(json.dumps(entries,indent=2)+'\n')
if __name__=='__main__':main()
