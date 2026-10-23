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

def curved_shell(m,role,sections,lod=0,window=None,cross_power=1.,cap_start=True,cap_end=True,circumference=None,longitudinal=None):
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
        for t in np.linspace(0,1,1 if lod else (longitudinal or 4),endpoint=False):
            p=(2*t**3-3*t*t+1)*values[j]+(t**3-2*t*t+t)*h[j]*tangents[j]
            p+=(-2*t**3+3*t*t)*values[j+1]+(t**3-t*t)*h[j]*tangents[j+1]
            samples.append([z[j]+t*h[j],*p])
    samples.append(a[-1].tolist())
    shell_surface(m,role,samples,lod,window,cross_power,segments=circumference or (12 if lod else 36),subdivisions=1,cap_start=cap_start,cap_end=cap_end)

def airfoil(m,stations,lod=0,role='paint',span_steps=None,chord_steps=None):
    """Closed symmetric airfoil. Stations are span-X, Y, leading-Z, trailing-Z."""
    count=chord_steps or (4 if lod else 10)
    chords=np.linspace(0,1,count)
    profile=[(t,1) for t in chords]+[(t,-1) for t in chords[-2:0:-1]]
    def ring(s):
        x,y,lead,trail=s;c=lead-trail;assert c>1e-4
        points=[]
        for t,side in profile:
            thickness=5*.085*(.2969*math.sqrt(t)-.1260*t-.3516*t*t+.2843*t**3-.1036*t**4)*c
            points.append([x,y+side*thickness,lead-t*c])
        return np.asarray(points)
    dense=[]
    for a,b in zip(stations,stations[1:]):
        for t in np.linspace(0,1,span_steps or (1 if lod else 6),endpoint=False):dense.append(np.asarray(a)*(1-t)+np.asarray(b)*t)
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
            v=np.array([side*(cuts[-1][0]-cuts[0][0]),cuts[-1][1]-cuts[0][1],cuts[-1][2]-cuts[0][2]])
            if v[0]<0:v=-v
            angle=math.atan2(-v[2],v[0])
            frame=quat([0,1,0],angle)
            if abs(v[1])>1e-8:
                unit=v/np.linalg.norm(v);frame=quat(np.cross([1,0,0],unit),math.acos(unit[0]))
            rig.add(name+'_'+label,'Wing_'+label,p,control,'X',frame_rotation=frame)

def fuselage(rig,s,lod):
    L=s.length;W=s.body_width;H=s.body_height;b=s.belly;cy=b+H/2;m=Mesh()
    default=[(-.455,0,.28,.32),(-.42,0,.47,.47),(-.25,0,.50,.50),(0,0,.50,.50),
             (.15,.04,.36,.43),(.30,.06,.25,.33),(.42,.03,.15,.20),(.50,0,.012,.020)]
    profile=s.details.get('profile',default)
    sections=[(z*L,cy+dy*H,rx*W,ry*H) for z,dy,rx,ry in profile]
    def windows(z,theta):
        if s.details.get('glazed_nose') and z>.44*L and math.cos(theta)<.45:return 'glass'
        return 'glass' if .325*L<z<.425*L and .35<math.cos(theta)<.92 else 'paint'
    curved_shell(m,'paint',sections,lod,windows if s.details.get('transport') else None,cross_power=s.details.get('cross_power',1.),cap_start=s.engines!=1 or bool(s.details.get('propellers')),cap_end=not s.details.get('nose_intake'),circumference=(12 if lod else 30) if s.details.get('transport') else None)
    if s.details.get('cft'):
        for side in (-1,1):
            tank=Mesh()
            curved_shell(tank,'paint',[(-L*.28,cy-.26,.18,.29),(-L*.20,cy-.25,.36,.50),
                (L*.015,cy-.22,.36,.50),(L*.08,cy-.20,.18,.28)],lod,cross_power=.80)
            tank.shift((side*W*.54,0,0));merge_mesh(m,tank)
    for side in (-1,1):
        p=(side*W*.49,cy,-L*.12)
        if s.details.get('unmanned'):
            a=np.asarray(profile);surface=W*np.interp(-.12,a[:,0],a[:,2]);localcy=cy+H*np.interp(-.12,a[:,0],a[:,1])
            p=(side*(surface-.015),localcy,-L*.12)
        m.box('paint',p,(.08,H*.23,L*.05));m.box('markings',(p[0]+side*.047,p[1],p[2]),(.016,H*.17,L*.042))
    rig.add('Fuselage',rig.root,(0,0,0),m)
    if s.details.get('transport'):
        glazing=Mesh();glazing.groups['glass']=m.groups.pop('glass');rig.add('Canopy','Fuselage',(0,cy,L*.38),glazing)

