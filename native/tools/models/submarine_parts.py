"""Original class-specific submarine exteriors with real local shaft pivots."""
import math
import numpy as np
from aircraft_parts import curved_shell,airfoil,quat
from ship_parts import block,beam
from vehicle_parts import Mesh,Rig,merge_mesh,rotation

def submarine(s,lod=0):
    d=s.details;L=s.length;B=s.beam;cy=B*.5;rig=Rig(lod);hull=Mesh()
    profile=d.get('body_profile',[(-.45,.07),(-.38,.27),(-.26,.45),(-.1,.5),(.15,.5),(.32,.47),(.43,.34),(.48,.17),(.5,.006)])
    curved_shell(hull,'paint',[(z*L,cy,B*r,B*r) for z,r in profile],lod,circumference=12 if lod else 48,longitudinal=1 if lod else 8)
    rig.add('Hull',rig.root,(0,0,0),hull)
    rig.add('Wake_Bow','Hull',(0,s.draft,L*.49),waterline_y=s.draft)
    rig.add('Wake_Stern','Hull',(0,s.draft,-L*.49),waterline_y=s.draft)
    z=d.get('sail_z',.08)*L;length=d.get('sail_length',L*.15);h=d.get('sail_height',B*.7);base=B*.92
    sail=Mesh()
    if d.get('faceted_sail'):block(sail,'paint',0,base,z,B*.28,h,length,.50)
    else:
        curved_shell(sail,'paint',[(z-length*.5,base+h*.5,B*.025,h*.35),(z-length*.35,base+h*.5,B*.13,h*.5),
            (z+length*.30,base+h*.5,B*.14,h*.5),(z+length*.5,base+h*.5,B*.03,h*.35)],lod,circumference=8 if lod else 24,longitudinal=1 if lod else 4)
    rig.add('Sail','Hull',(0,base,z),sail)
    top=base+h;fittings=Mesh()
    for i in range(4):
        zz=z+(i-1.5)*length*.14;p=np.array([0,top-.2,zz]);m=Mesh()
        m.tube('metal_dark',p,p+[0,B*.30,0],B*.012,6 if lod else 12)
        m.box('glass',p+[0,B*.30,0],(B*.06,B*.04,B*.08))
        rig.add('Periscope_'+str(i),'Sail',p,m,travel_axis='Y')
    # One real retractable surface-search radar mast and rotating head.
    p=np.array([0,top-.15,z-length*.28]);mast=Mesh();mast.tube('metal_dark',p,p+[0,B*.23,0],B*.018,6 if lod else 12)
    rig.add('Mast_0','Sail',p,mast,travel_axis='Y');head=Mesh();q=p+[0,B*.23,0]
    head.box('metal_dark',q,(B*.16,B*.05,B*.04));rig.add('Radar','Mast_0',q,head,'Y')
    for side in (-1,1):
        fittings.box('markings',(side*B*.14,base+h*.46,z),(B*.012,h*.18,length*.22))
    rig.add('Sail_Fittings','Sail',(0,base,z),fittings)
    if d.get('missile_cells'):
        deck=Mesh();count=d['missile_cells'];pitch=d.get('missile_pitch',L*.028);start=d.get('missile_start',z-length*.70)
        rows=math.ceil(count/2);roof=B*(.88+d.get('missile_deck_height',.18))
        block(deck,'paint',0,B*.88,start-(rows-1)*pitch/2,B*.70,roof-B*.88,rows*pitch,.96)
        for i in range(count):
            x=(-1 if i%2==0 else 1)*B*.20;zz=start-(i//2)*pitch;yy=roof+.025
            deck.tube('metal_dark',(x,yy-.04,zz),(x,yy+.04,zz),B*d.get('missile_radius',.105),8 if lod else 20)
        rig.add('Missile_Deck_Hatches','Hull',(0,B,start),deck,cell_count=count)
    # Stern diving surfaces: X-tail variants rotate their local span frames.
    angles=(45,135,225,315) if d.get('x_tail') else (0,90,180,270)
    for i,degrees in enumerate(angles):
        a=math.radians(degrees);R=rotation([0,0,1],a);p=np.array([0,cy,-L*.405]);m=Mesh()
        airfoil(m,[(B*.06,0,L*.025,-L*.035),(B*.24,0,L*.015,-L*.031),(B*.47,0,-L*.004,-L*.025)],lod,span_steps=1 if lod else 5)
        localpivot=np.array([B*.08,0,-L*.012]);worldpivot=p+R@localpivot
        transformed=Mesh();merge_mesh(transformed,m,R,p)
        rig.add('Tail_Control_'+str(i),'Hull',worldpivot,transformed,'X',frame_rotation=quat([0,0,1],a))
    planes=d.get('foreplanes','bow')
    if planes!='none':
        y=base+h*.42 if planes=='sail' else cy;zz=z if planes=='sail' else L*.26
        root=B*.10 if planes=='sail' else B*.38
        for side,label in ((-1,'L'),(1,'R')):
            m=Mesh();airfoil(m,[(root,0,L*.018,-L*.018),(B*.78,0,0,-L*.014)],lod,span_steps=1 if lod else 6)
            R=rotation([0,0,1],math.pi if side<0 else 0);mesh=Mesh();merge_mesh(mesh,m,R,(0,y,zz))
            rig.add('DivePlane_'+label,'Hull',(side*root,y,zz),mesh,'X')
    count=d.get('propellers',1);r=B*d.get('prop_radius',.31)
    for i in range(count):
        p=np.array([(i-(count-1)/2)*B*.62,cy,-L*.482]);m=Mesh()
        shaft=Mesh();a=np.array([p[0]*.65,cy,-L*(.40 if count>1 else .435)])
        shaft.tube('metal_dark',a,p+[0,0,.12],B*.055,8 if lod else 24,B*.035)
        rig.add('Propeller_Shaft_'+str(i),'Hull',a,shaft)
        m.tube('metal_dark',p+[0,0,.45],p-[0,0,.38],r*.21,8 if lod else 24,r*.035)
        blades=d.get('prop_blades',7)
        for a in np.linspace(0,math.tau,blades,endpoint=False):
            blade=Mesh();airfoil(blade,[(r*.16,0,r*.13,-r*.13),(r*.48,0,r*.19,-r*.10),(r*.86,0,r*.12,-r*.09),(r,0,r*.025,-r*.025)],lod,role='metal_dark',span_steps=1 if lod else 3,chord_steps=4 if lod else 8)
            R=rotation([0,0,1],a)@rotation([1,0,0],math.radians(65));merge_mesh(m,blade,R,p)
        rig.add('Propeller' if i==0 else 'Propeller_'+str(i),'Hull',p,m,'Z',blade_count=blades,radius_metres=r)
        if d.get('pumpjet'):
            duct=Mesh();n=12 if lod else 32;ra=r*1.05;inside=r*.97
            # Open annular shroud, with explicit inside wall and two end rings.
            for j in range(n):
                a=j*math.tau/n;b=(j+1)*math.tau/n
                def v(rad,z,t):return p+np.array([rad*math.cos(t),rad*math.sin(t),z])
                for rad,normal in ((ra,1),(inside,-1)):
                    duct.face('metal_dark',[v(rad,-.5,a),v(rad,-.5,b),v(rad,.4,b),v(rad,.4,a)],normal*np.array([math.cos((a+b)/2),math.sin((a+b)/2),0]))
                for zz,sign in ((-.5,-1),(.4,1)):
                    duct.face('metal_dark',[v(inside,zz,a),v(ra,zz,a),v(ra,zz,b),v(inside,zz,b)],[0,0,sign])
            rig.add('Pumpjet_Shroud','Hull',p,duct)
    for part in rig.parts:
        if part['mesh'] is not None:part['mesh'].remove_duplicates()
    return rig,s
