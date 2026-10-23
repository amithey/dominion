"""Evidence-led additions, with one original builder for each real designation.

Shared geometry comes from the approved Tier 7 Python parts. No Blender,
downloaded meshes, textures, game scripts or Godot project changes.
"""
from dataclasses import asdict
from pathlib import Path
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,write_glb,rotation,merge_mesh
from generate_p2_armour import carrier
from armour_parts import wreck as armour_wreck
from generate_p5_helicopters import model as helicopter_model
from helicopter_parts import burnt_wreck
from generate_p7_ships import combatant
from ship_parts import wreck as ship_wreck,beam

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'

def apc__m113as4(lod=0):
    rig,s=carrier('apc__m113as4','M113AS4',lod,6.,2.69,1.90,'m113','',6,.31,.77,True,
        source='https://www.army.gov.au/equipment/vehicles-and-surveillance/m113as4-armoured-personnel-carrier',
        features=['Australian lengthened M113 hull','six road wheels per side, unlike five-wheel M113A1','slab aluminium troop compartment','rear ramp','12.7 mm protected weapon turret'],
        approx=True,representative='Australian M113AS4 troop carrier; exterior fittings approximated',z=.12,front_engine=True,bow=.75,shoulder=.96)
    p=np.array([0,1.94,.12]);m=Mesh();m.tube('paint',p,p+[0,.46,0],.48,8 if lod else 24,.37)
    m.tube('paint',p+[0,.46,0],p+[0,.50,0],.34,8 if lod else 20)
    rig.add('Turret','Hull',p,m,'Y');q=p+[0,.26,.31];m=Mesh()
    m.box('metal_dark',q+[0,0,.22],(.17,.16,.45))
    m.tube('metal_dark',q+[0,0,.40],q+[0,0,1.25],.032,8 if lod else 16,.020)
    rig.add('Gun','Turret',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,1.25],forward='+Z')
    s.weapon='rws';s.features.append('enclosed powered 12.7 mm cupola, not a remote open weapon station')
    return rig,s

def helicopter__as532u2_cougar(lod=0):
    rig,s=helicopter_model('helicopter__as532u2_cougar','AS532U2 Cougar Mk II',lod,'h225',
        length=16.79,rotor_diameter=16.2,blades=4,hub_y=4.43,tail_diameter=3.15,tail_blades=4,
        source='https://www.defensie.nl/onderwerpen/m/materieel/vliegtuigen-helikopters-drones/cougar-transporthelikopter')
    s.features=['long-cabin Dutch AS532U2 Mk II transport','four main blades, unlike five-blade H225M','four-blade exposed tail rotor','twin turbine nacelles','retractable tricycle gear','sloped long tailcone','no attack stub wings']
    s.representative='Dutch AS532U2 transport; published rotor/body dimensions, small fittings estimated'
    return rig,s

def aaVehicle__fennek_swp(lod=0):
    rig,s=carrier('aaVehicle__fennek_swp','Fennek Stinger Weapon Platform',lod,5.58,2.55,1.79,'fennek','',2,.50,
        source='https://magazines.defensie.nl/landmacht/2019/10/08_mijn_uitrusting_10-2019',
        features=['Dutch low-profile four-wheel Fennek','two twin Stinger pods','four individual muzzle markers','passive electro-optical sensor, no invented search radar'],
        approx=True,representative='Current Dutch four-Stinger SWP; pod housing dimensions estimated',axles=[-1.73,1.73])
    p=np.array([0,1.85,-.25]);base=Mesh();base.tube('paint',p-[0,.07,0],p+[0,.18,0],.43,8 if lod else 24)
    rig.add('Turntable','Hull',p,base,'Y');q=p+[0,.25,0];m=Mesh()
    m.box('paint',q,(.50,.45,.55))
    for side in (-1,1):
        m.box('paint',q+[side*.62,.03,0],(.55,.37,1.64))
        for j in range(2):
            a=q+[side*(.48+j*.25),.03,-.79];b=a+[0,0,1.60]
            m.tube('metal_dark',a,b,.078,8 if lod else 16)
    m.box('glass',q+[0,.04,.30],(.28,.19,.06))
    rig.add('Launcher','Turntable',q,m,'X',tube_count=4)
    for i,(side,j) in enumerate(((-1,0),(-1,1),(1,0),(1,1))):
        rig.add('Muzzle_'+str(i),'Launcher',q+[side*(.48+j*.25),.03,.81],forward='+Z')
    s.details.update(tube_count=4,muzzle_positions=[(q+np.array([side*(.48+j*.25),.03,.81])).tolist() for side,j in ((-1,0),(-1,1),(1,0),(1,1))]);return rig,s

