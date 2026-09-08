'use strict';
/* ============================================================
   World generation: terrain styles (island / continent /
   archipelago), ocean, deposits, choppable forests, clouds
   ============================================================ */

/* deterministic value noise.
   The lattice hash is integer arithmetic rather than the usual
   fract(sin(dot(p,k))*43758.5) trick: that form costs a Math.sin per lattice
   corner, i.e. 12+ transcendentals per terrainH call. Terrain height is
   sampled a quarter-million times just to build the map (and again for every
   tree, path query and unit step), so this is the single hottest function in
   the game. The integer mix is ~10x faster and better distributed. */
function _hash2(x, y) {
  let n = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263);
  n = Math.imul(n ^ (n >>> 13), 1274126177);
  return ((n ^ (n >>> 16)) >>> 0) * 2.3283064365386963e-10; // n / 2^32
}
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const a = _hash2(xi, yi), b = _hash2(xi + 1, yi);
  const c = _hash2(xi, yi + 1), d = _hash2(xi + 1, yi + 1);
  const sx = xf * xf * (3 - 2 * xf), sy = yf * yf * (3 - 2 * yf);
  return lerp(lerp(a, b, sx), lerp(c, d, sx), sy);
}

/* terrain height at any world x,z — shape depends on MAP_STYLE */
function terrainH(x, z) {
  let h = vnoise(x * 0.008 + 37, z * 0.008 + 11) * 9
        + vnoise(x * 0.025 + 5, z * 0.025 + 71) * 3.5
        + vnoise(x * 0.07 + 13, z * 0.07 + 29) * 1.2;

  if (MAP_STYLE === 'continent') {
    // dry interior, dramatic ranges, no ocean fringe
    h = h * 1.35 - 2.2;
    const ridge = vnoise(x * 0.012 + 400, z * 0.012 + 150);
    if (ridge > 0.62) h += (ridge - 0.62) * 26; // mountain chains
  } else if (MAP_STYLE === 'archipelago') {
    h -= 3.6;
    // large-scale noise carves sea lanes between islands
    const lane = vnoise(x * 0.006 + 800, z * 0.006 + 900);
    if (lane < 0.52) h -= (0.52 - lane) * 34;
    // soft edge falloff too
    const f = Math.max(Math.abs(x), Math.abs(z)) / HALF_MAP;
    if (f > 0.86) h -= ((f - 0.86) / 0.14) * 14;
  } else if (MAP_STYLE === 'highlands') {
    // rugged mountain country, deep lakes, no ocean
    h = h * 1.45 - 1.4;
    const ridge = vnoise(x * 0.011 + 320, z * 0.011 + 210);
    if (ridge > 0.58) h += (ridge - 0.58) * 30;
    const lake = vnoise(x * 0.009 + 555, z * 0.009 + 666);
    if (lake < 0.30) h -= (0.30 - lake) * 46; // carved lake basins
  } else if (MAP_STYLE === 'twin') {
    // two continents divided by a central strait
    h -= 3.2;
    const sx = Math.abs(x) / HALF_MAP;
    const wobble = vnoise(z * 0.012 + 77, 3) * 0.08;
    if (sx < 0.18 + wobble) h -= ((0.18 + wobble - sx) / 0.18) * 26; // the strait
    const f = Math.max(Math.abs(x), Math.abs(z)) / HALF_MAP;
    if (f > 0.84) h -= ((f - 0.84) / 0.16) * 18; // soft outer ocean rim
  } else { // island (default)
    h -= 3.6;
    // ISLAND MASK. The old shape was `max(|x|,|z|)*0.7 + |p|*0.21`, which is a
    // rounded square with the corners bitten off — from the air it read as a
    // literal diamond, and the ±0.08 of additive coast noise only frayed the
    // edge rather than bending it. Two changes:
    //   · a cubic superellipse, so the outline is a smooth rounded form with
    //     no straight sides or corner points anywhere on it;
    //   · the sample point is DOMAIN-WARPED before the radius is measured.
    //     Displacing the point is what carves bays, headlands, peninsulas and
    //     the occasional offshore islet, because the whole contour bends.
    //     Additive noise can only ever make the same outline fuzzy.
    const wx = x + (vnoise(x * 0.0038 + 61, z * 0.0038 + 17) - 0.5) * MAP_SIZE * 0.115
                 + (vnoise(x * 0.0125 + 811, z * 0.0125 + 97) - 0.5) * MAP_SIZE * 0.035;
    const wz = z + (vnoise(x * 0.0038 + 133, z * 0.0038 + 205) - 0.5) * MAP_SIZE * 0.115
                 + (vnoise(x * 0.0125 + 349, z * 0.0125 + 523) - 0.5) * MAP_SIZE * 0.035;
    const ex = Math.abs(wx) / HALF_MAP, ez = Math.abs(wz) / HALF_MAP;
    const edge = Math.cbrt(ex * ex * ex + ez * ez * ez);
    // A volcanic spine. An island with no interior relief reads as a putting
    // green from the air; damping it near the coast keeps mountains from
    // falling straight into the sea.
    // RIDGED noise, not plain value noise: 1-|2n-1| peaks along the noise's
    // half-level contours, which are lines, so the result is narrow mountain
    // CHAINS. Thresholding a plain noise field instead (what this did before)
    // raises every local maximum into a broad dome, and those domes painted
    // out as the flat grey plateau that covered a quarter of the island.
    const rn = vnoise(x * 0.004 + 410, z * 0.004 + 260);
    const crest = Math.max(0, 1 - Math.abs(rn * 2 - 1) - 0.82) / 0.18;
    h += crest * crest * 26 * clamp(1.02 - edge, 0, 1);
    if (edge > 0.85) { const f = (edge - 0.85) / 0.22; h -= f * f * 34; }
  }

  // COASTAL SHELF. Real land flattens out as it approaches the water. Without
  // this the height field crosses sea level at full slope, so the terrain grid
  // slices the waterline into a staircase of triangle edges and the beach is a
  // one-cell-wide sliver. Halving the gradient only within a few metres of sea
  // level roughly doubles the beach and softens the whole shore; the weight is
  // zero (with zero derivative) at the band edges, so no crease ring appears.
  {
    const t = clamp(h / COAST_SHELF, -1, 1);
    const w = 1 - t * t;
    h *= 1 - 0.5 * w * w;
  }

  // Every capital sits on guaranteed hinterland: a broad, smooth rise that
  // keeps the coastline noise above from ever stranding a start position on a
  // private islet, plus a flat pad at the centre to build on.
  for (const [sx, sz] of START_POS) {
    const d = dist2d(x, z, sx, sz);
    if (d > 200) continue;
    const t = d / 200;
    const lift = 1 - t * t;
    h += lift * lift * 6;
    if (d < 78) {
      const s = clamp((d - 42) / 36, 0, 1);
      h = lerp(2.2, h, s * s * (3 - 2 * s));
    }
  }
  return h;
}

const isWater = (x, z) => terrainH(x, z) < 0.05;
const isNavigable = (x, z) => terrainH(x, z) < -0.6;
/* area scale relative to the original 480 map (for object counts) */
function areaScale() { return (MAP_SIZE / 480) ** 2; }

/* near-white multi-octave noise texture multiplied over the vertex colors —
   gives the ground fine organic grain. Pure noise tiles invisibly, unlike a
   photo texture whose features repeat as an obvious carpet pattern. */
let _groundTex = null;
function makeGroundDetailTexture() {
  if (_groundTex) return _groundTex;
  const S = 512;
  const c = document.createElement('canvas');
  c.width = c.height = S;
  const ctx = c.getContext('2d');
  const img = ctx.createImageData(S, S);
  // tileable multi-octave noise: sample vnoise on a torus-friendly small grid
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const u = x / S, v = y / S;
      // wrap the noise domain so the texture edge matches itself
      const wx = Math.sin(u * Math.PI * 2), wy = Math.cos(u * Math.PI * 2);
      const wz = Math.sin(v * Math.PI * 2), ww = Math.cos(v * Math.PI * 2);
      let n = vnoise(wx * 3 + 17, wz * 3 + 5) * 0.45
            + vnoise((wx + wy) * 6 + 41, (wz + ww) * 6 + 9) * 0.3
            + vnoise((wx - wz) * 14 + 3, (wy + ww) * 14 + 27) * 0.25;
      const g = Math.round(215 + n * 44); // ~215..259 clipped below
      const i = (y * S + x) * 4;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = Math.min(255, g);
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  // faint pebbles break up the smoothness — kept small and subtle so the
  // pattern never reads as repeating spots from the air
  for (let i = 0; i < 700; i++) {
    const v = 196 + Math.floor(Math.random() * 36);
    ctx.fillStyle = `rgba(${v},${v},${v},0.3)`;
    const s = 1 + Math.random() * 3;
    ctx.beginPath();
    ctx.ellipse(Math.random() * S, Math.random() * S, s, s * 0.6, Math.random() * 3, 0, Math.PI * 2);
    ctx.fill();
  }
  _groundTex = new THREE.CanvasTexture(c);
  _groundTex.wrapS = _groundTex.wrapT = THREE.RepeatWrapping;
  _groundTex.repeat.set(Math.round(MAP_SIZE / 30), Math.round(MAP_SIZE / 30));
  _groundTex.anisotropy = 8;
  return _groundTex;
}

/* Replace the generated fallback with the authored high-frequency albedo.
   Terrain vertex colours still define each biome; the texture contributes
   natural soil, fibres and tiny stones. */
function loadAuthoredGroundTexture(material) {
  new THREE.TextureLoader().load('assets/textures/terrain-ground-v2.png', source => {
    const c = document.createElement('canvas');
    c.width = c.height = 1024;
    const ctx = c.getContext('2d');
    ctx.drawImage(source.image, 0, 0, c.width, c.height);
    const pixels = ctx.getImageData(0, 0, c.width, c.height);
    for (let i = 0; i < pixels.data.length; i += 4) {
      const lum = pixels.data[i] * 0.22 + pixels.data[i + 1] * 0.68 + pixels.data[i + 2] * 0.1;
      const grain = clamp(220 + (lum - 85) * 0.28, 202, 244);
      pixels.data[i] = Math.min(255, grain + 2);
      pixels.data[i + 1] = Math.min(255, grain + 1);
      pixels.data[i + 2] = Math.max(0, grain - 2);
    }
    ctx.putImageData(pixels, 0, 0);
    const detail = new THREE.CanvasTexture(c);
    detail.colorSpace = THREE.SRGBColorSpace;
    detail.wrapS = detail.wrapT = THREE.RepeatWrapping;
    const repeats = Math.max(8, MAP_SIZE / 48);
    detail.repeat.set(repeats, repeats);
    detail.anisotropy = 12;
    material.map = detail;
    material.bumpMap = detail;
    material.bumpScale = 0.13;
    material.needsUpdate = true;
  }, undefined, () => {});
}

