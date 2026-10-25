"""Original Japanese service airframes, public exterior approximations, no Blender.

Sizes distinguish fuselage length from rotor sweep. National service evidence
and dated losses are recorded separately from model geometry and readiness.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_p5_helicopters as helis
import generate_p6_aircraft as planes
from aircraft_parts import AircraftSpec,build,curved_shell
from helicopter_parts import shell_surface
from generate_inventory_additions_12 import remove
from generate_inventory_additions_13 import without_box
from generate_p1_tanks import beam
from vehicle_parts import Mesh,hollow_muzzle

GSDF='https://www.mod.go.jp/gsdf/equipment/air/index.html'
F2='https://www.mod.go.jp/asdf/equipment/sentouki/F-2/'
RQ4='https://www.mod.go.jp/asdf/equipment/globalhawk/RQ-4B_Globalhawk/'
E2='https://www.navair.navy.mil/product/E-2D'

def connected_skids(r,s,lod,spread):
    remove(r,'Skid');m=Mesh()
    # Cross-tubes attach inside the actual curved cabin, rather than floating
    # beyond the side of a narrow fuselage.
    for side in (-1,1):
        for z in (s.length*.09,s.length*.28):
            beam(m,'metal_dark',(side*s.width*.29,s.belly+.45,z),(side*spread,.14,z),.065)
        m.tube('metal_dark',(side*spread,.07,-s.length*.12),(side*spread,.07,s.length*.32),.07,6 if lod else 16)
        beam(m,'metal_dark',(side*spread,.07,s.length*.32),(side*spread,.29,s.length*.36),.08)
    r.add('Skid','Fuselage',(0,s.belly,s.length*.1),m)

def helicopter__uh_1j(lod=0):
    r,s=helis.model('helicopter__uh_1j','UH-1J',lod,'bell205',length=12.70,width=2.35,
        engines=1,rotor_diameter=14.69,hub_y=3.84,hub_z=2.45,source=GSDF,
        details={'tail_y':2.67,'cross_section_power':.73,
          'profile':[(0,.08,.20,.25),(.04,0,.46,.46),(.14,0,.50,.50),(.31,0,.50,.50),(.40,-.06,.41,.43),(.475,-.17,.21,.27),(.50,-.19,.045,.065)]},representative='JGSDF single-engine UH-1J utility exterior; unarmed transport configuration. Body width estimated; published 2.86m tailplane and 14.69m rotor retained.')
    # Huey synchronized elevator is 2.86m, not the broad generic Bell412 box.
    body=next(p for p in r.parts if p['name']=='Fuselage')
    body['mesh']=without_box(body['mesh'],(0,2.37,-s.length*.355),(s.width*1.55,.09,s.length*.075))
    # Named elevator and extended Japanese nose, distinct from UH2 cowling.
    m=Mesh();m.box('paint',(0,2.37,-s.length*.355),(2.86,.085,.79));r.add('Elevator','Fuselage',(0,2.37,-s.length*.355+.395),m,'X')
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();x=side*1.177
        # Two sliding-door windows and lower rectangular panel, inside cabin
        # shoulders; visible door rail and latch remain separate fittings.
        m.box('paint',(x,1.36,2.35),(.045,.68,1.90))
        for z in (1.90,2.78):m.box('glass',(x,1.98,z),(.045,.52,.64))
        m.box('metal_dark',(x,2.30,2.35),(.05,.035,2.02))
        m.box('metal_dark',(side*1.21,1.53,3.18),(.035,.04,.15))
        r.add('Cabin_Door_'+label,'Fuselage',(x,1.4,2.35),m,translation_axis='Z')
    connected_skids(r,s,lod,1.16)
    m=Mesh();shell_surface(m,'paint',[(5.08,1.36,.66,.44),(5.85,1.28,.55,.38),(6.35,1.15,.08,.10)],lod)
    r.add('Nose_Fairing','Fuselage',(0,1.3,5.4),m)
    s.features=['single T53 engine and one exhaust','two-blade 14.69m main rotor','two-blade tail rotor','Huey sliding cabin doors','extended Japanese nose','2.86m synchronized elevator','connected landing skids; no weapon stations']
    return r,s

def gunship__ah_1s_japan(lod=0):
    r,s=helis.model('gunship__ah_1s_japan','AH-1S (Japan)',lod,'cobra',length=13.59,
        rotor_diameter=13.41,source=GSDF,tail_side=-1,
        representative='JGSDF Fuji-built AH-1S, representative TOW and 70mm rocket fit; public exterior estimates, no internal weapon construction.')
    connected_skids(r,s,lod,.88)
    # TOW is carried in four launch containers per outer rack, not as four
    # exposed finned missiles. Retain one game launch marker per rack.
    for label in ('L','R'):
        name='Store_'+label+'1';part=next(p for p in r.parts if p['name']==name);p=part['pivot'];m=Mesh()
        beam(m,'paint',p+[0,.36,0],p,.11)
        for dx in (-.13,.13):
            for dy in (-.13,.13):
                a=p+[dx,dy,-.67];b=p+[dx,dy,1.03]
                m.tube('paint',a,b,.105,6 if lod else 20)
                m.tube('metal_dark',b,b+[0,0,.018],.089,6 if lod else 20)
        m.box('metal_dark',p+[0,0,-.21],(.53,.53,.07));part['mesh']=m
        marker=next(p for p in r.parts if p['parent']==name and p['name'].startswith('Muzzle_'))
        marker['pivot']=p+[0,0,1.048];r.pivots[marker['name']]=marker['pivot']
        s.details['muzzle_positions'][marker['name']]=marker['pivot'].tolist()
    # Angular flat glazing is a characteristic of Japanese production Cobra.
    m=Mesh()
    for side in (-1,1):
        x=side*.43
        for za,zb,ya,yb in [(2.72,3.60,2.48,2.13),(3.73,4.48,2.12,1.90)]:
            m.face('glass',[(x,1.75,za),(x,1.56,zb),(x,yb,zb),(x,ya,za)],[side,0,0])
            beam(m,'paint',(x,ya,za),(x,yb,zb),.025)
    r.add('Canopy_Flat_Panels','Fuselage',(0,2.1,3.5),m)
    s.features=['narrow tandem stepped angular canopy','single T53 engine','two-blade 13.41m rotor','two-blade port tail rotor','3.28m stub wings; paired four-tube TOW banks and rocket pods','three-barrel20mm chin turret Y and Gun X','skid gear; no mast radar']
    return r,s

def jet__f_2a(lod=0):
    # F2 has enlarged wing and tail and a longer radome; independent station
    # coordinates, not a uniformly scaled F16 model.
    r,s=planes.airframe('jet__f_2a','Mitsubishi F-2A',lod,'f2',(15.50,11.10,5.00,1.42,1.50,1.03),
        [(.53,1.12,-3.40),(2.4,.10,-3.10),(5.55,-1.68,-2.73)],
        [(0,2.20,5.00,-2.20,-6.85,-4.72,-6.10)],F2,
        features=['enlarged clipped trapezoidal composite wing','long pointed Japanese radar nose','single F110 nozzle','elliptical chin intake','single-seat canopy','large rear stabilators and twin ventral fins','wingtip missile rails and separate controls'],
        side_intakes=False,engine_radius=.56,gun_side=-1,gun_fraction=.20,
        stabilator=[(.48,1.89,-3.63,-6.83),(3.11,1.89,-5.18,-6.53)],
        ventral_fin=True,stations=(.36,.59,.80),
        profile=[(-.455,0,.37,.38),(-.40,0,.5,.5),(-.25,0,.5,.5),(0,.05,.5,.46),(.16,.16,.46,.43),(.31,.07,.34,.35),(.43,.02,.17,.20),(.5,0,.012,.02)],
        representative='Single-seat F-2A, empty representative external pylons and wingtip rails; published15.5x11.1x5.0m. Small fittings estimated.')
    # Leave the game's stores empty; generic shared missile shapes are not
    # evidence of a Japanese operational loadout.
    remove(r,*['Store_'+label+str(j) for label in ('L','R') for j in range(3)])
    positions={'Muzzle_0':s.details['muzzle_positions']['Muzzle_0']};count=1
    for side,label in ((-1,'L'),(1,'R')):
        for j in range(3):
            parent='Pylon_'+label+str(j);p=np.asarray(r.pivots[parent])+[0,-.3,.35]
            r.add('Muzzle_'+str(count),parent,p,purpose='empty external station');positions['Muzzle_'+str(count)]=p.tolist();count+=1
        m=Mesh();p=np.array([side*5.55,1.81,-2.0]);m.box('metal_dark',p,(.075,.11,1.30))
        r.add('Wingtip_Rail_'+label,'Wing_'+label,p,m)
        p=p+[0,0,.65];r.add('Muzzle_'+str(count),'Wingtip_Rail_'+label,p,purpose='empty wingtip station');positions['Muzzle_'+str(count)]=p.tolist();count+=1
    s.details.update(muzzle_positions=positions,muzzle_count=count)
    return r,s

def aewc__e_2d_japan(lod=0):
    gear=[{'name':'Gear_Nose','x':0,'z':5.0,'radius':.31,'pairs':2},
          {'name':'Gear_Left','x':-4.05,'z':-.2,'radius':.49,'pairs':1,'hinge_y':3.3},
          {'name':'Gear_Right','x':4.05,'z':-.2,'radius':.49,'pairs':1,'hinge_y':3.3}]
    return planes.largeplane('aewc__e_2d_japan','E-2D (Japan)',lod,'e2',(17.60,24.56,5.58,2.45,2.4,1.23),
        [(.8,3.32,1.5,-2.0),(12.28,3.5,0,-1.5)],
        [(x,2.3,4.8,-4.8,-7.9,-6.,-7.5) for x in (-3.65,-1.2,1.2,3.65)],E2,
        ['high straight wing','two eight-blade NP2000 propellers','four vertical fins','7.32m rotating radar disc','twin nose tyres and single main tyres','JASDF land-based early warning, unarmed'],
        propellers=[(-4.05,3.10,3.),(4.05,3.10,3.)],prop_radius=2.05,prop_blades=8,prop_nacelle=5.2,
        stabilator=[(.5,2.3,-4.9,-7.8),(4.4,2.3,-5.3,-7.6)],radome=[0,5.12,-.65,3.66,3.66,.92],gear_layout=gear)

def drone__rq_4b_japan(lod=0):
    s=AircraftSpec('drone__rq_4b_japan','RQ-4B Global Hawk (Japan)','rq4',14.50,39.90,4.70,1.70,2.35,.86,1,RQ4,seats=0,
        representative='Unarmed JASDF RQ-4B public exterior. March2026 census3 is historical: one lost15September2026; model does not claim fleet availability.',
        features=['39.9m high-aspect-ratio tapered wings','large raised SATCOM nose without canopy','one dorsal jet inlet and rear exhaust','outward-canted V tail','retracting tricycle gear','no propeller, pylons or weapon markers'],
        details={'unmanned':True,'gun':False,'stations':(),
          'wing':[(.60,2.45,.95,-1.10),(5.6,2.60,.10,-1.35),(14.5,3.05,-1.08,-1.92),(19.95,3.36,-1.81,-2.30)],
          'fins':[(-.40,2.45,4.70,-4.3,-6.70,-5.65,-6.65),(.40,2.45,4.70,-4.3,-6.70,-5.65,-6.65)],'fin_cant':42,
          'dorsal_intake':True,'engine_radius':.38,'sensor_turret':False,
          'profile':[(-.50,-.18,.035,.055),(-.40,-.09,.27,.32),(-.20,-.02,.44,.43),(0,.07,.48,.5),(.22,.15,.50,.60),(.38,.10,.42,.60),(.47,-.09,.23,.38),(.5,-.19,.025,.08)],
          'gear_layout':[{'name':'Gear_Nose','x':0,'z':4.65,'radius':.27,'pairs':1,'hinge_y':1.38},
            {'name':'Gear_Left','x':-1.35,'z':-.5,'radius':.38,'pairs':1,'hinge_y':1.45},
            {'name':'Gear_Right','x':1.35,'z':-.5,'radius':.38,'pairs':1,'hinge_y':1.45}]})
    r,s=build(s,lod)
    # The engine is mounted high aft; the generic fighter nozzle and its
    # midbody dorsal inlet are replaced together, with an enclosed rear pod.
    remove(r,'Engine_0','Afterburner','Intake_Dorsal')
    m=Mesh();curved_shell(m,'paint',[(-6.83,2.68,.35,.35),(-5.9,2.78,.49,.46),(-3.3,2.98,.53,.48),(-2.1,3.02,.48,.43)],lod,cap_end=False)
    hollow_muzzle(m,(0,3.02,-2.55),(0,3.02,-2.10),.48,.40,8 if lod else 24)
    hollow_muzzle(m,(0,2.68,-6.45),(0,2.68,-6.94),.35,.28,8 if lod else 24)
    r.add('Engine_0','Fuselage',(0,2.85,-4.5),m)
    from aircraft_parts import quat
    r.add('Afterburner','Engine_0',(0,2.68,-6.94),frame_rotation=quat([0,1,0],math.pi),afterburning=False)
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('helicopter__','gunship__','jet__','aewc__','drone__')) and callable(f)}

def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for part in r.parts:
            if part['mesh'] is not None:part['mesh'].remove_duplicates()
        return r,s
    module=helis if slug.startswith(('helicopter__','gunship__')) else planes
    module.BUILDERS[slug]=checked;e=module.save(slug)
    e['notes']+=' Original generator generate_inventory_additions_14.py. National holdings, orders and losses require dated research evidence; no combat readiness inferred.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
