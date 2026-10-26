"""Original Korean selected exteriors, authored in Python, no Blender.

Public operator/manufacturer photographs guide recognition. Local measurements
and the selected fit are estimates, not factory drawings or fleet certification.
The rear-facing K105 mount keeps +Z along its own bore while the truck faces +Z.
Old assets, shared track vertices and the original P3 checker are unchanged.
"""
from pathlib import Path
from dataclasses import asdict,replace
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,profile_hull,loft,hollow_muzzle,write_glb,rotation,merge_mesh
from generate_p1_tanks import beam
from generate_inventory_additions_12 import base,remove,hatch,lamps
from generate_inventory_additions_18 import k200_body
from generate_inventory_additions_19 import body
from generate_inventory_additions_26 import truck,truck_wheel,outriggers
from armour_parts import ArmourSpec,road_tyre,wreck
import generate_inventory_additions as common

K21='https://kookbang.dema.mil.kr/newsWeb/20260624/6/ATCE_CTGR_0010030000/view.do'
K288='https://dapa.go.kr/jfile/board/readDownloadFile.do?fileNum=1&fileType=WT_CMS_DOC&fileTypeSeq=16190'
K239='https://kookbang.dema.mil.kr/newsWeb/20230816/1/ATCE_CTGR_0020010016/view.do'
KH179='https://www.hyundai-wia.com/lib/common/download.asp?file=%2Fupload%2Fdownload%2FHyundaiWia_Brochure_Korean.pdf'
K105='https://kookbang.dema.mil.kr/newsWeb/20260618/5/ATCE_CTGR_0010030000/view.do'


def rearward(r,name,s):
    """Rotate a complete authored mount, preserving its local +Z bore frame.

    Only the mount bind frame is changed. Hull, axle frames and +Z vehicle front
    stay fixed. Descendant world meshes/pivots are rotated together; the writer
    converts them back into their actual parent-local rest frames.
    """
    p=r.pivots[name];R=rotation([0,1,0],math.pi);selected={name}
    for part in r.parts:
        if part['parent'] in selected:selected.add(part['name'])
        if part['name'] not in selected:continue
        q=p+R@(part['pivot']-p);part['pivot']=q;r.pivots[part['name']]=q
        if part.get('mesh'):
            for g in part['mesh'].groups.values():
                if g[0]:g[0][:]=(np.asarray(g[0])@R.T+p-R@p).tolist();g[1][:]=(np.asarray(g[1])@R.T).tolist()
        if part['name']==name:part['extras']['frame_rotation']=[0,1,0,0]
    s.details.update(neutral_mount_yaw_degrees=180,weapon_forward='+Z in weapon bind frame; -Z in vehicle world frame',preserve_rest_basis_during_animation=True)
    if 'muzzle_positions' in s.details:s.details['muzzle_positions']=[r.pivots['Muzzle_'+str(i)].tolist() for i in range(s.details['tube_count'])]


