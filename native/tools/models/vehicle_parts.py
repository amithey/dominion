"""Shared metre-scale mesh parts and binary glTF rig IO. NumPy + standard library.

The surface authoring core is shared with the existing building generator.
No Blender, downloaded meshes, embedded textures, or vertex colours.
"""
from __future__ import annotations

from collections import defaultdict
import json
import math
from pathlib import Path
import struct
import numpy as np
from generate_buildings import Mesh as BaseMesh, unit

ROLES=('paint','metal_dark','rubber','glass','markings')


class Mesh(BaseMesh):
    def face(self,role,points,outward,normals=None,uv=None):
        # Vehicle armour lofts can make non-planar quads. Split them into true
        # planar facets so each hard normal and metre UV projection is correct.
        p=np.array(points,dtype=float)
        normal=unit(np.cross(p[1]-p[0],p[2]-p[0]))
        if len(p)>3 and np.abs((p-p[0])@normal).max()>1e-7:
            for i in range(1,len(p)-1):
                indices=[0,i,i+1]
                self.face(role,p[indices],outward,None if normals is None else np.array(normals)[indices],None if uv is None else np.array(uv)[indices])
            return
        super().face(role,p,outward,normals,uv)


def rotation(axis,angle):
    x,y,z=unit(axis);c=math.cos(angle);s=math.sin(angle);t=1-c
    return np.array([[t*x*x+c,t*x*y-s*z,t*x*z+s*y],[t*x*y+s*z,t*y*y+c,t*y*z-s*x],[t*x*z-s*y,t*y*z+s*x,t*z*z+c]])


def quaternion_matrix(q):
    """glTF xyzw quaternion. Used for canted rotor/propeller hinge frames."""
    q=np.asarray(q,dtype=float);assert np.isclose(np.linalg.norm(q),1,atol=1e-6)
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])


def quaternion_product(a,b):
    av=np.asarray(a[:3]);bv=np.asarray(b[:3]);aw=a[3];bw=b[3]
    return np.r_[aw*bv+bw*av+np.cross(av,bv),aw*bw-np.dot(av,bv)]


def merge_mesh(target,source,R=None,t=(0,0,0),roles=None):
    R=np.eye(3) if R is None else np.array(R);t=np.array(t)
    assert np.linalg.det(R)>.999
    for role,g in source.groups.items():
        if not g[3]:continue
        mapped=roles.get(role,role) if roles else role
        if mapped is None:continue
        p,n,uv,f=target.groups[mapped];offset=len(p)
        p.extend((np.asarray(g[0])@R.T+t).tolist());n.extend((np.asarray(g[1])@R.T).tolist())
        uv.extend(g[2]);f.extend([offset+i for i in g[3]])
    return target


def profile_hull(mesh,role,profile):
    """Extrude a sloped hull side profile; profile points are (z,y,half_width)."""
    vertices=[(sign*w,y,z) for sign in (-1,1) for z,y,w in profile]
    n=len(profile);faces=[tuple(range(n)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh.solid(role,vertices,faces)


def loft(mesh,role,rings):
    """Closed armour loft: same CCW footprint vertex count at each height."""
    n=len(rings[0]);p=np.array(rings,dtype=float).reshape(-1,3)
    faces=[tuple(range(n)),tuple(range((len(rings)-1)*n,len(rings)*n))]
    for j in range(len(rings)-1):
        faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n))
    mesh.solid(role,p,faces)


