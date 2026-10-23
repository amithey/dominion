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
        canisters=[(-4,4,4)],ciws=[(0,-30,5.3)],ciws_style='kashtan',hangar=False)
    s.representative='April 2025 public launch exterior; dimensions and hidden arrangement estimated';return rig,s

def destroyer__de_zeven_provincien_class(lod=0):
    return combatant('destroyer__de_zeven_provincien_class','De Zeven Provincien-class',lod,(144.,18.8,5.2,4.8),
        'https://www.defensie.nl/onderwerpen/m/materieel/schepen/luchtverdedigings-en-commandofregatten-lcf',
        ['large forward 127 mm turret','40-cell foredeck VLS','APAR faceted forward mast','wide rotating SMART-L array aft','two broad raked funnels','single aft helicopter hangar'],
        houses=[(0,14,14,34,7,0,.82),(0,-29,14,24,5.5,0,.90),(0,17,10,15,4.5,7,.72)],
        funnels=[(0,-3,5.2,7,8.5,3),(0,-17,5.2,6.4,8.5,3)],masts=[(-22,25,'panel',8.),(16,23,'bar',3.2)],
        fixed_arrays=[16,16,7],guns=[(0,51,127,6.4)],vls=[(35,8,5,.73,0)],canisters=[(-6,3,4)],ciws=[(0,-29,6)],ciws_style='goalkeeper',hangar_z=-41.1)

def destroyer__f124_sachsen_class(lod=0):
    return combatant('destroyer__f124_sachsen_class','F124 Sachsen-class',lod,(143.,17.4,6.,4.5),
        'https://www.bundeswehr.de/de/ausruestung-technik-bundeswehr/seesysteme-bundeswehr/sachsen-klasse-f124-fregatte',
        ['compact forward 76 mm gun','32 Mk41 foredeck cells','four-faced APAR mast','large SMART-L rotating aft array','paired funnels','two helicopter hangar doors','forward and aft short-range defence mounts'],
        houses=[(0,13,13,34,7,0,.82),(0,-30,13,25,5.5,0,.91),(0,16,8,14,4.4,7,.72)],
        funnels=[(0,-3,5,7,8,3),(0,-16,5,6,8,3)],masts=[(-20,24,'panel',7.5),(16,22,'bar',3)],fixed_arrays=[16,15,6.5],
        guns=[(0,50,76,4.)],vls=[(35,8,4,.74,0)],canisters=[(-6,3,4)],ciws=[(0,28,5),(0,-31,6)],ciws_style='ram',hangar_z=-42.6,hangar_doors=2)

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

def destroyer__istanbul_class(lod=0):
    return combatant('destroyer__istanbul_class','Istanbul-class',lod,(113.2,14.4,4.15,4.0),
        'https://www.stm.com.tr/en/i-class-frigate',
        ['extended MILGEM hull','16-cell MIDLAS foredeck bank','76 mm bow gun','single broad exhaust block','CENK-S rotating array','16 Atmaca canisters amidships','single Seahawk hangar'],
        houses=[(0,8,10.8,30,5.8,0,.82),(0,-22,10.8,20,5,0,.92),(0,11,7.7,12,3.2,5.8,.70)],
        funnels=[(0,-5,4,8,6.5,3)],masts=[(7,21,'panel',3.7)],guns=[(0,39,76,4.2)],vls=[(27,4,4,.72,0)],
        canisters=[(-1,3,8)],ciws=[(0,-22,5.5)],ciws_style='gokdeniz',hangar_z=-32.1)

def destroyer__maya_class(lod=0):
    return combatant('destroyer__maya_class','Maya-class',lod,(170.,21.,6.2,5.8),
        'https://www.mod.go.jp/msdf/equipment/ships/ddg/maya/',
        ['long Japanese Aegis destroyer hull','high raked forward bridge','two separated exhaust stacks','96 Mk41 cells: 64 forward and 32 aft','127 mm L62 bow gun','single aft hangar','two Phalanx mounts'],
        houses=[(0,20,16,41,8.8,0,.83),(0,-33,16,26,6,0,.91),(0,21,11,20,4,8.8,.82)],
        funnels=[(0,-3,5.5,8,10,3),(0,-21,5.5,7,10,3)],masts=[(17,30,'bar',5.5),(-22,20,'bar',3.8)],fixed_arrays=[22,11,13],
        guns=[(0,61,127,7.6)],vls=[(42,8,8,.76,0),(-35,8,4,.76,6.1)],canisters=[(-10,3,4)],ciws=[(0,32,9),(0,-35,6.3)],hangar_z=-46.1)

def destroyer__moudge_class(lod=0):
    rig,s=combatant('destroyer__moudge_class','Moudge-class',lod,(94.5,11.,3.2,3.8),
        'https://calhoun.nps.edu/server/api/core/bitstreams/ea671a69-0376-42ec-a853-6d2ab38676dc/content',
        ['Jamaran representative','narrow conventional frigate hull','stepped box bridge and lattice-style mast','single funnel','76 mm foredeck gun and 40 mm aft mount','four Noor canisters','open stern helicopter platform without hangar'],
        houses=[(0,7,8.3,24,4.8,0,.95),(0,-14,6.8,16,3,0,.93),(0,9,6.5,10,2.5,4.8,.95)],
        funnels=[(0,-5,3.6,5,6,2)],masts=[(5,20,'bar',4.8),(-12,12,'bar',2.6)],guns=[(0,32,76,4),(0,-24,40,2.4,0,True)],
        vls=[],canisters=[(-7,2,2)],ciws=[],hangar=False,bow_sheer=1.0)
    s.representative='Jamaran lead-ship exterior; later Moudge fits vary';return rig,s

def destroyer__sejong_the_great_class(lod=0):
    rig,s=combatant('destroyer__sejong_the_great_class','Sejong the Great-class',lod,(166.,21.4,6.25,5.6),
        'https://www.govinfo.gov/content/pkg/GOVPUB-D5-PURL-gpo19516/pdf/GOVPUB-D5-PURL-gpo19516.pdf',
        ['KDX-III Batch I representative','broad Aegis superstructure','128 VLS cells: 80 Mk41 and 48 K-VLS','two exhaust blocks','127 mm forward gun','large twin helicopter hangar','16 antiship canisters'],
        houses=[(0,19,16.5,40,8,0,.83),(0,-32,16,27,6,0,.91),(0,20,11.5,19,4,8,.82)],
        funnels=[(0,-1,5.6,8,10,3),(0,-20,5.6,7.5,10,3)],masts=[(16,28,'bar',5.6),(-23,20,'bar',3.8)],fixed_arrays=[20,10,13],
        guns=[(0,59,127,7.)],vls=[(40,8,6,.76,0),(-31,8,4,.76,6.1),(-40,8,6,.76,6.1)],
        canisters=[(-8,3,8)],ciws=[(0,29,9),(0,-32,7)],ciws_styles=['ram','goalkeeper'],rail_count=28,hangar_z=-45.6,hangar_doors=2)
    s.representative='KDX-III Batch I; approximate topside arrangement';return rig,s

def destroyer__type_055(lod=0):
    return combatant('destroyer__type_055','Type 055',lod,(180.,20.,6.6,5.5),
        'https://eng.mod.gov.cn/xb/News_213114/TopStories/4862976.html',
        ['large continuous stealth superstructure','integrated faceted radar tower','112 universal VLS cells: 64 forward, 48 aft','130 mm bow gun','twin helicopter hangar','enclosed exhaust blocks'],
        houses=[(0,16,16.7,55,9,0,.84),(0,-39,16.5,29,7,0,.91),(0,22,11,22,8,9,.65)],
        funnels=[(0,-9,6,9,7,6),(0,-27,6,8,7,6)],masts=[(22,31,'bar',4.6),(-23,21,'bar',3.5)],fixed_arrays=[22,14,12],
        guns=[(0,65,130,7.6)],vls=[(45,8,8,.85,0),(-39,8,6,.85,7.1)],canisters=[],ciws=[(0,32,9.4),(0,-43,7.4)],ciws_styles=['gatling','ram'],ciws_tubes=24,
        hangar_z=-53.6,hangar_doors=2,hull_profile=[(-.5,.68),(-.42,.86),(-.2,1),(.16,1),(.31,.84),(.43,.48),(.49,.1),(.5,.008)])

def destroyer__type_45(lod=0):
    return combatant('destroyer__type_45','Type 45',lod,(152.4,21.2,7.4,4.8),
        'https://www.royalnavy.mod.uk/equipment/ships/daring-class',
        ['very high pyramidal SAMPSON mast with spherical rotating radar','large aft S1850M rotating planar array','two raked funnels','48-cell Sylver VLS','114 mm bow gun','single Merlin hangar','clean enclosed sides'],
        houses=[(0,15,16,37,8,0,.81),(0,-31,15.8,24,6,0,.91),(0,18,10,18,5,8,.70)],
        funnels=[(0,-3,5.5,7,9,3),(0,-18,5.5,7,9,3)],masts=[(17,32,'sphere',4.1),(-23,27,'panel',7.8)],
        guns=[(0,54,114,6.)],vls=[(36,8,6,.72,0)],canisters=[],ciws=[(-7,-20,5),(7,-20,5)],hangar_z=-43.1)

