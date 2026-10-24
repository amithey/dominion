"""Evidence-led batch05: distinct German and Indonesian exterior models.

Original metre meshes and public exterior estimates; no source mesh imports.
The A8 is ordered/testing, not a declaration of current fleet readiness.
"""
from pathlib import Path
import argparse,json
import numpy as np
import generate_expansion_armour as tanks
import generate_inventory_additions as common
import generate_p5_helicopters as helis
from generate_p1_tanks import Spec,finish,basket
from generate_p7_ships import combatant
from vehicle_parts import Mesh,loft,profile_hull,rotation

BW='https://www.bundeswehr.de/de/'

def tank__leopard_2a8(lod=0):
    s=Spec('leopard_2a8','Leopard 2A8',7.72,3.98,1.48,2.64,7,.34,.99,.05,2.03,1.42,10.97,'leopard',
        ['seven road wheels','120mm L55A1','deep angular modular turret cheeks','four Trophy radar panels','two Trophy effector units with blast shields','reinforced hull bow','roof panoramic sight','ordered series fleet, current demonstration/testing stage'],
        BW+'beschaffung/leopard2-a8-kampfpanzer-6040490',approximate=True,
        representative='Public November2025 German rollout exterior; unpublished armour-module dimensions estimated. Dutch-specific communications/roof fittings not asserted.')
    b=[(-.44,1.87),(.44,1.87),(1.72,1.18),(1.70,-1.66),(1.35,-2.08),(-1.35,-2.08),(-1.70,-1.66),(-1.72,1.18)]
    t=[(-.43,1.26),(.43,1.26),(1.59,.84),(1.48,-1.65),(1.28,-2.03),(-1.28,-2.03),(-1.48,-1.65),(-1.59,.84)]
    def detail(h,m,s,l):
        for side in (-1,1):
            loft(m,'paint',[[[side*x,y,z] for x,y,z in ring] for ring in [
                [(.46,1.85,1.88),(1.73,1.85,1.18),(1.67,1.85,-.48),(.49,1.85,.60)],
                [(.46,2.47,1.29),(1.60,2.47,.88),(1.54,2.47,-.48),(.49,2.47,.55)]]])
            # Real fore/aft radar faces per side, with effector and safety shield aft.
            for z in (.53,-1.58):
                m.box('paint',(side*1.70,2.40,z),(.21,.40,.45))
                m.box('metal_dark',(side*1.81,2.40,z),(.018,.27,.31))
            m.box('paint',(side*1.66,2.56,-1.02),(.42,.12,.57))
            m.box('paint',(side*1.40,2.72,-1.35),(.10,.54,.91))
            if not l:
                m.tube('metal_dark',(side*1.67,2.61,-1.02),(side*1.67,2.73,-1.02),.14,12)
                for z in (-1.47,-1.17,-.87):m.box('paint',(side*1.72,2.75,z),(.06,.04,.09))
        m.box('paint',(.83,2.56,.65),(.55,.28,.58));m.box('glass',(.83,2.58,.953),(.35,.16,.02))
        m.box('paint',(-.57,2.74,-.92),(.52,.31,.52));m.box('glass',(-.57,2.74,-.65),(.33,.18,.02))
        h.box('paint',(0,1.30,3.55),(3.44,.28,.47),rotation([1,0,0],-.25))
        basket(m,s,l,z=-2.10,width=2.9)
    return finish(s,b,t,lod,detail)

def tank__leopard_2ri(lod=0):
    s=Spec('leopard_2ri','Leopard 2RI',7.72,3.94,1.48,2.53,7,.34,.99,.05,2.00,1.40,9.97,'leopard',
        ['seven road wheels','120mm L44 short gun','Indonesian modular slab and bevelled turret armour','deep bow applique block','large segmented side protection','rear bustle cooling installation','no invented Trophy launchers or L55 gun'],
        'https://dislitbang-tniad.mil.id/images/pages/Final_Jurnal_Litbang_2018_Oke.pdf',approximate=True,
        representative='Indonesian Leopard2RI exterior; recognition armour follows September2026 public display photograph; exact private module thickness estimated.')
    b=[(-.43,1.43),(.43,1.43),(1.73,1.20),(1.73,-1.57),(1.25,-2.05),(-1.25,-2.05),(-1.73,-1.57),(-1.73,1.20)]
    t=[(-.43,1.22),(.43,1.22),(1.57,1.08),(1.58,-1.60),(1.16,-1.97),(-1.16,-1.97),(-1.58,-1.60),(-1.57,1.08)]
    def detail(h,m,s,l):
        for side in (-1,1):
            loft(m,'paint',[[[side*x,y,z] for x,y,z in ring] for ring in [
                [(.46,1.78,1.45),(1.77,1.78,1.26),(1.77,1.78,-1.18),(.50,1.78,.76)],
                [(.46,2.44,1.24),(1.58,2.44,1.08),(1.60,2.44,-1.18),(.50,2.44,.65)]]])
            for z in np.linspace(-2.60,2.60,5 if not l else 3):
                h.box('paint',(side*1.87,1.11,z),(.17,.67,1.00 if not l else 1.70))
            m.box('paint',(side*1.57,2.15,-1.53),(.26,.56,.57))
        h.box('paint',(0,1.23,3.30),(3.62,.28,.90),rotation([1,0,0],-.27))
        m.box('paint',(.83,2.49,.85),(.56,.27,.53));m.box('glass',(.83,2.49,1.125),(.37,.15,.02))
        m.box('paint',(.60,2.12,-2.06),(1.42,.60,.45))
        for x in np.linspace(.03,1.18,4 if l else 9):m.box('metal_dark',(x,2.16,-2.292),(.035,.34,.018))
        basket(m,s,l,z=-2.08,width=2.9)
    return finish(s,b,t,lod,detail)

