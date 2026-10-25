"""Six distinct Japanese destroyer classes, original public exterior geometry.

Published lengths, beams, drafts and gun types; local deck fits estimated.
No inference that every hull has completed current missile/radar upgrades.
"""
from pathlib import Path
import argparse,json,math
import numpy as np
from generate_p7_ships import combatant as shared_combatant
import generate_inventory_additions_05 as saver
from vehicle_parts import Mesh,loft,hollow_muzzle
from ship_parts import beam,block

ROOT='https://www.mod.go.jp/msdf/equipment/ships/'

def combatant(*args,**kwargs):
    return shared_combatant(*args,rail_count=25,**kwargs)

def lattice(r,s,lod,index,z,height,width):
    D=s.draft+s.freeboard;m=Mesh()
    roof=max(a[4]+a[5] for a in s.details['houses'] if abs(z-a[1])<a[3]/2)
    base=D+roof-.12;top=D+height
    for x in (-width,width):
        for dz in (-width*.62,width*.62):beam(m,[x,base,z+dz],[x*.22,top,z+dz*.22],.095,lod,'paint')
    count=4 if lod else 7
    for t in np.linspace(.04,.91,count):
        yy=base+(top-base)*t;w=width*(1-.78*t);zz=w*.62
        for sign in (-1,1):
            beam(m,[-w,yy,z+sign*zz],[w,yy,z+sign*zz],.065,lod)
            if not lod:
                tt=min(.98,t+.11);ww=width*(1-.78*tt);y2=base+(top-base)*tt
                beam(m,[-w,yy,z+sign*zz],[ww,y2,z+sign*ww*.62],.040,lod)
    for p in r.parts:
        if p['name']=='Mast_'+str(index):p['mesh']=m

def closure_bank(r,s,lod,index,z,cols,rows,base=0,missing=(),x=0):
    """Individual closed exterior lids, including old Mk41 crane footprints.

    Custom cell counts are explicit; no phantom missiles occupy crane slots.
    The generic ship validator remains unchanged for its rectangular banks.
    """
    D=s.draft+s.freeboard;y=D+base;pitch=.80;m=Mesh();positions=[]
    m.box('paint',(x,y+.08,z),(cols*pitch+.22,.16,rows*pitch+.22))
    for a in range(cols):
        for b in range(rows):
            q=np.array([x+(a-(cols-1)/2)*pitch,y+.20,z+(b-(rows-1)/2)*pitch])
            if (a,b) in missing:continue
            positions.append(q.tolist())
            if not lod:
                m.box('metal_dark',q,(.70,.06,.70));m.box('paint',q+[0,.043,.23],(.55,.025,.12))
    r.add('VLS_'+str(index),'Hull',(x,y,z),m,cell_count=len(positions),closed_cell_centres_metres=positions,
          arrangement='public exterior estimate; no live load or current upgrade certification')
    s.details.setdefault('custom_vls_banks',[]).append({'name':'VLS_'+str(index),'cells':len(positions),'positions':positions})
    if missing:
        # Original strike-down crane folded into the three-cell footprint.
        m=Mesh();xx=x+(cols-1)/2*pitch;zz=z-(rows-1)/2*pitch
        m.box('paint',(xx-.40,y+.37,zz),(.46,.45,1.75))
        beam(m,[xx-.95,y+.57,zz],[xx+.15,y+.64,zz],.10,lod,'paint')
        r.add('VLS_Crane_'+str(index),'Hull',(xx-.4,y+.25,zz),m)