def destroyer__udaloy_class(lod=0):
    rig,s=combatant('destroyer__udaloy_class','Udaloy-class',lod,(163.,19.3,7.8,4.5),
        'https://www.usni.org/magazines/proceedings/2020/september/modernizing-udaloy-class-asw-destroyers',
        ['Project 1155 original ASW fit','two separate 100 mm forward gunhouses','large side-by-side Rastrub canister groups','two tall sensor masts','two helicopter hangar doors','twin broad funnels'],
        houses=[(0,13,14,36,6.5,0,.95),(0,-33,15,27,6,0,.94),(0,17,10,15,4,6.5,.94)],
        funnels=[(0,-3,6,8,8.5,3),(0,-22,6,8,8.5,3)],masts=[(15,27,'panel',7),(-23,25,'panel',6)],
        guns=[(0,60,100,5.5),(0,46,100,5.5,2.1)],vls=[(35,2,2,2.2,0),(-33,2,2,2.2,6.1)],vls_carousel=True,canisters=[(18,4,4)],ciws=[(-6,-6,5),(6,-6,5)],
        ciws_style='gatling',hangar_z=-46.6,hangar_doors=2)
    s.representative='Original Project 1155 exterior, not the Shaposhnikov modernisation';return rig,s

def destroyer__visakhapatnam_class(lod=0):
    return combatant('destroyer__visakhapatnam_class','Visakhapatnam-class',lod,(163.,17.4,6.5,4.7),
        'https://www.pib.gov.in/Pressreleaseshare.aspx?PRID=1768017&lang=2&reg=48',
        ['Project 15B destroyer','faceted bridge and enclosed MF-STAR mast','two exhaust blocks','16 large BrahMos cells and 32 Barak-8 cells','76 mm bow gun','two helicopter hangar doors','AK-630 close-in mounts'],
        houses=[(0,17,13,39,7.5,0,.82),(0,-32,13.6,25,6,0,.91),(0,19,8.5,16,5,7.5,.68)],
        funnels=[(0,-3,5,7,9,3),(0,-20,5,7,9,3)],masts=[(18,27,'bar',3.8),(-22,20,'bar',3.5)],fixed_arrays=[19,16,7.7],
        guns=[(0,59,76,4.4)],vls=[(43,4,4,1.08,0),(31,8,4,.67,0)],canisters=[],ciws=[(-6,-7,5),(6,-7,5)],ciws_style='gatling',hangar_z=-44.6,hangar_doors=2)

def aegisCruiser__maya_class_aegis_destroyer(lod=0):
    rig,s=destroyer__maya_class(lod);s.slug='aegisCruiser__maya_class_aegis_destroyer';s.name='Maya-class Aegis destroyer';return rig,s

def type45__type_45_destroyer(lod=0):
    rig,s=destroyer__type_45(lod);s.slug='type45__type_45_destroyer';s.name='Type 45 Destroyer';return rig,s

def corvette__ada_class(lod=0):
    return combatant('corvette__ada_class','Ada-class',lod,(99.56,14.42,3.85,3.9),
        'https://www.stm.com.tr/en/ada-class-corvette',
        ['short MILGEM corvette hull','76 mm foredeck gun','no forward VLS bank','eight Harpoon canisters amidships','21-round RAM on hangar roof','single funnel and SMART-S mast','single Seahawk hangar'],
        houses=[(0,7,10.5,28,5.4,0,.83),(0,-20,10.8,18,4.8,0,.92),(0,10,7.2,12,3,5.4,.72)],
        funnels=[(0,-4,4.1,7.2,6.8,2.5)],masts=[(8,20,'panel',3.8)],guns=[(0,34,76,4.2)],vls=[],canisters=[(-1,2.6,4)],ciws=[(0,-21,5)],ciws_style='ram',hangar_z=-29.1)

def corvette__al_jubail_class(lod=0):
    return combatant('corvette__al_jubail_class','Al Jubail-class',lod,(104.,14.,3.85,3.9),
        'https://www.navantia.es/en/news/press-releases/navantia-delivers-to-the-rsnf-the-first-avante-2200-class-corvette/',
        ['AVANTE 2200 hull','angular bridge and enclosed sensor tower','single wide funnel','76 mm bow gun and 16-cell forward VLS','eight antiship canisters','aft RAM and helicopter hangar'],
        houses=[(0,7,10.8,29,5.7,0,.82),(0,-21,10.6,19,5,0,.92),(0,10,7.5,12,3.5,5.7,.68)],
        funnels=[(0,-5,4.5,7.5,6.5,2.6)],masts=[(8,22,'panel',3.6)],guns=[(0,37,76,4.2)],vls=[(25,4,4,.7,0)],canisters=[(-2,2.7,4)],ciws=[(0,-21,5.2)],ciws_style='ram',hangar_z=-30.6)

def corvette__amnok_class(lod=0):
    rig,s=combatant('corvette__amnok_class','Amnok-class',lod,(77.,10.,3.,3.2),
        'native/CODEX-UNIT-ROSTER.md',
        ['approximate public patrol ship 661 exterior','short narrow hull','stepped forward bridge','single exhaust block','100 mm forward gun','eight cruise-missile canisters','four close-in mounts and open aft working deck'],
        houses=[(0,5,7.8,24,4.7,0,.91),(0,-14,7.2,14,3.2,0,.94),(0,7,5.5,10,2.5,4.7,.91)],
        funnels=[(0,-6,3.2,4.5,5.5,2)],masts=[(5,17,'bar',3.7),(-12,12,'bar',2.3)],guns=[(0,26,100,4.7)],
        vls=[],canisters=[(-3,2.5,4)],ciws=[(-3,1,4.5),(3,1,4.5),(-3,-17,3.5),(3,-17,3.5)],ciws_style='gatling',hangar=False,flight_deck=False,bow_sheer=1.1)
    s.representative='Approximate Amnok no.661 external silhouette; dimensions and fittings are estimates';return rig,s

def corvette__anzac_class(lod=0):
    rig,s=combatant('corvette__anzac_class','Anzac-class',lod,(118.,14.8,4.5,4.4),
        'https://seapower.navy.gov.au/history/units/hmas-anzac-iii',
        ['MEKO 200 frigate hull','127 mm foredeck gun','eight-cell Mk41 bank','large CEAFAR fixed-array enclosure on foremast','one broad funnel and slender aft mast','single helicopter hangar'],
        houses=[(0,9,10.8,31,6.3,0,.92),(0,-24,10.8,22,5.3,0,.94),(0,11,7,12,3,6.3,.86)],
        funnels=[(0,-7,4.5,8,7,2.6)],masts=[(9,24,'bar',3.4),(-20,18,'bar',3.2)],fixed_arrays=[9,14,7.3],
        guns=[(0,41,127,6.5)],vls=[(27,4,2,.75,0)],canisters=[(-1,2.7,4)],ciws=[],hangar_z=-35.1)
    s.representative='Australian Anzac ASMD exterior, approximate fixed-array mast';return rig,s

def corvette__babur_class_milgem(lod=0):
    return combatant('corvette__babur_class_milgem','Babur-class (MILGEM)',lod,(108.2,14.8,4.04,4.0),
        'https://www.karachishipyard.com.pk/page/ship-building',
        ['extended Pakistan MILGEM hull','12-cell Albatros-NG foredeck bank','76 mm bow gun','six antiship canisters','Gokdeniz twin-barrel mount on aft hangar','single SMART-S mast and broad funnel'],
        houses=[(0,7,11,30,5.8,0,.83),(0,-22,11.2,19,5.1,0,.92),(0,10,7.5,12,3.2,5.8,.72)],
        funnels=[(0,-5,4.3,7.3,7,2.6)],masts=[(8,22,'panel',3.9)],guns=[(0,38,76,4.2)],vls=[(25,4,3,.75,0)],
        canisters=[(-1,2.7,3)],ciws=[(0,-22,5.3)],ciws_style='gokdeniz',hangar_z=-31.6)

def corvette__daegu_class(lod=0):
    return combatant('corvette__daegu_class','Daegu-class',lod,(122.,14.,4.15,4.5),
        'https://www.rolls-royce.com/media/press-releases/2025/27-05-2025-rolls-royce-mt30-selected-for-korean-ffx-batch-iv-programme.aspx',
        ['FFX Batch II hull','long 127 mm Mk45 bow gun','16-cell K-VLS foredeck bank','two broad exhaust structures','eight Haeseong antiship canisters','Phalanx on aft hangar roof','single helicopter hangar'],
        houses=[(0,10,10.7,31,6.3,0,.84),(0,-25,10.6,22,5.3,0,.92),(0,12,7.4,13,3.4,6.3,.78)],
        funnels=[(0,-4,4.1,6.5,7.8,2.8),(0,-15,3.9,5.5,7.8,2.8)],masts=[(10,23,'panel',4.2)],guns=[(0,43,127,7.2)],
        vls=[(29,4,4,.75,0)],canisters=[(-1,2.8,4)],ciws=[(0,-25,5.6)],hangar_z=-36.1)