/* ============================================================
   TERRAIN MATERIAL — real photo-based PBR splatting.
   Four CC0 surface layers (grass / dirt / rock / sand) are blended
   per pixel by altitude, slope and noise, each with its own normal
   map, and rock is projected triplanar so cliffs never smear. Two
   tiling frequencies per layer break up the repeat pattern that
   makes flat-textured ground read as "browser game".
   Vertex colours still drive biome tint and territory shading, so
   all existing gameplay painting keeps working on top.
   ============================================================ */
const TERRAIN_TEX_DIR = 'assets/textures/terrain/';
function _whiteTex() {
  const t = new THREE.DataTexture(new Uint8Array([255, 255, 255, 255]), 1, 1);
  t.needsUpdate = true;
  return t;
}
function _flatNormalTex() {
  const t = new THREE.DataTexture(new Uint8Array([128, 128, 255, 255]), 1, 1);
  t.needsUpdate = true;
  return t;
}
function makeTerrainMaterial() {
  const loader = new THREE.TextureLoader();
  const aniso = (renderer && renderer.capabilities)
    ? Math.min(8, renderer.capabilities.getMaxAnisotropy()) : 4;
  const load = (file, srgb) => {
    const t = loader.load(TERRAIN_TEX_DIR + file, tex => {
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      tex.anisotropy = aniso;
      tex.needsUpdate = true;
    }, undefined, () => console.warn('terrain texture missing:', file));
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = aniso;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    return t;
  };

  const uniforms = {
    uGrass:  { value: load('grass_color.jpg', true) },
    uGrassN: { value: load('grass_normal.jpg', false) },
    uDirt:   { value: load('dirt_color.jpg', true) },
    uDirtN:  { value: load('dirt_normal.jpg', false) },
    uRock:   { value: load('rock_color.jpg', true) },
    uRockN:  { value: load('rock_normal.jpg', false) },
    uSand:   { value: load('sand_color.jpg', true) },
    uSandN:  { value: load('sand_normal.jpg', false) },
    // one texture repeat per ~11 world units: dense enough to read as real
    // ground under the closest camera zoom without shimmering far away
    uTile:   { value: 1 / 11 },
    uTint:   { value: 0.42 },  // how much biome/territory colour survives
  };

  const mat = new THREE.MeshStandardMaterial({
    vertexColors: true, roughness: 0.95, metalness: 0.0,
  });
  mat.userData.uniforms = uniforms;

  mat.onBeforeCompile = shader => {
    Object.assign(shader.uniforms, uniforms);

    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', `#include <common>
        varying vec3 vTerrWorld;
        varying vec3 vTerrNormal;`)
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        vTerrWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;
        vTerrNormal = normalize(mat3(modelMatrix) * objectNormal);`);

    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', `#include <common>
        varying vec3 vTerrWorld;
        varying vec3 vTerrNormal;
        uniform sampler2D uGrass, uGrassN, uDirt, uDirtN, uRock, uRockN, uSand, uSandN;
        uniform float uTile, uTint;

        float tHash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
        float tNoise(vec2 p){
          vec2 i = floor(p), f = fract(p);
          vec2 u = f * f * (3.0 - 2.0 * f);
          return mix(mix(tHash(i), tHash(i + vec2(1.0, 0.0)), u.x),
                     mix(tHash(i + vec2(0.0, 1.0)), tHash(i + vec2(1.0, 1.0)), u.x), u.y);
        }
        // detail + macro sample of the same map: the low-frequency copy hides
        // the tiling grid that otherwise reads as a repeating carpet
        vec3 dualSample(sampler2D t, vec2 uv){
          return mix(texture2D(t, uv).rgb, texture2D(t, uv * 0.173).rgb, 0.42);
        }
        vec3 unpackN(vec3 c){ return c * 2.0 - 1.0; }

        struct TerrSurf { vec3 albedo; vec3 nrm; };
        TerrSurf terrainSurface() {
          vec3 wp = vTerrWorld;
          vec3 wn = normalize(vTerrNormal);
          float h = wp.y;
          float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
          vec2 uv = wp.xz * uTile;

          // NOTE: do not name any of these "patch", "sample" or "filter" —
          // they are reserved words in GLSL and silently break compilation
          float moist = tNoise(wp.xz * 0.013 + 7.0);
          float blotch = tNoise(wp.xz * 0.055 + 41.0);

          float wSand = smoothstep(2.9, 0.8, h);
          // rock is overwhelmingly a SLOPE cue, not an altitude one — flat high
          // ground is alpine pasture, not scree
          float wRock = clamp(smoothstep(0.30, 0.60, slope) + smoothstep(14.0, 22.0, h), 0.0, 1.0);
          float ground = (1.0 - wSand) * (1.0 - wRock);
          float grassy = smoothstep(0.34, 0.66, moist * 0.75 + blotch * 0.25);
          float wGrass = ground * grassy;
          float wDirt  = ground * (1.0 - grassy);
          float total = max(wSand + wRock + wGrass + wDirt, 0.0001);
          wSand /= total; wRock /= total; wGrass /= total; wDirt /= total;

          // triplanar rock so cliff faces show real stone instead of
          // vertically smeared pixels.
          // The blend weights are raised to the 4th power by repeated squaring
          // rather than pow(): on flat ground two normal components are exactly
          // zero, and pow(0.0, 4.0) yields NaN on some drivers — that NaN then
          // survives the multiply by a zero rock weight and poisons the whole
          // albedo, flattening the terrain to a single grey.
          vec3 bw = abs(wn) + 1e-4;
          bw = bw * bw;
          bw = bw * bw;
          bw /= max(bw.x + bw.y + bw.z, 1e-4);
          vec2 rUv = wp.xz * uTile * 0.62;
          vec3 rockC = texture2D(uRock, rUv).rgb * bw.y
                     + texture2D(uRock, wp.zy * uTile * 0.62).rgb * bw.x
                     + texture2D(uRock, wp.xy * uTile * 0.62).rgb * bw.z;
          vec3 rockN = unpackN(texture2D(uRockN, rUv).rgb) * bw.y
                     + unpackN(texture2D(uRockN, wp.zy * uTile * 0.62).rgb) * bw.x
                     + unpackN(texture2D(uRockN, wp.xy * uTile * 0.62).rgb) * bw.z;

          vec3 albedo = dualSample(uGrass, uv) * wGrass
                      + dualSample(uDirt, uv * 0.8) * wDirt
                      + dualSample(uSand, uv * 0.9) * wSand
                      + rockC * wRock;

          vec3 nrm = unpackN(texture2D(uGrassN, uv).rgb) * wGrass
                   + unpackN(texture2D(uDirtN, uv * 0.8).rgb) * wDirt
                   + unpackN(texture2D(uSandN, uv * 0.9).rgb) * wSand
                   + rockN * wRock;

          // broad brightness drift so large fields are never one flat tone
          albedo *= 0.86 + tNoise(wp.xz * 0.006 + 19.0) * 0.30;

          TerrSurf s;
          s.albedo = albedo;
          s.nrm = normalize(nrm + vec3(0.0, 0.0, 0.35));
          return s;
        }`)
      .replace('#include <color_fragment>', `#include <color_fragment>
        {
          TerrSurf ts = terrainSurface();
          // keep the photographic detail pattern but let the biome / territory
          // colour drive the hue, so gameplay tinting still reads clearly
          float lum = max(dot(ts.albedo, vec3(0.299, 0.587, 0.114)), 0.06);
          vec3 pattern = ts.albedo / lum;
          // vColor is declared vec4 when three enables USE_COLOR_ALPHA, so always
          // swizzle — .rgb is valid on both vec3 and vec4
          vec3 tinted = mix(ts.albedo, vColor.rgb * pattern, uTint);
          // underwater the seabed gradient IS the sea colour — let it dominate
          float underwater = smoothstep(0.5, -1.2, vTerrWorld.y);
          diffuseColor.rgb = mix(tinted, vColor.rgb * mix(vec3(1.0), pattern, 0.45), underwater);
        }`)
      .replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
        {
          TerrSurf ts2 = terrainSurface();
          vec3 N = normalize(vTerrNormal);
          vec3 T = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
          vec3 B = cross(N, T);
          vec3 worldN = normalize(mat3(T, B, N) * ts2.nrm);
          // flatten the relief under water so the seabed stays smooth
          worldN = normalize(mix(worldN, N, smoothstep(0.5, -1.2, vTerrWorld.y)));
          normal = normalize((viewMatrix * vec4(worldN, 0.0)).xyz);
        }`);
  };
  return mat;
}

function buildTerrain(scene) {
  const segs = Math.min(384, Math.round(MAP_SIZE / 2.2));
  const geo = new THREE.PlaneGeometry(MAP_SIZE, MAP_SIZE, segs, segs);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const cSand = new THREE.Color(0xd6c390);     // dry beach
  const cWetSand = new THREE.Color(0x8f7a55);  // dark wet strip right at the waterline
  const cLow = new THREE.Color(0x8b9565);      // dry grass
  const cGrass = new THREE.Color(0x65875a);    // grass
  const cDark = new THREE.Color(0x4c7549);     // lush
  const cRock = new THREE.Color(0x8a8880);     // rocky high
  const cCliff = new THREE.Color(0x6e6a60);    // steep slopes
  const cSnow = new THREE.Color(0xe8edf2);
  const cAbyss = new THREE.Color(0x123f5c);    // deep seabed
  const cSea = new THREE.Color(0x174c69);      // mid-depth seabed — kept close to
                                               // the abyss tone so depth contours
                                               // never draw hard edges in the water
  const cShallow = new THREE.Color(0x3fa9b8);  // bright turquoise shallows
  const tmp = new THREE.Color();
  // Two passes. Heights first, then colour — because the cliff shading needs a
  // slope, and sampling terrainH at two extra offsets per vertex meant building
  // the map cost three height evaluations for every one of ~85,000 vertices.
  // The neighbouring vertices already hold those heights.
  const stride = segs + 1;
  const cell = MAP_SIZE / segs;
  const heights = new Float32Array(pos.count);
  for (let i = 0; i < pos.count; i++) {
    const h = terrainH(pos.getX(i), pos.getZ(i));
    heights[i] = h;
    pos.setY(i, h);
  }
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const h = heights[i];
    const moist = vnoise(x * 0.015 + 91, z * 0.015 + 43);
    // slope = how fast the ground rises around this point (for cliff painting),
    // rescaled to the 3-unit baseline the thresholds below were tuned against
    const col = i % stride, row = (i / stride) | 0;
    const hx = heights[col < segs ? i + 1 : i - 1];
    const hz = heights[row < segs ? i + stride : i - stride];
    const slope = Math.max(Math.abs(hx - h), Math.abs(hz - h)) * (3 / cell);
    if (h < 0) {
      // brilliant turquoise at the waterline darkening to deep blue offshore —
      // the water is transparent so this gradient IS the sea color
      if (h > -2.6) tmp.copy(cShallow).lerp(cSea, clamp(-h / 2.6, 0, 1));
      else tmp.copy(cSea).lerp(cAbyss, clamp((-h - 2.6) / 5.5, 0, 1));
    }
    else if (h < 0.35) tmp.copy(cWetSand).lerp(cSand, clamp(h / 0.35, 0, 1) * 0.4); // narrow wet strip
    else if (h < 1.2) tmp.copy(cWetSand).lerp(cSand, clamp(0.4 + (h - 0.35) / 0.85 * 0.6, 0, 1));
    // Rock and snow start far higher than they used to (6 and 8.5). On a map
    // whose ordinary farmland sits at 2–6, those thresholds painted every
    // gentle rise bare grey and capped it with snow, which is what turned the
    // interior into pale blotches. Alpine ground now needs a real mountain.
    else if (h > 24) tmp.copy(cRock).lerp(cSnow, clamp((h - 24) / 7, 0, 1));
    else if (h > 15) tmp.copy(cDark).lerp(cRock, (h - 15) / 9);
    else {
      tmp.copy(cLow).lerp(moist > 0.5 ? cDark : cGrass, clamp(moist * 1.4, 0, 1));
      if (h < 2) tmp.lerp(cSand, (2 - h) / 2 * 0.5); // blend grass into beach
    }
    // steep ground shows bare rock regardless of altitude — real topography
    if (slope > 1.9 && h > 1.2) tmp.lerp(cCliff, clamp((slope - 1.9) / 2.4, 0, 0.85));
    const v = 0.93 + vnoise(x * 0.2, z * 0.2) * 0.12 + vnoise(x * 0.55 + 7, z * 0.55 + 3) * 0.05;
    colors[i * 3] = tmp.r * v; colors[i * 3 + 1] = tmp.g * v; colors[i * 3 + 2] = tmp.b * v;
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  // keep an untinted copy so territory shading can be re-applied cleanly
  geo.userData.baseColors = colors.slice();
  const mat = makeTerrainMaterial();
  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  mesh.name = 'terrain';
  installTerrainPicking(mesh, MAP_SIZE, segs);
  scene.add(mesh);
  return mesh;
}

