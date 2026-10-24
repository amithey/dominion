"""Original evidence-led national variants: batch06, no Blender.

Public dimensions and visible fittings; uncertain measurements are disclosed.
Ordered equipment and delivered evaluation vehicles retain their actual status.
"""
from pathlib import Path
import argparse,json
import numpy as np
import generate_inventory_additions as common
import generate_inventory_additions_05 as previous
import generate_p3_artillery as artillery
from generate_p2_armour import carrier
from generate_p1_tanks import Spec,finish,basket
from generate_p7_ships import combatant
from artillery_parts import truck_howitzer
from vehicle_parts import Mesh,profile_hull,loft,rotation,hollow_muzzle

def replace_hull(rig,m):
    for p in rig.parts:
        if p['name']=='Hull':p['mesh']=m

def tank__ariete_c2(lod=0):
    s=Spec('ariete_c2','Ariete C2',7.99,3.61,1.834,2.65,7,.34,1.02,.10,2.16,1.32,9.905,'ariete',
        ['seven dual rubber-lined road wheels','four return rollers each side','120mm L44','upgraded long powerpack deck','Attila-D panoramic and Lothar-SD gunner optics','wider track fit','rear turret basket','baseline C2, no unverified PSO armour package'],
        'https://idv-otomelara.com/ariete-c2/',approximate=True,
        representative='Delivered C2 baseline with published7.99m chassis/9.905m overall/3.61m width; private hull and sensor contours estimated, no speculative full PSO kit.')
    b=[(-.44,1.40),(.44,1.40),(1.44,.67),(1.42,-1.37),(1.08,-1.90),(-1.08,-1.90),(-1.42,-1.37),(-1.44,.67)]
    t=[(-.43,.77),(.43,.77),(1.12,.42),(1.20,-1.38),(.99,-1.80),(-.99,-1.80),(-1.20,-1.38),(-1.12,.42)]
    def detail(h,m,s,l):
        m.box('paint',(-.66,2.78,.08),(.47,.37,.48));m.box('glass',(-.66,2.79,.33),(.32,.23,.02))
        m.box('paint',(.58,2.60,.89),(.44,.28,.52));m.box('glass',(.58,2.60,1.163),(.31,.16,.022))
        h.box('paint',(0,1.89,-2.67),(2.19,.16,1.72))
        for x in np.linspace(-.88,.88,4 if l else 11):h.box('metal_dark',(x,1.985,-2.67),(.055,.025,1.39))
        for side in (-1,1):m.box('paint',(side*1.34,2.14,-1.04),(.20,.34,1.02))
        basket(m,s,l,z=-2.04,width=2.65)
    rig,s=finish(s,b,t,lod,detail)
    rig.parts=[p for p in rig.parts if not p['name'].startswith('Roller_')]
    rig.pivots={n:p for n,p in rig.pivots.items() if not n.startswith('Roller_')}
    for side,label in ((-1,'L'),(1,'R')):
        for i,z in enumerate(np.linspace(-2.05,2.05,4)*s.track_scale):
            p=np.array([side*(s.width/2-.35),s.track_scale,z]);m=None
            if not lod:
                m=Mesh();m.tube('rubber',p+[-.16,0,0],p+[.16,0,0],.12*s.track_scale,8)
            rig.add('Roller_'+label+str(i),'Hull',p,m,'X')
    return rig,s

