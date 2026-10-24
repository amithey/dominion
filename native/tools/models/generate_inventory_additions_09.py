"""Original British ships and MCM craft, using public external references.

Metres, keel origin, +Z bow; no downloaded models, textures or Blender.
Local deck arrangements and unpublished hull sections are estimates. Future
frigates represent the published contracted design, not operational vessels.
"""
from pathlib import Path
import argparse, json, math
import numpy as np
import generate_inventory_additions_05 as saver
from generate_p7_ships import combatant
from ship_parts import block, beam
from vehicle_parts import Mesh, Rig, loft, profile_hull, hollow_muzzle

RN='https://www.royalnavy.mod.uk/'

def remove(rig,*names):
    rig.parts=[p for p in rig.parts if p['name'] not in names]
    for name in names:rig.pivots.pop(name,None)

def replace_mesh(rig,name,mesh):
    for p in rig.parts:
        if p['name']==name:p['mesh']=mesh;return
    raise KeyError(name)

def asFrigate__type_26_uk(lod=0):
    rig,s=combatant('asFrigate__type_26_uk','Type 26 City (UK)',lod,(149.9,20.8,6.0,5.3),
        'https://des.mod.uk/what-we-do/navy-procurement-support/type-26-frigate/',
        ['149.9m British City-class hull, not Australian Hunter or Canadian River',
         '127mm Mk45 forward gun','24 Mk41 cells ahead of bridge',
         '48 CAMM tube closures in twelve four-tube groups split fore and aft',
         'high angular forward Artisan mast','two integrated exhaust blocks',
         'wide mission bay with side doors','single large helicopter hangar',
         'two Phalanx and two 30mm remote mounts','stern Sonar2087 handling aperture'],
        houses=[(0,17.8,17.4,36.,7.8,0,.79),(0,-29.0,17.8,30.,6.4,0,.94),
                (0,-3.5,17.7,13.,5.6,0,.97)],
        funnels=[(0,-9.5,6.6,8.4,6.5,5.6),(0,-24.0,5.7,7.0,6.,6.4)],
        masts=[(17.2,25.2,'panel',3.9),(-24.0,17.4,'bar',2.6)],
        guns=[(0,57.0,127,7.9),(-8.1,-2.,30,2.1,5.65),(8.1,-2.,30,2.1,5.65)],
        vls=[(39.,6,4,.86,0)],canisters=[],ciws=[(-7.2,15.,7.9),(7.2,-29.,6.45)],
        hangar_z=-44.1,hangar_doors=1,bow_sheer=.95)
    D=s.draft+s.freeboard
    # Wide faceted tower, rather than a borrowed SAMPSON/APAR radar fit.
    m=Mesh();profile_hull(m,'paint',[(21.5,D+7.6,2.9),(20.2,D+22.9,1.45),
        (14.7,D+22.9,1.45),(12.4,D+7.6,2.9)])
    m.box('paint',(0,D+23.9,17.2),(2.35,2.45,3.5))
    for yy in (D+14.,D+20.1):beam(m,[-4.0,yy,17.2],[4.,yy,17.2],.12,lod,'paint')
    replace_mesh(rig,'Mast_0',m)
    # Each visible quartet has four individual soft-launch tube covers.
    m=Mesh()
    for z,y in ((48.0,D+.16),(-33.2,D+6.57)):
        for row in range(3):
            for col in range(2):
                cx=(col-.5)*1.45;cz=z+(row-1)*1.45
                m.box('paint',(cx,y,cz),(1.25,.15,1.25))
                if not lod:
                    for dx in (-.29,.29):
                        for dz in (-.29,.29):
                            m.tube('metal_dark',(cx+dx,y+.08,cz+dz),(cx+dx,y+.15,cz+dz),.24,16)
    rig.add('Sea_Ceptor_Quartets','Hull',(0,D,48.),m,physical_tube_count=48,quartet_count=12)
    m=Mesh()
    for side in (-1,1):
        m.box('metal_dark',(side*8.9,D+2.2,-3.5),(.05,3.5,9.8))
        for z in (-7.8,-3.5,.8):m.box('paint',(side*8.94,D+2.2,z),(.06,3.5,.11))
        m.box('paint',(side*7.2,D+6.40,-29.),(3.2,.15,4.8))
    m.box('metal_dark',(0,D-1.30,-73.15),(5.0,2.1,.06))
    for side in (-1,1):m.box('paint',(side*2.70,D-1.2,-73.20),(.35,2.5,.20))
    rig.add('Mission_Bay_And_2087_Ports','Hull',(0,D,-3.5),m)
    s.representative='Eight firm British ships still building/fitting out in September2026. Published149.9m/20.8m, local deck and underwater profiles estimated. Future completed baseline; not proof of fitted/qualified armament on Glasgow today. CAMM quartet arrangement interpreted from public equipment description.'
    s.details['inventory_status']='firm_order_under_construction'
    return rig,s