/* ocean surface */
let waterMesh = null;
/* real assets streamed from the official three.js repo (CORS-enabled CDN) */
const TEX_CDN = 'https://cdn.jsdelivr.net/gh/mrdoob/three.js@r184/examples/textures/';
const _texLoader = new THREE.TextureLoader();

let waterIsRealistic = false;

/* Deep-ocean floor.
   The terrain mesh is exactly MAP_SIZE across while the water sheet is 2.2x
   that, so past the map boundary the sea had nothing behind it at all — the
   terrain's own square edge showed straight through the water as a hard
   geometric seam running across open ocean, one of the most obvious "this is a
   demo" tells on the whole map. This plane carries the abyss colour out to the
   full extent of the water, so the sea reads as continuous to the horizon. */
function buildAbyss(scene) {
  const geo = new THREE.PlaneGeometry(MAP_SIZE * 2.6, MAP_SIZE * 2.6, 1, 1);
  geo.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0x123f5c, fog: true }));
  mesh.position.y = -13;
  mesh.name = 'abyss';
  mesh.renderOrder = -50;
  scene.add(mesh);
  return mesh;
}

function buildWater(scene) {
  buildAbyss(scene);
  const geo = new THREE.PlaneGeometry(MAP_SIZE * 2.2, MAP_SIZE * 2.2, 1, 1);
  // THE ocean from the three.js examples: planar reflections, animated
  // normal-mapped waves, sun glints. Falls back to phong water offline.
  if (THREE.Water) {
    try {
      const normals = _texLoader.load(TEX_CDN + 'waternormals.jpg', t => {
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
      });
      waterMesh = new THREE.Water(geo, {
        textureWidth: 384, textureHeight: 384, // reflections are distorted anyway — 384 is indistinguishable from 512 and much cheaper
        waterNormals: normals,
        sunDirection: new THREE.Vector3(120, 180, 60).normalize(),
        sunColor: 0xfff1d8,
        waterColor: 0x0d5a70, // teal-blue: lets the turquoise seabed gradient glow through
        distortionScale: 2.6,
        // Was 0.94, purely to hide the terrain mesh ending at the map border.
        // buildAbyss covers that properly now, so the surface can go back to
        // being water: at 0.82 the seabed gradient reads through it instead of
        // every sea pixel being a flat mirror of a pale sky.
        alpha: 0.82,
        fog: true,
      });
      // Keep animated normals at full rate; only recapture the reflected scene
      // when the camera changes or at 15 Hz for moving units.
      const capture = waterMesh.onBeforeRender;
      const lastPosition = new THREE.Vector3(Infinity, Infinity, Infinity);
      const lastRotation = new THREE.Quaternion();
      let lastCapture = -Infinity;
      waterMesh.onBeforeRender = function(r, sc, cam) {
        const now = performance.now();
        if (lastPosition.distanceToSquared(cam.position) > .0025 ||
            lastRotation.angleTo(cam.quaternion) > .001 || now - lastCapture > 66) {
          capture.call(this, r, sc, cam);
          lastPosition.copy(cam.position); lastRotation.copy(cam.quaternion);
          lastCapture = now;
        }
      };
      waterMesh.rotation.x = -Math.PI / 2;
      waterMesh.position.y = SEA_LEVEL;
      waterMesh.material.transparent = true;
      waterIsRealistic = true;
      scene.add(waterMesh);
      return waterMesh;
    } catch (e) { console.warn('THREE.Water unavailable, using fallback sea.', e); }
  }
  // fallback: segmented sheet riding wave functions
  const geo2 = new THREE.PlaneGeometry(MAP_SIZE * 2.2, MAP_SIZE * 2.2, 80, 80);
  geo2.rotateX(-Math.PI / 2);
  const mat = new THREE.MeshPhongMaterial({
    color: 0x2274a4, transparent: true, opacity: 0.8,
    shininess: 210, specular: 0xd6efff,
  });
  waterMesh = new THREE.Mesh(geo2, mat);
  waterMesh.position.y = SEA_LEVEL;
  scene.add(waterMesh);
  return waterMesh;
}

/* ============================================================
   Animated surf: breaking wave bands that roll in toward every
   coast plus a bright foam contact line exactly where water
   meets land. The shore profile is baked once into a texture
   (R = 0 offshore → 1 at the waterline), so the shader knows how
   far every sea pixel is from the nearest beach.
   ============================================================ */