def lathe_x(mesh,profile,center=(0,0,0),segments=12):
    """Closed wheel profile (axial x, radius, material after this point).

    Hard radial profile creases; smooth normals around each circumference.
    U is circumference in metres, V is profile arc length in metres.
    """
    center=np.array(center);distance=0
    for a,b in zip(profile,profile[1:]):
        x0,r0,role=a;x1,r1,_=b;step=math.hypot(x1-x0,r1-r0)
        if step<1e-8:continue
        for i in range(segments):
            t0=2*math.pi*i/segments;t1=2*math.pi*(i+1)/segments
            def point(x,r,t):return center+np.array([x,r*math.cos(t),r*math.sin(t)])
            def normal(t):return unit([-(r1-r0),(x1-x0)*math.cos(t),(x1-x0)*math.sin(t)])
            if r0==0:
                points=[point(x0,0,t0),point(x1,r1,t0),point(x1,r1,t1)]
                # Axis cap: orthonormal planar metre UVs, separate hard cap normals.
                mesh.face(role,points,[-1,0,0])
            elif r1==0:
                mesh.face(role,[point(x0,r0,t0),point(x1,0,t0),point(x0,r0,t1)],[1,0,0])
            else:
                uv=None if abs(x1-x0)<1e-8 else [[t0*r0,distance],[t0*r1,distance+step],[t1*r1,distance+step],[t1*r0,distance]]
                mesh.face(role,[point(x0,r0,t0),point(x1,r1,t0),point(x1,r1,t1),point(x0,r0,t1)],normal((t0+t1)/2),[normal(t0),normal(t0),normal(t1),normal(t1)],uv)
        distance+=step


def road_wheel(lod,side):
    m=Mesh()
    if lod:
        profile=[(-.215,0,'paint'),(-.215,.33,'rubber'),(.215,.33,'paint'),(.215,0,'paint')]
        lathe_x(m,profile,segments=6)
        return m
    profile=[(-.225,0,'paint'),(-.225,.18,'paint'),(-.20,.285,'rubber'),(-.20,.33,'rubber'),(-.08,.33,'paint'),(-.07,.285,'paint'),(.07,.285,'rubber'),(.08,.33,'rubber'),(.20,.33,'paint'),(.20,.285,'paint'),(.225,.18,'paint'),(.225,0,'paint')]
    lathe_x(m,profile,segments=12)
    m.tube('paint',(side*.226,0,0),(side*.27,0,0),.145,12)
    for t in np.linspace(0,2*math.pi,6,endpoint=False):
        m.box('metal_dark',(side*.279,.102*math.cos(t),.102*math.sin(t)),(.022,.026,.026))
    return m


def end_wheel(lod,sprocket=False):
    m=Mesh();n=8 if lod else 14
    lathe_x(m,[(-.22,0,'paint'),(-.22,.46,'metal_dark'),(.22,.46,'paint'),(.22,0,'paint')],segments=n)
    if not lod:
        m.tube('metal_dark',(-.235,0,0),(.235,0,0),.19,12)
        if sprocket:
            for t in np.linspace(0,2*math.pi,13,endpoint=False):
                R=rotation((1,0,0),t)
                m.box('metal_dark',(0,.482*math.cos(t),.482*math.sin(t)),(.45,.085,.10),R)
        else:
            for t in np.linspace(0,2*math.pi,6,endpoint=False):
                m.box('paint',(.225,.28*math.cos(t),.28*math.sin(t)),(.025,.09,.09))
    return m


class TrackPath:
    half=3.23
    radius=.57
    y=.65
    length=4*half+2*math.pi*radius

    def sample(self,u):
        s=(u%1)*self.length;straight=2*self.half;arc=math.pi*self.radius
        if s<straight:
            return np.array([0,self.y-self.radius,-self.half+s]),np.array([0,-1,0]),np.array([0,0,1])
        s-=straight
        if s<arc:
            a=-math.pi/2+s/self.radius
            return np.array([0,self.y+self.radius*math.sin(a),self.half+self.radius*math.cos(a)]),np.array([0,math.sin(a),math.cos(a)]),np.array([0,math.cos(a),-math.sin(a)])
        s-=arc
        if s<straight:
            return np.array([0,self.y+self.radius,self.half-s]),np.array([0,1,0]),np.array([0,0,-1])
        s-=straight;a=math.pi/2+s/self.radius
        return np.array([0,self.y+self.radius*math.sin(a),-self.half+self.radius*math.cos(a)]),np.array([0,math.sin(a),math.cos(a)]),np.array([0,math.cos(a),-math.sin(a)])


