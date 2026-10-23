"""Original fixed-wing airframes and control surfaces. Metres, +Z forward.

Closed airfoils, recessed intake ducts, hinge-local control axes and separate
gear/tyre nodes. No Blender, imported meshes, images or baked colours.
"""
from dataclasses import dataclass,field
import math
import numpy as np
from vehicle_parts import Mesh,Rig,rotation,merge_mesh,lathe_x,hollow_muzzle,quaternion_product
from helicopter_parts import shell_surface
from generate_p1_tanks import beam

@dataclass
class AircraftSpec:
    slug:str
    name:str
    family:str
    length:float
    span:float
    height:float
    body_width:float
    body_height:float
    belly:float
    engines:int
    source:str
    seats:int=1
    stealth:bool=False
    approximate:bool=True
    representative:str=''
    features:list=field(default_factory=list)
    details:dict=field(default_factory=dict)

def quat(axis,angle):
    axis=np.asarray(axis,dtype=float);axis/=np.linalg.norm(axis)
    return np.r_[axis*math.sin(angle/2),math.cos(angle/2)].tolist()

def curved_shell(m,role,sections,lod=0,window=None,cross_power=1.,cap_start=True,cap_end=True):
    """Bounded cubic Hermite meridians; smooth positive radii, fixed end sizes."""
    a=np.asarray(sections,dtype=float);z=a[:,0];values=a[:,1:];h=np.diff(z)
    assert (h>0).all()
    slopes=np.diff(values,axis=0)/h[:,None];tangents=np.zeros_like(values)
    tangents[0]=slopes[0];tangents[-1]=slopes[-1]
    for j in range(1,len(a)-1):
        for k in range(3):
            u,v=slopes[j-1,k],slopes[j,k]
            if u*v>0:tangents[j,k]=(h[j-1]+h[j])/(h[j-1]/u+h[j]/v)
    samples=[]
    for j in range(len(a)-1):
        for t in np.linspace(0,1,1 if lod else 4,endpoint=False):
            p=(2*t**3-3*t*t+1)*values[j]+(t**3-2*t*t+t)*h[j]*tangents[j]
            p+=(-2*t**3+3*t*t)*values[j+1]+(t**3-t*t)*h[j]*tangents[j+1]
            samples.append([z[j]+t*h[j],*p])
    samples.append(a[-1].tolist())
    shell_surface(m,role,samples,lod,window,cross_power,segments=12 if lod else 36,subdivisions=1,cap_start=cap_start,cap_end=cap_end)

def airfoil(m,stations,lod=0,role='paint'):
    """Closed symmetric airfoil. Stations are span-X, Y, leading-Z, trailing-Z."""
    count=4 if lod else 10
    chords=np.linspace(0,1,count)
    profile=[(t,1) for t in chords]+[(t,-1) for t in chords[-2:0:-1]]
    def ring(s):
        x,y,lead,trail=s;c=lead-trail;assert c>.015
        points=[]
        for t,side in profile:
            thickness=5*.085*(.2969*math.sqrt(t)-.1260*t-.3516*t*t+.2843*t**3-.1036*t**4)*c
            points.append([x,y+side*thickness,lead-t*c])
        return np.asarray(points)
    dense=[]
    for a,b in zip(stations,stations[1:]):
        for t in np.linspace(0,1,1 if lod else 6,endpoint=False):dense.append(np.asarray(a)*(1-t)+np.asarray(b)*t)
    dense.append(np.asarray(stations[-1]));rings=[ring(s) for s in dense]
    m.face(role,rings[0],[-1,0,0]);m.face(role,rings[-1],[1,0,0])
    for a,b in zip(rings,rings[1:]):
        mid=(a.mean(0)+b.mean(0))/2
        for i in range(len(a)):
            k=(i+1)%len(a);q=[a[i],a[k],b[k],b[i]]
            m.face(role,q,np.mean(q,axis=0)-mid)

