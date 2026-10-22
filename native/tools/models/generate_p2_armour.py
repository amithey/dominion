#!/usr/bin/env python3
"""P2 roster + Leclerc. Twelve reviewable batches (6 x 10, 5 x 2).

python native/tools/models/generate_p2_armour.py --batch 1 --report /path/batch.json
Use --validate-only to inspect existing files without rewriting their bytes.
Every designation has its own function. Combined rows choose one named real
representative; unspecified generic rows and uncertain fits are labelled.
No game files, textures, Blender, imported source meshes or P3 assets.
"""
from dataclasses import asdict
from pathlib import Path
import argparse, json
import numpy as np
from vehicle_parts import Mesh, loft, write_glb, merge_mesh
from armour_parts import ArmourSpec, build, wreck
from generate_p1_tanks import Spec, finish, make_wreck, beam

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={
 'leclerc':'https://media.knds.com/uploads/KRV_041_LECLERC_XLR_EN_BAT_BDEF_6a502524d1.pdf',
 'boxer':'https://www.army.mod.uk/learn-and-explore/equipment/combat-vehicles/boxer/',
 'crv':'https://www.army.gov.au/equipment/vehicles-and-surveillance/boxer-combat-reconnaissance-vehicle',
 'soviet':'https://www.trngcmd.marines.mil/Portals/207/Docs/MCIS/ITEP/RITC-East/FM%20100-2-3.pdf',
 'pindad':'https://www.pindad.org/special-vehicles',
 'ukraine':'https://morozov.com.ua/en/bronetexnika-i-vooruzhenie/bronetransportery/btr-4/',
 'stryker':'https://www.gdls.com/stryker/',
 'pars':'https://www.fnss.com.tr/en/products/pars-8x8-wheeled-armoured-combat-vehicle',
 'acv':'https://www.fnss.com.tr/uploads/docs/IDEF%2023%20KATALOGLAR%20ENG/1688545777_acv-15-eng-2023.pdf',
 'japan':'https://www.mod.go.jp/gsdf/equipment/ve/',
 'type96':'https://www.mod.go.jp/en/jdf/no114/equipment.html',
 'puma':'https://www.rheinmetall.com/en/products/tracked-armoured-vehicles',
 'bradley':'https://www.baesystems.com/en-us/product/bradley-fighting-vehicle',
 'pandur':'https://www.gdels.com/en/products/wheeled-vehicles/pandur',
 'warrior':'https://www.army.mod.uk/learn-and-explore/equipment/combat-vehicles/warrior/',
 'bushmaster':'https://www.army.gov.au/equipment/vehicles-and-surveillance/bushmaster',
 'hawkei':'https://www.thalesgroup.com/sites/default/files/2025-08/hawkei-new-generation-protected-vehicle.pdf',
 'fennek':'https://www.knds.com/en/products/systems/fennek',
 'jackal':'https://www.army.mod.uk/learn-and-explore/equipment/combat-vehicles/jackal-2/',
 'm88':'https://www.baesystems.com/en-us/product/m88a2-hercules-recovery-vehicle',
 'trojan':'https://www.army.mod.uk/learn-and-explore/equipment/engineering-equipment/trojan-armoured-vehicle/',
 'volcano':'https://asc.army.mil/docs/wsh2/1997-wsh.pdf',
 'korean':'https://www.hyundai-rotem.co.kr/en/business/defense/',
 'k21':'https://www.hanwhaaerospace.com/eng/business/land/',
 'israel':'https://www.mod.gov.il/en/departments/merkava-and-armored-vehicles-directorate',
 'hit':'https://hit.gov.pk/defence-tab.php',
 'china':'https://eng.mod.gov.cn/',
 'whap':'https://www.drdo.gov.in/drdo/wheeled-armoured-platform-whap',
 'guarani':'https://www.idvgroup.com/guarani',
 'koral':'https://www.aselsan.com/en/defence/product/2074/koral',
 'elbit':'https://www.elbitsystems.com/land/electronic-warfare',
}


def carrier(slug,name,lod,L,W,H,family,weapon='',wheels=4,r=.51,k=1.,tracked=False,
            source='soviet',features=(),z=0.,x=0.,approx=False,representative='',axles=None,**details):
    # The explicit axle layouts below are in rear-to-front order, as in P1.
    if axles is None:
        axles=([-L*.31,L*.31] if wheels==2 else [-L*.32,-L*.05,L*.32] if wheels==3 else
               [-L*.34,-L*.14,L*.13,L*.34]) if not tracked else []
    front=details.pop('front_engine',family not in ('btr','bmp3','zbd','recovery'))
    equipment=details.pop('equipment','');bow=details.pop('bow',.57);shoulder=details.pop('shoulder',.78)
    s=ArmourSpec(slug,name,L,W,H,'tracked' if tracked else 'wheeled',wheels,r,family,weapon,
          list(features),REF.get(source,source),k,front,approx,representative,list(axles),z,x,equipment,bow,shoulder,details)
    return build(s,lod)