def ifv__k21_korean_legacy(lod=0):
    r,s,h=body('ifv__k21_korean_legacy','K21 selected Korean 40mm exterior',lod,6.90,3.40,1.94,6,.32,.81,K21,
        ['six road wheels, front sprockets and unchanged canonical tracks','boat-like bow and broad side flotation covers','distinct low angular two-man turret with40mm gun and coaxial7.62mm','two roof hatches, tall optical blocks and open rear basket','no unverified Bradley-style twin ATGM box on this selected current fit'],weapon='k21')
    for side in (-1,1):
        h.box('paint',(side*1.64,1.46,-.10),(.20,.79,5.32))
        for z in (-2.13,-.65,.85,2.16):h.box('metal_dark',(side*1.751,1.77,z),(.022,.09,.13))
        h.box('paint',(side*1.55,1.84,-2.49),(.30,.22,.27))
    hatch(h,-.58,1.95,1.61,.58,.66,lod)
    for x in (-.81,-.58,-.35):h.box('glass',(x,2.02,1.90),(.17,.07,.10))
    if not lod:
        for z in np.linspace(1.20,2.07,12):h.box('metal_dark',(.65,1.958,z),(.89,.025,.042))
    # Separate rear access ramp, with its physical bottom transverse hinge.
    d=Mesh();d.box('paint',(0,1.19,-3.40),(1.45,1.27,.08));d.box('metal_dark',(0,1.78,-3.45),(.37,.04,.025))
    r.add('Ramp','Hull',(0,.555,-3.40),d,'X')
    p=np.array([0,1.98,-.38]);t=Mesh()
    b=[(-.38,1.27),(.38,1.27),(.97,.54),(.98,-.79),(.68,-1.14),(-.68,-1.14),(-.98,-.79),(-.97,.54)]
    a=[(-.33,.96),(.33,.96),(.84,.40),(.83,-.76),(.59,-1.04),(-.59,-1.04),(-.83,-.76),(-.84,.40)]
    loft(t,'paint',[[p+[x,.10,z] for x,z in b],[p+[x,.62,z] for x,z in a]])
    hatch(t,-.47,2.61,-.77,.51,.57,lod);hatch(t,.47,2.61,-.70,.51,.57,lod)
    for x,y,z,w in ((.47,2.75,.12,.38),(-.48,2.82,-.16,.32)):
        t.box('paint',(x,y,z),(w,.29,.37));t.box('glass',(x,y,z+.195),(w*.73,.17,.025))
    for side in (-1,1):
        for j in range(3):
            q=np.array([side*(.83+j*.055),2.37,-.03-j*.14]);t.tube('metal_dark',q,q+[side*.10,.09,.19],.035,6 if lod else 10)
        beam(t,'paint',(side*.88,2.15,-1.56),(side*.88,2.15,-1.99),.045)
        beam(t,'paint',(side*.88,2.15,-1.99),(side*.88,2.57,-1.99),.035)
        beam(t,'paint',(side*.88,2.57,-1.99),(side*.88,2.57,-1.46),.035)
        t.tube('metal_dark',(side*.74,2.60,-1.28),(side*.74,3.30,-1.28),.014,4 if lod else 6)
    beam(t,'paint',(-.88,2.57,-1.99),(.88,2.57,-1.99),.035)
    if not lod:
        for x in np.linspace(-.70,.70,6):beam(t,'metal_dark',(x,2.15,-1.99),(x,2.57,-1.99),.016)
    r.add('Turret','Hull',p,t,'Y');q=np.array([0,2.31,.66]);g=Mesh();n=8 if lod else 24
    g.box('paint',q+[0,0,.08],(.48,.40,.50));g.tube('metal_dark',q+[0,0,.27],q+[0,0,2.89],.047,n)
    g.tube('paint',q+[0,0,.31],q+[0,0,.65],.071,n)
    for z in (1.01,2.18):g.tube('metal_dark',q+[0,0,z],q+[0,0,z+.06],.055,n)
    hollow_muzzle(g,q+[0,0,2.89],q+[0,0,2.99],.052,.020,n)
    g.tube('metal_dark',q+[.24,-.02,.13],q+[.24,-.02,.62],.021,6 if lod else 12)
    r.add('Gun','Turret',q,g,'X');r.add('Muzzle','Gun',q+[0,0,2.99]);r.add('Muzzle_Coax','Gun',q+[.24,-.02,.62])
    s.details.update(selected_fit='June2026operatorphotos; 40mmlegacy exterior, no unverified missile box',k21_fourth_batch_order='signed2024, delivery window through2028; not all delivered, future production fit unverified')
    return r,s


