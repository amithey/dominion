"""Original selected public Israeli production/delivery exteriors, no Blender.

Static battery elements are not imaginary self-propelled trucks. Dimensions of
these external housings and small fittings are local photograph estimates.
No functional optics, electronics, operating logic, launch or weapon internals.
Historical exterior photographs do not certify every current national serial.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,profile_hull,loft,lathe_x,write_glb,rotation
from armour_parts import ArmourSpec,mobility,wreck
from generate_p1_tanks import beam
from generate_inventory_additions_12 import base,gun_station,hatch
import generate_inventory_additions as common

EITAN='https://mod.gov.il/en/press-releases/press-room/delivery-of-first-eitan-armored-personnel-carriers-apc-to-the-israel-defense-forces-nahal-infantry-brigade'
DOME='https://www.rafael.co.il/exhibitions/wp-content/uploads/2024/05/IRON-Dome_Brochure_new-2023b.pdf'
DAVID='https://www.timesofisrael.com/russia-reportedly-in-possession-of-advanced-israeli-interceptor-missile/'
BEAM='https://www.mod.gov.il/en/press-releases/press-room/israel-mod-and-rafael-deliver-first-operational-high-power-laser-system-iron-beam-to-the-idf'
MMR='https://www.iai.co.il/product/elm-2084-mmr/'
LIMIT='Original selected public outer fit, not all current national serials. All principal dimensions, small fittings and hinge placements locally estimated from photographs, not factory drawings. See dated national service/order evidence separately in research/evidence.json. No weapon or sensor internals reconstructed.'


def field_tyre(radius,side):
    m=Mesh();w=.18;r=radius
    lathe_x(m,[(-w,0,'paint'),(-w,r*.53,'rubber'),(-w*.84,r*.94,'rubber'),(-w*.58,r,'rubber'),(w*.58,r,'rubber'),(w*.84,r*.94,'rubber'),(w,r*.53,'paint'),(w,0,'paint')],segments=28)
    m.tube('paint',(side*(w+.004),0,0),(side*(w+.04),0,0),r*.46,16)
    for a in np.linspace(0,math.tau,8,endpoint=False):m.tube('metal_dark',(side*(w+.04),r*.31*math.cos(a),r*.31*math.sin(a)),(side*(w+.062),r*.31*math.cos(a),r*.31*math.sin(a)),.017,6)
    for row in (-1,1):
        for a in np.linspace(0,math.tau,24,endpoint=False):
            a+=row*.025;m.box('rubber',(row*w*.42,(r-.030)*math.cos(a),(r-.030)*math.sin(a)),(w*.68,.026,.105),rotation((1,0,0),a))
    return m


def static(slug,name,L,W,H,lod,source,features):
    s=ArmourSpec(slug,name,L,W,H,'static',0,0,'public_static_module','',list(features),source,approximate=True,representative=LIMIT,details={'tube_count':0,'all_dimensions_locally_estimated':True})
    r=Rig(lod);m=Mesh();r.add('Hull',r.root,(0,0,0),m,origin='ground centre of selected platform footprint')
    return r,s,m


def jacks(r,h,lod,L,W,height,*,z=None):
    for side,label in ((-1,'L'),(1,'R')):
        for i,zz in enumerate(z or [-L*.38,L*.38]):
            p=np.array([side*(W/2-.15),height,zz]);m=Mesh()
            beam(m,'paint',(side*W*.25,height,zz),p,.15)
            m.tube('paint',p,p+[0,-height+.15,0],.115,6 if lod else 16)
            m.tube('metal_dark',p+[0,-height+.15,0],p+[0,-height+.07,0],.075,6 if lod else 16)
            m.box('metal_dark',(p[0],.035,p[2]),(.42,.07,.46))
            if not lod:
                for y in np.linspace(.28,height-.12,4):m.tube('paint',(p[0],y,p[2]),(p[0],y+.025,p[2]),.123,12)
                beam(m,'metal_dark',p+[0,.09,0],p+[.18,.09,0],.025)
            r.add(f'Outrigger_{label}{i}','Hull',p,m,translation_axis='Y',mechanism='visible levelling leg, estimated extension')


def box_panels(m,center,size,lod,*,vent=False):
    x,y,z=center;w,h,d=size;m.box('paint',center,size)
    for side in (-1,1):
        xx=x+side*(w/2+.012)
        m.box('paint',(xx,y,z),(.025,h*.84,d*.84))
        beam(m,'metal_dark',(xx+side*.02,y-.10,z-.08),(xx+side*.02,y-.10,z+.08),.025)
        if not lod:
            for zz in (z-d*.38,z+d*.38):
                for yy in (y-h*.28,y+h*.28):m.box('metal_dark',(xx+side*.024,yy,zz),(.018,.07,.05))
            if vent:
                for zz in np.linspace(z-d*.32,z+d*.32,12):m.box('metal_dark',(xx+side*.024,y+h*.28,zz),(.018,.15,.018))


def apc__eitan_series_2023(lod=0):
    r,s,h=base('apc__eitan_series_2023','Eitan selected May2023 series-delivery APC',8.10,3.14,2.46,4,.64,lod,axles=[-2.78,-1.11,1.05,2.67],source=EITAN,weapon='rws',features=['eight large wheels/four axles and tall flat side armour','wide low wedge nose, split front shoulder facets and front-left engine grille','periscoped driver and commander hatches, actual remote MG station','rear centre ramp between separate tall side equipment cabinets','rear roof basket, mirror arms and external panel/handle details'],representative=LIMIT)
    s.family='israeli_eitan_series';s.details.update(selected_fit='May2023production delivery images, no fictional all-serial30mm turret or APS fit',future30mm_not_current_fit=True)
    # The broad low bow rises into a nearly flat roof, not a generic tall wedge.
    profile_hull(h,'paint',[(4.02,.91,1.11),(4.02,1.34,1.35),(2.27,2.46,1.36),(-3.66,2.46,1.36),(-4.02,1.14,1.25),(-3.82,.78,.94)])
    for side in (-1,1):
        for a,b in ((-3.84,-2.08),(-2.04,-.18),(-.14,1.71),(1.75,3.18)):
            cross=[(side*1.30,1.22),(side*1.57,1.22),(side*1.57,2.26),(side*1.40,2.49),(side*1.30,2.49)]
            # Convex closed cross section, extruded between the panel gaps;
            # no nonplanar concave side cap for the triangulator to guess.
            loft(h,'paint',[[(x,y,z) for x,y in cross] for z in (a,b)])
        h.box('markings',(side*1.582,1.88,-.52),(.012,.28,.48))
        h.box('metal_dark',(side*1.38,1.05,3.90),(.28,.17,.12));h.box('glass',(side*1.38,1.06,3.968),(.18,.10,.018))
        for z in s.axle_z:
            h.box('paint',(side*1.34,1.37,z),(.40,.09,1.27))
        box_panels(h,(side*1.06,1.91,-3.84),(.71,1.22,.36),lod)
        h.tube('paint',(side*1.35,2.35,-3.96),(side*1.35,2.35,-4.06),.105,8 if lod else 20)
        h.tube('glass',(side*1.35,2.35,-4.065),(side*1.35,2.35,-4.08),.076,8 if lod else 20)
        h.box('glass',(side*1.04,2.31,-4.045),(.31,.09,.03))
        beam(h,'metal_dark',(side*1.39,2.30,2.55),(side*1.75,2.69,2.51),.035)
        h.box('metal_dark',(side*1.75,2.75,2.51),(.16,.43,.13));h.box('glass',(side*1.75,2.76,2.435),(.12,.34,.02))
        if not lod:
            for zz in np.linspace(-3.55,2.25,18):h.box('paint',(side*1.38,2.49,zz),(.12,.04,.14))
            for y in (1.50,2.08):
                for z in (-2.7,-.6,1.7):beam(h,'metal_dark',(side*1.59,y,z-.09),(side*1.59,y,z+.09),.023)
    ramp=Mesh();profile_hull(ramp,'paint',[(-3.89,.91,.63),(-3.89,2.37,.63),(-4.01,2.37,.63),(-4.01,.91,.63)])
    ramp.box('paint',(0,1.66,-4.03),(.90,.85,.055));ramp.box('glass',(0,2.07,-4.067),(.24,.15,.025));r.add('Ramp','Hull',(0,.91,-3.96),ramp,'X')
    for i,(x,z) in enumerate(((.51,1.72),(.63,-.12))):
        p=np.array([x,2.50,z]);m=Mesh();m.tube('paint',p,p+[0,.07,0],.37,10 if lod else 28)
        m.box('metal_dark',p+[0,.09,0],(.18,.04,.055));r.add('Hatch_Driver' if i==0 else 'Hatch_Commander','Hull',p+[.34,0,0],m,'Z')
        for xx in (-.20,0,.20):h.box('paint',(x+xx,2.51,z+.40),(.16,.12,.12));h.box('glass',(x+xx,2.54,z+.468),(.12,.06,.018))
    for zz in np.linspace(1.55,2.78,5 if lod else 18):h.box('metal_dark',(-.66,2.48,zz),(.90,.025,.034))
    b=Mesh()
    for side in (-1,1):
        for z in (-3.44,-2.75):beam(b,'paint',(side*.75,2.46,z),(side*.75,2.94,z),.03)
        for y in (2.55,2.70,2.88):beam(b,'paint',(side*.75,y,-3.44),(side*.75,y,-2.75),.03)
    for y in (2.55,2.70,2.88):beam(b,'paint',(-.75,y,-3.44),(.75,y,-3.44),.03)
    r.add('Rear_Roof_Basket','Hull',(0,2.46,-3.10),b)
    gun_station(r,lod,-.57,2.49,-.18,remote=True)
    next(p for p in r.parts if p['name']=='Gun')['extras']['mechanism']='photographed remote machine gun transverse hinge; detailed receiver and calibre unverified'
    next(p for p in r.parts if p['name']=='Muzzle')['extras'].pop('caliber_metres',None)
    r.add('Engine_Deck','Hull',(-.64,2.50,2.15));r.add('Exhaust','Hull',(-1.48,2.26,.70))
    return r,s


def canister(m,c,w,d,lod,*,dome=False):
    x,y,z=c
    m.box('paint',c,(w,w,d))
    for zz in (z-d*.42,z,z+d*.42):
        m.box('paint',(x,y,zz),(w+.045,w+.045,.055))
    for zz,sign in ((z+d/2,1),(z-d/2,-1)):
        m.box('paint',(x,y,zz+sign*.025),(w+.035,w+.035,.05))
        if not lod:
            for dx in (-w*.33,w*.33):
                for dy in (-w*.33,w*.33):m.tube('metal_dark',(x+dx,y+dy,zz+sign*.053),(x+dx,y+dy,zz+sign*.062),.012,6)
    if not lod:
        m.box('metal_dark',(x+w/2+.008,y,z-d*.28),(.016,w*.22,.055))
        m.box('paint',(x+w/2+.018,y,z+d*.26),(.020,w*.28,d*.20))
    # A small blank side panel, not a copied warning/INERT label or insignia.
    m.box('markings',(x+w/2+.014,y,z+d*.12),(.012,w*.30,d*.12))


def rack(r,s,lod,cols,rows,w,depth,pivot,*,gaps=.07):
    p=np.array(pivot);m=Mesh();tips=[]
    for j in range(rows):
        for i in range(cols):
            c=p+[(i-(cols-1)/2)*(w+gaps),.18+w/2+j*(w+gaps),depth/2-.08]
            canister(m,c,w,depth,lod);tips.append((c+[0,0,depth/2+.062]).tolist())
    span=cols*(w+gaps)
    for z in (p[2]+.20,p[2]+depth*.55,p[2]+depth-.22):
        m.box('paint',(0,p[1]+.11,z),(span+.12,.14,.12))
        for side in (-1,1):beam(m,'paint',(side*span/2,p[1]+.08,z),(side*span/2,p[1]+rows*(w+gaps)+.25,z),.075)
    for side in (-1,1):beam(m,'paint',(side*span/2,p[1]+.06,p[2]+.12),(side*span/2,p[1]+.06,p[2]+depth-.10),.09)
    r.add('Launcher','Hull',p,m,'X',positive_elevation_rotation_sign=-1,mechanism='visible transverse erection hinge; no undocumented azimuth bearing')
    for i,q in enumerate(tips):r.add(f'Muzzle_{i}','Launcher',q,forward='+Z',aperture='closed canister external end')
    s.details.update(tube_count=len(tips),muzzle_positions=tips,radar=False,canisters_closed=True,azimuth_not_asserted=True)


def aaVehicle__iron_dome_mfu(lod=0):
    r,s,h=static('aaVehicle__iron_dome_mfu','Iron Dome selected public twenty-canister MFU',4.60,3.05,.72,lod,DOME,['separate static twenty-canister firing unit, not all-in-oneI-Dome truck','twenty individual long sealed containers, four across and five deep when upright','transverse erection hinge, exposed cross frame and four levelling legs','side exterior panels/retaining bands/end caps; separate radar not invented here'])
    h.box('paint',(0,.52,0),(2.54,.18,4.10))
    for side in (-1,1):h.box('metal_dark',(side*.83,.35,0),(.20,.24,4.20))
    h.box('markings',(1.284,.52,0),(.018,.13,.44));jacks(r,h,lod,4.6,3.05,.60)
    rack(r,s,lod,4,5,.34,3.12,(0,.76,-1.75),gaps=.055)
    for side in (-1,1):
        h.tube('paint',(side*.86,.58,-1.88),(side*.86,.76,-1.88),.15,6 if lod else 20)
        beam(h,'metal_dark',(side*.86,.65,-1.88),(side*.86,.70,-.35),.08)
    s.details['selected_fit']='maker February2023brochure MFU exterior; family current presence corroborated by procurement, not exact current serial'
    return r,s


def samLauncher__davids_sling_trailer(lod=0):
    r,s,h=base('samLauncher__davids_sling_trailer','David Sling selected public two-axle launcher trailer',9.80,2.60,1.48,2,.52,lod,axles=[-3.46,-2.20],source=DAVID,features=['unpowered two-axle semitrailer, no invented forward cab','twelve closed containers, three across/four deep when erect','large forward equipment shelter with exterior vents/doors and end safety rail','four visible levelling jacks, side steps and transverse erection hinge'],representative=LIMIT)
    s.family='israeli_david_trailer';s.front_engine=False
    h.box('paint',(0,1.22,0),(2.56,.23,9.60))
    for side in (-1,1):
        h.box('metal_dark',(side*.69,.98,0),(.18,.38,9.25));h.box('paint',(side*1.10,1.23,-2.82),(.38,.12,3.03))
        h.box('markings',(side*1.30,1.23,1.80),(.015,.17,.48))
    box_panels(h,(0,2.32,2.47),(2.44,2.0,3.28),lod,vent=True)
    for x in (-.72,.72):
        h.box('metal_dark',(x,3.12,4.122),(.54,.31,.025))
        if not lod:
            for xx in np.linspace(x-.23,x+.23,9):h.box('paint',(xx,3.12,4.141),(.018,.29,.014))
    for side in (-1,1):
        for z in (4.25,4.64):beam(h,'paint',(side*1.12,1.36,z),(side*1.12,2.02,z),.032)
        beam(h,'paint',(side*1.12,2.02,4.25),(side*1.12,2.02,4.64),.032)
    h.box('metal_dark',(0,.95,3.80),(.36,.36,.36))
    jacks(r,h,lod,9.8,2.6,1.20,z=[-4.15,3.96])
    rack(r,s,lod,3,4,.43,4.55,(0,1.53,-4.22),gaps=.065)
    step=Mesh()
    for i in range(4):step.box('paint',(1.46,.30+i*.22,-.87-i*.19),(.32,.09,.23))
    r.add('Access_Steps','Hull',(1.34,1.22,-1.44),step,'Y',local_small_fitting_estimate=True)
    s.details['selected_fit']='April2,2017AP/SebastianScheiner public display exterior, separate2025operator upgrade proof; not every new serial'
    return r,s


def counterBatteryRadar__elm_2084_mmr(lod=0):
    r,s,h=static('counterBatteryRadar__elm_2084_mmr','ELM2084 selected classic public static MMR module',4.70,2.70,1.19,lod,MMR,['separate deployable four-leg platform, no invented launcher or truck cab','large inclined single classic rectangular array on Y bearing','external antenna back braces, base housing, side equipment box and cooling grille','not automatically the2019multi-sensorMS-MMR or every national/export configuration'])
    h.box('paint',(0,1.05,0),(2.58,.23,4.45));jacks(r,h,lod,4.7,2.7,1.13)
    box_panels(h,(0,1.70,1.46),(2.30,1.08,1.10),lod,vent=True)
    h.tube('metal_dark',(0,1.16,-.55),(0,1.40,-.55),.66,10 if lod else 40)
    a=Mesh();box_panels(a,(0,1.65,-.55),(2.30,.43,1.20),lod)
    panel=Mesh();width=2.25;height=3.18;z=-.26;y=1.91
    # Tilted external slab. No RF elements, electronics or functional data.
    outer=[(-width/2,y,z),(-width/2,y+height,z-.51),(width/2,y+height,z-.51),(width/2,y,z)]
    front=np.array(outer);back=front-[0,0,.20];loft(panel,'paint',[front,back])
    for side in (-1,1):
        beam(panel,'metal_dark',(side*.94,1.77,-1.14),(side*.94,4.63,-.83),.08)
        if not lod:
            for yy in (2.48,4.44):panel.box('metal_dark',(side*1.24,yy,z-(yy-y)*.51/height),(.27,.035,.09))
        beam(panel,'paint',(side*(width/2-.055),y+.055,z+.018),(side*(width/2-.055),y+height-.055,z-.51+.018),.025)
    for yy in (y+.055,y+height-.055):
        zz=z-(yy-y)*.51/height;beam(panel,'paint',(-width/2+.055,yy,zz+.018),(width/2-.055,yy,zz+.018),.025)
    r.add('Radar','Hull',(0,1.34,-.55),a,'Y',mechanism='maker confirms rotating/sector modes; not fixed electronics')
    r.add('Radar_Elevation','Radar',(0,1.91,-.26),panel,'X',local_hinge_estimate=True)
    s.details.update(radar=True,selected_fit='classic maker front/back photographs inspected, national family corroborated separately; no claim photographed national serial',not_MS_MMR_payload=True)
    return r,s


def optical_head(r,lod,z,index,roof):
    n=10 if lod else 32;p=np.array([0,roof,z]);turn=Mesh()
    turn.tube('metal_dark',p,p+[0,.16,0],.49,n)
    for side in (-1,1):turn.box('paint',p+[side*.48,.47,0],(.14,.75,.46))
    a=Mesh();q=p+[0,.68,0];a.box('paint',q+[0,.17,-.09],(.88,1.20,.68))
    a.tube('paint',q+[0,0,.22],q+[0,0,.48],.43,n)
    a.tube('metal_dark',q+[0,0,.48],q+[0,0,.50],.385,n)
    a.tube('glass',q+[0,0,.503],q+[0,0,.515],.345,n)
    a.tube('paint',q+[-.28,.58,.28],q+[-.28,.58,.46],.16,n)
    a.tube('glass',q+[-.28,.58,.465],q+[-.28,.58,.48],.13,n)
    a.box('paint',q+[0,.82,-.08],(1.02,.19,.78))
    if not lod:
        for x in np.linspace(-.44,.44,10):a.box('metal_dark',q+[x,.37,-.446],(.025,.65,.025))
        for side in (-1,1):
            a.tube('metal_dark',q+[side*.44,0,0],q+[side*.53,0,0],.18,n)
            for zz in (-.22,.18):a.box('paint',q+[side*.51,.51,zz],(.07,.13,.10))
    turnname='Turntable' if index==0 else f'Turntable_{index}';headname='Launcher' if index==0 else f'Launcher_{index}'
    r.add(turnname,'Hull',p,turn,'Y',mechanism='independent optical azimuth bearing')
    r.add(headname,turnname,q,a,'X',mechanism='independent optical head transverse trunnion')
    r.add(f'Muzzle_{index}',headname,q+[0,0,.515],forward='+Z',marker_use='exterior optical aperture, no projectile or optical internals')


def laserAD__iron_beam_or_eitan(lod=0):
    r,s,h=static('laserAD__iron_beam_or_eitan','Iron Beam OrEitan selected2025twin-head container exterior',12.20,2.56,2.90,lod,BEAM,['long container with two separate photographed roof optical assemblies','each optical head independently traversesY/elevatesX, large lower and small upper apertures','external container doors/locking bars/corners and end levelling legs','not generic laser truck, no projector beams or functional laser electronics'])
    h.box('paint',(0,1.55,0),(2.44,2.58,11.95))
    for side in (-1,1):
        for z in np.linspace(-5.80,5.80,7 if lod else 14):h.box('paint',(side*1.25,1.55,z),(.10,2.68,.085))
        for y in (.22,2.85):h.box('paint',(side*1.25,y,0),(.10,.12,12.10))
        for z in (-4.00,-1.9,.20,2.30,4.40):
            h.box('paint',(side*1.232,1.48,z),(.025,2.23,1.50))
            beam(h,'metal_dark',(side*1.26,1.48-.28,z+.24),(side*1.26,1.48-.28,z+.42),.025)
            if not lod:
                for zz in (z-.58,z+.58):
                    beam(h,'paint',(side*1.28,.44,zz),(side*1.28,2.49,zz),.023)
                    for y in (.63,1.82,2.33):h.box('metal_dark',(side*1.29,y,zz),(.025,.065,.065))
        h.box('markings',(side*1.267,2.18,-.80),(.014,.24,.46))
    for z in (-6.015,6.015):
        h.box('paint',(0,1.55,z),(2.45,2.60,.07))
        if not lod:
            for x in np.linspace(-.95,.95,15):h.box('paint',(x,1.55,z+math.copysign(.05,z)),(.06,2.42,.025))
    jacks(r,h,lod,12.2,2.56,.55,z=[-5.84,5.84])
    for i,z in enumerate((-4.30,4.30)):optical_head(r,lod,z,i,2.91)
    s.details.update(emitter_heads=2,emitter_markers=['Muzzle_0','Muzzle_1'],tube_count=0,radar=False,selected_fit='September2025test and December28delivery public photographs, local container/optical/underside estimates; no assumed all-fleet serial fit')
    return r,s


BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('apc__','aaVehicle__','samLauncher__','counterBatteryRadar__','laserAD__')) and callable(f)}


def save(slug):
    from validate_p3_artillery import validate
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        if not lod and s.mobility=='wheeled':
            for p in r.parts:
                if p['name'].startswith(('Wheel_L','Wheel_R')):
                    m=field_tyre(s.wheel_radius,-1 if p['name'].startswith('Wheel_L') else 1);m.shift(p['pivot']);p['mesh']=m
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    a,s=checked(0);b,t=checked(1);assert asdict(s)==asdict(t)
    pts=np.concatenate([np.asarray(g[0]) for r in (a,b) for p in r.parts if p['name']=='Hull' for g in p['mesh'].groups.values() if g[0]])
    lo,hi=pts.min(0),pts.max(0);lo[1]=0;c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo)
    path=common.ART/'vehicles'/(slug+'.glb');write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P2' if slug.startswith('apc__') else 'P4','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']='Original generate_inventory_additions_34.py with approved shared Python parts, no Blender, imported mesh/pixels or insignia. Public outer geometry only, no functional weapon/sensor internals or operating logic. Local principal dimensions and fittings expressly estimated; selected historical/current exterior and national service/order evidence separated in research/evidence.json. Static equipment does not gain invented truck cabs or installed missiles/radars.'
    return e


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args();a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
