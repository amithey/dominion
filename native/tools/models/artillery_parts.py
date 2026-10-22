"""Original open artillery mechanisms, truck carriers and launcher hardware.

No downloaded meshes. World-authored metre geometry; empty real hinges. The
approved shared mesh writer supplies white material roles and hidden states.
"""
import math
import numpy as np
from dataclasses import replace
from vehicle_parts import Mesh,Rig,loft,hollow_muzzle,merge_mesh,rotation
from armour_parts import ArmourSpec,build,road_tyre
from generate_p1_tanks import beam

def artillery_barrel(rig,parent,p,tip,cal,lod,brake=True):
    p=np.array(p);m=Mesh();n=6 if lod else 12;length=tip-p[2]
    m.box('metal_dark',p+[0,0,-.28],(.40,.40,.78))
    m.tube('paint',p+[0,0,-.45],p+[0,0,1.0],cal*.95,n)
    for side in (-1,1):m.tube('paint',p+[side*.19,.20,-.43],p+[side*.19,.20,.82],cal*.40,n)
    m.tube('metal_dark',p+[0,0,.80],p+[0,0,length-.37],cal*.64,n)
    hollow_muzzle(m,p+[0,0,length-.37],p+[0,0,length],cal*.65,cal*.5,n)
    if brake:
        for z in (tip-.30,tip-.08):hollow_muzzle(m,[p[0],p[1],z-.035],[p[0],p[1],z+.035],cal*1.04,cal*.5,n)
        for side in (-1,1):m.box('metal_dark',(p[0]+side*cal*.90,p[1],tip-.19),(.05,.15,.30))
    rig.add('Gun',parent,p,m,'X',elevation_degrees=[-5,70],positive_elevation_rotation_sign=-1,recoil_axis=[0,0,-1])
    rig.add('Muzzle','Gun',(p[0],p[1],tip),forward='+Z')

def towed(slug,name,lod,kind,source,approximate=False,representative=''):
    dims={'d30':(5.40,3.40,1.43,.50,.122,3.72),'fh70':(8.30,4.10,1.70,.61,.155,5.87),
          'l118':(6.10,3.0,1.35,.45,.105,3.62),'m777':(7.30,3.70,1.52,.52,.155,4.84)}
    L,W,H,r,cal,tip=dims[kind]
    s=ArmourSpec(slug,name,L,W,H,'towed',1,r,kind,'towed',
        ['Towed '+kind.upper()+' in supported travel-height display pose','one main wheel axle with separate X pivots',
         'separate splayed trail hinges','open recoil cradle and '+str(round(cal*1000))+' mm barrel',
         'third central trail' if kind=='d30' else 'two split trails'],source,approximate=approximate,
         representative=representative,axle_z=[0])
    rig=Rig(lod);m=Mesh();n=6 if lod else 12
    m.tube('metal_dark',(-W/2+.19,r,0),(W/2-.19,r,0),.105,n)
    m.tube('paint',(0,.28,-.25),(0,H-.18,-.25),.24,n)
    for side in (-1,1):
        beam(m,'paint',(side*.37,.48,-.30),(side*.39,H,.12),.16)
        m.tube('metal_dark',(side*.30,H,.12),(side*.49,H,.12),.14,n)
    if kind=='d30':
        # Two sloping halves with the gun opening between them.
        for side in (-1,1):
            shield=Mesh();shield.box('paint',(side*.60,H-.10,.30),(.82,.94,.055),rotation([1,0,0],-.18));merge_mesh(m,shield)
    elif kind=='l118':
        for side in (-1,1):m.box('paint',(side*.40,H-.25,.28),(.48,.55,.045))
    elif kind=='fh70':
        m.box('paint',(-.80,.94,-.68),(.71,.61,.91))
        m.box('metal_dark',(-.80,1.26,-.68),(.61,.035,.70))
        for side in (-1,1):beam(m,'paint',(side*.75,.64,-.71),(side*1.28,.26,-1.13),.12)
    else:
        # M777 has open triangular titanium load paths, rather than a gun shield.
        for side in (-1,1):
            beam(m,'paint',(side*.32,H-.12,.07),(side*1.08,.42,-1.13),.10)
            beam(m,'paint',(side*1.08,.42,-1.13),(side*.44,.45,.67),.10)
    for side in (-1,1):m.box('markings',(side*.44,H-.26,-.12),(.017,.20,.28))
    rig.add('Carriage',rig.root,(0,0,0),m)
    for side,label in ((-1,'L'),(1,'R')):
        wp=np.array([side*(W/2-.19),r,0]);rig.add('Wheel_'+label+'0','Carriage',wp,merge_mesh(Mesh(),road_tyre(s,lod,side),t=wp),'X')
        hinge=np.array([side*.38,.49,-.30]);end=np.array([side*(W/2-.30),.16,-L*.47]);trail=Mesh()
        beam(trail,'paint',hinge,end,.17 if kind!='m777' else .12)
        if kind=='m777':
            beam(trail,'paint',hinge+[side*.16,0,0],end+[side*.12,0,0],.075)
            for t in (.28,.58,.85):
                q=hinge*(1-t)+end*t;beam(trail,'paint',q,q+[side*.15,0,0],.06)
        trail.box('paint',end+[0,-.06,0],(.47,.20,.42))
        rig.add('Trail_'+label,'Carriage',hinge,trail,'Y')
    if kind=='d30':
        third=Mesh();beam(third,'paint',(0,.38,-.25),(0,.16,2.13),.16);third.box('paint',(0,.10,2.13),(.44,.20,.39))
        rig.add('Trail_C','Carriage',(0,.38,-.25),third,'Y')
    artillery_barrel(rig,'Carriage',(0,H,.12),tip,cal,lod,brake=kind!='l118')
    # Handwheels, layer's seat and telescope attach to the stationary carriage.
    controls=Mesh();controls.box('paint',(-.53,.77,-.46),(.43,.09,.40));beam(controls,'metal_dark',(-.53,.77,-.46),(-.53,H-.16,-.04),.055)
    controls.tube('metal_dark',(-.62,H-.12,-.04),(-.70,H-.12,-.04),.16,n)
    controls.box('paint',(-.42,H+.10,.14),(.12,.19,.22));controls.box('glass',(-.42,H+.10,.261),(.09,.10,.018))
    rig.add('Fire_Controls','Carriage',(-.53,H-.12,-.04),controls)
    return rig,s