def recoveryVehicle__k288a1(lod=0):
    r,s=k200_body(lod,'recoveryVehicle__k288a1','K288A1 light recovery vehicle');remove(r,'Hatch_Roof_L','Hatch_Roof_R')
    h=next(p['mesh'] for p in r.parts if p['name']=='Hull');h.box('paint',(0,1.975,-1.10),(1.70,.05,1.90))
    s.source=K288;s.features=['five K200family road wheels, front drive and canonical tracks','K200boat hull with recovery roof replacing troop roof doors','left roof crane folded forward, yaw/luff/extension and hanging-hook pivots','paired rear anchoring spades with separate collinear Xhinges','manual12.7mm roof gun, closed winch outlet and external tool lockers']
    s.family='korean_k288';s.equipment='slew';s.details.update(recovery_parts=['Boom','Spade'],selected_fit='DAPA2022photographic annex labelled K288A1; 2026exercise identifies K288family, latest per-hull retrofit unverified',crane_stow='forward',crane_raise_positive_x=False,estimated_recovery_dimensions=True)
    for side in (-1,1):
        h.box('paint',(side*.61,2.13,-1.88),(.63,.24,.79))
        if not lod:
            beam(h,'metal_dark',(side*1.05,2.08,-2.10),(side*1.05,2.08,-.57),.035)
            for z in (-2.0,-.65):beam(h,'paint',(side*1.05,2.0,z),(side*1.05,2.18,z),.028)
    p=np.array([-.79,2.03,-.90]);m=Mesh();m.tube('paint',p,p+[0,.42,0],.35,8 if lod else 24)
    r.add('Boom','Hull',p,m,'Y');q=p+[0,.59,0];m=Mesh()
    profile_hull(m,'paint',[(-1.11,2.59,.25),(-1.05,3.03,.25),(1.46,3.01,.21),(1.74,2.70,.18),(1.56,2.59,.21)]);m.shift([-.79,0,0])
    m.tube('metal_dark',q-[.30,0,0],q+[.30,0,0],.13,8 if lod else 20)
    beam(m,'metal_dark',p+[0,.12,.25],(-.79,2.63,.83),.095)
    if not lod:
        for z in (-.45,.38,1.15):m.box('metal_dark',(-1.052,2.80,z),(.026,.10,.20))
    r.add('Boom_Lift','Boom',q,m,'X');m=Mesh();m.box('metal_dark',(-.79,2.73,1.83),(.27,.20,.79))
    m.tube('paint',(-1.01,2.73,2.23),(-.57,2.73,2.23),.10,6 if lod else 16)
    r.add('Boom_Extend','Boom_Lift',(-.79,2.73,1.55),m,translation_axis='Z');m=Mesh()
    m.tube('metal_dark',(-.79,2.64,2.23),(-.79,2.27,2.23),.027,6 if lod else 12)
    beam(m,'metal_dark',(-.79,2.27,2.23),(-.70,2.21,2.23),.055);beam(m,'metal_dark',(-.70,2.21,2.23),(-.65,2.30,2.23),.055)
    r.add('Crane_Hook','Boom_Extend',(-.79,2.64,2.23),m,'X')
    # Both spade hinges lie on the same rear transverse line. The named parent
    # exposes their common fold; each child also retains its own actual hinge.
    r.add('Spade','Hull',(0,1.18,-2.59),axis='X')
    for side,label in ((-1,'L'),(1,'R')):
        q=np.array([side*.89,1.18,-2.59]);m=Mesh();m.box('paint',q+[0,.05,-.19],(.58,.69,.18))
        m.box('metal_dark',q+[0,-.31,-.19],(.62,.065,.20));beam(m,'paint',q,q+[0,-.18,-.25],.15)
        r.add('Spade_'+label,'Spade',q,m,'X')
    m=Mesh();m.box('paint',(0,1.29,-2.79),(.72,.37,.12));m.box('metal_dark',(0,1.29,-2.86),(.46,.12,.025))
    for y in (1.16,1.42):m.tube('metal_dark',(-.25,y,-2.89),(.25,y,-2.89),.038,6 if lod else 14)
    r.add('Winch_Closed_Cover','Hull',(0,1.29,-2.79),m)
    s.representative='K288A1 recovery exterior identified by the labelled DAPA2022annex. Shared K200nominal hull, local crane/spade dimensions estimated. No mechanical rating or final2026retrofit, fleet count or per-hull readiness claimed.'
    return r,s