def tank__leclerc(lod=0):
    s=Spec('leclerc','Leclerc',6.88,3.60,1.40,2.44,6,.35,.88,.05,1.91,1.24,9.87,'leclerc',
        ['Six road wheels','long French CN120-26 L/52 barrel','faceted modular cheek armour',
         'low compact turret with broad rectangular autoloader bustle','HL-70 panoramic sight on left roof',
         'right-front gunner sight recess','rear V8X engine deck, segmented side skirts'],REF['leclerc'])
    b=[(-.33,1.34),(.33,1.34),(1.45,.64),(1.43,-1.49),(1.18,-1.88),(-1.18,-1.88),(-1.43,-1.49),(-1.45,.64)]
    t=[(-.33,.94),(.33,.94),(1.20,.45),(1.24,-1.46),(1.08,-1.80),(-1.08,-1.80),(-1.24,-1.46),(-1.20,.45)]
    def detail(h,m,s,l):
        m.box('paint',(0,2.15,-1.57),(2.17,.52,.66))
        for side in (-1,1):
            m.box('paint',(side*1.29,1.94,.44),(.24,.47,.72))
            if not l:
                for z in (-.39,.11,.61):m.box('metal_dark',(side*1.42,2.09,z),(.025,.030,.10))
        m.box('paint',(.64,2.34,.67),(.52,.26,.40));m.box('glass',(.64,2.36,.881),(.35,.13,.025))
        m.tube('paint',(-.62,2.42,-.25),(-.62,2.65,-.25),.18,6 if l else 12)
        m.box('paint',(-.62,2.69,-.25),(.37,.22,.35));m.box('glass',(-.62,2.69,-.061),(.25,.13,.025))
    return finish(s,b,t,lod,detail)


def apc__anoa(lod=0):
    return carrier('apc__anoa','Anoa',lod,6.0,2.50,2.36,'anoa','rws',3,.50,source='pindad',z=-.15,
        features=['6x6 with isolated front axle and close rear tandem','angled cab windscreen','high rear troop compartment','rear access ramp'],axles=[-1.95,-.55,1.87],spare=True,side_door=True)

def apc__bmp_1(lod=0):
    return carrier('apc__bmp_1','BMP-1',lod,6.74,2.94,1.52,'bmp','bmp1',6,.285,.77,True,z=-.24,
        features=['Six small road wheels','very low sloped hull','single-man conical turret','short 73 mm gun and Malyutka launch rail','twin rear fuel doors'],ports=3,rear_doors=True)

def apc__bmp_2_btr_80_captured(lod=0):
    return carrier('apc__bmp_2_btr_80_captured','BMP-2 / BTR-80 (captured)',lod,6.74,3.15,1.55,'bmp','bmp2',6,.285,.77,True,z=-.20,
        features=['BMP-2 selected for combined row','six wheels','two-man turret with long 30 mm cannon','low pointed BMP bow','rear fuel doors'],representative='BMP-2',approx=True,ports=3,rear_doors=True,storage=True)

def apc__boxer(lod=0):
    return carrier('apc__boxer','Boxer',lod,7.93,2.99,2.38,'boxer','rws',4,.61,source='boxer',z=.50,
        features=['8x8 large road tyres','separate tall rear mission module','sharply sloped front drive module','roof remote weapon station'],bow=.38,shoulder=.89)

def apc__boxer_crv(lod=0):
    return carrier('apc__boxer_crv','Boxer CRV',lod,7.93,2.99,2.38,'boxer','lance',4,.61,source='crv',z=-.15,
        features=['8x8 Boxer hull','large two-man Lance 30 mm turret','side missile pod','tall modular mission compartment'],bow=.38,shoulder=.89,storage=True)

def apc__btr_3un_proforce_ara(lod=0):
    return carrier('apc__btr_3un_proforce_ara','BTR-3UN / Proforce Ara',lod,7.65,2.90,1.94,'btr','parus',4,.54,source='ukraine',z=-.12,
        features=['BTR-3UN selected for combined row','8x8 boat hull with dual front windows','30 mm remote turret','side doors between middle axles'],representative='BTR-3UN',approx=True,swim=True,side_door=True)

def apc__btr_4(lod=0):
    return carrier('apc__btr_4','BTR-4',lod,7.65,2.92,2.22,'btr4','parus',4,.54,source='ukraine',z=-.65,
        features=['8x8 with mid-engine raised roof','forward driving compartment','Parus unmanned 30 mm turret','large rear ramp and waterjets'],swim=True,bow=.70,shoulder=.91)

