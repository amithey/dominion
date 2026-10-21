#!/usr/bin/env python3
"""Original compact civic/industrial architecture, built in metres without Blender.

Python 3.10+ and NumPy. Reuses the first batch's mesh builder, GLB writer and
strict read-back validator. Rebuild with --types <names>; singleton types have
only variant 1. All others have three distinct architectural variants.
"""
from __future__ import annotations
import argparse, json, math
from pathlib import Path
import numpy as np
from generate_buildings import Mesh, Facade, roof, front_gable_roof, chimney, unit, ART, export_glb, validate


def beam(m,role,a,b,width=.1,depth=None):
    a=np.asarray(a,float);b=np.asarray(b,float);axis=unit(b-a)
    helper=np.array([0,1,0]) if abs(axis[1])<.95 else np.array([1,0,0])
    u=unit(np.cross(helper,axis));v=np.cross(axis,u)
    m.box(role,(a+b)/2,(width,depth or width,np.linalg.norm(b-a)),np.stack([u,v,axis],axis=1))


def shell(m,w,d,top,lod,role='wall_brick',floors=2,columns=2,x=0,z=0,base=.28,doors=None):
    """Real recessed openings, joined masonry corners and closed floor plates."""
    m.box('wall_stone',(x,base/2,z),(w+.12,base,d+.12))
    storey=(top-base)/floors
    sides=[('front',(x,0,z+d/2),(1,0,0),(0,0,1),w),('back',(x,0,z-d/2),(-1,0,0),(0,0,-1),w),
           ('left',(x-w/2,0,z),(0,0,1),(-1,0,0),d),('right',(x+w/2,0,z),(0,0,-1),(1,0,0),d)]
    for side,c,u,n,width in sides:
        f=Facade(m,c,u,n,width,base,top,role,lod);f.joined_corners=True;f.mullions=False;openings=[]
        for level in range(floors):
            if columns==2:xs=[-width*.29,width*.29]
            else:xs=np.linspace(-width*.34,width*.34,columns)
            for xx in xs:
                ww=min(1.15,width/(columns+1)*.65);y0=base+level*storey+.9
                if side=='front' and level==0 and abs(xx)<1.2:continue
                openings.append((xx-ww/2,xx+ww/2,y0,min(y0+1.45,base+(level+1)*storey-.3),'window'))
        if side=='front':openings.extend(doors if doors is not None else [(-.7,.7,base,base+2.2,'door')])
        f.build(openings)
    m.box('wall_concrete',(x,top-.10,z),(w-.48,.20,d-.48))
    m.box('trim',(x,top-.03,z),(w+.25,.18,d+.25))
    if not lod:
        for floor in range(1,floors):
            yy=base+floor*storey
            for zz in (-d/2,d/2):m.box('trim',(x,yy,z+zz),(w+.09,.12,.12))
        for xx in (-w/2,w/2):
            for zz in (-d/2,d/2):
                for yy in np.arange(.5,top-.2,.7):m.box('wall_stone',(x+xx,yy,z+zz),(.3,.24,.3))
    return top


def flat_roof(m,w,d,y,lod,x=0,z=0,parapet=True):
    m.box('roof_metal',(x,y+.10,z),(w+.44,.20,d+.44))
    if parapet:
        for zz in (-d/2,d/2):m.box('wall_concrete',(x,y+.42,z+zz),(w+.32,.45,.17))
        for xx in (-w/2,w/2):m.box('wall_concrete',(x+xx,y+.42,z),(.17,.45,d-.18))
    if not lod:
        for xx in (-w/2,w/2):
            m.tube('metal',(x+xx,.24,z-d/2+.12),(x+xx,y-.12,z-d/2+.12),.04,6)


def entrance(m,z,lod,width=2.4,height=2.7,x=0,columns=False):
    for i in range(3):m.box('wall_stone',(x,.06+i*.08,z+.66-i*.16),(width+.35,.12+i*.16,.95-i*.24))
    m.box('roof_metal',(x,height,z+.57),(width,.15,1.28))
    if columns:
        for xx in (-width/2+.16,width/2-.16):
            m.tube('wall_stone',(x+xx,.32,z+.95),(x+xx,height-.08,z+.95),.16,12 if not lod else 6)
    if not lod:
        for xx in (-.85,.85):m.box('metal',(x+xx,1.9,z+.08),(.12,.22,.12))


def roof_vent(m,x,z,y,lod):
    m.box('metal',(x,y+.24,z),(.6,.48,.65))
    m.box('roof_metal',(x,y+.52,z),(.75,.10,.80))
    if not lod:
        for yy in np.linspace(y+.10,y+.38,4):m.box('trim',(x,yy,z+.337),(.48,.025,.035))


def civic(variant,lod,kind,w,d,floors,wall,style):
    v=variant-1;m=Mesh();w+=v*.12;d-=v*.12;top=.28+floors*(3.05+v*.08)
    shell(m,w,d,top,lod,wall,floors)
    if style=='pitched':
        roof(m,w,d,top+.14,1.5+v*.13,'roof_slate' if v!=1 else 'roof_tile',lod)
        chimney(m,-w*.30,-d*.17,top+2,lod)
    else:
        flat_roof(m,w,d,top,lod)
        roof_vent(m,w*.27,-d*.2,top+.2,lod)
    entrance(m,d/2,lod,width=2.8 if kind=='library' else 2.4,columns=kind=='library')
    return m,top,w,d