def canopy(rig,s,lod):
    if s.details.get('transport') or s.details.get('unmanned'):return
    L=s.length;W=s.body_width;H=s.body_height;top=s.belly+H
    front=L*s.details.get('canopy_front',.385);rear=L*s.details.get('canopy_rear',.075 if s.seats==2 else .15);mid=(front+rear)/2
    m=Mesh();sections=[(rear,top-.10,W*.13,.10),(rear+(front-rear)*.18,top+.20,W*.28,.46),
        (mid,top+.22,W*.29,.51),(front-(front-rear)*.16,top+.12,W*.22,.40),(front,top-.04,W*.04,.07)]
    def glazing(z,theta):
        if abs(z-rear)<.06 or abs(z-front)<.06:return 'paint'
        if s.seats==2 and not s.details.get('side_by_side') and abs(z-mid)<.05:return 'paint'
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
    m.face('metal_dark',bi,[0,0,1 if front>back else -1])
    m.remove_duplicates()

def engines(rig,s,lod):
    L=s.length;W=s.body_width;H=s.body_height;cy=s.belly+H/2
    if s.details.get('propellers'):
        for i,p in enumerate(s.details['propellers']):
            m=Mesh();radius=s.details['prop_radius'];blades=s.details['prop_blades'];p=np.array(p)
            parent='Fuselage'
            if s.details.get('prop_nacelle'):
                length=s.details['prop_nacelle'];body=Mesh();x,y,z=p;r=radius*.34
                curved_shell(body,'paint',[(z-length,y,r*.35,r*.35),(z-length*.65,y,r,r),(z-length*.20,y,r,r),(z-.12,y,r*.46,r*.46)],lod,circumference=8 if lod else 24,longitudinal=3)
                body.shift((x,0,0));parent='Engine_'+str(i);rig.add(parent,'Fuselage',p-[0,0,length*.40],body)
            for angle in np.linspace(0,math.tau,blades,endpoint=False):
                blade=Mesh();reduced=len(s.details['propellers'])*blades>=10 and not lod
                chord=s.details.get('prop_chord_scale',1.)
                airfoil(blade,[(radius*.12,0,.08*chord,-.08*chord),(radius*.35,0,.15*chord,-.15*chord),(radius*.80,0,.11*chord,-.11*chord),(radius,0,.045*chord,-.045*chord)],lod,
                    span_steps=3 if reduced else None,chord_steps=6 if reduced else None)
                R=rotation([0,0,1],angle)@rotation([1,0,0],math.radians(70))
                for g in blade.groups.values():
                    g[0]=(np.asarray(g[0])@R.T+p).tolist();g[1]=(np.asarray(g[1])@R.T).tolist()
                merge_mesh(m,blade)
            sign=-1 if s.details.get('prop_pusher') else 1;shaft=s.details.get('spinner_length',.27)
            m.tube('paint',p-[0,0,sign*shaft/.27*.20],p+[0,0,sign*shaft],radius*.14,8 if lod else 24,.012)
            rig.add('Propeller' if i==0 else 'Propeller_'+str(i),parent,p,m,'Z',blade_count=blades,radius_metres=radius)
        return
    if s.details.get('turbofans'):
        radius=s.details['fan_radius'];length=s.details['fan_length']
        for i,p in enumerate(s.details['turbofans']):
            x,y,z=p;m=Mesh()
            curved_shell(m,'paint',[(z-length/2,y,radius*.66,radius*.66),(z-length*.28,y,radius*.91,radius*.91),
                (z+length*.25,y,radius,radius),(z+length/2,y,radius*.94,radius*.94)],lod,cap_start=False,cap_end=False,circumference=6 if lod else 16,longitudinal=3)
            m.shift((x,0,0));front=np.array([x,y,z+length/2]);rear=np.array([x,y,z-length/2])
            if s.details.get('supersonic_pods'):rectangular_duct(m,front[2],front[2]-length*.6,x,x,y,y,radius*1.8,radius*1.6,lod)
            else:hollow_muzzle(m,front-[0,0,.45],front,radius*.94,radius*.83,6 if lod else 24)
            hollow_muzzle(m,rear+[0,0,.25],rear,radius*.66,radius*.48,6 if lod else 24)
            for t in np.linspace(0,math.tau,0 if lod or s.details.get('supersonic_pods') else 12,endpoint=False):
                R=rotation([0,0,1],t);c=front-[0,0,.35]+R@[0,radius*.42,0]
                m.box('metal_dark',c,(radius*.07,radius*.70,.045),R)
            if not lod and not s.details.get('supersonic_pods'):m.tube('metal_dark',front-[0,0,.39],front-[0,0,.17],radius*.18,20,.015)
            if s.details.get('engine_mount_y'):
                mount=np.interp(abs(x),np.array(s.details['wing'])[:,0],np.array(s.details['wing'])[:,1])
                a=np.array([x,y+radius*.70,z]);b=np.array([x,mount,z-length*.75])
                beam(m,'paint',a,b,.22)
            if s.details.get('rear_engines'):
                beam(m,'paint',(math.copysign(s.body_width*.40,x),y,z),(x,y,z),.22)
            rig.add('Engine_'+str(i),'Fuselage',p,m)
            rig.add('Afterburner' if i==0 else 'Afterburner_'+str(i),'Engine_'+str(i),rear,frame_rotation=quat([0,1,0],math.pi),forward='-Z',afterburning=False)
        return
    for i in range(s.engines):
        x=(i-(s.engines-1)/2)*s.details.get('engine_spacing',W*.62);m=Mesh()
        radius=s.details.get('engine_radius',.43 if s.engines==2 else .51);aft=L*(.50-s.details.get('engine_aft_fraction',.50))
        if s.engines==2 and not s.details.get('square_nozzle'):
            pod=Mesh();curved_shell(pod,'paint',[(-L*.46,cy,radius,radius),(-L*.42,cy,radius*1.13,radius*1.13),
                 (-L*.15,cy,radius*1.16,radius*1.16),(L*.03,cy,radius*.90,radius*.90)],lod,cap_start=False)
            pod.shift((x,0,aft));merge_mesh(m,pod)
        if s.details.get('square_nozzle'):
            nozzle=Mesh();rectangular_duct(nozzle,-L*.50,-L*.43,x,x,cy,cy,1.23,.48,lod)
            merge_mesh(m,nozzle,roles={'paint':'metal_dark'})
        else:hollow_muzzle(m,(x,cy,-L*.46+aft),(x,cy,-L*.50+aft),radius,radius*.82,8 if lod else 24)
        rig.add('Engine_'+str(i),'Fuselage',(x,cy,-L*.43 if s.details.get('vector_nozzle') else -L*.20),m,'X' if s.details.get('vector_nozzle') else None)
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
    elif s.details.get('dorsal_intake'):
        m=Mesh();z=L*.24;top=s.belly+s.body_height
        rectangular_duct(m,z,-L*.05,0,0,top+.05,cy,1.0,.44,lod)
        rig.add('Intake_Dorsal','Fuselage',(0,top+.05,z),m)
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
            name=('Rudder' if i==0 else 'Rudder_R' if i==1 else 'Rudder_'+str(i)) if moving else 'Fin_'+str(i)
            angle=math.atan2(cut1-cut0,y1-y0)
            frame=quaternion_product(quat([0,0,1],-math.radians(cant)),quat([1,0,0],angle))
            rig.add(name,'Fuselage',(x,y0,cut0),m,'Y' if moving else None,
                    **({'frame_rotation':np.asarray(frame).tolist()} if moving else {}))
    if 'stabilator' in s.details:horizontal(rig,s,lod,'Stabilator',s.details['stabilator'])
    if 'canard' in s.details:horizontal(rig,s,lod,'Canard',s.details['canard'])

