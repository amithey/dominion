"""Original Israeli inventory exteriors, current platforms and a confirmed order.

No Blender, imported meshes, photographic pixels, operational systems or weapon
internals. Principal public sizes; locally estimated minor outer fittings.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p6_aircraft as planes
import generate_p5_helicopters as helis
from aircraft_parts import build,curved_shell,burnt_wreck
from helicopter_parts import burnt_wreck as heli_wreck
from vehicle_parts import Mesh,merge_mesh,profile_hull,hollow_muzzle,write_glb
from generate_p1_tanks import beam
from generate_inventory_additions_12 import remove
from generate_inventory_additions_23 import stations

IAI='https://www.iai.co.il/press/iai-awarded-israel-defence-prize-for-the-development-and-production-of-the-shavit-eitam-and-oron-special-mission-aircraft/'
ELBIT='https://www.elbitsystems.com/autonomous/aerial/tactical-uas/hermes-450'
PEREH='https://mod.gov.il/en/press-releases/press-room/israel-ministry-of-defense-signs-approx-130-million-deal-with-elbit-systems-to-integrate-israeli-systems-on-ch-53k-helicopters'


def baz(slug,name,lod,seats):
    _,s=planes.model(slug,name,lod,'f15',seats,False)
    s.source='https://www.idf.il/en/mini-sites/israeli-air-force/opening-of-the-blue-flag-2021-exercise-the-largest-and-most-advanced-held-in-israel/'
    s.details.update(stations=[],canopy_front=.385,canopy_rear=.15 if seats==2 else .23,
        gear_layout=[{'name':'Gear_Nose','x':0,'z':5.25,'radius':.29,'pairs':1},
          {'name':'Gear_Left','x':-1.32,'z':-1.46,'radius':.47,'pairs':1},
          {'name':'Gear_Right','x':1.32,'z':-1.46,'radius':.47,'pairs':1}])
    r,s=build(s,lod);cy=s.belly+s.body_height/2
    # Both selected photographer references show the bulged FASTpack sides.
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();curved_shell(m,'paint',[(-6.6,cy-.28,.08,.17),(-5.4,cy-.28,.43,.55),
            (.0,cy-.25,.43,.55),(2.45,cy-.22,.08,.20)],lod,circumference=8 if lod else 24,longitudinal=2 if lod else 4,cross_power=.8)
        m.shift((side*1.65,0,0));r.add('Conformal_Tank_'+label,'Fuselage',(side*1.65,cy-.25,-2),m)
    if seats==2:
        m=Mesh();curved_shell(m,'paint',[(1.05,2.91,.08,.06),(1.48,2.96,.28,.28),(2.06,2.99,.29,.31),(2.46,2.91,.10,.08)],lod,circumference=8 if lod else 24,longitudinal=2)
        r.add('Dorsal_Satcom_Cover','Fuselage',(0,2.91,1.7),m)
    # Exposed-looking closed cosmetic nozzle ribs, rather than GE/F16 petal skins.
    for i in range(2):
        p=next(p for p in r.parts if p['name']=='Engine_'+str(i));p['mesh'].groups.pop('metal_dark',None)
        x=(i-.5)*s.details['engine_spacing'];rad=s.details['engine_radius'];m=p['mesh']
        hollow_muzzle(m,(x,cy,-s.length*.46),(x,cy,-s.length*.50),rad,rad*.82,8 if lod else 32)
        for a in np.linspace(0,math.tau,8 if lod else 15,endpoint=False):
            v=np.array([math.cos(a),math.sin(a),0]);p0=np.array([x,cy,-s.length*.465])+v*(rad+.045);p1=np.array([x,cy,-s.length*.496])+v*(rad+.012)
            beam(m,'metal_dark',p0,p1,.025 if lod else .033)
    stations(r,s,lod,(.48,),cft=True)
    s.features=['Israeli Baz air-superiority F15family, not F15I/IA','single-seat short canopy' if seats==1 else 'tandem canopy and selected dorsal SATCOM outer cover',
        'selected C/Dphotographs have FASTpack conformal tanks','twin rectangular inlets/twin fins, F100-family decorative exposed outer nozzle ribs',
        'three single-tyre gear groups and empty external racks']
    s.representative='Original selected Israeli '+('F15Csingle-seat/CFT' if seats==1 else 'F15Dtandem/CFT')+' exterior from firsthand2019photographs, current Bazfamily separately confirmed by2025operator. Optional mission fit is not universal; exact current serial, A/B/C/Dupgrade extent, nozzle and local gear/rack dimensions not certified. No copied insignia, live weapons or avionics.'
    s.details.update(inventory_status='current_Baz_family_selected_C_or_D_exterior_exact_serial_fit_unverified',engine_family='F100_family_outer_geometry_estimated')
    return r,s


def jet__f_15c_baz(lod=0):return baz('jet__f_15c_baz','F15C Baz selected Israeli exterior',lod,1)

def jet__f_15d_baz(lod=0):return baz('jet__f_15d_baz','F15D Baz selected Israeli CFT exterior',lod,2)


def mission_gulfstream(slug,name,lod,oron):
    _,s=planes.g550(slug,name,lod);s.source=IAI;s.family='g550_oron' if oron else 'legacy_g500_shavit'
    s.details['conformal_radar']=False
    if oron:
        s.details['profile'][-3:]=[(.40,-.07,.36,.36),(.46,-.10,.25,.25),(.50,-.12,.045,.075)]
    r,s=build(s,lod)
    # Fixed public exterior covers; neither aircraft carries a rotating radome.
    if oron:
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();curved_shell(m,'paint',[(2.25,2.65,.08,.15),(3.1,2.65,.57,.82),
                (9.35,2.65,.57,.82),(10.4,2.65,.08,.15)],lod,circumference=8 if lod else 24,longitudinal=2 if lod else 4,cross_power=.65)
            m.shift((side*1.10,0,0));r.add('Mission_Array_Cover_'+label,'Fuselage',(side*1.10,2.65,6),m)
        sections=[(-11.3,1.85,.05,.06),(-10.2,1.60,.42,.31),(-6.7,1.57,.44,.34),(-4.8,1.84,.08,.08)]
    else:
        sections=[(1.25,1.85,.06,.07),(2.2,1.60,.48,.34),(9.55,1.60,.48,.34),(10.45,1.89,.07,.08)]
        m=Mesh();curved_shell(m,'paint',[(-12.75,7.43,.10,.05),(-12.2,7.47,.64,.16),(-11.4,7.47,.64,.16),(-10.95,7.43,.10,.05)],lod,circumference=8 if lod else 20,longitudinal=2)
        r.add('Fixed_Tail_Cover','Fuselage',(0,7.45,-11.8),m)
    m=Mesh();curved_shell(m,'paint',sections,lod,circumference=8 if lod else 24,longitudinal=2 if lod else 4,cross_power=.7)
    r.add('Ventral_Mission_Canoe','Fuselage',(0,1.75,6 if not oron else -8),m)
    m=Mesh()
    for z in (-6.4,-3.0,2.6,8.2):m.box('paint',(0,3.72,z),(.10,.28,.42))
    r.add('Selected_Dorsal_Outer_Blades','Fuselage',(0,3.72,0),m)
    s.features=['legacy Gulfstream V/G500family, not the unrelated new G500' if not oron else 'Gulfstream G550fixed-wing platform',
        'two rear turbofans, Ttail, winglets, paired tyres on tricycle gear','fixed SIGINT outer canoe and tail cover' if not oron else 'large fixed side array covers and separate lower aft canoe',
        'no rotating disc, cannon, weapons, passenger-window decals or fictional mission internals']
    s.representative='Israeli '+('G550Oron MultiINT' if oron else 'legacyGV/G500Shavit SIGINT')+' in game aewc category as a role abstraction, not identical to EitamAEW. Current types confirmed by2025IAI; selected public '+('2024official operational-announcement closeup and2021maker planform' if oron else '2007original photographer')+' outer fit, not certified exact current installation. Principal Gulfstream29.4x28.5m, minor outer fairing/antenna dimensions estimated. No claim to classified sensor identities, functions or internal layouts.'
    s.details.update(inventory_status='documented_current_type_selected_historical_public_outer_fit',role_abstraction='aewc_game_category_for_special_mission_aircraft_not_AEW_equivalence')
    return r,s


def aewc__g550_oron(lod=0):return mission_gulfstream('aewc__g550_oron','G550 Oron selected public exterior',lod,True)

def aewc__g500_shavit(lod=0):return mission_gulfstream('aewc__g500_shavit','Legacy G500 Shavit selected public exterior',lod,False)


def drone__hermes_450_zik(lod=0):
    r,s=planes.male('drone__hermes_450_zik','Hermes450 Zik selected Israeli exterior',lod,'hermes450',(6.1,10.5,1.85,.52,.52,.62),ELBIT,
        'Maker identifies IDF450 separately from Hermes900/Watchkeeper. Public Singapore operator6.1m length/10.5mspan; selected maker exterior: narrow cylindrical body, upward Vtail, rear pusher, belly optic and tricycle gear. Local height/fittings estimated, no certified exact Israeli sensor configuration or live load.',
        blades=2,stations=(),prop_radius=.43,nose_hump=False,prop_chord_scale=.65)
    y=s.belly+s.body_height*.75
    s.details['wing']=[(.21,y,.40,-.42),(2.65,y,.34,-.36),(5.10,y,.20,-.30),(5.25,y-.11,.15,-.28)]
    r,s=build(s,lod)
    s.features=['narrow6.1m cylindrical body/10.5m narrow-chord wing with small drooped tips','outward upward Vtail with real canted control axes','two-blade rear pusher and belly electro-optical outer housing','three wheels, empty/unarmed selected exterior, no Hermes900large satellite hump']
    s.details['inventory_status']='maker_identified_IDF_type_operator_identity_corroborated_exact_national_fit_unverified'
    return r,s


def heavyLift__ch_53k_pereh(lod=0):
    r,s=helis.model('heavyLift__ch_53k_pereh','CH53K Pereh ordered public exterior',lod,'merlin',
        'Twelve contracted Israeli CH53K, expected first arrival2028, not delivered/operational. Original maker2024outline/photos and Israeli public concept:22.5m body,24.1m main/6.1m tail rotors, seven main/four tail blades, three engines, broad integrated sponsons. Local dimensions/final national sensor installation estimated/unverified.',
        length=22.5,width=3.,body_height=3.6,belly=1.,hub_y=6.20,hub_z=4.70,rotor_diameter=24.1,blades=7,tail_diameter=6.1,tail_blades=4,tail_cant=20,engines=3,source=PEREH,approximate=True,
        features=['three engines: two forward side nacelles and third raised port/aft nacelle','seven swept-tip main blades, four-blade canted tail rotor','broad integrated rounded-box sponsons, unlike Yasur round external tanks','three twin-tyre groups, rear ramp and long exterior refuelling probe','confirmed order, final Israeli EW/sensor installation not invented'],
        details={'tail_y':5.65,'boom_y':3.50,'boom_start':-.16,'main_gear_z':1.7/22.5,'gear_spread':1.95/3,'wheel_radius':.43,'chin_sensor':False,'main_blade_chord':.72,
          'profile':[(-.20,-.02,.35,.39),(-.15,0,.49,.49),(.02,0,.50,.50),(.28,0,.50,.50),(.40,-.03,.46,.46),(.47,-.12,.33,.35),(.50,-.18,.11,.16)]})
    remove(r,'Cargo_Ramp',*[p['name'] for p in r.parts if p['name'].startswith(('Sponson','Engine_','Exhaust_'))])
    for p in r.parts:
        if p['name'].startswith(('Gear_Nose','Wheel_Nose')):
            delta=np.array([0,0,2.0]);p['pivot']+=delta;r.pivots[p['name']]=p['pivot']
            if p['mesh'] is not None:p['mesh'].shift(delta)
        if p['name'].startswith('Wheel_'):
            m=Mesh();merge_mesh(m,p['mesh'],t=[-.16,0,0]);merge_mesh(m,p['mesh'],t=[.16,0,0]);p['mesh']=m
    for i,(x,y,z) in enumerate(((-1.38,4.95,7.15),(1.38,4.95,7.15),(-.85,5.65,2.30))):
        m=Mesh();curved_shell(m,'paint',[(z-4.5,y,.32,.37),(z-3.7,y,.57,.56),(z-.40,y,.60,.60),(z,y,.56,.56)],lod,circumference=6 if lod else 24,longitudinal=2)
        m.shift((x,0,0));m.tube('metal_dark',(x,y,z-4.48),(x,y,z-4.82),.29,6 if lod else 16)
        m.tube('metal_dark',(x,y,z+.01),(x,y,z+.045),.44,6 if lod else 20)
        if not lod:
            for a in np.linspace(0,math.tau,10,endpoint=False):
                v=np.array([math.cos(a),math.sin(a),0]);beam(m,'paint',np.array([x,y,z-.72])+v*.60,np.array([x,y,z-.05])+v*.56,.04)
        r.add('Engine_'+str(i),'Fuselage',(x,y,z-2),m);r.add('Exhaust_'+str(i),'Engine_'+str(i),(x,y,z-4.82))
    m=Mesh();profile_hull(m,'paint',[(8.1,4.45,.85),(6.8,5.55,.74),(3.8,5.66,.74),(-3.0,5.30,.62),(-3.4,4.35,.75)])
    m.tube('paint',(0,5.45,4.7),(0,6.04,4.7),.38,6 if lod else 20,r_top=.25);r.add('Transmission_Fairing','Fuselage',(0,4.5,4.7),m)
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();curved_shell(m,'paint',[(-4.6,1.72,.10,.16),(-3.6,1.72,.60,.68),(3.5,1.75,.60,.68),(4.9,1.85,.13,.20)],lod,circumference=6 if lod else 24,longitudinal=2,cross_power=.65)
        m.shift((side*2.05,0,0));r.add('Integrated_Sponson_'+label,'Fuselage',(side*2.05,1.75,0),m)
    m=Mesh();m.tube('paint',(.95,1.72,9.7),(.95,1.72,13.95),.13,6 if lod else 20,r_top=.085)
    m.tube('metal_dark',(.95,1.72,13.95),(.95,1.72,14.45),.06,6 if lod else 12);r.add('Refuelling_Probe','Fuselage',(.95,1.72,9.7),m)
    m=Mesh();p=np.array([0,1.35,-4.2]);m.box('paint',p+[0,.80,-.10],(2.50,1.65,.18));r.add('Ramp','Fuselage',p,m,'X')
    m=Mesh();beam(m,'metal_dark',(0,3.35,-10.0),(0,2.50,-10.30),.10);r.add('Tail_Bumper','Fuselage',(0,3.35,-10),m)
    s.details.update(inventory_status='confirmed_order_not_current_service',tyres_per_group=2,selected_reference='maker2024outline_and_photos_plus_Israeli_public_illustration',final_national_EW_installation_unverified=True)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('jet__','aewc__','drone__','heavyLift__')) and callable(f)}


def save(slug):
    from validate_aircraft import validate
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    a,s=checked(0);b,t=checked(1);assert asdict(s)==asdict(t)
    helicopter=slug.startswith('heavyLift__');points=[]
    for r in (a,b):
        for p in r.parts:
            central=not p['name'].startswith(('Rotor_Main','Rotor_Tail','Gear_','Wheel_')) if helicopter else p['name'].startswith(('Fuselage','Engine_','Intake','Canopy','Conformal_Tank','Dorsal_','Mission_Array','Ventral_Mission','Fixed_Tail_Cover','Sensor_Turret'))
            if p['mesh'] is not None and central:points.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    p=np.concatenate(points);lo,hi=p.min(0),p.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=planes.ART/'aircraft'/(slug+'.glb');write_glb(path,[a,b],heli_wreck(b,s) if helicopter else burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P5' if helicopter else 'P6','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_29.py. Current types/confirmed future order and selected historical exterior limitations in research/evidence.json. No imported symbols, pixels, live load or functional internals.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
