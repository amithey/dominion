"""P3 launchers, one explicit builder per roster designation. Original geometry.

Configurations retain actual chassis class, axle count, pod count, calibre and
tube layout. Ambiguous roster rows name a selected representative. No Blender.
"""
from pathlib import Path
import argparse,json
import numpy as np
from vehicle_parts import Mesh,loft,hollow_muzzle
from generate_p1_tanks import beam
from artillery_parts import launcher_vehicle
from generate_p3_artillery import save,ART

WEG='https://cgsc.contentdm.oclc.org/digital/api/collection/p4013coll11/id/2089/download'
REF={
 'himars':'https://www.lockheedmartin.com/en-us/products/himars.html',
 'm270':'https://www.lockheedmartin.com/en-us/products/mlrs.html',
 'puls':'https://www.elbitsystems.com/land/artillery-and-mortars/puls',
 'pinaka':'https://www.drdo.gov.in/drdo/pinaka-multi-barrel-rocket-launch-system',
 'chunmoo':'https://www.hanwhaaerospace.com/eng/business/land/',
 'astros':'https://www.avibras.com.br/site/en/areas-de-atuacao/defesa/astros.html',
 'sakarya':'https://www.roketsan.com.tr/en/products/t-122300-multi-barrel-rocket-launcher',
}
# L, W, cab roof, axle Zs (or tracked wheel count), wheel radius, tracks,
# canonical scale, bonnet, cab length, tube columns/rows/pods, calibre, depth,
# closed container, jacks, family. All lengths are metres.
CONFIGS={
 'grad':(7.35,2.40,2.68,[-2.47,-1.13,2.36],.61,False,1,1.35,1.74,10,4,1,.122,3.0,False,False,'ural_grad'),
 'a100':(11.50,3.05,2.96,[-3.80,-2.12,2.00,3.72],.65,False,1,0,2.42,5,2,1,.300,5.30,False,True,'a100'),
 'astros':(9.90,2.80,2.84,[-3.20,-1.52,3.14],.63,False,1,0,2.30,4,4,2,.127,3.40,True,True,'astros_ss30'),
 'astros6':(10.10,2.90,3.05,[-3.30,-1.64,3.21],.64,False,1,0,2.48,4,4,2,.127,3.50,True,True,'astros_mk6'),
 'uragan':(9.63,2.80,2.60,[-3.24,-1.61,1.60,3.21],.62,False,1,1.14,2.12,4,4,1,.220,4.10,False,True,'zil_135_uragan'),
 'smerch':(12.10,3.05,2.95,[-4.01,-2.25,2.05,3.94],.66,False,1,0,2.70,4,3,1,.300,7.60,False,True,'maz_smerch'),
 'fajr':(10.40,2.50,2.87,[-3.44,-1.80,3.21],.61,False,1,1.34,1.97,4,1,1,.333,5.05,False,True,'mercedes_fajr5'),
 'chunmoo':(9.0,2.90,3.0,[-2.90,-1.40,1.46,2.89],.65,False,1,0,2.38,3,2,2,.230,4.20,True,True,'chunmoo'),
 'm1991':(10.50,2.80,2.84,[-3.39,-1.62,3.32],.63,False,1,0,2.30,11,2,1,.240,4.20,False,True,'m1991'),
 'm270':(6.97,2.97,2.48,5,.32,True,.79,0,2.22,3,2,2,.227,3.80,True,False,'m270'),
 'm270a2':(6.97,2.97,2.76,5,.32,True,.79,0,2.22,3,2,2,.227,3.80,True,False,'m270a2'),
 'himars':(7.0,2.40,2.78,[-2.30,-.94,2.24],.57,False,1,0,2.24,3,2,1,.227,3.85,True,True,'fmtv_himars'),
 'phl03':(12.0,3.0,3.03,[-3.96,-2.15,1.96,3.84],.66,False,1,0,2.65,4,3,1,.300,7.60,False,True,'phl03'),
 'pinaka':(9.50,2.50,2.90,[-3.11,-1.51,1.39,3.0],.62,False,1,0,2.16,3,2,2,.214,5.10,True,True,'tatra_pinaka'),
 'puls':(10.20,2.80,2.98,[-3.37,-1.79,1.63,3.27],.63,False,1,0,2.30,4,5,2,.122,3.50,True,True,'puls_accular122'),
 'sakarya':(9.20,2.50,2.80,[-3.04,-1.48,2.95],.61,False,1,1.25,1.96,10,4,1,.122,3.08,False,True,'sakarya'),
 'fatah2':(11.80,2.90,3.05,[-3.92,-2.11,1.99,3.80],.65,False,1,0,2.40,2,1,1,.600,6.20,True,True,'fatah2'),
 'fath360':(9.60,2.55,2.90,[-3.12,-1.51,3.01],.62,False,1,0,2.20,3,2,1,.360,4.90,True,True,'fath360'),
 'kn25':(11.50,3.05,3.0,[-3.78,-2.05,1.91,3.64],.66,False,1,0,2.50,2,2,1,.600,7.0,False,True,'kn25_8x8'),
 'pch191':(11.80,3.05,3.05,[-3.90,-2.12,1.98,3.77],.66,False,1,0,2.50,2,2,2,.370,5.10,True,True,'pch191'),
 'trlg230':(10.50,2.80,2.92,[-3.46,-1.81,1.71,3.35],.63,False,1,0,2.30,3,2,1,.230,4.0,True,True,'trlg230'),
 'tos1':(7.0,3.46,1.48,6,.36,True,.87,0,0,8,3,1,.220,3.60,True,False,'tos1'),
 'ghader':(10.20,2.55,2.90,[-3.36,-1.66,3.23],.62,False,1,0,2.28,2,2,1,.50,6.40,True,True,'ghader'),
 'bastion':(12.60,3.0,3.20,[-4.14,-2.27,2.16,4.03],.68,False,1,0,2.60,2,1,1,.70,8.70,False,True,'bastion'),
 'nmesis':(6.20,2.50,1.50,[-2.05,2.02],.50,False,1,0,1.40,2,1,1,.50,4.50,True,True,'nmesis'),
 'nsm':(10.40,2.55,2.95,[-3.42,-1.73,3.31],.63,False,1,0,2.35,2,2,1,.50,5.0,True,True,'nsm'),
 'neptune':(12.0,2.90,3.10,[-3.94,-2.16,2.02,3.81],.65,False,1,0,2.52,2,2,1,.42,5.40,True,True,'neptune'),
 'type12':(9.60,2.48,2.78,[-3.15,-1.53,3.04],.61,False,1,0,2.25,3,2,1,.40,5.10,True,True,'type12'),
 'yj62':(12.0,3.0,3.05,[-3.95,-2.15,2.01,3.81],.66,False,1,0,2.50,3,1,1,.60,7.0,False,True,'yj62'),
 'brahmos':(12.70,2.80,3.10,[-4.20,-2.29,2.17,4.07],.66,False,1,0,2.52,3,1,1,.80,8.40,False,True,'brahmos'),
 'df17':(15.0,3.20,3.10,[-5.31,-3.75,-1.80,3.05,5.16],.70,False,1,0,2.70,1,1,1,1.0,10.40,False,True,'df17'),
 'shahedrail':(8.10,2.50,2.80,[-2.66,-1.10,2.58],.59,False,1,0,2.15,1,1,1,.32,4.20,False,True,'shahedrail'),
}

