"""Five evidence-led air/sea additions, shared original Python parts, no Blender.

Orders and service states belong in the evidence ledger. Unpublished fittings
remain explicitly estimated; no generic airframe is claimed to prove ownership.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as common
import generate_p6_aircraft as planes
import generate_p5_helicopters as helis
from aircraft_parts import AircraftSpec,build as build_plane,gear
from helicopter_parts import HelicopterSpec,build as build_heli
from vehicle_parts import Mesh,merge_mesh,profile_hull,rotation
from generate_p1_tanks import beam
from generate_p7_ships import combatant

def carrierJet__rafale_m(lod=0):
    rig,s=planes.rafale('carrierJet__rafale_m','Rafale M',lod)
    s.source='https://www.defense.gouv.fr/marine/force-laeronautique-navale/rafale-marine'
    s.representative='Single-seat French naval Rafale M, carrier undercarriage and hook; mission stores representative, small fittings estimated'
    s.features+=['reinforced long naval nose strut','twin nose wheels','catapult launch bar on nose leg','single main wheel each side','hinged rear arresting hook','13-store-station naval variant, representative selected stores']
    s.details['inventory_status']='documented_operator_activity'
    s.details['gear_layout']=[dict(name='Gear_Nose',x=0,z=4.12,radius=.29,pairs=2,hinge_y=1.60),
        dict(name='Gear_Left',x=-1.18,z=-1.08,radius=.39,pairs=1,hinge_y=1.62),
        dict(name='Gear_Right',x=1.18,z=-1.08,radius=.39,pairs=1,hinge_y=1.62)]
    rig.parts=[p for p in rig.parts if not p['name'].startswith('Gear_')]
    rig.pivots={n:p for n,p in rig.pivots.items() if not n.startswith('Gear_')}
    gear(rig,s,lod)
    p=np.array([0,.59,4.08]);m=Mesh();beam(m,'metal_dark',p,p+[0,-.27,.63],.065)
    m.tube('metal_dark',p+[-.18,-.27,.63],p+[.18,-.27,.63],.045,6 if lod else 12)
    rig.add('Launch_Bar','Gear_Nose',p,m,'X')
    p=np.array([0,1.19,-4.28]);m=Mesh();q=np.array([0,.42,-6.95]);beam(m,'metal_dark',p,q,.065)
    m.box('metal_dark',q+[0,-.04,.10],(.14,.15,.28));rig.add('Arresting_Hook','Fuselage',p,m,'X')
    # Include unused physical attachment markers, not just the six loaded stores.
    # Naval Rafale: six underwing + two wingtip + five fuselage stations.
    extra=[(-5.45,1.932,-3.55),(5.45,1.932,-3.55),
        (-.68,1.13,2.50),(.68,1.13,2.50),(-.68,1.13,-1.90),(.68,1.13,-1.90),(0,1.13,.10)]
    for i,p in enumerate(extra,start=s.details['muzzle_count']):
        rig.add('Muzzle_'+str(i),'Fuselage',p,weapon_station=True,loaded=False)
        s.details['muzzle_positions']['Muzzle_'+str(i)]=list(p)
    s.details['muzzle_count']+=len(extra)
    return rig,s

def aewc__globaleye_6500(lod=0):
    rig,s=planes.largeplane('aewc__globaleye_6500','GlobalEye Global6500',lod,'global6500',
        (30.3,28.7,7.8,2.70,2.70,1.35),
        [(.95,2.45,2.8,-3.9),(6.3,2.70,-.50,-5.0),(14.35,3.24,-5.20,-6.65)],
        [(0,2.95,7.8,-8.55,-14.80,-12.25,-14.28)],
        'https://www.saab.com/products/globaleye',
        ['Bombardier Global6500 business-jet hull','ten-metre fixed dorsal ErieyeER array','paired rear turbofans','T-tail','swept wing with winglets','ventral maritime radar and optical turret','no rotating radar disc'],
        turbofans=[(-1.87,3.25,-9.15),(1.87,3.25,-9.15)],fan_radius=.61,fan_length=3.35,rear_engines=True,
        aesa_bar=dict(y=5.32,z=.30,length=10.,width=.68,height=.86),winglets=True,
        belly_radar=[0,1.29,1.60,.60,.34,1.14],
        stabilator=[(.025,7.22,-11.90,-14.4),(4.15,7.22,-12.65,-14.32)],
        gear_layout=planes.airliner_gear(30.3,4.55,.39))
    s.representative='Ordered French Global6500 platform with public GlobalEye sensor layout; national final antenna fit unpublished'
    s.details['inventory_status']='ordered_future_2030';return rig,s

def carrierDrone__vsr700(lod=0):
    source='https://www.airbus.com/en/products-services/helicopters/uas/u070/u070-technical-information'
    s=HelicopterSpec('carrierDrone__vsr700','VSR700 / U070 naval ISR', 'vsr700',6.2,1.48,1.30,.45,2.28,1.0,7.2,3,.62,7,'skid',source,
        engines=1,approximate=True,representative='Ordered French uncrewed ISR configuration; public Cabri-derived exterior, minor equipment positions estimated',
        features=['compact unmanned rounded cabin without pilot glazing','three main rotor blades','ducted seven-blade tail rotor','tubular landing skids','ventral ISR radar and optical sensor','no armed scout demonstration stores'],
        details=dict(fenestron=True,tail_y=1.55,boom_y=1.55,boom_start=-.10,main_blade_chord=.17,inventory_status='ordered_future_2028',
            profile=[(-.12,0,.25,.35),(0,0,.47,.49),(.20,0,.50,.50),(.36,-.04,.42,.43),(.48,-.12,.18,.24),(.50,-.15,.045,.075)]))
    rig,s=build_heli(s,lod)
    # Uncrewed cabin and internal diesel: no invented pilot glazing or turboshaft pods.
    for part in rig.parts:
        if part['name']=='Fuselage':part['mesh']=merge_mesh(Mesh(),part['mesh'],roles={'glass':'paint'})
    rig.parts=[p for p in rig.parts if not p['name'].startswith('Engine_')]
    m=Mesh();m.box('paint',(0,1.81,.36),(.64,.31,.89))
    if not lod:
        for z in np.linspace(.02,.62,8):m.box('metal_dark',(.332,1.82,z),(.027,.17,.035))
    rig.add('Engine_Cowling','Fuselage',(0,1.81,.36),m)
    p=np.array([0,.56,1.34]);m=Mesh();m.tube('paint',p-[0,.12,0],p+[0,.10,0],.27,8 if lod else 20)
    rig.add('Radar_Belly','Fuselage',p,m)
    p=np.array([0,.66,2.35]);m=Mesh();m.tube('paint',p-[0,.09,0],p+[0,.10,0],.15,8 if lod else 20)
    m.tube('glass',p+[0,0,.10],p+[0,0,.157],.075,8 if lod else 16)
    rig.add('Sensor_EO','Fuselage',p,m,'Y');return rig,s

def loiterer__mx_10_damocles(lod=0):
    # Product envelope80cm: four hubs with compact independently turning rotors.
    a=.255;r=.145;positions=[[side*a,.29,end*a] for side in (-1,1) for end in (-1,1)]
    s=AircraftSpec('loiterer__mx_10_damocles','MX10 Damocles','multirotor',.80,.80,.39,.18,.10,.12,0,
        'https://knds.com/en/products/ammunition/mx-10-damocles',seats=0,
        representative='Public80cm quadcopter exterior; unpublished frame and electronics proportions estimated',
        features=['80cm-class four-motor airframe','independent two-blade horizontal propellers','exposed crossed arms','central battery and front optical/munition module','no tube-launched cruciform wings'],
        details=dict(multirotor=True,unmanned=True,motors=4,propellers=positions,prop_radius=r,prop_blades=2,
            small=True,bomber=False,payload_count=1,inventory_status='delivered_and_additionally_ordered'))
    rig,s=build_plane(s,lod);m=Mesh();m.box('paint',(0,.30,-.035),(.13,.10,.27))
    m.box('metal_dark',(0,.358,-.035),(.09,.016,.09));m.tube('metal_dark',(0,.30,-.12),(0,.48,-.14),.008,4 if lod else 8)
    rig.add('Battery_and_Antenna','Fuselage',(0,.30,-.035),m);return rig,s

def seaDrone__inspector_90(lod=0):
    rig,s=combatant('seaDrone__inspector_90','Inspector90 MCM USV',lod,(9.2,2.9,.60,.65),
        'https://www.exail.com/media-file/9720/datasheet-inspector-90.pdf',
        ['9.2m aluminium shallow-draft hull','low enclosed forward steering cabin','open aft mission deck','lattice radar/communications mast aft of cabin','twin waterjets','ROV launch and recovery equipment','no invented gun or explosive attack payload'],
        houses=[],funnels=[],masts=[],guns=[],vls=[],canisters=[],ciws=[],unmanned=True,
        hangar=False,flight_deck=False,bow_sheer=.20)
    s.representative='Indonesian ordered Inspector90 hull with representative MCM LARS; final national equipment allocation not public'
    D=s.draft+s.freeboard;m=Mesh()
    profile_hull(m,'paint',[(3.34,D,.99),(2.59,D+1.10,.87),(.09,D+1.10,.87),(-.31,D,.99)])
    for side in (-1,1):
        m.box('glass',(side*.88,D+.69,1.16),(.032,.43,1.05))
        m.box('glass',(side*.43,D+.68,2.94),(.65,.43,.035),rotation([1,0,0],-.52))
        profile=[(-.5,.65),(-.45,.80),(-.3,.96),(-.1,1),(.12,1),(.30,.86),(.41,.55),(.48,.18),(.5,.008)]
        def fender(zz):return (side*(1.45*np.interp(zz/9.2,*np.array(profile).T)+.035),D-.04,zz)
        for z in np.linspace(-4.05,3.75,11 if not lod else 6):
            m.tube('rubber',fender(z-.33),fender(z+.33),.075,6 if lod else 12)
        m.tube('metal_dark',(side*.57,.53,-4.35),(side*.57,.53,-4.60),.14,8 if lod else 16)
    rig.add('Forward_Cabin','Hull',(0,D,1.40),m)
    # Open lattice supports and actual rotating navigation-radar bar.
    m=Mesh();p=np.array([0,D,-.64])
    for side in (-1,1):
        beam(m,'metal_dark',p+[side*.45,0,0],p+[side*.24,2.44,0],.07)
        for y in (.45,1.15,1.85):beam(m,'metal_dark',p+[side*.40,y,0],p+[-side*.29,y+.43,0],.04)
    m.box('paint',p+[0,.30,0],(.76,.60,.51));rig.add('Sensor_Mast','Hull',p,m)
    q=p+[0,2.53,0];m=Mesh();m.box('paint',q,(1.04,.11,.18));rig.add('Radar','Hull',q,m,'Y')
    p=np.array([0,D+.05,-2.25]);m=Mesh()
    for side in (-1,1):
        beam(m,'paint',p+[side*.72,0,.5],p+[side*.72,.66,-.85],.10)
        m.box('paint',p+[side*.72,.35,.1],(.18,.65,.35))
    beam(m,'metal_dark',p+[-.72,.66,-.85],p+[.72,.66,-.85],.09)
    rig.add('LARS','Hull',p,m,'X')
    m=Mesh();m.box('paint',(0,D+.23,-2.12),(.65,.41,.91))
    for side in (-1,1):m.tube('metal_dark',(side*.38,D+.27,-2.39),(side*.38,D+.27,-1.83),.034,6 if lod else 12)
    rig.add('MCM_Payload_Cradle','Hull',(0,D,-2.12),m)
    s.details['inventory_status']='ordered_delivery_status_pending';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}
def save(slug):
    if slug=='carrierDrone__vsr700':helis.BUILDERS[slug]=BUILDERS[slug];return helis.save(slug)
    if slug=='seaDrone__inspector_90':common.BUILDERS[slug]=BUILDERS[slug];return common.save(slug)
    planes.BUILDERS[slug]=BUILDERS[slug];return planes.save(slug)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
