"""Original P4 carrier, cannon, missile and radar construction; no Blender.

Real rotating assemblies are empty hinges. A launcher does not acquire a
fictional radar merely because its battery uses a separate radar vehicle.
"""
from dataclasses import replace
import math
import numpy as np
from vehicle_parts import Mesh,Rig,profile_hull,loft,hollow_muzzle,merge_mesh,rotation
from armour_parts import ArmourSpec,build,mobility
from artillery_parts import launcher_vehicle
from generate_p1_tanks import beam

def carrier(slug,name,lod,cfg,source,approximate=False,representative=''):
    L,W,H,mode,N,r,k,front,family,axles=cfg
    s=ArmourSpec(slug,name,L,W,H,mode,N,r,family,'',[],source,k,front,approximate,representative,list(axles))
    if family=='truck' and N==2:s.details.update(cab=1.75,hood=1.20)
    if slug=='aaVehicle__rbs_70_vehicle':s.details.update(cab=1.32,hood=1.05)
    if mode=='wheeled' and family not in ('gun_trailer','aa_trailer'):
        rig,s=build(s,lod)
        # The rotating AA mounting occupies the hull roof commander position.
        rig.parts=[p for p in rig.parts if p['name']!='Hatch_Commander']
        if family=='humvee':
            # M1097 Avenger carrier: open rear weapon deck and short front cab.
            m=Mesh();h=L/2;m.box('paint',(0,.80,0),(W-.15,.40,L-.10))
            m.box('paint',(0,1.13,h-.72),(W-.18,.47,1.34))
            m.box('paint',(0,1.85,.55),(1.78,.07,1.11))
            for side in (-1,1):
                m.box('paint',(side*.46,1.58,1.08),(.81,.49,.07))
                m.box('glass',(side*.46,1.59,1.122),(.64,.37,.025))
                m.box('paint',(side*(W/2-.10),1.18,.44),(.08,.42,1.10))
                beam(m,'paint',(side*.85,1.37,.01),(side*.85,1.83,.01),.055)
                m.box('paint',(side*(W/2-.10),1.10,-1.24),(.08,.29,2.22))
                m.box('rubber',(side*.46,1.12,.52),(.42,.13,.44));m.box('rubber',(side*.46,1.42,.27),(.42,.55,.10))
                for z in axles:m.box('paint',(side*(W/2-.20),.91,z),(.46,.09,1.02))
                m.box('paint',(side*(W/2-.075),1.14,-1.55),(.10,.27,.47))
                m.box('markings',(side*(W/2-.016),1.14,-1.55),(.017,.21,.39))
                m.box('glass',(side*.75,1.08,h+.012),(.15,.15,.045))
            m.box('metal_dark',(0,1.10,h+.018),(1.25,.31,.05))
            for p in rig.parts:
                if p['name']=='Hull':p['mesh']=m
                elif p['name']=='Antenna_1':
                    a=np.array([-.77,1.89,.55]);ant=Mesh();ant.tube('metal_dark',a,a+[0,1.10,0],.013,4 if lod else 6)
                    p['pivot']=a;p['mesh']=ant;rig.pivots[p['name']]=a
                elif p['name']=='Engine_Deck':p['pivot']=np.array([0,1.38,h-.72]);rig.pivots[p['name']]=p['pivot']
                elif p['name']=='Exhaust':p['pivot']=np.array([.98,.90,.90]);rig.pivots[p['name']]=p['pivot']
        return rig,s
    rig=Rig(lod);m=Mesh();h=L/2;half=W/2-.43
    if mode=='tracked':
        profile_hull(m,'paint',[(h-.21,.41,half*.84),(h,H*.65,half*.95),(h-1.34,H,half),
            (-h+.14,H,half),(-h,.61,half*.93),(-h+.18,.41,half*.84)])
        for side in (-1,1):
            m.box('paint',(side*(W/2-.31),1.18*k,0),(.64,.11,L-.20))
            m.box('paint',(side*(W/2-.13),H-.18,-.70),(.31,.30,.58))
            m.box('markings',(side*(W/2+.036),H-.18,-.70),(.017,.23,.46))
        m.box('paint',(-.46,H+.04,h*.37),(.58,.08,.63));m.box('glass',(-.46,H+.11,h*.37+.22),(.35,.06,.12))
        ez=h*.43 if front else -h*.58
        for z in np.linspace(ez-.42,ez+.42,3 if lod else 9):m.box('metal_dark',(.45 if front else 0,H+.025,z),(.68 if front else 1.17,.035,.05))
        rig.add('Hull',rig.root,(0,0,0),m);mobility(rig,s,lod)
        rig.add('Engine_Deck','Hull',(0,H+.04,ez));rig.add('Exhaust','Hull',(W/2-.2,H*.72,ez))
    elif family=='stand':
        m.tube('paint',(0,.14,0),(0,H,0),.085,6 if lod else 12)
        for i in range(3):
            angle=i*math.tau/3;p=np.array([.78*math.sin(angle),.10,.78*math.cos(angle)])
            beam(m,'paint',(0,H-.18,0),p,.075);m.box('metal_dark',p,(.22,.20,.25))
        m.box('paint',(0,H-.09,.08),(.17,.22,.09));m.box('markings',(0,H-.09,.131),(.13,.16,.012))
        rig.add('Hull',rig.root,(0,0,0),m)
    else:
        # Cross-legged deployable mount, or a one-axle towed gun carriage.
        m.box('paint',(0,H-.10,0),(W*.48,.20,L*.43))
        for side in (-1,1):
            for end in (-1,1):
                p=np.array([side*W*.42,.14,end*L*.43])
                beam(m,'paint',(side*.35,H-.18,end*.36),p,.15)
                m.box('metal_dark',p-[0,.04,0],(.39,.20,.42))
        m.box('markings',(W*.24+.012,H-.10,0),(.018,.18,.43))
        if family=='aa_trailer':
            m=Mesh();m.box('paint',(0,H-.10,0),(W-.12,.20,L-.30))
            m.box('paint',(0,(H+.40)/2,0),(W-.30,H-.40,2.50))
            for side in (-1,1):m.box('markings',(side*(W/2-.051),H-.10,-.50),(.016,.18,.46))
            beam(m,'metal_dark',(0,H-.18,h-.17),(0,.72,h+.70),.16)
        rig.add('Hull',rig.root,(0,0,0),m)
        if mode=='wheeled':mobility(rig,s,lod)
        if family=='aa_trailer':
            for side,label in ((-1,'L'),(1,'R')):
                for i,zz in enumerate((-L*.38,L*.38)):
                    p=np.array([side*(W/2-.15),H-.20,zz]);leg=Mesh()
                    leg.tube('paint',p,p+[0,-(H-.40),0],.095,6 if lod else 12)
                    leg.box('metal_dark',(p[0],.10,p[2]),(.35,.20,.40))
                    rig.add('Outrigger_'+label+str(i),'Hull',p,leg,translation_axis='Y')
    return rig,s