def asFrigate__type_31_uk(lod=0):
    rig,s=combatant('asFrigate__type_31_uk','Type 31 Inspiration (UK initial baseline)',lod,(138.7,19.8,4.8,5.5),
        RN+'equipment/ships/inspiration-class',
        ['138.7m British Inspiration hull','one 57mm Mk3 and two 40mm Mk4 guns',
         'raised forward 40mm and aft hangar-roof 40mm','two tall raked funnels',
         'NS110 rotating forward radar, secondary navigation mast',
         'initial twelve Sea Ceptor launch closures amidships',
         'side mission-bay openings','single helicopter hangar',
         'reserved future Mk41 insertion area, no invented installed Mk41 count'],
        houses=[(0,19.,16.6,26.,8.2,0,.80),(0,-30.,16.8,25.,6.4,0,.92),
                (0,-3.8,17.9,20.,4.0,0,.97),(0,34.0,9.0,8.,3.,0,.82)],
        funnels=[(0,-7.7,6.9,8.5,8.7,4.),(0,-22.0,6.4,7.7,8.0,6.4)],
        masts=[(17.,24.6,'panel',2.8),(-7.5,19.0,'bar',2.8)],
        guns=[(0,48.0,57,3.75),(0,34.,40,2.65,3.05),(0,-34.,40,2.65,6.45,True)],
        vls=[(1.,3,4,.68,4.05)],canisters=[],ciws=[],hangar_z=-42.5,hangar_doors=1,
        bow_sheer=.85)
    D=s.draft+s.freeboard;m=Mesh()
    profile_hull(m,'paint',[(21.0,D+7.8,2.7),(19.0,D+24.5,1.15),
        (15.0,D+24.5,1.15),(12.6,D+7.8,2.7)])
    for yy in (D+17.,D+20.5):beam(m,[-3.4,yy,17.],[3.4,yy,17.],.10,lod,'paint')
    replace_mesh(rig,'Mast_0',m)
    m=Mesh()
    for side in (-1,1):
        for z in (-8.8,2.0):
            m.box('metal_dark',(side*8.99,D+2.0,z),(.06,3.1,6.0))
            m.box('paint',(side*9.04,D+.42,z),(.08,.18,6.3))
        for z in (-26.,8.):
            m.tube('paint',(side*5.85,D+7.9,z),(side*5.85,D+8.6,z),.40,6 if lod else 16,r_top=.16)
    rig.add('Mission_Doors_And_SATCOM','Hull',(0,D,0),m)
    # The modernisation space remains a clean deck; a future procurement
    # intention must not be turned into an invented installed missile load.
    s.representative='Five British ships contracted and under construction. Public initial exterior with12CAMM closures,57/40/40guns; manufacturer confirms40mm despite operator50mm typo. Mk41/NSM upgrade intentions recorded separately; final tube count/installation not invented. Beam/draft and local placement estimated from public Arrowhead lineage.'
    s.details['inventory_status']='firm_order_under_construction_initial_baseline'
    return rig,s

