"""Five individually shaped audit additions; original shared-parts Python GLBs.

Public exterior proportions only. Kaplan models the unarmed acceptance vehicle,
not the armed marketing rendering. No operational availability is inferred.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
from generate_p2_armour import carrier,arv
from vehicle_parts import Mesh,profile_hull,loft,rotation,hollow_muzzle

FNSS='https://www.fnss.com.tr/en/media/news/first-vehicle-pre-delivery-acceptance-tests-successfully-completed-kaplan-apc-program-developed-fnss-and-pt-pindad'

def replace_hull(rig,m):
    for part in rig.parts:
        if part['name']=='Hull':part['mesh']=m

def apc__kaplan_harimau_apc(lod=0):
    rig,s=carrier('apc__kaplan_harimau_apc','Kaplan/Harimau APC acceptance vehicle',lod,7.0,3.20,2.42,
        'engineering','',6,.34,.88,True,source=FNSS,front_engine=True,
        features=['six road wheels','high slab-sided troop compartment','wide angular wedge bow','two-level side armour panels','rear troop ramp','roof hatches and driver periscopes','unarmed September2026 acceptance configuration'],
        approx=True,representative='Unarmed first acceptance vehicle; unpublished dimensions estimated from public FNSS exterior photographs',bow=.64,shoulder=.94)
    m=Mesh();profile_hull(m,'paint',[(3.20,.44,1.06),(3.50,1.82,1.25),(2.18,2.42,1.25),(-3.32,2.42,1.25),(-3.48,.50,1.08)])
    for side in (-1,1):
        m.box('paint',(side*1.32,1.09,-.12),(.40,.10,6.52))
        for z in np.linspace(-2.90,1.65,7 if not lod else 4):
            m.box('paint',(side*1.28,1.94,z),(.11,.84,.58 if not lod else 1.16))
            if not lod:
                for y in (1.62,2.28):m.tube('metal_dark',(side*1.34,y,z),(side*1.36,y,z),.022,6)
        m.box('paint',(side*1.02,1.76,3.46),(.29,.24,.07));m.box('glass',(side*1.02,1.79,3.504),(.19,.11,.025))
        m.box('paint',(side*1.12,2.56,2.01),(.10,.27,.12));m.box('glass',(side*1.12,2.57,2.077),(.075,.17,.018))
    m.box('paint',(0,1.38,-3.49),(1.63,1.60,.08));m.box('metal_dark',(0,.62,-3.54),(1.60,.07,.05))
    for z in (-2.20,-.90,.40):
        m.box('paint',(0,2.455,z),(1.39,.07,.75))
        for side in (-1,1):m.box('metal_dark',(side*.53,2.50,z),(.13,.035,.10))
    for x in (-.64,-.40,-.16):m.box('glass',(x,2.48,2.0),(.15,.07,.10))
    if not lod:
        for z in np.linspace(1.18,2.05,10):m.box('metal_dark',(.72,2.446,z),(.60,.028,.035))
    replace_hull(rig,m);s.details['inventory_status']='ordered_pre_delivery_acceptance'
    return rig,s

def directFire__badak(lod=0):
    rig,s=carrier('directFire__badak','Badak 6x6 CSE90',lod,6.,2.50,1.88,'engineering','',3,.48,1.,False,
        source='https://pindad.com/downloads/article/BulletinDesember20141.pdf',front_engine=False,axles=[-1.91,-.48,1.86],
        features=['three widely separated wheel axles','compact welded six-wheel hull','right-front driver periscopes','rear-left engine grille','two-person Cockerill low-pressure90mm turret','short cannon with slotted muzzle brake'],
        approx=True,representative='Pindad delivered Badak CSE90; small fittings and hidden sections estimated',bow=.50,shoulder=.87)
    # Small two-man CSE90 turret: neither a 30 mm IFV nor Harimau105.
    p=np.array([0,1.96,-.18]);m=Mesh();m.tube('metal_dark',p-[0,.08,0],p,.72,6 if lod else 16)
    bottom=[(-.52,.92),(.52,.92),(.99,.38),(.94,-.95),(-.94,-.95),(-.99,.38)]
    loft(m,'paint',[[(x,p[1],z+p[2]) for x,z in bottom],[(x*.80,p[1]+.64,z*.84+p[2]) for x,z in bottom]])
    for side in (-1,1):
        m.tube('paint',p+[side*.43,.64,-.39],p+[side*.43,.70,-.39],.27,6 if lod else 12)
        m.box('glass',p+[side*.57,.53,.54],(.19,.10,.04))
    rig.add('Turret','Hull',p,m,'Y');q=p+[0,.33,.69];m=Mesh();m.box('paint',q,(.57,.42,.45))
    hollow_muzzle(m,q+[0,0,.21],q+[0,0,2.33],.073,.045,6 if lod else 16)
    m.box('metal_dark',q+[0,0,2.27],(.22,.17,.28))
    for side in (-1,1):
        for z in (2.21,2.31):m.box('paint',q+[side*.116,0,z],(.025,.08,.045))
    rig.add('Gun','Turret',q,m,'X',bore_metres=.09);rig.add('Muzzle','Gun',q+[0,0,2.42],forward='+Z')
    s.weapon='cse90';s.details['inventory_status']='documented_delivery';return rig,s

def recoveryVehicle__leclerc_dcl(lod=0):
    rig,s=arv('recoveryVehicle__leclerc_dcl','Leclerc DCL renovated',lod,9.15,3.40,2.16,7,1.03,'slew',
        'https://www.defense.gouv.fr/dga/actualites/dga-prononce-qualification-du-depanneur-du-char-leclerc-renove',
        ['lengthened seven-road-wheel Leclerc recovery chassis','asymmetric low forward crew cabin','right-side crane and articulated lift boom','front anchor spade','rear powerpack platform','renovated12.7mm remote cupola'],
        approx=True,representative='DCL renovated public exterior; small equipment dimensions estimated',front_engine=False,crane_offset=.72,spare_roadwheels=1)
    m=Mesh();profile_hull(m,'paint',[(4.39,.48,1.05),(4.57,1.05,1.20),(3.10,1.42,1.24),(-4.575,1.42,1.24),(-4.50,.48,1.03)])
    cabin=Mesh();profile_hull(cabin,'paint',[(3.79,1.42,.83),(3.26,2.16,.83),(.1,2.16,.83),(-.2,1.42,.83)])
    cabin.shift([-.40,0,0])
    # Merge preserves metre UVs and per-role primitive grouping.
    from vehicle_parts import merge_mesh
    merge_mesh(m,cabin)
    for side in (-1,1):
        m.box('paint',(side*1.34,1.24,0),(.48,.12,8.87))
        for z in np.linspace(-3.8,3.2,7 if not lod else 4):m.box('paint',(side*1.40,1.07,z),(.10,.48,.77 if not lod else 1.55))
    m.box('paint',(-.72,2.20,2.07),(.59,.08,.57));m.box('glass',(-.72,2.27,2.30),(.32,.07,.055))
    replace_hull(rig,m)
    # Actual renovated defensive RWS, separate from the recovery crane pivot.
    p=np.array([-.55,2.25,.82]);m=Mesh();m.tube('paint',p,p+[0,.25,0],.17,6 if lod else 12)
    m.box('paint',p+[0,.36,0],(.38,.27,.44));m.box('glass',p+[-.24,.34,.10],(.13,.14,.19))
    rig.add('Turret','Hull',p,m,'Y');q=p+[0,.39,.18];m=Mesh()
    hollow_muzzle(m,q,q+[0,0,.98],.027,.00635,6 if lod else 12)
    rig.add('Gun','Turret',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,.98],forward='+Z');s.weapon='rws'
    s.details['inventory_status']='renovated_qualification_delivery_programme';return rig,s

def mineClearer__sdpmac(lod=0):
    rig,s=carrier('mineClearer__sdpmac','SDPMAC CARPET on EBG',lod,6.78,3.15,1.62,'engineering','',5,.40,.88,True,
        source='https://www.defense.gouv.fr/en/node/587',front_engine=False,
        features=['five AMX30 road wheels','EBG turretless engineering hull','large rear-facing CARPET20-cell rack','three rack rows with central support space','launcher elevation pivot','front dozer blade'],
        approx=True,representative='French CARPET/EBG public exterior; rack transport pose and hidden fittings estimated',equipment='generic_clear',bow=.63,shoulder=.91)
    p=np.array([0,1.73,-1.28]);m=Mesh()
    for side in (-1,1):m.box('paint',p+[side*1.13,.32,-.12],(.17,.65,1.12))
    rig.add('Rack_Support','Hull',p,m)
    m=Mesh();tips=[];cols=np.linspace(-1.26,1.26,8)
    for row in range(3):
        for j,x in enumerate(cols):
            if row>0 and j in (3,4):continue
            c=p+[x,.28+row*.36,-.78]
            if lod:
                m.box('paint',c,(.34,.347,1.93))
                m.box('metal_dark',c+[0,0,-.97],(.273,.277,.01))
            else:
                # Four closed walls leave genuine open cartridge mouths.
                m.box('paint',c+[0,.156,0],(.34,.035,1.93));m.box('paint',c+[0,-.156,0],(.34,.035,1.93))
                for side in (-1,1):m.box('paint',c+[side*.153,0,0],(.035,.277,1.93))
                m.box('metal_dark',c+[0,0,.92],(.273,.277,.065))
            tips.append((c+[0,0,-.97]).tolist())
    m.box('paint',p+[0,.72,-.78],(.61,.95,1.92))
    rig.add('Launcher','Hull',p,m,'X',positive_elevation_rotation_sign=1)
    for i,tip in enumerate(tips):rig.add('Muzzle_'+str(i),'Launcher',tip,forward='-Z')
    s.details.update(tube_count=20,muzzle_positions=tips,inventory_status='documented_service');return rig,s

def apc__serval(lod=0):
    rig,s=carrier('apc__serval','Serval VBMR-L patrol',lod,6.50,2.53,2.46,'engineering','rws',2,.54,1.,False,
        source='https://media.knds.com/uploads/KRV_058_SERVAL_EN_BAT_BDEF_e06e0b2270.pdf',front_engine=True,axles=[-1.82,1.92],
        features=['four-wheel light protected patrol vehicle','short sloped bonnet','separate armoured windscreen panes','tall modular rear troop cabin','rear troop door','12.7mm remote cupola'],
        approx=True,representative='Standard patrol troop variant, not an unverified specialised EW payload',bow=.58,shoulder=.91,z=-.33)
    # Two convex shells preserve correct face winding around the bonnet step.
    m=Mesh();profile_hull(m,'paint',[(3.10,.62,1.0),(3.25,1.26,1.07),(1.84,1.57,1.05),(-3.14,1.57,1.09),(-3.22,.63,.91)])
    profile_hull(m,'paint',[(1.84,1.565,1.05),(1.33,2.46,1.09),(-3.14,2.46,1.09),(-3.14,1.565,1.09)])
    for side in (-1,1):
        m.box('glass',(side*.53,2.14,1.54),(.78,.43,.045),rotation([1,0,0],-.40))
        m.box('glass',(side*1.105,2.12,.73),(.035,.43,.71));m.box('paint',(side*1.11,1.77,.47),(.07,1.16,1.06))
        m.box('glass',(side*1.155,2.14,.64),(.04,.36,.66))
        m.box('metal_dark',(side*1.18,1.17,.30),(.18,.08,1.25));m.box('paint',(side*1.18,1.06,-1.53),(.13,.38,2.02))
        for z in s.axle_z:m.box('paint',(side*1.12,1.075,z),(.37,.11,1.20))
        m.box('glass',(side*.80,1.22,3.24),(.24,.13,.05))
        m.box('paint',(side*1.11,2.40,1.34),(.08,.24,.18))
    m.box('metal_dark',(0,1.24,3.266),(.80,.32,.035));m.box('paint',(0,.77,3.24),(2.17,.20,.18))
    m.box('paint',(0,1.62,-3.25),(1.33,1.57,.08));m.box('metal_dark',(.48,1.74,-3.301),(.13,.035,.04))
    m.box('paint',(0,2.50,-1.80),(.90,.08,.67));replace_hull(rig,m)
    s.details['inventory_status']='documented_delivery';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();common.BUILDERS.update(BUILDERS)
    a.report.write_text(json.dumps([common.save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
