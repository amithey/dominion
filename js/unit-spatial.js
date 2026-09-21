'use strict';

// Broad-phase only: combat and movement still apply their original exact
// distance/domain/diplomacy rules. Updated after each unit moves, so later
// units see current positions rather than a stale start-of-frame snapshot.
class UnitSpatialIndex {
  constructor(cellSize = 16) {
    this.cellSize = cellSize; this.cells = new Map(); this.members = new Map();
    this.order = new Map(); this.ready = false; this.visited = 0; this.queries = 0;
  }
  key(x,z) { return `${Math.floor(x/this.cellSize)},${Math.floor(z/this.cellSize)}`; }
  rebuild(units) {
    this.cells.clear(); this.members.clear(); this.order.clear();
    this.visited = this.queries = 0;
    units.forEach((u,i)=>{ this.order.set(u,i); this.update(u); });
    this.ready = true;
  }
  update(u) {
    const previous=this.members.get(u), next=u.dead?null:this.key(u.x,u.z);
    if(previous===next) return;
    if(previous!==undefined) {
      const cell=this.cells.get(previous);cell?.delete(u);
      if(cell?.size===0) this.cells.delete(previous);
      this.members.delete(u);
    }
    if(next===null) return;
    if(!this.order.has(u)) this.order.set(u,this.order.size);
    if(!this.cells.has(next)) this.cells.set(next,new Set());
    this.cells.get(next).add(u);this.members.set(u,next);
  }
  query(x,z,radius) {
    const result=[], size=this.cellSize;this.queries++;
    for(let cz=Math.floor((z-radius)/size);cz<=Math.floor((z+radius)/size);cz++)
      for(let cx=Math.floor((x-radius)/size);cx<=Math.floor((x+radius)/size);cx++) {
        const cell=this.cells.get(`${cx},${cz}`);if(!cell) continue;
        for(const u of cell) {this.visited++;if(!u.dead) result.push(u);}
      }
    // Preserve simulation order, including equal-distance target selection.
    return result.sort((a,b)=>this.order.get(a)-this.order.get(b));
  }
}
const UNIT_SPATIAL = new UnitSpatialIndex();
