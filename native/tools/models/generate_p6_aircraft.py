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

def airframe(slug,name,lod,family,dimensions,wing,fins,source,seats=1,engines=1,features=(),representative='',stealth=False,**details):
    L,S,H,W,B,b=dimensions;y=b+B*.52
    d={'wing':[(x,y,le,te) for x,le,te in wing],
       'fins':fins,'side_intakes':True,**details}
    s=AircraftSpec(slug,name,family,L,S,H,W,B,b,engines,source,seats=seats,stealth=stealth,
        representative=representative,features=list(features),details=d)
    return build(s,lod)

def jet__f_16_block_50(lod=0):return model('jet__f_16_block_50','F-16 Block 50',lod,'f16')
def jet__f_16iq_fighting_falcon(lod=0):return model('jet__f_16iq_fighting_falcon','F-16IQ Fighting Falcon',lod,'f16')

def f35(slug,name,lod):
    return airframe(slug,name,lod,'f35',(15.7,10.7,4.38,2.1,1.9,.90),
        [(.70,1.3,-3.5),(3,-.5,-3.7),(5.35,-2.75,-3.65)],
        [(-.75,2.35,4.52,-3.15,-6.85,-4.9,-6.1),(.75,2.35,4.52,-3.15,-6.85,-4.9,-6.1)],
        'https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/F-35/Fast_Facts_May_2020.pdf',
        stealth=True,features=['blended fuselage chines','trapezoidal wings','outward-canted twin fins','single large nozzle','internal weapon bays with hinged doors','no external pylons'],
        fin_cant=20,intake_x=1.02,intake_width=.72,intake_height=.83,intake_z=.21,engine_radius=.63,cross_power=.72,
        stabilator=[(.70,1.8,-3.8,-6.9),(3.43,1.8,-5.8,-7.0)],
        profile=[(-.455,0,.30,.36),(-.38,0,.43,.48),(-.22,0,.50,.50),(0,0,.50,.5),(.21,.10,.30,.40),(.32,.10,.22,.33),(.44,.04,.13,.18),(.50,0,.012,.02)])
def jet__f_35a(lod=0):return f35('jet__f_35a','F-35A',lod)

def jet__f_7ni(lod=0):
    return airframe('jet__f_7ni','F-7NI',lod,'f7',(14.89,7.15,4.1,1.25,1.28,1.05),
        [(.40,.2,-3.35),(2.3,-1.8,-3.3),(3.575,-2.9,-3.25)],[(0,2.1,4.1,-2.9,-6.6,-4.8,-5.9)],
        'https://odin.t2com.army.mil/WEG/Asset/F-7',features=['slender circular fuselage','annular nose intake with central shock cone','cranked delta wing','single fin','rear stabilators'],
        nose_intake=True,nose_radius=.46,side_intakes=False,engine_radius=.43,
        stabilator=[(.45,1.9,-3.6,-6.3),(2.02,1.9,-5.0,-6.0)],
        profile=[(-.455,0,.34,.34),(-.35,0,.50,.5),(-.1,0,.5,.5),(.15,0,.48,.48),(.34,0,.40,.42),(.484,0,.368,.359375)])

def hornet(slug,name,lod,ew=False):
    return airframe(slug,name,lod,'hornet',(18.31,13.62,4.88,2.2,1.75,1.12),
        [(.9,1.55,-3.7),(3.5,-.55,-3.5),(6.81,-2.2,-3.35)],
        [(-1.0,2.3,5.05,-3.4,-7.6,-5.9,-6.95),(1.0,2.3,5.05,-3.4,-7.6,-5.9,-6.95)],
        'https://www.airforce.gov.au/aircraft/18f-super-hornet',seats=2,engines=2,
        features=['large leading-edge extensions','rectangular side intakes','outward-canted twin fins','tandem canopy','broad swept wings','twin engine nozzles'],
        fin_cant=20,intake_x=1.11,intake_width=.86,intake_height=.90,intake_z=.16,engine_spacing=1.35,engine_radius=.49,
        stabilator=[(.8,1.95,-4.6,-8.0),(4.2,1.95,-6.8,-7.8)],lex=True,gun=not ew,
        profile=[(-.455,0,.3,.35),(-.35,0,.5,.5),(-.15,0,.5,.5),(0,0,.46,.5),(.16,.06,.27,.42),(.31,.07,.23,.3),(.44,.02,.13,.15),(.50,0,.012,.02)])
def jet__f_a_18f_super_hornet(lod=0):return hornet('jet__f_a_18f_super_hornet','F/A-18F Super Hornet',lod)