def apc__btr_4_m113(lod=0):
    return carrier('apc__btr_4_m113','BTR-4 / M113',lod,7.65,2.92,2.22,'btr4','parus',4,.54,source='ukraine',z=-.65,
        features=['Iraqi BTR-4E selected','8x8 mid-engine carrier','Parus turret','rear ramp and paired waterjets'],representative='BTR-4E',approx=True,swim=True,bow=.70,shoulder=.91,storage=True)

def apc__btr_60_bmp_1(lod=0):
    return carrier('apc__btr_60_bmp_1','BTR-60 / BMP-1',lod,7.56,2.825,1.80,'btr','kpvt',4,.50,z=.37,
        features=['BTR-60PB selected','eight equally spaced wheels','narrow boat hull and steep prow','small conical KPVT turret','twin rear engine decks'],representative='BTR-60PB',approx=True,axles=[-2.25,-.75,.75,2.25],swim=True,ports=3)

def apc__btr_60_mrap(lod=0):
    return carrier('apc__btr_60_mrap','BTR-60 / MRAP',lod,7.56,2.825,1.80,'btr','kpvt',4,.50,z=.37,
        features=['BTR-60PB selected for combined row','8x8 amphibious boat hull','KPVT conical turret','rear engine covers'],representative='BTR-60PB',approx=True,axles=[-2.25,-.75,.75,2.25],swim=True,storage=True)

def apc__btr_80_typhoon_mrap(lod=0):
    return carrier('apc__btr_80_typhoon_mrap','BTR-80 / Typhoon MRAP',lod,7.65,2.90,1.93,'btr','kpvt',4,.54,z=.32,
        features=['BTR-80 selected','8x8 enlarged hull','KPVT turret','split side entry doors between middle wheels','rear waterjet'],representative='BTR-80',approx=True,swim=True,side_door=True,ports=3)

def apc__btr_80a_btr_70(lod=0):
    return carrier('apc__btr_80a_btr_70','BTR-80A / BTR-70',lod,7.65,2.90,1.93,'btr','bppu',4,.54,z=.35,
        features=['BTR-80A selected','8x8 BTR hull','low BPPU mount with long 30 mm gun','split side doors'],representative='BTR-80A',approx=True,swim=True,side_door=True,ports=3)

def apc__btr_82a(lod=0):
    return carrier('apc__btr_82a','BTR-82A',lod,7.65,2.90,1.95,'btr','bppu',4,.54,z=.34,
        features=['8x8 BTR-80-derived hull','stabilized BPPU 30 mm turret','side split doors','turret sight and rear engine compartment'],swim=True,side_door=True,ports=3,storage=True)

def apc__eitan(lod=0):
    return carrier('apc__eitan','Eitan',lod,8.00,3.10,2.48,'eitan','rws',4,.63,source='israel',z=-.12,
        features=['8x8 high mine-protected hull','heavy faceted modular side armour','sloped wedge prow','rear infantry ramp','remote roof weapon'],era=True,bow=.51,shoulder=.87)

def apc__humvee_captured(lod=0):
    return carrier('apc__humvee_captured','Humvee (captured)',lod,4.57,2.16,1.83,'humvee','rws',2,.44,source='https://www.amgeneral.com/what-we-do/platforms-automotive-systems/humvee/',z=-.22,
        features=['4x4 wide low chassis','long flat bonnet','four-door armoured cab','roof weapon station','rear spare tyre'],approx=True,representative='M1114-pattern armoured HMMWV with weapon mount',spare=True)

def apc__k808_apc(lod=0):
    return carrier('apc__k808_apc','K808 APC',lod,7.40,2.70,2.25,'k808','rws',4,.55,source='korean',z=.10,
        features=['8x8','high boat hull and long sloping bow','rear ramp','paired rear waterjets','low weapon station'],swim=True,bow=.48,shoulder=.89)

def apc__lav_700(lod=0):
    return carrier('apc__lav_700','LAV 700',lod,8.20,3.0,2.55,'lav','rws',4,.57,source='https://www.gdls.com/lav/',z=-.20,
        features=['8x8 long high LAV chassis','steep front glacis','long rear troop compartment','APC roof weapon fit selected'],approx=True,representative='LAV 700 APC configuration',storage=True,bow=.52,shoulder=.88)

def apc__m_2010(lod=0):
    return carrier('apc__m_2010','M-2010',lod,7.35,2.75,1.92,'btr','twin_kpv',3,.52,source='https://odin.tradoc.army.mil/WEG',z=.22,
        features=['M-2010 6x6 configuration selected','three widely spaced axles','BTR-derived wedge hull','twin 14.5 mm turret'],approx=True,representative='M-2010 6x6',axles=[-2.15,0,2.15],swim=True)