def school(variant,lod):
    m,top,w,d=civic(variant,lod,'school',8.4,5.8,2,['wall_brick','wall_plaster','wall_stone'][variant-1],'pitched')
    # Pediment and raised central clock distinguish the school from residences.
    front_gable_roof(m,2.6,1.05,top+.3,.85,'roof_slate',z=d/2-.25)
    if not lod:
        m.tube('trim',(0,top+.50,d/2+.29),(0,top+.50,d/2+.33),.30,20)
        m.box('metal',(.07,top+.53,d/2+.36),(.18,.025,.025));m.box('metal',(0,top+.6,d/2+.36),(.025,.22,.025))
    return m


def library(variant,lod):
    m,top,w,d=civic(variant,lod,'library',8.2,5.7,2,['wall_stone','wall_brick','wall_plaster'][variant-1],'flat' if variant==3 else 'pitched')
    # Deep stone portico and paired columns, with an unlettered entablature.
    for xx in (-1.24,1.24):
        m.box('trim',(xx,.45,d/2+.95),(.46,.26,.46))
        m.box('trim',(xx,2.62,d/2+.95),(.46,.20,.46))
    m.box('wall_stone',(0,2.96,d/2+.57),(3.3,.35,1.48))
    return m


def hospital(variant,lod):
    m,top,w,d=civic(variant,lod,'hospital',9.1,5.4,3,['wall_plaster','wall_concrete','wall_brick'][variant-1],'flat')
    # Raised helipad: geometric annulus and an H, with no words or logos.
    y=top+.225;r=1.58;n=24 if not lod else 12
    for i in range(n):
        a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
        m.face('trim',[(rr*math.cos(t)-.65,y,rr*math.sin(t)) for rr,t in [(r,a),(r,b),(r-.085,b),(r-.085,a)]],[0,1,0])
    for xx in (-1.17,-.13):m.box('trim',(xx,y+.012,0),(.12,.024,1.8))
    m.box('trim',(-.65,y+.012,0),(1.04,.024,.12))
    m.box('wall_concrete',(w*.30,top+.72,-d*.2),(1.35,1.1,1.25));m.box('roof_metal',(w*.30,top+1.32,-d*.2),(1.55,.12,1.45))
    return m


def police_station(variant,lod):
    m,top,w,d=civic(variant,lod,'police_station',7.6,5.8,2,['wall_brick','wall_stone','wall_concrete'][variant-1],'pitched' if variant==1 else 'flat')
    # Secure windows, radio mast and roof service bulkhead.
    if not lod:
        for xx in (-w*.29,w*.29):
            for dx in (-.30,0,.30):m.box('metal',(xx+dx,1.95,d/2+.06),(.025,1.2,.035))
    mast_y=top+(.7 if variant==1 else .2)
    m.tube('metal',(w*.3,mast_y,-.8),(w*.3,mast_y+2,-.8),.035,6)
    if not lod:beam(m,'metal',(w*.3-.45,mast_y+1.55,-.8),(w*.3+.45,mast_y+1.55,-.8),.025)
    return m


def fire_station(variant,lod):
    v=variant-1;m=Mesh();w=8.6+v*.1;d=5.9-v*.15;top=4.6+v*.15
    # Two tall real appliance-bay openings, framed roller doors, attached hose tower.
    doors=[(-3.5,-.65,.28,3.65,'door'),(.65,3.5,.28,3.65,'door')]
    shell(m,w,d,top,lod,['wall_brick','wall_plaster','wall_concrete'][v],1,columns=0,doors=doors)
    flat_roof(m,w,d,top,lod)
    for x in (-2.075,2.075):
        if not lod:
            for yy in np.arange(.5,3.5,.3):m.box('metal',(x,yy,d/2+.025),(2.72,.035,.05))
            for dx in (-.75,.75):m.box('glass',(x+dx,2.8,d/2+.04),(.55,.4,.06))
    x=-w/2+.9;z=-d/2+1.0;h=9.2+v*.7
    m.box('wall_brick',(x,h/2,z),(1.8,h,2.0));m.box('trim',(x,h+.08,z),(2.05,.16,2.25))
    if not lod:
        f=Facade(m,(x,0,z+1),(1,0,0),(0,0,1),1.8,top+.8,h-.3,'wall_brick',lod)
        # Inset dark louvres on top of the solid drying-tower shaft.
        for yy in np.arange(top+1.2,h-1,.9):
            m.box('glass',(x,yy,z+1.025),(.52,.58,.04))
            m.box('trim',(x,yy+.34,z+1.05),(.7,.07,.12))
    return m


def grain_silo(variant,lod):
    m=Mesh();n=32 if not lod else 12
    m.box('wall_concrete',(0,.16,0),(6.9,.32,6.8))
    for x,z,h in [(-1.7,0,10),(1.7,0,9.2)]:
        m.tube('metal',(x,.32,z),(x,h,z),1.5,n)
        m.tube('roof_metal',(x,h,z),(x,h+1.5,z),1.62,n,r_top=.08)
        if not lod:
            for yy in np.arange(.6,h,.65):m.tube('trim',(x,yy,z),(x,yy+.035,z),1.515,n)
            for xx in (x-.23,x+.23):beam(m,'metal',(xx,.4,1.51),(xx,h+.5,1.51),.035)
            for yy in np.arange(.5,h+.4,.32):beam(m,'metal',(x-.23,yy,1.54),(x+.23,yy,1.54),.025)
        # Top fill pipe, bottom unloading chute and service door.
        m.tube('metal',(x,h+.8,0),(x,h+1.8,0),.1,6)
        m.box('metal',(x,.75,1.48),(.65,.85,.25))
        beam(m,'metal',(x,.8,1.5),(x,.55,2.1),.25)
    beam(m,'metal',(-1.7,10.4,0),(1.7,10.4,0),.18)
    return m