def reflector(m,center,R,lod):
    center=np.array(center);n=8 if lod else 16
    rings=[]
    for radius in (.035,R*.40,R*.75,R):
        z=R*.38*(radius/R)**2
        rings.append([center+[radius*math.cos(t),radius*math.sin(t),z] for t in np.linspace(0,math.tau,n,endpoint=False)])
    for a,b in zip(rings,rings[1:]):
        for j in range(n):
            q=[a[j],a[(j+1)%n],b[(j+1)%n],b[j]]
            m.solid('paint',q+[p-[0,0,.035] for p in q],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)])
    beam(m,'metal_dark',center,center+[0,0,R*.90],.045)
    m.box('paint',center+[0,0,R*.89],(.15,.15,.15))
    m.remove_duplicates()

def radar(rig,parent,p,lod,style='array',width=1.3,height=.8):
    p=np.array(p);m=Mesh();n=6 if lod else 12
    m.tube('paint',p,p+[0,.38,0],.09,n)
    center=p+[0,.38+height*.52,0]
    if style=='dish':reflector(m,center,width/2,lod)
    else:
        m.box('paint',center,(width,height,.20));m.box('metal_dark',center+[0,0,.117],(width-.11,height-.11,.025))
        for side in (-1,1):beam(m,'paint',p+[side*width*.27,.10,0],center+[side*width*.35,0,-.17],.065)
        if not lod:
            for x in np.linspace(-width*.40,width*.40,5):m.box('paint',center+[x,0,-.14],(.035,height*.87,.07))
    rig.add('Radar',parent,p,m,'Y',sensor_type=style)

