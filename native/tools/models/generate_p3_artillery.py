"""P3 original artillery exteriors. Metres, +Z front, articulated real mounts.

Explicit functions select a real representative for ambiguous combined rows.
Shared wheels/tracks retain the approved pilot's contract. No Blender.
"""
from dataclasses import asdict,replace
from pathlib import Path
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,loft,profile_hull,hollow_muzzle,write_glb,merge_mesh
from generate_p1_tanks import Spec,finish,make_wreck,beam,running_gear
from armour_parts import ArmourSpec,wreck as armour_wreck,mobility
from artillery_parts import towed,truck_howitzer,artillery_barrel

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

def spg(slug,name,lod,L,W,deck,roof,wheels,r,k,tz,gy,gz,overall,shape,tw,td,cal,features,source=SOVIET,representative='',approximate=False):
    """Closed SPG hull, family-specific fighting compartment and artillery mount."""
    s=Spec(slug.split('__',1)[1],name,L,W,deck,roof,wheels,r,k,tz,gy,gz,overall,shape,
           features,source,caliber=cal,front_engine=shape not in ('msta','palmaria'),approximate=approximate,representative=representative,skirts=0)
    rig=Rig(lod);h=L/2;half=W/2-.37;body=Mesh();n=6 if lod else 12
    profile_hull(body,'paint',[(h-.26,.43,half*.90),(h,deck*.73,half*.94),(h-1.15,deck,half),
       (-h+.10,deck,half),(-h,.62,half*.94),(-h+.15,.43,half*.90)])
    for side in (-1,1):
        body.box('paint',(side*(W/2-.28),1.19*k,0),(.58,.11,L-.20))
        body.box('rubber',(side*(W/2-.28),.72,-h+.04),(.53,.45,.05))
        body.box('paint',(side*(half-.06),deck*.73,h-.025),(.22,.17,.15))
        body.box('glass',(side*(half-.06),deck*.74,h+.062),(.15,.10,.025))
        body.box('paint',(side*(W/2-.14),deck-.16,-.48),(.31,.30,.66))
        body.box('markings',(side*(W/2+.024),deck-.16,-.48),(.018,.24,.51))
        if shape=='msta':body.box('rubber',(side*(W/2-.045),1.25,0),(.06,.32,L-.80))
    body.box('paint',(-.55,deck+.045,h*.43),(.64,.09,.67))
    body.box('glass',(-.55,deck+.12,h*.43+.23),(.40,.06,.13))
    grille_z=np.linspace(h*.26,h*.71,3 if lod else 12) if s.front_engine else np.linspace(-h+.20,-h+.88,3 if lod else 12)
    for zz in grille_z:body.box('metal_dark',(.48,deck+.025,zz),(.77,.035,.05))
    body.box('paint',(0,.93,-h-.02),(.82,.99,.08))
    body.remove_duplicates();rig.add('Hull',rig.root,(0,0,0),body)
    running_gear(rig,s,lod)
    if shape=='msta':
        rig.parts=[p for p in rig.parts if not p['name'].startswith('Roller_')]
        for side,label in ((-1,'L'),(1,'R')):
            for i,z in enumerate(np.linspace(-2.20,2.20,5)*k):
                name=f'Roller_{label}{i}';rig.pivots.pop(name,None)
                p=np.array([side*(W/2-.35),k,z]);roller=None
                if not lod:
                    roller=Mesh();roller.tube('rubber',p+[-.16,0,0],p+[.16,0,0],.12*k,8)
                rig.add(name,'Hull',p,roller,'X')
    m=Mesh();base=deck+.12
    m.tube('metal_dark',(0,deck+.02,tz),(0,base+.03,tz),tw*.35,8 if lod else 20)
    # Footprints encode the real turret's plan and height; no tank turret reskin.
    if shape=='msta':
        footprint=[(-tw*.31,td*.51),(tw*.31,td*.51),(tw*.50,td*.24),(tw*.50,-td*.43),(tw*.34,-td*.52),(-tw*.34,-td*.52),(-tw*.50,-td*.43),(-tw*.50,td*.24)];shrink=.96
    elif shape=='akatsiya':
        footprint=[(-tw*.25,td*.47),(tw*.25,td*.47),(tw*.50,td*.08),(tw*.49,-td*.34),(tw*.29,-td*.50),(-tw*.29,-td*.50),(-tw*.49,-td*.34),(-tw*.50,td*.08)];shrink=.85
    elif shape in ('as90','as9','k9','firtina','pzh','roem'):
        footprint=[(-tw*.28,td*.50),(tw*.28,td*.50),(tw*.50,td*.18),(tw*.50,-td*.44),(tw*.38,-td*.51),(-tw*.38,-td*.51),(-tw*.50,-td*.44),(-tw*.50,td*.18)];shrink=.91 if shape=='as90' else .96
    else:
        footprint=[(-tw*.28,td*.51),(tw*.28,td*.51),(tw*.50,td*.20),(tw*.50,-td*.37),(tw*.30,-td*.50),(-tw*.30,-td*.50),(-tw*.50,-td*.37),(-tw*.50,td*.20)];shrink=.90
    loft(m,'paint',[[(x,base,z+tz) for x,z in footprint],[(x*shrink,roof,z*.93+tz) for x,z in footprint]])
    # Rear ammunition handling doors and family-specific stowage/air conditioning.
    m.box('paint',(0,base+(roof-base)*.45,tz-td*.51-.045),(tw*.51,(roof-base)*.63,.12))
    if shape=='msta':
        for side in (-1,1):m.box('paint',(side*tw*.38,roof-.43,tz-td*.45),(.55,.69,.70))
        m.box('paint',(0,base+.31,tz-td*.63),(.64,.29,.54))
    if shape in ('as9','k9','firtina','roem'):
        m.box('paint',(tw*.30,roof-.40,tz-td*.48),(.60,.68,.43))
        for side in (-1,1):m.box('paint',(side*tw*.48,roof-.45,tz-.20),(.19,.51,1.10))
    if shape=='as9':
        for side in (-1,1):m.box('paint',(side*tw*.48,roof-.20,tz+.30),(.17,.32,1.32))
        m.box('paint',(0,roof+.12,tz-.55),(tw*.64,.24,.70))
    if shape in ('m109a7','m109a5'):
        m.box('paint',(-tw*.40,roof-.33,tz-.32),(.35,.54,1.14))
        if shape=='m109a7':m.box('paint',(tw*.39,roof-.25,tz-.35),(.39,.48,.95))
    for side in (-1,1):
        m.box('paint',(side*tw*.48,roof-.51,tz-.50),(.12,.33,.61))
        m.box('markings',(side*(tw*.48+.069),roof-.51,tz-.50),(.016,.25,.46))
        if not lod:
            for z in (tz-.84,tz-.30,tz+.25):beam(m,'metal_dark',(side*tw*.49,roof-.24,z-.13),(side*tw*.49,roof-.24,z+.13),.027)
    rig.add('Turret','Hull',(0,deck+.10,tz),m,'Y',yaw_degrees=[-180,180])
    # Commander hinge and gunner telescope, not a tank panoramic CITV.
    hatch=Mesh();hx=-tw*.20;hz=tz-.25
    hatch.tube('paint',(hx,roof,hz),(hx,roof+.075,hz),.31,n)
    rig.add('Hatch_Commander','Turret',(hx,roof,hz-.31),hatch,'X')
    sight=Mesh();sight.box('paint',(-.48,roof+.10,tz+.48),(.31,.20,.35));sight.box('glass',(-.48,roof+.11,tz+.67),(.20,.11,.025))
    rig.add('Gunner_Sight','Turret',(-.48,roof,tz+.48),sight)
    mg=Mesh();mx=hx+.46
    mg.tube('metal_dark',(mx,roof,hz),(mx,roof+.28,hz),.055,n);mg.box('metal_dark',(mx,roof+.32,hz+.10),(.14,.16,.44))
    mg.tube('metal_dark',(mx,roof+.33,hz+.27),(mx,roof+.33,hz+.84),.021,n)
    rig.add('Commander_MG','Turret',(mx,roof+.20,hz),mg,'Y')
    ant=Mesh();a=np.array([tw*.27,roof,tz-td*.35]);ant.tube('metal_dark',a,a+[0,.13,0],.047,6);ant.tube('metal_dark',a+[0,.13,0],a+[0,1.10,-.03],.010,4 if lod else 6,r_top=.004)
    rig.add('Antenna_1','Turret',a,ant,'Y')
    # Long artillery barrel, recoil cradle and genuine open brake mouth.
    g=Mesh();p=np.array([0,gy,gz]);tip=overall-L/2;length=tip-gz
    g.box('paint',p,(.64,.48,.73));g.tube('paint',p+[0,.13,-.30],p+[0,.13,.95],.13,n)
    evac=length*.47
    for aa,bb,rr in ((.22,evac-.22,.105),(evac-.22,evac+.26,.148),(evac+.26,length-.43,.090)):
        g.tube('metal_dark',p+[0,0,aa],p+[0,0,bb],rr,n)
    hollow_muzzle(g,[0,gy,tip-.43],[0,gy,tip],max(cal*.66,.10),cal/2,n)
    for zz in (tip-.34,tip-.09):
        # Ring baffles keep the bore open; separate side webs make gas ports.
        hollow_muzzle(g,[0,gy,zz-.04],[0,gy,zz+.04],cal*1.05,cal/2,n)
    for side in (-1,1):g.box('metal_dark',(side*cal*.90,gy,tip-.22),(.065,.15,.31))
    g.remove_duplicates();rig.add('Gun','Turret',p,g,'X',elevation_degrees=[-4,70],positive_elevation_rotation_sign=-1,recoil_axis=[0,0,-1])
    rig.add('Muzzle','Gun',(0,gy,tip),forward='+Z')
    # Rear anchoring spades on the M109 family have their own hinge pivots.
    if shape in ('m109a5','m109a7'):
        for side,label in ((-1,'L'),(1,'R')):
            foot=Mesh();pos=np.array([side*W*.30,1.10,-h+.02])
            beam(foot,'paint',pos,pos+[0,-.62,-.14],.13);foot.box('paint',pos+[0,-.66,-.14],(.52,.14,.31))
            rig.add('Spade_'+label,'Hull',pos,foot,'X')
    ez=h*.48 if s.front_engine else -h+.54
    rig.add('Engine_Deck','Hull',(.48,deck+.04,ez));rig.add('Exhaust','Hull',((-1 if shape=='msta' else 1)*(W/2-.20),deck-.22,ez))
    return rig,s