def jet__gripen_e(lod=0):
    return airframe('jet__gripen_e','Gripen E',lod,'gripen',(15.2,8.6,4.5,1.55,1.55,1.03),
        [(.45,1.4,-4.5),(2.5,-.9,-4.15),(4.3,-2.9,-3.9)],[(0,2.25,4.5,-3.7,-6.6,-5.3,-6.15)],
        'https://www.saab.com/contentassets/e8ba68d67f3d4974bedb48ea1d786237/saab_canada_interactive_brochure_2021_01_29.pdf',
        features=['close-coupled canards','delta wing','lateral intakes','single engine','single fin','wingtip electronic-warfare fairings'],
        intake_x=.83,intake_width=.57,intake_height=.67,intake_z=.19,engine_radius=.48,
        canard=[(.55,2.05,3.6,2.3),(2.0,2.05,2.7,2.2)],wingtip_pods=True,
        profile=[(-.455,0,.31,.35),(-.36,0,.5,.5),(-.12,0,.5,.5),(0,0,.45,.46),(.19,.04,.28,.4),(.34,.05,.22,.31),(.44,0,.11,.17),(.5,0,.012,.02)])

def j10(slug,name,lod,representative=''):
    return airframe(slug,name,lod,'j10',(16.43,9.75,5.43,1.65,1.65,1.18),
        [(.55,1.2,-4.6),(2.6,-1.2,-4.2),(4.875,-3.3,-3.95)],[(0,2.55,5.43,-3.7,-7.2,-5.6,-6.5)],
        'https://odin.t2com.army.mil/WEG/Asset/J-10',representative=representative,
        features=['delta wing and close-coupled canards','single swept tail','underslung chin intake','single large jet nozzle'],
        side_intakes=False,engine_radius=.55,canard=[(.65,2.5,4.2,2.4),(2.25,2.5,3.0,2.35)])
def jet__j_10c_jf_17_f_16(lod=0):return j10('jet__j_10c_jf_17_f_16','J-10C / JF-17 / F-16',lod,'J-10C exterior')

def flanker(slug,name,lod,seats=1,canards=False,representative=''):
    return airframe(slug,name,lod,'flanker',(21.94,14.70,6.36,3.1,2.0,1.28),
        [(.9,2.3,-5.0),(4.0,-.3,-5.0),(7.35,-3.65,-4.9)],
        [(-1.8,2.85,6.36,-4.3,-9.0,-7.1,-8.65),(1.8,2.85,6.36,-4.3,-9.0,-7.1,-8.65)],
        'https://www.uacrussia.ru/en/aircraft/lineup/military/su-35/',seats=seats,engines=2,representative=representative,
        features=['widely separated engine nacelles','long blended leading-edge extensions','parallel twin fins','broad swept wings','central rear sting','tandem canopy' if seats==2 else 'single-seat canopy']+(['foreplane canards'] if canards else []),
        engine_spacing=2.7,engine_radius=.65,engine_aft_fraction=.43,intake_x=1.43,intake_z=.10,intake_width=1.11,intake_height=1.03,lex=True,tail_sting=True,
        stabilator=[(1.1,2.35,-5.7,-9.8),(5.0,2.35,-8.1,-9.65)],
        **({'canard':[(1.2,2.95,3.2,1.8),(2.9,2.95,2.05,1.6)]} if canards else {}),
        profile=[(-.50,-.05,.055,.07),(-.40,0,.18,.19),(-.25,0,.50,.45),(0,0,.5,.50),(.17,.04,.32,.4),(.32,.04,.22,.3),(.43,0,.12,.17),(.5,0,.008,.015)])
def jet__j_16(lod=0):return flanker('jet__j_16','J-16',lod,2)

def jet__kf_21_boramae_f_15k(lod=0):
    return airframe('jet__kf_21_boramae_f_15k','KF-21 Boramae / F-15K',lod,'kf21',(16.9,11.2,4.7,2.15,1.7,1.10),
        [(.7,1.4,-3.9),(3,-.5,-3.8),(5.6,-2.6,-3.65)],
        [(-.8,2.45,4.86,-3.3,-7.3,-5.2,-6.6),(.8,2.45,4.86,-3.3,-7.3,-5.2,-6.6)],
        'https://www.koreaaero.com/VIRTUAL_EX/PDF/FixedWing/01_Fixed_Wing_KF-21_Boramae.pdf',engines=2,representative='KF-21 single-seat exterior',
        features=['chined forebody','two lateral intakes','twin engines','outward-canted fins','external weapon stations'],
        engine_spacing=1.25,engine_radius=.47,fin_cant=22,intake_x=1.04,intake_z=.18,intake_width=.70,intake_height=.84,cross_power=.80,
        stabilator=[(.7,2.03,-4.2,-7.1),(3.6,2.03,-6.1,-7.0)])

