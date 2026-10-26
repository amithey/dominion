"""Original Korean AEW/SIGINT orders and three distinct fielded UAV exteriors.

Public manufacturer sizes and pictures, original Python surfaces. Marketing
renders identify proposed outer fairings, not a delivered production fit.
No imported meshes, images, Blender, classified internals or mission performance.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p6_aircraft as planes
from aircraft_parts import AircraftSpec,build,curved_shell,burnt_wreck
from vehicle_parts import Mesh,merge_mesh,write_glb,profile_hull,lathe_x
from generate_inventory_additions_12 import remove
from generate_p1_tanks import beam

L3='https://www.l3harris.com/newsroom/press-release/2025/10/republic-korea-selects-l3harris-airborne-early-warning-and-control'
KAI='https://www.koreaaero.com/EN/Business/UAV.aspx'
KUS='https://aerospace.koreanair.com/contents/media/brochure/kus_ft.pdf'
UCON='https://www.geonoise.com/wp-content/uploads/2018/02/2018-Uconsystem-Introduction-Geonoise.pdf'

def aewc__global_6500_korean_caew(lod=0):
    r,s=planes.largeplane('aewc__global_6500_korean_caew','Global 6500 Korean conformal AEW order',lod,'global6500',
        (30.3,28.7,7.8,2.70,2.70,1.35),
        [(.95,2.45,2.8,-3.9),(6.3,2.70,-.50,-5.0),(14.35,3.24,-5.20,-6.65)],
        [(0,2.95,7.8,-8.55,-14.80,-12.25,-14.28)],L3,
        ['Global6500 airframe with two rear turbofans and Ttail','swept wings with winglets','paired fixed conformal side arrays, not Saab dorsal Erieye bar','public marketing exterior for contracted Korean programme','small dorsal and ventral antenna blades; no rotating radar disc or weapons'],
        turbofans=[(-1.87,3.25,-9.15),(1.87,3.25,-9.15)],fan_radius=.61,fan_length=3.35,rear_engines=True,winglets=True,
        stabilator=[(.025,7.22,-11.90,-14.4),(4.15,7.22,-12.65,-14.32)],gear_layout=planes.airliner_gear(30.3,4.55,.39))
    cy=s.belly+s.body_height/2
    # Closed fairings grown into the fuselage, their broad faces stay fixed.
    # Actual internal AESA panels/mechanisms are neither needed nor modelled.
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();curved_shell(m,'paint',[(-1.40,cy,.13,.45),(-.55,cy,.46,.92),(6.72,cy,.48,.92),(8.45,cy,.27,.60),(8.90,cy,.04,.12)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 3,cross_power=.65)
        m.shift((side*1.20,0,0));r.add('Conformal_Array_'+label,'Fuselage',(side*1.20,cy,3.5),m,fit='fixed conformal fairing, public marketing shape with estimated dimensions')
    m=Mesh()
    for z in (-6.,-3.8,-1.8,.2,2.2):m.box('paint',(0,4.10,z),(.08,.30,.48))
    for z in (-5.5,-2.8,.5):m.box('paint',(0,1.24,z),(.065,.26,.45))
    r.add('Mission_Antenna_Fairings','Fuselage',(0,2.67,0),m)
    s.representative='Contracted Korean L3Harris/ELTA Global6500 AEW programme, not French SaabGlobalEye or existing BoeingPeaceEye. Public2025contract rendering and current2026manufacturer datasheet used for fixed conformal fairings. Manufacturer-family30.3x28.7x7.8m; local fairing/antenna dimensions estimated, final national serial fit not certified. Order, not delivered fleet or operational readiness.'
    s.details['inventory_status']='confirmed_order_delivery_not_established';return r,s

def ewJet__falcon_2000lxs_baekdu_ii(lod=0):
    r,s=planes.largeplane('ewJet__falcon_2000lxs_baekdu_ii','Falcon 2000LXS Baekdu phaseII order',lod,'falcon2000',
        (20.23,21.38,7.11,2.50,2.50,1.10),
        [(.80,1.85,1.70,-2.10),(4.40,2.03,.30,-3.35),(10.69,2.67,-2.80,-3.60)],
        [(0,2.70,7.11,-5.80,-9.70,-7.95,-9.28)],
        'https://www.koreaaero.com/KO/_UploadFiles/Cyclb/o6ZFakV1hJmQ1xIWyMC.pdf',
        ['shorter Falcon2000LXS business-jet airframe, two rear PW308C nacelles','swept low wing with winglets','low cruciform tailplane rather than Global6500 Ttail','representative closed belly mission fairings from KAIpublic concept','passive intelligence exterior, no fighter missiles or jammer load'],
        turbofans=[(-1.55,3.14,-6.80),(1.55,3.14,-6.80)],fan_radius=.57,fan_length=2.85,rear_engines=True,winglets=False,
        stabilator=[(.06,3.72,-7.45,-9.55),(3.30,3.72,-8.35,-9.48)],gear_layout=planes.airliner_gear(20.23,3.60,.34))
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();profile_hull(m,'paint',[(-2.80,2.67,.028),(-2.95,3.67,.028),(-3.35,3.67,.028),(-3.60,2.67,.028)])
        m.shift((side*10.69,0,0));r.add('Winglet_'+label,'Wing_'+label,(side*10.69,2.67,-3.2),m)
    m=Mesh();curved_shell(m,'paint',[(-4.90,.95,.11,.09),(-4.20,.95,.29,.22),(2.95,.95,.29,.22),(3.55,.99,.09,.08)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 3)
    for side in (-1,1):
        for z in (-1.45,1.80):
            pod=Mesh();curved_shell(pod,'paint',[(z-.55,1.45,.06,.07),(z-.30,1.45,.22,.22),(z+.32,1.45,.22,.22),(z+.58,1.45,.05,.06)],lod,circumference=6 if lod else 20,longitudinal=1 if lod else 2);pod.shift((side*.80,0,0));merge_mesh(m,pod)
    r.add('Closed_Mission_Fairings','Fuselage',(0,1.10,-.5),m,fit='approximate KAIpublic phaseIIconcept outer covers; no inferred internal sensor geometry')
    s.representative='Four Falcon2000LXS-based Baekdu phaseII mission aircraft contracted16December2021, development targetend2026. Maker2024green-airframe handover is NOT completed mission-system delivery. Public KAI2022concept underside fairings used as estimated order exterior; final sensors/antennas/acceptance remain unverified.20.23x21.38x7.11m maker family size; not earlier two Falcon2000EX/Sairframes or four olderHawker800s. Passive SIGINT role, no fictional strike weapons/jamming stores.'
    s.details['inventory_status']='confirmed_development_order_final_acceptance_unverified';return r,s

def small_uav(slug,name,lod,*,length,span,height,width,body_h,belly,wing,fins,prop,prop_radius,boom_x,boom_y,tailplane,source,profile,gear=None,spinner=.10):
    s=AircraftSpec(slug,name,'tactical_uav',length,span,height,width,body_h,belly,1,source,seats=0,
        details={'wing':wing,'fins':fins,'unmanned':True,'gun':False,'stations':(),
            'profile':profile,'sensor_turret':False,'nose_hump':False,'propellers':[prop],'prop_radius':prop_radius,
            'prop_blades':2,'prop_pusher':True,'prop_chord_scale':prop_radius*.85,'spinner_length':spinner,
            'stabilator':tailplane,'landing_none':gear is None,'gear_layout':gear or []})
    r,s=build(s,lod);remove(r,'Airframe_Fittings')
    if gear:
        # Airliner struts/22cm-wide tyres are much too large for tactical UAVs.
        remove(r,*[p['name'] for p in r.parts if p['name'].startswith('Gear_')])
        for g in gear:
            name=g['name'];rr=g['radius'];x,z=g['x'],g['z'];p=np.array([math.copysign(min(abs(x),width*.40),x),g['hinge_y'],z+.07]);axle=np.array([x,rr,z]);m=Mesh()
            m.tube('metal_dark',p,axle+[0,rr*.15,0],rr*.19,6 if lod else 16)
            r.add(name,'Fuselage',p,m,None,fixed_landing_gear=True,rotation_axis=None)
            m=Mesh();half=rr*.25
            lathe_x(m,[(-half,0,'paint'),(-half,rr*.70,'rubber'),(-half*.70,rr,'rubber'),(half*.70,rr,'rubber'),(half,rr*.70,'paint'),(half,0,'paint')],axle,8 if lod else 20)
            r.add(name+'_Wheel_0_0',name,axle,m,'X')
    # Dedicated slender booms instead of the MALE-UAV shared10cm boxes.
    m=Mesh()
    for side in (-1,1):
        x=side*boom_x;start=-length*.015;end=-length*.46
        m.tube('paint',(x,boom_y,start),(x,boom_y,end),width*.065,6 if lod else 16,r_top=width*.045)
        beam(m,'paint',(x,boom_y,start),(x,wing[0][1],start),width*.11)
    r.add('Twin_Tail_Booms','Fuselage',(0,boom_y,-length*.20),m)
    s.details.update(boom_x=boom_x,boom_y=boom_y,inventory_status='documented_service_no_readiness_claim')
    return r,s

def drone__kus_ft(lod=0):
    r,s=small_uav('drone__kus_ft','KUS-FT tactical UAV',lod,length=3.70,span=4.50,height=.90,width=.48,body_h=.34,belly=.23,
        wing=[(.12,.53,.50,-.10),(1.12,.53,.43,-.12),(2.25,.56,.24,-.13)],
        fins=[(-.52,.39,.90,-1.37,-1.84,-1.57,-1.83),(.52,.39,.90,-1.37,-1.84,-1.57,-1.83)],
        prop=[0,.52,-.55],prop_radius=.25,boom_x=.52,boom_y=.40,
        tailplane=[(.01,.87,-1.54,-1.85),(.53,.87,-1.54,-1.85)],source=KUS,
        profile=[(-.12,0,.16,.24),(-.03,0,.36,.43),(.15,0,.50,.50),(.34,-.02,.41,.45),(.45,-.06,.25,.32),(.50,-.12,.02,.07)],
        gear=[{'name':'Gear_Nose','x':0,'z':1.21,'radius':.06,'pairs':1,'hinge_y':.27,'axis':None},
          {'name':'Gear_Left','x':-.44,'z':.07,'radius':.075,'pairs':1,'hinge_y':.34,'axis':None},
          {'name':'Gear_Right','x':.44,'z':.07,'radius':.075,'pairs':1,'hinge_y':.34,'axis':None}])
    m=Mesh();p=np.array([0,.235,1.04]);m.tube('paint',p-[0,.09,0],p+[0,.09,0],.095,8 if lod else 20)
    m.tube('glass',p+[0,0,.07],p+[0,0,.11],.06,8 if lod else 16);r.add('EO_IR_Sensor','Fuselage',p,m,'Y')
    m=Mesh();m.box('paint',(0,.59,.45),(.17,.08,.22));r.add('Dorsal_Antenna','Fuselage',(0,.55,.45),m)
    s.features=['3.7m body and4.5m straight high wing','two thin booms with raised connecting horizontal tail','one rear two-blade pusher propeller','fixed tricycle gear, three single tyres','small lower EO/IR turret and dorsal antenna','unarmed tactical ISR, no KUSFSMALEshape or stores']
    s.representative='KoreanAir current manufacturer brochure names Army/Marine operators,3.7x4.5x.9m;2021maker says series completedDecember2020. Broad public planform/photo used, local propeller/gear/EO dimensions estimated. Later VTOLdivision-UAV programmes not assumed identical, completed or replacing every aircraft.'
    return r,s

def drone__rq_101_songgolmae(lod=0):
    r,s=small_uav('drone__rq_101_songgolmae','RQ-101 Songgolmae',lod,length=4.70,span=6.40,height=1.50,width=.65,body_h=.62,belly=.47,
        wing=[(.20,1.08,.73,-.14),(1.65,1.08,.62,-.19),(3.20,1.08,.38,-.22)],
        fins=[(-.87,.67,1.43,-1.70,-2.35,-1.94,-2.28),(.87,.67,1.43,-1.70,-2.35,-1.94,-2.28)],
        prop=[0,.99,-.64],prop_radius=.39,boom_x=.87,boom_y=.96,
        tailplane=[(.01,1.50,-1.86,-2.30),(.50,1.50,-1.86,-2.30),(.87,1.17,-1.86,-2.30)],source=KAI,
        profile=[(-.13,0,.18,.25),(-.04,0,.38,.42),(.15,0,.5,.5),(.35,-.02,.45,.47),(.46,-.04,.26,.34),(.50,-.07,.035,.09)],
        gear=[{'name':'Gear_Nose','x':0,'z':1.75,'radius':.12,'pairs':1,'hinge_y':.61,'axis':None},
          {'name':'Gear_Left','x':-.63,'z':-.10,'radius':.16,'pairs':1,'hinge_y':.60,'axis':None},
          {'name':'Gear_Right','x':.63,'z':-.10,'radius':.16,'pairs':1,'hinge_y':.60,'axis':None}])
    m=Mesh();p=np.array([0,.39,1.25]);m.tube('paint',p-[0,.15,0],p+[0,.15,0],.17,8 if lod else 24)
    m.tube('glass',p+[0,0,.13],p+[0,0,.18],.105,8 if lod else 20);r.add('EO_IR_Sensor','Fuselage',p,m,'Y')
    m=Mesh();m.tube('paint',(0,1.05,1.02),(0,1.37,1.02),.035,6 if lod else 16);m.box('paint',(0,1.42,1.02),(.16,.12,.14));r.add('Dorsal_Antenna','Fuselage',(0,1.05,1.02),m)
    m=Mesh();m.tube('metal_dark',(-.24,.84,-.32),(-.40,.75,-.57),.055,6 if lod else 16);r.add('Engine_Exhaust','Fuselage',(-.24,.84,-.32),m)
    s.features=['KAI4.7m body,6.4m span and1.5m height image dimensions','straight high wing, twin long slender booms','two upright end fins and raised bent connecting tailplane','rear pusher propeller and visible small exhaust','fixed tricycle gear, three single tyres','lower EO/IR turret and tall dorsal antenna; no weapon stations']
    s.representative='Fielded RQ101, not larger17m-span next-corps UAV. Maker dimension image actually read4.7x6.4x1.5m; DAPAJanuary2025says obsolescence upgrade completed/fielded. Original external model follows public manufacturer photos, small propeller/EO/gear details estimated. Exact sensor replacement/new propeller geometry not certified per serial; no claimed fleet availability.'
    return r,s

def drone__remoeye_002b(lod=0):
    r,s=small_uav('drone__remoeye_002b','RemoEye-002B',lod,length=1.44,span=1.80,height=.36,width=.18,body_h=.18,belly=.055,
        wing=[(.055,.29,.23,-.015),(.45,.30,.19,-.035),(.90,.35,.12,-.045)],
        fins=[(-.30,.10,.35,-.48,-.72,-.58,-.69),(.30,.10,.35,-.48,-.72,-.58,-.69)],
        prop=[0,.18,-.12],prop_radius=.15,boom_x=.30,boom_y=.105,
        tailplane=[(.01,.105,-.57,-.72),(.39,.105,-.58,-.71)],source=UCON,
        profile=[(-.05,0,.28,.31),(.04,0,.48,.48),(.29,0,.50,.50),(.44,.02,.41,.45),(.50,0,.12,.22)],spinner=.045)
    # Hand-launched airbag recovery has no fictional three-wheel gear.
    m=Mesh();p=np.array([0,.16,.64]);m.tube('paint',p-[0,0,.06],p+[0,0,.075],.068,8 if lod else 24)
    m.tube('glass',p+[0,0,.076],p+[0,0,.080],.037,8 if lod else 20);r.add('Nose_Camera','Fuselage',p,m,'Y')
    m=Mesh();m.box('paint',(0,.035,.25),(.135,.070,.39));r.add('Airbag_Closed_Cover','Fuselage',(0,.035,.25),m)
    # Support the high wing with the short body centre pylon visible in photos.
    m=Mesh();m.box('paint',(0,.245,.10),(.14,.12,.28));r.add('Wing_Centre_Support','Fuselage',(0,.245,.10),m)
    s.features=['manufacturer1.44m length and1.80m span','small high wing with upturned tips','short round nose camera and small belly airbag cover','two thin low tail booms and twin upright fins','rear electric pusher propeller','hand launch/airbag recovery, no gear or live weapons']
    s.representative='Army battalion RemoEye002B, not006AorcivilRemoM. Manufacturer2018brochure plus operator2021type entry and2025RemoEyefamily exercise.1.44x1.80m published, height/tip rise/propeller/camera estimated from public images. Contemporary per-unit exact suffix/upgrade fit unverified; family activity not blanket all delivered airframes serviceable.'
    return r,s

def drone__muav_kus_fs_production(lod=0):
    r,s=planes.male('drone__muav_kus_fs_production','MUAV KUS-FS production ISR exterior',lod,'kusfs',(13.,26.,3.0,1.70,1.00,.75),
        'https://dapa.go.kr/dapa/doc/selectDoc.do?bbsSeq=534&docSeq=58416&menuSeq=3073',
        blades=4,stations=(),prop_radius=1.13,ventral_fin=True,sensor_turret=False,nose_hump=False,
        profile=[(-.50,-.14,.05,.10),(-.38,-.08,.25,.33),(-.20,0,.43,.45),(0,.01,.46,.48),
            (.18,.05,.50,.57),(.32,.12,.48,.64),(.43,.04,.29,.55),(.50,-.10,.045,.12)])
    m=Mesh();curved_shell(m,'paint',[(-2.45,.72,.18,.17),(-1.75,.72,.65,.42),(1.95,.72,.65,.42),(2.65,.85,.20,.15)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 3,cross_power=.68)
    r.add('Ventral_Sensor_Fairing','Fuselage',(0,.72,0),m,fit='large closed ventral fairing photographed at rollout; local dimensions estimated')
    m=Mesh()
    for side in (-1,1):
        m.tube('paint',(side*.23,1.08,5.55),(side*.50,1.08,5.55),.20,8 if lod else 24)
        m.tube('glass',(side*.501,1.08,5.55),(side*.515,1.08,5.55),.14,8 if lod else 20)
    r.add('Lower_Nose_Optical_Windows','Fuselage',(0,1.08,5.55),m,fit='approximate visible side-facing lower nose apertures; exact sensor identity not asserted')
    m=Mesh();curved_shell(m,'paint',[(-5.20,1.57,.20,.20),(-4.60,1.68,.36,.29),(-2.90,1.69,.35,.28),(-2.65,1.64,.28,.19)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 3)
    m.tube('metal_dark',(0,1.64,-2.68),(0,1.64,-2.62),.19,8 if lod else 24);r.add('Dorsal_Engine_Intake','Fuselage',(0,1.65,-3.8),m)
    m=Mesh();m.tube('paint',(0,1.70,1.60),(0,1.98,1.60),.065,6 if lod else 16)
    m.tube('paint',(0,1.95,1.60),(0,2.12,1.60),.24,8 if lod else 24,r_top=.10);r.add('Dorsal_Satcom_Fairing','Fuselage',(0,1.70,1.60),m)
    s.features=['production13m length/26m span from April2026manufacturer release','large rounded raised forebody','long tapered wing, outward Vtail and small ventral fin','single rear four-blade representative pusher propeller','large closed underside sensor fairing and lower nose apertures','dorsal engine intake and small mushroom-like fairing','retracting tricycle gear, no pylons or live weapons']
    s.representative='Production MUAV/KUSFS13x26m exterior, five DAPA8April2026rollout photographs inspected. Existing13x25marmed generic asset not treated as exact production ISRfit. Original bulbous nose, dorsal intake and closed belly sensor fairing, unarmed. Height3m/common-family and minor camera/propeller/fairing dimensions estimated; no exact serial equipment certification. April rollout/production not delivery; published2027handover plan, latest acceptance remains unverified.'
    s.details['inventory_status']='production_rollout_confirmed_latest_acceptance_unverified';return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('aewc__','ewJet__','drone__')) and callable(f)}

def save(slug):
    from validate_aircraft import validate
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    a,s=checked(0);b,t=checked(1);assert asdict(s)==asdict(t)
    points=[]
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None and p['name'].startswith(('Fuselage','Engine','Conformal','Closed_Mission','Canopy','Twin_Tail_Booms','EO_IR','Nose_Camera','Wing_Centre','Airbag_','Dorsal_','Mission_Antenna')):
                points.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    p=np.concatenate(points);lo,hi=p.min(0),p.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=planes.ART/'aircraft'/(slug+'.glb');write_glb(path,[a,b],burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P6','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_25.py. National possession/order stage and estimated local exterior fitting limits in research/evidence.json; no live weapons or imported imagery.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
