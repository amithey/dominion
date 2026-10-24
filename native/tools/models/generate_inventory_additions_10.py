"""Original UK helicopter inventory additions; public external geometry only.

Current Merlin/Peregrine/Jupiter and contracted AW149/H47ER have separate
statuses. Aircraft envelopes distinguish fuselage length from rotors turning.
"""
from pathlib import Path
import argparse, json, math
import numpy as np
import generate_p5_helicopters as helis
from helicopter_parts import HelicopterSpec, rotor_mesh, shell_surface
from vehicle_parts import Mesh, Rig, rotation, profile_hull, loft
from ship_parts import beam

RN='https://www.royalnavy.mod.uk/'

def remove(rig,*names):
    rig.parts=[p for p in rig.parts if p['name'] not in names]
    for name in names:rig.pivots.pop(name,None)

def merlin_mk2(slug,name,lod,asac=False):
    rig,s=helis.model(slug,name,lod,'merlin',
        'British Mk2 maritime airframe, local fairings estimated from operator photographs. Distinct from HC4 rear-ramp commando transport.',
        hub_z=2.45,naval=True,source=RN+'equipment/aircraft/merlin',
        details={'naval_store':'none' if asac else 'torpedo','chin_sensor':False,'naval_radar':False,
                 'published_rotors_turning_length':22.83,'inventory_status':'documented_2026_operator_use'})
    remove(rig,'Cargo_Ramp')
    s.features=['five-blade18.6m main rotor','four-blade tail rotor','three turbine nacelles',
        'maritime Mk2 airframe without HC4 cargo ramp','nose-underbody Blue Kestrel radar fairing',
        'tricycle wheels and short sponsons','starboard hoist',
        'Crowsnest Searchwater bag and deployment bracket; no external weapon load' if asac else
        'dipping-sonar floor port and representative pair of Sting Ray torpedoes']
    m=Mesh();shell_surface(m,'paint',[(5.8,.97,.50,.18),(6.5,.95,.67,.23),
        (7.8,.95,.65,.23),(8.5,1.03,.38,.13)],lod,segments=8 if lod else 24)
    rig.add('Blue_Kestrel_Radome','Fuselage',(0,.95,7.1),m)
    m=Mesh();m.box('metal_dark',(0,.95,7.1),(.75,.17,.06))
    rig.add('Radar_Nose' if asac else 'Radar','Fuselage',(0,.95,7.1),m,'Y')
    m=Mesh()
    for side in (-1,1):
        m.tube('paint',(side*1.72,1.72,-2.55),(side*1.72,1.72,.95),.31,8 if lod else 24,r_top=.23)
        m.box('paint',(side*1.52,1.74,-.8),(.48,.39,3.30))
    rig.add('Mk2_Wheel_Sponsons','Fuselage',(0,1.72,-.80),m)
    if not asac:
        m=Mesh();m.tube('paint',(0,.78,.4),(0,1.05,.4),.46,8 if lod else 24)
        m.tube('metal_dark',(0,.75,.4),(0,.78,.4),.35,8 if lod else 24)
        rig.add('Dipping_Sonar_Port','Fuselage',(0,.78,.4),m)
    else:
        # The port-side bag is shown raised for ground clearance, as in the
        # March2026 operational photograph. Its bracket turns in the roll plane.
        p=np.array([-1.40,1.45,3.65]);m=Mesh()
        beam(m,p,p+[-1.20,.30,0],.11,lod,'paint')
        beam(m,p+[0,0,-.48],p+[-1.20,.30,-.48],.11,lod,'paint')
        m.box('paint',p+[-1.22,.30,-.24],(.22,.25,.90))
        rig.add('Crowsnest_Arm','Fuselage',p,m,'Z')
        q=np.array([-2.62,2.32,3.40]);m=Mesh();rings=[]
        for yy,r in [(-.95,.12),(-.85,.50),(-.45,.87),(.15,.94),(.65,.67),(.88,.15)]:
            rings.append([[q[0]+r*math.cos(t),q[1]+yy,q[2]+r*math.sin(t)] for t in np.linspace(0,math.tau,8 if lod else 32,endpoint=False)])
        loft(m,'paint',rings);rig.add('Crowsnest_Radome','Crowsnest_Arm',q,m)
        # The antenna moves inside the fixed fabric radome, not the entire bag.
        m=Mesh();m.box('metal_dark',q,(.70,.60,.08));rig.add('Radar','Crowsnest_Arm',q,m,'Y')
        s.details['crowsnest_pose']='raised_side_bag_ground_clearance'
        s.details['retirement_plan']='2029-12-31; future replacement not yet a named ordered operational aircraft'
    return rig,s

