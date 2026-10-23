"""Designation-specific original P7 naval models, built with NumPy/stdlib."""
from dataclasses import asdict
from pathlib import Path
import argparse,json
from ship_parts import ShipSpec,build,wreck
from vehicle_parts import Mesh,write_glb
ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'

def combatant(slug,name,lod,dimensions,source,features,**details):
    s=ShipSpec(slug,name,*dimensions,source,features=features,details=details)
    return build(s,lod)

def destroyer__arleigh_burke_class(lod=0):
    return combatant('destroyer__arleigh_burke_class','Arleigh Burke-class',lod,(155.29,20.4,6.3,5.2),
        'https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2169871/destroyers-ddg/destroyers-ddg-51/',
        ['Flight IIA representative with twin helicopter hangar','raked bow and flared shoulder','two separated funnels','forward and aft Mk41 banks: 32 + 64 cells','forward Mk45 127 mm gun','fixed SPY panels and separate search radar'],
        houses=[(0,19,15,36,7,0,.83),(0,-30,15.3,27,6,0,.91),(0,17,11,18,4,7,.84)],
        funnels=[(0,-2,5,7,9,3),(0,-18,5,7,9,3)],masts=[(13,25,'bar',5.5),(-20,17,'bar',3.6)],
        fixed_arrays=[20,8.7,12],guns=[(0,53,127,6.8)],vls=[(37,8,4,.76,0),(-37,8,8,.76,6.1)],
        canisters=[],ciws=[(0,-16,10)],hangar_z=-43.6,hangar_doors=2)

def destroyer__choe_hyon_class(lod=0):
    rig,s=combatant('destroyer__choe_hyon_class','Choe Hyon-class',lod,(143.,15.4,5.2,4.7),
        'https://beyondparallel.csis.org/north-korea-launches-the-choe-hyon-guided-missile-destroyer/',
        ['approximate April 2025 launch configuration','tall faceted forward bridge and pyramidal mast','single central exhaust enclosure','three mixed-size VLS groups, 74 visible launch-configuration cells','127 mm bow gun and aft close-in mount','stern helicopter deck without a full-size hangar'],
        houses=[(0,13,12.5,37,8.6,0,.80),(0,-24,11.5,21,5,0,.82),(0,15,8,17,4,8.6,.7)],
        funnels=[(0,-7,6,9,6.5,4)],masts=[(12,27,'panel',4.8)],fixed_arrays=[15,13,8.5],
        guns=[(0,49,127,6.2)],vls=[(34,8,4,.70,0),(-12,6,6,.85,0),(-30,3,2,1.12,5.1)],
        canisters=[(-4,4,4)],ciws=[(0,-30,5.3)],hangar=False)
    s.representative='April 2025 public launch exterior; dimensions and hidden arrangement estimated';return rig,s

def destroyer__de_zeven_provincien_class(lod=0):
    return combatant('destroyer__de_zeven_provincien_class','De Zeven Provincien-class',lod,(144.,18.8,5.2,4.8),
        'https://www.defensie.nl/onderwerpen/m/materieel/schepen/luchtverdedigings-en-commandofregatten-lcf',
        ['large forward 127 mm turret','40-cell foredeck VLS','APAR faceted forward mast','wide rotating SMART-L array aft','two broad raked funnels','single aft helicopter hangar'],
        houses=[(0,14,14,34,7,0,.82),(0,-29,14,24,5.5,0,.90),(0,17,10,15,4.5,7,.72)],
        funnels=[(0,-3,5.2,7,8.5,3),(0,-17,5.2,6.4,8.5,3)],masts=[(-22,25,'panel',8.),(16,23,'bar',3.2)],
        fixed_arrays=[16,16,7],guns=[(0,51,127,6.4)],vls=[(35,8,5,.73,0)],canisters=[(-6,3,4)],ciws=[(0,-29,6)],hangar_z=-41.1)

