"""P3 original artillery exteriors. Metres, +Z front, articulated real mounts.

Explicit functions select a real representative for ambiguous combined rows.
Shared wheels/tracks retain the approved pilot's contract. No Blender.
"""
from dataclasses import asdict
from pathlib import Path
import argparse,json
from vehicle_parts import Mesh,hollow_muzzle,write_glb,merge_mesh
from generate_p1_tanks import Spec,finish,make_wreck,beam

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
SOVIET='https://www.trngcmd.marines.mil/Portals/207/Docs/MCIS/ITEP/RITC-East/FM%20100-2-3.pdf'

def artillery__2s1_gvozdika_d_30(lod=0):
    s=Spec('2s1_gvozdika_d_30','2S1 Gvozdika / D-30',7.26,2.85,1.42,2.29,7,.29,.82,-.89,1.94,.04,7.62,'2s1',
       ['2S1 chosen from combined 2S1/D-30 row','Seven small road wheels with front sprockets',
        'low amphibious hull','rear-mounted shallow welded turret','122 mm 2A31 howitzer with double-baffle muzzle brake',
        'bow trim vane and rear access door'],SOVIET,caliber=.122,front_engine=True,
        approximate=True,representative='2S1 Gvozdika self-propelled howitzer',skirts=0)
    b=[(-.34,1.08),(.34,1.08),(1.08,.39),(1.08,-.87),(.70,-1.35),(-.70,-1.35),(-1.08,-.87),(-1.08,.39)]
    t=[(-.32,.77),(.32,.77),(.89,.30),(.90,-.85),(.61,-1.19),(-.61,-1.19),(-.90,-.85),(-.89,.30)]
    def fittings(h,m,s,l):
        h.box('paint',(0,.91,3.64),(2.12,.36,.06))
        h.box('paint',(0,.92,-3.66),(.88,.90,.08))
        m.box('paint',(0,1.93,-2.14),(.88,.38,.19))
        for side in (-1,1):
            beam(h,'metal_dark',(side*1.14,.52,-3.60),(side*1.14,.52,-3.82),.06)
    rig,s=finish(s,b,t,lod,fittings)
    # 2S1 has a low episcope commander station, no tank CITV or roof HMG.
    rig.parts=[p for p in rig.parts if p['name'] not in ('CITV','Commander_MG')]
    g=Mesh();n=6 if lod else 12;gy=s.gun_y;gz=s.gun_z;tip=s.overall_length-s.length/2
    g.box('paint',(0,gy,gz+.09),(.65,.44,.64))
    g.tube('metal_dark',(0,gy,gz+.24),(0,gy,gz+1.05),.115,n)
    g.tube('metal_dark',(0,gy,gz+1.04),(0,gy,tip-.35),.088,n)
    # Two connected baffles with open bore and visible lateral gas ports.
    hollow_muzzle(g,[0,gy,tip-.35],[0,gy,tip],.115,.061,n)
    for zz in (tip-.29,tip-.08):g.box('metal_dark',(0,gy,zz),(.32,.25,.075))
    if not lod:
        for side in (-1,1):g.box('metal_dark',(side*.14,gy,tip-.19),(.055,.25,.25))
    for p in rig.parts:
        if p['name']=='Gun':p['mesh']=g
    return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith('artillery__') and callable(f)}

def save(slug):
    from validate_p2_armour import validate
    a,s=BUILDERS[slug](0);b,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
    spec=asdict(s);spec.update(mobility='tracked',weapon='howitzer',family=s.shape,equipment='',axle_z=[])
    c=Mesh();c.box('metal_dark',(0,s.deck/2,0),(s.width,s.deck,s.length))
    path=ART/'vehicles'/f'{slug}.glb'
    write_glb(path,[a,b],make_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P3','spec':spec,
        'units':'metres','up':'+Y','front':'+Z','detached_turret':True,'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}})
    entry,tree=validate(path);entry['notes']=entry['notes'].replace('generate_p2_armour.py + armour_parts.py','generate_p3_artillery.py')
    (Path(__file__).parent/'reports'/f'{slug}.node-tree.txt').write_text(tree,encoding='utf-8')
    print(tree);print('PASS',slug,entry['triangles'],flush=True);return entry

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
    manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
