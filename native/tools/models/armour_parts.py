"""Original P2 exterior construction. Metres, +Z forward, no Blender/assets.

Family components describe actual shared construction, not a tank reskin.
Wheels and track shader geometry reuse the approved vehicle_parts contract.
All moving assemblies contain an empty hinge and world-authored child meshes.
"""
from dataclasses import dataclass, field, asdict
import math
import numpy as np
from vehicle_parts import Mesh, Rig, loft, profile_hull, lathe_x, hollow_muzzle, merge_mesh, rotation, ROLES
from generate_p1_tanks import Spec as TankSpec, running_gear, beam, transformed, make_wreck as tank_wreck


@dataclass
class ArmourSpec:
    slug:str; name:str; length:float; width:float; roof:float
    mobility:str; wheels:int; wheel_radius:float; family:str; weapon:str
    features:list; source:str
    track_scale:float=1.; front_engine:bool=True; approximate:bool=False
    representative:str=''; axle_z:list=field(default_factory=list)
    turret_z:float=0.; turret_x:float=0.; equipment:str=''
    # Body profile: bow roof starts at this fraction of half-length.
    bow:float=.57; shoulder:float=.78; details:dict=field(default_factory=dict)


def gearbox_spec(s):
    return TankSpec(s.slug,s.name,s.length,s.width,s.roof,s.roof,s.wheels,s.wheel_radius,
                    s.track_scale,0,0,0,s.length,'carrier',s.features,s.source,
                    front_engine=s.front_engine,skirts=0)


def road_tyre(s,lod,side):
    m=Mesh();r=s.wheel_radius;w=.18 if s.width<2.6 else .23;n=8 if lod else 16
    # Rounded shoulder and recessed steel hub, actual radius in metres.
    profile=[(-w,0,'paint'),(-w,r*.53,'rubber'),(-w*.82,r*.93,'rubber'),
             (-w*.54,r,'rubber'),(w*.54,r,'rubber'),(w*.82,r*.93,'rubber'),
             (w,r*.53,'paint'),(w,0,'paint')]
    if lod:profile=[(-w,0,'rubber'),(-w,r,'rubber'),(w,r,'paint'),(w,0,'paint')]
    lathe_x(m,profile,segments=n)
    if lod:m.tube('paint',(side*(w+.006),0,0),(side*(w+.065),0,0),r*.47,6)
    if not lod:
        m.tube('paint',(side*(w+.006),0,0),(side*(w+.045),0,0),r*.47,12)
        for t in np.linspace(0,math.tau,8,endpoint=False):
            m.tube('metal_dark',(side*(w+.045),r*.31*math.cos(t),r*.31*math.sin(t)),
                   (side*(w+.065),r*.31*math.cos(t),r*.31*math.sin(t)),.018,6)
        for t in np.linspace(0,math.tau,20,endpoint=False):
            # Actual blocks beyond the carcass; all UV projections stay metre-scale.
            m.box('rubber',(0,(r-.015)*math.cos(t),(r-.015)*math.sin(t)),(w*1.5,.025,.09),rotation((1,0,0),t))
    return m


def mobility(rig,s,lod):
    if s.mobility=='tracked':
        running_gear(rig,gearbox_spec(s),lod);return
    zs=s.axle_z or np.linspace(-s.length*.32,s.length*.32,s.wheels).tolist()
    x=s.width/2-.19
    for side,label in ((-1,'L'),(1,'R')):
        for i,z in enumerate(zs):
            p=np.array([side*x,s.wheel_radius,z]);m=road_tyre(s,lod,side)
            rig.add(f'Wheel_{label}{i}','Hull',p,merge_mesh(Mesh(),m,t=p),'X',
                    radius_metres=s.wheel_radius,steering_axle=(i==len(zs)-1))


