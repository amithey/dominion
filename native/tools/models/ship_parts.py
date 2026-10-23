"""Original metre-scale naval geometry; no external meshes or textures.

Hull origin is at the keel under the footprint centre. The published draft
defines waterline_y in metadata; wake markers sit at that waterline.
"""
from dataclasses import dataclass,field,replace
import math
import numpy as np
from vehicle_parts import Mesh,Rig,loft,merge_mesh,hollow_muzzle,rotation

@dataclass
class ShipSpec:
    slug:str
    name:str
    length:float
    beam:float
    draft:float
    freeboard:float
    source:str
    family:str='combatant'
    approximate:bool=True
    representative:str=''
    features:list=field(default_factory=list)
    details:dict=field(default_factory=dict)

def block(m,role,x,y,z,w,h,l,taper=.85):
    """Chamfered eight-corner deckhouse with inward sloping topsides."""
    def ring(yy,scale):
        a=w*scale/2;b=l*scale/2;c=min(a,b)*.19
        return [[x+xx,yy,z+zz] for xx,zz in [(-a,-b+c),(-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),(a-c,b),(-a+c,b),(-a,b-c)]]
    loft(m,role,[ring(y,1),ring(y+h,taper)])

def beam(m,a,b,r=.06,lod=0,role='metal_dark'):
    m.tube(role,a,b,r,4 if lod else 8)

def hull(rig,s,lod):
    L=s.length;B=s.beam;D=s.draft+s.freeboard;d=s.details;m=Mesh()
    if d.get('catamaran'):
        temp=Rig(lod);demi=d.get('demi_beam',B*.22)
        hull(temp,replace(s,beam=demi,details={**d,'catamaran':False}),lod)
        for side in (-1,1):merge_mesh(m,temp.parts[0]['mesh'],t=(side*(B-demi)/2,0,0))
        # Full-width aft aviation deck bridges the two hulls to the transom.
        block(m,'paint',0,D-.8,-L*.075,B-.3,.8,L*.85,.98)
        rig.add('Hull',rig.root,(0,0,0),m)
        rig.add('Wake_Bow','Hull',(0,s.draft,L*.49),waterline_y=s.draft)
        rig.add('Wake_Stern','Hull',(0,s.draft,-L*.49),waterline_y=s.draft)
        return
    profile=d.get('hull_profile',[(-.5,.65),(-.45,.80),(-.3,.96),(-.1,1),(.12,1),(.30,.86),(.41,.55),(.48,.18),(.5,.008)])
    zz=sorted(set([p[0] for p in profile]+list(np.linspace(-.5,.5,10 if lod else 49))))
    rings=[]
    for z in zz:
        w=B/2*np.interp(z,*np.array(profile).T)
        sheer=max(0,(z-.22)/.28)*d.get('bow_sheer',1.7)
        # Full beam at deck shoulder, deep bilge and flat keel below waterline.
        section=[(w,D+sheer),(w*.97,D*.72),(w*.76,s.draft*.28),(w*.35,0),(-w*.35,0),(-w*.76,s.draft*.28),(-w*.97,D*.72),(-w,D+sheer)]
        rise=s.draft*.90*(max(0,(abs(z)-.25)/.25)**2)
        rings.append(np.array([[x,y+rise*(1-y/(D+sheer)),z*L-max(0,(z-.35)/.15)*L*.05*(1-y/(D+sheer))] for x,y in section]))
    m.face('paint',rings[0],[0,0,-1]);m.face('paint',rings[-1],[0,0,1])
    for a,b in zip(rings,rings[1:]):
        for j in range(8):
            k=(j+1)%8
            for tri in ([a[j],a[k],b[k]],[a[j],b[k],b[j]]):
                normal=np.cross(np.subtract(tri[1],tri[0]),np.subtract(tri[2],tri[0]))
                # Clockwise cross-sections generate inward strip triangles.
                # Reverse consistently, including the lifted bow/stern bilges.
                m.face('paint',tri,-normal)
    rig.add('Hull',rig.root,(0,0,0),m)
    rig.add('Wake_Bow','Hull',(0,s.draft,L*.49),waterline_y=s.draft)
    rig.add('Wake_Stern','Hull',(0,s.draft,-L*.49),waterline_y=s.draft)