def apc__m113_fahd(lod=0):
    return carrier('apc__m113_fahd','M113 / Fahd',lod,6.0,2.45,2.13,'fahd','rws',2,.51,source='https://www.aoi.org.eg/',z=-.35,
        features=['Fahd 4x4 selected','high square troop hull','short two-window forward cab','large single tyres','roof weapon mount'],approx=True,representative='Fahd 240 APC',side_door=True,bow=.64,shoulder=.94)

def apc__pars(lod=0):
    return carrier('apc__pars','Pars',lod,8.0,3.0,2.30,'pars','rws',4,.59,source='pars',z=-.24,
        features=['PARS 8x8 selected','low rounded wedge bow','two front windows','close middle axles and rear ramp'],representative='PARS 8x8 APC',axles=[-2.60,-.95,.95,2.60],swim=True,bow=.56,shoulder=.87)

def apc__rakhsh(lod=0):
    return carrier('apc__rakhsh','Rakhsh',lod,6.06,2.40,2.37,'rakhsh','rws',2,.51,source='https://www.diomil.ir/',z=-.25,
        features=['4x4 armoured patrol carrier','short bonnet and steep divided windscreen','tall windowed troop cabin','rear spare tyre'],approx=True,spare=True)

def apc__saad_m113(lod=0):
    return carrier('apc__saad_m113','Saad / M113',lod,5.50,2.69,2.20,'saad','rws',6,.27,.64,True,source='hit',z=.55,
        features=['Saad selected','extended M113-derived hull with six road wheels','vertical slab troop body','rear ramp and external fuel tanks'],representative='Saad',approx=True,m113_fuel=True,bow=.71,shoulder=.98)

def apc__stryker(lod=0):
    return carrier('apc__stryker','Stryker',lod,6.95,2.72,2.22,'stryker','rws',4,.56,source='stryker',z=.22,x=-.20,
        features=['8x8 with central axle spacing gap','faceted low nose and full rear ramp','M151 Protector remote weapon mount','front right engine grille'],axles=[-2.30,-.98,.98,2.30],storage=True,bow=.46,shoulder=.89)

def apc__type_96_apc(lod=0):
    return carrier('apc__type_96_apc','Type 96 APC',lod,6.84,2.48,1.85,'type96','rws',4,.51,source='type96',z=.34,
        features=['Compact narrow 8x8','low roof with front driver periscopes','12.7 mm roof weapon mount','rear troop ramp'],bow=.52,shoulder=.91)

def apc__vbtp_guarani(lod=0):
    return carrier('apc__vbtp_guarani','VBTP Guarani',lod,6.91,2.70,2.34,'guarani','rws',3,.55,source='guarani',z=-.10,
        features=['6x6 with rear tandem axles','high sloped boat hull','divided front windscreen','REMAX weapon fit','paired waterjets'],axles=[-2.13,-.69,2.07],swim=True)

def apc__whap(lod=0):
    return carrier('apc__whap','WhAP',lod,7.90,2.95,2.30,'whap','bmp2',4,.58,source='whap',z=-.20,
        features=['8x8 amphibious WhAP','long angular bow','BMP-2 derived 30 mm turret configuration','large rear ramp and waterjets'],swim=True,bow=.48,shoulder=.86)

def apc__zbl_08(lod=0):
    return carrier('apc__zbl_08','ZBL-08',lod,8.0,3.0,2.10,'zbl','zbl30',4,.57,source='china',z=-.30,
        features=['8x8 angular amphibious hull','two-man 30 mm turret','rear waterjets','raised front engine compartment'],swim=True,storage=True,bow=.56,shoulder=.88)

def ifv__acv_15(lod=0):
    return carrier('ifv__acv_15','ACV-15',lod,5.56,2.90,2.01,'acv','acv',5,.28,.66,True,source='acv',z=-.14,
        features=['Five M113-derived road wheels','slab troop hull with raised rear compartment','single-man 25 mm turret','rear ramp'],m113_fuel=True,bow=.62,shoulder=.96)

def ifv__bmp_2(lod=0):
    return carrier('ifv__bmp_2','BMP-2',lod,6.74,3.15,1.55,'bmp','bmp2',6,.285,.77,True,z=-.20,
        features=['Six small wheels','low sloped BMP hull','two-man 30 mm turret','rear fuel doors','three flank firing ports'],ports=3,rear_doors=True)

def ifv__bmp_2_sarath(lod=0):
    return carrier('ifv__bmp_2_sarath','BMP-2 Sarath',lod,6.74,3.15,1.55,'bmp','bmp2',6,.285,.77,True,source='https://avnl.co.in/',z=-.20,
        features=['Six-wheel Indian BMP-2 Sarath','30 mm two-man turret','low nose and rear fuel doors','Indian vehicle stowage fittings'],ports=3,rear_doors=True,storage=True)

