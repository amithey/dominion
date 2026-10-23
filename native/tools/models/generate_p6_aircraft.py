"""Original designation-specific P6 airframes. NumPy/stdlib, no Blender."""
from dataclasses import asdict
from pathlib import Path
import argparse,json
from aircraft_parts import AircraftSpec,build,burnt_wreck
from vehicle_parts import Mesh,write_glb
ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={'typhoon':'https://www.bundeswehr.de/en/organization/german-air-force/eurofighter',
     'f15':'https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104499/f-15e-strike-eagle/',
     'f16':'https://www.mindef.gov.sg/news-and-events/latest-releases/24sep23_fs/'}

def model(slug,name,lod,family,seats=1,cft=False,representative=''):
    if family=='typhoon':
        L,S,H,W,B,b=15.96,10.95,5.28,1.85,1.7,1.05;y=b+B*.48
        d={'wing':[(.5,y,2.2,-5.0),(2,y,.7,-4.9),(4,y,-1.9,-4.7),(S/2,y,-3.55,-4.43)],
           'fins':[(0,2.6,H,-3.35,-7.34,-5.90,-6.86)],
           'canard':[(.65,2.15,4.5,2.6),(2.4,2.15,3.2,2.7)],'engine_spacing':.90,'engine_radius':.43,
           'profile':[(-.455,0,.28,.32),(-.42,0,.47,.47),(-.25,0,.5,.5),(0,0,.5,.5),(.15,.24,.36,.40),(.30,.06,.25,.33),(.42,.03,.15,.20),(.5,0,.012,.020)]}
        features=['delta wing with separate trailing-edge controls','foreplane canards','paired chin intake ducts','two recessed engine nozzles','single swept vertical tail']
    elif family=='f15':
        L,S,H,W,B,b=19.44,13.05,5.6,2.4,1.7,1.15;y=b+B*.70
        d={'wing':[(1,y,2.0,-4.4),(3.8,y,-.35,-4.15),(S/2,y,-2.6,-3.9)],
           'fins':[(-1.0,2.5,H,-4.8,-9.1,-7.3,-8.35),(1.0,2.5,H,-4.8,-9.1,-7.3,-8.35)],
           'stabilator':[(.9,2.05,-4.8,-8.85),(4.25,2.05,-7.2,-8.5)],
           'engine_spacing':1.64,'engine_radius':.63,'gear_track':2.65,'cft':cft,'variant':('ex' if 'f_15ex' in slug else 'i' if 'f_15i_' in slug else 'sa' if 'f_15sa' in slug else 'j'),
           'profile':[(-.455,0,.28,.32),(-.42,0,.47,.47),(-.25,0,.5,.5),(0,0,.5,.5),(.15,.04,.30,.43),(.30,.06,.25,.33),(.42,.03,.15,.20),(.5,0,.012,.020)]}
        features=['broad trapezoidal wings','parallel twin vertical tails','paired rectangular lateral intakes','two engine nozzles','all-moving rear stabilators',str(seats)+'-seat canopy']
        if cft:features.append('paired conformal fuel tanks along inlet and fuselage sides')
    else:
        L,S,H,W,B,b=15.06,10.01,4.88,1.25,1.4,1.0;y=b+B*.48
        d={'wing':[(.5,y,.9,-3.2),(2.4,y,-.1,-2.8),(S/2,y,-1.3,-2.3)],
           'fins':[(0,2.1,H,-2,-6.4,-4.4,-5.9)],
           'stabilator':[(.4,1.8,-3.6,-6.4),(2.75,1.8,-5.1,-6.1)],'gun_side':-1,
           'profile':[(-.455,0,.38,.38),(-.40,0,.5,.5),(-.25,0,.5,.5),(0,.05,.5,.45),(.15,.20,.46,.42),(.30,.10,.34,.35),(.42,.04,.20,.20),(.5,0,.012,.02)]}
        features=['single recessed jet nozzle','elliptical underslung intake','single swept vertical tail','swept trapezoidal wings','all-moving stabilators']
    s=AircraftSpec(slug,name,family,L,S,H,W,B,b,1 if family=='f16' else 2,REF[family],seats=seats,
        representative=representative,features=features,details=d)
    return build(s,lod)

def jet__eurofighter_typhoon(lod=0):return model('jet__eurofighter_typhoon','Eurofighter Typhoon',lod,'typhoon')
def jet__f_15ex_eagle_ii(lod=0):return model('jet__f_15ex_eagle_ii','F-15EX Eagle II',lod,'f15',2,True)
def jet__f_15i_ra_am(lod=0):return model('jet__f_15i_ra_am',"F-15I Ra'am",lod,'f15',2,True)
def jet__f_15j(lod=0):return model('jet__f_15j','F-15J',lod,'f15')
def jet__f_15sa(lod=0):return model('jet__f_15sa','F-15SA',lod,'f15',2,True)
def jet__f_16_mig_29(lod=0):return model('jet__f_16_mig_29','F-16 / MiG-29',lod,'f16',representative='F-16C exterior')

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}
def save(slug,output_dir=None,tree_dir=None,print_tree=True):
    from validate_aircraft import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    out=Path(output_dir) if output_dir else ART/'aircraft';out.mkdir(exist_ok=True)
    path=out/(slug+'.glb');collision=Mesh();top=s.belly+s.body_height
    collision.box('metal_dark',(0,top/2,0),(s.body_width,top,s.length))
    write_glb(path,[a,b],burnt_wreck(b,s),collision,{'scene_name':s.name,'vehicle':slug,'priority':'P6','spec':asdict(s),
        'units':'metres','up':'+Y','front':'+Z','detached_turret':False})
    entry,tree=validate(path);folder=Path(tree_dir) if tree_dir else Path(__file__).parent/'reports'
    folder.mkdir(exist_ok=True);(folder/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8')
    if print_tree:print(tree)
    print('PASS',slug,entry['triangles'],flush=True);return entry

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();a.report.write_text(json.dumps([save(x) for x in a.types],indent=2)+'\n')
