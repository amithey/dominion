'use strict';

// Shared materials and batched geometry keep architectural detail inexpensive.
let sitePalette;
function getSitePalette() {
  if (sitePalette) return sitePalette;
  const canvas = document.createElement('canvas'); canvas.width = canvas.height = 256;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#8d918c'; ctx.fillRect(0, 0, 256, 256);
  for (let row = 0; row < 8; row++) for (let col = -1; col < 8; col++) {
    const shade = 155 + ((row * 31 + col * 17) & 15);
    ctx.fillStyle = `rgb(${shade},${shade + 2},${shade})`;
    ctx.fillRect(col * 32 + (row % 2) * 16 + 1, row * 32 + 1, 30, 30);
  }
  const paving = new THREE.CanvasTexture(canvas);
  paving.wrapS = paving.wrapT = THREE.RepeatWrapping;
  paving.repeat.set(3, 3); paving.colorSpace = THREE.SRGBColorSpace;
  paving.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  sitePalette = {
    paving: new THREE.MeshStandardMaterial({ map: paving, color: 0xb2b1a5, roughness: .92 }),
    curb: new THREE.MeshStandardMaterial({ color: 0x92978d, roughness: .86 }),
    steel: new THREE.MeshStandardMaterial({ color: 0x3f4b4e, roughness: .48, metalness: .65 }),
    timber: new THREE.MeshStandardMaterial({ color: 0x73604a, roughness: .85 }),
    vent: new THREE.MeshStandardMaterial({ color: 0x6e7b7c, roughness: .64, metalness: .4 }),
    marking: new THREE.MeshStandardMaterial({ color: 0xd1c79d, roughness: .85 }),
  };
  return sitePalette;
}

function dressArchitecture(root, key) {
  const industrial = ['tankFactory', 'warehouse', 'barracks', 'powerPlant', 'oilRefinery', 'chipFab', 'foodDepot', 'ammoDepot'].includes(key);
  const civic = ['hq', 'housing', 'residential', 'apartments', 'market', 'workerHouse', 'cottage', 'cityHall', 'courthouse', 'bank', 'tvStation', 'intelAgency', 'techPark', 'university', 'hospital', 'school', 'library', 'museum', 'policeStation', 'commandCenter'].includes(key);
  if (!industrial && !civic) return root;
  const p = getSitePalette(), bounds = new THREE.Box3().setFromObject(root);
  const width = Math.min(20, bounds.max.x - bounds.min.x);
  const depth = Math.min(20, bounds.max.z - bounds.min.z);
  const cx = (bounds.min.x + bounds.max.x) / 2;
  const front = bounds.max.z;
  const group = new THREE.Group(); group.name = 'architectural-details'; root.add(group);
  const box = (w, h, d, x, y, z, material, shadow = true) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z); mesh.castShadow = shadow; mesh.receiveShadow = true;
    group.add(mesh); return mesh;
  };
  // A shallow entrance terrace, rather than a pedestal beneath the whole model.
  box(width, .08, 2.2, cx, .045, front + .9, p.paving, false);
  for (const side of [-1, 1]) {
    box(.16, .18, 2.2, cx + side * width / 2, .09, front + .9, p.curb);
    // Safety bollards frame the entrance without hiding the silhouette.
    box(.13, .65, .13, cx + side * width * .35, .325, front + 1.75, p.steel);
  }
  if (industrial) {
    // Loading-bay markings and stacked cargo give factories a working yard.
    for (let i = 0; i < 4; i++)
      box(.1, .015, 1.3, cx - width * .3 + i * width * .2, .095, front + .9, p.marking, false);
    for (let i = 0; i < 3; i++) {
      const x = bounds.min.x + .5 + i * .65;
      box(.55, .48, .65, x, .3, front + .6, p.timber);
      box(.04, .5, .67, x, .3, front + .6, p.steel);
    }
  } else {
    for (const side of [-1, 1]) {
      const x = cx + side * width * .32;
      box(1.2, .12, .4, x, .48, front + .85, p.timber);
      box(1.2, .4, .09, x, .7, front + .68, p.timber);
      for (const leg of [-.42, .42]) box(.08, .43, .32, x + leg, .22, front + .85, p.steel);
    }
  }
  // Service equipment sits beside the wall; authored roofs may be pitched.
  if (['tankFactory', 'warehouse', 'barracks'].includes(key)) {
    const y = .12;
    box(Math.min(1.8, width * .2), .55, 1.1, cx + width * .2, y + .24, front + .55, p.vent);
    for (let i = 0; i < 6; i++)
      box(.06, .035, .9, cx + width * .2 - .45 + i * .18, y + .535, front + .55, p.steel, false);
  }
  return root;
}