def artillery__2s19_msta_s(lod=0):
    return spg('artillery__2s19_msta_s','2S19 Msta-S',lod,7.15,3.38,1.48,2.98,6,.36,.90,-.42,2.29,1.05,12.47,'msta',2.78,3.78,.152,
       ['Six T-80-derived road wheels; rear sprockets and five return rollers','very large tall rear fighting turret','long 152 mm 2A64 gun','rear ammunition handling conveyor housing','rear engine deck and forward driver'],source='https://www.gulflink.osd.mil/irfna/irfna_refs/n28en023/firespt.htm')

def artillery__2s3_pzh_2000_krab(lod=0):
    return spg('artillery__2s3_pzh_2000_krab','2S3 / PzH 2000 / Krab',lod,6.97,3.25,1.39,2.62,6,.34,.87,-.66,2.09,.62,8.40,'akatsiya',2.53,2.83,.152,
       ['2S3 Akatsiya selected from combined roster row','Six road wheels','rear-mounted compact rounded-polygon turret','shorter 152 mm D-22 gun with muzzle brake','low front engine hull'],representative='2S3 Akatsiya',approximate=True)

def artillery__as_90_archer(lod=0):
    return spg('artillery__as_90_archer','AS-90 / Archer',lod,7.20,3.30,1.46,2.95,6,.37,.92,-.38,2.26,.92,9.90,'as90',2.78,3.10,.155,
       ['AS90 selected from combined roster row','Six road wheels','large sloping-front box turret','155 mm L/39 gun','forward engine and driver deck'],
       source='https://www.army.mod.uk/learn-and-explore/equipment/artillery-and-air-defence/as90/',representative='AS90',approximate=True)

