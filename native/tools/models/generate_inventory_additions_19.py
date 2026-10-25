"""Korean artillery, air defence and combat engineering: original exterior meshes.

Photographs identify exterior form; estimated small fittings and dimensions are
declared. Original Python geometry only; unchanged approved canonical tracks.
The existing HybridBiho is reused, not duplicated under another designation.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,profile_hull,loft,hollow_muzzle,write_glb
from generate_p1_tanks import beam
from generate_inventory_additions_12 import base,remove,hatch,lamps,gun_station
from generate_inventory_additions_18 import k200_body
from armour_parts import wreck
from air_defence_parts import radar
import generate_inventory_additions as common

GUIDE='https://www.kotra.or.kr/kodits/upload_file/promotion/2019%20Korea%20Defense%20Products%20Guide.pdf'
K600='https://www.hyundai-rotem.co.kr/ko/business/defense/details.do?productNm=K600+%EC%9E%A5%EC%95%A0%EB%AC%BC%EA%B0%9C%EC%B2%99%EC%A0%84%EC%B0%A8'
CHUNHO='https://www.dapa.go.kr/dapa/doc/selectDoc.do?bbsSeq=326&docSeq=10819&menuSeq=3069'
CHUNMA='https://kookbang.dema.mil.kr/newsWeb/20260202/8/ATCE_CTGR_0010030000/view.do'
VULCAN='https://odin.t2com.army.mil/WEG/Asset/ce357c56bdc313fa53e7ccf50695b686'

def body(slug,name,lod,length,width,deck,wheels,radius,scale,source,features,*,axles=None,front=True,weapon=''):
    r,s,m=base(slug,name,length,width,deck,wheels,radius,lod,scale=scale,axles=axles,front=front,weapon=weapon,source=source,features=features,
        representative='Public Korean exterior; dimensions and local fittings estimated, not a measured technical replica. Operator service, orders and subvariant uncertainties are separated in research/evidence.json.')
    s.family='korean_original'
    L=length/2;W=width/2
    profile_hull(m,'paint',[(L-.20,.46,W-.38),(L,deck*.68,W-.18),(L*.54,deck,W-.16),(-L+.14,deck,W-.16),(-L,.52,W-.30)])
    for side in (-1,1):
        m.box('paint',(side*(W-.09),deck*.70,0),(.16,.10,length-.32))
        m.box('rubber',(side*(W-.18),.55,-L+.06),(.40,.62,.05))
        m.box('paint',(side*(W-.19),deck-.22,-.48),(.10,.25,.48))
        m.box('markings',(side*(W-.145),deck-.22,-.48),(.02,.21,.44))
    lamps(m,width,deck*.71,L-.07,lod)
    r.add('Engine_Deck','Hull',(.60,deck,(.50 if front else -.55)*L));r.add('Exhaust','Hull',(W-.10,deck-.14,(.50 if front else -.70)*L))
    return r,s,m

def secondary_hmg(r,lod,p,parent='Turret'):
    p=np.asarray(p,dtype=float);t=Mesh();t.box('metal_dark',p+[0,.14,0],(.12,.28,.12));r.add('HMG_Turret',parent,p,t,'Y')
    q=p+[0,.36,0];g=Mesh();g.box('metal_dark',q+[0,0,.06],(.15,.15,.40))
    if lod:g.box('metal_dark',q+[0,0,.64],(.04,.04,.78))
    else:
        g.tube('metal_dark',q+[0,0,.25],q+[0,0,1.02],.026,12)
        hollow_muzzle(g,q+[0,0,1.02],q+[0,0,1.08],.029,.00635,12)
        g.box('metal_dark',q+[.19,-.1,0],(.2,.25,.29))
    r.add('HMG_Gun','HMG_Turret',q,g,'X');r.add('HMG_Muzzle','HMG_Gun',q+[0,0,1.08])

def artillery__k55a1(lod=0):
    r,s,h=body('artillery__k55a1','K55A1',lod,6.61,3.15,1.50,7,.30,.87,GUIDE,
        ['seven road wheels and front drive','M109-derived high box turret, distinct from K9','155mm39cal barrel and open-frame muzzle brake','rear turret bustle and external baskets','folded forward travel lock'],weapon='howitzer')
    t=Mesh();b=[(-.48,.75),(.48,.75),(1.24,.37),(1.24,-1.78),(.96,-2.30),(-.96,-2.30),(-1.24,-1.78),(-1.24,.37)]
    a=[(-.43,.50),(.43,.50),(1.15,.20),(1.15,-1.68),(.91,-2.12),(-.91,-2.12),(-1.15,-1.68),(-1.15,.20)]
    loft(t,'paint',[[(x,1.64,z) for x,z in b],[(x,2.78,z) for x,z in a]])
    t.box('paint',(0,2.19,-2.22),(1.15,.67,.20));t.box('paint',(1.23,2.25,-.77),(.08,.72,.61))
    hatch(t,.65,2.79,-.78,.59,.65,lod);hatch(t,-.54,2.79,-1.15,.58,.66,lod)
    t.box('paint',(-.61,2.91,.04),(.39,.24,.34));t.box('glass',(-.61,2.93,.22),(.24,.11,.025))
    if not lod:
        for side in (-1,1):
            for z in (-1.95,-1.52,-1.09):beam(t,'paint',(side*1.32,1.94,z),(side*1.32,2.47,z),.025)
            beam(t,'paint',(side*1.32,2.47,-1.95),(side*1.32,2.47,-1.09),.025)
        for z in np.linspace(.66,1.75,11):h.box('metal_dark',(.67,1.515,z),(.74,.025,.04))
    r.add('Turret','Hull',(0,1.58,-.70),t,'Y')
    q=np.array([0,2.16,.22]);g=Mesh();g.box('paint',q+[0,0,.15],(.71,.58,.70));n=8 if lod else 20
    g.tube('metal_dark',q+[0,0,.40],(0,q[1],5.41),.10,n)
    g.tube('paint',(0,q[1],2.76),(0,q[1],3.32),.155,n)
    for z in (1.18,2.57,4.15):g.tube('paint',(0,q[1],z),(0,q[1],z+.08),.116,6 if lod else 14)
    hollow_muzzle(g,(0,q[1],5.29),(0,q[1],5.41),.10,.0775,n)
    # The recognition feature is an open brake, not a solid muzzle cuboid.
    for za,zb,ix,iy in ((5.40,5.46,.0775,.0775),(5.75,5.81,.13,.15)):
        nn=8 if lod else 16
        def ring(a,z,inner=False):return [(ix if inner else .18)*math.cos(a),q[1]+(iy if inner else .20)*math.sin(a),z]
        for i in range(nn):
            a0=math.tau*i/nn;a1=math.tau*(i+1)/nn;out=[math.cos((a0+a1)/2),math.sin((a0+a1)/2),0]
            g.face('metal_dark',[ring(a0,zb),ring(a1,zb),ring(a1,zb,True),ring(a0,zb,True)],[0,0,1])
            g.face('metal_dark',[ring(a0,za),ring(a1,za),ring(a1,za,True),ring(a0,za,True)],[0,0,-1])
            g.face('metal_dark',[ring(a0,za),ring(a1,za),ring(a1,zb),ring(a0,zb)],out)
            g.face('metal_dark',[ring(a0,za,True),ring(a1,za,True),ring(a1,zb,True),ring(a0,zb,True)],-np.array(out))
    for a in (math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4):
        x=.16*math.cos(a);y=q[1]+.18*math.sin(a);beam(g,'metal_dark',(x,y,5.44),(x,y,5.78),.045)
    r.add('Gun','Turret',q,g,'X');r.add('Muzzle','Gun',(0,q[1],5.82))
    lock=Mesh();beam(lock,'paint',(-.20,1.56,2.54),(-.20,1.61,1.81),.08);beam(lock,'paint',(.20,1.56,2.54),(.20,1.61,1.81),.08)
    r.add('Travel_Lock','Hull',(0,1.54,2.54),lock,'X',state='folded')
    secondary_hmg(r,lod,(.62,2.81,-.77));s.details.update(calibre_mm=155,nominal_overall_length_m=9.12)
    return r,s

def aaVehicle__k263a3_vulcan(lod=0):
    r,s=k200_body(lod,'aaVehicle__k263a3_vulcan','K263A3 Vulcan',0)
    h=next(p['mesh'] for p in r.parts if p['name']=='Hull')
    remove(r,'Turret','Hatch_Roof_L','Hatch_Roof_R');s.weapon='rotary_cannon';s.source=VULCAN;s.family='korean_k263'
    s.features=['five K200family road wheels and front drive','M16820mm six-barrel rotary Vulcan','open gunner shield, not an enclosed missile turret','single rotary-cannon elevation and azimuth mount']
    s.representative='K263A3family exterior. USArmy2025recognition reference identifies A3upgrade. Original2013operator photograph identifies the hull and open Vulcan mount, not the later electronics of every hull.2026operator reports Vulcan family activity without per-hull A3configuration certification; fine sensor fit estimated.'
    h.box('paint',(0,1.98,-1.10),(1.72,.08,1.94));h.box('paint',(0,1.02,-.60),(2.30,.10,3.80))
    p=np.array([0,2.0,-.60]);t=Mesh();t.tube('metal_dark',p,p+[0,.10,0],.63,8 if lod else 20)
    for side in (-1,1):
        x=side*.49
        loft(t,'paint',[[(x-.07,2.09,-1.10),(x+.07,2.09,-1.10),(x+.07,2.09,.08),(x-.07,2.09,.08)],
                        [(x-.06,2.73,-1.05),(x+.06,2.73,-1.05),(x+.06,2.73,-.03),(x-.06,2.73,-.03)]])
        t.box('paint',(side*.33,2.39,.03),(.34,.63,.09))
    t.box('metal_dark',(-.27,2.30,-1.04),(.37,.12,.31));t.box('paint',(-.43,2.65,-.08),(.17,.13,.20));t.box('glass',(-.43,2.65,.032),(.10,.07,.025))
    r.add('Turret','Hull',p,t,'Y');q=np.array([0,2.38,-.15]);g=Mesh();g.box('metal_dark',q+[0,0,-.24],(.31,.36,.67))
    r.add('Gun','Turret',q,g,'X');rotor=Mesh();n=4 if lod else 10;length=1.46;tips=[]
    for i in range(6):
        a=2*math.pi*i/6;off=np.array([.043*math.cos(a),.043*math.sin(a),0]);start=q+off+[0,0,.10];tip=q+off+[0,0,length]
        rotor.tube('metal_dark',start,tip-[0,0,.08],.014,n);hollow_muzzle(rotor,tip-[0,0,.08],tip,.014,.010,n);tips.append(tip)
    for z in (.31,1.18):rotor.tube('metal_dark',q+[0,0,z],q+[0,0,z+.055],.063,6 if lod else 18)
    r.add('Gun_Rotor','Gun',q,rotor,'Z')
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Gun_Rotor',tip)
    r.add('Muzzle','Gun',q+[0,0,length]);s.details.update(rotary_barrels=6,rotary_muzzles=[p.tolist() for p in tips],radar=False,sensor_subvariant_estimated=True)
    return r,s

def aaVehicle__k30w_chunho(lod=0):
    r,s,h=body('aaVehicle__k30w_chunho','K30W Chunho AAGW',lod,7.40,2.70,2.20,4,.55,1.,CHUNHO,
        ['K808family eight-wheel boat hull','four axles, no tracks','twin30mm cannon and forward electro-optical head','open rear turret basket','no invented on-board search radar or missile pack'],
        axles=[-2.52,-1.04,.96,2.52])
    door=Mesh();v=[(x,y,z+dz) for dz in (-.035,.035) for x,y,z in [(-.74,.59,-3.73),(.74,.59,-3.73),(.74,1.98,-3.61),(-.74,1.98,-3.61)]]
    door.solid('paint',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    r.add('Ramp','Hull',(0,.59,-3.73),door,'X');hatch(h,-.52,2.21,1.75,.62,.67,lod)
    for x in (-.76,-.52,-.28):h.box('glass',(x,2.29,2.04),(.17,.09,.11))
    if not lod:
        for z in np.linspace(1.05,2.10,11):h.box('metal_dark',(.56,2.215,z),(.73,.025,.042))
    t=Mesh();p=np.array([0,2.26,-.30]);fp=[(-.65,.96),(.65,.96),(1.04,.45),(1.01,-1.43),(-1.01,-1.43),(-1.04,.45)]
    loft(t,'paint',[[(x,2.26,z-.30) for x,z in fp],[(x*.91,3.11,z*.93-.30) for x,z in fp]])
    t.tube('metal_dark',p-[0,.05,0],p+[0,.07,0],.73,8 if lod else 20)
    for side in (-1,1):
        for z in (-1.78,-1.31,-.84):beam(t,'paint',(side*1.12,2.64,z),(side*1.12,3.17,z),.027)
        beam(t,'paint',(side*1.12,3.17,-1.78),(side*1.12,3.17,-.84),.027)
        t.box('paint',(side*1.04,2.90,-.92),(.16,.40,.74))
    t.box('paint',(-.36,3.23,.28),(.36,.35,.39));t.box('glass',(-.36,3.25,.489),(.24,.18,.025))
    r.add('Turntable','Hull',p,t,'Y');q=np.array([0,2.79,.13]);g=Mesh();g.box('paint',q,(1.58,.29,.52));tips=[]
    for side in (-1,1):
        x=side*.83;g.box('paint',(x,q[1],.13),(.31,.43,.73));end=np.array([x,q[1],2.83]);tips.append(end.tolist())
        g.tube('metal_dark',(x,q[1],.46),end-[0,0,.12],.043,6 if lod else 16)
        hollow_muzzle(g,end-[0,0,.12],end,.043,.015,6 if lod else 16)
        for z in (.76,1.82):g.tube('paint',(x,q[1],z),(x,q[1],z+.075),.062,6 if lod else 12)
    r.add('Launcher','Turntable',q,g,'X')
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Launcher',tip)
    s.details.update(tube_count=2,muzzle_positions=tips,radar=False,electro_optical=True)
    return r,s

def shortRangeSAM__k31_chunma(lod=0):
    r,s,h=body('shortRangeSAM__k31_chunma','K31 Chunma',lod,7.00,3.40,1.72,6,.34,.89,CHUNMA,
        ['six road wheels, long K200-derived chassis','eight cylindrical closed missile containers in two2x2banks','central circular tracking-radar cover','tall rotating rectangular search radar','rear side ventilation galleries'])
    for side in (-1,1):
        h.box('paint',(side*1.57,2.02,-1.86),(.17,.55,1.88))
        if not lod:
            for z in np.linspace(-2.65,-1.08,13):h.box('metal_dark',(side*1.665,2.02,z),(.025,.41,.048))
        for j in range(4):
            a=np.array([side*(.93+j*.15),1.65,2.14]);h.tube('metal_dark',a,a+[side*.10,.17,.20],.044,6 if lod else 10)
    hatch(h,-.64,1.73,1.59,.58,.68,lod)
    t=Mesh();p=np.array([0,1.82,-.30]);t.box('paint',(0,2.15,-.42),(1.35,.66,1.80))
    t.tube('metal_dark',p-[0,.08,0],p+[0,.15,0],.71,8 if lod else 20)
    t.box('paint',(0,3.10,-.72),(.43,1.80,.48));t.box('glass',(-.40,2.73,.55),(.19,.19,.10))
    r.add('Turntable','Hull',p,t,'Y');q=np.array([0,2.72,-.35]);g=Mesh();tips=[];n=6 if lod else 18
    g.box('paint',q,(2.36,.18,.34))
    for side in (-1,1):
        for dx in (-.19,.19):
            for dy in (-.19,.19):
                x=side*1.22+dx;y=q[1]+dy;z=1.32
                g.tube('paint',(x,y,-1.27),(x,y,z),.151,n)
                g.tube('metal_dark',(x,y,z+.004),(x,y,z+.016),.137,n);tips.append([x,y,z+.018])
        for z in (-.96,.56):
            for d in (-.37,.37):
                g.box('paint',(side*1.22,q[1]+d,z),(.80,.055,.10))
                g.box('paint',(side*1.22+d,q[1],z),(.055,.69,.10))
    r.add('Launcher','Turntable',q,g,'X')
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Launcher',tip)
    tracker=Mesh();tracker.tube('rubber',(0,2.84,.33),(0,2.84,.505),.61,10 if lod else 32)
    tracker.tube('paint',(0,2.84,.49),(0,2.84,.55),.58,10 if lod else 32)
    r.add('Radar_Tracking','Turntable',(0,2.84,.34),tracker,'X',sensor='covered circular tracking antenna')
    radar(r,'Turntable',(0,3.92,-.72),lod,width=1.78,height=.92)
    s.details.update(tube_count=8,muzzle_positions=tips,radar=True,road_wheels_observed=6,selected_radar_fit='legacy exterior; current per-hull PIP state not certified')
    return r,s

def mineClearer__k600_rhino(lod=0):
    r,s,h=body('mineClearer__k600_rhino','K600 combat engineering vehicle',lod,7.47,3.60,1.48,6,.35,.94,K600,
        ['K1A1derived six-wheel chassis and rear drive','split toothed mine plough;3.8m published clearance, physical span estimated','slewing excavator and two boom joints','rounded offset crew cab and manual12.7mm','rear route-marking boxes'],front=False,weapon='manual_hmg')
    cab=Mesh();rings=[]
    for y,rx,rz in ((1.48,1.12,1.39),(2.34,.89,1.14)):
        rings.append([(-.44+rx*math.cos(a),y,.26+rz*math.sin(a)) for a in np.linspace(0,2*math.pi,10,endpoint=False)])
    loft(cab,'paint',rings);cab.box('paint',(-.44,2.37,.28),(.68,.08,.70))
    for x in (-.72,-.44,-.16):cab.box('glass',(x,2.24,1.32),(.18,.10,.055))
    r.add('Crew_Cab','Hull',(-.44,1.48,.26),cab)
    gun_station(r,lod,-.44,2.40,.13)
    p=np.array([.85,1.77,.50]);az=Mesh();az.tube('metal_dark',p,p+[0,.18,0],.39,6 if lod else 16)
    r.add('Boom','Hull',p,az,'Y')
    a=np.array([.85,1.95,.50]);b=np.array([.85,2.78,3.22]);c=np.array([.85,1.34,4.02])
    arm=Mesh();beam(arm,'paint',a,b,.29);beam(arm,'metal_dark',a+[0,.13,.10],b+[0,-.15,-.31],.10)
    arm.tube('paint',b-[.25,0,0],b+[.25,0,0],.17,6 if lod else 14)
    r.add('Boom_Main','Boom',a,arm,'X')
    stick=Mesh();beam(stick,'paint',b,c,.23);beam(stick,'metal_dark',b+[0,-.16,-.10],c+[0,.22,-.09],.085)
    r.add('Boom_Stick','Boom_Main',b,stick,'X')
    bucket=Mesh();profile_hull(bucket,'metal_dark',[(4.02,1.36,.30),(4.38,1.15,.30),(4.43,.99,.30),(3.99,1.03,.30)])
    bucket.shift([.85,0,0]);r.add('Bucket','Boom_Stick',c,bucket,'X')
    blade=Mesh();ys=[.62,.91,1.21,1.40];bend=[.15,0,.025,.14]
    for side in (-1,1):
        xa,xb=(0,2.05) if side>0 else (-2.05,0)
        def point(x,j,offset=0):return [x,ys[j],5.25-.43*abs(x)+bend[j]+offset]
        for j in range(3):
            blade.face('metal_dark',[point(xa,j),point(xb,j),point(xb,j+1),point(xa,j+1)],[0,0,1])
            blade.face('metal_dark',[point(xa,j,-.065),point(xb,j,-.065),point(xb,j+1,-.065),point(xa,j+1,-.065)],[0,0,-1])
        for j,normal in ((0,[0,-1,0]),(3,[0,1,0])):blade.face('metal_dark',[point(xa,j),point(xb,j),point(xb,j,-.065),point(xa,j,-.065)],normal)
        x=side*2.05
        for j in range(3):blade.face('metal_dark',[point(x,j),point(x,j+1),point(x,j+1,-.065),point(x,j,-.065)],[side,0,0])
    for x in np.linspace(-1.93,1.93,18 if not lod else 12):
        z=5.25-.43*abs(x)
        v=[(x+dx,y,zz) for dx in (-.035,.035) for y,zz in ((.38,z+.40),(.78,z+.03),(.62,z-.10))]
        blade.solid('paint',v,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)])
    for x in (-1.38,1.38):
        beam(blade,'paint',(x,.94,3.64),(x,1.16,4.68),.17)
        beam(blade,'paint',(x,1.39,4.65),(x,1.66,4.55),.035)
    beam(blade,'paint',(-1.85,1.66,4.55),(1.85,1.66,4.55),.035)
    r.add('Spade','Hull',(0,.94,3.64),blade,'X',equipment='split mine plough in raised transport position; physical span estimated')
    for side in (-1,1):
        h.box('paint',(side*1.42,1.85,-2.64),(.31,.80,.60))
        h.box('paint',(side*1.38,1.24,2.80),(.20,.16,.25))
        h.box('paint',(side*1.38,1.78,2.80),(.13,1.12,.13))
    if not lod:
        for z in np.linspace(-2.88,-1.70,12):h.box('metal_dark',(.20,1.50,z),(1.10,.035,.045))
    s.details.update(published_clearance_width_m=3.8,estimated_plough_span_m=4.1,selected_fit='first-production exterior with interchangeable bucket; later2025contract deliveries not all complete')
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('artillery__','mineClearer__','aaVehicle__','shortRangeSAM__')) and callable(f)}
def save(slug):
    from validate_p3_artillery import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    priority='P3' if slug.startswith('artillery__') else 'P2' if slug.startswith('mineClearer__') else 'P4'
    c=Mesh();c.box('metal_dark',(0,s.roof/2,0),(s.width,s.roof,s.length));path=common.ART/'vehicles'/(slug+'.glb')
    write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':priority,'spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','canonical_track_path':{'half':3.23,'radius':.57,'y':.65},'research_addition':True})
    e,tree=validate(path);e['notes']+=' Original generate_inventory_additions_19.py; actual platform-specific exteriors, estimated local fittings; sources and variant limits in research/evidence.json.'
    e['has_radar']=bool(s.details.get('radar'));e['validation']['radar_axes_checked']=bool(s.details.get('radar'))
    (Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    return e
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