def bank(variant,lod):
    m,top,w,d=civic(variant,lod,'bank',8.2,5.5,2,'wall_stone','flat' if variant==3 else 'pitched')
    # Monumental six-column portico; capitals and bases stay distinct in silhouette.
    z=d/2+.72
    for x in np.linspace(-3.15,3.15,6):
        m.box('trim',(x,.45,z),(.52,.34,.52))
        m.tube('wall_stone',(x,.62,z),(x,4.18,z),.20,12 if not lod else 6,r_top=.17)
        m.box('trim',(x,4.28,z),(.52,.20,.52))
    m.box('wall_stone',(0,4.54,z-.28),(7.35,.32,1.48))
    front_gable_roof(m,7.35,1.48,4.73,1.1,'roof_slate',z=z-.28)
    return m


def office_tower(variant,lod):
    m=Mesh();v=variant-1;w=6.3+v*.5;d=6.1-v*.35;floors=12;floorh=3.15;top=.3+floors*floorh
    m.box('wall_stone',(0,.15,0),(w+.65,.3,d+.65))
    # Continuous glazed curtain walls behind structural concrete fins, metric UVs.
    m.box('glass',(0,(top+.3)/2,0),(w,top-.3,d))
    for x in (-w/2,w/2):
        for z in (-d/2,d/2):m.box('wall_concrete',(x,top/2,z),(.28,top,.28))
    for level in range(1,floors+1):
        y=.3+level*floorh
        for z in (-d/2-.025,d/2+.025):m.box('wall_concrete',(0,y,z),(w+.25,.18,.18))
        for x in (-w/2-.025,w/2+.025):m.box('wall_concrete',(x,y,0),(.18,.18,d-.12))
    if not lod:
        for x in np.linspace(-w/2+.7,w/2-.7,6):
            for z in (-d/2-.025,d/2+.025):m.box('metal',(x,top/2,z),(.055,top-.5,.08))
        for z in np.linspace(-d/2+.8,d/2-.8,5):
            for x in (-w/2-.025,w/2+.025):m.box('metal',(x,top/2,z),(.08,top-.5,.055))
    flat_roof(m,w,d,top,lod)
    m.box('wall_concrete',(w*.18,top+.8,-d*.18),(w*.4,1.2,d*.38))
    m.box('roof_metal',(w*.18,top+1.46,-d*.18),(w*.4+.2,.12,d*.38+.2))
    entrance(m,d/2,lod,3.2)
    if variant==2:m.tube('metal',(0,top+1.52,0),(0,top+4.0,0),.055,6)
    return m


def stack(m,x,z,y,height,lod,r=.42,role='wall_brick',marker='Smoke_Industry_0'):
    n=20 if not lod else 8
    m.tube(role,(x,y,z),(x,height-.16,z),r,n,r_top=r*.72)
    # Open dark chimney bore, annular coping, marker precisely at its opening.
    outer=r*.87;inner=r*.52
    for i in range(n):
        a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
        def p(t,rr,yy):return (x+rr*math.cos(t),yy,z+rr*math.sin(t))
        m.face('trim',[p(a,outer,height),p(b,outer,height),p(b,inner,height),p(a,inner,height)],[0,1,0])
        m.face('metal',[p(a,inner,height),p(b,inner,height),p(b,inner,height-.3),p(a,inner,height-.3)],[-math.cos((a+b)/2),0,-math.sin((a+b)/2)])
        m.face(role,[p(a,outer,height-.16),p(b,outer,height-.16),p(b,outer,height),p(a,outer,height)],[math.cos((a+b)/2),0,math.sin((a+b)/2)])
    m.markers[marker]=[x,height,z]
    if not lod:
        for yy in np.arange(y+.6,height-.5,2):m.tube('metal',(x,yy,z),(x,yy+.07,z),r*(1-(yy-y)/(height-y)*.28)+.025,n)


def sawtooth(m,w,d,y,lod,count=3,offset_z=0):
    bay=d/count
    for j in range(count):
        z=offset_z-d/2+j*bay
        # Solid pitched wedge, northlight vertical face and roof edge gutters.
        vertices=[(-w/2,y,z),(w/2,y,z),(-w/2,y,z+bay),(w/2,y,z+bay),(-w/2,y+1.15,z+bay),(w/2,y+1.15,z+bay)]
        m.solid('roof_metal',vertices,[(0,2,3,1),(0,1,5,4),(2,4,5,3),(0,4,2),(1,3,5)])
        m.box('glass',(0,y+.65,z+bay+.015),(w-.4,.72,.04))
        if not lod:
            for x in np.linspace(-w/2+.3,w/2-.3,7):m.box('metal',(x,y+.65,z+bay+.045),(.045,.78,.05))
            m.box('metal',(0,y+.03,z),(w+.1,.10,.12))


def factory_brick(variant,lod):
    m=Mesh();v=variant-1;w=7.8;d=5.5;top=4.0+v*.2
    shell(m,w,d,top,lod,'wall_brick',1,2,z=.75)
    sawtooth(m,w+.25,d+.2,top+.1,lod,3 if variant!=2 else 4,offset_z=.75)
    # Tall twin stacks behind the production hall, boiler base and intake ducts.
    for i,(x,h) in enumerate([(-2.2,12.5+v),(.4,10.8+v*.8)]):
        m.box('wall_brick',(x,.65,-3.15),(1.35,1.3,1.4))
        stack(m,x,-3.15,1.3,h,lod,.47,marker=f'Smoke_Industry_{i}')
        beam(m,'metal',(x,2.3,-3.15),(x,2.3,-1.85),.36)
    entrance(m,3.5,lod,2.2)
    return m


