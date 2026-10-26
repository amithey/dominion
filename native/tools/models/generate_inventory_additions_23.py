"""Original Korean fighter variants; public sizes, estimated exterior fittings.

One builder per real airframe. No downloaded meshes, Blender, textures or
functional weapon internals. Operator/contract/retirement evidence is separate.
"""
from pathlib import Path
from dataclasses import asdict
import argparse,json,math
import numpy as np
import generate_p6_aircraft as planes
from aircraft_parts import AircraftSpec,build,curved_shell,interpolate,burnt_wreck
from generate_inventory_additions_12 import remove
from vehicle_parts import Mesh,hollow_muzzle,loft,write_glb

DEMA='https://kookbang.dema.mil.kr/newsWeb/'
PW='https://app.prattwhitney.com/2024-02-13-RTXs-Pratt-Whitney-receives-a-355-million-F100-engine-sustainment-contract-for-South-Koreas-F-15s%2C-F-16s'

def stations(r,s,lod,fractions,tips=False,centre=True,cft=False):
    """Empty representative external racks; no arbitrary six-missile load."""
    for p in list(r.parts):
        if p['name'].startswith(('Pylon_','Store_')):remove(r,p['name'])
    count=s.details['muzzle_count'];positions=s.details['muzzle_positions']
    def mount(name,parent,p,width=.12,height=.30,length=.85):
        nonlocal count
        p=np.array(p);m=Mesh();m.box('paint',p,(width,height,length))
        r.add(name,parent,p+[0,height/2,0],m)
        tip=p+[0,-height/2,length/2];r.add('Muzzle_'+str(count),name,tip)
        positions['Muzzle_'+str(count)]=tip.tolist();count+=1
    for side,label in ((-1,'L'),(1,'R')):
        for i,f in enumerate(fractions):
            q=interpolate(s.details['wing'],s.span/2*f)
            mount('Pylon_'+label+str(i),'Wing_'+label,[side*q[0],q[1]-.17,(q[2]+q[3])/2],height=.40 if cft else .30)
        if tips:
            q=s.details['wing'][-1];mount('Wingtip_Rail_'+label,'Wing_'+label,[side*(s.span/2-.06),q[1],(q[2]+q[3])/2],.12,.12,1.70)
    if centre:mount('Pylon_Centre','Fuselage',[0,s.belly-.12,-.45],.16,.28,1.2)
    if cft:
        cy=s.belly+s.body_height/2
        for side,label in ((-1,'L'),(1,'R')):
            for row in (0,1):
                for i,z in enumerate((-4.4,-2.,.6)):
                    mount('CFT_Rack_'+label+str(row)+'_'+str(i),'Conformal_Tank_'+label,[side*(1.65 if row==0 else 1.98),cy-(.85 if row==0 else .42),z],.16,.24,.80)
    s.details['muzzle_count']=count;s.details['muzzle_positions']=positions
    s.details['store_selection']='empty representative exterior racks; station/local support positions estimated, not actual sortie load'

def feathered_nozzles(r,s,lod,kind='F100'):
    """Closed decorative outer petal bands, recessed dark nozzle interior."""
    cy=s.belly+s.body_height/2;radius=s.details['engine_radius'];L=s.length
    for i in range(s.engines):
        p=next(p for p in r.parts if p['name']=='Engine_'+str(i));m=p['mesh'];m.groups.pop('metal_dark',None)
        x=(i-(s.engines-1)/2)*s.details.get('engine_spacing',s.body_width*.62)
        n=15 if kind=='F100' else 16
        hollow_muzzle(m,(x,cy,-L*.46),(x,cy,-L*.50),radius,radius*.82,8 if lod else 32)
        # Each strip is a closed thin surface, cosmetic rather than machinery.
        for a in np.linspace(0,math.tau,n,endpoint=False):
            da=math.tau/n*.42;rr=radius+(.012 if kind=='F100' else .018)
            rings=[]
            for z,scale in ((-L*.461,1.015),(-L*.497,.995)):
                rings.append([[x+rad*math.cos(t),cy+rad*math.sin(t),z] for rad,t in [(rr*scale,a-da),(rr*scale,a+da),((rr-.012)*scale,a+da),((rr-.012)*scale,a-da)]])
            loft(m,'metal_dark',rings)
    s.details['engine_family']=kind;s.details['nozzle_limits']='outer petal count/shape is a decorative approximation; no independently certified nozzle dimensions or machinery'