def ifv__bmp_3(lod=0):
    return carrier('ifv__bmp_3','BMP-3',lod,7.14,3.20,1.67,'bmp3','bmp3',6,.30,.80,True,z=.10,
        features=['Six wheels and rear engine','wide shallow hull','coaxial 100 mm and 30 mm barrels','two bow machine guns','rear waterjets'],swim=True,bow_guns=True,front_engine=False)

def ifv__k21_ifv(lod=0):
    return carrier('ifv__k21_ifv','K21 IFV',lod,6.90,3.40,1.94,'k21','k21',6,.32,.81,True,source='k21',z=-.10,
        features=['Six road wheels','40 mm two-man turret','sloped front hull','large side flotation covers','rear ramp'],skirts=True,bow=.53,shoulder=.91)

def ifv__m2a2_bradley(lod=0):
    return carrier('ifv__m2a2_bradley','M2A2 Bradley',lod,6.55,3.60,2.07,'bradley','bradley',6,.33,.77,True,source='bradley',z=-.12,
        features=['Six road wheels','tall faceted hull','25 mm turret and left twin-TOW box','side applique armour','rear ramp'],era=True,bow=.53,shoulder=.91)

def ifv__m2a4_bradley(lod=0):
    return carrier('ifv__m2a4_bradley','M2A4 Bradley',lod,6.55,3.60,2.10,'bradley','bradley',6,.34,.78,True,source='bradley',z=-.12,
        features=['Six-wheel upgraded Bradley suspension','25 mm turret and twin-TOW side launcher','broad side armour','roof equipment and rear stowage'],era=True,storage=True,bow=.53,shoulder=.91)

def ifv__pandur_ii_ifv(lod=0):
    return carrier('ifv__pandur_ii_ifv','Pandur II IFV',lod,7.54,2.67,2.08,'pandur','ut30',4,.54,source='https://pindad.com/komandan-pmpp-tni-hadiri-penutupan-pelatihan-pengoperasian-ranpur-pandur-8x8',z=-.20,
        features=['8x8 compact narrow hull','30 mm turret configuration','sloped bow and rear ramp','paired waterjets'],approx=True,representative='Pandur II 8x8 30 mm IFV',swim=True,bow=.52,shoulder=.90)

def ifv__puma_ifv(lod=0):
    return carrier('ifv__puma_ifv','Puma IFV',lod,7.33,3.43,2.16,'puma','puma',6,.31,.82,True,source='puma',z=-.34,x=.18,
        features=['Six small road wheels','thick modular flank armour','offset unmanned 30 mm turret','left missile pod','high protected troop roof'],era=True,bow=.48,shoulder=.91)

def ifv__type_89_ifv(lod=0):
    return carrier('ifv__type_89_ifv','Type 89 IFV',lod,6.80,3.20,2.05,'type89','type89',6,.31,.80,True,source='japan',z=-.15,
        features=['Six road wheels','35 mm two-man turret','bilateral Type 79 missile launchers','flank firing ports','rear doors'],ports=3,rear_doors=True,bow=.58,shoulder=.91)

def ifv__warrior(lod=0):
    return carrier('ifv__warrior','Warrior',lod,6.34,3.03,1.94,'warrior','warrior',6,.31,.75,True,source='warrior',z=-.12,
        features=['Six wheels','boxy troop hull','compact two-man turret with 30 mm RARDEN','ribbed side armour','rear door'],strakes=True,bow=.57,shoulder=.94)

def ifv__zbd_04a(lod=0):
    return carrier('ifv__zbd_04a','ZBD-04A',lod,7.20,3.20,1.94,'zbd','zbd',6,.31,.82,True,source='china',z=-.27,
        features=['Six road wheels','high angular hull and rear ramp','twin 100/30 mm gun turret','thick flank armour modules'],era=True,front_engine=True,bow=.51,shoulder=.90)

def heavyAPC__namer(lod=0):
    return carrier('heavyAPC__namer','Namer',lod,7.50,3.80,2.15,'namer','rws',6,.37,.92,True,source='israel',z=.24,x=-.35,
        features=['Six large Merkava-derived wheels','front engine and front sprockets','very heavy faceted hull','rear infantry ramp','low remote weapon station'],era=True,bow=.47,shoulder=.90)

def bushmaster__bushmaster(lod=0):
    return carrier('bushmaster__bushmaster','Bushmaster',lod,7.18,2.48,2.65,'bushmaster','rws',2,.60,source='bushmaster',z=.20,
        features=['4x4 mine-protected chassis','short bonnet and tall windowed passenger cabin','roof weapon station','large rear spare tyre'],spare=True,axles=[-2.15,2.15])

