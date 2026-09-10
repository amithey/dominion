'use strict';

// A fixed GPU buffer keeps explosions and exhaust from allocating one mesh
// per puff. Oldest particles are recycled under heavy combat.
const BATTLE_FX = { capacity: 1200, next: 0, particles: [], mesh: null };
function initBattleVisuals() {
  const fx = BATTLE_FX, geometry = new THREE.BufferGeometry();
  for (const [name, width] of [['position', 3], ['color', 3], ['particleSize', 1], ['alpha', 1], ['seed', 1]])
    geometry.setAttribute(name, new THREE.BufferAttribute(new Float32Array(fx.capacity * width), width).setUsage(THREE.DynamicDrawUsage));
  const material = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false,
    uniforms: { viewportHeight: { value: 900 } },
    vertexShader: `attribute float particleSize, alpha, seed; attribute vec3 color;
      varying float vAlpha,vSeed; varying vec3 vColor; uniform float viewportHeight;
      void main(){vAlpha=alpha;vSeed=seed;vColor=color;
        vec4 p=modelViewMatrix*vec4(position,1.0);gl_Position=projectionMatrix*p;
        gl_PointSize=clamp(particleSize*viewportHeight*projectionMatrix[1][1]/max(1.0,-2.0*p.z),1.0,256.0);}`,
    fragmentShader: `varying float vAlpha,vSeed; varying vec3 vColor;
      void main(){vec2 p=gl_PointCoord*2.0-1.0;float r=length(p);
        float grain=.78+.12*sin(p.x*17.0+vSeed)*sin(p.y*19.0-vSeed)+.1*sin((p.x+p.y)*29.0+vSeed);
        float a=(1.0-smoothstep(.15,1.0,r))*grain*vAlpha;if(a<.004)discard;
        gl_FragColor=vec4(vColor,a);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  fx.mesh = new THREE.Points(geometry, material);
  fx.mesh.name = 'battle-particles'; fx.mesh.frustumCulled = false;
  scene.add(fx.mesh);
}
function battleParticle(x, y, z, size, life, vx, vy, vz, kind = 'smoke') {
  const fx = BATTLE_FX;
  if (!fx.mesh) initBattleVisuals();
  fx.particles[fx.next] = { x, y, z, size, life, age: 0, vx, vy, vz, kind, seed: Math.random() * 100 };
  fx.next = (fx.next + 1) % fx.capacity;
}
function emitBlast(x, y, z, size) {
  const radius = Math.max(.4, size * .32);
  for (let i = 0; i < 30; i++) {
    const a = Math.random() * Math.PI * 2, speed = radius * (.3 + Math.random());
    battleParticle(x + Math.cos(a) * radius * .2, y, z + Math.sin(a) * radius * .2,
      radius * (.7 + Math.random()), 1.5 + Math.random() * 1.5,
      Math.cos(a) * speed, radius * (.5 + Math.random()), Math.sin(a) * speed, 'fire');
  }
  for (let i = 0; i < 18; i++) {
    const a = Math.random() * Math.PI * 2, speed = radius * (2 + Math.random() * 3);
    battleParticle(x, y, z, Math.max(.1, radius * .06), .4 + Math.random() * .7,
      Math.cos(a) * speed, radius * (1 + Math.random() * 3), Math.sin(a) * speed, 'spark');
  }
}
function updateBattleVisuals(dt) {
  const fx = BATTLE_FX;
  if (!fx.mesh) return;
  const attributes = fx.mesh.geometry.attributes;
  fx.mesh.material.uniforms.viewportHeight.value = renderer.domElement.height;
  for (let i = 0; i < fx.capacity; i++) {
    const p = fx.particles[i];
    if (!p || p.age >= p.life) { attributes.alpha.array[i] = 0; continue; }
    p.age += dt;
    const f = Math.min(1, p.age / p.life), fire = p.kind === 'fire', spark = p.kind === 'spark';
    p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
    if (spark) p.vy -= 9.8 * dt;
    else { const drag = Math.exp(-dt * .8); p.vx *= drag; p.vz *= drag; }
    attributes.position.setXYZ(i, p.x, p.y, p.z);
    const heat = fire ? Math.max(0, 1 - f * 3.5) : 0;
    const base = p.kind === 'steam' ? .8 : .12;
    attributes.color.setXYZ(i, spark ? 3 : base + heat * 3, spark ? 1.3 : base + heat * .85, spark ? .25 : base + heat * .08);
    attributes.alpha.array[i] = Math.max(0, Math.min(1, p.age * 20)) * (1 - f) * (spark ? 1 : .62);
    attributes.particleSize.array[i] = p.size * (spark ? 1 : 1 + f * 2.5);
    attributes.seed.array[i] = p.seed;
  }
  for (const a of Object.values(attributes)) a.needsUpdate = true;
}

let foamTexture;
function wakeTexture() {
  if (foamTexture) return foamTexture;
  const canvas = document.createElement('canvas'); canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d');
  for (let i = 0; i < 400; i++) {
    const t = Math.random(), side = Math.random() < .5 ? -1 : 1;
    const x = 64 + side * t * 52 + (Math.random() - .5) * 12;
    const y = 12 + t * 105;
    ctx.fillStyle = `rgba(230,245,245,${.1 + Math.random() * .35})`;
    ctx.beginPath(); ctx.ellipse(x, y, 2 + Math.random() * 5, 1 + Math.random() * 3, 0, 0, Math.PI * 2); ctx.fill();
  }
  foamTexture = new THREE.CanvasTexture(canvas); return foamTexture;
}

function detailUnitSurface(root, def) {
  if (!def.fly && !def.naval) return;
  const copies = new Map();
  root.traverse(o => {
    if (!o.isMesh) return;
    const list = Array.isArray(o.material) ? o.material : [o.material];
    const next = list.map(m => {
      if (m.isMeshBasicMaterial) return m;
      if (copies.has(m)) return copies.get(m);
      const glass = m.transparent || m === MAT.glass;
      const copy = new THREE.MeshStandardMaterial({ color: m.color, map: m.map,
        normalMap: m.normalMap, roughness: glass ? .16 : .53, metalness: glass ? .45 : .32,
        transparent: m.transparent, opacity: m.opacity, side: m.side,
        emissive: m.emissive || 0x000000, emissiveIntensity: m.emissiveIntensity ?? 0 });
      // Building brick/wood and red civilian hull paint do not belong on a warship.
      if (def.naval && !glass) {
        copy.map = null;
        if (m === MAT.wall || m === MAT.wallDark) copy.color.setHex(0x78868a);
        else if (m === MAT.hull) copy.color.setHex(0x343f45);
        else if (m !== MAT.dark) copy.color.lerp(new THREE.Color(0x68777e), .6);
        copy.roughness = .68; copy.metalness = .22;
      }
      copies.set(m, copy); return copy;
    });
    o.material = Array.isArray(o.material) ? next : next[0];
  });
}

function detailBuildingSite(root, key) {
  if (!['cottage', 'workerHouse', 'housing', 'residential', 'hq', 'warehouse', 'tankFactory'].includes(key)) return root;
  const bounds = new THREE.Box3().setFromObject(root), size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const stone = new THREE.MeshStandardMaterial({ color: 0x89887c, roughness: .95 });
  const foliage = new THREE.MeshStandardMaterial({ color: 0x414d32, roughness: .95 });
  const path = new THREE.Mesh(new THREE.BoxGeometry(Math.min(2, size.x * .35), .07, 1.4), stone);
  path.position.set(center.x, .03, bounds.max.z + .45); path.receiveShadow = true; root.add(path);
  for (const side of [-1, 1]) {
    const planter = new THREE.Mesh(new THREE.BoxGeometry(.55, .3, 1.1), stone);
    planter.position.set(center.x + side * Math.min(1.7, size.x * .3), .15, bounds.max.z + .25);
    root.add(planter);
    const bush = new THREE.Mesh(new THREE.IcosahedronGeometry(.42, 1), foliage);
    bush.scale.set(.7, .7, 1.25); bush.position.copy(planter.position); bush.position.y += .28;
    bush.castShadow = true; root.add(bush);
  }
  if (['cottage', 'workerHouse', 'warehouse', 'tankFactory'].includes(key)) {
    const chimney = new THREE.Mesh(new THREE.BoxGeometry(.45, .85, .45), stone);
    chimney.position.set(center.x, bounds.max.y + .22, center.z);
    chimney.castShadow = true; root.add(chimney);
    root.userData.siteSmoke = new THREE.Vector3(center.x, bounds.max.y + .67, center.z);
  }
  return root;
}
function animateBuildingSite(b, dt) {
  if (!b.built || !b.mesh.userData.siteSmoke) return;
  b.siteSmokeTime = (b.siteSmokeTime || 0) + dt;
  if (b.siteSmokeTime < .55) return;
  b.siteSmokeTime %= .55;
  const p = b.mesh.userData.siteSmoke.clone().applyMatrix4(b.mesh.matrixWorld);
  battleParticle(p.x, p.y, p.z, .55, 2.8, .18, .55, .12, 'steam');
}

const MISSILE_NOSE_X = new THREE.Vector3(1, 0, 0), MISSILE_NOSE_Y = new THREE.Vector3(0, 1, 0);
const missileDirection = new THREE.Vector3();
function poseMissile(m, f) {
  const arc = MISSILES[m.type].arc;
  const x = lerp(m.sx, m.tx, f), z = lerp(m.sz, m.tz, f);
  const fromY = Math.max(terrainH(m.sx, m.sz), SEA_LEVEL) + 3;
  const toY = Math.max(terrainH(m.tx, m.tz), SEA_LEVEL) + .3;
  const y = arc ? lerp(fromY, toY, f) + Math.sin(f * Math.PI) * 130
    : lerp(Math.max(terrainH(x, z), SEA_LEVEL) + 9, toY, Math.max(0, (f - .85) / .15));
  // Sample the terrain-following path too, so the nose follows the final dive.
  const cruiseHeight = t => lerp(Math.max(terrainH(lerp(m.sx, m.tx, t), lerp(m.sz, m.tz, t)), SEA_LEVEL) + 9, toY, Math.max(0, (t - .85) / .15));
  const a = Math.max(0, f - .001), b = Math.min(1, f + .001);
  const slope = arc ? toY - fromY + Math.cos(f * Math.PI) * 130 * Math.PI
    : (cruiseHeight(b) - cruiseHeight(a)) / (b - a);
  missileDirection.set(m.tx - m.sx, slope, m.tz - m.sz);
  if (missileDirection.lengthSq() < .0001) missileDirection.set(0, -1, 0);
  missileDirection.normalize();
  m.mesh.position.set(x, y, z);
  m.mesh.quaternion.setFromUnitVectors(arc ? MISSILE_NOSE_Y : MISSILE_NOSE_X, missileDirection);
}