def ifv__lynx_kf41_lance_italy(lod=0):
    rig,s=carrier('ifv__lynx_kf41_lance_italy','Lynx KF41 Italian first-delivery Lance',lod,
        7.73,3.60,2.24,'warrior','lance',6,.35,.96,True,z=-.34,front_engine=True,
        source='https://www.rheinmetall.com/en/media/news-watch/news/2026/01/2026-01-27-leonardo-and-rheinmetall-hand-over-first-lynx-infantry-fighting-vehicles-to-italy',
        features=['six large road wheels','heavy long modular troop hull','30mm Lance first-delivery turret','raised front engine deck','deep side modules','rear ramp','January2026four vehicles for Italian evaluation, not future Hitfist turret'],
        approx=True,representative='Italian January2026 initialLance-equipped evaluation vehicles. No assertion of installed optionalATGM or finalHitfist configuration.')
    m=Mesh();profile_hull(m,'paint',[(3.60,.50,1.19),(3.82,1.25,1.42),(2.05,2.24,1.38),(-3.60,2.24,1.43),(-3.78,.58,1.22)])
    for side in (-1,1):
        m.box('paint',(side*1.47,1.14,-.05),(.58,.14,7.34))
        for z in np.linspace(-2.93,2.43,7 if not lod else 4):
            m.box('paint',(side*1.63,1.80,z),(.25,.90,.71 if not lod else 1.25))
        m.box('rubber',(side*1.52,.70,-3.67),(.55,.48,.07))
    m.box('paint',(-.61,2.28,1.65),(.63,.08,.79));m.box('glass',(-.61,2.35,1.95),(.43,.08,.17))
    for z in np.linspace(1.40,2.45,3 if lod else 10):m.box('metal_dark',(.61,2.27,z),(.95,.04,.04))
    m.box('paint',(0,1.34,-3.78),(1.89,1.56,.06));replace_hull(rig,m)
    # A dedicated Lance exterior without assuming a national missile bank.
    m=Mesh();y=2.35;z=-.34
    b=[(-.60,1.24),(.60,1.24),(1.14,.55),(1.05,-1.22),(-1.05,-1.22),(-1.14,.55)]
    loft(m,'paint',[[(x,y,z+zz) for x,zz in b],[(x*.83,y+.78,z+zz*.90) for x,zz in b]])
    m.tube('paint',(-.43,3.10,-.68),(-.43,3.21,-.68),.30,6 if lod else 12)
    m.box('paint',(.61,3.25,-.75),(.30,.29,.32));m.box('glass',(.61,3.25,-.58),(.20,.17,.02))
    for p in rig.parts:
        if p['name']=='Turret':p['mesh']=m
    s.details['inventory_status']='delivered_evaluation';return rig,s

def ewVehicle__fuchs_cg20_suas(lod=0):
    rig,s=carrier('ewVehicle__fuchs_cg20_suas','Fuchs CG20+ sUAS',lod,7.39,3.09,2.30,'fuchs','',3,.62,
        source='https://www.bundeswehr.de/de/ausruestung-technik-bundeswehr/landsysteme-bundeswehr/transportpanzer-fuchs-cg20-suas',
        axles=[-2.18,-.03,2.22],front_engine=True,approx=True,
        representative='German counterIED/UAS CG20+ exterior; public overall dimensions, antenna/roof component measurements estimated from operator photographs.',
        features=['6x6 Fuchs hull','two windscreens and angular driving compartment','low bow and full-height troop capsule','multiple upright jammer antenna housings','MG3 self-defence station','not a cargo-bodied EW truck'])
    removed={'Mission_Shelter','Mast'}
    rig.parts=[p for p in rig.parts if p['name'] not in removed]
    rig.pivots={n:p for n,p in rig.pivots.items() if n not in removed}
    m=Mesh();profile_hull(m,'paint',[(3.51,.61,1.05),(3.62,1.46,1.37),(2.44,2.30,1.35),(-3.37,2.30,1.38),(-3.60,.65,1.09)])
    for side in (-1,1):
        m.box('glass',(side*.57,2.015,2.85),(.87,.40,.04),rotation([1,0,0],-.36))
        m.box('glass',(side*1.365,2.02,1.82),(.035,.40,.65))
        m.box('paint',(side*1.31,1.44,1.73),(.12,.66,.82))
        m.box('metal_dark',(side*1.48,.97,1.76),(.26,.10,.84))
        for z in s.axle_z:m.box('paint',(side*1.36,1.25,z),(.40,.10,1.34))
        m.box('paint',(side*.63,1.34,-3.56),(1.10,1.39,.08))
        m.box('markings',(side*1.40,1.54,-1.38),(.02,.28,.52))
        for y in (1.57,1.88,2.17):
            for z in (-2.55,-1.25,.05):m.box('paint',(side*1.42,y,z),(.14,.24,1.23))
    replace_hull(rig,m)
    m=Mesh()
    # Two different raised jammer heads and four slender whips, matching
    # the operator's CG20+sUAS side photograph rather than a truck mast.
    for x,z in [(-1.,-2.85),(1.,-2.85),(-.96,.65),(.96,.65)]:
        p=np.array([x,2.30,z]);m.tube('metal_dark',p,p+[0,1.64,0],.014,4 if lod else 6,r_top=.005)
    for i,z in enumerate((-1.65,.05)):
        p=np.array([-.42,2.30,z]);m.tube('paint',p,p+[0,.80,0],.075,6 if lod else 12)
        if i:
            m.tube('paint',p+[0,.72,0],p+[0,1.32,0],.125,6 if lod else 12)
            m.tube('metal_dark',p+[0,1.30,0],p+[0,1.62,0],.018,4 if lod else 6)
        else:
            for a in np.linspace(0,6.283185,4 if lod else 6,endpoint=False):
                d=np.array([.12*np.cos(a),0,.12*np.sin(a)])
                m.tube('paint',p+d+[0,.54,0],p+d+[0,1.08,0],.018,4 if lod else 6)
            m.tube('paint',p+[0,1.04,0],p+[0,1.41,0],.16,6 if lod else 12)
            m.tube('paint',p+[0,1.38,0],p+[0,1.58,0],.19,6 if lod else 12,r_top=.10)
    rig.add('Jammer_Antennas','Hull',(0,2.30,-1.70),m)
    p=np.array([-.44,2.43,1.72]);m=Mesh();m.tube('metal_dark',p,p+[0,.28,0],.07,6 if lod else 12)
    m.box('paint',p+[0,.46,.28],(.74,.48,.055))
    rig.add('Turret','Hull',p,m,'Y');q=p+[0,.29,.08];m=Mesh();m.box('metal_dark',q,(.12,.16,.35))
    hollow_muzzle(m,q+[0,0,.12],q+[0,0,.91],.022,.00762/2,6 if lod else 12)
    rig.add('Gun','Turret',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,.91],forward='+Z')
    s.weapon='mg3';s.details['inventory_status']='in_service';return rig,s