let shoreMesh = null;
function buildShoreline(scene) {
  const N = 512;
  // chamfer distance transform: for every sea texel, the distance (in texels)
  // to the nearest land. This gives the surf a constant width along every
  // coast — depth-based masks balloon into huge foam fields on shallow flats.
  const land = new Uint8Array(N * N);
  const dist = new Float32Array(N * N);
  const depth = new Float32Array(N * N);
  for (let j = 0; j < N; j++) {
    for (let i = 0; i < N; i++) {
      const x = (i / (N - 1) - 0.5) * MAP_SIZE;
      // Row j is sampled by the shader at uv.y = j/(N-1), and the shore plane
      // is rotated -90° about X — which puts uv.y = 1 at z = -MAP_SIZE/2, not
      // +MAP_SIZE/2. Filling rows in +z order mirrored the entire surf mask
      // across the map, drawing foam ribbons out in open water while real
      // beaches got none. Fill in the order the shader actually reads.
      const z = (0.5 - j / (N - 1)) * MAP_SIZE;
      const h = terrainH(x, z);
      const isLand = h >= 0.2;
      land[j * N + i] = isLand ? 1 : 0;
      dist[j * N + i] = isLand ? 0 : 1e9;
      depth[j * N + i] = isLand ? 0 : -h;
    }
  }
  const D = 1.4142;
  for (let j = 0; j < N; j++) {          // forward pass
    for (let i = 0; i < N; i++) {
      const k = j * N + i;
      if (i > 0) dist[k] = Math.min(dist[k], dist[k - 1] + 1);
      if (j > 0) {
        dist[k] = Math.min(dist[k], dist[k - N] + 1);
        if (i > 0) dist[k] = Math.min(dist[k], dist[k - N - 1] + D);
        if (i < N - 1) dist[k] = Math.min(dist[k], dist[k - N + 1] + D);
      }
    }
  }
  for (let j = N - 1; j >= 0; j--) {     // backward pass
    for (let i = N - 1; i >= 0; i--) {
      const k = j * N + i;
      if (i < N - 1) dist[k] = Math.min(dist[k], dist[k + 1] + 1);
      if (j < N - 1) {
        dist[k] = Math.min(dist[k], dist[k + N] + 1);
        if (i < N - 1) dist[k] = Math.min(dist[k], dist[k + N + 1] + D);
        if (i > 0) dist[k] = Math.min(dist[k], dist[k + N - 1] + D);
      }
    }
  }
  const texel = MAP_SIZE / N;            // world units per texel
  const bandW = 13;                      // surf band reaches ~13 world units offshore
  const SHELF_DEPTH = 15;                // metres of water the shallows tint spans
  const data = new Uint8Array(N * N * 4);
  for (let k = 0; k < N * N; k++) {
    // R: 1 at the waterline → 0 at bandW offshore; land stays 0
    const shore = land[k] ? 0 : clamp(1 - (dist[k] * texel) / bandW, 0, 1);
    // G: shallowness by actual DEPTH, which is what decides sea colour. The
    // terrain already paints a turquoise-to-abyss gradient on the seabed, but
    // the reflective ocean surface is nearly opaque, so none of it was ever
    // visible — every coast met the water on a flat grey line. This channel
    // lets the shore pass lay that gradient back over the water itself.
    const shallow = land[k] ? 0 : clamp(1 - depth[k] / SHELF_DEPTH, 0, 1);
    data[k * 4] = Math.round(shore * 255);
    data[k * 4 + 1] = Math.round(shallow * 255);
    data[k * 4 + 3] = 255;
  }
  const shoreTex = new THREE.DataTexture(data, N, N, THREE.RGBAFormat);
  shoreTex.magFilter = THREE.LinearFilter;
  shoreTex.minFilter = THREE.LinearFilter;
  shoreTex.needsUpdate = true;

  const geo = new THREE.PlaneGeometry(MAP_SIZE, MAP_SIZE, 1, 1);
  geo.rotateX(-Math.PI / 2);
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false,
    uniforms: {
      shoreTex: { value: shoreTex },
      time: { value: 0 },
      mapSize: { value: MAP_SIZE },
      fogRange: { value: new THREE.Vector2(320, 900 + MAP_SIZE * 0.35) },
    },
    vertexShader: `
      varying vec2 vUv;
      varying vec3 vWorld;
      void main() {
        vUv = uv;
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vWorld = wp.xyz;
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,
    fragmentShader: `
      varying vec2 vUv;
      varying vec3 vWorld;
      uniform sampler2D shoreTex;
      uniform float time, mapSize;
      uniform vec2 fogRange;
      float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      float n2(vec2 p){
        vec2 i = floor(p), f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
                   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
      }
      void main() {
        vec4 mask = texture2D(shoreTex, vUv);
        float shore = mask.r;        // distance-to-beach band, for the surf
        float shallow = mask.g;      // depth-based shallowness, for the water colour
        if (shore < 0.02 && shallow < 0.015) discard;
        vec2 wp = vWorld.xz;
        // two scales of drifting noise break the foam into realistic patches
        float nz = n2(wp * 0.22 + time * 0.18) * 0.6 + n2(wp * 0.85 - time * 0.12) * 0.4;
        // breakers: phase increases toward the beach, so crests roll shoreward
        float band = sin(shore * 24.0 - time * 2.1 + nz * 4.0);
        float breaker = smoothstep(0.68, 0.97, band)
                      * smoothstep(0.30, 0.62, shore)   // only near the coast
                      * (0.45 + 0.55 * nz);
        // solid foam line right where the sea touches the sand
        float contact = smoothstep(0.80, 0.97, shore + nz * 0.10);
        // gentle sparkle further out
        float sparkle = smoothstep(0.75, 1.0, n2(wp * 1.6 + time * 0.35)) * shore * 0.12;
        float foam = clamp(contact * 0.85 + breaker * 0.6 + sparkle, 0.0, 0.92);

        // SHALLOWS. Deep water keeps the reflective surface underneath; the
        // closer to the beach, the more the sea reads as its own bright
        // turquoise instead of a mirror of the sky. The subtle depth banding
        // is what makes a coast look like a coast from any altitude.
        // a gentle curve, not a square one: the tint has to fade out over a
        // wide shelf, or it reads as a cyan stripe painted along the coast
        float shelf = pow(shallow, 1.35);
        vec3 shallowCol = mix(vec3(0.07, 0.26, 0.39), vec3(0.24, 0.63, 0.63), shelf);
        // a slow swell ripple so the tint is not a flat wash
        shallowCol *= 0.94 + n2(wp * 0.13 + time * 0.06) * 0.14;
        float tint = shelf * 0.60;

        // composite foam over the shallow tint
        float a = clamp(foam + tint * (1.0 - foam), 0.0, 0.95);
        float dist = distance(cameraPosition, vWorld);
        a *= 1.0 - smoothstep(fogRange.x, fogRange.y, dist);
        if (a < 0.01) discard;
        vec3 col = mix(shallowCol, vec3(0.93, 0.97, 1.0), foam / max(foam + tint * (1.0 - foam), 1e-4));
        gl_FragColor = vec4(col, a);
      }`,
  });
  shoreMesh = new THREE.Mesh(geo, mat);
  shoreMesh.position.y = SEA_LEVEL + 0.07;
  shoreMesh.renderOrder = 2; // draw over the water surface
  scene.add(shoreMesh);
  return shoreMesh;
}
function updateWater(t) {
  if (shoreMesh) shoreMesh.material.uniforms.time.value = t;
  if (!waterMesh) return;
  if (waterIsRealistic) {
    waterMesh.material.uniforms['time'].value = t * 0.8;
    return;
  }
  const pos = waterMesh.geometry.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    pos.setY(i,
      Math.sin(x * 0.021 + t * 1.15) * 0.34
      + Math.cos(z * 0.024 + t * 0.85) * 0.28
      + Math.sin((x + z) * 0.011 + t * 0.5) * 0.22);
  }
  pos.needsUpdate = true;
  waterMesh.geometry.computeVertexNormals();
}

/* drifting clouds */
const CLOUDS = { mesh: null, items: [] };

/* Soft round puff with a ragged, noise-eaten rim — the alpha falloff is what
   keeps a cloud from having a silhouette. */
let _cloudTex = null;
function makeCloudTexture() {
  if (_cloudTex) return _cloudTex;
  const S = 128;
  const c = document.createElement('canvas');
  c.width = c.height = S;
  const ctx = c.getContext('2d');
  const img = ctx.createImageData(S, S);
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const dx = (x / S - 0.5) * 2, dy = (y / S - 0.5) * 2;
      const r = Math.sqrt(dx * dx + dy * dy);
      // billowing edge: noise pushes the falloff radius in and out
      const lumps = vnoise(x * 0.09 + 3, y * 0.09 + 11) * 0.34
                  + vnoise(x * 0.22 + 41, y * 0.22 + 7) * 0.16;
      const a = clamp(1 - (r + lumps - 0.25) / 0.75, 0, 1);
      const i = (y * S + x) * 4;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = 255;
      img.data[i + 3] = Math.round(a * a * 255);
    }
  }
  ctx.putImageData(img, 0, 0);
  _cloudTex = new THREE.CanvasTexture(c);
  _cloudTex.colorSpace = THREE.SRGBColorSpace;
  return _cloudTex;
}
function buildClouds(scene) {
  // Clouds used to fly at 105–160 units in half-opaque clumps of four small
  // spheres — from the normal camera altitude that is a string of solid white
  // golf balls parked between the player and their own base. They now sit well
  // above the play space, spread much wider and much fainter, so they read as
  // drifting weather instead of obstacles.
  const N = Math.round(11 * Math.sqrt(areaScale()));
  // Flat, soft-edged puffs rather than shaded spheres. A low-poly sphere has a
  // hard silhouette, so from above every cloud was a white polygon with visible
  // straight edges sitting on the sea; a radial alpha falloff has no edge at
  // all and reads as weather.
  const geo = new THREE.PlaneGeometry(1, 1);
  geo.rotateX(-Math.PI / 2);
  const mat = new THREE.MeshBasicMaterial({
    color: 0xf4f8fc, map: makeCloudTexture(),
    transparent: true, opacity: 0.42, depthWrite: false, fog: true,
  });
  CLOUDS.mesh = new THREE.InstancedMesh(geo, mat, N * 4);
  CLOUDS.mesh.renderOrder = 1;
  const dummy = new THREE.Object3D();
  let idx = 0;
  for (let i = 0; i < N; i++) {
    const cx = (Math.random() - 0.5) * MAP_SIZE * 1.6;
    const cz = (Math.random() - 0.5) * MAP_SIZE * 1.6;
    const cy = 235 + Math.random() * 90;
    const s = 26 + Math.random() * 34;
    const speed = 1.2 + Math.random() * 1.8;
    for (let p = 0; p < 4; p++) {
      const item = {
        idx, x: cx + (p - 1.5) * s * 0.65, y: cy + (Math.random() - 0.5) * 6,
        z: cz + (Math.random() - 0.5) * s * 0.6,
        sx: s * (0.7 + Math.random() * 0.5), sy: s * 0.18, sz: s * (0.55 + Math.random() * 0.3),
        speed,
      };
      CLOUDS.items.push(item);
      dummy.position.set(item.x, item.y, item.z);
      dummy.scale.set(item.sx, item.sy, item.sz);
      dummy.updateMatrix();
      CLOUDS.mesh.setMatrixAt(idx++, dummy.matrix);
    }
  }
  scene.add(CLOUDS.mesh);
}
const _cloudDummy = new THREE.Object3D();
function updateClouds(dt) {
  if (!CLOUDS.mesh) return;
  for (const it of CLOUDS.items) {
    it.x += it.speed * dt;
    if (it.x > MAP_SIZE * 0.85) it.x = -MAP_SIZE * 0.85;
    _cloudDummy.position.set(it.x, it.y, it.z);
    _cloudDummy.scale.set(it.sx, it.sy, it.sz);
    _cloudDummy.updateMatrix();
    CLOUDS.mesh.setMatrixAt(it.idx, _cloudDummy.matrix);
  }
  CLOUDS.mesh.instanceMatrix.needsUpdate = true;
}

/* scattered resource deposits, avoiding base centers and water */
function placeDeposits(scene) {
  const deposits = [];
  const taken = [];
  const nearStart = (x, z, r) => START_POS.some(([sx, sz]) => dist2d(x, z, sx, sz) < r);
  const scale = areaScale();
  for (const [type, def] of Object.entries(DEPOSIT_TYPES)) {
    const target = Math.max(2, Math.round(def.count * scale));
    let placed = 0, tries = 0;
    while (placed < target && tries++ < 900) {
      // bias a couple of each toward bases so early game has options
      let x, z;
      if (placed < 2) {
        const [sx, sz] = START_POS[placed % 4 === 0 ? 0 : Math.floor(Math.random() * 4)];
        const ang = Math.random() * Math.PI * 2, r = 45 + Math.random() * 40;
        x = clamp(sx + Math.cos(ang) * r, -HALF_MAP + 20, HALF_MAP - 20);
        z = clamp(sz + Math.sin(ang) * r, -HALF_MAP + 20, HALF_MAP - 20);
      } else {
        x = (Math.random() - 0.5) * (MAP_SIZE - 60);
        z = (Math.random() - 0.5) * (MAP_SIZE - 60);
      }
      if (nearStart(x, z, 34)) continue;
      if (def.water) {
        // sea deposits: navigable water, not far from a coast (rigs & wharves must reach them)
        if (!isNavigable(x, z) || terrainH(x, z) < -9) continue;
        let nearLand = false;
        for (let a = 0; a < Math.PI * 2 && !nearLand; a += Math.PI / 6) {
          if (terrainH(x + Math.cos(a) * 45, z + Math.sin(a) * 45) > 0.5) nearLand = true;
        }
        if (!nearLand) continue;
      } else if (terrainH(x, z) < 1.0) continue; // keep land deposits on dry land
      if (taken.some(([tx, tz]) => dist2d(x, z, tx, tz) < 26)) continue;
      taken.push([x, z]);
      const dep = { type, def, x, z, hasExtractor: false, workers: [] };
      dep.mesh = makeDepositMesh(type, def);
      dep.mesh.position.set(x, def.water ? SEA_LEVEL : terrainH(x, z), z);
      dep.mesh.userData.deposit = dep;
      scene.add(dep.mesh);
      deposits.push(dep);
      placed++;
    }
  }
  return deposits;
}

/* ============================================================
   Deposit props.
   Each deposit is authored as a dozen little rocks, crystals and pipes. Built
   naively that was ~1100 separate meshes with ~500 unique materials on a large
   map — more draw calls than everything else in the game combined, and every
   one of them redrawn again by the shadow pass and again by the water
   reflection. Two fixes, no visual change:
     · materials are cached and shared, so deposits of a type all use one;
     · the props of one deposit are merged into a single geometry per material,
       so a deposit costs one or two draw calls instead of twelve.
   ============================================================ */
const _depMats = new Map();
function depMat(key, make) {
  let m = _depMats.get(key);
  if (!m) { m = make(); _depMats.set(key, m); }
  return m;
}

/* Flatten a freshly authored prop group into one mesh per material. */
function mergeProps(group) {
  group.updateMatrixWorld(true);
  const byMaterial = new Map();
  group.traverse(o => {
    if (!o.isMesh || Array.isArray(o.material)) return;
    const geo = o.geometry.clone();
    geo.applyMatrix4(o.matrixWorld);
    // merging demands identical attribute sets; drop anything exotic
    for (const name of Object.keys(geo.attributes)) {
      if (name !== 'position' && name !== 'normal' && name !== 'uv') geo.deleteAttribute(name);
    }
    if (!geo.attributes.uv) {
      geo.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(geo.attributes.position.count * 2), 2));
    }
    if (!byMaterial.has(o.material)) byMaterial.set(o.material, []);
    byMaterial.get(o.material).push(geo);
  });
  const out = new THREE.Group();
  for (const [material, geometries] of byMaterial) {
    const merged = geometries.length === 1 ? geometries[0] : THREE.mergeGeometries(geometries, false);
    if (!merged) { for (const geo of geometries) out.add(new THREE.Mesh(geo, material)); continue; }
    if (geometries.length > 1) for (const geo of geometries) geo.dispose();
    const mesh = new THREE.Mesh(merged, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    out.add(mesh);
  }
  return out;
}

function makeDepositMesh(type, def) {
  const g = new THREE.Group();
  const rockMat = depMat('rock', () => new THREE.MeshStandardMaterial({ color: 0x76796f, roughness: 0.95 }));
  const addRocks = (n, rMax) => {
    for (let i = 0; i < n; i++) {
      const s = 0.5 + Math.random() * 1.1;
      const r = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 0), rockMat);
      const a = Math.random() * Math.PI * 2, rr = Math.random() * rMax;
      r.position.set(Math.cos(a) * rr, s * 0.4, Math.sin(a) * rr);
      r.rotation.set(Math.random() * 3, Math.random() * 3, Math.random() * 3);
      r.castShadow = true; g.add(r);
    }
  };
  const irregularPatch = (radius, material) => {
    const shape = new THREE.Shape();
    const points = 14;
    for (let i = 0; i < points; i++) {
      const a = (i / points) * Math.PI * 2;
      const rr = radius * (0.72 + Math.random() * 0.28);
      const x = Math.cos(a) * rr, y = Math.sin(a) * rr;
      if (i === 0) shape.moveTo(x, y); else shape.lineTo(x, y);
    }
    shape.closePath();
    const patch = new THREE.Mesh(new THREE.ShapeGeometry(shape), material);
    patch.rotation.x = -Math.PI / 2;
    patch.position.y = 0.025;
    patch.receiveShadow = true;
    return patch;
  };
  switch (type) {
    case 'oil': {
      // glossy tar pool with a rusty test derrick
      const pool = irregularPatch(3.6, depMat('tar', () =>
        new THREE.MeshStandardMaterial({ color: 0x171a19, roughness: 0.28, metalness: 0.18 })));
      pool.position.y = 0.04; g.add(pool);
      const derrickMat = depMat('derrick', () => new THREE.MeshStandardMaterial({ color: 0x7a4a2c, roughness: 0.7, metalness: 0.5 }));
      for (const [lx, lz] of [[-0.7, -0.7], [0.7, -0.7], [0, 0.8]]) {
        const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.1, 4.4, 5), derrickMat);
        leg.position.set(1.8 + lx * 0.55, 2.2, -1.4 + lz * 0.55);
        leg.rotation.set(lz * 0.16, 0, -lx * 0.16); leg.castShadow = true; g.add(leg);
      }
      const top = new THREE.Mesh(new THREE.SphereGeometry(0.3, 6, 5), derrickMat);
      top.position.set(1.8, 4.4, -1.4); g.add(top);
      for (let i = 0; i < 3; i++) {
        const bub = new THREE.Mesh(new THREE.SphereGeometry(0.3 + Math.random() * 0.4, 7, 5),
          depMat('tarBubble', () => new THREE.MeshStandardMaterial({ color: 0x22262c, roughness: 0.25 })));
        bub.position.set((Math.random() - 0.5) * 4, 0.45, (Math.random() - 0.5) * 4);
        g.add(bub);
      }
      break;
    }
    case 'iron': {
      // rust-streaked ore slabs
      addRocks(3, 3.4);
      const oreMat = depMat('ore', () => new THREE.MeshStandardMaterial({ color: 0x9a6248, roughness: 0.85, metalness: 0.35 }));
      for (let i = 0; i < 4; i++) {
        const s = 0.8 + Math.random() * 1.2;
        const ore = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 0), oreMat);
        ore.scale.set(1.5, 0.78, 1.05);
        ore.position.set((Math.random() - 0.5) * 4.5, s * 0.4, (Math.random() - 0.5) * 4.5);
        ore.rotation.set(Math.random() * 0.6, Math.random() * 3, Math.random() * 0.5);
        ore.castShadow = true; g.add(ore);
      }
      break;
    }
    case 'gold': {
      // grey rock with glinting nuggets embedded
      addRocks(5, 3.2);
      const goldMat = depMat('gold', () => new THREE.MeshStandardMaterial({
        color: 0xffc93d, roughness: 0.25, metalness: 1.0, emissive: 0x9a6b12, emissiveIntensity: 0.35 }));
      for (let i = 0; i < 7; i++) {
        const nug = new THREE.Mesh(new THREE.OctahedronGeometry(0.28 + Math.random() * 0.3, 0), goldMat);
        nug.position.set((Math.random() - 0.5) * 4.5, 0.5 + Math.random() * 1.1, (Math.random() - 0.5) * 4.5);
        nug.rotation.set(Math.random() * 3, Math.random() * 3, 0);
        nug.castShadow = true; g.add(nug);
      }
      break;
    }
    case 'silicon': {
      // slender glassy blue crystal spires
      const cryMat = depMat('silicon', () => new THREE.MeshPhysicalMaterial({
        color: 0x9fd7ff, roughness: 0.12, metalness: 0.1, transparent: true, opacity: 0.85,
        emissive: 0x2a5a80, emissiveIntensity: 0.4 }));
      for (let i = 0; i < 6; i++) {
        const hgt = 1.4 + Math.random() * 2.4;
        const cry = new THREE.Mesh(new THREE.ConeGeometry(0.32 + Math.random() * 0.2, hgt, 5), cryMat);
        const a = Math.random() * Math.PI * 2, rr = Math.random() * 2.6;
        cry.position.set(Math.cos(a) * rr, hgt * 0.42, Math.sin(a) * rr);
        cry.rotation.set((Math.random() - 0.5) * 0.5, Math.random() * 3, (Math.random() - 0.5) * 0.5);
        cry.castShadow = true; g.add(cry);
      }
      addRocks(3, 3);
      break;
    }
    case 'uranium': {
      // radioactive green crystals that genuinely glow (bloom picks these up)
      const uMat = depMat('uranium', () => new THREE.MeshStandardMaterial({
        color: 0x7dff5d, roughness: 0.3, emissive: 0x39e83a, emissiveIntensity: 1.1 }));
      for (let i = 0; i < 5; i++) {
        const s = 0.5 + Math.random() * 0.9;
        const cry = new THREE.Mesh(new THREE.OctahedronGeometry(s, 0), uMat);
        cry.position.set((Math.random() - 0.5) * 4, s * 0.7, (Math.random() - 0.5) * 4);
        cry.rotation.set(Math.random() * 3, Math.random() * 3, 0);
        cry.castShadow = true; g.add(cry);
      }
      // scorched earth ring
      const scorch = irregularPatch(3.5, depMat('scorch', () =>
        new THREE.MeshStandardMaterial({ color: 0x3f4836, roughness: 1 })));
      scorch.position.y = 0.02; g.add(scorch);
      break;
    }
    case 'diamond': {
      // brilliant white-blue gems
      const dMat = depMat('diamond', () => new THREE.MeshPhysicalMaterial({
        color: 0xeaf6ff, roughness: 0.05, metalness: 0.05, transparent: true, opacity: 0.9,
        emissive: 0x7fb8dd, emissiveIntensity: 0.5 }));
      for (let i = 0; i < 6; i++) {
        const s = 0.4 + Math.random() * 0.7;
        const gem = new THREE.Mesh(new THREE.OctahedronGeometry(s, 0), dMat);
        gem.position.set((Math.random() - 0.5) * 4, s * 0.9, (Math.random() - 0.5) * 4);
        gem.rotation.set(Math.random() * 3, Math.random() * 3, 0);
        gem.castShadow = true; g.add(gem);
      }
      addRocks(4, 3.2);
      break;
    }
    case 'seaOil': {
      // dark slick on the surface, ringed by orange marker buoys
      const slick = irregularPatch(4.4, depMat('slick', () =>
        new THREE.MeshStandardMaterial({ color: 0x1d2328, roughness: 0.16, metalness: 0.32,
          transparent: true, opacity: 0.68 })));
      slick.position.y = 0.12; g.add(slick);
      const buoyMat = depMat('buoy', () => new THREE.MeshStandardMaterial({ color: 0xe86a1e, roughness: 0.5 }));
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * Math.PI * 2;
        const buoy = new THREE.Mesh(new THREE.SphereGeometry(0.42, 8, 6), buoyMat);
        buoy.position.set(Math.cos(a) * 4.6, 0.25, Math.sin(a) * 4.6);
        buoy.castShadow = true; g.add(buoy);
        g.add(cyl(0.05, 0.05, 0.8, buoyMat, Math.cos(a) * 4.6, 0.75, Math.sin(a) * 4.6, 5));
      }
      // gas flare bubbles
      for (let i = 0; i < 3; i++) {
        const bub = new THREE.Mesh(new THREE.SphereGeometry(0.2 + Math.random() * 0.2, 6, 5),
          depMat('gasBubble', () => new THREE.MeshStandardMaterial({ color: 0x2c3644, roughness: 0.2 })));
        bub.position.set((Math.random() - 0.5) * 5, 0.15, (Math.random() - 0.5) * 5);
        g.add(bub);
      }
      break;
    }
    case 'fish': {
      // circling silver fins breaking the surface + gulls' splash rings
      const finMat = depMat('fin', () => new THREE.MeshStandardMaterial({ color: 0xb9ccd6, roughness: 0.35, metalness: 0.5 }));
      for (let i = 0; i < 8; i++) {
        const a = Math.random() * Math.PI * 2, r = 1 + Math.random() * 3.4;
        const fin = new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.66, 4), finMat);
        fin.position.set(Math.cos(a) * r, 0.32, Math.sin(a) * r);
        fin.rotation.set((Math.random() - 0.5) * 0.4, Math.random() * Math.PI, (Math.random() - 0.5) * 0.4);
        fin.castShadow = true; g.add(fin);
      }
      const ring = new THREE.Mesh(new THREE.RingGeometry(3.4, 4.2, 20),
        depMat('splash', () => new THREE.MeshBasicMaterial({ color: 0xdff2f6, transparent: true, opacity: 0.35, side: THREE.DoubleSide, depthWrite: false })));
      ring.rotation.x = -Math.PI / 2; ring.position.y = 0.1; g.add(ring);
      break;
    }
    default: {
      addRocks(5, 3.2);
    }
  }
  // irregular rocky outcrop base — not a perfect circle (land deposits only;
  // sea deposits float on the surface)
  if (!def.water) {
    addRocks(4, 3.8);
  }
  return mergeProps(g);
}

/* ============================================================
   Forests — instanced but individually choppable.
   TREES.list[i] = {x, z, s, kind, removed, canopyIdx, trunkIdx}
   ============================================================ */
const TREES = {
  list: [], trunks: null,
  cones: null, cones2: null, cones3: null,
  leaves: null, leaves2: null, leaves3: null,
  authored: [],
};
const _treeDummy = new THREE.Object3D();
const _windMaterials = [];

function windMaterial(material, strength) {
  material.onBeforeCompile = shader => {
    shader.uniforms.windTime = { value: 0 };
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float windTime;')
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        float windPhase = windTime * 1.15 + instanceMatrix[3].x * 0.045 + instanceMatrix[3].z * 0.038;
        float windLift = max(position.y + 1.5, 0.0);
        transformed.x += sin(windPhase + position.y * 0.55) * windLift * ${strength.toFixed(3)};
        transformed.z += cos(windPhase * 0.83 + position.y * 0.35) * windLift * ${(strength * 0.55).toFixed(3)};`);
    material.userData.windShader = shader;
  };
  material.customProgramCacheKey = () => `natural-wind-${strength}`;
  _windMaterials.push(material);
  return material;
}