def shell(m,s,lod):
    """Sloped boat/APC hull, with separately modelled deck, fenders and ramp."""
    h=s.length/2;w=s.width/2;roof=s.roof
    half=w-.46 if s.mobility=='tracked' else w-.10
    low=.38 if s.mobility=='tracked' else s.wheel_radius*.84
    if s.equipment in ('engineer_layer','skorpion'):
        # M548 is an open cargo carrier with a forward cab, not a troop box.
        m.box('paint',(0,.89,-.10),(s.width-.65,.38,s.length-.16))
        profile_hull(m,'paint',[(h-.05,.80,half),(h-.05,roof-.35,half),
            (h-.27,roof,half*.94),(h-1.65,roof,half*.94),(h-1.65,.80,half)])
        for side in (-1,1):
            m.box('glass',(side*.42,roof-.63,h-.019),(.66,.43,.035))
            m.box('paint',(side*(w-.32),1.18*s.track_scale,0),(.64,.10,s.length-.26))
        return
    if s.family=='recovery':
        deck=roof*.59
        profile_hull(m,'paint',[(h-.18,low,half*.73),(h,deck*.80,half*.88),
            (h*.65,deck,half),(-h+.12,deck,half),(-h,deck*.72,half),(-h+.22,low,half*.74)])
        cabin=Mesh();cx=-.12 if s.equipment!='aframe' else 0
        profile_hull(cabin,'paint',[(h*.76,deck,half*.89),(h*.69,roof-.38,half*.89),
            (h*.46,roof,half*.80),(-.52,roof,half*.80),(-.65,deck,half*.89)])
        merge_mesh(m,cabin,t=[cx,0,0])
        for side in (-1,1):m.box('paint',(side*(w-.32),1.18*s.track_scale,0),(.64,.10,s.length-.26))
        m.box('paint',(-.48,roof+.04,.38),(.58,.08,.62))
        m.box('glass',(-.48,roof+.10,.55),(.31,.045,.10))
        if not lod:
            for z in np.linspace(-h+.35,-h*.38,7):m.box('metal_dark',(0,deck+.025,z),(1.32,.035,.055))
        return
    cabin_end=-h+.12;rear_roof=roof
    profile=[(h-.18,low,half*.73),(h,roof*.66,half*.88),
        (h*s.bow,roof,half*s.shoulder),(cabin_end,roof,half*.91)]
    profile.extend([(-h,min(roof*.72,rear_roof),half),(-h+.22,low,half*.74)])
    profile_hull(m,'paint',profile)
    # High-sided compartment for the characteristic square M113/Saad/ACV roof.
    if s.family in ('m113','acv','saad'):
        m.box('paint',(0,(roof+low)/2,-.27),(2*half,roof-low,s.length-.83))
    if s.family=='boxer':
        # Removable mission module, high rear roof and pronounced sloping nose.
        m.box('paint',(0,roof-.26,-h*.29),(s.width-.30,.57,s.length*.56))
        for side in (-1,1):
            m.box('metal_dark',(side*(w-.12),roof-.59,-h*.42),(.055,.045,s.length*.50))
            m.box('paint',(side*(w-.22),roof+.06,-h*.78),(.10,.15,.16))
    # Independent mudguards over every road tyre, never a rectangular slab
    # through the wheels. Tracked carriers use narrow full length sponsons.
    if s.mobility=='tracked':
        for side in (-1,1):m.box('paint',(side*(w-.32),1.18*s.track_scale,0),(.64,.10,s.length-.26))
    else:
        for side in (-1,1):
            for z in s.axle_z:
                m.box('paint',(side*(w-.20),s.wheel_radius*1.94,z),(.48,.09,s.wheel_radius*2.08))
    # Rear entry ramp, hinges, handle, tail lights. Front hull lights and tow eyes.
    m.box('paint',(0,roof*.60,-h-.018),(half*1.30,roof*.58,.065))
    m.box('metal_dark',(0,roof*.34,-h-.060),(half*1.27,.035,.055))
    for side in (-1,1):
        m.box('glass',(side*half*.83,roof*.60,-h-.025),(.13,.16,.07))
        m.box('paint',(side*half*.78,roof*.58,h-.03),(.24,.16,.18))
        m.box('glass',(side*half*.78,roof*.58,h+.066),(.16,.10,.025))
        m.tube('metal_dark',(side*half*.70,low+.10,h-.10),(side*half*.70,low+.10,h+.04),.045,6)
    m.box('paint',(-.40,roof+.055,h*.33),(.55,.09,.63))
    m.box('glass',(-.40,roof+.12,h*.33+.20),(.36,.055,.09))
    if not lod:
        engine_z=h*.44 if s.front_engine else -h*.62
        for z in np.linspace(engine_z-.42,engine_z+.42,8):m.box('metal_dark',(.50 if s.front_engine else 0,roof+.025,z),(.65 if s.front_engine else 1.15,.032,.045))
        for side in (-1,1):
            for z in np.linspace(-h+.55,h*.25,4):
                m.box('metal_dark',(side*(half*.95+.012),roof*.73,z),(.025,.035,.12))


def windows(m,s,lod):
    h=s.length/2;w=s.width/2;roof=s.roof
    # Windowed driving compartment is a real family distinction (BTR, Anoa,
    # Guarani, Pars), absent from periscope-only Stryker/Boxer/BMP/Namer.
    if s.family not in ('btr','btr4','anoa','guarani','pars','fahd'):return
    y=roof-.25
    t=(roof-y)/(roof-roof*.66)
    z=h*s.bow+(h-h*s.bow)*t+.035
    for side in (-1,1):
        m.box('paint',(side*.43,y,z),(.77,.47,.08))
        m.box('glass',(side*.43,y,z+.046),(.63,.32,.025))
        m.box('glass',(side*(w*.82),y,z-.35),(.035,.28,.38))
        if not lod:beam(m,'metal_dark',(side*.43-.16,y-.14,z+.07),(side*.43+.10,y+.10,z+.07),.018)