def deckhouses(rig,s,lod):
    D=s.draft+s.freeboard;B=s.beam;L=s.length
    for i,item in enumerate(s.details['houses']):
        # x,z,w,length,height,base elevation above main deck,taper
        x,z,w,l,h,base,taper=item;m=Mesh();block(m,'paint',x,D+base,z,w,h,l,taper)
        rig.add('Bridge' if i==0 else 'Deckhouse_'+str(i),'Hull',(x,D+base,z),m)
        if i==0:
            glass=Mesh();yy=D+base+h*.72;front=z+l*(1-(1-taper)*.72)/2+.018
            for xx in np.linspace(-w*.32,w*.32,4 if lod else 8):
                glass.box('glass',(x+xx,yy,front),(w*.075,.60,.035))
            rig.add('Bridge_Windows','Hull',(x,yy,z),glass)
    # Hangar closures, flight-deck markings, liferafts and small boats.
    z=s.details.get('hangar_z',-L*.24);hangar=s.details.get('hangar',True)
    if hangar:
        m=Mesh();doors=s.details.get('hangar_doors',1)
        for i in range(doors):
            x=(i-(doors-1)/2)*B*.30
            m.box('metal_dark',(x,D+2.3,z),(B*.25,4.5,.065))
            if not lod:
                for y in np.linspace(D+.3,D+4.2,9):m.box('paint',(x,y,z-.045),(B*.245,.045,.04))
        rig.add('Hangar_Doors','Hull',(0,D,z),m)
    if s.details.get('flight_deck',True):
        m=Mesh();z=-L*.37;y=D+.025;R=min(B*.31,L*.055)
        for a in np.linspace(0,math.tau,12 if lod else 32,endpoint=False):
            b=a+math.tau/(12 if lod else 32)
            beam(m,[R*math.cos(a),y,z+R*math.sin(a)],[R*math.cos(b),y,z+R*math.sin(b)],.045,lod,'markings')
        for x in (-R*.30,R*.30):m.box('markings',(x,y,z),(.12,.022,R*.80))
        m.box('markings',(0,y,z),(R*.60,.022,.12));rig.add('Flight_Deck_Markings','Hull',(0,y,z),m)
    m=Mesh()
    for side in (-1,1):
        for i in range(2 if lod else 5):
            z=-L*.035+i*1.4;x=side*B*.40
            m.tube('rubber',(x-.48,D+1,z),(x+.48,D+1,z),.37,6 if lod else 12)
        if not lod:
            block(m,'rubber',side*B*.38,D+.15,-L*.08,1.6,.50,5.1,.7)
            block(m,'paint',side*B*.38,D+.62,-L*.085,1.0,.4,1.8,.7)
    rig.add('Boats_and_Liferafts','Hull',(0,D,0),m)

def funnels(rig,s,lod):
    D=s.draft+s.freeboard
    for i,(x,z,w,l,h,base) in enumerate(s.details['funnels']):
        m=Mesh();block(m,'paint',x,D+base,z,w,h,l,.76)
        m.box('metal_dark',(x,D+base+h+.035,z),(w*.71,.08,l*.71))
        if not lod:
            for side in (-1,1):
                for yy in np.linspace(D+base+h*.3,D+base+h*.62,5):
                    m.box('metal_dark',(x+side*w*.46,yy,z),(.035,.14,l*.5))
        rig.add('Funnel_'+str(i),'Hull',(x,D+base,z),m)
        rig.add('Exhaust_'+str(i),'Hull',(x,D+base+h+.1,z))

