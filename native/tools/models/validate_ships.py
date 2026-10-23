"""Validate saved naval buffers, metre UVs, equipment and all local pivots."""
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
    tracked=False;body='Hull'
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
    axes={'X':np.array([1.,0,0]),'Y':np.array([0.,1,0]),'Z':np.array([0.,0,1])}
    for lod in (0,1):
        prefix=f'LOD{lod}/Hull';assert prefix in by and 'mesh' not in by[prefix][0]
        for name,z in [('Wake_Bow',s['length']*.49),('Wake_Stern',-s['length']*.49)]:
            assert np.allclose(by[prefix+'/'+name][1][:3,3],[0,s['draft'],z],atol=1e-5)
        for i,g in enumerate(s['details']['guns']):
            turret=prefix+('/Turret_Main' if i==0 else '/Turret_'+str(i));gun=turret+('/Gun' if i==0 else '/Gun_'+str(i))
            assert by[turret][0]['extras']['rotation_axis']=='Y' and by[gun][0]['extras']['rotation_axis']=='X'
            marker=gun+('/Muzzle' if i==0 else '/Muzzle_'+str(i));assert marker in by
            direction=-1 if len(g)>5 and g[5] else 1
            expected=[g[0],s['draft']+s['freeboard']+(g[4] if len(g)>4 else 0)+(1.6 if g[2]>=100 else 1.3),g[1]+.35+direction*g[3]]
            if len(g)<5 or g[4]==0:expected[1]+=max(0,(g[1]/s['length']-.22)/.28)*s['details'].get('bow_sheer',1.7)
            assert np.allclose(by[marker][1][:3,3],expected,atol=2e-5)
        for i,(z,cols,rows,pitch,y) in enumerate(s['details'].get('vls',[])):
            assert by[prefix+'/VLS_'+str(i)][0]['extras']['cell_count']==cols*rows
        for i,_ in enumerate(s['details']['masts']):assert by[prefix+('/Mast_'+str(i))+('/Radar' if i==0 else '/Radar_'+str(i))][0]['extras']['rotation_axis']=='Y'
        for p,(node,M,v) in by.items():
            axisname=node.get('extras',{}).get('rotation_axis')
            if not axisname or not p.startswith(prefix+'/'):continue
            assert 'mesh' not in node and node.get('children'),(p,'hinge requires mesh children')
            axis=axes[axisname];worldaxis=M[:3,:3]@axis;worldaxis/=np.linalg.norm(worldaxis)
            posed={q:T for q,n,T,v in walk_nodes(doc,{p:matrix(axis,17)},canonical=True)}
            for q,(child,T,_) in by.items():
                if not q.startswith(p+'/'):continue
                points=np.concatenate([g['p'] for g in meshes[child['mesh']]]) if 'mesh' in child else np.zeros((1,3))
                neutral=points@T[:3,:3].T+T[:3,3];actual=points@posed[q][:3,:3].T+posed[q][:3,3]
                expected=(neutral-M[:3,3])@rotation(worldaxis,math.radians(17)).T+M[:3,3]
                assert np.allclose(actual,expected,atol=4e-5),(p,q,'local hinge propagation')
    nodes=[];tree=[]
    for p,n,M,v in walk:
        local=n.get('translation',[0,0,0]);axis=n.get('extras',{}).get('rotation_axis')
        tree.append('  '*p.count('/')+n['name']+' local='+str(np.round(local,5).tolist())+' world='+str(np.round(M[:3,3],5).tolist())+' axis='+str(axis)+(' mesh' if 'mesh' in n else ' pivot')+(' hidden' if not v else ''))
        if 'mesh' not in n or n['name'] in ('Wreck','Collision_Box'):
            nodes.append({'path':p,'canonical_part':n.get('extras',{}).get('canonical_part',n['name']),
                'pivot_local':[round(float(x),6) for x in local],'pivot_world':[round(float(x),6) for x in M[:3,3]],
                'axis':axis,'rotation_xyzw':n.get('rotation',[0,0,0,1]),'default_visible':v})
    low,high=bounds['LOD0']
    entry={'file':'ships/'+Path(path).name,'kind':'model','name':s['name'],'priority':'P7',
        'approximate':s['approximate'],'representative_vehicle':s['representative'] or s['name'],
        'triangles':[counts['LOD0'],counts['LOD1']],'wreck_triangles':counts['Wreck'],'collision_triangles':counts['collision'],
        'size':[round(float(x),5) for x in high-low],'bounds':[[round(float(x),5) for x in low],[round(float(x),5) for x in high]],
        'length_metres':s['length'],'beam_metres':s['beam'],'waterline_y':s['draft'],
        'mobility':'ship','has_turret':bool(s['details']['guns']),'has_launcher':bool(s['details'].get('vls')),'road_wheels_per_side':0,
        'recognition_features':s['features'],'units':'metres','up':'+Y','front':'+Z','materials':list(ROLES),'nodes':nodes,
        'grid':None,'tileable':False,'frames':None,
        'sources':[{'url':s['source'],'use':'Exterior identification and dimensions; original procedural geometry, estimated cross sections and fitting locations.'}],
        'notes':'Original Python naval model, five white PBR roles, no imported meshes or textures. Origin at keel under hull footprint; waterline_y and wake markers use published draft. All moving parts are empty real hinges with mesh children. Static dark Wreck and Collision_Box hidden. Approximate exterior fittings and class representatives disclosed.',
        'validation':{'readback':True,'node_tree_printed':True,'ccw_normals':True,'duplicate_faces':0,'below_ground_vertices':0,
            'pose_checks':['every hinge mesh vertex and descendant marker checked at 17 degrees','gun trunnions and muzzle positions','VLS counts and rotating search radar','wake markers at waterline'],'lod_limits':[15000,2500]},
        'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    return entry,'\n'.join(tree)+'\n'
