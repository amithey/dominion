"""Original designation-specific P5 helicopters, NumPy/stdlib, no Blender."""
from dataclasses import asdict
from pathlib import Path
import argparse,json
from helicopter_parts import HelicopterSpec,build,burnt_wreck
from vehicle_parts import Mesh,write_glb

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={
 'bell':'https://www.bellflight.com/products/-/media/site-specific/bell-flight/documents/products/412/bell-412epi-fact-sheet.pdf',
 'dhruv':'https://hal-india.co.in/backend/wp-content/uploads/2023/05/297_Download_ALH-DHRUV-UPGRADED-CIVIL.pdf',
 'h225':'https://www.airbus.com/en/products-services/helicopters/military-helicopters/h225m/h225m-technical-information',
 'surion':'https://www.koreaaero.com/KO/Business/KUH1.aspx',
 'merlin':'https://www.leonardo.com/documents/15646808/16756390/BROCHURE_AW101_Mk517.pdf',
 'mi':'https://rdl.train.army.mil/catalog-ws/view/100.ATSC/9132D7F5-95A6-4723-A29E-B1D4B6F8E3CE-1456490341914/tc3_01x80.pdf',
 'blackhawk':'https://www.lockheedmartin.com/content/dam/lockheed-martin/rms/documents/black-hawk/9221_S-70_Brochure_2024_web.pdf',
 'nh90':'https://www.nhindustries.com/wp-content/uploads/2025/06/NH90_Brochure_NHI_2024.pdf',
 'chinook':'https://www.boeing.com/defense/military-rotorcraft/h-47-chinook',
 'apache':'https://www.boeing.com/content/theboeingcompany/us/en/defense/military-rotorcraft/ah-64-apache.html',
 'wildcat':'https://www.leonardo.com/documents/16114711/0/AW159_LDO_UK24_00856_1024.pdf',
}
# Body length/width/height, belly clearance, hub Y/Z, main diameter/blades,
# tail diameter/blades, landing gear, source. Body length excludes rotor sweep.
FAMILIES={
 'bell412':(12.92,2.50,2.20,.62,3.85,2.55,14.02,4,2.60,2,'skid','bell'),
 'dhruv':(12.89,2.05,2.20,.72,3.89,2.72,13.20,4,2.55,4,'skid','dhruv'),
 'h225':(16.79,2.80,2.80,.75,4.43,2.95,16.20,5,3.15,4,'tricycle','h225'),
 'surion':(15.00,2.45,2.55,.78,4.00,2.60,15.80,4,3.10,4,'tricycle','surion'),
 'merlin':(19.53,3.20,3.20,.90,5.15,3.65,18.60,5,4.00,4,'tricycle','merlin'),
 'mi17':(18.17,2.50,3.25,.85,5.05,3.65,21.29,5,3.91,3,'tricycle','mi'),
}

# z/body length, centre offset/body height, half-width/body width,
# half-height/body height: cabin shapes differ independently of size.
PROFILES={
 'bell412':[(.00,.13,.18,.23),(.045,0,.43,.46),(.14,0,.50,.50),(.31,0,.50,.50),(.405,-.02,.42,.43),(.475,-.15,.24,.27),(.50,-.18,.055,.09)],
 'dhruv':[(-.035,.12,.20,.24),(.025,0,.42,.44),(.13,0,.50,.50),(.29,0,.50,.50),(.40,-.04,.43,.43),(.475,-.17,.20,.24),(.50,-.19,.045,.065)],
 'h225':[(-.045,.16,.17,.22),(.015,.03,.40,.43),(.12,0,.50,.50),(.27,0,.50,.50),(.38,-.025,.44,.45),(.475,-.20,.20,.25),(.50,-.22,.04,.06)],
 'surion':[(-.03,.15,.20,.25),(.03,.02,.45,.46),(.14,0,.50,.50),(.30,0,.50,.50),(.405,-.01,.46,.46),(.475,-.13,.26,.30),(.50,-.16,.08,.10)],
 'merlin':[(-.17,0,.35,.43),(-.12,.01,.46,.45),(.02,0,.50,.50),(.26,0,.50,.50),(.39,-.025,.47,.47),(.475,-.13,.26,.29),(.50,-.18,.055,.09)],
 'mi17':[(.00,.15,.26,.27),(.055,0,.46,.47),(.17,0,.50,.50),(.34,0,.50,.49),(.445,-.015,.43,.44),(.485,-.11,.22,.28),(.50,-.16,.065,.12)],
}