def gear(rig,s,lod):
    if s.details.get('landing_none'):return
    if s.details.get('gear_layout'):
        for spec in s.details['gear_layout']:
            name=spec['name'];x=spec['x'];z=spec['z'];r=spec.get('radius',.48);hy=spec.get('hinge_y',s.belly+.30)
            hinge=np.array([x,hy,z+.25]);axle=np.array([x,r,z]);m=Mesh();m.tube('metal_dark',hinge,axle,.09,6 if lod else 16)
            beam(m,'paint',hinge,axle+[0,0,.25],.15);rig.add(name,'Fuselage',hinge,m,spec.get('axis','X'))
            axles=spec.get('axles',1);pairs=spec.get('pairs',2)
            for j in range(axles):
                for k in range(pairs):
                    p=axle+[(k-(pairs-1)/2)*.31,0,(j-(axles-1)/2)*r*1.7];tyre=Mesh()
                    profile=[(-.11,0,'rubber'),(-.11,r*.85,'rubber'),(-.06,r,'rubber'),(.06,r,'rubber'),(.11,r*.85,'rubber'),(.11,0,'rubber')]
                    if lod:profile=[(-.11,0,'rubber'),(-.11,r,'rubber'),(.11,r,'rubber'),(.11,0,'rubber')]
                    lathe_x(tyre,profile,p,6 if lod else 12)
                    if not lod:tyre.tube('metal_dark',p+[-.115,0,0],p+[.115,0,0],r*.65,12)
                    rig.add(name+'_Wheel_'+str(j)+'_'+str(k),name,p,tyre,'X')
        return
    L=s.length;track=s.details.get('gear_track',s.span*.24);r=s.details.get('wheel_radius',.36)
    for name,x,z in [('Gear_Nose',0,L*.27),('Gear_Left',-track/2,-L*.075),('Gear_Right',track/2,-L*.075)]:
        rr=r*.77 if name=='Gear_Nose' else r;hx=x*.75
        if s.details.get('unmanned'):hx=math.copysign(min(abs(hx),s.body_width*.40),x)
        hinge=np.array([hx,s.belly+.35,z+.20]);wheel=np.array([x,rr,z])
        m=Mesh();m.tube('metal_dark',hinge,wheel,.055,6 if lod else 12)
        m.tube('paint',hinge,hinge*.35+wheel*.65,.09,6 if lod else 12)
        rig.add(name,'Fuselage',hinge,m,'X')
        tyre=Mesh();lathe_x(tyre,[(-.095,0,'rubber'),(-.095,rr*.70,'rubber'),(-.085,rr*.96,'rubber'),(-.045,rr,'rubber'),(.045,rr,'rubber'),(.085,rr*.96,'rubber'),(.095,rr*.70,'rubber'),(.095,0,'rubber')],wheel,8 if lod else 20)
        tyre.tube('metal_dark',wheel+[-.10,0,0],wheel+[.10,0,0],rr*.63,8 if lod else 16)
        rig.add(name+'_Wheel',name,wheel,tyre,'X')