function updateVegetation(t) {
  for (const material of _windMaterials) {
    if (material.userData.windShader) material.userData.windShader.uniforms.windTime.value = t;
  }
}

/* ---------------- foliage colour ----------------
   The Quaternius birch kit ships a single AUTUMN leaf texture — its average
   opaque pixel is (232, 199, 0), pure gold. Instancing it five times gave an
   island where every tree on every hillside was the same yellow, which is what
   made the map read as unnatural from the air.
   Multiplying through material.color cannot fix it: the texture's blue channel
   is 0, so no multiplier can put any blue back and every result is an acid
   yellow-green. So the texture is re-mapped once per species: the source
   luminance (which carries all the leaf shading and edge detail) is used to
   look up a two-point colour ramp, and alpha is preserved for the alpha test.
   One late-season gold stand is kept on purpose, for contrast. */
const LEAF_RAMPS = [
  [[0x22, 0x3d, 0x18], [0x6f, 0xa0, 0x42]], // deep forest green
  [[0x2c, 0x4a, 0x1c], [0x8a, 0xba, 0x51]], // fresh mid green
  [[0x1d, 0x35, 0x1b], [0x5c, 0x8c, 0x45]], // dark, damp green
  [[0x36, 0x4c, 0x1a], [0x9c, 0xc0, 0x54]], // bright open-canopy green
  [[0x5a, 0x42, 0x14], [0xd8, 0xae, 0x3c]], // one autumn stand, for contrast
];
const _leafTextures = new Map();
function rampedLeafTexture(source, rampIndex) {
  const cached = _leafTextures.get(rampIndex);
  if (cached) return cached;
  const image = source && source.image;
  if (!image || !image.width) return null;
  const [dark, light] = LEAF_RAMPS[rampIndex % LEAF_RAMPS.length];
  const c = document.createElement('canvas');
  c.width = image.width; c.height = image.height;
  const ctx = c.getContext('2d');
  ctx.drawImage(image, 0, 0);
  const px = ctx.getImageData(0, 0, c.width, c.height);
  const d = px.data;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 8) continue;
    // the source is monochromatic gold, so plain luminance IS the leaf shading
    const l = clamp((d[i] * 0.35 + d[i + 1] * 0.55 + d[i + 2] * 0.10) / 235, 0, 1);
    d[i]     = dark[0] + (light[0] - dark[0]) * l;
    d[i + 1] = dark[1] + (light[1] - dark[1]) * l;
    d[i + 2] = dark[2] + (light[2] - dark[2]) * l;
  }
  ctx.putImageData(px, 0, 0);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = tex.wrapT = source.wrapS;
  tex.flipY = source.flipY;
  tex.needsUpdate = true;
  _leafTextures.set(rampIndex, tex);
  return tex;
}

