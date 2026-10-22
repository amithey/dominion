"""Original helicopter surfaces, rotors and landing gear, in metres.

Airframes use their own dimensions and profiles. Rotor discs are real blades,
not alpha planes. Canted tail rotors retain an X-axis hinge in a local frame.
"""
from dataclasses import dataclass,field
import math
import numpy as np
from generate_buildings import unit
from vehicle_parts import Mesh,Rig,rotation,merge_mesh,lathe_x
from generate_p1_tanks import beam

@dataclass
class HelicopterSpec:
    slug:str
    name:str
    family:str
    length:float
    width:float
    body_height:float
    belly:float
    hub_y:float
    hub_z:float
    rotor_diameter:float
    blades:int
    tail_diameter:float
    tail_blades:int
    gear:str
    source:str
    engines:int=2
    tail_side:int=1
    tail_cant:float=0
    naval:bool=False
    attack:bool=False
    approximate:bool=False
    representative:str=''
    features:list=field(default_factory=list)
    details:dict=field(default_factory=dict)

def shell_surface(m,role,sections,lod=0,window=None):
    """Closed longitudinal elliptical shell; explicit radial face orientation.

    Sections are z, centre-Y, half-width, half-height. Individual planar faces
    receive orthonormal metre UVs; a window changes only the surface material.
    """
    samples=[]
    for a,b in zip(sections,sections[1:]):
        for t in np.linspace(0,1,1 if lod else 4,endpoint=False):samples.append(np.array(a)*(1-t)+np.array(b)*t)
    samples.append(np.array(sections[-1]));n=12 if lod else 48
    def ring(s):
        z,y,w,h=s
        return np.array([[w*math.sin(t),y+h*math.cos(t),z] for t in np.linspace(0,math.tau,n,endpoint=False)])
    rings=[ring(s) for s in samples]
    m.face(role,rings[0],[0,0,-1]);m.face(role,rings[-1],[0,0,1])
    for j,(a,b) in enumerate(zip(rings,rings[1:])):
        for i in range(n):
            k=(i+1)%n;theta=(i+.5)*math.tau/n;q=[a[i],a[k],b[k],b[i]]
            centre=np.mean(q,axis=0);out=centre-np.array([0,(samples[j][1]+samples[j+1][1])/2,centre[2]])
            selected=window(float(centre[2]),theta) if window else role
            m.face(selected,q,out)