def interpolate(stations,x):
    a=np.asarray(stations,dtype=float)
    return np.array([x,*[np.interp(x,a[:,0],a[:,j]) for j in range(1,4)]])

def interval(stations,start,end):
    return [interpolate(stations,start)]+[np.asarray(s) for s in stations if start<s[0]<end]+[interpolate(stations,end)]

def wings(rig,s,lod):
    stations=s.details['wing'];root=stations[0][0];tip=stations[-1][0];split=root+(tip-root)*.55
    for side,label in ((-1,'L'),(1,'R')):
        base=[]
        for x,y,le,te in stations:base.append([x,y,le,te+(le-te)*.25+.008])
        wing=Mesh();airfoil(wing,base,lod)
        if side<0:
            # Proper rotation, rather than negative scale or inverted winding.
            mirrored=Mesh()
            for role,g in wing.groups.items():
                p,n,uv,f=mirrored.groups[role];p.extend((np.asarray(g[0])*[-1,1,1]).tolist());n.extend((np.asarray(g[1])*[-1,1,1]).tolist())
                uv.extend(g[2]);f.extend(np.asarray(g[3]).reshape(-1,3)[:,::-1].reshape(-1).tolist())
            wing=mirrored
        wp=(side*root,stations[0][1],(stations[0][2]+stations[0][3])/2)
        rig.add('Wing_'+label,'Fuselage',wp,wing,'Y' if s.details.get('swing_wing') else None)
        for name,start,end in [('Flap',root,split-.006),('Aileron',split+.006,tip)]:
            data=interval(stations,start,end);control=Mesh()
            cuts=[[x,y,te+(le-te)*.25-.008,te] for x,y,le,te in data]
            airfoil(control,cuts,lod)
            if side<0:
                for g in control.groups.values():
                    g[0]=(np.asarray(g[0])*[-1,1,1]).tolist();g[1]=(np.asarray(g[1])*[-1,1,1]).tolist()
                    g[3]=np.asarray(g[3]).reshape(-1,3)[:,::-1].reshape(-1).tolist()
            p=np.array([side*cuts[0][0],cuts[0][1],cuts[0][2]])
            v=np.array([side*(cuts[-1][0]-cuts[0][0]),0,cuts[-1][2]-cuts[0][2]])
            if v[0]<0:v=-v
            angle=math.atan2(-v[2],v[0])
            rig.add(name+'_'+label,'Wing_'+label,p,control,'X',frame_rotation=quat([0,1,0],angle))

def fuselage(rig,s,lod):
    L=s.length;W=s.body_width;H=s.body_height;b=s.belly;cy=b+H/2;m=Mesh()
    default=[(-.455,0,.28,.32),(-.42,0,.47,.47),(-.25,0,.50,.50),(0,0,.50,.50),
             (.15,.04,.36,.43),(.30,.06,.25,.33),(.42,.03,.15,.20),(.50,0,.012,.020)]
    profile=s.details.get('profile',default)
    sections=[(z*L,cy+dy*H,rx*W,ry*H) for z,dy,rx,ry in profile]
    curved_shell(m,'paint',sections,lod,cross_power=s.details.get('cross_power',1.),cap_start=s.engines!=1,cap_end=not s.details.get('nose_intake'))
    if s.details.get('cft'):
        for side in (-1,1):
            tank=Mesh()
            curved_shell(tank,'paint',[(-L*.28,cy-.26,.18,.29),(-L*.20,cy-.25,.36,.50),
                (L*.015,cy-.22,.36,.50),(L*.08,cy-.20,.18,.28)],lod,cross_power=.80)
            tank.shift((side*W*.54,0,0));merge_mesh(m,tank)
    for side in (-1,1):
        p=(side*W*.49,cy,-L*.12)
        m.box('paint',p,(.08,H*.23,L*.05));m.box('markings',(p[0]+side*.047,p[1],p[2]),(.016,H*.17,L*.042))
    rig.add('Fuselage',rig.root,(0,0,0),m)