def small_inlet(r,s,lod):
    p=next(p for p in r.parts if p['name']=='Intake');m=Mesh();z=s.length*.20;cy=s.belly+.05;n=8 if lod else 28
    outer=[];inner=[]
    for zz,yy,wx,hy in ((z,cy,.55,.33),(-s.length*.05,s.belly+s.body_height/2,.50,.44)):
        outer.append(np.array([[wx*math.sin(a),yy+hy*math.cos(a),zz] for a in np.linspace(0,math.tau,n,endpoint=False)]))
        inner.append(np.array([[(wx-.055)*math.sin(a),yy+(hy-.055)*math.cos(a),zz] for a in np.linspace(0,math.tau,n,endpoint=False)]))
    for i in range(n):
        j=(i+1)%n;normal=(outer[0][i]+outer[0][j])/2-[0,cy,z]
        m.face('paint',[outer[0][i],outer[0][j],outer[1][j],outer[1][i]],normal)
        m.face('metal_dark',[inner[0][i],inner[1][i],inner[1][j],inner[0][j]],-normal)
        m.face('paint',[outer[0][i],inner[0][i],inner[0][j],outer[0][j]],[0,0,1])
    m.face('metal_dark',inner[1],[0,0,1]);p['mesh']=m

def korean_falcon(slug,name,lod,seats):
    _,s=planes.model(slug,name,lod,'f16',seats)
    s.source=PW;s.details.update({'stations':[],'engine_radius':.48,'canopy_front':.285,'canopy_rear':.055 if seats==2 else .125})
    r,s=build(s,lod);small_inlet(r,s,lod);feathered_nozzles(r,s,lod)
    stations(r,s,lod,(.40,.64,.82),tips=True)
    m=Mesh();y=s.belly+s.body_height*.91
    for x in (-.18,-.06,.06,.18):m.box('paint',(x,y,s.length*.31),(.03,.12,.45))
    r.add('IFF_Blades','Fuselage',(0,y,s.length*.31),m,fit='representative external IFF blades; upgrade completion not asserted')
    s.features+=['Pratt and Whitney F100 family, small-mouth representative inlet','no conformal tanks or export dorsal spine','empty wingtip/underwing/centre racks']
    s.representative='Korean Block52 KF16 '+('tandem-seat D' if seats==2 else 'single-seat C')+' exterior; published F16family principal size and national manufacturer/operator references. F100PW229family, local inlet/nozzle/antenna geometry estimated. Early imported Block32/F100PW220 and completed fleet-wide Viper upgrade not automatically represented.'
    return r,s

def lightFighter__kf_16c(lod=0):return korean_falcon('lightFighter__kf_16c','KF-16C Block52',lod,1)
def lightFighter__kf_16d(lod=0):return korean_falcon('lightFighter__kf_16d','KF-16D Block52',lod,2)