def artillery__as9_huntsman(lod=0):
    return spg('artillery__as9_huntsman','AS9 Huntsman',lod,7.44,3.40,1.47,2.90,6,.38,.94,-.40,2.27,.96,12.0,'as9',2.83,3.46,.155,
       ['Six-wheel K9-derived chassis','155 mm L/52 barrel','Australian enhanced turret armour','raised roof module and rear air-conditioning housing','long square bustle'],
       source='https://www.defence.gov.au/news-events/news/2023-08-11/self-propelled-howitzers-give-preview')

def artillery__k9_vajra_t(lod=0):
    return spg('artillery__k9_vajra_t','K9 Vajra-T',lod,7.44,3.40,1.46,2.78,6,.38,.94,-.40,2.22,.96,12.0,'k9',2.75,3.34,.155,
       ['Indian K9 derivative','Six road wheels','155 mm L/52 howitzer','angular welded turret with rear cooling housing','low forward engine deck'],source='https://www.larsentoubro.com/defence/')

def artillery__k9a1_thunder(lod=0):
    return spg('artillery__k9a1_thunder','K9A1 Thunder',lod,7.44,3.40,1.46,2.78,6,.38,.94,-.40,2.22,.96,12.0,'k9',2.75,3.34,.155,
       ['Six large road wheels','long L/52 howitzer','K9 welded angular turret','rear ammunition door and side stowage','front engine deck'],source='https://www.hanwhaaerospace.com/eng/business/land/')

