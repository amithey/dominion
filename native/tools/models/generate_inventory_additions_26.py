"""Korean engineering/air-defence exteriors, authored in Python from public views.

No imported mesh, texture, insignia or weapon internals. Published type identity
and orders are distinct from estimated local dimensions and selected exteriors.
Old exports remain byte-for-byte unchanged; these are explicit national choices.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,profile_hull,loft,write_glb,rotation,lathe_x
from generate_p1_tanks import beam
from generate_inventory_additions_12 import base,remove,hatch,lamps,gun_station
from generate_inventory_additions_19 import body
from armour_parts import wreck
import generate_inventory_additions as common

GUIDE='https://www.kotra.or.kr/kodits/upload_file/promotion/2019%20Korea%20Defense%20Products%20Guide.pdf'
ARV='https://www.hyundai-rotem.co.kr/en/business/defense/details.do?productNm=K1+ARV'
KM138='https://kookbang.dema.mil.kr/newsWeb/20240201/1/ATCE_CTGR_0010040000/view.do'
CHEONG='https://kookbang.dema.mil.kr/newsWeb/20260804/38/ATCE_CTGR_0010010000/view.do'
LSAM='https://www.hanwhaaerospace.com/eng/media/newsroom/view.do?seq=587'
RADAR='https://www.thessen-lig.com/svcShowWebZinDetail.do?contentsSeq=1252'

def truck_wheel(radius,width,side):
    """Denser rounded carcass using the shared metre-UV lathe, same actual axle."""
    m=Mesh();w=.18 if width<2.6 else .23;r=radius
    profile=[(-w,0,'paint'),(-w,r*.53,'rubber'),(-w*.82,r*.93,'rubber'),(-w*.54,r,'rubber'),
             (w*.54,r,'rubber'),(w*.82,r*.93,'rubber'),(w,r*.53,'paint'),(w,0,'paint')]
    lathe_x(m,profile,segments=32)
    m.tube('paint',(side*(w+.006),0,0),(side*(w+.045),0,0),r*.47,20)
    for a in np.linspace(0,math.tau,8,endpoint=False):
        m.tube('metal_dark',(side*(w+.045),r*.31*math.cos(a),r*.31*math.sin(a)),(side*(w+.065),r*.31*math.cos(a),r*.31*math.sin(a)),.018,6)
    for a in np.linspace(0,math.tau,20,endpoint=False):
        m.box('rubber',(0,(r-.015)*math.cos(a),(r-.015)*math.sin(a)),(w*1.5,.025,.09),rotation((1,0,0),a))
    return m

def recoveryVehicle__k1_arv_korean(lod=0):
    r,s,h=body('recoveryVehicle__k1_arv_korean','K1 ARV Korean selected exterior',lod,7.47,3.60,1.48,6,.35,.94,ARV,
        ['six K1family road wheels, rear sprockets and canonical track loops','low hull with distinct sloping forward recovery cabin','large starboard telescopic crane folded aft, real yaw/luff/extension pivots','broad raised front dozer and closed front winch cover','manual12.7mm cupola, smoke-launcher banks and rear work deck'],front=False,weapon='manual_hmg')
    s.equipment='slew';s.details.update(recovery_parts=['Boom','Spade'],published_nominal_overall_m=[8.96,3.60,2.65],local_fittings_estimated=True,crane_stow='aft',crane_raise_positive_x=True)
    cab=Mesh();profile_hull(cab,'paint',[(2.88,1.48,1.12),(2.82,1.73,1.12),(1.40,2.44,.96),(-.95,2.44,1.03),(-1.08,1.48,1.12)]);cab.shift([-.28,0,0])
    for x in (-.74,-.40,-.06):cab.box('glass',(x,2.43,1.445),(.22,.10,.07))
    for side in (-1,1):
        h.box('paint',(side*1.50,1.22,-.12),(.14,.76,6.84))
        cab.box('markings',(side*1.325,1.99,.10),(.017,.24,.49))
        for j in range(4):
            a=np.array([side*(1.13+j*.105),1.95,2.42]);cab.tube('metal_dark',a,a+[side*.07,.04,.25],.044,5 if lod else 10)
            a=a+[0,-.12,0];cab.tube('metal_dark',a,a+[side*.07,.04,.25],.044,5 if lod else 10)
    hatch(cab,-.48,2.46,.23,.68,.70,lod);hatch(cab,.14,2.46,-.61,.59,.62,lod)
    r.add('Recovery_Cabin','Hull',(-.28,1.48,.60),cab);gun_station(r,lod,-.50,2.52,.18)
    p=np.array([1.14,1.66,1.67]);m=Mesh();m.tube('paint',p-[0,.18,0],p+[0,.31,0],.45,8 if lod else 24)
    r.add('Boom','Hull',p,m,'Y');q=p+[0,.42,0];b=Mesh()
    profile_hull(b,'paint',[(1.77,2.10,.29),(1.69,2.48,.29),(-2.60,2.50,.24),(-2.69,2.10,.24)]);b.shift([1.14,0,0])
    b.tube('metal_dark',q-[.37,0,0],q+[.37,0,0],.16,6 if lod else 20)
    beam(b,'metal_dark',p+[0,.07,-.15],(1.14,2.11,-.72),.12)
    if not lod:
        for z in (-1.92,-.99,.0):
            b.box('metal_dark',(1.439,2.30,z),(.025,.12,.25));b.box('paint',(1.45,2.29,z),(.025,.035,.18))
    r.add('Boom_Lift','Boom',q,b,'X')
    b=Mesh();b.box('paint',(1.14,2.29,-2.96),(.36,.34,1.26));b.tube('metal_dark',(.89,2.29,-3.57),(1.39,2.29,-3.57),.12,6 if lod else 20)
    r.add('Boom_Extend','Boom_Lift',(1.14,2.29,-2.45),b,translation_axis='Z')
    b=Mesh();b.tube('metal_dark',(1.14,2.17,-3.57),(1.14,1.86,-3.57),.035,5 if lod else 12)
    beam(b,'metal_dark',(1.14,1.86,-3.57),(1.23,1.78,-3.57),.065);beam(b,'metal_dark',(1.23,1.78,-3.57),(1.29,1.88,-3.57),.065)
    r.add('Crane_Hook','Boom_Extend',(1.14,2.17,-3.57),b,'X')
    b=Mesh();profile_hull(b,'paint',[(5.07,.54,1.79),(5.225,.61,1.79),(4.96,1.63,1.79),(4.81,1.63,1.79)])
    b.box('metal_dark',(0,.585,5.17),(3.58,.09,.08))
    for x in (-1.20,1.20):
        beam(b,'paint',(x,1.17,3.37),(x,.87,4.99),.21);beam(b,'metal_dark',(x,1.39,3.52),(x,1.10,4.70),.075)
    if not lod:
        for x in np.linspace(-1.65,1.65,12):beam(b,'paint',(x,.65,5.07),(x,1.49,4.88),.045)
    r.add('Spade','Hull',(0,1.17,3.37),b,'X')
    w=Mesh();w.box('paint',(0,1.07,3.735),(.73,.47,.09));w.box('metal_dark',(0,1.07,3.79),(.46,.13,.03))
    for y in (.95,1.19):w.tube('metal_dark',(-.26,y,3.80),(.26,y,3.80),.045,5 if lod else 12)
    r.add('Winch_Closed_Cover','Hull',(0,1.07,3.735),w)
    for side in (-1,1):
        h.box('paint',(side*.55,1.66,-2.18),(.65,.34,1.17))
        beam(h,'metal_dark',(side*1.44,1.70,-3.26),(side*1.44,1.70,-.95),.035)
        if not lod:
            for z in (-3.22,-2.13,-1.03):beam(h,'paint',(side*1.44,1.48,z),(side*1.44,1.70,z),.035)
    if not lod:
        for z in np.linspace(-3.20,-1.30,14):h.box('metal_dark',(-.35,1.50,z),(1.20,.028,.047))
    return r,s

def truck(slug,name,lod,L,W,H,axles,radius,source,style,features):
    r,s,m=base(slug,name,L,W,H,len(axles),radius,lod,axles=axles,source=source,features=features,
        representative='Selected public Korean exterior; principal carrier class and role identified, local dimensions/fittings estimated. No fleet-wide fit, load, performance or readiness certification.')
    s.family='korean_'+style;f=L/2;n=6 if lod else 20;bed=1.36 if style=='bonnet' else 1.51
    for side in (-1,1):
        m.box('metal_dark',(side*.64,.92,0),(.19,.27,L-.30))
    for z in axles:m.tube('metal_dark',(-W*.35,radius,z),(W*.35,radius,z),.11,6 if lod else 12)
    if style=='bonnet':
        front=f-.15;m.box('paint',(0,1.40,front-.60),(1.53,.54,1.22))
        m.box('paint',(0,1.51,f-2.04),(2.18,1.03,1.43));m.box('paint',(0,2.79,f-2.04),(2.24,.12,1.50))
        for side in (-1,1):
            m.box('paint',(side*.56,2.37,f-1.294),(1.06,.78,.07));m.box('glass',(side*.56,2.38,f-1.251),(.94,.64,.025))
            m.box('glass',(side*1.102,2.38,f-2.00),(.025,.64,1.18));m.box('paint',(side*1.10,1.85,f-2.02),(.04,.42,1.12))
            for z in (f-2.04-.62,f-2.04+.62):m.box('paint',(side*1.10,2.38,z),(.08,.78,.08))
            for y in (2.04,2.74):m.box('paint',(side*1.10,y,f-2.04),(.08,.10,1.40))
            m.box('paint',(side*(W/2-.12),1.32,axles[-1]),(.47,.11,1.42));m.box('metal_dark',(side*1.03,.89,f-2.08),(.43,.10,1.04))
            m.box('glass',(side*.94,1.46,front+.025),(.23,.23,.03));m.tube('paint',(side*.94,1.46,front),(side*.94,1.46,front+.03),.16,n)
        m.box('metal_dark',(0,1.40,front+.03),(1.05,.46,.035));m.box('paint',(0,.98,front+.04),(W-.10,.22,.23))
        if not lod:
            for yy in np.linspace(1.23,1.59,5):m.box('paint',(0,yy,front+.06),(1.02,.045,.035))
        cz=f-2.04
    else:
        cz=f-1.14;bottom=.98;roof=H-.15;ww=W*.45
        b=[(-ww,cz-1.05),(ww,cz-1.05),(ww,cz+.99),(-ww,cz+.99)]
        t=[(-ww,cz-.99),(ww,cz-.99),(ww,cz+.62),(-ww,cz+.62)]
        loft(m,'paint',[[(x,bottom,z) for x,z in b],[(x,roof,z) for x,z in t]])
        for side in (-1,1):
            zglass=cz+.62+.37*.64/(roof-bottom)+.018
            m.box('glass',(side*ww*.51,roof-.64,zglass),(ww*.85,.79,.03),rotation([1,0,0],-math.atan2(.37,roof-bottom)))
            m.box('glass',(side*(ww+.017),roof-.68,cz-.07),(.025,.83,1.13));m.box('paint',(side*(ww+.025),roof-1.34,cz-.07),(.035,.38,1.20))
            m.box('metal_dark',(side*(ww-.05),.83,cz-.05),(.47,.10,1.08));m.box('glass',(side*.90,1.36,f-.07),(.24,.21,.035))
            m.box('paint',(side*(W/2-.16),1.28,axles[-1]),(.50,.09,1.49))
        m.box('metal_dark',(0,1.63,f-.095),(W*.62,.38,.04));m.box('paint',(0,.99,f-.035),(W-.12,.23,.21))
        if not lod:
            for yy in np.linspace(1.49,1.76,5):m.box('paint',(0,yy,f-.062),(W*.60,.032,.029))
    for side in (-1,1):
        x=side*(W*.45+.24);a=[side*(W*.45),H-.24,cz+.21];b=[x,H-.24,cz+.56]
        beam(m,'metal_dark',a,b,.035);m.box('paint',(x,H-.45,cz+.56),(.14,.39,.28));m.box('glass',(x+side*.077,H-.45,cz+.56),(.018,.31,.21))
        m.box('markings',(side*(W*.45+.045),H-1.11,cz-.25),(.017,.22,.39))
        if not lod:
            m.box('metal_dark',(side*(W*.45+.055),H-1.04,cz-.30),(.025,.05,.20))
            for y in (H-1.43,H-.85):m.box('paint',(side*(W*.45+.06),y,cz+.51),(.035,.14,.06))
    r.add('Engine_Deck','Hull',(0,1.68 if style=='bonnet' else H-.2,cz+.30));r.add('Exhaust','Hull',(W*.45,1.2,cz-1.02))
    s.details.update(estimated_carrier=True,bed_height=bed)
    return r,s,m,bed

def mineLayer__km138_truck(lod=0):
    r,s,h,bed=truck('mineLayer__km138_truck','KM138 on representative Korean KM250family truck',lod,6.80,2.50,2.90,[-2.15,-.88,1.76],.51,KM138,'bonnet',
        ['6x6 bonneted KM250class cargo carrier; exact photographed chassis suffix unverified','open slatted cargo body and closed transport stowage','one small KM138exterior unit, not a fictional multi-tube rocket rack','separate manual azimuth and elevation pivots; single visible outlet marker','no mines, dispensing internals, operational pattern or crew copied'])
    h.box('paint',(0,bed,-1.14),(2.36,.16,4.05))
    for side in (-1,1):
        for y in np.linspace(bed+.23,bed+.86,4):h.box('paint',(side*1.17,y,-1.14),(.07,.13,3.96))
        for z in (-3.02,-1.13,.74):h.box('metal_dark',(side*1.21,bed+.52,z),(.055,.91,.065))
        h.box('rubber',(side*1.01,.91,-3.05),(.40,.56,.04));h.box('glass',(side*.92,1.30,-3.23),(.19,.12,.035))
    for y in np.linspace(bed+.23,bed+.86,4):h.box('paint',(0,y,-3.17),(2.30,.13,.065))
    for x in (-.75,.75):h.box('paint',(x,bed+.24,.35),(.58,.42,.78))
    p=np.array([0,bed+.15,-1.80]);m=Mesh();m.tube('paint',p,p+[0,.31,0],.24,6 if lod else 20);r.add('Turntable','Hull',p,m,'Y')
    q=p+[0,.36,0];m=Mesh();m.box('paint',q+[0,.15,.10],(.47,.42,.63));m.box('paint',q+[0,.41,-.12],(.47,.17,.45))
    m.tube('paint',q+[0,.09,.35],q+[0,.09,.50],.145,8 if lod else 28)
    m.tube('metal_dark',q+[0,.09,.50],q+[0,.09,.512],.114,8 if lod else 24)
    for side in (-1,1):
        beam(m,'metal_dark',q+[side*.27,.34,-.22],q+[side*.27,.34,.33],.024)
        beam(m,'metal_dark',q+[side*.27,.34,.33],q+[side*.27,.03,.33],.024)
        m.box('paint',q+[side*.23,.13,-.16],(.07,.24,.30))
        m.tube('paint',q+[side*.245,.15,.10],q+[side*.282,.15,.10],.215,8 if lod else 24)
    m.box('paint',q+[0,.44,-.20],(.48,.06,.47),rotation([1,0,0],math.radians(15)))
    r.add('Launcher','Turntable',q,m,'X',fit='closed exterior approximation; no dispensing mechanism or explosive internals')
    tip=q+[0,.09,.52];r.add('Muzzle_0','Launcher',tip)
    s.details.update(tube_count=1,muzzle_positions=[tip.tolist()],carrier_fit='representative KM250family; photographed bed fit, exact suffix pending',manufacturer_disclaimer='KM138manufacturer states launcher no longer produced; this does not establish operator retirement')
    return r,s

def canister_rack(r,lod,p,columns,rows,radius,length,spacing):
    """Closed exterior canisters; no live missiles, explosive parts or internals."""
    p=np.asarray(p);m=Mesh();tips=[];n=8 if lod else 28
    for j in range(rows):
        for i in range(columns):
            q=p+[(i-(columns-1)/2)*spacing,.42+j*spacing,0];end=q+[0,0,length]
            m.tube('paint',q,end,radius,n);m.tube('metal_dark',end+[0,0,.008],end+[0,0,.025],radius*.88,n)
            tips.append((end+[0,0,.03]).tolist())
            for z in (.16,length*.48,length-.14):m.tube('paint',q+[0,0,z],q+[0,0,z+.07],radius+.032,n)
    width=(columns-1)*spacing+radius*2+.14
    for z in (.10,length*.46,length-.09):
        m.box('metal_dark',p+[0,.12,z],(width,.16,.14))
        top=.42+(rows-1)*spacing+radius+.07
        for side in (-1,1):beam(m,'paint',p+[side*width/2,.14,z],p+[side*width/2,top,z],.09)
    r.add('Launcher','Hull',p,m,'X',closed_canisters=True)
    for i,tip in enumerate(tips):r.add('Muzzle_'+str(i),'Launcher',tip)
    return tips

def outriggers(r,lod,ys,zs,width):
    for label,side in (('L',-1),('R',1)):
        for i,z in enumerate(zs):
            p=np.array([side*width,ys,z]);m=Mesh();m.tube('paint',p,p+[0,-ys+.30,0],.11,6 if lod else 16)
            m.tube('metal_dark',p+[0,-ys+.30,0],p+[0,-ys+.12,0],.065,6 if lod else 12);m.box('metal_dark',(p[0],.065,z),(.42,.13,.48))
            r.add('Outrigger_'+label+str(i),'Hull',p,m,translation_axis='Y')

def samLauncher__cheongung_ii_korean(lod=0):
    r,s,h,bed=truck('samLauncher__cheongung_ii_korean','CheongungII Korean three-axle launcher',lod,9.10,2.70,3.15,[-2.85,-1.40,2.34],.58,CHEONG,'cabover',
        ['three-axle Korean Mercedes-style cabover carrier, not an eight-wheel export substitute','eight closed cylindrical canisters in two rows of four','rear Xerection hinge; vertical-launch rack has no invented traverse turntable','four screw/ram stabilisers and exposed lift supports','separate battery radar is not mounted on this launcher'])
    h.box('paint',(0,bed,-1.28),(2.56,.20,6.20));h.box('paint',(0,2.31,1.56),(2.29,1.38,.82))
    for y in (1.10,1.67):beam(h,'metal_dark',(-1.23,y,4.68),(1.23,y,4.68),.055)
    for x in (-1.23,1.23):
        beam(h,'metal_dark',(x,1.10,4.68),(x,2.02,4.68),.055);beam(h,'metal_dark',(x,1.10,4.68),(x,1.10,4.42),.055)
    h.tube('rubber',(-.45,2.31,1.08),(-.45,2.31,.90),.54,8 if lod else 24);h.tube('paint',(-.45,2.31,.89),(-.45,2.31,.86),.30,8 if lod else 20)
    p=np.array([0,bed+.22,-3.38]);tips=canister_rack(r,lod,p,4,2,.205,4.72,.49)
    supports=Mesh()
    for side in (-1,1):
        beam(supports,'paint',(side*.61,bed+.04,-1.5),(side*.61,bed+.35,-3.05),.13)
        supports.box('paint',(side*1.10,bed+.40,-3.38),(.19,.79,.35))
    r.add('Lift_Supports','Hull',(0,bed,-3.38),supports)
    outriggers(r,lod,bed+.10,[-3.64,.76],1.46)
    s.details.update(tube_count=8,muzzle_positions=tips,radar=False,observed_axles=3,selected_fit='actual May2026Korean deployed-vehicle photo; local rack/cab measurements estimated',inventory_status='additional2026equipment_actual_operation_from_August_confirmed')
    return r,s

def abmLauncher__l_sam_trailer(lod=0):
    r,s,h=base('abmLauncher__l_sam_trailer','L-SAM ordered six-canister semitrailer',12.40,3.0,2.25,3,.54,lod,axles=[-4.65,-3.36,-2.07],source=LSAM,
        features=['standalone three-axle semitrailer; separate6x6tractor is not fabricated as an integrated chassis','six closed cylindrical launch canisters in two rows of three','aft Xerection hinge, no invented onboard radar or azimuth turntable','raised gooseneck with coupling marker, work platform and stabilisers','confirmed2025production contract, not completed operational fielding'],
        representative='Public2025Hanwha system illustration selected; trailer/canister exterior dimensions and local fittings estimated. Future production fit/acceptance unverified. No battery layout, ammunition holdings or performance simulated.')
    s.family='korean_lsam_trailer';h.box('paint',(0,1.48,-1.58),(2.86,.24,9.20));h.box('paint',(0,2.08,4.41),(2.78,.26,3.54))
    for side in (-1,1):
        beam(h,'metal_dark',(side*.67,1.29,-5.80),(side*.67,1.29,2.84),.22)
        beam(h,'paint',(side*.67,1.38,2.70),(side*.67,2.00,3.53),.24)
        h.box('paint',(side*1.35,1.58,-3.35),(.26,.12,4.62));h.box('rubber',(side*1.28,1.03,-5.62),(.42,.60,.045))
        h.box('markings',(side*1.44,1.81,4.50),(.017,.26,.65));h.box('glass',(side*1.14,1.37,-6.00),(.23,.13,.035))
        for z in (3.16,5.75):beam(h,'paint',(side*1.32,2.23,z),(side*1.32,3.14,z),.045)
        beam(h,'paint',(side*1.32,3.14,3.16),(side*1.32,3.14,5.75),.045)
    h.box('paint',(0,2.54,4.50),(1.28,.66,1.13));r.add('Coupling','Hull',(0,1.85,5.29))
    p=np.array([0,1.78,-4.96]);tips=canister_rack(r,lod,p,3,2,.35,7.54,.83)
    outriggers(r,lod,1.60,[-5.54,2.48],1.47)
    s.details.update(tube_count=6,muzzle_positions=tips,radar=False,inventory_status='confirmed_production_order_2025_latest_acceptance_unverified',prime_mover_separate=True,canisters_closed=True,selected_fit='2025manufacturerpublicillustration; local dimensions estimated')
    return r,s

def counterBatteryRadar__cheongyeong_ii(lod=0):
    r,s,h,bed=truck('counterBatteryRadar__cheongyeong_ii','Cheongyeong counter-battery radarII',lod,11.0,3.0,3.55,[-3.70,-2.34,1.16,2.86],.60,RADAR,'radar',
        ['eight-wheel KIAclass carrier with two forward and two rear axles','short angular cab distinct from a Mercedes Cheongung6x6','tall single rectangular radar panel on lift frame, Yazimuth bearing','rear equipment van with two large side cooling apertures and roof rails','no weapon launcher or fictional missile tube on radar truck'])
    h.box('paint',(0,2.45,-2.23),(2.70,1.85,5.55));h.box('paint',(0,bed,-1.52),(2.85,.20,7.12))
    h.box('paint',(0,2.63,.55),(2.42,2.07,.68));h.box('metal_dark',(0,3.70,.55),(2.48,.09,.72))
    for side in (-1,1):
        for z in (-1.87,-2.83):
            h.tube('metal_dark',(side*1.36,2.44,z),(side*1.38,2.44,z),.32,8 if lod else 28)
            if not lod:
                for y in np.linspace(2.20,2.68,7):h.box('paint',(side*1.40,y,z),(.025,.025,.50))
        h.box('metal_dark',(side*1.37,2.82,-4.12),(.025,.35,.53))
        for z in (-4.72,-3.60,-1.0):beam(h,'paint',(side*1.21,3.42,z),(side*1.21,3.94,z),.035)
        beam(h,'paint',(side*1.21,3.94,-4.72),(side*1.21,3.94,-1.0),.035)
    p=np.array([0,3.65,.74]);lift=Mesh();lift.box('metal_dark',p,(1.30,.16,.80))
    r.add('Radar_Lift','Hull',p,lift,'X',display_pose='deployed; fold aft for travel using negative X')
    m=Mesh();q=p+[0,.05,0];m.tube('metal_dark',q-[0,.20,0],q+[0,.05,0],.49,8 if lod else 24)
    m.box('paint',q+[0,.02,-.08],(2.20,.13,.24))
    m.box('paint',q+[0,1.63,0],(2.38,3.22,.29));m.box('metal_dark',q+[0,1.63,.158],(2.16,2.99,.025))
    for side in (-1,1):
        beam(m,'paint',q+[side*1.02,0,-.08],q+[side*1.02,3.22,-.08],.10)
        if not lod:
            for y in np.linspace(.24,3.03,11):m.box('metal_dark',q+[side*1.20,y,.02],(.08,.09,.16))
    if not lod:
        for x in np.linspace(-.89,.89,5):m.box('paint',q+[x,1.63,-.184],(.055,2.86,.09))
    r.add('Radar','Radar_Lift',q,m,'Y',sensor_type='single flat public exterior array; no RF internals')
    s.details.update(radar=True,radar_axes=['Y'],inventory_status='fielding_completion_reported_March2024',selected_fit='2024manufacturerphoto; exact latest per-vehicle modifications and dimensions unverified')
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('recoveryVehicle__','mineLayer__','samLauncher__','abmLauncher__','counterBatteryRadar__')) and callable(f)}

def save(slug):
    from validate_p3_artillery import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    if s.mobility=='wheeled':
        for p in a.parts:
            if p['name'].startswith(('Wheel_L','Wheel_R')):
                m=truck_wheel(s.wheel_radius,s.width,-1 if p['name'].startswith('Wheel_L') else 1);m.shift(p['pivot']);p['mesh']=m
    for rig in (a,b):
        for p in rig.parts:
            if p.get('mesh'):p['mesh'].remove_duplicates()
    central=[np.asarray(g[0]) for rig in (a,b) for p in rig.parts if p['name'] in ('Hull','Recovery_Cabin','Winch_Closed_Cover') for g in p['mesh'].groups.values() if len(g[0])]
    pts=np.concatenate(central);lo=pts.min(0);hi=pts.max(0);lo[1]=0
    c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo);path=common.ART/'vehicles'/(slug+'.glb')
    write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P2' if slug.startswith(('recoveryVehicle__','mineLayer__')) else 'P4','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','canonical_track_path':{'half':3.23,'radius':.57,'y':.65},'research_addition':True})
    e,tree=validate(path);e['notes']+=' Original generate_inventory_additions_26.py, public exterior only; source/date/variant qualifications in research/evidence.json. Stabilisers use Ytranslation, crane has yaw/luff and telescopic extension pivots. Closed canisters contain no modelled missiles or explosive internals.'
    e['has_radar']=bool(s.details.get('radar'));e['validation']['radar_axes_checked']=bool(s.details.get('radar'))
    (Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