def warehouse(variant,lod):
    m=Mesh();v=variant-1;w=8.6;d=6.5;top=4.4+v*.3
    shell(m,w,d,top,lod,'metal',1,0,doors=[(-1.65,1.65,.28,3.65,'door')])
    front_gable_roof(m,w,d,top+.1,1.4+v*.1,'roof_metal')
    m.box('wall_concrete',(0,.45,d/2+.45),(4.2,.9,1.1))
    m.box('roof_metal',(0,3.95,d/2+.65),(4.5,.16,1.6))
    if not lod:
        for x in np.arange(-w/2+.3,w/2,.42):
            for z in (-d/2-.02,d/2+.02):
                if z>0 and abs(x)<1.8:continue
                m.box('metal',(x,top/2+.14,z),(.035,top-.4,.045))
        for y in np.arange(.7,3.5,.32):m.box('metal',(0,y,d/2+.035),(3.15,.035,.06))
        for x in (-w/2+.15,w/2-.15):m.tube('metal',(x,.3,d/2),(x,top,d/2),.05,6)
    roof_vent(m,-2,-1,top+.9,lod)
    return m


def cooling_tower(m,x,z,lod):
    n=28 if not lod else 10
    # Hollow hyperboloid shell with visible inner lip; no cap across the opening.
    profile=[(.6,1.65),(1.2,1.95),(3.0,1.55),(5.5,1.15),(7.4,1.28),(8.8,1.65)]
    if lod:profile=[profile[i] for i in (0,1,3,5)]
    for (y0,r0),(y1,r1) in zip(profile,profile[1:]):
        for i in range(n):
            a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
            def p(y,r,t):return (x+r*math.cos(t),y,z+r*math.sin(t))
            mid=(a+b)/2
            ns=[unit([math.cos(t),-(r1-r0)/(y1-y0),math.sin(t)]) for t in (a,b,b,a)]
            m.face('wall_concrete',[p(y0,r0,a),p(y0,r0,b),p(y1,r1,b),p(y1,r1,a)],[math.cos(mid),0,math.sin(mid)],ns,
                   [[a*(r0+r1)/2,y0],[b*(r0+r1)/2,y0],[b*(r0+r1)/2,y1],[a*(r0+r1)/2,y1]])
            m.face('wall_concrete',[p(y0,r0-.14,a),p(y0,r0-.14,b),p(y1,r1-.14,b),p(y1,r1-.14,a)],[-math.cos(mid),0,-math.sin(mid)],[-v for v in ns],
                   [[a*(r0+r1-.28)/2,y0],[b*(r0+r1-.28)/2,y0],[b*(r0+r1-.28)/2,y1],[a*(r0+r1-.28)/2,y1]])
    y,r=profile[-1]
    for i in range(n):
        a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
        def p(t,rr,yy):return (x+rr*math.cos(t),yy,z+rr*math.sin(t))
        m.face('trim',[p(a,r,y),p(b,r,y),p(b,r-.14,y),p(a,r-.14,y)],[0,1,0])
        bottom_y,bottom_r=profile[0]
        m.face('wall_concrete',[p(a,bottom_r,bottom_y),p(b,bottom_r,bottom_y),p(b,bottom_r-.14,bottom_y),p(a,bottom_r-.14,bottom_y)],[0,-1,0])
    for i in range(6 if not lod else 4):
        t=i*2*math.pi/(6 if not lod else 4)
        beam(m,'wall_concrete',(x+1.3*math.cos(t),.15,z+1.3*math.sin(t)),(x+1.8*math.cos(t),1.2,z+1.8*math.sin(t)),.22)
    m.markers['Smoke_Industry_1']=[x,y,z]


def power_station(variant,lod):
    m=Mesh();v=variant-1
    m.box('wall_concrete',(0,.12,0),(9.3,.24,8.6))
    shell(m,4.4,6.1,5.4+v*.3,lod,'wall_concrete',1,2,x=-2.1,z=.35)
    flat_roof(m,4.4,6.1,5.4+v*.3,lod,x=-2.1,z=.35)
    cooling_tower(m,2.4,-1.25,lod)
    stack(m,-2.2,-3.6,.24,13+v,lod,.42,'wall_concrete')
    # Transformer yard: ceramic insulators, fins and the pipe from boiler to tower.
    m.box('metal',(2.25,.8,2.5),(2.3,1.2,1.5))
    for x in (1.55,2.25,2.95):m.tube('trim',(x,1.4,2.5),(x,2.15,2.5),.12,8 if not lod else 6)
    beam(m,'metal',(-.1,2.8,-.7),(1.1,2.8,-.7),.32)
    if not lod:
        for x in np.arange(1.2,3.4,.2):m.box('metal',(x,.8,3.28),(.06,1.0,.18))
    return m


