"""Original public Israeli exteriors; fielded types and ordered platforms.

No imported meshes/pixels/insignia, Blender, operating systems or weapon
internals. Manufacturer family sizes and national photo estimates are separate.
Empty photographed mounts do not acquire imagined guns or muzzle markers.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,profile_hull,loft,lathe_x,rotation,write_glb,merge_mesh
from armour_parts import ArmourSpec,wreck as ground_wreck
from aircraft_parts import AircraftSpec,airfoil,curved_shell,burnt_wreck as plane_wreck
from helicopter_parts import HelicopterSpec,burnt_wreck as heli_wreck
from ship_parts import ShipSpec,wreck as ship_wreck
import generate_p5_helicopters as helis
from generate_p7_ships import sub
from generate_p1_tanks import beam
from generate_inventory_additions_12 import base,hatch,remove
from generate_inventory_additions_32 import dense_tyre,side_plate
import generate_inventory_additions as common

PERA='https://www.idf.il/220860/'
BEERI='https://www.idf.il/175005/'
FIREFLY='https://www.rafael.co.il/wp-content/uploads/2024/03/spike-firefly_compressed.pdf'
SH60='https://www.dvidshub.net/image/545255/sh-60f-sea-hawk-helicopter'
DAKAR='https://www.navalnews.com/naval-news/2022/01/israel-orders-3-new-dakar-class-submarines-from-tkms/'
LIMIT='Original selected public exterior. Local small fittings/hinges and unverified national kit dimensions are estimates, not factory or fleet readiness certification. Source dates, variants and future orders are separated in research/evidence.json.'


def fender(m,x,y,z,r,lod):
    """Segmented real open wheel arch, not a solid cuboid through a tyre."""
    count=5 if lod else 12;extent=1.28
    for a in np.linspace(-extent,extent,count):
        m.box('paint',(x,y+r*math.cos(a),z+r*math.sin(a)),(.27,.045,2*r*math.sin(extent/(count-1))+.012),rotation((1,0,0),a))


def chassis(h,s,lod):
    for side in (-1,1):h.box('metal_dark',(side*.53,.62,0),(.17,.19,s.length-.24))
    for z in s.axle_z:
        h.tube('metal_dark',(-s.width*.35,s.wheel_radius,z),(s.width*.35,s.wheel_radius,z),.07,6 if lod else 12)
        for side in (-1,1):
            fender(h,side*(s.width/2-.15),s.wheel_radius,z,s.wheel_radius+.105,lod)
            beam(h,'metal_dark',(side*.34,.80,z-.24),(side*(s.width/2-.33),s.wheel_radius,z),.065)


def bushmaster__jltv_pera(lod=0):
    r,s,h=base('bushmaster__jltv_pera','JLTV Pera selected Israeli trial exterior',6.20,2.50,2.57,2,.56,lod,axles=[-1.65,1.65],source=PERA,
        features=['four wheels/two axles, large open arches and high clearance','faceted four-door JLTV protected cab and low raked two-pane windscreen','short rounded-shoulder bonnet with recessed paired round lamps','small open rear load frame, mirror guards and steps','selected2024unarmed exterior, no catalogue RWS invented'],representative=LIMIT)
    s.family='israeli_jltv_pera';s.details.update(selected_fit='operator2024trial vehicle photographs;2025fielding and2026type presence independently documented',local_photo_estimated_size=True,weapon_mount_absent_in_selected_photo=True)
    chassis(h,s,lod)
    # Narrower Vlower hull leaves the external wheel/suspension space open.
    profile_hull(h,'paint',[(1.52,.77,.69),(1.52,1.83,1.10),(1.04,2.57,1.00),(-1.37,2.57,1.00),(-1.48,.77,.69)])
    cross=[(-.94,1.08),(.94,1.08),(1.19,1.62),(1.19,1.82),(1.08,1.99),(-1.08,1.99),(-1.19,1.82),(-1.19,1.62)]
    loft(h,'paint',[[(x*k,y-dy,z) for x,y in cross] for z,k,dy in ((1.43,1,0),(2.72,1,0),(3.01,.93,.10))])
    h.box('metal_dark',(0,1.53,3.038),(1.10,.67,.025))
    if not lod:
        for y in np.linspace(1.24,1.81,12):h.box('paint',(0,y,3.057),(1.02,.014,.014))
    for side in (-1,1):
        for y,z in ((1.72,3.033),(1.49,3.04)):
            h.tube('metal_dark',(side*.93,y,z),(side*.93,y,z+.035),.105,8 if lod else 20)
            h.tube('glass',(side*.93,y,z+.037),(side*.93,y,z+.05),.074,8 if lod else 20)
        h.box('paint',(side*1.15,1.10,3.05),(.23,.28,.23));h.box('markings',(side*1.275,1.12,3.05),(.015,.13,.11))
        h.box('metal_dark',(side*1.17,.67,-.04),(.30,.075,2.18))
        for i,(a,b) in enumerate(((.02,1.42),(-1.34,-.02))):
            d=Mesh();x=side*1.108
            side_plate(d,x,[(.87,a),(.87,b),(1.80,b),(2.49,min(b,1.03)),(2.49,a)])
            if i==0:wyz=[(1.92,a+.12),(1.92,b-.13),(2.36,.98),(2.36,a+.12)]
            else:wyz=[(1.94,a+.16),(1.94,b-.14),(2.32,b-.14),(2.32,a+.16)]
            d.face('glass',[(x+side*.022,y,z) for y,z in wyz],(side,0,0))
            d.box('metal_dark',(x+side*.04,1.56,(a+b)/2),(.045,.055,.50))
            for y in (1.03,2.12):d.box('paint',(x+side*.05,y,a+.07),(.08,.12,.14))
            if not lod:
                for z in np.linspace(a+.10,b-.10,6):d.tube('metal_dark',(x+side*.028,1.83,z),(x+side*.048,1.83,z),.016,6)
            r.add(f'Door_{"L" if side<0 else "R"}{i}','Hull',(x,1.60,a+.07),d,'Y')
        # Guarded mirrors sit on the door/front pillar, not on thin bonnet tips.
        h.box('metal_dark',(side*1.37,2.25,1.03),(.15,.36,.13))
        for y in (2.04,2.48):beam(h,'paint',(side*1.11,y,.84),(side*1.48,y,.84),.03)
        beam(h,'paint',(side*1.48,2.04,.84),(side*1.48,2.48,.84),.03)
        h.box('paint',(side*.93,1.20,-2.23),(.22,.35,1.34))
        h.box('markings',(side*1.112,1.45,-.67),(.014,.22,.36))
        for z in (-2.87,-1.49):h.box('paint',(side*1.03,1.91,z),(.15,1.08,.15))
        h.box('paint',(side*1.03,2.44,-2.18),(.15,.15,1.50))
    h.box('paint',(0,1.12,-2.18),(2.10,.15,1.50));h.box('paint',(0,2.44,-2.83),(2.10,.15,.15))
    h.box('paint',(0,1.70,-2.86),(1.77,.84,.12));h.box('metal_dark',(.58,1.73,-2.14),(.37,.88,.42))
    for x in (-.51,.51):h.face('glass',[(x-.43,1.98,1.444),(x+.43,1.98,1.444),(x+.43,2.45,1.142),(x-.43,2.45,1.142)],(0,.56,.83))
    hatch(h,0,2.58,-.19,.73,.77,lod)
    # External test/tow guard seen on this particular trial carrier, uncoloured.
    beam(h,'metal_dark',(-.98,.96,3.15),(.98,.96,3.15),.12)
    for side in (-1,1):beam(h,'metal_dark',(side*.55,.96,3.15),(side*1.15,.73,3.29),.10)
    return r,s


def reconVehicle__flyer72_beeri(lod=0):
    r,s,h=base('reconVehicle__flyer72_beeri','Flyer72 Beeri selected protected empty-station exterior',4.94,2.12,2.13,2,.47,lod,axles=[-1.60,1.60],source=BEERI,
        features=['four wheels on maker3.20m wheelbase, no tracks','protected four-door Flyer72 body, broad single raked windshield','distinct low angular bonnet/front rack/winch guard and rear equipment box','real traversing roof gunner protection kit photographed empty, no invented gun','side/rear hinges and forward-opening windscreen frame'],representative=LIMIT)
    s.family='israeli_flyer72_beeri';s.details.update(selected_fit='IDFJanuary2024photographed armoured enclosure and empty roof shields;2026operator type presence',related_maker_family_wheelbase_m=3.20,related_maker_bare_length_m=4.94,national_enclosure_and_overall_estimated=True,empty_gunner_station=True)
    chassis(h,s,lod)
    profile_hull(h,'paint',[(1.40,.72,.77),(1.40,1.48,.92),(.98,2.13,.91),(-2.38,2.13,.91),(-2.48,.78,.77)])
    profile_hull(h,'paint',[(2.43,1.01,.64),(2.43,1.45,.96),(1.43,1.59,.94),(1.31,.87,.73)])
    h.box('paint',(0,1.58,1.95),(1.72,.06,1.27));h.box('metal_dark',(0,1.29,2.45),(1.25,.29,.035))
    for side in (-1,1):beam(h,'paint',(0,1.13,2.475),(side*.61,1.435,2.475),.050)
    for side in (-1,1):
        for y,z in ((1.20,2.46),(1.43,2.32)):
            rad=.11 if y<1.3 else .065
            h.tube('metal_dark',(side*.82,y,z),(side*.82,y,z+.03),rad,8 if lod else 18)
            h.tube('glass',(side*.82,y,z+.032),(side*.82,y,z+.045),rad*.77,8 if lod else 18)
        h.box('paint',(side*1.02,.75,-.07),(.19,.10,2.16))
        for i,(a,b) in enumerate(((-.10,1.26),(-1.34,-.14))):
            d=Mesh();x=side*.948
            side_plate(d,x,[(.80,a),(.80,b),(1.50,b),(2.08,min(b,.97)),(2.08,a)])
            d.face('glass',[(x+side*.02,1.64,a+.12),(x+side*.02,1.64,min(b-.10,1.13)),(x+side*.02,2.00,min(b-.10,.90)),(x+side*.02,2.00,a+.12)],(side,0,0))
            d.box('paint',(x+side*.027,1.24,(a+b)/2),(.045,.07,b-a-.15))
            for y in (.94,1.54):d.box('paint',(x+side*.043,y,b-.10),(.07,.13,.13))
            d.box('metal_dark',(x+side*.04,1.34,a+.17),(.045,.18,.04))
            r.add(f'Door_{"L" if side<0 else "R"}{i}','Hull',(x,1.42,b-.10),d,'Y')
        h.box('paint',(side*.87,1.61,-1.97),(.13,.97,.82))
        h.box('metal_dark',(side*1.07,1.91,1.11),(.13,.23,.10))
        beam(h,'paint',(side*.94,1.83,1.15),(side*1.10,1.83,1.15),.03)
        h.box('markings',(side*.958,1.40,-1.94),(.013,.22,.35))
    w=Mesh();w.face('glass',[(-.83,1.56,1.356),(.83,1.56,1.356),(.83,2.06,1.033),(-.83,2.06,1.033)],(0,.54,.84))
    for x in (-.84,.84):beam(w,'paint',(x,1.52,1.38),(x,2.11,1.0),.055)
    beam(w,'paint',(-.84,2.11,1.0),(.84,2.11,1.0),.055);beam(w,'paint',(-.84,1.52,1.38),(.84,1.52,1.38),.055)
    r.add('Windscreen','Hull',(0,2.11,1.0),w,'X',selected_hinge_estimated=True)
    p=np.array([0,2.15,-.30]);g=Mesh();g.tube('metal_dark',p,p+[0,.08,0],.48,8 if lod else 32)
    # Three separate plates form a real Uopening, without concave fan caps.
    for x in (-.31,.31):g.box('paint',(x,2.65,.11),(.39,.70,.045))
    g.box('paint',(0,2.36,.11),(1.01,.13,.045));g.box('paint',(0,2.48,-.77),(1.13,.36,.055))
    for side in (-1,1):g.box('paint',(side*.52,2.38,-.30),(.05,.26,.78))
    for side in (-1,1):g.face('markings',[(side*.548,2.30,-.49),(side*.548,2.30,-.11),(side*.548,2.46,-.11),(side*.548,2.46,-.49)],(side,0,0))
    r.add('Gunner_Ring','Hull',p,g,'Y',fit='photographed empty protected ring; no gun/trunnion/muzzle inferred')
    h.box('metal_dark',(0,.94,2.56),(.59,.21,.21))
    beam(h,'paint',(-.96,1.01,2.64),(.96,1.01,2.64),.065)
    for side in (-1,1):beam(h,'paint',(side*.96,1.01,2.64),(side*.71,.78,2.54),.065)
    return r,s


def loiterer__firefly_maoz(lod=0):
    s=AircraftSpec('loiterer__firefly_maoz','SPIKE Firefly Maoz selected public exterior','firefly_coaxial',.08,.40,.40,.08,.19,.055,0,FIREFLY,seats=0,
        representative='RafaelJune2025brochure publishes80x80x400mm round envelope; deployed rotor span, feet/mast/optic fittings locally estimated from public images, not fabrication drawings. IDFtype/order/current presence documented separately. Closed inert external representation only, no payload internals, powertrain, controls or operational behaviour.',
        features=['tiny square upright closed casing with lower forward optical aperture','two coaxial two-blade rotors on separated Yhubs, no tail rotor','exposed upper mast envelope and four slim landing legs','no fixed wings, wheels, invented gun, copied pixels or markings'],
        details={'multirotor':True,'unmanned':True,'landing_none':True,'gun':False,'muzzle_count':0,'muzzle_positions':{},'propellers':[],
                 'published_round_envelope_m':[.08,.08,.40],'deployed_rotor_span_estimated_m':.40,'electric_drive_internals_not_modelled':True,'coaxial_rotors':2})
    r=Rig(lod);h=Mesh();loft(h,'paint',[[(-.033,y,-.04),(.033,y,-.04),(.04,y,-.033),(.04,y,.033),(.033,y,.04),(-.033,y,.04),(-.04,y,.033),(-.04,y,-.033)] for y in (.055,.245)])
    h.box('metal_dark',(0,.102,.042),(.059,.063,.007));h.tube('paint',(0,.10,.046),(0,.10,.052),.019,8 if lod else 24)
    h.tube('glass',(0,.10,.0525),(0,.10,.055),.012,8 if lod else 24)
    h.box('glass',(-.017,.216,.042),(.012,.011,.004))
    for side in (-1,1):h.box('markings',(side*.041,.178,-.011),(.002,.020,.027))
    if not lod:
        for side in (-1,1):
            for y in (.075,.132,.219):h.tube('metal_dark',(side*.0402,y,-.023),(side*.042,y,-.023),.0022,6)
    r.add('Fuselage',r.root,(0,0,0),h)
    m=Mesh();m.tube('metal_dark',(0,.245,0),(0,.399,0),.0045,8 if lod else 16)
    for x in (-.012,.012):
        m.tube('paint',(x,.278,0),(x,.381,0),.003,6 if lod else 10)
        m.box('metal_dark',(x,.327,0),(.012,.045,.025))
    r.add('Mast','Fuselage',(0,.245,0),m)
    for i,(y,phase) in enumerate(((.393,0),(.258,math.pi/2))):
        p=np.array([0,y,0]);m=Mesh();radius=.20
        for angle in (phase,phase+math.pi):
            b=Mesh();airfoil(b,[(.025,0,.009,-.009),(.068,0,.014,-.014),(.166,0,.010,-.010),(.20,0,.006,-.006)],lod,span_steps=1 if lod else 4)
            merge_mesh(m,b,R=rotation((0,1,0),angle),t=p)
        m.tube('metal_dark',p-[0,.003,0],p+[0,.003,0],.010,8 if lod else 20)
        r.add('Rotor_Main_'+str(i),'Fuselage',p,m,'Y',blade_count=2,diameter_metres=.40,cosmetic_spin_sign=1 if i==0 else -1)
    m=Mesh()
    for x,z in ((-.115,-.09),(.115,-.09),(-.115,.09),(.115,.09)):
        m.tube('metal_dark',(math.copysign(.033,x),.108,math.copysign(.025,z)),(x,.004,z),.0028,5 if lod else 8)
        m.box('rubber',(x,.002,z),(.010,.004,.010))
    r.add('Skid','Fuselage',(0,.055,0),m,fit='four small landing feet, not helicopter runners')
    return r,s


def seahawk_glazing(r,s,lod):
    """Short opaque Seahawk nose and framed divided cockpit, not a glass dome."""
    part=next(p for p in r.parts if p['name']=='Fuselage');m=Mesh();L=s.length;W=s.width;H=s.body_height
    for role,g in part['mesh'].groups.items():
        if not g[3]:continue
        points,normals,uv=(np.asarray(g[i]) for i in range(3))
        for f in np.asarray(g[3]).reshape(-1,3):
            q=points[f];c=q.mean(0);material='paint' if role=='glass' and (c[2]>L*.400 or abs(c[0])<.075) else role
            m.face(material,q,np.cross(q[1]-q[0],q[2]-q[0]),normals=normals[f],uv=uv[f])
    part['mesh']=m;f=Mesh();profile=np.array(s.details['profile']);cy=s.belly+H/2;power=s.details['cross_section_power']
    def pt(z,t):
        dz=np.interp(z,profile[:,0],profile[:,1])*H;rx=np.interp(z,profile[:,0],profile[:,2])*W;ry=np.interp(z,profile[:,0],profile[:,3])*H
        return np.array([math.copysign((abs(math.sin(t))**power)*(rx+.020),math.sin(t)),cy+dz+(ry+.020)*math.cos(t)**power,z*L])
    def line(points):
        for a,b in zip(points,points[1:]):f.tube('paint',a,b,.022,4 if lod else 6)
    for t in (0,-1.05,1.05):line([pt(z,t) for z in np.linspace(.30,.40,3 if lod else 7)])
    for z in (.30,.40):line([pt(z,t) for t in np.linspace(-1.05,1.05,5 if lod else 13)])
    r.add('Cockpit_Window_Frames','Fuselage',(0,cy,L*.35),f)


def navalHelicopter__sh_60f_israel(lod=0):
    r,s=helis.model('navalHelicopter__sh_60f_israel','SH60F Israeli refurbishment order, selected public base airframe',lod,'blackhawk',naval=True,length=15.26,
        details={'naval_radar':False,'naval_store':'none','tail_gear_z':-.08,'tail_gear_anchor_y':1.45,'main_blade_chord':.53})
    s.source=SH60;s.features=['classic SeahawkF base airframe, four main/four canted tail blades','forward main wheel struts and forward-positioned twin tail tyres, not transport UH60 tail layout','unarmed public NavyF exterior, no B/Rnose radar or torpedo stores assumed','right-side rescue hoist and estimated closed underside cover']
    s.representative='Confirmed2022USgovernment contract for refurbishment/return-to-flight of three IsraeliSH60F, distinct from2016approval of eight airframes/equipment and from actual delivery/FOC. Selected2012USNavy photographer baseF exterior, not a certified final Israeli sensor/weapon installation. Related BlackHawk/Seahawk family rotor/hull sizes adopted; local fitting/gear positions estimated. No painted serials/insignia, armed stores or claimed current operational readiness.'
    s.details.update(seahawk_variant='F',selected_public_base_fit_before_national_integration=True,inventory_status='confirmed_refurbishment_contract_delivery_acceptance_unverified',tail_wheel_count=2,gear_positions_estimated=True)
    seahawk_glazing(r,s,lod)
    for p in r.parts:
        if p['name'] in ('Gear_Left','Gear_Right','Wheel_Left','Wheel_Right'):
            delta=np.array([0,0,s.length*(.23-.12)]);p['pivot']+=delta;r.pivots[p['name']]=p['pivot'].copy()
            if p['mesh'] is not None:p['mesh'].shift(delta)
    old=next(p for p in r.parts if p['name']=='Wheel_Tail');q=old['pivot'].copy();remove(r,'Wheel_Tail');rr=.27*.65;half=rr*.33
    for side,label in ((-1,'L'),(1,'R')):
        p=q+[side*.105,0,0];m=Mesh();lathe_x(m,[(-half,0,'metal_dark'),(-half,rr*.68,'rubber'),(-half*.65,rr,'rubber'),(half*.65,rr,'rubber'),(half,rr*.68,'metal_dark'),(half,0,'metal_dark')],segments=8 if lod else 20)
        m.shift(p);r.add('Wheel_Tail_'+label,'Gear_Tail',p,m,'X',radius_metres=rr)
    m=Mesh();m.box('paint',(0,.65,-.12),(.72,.07,.76));r.add('Closed_Underside_Panel','Fuselage',(0,.65,-.12),m)
    return r,s


def submarine__dakar_class(lod=0):
    r,s=sub('submarine__dakar_class','Dakar class contracted future official public concept',lod,80.,7.5,6.6,DAKAR,
        ['selected official2022TKMS concept, not current Drakon or generic212CD','broad rounded/faceted outer hull with long closed dorsal casing','long sail aft of midships, swept aft shoulder and rounded upright leading edge','four cruciform stern controls and one decorative screw','stowed mast geometry and unlabelled visible foredeck cover; no invented concealed weapons'],
        sail_z=-.095,sail_height=4.8,sail_length=24.,x_tail=False,foreplanes='none',prop_blades=7)
    B=s.beam;L=s.length;cy=B/2;m=Mesh()
    profile=[(-.45,.055),(-.38,.25),(-.25,.45),(-.10,.5),(.16,.5),(.32,.47),(.43,.34),(.48,.16),(.5,.006)]
    curved_shell(m,'paint',[(z*L,cy,B*rad,B*rad) for z,rad in profile],lod,circumference=12 if lod else 40,longitudinal=1 if lod else 7,cross_power=.84)
    next(p for p in r.parts if p['name']=='Hull')['mesh']=m
    # Explicitly oriented station faces preserve the concave upper casing and
    # swept sail shoulder; a convex-solid cap heuristic would flip those faces.
    def station_shell(name,stations,pivot):
        m=Mesh();rows=[]
        for z,w,low,top in stations:
            c=min(.18,w*.25,(top-low)*.10)
            rows.append([[-w+c,low,z],[w-c,low,z],[w,low+c,z],[w,top-c,z],[w-c,top,z],[-w+c,top,z],[-w,top-c,z],[-w,low+c,z]])
        m.face('paint',rows[0],(0,0,-1));m.face('paint',rows[-1],(0,0,1))
        for a,b in zip(rows,rows[1:]):
            for i,outward in enumerate(([0,-1,0],[1,-1,0],[1,0,0],[1,1,0],[0,1,0],[-1,1,0],[-1,0,0],[-1,-1,0])):
                j=(i+1)%8;f=np.array([a[i],a[j],b[j],b[i]]);n=np.cross(f[1]-f[0],f[2]-f[0])
                if np.dot(n,outward)<0:n=-n
                m.face('paint',f,n)
        found=next((p for p in r.parts if p['name']==name),None)
        if found is None:r.add(name,'Hull',pivot,m)
        else:found['mesh']=m
    station_shell('Sail',[(-21.0,.10,B*.91,B*.96),(-18.0,1.55,B*.91,B*.91+4.43),(-16.,1.70,B*.91,B*.91+4.8),(2.0,1.70,B*.91,B*.91+4.8),(4.3,1.24,B*.91,B*.91+4.63),(4.5,.12,B*.91,B*.91+4.30)],(0,B*.92,-7.6))
    station_shell('Upper_Casing',[(-L*.38,.30,B*.58,B*.72),(-L*.25,1.70,B*.82,B*1.015),(L*.10,1.80,B*.82,B*1.015),(L*.34,1.50,B*.79,B*.99),(L*.43,.25,B*.65,B*.84)],(0,B*.94,0))
    m=Mesh();profile_hull(m,'paint',[(20.6,B*1.005,.66),(20.4,B*1.13,.60),(17.9,B*1.15,.58),(17.8,B*1.005,.66)])
    r.add('Foredeck_Cover','Hull',(0,B*1.005,19.2),m,underlying_function_unverified=True)
    # No mast/radar geometry is visible in this closed concept. Remove the
    # generic deployed assemblies instead of inventing hardware to animate.
    remove(r,'Mast_0','Periscope_0','Periscope_1','Periscope_2','Periscope_3','Sail_Fittings')
    s.details['masts']=[]
    m=Mesh()
    for side in (-1,1):m.face('markings',[(side*1.703,9.2,-8.5),(side*1.703,9.2,-6.7),(side*1.703,9.8,-6.7),(side*1.703,9.8,-8.5)],(side,0,0))
    r.add('Sail_Markings','Sail',(0,9.5,-7.6),m,fit='blank game mark panels, no copied insignia')
    s.details.update(inventory_status='three_confirmed_future_class_in_construction_selected2022_official_concept',local_adopted_size_m=[80.,7.5],all_principal_sizes_and_propulsor_estimated=True,concealed_cells_or_weapons_not_asserted=True,stowed_masts_not_reconstructed=True,foredeck_cover_function_unverified=True)
    s.representative='Original interpretation of the explicitly TKMScredited January2022official concept, cross-checked in two public mirrors. Three futureDakar under construction separately confirmed2026, not deliveredDrakon or an operational current submarine. Adopted80x7.5m/draft/sail/casing/control dimensions and seven decorative screw blades are local estimates, not primary factory data or authentic hydrodynamics. Concept rendering may differ final production. No speculative VLS, hidden weapon capacities, nuclear payloads or propulsion internals modelled. Foredeck raised cover function unknown; closed/stowed masts not reconstructed.'
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('bushmaster__','reconVehicle__','loiterer__','navalHelicopter__','submarine__')) and callable(f)}


def save(slug):
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    ground=isinstance(s,ArmourSpec);naval=isinstance(s,ShipSpec);helicopter=isinstance(s,HelicopterSpec)
    if ground:
        for p in a.parts:
            if p['name'].startswith(('Wheel_L','Wheel_R')):
                m=dense_tyre(s.wheel_radius,s.width,-1 if p['name'].startswith('Wheel_L') else 1);m.shift(p['pivot']);p['mesh']=m
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
    central='Hull' if ground or naval else 'Fuselage'
    pts=np.concatenate([np.array(g[0]) for r in (a,b) for p in r.parts if p['name']==central for g in p['mesh'].groups.values() if g[0]])
    low,high=pts.min(0),pts.max(0);low[1]=0;c=Mesh();c.box('metal_dark',(low+high)/2,high-low)
    path=common.ART/('vehicles' if ground else 'ships' if naval else 'aircraft')/(slug+'.glb')
    w=ground_wreck(b,s) if ground else ship_wreck(b) if naval else heli_wreck(b,s) if helicopter else plane_wreck(b,s)
    write_glb(path,[a,b],w,c,{'scene_name':s.name,'vehicle':slug,'priority':'P2' if ground else 'P7' if naval else 'P5' if helicopter else 'P6','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    if ground:from validate_framed_ground import validate
    elif naval:from validate_naval_inventory31 import validate
    else:from validate_aircraft import validate
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']='Original generate_inventory_additions_33.py with shared approved Python parts; no imported geometry/pixels, Blender, insignia, functional weapon internals or operating logic. Metres,+Zfront,ground origin, role-named white PBR, metre UVs, LOD0/LOD1, hidden static Wreck/Collision_Box. Selected public exteriors, family published dimensions and local national-fit estimates distinguished in research/evidence.json.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