/* Build one instancing set per authored tree variant. This keeps hundreds of
   fully textured trees to a small, fixed number of draw calls. */
function createAuthoredTreeVariants(total) {
  const keys = ['nature:birch1', 'nature:birch2', 'nature:birch3', 'nature:birch4', 'nature:birch5'];
  const loaded = keys.map(key => MODELS.loaded.get(key)).filter(Boolean);
  if (!loaded.length) return [];
  // Species are assigned per grove, so one variant can legitimately take far
  // more than its even share. These are staging buffers that chunkAuthoredForest
  // copies out of and then disposes, so sizing them for the worst case is cheap.
  const capacity = total + 4;
  return loaded.map((gltf, variantIndex) => {
    gltf.scene.updateMatrixWorld(true);
    const parts = [];
    gltf.scene.traverse(source => {
      if (!source.isMesh) return;
      const geometry = source.geometry.clone();
      geometry.applyMatrix4(source.matrixWorld);
      const srcMaterials = Array.isArray(source.material) ? source.material : [source.material];
      const materials = srcMaterials.map(src => {
        const material = src.clone();
        material.roughness = Math.max(0.78, material.roughness ?? 0.8);
        material.metalness = 0;
        material.envMapIntensity = 0.34;
        if ((material.name || '').toLowerCase().includes('leaves')) {
          const tinted = rampedLeafTexture(material.map, variantIndex);
          if (tinted) material.map = tinted;
          material.transparent = false;
          material.alphaTest = 0.38;
          material.depthWrite = true;
          material.side = THREE.DoubleSide;
          windMaterial(material, 0.012);
        }
        return material;
      });
      const instanced = new THREE.InstancedMesh(
        geometry,
        Array.isArray(source.material) ? materials : materials[0],
        capacity,
      );
      instanced.castShadow = true;
      instanced.receiveShadow = true;
      parts.push(instanced);
    });
    return { parts, count: 0 };
  }).filter(variant => variant.parts.length);
}

// Partition the authored forest into batches. Whole-map instance bounds
// otherwise defeat camera AND shadow frustum culling on large maps.
//
// The batch key is the GROVE, not a fixed grid cell. Under the old
// `variant:cellX:cellZ` key an evenly-scattered forest of ~1100 trees split
// into ~300 buckets averaging under four trees each — one draw call per four
// trees, tripled again by the shadow and water-reflection passes. Because a
// grove is planted as a single species (see planForest), one grove is one
// bucket, and it is also a tight sphere for culling.
function chunkAuthoredForest(scene) {
  for (const variant of TREES.authored) variant.impostor = bakeTreeImpostor(variant.parts);
  const buckets = new Map();
  for (const tree of TREES.list) {
    if (tree.kind !== 'real') continue;
    const key = tree.grove >= 0
      ? `g${tree.grove}`
      : `s${tree.authoredVariant}:${Math.floor(tree.x / 160)}:${Math.floor(tree.z / 160)}`;
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(tree);
  }
  const matrix = new THREE.Matrix4();
  for (const trees of buckets.values()) {
    const source = TREES.authored[trees[0].authoredVariant];
    const parts = source.parts.map(part => {
      const batch = new THREE.InstancedMesh(part.geometry, part.material, trees.length);
      batch.castShadow = batch.receiveShadow = true;
      batch.name = 'forest-cell';
      trees.forEach((tree, i) => {
        part.getMatrixAt(tree.canopyIdx, matrix);
        batch.setMatrixAt(i, matrix);
      });
      batch.computeBoundingSphere();
      batch.updateMatrix(); batch.matrixAutoUpdate = false;
      scene.add(batch);
      return batch;
    });
    const impostor = new THREE.InstancedMesh(source.impostor.geometry, source.impostor.material, trees.length);
    trees.forEach((tree, i) => {
      source.parts[0].getMatrixAt(tree.canopyIdx, matrix);
      impostor.setMatrixAt(i, matrix);
    });
    impostor.computeBoundingSphere();
    impostor.visible = false;
    impostor.name = 'distant-forest';
    scene.add(impostor);
    FOREST_CELLS.push({ parts, impostor, bounds: impostor.boundingSphere.clone(), detailed: true });
    trees.forEach((tree, i) => { tree.renderParts = [...parts, impostor]; tree.renderIndex = i; });
  }
  for (const variant of TREES.authored) for (const part of variant.parts) part.dispose();
}

/* clump of individual grass blades on a transparent background —
   alpha-tested so only the blades render, not the quad */
let _grassBladeTex = null;
function makeGrassBladeTexture() {
  if (_grassBladeTex) return _grassBladeTex;
  const c = document.createElement('canvas');
  c.width = 128; c.height = 64;
  const ctx = c.getContext('2d');
  ctx.clearRect(0, 0, 128, 64);
  for (let i = 0; i < 26; i++) {
    const bx = 8 + Math.random() * 112;         // blade root x
    const lean = (Math.random() - 0.5) * 26;    // tip lean
    const hgt = 26 + Math.random() * 34;        // blade height
    const wid = 1.5 + Math.random() * 2.5;      // root width
    const g = 72 + Math.floor(Math.random() * 52);
    const r = Math.floor(g * (0.45 + Math.random() * 0.25));
    const b = Math.floor(g * 0.35);
    ctx.fillStyle = `rgb(${r},${g},${b})`;
    ctx.beginPath();
    ctx.moveTo(bx - wid, 64);
    ctx.quadraticCurveTo(bx - wid * 0.4 + lean * 0.4, 64 - hgt * 0.6, bx + lean, 64 - hgt);
    ctx.quadraticCurveTo(bx + wid * 0.4 + lean * 0.4, 64 - hgt * 0.6, bx + wid, 64);
    ctx.closePath();
    ctx.fill();
  }
  _grassBladeTex = new THREE.CanvasTexture(c);
  return _grassBladeTex;
}

/* ---------------- forest layout ----------------
   Trees grow in GROVES, not as confetti scattered evenly over the island.
   Three things fall out of this:
     · it looks like real woodland — dense cores, ragged edges, open pasture
       between stands, instead of a uniform speckle of single trees;
     · felling a stand visibly opens a clearing, so chopping reads as progress;
     · every grove is one species and one tight sphere, which is what lets
       chunkAuthoredForest batch a whole grove into one draw call.
   Deposits punch a clearing in whatever grove covers them, so ore is never
   buried under a canopy the player has to chop before they can even see it. */
const DEPOSIT_CLEARING = 15;   // world units of open ground kept around every deposit