def landingShip__bay_class(lod=0):
    rig,s=combatant('landingShip__bay_class','Bay-class RFA amphibious support',lod,(176.6,26.4,5.8,7.2),
        RN+'equipment/ships/bay-class',
        ['176.6m landing ship dock','high box-shaped forward accommodation and bridge wings',
         'large aft helicopter deck without permanent hangar','two amidships cargo cranes',
         'stern well-deck closure Ramp with X hinge','side vehicle door',
         'steerable electric propulsion pods','two Phalanx fit represented',
         'base amphibious exterior, not assumed completed Lyme Bay 2026 MCM conversion'],
        houses=[(0,35.,23.,34.,13.8,0,.96),(0,40.5,22.8,15.0,3.0,13.8,.97)],
        funnels=[(-8.7,14.,3.6,5.5,10.0,0),(8.7,14.,3.6,5.5,10.0,0)],
        masts=[(32.,24.0,'bar',4.2),(32.,21.,'bar',3.1)],
        guns=[],vls=[],canisters=[],ciws=[(-10.6,50.,1.6),(10.6,-70.,1.0)],
        hangar=False,flight_deck=True,landing=True,ramp_height=7.05,
        cranes=[(-9.5,-1.,6.4,15.5),(9.5,-1.,6.4,15.5)],
        bow_sheer=.75,hull_profile=[(-.5,.93),(-.43,1),(-.2,1),(.15,1),(.30,.95),(.40,.70),(.48,.20),(.5,.008)])
    D=s.draft+s.freeboard
    # One actual mast supports both named navigation heads.
    for part in rig.parts:
        if part['name']=='Mast_0':
            m=Mesh();profile_hull(m,'paint',[(33.1,D+16.7,.8),(32.6,D+24.,.28),(31.4,D+24.,.28),(30.9,D+16.7,.8)])
            for yy in (D+20.,D+23.):beam(m,[-4.9,yy,32.],[4.9,yy,32.],.10,lod)
            part['mesh']=m
        elif part['name']=='Mast_1':
            m=Mesh();m.box('paint',(0,D+20.9,32.),(3.3,.15,.25));part['mesh']=m
    m=Mesh()
    # Stern bulkhead frames a closed, hinged well-dock gate.
    for side in (-1,1):
        m.box('paint',(side*9.45,D-3.6,-86.4),(6.5,7.2,2.6))
        for z in np.linspace(-74.,9.,6 if lod else 18):
            m.box('metal_dark',(side*13.1,D-1.65,z),(.04,1.1,2.8))
        for z in np.linspace(23.,46.,4 if lod else 9):
            m.box('glass',(side*11.25,D+8.1,z),(.04,.55,.72))
    m.box('paint',(0,D-.4,-86.5),(25.2,.8,3.0))
    m.box('metal_dark',(-13.21,D-3.8,-10.),(.04,4.2,6.7))
    rig.add('Well_Dock_Facade_And_Vehicle_Door','Hull',(0,D,-86.4),m)
    for side,label in ((-1,'L'),(1,'R')):
        p=np.array([side*7.2,2.2,-63.0]);m=Mesh()
        m.box('metal_dark',p+[0,1.8,0],(.65,3.5,1.0))
        m.tube('paint',p-[0,0,2.6],p+[0,0,2.6],1.15,8 if lod else 24,r_top=.62)
        rig.add('Azimuth_Pod_'+label,'Hull',p,m,'Y')
        q=p+[0,0,2.7];m=Mesh();m.tube('metal_dark',q-[0,0,.10],q+[0,0,.12],.26,8 if lod else 16)
        for a in np.linspace(0,math.tau,4,endpoint=False):
            pts=[]
            for z in (q[2]-.065,q[2]+.065):
                for r,t in ((.23,a-.18),(1.02,a+.10),(1.02,a+.47),(.23,a+.30)):
                    pts.append([q[0]+r*math.cos(t),q[1]+r*math.sin(t),z])
            m.solid('metal_dark',pts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        rig.add('Propeller_'+label,'Azimuth_Pod_'+label,q,m,'Z')
    # A second helicopter spot; no permanent aviation hangar is invented.
    m=Mesh()
    for z in (-35.,-66.):
        for side in (-1,1):m.box('markings',(side*2.0,D+.04,z),(.20,.03,5.0))
        m.box('markings',(0,D+.04,z),(4.2,.03,.20))
    rig.add('Aft_Landing_Spots','Hull',(0,D,-35.),m)
    s.representative='Current British RFA base amphibious exterior. Published176.6m;26.4mbeam/5.8mdraft from class public dimensions, local fittings estimated. Closed well gate, no fictional carrier hangar. Exact Phalanx and boat load vary per deployment; LymeBay2026MCMconversion not assumed universal.'
    s.details['inventory_status']='in_service_representative_amphibious_fit'
    return rig,s

def small_hull(slug,name,lod,L,B,draft,freeboard,source,features,house):
    return combatant(slug,name,lod,(L,B,draft,freeboard),source,features,
        houses=[house],funnels=[],masts=[],guns=[],vls=[],canisters=[],ciws=[],
        hangar=False,flight_deck=False,unmanned=True,bow_sheer=.18,
        hull_profile=[(-.5,.88),(-.4,.99),(-.15,1),(.14,1),(.30,.84),(.43,.49),(.5,.012)])

def cabin_windows(rig,s,lod,z,w,l,h,base=0,taper=.75):
    D=s.draft+s.freeboard;m=Mesh();y=D+base+h*.64
    low=y-h*.185;high=y+h*.185
    def scale(yy):return 1-(1-taper)*(yy-D-base)/h
    for side in (-1,1):
        for zz in np.linspace(z-l*.24,z+l*.24,2 if lod else 3):
            pts=[[side*(w*scale(yy)/2+.009),yy,zzz] for yy,zzz in
                 ((low,zz-l*.0725),(low,zz+l*.0725),(high,zz+l*.0725),(high,zz-l*.0725))]
            m.face('glass',pts,[side,0,0])
    for x in (-w*.18,w*.18):
        pts=[[xx,yy,z+l*scale(yy)/2+.009] for xx,yy in
             ((x-w*.135,low),(x+w*.135,low),(x+w*.135,high),(x-w*.135,high))]
        m.face('glass',pts,[0,0,1])
    rig.add('Cabin_Windows','Hull',(0,y,z),m)

def small_mast(rig,s,lod,z,base,height):
    D=s.draft+s.freeboard;p=np.array([0,D+base,z]);q=p+[0,height,-.32];m=Mesh()
    beam(m,p,q,.075,lod,'paint')
    for dy,w in ((.45,.65),(height*.58,.80)):
        beam(m,p+[0,dy,-.15],p+[w,dy,-.15],.045,lod)
    rig.add('Mast_0','Hull',p,m)
    r=p+[0,height*.55,-.18];m=Mesh();m.tube('paint',r,r+[0,.18,0],.22,6 if lod else 20)
    rig.add('Radar','Mast_0',r,m,'Y')
    r=q+[0,.10,0];m=Mesh();m.box('metal_dark',r,(.24,.22,.24));m.box('glass',r+[0,0,.125],(.14,.13,.018))
    rig.add('Sensor_EO','Mast_0',r,m,'Y')
    s.details['masts']=[(z,base+height*.55,'small',.44)]

def fender(rig,s,lod,halfwidth):
    D=s.draft+s.freeboard;m=Mesh();pts=[]
    for z,f in [(-.49,.88),(-.4,.99),(-.1,1),(.16,.98),(.32,.81),(.44,.43),(.495,.025)]:
        pts.append((halfwidth*f,D-.14,z*s.length))
    for side in (-1,1):
        seq=[np.array([side*x,y,z]) for x,y,z in pts]
        for a,b in zip(seq,seq[1:]):beam(m,a,b,.11,lod,'rubber')
    rig.add('Solid_Fender','Hull',(0,D-.14,0),m)

def gunboat__cutlass_class(lod=0):
    rig,s=small_hull('gunboat__cutlass_class','Cutlass-class HPB1900',lod,19.,5.30,.95,1.35,
        RN+'equipment/ships/cutlass-class',
        ['19m overall,17.5m hull','5.30m overall beam,4.80m hull','long angular enclosed cabin',
         'three manual general-purpose machineguns','three stern waterjets','raked aft mast with EO',
         'solid fender collar','no optional remote heavy weapon or fictional30mm turret'],
        (0,.5,3.7,8.0,2.0,0,.79))
    # Keep the manufacturer hull beam distinct from the fender-inclusive beam.
    s.details['hull_beam']=4.8
    # Initial hull must be rebuilt because the footprint above includes fenders.
    from ship_parts import hull
    temp=Rig(lod);hull(temp,s,lod);replace_mesh(rig,'Hull',temp.parts[0]['mesh'])
    cabin_windows(rig,s,lod,.5,3.7,8.,2.,taper=.79)
    small_mast(rig,s,lod,-2.4,1.98,2.55);fender(rig,s,lod,2.54)
    D=s.draft+s.freeboard;m=Mesh()
    for x in (-1.20,0,1.20):
        m.tube('metal_dark',(x,.61,-8.67),(x,.61,-9.20),.24,8 if lod else 20)
        m.box('paint',(x,.60,-9.12),(.60,.50,.18))
    for side in (-1,1):
        for z in (-7.7,-5.9,5.8,7.2):beam(m,[side*1.92,D,z],[side*1.92,D+.75,z],.032,lod)
        for a,b in ((-7.7,-5.9),(5.8,7.2)):beam(m,[side*1.92,D+.75,a],[side*1.92,D+.75,b],.032,lod)
        for z in (-4.0,1.0):m.box('markings',(side*2.39,D-.43,z),(.025,.24,.70))
    rig.add('Triple_Jets_And_Deck_Rails','Hull',(0,.61,-8.67),m)
    for i,(x,z,aft) in enumerate(((0,6.2,False),(-1.65,-6.65,True),(1.65,-6.65,True))):
        p=np.array([x,D,z]);m=Mesh();m.tube('metal_dark',p,p+[0,1.0,0],.055,6 if lod else 12)
        m.box('paint',p+[0,.82,-.15],(.38,.55,.06))
        turret='Turret_Main' if i==0 else 'Turret_'+str(i);rig.add(turret,'Hull',p,m,'Y')
        q=p+[0,1.05,.1];m=Mesh();sgn=-1 if aft else 1
        m.box('metal_dark',q,(.12,.13,.42));hollow_muzzle(m,q+[0,0,sgn*.14],q+[0,0,sgn*.78],.015,.00381,6 if lod else 12)
        gun='Gun' if i==0 else 'Gun_'+str(i);rig.add(gun,turret,q,m,'X')
        rig.add('Muzzle' if i==0 else 'Muzzle_'+str(i),gun,q+[0,0,sgn*.78],**({'frame_rotation':[0,1,0,0]} if aft else {}))
    s.details['manual_gun_count']=3;s.details['inventory_status']='in_service'
    s.representative='Delivered Gibraltar three-GPMG representative exterior. RN page0.5mm wording is an apparent unit typo, not copied. No optional heavyRWS. Manufacturer19moverall includes stern fittings and bow overhang; detailed private hull sections estimated.'
    return rig,s

def seaDrone__mmcm_ariadne(lod=0):
    rig,s=small_hull('seaDrone__mmcm_ariadne','Ariadne / Adventure MMCM USV',lod,12.,3.5,.80,.80,
        RN+'news/2026/april/03/20260402-adventure-delivered',
        ['12m minehunting USV','low forward pilothouse with emergency crew windows',
         'raked sensor mast','open aft mission deck','hinged stern sonar handling A-frame',
         'SAMDIS towed sonar on inclined rails','twin winch drums','no weapons or explosive bow payload'],
        (0,2.5,2.45,3.5,1.05,0,.73))
    D=s.draft+s.freeboard;cabin_windows(rig,s,lod,2.5,2.45,3.5,1.05,taper=.73)
    # This mast is stepped on the deck behind the sloping cabin. A roof-
    # height base at this Z would leave its lower end hanging in free space.
    small_mast(rig,s,lod,1.0,0.,3.65);fender(rig,s,lod,1.65)
    p=np.array([0,D,-3.8]);m=Mesh()
    for side in (-1,1):
        beam(m,p+[side*1.18,0,0],p+[side*.95,1.95,-.18],.085,lod)
        beam(m,p+[side*.95,1.95,-.18],p+[side*.55,1.95,-.18],.065,lod)
    beam(m,p+[-.95,1.95,-.18],p+[.95,1.95,-.18],.075,lod)
    rig.add('Sonar_LARS','Hull',p,m,'X')
    m=Mesh()
    for side in (-1,1):
        for y,z in ((D+.20,-2.3),(D+.62,-4.8)):
            m.box('paint',(side*.57,y,z),(.20,.20,.20))
        beam(m,[side*.57,D+.20,-2.3],[side*.57,D+.62,-4.8],.055,lod,'paint')
        q=np.array([side*.95,D+.78,-2.9])
        m.tube('metal_dark',q-[.26,0,0],q+[.26,0,0],.42,8 if lod else 24)
        for dx in (-.29,.29):m.tube('paint',q+[dx-.025,0,0],q+[dx+.025,0,0],.48,8 if lod else 24)
        m.box('metal_dark',(side*1.47,D+.60,-4.20),(.04,.75,.42))
    rig.add('Winches_And_Launch_Rails','Hull',(0,D,-3.),m)
    # Stowed sonar shape is visible in the operator's delivered-boat gallery.
    m=Mesh();a=np.array([0,D+.55,-2.25]);b=np.array([0,D+.89,-5.12])
    m.tube('paint',a,b,.23,8 if lod else 24,r_top=.15)
    for side in (-1,1):
        m.solid('paint',[[side*x,y,z] for x,y,z in [(.16,D+.78,-4.45),(.90,D+.78,-4.75),(.90,D+.84,-5.0),(.16,D+.84,-4.95)]],[(0,1,2,3)])
    rig.add('SAMDIS_Stowed','Hull',(0,D+.55,-2.25),m)
    rig.add('Tow_Point','Hull',(0,D+.4,-5.65))
    s.details['inventory_status']='first_system_in_service_second_delivered2026'
    s.representative='Delivered Ariadne/Adventure primary-system exterior,12m length. Width/draft and private contours estimated from public MMCM prototype lineage. April2026Navy gallery inspected for low cabin, A-frame, split winches and stowed sonar. Not older Halcyon demonstration boat or11mARCIMS.'
    return rig,s

def seaDrone__arcims_sweep(lod=0):
    rig,s=small_hull('seaDrone__arcims_sweep','ARCIMS combined-influence SWEEP host',lod,11.,3.4,.60,.90,
        RN+'news/2025/july/04/20250704-new-sweep-mine-hunting-capability-for-the-rn',
        ['11m Atlas modular MCM hull','short forward angular pilothouse',
         'forward-raked sensor mast','open modular aft payload deck','power-generation module and stern tow winch',
         'magnetic/acoustic sweep host, no gun or explosive attack bow',
         'separate from Thales12mAriadne MMCM hull'],
        (0,2.0,2.5,3.4,1.35,0,.71))
    D=s.draft+s.freeboard;cabin_windows(rig,s,lod,2.,2.5,3.4,1.35,taper=.71)
    small_mast(rig,s,lod,.9,1.35,2.8);fender(rig,s,lod,1.58)
    m=Mesh();block(m,'paint',0,D,-.95,1.85,1.25,2.2,.97)
    for side in (-1,1):
        if not lod:
            for z in np.linspace(-1.75,-.20,15):m.box('metal_dark',(side*.928,D+.77,z),(.018,.55,.055))
        m.box('paint',(side*.95,D+.12,-.95),(.20,.22,2.7))
    m.box('metal_dark',(0,D+1.28,-.95),(1.42,.04,1.65))
    m.tube('metal_dark',(.55,D+.85,-2.0),(.55,D+1.5,-2.0),.08,6 if lod else 16)
    rig.add('Sweep_Power_Generation_Module','Hull',(0,D,-.95),m)
    p=np.array([0,D+.45,-3.55]);m=Mesh();m.tube('metal_dark',p-[.6,0,0],p+[.6,0,0],.34,8 if lod else 24)
    for side in (-1,1):
        m.tube('paint',p+[side*.65-.03,0,0],p+[side*.65+.03,0,0],.45,8 if lod else 24)
        m.box('paint',(side*.68,D+.18,-3.55),(.15,.36,.75))
        m.box('paint',(side*1.45,D+.30,-3.65),(.17,.60,1.9))
    rig.add('Sweep_Tow_Winch','Hull',p,m,'X')
    rig.add('Tow_Point','Hull',(0,D+.3,-5.15))
    s.details['inventory_status']='accepted2025_training_and_evaluation_before_deployment'
    s.representative='ThreeSWEEP systems accepted2025; hostboat shown without towed auxiliarycoilboats, which are separate offboard craft. Manufacturer bare-hull photo inspected for short angular cabin and tall raked mast.11m length;3.4mbeam/draft and installed power-module dimensions are public-exterior estimates, not detailed engineering dimensions.'
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('asFrigate__','landingShip__','gunboat__','seaDrone__')) and callable(f)}

def save(slug):
    # All ships use the same saved-buffer checks as the preceding batch.
    def checked(lod):
        rig,s=BUILDERS[slug](lod)
        for p in rig.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return rig,s
    saver.BUILDERS[slug]=checked
    e=saver.save(slug);e['notes']=e['notes'].replace('generate_inventory_additions_05.py','generate_inventory_additions_09.py')
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