def weapons(rig,s,lod):
    count=0;positions={};L=s.length;y=s.details.get('gun_y',s.belly+s.body_height*.52)
    if s.details.get('oneway'):
        p=[0,s.belly+s.body_height/2,L*.5];rig.add('Muzzle_0','Fuselage',p,purpose='forward warhead/impact reference');positions['Muzzle_0']=p;count=1
    gun=s.details.get('gun',True)
    for gi in range(s.details.get('gun_count',1) if gun else 0):
        side=(-1 if gi==0 else 1) if s.details.get('gun_count',1)==2 else s.details.get('gun_side',1)
        x=side*s.body_width*s.details.get('gun_width',.43);z=L*s.details.get('gun_fraction',.15);m=Mesh()
        if s.stealth:
            x=-abs(x);m.box('paint',(x,y,z),(.12,.13,.42))
        else:m.box('paint',(x,y,z),(.20,.20,.64))
        if s.details.get('gatling'):
            m.tube('metal_dark',(x,y,z+.25),(x,y,z+.43),.16,8 if lod else 20)
            for t in np.linspace(0,math.tau,7,endpoint=False):
                dx=.087*math.cos(t);dy=.087*math.sin(t)
                hollow_muzzle(m,(x+dx,y+dy,z+.40),(x+dx,y+dy,z+.48),.033,.022,4 if lod else 8)
        else:hollow_muzzle(m,(x,y,z+.28),(x,y,z+.48),.049,.024,6 if lod else 12)
        parent='Cannon' if gi==0 else 'Cannon_'+str(gi)
        rig.add(parent,'Fuselage',(x,y,z),m);p=[x,y,z+.48]
        rig.add('Muzzle_'+str(count),parent,p);positions['Muzzle_'+str(count)]=p;count+=1
    if s.stealth or s.details.get('internal_bomber'):
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();x=side*s.body_width*.25;m.box('paint',(x,s.belly+.06,0),(s.body_width*.44,.10,L*.18))
            rig.add('Bay_Door_'+label,'Fuselage',(side*s.body_width*.47,s.belly+.06,0),m,'Z')
            p=[x,s.belly+.17,L*.07];rig.add('Muzzle_'+str(count),'Fuselage',p);positions['Muzzle_'+str(count)]=p;count+=1
    else:
        for side,label in ((-1,'L'),(1,'R')):
            for j,f in enumerate(s.details.get('stations',(.40,.66,.89))):
                station=interpolate(s.details['wing'],s.span/2*f);x=side*station[0];yy=station[1]-.22;z=(station[2]+station[3])/2
                m=Mesh();m.box('paint',(x,yy,z),(.10,.38,.70));rig.add('Pylon_'+label+str(j),'Wing_'+label,(x,yy+.19,z),m)
                store=Mesh();length=s.details.get('store_length',1.95);radius=s.details.get('store_radius',.105)
                a=(x,yy-.30,z-length/1.95*.95);b=(x,yy-.30,z+length/1.95)
                store.tube('paint',a,b,radius,6 if lod else 12,.025 if not s.details.get('store_torpedo') else radius*.65)
                fin=s.details.get('store_fin_scale',1.)
                for sign in (-1,1):store.box('paint',(x+sign*.16*fin,yy-.30,z-length/1.95*.66),(.25*fin,.035*fin,.29*fin))
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
    if s.details.get('winglets'):
        x,yy,le,te=s.details['wing'][-1]
        for side in (-1,1):
            verts=[[side*x+dx,yv,zv] for dx in (-.035,.035) for yv,zv in [(yy,le),(yy,te),(yy+1.5,te+.5),(yy+1.5,le-.4)]]
            m.solid('paint',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    if s.details.get('lift_fan'):
        for side,label in ((-1,'L'),(1,'R')):
            door=Mesh();door.box('paint',(side*.38,y+.015,L*.08),(.74,.07,1.7))
            rig.add('Lift_Fan_Door_'+label,'Fuselage',(side*.76,y+.015,L*.08),door,'Z')
    if s.details.get('ew_pods'):
        for side,label in ((-1,'L'),(1,'R')):
            station=interpolate(s.details['wing'],s.span*.22);x=side*station[0];yy=station[1]-.70;z=(station[2]+station[3])/2
            pod=Mesh();pod.tube('paint',(x,yy,z-1.4),(x,yy,z+1.4),.23,8 if lod else 20,.13)
            pod.box('paint',(x,yy+.26,z),(.11,.37,.70))
            rig.add('Jammer_Pod_'+label,'Wing_'+label,(x,yy+.44,z),pod)
    if s.details.get('unmanned'):
        if s.details.get('nose_hump'):
            hump=Mesh();cy=y-.10;W=s.body_width
            curved_shell(hump,'paint',[(L*.12,cy,W*.12,.08),(L*.20,cy+.10,W*.42,.30),(L*.31,cy+.08,W*.36,.27),(L*.39,cy-.05,W*.08,.06)],lod,circumference=8 if lod else 24,longitudinal=3)
            merge_mesh(m,hump)
        if s.details.get('sensor_turret',True):
            p=np.array([0,s.belly-.12,L*.28]);optic=Mesh()
            optic.tube('paint',p-[0,.14,0],p+[0,.14,0],min(W*.25,.23),8 if lod else 20)
            optic.tube('glass',p+[0,0,.12],p+[0,0,.19],min(W*.17,.14),8 if lod else 20)
            rig.add('Sensor_Turret','Fuselage',p,optic,'Y')
        for side,label in ((-1,'L'),(1,'R')):
            if s.details.get('twin_boom'):
                x=side*s.details['boom_x'];yy=s.details['boom_y'];boom=Mesh()
                beam(boom,'paint',(x,yy,-L*.02),(x,yy,-L*.46),.10)
                wing=interpolate(s.details['wing'],abs(x));beam(boom,'paint',(x,yy,-L*.02),(x,wing[1],-L*.02),.10)
                rig.add('Tail_Boom_'+label,'Fuselage',(x,yy,-L*.02),boom)
        if s.details.get('h_tail'):
            m.box('paint',(0,s.details['boom_y']+.05,-L*.455),(.12,.08,L*.07))
        if s.details.get('ventral_fin'):
            cy=s.belly+s.body_height/2
            verts=[[dx,yy,zz] for dx in (-.035,.035) for yy,zz in [(cy-.1,-L*.35),(cy-.1,-L*.465),(max(.20,cy-.95),-L*.45)]]
            m.solid('paint',verts,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)])
    # Dorsal blades are supported by the skin, with no free-floating fittings.
    for z,h in (() if s.details.get('oneway') else ((L*.04,.23),(-L*.19,.18))):
        base=y-.06
        if s.details.get('unmanned'):
            a=np.asarray(s.details['profile']);local=s.belly+s.body_height/2+s.body_height*np.interp(z/L,a[:,0],a[:,1]+a[:,3])
            base=min(base,local-.06)
        m.box('paint',(0,base+h/2,z),(.045,h,.28))
    if any(g[0] for g in m.groups.values()):rig.add('Airframe_Fittings','Fuselage',(0,y,0),m)

