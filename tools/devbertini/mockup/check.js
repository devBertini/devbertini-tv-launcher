// Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
// Mockup self-check for HTML mockups of the home drawn at the launcher's 960x540 logical canvas (design options shown
// for review before a screen is built). Each mockup page loads it as the last element of <body> (copy this file
// beside the mockups, for example build/redesign/kit/). Opened with ?check=1 it waits for fonts and images, then
// writes a JSON report into
// <html data-check="...">, which render.sh reads back from Chrome's --dump-dom. It reports: fonts declared with
// @font-face that did not load, <img> that failed, text below 12 px, text boxes whose content overflows them,
// elements outside the 960x540 canvas (unless marked data-bleed), and the lowest text contrast found against a
// solid background (text over an image or a gradient is skipped and counted, since no single colour applies).
(function () {
  if (!/[?&]check=1/.test(location.search)) return;
  function rgba(s) {
    var m = /rgba?\(([^)]+)\)/.exec(s);
    if (!m) return null;
    var p = m[1].split(',').map(function (x) { return parseFloat(x); });
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function lum(c) {
    function ch(v) { v = v / 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }
  function mix(top, under) {
    var a = top.a;
    return { r: top.r * a + under.r * (1 - a), g: top.g * a + under.g * (1 - a), b: top.b * a + under.b * (1 - a), a: 1 };
  }
  function background(el) {
    // Looks at what is painted under the middle of the text (elementsFromPoint, so absolutely placed siblings count
    // too) down to the first solid colour; returns null when an image or a gradient lies on the way.
    var r = el.getBoundingClientRect();
    var stack = document.elementsFromPoint(r.left + r.width / 2, r.top + r.height / 2);
    var start = stack.indexOf(el);
    if (start < 0) start = 0;
    var layers = [];
    for (var i = start; i < stack.length; i++) {
      var n = stack[i];
      if (n !== el && el.contains(n)) continue;
      var cs = getComputedStyle(n);
      if (n.tagName === 'IMG' || n.tagName === 'svg' || n.tagName === 'CANVAS' || n.tagName === 'VIDEO') return null;
      if (cs.backgroundImage && cs.backgroundImage !== 'none') return null;
      var c = rgba(cs.backgroundColor);
      if (c && c.a > 0) {
        layers.push(c);
        if (c.a >= 0.999) break;
      }
    }
    if (!layers.length) return null;
    var base = layers[layers.length - 1];
    if (base.a < 0.999) return null;
    for (var i = layers.length - 2; i >= 0; i--) base = mix(layers[i], base);
    return base;
  }
  function textOwners() {
    var out = [];
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var t = walker.currentNode;
      if (!t.nodeValue.trim()) continue;
      var el = t.parentElement;
      if (!el || el.closest('script,style,[data-nocheck]')) continue;
      if (out.indexOf(el) < 0) out.push(el);
    }
    return out;
  }
  function label(el) {
    var s = el.tagName.toLowerCase();
    if (el.id) s += '#' + el.id;
    if (el.className && typeof el.className === 'string') s += '.' + el.className.trim().split(/\s+/).join('.');
    return s + ' "' + (el.textContent || '').trim().slice(0, 40) + '"';
  }
  function run() {
    var report = { fonts_failed: [], images_failed: [], small_text: [], overflow: [], outside: [], contrast_min: null,
      contrast_low: [], contrast_skipped: 0, text_count: 0 };
    document.fonts.forEach(function (f) { if (f.status !== 'loaded') report.fonts_failed.push(f.family + ' ' + f.weight + ' ' + f.status); });
    Array.prototype.forEach.call(document.images, function (img) {
      if (!img.complete || !img.naturalWidth) report.images_failed.push(img.getAttribute('src'));
    });
    textOwners().forEach(function (el) {
      report.text_count++;
      var cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) === 0) return;
      var size = parseFloat(cs.fontSize);
      if (size < 12) report.small_text.push(label(el) + ' ' + size + 'px');
      if (el.scrollWidth > el.clientWidth + 1 && /hidden|clip/.test(cs.overflowX + cs.overflow)) report.overflow.push(label(el) + ' width');
      if (el.scrollHeight > el.clientHeight + 1 && /hidden|clip/.test(cs.overflowY + cs.overflow)) report.overflow.push(label(el) + ' height');
      var bg = background(el);
      var fg = rgba(cs.color);
      if (!bg || !fg) { report.contrast_skipped++; return; }
      fg = mix(fg, bg);
      var l1 = lum(fg), l2 = lum(bg);
      var ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
      ratio = Math.round(ratio * 100) / 100;
      if (report.contrast_min === null || ratio < report.contrast_min) report.contrast_min = ratio;
      var large = size >= 18.66 || (size >= 14 && parseInt(cs.fontWeight, 10) >= 700);
      if (ratio < (large ? 3 : 4.5)) report.contrast_low.push(label(el) + ' ' + ratio);
    });
    Array.prototype.forEach.call(document.querySelectorAll('body *'), function (el) {
      if (el.closest('[data-bleed],script,style')) return;
      var r = el.getBoundingClientRect();
      if (!r.width || !r.height) return;
      if (r.left < -0.5 || r.top < -0.5 || r.right > 960.5 || r.bottom > 540.5) report.outside.push(label(el));
    });
    report.outside = report.outside.slice(0, 20);
    document.documentElement.setAttribute('data-check', JSON.stringify(report));
  }
  Promise.all([document.fonts.ready].concat(Array.prototype.map.call(document.images, function (img) {
    return img.complete ? Promise.resolve() : new Promise(function (ok) { img.onload = img.onerror = ok; });
  }))).then(function () { setTimeout(run, 50); });
})();