def launch(slug,name,lod,key,source=None,representative='',approximate=False):
    return launcher_vehicle(slug,name,lod,CONFIGS[key],source or REF.get(key,WEG),approximate,representative)

def mlrs__a_100_fatah_1(lod=0):
    return launch('mlrs__a_100_fatah_1','A-100 / Fatah-1',lod,'a100',representative='A-100 ten-tube 300 mm launcher',approximate=True)

def mlrs__astros_ii(lod=0):
    return launch('mlrs__astros_ii','ASTROS II',lod,'astros',representative='ASTROS II with 32 SS-30 rockets')

def mlrs__astros_ii_rm_70(lod=0):
    return launch('mlrs__astros_ii_rm_70','ASTROS II / RM-70',lod,'astros',representative='ASTROS II with 32 SS-30 rockets',approximate=True)

def mlrs__astros_ii_mk6(lod=0):
    return launch('mlrs__astros_ii_mk6','ASTROS II Mk6',lod,'astros6',REF['astros'],representative='ASTROS II Mk6 with SS-30 load')

def mlrs__bm_21_badr_rockets(lod=0):
    return launch('mlrs__bm_21_badr_rockets','BM-21 / Badr rockets',lod,'grad',representative='BM-21 Grad',approximate=True)

def mlrs__bm_21_taka(lod=0):
    return launch('mlrs__bm_21_taka','BM-21 / Taka',lod,'grad',representative='BM-21 Grad',approximate=True)

