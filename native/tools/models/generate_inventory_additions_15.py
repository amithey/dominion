"""Japanese rescue/maritime rotorcraft and two distinct naval exteriors.

Original Python surfaces, public dimensions, estimated local fittings.
No imported meshes, photographs, textures, Blender or weapon internals.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_p5_helicopters as helis
import generate_inventory_additions_05 as saver
from generate_inventory_additions_12 import remove
from generate_inventory_additions_13 import without_box
from generate_p7_ships import combatant,carrier
from helicopter_parts import shell_surface
from vehicle_parts import Mesh,lathe_x,merge_mesh,hollow_muzzle,rotation
from generate_p1_tanks import beam

JMSDF='https://www.mod.go.jp/msdf/equipment/'

def twin_tyres(r,lod,labels,radius):
    for p in r.parts:
        if p['name'] not in ['Wheel_'+label for label in labels]:continue
        rr=radius*(.77 if p['name']=='Wheel_Nose' else .65 if p['name']=='Wheel_Tail' else 1)
        m=Mesh();q=p['pivot'];half=rr*.18
        for side in (-1,1):
            tyre=Mesh();lathe_x(tyre,[(-half,0,'paint'),(-half,rr*.70,'rubber'),(-half*.65,rr,'rubber'),
                (half*.65,rr,'rubber'),(half,rr*.70,'rubber'),(half,0,'paint')],segments=8 if lod else 20)
            merge_mesh(m,tyre,t=q+[side*rr*.30,0,0])
        p['mesh']=m

def transmission(r,s,lod):
    m=Mesh();hz=s.hub_z
    shell_surface(m,'paint',[(hz-1.2,s.hub_y-.67,.28,.13),(hz-.6,s.hub_y-.52,.47,.27),
        (hz+.5,s.hub_y-.54,.43,.25),(hz+.9,s.hub_y-.65,.24,.12)],lod,segments=8 if lod else 24)
    r.add('Transmission_Fairing','Fuselage',(0,s.hub_y-.52,hz),m)

def replace_tailplane(r,s,width):
    for p in r.parts:
        if p['name']=='Fuselage':
            q=(0,s.details['tail_y']-.30,-s.length*.355)
            p['mesh']=without_box(p['mesh'],q,(s.width*1.55,.09,s.length*.075))
            p['mesh'].box('paint',q,(width,.09,s.length*.075))

def helicopter__uh_60j_rescue(lod=0):
    r,s=helis.model('helicopter__uh_60j_rescue','UH-60J rescue',lod,'blackhawk',length=15.65,width=2.36,
        source='https://www.mod.go.jp/asdf/equipment/kyuunanki/UH-60J/',
        details={'chin_sensor':False,'tail_gear_z':-.40,'tail_gear_anchor_y':1.75},
        representative='JASDF UH60J rescue, representative probe-equipped airframe; operator explicitly limits refuelling fit to a subset. Not Army UH60JA or naval ASW fit. Local contours estimated.')
    transmission(r,s,lod);replace_tailplane(r,s,4.40)
    # Tanks need separate meshes before merging, otherwise the second side
    # would shift the first one twice.
    m=Mesh()
    for side in (-1,1):
        tank=Mesh();shell_surface(tank,'paint',[(.25,1.63,.10,.10),(.80,1.63,.35,.37),(3.40,1.63,.35,.37),(4.05,1.63,.035,.06)],lod,segments=8 if lod else 24)
        tank.shift((side*2.23,0,0));merge_mesh(m,tank)
        beam(m,'paint',(side*.96,2.01,2.20),(side*2.23,2.05,2.20),.13)
    r.add('External_Fuel_Tanks','Fuselage',(0,1.63,2.2),m)
    m=Mesh();p=np.array([1.07,2.65,4.10]);beam(m,'paint',p,p+[.55,.14,0],.10)
    m.tube('paint',p+[.55,.14,0],p+[.55,.14,-.72],.15,8 if lod else 20)
    beam(m,'metal_dark',p+[.55,.14,-.67],p+[.55,-.54,-.67],.025)
    r.add('Rescue_Hoist','Fuselage',p,m)
    m=Mesh();m.tube('paint',(1.01,1.14,4.72),(1.01,1.14,7.65),.055,8 if lod else 20)
    m.tube('metal_dark',(1.01,1.14,7.65),(1.01,1.14,8.03),.042,8 if lod else 16)
    r.add('Refuelling_Probe','Fuselage',(1.01,1.14,4.72),m)
    m=Mesh();m.tube('paint',(0,1.19,6.70),(0,1.19,7.56),.34,8 if lod else 24,r_top=.20)
    m.tube('glass',(-.34,1.09,6.75),(-.34,1.09,7.01),.16,8 if lod else 20)
    r.add('Rescue_Radar_And_FLIR','Fuselage',(0,1.19,6.7),m)
    s.features=['rescue BlackHawk cabin with right-side hoist','paired external fuel tanks','representative subset refuelling probe','nose weather radar and FLIR','four main and four canted tail blades','long aft single-tailwheel gear','unarmed; no ASW torpedoes or weapon stations']
    return r,s

def navalHelicopter__sh_60j(lod=0):
    r,s=helis.model('navalHelicopter__sh_60j','SH-60J',lod,'blackhawk',length=15.30,width=2.36,
        rotor_diameter=16.40,hub_y=3.92,source=JMSDF+'rotorcraft/patrol/sh60j/',naval=True,
        details={'tail_gear_z':-.08,'tail_gear_anchor_y':1.35,'naval_radar':False,'naval_store':'torpedo'},
        representative='Original SH60J compact Seahawk-derived cabin, not enlarged K/L body. March2026 holdings require later serviceability review; representative ASW stores, public exterior contours estimated.')
    transmission(r,s,lod);replace_tailplane(r,s,4.40);twin_tyres(r,lod,['Tail'],.27)
    m=Mesh();shell_surface(m,'paint',[(4.12,.81,.18,.12),(4.60,.78,.58,.22),(5.55,.84,.54,.22),(5.89,.96,.17,.10)],lod,segments=8 if lod else 24)
    r.add('Search_Radar_Radome','Fuselage',(0,.82,5.0),m)
    m=Mesh();m.box('metal_dark',(0,.82,5.0),(.61,.12,.06));r.add('Radar','Fuselage',(0,.82,5.0),m,'Y',mechanism='internal antenna inside fixed lower fairing')
    s.features=['compact Japanese SH60J Seahawk cabin','four16.4m main blades and four canted tail blades','twoT700 engines','fixed lower-nose search-radar fairing with internal Y antenna','short shipboard tail gear with twin tyres','representative two ASW torpedo stations','no enlarged SH60K/L cabin']
    return r,s

def heavyLift__mch_101(lod=0):
    r,s=helis.model('heavyLift__mch_101','MCH-101',lod,'merlin',length=19.53,width=3.20,
        source=JMSDF+'rotorcraft/ms-t/mch-101/',hub_y=5.15,
        representative='JMSDF mine-countermeasure and transport MCH101. Clean transport/external towing-hardpoint fit; minehunting equipment can be stowed internally, no invented ASW torpedoes.22.8m turning length versus19.53m airframe. Local fairings estimated.')
    twin_tyres(r,lod,['Left','Right','Nose'],.39)
    # The MCH has a real aft loading ramp, unlike ASW Merlin HM2.
    m=Mesh();p=np.array([0,1.15,-3.36]);m.box('paint',p+[0,.74,-.10],(2.14,1.48,.16))
    if not lod:
        for x in np.linspace(-.86,.86,7):m.box('metal_dark',p+[x,.74,-.191],(.035,1.29,.025))
    r.add('CargoRamp','Fuselage',p,m,'X')
    m=Mesh()
    for side in (-1,1):
        pod=Mesh();shell_surface(pod,'paint',[(-2.55,1.60,.12,.10),(-1.9,1.60,.40,.27),(1.4,1.60,.40,.27),(1.91,1.60,.12,.10)],lod,segments=8 if lod else 24)
        pod.shift((side*2.03,0,0));merge_mesh(m,pod)
        m.box('paint',(side*1.70,1.58,-.35),(.70,.30,3.7))
    r.add('Wheel_Sponsons','Fuselage',(0,1.60,-.35),m)
    m=Mesh();shell_surface(m,'paint',[(7.48,1.72,.25,.21),(8.57,1.79,.53,.45),(9.31,1.82,.25,.27)],lod,segments=8 if lod else 24)
    r.add('Nose_Fairing','Fuselage',(0,1.8,8.6),m)
    m=Mesh();beam(m,'metal_dark',(-.70,1.30,8.15),(-1.20,1.34,9.75),.026)
    m.tube('paint',(-1.20,1.34,9.72),(-1.20,1.34,9.84),.11,8 if lod else 20)
    r.add('Nose_Air_Data_Probe','Fuselage',(-.70,1.30,8.15),m)
    m=Mesh();m.tube('metal_dark',(0,1.30,-3.35),(0,1.30,-3.71),.075,8 if lod else 20)
    r.add('MCM_Tow_Attachment','Fuselage',(0,1.30,-3.35),m)
    s.features=['threeRTM322engines','five18.6m main blades and four tail blades','three paired-wheel landing struts','wide sponsons and Japanese cabin window fit','rear loading ramp X','extended nose and air-data boom','MCM towing attachment, no invented missile or ASW stores']
    return r,s

def gunboat__hayabusa_class(lod=0):
    r,s=combatant('gunboat__hayabusa_class','Hayabusa class',lod,(50.,8.4,1.7,2.5),
        JMSDF+'ships/pg/hayabusa/',
        ['50m high-speed missile boat','one forward76mmL62gun','four aft inclined SSM containers','three transom waterjets','faceted bridge and lattice search mast','no helicopter deck or hangar'],
        houses=[(0,2.5,5.45,17.8,3.30,0,.79),(0,4.0,4.5,7.0,1.45,3.3,.87)],
        funnels=[(-1.28,-7.9,1.25,3.2,3.4,1.5),(1.28,-7.9,1.25,3.2,3.4,1.5)],
        masts=[(-2.,13.3,'bar',2.7)],guns=[(0,16.0,76,4.70)],
        vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.55)
    D=s.draft+s.freeboard
    # Hayabusa's open lattice mast, rather than the shared solid tower.
    m=Mesh()
    for x in (-.67,.67):
        for dz in (-.55,.55):
            beam(m,'paint',(x,D+3.8,-2.+dz),(x*.34,D+13.3,-2.+dz*.34),.075)
    for yy in (4.2,6.3,8.4,10.5,12.6):
        f=(yy-3.8)/9.5;xx=.67*(1-f*.66);zz=.55*(1-f*.66)
        for side in (-1,1):
            beam(m,'metal_dark',(-xx,D+yy,-2.+side*zz),(xx,D+yy,-2.+side*zz),.045)
            if not lod and yy<12.6:beam(m,'metal_dark',(-xx,D+yy,-2.+side*zz),(xx*.86,D+yy+1.8,-2.+side*zz*.86),.025)
    for part in r.parts:
        if part['name']=='Mast_0':part['mesh']=m
    # Four individual cylinders in two paired oblique launch groups.
    for side,label in ((-1,'L'),(1,'R')):
        p=np.array([side*1.28,D+1.02,-16.0]);m=Mesh()
        for dx in (-.39,.39):
            a=p+[dx,-.15,-2.18];b=p+[dx,1.06,1.93]
            m.tube('paint',a,b,.32,8 if lod else 24)
            m.tube('metal_dark',b,b+[0,.02,.06],.29,8 if lod else 20)
            beam(m,'paint',a-[0,.65,0],a,.12)
        r.add('SSM_Containers_'+label,'Hull',p,m,container_count=2)
    # Surface render of the three jet outlets, no invented exposed propellers.
    for i,x in enumerate((-1.87,0,1.87)):
        m=Mesh();q=np.array([x,1.38,-25.12]);hollow_muzzle(m,q+[0,0,.46],q,.43,.32,8 if lod else 24)
        m.box('paint',q+[0,.08,-.08],(.94,.14,.30));r.add('Waterjet_'+str(i),'Hull',q,m)
    s.representative='Operator50x8.4m,draft1.7m; stern jets, bridge and four SSM exterior containers interpreted from official photographs. Local hull and fittings estimated; no fleet-wide readiness claim.'
    return r,s

def carrier__hyuga_class(lod=0):
    r,s=carrier('carrier__hyuga_class','Hyuga class DDH',lod,(197.,33.,7.,15.),
        JMSDF+'ships/ddh/hyuga/',
        ['197m through-deck helicopter destroyer','long starboard island with two funnels','rounded/chamfered bow flight deck','two inboard aircraft elevators','four fixed FCS3 array directions','two Phalanx mounts','aft starboard VLS bank','no catapult, ski jump or fixed-wing strike fit'],
        hull_beam=25.0,deck_beam=33.,houses=[(10.2,7.0,9.2,69.,9.0,0,.94),(10.2,22.,7.1,20.,4.1,9.,.89)],
        funnels=[(10.2,9.,5.2,7.5,7.0,7.3),(10.2,-13.0,5.2,7.0,7.0,7.3)],
        masts=[(21.,25.,'bar',3.4),(-17.,20.,'bar',2.8)],mast_offsets=[10.2,10.2],
        elevators=[(0,47.),(0,-53.)],ciws=[(-12.8,76.,.3),(13.,-76.,.3)],
        sponsons=[(-12.8,76.,4.,7.),(13.,-76.,4.,7.)],vls=[])
    D=s.draft+s.freeboard
    # Two octagonal integrated FCS3 structures; fixed faces do not spin.
    m=Mesh()
    from ship_parts import block
    for z in (24.,-18.):
        block(m,'paint',10.2,D+12.0,z,6.3,4.2,6.3,.78)
        for side in (-1,1):
            m.box('metal_dark',(10.2+side*2.64,D+14.2,z),(.035,1.40,1.90))
            m.box('metal_dark',(10.2,D+14.2,z+side*2.64),(1.90,1.40,.035))
    r.add('FCS3_Fixed_Arrays','Hull',(10.2,D+14.2,24.),m)
    # Aft starboard16-cell closure arrangement: closed exterior only.
    m=Mesh()
    for i in range(4):
        for j in range(4):m.box('paint',(10.0+(i-1.5)*.88,D+.20,-79.+(j-1.5)*.88),(.79,.18,.79))
    r.add('VLS_0','Hull',(10.,D,-79.),m,cell_count=16)
    s.details['vls']=[(-79.,4,4,.88,.11)]
    # Four helicopter spots replace a generic fixed-wing runway presentation.
    remove(r,'Runway_Markings');m=Mesh()
    for z in (-70.,-29.,16.,65.):
        for x in (-7.,3.):m.box('markings',(x,D+.13,z),(.16,.025,8.))
        m.box('markings',(-2.,D+.13,z),(10.,.025,.16))
    r.add('Helicopter_Spot_Markings','Hull',(0,D,0),m)
    m=Mesh()
    for side in (-1,1):
        for z in (-35.55,-35.,-34.45):
            a=np.array([side*11.0,D-2.3,z]);b=a+[side*2.0,0,0]
            m.tube('paint',a,b,.22,8 if lod else 20);m.tube('metal_dark',b,b+[side*.03,0,0],.18,8 if lod else 20)
    r.add('Torpedo_Tube_Closures','Hull',(0,D-2.3,-35.),m)
    s.representative='Hyuga helicopter destroyer, not Kaga F35B conversion or a CATOBAR carrier. Operator197x33m,draft7m/depth22m; local island, sensors and underwater contours estimated from official photographs.16-cell closed exterior arrangement is approximate; catalogue confirms VLS but does not publish cell count. No operational airwing availability implied.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('helicopter__','navalHelicopter__','heavyLift__','gunboat__','carrier__')) and callable(f)}
def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for part in r.parts:
            if part['mesh'] is not None:part['mesh'].remove_duplicates()
        return r,s
    if slug.startswith(('helicopter__','navalHelicopter__','heavyLift__')):
        helis.BUILDERS[slug]=checked;e=helis.save(slug)
    else:saver.BUILDERS[slug]=checked;e=saver.save(slug)
    e['notes']+=' Original evidence-led generator generate_inventory_additions_15.py; public exterior estimates and dated national service findings remain distinct.'
    return e
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