def navalHelicopter__nh90_sea_tiger(lod=0):
    rig,s=helis.model('navalHelicopter__nh90_sea_tiger','NH90 MRFH Sea Tiger',lod,'nh90',
        'German delivered ASW variant, representative MU90 load; exact sensor/defensive-suite housings estimated',
        naval=True,approximate=True,source=BW+'ausruestung-technik-bundeswehr/luftsysteme-bundeswehr/bordhubschrauber-nh-90-sea-tiger',
        details={'naval_store':'torpedo','chin_sensor':True})
    s.features+=['four-blade16.3m main rotor','two MU90 external stations','belly ENR radar','German EO/ESM fittings','dipping-sonar housing','starboard rescue hoist','distinct from unarmed SeaLion transport']
    m=Mesh();m.tube('paint',(0,.88,-1.20),(0,1.22,-1.20),.31,8 if lod else 20)
    m.box('metal_dark',(0,.86,-1.20),(.36,.03,.36))
    for side in (-1,1):
        m.box('paint',(side*1.22,2.75,3.25),(.28,.32,.44))
        m.box('metal_dark',(side*1.37,2.75,3.25),(.02,.21,.28))
        m.box('paint',(side*1.18,1.50,-1.18),(.27,.22,.46))
    rig.add('ASW_and_ESM_Fittings','Fuselage',(0,1.04,-1.20),m)
    s.details['inventory_status']='delivered_introduction';return rig,s

def heavyLift__ch_53ga(lod=0):
    rig,s=helis.model('heavyLift__ch_53ga','CH-53GA',lod,'merlin',
        'GermanAdvanced two-engine six-blade CH53; public exterior estimates. Internal fuel arrangement, no GS long external tanks or CH53K third engine.',
        length=20.47,width=2.69,body_height=3.40,belly=1.00,hub_y=5.72,hub_z=3.90,
        rotor_diameter=22.,blades=6,tail_diameter=4.88,tail_blades=4,engines=2,approximate=True,
        source=BW+'ausruestung-technik-bundeswehr/luftsysteme-bundeswehr/sikorsky-ch-53',
        features=['single six-blade22m main rotor','two T64 engine nacelles','four-blade tail rotor','wide bulky transport cabin','short projecting undercarriage sponsons','rear hinged cargo ramp','tricycle wheels','GA internal tank and chin EO'],
        details={'tail_y':5.08,'boom_y':3.40,'boom_start':-.16,'main_gear_z':-.12,'gear_spread':.72,'wheel_radius':.43,
            'chin_sensor':True,'main_blade_chord':.65,'window_z':(-.12,.0,.12,.23),
            'profile':[(-.20,-.02,.31,.40),(-.15,0,.46,.49),(.02,0,.50,.50),(.27,0,.50,.50),(.39,-.03,.45,.45),(.47,-.13,.29,.32),(.50,-.18,.08,.14)]})
    # Public CH53GA has small wheel sponsons, not Merlin's long pontoons.
    rig.parts=[p for p in rig.parts if not p['name'].startswith('Sponson')]
    # The CH53 gearbox has a raised, connected dorsal fairing. Its two
    # nacelles sit alongside the forward transmission, unlike the AW101.
    for part in rig.parts:
        if part['name'].startswith(('Engine_','Exhaust_')):
            delta=np.array([0,0,2.20]);part['pivot']+=delta
            if part['mesh'] is not None:part['mesh'].shift(delta)
            rig.pivots[part['name']]=part['pivot']
    m=Mesh();profile_hull(m,'paint',[(5.55,4.12,.66),(4.90,5.10,.59),(1.30,5.10,.55),(.25,4.10,.64)])
    m.tube('paint',(0,4.95,3.90),(0,5.57,3.90),.36,8 if lod else 20,r_top=.23)
    rig.add('Transmission_Fairing','Fuselage',(0,4.12,3.90),m)
    m=Mesh()
    for side in (-1,1):
        m.tube('paint',(side*1.56,1.66,-4.38),(side*1.56,1.66,-.54),.41,6 if lod else 14,r_top=.32)
        m.box('paint',(side*1.37,1.76,-2.46),(.47,.42,3.15))
    rig.add('Undercarriage_Sponsons','Fuselage',(0,1.66,-2.46),m)
    p=np.array([0,1.30,-3.79]);m=Mesh()
    m.box('paint',p+[0,.65,-.13],(2.18,1.36,.16),rotation([1,0,0],-.24))
    rig.add('Ramp','Fuselage',p,m,'X')
    m=Mesh();m.tube('paint',(0,4.36,1.65),(0,4.64,1.65),.35,8 if lod else 20)
    rig.add('SATCOM','Fuselage',(0,4.36,1.65),m)
    s.details['inventory_status']='in_service';return rig,s