def recognition(m,s,lod):
    """Vehicle-specific exterior fittings; selected by each explicit builder."""
    h=s.length/2;w=s.width/2;r=s.roof;f=s.details
    if f.get('swim'):
        # Paired waterjet housings on amphibious families, not on dry carriers.
        centers=[0] if s.family=='btr' else [-w*.65,w*.65]
        for xx in centers:
            m.tube('paint',(xx,.72,-h+.05),(xx,.72,-h-.14),.25 if s.family=='btr' else .18,6 if lod else 10)
        m.box('paint',(0,r*.60,h+.025),(s.width*.72,.24,.055))
    if f.get('ports') and not lod:
        for side in (-1,1):
            for z in np.linspace(-h+.65,.25,f['ports']):
                m.box('glass',(side*(w-.19),r-.35,z),(.035,.075,.16))
                m.tube('metal_dark',(side*(w-.18),r-.57,z),(side*(w-.12),r-.57,z),.045,8)
    if f.get('skirts'):
        for side in (-1,1):
            for z in np.linspace(-h+.50,h-.65,5):m.box('paint',(side*(w-.025),r*.63,z),(.065,.48,(s.length-1.1)/5-.055))
    if f.get('era'):
        count=6 if not lod else 3;start=-h+.50;end=h-.55;cell=(end-start)/count
        for side in (-1,1):
            for z in start+(np.arange(count)+.5)*cell:
                m.box('paint',(side*(w-.06),r*.73,z),(.16,.42,cell-.08))
    if f.get('bow_guns'):
        for side in (-1,1):m.tube('metal_dark',(side*.90,r*.52,h-.1),(side*.90,r*.52,h+.23),.026,6)
    if f.get('side_door'):
        for side in (-1,1):m.box('paint',(side*(w-.07),r*.55,-.15),(.06,r*.39,.74))
    if f.get('spare'):
        dummy=ArmourSpec('', '',1,s.width,1,'wheeled',2,s.wheel_radius,s.family,'',[],s.source)
        tyre=road_tyre(dummy,lod,1)
        m.box('metal_dark',(w*.45,r*.57,-h),(.22,.22,.55))
        merge_mesh(m,tyre,R=rotation((0,1,0),math.pi/2),t=[w*.45,r*.57,-h-.28])
    if f.get('m113_fuel'):
        for side in (-1,1):m.box('paint',(side*w*.76,1.13,-h+.02),(.33,.94,.34))
    if f.get('strakes'):
        for side in (-1,1):
            for y in (r*.48,r*.61,r*.74):m.box('paint',(side*(w-.035),y,-.15),(.06,.11,s.length*.64))
    if f.get('rear_doors'):
        for side in (-1,1):m.box('paint',(side*.47,r*.53,-h-.065),(.86,r*.66,.08))
    if f.get('propellers'):
        for side in (-1,1):
            m.tube('metal_dark',(side*.85,.66,-h-.08),(side*.85,.66,-h-.22),.19,6)
    if f.get('storage'):
        store_y=r*.59+.10 if s.family=='recovery' else r+.08
        for side in (-1,1):m.box('paint',(side*(w-(.64 if s.mobility=='tracked' else .40)),store_y,-h*.61),(.30,.24,s.length*.25))


WEAPONS={
    # width, height, depth, barrel visible length, bore, turret style
    'rws':(.62,.32,.72,.83,.0127,'rws'),
    'ring':(1.0,.36,.86,1.05,.0127,'ring'),
    'kpvt':(.78,.44,.85,1.12,.0145,'cone'),
    'twin_kpv':(1.05,.49,1.05,1.12,.0145,'cone'),
    'bmp1':(1.32,.46,1.40,1.05,.073,'cone'),
    'bmp2':(1.50,.66,1.65,2.20,.030,'cone'),
    'bmp3':(1.75,.52,1.78,1.90,.100,'flat'),
    'parus':(1.68,.79,1.70,2.15,.030,'remote'),
    'bppu':(1.12,.48,1.15,2.12,.030,'flat'),
    'zbl30':(1.65,.72,1.90,2.15,.030,'wedge'),
    'lance':(2.12,.76,2.35,2.10,.030,'wedge'),
    'ut30':(1.82,.65,1.95,2.05,.030,'remote'),
    'bradley':(1.73,.83,1.94,1.72,.025,'wedge'),
    'k21':(1.86,.66,2.00,2.20,.040,'wedge'),
    'puma':(1.72,.60,2.12,2.02,.030,'remote'),
    'warrior':(1.57,.80,1.80,1.53,.030,'wedge'),
    'type89':(1.76,.77,2.02,2.03,.035,'wedge'),
    'zbd':(1.80,.56,1.92,1.92,.100,'flat'),
    'acv':(1.06,.65,1.18,1.58,.025,'wedge'),
}


