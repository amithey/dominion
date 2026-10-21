#!/usr/bin/env python3
"""DOMINION Tier 7: ONE Abrams pilot. NumPy + Python standard library, no Blender.

Build: python native/tools/models/generate_vehicles.py
Check: python native/tools/models/generate_vehicles.py --validate-only
Optional: --output FILE --manifest FILE --report FILE --tree FILE --evidence FILE

One function per vehicle: m1a2_sepv3_abrams(). No other roster vehicle is built.
Shared parts and glTF IO live in vehicle_parts.py; Mesh is shared with the
building generator. The default export is intentionally gated to this pilot.
Body UVs are metres. Track U is the explicitly requested 0..1 loop exception;
track V is metres. All five material roles are white, roughness .8, metallic 0.
KHR_node_visibility hides LOD1, Wreck and collision on import into Godot 4.7.
LOD0 uses the exact canonical part names. LOD1 appends _LOD1 to keep names
globally unique for Godot; every node also carries its canonical_part role.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from vehicle_parts import (Mesh,unit,rotation,merge_mesh,profile_hull,loft,road_wheel,
                           end_wheel,track,hollow_muzzle,Rig,write_glb,read_glb,walk_nodes,ROLES)

ROOT=Path(__file__).resolve().parents[3]
ART=ROOT/'native/godot/assets/art'
SLUG='tank__m1a2_sepv3_abrams'
SOURCES=[
    {'url':'https://www.army.gov.au/equipment/vehicles-and-surveillance/m1a2-abrams-tank','use':'Official overall length 9.7 m, width 3.7 m, equipment height 3.09 m and general appearance.'},
    {'url':'https://www.gdls.com/abrams/','use':'SEPv3 external feature identification: angular Abrams armour, remote weapon station, advanced optics, under-armour APU.'},
    {'url':'https://www.army.mil/article/222100/2_8_cav_tests_abrams_upgrades_demonstrates_increased_lethality','use':'Army SEPv3 visual reference; no source photograph or external mesh is embedded.'},
    {'url':'https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_node_visibility','use':'Standards-based hidden wreck, collision proxy and inactive LOD.'},
]


def positioned(mesh,pivot):return merge_mesh(Mesh(),mesh,t=pivot)


def m1a2_sepv3_abrams(lod=0):
    """Original visual reconstruction of the Abrams SEPv3 exterior, not a generic tank.

    Seven paired road-wheel stations per side; rear sprockets, front idlers;
    long low glacis, faceted heavy cheeks, broad rear bustle/basket, 120 mm
    L/44-class smoothbore with evacuator, CITV, gunner optic, CROWS-LP and
    under-armour APU configuration. No optional TUSK/Trophy kit or markings.
    Exterior dimensions are reference-based; small fittings are simplified.
    """
    rig=Rig(lod);body=Mesh()
    profile_hull(body,'paint',[(3.48,.50,1.12),(3.90,1.02,1.30),(1.80,1.50,1.36),(-3.72,1.46,1.35),(-3.90,.86,1.24),(-3.48,.50,1.12)])
    # Rear turbine/exhaust plate, front glacis hatch and broad fender decks.
    body.box('metal_dark',(0,1.055,-3.915),(1.85,.56,.09))
    body.box('paint',(0,1.385,2.17),(.66,.085,.78),rotation((1,0,0),math.radians(12.9)))
    body.box('glass',(0,1.447,2.39),(.35,.045,.10))
    for side in (-1,1):
        body.box('paint',(side*1.56,1.445,-.04),(.53,.105,7.54))
        # Six separate skirt panels, leaving readable seams and the wheel bottoms visible.
        for i,z in enumerate(np.linspace(-2.67,2.63,6)):
            h=.70 if i>0 else .57
            body.box('paint',(side*1.79,1.50-h/2,z),(.12,h,1.015))
            if not lod:
                for zz in (-.36,.36):body.box('metal_dark',(side*1.858,1.36,z+zz),(.018,.035,.035))
        body.box('rubber',(side*1.47,.66,-3.82),(.61,.72,.065))
        body.box('paint',(side*1.25,1.13,3.77),(.29,.22,.20))
        body.box('glass',(side*1.25,1.14,3.88),(.18,.115,.025))
        if not lod:
            for sign in (-1,1):body.box('paint',(side*1.25+sign*.15,1.19,3.82),(.04,.28,.31))
            body.box('paint',(side*1.25,1.335,3.82),(.34,.035,.31))
            body.tube('metal_dark',(side*.95,.77,3.88),(side*.95,.77,3.96),.08,8)
            body.tube('metal_dark',(side*.95,.80,-3.88),(side*.95,.80,-3.96),.08,8)
    if not lod:
        for z in np.linspace(-3.48,-2.13,12):body.box('metal_dark',(0,1.478,z),(1.95,.025,.045))
        for z in np.linspace(-3.65,-3.28,7):body.box('paint',(0,1.07,z),(1.84,.035,.045))
        for x in (-1.07,1.07):body.box('paint',(x,1.51,-2.72),(.12,.10,1.12))
    body.remove_duplicates();rig.add('Hull',rig.root,(0,0,0),body,origin='ground centre of hull footprint')
    ring=Mesh();ring.tube('metal_dark',(0,1.445,.15),(0,1.575,.15),1.08,12 if lod else 28)
    rig.add('Turret_Ring','Hull',(0,1.50,.15),ring)
    turret=Mesh();pivot=(0,1.50,.15)
    bottom=[(-.48,1.60),( .48,1.60),(1.52,1.05),(1.60,-1.20),(1.30,-2.20),(-1.30,-2.20),(-1.60,-1.20),(-1.52,1.05)]
    top=[(-.48,.85),(.48,.85),(1.36,.52),(1.38,-1.25),(1.15,-2.08),(-1.15,-2.08),(-1.38,-1.25),(-1.36,.52)]
    loft(turret,'paint',[[[x,1.575,z+.15] for x,z in bottom],[[x,2.30,z+.15] for x,z in top]])
    # Distinct bustle with blow-out panels and the characteristic rear storage basket.
    for x in (-.59,.59):turret.box('paint',(x,2.319,-1.24),(1.10,.038,1.12))
    turret.box('paint',(0,1.99,-2.09),(2.62,.26,.26))
    if lod:
        turret.box('metal_dark',(0,2.10,-2.37),(2.94,.20,.40))
    else:
        for y in (1.92,2.16,2.37):turret.box('metal_dark',(0,y,-2.54),(2.92,.035,.035))
        for x in np.linspace(-1.45,1.45,9):turret.box('metal_dark',(x,2.15,-2.54),(.028,.48,.028))
        for side in (-1,1):
            for y in (1.92,2.37):turret.box('metal_dark',(side*1.45,y,-2.15),(.035,.035,.80))
            for z in (-2.53,-2.15,-1.78):turret.box('metal_dark',(side*1.45,2.15,z),(.03,.48,.03))
        for x in (-.88,.88):
            turret.box('paint',(x,2.36,-1.73),(.33,.08,.18))
            for z in (-.80,.05):turret.box('metal_dark',(x*1.48,2.25,z),(.05,.04,.18))
    rig.add('Turret','Hull',pivot,turret,'Y',yaw_degrees=[-180,180])
    # The gun origin is the trunnion. Geometry is authored in world metres,
    # then localised to this pivot by the exporter, preserving true hierarchy.
    gunpivot=np.array([0,1.96,1.35]);gun=Mesh()
    gun.box('paint',gunpivot+[0,0,.16],(.86,.61,.70))
    n=6 if lod else 16
    for a,b,r in ((.43,1.16,.125),(1.16,1.94,.108),(1.94,2.37,.165),(2.37,3.92,.105)):
        gun.tube('metal_dark',gunpivot+[0,0,a],gunpivot+[0,0,b],r,n)
    hollow_muzzle(gun,gunpivot+[0,0,3.92],gunpivot+[0,0,4.39],.084,.060,8 if lod else 16)
    if not lod:
        for z in (1.13,1.91,2.40,3.88):gun.tube('metal_dark',gunpivot+[0,0,z],gunpivot+[0,0,z+.04],.129 if z<1.5 else .115,12)
    gun.remove_duplicates()
    rig.add('Gun','Turret',gunpivot,gun,'X',elevation_degrees=[-8,20],positive_elevation_rotation_sign=-1,recoil_axis=[0,0,-1])
    rig.add('Muzzle','Gun',gunpivot+[0,0,4.39],forward=[0,0,1])
    # Seven road-wheel axle pivots per side, numbered REAR -> FRONT.
    for label,side in (('L',-1),('R',1)):
        x=side*1.46
        for i,z in enumerate(np.linspace(-2.40,2.40,7)):
            p=np.array([x,.50,z]);rig.add(f'Wheel_{label}{i}','Hull',p,positioned(road_wheel(lod,side),p),'X')
        for name,z,sprocket in (('Sprocket',-3.23,True),('Idler',3.23,False)):
            p=np.array([x,.65,z]);rig.add(name+'_'+label,'Hull',p,positioned(end_wheel(lod,sprocket),p),'X')
        for i,z in enumerate((-1.75,0,1.75)):
            p=np.array([x,1.00,z]);roller=None
            if not lod:
                roller=Mesh();roller.tube('rubber',p+[-.17,0,0],p+[.17,0,0],.14,8)
            rig.add(f'Roller_{label}{i}','Hull',p,roller,'X',lod1_mesh_omitted=bool(lod))
        rig.add('Track_'+label,'Hull',(x,0,0),track(lod,x),scroll_uv='U',u_loop=[0,1],v_units='metres')
    # Commander hatch opens about a rear hinge; independent from the rotating turret.
    hatch=Mesh();hatch.tube('paint',(.62,2.32,-.13),(.62,2.415,-.13),.30,8 if lod else 16)
    if not lod:
        hatch.box('metal_dark',(.62,2.44,-.17),(.24,.045,.045))
        for x in (.40,.84):hatch.box('paint',(x,2.405,-.40),(.09,.09,.12))
    rig.add('Hatch_Commander','Turret',(.62,2.34,-.43),hatch,'X',open_degrees=[0,-95])
    loader=Mesh();loader.tube('paint',(-.55,2.315,-.66),(-.55,2.395,-.66),.27,8 if lod else 12)
    rig.add('Hatch_Loader','Turret',(-.55,2.34,-.93),loader,'X')
    # M1A2's independent thermal viewer on the left roof, plus right gunner optic.
    optic=Mesh();optic.tube('paint',(-.79,2.30,.51),(-.79,2.61,.51),.205,8 if lod else 14)
    optic.box('paint',(-.79,2.66,.51),(.45,.26,.44));optic.box('glass',(-.79,2.66,.738),(.29,.16,.025))
    rig.add('CITV','Turret',(-.79,2.32,.51),optic,'Y')
    sight=Mesh();sight.box('paint',(.74,2.37,.70),(.50,.20,.55));sight.box('glass',(.74,2.38,.983),(.32,.11,.025))
    rig.add('Gunner_Sight','Turret',(.74,2.32,.70),sight)
    # Low-profile remotely controlled 12.7 mm station; highest rigid equipment 3.09 m.
    crows=Mesh();crows.tube('paint',(.60,2.42,-.80),(.60,2.56,-.80),.25,6 if lod else 12)
    crows.box('paint',(.60,2.69,-.80),(.29,.31,.32))
    crows.box('metal_dark',(.85,2.74,-.82),(.25,.37,.38));crows.box('glass',(.40,2.76,-.62),(.12,.14,.06))
    rig.add('CROWS','Turret',(.60,2.44,-.80),crows,'Y')
    mg=Mesh();mg.box('metal_dark',(.60,2.95,-.61),(.14,.28,.57))
    mg.tube('metal_dark',(.60,2.94,-.325),(.60,2.94,.42),.025,6 if lod else 10)
    rig.add('CROWS_Gun','CROWS',(.60,2.94,-.60),mg,'X')
    for label,side in (('L',-1),('R',1)):
        smoke=Mesh();smoke.box('paint',(side*1.37,1.97,.49),(.15,.28,.48))
        if not lod:
            direction=unit([side*.68,.42,.61])
            for row in range(2):
                for col in range(3):
                    p=np.array([side*1.45,1.88+row*.15,.31+col*.15])
                    smoke.tube('metal_dark',p,p+direction*.23,.041,8)
        rig.add('Smoke_Launcher_'+label,'Turret',(side*1.37,1.96,.49),smoke)
    for i,x in enumerate((-.94,.94),1):
        antenna=Mesh();p=np.array([x,2.34,-1.52])
        antenna.tube('metal_dark',p,p+[0,.12,0],.045,6 if lod else 10)
        antenna.tube('metal_dark',p+[0,.12,0],p+[0,1.36,-.055],.012,4 if lod else 6,r_top=.004)
        rig.add('Antenna_'+str(i),'Turret',p,antenna,'Y',flexible_whip=True)
    rig.add('Exhaust','Hull',(0,1.05,-3.96),forward=[0,0,-1])
    rig.add('Engine_Deck','Hull',(0,1.49,-2.75),forward=[0,1,0])
    hull_marks=Mesh();turret_marks=Mesh()
    for side in (-1,1):
        x=side*1.857
        hull_marks.face('markings',[(x,.99,-.40),(x,.99,.18),(x,1.28,.18),(x,1.28,-.40)],[side,0,0])
        # Turret decal conforms to the sloping cheek side; no floating panel.
        points=[]
        for y,z in ((1.82,-.98),(1.82,-.40),(2.08,-.40),(2.08,-.98)):
            xx=side*(1.60+(1.38-1.60)*(y-1.575)/(2.30-1.575)+.006)
            points.append((xx,y,z))
        turret_marks.face('markings',points,[side,.30,0])
    rig.add('Markings_Hull','Hull',(0,0,0),hull_marks)
    rig.add('Markings_Turret','Turret',(0,1.50,.15),turret_marks)
    return rig


def make_wreck(rig):
    """Single static wreck mesh: exposed ring and turret physically beside the hull."""
    body=Mesh();detached=Mesh();byname={p['name']:p for p in rig.parts}
    def turret_part(part):
        name=part['name']
        while name in byname:
            if name=='Turret':return True
            name=byname[name]['parent']
        return False
    remap={'paint':'metal_dark','glass':None,'markings':None}
    for part in rig.parts:
        if part['mesh'] is None or part['name'] in ('Turret_Ring','Markings'):continue
        merge_mesh(detached if turret_part(part) else body,part['mesh'],roles=remap)
    # Open the hull deck under the missing turret. This is actual missing geometry.
    g=body.groups['metal_dark'];p=np.array(g[0]);fs=np.array(g[3]).reshape(-1,3);keep=[]
    for f in fs:
        q=p[f]
        deck=np.all((np.isclose(q[:,2],1.80)|np.isclose(q[:,2],-3.72)) & (np.isclose(q[:,1],1.50)|np.isclose(q[:,1],1.46)))
        if not deck:keep.extend(f.tolist())
    g[3]=keep
    outer=[(-1.35,-3.72),(0,-3.72),(1.35,-3.72),(1.355,-.96),(1.36,1.80),(0,1.80),(-1.36,1.80),(-1.355,-.96)]
    inner=[]
    def deck_y(z):return 1.46+(z+3.72)/5.52*.04
    for x,z in outer:
        v=unit([x,z-.15]);inner.append((v[0]*.94,.15+v[1]*.94))
    for i in range(8):
        j=(i+1)%8;coords=[outer[i],outer[j],inner[j],inner[i]]
        body.face('metal_dark',[[x,deck_y(z),z] for x,z in coords],[0,1,0])
        a,b=inner[i],inner[j]
        body.face('metal_dark',[[a[0],deck_y(a[1]),a[1]],[b[0],deck_y(b[1]),b[1]],[b[0],.70,b[1]],[a[0],.70,a[1]]],[-(a[0]+b[0]),0,.30-a[1]-b[1]])
    body.box('metal_dark',(0,.69,.15),(1.80,.04,1.80))
    R=rotation((0,1,0),math.radians(55))@rotation((0,0,1),math.radians(63))
    loose=merge_mesh(Mesh(),detached,R=R,t=[4.8,0,-.2])
    low,_=loose.bounds();loose.shift([0,-low[1],0])
    merge_mesh(body,loose);body.remove_duplicates()
    # A wreck never scrolls its tracks: bake all its facets to ordinary metre UVs.
    baked=Mesh()
    for role,g in body.groups.items():
        p=np.array(g[0]);n=np.array(g[1])
        for f in np.array(g[3]).reshape(-1,3):
            q=p[f];baked.face(role,q,np.cross(q[1]-q[0],q[2]-q[0]),normals=n[f])
    return baked


def _matrix(axis,degrees):
    result=np.eye(4);result[:3,:3]=rotation(axis,math.radians(degrees));return result


def validate(path):
    doc,meshes=read_glb(path);walk=walk_nodes(doc);byname={p:(n,M,v) for p,n,M,v in walk_nodes(doc,canonical=True)}
    roots=[doc['nodes'][i]['name'] for i in doc['scenes'][0]['nodes']]
    assert roots==['LOD0','LOD1','Wreck','collision']
    assert doc['extensionsRequired']==['KHR_node_visibility']
    assert not any(k in doc for k in ('images','textures','animations','cameras','skins'))
    assert [m['name'] for m in doc['materials']]==list(ROLES)
    for mat in doc['materials']:assert mat['pbrMetallicRoughness']=={'baseColorFactor':[1,1,1,1],'roughnessFactor':.8,'metallicFactor':0}
    assert byname['LOD0'][2] and not byname['LOD1'][2] and not byname['Wreck'][2] and not byname['collision'][2]
    counts=defaultdict(int);bounds=defaultdict(list);track_seams=0;seen_by_state=defaultdict(set)
    for path_name,node,M,visible in walk:
        if 'mesh' not in node:continue
        state=path_name.split('/')[0]
        assert 'children' not in node,'geometry is a leaf below its named empty pivot'
        for g in meshes[node['mesh']]:
            p,n,uv,f=(g[k] for k in ('p','n','uv','f'));assert len(p)==len(n)==len(uv)
            assert np.isfinite(p).all() and np.isfinite(n).all() and np.isfinite(uv).all()
            assert np.allclose(np.linalg.norm(n,axis=1),1,atol=2e-5)
            assert f.min()>=0 and f.max()<len(p)
            world=p@M[:3,:3].T+M[:3,3];bounds[state].append(world);tri=p[f]
            cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);area=np.linalg.norm(cross,axis=1)
            assert (area>1e-8).all(),(path_name,g['role'],'zero-area triangle')
            normals=cross/area[:,None];dots=np.einsum('ij,ikj->ik',normals,n[f])
            assert dots.min()>.40,(path_name,g['role'],'flipped face')
            edges=defaultdict(lambda:[0,0])
            for t in world[f]:
                points=[tuple(x) for x in np.round(t,5)];key=tuple(sorted(points))
                assert key not in seen_by_state[state],(path_name,g['role'],'duplicate face')
                seen_by_state[state].add(key)
                for a,b in zip(points,points[1:]+points[:1]):
                    e=tuple(sorted((a,b)));edges[e][0]+=1;edges[e][1]+=1 if a<b else -1
            assert all(c!=2 or s==0 for c,s in edges.values()),(path_name,g['role'],'inconsistent welded winding')
            is_track='/Track_' in path_name
            if is_track:
                assert uv[:,0].min()>=-1e-6 and uv[:,0].max()<=1.000001
                if g['role']=='metal_dark':
                    assert abs(uv[:,0].min())<1e-6 and abs(uv[:,0].max()-1)<1e-6
                    seam0={tuple(x) for x in np.round(p[uv[:,0]<1e-6],5)};seam1={tuple(x) for x in np.round(p[uv[:,0]>1-1e-6],5)}
                    assert seam0==seam1 and len(seam0)>=4;track_seams+=1
            else:
                flat=(np.abs(n[f][:,0]-n[f][:,1]).max(1)<1e-5)&(np.abs(n[f][:,0]-n[f][:,2]).max(1)<1e-5)
                # Planar projections have exact metre scale; curved circumference unwraps
                # are intentionally checked through units/geometry, not planar triangle area.
                du=uv[f][:,1]-uv[f][:,0];dv=uv[f][:,2]-uv[f][:,0];ua=np.abs(du[:,0]*dv[:,1]-du[:,1]*dv[:,0])
                if flat.any():assert np.allclose(ua[flat]/area[flat],1,atol=.005),(path_name,'UV metre scale')
            counts[state]+=len(f)
    assert track_seams==4
    assert counts['LOD0']<=15000 and counts['LOD1']<=2500,(dict(counts),'LOD triangle budgets')
    bbox={k:(np.concatenate(v).min(0),np.concatenate(v).max(0)) for k,v in bounds.items()}
    for state,(low,high) in bbox.items():assert low[1]>=-2e-5,(state,'below ground',low)
    for level in (0,1):
        prefix=f'LOD{level}/Hull'
        for label in ('L','R'):
            wheels=[p for p in byname if p.startswith(prefix+'/Wheel_'+label) and not p.endswith('_Mesh')]
            assert len(wheels)==7
            for i in range(7):
                node,M,_=byname[prefix+f'/Wheel_{label}{i}'];assert 'mesh' not in node and node['extras']['rotation_axis']=='X'
                assert np.allclose(M[:3,3],[(-1 if label=='L' else 1)*1.46,.50,-2.4+.8*i])
            assert prefix+'/Sprocket_'+label in byname and prefix+'/Idler_'+label in byname
        for suffix in ('Turret','Turret/Gun','Turret/Gun/Muzzle','Turret/Hatch_Commander','Engine_Deck','Exhaust'):
            assert prefix+'/'+suffix in byname
        assert 'mesh' not in byname[prefix+'/Turret'][0] and 'mesh' not in byname[prefix+'/Turret/Gun'][0]
        mu=byname[prefix+'/Turret/Gun/Muzzle'][1][:3,3]
        assert np.allclose(mu,[0,1.96,5.74])
        turn=walk_nodes(doc,{prefix+'/Turret':_matrix((0,1,0),90)},canonical=True)
        turned={p:M for p,n,M,v in turn}[prefix+'/Turret/Gun/Muzzle'][:3,3]
        assert np.allclose(turned,[5.59,1.96,.15],atol=1e-5),'yaw pivot propagation'
        for elevation in (-8,20):
            pose=walk_nodes(doc,{prefix+'/Turret/Gun':_matrix((1,0,0),-elevation)},canonical=True)
            moved={p:M for p,n,M,v in pose}[prefix+'/Turret/Gun/Muzzle'][:3,3]
            assert np.allclose(moved,[0,1.96+4.39*math.sin(math.radians(elevation)),1.35+4.39*math.cos(math.radians(elevation))],atol=1e-5),'elevation pivot propagation'
        recoil=np.eye(4);recoil[2,3]=-.20
        posed={p:M for p,n,M,v in walk_nodes(doc,{prefix+'/Turret/Gun':recoil},canonical=True)}
        assert np.allclose(posed[prefix+'/Turret/Gun/Muzzle'][:3,3],mu-[0,0,.2])
    low,high=bbox['LOD0'];assert np.allclose(low[1],0,atol=2e-5)
    assert np.allclose(high-low,[3.716,3.70,9.70],atol=.04),(low,high,'reference size')
    assert np.allclose(bbox['LOD0'],bbox['LOD1'],atol=.04),'LOD silhouette bounds'
    nodes=[];tree=[]
    for p,n,M,v in walk:
        local=n.get('translation',[0,0,0]);world=M[:3,3]
        depth=p.count('/');axis=n.get('extras',{}).get('rotation_axis','-')
        tree.append('  '*depth+n['name']+f' local={np.round(local,5).tolist()} world={np.round(world,5).tolist()} axis={axis}'+(' mesh' if 'mesh' in n else ' pivot')+(' hidden' if not v else ''))
        if 'mesh' not in n or n['name'] in ('Wreck','Collision_Box'):
            nodes.append({'path':p,'canonical_part':n.get('extras',{}).get('canonical_part',n['name']),'pivot_local':[round(float(x),6) for x in local],'pivot_world':[round(float(x),6) for x in world],'axis':None if axis=='-' else axis,'default_visible':v})
    entry={'file':'vehicles/'+SLUG+'.glb','kind':'model','name':'M1A2 SEPv3 Abrams','priority':'P1','pilot':True,'approximate':False,
           'triangles':[counts['LOD0'],counts['LOD1']],'wreck_triangles':counts['Wreck'],'collision_triangles':counts['collision'],
           'size':[round(float(x),5) for x in high-low],'bounds':[[round(float(x),5) for x in low],[round(float(x),5) for x in high]],'hull_footprint':[3.70,7.92],
           'height_without_antennas':3.09,'units':'metres','up':'+Y','front':'+Z','materials':list(ROLES),'nodes':nodes,'grid':None,'tileable':False,'frames':None,
           'notes':'Original Python-authored exterior reconstruction with seven road-wheel stations per side, rear sprockets, front idlers, Abrams glacis and faceted turret cheeks, bustle rack, L/44-class 120 mm visual gun with evacuator and recessed bore, CITV, CROWS-LP and roof fittings. Small fittings are simplified; this is a visual game model, not an engineering reconstruction. No external mesh, texture, vertex colour, national insignia or number. All five materials white PBR (.8 roughness, 0 metallic). LOD1 preserves pivots with simplified geometry; return rollers keep pivots and omit hidden meshes. Wreck is one static mesh with an open hull ring and detached turret; dark treatment is by metal_dark role. KHR_node_visibility hides LOD1, Wreck and collision by default. Body UVs in metres; Track_L/R U is normalized 0..1 around the loop as explicitly requested, V in metres. Both tracks include solid shoe/pad geometry. Hull origin is its ground footprint centre; visible overall bounds include forward gun overhang and antenna whips. Gun positive elevation uses negative local-X rotation. Wheel numbering rear to front.',
           'lod1_naming':'LOD0 has exact canonical names. LOD1 appends _LOD1 to every part to prevent Godot global-name deduplication. extras.canonical_part and the nodes list provide an explicit binding map.',
           'sources':SOURCES,'validation':{'readback':True,'node_tree_printed':True,'ccw_normals':True,'duplicate_faces':0,'below_ground_vertices':0,'track_uv_seams':4,'pose_checks':['turret +90 deg','gun -8/+20 deg','gun 0.20 m recoil'],'lod_limits':[15000,2500]},
           'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    return entry,'\n'.join(tree)+'\n'


def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--output',type=Path,default=ART/'vehicles'/f'{SLUG}.glb');p.add_argument('--manifest',type=Path,default=ART/'MANIFEST.json')
    p.add_argument('--validate-only',action='store_true');p.add_argument('--report',type=Path);p.add_argument('--tree',type=Path)
    p.add_argument('--evidence',type=Path,help='Optional external-loader evidence, accepted only when its SHA-256 matches this GLB')
    args=p.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    if not args.validate_only:
        rigs=[m1a2_sepv3_abrams(i) for i in (0,1)];wreck=make_wreck(rigs[1]);collision=Mesh();collision.box('metal_dark',(0,.75,0),(3.70,1.50,7.92))
        metadata={'vehicle':'m1a2_sepv3_abrams','units':'metres','up':'+Y','front':'+Z','uv_units':'metres except Track U normalized loop','road_wheels_per_side':7,'default_lod':0,'pilot_only':True}
        write_glb(args.output,rigs,wreck,collision,metadata)
    entry,tree=validate(args.output)
    if args.evidence:
        evidence=json.loads(args.evidence.read_text(encoding='utf-8'))
        assert evidence['sha256']==entry['sha256'],'external evidence belongs to a different GLB'
        assert evidence['trimesh']['passed'] and evidence['godot']['passed']
        entry['validation']['external_loaders']=evidence
    print(tree)
    print('PASS',args.output.name,'LOD0/1 triangles',entry['triangles'],'size',entry['size'],'wreck',entry['wreck_triangles'])
    if not args.validate_only:
        entries=json.loads(args.manifest.read_text(encoding='utf-8')) if args.manifest.exists() else []
        entries=[e for e in entries if e['file']!=entry['file']]+[entry]
        args.manifest.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
    if args.report:args.report.write_text(json.dumps(entry,indent=2)+'\n',encoding='utf-8')
    if args.tree:args.tree.write_text(tree,encoding='utf-8')


if __name__=='__main__':main()