def build(s,lod=0):
    if s.details.get('multirotor'):return build_multirotor(s,lod)
    if s.details.get('cruciform'):return build_cruciform(s,lod)
    rig=Rig(lod);fuselage(rig,s,lod);wings(rig,s,lod);canopy(rig,s,lod);engines(rig,s,lod)
    tails(rig,s,lod);gear(rig,s,lod);weapons(rig,s,lod);fittings(rig,s,lod);radar(rig,s,lod)
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    if s.details.get('oneway'):ground_rig(rig,s)
    return rig,s

def ground_rig(rig,s):
    if s.details.get('oneway'):
        low=min(float(np.asarray(g[0])[:,1].min()) for p in rig.parts if p['mesh'] is not None for g in p['mesh'].groups.values() if g[0])
        shift=math.floor(low*1000+1e-4)/1000
        for p in rig.parts:
            if p['name']!='Fuselage':p['pivot'][1]-=shift
            if p['mesh'] is not None:p['mesh'].shift((0,-shift,0))
        for name,pivot in rig.pivots.items():
            if name!='Fuselage':pivot[1]-=shift
        s.belly-=shift;s.details['ground_shift_metres']=shift
        s.details['wing']=[[x,y-shift,le,te] for x,y,le,te in s.details['wing']]
        s.details['fins']=[[x,y0-shift,y1-shift,*rest] for x,y0,y1,*rest in s.details['fins']]
        s.details['propellers']=[[x,y-shift,z] for x,y,z in s.details.get('propellers',[])]
        for p in s.details['muzzle_positions'].values():p[1]-=shift

