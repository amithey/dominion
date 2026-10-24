"""British Ajax support variants and two distinct naval classes.

Original geometry from public manufacturer/operator references, in metres.
Shared wheels, canonical tracks and naval machinery retain the pilot contract.
Closed stowage and unpublished local dimensions are estimates, not internals.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
import generate_inventory_additions as armour_saver
import generate_inventory_additions_05 as ship_saver
from generate_inventory_additions_08 import ajax_hull,discard
from generate_inventory_additions_09 import replace_mesh
from generate_p7_ships import combatant,sub
from armour_parts import weapon
from vehicle_parts import Mesh,profile_hull,loft,hollow_muzzle,rotation
from ship_parts import beam

GD='https://uk.gdls.com/ajax/'
RN='https://www.royalnavy.mod.uk/'

def hull_surface_projector(rig,axis):
    """Project detail caps onto the actual LOD hull, including its facets."""
    hull=next(p['mesh'] for p in rig.parts if p['name']=='Hull')
    g=hull.groups['paint'];tri=np.asarray(g[0])[np.asarray(g[3]).reshape(-1,3)]
    plane=[k for k in range(3) if k!=axis];a=tri[:,0,plane];b=tri[:,1,plane];c=tri[:,2,plane]
    v=b-a;w=c-a;den=v[:,0]*w[:,1]-v[:,1]*w[:,0]
    valid=np.abs(den)>1e-10;a=a[valid];v=v[valid];w=w[valid];den=den[valid];tri=tri[valid]
    def surface(u,vv,offset):
        q=np.array([u,vv])-a
        t=(q[:,0]*w[:,1]-q[:,1]*w[:,0])/den
        r=(v[:,0]*q[:,1]-v[:,1]*q[:,0])/den
        inside=(t>=-1e-7)&(r>=-1e-7)&(t+r<=1.0000001)
        assert inside.any(),('cap outside hull',u,vv)
        h=(tri[:,0,axis]+t*(tri[:,1,axis]-tri[:,0,axis])+r*(tri[:,2,axis]-tri[:,0,axis]))[inside].max()
        p=np.zeros(3);p[plane]=[u,vv];p[axis]=h+offset;return p
    return surface

def support_base(slug,name,lod,weapon_x=.48):
    rig,s=ajax_hull(slug,name,lod)
    discard(rig,['Spade','Boom','Boom_Lift','Winch_Deck'])
    s.source=GD;s.weapon='rws';s.turret_z=.65;s.turret_x=weapon_x
    # GD photographs show the RWS above Athena's raised command roof.
    # The low generic station needs its real supporting pedestal here.
    s.details['weapon_base']=2.55;weapon(rig,s,lod)
    m=Mesh();p=np.array([weapon_x,2.05,.65])
    m.tube('paint',p,p+[0,.50,0],.16,8 if lod else 16,r_top=.13)
    rig.add('Weapon_Station_Pedestal','Hull',p,m)
    s.features+=['public manufacturer photograph inspected for variant equipment',
                 'compact Protector-style representative RWS, not the Ajax CT40 turret']
    s.details['weapon_calibre']='12.7mm representative family RWS; interchangeable weapon fits vary'
    return rig,s

def roof_hatches(rig,lod,z=-1.4,length=1.6):
    m=Mesh()
    for side in (-1,1):
        p=np.array([side*.55,2.09,z]);m.box('paint',p,(.80,.08,length))
        if not lod:
            for zz in (z-length*.34,z+length*.34):
                beam(m,[side*.55-.18,2.17,zz],[side*.55+.18,2.17,zz],.018,lod)
    rig.add('Roof_Hatch_Pair','Hull',(0,2.09,z),m)

def whips(rig,lod,points):
    discard(rig,['Antenna_1'])
    for i,p in enumerate(points):
        p=np.array(p);m=Mesh();m.tube('paint',p,p+[0,.10,0],.055,6 if lod else 12)
        m.tube('metal_dark',p+[0,.10,0],p+[0,1.75+(i%2)*.22,0],.014,6 if lod else 8)
        rig.add('Antenna_'+str(i+1),'Hull',p,m)

def apc__athena(lod=0):
    rig,s=support_base('apc__athena','Athena command and control',lod)
    m=Mesh();profile_hull(m,'paint',[(-.45,2.04,1.02),(-.69,2.54,.98),(-3.40,2.54,.98),(-3.50,2.04,1.02)])
    m.box('paint',(0,2.58,-2.05),(1.56,.08,1.67))
    for side in (-1,1):
        m.box('paint',(side*1.025,2.33,-1.95),(.06,.30,1.82))
        if not lod:
            for z in (-2.66,-1.96,-1.26):m.tube('metal_dark',(side*1.06,2.22,z),(side*1.08,2.22,z),.018,6)
    rig.add('Raised_Command_Compartment','Hull',(0,2.05,-1.95),m)
    whips(rig,lod,[[-.84,2.54,-1.10],[.84,2.54,-2.85],[-.84,2.54,-2.85]])
    s.features+=['higher rear command compartment','closed command roof hatch and communications whips',
                 'command vehicle, not a dedicated jammer or IFV']
    s.representative='112 Athena contracted within the589 Ajax family. Public GD command-variant exterior; local cabin sections and antenna lengths estimated from manufacturer photograph. Programme acceptance/trials status is not proof that all112 are operational.'
    return rig,s

def reconVehicle__argus(lod=0):
    rig,s=support_base('reconVehicle__argus','Argus engineer reconnaissance',lod)
    roof_hatches(rig,lod,z=-1.55,length=1.62)
    m=Mesh()
    for x,z in ((-.92,-2.72),(.92,-2.72),(-.95,-.48)):
        m.box('paint',(x,2.14,z),(.18,.18,.20));m.box('metal_dark',(x,2.24,z),(.12,.025,.14))
    m.box('paint',(0,2.16,-2.89),(.65,.20,.39))
    rig.add('Survey_And_Detection_Fittings','Hull',(0,2.05,-1.9),m)
    whips(rig,lod,[[-.93,2.05,-2.12],[.93,2.05,-2.82],[-.62,2.05,-2.83]])
    s.features+=['low reconnaissance troop roof with paired hatches','three communications whips',
                 'closed survey stowage and small detection heads','no invented excavator, plough or raised surveillance tower']
    s.representative='51 Argus contracted; public GD engineering-reconnaissance exterior with its low Ares-derived roof and stowed fittings. Internal survey electronics are not rendered. Small head/stowage dimensions estimated; no assertion of fleet-wide operational acceptance.'
    return rig,s

def recoveryVehicle__atlas(lod=0):
    rig,s=support_base('recoveryVehicle__atlas','Atlas winch recovery',lod)
    s.details['recovery_parts']=['Spade'];roof_hatches(rig,lod,z=-1.36,length=1.43)
    whips(rig,lod,[[-.93,2.05,-2.70],[.95,2.05,-2.72]])
    m=Mesh()
    for side in (-1,1):
        # Long external recovery stores and low stowed towing bar.
        m.box('paint',(side*1.45,1.90,-1.62),(.25,.34,2.90))
        m.tube('metal_dark',(side*1.61,1.62,-2.87),(side*1.61,1.62,-.62),.065,6 if lod else 12)
    rig.add('Recovery_Tool_Stores','Hull',(0,1.90,-1.62),m)
    p=np.array([0,.76,3.46]);m=Mesh()
    for side in (-1,1):
        a=np.array([side*.79,.91,3.12]);b=np.array([side*1.10,.59,4.10])
        beam(m,a,b,.11,lod,'paint');beam(m,a+[0,.33,0],b+[0,.25,0],.054,lod)
    profile_hull(m,'paint',[(4.28,.16,1.29),(4.41,.27,1.29),(4.17,.92,1.29),(3.99,.93,1.29)])
    m.box('metal_dark',(0,.19,4.31),(2.74,.12,.13))
    rig.add('Spade','Hull',p,m,'X',purpose='front winch anchoring blade; no recovery crane on Atlas')
    p=np.array([0,1.20,3.48]);m=Mesh()
    m.box('paint',p,(1.04,.42,.25))
    for side in (-1,1):
        m.tube('metal_dark',p+[side*.29,-.10,.14],p+[side*.29,.10,.14],.10,6 if lod else 12)
        m.tube('metal_dark',p+[side*.29,0,.13],p+[side*.29,0,.31],.025,6 if lod else 8)
    rig.add('Winch_Fairleads','Hull',p,m)
    p=np.array([0,1.30,2.89]);m=Mesh();m.tube('metal_dark',p-[.37,0,0],p+[.37,0,0],.24,8 if lod else 20)
    rig.add('Recovery_Winch','Hull',p,m,'X')
    s.features+=['front anchoring Spade with two hydraulic arms','paired forward winch fairleads',
                 'long external tool stores and towing bar','winch-recovery vehicle without an invented crane']
    s.representative='38 Atlas contracted. GD recovery photograph directly inspected: front anchoring blade, paired fairleads and external stores. No Boom exists because this variant uses a winch, not the Apollo crane. Public stowed exterior; winch capacity and hidden machinery not modelled as engineering data.'
    return rig,s

def recoveryVehicle__apollo(lod=0):
    rig,s=support_base('recoveryVehicle__apollo','Apollo repair vehicle',lod,weapon_x=-.48)
    s.details['recovery_parts']=['Boom'];whips(rig,lod,[[-.94,2.05,-2.82],[-.93,2.05,-.97]])
    m=Mesh();m.box('paint',(-.41,2.17,-1.80),(1.27,.24,2.53))
    for side in (-1,1):
        m.box('paint',(side*1.45,1.89,-1.55),(.27,.35,3.10))
        m.tube('metal_dark',(side*1.61,1.61,-2.82),(side*1.61,1.61,-.45),.06,6 if lod else 12)
    # Folded workshop access ladder on the exterior flank, as photographed.
    for z in (-.67,-1.16):beam(m,[1.68,.78,z],[1.68,1.92,z],.027,lod)
    for y in np.linspace(.86,1.82,3 if lod else 5):beam(m,[1.68,y,-.67],[1.68,y,-1.16],.022,lod)
    rig.add('Repair_Deck_And_Stores','Hull',(0,2.05,-1.80),m)
    p=np.array([.83,2.08,-2.38]);m=Mesh();m.tube('paint',p,p+[0,.25,0],.34,8 if lod else 20)
    rig.add('Boom','Hull',p,m,'Y',purpose='repair-crane slew bearing, not an Atlas recovery A-frame')
    a=p+[0,.27,0];b=np.array([.83,2.72,1.23]);m=Mesh()
    beam(m,a,b,.17,lod,'paint');beam(m,a+[.22,-.10,.07],b+[.22,-.18,-.64],.06,lod)
    rig.add('Boom_Lift','Boom',a,m,'X',purpose='luffing trunnion; low transport pose')
    m=Mesh();beam(m,b-[0,0,.80],b+[0,.04,.62],.115,lod,'metal_dark')
    rig.add('Boom_Extension','Boom_Lift',b-[0,0,.80],m,travel_axis='Z')
    q=b+[0,.04,.62];m=Mesh();m.tube('metal_dark',q,q-[0,.41,0],.014,6 if lod else 8)
    m.tube('metal_dark',q-[0,.41,0],q-[0,.49,.06],.038,6 if lod else 10)
    rig.add('Crane_Hook','Boom_Extension',q,m)
    m=Mesh();m.box('paint',(.83,2.14,.95),(.44,.18,.32))
    rig.add('Crane_Transport_Rest','Hull',(.83,2.05,.95),m)
    s.features+=['low stowed telescoping repair crane','Boom slew Y and Boom_Lift trunnion X',
                 'rear workshop service deck and flank access ladder','no fictional front recovery blade']
    s.representative='50 Apollo repair variants contracted. GD photograph shows crane lifting a powerpack, unlike winch-only Atlas. Crane is exported lowered along the right deck in a transport pose; local reach/stowage lengths estimated. No front Spade is present in the reference exterior.'
    return rig,s

def nuclearSub__dreadnought_class(lod=0):
    rig,s=sub('nuclearSub__dreadnought_class','Dreadnought-class contracted design',lod,153.6,12.8,12.,
        RN+'equipment/submarine/dreadnought-class',
        ['153.6m British future SSBN','twelve Trident launch closures in three four-tube groups',
         'smooth full-diameter missile body, not Vanguard tall casing','distinctive raked sail',
         'bow diving planes','X-form stern controls ahead of ducted pumpjet','four bow torpedo closures'],
        sail_z=.23,sail_length=20.,sail_height=7.8,x_tail=True,foreplanes='bow',pumpjet=True,
        body_profile=[(-.45,.07),(-.38,.29),(-.25,.46),(-.12,.50),(.21,.50),(.34,.48),(.44,.34),(.49,.16),(.5,.006)])
    m=Mesh();profile_hull(m,'paint',[(46.,11.75,1.75),(41.,19.576,1.26),(27.,19.576,1.26),(25.,11.75,1.75)])
    replace_mesh(rig,'Sail',m)
    # Give the duct finite depth and rotor-tip clearance; the shared thin
    # ring is inadequate for this large representative pumpjet exterior.
    p=next(part['pivot'] for part in rig.parts if part['name']=='Propeller')
    radius=s.beam*.31;m=Mesh();segments=12 if lod else 32
    def duct_point(r,z,t):return p+np.array([r*math.cos(t),r*math.sin(t),z])
    for j in range(segments):
        a=j*math.tau/segments;b=(j+1)*math.tau/segments
        for r,sign in ((radius*1.10,1),(radius*1.025,-1)):
            m.face('metal_dark',[duct_point(r,-2.7648,a),duct_point(r,-2.7648,b),duct_point(r,1.1,b),duct_point(r,1.1,a)],
                   sign*np.array([math.cos((a+b)/2),math.sin((a+b)/2),0]))
        for z,sign in ((-2.7648,-1),(1.1,1)):
            m.face('metal_dark',[duct_point(radius*1.025,z,a),duct_point(radius*1.10,z,a),duct_point(radius*1.10,z,b),duct_point(radius*1.025,z,b)],[0,0,sign])
    replace_mesh(rig,'Pumpjet_Shroud',m)
    m=Mesh();n=8 if lod else 24;R=s.beam/2
    surface=hull_surface_projector(rig,1)
    # Closures follow the circular hull: horizontal floating disks would
    # recreate a false missile hump. Caps are closed, not firing tubes.
    for row in range(6):
        zz=20.0-row*4.5-(row//2)*.35
        for side in (-1,1):
            cx=side*2.15;rad=1.13;bottom=[];top=[]
            for t in np.linspace(0,math.tau,n,endpoint=False):
                x=cx+rad*math.cos(t);z=zz+rad*math.sin(t)
                bottom.append(surface(x,z,.012));top.append(surface(x,z,.055))
            for j in range(n):
                k=(j+1)%n
                m.face('paint',[surface(cx,zz,.055),top[j],top[k]],[0,1,0])
                m.face('metal_dark',[surface(cx,zz,.012),bottom[k],bottom[j]],[0,-1,0])
                rim=(top[j]+top[k])/2-surface(cx,zz,.055);rim[1]=0
                m.face('metal_dark',[bottom[j],bottom[k],top[k],top[j]],rim)
    rig.add('Missile_Deck_Hatches','Hull',(0,12.8,20.),m,cell_count=12,quad_packs=3)
    m=Mesh()
    bow_surface=hull_surface_projector(rig,2)
    for side in (-1,1):
        for y in (5.65,6.55):
            cx=side*1.1;points=[(cx+.269*math.cos(t),y+.269*math.sin(t)) for t in np.linspace(0,math.tau,n,endpoint=False)]
            low=[bow_surface(x,yy,.008) for x,yy in points];high=[bow_surface(x,yy,.05) for x,yy in points]
            for j in range(n):
                k=(j+1)%n
                m.face('metal_dark',[bow_surface(cx,y,.05),high[j],high[k]],[0,0,1])
                m.face('metal_dark',[bow_surface(cx,y,.008),low[k],low[j]],[0,0,-1])
                rim=(high[j]+high[k])/2-bow_surface(cx,y,.05);rim[2]=0
                m.face('metal_dark',[low[j],low[k],high[k],high[j]],rim)
    rig.add('Bow_Torpedo_Closures','Hull',(0,6.1,75.7),m,tube_count=4)
    s.details['inventory_status']='four_firm_order_under_construction_not_in_service'
    s.details['missile_cells']=12
    s.representative='Four firm boats, all in production by September2025; first entry planned early2030s, reaffirmed2026. Operator confirms153.6m,12launch tubes,4torpedo tubes,X-rudders and pumpjet. Beam12.8m,draft12m,sail sections,shaft/rotor internals and local closure placement are exterior estimates, not published engineering measurements. Public future-design representative, not an operational Vanguard.'
    return rig,s

def gunboat__river_batch_1(lod=0):
    rig,s=combatant('gunboat__river_batch_1','River Batch 1 (Tyne/Mersey/Severn)',lod,(79.5,13.5,3.8,3.6),
        RN+'news/2026/july/13/20260713-ride-on-tyne-patrol-ship-thanks-those-behind-her-successful-patrols',
        ['original approximately80m River Batch1 hull','single manual20mm bow mounting, not Batch2 remote30mm',
         'high forward bridge with open wings','central lattice mast','aft working deck and cargo crane',
         'two amidships boarding RHIBs','no helicopter landing deck or hangar'],
        houses=[(0,9.8,10.5,24.0,7.8,0,.90),(0,12.2,12.0,10.0,2.1,7.8,.97)],
        funnels=[(-3.5,-3.6,2.4,3.6,8.8,0),(3.5,-3.6,2.4,3.6,8.8,0)],
        masts=[(4.8,23.0,'bar',3.1)],guns=[],vls=[],canisters=[],ciws=[],
        hangar=False,flight_deck=False,bow_sheer=.60,
        cranes=[(0,-14.0,3.2,10.0)],boats=[(-4.8,-7.6),(4.8,-7.6)])
    D=s.draft+s.freeboard;m=Mesh();p=np.array([0,D,29.0])
    m.tube('paint',p,p+[0,.65,0],.32,8 if lod else 20)
    m.box('paint',p+[0,.83,.25],(1.25,1.22,.09))
    rig.add('Turret_Main','Hull',p,m,'Y',purpose='manual20mm mounting, not enclosed naval turret')
    q=p+[0,.91,.06];m=Mesh();m.box('metal_dark',q,(.20,.27,.61))
    hollow_muzzle(m,q+[0,0,.27],q+[0,0,1.67],.045,.010,6 if lod else 16)
    rig.add('Gun','Turret_Main',q,m,'X');rig.add('Muzzle','Gun',q+[0,0,1.67])
    # Airy lattice mast, with cross braces rather than an oversized frigate tower.
    m=Mesh()
    for x in (-.8,.8):
        beam(m,[x,D+7.7,4.8],[x*.35,D+22.3,4.8],.10,lod,'paint')
        beam(m,[x,D+7.7,5.35],[x*.35,D+22.3,5.05],.10,lod,'paint')
    for yy in (D+13.,D+17.,D+21.):
        beam(m,[-1.0,yy,4.8],[1.,yy,4.8],.06,lod)
        beam(m,[-.8,yy-2.,4.8],[.8,yy,4.8],.045,lod)
        beam(m,[-.8,yy,4.8],[-.8,yy,5.35],.045,lod)
        beam(m,[.8,yy,4.8],[.8,yy,5.35],.045,lod)
    for yy,w in ((D+16.0,3.4),(D+21.0,2.7)):
        beam(m,[-w,yy,4.8],[w,yy,4.8],.07,lod)
    beam(m,[-.28,D+22.3,4.8],[.28,D+22.3,4.8],.06,lod)
    beam(m,[0,D+21.0,4.8],[0,D+23.1,4.8],.08,lod,'paint')
    replace_mesh(rig,'Mast_0',m)
    s.details['inventory_status']='in_service_2026_retirement_planned_2028'
    s.details['manual_main_gun']=True
    s.representative='Three Batch1 ships explicitly operating in July/August2026; planned2028 class retirement is not current withdrawal or sale. Published operator length rounded80m;79.5m length,13.5m beam,draft and local geometry estimated.20mm armament confirmed by operator. No Batch2 helicopter pad or30mm remote gun borrowed.'
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('apc__','reconVehicle__','recoveryVehicle__','nuclearSub__','gunboat__')) and callable(f)}

def save(slug):
    if slug.startswith(('nuclearSub__','gunboat__')):
        ship_saver.BUILDERS[slug]=BUILDERS[slug];e=ship_saver.save(slug)
        e['notes']=e['notes'].replace('generate_inventory_additions_05.py','generate_inventory_additions_11.py')
        if slug=='gunboat__river_batch_1':e['has_turret']=True
    else:
        armour_saver.BUILDERS[slug]=BUILDERS[slug];e=armour_saver.save(slug)
        if slug.startswith('recoveryVehicle__'):
            e['recovery_parts']=['Spade'] if slug.endswith('__atlas') else ['Boom']
            e['notes']=e['notes'].replace('recovery vehicles expose Boom and Spade','recovery vehicles expose only their documented Boom or Spade')
    e['notes']+=' Original generator generate_inventory_additions_11.py; public reference and national status evidence in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
