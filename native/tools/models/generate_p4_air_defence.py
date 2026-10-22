"""Original P4 air defence and radar exteriors. Real carriers and mounts.

Each exact roster designation has an explicit builder. Ambiguous combined rows
name one representative, and uncertain public proportions are flagged. No
Blender, source mesh, textures, baked colours, lights or national insignia.
"""
from dataclasses import asdict
from pathlib import Path
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,write_glb,merge_mesh
from armour_parts import wreck
from air_defence_parts import carrier,gun_mount,sam,radar_carrier,radar
from generate_p1_tanks import beam

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={
 'weg':'https://cgsc.contentdm.oclc.org/digital/api/collection/p4013coll11/id/2089/download',
 'gepard':'https://www.bundeswehr.de/',
 'skyranger':'https://www.rheinmetall.com/en/products/air-defence-systems/mobile-air-defence-skyranger',
 'korkut':'https://www.fnss.com.tr/en/products/acv-ad-air-defence-system-platform',
 'avenger':'https://www.army.mil/',
 'nasams':'https://www.kongsberg.com/kda/what-we-do/air-defence/nasams/',
 'patriot':'https://www.rtx.com/raytheon/what-we-do/integrated-air-and-missile-defense/patriot',
 'thaad':'https://www.lockheedmartin.com/en-us/products/thaad.html',
 'iris':'https://www.diehl.com/defence/en/products/air-defence-systems/',
 'aster':'https://www.eurosam.com/ground-based-systems/',
 'hisar':'https://www.aselsan.com/en/defence/product/195/hisar',
 'rbs':'https://www.saab.com/products/rbs-70-ng',
 'japan':'https://www.mod.go.jp/gsdf/equipment/ve/',
 'rafael':'https://www.rafael.co.il/',
 'china':'https://eng.mod.gov.cn/',
 'hanwha':'https://www.hanwhaaerospace.com/eng/business/land/',
 'cobra':'https://www.thalesgroup.com/en/markets/defence-and-security/land-forces/weapon-systems/cobra',
 'tpq':'https://www.lockheedmartin.com/en-us/products/tpq-53.html',
 'swathi':'https://www.drdo.gov.in/drdo/weapon-locating-radar-swathi',
 'leonidas':'https://www.epirusinc.com/leonidas',
}
# L/W/body roof, mobility, wheel/axle count, radius, canonical scale, engine,
# construction family, axle Zs (tracked defaults retain the shared path).
CARRIERS={
 'tunguska':(7.93,3.25,1.50,'tracked',6,.35,.96,True,'engineering',[]),
 'gepard':(7.68,3.42,1.42,'tracked',7,.34,.98,False,'engineering',[]),
 'type87':(6.70,3.18,1.40,'tracked',5,.38,.88,False,'engineering',[]),
 'shilka':(6.54,3.13,1.42,'tracked',6,.30,.82,False,'engineering',[]),
 'sidam':(4.86,2.69,1.83,'tracked',5,.28,.69,True,'engineering',[]),
 'biho':(6.77,3.0,1.55,'tracked',6,.31,.82,True,'engineering',[]),
 'korkut':(7.0,3.90,1.72,'tracked',6,.34,.88,True,'engineering',[]),
 'pgz':(6.90,3.27,1.48,'tracked',6,.35,.87,True,'engineering',[]),
 'stormer':(5.27,2.76,1.65,'tracked',6,.27,.68,True,'engineering',[]),
 'avenger':(4.83,2.16,1.85,'wheeled',2,.45,1,True,'humvee',[-1.48,1.48]),
 'crotale':(6.50,2.50,1.10,'wheeled',2,.50,1,False,'aa_trailer',[-1.70,-.40]),
 'mshorad':(6.95,2.72,2.01,'wheeled',4,.54,1,True,'stryker',[-2.38,-.90,.89,2.35]),
 'boxer':(7.93,2.99,2.13,'wheeled',4,.57,1,True,'boxer',[-2.75,-1.16,1.10,2.73]),
 'pantsir':(10.50,2.75,3.0,'wheeled',4,.63,1,True,'truck',[-3.45,-1.76,1.82,3.32]),
 'gdf':(5.30,2.70,.70,'wheeled',1,.45,1,False,'gun_trailer',[0]),
 'zu23':(4.60,2.30,.64,'wheeled',1,.40,1,False,'gun_trailer',[0]),
 'technical':(5.80,2.05,1.95,'wheeled',2,.43,1,True,'truck',[-1.70,1.60]),
 'rbstruck':(6.90,2.40,2.60,'wheeled',2,.53,1,True,'truck',[-2.10,2.10]),
 'tripod':(2.40,2.0,.65,'static',0,0,1,False,'stand',[]),
 'truck6':(9.40,2.55,2.90,'wheeled',3,.60,1,True,'truck',[-3.10,-1.48,2.98]),
 'radar6':(8.50,2.50,2.78,'wheeled',3,.57,1,True,'truck',[-2.74,-1.15,2.64]),
 'radar8':(10.50,2.80,3.0,'wheeled',4,.64,1,True,'truck',[-3.46,-1.81,1.72,3.35]),
 'radartrack':(7.80,3.30,1.75,'tracked',7,.34,.96,True,'engineering',[]),
}
# Same physical module layout as P3: L/W/cab roof/axles/radius/tracks/scale,
# bonnet/cab length, columns/rows/pods, canister diameter/length, box/jacks/family.
SAM_CONFIGS={
 'akash':(7.0,3.46,1.48,6,.36,True,.87,0,0,3,1,1,.35,5.80,False,False,'sam_akash'),
 'bavar':(13.0,3.20,3.10,[-4.60,-3.0,-1.43,2.59,4.30],.67,False,1,0,2.50,2,2,1,.58,7.0,True,True,'sam_bavar'),
 'cheongung':(11.30,2.80,3.0,[-3.72,-2.03,1.89,3.60],.65,False,1,0,2.35,4,2,1,.40,4.80,True,True,'sam_cheongung'),
 'david':(11.70,2.90,3.0,[-3.85,-2.10,1.98,3.72],.65,False,1,0,2.40,4,3,1,.25,5.10,True,True,'sam_david'),
 'hisaro':(9.20,2.50,2.90,[-3.01,-1.44,2.88],.61,False,1,0,2.22,3,2,1,.35,4.20,True,True,'sam_hisaro'),
 'hq9':(12.0,3.0,3.10,[-3.94,-2.15,2.01,3.82],.66,False,1,0,2.52,2,2,1,.70,7.0,False,True,'sam_hq9'),
 'kn06':(10.80,2.80,2.98,[-3.55,-1.78,3.41],.64,False,1,0,2.35,3,1,1,.65,7.50,False,True,'sam_kn06'),
 'nasams':(6.80,2.60,1.60,[-2.10,-.90],.50,False,1,0,2.10,3,2,1,.30,3.80,True,True,'nasams_trailer'),
 'pac3':(8.80,2.60,1.70,[-3.0,-1.50],.55,False,1,0,2.10,4,4,1,.25,5.60,True,True,'patriot_trailer'),
 'pac3mse':(9.20,2.60,1.70,[-3.12,-1.57],.55,False,1,0,2.10,3,4,1,.32,6.0,True,True,'patriot_trailer'),
 'irist':(10.30,2.55,2.90,[-3.38,-1.78,1.63,3.26],.62,False,1,0,2.32,4,2,1,.28,4.0,True,True,'sam_irist'),
 's400':(13.0,3.0,3.20,[-4.27,-2.35,2.21,4.14],.68,False,1,0,2.62,4,1,1,.65,8.0,False,True,'sam_s400'),
 'aster':(11.0,2.80,2.92,[-3.62,-1.95,1.82,3.50],.64,False,1,0,2.35,4,2,1,.50,6.0,True,True,'sam_aster'),
 'camm':(11.50,2.60,3.0,[-3.79,-2.06,1.93,3.66],.64,False,1,0,2.40,4,2,1,.25,3.80,True,True,'sam_camm'),
 'spyder':(9.40,2.50,2.90,[-3.09,-1.48,2.96],.61,False,1,0,2.25,2,2,1,.35,4.0,True,True,'sam_spyder'),
 'type03':(11.0,2.48,2.90,[-3.61,-1.95,1.83,3.49],.63,False,1,0,2.35,3,2,1,.40,5.40,True,True,'sam_type03'),
 'arrow3':(12.80,3.20,3.10,[-4.20,-2.31,2.16,4.06],.68,False,1,0,2.58,3,2,1,.80,8.50,False,True,'sam_arrow'),
 'hq19':(14.0,3.20,3.20,[-4.98,-3.36,-1.67,2.83,4.81],.70,False,1,0,2.65,3,2,1,.70,8.50,False,True,'sam_hq19'),
 's500':(14.0,3.10,3.20,[-4.98,-3.36,-1.67,2.83,4.81],.70,False,1,0,2.65,2,1,1,.80,10.0,False,True,'sam_s500'),
 'thaad':(12.0,2.90,3.10,[-3.95,-2.17,2.02,3.82],.65,False,1,0,2.50,4,2,1,.38,6.20,True,True,'sam_thaad'),
 'hisara':(7.0,3.20,1.65,6,.34,True,.87,0,0,2,2,1,.25,3.50,True,False,'sam_hisara'),
 'irissls':(7.80,2.40,2.50,[-2.48,-1.02,2.41],.52,False,1,0,2.0,2,2,1,.28,3.60,True,True,'sam_irissls'),
 'type11':(8.60,2.48,2.80,[-2.82,-1.30,2.70],.60,False,1,0,2.15,2,2,1,.28,3.30,True,True,'sam_type11'),
 'irondome':(4.0,3.0,1.0,[],0,False,1,0,2.10,4,5,1,.25,3.10,True,False,'irondome_static'),
}