def body(rig,s,lod):
    m=Mesh();L=s.length;W=s.width;H=s.body_height;b=s.belly;cy=b+H/2
    broad=s.family in ('mi8','mi17','mi26','chinook','ka27','z8')
    attack=s.attack or s.family=='oh1'
    # Mi-24 has a genuine passenger cabin behind its tandem cockpit.
    end=-.25 if s.family=='mi24' else -.17 if broad else -.12
    nose=.41 if s.family in ('blackhawk','z20','surion','nh90','apache','tiger','z10') else .44
    sections=[(end*L,cy+.10,W*.22,H*.28),(-L*.10,cy,W*.43,H*.46),
              (L*.04,cy,W*.50,H*.50),(L*.23,cy,W*.50,H*.50),
              (L*nose,cy-.06,W*.30,H*.37),(L*.49,cy-H*.16,W*.09,H*.15),
              (L*.50,cy-H*.19,W*.035,H*.055)]
    if s.family=='chinook':
        sections=[(-L*.5,cy+.20,W*.24,H*.31),(-L*.40,cy,W*.47,H*.48),
                  (L*.15,cy,W*.50,H*.50),(L*.37,cy,W*.46,H*.49),
                  (L*.47,cy-H*.10,W*.27,H*.34),(L*.50,cy-H*.18,W*.06,H*.12)]
    if attack:
        # Tandem stepped canopy, not a transport's broad cabin roof.
        sections=[(end*L,cy,W*.25,H*.33),(-L*.05,cy,W*.49,H*.46),
                  (L*.12,cy+.13,W*.50,H*.53),(L*.23,cy+.03,W*.44,H*.48),
                  (L*.34,cy-.13,W*.39,H*.42),(L*.45,cy-H*.20,W*.24,H*.28),
                  (L*.50,cy-H*.27,W*.06,H*.075)]
    if 'profile' in s.details:
        sections=[(z*L,cy+dy*H,wx*W,hy*H) for z,dy,wx,hy in s.details['profile']]
    def windows(z,theta):
        upper=math.cos(theta)>.08
        if z>L*.30 and z<L*.455 and upper and .18<theta<math.tau-.18:return 'glass'
        if attack and L*.10<z<L*.34 and upper and .36<theta<math.tau-.36:
            if abs(z-L*.225)>L*.014:return 'glass'
        if not attack and s.family not in ('mi8','mi17','mi26'):
            side=abs(math.sin(theta))>.91 and math.cos(theta)>.0
            if side and any(abs(z-q*L)<L*.028 for q in s.details.get('window_z',(-.055,.045,.14,.22))):return 'glass'
        return 'paint'
    shell_surface(m,'paint',sections,lod,windows)
    # Tail boom is tapered separately, joined inside the upper rear cabin.
    ty=s.details.get('tail_y',s.hub_y-.35);tz=-L*.465
    if s.family!='chinook':
        start=L*s.details.get('boom_start',-.10);sy=cy+H*.23
        shell_surface(m,'paint',[(tz,ty,W*.065,H*.07),(-L*.33,(ty+sy)/2,W*.12,H*.14),(start,sy,W*.30,H*.28)],lod)
    if s.family in ('mi8','mi17','mi26'):
        count=5 if s.family!='mi26' else 8
        for side in (-1,1):
            for z in np.linspace(L*.095,L*.34,count):
                x=side*(W*.5+.010);rad=.20 if s.family!='mi26' else .26
                m.tube('metal_dark',(x-side*.025,cy+.12,z),(x+side*.035,cy+.12,z),rad+.045,8 if lod else 20)
                m.tube('glass',(x+side*.036,cy+.12,z),(x+side*.047,cy+.12,z),rad,8 if lod else 20)
    # Static fins and tailplane are physical closed wedges.
    if s.family not in ('chinook','ka27','ka52'):
        finx=.06;finH=max(.70,s.tail_diameter*.50)
        verts=[(-finx,ty-.35,tz+.85),(finx,ty-.35,tz+.85),(-finx,ty+finH,tz-.12),
               (finx,ty+finH,tz-.12),(-finx,ty+finH*.85,tz-.61),(finx,ty+finH*.85,tz-.61),
               (-finx,ty-.32,tz-.54),(finx,ty-.32,tz-.54)]
        m.solid('paint',verts,[(0,2,4,6),(1,7,5,3),(0,1,3,2),(2,3,5,4),(4,5,7,6),(6,7,1,0)])
        m.box('paint',(0,ty-.30,tz+L*.11),(W*1.55,.09,L*.075))
    elif s.family in ('ka27','ka52'):
        for side in (-1,1):
            m.box('paint',(side*W*.58,ty+.25,tz+.75),(.095,1.05,1.30))
        m.box('paint',(0,ty-.20,tz+.75),(W*1.35,.095,1.20))
    if s.family in ('mi8','mi17','z8','chinook'):
        for side in (-1,1):
            pod=Mesh();pz=L*.20 if s.family in ('mi8','mi17') else -L*.01;py=b+H*.23
            shell_surface(pod,'paint',[(pz-L*.20,py,W*.12,H*.12),(pz-L*.15,py,W*.19,H*.18),
                         (pz+L*.12,py,W*.19,H*.18),(pz+L*.17,py,W*.10,H*.10)],lod)
            pod.shift((side*W*.47,0,0));merge_mesh(m,pod)
    for side in (-1,1):
        # Supported blank identification panels and side access handles.
        mz=L*s.details.get('mark_z',.15)
        pw=float(np.interp(mz,np.asarray(sections)[:,0],np.asarray(sections)[:,2]))
        p=(side*(pw+.018),cy,mz)
        m.box('paint',p,(.07,H*.23,L*.055));m.box('markings',(p[0]+side*.044,cy,p[2]),(.016,H*.18,L*.045))
        if not lod:
            for z in (L*.12,L*.25):
                pw=float(np.interp(z,np.asarray(sections)[:,0],np.asarray(sections)[:,2]))
                m.box('metal_dark',(side*(pw+.015),cy-.25,z),(.05,.045,.20))
    rig.add('Fuselage',rig.root,(0,0,0),m)
    return cy,ty,tz