def reconVehicle__fennek(lod=0):
    return carrier('reconVehicle__fennek','Fennek',lod,5.58,2.55,1.79,'fennek','rws',2,.50,source='fennek',z=-.20,x=.42,
        features=['Low 4x4 wedge reconnaissance hull','three-window driving compartment','retractable observation sensor mast','compact roof weapon station'],axles=[-1.78,1.78])

def reconVehicle__hawkei(lod=0):
    return carrier('reconVehicle__hawkei','Hawkei',lod,5.78,2.40,2.30,'hawkei','rws',2,.52,source='hawkei',z=-.20,
        features=['4x4 four-door protected patrol vehicle','pronounced short bonnet','sloped windscreen and rear equipment bay','roof remote weapon'],spare=True,axles=[-1.80,1.80])

def reconVehicle__jackal(lod=0):
    return carrier('reconVehicle__jackal','Jackal',lod,5.39,2.0,2.18,'jackal','ring',2,.50,source='jackal',z=-.32,
        features=['Open 4x4 patrol platform','exposed roll cage and visible seats','front bonnet','central traverse weapon ring'],axles=[-1.72,1.72])

def reconVehicle__komodo_scout(lod=0):
    return carrier('reconVehicle__komodo_scout','Komodo Scout',lod,5.65,2.25,2.18,'komodo','rws',2,.49,source='pindad',z=-.19,
        features=['4x4 armoured scout','compact bonnet','sloped four-door cab','rear spare wheel'],spare=True,axles=[-1.69,1.69])

def reconVehicle__m3_bradley_scout(lod=0):
    return carrier('reconVehicle__m3_bradley_scout','M3 Bradley Scout',lod,6.55,3.60,2.07,'bradley','bradley',6,.33,.77,True,source='bradley',z=-.12,
        features=['Six-wheel cavalry Bradley','25 mm turret and twin TOW launcher','large side armour and reconnaissance stowage','rear ramp'],era=True,storage=True,bow=.53,shoulder=.91)


def arv(slug,name,lod,L,W,H,wheels,k,equipment,source,features,**kw):
    return carrier(slug,name,lod,L,W,H,'recovery','',wheels,.35,k,True,source=source,
                   features=features,equipment=equipment,storage=True,bow=.52,shoulder=.91,**kw)

def recoveryVehicle__armoured_recovery_vehicle(lod=0):
    return arv('recoveryVehicle__armoured_recovery_vehicle','Armoured Recovery Vehicle',lod,8.27,3.43,2.35,6,.94,'aframe','m88',
        ['M88-family representative for unspecified ARV','six wheels','raised forward recovery cabin','A-frame boom and front spade','rear winch deck'],approx=True,representative='M88-family ARV')

def recoveryVehicle__bergepanzer_3_buffel(lod=0):
    return arv('recoveryVehicle__bergepanzer_3_buffel','Bergepanzer 3 Buffel',lod,8.13,3.54,2.20,7,.99,'slew','puma',
        ['Seven-wheel Leopard 2 chassis','front dozer spade','front-right slewing crane','low asymmetric recovery cabin','rear work deck with spare wheels'],spare_roadwheels=2)

def recoveryVehicle__brem_1(lod=0):
    return arv('recoveryVehicle__brem_1','BREM-1',lod,6.98,3.46,1.68,6,.87,'slew','soviet',
        ['Six T-72 road wheels','very low turretless hull','folded port-side crane','front anchor spade','rear cargo platform'],crane_side=-1)

def recoveryVehicle__challenger_arrv(lod=0):
    return arv('recoveryVehicle__challenger_arrv','Challenger ARRV',lod,8.30,3.62,2.35,6,1.02,'slew','trojan',
        ['Six Challenger road wheels','large slab recovery superstructure','starboard hydraulic crane','broad front spade','rear spare powerpack'],powerpack=True)

def recoveryVehicle__k1_arv(lod=0):
    return arv('recoveryVehicle__k1_arv','K1 ARV',lod,7.48,3.60,2.18,6,.95,'slew','korean',
        ['Six K1 chassis wheels','front dozer spade','folding slewing crane','recovery superstructure with spare powerpack'],powerpack=True)

def recoveryVehicle__m88a2_hercules(lod=0):
    return arv('recoveryVehicle__m88a2_hercules','M88A2 Hercules',lod,8.27,3.66,2.40,6,.96,'aframe','m88',
        ['Six large road wheels','high forward armoured cabin','twin-leg A-frame boom','large front spade','heavy rear winch and spare road wheel'],spare_roadwheels=1)