def destroyer__f124_sachsen_class(lod=0):
    return combatant('destroyer__f124_sachsen_class','F124 Sachsen-class',lod,(143.,17.4,6.,4.5),
        'https://www.bundeswehr.de/de/ausruestung-technik-bundeswehr/seesysteme-bundeswehr/sachsen-klasse-f124-fregatte',
        ['compact forward 76 mm gun','32 Mk41 foredeck cells','four-faced APAR mast','large SMART-L rotating aft array','paired funnels','two helicopter hangar doors','forward and aft short-range defence mounts'],
        houses=[(0,13,13,34,7,0,.82),(0,-30,13,25,5.5,0,.91),(0,16,8,14,4.4,7,.72)],
        funnels=[(0,-3,5,7,8,3),(0,-16,5,6,8,3)],masts=[(-20,24,'panel',7.5),(16,22,'bar',3)],fixed_arrays=[16,15,6.5],
        guns=[(0,50,76,4.)],vls=[(35,8,4,.74,0)],canisters=[(-6,3,4)],ciws=[(0,28,5),(0,-31,6)],hangar_z=-42.6,hangar_doors=2)

def destroyer__hobart_class(lod=0):
    return combatant('destroyer__hobart_class','Hobart-class',lod,(146.7,18.6,7.2,4.6),
        'https://www.navy.gov.au/capabilities/ships-boats-and-submarines/hmas-hobart-iii',
        ['F100-derived tall forward Aegis bridge','48-cell forward Mk41 bank','single forward 127 mm Mk45 gun','two funnels and integrated pyramidal mast','single helicopter hangar','two quadruple Harpoon canister sets'],
        houses=[(0,13,14,40,8,0,.78),(0,-29,13.5,23,6,0,.91),(0,17,9.5,17,4.5,8,.80)],
        funnels=[(0,-3,4.8,6.5,8.5,3),(0,-17,4.8,6,8.5,3)],masts=[(14,26,'bar',4.0),(-22,18,'bar',3)],fixed_arrays=[17,10,11],
        guns=[(0,51,127,7.)],vls=[(34,8,6,.73,0)],canisters=[(-5,3,4)],ciws=[(0,-30,6.5)],hangar_z=-40.6)

def destroyer__horizon_class(lod=0):
    rig,s=combatant('destroyer__horizon_class','Horizon-class',lod,(153.,20.3,5.4,5.6),
        'https://www.naviris.com/naviris-horizon-frigates-mid-life-upgrade-progress/',
        ['Italian Andrea Doria representative','two forward 76 mm mounts and one hangar-roof 76 mm mount','48-cell Sylver foredeck bank','EMPAR radome on high forward mast','S1850M rotating aft radar','separated raked exhaust structures'],
        houses=[(0,15,15.5,36,7.5,0,.83),(0,-30,14.8,25,6,0,.90),(0,16,10,17,4,7.5,.75)],
        funnels=[(0,-4,5.5,7,9,3),(0,-18,5.2,6,9,3)],masts=[(15,29,'sphere',4.0),(-22,25,'panel',7.2)],
        guns=[(-3,52,76,4.2),(3,52,76,4.2),(0,-34,76,4.2,6,True)],vls=[(36,8,6,.70,0)],canisters=[(-6,3,4)],ciws=[],hangar_z=-42.6)
    s.representative='Italian Andrea Doria pre-MLU exterior, three 76 mm guns';return rig,s

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and not n.startswith('_') and callable(f)}

def save(slug,output_dir=None,tree_dir=None,print_tree=True):
    from validate_ships import validate
    a,s=BUILDERS[slug](0);b,t=BUILDERS[slug](1);assert asdict(s)==asdict(t)
    out=Path(output_dir) if output_dir else ART/'ships';out.mkdir(exist_ok=True)
    path=out/(slug+'.glb');collision=Mesh();h=s.draft+s.freeboard
    collision.box('metal_dark',(0,h/2,0),(s.beam,h,s.length))
    write_glb(path,[a,b],wreck(b),collision,{'scene_name':s.name,'vehicle':slug,'priority':'P7','spec':asdict(s),
        'units':'metres','up':'+Y','front':'+Z','waterline_y':s.draft,'detached_turret':False})
    entry,tree=validate(path);folder=Path(tree_dir) if tree_dir else Path(__file__).parent/'reports';folder.mkdir(exist_ok=True)
    (folder/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8')
    if print_tree:print(tree)
    print('PASS',slug,entry['triangles'],flush=True);return entry

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();a.report.write_text(json.dumps([save(x) for x in a.types],indent=2)+'\n',encoding='utf-8')