def artillery__m109a5(lod=0):
    return spg('artillery__m109a5','M109A5',lod,6.61,3.15,1.43,2.66,7,.31,.82,-.52,2.07,.72,9.12,'m109a5',2.50,2.82,.155,
       ['Seven small road wheels','155 mm M284 L/39 barrel','compact chamfered aluminium turret','large rear ammunition door','paired hinged rear anchoring spades'])

def artillery__m109a5_sh_15(lod=0):
    return spg('artillery__m109a5_sh_15','M109A5 / SH-15',lod,6.61,3.15,1.43,2.66,7,.31,.82,-.52,2.07,.72,9.12,'m109a5',2.50,2.82,.155,
       ['M109A5 selected from combined row','Seven small road wheels','M284 L/39 barrel','rear-mounted chamfered turret','two rear anchoring spades'],representative='M109A5',approximate=True)

def artillery__m109a5_br(lod=0):
    return spg('artillery__m109a5_br','M109A5+ BR',lod,6.61,3.15,1.43,2.69,7,.31,.82,-.52,2.07,.72,9.12,'m109a5',2.50,2.82,.155,
       ['Brazilian upgraded M109A5 configuration','Seven road wheels','155 mm L/39 M284 barrel','rear entry and ammunition port','paired rear spades'],source='https://www.baesystems.com/en-us/product/m109a5-selfpropelled-howitzer')

def artillery__m109a7_paladin(lod=0):
    return spg('artillery__m109a7_paladin','M109A7 Paladin',lod,6.83,3.89,1.49,2.93,7,.35,.86,-.42,2.20,.78,9.75,'m109a7',2.66,3.02,.155,
       ['Seven larger Bradley-derived running-gear wheels','new wide chassis','155 mm M284 gun','Paladin turret side electronics enclosures','two rear anchoring spades'],source='https://www.baesystems.com/en-us/product/m109a7')

def artillery__plz_05(lod=0):
    return spg('artillery__plz_05','PLZ-05',lod,6.92,3.38,1.46,2.98,6,.35,.87,-.36,2.27,1.00,11.60,'plz',2.92,3.72,.155,
       ['Six road wheels','tall angular fighting turret with long bustle','long 155 mm L/52 cannon','rear ammunition access housing','front engine and driver deck'],source='https://eng.mod.gov.cn/')

def artillery__pzh_2000(lod=0):
    return spg('artillery__pzh_2000','PzH 2000',lod,7.90,3.58,1.55,3.05,7,.36,.99,-.37,2.38,1.18,11.70,'pzh',3.12,4.05,.155,
       ['Seven road wheels','very wide angular turret and long ammunition bustle','155 mm L/52 barrel','broad forward hull deck','large rear turret doors'],source='https://knds.com/en/products/systems/pzh-2000')

def artillery__raad_2(lod=0):
    return spg('artillery__raad_2','Raad-2',lod,6.95,3.10,1.43,2.64,6,.35,.87,-.54,2.08,.73,9.20,'raad',2.48,2.92,.155,
       ['Six-wheel Boragh-derived chassis','M109-like turret on a distinct sloped hull','155 mm HM44 gun','front engine compartment','large rear turret door'],source='https://www.diomil.ir/',approximate=True,representative='Raad-2 exterior, approximate publicly documented proportions')