def radars(rig,s,lod):
    D=s.draft+s.freeboard
    for i,(z,h,style,width) in enumerate(s.details['masts']):
        m=Mesh();base=D+5;top=D+h
        block(m,'paint',0,base,z,width*.48,top-base,width*.6,.50)
        if not lod:
            for y in (top-4,top-1):beam(m,[-width*.8,y,z],[width*.8,y,z],.12,lod,'paint')
            for x in (-width*.75,width*.75):beam(m,[x,top-4,z],[x,top-1,z],.065,lod)
        rig.add('Mast_'+str(i),'Hull',(0,base,z),m)
        sensor=Mesh();p=np.array([0,top,z])
        if style=='enclosed':
            sensor.box('metal_dark',p+[0,1.3,0],(width*.7,1.5,.4))
            cover=Mesh();cover.tube('paint',p-[0,.2,0],p+[0,3,0],width*.55,8 if lod else 24,width*.44)
            rig.add('Radar_Radome_'+str(i),'Mast_'+str(i),p,cover)
        elif style=='panel':
            sensor.box('metal_dark',p+[0,1,0],(width,2,.50))
            sensor.box('paint',p+[0,-.1,0],(1,.25,1.4))
        elif style=='sphere':
            # Low-poly radome assembled as a closed ring loft.
            rr=[]
            for yy,rad in [(-.7,.15),(-.5,.8),(0,1),(.5,.8),(.7,.15)]:
                rr.append([[width*.5*rad*math.cos(t),top+1+yy*width,z+width*.5*rad*math.sin(t)] for t in np.linspace(0,math.tau,8 if lod else 24,endpoint=False)])
            loft(sensor,'paint',rr)
        else:
            sensor.box('metal_dark',p+[0,.3,0],(width,.60,.32))
        rig.add('Radar' if i==0 else 'Radar_'+str(i),'Mast_'+str(i),p,sensor,'Y')
    # SPY/APAR arrays are fixed panels: separate from the spinning search array.
    if s.details.get('fixed_arrays'):
        z,y,w=s.details['fixed_arrays'];y+=D;m=Mesh()
        # A closed diamond-section plinth supports all four diagonal array faces.
        r=w*.22
        loft(m,'paint',[[[x,yy,z+zz] for x,zz in [(w*.5,0),(0,w*.5),(-w*.5,0),(0,-w*.5)]] for yy in (y-r-.1,y+r+.1)])
        for side in (-1,1):
            for front in (-1,1):
                normal=np.array([side,0,front])/math.sqrt(2)
                p=np.array([side*w*.25,y,z+front*w*.25])+normal*.025
                t=np.array([front,0,-side])/math.sqrt(2);v=np.array([0,1,0]);r=w*.22;c=r*.28
                pts=[p+t*a+v*b for a,b in [(-r,-r+c),(-r+c,-r),(r-c,-r),(r,-r+c),(r,r-c),(r-c,r),(-r+c,r),(-r,r-c)]]
                m.face('metal_dark',pts,normal)
        rig.add('Fixed_Phased_Arrays','Hull',(0,y,z),m)

def naval_gun(rig,s,lod,i,x,z,calibre,length,base=0,aft=False):
    D=s.draft+s.freeboard;parent='Turret_Main' if i==0 else 'Turret_'+str(i)
    y=D+base+(max(0,(z/s.length-.22)/.28)*s.details.get('bow_sheer',1.7) if base==0 else 0)
    m=Mesh();m.tube('paint',(x,y,z),(x,y+.32,z),1.7 if calibre>=100 else 1.05,8 if lod else 24)
    block(m,'paint',x,y+.30,z,3.1 if calibre>=100 else 2.1,2.25 if calibre>=100 else 1.7,3.4 if calibre>=100 else 2.2,.55)
    rig.add(parent,'Hull',(x,y+.16,z),m,'Y')
    p=np.array([x,y+(1.6 if calibre>=100 else 1.3),z+.35]);gun=Mesh();sgn=-1 if aft else 1
    start=p+[0,0,sgn*.2];tip=p+[0,0,sgn*length]
    hollow_muzzle(gun,start,tip,calibre/1000*.70,calibre/1000*.46,8 if lod else 20)
    rig.add('Gun' if i==0 else 'Gun_'+str(i),parent,p,gun,'X')
    rig.add('Muzzle' if i==0 else 'Muzzle_'+str(i),'Gun' if i==0 else 'Gun_'+str(i),tip,
            **({'frame_rotation':[0,1,0,0]} if aft else {}))