def model(slug,name,lod,family,representative='',**overrides):
    L,W,H,b,hy,hz,D,N,td,tn,gear,ref=FAMILIES[family]
    s=HelicopterSpec(slug,name,family,L,W,H,b,hy,hz,D,N,td,tn,gear,REF[ref])
    if family=='merlin':s.engines=3
    if family=='mi17':s.tail_side=-1
    if family=='blackhawk':s.tail_cant=20
    s.details['tail_y']={'bell412':3.00,'dhruv':3.70,'h225':3.40,'surion':3.10,'merlin':4.66,'mi17':3.70}.get(family,hy-.35)
    if family in PROFILES:
        s.details.update(profile=PROFILES[family],boom_start=(-.10 if family=='merlin' else .08),
            window_z=((-.07,.04,.15,.26) if family=='merlin' else (.08,.18,.27)),
            main_gear_z=(.04 if family=='mi17' else .0 if family in ('surion','h225') else -.08))
    for key,value in overrides.items():setattr(s,key,value)
    s.representative=representative;s.approximate=True
    s.features=[family+' fuselage and tail profile',str(N)+'-blade '+str(D)+' m main rotor',
        str(tn)+'-blade tail rotor',gear+' landing gear',str(s.engines)+' separate turbine nacelles',
        'published rotor size; small fittings and fuselage cross-sections approximated']
    return build(s,lod)

def helicopter__bell_412epi(lod=0):
    return model('helicopter__bell_412epi','Bell 412EPi',lod,'bell412')

def helicopter__dhruv_alh(lod=0):
    return model('helicopter__dhruv_alh','Dhruv ALH',lod,'dhruv')

def helicopter__h225m(lod=0):
    return model('helicopter__h225m','H225M',lod,'h225')

def helicopter__kuh_1_surion(lod=0):
    return model('helicopter__kuh_1_surion','KUH-1 Surion',lod,'surion')

def helicopter__merlin_hc4(lod=0):
    return model('helicopter__merlin_hc4','Merlin HC4',lod,'merlin')

def helicopter__mi_17(lod=0):
    return model('helicopter__mi_17','Mi-17',lod,'mi17')

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and n.split('__')[0] in ('helicopter','gunship','navalHelicopter','heavyLift','scoutHelicopter') and callable(f)}

def save(slug,output_dir=None,tree_dir=None,print_tree=True):
    from validate_aircraft import validate
    a,s=BUILDERS[slug](0);b,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
    out=Path(output_dir) if output_dir else ART/'aircraft';out.mkdir(exist_ok=True)
    path=out/(slug+'.glb');collision=Mesh();top=s.belly+s.body_height
    collision.box('metal_dark',(0,top/2,0),(s.width,top,s.length))
    write_glb(path,[a,b],burnt_wreck(b,s),collision,{'scene_name':s.name,'vehicle':slug,'priority':'P5','spec':asdict(s),
         'units':'metres','up':'+Y','front':'+Z','detached_turret':False})
    entry,tree=validate(path)
    treepath=(Path(tree_dir) if tree_dir else Path(__file__).parent/'reports')/(slug+'.node-tree.txt')
    treepath.write_text(tree,encoding='utf-8')
    if print_tree:print(tree)
    print('PASS',slug,entry['triangles'],flush=True);return entry

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    path=ART/'MANIFEST.json';old=json.loads(path.read_text());updates={e['file']:e for e in entries}
    path.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n')
    a.report.write_text(json.dumps(entries,indent=2)+'\n')
if __name__=='__main__':main()
