"""Country-audit batch 02: distinct current and confirmed-order platforms.

Exterior estimates are explicit. A model of ordered equipment is never proof
that the equipment is already operational. No source meshes or game edits.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
from vehicle_parts import Mesh,rotation,profile_hull,loft
from generate_p2_armour import carrier
from air_defence_parts import gun_mount,radar
from generate_p7_ships import combatant,carrier as aviation,sub

FFG='https://www.ffg-flensburg.de/fileadmin/user_upload/FFG_Imagebrosch%C3%BCre_EN.pdf'

def acsv(slug,name,lod):
    rig,s=carrier(slug,name,lod,6.93,2.99,1.55,'engineering','',6,.32,.86,True,source=FFG,
        features=['FFG ACSV G5 tracked carrier','six road wheels per side','high forward two-person cabin','rear mission deck','rubber-band track arrangement'],
        approx=True,representative='Dutch ordered ACSV G5 exterior; cabin and module dimensions estimated',front_engine=True,bow=.60,shoulder=.92)
    m=Mesh();profile_hull(m,'paint',[(3.30,.50,1.27),(3.40,1.10,1.36),(2.75,1.55,1.36),(-3.25,1.55,1.36),(-3.38,.50,1.25)])
    profile_hull(m,'paint',[(3.12,1.52,1.15),(2.78,2.65,1.12),(.83,2.65,1.12),(.60,1.52,1.15)])
    for side in (-1,1):
        m.box('glass',(side*.53,2.36,2.89),(.83,.40,.045),rotation([1,0,0],-.30))
        m.box('glass',(side*1.13,2.34,1.72),(.04,.42,.75))
        m.box('markings',(side*1.375,1.26,-1.70),(.02,.26,.55))
        m.box('paint',(side*1.26,1.42,0),(.27,.17,6.40))
    for p in rig.parts:
        if p['name']=='Hull':p['mesh']=m
    rig.parts=[p for p in rig.parts if p['name']!='Hatch_Commander']
    s.details['inventory_status']='ordered_future';return rig,s

def aaVehicle__skyranger_30_acsv(lod=0):
    rig,s=acsv('aaVehicle__skyranger_30_acsv','Skyranger 30 on ACSV G5',lod)
    gun_mount(rig,s,lod,'skyranger',has_radar=True)
    # The shared ring already starts at the 1.55 m mission deck height.
    delta=np.array([0,0,-1.35])
    for p in rig.parts:
        if p['name']=='Turntable' or p['parent'] in ('Turntable','Launcher'):
            p['pivot']+=delta
            if p['mesh'] is not None:p['mesh'].shift(delta)
            rig.pivots[p['name']]=p['pivot']
    for p in s.details['muzzle_positions']:
        for i in range(3):p[i]+=float(delta[i])
    s.source='https://www.defensie.nl/actueel/nieuws/2025/01/29/defensie-versterkt-luchtverdediging-met-anti-drone-kanonsystemen'
    s.features+=['tracked Dutch configuration, not wheeled Boxer','30 mm cannon and outboard missile group','three fixed AESA faces on traversing turret','first Dutch deliveries planned 2028']
    return rig,s

def shortRangeSAM__nomads(lod=0):
    rig,s=acsv('shortRangeSAM__nomads','NOMADS on ACSV G5',lod)
    p=np.array([0,1.58,-1.40]);m=Mesh();m.box('paint',p+[0,.35,0],(1.70,.70,2.50))
    rig.add('Turntable','Hull',p,m,'Y');q=p+[0,1.10,0];m=Mesh();tips=[]
    for side in (-1,1):
        for row in (-1,1):
            c=q+[side*.71,row*.19,0];m.box('paint',c,(.44,.33,3.18))
            m.tube('metal_dark',c+[0,0,1.59],c+[0,0,1.63],.13,8 if lod else 16)
            tips.append((c+[0,0,1.63]).tolist())
        m.box('paint',q+[side*.54,0,-.10],(.18,.75,.46))
    rig.add('Launcher','Turntable',q,m,'X')
    for i,tip in enumerate(tips):rig.add('Muzzle_'+str(i),'Launcher',tip,forward='+Z')
    radar(rig,'Hull',[-.75,3.06,-2.22],lod,'array',.95,.70)
    # A real .50 RWS remains separate from the missile elevation frame.
    m=Mesh();p=np.array([.50,2.70,1.60]);m.box('paint',p+[0,.10,0],(.32,.28,.38))
    rig.add('Turret','Hull',p,m,'Y');q=p+[0,.18,.18];m=Mesh();m.tube('metal_dark',q,q+[0,0,.87],.027,8 if lod else 16)
    rig.add('Gun','Turret',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,.87],forward='+Z')
    s.weapon='rws';s.details.update(tube_count=4,muzzle_positions=tips)
    s.source='https://www.kongsberg.com/what-we-do/defence-and-security/integrated-air-and-missile-defence/nomads/'
    s.features+=['four Sidewinder launch canisters','separate 3D radar mast','independent self-defence .50 RWS','Dutch order delivery from 2028']
    return rig,s

def ifv__as21_redback(lod=0):
    rig,s=carrier('ifv__as21_redback','AS21 Redback',lod,7.90,3.64,2.02,'k21','lance',7,.34,.96,True,
        source='https://www.hanwha.co.kr/newsroom/media_center/news/article.do?seq=16003',
        features=['seven road wheels and long heavy hull','Australian 30 mm turret','Spike LR2 side pack','Iron Fist active-protection fittings','deep segmented side armour','rear infantry ramp'],
        approx=True,representative='Australian ordered Redback with prototype-derived exterior; national production fittings may change',z=-.10,front_engine=True,skirts=True,storage=True,bow=.55,shoulder=.93)
    m=Mesh()
    for side in (-1,1):
        for z in np.linspace(-2.80,2.35,8 if not lod else 4):m.box('paint',(side*1.66,1.43,z),(.25,.75,.61 if not lod else 1.30))
    rig.add('Side_Armour','Hull',(0,1.43,0),m)
    m=Mesh()
    for side in (-1,1):
        p=np.array([side*.91,3.01,-.67]);m.box('paint',p,(.23,.39,.27));m.box('metal_dark',p+[side*.13,0,0],(.04,.24,.20))
        m.tube('metal_dark',p+[0,.22,0],p+[0,.35,0],.09,6 if lod else 12)
    rig.add('APS_and_Sensors','Turret',(0,2.90,-.10),m)
    s.details['inventory_status']='ordered_in_testing';return rig,s

def gunboat__arafura_class(lod=0):
    rig,s=combatant('gunboat__arafura_class','Arafura-class OPV',lod,(80.,13.,4.,3.7),
        'https://www.navy.gov.au/capabilities/ships-boats-and-submarines/hmas-arafura',
        ['80 m constabulary offshore patrol ship','high forward bridge','large working aft deck','two side boat launch positions and stern boat ramp','no invented heavy gun or anti-ship missile bank'],
        houses=[(0,10,9.8,25,6.7,0,.93),(0,12,8.5,12,3.4,6.7,.87)],funnels=[(0,-7,4,6,6.8,3)],
        masts=[(10,22,'bar',3.2)],guns=[],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,
        landing=True,ramp_height=3.1,cranes=[(-4.5,-8,5,4.3),(4.5,-8,5,4.3)])
    s.representative='Commissioned OPV exterior; omit unverified/proposed main-gun upgrades. Boat-launch stern ramp is not an amphibious well dock.'
    s.details['inventory_status']='in_service';return rig,s

def carrier__kri_sriwijaya_100(lod=0):
    rig,s=aviation('carrier__kri_sriwijaya_100','KRI Sriwijaya-100 (ex-Garibaldi)',lod,(180.2,33.4,6.7,10.3),
        'https://www.tnial.mil.id/berita/93146/KAPAL-ITS-GIUSEPPE-GARIBALDI-RESMI-TIBA-DI-JAKARTA/',
        ['compact former Italian light carrier','single long starboard island','port bow ski jump','two aircraft lifts','helicopter and drone support role','no catapults','do not infer an Indonesian fighter air wing'],
        hull_beam=23.4,deck_beam=30.4,houses=[(9,5,7.4,66,9,0,.93),(9,18,6.5,20,4,9,.89)],
        funnels=[(9,-2,4.3,7,7.4,7),(9,-18,4.3,6.8,7.4,7)],masts=[(14,28,'bar',3.8),(-14,25,'panel',3.0)],
        mast_offsets=[9,9],ski_jump=True,elevators=[(-2,42),(-2,-42)],sponsons=[(-14.5,35,4.4,7),(14.5,-38,4.4,7)])
    s.representative='September 2026 transferred exterior; Indonesian refit/weapon changes unverified, historical Italian missile armament not asserted.'
    s.details['inventory_status']='commissioned_2026_09_24';return rig,s

def submarine__scorpene_evolved(lod=0):
    rig,s=sub('submarine__scorpene_evolved','Scorpene Evolved Full LiB',lod,72.,6.2,5.8,
        'https://www.naval-group.com/sites/default/files/2024-04/PR_20240402_Naval%20Group%20and%20PT%20PAL%20have%20signed%20a%20contract%20with%20Indonesia%20for%202%20locally%20built%20Scorp%C3%A8ne%C2%AE%20Evolved%20Full%20LiB%20submarines.pdf',
        ['ordered Indonesian 72 m lithium-ion Scorpene','long parallel midbody','streamlined sail','bow diving planes','cruciform tail','single exposed propeller','no invented vertical ballistic missile cells'],
        sail_z=.12,sail_length=11.8,sail_height=5.0,foreplanes='bow')
    s.representative='Contracted public exterior concept; unpublicised beam/draft/fittings estimated, not an operational delivered boat.'
    s.details['inventory_status']='ordered_future';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    common.BUILDERS.update(BUILDERS)
    a.report.write_text(json.dumps([common.save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