def weapons(rig,s,lod):
    D=s.draft+s.freeboard
    for i,g in enumerate(s.details['guns']):naval_gun(rig,s,lod,i,*g)
    for i,(z,cols,rows,pitch,yoff) in enumerate(s.details.get('vls',[])):
        m=Mesh();y=D+yoff
        if s.details.get('vls_carousel'):
            for a in range(cols):
                for b in range(rows):
                    p=np.array([(a-(cols-1)/2)*pitch,y,z+(b-(rows-1)/2)*pitch])
                    m.tube('metal_dark',p+[0,.03,0],p+[0,.18,0],pitch*.44,8 if lod else 24)
                    if not lod:
                        for t in np.linspace(0,math.tau,8,endpoint=False):
                            c=p+[pitch*.29*math.cos(t),.21,pitch*.29*math.sin(t)]
                            m.tube('paint',c,c+[0,.025,0],pitch*.085,8)
            rig.add('VLS_'+str(i),'Hull',(0,y,z),m,cell_count=cols*rows*8)
            continue
        m.box('paint',(0,y+.08,z),(cols*pitch+.16,.16,rows*pitch+.16))
        if not lod:
            for a in range(cols):
                for b in range(rows):
                    p=[(a-(cols-1)/2)*pitch,y+.19,z+(b-(rows-1)/2)*pitch]
                    m.box('metal_dark',p,(pitch*.86,.055,pitch*.86))
                    m.box('paint',np.array(p)+[0,.038,pitch*.30],(pitch*.64,.028,pitch*.12))
        rig.add('VLS_'+str(i),'Hull',(0,y,z),m,cell_count=cols*rows)
    for i,(z,yoff,count) in enumerate(s.details.get('canisters',[])):
        m=Mesh();y=D+yoff
        for side in (-1,1):
            for j in range(count):
                a=np.array([side*.3,y+1,z+(j-(count-1)/2)*.75]);b=a+[side*4,1.5,0]
                m.tube('paint',a,b,.33,6 if lod else 12)
                m.tube('metal_dark',b,b+[side*.07,.026,0],.29,6 if lod else 12)
        rig.add('AntiShip_Canisters_'+str(i),'Hull',(0,y,z),m)
    for i,(x,z,yoff) in enumerate(s.details.get('ciws',[])):
        style=s.details.get('ciws_styles',[s.details.get('ciws_style','phalanx')]*len(s.details.get('ciws',[])))[i]
        if style in ('ram','crotale'):
            p=np.array([x,D+yoff,z]);mount=Mesh();mount.tube('paint',p,p+[0,.8,0],.75,6 if lod else 16)
            rig.add('CIWS_'+str(i),'Hull',p,mount,'Y');rack=Mesh();pivot=p+[0,1.2,0]
            rack.box('paint',pivot,(1.0,1.3,1.8) if style=='crotale' else (2.3,2.2,2.0))
            if style=='crotale':rack.tube('paint',pivot+[0,.7,0],pivot+[0,1.5,0],.5,6 if lod else 16)
            tips=[]
            for j in range(s.details.get('ciws_tubes',21)):
                tip=pivot+([(-1 if j<4 else 1)*1.12+(j%2-.5)*.36,((j//2)%2-.5)*.36,1.04] if style=='crotale' else [(j%5-2)*.42,(j//5-2)*.42,1.04])
                if style=='crotale':rack.tube('paint',tip-[0,0,2.1],tip,.17,6 if lod else 12)
                if not lod:rack.tube('metal_dark',tip-[0,0,.05],tip+[0,0,.035],.16,8)
                tips.append(tip)
            rig.add('CIWS_Launcher_'+str(i),'CIWS_'+str(i),pivot,rack,'X')
            for j,tip in enumerate(tips):rig.add('RAM_Muzzle_'+str(i)+'_'+str(j),'CIWS_Launcher_'+str(i),tip)
            continue
        m=Mesh();p=np.array([x,D+yoff,z]);m.tube('paint',p,p+[0,1,0],.8,6 if lod else 16)
        m.box('paint',p+[0,1.5,0],(1.4,1.0,1.2))
        if style in ('goalkeeper','gokdeniz'):m.box('metal_dark',p+[0,2.6,-.25],(1.5,.8,.45))
        elif style=='gatling':m.tube('paint',p+[0,2,0],p+[0,2.5,0],.55,6 if lod else 16)
        elif style=='kashtan':
            for side in (-1,1):m.box('paint',p+[side*1.1,2,0],(.6,.8,2.6))
        else:m.tube('paint',p+[0,2,0],p+[0,3.2,0],.5,6 if lod else 16)
        rig.add('CIWS_'+str(i),'Hull',p,m,'Y')
        barrel=Mesh()
        for offset in ((-.35,.35) if style in ('gokdeniz','kashtan') else (0,)):
            hollow_muzzle(barrel,p+[offset,1.4,.6],p+[offset,1.4,2.1],.12,.065,6 if lod else 12)
        rig.add('CIWS_Gun_'+str(i),'CIWS_'+str(i),p+[0,1.4,.6],barrel,'X')
        rig.add('CIWS_Muzzle_'+str(i),'CIWS_Gun_'+str(i),p+[0,1.4,2.1])
    for i,(x,z,yoff) in enumerate(s.details.get('rbu_positions',[])):
        p=np.array([x,D+yoff,z]);m=Mesh();m.tube('paint',p,p+[0,.5,0],.65,6 if lod else 16)
        rig.add('RBU_'+str(i),'Hull',p,m,'Y');rack=Mesh();pivot=p+[0,1,0];tips=[]
        for j,t in enumerate(np.linspace(0,math.tau,12,endpoint=False)):
            a=pivot+[.65*math.cos(t),.45*math.sin(t),0];b=a+[0,.60,.75]
            rack.tube('metal_dark',a,b,.14,4 if lod else 8);tips.append(b)
        rig.add('RBU_Rack_'+str(i),'RBU_'+str(i),pivot,rack,'X')
        for j,p in enumerate(tips):rig.add('RBU_Muzzle_'+str(i)+'_'+str(j),'RBU_Rack_'+str(i),p)
    if s.details.get('arm_launcher'):
        x,z,yoff=s.details['arm_launcher'];p=np.array([x,D+yoff,z]);m=Mesh()
        m.tube('paint',p,p+[0,1.4,0],.65,6 if lod else 16)
        rig.add('Launcher_SAM','Hull',p,m,'Y');q=p+[0,1.4,0];rail=Mesh()
        rail.box('metal_dark',q+[0,0,.4],(.45,.35,3.2))
        rail.tube('paint',q+[0,.3,-1.8],q+[0,.3,2.6],.17,6 if lod else 16,.035)
        for side in (-1,1):rail.box('paint',q+[side*.35,.3,-1.2],(.7,.08,.9))
        rig.add('Launcher_Rail','Launcher_SAM',q,rail,'X');rig.add('SAM_Muzzle','Launcher_Rail',q+[0,.3,2.6])

def fittings(rig,s,lod):
    D=s.draft+s.freeboard;B=s.beam;L=s.length;m=Mesh()
    # Railings follow actual deck outlines; no rails across the flight deck.
    outline=s.details.get('hull_profile',[(-.5,.65),(-.45,.80),(-.3,.96),(-.1,1),(.12,1),(.30,.86),(.41,.55),(.48,.18),(.5,.008)])
    for side in (-1,1):
        points=[]
        for z in np.linspace(-.28,.465,9 if lod else s.details.get('rail_count',37)):
            w=np.interp(z,*np.array(outline).T)
            x=side*((B-demi)/2+demi/2*w-.10) if s.details.get('catamaran') and (demi:=s.details.get('demi_beam',B*.22)) else side*(B/2*w-.10)
            y=D+max(0,(z-.22)/.28)*s.details.get('bow_sheer',1.7)
            p=np.array([x,y,z*L]);points.append(p)
            if not lod:beam(m,p,p+[0,1.05,0],.028,lod)
        for a,b in zip(points,points[1:]):
            beam(m,a+[0,1.05,0],b+[0,1.05,0],.027,lod)
            if not lod:beam(m,a+[0,.5,0],b+[0,.5,0],.022,lod)
        # Bow pennant backing panel, mooring bollards and an anchor.
        p=[side*((B-s.details.get('demi_beam',B*.22))/2+s.details.get('demi_beam',B*.22)*.25) if s.details.get('catamaran') else side*B*.31,D*.65,L*.40]
        m.box('markings',p,(.045,1.4,4.))
        for z in (-L*.44,L*.40):
            for dz in (-.35,.35):m.tube('metal_dark',(side*B*.25,D,z+dz),(side*B*.25,D+.5,z+dz),.18,6 if lod else 12)
        beam(m,[side*B*.40,D*.7,L*.34],[side*B*.40,D*.4,L*.34],.14,lod)
    rig.add('Deck_Fittings','Hull',(0,D,0),m)

def build(s,lod=0):
    rig=Rig(lod);hull(rig,s,lod);deckhouses(rig,s,lod);funnels(rig,s,lod);radars(rig,s,lod);weapons(rig,s,lod);fittings(rig,s,lod)
    for p in rig.parts:
        if p['mesh'] is not None:p['mesh'].remove_duplicates()
    return rig,s

def wreck(rig):
    m=Mesh()
    for p in rig.parts:
        if p['mesh'] is not None:merge_mesh(m,p['mesh'],roles={'paint':'metal_dark','glass':'metal_dark','markings':'metal_dark'})
    m.remove_duplicates();return m
