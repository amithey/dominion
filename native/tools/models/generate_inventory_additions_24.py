"""Original Korean rescue, naval and light attack helicopter exteriors.

Public operator photographs and manufacturer family sizes; local fittings are
estimates. Historical photographic configuration is distinct from current type
activity. No imported meshes, photographs, textures, Blender or weapon internals.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p5_helicopters as helis
from helicopter_parts import HelicopterSpec,build,shell_surface,burnt_wreck
from generate_inventory_additions_12 import remove
from generate_inventory_additions_13 import without_box
from generate_inventory_additions_15 import transmission,twin_tyres
from generate_inventory_additions_20 import blackhawk_transport
from generate_p1_tanks import beam
from vehicle_parts import Mesh,merge_mesh,profile_hull,write_glb

DEMA='https://kookbang.dema.mil.kr/newsWeb/'
ADEX='https://theaviationist.com/2013/10/28/seoul-adex-13/'

def subtract(mesh,old):
    def key(a):return tuple(sorted(tuple(p) for p in np.round(a,6)))
    keys={key(np.asarray(g[0])[f]) for g in old.groups.values() for f in np.asarray(g[3]).reshape(-1,3)}
    out=Mesh()
    for role,g in mesh.groups.items():
        p,n,uv=map(np.asarray,g[:3])
        for f in np.asarray(g[3]).reshape(-1,3):
            q=p[f]
            if key(q) not in keys:out.face(role,q,np.cross(q[1]-q[0],q[2]-q[0]),normals=n[f],uv=uv[f])
    return out

def remove_family_tail(r,s):
    p=next(p for p in r.parts if p['name']=='Fuselage');tz=-s.length*.465;ty=s.details['tail_y'];fy=s.details.get('boom_y',ty)-.35;h=max(.70,s.tail_diameter*.50)
    old=Mesh();v=[(-.06,fy,tz+.85),(.06,fy,tz+.85),(-.06,ty+h,tz-.12),(.06,ty+h,tz-.12),(-.06,ty+h*.85,tz-.61),(.06,ty+h*.85,tz-.61),(-.06,fy+.03,tz-.54),(.06,fy+.03,tz-.54)]
    old.solid('paint',v,[(0,2,4,6),(1,7,5,3),(0,1,3,2),(2,3,5,4),(4,5,7,6),(6,7,1,0)])
    old.box('paint',(0,s.details.get('boom_y',ty)-.30,tz+s.length*.11),(s.width*1.55,.09,s.length*.075));p['mesh']=subtract(p['mesh'],old)

def rescue_hoist(r,lod,p,length=.70):
    p=np.array(p);m=Mesh();beam(m,'paint',p,p+[.52,.12,0],.105)
    m.tube('paint',p+[.52,.12,0],p+[.52,.12,-length],.135,8 if lod else 20)
    beam(m,'metal_dark',p+[.52,.12,-length+.06],p+[.52,-.20,-length+.06],.022)
    r.add('Rescue_Hoist','Fuselage',p,m,fit='stowed rescue hoist, outer support estimated')

def optic(r,lod,name,p,radius=.23):
    p=np.array(p);m=Mesh();m.tube('paint',p-[0,radius*.8,0],p+[0,radius*.8,0],radius,8 if lod else 24)
    m.tube('glass',p+[0,0,radius*.75],p+[0,0,radius*1.02],radius*.58,8 if lod else 20)
    r.add(name,'Fuselage',p,m)

def empty_naval_stations(r,s,lod):
    positions={}
    for i,(side,label) in enumerate(((-1,'L'),(1,'R'))):
        p=np.array([side*1.60,1.34,1.30]);m=Mesh()
        beam(m,'paint',(side*.84,1.80,1.30),p+[0,.13,0],.13)
        m.box('metal_dark',p,(.13,.14,1.18))
        for z in (.92,1.65):beam(m,'paint',(side*1.60,1.42,z),(side*1.24,1.99,z),.055)
        r.add('Weapon_Carrier_'+label,'Fuselage',p,m)
        q=p+[0,-.12,.59];r.add('Muzzle_'+str(i),'Weapon_Carrier_'+label,q,purpose='empty exterior carrier reference; no selected live sortie load');positions['Muzzle_'+str(i)]=q.tolist()
    s.details.update(naval_store='empty_external_carriers',muzzle_count=2,muzzle_positions=positions)

def navalHelicopter__aw159_korean_asw(lod=0):
    r,s=helis.model('navalHelicopter__aw159_korean_asw','AW159 Korean naval ASW',lod,'wildcat',naval=True,
        source=DEMA+'20260622/5/ATCE_CTGR_0010040000/view.do',details={'naval_store':'none','naval_radar':False,'chin_sensor':False},
        representative='Korean ASW AW159, not UK HMA2 loaded with UK missiles. Maker12.8m main rotor/15.24m overall turning length/3.73m height;12m body and small carrier/sonar/ESM geometry estimated. Korean current activity and historical dipping-sonar operation separately documented. Empty carriers, sonar stowed; no assumption of optional UK kits or all-airframe fit.')
    remove(r,'Hoist');transmission(r,s,lod);twin_tyres(r,lod,['Nose'],.27)
    remove_family_tail(r,s);m=Mesh();tz=-s.length*.465
    # AW159 has two conspicuous tail stabilising surfaces, unlike the Lynx.
    m.box('paint',(0,2.25,tz+.12),(2.35,.10,1.08))
    for side in (-1,1):
        fin=Mesh();profile_hull(fin,'paint',[(tz+.52,2.23,.055),(tz+.07,3.68,.055),(tz-.54,3.73,.055),(tz-.39,2.23,.055)])
        fin.shift((side*.85,0,0));merge_mesh(m,fin)
    r.add('Twin_Tail_Fins','Fuselage',(0,2.25,tz),m)
    m=Mesh();shell_surface(m,'paint',[(4.10,.68,.32,.17),(4.60,.65,.66,.28),(5.52,.65,.65,.29),(5.90,.76,.16,.12)],lod,segments=8 if lod else 24)
    r.add('Search_Radar_Radome','Fuselage',(0,.65,5.0),m)
    optic(r,lod,'Nose_Optical_Sensor',(0,1.65,5.89),.21)
    m=Mesh();m.box('metal_dark',(0,.55,.24),(.48,.055,.62));m.box('paint',(0,.58,.24),(.55,.06,.70))
    r.add('Sonar_Bay_Closed','Fuselage',(0,.55,.24),m,fit='closed exterior sonar aperture only, no deployed sensor or functional internals')
    empty_naval_stations(r,s,lod)
    m=Mesh()
    for side in (-1,1):
        for z in (4.10,-.60):m.box('paint',(side*(.87 if z>0 else .72),1.80,z),(.17,.17,.27))
    r.add('Representative_ESM_Fairings','Fuselage',(0,1.80,0),m)
    s.features=['Korean naval ASW Wildcat, four main/four tail blades','twin tail stabilising fins and faceted cabin','fixed tricycle gear, twin nose tyres','closed lower-nose search radome and EO sensor','stowed dipping-sonar aperture and two empty external carriers','local ESM/carrier contour estimates; no copied UK missile load']
    return r,s

def navalHelicopter__super_lynx_mk99a(lod=0):
    r,s=helis.model(
        'navalHelicopter__super_lynx_mk99a','Super Lynx Mk99A Korean naval',lod,'wildcat',length=12.06,width=2.0,body_height=2.05,hub_y=3.43,hub_z=1.95,
        naval=True,source='https://www.leonardo.com/documents/15646808/16751907/ComLDO_Participation_Seoul_ADEX_16_10_2017_ENG.pdf?t=1538990870629',
        details={'naval_store':'none','naval_radar':False,'chin_sensor':False,'cross_section_power':.90,
        'profile':[(-.14,.04,.24,.30),(-.08,0,.46,.46),(.10,0,.50,.50),(.30,0,.50,.50),(.41,-.02,.44,.44),(.48,-.12,.25,.28),(.50,-.16,.08,.10)]},
        representative='ROKNavy Mk99A selected rounded-nose Seaspray/EO exterior photographed by USNavy18March2013; current2026Lynx activity does not certify this fit for every hull.12.06m body/12.8m main rotor family references; minor antenna and cabin dimensions estimated. Separate from AW159 twin-fin/engine/exhaust exterior. Mk99earlier subset and exact contemporary upgrades pending.')
    remove(r,'Hoist');transmission(r,s,lod);twin_tyres(r,lod,['Nose'],.27)
    # Older Gem nacelles: modest separate round exhausts, not Wildcat IR ducts.
    for p in r.parts:
        if p['name'].startswith('Engine_'):
            side=-1 if p['name']=='Engine_0' else 1;cy=2.63;z=.35;m=Mesh();shell_surface(m,'paint',[(-1.05,cy,.18,.19),(-.70,cy,.35,.34),(1.40,cy,.35,.34),(1.62,cy,.25,.26)],lod,segments=8 if lod else 24);m.shift((side*.49,0,0))
            m.tube('metal_dark',(side*.49,cy,-1.03),(side*.49,cy,-1.35),.18,8 if lod else 20);p['mesh']=m
    m=Mesh();shell_surface(m,'paint',[(4.68,.65,.28,.20),(5.04,.65,.62,.30),(5.90,.65,.63,.31),(6.23,.74,.23,.18)],lod,segments=8 if lod else 24)
    r.add('Search_Radar_Radome','Fuselage',(0,.65,5.6),m)
    optic(r,lod,'Nose_Optical_Sensor',(0,1.60,6.02),.22)
    m=Mesh();m.box('metal_dark',(0,.55,.30),(.47,.055,.62));r.add('Sonar_Bay_Closed','Fuselage',(0,.55,.30),m)
    rescue_hoist(r,lod,(.90,2.31,.25),.48);empty_naval_stations(r,s,lod)
    s.features=['rounded Lynx cabin with older twin Gem nacelles','single central tail fin and horizontal stabiliser, not Wildcat twin fins','four main/four tail blades','fixed tricycle landing gear with twin nose tyres','low rounded Seaspray radome and above-nose optical turret','stowed sonar aperture, rescue hoist and empty external carriers','historical selected Mk99Afit, not certification of all current Lynx hulls']
    return r,s

def helicopter__hh_60p_rescue(lod=0):
    r,s=blackhawk_transport('helicopter__hh_60p_rescue','HH-60P Korean Air Force rescue',lod,ADEX,
        'ROKAF HH60P photographed2013 rescue exterior; current HH60family operations confirmed2026. High-mounted paired external tanks, cheek fairing/searchlight/chin optics, stowed hoist. No assumption planned2029cockpit upgrade completed. Principal UH60family size; local tank/sensor dimensions and exact current per-hull fit estimated.')
    # The reused transport helper places a second plane using tail-rotor Y,
    # while the boom has a different Y. Keep one lower aft stabilator here.
    for p in r.parts:
        if p['name']=='Fuselage':
            z=-s.length*.355
            p['mesh']=without_box(p['mesh'],(0,s.details['tail_y']-.30,z),(4.40,.09,s.length*.075))
            p['mesh']=without_box(p['mesh'],(0,s.details['boom_y']-.30,z),(s.width*1.55,.09,s.length*.075))
            p['mesh'].box('paint',(0,s.details['boom_y']-.30,z),(4.40,.09,s.length*.075))
    m=Mesh()
    for side in (-1,1):
        q=Mesh();shell_surface(q,'paint',[(-.65,2.90,.035,.04),(-.12,2.90,.43,.42),(2.60,2.90,.43,.42),(3.30,2.90,.025,.035)],lod,segments=8 if lod else 24);q.shift((side*2.02,0,0));merge_mesh(m,q)
        for z in (.38,1.95):
            beam(m,'paint',(side*.90,2.77,z),(side*2.02,3.14,z),.13)
            beam(m,'metal_dark',(side*1.05,1.55,z),(side*1.99,3.05,z),.075)
    r.add('High_External_Fuel_Tanks','Fuselage',(0,2.90,1.2),m)
    m=Mesh();m.box('metal_dark',(1.02,1.72,5.13),(.34,.52,1.45));r.add('Right_Cheek_Fairing','Fuselage',(1.02,1.72,5.13),m)
    optic(r,lod,'Chin_Optical_Sensor',(0,.85,7.75),.30)
    m=Mesh();beam(m,'paint',(0,1.10,6.65),(0,1.10,7.75),.12);r.add('Optical_Support','Fuselage',(0,1.10,6.65),m)
    optic(r,lod,'Nose_Searchlight',(.62,1.65,7.10),.17);rescue_hoist(r,lod,(1.04,2.80,3.20))
    s.features+=['high-mounted two external fuel tanks on braced arms','right cheek fairing, nose searchlight and chin optics','right rescue hoist stowed','no Japanese refuelling probe or naval elongated radar nose','historical exterior fit/current family activity distinguished']
    return r,s

def helicopter__hh_47d_rescue(lod=0):
    r,s=helis.model('helicopter__hh_47d_rescue','HH-47D Korean Air Force rescue ER',lod,'chinook',source=ADEX,
        representative='ROKAF HH47D photographed2013 extended-range rescue exterior, distinguished from basic Army CH47D. Current HH47family operations confirmed2026. Larger side fuel tanks, nose radome/optical sensor and rescue hoist; no MH47refuelling probe.15.56m family body/18.3m rotors; local tank, sensor, gear and fairing dimensions estimated; present per-hull fit not certified.')
    # Remove exactly the shared small sponsons before fitting the tall ER tanks.
    old=Mesh();L=s.length;W=s.width;H=s.body_height;py=s.belly+H*.23;pz=-L*.01
    for side in (-1,1):
        q=Mesh();shell_surface(q,'paint',[(pz-L*.36,py,W*.12,H*.12),(pz-L*.32,py,W*.19,H*.18),(pz+L*.30,py,W*.19,H*.18),(pz+L*.34,py,W*.10,H*.10)],lod);q.shift((side*W*.47,0,0));merge_mesh(old,q)
    for p in r.parts:
        if p['name']=='Fuselage':p['mesh']=subtract(p['mesh'],old)
    m=Mesh()
    for side in (-1,1):
        q=Mesh();shell_surface(q,'paint',[(-5.90,1.40,.20,.32),(-5.25,1.40,.84,.68),(4.78,1.40,.84,.68),(5.45,1.40,.36,.45)],lod,segments=8 if lod else 24);q.shift((side*1.55,0,0));merge_mesh(m,q)
    r.add('Extended_Range_Sponsons','Fuselage',(0,1.40,0),m)
    twin_tyres(r,lod,['Left','Right'],.27)
    m=Mesh();shell_surface(m,'metal_dark',[(6.70,1.76,.30,.30),(7.20,1.76,.58,.49),(8.08,1.76,.52,.44),(8.39,1.76,.025,.04)],lod,segments=8 if lod else 24)
    r.add('Weather_Radar_Nose','Fuselage',(0,1.76,7.75),m)
    optic(r,lod,'Chin_Optical_Sensor',(.28,.85,8.0),.25)
    m=Mesh();m.tube('paint',(.28,1.01,8.0),(.28,1.45,8.0),.10,6 if lod else 16)
    r.add('Optical_Support','Fuselage',(.28,1.45,8.0),m);rescue_hoist(r,lod,(1.26,3.12,4.10),.75)
    s.features=['two tandem three-blade rotors, raised aft mast','two rear engine pods and closed rear cargo ramp','tall enlarged ER side fuel sponsons replacing small shared tanks','four landing gear stations, twin forward and single aft tyres','rounded black nose radome, chin optical sensor and right hoist','no aerial-refuelling probe or weapon stations','photographed2013 selected fit, current HH47family separate']
    return r,s

def gunship__500md_korean_attack(lod=0):
    s=HelicopterSpec('gunship__500md_korean_attack','500MD Korean Army armed scout','md500d',7.01,1.40,1.66,.54,2.64,1.45,8.05,5,1.40,2,'skid',
        DEMA+'20260904/11/ATCE_CTGR_0010030000/view.do',engines=1,approximate=True,
        details={'tail_y':1.65,'boom_y':1.60,'boom_start':.07,'window_z':(.22,),'main_blade_chord':.17,
        'profile':[(-.02,.02,.12,.22),(.08,0,.34,.40),(.22,0,.50,.50),(.34,.02,.49,.50),(.43,-.01,.36,.44),(.48,-.05,.20,.31),(.50,-.08,.025,.08)]},
        representative='Korean Army manned armed500MD, not500Epointed nose, OH6Afour-blade or experimental KUSVH UAV.2026September Army firing proves attack activity after August school-role retirement. Original bubble cabin/Ttail and empty exterior weapon supports.8.05m rotor family;7.01m body and1.4m tail rotor/2.64m hub are family/local estimates, not certified Korean dimensional drawing. No invented loaded pod tube count, TOWload, chin turret or sensor ball.')
    r,s=build(s,lod);remove_family_tail(r,s);remove(r,'Engine_0','Exhaust_0')
    m=Mesh();shell_surface(m,'paint',[(-1.00,1.78,.19,.22),(-.60,1.91,.34,.35),(.60,1.96,.33,.34),(1.10,1.97,.20,.19)],lod,segments=8 if lod else 24)
    m.tube('metal_dark',(0,1.86,-.90),(0,1.86,-1.22),.16,8 if lod else 20);r.add('Engine_0','Fuselage',(0,1.91,0),m);r.add('Exhaust_0','Fuselage',(0,1.86,-1.22))
    transmission(r,s,lod);m=Mesh();tz=-s.length*.465
    profile_hull(m,'paint',[(tz+.48,1.58,.055),(tz+.13,2.69,.055),(tz-.35,2.76,.055),(tz-.47,1.08,.055)])
    m.box('paint',(0,2.68,tz-.08),(1.62,.065,.53))
    for side in (-1,1):m.box('paint',(side*.79,2.73,tz-.08),(.05,.25,.56))
    r.add('T_Tail','Fuselage',(0,2.68,tz),m)
    # Empty compact carriers preserve the known armed role without guessing
    # an obscured pod tube count or copying a different500MDTOWconfiguration.
    positions={}
    for i,(side,label) in enumerate(((-1,'L'),(1,'R'))):
        m=Mesh();p=np.array([side*.89,1.0,1.50]);beam(m,'metal_dark',(side*.45,1.35,1.15),p,.09);m.box('paint',p,(.12,.12,.74));r.add('Weapon_Carrier_'+label,'Fuselage',p,m)
        q=p+[0,-.08,.37];r.add('Muzzle_'+str(i),'Weapon_Carrier_'+label,q,purpose='empty armed-scout carrier reference; installed live pod fit unresolved');positions['Muzzle_'+str(i)]=q.tolist()
    s.attack=True;s.details.update(gun=False,wing_span=1.90,stations_per_wing=1,muzzle_count=2,muzzle_positions=positions)
    s.features=['small rounded side-by-side bubble cabin','five main blades and two tail blades, single turbine','thin rear boom and high Ttail with tip plates','skid landing gear','two empty compact exterior weapon carriers, no invented load','training-role retirement distinguished from current Army firing']
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('helicopter__','navalHelicopter__','gunship__')) and callable(f)}

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
            if p['mesh'] is not None and p['name'] not in ('Rotor_Main','Rotor_Main_Aft','Rotor_Tail','Skid') and not p['name'].startswith(('Gear_','Wheel_')):
                points.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    p=np.concatenate(points);lo,hi=p.min(0),p.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=helis.ART/'aircraft'/(slug+'.glb');write_glb(path,[a,b],burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P5','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_24.py; public family principal dimensions and explicitly estimated local fittings. Historical photographic exterior and current family activity distinguished in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