def track(lod,x):
    m=Mesh();path=TrackPath();segments=20 if lod else 72;width=.66;thickness=.08
    # Longitudinal U goes exactly 0..1 around the complete loop. V is metres.
    for i in range(segments):
        u0=i/segments;u1=(i+1)/segments;p0,n0,_=path.sample(u0);p1,n1,_=path.sample(u1)
        p0=p0+[x,0,0];p1=p1+[x,0,0]
        for radial,sign in ((0,1),(-thickness,-1)):
            points=[p0+n0*radial+[-width/2,0,0],p1+n1*radial+[-width/2,0,0],p1+n1*radial+[width/2,0,0],p0+n0*radial+[width/2,0,0]]
            m.face('metal_dark',points,(n0+n1)*sign,[n0*sign,n1*sign,n1*sign,n0*sign],[[u0,0],[u1,0],[u1,width],[u0,width]])
        for side in (-1,1):
            points=[p0+[side*width/2,0,0],p1+[side*width/2,0,0],p1-n1*thickness+[side*width/2,0,0],p0-n0*thickness+[side*width/2,0,0]]
            m.face('metal_dark',points,[side,0,0],uv=[[u0,0],[u1,0],[u1,thickness],[u0,thickness]])
    pads=12 if lod else 80
    for i in range(pads):
        u=(i+.5)/pads;p,normal,tangent=path.sample(u);p=p+[x,0,0]
        basis=np.stack([[1,0,0],normal,tangent],axis=1)
        # This orthonormal basis can be left handed on a loop; Mesh.box reorients every face.
        shoe=Mesh();pitch=path.length/80
        shoe.box('metal_dark',p+normal*.025,(width,.05,pitch*.82),basis)
        if not lod:shoe.box('rubber',p+normal*.065,(.43,.03,pitch*.64),basis)
        else:shoe.box('rubber',p+normal*.065,(.44,.03,pitch*.70),basis)
        # All track vertices, including real pad boxes, use longitudinal loop U.
        for role,g in shoe.groups.items():
            pos=np.array(g[0]);along=(pos-p)@tangent
            g[2]=np.stack([u+along/path.length,pos[:,0]-x+width/2],axis=1).tolist()
        merge_mesh(m,shoe)
    m.remove_duplicates()
    # Tangent shoe corners on an arc can dip a few millimetres below the
    # analytic loop. Seat the actual solid pads, not just the guide curve.
    low,_=m.bounds();m.shift([0,-low[1],0])
    return m


def hollow_muzzle(mesh,a,b,radius=.084,bore=.06,n=16):
    """Visible recessed bore, annular muzzle face, no black overlay disk."""
    a=np.array(a);b=np.array(b);axis=unit(b-a);u=unit(np.cross(axis,[1,0,0]));v=np.cross(axis,u)
    for i in range(n):
        t0=i/n*2*math.pi;t1=(i+1)/n*2*math.pi
        r0=math.cos(t0)*u+math.sin(t0)*v;r1=math.cos(t1)*u+math.sin(t1)*v
        mesh.face('metal_dark',[a+radius*r0,b+radius*r0,b+radius*r1,a+radius*r1],r0+r1,[r0,r0,r1,r1],[[t0*radius,0],[t0*radius,np.linalg.norm(b-a)],[t1*radius,np.linalg.norm(b-a)],[t1*radius,0]])
        mesh.face('metal_dark',[a+bore*r0,b+bore*r0,b+bore*r1,a+bore*r1],-r0-r1,[-r0,-r0,-r1,-r1],[[t0*bore,0],[t0*bore,np.linalg.norm(b-a)],[t1*bore,np.linalg.norm(b-a)],[t1*bore,0]])
        mesh.face('metal_dark',[b+radius*r0,b+radius*r1,b+bore*r1,b+bore*r0],axis)
        mesh.face('metal_dark',[a+radius*r0,a+radius*r1,a+bore*r1,a+bore*r0],-axis)
    back=[a+bore*(math.cos(t)*u+math.sin(t)*v) for t in np.linspace(0,2*math.pi,n,endpoint=False)]
    mesh.face('metal_dark',back,axis)