def mlrs__bm_21_grad(lod=0):
    return launch('mlrs__bm_21_grad','BM-21 Grad',lod,'grad')

def mlrs__bm_21_sakr(lod=0):
    return launch('mlrs__bm_21_sakr','BM-21 Sakr',lod,'grad',representative='BM-21 with Sakr 122 mm rockets')

def mlrs__bm_27_himars(lod=0):
    return launch('mlrs__bm_27_himars','BM-27 / HIMARS',lod,'uragan',representative='BM-27 Uragan sixteen-tube launcher',approximate=True)

def mlrs__bm_30_smerch(lod=0):
    return launch('mlrs__bm_30_smerch','BM-30 Smerch',lod,'smerch')

def mlrs__fajr_5(lod=0):
    return launch('mlrs__fajr_5','Fajr-5',lod,'fajr')

def mlrs__k239_chunmoo(lod=0):
    return launch('mlrs__k239_chunmoo','K239 Chunmoo',lod,'chunmoo')

def mlrs__kn_25_m1991(lod=0):
    return launch('mlrs__kn_25_m1991','KN-25 / M1991',lod,'m1991',representative='M1991 22-tube 240 mm launcher',approximate=True)

def mlrs__lru(lod=0):
    return launch('mlrs__lru','LRU',lod,'m270',REF['m270'])

def mlrs__lynx(lod=0):
    return launch('mlrs__lynx','Lynx',lod,'puls',REF['puls'],representative='Lynx with paired Accular-122 pods')

def mlrs__m142_himars(lod=0):
    return launch('mlrs__m142_himars','M142 HIMARS',lod,'himars')

def mlrs__m270_jgsdf(lod=0):
    return launch('mlrs__m270_jgsdf','M270 (JGSDF)',lod,'m270')

def mlrs__m270_mlrs(lod=0):
    return launch('mlrs__m270_mlrs','M270 MLRS',lod,'m270')

def mlrs__m270a2_mlrs(lod=0):
    return launch('mlrs__m270a2_mlrs','M270A2 MLRS',lod,'m270a2',REF['m270'],representative='M270A2, improved armoured cab and conventional paired six-round pods')

def mlrs__mars_ii(lod=0):
    return launch('mlrs__mars_ii','MARS II',lod,'m270',REF['m270'])

def mlrs__phl_03(lod=0):
    return launch('mlrs__phl_03','PHL-03',lod,'phl03')

def mlrs__pinaka(lod=0):
    return launch('mlrs__pinaka','Pinaka',lod,'pinaka')

def mlrs__puls(lod=0):
    return launch('mlrs__puls','PULS',lod,'puls',representative='PULS with paired Accular-122 pods')

def mlrs__t_122_sakarya(lod=0):
    return launch('mlrs__t_122_sakarya','T-122 Sakarya',lod,'sakarya')

def himars__chunmoo_guided_cgr_080(lod=0):
    return launch('himars__chunmoo_guided_cgr_080','Chunmoo (guided CGR-080)',lod,'chunmoo')

def himars__europuls(lod=0):
    return launch('himars__europuls','EuroPULS',lod,'puls',REF['puls'],representative='EuroPULS Accular-122 configuration')

def himars__fatah_ii(lod=0):
    return launch('himars__fatah_ii','Fatah-II',lod,'fatah2',representative='Fatah-II dual-canister 8x8 TEL',approximate=True)

def himars__fath_360_launcher(lod=0):
    return launch('himars__fath_360_launcher','Fath-360 launcher',lod,'fath360',approximate=True,representative='Six-canister Fath-360 truck launcher')

def himars__guided_pinaka(lod=0):
    return launch('himars__guided_pinaka','Guided Pinaka',lod,'pinaka')

def himars__guided_rocket_launcher(lod=0):
    return launch('himars__guided_rocket_launcher','Guided Rocket Launcher',lod,'himars',REF['himars'],representative='Generic guided rocket launcher, HIMARS representative',approximate=True)

def himars__himars(lod=0):
    return launch('himars__himars','HIMARS',lod,'himars')

def himars__kn_25_600_mm_guided(lod=0):
    return launch('himars__kn_25_600_mm_guided','KN-25 (600 mm guided)',lod,'kn25',representative='KN-25 four-tube 8x8 carrier',approximate=True)

def himars__lru_gmlrs(lod=0):
    return launch('himars__lru_gmlrs','LRU (GMLRS)',lod,'m270',REF['m270'])