def weapon(rig,s,lod):
    if not s.weapon:return
    tw,th,td,barrel,bore,style=WEAPONS[s.weapon];x=s.turret_x;z=s.turret_z;y=s.details.get('weapon_base',s.roof+.11)
    m=Mesh();n=6 if lod else 12
    m.tube('metal_dark',(x,y-.08,z),(x,y,z),tw*.37,n)
    if style=='ring':
        hollow_muzzle(m,[x,y,z],[x,y+.10,z],.50,.43,n)
        for side in (-1,1):m.box('metal_dark',(x+side*.40,y+.19,z+.27),(.065,.29,.10))
    elif style in ('cone','flat'):
        m.tube('paint',(x,y,z),(x,y+th,z-.08),tw*.50,n,r_top=tw*(.30 if style=='cone' else .43))
        m.box('paint',(x,y+th-.03,z-.22),(tw*.58,.08,td*.63))
    elif style=='rws':
        m.tube('paint',(x,y,z),(x,y+.18,z),.17,n)
        m.box('paint',(x,y+.25,z),(.36,.30,.42))
        m.box('paint',(x-.28,y+.28,z),(.22,.33,.40))
    else:
        # Deliberately distinct asymmetric turret footprints and cheek slopes.
        b=[(-tw*.28,td*.53),(tw*.28,td*.53),(tw*.51,td*.18),(tw*.48,-td*.40),
           (tw*.29,-td*.55),(-tw*.35,-td*.55),(-tw*.50,-td*.32),(-tw*.48,td*.20)]
        top=[(a*(.76 if style=='wedge' else .88),c*.87) for a,c in b]
        loft(m,'paint',[[(x+a,y,z+c) for a,c in b],[(x+a,y+th,z+c) for a,c in top]])
    if style!='ring':
        m.box('paint',(x+tw*.29,y+th+.04,z-.10),(.27,.13,.33))
        m.box('glass',(x+tw*.29,y+th+.045,z+.078),(.20,.08,.027))
    if style not in ('rws','ring'):
        m.tube('paint',(x-tw*.19,y+th,z-.29),(x-tw*.19,y+th+.065,z-.29),tw*.18,n)
    # Mark carrier belongs to the traversing assembly, not the hull.
    for side in (-1,1):m.box('markings',(x+side*(tw*.51+.012),y+th*.47,z-.20),(.018,th*.31,td*.26))
    if s.weapon in ('bradley','type89','puma','lance','ut30','parus','k21','zbl30'):
        # Bradley twin TOW box; Type89 bilateral tubes; modern IFVs ATGM pack.
        for side in ((-1,1) if s.weapon=='type89' else (-1,)):
            m.box('paint',(x+side*(tw*.55+.12),y+th*.65,z-.10),(.32,.38,1.16))
            if not lod:
                for yy in (-.095,.095):m.tube('metal_dark',(x+side*(tw*.55+.12),y+th*.65+yy,z+.46),(x+side*(tw*.55+.12),y+th*.65+yy,z+.49),.073,8)
    rig.add('Turret','Hull',(x,y,z),m,'Y',weapon=s.weapon)
    gy=y+th*.55;gz=z+td*.32;p=np.array([x,gy,gz]);g=Mesh()
    g.box('paint',p,(tw*.31,th*.40,.36))
    end=gz+barrel
    hollow_muzzle(g,[x,gy,gz+.15],[x,gy,end],max(bore*.67,.025),bore*.5,n)
    if s.weapon in ('bmp3','zbd'):
        hollow_muzzle(g,[x+.19,gy,gz+.15],[x+.19,gy,end+.24],.032,.015,n)
    if s.weapon=='twin_kpv':
        hollow_muzzle(g,[x+.18,gy,gz+.15],[x+.18,gy,end],.026,.00725,n)
    if s.weapon=='bmp1':g.box('metal_dark',(x,gy+.24,gz+.34),(.18,.04,.73))
    rig.add('Gun','Turret',p,g,'X',bore_metres=bore)
    rig.add('Muzzle','Gun',(x,gy,end),forward='+Z')
    if not lod:
        for side in (-1,1):
            smoke=Mesh()
            for j in range(3):smoke.tube('metal_dark',(x+side*tw*.40,y+th*.65,z-.20-j*.105),(x+side*(tw*.40+.09),y+th*.65+.10,z-.12-j*.105),.032,6)
            rig.add('Smoke_Launcher_'+('L' if side<0 else 'R'),'Turret',(x+side*tw*.40,y+th*.65,z-.20),smoke)