def artillery__roem(lod=0):
    rig,s=truck_howitzer('artillery__roem','Roem',lod,12.20,3.0,3.20,[-4.25,-2.83,-1.40,2.05,3.65],.65,.155,6.90,
       'https://www.elbitamerica.com/news/americas-most-advanced-mobile-tactical-cannon-sigma-on-display-at-ausa-global-force-in-huntsville-alabama',
       family='roem',approximate=True,representative='SIGMA/Roem on Oshkosh 10x10; public exterior dimensions approximated')
    s.features=['Five axle Oshkosh 10x10 truck chassis','armoured forward crew cab','large unmanned enclosed gunhouse',
        '155 mm L/52 gun','automatic-loading bustle and rear anchoring spade'];return rig,s

def artillery__t_155_firtina(lod=0):
    return spg('artillery__t_155_firtina','T-155 Firtina',lod,7.44,3.40,1.46,2.87,6,.38,.94,-.38,2.24,.98,12.0,'firtina',2.83,3.44,.155,
       ['Six-wheel K9-derived chassis','Turkish modified angular turret','155 mm L/52 gun','long bustle with rear cooling enclosure','forward engine deck'],source='https://www.msb.gov.tr/')

def artillery__type_99_sph(lod=0):
    return spg('artillery__type_99_sph','Type 99 SPH',lod,7.10,3.20,1.46,2.91,7,.31,.87,-.46,2.25,.92,11.30,'type99sph',2.68,3.51,.155,
       ['Seven small road wheels','high square Japanese welded turret','155 mm L/52 gun','broad rear ammunition bustle','front engine and driver compartment'],source='https://www.mod.go.jp/gsdf/equipment/ve/')

def k9__k9_thunder(lod=0):
    return spg('k9__k9_thunder','K9 Thunder',lod,7.44,3.40,1.46,2.78,6,.38,.94,-.40,2.22,.96,12.0,'k9',2.75,3.34,.155,
       ['Six large road wheels','long L/52 howitzer','K9 angular welded turret','side stowage and rear ammunition door','forward powerpack'],source='https://www.hanwhaaerospace.com/eng/business/land/')

def artillery__d_30_2s1(lod=0):
    rig,s=artillery__2s1_gvozdika_d_30(lod);s.slug='d_30_2s1';s.name='D-30 / 2S1';return rig,s

def artillery__d_30_2s1_captured(lod=0):
    rig,s=artillery__2s1_gvozdika_d_30(lod);s.slug='d_30_2s1_captured';s.name='D-30 / 2S1 (captured)';return rig,s

def artillery__d_30_m109a5(lod=0):
    rig,s=artillery__m109a5(lod);s.slug='d_30_m109a5';s.name='D-30 / M109A5';s.approximate=True;s.representative='M109A5';s.features.insert(0,'M109A5 selected from combined D-30/M109A5 roster designation');return rig,s

def artillery__d_30_towed(lod=0):
    return towed('artillery__d_30_towed','D-30 (towed)',lod,'d30',SOVIET)

def artillery__d_30_khalifa(lod=0):
    return towed('artillery__d_30_khalifa','D-30 / Khalifa',lod,'d30',SOVIET,True,'D-30 towed howitzer selected from combined D-30/Khalifa designation')

def towedHowitzer__fh70(lod=0):
    return towed('towedHowitzer__fh70','FH70',lod,'fh70','https://www.esercito.difesa.it/equipaggiamenti/artiglieria/artiglieria-terrestre/index.html')

def towedHowitzer__l118_light_gun(lod=0):
    return towed('towedHowitzer__l118_light_gun','L118 Light Gun',lod,'l118','https://www.army.mod.uk/learn-and-explore/equipment/artillery-and-air-defence/105mm-light-gun/')

def towedHowitzer__m777(lod=0):
    return towed('towedHowitzer__m777','M777',lod,'m777','https://www.baesystems.com/en-us/product/m777')

def artillery__caesar(lod=0):
    return truck_howitzer('artillery__caesar','CAESAR',lod,9.50,2.55,2.85,[-3.18,-1.72,3.00],.59,.155,6.35,
       'https://knds.com/en/products/systems/caesar-6x6')

def wheeledHowitzer__caesar(lod=0):
    rig,s=artillery__caesar(lod);s.slug='wheeledHowitzer__caesar';return rig,s

