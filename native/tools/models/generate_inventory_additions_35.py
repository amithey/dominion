"""Original US rescue/SOF helicopter exteriors, shared Python parts, no Blender.

Selected public photographic fits, not invisible avionics or every serial.
Published rotor sizes and locally estimated body/fittings are distinguished.
External weapon silhouettes only; no functional internals or operating logic.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,merge_mesh,rotation,lathe_x,profile_hull,write_glb
from helicopter_parts import HelicopterSpec,shell_surface,rotors,landing_gear,burnt_wreck
from generate_p1_tanks import beam
from generate_inventory_additions_12 import remove
from generate_inventory_additions_33 import seahawk_glazing
import generate_p5_helicopters as helis
import generate_inventory_additions as common

SOCOM='https://www.socom.mil/FactBook/2026%20Fact%20Book.pdf'
PEO='https://www.socom.mil/SOF-ATL/SOF%20Week%202025%20Briefing%20Slides/PEO_RW_Overview_Smith.pdf'
MH6='https://www.dvidshub.net/image/7774208/afsoc-total-force-landed-mc-130j-mq-9-10s-mh-6s-wyoming-highways'
AH6='https://www.americanspecialops.com/night-stalkers/helicopters/little-birds.php'
MH60='https://www.dvidshub.net/image/9516854/vmgr-153-trains-texas'
MH47='https://www.dvidshub.net/image/8294959/arctic-edge-24-27th-special-operations-wing'
HH60='https://www.dvidshub.net/image/9235613/hh60w-jolly-green-ii-basic-air-craft-commander-certification'
LIMIT='Original selected public exterior; body cross sections, local small housings/gear/hinges are photo estimates, not factory drawings, invisible equipment or every current serial/readiness. Current family, past photographic fit and future orders are separated in research/evidence.json.'


def clipped(poly,axis,value,sign):
    """Clip a planar triangle/polygon, retaining metre UVs and its normals."""
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=sign*(a[0][axis]-value);db=sign*(b[0][axis]-value)
        if da>=-1e-10:out.append(a)
        if (da>1e-10 and db< -1e-10) or (da< -1e-10 and db>1e-10):
            t=da/(da-db);out.append(tuple(x+(y-x)*t for x,y in zip(a,b)))
    clean=[]
    for p in out:
        if not clean or np.linalg.norm(p[0]-clean[-1][0])>1e-8:clean.append(p)
    if len(clean)>1 and np.linalg.norm(clean[0][0]-clean[-1][0])<1e-8:clean.pop()
    return clean


def shell(m,role,sections,lod,**kw):
    shell_surface(m,role,sections,lod,segments=10 if lod else 32,subdivisions=1 if lod else 3,**kw)


def optic(r,name,parent,p,lod,radius=.23):
    p=np.array(p);m=Mesh();n=8 if lod else 24
    shell(m,'paint',[(p[2]-.20,p[1],radius*.55,radius*.55),(p[2],p[1],radius,radius),(p[2]+.21,p[1],radius*.65,radius*.65)],lod)
    m.shift([p[0],0,0]);m.tube('glass',p+[0,0,.213],p+[0,0,.228],radius*.49,n)
    r.add(name,parent,p,m,'Y',mechanism='external optical housing azimuth; no optical internals')


def fixed_minigun(m,p,lod):
    p=np.array(p);n=6 if lod else 8;m.box('metal_dark',p+[0,0,-.15],(.22,.22,.50))
    if lod:
        # Distant LOD keeps the barrel-cluster envelope and marker. Individual
        # six-barrel geometry remains in LOD0; no internal parts are modelled.
        m.tube('metal_dark',p,p+[0,0,.73],.062,n)
    else:
        for a in np.linspace(0,math.tau,6,endpoint=False):
            q=p+[.048*math.cos(a),.048*math.sin(a),0]
            m.tube('metal_dark',q,q+[0,0,.73],.014,n)
    for z in (.12,.60):m.tube('metal_dark',p+[0,0,z],p+[0,0,z+.045],.077,n)
    return p+[0,0,.73]


def pintle(r,label,p,lod,index,*,single=False):
    p=np.array(p);m=Mesh();m.tube('metal_dark',p-[0,.23,0],p+[0,.12,0],.065,6 if lod else 16)
    support=Mesh();beam(support,'paint',(p[0]*.75,p[1]-.23,p[2]),p-[0,.23,0],.075)
    r.add('Gunner_Frame_'+label,'Fuselage',p-[0,.23,0],support)
    for side in (-1,1):m.box('paint',p+[side*.11,.10,0],(.05,.22,.20))
    r.add('Gunner_'+label,'Fuselage',p,m,'Y',mechanism='external door-gun pintle')
    q=p+[0,.18,0];g=Mesh()
    if single:
        g.box('metal_dark',q+[0,0,-.10],(.16,.16,.39));g.tube('metal_dark',q,q+[0,0,.77],.022,6 if lod else 12);tip=q+[0,0,.77]
    else:tip=fixed_minigun(g,q,lod)
    g.box('metal_dark',q+[.18,-.07,-.12],(.20,.25,.35))
    r.add('Gun_'+label,'Gunner_'+label,q,g,'X',mechanism='external trunnion, local estimate')
    r.add(f'Muzzle_{index}','Gun_'+label,tip,forward='+Z')
    return tip.tolist()


def little_bird(slug,name,lod,armed):
    # Factbook nominal main rotor27.5ft adopted. Body station envelope, width,
    # tail diameter and fitting positions are local photographic estimates.
    s=HelicopterSpec(slug,name,'littlebird',7.45,1.44,1.68,.34,2.55,1.65,8.382,6,1.44,4,'skid',AH6 if armed else MH6,engines=1,tail_side=-1,attack=armed,approximate=True,representative=LIMIT)
    s.features=['compact rounded bubble cockpit and tapered single-engine cabin','six real main blades/four tail blades, high Ttail and thin boom','open rear side apertures and physical skid cross tubes','fixed light attack planks/two miniguns/two seven-mouth pods' if armed else 'two empty three-pad external transport benches, no invented installed guns']
    s.details.update(nominal_rotor_from_socom2026=True,body_and_tail_sizes_locally_estimated=True,selected_fit='SOCOM2026listed two-M134/two-M260 option and2025PEO outer form; inspected close-up has mixed gun fit, not asserted identical selected load' if armed else 'public2023MH6M external transport benches',gun=False,muzzle_count=0,muzzle_positions={})
    r=Rig(lod);m=Mesh();L=s.length;cy=s.belly+s.body_height/2
    sections=[(-.78,1.20,.30,.46),(-.36,1.19,.60,.73),(.35,1.18,.72,.83),(1.68,1.18,.72,.84),(2.53,1.13,.65,.79),(3.10,1.02,.42,.58),(3.42,.97,.035,.07)]
    shell_surface(m,'paint',sections,lod,window=lambda z,t:'glass' if z>1.72 and math.cos(t)>-.62 else 'paint',segments=12 if lod else 44,subdivisions=1 if lod else 5)
    # Remove the photographed rear cabin side apertures, retain their real
    # floor/roof frames and a small empty interior rather than painted windows.
    out=Mesh()
    for role,g in m.groups.items():
        if not g[3]:continue
        ps,ns,uv=(np.asarray(g[i]) for i in range(3))
        for f in np.asarray(g[3]).reshape(-1,3):
            q=ps[f];c=q.mean(0)
            poly=[(ps[k],ns[k],uv[k]) for k in f]
            if q[:,2].max()<=.05 or q[:,2].min()>=1.55 or q[:,1].max()<=.72 or q[:,1].min()>=1.70:parts=[poly]
            else:
                middle=clipped(clipped(poly,1,.72,1),1,1.70,-1)
                parts=[clipped(poly,1,.72,-1),clipped(poly,1,1.70,1),clipped(middle,2,.05,-1),clipped(middle,2,1.55,1)]
            for face in parts:
                if len(face)<3:continue
                for i in range(1,len(face)-1):
                    tri=[face[j] for j in (0,i,i+1)];points=np.array([a[0] for a in tri]);n=np.cross(points[1]-points[0],points[2]-points[0])
                    if np.linalg.norm(n)<1e-8:continue
                    normals=np.array([a[1]/np.linalg.norm(a[1]) for a in tri]);out.face(role,points,n,normals=normals,uv=[a[2] for a in tri])
    m=out;m.box('paint',(0,.59,.70),(1.24,.10,2.22));m.box('paint',(0,1.12,-.09),(1.10,1.05,.07))
    shell(m,'paint',[(-3.65,1.90,.075,.085),(-2.85,1.80,.12,.14),(-.55,1.48,.35,.34)],lod)
    # Upright Ttail, distinct from the lower tailplane of an ordinary MD500.
    m.solid('paint',[(-.045,1.80,-3.04),(.045,1.80,-3.04),(-.045,2.52,-3.34),(.045,2.52,-3.34),(-.045,2.47,-3.94),(.045,2.47,-3.94),(-.045,1.84,-3.70),(.045,1.84,-3.70)],[(0,2,4,6),(1,7,5,3),(0,1,3,2),(2,3,5,4),(4,5,7,6),(6,7,1,0)])
    m.box('paint',(0,2.48,-3.50),(1.62,.065,.53))
    for side in (-1,1):
        m.box('paint',(side*.84,2.57,-3.54),(.055,.24,.47))
        m.box('markings',(side*.364,1.64,-.64),(.015,.18,.28))
        for z in (.11,1.60):beam(m,'paint',(side*.67,.55,z),(side*.67,1.91,z),.035)
    for x in (-.37,.37):
        m.box('rubber',(x,.68,2.01),(.40,.10,.50));m.box('rubber',(x,1.00,1.75),(.40,.55,.08))
    # Bubble centre seam, lower bow band and side frame follow the surface.
    frame=Mesh()
    for theta in (0,-1.14,1.14):
        points=[]
        for z in np.linspace(1.68,3.38,4 if lod else 15):
            yy=np.interp(z,[p[0] for p in sections],[p[1] for p in sections]);ww=np.interp(z,[p[0] for p in sections],[p[2] for p in sections]);hh=np.interp(z,[p[0] for p in sections],[p[3] for p in sections]);points.append([ww*math.sin(theta),yy+(hh+.015)*math.cos(theta),z])
        for a,b in zip(points,points[1:]):frame.tube('paint',a,b,.018,4 if lod else 6)
    for side in (-1,1):beam(frame,'paint',(side*.67,1.12,1.70),(side*.20,.82,3.32),.023)
    r.add('Fuselage',r.root,(0,0,0),m);r.add('Canopy_Frames','Fuselage',(0,1.18,2.30),frame)
    e=Mesh();e.box('paint',(0,2.04,-.10),(.68,.40,1.10));e.tube('metal_dark',(0,1.80,-.85),(0,1.80,-1.02),.16,6 if lod else 20)
    if not lod:
        for x in np.linspace(-.28,.28,10):e.box('metal_dark',(x,2.255,-.10),(.025,.016,.76))
    r.add('Engine_0','Fuselage',(0,1.80,-.10),e);r.add('Exhaust_0','Engine_0',(0,1.80,-1.02))
    rotors(r,s,lod,1.98,-3.56);landing_gear(r,s,lod)
    if armed:
        optic(r,'Chin_Optic','Fuselage',(0,.43,2.73),lod,.16)
        positions={};idx=0
        for side,label in ((-1,'L'),(1,'R')):
            plank=Mesh();plank.box('paint',(side*1.11,.80,1.18),(1.18,.15,.42));r.add('Weapon_Plank_'+label,'Fuselage',(side*.55,.80,1.18),plank)
            p=np.array([side*.91,.80,1.38]);g=Mesh();tip=fixed_minigun(g,p,lod);r.add('Gun_'+label,'Weapon_Plank_'+label,p,g);r.add(f'Muzzle_{idx}','Gun_'+label,tip,forward='+Z');positions[f'Muzzle_{idx}']=tip.tolist();idx+=1
            p=np.array([side*1.52,.64,1.16]);pod=Mesh();n=8 if lod else 24
            pod.tube('paint',p+[0,0,-.51],p+[0,0,.51],.205,n)
            for z in (-.36,.28):pod.tube('metal_dark',p+[0,0,z],p+[0,0,z+.03],.215,n)
            r.add('Pod_'+label,'Weapon_Plank_'+label,p,pod)
            for j in range(7):
                a=(j-1)*math.tau/6;off=np.zeros(3) if not j else np.array([.128*math.cos(a),.128*math.sin(a),0]);tip=p+off+[0,0,.535]
                cap=Mesh();cap.tube('metal_dark',tip-[0,0,.020],tip,.046,6 if lod else 12)
                r.add('Pod_Mouth_'+label+str(j),'Pod_'+label,tip,cap);r.add(f'Muzzle_{idx}','Pod_'+label,tip,forward='+Z');positions[f'Muzzle_{idx}']=tip.tolist();idx+=1
        s.details.update(muzzle_count=idx,muzzle_positions=positions,fixed_side_guns=2,pod_mouths=14,no_chin_turret=True)
    else:
        for side,label in ((-1,'L'),(1,'R')):
            b=Mesh();b.box('paint',(side*1.04,.77,.80),(.87,.11,1.85))
            for z in (.18,.80,1.42):b.box('rubber',(side*1.08,.855,z),(.70,.065,.52))
            for z in (.05,1.60):beam(b,'metal_dark',(side*.56,.60,z),(side*1.36,.69,z),.045)
            beam(b,'metal_dark',(side*1.43,.62,-.02),(side*1.43,.62,1.67),.035)
            r.add('External_Bench_'+label,'Fuselage',(side*.68,.77,.80),b,empty_transport_pads=3)
        s.details['external_empty_pads']=6
    return r,s


def helicopter__mh_6m_little_bird(lod=0):return little_bird('helicopter__mh_6m_little_bird','MH6M Little Bird selected external-bench fit',lod,False)
def gunship__ah_6m_little_bird(lod=0):return little_bird('gunship__ah_6m_little_bird','AH6M Little Bird selected two-pod two-minigun fit',lod,True)


def probe(r,s,lod,start,end,radius=.085):
    p=np.array(start);q=np.array(end);m=Mesh();n=6 if lod else 18
    m.tube('paint',p,q,radius,n);m.tube('metal_dark',q-[0,0,.18],q+[0,0,.08],radius*.73,n)
    for f in (.12,.38,.72):
        a=p*(1-f)+q*f;m.tube('metal_dark',a,a+[0,0,.025],radius*1.10,n)
    r.add('Refuelling_Probe','Fuselage',p,m,exterior_only=True)


def hawk_engines(r,s,lod):
    remove(r,'Engine_0','Engine_1','Exhaust_0','Exhaust_1')
    for i,side in enumerate((-1,1)):
        x=side*.57;y=3.04;m=Mesh()
        shell(m,'paint',[(-1.00,y,.30,.31),(-.40,y,.43,.42),(1.55,y,.43,.42),(2.22,y,.34,.34)],lod);m.shift([x,0,0])
        m.tube('metal_dark',(x,y,2.23),(x,y,2.25),.29,8 if lod else 24)
        # Separate upturned external fairing in the actual nacelle's frame.
        ex=Mesh();shell(ex,'paint',[(-1.48,3.59,.32,.19),(-1.13,3.26,.35,.28),(-.89,3.12,.30,.28)],lod);ex.shift([x,0,0])
        merge_mesh(m,ex)
        m.tube('metal_dark',(x,3.60,-1.46),(x,3.63,-1.51),.21,8 if lod else 20)
        if not lod:
            for z in np.linspace(-.50,1.30,10):m.box('paint',(x+side*.438,3.02,z),(.022,.055,.025))
        r.add('Engine_'+str(i),'Fuselage',(x,y,.55),m);r.add('Exhaust_'+str(i),'Engine_'+str(i),(x,3.63,-1.51))


def hawk(slug,name,lod,rescue):
    r,s=helis.model(slug,name,lod,'blackhawk',details={'main_blade_chord':.53,'window_z':(-.03,.10,.23)})
    s.source=HH60 if rescue else MH60;s.representative=LIMIT
    s.details.update(selected_fit='USAF2025public exterior; weapon mounts left empty where no installed guns resolved' if rescue else 'public2025/2026assault MH60M, not DAP combined stores',body_fittings_locally_estimated=True,nominal_rotor_metres=16.36,muzzle_count=0,muzzle_positions={})
    s.features=['four wide-chord main blades/four canted tail blades','framed divided cockpit over opaque nose, fixed tailwheel gear','starboard refuelling probe and external nose optical/weather housings','upturned external exhaust fairings and separate roof intakes','rescue hoist and empty side weapon supports; no invented installed guns' if rescue else 'two separate pintle-mounted door miniguns; no DAPstub wings/rocket banks']
    seahawk_glazing(r,s,lod);hawk_engines(r,s,lod)
    p=np.array([0,1.50,7.46]);m=Mesh()
    shell(m,'paint',[(7.10,1.53,.40,.35),(7.61,1.50,.33,.30),(7.96 if not rescue else 7.80,1.50,.11,.15)],lod)
    if rescue:m.tube('metal_dark',p+[0,0,.35],p+[0,0,.37],.25,8 if lod else 24)
    else:m.box('paint',(0,1.90,7.41),(.62,.21,.50))
    r.add('Nose_Weather_Cover','Fuselage',p,m,external_cover_function_details_unverified=True)
    optic(r,'Chin_Optic','Fuselage',(-.12,.80,7.21),lod,.24)
    probe(r,s,lod,(.90,1.05,5.18),(.90,1.05,9.72))
    fit=Mesh()
    for side in (-1,1):
        fit.box('paint',(side*1.04,2.47,5.75),(.26,.20,.41))
        fit.box('paint',(side*1.20,1.74,-.58),(.24,.25,.40))
        beam(fit,'metal_dark',(side*.70,3.02,-1.50),(side*.70,3.53,-1.72),.022)
        if not lod:
            for z in np.linspace(-.2,3.6,12):fit.box('paint',(side*1.20,1.16,z),(.025,.12,.11))
    r.add('Selected_External_Fittings','Fuselage',(0,1.50,0),fit)
    if rescue:
        hoist=Mesh();hoist.tube('paint',(.78,2.95,3.41),(1.58,2.95,3.41),.15,8 if lod else 20)
        beam(hoist,'paint',(.88,2.74,3.19),(1.58,2.95,3.41),.08);hoist.box('metal_dark',(1.58,2.72,3.41),(.17,.25,.17))
        r.add('Rescue_Hoist','Fuselage',(.78,2.95,3.41),hoist)
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();beam(m,'paint',(side*1.02,1.24,3.66),(side*1.65,1.24,3.66),.10);m.tube('metal_dark',(side*1.65,1.24,3.66),(side*1.65,1.60,3.66),.055,6 if lod else 12)
            r.add('Empty_Weapon_Support_'+label,'Fuselage',(side*1.02,1.24,3.66),m)
        s.details.update(rescue_hoist=True,installed_guns_in_selected_fit=0)
    else:
        positions={}
        for i,(side,label) in enumerate(((-1,'L'),(1,'R'))):positions[f'Muzzle_{i}']=pintle(r,label,(side*1.42,1.62,3.34),lod,i)
        s.details.update(muzzle_count=2,muzzle_positions=positions,door_guns=2,not_DAP=True)
    return r,s


def helicopter__mh_60m_black_hawk(lod=0):return hawk('helicopter__mh_60m_black_hawk','MH60M Black Hawk selected assault exterior',lod,False)
def helicopter__hh_60w_jolly_green_ii(lod=0):return hawk('helicopter__hh_60w_jolly_green_ii','HH60W Jolly Green II selected public rescue exterior',lod,True)


def chinook_distant_body(s):
    """Same principal outline, eight-sided shells and four-sided round windows."""
    m=Mesh();L=s.length;W=s.width;H=s.body_height;b=s.belly;cy=b+H/2
    sections=[(-L*.5,cy+.20,W*.24,H*.31),(-L*.40,cy,W*.47,H*.48),(L*.15,cy,W*.50,H*.50),(L*.37,cy,W*.46,H*.49),(L*.47,cy-H*.10,W*.27,H*.34),(L*.50,cy-H*.18,W*.06,H*.12)]
    shell_surface(m,'paint',sections,1,window=lambda z,t:'glass' if L*.30<z<L*.455 and math.cos(t)>.08 and .18<t<math.tau-.18 else 'paint',segments=8,subdivisions=1)
    ay=s.details['aft_hub_y'];profile_hull(m,'paint',[(-L*.47,b+H*.63,W*.30),(-L*.45,ay-.30,W*.19),(-L*.29,ay-.30,W*.19),(-L*.24,b+H*.65,W*.31)])
    for side in (-1,1):
        pod=Mesh();pz=-L*.01;py=b+H*.23;rr=s.details['fuel_sponson_radius']
        shell_surface(pod,'paint',[(pz-L*.36,py,rr*.63,H*.12),(pz-L*.32,py,rr,H*.18),(pz+L*.30,py,rr,H*.18),(pz+L*.34,py,rr*.53,H*.10)],1,segments=8,subdivisions=1);pod.shift([side*W*.47,0,0]);merge_mesh(m,pod)
        for z in np.linspace(-L*.28,L*.29,6):
            x=side*(float(np.interp(z,np.asarray(sections)[:,0],np.asarray(sections)[:,2]))+.010)
            m.tube('metal_dark',(x-side*.025,cy+.12,z),(x+side*.035,cy+.12,z),.225,4)
            m.tube('glass',(x+side*.036,cy+.12,z),(x+side*.047,cy+.12,z),.18,4)
        mz=L*.15;pw=float(np.interp(mz,np.asarray(sections)[:,0],np.asarray(sections)[:,2]));x=side*(pw+.018)
        m.box('paint',(x,cy,mz),(.07,H*.23,L*.055));m.box('markings',(x+side*.044,cy,mz),(.016,H*.18,L*.045))
    return m


def heavyLift__mh_47g_chinook(lod=0):
    r,s=helis.model('heavyLift__mh_47g_chinook','MH47G Chinook selected public exterior',lod,'chinook',rotor_diameter=18.288,details={'fuel_sponson_radius':.94,'main_blade_chord':.64,'wheel_radius':.31})
    s.source=MH47;s.representative=LIMIT
    s.features=['two three-blade18.288m tandem rotors, raised aft pylon, no tail rotor','large continuous external fuel sponsons distinct from basic CH47F','long starboard probe, forward weather radome and lower optical housing','four fixed landing-gear legs, front twin tyres/rear single tyres','rear Cargo_Ramp X hinge and four separate selected external MG pintles']
    s.details.update(selected_fit='public2024MH47G exterior and2025PEO/2026factbook family, not every BlockII future modification',principal_family_body_sizes_adopted=True,local_sponsons_probe_housings_estimated=True,front_tyre_pairs=2,aft_tyre_pairs=1)
    if lod:next(p for p in r.parts if p['name']=='Fuselage')['mesh']=chinook_distant_body(s)
    # The quadricycle arrangement has six tyres, not four generic singles.
    for label in ('Left','Right'):
        old=next(p for p in r.parts if p['name']=='Wheel_'+label);p=old['pivot'].copy();remove(r,'Wheel_'+label);rr=.31;half=rr*.29
        for i,dx in enumerate((-.115,.115)):
            q=p+[dx,0,0];m=Mesh();lathe_x(m,[(-half,0,'metal_dark'),(-half,rr*.7,'rubber'),(-half*.65,rr,'rubber'),(half*.65,rr,'rubber'),(half,rr*.7,'metal_dark'),(half,0,'metal_dark')],segments=6 if lod else 20);m.shift(q)
            r.add('Wheel_'+label+'_'+str(i),'Gear_'+label,q,m,'X',radius_metres=rr)
    probe(r,s,lod,(.87,1.35,5.57),(.87,1.35,11.26),.105)
    m=Mesh();shell(m,'paint',[(7.10,2.02,.46,.45),(7.77,2.02,.50,.45),(8.14,2.02,.16,.19)],lod)
    r.add('Nose_Weather_Cover','Fuselage',(0,2.02,7.61),m)
    optic(r,'Forward_Optic','Fuselage',(-.42,1.27,7.41),lod,.27)
    fittings=Mesh()
    for side in (-1,1):
        fittings.box('paint',(side*1.18,3.42,4.38),(.25,.28,.48))
        if not lod:
            fittings.box('paint',(side*1.75,2.59,-3.95),(.21,.30,.36))
            for z in (-4.0,-1.9,.30,2.5):fittings.box('paint',(side*1.90,1.55,z),(.08,.08,.12))
    r.add('Selected_External_Fittings','Fuselage',(0,2,0),fittings)
    positions={}
    for i,(side,label,z) in enumerate(((-1,'L0',5.16),(1,'R0',5.16),(-1,'L1',-4.35),(1,'R1',-4.35))):positions[f'Muzzle_{i}']=pintle(r,label,(side*1.63,1.94,z),lod,i,single=i>1)
    s.details.update(muzzle_count=4,muzzle_positions=positions,external_gun_stations=4)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('helicopter__','gunship__','heavyLift__')) and callable(f)}


def save(slug):
    from validate_aircraft import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    points=np.concatenate([np.asarray(g[0]) for r in (a,b) for p in r.parts if p['name']=='Fuselage' for g in p['mesh'].groups.values() if g[0]])
    lo,hi=points.min(0),points.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=common.ART/'aircraft'/(slug+'.glb');write_glb(path,[a,b],burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P5','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']='Original generate_inventory_additions_35.py using approved shared Python parts. No Blender, imported mesh/pixels, copied insignia, functional weapon/sensor internals or operating logic. Published nominal rotors separated from local body/fittings and hinge estimates; selected historic/maker/current family fits do not certify every serial or readiness. Evidence and orders separately recorded in research/evidence.json.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
