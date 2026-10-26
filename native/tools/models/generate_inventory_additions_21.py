"""Five distinct Korean surface-combatant exteriors, generated without Blender.

Primary manufacturer/operator photographs and public principal dimensions.
Local surfaces, draft/freeboard, sensor supports and concealed equipment positions
are estimated. Closed launch-cell lids do not assert a live missile load.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from generate_p7_ships import combatant
import generate_inventory_additions_05 as saver
from generate_inventory_additions_16 import lattice
from vehicle_parts import Mesh,loft,hollow_muzzle,write_glb
from ship_parts import beam,block,wreck
from generate_p1_tanks import beam as square_beam

DEMA='https://kookbang.dema.mil.kr/newsWeb/'
DAPA='https://www.dapa.go.kr/dapa/doc/selectDoc.do?bbsSeq=326&menuSeq=3069&docSeq='
HHI='https://naval-special.hhi.co.kr/Uploads/Brochure/Attachment/2026031294530_hhi_naval_ship_division.pdf'

def exterior_refinement(r,s,lod):
    D=s.draft+s.freeboard
    # A real tapering reinforcement sleeve around the exposed gun tube.
    for i,g in enumerate(s.details['guns']):
        name='Gun' if i==0 else 'Gun_'+str(i);p=next(v for v in r.parts if v['name']==name);q=p['pivot'];m=Mesh()
        m.tube('metal_dark',q+[0,0,.12],q+[0,0,1.45],.25,6 if lod else 16,.15)
        hollow_muzzle(m,q+[0,0,.25],q+[0,0,g[3]],.12,g[2]/2000,8 if lod else 16);p['mesh']=m
    # Reallocate rail tessellation to more stanchions and visible ship details.
    if not lod:
        p=next(v for v in r.parts if v['name']=='Deck_Fittings');m=Mesh();m.groups['markings']=p['mesh'].groups['markings']
        outline=np.array(s.details.get('hull_profile',[(-.5,.65),(-.45,.80),(-.3,.96),(-.1,1),(.12,1),(.30,.86),(.41,.55),(.48,.18),(.5,.008)]))
        for side in (-1,1):
            points=[]
            for z in np.linspace(-.28,.465,42):
                x=side*(s.beam/2*np.interp(z,outline[:,0],outline[:,1])-.10);y=D+max(0,(z-.22)/.28)*s.details.get('bow_sheer',1.7)
                q=np.array([x,y,z*s.length]);points.append(q);square_beam(m,'metal_dark',q,q+[0,1.05,0],.05)
            for a,b in zip(points,points[1:]):
                for y,width in ((1.05,.045),(.5,.038)):square_beam(m,'metal_dark',a+[0,y,0],b+[0,y,0],width)
            for z in (-s.length*.44,s.length*.40):
                y=D+max(0,(z/s.length-.22)/.28)*s.details.get('bow_sheer',1.7)
                for dz in (-.35,.35):m.tube('metal_dark',(side*s.beam*.25,y,z+dz),(side*s.beam*.25,y+.5,z+dz),.18,12)
            a=np.array([side*s.beam*.40,D*.7,s.length*.34]);b=np.array([side*s.beam*.40,D*.4,s.length*.34])
            square_beam(m,'metal_dark',a,b,.20)
            x=side*s.beam*.5*np.interp(.34,outline[:,0],outline[:,1]);square_beam(m,'metal_dark',a,[x,D+.75,s.length*.34],.05)
        p['mesh']=m
    # Louvre strips sit on the actual tapered funnel skin.
    for i,(x,z,w,length,h,base) in enumerate(s.details['funnels']):
        m=Mesh();block(m,'paint',x,D+base,z,w,h,length,.76)
        m.box('metal_dark',(x,D+base+h+.035,z),(w*.71,.08,length*.71))
        if not lod:
            for side in (-1,1):
                for yy in np.linspace(.3*h,.62*h,5):
                    xx=x+side*(w/2*(1-.24*yy/h)+.015)
                    m.box('metal_dark',(xx,D+base+yy,z),(.03,.14,length*.50))
        next(v for v in r.parts if v['name']=='Funnel_'+str(i))['mesh']=m
    # Cooling grilles on the aft house, with lower-detail panels in LOD1.
    house=min(s.details['houses'],key=lambda h:h[1]-h[3]/2);x,z,w,length,h,base,taper=house;m=Mesh()
    for side in (-1,1):
        for row in range(1 if lod else 3):
            yy=h*.55+(row-(0 if lod else 1))*.68;xx=x+side*(w/2*(1-(1-taper)*yy/h)+.02)
            for col in range(1 if lod else 4):
                zz=z+(col-(0 if lod else 1.5))*1.30
                m.box('metal_dark',(xx,D+base+yy,zz),(.04,1.80 if lod else .43,5.05 if lod else .97))
    r.add('Aft_Ventilation_Grilles','Hull',(x,D+base+h*.55,z),m)

def cyclic_ciws(r,s,lod):
    """Actual six/seven exterior barrels, on an independent local Z rotor."""
    for i,style in enumerate(s.details.get('ciws_styles',[])):
        if style not in ('phalanx','goalkeeper'):continue
        n=7 if style=='goalkeeper' else 6;radius=.115 if n==7 else .080
        p=next(x for x in r.parts if x['name']=='CIWS_Gun_'+str(i));q=p['pivot'];m=Mesh()
        m.box('metal_dark',q+[0,0,.13],(.32,.30,.36));p['mesh']=m
        m=Mesh();tips=[]
        for a in np.linspace(0,math.tau,n,endpoint=False):
            delta=np.array([radius*math.cos(a),radius*math.sin(a),0]);tip=q+delta+[0,0,1.5]
            hollow_muzzle(m,q+delta+[0,0,.21],tip,.027 if n==7 else .020,.015 if n==7 else .011,3 if lod else 8);tips.append(tip)
        rotor='CIWS_Rotor_'+str(i);r.add(rotor,p['name'],q,m,'Z',barrel_count=n)
        for j,tip in enumerate(tips):r.add('CIWS_Port_'+str(i)+'_'+str(j),rotor,tip,purpose='exterior barrel muzzle')
    s.details['ciws_barrel_counts']=[7 if v=='goalkeeper' else 6 if v=='phalanx' else 0 for v in s.details.get('ciws_styles',[])]

def ram_face(r,s,lod):
    """Symmetric twenty-one closed front covers; no live missiles modelled."""
    for i,style in enumerate(s.details.get('ciws_styles',[])):
        if style!='ram':continue
        p=next(x for x in r.parts if x['name']=='CIWS_Launcher_'+str(i));q=p['pivot'];m=Mesh()
        m.box('paint',q,(2.3,2.2,2.0));ports=[]
        for row in range(5):
            for col in range(5):
                if row in (0,4) and col in (0,4):continue
                tip=q+[(col-2)*.42,(row-2)*.42,1.04]
                if not lod:m.tube('metal_dark',tip-[0,0,.05],tip+[0,0,.035],.16,8)
                ports.append(tip)
        p['mesh']=m
        for j,tip in enumerate(ports):
            name='RAM_Muzzle_'+str(i)+'_'+str(j);part=next(v for v in r.parts if v['name']==name)
            part['pivot']=tip;r.pivots[name]=tip
    s.details['ram_cover_layout']='21 closed exterior covers; local arrangement estimated'

def fittings(r,s,lod,*,torpedo_z=-7):
    D=s.draft+s.freeboard;m=Mesh()
    for side in (-1,1):
        m.box('paint',(side*(s.beam*.31+.45),D+.45,torpedo_z),(1.3,.9,1.75))
        for dz in (-.45,0,.45):
            a=np.array([side*s.beam*.31,D+1.1,torpedo_z+dz]);b=a+[side*1.10,0,0]
            m.tube('paint',a,b,.20,4 if lod else 10)
        for z in (() if lod else (s.length*.13,-s.length*.17)):
            for j in range(4):
                a=np.array([side*s.beam*.36,D+1.25,z+j*.23]);b=a+[side*.27,.36,.10]
                m.tube('metal_dark',a,b,.05,4 if lod else 6)
            m.box('paint',(side*s.beam*.36,D+.60,z+.3),(.53,1.20,1.15))
        for i in range(2 if lod else 5):
            z=-s.length*.035+i*1.4;x=side*s.beam*.40
            for dz in ((0,) if lod else (-.22,.22)):beam(m,[x,D,z+dz],[x,D+.68,z+dz],.045,lod,'paint')
    r.add('Torpedo_And_Decoy_Fittings','Hull',(0,D,torpedo_z),m)

def supported_canisters(r,s,lod):
    D=s.draft+s.freeboard
    for i,(z,base,count) in enumerate(s.details.get('canisters',[])):
        p=next(v for v in r.parts if v['name']=='AntiShip_Canisters_'+str(i));y=D+base
        m=Mesh() if lod else p['mesh']
        roof=max((v[4]+v[5] for v in s.details['houses'] if abs(z-v[1])<v[3]/2),default=0)
        if abs(roof-base)>.05:m.box('paint',(0,D+base/2,z),(8.,max(.08,base),count*.75+.55))
        for side in (-1,1):
            if lod:
                for j in range(count):
                    a=np.array([side*.3,y+1,z+(j-(count-1)/2)*.75]);beam(m,a,a+[side*4,1.5,0],.33,lod,'paint')
                points=[(side*.30,y),(side*4.40,y),(side*4.40,y+2.40),(side*.30,y+.85)]
                v=[(x,yy,z+zz) for zz in (-count*.375,count*.375) for x,yy in points]
                m.solid('paint',v,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
            else:
                for x,top in ((side*1.6,y+1.5),(side*3.2,y+2.1)):
                    for dz in (-count*.34,count*.34):beam(m,[x,y,z+dz],[x,top,z+dz],.095,lod,'paint')
                    beam(m,[x,top,z-count*.37],[x,top,z+count*.37],.11,lod,'paint')
        p['mesh']=m

def mounted_hangar_doors(r,s,lod):
    # The aft wall tapers; flat constant-Z doors would hover behind it.
    house=min(s.details['houses'],key=lambda h:h[1]-h[3]/2)
    x,z,w,length,h,base,taper=house;D=s.draft+s.freeboard;m=Mesh();doors=s.details.get('hangar_doors',1)
    def back(y):return z-length/2*(1-(1-taper)*(y-D-base)/h)-.025
    y0=D+base+.15;y1=D+base+min(4.5,h-.15)
    for i in range(doors):
        xx=x+(i-(doors-1)/2)*s.beam*.30;half=s.beam*.122
        v=[(xx+dx,yy,back(yy)+off) for off in (0,.03) for dx,yy in ((-half,y0),(half,y0),(half,y1),(-half,y1))]
        m.solid('metal_dark',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        if not lod:
            for yy in np.linspace(y0+.18,y1-.18,9):m.box('paint',(xx,yy,back(yy)-.025),(half*1.96,.045,.04))
    p=next(v for v in r.parts if v['name']=='Hangar_Doors');p['mesh']=m

def fore_vls_foundations(r,s,lod):
    D=s.draft+s.freeboard
    for i,(z,cols,rows,pitch,base) in enumerate(list(s.details.get('vls',[]))):
        if z<=0:continue
        halfz=(rows*pitch+.16)/2;halfx=(cols*pitch+.16)/2
        def deck(zz):return D+max(0,(zz/s.length-.22)/.28)*s.details.get('bow_sheer',1.7)
        top=max(D+base,deck(z+halfz)+.025);delta=top-(D+base)
        p=next(v for v in r.parts if v['name']=='VLS_'+str(i));p['mesh'].shift([0,delta,0]);p['pivot'][1]+=delta;r.pivots[p['name']]=p['pivot']
        s.details['vls'][i]=[z,cols,rows,pitch,top-D]
        m=Mesh();v=[]
        for level in (0,1):
            for x,zz in ((-halfx,z-halfz),(halfx,z-halfz),(halfx,z+halfz),(-halfx,z+halfz)):
                v.append([x,top+.004 if level else deck(zz)-.025,zz])
        m.solid('paint',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        r.add('VLS_Foundation_'+str(i),'Hull',(0,D,z),m)

def radomes(r,s,lod,index=0):
    D=s.draft+s.freeboard;x,z,w,length,h,base,taper=s.details['houses'][index];m=Mesh();y=D+base+h
    for side in (-1,1):
        xx=x+side*w*.29;zz=z+length*.20
        m.tube('paint',(xx,y-.08,zz),(xx,y+.24,zz),.30,6 if lod else 16)
        loft(m,'paint',[[[xx+rr*math.cos(a),yy,zz+rr*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 20,endpoint=False)]
            for yy,rr in ((y+.20,.26),(y+.38,.49),(y+.85,.48),(y+1.09,.13))])
    r.add('Deck_Radomes','Hull',(x,y,z),m)

def upper_bridge_windows(r,s,lod,index=1):
    D=s.draft+s.freeboard;x,z,w,length,h,base,taper=s.details['houses'][index];m=Mesh();yy=D+base+h*.72
    front=z+length*(1-(1-taper)*.72)/2+.018
    for xx in np.linspace(-w*.32,w*.32,4 if lod else 8):m.box('glass',(x+xx,yy,front),(w*.075,.60,.035))
    p=next(v for v in r.parts if v['name']=='Bridge_Windows');p['mesh']=m;p['pivot']=np.array([x,yy,z]);r.pivots[p['name']]=p['pivot']

def search_array(r,s,lod,index=0,width=6.0,height=1.8):
    p=next(v for v in r.parts if v['name']==('Radar' if index==0 else 'Radar_'+str(index)));q=p['pivot'];m=Mesh()
    m.tube('paint',q-[0,.18,0],q+[0,.25,0],.35,6 if lod else 16)
    # Rounded rectangular reflector, with its own support; not a SPY face.
    ring=[]
    for a in np.linspace(0,math.tau,8 if lod else 24,endpoint=False):
        ring.append([q[0]+width*.5*math.cos(a),q[1]+height*.55+height*.5*math.sin(a),q[2]])
    loft(m,'metal_dark',[[[x,y,z-.08] for x,y,z in ring],[[x,y,z+.08] for x,y,z in ring]])
    if not lod:
        for x in np.linspace(-width*.40,width*.40,9):beam(m,[q[0]+x,q[1]+.23,q[2]-.12],[q[0]+x,q[1]+height*.91,q[2]-.12],.025,lod,'paint')
    p['mesh']=m

def oto_compact_mount(r,s,lod):
    p=next(x for x in r.parts if x['name']=='Turret_Main');q=p['pivot'];m=Mesh()
    m.tube('paint',q-[0,.16,0],q+[0,.18,0],1.72,8 if lod else 24)
    rings=[]
    for y,rx,rz in ((.18,1.86,1.74),(1.60,1.48,1.50),(2.14,1.13,1.16)):
        rings.append([[q[0]+rx*math.cos(a),q[1]+y,q[2]+rz*math.sin(a)] for a in np.linspace(0,math.tau,8 if lod else 24,endpoint=False)])
    loft(m,'paint',rings);p['mesh']=m

def fixed_spy_faces(r,s,lod):
    """Four fixed octagonal panels on a chamfered, supported bridge body."""
    D=s.draft+s.freeboard;m=Mesh();z=16.;w=16.6;l=39.;h=9.6;taper=.84;c=4.8
    footprint=[(-w/2+c,l/2),(w/2-c,l/2),(w/2,l/2-c),(w/2,-l/2+c),
        (w/2-c,-l/2),(-w/2+c,-l/2),(-w/2,-l/2+c),(-w/2,l/2-c)]
    loft(m,'paint',[[[x*k,D+y,z+zz*k] for x,zz in footprint] for y,k in ((0,1),(h,taper))])
    for side in (-1,1):
        for front in (-1,1):
            centre=np.array([side*(w/2-c/2),0,front*(l/2-c/2)])
            normal=np.array([side,0,front],dtype=float)/math.sqrt(2);t=np.array([front,0,-side],dtype=float)/math.sqrt(2)
            corners=[];half=1.72;cut=.45
            for xx,yy in [(-half,-half+cut),(-half+cut,-half),(half-cut,-half),(half,-half+cut),(half,half-cut),(half-cut,half),(-half+cut,half),(-half,half-cut)]:
                y=5.6+yy;k=1-(1-taper)*y/h;q=centre*k+t*xx+normal*.028;q[1]=D+y;q[2]+=z;corners.append(q)
            m.face('metal_dark',corners,[normal[0],.12,normal[2]])
    p=next(v for v in r.parts if v['name']=='Bridge');p['mesh']=m
    glazing=Mesh()
    for a,b,normal in ((footprint[0],footprint[1],[0,.12,1]),(footprint[1],footprint[2],[1,.12,1]),(footprint[7],footprint[0],[-1,.12,1])):
        for i in range(3 if not lod else 2):
            count=3 if not lod else 2;t0=(i+.10)/count;t1=(i+.90)/count;pts=[]
            for t,y in ((t0,7.2),(t1,7.2),(t1,7.8),(t0,7.8)):
                q=np.asarray(a)*(1-t)+np.asarray(b)*t;k=1-(1-taper)*y/h
                n=np.array([normal[0],normal[2]])/np.linalg.norm([normal[0],normal[2]])
                q=q*k+n*.025;pts.append([q[0],D+y,z+q[1]])
            glazing.face('glass',pts,normal)
    p=next(v for v in r.parts if v['name']=='Bridge_Windows');p['mesh']=glazing
    s.details['fixed_sensor_faces']=4

def integrated_sensor_mast(r,s,lod):
    D=s.draft+s.freeboard;z=9.;m=Mesh()
    block(m,'paint',0,D+9.8,z,3.3,9.0,3.4,.86)
    base=D+18.3;h=7.5;w=7.1;depth=6.3;taper=.66
    block(m,'paint',0,base,z,w,h,depth,taper)
    for side in (-1,1):
        for direction in ('x','z'):
            pts=[];half=1.35;cut=.35
            for a,b in [(-half,-half+cut),(-half+cut,-half),(half-cut,-half),(half,-half+cut),(half,half-cut),(half-cut,half),(-half+cut,half),(-half,half-cut)]:
                y=h*.50+b;scale=1-(1-taper)*y/h
                pts.append([side*(w*.5*scale+.025),base+y,z+a] if direction=='x' else [a,base+y,z+side*(depth*.5*scale+.025)])
            m.face('metal_dark',pts,[side,.2,0] if direction=='x' else [0,.2,side])
    # The navigation shaft is fixed too; only its small top radar turns.
    m.tube('paint',(0,D+25.6,z),(0,D+28.5,z),.14,6 if lod else 16)
    for y in (D+12.1,D+15.0):beam(m,[-2.4,y,z],[2.4,y,z],.08,lod,'paint')
    p=next(v for v in r.parts if v['name']=='Mast_0');p['mesh']=m
    s.details['fixed_sensor_faces']=4;s.details['ciws_ii']='planned, not represented as fitted'

def destroyer__gwanggaeto_the_great_class(lod=0):
    r,s=combatant('destroyer__gwanggaeto_the_great_class','Gwanggaeto the Great class',lod,(135.4,14.2,4.3,4.7),
        'https://www.guri.go.kr/www/contents.do?key=478',
        ['early KDXI narrow hull,135.4m','rounded OTO127mmL54compact mount, not Mk45','two masts and broad rotating search reflector',
         'sixteen closed SeaSparrow cells forward','eight closed SSM canisters','two seven-barrel Goalkeeper mounts','twin helicopter hangar doors'],
        houses=[(0,17.,10.8,27.,7.0,0,.91),(0,-28.,11.8,34.,5.3,0,.95)],
        funnels=[(0,-1.4,3.6,6.3,6.2,2.0),(0,-18.,3.4,5.4,5.8,2.0)],
        masts=[(17.,25.,'bar',6.0),(-20.,17.,'bar',2.1)],guns=[(0,48.,127,6.0)],vls=[(34.0,4,4,.66,0)],
        canisters=[(-8.,1.4,4)],ciws=[(0,27.,7.0),(0,-36.,5.3)],ciws_styles=['goalkeeper','goalkeeper'],
        hangar_z=-45.1,hangar_doors=2,rail_count=26)
    lattice(r,s,lod,0,17.,25.,1.25);search_array(r,s,lod);oto_compact_mount(r,s,lod);cyclic_ciws(r,s,lod);fittings(r,s,lod);radomes(r,s,lod)
    s.representative='KDXI class exterior; primary archive135.4m length and municipal rounded14m beam,14.2m selected beam estimate. Current2026operator activity separate from historical exterior photograph; individual upgrade electronics not certified. Local surfaces, cell positions and exposed barrel length estimated.'
    return r,s

def destroyer__chungmugong_yi_sun_sin_class(lod=0):
    r,s=combatant('destroyer__chungmugong_yi_sun_sin_class','Chungmugong Yi Sun-sin class',lod,(150.,17.4,4.9,5.2),
        DEMA+'20190722/1/BBSMSTR_000000010206/view.do',
        ['150x17.4m KDXII hull and angular separated deckhouses','127mmL62Mk45family gun','two funnels and solid tapered foremast',
         '32Mk41plus24KVLSclosed baseline lids','forward21cover RAM and aft seven-barrel Goalkeeper','eight SSM canisters','two helicopter hangar doors; no SPY arrays'],
        houses=[(0,19.,13.9,32.,8.0,0,.85),(0,-30.,14.2,31.,6.2,0,.92)],
        funnels=[(0,-2.,4.6,7.0,7.2,2.3),(0,-18.,4.3,6.5,6.8,2.3)],
        masts=[(17.,25.5,'bar',6.2),(-21.,18.0,'bar',2.4)],guns=[(0,54.,127,6.95)],
        vls=[(38.,8,4,.80,0),(29.8,6,4,.80,0)],canisters=[(-9.,2.3,4)],
        ciws=[(0,29.,8.0),(0,-37.,6.2)],ciws_styles=['ram','goalkeeper'],hangar_z=-45.6,hangar_doors=2,rail_count=28)
    search_array(r,s,lod,width=6.2);ram_face(r,s,lod);cyclic_ciws(r,s,lod);fittings(r,s,lod,torpedo_z=-12.);radomes(r,s,lod)
    s.representative='KDXII exterior, deployed Chungmugong/WangGeon family, not an HDF6000 export concept or Aegis KDXIII. Public150x17.4m and127mmL62family; local baseline cell layout/upgrade completion and fitting positions are not per-hull certification.'
    return r,s

def destroyer__jeongjo_the_great_class(lod=0):
    r,s=combatant('destroyer__jeongjo_the_great_class','Jeongjo the Great class',lod,(170.,21.,6.2,5.8),DAPA+'20270',
        ['170m KDXIII BatchII, published rounded21m beam','four fixed SPY1Dfamily faces on chamfered bridge','tall solid main mast and two funnels',
         '127mmL62family forward mount','48Mk41,16KVLSIand24KVLSIIclosed lids','two six-barrel Phalanx mounts, not RAM/Goalkeeper','two helicopter hangar doors'],
        houses=[(0,16.,16.6,39.,9.6,0,.84),(0,19.,11.5,18.,3.2,9.6,.87),(0,-32.,17.3,31.,7.2,0,.93),(0,35.,7.5,9.,2.8,0,.94)],
        funnels=[(0,-3.,5.6,8.,9.2,2.4),(0,-20.,5.4,7.5,8.6,2.4)],
        masts=[(18.,36.,'bar',3.4),(-22.,19.0,'bar',2.3)],guns=[(0,63.,127,6.95)],
        vls=[(47.,8,6,.82,0),(-25.,4,4,.84,7.2),(-36.,6,4,1.02,7.2)],canisters=[(-11.,2.7,8)],
        ciws=[(0,35.,2.8),(0,-42.,7.2)],ciws_styles=['phalanx','phalanx'],hangar_z=-47.6,hangar_doors=2,rail_count=25)
    fixed_spy_faces(r,s,lod);cyclic_ciws(r,s,lod);fittings(r,s,lod,torpedo_z=-14.);radomes(r,s,lod,1)
    mast=next(v for v in r.parts if v['name']=='Mast_0')['mesh'];D=s.draft+s.freeboard
    for h in (21.,28.):
        beam(mast,[-4.8,D+h,18.],[4.8,D+h,18.],.08,lod,'paint')
        if not lod:
            for side in (-1,1):beam(mast,[side*4.5,D+h,18.],[side*.5,D+h-1.6,18.],.045,lod,'paint')
    s.representative='Delivered Jeongjo2024and current RIMPAC2026type. Rounded170x21m primary dimensions; local topsides/draft/freeboard,88lid arrangement and sensor positions are exterior estimates. No128cell SejongBatchIor experimental KDDX body; no assertion all future missiles/CIWSIIalready fitted.'
    return r,s

def asFrigate__incheon_class(lod=0):
    r,s=combatant('asFrigate__incheon_class','Incheon class FFX BatchI',lod,(114.3,14.,4.2,4.5),
        DEMA+'20191004/2/ATCE_CTGR_0020050014/view.do',
        ['114m first-batch frigate','127mmMk45family forward gun','rotating SPS550Kfamily search array on conventional mast',
         'no VLS bank','eight external SSM canisters','forward six-barrel Phalanx and aft21cover RAM','single helicopter hangar and flight deck'],
        houses=[(0,12.,10.8,27.,6.5,0,.86),(0,-25.,11.0,22.,5.3,0,.93),(0,13.,7.1,13.,2.4,6.5,.82)],
        funnels=[(0,-5.0,4.0,7.8,6.4,1.8)],masts=[(10.,20.4,'panel',4.1)],guns=[(0,40.,127,6.95)],
        vls=[],canisters=[(-11.4,1.7,4)],ciws=[(0,21.,6.5),(0,-26.,5.3)],ciws_styles=['phalanx','ram'],
        hangar_z=-36.1,hangar_doors=1,rail_count=27)
    cyclic_ciws(r,s,lod);ram_face(r,s,lod);fittings(r,s,lod,torpedo_z=-13.);radomes(r,s,lod,2)
    s.representative='FFXBatchI Incheon exterior with RAM/Phalanx and no invented Daegu/ChungnamVLS. Length114.3m observed in commissioning photo caption, manufacturer family rounded114m; one representative current type, not an export HDFvariant. Local draft/freeboard and equipment positions estimated.'
    return r,s

def asFrigate__chungnam_class(lod=0):
    r,s=combatant('asFrigate__chungnam_class','Chungnam class FFX BatchIII',lod,(129.,14.8,4.1,5.7),DAPA+'20423',
        ['129x14.8m FFXBatchIII frigate','continuous stealth sidehouse,127mm forward gun and16closedKVLSlids',
         'four fixed MFRfaces on tall integrated sensor mast','only small top navigation radar rotates','single hangar and flight deck','CIWSIIplanned; empty foundation selected instead of inventing fielded fit'],
        houses=[(0,-7.,13.2,65.,5.6,0,.94),(0,16.,11.2,22.,4.4,5.6,.84)],
        funnels=[(0,-11.,4.7,6.2,4.9,5.6)],masts=[(9.,28.5,'bar',1.6)],guns=[(0,45.,127,6.95)],
        vls=[(32.,4,4,.86,1.4)],canisters=[(-19.,5.6,4)],ciws=[],ciws_styles=[],hangar_z=-39.6,hangar_doors=1,rail_count=28)
    integrated_sensor_mast(r,s,lod);fittings(r,s,lod,torpedo_z=-20.);upper_bridge_windows(r,s,lod);radomes(r,s,lod,1)
    m=Mesh();D=s.draft+s.freeboard;m.tube('paint',(0,D+5.6,-30.),(0,D+5.9,-30.),1.15,8 if lod else 24)
    r.add('CIWS_Reserved_Foundation','Hull',(0,D+5.6,-30.),m,fit='empty representative foundation; CIWSIIplanned, not asserted installed')
    s.representative='Delivered Chungnam-class FFXIII, four fixed MFRfaces, not rotating-radar Daegu or an export concept.129x14.8m/38.9m manufacturer dimensions; local surfaces and16lid layout estimated. CIWSIIexplicitly planned in2026maker brochure; empty reserved foundation, no unsupported installed gun claimed. Class includes delivered Gyeongbuk2026and separately launched/contracted later hulls, not all operational.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('destroyer__','asFrigate__')) and callable(f)}

def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        supported_canisters(r,s,lod);mounted_hangar_doors(r,s,lod);fore_vls_foundations(r,s,lod)
        exterior_refinement(r,s,lod)
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    from validate_ships import validate
    a,s=checked(0);b,t=checked(1);assert asdict(s)==asdict(t)
    hull=next(p['mesh'] for p in a.parts if p['name']=='Hull')
    points=np.concatenate([g[0] for g in hull.groups.values() if g[0]])
    low,high=points.min(0),points.max(0);collision=Mesh()
    collision.box('metal_dark',(low+high)/2,high-low)
    path=saver.common.ART/'ships'/(slug+'.glb')
    write_glb(path,[a,b],wreck(b),collision,{'scene_name':s.name,'vehicle':slug,'priority':'P7','spec':asdict(s),
        'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8')
    print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_21.py; current service and contract/delivery distinctions, configuration uncertainties and primary references in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