class Rig:
    def __init__(self,lod):
        self.lod=lod;self.parts=[];self.pivots={};self.root=f'LOD{lod}'

    def add(self,name,parent,pivot=(0,0,0),mesh=None,axis=None,**extras):
        assert name not in self.pivots
        self.pivots[name]=np.array(pivot,dtype=float)
        self.parts.append({'name':name,'parent':parent,'pivot':np.array(pivot,dtype=float),'mesh':mesh,'axis':axis,'extras':extras})
        return name


def write_glb(path,rigs,wreck,collision,metadata):
    doc={'asset':{'version':'2.0','generator':'DOMINION original vehicle generator 1.0'},'scene':0,'scenes':[{'name':'M1A2_SEPv3_Abrams','nodes':[]}],
         'nodes':[],'meshes':[],'materials':[{'name':role,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'roughnessFactor':.8,'metallicFactor':0}} for role in ROLES],
         'buffers':[{'byteLength':0}],'bufferViews':[],'accessors':[],
         'extensionsUsed':['KHR_node_visibility'],'extensionsRequired':['KHR_node_visibility'],'extras':metadata}
    doc['scenes'][0]['name']=metadata.get('scene_name',doc['scenes'][0]['name'])
    blob=bytearray()
    def acc(data,typ,target,integer=False):
        data=np.asarray(data,dtype='<u4' if integer else '<f4');offset=len(blob);blob.extend(data.tobytes())
        while len(blob)%4:blob.append(0)
        vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':data.nbytes,'target':target})
        ac={'bufferView':vi,'componentType':5125 if integer else 5126,'count':len(data),'type':typ}
        if typ=='VEC3':ac.update(min=data.min(0).tolist(),max=data.max(0).tolist())
        idx=len(doc['accessors']);doc['accessors'].append(ac);return idx
    def mesh_index(mesh,name,origin=(0,0,0),frame=None):
        primitives=[]
        for role,g in sorted(mesh.groups.items()):
            if not g[3]:continue
            p=np.array(g[0])-origin
            normal=g[1]
            if frame is not None:p=p@frame;normal=np.asarray(normal)@frame
            primitives.append({'attributes':{'POSITION':acc(p,'VEC3',34962),'NORMAL':acc(normal,'VEC3',34962),'TEXCOORD_0':acc(g[2],'VEC2',34962)},'indices':acc(g[3],'SCALAR',34963,True),'material':ROLES.index(role),'mode':4})
        idx=len(doc['meshes']);doc['meshes'].append({'name':name,'primitives':primitives});return idx
    def node(name,parent=None,translation=(0,0,0),mesh=None,visible=None,extras=None):
        n={'name':name,'translation':np.asarray(translation).tolist()}
        if mesh is not None:n['mesh']=mesh
        if visible is not None:n['extensions']={'KHR_node_visibility':{'visible':visible}}
        if extras:n['extras']=extras
        idx=len(doc['nodes']);doc['nodes'].append(n)
        if parent is None:doc['scenes'][0]['nodes'].append(idx)
        else:doc['nodes'][parent].setdefault('children',[]).append(idx)
        return idx
    for rig in rigs:
        root=node(rig.root,visible=(rig.lod==0),extras={'lod':rig.lod})
        byname={rig.root:root};frames={rig.root:None};orientations={rig.root:np.array([0.,0.,0.,1.])}
        for part in rig.parts:
            parent=part['parent'];parentpivot=rig.pivots.get(parent,np.zeros(3));local=part['pivot']-parentpivot
            parentframe=frames[parent]
            if parentframe is not None:local=parentframe.T@local
            worldq=part['extras'].get('frame_rotation',orientations[parent])
            frame=quaternion_matrix(worldq) if 'frame_rotation' in part['extras'] else parentframe
            frames[part['name']]=frame;orientations[part['name']]=worldq
            extras=dict(part['extras'])
            extras['canonical_part']=part['name']
            if part['axis']:extras['rotation_axis']=part['axis']
            suffix='_LOD1' if rig.lod else ''
            pivot=node(part['name']+suffix,byname[parent],local,extras=extras);byname[part['name']]=pivot
            if 'frame_rotation' in part['extras']:
                inverse=np.array(orientations[parent])*[-1,-1,-1,1]
                doc['nodes'][pivot]['rotation']=quaternion_product(inverse,worldq).tolist()
            if part['mesh'] is not None:
                mi=mesh_index(part['mesh'],rig.root+'_'+part['name'],part['pivot'],frame)
                child=node(part['name']+'_Mesh'+suffix,pivot,mesh=mi,extras={'canonical_part':part['name']+'_Mesh'})
                if 'mesh_scale' in part['extras']:
                    doc['nodes'][child]['scale']=part['extras']['mesh_scale']
    node('Wreck',mesh=mesh_index(wreck,'Wreck'),visible=False,extras={'state':'destroyed','default_visible':False,'detached_turret':metadata.get('detached_turret',True)})
    cr=node('collision',visible=False,extras={'purpose':'game collision proxy','default_visible':False})
    low,high=collision.bounds();center=(low+high)/2
    node('Collision_Box',cr,mesh=mesh_index(collision,'Collision_Box',center),translation=center,extras={'shape':'box','size':(high-low).tolist()})
    doc['buffers'][0]['byteLength']=len(blob)
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    raw=struct.pack('<4sII',b'glTF',2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob
    path.write_bytes(raw)


def read_glb(path):
    raw=Path(path).read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw)
    size,typ=struct.unpack_from('<II',raw,12);assert typ==0x4E4F534A and size%4==0
    doc=json.loads(raw[20:20+size]);offset=20+size
    size,typ=struct.unpack_from('<II',raw,offset);assert typ==0x004E4942 and size%4==0
    binary=raw[offset+8:offset+8+size];assert offset+8+size==len(raw)
    def accessor(index):
        ac=doc['accessors'][index];view=doc['bufferViews'][ac['bufferView']]
        dims={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[ac['type']];dtype={5126:'<f4',5125:'<u4'}[ac['componentType']]
        start=view.get('byteOffset',0)+ac.get('byteOffset',0);count=ac['count']*dims
        assert start+count*np.dtype(dtype).itemsize<=view.get('byteOffset',0)+view['byteLength']<=len(binary)
        data=np.frombuffer(binary,dtype=dtype,count=count,offset=start).reshape(ac['count'],dims).copy()
        if 'min' in ac:assert np.allclose(data.min(0),ac['min']) and np.allclose(data.max(0),ac['max'])
        return data
    groups=[]
    for mesh in doc['meshes']:
        parts=[]
        for p in mesh['primitives']:
            assert set(p['attributes'])=={'POSITION','NORMAL','TEXCOORD_0'}
            parts.append({'role':doc['materials'][p['material']]['name'],'p':accessor(p['attributes']['POSITION']),'n':accessor(p['attributes']['NORMAL']),'uv':accessor(p['attributes']['TEXCOORD_0']),'f':accessor(p['indices']).reshape(-1,3)})
        groups.append(parts)
    return doc,groups


def walk_nodes(doc,override=None,canonical=False):
    """Read-back traversal, including hidden nodes; override maps full paths to matrices."""
    override=override or {};result=[]
    def visit(index,parent_matrix,path,parent_visible):
        node=doc['nodes'][index];local=np.eye(4);local[:3,3]=node.get('translation',[0,0,0])
        local[:3,:3]=np.diag(node.get('scale',[1,1,1]))
        if 'rotation' in node:local[:3,:3]=quaternion_matrix(node['rotation'])@local[:3,:3]
        name=node.get('extras',{}).get('canonical_part',node['name']) if canonical else node['name']
        path=path+'/'+name if path else name
        if path in override:local=local@override[path]
        world=parent_matrix@local;visible=parent_visible and node.get('extensions',{}).get('KHR_node_visibility',{}).get('visible',True)
        result.append((path,node,world,visible))
        for child in node.get('children',[]):visit(child,world,path,visible)
    for root in doc['scenes'][doc['scene']]['nodes']:visit(root,np.eye(4),'',True)
    return result
