import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const source=readFileSync(new URL('../web/presentation-state.js',import.meta.url),'utf8');
function fixture(search='') {
  const actual={scissor:false,draw:null,read:null,lost:false,queries:0};
  const gl={SCISSOR_TEST:3089,FRAMEBUFFER:36160,DRAW_FRAMEBUFFER:36009,READ_FRAMEBUFFER:36008,DRAW_FRAMEBUFFER_BINDING:36006,READ_FRAMEBUFFER_BINDING:36010,
    getParameter(p){actual.queries++;if(actual.lost)return null;return p===3089?actual.scissor:p===36006?actual.draw:p===36010?actual.read:'delegated';},
    enable(p){if(p===3089)actual.scissor=true;},disable(p){if(p===3089)actual.scissor=false;},
    bindFramebuffer(target,fb){if(target===36160||target===36009)actual.draw=fb;if(target===36160||target===36008)actual.read=fb;},
    deleteFramebuffer(fb){if(actual.draw===fb)actual.draw=null;if(actual.read===fb)actual.read=null;}
  };
  class Canvas {constructor(){this.id='canvas';this.events={};}getContext(){return gl;}addEventListener(name,fn){this.events[name]=fn;}}
  const window={};vm.runInNewContext(source,{HTMLCanvasElement:Canvas,window,location:{search},URLSearchParams});
  const canvas=new Canvas();canvas.getContext('webgl2');return {gl,actual,cache:window.velumPresentationCache,canvas};
}
test('presentation cache preserves scissor and independent read/draw framebuffer bindings',()=>{
  const {gl,actual,cache}=fixture();const initial=actual.queries;
  gl.enable(gl.SCISSOR_TEST);assert.equal(gl.getParameter(gl.SCISSOR_TEST),true);
  const a={},b={};gl.bindFramebuffer(gl.FRAMEBUFFER,a);gl.bindFramebuffer(gl.READ_FRAMEBUFFER,b);
  assert.equal(gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING),a);
  assert.equal(actual.queries,initial);assert.equal(cache.verify().ok,true);
  gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER,b);gl.disable(gl.SCISSOR_TEST);gl.deleteFramebuffer(b);
  assert.equal(gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING),null);assert.equal(cache.verify().ok,true);
  assert.equal(gl.getParameter(999),'delegated');
});
test('state divergence disables caching instead of returning stale GL state',()=>{
  const {gl,actual,cache}=fixture();actual.scissor=true;
  assert.equal(cache.verify().ok,false);assert.equal(cache.enabled,false);
  assert.equal(gl.getParameter(gl.SCISSOR_TEST),true);assert.equal(cache.mismatches,1);
});
test('lost contexts delegate to WebGL and restored contexts reset mirrors',()=>{
  const {gl,actual,cache,canvas}=fixture();gl.enable(gl.SCISSOR_TEST);
  actual.lost=true;canvas.events.webglcontextlost();assert.equal(gl.getParameter(gl.SCISSOR_TEST),null);
  actual.lost=false;actual.scissor=false;actual.draw=null;actual.read=null;canvas.events.webglcontextrestored();
  assert.equal(cache.verify().ok,true);
});
test('explicit opt-out leaves the original GL methods untouched',()=>{
  const {gl,actual,cache}=fixture('?gpu-state-cache=off');assert.equal(cache,undefined);
  const before=actual.queries;gl.getParameter(gl.SCISSOR_TEST);assert.equal(actual.queries,before+1);
});