def mineClearer__kodiak(lod=0):
    rig,s=carrier('mineClearer__kodiak','Kodiak AEV 3 mine-breaching configuration',lod,7.72,3.60,1.48,'engineering','rws',7,.35,.99,True,
        source='https://magazines.defensie.nl/landmacht/2020/05/05_mijn_uitrusting_kodiak_chauffeur',
        features=['seven-wheel Leopard 2 chassis','split forward crew shelters','centre-mounted articulated excavator','front two-wing mine plough with tines','folded dipper and digging bucket','rear engine deck'],
        approx=True,representative='Dutch Kodiak with mine plough; hull, tool stowage and hydraulic details approximated',z=-.70,x=-.92,front_engine=False,storage=True,bow=.60,shoulder=.93)
    cab=Mesh()
    for side in (-1,1):
        cab.box('paint',(side*1.02,1.88,1.08),(1.10,.80,2.24))
        cab.box('glass',(side*1.02,2.18,2.22),(.50,.15,.04))
    rig.add('Crew_Shelters','Hull',(0,1.48,1.08),cab)
    p=np.array([0,1.55,1.45]);m=Mesh();m.tube('paint',p,p+[0,.27,0],.36,8 if lod else 20)
    rig.add('Boom','Hull',p,m,'Y');a=p+[0,.30,0];b=np.array([0,2.68,-1.25]);m=Mesh()
    for side in (-1,1):
        beam(m,a+[side*.17,0,0],b+[side*.17,0,0],.17,lod,'paint')
        beam(m,a+[side*.25,-.15,.15],b+[side*.25,-.22,.36],.065,lod)
    rig.add('Boom_Lift','Boom',a,m,'X');c=np.array([0,1.99,1.86]);m=Mesh()
    beam(m,b,c,.20,lod,'paint');beam(m,b+[.20,-.05,.20],c+[.20,.10,-.35],.07,lod)
    rig.add('Dipper','Boom_Lift',b,m,'X');m=Mesh();m.box('metal_dark',c+[0,-.21,.20],(.93,.50,.70))
    for x in np.linspace(-.40,.40,5):m.box('metal_dark',c+[x,-.40,.64],(.10,.14,.24))
    rig.add('Bucket','Dipper',c,m,'X')
    p=np.array([0,.85,3.72]);m=Mesh()
    for side in (-1,1):
        R=rotation([0,1,0],side*-.23);m.box('paint',(side*1.0,.68,4.15),(1.95,.74,.18),R)
        for x in np.linspace(.20,1.85,8 if not lod else 4):
            m.box('metal_dark',(side*x,.34,4.20),(.09,.52,.16))
        beam(m,[side*.62,1.0,3.05],[side*1.15,.75,4.13],.10,lod,'paint')
    rig.add('Spade','Hull',p,m,'X',purpose='two-wing mine plough')
    return rig,s

def landingShip__johan_de_witt(lod=0):
    return combatant('landingShip__johan_de_witt','Johan de Witt',lod,(176.,29.,6.,7.),
        'https://magazines.defensie.nl/materieelgezien/2025/03/mijn-materieel-zr.ms.-johan-de-witt',
        ['larger Dutch LPD, distinct from 166 m Rotterdam','broad forward command superstructure','twin exhaust blocks','aft helicopter hangar and landing deck','stern well-deck ramp','two Goalkeeper mounts','diesel-electric pod propulsion'],
        houses=[(0,26,22,52,11,0,.93),(0,35,18,22,5,11,.88),(0,-23,21,27,6,0,.94)],
        funnels=[(-7,-1,4.5,7,7.5,5),(7,-1,4.5,7,7.5,5)],masts=[(24,29,'panel',4.3),(-4,23,'bar',3.8)],
        guns=[],vls=[],canisters=[],ciws=[(-10,47,9),(10,-38,6.4)],ciws_style='goalkeeper',landing=True,ramp_height=5.8,hangar_z=-36.6,hangar_doors=2)