def gun_mount(rig,s,lod,style,has_radar=True):
    """Gun barrels and missile banks share only a real common trunnion line."""
    patterns={
      'gepard':[(-1.03,0,3.12,.035,'gun'),(1.03,0,3.12,.035,'gun')],
      'type87':[(-.99,0,3.09,.035,'gun'),(.99,0,3.09,.035,'gun')],
      'shilka':[(x,y,1.66,.023,'gun') for x in (-.16,.16) for y in (-.12,.12)],
      'sidam':[(x,y,1.96,.025,'gun') for x in (-.59,.59) for y in (-.14,.14)],
      'gdf':[(-.17,0,2.71,.035,'gun'),(.17,0,2.71,.035,'gun')],
      'zu23':[(-.14,0,1.54,.023,'gun'),(.14,0,1.54,.023,'gun')],
      'biho':[(-.92,0,2.57,.030,'gun'),(.92,0,2.57,.030,'gun')]+[(x,y,1.78,.10,'missile') for x in (-1.25,1.25) for y in (-.13,.13)],
      'korkut':[(-.18,0,3.12,.035,'gun'),(.18,0,3.12,.035,'gun')],
      'tunguska':[(x,y,2.66,.030,'gun') for x in (-.92,.92) for y in (-.10,.10)]+[(x,y,2.21,.13,'missile') for x in (-1.32,1.32) for y in (-.31,-.09,.13,.35)],
      'pantsir':[(x,y,2.62,.030,'gun') for x in (-.76,.76) for y in (-.09,.09)]+[(side*(1.13+dx),y,2.38,.17,'missile') for side in (-1,1) for dx in (0,.24) for y in (-.26,0,.26)],
      'avenger':[(side*(.73+dx),y,1.56,.12,'missile') for side in (-1,1) for dx in (0,.18) for y in (-.10,.10)],
      'crotale':[(side*(1.06+dx),y,2.35,.17,'missile') for side in (-1,1) for dx in (0,.25) for y in (-.15,.15)],
      'stormer':[(side*(.79+dx),y,1.67,.13,'missile') for side in (-1,1) for dx in (0,.20) for y in (-.12,.12)],
      'mshorad':[(0,-.17,2.05,.030,'gun')]+[(-.80+dx,y,1.60,.12,'missile') for dx in (0,.19) for y in (-.11,.11)]+[(.79,y,1.70,.17,'missile') for y in (-.13,.13)],
      'skyranger':[(0,-.12,2.03,.030,'gun')]+[(.77+dx,y,1.55,.12,'missile') for dx in (0,.19) for y in (-.11,.11)],
      'm1992':[(-.25,0,2.10,.030,'gun'),(.25,0,2.10,.030,'gun')],
      'rbs70':[(0,0,1.35,.105,'missile')],
    }
    tubes=patterns[style];n=4 if lod else 12
    if style=='avenger':tubes=[(x,y+.35,length,cal,kind) for x,y,length,cal,kind in tubes]
    truck=s.family=='truck';base=s.wheel_radius*2.05+.42 if truck else s.roof+.10
    if style=='avenger':base=s.wheel_radius*2.05+.32
    bare=style in ('gdf','zu23','rbs70');th=.38 if bare else .66 if style=='stormer' else 1.05 if style=='avenger' else .92
    tw=1.65 if style in ('stormer','avenger') else 2.30;td=1.55 if bare else 2.40
    if style=='avenger':tw=1.20;td=1.35
    t=Mesh();t.tube('metal_dark',(0,base-.10,0),(0,base+.03,0),.45 if bare else .73,6 if lod else 16)
    if not bare:
        fp=[(-tw*.27,td*.49),(tw*.27,td*.49),(tw*.50,td*.14),(tw*.47,-td*.46),(-tw*.47,-td*.46),(-tw*.50,td*.14)]
        loft(t,'paint',[[(x,base,z) for x,z in fp],[(x*.86,base+th,z*.90) for x,z in fp]])
        for side in (-1,1):t.box('markings',(side*(tw*.48+.012),base+th*.50,-.45),(.017,.22,.43))
        t.box('paint',(-.46,base+th+.05,-.39),(.52,.10,.55))
    else:
        for side in (-1,1):
            beam(t,'paint',(side*.31,base,0),(side*.31,base+th,.19),.12)
            if style!='rbs70':t.box('paint',(side*.44,base+.15,-.36),(.37,.10,.39))
    t.box('paint',(.37,base+th+.04,.34),(.24,.16,.33));t.box('glass',(.37,base+th+.05,.519),(.16,.10,.025))
    if style=='avenger':
        t.box('paint',(0,base+.73,.66),(.85,.68,.08));t.box('glass',(0,base+.74,.713),(.72,.55,.025))
    rig.add('Turntable','Hull',(0,base,0),t,'Y')
    p=np.array([0,base+th*.57,.20]);m=Mesh();tips=[]
    m.box('paint',p,(1.10,.22,.51))
    for i,(dx,dy,length,cal,kind) in enumerate(tubes):
        a=p+[dx,dy,-.23];b=p+[dx,dy,length-.23]
        if kind=='gun':
            hollow_muzzle(m,a,b,max(cal*.75,.026),cal*.5,n)
            m.tube('paint',a-[0,0,.17],a+[0,0,.48],max(cal*1.7,.069),n)
        else:
            m.tube('paint',a,b,cal*.58,n)
            m.tube('metal_dark',b-[0,0,.035],b+[0,0,.012],cal*.61,n)
        tips.append((b+[0,0,.012] if kind!='gun' else b).tolist())
        # Each outboard bank is held by a solid bracket reaching the trunnion.
        beam(m,'paint',p+[0,dy,-.16],a,.075)
    m.remove_duplicates();rig.add('Launcher','Turntable',p,m,'X',elevation_degrees=[-5,85],positive_elevation_rotation_sign=-1)
    for i,tip in enumerate(tips):rig.add('Muzzle_'+str(i),'Launcher',tip,forward='+Z')
    s.details.update(tube_count=len(tips),muzzle_positions=tips,radar=has_radar,aa_mount=style)
    if style in ('avenger','crotale','stormer'):
        for side in (-1,1):
            width,height,depth,cx=(.58,.58,1.44,.82) if style=='avenger' else (.65,.65,2.12,1.18) if style=='crotale' else (.56,.53,1.46,.89)
            m.box('paint',p+[side*cx,.35 if style=='avenger' else 0,depth*.35],(width,height,depth))
    if has_radar:
        if style in ('skyranger','mshorad'):
            array=Mesh()
            angles=(0,math.pi/2,math.pi,math.pi*1.5) if style=='mshorad' else (0,math.tau/3,math.tau*2/3)
            for angle in angles:
                R=rotation([0,1,0],angle);center=R@np.array([0,0,.94])+[0,base+th*.57,0]
                array.box('paint',center,(.64,.49,.16),R)
                array.box('metal_dark',center+R@np.array([0,0,.094]),(.54,.39,.025),R)
            rig.add('Radar','Turntable',(0,base,0),array,'Y',sensor_type='fixed_aesa',fixed_to_turret=True)
            s.details['radar_fixed_to_turret']=True
        else:radar(rig,'Turntable',(0,base+th,-.92),lod,'dish' if style in ('gepard','type87','shilka') else 'array',1.05,.69)
        if style in ('gepard','type87','tunguska','pantsir','crotale'):
            track=Mesh();center=np.array([0,base+.58,td*.51]);reflector(track,center,.35,lod)
            track.box('paint',center+[0,-.23,-.08],(.34,.55,.30))
            rig.add('Radar_Tracking','Turntable',(0,base+.28,td*.45),track,'Y',sensor_type='tracking_dish')
    s.features=[style+' anti-aircraft mounting',str(len(tips))+' independently marked barrels/canisters',
        'Y turntable and X common trunnion','rear '+('search radar' if has_radar else 'optical fire control; no invented radar')]
    if style=='avenger':
        for part in rig.parts:
            if part['name']=='Turntable' or part['parent'] in ('Turntable','Launcher'):
                part['pivot'][2]-=.91
                if part['mesh'] is not None:part['mesh'].shift([0,0,-.91])
                rig.pivots[part['name']]=part['pivot']
        for tip in s.details['muzzle_positions']:tip[2]-=.91
        s.turret_z=-.91
    if style=='pantsir':
        floor=s.wheel_radius*2.05+.18
        # Rear combat module above the equipment shelter, clear of the cab.
        delta=np.array([0,.72,-2.05])
        for part in rig.parts:
            if part['name']=='Turntable' or part['parent'] in ('Turntable','Launcher'):
                part['pivot']+=delta
                if part['mesh'] is not None:part['mesh'].shift(delta)
                rig.pivots[part['name']]=part['pivot']
        for tip in s.details['muzzle_positions']:
            for j in range(3):tip[j]+=float(delta[j])
        shelter=Mesh();shelter.box('paint',(0,floor+.48,-.83),(2.39,.96,5.32))
        for side in (-1,1):
            shelter.box('metal_dark',(side*1.206,floor+.52,.32),(.025,.48,.90))
        rig.add('Equipment_Shelter','Hull',(0,floor,-.83),shelter)
        for side,label in ((-1,'L'),(1,'R')):
            for i,zz in enumerate((-s.length*.34,s.length*.10)):
                p=np.array([side*(s.width/2-.18),floor,zz]);leg=Mesh()
                beam(leg,'paint',(side*s.width*.28,floor,zz),p,.13)
                leg.tube('paint',p,p+[0,-.65,0],.10,6 if lod else 12);leg.box('metal_dark',p+[0,-.70,0],(.40,.10,.43))
                rig.add('Outrigger_'+label+str(i),'Hull',p,leg,translation_axis='Y')
    if style=='zu23' and s.family=='truck':
        delta=np.array([0,0,-1.85])
        for part in rig.parts:
            if part['name']=='Turntable' or part['parent'] in ('Turntable','Launcher'):
                part['pivot']+=delta
                if part['mesh'] is not None:part['mesh'].shift(delta)
                rig.pivots[part['name']]=part['pivot']
        for tip in s.details['muzzle_positions']:tip[2]-=1.85
        stand=Mesh();tray=s.wheel_radius*2.05+.18
        stand.tube('metal_dark',(0,tray,-1.85),(0,base-.08,-1.85),.43,6 if lod else 12)
        rig.add('Launcher_Stand','Hull',(0,tray,-1.85),stand)
    if style=='rbs70' and s.mobility=='wheeled':
        # Fire unit carried on the rear tray, with sight and operator seat.
        delta=np.array([0,.45,-1.30])
        for part in rig.parts:
            if part['name']=='Turntable' or part['parent'] in ('Turntable','Launcher'):
                part['pivot']+=delta
                if part['mesh'] is not None:part['mesh'].shift(delta)
                rig.pivots[part['name']]=part['pivot']
        for tip in s.details['muzzle_positions']:
            for j in range(3):tip[j]+=float(delta[j])
        support=Mesh();tray=s.wheel_radius*2.05+.18
        for i in range(3):
            angle=i*math.tau/3
            foot=np.array([.39*math.sin(angle),tray+.02,-1.30+.39*math.cos(angle)])
            beam(support,'paint',(0,base+.45,-1.30),foot,.075)
        for side in (-1,1):
            support.box('paint',(side*.72,tray+.21,-.22),(.39,.42,1.45))
        rig.add('Launcher_Stand','Hull',(0,tray,-1.30),support)
    return rig,s

