"""Original Japanese launcher, reconnaissance and helicopter exteriors.

Public-exterior estimates only. A dated holding, a development aircraft and a
firm series order are different statuses; none asserts fleet combat readiness.
Metres, +Z front, ground origin; shared saved-buffer validators, no Blender.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
import generate_p5_helicopters as helis
from generate_inventory_additions_12 import base,remove,hatch,lamps
from generate_p1_tanks import beam
from armour_parts import wreck
from helicopter_parts import shell_surface
from vehicle_parts import Mesh,profile_hull,loft,write_glb,lathe_x,merge_mesh,hollow_muzzle

GSDF='https://www.mod.go.jp/gsdf/'
SH60='https://www.mhi.com/jp/business/products-services/space-defense/defense-aircraft/sh-60l-maritime-patrol-helicopter'


def without_box(mesh,centre,size):
    """Replace a known shared static box without deleting adjacent shell faces."""
    old=Mesh();old.box('paint',centre,size)
    def key(p):return tuple(sorted(tuple(q) for q in np.round(p,6)))
    forbidden={key(np.asarray(g[0])[f]) for g in old.groups.values() for f in np.asarray(g[3]).reshape(-1,3)}
    out=Mesh()
    for role,g in mesh.groups.items():
        p,n,uv=map(np.asarray,g[:3])
        for f in np.asarray(g[3]).reshape(-1,3):
            q=p[f]
            if role=='paint' and key(q) in forbidden:continue
            out.face(role,q,np.cross(q[1]-q[0],q[2]-q[0]),normals=n[f],uv=uv[f])
    return out


def bonnet_hull(m,profile):
    """Ear-clip a concave bonnet/cabin side; a convex fan crosses the cowl."""
    xy=np.asarray([[z,y] for z,y,w in profile]);ids=list(range(len(profile)));tri=[]
    def cross(a,b):return a[0]*b[1]-a[1]*b[0]
    sign=1 if sum(cross(a,b) for a,b in zip(xy,np.roll(xy,-1,axis=0)))>0 else -1
    while len(ids)>3:
        for j,b in enumerate(ids):
            a,c=ids[j-1],ids[(j+1)%len(ids)];A,B,C=xy[[a,b,c]]
            if sign*cross(B-A,C-B)<=1e-9:continue
            if any(all(sign*cross(v-u,xy[k]-u)>=-1e-9 for u,v in ((A,B),(B,C),(C,A))) for k in ids if k not in (a,b,c)):continue
            tri.append((a,b,c));ids.pop(j);break
        else:raise ValueError('non-simple cabin profile')
    tri.append(tuple(ids))
    for side in (-1,1):
        for t in tri:m.face('paint',[(side*profile[i][2],profile[i][1],profile[i][0]) for i in t],[side,0,0])
    for (z,y,w),(zz,yy,ww) in zip(profile,profile[1:]+profile[:1]):
        m.face('paint',[(-w,y,z),(w,y,z),(ww,yy,zz),(-ww,yy,zz)],[0,-sign*(zz-z),sign*(yy-y)])


def launcher_truck(slug,name,lod,*,cylindrical=False):
    r,s,m=base(slug,name,11.90,2.50,3.20,4,.64,lod,axles=[-4.00,-2.50,2.00,3.50],
        source=GSDF+'assets/pdf/news/press/2026/20260331.pdf',
        features=['eight-wheel heavy carrier with paired fore and aft axles','raked two-seat cab with corner glazing',
        'aft transverse launcher erection bearings','four chassis stabilisers',
        'two long cylindrical transport canisters' if cylindrical else 'four long rectangular transport canisters, two by two'],
        representative='Initially deployed31March2026. Approximately12m carrier envelope estimated from public exterior photographs, not unpublished manufacturer drawings. Transport configuration; visible elevation bearings modelled, no unverified azimuth mechanism or weapon internals.')
    s.details.update(inventory_status='initial_equipment_deployment_2026_training_not_fleet_readiness',estimated_carrier_envelope=True)
    h=s.length/2
    for side in (-1,1):
        m.box('metal_dark',(side*.77,.93,0),(.22,.31,11.42))
        for z in s.axle_z:
            m.box('paint',(side*1.12,1.40,z),(.30,.12,1.43))
            m.box('rubber',(side*1.08,.91,z-.76),(.33,.83,.055))
    for z in (-5.35,-3.1,0,2.7,4.9):m.box('metal_dark',(0,1.04,z),(2.13,.17,.21))
    m.box('paint',(0,1.50,-.84),(2.32,.14,9.68))
    profile_hull(m,'paint',[(h-.17,1.36,1.08),(h-.02,1.91,1.10),(h-.64,3.20,1.13),(h-2.73,3.20,1.13),(h-2.85,1.38,1.07)])
    def front(y):return h-.02-(y-1.91)*.62/1.29+.018
    for x in (-.53,.53):m.face('glass',[(x-.47,2.16,front(2.16)),(x+.47,2.16,front(2.16)),(x+.47,2.94,front(2.94)),(x-.47,2.94,front(2.94))],[0,.43,.90])
    for side in (-1,1):
        m.face('glass',[(side*1.149,2.23,h-2.45),(side*1.149,2.23,h-1.11),(side*1.149,2.96,h-1.11),(side*1.149,2.96,h-2.45)],[side,0,0])
        m.box('paint',(side*1.15,1.84,h-1.84),(.04,.58,1.71))
        m.box('metal_dark',(side*1.183,2.12,h-2.37),(.03,.055,.17))
        for yy in (1.12,1.39):m.box('metal_dark',(side*1.21,yy,h-2.35),(.30,.055,.64))
        beam(m,'metal_dark',[side*1.12,2.80,h-.81],[side*1.43,2.86,h-.55],.035)
        m.box('metal_dark',(side*1.45,2.78,h-.54),(.12,.37,.18));m.box('glass',(side*1.45,2.78,h-.641),(.085,.30,.025))
    lamps(m,s.width,1.64,h-.04,lod)
    m.box('metal_dark',(0,1.27,h+.05),(2.31,.20,.17))
    hatch(m,0,3.215,h-1.57,.82,.75,lod)
    # Engine/cooling pack and protected control cabinets behind the cab.
    m.box('paint',(0,2.02,2.52),(1.91,.86,.67))
    if not lod:
        for x in np.linspace(-.78,.78,14):m.box('metal_dark',(x,2.11,2.166),(.045,.58,.025))
    for side in (-1,1):
        m.box('paint',(side*1.01,1.89,-.13),(.38,.64,2.53))
        for z in (-.97,-.26,.45):m.box('metal_dark',(side*1.211,1.89,z),(.025,.12,.15))
    # Stowed hydraulic jacks translate; do not pretend that their stems rotate.
    for side,label in ((-1,'L'),(1,'R')):
        for z,where in ((.65,'F'),(-5.10,'R')):
            p=np.array([side*1.02,1.63,z]);j=Mesh();j.tube('paint',p,p+[0,-.67,0],.12,6 if lod else 14)
            j.tube('metal_dark',p+[0,-.43,0],p+[0,-.83,0],.069,6 if lod else 12)
            j.box('paint',p+[0,-.87,0],(.43,.095,.44))
            r.add('Outrigger_'+where+label,'Hull',p,j,translation_axis='Y',mechanism='stowed telescopic stabiliser; exterior approximation')
    p=np.array([0,1.82,-4.95]);rack=Mesh();rack.box('metal_dark',(0,1.89,-1.03),(2.11,.19,8.13));markers=[]
    if cylindrical:
        for i,x in enumerate((-.57,.57)):
            cy=2.62;a=np.array([x,cy,-5.35]);b=np.array([x,cy,2.40]);n=10 if lod else 32
            rack.tube('paint',a,b,.48,n)
            rack.tube('metal_dark',b,b+[0,0,.045],.489,n);rack.tube('paint',b+[0,0,.045],b+[0,0,.085],.455,n)
            for z in (-5.15,-1.42,2.16):rack.tube('paint',(x,cy,z),(x,cy,z+.10),.505,n)
            for z in (-4.55,-.50,1.73):rack.box('paint',(x,2.04,z),(1.01,.26,.25))
            markers.append([x,cy,2.495])
    else:
        for x in (-.48,.48):
            for cy in (2.27,3.14):
                rack.box('paint',(x,cy,-1.05),(.86,.79,8.20))
                rack.box('metal_dark',(x,cy,3.07),(.90,.83,.04));rack.box('paint',(x,cy,3.105),(.83,.76,.035))
                for z in (-4.82,-1.05,2.73):rack.box('paint',(x,cy,z),(.91,.84,.10))
                if not lod:
                    for z in (-4.50,-2.80,-.90,.90,2.40):rack.box('metal_dark',(x,cy+.404,z),(.35,.028,.06))
                markers.append([x,cy,3.14])
    r.add('Launcher','Hull',p,rack,'X',mechanism='aft transverse launcher erection trunnions; no unverified turntable')
    for i,q in enumerate(markers):r.add('Muzzle_'+str(i),'Launcher',q,forward=[0,0,1],purpose='transport-canister forward exit')
    s.details.update(tube_count=len(markers),muzzle_positions=markers,azimuth_mechanism='not publicly established; no invented turntable')
    for side,label in ((-1,'L'),(1,'R')):
        q=np.array([side*.76,1.56,-3.80]);cy=Mesh();beam(cy,'metal_dark',q,[side*.76,1.94,.74],.12)
        r.add('Elevation_Actuator_'+label,'Hull',q,cy,'X',mechanism='transverse hydraulic-cylinder foot pin; runtime linkage may animate independently')
    return r,s


def coastalASM__type_25_ssm(lod=0):
    return launcher_truck('coastalASM__type_25_ssm','Type 25 surface-to-ship missile launcher',lod)


def df17__type_25_hvgp(lod=0):
    return launcher_truck('df17__type_25_hvgp','Type 25 high-velocity gliding projectile launcher',lod,cylindrical=True)


def reconVehicle__type_87_rcv(lod=0):
    r,s,m=base('reconVehicle__type_87_rcv','Type 87 reconnaissance combat vehicle',5.53,2.48,1.79,3,.51,lod,
        axles=[-1.80,-.35,1.75],weapon='kba_25',source=GSDF+'nae/7d/hensei/team/73/kunren/kunren.html',
        features=['six combat tyres with unequal axle spacing','raked narrow armoured bow','two-person welded25mm turret','rear powerpack and side access doors','paired turret antennas; no fictional missile racks'],
        representative='Retained Type87 exterior, not an invented2026 upgrade. Approximately6m overall including cannon;5.53m estimated body. Public photograph and rounded public dimensions guide the hull, wheelbase and turret fittings.')
    s.details.update(overall_length_metres=5.99,inventory_status='operator_live_fire_2025_and_2026_support')
    profile_hull(m,'paint',[(2.765,.63,.73),(2.64,1.27,1.06),(1.38,1.79,1.07),(-2.51,1.79,1.07),(-2.765,.80,.91)])
    lamps(m,s.width,1.24,2.63,lod)
    for side in (-1,1):
        m.box('paint',(side*1.12,1.17,-.04),(.17,.10,4.87))
        m.box('paint',(side*1.087,1.38,-.41),(.045,.70,.83))
        m.box('glass',(side*1.119,1.54,-.38),(.025,.17,.31))
        m.box('metal_dark',(side*1.14,1.36,-.70),(.035,.045,.15))
    hatch(m,-.51,1.81,1.59,.54,.56,lod)
    for x in (-.72,-.50,-.28):m.box('glass',(x,1.87,1.83),(.16,.08,.10))
    if not lod:
        for z in np.linspace(-2.48,-1.54,9):m.box('metal_dark',(0,1.805,z),(1.28,.018,.045))
    t=Mesh();loft(t,'paint',[[[x,y,z] for x,z in ring] for y,ring in [
        (1.91,[(-.38,1.04),(.38,1.04),(.91,.58),(.88,-.91),(-.88,-.91),(-.91,.58)]),
        (2.53,[(-.34,.80),(.34,.80),(.76,.43),(.72,-.77),(-.72,-.77),(-.76,.43)])]])
    for side in (-1,1):
        t.tube('paint',(side*.43,2.52,-.25),(side*.43,2.61,-.25),.31,8 if lod else 20)
        t.box('glass',(side*.48,2.67,.13),(.23,.10,.12))
        beam(t,'metal_dark',[side*.69,2.52,-.63],[side*.69,3.55,-.63],.016)
        for z in (-.20,-.42,-.64):t.tube('metal_dark',(side*.79,2.28,z),(side*1.01,2.39,z+.04),.039,6 if lod else 10)
    r.add('Turret','Hull',(0,1.89,.08),t,'Y')
    q=np.array([0,2.22,.85]);g=Mesh();g.box('paint',q,(.41,.39,.41))
    g.tube('metal_dark',q+[0,0,.16],q+[0,0,.66],.065,8 if lod else 16)
    g.tube('metal_dark',q+[0,0,.62],[0,2.22,3.19],.035,8 if lod else 16)
    hollow_muzzle(g,(0,2.22,3.19),(0,2.22,3.225),.047,.0125,8 if lod else 16)
    g.tube('metal_dark',q+[.19,-.035,.20],q+[.19,-.035,.72],.016,6 if lod else 10)
    r.add('Gun','Turret',q,g,'X');r.add('Muzzle','Gun',(0,2.22,3.225),forward=[0,0,1],caliber_metres=.025)
    return r,s


def reconVehicle__komatsu_lav(lod=0):
    r,s,m=base('reconVehicle__komatsu_lav','Komatsu light armoured vehicle',4.40,2.04,1.85,2,.39,lod,axles=[-1.35,1.35],
        source='https://sec.mod.go.jp/gsdf/neae/neafar/img2/20240827_soubihintenzi.pdf',
        features=['compact four-seat4x4','short armoured bonnet and steep cabin glazing','four side doors and rear personnel door','closed roof infantry hatch; no organic RWS','distinct from the larger Bushmaster'],
        representative='Unarmed baseline troop/scout exterior. The real vehicle permits infantry weapons to be fired from the hatch; this does not justify inventing a permanently fitted M2 or powered turret. Published4.4m by2.04m, local contours estimated.')
    bonnet_hull(m,[(2.20,.69,.79),(2.10,1.13,.88),(1.04,1.28,.92),(.50,1.85,.84),(-1.67,1.85,.84),(-2.20,1.22,.90),(-2.05,.53,.72),(1.90,.53,.72)])
    # A narrow cabin above its shoulder; glazing follows both raked surfaces.
    def front(y):return 1.04-(y-1.28)*.54/.57+.017
    for x in (-.40,.40):m.face('glass',[(x-.33,1.37,front(1.37)),(x+.33,1.37,front(1.37)),(x+.33,1.73,front(1.73)),(x-.33,1.73,front(1.73))],[0,.69,.73])
    for side in (-1,1):
        for z in (-1.09,.05):
            def sx(y):return side*(.92-(y-1.28)*.08/.57+.017)
            m.face('glass',[(sx(1.38),1.38,z-.31),(sx(1.38),1.38,z+.31),(sx(1.72),1.72,z+.31),(sx(1.72),1.72,z-.31)],[side,.14,0])
            m.box('metal_dark',(side*.944,1.24,z-.40),(.025,.045,.11))
            if not lod:
                for zz in (z-.44,z+.44):m.box('paint',(side*.940,1.10,zz),(.035,.30,.045))
        for z in s.axle_z:m.box('paint',(side*.91,.96,z),(.19,.11,1.02))
        beam(m,'metal_dark',[side*.94,1.62,.73],[side*1.10,1.66,.84],.025)
        m.box('metal_dark',(side*1.12,1.67,.84),(.10,.22,.12));m.box('glass',(side*1.12,1.67,.768),(.065,.16,.025))
    lamps(m,s.width,1.03,2.13,lod);m.box('metal_dark',(0,.68,2.22),(1.89,.15,.10))
    hatch(m,0,1.87,-.49,.96,.87,lod)
    # The actual rear has a personnel door, not a speculative spare tyre.
    m.box('paint',(0,1.17,-2.175),(.88,1.17,.06));m.box('glass',(0,1.49,-2.214),(.46,.22,.025))
    for side in (-1,1):m.box('markings',(side*.74,1.06,-2.194),(.24,.11,.026))
    beam(m,'metal_dark',[.68,1.81,-1.31],[.68,2.72,-1.31],.015)
    return r,s


def helicopter__uh_2(lod=0):
    r,s=helis.model('helicopter__uh_2','Subaru UH-2',lod,'bell412',length=13.10,width=2.30,hub_y=3.70,
        source='https://www.subaru.co.jp/news/2022_06_30_142233/',
        representative='Current Japanese production aircraft, delivery2022 and new operator deliverySeptember2026. Published13.1m airframe length and2.9m envelope exclude rotor diameters. Cowling, cabin profiles and local fittings reconstructed from public photographs.',
        details={'tail_y':2.40,'inventory_status':'documented_operator_delivery_2026','published_airframe_envelope':[13.1,2.9,3.7]})
    remove(r,'Engine_0','Engine_1','Exhaust_0','Exhaust_1','Skid')
    # Two PT6 turbines share one Twin-Pac cowling, not two BlackHawk pods.
    m=Mesh();shell_surface(m,'paint',[(-1.54,2.91,.49,.22),(-.95,3.00,.75,.37),(.85,3.05,.70,.36),(1.70,2.92,.42,.19)],lod,segments=10 if lod else 32)
    r.add('Engine_Cowling','Fuselage',(0,3.00,.05),m)
    for i,side in enumerate((-1,1)):
        p=np.array([side*.68,3.00,.42]);m=Mesh();m.tube('paint',p,p+[side*.12,0,0],.27,8 if lod else 24)
        m.tube('metal_dark',p+[side*.12,0,0],p+[side*.14,0,0],.21,8 if lod else 24)
        m.tube('metal_dark',(side*.39,2.98,-1.32),(side*.39,3.05,-1.90),.18,8 if lod else 20)
        r.add('Engine_'+str(i),'Fuselage',p,m);r.add('Exhaust_'+str(i),'Fuselage',(side*.39,3.05,-1.90),forward=[0,0,-1])
    m=Mesh()
    for side in (-1,1):
        for z,x,y in ((.27,.40,1.40),(3.01,.76,1.12)):
            beam(m,'metal_dark',[side*x,y,z],[side*1.375,.16,z],.075)
        m.tube('metal_dark',(side*1.375,.075,-1.31),(side*1.375,.075,3.67),.075,6 if lod else 16)
        beam(m,'metal_dark',[side*1.375,.075,3.67],[side*1.375,.32,4.45],.11)
    r.add('Skid','Fuselage',(0,.62,1.31),m)
    # The generic family's tailplane was scaled by cabin width; use the known
    # airframe envelope instead and retain all adjacent boom/fin triangles.
    for p in r.parts:
        if p['name']=='Fuselage':
            centre=(0,2.10,-s.length*.465+s.length*.11);size=(s.width*1.55,.09,s.length*.075)
            p['mesh']=without_box(p['mesh'],centre,size);p['mesh'].box('paint',centre,(2.88,.09,s.length*.075))
    s.features=['Japanese Bell412EPX-derived cabin','four14.02m main blades','two2.6m tail blades','shared Twin-Pac cowling with two turbine exhausts','2.9m skid/tailplane envelope','closed cabin doors; no invented cargo ramp or weapons']
    return r,s


def navalHelicopter__sh_60l(lod=0):
    r,s=helis.model('navalHelicopter__sh_60l','Mitsubishi SH-60L',lod,'blackhawk',naval=True,length=15.90,width=2.45,body_height=2.60,hub_y=4.00,rotor_diameter=16.40,tail_diameter=3.40,
        source=SH60,representative='Public K-derived SH60L exterior. Two development airframes held in March2026; first firm-contract series delivery plannedFY2027. Representative ASW stores do not assert an identical load on every aircraft. Local fairings and sensors estimated from operator/manufacturer photographs.',
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'main_blade_chord':.50,'chin_sensor':False,'naval_radar':False,
                 'naval_store':'torpedo','inventory_status':'development_airframes_held_series_order_future','published_rotors_turning_length':19.8})
    m=Mesh();shell_surface(m,'paint',[(3.72,.80,.39,.13),(4.22,.79,.72,.22),(5.67,.91,.66,.24),(6.02,1.03,.25,.11)],lod,segments=10 if lod else 28)
    r.add('Search_Radar_Radome','Fuselage',(0,.91,4.80),m)
    m=Mesh();m.box('metal_dark',(0,.89,4.80),(.78,.14,.06));r.add('Radar','Fuselage',(0,.89,4.80),m,'Y',mechanism='antenna inside fixed lower-nose fairing')
    m=Mesh();m.box('paint',(-.91,1.20,6.65),(.35,.55,.40));m.box('glass',(-.91,1.20,6.865),(.26,.40,.025))
    m.tube('paint',(0,.93,7.10),(0,.93,7.43),.18,8 if lod else 24,r_top=.12)
    r.add('Chin_Sensors','Fuselage',(0,1.20,6.65),m)
    # The transmission fairing supports the rotor mast between the engines.
    m=Mesh();shell_surface(m,'paint',[(1.61,3.23,.37,.15),(2.12,3.34,.55,.31),(3.16,3.31,.49,.28),(3.66,3.16,.28,.12)],lod,segments=8 if lod else 24)
    r.add('Transmission_Fairing','Fuselage',(0,3.34,2.81),m)
    # Shipboard tail landing gear uses a twin tyre on one transverse axle.
    for p in r.parts:
        if p['name']=='Wheel_Tail':
            q=p['pivot'];rr=.27*.65;m=Mesh()
            for side in (-1,1):
                tyre=Mesh();lathe_x(tyre,[(-.043,0,'paint'),(-.043,rr*.7,'rubber'),(-.027,rr,'rubber'),(.027,rr,'rubber'),(.043,rr*.7,'rubber'),(.043,0,'paint')],segments=8 if lod else 20)
                merge_mesh(m,tyre,t=q+[side*.09,0,0])
            p['mesh']=m
        if p['name']=='Fuselage':
            centre=(0,s.details['tail_y']-.30,-s.length*.465+s.length*.11);size=(s.width*1.55,.09,s.length*.075)
            p['mesh']=without_box(p['mesh'],centre,size);p['mesh'].box('paint',centre,(4.40,.09,s.length*.075))
    s.features=['K-derived Japanese enlarged cabin; not a generic Army BlackHawk','four16.4m main blades','four3.4m canted tail blades','two T700 engines','fixed search-radar fairing with internal Y antenna','short shipboard tail gear with twin rear tyres','representative pair of ASW torpedoes and actual station markers','two development airframes; future series deliveries distinguished']
    return r,s


BUILDERS={f.__name__:f for f in (coastalASM__type_25_ssm,df17__type_25_hvgp,reconVehicle__type_87_rcv,reconVehicle__komatsu_lav,helicopter__uh_2,navalHelicopter__sh_60l)}


def cite(entry,slug):
    refs={'coastalASM__type_25_ssm':['JP-SSM25-PHOTO26','JP-SSM25-EXHIBIT26'],
          'df17__type_25_hvgp':['JP-HVGP-PHOTO26','JP-HVGP-DEPLOY26'],
          'reconVehicle__type_87_rcv':['JP-RCV87-PHOTO25','JP-SUPPORT26'],
          'reconVehicle__komatsu_lav':['JP-LAV-PHOTO26','JP-LAV-SPEC24'],
          'helicopter__uh_2':['JP-UH2-DELIVERY26','JP-UH2-SPEC25'],
          'navalHelicopter__sh_60l':['JP-SH60L-PRODUCTION25','JP-CENSUS26']}
    evidence=json.loads((Path(__file__).parent/'research/evidence.json').read_text(encoding='utf-8'))
    urls={x['url'] for x in entry['sources']}
    entry['sources'] += [{'url':evidence['sources'][k]['url'],'use':evidence['sources'][k]['supports']} for k in refs[slug] if evidence['sources'][k]['url'] not in urls]
    return entry


def save(slug):
    if slug.startswith(('helicopter__','navalHelicopter__')):
        helis.BUILDERS[slug]=BUILDERS[slug];e=helis.save(slug)
    elif slug.startswith('reconVehicle__'):
        common.BUILDERS[slug]=BUILDERS[slug];e=common.save(slug)
    else:
        from validate_p3_artillery import validate
        a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
        path=common.ART/'vehicles'/(slug+'.glb');c=Mesh();c.box('metal_dark',(0,s.roof/2,0),(s.width,s.roof,s.length))
        write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P3','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','detached_turret':False,'research_addition':True})
        e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original evidence-led generator generate_inventory_additions_13.py. Metre-scale public exterior estimates; exact national delivery/contract distinctions in research/evidence.json. No imported meshes or photographs.'
    return cite(e,slug)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