def navalHelicopter__merlin_hm2(lod=0):
    return merlin_mk2('navalHelicopter__merlin_hm2','Merlin HM2 ASW',lod)

def aewc__merlin_hm2_crowsnest(lod=0):
    return merlin_mk2('aewc__merlin_hm2_crowsnest','Merlin HM2 Crowsnest ASaC',lod,True)

def helicopter__aw149_nmh(lod=0):
    rig,s=helis.model('helicopter__aw149_nmh','AW149 British NMH (contracted)',lod,'nh90',
        '23 firm British aircraft, first delivery2030. Public AW149 transport exterior; final national defensive suite and weapon fit not yet certified by evidence. No Polish attack stores copied.',
        length=14.60,width=2.80,body_height=2.50,belly=.60,hub_y=3.95,hub_z=2.03,
        rotor_diameter=14.60,blades=5,tail_diameter=2.90,tail_blades=4,engines=2,
        source='https://www.leonardo.com/documents/16114711/18054569/AW149-brochure-2024.pdf/ec8f5387-7bf3-eb5b-19e1-b6d32038f11b',
        details={'tail_y':3.61,'boom_y':2.85,'boom_start':-.10,'main_gear_z':-.08,
            'gear_spread':.48,'wheel_radius':.30,'main_blade_chord':.48,
            'window_z':(-.02,.10,.22),'cross_section_power':.87,
            'profile':[(-.17,0,.23,.30),(-.10,0,.43,.47),(.08,0,.50,.50),
                (.25,0,.49,.50),(.39,-.05,.43,.44),(.48,-.13,.22,.27),(.5,-.20,.045,.075)],
            'published_rotors_turning_length':17.57,'published_height':5.07,
            'inventory_status':'firm_order_future_2030_delivery'})
    remove(rig,'Cargo_Ramp');s.family='aw149'
    s.features=['five-blade14.6m main rotor','four-blade2.9m tail rotor','two CT7-class engines',
        'broad rounded cabin and stepped cockpit','large paired sliding troop doors',
        'retractable tricycle undercarriage','low stubby main wheel sponsons',
        'high ground clearance','no unverified British missile pylons']
    m=Mesh();profile_hull(m,'paint',[(3.15,2.93,.56),(2.85,3.50,.48),(1.0,3.50,.48),(.60,2.92,.62)])
    for side in (-1,1):
        m.box('paint',(side*1.28,1.02,-1.20),(.42,.38,1.90))
        for z in (.0,2.8):
            beam(m,[side*1.35,.83,z],[side*1.65,.65,z],.05,lod)
        beam(m,[side*1.65,.65,0],[side*1.65,.65,2.8],.05,lod)
        m.box('metal_dark',(side*1.41,1.2,1.35),(.025,.035,1.50))
    rig.add('AW149_Transmission_And_Access_Steps','Fuselage',(0,2.93,2.0),m)
    return rig,s