def build_cruciform(s,lod):
    rig=Rig(lod);fuselage(rig,s,lod);engines(rig,s,lod);cy=s.belly+s.body_height/2;L=s.length;S=s.span
    for bank in (0,1):
        radius=S/math.sqrt(2)*(1 if bank==0 else s.details.get('rear_span_ratio',.65))
        z=L*s.details.get('front_bank',.12) if bank==0 else -L*.31
        chord=L*(.17 if bank==0 else .11)
        for j in range(4):
            angle=math.pi/4+j*math.pi/2;R=rotation([0,0,1],angle)
            for moving in (False,True):
                m=Mesh();le=z+chord*.5 if not moving else z-chord*.26-.004;te=z-chord*.26+.004 if not moving else z-chord*.5
                airfoil(m,[(s.body_width*.38,0,le,te),(radius,0,le-chord*.16,te-chord*.12)],lod)
                for g in m.groups.values():g[0]=(np.asarray(g[0])@R.T+[0,cy,0]).tolist();g[1]=(np.asarray(g[1])@R.T).tolist()
                if not moving:name='Wing_Plane_'+str(bank)+'_'+str(j)
                elif bank==0:name=('Flap_L','Flap_R','Aileron_L','Aileron_R')[j]
                else:name='Rudder' if j==0 else 'Tail_Control_'+str(j)
                p=R@np.array([s.body_width*.38,0,0])+[0,cy,z-chord*.26]
                rig.add(name,'Fuselage',p,m,'X' if moving else None,**({'frame_rotation':quat([0,0,1],angle)} if moving else {}))
    optics=Mesh();p=np.array([0,cy,L*.5]);optics.tube('glass',p+[0,0,.001],p+[0,0,.012],s.body_width*.32,8 if lod else 24)
    rig.add('Nose_Seeker','Fuselage',p,optics);weapons(rig,s,lod)
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    ground_rig(rig,s);return rig,s

