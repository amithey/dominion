"""Original Italian naval inventory additions, built with shared Python parts.

Public dimensions and externally visible equipment; unmeasured contours are
estimates. Delivered ships and future U212 NFS orders retain separate statuses.
"""
from pathlib import Path
import argparse, json, math
import numpy as np
import generate_inventory_additions_05 as previous
import generate_p6_aircraft as planes
from generate_p7_ships import combatant, carrier, sub
from ship_parts import block, beam
from aircraft_parts import AircraftSpec, fuselage, wings, engines, airfoil, mirror
from vehicle_parts import Mesh, Rig, loft

NAVY='https://www.marina.difesa.it/'
FREMM=NAVY+'noi-siamo-la-marina/pilastro-logistico/log_amm/marinalles/Pagine/FREMM.aspx'

def italian_fremm(slug, name, lod, asw):
    rig,s=combatant(slug,name,lod,(144.,19.7,5.4,5.6),FREMM,
        ['Italian Carlo Bergamini-class hull, 144m overall',
         'two 76mm Strales guns' if asw else '127/64 Vulcano forward and 76mm Strales aft',
         'four Teseo antiship canisters' if asw else 'eight Teseo antiship canisters',
         '16 Sylver A50 cells, no French MdCN bank','EMPAR spherical radome above pyramidal forward mast',
         'two separate funnel blocks','twin helicopter hangars','two 25mm remote mounts',
         'CAPTAS4 stern handling enclosure and separate towed-array apertures' if asw else 'general-purpose stern, no invented CAPTAS4 deployment'],
        houses=[(0,15,15.4,43,7.4,0,.81),(0,-29.5,15.9,27,6.3,0,.92),
                (0,18,9.7,19,4.2,7.4,.74)],
        funnels=[(0,-5.5,5.5,7.7,8.6,3.4),(0,-20,5.3,6.8,7.7,3.5)],
        masts=[(16.8,27.2,'sphere',3.7),(-20.5,19.4,'bar',3.8)],
        guns=[(0,51.8,76 if asw else 127,4.7 if asw else 8.1),(0,-32.8,76,4.7,6.3,True),
              (-8.4,-11.5,25,2.,.8),(8.4,-11.5,25,2.,.8)],
        vls=[(36,4,4,.80,0)],canisters=[(-8.5,3.2,2 if asw else 4)],ciws=[],
        hangar_z=-43.1,hangar_doors=2,bow_sheer=1.15)
    s.representative='Italian ASW exterior (Alpino baseline), not French Aquitaine or ASW-EVO.' if asw else 'Italian GP exterior (Carlo Bergamini baseline), not French Aquitaine or later EVO.'
    # Distinct national forward mast apron and broad bridge wings.
    m=Mesh();D=s.draft+s.freeboard
    block(m,'paint',0,D+11.5,16.8,5.1,11.3,6.3,.40)
    for side in (-1,1):
        m.box('paint',(side*7.6,D+7.3,27.0),(2.0,.38,5.8))
        beam(m,[side*6.1,D+4.8,27],[side*8.0,D+7.1,27],.14,lod,'paint')
        m.box('paint',(side*8.4,D+.65,-11.5),(2.6,.30,3.2))
        for z in (() if lod else (-12.6,-10.4)):
            beam(m,[side*7.7,D,z],[side*8.4,D+.5,z],.12,lod,'paint')
        # Three visible tubes on each torpedo mounting, no invented missile tips.
        for j in range(3):
            x=side*7.25;y=D+1.1+(j%2)*.43;z=-18.5+(j//2)*.50
            m.tube('paint',(x,y,z-1.2),(x,y,z+1.2),.19,6 if lod else 14)
            m.tube('metal_dark',(x,y,z+1.21),(x,y,z+1.24),.14,6 if lod else 14)
    rig.add('Italian_Mast_Apron_And_Fittings','Hull',(0,D,0),m)
    if asw:
        m=Mesh();block(m,'paint',0,D-3.5,-66.0,9.8,3.7,8.0,.96)
        # A recessed dark opening framed by guides, rather than a false ramp.
        m.box('metal_dark',(0,D-1.65,-70.04),(4.5,2.5,.06))
        for x in (-2.45,2.45):m.box('paint',(x,D-1.6,-70.12),(.20,2.8,.28))
        m.box('paint',(0,D-.15,-70.13),(5.1,.24,.3))
        m.tube('metal_dark',(4.1,D-1.7,-70.12),(4.1,D-1.7,-70.20),.52,8 if lod else 24)
        rig.add('CAPTAS4_And_Towed_Array_Ports','Hull',(0,D-2,-68),m)
    s.details['inventory_status']='in_service'
    return rig,s

def asFrigate__fremm_gp_italy(lod=0):
    return italian_fremm('asFrigate__fremm_gp_italy','Italian FREMM GP',lod,False)

def asFrigate__fremm_asw_italy(lod=0):
    return italian_fremm('asFrigate__fremm_asw_italy','Italian FREMM ASW',lod,True)

def landingShip__trieste(lod=0):
    rig,s=carrier('landingShip__trieste','Trieste L9890',lod,(245.,36.,7.2,20.5),
        NAVY+'media-cultura/Notiziario-online/Pagine/20241207_A-LIVORNO-LA-CONSEGNA-DI-NAVE-TRIESTE-E-IL-GIURAMENTO-.aspx',
        ['245m LHD, 36m flight deck','two separated starboard islands','port bow ski jump',
         'stern well-deck closure with X hinge','two lateral aircraft elevators','three 76mm Strales and three 25mm mounts',
         'fixed X-band array faces and rotating L-band search radar','no catapults, no assumed future missile battery'],
        hull_beam=31.5,deck_beam=36.,
        deck_outline=[(-.50,-.469),(.50,-.469),(.50,.405),(.39,.469),(-.46,.469),(-.50,.43)],
        houses=[(11.8,33,9.7,38,10.5,.1,.88),(11.8,-22,10.1,34,10.5,.1,.87),
                (11.8,40,9.0,16,4.0,10.6,.91),(11.8,-28,8.7,15,3.8,10.6,.91)],
        funnels=[(11.8,28,5.4,8.4,7.0,10.6),(11.8,-17,5.4,8.,7.0,10.6)],
        masts=[(42,26,'bar',3.0),(-25,28,'panel',6.8)],mast_offsets=[11.8,11.8],
        guns=[(15.5,111.5,76,4.7,-2.1),(-17,-105,76,4.7,-1.5,True),
              (17,-61,76,4.7,-1.5,True),(-17.7,47,25,2.,-1.2),
              (17.7,6,25,2.,-1.2),(-17.7,-66,25,2.,-1.2)],
        sponsons=[(15.5,111.5,5.3,9.0),(-17,-105,5.4,9.2),(17,-61,5.4,9.2),
                  (-17.7,47,4.7,8.),(17.7,6,4.7,8.),(-17.7,-66,4.7,8.)],
        ski_jump=True,elevators=[(-16,-43),(16,-49)],landing=True,ramp_height=9.,
        catapults=[],flight_deck=False)
    s.representative='Delivered LHD exterior; F35B integration work is not a claim of completed carrier aviation certification. Hull beam/draft and local sensor placements estimated; 245m length and 36m deck are published. Manufacturer depth27.7m is used as main-deck height, not confused with beam.'
    # These gun galleries lie below the flight deck. Lower the complete
    # platform and its struts to support the corresponding mount bases.
    gallery_drops=(-2.2,-1.6,-1.6,-1.3,-1.3,-1.3)
    for p in rig.parts:
        if p['name'].startswith('Sponson_'):
            delta=np.array([0,gallery_drops[int(p['name'].split('_')[1])],0])
            p['pivot']+=delta;p['mesh'].shift(delta)
            rig.pivots[p['name']]=p['pivot']
    D=s.draft+s.freeboard;m=Mesh()
    # Fixed X-band faces distributed between two islands. Navigation radar
    # heads above are the separately rotating named nodes.
    for z in (43,-29):
        for side in (-1,1):
            m.box('metal_dark',(11.8+side*3.96,D+12.7,z),( .04,2.9,3.5))
        m.box('metal_dark',(11.8,D+12.6,z+7.0),(3.5,2.9,.04))
    # The very tall enclosed hull has real side openings below the deck edge.
    for side in (-1,1):
        for z in (-80,-60,-5,67):
            m.box('metal_dark',(side*15.52,D-6.6,z),(.04,2.8,5.0))
        for z in (-96,-70,-20,18,63):
            m.box('metal_dark',(side*15.48,D-11.7,z),(.05,.85,1.3))
    # Flat lower well-deck facade and a recessed frame around the hinged door.
    for x in (-8.8,8.8):m.box('paint',(x,12.1,-120.3),(2.4,10.0,2.0))
    m.box('metal_dark',(0,12.1,-121.33),(15.0,9.0,.08))
    m.box('paint',(0,17.15,-120.4),(20.,1.0,2.1))
    rig.add('LHD_Array_Faces_And_Hull_Openings','Hull',(0,D,0),m)
    s.details['inventory_status']='delivered_integration_ongoing'
    return rig,s

def submarine__u212_nfs(lod=0):
    rig,s=sub('submarine__u212_nfs','U212 NFS',lod,58.35,7.,6.0,
        'https://www.fincantieri.com/globalassets/prodotti-servizi/repository/bb1_fincantieri_scheda_naval_vessels_u212-nfs_2025.pdf',
        ['58.35m Italian NFS hull, 7m pressure hull diameter','four firm boats under construction',
         'X stern controls','sail-mounted diving planes','single seven-blade screw','six 533mm bow tube closures',
         'streamlined stepped sail and enlarged tropical cooling grilles','no unverified vertical missile bank'],
        sail_z=.075,sail_length=8.9,sail_height=5.56,x_tail=True,foreplanes='sail',prop_blades=7,
        body_profile=[(-.45,.06),(-.38,.27),(-.28,.45),(-.13,.50),(.15,.50),(.31,.48),(.43,.36),(.48,.18),(.5,.006)])
    s.representative='Contracted Italian U212 NFS public design, first delivery scheduled September2029 by OCCAR. Private hydrodynamic contours and precise sensor mast heads estimated; not a delivered Todaro boat.'
    m=Mesh();block(m,'paint',0,6.1,1.0,4.1,.75,27.,.97)
    for side in (-1,1):
        for z in np.linspace(-10,-4,3 if lod else 12):
            m.box('metal_dark',(side*2.22,6.05,z),(.045,.12,.25))
    rig.add('NFS_Upper_Casing_And_Cooling','Hull',(0,6.1,1),m)
    add_tube_closures(rig,s,lod)
    s.details['inventory_status']='firm_order_under_construction'
    return rig,s

def add_tube_closures(rig,s,lod):
    # Flush visible closures only; no open, oversized fantasy launch tubes.
    m=Mesh();L=s.length;B=s.beam
    for side in (-1,1):
        for j in range(3):
            p=np.array([side*.72,B*.44+(j-1)*.68,L*.478])
            m.tube('metal_dark',p-[0,0,.02],p+[0,0,.02],.275,8 if lod else 20)
    rig.add('Bow_Torpedo_Closures','Hull',(0,B*.44,L*.478),m)

def submarine__sauro_class(lod=0):
    rig,s=sub('submarine__sauro_class','Sauro IV series (Primo Longobardo)',lod,66.36,6.83,6.3,
        NAVY+'noi-siamo-la-marina/pilastro-operativo/mezzi/sottomarini/Pagine/06_PrimoLongobardo.aspx',
        ['Italian Sauro IV series, not shorter series III','66.36m long, 6.83m beam, 6.3m surfaced draft',
         'long raised upper casing','tall sail with slanted leading edge','sail diving planes',
         'cruciform stern controls, not U212 X-tail','single seven-blade propeller representative','six 533mm torpedo tubes'],
        sail_z=.065,sail_length=10.8,sail_height=5.25,x_tail=False,foreplanes='sail',prop_blades=7,
        body_profile=[(-.45,.055),(-.39,.25),(-.30,.43),(-.13,.50),(.17,.50),(.34,.47),(.45,.32),(.49,.16),(.5,.008)])
    # Replace the generic rounded sail with the tall, raked Sauro IV casing.
    m=Mesh();loft(m,'paint',[
        [[x,6.28,z] for x,z in [(-.83,-1.1),(.83,-1.1),(.83,8.7),(.39,9.6),(-.39,9.6),(-.83,8.7)]],
        [[x,11.53,z] for x,z in [(-.73,-.65),(.73,-.65),(.73,7.8),(.32,8.55),(-.32,8.55),(-.73,7.8)]]])
    for p in rig.parts:
        if p['name']=='Sail':p['mesh']=m
    m=Mesh();block(m,'paint',0,6.13,1.5,3.6,.76,48.,.98)
    if not lod:
        for z in np.linspace(-19,16,32):
            for side in (-1,1):m.box('metal_dark',(side*1.80,6.51,z),(.025,.16,.29))
    rig.add('Sauro_Long_Casing','Hull',(0,6.13,1.5),m)
    add_tube_closures(rig,s,lod)
    s.representative='Primo Longobardo S524, Sauro IV series. Published dimensions from Navy technical tab; hull/propeller contours estimated. Navy fleet listing does not certify October2026 readiness of each individual boat.'
    s.details['inventory_status']='fleet_listed_individual_readiness_unverified'
    return rig,s

def carrierDrone__scaneagle(lod=0):
    d={'unmanned':True,'flying_wing':True,'landing_none':True,'fins':[],
       'wing':[(.065,.30,.30,-.18),(.70,.30,.12,-.24),(1.55,.35,-.12,-.32)],
       'profile':[(-.48,0,.20,.23),(-.34,0,.38,.42),(-.10,0,.50,.50),(.24,0,.50,.50),(.40,0,.43,.44),(.5,0,.10,.12)],
       'propellers':[[0,.27,-.82]],'prop_radius':.21,'prop_blades':2,'prop_pusher':True,
       'prop_chord_scale':.16,'spinner_length':.06,'muzzle_count':0,'muzzle_positions':{},
       'inventory_status':'italian_contract_confirmed_delivery_status_unverified'}
    s=AircraftSpec('carrierDrone__scaneagle','ScanEagle maritime ISR','scaneagle',1.71,3.1,.67,.20,.26,.14,1,
        'https://www.insitu.com/products/scaneagle',seats=0,
        representative='Current manufacturer1.71m/3.1m exterior; Italian2025PO and2026 conformity work establish procurement, not delivered final sensor fit or FLARES purchase. Gearless ISR aircraft with EO nose and pusher; no weapons or fictional pilot canopy.',
        features=['3.1m swept wing','tailless layout with upturned wingtip fins','two-blade rear pusher',
                  'chin EO gimbal','wingtip Skyhook capture fittings','rail/Skyhook recovery, no wheels','unarmed'],details=d)
    rig=Rig(lod);fuselage(rig,s,lod);wings(rig,s,lod);engines(rig,s,lod)
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();m.solid('paint',[[side*1.55+dx,y,z] for dx in (-.009,.009) for y,z in
            [(.35,-.32),(.35,-.12),(.67,-.10),(.67,-.20)]],
            [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        rig.add('Wingtip_Fin_'+label,'Wing_'+label,(side*1.55,.35,-.22),m)
        m=Mesh();m.tube('metal_dark',(side*1.54,.35,-.12),(side*1.59,.35,-.11),.014,6 if lod else 12)
        m.tube('metal_dark',(side*1.59,.35,-.11),(side*1.59,.35,-.18),.014,6 if lod else 12)
        rig.add('Capture_Hook_'+label,'Wing_'+label,(side*1.54,.35,-.12),m)
    m=Mesh();rings=[]
    for yy,r in [(0,.012),(.025,.065),(.10,.10),(.175,.065),(.20,.012)]:
        rings.append([[r*math.cos(t),yy,.58+r*math.sin(t)] for t in np.linspace(0,math.tau,8 if lod else 24,endpoint=False)])
    loft(m,'paint',rings);m.tube('glass',(0,.10,.671),(0,.10,.683),.052,8 if lod else 20)
    rig.add('Sensor_Turret','Fuselage',(0,.10,.58),m,'Y')
    m=Mesh();m.box('paint',(0,.20,-.60),(.19,.12,.27))
    for side in (-1,1):
        m.box('metal_dark',(side*.097,.23,-.60),(.012,.05,.16))
        m.box('markings',(side*.101,.28,.12),(.004,.08,.18))
    rig.add('Engine_Cowl_And_Marking_Panels','Fuselage',(0,.20,-.60),m)
    for p in rig.parts:
        if p['mesh'] is not None:p['mesh'].remove_duplicates()
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('asFrigate__','landingShip__','submarine__','carrierDrone__')) and callable(f)}

def save(slug):
    if slug.startswith('carrierDrone__'):
        planes.BUILDERS[slug]=BUILDERS[slug];entry=planes.save(slug)
    else:
        previous.BUILDERS[slug]=BUILDERS[slug];entry=previous.save(slug)
    entry['notes']=entry['notes'].replace('generate_inventory_additions_05.py','generate_inventory_additions_07.py')
    return entry

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