def engines(rig,s,lod,cy):
    for i in range(s.engines):
        m=Mesh();x=(i-(s.engines-1)/2)*s.width*.45
        ez=-s.length*.34 if s.family=='chinook' else s.length*.04
        ey=cy+s.body_height*.48 if s.family!='chinook' else s.hub_y+.25
        length=s.length*.17;rad=s.width*.19
        if s.engines==3:
            x=(-s.width*.23,s.width*.23,0)[i]
            ez=s.length*(.05 if i<2 else -.13);rad=s.width*.16
        shell_surface(m,'paint',[(ez-length*.55,ey,rad*.55,rad*.63),
             (ez-length*.35,ey,rad,rad),(ez+length*.38,ey,rad,rad),
             (ez+length*.55,ey,rad*.78,rad*.78)],lod)
        m.shift((x,0,0))
        m.tube('metal_dark',(x,ey,ez+length*.55),(x,ey,ez+length*.56),rad*.71,8 if lod else 24)
        m.tube('metal_dark',(x,ey,ez-length*.55),(x,ey,ez-length*.64),rad*.42,8 if lod else 16)
        rig.add('Engine_'+str(i),'Fuselage',(x,ey,ez),m)
        rig.add('Exhaust_'+str(i),'Fuselage',(x,ey,ez-length*.64))

def rotor_mesh(radius,blades,lod,chord=None,phase=0):
    m=Mesh();chord=chord or max(.22,radius*.059);n=8 if lod else 24
    m.tube('metal_dark',(0,-.17,0),(0,.16,0),max(.12,radius*.038),n)
    for i in range(blades):
        R=rotation([0,1,0],i*math.tau/blades+phase);blade=Mesh();rings=[]
        radii=np.linspace(radius*.12,radius,4 if lod else 20)
        for rr in radii:
            f=rr/radius;c=chord*(.95 if f<.82 else max(.42,1-(f-.82)*2.8));sweep=-radius*.045*max(0,(f-.80)/.20)
            profile=[(-.5,0),(-.32,.075),(.23,.045),(.5,0),(.20,-.032),(-.33,-.035)]
            rings.append(np.array([[rr,h*c,sweep+z*c] for z,h in profile]))
        # Independent cells handle the real twist/swept tip without convex loft assumptions.
        blade.face('metal_dark',rings[0],[-1,0,0]);blade.face('metal_dark',rings[-1],[1,0,0])
        for a,b in zip(rings,rings[1:]):
            mid=(a.mean(0)+b.mean(0))/2
            for j in range(6):
                k=(j+1)%6;q=[a[j],a[k],b[k],b[j]]
                blade.face('paint',q,np.mean(q,axis=0)-mid)
        beam(blade,'metal_dark',(radius*.02,0,0),(radius*.16,0,0),max(.035,chord*.16))
        if not lod:
            beam(blade,'metal_dark',(radius*.045,-.14,chord*.13),(radius*.12,0,chord*.13),.028)
        merge_mesh(m,blade,R)
    return m

def rotors(rig,s,lod,ty,tz):
    hubs=[('Rotor_Main',(0,s.hub_y,s.hub_z),0)]
    if s.family=='chinook':hubs.append(('Rotor_Main_Aft',(0,s.hub_y+1.12,-s.length*.36),math.pi/3))
    elif s.family in ('ka27','ka52'):
        hubs.append(('Rotor_Main_Upper',(0,s.hub_y+.72,s.hub_z),math.pi/3))
    for name,p,phase in hubs:
        m=rotor_mesh(s.rotor_diameter/2,s.blades,lod,phase=phase);m.shift(p)
        rig.add(name,'Fuselage',p,m,'Y',blade_count=s.blades,diameter_metres=s.rotor_diameter,
                spin_sign=-1 if name in ('Rotor_Main_Aft','Rotor_Main_Upper') else 1)
        mast=Mesh();mast.tube('metal_dark',(p[0],p[1]-.62,p[2]),(p[0],p[1]-.15,p[2]),max(.10,s.width*.045),6 if lod else 16)
        rig.add(name+'_Mast','Fuselage',(p[0],p[1]-.62,p[2]),mast)
    if s.tail_blades:
        p=np.array([s.tail_side*s.width*.12,ty,tz]);cant=math.radians(s.tail_cant)
        m=rotor_mesh(s.tail_diameter/2,s.tail_blades,lod,chord=max(.10,s.tail_diameter*.045))
        posed=Mesh();merge_mesh(posed,m,rotation([0,0,1],cant-math.pi/2),p)
        q=[0,0,math.sin(cant/2),math.cos(cant/2)]
        rig.add('Rotor_Tail','Fuselage',p,posed,'X',frame_rotation=q,blade_count=s.tail_blades,diameter_metres=s.tail_diameter)