def canopy(rig,s,lod):
    L=s.length;W=s.body_width;H=s.body_height;top=s.belly+H
    front=L*.385;rear=L*(.075 if s.seats==2 else .15);mid=(front+rear)/2
    m=Mesh();sections=[(rear,top-.10,W*.13,.10),(rear+(front-rear)*.18,top+.20,W*.28,.46),
        (mid,top+.22,W*.29,.51),(front-(front-rear)*.16,top+.12,W*.22,.40),(front,top-.04,W*.04,.07)]
    def glazing(z,theta):
        if abs(z-rear)<.06 or abs(z-front)<.06:return 'paint'
        if s.seats==2 and abs(z-mid)<.05:return 'paint'
        return 'glass' if math.cos(theta)>-.18 and .15<theta<math.tau-.15 else 'paint'
    curved_shell(m,'paint',sections,lod,glazing)
    rig.add('Canopy','Fuselage',(0,top-.10,rear),m,'X',seats=s.seats)

def rectangular_duct(m,front,back,x0,x1,y0,y1,width,height,lod):
    def ring(x,y,z,w,h):return np.array([[x-w/2,y-h/2,z],[x+w/2,y-h/2,z],[x+w/2,y+h/2,z],[x-w/2,y+h/2,z]])
    a=ring(x0,y0,front,width,height);b=ring(x1,y1,back,width*.91,height*.91)
    ai=ring(x0,y0,front,width-.10,height-.10);bi=ring(x1,y1,back,width*.91-.10,height*.91-.10)
    for i in range(4):
        j=(i+1)%4
        m.solid('paint',[a[i],a[j],b[j],b[i],ai[i],ai[j],bi[j],bi[i]],
            [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
    m.face('metal_dark',bi,[0,0,1])
    m.remove_duplicates()

def engines(rig,s,lod):
    L=s.length;W=s.body_width;H=s.body_height;cy=s.belly+H/2
    for i in range(s.engines):
        x=(i-(s.engines-1)/2)*s.details.get('engine_spacing',W*.62);m=Mesh()
        radius=s.details.get('engine_radius',.43 if s.engines==2 else .51);aft=L*(.50-s.details.get('engine_aft_fraction',.50))
        if s.engines==2:
            pod=Mesh();curved_shell(pod,'paint',[(-L*.46,cy,radius,radius),(-L*.42,cy,radius*1.13,radius*1.13),
                 (-L*.15,cy,radius*1.16,radius*1.16),(L*.03,cy,radius*.90,radius*.90)],lod,cap_start=False)
            pod.shift((x,0,aft));merge_mesh(m,pod)
        hollow_muzzle(m,(x,cy,-L*.46+aft),(x,cy,-L*.50+aft),radius,radius*.82,8 if lod else 24)
        rig.add('Engine_'+str(i),'Fuselage',(x,cy,-L*.20),m)
        rig.add('Afterburner' if i==0 else 'Afterburner_'+str(i),'Fuselage',(x,cy,-L*.50+aft),frame_rotation=quat([0,1,0],math.pi),forward='-Z')
    if s.family=='f15':
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();rectangular_duct(m,L*.16,-L*.20,side*1.32,side*.82,cy+.04,cy,1.10,1.08,lod)
            rig.add('Intake_'+label,'Fuselage',(side*1.32,cy,L*.16),m)
    elif s.family=='typhoon':
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();rectangular_duct(m,L*.16,-L*.08,side*.46,side*.51,s.belly+.05,cy-.05,.82,.78,lod)
            m.box('paint',(side*.46,s.belly+.51,L*.14),(.81,.18,.64))
            rig.add('Intake_'+label,'Fuselage',(side*.46,s.belly+.05,L*.16),m)
    elif s.details.get('nose_intake'):
        m=Mesh();radius=s.details.get('nose_radius',.46);z=L*.484
        hollow_muzzle(m,(0,cy,z-.55),(0,cy,z),radius,radius*.88,8 if lod else 24)
        m.tube('paint',(0,cy,z-.35),(0,cy,L*.50),radius*.47,8 if lod else 24,.012)
        rig.add('Nose_Intake','Fuselage',(0,cy,z),m)
    elif s.details.get('side_intakes'):
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();x=side*s.details.get('intake_x',W*.46);z=L*s.details.get('intake_z',.19)
            if s.details.get('intake_round'):
                radius=s.details.get('intake_width',.70)/2
                hollow_muzzle(m,(x,cy-.15,z-.85),(x,cy-.15,z),radius,radius*.86,8 if lod else 24)
                if s.details.get('shock_cones'):m.tube('paint',(x,cy-.15,z-.45),(x,cy-.15,z+.22),radius*.47,8 if lod else 20,.012)
            else:rectangular_duct(m,z,-L*.08,x,x*.80,cy-.15,cy,s.details.get('intake_width',.70),s.details.get('intake_height',.75),lod)
            rig.add('Intake_'+label,'Fuselage',(x,cy-.15,z),m)
    else:
        # F-16's underslung elliptical mouth, with a recessed closed interior.
        m=Mesh();z=L*.20;cy0=s.belly+.05;n=8 if lod else 24;outer=[];inner=[]
        for zz,yy,wx,hy in [(z,cy0,.62,.35),(-L*.05,cy,.54,.48)]:
            outer.append(np.array([[wx*math.sin(t),yy+hy*math.cos(t),zz] for t in np.linspace(0,math.tau,n,endpoint=False)]))
            inner.append(np.array([[(wx-.06)*math.sin(t),yy+(hy-.06)*math.cos(t),zz] for t in np.linspace(0,math.tau,n,endpoint=False)]))
        for i in range(n):
            j=(i+1)%n
            m.face('paint',[outer[0][i],outer[0][j],outer[1][j],outer[1][i]],np.mean([outer[0][i],outer[0][j]],axis=0)-[0,cy0,z])
            m.face('metal_dark',[inner[0][i],inner[1][i],inner[1][j],inner[0][j]],[0,cy0,z]-np.mean([outer[0][i],outer[0][j]],axis=0))
            m.face('paint',[outer[0][i],inner[0][i],inner[0][j],outer[0][j]],[0,0,1])
            m.face('paint',[outer[1][i],outer[1][j],inner[1][j],inner[1][i]],[0,0,-1])
        m.face('metal_dark',inner[1],[0,0,1]);rig.add('Intake','Fuselage',(0,cy0,z),m)

def mirror(m):
    for g in m.groups.values():
        g[0]=(np.asarray(g[0])*[-1,1,1]).tolist();g[1]=(np.asarray(g[1])*[-1,1,1]).tolist()
        g[3]=np.asarray(g[3]).reshape(-1,3)[:,::-1].reshape(-1).tolist()
    return m

def horizontal(rig,s,lod,name,stations):
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();airfoil(m,stations,lod)
        if side<0:mirror(m)
        x,y,le,te=stations[0]
        rig.add(name+'_'+label,'Fuselage',(side*x,y,(le+te)/2),m,'X')

def tails(rig,s,lod):
    for i,fin in enumerate(s.details['fins']):
        x,y0,y1,le0,te0,le1,te1=fin;cant=s.details.get('fin_cant',0)*(1 if x>=0 else -1)
        cut0=te0+(le0-te0)*.27;cut1=te1+(le1-te1)*.27
        # Airfoil span is rotated into the vertical plane. No negative scales.
        R=rotation([0,0,1],math.pi/2-math.radians(cant))
        for moving in (False,True):
            m=Mesh();a,b=(cut0-.008,te0) if moving else (le0,cut0+.008)
            c,d=(cut1-.008,te1) if moving else (le1,cut1+.008)
            airfoil(m,[(0,0,a,b),(y1-y0,0,c,d)],lod)
            for g in m.groups.values():
                g[0]=(np.asarray(g[0])@R.T+[x,y0,0]).tolist();g[1]=(np.asarray(g[1])@R.T).tolist()
            name=('Rudder' if i==0 else 'Rudder_R') if moving else 'Fin_'+str(i)
            angle=math.atan2(cut1-cut0,y1-y0)
            frame=quaternion_product(quat([0,0,1],-math.radians(cant)),quat([1,0,0],angle))
            rig.add(name,'Fuselage',(x,y0,cut0),m,'Y' if moving else None,
                    **({'frame_rotation':np.asarray(frame).tolist()} if moving else {}))
    if 'stabilator' in s.details:horizontal(rig,s,lod,'Stabilator',s.details['stabilator'])
    if 'canard' in s.details:horizontal(rig,s,lod,'Canard',s.details['canard'])

def gear(rig,s,lod):
    L=s.length;track=s.details.get('gear_track',s.span*.24);r=s.details.get('wheel_radius',.36)
    for name,x,z in [('Gear_Nose',0,L*.27),('Gear_Left',-track/2,-L*.075),('Gear_Right',track/2,-L*.075)]:
        rr=r*.77 if name=='Gear_Nose' else r;hinge=np.array([x*.75,s.belly+.35,z+.20]);wheel=np.array([x,rr,z])
        m=Mesh();m.tube('metal_dark',hinge,wheel,.055,6 if lod else 12)
        m.tube('paint',hinge,hinge*.35+wheel*.65,.09,6 if lod else 12)
        rig.add(name,'Fuselage',hinge,m,'X')
        tyre=Mesh();lathe_x(tyre,[(-.095,0,'rubber'),(-.095,rr*.70,'rubber'),(-.085,rr*.96,'rubber'),(-.045,rr,'rubber'),(.045,rr,'rubber'),(.085,rr*.96,'rubber'),(.095,rr*.70,'rubber'),(.095,0,'rubber')],wheel,8 if lod else 20)
        tyre.tube('metal_dark',wheel+[-.10,0,0],wheel+[.10,0,0],rr*.63,8 if lod else 16)
        rig.add(name+'_Wheel',name,wheel,tyre,'X')

def weapons(rig,s,lod):
    count=0;positions={};L=s.length;y=s.belly+s.body_height*.52
    gun=s.details.get('gun',True)
    for gi in range(s.details.get('gun_count',1) if gun else 0):
        side=(-1 if gi==0 else 1) if s.details.get('gun_count',1)==2 else s.details.get('gun_side',1)
        x=side*s.body_width*s.details.get('gun_width',.43);z=L*s.details.get('gun_fraction',.15);m=Mesh()
        if s.stealth:
            x=-abs(x);m.box('paint',(x,y,z),(.12,.13,.42))
        else:m.box('paint',(x,y,z),(.20,.20,.64))
        hollow_muzzle(m,(x,y,z+.28),(x,y,z+.48),.049,.024,6 if lod else 12)
        parent='Cannon' if gi==0 else 'Cannon_'+str(gi)
        rig.add(parent,'Fuselage',(x,y,z),m);p=[x,y,z+.48]
        rig.add('Muzzle_'+str(count),parent,p);positions['Muzzle_'+str(count)]=p;count+=1
    if s.stealth:
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();x=side*s.body_width*.25;m.box('paint',(x,s.belly+.06,0),(s.body_width*.44,.10,L*.18))
            rig.add('Bay_Door_'+label,'Fuselage',(side*s.body_width*.47,s.belly+.06,0),m,'Z')
            p=[x,s.belly+.17,L*.07];rig.add('Muzzle_'+str(count),'Fuselage',p);positions['Muzzle_'+str(count)]=p;count+=1
    else:
        for side,label in ((-1,'L'),(1,'R')):
            for j,f in enumerate((.40,.66,.89)):
                station=interpolate(s.details['wing'],s.span/2*f);x=side*station[0];yy=station[1]-.22;z=(station[2]+station[3])/2
                m=Mesh();m.box('paint',(x,yy,z),(.10,.38,.70));rig.add('Pylon_'+label+str(j),'Wing_'+label,(x,yy+.19,z),m)
                store=Mesh();a=(x,yy-.30,z-.95);b=(x,yy-.30,z+1.0)
                store.tube('paint',a,b,.105,6 if lod else 12,.025)
                for sign in (-1,1):store.box('paint',(x+sign*.16,yy-.30,z-.66),(.25,.035,.29))
                parent='Store_'+label+str(j);rig.add(parent,'Pylon_'+label+str(j),(x,yy-.30,z),store)
                p=list(b);rig.add('Muzzle_'+str(count),parent,p);positions['Muzzle_'+str(count)]=p;count+=1
    s.details['muzzle_positions']=positions;s.details['muzzle_count']=count

def burnt_wreck(rig,s):
    out=Mesh()
    for part in rig.parts:
        if part['mesh'] is not None:
            for role,g in part['mesh'].groups.items():
                target=out.groups['rubber' if role=='rubber' else 'metal_dark'];offset=len(target[0])
                target[0].extend(g[0]);target[1].extend(g[1]);target[2].extend(g[2]);target[3].extend([i+offset for i in g[3]])
    out.remove_duplicates();return out

def fittings(rig,s,lod):
    L=s.length;W=s.body_width;y=s.belly+s.body_height;m=Mesh()
    if s.family=='f15':
        m.box('paint',(0,y+.025,-L*.04),(W*.58,.07,L*.14))
        # Eagle tail-boom warning-receiver fairings differ by export fit.
        variant=s.details.get('variant','j')
        radii={'j':(.11,.11),'ex':(.19,.19),'i':(.13,.21),'sa':(.18,.18)}[variant]
        for side,r in zip((-1,1),radii):
            p=np.array([side*W*.51,y-.32,-L*.43])
            m.tube('paint',p,p+[0,0,-.70],r,6 if lod else 16,r*.60)
        if variant=='i':
            for side in (-1,1):
                m.box('paint',(side*W*.43,y-.12,L*.24),(.11,.24,.35))
                m.box('glass',(side*W*.46,y-.12,L*.24),(.025,.13,.19))
        if variant in ('ex','sa'):
            for side in (-1,1):m.box('paint',(side*W*.48,y-.05,-L*.15),(.15,.25,.48))
    if s.family=='f16' or s.details.get('lex'):
        for side in (-1,1):
            lex=Mesh();airfoil(lex,[(W*.32,y-.48,L*.21,-L*.13),(W*.68,y-.48,L*.08,-L*.13),(W*1.1,y-.48,0,-L*.13)],lod)
            if side<0:mirror(lex)
            merge_mesh(m,lex)
        if s.family=='f16':
            for side in (-1,1):
                p=np.array([side*.43,s.belly+.17,-L*.35]);m.box('paint',p,(.045,.49,1.23))
    if s.details.get('wingtip_pods'):
        for side in (-1,1):
            x,yw,le,te=s.details['wing'][-1];z=(le+te)/2
            m.tube('paint',(side*x,yw,z-.65),(side*x,yw,z+.75),.12,8 if lod else 20,.07)
    if s.details.get('modern_f5'):
        m.box('paint',(0,y+.05,-L*.10),(.24,.20,.65))
        for side in (-1,1):m.box('paint',(side*W*.43,y-.30,L*.27),(.11,.16,.28))
    # Dorsal blades are supported by the skin, with no free-floating fittings.
    for z,h in ((L*.04,.23),(-L*.19,.18)):
        m.box('paint',(0,y-.06+h/2,z),(.045,h,.28))
    rig.add('Airframe_Fittings','Fuselage',(0,y,0),m)

def build(s,lod=0):
    rig=Rig(lod);fuselage(rig,s,lod);wings(rig,s,lod);canopy(rig,s,lod);engines(rig,s,lod)
    tails(rig,s,lod);gear(rig,s,lod);weapons(rig,s,lod);fittings(rig,s,lod)
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    return rig,s