def wheeledHowitzer__caesar_mkii(lod=0):
    rig,s=truck_howitzer('wheeledHowitzer__caesar_mkii','CAESAR MkII',lod,8.70,2.55,3.18,
        [-2.86,-1.39,2.76],.65,.155,6.25,
        'https://knds.com/en/press-releases/the-french-mod-orders-109-caesar-mk-ii-from-nexter-a-company-of-knds',
        approximate=True,representative='French109system firm order; larger protected Arquus6x6cab, current public exterior proportions estimated, not proof of delivery/FOC.')
    m=Mesh();L=s.length;bed=.65*2.05+.10
    for side in (-1,1):
        m.box('metal_dark',(side*.67,.95,-.12),(.18,.27,8.30))
        for z in s.axle_z:m.box('paint',(side*1.08,1.34,z),(.42,.13,1.40))
    m.box('paint',(0,bed,-.80),(2.40,.17,6.25))
    # Long reinforced bonnet and chamfered four-seat protected capsule.
    profile_hull(m,'paint',[(4.25,1.18,.98),(4.22,2.10,.96),(3.18,2.23,1.02),(2.90,1.18,1.04)])
    profile_hull(m,'paint',[(3.24,1.15,1.08),(3.15,2.52,1.10),(2.72,3.18,1.06),(.69,3.18,1.07),(.61,1.15,1.08)])
    for side in (-1,1):
        m.box('glass',(side*.48,2.80,2.98),(.79,.43,.05),rotation([1,0,0],-.58))
        for z in (1.13,2.15):m.box('glass',(side*1.10,2.78,z),(.035,.43,.58))
        m.box('paint',(side*1.12,2.12,1.65),(.035,.66,1.75))
        m.box('metal_dark',(side*1.21,1.20,1.65),(.29,.13,1.70))
        m.box('glass',(side*.89,1.57,4.28),(.26,.18,.04))
        m.box('paint',(side*.88,2.18,-.40),(.54,1.16,1.24))
    m.box('metal_dark',(0,1.74,4.28),(1.19,.47,.04));replace_hull(rig,m)
    s.details['inventory_status']='ordered_delivery_status_unverified'
    s.features+=['new protected four-seat angular cabin','long reinforced bonnet','460hp Arquus chassis configuration','unchanged155mm52cal artillery system']
    return rig,s

