'use strict';

// Purpose-built airframes and naval silhouettes. Shared physically based
// surfaces, smooth hull sections and restrained markings replace toy blocks.
let serviceMaterials;
function servicePalette() {
  return serviceMaterials ||= {
    paint: new THREE.MeshStandardMaterial({ color: 0x747f83, roughness: .62, metalness: .32 }),
    deck: new THREE.MeshStandardMaterial({ color: 0x444f52, roughness: .9, metalness: .12 }),
    rubber: new THREE.MeshStandardMaterial({ color: 0x252e31, roughness: .77, metalness: .08 }),
    glass: new THREE.MeshStandardMaterial({ color: 0x344e59, roughness: .13, metalness: .65 }),
    steel: new THREE.MeshStandardMaterial({ color: 0x697172, roughness: .39, metalness: .72 }),
    seam: new THREE.MeshStandardMaterial({ color: 0x485459, roughness: .72 }),
    marking: new THREE.MeshStandardMaterial({ color: 0xc5c5b5, roughness: .8 }),
    bronze: new THREE.MeshStandardMaterial({ color: 0x857342, roughness: .4, metalness: .8 }),
  };
}
function makeServiceVehicle(key, color) {
  if (!['jet', 'bomber', 'submarine', 'nuclearSub', 'destroyer', 'corvette', 'gunboat'].includes(key)) return null;
  const g = new THREE.Group(), p = servicePalette(); g.name = `${key}-service-model`;
  const add = (geometry, mat, x = 0, y = 0, z = 0, parent = g) => {
    const mesh = new THREE.Mesh(geometry, mat); mesh.position.set(x,y,z);
    mesh.castShadow = mesh.receiveShadow = true; parent.add(mesh); return mesh;
  };
  const slab = (w,h,d,x,y,z,mat=p.paint,parent=g) => add(new THREE.BoxGeometry(w,h,d),mat,x,y,z,parent);
  const tube = (r,h,x,y,z,mat=p.steel) => add(new THREE.CylinderGeometry(r,r,h,12),mat,x,y,z);
  const body = (sections,mat,y=0) => {
    const mesh = add(new THREE.LatheGeometry(sections.map(([x,r])=>new THREE.Vector2(r,x)),32),mat,0,y,0);
    mesh.rotation.z = -Math.PI/2; return mesh;
  };
  const wing = (points,thickness,x,y,z,mat=p.paint) => {
    const mesh = finMesh(points,thickness,mat); mesh.position.set(x,y,z); g.add(mesh); return mesh;
  };
  const badge = new THREE.MeshStandardMaterial({ color, roughness:.65, metalness:.15 });
  if (key === 'submarine' || key === 'nuclearSub') {
    const nuclear = key === 'nuclearSub', length = nuclear ? 9 : 7, r = nuclear ? .75 : .62;
    body([[-length*.53,.04],[-length*.46,r*.38],[-length*.34,r*.86],[-length*.22,r],
      [length*.28,r],[length*.4,r*.94],[length*.48,r*.62],[length*.51,0]],p.rubber,.08);
    // A curved sail, hydroplanes and aft control surfaces, with subdued
    // acoustic tile joints instead of a bright team-colour cap.
    const sail = add(new THREE.SphereGeometry(1,24,16),p.rubber,.75,.8,0);
    sail.scale.set(.75,1,.25);
    wing([[-.35,-.9],[.22,-.9],[.4,.9],[-.35,.9]],.06,.8,.95,0,p.rubber);
    for (const side of [-1,1]) {
      wing([[-.65,0],[.3,0],[-.25,side*1.2],[-.6,side*1.2]],.055,-length*.38,.08,0,p.rubber);
      const fin = slab(.58,.8,.065,-length*.4,side*.38+.08,0,p.rubber); fin.rotation.z = -.24;
    }
    tube(.035,.7,.9,1.92,0); slab(.19,.075,.065,.97,2.25,0,p.steel);
    tube(.025,.46,.5,1.8,.1);
    for (let i=0;i<7;i++) {
      const ring = add(new THREE.TorusGeometry(r+.003,.008,4,40),p.seam,-length*.22+i*length*.077,.08,0);
      ring.rotation.y=Math.PI/2;
    }
    if(nuclear) for(let i=0;i<5;i++) for(const side of [-1,1]) {
      const hatch=add(new THREE.CylinderGeometry(.18,.18,.025,16),p.seam,-1.8+i*.46,.805,side*.22);
      hatch.rotation.z=.02;
    }
    const prop = new THREE.Group(); prop.position.set(-length*.54,.08,0); g.add(prop); g.userData.prop=prop;
    for(let i=0;i<7;i++) {
      const arm=new THREE.Group(); arm.rotation.x=i*Math.PI*2/7; prop.add(arm);
      const blade=slab(.065,.43,.16,0,.24,0,p.bronze,arm); blade.rotation.y=.48; blade.rotation.x=.25;
    }
    slab(.22,.1,.012,.75,1.44,.254,badge);
  } else if (key === 'jet' || key === 'bomber') {
    const bomber=key==='bomber', size=bomber?1.32:1;
    body([[-2.7,.26],[-2.1,.4],[-.7,.46],[.65,.35],[1.8,.24],[2.8,0]],p.paint,1);
    const canopy=add(new THREE.SphereGeometry(1,24,16),p.glass,1.05,1.34,0); canopy.scale.set(.88,.28,.27);
    // Swept leading edges, thin trailing edges and separate control surfaces.
    for(const side of [-1,1]) {
      wing([[.8,0],[-.7,side*(bomber?3.7:2.5)],[-1.6,side*(bomber?3.7:2.5)],[-1.2,0]],.075,-.15,1,0);
      wing([[.35,0],[-.35,side*1.15],[-.95,side*1.15],[-.75,0]],.065,-1.75,1.12,0);
      const intake=slab(.8,.32,.38,-.12,.86,side*.44,p.seam); intake.rotation.z=-.06;
      slab(.025,.25,.29,.29,.86,side*.44,p.rubber);
      const fin=wing([[-.75,0],[.15,0],[-.5,1.15],[-.8,1.15]],.07,-1.55,1.05,side*.26);
      fin.rotation.x=-Math.PI/2+side*.16;
      slab(.72,.012,.022,-.88,1.05,side*1.42,p.seam);
      slab(.22,.013,.18,-.85,1.06,side*1.85,badge);
      const nozzle=tube(.22,.42,-2.55,1,side*.2,p.steel); nozzle.rotation.z=Math.PI/2;
      const cavity=tube(.17,.03,-2.78,1,side*.2,p.rubber); cavity.rotation.z=Math.PI/2;
      if(bomber) for(const z of [1.5,2.5]) {
        const engine=body([[-.65,.18],[-.45,.22],[.5,.22],[.65,.16]],p.paint,.74);
        engine.position.x=-.85; engine.position.z=side*z;
      }
    }
    for(let i=0;i<5;i++) slab(.018,.012,.63,-1.7+i*.62,1.43,0,p.seam);
    g.userData.displayScale=size;
  } else {
    const destroyer=key==='destroyer', length=destroyer?10:7, beam=destroyer?2.3:1.8;
    const hull=shipHull(length,beam,.68,p.paint); hull.position.y=.72;g.add(hull);
    const deck=shipHull(length*.95,beam*.91,.09,p.deck); deck.position.y=.78;g.add(deck);
    slab(length*.38,.45,beam*.69,-.35,1.02,0);
    const bridge=slab(1.35,.65,beam*.54,.2,1.54,0);bridge.rotation.z=-.035;
    // Individual bridge glazing, deck hatches, lifeboats and rail stanchions.
    for(let i=0;i<5;i++) slab(.028,.2,.14,.88,1.7,-beam*.21+i*beam*.105,p.glass);
    for(const side of [-1,1]) {
      slab(1.08,.18,.025,.15,1.7,side*beam*.28,p.glass);
      for(let i=0;i<16;i++) tube(.016,.27,-length*.39+i*length*.045,1.0,side*beam*.39);
      slab(length*.72,.022,.022,-length*.055,1.14,side*beam*.39,p.steel);
      const boat=add(new THREE.SphereGeometry(1,12,8),p.rubber,-1.55,1.15,side*beam*.31);boat.scale.set(.58,.16,.18);
      for(let i=0;i<3;i++) slab(.36,.045,.3,.95+i*.4,.91,side*.3,p.seam);
    }
    const mast=tube(.055,1.5,-.5,2.35,0);
    const radar=slab(.86,.16,.12,-.5,3.05,0,p.steel);g.userData.spin=radar;
    slab(.75,.6,.56,-1.5,1.7,0,p.paint);slab(.68,.04,.49,-1.5,2.02,0,p.rubber);
    const turret=new THREE.Group();turret.position.set(length*.3,.93,0);g.add(turret);g.userData.turret=turret;
    slab(.7,.36,.64,0,.1,0,p.paint,turret);
    const gun=add(new THREE.CylinderGeometry(.045,.075,1.2,12),p.steel,.72,.2,0,turret);gun.rotation.z=-Math.PI/2;
    // Aft helicopter landing pad stays painted flat onto the deck.
    for(const side of [-1,1]) slab(.7,.012,.035,-length*.29,.86,side*.28,p.marking);
    slab(.035,.012,.56,-length*.29,.86,0,p.marking);
    slab(.25,.12,.012,.3,1.28,beam*.35,badge);
  }
  g.userData.faceOffset=-Math.PI/2;
  batchBuildingGeometry(g);
  if(g.userData.displayScale) g.scale.setScalar(g.userData.displayScale);
  return g;
}