def heavyLift__h_47er_uk(lod=0):
    rig,s=helis.model('heavyLift__h_47er_uk','British H-47 Extended Range (contracted)',lod,'chinook',
        'Fourteen firm extended-range aircraft, distinct from ordinary HC6. Public contracted receiver capability; exact radar/defensive-suite housings remain estimates. Future type, not an existing fully operational SOF fleet.',
        source='https://questions-statements.parliament.uk/written-questions/detail/2026-02-20/114700',
        details={'fuel_sponson_radius':1.05,'inventory_status':'firm_tranche1_future',
            'published_rotors_turning_length':30.14,'exact_delivery_date':'officialJuly2026 forecast late2027, later industry schedules differ; not treated as guaranteed'})
    s.features=['tandem three-blade18.3m rotors','raised aft rotor pylon','two aft engine nacelles',
        'enlarged long-range fuel sponsons','contracted air-refuelling receiver probe',
        'four wheel gear units','rear hinged cargo ramp','no invented fully fitted US MH47 mission suite']
    m=Mesh();p=np.array([1.12,1.62,5.40]);tip=np.array([1.12,1.68,10.35])
    m.tube('paint',p,tip,.082,8 if lod else 24,r_top=.055)
    m.tube('metal_dark',tip,tip+[0,0,.22],.065,8 if lod else 20)
    for z in (5.65,7.20):beam(m,[.72,1.62,z],[1.12,1.62,z],.07,lod,'paint')
    rig.add('Refuelling_Probe','Fuselage',p,m)
    rig.add('Refuelling_Contact','Refuelling_Probe',tip+[0,0,.22])
    # A connected low dorsal SATCOM housing, not an unverified radar nose.
    m=Mesh();m.tube('paint',(0,3.47,.2),(0,3.79,.2),.40,8 if lod else 24,r_top=.27)
    rig.add('Dorsal_Comms_Fairing','Fuselage',(0,3.47,.2),m)
    return rig,s