def mig29(slug,name,lod,representative=''):
    return airframe(slug,name,lod,'mig29',(17.32,11.36,4.73,2.5,1.8,1.08),
        [(.8,1.35,-3.9),(3.4,-.5,-3.6),(5.68,-2.45,-3.45)],
        [(-1.0,2.5,4.73,-3.6,-6.9,-5.3,-6.4),(1.0,2.5,4.73,-3.6,-6.9,-5.3,-6.4)],
        'https://aviamuseum.com.ua/en/exposition/exposition/kb-mig/213-mig-29',engines=2,representative=representative,
        features=['broad leading-edge root extensions','two underslung intake boxes','widely spaced jet nozzles','twin vertical tails','rear all-moving stabilators'],
        engine_spacing=1.7,engine_radius=.52,intake_x=.97,intake_width=.94,intake_height=.93,intake_z=.14,lex=True,
        stabilator=[(.8,2.0,-4.2,-7.7),(3.85,2.,-6.,-7.3)],gun_side=-1,
        profile=[(-.455,0,.3,.35),(-.35,0,.50,.48),(-.1,0,.5,.5),(.08,.04,.38,.47),(.22,.10,.23,.40),(.36,.06,.19,.27),(.45,0,.10,.14),(.5,0,.012,.02)])
def jet__mig_29(lod=0):return mig29('jet__mig_29','MiG-29',lod)
def jet__mig_29_mig_21(lod=0):return mig29('jet__mig_29_mig_21','MiG-29 / MiG-21',lod,'MiG-29 9-12 exterior')

def rafale(slug,name,lod,seats=1,representative=''):
    return airframe(slug,name,lod,'rafale',(15.30,10.90,5.34,1.9,1.6,1.1),
        [(.55,1.7,-4.1),(3.,-.95,-4.0),(5.45,-3.35,-3.9)],[(0,2.6,5.34,-2.8,-6.6,-4.7,-5.9)],
        'https://www.dassault-aviation.com/en/defense/rafale/specifications-and-performance-data/',seats=seats,engines=2,representative=representative,
        features=['delta wings','close-coupled canards','paired lateral intakes','twin recessed nozzles','single swept vertical tail'],
        engine_spacing=.90,engine_radius=.40,intake_x=.94,intake_width=.63,intake_height=.68,intake_z=.19,
        canard=[(.70,2.45,3.7,2.3),(2.1,2.45,2.65,2.15)])
def jet__rafale(lod=0):return rafale('jet__rafale','Rafale',lod)

def jet__rafale_f_16(lod=0):return rafale('jet__rafale_f_16','Rafale / F-16',lod,representative='Rafale C exterior')

def su25(slug,name,lod,representative=''):
    return airframe(slug,name,lod,'su25',(15.53,14.36,4.80,1.6,1.85,.86),
        [(.55,1.05,-2.25),(3.5,.05,-2.65),(7.18,-1.65,-3.1)],[(0,2.4,4.8,-3.8,-6.85,-5.3,-6.35)],
        'https://info.publicintelligence.net/MCIA-UzbekistanHandbook.pdf',engines=2,representative=representative,
        features=['high-set modestly swept wing','two shoulder-mounted engine nacelles','armoured blunt nose','single fin','wingtip airbrake fairings'],
        engine_spacing=2.1,engine_radius=.49,engine_aft_fraction=.39,intake_x=1.13,intake_z=.08,intake_width=.79,intake_height=.77,
        wingtip_pods=True,stabilator=[(.5,2.5,-4.1,-6.7),(2.9,2.5,-5.45,-6.55)],
        profile=[(-.455,.03,.23,.22),(-.32,.02,.38,.4),(-.10,0,.5,.5),(.13,0,.49,.49),(.30,-.01,.40,.35),(.43,-.10,.29,.23),(.50,-.15,.06,.08)])
def jet__su_25_mig_29se(lod=0):return su25('jet__su_25_mig_29se','Su-25 / MiG-29SE',lod,'Su-25 single-seat exterior')
def jet__su_30k_su_27(lod=0):return flanker('jet__su_30k_su_27','Su-30K / Su-27',lod,2,representative='Su-30K tandem-seat exterior')
def jet__su_30mki(lod=0):return flanker('jet__su_30mki','Su-30MKI',lod,2,True)
def jet__su_35s(lod=0):return flanker('jet__su_35s','Su-35S',lod)
def jet__typhoon_fgr4(lod=0):return model('jet__typhoon_fgr4','Typhoon FGR4',lod,'typhoon')

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
