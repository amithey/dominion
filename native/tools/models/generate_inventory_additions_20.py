"""Korean rotary-wing variants and KA-1 FAC; original Python exterior surfaces.

Public manufacturer/operator references identify the selected fit. Local contours,
equipment positions and unpublished dimensions are estimates, not engineering data.
No imported meshes, photograph textures, Blender or functional weapon internals.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_p5_helicopters as helis
import generate_p6_aircraft as planes
from generate_inventory_additions_12 import remove
from generate_inventory_additions_13 import without_box
from generate_inventory_additions_15 import transmission,replace_tailplane,twin_tyres
from helicopter_parts import shell_surface
from aircraft_parts import curved_shell,build as build_plane
from vehicle_parts import Mesh,merge_mesh,profile_hull,hollow_muzzle
from generate_p1_tanks import beam

KAI='https://www.koreaaero.com/EN/Business/'
DECK='https://kookbang.dema.mil.kr/newsWeb/20260415/9/ATCE_CTGR_0010030000/view.do'
NAVY='https://kookbang.dema.mil.kr/newsWeb/20260318/4/ATCE_CTGR_0010040000/view.do'

def gunship__lah_1_miron(lod=0):
    # Build a broad side-by-side cockpit before adding the chin weapon; the
    # attack=True generic helicopter canopy would incorrectly make it tandem.
    r,s=helis.model('gunship__lah_1_miron','LAH-1 Miron',lod,'panther',length=12.7,width=2.15,
        body_height=2.12,belly=.75,hub_y=4.08,hub_z=1.50,rotor_diameter=12.6,blades=5,
        tail_diameter=1.10,tail_blades=10,source=KAI+'LAH.aspx',
        details={'tail_y':2.77,'window_z':(.13,.25),'main_gear_z':.0,'wheel_radius':.29},
        representative='H155B1-derived LAH, side-by-side crew, chin cannon and empty stub-wing weapon stations. Flight-test nose boom omitted. Published14.3m overall/4.3m height;12.7m fuselage and local surfaces estimated. Ten tail blades follow H155B1 heritage; exact production fan detail requires further confirmation.')
    twin_tyres(r,lod,['Nose'],.29)
    for p in r.parts:
        if p['name']=='Fenestron_Surround':
            outer=s.tail_diameter*.62;ty=s.details['tail_y'];tz=-s.length*.465
            p['mesh']=without_box(p['mesh'],(0,ty+outer+.16,tz-.10),(.19,.38,.65))
            profile_hull(p['mesh'],'paint',[(tz+.46,ty+.45,.085),(tz+.25,4.24,.085),
                (tz-.62,4.30,.085),(tz-.74,ty+.40,.085)])
    # Twin stub wings, four real hardpoint markers, no invented loaded rockets.
    m=Mesh();positions={}
    for side,label in ((-1,'L'),(1,'R')):
        x0=side*.87;x1=side*1.95
        v=[(x,y,z) for y in (1.72,1.83) for x,z in ((x0,1.62),(x0,.28),(x1,.46),(x1,1.05))]
        m.solid('paint',v,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
        for j,x in enumerate((side*1.34,side*1.77)):
            m.box('paint',(x,1.60,.88),(.11,.28,.56))
            q=[x,1.50,1.18];name='Muzzle_'+str(1+(0 if side<0 else 2)+j)
            r.add(name,'Fuselage',q,purpose='empty supported weapon-station reference');positions[name]=q
    r.add('Stub_Wings','Fuselage',(0,1.78,.90),m)
    p=np.array([0,1.13,5.79]);m=Mesh();m.tube('paint',p-[0,.12,0],p+[0,.12,0],.28,8 if lod else 24)
    r.add('Turret','Fuselage',p,m,'Y')
    q=p+[0,-.11,.10];m=Mesh();m.box('metal_dark',q+[0,0,.20],(.29,.27,.43))
    for a in np.linspace(0,math.tau,3,endpoint=False):
        d=np.array([.077*math.cos(a),.077*math.sin(a),0]);hollow_muzzle(m,q+d+[0,0,.20],q+d+[0,0,1.42],.028,.016,6 if lod else 12)
    r.add('Gun','Turret',q,m,'X');end=(q+[0,0,1.42]).tolist();r.add('Muzzle_0','Gun',end);positions['Muzzle_0']=end
    m=Mesh();c=np.array([0,1.75,6.10]);m.tube('paint',c-[0,.24,0],c+[0,.24,0],.24,8 if lod else 24)
    m.tube('glass',c+[0,0,.19],c+[0,0,.25],.13,8 if lod else 20)
    r.add('Electro_Optical_Sight','Fuselage',c,m)
    s.attack=True;s.details.update(muzzle_count=5,muzzle_positions=positions,wing_span=3.9,stations_per_wing=2,
        tail_blade_evidence='H155B1 heritage, production count not independently certified')
    s.features=['broad side-by-side H155B1-derived cockpit, not tandem','five-blade12.6m main rotor and enclosed tail fan',
        'tall swept Fenestron fin','twin nose tyres and two single main tyres','three-barrel20mm chin turret, Y traverse/X elevation',
        'four empty stub-wing weapon hardpoints','nose EO sight; no flight-test instrumentation boom']
    return r,s

def helicopter__muh_1_marineon(lod=0):
    r,s=helis.model('helicopter__muh_1_marineon','MUH-1 Marineon',lod,'surion',length=15.,width=2.45,
        hub_y=4.17,source=KAI+'MUH1.aspx',details={'chin_sensor':False,'window_z':(.08,.16,.25),'wheel_radius':.33,'cross_section_power':.72},
        representative='Marine utility Marineon in spread-rotor, closed-door transport fit. Main-blade folding is documented; no unsupported tail-fold joint or ASW stores.15m body/15.8m rotor manufacturer dimensions; local fittings estimated.')
    transmission(r,s,lod);twin_tyres(r,lod,['Nose'],.33)
    m=Mesh()
    for side in (-1,1):
        # Stowed flotation bags along the lower cabin, not exposed torpedoes.
        pod=Mesh();shell_surface(pod,'paint',[(.10,.99,.07,.07),(.45,.99,.17,.15),(4.30,.99,.17,.15),(4.56,.99,.055,.07)],lod,segments=8 if lod else 20)
        pod.shift((side*1.23,0,0));merge_mesh(m,pod)
        for z in (1.0,2.8,4.0):
            m.box('metal_dark',(side*1.23,.99,z),(.34,.022,.045))
            beam(m,'paint',(side*.70,1.05,z),(side*1.23,1.05,z),.08)
    r.add('Stowed_Flotation_Bags','Fuselage',(0,.99,2.5),m)
    m=Mesh();shell_surface(m,'paint',[(6.79,1.64,.33,.29),(7.26,1.64,.45,.39),(7.78,1.64,.35,.30),(7.94,1.64,.04,.04)],lod,segments=8 if lod else 24)
    r.add('Weather_Radar_Nose','Fuselage',(0,1.64,7.2),m)
    m=Mesh();m.tube('paint',(0,1.18,7.43),(0,1.43,7.43),.20,8 if lod else 20)
    m.tube('glass',(0,1.30,7.55),(0,1.30,7.64),.11,8 if lod else 16)
    r.add('Nose_Optical_Sensor','Fuselage',(0,1.30,7.43),m)
    # Visible root collars are attached to the rotating mesh in flight position.
    for p in r.parts:
        if p['name']=='Rotor_Main':
            for a in np.linspace(0,math.tau,4,endpoint=False):
                q=np.array([math.cos(a),0,math.sin(a)])*.74+[0,s.hub_y,s.hub_z]
                p['mesh'].box('metal_dark',q,(.17,.09,.17))
    s.features=['Surion-derived Marine utility cabin','four main and four tail blades','manufacturer main-blade folding represented spread with root collars',
        'two engines and dorsal transmission fairing','two single main tyres and twin nose tyres','stowed lower-cabin flotation bags',
        'rounded nose weather radar and lower optical sensor','unarmed closed-door transport; no ASW stores or fictional tail-fold node']
    return r,s

def blackhawk_transport(slug,name,lod,source,representative):
    r,s=helis.model(slug,name,lod,'blackhawk',length=15.27,width=2.36,source=source,
        details={'chin_sensor':False,'tail_gear_z':-.40,'tail_gear_anchor_y':2.30},representative=representative)
    transmission(r,s,lod);replace_tailplane(r,s,4.40)
    s.features=['conventional BlackHawk transport cabin','four main and four20degree-canted tail blades','two engines and transmission fairing',
        'long aft single tailwheel, two single main tyres','no shipboard short twin-tailwheel gear','no weapon stations']
    return r,s

def helicopter__uh_60p(lod=0):
    return blackhawk_transport('helicopter__uh_60p','UH-60P',lod,DECK,
        'ROK Army UH60P basic closed-door transport, not a Japanese rescue or naval ASW helicopter. Current April2026 operator exercise confirms type; standard family size and local contours estimated. No assumed fleetwide digital upgrade.')

def navalHelicopter__uh_60_navy_rescue(lod=0):
    r,s=blackhawk_transport('navalHelicopter__uh_60_navy_rescue','ROK Navy UH-60 rescue',lod,NAVY,
        'Navy631Squadron rescue exterior photographed17March2026, not ROKAF HH60 or MH60R. Paired external tanks, elongated nose radar and rescue hoist. Source names UH60 only; exact suffix and local fittings not certified. No refuelling probe or ASW weapons.')
    m=Mesh()
    for side in (-1,1):
        tank=Mesh();shell_surface(tank,'paint',[(.00,1.53,.055,.055),(.55,1.53,.35,.34),(3.40,1.53,.35,.34),(4.15,1.53,.035,.045)],lod,segments=8 if lod else 24)
        tank.shift((side*2.40,0,0));merge_mesh(m,tank)
        beam(m,'paint',(side*.97,2.07,2.15),(side*2.40,2.05,2.15),.15)
        beam(m,'metal_dark',(side*1.10,1.30,2.15),(side*2.25,1.95,2.15),.075)
        for z in (1.30,2.90):beam(m,'paint',(side*2.40,2.05,z),(side*2.40,1.65,z),.09)
    r.add('External_Fuel_Tanks','Fuselage',(0,1.53,2.15),m)
    m=Mesh();shell_surface(m,'paint',[(6.82,1.56,.32,.31),(7.24,1.58,.43,.40),(8.35,1.66,.31,.32),(8.57,1.66,.025,.025)],lod,segments=8 if lod else 24)
    r.add('Weather_Radar_Nose','Fuselage',(0,1.60,7.7),m)
    p=np.array([1.08,2.68,3.52]);m=Mesh();beam(m,'paint',p,p+[.56,.10,0],.10)
    m.tube('paint',p+[.56,.10,0],p+[.56,.10,-.66],.14,8 if lod else 20)
    beam(m,'metal_dark',p+[.56,.10,-.60],p+[.56,-.32,-.60],.025)
    r.add('Rescue_Hoist','Fuselage',p,m)
    s.features+=['Navy photographed paired external tanks on supported ESSS arms','elongated rounded nose weather-radar fairing','right-side rescue hoist, cable stowed',
        'no Japanese refuelling probe, torpedoes or invented short Seahawk tail gear']
    return r,s

def lightFighter__ka_1(lod=0):
    # KT1-derived FAC, not the five-blade A29 with built-in wing guns.
    r,s=planes.airframe('lightFighter__ka_1','KA-1 forward air controller',lod,'ka1',(10.3,10.6,3.7,.93,1.05,.85),
        [(.30,.92,-1.25),(2.65,.67,-1.18),(5.30,.12,-.83)],[(0,1.67,3.70,-2.96,-5.12,-3.88,-4.85)],
        KAI+'KA1.aspx',seats=2,propellers=[(0,1.65,4.88)],prop_radius=1.05,prop_blades=4,
        stations=(.35,.64),gun=False,wheel_radius=.27,gear_track=2.45,
        stabilator=[(.23,1.88,-3.64,-5.04),(1.91,2.03,-3.99,-4.79)],canopy_front=.30,canopy_rear=-.055,
        profile=[(-.50,.08,.015,.025),(-.35,.08,.19,.19),(-.17,.04,.42,.40),(.06,0,.50,.50),
            (.25,.10,.41,.36),(.40,.25,.29,.29),(.46,.26,.23,.23)],
        features=['KT1-derived10.3m airframe and10.6m low tapered wing with dihedral','four-blade tractor propeller, not A29five-blade',
            'tandem two-seat canopy','three single tyres on retracting tricycle gear','four underwing hardpoints, two external fuel tanks and empty outer stations','no built-in wing guns, jets or Afterburner'],
        representative='ROKAF armed FAC derivative, representative two external50gal-class tanks with empty outer weapon stations. Manufacturer10.3x10.6x3.7m dimensions; propeller diameter and local fittings estimated. No imported meshes or invented built-in guns.')
    s.details['wing']=[[x,y+max(0,x-.30)*math.tan(math.radians(5.0)),le,te] for x,y,le,te in s.details['wing']]
    r,s=build_plane(s,lod)
    remove(r,*[p['name'] for p in r.parts if p['name'].startswith(('Store_','Muzzle_'))])
    positions={}
    for p in list(r.parts):
        if p['name'].startswith('Pylon_'):
            q=p['pivot']+[0,-.19,.35];name='Muzzle_'+str(len(positions));r.add(name,p['name'],q,purpose='multipurpose weapon-hardpoint marker; fuel carried on inner pair');positions[name]=q.tolist()
            if p['name'].endswith('0'):
                x=p['pivot'][0];z=p['pivot'][2];m=Mesh()
                curved_shell(m,'paint',[(z-1.15,.84,.035,.035),(z-.67,.84,.24,.24),(z+.66,.84,.24,.24),(z+1.16,.84,.025,.025)],lod,circumference=8 if lod else 24)
                for dz in (-.20,.20):beam(m,'paint',(0,p['pivot'][1]-.24,z+dz),(0,1.02,z+dz),.07)
                m.shift((x,0,0));r.add('Fuel_Tank_'+p['name'][-2:],'Fuselage',(x,.84,z),m)
    # PT6 exhaust stubs and the chin induction mouth, observed in KAI photos.
    m=Mesh()
    for side in (-1,1):m.tube('metal_dark',(side*.24,1.68,3.95),(side*.43,1.67,3.62),.08,8 if lod else 20)
    m.tube('paint',(0,1.27,4.30),(0,1.27,4.61),.17,8 if lod else 20,.14)
    m.tube('metal_dark',(0,1.27,4.61),(0,1.27,4.62),.115,8 if lod else 20)
    r.add('Engine_Intake_And_Exhaust','Fuselage',(0,1.45,4.0),m)
    s.details.update(muzzle_count=len(positions),muzzle_positions=positions,published_dimensions_m=[10.3,10.6,3.7],prop_diameter_estimated=True)
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('gunship__','helicopter__','navalHelicopter__','lightFighter__')) and callable(f)}

def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    module=planes if slug.startswith('lightFighter__') else helis
    module.BUILDERS[slug]=checked;e=module.save(slug)
    e['notes']+=' Original generate_inventory_additions_20.py. Variant evidence and remaining fit/dimension uncertainties in research/evidence.json; operator ownership does not imply combat readiness.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