def landing_gear(rig,s,lod):
    L=s.length;W=s.width;b=s.belly;H=s.body_height
    if s.gear=='skid':
        m=Mesh();sx=W*.62
        for side in (-1,1):
            for z in (L*.02,L*.23):beam(m,'metal_dark',(side*W*.32,b+.20,z),(side*sx,.15,z),.075)
            m.tube('metal_dark',(side*sx,.075,-L*.10),(side*sx,.075,L*.28),.075,6 if lod else 12)
            beam(m,'metal_dark',(side*sx,.075,L*.28),(side*sx,.32,L*.34),.11)
        rig.add('Skid','Fuselage',(0,b,L*.10),m)
        return
    radius=s.details.get('wheel_radius',.27 if L<18 else .39)
    if s.family=='mi26':radius=.66
    if s.gear=='tailwheel':
        positions=[('Left',-W*.65,L*.12),('Right',W*.65,L*.12),('Tail',0,-L*.42)]
    elif s.gear=='four':
        positions=[('Left',-W*.56,L*.29),('Right',W*.56,L*.29),('Left_Aft',-W*.56,-L*.30),('Right_Aft',W*.56,-L*.30)]
    else:
        main_z=L*s.details.get('main_gear_z',-.08)
        positions=[('Left',-W*.63,main_z),('Right',W*.63,main_z),('Nose',0,L*.36)]
    for label,x,z in positions:
        rr=radius*.65 if label=='Tail' else radius*.77 if label=='Nose' else radius
        p=np.array([x*.65,b+H*.22,z]);m=Mesh();axle=np.array([x,rr,z])
        beam(m,'paint',p,axle+[0,.09,0],max(.075,rr*.22))
        m.tube('metal_dark',p*.55+(axle+[0,.09,0])*.45,axle+[0,.09,0],max(.035,rr*.12),6 if lod else 12)
        rig.add('Gear_'+label,'Fuselage',p,m,'X' if s.family in ('nh90','h225','merlin','mi24','ka52','panther') else None)
        tyre=Mesh();half=rr*.33
        lathe_x(tyre,[(-half,0,'metal_dark'),(-half,rr*.68,'rubber'),(-half*.65,rr,'rubber'),
                   (half*.65,rr,'rubber'),(half,rr*.68,'metal_dark'),(half,0,'metal_dark')],segments=8 if lod else 20)
        tyre.shift(axle);rig.add('Wheel_'+label,'Gear_'+label,axle,tyre,'X')

def burnt_wreck(rig,s):
    m=Mesh()
    for part in rig.parts:
        if part['mesh'] is None:continue
        merge_mesh(m,part['mesh'],roles={'paint':'metal_dark','glass':'metal_dark','markings':'metal_dark'})
    m.remove_duplicates();return m

def build(s,lod=0):
    rig=Rig(lod);cy,ty,tz=body(rig,s,lod)
    engines(rig,s,lod,cy);rotors(rig,s,lod,ty,tz);landing_gear(rig,s,lod)
    if s.family=='merlin':
        p=np.array([0,cy-s.body_height*.275,-s.length*.17-.04]);ramp=Mesh()
        ramp.box('paint',p+[0,s.body_height*.275,0],(s.width*.50,s.body_height*.55,.06))
        if not lod:
            for yy in np.linspace(.10,s.body_height*.50,7):ramp.box('metal_dark',p+[0,yy,-.038],(s.width*.43,.035,.018))
        rig.add('Cargo_Ramp','Fuselage',p,ramp,'X')
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    return rig,s
