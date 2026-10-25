"""Original Japanese escort, conventional submarine and ordered OPV exteriors.

Public size and photographs; local surfaces, sensor heads and concealed screw
profiles are estimates. Launch, trials and commission are separate statuses.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
from generate_p7_ships import sub
from generate_inventory_additions_16 import combatant,lattice,fittings
import generate_inventory_additions_05 as saver
from generate_inventory_additions_12 import remove
from vehicle_parts import Mesh,loft,hollow_muzzle
from ship_parts import beam,block

NAVY='https://www.mod.go.jp/msdf/equipment/ships/'

def box_launcher(r,s,lod,name,z,base,*,sam=False):
    """Eight closed exterior launch containers, Y traverse/X elevation."""
    D=s.draft+s.freeboard;p=np.array([0,D+base,z]);m=Mesh()
    m.tube('paint',p,p+[0,.46,0],.62,8 if lod else 20)
    r.add(name+'_Turntable','Hull',p,m,'Y');q=p+[0,.95,0];m=Mesh()
    length=2.2 if sam else 3.45;pitch=.46 if sam else .56
    for row in range(2):
        for col in range(4):
            x=(col-1.5)*pitch;y=(row-.5)*pitch;centre=q+[x,y,0]
            m.box('paint',centre,(pitch*.90,pitch*.90,length))
            if not lod:m.box('metal_dark',centre+[0,0,length/2+.012],(pitch*.74,pitch*.74,.025))
    r.add(name+'_Launcher',name+'_Turntable',q,m,'X',tube_count=8,exterior_only=True)
    for i in range(8):
        tip=q+[(i%4-1.5)*pitch,(i//4-.5)*pitch,length/2+.03]
        r.add(name+'_Muzzle_'+str(i),name+'_Launcher',tip,purpose='closed exterior launch station')

def destroyer__asagiri_class(lod=0):
    r,s=combatant('destroyer__asagiri_class','Asagiri class DD',lod,(137.,14.6,4.5,4.3),
        NAVY+'dd/asagiri/',
        ['137m late-batch general-purpose destroyer','76mmL62bow gun','eight-box trainable ASROC forward launcher','eight-box SeaSparrow on hangar roof','two tall lattice masts','two narrow funnels','single helicopter hangar','eightSSM containers and twoPhalanx'],
        houses=[(0,16.,11.3,25.,6.7,0,.88),(0,-27.,11.6,25.,5.5,0,.93)],
        funnels=[(0,-.5,3.7,5.4,7.8,1.7),(0,-15.,3.7,5.4,7.6,1.9)],
        masts=[(14.5,24.8,'bar',3.3),(-18.,19.,'bar',2.5)],guns=[(0,47.,76,4.71)],
        vls=[],canisters=[(-7.,2.6,4)],ciws=[(-5.15,16.,3.1),(5.15,16.,3.1)],hangar_z=-39.6)
    lattice(r,s,lod,0,14.5,24.8,1.45)
    # The aft lattice tower is rooted in its actual lower deck pedestal.
    m=Mesh();D=s.draft+s.freeboard
    for x in (-.85,.85):
        for dz in (-.5,.5):beam(m,[x,D+3.,-18.+dz],[x*.32,D+19.,-18.+dz*.32],.075,lod,'paint')
    for yy in (7.,11.,15.,18.):
        w=.85*(1-.68*(yy-3)/16)
        beam(m,[-w,D+yy,-18.],[w,D+yy,-18.],.065,lod)
        if not lod and yy<18:beam(m,[-w,D+yy,-18.],[w*.85,D+yy+2.2,-18.],.035,lod)
    for p in r.parts:
        if p['name']=='Mast_1':p['mesh']=m
    box_launcher(r,s,lod,'ASROC',33.5,.15)
    box_launcher(r,s,lod,'SeaSparrow',-27.0,5.70,sam=True)
    fittings(r,s,lod,-3.)
    s.representative='Late-batch Hamagiri/Setogiri-family4.5m draft representative; early Yugiri/Amagiri4.4m draft differs. Active DD list excludes training/retired names. Mk112/Mk29 closed external boxes, not VLS. Local small fittings estimated.'
    return r,s

def asFrigate__abukuma_class(lod=0):
    r,s=combatant('asFrigate__abukuma_class','Abukuma class DE',lod,(109.,13.4,3.8,4.0),
        NAVY+'de/abukuma/',
        ['109m compact destroyer escort','76mmL62bow gun','eight-box forward ASROC launcher','lattice foremast','two small exhaust groups','eightHarpoon containers','onePhalanx aft','no helicopter hangar or landing deck'],
        houses=[(0,10.5,10.1,23.,5.7,0,.89),(0,-17.,9.4,19.,3.8,0,.94)],
        funnels=[(0,-4.,3.1,4.9,5.8,1.8),(0,-17.,2.7,4.3,5.3,2.1)],
        masts=[(9.0,21.,'bar',3.0)],guns=[(0,38.,76,4.71)],
        vls=[],canisters=[(-10.,2.8,4)],ciws=[(0,-35.,.25)],hangar=False,flight_deck=False)
    lattice(r,s,lod,0,9.,21.,1.25);box_launcher(r,s,lod,'ASROC',26.,.1)
    fittings(r,s,lod,-3.)
    s.representative='Japanese Abukuma-class escort exterior; future Philippine transfer discussions do not establish transfer or retirement of the class today. No helicopter capability invented. Public109x13.4m/draft3.8m, small fittings estimated.'
    return r,s

def upper_casing(r,s,lod,width,length,z):
    # Narrow, closed upper deck, set into the rounded outer hull, with light
    # drainage detail. Does not pretend to model internal pressure vessels.
    m=Mesh();B=s.beam
    block(m,'paint',0,B*.88,z,width,.42,length,.98)
    if not lod:
        for zz in np.linspace(z-length*.45,z+length*.45,24):
            for side in (-1,1):m.box('metal_dark',(side*width*.496,B*.90,zz),(.025,.075,.24))
    r.add('Upper_Casing','Hull',(0,B*.88,z),m)

def japanese_sail(r,s,*,raked):
    """Flat-topped narrow sail with a lower skirt inside the curved casing."""
    B=s.beam;d=s.details;z=d['sail_z']*s.length;L=d['sail_length'];base=B*.92;h=d['sail_height'];w=B*.14
    rings=[]
    for y,scale,front in ((base-.55,1.,.50),(base+h,.80,.40 if raked else .48)):
        footprint=[(-w,-.40*L),(-w*.52,-.50*L),(w*.52,-.50*L),(w,-.40*L),
                   (w,front*L-.8),(w*.30,front*L),(-w*.30,front*L),(-w,front*L-.8)]
        rings.append([[x*scale,y,z+zz] for x,zz in footprint])
    m=Mesh();loft(m,'paint',rings)
    for part in r.parts:
        if part['name']=='Sail':part['mesh']=m
    remove(r,'Sail_Fittings');m=Mesh()
    for side in (-1,1):
        points=[]
        for yy,zz in ((base+h*.37,z-L*.11),(base+h*.37,z+L*.11),(base+h*.55,z+L*.11),(base+h*.55,z-L*.11)):
            xx=w*(1-.20*(yy-base+.55)/(h+.55))+.014
            points.append([side*xx,yy,zz])
        m.face('markings',points,[side,w*.20/(h+.55),0])
    r.add('Sail_Fittings','Sail',(0,base,z),m)

def submarine__oyashio_class(lod=0):
    r,s=sub('submarine__oyashio_class','Oyashio class SS',lod,82.,8.9,7.4,NAVY+'ss/oyashio/',
        ['82m conventional rounded hull','tall narrow sail','sail-mounted diving planes','cruciform stern controls','long narrow upper casing','one estimated skewback screw','no missile deck or unverified pumpjet'],
        sail_z=.13,sail_height=5.6,sail_length=14.8,foreplanes='sail',x_tail=False,prop_blades=7,
        body_profile=[(-.45,.06),(-.38,.27),(-.26,.45),(-.1,.5),(.15,.5),(.33,.47),(.44,.32),(.485,.14),(.5,.006)])
    upper_casing(r,s,lod,3.15,54.,1.0);japanese_sail(r,s,raked=False)
    s.representative='Active SSclass exterior, not a claim that training TSSboats or retired lead hull remain combat boats. Operator listsSS594-600 separately from training fleet. Published82x8.9m/draft7.4m; concealed seven-blade screw and local contours are estimates.'
    return r,s

def submarine__soryu_class(lod=0):
    r,s=sub('submarine__soryu_class','Soryu class',lod,84.,9.1,8.5,NAVY+'ss/souryu/',
        ['84m conventional Japanese submarine','broad full bow and long upper casing','larger raked sail than Oyashio','sail-mounted planes','four X stern controls','one estimated skewback screw','no unverified vertical missile bank'],
        sail_z=.105,sail_height=4.65,sail_length=15.4,foreplanes='sail',x_tail=True,prop_blades=7,
        body_profile=[(-.45,.06),(-.37,.29),(-.25,.46),(-.10,.5),(.17,.5),(.34,.47),(.45,.33),(.485,.15),(.5,.006)])
    upper_casing(r,s,lod,3.5,56.,1.0);japanese_sail(r,s,raked=True)
    s.representative='Soryu-class public exterior; original AIP and final lithium-ion boats not treated as identical internal machinery. Published84x9.1m/draft8.5m. Concealed screw blade count/profile and local contours estimated, not published propulsor engineering.'
    return r,s

def gunboat__sakura_class_opv(lod=0):
    r,s=combatant('gunboat__sakura_class_opv','Sakura class OPV (ordered/trials)',lod,(95.,12.,4.2,3.5),
        'https://www.mod.go.jp/msdf/operation/meimei/r07/',
        ['95m1900ton ordered offshore patrol vessel','long high faceted forward superstructure','broad bridge wings','integrated low exhaust enclosure','single small30mm remote bow gun','navigation radar and EO sensors','open stern UAV working deck','no missiles,Phalanx,helicopter hangar or full helicopter landing deck'],
        houses=[(0,-1.5,10.4,45.,8.2,0,.79),(0,15.,11.15,12.,2.0,8.0,.94)],
        funnels=[(0,-12.,4.3,6.,4.8,4.7)],masts=[(-.5,19.,'bar',2.6)],
        guns=[],vls=[],canisters=[],ciws=[],hangar=False,flight_deck=False,bow_sheer=.72,
        boats=[(-4.9,-11.),(4.9,-11.)])
    D=s.draft+s.freeboard;p=np.array([0,D+.15,32.0]);m=Mesh()
    m.tube('paint',p,p+[0,.45,0],.45,8 if lod else 20)
    block(m,'paint',0,p[1]+.40,p[2],1.0,.85,1.30,.76)
    r.add('Turret_Main','Hull',p,m,'Y');q=p+[0,.92,.16];m=Mesh()
    m.box('metal_dark',q,(.26,.30,.65));hollow_muzzle(m,q+[0,0,.30],q+[0,0,1.93],.046,.015,8 if lod else 20)
    r.add('Gun','Turret_Main',q,m,'X');r.add('Muzzle','Gun',q+[0,0,1.93])
    m=Mesh()
    for x in (-4.2,4.2):
        m.box('glass',(x,D+7.95,-16.),(.06,1.4,2.1))
    # Optical fire control and lookout heads; no imagined missile radar.
    for x,z,y in ((0,18.,10.4),(-2.1,5.,8.6),(2.1,5.,8.6)):
        m.tube('paint',(x,D+y,z),(x,D+y+.35,z),.20,8 if lod else 20)
        m.box('glass',(x,D+y+.16,z+.21),(.20,.18,.025))
    r.add('Optical_Sensors','Hull',(0,D+10.4,18.),m)
    m=Mesh();m.box('paint',(0,D+.04,-34.0),(7.5,.08,8.5))
    r.add('UAV_Working_Deck','Hull',(0,D,-34.0),m)
    s.details['inventory_status']='firm_built_sea_trials_commission_planned_2027'
    s.representative='Sakura/Tachibana launchedNovember2025; four built or fitting byMarch2026, official current schedule2027commission. September2026 original sea-trial photographs corroborate exterior, not operational service.95x12m,depth7.7m/draft4.2m. Clean UAV working deck; no named UAV model or weapon system invented.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('destroyer__','asFrigate__','submarine__','gunboat__')) and callable(f)}
def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for part in r.parts:
            if part['mesh'] is not None:part['mesh'].remove_duplicates()
        return r,s
    saver.BUILDERS[slug]=checked;e=saver.save(slug)
    e['notes']+=' Original evidence-led generator generate_inventory_additions_17.py. Public exterior approximations; active, training, ordered and trial statuses recorded separately.'
    return e
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
