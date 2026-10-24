"""Original British land additions; prototype/order statuses are explicit.

Shared running gear retains the pilot TrackPath. Vehicle-specific hulls,
turrets and mission equipment are authored here, not imported from meshes.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
import generate_inventory_additions_05 as tank_saver
import generate_p3_artillery as artillery
from generate_p1_tanks import Spec,finish,basket
from generate_p2_armour import carrier
from vehicle_parts import Mesh,loft,profile_hull,hollow_muzzle,rotation
from artillery_parts import artillery_barrel
from ship_parts import beam

ARMY='https://www.army.mod.uk/learn-and-explore/equipment/'
GD='https://generaldynamics.uk.com/businesses/land-systems/ajax/'

def discard(rig,names):
    names=set(names);rig.parts=[p for p in rig.parts if p['name'] not in names]
    rig.pivots={n:p for n,p in rig.pivots.items() if n not in names}

def replace_hull(rig,m):
    m.remove_duplicates()
    for p in rig.parts:
        if p['name']=='Hull':p['mesh']=m

def manual_gun(rig,parent,base,lod,cal=.00762,length=.78,shield=False):
    p=np.array(base);m=Mesh();m.tube('metal_dark',p,p+[0,.22,0],.055,6 if lod else 12)
    if shield:m.box('paint',p+[0,.35,.28],(.73,.57,.06))
    rig.add('Turret',parent,p,m,'Y',purpose='manual pintle traverse, not an armored turret')
    q=p+[0,.32,.08];m=Mesh();m.box('metal_dark',q,(.10,.14,.35))
    m.box('metal_dark',q+[-.14,-.03,0],(.18,.22,.24))
    hollow_muzzle(m,q+[0,0,.15],q+[0,0,length],.019 if cal<.01 else .028,cal/2,6 if lod else 12)
    rig.add('Gun','Turret',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,length],forward='+Z')

def tank__challenger_3(lod=0):
    s=Spec('challenger_3','Challenger 3 prototype',8.33,3.52,1.53,2.54,6,.39,1.03,.10,2.08,1.47,11.55,'challenger',
        ['Challenger-based six-wheel hull','new broad modular-armour turret','120mm L55A1 smoothbore, not L30 rifled gun',
         'long box bustle and slab cheek modules','separate new gunner and commander optics','four smoke tubes per cheek bank',
         'public early prototype exterior, not speculative completed Trophy installation'],
        'https://rbsl.com/news-and-events/news/challenger-3-programme-achieves-milestone',approximate=True,
        representative='Public pre-series prototype exterior.148 upgrades contracted; seven prototypes in demonstration as of19October2026. Hull and gun dimensions estimated from Challenger lineage, not a claim of final4.2m applique-kit width or operational entry.')
    b=[(-.48,1.49),(.48,1.49),(1.49,.92),(1.49,-1.64),(1.18,-2.19),(-1.18,-2.19),(-1.49,-1.64),(-1.49,.92)]
    t=[(-.43,.99),(.43,.99),(1.32,.53),(1.29,-1.68),(1.08,-2.05),(-1.08,-2.05),(-1.29,-1.68),(-1.32,.53)]
    def details(h,m,s,l):
        # The new cheeks are broad flat armour modules, not Leopard wedges.
        for side in (-1,1):
            m.box('paint',(side*1.15,2.12,.66),(.65,.66,.83),rotation([0,1,0],side*.14))
            m.box('paint',(side*1.34,2.12,-.78),(.22,.67,1.38))
            m.box('paint',(side*1.13,2.22,-1.80),(.25,.53,.54))
            if not l:
                for z in (-1.65,-1.1,-.5,.08):m.tube('metal_dark',(side*1.46,2.22,z),(side*1.485,2.22,z),.018,6)
        basket(m,s,l,z=-2.21,width=2.71)
    rig,s=finish(s,b,t,lod,details)
    discard(rig,['CITV','Smoke_Launcher_L','Smoke_Launcher_R'])
    # New optical blocks are visible in the maker's prototype photo.
    m=Mesh();p=np.array([-.54,2.54,-.16]);m.box('paint',p+[0,.23,0],(.33,.46,.38))
    m.box('glass',p+[0,.25,.20],(.25,.25,.025));rig.add('Sight_Commander','Turret',p,m,'Y')
    m=Mesh();m.box('paint',(.51,2.63,.29),(.34,.23,.43));m.box('glass',(.51,2.65,.52),(.25,.13,.02))
    rig.add('Sight_Gunner','Turret',(.51,2.54,.29),m)
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();p=np.array([side*1.30,2.06,.90]);m.box('paint',p,(.22,.27,.46))
        for j in range(4):
            q=p+[side*.10,(j//2)*.10-.04,(j%2-.5)*.14]
            m.tube('metal_dark',q,q+[side*.13,.10,.11],.043,6 if lod else 10)
        rig.add('Smoke_Launcher_'+label,'Turret',p,m)
    m=Mesh();p=np.array([0,s.gun_y,s.gun_z]);tip=s.overall_length-s.length/2;n=6 if lod else 16
    m.box('paint',p+[0,0,.10],(.68,.47,.56))
    for a,b,r in ((.35,2.22,.105),(2.22,2.72,.16),(2.72,tip-s.gun_z-.27,.09)):
        m.tube('metal_dark',p+[0,0,a],p+[0,0,b],r,n)
    hollow_muzzle(m,(0,s.gun_y,tip-.27),(0,s.gun_y,tip),.083,.060,n)
    for part in rig.parts:
        if part['name']=='Gun':part['mesh']=m
    return rig,s

def ajax_hull(slug,name,lod):
    rig,s=carrier(slug,name,lod,7.62,3.35,2.05,'warrior','',7,.34,.98,True,source=GD,front_engine=True,
        features=['seven dual road wheels per side','front drive sprockets','long ASCOD-derived hull',
                  'wide steep upper bow plate and high engine deck','segmented side armour and rear troop ramp'],
        approx=True,representative='Public British Ajax-family exterior; variant-specific sensors/hatches estimated. Contract and trial status does not certify operational availability.')
    m=Mesh();profile_hull(m,'paint',[(3.54,.48,1.25),(3.81,1.12,1.32),(1.82,2.05,1.30),(-3.65,2.05,1.31),(-3.81,.52,1.26)])
    for side in (-1,1):
        m.box('paint',(side*1.41,1.15,-.05),(.49,.15,7.43))
        for z in np.linspace(-2.95,2.65,7 if not lod else 4):
            m.box('paint',(side*1.53,1.74,z),(.26,.63,.70 if not lod else 1.25))
        m.box('paint',(side*1.39,1.66,3.11),(.52,.35,.82))
        m.box('glass',(side*1.39,1.67,3.535),(.32,.14,.025))
        m.box('rubber',(side*1.43,.70,-3.74),(.53,.44,.06))
        m.box('markings',(side*1.675,1.78,-1.5),(.018,.22,.57))
    m.box('paint',(-.60,2.10,1.74),(.74,.12,.67))
    m.box('paint',(-.60,2.22,2.02),(.61,.22,.23));m.box('glass',(-.60,2.23,2.15),(.47,.12,.025))
    m.box('paint',(.61,2.09,2.22),(.89,.10,1.07))
    for z in np.linspace(1.80,2.62,3 if lod else 11):m.box('metal_dark',(.61,2.155,z),(.78,.023,.035))
    m.box('paint',(0,1.23,-3.83),(1.73,1.47,.06))
    for side in (-1,1):m.tube('metal_dark',(side*.83,.46,3.53),(side*.83,.46,3.85),.07,6 if lod else 12)
    replace_hull(rig,m);discard(rig,['Hatch_Commander'])
    s.details['inventory_status']='contracted_trials_and_acceptance_restart'
    return rig,s

def reconVehicle__ajax(lod=0):
    rig,s=ajax_hull('reconVehicle__ajax','Ajax 40mm reconnaissance',lod);s.weapon='40ct';s.turret_z=-.55
    s.features+=['large faceted40mm CTAS turret','long asymmetric turret bustle','high commander sight and cheek EO sensor','four-tube smoke banks both sides','no invented side ATGM pod']
    y=2.10;z=-.55;m=Mesh()
    b=[(-.50,1.30),(.50,1.30),(1.24,.69),(1.23,-1.21),(.95,-1.52),(-.95,-1.52),(-1.23,-1.21),(-1.24,.69)]
    t=[(-.47,.94),(.47,.94),(1.04,.50),(1.08,-1.21),(.87,-1.41),(-.87,-1.41),(-1.08,-1.21),(-1.04,.50)]
    loft(m,'paint',[[(x,y,z+zz) for x,zz in b],[(x,y+.87,z+zz) for x,zz in t]])
    m.box('paint',(-.68,2.69,z+.87),(.49,.44,.30))
    m.tube('glass',(-.68,2.70,z+1.025),(-.68,2.70,z+1.05),.16,8 if lod else 20)
    for side in (-1,1):
        m.box('markings',(side*1.25,2.55,z-.44),(.015,.23,.48))
        m.box('paint',(side*1.13,2.59,z+.44),(.16,.43,.48))
        for j in range(4):
            q=np.array([side*1.22,2.50+(j//2)*.14,z+.31+(j%2)*.20])
            m.tube('metal_dark',q,q+[side*.17,.09,.13],.048,6 if lod else 10)
    rig.add('Turret','Hull',(0,y,z),m,'Y')
    p=np.array([0,2.60,z+1.02]);m=Mesh();m.box('paint',p,(.59,.44,.47))
    m.tube('metal_dark',p+[0,0,.22],p+[0,0,1.75],.059,6 if lod else 16)
    hollow_muzzle(m,p+[0,0,1.75],p+[0,0,1.88],.044,.020,6 if lod else 16)
    rig.add('Gun','Turret',p,m,'X');rig.add('Muzzle','Gun',p+[0,0,1.88],forward='+Z')
    m=Mesh();p=np.array([.55,2.96,z-.24]);m.tube('paint',p,p+[0,.12,0],.13,6 if lod else 12)
    m.box('paint',p+[0,.35,0],(.34,.46,.38));m.box('glass',p+[0,.37,.20],(.25,.24,.025))
    rig.add('Sight_Commander','Turret',p,m,'Y')
    m=Mesh();m.tube('paint',(-.50,2.98,z-.33),(-.50,3.05,z-.33),.28,8 if lod else 20)
    rig.add('Hatch_Commander','Turret',(-.50,2.98,z-.61),m,'X')
    return rig,s

def apc__ares(lod=0):
    rig,s=ajax_hull('apc__ares','Ares specialist troop carrier',lod);s.weapon='rws';s.turret_z=.65
    s.features+=['flat rear troop roof, no40mm turret','compact remotely operated12.7mm station','roof troop hatch pair','rear ramp']
    # Compact Protector-style station, explicit on the public Ares exterior.
    from armour_parts import weapon
    s.turret_x=.48;s.details['weapon_base']=2.17;weapon(rig,s,lod)
    m=Mesh()
    for side in (-1,1):
        p=np.array([side*.55,2.09,-1.18]);m.box('paint',p,(.81,.08,1.65))
        if not lod:
            for z in (-1.8,-.6):m.tube('metal_dark',(side*.55-.21,2.17,z),(side*.55+.21,2.17,z),.022,6)
    rig.add('Troop_Roof_Hatches','Hull',(0,2.09,-1.18),m)
    s.details['weapon_calibre']='12.7mm representative; final fitted national RWS block estimated'
    return rig,s

def apc__bulldog_fv432(lod=0):
    rig,s=carrier('apc__bulldog_fv432','FV432 Mk3 Bulldog',lod,5.25,2.80,2.28,'warrior','',5,.29,.70,True,
        source=ARMY+'combat-vehicles/bulldog/',front_engine=True,approx=True,
        features=['five small road wheels','front sprocket','short high flat-roof troop box','rounded front corners and short steep glacis',
                  'large twin top troop hatches','single rear troop door','front-right manual GPMG station','two three-tube smoke banks'],
        representative='Baseline Bulldog Mk3 troop carrier, representative manualGPMG fit. Not an invented turretedIFV; later remote/urban armour kits vary. Operator5.25m/2.80m/2.28m baseline dimensions.')
    m=Mesh();profile_hull(m,'paint',[(2.38,.42,1.04),(2.625,1.55,1.07),(1.82,2.28,1.10),(-2.50,2.28,1.10),(-2.625,.45,1.06)])
    for side in (-1,1):
        m.box('paint',(side*1.22,1.03,0),(.35,.14,5.05))
        for z in np.linspace(-1.85,1.65,5 if not lod else 3):m.box('paint',(side*1.21,1.90,z),(.19,.55,.66 if not lod else 1.13))
        m.box('markings',(side*1.335,1.94,-1.15),(.014,.25,.46))
        for j in range(3):
            p=np.array([side*1.06,1.93,2.02-j*.14]);m.tube('metal_dark',p,p+[side*.17,.13,.12],.047,6 if lod else 10)
    m.box('paint',(0,1.43,-2.66),(1.35,1.64,.08))
    m.box('paint',(-.53,2.30,1.26),(.72,.08,.62));m.box('glass',(-.53,2.36,1.56),(.42,.09,.06))
    for side in (-1,1):m.box('paint',(side*.47,2.33,-.70),(.85,.08,1.68))
    m.box('paint',(.54,2.34,1.30),(.76,.10,.69))
    for z in np.linspace(.95,1.65,3 if lod else 9):m.box('metal_dark',(-.60,2.345,z),(.65,.025,.035))
    replace_hull(rig,m);discard(rig,['Hatch_Commander']);s.weapon='manual_gpmg';s.turret_z=1.08
    manual_gun(rig,'Hull',(.48,2.36,1.08),lod)
    m=Mesh();m.tube('paint',(.48,2.29,1.08),(.48,2.38,1.08),.38,8 if lod else 20)
    rig.add('Commander_Hatch_Ring','Hull',(.48,2.29,1.08),m)
    s.details['inventory_status']='inventory_reported_2026';return rig,s

def reconVehicle__jackal_3e(lod=0):
    rig,s=carrier('reconVehicle__jackal_3e','Jackal 3E Extenda',lod,7.05,2.05,2.445,'jackal','',3,.50,
        source='https://www.babcockinternational.com/news/babcock-to-build-a-further-53-jackal-3s-for-the-british-army/',
        features=['three real axles, six large tyres','open cab with visible seats','long exposed rear mission deck','detachable Extenda rear axle module',
                  'central HMG ring and front passenger pintle','high tubular roll cages','no roof glazing or invented fixed armoured cabin'],
        approx=True,axles=[-2.13,-.88,2.12],
        representative='Six-wheel contracted Jackal3E representative patrol configuration. Supacat Extenda Mk2 public7.05m/2.05m size and4.25m first-to-third axle wheelbase used as estimates for J3E; no assertion of final mission-kit equivalence.')
    m=Mesh();m.box('paint',(0,.91,0),(1.78,.31,6.77))
    # Short bonnet, front crew cell, open rear cargo deck.
    profile_hull(m,'paint',[(3.43,1.13,.78),(3.40,1.62,.80),(2.50,1.72,.80),(2.24,1.18,.82)])
    m.box('paint',(0,1.19,-1.40),(1.78,.18,3.70))
    for side in (-1,1):
        for z in (-2.13,-.88,2.12):m.box('paint',(side*.84,1.02,z),(.42,.13,1.10))
        for z in (-3.1,-.18,2.1):
            beam(m,[side*.80,1.20,z],[side*.80,2.43,z],.045,lod,'metal_dark')
        for z in (-.18,2.1):beam(m,[-.80,2.43,z],[.80,2.43,z],.045,lod,'metal_dark')
        beam(m,[side*.80,2.43,-.18],[side*.80,2.43,2.10],.045,lod,'metal_dark')
        beam(m,[side*.80,1.20,-3.1],[side*.80,1.20,-.18],.035,lod,'metal_dark')
        m.box('paint',(side*.89,1.24,.78),(.10,.56,1.55))
        m.box('markings',(side*.951,1.28,.75),(.014,.23,.44))
        m.box('glass',(side*.68,1.43,3.45),(.18,.14,.03))
        for z in (.72,-.83):
            m.box('rubber',(side*.47,1.33,z),(.45,.15,.47))
            m.box('rubber',(side*.47,1.65,z-.25),(.45,.57,.11))
    m.box('metal_dark',(0,1.32,3.45),(.87,.22,.05))
    for x in (-.62,.62):m.box('paint',(x,1.35,-2.48),(.49,.31,.91))
    beam(m,[-.80,2.43,-3.1],[.80,2.43,-3.1],.045,lod,'metal_dark')
    replace_hull(rig,m);s.weapon='manual_hmg';s.turret_z=.12
    # The shared scout whip assumed an enclosed roof. On the open Jackal,
    # attach it to the actual rear cage upright instead of leaving it in air.
    for part in rig.parts:
        if part['name']=='Antenna_1':
            target=np.array([.80,2.43,-3.10]);delta=target-part['pivot']
            part['mesh'].shift(delta);part['pivot']=target
            rig.pivots['Antenna_1']=target
    # Supported high ring; its central opening remains real geometry.
    p=np.array([0,2.43,.12]);m=Mesh();hollow_muzzle(m,p,p+[0,.10,0],.52,.45,8 if lod else 24)
    rig.add('Weapon_Ring','Hull',p,m)
    manual_gun(rig,'Hull',(0,2.53,.12),lod,.0127,1.12)
    # Passenger GPMG has its own pivots, without duplicating canonical main nodes.
    p=np.array([.81,1.91,1.72]);m=Mesh();m.tube('metal_dark',p-[0,.35,0],p,.035,6 if lod else 12)
    rig.add('Pintle_Passenger','Hull',p,m,'Y');q=p+[0,.12,0];m=Mesh()
    m.box('metal_dark',q,(.09,.12,.32));hollow_muzzle(m,q+[0,0,.12],q+[0,0,.73],.019,.00381,6 if lod else 12)
    rig.add('Gun_Passenger','Pintle_Passenger',q,m,'X');rig.add('Muzzle_1','Gun_Passenger',q+[0,0,.73])
    s.details['inventory_status']='contracted_first_vehicle_completed';return rig,s

def wheeledHowitzer__rch_155(lod=0):
    rig,s=carrier('wheeledHowitzer__rch_155','RCH 155 Boxer',lod,7.93,2.99,2.30,'boxer','',4,.61,
        source='https://www.knds.com/fileadmin/user_upload/content/Newsroom/PressAreas/2024_Eurosatory/RCH_155/KNDS_B_Ansicht_RCH155_EN.pdf',
        features=['Boxer8x8 carrier, four axles','tall unmanned AGM turret','155mmL52 long gun','360degree traverse without outriggers',
                  'no troop module or invented rear spade','large rectangular ammunition bustle','two-person forward crew compartment'],
        approx=True,representative='Public Boxer-based RCH155 exterior. British72 contracted2026, first expected2028. KNDS10.5m overall/2.99m width/3.6m height; precise future national B0 fittings estimated. Optional secondaryRWS omitted.')
    # Drive module follows Boxer; replace the troop-module roof and rear hatch.
    m=Mesh();profile_hull(m,'paint',[(3.70,.64,1.12),(3.965,1.22,1.20),(1.76,2.30,1.25),(-3.80,1.75,1.28),(-3.965,.65,1.17)])
    for side in (-1,1):
        m.box('paint',(side*1.32,1.38,-.02),(.27,.24,7.59))
        m.box('markings',(side*1.51,1.74,.93),(.014,.25,.51))
        for z in s.axle_z:m.box('paint',(side*1.26,1.35,z),(.43,.16,1.30))
        m.box('glass',(side*.97,1.70,3.67),(.25,.13,.06))
    m.box('paint',(-.58,2.33,2.29),(.67,.10,.65));m.box('glass',(-.58,2.42,2.53),(.43,.08,.13))
    for z in np.linspace(1.56,2.54,3 if lod else 12):m.box('metal_dark',(.62,2.32,z),(.69,.035,.04))
    m.box('paint',(0,1.55,-3.72),(2.02,.52,.47));replace_hull(rig,m);discard(rig,['Hatch_Commander'])
    z=-.90;y=2.27;m=Mesh();m.tube('metal_dark',(0,y-.10,z),(0,y+.10,z),1.12,8 if lod else 24)
    b=[(-1.30,1.59),(1.30,1.59),(1.43,1.34),(1.43,-1.88),(1.18,-2.09),(-1.18,-2.09),(-1.43,-1.88),(-1.43,1.34)]
    t=[(-1.20,1.33),(1.20,1.33),(1.35,1.15),(1.35,-1.82),(1.12,-2.01),(-1.12,-2.01),(-1.35,-1.82),(-1.35,1.15)]
    loft(m,'paint',[[(x,y+.10,z+zz) for x,zz in b],[(x,3.60,z+zz) for x,zz in t]])
    for side in (-1,1):
        m.box('paint',(side*1.45,2.93,z-.45),(.055,.90,1.50))
        m.box('markings',(side*1.49,3.10,z-.48),(.015,.25,.54))
        if not lod:
            for zz in np.linspace(-1.65,.5,6):m.tube('metal_dark',(side*1.49,2.60,z+zz),(side*1.515,2.60,z+zz),.016,6)
    m.box('paint',(0,2.93,z-2.12),(1.85,.84,.11))
    rig.add('Turret','Hull',(0,y,z),m,'Y');s.weapon='155mm_agm';s.turret_z=z
    artillery_barrel(rig,'Turret',(0,3.01,.76),10.5-s.length/2,.155,lod)
    s.details['inventory_status']='british_firm_order_first_delivery_expected_2028'
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('tank__','apc__','reconVehicle__','wheeledHowitzer__')) and callable(f)}

def save(slug):
    if slug.startswith('tank__'):
        tank_saver.BUILDERS[slug]=BUILDERS[slug];e=tank_saver.save(slug)
        e['notes']=e['notes'].replace('generate_inventory_additions_05.py','generate_inventory_additions_08.py')
    elif slug.startswith('wheeledHowitzer__'):
        artillery.BUILDERS[slug]=BUILDERS[slug];e=artillery.save(slug)
    else:
        common.BUILDERS[slug]=BUILDERS[slug];e=common.save(slug)
    e['notes']+=' Original national exterior: generate_inventory_additions_08.py; sources and status in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