def helicopter__h145_jupiter_hc2(lod=0):
    rig,s=helis.model('helicopter__h145_jupiter_hc2','Jupiter HC2 H145 D3',lod,'panther',
        'Six British D3 aircraft, actual Cyprus flightJuly2026. Five-blade D3 and ducted tail distinguish it from four-blade HT1. Local fittings estimated; no police or H145M weapons borrowed.',
        length=11.69,width=1.73,body_height=1.80,belly=.62,hub_y=3.80,hub_z=2.02,
        rotor_diameter=10.80,blades=5,tail_diameter=1.10,tail_blades=10,gear='skid',
        source='https://www.raf.mod.uk/news/articles/new-helicopters-restore-year-round-response-capability-in-cyprus/',
        details={'tail_y':2.85,'boom_y':2.40,'boom_start':.03,'main_blade_chord':.32,
            'cross_section_power':.93,'fenestron':True,'window_z':(.08,.19,.30),
            'profile':[(-.07,0,.43,.42),(.02,0,.50,.50),(.17,0,.50,.50),
                (.29,0,.50,.50),(.40,-.04,.43,.43),(.48,-.15,.22,.29),(.50,-.22,.13,.16)],
            'inventory_status':'documented2026_cyprus_operator_use','published_rotors_turning_length':13.54,
            'published_width_including_skids':2.71,'published_height':4.0})
    s.family='h145_d3';remove(rig,'Skid')
    m=Mesh()
    for side in (-1,1):
        for z in (.50,3.10):beam(m,[side*.70,.82,z],[side*1.30,.065,z],.055,lod)
        beam(m,[side*1.30,.065,-.15],[side*1.30,.065,3.80],.055,lod)
        beam(m,[side*1.30,.065,3.80],[side*1.30,.25,4.16],.055,lod)
        m.tube('paint',(side*1.18,.66,.15),(side*1.18,.66,.65),.12,6 if lod else 16)
    rig.add('Skid','Fuselage',(0,.065,.50),m)
    for side,label in ((-1,'Left'),(1,'Right')):
        p=np.array([side*.65,1.52,-.837]);m=Mesh()
        pts=[[side*.65*math.sin(t),1.52+.65*math.cos(t),-.837]
             for t in np.linspace(0,math.pi,5 if lod else 13)]
        m.face('paint',pts,[0,0,-1]);m.box('metal_dark',(side*.17,1.52,-.852),(.025,.09,.018))
        rig.add('CargoDoor_'+label,'Fuselage',p,m,'Y')
    m=Mesh();profile_hull(m,'paint',[(3.6,2.20,.68),(3.0,3.19,.55),(.7,3.19,.55),(.1,2.20,.65)])
    rig.add('Transmission_Fairing','Fuselage',(0,2.20,2.02),m)
    m=Mesh();tz=-s.length*.465
    # Keep the duct opening clear; these wedges join its upper/rear rim to
    # the taller fin rather than filling the Fenestron with a solid panel.
    for yz in [((3.43,tz+.25),(3.94,tz-.12),(3.94,tz-.49),(3.42,tz-.43)),
               ((3.42,tz-.59),(3.42,tz-.69),(2.36,tz-.68),(2.36,tz-.59))]:
        m.solid('paint',[[x,y,z] for x in (-.045,.045) for y,z in yz],
            [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    rig.add('H145_Tail_Fin_Extensions','Fuselage',(0,2.85,tz),m)
    # The Fenestron has ten asymmetrically spaced blades in a fixed duct.
    for p in rig.parts:
        if p['name']=='Rotor_Tail':
            m=rotor_mesh(.5445,10,lod,chord=.065,root_fraction=.30,asymmetric=True)
            # Same X-axis local frame as the shared canted-tail convention.
            from vehicle_parts import merge_mesh
            posed=Mesh();merge_mesh(posed,m,rotation([0,0,1],-math.pi/2),p['pivot']);p['mesh']=posed
    m=Mesh();p=np.array([0,.91,5.34]);m.tube('paint',p,p+[0,0,.12],.10,6 if lod else 16)
    m.tube('glass',p+[0,0,.125],p+[0,0,.14],.075,6 if lod else 16)
    rig.add('Nose_Searchlight','Fuselage',p,m)
    s.features=['five-blade10.8m rotor','ten-blade asymmetric Fenestron','two engines in joined dorsal cowling',
        'wide cockpit glazing and sliding cabin doors','2.71m skid footprint','rear clamshell cargo doors',
        'unarmed Cyprus and Brunei support aircraft, not H145M attack fit']
    return rig,s

def miniature_rotor(radius,count,lod,chord):
    # Reduce the shared rotor's hub/links to this200kg aircraft scale. Scaling
    # both positions and UVs preserves metre UVs, with no glTF node scaling.
    m=rotor_mesh(radius*8,count,lod,chord=chord*8)
    for g in m.groups.values():
        for index in (0,2):
            for i,p in enumerate(g[index]):g[index][i]=(np.asarray(p)/8).tolist()
    return m

def carrierDrone__peregrine_s100(lod=0):
    s=HelicopterSpec('carrierDrone__peregrine_s100','Peregrine S100 naval ISR','s100',
        3.11,.62,.58,.30,1.10,.65,3.4,2,.50,2,'tripod',
        'https://schiebel.net/schiebel-and-thales-awarded-royal-navy-contract-by-uk-ministry-of-defence/',
        engines=1,naval=True,approximate=True,
        representative='Current British S100ISR:3.11m length,3.4m rotor,1.12m height. Body width excludes1.24m landing-foot span. Operator photograph inspected: three fixed splayed legs, no fictional skid runners or pilot windows. IMaster and EO placements estimated; exhibition Martlet fit not treated as service armament.',
        features=['compact teardrop uncrewed fuselage','two-blade3.4m rotor','two-blade tail rotor',
            'three splayed landing legs with foot pads','internal rotary engine',
            'I-Master radar and chin EO','no weapons or cockpit'],
        details={'naval_store':'none','inventory_status':'declared_service2025_operator_activity2026',
            'published_overall_width':1.24,'published_overall_height':1.12,'landing_style':'three_fixed_feet'})
    rig=Rig(lod);m=Mesh()
    shell_surface(m,'paint',[(-.15,.63,.12,.13),(.05,.64,.26,.23),(.54,.65,.31,.24),
        (1.05,.62,.28,.20),(1.40,.57,.16,.13),(1.58,.56,.035,.05)],lod,
        segments=12 if lod else 40,subdivisions=1 if lod else 4)
    shell_surface(m,'paint',[(-1.28,.70,.045,.045),(-.75,.68,.075,.065),(.05,.70,.17,.13)],lod,
        segments=8 if lod else 20,subdivisions=1 if lod else 3)
    m.tube('metal_dark',(0,.80,.65),(0,1.08,.65),.038,6 if lod else 16)
    rig.add('Fuselage',rig.root,(0,0,0),m)
    for name,p,rad,chord,axis,count in [('Rotor_Main',np.array([0,1.10,.65]),1.70,.105,'Y',2),
            ('Rotor_Tail',np.array([.045,.79,-1.28]),.25,.047,'X',2)]:
        m=miniature_rotor(rad,count,lod,chord)
        if axis=='X':
            from vehicle_parts import merge_mesh
            posed=Mesh();merge_mesh(posed,m,rotation([0,0,1],-math.pi/2),p);m=posed
        else:m.shift(p)
        rig.add(name,'Fuselage',p,m,axis,blade_count=count,diameter_metres=rad*2)
    m=Mesh();m.solid('paint',[[x,y,z] for x in (-.018,.018) for y,z in
        [(.67,-.93),(1.075,-1.22),(1.075,-1.42),(.64,-1.30)]],
        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    m.box('paint',(0,.68,-.94),(.70,.035,.23));rig.add('Tail_Surfaces','Fuselage',(0,.68,-.94),m)
    for label,anchor,foot in [('Left',[-.18,.60,.67],[-.62,.018,1.23]),
            ('Right',[.18,.60,.67],[.62,.018,1.23]),('Aft',[0,.68,-.97],[0,.018,-1.52])]:
        m=Mesh();beam(m,anchor,foot,.016,lod)
        m.tube('metal_dark',np.asarray(foot)-[0,.018,0],np.asarray(foot)+[0,.012,0],.045,6 if lod else 16)
        rig.add('Gear_'+label,'Fuselage',anchor,m)
    p=np.array([0,.34,1.04]);m=Mesh();rings=[]
    for yy,r in [(-.09,.025),(-.055,.077),(.015,.10),(.075,.055)]:
        rings.append([[r*math.cos(a),p[1]+yy,p[2]+r*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 24,endpoint=False)])
    loft(m,'paint',rings);m.tube('glass',p+[0,0,.085],p+[0,0,.105],.050,8 if lod else 20)
    rig.add('Sensor_EO','Fuselage',p,m,'Y')
    p=np.array([0,.30,.38]);m=Mesh();m.tube('paint',p-[0,.08,0],p+[0,.12,0],.17,8 if lod else 24)
    rig.add('IMaster_Radome','Fuselage',p,m)
    m=Mesh();m.box('metal_dark',p,(.19,.12,.015));rig.add('Radar','Fuselage',p,m,'Y')
    m=Mesh();m.tube('metal_dark',(.26,.58,.08),(.32,.58,.08),.035,6 if lod else 16)
    for side in (-1,1):
        if not lod:
            for z in np.linspace(.83,1.15,5):m.box('metal_dark',(side*.264,.51,z),(.015,.04,.025))
        m.box('markings',(side*.25,.68,.56),(.012,.11,.28))
    rig.add('Engine_0','Fuselage',(0,.58,.08),m)
    rig.add('Exhaust_0','Engine_0',(.33,.58,.08))
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('navalHelicopter__','aewc__','helicopter__','heavyLift__','carrierDrone__')) and callable(f)}

def save(slug):
    def checked(lod):
        rig,s=BUILDERS[slug](lod)
        for part in rig.parts:
            if part['mesh'] is not None:part['mesh'].remove_duplicates()
        return rig,s
    helis.BUILDERS[slug]=checked;e=helis.save(slug)
    e['notes']+=' Original evidence-led generator: generate_inventory_additions_10.py. Current and ordered statuses are separate in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