def corvette__freedom_class_lcs(lod=0):
    return combatant('corvette__freedom_class_lcs','Freedom-class LCS',lod,(118.1,17.6,4.3,4.1),
        'https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2171607/littoral-combat-ship-class-lcs/',
        ['broad planing monohull','long angular aluminium superstructure','large aft flight deck and mission bay','57 mm foredeck gun','11-tube SeaRAM on hangar roof','compact TRS search mast','no Mk41 bank'],
        houses=[(0,9,13.8,45,6,0,.76),(0,-21,13.5,17,5.2,0,.90),(0,14,9.5,18,3.6,6,.75)],
        funnels=[(-3,-4,2.7,5,5.7,4),(3,-4,2.7,5,5.7,4)],masts=[(10,21,'panel',3.5)],guns=[(0,41,57,3.7)],
        vls=[],canisters=[],ciws=[(0,-22,5.5)],ciws_style='ram',ciws_tubes=11,hangar_z=-29.6,
        hull_profile=[(-.5,.86),(-.4,.97),(-.15,1),(.18,.96),(.34,.77),(.46,.37),(.5,.008)])

def corvette__gowind_2500(lod=0):
    return combatant('corvette__gowind_2500','Gowind 2500',lod,(102.,16.,3.6,4.3),
        'https://sis.gov.eg/en/media-center/news/egypts-1st-locally-built-gowind-2500-stealth-corvette-delivered/',
        ['Egyptian Al Fateh exterior','broad stealth hull and continuous angular deckhouse','PSIM integrated sensor enclosure','16 VL-MICA forward cells','76 mm bow gun','eight Exocet canisters','single helicopter hangar'],
        houses=[(0,7,12.5,32,6,0,.80),(0,-20,12.1,20,5.1,0,.91),(0,9,7.6,12,5.5,6,.70)],
        funnels=[(0,-6,4.8,7,6,3)],masts=[(8,21,'enclosed',4.8)],guns=[(0,35,76,4.2)],vls=[(24,4,4,.70,0)],
        canisters=[(-1,2.8,4)],ciws=[],hangar_z=-30.1)

def corvette__holland_class(lod=0):
    return combatant('corvette__holland_class','Holland-class',lod,(108.,16.,4.55,5.),
        'https://www.ministryofdefence.nl/documents/2022/04/01/ocean-going-patrol-vessel',
        ['high-freeboard ocean patrol hull','large forward bridge','integrated I-Mast enclosure','76 mm foredeck gun','30 mm aft gun','no antiship canisters or VLS','single NH90 hangar'],
        houses=[(0,9,12.5,31,7,0,.88),(0,-22,12,20,5.6,0,.94),(0,11,8.5,13,6,7,.65)],
        funnels=[(0,-6,4.5,7,6,3)],masts=[(10,23,'bar',3)],fixed_arrays=[11,15,6.8],guns=[(0,37,76,4.2),(0,-22,30,1.8,5.8,True)],vls=[],canisters=[],ciws=[],hangar_z=-32.1)

def corvette__k130_braunschweig(lod=0):
    return combatant('corvette__k130_braunschweig','K130 Braunschweig',lod,(89.1,13.3,3.4,3.8),
        'https://www.bundeswehr.de/de/ausruestung-technik-bundeswehr/seesysteme-bundeswehr/korvette-k130',
        ['short X-section stealth corvette','76 mm bow gun','two 21-tube RAM mounts','four RBS15 antiship canisters','two enclosed exhausts','stern helicopter platform and small UAV hangar'],
        houses=[(0,7,10.3,25,5.2,0,.80),(0,-18,9.6,15,3.8,0,.90),(0,9,6.4,10,3,5.2,.75)],
        funnels=[(0,-3,3.8,5,6,2),(0,-12,3.7,4.6,6,2)],masts=[(7,18,'panel',3.5)],guns=[(0,30,76,4.2)],vls=[],canisters=[(-5,2,2)],ciws=[(0,17,4),(0,-19,4)],ciws_style='ram',hangar_z=-25.6)

def corvette__kamorta_class(lod=0):
    return combatant('corvette__kamorta_class','Kamorta-class',lod,(109.1,14.17,4.,4.4),
        'https://grse.in/anti-submarine-warfare-corvette/index',
        ['Project 28 ASW corvette','X-section inclined topsides','76 mm gun','ASW rocket launchers on raised forward deck','two exhaust structures','no antiship canister battery','single helicopter hangar'],
        houses=[(0,9,11,31,6,0,.82),(0,-22,11,20,5.3,0,.92),(0,11,7.2,13,3.5,6,.76)],
        funnels=[(0,-4,4.3,6.3,7,3),(0,-14,4.2,5.7,7,3)],masts=[(9,22,'bar',4.8),(-16,17,'bar',3)],guns=[(0,38,76,4.2)],vls=[],canisters=[],ciws=[(-4,-20,5.5),(4,-20,5.5)],ciws_style='gatling',rbu_positions=[(-3,27,1),(3,27,1)],hangar_z=-32.1)

def corvette__karakurt_class(lod=0):
    return combatant('corvette__karakurt_class','Karakurt-class',lod,(67.,11.,3.3,3.1),
        'native/CODEX-UNIT-ROSTER.md',
        ['Project 22800 compact missile corvette','high angular bridge and integrated mast','eight UKSK cells aft of bridge','76 mm forward gun','Pantsir-type aft gun-missile mount','no helicopter hangar or landing circle'],
        houses=[(0,5,8.5,19,5.5,0,.78),(0,-13,7.8,12,3.2,0,.87),(0,6,5.4,9,3.8,5.5,.65)],
        funnels=[(0,-5,3.4,4.8,5.4,2)],masts=[(5,18,'bar',2.5)],fixed_arrays=[6,10.3,4.4],guns=[(0,23,76,4.2)],vls=[(-9,4,2,.95,3.3)],canisters=[],ciws=[(0,-15,3.5)],ciws_style='kashtan',hangar=False,flight_deck=False,bow_sheer=1.1)

def corvette__la_fayette_class(lod=0):
    rig,s=combatant('corvette__la_fayette_class','La Fayette-class',lod,(125.,15.4,4.1,5.1),
        'https://archives.defense.gouv.fr/marine/equipements/batiments-de-combat/fregates/type-la-fayette/la-fayette-f-710.html',
        ['long continuous stealth deckhouse','high swept bridge sides','100 mm enclosed bow turret','eight Exocet canisters','aft Crotale launcher','two angular exhaust blocks','single Panther hangar'],
        houses=[(0,10,12,39,7,0,.82),(0,-26,11.7,24,5.7,0,.93),(0,12,7.6,15,3.2,7,.80)],
        funnels=[(0,-3,4.5,6,6.5,4),(0,-17,4.5,6,6.5,4)],masts=[(10,23,'bar',4.5),(-20,18,'bar',3.3)],guns=[(0,44,100,5.5)],vls=[],canisters=[(-7,3,4)],ciws=[(0,-27,6)],ciws_style='crotale',ciws_tubes=8,hangar_z=-38.1)
    s.representative='Pre-renovation La Fayette fit with eight-round Crotale';return rig,s

def corvette__martadinata_class(lod=0):
    return combatant('corvette__martadinata_class','Martadinata-class',lod,(105.11,14.02,3.7,4.1),
        'https://res.cloudinary.com/damen-shipyards2/catalogue/defence-and-security/sigma/sigma-multi-mission-frigate-10514/product-sheet-sigma-multi-mission-frigate-10514.pdf',
        ['SIGMA 10514 modular frigate hull','faceted forward bridge','12-cell VL-MICA foredeck bank','76 mm bow gun','eight Exocet canisters','aft Millennium gun','single integrated exhaust and hangar'],
        houses=[(0,8,10.7,29,5.9,0,.82),(0,-21,10.8,20,5.2,0,.92),(0,10,7.5,12,3.5,5.9,.73)],
        funnels=[(0,-5,4.4,7,6.8,3)],masts=[(8,22,'panel',3.8)],guns=[(0,37,76,4.2),(0,-22,35,2.5,5.5,True)],vls=[(25,4,3,.7,0)],canisters=[(-1,2.8,4)],ciws=[],hangar_z=-31.1)

def corvette__minerva_class(lod=0):
    return combatant('corvette__minerva_class','Minerva-class',lod,(87.,10.3,3.2,3.6),
        'https://www.marina.difesa.it/noi-siamo-la-marina/pilastro-operativo/mezzi/forze-navali/SiteAssets/navi_radiate/_Corvette_old.aspx',
        ['compact conventional ASW corvette','76 mm bow turret','eight-round Albatros aft launcher','single funnel','two separated slim sensor masts','no helicopter hangar or landing deck'],
        houses=[(0,6,7.8,24,4.7,0,.95),(0,-16,6.8,14,2.8,0,.95),(0,8,5.8,10,2.2,4.7,.92)],
        funnels=[(0,-5,3.5,5.4,5.6,2)],masts=[(6,17,'bar',3.9),(-12,13,'bar',3)],guns=[(0,30,76,4.1)],vls=[],canisters=[],ciws=[(0,-22,1.2)],ciws_style='ram',ciws_tubes=8,hangar=False,flight_deck=False,bow_sheer=1.1)