def water_tower(variant,lod):
    m=Mesh();n=28 if not lod else 10
    m.box('wall_concrete',(0,.18,0),(5.8,.36,5.8))
    for x in (-1.65,1.65):
        for z in (-1.65,1.65):
            beam(m,'metal',(x,.36,z),(x,9.5,z),.20)
    for y in (1,4,7):
        for z in (-1.65,1.65):
            beam(m,'metal',(-1.65,y,z),(1.65,y+2.7,z),.09)
            if not lod:beam(m,'metal',(1.65,y,z),(-1.65,y+2.7,z),.09)
        for x in (-1.65,1.65):beam(m,'metal',(x,y,-1.65),(x,y+2.7,1.65),.09)
    m.tube('metal',(0,8.7,0),(0,9.8,0),1.2,n,r_top=2.4)
    m.tube('metal',(0,9.8,0),(0,12.3,0),2.4,n)
    m.tube('roof_metal',(0,12.3,0),(0,13,0),2.45,n,r_top=.12)
    m.tube('metal',(.5,.36,.5),(.5,9.8,.5),.13,8)
    if not lod:
        for y in (9.85,11,12.25):m.tube('trim',(0,y,0),(0,y+.07,0),2.42,n)
        for x in (-.2,.2):beam(m,'metal',(x,.4,2.5),(x,12.4,2.5),.035)
        for y in np.arange(.5,12.4,.32):beam(m,'metal',(-.2,y,2.53),(.2,y,2.53),.025)
    return m


def church(variant,lod):
    m=Mesh();v=variant-1;w=5.4+v*.25;d=7.4;top=5.3+v*.25
    shell(m,w,d,top,lod,'wall_stone' if v!=1 else 'wall_brick',1,2,z=-.3)
    front_gable_roof(m,w,d,top+.1,2.25,'roof_slate',z=-.3)
    # Square bell tower, paired louvres, pyramidal stone spire (no insignia).
    x=-w/2+.7;z=2.2;h=10.4+v
    m.box('wall_stone',(x,h/2,z),(2.05,h,2.1))
    m.box('trim',(x,h+.08,z),(2.3,.16,2.35))
    m.tube('roof_slate',(x,h+.16,z),(x,h+4.6,z),1.66,4,r_top=.015)
    if not lod:
        for zz in (-1.06,1.06):
            for dx in (-.42,.42):
                m.box('glass',(x+dx,h-1.15,z+zz),(.44,1.25,.06))
                for yy in np.arange(h-1.65,h-.6,.17):m.box('metal',(x+dx,yy,z+zz*1.025),(.42,.035,.05))
        # Buttresses and tall lancet surrounds on the nave sides.
        for xx in (-w/2,w/2):
            for zz in (-2.8,-.5,1.6):
                m.box('wall_stone',(xx,2.3,zz),(.38,4.6,.42))
                m.box('trim',(xx,4.7,zz),(.45,.18,.5))
    entrance(m,d/2-.3,lod,2.0,3.0,x=.65)
    return m


def mosque(variant,lod):
    m=Mesh();v=variant-1;w=6.4+v*.15;d=6.0;top=4.6+v*.25
    shell(m,w,d,top,lod,'wall_plaster' if v!=1 else 'wall_stone',1,2)
    flat_roof(m,w,d,top,lod)
    n=24 if not lod else 10
    m.tube('wall_stone',(0,top+.2,-.2),(0,top+.85,-.2),2.12,n)
    m.dome('roof_metal',(0,top+.85,-.2),2.3,2.5,n,8 if not lod else 3)
    m.tube('metal',(0,top+3.35,-.2),(0,top+3.85,-.2),.045,6)
    x=-4.05;z=-1.9;h=11.2+v*.7
    m.tube('wall_stone',(x,0,z),(x,1,z),.72,n)
    m.tube('wall_plaster',(x,1,z),(x,h,z),.46,n,r_top=.32)
    m.tube('trim',(x,h-2.1,z),(x,h-1.9,z),.75,n)
    m.tube('wall_plaster',(x,h-1.9,z),(x,h-1.2,z),.70,n)
    m.tube('roof_metal',(x,h,z),(x,h+1.8,z),.47,n,r_top=.02)
    if not lod:
        for a in np.linspace(0,2*math.pi,12,endpoint=False):
            m.tube('trim',(x+.69*math.cos(a),h-1.9,z+.69*math.sin(a)),(x+.69*math.cos(a),h-1.2,z+.69*math.sin(a)),.025,6)
    entrance(m,d/2,lod,3.6,3.1,columns=True)
    return m


def railway_station(variant,lod):
    m=Mesh();v=variant-1;w=8.3;d=4.4;top=6.0+v*.2
    shell(m,w,d,top,lod,['wall_brick','wall_stone','wall_plaster'][v],2,2,z=-.9)
    roof(m,w,d,top+.12,1.65,'roof_slate',lod,z=-.9)
    m.box('wall_stone',(0,.14,.5),(9.4,.28,8.6))
    # Broad platform canopy with real steel posts and open truss brackets.
    m.box('roof_metal',(0,3.25,2.5),(9.35,.16,2.9))
    for x in np.linspace(-4,4,5):
        beam(m,'metal',(x,.28,3.5),(x,3.17,3.5),.11)
        if not lod:
            beam(m,'metal',(x,2.2,3.5),(x,3.15,2.7),.06)
            beam(m,'metal',(x,2.2,3.5),(x,3.15,3.9),.06)
    # Front central clock under the eave, hands but no letters/numerals.
    if not lod:
        m.tube('trim',(0,top-.8,1.32),(0,top-.8,1.39),.43,20)
        m.box('metal',(.1,top-.8,1.43),(.24,.025,.025));m.box('metal',(0,top-.68,1.43),(.025,.28,.025))
    chimney(m,-2.7,-1.5,top+2.05,lod)
    return m


