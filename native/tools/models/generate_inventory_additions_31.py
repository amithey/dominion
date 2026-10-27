"""Five distinct original Israeli naval public exteriors, Python/shared parts.

Selected dated views and local estimates, not certified production drawings.
No Blender, imported meshes/pixels, national insignia or concealed machinery.
Reshef is a future public concept. Drakon's new arrival is not fleet readiness.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from generate_p7_ships import combatant,sub
from generate_inventory_additions_16 import lattice
from generate_inventory_additions_21 import upper_bridge_windows,exterior_refinement
from ship_parts import block,beam,wreck
from generate_p1_tanks import beam as square_beam
from vehicle_parts import Mesh,loft,hollow_muzzle,write_glb

ART=Path(__file__).resolve().parents[3]/'native/godot/assets/art'
RESHEF='https://mod.gov.il/en/press-releases/press-room/israel-mod-purchases-5-advanced-reshef-missile-ships-from-israel-shipyards-at-approximately-780m'
NAHSHON='https://www.idf.il/en/articles/2023/joint-idf-and-ministry-of-defense-announcement-the-israeli-navys-new-landing-craft/'
DOLPHIN='https://www.idf.il/אתרי-יחידות/זרוע-הים/כל-הכתבות/2025/שמות-הצוללות/'
DRAKON='https://www.mod.gov.il/en/press-releases/press-room/years-of-joint-work-become-an-operational-reality-ins-drakon-en-route-from-germany-to-israel'


def part(r,name):return next(p for p in r.parts if p['name']==name)


def move(r,name,delta):
    p=part(r,name);delta=np.array(delta);p['pivot']+=delta;r.pivots[name]=p['pivot'].copy()
    if p['mesh'] is not None:p['mesh'].shift(delta)


def closed_bank(r,name,x,y,z,w,length,lod):
    """Only an exterior bank cover; no invented concealed cell/weapon count."""
    m=Mesh();m.box('paint',(x,y+.14,z),(w,.28,length))
    m.box('metal_dark',(x,y+.29,z),(w*.93,.025,length*.94))
    if not lod:
        for side in (-1,1):m.box('paint',(x+side*w*.44,y+.32,z),(.07,.07,length*.85))
    r.add(name,'Hull',(x,y,z),m,fit='closed outer bank envelope, capacity not certified')


def reshef_stern(r,s,lod):
    D=s.draft+s.freeboard
    p=np.array([-3.15,D+.20,-25.5]);q=p+[0,1.18,-.10];m=Mesh()
    m.tube('paint',p,p+[0,.65,0],.48,6 if lod else 16)
    block(m,'paint',p[0],D+.70,p[2],1.30,1.20,1.70,.60)
    r.add('Turret_Aft','Hull',p,m,'Y',fit='one visible angular remote-gun exterior in selected concept, exact final calibre not certified')
    m=Mesh();m.box('paint',q+[0,0,-.16],(.37,.37,.62))
    hollow_muzzle(m,q-[0,0,.15],q-[0,0,2.10],.043,.018,5 if lod else 12)
    r.add('Gun_Aft','Turret_Aft',q,m,'X');r.add('Muzzle_Aft','Gun_Aft',q-[0,0,2.10],frame_rotation=[0,1,0,0])
    m=Mesh();x=2.05;z=-27.2;w=2.65;length=7.0;h=2.15
    m.box('paint',(x,D+h/2,z),(w,h,length))
    for side in (-1,1):
        for zz in (z-length/2,z+length/2):m.box('metal_dark',(x+side*(w/2-.04),D+h/2,zz),(.08,h,.07))
        if not lod:
            for zz in np.linspace(z-length*.46,z+length*.46,18):m.box('metal_dark',(x+side*(w/2+.01),D+h/2,zz),(.025,h*.9,.055))
    r.add('Stern_Closed_Equipment','Hull',(x,D,z),m,fit='public-concept closed equipment envelope, not asserted concealed contents')
    m=Mesh()
    for side in (-1,1):
        for z in (12.,-2.5):
            for i in range(1 if lod else 7):
                y=D+2.05+(i-3)*.13 if not lod else D+2.05
                m.box('metal_dark',(side*4.10,y,z),(.035,.82 if lod else .06,1.25))
        beam(m,[side*2.2,D+4.,-8.],[side*3.7,D+6.2,-8.],.09,lod,'paint')
    for x in (-1.8,1.8):
        for z in (19.0,20.0):
            for i in range(1 if lod else 5):m.box('metal_dark',(x,D+3.55,z+(i-2)*.11),(.8,.05,.45 if lod else .04))
    r.add('Outer_Grilles_and_Platform_Braces','Hull',(0,D,-3),m)


def landing_detail(r,s,lod):
    D=s.draft+s.freeboard;m=Mesh()
    for y in (D+3.25,D+5.25,D+7.95):
        w=8.7 if y<D+6 else 7.0;front=-18.8 if y<D+6 else -22.4;back=-35.8 if y<D+6 else -32.7
        for side in (-1,1):
            for z in np.linspace(back,front,4 if lod else 11):square_beam(m,'metal_dark',(side*w,y,z),(side*w,y+1.05,z),.045)
            for yy in (y+.5,y+1.05):square_beam(m,'metal_dark',(side*w,yy,back),(side*w,yy,front),.035)
        for x in np.linspace(-w,w,5 if lod else 13):square_beam(m,'metal_dark',(x,y,front),(x,y+1.05,front),.045)
        for yy in (y+.5,y+1.05):square_beam(m,'metal_dark',(-w,yy,front),(w,yy,front),.035)
    # One permanent aft inclined stair seen in the official quarter view.
    for i in range(5 if lod else 15):
        t=i/(4 if lod else 14);y=D+3.2+t*2.0;z=-34.0-t*3.6
        m.box('metal_dark',(7.8,y,z),(1.0,.06,.70 if lod else .24))
    for x in (7.26,8.34):
        square_beam(m,'metal_dark',(x,D+3.2,-34.),(x,D+5.2,-37.6),.09)
        square_beam(m,'metal_dark',(x,D+4.2,-34.),(x,D+6.2,-37.6),.045)
    for side in (-1,1):
        for z in (-31.,-28.,-25.,-22.):m.box('glass',(side*8.58,D+1.8,z),(.035,.62,.44))
        m.box('paint',(side*8.60,D+1.1,-33.),(.045,1.95,.86))
        m.box('metal_dark',(side*8.64,D+1.12,-32.66),(.05,.10,.10))
    r.add('Accommodation_Walkways_Stair_and_Fittings','Hull',(0,D,-27.),m)


def phalanx_bow(r,s,lod):
    """Six decorative exterior tubes on the real Y/X/Z hierarchy."""
    t=part(r,'Turret_Main');q=part(r,'Gun')['pivot'];p=t['pivot'];m=Mesh()
    m.tube('paint',p-[0,.16,0],p+[0,.68,0],.69,8 if lod else 24)
    m.box('paint',q+[0,.20,-.16],(1.15,1.35,1.23))
    rings=[]
    for y,rad in ((.65,.40),(.78,.52),(2.0,.52),(2.18,.37)):
        rings.append([q+[rad*math.cos(a),y,-.25+rad*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 24,endpoint=False)])
    loft(m,'paint',rings);t['mesh']=m;m=Mesh();m.box('metal_dark',q+[0,0,.12],(.32,.30,.32));part(r,'Gun')['mesh']=m
    m=Mesh();length=s.details['guns'][0][3]
    r.add('Barrel_Rotor','Gun',q,m,'Z',blade_count=6,fit='cosmetic six-tube naval CIWS exterior, no feed/internals')
    for i,a in enumerate(np.linspace(0,math.tau,6,endpoint=False)):
        off=np.array([.080*math.cos(a),.080*math.sin(a),0]);tip=q+off+[0,0,length]
        hollow_muzzle(m,q+off+[0,0,.15],tip,.022,.0095,3 if lod else 8)
        r.add('Muzzle_'+str(i),'Barrel_Rotor',tip)


def corvette__sa_ar_5(lod=0):
    r,s=combatant('corvette__sa_ar_5','Sa ar5 selected2018 public exterior',lod,(85.6,11.9,3.2,3.2),
        'https://commons.wikimedia.org/wiki/File:Saar_5_-_2018.jpg',
        ['compact classic Sa ar5 hull and raked bridge','two separated legacy search/sensor masts, not Sa ar6 four-face tower','bow six-tube Phalanx-family outer mount, no invented76mmgun','central enclosed launch-bank envelopes and separate exhaust group','aft helicopter hangar and open landing deck'],
        houses=[(0,13.5,8.8,16.5,3.6,0,.84),(0,-13.5,8.8,22.,4.8,0,.89),(0,12.,7.4,10.,2.6,3.6,.92)],
        funnels=[(-1.15,-1.4,1.7,3.2,4.0,4.1),(1.15,-1.4,1.7,3.2,4.0,4.1)],
        masts=[(10.5,18.,'bar',2.6),(-17.,13.0,'bar',2.0)],guns=[(0,30.,20,1.50)],vls=[],canisters=[],ciws=[],
        hangar_z=-24.6,hangar=True,flight_deck=True,bow_sheer=.85)
    upper_bridge_windows(r,s,lod,2);lattice(r,s,lod,0,10.5,18.,.82);lattice(r,s,lod,1,-17.,13.,.60)
    for i,z,y,w,h in ((0,10.5,12.48,3.0,6.0),(1,-17.,11.08,1.9,3.4)):
        block(part(r,'Mast_'+str(i))['mesh'],'paint',0,y,z,w,h,w*1.10,.30)
    exterior_refinement(r,s,lod);phalanx_bow(r,s,lod)
    # Exterior envelope only: the photograph does not resolve current cell loads.
    closed_bank(r,'Forward_Closed_Bank',0,6.4,24.,3.0,4.4,lod)
    closed_bank(r,'Aft_Closed_Bank',0,11.2,-20.,3.3,3.7,lod)
    m=Mesh();block(m,'paint',0,10.5,-3.4,5.4,2.5,6.4,.96);r.add('Central_Rack_Envelope','Hull',(0,10.5,-3.4),m)
    s.representative='Selected original2018DavidShay class exterior, attributed to Eilat by the Commons category but exact hull identity not independently certified;2025USNphoto separately confirms current Sa ar5Hanit family, not identical per-hull mast fit.85.6x11.9m nominal outer target and draft/freeboard/fittings are locally adopted estimates, not factory-certified here. Legacy two-mast/Phalanx/aviation outline rather than Sa ar6or the updated LahavMFSTARfit. Closed bank envelopes do not assert hidden missile capacity/load.'
    s.details.update(inventory_status='current_family_selected2018_public_exterior_exact_current_serial_unverified',local_dimensions_estimated=True,closed_bank_capacities_unverified=True)
    return r,s


def missileBoat__reshef(lod=0):
    r,s=combatant('missileBoat__reshef','Reshef confirmed-order official public concept',lod,(80.,11.,3.0,3.0),RESHEF,
        ['official national concept, not generic maker S80helicopter version','faceted bow gun and tiered angular bridge','pyramidal forward mast with rotating polygonal search head','raked central external covers and aft sensor platform','open stern working area, no helicopter hangar/landing circle'],
        houses=[(0,13.3,8.8,20.,3.5,0,.85),(0,9.2,7.2,10.,2.4,3.5,.88),(0,-3.5,8.3,20.,4.0,0,.92)],
        funnels=[],masts=[(7.,17.,'panel',2.4),(-8.,10.,'sphere',1.2)],guns=[(0,27.,76,3.9)],vls=[],canisters=[],ciws=[],
        hangar=False,flight_deck=False,bow_sheer=.4)
    upper_bridge_windows(r,s,lod,1);exterior_refinement(r,s,lod)
    m=Mesh();D=s.draft+s.freeboard
    block(m,'paint',0,D+5.8,7.,4.1,7.2,5.3,.42)
    m.tube('paint',(0,D+13.,7.),(0,D+17.,7.),.15,6 if lod else 16)
    beam(m,[-1.05,D+10.,9.0],[1.05,D+10.,9.0],.11,lod,'paint')
    part(r,'Mast_0')['mesh']=m
    # Small octagonal rotating public-concept panel on its real vertical spindle.
    p=part(r,'Radar');q=p['pivot'];m=Mesh();rings=[]
    for z in (-.20,.20):
        rings.append([q+[1.05*math.cos(a),1.05+1.05*math.sin(a),z] for a in np.linspace(0,math.tau,8,endpoint=False)])
    loft(m,'metal_dark',rings);m.tube('paint',q-[0,.13,0],q+[0,.35,0],.25,6 if lod else 16);p['mesh']=m
    D=s.draft+s.freeboard;m=Mesh()
    for side in (-1,1):
        # Raked closed outer launch/vent covers visible in the official image.
        verts=[[side*x,y,z] for x,y,z in [(1.3,D+4.,-2.7),(3.7,D+4.,-2.7),(3.3,D+8.,-5.5),(1.4,D+8.,-5.5),
                                         (1.3,D+4.,-5.8),(3.7,D+4.,-5.8),(3.3,D+8.,-8.6),(1.4,D+8.,-8.6)]]
        # Mesh.solid orients every convex face; mirrored input stays outward.
        m.solid('paint',verts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)])
    r.add('Raked_Central_Enclosures','Hull',(0,D+4.,-5.),m)
    m=Mesh();block(m,'paint',0,D+6.2,-8.0,8.2,.5,4.0,.96)
    for side in (-1,1):
        q=np.array([side*2.6,D+6.7,-8.0]);m.tube('paint',q,q+[0,.65,0],.45,6 if lod else 16)
        rr=[]
        for y,rad in ((.60,.32),(.77,.53),(1.4,.53),(1.6,.30)):rr.append([q+[rad*math.cos(a),y,rad*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 20,endpoint=False)])
        loft(m,'paint',rr)
    r.add('Aft_Sensor_Platform','Hull',(0,D+6.2,-8.),m)
    reshef_stern(r,s,lod)
    s.representative='Five signed December2024Reshef vessels, production started February2025with first expected about3.5years later, not current fielded fleet. Original official MODconcept inspected at full1600px: tiered bridge, angular mast, central raked covers, aft sensor platform and closed stern equipment; unlike makerS80image, no helicopter/hangar/circle.80x11m uses related makerpublicS80nominal size as representative; exact final Reshef dimensions/installed equipment/cell counts and local fittings remain unverified. No imagined concealed missile cells or future production certification.'
    s.details.update(inventory_status='confirmed_order_official_public_concept_not_current_service',related_S80_nominal_size_not_final_national_certification=True,closed_bank_capacities_unverified=True)
    return r,s


def landingShip__nahshon(lod=0):
    r,s=combatant('landingShip__nahshon','Nahshon class selected public landing-ship exterior',lod,(95.,20.,4.2,3.0),NAHSHON,
        ['95x20m operator-published ship, distinct from a missile corvette','long empty open cargo deck and broad closed bow loading ramp','aft full-width accommodation and upper wheelhouse','paired tall side exhaust trunks and central antenna mast','no invented helicopter hangar, missiles or gun fit'],
        houses=[(0,-27.5,17.3,17.0,5.2,0,.98),(0,-27.8,13.6,10.5,2.7,5.2,.97)],
        funnels=[(-7.4,-29.,1.7,3.6,6.7,3.3),(7.4,-29.,1.7,3.6,6.7,3.3)],
        masts=[(-28.,17.,'bar',4.0)],guns=[],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,
        landing=True,bow_ramp=True,ramp_height=5.0,bow_sheer=0,
        hull_profile=[(-.5,.84),(-.46,.98),(-.30,1),(.15,1),(.38,.92),(.5,.70)])
    upper_bridge_windows(r,s,lod,1);exterior_refinement(r,s,lod);D=s.draft+s.freeboard
    # The loading ramp hinges at the actual cargo deck, not a waterline marker.
    p=part(r,'Ramp');q=np.array([0,D,s.length*.5+.04]);p['pivot']=q;r.pivots['Ramp']=q.copy();m=Mesh()
    m.box('paint',q+[0,2.5,0],(8.0,5.0,.22))
    for x in np.linspace(-3.7,3.7,3 if lod else 9):m.box('metal_dark',q+[x,2.5,.14],(.09,4.7,.08))
    p['mesh']=m;s.details['ramp_hinge']='cargo_deck'
    m=Mesh()
    for side in (-1,1):
        # Low cargo bulwarks leave a broad, genuinely empty working deck.
        m.box('paint',(side*8.6,D+.6,9.),(.24,1.2,52.))
        for z in (-32.,-21.):
            block(m,'paint',side*8.1,D+4.9,z,2.5,.22,3.,.98)
        for z in (-18.,1.,20.):
            m.tube('paint',(side*7.9,D,z),(side*7.9,D+.20,z),.49,6 if lod else 16)
    r.add('Cargo_Bulwarks_and_Walkways','Hull',(0,D,0),m)
    m=Mesh()
    for side in (-1,1):
        for z in (-29.,-27.,-25.):m.box('glass',(side*6.64,D+7.1,z),(.035,.64,1.0))
    r.add('Wheelhouse_Side_Windows','Hull',(0,D+7.1,-27.8),m);landing_detail(r,s,lod)
    s.representative='Operator95x20m principal size.2023handover and2024arrival/commissioning ceremony distinguished from completion of all integration/readiness. Original official aft bridge photos inspected through a credited IDFphoto mirror; local draft4.2m, freeboard, bow/hull/ramp/remaining fittings are selected estimates, not complete factory drawings. Broad cargo deck, aft accommodation, upper bridge, side exhaust trunks and cargo-deck bow ramp, no fictional missile/aviation load. Same class can represent Komemiyut, not a different duplicate vessel.'
    s.details.update(inventory_status='delivered_class_2024_integration_exact_current_FOC_unverified',local_draft_freeboard_and_fittings_estimated=True)
    return r,s


def sail_and_casing(r,s,lod,width,length,height):
    """Original flat-sided rounded sail; decorative external casing only."""
    B=s.beam;z=s.details['sail_z']*s.length;base=B*.92;m=Mesh();rings=[];n=12 if lod else 40
    for y,scale in ((base,.94),(base+.45,1),(base+height-.30,1),(base+height,.94)):
        rings.append([[width*.5*scale*math.copysign(abs(math.sin(a))**.45,math.sin(a)),y,
                       z+length*.5*math.copysign(abs(math.cos(a))**.85,math.cos(a))] for a in np.linspace(0,math.tau,n,endpoint=False)])
    loft(m,'paint',rings);part(r,'Sail')['mesh']=m
    m=Mesh()
    for side in (-1,1):m.box('markings',(side*width*.5,base+height*.5,z+length*.12),(.022,.65,1.8))
    part(r,'Sail_Fittings')['mesh']=m
    m=Mesh();rr=[]
    for zz,w,low,top in [(-s.length*.34,.38,4.0,4.75),(-s.length*.24,.95,5.7,6.9),(0,1.15,6.0,6.95),(s.length*.28,.95,5.7,6.90),(s.length*.40,.30,4.4,5.65)]:
        rr.append([[-w,low,zz],[w,low,zz],[w,top,zz],[-w,top,zz]])
    # The casing's raised middle underside is concave; orient each station
    # face explicitly instead of using a convex-solid centroid heuristic.
    m.face('paint',rr[0],[0,0,-1]);m.face('paint',rr[-1],[0,0,1])
    for a,b in zip(rr,rr[1:]):
        for i,outward in enumerate(([0,-1,0],[1,0,0],[0,1,0],[-1,0,0])):
            j=(i+1)%4;face=np.array([a[i],a[j],b[j],b[i]]);normal=np.cross(face[1]-face[0],face[2]-face[0])
            if np.dot(normal,outward)<0:normal=-normal
            m.face('paint',face,normal)
    if not lod:
        for zz in np.linspace(-s.length*.20,s.length*.26,18):
            for side in (-1,1):m.box('metal_dark',(side*1.04,6.72,zz),(.08,.08,.33))
    for zz in (-s.length*.18,s.length*.23):
        top=float(np.interp(zz,[q[0][2] for q in rr],[q[2][1] for q in rr]));m.tube('paint',(0,top,zz),(0,top+.06,zz),.40,8 if lod else 24)
    r.add('Upper_Casing','Hull',(0,6.8,0),m)
    for side in ('L','R'):move(r,'DivePlane_'+side,(0,1.75,0))


def submarine__dolphin_i(lod=0):
    r,s=sub('submarine__dolphin_i','DolphinI selected original public exterior',lod,57.3,6.8,6.2,DOLPHIN,
        ['short original diesel-electric Dolphin generation, not longer AIPboats','small rounded flat-sided sail and narrow upper casing','high shoulder-mounted bow diving planes','four Xstern controls and one decorative open screw','no invented VLSsail or deck'],
        sail_z=.11,sail_height=4.6,sail_length=10.0,x_tail=True,foreplanes='bow',prop_blades=7)
    sail_and_casing(r,s,lod,1.9,10.0,4.6)
    s.representative='2025operator lists original DolphinI and AIPas distinct current generations. Selected original museum/participant1990slaunch/sea photographs, smaller10m rounded sail/high bow planes/narrow casing, not an AIPrename.57.3x6.8m nominal target and local fitting/draft sizes are adopted estimates here, not primary factory certification; underwater hull, Xcontrol/shaft details and seven decorative screw blades unverified. No reconstructed weapon internals/capacity or concealedVLS.'
    s.details.update(inventory_status='documented_current_original_generation_selected_historical_public_fit',local_dimensions_and_propulsor_estimated=True)
    return r,s


def submarine__drakon(lod=0):
    r,s=sub('submarine__drakon','INS Drakon newly delivered public exterior',lod,73.,6.8,6.2,DRAKON,
        ['extended DolphinAIPfamily, not Dakar or original compact sail','very long broad flat-sided rounded sail visible in2026operator pictures','forward-clustered mast housings and high bow planes','four Xstern controls and one representative decorative screw','closed outer hull and sail, no imagined VLSinternals'],
        sail_z=.075,sail_height=5.6,sail_length=23.,x_tail=True,foreplanes='bow',prop_blades=7)
    sail_and_casing(r,s,lod,3.25,23.,5.6)
    z=s.details['sail_z']*s.length
    for i in range(4):
        p=part(r,'Periscope_'+str(i));move(r,p['name'],(0,0,z+6.2+i*.85-p['pivot'][2]))
    delta=z+8.0-part(r,'Mast_0')['pivot'][2]
    for name in ('Mast_0','Radar'):move(r,name,(0,0,delta))
    s.representative='TKMS/MODSeptember2026handover/transit confirmed, official23Septannouncement and subsequent firsthand28Septboarded report/credited IDFexterior photographs corroborate new arrival, not fleetwide operational certification. Operator publishes only length greater than70m: selected73m body/6.8m beam/23m long3.25m broad sail and local fittings are photo estimates, not exact factory dimensions. Four foreclustered representative masts, closed sail/casing/high bow planes. No asserted hidden silos, weapon capacities, propulsion internals or authentic screw hydrodynamics; seven blades decorative. Not the separately ordered future Dakarclass.'
    s.details.update(inventory_status='newly_delivered_Sept2026_exact_operational_certification_unverified',published_length_lower_bound_metres=70,local_dimensions_and_propulsor_estimated=True)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('corvette__','missileBoat__','landingShip__','submarine__')) and callable(f)}


def save(slug):
    from validate_naval_inventory31 import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    pts=np.concatenate([g[0] for g in part(a,'Hull')['mesh'].groups.values() if g[0]]);lo,hi=pts.min(0),pts.max(0);c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=ART/'ships'/(slug+'.glb');write_glb(path,[a,b],wreck(b),c,{'scene_name':s.name,'vehicle':slug,'priority':'P7','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_31.py; source-published size/status and adopted local estimates explicitly separated in research/evidence.json. Closed exteriors only, no copied pixels/symbols or internal weapon/propulsion systems. Cargo-deck Ramp checked against actual deck Y by validate_naval_inventory31.py.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
