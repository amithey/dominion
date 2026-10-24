"""Japanese inventory additions: original public-exterior meshes, metres, no Blender.

Published overall dimensions are distinguished from estimated exterior details.
The AMV is the observed Japanese M2 demonstration fit, not a claim that every
one of the 82 contracted vehicles has been delivered or has identical stores.
The Type94 is the four-wheel production vehicle, not the later six-wheel study.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
import generate_expansion_armour as tanks
from armour_parts import ArmourSpec,mobility
from generate_p1_tanks import Spec,finish,basket,beam
from vehicle_parts import Mesh,Rig,profile_hull,loft,hollow_muzzle

VE='https://www.mod.go.jp/gsdf/equipment/ve/'
EE='https://www.mod.go.jp/gsdf/equipment/ee/'
AMV='https://www.jsw.co.jp/ja/news/details/20250917172746.html'


def remove(rig,*names):
    """Remove the named geometry and its dependent pivots before reauthoring."""
    gone=set(names)
    for p in rig.parts:
        if p['parent'] in gone:gone.add(p['name'])
    rig.parts[:]=[p for p in rig.parts if p['name'] not in gone]
    for name in gone:rig.pivots.pop(name,None)


def base(slug,name,length,width,roof,wheels,radius,lod,*,scale=1,axles=None,front=True,source=VE,features=(),weapon='',representative=''):
    s=ArmourSpec(slug,name,length,width,roof,'wheeled' if axles else 'tracked',wheels,radius,'japanese_original',weapon,
        list(features),source,track_scale=scale,front_engine=front,approximate=True,axle_z=axles or [],
        representative=representative,details={'inventory_status':'documented_service','public_exterior_estimates':True})
    rig=Rig(lod);m=Mesh();rig.add('Hull',rig.root,(0,0,0),m,origin='ground centre of hull footprint')
    mobility(rig,s,lod)
    return rig,s,m


def hatch(m,x,y,z,w=.6,d=.65,lod=0):
    m.box('paint',(x,y+.025,z),(w,.05,d))
    if not lod:
        for dx in (-w*.30,w*.30):m.box('metal_dark',(x+dx,y+.065,z-d*.38),(.07,.04,.10))
        beam(m,'metal_dark',[x-.10,y+.09,z],[x+.10,y+.09,z],.025)


def lamps(m,width,y,z,lod):
    for side in (-1,1):
        x=side*(width/2-.21);m.box('paint',(x,y,z),(.31,.23,.18));m.box('glass',(x,y,z+.101),(.19,.12,.026))
        if not lod:
            for dx in (-.13,.13):beam(m,'metal_dark',[x+dx,y-.15,z+.14],[x+dx,y+.15,z+.14],.025)
            beam(m,'metal_dark',[x-.13,y+.15,z+.14],[x+.13,y+.15,z+.14],.025)


def gun_station(rig,lod,x,y,z,*,remote=False):
    """One actual gun: yaw bearing, transverse trunnion, and its own marker."""
    n=8 if lod else 16;p=np.array([x,y,z]);m=Mesh();m.tube('metal_dark',p,p+[0,.13,0],.27,n)
    if remote:
        m.box('paint',p+[0,.30,0],(.47,.40,.42));m.box('metal_dark',p+[0,.53,0],(.49,.08,.40))
        m.box('paint',p+[-.31,.45,.02],(.22,.30,.35));m.box('glass',p+[-.31,.45,.205],(.14,.18,.025))
        m.box('paint',p+[.30,.43,-.05],(.25,.35,.42));gy=y+.62
    else:
        m.tube('metal_dark',p+[0,.10,0],p+[0,.31,0],.07,n);gy=y+.36
        for dx in (-.13,.13):m.box('metal_dark',(x+dx,gy-.05,z),(.06,.22,.24))
    rig.add('Turret','Hull',p,m,'Y',mechanism='RWS azimuth bearing' if remote else 'manual pintle azimuth')
    q=np.array([x,gy,z]);g=Mesh();g.box('metal_dark',q+[0,0,.07],(.16,.15,.44))
    g.tube('metal_dark',q+[0,0,.29],q+[0,0,1.03],.027,n)
    hollow_muzzle(g,(x,gy,z+1.03),(x,gy,z+1.10),.030,.012,n)
    g.box('metal_dark',q+[.20,-.10,-.02],(.20,.26,.34))
    beam(g,'metal_dark',q+[-.07,.08,-.16],q+[-.07,.17,-.23],.025)
    rig.add('Gun','Turret',q,g,'X',mechanism='12.7 mm M2 trunnions; +Z bore')
    rig.add('Muzzle','Gun',(x,gy,z+1.10),forward=[0,0,1],caliber_metres=.0127)


def tank__type_90(lod=0):
    s=Spec('type_90','Type 90 main battle tank',7.54,3.40,1.43,2.30,6,.355,.94,-.05,1.87,1.35,9.80,'japanese_type90',
        ['six road wheels, rear sprockets','flat slab turret front, not Type10 modular cheeks','120 mm L44 with fume extractor',
         'deep rear autoloader bustle and stowage basket','manual roof 12.7 mm gun','published 9.8 by 3.4 metres'],VE,
        approximate=True,skirts=4,representative='Retained JGSDF Type90 exterior. Selected vehicles entered reserve storage; not a claim that every historical hull is operational. Hull/turret contours and small fittings estimated from public photographs.')
    b=[(-.40,1.67),(.40,1.67),(1.43,1.54),(1.46,-1.67),(1.18,-2.02),(-1.18,-2.02),(-1.46,-1.67),(-1.43,1.54)]
    t=[(-.40,1.43),(.40,1.43),(1.37,1.35),(1.34,-1.63),(1.13,-1.92),(-1.13,-1.92),(-1.34,-1.63),(-1.37,1.35)]
    def detail(h,m,s,l):
        basket(m,s,l,z=-2.23,width=2.60)
        # Separate broad front armour slabs on either side of the gun opening.
        for side in (-1,1):
            m.box('paint',(side*.92,1.93,1.48),(.84,.53,.20))
            for j in range(3):
                p=np.array([side*1.46,2.04,-.25-j*.18]);m.tube('metal_dark',p,p+[side*.17,.10,.05],.038,6 if l else 10)
        m.box('paint',(-.72,2.33,.70),(.45,.20,.37));m.box('glass',(-.72,2.34,.90),(.30,.11,.028))
        if not l:
            for x in (-.85,.85):
                for z in (-1.65,-1.25):beam(m,'metal_dark',[x,2.32,z],[x,2.42,z+.18],.027)
    rig,s=finish(s,b,t,lod,detail)
    # Replace the generic tank barrel by the L44 layout and a proper open bore.
    remove(rig,'Gun');g=Mesh();q=np.array([0,s.gun_y,s.gun_z]);end=s.overall_length-s.length/2
    g.box('paint',q+[0,0,.12],(.67,.50,.54));g.tube('metal_dark',q+[0,0,.25],[0,s.gun_y,end-.10],.090,8 if lod else 20)
    g.tube('paint',q+[0,0,2.0],q+[0,0,2.47],.142,8 if lod else 20)
    for z in (s.gun_z+.62,s.gun_z+1.75,end-.55):g.tube('paint',(0,s.gun_y,z),(0,s.gun_y,z+.07),.104,8 if lod else 16)
    hollow_muzzle(g,(0,s.gun_y,end-.10),(0,s.gun_y,end),.091,.060,8 if lod else 20)
    rig.add('Gun','Turret',q,g,'X');rig.add('Muzzle','Gun',(0,s.gun_y,end),forward=[0,0,1])
    return rig,s


def apc__type_73(lod=0):
    r,s,m=base('apc__type_73','Type 73 armoured personnel carrier',5.80,2.90,2.21,5,.385,lod,scale=.735,weapon='manual_hmg',
        features=['five large road wheels, front sprockets','short aluminium troop hull and raked bow','manual roof 12.7 mm gun and bow machine gun','large paired rear roof hatches','rear troop door'],
        representative='Production five-wheel Type73 APC, distinct from the longer Type73 artillery tractor. Published body dimensions; hatch, axle and weapon-station fittings estimated from official exterior photograph.')
    remove(r,*[p['name'] for p in r.parts if p['name'].startswith('Roller_')])
    profile_hull(m,'paint',[(2.72,.49,.96),(2.90,1.28,1.16),(1.42,2.21,1.27),(-2.65,2.21,1.27),(-2.90,1.72,1.18),(-2.70,.48,1.01)])
    lamps(m,s.width,1.35,2.76,lod)
    for side in (-1,1):
        m.box('paint',(side*1.32,1.12,-.02),(.18,.10,5.30));m.box('rubber',(side*1.28,.60,-2.71),(.39,.70,.06))
        hatch(m,side*.64,2.22,-1.14,.94,1.40,lod)
        for z in (-.80,-1.45,-2.10):m.box('metal_dark',(side*1.286,1.85,z),(.025,.13,.17))
    hatch(m,-.57,2.22,.97,.56,.62,lod);hatch(m,.60,2.22,.45,.60,.66,lod)
    for x in (-.78,-.53,-.28):m.box('glass',(x,2.28,1.24),(.17,.08,.09))
    if not lod:
        for z in np.linspace(.9,1.65,9):m.box('metal_dark',(.57,2.215,z),(.78,.018,.043))
        for side in (-1,1):m.tube('metal_dark',(side*1.06,1.71,1.93),(side*1.06,1.71,2.17),.055,10)
    m.box('paint',(0,1.33,-2.912),(1.00,1.45,.05))
    # Bow gun follows its own ball mount, not the roof gun's recoil.
    p=np.array([.68,1.57,2.50]);g=Mesh();g.tube('metal_dark',p,p+[0,0,.47],.024,6 if lod else 12)
    r.add('Bow_Gun','Hull',p,g,'Y',mechanism='limited ball-mount yaw; exterior approximation')
    gun_station(r,lod,.58,2.25,.32)
    return r,s


def recoveryVehicle__type_11_arv(lod=0):
    r,s,m=base('recoveryVehicle__type_11_arv','Type 11 armoured recovery vehicle',7.40,3.40,1.83,5,.36,lod,scale=.93,front=False,weapon='manual_hmg',
        features=['five-wheel Type10-derived running gear','forward crane pedestal with boom stowed aft','front spade and recovery winch','asymmetric crew cabin','published 9.1 m overall including equipment'],
        representative='Official production Type11 photograph. Published 9.1 by 3.4 by 2.7 m envelope distinguished from estimated 7.4 m hull and crane geometry; crane internals and hook details illustrative.')
    s.details.update(overall_length_metres=9.1,recovery_parts=['Boom','Spade'])
    profile_hull(m,'paint',[(3.70,.58,1.06),(3.63,1.32,1.33),(2.10,1.83,1.34),(-3.50,1.83,1.34),(-3.70,.65,1.08)])
    for side in (-1,1):m.box('paint',(side*1.62,1.32,-.15),(.12,.59,6.55))
    # Low crew cabin opposite the long crane; 2.7 m is the equipment envelope.
    from vehicle_parts import merge_mesh
    cabin=Mesh();profile_hull(cabin,'paint',[(2.60,1.82,.48),(2.23,2.18,.48),(.20,2.18,.48),(-.08,1.82,.48)])
    merge_mesh(m,cabin,t=(.73,0,0))
    hatch(m,.73,2.19,1.16,.65,.74,lod)
    for x in (.45,.72,1.0):m.box('glass',(x,2.235,1.80),(.19,.08,.10))
    lamps(m,s.width,1.30,3.53,lod)
    if not lod:
        for z in np.linspace(-3.15,-1.65,12):m.box('metal_dark',(.50,1.846,z),(1.25,.025,.045))
        for side in (-1,1):
            for z in (-2.7,-1.9,-1.1):m.box('paint',(side*1.39,1.76,z),(.31,.45,.65))
    bp=np.array([-.91,1.84,1.68]);cr=Mesh();cr.tube('paint',bp-[0,.05,0],bp+[0,.27,0],.40,8 if lod else 18)
    cr.box('paint',bp+[0,.34,0],(.61,.31,.65));r.add('Boom','Hull',bp,cr,'Y',mechanism='forward crane azimuth bearing; stowed aft')
    heel=np.array([-.91,2.25,1.55]);tip=np.array([-.91,2.25,-4.28]);bm=Mesh()
    beam(bm,'paint',heel,tip+[0,0,.80],.48);beam(bm,'metal_dark',tip+[0,0,.95],tip,.27)
    beam(bm,'metal_dark',heel+[.27,-.25,-.10],heel+[.27,-.05,-2.65],.10)
    bm.tube('metal_dark',tip+[-.17,0,0],tip+[.17,0,0],.17,8 if lod else 16)
    r.add('Boom_Lift','Boom',heel,bm,'X',mechanism='transverse crane heel trunnions')
    hk=Mesh();beam(hk,'metal_dark',tip,tip+[0,-.52,0],.030);hk.tube('metal_dark',tip+[0,-.55,-.06],tip+[0,-.55,.09],.10,8)
    r.add('Boom_Hook','Boom_Lift',tip,hk)
    sp=np.array([0,1.02,3.49]);blade=Mesh();profile_hull(blade,'paint',[(4.66,.65,1.48),(4.76,1.25,1.48),(4.56,1.36,1.48),(4.48,.66,1.48)])
    for x in (-.85,.85):beam(blade,'metal_dark',[x,.96,3.50],[x,.98,4.52],.16)
    r.add('Spade','Hull',sp,blade,'X',mechanism='front transverse stabilising-spade hinge')
    winch=Mesh();winch.tube('metal_dark',[-.44,1.16,3.67],[.44,1.16,3.67],.14,8 if lod else 16)
    r.add('Winch','Hull',(0,1.16,3.67),winch,'X')
    gun_station(r,lod,.73,2.19,.43)
    return r,s


def mineClearer__type_92_mbrs(lod=0):
    r,s,m=base('mineClearer__type_92_mbrs','Type 92 minefield breaching rocket system',7.63,3.00,1.67,7,.34,lod,scale=.94,source=EE,
        features=['seven-wheel Type73 artillery-tractor / Type87 supply-vehicle lineage, not the five-wheel APC','twin enclosed line-charge launcher boxes','fixed-azimuth elevating launcher','front crew compartment and low tracked chassis'],
        representative='JGSDF Type92 retained for 2026 training. Published 7.63 by 3.0 by 2.77 m envelope. Launcher casing, running-gear spacing and stowed line-charge containers are public-exterior approximations, without internal mechanism reconstruction.')
    profile_hull(m,'paint',[(3.815,.50,1.00),(3.70,1.22,1.22),(3.36,1.67,1.26),(-3.59,1.67,1.26),(-3.815,.60,1.03)])
    for side in (-1,1):m.box('paint',(side*1.34,1.28,-.08),(.18,.10,7.12))
    hatch(m,-.57,1.69,3.04,.64,.58,lod);hatch(m,.57,1.69,3.04,.64,.58,lod)
    for side in (-1,1):
        m.box('paint',(side*.57,1.73,3.29),(.46,.13,.16))
        m.box('glass',(side*.57,1.78,3.38),(.38,.08,.025))
    lamps(m,s.width,1.12,3.66,lod)
    p=np.array([0,1.79,-2.54]);rack=Mesh();rack.box('metal_dark',(0,1.78,.08),(2.17,.22,5.68))
    mu=[]
    for i,x in enumerate((-.53,.53)):
        rack.box('paint',(x,2.25,-.02),(.99,1.04,5.51))
        # Finite closed transport cover: markers sit at the real forward exits.
        rack.tube('metal_dark',(x,2.24,2.74),(x,2.24,2.79),.29,8 if lod else 18)
        rack.tube('paint',(x,2.24,2.79),(x,2.24,2.82),.25,8 if lod else 18)
        if not lod:
            for z in np.linspace(-2.47,2.40,8):rack.box('paint',(x,2.78,z),(.94,.045,.065))
            for side in (-1,1):
                for z in (-2.30,-.80,.80,2.30):rack.box('metal_dark',(x+side*.50,2.24,z),(.027,.12,.12))
        mu.append([x,2.24,2.825])
    r.add('Launcher','Hull',p,rack,'X',mechanism='rear launcher elevation bearings; vehicle aims azimuth')
    for i,q in enumerate(mu):r.add('Muzzle_'+str(i),'Launcher',q,forward=[0,0,1])
    s.details.update(tube_count=2,muzzle_positions=mu)
    # Exposed supporting elevation actuators are separate from the firing tubes.
    for side in (-1,1):
        a=np.array([side*.92,1.58,-1.65]);b=np.array([side*.92,1.87,.9]);cy=Mesh();beam(cy,'metal_dark',a,b,.14)
        r.add('Launcher_Actuator_'+('L' if side<0 else 'R'),'Hull',a,cy)
    return r,s


def mineLayer__type_94_amphibious(lod=0):
    r,s,m=base('mineLayer__type_94_amphibious','Type 94 amphibious minelaying vehicle',11.80,2.80,2.13,2,.58,lod,
        axles=[-3.31,3.66],source=EE,features=['production four-wheel amphibian, not six-wheel successor prototype','high forward wheelhouse and boat bow',
        'folding longitudinal side pontoons','two stern propellers, not waterjets','open aft rack modules for representative training stores'],
        representative='Published 11.8 m length, 2.8 m road width and 4.0 m afloat width; production vehicle in the 2026 Funaoka programme. Wheelbase, mine-rack load, propeller blades and small deck fittings estimated from official photographs; rack contents do not assert live mine capacity.')
    # The published overall length includes the stern screws. End the boat body
    # ahead of them so the shafts and blades are exposed, not buried in a hull.
    profile_hull(m,'paint',[(5.90,.95,.73),(5.70,1.98,1.24),(4.40,2.13,1.24),(-5.39,2.13,1.24),(-5.45,.79,1.04),(-4.90,.48,.74),(4.65,.48,.62)])
    cabin=Mesh();profile_hull(cabin,'paint',[(5.40,2.12,1.17),(4.55,3.43,1.13),(2.20,3.43,1.13),(1.96,2.12,1.17)])
    from vehicle_parts import merge_mesh
    merge_mesh(m,cabin)
    def front(y):return 5.40-(y-2.12)*.85/1.31+.018
    for x in (-.73,0,.73):
        m.face('glass',[(x-.30,2.60,front(2.60)),(x+.30,2.60,front(2.60)),(x+.30,3.20,front(3.20)),(x-.30,3.20,front(3.20))],[0,.54,.84])
    for side in (-1,1):
        for z in (2.74,3.65):
            def sx(y):return side*(1.17-(y-2.12)*.04/1.31+.018)
            m.face('glass',[(sx(2.65),2.65,z-.34),(sx(2.65),2.65,z+.34),(sx(3.20),3.20,z+.34),(sx(3.20),3.20,z-.34)],[side,.03,0])
        # Stowed narrow floats hinge longitudinally outward about Z.
        p=np.array([side*1.08,2.10,-.50]);pont=Mesh();pont.box('paint',(side*1.26,2.56,-.50),(.25,.85,6.84))
        if not lod:
            for z in (-3.52,-1.62,.62,2.38):pont.box('metal_dark',(side*1.40,2.56,z),(.025,.67,.07))
        r.add('Pontoon_'+('L' if side<0 else 'R'),'Hull',p,pont,'Z',mechanism='longitudinal flotation-pontoon hinge; stowed road configuration')
    lamps(m,s.width,1.82,5.62,lod);hatch(m,0,3.45,3.31,.75,.78,lod)
    if not lod:
        for z in np.linspace(1.96,2.33,5):m.box('metal_dark',(0,3.445,z),(1.38,.025,.035))
    beam(m,'metal_dark',[.91,3.40,2.37],[.91,3.83,2.37],.022)
    rack=Mesh()
    for z in (-4.70,-3.22,-1.64,-.06):
        for x in (-.56,.56):
            for dx in (-.47,.47):
                for dz in (-.63,.63):beam(rack,'metal_dark',[x+dx,2.15,z+dz],[x+dx,3.45,z+dz],.06 if lod else .055)
                beam(rack,'metal_dark',[x+dx,3.45,z-.63],[x+dx,3.45,z+.63],.06)
                beam(rack,'metal_dark',[x+dx,2.20,z-.63],[x+dx,3.38,z+.63],.04)
            rack.box('paint',(x,2.20,z),(1.02,.08,1.37))
            for dz in (-.32,.32):
                for y in (2.57,3.10):rack.tube('paint',(x-.41,y,z+dz),(x+.41,y,z+dz),.20,6 if lod else 12)
    r.add('Dispenser','Hull',(0,2.15,-2.44),rack)
    r.add('Mine_Release_0','Dispenser',(0,2.17,-5.78),forward=[0,0,-1])
    for side in (-1,1):
        p=np.array([side*.72,.97,-5.67]);prop=Mesh();n=8 if lod else 16
        m.tube('paint',p+[0,.28,.34],p+[0,0,.19],.13,n)
        prop.tube('metal_dark',p+[0,0,.30],p-[0,0,.20],.08,n)
        for angle in np.linspace(0,2*math.pi,4,endpoint=False):
            u=np.array([math.cos(angle),math.sin(angle),0]);v=np.array([-u[1],u[0],0])
            a=p+u*.10;b=p+u*.35+v*.07
            prop.face('metal_dark',[a-v*.035,b-v*.065,b+v*.065,a+v*.035],[0,0,1])
            prop.face('metal_dark',[a-v*.035+[0,0,-.025],a+v*.035+[0,0,-.025],b+v*.065+[0,0,-.025],b-v*.065+[0,0,-.025]],[0,0,-1])
        r.add('Propeller_'+('L' if side<0 else 'R'),'Hull',p,prop,'Z',mechanism='production stern screw shaft; illustrative blade geometry')
    return r,s


def apc__amv_xp_japan(lod=0):
    r,s,m=base('apc__amv_xp_japan','Patria AMV XP, Japanese 12.7 mm demonstration fit',8.40,2.80,2.38,4,.59,lod,
        axles=[-2.08,-.58,.92,2.42],source=AMV,weapon='remote_m2',features=['eight wheels on four independent axles','Japanese-production applique side modules',
        'long sharply raked nose and periscope driver position','Kongsberg remote station with observed M2 fit','rear troop ramp'],
        representative='First Japanese delivery September2025; 82 firm orders across 2024–2026 are not 82 deliveries. M2 fit follows firsthand June2026 firing photographs, rather than treating factory protective covers as ballistic shields. XP family dimensions and axle positions approximate the national exterior.')
    s.details.update(inventory_status='deliveries_started_firm_orders_remaining',ordered_total_documented=82,ordered_total_is_not_delivered_total=True,weapon_fit='observed June2026 M2 demonstration, not uniform fleet assertion')
    profile_hull(m,'paint',[(4.20,.86,.92),(4.10,1.40,1.27),(2.64,2.38,1.34),(-3.80,2.38,1.34),(-4.20,1.71,1.17),(-3.95,.49,.88),(3.60,.49,.87)])
    for side in (-1,1):
        for z,w in ((-2.89,1.57),(-1.15,1.65),(.65,1.70)):
            m.box('paint',(side*1.37,1.94,z),(.09,.72,w))
            if not lod:
                for zz in (z-w*.39,z+w*.39):m.box('metal_dark',(side*1.426,2.14,zz),(.025,.045,.045))
        m.box('paint',(side*1.31,1.32,3.22),(.23,.12,1.19))
        for z in s.axle_z:m.box('rubber',(side*1.21,.70,z-.69),(.31,.58,.055))
        if not lod:
            for z in (-3.67,-2.05,-.45,1.15):beam(m,'metal_dark',[side*1.21,2.42,z],[side*1.21,2.48,z+.23],.025)
    lamps(m,s.width,1.56,3.86,lod)
    hatch(m,-.55,2.40,2.10,.64,.72,lod);hatch(m,.48,2.40,1.35,.65,.73,lod)
    for x in (-.80,-.57,-.34):
        m.box('paint',(x,2.48,2.44),(.20,.14,.13));m.box('glass',(x,2.48,2.516),(.14,.08,.024))
    hatch(m,-.56,2.40,-2.46,.89,1.04,lod);hatch(m,.56,2.40,-2.46,.89,1.04,lod)
    ramp=Mesh();ramp.box('paint',(0,1.48,-4.169),(1.57,1.66,.055))
    if not lod:
        for y in np.linspace(.84,1.94,7):ramp.box('metal_dark',(0,y,-4.207),(1.34,.025,.025))
    r.add('Ramp','Hull',(0,.66,-4.17),ramp,'X',mechanism='aft lower ramp hinge')
    for side in (-1,1):
        mirror=Mesh();beam(mirror,'metal_dark',[side*1.16,2.26,3.02],[side*1.60,2.57,3.12],.034)
        mirror.box('metal_dark',(side*1.60,2.61,3.12),(.15,.30,.10));mirror.box('glass',(side*1.60,2.61,3.058),(.11,.23,.025))
        r.add('Mirror_'+('L' if side<0 else 'R'),'Hull',(side*1.16,2.26,3.02),mirror)
    gun_station(r,lod,0,2.41,-.48,remote=True)
    return r,s


BUILDERS={f.__name__:f for f in (tank__type_90,apc__type_73,recoveryVehicle__type_11_arv,mineClearer__type_92_mbrs,mineLayer__type_94_amphibious,apc__amv_xp_japan)}


def save(slug):
    saver=tanks if slug.startswith('tank__') else common
    saver.BUILDERS[slug]=BUILDERS[slug];e=saver.save(slug)
    e['notes']+=' Japanese evidence-led original generator: generate_inventory_additions_12.py. Public exterior estimates and national delivery/contract distinctions in research/evidence.json.'
    evidence=json.loads((Path(__file__).parent/'research/evidence.json').read_text(encoding='utf-8'))
    refs={'tank__type_90':['JP-TANK90-PHOTO','JP-TANK-STATUS26'],
          'apc__type_73':['JP-APC73-PHOTO','JP-TRACKED-MOVEMENT26'],
          'recoveryVehicle__type_11_arv':['JP-ARV11-PHOTO','JP-SUPPORT26'],
          'mineClearer__type_92_mbrs':['JP-TYPE92-MAKER','JP-TYPE92-TRAIN26'],
          'mineLayer__type_94_amphibious':['JP-TYPE94-MAKER','JP-TYPE94-26','JP-MINELAYER94-PHOTO'],
          'apc__amv_xp_japan':['JP-AMV-FIRING-PHOTO26','JP-AMV-ORDERS26']}
    e['sources'] += [{'url':evidence['sources'][k]['url'],'use':evidence['sources'][k]['supports']} for k in refs[slug]]
    if slug.startswith('recoveryVehicle'):e['recovery_parts']=['Boom','Spade']
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
