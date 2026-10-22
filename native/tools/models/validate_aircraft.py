"""Validate saved aircraft geometry, metre UVs, local hinges and named rotors."""
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
    tracked=False;body='Fuselage'
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
    checks=[]
    for lod in (0,1):
        prefix=f'LOD{lod}/Fuselage';assert prefix in by and 'mesh' not in by[prefix][0]
        assert not any('/Track_' in p or '/Sprocket_' in p for p in by if p.startswith(prefix+'/'))
        if doc['extras']['priority']=='P5':
            main=[p for p in by if p.startswith(prefix+'/Rotor_Main') and not p.endswith(('_Mesh','_Mast'))]
            expected=2 if s['family'] in ('chinook','ka27','ka52') else 1
            assert len(main)==expected,(s['slug'],'rotor configuration')
            for p in main:
                node,M,_=by[p];assert node['extras']['rotation_axis']=='Y'
                assert node['extras']['blade_count']==s['blades']
            tail=prefix+'/Rotor_Tail'
            assert (tail in by)==bool(s['tail_blades'])
            if tail in by:
                assert by[tail][0]['extras']['rotation_axis']=='X'
                assert by[tail][0]['extras']['blade_count']==s['tail_blades']
            assert (prefix+'/Skid' in by)==(s['gear']=='skid')
            gear=[p for p in by if p.startswith(prefix+'/Gear_') and p.count('/')==2]
            assert len(gear)==(0 if s['gear']=='skid' else 4 if s['gear']=='four' else 3)
            if s['gear']!='skid':
                assert prefix+'/Gear_Left' in by and prefix+'/Gear_Right' in by
                assert (prefix+'/Gear_Nose' in by)==(s['gear']=='tricycle')
                assert (prefix+'/Gear_Tail' in by)==(s['gear']=='tailwheel')
            for rotor in main+([tail] if tail in by else []):
                node=by[rotor][0];name=node['extras']['canonical_part']
                child=by[rotor+'/'+name+'_Mesh'][0]
                points=np.concatenate([g['p'] for g in meshes[child['mesh']] if g['role']=='paint'])
                projected=points[:,[1,2] if name=='Rotor_Tail' else [0,2]]
                radii=np.linalg.norm(projected,axis=1);radius=node['extras']['diameter_metres']/2
                assert .98*radius<=radii.max()<=1.02*radius,(rotor,'actual blade radius')
                tips=projected[radii>.985*radii.max()]
                angles=np.sort(np.mod(np.arctan2(tips[:,1],tips[:,0]),math.tau))
                gaps=np.diff(np.r_[angles,angles[0]+math.tau]);blades=node['extras']['blade_count']
                assert np.count_nonzero(gaps>math.pi/blades*.5)==blades,(rotor,'geometric blade count')
            if s.get('attack'):
                markers={n['extras']['canonical_part']:M[:3,3] for p,(n,M,v) in by.items()
                    if p.startswith(prefix+'/') and n.get('extras',{}).get('canonical_part','').startswith('Muzzle_')}
                assert set(markers)=={'Muzzle_'+str(i) for i in range(s['details']['muzzle_count'])}
                for name,pos in s['details']['muzzle_positions'].items():assert np.allclose(markers[name],pos,atol=1e-5)
                if s['details'].get('gun',True):
                    fixed=s['details'].get('fixed_gun',False)
                    assert (prefix+'/Turret' in by)==(not fixed)
                    gun=prefix+('/Gun' if fixed else '/Turret/Gun')
                    assert gun in by and gun+'/Muzzle_0' in by
            elif s.get('naval'):
                want=0 if s['details'].get('naval_store')=='none' else 1 if s['details'].get('naval_store')=='internal' else 2
                actual=[p for p,(n,M,v) in by.items() if p.startswith(prefix+'/') and n.get('extras',{}).get('canonical_part','').startswith('Muzzle_')]
                assert len(actual)==want,(prefix,'naval mission store count')
        for p,(node,M,v) in by.items():
            axisname=node.get('extras',{}).get('rotation_axis')
            if not axisname or not p.startswith(prefix+'/'):continue
            assert 'mesh' not in node and node.get('children'),(p,'empty hinge with mesh children')
            axis=axes[axisname];worldaxis=M[:3,:3]@axis;worldaxis/=np.linalg.norm(worldaxis)
            posed={q:T for q,n,T,v in walk_nodes(doc,{p:matrix(axis,17)},canonical=True)}
            for q,(child,T,_) in by.items():
                if not q.startswith(p+'/') or 'mesh' not in child:continue
                for group in meshes[child['mesh']]:
                    pt=group['p'][0];neutral=T[:3,:3]@pt+T[:3,3]
                    actual=posed[q][:3,:3]@pt+posed[q][:3,3]
                    expected=M[:3,3]+rotation(worldaxis,math.radians(17))@(neutral-M[:3,3])
                    assert np.allclose(actual,expected,atol=3e-5),(p,'local-frame hinge propagation')
            if node['extras']['canonical_part'].startswith(('Rotor_','Propeller')):
                full={q:T for q,n,T,v in walk_nodes(doc,{p:matrix(axis,360)},canonical=True)}
                assert np.allclose(full[p],M,atol=1e-6)
    nodes=[];tree=[]
    for p,n,M,v in walk:
        local=n.get('translation',[0,0,0]);axis=n.get('extras',{}).get('rotation_axis')
        tree.append('  '*p.count('/')+n['name']+' local='+str(np.round(local,5).tolist())+' world='+str(np.round(M[:3,3],5).tolist())+' axis='+str(axis)+(' rotation='+str(n['rotation']) if 'rotation' in n else '')+(' mesh' if 'mesh' in n else ' pivot')+(' hidden' if not v else ''))
        if 'mesh' not in n or n['name'] in ('Wreck','Collision_Box'):
            nodes.append({'path':p,'canonical_part':n.get('extras',{}).get('canonical_part',n['name']),
                'pivot_local':[round(float(x),6) for x in local],'pivot_world':[round(float(x),6) for x in M[:3,3]],
                'axis':axis,'rotation_xyzw':n.get('rotation',[0,0,0,1]),'default_visible':v})
    low,high=bounds['LOD0']
    entry={'file':'aircraft/'+Path(path).name,'kind':'model','name':s['name'],'priority':doc['extras']['priority'],
        'approximate':s['approximate'],'representative_vehicle':s['representative'] or s['name'],
        'triangles':[counts['LOD0'],counts['LOD1']],'wreck_triangles':counts['Wreck'],'collision_triangles':counts['collision'],
        'size':[round(float(x),5) for x in high-low],'bounds':[[round(float(x),5) for x in low],[round(float(x),5) for x in high]],
        'fuselage_length_metres':s['length'],'rotor_diameter_metres':s.get('rotor_diameter'),
        'mobility':'aircraft','has_turret':False,'has_launcher':False,'road_wheels_per_side':0,
        'recognition_features':s['features'],'units':'metres','up':'+Y','front':'+Z','materials':list(ROLES),'nodes':nodes,
        'grid':None,'tileable':False,'frames':None,
        'sources':[{'url':s['source'],'use':'Exterior identification and published size; original procedural geometry.'}],
        'notes':'Original Python aircraft; five plain-white PBR roles, no images, baked colours or imported meshes. Closed metre-UV surfaces; empty real hinges carry mesh children. Local quaternion frames preserve canted rotor shafts. LOD1 uses suffixed names and canonical_part extras. Hidden dark static Wreck and Collision_Box. Approximate fields record uncertain exterior proportions and combined-row representatives.',
        'validation':{'readback':True,'node_tree_printed':True,'ccw_normals':True,'duplicate_faces':0,'below_ground_vertices':0,
            'pose_checks':['all named hinges propagate children about their actual local shaft','rotor full-revolution return','airframe-specific main/tail rotor and landing gear configuration'],
            'lod_limits':[15000,2500]},'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    return entry,'\n'.join(tree)+'\n'