def asFrigate__f123_brandenburg_class(lod=0):
    rig,s=combatant('asFrigate__f123_brandenburg_class','F123 Brandenburg-class',lod,(139.,16.7,6.3,4.9),
        BW+'ausruestung-technik-bundeswehr/seesysteme-bundeswehr/brandenburg-klasse-f123-fregatte',
        ['139m ASW frigate','forward76mm gun','16foredeck Mk41cells','SMART-S forward and LW08 aft search arrays','two separated funnels','twin helicopter hangar doors','two21-cellRAM launchers','two quadruple Harpoon groups','two27mm MLG mounts','bow sonar housing'],
        houses=[(0,13,12.9,32,6.8,0,.87),(0,-28,13.1,26,5.5,0,.92),(0,17,9.1,14,3.9,6.8,.90)],
        funnels=[(0,-1,4.3,6,7.9,2.8),(0,-15,4.3,5.8,7.5,2.8)],
        masts=[(15,23.5,'panel',4.6),(-20,24.5,'bar',7.8)],
        guns=[(0,49,76,4.0),(-6.4,3,27,1.8),(6.4,3,27,1.8)],
        vls=[(35,4,4,.77,0)],canisters=[(-6,3,4)],ciws=[(0,27,5.0),(0,-31,5.8)],ciws_style='ram',
        hangar_z=-41.1,hangar_doors=2)
    s.representative='Public pre-modernisation search-radar exterior and current equipment-page weapons. Fleet-wide completion of radar/NSM modernization not asserted; historical Exocet photo not copied as current.'
    m=Mesh();m.tube('paint',(0,2.90,54.),(0,2.90,61.4),1.05,8 if lod else 20,r_top=.42)
    rig.add('Bow_Sonar','Hull',(0,2.90,57.7),m)
    # Two STIR fire-control radars are separately steerable from the search masts.
    for i,(z,y) in enumerate(((22.,17.6),(-29.,15.6))):
        m=Mesh();p=np.array([0,y,z]);m.tube('paint',p,p+[0,.75,0],.38,6 if lod else 12)
        m.tube('paint',p+[0,.85,-.18],p+[0,.85,.16],.70,8 if lod else 20)
        rig.add('Radar_FireControl_'+str(i),'Hull',p,m,'Y')
    s.details['inventory_status']='in_service';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('tank__','navalHelicopter__','heavyLift__','asFrigate__')) and callable(f)}

def save(slug):
    if slug.startswith('tank__'):
        tanks.BUILDERS[slug]=BUILDERS[slug];entry=tanks.save(slug)
    elif slug.startswith(('heavyLift__','navalHelicopter__')):
        helis.BUILDERS[slug]=BUILDERS[slug];entry=helis.save(slug)
    else:
        common.BUILDERS[slug]=BUILDERS[slug]
        # General saver dispatch is explicit here; no mutation of old builders.
        from dataclasses import asdict
        from vehicle_parts import write_glb
        from ship_parts import wreck
        from validate_ships import validate
        a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
        c=Mesh();c.box('metal_dark',(0,(s.draft+s.freeboard)/2,0),(s.beam,s.draft+s.freeboard,s.length))
        path=common.ART/'ships'/(slug+'.glb')
        write_glb(path,[a,b],wreck(b),c,{'scene_name':s.name,'vehicle':slug,'priority':'P7','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
        entry,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree)
    entry['notes']+=' Evidence-led original generator: generate_inventory_additions_05.py; national status/evidence in research/evidence.json.'
    return entry

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
