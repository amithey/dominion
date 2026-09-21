import * as ThreeCore from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
// Quaternius tank/ship packs ship as FBX only (no glTF), so vehicles load
// through this loader instead of converting formats offline.
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { Water } from 'three/addons/objects/Water.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
// OutputPass is mandatory once a composer is in play: it performs the tone
// mapping and sRGB conversion the renderer would otherwise do on its own.
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { SMAAPass } from 'three/addons/postprocessing/SMAAPass.js';

// Ambient occlusion is optional — if the addon ever fails to resolve the game
// still runs, just without contact shadows.
let GTAOPass = null;
try { ({ GTAOPass } = await import('three/addons/postprocessing/GTAOPass.js')); }
catch (e) { console.warn('GTAO unavailable — running without ambient occlusion.', e); }

// Keep the existing simulation/UI scripts intact while using modern ES modules.
window.THREE = {
  ...ThreeCore, mergeGeometries, GLTFLoader, FBXLoader, SkeletonUtils, Water, EffectComposer, RenderPass,
  ShaderPass, UnrealBloomPass, FXAAShader, RoomEnvironment, RoundedBoxGeometry,
  OutputPass, SMAAPass, GTAOPass,
};

const gameScripts = [
  'config.js', 'models.js', 'terrain-picking.js', 'forest-lod.js', 'world.js', 'path.js', 'territory.js', 'unit-spatial.js',
  'entities.js', 'battle-visuals.js', 'site-art.js', 'logistics.js', 'settlement-art.js', 'vehicle-art.js', 'diplomacy.js', 'ai.js', 'ui.js', 'performance.js', 'presentation.js', 'control-groups.js', 'review.js', 'main.js',
];

for (const file of gameScripts) {
  await new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `js/${file}?v=rts-foundation-2`;
    script.async = false;
    script.onload = resolve;
    script.onerror = () => reject(new Error(`Could not load ${file}`));
    document.body.appendChild(script);
  });
}