def aa(slug,name,lod,body,style,search,source='weg',approximate=False,representative=''):
    rig,s=carrier(slug,name,lod,CARRIERS[body],REF.get(source,source),approximate,representative)
    rig,s=gun_mount(rig,s,lod,style,search);s.features[0]=name+' anti-aircraft mounting';return rig,s

def sam_model(slug,name,lod,key,source='weg',approximate=False,representative=''):
    rig,s=sam(slug,name,lod,SAM_CONFIGS[key],REF.get(source,source),approximate,representative)
    if key=='akash':
        # Exposed winged missiles, not hollow launch pipes; rear-drive T-72 hull.
        s.front_engine=False
        for p in rig.parts:
            if p['name'].startswith(('Sprocket_','Idler_')):
                old=p['pivot'][2];p['pivot'][2]=-old;p['mesh'].shift([0,0,-2*old]);rig.pivots[p['name']]=p['pivot']
        m=Mesh();tips=[];rear=-s.length/2+.30;n=6 if lod else 12
        original=s.details['muzzle_positions']
        for i,tip in enumerate(original):
            p=np.array(tip);p[0]=(i-1)*.95;tips.append(p.tolist());base=p-[0,0,5.80]
            m.tube('paint',base+[0,0,.12],p-[0,0,.63],.175,n)
            m.tube('paint',p-[0,0,.63],p,.175,n,r_top=.002)
            m.box('metal_dark',((base+p)/2)-[0,.24,0],(.20,.10,5.68))
            for z in (base[2]+1.10,p[2]-1.50):
                for angle in (0,math.pi/2,math.pi,math.pi*1.5):
                    R=np.array([[math.cos(angle),-math.sin(angle),0],[math.sin(angle),math.cos(angle),0],[0,0,1]])
                    q=np.array([[.12,0,z-.45],[.53,0,z-.06],[.12,0,z+.34]])
                    a=q.copy();a[:,1]=-.018;b=q.copy();b[:,1]=.018
                    vertices=np.vstack((a,b));vertices[:,:2]=vertices[:,:2]@R[:2,:2].T+p[:2]
                    m.solid('paint',vertices,[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
        for p in rig.parts:
            if p['name']=='Launcher':p['mesh']=m
            elif p['name'].startswith('Muzzle_'):
                i=int(p['name'][7:]);p['pivot']=np.array(tips[i]);rig.pivots[p['name']]=p['pivot']
            elif p['name']=='Engine_Deck':p['pivot']=np.array([0,1.49,-s.length*.35]);rig.pivots[p['name']]=p['pivot']
        s.details['muzzle_positions']=tips;s.features=['Six-wheel rear-drive Akash carrier','three exposed Akash missiles','four cruciform fins at two body stations','elevating launch rails']
    if key=='hisara':
        radar(rig,'Hull',(0,s.roof,-s.length*.29),lod,'array',1.05,.72);s.details['radar']=True
    return rig,s

def radar_model(slug,name,lod,key,source,width,height,approximate=False,representative=''):
    return radar_carrier(slug,name,lod,CARRIERS[key],REF.get(source,source),width,height,'array',approximate,representative)

def laser_model(slug,name,lod):
    rig,s=aa(slug,name,lod,'truck6','rbs70',False,'rafael',True,'Iron Beam optical-head truck; public exterior proportions approximated')
    m=Mesh();p=rig.pivots['Launcher'];n=6 if lod else 16
    m.box('paint',p+[0,-.25,-.12],(.85,.56,.72));m.tube('paint',p,p+[0,0,.70],.44,n)
    m.tube('glass',p+[0,0,.71],p+[0,0,.73],.39,n)
    tip=p+[0,0,.73]
    for part in rig.parts:
        if part['name']=='Launcher':part['mesh']=m
        elif part['name']=='Muzzle_0':part['pivot']=tip;rig.pivots[part['name']]=tip
    s.details['muzzle_positions']=[tip.tolist()];s.details['beam_emitter']=True
    s.features=['Six-wheel optical laser carrier','large glass beam aperture','Y beam director turntable and X optical head hinge','battery radar is separate']
    return rig,s

def save(slug,output_dir=None,tree_dir=None,print_tree=True):
    from validate_p3_artillery import validate
    a,s=BUILDERS[slug](0);b,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
    c=Mesh();c.box('metal_dark',(0,s.roof/2,0),(s.width,s.roof,s.length));path=(Path(output_dir) if output_dir else ART/'vehicles')/f'{slug}.glb'
    write_glb(path,[a,b],wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P4','spec':asdict(s),
        'units':'metres','up':'+Y','front':'+Z','detached_turret':False,'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}})
    entry,tree=validate(path)
    if s.details.get('radar'):
        from vehicle_parts import read_glb,walk_nodes
        doc,_=read_glb(path);by={p:(n,M) for p,n,M,v in walk_nodes(doc,canonical=True)}
        for lod in (0,1):
            sensors=[(p,n,M) for p,(n,M) in by.items() if p.startswith(f'LOD{lod}/') and n.get('extras',{}).get('canonical_part')=='Radar']
            assert len(sensors)==1 and sensors[0][1]['extras']['rotation_axis']=='Y'
    entry['notes']='Original P4 Python exterior: generate_p4_air_defence.py + air_defence_parts.py and approved vehicle_parts.py. No Blender, source mesh, baked colours, textures or insignia. White PBR roles, metre UVs except the unchanged canonical track loop. All named rotation axes are empty hinges with mesh children. Muzzle_N identifies every barrel/canister or beam aperture in both LODs. Separate battery radars are not invented on a launcher vehicle; fixed AESA panels identify fixed_to_turret. Approximate fields identify uncertain carriers, public dimensions or combined roster representatives. Hidden LOD1, static burnt Wreck and hull Collision_Box.'
    entry['has_radar']=bool(s.details.get('radar'));entry['validation']['radar_axes_checked']=bool(s.details.get('radar'))
    tree_path=(Path(tree_dir) if tree_dir else Path(__file__).parent/'reports')/f'{slug}.node-tree.txt'
    tree_path.write_text(tree,encoding='utf-8')
    if print_tree:print(tree)
    print('PASS',slug,entry['triangles'],flush=True);return entry

# Explicit designation builders follow below.

def aaVehicle__2k22_tunguska(lod=0):
    return aa('aaVehicle__2k22_tunguska', '2K22 Tunguska', lod, 'tunguska', 'tunguska', True, 'weg', False, '')

def aaVehicle__35_mm_air_defence_gun(lod=0):
    return aa('aaVehicle__35_mm_air_defence_gun', '35 mm air defence gun', lod, 'gdf', 'gdf', False, 'skyranger', True, 'Oerlikon GDF twin-35 mm towed gun')

def aaVehicle__avenger_shahine(lod=0):
    return aa('aaVehicle__avenger_shahine', 'Avenger / Shahine', lod, 'avenger', 'avenger', False, 'avenger', True, 'AN/TWQ-1 Avenger')

def aaVehicle__avenger_sinai_23(lod=0):
    return aa('aaVehicle__avenger_sinai_23', 'Avenger / Sinai-23', lod, 'avenger', 'avenger', False, 'avenger', True, 'AN/TWQ-1 Avenger')

def aaVehicle__crotale_ng(lod=0):
    return aa('aaVehicle__crotale_ng', 'Crotale NG', lod, 'crotale', 'crotale', True, 'https://www.artillerie.asso.fr/cesane/Texte/DocumentsMemorial/5.67.CROTALE_NG_%28FR%29.pdf', True, 'French trailer-mounted Crotale NG fire unit; public exterior proportions approximated')

def aaVehicle__gepard_strela_10(lod=0):
    return aa('aaVehicle__gepard_strela_10', 'Gepard / Strela-10', lod, 'gepard', 'gepard', True, 'gepard', True, 'Gepard 1A2')

def aaVehicle__gepard_1a2(lod=0):
    return aa('aaVehicle__gepard_1a2', 'Gepard 1A2', lod, 'gepard', 'gepard', True, 'gepard', False, '')

def aaVehicle__iron_dome_battery(lod=0):
    return sam_model('aaVehicle__iron_dome_battery', 'Iron Dome battery', lod, 'irondome', 'rafael', True, 'Twenty-Tamir Iron Dome launch unit; public exterior dimensions approximated')

def aaVehicle__k30_biho_ii(lod=0):
    return aa('aaVehicle__k30_biho_ii', 'K30 Biho II', lod, 'biho', 'biho', True, 'hanwha', True, 'K30 Biho Hybrid, two 30 mm guns and four Shingung canisters')

def aaVehicle__korkut(lod=0):
    return aa('aaVehicle__korkut', 'Korkut', lod, 'korkut', 'korkut', True, 'korkut', False, '')

def aaVehicle__ly_80_oerlikon(lod=0):
    return aa('aaVehicle__ly_80_oerlikon', 'LY-80 / Oerlikon', lod, 'gdf', 'gdf', False, 'skyranger', True, 'Oerlikon GDF twin-35 mm towed gun')

def aaVehicle__m_shorad(lod=0):
    return aa('aaVehicle__m_shorad', 'M-SHORAD', lod, 'mshorad', 'mshorad', True, 'avenger', False, '')

def aaVehicle__m1992_30_mm(lod=0):
    return aa('aaVehicle__m1992_30_mm', 'M1992 30 mm', lod, 'shilka', 'm1992', True, 'weg', True, 'M1992 twin-30 mm tracked SPAAG exterior, public configuration approximated')

def aaVehicle__pantsir_s1(lod=0):
    return aa('aaVehicle__pantsir_s1', 'Pantsir-S1', lod, 'pantsir', 'pantsir', True, 'weg', False, '')

def aaVehicle__pgz_09(lod=0):
    return aa('aaVehicle__pgz_09', 'PGZ-09', lod, 'pgz', 'korkut', True, 'china', False, '')

def aaVehicle__rbs_70_vehicle(lod=0):
    return aa('aaVehicle__rbs_70_vehicle', 'RBS 70 (vehicle)', lod, 'rbstruck', 'rbs70', False, 'rbs', True, 'RBS 70 on representative 4x4 military truck')

def aaVehicle__sidam_25(lod=0):
    return aa('aaVehicle__sidam_25', 'SIDAM 25', lod, 'sidam', 'sidam', False, 'weg', False, '')

def aaVehicle__skyranger_30(lod=0):
    return aa('aaVehicle__skyranger_30', 'Skyranger 30', lod, 'boxer', 'skyranger', True, 'skyranger', False, '')

def aaVehicle__skyshield_rbs_70(lod=0):
    return aa('aaVehicle__skyshield_rbs_70', 'Skyshield / RBS 70', lod, 'tripod', 'rbs70', False, 'rbs', True, 'RBS 70 stand-mounted fire unit')

def aaVehicle__stormer_hvm(lod=0):
    return aa('aaVehicle__stormer_hvm', 'Stormer HVM', lod, 'stormer', 'stormer', False, 'weg', False, '')

def aaVehicle__type_87_spaag(lod=0):
    return aa('aaVehicle__type_87_spaag', 'Type 87 SPAAG', lod, 'type87', 'type87', True, 'japan', False, '')

def aaVehicle__zsu_23_4_shilka(lod=0):
    return aa('aaVehicle__zsu_23_4_shilka', 'ZSU-23-4 Shilka', lod, 'shilka', 'shilka', True, 'weg', False, '')

def aaVehicle__zu_23_2(lod=0):
    return aa('aaVehicle__zu_23_2', 'ZU-23-2', lod, 'zu23', 'zu23', False, 'weg', False, '')

def aaVehicle__zu_23_2_technical(lod=0):
    return aa('aaVehicle__zu_23_2_technical', 'ZU-23-2 (technical)', lod, 'technical', 'zu23', False, 'weg', True, 'ZU-23-2 on a generic unarmoured 4x4 pickup')

def aaVehicle__zu_23_2_saqr_358(lod=0):
    return aa('aaVehicle__zu_23_2_saqr_358', 'ZU-23-2 / Saqr (358)', lod, 'zu23', 'zu23', False, 'weg', True, 'ZU-23-2 towed gun')

def samLauncher__akash(lod=0):
    return sam_model('samLauncher__akash', 'Akash', lod, 'akash', 'weg', False, '')

def samLauncher__bavar_373(lod=0):
    return sam_model('samLauncher__bavar_373', 'Bavar-373', lod, 'bavar', 'weg', True, 'Four-canister Bavar-373 ten-wheel TEL, exterior proportions approximated')

def samLauncher__cheongung_ii(lod=0):
    return sam_model('samLauncher__cheongung_ii', 'Cheongung II', lod, 'cheongung', 'hanwha', False, '')

def samLauncher__david_s_sling(lod=0):
    return sam_model('samLauncher__david_s_sling', "David's Sling", lod, 'david', 'rafael', True, 'Twelve-canister David Sling launcher on representative 8x8 carrier')

def samLauncher__hisar_o(lod=0):
    return sam_model('samLauncher__hisar_o', 'Hisar-O', lod, 'hisaro', 'hisar', False, '')

def samLauncher__hq_9_p(lod=0):
    return sam_model('samLauncher__hq_9_p', 'HQ-9/P', lod, 'hq9', 'china', False, '')

def samLauncher__hq_9b(lod=0):
    return sam_model('samLauncher__hq_9b', 'HQ-9B', lod, 'hq9', 'china', False, '')

def samLauncher__kn_06_pongae_5(lod=0):
    return sam_model('samLauncher__kn_06_pongae_5', 'KN-06 (Pongae-5)', lod, 'kn06', 'weg', True, 'KN-06 three-canister 6x6 carrier, publicly documented exterior approximated')

def samLauncher__nasams(lod=0):
    return sam_model('samLauncher__nasams', 'NASAMS', lod, 'nasams', 'nasams', False, '')

def samLauncher__patriot_iris_t_nasams(lod=0):
    return sam_model('samLauncher__patriot_iris_t_nasams', 'Patriot / IRIS-T / NASAMS', lod, 'pac3', 'patriot', True, 'M901 Patriot PAC-3 launcher trailer')

def samLauncher__patriot_pac_3(lod=0):
    return sam_model('samLauncher__patriot_pac_3', 'Patriot PAC-3', lod, 'pac3', 'patriot', False, '')

def samLauncher__patriot_pac_3_mse(lod=0):
    return sam_model('samLauncher__patriot_pac_3_mse', 'Patriot PAC-3 MSE', lod, 'pac3mse', 'patriot', False, '')

def samLauncher__rbs_70_ng_battery(lod=0):
    return aa('samLauncher__rbs_70_ng_battery', 'RBS 70 NG battery', lod, 'tripod', 'rbs70', False, 'rbs', False, '')

def samLauncher__s_300vm_iris_t_slm(lod=0):
    return sam_model('samLauncher__s_300vm_iris_t_slm', 'S-300VM / IRIS-T SLM', lod, 'irist', 'iris', True, 'IRIS-T SLM eight-round truck launcher')

def samLauncher__s_400(lod=0):
    return sam_model('samLauncher__s_400', 'S-400', lod, 's400', 'weg', False, '')

def samLauncher__samp_t_ng(lod=0):
    return sam_model('samLauncher__samp_t_ng', 'SAMP/T NG', lod, 'aster', 'aster', False, '')

def samLauncher__sky_sabre_camm(lod=0):
    return sam_model('samLauncher__sky_sabre_camm', 'Sky Sabre (CAMM)', lod, 'camm', 'aster', False, '')

def samLauncher__spyder_s_125(lod=0):
    return sam_model('samLauncher__spyder_s_125', 'Spyder / S-125', lod, 'spyder', 'rafael', True, 'SPYDER four-canister launcher')

def samLauncher__type_03_chu_sam(lod=0):
    return sam_model('samLauncher__type_03_chu_sam', 'Type 03 Chu-SAM', lod, 'type03', 'japan', False, '')

def abmLauncher__arrow_3(lod=0):
    return sam_model('abmLauncher__arrow_3', 'Arrow 3', lod, 'arrow3', 'rafael', True, 'Six-canister Arrow 3 TEL, public carrier proportions approximated')

def abmLauncher__hq_19(lod=0):
    return sam_model('abmLauncher__hq_19', 'HQ-19', lod, 'hq19', 'china', True, 'Six-canister HQ-19 ten-wheel TEL, public dimensions approximated')

def abmLauncher__missile_defence_battery(lod=0):
    return sam_model('abmLauncher__missile_defence_battery', 'Missile Defence Battery', lod, 'thaad', 'thaad', True, 'THAAD eight-canister 8x8 launcher')

def abmLauncher__patriot_pac_3(lod=0):
    return sam_model('abmLauncher__patriot_pac_3', 'Patriot PAC-3', lod, 'pac3', 'patriot', False, '')

def abmLauncher__s_500(lod=0):
    return sam_model('abmLauncher__s_500', 'S-500', lod, 's500', 'weg', True, 'Two-canister S-500 ten-wheel TEL, public dimensions approximated')

def abmLauncher__samp_t_ng_aster_30_b1nt(lod=0):
    return sam_model('abmLauncher__samp_t_ng_aster_30_b1nt', 'SAMP/T NG (Aster 30 B1NT)', lod, 'aster', 'aster', False, '')

def abmLauncher__sm_3_pac_3_mse(lod=0):
    return sam_model('abmLauncher__sm_3_pac_3_mse', 'SM-3 / PAC-3 MSE', lod, 'pac3mse', 'patriot', True, 'Patriot PAC-3 MSE launcher trailer')

def abmLauncher__thaad(lod=0):
    return sam_model('abmLauncher__thaad', 'THAAD', lod, 'thaad', 'thaad', False, '')

def saudiThaad__saudi_thaad(lod=0):
    return sam_model('saudiThaad__saudi_thaad', 'Saudi THAAD', lod, 'thaad', 'thaad', False, '')

def irisT__iris_t_slm(lod=0):
    return sam_model('irisT__iris_t_slm', 'IRIS-T SLM', lod, 'irist', 'iris', False, '')

def laserAD__iron_beam(lod=0):
    return laser_model('laserAD__iron_beam', 'Iron Beam', lod)

def shortRangeSAM__an_twq_1_avenger(lod=0):
    return aa('shortRangeSAM__an_twq_1_avenger', 'AN/TWQ-1 Avenger', lod, 'avenger', 'avenger', False, 'avenger', False, '')

def shortRangeSAM__hisar_a(lod=0):
    return sam_model('shortRangeSAM__hisar_a', 'HISAR-A', lod, 'hisara', 'hisar', False, '')

def shortRangeSAM__iris_t_sls(lod=0):
    return sam_model('shortRangeSAM__iris_t_sls', 'IRIS-T SLS', lod, 'irissls', 'iris', True, 'IRIS-T SLS Mk3 on a representative EAGLE 6x6 chassis')

def shortRangeSAM__pantsir_s(lod=0):
    return aa('shortRangeSAM__pantsir_s', 'Pantsir-S', lod, 'pantsir', 'pantsir', True, 'weg', False, '')

def shortRangeSAM__stormer_hvm(lod=0):
    return aa('shortRangeSAM__stormer_hvm', 'Stormer HVM', lod, 'stormer', 'stormer', False, 'weg', False, '')

def shortRangeSAM__type_11_sam(lod=0):
    return sam_model('shortRangeSAM__type_11_sam', 'Type 11 SAM', lod, 'type11', 'japan', False, 'JGSDF Type 11 six-wheel launcher')

def hpmVehicle__leonidas(lod=0):
    return radar_model('hpmVehicle__leonidas', 'Leonidas', lod, 'radar6', 'leonidas', 2.2, 1.8, True, 'Leonidas high-power-microwave array on representative 6x6 carrier')

def counterBatteryRadar__an_tpq_53(lod=0):
    return radar_model('counterBatteryRadar__an_tpq_53', 'AN/TPQ-53', lod, 'radar6', 'tpq', 2.45, 2.15, True, 'AN/TPQ-53 rotating phased array on FMTV, public exterior proportions approximated')

def counterBatteryRadar__cobra(lod=0):
    return radar_model('counterBatteryRadar__cobra', 'COBRA', lod, 'radar8', 'cobra', 3.2, 2.2, True, 'COBRA weapon locating radar on representative 8x8 carrier')

def counterBatteryRadar__cobra_an_tpq_37(lod=0):
    return radar_model('counterBatteryRadar__cobra_an_tpq_37', 'COBRA / AN/TPQ-37', lod, 'radar8', 'cobra', 3.2, 2.2, True, 'COBRA weapon locating radar')

def counterBatteryRadar__slc_2(lod=0):
    return radar_model('counterBatteryRadar__slc_2', 'SLC-2', lod, 'radar8', 'china', 3.1, 2.2, True, 'SLC-2 phased-array truck, public exterior proportions approximated')

def counterBatteryRadar__swathi_wlr(lod=0):
    return radar_model('counterBatteryRadar__swathi_wlr', 'Swathi WLR', lod, 'radar8', 'swathi', 3.2, 2.1, True, 'Swathi on BEML 8x8, public exterior proportions approximated')

def counterBatteryRadar__zoopark_1m(lod=0):
    return radar_model('counterBatteryRadar__zoopark_1m', 'Zoopark-1M', lod, 'radartrack', 'weg', 2.6, 1.85, True, 'Zoopark-1M tracked phased-array carrier, public exterior proportions approximated')

BUILDERS={n:f for n,f in list(globals().items()) if "__" in n and n.split("__")[0] in ("aaVehicle","samLauncher","abmLauncher","saudiThaad","irisT","laserAD","shortRangeSAM","hpmVehicle","counterBatteryRadar") and callable(f)}
assert len(BUILDERS)==68

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
    manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
