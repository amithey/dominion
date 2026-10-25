"""South Korean service additions: original Python exterior meshes.

K1E1/K1A2 and K200A1/K242A1/K281A1. Mortars are carried horizontally inside
their closed rear bay for transport; real floor yaw/trunnion pivots permit
elevation after the roof doors open. No weapon internals or imported geometry.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from generate_p1_tanks import Spec,finish,basket,beam
import generate_expansion_armour as tanks
import generate_inventory_additions as common
from generate_inventory_additions_12 import base,remove,hatch,lamps,gun_station
from vehicle_parts import Mesh,profile_hull,loft,hollow_muzzle,write_glb
from armour_parts import wreck

DAPA='https://dapa.go.kr/dapa/doc/selectDoc.do?bbsSeq=326&docSeq=20549&menuSeq=3069'
ROTE='https://www.hyundai-rotem.co.kr/ko/company/press/details.do?seq=1051'

def k1(lod,upgun):
    slug='k1a2' if upgun else 'k1e1';cal=.120 if upgun else .105
    s=Spec(slug,'K1A2' if upgun else 'K1E1',7.47,3.60,1.38,2.25,6,.35,.94,.02,1.85,1.36,9.71 if upgun else 9.67,'korean_k1',
        ['six road wheels and rear drive','low welded angular Korean turret','120mmL44smoothbore' if upgun else '105mmrifled gun',
         'left hull driver','two raised turret sights','fume extractor and rear bustle baskets','fielded digital upgrade, no invented APS'],ROTE,
        caliber=cal,approximate=True,skirts=5,
        representative='Public K1family dimensions and contours estimated from manufacturer exteriors;105mm K1E1 versus120mm K1A2. DAPA2024 completion of A1toA2 upgrade and2025service evidence are separate from any claim of current per-hull readiness.')
    b=[(-.40,1.60),(.40,1.60),(1.48,.59),(1.47,-1.58),(1.10,-1.94),(-1.10,-1.94),(-1.47,-1.58),(-1.48,.59)]
    t=[(-.40,.91),(.40,.91),(1.28,.37),(1.31,-1.54),(1.04,-1.83),(-1.04,-1.83),(-1.31,-1.54),(-1.28,.37)]
    if upgun:
        b=[(-.48,1.72),(.48,1.72),(1.56,.70),(1.50,-1.62),(1.14,-2.02),(-1.14,-2.02),(-1.50,-1.62),(-1.56,.70)]
        t=[(-.48,.99),(.48,.99),(1.37,.48),(1.35,-1.58),(1.08,-1.91),(-1.08,-1.91),(-1.35,-1.58),(-1.37,.48)]
    def details(h,m,s,l):
        for side in (-1,1):
            # Two distinct angular cheeks; the A2 mantlet and frontal pack are
            # broader, rather than making a scaledK2 or generic Abrams turret.
            width=.87 if upgun else .73
            m.box('paint',(side*.90,1.87,.98),(width,.43,.32))
            m.box('paint',(side*1.40,1.97,-.10),(.18,.23,.79))
            for j in range(3):
                q=np.array([side*1.48,1.92,-.02-j*.17]);m.tube('metal_dark',q,q+[side*.18,.12,.10],.038,6 if l else 10)
        for x,z,hh in ((-.66,.69,.26),(.58,-.14,.31 if upgun else .22)):
            m.box('paint',(x,2.27,z),(.40,hh,.43));m.box('glass',(x,2.29,z+.226),(.27,hh*.55,.025))
        basket(m,s,l,z=-2.11,width=2.73)
        h.box('paint',(-.55,1.43,2.25),(.64,.12,.63))
        for x in (-.82,-.55,-.28):h.box('glass',(x,1.52,2.44),(.17,.07,.10))
        h.box('glass',(0,1.04,s.length/2-.035),(.16,.09,.025))
        if not l:
            for x in (-1.11,1.11):m.box('paint',(x,2.13,-1.22),(.46,.36,.73))
    r,s=finish(s,b,t,lod,details);remove(r,'Gun');m=Mesh();p=np.array([0,s.gun_y,s.gun_z]);end=s.overall_length-s.length/2
    m.box('paint',p+[0,0,.12],(.74 if upgun else .62,.48,.64))
    m.tube('metal_dark',p+[0,0,.32],(0,s.gun_y,end-.12),.087 if upgun else .074,8 if lod else 20)
    m.tube('paint',p+[0,0,1.81],p+[0,0,2.29],.142 if upgun else .126,8 if lod else 20)
    for z in (p[2]+.71,p[2]+1.61,end-.61):m.tube('paint',(0,s.gun_y,z),(0,s.gun_y,z+.07),.103 if upgun else .090,8 if lod else 16)
    hollow_muzzle(m,(0,s.gun_y,end-.12),(0,s.gun_y,end),.087 if upgun else .074,cal/2,8 if lod else 20)
    r.add('Gun','Turret',p,m,'X');r.add('Muzzle','Gun',(0,s.gun_y,end))
    # The commander's manualHMG is separate from the main-gun trunnion.
    q=np.array([.66,2.30,-.55]);ped=Mesh();ped.box('metal_dark',q+[0,.14,0],(.12,.28,.12))
    r.add('Commander_HMG','Turret',q,ped,'Y');q=q+[0,.36,0];h=Mesh()
    h.box('metal_dark',q+[0,0,.06],(.15,.15,.40))
    if lod:h.box('metal_dark',q+[0,0,.64],(.042,.042,.78))
    else:
        h.tube('metal_dark',q+[0,0,.25],q+[0,0,1.02],.026,12)
        hollow_muzzle(h,q+[0,0,1.02],q+[0,0,1.08],.029,.00635,12)
        h.box('metal_dark',q+[.19,-.10,0],(.20,.25,.29))
    r.add('Commander_HMG_Gun','Commander_HMG',q,h,'X');r.add('Commander_HMG_Muzzle','Commander_HMG_Gun',q+[0,0,1.08])
    return r,s

def tank__k1e1(lod=0):return k1(lod,False)
def tank__k1a2(lod=0):return k1(lod,True)

def k200_body(lod,slug,name,mortar=0):
    r,s,m=base(slug,name,5.49,2.85,2.0,5,.35,lod,scale=.70,weapon='mortar' if mortar else 'manual_hmg',source=DAPA,
        features=['five road wheels and front sprockets','short K200family raked front, spaced sides','manual12.7mm cupola','rear troop ramp',
                  '107mmrear-bay mortar' if mortar==107 else '81mmrear-bay mortar' if mortar else 'troop carrier with paired roof doors'],
        representative='Korean K200A1family public exterior;5.49x2.85m nominal body, local fittings estimated. DAPA2025ergonomic project covered oneprototype of each type, not a completed whole-fleet camera/dash retrofit. Mortar model shows closed transport bay and horizontally stowed exterior tube, not operational internals.')
    s.family='korean_k200'
    profile_hull(m,'paint',[(2.52,.42,.95),(2.745,1.10,1.15),(1.20,2.,1.20),(-2.52,2.,1.20),(-2.745,.51,1.04)])
    # Remove the complete roof plate, then author a real hatch aperture.
    for g in m.groups.values():
        p=np.asarray(g[0]);f=np.asarray(g[3]).reshape(-1,3)
        g[3]=f[~np.all(np.abs(p[f][:,:,1]-2.)<1e-8,axis=1)].reshape(-1).tolist()
    m.box('paint',(0,1.975,.525),(2.40,.05,1.35));m.box('paint',(0,1.975,-2.285),(2.40,.05,.47))
    for side,label in ((-1,'L'),(1,'R')):
        m.box('paint',(side*1.025,1.975,-1.10),(.35,.05,1.90))
        m.box('paint',(side*1.34,1.18,-.05),(.16,.12,5.25))
        m.box('rubber',(side*1.31,.63,-2.60),(.39,.69,.055))
        for z in (-.8,-1.45,-2.1):m.box('metal_dark',(side*1.225,1.78,z),(.04,.12,.19))
        roof=Mesh();roof.box('paint',(side*.425,2.03,-1.10),(.85,.06,1.90))
        beam(roof,'metal_dark',(side*.36,2.10,-.95),(side*.53,2.10,-.95),.025)
        r.add('Hatch_Roof_'+label,'Hull',(side*.85,2.03,-1.10),roof,'Z')
    lamps(m,s.width,1.13,2.68,lod);hatch(m,-.55,2.01,.71,.57,.62,lod)
    for x in (-.77,-.55,-.33):m.box('glass',(x,2.08,.99),(.16,.07,.10))
    if not lod:
        for z in np.linspace(.40,1.10,10):m.box('metal_dark',(.54,2.015,z),(.78,.02,.035))
        for side in (-1,1):
            for j in range(3):
                q=np.array([side*(.80+j*.13),1.72,1.56]);m.tube('metal_dark',q,q+[side*.13,.17,.12],.037,8)
    # Rear door lies flush against the sloped hull closure.
    door=Mesh();verts=[[x,y,z+dz] for dz in (-.04,.04) for x,y,z in [(-.77,.59,-2.74),(.77,.59,-2.74),(.77,1.84,-2.55),(-.77,1.84,-2.55)]]
    centre=np.mean(verts,axis=0)
    for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
        points=np.asarray([verts[i] for i in face]);door.face('paint',points,np.mean(points,axis=0)-centre)
    r.add('Ramp','Hull',(0,.59,-2.74),door,'X')
    m.box('markings',(-1.235,1.61,-.45),(.02,.22,.48));m.box('markings',(1.235,1.61,-.45),(.02,.22,.48))
    gun_station(r,lod,.47,2.02,.28)
    if mortar:
        m.box('paint',(0,1.02,-.60),(2.30,.10,3.80))
        # Rename the secondaryHMG before adding the mortar floor turntable.
        rename={'Turret':'HMG_Turret','Gun':'HMG_Gun','Muzzle':'HMG_Muzzle'}
        for part in r.parts:
            part['name']=rename.get(part['name'],part['name']);part['parent']=rename.get(part['parent'],part['parent'])
        r.pivots={rename.get(n,n):p for n,p in r.pivots.items()}
        p=np.array([0,1.16,-1.43]);turn=Mesh();turn.tube('metal_dark',p-[0,.09,0],p+[0,.06,0],.30,8 if lod else 20)
        r.add('Turret','Hull',p,turn,'Y',purpose='mortar floor traverse bearing')
        q=p+[0,.11,0];g=Mesh();length=1.23 if mortar==107 else .99;radius=.071 if mortar==107 else .055
        g.tube('paint',q,q+[0,0,length-.10],radius,8 if lod else 20)
        hollow_muzzle(g,q+[0,0,length-.10],q+[0,0,length],radius,mortar/2000,8 if lod else 20)
        g.box('metal_dark',q+[0,-.07,.15],(.24,.15,.31))
        r.add('Gun','Turret',q,g,'X',purpose='horizontal transport stow; open roof before elevation')
        r.add('Muzzle','Gun',q+[0,0,length])
        plate=Mesh();diam=.72 if mortar==107 else .56
        plate.tube('paint',(-1.245,1.39,-1.50),(-1.32,1.39,-1.50),diam/2,8 if lod else 20)
        r.add('External_Baseplate','Hull',(-1.245,1.39,-1.50),plate)
        s.details.update(mortar_calibre_mm=mortar,transport_stow=True,roof_must_open_for_elevation=True)
    r.add('Exhaust','Hull',(1.23,1.72,.80));r.add('Engine_Deck','Hull',(.54,2.0,.75))
    return r,s

def apc__k200a1(lod=0):return k200_body(lod,'apc__k200a1','K200A1')
def artillery__k242a1(lod=0):return k200_body(lod,'artillery__k242a1','K242A1',107)
def artillery__k281a1(lod=0):return k200_body(lod,'artillery__k281a1','K281A1',81)

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('tank__','apc__','artillery__')) and callable(f)}
def save(slug):
    if slug.startswith('tank__'):
        tanks.BUILDERS[slug]=BUILDERS[slug];e=tanks.save(slug)
    elif slug.startswith('apc__'):
        common.BUILDERS[slug]=BUILDERS[slug];e=common.save(slug)
    else:
        from validate_p3_artillery import validate
        a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
        c=Mesh();c.box('metal_dark',(0,s.roof/2,0),(s.width,s.roof,s.length));path=common.ART/'vehicles'/(slug+'.glb')
        write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P3','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','canonical_track_path':{'half':3.23,'radius':.57,'y':.65},'research_addition':True})
        e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree)
    e['notes']+=' Original generator generate_inventory_additions_18.py; unchanged canonical TrackPath, current service and prototype-only improvements distinguished in research ledger.'
    return e
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
