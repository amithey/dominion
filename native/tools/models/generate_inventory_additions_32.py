"""Original Israeli public exteriors, authored in metres without Blender.

Selected photographic configurations are separate from fleet status. Small
dimensions and fittings are estimates, not factory drawings. The Namer dozer
option is buyer documented; its attachment is an original approximation, not
claimed to be attached in the 2018 display photograph. No reference pixels,
insignia, weapon internals or operating logic are incorporated.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,profile_hull,loft,lathe_x,hollow_muzzle,rotation,write_glb
from generate_p1_tanks import Spec,finish,beam,basket,running_gear,make_wreck
from armour_parts import ArmourSpec,mobility,gearbox_spec,wreck
from generate_inventory_additions_12 import base,remove,hatch,lamps,gun_station
import generate_inventory_additions as common

MANTAK='https://www.mod.gov.il/אגפים/מנתק-מנהלת-המרכבה-והרקם'
PUMA='https://commons.wikimedia.org/wiki/File:Puma_--_Our-IDF-2018-IZE-198_(44814844412).jpg'
MK3='https://commons.wikimedia.org/wiki/File:Merkava_Mk_III_tank_01.jpg'
NAMER='https://commons.wikimedia.org/wiki/File:Nammer-Handasa_--_Our-IDF-2018-IZE-073_(44815210772).jpg'
TIGRIS='https://commons.wikimedia.org/wiki/File:Tigris-APC-0001.jpg'
ZMAG='https://www.iai.co.il/news/redefining-light-maneuver-in-complex-combat-terrain/'
LIMIT='Selected public exterior; principal sizes, small fittings and hinges locally estimated, not factory or fleet-wide configuration/readiness certification. Current equipment and confirmed orders are separate in research/evidence.json.'


def tracked(slug,name,lod,L,W,deck,radius,scale,front,source,features,*,paired=False):
    r,s,h=base(slug,name,L,W,deck,6,radius,lod,scale=scale,front=front,source=source,features=features,weapon='rws',representative=LIMIT)
    s.family='israeli_original';s.details.update(local_photo_estimated_size=True,published_factory_size_unverified=True)
    if paired:
        remove(r,*[f'Wheel_{side}{i}' for side in ('L','R') for i in range(6)],*[f'{n}_{side}' for side in ('L','R') for n in ('Sprocket','Idler')],*[f'Roller_{side}{i}' for side in ('L','R') for i in range(3)],'Track_L','Track_R')
        g=gearbox_spec(s);g.wheel_z=[-2.50,-1.68,-.41,.41,1.68,2.50];running_gear(r,g,lod)
        s.details['wheel_z']=(np.array(g.wheel_z)*scale).tolist();s.details['bogie_pairs']=3
    p=L/2;w=W/2-.39
    profile_hull(h,'paint',[(p-.12,.43,w-.20),(p,deck*.65,w),(p*.46,deck,w),(-p+.14,deck,w),(-p,.53,w-.15)])
    for side in (-1,1):
        h.box('paint',(side*(W/2-.10),deck-.06,0),(.38,.11,L-.10))
        for i,z in enumerate(np.linspace(-p+.56,p-.56,6)):
            h.box('paint',(side*(W/2-.035),deck-.40,z),(.09,.68,(L-.70)/6-.025))
            if not lod:
                for yy in (deck-.13,deck-.64):
                    for dz in (-.30,.30):h.tube('metal_dark',(side*(W/2+.015),yy,z+dz),(side*(W/2+.033),yy,z+dz),.022,6)
    lamps(h,W,deck+.08,p-.36,lod)
    r.add('Engine_Deck','Hull',(.43,deck,(.55 if front else -.65)*p));r.add('Exhaust','Hull',(W/2-.15,deck-.11,(.48 if front else -.70)*p))
    return r,s,h


def manual_mg(r,lod,name,p,parent='Turret'):
    p=np.array(p);m=Mesh();m.tube('metal_dark',p,p+[0,.24,0],.075,6 if lod else 14)
    r.add(name,parent,p,m,'Y');q=p+[0,.26,0];m=Mesh();m.box('metal_dark',q,(.13,.14,.40))
    m.tube('metal_dark',q+[0,0,.18],q+[0,0,.83],.023,6 if lod else 12)
    hollow_muzzle(m,q+[0,0,.83],q+[0,0,.89],.025,.006,6 if lod else 12)
    m.box('metal_dark',q+[.15,-.06,-.03],(.19,.23,.28))
    r.add(name+'_Gun',name,q,m,'X');r.add(name+'_Muzzle',name+'_Gun',q+[0,0,.89])


def mineClearer__puma(lod=0):
    r,s,h=tracked('mineClearer__puma','Puma Israeli Centurion-derived CEV, selected display fit',lod,7.55,3.38,1.76,.36,.94,False,PUMA,
        ['six Centurion road wheels in three paired bogies, rear drive, canonical tracks','low forward sloping casemate, two forward vision shutters','central remote machine-gun station, rear engineering equipment boxes','selected bare tool interface, no invented attached mine plough or German Puma turret'],paired=True)
    cab=Mesh();profile_hull(cab,'paint',[(3.28,1.75,1.19),(2.96,2.01,1.17),(1.48,2.10,1.15),(-1.57,2.10,1.15),(-1.68,1.75,1.19)])
    for side in (-1,1):
        hatch(cab,side*.63,2.115,.46,.59,.64,lod)
        cab.box('paint',(side*.90,2.16,1.69),(.60,.34,.12));cab.box('glass',(side*.90,2.16,1.765),(.48,.22,.025))
        h.box('paint',(side*1.15,2.05,-2.47),(.47,.61,1.06));h.box('paint',(side*1.45,1.94,-2.38),(.16,.36,1.28))
        if not lod:
            zs=s.details['wheel_z']
            for i in (0,2,4):
                z=(zs[i]+zs[i+1])/2;x=side*(s.width/2-.36)
                beam(h,'paint',(x,.72,z),(x,.53,zs[i]),.11);beam(h,'paint',(x,.72,z),(x,.53,zs[i+1]),.11)
    r.add('Puma_Casemate','Hull',(0,1.76,.2),cab);gun_station(r,lod,0,2.11,-.10,remote=True)
    t=next(p['mesh'] for p in r.parts if p['name']=='Turret')
    for side in (-1,1):t.box('paint',(side*.44,2.73,-.10),(.27,.66,.40))
    for z in np.linspace(-3.20,-1.86,7 if lod else 14):h.box('metal_dark',(0,1.78,z),(1.56,.025,.047))
    h.box('paint',(0,.92,3.78),(.51,.40,.13))
    r.add('Front_Tool_Interface','Hull',(0,.92,3.78));s.details.update(selected_fit='2018ZachiEvenor display, remote MG and bare forward interface; continued type presence corroborated2025',attached_tool=False)
    return r,s


def tank__merkava_mk_3_baz(lod=0):
    s=Spec('tank__merkava_mk_3_baz','Merkava III Baz selected Dor Dalet exterior',7.60,3.72,1.57,2.37,6,.365,.96,-.35,2.02,1.03,9.04,'merkava',
        ['six road wheels, front engine/drive','low narrow MkIII turret with separate side armour and deep rear basket','120mm gun with thermal jacket and extractor, no invented Trophy kit','two manual roof guns with individual yaw/elevation pivots','rear basket ball-and-chain exterior approximation'],MK3,front_engine=True,approximate=True,
        representative='Selected Staselnik2013photograph and historical MANTAK MkIII/Baz/DorDalet description. Dated2025IDF-hosted authors discuss retained MkIII family separately; not a claim every hull remains operational in2026 or that all have Trophy. Adopted7.60x3.72m hull/9.04m overall and all fittings are local estimates, not primary factory dimensions.')
    bottom=[(-.35,1.55),(.35,1.55),(1.47,.65),(1.45,-1.59),(1.07,-2.03),(-1.07,-2.03),(-1.45,-1.59),(-1.47,.65)]
    top=[(-.31,1.22),(.31,1.22),(1.23,.44),(1.19,-1.53),(.90,-1.81),(-.90,-1.81),(-1.19,-1.53),(-1.23,.44)]
    def detail(h,t,ss,ll):
        # MkIII rear stowage stays at roof level; the tall generic tank basket
        # would wrongly put its parapet well above the photographed turret.
        t.box('paint',(0,1.87,-2.78),(2.61,.08,.74))
        t.box('paint',(0,2.10,-3.12),(2.61,.45,.06))
        for side in (-1,1):t.box('paint',(side*1.28,2.10,-2.78),(.06,.45,.74))
        if not ll:
            for x in np.linspace(-1.18,1.18,9):beam(t,'metal_dark',(x,1.90,-3.16),(x,2.31,-3.16),.018)
        for side in (-1,1):
            for i,z in enumerate((.22,-.45,-1.12)):
                m=Mesh();profile_hull(m,'paint',[(z+.30,1.85,.105),(z+.27,2.13,.12),(z-.29,2.30,.10),(z-.32,1.94,.09)]);m.shift((side*1.39,0,-.35))
                from vehicle_parts import merge_mesh
                merge_mesh(t,m)
            if not ll:
                for z in np.linspace(-1.85,.80,9):t.tube('metal_dark',(side*1.455,2.05,z-.35),(side*1.485,2.05,z-.35),.025,6)
        if not ll:
            for x in np.linspace(-1.05,1.05,14):
                z=-2.88;beam(t,'metal_dark',(x,1.86,z),(x,1.49,z),.012)
                t.tube('metal_dark',(x,1.45,z),(x,1.52,z),.039,8)
    r,s=finish(s,bottom,top,lod,detail)
    remove(r,'CITV','Gunner_Sight','Commander_MG');m=Mesh();m.box('paint',(-1.02,2.30,.62),(.42,.20,.36));m.box('glass',(-1.02,2.30,.817),(.29,.12,.025));r.add('Gunner_Sight','Turret',(-1.02,2.23,.62),m)
    manual_mg(r,lod,'Commander_MG',(.59,2.43,-.85));manual_mg(r,lod,'Loader_MG',(-.58,2.43,-.92))
    return r,s


def mineClearer__namer_engineering(lod=0):
    r,s,h=tracked('mineClearer__namer_engineering','Namer engineering, buyer-described company dozer option',lod,7.65,3.80,1.73,.37,.98,True,MANTAK,
        ['six Merkava-family road wheels, front engine/drive, canonical tracks','long sloping bow and raised protected engineering crew roof','real remote machine-gun station, closed exterior sensor housings','separate broad dozer Spade on X hinge; no combined plough/roller/bridge fit'])
    cab=Mesh();profile_hull(cab,'paint',[(3.72,1.15,1.39),(3.60,1.66,1.42),(1.50,2.17,1.39),(-3.50,2.17,1.35),(-3.61,1.35,1.30)])
    for side in (-1,1):
        cab.box('paint',(side*1.25,2.36,-.55),(.37,.52,1.40));cab.box('paint',(side*1.24,2.68,-.69),(.31,.30,.49))
        cab.box('metal_dark',(side*1.45,2.39,-.29),(.025,.20,.41))
        for j in range(4):
            p=np.array([side*(1.05+j*.085),2.23,1.23]);cab.tube('metal_dark',p,p+[side*.08,.11,.21],.045,5 if lod else 10)
        if not lod:
            for z in np.linspace(1.58,2.55,12):cab.box('metal_dark',(side*.69,1.94,z),(.48,.025,.035))
    hatch(cab,.38,2.18,-.32,.67,.73,lod);hatch(cab,-.55,2.18,-.69,.65,.69,lod)
    for x in (-.04,.19,.42,.65):cab.box('glass',(x,2.27,.12),(.18,.10,.08))
    r.add('Engineering_Roof','Hull',(0,1.73,0),cab);gun_station(r,lod,-.72,2.20,.35,remote=True)
    r.add('Rear_Ramp','Hull',(0,.58,-3.76),None,'X')
    door=Mesh();door.box('paint',(0,1.28,-3.77),(1.54,1.41,.13));door.box('metal_dark',(0,1.67,-3.85),(.39,.12,.025));r.add('Ramp_Panel','Rear_Ramp',(0,.58,-3.76),door)
    p=np.array([0,1.18,3.47]);m=Mesh();profile_hull(m,'paint',[(4.99,.56,1.91),(5.12,.63,1.91),(4.83,1.48,1.91),(4.70,1.48,1.91)])
    m.box('metal_dark',(0,.595,5.05),(3.82,.075,.15))
    for x in (-1.28,1.28):
        beam(m,'paint',(x,1.18,3.47),(x,.94,4.83),.19);beam(m,'metal_dark',(x,1.40,3.59),(x,1.20,4.61),.075)
    if not lod:
        for x in np.linspace(-1.72,1.72,12):beam(m,'paint',(x,.69,4.97),(x,1.38,4.74),.04)
    r.add('Spade','Hull',p,m,'X',mechanism='estimated external company-dozer lift hinge')
    s.details.update(selected_fit='Buyer-described company dozer option;2018CEV display hull/roof reference has bare coupler, not this blade attached',dozer_attachment_and_hinge_estimated=True,configuration_not_all_three_engineering_options=True)
    s.representative=LIMIT+' '+s.details['selected_fit']+'. No bridging/towing/breach-roller combination or certified internal engineering equipment.'
    return r,s


def dense_tyre(radius,width,side):
    m=Mesh();w=.18;r=radius
    lathe_x(m,[(-w,0,'paint'),(-w,r*.53,'rubber'),(-w*.84,r*.94,'rubber'),(-w*.58,r,'rubber'),(w*.58,r,'rubber'),(w*.84,r*.94,'rubber'),(w,r*.53,'paint'),(w,0,'paint')],segments=40)
    m.tube('paint',(side*(w+.004),0,0),(side*(w+.04),0,0),r*.46,20)
    for a in np.linspace(0,math.tau,8,endpoint=False):
        m.tube('metal_dark',(side*(w+.04),r*.31*math.cos(a),r*.31*math.sin(a)),(side*(w+.062),r*.31*math.cos(a),r*.31*math.sin(a)),.017,6)
    for row in (-1,1):
        for a in np.linspace(0,math.tau,36,endpoint=False):
            a+=row*.025;m.box('rubber',(row*w*.42,(r-.030)*math.cos(a),(r-.030)*math.sin(a)),(w*.68,.026,.105),rotation((1,0,0),a))
    return m


def side_plate(m,x,yz,thick=.025,role='paint'):
    n=len(yz);v=[(x+dx,y,z) for dx in (-thick/2,thick/2) for y,z in yz]
    m.solid(role,v,[tuple(range(n)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])


def window_grid(m,x,yz,lod):
    side=-1 if x<0 else 1;p=[(x,y,z) for y,z in yz];m.face('glass',p,(side,0,0))
    if lod:return
    for a,b in zip(p,p[1:]+p[:1]):beam(m,'metal_dark',np.array(a)+[side*.025,0,0],np.array(b)+[side*.025,0,0],.019)
    # Clip horizontal and vertical guard bars to the actual window polygon.
    for dim in (0,1):
        bounds=[q[dim] for q in yz]
        for value in np.arange(min(bounds)+.09,max(bounds)-.025,.09):
            hits=[]
            for a,b in zip(yz,yz[1:]+yz[:1]):
                if min(a[dim],b[dim])<value<max(a[dim],b[dim]):
                    t=(value-a[dim])/(b[dim]-a[dim]);hits.append(np.array(a)*(1-t)+np.array(b)*t)
            if len(hits)==2:beam(m,'metal_dark',(x+side*.04,*hits[0]),(x+side*.04,*hits[1]),.009)


def bushmaster__sandcat_tigris(lod=0):
    r,s,h=base('bushmaster__sandcat_tigris','SandCat Tigris selected unarmed IDF exterior',6.20,2.24,2.68,2,.445,lod,axles=[-1.79,1.91],source=TIGRIS,
        features=['four wheels/two axles, no tracks','tall five-door armoured passenger body, sloped two-pane windshield','distinct short angular bonnet, front bull bar, side steps','separate protected side windows and guards, closed roof hatch, no fictional RWS'],representative=LIMIT)
    s.family='israeli_sandcat_tigris';s.details.update(local_photo_estimated_size=True,published_factory_size_unverified=True,selected_fit='IDF2023photographs; current type presence operator2026',ambulance_is_not_separately_generated=True)
    for side in (-1,1):
        h.box('metal_dark',(side*.55,.60,0),(.17,.18,5.82));h.box('metal_dark',(side*.68,.83,-.30),(.07,.25,4.50))
    profile_hull(h,'paint',[(2.05,.84,.88),(2.05,1.87,1.02),(1.42,2.68,.96),(-2.98,2.68,.96),(-3.07,.88,.88)])
    profile_hull(h,'paint',[(3.03,1.03,.85),(3.03,1.67,.99),(1.98,1.93,1.02),(1.91,1.05,.94)])
    h.box('metal_dark',(0,1.30,3.052),(1.69,.39,.026))
    for side in (-1,1):
        h.box('glass',(side*.77,1.56,3.072),(.24,.26,.035));h.box('paint',(side*.80,.90,3.12),(.46,.20,.28))
        for z in s.axle_z:
            # Open wheel arches: three short fender sections, no box across tyre.
            h.box('paint',(side*1.02,1.04,z),(.22,.11,1.29))
            for dz in (-.67,.67):h.box('paint',(side*1.02,.88,z+dz),(.22,.33,.11))
        h.box('metal_dark',(side*1.11,.67,-.10),(.30,.09,2.39))
        beam(h,'metal_dark',(side*.87,1.04,3.20),(side*.87,2.02,3.20),.055)
        beam(h,'metal_dark',(side*1.04,1.99,2.56),(side*1.04,2.37,2.56),.035)
        h.box('metal_dark',(side*1.18,2.23,2.56),(.19,.37,.11));h.box('glass',(side*1.18,2.23,2.492),(.14,.29,.025))
        for i,(z0,z1) in enumerate(((.12,1.70),(-1.15,.03))):
            d=Mesh();x=side*1.038;yz=[(.94,z0),(1.02,z1),(1.91,z1),(2.56,min(z1,1.34)),(2.56,z0)]
            side_plate(d,x,yz);d.box('metal_dark',(x+side*.025,1.57,z0+.22),(.045,.06,.23))
            for y in (1.17,1.96):d.box('paint',(x+side*.04,y,z1-.08),(.075,.11,.16))
            wyz=[(1.94,z0+.12),(1.94,min(z1-.10,1.57)),(2.46,min(z1-.10,1.21)),(2.46,z0+.12)]
            window_grid(d,x+side*.029,wyz,lod)
            r.add(f'Door_{"L" if side<0 else "R"}{i}','Hull',(x,1.70,z1-.08),d,'Y')
        window_grid(h,side*1.045,[(1.96,-2.57),(1.96,-1.58),(2.39,-1.58),(2.39,-2.57)],lod)
        h.box('paint',(side*1.055,1.71,-2.04),(.025,.23,.23));h.box('markings',(side*1.072,1.71,-2.04),(.012,.19,.19))
    for x in (-.48,.48):
        # Two separate glazed panes on the actual raked front face.
        h.face('glass',[(x-.39,2.02,1.947),(x+.39,2.02,1.947),(x+.39,2.57,1.517),(x-.39,2.57,1.517)],(0,.55,.80))
        beam(h,'metal_dark',(x-.22,2.05,1.93),(x+.22,2.10,1.89),.018)
    for y in (1.08,1.45,1.87):beam(h,'metal_dark',(-.87,y,3.20),(.87,y,3.20),.055)
    hatch(h,0,2.69,-.44,.77,.89,lod)
    d=Mesh();d.box('paint',(0,1.76,-3.094),(1.01,1.65,.045));d.box('glass',(0,2.24,-3.126),(.51,.29,.025));r.add('Door_Rear','Hull',(-.51,1.75,-3.094),d,'Y')
    return r,s


def reconVehicle__zmag(lod=0):
    r,s,h=base('reconVehicle__zmag','ZMAG open four-wheel mobility platform',5.20,2.25,1.45,2,.49,lod,axles=[-1.67,1.72],source=ZMAG,
        features=['four wheels/two axles, no tracks; distinct from closed Zibar and smaller ZD','open low sides and bucket seats, exposed roll cage','broad angular bonnet with high grille and round lamps','rear vertical spare, rear open platform, selected unarmed maker exterior'],representative=LIMIT)
    s.family='israeli_zmag';s.details.update(local_photo_estimated_size=True,published_factory_size_unverified=True,selected_fit='makerJune2026ZMAG middle vehicle and clearly labelled ZMAGgallery; not Zibar or ZD',gun=False)
    h.box('paint',(0,.69,-.11),(1.67,.15,4.73))
    for side in (-1,1):
        h.box('metal_dark',(side*.55,.52,-.12),(.15,.19,4.51));h.box('paint',(side*.84,.87,-.13),(.10,.27,2.94))
        for z in s.axle_z:
            h.tube('metal_dark',(-.84,.51,z),(.84,.51,z),.065,6 if lod else 12)
            for dz in (-.32,.32):beam(h,'metal_dark',(side*.32,.73,z+dz),(side*.89,.47,z),.045)
            h.tube('metal_dark',(side*.85,.56,z),(side*.85,1.32,z),.055,6 if lod else 12)
        # Three distinct cage hoops, plus their longitudinal and diagonal braces.
        for z,y in ((1.18,2.14),(-.56,2.43),(-2.10,2.43)):
            h.tube('paint',(side*.83,.86,z),(side*.83,y-.11,z),.035,5 if lod else 10)
            h.tube('paint',(side*.83,y-.11,z),(side*.69,y,z),.035,5 if lod else 10)
        for za,ya,zb,yb in ((1.18,2.14,-.56,2.43),(-.56,2.43,-2.10,2.43)):
            h.tube('paint',(side*.69,ya,za),(side*.69,yb,zb),.035,5 if lod else 10)
        h.tube('paint',(side*.83,.97,-2.10),(side*.83,2.30,-.56),.027,5 if lod else 10)
        h.box('paint',(side*.85,1.12,-2.05),(.10,.72,.87));h.box('paint',(side*.96,1.02,-1.69),(.25,.10,1.22))
        h.box('metal_dark',(side*.96,1.55,1.16),(.17,.23,.07));h.box('glass',(side*.96,1.55,1.116),(.13,.17,.025))
        h.box('markings',(side*.905,.90,-.61),(.013,.15,.32))
    for z,y in ((1.18,2.14),(-.56,2.43),(-2.10,2.43)):h.tube('paint',(-.69,y,z),(.69,y,z),.035,5 if lod else 10)
    profile_hull(h,'paint',[(2.49,1.02,.65),(2.49,1.47,1.04),(1.08,1.50,.91),(1.05,.86,.73)])
    h.box('metal_dark',(0,1.27,2.513),(1.32,.28,.025))
    for x in (-.58,.58):
        h.tube('metal_dark',(x,1.28,2.51),(x,1.28,2.535),.115,8 if lod else 24)
        h.tube('glass',(x,1.28,2.536),(x,1.28,2.55),.083,8 if lod else 24)
        h.box('paint',(x,.97,2.48),(.11,.15,.18))
    h.box('metal_dark',(0,.99,2.55),(.61,.18,.15))
    for z in (.42,-.86):
        for x in (-.43,.43):
            h.box('metal_dark',(x,.87,z),(.40,.22,.42));h.box('paint',(x,1.01,z),(.42,.11,.44))
            h.box('paint',(x,1.31,z-.22),(.43,.59,.09),rotation((1,0,0),math.radians(-12)))
            h.box('paint',(x,1.65,z-.29),(.23,.17,.12))
    h.box('paint',(0,1.37,1.03),(1.50,.34,.10));h.box('glass',(-.43,1.43,.969),(.27,.11,.025))
    # Empty steering wheel and exposed cage are exterior details, no driving logic.
    if not lod:
        c=np.array([-.43,1.32,.73]);a=np.array([.19,0,0])
        for i in range(24):
            u=math.tau*i/24;v=math.tau*(i+1)/24
            h.tube('metal_dark',c+[.19*math.cos(u),.13*math.sin(u),.13*math.sin(u)],c+[.19*math.cos(v),.13*math.sin(v),.13*math.sin(v)],.012,6)
        for u in (0,math.tau/3,math.tau*2/3):beam(h,'metal_dark',c,c+[.18*math.cos(u),.12*math.sin(u),.12*math.sin(u)],.017)
    spare=Mesh();lathe_x(spare,[(-.15,0,'paint'),(-.15,.42,'rubber'),(.15,.42,'paint'),(.15,0,'paint')],segments=8 if lod else 28)
    from vehicle_parts import merge_mesh
    merge_mesh(h,spare,R=rotation((0,1,0),math.pi/2),t=(0,1.43,-2.48))
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('mineClearer__','tank__','bushmaster__','reconVehicle__')) and callable(f)}


def save(slug):
    from validate_framed_ground import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    tank=isinstance(s,Spec);spec=asdict(s)
    if tank:spec.update(slug=slug,mobility='tracked',weapon='tank_gun',family=s.shape,equipment='',axle_z=[],details={'local_photo_estimated_size':True})
    elif s.mobility=='wheeled':
        for p in a.parts:
            if p['name'].startswith(('Wheel_L','Wheel_R')):
                m=dense_tyre(s.wheel_radius,s.width,-1 if p['name'].startswith('Wheel_L') else 1);m.shift(p['pivot']);p['mesh']=m
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    pts=np.concatenate([np.array(g[0]) for r in (a,b) for p in r.parts if p['name'] in ('Hull','Puma_Casemate','Engineering_Roof') for g in p['mesh'].groups.values() if g[0]])
    lo,hi=pts.min(0),pts.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=common.ART/'vehicles'/(slug+'.glb')
    write_glb(path,[a,b],make_wreck(b,s) if tank else wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P1' if tank else 'P2','spec':spec,'units':'metres','up':'+Y','front':'+Z','research_addition':True,**({'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}} if spec['mobility']=='tracked' else {})})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']='Original generate_inventory_additions_32.py and shared approved vehicle_parts.py geometry. Metres,+Z front, ground origin, metre UVs except canonical Track U0..1; plain white named PBR roles, LOD0/LOD1, hidden static Wreck/Collision_Box. Every saved hinge read back with local/world pivot tree and propagation checks. Selected photographic configurations and buyer-described options, current type presence and unverified factory dimensions are distinguished in research/evidence.json. No imported geometry/pixels/insignia or functional weapon internals.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