def gunboat__flamant_class(lod=0):
    rig,s=combatant('gunboat__flamant_class','Flamant-class PSP',lod,(54.,10.,2.70,2.75),
        'https://www.defense.gouv.fr/marine/forces-surface/patrouilleurs-service-public-psp',
        ['54m public-service patrol hull','high forward bridge','open stern RHIB launch area','two12.7mm manual mounts','water cannon','two navigation radar bars','no missile bank or heavy naval turret'],
        houses=[(0,7.2,7.2,19.5,3.8,0,.89),(0,9.0,6.6,8.0,2.2,3.8,.90)],
        funnels=[(0,-4.9,2.6,3.5,3.0,1.7)],masts=[(3.3,9.0,'bar',2.3),(3.3,7.2,'bar',1.8)],
        guns=[],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.65,
        landing=True,ramp_height=2.30,boat_z=-16.0)
    # Both navigation bars occupy one physical mast. The second named
    # mount is an attached bracket, not a second destroyer-size tower.
    for part in rig.parts:
        if part['name']=='Mast_0':
            m=Mesh();profile_hull(m,'paint',[(3.76,9.20,.44),(3.60,14.45,.18),(3.02,14.45,.18),(2.84,9.20,.44)])
            m.box('paint',(0,12.65,3.3),(2.2,.10,.18));part['mesh']=m
        elif part['name']=='Mast_1':
            m=Mesh();m.box('paint',(0,12.60,3.3),(1.70,.10,.17));part['mesh']=m
    s.representative='Flamant/Pluvier PSP54 baseline; published54×10m. Draft and private deck components estimated; stern launch ramp is for its RHIB, no amphibious assault well dock. Only two12.7mm guns, no invented20/30mm cannon.'
    platforms=Mesh()
    for side,label in ((-1,'Main'),(1,'Secondary')):
        platforms.box('paint',(side*3.68,9.25,11.50),(1.10,.14,3.10))
        p=np.array([side*3.75,9.32,11.50]);m=Mesh();m.tube('metal_dark',p,p+[0,.72,0],.075,6 if lod else 12)
        name='Turret_'+label;rig.add(name,'Hull',p,m,'Y');q=p+[0,.76,.06];m=Mesh()
        m.box('metal_dark',q,(.15,.18,.55));hollow_muzzle(m,q+[0,0,.20],q+[0,0,1.12],.026,.00635,6 if lod else 12)
        gun='Gun' if label=='Main' else 'Gun_Secondary';rig.add(gun,name,q,m,'X')
        rig.add('Muzzle' if label=='Main' else 'Muzzle_1',gun,q+[0,0,1.12],forward='+Z')
    rig.add('Bridge_Wing_Gun_Platforms','Hull',(0,9.25,11.50),platforms)
    m=Mesh();p=np.array([0,6.15,17.0]);m.tube('paint',p-[0,.72,0],p+[0,.65,0],.12,6 if lod else 12)
    m.tube('paint',p+[0,.65,0],p+[0,.65,1.05],.13,6 if lod else 12)
    rig.add('Water_Cannon','Hull',p,m,'Y')
    s.details['inventory_status']='in_service';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('tank__','ifv__','ewVehicle__','wheeledHowitzer__','gunboat__')) and callable(f)}

def save(slug):
    if slug.startswith(('tank__','gunboat__')):
        previous.BUILDERS[slug]=BUILDERS[slug];e=previous.save(slug)
        e['notes']=e['notes'].replace('generate_inventory_additions_05.py','generate_inventory_additions_06.py')
    elif slug.startswith('wheeledHowitzer__'):
        artillery.BUILDERS[slug]=BUILDERS[slug];e=artillery.save(slug)
    else:
        common.BUILDERS[slug]=BUILDERS[slug];e=common.save(slug)
    e['notes']+=' Original national exterior: generate_inventory_additions_06.py; sources/status in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