def market_hall(variant,lod):
    m=Mesh();v=variant-1;w=8.4;d=6.7;top=4.3+v*.2
    shell(m,w,d,top,lod,['wall_brick','wall_stone','wall_plaster'][v],1,2,doors=[(-1.4,1.4,.28,3.3,'door')])
    front_gable_roof(m,w,d,top+.1,1.7,'roof_metal')
    # Glazed clerestory lantern, raised roof and projecting entrance hood.
    m.box('glass',(0,top+1.6,0),(2.2,.85,5.5))
    front_gable_roof(m,2.4,5.7,top+2.03,.55,'roof_metal')
    if not lod:
        for z in np.linspace(-2.6,2.6,7):
            for x in (-1.12,1.12):m.box('metal',(x,top+1.6,z),(.07,.85,.06))
        for x in (-3.1,3.1):
            for z in (-d/2,d/2):m.box('wall_stone',(x,2.1,z),(.32,4.2,.32))
    entrance(m,d/2,lod,3.2,3.6,columns=True)
    return m


def barracks(variant,lod):
    m,top,w,d=civic(variant,lod,'barracks',9.0,5.3,2,['wall_brick','wall_plaster','wall_concrete'][variant-1],'pitched')
    if not lod:
        # Plain repeated side entries, plain roof vents; no flags or unit emblems.
        for x in (-3,3):
            m.box('wood',(x,1.2,d/2+.025),(.85,1.85,.06))
            m.box('wall_stone',(x,.12,d/2+.35),(1.2,.24,.7))
    return m


def aerial(m,x,z,y,lod,h=2.7):
    m.tube('metal',(x,y,z),(x,y+h,z),.045,6)
    if not lod:
        for yy,ww in ((y+h*.55,.75),(y+h*.8,.5)):
            beam(m,'metal',(x-ww/2,yy,z),(x+ww/2,yy,z),.027)
        for dx,dz in ((.7,0),(-.7,0),(0,.7)):
            beam(m,'metal',(x,y+h*.7,z),(x+dx,y,z+dz),.016)


def command_bunker(variant,lod):
    m=Mesh();v=variant-1;w=8.2;d=6.2;top=2.75+v*.12
    shell(m,w,d,top,lod,'wall_concrete',1,2,doors=[(-.6,.6,.28,2.25,'door')])
    # Heavy bevelled roof cap; a low shell protected by angled concrete shoulders.
    vertices=[(sx*w/2,top,sz*d/2) for sz in (-1,1) for sx in (-1,1)]+[(sx*(w/2-.5),top+.7,sz*(d/2-.5)) for sz in (-1,1) for sx in (-1,1)]
    m.solid('wall_concrete',vertices,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)])
    entrance(m,d/2,lod,1.9,2.45)
    aerial(m,-2.5,-1.4,top+.7,lod,3.1+v*.3);aerial(m,2.5,-1.4,top+.7,lod,1.9)
    if not lod:
        for x in (-2.6,2.6):
            for dx in (-.3,0,.3):m.box('metal',(x+dx,1.9,d/2+.05),(.04,1.0,.06))
        roof_vent(m,1.4,0,top+.7,lod)
    return m


def dish(m,center,r,lod):
    c=np.asarray(center);n=24 if not lod else 10;rings=6 if not lod else 3;focal=1.2
    def point(rr,t,back=False):return c+np.array([rr*math.cos(t),rr*math.sin(t),rr*rr/(4*focal)-(.08 if back else 0)])
    for back in (False,True):
        sign=-1 if back else 1
        for j in range(rings):
            r0=r*j/rings;r1=r*(j+1)/rings
            for i in range(n):
                a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
                specs=[(r0,a),(r1,a),(r1,b)] if j==0 else [(r0,a),(r1,a),(r1,b),(r0,b)]
                ps=[point(rr,t,back) for rr,t in specs]
                ns=[unit([-rr/(2*focal)*math.cos(t),-rr/(2*focal)*math.sin(t),1])*sign for rr,t in specs]
                # Planar metre projection; normals describe the shallow paraboloid.
                m.face('metal',ps,[0,0,sign],ns)
        for i in range(n):
            a=2*math.pi*i/n;b=2*math.pi*(i+1)/n
            if not back:m.face('trim',[point(r,a),point(r,b),point(r,b,True),point(r,a,True)],[math.cos((a+b)/2),math.sin((a+b)/2),0])
    # Feed horn and three support struts, genuinely attached to the bowl rim.
    feed=c+np.array([0,0,focal]);m.tube('metal',feed,feed+[0,0,.28],.12,8 if not lod else 6)
    for t in (math.pi/2,7*math.pi/6,11*math.pi/6):beam(m,'metal',point(r*.93,t),feed,.045 if not lod else .06)


def radar_station(variant,lod):
    m=Mesh();v=variant-1;top=2.9
    shell(m,6.4,5.2,top,lod,'wall_concrete',1,2)
    flat_roof(m,6.4,5.2,top,lod)
    m.tube('wall_concrete',(0,top+.2,0),(0,6.0+v*.3,0),.58,16 if not lod else 8)
    m.box('metal',(0,6.15+v*.3,0),(1.2,.3,1.25))
    beam(m,'metal',(0,6.3+v*.3,0),(0,7.5+v*.3,.4),.30)
    dish(m,(0,7.5+v*.3,.5),1.85+v*.15,lod)
    aerial(m,-2.5,-1.8,top+.2,lod,3.5)
    entrance(m,2.6,lod,1.9,2.6)
    return m