def mlrs__k239_chunmoo_korean(lod=0):
    r,s,h,bed=truck('mlrs__k239_chunmoo_korean','K239 Chunmoo Korean twin six-cell pods',lod,9.0,2.90,3.05,[-2.90,-1.40,1.46,2.89],.65,K239,'cabover',
        ['Korean8x8 armoured angular cab, not Polish Jelcz export vehicle','two rectangular pod cages, six closed230mm-class canisters per selected pod','rear equipment and cooling modules with two spare wheels behind cab','separate turntable Y and launcher Xhinges with twelve tube-front markers','closed public canister exteriors; no launcher internals or battery layout'])
    h.box('paint',(0,bed,-1.25),(2.78,.18,6.12));h.box('paint',(0,2.05,1.02),(2.51,1.06,1.26))
    for side in (-1,1):
        h.tube('rubber',(side*.69,2.13,1.76),(side*.69,2.13,1.91),.58,8 if lod else 24)
        h.tube('paint',(side*.69,2.13,1.92),(side*.69,2.13,1.94),.29,8 if lod else 20)
        h.box('metal_dark',(side*1.27,2.12,.86),(.035,.64,.85))
        h.box('rubber',(side*1.24,.91,-4.04),(.41,.65,.045));h.box('glass',(side*1.10,1.37,-4.47),(.22,.13,.03))
        if not lod:
            for y in np.linspace(1.88,2.37,8):h.box('paint',(side*1.30,y,.86),(.027,.026,.79))
    p=np.array([0,bed+.18,-.59]);m=Mesh();m.tube('metal_dark',p,p+[0,.21,0],.79,8 if lod else 24)
    r.add('Turntable','Hull',p,m,'Y');q=p+[0,.28,0];m=Mesh();tips=[];n=8 if lod else 24
    for side in (-1,1):
        cx=side*.68
        # The open cage surrounds twelve closed exterior canisters.
        for z in (-.22,3.84):
            for x in (cx-.57,cx+.57):beam(m,'paint',q+[x,.10,z],q+[x,1.01,z],.065)
            for y in (.10,1.01):beam(m,'paint',q+[cx-.57,y,z],q+[cx+.57,y,z],.065)
        for x in (cx-.57,cx+.57):
            for y in (.10,1.01):beam(m,'paint',q+[x,y,-.22],q+[x,y,3.84],.065)
        m.box('paint',q+[cx,.55,1.81],(1.10,.83,4.03))
        for row in range(2):
            for col in range(3):
                a=q+[cx+(col-1)*.34,.36+row*.36,-.245];b=a+[0,0,4.115]
                # Small visible circular ends emerge from the closed pod shell.
                m.tube('paint',a,a+[0,0,.035],.155,n);m.tube('paint',b,b+[0,0,.035],.155,n)
                m.tube('metal_dark',b+[0,0,.04],b+[0,0,.055],.132,n);tips.append((b+[0,0,.06]).tolist())
                if not lod:
                    for angle in (-.66,.66):m.box('paint',b+[0,0,.065],(.24,.025,.016),rotation([0,0,1],angle))
        if not lod:
            for z in (.18,1.32,2.46,3.58):m.box('metal_dark',q+[cx+side*.565,.56,z],(.018,.18,.32))
    m.box('paint',q+[0,.08,1.50],(2.63,.18,3.91))
    r.add('Launcher','Turntable',q,m,'X')
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Launcher',tip)
    s.details.update(tube_count=12,muzzle_positions=tips,selected_fit='Koreanoperator2023launcher photos and2026actualuse; local carrier/rack dimensions estimated',canisters_closed=True,radar=False)
    # Selected transport direction follows the rear-facing tube fronts in the
    # operator loading view. The complete mount retains its own +Z bore frame.
    rearward(r,'Turntable',s)
    return r,s