def recoveryVehicle__type_90_arv(lod=0):
    return arv('recoveryVehicle__type_90_arv','Type 90 ARV',lod,7.95,3.40,2.20,6,.97,'slew','japan',
        ['Six Type 90 chassis wheels','folded deck crane','large forward blade','rectangular turretless superstructure','rear work platform'])

def recoveryVehicle__wzt_3(lod=0):
    return arv('recoveryVehicle__wzt_3','WZT-3',lod,7.10,3.46,1.85,6,.88,'slew','https://bumar.gliwice.pl/',
        ['Six T-72-derived road wheels','low armoured recovery cab','rear cargo platform','folded port-side crane and front anchor spade'],crane_side=-1)

def mineClearer__keiler(lod=0):
    return carrier('mineClearer__keiler','Keiler',lod,8.0,3.50,1.92,'engineering','',6,.38,.96,True,source='puma',
        features=['M48-derived six-wheel chassis','large forward flail rotor with real chains','hinged carrier arms','turretless rear work deck'],equipment='flail',front_engine=False)

def mineClearer__m1150_assault_breacher(lod=0):
    return carrier('mineClearer__m1150_assault_breacher','M1150 Assault Breacher',lod,7.92,3.66,1.50,'engineering','rws',7,.33,1.,True,source='https://www.army.mil/article/127291',z=.50,
        features=['Seven-wheel Abrams chassis','wide front mine plough','armoured crew cupola','two rear line-charge launch boxes','remote defensive weapon'],equipment='breacher',front_engine=False,skirts=True,weapon_base=2.30)

def mineClearer__mine_clearing_vehicle(lod=0):
    return carrier('mineClearer__mine_clearing_vehicle','Mine-clearing Vehicle',lod,6.95,3.46,1.76,'engineering','',6,.36,.87,True,source='soviet',
        features=['T-72 engineering representative','six road wheels','turretless engineering hull','front mine-clearing blade'],equipment='generic_clear',approx=True,representative='T-72-based engineering carrier',front_engine=False)

def mineClearer__trojan_avre(lod=0):
    return carrier('mineClearer__trojan_avre','Trojan AVRE',lod,8.30,3.50,2.08,'engineering','',6,.36,1.02,True,source='trojan',
        features=['Six Challenger wheels','front mine plough','articulated excavator arm','tall turretless engineer cabin'],equipment='trojan',front_engine=False)

def mineClearer__ur_77_meteorit(lod=0):
    return carrier('mineClearer__ur_77_meteorit','UR-77 Meteorit',lod,7.26,2.85,1.50,'engineering','',7,.29,.82,True,source='soviet',
        features=['Seven 2S1-derived road wheels','long low hull','twin line-charge rocket tubes in large roof launcher housing'],equipment='ur77',front_engine=True)

def mineLayer__engineer_minelayer(lod=0):
    return carrier('mineLayer__engineer_minelayer','Engineer Minelayer',lod,5.90,2.65,2.02,'m113','',5,.28,.68,True,source='volcano',
        features=['M548-pattern tracked dispenser representative','five wheels','forward crew cab and rear mine racks'],equipment='engineer_layer',approx=True,representative='M548-pattern tracked minelayer',bow=.72,shoulder=.98)

def mineLayer__gmz_3(lod=0):
    return carrier('mineLayer__gmz_3','GMZ-3',lod,9.30,3.25,2.02,'engineering','',7,.35,1.09,True,source='soviet',
        features=['Seven widely spaced road wheels','long low mine-carrying hull','forward driving compartment','twin hinged rear mine-laying chutes'],equipment='gmz',bow=.72,shoulder=.93)

def mineLayer__isdm_zemledelie(lod=0):
    return carrier('mineLayer__isdm_zemledelie','ISDM Zemledelie',lod,10.0,2.55,2.95,'truck','',4,.61,source='https://rostec.ru/',
        features=['KamAZ-6560 8x8 truck chassis','cab-over forward-control cabin','two rectangular 25-tube mine rocket pods','hinged launcher cradle'],equipment='zemledelie',axles=[-3.15,-1.60,1.65,3.15],cab=2.30)

def mineLayer__m139_volcano(lod=0):
    return carrier('mineLayer__m139_volcano','M139 Volcano',lod,8.70,2.50,2.72,'truck','',3,.57,source='volcano',
        features=['M939-series 6x6 truck carrier selected','bonneted truck cab','four mine-dispenser racks on cargo bed','isolated front axle and rear tandem'],equipment='volcano',representative='M139 Volcano on M939-series 5-ton 6x6',axles=[-2.78,-1.28,2.85],cab=1.90,hood=1.50)

def mineLayer__skorpion_mine_dispenser(lod=0):
    return carrier('mineLayer__skorpion_mine_dispenser','Skorpion Mine Dispenser',lod,5.75,2.65,1.83,'m113','',5,.28,.67,True,source='https://www.bundeswehr.de/',
        features=['M548-derived five-wheel chassis','forward low cab','six angled dispenser banks arranged in two rows','open rear equipment platform'],equipment='skorpion',bow=.72,shoulder=.98)