def truck_body(m,s,lod):
    """Cab, exposed chassis rails, glazing, mirrors, steps and equipment deck."""
    h=s.length/2;w=s.width/2;r=s.roof;cab=s.details.get('cab',2.1);front=h-.10
    for side in (-1,1):m.box('metal_dark',(side*w*.57,s.wheel_radius*.9,-.12),(.15,.23,s.length-.50))
    m.box('paint',(0,s.wheel_radius*1.75,-cab*.30),(s.width-.12,.16,s.length-cab*.45))
    # Flat-front cab-over vs bonneted Elbit/Type2 truck configurations.
    hood=s.details.get('hood',0.)
    cz=front-cab*.5-hood
    profile_hull(m,'paint',[(front-hood,s.wheel_radius*1.65,w*.91),(front-hood,r-.48,w*.95),
        (front-hood-.25,r,w*.89),(front-cab-hood,r,w*.89),(front-cab-hood,s.wheel_radius*1.65,w*.91)])
    if hood:m.box('paint',(0,s.wheel_radius*1.84,front-hood*.5),(s.width*.81,.63,hood))
    m.box('metal_dark',(0,s.wheel_radius*1.54,h-.01),(s.width*.70,.44,.045))
    for side in (-1,1):
        m.box('glass',(side*w*.43,r-.80,front-hood+.026),(w*.70,.57,.04))
        m.box('glass',(side*(w*.94+.005),r-.52,cz),(.035,.52,cab*.46))
        m.box('paint',(side*w*.95,r-1.0,cz),(.04,.47,cab*.62))
        m.box('metal_dark',(side*(w+.08),r-.48,front-cab*.53-hood),(.13,.27,.13))
        m.box('metal_dark',(side*(w-.04),s.wheel_radius*1.2,cz),(.22,.12,cab*.68))
        m.box('glass',(side*w*.72,s.wheel_radius*1.60,h+.025),(.26,.15,.05))
    if not lod:
        for yy in np.linspace(s.wheel_radius*1.4,s.wheel_radius*1.7,5):m.box('paint',(0,yy,h+.02),(s.width*.65,.025,.035))
    # Guards and brake drums belong to the rigid chassis, wheels to axle pivots.
    for side in (-1,1):
        for z in s.axle_z:m.box('paint',(side*(w-.18),s.wheel_radius*1.97,z),(.48,.09,s.wheel_radius*2.03))


def scout_body(m,s,lod):
    h=s.length/2;w=s.width/2;r=s.roof;f=s.family
    if f=='fennek':
        profile_hull(m,'paint',[(h-.20,.42,w*.77),(h,r*.60,w*.90),(h*.44,r,w*.73),
             (-h*.72,r,w*.80),(-h,r*.57,w*.96),(-h+.15,.42,w*.77)])
        for side in (-1,1):
            angle=-math.atan((h-h*.44)/(r*.40));yy=r-.21
            zz=h*.44+(r-yy)*(h-h*.44)/(r*.40)
            m.box('glass',(side*.44,yy+.02,zz+.025),(.63,.43,.035),rotation((1,0,0),angle))
            m.box('glass',(side*w*.82,r-.23,h*.12),(.04,.36,.62))
    else:
        # Bonneted 4x4 armoured protected patrol vehicle; Jackal is open.
        hood=.35*s.length if f in ('humvee','jackal') else .25*s.length
        rear=-h+.14;front=h-hood
        m.box('paint',(0,.87,0),(s.width-.25,.40,s.length-.25))
        m.box('paint',(0,1.22,h-hood*.50),(s.width*.86,.45,hood))
        if f=='jackal':
            m.box('paint',(0,1.22,-.48),(s.width-.22,.45,s.length*.55))
            # Seats, visible floor and true open roll cage, not opaque glazing.
            for x in (-.48,.48):
                for z in (-1.,.30):
                    m.box('rubber',(x,1.37,z),(.42,.14,.42));m.box('rubber',(x,1.66,z-.22),(.42,.55,.10))
            for z in (-h*.65,.28):
                for x in (-w*.83,w*.83):beam(m,'metal_dark',(x,1.30,z),(x,r,z),.065)
                beam(m,'metal_dark',(-w*.83,r,z),(w*.83,r,z),.065)
            for x in (-w*.83,w*.83):beam(m,'metal_dark',(x,r,-h*.65),(x,r,.28),.065)
        else:
            profile_hull(m,'paint',[(front,.93,w*.91),(front,r-.33,w*.87),(front-.22,r,w*.75),
                 (rear,r,w*.77),(rear,.93,w*.91)])
            for side in (-1,1):
                m.box('glass',(side*.43,r-.145,front-.089),(.65,.30,.035),rotation((1,0,0),-math.atan(.22/.33)))
                for z in np.linspace(rear+.55,front-.57,2 if s.length<6 else 3):
                    m.box('paint',(side*w*.90,r-.63,z),(.04,.82,.74))
                    m.box('glass',(side*(w*.90+.025),r-.34,z),(.025,.33,.55))
                    m.box('metal_dark',(side*(w*.90+.045),r-.65,z-.21),(.035,.035,.14))
    for side in (-1,1):
        for z in s.axle_z:m.box('paint',(side*(w-.16),s.wheel_radius*1.96,z),(.46,.10,s.wheel_radius*2.12))
        m.box('glass',(side*w*.65,1.16,h+.018),(.20,.14,.05))
    m.box('metal_dark',(0,1.03,h+.028),(s.width*.55,.28,.06))
    if not lod:
        for x in np.linspace(-w*.42,w*.42,7):m.box('paint',(x,1.03,h+.065),(.045,.27,.035))


