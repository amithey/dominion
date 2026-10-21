#!/usr/bin/env python3
"""Original DOMINION architecture, no Blender. Python 3.10+ and NumPy only.

Rebuild: python native/tools/models/generate_buildings.py
Validate saved files: python native/tools/models/generate_buildings.py --validate-only
Optional: --output-dir DIR --manifest FILE --report FILE --types cottage barn

Metres, Y up, front +Z. One material-grouped mesh per LOD, two root nodes.
LOD1 deliberately retains roof/porch/balcony/tank silhouettes; window reveals,
frames, sill/lintel detail, quoins, gutters and downpipes belong to LOD0.
All glTF materials are white, roughness .8, metallic 0, without textures.
No authoring colours, lighting, camera, animation or vertex colours are exported.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / 'native/godot/assets/art'
KINDS = ('cottage', 'townhouse', 'apartment_block', 'farmhouse', 'barn', 'town_hall')
ROLES = {'wall_brick','wall_plaster','wall_stone','wall_concrete','roof_tile','roof_slate','roof_metal','trim','glass','wood','metal'}


def unit(a):
    a = np.asarray(a, dtype=float)
    return a / np.linalg.norm(a)


class Mesh:
    def __init__(self):
        self.groups = defaultdict(lambda: [[], [], [], []])

    def face(self, role, points, outward, normals=None, uv=None):
        """Convex planar polygon, outward CCW winding and metre-based planar UVs."""
        p = np.array(points, dtype=float)
        outward = unit(outward)
        normal = unit(np.cross(p[1]-p[0],p[2]-p[0]))
        if np.dot(normal,outward) < 0:
            p = p[::-1]
            if normals is not None: normals = np.array(normals)[::-1]
            if uv is not None: uv = np.array(uv)[::-1]
            normal = -normal
        if uv is None:
            u = unit(p[1]-p[0]); v = np.cross(normal,u)
            uv = np.stack([p@u,p@v],axis=1)
        if normals is None: normals = np.tile(normal,(len(p),1))
        pos, nor, tex, idx = self.groups[role]
        start = len(pos);pos.extend(p.tolist());nor.extend(np.asarray(normals).tolist());tex.extend(np.asarray(uv).tolist())
        for i in range(1,len(p)-1): idx.extend([start,start+i,start+i+1])

    def solid(self,role,vertices,faces):
        p = np.array(vertices,dtype=float);center = p.mean(0)
        for face in faces:
            q = p[list(face)];self.face(role,q,q.mean(0)-center)

    def box(self,role,center,size,basis=None):
        c=np.array(center);w,h,d=np.array(size)/2
        vertices=np.array([[-w,-h,-d],[w,-h,-d],[w,h,-d],[-w,h,-d],[-w,-h,d],[w,-h,d],[w,h,d],[-w,h,d]])
        if basis is not None: vertices=vertices@np.asarray(basis).T
        self.solid(role,vertices+c,[(0,1,2,3),(4,5,6,7),(0,4,7,3),(1,5,6,2),(0,1,5,4),(3,2,6,7)])

    def tube(self,role,a,b,r,n=12,r_top=None):
        """Closed cylinder/frustum with smooth sides, hard caps, unwrapped metre UVs."""
        a=np.asarray(a);b=np.asarray(b);axis=unit(b-a);length=float(np.linalg.norm(b-a))
        u=unit(np.cross(axis,[0,0,1] if abs(axis[2])<.9 else [1,0,0]));v=np.cross(axis,u)
        r2=r if r_top is None else r_top
        circles=[]
        for center,radius in ((a,r),(b,r2)):
            circles.append([center+radius*(math.cos(t)*u+math.sin(t)*v) for t in np.linspace(0,2*math.pi,n,endpoint=False)])
        for i in range(n):
            j=(i+1)%n;rad0=math.cos(i*2*math.pi/n)*u+math.sin(i*2*math.pi/n)*v;rad1=math.cos((i+1)*2*math.pi/n)*u+math.sin((i+1)*2*math.pi/n)*v
            nn0=unit(rad0+axis*(r-r2)/length);nn1=unit(rad1+axis*(r-r2)/length)
            circumference=2*math.pi*(r+r2)/2
            self.face(role,[circles[0][i],circles[0][j],circles[1][j],circles[1][i]],rad0+rad1,[nn0,nn1,nn1,nn0],[[i/n*circumference,0],[(i+1)/n*circumference,0],[(i+1)/n*circumference,length],[i/n*circumference,length]])
        self.face(role,circles[0],-axis);self.face(role,circles[1],axis)

    def dome(self,role,center,r,height,n=16,rings=6):
        center=np.asarray(center)
        for j in range(rings):
            t0=j/rings*math.pi/2;t1=(j+1)/rings*math.pi/2
            for i in range(n):
                a0=i/n*2*math.pi;a1=(i+1)/n*2*math.pi
                def point(t,a):return center+np.array([r*math.cos(t)*math.cos(a),height*math.sin(t),r*math.cos(t)*math.sin(a)])
                def normal(t,a):return unit([math.cos(t)*math.cos(a)/r,math.sin(t)/height,math.cos(t)*math.sin(a)/r])
                if j==rings-1:
                    ps=[point(t0,a0),point(t0,a1),center+[0,height,0]]
                    ns=[normal(t0,a0),normal(t0,a1),[0,1,0]]
                    uv=[[a0*r,t0*height],[a1*r,t0*height],[(a0+a1)*r/2,t1*height]]
                else:
                    ps=[point(t0,a0),point(t0,a1),point(t1,a1),point(t1,a0)]
                    ns=[normal(t0,a0),normal(t0,a1),normal(t1,a1),normal(t1,a0)]
                    uv=[[a0*r,t0*height],[a1*r,t0*height],[a1*r,t1*height],[a0*r,t1*height]]
                self.face(role,ps,np.array(ps).mean(0)-center,ns,uv)

    def shift(self,delta):
        for g in self.groups.values():g[0]=(np.array(g[0])+delta).tolist()

    def bounds(self):
        p=np.concatenate([np.array(g[0]) for g in self.groups.values()]);return p.min(0),p.max(0)

    def remove_duplicates(self):
        # Exact coincident triangles (including internal shared faces) are never exported.
        seen={};remove=defaultdict(set)
        for role,g in self.groups.items():
            p=np.round(np.array(g[0]),6);faces=np.array(g[3]).reshape(-1,3)
            for fi,f in enumerate(faces):
                key=tuple(sorted(tuple(x) for x in p[f]))
                if key in seen:
                    other,of=seen[key];remove[other].add(of);remove[role].add(fi)
                else:seen[key]=(role,fi)
        for role,indices in remove.items():
            g=self.groups[role];fs=np.array(g[3]).reshape(-1,3)
            g[3]=[int(x) for i,f in enumerate(fs) if i not in indices for x in f]


class Facade:
    def __init__(self,mesh,center,u,normal,width,y0,y1,role,lod):
        self.mesh=mesh;self.c=np.array(center);self.u=np.array(u);self.n=np.array(normal)
        self.width=width;self.y0=y0;self.y1=y1;self.role=role;self.lod=lod
        self.basis=np.stack([self.u,[0,1,0],self.n],axis=1)

    def p(self,x,y,z=0):return self.c+self.u*x+np.array([0,y,0])+self.n*z

    def box(self,role,x,y,z,w,h,d):self.mesh.box(role,self.p(x,y,z),(w,h,d),self.basis)

    def plane(self,role,x0,x1,y0,y1,z=0,normal=1):
        self.mesh.face(role,[self.p(x0,y0,z),self.p(x1,y0,z),self.p(x1,y1,z),self.p(x0,y1,z)],self.n*normal)

    def frame(self,x0,x1,y0,y1,width=.065):
        outer=np.array([[x0,y0],[x1,y0],[x1,y1],[x0,y1]])
        inner=outer+np.array([[width,width],[-width,width],[-width,-width],[width,-width]])
        center=outer.mean(0)
        for i in range(4):
            j=(i+1)%4
            for z,sign in ((.01,1),(-.12,-1)):
                self.mesh.face('trim',[self.p(*outer[i],z),self.p(*outer[j],z),self.p(*inner[j],z),self.p(*inner[i],z)],self.n*sign)
            for ring,sign in ((outer,1),(inner,-1)):
                midpoint=(ring[i]+ring[j])/2-center
                outward=(self.u*midpoint[0]+np.array([0,midpoint[1],0]))*sign
                self.mesh.face('trim',[self.p(*ring[i],.01),self.p(*ring[j],.01),self.p(*ring[j],-.12),self.p(*ring[i],-.12)],outward)

    def build(self,openings):
        """LOD0 has real wall openings, 18 cm recessed glass and reveal geometry."""
        if self.lod:
            self.box(self.role,0,(self.y0+self.y1)/2,-.12,self.width,self.y1-self.y0,.24)
        else:
            joined=getattr(self,'joined_corners',False)
            def back_x(x):
                if not joined:return x
                return min(self.width/2-.24,max(-self.width/2+.24,x))
            xs=sorted(set([-self.width/2,self.width/2]+[o[k] for o in openings for k in (0,1)]))
            ys=sorted(set([self.y0,self.y1]+[o[k] for o in openings for k in (2,3)]))
            for x0,x1 in zip(xs,xs[1:]):
                for y0,y1 in zip(ys,ys[1:]):
                    x=(x0+x1)/2;y=(y0+y1)/2
                    if any(o[0]<x<o[1] and o[2]<y<o[3] for o in openings):continue
                    self.plane(self.role,x0,x1,y0,y1)
                    self.mesh.face(self.role,[self.p(back_x(x0),y0,-.24),self.p(back_x(x1),y0,-.24),self.p(back_x(x1),y1,-.24),self.p(back_x(x0),y1,-.24)],-self.n)
            # Wall boundary caps, oriented outward relative to this wall volume.
            if not joined:
                for x,sign in ((-self.width/2,-1),(self.width/2,1)):
                    self.mesh.face(self.role,[self.p(x,self.y0,0),self.p(x,self.y1,0),self.p(x,self.y1,-.24),self.p(x,self.y0,-.24)],self.u*sign)
            for y,sign in ((self.y0,-1),(self.y1,1)):
                # The bottom may contain a door, so split it into occupied intervals.
                intervals=list(zip(xs,xs[1:]))
                for x0,x1 in intervals:
                    mid=(x0+x1)/2
                    if any(o[0]<mid<o[1] and abs(o[2]-y)<1e-6 for o in openings):continue
                    self.mesh.face(self.role,[self.p(x0,y,0),self.p(x1,y,0),self.p(back_x(x1),y,-.24),self.p(back_x(x0),y,-.24)],[0,sign,0])
        for x0,x1,y0,y1,kind in openings:
            w=x1-x0;h=y1-y0;x=(x0+x1)/2;y=(y0+y1)/2
            if self.lod:
                self.plane('wood' if kind=='door' else 'glass',x0,x1,y0,y1,.006)
                continue
            # Reveals terminate at the frame/glazing; jamb normals face into the opening.
            for xx,sign in ((x0,1),(x1,-1)):
                self.mesh.face(self.role,[self.p(xx,y0,0),self.p(xx,y1,0),self.p(xx,y1,-.24),self.p(xx,y0,-.24)],self.u*sign)
            for yy,sign in ((y0,1),(y1,-1)):
                self.mesh.face(self.role,[self.p(x0,yy,0),self.p(x1,yy,0),self.p(x1,yy,-.24),self.p(x0,yy,-.24)],[0,sign,0])
            self.box('wood' if kind=='door' else 'glass',x,y,-.18,w-.07,h-.07,.035)
            # One closed frame ring avoids internal faces between four joined strips.
            self.frame(x0,x1,y0,y1)
            self.box('trim',x,y1+.055,.025,w+.18,.10,.20)
            if kind!='door':
                self.box('trim',x,y0-.055,.045,w+.22,.10,.28)
                if getattr(self,'mullions',True):self.box('trim',x,y,-.06,.045,h-.13,.07)
            else:
                for dy in (-.45,.45):self.box('wood',x,y+dy,-.149,w*.70,.07,.025)
                self.box('metal',x+w*.32,y,.012,.045,.15,.045)


def roof(mesh,w,d,y,rise,role,lod,gambrel=False,x=0,z=0):
    """Closed pitched roof slabs, overhangs, fascia, ridge, solid gable ends."""
    e=.34;half=d/2+e;wx=w/2+e
    profile=[(-half,y),(0,y+rise),(half,y)]
    if gambrel:profile=[(-half,y),(-half*.48,y+rise*.70),(0,y+rise),(half*.48,y+rise*.70),(half,y)]
    for (z0,h0),(z1,h1) in zip(profile,profile[1:]):
        v=[[x-wx,h0,z+z0],[x+wx,h0,z+z0],[x+wx,h1,z+z1],[x-wx,h1,z+z1]]
        v+= [[a,b-.14,c] for a,b,c in v]
        mesh.solid(role,v,[(0,1,2,3),(4,5,6,7),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
    # End gables are separate walls, not painted triangles on a box.
    for side in (-1,1):
        ps=[[x+side*w/2,y-.14,z-d/2],[x+side*w/2,y-.14,z+d/2]]
        top=[(zz,hh) for zz,hh in profile[1:-1]]
        for zz,hh in reversed(top):ps.append([x+side*w/2,hh-.14,z+zz])
        mesh.face('wall_plaster',ps,[side,0,0])
    mesh.box(role,(x,y+rise+.015,z),(w+.73,.09,.18))
    for side in (-1,1):
        mesh.box('trim',(x,y-.09,z+side*half),(w+.69,.18,.16))
        if not lod:
            mesh.tube('metal',(x-w/2-.24,y-.02,z+side*(half+.025)),(x+w/2+.24,y-.02,z+side*(half+.025)),.055,8)
            mesh.tube('metal',(x+w/2+.13,.24,z+side*(d/2+.09)),(x+w/2+.13,y-.08,z+side*(d/2+.09)),.045,8)


def front_gable_roof(m,w,d,y,rise,role,x=0,z=0):
    """Ridge along Z, with real triangular front/back pediments (no applied sign panel)."""
    half=w/2+.18;near=z-d/2-.18;far=z+d/2+.18
    for x0,x1,y0,y1 in ((x-half,x,y,y+rise),(x,x+half,y+rise,y)):
        top=[[x0,y0,near],[x1,y1,near],[x1,y1,far],[x0,y0,far]]
        points=top+[[a,b-.12,c] for a,b,c in top]
        m.solid(role,points,[(0,1,2,3),(4,5,6,7),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
    for zz,sign in ((z-d/2,-1),(z+d/2,1)):
        m.face('wall_stone',[[x-w/2,y-.12,zz],[x+w/2,y-.12,zz],[x,y+rise-.12,zz]],[0,0,sign])
    m.box(role,(x,y+rise+.015,z),(.16,.09,d+.40))
    for xx in (x-half,x+half):m.box('trim',(xx,y-.055,z),(.10,.13,d+.38))


def chimney(m,x,z,y,lod):
    m.box('wall_brick',(x,y-.45,z),(.54,1.65,.62))
    m.box('trim',(x,y+.43,z),(.72,.13,.80))
    m.box('metal',(x,y+.55,z),(.44,.12,.48))
    if not lod:m.box('trim',(x,y-.75,z),(.68,.10,.76))


def porch(m,w,depth,wallfront,y,lod):
    # Pillars meet both the deck and canopy. Front remains +Z.
    z=wallfront+depth/2
    m.box('wall_stone',(0,.16,z),(w,.32,depth))
    m.box('roof_metal',(0,y,wallfront+depth/2-.04),(w+.22,.16,depth+.28))
    for x in (-w/2+.16,w/2-.16):
        m.box('wood',(x,(y+.32)/2,wallfront+depth-.18),(.16,y-.32,.16))
        if not lod:m.box('trim',(x,.42,wallfront+depth-.18),(.25,.20,.25))


def balcony(m,x,y,z,lod):
    w=2.1;depth=.85
    m.box('wall_concrete',(x,y-.08,z+depth/2),(w,.16,depth))
    if lod:
        m.box('metal',(x,y+.48,z+depth-.04),(w,.94,.065))
        for sign in (-1,1):m.box('metal',(x+sign*(w/2-.03),y+.48,z+depth/2),(.06,.94,depth-.13))
    else:
        for h in (.10,.98):m.box('metal',(x,y+h,z+depth-.04),(w,.045,.055))
        for xx in np.linspace(-w/2+.04,w/2-.04,7):m.box('metal',(x+xx,y+.54,z+depth-.04),(.034,.94,.034))
        for sign in (-1,1):
            m.box('metal',(x+sign*(w/2-.03),y+.98,z+depth/2),(.05,.045,depth))
            m.box('metal',(x+sign*(w/2-.03),y+.52,z+.05),(.04,.94,.04))


def build(kind,variant,lod):
    m=Mesh();v=variant-1
    settings={
        'cottage':[(6.6,5.4,1,2.75),(7.1,5.8,1,2.9),(6.2,6.4,1,2.8)],
        'townhouse':[(4.9,6.8,2,2.9),(5.2,6.4,3,2.8),(5.6,6.7,2,3.0)],
        'apartment_block':[(7.5,6.6,5,2.85),(7.9,6.3,5,2.9),(7.3,7.0,5,2.8)],
        'farmhouse':[(7.8,5.7,2,2.7),(7.4,6.0,1,3.05),(8.0,5.8,2,2.65)],
        'barn':[(7.6,6.8,1,3.5),(8.0,6.7,1,3.6),(7.4,7.0,1,3.8)],
        'town_hall':[(8.0,6.2,2,3.2),(8.3,6.0,2,3.15),(8.1,6.1,2,3.1)],
    }
    w,d,floors,storey=settings[kind][v];base=.28;top=base+floors*storey
    wall={'cottage':['wall_plaster','wall_stone','wall_brick'],'townhouse':['wall_brick','wall_plaster','wall_brick'],'apartment_block':['wall_concrete','wall_brick','wall_plaster'],'farmhouse':['wall_plaster','wall_stone','wall_brick'],'barn':['wood','wall_brick','wood'],'town_hall':['wall_stone','wall_plaster','wall_brick']}[kind][v]
    m.box('wall_stone',(0,base/2,0),(w+.12,base,d+.12))
    for side,center,u,n,width in [('front',(0,0,d/2),(1,0,0),(0,0,1),w),('back',(0,0,-d/2),(-1,0,0),(0,0,-1),w),('left',(-w/2,0,0),(0,0,1),(-1,0,0),d),('right',(w/2,0,0),(0,0,-1),(1,0,0),d)]:
        facade=Facade(m,center,u,n,width,base,top,wall,lod);openings=[]
        facade.mullions=kind!='apartment_block'
        facade.joined_corners=True
        for level in range(floors):
            y0=base+level*storey+.85;wh=1.35 if kind!='barn' else .65
            for x in (-width*.285,width*.285):
                ww=1.10 if kind=='townhouse' else 1.22
                if kind=='barn':ww=.85;y0=base+2.35
                openings.append((x-ww/2,x+ww/2,y0,y0+wh,'window'))
        if side=='front':
            dw=2.8 if kind=='barn' else (1.5 if kind=='town_hall' else 1.0)
            dh=2.9 if kind=='barn' else 2.16
            openings.append((-dw/2,dw/2,base,base+dh,'door'))
        facade.build(openings)
    # Floor plates and cornices close the shell and give the facade believable depth.
    m.box('wall_concrete',(0,top-.09,0),(w-.48,.18,d-.48))
    if not lod:
        for floor in range(1,floors):
            yy=base+floor*storey
            for zz in (-d/2,d/2):m.box('trim',(0,yy,zz),(w+.08,.12,.09))
        # Alternating dressed corner stones remain geometry at close range.
        if kind not in ('apartment_block','barn'):
            for yy in np.arange(base+.22,top-.15,.48):
                for xx in (-w/2,w/2):
                    for zz in (-d/2,d/2):m.box('wall_stone',(xx,yy,zz),(.34,.25,.34))
    m.box('trim',(0,top-.05,0),(w+.37,.18,d+.37))
    if kind=='apartment_block':
        m.box('roof_metal',(0,top+.04,0),(w+.24,.12,d+.24))
        for zz in (-d/2,d/2):m.box('wall_concrete',(0,top+.38,zz),(w+.22,.64,.18))
        for xx in (-w/2,w/2):m.box('wall_concrete',(xx,top+.38,0),(.18,.64,d-.18))
        for level in range(1,5):
            for xx in (-w*.285,w*.285):balcony(m,xx,base+level*storey+.13,d/2,lod)
        # Tank and its support platform are kept in both LOD silhouettes.
        m.box('metal',(0,top+.40,-.65),(1.7,.70,1.7))
        m.tube('metal',(0,top+.76,-.65),(0,top+2.12,-.65),.8,12 if not lod else 8)
        m.tube('metal',(0,top+2.12,-.65),(0,top+2.27,-.65),.86,12 if not lod else 8,r_top=.72)
        m.box('wall_concrete',(w*.27,top+.68,-d*.22),(1.35,1.25,1.45))
        m.box('roof_metal',(w*.27,top+1.34,-d*.22),(1.52,.12,1.62))
    elif kind=='town_hall':
        m.box('roof_slate',(0,top+.09,0),(w+.45,.18,d+.45))
        for zz in (-d/2,d/2):m.box('wall_stone',(0,top+.38,zz),(w+.36,.45,.24))
        # Raised portico, four smooth columns, entablature and a pediment.
        pw=4.8;front=d/2;end=front+1.30
        m.box('wall_stone',(0,.36,front+.66),(pw+.6,.72,1.65))
        for i in range(3):m.box('wall_stone',(0,.12+i*.12,end+.35-i*.20),(pw+.6,.24+i*.24,.45))
        for xx in np.linspace(-pw/2+.32,pw/2-.32,4):
            m.box('trim',(xx,.85,end-.20),(.52,.26,.52))
            m.tube('wall_stone',(xx,.98,end-.20),(xx,3.75,end-.20),.18,12 if not lod else 8,r_top=.155)
            m.box('trim',(xx,3.88,end-.20),(.52,.26,.52))
        m.box('trim',(0,4.10,front+.65),(pw+.38,.22,1.68))
        if v==1:
            m.tube('wall_stone',(0,top+.18,0),(0,top+.62,0),1.30,16 if not lod else 8)
            m.dome('roof_metal',(0,top+.62,0),1.42,1.65,16 if not lod else 8,6 if not lod else 3)
        else:
            # A central clock lantern, with geometric hands and no text or numerals.
            m.box('wall_stone',(0,top+1.02,0),(1.8,2.0,1.8))
            m.box('trim',(0,top+2.10,0),(2.04,.18,2.04))
            roof(m,1.8,1.8,top+2.25,.75,'roof_slate',lod)
            if not lod:
                m.tube('trim',(0,top+1.12,.91),(0,top+1.12,.96),.55,20)
                m.box('metal',(.0,top+1.25,.995),(.045,.36,.035))
                m.box('metal',(.14,top+1.12,1.000),(.32,.045,.035))
        front_gable_roof(m,pw+.38,1.68,4.22,1.0,'roof_slate',z=front+.65)
    else:
        role='roof_slate' if (kind=='townhouse' or v==1) else ('roof_metal' if kind=='barn' and v==2 else 'roof_tile')
        rise=1.75 if kind=='cottage' else (2.35 if kind=='barn' else 1.85)
        roof(m,w,d,top+.15,rise,role,lod,gambrel=(kind=='barn' and v==1))
        if kind!='barn':chimney(m,-w*.27,-d*.18,top+rise+.60,lod)
        if kind in ('cottage','farmhouse'):
            porch(m,3.0 if kind=='cottage' else 5.3,.95,d/2,2.55,lod)
        if kind=='cottage' and v==1:
            # Raised dormer with its own front-facing gable and recessed window.
            for xx in (.9-.575,.9+.575):m.box('wall_plaster',(xx,top+1.35,d*.20),(.20,1.35,1.3))
            m.box('wall_plaster',(.9,top+1.35,d*.20-.55),(.95,1.35,.20))
            ff=Facade(m,(.9,0,d*.20+.65),(1,0,0),(0,0,1),1.35,top+.675,top+2.025,'wall_plaster',lod)
            ff.build([(-.42,.42,top+1.10,top+1.84,'window')])
            front_gable_roof(m,1.35,1.3,top+2.025,.55,'roof_slate',x=.9,z=d*.20)
        if kind=='barn':
            # Door split, external timber braces and loft louvre, no signage.
            if not lod:
                m.box('metal',(0,1.65,d/2+.03),(.055,2.7,.055))
                for xx in (-1.2,1.2):m.box('wood',(xx,1.70,d/2+.03),(.09,2.55,.10))
            m.box('wood',(0,top+.48,0),(1.0,.8,1.0))
            roof(m,1.0,1.0,top+.90,.42,'roof_metal',lod)
    if kind not in ('town_hall','barn'):
        m.box('wall_stone',(0,.10,d/2+.44),(1.65,.20,.88))
        m.box('wall_stone',(0,.21,d/2+.20),(1.40,.22,.40))
        if kind in ('townhouse','apartment_block'):m.box('roof_metal',(0,2.65,d/2+.43),(1.65,.15,.92))
    m.remove_duplicates()
    return m


def export_glb(path,meshes,kind,variant):
    materials=sorted(set(role for m in meshes for role in m.groups))
    doc={'asset':{'version':'2.0','generator':'DOMINION original architecture generator 1.0'},'scene':0,'scenes':[{'nodes':[0,1]}],
         'nodes':[{'name':'LOD0','mesh':0},{'name':'LOD1','mesh':1}], 'meshes':[],
         'materials':[{'name':role,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.8}} for role in materials],
         'buffers':[{'byteLength':0}],'bufferViews':[],'accessors':[],
         'extras':{'units':'metres','up':'+Y','front':'+Z','uv_units':'metres','building':kind,'variant':variant,'lod_usage':'Select one root node at a time; LOD nodes intentionally share the same coordinate space.'}}
    blob=bytearray()
    def accessor(data,component,typ,target):
        nonlocal blob
        data=np.asarray(data,dtype='<f4' if component==5126 else '<u4')
        while len(blob)%4:blob.append(0)
        vi=len(doc['bufferViews']);offset=len(blob);raw=data.tobytes();blob.extend(raw)
        doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(raw),'target':target})
        ai=len(doc['accessors']);ac={'bufferView':vi,'componentType':component,'count':len(data),'type':typ}
        if typ=='VEC3':ac.update(min=data.min(0).tolist(),max=data.max(0).tolist())
        doc['accessors'].append(ac);return ai
    for lod,m in enumerate(meshes):
        primitives=[]
        for role,g in sorted(m.groups.items()):
            if not g[3]:continue
            p,n,uv,idx=g
            attributes={'POSITION':accessor(p,5126,'VEC3',34962),'NORMAL':accessor(n,5126,'VEC3',34962),'TEXCOORD_0':accessor(uv,5126,'VEC2',34962)}
            primitives.append({'attributes':attributes,'indices':accessor(idx,5125,'SCALAR',34963),'material':materials.index(role),'mode':4})
        doc['meshes'].append({'name':f'{kind}_{variant}_LOD{lod}','primitives':primitives})
    while len(blob)%4:blob.append(0)
    doc['buffers'][0]['byteLength']=len(blob)
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    binary=struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob
    path.write_bytes(binary)


def load_glb(path):
    """Independent read-back path: validates chunk bounds and decodes accessors."""
    raw=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and total==len(raw),f'{path}: GLB header'
    chunks=[];offset=12
    while offset<len(raw):
        length,typ=struct.unpack_from('<II',raw,offset);assert length%4==0
        offset+=8;assert offset+length<=len(raw);chunks.append((typ,raw[offset:offset+length]));offset+=length
    assert len(chunks)==2 and chunks[0][0]==0x4E4F534A and chunks[1][0]==0x004E4942
    doc=json.loads(chunks[0][1]);binary=chunks[1][1]
    def read(index):
        ac=doc['accessors'][index];bv=doc['bufferViews'][ac['bufferView']]
        dims={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[ac['type']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[ac['componentType']]
        begin=bv.get('byteOffset',0)+ac.get('byteOffset',0);size=ac['count']*dims*np.dtype(dtype).itemsize
        assert begin+size<=bv.get('byteOffset',0)+bv['byteLength']<=len(binary)
        data=np.frombuffer(binary,dtype=dtype,count=ac['count']*dims,offset=begin).reshape(ac['count'],dims).copy()
        if 'min' in ac:assert np.allclose(data.min(0),ac['min']) and np.allclose(data.max(0),ac['max'])
        return data
    lods=[]
    for mesh in doc['meshes']:
        groups=[]
        for p in mesh['primitives']:
            groups.append({'role':doc['materials'][p['material']]['name'],'p':read(p['attributes']['POSITION']),'n':read(p['attributes']['NORMAL']),'uv':read(p['attributes']['TEXCOORD_0']),'f':read(p['indices']).reshape(-1,3)})
        lods.append(groups)
    return doc,lods


def validate(path):
    doc,lods=load_glb(path)
    assert [n['name'] for n in doc['nodes']]==['LOD0','LOD1'] and doc['scenes'][0]['nodes']==[0,1]
    assert len(doc['meshes'])==2 and len(lods)==2
    assert not any(k in doc for k in ('images','textures','cameras','animations','extensions'))
    for mat in doc['materials']:
        assert mat['name'] in ROLES
        assert mat['pbrMetallicRoughness']=={'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.8}
    totals=[];bounds=[];uv_errors=[]
    for level,groups in enumerate(lods):
        seen=set();total=0;positions=[];roles=set()
        for g in groups:
            assert g['role'] not in roles,'one primitive per material per LOD';roles.add(g['role'])
            p,n,uv,f=(g[k] for k in ('p','n','uv','f'));assert len(p)==len(n)==len(uv)
            assert np.isfinite(p).all() and np.isfinite(n).all() and np.isfinite(uv).all()
            assert f.min()>=0 and f.max()<len(p)
            assert np.allclose(np.linalg.norm(n,axis=1),1,atol=2e-5)
            triangles=p[f];cross=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]);lengths=np.linalg.norm(cross,axis=1)
            assert (lengths>1e-7).all(),f'{path.name} LOD{level}: degenerate face'
            # Geometric CCW normals must agree with all exported vertex normals.
            dots=np.einsum('ij,ikj->ik',cross/lengths[:,None],n[f])
            assert (dots>.45).all(),f'{path.name} LOD{level}: flipped face/normal'
            edges=defaultdict(lambda:[0,0])
            for tri in triangles:
                key=tuple(sorted(tuple(q) for q in np.round(tri,5)))
                assert key not in seen,f'{path.name} LOD{level}: duplicate face';seen.add(key)
                points=[tuple(q) for q in np.round(tri,5)]
                for va,vb in zip(points,points[1:]+points[:1]):
                    edge=tuple(sorted((va,vb)));edges[edge][0]+=1;edges[edge][1]+=1 if va<vb else -1
            assert all(count!=2 or balance==0 for count,balance in edges.values()),f'{path.name} LOD{level}: inconsistent welded edge winding'
            # All hard planar faces use orthonormal metre projection, verified per triangle.
            flat=(np.abs(n[f][:,0]-n[f][:,1]).max(1)<1e-5)&(np.abs(n[f][:,0]-n[f][:,2]).max(1)<1e-5)
            duv=uv[f];ab=duv[:,1]-duv[:,0];ac=duv[:,2]-duv[:,0]
            uv_cross=np.abs(ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0])
            if flat.any():
                ratio=uv_cross[flat]/lengths[flat]
                assert np.allclose(ratio,1,atol=3e-3),f'{path.name}: UV metre scale'
                uv_errors.append(float(np.max(np.abs(ratio-1))))
            total+=len(f);positions.append(p)
        allp=np.concatenate(positions);low=allp.min(0);high=allp.max(0);bounds.append((low,high))
        assert low[1]>=-1e-5 and abs(low[1])<1e-5,'ground origin / underground pieces'
        assert max(high[0]-low[0],high[2]-low[2])<=10.0001,'footprint exceeds 10m square'
        assert np.max(np.linalg.norm(allp[:,[0,2]],axis=1))<12,'hex radius'
        assert np.allclose((low+high)[[0,2]],0,atol=.002),'origin must centre footprint'
        assert total<=(6000 if level==0 else 1200),f'{path.name} LOD{level}: {total} triangles'
        totals.append(total)
    assert np.allclose(bounds[0],bounds[1],atol=.08),'LOD silhouette bounds differ'
    low,high=bounds[0]
    return {'file':'buildings/'+path.name,'kind':'model','triangles':totals,'footprint':[round(float(high[0]-low[0]),4),round(float(high[2]-low[2]),4)],'height':round(float(high[1]),4),'materials':[m['name'] for m in doc['materials']],
            'size':[round(float(x),4) for x in high-low],'grid':None,'tileable':False,'frames':None,'units':'metres','up':'+Y','front':'+Z','nodes':['LOD0','LOD1'],
            'notes':'Original architecture authored by native/tools/models/generate_buildings.py using NumPy, json and struct; no Blender, external mesh or embedded texture/colour. One mesh per LOD, one primitive per named material. Recessed LOD0 windows, frames, sills, lintels, entry, roof details; LOD1 retains major silhouette. Independently loaded from GLB and checked for structure, unit normals, CCW face agreement, degenerate/duplicate faces, metre planar UV area, ground clearance, centred footprint, LOD bounds and triangle budgets.',
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    parser=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output-dir',type=Path,default=ART/'buildings');parser.add_argument('--manifest',type=Path,default=ART/'MANIFEST.json')
    parser.add_argument('--types',nargs='+',choices=KINDS,default=list(KINDS));parser.add_argument('--validate-only',action='store_true');parser.add_argument('--report',type=Path)
    args=parser.parse_args();args.output_dir.mkdir(parents=True,exist_ok=True);entries=[]
    for kind in args.types:
        for variant in range(1,4):
            path=args.output_dir/f'{kind}_{variant}.glb'
            if not args.validate_only:
                meshes=[build(kind,variant,level) for level in (0,1)]
                low,high=meshes[0].bounds();shift=np.array([-(low[0]+high[0])/2,0,-(low[2]+high[2])/2])
                for m in meshes:m.shift(shift)
                export_glb(path,meshes,kind,variant)
            entry=validate(path);entries.append(entry)
            print(f'PASS {path.name}: LOD0/1 {entry["triangles"]}, footprint {entry["footprint"]}, height {entry["height"]}',flush=True)
    if not args.validate_only:
        manifest=json.loads(args.manifest.read_text(encoding='utf-8')) if args.manifest.exists() else []
        names={e['file'] for e in entries};manifest=[e for e in manifest if e['file'] not in names]+entries
        args.manifest.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    if args.report:args.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
    print(f'{len(entries)} GLBs loaded back and validated.')


if __name__=='__main__':main()
