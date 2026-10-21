"""Strict saved-GLB validation for P1; never assumes every tank is an Abrams."""
from collections import defaultdict
from pathlib import Path
import hashlib,math,json
import numpy as np
from vehicle_parts import read_glb,walk_nodes,rotation,track,TrackPath,ROLES

_tracks={}


def matrix(axis,angle):
    m=np.eye(4);m[:3,:3]=rotation(axis,math.radians(angle));return m


def validate(path):
    doc,meshes=read_glb(path);s=doc['extras']['spec'];walk=walk_nodes(doc)
    by={p:(n,M,v) for p,n,M,v in walk_nodes(doc,canonical=True)}
    roots=[doc['nodes'][i]['name'] for i in doc['scenes'][0]['nodes']]
    assert roots==['LOD0','LOD1','Wreck','collision']
    assert by['LOD0'][2] and all(not by[n][2] for n in roots[1:])
    assert doc['extensionsRequired']==['KHR_node_visibility']
    assert [m['name'] for m in doc['materials']]==list(ROLES)
    assert not any(k in doc for k in ('images','textures','animations','cameras','skins'))
    for mat in doc['materials']:assert mat['pbrMetallicRoughness']=={'baseColorFactor':[1,1,1,1],'roughnessFactor':.8,'metallicFactor':0}
    counts=defaultdict(int);positions=defaultdict(list);seen=defaultdict(set);seams=0;motion_min=1
    for nodepath,node,M,visible in walk:
        if 'mesh' not in node:continue
        assert 'children' not in node
        state=nodepath.split('/')[0]
        roles=set()
        for g in meshes[node['mesh']]:
            assert g['role'] not in roles;roles.add(g['role'])
            p,n,uv,f=(g[k] for k in ('p','n','uv','f'))
            assert len(p)==len(n)==len(uv) and f.min()>=0 and f.max()<len(p)
            assert np.isfinite(p).all() and np.isfinite(n).all() and np.isfinite(uv).all()
            assert np.allclose(np.linalg.norm(n,axis=1),1,atol=2e-5)
            tri=p[f];cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);area=np.linalg.norm(cross,axis=1)
            assert (area>1e-8).all(),(nodepath,'degenerate triangle')
            assert np.einsum('ij,ikj->ik',cross/area[:,None],n[f]).min()>.40,(nodepath,g['role'],'flipped face')
            world=p@M[:3,:3].T+M[:3,3];positions[state].append(world);edges=defaultdict(lambda:[0,0])
            for t in world[f]:
                points=[tuple(x) for x in np.round(t,5)];key=tuple(sorted(points))
                assert key not in seen[state],(nodepath,g['role'],'duplicate face');seen[state].add(key)
                for a,b in zip(points,points[1:]+points[:1]):
                    edge=tuple(sorted((a,b)));edges[edge][0]+=1;edges[edge][1]+=1 if a<b else -1
            assert all(c!=2 or balance==0 for c,balance in edges.values()),(nodepath,g['role'],'inconsistent winding')
            if '/Track_' in nodepath:
                assert uv[:,0].min()>=-1e-6 and uv[:,0].max()<=1.000001
                if g['role']=='metal_dark':
                    a={tuple(x) for x in np.round(p[uv[:,0]<1e-6],5)};b={tuple(x) for x in np.round(p[uv[:,0]>1-1e-6],5)}
                    assert a==b and len(a)>=4;seams+=1
                lod=int(state[-1]);_tracks.setdefault(lod,track(lod,0));ref=_tracks[lod].groups[g['role']]
                assert np.allclose(p,np.array(ref[0]),atol=2e-6),'shader requires unmodified canonical TrackPath vertices'
                assert np.allclose(uv,ref[2],atol=2e-7)
                assert np.allclose(node.get('scale',[1,1,1]),[1,s['track_scale'],s['track_scale']])
                # CPU emulation of the game's actual shader at four moving phases.
                pathcurve=TrackPath()
                for idx in np.linspace(0,len(p)-1,min(80,len(p)),dtype=int):
                    u=float(uv[idx,0]);p0,n0,t0=pathcurve.sample(u);d=p[idx]-p0
                    for phase in (.0,.25,.5,.75,1.):
                        p1,n1,t1=pathcurve.sample(u+phase);q=p1+np.dot(d,n0)*n1+np.dot(d,t0)*t1;q[0]=p[idx,0]
                        if phase in (0,1):assert np.allclose(q,p[idx],atol=2e-5)
                        motion_min=min(motion_min,float(q[1]*s['track_scale']))
            else:
                assert 'scale' not in node,'ordinary body meshes must be authored in metres'
                flat=(np.abs(n[f][:,0]-n[f][:,1]).max(1)<1e-5)&(np.abs(n[f][:,0]-n[f][:,2]).max(1)<1e-5)
                du=uv[f][:,1]-uv[f][:,0];dv=uv[f][:,2]-uv[f][:,0];uvarea=np.abs(du[:,0]*dv[:,1]-du[:,1]*dv[:,0])
                if flat.any():assert np.allclose(uvarea[flat]/area[flat],1,atol=.005),(nodepath,'metre UV area')
            counts[state]+=len(f)
    assert seams==4 and motion_min>-.025,('track motion ground',motion_min)
    assert counts['LOD0']<=15000 and counts['LOD1']<=2500,dict(counts)
    bounds={state:(np.concatenate(ps).min(0),np.concatenate(ps).max(0)) for state,ps in positions.items()}
    for state,(low,high) in bounds.items():assert low[1]>=-2e-5,(state,'below ground',low)
    assert np.allclose(bounds['LOD0'],bounds['LOD1'],atol=.055),('LOD silhouette',bounds['LOD0'],bounds['LOD1'])
    for lod in (0,1):
        prefix=f'LOD{lod}/Hull';k=s['track_scale'];overrides=s.get('pivot_overrides',{});x=overrides.get('wheel_x',s['width']/2-.35)
        wheel_y=overrides.get('wheel_y',s['wheel_radius']+.13*k)
        zs=np.array(s['wheel_z'] if s['wheel_z'] else np.linspace(-2.43,2.43,s['wheels']))*k
        for label,side in (('L',-1),('R',1)):
            wheels=[p for p in by if p.startswith(prefix+'/Wheel_'+label) and not p.endswith('_Mesh')]
            assert len(wheels)==s['wheels']
            for i,z in enumerate(zs):
                node,M,_=by[prefix+f'/Wheel_{label}{i}'];assert 'mesh' not in node and node['extras']['rotation_axis']=='X'
                assert np.allclose(M[:3,3],[side*x,wheel_y,z])
            for part,z in [('Sprocket',3.23 if s['front_engine'] else -3.23),('Idler',-3.23 if s['front_engine'] else 3.23)]:
                assert np.allclose(by[prefix+'/'+part+'_'+label][1][:3,3],[side*x,.65*k,z*k])
        for part in ('Turret','Turret/Gun','Turret/Gun/Muzzle','Turret/Hatch_Commander','Engine_Deck','Exhaust','Track_L','Track_R'):
            assert prefix+'/'+part in by
        turret=prefix+'/Turret';gun=turret+'/Gun';muzzle=gun+'/Muzzle'
        tp=by[turret][1][:3,3];gp=by[gun][1][:3,3];mp=by[muzzle][1][:3,3]
        assert np.allclose(tp,overrides.get('turret',[0,s['deck']+.10,s['turret_z']])) and np.allclose(gp,[0,s['gun_y'],s['gun_z']])
        assert np.allclose(mp,[0,s['gun_y'],s['overall_length']-s['length']/2])
        turn={p:M for p,n,M,v in walk_nodes(doc,{turret:matrix([0,1,0],90)},canonical=True)}
        assert np.allclose(turn[muzzle][:3,3],tp+rotation([0,1,0],math.pi/2)@(mp-tp),atol=1e-5)
        for elevation in (-8,20):
            pose={p:M for p,n,M,v in walk_nodes(doc,{gun:matrix([1,0,0],-elevation)},canonical=True)}
            assert np.allclose(pose[muzzle][:3,3],gp+rotation([1,0,0],math.radians(-elevation))@(mp-gp),atol=1e-5)
        recoil=np.eye(4);recoil[2,3]=-.2
        pose={p:M for p,n,M,v in walk_nodes(doc,{gun:recoil},canonical=True)}
        assert np.allclose(pose[muzzle][:3,3],mp-[0,0,.2])
    nodes=[];tree=[]
    for p,n,M,v in walk:
        local=n.get('translation',[0,0,0]);axis=n.get('extras',{}).get('rotation_axis')
        tree.append('  '*p.count('/')+n['name']+' local='+str(np.round(local,5).tolist())+' world='+str(np.round(M[:3,3],5).tolist())+' axis='+str(axis)+(' scale='+str(n['scale']) if 'scale' in n else '')+(' mesh' if 'mesh' in n else ' pivot')+(' hidden' if not v else ''))
        if 'mesh' not in n or n['name'] in ('Wreck','Collision_Box'):
            nodes.append({'path':p,'canonical_part':n.get('extras',{}).get('canonical_part',n['name']),'pivot_local':[round(float(x),6) for x in local],'pivot_world':[round(float(x),6) for x in M[:3,3]],'axis':axis,'default_visible':v})
    low,high=bounds['LOD0']
    entry={'file':'vehicles/'+Path(path).name,'kind':'model','name':s['name'],'priority':'P1','pilot':False,'approximate':s['approximate'],
           'representative_vehicle':s['representative'] or s['name'],'triangles':[counts['LOD0'],counts['LOD1']],'wreck_triangles':counts['Wreck'],'collision_triangles':counts['collision'],
           'size':[round(float(x),5) for x in high-low],'bounds':[[round(float(x),5) for x in low],[round(float(x),5) for x in high]],'hull_footprint':[s['width'],s['length']],
           'road_wheels_per_side':s['wheels'],'wheel_radius_metres':s['wheel_radius'],'recognition_features':s['features'],'units':'metres','up':'+Y','front':'+Z','materials':list(ROLES),
           'nodes':nodes,'grid':None,'tileable':False,'frames':None,
           'notes':'Original Python-authored visual exterior by generate_p1_tanks.py using shared vehicle_parts.py, no Blender or external mesh. Model-specific armour silhouettes, running gear, gun and recognition details; small fittings simplified, not an engineering reconstruction. Five plain white PBR roles, no embedded textures, colours, flags or markings. UVs in metres except longitudinal Track U (0..1). Ground-centred hull, +Y up/+Z front; actual muzzle, axle and hinge pivots; positive gun elevation uses negative X. Rear-to-front wheel numbering. Hidden static dark-role wreck with physically detached/grounded turret; hidden hull collision proxy. KHR_node_visibility hides LOD1, Wreck and collision. LOD1 parts append _LOD1 with extras.canonical_part for the same bindings as the approved pilot.',
           'track_shader_contract':{'canonical_path':doc['extras']['canonical_track_path'],'mesh_child_scale':[1,s['track_scale'],s['track_scale']],
               'world_loop_length_metres':round(TrackPath.length*s['track_scale'],6),
               'description':'The shader sees unchanged pilot-space vertices and U before glTF mesh-child scale. Parent pivots and non-track geometry are in actual metres. World track V remains metre-scale (X is not scaled).'},
           'sources':[{'url':s['source'],'use':'Exterior identification and size class; original geometry reconstructed from public visual/reference data. No photograph or source mesh embedded.'}],
           'validation':{'readback':True,'node_tree_printed':True,'ccw_normals':True,'duplicate_faces':0,'below_ground_vertices':0,'track_uv_seams':4,'canonical_track_vertices':True,
                         'track_shader_phases':[0,.25,.5,.75,1],'pose_checks':['turret +90 deg','gun -8/+20 deg','gun .20 m recoil'],'lod_limits':[15000,2500]},
           'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    return entry,'\n'.join(tree)+'\n'