def fittings(r,s,lod,z):
    D=s.draft+s.freeboard;m=Mesh()
    for side in (-1,1):
        # Two triple torpedo tube installations and compact chaff racks.
        for dz in (-.45,0,.45):
            a=np.array([side*s.beam*.31,D+2.0,z+dz]);b=a+[side*1.45,0,0]
            m.tube('paint',a,b,.20,4 if lod else 10)
            if not lod:m.tube('metal_dark',b,b+[side*.03,0,0],.16,10)
        for zz in (() if lod else (15.,-19.)):
            for j in range(3):
                a=np.array([side*s.beam*.38,D+2.3,zz+j*.22]);b=a+[side*.32,.39,.12]
                m.tube('metal_dark',a,b,.055,6)
        for zz in np.linspace(-30,-24,2 if lod else 4):
            m.tube('paint',(side*s.beam*.39,D+3.4,zz),(side*(s.beam*.39+.9),D+3.4,zz),.37,4 if lod else 10)
            beam(m,[side*s.beam*.31,D+3.0,zz],[side*(s.beam*.39+.45),D+3.0,zz],.055,lod,'paint')
    r.add('Japanese_Deck_Fittings','Hull',(0,D,z),m)

def fixed_arrays(r,s,lod,*,asahi=False):
    D=s.draft+s.freeboard;m=Mesh()
    # Fixed AESA faces integrated into the forward bridge and aft upper house;
    # these are not the rotating navigation radar above the lattice mast.
    for z,base,w in ((22.,7.9,6.3),(-30.,6.3,5.6)):
        h=3.0 if asahi else 2.4
        block(m,'paint',0,D+base,z,w,h,5.4,.82)
        for side in (-1,1):
            # Follow the sloping support skin exactly; constant-X rectangles
            # become buried inside a tapered mast instead of visible arrays.
            points=[]
            for yy,zz in ((h*.55-.675,-.775),(h*.55-.675,.775),(h*.55+.675,.775),(h*.55+.675,-.775)):
                points.append([side*(w/2*(1-.18*yy/h)+.025),D+base+yy,z+zz])
            m.face('metal_dark',points,[side,w*.09/h,0])
            points=[]
            for yy,xx in ((h*.55-.675,-.775),(h*.55-.675,.775),(h*.55+.675,.775),(h*.55+.675,-.775)):
                points.append([xx,D+base+yy,z+side*(2.7*(1-.18*yy/h)+.025)])
            m.face('metal_dark',points,[0,2.7*.18/h,side])
    r.add('OPY1_Fixed_Arrays' if asahi else 'FCS3A_Fixed_Arrays','Hull',(0,D+9,22),m)

def destroyer__kongo_class(lod=0):
    r,s=combatant('destroyer__kongo_class','Kongo class',lod,(161.,21.,6.2,5.8),ROOT+'ddg/kongou/',
        ['161m first-generation Japanese Aegis hull','large lattice mast','four fixed SPY faces on tall bridge','127mmL54 forward gun','90 closed VLS cells with two original crane footprints','open helicopter deck without hangar','two funnels and twoPhalanx'],
        houses=[(0,17.,16.2,41.,8.5,0,.82),(0,20.,11.8,20.,4.6,8.5,.82),(0,-22.,12.9,18.,3.2,0,.91)],
        funnels=[(0,-3.5,5.3,7.5,8.1,2.8),(0,-21.,5.2,7.3,7.7,2.8)],
        masts=[(18.,28.,'bar',3.6),(-19.,15.5,'bar',2.6)],fixed_arrays=[18.,10.5,13.6],
        guns=[(0,58.,127,6.86)],vls=[],canisters=[(-12.,3.1,4)],ciws=[(0,29.,8.7),(0,-25.,3.4)],hangar=False)
    lattice(r,s,lod,0,18.,28.,1.72)
    closure_bank(r,s,lod,0,42.,8,4,missing=((5,0),(6,0),(7,0)))
    closure_bank(r,s,lod,1,-39.,8,8,base=.25,missing=((5,0),(6,0),(7,0)))
    fittings(r,s,lod,-10.)
    s.representative='Public Kongo exterior, no helicopter hangar.90-cell29/61 baseline includes original three-cell crane spaces; local profiles and bank positions estimated, not proof of a specific hull current Tomahawk or radar upgrade.'
    return r,s