def truck_howitzer(slug,name,lod,L,W,H,axles,r,cal,tip,source,family='caesar',approximate=False,representative=''):
    s=ArmourSpec(slug,name,L,W,H,'wheeled',len(axles),r,'truck','',
      [family+' truck carrier',str(len(axles)*2)+' driven wheels with real axle pivots',
       'open rear gun cradle with Y traverse and X trunnion','long '+str(round(cal*1000))+' mm barrel',
       'hinged rear anchoring spade and supported work platform'],source,approximate=approximate,representative=representative,
       axle_z=list(axles),details={'cab':2.02,'hood':1.26 if family in ('caesar','archer') else 0.})
    rig,s=build(s,lod);s.weapon='truckhowitzer';bed=r*2.05+.18;z=-L*.27
    mount=Mesh();mount.tube('metal_dark',(0,bed,z),(0,bed+.35,z),.52,8 if lod else 20)
    for side in (-1,1):
        mount.box('paint',(side*.40,bed+.72,z),(.17,.94,.86))
        beam(mount,'paint',(side*.40,bed+.28,z-.38),(side*.40,H+.17,z+.18),.15)
    if family=='archer':mount.box('paint',(0,H-.12,z-.44),(2.18,1.35,2.15))
    rig.add('Turret','Hull',(0,bed+.27,z),mount,'Y',yaw_degrees=[-30,30])
    gy=H+.16;artillery_barrel(rig,'Turret',(0,gy,z+.14),tip,cal,lod)
    for side,label in ((-1,'L'),(1,'R')):
        platform=Mesh();platform.box('metal_dark',(side*(W/2-.30),bed,-L*.28),(.52,.12,L*.44))
        if not lod:
            for zz in np.linspace(-L*.46,-.75,7):platform.box('metal_dark',(side*(W/2-.30),bed+.073,zz),(.49,.022,.04))
        rig.add('Platform_'+label,'Hull',(side*(W/2-.30),bed,-L*.28),platform)
    spade=Mesh();p=np.array([0,bed,-L/2+.20]);spade.box('paint',p+[0,.40,-.24],(W*.78,.73,.16))
    for side in (-1,1):beam(spade,'paint',p+[side*.56,0,0],p+[side*.56,.44,-.21],.13)
    rig.add('Spade','Hull',p,spade,'X')
    # The gun travel rest has a physical base on the forward chassis.
    rest=Mesh();rz=L*.20;rest.box('paint',(0,bed+.12,rz),(.34,.24,.39))
    beam(rest,'paint',(0,bed+.20,rz),(0,gy-.18,rz),.08)
    rest.box('metal_dark',(0,gy-.12,rz),(.37,.15,.16));rig.add('Gun_Travel_Rest','Hull',(0,bed,rz),rest,'X')
    return rig,s