def himars__m142_himars(lod=0):
    return launch('himars__m142_himars','M142 HIMARS',lod,'himars')

def himars__m270_gmlrs(lod=0):
    return launch('himars__m270_gmlrs','M270 GMLRS',lod,'m270')

def himars__m270a2_gmlrs(lod=0):
    return launch('himars__m270a2_gmlrs','M270A2 (GMLRS)',lod,'m270a2',REF['m270'],representative='M270A2 improved armoured cab with paired GMLRS pods')

def himars__pch_191(lod=0):
    return launch('himars__pch_191','PCH-191',lod,'pch191')

def himars__puls(lod=0):
    return launch('himars__puls','PULS',lod,'puls',representative='PULS with paired Accular-122 pods')

def himars__tornado_s(lod=0):
    return launch('himars__tornado_s','Tornado-S',lod,'smerch',representative='9A54 Tornado-S 12-tube carrier')

def himars__trlg_230(lod=0):
    return launch('himars__trlg_230','TRLG-230',lod,'trlg230',REF['sakarya'])

def heavyRocket__heavy_rocket_launcher(lod=0):
    return launch('heavyRocket__heavy_rocket_launcher','Heavy Rocket Launcher',lod,'kn25',representative='Generic heavy launcher, KN-25 four-tube 8x8 representative',approximate=True)

def tos1a__tos_1a_solntsepyok(lod=0):
    return launch('tos1a__tos_1a_solntsepyok','TOS-1A Solntsepyok',lod,'tos1')

def coastalASM__ghader_coastal_battery(lod=0):
    return launch('coastalASM__ghader_coastal_battery','Ghader Coastal Battery',lod,'ghader',representative='Representative four-canister Ghader coastal truck',approximate=True)

def coastalASM__k_300p_bastion_p(lod=0):
    return launch('coastalASM__k_300p_bastion_p','K-300P Bastion-P',lod,'bastion',representative='K-340P eight-wheel TEL with two Oniks canisters')

def coastalASM__nmesis(lod=0):
    rig,s=launch('coastalASM__nmesis','NMESIS',lod,'nmesis','https://www.marines.mil/News/News-Display/Article/2745323/',representative='ROGUE-Fires unmanned carrier and paired NSM canisters')
    # Driverless ROGUE-Fires is a low bonnet chassis, without a cab or windows.
    m=Mesh();h=s.length/2
    for side in (-1,1):
        m.box('metal_dark',(side*.60,.74,0),(.17,.26,s.length-.25))
        for z in s.axle_z:m.box('paint',(side*1.05,.99,z),(.46,.10,1.06))
    m.box('paint',(0,.98,2.05),(2.07,.79,1.86));m.box('paint',(0,1.09,-.70),(2.28,.20,3.63))
    m.box('metal_dark',(0,.96,3.04),(1.36,.38,.06))
    for side in (-1,1):m.box('markings',(side*1.058,1.08,2.18),(.018,.22,.41))
    for p in rig.parts:
        if p['name']=='Hull':p['mesh']=m
        elif p['name']=='Antenna_1':
            a=np.array([.79,1.39,2.25]);ant=Mesh();ant.tube('metal_dark',a,a+[0,.67,0],.013,4 if lod else 6);p['pivot']=a;p['mesh']=ant;rig.pivots[p['name']]=a
        elif p['name']=='Engine_Deck':p['pivot']=np.array([0,1.39,2.05]);rig.pivots[p['name']]=p['pivot']
    return rig,s

def coastalASM__nsm_coastal_defence_system(lod=0):
    return launch('coastalASM__nsm_coastal_defence_system','NSM Coastal Defence System',lod,'nsm','https://www.kongsberg.com/kda/what-we-do/missile-systems/nsm-coastal-defence-system/')

def coastalASM__rk_360mc_neptune(lod=0):
    return launch('coastalASM__rk_360mc_neptune','RK-360MC Neptune',lod,'neptune','https://www.luch.kiev.ua/en/',approximate=True,representative='Four-canister Neptune TEL on KrAZ-7634 8x8 exterior')

def coastalASM__type_12_ssm(lod=0):
    return launch('coastalASM__type_12_ssm','Type 12 SSM',lod,'type12','https://www.mod.go.jp/gsdf/equipment/ve/')

def coastalASM__yj_62_coastal_battery(lod=0):
    return launch('coastalASM__yj_62_coastal_battery','YJ-62 Coastal Battery',lod,'yj62','https://eng.mod.gov.cn/')

