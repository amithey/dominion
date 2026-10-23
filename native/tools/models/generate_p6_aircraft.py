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

def f35(slug,name,lod,stovl=False):
    return airframe(slug,name,lod,'f35',(15.6 if stovl else 15.7,10.7,4.36 if stovl else 4.38,2.1,1.9,.90),
        [(.70,1.3,-3.5),(3,-.5,-3.7),(5.35,-2.75,-3.65)],
        [(-.75,2.35,4.52,-3.15,-6.85,-4.9,-6.1),(.75,2.35,4.52,-3.15,-6.85,-4.9,-6.1)],
        'https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/F-35/Fast_Facts_May_2020.pdf',
        stealth=True,features=['blended fuselage chines','trapezoidal wings','outward-canted twin fins','single large nozzle','internal weapon bays with hinged doors','no external pylons'],
        fin_cant=20,intake_x=1.02,intake_width=.72,intake_height=.83,intake_z=.21,engine_radius=.63,cross_power=.72,
        lift_fan=stovl,vector_nozzle=stovl,gun=not stovl,
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
        stabilator=[(.8,1.95,-4.6,-8.0),(4.2,1.95,-6.8,-7.8)],lex=True,gun=not ew,wingtip_pods=ew,ew_pods=ew,
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

def flanker(slug,name,lod,seats=1,canards=False,representative='',ew=False):
    return airframe(slug,name,lod,'flanker',(21.94,14.70,6.36,3.1,2.0,1.28),
        [(.9,2.3,-5.0),(4.0,-.3,-5.0),(7.35,-3.65,-4.9)],
        [(-1.8,2.85,6.36,-4.3,-9.0,-7.1,-8.65),(1.8,2.85,6.36,-4.3,-9.0,-7.1,-8.65)],
        'https://www.uacrussia.ru/en/aircraft/lineup/military/su-35/',seats=seats,engines=2,representative=representative,
        features=['widely separated engine nacelles','long blended leading-edge extensions','parallel twin fins','broad swept wings','central rear sting','tandem canopy' if seats==2 else 'single-seat canopy']+(['foreplane canards'] if canards else []),
        engine_spacing=2.7,engine_radius=.65,engine_aft_fraction=.43,intake_x=1.43,intake_z=.10,intake_width=1.11,intake_height=1.03,lex=True,tail_sting=True,gun=not ew,wingtip_pods=ew,ew_pods=ew,
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

def lightFighter__eurofighter_typhoon(lod=0):return model('lightFighter__eurofighter_typhoon','Eurofighter Typhoon',lod,'typhoon')
def lightFighter__f_16(lod=0):return model('lightFighter__f_16','F-16',lod,'f16')
def lightFighter__f_16c(lod=0):return model('lightFighter__f_16c','F-16C',lod,'f16')

def f5(slug,name,lod,modern=False):
    return airframe(slug,name,lod,'f5',(14.68,8.13,4.06,1.15,1.35,1.02),
        [(.38,.9,-2.6),(2.15,-.25,-2.5),(4.065,-1.65,-2.4)],[(0,2.05,4.06,-2.5,-6.4,-4.3,-5.55)],
        'https://www.vtg.admin.ch/dam/en/sd-web/HMnPkJcj12vX/84_003_de_PatrouilleSuisse_2015_web.pdf',engines=2,
        features=['slender pointed nose','two small engine nozzles','small swept trapezoidal wing','single tail','two nose cannons']+(['modern dorsal warning-receiver fairings'] if modern else []),
        engine_spacing=.66,engine_radius=.30,intake_x=.64,intake_z=.14,intake_width=.45,intake_height=.48,
        gun_count=2,gun_fraction=.33,gun_width=.25,modern_f5=modern,
        stabilator=[(.38,1.78,-3.6,-6.2),(2.1,1.78,-5.,-6.)],
        profile=[(-.455,0,.3,.35),(-.34,0,.50,.49),(-.12,0,.5,.5),(.12,.01,.39,.44),(.28,.02,.31,.32),(.42,0,.16,.18),(.5,0,.008,.015)])
def lightFighter__f_5e(lod=0):return f5('lightFighter__f_5e','F-5E',lod)
def lightFighter__f_5m(lod=0):return f5('lightFighter__f_5m','F-5M',lod,True)

def fa50(slug,name,lod):
    return airframe(slug,name,lod,'fa50',(13.14,9.45,4.82,1.4,1.4,1.0),
        [(.5,1.1,-2.5),(2.7,-.1,-2.4),(4.725,-1.25,-2.1)],[(0,2.25,4.82,-2.3,-5.7,-3.95,-5.1)],
        'https://www.koreaaero.com/EN/Business/FA50.aspx',seats=2,
        features=['tandem trainer-derived canopy','lateral intakes','single nozzle','swept wing with leading-edge extensions','single tall fin'],
        lex=True,intake_x=.76,intake_z=.17,intake_width=.54,intake_height=.61,engine_radius=.44,
        stabilator=[(.42,1.85,-3.25,-5.7),(2.5,1.85,-4.75,-5.4)])
def lightFighter__fa_50(lod=0):return fa50('lightFighter__fa_50','FA-50',lod)

def lightFighter__j_10c(lod=0):return j10('lightFighter__j_10c','J-10C',lod)
def mirage(slug,name,lod,seats=1,older=False):
    L,S,H=(15.55,8.22,4.5) if older else (14.36,9.13,5.20)
    return airframe(slug,name,lod,'mirage5' if older else 'mirage2000',(L,S,H,1.50,1.5,1.03),
        [(.48,1.35,-4.0),(2.5,-1.4,-3.8),(S/2,-3.25,-3.65)],[(0,2.25,H,-2.4,-6.0,-4.2,-5.4)],
        'https://dassault-aviation.publispeak.com/2023-annual-report/doc/article/44/',seats=seats,
        features=['tailless delta wing','single large nozzle','two lateral intakes with shock cones','single vertical fin'],
        intake_round=True,shock_cones=True,intake_x=.82,intake_width=.85,intake_z=.20,engine_radius=.52,gun_count=2,gun_fraction=.10)
def lightFighter__mirage_2000_5f(lod=0):return mirage('lightFighter__mirage_2000_5f','Mirage 2000-5F',lod)
def lightFighter__t_50iq(lod=0):return fa50('lightFighter__t_50iq','T-50IQ',lod)
def lightFighter__tejas_mk1(lod=0):
    return airframe('lightFighter__tejas_mk1','Tejas Mk1',lod,'tejas',(13.2,8.2,4.4,1.45,1.48,1.01),
        [(.45,1.0,-3.4),(2.1,-.65,-3.25),(4.1,-2.5,-3.05)],[(0,2.2,4.4,-2.5,-5.8,-4.2,-5.2)],
        'https://www.ddpmod.gov.in/en/resources/products/lca-tejas',
        features=['compound delta wing','tailless planform without canards','lateral intakes','single nozzle','single fin'],
        intake_x=.76,intake_width=.55,intake_height=.65,intake_z=.18,engine_radius=.45)
def stealthFighter__f_35a(lod=0):return f35('stealthFighter__f_35a','F-35A',lod)
def stealthFighter__f_35a_lightning_ii(lod=0):return f35('stealthFighter__f_35a_lightning_ii','F-35A Lightning II',lod)

def stealthFighter__f_35b_lightning(lod=0):return f35('stealthFighter__f_35b_lightning','F-35B Lightning',lod,True)
def stealthFighter__f_35i_adir(lod=0):return f35('stealthFighter__f_35i_adir','F-35I Adir',lod)
def stealthFighter__j_20(lod=0):
    return airframe('stealthFighter__j_20','J-20',lod,'j20',(20.4,13.5,4.45,2.6,1.8,1.15),
        [(.8,2.5,-5.4),(3.9,-.4,-5.2),(6.75,-3.5,-5.0)],
        [(-1.05,2.55,4.66,-4.4,-8.6,-6.5,-7.9),(1.05,2.55,4.66,-4.4,-8.6,-6.5,-7.9)],
        'https://odin.t2com.army.mil/WEG/Asset/J-20',engines=2,stealth=True,
        features=['long chined forebody','canard-delta layout','canted twin fins','twin nozzles','internal weapon bays without pylons'],
        fin_cant=25,engine_spacing=1.65,engine_radius=.60,intake_x=1.34,intake_width=.80,intake_height=.90,intake_z=.18,cross_power=.75,
        canard=[(.85,2.65,4.6,2.7),(3.3,2.65,3.1,2.4)])
def stealthFighter__su_57(lod=0):
    return airframe('stealthFighter__su_57','Su-57',lod,'su57',(20.1,14.1,4.74,3.6,1.35,1.35),
        [(1.1,2.2,-4.6),(4.5,-.7,-4.5),(7.05,-3.45,-4.3)],
        [(-1.75,2.5,4.97,-4.0,-8.2,-6.4,-7.6),(1.75,2.5,4.97,-4.,-8.2,-6.4,-7.6)],
        'https://www.uacrussia.ru/en/aircraft/lineup/military/su-57/',engines=2,stealth=True,
        features=['broad flattened blended fuselage','widely separated nozzles','low outward-canted twin fins','swept trapezoidal wings','internal longitudinal weapon bays'],
        engine_spacing=2.75,engine_radius=.58,intake_x=1.40,intake_width=1.0,intake_height=.75,intake_z=.12,fin_cant=25,cross_power=.70,
        stabilator=[(1.0,2.15,-5.3,-9.0),(4.8,2.15,-7.4,-8.8)],lex=True)
def attackJet__a_10c_thunderbolt_ii(lod=0):
    return airframe('attackJet__a_10c_thunderbolt_ii','A-10C Thunderbolt II',lod,'a10',(16.16,17.42,4.42,1.9,1.95,1.05),
        [(.65,.7,-1.9),(5.2,.3,-2.0),(8.71,-.2,-1.9)],
        [(-2.4,2.1,4.42,-5.4,-7.7,-6.0,-7.3),(2.4,2.1,4.42,-5.4,-7.7,-6.0,-7.3)],
        'https://www.af.mil/Portals/1/documents/aboutus/FactSheets/A10_Thunderbolt_II.pdf',engines=2,
        features=['straight high-aspect-ratio wings','twin high aft turbofan nacelles','twin tail fins','low blunt armoured nose','forward GAU-8 cannon'],
        turbofans=[(-1.5,3.25,-3.7),(1.5,3.25,-3.7)],fan_radius=.73,fan_length=3.2,
        stabilator=[(.55,2.1,-5.45,-7.6),(3.35,2.1,-5.7,-7.5)],gun_fraction=.472,gun_width=.10,gun_y=1.42,gatling=True,
        profile=[(-.50,0,.05,.08),(-.35,0,.30,.34),(-.1,0,.5,.5),(.12,0,.5,.5),(.3,-.04,.42,.38),(.45,-.12,.27,.22),(.50,-.15,.10,.10)])
def attackJet__jaguar(lod=0):
    return airframe('attackJet__jaguar','Jaguar',lod,'jaguar',(16.83,8.68,4.89,1.3,1.6,1.15),
        [(.45,.55,-2.4),(2.4,-.95,-2.5),(4.34,-2.1,-2.6)],[(0,2.4,4.89,-3.4,-7.0,-5.2,-6.4)],
        'https://www.rafmuseum.org.uk/documents/LargePrintGuides/The%20RAF%20in%20an%20Age%20of%20Uncertainty.pdf',engines=2,
        features=['narrow swept high wing','paired lateral intakes','slender twin-engine fuselage','single fin','rear stabilators'],
        engine_spacing=.82,engine_radius=.35,intake_x=.77,intake_width=.57,intake_height=.62,intake_z=.14,
        stabilator=[(.4,2.3,-4.6,-7.5),(2.65,2.3,-6.3,-7.25)],gun_count=2,gun_fraction=.25)

def attackJet__l_159_alca(lod=0):
    return airframe('attackJet__l_159_alca','L-159 ALCA',lod,'l159',(12.72,9.54,4.87,1.3,1.45,.97),
        [(.4,.6,-2.2),(2.6,-.15,-2.15),(4.77,-1.25,-2.0)],[(0,2.3,4.87,-2.2,-5.3,-3.65,-4.9)],
        'https://www.aero.cz/en/aircraft/l-159/',
        features=['compact subsonic trainer-derived airframe','lateral intakes','single nozzle','swept wing','ventral cannon pod'],
        intake_x=.72,intake_width=.50,intake_height=.52,intake_z=.13,engine_radius=.36,
        gun_y=.84,gun_fraction=.04,gun_width=.05,canopy_rear=.10,
        stabilator=[(.4,2.2,-3.2,-5.5),(2.4,2.2,-4.7,-5.2)])
def attackJet__mirage_2000d(lod=0):return mirage('attackJet__mirage_2000d','Mirage 2000D',lod,2)
def attackJet__mirage_5(lod=0):return mirage('attackJet__mirage_5','Mirage 5',lod,older=True)
def attackJet__su_24mk(lod=0):
    return airframe('attackJet__su_24mk','Su-24MK',lod,'su24',(24.53,17.64,6.19,2.6,2.1,1.30),
        [(1.1,1.1,-4.9),(4.8,-1.1,-5.2),(8.82,-3.5,-5.4)],[(0,3.0,6.19,-5.7,-10.8,-8.5,-10.0)],
        'https://www.uacrussia.ru/en/aircraft/lineup/military/su-24/',seats=2,engines=2,
        features=['side-by-side cockpit','variable-sweep wings','two side intake boxes','twin nozzles','single large swept fin','long pointed attack nose'],
        swing_wing=True,side_by_side=True,canopy_front=.34,canopy_rear=.20,engine_spacing=1.42,engine_radius=.59,
        intake_x=1.4,intake_z=.12,intake_width=1.1,intake_height=1.1,
        stabilator=[(.9,2.6,-6.5,-10.5),(4.9,2.6,-8.6,-10.3)],
        profile=[(-.455,0,.30,.35),(-.33,0,.5,.5),(-.05,0,.5,.5),(.16,.04,.44,.46),(.30,.04,.32,.34),(.43,0,.15,.18),(.50,0,.008,.015)])
def attackJet__su_25(lod=0):return su25('attackJet__su_25','Su-25',lod)
def tornado(slug,name,lod,ew=False):
    return airframe(slug,name,lod,'tornado',(16.72,13.91,5.95,2.05,1.8,1.23),
        [(.9,1.2,-3.6),(3.7,-.5,-3.8),(6.955,-2.5,-3.9)],[(0,2.7,5.95,-2.3,-6.7,-4.5,-6.2)],
        'https://www.bundeswehr.de/en/equipment/air/aircraft/tornado',seats=2,engines=2,
        features=['variable-sweep wings','tandem canopy','rectangular side intakes','two close-set nozzles','large tall swept fin','electronic-combat configuration' if ew else 'strike configuration'],
        swing_wing=True,engine_spacing=1.05,engine_radius=.45,intake_x=1.10,intake_z=.08,intake_width=.78,intake_height=.81,gun=not ew,
        stabilator=[(.7,2.12,-4.7,-7.5),(3.65,2.12,-6.2,-7.3)])
def attackJet__tornado_ids(lod=0):return tornado('attackJet__tornado_ids','Tornado IDS',lod)

def raptor__f_22_raptor(lod=0):
    return airframe('raptor__f_22_raptor','F-22 Raptor',lod,'f22',(18.9,13.6,5.1,2.8,1.8,1.22),
        [(.85,2.35,-4.8),(4.,-.7,-4.65),(6.8,-3.7,-4.4)],
        [(-1.10,2.65,5.28,-3.5,-8.1,-5.8,-7.2),(1.10,2.65,5.28,-3.5,-8.1,-5.8,-7.2)],
        'https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/',engines=2,stealth=True,
        features=['diamond wings','chined forebody','canted twin fins','two-dimensional rectangular exhaust nozzles','internal main weapon bays','no external pylons'],
        fin_cant=25,engine_spacing=1.55,square_nozzle=True,vector_nozzle=True,intake_x=1.43,intake_z=.20,intake_width=.93,intake_height=.90,cross_power=.75,
        stabilator=[(.9,2.25,-4.9,-8.4),(4.4,2.25,-7.0,-8.1)])
def jf17__jf_17_thunder(lod=0):
    return airframe('jf17__jf_17_thunder','JF-17 Thunder',lod,'jf17',(14.97,9.465,4.775,1.4,1.5,1.05),
        [(.48,1.0,-3.1),(2.8,-.5,-3.05),(4.7325,-1.8,-2.8)],[(0,2.3,4.775,-2.8,-6.3,-4.5,-5.65)],
        'https://info.publicintelligence.net/MCIA-PakistanHandbook.pdf',
        features=['small swept wing','lateral diverterless intakes','single nozzle','single fin','rear stabilators'],
        intake_x=.76,intake_width=.58,intake_height=.65,intake_z=.18,engine_radius=.46,
        stabilator=[(.43,1.9,-3.6,-6.2),(2.5,1.9,-5.0,-5.9)])
def superTucano__a_29_super_tucano(lod=0):
    return airframe('superTucano__a_29_super_tucano','A-29 Super Tucano',lod,'tucano',(11.34,11.14,3.97,1.05,1.35,1.07),
        [(.35,.7,-1.8),(3.,.15,-1.65),(5.57,-.4,-1.35)],[(0,2.0,3.97,-2.7,-5.15,-3.85,-4.8)],
        'https://www.fab.mil.br/dimensao22/',seats=2,
        features=['five-blade tractor propeller','tandem canopy','straight tapered low wing','single tail','two wing machine guns'],
        propellers=[(0,1.745,5.3)],prop_radius=1.19,prop_blades=5,stations=(.42,.74),gun_count=2,gun_fraction=.02,gun_width=.62,gun_y=1.73,
        stabilator=[(.35,1.85,-3.4,-5.1),(2.25,1.85,-4.2,-4.95)],
        profile=[(-.5,0,.025,.04),(-.33,0,.27,.28),(-.1,0,.5,.5),(.13,0,.5,.5),(.30,-.02,.41,.39),(.46,0,.24,.24),(.49,0,.18,.18)])
def carrierJet__carrier_fighter(lod=0):
    rig,s=hornet('carrierJet__carrier_fighter','Carrier Fighter',lod);s.representative='Generic carrier fighter with F/A-18F exterior';return rig,s
def ewJet__ea_18g_growler(lod=0):return hornet('ewJet__ea_18g_growler','EA-18G Growler',lod,True)
def ewJet__j_16d(lod=0):return flanker('ewJet__j_16d','J-16D',lod,2,ew=True)

def ewJet__tornado_ecr(lod=0):return tornado('ewJet__tornado_ecr','Tornado ECR',lod,True)

def largeplane(slug,name,lod,family,dimensions,wing,fins,source,features,**details):
    L,S,H,W,B,b=dimensions
    profile=[(-.5,.02,.025,.04),(-.40,.02,.20,.24),(-.26,0,.5,.5),(.16,0,.5,.5),(.30,0,.47,.47),(.40,-.04,.36,.36),(.47,-.10,.19,.20),(.5,-.12,.04,.07)]
    d={'wing':wing,'fins':fins,'transport':True,'gun':False,'stations':(), 'profile':profile,**details}
    s=AircraftSpec(slug,name,family,L,S,H,W,B,b,len(d.get('turbofans',d.get('propellers',[]))) or 2,source,seats=2,features=features,details=d)
    return build(s,lod)

def bomber__b_52h_stratofortress(lod=0):
    gear=[{'name':n,'x':x,'z':z,'radius':.56,'axles':2} for n,x,z in
          [('Gear_Nose',-.8,7.8),('Gear_Front_Right',.8,7.8),('Gear_Left',-.8,-6.7),('Gear_Right',.8,-6.7)]]
    gear +=[{'name':'Gear_Wing_'+t,'x':x,'z':-16.,'radius':.28,'hinge_y':1.7,'pairs':1} for t,x in [('L',-27.),('R',27.)]]
    return largeplane('bomber__b_52h_stratofortress','B-52H Stratofortress',lod,'b52',(48.5,56.4,12.4,3.7,4.,3.),
        [(1.4,5.8,6.,-5.),(28.2,1.5,-16.,-19.2)],[(0,6.0,12.4,-13.,-23.,-18.6,-21.8)],
        'https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104465/b-52-stratofortress/',
        ['eight engines in four paired pods','long swept drooping wings','four body-wheel bogies and wingtip outriggers','single swept fin','internal bomb bay'],
        turbofans=[(side*x,y,z) for side in (-1,1) for x,y,z in [(7.8,3.4,1.0),(9.05,3.4,1.0),(16.2,2.1,-6.8),(17.45,2.1,-6.8)]],
        fan_radius=.60,fan_length=3.5,engine_mount_y=5.1,gear_layout=gear,internal_bomber=True,
        stabilator=[(.9,5.4,-14.,-22.),(9.5,5.4,-19.3,-21.8)])

def bomber__h_6k(lod=0):
    return largeplane('bomber__h_6k','H-6K',lod,'h6',(34.8,33.,10.36,2.9,3.2,2.3),
        [(1.1,4.8,4.3,-5.1),(16.5,4.3,-7.9,-10.1)],[(0,5.0,10.36,-9.0,-16.,-12.9,-15.2)],
        'https://odin.t2com.army.mil/WEG/Asset/H-6',
        ['swept mid wing','two large root-mounted turbofans','solid radar nose','single swept tail','internal bomb bay'],
        turbofans=[(-2.2,3.8,-.7),(2.2,3.8,-.7)],fan_radius=.79,fan_length=11.5,internal_bomber=True,
        stabilator=[(.8,4.7,-10.,-15.8),(5.8,4.7,-13.2,-15.5)],
        gear_layout=[{'name':'Gear_Nose','x':0,'z':10.,'radius':.45,'pairs':2}]+[{'name':n,'x':x,'z':-2.8,'radius':.63,'axles':2} for n,x in [('Gear_Left',-2.75),('Gear_Right',2.75)]])

def bomber__tu_160m(lod=0):
    return largeplane('bomber__tu_160m','Tu-160M',lod,'tu160',(54.1,55.7,13.1,4.1,4.5,3.1),
        [(2.5,6.1,4.8,-9.2),(27.85,5.5,-11.,-15.)],[(0,7.,13.1,-13.,-25.5,-20.,-23.8)],
        'https://www.uacrussia.ru/en/aircraft/lineup/special/tu-160/',
        ['long blended pointed nose','variable-sweep wings','four engines in paired ventral groups','large swept fin','internal cruise-missile bays'],
        turbofans=[(-4.6,4.1,-3.),(-3.15,4.1,-3.),(3.15,4.1,-3.),(4.6,4.1,-3.)],fan_radius=.90,fan_length=11.5,
        supersonic_pods=True,internal_bomber=True,swing_wing=True,
        stabilator=[(1.1,6.5,-15.2,-25.),(9.7,6.5,-20.8,-24.)],
        gear_layout=[{'name':'Gear_Nose','x':0,'z':16.,'radius':.50,'pairs':2}]+[{'name':n,'x':x,'z':-3.6,'radius':.70,'axles':3} for n,x in [('Gear_Left',-2.9),('Gear_Right',2.9)]])

def aewc__a_50u(lod=0):
    gear=[{'name':'Gear_Nose','x':0,'z':14.,'radius':.46,'pairs':4}]
    gear +=[{'name':name,'x':x,'z':z,'radius':.62,'axles':2} for name,x,z in
            [('Gear_Left',-2.5,-3.9),('Gear_Right',2.5,-3.9),('Gear_Left_Aft',-2.5,-6.2),('Gear_Right_Aft',2.5,-6.2)]]
    return largeplane('aewc__a_50u','A-50U',lod,'a50',(46.59,50.5,14.76,4.8,4.9,2.2),
        [(1.7,6.45,4.3,-6.),(25.25,6.5,-6.6,-10.1)],[(0,7.,14.76,-12.,-22.,-18.4,-21.)],
        'https://www.uacrussia.ru/en/aircraft/lineup/special/',
        ['Il-76 high-wing airframe','four underwing turbofans','T-tail','large dorsal rotating radar disc','four main bogies'],
        turbofans=[(side*x,4.7,z) for side in (-1,1) for x,z in [(7.2,1.),(13.6,-2.0)]],fan_radius=.88,fan_length=4.0,engine_mount_y=6.5,
        stabilator=[(.04,14.0,-17.6,-21.3),(8.8,14.0,-19.7,-21.1)],radome=[0,11.65,-2.7,4.5,4.5,1.0],gear_layout=gear)

def aewc__e_2c_hawkeye(lod=0):
    gear=[{'name':'Gear_Nose','x':0,'z':5.0,'radius':.31,'pairs':2},
          {'name':'Gear_Left','x':-4.05,'z':-.2,'radius':.49,'pairs':1,'hinge_y':3.3},
          {'name':'Gear_Right','x':4.05,'z':-.2,'radius':.49,'pairs':1,'hinge_y':3.3}]
    fins=[(x,2.3,4.8,-4.8,-7.9,-6.0,-7.5) for x in (-3.65,-1.2,1.2,3.65)]
    return largeplane('aewc__e_2c_hawkeye','E-2C Hawkeye',lod,'e2',(17.53,24.56,5.58,2.45,2.4,1.23),
        [(.8,3.32,1.5,-2.0),(12.28,3.5,.0,-1.5)],fins,
        'https://www.marines.mil/Portals/1/Publications/FM%2044-80.pdf',
        ['high straight wing','two four-blade turboprop engines','four vertical tail fins','dorsal rotating radar disc','carrier landing gear'],
        propellers=[(-4.05,3.10,3.),(4.05,3.10,3.)],prop_radius=2.05,prop_blades=4,prop_nacelle=5.2,
        stabilator=[(.5,2.3,-4.9,-7.8),(4.4,2.3,-5.3,-7.6)],radome=[0,5.12,-.65,3.66,3.66,.92],gear_layout=gear)

def airliner_gear(L,track,r=.5,axles=1):
    return [{'name':'Gear_Nose','x':0,'z':L*.32,'radius':r*.72,'pairs':2}]+[
        {'name':n,'x':x,'z':-L*.08,'radius':r,'pairs':2,'axles':axles,'axis':'Z'} for n,x in [('Gear_Left',-track/2),('Gear_Right',track/2)]]

def sentry(slug,name,lod,cfm=False):
    return largeplane(slug,name,lod,'e3',(46.68,44.45,12.70,3.76,3.8,2.2),
        [(1.35,3.8,4.5,-5.8),(22.225,4.9,-10.7,-13.5)],[(0,5.2,12.7,-12.2,-22.3,-18.7,-21.)],
        'https://awacs.nato.int/organisation/awacs-fleet-2',
        ['Boeing 707 airframe','four underwing turbofans','dorsal rotating radar disc','low swept wing','four-wheel main bogies','CFM56 nacelles' if cfm else 'slender TF33 nacelles'],
        turbofans=[(side*x,2.9,z) for side in (-1,1) for x,z in [(7.,2.6),(12.8,-1.6)]],
        fan_radius=.91 if cfm else .64,fan_length=3.6,engine_mount_y=4.,radome=[0,9.55,-3.3,4.55,4.55,1.8],
        stabilator=[(.7,5.1,-13.3,-21.),(7.6,5.8,-17.4,-20.3)],gear_layout=airliner_gear(46.68,6.7,.56,2))
def aewc__e_3a_sentry(lod=0):return sentry('aewc__e_3a_sentry','E-3A Sentry',lod)
def aewc__e_3f_sentry(lod=0):return sentry('aewc__e_3f_sentry','E-3F Sentry',lod,True)
def aewc__e_3g_sentry(lod=0):return sentry('aewc__e_3g_sentry','E-3G Sentry',lod)

def wedgetail(slug,name,lod):
    return largeplane(slug,name,lod,'e7',(33.6,34.3,12.6,3.76,3.8,1.3),
        [(1.35,2.95,3.6,-5.5),(17.15,4.0,-5.6,-7.9)],[(0,4.9,12.6,-7.,-15.5,-12.0,-14.5)],
        'https://www.airforce.gov.au/aircraft/e-7a-wedgetail',
        ['Boeing 737-700 airframe','two underwing turbofans','fixed MESA top-hat radar','swept low wing','electronic radar scan without rotating exterior'],
        turbofans=[(-5.6,2.15,1.4),(5.6,2.15,1.4)],fan_radius=.94,fan_length=3.1,engine_mount_y=3.0,
        aesa_bar={'y':7.55,'z':-1.6,'length':10.5,'width':2.4,'height':.34,'top_hat':True},
        stabilator=[(.65,4.4,-9.1,-15.0),(6.2,4.8,-12.,-14.5)],gear_layout=airliner_gear(33.6,5.3,.48))
def aewc__e_7_peace_eye(lod=0):return wedgetail('aewc__e_7_peace_eye','E-7 Peace Eye',lod)
def aewc__e_7_wedgetail_aew1(lod=0):return wedgetail('aewc__e_7_wedgetail_aew1','E-7 Wedgetail AEW1',lod)
def aewc__e_767(lod=0):
    return largeplane('aewc__e_767','E-767',lod,'e767',(48.51,47.57,15.85,5.03,5.1,2.0),
        [(1.8,4.0,4.7,-6.8),(23.785,5.2,-7.8,-10.5)],[(0,6.7,15.85,-12.0,-23.0,-19.2,-22.)],
        'https://www.mod.go.jp/asdf/equipment/keikaiki/E-767/',
        ['Boeing 767 wide-body airframe','two large underwing turbofans','dorsal rotating radar disc','swept low wing','four-wheel main bogies'],
        turbofans=[(-7.1,2.9,1.8),(7.1,2.9,1.8)],fan_radius=1.12,fan_length=4.2,engine_mount_y=4.2,
        radome=[0,11.0,-3.5,4.55,4.55,1.8],stabilator=[(.9,5.8,-13.0,-22.3),(9.5,6.4,-18.0,-21.5)],gear_layout=airliner_gear(48.51,9.3,.62,2))

def aewc__e_7a_wedgetail(lod=0):return wedgetail('aewc__e_7a_wedgetail','E-7A Wedgetail',lod)
def aewc__e_7t_peace_eagle(lod=0):return wedgetail('aewc__e_7t_peace_eagle','E-7T Peace Eagle',lod)

def emb145(slug,name,lod,netra=False):
    return largeplane(slug,name,lod,'emb145',(29.87,20.04,6.76,2.1,2.2,1.3),
        [(.75,2.3,1.9,-3.2),(10.02,3.1,-3.8,-5.5)],[(0,3.6,6.76,-7.7,-14.2,-11.7,-13.8)],
        'https://drdo.gov.in/drdo/en/offerings/products/netra' if netra else 'https://www.embraer.com/defense-security/en-us/airborne-early-warning-control',
        ['slender ERJ-145 airframe','two rear-mounted turbofans','T-tail','fixed dorsal DRDO radar array' if netra else 'fixed dorsal Erieye radar beam','low swept wings'],
        turbofans=[(-1.6,3.05,-9.),(1.6,3.05,-9.)],fan_radius=.55,fan_length=2.8,rear_engines=True,
        aesa_bar={'y':5.05,'z':-.5,'length':8.1 if netra else 8.6,'width':.80 if netra else .65,'height':.85},
        stabilator=[(.025,6.35,-11.6,-14.1),(4.1,6.35,-12.5,-13.9)],gear_layout=airliner_gear(29.87,4.3,.36))
def aewc__e_99(lod=0):return emb145('aewc__e_99','E-99',lod)

def g550(slug,name,lod):
    return largeplane(slug,name,lod,'g550',(29.4,28.5,7.9,2.4,2.4,1.4),
        [(.85,2.6,2.5,-3.5),(14.25,3.4,-4.8,-6.1)],[(0,3.7,7.9,-8.3,-14.2,-12.2,-13.8)],
        'https://www.aeronautica.difesa.it/en/2024/06/19/g-550-caew/',
        ['Gulfstream G550 airframe','conformal lateral radar fairings','two rear turbofans','T-tail','winglets','electronic radar scan without rotating disc'],
        turbofans=[(-1.85,3.25,-9.4),(1.85,3.25,-9.4)],fan_radius=.64,fan_length=3.0,rear_engines=True,winglets=True,conformal_radar=True,
        stabilator=[(.025,7.25,-11.8,-14.1),(4.5,7.25,-12.65,-13.85)],gear_layout=airliner_gear(29.4,4.1,.40))
def aewc__g550_caew(lod=0):return g550('aewc__g550_caew','G550 CAEW',lod)
def aewc__g550_eitam(lod=0):return g550('aewc__g550_eitam','G550 Eitam',lod)

def aewc__kj_500(lod=0):
    return largeplane('aewc__kj_500','KJ-500',lod,'kj500',(34.02,38.,11.3,3.5,3.7,1.7),
        [(1.3,5.0,2.6,-3.5),(19.,5.5,-.9,-3.2)],[(0,5.2,11.3,-8.7,-15.8,-12.9,-15.3)],
        'https://odin.t2com.army.mil/WEG/Asset/KJ-500',
        ['Y-9 high-wing turboprop airframe','four six-blade propellers','fixed dorsal three-array AESA disc','conventional single tail'],
        propellers=[(side*x,4.65,z) for side in (-1,1) for x,z in [(5.,4.2),(10.5,3.0)]],prop_radius=2.25,prop_blades=6,prop_nacelle=5.7,
        radome=[0,8.45,-1.5,3.5,3.5,.80],radome_static=True,
        stabilator=[(.6,4.8,-9.3,-15.4),(6.7,4.8,-12.0,-15.0)],gear_layout=airliner_gear(34.02,4.9,.54))

def aewc__netra_aew_c(lod=0):return emb145('aewc__netra_aew_c','Netra AEW&C',lod,True)
def aewc__saab_2000_erieye(lod=0):
    return largeplane('aewc__saab_2000_erieye','Saab 2000 Erieye',lod,'saab2000',(27.28,24.76,7.73,2.31,2.4,1.25),
        [(.8,2.6,2.,-2.5),(12.38,3.05,-.5,-1.95)],[(0,3.4,7.73,-7.8,-12.9,-10.6,-12.4)],
        'https://www.saab.com/products/saab2000',
        ['slender turboprop airliner','two six-blade propellers','fixed Erieye dorsal radar beam','low tapered wings','conventional tail'],
        propellers=[(-4.2,2.365,3.6),(4.2,2.365,3.6)],prop_radius=1.905,prop_blades=6,prop_nacelle=4.4,
        aesa_bar={'y':5.4,'z':-.5,'length':8.5,'width':.65,'height':.85},
        stabilator=[(.03,3.65,-8.4,-12.8),(4.6,3.65,-10.1,-12.4)],gear_layout=airliner_gear(27.28,5.1,.39))

def maritimePatrol__atlantique_2(lod=0):
    return largeplane('maritimePatrol__atlantique_2','Atlantique 2',lod,'atl2',(31.7,37.5,10.8,3.3,4.1,1.25),
        [(1.1,4.2,2.8,-3.4),(18.75,4.3,-1.8,-3.6)],[(0,5.0,10.8,-7.3,-13.3,-10.7,-12.7)],
        'https://www.dassault-aviation.com/en/defense/customer-support/operational-aircraft/atlantique-2/',
        ['deep double-bubble patrol fuselage','glazed observer nose','two four-blade Tyne turboprops','ventral radar fairing','long MAD tail sting','internal torpedo bay'],
        propellers=[(-6.0,4.05,3.6),(6.0,4.05,3.6)],prop_radius=2.44,prop_blades=4,prop_nacelle=6.1,
        glazed_nose=True,internal_bomber=True,belly_radar=[0,1.20,4.0,1.05,.36,1.5],
        stabilator=[(.06,4.6,-8.6,-12.8),(6.1,4.6,-10.2,-12.4)],gear_layout=airliner_gear(31.7,7.8,.58,2),
        profile=[(-.5,.02,.015,.02),(-.40,.02,.04,.05),(-.30,0,.32,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.09,.12)])
def maritimePatrol__cn_235_mpa(lod=0):
    return largeplane('maritimePatrol__cn_235_mpa','CN-235 MPA',lod,'cn235',(21.4,25.81,8.12,2.9,3.1,1.25),
        [(1.,4.0,1.8,-2.3),(12.905,4.1,-.5,-2.1)],[(0,4.0,8.12,-5.4,-9.7,-7.5,-9.1)],
        'https://www.military.ie/en/who-we-are/air-corps/the-fleet/casa-cn-235/',
        ['high tapered wing','two four-blade turboprops','squared cargo-derived fuselage','ventral maritime radar fairing','conventional tail'],
        propellers=[(-4.4,3.65,3.0),(4.4,3.65,3.0)],prop_radius=1.85,prop_blades=4,prop_nacelle=4.7,cross_power=.85,
        belly_radar=[0,1.15,2.8,.75,.35,1.1],stabilator=[(.05,3.9,-5.6,-9.3),(4.4,3.9,-7.6,-9.0)],gear_layout=airliner_gear(21.4,3.9,.43))
def maritimePatrol__il_38n(lod=0):
    return largeplane('maritimePatrol__il_38n','Il-38N',lod,'il38',(39.6,37.4,10.16,3.7,3.7,2.0),
        [(1.3,3.5,4.0,-3.6),(18.7,4.0,-.6,-3.2)],[(0,5.1,10.16,-10.1,-17.6,-13.9,-16.9)],
        'https://npo-leninetz.ru/news/67/',
        ['four four-blade turboprops','low tapered wings','Novella dorsal sensor frame','ventral radar fairing','MAD tail sting','internal torpedo bay'],
        propellers=[(side*x,3.55,z) for side in (-1,1) for x,z in [(5.6,5.6),(11.4,4.6)]],prop_radius=2.25,prop_blades=4,prop_nacelle=5.9,
        novella_array=True,belly_radar=[0,1.8,6.,1.0,.40,1.5],internal_bomber=True,
        stabilator=[(.05,4.8,-11.5,-17.1),(6.8,4.8,-14.,-16.6)],gear_layout=airliner_gear(39.6,8.0,.58,2),
        profile=[(-.5,0,.015,.02),(-.42,0,.04,.05),(-.32,0,.32,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.08,.1)])
def maritimePatrol__kawasaki_p_1(lod=0):
    return largeplane('maritimePatrol__kawasaki_p_1','Kawasaki P-1',lod,'p1',(38.,35.4,12.1,3.7,4.,1.6),
        [(1.3,3.5,4.5,-4.),(17.7,4.5,-5.7,-7.8)],[(0,5.2,12.1,-9.0,-16.9,-13.5,-16.3)],
        'https://global.kawasaki.com/en/mobility/air/aircrafts/p_1.html',
        ['four underwing turbofans','broad patrol fuselage','low swept wing','MAD tail sting','internal torpedo bay'],
        turbofans=[(side*x,2.7,z) for side in (-1,1) for x,z in [(5.,2.4),(9.5,.5)]],fan_radius=.65,fan_length=3.0,engine_mount_y=3.5,internal_bomber=True,
        stabilator=[(.05,4.9,-10.,-16.4),(6.2,5.1,-13.,-16.)],gear_layout=airliner_gear(38.,7.2,.56,2),
        profile=[(-.5,0,.015,.02),(-.41,0,.04,.05),(-.30,0,.33,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.08,.10)])

def orion(slug,name,lod):
    return largeplane(slug,name,lod,'p3',(35.57,30.38,10.27,3.45,3.6,1.85),
        [(1.2,3.3,3.,-3.4),(15.19,3.9,-1.3,-3.3)],[(0,4.9,10.27,-8.3,-14.4,-11.6,-13.8)],
        'https://www.navair.navy.mil/product/P-3C-Orion',
        ['four four-blade turboprops','low tapered wing','long MAD tail sting','conventional tail','internal torpedo bay'],
        propellers=[(side*x,3.35,z) for side in (-1,1) for x,z in [(5.1,4.8),(10.2,3.8)]],prop_radius=2.055,prop_blades=4,prop_nacelle=5.5,
        internal_bomber=True,stabilator=[(.05,4.7,-9.4,-14.0),(5.5,4.7,-11.5,-13.7)],gear_layout=airliner_gear(35.57,7.2,.52),
        profile=[(-.5,0,.015,.02),(-.41,0,.04,.05),(-.30,0,.32,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.08,.10)])
def maritimePatrol__p_3am_orion(lod=0):return orion('maritimePatrol__p_3am_orion','P-3AM Orion',lod)
def maritimePatrol__p_3c_orion(lod=0):return orion('maritimePatrol__p_3c_orion','P-3C Orion',lod)

def atr72(slug,name,lod,armed=False):
    return largeplane(slug,name,lod,'atr72',(27.16,27.05,7.65,2.86,3.0,1.2),
        [(1.0,3.9,1.9,-2.7),(13.525,4.25,-.9,-2.4)],[(0,4.0,7.65,-7.1,-12.8,-10.1,-12.3)],
        'https://www.aeronautica.difesa.it/en/home/noi-siamo-l-am/personale-e-mezzi/',
        ['high tapered wing','two six-blade turboprops','T-tail','ventral search radar','two external torpedo stations' if armed else 'unarmed maritime-surveillance configuration'],
        propellers=[(-4.9,3.6,3.3),(4.9,3.6,3.3)],prop_radius=1.965,prop_blades=6,prop_nacelle=4.9,
        belly_radar=[0,1.15,3.0,.88,.34,1.25],stabilator=[(.025,7.15,-9.8,-12.5),(4.7,7.15,-10.8,-12.3)],
        stations=(.42,) if armed else (),store_length=2.85,store_radius=.162,store_torpedo=True,gear_layout=airliner_gear(27.16,4.1,.43))
def maritimePatrol__p_72(lod=0):return atr72('maritimePatrol__p_72','P-72',lod,True)
def maritimePatrol__p_72a(lod=0):return atr72('maritimePatrol__p_72a','P-72A',lod)

def poseidon(slug,name,lod,indian=False):
    extra={'profile':[(-.5,0,.015,.02),(-.43,0,.04,.05),(-.32,0,.32,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.08,.10)]} if indian else {}
    return largeplane(slug,name,lod,'p8',(39.5,37.64,12.83,3.76,3.8,1.3),
        [(1.35,2.95,4.0,-5.8),(15.7,4.0,-5.1,-7.3),(18.82,4.2,-7.3,-8.2)],[(0,4.9,12.83,-8.6,-18.4,-14.7,-17.5)],
        'https://www.boeing.com/defense/patrol-early-warning-and-battle-management/p-8-poseidon',
        ['Boeing 737-800 patrol airframe','two underwing turbofans','raked wingtips','internal torpedo bay']+(['MAD tail sting'] if indian else ['conventional tail cone without MAD boom']),
        turbofans=[(-5.65,2.15,1.8),(5.65,2.15,1.8)],fan_radius=.94,fan_length=3.1,engine_mount_y=3.,internal_bomber=True,
        stabilator=[(.65,4.4,-11.3,-17.8),(6.4,4.8,-14.5,-17.2)],gear_layout=airliner_gear(39.5,5.5,.49),**extra)
def maritimePatrol__p_8a_poseidon(lod=0):return poseidon('maritimePatrol__p_8a_poseidon','P-8A Poseidon',lod)
def maritimePatrol__p_8i_neptune(lod=0):return poseidon('maritimePatrol__p_8i_neptune','P-8I Neptune',lod,True)

def maritimePatrol__poseidon_mra1(lod=0):return poseidon('maritimePatrol__poseidon_mra1','Poseidon MRA1',lod)
def maritimePatrol__y_8q(lod=0):
    return largeplane('maritimePatrol__y_8q','Y-8Q',lod,'y8q',(34.02,38.,11.3,3.5,3.7,1.7),
        [(1.3,5.0,2.6,-3.5),(19.,5.5,-.9,-3.2)],[(0,5.2,11.3,-8.7,-15.8,-12.9,-15.3)],
        'https://odin.t2com.army.mil/WEG/Asset/Y-8',
        ['high-wing patrol airframe','four six-blade propellers','large undernose search radar','long MAD tail boom','internal torpedo bay'],
        propellers=[(side*x,4.65,z) for side in (-1,1) for x,z in [(5.,4.2),(10.5,3.0)]],prop_radius=2.25,prop_blades=6,prop_nacelle=5.7,
        belly_radar=[0,1.50,7.5,1.05,.45,1.6],internal_bomber=True,
        stabilator=[(.05,4.8,-9.3,-15.4),(6.7,4.8,-12.0,-15.0)],gear_layout=airliner_gear(34.02,4.9,.54),
        profile=[(-.5,0,.015,.02),(-.41,0,.04,.05),(-.30,0,.32,.32),(-.14,0,.5,.5),(.16,0,.5,.5),(.32,0,.46,.46),(.43,-.04,.31,.34),(.50,-.08,.08,.10)])

def uas(slug,name,lod,family,dimensions,wing,fins,source,features,representative='',**details):
    L,S,H,W,B,b=dimensions
    profile=[(-.48,0,.10,.12),(-.35,0,.25,.30),(-.15,0,.44,.43),(.05,0,.5,.5),(.25,0,.46,.46),(.40,-.03,.28,.31),(.5,-.06,.04,.06)]
    d={'wing':wing,'fins':fins,'unmanned':True,'gun':False,'nose_hump':True,'profile':profile,
       'stations':(.34,.56),'store_length':.95,'store_radius':.07,'store_fin_scale':.45,**details}
    s=AircraftSpec(slug,name,family,L,S,H,W,B,b,len(d.get('propellers',[])) or 1,source,
        seats=0,representative=representative,features=features,details=d)
    return build(s,lod)

def akinci(slug,name,lod,representative=''):
    return uas(slug,name,lod,'akinci',(12.2,20.,4.1,1.5,1.5,1.1),
        [(.5,2.35,1.4,-2.3),(3.3,3.0,.6,-2.0),(10.,2.6,-1.0,-1.9)],[(0,2.5,4.1,-3.2,-5.6,-4.35,-5.25)],
        'https://baykartech.com/en/uav/bayraktar-akinci/',
        ['twin five-blade tractor turboprops','gull-wing centre section','large nose satellite fairing','conventional tail','ventral electro-optical turret'],representative or 'Bayraktar Akinci-A, AI-450T five-blade propeller configuration',
        propellers=[(-3.3,2.6,2.3),(3.3,2.6,2.3)],prop_radius=1.5,prop_blades=5,prop_nacelle=4.1,
        stabilator=[(.05,2.15,-3.5,-5.8),(3.25,2.15,-4.6,-5.6)],gear_track=3.6,wheel_radius=.26,stations=(.36,.56,.77),store_length=1.45,store_radius=.10)
def drone__akinci_wing_loong(lod=0):return akinci('drone__akinci_wing_loong','Akinci / Wing Loong',lod,'Bayraktar Akinci exterior')

def tb2(slug,name,lod,representative=''):
    return uas(slug,name,lod,'tb2',(6.4,12.,2.2,.65,.68,.75),
        [(.30,1.2,.75,-1.35),(3.,1.2,.4,-1.05),(6.,1.2,-.1,-.75)],
        [(-1.15,.95,2.70,-2.34,-3.18,-2.73,-3.12),(1.15,.95,2.70,-2.34,-3.18,-2.73,-3.12)],
        'https://baykartech.com/en/uav/bayraktar-tb2/',
        ['twin tail booms','inverted-V tail','single rear pusher propeller','straight high-aspect-ratio wing','nose sensor turret','four light-munition stations'],representative,
        propellers=[(0,1.09,-1.63)],prop_radius=.70,prop_blades=3,prop_pusher=True,
        twin_boom=True,boom_x=1.15,boom_y=.95,fin_cant=-45,gear_track=2.1,wheel_radius=.17,
        profile=[(-.25,0,.10,.12),(-.18,0,.30,.34),(0,0,.5,.5),(.20,0,.48,.48),(.38,-.03,.31,.34),(.50,-.06,.05,.07)])
def drone__bayraktar_tb2(lod=0):return tb2('drone__bayraktar_tb2','Bayraktar TB2',lod)
def drone__bayraktar_tb2_domestic(lod=0):return tb2('drone__bayraktar_tb2_domestic','Bayraktar TB2 / domestic',lod,'Bayraktar TB2 exterior')
def drone__bayraktar_tb2_mohajer_6(lod=0):return tb2('drone__bayraktar_tb2_mohajer_6','Bayraktar TB2 / Mohajer-6',lod,'Bayraktar TB2 exterior')

def male(slug,name,lod,family,dimensions,source,representative='',blades=3,stations=(.34,.56),prop_radius=None,**extras):
    L,S,H,W,B,b=dimensions;cy=b+B/2;root=b+B*.75;delta=(H-root)/.70710678
    return uas(slug,name,lod,family,dimensions,
        [(W*.40,b+B*.75,L*.11,-L*.17),(S*.27,b+B*.75,L*.035,-L*.145),(S/2,b+B*.75,-L*.065,-L*.12)],
        [(-W*.22,root,root+delta,-L*.30,-L*.455,-L*.38,-L*.445),(W*.22,root,root+delta,-L*.30,-L*.455,-L*.38,-L*.445)],
        source,['long straight tapered wing','single pusher propeller','outward V tail','nose satellite fairing','ventral sensor turret'],representative,
        propellers=[(0,cy,-L*.49)],prop_radius=prop_radius or min(cy-.28,L*.13),prop_blades=blades,prop_pusher=True,
        fin_cant=45,gear_track=W*2.2,wheel_radius=min(.27,L*.027),stations=stations,**extras)
def drone__ch_4b(lod=0):
    return male('drone__ch_4b','CH-4B',lod,'ch4',(8.5,18.,2.7,.80,.95,1.0),'https://odin.t2com.army.mil/WEG/Asset/CH-4')
def drone__ch_4b_anka(lod=0):
    return male('drone__ch_4b_anka','CH-4B / Anka',lod,'ch4',(8.5,18.,2.7,.80,.95,1.0),'https://odin.t2com.army.mil/WEG/Asset/CH-4','CH-4B exterior')
def drone__hermes_900(lod=0):
    return male('drone__hermes_900','Hermes 900',lod,'hermes900',(8.3,15.,1.8,.75,.70,.55),'https://www.elbitsystems.com/air-space/unmanned-aerial-systems/hermes-900',blades=2,stations=())

def heron(slug,name,lod,tp=False):
    L,S,H,W,B,b=(14.,26.,4.6,1.4,1.5,1.5) if tp else (8.5,16.6,2.3,1.0,.85,.75)
    x=2.0 if tp else 1.3;y=2.1 if tp else 1.2
    return uas(slug,name,lod,'herontp' if tp else 'heron',(L,S,H,W,B,b),
        [(W*.4,b+B*.78,L*.1,-L*.17),(S*.28,b+B*.78,L*.03,-L*.14),(S/2,b+B*.78,-L*.04,-L*.10)],
        [(-x,y,H,-L*.36,-L*.50,-L*.43,-L*.48),(x,y,H,-L*.36,-L*.50,-L*.43,-L*.48)],
        'https://www.iai.co.il/product/heron-tp/' if tp else 'https://www.iai.co.il/product/heron/',
        ['long high-aspect-ratio wing','twin tail booms','two vertical fins with connecting tailplane','rear pusher propeller','ISR configuration without external weapons'],
        propellers=[(0,b+B/2,-L*.26)],prop_radius=1.50 if tp else .75,prop_blades=4 if tp else 2,prop_pusher=True,
        twin_boom=True,boom_x=x,boom_y=y,h_tail=True,stations=(),gear_track=W*2.3,wheel_radius=.30 if tp else .18,
        stabilator=[(.03,y+.05,-L*.42,-L*.49),(x+.20,y+.05,-L*.43,-L*.49)],
        profile=[(-.26,0,.10,.12),(-.18,0,.30,.34),(0,0,.5,.5),(.20,0,.48,.48),(.38,-.03,.31,.34),(.50,-.06,.05,.07)])
def drone__heron_isr(lod=0):return heron('drone__heron_isr','Heron ISR',lod)
def drone__heron_tp(lod=0):return heron('drone__heron_tp','Heron TP',lod,True)
def drone__kus_fs(lod=0):
    return male('drone__kus_fs','KUS-FS',lod,'kusfs',(13.,25.,3.0,1.2,1.4,1.0),'https://www.koreanair.com/contents/footer/about-us/aerospace',blades=4,
        ventral_fin=True,belly_radar=[0,.95,-.5,.60,.25,.80])

def drone__mohajer_6(lod=0):
    return uas('drone__mohajer_6','Mohajer-6',lod,'mohajer6',(5.67,10.,1.8,.63,.60,.60),
        [(.28,1.05,.45,-.80),(2.8,1.05,.18,-.70),(5.,1.05,-.15,-.55)],
        [(-.88,.90,1.8,-2.0,-2.8,-2.35,-2.7),(.88,.90,1.8,-2.0,-2.8,-2.35,-2.7)],
        'https://odin.t2com.army.mil/WEG/Asset/Mohajer-6',
        ['straight tapered wing','twin booms with H tail','three-blade rear pusher','two light guided-bomb stations','ventral sensor turret'],
        propellers=[(0,.90,-1.50)],prop_radius=.65,prop_blades=3,prop_pusher=True,
        twin_boom=True,boom_x=.88,boom_y=.90,h_tail=True,gear_track=1.65,wheel_radius=.14,stations=(.34,),
        stabilator=[(.03,.95,-2.35,-2.78),(1.05,.95,-2.42,-2.76)],
        profile=[(-.26,0,.10,.12),(-.18,0,.30,.34),(0,0,.5,.5),(.20,0,.48,.48),(.38,-.03,.31,.34),(.50,-.06,.05,.07)])

def reaper(slug,name,lod,b=False,sea=False):
    return male(slug,name,lod,'mq9b' if b else 'mq9a',(11.7,24.,3.9,1.3,1.4,1.25) if b else (11.,20.1,3.8,1.2,1.3,1.3),
        'https://www.ga-asi.com/remotely-piloted-aircraft/mq-9b' if b else 'https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104470/mq-9-reaper/',
        blades=4 if b else 3,stations=(.34,.53,.72),prop_radius=1.55 if b else 1.50,ventral_fin=True,store_length=1.63,store_radius=.089,store_fin_scale=.6,
        **({'belly_radar':[0,1.15,.5,.45,.30,.65]} if sea else {}))
def drone__mq_9_reaper(lod=0):return reaper('drone__mq_9_reaper','MQ-9 Reaper',lod)
def drone__mq_9a_reaper(lod=0):return reaper('drone__mq_9a_reaper','MQ-9A Reaper',lod)
def drone__mq_9b_protector(lod=0):return reaper('drone__mq_9b_protector','MQ-9B Protector',lod,True)
def drone__mq_9b_seaguardian(lod=0):return reaper('drone__mq_9b_seaguardian','MQ-9B SeaGuardian',lod,True,True)
def drone__orion(lod=0):
    return male('drone__orion','Orion',lod,'orion',(8.,16.3,3.2,.8,.95,.80),'https://odin.t2com.army.mil/WEG/Asset/Orion',blades=3,stations=(.34,))

ROSTER_REFERENCE='https://github.com/amithey/dominion/blob/main/native/CODEX-UNIT-ROSTER.md'
def drone__saetbyol_4_9(lod=0):
    return male('drone__saetbyol_4_9','Saetbyol-4/9',lod,'saetbyol9',(11.5,20.,3.8,1.2,1.4,1.3),ROSTER_REFERENCE,
        'Approximate Saetbyol-9 MALE exterior; combined roster row',blades=4,stations=(.34,.53,.72),ventral_fin=True,generic_design=True)

def multicopter(slug,name,lod,motors=4,heavy=False,representative='',payload_count=1,small=False):
    import math
    L,S,H,W,B,b=(2.8,2.8,1.05,.78,.28,.48) if heavy else (1.25,1.25,.62,.35,.18,.28)
    arm=1.02 if heavy else .52;hub=.90 if heavy else .49
    if small:L=S=.65;H=.35;W=.18;B=.10;b=.12;arm=.27;hub=.24
    positions=[[arm*math.sin(t),hub,arm*math.cos(t)] for t in [math.tau*i/motors+math.pi/motors for i in range(motors)]]
    s=AircraftSpec(slug,name,'multirotor',L,S,H,W,B,b,0,ROSTER_REFERENCE,seats=0,representative=representative,
        features=[str(motors)+' independent motor/propeller hubs','closed central battery/payload frame','landing skids','gravity payload release' if heavy else 'forward payload and camera'],
        details={'multirotor':True,'unmanned':True,'generic_design':True,'motors':motors,'propellers':positions,'prop_radius':.12 if small else .43 if heavy else .23,'prop_blades':2,'bomber':heavy,'payload_count':payload_count,'small':small})
    return build(s,lod)
def drone__shaheen(lod=0):return multicopter('drone__shaheen','Shaheen',lod,representative='Plausible Syrian light FPV strike quadcopter; roster does not identify a unique production airframe')

def drone__shahpar_ii_burraq(lod=0):
    return uas('drone__shahpar_ii_burraq','Shahpar II / Burraq',lod,'shahpar2',(8.,9.45,2.3,.85,.85,.8),
        [(.35,1.45,.65,-1.2),(2.5,1.45,-.1,-1.5),(4.725,1.45,-1.,-1.7)],
        [(-1.2,1.2,2.3,-2.6,-3.95,-3.25,-3.75),(1.2,1.2,2.3,-2.6,-3.95,-3.25,-3.75)],
        'https://www.gids.com.pk/english-short.pdf',
        ['twin-boom pusher layout','straight tapered wing','H-tail','three-blade propeller','four light weapon stations'],
        'Approximate Shahpar-II exterior; combined roster row',
        propellers=[(0,1.225,-2.1)],prop_radius=.75,prop_blades=3,prop_pusher=True,
        twin_boom=True,boom_x=1.2,boom_y=1.2,h_tail=True,gear_track=2.2,wheel_radius=.18,
        stabilator=[(.03,1.25,-3.3,-3.9),(1.4,1.25,-3.4,-3.85)],
        profile=[(-.26,0,.10,.12),(-.18,0,.30,.34),(0,0,.5,.5),(.20,0,.48,.48),(.38,-.03,.31,.34),(.50,-.06,.05,.07)])
def drone__taliban_built_drone(lod=0):
    return male('drone__taliban_built_drone','Taliban-built drone',lod,'local_light',(3.2,4.8,1.1,.40,.40,.45),ROSTER_REFERENCE,
        'Original plausible locally assembled light UAV; roster provides no unique airframe',blades=2,stations=(),generic_design=True)
def drone__wing_loong_i_ch_4(lod=0):
    return male('drone__wing_loong_i_ch_4','Wing Loong I / CH-4',lod,'wingloong1',(9.05,14.,2.77,.82,1.,1.),
        'https://cgsc.contentdm.oclc.org/digital/api/collection/p4013coll11/id/2090/download','Wing Loong I exterior',blades=3,stations=(.37,))

def wingloong2(slug,name,lod,representative=''):
    return male(slug,name,lod,'wingloong2',(11.,20.5,4.1,1.2,1.3,1.25),
        'https://odin.t2com.army.mil/WEG/Asset/Wing_Loong_II',representative,blades=3,stations=(.34,.53,.72),ventral_fin=True,prop_radius=1.4,store_length=1.6,store_radius=.10)
def drone__wing_loong_ii(lod=0):return wingloong2('drone__wing_loong_ii','Wing Loong II',lod)
def drone__wing_loong_ii_akinci(lod=0):return wingloong2('drone__wing_loong_ii_akinci','Wing Loong II / Akinci',lod,'Wing Loong II exterior')
def akinci__bayraktar_akinci(lod=0):return akinci('akinci__bayraktar_akinci','Bayraktar Akinci',lod)
def heavyBomberDrone__heavy_hexacopter(lod=0):return multicopter('heavyBomberDrone__heavy_hexacopter','Heavy Hexacopter',lod,6,True,'Original generic six-motor bomber drone')
def heavyBomberDrone__vampire_baba_yaga(lod=0):return multicopter('heavyBomberDrone__vampire_baba_yaga','Vampire / Baba Yaga',lod,6,True,'Approximate Vampire six-motor bomber with three light mortar payload positions',3)

def carrierDrone__carrier_drone(lod=0):
    return airframe('carrierDrone__carrier_drone','Carrier Drone',lod,'carrier_ucav',(12.,19.,3.2,3.5,1.4,1.1),
        [(.5,2.2,-4.8),(4.9,.1,-4.6),(9.5,-2.8,-3.7)],[],ROSTER_REFERENCE,stealth=True,
        features=['cranked flying wing','dorsal jet intake','single recessed nozzle','internal weapon bays','no vertical tail or external pylons'],
        representative='Original plausible carrier UCAV with X-47B-like planform',unmanned=True,generic_design=True,flying_wing=True,dorsal_intake=True,
        gun=False,afterburning=False,engine_radius=.50,cross_power=.72,gear_track=4.4,wheel_radius=.28,
        profile=[(-.47,0,.16,.30),(-.30,0,.40,.40),(-.10,0,.5,.5),(.12,0,.43,.46),(.30,.03,.23,.32),(.44,0,.10,.17),(.50,0,.008,.015)])
def interceptorDrone__interceptor_drone(lod=0):return multicopter('interceptorDrone__interceptor_drone','Interceptor Drone',lod,representative='Original plausible compact FPV interceptor quadcopter',small=True)

def oneway(slug,name,lod,dimensions,wing,fins,source,features,**details):
    L,S,H,W,B,b=dimensions
    return uas(slug,name,lod,'oneway',dimensions,wing,fins,source,features,
        oneway=True,landing_none=True,sensor_turret=False,nose_hump=False,stations=(),spinner_length=.12,prop_chord_scale=.40,**details)
def shahed(slug,name,lod):
    return oneway(slug,name,lod,(3.5,2.5,.60,.38,.35,.145),
        [(.13,.32,.75,-1.45),(1.25,.32,-1.05,-1.55)],
        [(-1.25,0,.60,-1.05,-1.62,-1.13,-1.54),(1.25,0,.60,-1.05,-1.62,-1.13,-1.54)],
        'https://www.dia.mil/Portals/110/DIA_Iranian_UAVs_in_Ukraine-A_Visual_Comparison.pdf',
        ['delta wing','tip fins extend above and below the wing','narrow central fuselage','rear two-blade piston pusher','no landing gear'],
        propellers=[[0,.32,-1.6275]],prop_radius=.29,prop_blades=2,prop_pusher=True)
def shahed__geran_2(lod=0):return shahed('shahed__geran_2','Geran-2',lod)
def shahed__shahed_drone(lod=0):return shahed('shahed__shahed_drone','Shahed Drone',lod)
def loiterer__arash(lod=0):
    return oneway('loiterer__arash','Arash',lod,(4.5,4.,1.0,.38,.38,.28),
        [(.14,.50,.8,-.8),(2.,.50,-.2,-.70)],[(0,.55,1.0,-1.25,-2.0,-1.55,-1.9)],ROSTER_REFERENCE,
        ['slender long fuselage','swept tapered wings','single swept fin','rear pusher propeller','gearless one-way airframe'],
        propellers=[[0,.47,-2.1]],prop_radius=.40,prop_blades=2,prop_pusher=True,generic_design=True)

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