def korean_tiger(slug,name,lod,seats):
    L=15.7 if seats==2 else 14.45;shift=(L-14.45)/2;S=8.13;H=4.0 if seats==2 else 4.07;y=1.02+1.35*.48
    wing=[(.38,y,.9-shift,-2.6-shift),(2.15,y,-.25-shift,-2.5-shift),(S/2,y,-1.65-shift,-2.4-shift)]
    profile=[(-.455,0,.3,.35),(-.34,0,.50,.49),(-.12,0,.5,.5),(.12,.01,.39,.44),(.28,.02,.31,.32),(.42,0,.16,.18),(.5,0,.008,.015)]
    if seats==2:
        profile=[((z*14.45+(-shift if z<.12 else shift))/L,cy,wx,hy) for z,cy,wx,hy in profile]
    s=AircraftSpec(slug,name,'f5',L,S,H,1.15,1.35,1.02,2,DEMA+'20190116/1/ATCE_CTGR_0080040001/view.do',seats=seats,
        features=['KF5 Korean-built TigerII, not retired imported fleet','two small J85 engine nozzles','small swept wings and leading edge extensions','one long single-seat canopy' if seats==1 else 'longer forebody and TWO separately hinged tandem canopies','empty two-per-wing racks, wingtip rails and centre rack'],
        details={'wing':wing,'fins':[(0,2.05,H,-2.5-shift,-6.4-shift,-4.3-shift,-5.55-shift)],
          'engine_spacing':.66,'engine_radius':.30,'engine_aft_fraction':.50,'side_intakes':True,'intake_x':.64,'intake_z':.14,'intake_width':.45,'intake_height':.48,
          'gun_count':1 if seats==2 else 2,'gun_side':-1,'gun_fraction':.33,'gun_width':.25,'lex':True,'stations':[],
          'stabilator':[(.38,1.78,-3.6-shift,-6.2-shift),(2.1,1.78,-5.-shift,-6.-shift)],'profile':profile,'canopy_front':.30,'canopy_rear':.13})
    r,s=build(s,lod)
    if seats==2:
        remove(r,'Canopy');top=s.belly+s.body_height
        for i,(name,a,b) in enumerate((('Canopy',3.10,4.95),('Canopy_Rear',.90,2.75))):
            m=Mesh()
            def glazing(z,t):return 'paint' if abs(z-a)<.03 or abs(z-b)<.03 else 'glass'
            curved_shell(m,'glass',[(a,top-.08,.17,.10),(a+.35,top+.15,.33,.43),(b-.35,top+.15,.30,.43),(b,top-.03,.13,.10)],lod,glazing)
            r.add(name,'Fuselage',(0,top-.08,a),m,'X',fit='photo-informed independently rear-hinged canopy; local frame dimensions estimated')
        m=Mesh();curved_shell(m,'glass',[(4.94,top+.04,.24,.30),(5.25,top-.02,.17,.16),(5.52,top-.10,.08,.045)],lod)
        r.add('Windscreen','Fuselage',(0,top-.10,5.52),m)
        m=Mesh();loft(m,'paint',[[[-.26,1.75,4.90],[.26,1.75,4.90],[.26,2.40,4.90],[-.26,2.40,4.90]],
            [[-.09,1.72,5.60],[.09,1.72,5.60],[.09,2.22,5.60],[-.09,2.22,5.60]]])
        r.add('Windscreen_Base','Fuselage',(0,2.0,5.25),m)
    m=Mesh();front=4.95 if seats==2 else L*.30;rear=.90 if seats==2 else L*.13
    m.box('paint',(0,2.08,(front+rear)/2),(.50,.58,front-rear));r.add('Cockpit_Sill','Fuselage',(0,2.08,(front+rear)/2),m)
    stations(r,s,lod,(.45,.73),tips=True)
    s.representative='Korean-built KF5'+('F tandem long-nose variant,15.7m F5Ffamily reference, not incorrectly14.45m single-seater' if seats==2 else 'E single-seat14.45m Navy/DMApublished size')+'. Current Korean family/retirement timetable separately researched; not all imported F5E/Fstill active. Korean historical photos used for outer form; exact current per-airframe radome, cannon fit and sensors remain unverified. Selected '+('one left' if seats==2 else 'two')+' nose gun-port layout is representative; no functional internals.'
    return r,s

def lightFighter__kf_5e(lod=0):return korean_tiger('lightFighter__kf_5e','KF-5E Jegongho',lod,1)
def lightFighter__kf_5f(lod=0):return korean_tiger('lightFighter__kf_5f','KF-5F Jegongho',lod,2)