def build_multirotor(s,lod):
    rig=Rig(lod);d=s.details;L=s.length;cy=s.belly+s.body_height/2;m=Mesh()
    m.box('paint',(0,cy,0),(s.body_width,s.body_height,L*.36))
    small=d.get('small',False)
    m.box('metal_dark',(0,cy+(.05 if small else .10),0),(s.body_width*.75,.08 if small else .16,L*.28))
    m.box('markings',(s.body_width/2+.006,cy,0),(.012,s.body_height*.58,L*.16))
    rig.add('Fuselage',rig.root,(0,0,0),m)
    for i,p in enumerate(d['propellers']):
        p=np.asarray(p);arm=Mesh();beam(arm,'metal_dark',(0,cy,0),p-[0,.065,0],.045 if d['motors']==4 else .065)
        arm.tube('metal_dark',p-[0,.11,0],p,.030 if small else .055 if d['motors']==4 else .085,8 if lod else 20)
        parent='Motor_'+str(i);rig.add(parent,'Fuselage',p,arm)
        rotor=Mesh();r=d['prop_radius']
        for angle in np.linspace(0,math.tau,d['prop_blades'],endpoint=False):
            blade=Mesh();airfoil(blade,[(r*.14,0,r*.06,-r*.06),(r*.35,0,r*.08,-r*.08),(r*.82,0,r*.06,-r*.06),(r,0,r*.025,-r*.025)],lod,span_steps=1 if lod else 3)
            R=rotation([0,1,0],angle)
            for g in blade.groups.values():g[0]=(np.asarray(g[0])@R.T+p).tolist();g[1]=(np.asarray(g[1])@R.T).tolist()
            merge_mesh(rotor,blade)
        rotor.tube('metal_dark',p-[0,.025,0],p+[0,.025,0],r*.14,8 if lod else 20)
        rig.add('Propeller' if i==0 else 'Propeller_'+str(i),parent,p,rotor,'Z',
            frame_rotation=quat([1,0,0],-math.pi/2),blade_count=d['prop_blades'],radius_metres=d['prop_radius'])
    skid=Mesh()
    for side in (-1,1):
        x=side*s.body_width*.8
        for z in (-L*.18,L*.18):beam(skid,'metal_dark',(side*s.body_width*.35,cy-.05,z),(x,.025,z),.025)
        skid.tube('rubber',(x,.025,-L*.27),(x,.025,L*.27),.025,6 if lod else 12)
    rig.add('Skid','Fuselage',(0,s.belly,0),skid)
    camera=Mesh();p=np.array([0,cy,L*.20])
    camera.tube('paint',p,p+[0,0,.11],s.body_width*.20,8 if lod else 20)
    camera.tube('glass',p+[0,0,.115],p+[0,0,.13],s.body_width*.15,8 if lod else 20)
    rig.add('Camera','Fuselage',p,camera,'X')
    count=d.get('payload_count',1);positions={}
    for j in range(count):
        p=np.array([(j-(count-1)/2)*s.body_width*.28,max(.16,s.belly-.04),0]);payload=Mesh()
        if d.get('bomber'):
            if count>1:
                payload.tube('paint',p+[0,.16,0],p-[0,.19,0],.067,8 if lod else 20,.02)
                payload.box('metal_dark',p+[0,.12,0],(.20,.035,.08));muzzle=p-[0,.19,0]
            else:
                payload.tube('paint',p-[0,0,L*.17],p+[0,0,L*.17],s.body_width*.22,8 if lod else 20,.04);muzzle=p+[0,-s.body_width*.22,0]
            rig.add('Payload_Release' if count==1 else 'Payload_Release_'+str(j),'Fuselage',p,payload,'X')
        else:
            if d.get('round_payload'):
                p=np.array([0,s.belly-.01,0]);payload.tube('paint',p+[0,.08,0],p-[0,.10,0],s.body_width*.40,8 if lod else 24)
                muzzle=p+[0,0,s.body_width*.40]
            else:
                p=np.array([0,cy,L*.25]);payload.tube('paint',p,p+[0,0,L*.18],s.body_width*.22,8 if lod else 20,.02);muzzle=p+[0,0,L*.18]
            rig.add('Payload','Fuselage',p,payload)
        rig.add('Muzzle_'+str(j),'Fuselage',muzzle,**({'frame_rotation':quat([1,0,0],math.pi/2)} if d.get('bomber') else {}));positions['Muzzle_'+str(j)]=muzzle.tolist()
    d['muzzle_count']=count;d['muzzle_positions']=positions
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    return rig,s