def blade(rig,s,lod,name='Spade'):
    h=s.length/2;w=s.width/2;p=np.array([0,.90,h-.70]);m=Mesh()
    for side in (-1,1):beam(m,'metal_dark',(side*.68,.90,h-.70),(side*.68,.50,h+.28),.13)
    # Angled dozer spade, closed wedge with a sharpened but finite lower edge.
    profile_hull(m,'paint',[(h+.40,.20,w*.94),(h+.51,.80,w*.94),(h+.33,.96,w*.94),(h+.21,.26,w*.94)])
    m.box('metal_dark',(0,.22,h+.39),(s.width*.94,.11,.12))
    rig.add(name,'Hull',p,m,'X',hinge='transverse blade lift')


def recovery(rig,s,lod):
    h=s.length/2;r=s.roof;w=s.width/2;n=6 if lod else 10
    blade(rig,s,lod);m=Mesh()
    if s.equipment=='aframe':
        # M88 twin A-frame legs hinge about the actual transverse deck axle.
        p=np.array([0,r-.25,.65]);end=np.array([0,r+1.48,h-.36])
        for side in (-1,1):
            beam(m,'paint',[side*.92,p[1],p[2]],end,.18)
            beam(m,'metal_dark',[side*.72,r-.50,-.48],[side*.31,r+.83,h-.92],.085)
        m.tube('metal_dark',end+[-.17,0,0],end+[.17,0,0],.18,n)
        beam(m,'metal_dark',end,[0,r-.30,-h*.56],.018)
        rig.add('Boom','Hull',p,m,'X',hinge='A-frame heel bearings')
    else:
        # Slewing crane carried on a starboard turntable; articulated lift arm.
        x=w*.56;p=np.array([x,r-.08,-.28]);m.tube('paint',p-[0,.12,0],p+[0,.23,0],.32,n)
        rig.add('Boom','Hull',p,m,'Y',hinge='crane turntable')
        m=Mesh();a=p+[0,.27,0];b=np.array([x,r+.54,-h+.38])
        beam(m,'paint',a,b,.31);beam(m,'metal_dark',a+[0,-.12,-.18],b+[0,-.17,.40],.10)
        m.tube('metal_dark',b+[0,-.10,0],b+[0,-.38,0],.048,n)
        rig.add('Boom_Lift','Boom',a,m,'X',hinge='crane luffing trunnions')
    deck=Mesh()
    for side in (-1,1):deck.box('paint',(side*w*.57,r*.59+.17,-h*.62),(.50,.38,s.length*.19))
    deck.tube('metal_dark',(-.45,r+.10,.14),(.45,r+.10,.14),.18,n)
    if not lod:
        for x in np.linspace(-.40,.40,7):deck.tube('metal_dark',(x,r+.10,.14),(x+.022,r+.10,.14),.196,n)
        for side in (-1,1):beam(deck,'metal_dark',(side*w*.72,r+.25,h*.33),(side*w*.72,r+.25,-h*.55),.035)
    rig.add('Winch_Deck','Hull',(0,r,0),deck)