def arch_roof(m,w,d,y,rise,lod):
    n=28 if not lod else 10;rx=w/2+.18;rz=rise
    for i in range(n):
        a=math.pi*i/n;b=math.pi*(i+1)/n
        def p(t,z,inner=False):return ((rx-(.14 if inner else 0))*math.cos(t),y+(rz-(.14 if inner else 0))*math.sin(t),z)
        for inner in (False,True):
            sign=-1 if inner else 1;ps=[p(a,-d/2-.18,inner),p(a,d/2+.18,inner),p(b,d/2+.18,inner),p(b,-d/2-.18,inner)]
            ns=[unit([math.cos(t)/rx,math.sin(t)/rz,0])*sign for t in (a,a,b,b)]
            length=(b-a)*math.sqrt((rx*math.sin((a+b)/2))**2+(rz*math.cos((a+b)/2))**2)
            m.face('roof_metal',ps,[math.cos((a+b)/2)*sign,math.sin((a+b)/2)*sign,0],ns,[[0,0],[d+.36,0],[d+.36,length],[0,length]])
        for z,sign in ((-d/2-.18,-1),(d/2+.18,1)):
            m.face('trim',[p(a,z),p(b,z),p(b,z,True),p(a,z,True)],[0,0,sign])
    for t in (0,math.pi):
        m.face('roof_metal',[p(t,-d/2-.18),p(t,d/2+.18),p(t,d/2+.18,True),p(t,-d/2-.18,True)],[0,-1,0])
    # End gables fill the space above the door wall, inside the curved roof.
    for z,sign in ((-d/2,-1),(d/2,1)):
        ps=[((rx-.13)*math.cos(t),y+(rz-.13)*math.sin(t),z) for t in np.linspace(0,math.pi,n+1)]
        m.face('metal',ps,[0,0,sign])
    if not lod:
        for z in np.linspace(-d/2,d/2,7):
            for i in range(n):
                a=math.pi*i/n;b=math.pi*(i+1)/n
                beam(m,'metal',((rx+.025)*math.cos(a),y+(rz+.025)*math.sin(a),z),((rx+.025)*math.cos(b),y+(rz+.025)*math.sin(b),z),.035)


def hangar(variant,lod):
    m=Mesh();v=variant-1;w=8.4+v*.15;d=6.6-v*.1;top=3.3
    shell(m,w,d,top,lod,'metal',1,0,doors=[(-3.2,3.2,.28,3.12,'door')])
    arch_roof(m,w,d,top,3.1+v*.25,lod)
    m.box('wall_concrete',(0,.11,d/2+.65),(w+.2,.22,1.7))
    m.box('metal',(0,3.22,d/2+.12),(7.1,.13,.20))
    if not lod:
        for x in np.linspace(-3.1,3.1,9):m.box('metal',(x,1.7,d/2+.025),(.045,2.8,.065))
        for x in (-3.38,3.38):m.box('metal',(x,1.75,d/2+.04),(.12,3.0,.16))
        for x in (-2,0,2):m.box('glass',(x,top+.6,d/2+.025),(.9,.45,.04))
    return m


def control_tower(variant,lod):
    m=Mesh();v=variant-1;h=10.8+v*1.2;n=8
    shell(m,3.0,3.2,h,lod,'wall_concrete',3,2)
    # Splayed panoramic cab, wraparound windows, gallery and broad overhanging roof.
    m.tube('wall_concrete',(0,h,0),(0,h+.85,0),1.65,n,r_top=2.45)
    m.tube('glass',(0,h+.85,0),(0,h+3.0,0),2.45,n,r_top=2.7)
    m.tube('roof_metal',(0,h+3.0,0),(0,h+3.24,0),2.95,n)
    for i in range(n):
        t=2*math.pi*i/n
        beam(m,'metal',(2.45*math.cos(t),h+.85,2.45*math.sin(t)),(2.7*math.cos(t),h+3,2.7*math.sin(t)),.085)
    aerial(m,.6,-.5,h+3.24,lod,1.9)
    entrance(m,1.6,lod,1.8,2.6)
    if not lod:
        m.box('wood',(0,1.4,1.62),(.8,2.1,.04))
        for yy in np.arange(.9,h-.5,.6):m.box('metal',(1.56,yy,-.45),(.06,.04,.55))
    return m


def harbour_crane(variant,lod):
    m=Mesh();n=12 if not lod else 6
    # Four bogies on rails and an open portal frame, all built at real crane scale.
    for x in (-2.8,2.8):
        m.box('metal',(x,.08,0),(.22,.16,7.4))
        for z in (-2.5,2.5):
            m.box('metal',(x,.55,z),(1.0,.55,1.2))
            for dz in (-.33,.33):m.tube('metal',(x-.55,.31,z+dz),(x+.55,.31,z+dz),.25,n)
            beam(m,'metal',(x,.8,z),(x*.70,8.5,z*.60),.34)
    for z in (-1.5,1.5):beam(m,'metal',(-2.0,8.5,z),(2.0,8.5,z),.5)
    for x in (-2.0,2.0):beam(m,'metal',(x,8.5,-1.5),(x,8.5,1.5),.5)
    m.tube('metal',(0,8.5,0),(0,9.3,0),1.25,16 if not lod else 8)
    m.box('metal',(0,10.2,-.45),(2.6,1.8,3.1))
    m.box('glass',(1.6,10.0,.85),(1.3,1.8,1.6));m.box('roof_metal',(1.6,10.98,.85),(1.5,.16,1.8))
    m.box('wall_concrete',(0,11,-3.0),(2.3,1.5,1.5))
    a=np.array([0,11,-.4]);b=np.array([0,17,4.25])
    # Twin boom chords with a spatial web; reduced LOD retains the same open silhouette.
    for x in (-.48,.48):
        for dy in (-.3,.3):beam(m,'metal',a+[x,dy,0],b+[x,dy,0],.12)
    divisions=9 if not lod else 4
    for i in range(divisions):
        p=a+(b-a)*i/divisions;q=a+(b-a)*(i+1)/divisions
        for x in (-.48,.48):beam(m,'metal',p+[x,-.3,0],q+[x,.3,0],.065)
        beam(m,'metal',p+[-.48,.3,0],q+[.48,.3,0],.065)
    beam(m,'metal',(0,10.9,-1.5),(0,16,-1.5),.25)
    beam(m,'metal',(0,16,-1.5),b+[0,.3,0],.045)
    beam(m,'metal',(0,16,-1.5),(0,11.8,-3.0),.045)
    for x in (-.18,.18):beam(m,'metal',b+[x,0,0],(x,8.6,4.25),.035)
    m.box('metal',(0,8.35,4.25),(.65,.5,.45))
    # Open J-shaped hook.
    ps=[(0,8.1,4.25),(0,7.6,4.25),(.25,7.4,4.25),(.48,7.65,4.25)]
    for p,q in zip(ps,ps[1:]):beam(m,'metal',p,q,.12)
    if not lod:
        for y in np.arange(1.1,8.4,.33):beam(m,'metal',(-2.05,y,-1.65),(-1.65,y,-1.65),.03)
    return m