def wheeledHowitzer__sh_15(lod=0):
    return truck_howitzer('wheeledHowitzer__sh_15','SH-15',lod,10.50,2.65,2.95,[-3.54,-1.91,3.30],.61,.155,6.75,
       'https://eng.mod.gov.cn/',family='sh15')

def wheeledHowitzer__pcl_181(lod=0):
    return truck_howitzer('wheeledHowitzer__pcl_181','PCL-181',lod,10.50,2.65,2.95,[-3.54,-1.91,3.30],.61,.155,6.75,
       'https://eng.mod.gov.cn/',family='pcl181')

def artillery__sh_15_d_30(lod=0):
    rig,s=wheeledHowitzer__sh_15(lod);s.slug='artillery__sh_15_d_30';s.name='SH-15 / D-30';s.approximate=True;s.representative='SH-15 truck-mounted howitzer';return rig,s

def wheeledHowitzer__type_19_howitzer(lod=0):
    return truck_howitzer('wheeledHowitzer__type_19_howitzer','Type 19 Howitzer',lod,11.30,2.50,2.95,[-3.84,-2.30,1.87,3.55],.59,.155,6.65,
       'https://www.mod.go.jp/gsdf/equipment/ve/',family='type19')

def wheeledHowitzer__2s43_malva(lod=0):
    return truck_howitzer('wheeledHowitzer__2s43_malva','2S43 Malva',lod,11.80,2.75,3.0,[-3.95,-2.30,2.02,3.81],.64,.152,6.70,
       'https://rostec.ru/',family='malva')

def wheeledHowitzer__archer(lod=0):
    return truck_howitzer('wheeledHowitzer__archer','Archer',lod,11.75,3.0,3.18,[-3.70,-1.91,3.56],.72,.155,7.04,
       'https://www.baesystems.com/en/product/archer',family='archer',approximate=True,representative='Archer on Volvo A30 6x6 carrier; articulated chassis shown straight')

def artillery__sh_5_palmaria(lod=0):
    return spg('artillery__sh_5_palmaria','SH-5 / Palmaria',lod,7.65,3.35,1.49,2.80,7,.34,.94,-.42,2.22,.97,10.91,'palmaria',2.77,3.37,.155,
      ['Palmaria selected from combined designation','Seven OF-40-derived road wheels','broad 155 mm L/41 turret','large rear ammunition bustle','rear engine hull'],
      source='https://www.leonardo.com/',representative='Palmaria 155 mm self-propelled howitzer',approximate=True)

def artillery__m1989_koksan(lod=0):
    s=Spec('m1989_koksan','M1989 Koksan',9.0,3.27,1.43,2.0,6,.40,1.07,-2.72,2.24,-2.18,12.4,'koksan',
      ['Six road wheels and front sprockets','170 mm long open-mounted gun','low forward crew compartment',
       'rear trunnion support with narrow traverse','onboard ammunition side lockers','wide rear recoil spade'],
      'https://cgsc.contentdm.oclc.org/digital/api/collection/p4013coll11/id/2089/download',
      caliber=.170,front_engine=True,approximate=True,representative='M1989 Koksan; public exterior dimensions approximated',skirts=0)
    rig=Rig(lod);m=Mesh();h=s.length/2;n=6 if lod else 12
    profile_hull(m,'paint',[(h-.28,.50,1.10),(h,1.15,1.23),(h-1.70,1.43,1.25),(-h+.12,1.43,1.24),(-h,.65,1.14)])
    for side in (-1,1):
        m.box('paint',(side*1.34,1.35,0),(.52,.13,8.8))
        m.box('paint',(side*.76,1.64,2.85),(.96,.73,2.20))
        m.box('glass',(side*.76,1.80,3.97),(.62,.28,.035))
        m.box('paint',(side*1.02,1.70,-.62),(.55,.54,3.03))
        m.box('markings',(side*1.311,1.71,-.80),(.015,.25,.58))
        if not lod:
            for z in np.linspace(-1.74,.54,5):m.box('metal_dark',(side*1.31,1.92,z),(.025,.025,.12))
    rig.add('Hull',rig.root,(0,0,0),m);running_gear(rig,s,lod)
    cradle=Mesh();cradle.tube('metal_dark',(0,1.44,-2.72),(0,1.69,-2.72),.61,n)
    for side in (-1,1):
        beam(cradle,'paint',(side*.43,1.63,-3.05),(side*.43,2.24,-2.18),.23)
        cradle.tube('metal_dark',(side*.30,2.24,-2.18),(side*.55,2.24,-2.18),.17,n)
    rig.add('Turret','Hull',(0,1.61,-2.72),cradle,'Y',yaw_degrees=[-8,8])
    artillery_barrel(rig,'Turret',(0,2.24,-2.18),s.overall_length-s.length/2,.170,lod)
    spade=Mesh();spade.box('paint',(0,1.29,-4.57),(2.62,1.11,.17))
    for side in (-1,1):beam(spade,'paint',(side*.70,.88,-4.28),(side*.70,1.53,-4.57),.16)
    rig.add('Spade','Hull',(0,1.0,-4.28),spade,'X')
    rig.add('Engine_Deck','Hull',(.65,2.02,2.92));rig.add('Exhaust','Hull',(1.37,1.57,2.56))
    return rig,s