def engineering(rig,s,lod):
    h=s.length/2;r=s.roof;w=s.width/2;n=6 if lod else 10;kind=s.equipment
    if kind in ('breacher','generic_clear'):blade(rig,s,lod,'Mine_Plough')
    if kind=='breacher':
        m=Mesh();m.box('paint',(0,r+.27,-.30),(2.15,.60,2.25))
        m.box('paint',(0,r+.50,1.0),(1.40,.33,.60));rig.add('Crew_Cupola','Hull',(0,r,0),m)
        m=Mesh()
        for side in (-1,1):m.box('paint',(side*.58,r+.66,-1.15),(.94,.46,1.30))
        rig.add('Line_Charge_Launcher','Hull',(0,r+.35,-1.15),m,'X')
    elif kind=='flail':
        p=np.array([0,1.10,h-.65]);m=Mesh();end=np.array([0,1.22,h+1.16])
        for side in (-1,1):beam(m,'paint',[side*w*.77,*p[1:]],[side*w*.77,*end[1:]],.24)
        rig.add('Flail_Arm','Hull',p,m,'X');m=Mesh()
        m.tube('metal_dark',end+[-w,0,0],end+[w,0,0],.22,n)
        for x in np.linspace(-w*.9,w*.9,8 if lod else 20):
            for angle in (-math.pi/2,math.pi/5):
                a=np.array([x,end[1]+.20*math.sin(angle),end[2]+.20*math.cos(angle)])
                b=a+[0,.55*math.sin(angle),.55*math.cos(angle)]
                beam(m,'metal_dark',a,b,.035);m.box('metal_dark',b,(.10,.10,.13))
        rig.add('Flail','Flail_Arm',end,m,'X')
    elif kind=='ur77':
        m=Mesh();m.box('paint',(0,r+.26,-.18),(1.84,.62,2.78))
        for side in (-1,1):m.tube('paint',(side*.51,r+.61,-1.54),(side*.51,r+.61,.84),.17,n)
        rig.add('Line_Charge_Launcher','Hull',(0,r+.10,-1.25),m,'X')
    if kind=='trojan':
        recovery(rig,s,lod)
    if kind in ('gmz','engineer_layer','volcano','skorpion','zemledelie'):
        m=Mesh()
        if kind=='gmz':
            m.box('paint',(0,r+.11,-.50),(s.width-.85,.36,s.length*.57))
            for side in (-1,1):
                beam(m,'metal_dark',(side*.61,r-.12,-h+.05),(side*.61,.42,-h-.78),.12)
                m.box('paint',(side*.61,.48,-h-.73),(.36,.17,.54))
            rig.add('Mine_Chutes','Hull',(0,r-.12,-h+.05),m,'X')
        elif kind=='zemledelie':
            # Two 25-tube modules (50 tubes), carried on the 8x8 KamAZ chassis.
            for side in (-1,1):
                m.box('paint',(side*.60,r-.10,-1.30),(1.13,1.12,3.30))
                for ix in range(5 if not lod else 2):
                    for iy in range(5 if not lod else 2):
                        m.tube('metal_dark',(side*.60-.43+ix*(.215 if not lod else .86),r-.53+iy*(.215 if not lod else .86),.365),
                               (side*.60-.43+ix*(.215 if not lod else .86),r-.53+iy*(.215 if not lod else .86),.39),.075,n)
            rig.add('Launcher','Hull',(0,r-.58,-2.60),m,'X')
        else:
            count=6 if kind=='skorpion' else 4
            for side in (-1,1):
                for j,z in enumerate(np.linspace(-h+.50,.65,count//2)):
                    # Distinct angled dispenser banks, not a missile turret.
                    box=Mesh();box.box('paint',(0,0,0),(.59,.86,.75))
                    merge_mesh(m,box,R=rotation((0,0,1),side*.28),t=[side*.79,r+.28,z])
                    if not lod:
                        for yy in (-.22,0,.22):m.tube('metal_dark',(side*1.08,r+.28+yy,z-.24),(side*1.13,r+.28+yy,z-.24),.071,6)
            rig.add('Mine_Dispensers','Hull',(0,r,0),m)


def ew_equipment(rig,s,lod):
    h=s.length/2;r=s.roof;n=8 if lod else 12;m=Mesh();z=-h*.35
    m.box('paint',(0,r-.26,z),(s.width-.28,1.65,s.length*.46))
    if not lod:
        for side in (-1,1):
            for yy in np.linspace(r-.77,r-.30,6):m.box('metal_dark',(side*(s.width/2-.125),yy,z-.40),(.025,.035,1.1))
    rig.add('Mission_Shelter','Hull',(0,r-.26,z),m)
    mast=np.array([s.width*.27,r+.58,z-.50]);m=Mesh()
    height=1.30 if s.equipment!='krasukha' else .55
    m.tube('paint',mast,mast+[0,height,0],.10,n,r_top=.065)
    if s.equipment=='koral':
        m.box('paint',mast+[0,height+.38,0],(1.72,.79,.26))
        m.box('metal_dark',mast+[0,height+.38,.145],(1.54,.63,.025))
    elif s.equipment=='krasukha':
        # Concave parabolic reflector, modelled as a closed double-skin dish.
        center=mast+[0,height+.37,0];radius=.86;rings=[]
        for rr in (.0,.35,.66,.86):
            rr=max(rr,.035);zz=.37*(rr/radius)**2
            rings.append([(center[0]+rr*math.cos(a),center[1]+rr*math.sin(a),center[2]+zz) for a in np.linspace(0,math.tau,n,endpoint=False)])
        # Closed frustum strips have physical thickness; no double-sided cards.
        for i in range(len(rings)-1):
            outer=[tuple(np.array(q)+[0,0,-.035]) for q in rings[i]]
            outer2=[tuple(np.array(q)+[0,0,-.035]) for q in rings[i+1]]
            for j in range(n):
                k=(j+1)%n
                m.solid('paint',[rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j],outer[j],outer[k],outer2[k],outer2[j]],
                        [[0,1,2,3],[7,6,5,4],[0,4,5,1],[3,2,6,7],[0,3,7,4],[1,5,6,2]])
        beam(m,'metal_dark',center,center+[0,0,.80],.055)
        m.box('paint',center+[0,0,.77],(.20,.18,.16))
    else:
        m.tube('paint',mast+[0,height,0],mast+[0,height+.48,0],.22,n)
        for side in (-1,1):beam(m,'metal_dark',mast+[side*.40,height,0],mast+[side*.40,height+.82,0],.025)
    rig.add('Mast','Hull',mast,m,'Y',hinge='antenna mast base')


def build(s,lod=0):
    rig=Rig(lod);m=Mesh()
    if s.family=='truck':truck_body(m,s,lod)
    elif s.family in ('fennek','humvee','jackal','hawkei','komodo','bushmaster','rakhsh'):scout_body(m,s,lod)
    else:shell(m,s,lod);windows(m,s,lod)
    recognition(m,s,lod)
    # Registration/flag carrier panels remain blank white material roles.
    half=s.width/2-(.46 if s.mobility=='tracked' else .10)
    mark_y=s.roof*.80;mark_z=-s.length*.14;mark_x=half*.91
    if s.family=='recovery':mark_z=s.length*.18
    if s.family=='truck':
        mark_x=s.width*.475+.03;mark_y=s.roof-1.05
        mark_z=s.length/2-.10-s.details.get('cab',2.1)*.5-s.details.get('hood',0.)
    if s.family=='jackal':mark_x=s.width/2-.10;mark_y=1.28
    for side in (-1,1):
        px=side*mark_x
        m.box('paint',(px,mark_y,mark_z),(.10,.28,.50))
        m.box('markings',(px+side*.058,mark_y,mark_z),(.018,.24,.45))
    m.remove_duplicates();rig.add('Hull',rig.root,(0,0,0),m)
    mobility(rig,s,lod);weapon(rig,s,lod)
    p=np.array([-.46,s.roof+.025,-.32]);m=Mesh();m.tube('paint',p+[0,-.015,.27],p+[0,.055,.27],.28,6 if lod else 12)
    if s.family not in ('jackal','truck'):rig.add('Hatch_Commander','Hull',p,m,'X')
    a=np.array([s.width*.33,s.roof,-s.length*.32]);m=Mesh()
    m.tube('metal_dark',a,a+[0,.63 if s.family=='fennek' else 1.10,0],.013,4 if lod else 6)
    rig.add('Antenna_1','Hull',a,m,'Y')
    rig.add('Engine_Deck','Hull',(s.width*.20,s.roof,s.length*.28 if s.front_engine else -s.length*.30))
    rig.add('Exhaust','Hull',(s.width*.40,s.roof*.72,s.length*.12 if s.front_engine else -s.length*.43))
    if s.family=='fennek':
        p=np.array([-.64,s.roof,-.45]);m=Mesh();m.tube('paint',p,p+[0,.48,0],.075,6)
        m.box('paint',p+[0,.57,0],(.36,.26,.29));m.box('glass',p+[0,.57,.16],(.27,.15,.025))
        rig.add('Observation_Mast','Hull',p,m,'Y')
    if s.slug.startswith('recoveryVehicle'):recovery(rig,s,lod)
    if s.slug.startswith(('mineClearer','mineLayer')):engineering(rig,s,lod)
    if s.slug.startswith('ewVehicle'):ew_equipment(rig,s,lod)
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    return rig,s


def wreck(rig,s):
    if s.weapon:
        return tank_wreck(rig,gearbox_spec(s))
    # Unarmed machines retain their recognizable equipment; burnt role, sagged
    # body panels, no imaginary detached gun turret on a recovery or EW truck.
    m=Mesh()
    for part in rig.parts:
        if part['mesh'] is None:continue
        mesh=part['mesh']
        if 'mesh_scale' in part['extras']:mesh=transformed(mesh,part['extras']['mesh_scale'],part['pivot'])
        merge_mesh(m,mesh,roles={'paint':'metal_dark','glass':None,'markings':None})
    # Bake canonical track UVs back to metre projection on static wreck faces.
    m.remove_duplicates();out=Mesh()
    for role,g in m.groups.items():
        p=np.asarray(g[0]);n=np.asarray(g[1])
        for f in np.asarray(g[3]).reshape(-1,3):
            q=p[f];out.face(role,q,np.cross(q[1]-q[0],q[2]-q[0]),normals=n[f])
    return out