function planForest(deposits) {
  const scale = areaScale();
  const groveCount = Math.max(6, Math.round(13 * scale));
  const groves = [];
  const trees = [];
  const nearStart = (x, z, r) => START_POS.some(([sx, sz]) => dist2d(x, z, sx, sz) < r);
  const onDeposit = (x, z) => deposits.some(d => dist2d(x, z, d.x, d.z) < DEPOSIT_CLEARING);
  const plantable = (x, z) => {
    const h = terrainH(x, z);
    // no trees on the beach, on bare rock, in a capital's build zone, or on ore
    return h > 1.2 && h < 16 && !nearStart(x, z, 62) && !onDeposit(x, z);
  };

  for (let g = 0; g < groveCount; g++) {
    // moisture drives where woodland wants to be, exactly as it drives the
    // ground colouring, so forests sit on the green ground and not the dry
    const size = 18 + Math.round(Math.random() * 26);
    const radius = 13 + Math.sqrt(size) * 3.2;
    let cx = 0, cz = 0, sited = false;
    for (let tries = 0; tries < 220 && !sited; tries++) {
      cx = (Math.random() - 0.5) * (MAP_SIZE - 110);
      cz = (Math.random() - 0.5) * (MAP_SIZE - 110);
      const h = terrainH(cx, cz);
      if (h < 1.6 || h > 12) continue;
      if (nearStart(cx, cz, 95)) continue;
      const moist = vnoise(cx * 0.015 + 91, cz * 0.015 + 43);
      if (moist < 0.42 && Math.random() > 0.2) continue;
      if (groves.some(o => dist2d(cx, cz, o.x, o.z) < o.radius + radius + 26)) continue;
      sited = true;
    }
    if (!sited) continue;
    const grove = { x: cx, z: cz, radius, species: g };
    groves.push(grove);
    const id = groves.length - 1;
    let placed = 0;
    for (let tries = 0; tries < size * 14 && placed < size; tries++) {
      // sqrt-biased radius keeps the middle of a stand dense and the rim thin
      const a = Math.random() * Math.PI * 2;
      const rr = radius * Math.sqrt(Math.random()) * (0.55 + Math.random() * 0.55);
      const x = cx + Math.cos(a) * rr, z = cz + Math.sin(a) * rr;
      if (Math.abs(x) > HALF_MAP - 16 || Math.abs(z) > HALF_MAP - 16) continue;
      if (!plantable(x, z)) continue;
      trees.push({ x, z, grove: id, s: 0.85 + Math.random() * 0.85 });
      placed++;
    }
  }

  // a scatter of lone trees and two-tree clumps across the open country, so the
  // land between groves is not conspicuously bare
  const strays = Math.round(70 * scale);
  for (let i = 0, tries = 0; i < strays && tries < strays * 12; tries++) {
    const x = (Math.random() - 0.5) * (MAP_SIZE - 40);
    const z = (Math.random() - 0.5) * (MAP_SIZE - 40);
    if (!plantable(x, z)) continue;
    const moist = vnoise(x * 0.015 + 91, z * 0.015 + 43);
    if (moist < 0.4 && Math.random() > 0.3) continue;
    const clump = 1 + (Math.random() < 0.45 ? 1 : 0) + (Math.random() < 0.2 ? 1 : 0);
    for (let c = 0; c < clump; c++) {
      const ox = c ? (Math.random() - 0.5) * 9 : 0, oz = c ? (Math.random() - 0.5) * 9 : 0;
      if (c && !plantable(x + ox, z + oz)) continue;
      trees.push({ x: x + ox, z: z + oz, grove: -1, s: 0.85 + Math.random() * 0.85 });
      i++;
    }
  }
  return { groves, trees };
}

function decorate(scene) {
  const dummy = _treeDummy;
  const nearStart = (x, z) => START_POS.some(([sx, sz]) => dist2d(x, z, sx, sz) < 55);
  const scale = areaScale();
  const plan = planForest(G.deposits || []);
  const N_TREES = plan.trees.length;
  const N_CONIFER = N_TREES, N_BROAD = N_TREES; // procedural fallback capacities
  TREES.authored = createAuthoredTreeVariants(N_TREES);

  const trunkGeo = new THREE.CylinderGeometry(0.22, 0.42, 2.4, 6);
  const trunkMat = new THREE.MeshStandardMaterial({ color: 0x6d4c33, roughness: 0.95 });
  const coneGeo = new THREE.ConeGeometry(1.95, 3.0, 9);
  const coneMat = windMaterial(new THREE.MeshStandardMaterial({
    color: 0xffffff, roughness: 0.96, envMapIntensity: 0.24,
  }), 0.018);
  const cone2Geo = new THREE.ConeGeometry(1.5, 2.7, 9);
  const cone3Geo = new THREE.ConeGeometry(1.0, 2.25, 8);
  const leafGeo = new THREE.DodecahedronGeometry(1.8, 1);
  const leafMat = windMaterial(new THREE.MeshStandardMaterial({
    color: 0xffffff, roughness: 0.98, envMapIntensity: 0.22,
  }), 0.025);
  const leaf2Geo = new THREE.IcosahedronGeometry(1.15, 1);
  const leaf3Geo = new THREE.DodecahedronGeometry(0.95, 0);

  TREES.trunks = new THREE.InstancedMesh(trunkGeo, trunkMat, N_CONIFER + N_BROAD);
  TREES.cones = new THREE.InstancedMesh(coneGeo, coneMat, N_CONIFER);
  TREES.cones2 = new THREE.InstancedMesh(cone2Geo, coneMat, N_CONIFER);
  TREES.cones3 = new THREE.InstancedMesh(cone3Geo, coneMat, N_CONIFER);
  TREES.leaves = new THREE.InstancedMesh(leafGeo, leafMat, N_BROAD);
  TREES.leaves2 = new THREE.InstancedMesh(leaf2Geo, leafMat, N_BROAD);
  TREES.leaves3 = new THREE.InstancedMesh(leaf3Geo, leafMat, N_BROAD);
  TREES.cones.castShadow = true; TREES.cones2.castShadow = true; TREES.cones3.castShadow = true;
  TREES.leaves.castShadow = true; TREES.leaves2.castShadow = true; TREES.leaves3.castShadow = true;
  TREES.list = [];

  const col = new THREE.Color();
  const variantCount = Math.max(1, TREES.authored.length);
  let ti = 0, ci = 0, li = 0;
  for (const spot of plan.trees) {
    const { x, z, s } = spot;
    const h = terrainH(x, z);
    // One species per grove: real stands are not a random mix, and it is what
    // lets the whole grove collapse into a single instanced batch.
    const variantIndex = spot.grove >= 0
      ? spot.grove % variantCount
      : Math.floor(Math.random() * variantCount);
    const moist = vnoise(x * 0.015 + 91, z * 0.015 + 43);
    const conifer = spot.grove >= 0 ? spot.grove % 2 === 0 : moist > 0.55;

    dummy.position.set(x, h + 1.1 * s, z);
    dummy.scale.setScalar(s);
    dummy.rotation.set(0, Math.random() * Math.PI, (Math.random() - 0.5) * 0.06); // slight natural lean
    dummy.updateMatrix();
    TREES.trunks.setMatrixAt(ti, dummy.matrix);
    col.setScalar(0.8 + Math.random() * 0.4); // bark tone varies per tree
    TREES.trunks.setColorAt(ti, col);

    if (TREES.authored.length) {
      const variant = TREES.authored[variantIndex];
      const instanceIndex = variant.count++;
      dummy.position.set(x, h, z);
      const authoredScale = s * (1.32 + Math.random() * 0.18);
      dummy.scale.set(authoredScale * (0.92 + Math.random() * 0.14), authoredScale, authoredScale * (0.92 + Math.random() * 0.14));
      dummy.rotation.set(0, Math.random() * Math.PI * 2, (Math.random() - 0.5) * 0.025);
      dummy.updateMatrix();
      for (const part of variant.parts) part.setMatrixAt(instanceIndex, dummy.matrix);
      TREES.list.push({
        x, z, s, kind: 'real', removed: false, grove: spot.grove,
        authoredVariant: variantIndex, canopyIdx: instanceIndex, trunkIdx: -1,
      });
      ti++;
      continue;
    }

    let canopyIdx;
    if (conifer) {
      // two stacked tiers — reads as a real fir
      col.setHSL(0.34 + (Math.random() - 0.5) * 0.045, 0.26 + Math.random() * 0.12, 0.25 + Math.random() * 0.08);
      dummy.position.y = h + 3.1 * s;
      dummy.scale.set(s * 1.08, s, s * (0.88 + Math.random() * 0.15));
      dummy.updateMatrix();
      TREES.cones.setMatrixAt(ci, dummy.matrix);
      TREES.cones.setColorAt(ci, col);
      dummy.position.y = h + 4.55 * s;
      dummy.scale.set(s * 0.98, s, s * (0.82 + Math.random() * 0.14));
      dummy.updateMatrix();
      TREES.cones2.setMatrixAt(ci, dummy.matrix);
      TREES.cones2.setColorAt(ci, col.clone().multiplyScalar(1.06));
      dummy.position.y = h + 5.8 * s;
      dummy.scale.set(s * 0.9, s, s * (0.78 + Math.random() * 0.14));
      dummy.updateMatrix();
      TREES.cones3.setMatrixAt(ci, dummy.matrix);
      TREES.cones3.setColorAt(ci, col.clone().multiplyScalar(1.1));
      canopyIdx = ci; ci++;
    } else {
      // main lobe + offset side lobe, occasional autumn tint
      const autumn = Math.random() < 0.12;
      col.setHSL(autumn ? 0.09 + Math.random() * 0.03 : 0.28 + (Math.random() - 0.5) * 0.06,
        0.28 + Math.random() * 0.14, 0.28 + Math.random() * 0.09);
      dummy.position.y = h + 3.1 * s;
      dummy.scale.set(s * (0.9 + Math.random() * 0.22), s * (0.78 + Math.random() * 0.2), s * (0.88 + Math.random() * 0.2));
      dummy.updateMatrix();
      TREES.leaves.setMatrixAt(li, dummy.matrix);
      TREES.leaves.setColorAt(li, col);
      const ang = Math.random() * Math.PI * 2;
      dummy.position.set(x + Math.cos(ang) * 1.1 * s, h + (2.4 + Math.random()) * s, z + Math.sin(ang) * 1.1 * s);
      dummy.scale.set(s * (0.76 + Math.random() * 0.2), s * (0.7 + Math.random() * 0.18), s * (0.78 + Math.random() * 0.2));
      dummy.updateMatrix();
      TREES.leaves2.setMatrixAt(li, dummy.matrix);
      TREES.leaves2.setColorAt(li, col.clone().multiplyScalar(0.9 + Math.random() * 0.25));
      const ang2 = ang + 2.1 + Math.random() * 1.1;
      dummy.position.set(x + Math.cos(ang2) * 0.95 * s, h + (3.4 + Math.random() * 0.7) * s, z + Math.sin(ang2) * 0.95 * s);
      dummy.scale.set(s * (0.68 + Math.random() * 0.18), s * (0.66 + Math.random() * 0.16), s * (0.7 + Math.random() * 0.18));
      dummy.updateMatrix();
      TREES.leaves3.setMatrixAt(li, dummy.matrix);
      TREES.leaves3.setColorAt(li, col.clone().multiplyScalar(0.92 + Math.random() * 0.18));
      canopyIdx = li; li++;
    }
    TREES.list.push({ x, z, s, kind: conifer ? 'cone' : 'leaf', removed: false, grove: spot.grove, trunkIdx: ti, canopyIdx });
    ti++;
  }
  if (TREES.authored.length) {
    TREES.trunks.count = 0;
    TREES.cones.count = TREES.cones2.count = TREES.cones3.count = 0;
    TREES.leaves.count = TREES.leaves2.count = TREES.leaves3.count = 0;
    for (const variant of TREES.authored) {
      for (const part of variant.parts) {
        part.count = variant.count;
        part.instanceMatrix.needsUpdate = true;
        part.computeBoundingSphere();
        // Spatial batches below own rendering; these are staging buffers.
      }
    }
  } else {
    TREES.trunks.count = ti;
    TREES.cones.count = ci; TREES.cones2.count = ci; TREES.cones3.count = ci;
    TREES.leaves.count = li; TREES.leaves2.count = li; TREES.leaves3.count = li;
    for (const m of [TREES.trunks, TREES.cones, TREES.cones2, TREES.cones3, TREES.leaves, TREES.leaves2, TREES.leaves3]) {
      if (m.instanceColor) m.instanceColor.needsUpdate = true;
    }
    scene.add(TREES.trunks);
    scene.add(TREES.cones); scene.add(TREES.cones2); scene.add(TREES.cones3);
    scene.add(TREES.leaves); scene.add(TREES.leaves2); scene.add(TREES.leaves3);
  }

  chunkAuthoredForest(scene);

  // grass tufts — thousands of blade clumps, one draw call, huge close-up realism.
  // Each instance is a quad with an alpha-tested texture of individual blades,
  // so tufts read as real grass instead of floating green rectangles.
  const N_GRASS = Math.round(2400 * scale);
  const bladeGeo = new THREE.PlaneGeometry(1.5, 0.85);
  bladeGeo.translate(0, 0.4, 0);
  const bladeMat = new THREE.MeshLambertMaterial({
    color: 0xffffff, side: THREE.DoubleSide,
    map: makeGrassBladeTexture(), alphaTest: 0.45,
  });
  windMaterial(bladeMat, 0.04);
  const grass = new THREE.InstancedMesh(bladeGeo, bladeMat, N_GRASS);
  const gCol = new THREE.Color();
  let gi = 0, gGuard = 0;
  while (gi < N_GRASS && gGuard++ < N_GRASS * 8) {
    const x = (Math.random() - 0.5) * (MAP_SIZE - 20);
    const z = (Math.random() - 0.5) * (MAP_SIZE - 20);
    const h = terrainH(x, z);
    if (h < 1.4 || h > 12) continue;
    const moist = vnoise(x * 0.015 + 91, z * 0.015 + 43);
    if (moist < 0.35 && Math.random() > 0.35) continue;
    dummy.position.set(x, h, z);
    dummy.rotation.set(0, Math.random() * Math.PI, 0);
    dummy.scale.setScalar(0.7 + Math.random() * 0.7);
    dummy.updateMatrix();
    grass.setMatrixAt(gi, dummy.matrix);
    // the blade texture is already green — tint with a light, barely-saturated
    // multiplier so tufts vary in brightness without going black
    gCol.setHSL(0.24 + Math.random() * 0.08, 0.12, 0.72 + Math.random() * 0.14);
    grass.setColorAt(gi, gCol);
    gi++;
  }
  grass.count = gi;
  if (grass.instanceColor) grass.instanceColor.needsUpdate = true;
  scene.add(grass);

  // Boulders. Previously these were sprinkled uniformly over the whole island,
  // which put bare grey lumps in the middle of open pasture where nothing would
  // weather them out of the ground. Real loose rock collects on steep slopes,
  // ridge lines and the storm-scoured strip just above the beach, so that is
  // where they go — fewer of them, and each one now reads as belonging there.
  const N_ROCKS = Math.round(110 * scale);
  const rockGeo = new THREE.DodecahedronGeometry(1, 0);
  const rockMat = new THREE.MeshLambertMaterial({ color: 0x8f8f88 });
  const rocks = new THREE.InstancedMesh(rockGeo, rockMat, N_ROCKS);
  const rockCol = new THREE.Color();
  let ri = 0, rGuard = 0;
  while (ri < N_ROCKS && rGuard++ < N_ROCKS * 14) {
    const x = (Math.random() - 0.5) * (MAP_SIZE - 20);
    const z = (Math.random() - 0.5) * (MAP_SIZE - 20);
    if (nearStart(x, z)) continue;
    const h = terrainH(x, z);
    if (h < 0.6) continue;
    const slope = Math.max(Math.abs(terrainH(x + 3, z) - h), Math.abs(terrainH(x, z + 3) - h));
    const wants = slope > 1.1 || h > 7 || h < 1.6;
    if (!wants && Math.random() > 0.12) continue;
    const s = 0.5 + Math.random() * 1.6;
    dummy.position.set(x, h + s * 0.3, z);
    dummy.scale.set(s, s * (0.6 + Math.random() * 0.5), s);
    dummy.rotation.set(Math.random(), Math.random(), Math.random());
    dummy.updateMatrix();
    rocks.setMatrixAt(ri, dummy.matrix);
    rockCol.setScalar(0.78 + Math.random() * 0.34); // no two boulders the same grey
    rocks.setColorAt(ri, rockCol);
    ri++;
  }
  rocks.count = ri;
  if (rocks.instanceColor) rocks.instanceColor.needsUpdate = true;
  scene.add(rocks);
}

