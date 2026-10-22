"""Read saved bytes back: buffers, geometry, metre UVs, canonical tracks and pivots.

Independently checks wheel counts/positions from the published vehicle spec,
weapon absence on unarmed vehicles, and parent propagation of moving parts.
P3 fork: the same saved-buffer checks, with towed gun carriages and launcher markers.
"""
from collections import defaultdict
from pathlib import Path
import hashlib, json, math
import numpy as np
from vehicle_parts import read_glb,walk_nodes,rotation,track,TrackPath,ROLES
from validate_p1_tanks import matrix

_tracks={}


def validate(path):
    doc,meshes=read_glb(path);s=doc['extras']['spec'];walk=walk_nodes(doc)
    by={p:(n,M,v) for p,n,M,v in walk_nodes(doc,canonical=True)}
    tracked=s['mobility']=='tracked';towed=s['mobility']=='towed';armed=bool(s['weapon']) and not towed;body='Carriage' if towed else 'Hull'
    roots=[doc['nodes'][i]['name'] for i in doc['scenes'][0]['nodes']]
    assert roots==['LOD0','LOD1','Wreck','collision']
    assert by['LOD0'][2] and all(not by[n][2] for n in roots[1:])
    assert doc['extensionsRequired']==['KHR_node_visibility']
    assert [m['name'] for m in doc['materials']]==list(ROLES)
    assert not any(k in doc for k in ('images','textures','animations','cameras','skins'))
    assert len({n['name'] for n in doc['nodes']})==len(doc['nodes'])
    for m in doc['materials']:assert m['pbrMetallicRoughness']=={'baseColorFactor':[1,1,1,1],'roughnessFactor':.8,'metallicFactor':0}
    counts=defaultdict(int);positions=defaultdict(list);seen=defaultdict(set);seams=0;motion_min=1
    for nodepath,node,M,visible in walk:
        if 'mesh' not in node:continue
        assert 'children' not in node
        state=nodepath.split('/')[0];roles=set()
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
                pts=[tuple(x) for x in np.round(t,5)];key=tuple(sorted(pts))
                assert key not in seen[state],(nodepath,g['role'],'duplicate face');seen[state].add(key)
                for a,b in zip(pts,pts[1:]+pts[:1]):
                    edge=tuple(sorted((a,b)));edges[edge][0]+=1;edges[edge][1]+=1 if a<b else -1
            assert all(c!=2 or balance==0 for c,balance in edges.values()),(nodepath,g['role'],'inconsistent winding')
            if '/Track_' in nodepath:
                assert tracked and uv[:,0].min()>=-1e-6 and uv[:,0].max()<=1.000001
                if g['role']=='metal_dark':
                    aa={tuple(x) for x in np.round(p[uv[:,0]<1e-6],5)};bb={tuple(x) for x in np.round(p[uv[:,0]>1-1e-6],5)}
                    assert aa==bb and len(aa)>=4;seams+=1
                lod=int(state[-1]);_tracks.setdefault(lod,track(lod,0));ref=_tracks[lod].groups[g['role']]
                assert np.allclose(p,ref[0],atol=2e-6),'shader requires unchanged canonical vertices'
                assert np.allclose(uv,ref[2],atol=2e-7)
                assert np.allclose(node.get('scale',[1,1,1]),[1,s['track_scale'],s['track_scale']])
                curve=TrackPath()
                for idx in np.linspace(0,len(p)-1,min(64,len(p)),dtype=int):
                    u=float(uv[idx,0]);p0,n0,t0=curve.sample(u);d=p[idx]-p0
                    for phase in (0,.25,.5,.75,1):
                        p1,n1,t1=curve.sample(u+phase);q=p1+np.dot(d,n0)*n1+np.dot(d,t0)*t1;q[0]=p[idx,0]
                        if phase in (0,1):assert np.allclose(q,p[idx],atol=2e-5)
                        motion_min=min(motion_min,float(q[1]*s['track_scale']))
            else:
                assert 'scale' not in node
                flat=(np.abs(n[f][:,0]-n[f][:,1]).max(1)<1e-5)&(np.abs(n[f][:,0]-n[f][:,2]).max(1)<1e-5)
                du=uv[f][:,1]-uv[f][:,0];dv=uv[f][:,2]-uv[f][:,0];uvarea=np.abs(du[:,0]*dv[:,1]-du[:,1]*dv[:,0])
                if flat.any():assert np.allclose(uvarea[flat]/area[flat],1,atol=.005),(nodepath,'metre UV area')
            counts[state]+=len(f)
    assert seams==(4 if tracked else 0) and motion_min>-.025
    assert counts['LOD0']<=15000 and counts['LOD1']<=2500,dict(counts)
    bounds={st:(np.concatenate(ps).min(0),np.concatenate(ps).max(0)) for st,ps in positions.items()}
    for st,(low,high) in bounds.items():assert low[1]>=-2e-5,(st,'below ground',low)
    assert np.allclose(bounds['LOD0'],bounds['LOD1'],atol=.055),('LOD silhouette',bounds['LOD0'],bounds['LOD1'])
    poses=[]
    for lod in (0,1):
        prefix=f'LOD{lod}/{body}';k=s['track_scale'];x=s['width']/2-(.35 if tracked else .19)
        y=s['wheel_radius']+.13*k if tracked else s['wheel_radius']
        zs=s.get('details',{}).get('wheel_z',np.linspace(-2.43,2.43,s['wheels'])*k) if tracked else s['axle_z']
        for label,side in (('L',-1),('R',1)):
            wheels=[p for p in by if p.startswith(prefix+'/Wheel_'+label) and not p.endswith('_Mesh')]
            assert len(wheels)==s['wheels'],(prefix,label,'wheel count')
            for i,z in enumerate(zs):
                node,M,_=by[prefix+f'/Wheel_{label}{i}'];assert 'mesh' not in node and node['extras']['rotation_axis']=='X'
                assert np.allclose(M[:3,3],[side*x,y,z]),('axle',label,i)
                if not tracked:
                    # A full roll returns the actual tyre geometry to its origin.
                    wp=prefix+f'/Wheel_{label}{i}';full={p:M for p,n,M,v in walk_nodes(doc,{wp:matrix([1,0,0],360)},canonical=True)}
                    assert np.allclose(full[wp],by[wp][1],atol=1e-6)
            for part,z in [('Sprocket',3.23 if s['front_engine'] else -3.23),('Idler',-3.23 if s['front_engine'] else 3.23)]:
                if tracked:assert np.allclose(by[prefix+'/'+part+'_'+label][1][:3,3],[side*x,.65*k,z*k])
                else:assert not any('/'+part+'_' in p for p in by)
            assert (prefix+'/Track_'+label in by)==tracked
        turret=prefix+'/Turret';gun=turret+'/Gun';muzzle=gun+'/Muzzle'
        assert (turret in by)==armed and (gun in by)==armed and (muzzle in by)==armed
        if towed:
            gp=prefix+'/Gun';mp=gp+'/Muzzle'
            assert gp in by and mp in by
            assert by[gp][0]['extras']['rotation_axis']=='X'
            for label in ('L','R'):
                assert by[prefix+'/Trail_'+label][0]['extras']['rotation_axis']=='Y'
            neutral=by[mp][1][:3,3];origin=by[gp][1][:3,3]
            raised={q:T for q,n,T,v in walk_nodes(doc,{gp:matrix([1,0,0],-20)},canonical=True)}
            assert np.allclose(raised[mp][:3,3],origin+rotation([1,0,0],math.radians(-20))@(neutral-origin),atol=1e-5)
            recoil=np.eye(4);recoil[2,3]=-.2
            pulled={q:T for q,n,T,v in walk_nodes(doc,{gp:recoil},canonical=True)}
            assert np.allclose(pulled[mp][:3,3],neutral-[0,0,.2],atol=1e-5)
        tubes=s.get('details',{}).get('tube_count',0)
        if tubes:
            turn=prefix+'/Turntable';launch=(turn if turn in by else prefix)+'/Launcher'
            assert by[launch][0]['extras']['rotation_axis']=='X'
            if turn in by:assert by[turn][0]['extras']['rotation_axis']=='Y'
            markers=[q for q in by if q.startswith(launch+'/Muzzle_')]
            assert len(markers)==tubes,(launch,'tube marker count',len(markers),tubes)
            for i in range(tubes):
                q=launch+f'/Muzzle_{i}';assert 'mesh' not in by[q][0]
                assert np.allclose(by[q][1][:3,3],s['details']['muzzle_positions'][i],atol=1e-5)
            for target,axis,angle in [(launch,[1,0,0],-30)]+([(turn,[0,1,0],90)] if turn in by else []):
                pose={q:T for q,n,T,v in walk_nodes(doc,{target:matrix(axis,angle)},canonical=True)}
                origin=by[target][1][:3,3]
                for q in markers:
                    assert np.allclose(pose[q][:3,3],origin+rotation(axis,math.radians(angle))@(by[q][1][:3,3]-origin),atol=1e-5)
        if armed:
            assert by[turret][0]['extras']['rotation_axis']=='Y' and by[gun][0]['extras']['rotation_axis']=='X'
            tp=by[turret][1][:3,3];gp=by[gun][1][:3,3];mp=by[muzzle][1][:3,3]
            assert mp[2]>gp[2] and np.allclose(mp[:2],gp[:2])
            for target,axis,angle,origin in [(turret,[0,1,0],90,tp),(gun,[1,0,0],8,gp),(gun,[1,0,0],-20,gp)]:
                turn={p:M for p,n,M,v in walk_nodes(doc,{target:matrix(axis,angle)},canonical=True)}
                assert np.allclose(turn[muzzle][:3,3],origin+rotation(axis,math.radians(angle))@(mp-origin),atol=1e-5)
            recoil=np.eye(4);recoil[2,3]=-.2
            turn={p:M for p,n,M,v in walk_nodes(doc,{gun:recoil},canonical=True)}
            assert np.allclose(turn[muzzle][:3,3],mp-[0,0,.2]);poses=['yaw +90','gun -8/+20','recoil .20 m']
        if s['slug'].startswith('recoveryVehicle'):
            for part in ('Boom','Spade'):
                node,M,_=by[prefix+'/'+part];assert 'mesh' not in node and node['extras']['rotation_axis'] in ('X','Y')
        # Every exported moving hinge must carry all mesh children with it.
        for p,(node,M,v) in by.items():
            if not p.startswith(prefix+'/') or 'rotation_axis' not in node.get('extras',{}):continue
            axis={'X':[1,0,0],'Y':[0,1,0],'Z':[0,0,1]}[node['extras']['rotation_axis']]
            pose={q:T for q,n,T,v in walk_nodes(doc,{p:matrix(axis,17)},canonical=True)}
            for q,(child,T,_) in by.items():
                if not q.startswith(p+'/') or 'mesh' not in child:continue
                group=meshes[child['mesh']][0];pt=group['p'][0]
                neutral=T[:3,:3]@pt+T[:3,3];actual=pose[q][:3,:3]@pt+pose[q][:3,3]
                expected=M[:3,3]+rotation(axis,math.radians(17))@(neutral-M[:3,3])
                assert np.allclose(actual,expected,atol=2e-5),(p,'hinge propagation')
    nodes=[];tree=[]
    for p,n,M,v in walk:
        local=n.get('translation',[0,0,0]);axis=n.get('extras',{}).get('rotation_axis')
        tree.append('  '*p.count('/')+n['name']+' local='+str(np.round(local,5).tolist())+' world='+str(np.round(M[:3,3],5).tolist())+' axis='+str(axis)+(' scale='+str(n['scale']) if 'scale' in n else '')+(' mesh' if 'mesh' in n else ' pivot')+(' hidden' if not v else ''))
        if 'mesh' not in n or n['name'] in ('Wreck','Collision_Box'):
            nodes.append({'path':p,'canonical_part':n.get('extras',{}).get('canonical_part',n['name']),'pivot_local':[round(float(x),6) for x in local],
                'pivot_world':[round(float(x),6) for x in M[:3,3]],'axis':axis,'default_visible':v})
    low,high=bounds['LOD0']
    entry={'file':'vehicles/'+Path(path).name,'kind':'model','name':s['name'],'priority':doc['extras']['priority'],'pilot':False,
        'approximate':s['approximate'],'representative_vehicle':s['representative'] or s['name'],
        'triangles':[counts['LOD0'],counts['LOD1']],'wreck_triangles':counts['Wreck'],'collision_triangles':counts['collision'],
        'size':[round(float(x),5) for x in high-low],'bounds':[[round(float(x),5) for x in low],[round(float(x),5) for x in high]],
        'hull_footprint':[s['width'],s['length']],'road_wheels_per_side':s['wheels'],'wheel_radius_metres':s['wheel_radius'],
        'mobility':s['mobility'],'has_turret':armed,'recognition_features':s['features'],'units':'metres','up':'+Y','front':'+Z',
        'materials':list(ROLES),'nodes':nodes,'grid':None,'tileable':False,'frames':None,
        'notes':'Original Python exterior model, no Blender or source mesh. generate_p3_artillery.py + artillery_parts.py + approved vehicle_parts.py. Actual-size hull and axle layout; named empty hinges with mesh children; metre UVs except Track U (0..1). Small fittings simplified; approximate/representative fields describe ambiguous roster designations. Blank white PBR roles; hidden LOD1 and static dark-role Wreck; hidden hull Collision_Box. LOD1 parts append _LOD1 with canonical_part extras. Wheeled vehicles have axle pivots and no tracks. Turret/Gun/Muzzle exist only with a weapon mount; recovery vehicles expose Boom and Spade. No national symbols or baked colours.',
        'sources':[{'url':s['source'],'use':'Vehicle exterior identification and size class; original geometry, no photographs embedded.'}],
        'validation':{'readback':True,'node_tree_printed':True,'ccw_normals':True,'duplicate_faces':0,'below_ground_vertices':0,
            'track_uv_seams':seams,'canonical_track_vertices':tracked,'track_shader_phases':[0,.25,.5,.75,1] if tracked else [],
            'pose_checks':poses+['all named hinges propagate children','axle positions and wheel count'],'lod_limits':[15000,2500]},
        'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    entry['has_launcher']=bool(s.get('details',{}).get('tube_count',0))
    entry['launcher_tubes']=s.get('details',{}).get('tube_count',0)
    if entry['has_launcher']:entry['validation']['pose_checks']+=['every tube marker elevates -30 degrees and traverses +90 degrees']
    if tracked:entry['track_shader_contract']={'canonical_path':doc['extras']['canonical_track_path'],'mesh_child_scale':[1,s['track_scale'],s['track_scale']],
        'world_loop_length_metres':round(TrackPath.length*s['track_scale'],6),'description':'Unmodified canonical TrackPath vertices and U, followed by mesh-child YZ scale, exactly as approved P1.'}
    return entry,'\n'.join(tree)+'\n'