def radar(rig,s,lod):
    if s.details.get('aesa_bar'):
        d=s.details['aesa_bar'];y=d['y'];z=d['z'];length=d['length'];width=d['width'];h=d['height'];m=Mesh()
        if d.get('top_hat'):
            m.box('paint',(0,(s.belly+s.body_height+y)/2,z),(.70,y-s.belly-s.body_height,length*.78))
            curved_shell(m,'paint',[(z-length/2,y,width*.08,h*.15),(z-length*.42,y,width/2,h/2),
                (z+length*.42,y,width/2,h/2),(z+length/2,y,width*.08,h*.15)],lod,circumference=8 if lod else 20,longitudinal=3)
        else:
            m.box('paint',(0,y,z),(width,h,length))
            for zz in (z-length*.27,z+length*.27):m.box('paint',(0,(y-h/2+s.belly+s.body_height)/2,zz),(.35,y-h/2-s.belly-s.body_height,.55))
        rig.add('Radar_AESA','Fuselage',(0,y,z),m,scan='electronic; static exterior')
    if s.details.get('conformal_radar'):
        m=Mesh();L=s.length;W=s.body_width;cy=s.belly+s.body_height*.52
        for side in (-1,1):
            pod=Mesh();curved_shell(pod,'paint',[(-L*.22,cy,.10,.16),(-L*.16,cy,.28,.45),(L*.12,cy,.28,.45),(L*.21,cy,.10,.16)],lod,circumference=8 if lod else 24,longitudinal=3)
            pod.shift((side*W*.46,0,0));merge_mesh(m,pod)
        rig.add('Radar_Conformal','Fuselage',(0,cy,0),m,scan='electronic; static exterior')
    if s.details.get('belly_radar'):
        x,y,z,rx,ry,half=s.details['belly_radar'];m=Mesh()
        curved_shell(m,'paint',[(z-half,y,rx*.10,ry*.10),(z-half*.55,y,rx*.86,ry*.86),(z,y,rx,ry),(z+half*.55,y,rx*.86,ry*.86),(z+half,y,rx*.10,ry*.10)],lod,circumference=8 if lod else 24,longitudinal=3)
        m.shift((x,0,0));rig.add('Radar_Belly','Fuselage',(x,y,z),m)
    if s.details.get('novella_array'):
        y=s.belly+s.body_height;z=s.length*.26;m=Mesh()
        for x in (-.62,.62):beam(m,'paint',(x,y-.15,z),(x,y+1.35,z),.12)
        for side in (-1,1):
            m.box('paint',(0,y+1.45,z+side*.85),(1.8,.65,.08))
            m.box('paint',(side*.85,y+1.45,z),(.08,.65,1.8))
        rig.add('Novella_Sensor_Array','Fuselage',(0,y,z),m)
    d=s.details.get('radome')
    if not d:return
    x,y,z,rx,rz,h=d;m=Mesh();rings=[];n=8 if lod else 32
    for yy,r in [(-h*.5,.12),(-h*.35,.80),(0,1),(h*.35,.80),(h*.5,.12)]:
        rings.append(np.array([[x+rx*r*math.cos(t),y+yy,z+rz*r*math.sin(t)] for t in np.linspace(0,math.tau,n,endpoint=False)]))
    m.face('paint',rings[0],[0,-1,0]);m.face('paint',rings[-1],[0,1,0])
    for a,b in zip(rings,rings[1:]):
        for j in range(n):
            k=(j+1)%n;q=[a[j],a[k],b[k],b[j]];m.face('paint',q,np.mean(q,axis=0)-[x,y,z])
    support=Mesh()
    for side in (-1,1):
        xx=side*.60;bottom=s.belly+s.body_height-.20;top=y-h*.35;c=min(2.4,s.length*.07)
        verts=[[xx+dx,yy,z+dz] for yy,chord in [(bottom,c),(top,c*.62)] for dx,dz in [(-.15,-chord/2),(.15,-chord/2),(.15,chord/2),(-.15,chord/2)]]
        support.solid('paint',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    rig.add('Radar_Support','Fuselage',(0,s.belly+s.body_height,z),support)
    rig.add('Radar_AESA_Disc' if s.details.get('radome_static') else 'Rotodome','Fuselage',(x,y,z),m,None if s.details.get('radome_static') else 'Y')