/* Pulsing glow on radioactive / crystalline deposits (bloom breathes with
   them). Ore materials are shared across every deposit of a type, so this is
   two assignments per frame rather than a scene traversal per deposit. */
function updateDeposits(t) {
  const u = _depMats.get('uranium');
  if (u) u.emissiveIntensity = 0.85 + Math.sin(t * 2.4) * 0.45;
  const d = _depMats.get('diamond');
  if (d) d.emissiveIntensity = 0.45 + Math.sin(t * 3.1) * 0.18;
}

/* trees within radius r of a point (for chopping & build-blocking) */
function treesNear(x, z, r) {
  const out = [];
  for (const t of TREES.list) {
    if (!t.removed && dist2d(t.x, t.z, x, z) < r) out.push(t);
  }
  return out;
}
function removeTree(t) {
  if (t.removed) return;
  t.removed = true;
  _treeDummy.position.set(0, -1000, 0);
  _treeDummy.scale.setScalar(0.0001);
  _treeDummy.rotation.set(0, 0, 0);
  _treeDummy.updateMatrix();
  if (t.kind === 'real') {
    const parts = t.renderParts;
    if (!parts) return;
    for (const part of parts) {
      part.setMatrixAt(t.renderIndex, _treeDummy.matrix);
      part.instanceMatrix.needsUpdate = true;
    }
    return;
  }
  TREES.trunks.setMatrixAt(t.trunkIdx, _treeDummy.matrix);
  TREES.trunks.instanceMatrix.needsUpdate = true;
  const tiers = t.kind === 'cone'
    ? [TREES.cones, TREES.cones2, TREES.cones3]
    : [TREES.leaves, TREES.leaves2, TREES.leaves3];
  for (const canopy of tiers) {
    canopy.setMatrixAt(t.canopyIdx, _treeDummy.matrix);
    canopy.instanceMatrix.needsUpdate = true;
  }
}

/* lighting + atmosphere */
/* Resize the sun's shadow frustum to the area actually on screen. A fixed
   large box wastes almost all of the shadow map on off-screen ground, which is
   why distant-looking, blocky shadows are such a common giveaway. */
function setShadowExtent(sun, extent) {
  if (!sun || !sun.castShadow) return;
  if (Math.abs((sun.userData.shadowExtent || 0) - extent) < 4) return;
  sun.userData.shadowExtent = extent;
  const c = sun.shadow.camera;
  c.left = -extent; c.right = extent;
  c.top = extent; c.bottom = -extent;
  c.updateProjectionMatrix();
}

function buildLights(scene, highGfx) {
  scene.fog = new THREE.Fog(0xaebdca, 340, 920 + MAP_SIZE * 0.35);
  buildSky(scene);

  // Sky IBL plus this fill carry the ambient. Keeping the fill low and the sun
  // strong is what gives a scene readable form and shadow contrast instead of
  // the evenly-lit, flat look of a default web renderer.
  const hemi = new THREE.HemisphereLight(0xcfe0f0, 0x646c57, 0.85);
  scene.add(hemi);

  const sun = new THREE.DirectionalLight(0xfff1dc, 1.75);
  sun.position.set(120, 180, 60);
  {
    sun.castShadow = true;
    // 2048 over a shadow box that tightens as you zoom in: at close range the
    // map resolves to ~30 texels per world unit, so shadow edges stay crisp
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.near = 20; sun.shadow.camera.far = 620;
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.02;
    setShadowExtent(sun, 120);
    sun.castShadow = highGfx;
  }
  scene.add(sun);
  scene.add(sun.target);
  return sun;
}

/* gradient sky dome with a sun disc — tuned to play nicely with the
   bloom pass (the physical Sky shader blows out white against it) */
function buildSky(scene) {
  const geo = new THREE.SphereGeometry(2200, 24, 16);
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: {
      // The ocean is mostly a mirror at grazing angles, so the horizon colour
      // IS the colour of distant water. A near-white haze band made every sea
      // pixel past the shallows read as flat grey sheet metal.
      topColor: { value: new THREE.Color(0x2f66b2) },   // zenith blue
      midColor: { value: new THREE.Color(0x6f9fca) },   // sky
      botColor: { value: new THREE.Color(0xa6c1d8) },   // horizon haze
      sunDir:   { value: new THREE.Vector3(120, 180, 60).normalize() },
    },
    vertexShader: `
      varying vec3 vDir;
      void main() {
        vDir = normalize(position);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
    fragmentShader: `
      varying vec3 vDir;
      uniform vec3 topColor, midColor, botColor, sunDir;
      void main() {
        vec3 d = normalize(vDir);
        float h = clamp(d.y, -0.08, 1.0);
        vec3 col = mix(botColor, midColor, smoothstep(0.0, 0.16, h));
        col = mix(col, topColor, smoothstep(0.16, 0.6, h));
        float sunDot = max(dot(d, sunDir), 0.0);
        float disc = pow(sunDot, 350.0) * 1.8;   // the sun itself
        float halo = pow(sunDot, 12.0) * 0.28;   // warm glow around it
        col += vec3(1.0, 0.93, 0.78) * (disc + halo);
        gl_FragColor = vec4(col, 1.0);
      }`,
  });
  const sky = new THREE.Mesh(geo, mat);
  sky.name = 'sky';
  sky.renderOrder = -100;
  scene.add(sky);
  return sky;
}

/* find open water near a coastal building (for launching ships) */
function findWaterNear(x, z) {
  for (let r = 8; r < 60; r += 4) {
    for (let a = 0; a < Math.PI * 2; a += Math.PI / 10) {
      const wx = x + Math.cos(a) * r, wz = z + Math.sin(a) * r;
      if (Math.abs(wx) < HALF_MAP - 4 && Math.abs(wz) < HALF_MAP - 4 && isNavigable(wx, wz)) return [wx, wz];
    }
  }
  return null;
}
/* is there water close enough for a coastal building? */
function nearCoast(x, z, maxDist = 18) {
  for (let a = 0; a < Math.PI * 2; a += Math.PI / 8) {
    for (let r = 6; r <= maxDist; r += 4) {
      if (isNavigable(x + Math.cos(a) * r, z + Math.sin(a) * r)) return true;
    }
  }
  return false;
}
