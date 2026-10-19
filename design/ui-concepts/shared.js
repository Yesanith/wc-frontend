/* shared helpers for the Tyria Codex UI concepts. no framework, no network. */
(function () {
  const pad = (n) => String(n).padStart(2, '0');

  // the next daily reset is 00:00 UTC, the weekly one Monday 07:30 UTC
  function nextReset(kind, now) {
    const d = new Date(now);
    if (kind === 'daily') {
      return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1);
    }
    const day = (d.getUTCDay() + 6) % 7; // Monday = 0
    let t = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - day, 7, 30);
    if (t <= now) t += 7 * 864e5;
    return t;
  }

  function fmt(ms, style) {
    const s = Math.max(0, Math.floor(ms / 1000));
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    if (style === 'short') return d ? `${d}d ${pad(h)}h` : `${h}h ${pad(m)}m`;
    if (style === 'long') return d ? `${d}d ${pad(h)}h ${pad(m)}m` : `${pad(h)}:${pad(m)}:${pad(sec)}`;
    return `${pad(h + d * 24)}:${pad(m)}:${pad(sec)}`;
  }

  function tick() {
    const now = Date.now();
    document.querySelectorAll('[data-reset]').forEach((el) => {
      el.textContent = fmt(nextReset(el.dataset.reset, now) - now, el.dataset.fmt || 'hms');
    });
    // data-in="minutes" counts down from page load
    document.querySelectorAll('[data-in]').forEach((el) => {
      const end = (el._end ||= now + Number(el.dataset.in) * 60000);
      el.textContent = fmt(end - now, el.dataset.fmt || 'hms');
    });
    const clock = document.querySelector('[data-clock]');
    if (clock) clock.textContent = `${pad(new Date().getUTCHours())}:${pad(new Date().getUTCMinutes())} UTC`;
  }

  // 12345 copper -> 1g 23s 45c
  function coins() {
    document.querySelectorAll('[data-coin]').forEach((el) => {
      const v = Math.round(Number(el.dataset.coin));
      const g = Math.floor(v / 10000), s = Math.floor((v % 10000) / 100), c = v % 100;
      el.innerHTML =
        (g ? `<span class="cg">${g.toLocaleString('en')}<i>g</i></span>` : '') +
        (g || s ? `<span class="cs">${s}<i>s</i></span>` : '') +
        `<span class="cc">${c}<i>c</i></span>`;
    });
  }

  function sparks() {
    document.querySelectorAll('[data-spark]').forEach((el) => {
      const pts = el.dataset.spark.split(',').map(Number);
      const w = Number(el.dataset.w || 96), h = Number(el.dataset.h || 28);
      const lo = Math.min(...pts), hi = Math.max(...pts), span = hi - lo || 1;
      const xy = pts.map((p, i) => `${((i / (pts.length - 1)) * w).toFixed(1)},${(h - 3 - ((p - lo) / span) * (h - 6)).toFixed(1)}`);
      el.innerHTML = `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" fill="none" aria-hidden="true">` +
        `<polyline points="${xy.join(' ')}" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
    });
  }

  function fills() {
    requestAnimationFrame(() => document.querySelectorAll('[data-fill]').forEach((el) => (el.style.width = el.dataset.fill + '%')));
  }

  function views() {
    const btns = document.querySelectorAll('[data-view-btn]');
    const panels = document.querySelectorAll('[data-view]');
    if (!btns.length) return;
    const show = (name) => {
      panels.forEach((p) => (p.hidden = p.dataset.view !== name));
      btns.forEach((b) => {
        const on = b.dataset.viewBtn === name;
        b.classList.toggle('active', on);
        on ? b.setAttribute('aria-current', 'page') : b.removeAttribute('aria-current');
      });
      try { history.replaceState(null, '', '#' + name); } catch (_) {}
      window.scrollTo({ top: 0 });
    };
    btns.forEach((b) => b.addEventListener('click', (e) => { e.preventDefault(); show(b.dataset.viewBtn); }));
    const first = (location.hash || '').slice(1);
    show([...btns].some((b) => b.dataset.viewBtn === first) ? first : btns[0].dataset.viewBtn);
  }

  function pins() {
    document.querySelectorAll('[data-pin]').forEach((b) => b.addEventListener('click', () => {
      const on = b.getAttribute('aria-pressed') !== 'true';
      b.setAttribute('aria-pressed', on);
    }));
  }

  function chips() {
    document.querySelectorAll('[data-chips]').forEach((group) => group.querySelectorAll('button').forEach((b) => b.addEventListener('click', () => {
      group.querySelectorAll('button').forEach((x) => x.setAttribute('aria-pressed', x === b));
    })));
  }


  // icon sprite: <svg class="i"><use href="#i-home"/></svg>
  function sprite() {
    const s = document.createElement('div');
    s.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden';
    s.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg"><symbol id="i-home" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/></symbol><symbol id="i-boss" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 4.5l5 5-9 9-5-5z"/><path d="M4 20l3-3"/><path d="M13 7l4 4"/></symbol><symbol id="i-cal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/></symbol><symbol id="i-trophy" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M8 4h8v5a4 4 0 01-8 0z"/><path d="M8 6H4v2a3 3 0 003 3M16 6h4v2a3 3 0 01-3 3"/><path d="M12 13v4M8 20h8M10 17h4"/></symbol><symbol id="i-user" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/></symbol><symbol id="i-wallet" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="14" rx="2"/><path d="M3 10h18"/><circle cx="16.5" cy="14.5" r="1.2"/></symbol><symbol id="i-chart" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V5M4 20h16"/><path d="M8 15l4-4 3 3 5-6"/></symbol><symbol id="i-map" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4l-6 2v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/></symbol><symbol id="i-book" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h10a3 3 0 013 3v13H8a3 3 0 01-3-3z"/><path d="M5 17a3 3 0 013-3h10"/></symbol><symbol id="i-gear" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1"/></symbol><symbol id="i-search" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l5 5"/></symbol><symbol id="i-bell" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 17V11a6 6 0 0112 0v6l2 2H4z"/><path d="M10 21h4"/></symbol><symbol id="i-clock" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></symbol><symbol id="i-coins" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="9" cy="8" rx="6" ry="3"/><path d="M3 8v4c0 1.7 2.7 3 6 3s6-1.3 6-3V8"/><path d="M15 12.5c3 .2 6 1.3 6 2.7v3c0 1.7-2.7 3-6 3-2.2 0-4.1-.6-5.2-1.4"/></symbol><symbol id="i-shield" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/></symbol><symbol id="i-star" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.9L12 16.9 6.8 19.7l1-5.9L3.5 9.7l5.9-.8z"/></symbol><symbol id="i-pin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4h6l-1 6 3 3H7l3-3z"/><path d="M12 13v7"/></symbol><symbol id="i-flame" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3c1 4 5 5.5 5 10a5 5 0 01-10 0c0-2 1-3 2-4 .3 1.4 1 2 1.8 2.2C10.5 8 11 5.5 12 3z"/></symbol><symbol id="i-gem" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h12l3 5-9 11L3 9z"/><path d="M3 9h18M9 4l-1 5 4 11 4-11-1-5"/></symbol><symbol id="i-users" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 3-5.5 6.5-5.5s6.5 2 6.5 5.5"/><path d="M16 4.7a3.5 3.5 0 010 6.6M18 14.8c2 .6 3.5 2.2 3.5 5.2"/></symbol><symbol id="i-scroll" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h11v13a3 3 0 01-3 3H6"/><path d="M7 4a3 3 0 00-3 3v1h3"/><path d="M6 20a2 2 0 01-2-2v-1h11"/><path d="M10 9h5M10 13h5"/></symbol><symbol id="i-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></symbol><symbol id="i-up" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></symbol><symbol id="i-down" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></symbol><symbol id="i-swords" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4l9 9M4 4h5M4 4v5"/><path d="M20 4l-9 9M20 4h-5M20 4v5"/><path d="M8 17l-3 3M16 17l3 3"/></symbol><symbol id="i-crown" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/></symbol><symbol id="i-filter" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16l-6 8v6l-4-2v-4z"/></symbol><symbol id="i-menu" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M4 12h16M4 17h16"/></symbol><symbol id="i-dot" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/></symbol><symbol id="i-check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10"/></symbol></svg>';
    document.body.prepend(s);
  }

  document.addEventListener('DOMContentLoaded', () => {
    sprite(); coins(); sparks(); fills(); views(); pins(); chips(); tick();
    setInterval(tick, 1000);
  });
})();
