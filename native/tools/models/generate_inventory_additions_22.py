"""Five original Korean naval exteriors; public principal sizes, estimated fittings.

No external meshes, textures or Blender. Current activity and delivery/contract
stages are separately documented in research/evidence.json. Local dimensions,
closed launcher layouts, propeller shape and concealed arrangements are estimates.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from generate_p7_ships import combatant,sub
from generate_inventory_additions_16 import lattice
from generate_inventory_additions_21 import supported_canisters,upper_bridge_windows
from ship_parts import block,beam,wreck
from aircraft_parts import curved_shell
from vehicle_parts import Mesh,loft,hollow_muzzle,write_glb,merge_mesh

ART=Path(__file__).resolve().parents[3]/'native/godot/assets/art'
DEMA='https://kookbang.dema.mil.kr/newsWeb/'
PATROL='https://www.hjsc.co.kr/ship/lph_highspeed.asp'
LANDING=DEMA+'20190624/1/BBSMSTR_000000010206/view.do'

def twin40(r,s,lod,index=0):
    """Rounded Nobong shield, two visible tubes and two child port markers."""
    tname='Turret_Main' if index==0 else 'Turret_'+str(index)
    gname='Gun' if index==0 else 'Gun_'+str(index)
    turret=next(p for p in r.parts if p['name']==tname)
    gun=next(p for p in r.parts if p['name']==gname);q=gun['pivot']
    y=turret['pivot'][1]-.16;x=turret['pivot'][0];z=turret['pivot'][2]
    m=Mesh();m.tube('paint',(x,y,z),(x,y+.28,z),1.55,8 if lod else 28)
    rings=[]
    for yy,rr in ((.28,1.48),(.75,1.40),(1.35,1.06),(1.70,.30)):
        rings.append([[x+rr*math.cos(a),y+yy,z+rr*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 28,endpoint=False)])
    loft(m,'paint',rings);turret['mesh']=m
    aft=len(s.details['guns'][index])>5 and s.details['guns'][index][5];sign=-1 if aft else 1
    length=s.details['guns'][index][3];m=Mesh()
    for j,dx in enumerate((-.27,.27)):
        tip=q+[dx,0,sign*length]
        hollow_muzzle(m,q+[dx,0,sign*.25],tip,.060,.019,6 if lod else 14)
        m.tube('metal_dark',q+[dx,0,sign*.25],q+[dx,0,sign*.95],.095,6 if lod else 14,.070)
        r.add('Muzzle_Twin_'+str(index)+'_'+str(j),gname,tip,**({'frame_rotation':[0,1,0,0]} if aft else {}))
    gun['mesh']=m

def deck_detail(r,s,lod):
    """Ship-scaled cleats, fairleads, vents, hatches, optical heads and rails."""
    D=s.draft+s.freeboard;L=s.length;B=s.beam;m=Mesh()
    for side in (-1,1):
        for zf in (-.43,.32):
            z=zf*L;y=D+max(0,(zf-.22)/.28)*s.details.get('bow_sheer',1.7)
            x=side*B*(.26 if zf>0 else .27)
            for dz in (-.25,.25):m.tube('metal_dark',(x,y,z+dz),(x,y+.36,z+dz),.10,4 if lod else 14)
            beam(m,(x-.3,y+.28,z),(x+.3,y+.28,z),.06,lod)
        for i in range(2 if lod else 5):
            z=L*(-.16+i*.055);x=side*B*.475
            m.box('paint',(x,D+.50,z),(.12,.9,.65))
    for h in s.details['houses']:
        x,z,w,length,height,base,taper=h
        for side in (-1,1):
            yy=height*.42;xx=x+side*(w/2*(1-(1-taper)*.42)+.015)
            for j in range(1 if lod else 6):
                y=D+base+yy+(j-(0 if lod else 2.5))*.14
                m.box('metal_dark',(xx,y,z),(.027,.78 if lod else .075,min(3,length*.45)))
        if not lod:
            for zz in (z-length*.20,z+length*.20):
                block(m,'paint',x,D+base+height,zz,.8,.13,1.1,.98)
    r.add('Deck_Equipment','Hull',(0,D,0),m)
    # Domes are individually supported on an actual house roof.
    h=s.details['houses'][0];x,z,w,length,height,base,taper=h
    for i,side in enumerate((-1,1)):
        p=np.array([side*w*.27,D+height+base,z]);m=Mesh()
        m.tube('paint',p,p+[0,.45,0],.26,6 if lod else 16)
        rings=[]
        for yy,rr in ((.43,.20),(.6,.43),(.90,.43),(1.14,.22)):
            rings.append([p+[rr*math.cos(a),yy,rr*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 20,endpoint=False)])
        loft(m,'paint',rings);r.add('Radome_'+str(i),'Hull',p,m)

def jet_outlets(r,s,lod):
    """Three representative open stern jet outlets; local fit is approximate."""
    D=s.draft+s.freeboard;m=Mesh();y=s.draft*.67;z=-s.length*.5-.10
    for i,x in enumerate((-s.beam*.24,0,s.beam*.24)):
        hollow_muzzle(m,(x,y,z+.50),(x,y,z),.34,.25,6 if lod else 20)
        p=np.array([x,y,z-.06]);b=Mesh();b.box('metal_dark',p+[0,.25,.05],(.72,.25,.25))
        r.add('Jet_Bucket_'+str(i),'Hull',p,b,'X',fit='representative external reversing bucket; dimensions estimated')
    r.add('Waterjet_Outlets','Hull',(0,y,z),m)

def patrol_windows(r,s,lod):
    x,z,w,length,h,base,taper=s.details['houses'][0];D=s.draft+s.freeboard;m=Mesh()
    for side in (-1,1):
        xx=x+side*(w/2*(1-(1-taper)*.76)+.025)
        for zz in (z+length*.17,z+length*.23,z+length*.29):
            m.box('glass',(xx,D+base+h*.76,zz),(.035,.52,length*.035))
    r.add('Bridge_Side_Windows','Hull',(0,D+h*.76,z),m)

def sea_vulcan_exterior(r,s,lod):
    """Selected six-tube naval Vulcan-family exterior; per-hull fit unverified."""
    p=next(v for v in r.parts if v['name']=='Turret_1');q=next(v['pivot'] for v in r.parts if v['name']=='Gun_1');m=Mesh()
    m.tube('paint',p['pivot']-[0,.16,0],q-[0,.35,0],.42,6 if lod else 16)
    m.box('paint',q+[0,-.18,.18],(1.05,.72,.50));p['mesh']=m
    g=next(v for v in r.parts if v['name']=='Gun_1');m=Mesh();m.box('metal_dark',q+[0,0,.12],(.34,.32,.45));g['mesh']=m
    m=Mesh();tips=[]
    for a in np.linspace(0,math.tau,6,endpoint=False):
        offset=np.array([.075*math.cos(a),.075*math.sin(a),0]);tip=q+offset+[0,0,-1.25]
        hollow_muzzle(m,q+offset-[0,0,.10],tip,.022,.009,3 if lod else 8);tips.append(tip)
    r.add('Vulcan_Rotor','Gun_1',q,m,'Z',fit='six-barrel naval Vulcan-family modelling selection; installed per-hull configuration unverified')
    for i,p in enumerate(tips):r.add('Vulcan_Port_'+str(i),'Vulcan_Rotor',p,frame_rotation=[0,1,0,0])

def small_rws(r,s,lod,x,z,index):
    D=s.draft+s.freeboard;roof=max((a[4]+a[5] for a in s.details['houses'] if abs(x-a[0])<a[2]/2 and abs(z-a[1])<a[3]/2),default=0)
    p=np.array([x,D+roof+.7,z]);m=Mesh()
    m.tube('paint',p-[0,.7,0],p,.18,6 if lod else 12)
    r.add('RWS_'+str(index),'Hull',p,m,'Y');m=Mesh();q=p+[0,.18,0]
    m.box('metal_dark',q,(.22,.26,.38));hollow_muzzle(m,q+[0,0,.15],q+[0,0,1.1],.025,.006,6 if lod else 12)
    m.box('glass',q+[.18,.06,.18],(.12,.12,.10))
    r.add('RWS_Gun_'+str(index),'RWS_'+str(index),q,m,'X');r.add('RWS_Muzzle_'+str(index),'RWS_Gun_'+str(index),q+[0,0,1.1])

def gunboat__chamsuri_211_pkmr(lod=0):
    r,s=combatant('gunboat__chamsuri_211_pkmr','Chamsuri211 PKMR BatchI',lod,(45.,7.,1.8,2.2),PATROL,
        ['maker rounded45x7x4m hull; distinct smaller PKMR','stealth76mm bow mount','12 representative closed Biryong rocket covers aft','two12.7mm remote stations','waterjet transom; no propeller invented','single search mast and side exhaust enclosures'],
        houses=[(0,3.,6.4,18.,3.8,0,.84),(0,-9.,5.1,5.8,1.8,0,.95)],
        funnels=[],masts=[(3.,10.5,'panel',1.3)],guns=[(0,15.4,76,3.5)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.75,rail_count=30)
    p=np.array([0,s.draft+s.freeboard+.7,-16.0]);m=Mesh();m.tube('paint',p-[0,.7,0],p,.72,6 if lod else 20)
    r.add('Launcher_Turntable','Hull',p,m,'Y');q=p+[0,.65,0];m=Mesh()
    m.box('paint',q,(1.82,2.12,2.4));tips=[]
    for row in range(4):
        for col in range(3):
            tip=q+[(col-1)*.53,(row-1.5)*.49,-1.23]
            m.box('metal_dark',tip,(.44,.40,.045))
            tips.append(tip)
    r.add('Launcher','Launcher_Turntable',q,m,'X',fit='photo-informed twelve closed covers; not actual loaded rockets')
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Launcher',tip,frame_rotation=[0,1,0,0])
    for i,x in enumerate((-2.0,2.0)):small_rws(r,s,lod,x,-9.,i)
    jet_outlets(r,s,lod);deck_detail(r,s,lod);patrol_windows(r,s,lod)
    m=Mesh();D=s.draft+s.freeboard
    for side in (-1,1):
        block(m,'paint',side*2.25,D,-6.3,.72,2.1,2.1,.8)
        m.box('metal_dark',(side*2.25,D+2.12,-6.3),(.53,.05,1.5))
    r.add('Side_Exhaust_Housings','Hull',(0,D,-6.3),m,fit='photo-informed side ventilation/exhaust enclosures; internal ducts not modelled')
    s.representative='Chamsuri211/PKX-B BatchI photo-informed exterior.45x7x4m maker rounded hull dimensions; draft and local fittings estimated. Not a claim every BatchII hull delivered; DAPA2026first BatchII delivery separately recorded. Twelve closed-cover arrangement estimated from exterior references.'
    return r,s

def missileBoat__yoon_youngha_class(lod=0):
    r,s=combatant('missileBoat__yoon_youngha_class','Yoon Youngha class later-hull PKG',lod,(63.,9.,2.8,2.2),PATROL,
        ['larger63x9m PKG hull, not45m PKMR','later-hull angular WIA76mm bow gun; lead ship rounded OTO mount deliberately not selected','aft rounded twin40mm Nobong','four amidships Haeseong canisters','waterjet transom and stepped aft deckhouse'],
        houses=[(0,4.,8.2,28.,5.8,0,.85),(0,-20.,6.5,11.,2.1,0,.95)],
        funnels=[],masts=[(3.,13.5,'panel',1.8),(-16.,7.3,'bar',1.5)],guns=[(0,22.,76,3.8),(0,-24.0,40,2.2,2.1,True)],
        vls=[],canisters=[(-13.0,.0,2)],ciws=[],hangar=False,flight_deck=False,bow_sheer=.9,rail_count=33)
    twin40(r,s,lod,1);supported_canisters(r,s,lod);jet_outlets(r,s,lod);deck_detail(r,s,lod);patrol_windows(r,s,lod)
    s.representative='Later-hull class representative with angular WIA76mm and rounded twin40mm aft mount, matching maker photograph and DMA distinction from lead YoonYoungha rounded OTO76.63x9x5m rounded principal hull dimensions; local waterjet and weapons positions estimated. Current2026PKGownership independent of historical product photo.'
    return r,s

def lcm(r,s,lod,index,x,z):
    """Stowed open cargo boat, stern cabin and a separately hinged bow ramp."""
    D=s.draft+s.freeboard;y=D+.42;length=23.;width=5.8;m=Mesh()
    for zz in (-length*.30,length*.30):m.box('metal_dark',(x,D+.22,z+zz),(width*.75,.44,.42))
    rings=[]
    for dz,w in ((-length/2,width*.85),(length*.35,width),(length/2,width*.85)):
        rings.append([[x+sx*w/2,y+yy,z+dz] for sx,yy in [(1,.40),(1,.20),(.7,0),(-.7,0),(-1,.20),(-1,.40)]])
    loft(m,'paint',rings)
    # Actual open well: low cargo floor and separately closed side bulwarks.
    m.box('metal_dark',(x,y+.425,z),(width*.70,.035,length*.66))
    for side in (-1,1):m.box('paint',(x+side*width*.45,y+1.10,z),(width*.08,1.40,length*.92))
    block(m,'paint',x,y+.40,z-length*.35,width*.62,1.70,3.4,.9)
    m.box('glass',(x,y+1.65,z-length*.35+1.55),(width*.36,.45,.05))
    r.add('LCM_'+str(index),'Hull',(x,y,z),m,fit='two visible stowed foredeck boats; local dimensions estimated')
    p=np.array([x,y+.25,z+length/2+.025]);m=Mesh();m.box('paint',p+[0,.83,0],(width*.74,1.66,.12))
    r.add('LCM_Ramp_'+str(index),'LCM_'+str(index),p,m,'X')

def landingShip__cheonwangbong_class(lod=0):
    r,s=combatant('landingShip__cheonwangbong_class','Cheon Wang Bong class LSTII',lod,(126.9,19.4,4.6,3.6),LANDING,
        ['126.9x19.4m current LSTII family, not Dokdo LPH','central bridge and large aft twin-spot helicopter deck','two visible stowed LCMs foredeck, capacity for third does not invent a visible third','two estimated handling cranes','rounded twin40mm bow gun and closed SAAM lids','stern Ramp; no invented bow landing ramp'],
        houses=[(0,3.,17.2,28.,6.2,0,.94),(0,3.,12.,14.,4.0,6.2,.9)],
        funnels=[(-5.8,-5.,2.0,4.0,5.0,6.2),(5.8,-5.,2.0,4.0,5.0,6.2)],
        masts=[(3.,21.,'bar',2.5)],guns=[(0,51.0,40,2.3)],vls=[(-5.0,2,4,.60,10.2)],canisters=[],ciws=[],
        hangar=False,flight_deck=False,landing=True,cranes=[(-7.7,15.,7.,9.),(7.7,15.,7.,9.)],bow_sheer=1.15,rail_count=34)
    twin40(r,s,lod);lattice(r,s,lod,0,3.,21.,1.35);upper_bridge_windows(r,s,lod)
    lcm(r,s,lod,0,-4.,31.);lcm(r,s,lod,1,4.,31.)
    D=s.draft+s.freeboard;m=Mesh()
    for z in (-28.,-48.):
        radius=6.0
        for a in np.linspace(0,math.tau,12 if lod else 36,endpoint=False):
            b=a+math.tau/(12 if lod else 36);beam(m,(radius*math.cos(a),D+.025,z+radius*math.sin(a)),(radius*math.cos(b),D+.025,z+radius*math.sin(b)),.045,lod,'markings')
        for x in (-2,2):m.box('markings',(x,D+.03,z),(.16,.03,4.5))
        m.box('markings',(0,D+.03,z),(4.0,.03,.16))
    r.add('Helipad_Markings','Hull',(0,D,-38.),m);deck_detail(r,s,lod)
    s.representative='126.9x19.4m published principal dimensions, photo-informed central house, two foredeck LCMs, twin helicopter spots and rounded twin40mm Nobong. Third craft capacity is not a visible third boat claim. Draft/freeboard, crane hinges and eight selected closed SAAM covers are estimates; no live load or internal well-deck geometry claimed. Current2026CheonJaBong RIMPAC independently confirmed.'
    return r,s

def landingShip__gojunbong_class(lod=0):
    r,s=combatant('landingShip__gojunbong_class','Go Jun Bong class LSTI',lod,(112.7,15.4,3.4,2.9),LANDING,
        ['112.7x15.4m older beaching LST, current2026captain account','aft central superstructure and long open vehicle deck','working stern Ramp and separate bow doors/ramp','rounded twin40mm forward gun and20mm aft representative mount','lattice mast, single helicopter spot and davit boats'],
        houses=[(0,-27.,13.2,25.,5.8,0,.94),(0,-24.,9.4,12.,3.,5.8,.88)],
        funnels=[(-4.,-31.,2.1,3.2,4.,5.8),(4.,-31.,2.1,3.2,4.,5.8)],masts=[(-21.,19.,'bar',3.7)],
        guns=[(0,44.,40,2.3),(0,-33.,20,1.25,5.8,True)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,
        landing=True,bow_sheer=1.1,rail_count=32,
        hull_profile=[(-.5,.65),(-.40,.94),(-.20,1),(.20,1),(.35,.84),(.46,.58),(.5,.45)])
    twin40(r,s,lod);lattice(r,s,lod,0,-21.,19.,1.2);upper_bridge_windows(r,s,lod);D=s.draft+s.freeboard
    p=np.array([0,s.draft+.25,s.length*.5+.08]);height=D+1.1-p[1];m=Mesh()
    m.box('paint',p+[0,height/2,-.11],(s.beam*.36,height,.15));r.add('Ramp_Bow','Hull',p,m,'X')
    for side,label in ((-1,'L'),(1,'R')):
        p=np.array([side*s.beam*.205,s.draft+.25,s.length*.5+.12]);m=Mesh()
        m.box('paint',p+[-side*s.beam*.105,height/2,.07],(s.beam*.21,height,.12))
        r.add('Bow_Door_'+label,'Hull',p,m,'Y')
    m=Mesh();z=-s.length*.435
    for x in (-2.0,2.0):m.box('markings',(x,D+.03,z),(.16,.03,4.0))
    m.box('markings',(0,D+.03,z),(4.0,.03,.16));r.add('Helipad_Markings','Hull',(0,D,z),m)
    # Four small historical-style davit boats on the clear middle deck edges.
    for i,(x,z) in enumerate(((-5.2,8.),(5.2,8.),(-5.2,-2.),(5.2,-2.))):
        m=Mesh();block(m,'paint',x,D+.6,z,2.4,.95,6.5,.72)
        for zz in (-2,2):beam(m,[x,D,z+zz],[x,D+2.,z+zz],.075,lod,'paint')
        r.add('Davit_Boat_'+str(i),'Hull',(x,D,z),m,fit='historical photo-informed small boat exterior, local estimate')
    deck_detail(r,s,lod);sea_vulcan_exterior(r,s,lod)
    s.representative='Current older LSTI, not a second name for LSTII.112.7x15.4m public size, aft central bridge, twin40mm forward gun, selected six-barrel naval Vulcan-family20mm aft exterior and separate bow beaching doors/ramp plus stern Ramp. Local draft/freeboard, exact20mm mount/count/location, davits and fitting positions are estimates; not every remaining hull or upgrade certified.'
    return r,s

def submarine__son_won_il_class(lod=0):
    r,s=sub('submarine__son_won_il_class','Son Won-il class KSSII Type214',lod,65.3,6.3,5.6,
        DEMA+'20190930/1/BBSMSTR_000000010206/view.do',
        ['65.3x6.3m conventional Type214 AIP hull','tall narrow sail and long flat upper casing','bow-mounted diving planes; no fairwater planes','cruciform tail, single open representative screw','no invented VLS deck'],
        sail_z=.09,sail_height=4.8,sail_length=9.3,foreplanes='bow',prop_blades=7,
        body_profile=[(-.45,.07),(-.36,.30),(-.23,.48),(-.08,.5),(.16,.5),(.32,.47),(.43,.34),(.48,.17),(.5,.006)])
    m=Mesh();rings=[]
    # Closed outer casing supported down to the curved body at each station.
    for z,w,low,top in [(-27.,.35,4.0,4.8),(-20.,1.05,5.4,6.1),(-8.,1.50,5.9,6.5),(10.,1.50,5.9,6.5),(23.,1.12,5.1,6.5),(29.,.30,4.3,5.3)]:
        rings.append([[-w,low,z],[w,low,z],[w,top,z],[-w,top,z]])
    m.face('paint',rings[0],[0,0,-1]);m.face('paint',rings[-1],[0,0,1])
    for a,b in zip(rings,rings[1:]):
        for i,normal in enumerate(([0,-1,0],[1,0,0],[0,1,0],[-1,0,0])):
            j=(i+1)%4;m.face('paint',[a[i],a[j],b[j],b[i]],normal)
    if not lod:
        for side in (-1,1):
            for z in np.linspace(-16,19,25):
                width=np.interp(z,[-20,-8,10,23],[1.05,1.50,1.50,1.12])
                m.box('metal_dark',(side*(width+.01),6.12,z),(.035,.13,.48))
    # Raised closed circular access covers, exterior only.
    for z in (-6.,18.):m.tube('metal_dark',(0,6.50,z),(0,6.54,z),.54,8 if lod else 24)
    r.add('Upper_Casing','Hull',(0,6.3,0),m)
    s.representative='Current KSSII family confirmed by2026operator training and named onboard personnel.65.3x6.3m published public size; photo-informed tall sail, flat casing and bow planes; cruciform tail and open screw. Seven decorative propeller blades and local sensor/shaft geometry are estimates, not independently certified propulsor geometry. July2026trial EW/SATCOM prototypes on AnJungGeun/YunBongGil are not a fleet-wide completed retrofit; no VLS copied from KSSIII.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('gunboat__','missileBoat__','landingShip__','submarine__')) and callable(f)}

def save(slug):
    from validate_ships import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    for r in (a,b):
        if r.lod and s.details.get('landing'):
            p=next(v for v in r.parts if v['name']=='Ramp');q=p['pivot'];h=s.details.get('ramp_height',min(6.,s.freeboard+1));m=Mesh()
            m.box('metal_dark',q+[0,h/2,0],(s.beam*.40,h,.22));m.box('paint',q+[0,h/2,-.14],(s.beam*.36,h*.93,.08));p['mesh']=m
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    hull=next(p['mesh'] for p in a.parts if p['name']=='Hull')
    pts=np.concatenate([g[0] for g in hull.groups.values() if g[0]])
    lo,hi=pts.min(0),pts.max(0);c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=ART/'ships'/(slug+'.glb');write_glb(path,[a,b],wreck(b),c,{'scene_name':s.name,'vehicle':slug,'priority':'P7','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_22.py; current/ordered statuses and variant/geometry limits in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
