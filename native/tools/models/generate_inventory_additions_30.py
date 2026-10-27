"""Original Israeli public exteriors: three Skylarks, ordered F15IA, M109Doher.

Public manufacturer outlines/photos, locally estimated unlisted dimensions.
No Blender, imported meshes/images, avionics, operational logic or live stores.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p6_aircraft as planes
import generate_p3_artillery as guns
from aircraft_parts import AircraftSpec,build,curved_shell,wings,tails,engines,burnt_wreck
from vehicle_parts import Mesh,Rig,hollow_muzzle,write_glb
from generate_p1_tanks import beam,make_wreck
from generate_inventory_additions_10 import miniature_rotor
from generate_inventory_additions_23 import stations,feathered_nozzles

LEX='https://www.elbitsystems.com/sites/default/files/2025-02/skylark-lex_2016.pdf'
SK3='https://www.elbitsystems.com/sites/default/files/2025-02/skylark_3_2016.pdf'
EVTOL='https://www.elbitsystems.com/sites/default/files/2025-05/skylark_2024.pdf'
IA='https://mod.gov.il/en/press-releases/press-room/israel-mod-acquires-25-advanced-f-15-aircraft-for-52-billion'


def ground_model(r,s):
    """Ground an unarmed airframe without adding a loiterer impact marker."""
    low=min(np.asarray(g[0])[:,1].min() for p in r.parts if p['mesh'] is not None for g in p['mesh'].groups.values() if g[0])
    shift=math.floor(low*1000+1e-4)/1000
    for p in r.parts:
        if p['name']!='Fuselage':p['pivot'][1]-=shift
        if p['mesh'] is not None:p['mesh'].shift((0,-shift,0))
    for name,pivot in r.pivots.items():
        if name!='Fuselage':pivot[1]-=shift
    s.belly-=shift;s.details['ground_shift_metres']=shift
    s.details['wing']=[[x,y-shift,le,te] for x,y,le,te in s.details['wing']]
    s.details['fins']=[[x,y0-shift,y1-shift,*rest] for x,y0,y1,*rest in s.details['fins']]
    for name in ('stabilator','canard'):
        if name in s.details:s.details[name]=[[x,y-shift,le,te] for x,y,le,te in s.details[name]]
    s.details['propellers']=[[x,y-shift,z] for x,y,z in s.details['propellers']]


def small_airframe(s,lod,optic,optic_radius):
    r=Rig(lod);cy=s.belly+s.body_height/2;m=Mesh()
    curved_shell(m,'paint',[(z*s.length,cy+dy*s.body_height,rx*s.body_width,ry*s.body_height)
        for z,dy,rx,ry in s.details['profile']],lod,circumference=12 if lod else 32,longitudinal=3)
    for side in (-1,1):m.box('markings',(side*s.body_width*.5,cy,s.length*.20),(.0015,s.body_height*.28,s.length*.06))
    r.add('Fuselage',r.root,(0,0,0),m);wings(r,s,lod);tails(r,s,lod);engines(r,s,lod)
    x,y,z=optic;rad=optic_radius;m=Mesh()
    curved_shell(m,'paint',[(z-rad,y,rad*.05,rad*.05),(z-rad*.7,y,rad*.8,rad*.8),
        (z+rad*.65,y,rad*.8,rad*.8),(z+rad*.7,y,rad*.65,rad*.65)],lod,circumference=8 if lod else 20,longitudinal=2)
    m.shift((x,0,0));m.tube('glass',(x,y,z+rad*.70),(x,y,z+rad*.79),rad*.5,8 if lod else 16)
    # An outer camera housing only; no internal detector or targeting systems.
    r.add('Nose_Optic','Fuselage',optic,m,'Y')
    s.details.update(muzzle_positions={},muzzle_count=0)
    return r,s


def drone__skylark_i_lex(lod=0):
    y=.38
    s=AircraftSpec('drone__skylark_i_lex','Skylark ILEX selected public exterior','skylark_lex',1.8,3.,.65,.19,.18,.23,1,LEX,seats=0,
        representative='Manufacturer3m span and selected2016public photograph: tractor propeller, high gull wing, slender single tail boom and conventional fin/tailplane.1.8m length/local fitting sizes are estimates, not manufacturer-certified. IDF standard type corroborated by maker/government documents;2023replacement contract does not certify completed withdrawal or delivery count.',
        details={'unmanned':True,'landing_none':True,'gun':False,'stations':[],
          'profile':[(-.5,0,.07,.07),(-.30,0,.08,.08),(-.10,0,.40,.43),(.20,0,.50,.50),(.45,0,.28,.30),(.50,0,.10,.10)],
          'wing':[(.075,y,.27,-.14),(.55,y,.25,-.13),(1.35,y+.11,.14,-.10),(1.5,y+.14,.08,-.09)],
          'fins':[(0,.32,.68,-.62,-.88,-.76,-.89)],
          'stabilator':[(.01,.32,-.64,-.9),(.37,.32,-.70,-.90)],
          'propellers':[[0,.32,.95]],'prop_radius':.13,'prop_blades':2,'prop_chord_scale':.13,'spinner_length':.045})
    r,s=small_airframe(s,lod,(0,.23,.43),.065);ground_model(r,s)
    s.features=['3m high gull wing and slender single tail boom','two-blade front tractor, no rear pusher','conventional single fin and horizontal tailplane','small outer belly optic, no wheels/weapon racks or cockpit']
    s.details['inventory_status']='documented_IDF_standard_legacy_type_replacement_contract_not_full_withdrawal_proof';return r,s


def drone__skylark_3(lod=0):
    y=.79;cy=.815
    s=AircraftSpec('drone__skylark_3','Skylark3 selected electric public exterior','skylark3',2.6,4.7,1.05,.38,.33,.65,1,SK3,seats=0,
        representative='Electric Skylark3, distinct from Hybrid or ILEX. Manufacturer4.7m span and public outline/photographs;2.6m length is a local planform estimate because the brochure does not specify length. Low wing, inverted Vtail, rear pusher, closed outer belly camera.2023maker IDFmaintenance contract corroborates existing Skylark3fleet; current exact serial payload not certified.',
        details={'unmanned':True,'landing_none':True,'gun':False,'stations':[],'fin_cant':135,
          'profile':[(-.5,0,.07,.07),(-.34,0,.14,.16),(-.15,0,.37,.38),(.12,0,.50,.50),(.35,-.02,.43,.43),(.47,-.05,.22,.22),(.50,-.05,.08,.08)],
          'wing':[(.13,y,.37,-.24),(.90,y,.34,-.23),(2.15,y+.05,.19,-.17),(2.35,y+.02,.10,-.15)],
          'fins':[(-.04,cy,cy+.53,-.88,-1.22,-1.02,-1.23),(.04,cy,cy+.53,-.88,-1.22,-1.02,-1.23)],
          'propellers':[[0,cy,-1.35]],'prop_radius':.20,'prop_blades':2,'prop_pusher':True,'prop_chord_scale':.21,'spinner_length':.05})
    r,s=small_airframe(s,lod,(0,.60,.68),.10);ground_model(r,s)
    s.features=['4.7m low nearly straight wing, locally estimated body length','inverted Vtail with downward-canted real control axes','two-blade rear electric pusher, no tractor','unarmed closed outer optic housing, no wheels or fictional rocket stores']
    s.details['inventory_status']='documented_IDF_Skylark3_type_electric_selected_exterior_not_unverified_Hybrid';return r,s


def drone__skylark_i_evtol(lod=0):
    y=.53
    s=AircraftSpec('drone__skylark_i_evtol','Skylark I eVTOL contracted public exterior','skylark_evtol',2.4,3.,.86,.27,.25,.30,5,EVTOL,seats=0,
        representative='Signed2023IDF supply/replacement contract; delivered quantity/current exact acceptance not established. Selected maker2023brochure exterior: four vertical lift rotors on two longitudinal wing booms, rear pusher, Htail/twin fins, fixed landing feet. Published brochure lacks span/length;3m/2.4m and all minor dimensions are explicitly local photo estimates, not factory dimensions. Not a VTOLkit attached to the old ILEX.',
        details={'unmanned':True,'landing_none':True,'gun':False,'stations':[],
          'profile':[(-.22,0,.07,.07),(-.15,0,.35,.38),(.0,0,.50,.50),(.28,0,.49,.49),(.44,-.02,.34,.36),(.50,-.02,.10,.10)],
          'wing':[(.12,y,.39,-.17),(.72,y,.34,-.15),(1.38,y+.02,.15,-.14),(1.5,y+.01,.08,-.12)],
          'fins':[(-.53,y,y+.30,-.98,-1.23,-1.08,-1.24),(.53,y,y+.30,-.98,-1.23,-1.08,-1.24)],
          'stabilator':[(.01,y,-.98,-1.23),(.57,y,-1.0,-1.23)],
          'propellers':[[0,.425,-.58]],'prop_radius':.16,'prop_blades':2,'prop_pusher':True,'prop_chord_scale':.17,'spinner_length':.04})
    r,s=small_airframe(s,lod,(0,.28,.78),.085)
    for side,label in ((-1,'L'),(1,'R')):
        x=side*.53;m=Mesh();beam(m,'paint',(x,y,.72),(x,y,-1.13),.045)
        r.add('Lift_Tail_Boom_'+label,'Fuselage',(x,y,0),m)
        for i,z in enumerate((.63,-.40)):
            p=np.array([x,y-.055,z]);m=miniature_rotor(.23,2,lod,.027);m.shift(p)
            r.add('Rotor_'+label+str(i),'Lift_Tail_Boom_'+label,p,m,'Y',blade_count=2,diameter_metres=.46)
            m=Mesh();m.tube('paint',p+[0,-.01,0],p+[0,.09,0],.035,6 if lod else 12)
            beam(m,'metal_dark',(x,y-.08,z),(x,0.025,z+.09),.025)
            m.box('rubber',(x,.0125,z+.09),(.065,.025,.12));r.add('Motor_and_Foot_'+label+str(i),'Lift_Tail_Boom_'+label,p,m)
    ground_model(r,s);s.details.update(inventory_status='signed2023_IDF_order_exact_delivery_acceptance_unverified',lift_rotors=4,local_photo_estimated_span_and_length=True)
    s.features=['new compound fixed-wing design, not ILEX relabel','four two-blade vertical lift rotors, Yaxes on two booms','separate two-blade rear pusher, Zaxis','Htail/twin fins, four fixed landing feet, no wheels or armament'];return r,s


def jet__f_15ia(lod=0):
    _,s=planes.model('jet__f_15ia','F15IA confirmed-order public concept',lod,'f15',2,False)
    s.source=IA;s.details.update(variant='ex',stations=[],canopy_front=.385,canopy_rear=.15)
    r,s=build(s,lod);cy=s.belly+s.body_height/2
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();curved_shell(m,'paint',[(-6.7,cy-.28,.10,.18),(-5.2,cy-.28,.43,.58),(.0,cy-.25,.43,.58),(2.5,cy-.22,.10,.24)],lod,circumference=8 if lod else 24,longitudinal=2 if lod else 4,cross_power=.8)
        m.shift((side*1.65,0,0));r.add('Conformal_Tank_'+label,'Fuselage',(side*1.65,cy-.25,-2),m)
    feathered_nozzles(r,s,lod,'F110');stations(r,s,lod,(.34,.50,.72),cft=True)
    s.features=['ordered AdvancedEagle F15IAfamily, not delivered Baz or Raam','two-seat canopy, twin rectangular intakes and conformal tanks','selected modern F110family outer feathered nozzle bands and large twin-tail tip fairings','empty inner/outer wing and CFT racks; no depicted live load or copied camouflage']
    s.representative='Original selected public future F15IAconcept from the Israeli signed-order gallery, with AdvancedEagle shared parts.25confirmed2024purchase plus25option and later2026second-squadron approval are distinct stages, not deliveries. Final Israeli sensor/antenna/pylon installation and precise local dimensions unverified; generic public empty racks are representative, not a certified final station count.'
    s.details['inventory_status']='confirmed_order_future_public_concept_not_current_service';return r,s


def artillery__m109_doher(lod=0):
    r,s=guns.spg('artillery__m109_doher','M109 Doher selected Israeli exterior',lod,6.61,3.15,1.43,2.66,7,.31,.82,-.52,2.07,.72,9.12,'m109a5',2.50,2.82,.155,
        ['classic M109 seven-wheel hull/front drive, not wide A7Paladin','rear chamfered turret and long155mmgun','large rear plate spades and rear/side stowage boxes','open rounded brake with side port, no hidden loading machinery'],
        source='https://commons.wikimedia.org/wiki/File:M109_idf.webp',approximate=True,
        representative='Selected Israeli long-gun M109/Doher public2024operator exterior, current M109family corroborated by firsthand2024unit visit. Shared classic M109hull principal dimensions; local fittings/gun/brake estimates, not exact A2/A3/A5tube or serial certification. Roem introduction does not prove entire M109fleet withdrawn.')
    for side,label in ((-1,'L'),(1,'R')):
        p=next(p for p in r.parts if p['name']=='Spade_'+label);m=Mesh();q=p['pivot']
        m.box('paint',q+[0,-.42,-.10],(.77,1.12,.11));beam(m,'paint',q+[0,.05,-.03],q+[0,-.80,-.16],.10)
        beam(m,'metal_dark',q+[-.13,-.20,-.17],q+[.13,-.20,-.17],.035);p['mesh']=m
    m=Mesh();q=np.array([0,s.gun_y,s.gun_z]);end=s.overall_length-s.length/2;length=end-s.gun_z;n=6 if lod else 16
    m.box('paint',q,(.64,.48,.73));m.tube('paint',q+[0,.13,-.30],q+[0,.13,.95],.13,n)
    for a,b,rad in ((.22,2.05,.105),(2.05,2.55,.148),(2.55,length-.45,.090)):m.tube('metal_dark',q+[0,0,a],q+[0,0,b],rad,n)
    for a,b in ((end-.45,end-.35),(end-.10,end)):hollow_muzzle(m,(0,s.gun_y,a),(0,s.gun_y,b),.17,.0775,n)
    for y in (-.145,.145):m.box('metal_dark',(0,s.gun_y+y,end-.225),(.13,.05,.35))
    next(p for p in r.parts if p['name']=='Gun')['mesh']=m
    m=Mesh();z=s.turret_z-1.51
    for x in (-.91,.91):
        for y in (1.92,2.36):m.box('paint',(x,y,z),(.52,.35,.28))
    for x in (-.72,.72):m.box('paint',(x,2.25,z+.06),(.25,.52,.30))
    r.add('Rear_Stowage_Boxes','Turret',(0,2.16,z),m)
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('drone__','jet__','artillery__')) and callable(f)}


def save(slug):
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    ground=slug.startswith('artillery__');spec=asdict(s)
    if ground:spec.update(mobility='tracked',weapon='howitzer',family=s.shape,equipment='',axle_z=[])
    pts=[]
    for r in (a,b):
        for p in r.parts:
            central=p['name']=='Hull' if ground else p['name'].startswith(('Fuselage','Engine_','Intake','Canopy','Conformal_Tank','Nose_Optic'))
            if p['mesh'] is not None and central:pts.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    pts=np.concatenate(pts);lo,hi=pts.min(0),pts.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=planes.ART/('vehicles' if ground else 'aircraft')/(slug+'.glb')
    write_glb(path,[a,b],make_wreck(b,s) if ground else burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P3' if ground else 'P6','spec':spec,'units':'metres','up':'+Y','front':'+Z','research_addition':True,**({'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}} if ground else {})})
    if ground:from validate_framed_ground import validate
    else:from validate_aircraft import validate
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_30.py. Public exterior/local dimensions and current-vs-order limitations in research/evidence.json. No copied pixels/insignia, operational logic, live loads or functional internals.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