def lighthouse(variant,lod):
    m=Mesh();n=32 if not lod else 12
    m.tube('wall_stone',(0,0,0),(0,.55,0),2.45,n)
    m.tube('wall_plaster',(0,.55,0),(0,15.8,0),1.65,n,r_top=1.0)
    m.tube('wall_stone',(0,15.8,0),(0,16.15,0),1.05,n,r_top=2.05)
    m.tube('metal',(0,16.15,0),(0,16.32,0),2.05,n)
    m.tube('glass',(0,16.32,0),(0,18.35,0),1.27,n)
    m.tube('roof_metal',(0,18.35,0),(0,19.55,0),1.52,n,r_top=.06)
    # Rail gallery outside the lantern, deliberately open rather than a solid drum.
    ring=16 if not lod else 8
    for i in range(ring):
        a=i*2*math.pi/ring;b=(i+1)*2*math.pi/ring
        beam(m,'metal',(1.95*math.cos(a),16.32,1.95*math.sin(a)),(1.95*math.cos(a),17.25,1.95*math.sin(a)),.045)
        beam(m,'metal',(1.95*math.cos(a),17.25,1.95*math.sin(a)),(1.95*math.cos(b),17.25,1.95*math.sin(b)),.045)
        if i%(2 if not lod else 1)==0:
            beam(m,'metal',(1.28*math.cos(a),16.32,1.28*math.sin(a)),(1.28*math.cos(a),18.35,1.28*math.sin(a)),.06)
    m.box('wood',(0,1.55,1.63),(.9,2.0,.10))
    for x in (-.53,.53):m.box('trim',(x,1.55,1.64),(.16,2.25,.24))
    m.box('trim',(0,2.7,1.64),(1.22,.18,.25))
    for i in range(3):m.box('wall_stone',(0,.15+i*.12,2.08-i*.15),(1.4,.3+i*.24,1.2-i*.3))
    if not lod:
        for y in (4.5,7.5,10.5,13.5):
            radius=1.65-(y-.55)/15.25*.65
            m.box('glass',(0,y,radius+.015),(.4,.75,.06))
            m.box('trim',(0,y+.42,radius+.04),(.55,.08,.13))
    return m


BUILDERS={f.__name__:f for f in (grain_silo,school,library,hospital,police_station,fire_station,bank,office_tower,factory_brick,warehouse,power_station,water_tower,church,mosque,railway_station,market_hall,barracks,command_bunker,radar_station,hangar,control_tower,harbour_crane,lighthouse)}
SINGLETONS={'grain_silo','water_tower','harbour_crane','lighthouse'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--types',nargs='+',choices=tuple(BUILDERS),default=list(BUILDERS));p.add_argument('--validate-only',action='store_true')
    p.add_argument('--output-dir',type=Path,default=ART/'buildings');p.add_argument('--manifest',type=Path,default=ART/'MANIFEST.json');p.add_argument('--report',type=Path)
    args=p.parse_args();args.output_dir.mkdir(parents=True,exist_ok=True);entries=[]
    for kind in args.types:
        for variant in range(1,2 if kind in SINGLETONS else 4):
            path=args.output_dir/f'{kind}_{variant}.glb'
            if not args.validate_only:
                meshes=[BUILDERS[kind](variant,lod) for lod in (0,1)]
                low,high=meshes[0].bounds();shift=np.array([-(low[0]+high[0])/2,0,-(low[2]+high[2])/2])
                for m in meshes:m.remove_duplicates();m.shift(shift)
                export_glb(path,meshes,kind,variant)
            entry=validate(path)
            entry['notes']=entry['notes'].replace('native/tools/models/generate_buildings.py','native/tools/models/generate_buildings_extended.py with shared generate_buildings.py')
            entries.append(entry);print('PASS',path.name,entry['triangles'],entry['smoke_emitters'],flush=True)
    if not args.validate_only:
        manifest=json.loads(args.manifest.read_text(encoding='utf-8'));names={e['file'] for e in entries}
        args.manifest.write_text(json.dumps([e for e in manifest if e['file'] not in names]+entries,indent=2)+'\n',encoding='utf-8')
    if args.report:args.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
    print('Loaded back and validated',len(entries),'GLBs.')


if __name__=='__main__':main()
