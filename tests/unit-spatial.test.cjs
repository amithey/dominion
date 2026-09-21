const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
function harness(units) {
  const c=vm.createContext({G:{units,buildings:[]},isAtWar:()=>true,canEngageTarget:()=>true});
  vm.runInContext(fs.readFileSync('js/unit-spatial.js','utf8'),c);
  const src=fs.readFileSync('js/entities.js','utf8');
  vm.runInContext(src.slice(src.indexOf('function nearestEnemy('),src.indexOf('/* shortest-arc')),c);
  c.index=vm.runInContext('UNIT_SPATIAL',c);return c;
}
test('spatial targets match the linear search across boundaries, ties, deaths and movement',()=>{
  const units=Array.from({length:400},(_,i)=>({x:(i%20)*13-130,z:Math.floor(i/20)*13-130,owner:i%3,dead:i%23===0}));
  units.push({x:1,z:0,owner:1},{x:-1,z:0,owner:1});
  const c=harness(units),attacker={x:0,z:0,owner:0};
  for(let step=0;step<4;step++) {
    c.index.rebuild(units);
    for(const radius of [2,16,35,90]) for(const u of [attacker,...units.slice(0,40)]) {
      c.index.ready=false;const expected=c.nearestEnemy(u,radius);
      c.index.ready=true;assert.equal(c.nearestEnemy(u,radius),expected);
    }
    units[3].x+=53;units[3].z-=27;units[4].dead=true;
    c.index.update(units[3]);c.index.update(units[4]);
    assert.ok(c.index.query(units[3].x,units[3].z,1).includes(units[3]));
    assert.ok(!c.index.query(units[4].x,units[4].z,1).includes(units[4]));
  }
});
test('spatial membership handles newly recruited units and revival without duplicates',()=>{
  const units=[{x:-.1,z:16,owner:0}],c=harness(units);c.index.rebuild(units);
  const recruit={x:16,z:-.1,owner:1};c.index.update(recruit);c.index.update(recruit);
  assert.equal(c.index.query(16,0,2).filter(u=>u===recruit).length,1);
  recruit.dead=true;c.index.update(recruit);recruit.dead=false;c.index.update(recruit);
  assert.equal(c.index.query(16,0,2).filter(u=>u===recruit).length,1);
});
test('distributed army proximity searches inspect less than 5% of all-pairs candidates',()=>{
  const units=Array.from({length:1600},(_,i)=>({x:(i%40)*12,z:Math.floor(i/40)*12,owner:i%2}));
  const c=harness(units);c.index.rebuild(units);
  for(const u of units) c.index.query(u.x,u.z,2);
  const ratio=c.index.visited/(units.length*units.length);
  assert.ok(ratio<.05,`candidate ratio ${ratio}`);
  console.log(`Proximity benchmark: ${c.index.visited} candidates vs ${units.length*units.length} full-scan candidates (${(ratio*100).toFixed(2)}%)`);
});
