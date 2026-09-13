'use strict';

function fitBuildingToHex(root) {
  root.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(root);
  const apothem = 12 * Math.sqrt(3) / 2 - .55;
  let extent = 0;
  // Conservative footprint containment against all six hex edge planes,
  // including roofs, chimneys and ancillary structures, not just the core.
  for (let side = 0; side < 6; side++) {
    const a = side * Math.PI / 3, nx = Math.cos(a), nz = Math.sin(a);
    for (const x of [bounds.min.x, bounds.max.x]) for (const z of [bounds.min.z, bounds.max.z])
      extent = Math.max(extent, x * nx + z * nz);
  }
  if (extent > apothem) root.scale.multiplyScalar(apothem / extent);
  return root;
}
function makeBuildingVisual(key, color, seed = 0) {
  const core = batchBuildingGeometry(buildingMesh(key, color, seed));
  const art = isNeighborhoodBuilding(key) ? settlementCluster(core, key, color, seed)
    : dressArchitecture(detailBuildingSite(core, key), key);
  return fitBuildingToHex(batchBuildingGeometry(art));
}

// One logical settlement occupies one hex, but contains a civic core, streets,
// and many houses. These are scenery, not separately selectable buildings.
function isHousingDistrict(key) { return ['cottage', 'housing', 'residential', 'apartments', 'luxuryVillas', 'workerHouse'].includes(key); }
function districtStyle(key) {
  if (['tankFactory', 'warehouse', 'barracks', 'powerPlant', 'oilRefinery', 'chipFab', 'foodDepot', 'ammoDepot'].includes(key)) return 'industrial';
  if (['market', 'cityHall', 'courthouse', 'bank', 'tvStation', 'intelAgency', 'techPark', 'university', 'hospital', 'school', 'library', 'museum', 'policeStation', 'commandCenter'].includes(key)) return 'civic';
  if (key === 'luxuryVillas') return 'garden';
  if (['apartments', 'residential'].includes(key)) return 'urban';
  return 'residential';
}
function isNeighborhoodBuilding(key) {
  return !!BUILDINGS[key].settlement || isHousingDistrict(key) || ['industrial', 'civic'].includes(districtStyle(key));
}
let neighborhoodMaterials;
function neighborhoodPalette() {
  if (neighborhoodMaterials) return neighborhoodMaterials;
  const texture = roof => {
    const c = document.createElement('canvas'); c.width = c.height = 128;
    const ctx = c.getContext('2d');
    ctx.fillStyle = roof ? '#93938d' : '#dad7ce'; ctx.fillRect(0, 0, 128, 128);
    for (let row = 0; row < 16; row++) for (let col = -1; col < 8; col++) {
      const v = (roof ? 122 : 198) + ((row * 13 + col * 7) & 15);
      ctx.fillStyle = `rgb(${v},${v},${v})`;
      ctx.fillRect(col * 16 + (row % 2) * 8, row * 8, 15, 7);
    }
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
    t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 4; return t;
  };
  const brick = texture(false), tile = texture(true);
  neighborhoodMaterials = {
    walls: [0xd4c6ac, 0xbabcae, 0xc0a08b].map(color => new THREE.MeshStandardMaterial({ color, map: brick, roughness: .88 })),
    roofs: [0x93634b, 0x68736d, 0x73695b].map(color => new THREE.MeshStandardMaterial({ color, map: tile, roughness: .8 })),
    trim: new THREE.MeshStandardMaterial({ color: 0xdbd3bd, roughness: .8 }),
    stone: new THREE.MeshStandardMaterial({ color: 0x85877b, roughness: .94 }),
    door: new THREE.MeshStandardMaterial({ color: 0x524336, roughness: .84 }),
    glass: new THREE.MeshStandardMaterial({ color: 0x405d65, roughness: .25, metalness: .32 }),
    iron: new THREE.MeshStandardMaterial({ color: 0x444e4c, roughness: .5, metalness: .6 }),
  };
  return neighborhoodMaterials;
}
function settlementCluster(core, key, color, seed) {
  if (!isNeighborhoodBuilding(key)) return core;
  const root = new THREE.Group(); root.name = `${key}-district`;
  const style = districtStyle(key), industrial = style === 'industrial', civic = style === 'civic';
  const village = ['villageCenter', 'cottage', 'workerHouse', 'luxuryVillas'].includes(key);
  const radius = BUILDINGS[key].settlement ? (village ? 6 : 8.4) : Math.min(8.4, BUILDINGS[key].size * .85);
  const base = new THREE.MeshStandardMaterial({ color: village ? 0x85806a : 0x999b8b, roughness: .95 });
  const palette = neighborhoodPalette(), roofs = palette.roofs, glass = palette.glass;
  const road = new THREE.MeshStandardMaterial({ color: 0x64675f, roughness: 1 });
  const disk = new THREE.Mesh(new THREE.CylinderGeometry(radius + .7, radius + .7, .1, 6), base);
  disk.position.y = .04; disk.receiveShadow = true; root.add(disk);
  const bounds = new THREE.Box3().setFromObject(core), s = bounds.getSize(new THREE.Vector3());
  const scale = Math.min(industrial || civic ? radius * 1.02 : village ? 3.4 : 4.4, radius * 1.02) / Math.max(s.x, s.z, 1);
  core.scale.multiplyScalar(scale); root.add(core);
  // Preserve the existing animated core after static geometry batching.
  root.userData.core = core;
  const count = industrial ? 4 : civic || style === 'garden' ? 6 : radius < 4 ? 6 : village ? 8 : 12;
  for (let i = 0; i < count; i++) {
    const angle = i * Math.PI * 2 / count, ring = radius * (i % 2 ? .73 : .67);
    const block = new THREE.Group(), floors = industrial || village ? 1 : style === 'urban' ? 4 + i % 2 : civic ? 2 : 2 + ((i + seed) % 3);
    const w = Math.min(village ? 1.65 : 1.8, radius * .27), depth = w * .95, h = floors * Math.min(.9, radius * .18);
    const detail = (width, height, d, x, y, z, mat) => {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, d), mat);
      mesh.position.set(x, y, z); mesh.castShadow = mesh.receiveShadow = true; block.add(mesh); return mesh;
    };
    const body = new THREE.Mesh(new THREE.BoxGeometry(w, h, depth), industrial ? palette.stone : palette.walls[(i + seed) % 3]); body.position.y = h / 2;
    body.castShadow = body.receiveShadow = true; block.add(body);
    let chimneyOutlet = null;
    if (!industrial && style !== 'urban' && (village || i % 3)) {
      const shape = new THREE.Shape();
      shape.moveTo(-w * .56, 0); shape.lineTo(0, w * .4); shape.lineTo(w * .56, 0); shape.closePath();
      const roof = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: depth + .16, bevelEnabled: false }), roofs[i % 3]);
      roof.position.set(0, h, -depth / 2 - .08); roof.castShadow = true; block.add(roof);
      detail(.17, w * .5, .2, w * .27, h + w * .3, -depth * .2, palette.stone);
      chimneyOutlet = new THREE.Vector3(w * .27, h + w * .55, -depth * .2);
    } else {
      const roof = new THREE.Mesh(new THREE.BoxGeometry(w + .14, .12, depth + .14), roofs[i % 3]); roof.position.y = h + .06; block.add(roof);
    }
    detail(w + .07, .12, depth + .07, 0, .06, 0, palette.stone);
    detail(w + .12, .09, depth + .12, 0, h - .045, 0, palette.trim);
    // Roof drainage, recessed entrances and projecting shop canopies add
    // readable depth under sunlight from any camera angle.
    for(const side of [-1,1]) {
      detail(.035,h,.035,side*(w*.5+.035),h*.5,depth*.5,palette.iron);
      detail(w+.18,.045,.06,0,h,side*(depth*.5+.08),palette.iron);
    }
    if(!industrial) {
      const canopy=detail(w*.58,.065,.4,0,h/floors*.72,depth*.5+.18,roofs[(i+1)%3]);
      canopy.rotation.x=.1;
      if(village) for(const side of [-1,1]) detail(.045,h*.68,.045,side*w*.26,h*.34,depth*.5+.34,palette.trim);
    }
    const opening = Math.min(.3, w * .2), wh = Math.min(.4, h / floors * .46);
    for (let floor = 0; floor < floors; floor++) for (const face of [-1, 1]) for (const side of [-1, 1]) {
      const wx = side * w * .27, wy = (floor + .56) * h / floors, wz = face * (depth / 2 + .025);
      detail(opening + .08, wh + .08, .045, wx, wy, wz, palette.trim);
      detail(opening, wh, .025, wx, wy, wz + face * .03, glass);
      detail(.025, wh, .03, wx, wy, wz + face * .05, palette.trim);
      detail(opening + .12, .045, .12, wx, wy - wh / 2 - .025, wz, palette.stone);
    }
    detail(w * .21, h / floors * .62, .06, 0, h / floors * .31, depth / 2 + .035, palette.door);
    if (industrial) {
      detail(w * .72, h * .72, .07, 0, h * .36, depth / 2 + .08, palette.iron);
      for (let slat = 1; slat < 5; slat++) detail(w * .7, .025, .09, 0, h * .14 * slat, depth / 2 + .1, palette.trim);
    }
    // Side elevations stay finished when the player rotates the camera.
    for (let floor = 0; floor < floors; floor++) for (const face of [-1, 1]) for (const side of [-1, 1]) {
      const wx = face * (w / 2 + .025), wy = (floor + .56) * h / floors, wz = side * depth * .26;
      detail(.045, wh + .08, opening + .08, wx, wy, wz, palette.trim);
      detail(.025, wh, opening, wx + face * .03, wy, wz, glass);
      detail(.12, .045, opening + .12, wx, wy - wh / 2 - .025, wz, palette.stone);
    }
    detail(w * .34, .07, .34, 0, .04, depth / 2 + .15, palette.stone);
    if (!village && floors > 1) {
      detail(w * .72, .09, .38, 0, h / floors, depth / 2 + .13, palette.trim);
      detail(w * .72, .05, .045, 0, h / floors + .3, depth / 2 + .3, palette.iron);
      for (const side of [-1, 0, 1]) detail(.035, .3, .035, side * w * .34, h / floors + .15, depth / 2 + .3, palette.iron);
    }
    block.position.set(Math.cos(angle) * ring, .1, Math.sin(angle) * ring); block.rotation.y = -angle - Math.PI / 2; root.add(block);
    if (chimneyOutlet && !root.userData.districtSmoke) {
      block.updateMatrix(); root.userData.districtSmoke = chimneyOutlet.applyMatrix4(block.matrix);
    }
  }
  // Gardens and tree-lined plazas distinguish residential/civic districts
  // from the paved loading courts around industrial landmarks.
  const green = new THREE.MeshStandardMaterial({ color: 0x50654a, roughness: .95 });
  if (!industrial) for (let i = 0; i < (style === 'garden' ? 8 : 4); i++) {
    const a = (i + .5) * Math.PI / 2, r = radius * (i < 4 ? .88 : .43);
    const planter = new THREE.Mesh(new THREE.CylinderGeometry(.43, .47, .18, 8), palette.stone);
    planter.position.set(Math.cos(a) * r, .18, Math.sin(a) * r); root.add(planter);
    const crown = new THREE.Mesh(new THREE.IcosahedronGeometry(.48, 1), green);
    crown.scale.y = 1.4; crown.position.copy(planter.position); crown.position.y = .85; crown.castShadow = true; root.add(crown);
  }
  // A compact animated layer survives static batching. No per-frame scene
  // traversal or additional lights are needed for neighbourhood activity.
  const activity = new THREE.Group(); root.add(activity); root.userData.districtActivity = activity;
  const flag = new THREE.Mesh(new THREE.PlaneGeometry(.65, .36, 5, 1), new THREE.MeshStandardMaterial({ color, side: THREE.DoubleSide, roughness: .8 }));
  flag.position.set(.34, 1.95, radius * .38); activity.add(flag); activity.userData.flag = flag;
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(.025, .025, 2.1, 6), palette.iron);
  pole.position.set(0, 1.15, radius * .38); root.add(pole);
  const traffic = new THREE.Group();
  const carBody = new THREE.Mesh(new THREE.BoxGeometry(.27,.16,industrial?.65:.46),palette.iron);carBody.position.y=.08;traffic.add(carBody);
  const cab = new THREE.Mesh(new THREE.BoxGeometry(.24,.12,.22),palette.glass);cab.position.set(0,.2,industrial?.17:0);traffic.add(cab);
  for(const side of [-1,1]) for(const end of [-1,1]) {
    const wheel=new THREE.Mesh(new THREE.CylinderGeometry(.065,.065,.035,8),palette.door);
    wheel.rotation.z=Math.PI/2;wheel.position.set(side*.145,.025,end*.16);traffic.add(wheel);
  }
  activity.add(traffic); activity.userData.traffic = traffic;
  activity.userData.radius = radius * .43;
  for (let i = 0; i < 3; i++) {
    const street = new THREE.Mesh(new THREE.BoxGeometry(.62, .04, radius * 2), road);
    street.position.y = .115; street.rotation.y = i * Math.PI / 3; street.receiveShadow = true; root.add(street);
  }
  // Six-sided border communicates the building tile even with the map grid off.
  const points = [];
  for (let i = 0; i <= 6; i++) { const a = (i * 60 + 30) * Math.PI / 180; points.push(new THREE.Vector3(Math.cos(a) * (radius + .8), .13, Math.sin(a) * (radius + .8))); }
  root.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), new THREE.LineBasicMaterial({ color, transparent: true, opacity: .65 })));
  return root;
}