def towedHowitzer__kh179(lod=0):
    s=ArmourSpec('towedHowitzer__kh179','KH179 Korean reserve/training155mm howitzer',8.40,2.44,1.64,'towed',1,.58,'kh179','towed',
        ['M114derived conventional two-wheel carriage, not M777 titanium frame','long155mm39calibre barrel with open muzzle brake','two massive box trails with separate Yhinges and trail spades','exposed twin external recoil cylinders, hand wheels and small sight','2026reserve and stored-equipment training documented; no whole-fleet retirement assumed'],KH179,approximate=True,
        representative='HyundaiWIAcurrent brochure KH179photo, plus actual2026Korean reserve/storage training. Carrier, gun and small-fitting measurements estimated from public exteriors; not a measured technical replica.',axle_z=[0],details={'inventory_status':'documented_2026_reserve_storage_training','public_exterior_estimates':True})
    r=Rig(lod);m=Mesh();n=8 if lod else 24
    m.tube('metal_dark',(-1.06,.58,0),(1.06,.58,0),.12,n);m.box('paint',(0,.66,-.20),(1.28,.31,.99))
    m.tube('paint',(0,.65,-.20),(0,1.20,-.20),.30,n)
    for side in (-1,1):
        beam(m,'paint',(side*.41,.75,-.45),(side*.40,1.64,.0),.19)
        m.tube('metal_dark',(side*.29,1.64,.0),(side*.49,1.64,.0),.15,n)
        m.box('markings',(side*.512,1.25,-.15),(.018,.20,.32))
    r.add('Carriage',r.root,mesh=m)
    for side,label in ((-1,'L'),(1,'R')):
        p=np.array([side*(s.width/2-.19),s.wheel_radius,0]);m=road_tyre(s,lod,side);m.shift(p);r.add('Wheel_'+label+'0','Carriage',p,m,'X')
        p=np.array([side*.43,.57,-.49]);end=np.array([side*1.29,.23,-3.35]);m=Mesh()
        beam(m,'paint',p,end,.24);m.box('paint',end+[0,-.02,-.08],(.53,.36,.22))
        beam(m,'metal_dark',p+[side*.11,.15,0],end+[side*.11,.15,0],.045)
        if not lod:
            for f in (.22,.46,.70,.88):
                q=p*(1-f)+end*f;m.box('paint',q+[0,.16,0],(.31,.05,.12))
        beam(m,'metal_dark',end+[0,.18,.05],end+[0,.28,.25],.045)
        r.add('Trail_'+label,'Carriage',p,m,'Y')
    q=np.array([0,1.64,0]);g=Mesh();g.box('paint',q+[0,-.10,.44],(.57,.29,1.82))
    g.box('metal_dark',q+[0,0,-.45],(.43,.46,.64));g.tube('metal_dark',q+[0,0,.10],q+[0,0,4.56],.103,n)
    for side in (-1,1):
        g.tube('paint',q+[side*.235,-.16,-.30],q+[side*.235,-.16,1.36],.087,n)
        g.tube('metal_dark',q+[side*.235,-.16,1.36],q+[side*.235,-.16,1.69],.055,n)
    for z in (.86,1.71,3.52):g.tube('paint',q+[0,0,z],q+[0,0,z+.07],.125,n)
    hollow_muzzle(g,q+[0,0,4.56],q+[0,0,4.75],.117,.0775,n)
    # Rounded two-baffle muzzle brake, following the maker's cylindrical outline.
    # Annular collars and separated upper/lower bridges leave the side ports
    # open; there is no solid cuboid or cap across the visible central bore.
    for z in (4.53,4.83):hollow_muzzle(g,q+[0,0,z],q+[0,0,z+.10],.175,.081,n)
    for y in (-.151,.151):g.box('metal_dark',q+[0,y,4.73],(.10,.045,.39))
    r.add('Gun','Carriage',q,g,'X');r.add('Muzzle','Gun',q+[0,0,4.94])
    controls=Mesh();controls.box('paint',(-.57,1.17,-.37),(.42,.09,.41))
    beam(controls,'metal_dark',(-.57,1.17,-.37),(-.57,1.55,-.12),.055)
    for x,y,z in ((-.64,1.45,-.08),(.64,1.12,-.25)):
        controls.tube('metal_dark',(x-.025,y,z),(x+.025,y,z),.17,n)
        if not lod:
            controls.tube('paint',(x-.031,y,z),(x+.031,y,z),.085,n)
    controls.box('paint',(-.43,1.86,.11),(.12,.25,.21));controls.box('glass',(-.43,1.86,.225),(.08,.15,.018))
    r.add('Fire_Controls','Carriage',(-.57,1.45,-.08),controls)
    return r,s


