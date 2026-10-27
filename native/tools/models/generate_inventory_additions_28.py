"""Original Warmate3 and Israeli fighter/heavy-lift exteriors, no Blender.

Current types, signed orders and historical reference photographs are separated
in the evidence ledger. Public principal sizes; estimated local outer fittings.
No source meshes, photographic pixels, insignia, weapon internals or avionics.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p6_aircraft as planes
import generate_p5_helicopters as helis
from aircraft_parts import AircraftSpec,build,curved_shell,burnt_wreck,wings,tails,engines,ground_rig
from helicopter_parts import burnt_wreck as heli_wreck
from vehicle_parts import Mesh,Rig,profile_hull,merge_mesh,write_glb,rotation,hollow_muzzle
from generate_p1_tanks import beam
from generate_inventory_additions_12 import remove
from generate_inventory_additions_23 import stations,small_inlet,feathered_nozzles

WB='https://www.wbgroup.pl/aktualnosci/warmate3dlakorei/'
LM='https://lockheedmartin.com/en-il/index.html'
SIK='https://sikorskyarchives.com/home/sikorsky-product-history/helicopter-innovation-era/sikorsky-s-65/'


def loiterer__warmate_3(lod=0):
    # WB's own brochure gives1.6m span. Length/height/local fittings are public
    # photo estimates; no borrowed launcher, explosive parts or flight logic.
    L=1.17;y=.205
    s=AircraftSpec('loiterer__warmate_3','Warmate3 selected Korean contracted family','warmate3',L,1.60,.48,.13,.13,.14,1,WB,seats=0,
        features=['small cylindrical fuselage and closed nose camera housing','straight high-aspect wing with rounded tapered tips','outward Vtail with separate canted rudder hinges','two-blade rear electric pusher, local Zaxis','no wheels, cockpit, fictional gun or external weapons'],
        representative='WB2October2024signed Korean Warmate3contract and May2025maker reference to deliveries. Selected public maker exterior; manufacturer1.6m span,1.17m local estimated length and minor fittings. Not a certified exact Korean delivered nose/sensor configuration or current count/readiness.',
        details={'wing':[(.045,y,.13,-.10),(.61,y,.12,-.10),(.74,y+.004,.10,-.065),(.785,y+.009,.085,-.035),(.8,y+.01,.065,-.030)],
         'fins':[(-.012,y,y+.34,-.36,-.56,-.45,-.585),(.012,y,y+.34,-.36,-.56,-.45,-.585)],'fin_cant':45,
         'profile':[(-.50,0,.08,.10),(-.44,0,.40,.42),(-.22,0,.50,.50),(.18,0,.50,.50),(.36,0,.45,.45),(.46,0,.30,.32),(.50,0,.04,.05)],
         'unmanned':True,'sensor_turret':False,'gun':False,'stations':[],'landing_none':True,'oneway':True,
         'propellers':[[0,y,-.62]],'prop_radius':.14,'prop_blades':2,'prop_pusher':True,'prop_chord_scale':.10,'spinner_length':.035})
    # Assemble shared aerodynamic parts directly: the general UAV builder adds
    # a belly gimbal and large access blocks absent from WB's small airframe.
    r=Rig(lod);m=Mesh();cy=s.belly+s.body_height/2
    curved_shell(m,'paint',[(z*L,cy+dy*s.body_height,rx*s.body_width,ry*s.body_height)
        for z,dy,rx,ry in s.details['profile']],lod)
    r.add('Fuselage',r.root,(0,0,0),m);wings(r,s,lod);engines(r,s,lod);tails(r,s,lod)
    p=[0,cy,.596];r.add('Muzzle_0','Fuselage',p,purpose='nonfunctional forward impact reference')
    s.details.update(muzzle_positions={'Muzzle_0':p},muzzle_count=1);m=Mesh()
    m.tube('paint',(0,cy,.555),(0,cy,.589),.029,8 if lod else 20,r_top=.020)
    m.tube('glass',(0,cy,.590),(0,cy,.596),.014,8 if lod else 16)
    # Closed seam collars identify the modular exterior, without internal parts.
    for z in (.26,.39):m.tube('metal_dark',(0,cy,z),(0,cy,z+.005),.0655,8 if lod else 24)
    r.add('Nose_Camera_and_Closed_Seams','Fuselage',(0,cy,.555),m)
    ground_rig(r,s)
    s.details['inventory_status']='signed2024_contract_manufacturer2025_delivery_reference_exact_acceptance_unverified';return r,s


def wide_inlet(r,s,lod):
    """Selected GEpowered Barak big-mouth outer duct, locally estimated."""
    p=next(p for p in r.parts if p['name']=='Intake');m=Mesh();z=s.length*.20;cy=s.belly+.06;n=8 if lod else 28
    outer=[];inner=[]
    for zz,yy,wx,hy in ((z,cy,.69,.39),(-s.length*.05,s.belly+s.body_height/2,.56,.46)):
        a=np.linspace(0,math.tau,n,endpoint=False)
        outer.append(np.array([[wx*math.sin(t),yy+hy*math.cos(t),zz] for t in a]));inner.append(np.array([[(wx-.055)*math.sin(t),yy+(hy-.055)*math.cos(t),zz] for t in a]))
    for i in range(n):
        j=(i+1)%n;out=(outer[0][i]+outer[0][j])/2-[0,cy,z]
        m.face('paint',[outer[0][i],outer[0][j],outer[1][j],outer[1][i]],out)
        m.face('metal_dark',[inner[0][i],inner[1][i],inner[1][j],inner[0][j]],-out)
        m.face('paint',[outer[0][i],inner[0][i],inner[0][j],outer[0][j]],[0,0,1])
    m.face('metal_dark',inner[1],[0,0,1]);p['mesh']=m


def israeli_falcon(slug,name,lod,seats,sufa=False):
    _,s=planes.model(slug,name,lod,'f16',seats);s.source=LM
    s.details.update(stations=[],engine_radius=.48 if sufa else .50,canopy_front=.285,canopy_rear=.055 if seats==2 else .125)
    r,s=build(s,lod)
    if sufa:small_inlet(r,s,lod)
    else:wide_inlet(r,s,lod)
    feathered_nozzles(r,s,lod,'F100' if sufa else 'F110');stations(r,s,lod,(.40,.64,.82),tips=True)
    if seats==2:
        m=Mesh();profile_hull(m,'paint',[(.86,2.34,.30),(.73,2.54,.30),(-.16,2.86,.32),(-3.88,2.88,.32),(-4.69,2.57,.28),(-4.72,2.34,.28)])
        for side in (-1,1):
            for z in (-3.93,-3.65):m.box('metal_dark',(side*.337,2.65,z),(.019,.22,.13))
            if not lod:
                for z in (-2.76,-1.48,.03):m.box('paint',(side*.338,2.65,z),(.024,.20,.35))
        r.add('Dorsal_Avionics_Spine','Fuselage',(0,2.35,-1.8),m)
    if sufa:
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();curved_shell(m,'paint',[(-4.10,2.04,.035,.045),(-3.70,2.08,.25,.24),(-2.80,2.12,.35,.31),
                (.98,2.13,.35,.31),(1.95,2.08,.25,.25),(2.65,1.99,.045,.075)],lod,cross_power=.72,circumference=8 if lod else 24,longitudinal=1 if lod else 3)
            m.shift([side*.75,0,0]);r.add('Conformal_Tank_'+label,'Fuselage',(side*.75,2.1,-.7),m)
            # The nose-side fairing is visible in the selected2022photograph.
            m=Mesh();m.box('paint',(side*.448,2.06,4.30),(.13,.31,.44));m.box('glass',(side*.519,2.06,4.30),(.018,.20,.27))
            r.add('Nose_Outer_Fairing_'+label,'Fuselage',(side*.448,2.06,4.30),m,fit='public outer cover, exact sensor identity not inferred')
    m=Mesh()
    for z in (-4.73,-1.90):m.box('paint',(0,2.92 if seats==2 else 2.36,z),(.055,.19,.28))
    for x in (-.18,-.06,.06,.18):m.box('paint',(x,2.51,4.57),(.026,.09,.34))
    r.add('Selected_Outer_Antenna_Covers','Fuselage',(0,2.4,1.0),m)
    s.features=['one F16engine and underslung inlet, swept wings/ventral fins','two-seat continuous hinged canopy' if seats==2 else 'single-seat short hinged canopy',
        'broad Israeli dorsal avionics spine' if seats==2 else 'short aft canopy fairing, no two-seat avionics spine',
        'paired close-fitting upper-fuselage conformal fuel tanks' if sufa else 'no conformal tanks on selected Barak fit',
        'PrattF100family/small inlet' if sufa else 'selected GEfamily wide inlet, no unverified engine swap',
        'empty wingtip/underwing/centre racks; actual sortie load not copied']
    s.representative=('IsraeliF16ISufa' if sufa else 'IsraeliF16DBarak selected dorsal-spine exterior' if seats==2 else 'IsraeliF16CBarakII selected single-seat exterior, not retired CBlock30BarakI')+'. Current family corroborated by operator/maker; original geometry from public principal F16size and selected exterior photographs. Local inlet/nozzle/fairing dimensions estimated; no national serial-fit certification or completed2025EWupgrade assumed. F16is single-engine; erroneous two-engine phrase in one operator editorial explicitly disregarded. No imported insignia, photographic pixels or live weapon load.'
    s.details['inventory_status']='current_type_supported_exact_current_serial_and_upgrade_fit_unverified';return r,s


def jet__f_16i_sufa(lod=0):return israeli_falcon('jet__f_16i_sufa','F16I Sufa selected Israeli exterior',lod,2,True)
def lightFighter__f_16c_barak_ii(lod=0):return israeli_falcon('lightFighter__f_16c_barak_ii','F16C BarakII selected Israeli exterior',lod,1)
def lightFighter__f_16d_barak(lod=0):return israeli_falcon('lightFighter__f_16d_barak','F16D Barak selected Israeli exterior',lod,2)


def heavyLift__ch_53_yasur_2025(lod=0):
    r,s=helis.model('heavyLift__ch_53_yasur_2025','CH53 Yasur2025 selected Israeli exterior',lod,'merlin',
        'Israeli two-engine S65C3/CH53Dfamily, not three-engine seven-blade CH53Korder. Principal20.42m fuselage/22m main rotor from Sikorsky archive; local height/probe/sponson/filter fittings estimated from public exterior photograph, not every current serial configuration.',
        length=20.42,width=2.69,body_height=3.40,belly=1.,hub_y=5.72,hub_z=3.90,rotor_diameter=22.,blades=6,tail_diameter=4.88,tail_blades=4,engines=2,approximate=True,source=SIK,
        features=['two large T64 nacelles and flared exterior particle-separator covers','six-blade22m main rotor and four-blade4.88m tail rotor','conventional vertical tail pylon, no CH53K third engine','large rounded side fuel sponsons and external braces','six physical tyres in three twin-wheel groups','short stored starboard refuelling probe, crew hoist and rear ramp','current Yasurfamily distinct from12CH53Kordered replacements'],
        details={'tail_y':5.08,'boom_y':3.40,'boom_start':-.16,'main_gear_z':-.12,'gear_spread':2.35/2.69,'wheel_radius':.43,
            'chin_sensor':False,'main_blade_chord':.65,'window_z':(-.12,.0,.12,.23),
            'profile':[(-.20,-.02,.31,.40),(-.15,0,.46,.49),(.02,0,.50,.50),(.27,0,.50,.50),(.39,-.03,.45,.45),(.47,-.13,.29,.32),(.50,-.18,.08,.14)]})
    remove(r,'Cargo_Ramp',*[p['name'] for p in r.parts if p['name'].startswith('Sponson')])
    for p in r.parts:
        if p['name'].startswith(('Engine_','Exhaust_')):
            delta=np.array([0,0,2.85]);p['pivot']+=delta;r.pivots[p['name']]=p['pivot']
            if p['mesh'] is not None:p['mesh'].shift(delta)
        if p['name'].startswith('Wheel_'):
            dual=Mesh();merge_mesh(dual,p['mesh'],t=[-.16,0,0]);merge_mesh(dual,p['mesh'],t=[.16,0,0]);p['mesh']=dual
    m=Mesh();profile_hull(m,'paint',[(5.65,4.12,.66),(4.90,5.10,.59),(1.30,5.10,.55),(.25,4.10,.64)])
    m.tube('paint',(0,4.95,3.90),(0,5.57,3.90),.36,8 if lod else 20,r_top=.23);r.add('Transmission_Fairing','Fuselage',(0,4.12,3.90),m)
    for side,label in ((-1,'L'),(1,'R')):
        x=side*s.width*.45;y=4.332;front=s.length*.04+s.length*.17*.55+2.85;m=Mesh()
        m.tube('paint',(x,y,front-.10),(x,y,front+.56),.53,8 if lod else 24,r_top=.68)
        m.tube('metal_dark',(x,y,front+.57),(x,y,front+.585),.57,8 if lod else 24)
        if not lod:
            for a in np.linspace(0,math.tau,12,endpoint=False):
                beam(m,'paint',(x+.50*math.cos(a),y+.50*math.sin(a),front-.04),(x+.65*math.cos(a),y+.65*math.sin(a),front+.57),.035)
        r.add('Engine_Particle_Separator_'+label,'Engine_'+str(0 if side<0 else 1),(x,y,front),m)
    m=Mesh()
    for side in (-1,1):
        pod=Mesh();curved_shell(pod,'paint',[(-4.80,1.56,.05,.08),(-4.42,1.56,.43,.44),(-.45,1.56,.43,.44),(.10,1.56,.07,.12)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 3)
        pod.shift([side*1.90,0,0]);merge_mesh(m,pod)
        for z in (-3.9,-.80):beam(m,'paint',(side*1.24,3.15,z),(side*1.90,2.00,z),.09)
        m.tube('paint',(side*1.90,2.13,-3.95),(side*1.90,2.13,-.55),.075,6 if lod else 16)
    r.add('External_Fuel_Sponsons','Fuselage',(0,1.56,-2.3),m)
    m=Mesh();m.tube('paint',(.83,1.65,8.60),(.83,1.65,10.73),.11,8 if lod else 20,r_top=.072)
    m.tube('metal_dark',(.83,1.65,10.73),(.83,1.65,10.96),.052,6 if lod else 16)
    r.add('Refuelling_Probe_Stowed','Fuselage',(.83,1.65,8.60),m)
    m=Mesh();p=np.array([1.22,3.35,6.55]);beam(m,'paint',p,p+[.47,0,.12],.09)
    m.tube('metal_dark',p+[.47,-.09,.12],p+[.47,.09,.12],.14,8 if lod else 20);r.add('Hoist','Fuselage',p,m)
    m=Mesh();p=np.array([0,1.30,-3.79]);m.box('paint',p+[0,.65,-.13],(2.18,1.36,.16),rotation([1,0,0],-.24));r.add('Ramp','Fuselage',p,m,'X')
    m=Mesh();m.tube('paint',(0,3.76,-4.65),(0,3.94,-4.65),.16,8 if lod else 20);r.add('Small_Dorsal_Fairing','Fuselage',(0,3.76,-4.65),m)
    s.details.update(inventory_status='documented_current_Yasur_family_not_CH53Kdelivery',tyres_per_group=2,selected_reference='firsthand2016Yasur2025photograph; current type confirmed separately by2026IMODreplacement contract',local_height_and_fittings_estimated=True)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('loiterer__','jet__','lightFighter__','heavyLift__')) and callable(f)}

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
            if p['mesh'] is not None and (p['name'] not in ('Rotor_Main','Rotor_Tail') and not p['name'].startswith(('Gear_','Wheel_')) if helicopter else p['name'].startswith(('Fuselage','Engine_','Engine_Particle','Intake','Canopy','Conformal_Tank','Dorsal_','Nose_Camera'))):
                points.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    p=np.concatenate(points);lo,hi=p.min(0),p.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=planes.ART/'aircraft'/(slug+'.glb');write_glb(path,[a,b],heli_wreck(b,s) if helicopter else burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P5' if helicopter else 'P6','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_28.py; national operator/order/retirement distinctions and exact public-reference limitations in research/evidence.json. No photo pixels, national symbols or functional weapon internals.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