def wheeled_direct(slug,name,lod,L,W,H,axles,r,tw,th,td,barrel,cal,style,source):
    s=ArmourSpec(slug,name,L,W,H,'wheeled',len(axles),r,style,'direct',
       [str(len(axles)*2)+' wheel drive','low '+style+' hull with '+('front' if style=='type16' else 'rear')+' engine',
        str(round(cal*1000))+' mm direct-fire gun','separate Y turret ring and X trunnion','gunner sight and commander hatch'],
       source,front_engine=style=='type16',axle_z=axles,turret_z=-.22)
    rig=Rig(lod);m=Mesh();h=L/2;half=W/2-.16;n=6 if lod else 12
    profile_hull(m,'paint',[(h-.18,.47,half*.75),(h,H*.62,half*.91),(h*.38,H,half*.87),
       (-h+.12,H,half*.91),(-h,.61,half),(-h+.18,.47,half*.84)])
    for side in (-1,1):
        for z in axles:m.box('paint',(side*(W/2-.20),r*1.97,z),(.48,.10,r*2.08))
        m.box('paint',(side*(W/2-.24),H-.18,-.62),(.38,.29,.64));m.box('markings',(side*(W/2-.04),H-.18,-.62),(.018,.23,.48))
        m.box('paint',(side*half*.78,H*.60,h-.02),(.24,.19,.20));m.box('glass',(side*half*.78,H*.60,h+.095),(.16,.12,.025))
    m.box('paint',(-.49,H+.045,h*.37),(.57,.09,.62));m.box('glass',(-.49,H+.12,h*.37+.22),(.37,.07,.12))
    ez=h*.34 if s.front_engine else -h+.70;ex=.55 if s.front_engine else 0
    for z in np.linspace(ez-.40,ez+.40,3 if lod else 10):m.box('metal_dark',(ex,H+.026,z),(.69 if s.front_engine else 1.19,.035,.047))
    rig.add('Hull',rig.root,(0,0,0),m);mobility(rig,s,lod)
    y=H+.11;z=-.22;t=Mesh();t.tube('metal_dark',(0,H+.01,z),(0,y+.03,z),tw*.36,n)
    front=.50 if style!='cascavel' else .42
    fp=[(-tw*.26,td*front),(tw*.26,td*front),(tw*.50,td*.15),(tw*.47,-td*.44),(-tw*.47,-td*.44),(-tw*.50,td*.15)]
    shrink=.74 if style=='cascavel' else .84
    loft(t,'paint',[[(x,y,z+zz) for x,zz in fp],[(x*shrink,y+th,z+zz*.86) for x,zz in fp]])
    for side in (-1,1):t.box('markings',(side*(tw*.47+.012),y+th*.49,z-.42),(.017,.22,.40))
    t.tube('paint',(-tw*.18,y+th,z-.25),(-tw*.18,y+th+.07,z-.25),.29,n)
    t.box('paint',(.50,y+th+.10,z+.27),(.33,.22,.40));t.box('glass',(.50,y+th+.11,z+.484),(.22,.13,.025))
    rig.add('Turret','Hull',(0,y,z),t,'Y')
    gy=y+th*.52;gz=z+td*.31;artillery_barrel(rig,'Turret',(0,gy,gz),gz+barrel,cal,lod)
    ant=Mesh();a=np.array([-tw*.27,y+th,z-.70]);ant.tube('metal_dark',a,a+[0,1.0,0],.012,4 if lod else 6)
    rig.add('Antenna_1','Turret',a,ant,'Y');rig.add('Engine_Deck','Hull',(ex,H+.04,ez));rig.add('Exhaust','Hull',(W/2-.17,H*.76,ez))
    return rig,s

