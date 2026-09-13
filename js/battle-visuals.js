'use strict';

// A fixed GPU buffer keeps explosions and exhaust from allocating one mesh
// per puff. Oldest particles are recycled under heavy combat.
const BATTLE_FX = { capacity: 1200, next: 0, particles: [], mesh: null };
function initBattleVisuals() {
  if (BATTLE_FX.mesh) return;
  const fx = BATTLE_FX, geometry = new THREE.BufferGeometry();
  for (const [name, width] of [['position', 3], ['color', 3], ['particleSize', 1], ['alpha', 1], ['seed', 1], ['rotation', 1], ['textured', 1]])
    geometry.setAttribute(name, new THREE.BufferAttribute(new Float32Array(fx.capacity * width), width).setUsage(THREE.DynamicDrawUsage));
  const material = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false,
    uniforms: { viewportHeight: { value: 900 }, smokeMap: { value: null }, spriteReady: { value: 0 } },
    vertexShader: `attribute float particleSize, alpha, seed, rotation, textured; attribute vec3 color;
      varying float vAlpha,vSeed,vRotation,vTextured; varying vec3 vColor; uniform float viewportHeight;
      void main(){vAlpha=alpha;vSeed=seed;vColor=color;vRotation=rotation;vTextured=textured;
        vec4 p=modelViewMatrix*vec4(position,1.0);gl_Position=projectionMatrix*p;
        gl_PointSize=clamp(particleSize*viewportHeight*projectionMatrix[1][1]/max(1.0,-2.0*p.z),1.0,256.0);}`,
    fragmentShader: `varying float vAlpha,vSeed,vRotation,vTextured; varying vec3 vColor;
      uniform sampler2D smokeMap; uniform float spriteReady;
      void main(){vec2 p=gl_PointCoord*2.0-1.0;float r=length(p);
        float grain=.78+.12*sin(p.x*17.0+vSeed)*sin(p.y*19.0-vSeed)+.1*sin((p.x+p.y)*29.0+vSeed);
        float a=(1.0-smoothstep(.15,1.0,r))*grain*vAlpha;vec3 col=vColor;
        if(spriteReady>.5 && vTextured>.5){
          float cs=cos(vRotation),sn=sin(vRotation);
          vec2 uv=mat2(cs,-sn,sn,cs)*p*.69+.5;
          vec4 texel=texture2D(smokeMap,clamp(uv,0.0,1.0));
          float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
          a=texel.a*vAlpha*inside*(1.0-smoothstep(.82,1.0,r));
          col*=.55+texel.rgb*.65;
        }
        if(a<.004)discard;
        gl_FragColor=vec4(col,a);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  fx.mesh = new THREE.Points(geometry, material);
  fx.mesh.name = 'battle-particles'; fx.mesh.frustumCulled = false;
  scene.add(fx.mesh);
  // Local asset generated with ImageGen. The analytic puff remains available
  // while loading or when an offline installation is missing the optional PNG.
  if (typeof document !== 'undefined') new THREE.TextureLoader().load('assets/textures/fx/smoke-puff-v1.png', texture => {
    texture.colorSpace = THREE.SRGBColorSpace;
    material.uniforms.smokeMap.value = texture;
    material.uniforms.spriteReady.value = 1;
  }, undefined, () => console.warn('Smoke sprite unavailable; using procedural particles.'));
}
function battleParticle(x, y, z, size, life, vx, vy, vz, kind = 'smoke') {
  const fx = BATTLE_FX;
  if (!fx.mesh) initBattleVisuals();
  const particle = fx.particles[fx.next] || (fx.particles[fx.next] = {});
  Object.assign(particle, { x, y, z, size, life, age: 0, vx, vy, vz, kind, seed: Math.random() * 100 });
  fx.next = (fx.next + 1) % fx.capacity;
}
function emitBlast(x, y, z, size) {
  const radius = Math.max(.4, size * .32);
  battleParticle(x, y, z, radius * 2.2, .14, 0, 0, 0, 'flash');
  for (let i = 0; i < 20; i++) {
    const a = i / 20 * Math.PI * 2, speed = radius * (1.2 + Math.random() * .5);
    battleParticle(x, y + .1, z, radius * .55, 1.3 + Math.random() * .6,
      Math.cos(a) * speed, .12, Math.sin(a) * speed, 'dust');
  }
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
  let alive = 0;
  for (let i = 0; i < fx.capacity; i++) {
    const p = fx.particles[i];
    if (!p || p.age >= p.life) { attributes.alpha.array[i] = 0; continue; }
    p.age += dt;
    const f = Math.min(1, p.age / p.life), fire = p.kind === 'fire', spark = p.kind === 'spark', flash = p.kind === 'flash', dust = p.kind === 'dust';
    if (f < 1) alive++;
    p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
    if (spark) p.vy -= 9.8 * dt;
    else { const drag = Math.exp(-dt * .8); p.vx *= drag; p.vz *= drag; }
    attributes.position.setXYZ(i, p.x, p.y, p.z);
    const heat = fire ? Math.max(0, 1 - f * 3.5) : 0;
    const base = p.kind === 'steam' ? .8 : .18;
    attributes.color.setXYZ(i, flash ? 7 : spark ? 3 : dust ? .45 : base + heat * 3,
      flash ? 3.5 : spark ? 1.3 : dust ? .34 : base + heat * .85,
      flash ? 1.4 : spark ? .25 : dust ? .23 : base + heat * .08);
    attributes.alpha.array[i] = (flash ? 1 : Math.max(0, Math.min(1, p.age * 20))) * (1 - f) * (spark || flash ? 1 : dust ? .32 : .75);
    attributes.particleSize.array[i] = p.size * (spark ? 1 : 1 + f * 2.5);
    attributes.seed.array[i] = p.seed;
    attributes.rotation.array[i] = p.seed + p.age * ((p.seed % 2) - 1) * .35;
    attributes.textured.array[i] = spark || flash ? 0 : 1;
  }
  fx.mesh.visible = alive > 0;
  fx.mesh.geometry.setDrawRange(0, fx.particles.length);
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
  if (!b.built) return;
  const activity = b.mesh.userData.districtActivity;
  const active = b.supplied !== false && !(b.disabledUntil > G.time);
  if (activity) {
    const flag = activity.userData.flag, positions = flag.geometry.attributes.position;
    for (let i = 0; i < positions.count; i++) {
      const along = (positions.getX(i) + .325) / .65;
      positions.setZ(i, Math.sin(G.time * 3.6 - along * 5 + b.id) * .085 * along);
    }
    positions.needsUpdate = true;
    // Local service traffic uses the straight streets, pauses at each end,
    // and stops when the district loses supply.
    b.activityTime = (b.activityTime || 0) + (active ? dt : 0);
    const phase = (b.activityTime * .15 + b.id * .31) % (Math.PI * 2);
    const traffic = activity.userData.traffic;
    traffic.position.set(.2, .27, Math.sin(phase) * activity.userData.radius);
    traffic.rotation.y = Math.cos(phase) < 0 ? Math.PI : 0;
  }
  const smoke = b.mesh.userData.siteSmoke || b.mesh.userData.districtSmoke;
  if (!active || !smoke) return;
  b.siteSmokeTime = (b.siteSmokeTime || 0) + dt;
  if (b.siteSmokeTime < .55) return;
  b.siteSmokeTime %= .55;
  b.mesh.updateMatrixWorld();
  const p = smoke.clone().applyMatrix4(b.mesh.matrixWorld);
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