def ewVehicle__elbit_ew_truck(lod=0):
    return carrier('ewVehicle__elbit_ew_truck','Elbit EW truck',lod,8.10,2.50,2.80,'truck','',3,.57,source='elbit',
        features=['6x6 EW truck representative','bonneted driving cab','rear mission shelter with cooling louvers','raised antenna mast'],equipment='elbit',approx=True,representative='Elbit truck-mounted land EW shelter, representative 6x6 carrier',axles=[-2.58,-1.10,2.50],cab=1.80,hood=1.28)

def ewVehicle__ew_vehicle(lod=0):
    return carrier('ewVehicle__ew_vehicle','EW Vehicle',lod,7.60,2.50,2.70,'truck','',3,.55,source='elbit',
        features=['Generic 6x6 EW shelter vehicle','forward-control cab','rear electronics shelter','vertical antenna mast'],equipment='generic',approx=True,representative='Representative 6x6 truck-mounted EW shelter',axles=[-2.35,-.96,2.35],cab=2.0)

def ewVehicle__koral(lod=0):
    return carrier('ewVehicle__koral','KORAL',lod,11.0,2.90,3.10,'truck','',4,.63,source='koral',
        features=['MAN 8x8 truck carrier','large rear electronic warfare shelter','raised rectangular antenna array','cab-over driving compartment'],equipment='koral',axles=[-3.65,-2.02,1.75,3.40],cab=2.25)

def ewVehicle__krasukha_4(lod=0):
    return carrier('ewVehicle__krasukha_4','Krasukha-4',lod,10.0,2.75,3.0,'truck','',4,.62,source='https://rostec.ru/',
        features=['BAZ-6910 8x8 chassis','long rear electronics shelter','large concave dish reflector and feed arm','forward-control cab'],equipment='krasukha',axles=[-3.27,-1.60,1.68,3.20],cab=2.20)

def ewVehicle__type_2_ew_truck(lod=0):
    return carrier('ewVehicle__type_2_ew_truck','Type 2 EW truck',lod,8.20,2.50,2.85,'truck','',3,.57,source='china',
        features=['Chinese 6x6 EW truck representative','bonneted cab','rear communications shelter','mast with cylindrical sensor and whip aerials'],equipment='type2',approx=True,representative='Type 2 designation: representative Chinese 6x6 EW shelter',axles=[-2.60,-1.12,2.55],cab=1.85,hood=1.35)


BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and callable(f) and n.split('__')[0] in ('tank','apc','ifv','heavyAPC','bushmaster','reconVehicle','recoveryVehicle','mineClearer','mineLayer','ewVehicle')}
_names=list(BUILDERS)
BATCHES={i+1:_names[i*6:(i+1)*6] for i in range(10)}
BATCHES[11]=_names[60:65];BATCHES[12]=_names[65:70]
assert len(BUILDERS)==70 and all(len(v) in (5,6) for v in BATCHES.values())


def main():
    from validate_p2_armour import validate
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--batch',type=int,choices=BATCHES,default=1)
    p.add_argument('--types',nargs='+',choices=BUILDERS);p.add_argument('--validate-only',action='store_true');p.add_argument('--report',type=Path)
    a=p.parse_args();entries=[]
    for slug in a.types or BATCHES[a.batch]:
        path=ART/'vehicles'/f'{slug}.glb'
        if not a.validate_only:
            r0,s=BUILDERS[slug](0);r1,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
            is_tank=slug.startswith('tank__');spec=asdict(s)
            if is_tank:spec.update(mobility='tracked',weapon='tank',family='leclerc',equipment='',axle_z=[])
            c=Mesh();height=s.deck if is_tank else s.roof;c.box('metal_dark',(0,height/2,0),(s.width,height,s.length))
            w=make_wreck(r1,s) if is_tank else wreck(r1,s)
            write_glb(path,[r0,r1],w,c,{'scene_name':s.name,'vehicle':slug,'priority':'P1' if is_tank else 'P2',
                'units':'metres','up':'+Y','front':'+Z','spec':spec,'detached_turret':bool(spec['weapon']),
                'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}})
        entry,tree=validate(path);entries.append(entry)
        out=Path(__file__).parent/'reports'/f'{slug}.node-tree.txt';out.parent.mkdir(exist_ok=True);out.write_text(tree,encoding='utf-8')
        print(tree);print('PASS',path.name,entry['triangles'],flush=True)
    if not a.validate_only:
        manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
        manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    if a.report:a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
    print('RELOADED',len(entries),'vehicles')


if __name__=='__main__':main()