def gunboat__frisc(lod=0):
    rig,s=combatant('gunboat__frisc','FRISC 12 m boarding craft',lod,(12.,3.3,.65,.65),
        'https://www.defensie.nl/onderwerpen/m/materieel/schepen/frisc-motorboot-fast-raiding-interception-and-special-forces-craft',
        ['rigid-hull inflatable boarding craft','large continuous buoyancy collars','open deck with console and crew seats','no invented naval cannon or missile battery'],
        houses=[],masts=[],guns=[],vls=[],canisters=[],ciws=[],funnels=[],hangar=False,flight_deck=False,unmanned=True,bow_sheer=.25,
        hull_beam=2.55,hull_profile=[(-.5,.95),(-.3,1),(.1,1),(.30,.90),(.44,.55),(.5,.04)])
    m=Mesh();n=8 if lod else 24
    for side in (-1,1):
        points=[(side*1.31,1.05,-5.8),(side*1.31,1.05,1.0),(side*1.12,1.10,3.1),(side*.69,1.22,4.7),(0,1.30,5.5)]
        for a,b in zip(points,points[1:]):m.tube('rubber',a,b,.34,n)
    m.box('paint',(0,1.35,-.60),(.85,.80,1.15));m.box('glass',(0,1.96,-.28),(.83,.48,.06))
    for z in (-4.2,-2.6,1.5,3.):
        for x in (-.62,.62):
            m.box('rubber',(x,1.04,z),(.47,.12,.49));m.box('rubber',(x,1.31,z-.22),(.47,.56,.10))
    rig.add('Collars_Console_and_Seats','Hull',(0,1.05,0),m)
    covers=Mesh()
    for i,x in enumerate((-.64,.64)):
        covers.box('paint',(x,1.37,-4.65),(.94,.28,1.70))
        m=Mesh();p=np.array([x,.54,-5.94]);m.box('metal_dark',p+[0,-.08,-.12],(.16,.42,.23))
        m.tube('metal_dark',p+[0,-.20,-.12],p+[0,-.20,-.39],.12,n)
        rig.add('Stern_Drive_'+str(i),'Hull',p,m,'Y',purpose='steerable leg; engines are inboard')
    rig.add('Inboard_Engine_Covers','Hull',(0,1.30,-4.65),covers)
    s.features.append('twin inboard diesel covers with steerable stern-drive legs')
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}

def save(slug):
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    priority='P7' if slug.startswith(('gunboat__','landingShip__')) else 'P5' if slug.startswith('helicopter__') else 'P4' if slug.startswith('aaVehicle__') else 'P2'
    folder='ships' if priority=='P7' else 'aircraft' if priority=='P5' else 'vehicles'
    path=ART/folder/(slug+'.glb');c=Mesh()
    if priority=='P7':
        from validate_ships import validate
        width,height,length=s.beam,s.draft+s.freeboard,s.length;w=ship_wreck(b)
    elif priority=='P5':
        from validate_aircraft import validate
        width,height,length=s.width,s.belly+s.body_height,s.length;w=burnt_wreck(b,s)
    else:
        from validate_p3_artillery import validate
        width,height,length=s.width,s.roof,s.length;w=armour_wreck(b,s)
    c.box('metal_dark',(0,height/2,0),(width,height,length))
    write_glb(path,[a,b],w,c,{'scene_name':s.name,'vehicle':slug,'priority':priority,'spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','detached_turret':bool(getattr(s,'weapon','')),
        'canonical_track_path':{'half':3.23,'radius':.57,'y':.65},'research_addition':True})
    entry,tree=validate(path);entry['notes']+=' Evidence-led addition: generate_inventory_additions.py; operator sources in native/tools/models/research/evidence.json.'
    (Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8')
    print(tree);print('PASS',slug,entry['triangles'],flush=True);return entry

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--types',nargs='+',choices=BUILDERS,default=list(BUILDERS));p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in a.types],indent=2)+'\n',encoding='utf-8')