def destroyer__atago_class(lod=0):
    r,s=combatant('destroyer__atago_class','Atago class',lod,(165.,21.,6.2,5.8),ROOT+'ddg/atago/',
        ['165m Japanese Aegis destroyer','solid tapered main mast','127mmL62 bow gun','96 closed VLS cells in64forward/32aft banks','stern aircraft hangar and flight deck','two funnels and twoPhalanx','four fixed SPY faces'],
        houses=[(0,17.,16.2,43.,9.1,0,.81),(0,21.,11.6,19.,4.1,9.1,.81),(0,-32.,15.,26.,6.2,0,.92)],
        funnels=[(0,-4.,5.5,8.,8.0,3.1),(0,-19.,5.4,7.2,7.9,3.1)],
        masts=[(20.,27.,'bar',3.5),(-22.,16.5,'bar',2.6)],fixed_arrays=[20.,11.1,13.8],
        guns=[(0,60.,127,7.87)],vls=[(41.,8,8,.80,0),(-32.,8,4,.80,6.3)],canisters=[(-11.,3.5,4)],
        ciws=[(0,30.,9.3),(0,-34.,6.5)],hangar_z=-45.1,hangar_doors=1)
    fittings(r,s,lod,-9.)
    s.representative='Atago public exterior with aircraft hangar, longerL62gun and solid mast; not Kongo or later170mMaya. One representative hangar frontage, local details estimated. Catalogue doesnotquantifycell count or establish fleet-wide completion of modernisation.'
    return r,s

def destroyer__murasame_class(lod=0):
    r,s=combatant('destroyer__murasame_class','Murasame class',lod,(151.,17.4,5.2,5.7),ROOT+'dd/murasame/',
        ['76mmL62bow gun','16forwardMk41 and16midshipMk48closed cells','high lattice mast','two separated raked funnels','eightSSM containers between funnels','single helicopter hangar','twoPhalanx'],
        houses=[(0,18.,13.4,30.,7.1,0,.86),(0,-30.,13.5,28.,5.9,0,.93)],
        funnels=[(0,-1.,4.8,6.7,7.8,2.3),(0,-20.,4.9,7.0,7.6,2.5)],
        masts=[(16.,25.2,'bar',3.8),(-23.,14.2,'bar',2.4)],guns=[(0,53.,76,4.71)],
        vls=[(37.,4,4,.80,0),(-15.,4,4,.65,2.4)],canisters=[(-8.,3.1,4)],ciws=[(0,29.,3.0),(0,-33.,6.1)],hangar_z=-44.1)
    lattice(r,s,lod,0,16.,25.2,1.65);fittings(r,s,lod,-4.)
    s.representative='Murasame76mm and splitMk41/Mk48baseline; not Takanami127mm/all-forwardMk41. Public dimensions; bank count/position and local exterior details estimated. No all-hull missile fit or availability certification.'
    return r,s

def destroyer__takanami_class(lod=0):
    r,s=combatant('destroyer__takanami_class','Takanami class',lod,(151.,17.4,5.3,5.6),ROOT+'dd/takanami/',
        ['127mmL54bow gun','one32-cellforwardMk41bank; no midshipMk48','tall lattice mast','two separated raked funnels','eightSSM containers','revised bridge and upper deck','single helicopter hangar and twoPhalanx'],
        houses=[(0,19.,13.5,31.,7.3,0,.84),(0,-29.,13.6,28.,6.1,0,.93)],
        funnels=[(0,-1.,4.9,7.1,8.1,2.2),(0,-19.,4.9,7.0,7.7,2.3)],
        masts=[(16.5,25.7,'bar',3.8),(-23.,15.,'bar',2.5)],guns=[(0,53.,127,6.86)],
        vls=[(37.,8,4,.80,0)],canisters=[(-8.,3.1,4)],ciws=[(0,29.,3.0),(0,-32.,6.3)],hangar_z=-43.1)
    lattice(r,s,lod,0,16.5,25.7,1.63);fittings(r,s,lod,-3.)
    s.representative='Takanami public127mmL54 fit, consolidated forward VLS and revised bridge; close sister-family hull remains distinct from Murasame76mm/splitbanks. Local geometry and bank layout estimates.'
    return r,s

