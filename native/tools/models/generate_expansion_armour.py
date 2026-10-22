"""Nine new-nation armour designations; original metre geometry, no Blender.

The old approved assets are never regenerated. Each vehicle owns its proportions,
turret footprint, axle layout and recognition fittings. Reuse only real shared
construction and the approved canonical track mesh/shader contract.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
from vehicle_parts import Mesh,Rig,loft,profile_hull,hollow_muzzle,write_glb
from generate_p1_tanks import Spec,finish,make_wreck,basket,beam
from armour_parts import ArmourSpec,mobility,wreck

ROOT=Path(__file__).resolve().parents[3];ART=ROOT/'native/godot/assets/art'
REF={
 'ariete':'https://www.esercito.difesa.it/equipaggiamenti/veicoli-blindati-e-corazzati-da-combattimento/veicoli-da-combattimento/carro-armato-ariete/81543.html',
 'leopard':'https://knds.com/en/products/systems/leopard/leopard-2-a6',
 'griffon':'https://www.defense.gouv.fr/terre/nos-materiels/nos-innovations/dossier-programme-scorpion/griffon-vehicule-blinde-multi-roles',
 'cv90':'https://www.defensie.nl/onderwerpen/m/materieel/voertuigen/combat-vehicle-90',
 'italian':'https://www.difesa.it/assets/allegati/3756/annesso_pdfa.pdf',
 'centauro':'https://www.esercito.difesa.it/equipaggiamenti/veicoli-blindati-e-corazzati-da-combattimento/veicoli-da-combattimento/blindo-centauro-2/122297.html',
 'jaguar':'https://www.defense.gouv.fr/en/node/4062',
 'vbci':'https://www.defense.gouv.fr/terre/nos-materiels/nos-equipements-terre/nos-vehicules/vbci-vehicule-blinde-combat-dinfanterie',
}

def tank__ariete(lod=0):
    s=Spec('ariete','Ariete',7.59,3.61,1.45,2.50,7,.34,.96,.10,2.02,1.32,9.67,'ariete',
      ['Seven road wheels; rear sprockets','C1 welded turret with straight sloping cheeks, not Leopard applique wedges',
       '120 mm L/44 gun','rectangular bustle stowage cage','broad rear engine deck and segmented skirts','right hull driver and raised gunner sight'],REF['ariete'])
    b=[(-.44,1.40),(.44,1.40),(1.44,.67),(1.42,-1.37),(1.08,-1.90),(-1.08,-1.90),(-1.42,-1.37),(-1.44,.67)]
    t=[(-.43,.77),(.43,.77),(1.12,.42),(1.20,-1.38),(.99,-1.80),(-.99,-1.80),(-1.20,-1.38),(-1.12,.42)]
    def detail(h,m,s,l):
        m.box('paint',(-.66,2.44,.71),(.57,.32,.48));m.box('glass',(-.66,2.47,.963),(.38,.17,.023))
        for side in (-1,1):
            m.box('paint',(side*1.36,2.03,-1.06),(.20,.33,1.01))
            if not l:
                for z in (-1.41,-1.09,-.77):m.box('metal_dark',(side*1.47,2.19,z),(.025,.025,.11))
        basket(m,s,l,z=-2.04,width=2.65)
        h.box('paint',(.65,1.49,2.02),(.59,.12,.70))
    return finish(s,b,t,lod,detail)

def tank__leopard_2a6(lod=0):
    s=Spec('leopard_2a6','Leopard 2A6',7.72,3.75,1.46,2.48,7,.34,.99,.05,2.03,1.42,10.97,'leopard',
      ['Seven road wheels; rear sprockets','120 mm L/55 gun','hollow arrowhead wedge cheeks with EMES recess',
       'standard A6 side skirts and rear stowage baskets','rear-mounted PERI panoramic head','no A7V extra front hull armour'],REF['leopard'])
    b=[(-.42,1.8),(.42,1.8),(1.60,.80),(1.58,-1.65),(1.28,-2.),(-1.28,-2.),(-1.58,-1.65),(-1.60,.80)]
    t=[(-.42,.90),(.42,.90),(1.36,.45),(1.38,-1.60),(1.15,-1.92),(-1.15,-1.92),(-1.38,-1.60),(-1.36,.45)]
    def detail(h,m,s,l):
        for side in (-1,1):
            loft(m,'paint',[[[side*x,y,z] for x,y,z in ring] for ring in [
              [(.45,1.76,1.80),(1.64,1.76,.90),(1.56,1.76,-.15),(.50,1.76,.55)],
              [(.45,2.40,.95),(1.54,2.40,.48),(1.42,2.40,-.18),(.50,2.40,.40)]]])
        m.box('paint',(.83,2.45,.65),(.55,.24,.58));m.box('glass',(.83,2.47,.953),(.35,.13,.02))
        basket(m,s,l,z=-2.05,width=2.9)
    return finish(s,b,t,lod,detail)

def armoured_body(s,lod):
    """Hand-shaped station profiles, with real roof heights and axle clearances."""
    m=Mesh();h=s.length/2;w=s.width/2;r=s.roof;f=s.family
    profiles={
      'griffon':[(h-.13,.66,.83),(h,1.66,1.12),(h-.93,1.95,1.13),(h-1.50,r,1.08),(-h+.12,r,1.13),(-h,.78,1.02)],
      'freccia':[(h-.22,.58,1.08),(h,1.28,1.30),(h-1.62,r,1.25),(-h+.13,r,1.28),(-h,.68,1.12)],
      'cv90':[(h-.32,.40,1.04),(h,1.09,1.21),(h-1.56,r,1.14),(-h+.07,r,1.22),(-h,.55,1.08)],
      'dardo':[(h-.25,.40,1.03),(h,1.04,1.21),(h-1.49,r,1.15),(-h+.10,r,1.21),(-h,.61,1.05)],
      'vbci':[(h-.20,.56,1.10),(h,1.23,1.31),(h-1.38,r,1.20),(-h+.13,r,1.29),(-h,.68,1.11)],
      'centauro':[(h-.24,.58,1.08),(h,1.23,1.37),(h-1.75,r,1.28),(-h+.13,r,1.35),(-h,.66,1.14)],
      'jaguar':[(h-.24,.62,1.04),(h,1.24,1.26),(h-1.52,r,1.12),(-h+.12,r,1.20),(-h,.72,1.10)]}
    if f=='griffon':
        # Split the concave bonnet/cab step into two convex closed solids.
        profile_hull(m,'paint',[(h-.13,.66,.83),(h,1.66,1.12),(h-.93,1.95,1.13),(-h+.12,1.95,1.13),(-h,.78,1.02)])
        profile_hull(m,'paint',[(h-1.18,1.82,1.08),(h-1.50,r,1.08),(-h+.12,r,1.13),(-h+.12,1.82,1.13)])
    else:profile_hull(m,'paint',profiles[f])
    if s.mobility=='tracked':
        for side in (-1,1):
            m.box('paint',(side*(w-.32),1.18*s.track_scale,0),(.64,.10,s.length-.26))
            m.box('paint',(side*(w-.21),r*.70,-.12),(.44,.52,s.length-.83))
            for z in np.linspace(-h+.48,h-.62,5):m.box('paint',(side*(w-.03),1.34,z),(.075,.40,(s.length-1.1)/5-.045))
    else:
        for side in (-1,1):
            for z in s.axle_z:m.box('paint',(side*(w-.20),s.wheel_radius*1.96,z),(.49,.09,s.wheel_radius*2.08))
        for z in s.axle_z:
            m.tube('metal_dark',(-w+.18,s.wheel_radius,z),(w-.18,s.wheel_radius,z),.09,6)
            if not lod:
                for side in (-1,1):beam(m,'metal_dark',(side*.60,.95,z+.20),(side*(w-.34),s.wheel_radius,z),.075)
    if f=='griffon':
        # Bonnet, high protected cab and troop capsule are separate volumes.
        m.box('paint',(0,1.75,h-.61),(2.18,.24,1.00))
        for side in (-1,1):
            m.box('paint',(side*1.12,2.06,h-1.78),(.12,1.09,.89))
            m.box('glass',(side*.46,2.57,h-1.32),(.75,.47,.06))
            m.box('glass',(side*1.188,2.50,h-1.78),(.028,.41,.54))
            m.box('metal_dark',(side*1.15,1.28,h-1.78),(.32,.10,.84))
            if not lod:
                for z in np.linspace(-h+.60,-.48,3):m.box('glass',(side*1.17,2.55,z),(.025,.28,.41))
        for yy in np.linspace(1.42,1.76,3 if lod else 6):m.box('metal_dark',(0,yy,h+.006),(1.30,.025,.035))
    if f=='jaguar':
        # Low bow with central driver's episcope; high rear engine compartment.
        m.box('paint',(0,r-.11,h*.45),(.73,.24,.78))
        m.box('glass',(0,r+.025,h*.45+.23),(.43,.07,.13))
        m.box('paint',(0,r+.12,-h*.73),(s.width-.45,.24,1.10))
    if f in ('freccia','vbci','cv90','dardo','centauro'):
        m.box('paint',(-.57,r+.035,h*.42),(.57,.08,.65))
        for j in range(3):m.box('glass',(-.76+j*.20,r+.11,h*.42+.21),(.15,.07,.12))
    # Characteristic armour modules and rear troop ramp on personnel vehicles.
    if f not in ('centauro','jaguar'):
        m.box('paint',(0,r*.61,-h-.025),(1.46,r*.57,.075))
        m.box('metal_dark',(0,r*.33,-h-.076),(1.32,.055,.07))
        if not lod:
            for side in (-1,1):
                for z in np.linspace(-h+.46,.30,5 if f=='cv90' else 4):
                    m.box('paint',(side*(w-(.03 if f=='cv90' else .14)),r*.72,z),(.10,.40,.40))
    for side in (-1,1):
        m.box('paint',(side*(w-.40),1.29,h-.10),(.27,.19,.26))
        m.box('glass',(side*(w-.40),1.30,h+.038),(.19,.11,.025))
        m.box('glass',(side*(w-.37),.93,-h-.052),(.15,.15,.03))
        m.box('paint',(side*(w-.23),r*.70,-.45),(.48,.31,.56))
        m.box('markings',(side*(w+.016),r*.70,-.45),(.017,.26,.46))
        beam(m,'metal_dark',(side*(w-.26),.70,h-.03),(side*(w-.26),.70,h+.15),.06)
        if not lod:
            for z in (-h+.50,-h+1.0):m.box('metal_dark',(side*(w-.12),r-.16,z),(.035,.035,.16))
    # Engine louvers always sit on a real deck; never on an empty bounding box.
    ez=-h*.73 if f in ('jaguar','centauro') else h*.35
    for z in np.linspace(ez-.38,ez+.38,3 if lod else 9):m.box('metal_dark',(.55,r+.027,z),(.64,.035,.04))
    return m

def weapon_mount(rig,s,lod):
    """Individual manned turrets, no fictional missile pack on Dutch CV90."""
    f=s.family;x=s.turret_x;z=s.turret_z;y=s.roof+.08;n=6 if lod else 12
    dims={ 'freccia':(1.80,.65,1.95,2.0,.025),'cv90':(1.91,.68,2.06,2.65,.035),
      'dardo':(1.73,.65,1.76,1.93,.025),'vbci':(1.31,.68,1.48,1.77,.025),
      'centauro':(2.55,.81,3.35,3.93,.120),'jaguar':(2.05,.86,2.32,1.85,.040)}
    if f=='griffon':
        m=Mesh();m.tube('paint',(x,y-.06,z),(x,y+.22,z),.16,n)
        m.box('paint',(x,y+.33,z),(.36,.27,.43));m.box('paint',(x-.28,y+.34,z),(.21,.31,.38))
        m.box('glass',(x-.28,y+.36,z+.202),(.14,.15,.028))
        rig.add('Turret','Hull',(x,y,z),m,'Y');g=Mesh();gy=y+.40;gz=z+.13
        g.box('metal_dark',(x,gy,gz),(.12,.15,.39));hollow_muzzle(g,[x,gy,gz+.16],[x,gy,gz+.88],.024,.00635,n)
        rig.add('Gun','Turret',(x,gy,gz),g,'X');rig.add('Muzzle','Gun',(x,gy,gz+.88),forward='+Z');return
    tw,th,td,barrel,bore=dims[f];m=Mesh()
    m.tube('metal_dark',(x,y-.07,z),(x,y+.03,z),tw*.35,n)
    if f=='vbci':
        # One-man TARASK turret, compact and offset to the left of the hull.
        b=[(-.44,.68),(.40,.68),(.65,.18),(.57,-.70),(-.50,-.70),(-.67,.06)]
    elif f=='centauro':
        b=[(-.40,1.60),(.40,1.60),(1.28,.40),(1.24,-1.72),(-1.24,-1.72),(-1.28,.40)]
    elif f=='jaguar':
        b=[(-.40,1.14),(.45,1.14),(1.04,.40),(.98,-1.10),(-.88,-1.10),(-1.03,.32)]
    elif f=='cv90':
        b=[(-.35,1.0),(.42,1.0),(.96,.26),(.91,-1.04),(-.86,-1.04),(-.96,.16)]
    else:b=[(-tw*.26,td*.52),(tw*.30,td*.52),(tw*.50,td*.12),(tw*.47,-td*.48),(-tw*.47,-td*.48),(-tw*.50,td*.12)]
    loft(m,'paint',[[(x+a,y,z+c) for a,c in b],[(x+a*.80,y+th,z+c*.84) for a,c in b]])
    m.tube('paint',(x-tw*.18,y+th,z-.30),(x-tw*.18,y+th+.07,z-.30),tw*.19,n)
    m.box('paint',(x+tw*.28,y+th+.08,z+.04),(.32,.23,.41));m.box('glass',(x+tw*.28,y+th+.09,z+.259),(.23,.14,.023))
    if f=='centauro':
        m.box('paint',(x,y+th*.65,z-1.52),(2.10,.45,.66))
        m.tube('paint',(x-.75,y+th,z-.61),(x-.75,y+th+.29,z-.61),.15,n)
        m.box('glass',(x-.75,y+th+.35,z-.61),(.28,.14,.29))
    if f=='jaguar':
        # Starboard retractable twin Akeron pack and raised panoramic optic.
        m.box('paint',(x+1.03,y+.57,z-.28),(.39,.42,1.10))
        for yy in (-.10,.10):hollow_muzzle(m,[x+1.03,y+.57+yy,z+.12],[x+1.03,y+.57+yy,z+.29],.075,.052,n)
        m.tube('paint',(x-.50,y+th,z-.47),(x-.50,y+th+.29,z-.47),.11,n)
        m.box('paint',(x-.50,y+th+.39,z-.47),(.33,.26,.34));m.box('glass',(x-.50,y+th+.40,z-.286),(.23,.14,.025))
    if f=='dardo':
        for side in (-1,1):hollow_muzzle(m,[x+side*1.02,y+.38,z-.65],[x+side*1.02,y+.38,z+.45],.105,.078,n)
    for side in (-1,1):
        m.box('paint',(x+side*(tw*.49),y+th*.50,z-.45),(.08,.27,.48))
        m.box('markings',(x+side*(tw*.49+.047),y+th*.50,z-.45),(.015,.22,.40))
        if not lod:
            for j in range(3):
                a=np.array([x+side*tw*.45,y+th*.59,z+.18-j*.14]);m.tube('metal_dark',a,a+[side*.10,.10,.13],.034,6)
    rig.add('Turret','Hull',(x,y,z),m,'Y')
    gy=y+th*.55;gz=z+td*.32;g=Mesh();g.box('paint',(x,gy,gz),(.45,.34,.40))
    if f=='centauro':
        g.tube('metal_dark',(x,gy,gz+.15),(x,gy,gz+barrel-.32),.090,n)
        g.box('metal_dark',(x,gy,gz+barrel-.16),(.26,.21,.32))
        hollow_muzzle(g,[x,gy,gz+barrel-.10],[x,gy,gz+barrel+.01],.09,.06,n)
    else:hollow_muzzle(g,[x,gy,gz+.16],[x,gy,gz+barrel],.046 if bore<.04 else .055,bore/2,n)
    rig.add('Gun','Turret',(x,gy,gz),g,'X',bore_metres=bore)
    rig.add('Muzzle','Gun',(x,gy,gz+barrel+(.01 if f=='centauro' else 0)),forward='+Z')

def assemble(s,lod):
    rig=Rig(lod);m=armoured_body(s,lod);m.remove_duplicates();rig.add('Hull',rig.root,(0,0,0),m)
    mobility(rig,s,lod);weapon_mount(rig,s,lod)
    # Small roof fittings are attached to their actual supporting surfaces.
    z=-s.length*.35;y=s.roof+(.24 if s.family=='jaguar' else 0)
    ant=Mesh();ant.tube('metal_dark',(-.60,y,z),(-.60,y+.12,z),.043,6)
    ant.tube('metal_dark',(-.60,y+.12,z),(-.60,y+1.10,z-.025),.009,4 if lod else 6,r_top=.003)
    rig.add('Antenna_1','Hull',(-.60,y,z),ant,'Y')
    rig.add('Engine_Deck','Hull',(.55,s.roof+.04,(-1 if s.family in ('jaguar','centauro') else 1)*s.length*.35))
    rig.add('Exhaust','Hull',(s.width/2-.12,s.roof*.80,-s.length*.40))
    return rig,s

def apc__griffon(lod=0):
    return assemble(ArmourSpec('apc__griffon','Griffon',7.58,2.54,2.93,'wheeled',3,.61,'griffon','hornet',
      ['6x6 with spaced axles','short bonnet and tall protected capsule','two large windscreens and side cab doors','roof Hornet RWS','rear troop ramp'],REF['griffon'],axle_z=[-2.30,-.20,2.42],turret_z=.25,turret_x=.24),lod)

def apc__vbm_freccia(lod=0):
    return assemble(ArmourSpec('apc__vbm_freccia','VBM Freccia',8.56,2.99,2.23,'wheeled',4,.57,'freccia','hitfist25',
      ['8x8 Centauro-derived chassis','long sloping bow','two-man Hitfist 25 turret','rear troop ramp','four discrete wheel stations per side'],REF['italian'],axle_z=[-2.93,-1.38,1.33,2.93],turret_z=-.12),lod)

def ifv__cv9035nl(lod=0):
    return assemble(ArmourSpec('ifv__cv9035nl','CV9035NL',6.55,3.10,1.96,'tracked',7,.30,'cv90','bushmaster35',
      ['Seven road wheels and front sprockets','long 35 mm Bushmaster III barrel','two-man faceted turret','rear troop door','sloping bow and segmented side applique','baseline Dutch configuration without invented missile box'],REF['cv90'],track_scale=.80,turret_z=-.28),lod)

def ifv__dardo_ifv(lod=0):
    return assemble(ArmourSpec('ifv__dardo_ifv','Dardo IFV',6.70,3.0,1.91,'tracked',6,.29,'dardo','hitfist25tow',
      ['Six road wheels and front sprockets','compact two-man Hitfist turret','25 mm Oerlikon gun','bilateral TOW launch tubes','low sharply sloped front glacis'],REF['italian'],track_scale=.81,turret_z=-.26),lod)

def ifv__vbci(lod=0):
    return assemble(ArmourSpec('ifv__vbci','VBCI',7.60,2.98,2.27,'wheeled',4,.60,'vbci','tarask25',
      ['8x8 aluminium hull','compact offset one-man TARASK turret','25 mm cannon','high troop compartment and rear ramp','periscope driving position'],REF['vbci'],axle_z=[-2.45,-.92,.87,2.45],turret_z=-.30,turret_x=-.24),lod)

def reconVehicle__centauro_ii(lod=0):
    return assemble(ArmourSpec('reconVehicle__centauro_ii','Centauro II',8.26,3.12,1.97,'wheeled',4,.60,'centauro','hitfact120',
      ['8x8 with front powerpack','large Hitfact II three-man turret','long 120 mm gun with box muzzle brake','large angular ammunition bustle','panoramic roof optic'],REF['centauro'],axle_z=[-2.80,-1.28,1.14,2.79],turret_z=-.53),lod)

def reconVehicle__ebrc_jaguar(lod=0):
    return assemble(ArmourSpec('reconVehicle__ebrc_jaguar','EBRC Jaguar',7.30,2.99,1.91,'wheeled',3,.61,'jaguar','t40',
      ['6x6 reconnaissance chassis','central driver in low pointed bow','large T40 turret with 40 mm CT cannon','starboard twin Akeron missile pack','raised panoramic sight and high rear engine deck'],REF['jaguar'],axle_z=[-2.35,-.18,2.35],turret_z=-.12),lod)

BUILDERS={n:f for n,f in list(globals().items()) if '__' in n and callable(f) and n.startswith(('tank__','apc__','ifv__','reconVehicle__'))}

def save(slug):
    from validate_p2_armour import validate
    a,s=BUILDERS[slug](0);b,s1=BUILDERS[slug](1);assert asdict(s)==asdict(s1)
    spec=asdict(s);tank=slug.startswith('tank__')
    if tank:spec.update(mobility='tracked',weapon='tank',family=s.shape,equipment='',axle_z=[])
    c=Mesh();height=s.deck if tank else s.roof;c.box('metal_dark',(0,height/2,0),(s.width,height,s.length))
    path=ART/'vehicles'/f'{slug}.glb'
    write_glb(path,[a,b],make_wreck(b,s) if tank else wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P1' if tank else 'P2',
       'spec':spec,'units':'metres','up':'+Y','front':'+Z','detached_turret':True,'canonical_track_path':{'half':3.23,'radius':.57,'y':.65}})
    entry,tree=validate(path)
    entry['notes']=entry['notes'].replace('generate_p2_armour.py + armour_parts.py','generate_expansion_armour.py + armour_parts.py')
    (Path(__file__).parent/'reports'/f'{slug}.node-tree.txt').write_text(tree,encoding='utf-8')
    print(tree);print('PASS',slug,entry['triangles'],flush=True);return entry

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--types',nargs='+',choices=BUILDERS,required=True);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();entries=[save(slug) for slug in a.types]
    manifest=ART/'MANIFEST.json';old=json.loads(manifest.read_text(encoding='utf-8'));updates={e['file']:e for e in entries}
    manifest.write_text(json.dumps([updates.pop(e['file'],e) for e in old]+list(updates.values()),indent=2)+'\n',encoding='utf-8')
    a.report.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
