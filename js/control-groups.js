'use strict';
const CONTROL_GROUPS = { slots: new Map(), lastSlot: null, lastTime: -Infinity };
function handleControlGroup(event) {
  if (!/^[1-9]$/.test(event.key) || event.altKey || event.metaKey) return false;
  event.preventDefault();
  if (event.repeat) return true;
  const slot = event.key, alive = entities => entities.filter(e=>!e.dead && e.owner===0);
  if(event.ctrlKey) {
    CONTROL_GROUPS.slots.set(slot, alive(G.selection));
    CONTROL_GROUPS.lastSlot=null;
    notify(`Group ${slot}: ${CONTROL_GROUPS.slots.get(slot).length} selected. Press ${slot} to recall; twice to focus.`, '', 3);
    return true;
  }
  const group=alive(CONTROL_GROUPS.slots.get(slot)||[]);
  CONTROL_GROUPS.slots.set(slot,group);
  if(!group.length) return true;
  const now=performance.now();
  select(event.shiftKey ? [...new Set([...alive(G.selection),...group])] : group);
  if(!event.shiftKey && CONTROL_GROUPS.lastSlot===slot && now-CONTROL_GROUPS.lastTime<350) {
    camFocus.set(group.reduce((sum,e)=>sum+e.x,0)/group.length,0,group.reduce((sum,e)=>sum+e.z,0)/group.length);
  }
  CONTROL_GROUPS.lastSlot=slot;CONTROL_GROUPS.lastTime=now;
  return true;
}