def sam(slug,name,lod,config,source,approximate=False,representative=''):
    rig,s=launcher_vehicle(slug,name,lod,config,source,approximate,representative)
    s.details['radar']=False
    # Some missile systems are unpowered trailers, with four real stabilisers.
    if s.family.endswith('_trailer'):
        floor=s.wheel_radius*2.05+.18;m=Mesh();h=s.length/2
        m.box('paint',(0,floor-.10,0),(s.width-.12,.20,s.length-.30))
        for side in (-1,1):
            m.box('metal_dark',(side*.65,floor-.34,0),(.17,.39,s.length-.35))
            m.box('markings',(side*(s.width/2-.041),floor-.10,-.50),(.017,.18,.56))
        beam(m,'metal_dark',(0,floor-.20,h-.20),(0,.71,h+.70),.15)
        for p in rig.parts:
            if p['name']=='Hull':p['mesh']=m
        rig.parts=[p for p in rig.parts if p['name'] not in ('Antenna_1','Engine_Deck','Exhaust')]
        for side,label in ((-1,'L'),(1,'R')):
            p=np.array([side*(s.width/2-.18),floor,s.length*.34]);m=Mesh()
            m.tube('paint',p,p+[0,-.69,0],.11,6 if lod else 12);m.box('metal_dark',p+[0,-.73,0],(.40,.09,.40))
            rig.add('Outrigger_Front_'+label,'Hull',p,m,translation_axis='Y')
        s.front_engine=False
    if s.family.endswith('_static'):
        s.mobility='static';s.wheels=0;s.axle_z=[];s.front_engine=False;m=Mesh()
        m.box('paint',(0,.13,0),(s.width-.10,.10,s.length-.20))
        for side in (-1,1):
            for end in (-1,1):m.box('metal_dark',(side*(s.width/2-.23),.07,end*(s.length/2-.27)),(.37,.14,.40))
        for p in rig.parts:
            if p['name']=='Hull':p['mesh']=m
        rig.parts=[p for p in rig.parts if p['name'] not in ('Antenna_1','Engine_Deck','Exhaust')]
    return rig,s

def radar_carrier(slug,name,lod,cfg,source,width,height,style='array',approximate=False,representative=''):
    rig,s=carrier(slug,name,lod,cfg,source,approximate,representative)
    base=s.wheel_radius*2.05+.18 if s.family=='truck' else s.roof
    shelter=Mesh();z=-s.length*.24
    if s.family=='truck':
        shelter.box('paint',(0,base+.66,z),(s.width-.27,1.32,s.length*.39))
        if not lod:
            for side in (-1,1):
                for yy in np.linspace(base+.30,base+.98,6):shelter.box('metal_dark',(side*(s.width/2-.12),yy,z-.30),(.027,.035,.80))
        rig.add('Electronics_Shelter','Hull',(0,base,z),shelter)
        base+=1.32
    radar(rig,'Hull',(0,base,z),lod,style,width,height)
    s.details.update(radar=True,tube_count=0);s.features=['actual radar carrier class','rotating '+style+' with backed reflector/array','Y-axis antenna bearing','electronics enclosure']
    return rig,s