def artillery__k105a1(lod=0):
    r,s,h,bed=truck('artillery__k105a1','K105A1 Korean rear-facing105mm truck howitzer',lod,7.79,2.50,3.0,[-2.40,-1.03,2.14],.57,K105,'bonnet',
        ['Korean5ton6x6 bonneted carrier, not the shorter2.5ton KM250','open rear fighting compartment with tall side protection and crew canopy','short105mm barrel faces aft in the selected neutral mount','separate Ytraverse, Xtrunnion and local+Z muzzle/recoil frame','folding rear access panel and actual ground stabiliser nodes'])
    s.weapon='howitzer';s.family='korean_k105a1';n=8 if lod else 24
    h.box('paint',(0,bed+.10,-1.30),(2.39,.20,4.59))
    for side in (-1,1):
        h.box('paint',(side*1.16,2.15,-1.25),(.10,1.30,3.53))
        h.box('paint',(side*1.16,2.85,-.10),(.10,.14,1.31))
        for z in (-2.46,-1.72,-.98):
            h.box('metal_dark',(side*1.235,2.00,z),(.04,.42,.32));h.box('paint',(side*1.27,1.78,z),(.11,.07,.40))
    h.box('paint',(0,2.94,-.10),(2.43,.11,1.49))
    p=np.array([0,bed+.22,-1.53]);m=Mesh();m.tube('paint',p,p+[0,.37,0],.57,n)
    for side in (-1,1):beam(m,'paint',p+[side*.38,.20,-.18],p+[side*.38,1.01,.13],.18)
    r.add('Turret','Hull',p,m,'Y');q=p+[0,1.05,.10];g=Mesh()
    g.box('metal_dark',q+[0,0,-.24],(.37,.39,.56));g.box('paint',q+[0,-.15,.55],(.46,.24,1.37))
    g.tube('metal_dark',q+[0,0,.05],q+[0,0,2.40],.073,n)
    for side in (-1,1):g.tube('paint',q+[side*.21,-.12,-.14],q+[side*.21,-.12,1.05],.072,n)
    for z in (.35,1.24):g.tube('paint',q+[0,0,z],q+[0,0,z+.08],.094,n)
    hollow_muzzle(g,q+[0,0,2.40],q+[0,0,2.51],.077,.0525,n)
    g.box('paint',q+[-.35,.19,.02],(.18,.23,.26));g.box('glass',q+[-.35,.19,.163],(.10,.13,.02))
    r.add('Gun','Turret',q,g,'X');r.add('Muzzle','Gun',q+[0,0,2.51]);rearward(r,'Turret',s)
    door=Mesh();door.box('paint',(0,1.95,-3.64),(2.24,.84,.10))
    if not lod:
        for y in (1.65,1.87,2.09):beam(door,'metal_dark',(-.48,y,-3.71),(.48,y,-3.71),.035)
    r.add('Ramp','Hull',(0,1.53,-3.64),door,'X')
    # The observed production truck has jacks ahead of the rear firing body.
    outriggers(r,lod,1.48,[.53],1.28)
    s.details.update(selected_fit='actualJune2026operatorphoto; five-ton chassis class confirmed by2021operatorexplanation, local gun/carrier dimensions estimated',carrier_nominal_km500_m=[7.79,2.50,3.0],internal_ammunition_not_modelled=True)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('ifv__','recoveryVehicle__','mlrs__','towedHowitzer__','artillery__')) and callable(f)}

def save(slug):
    from validate_framed_ground import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    if s.mobility=='wheeled':
        for p in a.parts:
            if p['name'].startswith(('Wheel_L','Wheel_R')):
                m=truck_wheel(s.wheel_radius,s.width,-1 if p['name'].startswith('Wheel_L') else 1);m.shift(p['pivot']);p['mesh']=m
    for r in (a,b):
        for p in r.parts:
            if p.get('mesh'):p['mesh'].remove_duplicates()
    key='Carriage' if s.mobility=='towed' else 'Hull'
    pts=np.concatenate([np.asarray(g[0]) for r in (a,b) for p in r.parts if p['name']==key for g in p['mesh'].groups.values() if len(g[0])]);lo=pts.min(0);hi=pts.max(0);lo[1]=0
    c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo);path=common.ART/'vehicles'/(slug+'.glb')
    write_glb(path,[a,b],wreck(b,replace(s,weapon='') if s.mobility=='towed' else s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P2' if slug.startswith(('ifv__','recoveryVehicle__')) else 'P3','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','canonical_track_path':{'half':3.23,'radius':.57,'y':.65},'research_addition':True})
    e,tree=validate(path);e['notes']+=' Original generate_inventory_additions_27.py; source/fit/order qualifications in research/evidence.json. Rear-facing mounts retain local+Z bore, axes in their saved bind frame; vehicle front stays+Z. Preserve bind basis when animating. No photographs, textures or source geometry embedded.'
    (Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
