/* Nocturnal's moving light.
 *
 * flow(canvas, palette): a slowly flowing, domain-warped gradient drawn with WebGL, in the app's own colours.
 *   Rendered at half resolution (it is all soft edges), only while on screen, and as one still frame for
 *   people who ask for reduced motion. Without WebGL the canvas stays empty and the CSS glows show instead.
 * trail(host): the hero's cursor trail, a soft grid of mint and night-blue cells that fade behind the words.
 */
(function () {
  "use strict";
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var coarse = matchMedia("(pointer: coarse)").matches;   // phones and tablets

  var PALETTES = {
    // [base, body, light, accent] as 0..1 RGB
    green: [[0.016, 0.09, 0.05], [0.063, 0.40, 0.23], [0.25, 0.84, 0.61], [0.23, 0.30, 0.60]],
    bold:  [[0.008, 0.06, 0.035], [0.05, 0.36, 0.20], [0.30, 0.90, 0.66], [0.33, 0.40, 0.85]],
    night: [[0.02, 0.03, 0.08], [0.09, 0.13, 0.28], [0.55, 0.61, 0.84], [0.25, 0.84, 0.61]],
    mint:  [[0.03, 0.16, 0.10], [0.10, 0.55, 0.36], [0.70, 0.95, 0.83], [0.17, 0.83, 0.75]],
  };

  var VERT = "attribute vec2 a; void main(){ gl_Position = vec4(a, 0.0, 1.0); }";
  // Smooth ribbons, not smoke: two gentle sine warps bend a few broad bands, and a little low-frequency noise
  // keeps them from repeating.
  var FRAG = [
    "precision mediump float;",
    "uniform vec2 r; uniform float t; uniform vec3 c0, c1, c2, c3; uniform float k;",
    "float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }",
    "float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);",
    "  return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }",
    "void main(){",
    "  vec2 uv = gl_FragCoord.xy / r; vec2 p = (uv - 0.5) * vec2(r.x / r.y, 1.0) * 1.45;",
    "  float s = t * 0.07;",
    "  p += 0.42 * vec2(sin(p.y * 2.1 + s * 1.3), cos(p.x * 1.7 - s));",
    "  p += 0.24 * vec2(sin(p.y * 3.4 - s * 0.8 + 1.3), cos(p.x * 2.8 + s * 0.9 + 2.1));",
    "  p += 0.30 * (vec2(n(p * 1.3 + s * 0.4), n(p * 1.3 + 7.1 - s * 0.4)) - 0.5);",
    "  float f = 0.5 + 0.5 * sin(p.y * 2.6 + 1.1 * sin(p.x * 1.2 + s) + s * 0.6);",
    "  float g = 0.5 + 0.5 * sin(p.x * 1.3 - p.y * 0.7 - s * 0.9 + 1.7);",
    "  vec3 col = mix(c0, c1, smoothstep(0.0, 0.8, f * 0.7 + g * 0.3));",
    "  col = mix(col, c2, k * smoothstep(0.7, 0.97, f) * smoothstep(0.25, 0.85, g));",
    "  col = mix(col, c3, k * 0.75 * smoothstep(0.72, 0.98, 1.0 - f) * smoothstep(0.35, 0.95, 1.0 - g));",
    "  gl_FragColor = vec4(col, 1.0);",
    "}"
  ].join("\n");

  function flow(canvas, name, strength, still) {
    var gl = canvas.getContext("webgl", { antialias: false, alpha: false, premultipliedAlpha: false, powerPreference: "low-power" });
    if (!gl) return;
    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null; }
    var vs = sh(gl.VERTEX_SHADER, VERT), fs = sh(gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) return;
    var prog = gl.createProgram(); gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return;
    gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, "a"); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    var u = {}; ["r", "t", "c0", "c1", "c2", "c3", "k"].forEach(function (x) { u[x] = gl.getUniformLocation(prog, x); });
    var pal = PALETTES[name] || PALETTES.green;
    for (var i = 0; i < 4; i++) gl.uniform3fv(u["c" + i], pal[i]);
    gl.uniform1f(u.k, strength == null ? 1 : strength);

    var seed = Math.random() * 100, visible = false, raf = 0, last = 0;
    function size() {
      var w = Math.max(1, Math.round(canvas.clientWidth * 0.5)), h = Math.max(1, Math.round(canvas.clientHeight * 0.5));
      if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; gl.viewport(0, 0, w, h); }
      gl.uniform2f(u.r, w, h);
    }
    function draw(ms) {
      size(); gl.uniform1f(u.t, seed + ms / 1000); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
    function loop(ms) {
      raf = 0;
      if (!visible) return;
      if (ms - last > 33) { draw(ms); last = ms; }   // about 30 frames a second is plenty for something this slow
      raf = requestAnimationFrame(loop);
    }
    canvas.classList.add("on");
    canvas.parentElement.classList.add("has-flow");
    if (reduce || still) { draw(12000); addEventListener("resize", function () { draw(12000); }); return; }
    new IntersectionObserver(function (e) {
      visible = e[0].isIntersecting;
      if (visible && !raf) raf = requestAnimationFrame(loop);
    }).observe(canvas);
  }

  function trail(host) {
    if (reduce || !matchMedia("(pointer: fine)").matches) return;
    var c = document.createElement("canvas"); c.className = "trail"; c.setAttribute("aria-hidden", "true");
    host.insertBefore(c, host.firstChild);
    var ctx = c.getContext("2d"), cells = [], CELL = 30, GAP = 3, LIFE = 1700, raf = 0, prev = null, step = 0, W = 0, H = 0;
    // Sharp, at the screen's own resolution: every cell a clean rounded square with a soft glow of its own colour.
    function fit() { var r = host.getBoundingClientRect(), d = Math.min(2, devicePixelRatio || 1); W = r.width; H = r.height; c.width = Math.ceil(W * d); c.height = Math.ceil(H * d); ctx.setTransform(d, 0, 0, d, 0, 0); }
    // The colour drifts smoothly along the trail through the app's greens: mint, emerald, teal, pale mint.
    function tint(i) { var h = 158 + 14 * Math.sin(i / 9), l = 58 + 12 * Math.sin(i / 13 + 1); return "hsl(" + h.toFixed(1) + " 72% " + l.toFixed(1) + "%)"; }
    function cell(gx, gy, color, alpha, shrink, glow) {
      var pad = GAP + shrink, x = gx * CELL + pad, y = gy * CELL + pad, sz = CELL - pad * 2;
      ctx.globalAlpha = alpha; ctx.fillStyle = color; ctx.shadowColor = color; ctx.shadowBlur = glow;
      ctx.beginPath(); if (ctx.roundRect) ctx.roundRect(x, y, sz, sz, 7); else ctx.rect(x, y, sz, sz); ctx.fill();
    }
    fit(); addEventListener("resize", fit);
    function add(x, y, now) {
      var gx = Math.floor(x / CELL), gy = Math.floor(y / CELL);
      for (var i = cells.length - 1; i >= Math.max(0, cells.length - 6); i--) if (cells[i].gx === gx && cells[i].gy === gy) { cells[i].born = now; return; }
      cells.push({ gx: gx, gy: gy, born: now, color: tint(step++) });
      if (step === 40) hint();
    }
    var cursor = { x: 0, y: 0 };
    host.addEventListener("pointermove", function (e) {
      var r = host.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top, now = performance.now();
      cursor.x = x; cursor.y = y;
      if (game) return;
      if (prev) {   // fill the gap between two samples so a quick flick still leaves an unbroken trail
        var dx = x - prev.x, dy = y - prev.y, steps = Math.ceil(Math.hypot(dx, dy) / (CELL * 0.6));
        for (var i = 1; i <= steps; i++) add(prev.x + dx * i / steps, prev.y + dy * i / steps, now);
      } else add(x, y, now);
      prev = { x: x, y: y };
      if (!raf) raf = requestAnimationFrame(frame);
    });
    host.addEventListener("pointerleave", function () { prev = null; });
    function frame(now) {
      raf = 0;
      if (game) return;
      ctx.clearRect(0, 0, W, H);
      cells = cells.filter(function (k) { return now - k.born < LIFE; });
      cells.forEach(function (k) {
        var a = 1 - (now - k.born) / LIFE, e = a * a * (3 - 2 * a);   // eased, so cells linger then go, shrinking as they fade
        cell(k.gx, k.gy, k.color, e * 0.95, (1 - e) * 7, 16 * e);
      });
      ctx.shadowBlur = 0;
      if (cells.length) raf = requestAnimationFrame(frame);
    }

    // ---------- Snake: click anywhere empty in the green, then steer with the cursor ----------
    var ui = host.querySelector("[data-snake]"), uiScore = ui.querySelector("[data-snake-score]"), uiMsg = ui.querySelector("[data-snake-msg]");
    var hintEl = host.querySelector("[data-snake-hint]"), game = null, best = 0;
    try { best = Number(localStorage.getItem("nocturnal.snake.best")) || 0; } catch (e) {}
    function hint() {
      try { if (localStorage.getItem("nocturnal.snake.hinted")) return; localStorage.setItem("nocturnal.snake.hinted", "1"); } catch (e) {}
      hintEl.classList.add("on"); setTimeout(function () { hintEl.classList.remove("on"); }, 4200);
    }
    var EMPTY = "a, button, input, code, pre, summary, h1, p, figure, .get, .top nav, .brand, .chip";
    host.addEventListener("click", function (e) {
      if (game && !game.over) return;
      if (!game && e.target.closest(EMPTY)) return;
      start();
    });
    addEventListener("keydown", function (e) { if (game && e.key === "Escape") stop(); });
    new IntersectionObserver(function (en) { if (!en[0].isIntersecting && game) stop(); }).observe(host);

    function free(x, y) { return !game.body.some(function (b) { return b.x === x && b.y === y; }); }
    function food() {
      for (var i = 0; i < 300; i++) {
        var x = game.x0 + 1 + Math.floor(Math.random() * (game.x1 - game.x0 - 1)), y = game.y0 + 1 + Math.floor(Math.random() * (game.y1 - game.y0 - 1));
        if (free(x, y)) return { x: x, y: y };
      }
      return { x: game.x0 + 1, y: game.y0 + 1 };
    }
    if (location.hash === "#snake-debug") window.__snake = function () { return game; };
    function start() {
      fit();
      // The field is the part of the green on screen, minus the row the score sits in.
      var r = host.getBoundingClientRect(), top = Math.max(0, -r.top), bottom = Math.min(H, innerHeight - r.top);
      var x0 = 0, x1 = Math.floor(W / CELL) - 1, y0 = Math.ceil(top / CELL) + 3, y1 = Math.floor(bottom / CELL) - 1;
      var hx = Math.min(x1 - 2, Math.max(x0 + 4, Math.floor(cursor.x / CELL))), hy = Math.min(y1 - 1, Math.max(y0 + 1, Math.floor(cursor.y / CELL)));
      game = { x0: x0, x1: x1, y0: y0, y1: y1, dir: { x: 1, y: 0 }, body: [], score: 0, over: false, last: 0, flash: 0 };
      for (var i = 0; i < 4; i++) game.body.push({ x: hx - i, y: hy });
      game.food = food();
      cells = []; host.classList.add("playing"); ui.hidden = false; ui.style.top = (game.y0 * CELL - 64) + "px"; hintEl.classList.remove("on");
      say(); cancelAnimationFrame(raf); raf = requestAnimationFrame(play);
    }
    function stop() {
      game = null; host.classList.remove("playing"); ui.hidden = true; ctx.clearRect(0, 0, W, H);
    }
    function say() {
      uiScore.textContent = String(game.score);
      uiMsg.textContent = game.over
        ? (game.score && game.score >= best ? "New best. Click to play again" : "Best " + best + ". Click to play again")
        : "Steer with your cursor · Esc to leave";
    }
    function turn() {
      var h = game.body[0], dx = Math.floor(cursor.x / CELL) - h.x, dy = Math.floor(cursor.y / CELL) - h.y, d = game.dir, want = d;
      if (Math.abs(dx) >= Math.abs(dy) && dx) want = { x: Math.sign(dx), y: 0 };
      else if (dy) want = { x: 0, y: Math.sign(dy) };
      if (want.x === -d.x && want.y === -d.y) {   // never straight back into itself: go round instead
        want = d.x ? { x: 0, y: Math.sign(dy) || 1 } : { x: Math.sign(dx) || 1, y: 0 };
      }
      game.dir = want;
    }
    function tick() {
      turn();
      var h = game.body[0], n = { x: h.x + game.dir.x, y: h.y + game.dir.y };
      var grows = n.x === game.food.x && n.y === game.food.y;
      var body = grows ? game.body : game.body.slice(0, -1);
      if (n.x < game.x0 || n.y < game.y0 || n.x > game.x1 || n.y > game.y1 || body.some(function (b) { return b.x === n.x && b.y === n.y; })) {
        game.over = true; game.flash = performance.now();
        if (game.score > best) { best = game.score; try { localStorage.setItem("nocturnal.snake.best", String(best)); } catch (e) {} }
        say(); return;
      }
      game.body.unshift(n);
      if (grows) { game.score++; game.food = food(); say(); } else game.body.pop();
    }
    function play(now) {
      raf = 0;
      if (!game) return;
      var every = Math.max(55, 110 - game.score * 3);   // a little faster with every bite
      if (!game.over && now - game.last >= every) { tick(); game.last = now; }
      ctx.clearRect(0, 0, W, H);
      ctx.globalAlpha = 0.35; ctx.strokeStyle = "rgba(255,255,255,.5)"; ctx.lineWidth = 1.5; ctx.shadowBlur = 0;
      ctx.beginPath(); if (ctx.roundRect) ctx.roundRect(game.x0 * CELL + 1, game.y0 * CELL + 1, (game.x1 - game.x0 + 1) * CELL - 2, (game.y1 - game.y0 + 1) * CELL - 2, 18); ctx.stroke();
      var pulse = 0.5 + 0.5 * Math.sin(now / 180);
      cell(game.food.x, game.food.y, "#f4fff9", 0.75 + 0.25 * pulse, 2 + pulse * 2, 18 + 10 * pulse);
      var fade = game.over ? Math.max(0.25, 1 - (now - game.flash) / 900) : 1;
      for (var i = game.body.length - 1; i >= 0; i--) {
        var b = game.body[i];
        cell(b.x, b.y, i === 0 ? "#e6fff4" : tint(i * 3), fade * (i === 0 ? 1 : 0.92), i === 0 ? 0 : Math.min(4, i * 0.15), i === 0 ? 20 : 12);
      }
      ctx.shadowBlur = 0;
      raf = requestAnimationFrame(play);
    }
  }

  document.querySelectorAll("canvas[data-flow]").forEach(function (cv) {
    flow(cv, cv.dataset.flow, cv.dataset.k ? Number(cv.dataset.k) : 1, cv.hasAttribute("data-small") && coarse);
  });
  var hero = document.querySelector("[data-trail]");
  if (hero) trail(hero);
})();