def jet__f_15k_slam_eagle(lod=0):
    _,s=planes.model('jet__f_15k_slam_eagle','F-15K Slam Eagle GE representative',lod,'f15',2,True)
    s.source=DEMA+'20260930/1/ATCE_CTGR_0020010033/view.do';s.details.update({'stations':[],'cft':False,'canopy_front':.315,'canopy_rear':.13})
    r,s=build(s,lod);cy=s.belly+s.body_height/2
    for side,label in ((-1,'L'),(1,'R')):
        m=Mesh();curved_shell(m,'paint',[(-6.7,cy-.28,.15,.25),(-5.2,cy-.28,.43,.58),(0,cy-.25,.43,.58),(2.5,cy-.22,.15,.28)],lod,circumference=8 if lod else 24,longitudinal=2 if lod else 5,cross_power=.8)
        m.shift((side*1.65,0,0));r.add('Conformal_Tank_'+label,'Fuselage',(side*1.65,cy-.25,-2),m)
    feathered_nozzles(r,s,lod,'F110');stations(r,s,lod,(.50,),cft=True)
    m=Mesh();y=s.details['wing'][-1][1]
    for side in (-1,1):
        m.tube('paint',(side*s.span*.48,y+.05,-2.6),(side*s.span*.48,y+.05,-3.25),.08,6 if lod else 16,.04)
    r.add('Wingtip_Antennae','Fuselage',(0,y+.05,-2.9),m)
    s.details['national_conformal_tanks']=True
    s.features+=['Korean tandem F15K with separate conformal tanks and short exterior CFT racks','representative F110GE129 earlier-lot exterior','two main wing pylons, no invented EXouterwing stations','Pratt and Whitney powered later lot documented separately, not claimed identical engine fit']
    s.representative='F15K is separate from existing KF21-only combined-label asset. GEpowered earlier-lot representative, twin-seat canopy, conformal tanks and short racks; approximate F15family19.44x13.05x5.6m. National current photos inspected; public Korean rounded size19.4x13x5.7also noted. Later F100PW229EEP aircraft and upgrades need separate installed-fit comparison; no claim this GEexterior covers every airframe or all planned AESAradar upgrades completed. Decorative nozzle/petal and station dimensions estimated, no live sortie load.'
    return r,s

BUILDERS={n:f for n,f in list(globals().items()) if n.startswith(('jet__','lightFighter__')) and callable(f)}
def save(slug):
    def checked(lod):
        r,s=BUILDERS[slug](lod)
        for p in r.parts:
            if p['mesh'] is not None:p['mesh'].remove_duplicates()
        return r,s
    from validate_aircraft import validate
    a,s=checked(0);b,t=checked(1);assert asdict(s)==asdict(t)
    # Bound the actual central body, including inlets, engine nacelles, cockpit
    # and conformal tanks. A nominal thin fuselage box would miss these parts.
    points=[]
    for r in (a,b):
        for p in r.parts:
            if p['mesh'] is not None and p['name'].startswith(('Fuselage','Engine_','Intake','Conformal_Tank_','Canopy','Windscreen','Cockpit_Sill')):
                points.extend(g[0] for g in p['mesh'].groups.values() if g[0])
    p=np.concatenate(points);lo,hi=p.min(0),p.max(0);lo[1]=0
    c=Mesh();c.box('metal_dark',(lo+hi)/2,hi-lo);path=planes.ART/'aircraft'/(slug+'.glb')
    write_glb(path,[a,b],burnt_wreck(b,s),c,{'scene_name':s.name,'vehicle':slug,'priority':'P6','spec':asdict(s),'units':'metres','up':'+Y','front':'+Z','research_addition':True})
    e,tree=validate(path);(Path(__file__).parent/'reports'/(slug+'.node-tree.txt')).write_text(tree,encoding='utf-8');print(tree);print('PASS',slug,e['triangles'],flush=True)
    e['notes']+=' Original generate_inventory_additions_23.py. Source distinctions/current orders/retirements and explicit exterior uncertainties in research/evidence.json.'
    return e

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    a.report.write_text(json.dumps([save(n) for n in BUILDERS],indent=2)+'\n',encoding='utf-8')