def destroyer__akizuki_class(lod=0):
    r,s=combatant('destroyer__akizuki_class','Akizuki class',lod,(151.,18.3,5.4,5.5),ROOT+'dd/akizuki/',
        ['wider18.3m general-purpose destroyer','127mmL62gun','32closed forwardMk41cells','integrated forward/aftFCS3A fixed faces','low enclosed stepped bridge','two separated funnels','single helicopter hangar','eightSSM containers and twoPhalanx'],
        houses=[(0,20.,14.7,34.,7.9,0,.84),(0,-30.,14.7,28.,6.3,0,.91)],
        funnels=[(0,-1.,5.2,7.8,8.3,2.3),(0,-18.,5.0,7.7,8.0,2.4)],
        masts=[(17.,23.8,'bar',3.1),(-29.,14.3,'bar',2.1)],guns=[(0,54.,127,7.87)],
        vls=[(38.,8,4,.80,0)],canisters=[(-9.,3.1,4)],ciws=[(0,30.,2.6),(0,-33.,6.6)],hangar_z=-44.1)
    fixed_arrays(r,s,lod);fittings(r,s,lod,-4.)
    s.representative='Akizuki/FCS3A public exterior, not an Aegis destroyer. MainL62gun corroborated by current Fuyuzuki operator page. Fixed faces remain static; navigation radarY. Small fittings/bank layout estimated.'
    return r,s

def destroyer__asahi_class(lod=0):
    r,s=combatant('destroyer__asahi_class','Asahi class',lod,(150.5,18.3,5.4,5.5),ROOT+'dd/asahi/',
        ['150.5m hybrid-propulsion ASW destroyer','127mmL62gun','32closedforwardMk41cells','integratedOPY1 fixed radar faces','different raised forward sensor shoulders','two exhaust enclosures','single helicopter hangar','towed-sonar stern aperture and twoPhalanx'],
        houses=[(0,19.,14.8,35.,8.5,0,.81),(0,-29.,14.8,29.,6.5,0,.90)],
        funnels=[(0,-1.8,5.0,7.4,7.7,2.6),(0,-18.5,4.7,7.2,7.6,2.7)],
        masts=[(16.5,24.4,'bar',3.0),(-29.,14.8,'bar',2.1)],guns=[(0,53.5,127,7.87)],
        vls=[(37.,8,4,.80,0)],canisters=[(-10.,3.1,4)],ciws=[(0,29.,2.8),(0,-32.,6.8)],hangar_z=-43.6)
    fixed_arrays(r,s,lod,asahi=True);fittings(r,s,lod,-4.)
    m=Mesh();m.box('metal_dark',(0,6.5,-75.30),(4.1,1.55,.06))
    r.add('Towed_Sonar_Aperture','Hull',(0,6.5,-75.30),m)
    s.representative='Asahi ASW/hybrid class, operator150.5m length; maintenance table rounds151m and gives5.4m draft. OPY1integrated exterior and towed sonar, not identical Akizuki fit. Cell layout/local hull contours estimates.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith('destroyer__') and callable(f)}
def save(slug):
    saver.BUILDERS[slug]=BUILDERS[slug];e=saver.save(slug)
    # Reopen custom banks independently; count actual authored centres rather
    # than disguising29/61as a rectangular32/64bank in the generic validator.
    from vehicle_parts import read_glb,walk_nodes
    doc,meshes=read_glb(saver.common.ART/e['file']);by={p:n for p,n,_,_ in walk_nodes(doc,canonical=True)}
    for lod in (0,1):
        for bank in doc['extras']['spec']['details'].get('custom_vls_banks',[]):
            n=by[f'LOD{lod}/Hull/'+bank['name']];assert n['extras']['cell_count']==bank['cells']==len(bank['positions'])
            if lod==0:
                child=by[f'LOD{lod}/Hull/'+bank['name']+'/'+bank['name']+'_Mesh']
                assert sum(len(g['f']) for g in meshes[child['mesh']] if g['role']=='metal_dark')==bank['cells']*12
    e['notes']+=' Original generator generate_inventory_additions_16.py. Per-class public exterior estimates; exact current national missile upgrade and serviceability not certified.'
    return e
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(x) for x in BUILDERS],indent=2)+'\n',encoding='utf-8')
