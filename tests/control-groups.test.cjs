const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
test('control groups retain friendly survivors, merge selection and focus on double recall',()=>{
  let now=0,focus=null;const G={selection:[]};
  const c=vm.createContext({G,performance:{now:()=>now},notify(){},select:a=>G.selection=a,camFocus:{set:(...a)=>focus=a}});
  vm.runInContext(fs.readFileSync('js/control-groups.js','utf8'),c);
  const key=(k,opts={})=>c.handleControlGroup({key:k,preventDefault(){},...opts});
  const a={x:10,z:20,owner:0},b={x:30,z:40,owner:0},enemy={owner:1};G.selection=[a,b,enemy];
  key('1',{ctrlKey:true});G.selection=[];key('1');assert.equal(G.selection.length,2);
  now=200;key('1');assert.deepEqual(focus,[20,0,30]);
  b.dead=true;G.selection=[];now=1000;key('1');assert.deepEqual([...G.selection],[a]);
  const extra={x:5,z:6,owner:0};G.selection=[extra];key('1',{shiftKey:true});assert.deepEqual([...G.selection],[extra,a]);
  assert.equal(key('a'),false);assert.equal(key('1',{altKey:true}),false);
});