def corvette__mogami_class(lod=0):
    rig,s=combatant('corvette__mogami_class','Mogami-class',lod,(133.,16.3,4.9,4.1),
        'https://www.mhi.com/jp/business/products-services/space-defense/surface-ships/frigate-mogami-class',
        ['very clean continuous stealth superstructure','enclosed pyramidal integrated mast','127 mm L62 bow gun','16-cell Mk41 bank','eight Type 17 canisters','11-tube SeaRAM on hangar','aft mine-warfare working deck'],
        houses=[(0,12,12.7,43,7,0,.80),(0,-27,12.5,23,5.6,0,.91),(0,14,8,17,7,7,.55)],
        funnels=[(0,-8,5.1,9,6.2,3.8)],masts=[(14,25,'bar',2.6)],fixed_arrays=[14,15,6.3],guns=[(0,48,127,7.6)],vls=[(32,4,4,.76,0)],canisters=[(-4,3,4)],ciws=[(0,-28,5.9)],ciws_style='ram',ciws_tubes=11,hangar_z=-38.6)
    s.representative='Mogami class with planned/retrofitted Mk41 bank';return rig,s

def corvette__opv_76_nns_aradu(lod=0):
    rig,s=combatant('corvette__opv_76_nns_aradu','OPV-76 / NNS Aradu',lod,(76.9,11.9,3.5,3.4),
        'https://www.dearsan.com/en/product/opv-76/',
        ['Dearsan OPV-76 representative for combined roster row','short high-freeboard patrol hull','long forward bridge','76 mm bow gun','compact aft gun','single exhaust','open stern working platform'],
        houses=[(0,6,8.8,25,5.2,0,.88),(0,-15,7.8,12,3.3,0,.92),(0,8,6.1,10,2.6,5.2,.81)],
        funnels=[(0,-5,3.7,5.7,5.4,2)],masts=[(6,18,'panel',3.2)],guns=[(0,26,76,4.0),(0,-20,30,1.8)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=1.2)
    s.representative='Dearsan OPV-76; not the much larger MEKO NNS Aradu';return rig,s

def corvette__sa_ar_6(lod=0):
    return combatant('corvette__sa_ar_6',"Sa'ar 6",lod,(90.,13.,3.8,3.7),
        'https://d2zo35mdb530wx.cloudfront.net/_binary/UCPthyssenkruppMarineSystems/Press-release-tkMS-hands-over-corvette-to-Israeli-Navy.pdf',
        ['dense weapon fit on a compact stealth hull','76 mm bow gun','32 Barak-8 and 40 C-Dome cells','16 antiship canisters','large fixed MF-STAR faces','two exhaust blocks','single helicopter hangar'],
        houses=[(0,7,10,27,5.7,0,.82),(0,-18,10,17,4.8,0,.92),(0,9,6.5,11,4.5,5.7,.68)],
        funnels=[(0,-3,3.7,4.7,6,2.4),(0,-11,3.6,4.5,6,2.4)],masts=[(8,21,'bar',2.8)],fixed_arrays=[9,12,6.3],guns=[(0,31,76,4.2)],
        vls=[(21,8,4,.55,0),(-18,8,5,.43,5)],canisters=[(-1,2.4,8)],ciws=[],hangar_z=-26.6)

def corvette__shahid_soleimani_class(lod=0):
    rig,s=combatant('corvette__shahid_soleimani_class','Shahid Soleimani-class',lod,(65.,14.5,2.,3.5),
        'native/CODEX-UNIT-ROSTER.md',
        ['wave-piercing twin hulls with open tunnel','wide cross deck and angular central bridge','30 mm forward gun','six antiship canisters','small vertical-launch banks','raised stern helicopter platform'],
        houses=[(0,4,8.5,21,4.8,0,.75),(0,-9,8,10,2.2,0,.84),(0,5,5.7,9,3,4.8,.65)],
        funnels=[(-3,-3,2.1,3.8,3.5,2),(3,-3,2.1,3.8,3.5,2)],masts=[(4,16,'bar',2.8)],guns=[(0,20,30,1.8)],
        vls=[(-8,4,2,.65,2.3)],canisters=[(-2,2,3)],ciws=[],hangar=False,catamaran=True,demi_beam=3.1,bow_sheer=.8)
    s.representative='Approximate 65 m / 14.5 m public-estimate class exterior; exact dimensions undisclosed';return rig,s

def corvette__tamandare_frigate(lod=0):
    return combatant('corvette__tamandare_frigate','Tamandare frigate',lod,(107.2,16.,5.2,4.2),
        'https://www.ir.tkmsgroup.com/news/after-less-than-four-years-of-construction-tkms-celebrates-the-commissioning-of-the-tamandare-frigate/6a216b0f-7ab3-46cd-a4e7-55ea494d7086',
        ['MEKO A100-derived hull','12-cell Sea Ceptor foredeck bank','76 mm bow gun','eight antiship canisters','large TRS rotating search array','single wide exhaust structure','aft 30 mm mount and helicopter hangar'],
        houses=[(0,8,12.3,30,6.1,0,.83),(0,-22,12,20,5.4,0,.92),(0,10,8.1,13,3.7,6.1,.72)],
        funnels=[(0,-6,4.8,7.5,6.8,3)],masts=[(8,23,'panel',4.5)],guns=[(0,37,76,4.2),(0,-23,30,1.8,5.6,True)],vls=[(25,4,3,.7,0)],canisters=[(-1,2.8,4)],ciws=[],hangar_z=-32.1)

def corvette__type_056a(lod=0):
    return combatant('corvette__type_056a','Type 056A',lod,(89.,11.14,4.,3.2),
        'https://eng.chinamil.com.cn/OPINIONS_209196/Opinions_209197/9986542.html',
        ['short Jiangdao ASW hull','76 mm foredeck gun','four YJ-83 canisters','eight-round HHQ-10 aft launcher','single funnel','open stern helicopter platform without a hangar','stern towed-sonar working area'],
        houses=[(0,6,8.5,25,5.1,0,.84),(0,-17,7.8,12,3.4,0,.91),(0,8,5.8,10,2.8,5.1,.76)],
        funnels=[(0,-6,3.6,5.5,5.6,2.3)],masts=[(6,18,'panel',3.5)],guns=[(0,30,76,4.2)],vls=[],canisters=[(-4,2.4,2)],ciws=[(0,-20,3.6)],ciws_style='ram',ciws_tubes=8,hangar=False,bow_sheer=1.1)

def corvette__type_23_frigate(lod=0):
    return combatant('corvette__type_23_frigate','Type 23 frigate',lod,(133.,16.1,5.5,4.5),
        'https://www.royalnavy.mod.uk/equipment/ships/duke-class',
        ['Duke-class ASW frigate','114 mm Mk8 bow gun','32-cell Sea Ceptor bank','separate bridge and tall Artisan radar mast','single large funnel','eight antiship canisters','single Merlin hangar'],
        houses=[(0,13,11.8,31,6.5,0,.94),(0,-28,11.7,24,5.5,0,.94),(0,15,7.7,13,2.8,6.5,.94)],
        funnels=[(0,-8,5.1,8.5,7.4,3)],masts=[(11,25,'panel',4.8),(-22,18,'bar',3.4)],guns=[(0,47,114,6.)],vls=[(32,8,4,.65,0)],canisters=[(-1,3,4)],ciws=[],hangar_z=-40.1)

def asFrigate__admiral_gorshkov_class(lod=0):
    return combatant('asFrigate__admiral_gorshkov_class','Admiral Gorshkov-class',lod,(135.,16.,4.53,5.2),
        'https://www.mintrans.gov.ru/press-center/branch-news/8894',
        ['Project 22350 lead-ship fit','130 mm enclosed bow turret','16 UKSK and 32 Redut foredeck cells','large fixed Polyment array tower','separate aft search radar','two Palash-type defence mounts','single helicopter hangar'],
        houses=[(0,13,12.4,35,7.2,0,.82),(0,-28,12.2,23,5.8,0,.91),(0,15,8,15,6,7.2,.65)],
        funnels=[(0,-7,5,8,7,3.5)],masts=[(14,27,'bar',3),(-20,23,'panel',5.8)],fixed_arrays=[15,15,7.6],
        guns=[(0,49,130,6.8)],vls=[(36,4,4,1.05,0),(25,8,4,.65,0)],canisters=[],ciws=[(-5,-27,6),(5,-27,6)],ciws_style='kashtan',hangar_z=-39.6)

def asFrigate__al_riyadh_class(lod=0):
    return combatant('asFrigate__al_riyadh_class','Al Riyadh-class',lod,(133.,17.,4.4,5.4),
        'native/CODEX-UNIT-ROSTER.md',
        ['enlarged Saudi La Fayette derivative','long continuous stealth deckhouse','76 mm bow gun','16-cell Sylver/Aster foredeck bank','large Arabel radome and aft search panel','eight Exocet canisters','single helicopter hangar'],
        houses=[(0,13,13.1,39,7.1,0,.82),(0,-28,12.8,24,5.8,0,.92),(0,15,8.5,16,4.1,7.1,.75)],
        funnels=[(0,-4,4.9,6.6,7,3.5),(0,-18,4.8,6.2,7,3.5)],masts=[(14,25,'sphere',3.8),(-22,21,'panel',4.6)],guns=[(0,47,76,4.2)],vls=[(32,4,4,.75,0)],canisters=[(-7,3,4)],ciws=[],hangar_z=-40.1)

def asFrigate__anzac_class(lod=0):
    rig,s=corvette__anzac_class(lod);s.slug='asFrigate__anzac_class';return rig,s

def asFrigate__daegu_class(lod=0):
    rig,s=corvette__daegu_class(lod);s.slug='asFrigate__daegu_class';return rig,s

def asFrigate__de_zeven_provincien_class(lod=0):
    rig,s=destroyer__de_zeven_provincien_class(lod);s.slug='asFrigate__de_zeven_provincien_class';return rig,s

def asFrigate__f125_class(lod=0):
    return combatant('asFrigate__f125_class','F125-class',lod,(149.5,18.8,5.4,5.3),
        'https://www.bundeswehr.de/de/ausruestung-technik-bundeswehr/seesysteme-bundeswehr/baden-wuerttemberg-klasse-f125-fregatten',
        ['two separated island superstructures','127 mm L64 forward gun','two 21-tube RAM launchers','eight Harpoon canisters','no VLS bank','large twin helicopter hangar','four embarked boat stations'],
        houses=[(0,17,14.5,31,7,0,.83),(0,-28,14.2,26,6,0,.91),(0,17,9.5,15,8,7,.60),(0,-17,8.7,15,8,6,.60)],
        funnels=[(0,2,5,7,7.5,3),(0,-15,5,7,7.5,3)],masts=[(17,28,'bar',3),(-17,27,'bar',3)],fixed_arrays=[17,16,7],guns=[(0,54,127,7.7)],
        vls=[],canisters=[(-5,3,4)],ciws=[(0,31,5),(0,-29,6.3)],ciws_style='ram',hangar_z=-41.1,hangar_doors=2)

def french_fremm(slug,name,lod,egypt=False):
    rig,s=combatant(slug,name,lod,(142.2,19.8,5.5,5.4),
        'https://www.defense.gouv.fr/marine/forces-surface/fregates-multimissions',
        ['French Aquitaine-derived FREMM hull','76 mm forward gun','Herakles radar in integrated pyramidal mast',
         '16 Aster cells without MdCN bank' if egypt else '16 Aster and 16 MdCN cells','eight Exocet canisters','two broad exhaust blocks','single NH90 hangar'],
        houses=[(0,14,15.5,40,7.5,0,.82),(0,-30,14.6,25,6,0,.92),(0,17,9.8,17,7,7.5,.60)],
        funnels=[(0,-4,5.2,7.5,7.5,3.5),(0,-20,5.2,7,7.5,3.5)],masts=[(16,27,'enclosed',4.5),(-23,18,'bar',3)],guns=[(0,51,76,4.4)],
        vls=[(35,4,4,.74,0)]+([] if egypt else [(28,4,4,.85,0)]),canisters=[(-8,3,4)],ciws=[],hangar_z=-42.6)
    s.representative='Egyptian Tahya Misr, ex-Normandie French FREMM' if egypt else 'French Aquitaine ASW exterior for combined France/Italy row';return rig,s

def asFrigate__fremm(lod=0):return french_fremm('asFrigate__fremm','FREMM',lod)

def asFrigate__fremm_tahya_misr(lod=0):return french_fremm('asFrigate__fremm_tahya_misr','FREMM (Tahya Misr)',lod,True)

def asFrigate__istanbul_class(lod=0):
    rig,s=destroyer__istanbul_class(lod);s.slug='asFrigate__istanbul_class';return rig,s

def asFrigate__martadinata_class(lod=0):
    rig,s=corvette__martadinata_class(lod);s.slug='asFrigate__martadinata_class';return rig,s

def asFrigate__mogami_class(lod=0):
    rig,s=corvette__mogami_class(lod);s.slug='asFrigate__mogami_class';return rig,s

def asFrigate__moudge_class(lod=0):
    rig,s=destroyer__moudge_class(lod);s.slug='asFrigate__moudge_class';return rig,s

def asFrigate__niteroi_class(lod=0):
    rig,s=combatant('asFrigate__niteroi_class','Niteroi-class',lod,(129.2,13.5,5.5,4.0),
        'native/CODEX-UNIT-ROSTER.md',
        ['long conventional Vosper frigate hull','114 mm bow gun','eight-round Aspide aft launcher','two amidships 40 mm gun positions','two raked funnels','separate lattice-style radar masts','single helicopter hangar'],
        houses=[(0,11,10,32,5.8,0,.96),(0,-27,10,23,4.8,0,.95),(0,13,6.9,13,2.7,5.8,.94)],
        funnels=[(0,-2,4.3,6,6.5,2.5),(0,-17,4.3,6,6.5,2.5)],masts=[(10,23,'bar',5.1),(-20,18,'panel',4.1)],guns=[(0,46,114,6.),(-4,-8,40,2.6,3),(4,-8,40,2.6,3)],
        vls=[],canisters=[(-6,2.6,2)],ciws=[(0,-28,5)],ciws_style='ram',ciws_tubes=8,hangar_z=-38.6)
    s.representative='Approximate post-MODFRAG ASW Niteroi-class exterior';return rig,s

def asFrigate__talwar_class(lod=0):
    rig,s=combatant('asFrigate__talwar_class','Talwar-class',lod,(124.8,15.2,4.2,4.8),
        'https://severnoepkb.ru/wp-content/uploads/2020/12/11356_en-1.pdf',
        ['Project 11356 first-batch exterior','100 mm forward turret','single-arm Shtil launcher','eight Club vertical-launch cells','large Fregat rotating radar','two Kashtan gun-missile mounts','single helicopter hangar'],
        houses=[(0,11,11.7,32,6.5,0,.88),(0,-26,11.6,22,5.3,0,.93),(0,13,7.6,13,3.5,6.5,.82)],
        funnels=[(0,-6,4.8,7.8,7.4,3)],masts=[(11,25,'panel',5.8),(-20,18,'bar',3.2)],guns=[(0,44,100,5.5)],
        vls=[(25,4,2,1.05,0)],canisters=[],ciws=[(-4.5,-23,5.5),(4.5,-23,5.5)],ciws_style='kashtan',arm_launcher=[0,34,0],rbu_positions=[(0,21,1)],hangar_z=-37.1)
    s.representative='Talwar first-batch fit with Shtil arm launcher';return rig,s

def chinese_frigate(slug,name,lod,pakistan=False):
    return combatant(slug,name,lod,(134.,16.,5.,4.8),
        'https://odin.t2com.army.mil/WEG/Asset/Type_054A_Class_%28Jiangkai_II_Class%29_Chinese_Frigate',
        ['Type 054A/P export frigate' if pakistan else 'Jiangkai II ASW frigate','76 mm bow gun','32-cell HQ-16 foredeck bank',
         'SR2410C planar search radar' if pakistan else 'large Fregat-style dual-plane search radar','eight angled antiship canisters','two close-in gun positions','single helicopter hangar'],
        houses=[(0,12,12.4,35,6.8,0,.86),(0,-28,12,23,5.6,0,.92),(0,14,8.3,14,3.5,6.8,.80)],
        funnels=[(0,-6,4.9,8,7.5,3)],masts=[(12,25,'panel',4.5 if pakistan else 6.2),(-20,19,'bar',3.1)],guns=[(0,48,76,4.4)],
        vls=[(32,8,4,.74,0)],canisters=[(-2,3,4)],ciws=[(-5,-24,5.8),(5,-24,5.8)],ciws_style='gatling',hangar_z=-39.6)

def asFrigate__tughril_class(lod=0):return chinese_frigate('asFrigate__tughril_class','Tughril-class',lod,True)

def asFrigate__type_054a(lod=0):return chinese_frigate('asFrigate__type_054a','Type 054A',lod)

def asFrigate__type_23(lod=0):
    rig,s=corvette__type_23_frigate(lod);s.slug='asFrigate__type_23';s.name='Type 23';return rig,s

def kcr60__kcr_60(lod=0):
    return combatant('kcr60__kcr_60','KCR-60',lod,(60.,8.1,2.6,2.7),
        'https://www.pal.co.id/hadiah-di-hari-armada-menteri-pertahanan-ri-luncurkan-kapal-cepat-rudal-kcr-60m-ke-5/',
        ['KCR-60 fifth-vessel configuration','57 mm Bofors bow gun','four Exocet canisters','compact swept bridge','single funnel and open aft gun deck','no helicopter facilities'],
        houses=[(0,4,6.4,18,3.8,0,.85),(0,-11,5.6,10,2.0,0,.91),(0,6,4.5,8,2,3.8,.78)],
        funnels=[(0,-5,2.7,4,4,1.7)],masts=[(4,13,'panel',2.5)],guns=[(0,21,57,3.4),(0,-19,20,1.4)],vls=[],canisters=[(-7,1.8,2)],ciws=[],hangar=False,flight_deck=False,bow_sheer=.8)

def missileBoat__ambassador_mk_iii(lod=0):
    return combatant('missileBoat__ambassador_mk_iii','Ambassador Mk III',lod,(62.6,10.,2.9,3.1),
        'native/CODEX-UNIT-ROSTER.md',
        ['broad angular stealth missile boat','76 mm bow gun','eight Harpoon canisters','21-round RAM and separate Phalanx','central enclosed exhaust','compact integrated radar mast','no helicopter deck'],
        houses=[(0,4,7.8,20,4.6,0,.78),(0,-12,7.2,10,2.6,0,.86),(0,6,5.4,8,2.7,4.6,.68)],
        funnels=[(0,-5,3.3,4.3,4.7,2)],masts=[(4,15,'panel',3)],guns=[(0,22,76,4.1)],vls=[],canisters=[(-6,2.1,4)],ciws=[(0,10,4.7),(0,-16,3)],ciws_styles=['ram','phalanx'],hangar=False,flight_deck=False,bow_sheer=.9)

def missileBoat__azmat_class(lod=0):
    rig,s=combatant('missileBoat__azmat_class','Azmat-class',lod,(63.,8.8,2.4,2.8),
        'https://www.karachishipyard.com.pk/page/ship-building',
        ['first-batch Chinese-derived fast missile hull','compact rounded twin 37 mm forward mount','eight C802 canisters','aft AK630 close-in gun','small stepped bridge and twin slim sensor positions','no helicopter deck'],
        houses=[(0,4,6.8,19,3.9,0,.90),(0,-11,5.7,10,2.1,0,.93),(0,6,4.6,8,2.2,3.9,.85)],
        funnels=[(0,-5,2.8,4,4,1.7)],masts=[(4,14,'bar',3.4),(-9,10,'bar',2.6)],guns=[(0,22,37,2.7)],gun_barrels=2,vls=[],canisters=[(-7,2,4)],ciws=[(0,-19,.2)],ciws_style='gatling',hangar=False,flight_deck=False,bow_sheer=.8)
    s.representative='Azmat first-batch eight-C802 fit; not later six-Harbah boats';return rig,s

def missileBoat__sa_ar_4_5(lod=0):
    rig,s=combatant('missileBoat__sa_ar_4_5',"Sa'ar 4.5",lod,(62.,7.6,2.8,2.6),
        'https://www.israel-shipyards.com/naval-003.asp',
        ['Nirit/Hetz missile-boat representative','narrow fast hull','76 mm bow gun','eight Harpoon canisters','forward Phalanx mount','compact bridge and tall search mast','no helicopter hangar'],
        houses=[(0,4,5.8,17,3.6,0,.95),(0,-11,4.7,9,1.8,0,.95),(0,6,4,7,1.9,3.6,.92)],
        funnels=[(0,-4,2.4,4,3.7,1.6)],masts=[(4,15,'bar',3.5)],guns=[(0,22,76,4.0)],vls=[],canisters=[(-6,1.8,4)],ciws=[(0,12,1.2)],hangar=False,flight_deck=False,bow_sheer=.8)
    s.representative='Approximate Nirit/Hetz exterior, no Aliya aviation deck';return rig,s

def missileBoat__type_022(lod=0):
    return combatant('missileBoat__type_022','Type 022',lod,(42.6,12.2,1.4,2.6),
        'native/CODEX-UNIT-ROSTER.md',
        ['wave-piercing catamaran with open bow tunnel','wide cross deck','small sharply faceted bridge','30 mm six-barrel bow gun','eight aft YJ83 canisters','single short integrated mast','no helicopter facilities'],
        houses=[(0,3,6.8,14,3.4,0,.72),(0,-8,7.5,9,1.7,0,.86),(0,4,4.4,7,2.3,3.4,.65)],
        funnels=[(-2,-4,1.5,3,2.5,1),(2,-4,1.5,3,2.5,1)],masts=[(3,11,'bar',2.3)],guns=[(0,14,30,1.9)],gun_barrels=6,
        vls=[],canisters=[(-8,1.8,4)],ciws=[],hangar=False,flight_deck=False,catamaran=True,demi_beam=2.4,bow_sheer=.55)

def gunboat__gunboat(lod=0):
    rig,s=combatant('gunboat__gunboat','Gunboat',lod,(30.,6.5,1.5,1.8),
        'native/CODEX-UNIT-ROSTER.md',['original generic coastal gunboat','small pilothouse','forward 30 mm gun','aft light gun','single exhaust and search mast','no missiles or helicopter facilities'],
        houses=[(0,2,4.8,11,2.6,0,.92),(0,-7,3.6,5,1.0,0,.92)],funnels=[(0,-3,1.6,2.4,2.3,1)],masts=[(1,8,'bar',2.2)],guns=[(0,10,30,1.8),(0,-10,12.7,1.1,0,True)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.5)
    s.representative='Original plausible generic 30 m coastal gunboat';return rig,s

def gunboat__island_class_patrol_boat(lod=0):
    return combatant('gunboat__island_class_patrol_boat','Island-class patrol boat',lod,(33.53,6.4,2.0,1.7),
        'https://www.uscg.mil/Portals/0/documents/CG_Cutters-Boats-Aircraft_2015-2016_edition.pdf',
        ['110-foot transferred USCG patrol cutter','narrow round-bilge hull','forward 25 mm gun','long low accommodation block','raised pilothouse and short mast','open stern boat-handling deck'],
        houses=[(0,2,4.8,14,2.6,0,.98),(0,3,3.9,6,1.9,2.6,.96)],funnels=[(0,-4,1.5,2.6,2.7,1.5)],masts=[(2,9,'bar',2.4)],guns=[(0,11,25,1.7)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.6)

def gunboat__patrol_boat(lod=0):
    rig,s=combatant('gunboat__patrol_boat','Patrol boat',lod,(35.,7.2,1.8,1.9),
        'native/CODEX-UNIT-ROSTER.md',['Iraqi Swiftships-like patrol representative','forward 30 mm mount','long low deckhouse and raised bridge','single radar mast','aft boat-handling deck'],
        houses=[(0,2,5.3,14,2.7,0,.93),(0,4,4.1,6,1.8,2.7,.90)],funnels=[(0,-4,1.8,2.9,2.5,1.7)],masts=[(2,9,'panel',2.1)],guns=[(0,12,30,1.8)],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.5)
    s.representative='Approximate Iraqi 35 m Swiftships-type exterior for generic roster row';return rig,s

def landingShip__albion_class(lod=0):
    return combatant('landingShip__albion_class','Albion-class',lod,(176.,28.9,7.1,5.7),
        'https://www.royalnavy.mod.uk/news/2021/november/10/211110-hms-albion-works-with-french-navy-ship-garonne',
        ['large high-freeboard landing-platform dock','broad forward accommodation block','two separated radar masts','large stern helicopter deck without a full hangar','stern well-deck ramp','two Phalanx mounts'],
        houses=[(0,25,23,61,11,0,.94),(0,28,17,24,6,11,.92),(0,-15,18,20,5,0,.94)],
        funnels=[(-8,-1,5,8,8,4),(8,-1,5,8,8,4)],masts=[(25,31,'panel',5),(-12,23,'bar',4)],guns=[],vls=[],canisters=[],ciws=[(-10,12,10),(10,-20,5)],hangar=False,landing=True,ramp_height=7,cranes=[(10,1,12,-16)])

def landingShip__bahia(lod=0):
    return combatant('landingShip__bahia','Bahia',lod,(168.,23.5,5.91,5.2),
        'https://redebim.marinha.mil.br/vinculos/00001c/00001c9b.pdf',
        ['ex-Siroco Foudre-class landing dock','large forward accommodation block','two slender masts','central boat and cargo working area','wide open stern helicopter deck','heavy cargo crane','stern well-deck closure'],
        houses=[(0,25,18,51,10,0,.96),(0,28,13,21,5,10,.95),(0,-13,14,18,3.5,0,.96)],
        funnels=[(-6,0,4,6,7,4),(6,0,4,6,7,4)],masts=[(25,28,'bar',4.6),(-10,20,'bar',3.8)],guns=[],vls=[],canisters=[],ciws=[],hangar=False,landing=True,cranes=[(7,-5,14,-20)],ramp_height=6)

def landingShip__bayraktar_class(lod=0):
    return combatant('landingShip__bayraktar_class','Bayraktar-class',lod,(138.75,19.6,2.0,5.8),
        'https://www.anadolushipyard.com/en/catalogue/delivered-projects/landing-ship-tank-lst',['broad bow-ramp landing ship','flat tank deck ahead of aft superstructure','high aft bridge block','two exhausts','stern helicopter platform','twin 40 mm bow gun positions'],
        houses=[(0,-22,15,38,9,0,.94),(0,-19,10,18,5,9,.90)],funnels=[(-5,-30,3.5,5.5,7,5),(5,-30,3.5,5.5,7,5)],masts=[(-20,27,'panel',4.5)],guns=[(-6,44,40,2.8),(6,44,40,2.8)],
        vls=[],canisters=[],ciws=[],hangar=False,landing=True,bow_ramp=True,ramp_height=6,
        hull_profile=[(-.5,.72),(-.40,.93),(-.2,1),(.2,1),(.40,.85),(.50,.55)],bow_sheer=.4,cranes=[(-7,3,8,12),(7,3,8,12)])

def landingShip__canberra_class(lod=0):
    return combatant('landingShip__canberra_class','Canberra-class',lod,(230.8,32.,7.18,14.32),
        'https://www.navy.gov.au/capabilities/ships-boats-and-submarines/hmas-canberra-iii',
        ['Juan Carlos I-derived LHD','long full-width aviation deck','port-side bow ski jump','long starboard island with two funnels','two aircraft elevators','stern well-deck ramp'],
        houses=[(10,4,9,79,9,0,.93),(10,23,7.8,24,4,9,.91)],funnels=[(10,8,5,8,6,8),(10,-20,5,7,6,8)],
        masts=[(20,28,'panel',4),(-15,25,'bar',3.5)],mast_offsets=[10,10],guns=[],vls=[],canisters=[],ciws=[],hangar=False,landing=True,ramp_height=7,
        aviation_deck=True,deck_beam=32,aviation_y=.1,ski_jump=True,bow_sheer=0,elevators=[(0,-65),(10,62)])

def landingShip__dokdo_class(lod=0):
    return combatant('landingShip__dokdo_class','Dokdo-class',lod,(199.4,31.,6.6,12.4),
        'https://www.mnd.go.kr/user/mndEN/upload/pblictn/PBLICTNEBOOK_202307280406255500.pdf',
        ['flat through-deck helicopter assault ship','large starboard island','SMART-L planar radar','two Goalkeeper mounts and one RAM launcher','two aircraft elevators','stern well-deck closure'],
        houses=[(10,5,9,68,10,0,.93),(10,20,7.5,21,4,10,.92)],funnels=[(10,-8,5.5,8,7,8)],masts=[(18,29,'panel',7.2),(-15,24,'bar',3.7)],mast_offsets=[10,10],
        guns=[],vls=[],canisters=[],ciws=[(-12,65,.3),(12,-65,.3),(12,60,.3)],ciws_styles=['goalkeeper','goalkeeper','ram'],hangar=False,landing=True,
        aviation_deck=True,aviation_y=.1,bow_sheer=0,elevators=[(0,46),(0,-55)],ramp_height=7)

def landingShip__hengam_class(lod=0):
    return combatant('landingShip__hengam_class','Hengam-class',lod,(93.,14.7,2.5,3.5),
        'native/CODEX-UNIT-ROSTER.md',['conventional bow-ramp tank landing ship','wide flat loading deck','aft bridge and accommodation','single central funnel','40 mm gun positions','small stern helicopter working deck'],
        houses=[(0,-17,11.4,26,6,0,.96),(0,-15,8,12,3,6,.94)],funnels=[(0,-23,3.8,5.2,5,4)],masts=[(-15,18,'bar',3.9)],guns=[(-4,28,40,2.6),(4,28,40,2.6)],
        vls=[],canisters=[],ciws=[],hangar=False,landing=True,bow_ramp=True,ramp_height=5,bow_sheer=.4,hull_profile=[(-.5,.70),(-.4,.93),(-.2,1),(.2,1),(.4,.86),(.5,.55)],cranes=[(5,0,6,10)])

def landingShip__ins_jalashwa(lod=0):
    rig,s=combatant('landingShip__ins_jalashwa','INS Jalashwa',lod,(173.7,25.2,7.,5.5),
        'native/CODEX-UNIT-ROSTER.md',['ex-Trenton Austin-class landing dock','large forward bridge block','central working well and heavy cargo crane','open stern helicopter deck','two exhaust structures','stern well-deck ramp'],
        houses=[(0,25,19,56,10.5,0,.96),(0,28,13.5,21,5.2,10.5,.95),(0,-15,15.5,18,4,0,.96)],
        funnels=[(-7,0,4.3,6,7.6,4),(7,0,4.3,6,7.6,4)],masts=[(25,29,'bar',4.6),(-12,22,'bar',3.8)],guns=[],vls=[],canisters=[],ciws=[(-9,12,10),(9,-20,4.4)],ciws_style='gatling',hangar=False,landing=True,ramp_height=7,cranes=[(8,-3,15,-20)])
    s.representative='Approximate Indian Jalashwa post-transfer exterior';return rig,s

def landingShip__ivan_gren_class(lod=0):
    return combatant('landingShip__ivan_gren_class','Ivan Gren-class',lod,(120.,16.5,3.6,4.6),
        'native/CODEX-UNIT-ROSTER.md',['Project 11711 landing ship','bow ramp and doors','separated forward bridge and aft helicopter hangar','central cargo crane','forward Duet-type gun mount and aft gun positions','stern helicopter deck'],
        houses=[(0,18,12.2,31,7.5,0,.91),(0,-27,11.5,21,5.3,0,.94),(0,20,8.5,13,3.7,7.5,.88)],
        funnels=[(0,-4,4.3,6.5,6.5,3)],masts=[(18,23,'panel',4.2)],guns=[],vls=[],canisters=[],ciws=[(0,36,.3),(-5,-25,5.7),(5,-25,5.7)],ciws_styles=['gokdeniz','gatling','gatling'],
        landing=True,bow_ramp=True,ramp_height=6,bow_sheer=.5,hull_profile=[(-.5,.68),(-.4,.93),(-.2,1),(.2,1),(.4,.83),(.5,.52)],hangar_z=-37.6,cranes=[(5,-3,9,12)])

def landingShip__makassar_class(lod=0):
    rig,s=combatant('landingShip__makassar_class','Makassar-class',lod,(122.,22.,4.9,5.6),
        'native/CODEX-UNIT-ROSTER.md',['Indonesian Makassar landing-platform dock','high forward accommodation block','single central funnel','two helicopter operating spots','wide stern working deck','stern well-deck ramp'],
        houses=[(0,22,17,42,9.5,0,.94),(0,24,12,18,4.8,9.5,.92),(0,-15,13,17,4.5,0,.94)],funnels=[(0,0,5,8,7,4)],masts=[(22,27,'bar',4.4)],
        guns=[(0,43,40,2.8)],vls=[],canisters=[],ciws=[],landing=True,ramp_height=6,hangar_z=-23.6,cranes=[(8,-1,9,-14)])
    s.representative='Approximate 122 m lead-ship Makassar exterior; follow-on hulls vary';return rig,s

def landingShip__mistral_class(lod=0):
    return combatant('landingShip__mistral_class','Mistral-class',lod,(199.,32.,6.2,14.3),
        "https://www.defense.gouv.fr/sites/default/files/operations/Dossier%20de%20presse%20JEANNE%20D%27ARC.pdf",
        ['flat full-length helicopter deck','long starboard island','two separated exhausts','large stern and lateral aircraft elevators','stern well-deck closure','six helicopter operating positions'],
        houses=[(10,8,9.5,76,10,0,.94),(10,25,8,22,4,10,.94)],funnels=[(10,9,5.3,8,6.5,8),(10,-15,5.3,7.5,6.5,8)],
        masts=[(22,28,'panel',4),(-13,24,'bar',3.5)],mast_offsets=[10,10],guns=[],vls=[],canisters=[],ciws=[],hangar=False,landing=True,ramp_height=7,
        aviation_deck=True,aviation_y=.1,bow_sheer=0,elevators=[(0,-76),(12,47)])

def landingShip__osumi_class(lod=0):
    return combatant('landingShip__osumi_class','Osumi-class',lod,(178.,25.8,6.,9.8),
        'https://www.pa.skr.mlit.go.jp/general/image/policy/jisintunami/part10/06_shiryo3.pdf',
        ['flat vehicle and helicopter deck','compact starboard island','fore and aft Phalanx positions','stern LCAC well-deck closure','two exhausts','no ski jump or catapult'],
        houses=[(8,7,8,52,8.5,0,.94),(8,20,6.5,18,3.5,8.5,.93)],funnels=[(8,4,4.3,6,6,7),(8,-14,4.3,6,6,7)],masts=[(16,25,'panel',4.6),(-12,21,'bar',3.3)],mast_offsets=[8,8],
        guns=[],vls=[],canisters=[],ciws=[(-10,65,.2),(10,-62,.2)],hangar=False,landing=True,ramp_height=6,aviation_deck=True,aviation_y=.1,bow_sheer=0)

def landingShip__rotterdam_class(lod=0):
    return combatant('landingShip__rotterdam_class','Rotterdam-class',lod,(166.,27.,5.9,6.1),
        'https://www.defensie.nl/onderwerpen/m/materieel/schepen/amfibische-transportschepen',
        ['large forward accommodation and command block','single broad exhaust block','two Goalkeeper mounts','large helicopter hangar and open aft flight deck','heavy side crane','stern well-deck ramp'],
        houses=[(0,25,21.5,53,10,0,.94),(0,28,15,23,5.5,10,.92),(0,-18,20,23,5.5,0,.94)],funnels=[(0,-2,7,9,8,4)],masts=[(25,30,'panel',5.8),(-14,23,'bar',4)],
        guns=[],vls=[],canisters=[],ciws=[(0,48,5),(0,-24,6)],ciws_style='goalkeeper',landing=True,ramp_height=7,hangar_z=-29.6,hangar_doors=2,cranes=[(10,0,12,-18)])

def landingShip__san_antonio_class(lod=0):
    return combatant('landingShip__san_antonio_class','San Antonio-class',lod,(208.48,32.,7.,7.5),
        'https://www.navy.mil/DesktopModules/ArticleCS/Print.aspx?Article=2222713&ModuleId=724&PortalId=1',
        ['LPD-17 Flight I high-freeboard hull','two tall enclosed advanced sensor masts','large forward bridge','30 mm fore and aft gun mounts','two RAM launchers','large aft flight deck and hangar','stern LCAC closure'],
        houses=[(0,30,25,66,11,0,.88),(0,34,18,26,5,11,.88),(0,-36,24,28,6.6,0,.92)],funnels=[(-8,-4,5.5,8,9,5),(8,-4,5.5,8,9,5)],
        masts=[(28,35,'enclosed',7),(-18,31,'enclosed',6.5)],guns=[(0,72,30,1.8),(0,-48,30,1.8,6.8,True)],vls=[],canisters=[],ciws=[(-12,36,9),(12,-42,7)],ciws_style='ram',landing=True,ramp_height=8,hangar_z=-50.1,hangar_doors=2)

def landingShip__san_giorgio_class(lod=0):
    return combatant('landingShip__san_giorgio_class','San Giorgio-class',lod,(133.3,20.5,5.25,7.25),
        'https://digitallibrary.un.org/record/3976750/files/S_2022_427-AR.pdf',
        ['compact Italian through-deck landing ship','short starboard island','single funnel','bow and stern ramp access','open aft helicopter deck','flat aviation deck without ski jump'],
        houses=[(6,7,6.5,39,7,0,.94),(6,17,5.3,13,3,7,.92)],funnels=[(6,-3,3.8,5.5,5.4,6)],masts=[(12,22,'bar',3.7)],mast_offsets=[6],guns=[],vls=[],canisters=[],ciws=[],hangar=False,landing=True,ramp_height=5.5,
        aviation_deck=True,aviation_y=.1,bow_sheer=0,elevators=[(0,30)])

def landingShip__type_071(lod=0):
    return combatant('landingShip__type_071','Type 071',lod,(210.,28.,7.,6.),
        'native/CODEX-UNIT-ROSTER.md',['Yuzhao landing-platform dock','large forward bridge and accommodation','76 mm bow gun','four close-in gun positions','two exhausts and separate search radars','large aft hangar and helicopter deck','stern LCAC ramp'],
        houses=[(0,31,22,61,10,0,.89),(0,34,15.5,24,5.5,10,.88),(0,-38,21.5,30,6.3,0,.93)],funnels=[(0,-4,7,10,9,4),(0,-24,6,8,8,4)],
        masts=[(28,32,'panel',6.2),(-24,25,'bar',4.4)],guns=[(0,77,76,4.5)],vls=[],canisters=[],ciws=[(-10,20,9),(10,20,9),(-10,-39,6.7),(10,-39,6.7)],ciws_style='gatling',landing=True,ramp_height=7,hangar_z=-53.1,hangar_doors=2)

CATOBAR_OUTLINE=[(-.34,-.48),(.36,-.48),(.47,-.30),(.40,.35),(.22,.49),(-.20,.49),(-.44,.20),(-.50,-.16)]

def carrier(slug,name,lod,dimensions,source,features,**details):
    d={'aviation_deck':True,'aviation_y':.1,'bow_sheer':0,'hangar':False,'landing':False,'guns':[],'vls':[],'canisters':[],'ciws':[],**details}
    return combatant(slug,name,lod,dimensions,source,features,**d)

def carrier__cavour(lod=0):
    return carrier('carrier__cavour','Cavour',lod,(244.,39.,8.7,13.3),
        'https://www.marina.difesa.it/cosa-facciamo/per-la-difesa-sicurezza/operazioni-in-corso/Documents/Sistema%20Paese%20in%20movimento/Schede%20Navi%20e%20depliant/CAVOUR_ITA_14_11.pdf',
        ['Italian STOVL carrier','long narrow flight deck','port-side ski jump','long starboard island and twin exhausts','two aircraft elevators','two 76 mm defence gun positions','no catapults'],
        hull_beam=29.1,deck_beam=34.,houses=[(11,7,9.5,83,10,0,.92),(11,29,8,22,4.5,10,.91)],funnels=[(11,10,5,8,7,8),(11,-17,5,7,7,8)],
        masts=[(24,29,'sphere',4),(-12,25,'bar',3.5)],mast_offsets=[11,11],guns=[(-17,78,76,4.2),(17,-80,76,4.2,0,True)],sponsons=[(-17,78,5,10),(17,-80,5,10)],ski_jump=True,elevators=[(12,60),(10,-62)])

def carrier__charles_de_gaulle(lod=0):
    return carrier('carrier__charles_de_gaulle','Charles de Gaulle',lod,(261.5,64.36,9.4,13.6),
        'https://www.colsbleus.defense.gouv.fr/fr/le-charles-fete-ses-25-ans',
        ['French nuclear carrier','angled landing deck','two steam catapults','large forward starboard island','two starboard aircraft elevators','three arrestor wires','no propulsion smokestack'],
        hull_beam=31.5,deck_beam=64.36,deck_outline=CATOBAR_OUTLINE,angled_deck=-8.5,
        houses=[(20,30,12,58,12,0,.92),(20,39,10,24,5,12,.89)],funnels=[],masts=[(36,33,'panel',5.5),(13,29,'sphere',3.6)],mast_offsets=[20,20],
        catapults=[(5,78,75,0),(-18,2,75,-8.5)],elevators=[(25,65),(26,-24)],ciws=[(-23,-75,.3),(24,78,.3)],ciws_style='ram',ciws_tubes=6)

def carrier__fujian(lod=0):
    rig,s=carrier('carrier__fujian','Fujian',lod,(316.,76.,10.,14.),
        'https://eng.mod.gov.cn/2025xb/D/V/16420460.html',
        ['conventional-powered Type 003 carrier','three electromagnetic catapults','angled landing deck','compact starboard island amidships','two starboard aircraft elevators','no ski jump'],
        hull_beam=39.,deck_beam=76.,deck_outline=CATOBAR_OUTLINE,angled_deck=-9,
        houses=[(24,0,13,63,13,0,.85),(24,13,10,25,5.5,13,.79)],funnels=[(24,-12,7,10,7,10)],masts=[(9,36,'bar',4),(-13,30,'panel',4)],mast_offsets=[24,24],
        catapults=[(-9,100,90,0),(11,100,90,0),(-24,2,90,-9)],elevators=[(30,60),(30,-70)],ciws=[(-20,110,.3),(24,-110,.3),(-25,-90,.3)],ciws_styles=['gatling','gatling','ram'],ciws_tubes=24)
    s.representative='Approximate public 316 m / 76 m exterior dimensions; no internal arrangement';return rig,s

def carrier__gerald_r_ford_class(lod=0):
    return carrier('carrier__gerald_r_ford_class','Gerald R. Ford-class',lod,(337.,78.,11.9,13.1),
        'https://www.airpac.navy.mil/Organization/Distinguished-Visitor-Info/Important-Links-and-Info/',
        ['large nuclear supercarrier','four EMALS catapults','angled flight deck','small aft starboard island','three aircraft elevators','no propulsion funnels','three arrestor wires'],
        hull_beam=40.8,deck_beam=78.,deck_outline=CATOBAR_OUTLINE,angled_deck=-9,
        houses=[(25,-45,13,48,15,0,.86),(25,-36,10,24,6,15,.82)],funnels=[],masts=[(-36,38,'panel',6),(-53,33,'bar',4)],mast_offsets=[25,25],
        catapults=[(-8,105,94,0),(12,105,94,0),(-21,10,94,-9),(-30,-15,94,-9)],elevators=[(31,65),(31,0),(-31,-85)],
        ciws=[(-22,115,.3),(27,-120,.3),(-28,-100,.3),(25,105,.3)],ciws_styles=['phalanx','phalanx','ram','ram'])

def carrier__ins_vikrant(lod=0):
    return carrier('carrier__ins_vikrant','INS Vikrant',lod,(262.,62.,8.4,13.1),
        'https://www.pib.gov.in/FeaturesDeatils.aspx?ModuleId+=+2%2F1000&NoteId=151135',
        ['Indian STOBAR carrier','broad angled landing area','port bow ski jump','long starboard island with twin funnels','two aircraft elevators','arrestor wires and no catapults'],
        hull_beam=32.,deck_beam=62.,deck_outline=CATOBAR_OUTLINE,angled_deck=-8.5,ski_jump=True,
        houses=[(19,10,12,82,12,0,.88),(19,30,9.5,24,5,12,.85)],funnels=[(19,10,6.5,9,7.5,9),(19,-16,6.5,8,7.5,9)],masts=[(27,33,'panel',4.5),(-10,29,'bar',3.6)],mast_offsets=[19,19],
        elevators=[(24,58),(24,-58)],ciws=[(-20,85,.3),(22,-85,.3)],ciws_style='gatling')

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