def brahmos__brahmos_battery(lod=0):
    return launch('brahmos__brahmos_battery','BrahMos Battery',lod,'brahmos','https://www.brahmos.com/',representative='Three-canister mobile autonomous launcher')

def df17__df_17_launcher(lod=0):
    rig,s=launch('df17__df_17_launcher','DF-17 Launcher',lod,'df17','https://www.defense.gov/Spotlights/2024-China-Military-Power-Report/',
       representative='DF-17 ten-wheel TEL, exposed booster and hypersonic glide vehicle; approximate public dimensions',approximate=True)
    x,y,tip=s.details['muzzle_positions'][0];rear=-s.length/2+.30;n=8 if lod else 16;m=Mesh()
    m.box('paint',(0,y-.64,(rear+tip)/2),(.78,.21,tip-rear-.10))
    m.tube('paint',(0,y,rear+.14),(0,y,tip-2.20),.48,n)
    m.tube('paint',(0,y,tip-2.20),(0,y,tip-1.73),.48,n,r_top=.25)
    loft(m,'paint',[[(-.53,y-.13,tip-2.03),(.53,y-.13,tip-2.03),(.53,y+.13,tip-2.03),(-.53,y+.13,tip-2.03)],
        [(-.008,y-.008,tip),(.008,y-.008,tip),(.008,y+.008,tip),(-.008,y+.008,tip)]])
    hollow_muzzle(m,(0,y,rear+.24),(0,y,rear-.025),.32,.23,n)
    for side in (-1,1):
        beam(m,'paint',(side*.38,y-.60,rear+.19),(side*.38,y-.34,rear+2.10),.14)
    for p in rig.parts:
        if p['name']=='Launcher':p['mesh']=m
    s.features=['Ten-wheel TEL with five axle pairs','exposed long solid-fuel booster on elevating rail','distinct pointed flattened hypersonic glide vehicle','rear stabilising jacks','single forward launch marker']
    return rig,s

def drone_rail(slug,name,lod):
    rig,s=launch(slug,name,lod,'shahedrail',WEG,approximate=True,
       representative='Generic single Shahed-136/Geran-2 launch rail on a 6x6 truck; no specific carrier asserted')
    x,y,tip=s.details['muzzle_positions'][0];rear=-s.length/2+.30;n=6 if lod else 12;m=Mesh()
    m.box('metal_dark',(0,y-.36,(rear+tip)/2),(.25,.15,tip-rear+.10))
    for zz in (rear+.50,tip-.65):beam(m,'paint',(0,y-.32,zz),(0,y-.10,zz),.12)
    m.tube('paint',(0,y,rear+.22),(0,y,tip-.38),.17,n)
    m.tube('paint',(0,y,tip-.38),(0,y,tip),.17,n,r_top=.002)
    for side in (-1,1):
        q=[(0,y+.025,tip-1.04),(side*1.48,y+.025,rear+.80),(0,y+.025,rear+.25)]
        m.solid('paint',q+[(a,b+.04,c) for a,b,c in q],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
        fin=[(side*1.48,y+.04,rear+.68),(side*1.48,y+.04,rear+1.31),(side*1.48,y+.65,rear+.78)]
        m.solid('paint',fin+[(a+side*.035,b,c) for a,b,c in fin],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
    m.tube('metal_dark',(0,y,rear+.22),(0,y,rear-.08),.045,n);m.box('metal_dark',(0,y,rear-.10),(.77,.045,.035))
    for p in rig.parts:
        if p['name']=='Launcher':p['mesh']=m
    s.features=['Original generic six-wheel mobile drone rail carrier','single delta-wing Shahed-136/Geran-2 representative',
        'twin wingtip fins and rear pusher propeller','elevating open launch rail','carrier identity unspecified in roster']
    return rig,s

def shahedLauncher__geran_2_launcher(lod=0):
    return drone_rail('shahedLauncher__geran_2_launcher','Geran-2 Launcher',lod)

def shahedLauncher__shahed_launcher(lod=0):
    return drone_rail('shahedLauncher__shahed_launcher','Shahed Launcher',lod)

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and n.startswith(('mlrs__','himars__','heavyRocket__','tos1a__','coastalASM__','brahmos__','df17__','shahedLauncher__')) and callable(f)}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug,BUILDERS[slug]) for slug in a.types]
    manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
    manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