def directFire__amx_10_rc(lod=0):
    return wheeled_direct('directFire__amx_10_rc','AMX-10 RC',lod,6.24,2.78,1.55,[-1.91,-.12,1.94],.53,2.35,.65,2.75,3.38,.105,'amx10',
       'https://www.defense.gouv.fr/terre/nos-materiels/nos-equipements-terre/nos-vehicules/amx-10-rc')

def directFire__ee_9_cascavel(lod=0):
    return wheeled_direct('directFire__ee_9_cascavel','EE-9 Cascavel',lod,5.20,2.60,1.47,[-1.64,-.63,1.68],.49,1.61,.59,1.77,1.88,.090,'cascavel',
       'https://www.eb.mil.br/')

def directFire__type_16_mcv(lod=0):
    return wheeled_direct('directFire__type_16_mcv','Type 16 MCV',lod,8.45,2.98,1.65,[-2.82,-1.28,1.26,2.81],.57,2.47,.69,3.21,4.38,.105,'type16',
       'https://www.mod.go.jp/gsdf/equipment/ve/')

def directFire__harimau(lod=0):
    s=Spec('harimau','Harimau',6.95,3.30,1.42,2.48,6,.36,.87,-.04,2.00,1.23,9.10,'harimau',
      ['Six road wheels and rear sprockets','light Kaplan MT hull','Cockerill 3105 turret','long 105 mm gun','large angular autoloader bustle'],
      'https://www.pindad.com/harimau',caliber=.105)
    b=[(-.36,1.30),(.36,1.30),(1.27,.57),(1.29,-1.49),(1.03,-1.86),(-1.03,-1.86),(-1.29,-1.49),(-1.27,.57)]
    t=[(-.34,.83),(.34,.83),(1.03,.34),(1.11,-1.46),(.92,-1.76),(-.92,-1.76),(-1.11,-1.46),(-1.03,.34)]
    def details(h,m,s,l):m.box('paint',(0,2.16,-1.64),(2.01,.50,.54))
    return finish(s,b,t,lod,details)

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('artillery__','k9__','towedHowitzer__','wheeledHowitzer__','directFire__')) and callable(f)}

def save(slug,builder=None):
    from validate_p3_artillery import validate
    launcher_builder=builder is not None;builder=builder or BUILDERS[slug]
    a,s=builder(0);b,s1=builder(1);assert asdict(s)==asdict(s1)
    spec=asdict(s);tank=isinstance(s,Spec)
    if tank:spec.update(mobility='tracked',weapon='howitzer',family=s.shape,equipment='',axle_z=[])
    height=s.deck if tank else s.roof
    c=Mesh();c.box('metal_dark',(0,height/2,0),(s.width,height,s.length))
    path=ART/'vehicles'/f'{slug}.glb'
    burnt=make_wreck(b,s) if tank else armour_wreck(b,replace(s,weapon='') if s.mobility=='towed' else s)
    write_glb(path,[a,b],burnt,c,{'scene_name':s.name,'vehicle':slug,'priority':'P3','spec':spec,
        'units':'metres','up':'+Y','front':'+Z','detached_turret':s.mobility!='towed' if not tank else True,'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}})
    entry,tree=validate(path);entry['notes']=entry['notes'].replace('generate_p2_armour.py + armour_parts.py','generate_p3_artillery.py')
    if launcher_builder:entry['notes']+=' Launcher authored by generate_p3_launchers.py + artillery_parts.py. Numbered Muzzle_N markers at every tube front in both LODs; Launcher X elevation under Turntable Y. Independent marker pose checks included.'
    (Path(__file__).parent/'reports'/f'{slug}.node-tree.txt').write_text(tree,encoding='utf-8')
    print(tree);print('PASS',slug,entry['triangles'],flush=True);return entry

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
    manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
