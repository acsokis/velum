/* VELUM's WebGL2 presentation bridge. Only two queried states are mirrored.
 * Emscripten's offscreen present reads SCISSOR_TEST and DRAW_FRAMEBUFFER_BINDING.
 * Synchronous readback stalls the GPU process; both states are already known
 * from the renderer's own enable/disable/bind calls. All other queries pass through.
 * Opt out with ?gpu-state-cache=off. No SDK files or browser settings are changed.
 */
(() => {
  if (new URLSearchParams(location.search).get('gpu-state-cache') === 'off') return;
  const originalGetContext = HTMLCanvasElement.prototype.getContext;
  const installed = new WeakSet();
  HTMLCanvasElement.prototype.getContext = function(type, ...args) {
    const gl = originalGetContext.call(this, type, ...args);
    if (this.id !== 'canvas' || type !== 'webgl2' || !gl || installed.has(gl)) return gl;
    installed.add(gl);
    const raw = {
      getParameter: gl.getParameter.bind(gl), enable: gl.enable.bind(gl),
      disable: gl.disable.bind(gl), bindFramebuffer: gl.bindFramebuffer.bind(gl),
      deleteFramebuffer: gl.deleteFramebuffer.bind(gl)
    };
    // One initial read handles installation even if another initializer touched GL.
    let scissor = raw.getParameter(gl.SCISSOR_TEST);
    let draw = raw.getParameter(gl.DRAW_FRAMEBUFFER_BINDING);
    let read = raw.getParameter(gl.READ_FRAMEBUFFER_BINDING);
    let lost = false;
    const state = {enabled: true, avoidedQueries: 0, mismatches: 0};
    gl.enable = function(cap) {raw.enable(cap);if(cap === gl.SCISSOR_TEST) scissor = true;};
    gl.disable = function(cap) {raw.disable(cap);if(cap === gl.SCISSOR_TEST) scissor = false;};
    gl.bindFramebuffer = function(target, framebuffer) {
      raw.bindFramebuffer(target,framebuffer);
      if(target === gl.FRAMEBUFFER || target === gl.DRAW_FRAMEBUFFER) draw = framebuffer;
      if(target === gl.FRAMEBUFFER || target === gl.READ_FRAMEBUFFER) read = framebuffer;
    };
    gl.deleteFramebuffer = function(framebuffer) {
      raw.deleteFramebuffer(framebuffer);
      if(framebuffer && draw === framebuffer) draw = null;
      if(framebuffer && read === framebuffer) read = null;
    };
    gl.getParameter = function(parameter) {
      if(state.enabled && !lost) {
        if(parameter === gl.SCISSOR_TEST) {state.avoidedQueries++;return scissor;}
        if(parameter === gl.DRAW_FRAMEBUFFER_BINDING) {state.avoidedQueries++;return draw;}
      }
      return raw.getParameter(parameter);
    };
    this.addEventListener('webglcontextlost',()=>{lost = true;});
    this.addEventListener('webglcontextrestored',()=>{lost = false;scissor = false;draw = null;read = null;});
    state.verify = () => {
      const ok = !lost && scissor === raw.getParameter(gl.SCISSOR_TEST)
        && draw === raw.getParameter(gl.DRAW_FRAMEBUFFER_BINDING)
        && read === raw.getParameter(gl.READ_FRAMEBUFFER_BINDING);
      if(!ok) {state.mismatches++;state.enabled = false;}
      return {ok,enabled:state.enabled,avoidedQueries:state.avoidedQueries,mismatches:state.mismatches};
    };
    window.velumPresentationCache = state;
    return gl;
  };
})();
