// Extract existing embedded images into ordinary files so all supported
// browsers use the same image decoding path. No resampling or art changes.
const fs = require('node:fs');
const path = require('node:path');
const input = fs.readFileSync('assets/models/three/Soldier.glb');
const jsonLength = input.readUInt32LE(12);
const model = JSON.parse(input.subarray(20, 20 + jsonLength));
const binOffset = 20 + jsonLength;
const binary = input.subarray(binOffset + 8, binOffset + 8 + input.readUInt32LE(binOffset));
const output = 'assets/models/infantry';
fs.mkdirSync(output, { recursive: true });
for (const [i, image] of model.images.entries()) {
  const view = model.bufferViews[image.bufferView];
  image.uri = `texture-${i}.jpg`;
  fs.writeFileSync(path.join(output, image.uri), binary.subarray(view.byteOffset, view.byteOffset + view.byteLength));
  delete image.bufferView;
}
model.buffers[0].uri = 'infantry.bin';
fs.writeFileSync(path.join(output, 'infantry.bin'), binary);
fs.writeFileSync(path.join(output, 'infantry.gltf'), JSON.stringify(model));
