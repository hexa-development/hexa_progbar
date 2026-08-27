/* 🖼️ hexa_progbar NUI - one screen-fixed bar driven by start / finish / clear messages */

(function () {
    'use strict';

    var dock = document.getElementById('rbp-dock');
    var liveRegion = document.getElementById('rbp-live');
    var runs = {};                   // 🗂️ id -> { el, endsAt, timeEl, markEl, stateEl, raf }

    // 🔤 State words on the bar - the result is spelled out, not signalled by color alone
    var STATE = {
        running:   { text: 'กำลังดำเนินการ' },
        done:      { text: 'สำเร็จ',        icon: 'check' },
        cancelled: { text: 'ยกเลิกแล้ว',    icon: 'close' }
    };

    // ⏲️ Ask CSS for the leave duration, so the timing lives in exactly one place
    function cssMs(name, fallback) {
        var raw = getComputedStyle(document.documentElement)
            .getPropertyValue(name).trim();
        var n = parseFloat(raw);
        if (!isFinite(n)) return fallback;
        return /ms\s*$/.test(raw) ? n : n * 1000;   // 🔁 Accepts both '.18s' and '180ms'
    }
    var LEAVE_MS = cssMs('--rbp-out', 180) + 30;

    // ✏️ HexaIcon takes central, Font Awesome and Material names alike
    function iconSvg(name) {
        var key = (name && window.HexaIcon && HexaIcon.name(name)) ? name : 'hourglass';
        return HexaIcon.el(key, '');
    }

    // 🔲 Icon slot - the <svg> inside is swapped for a tick or a cross when the run ends
    function markEl(name) {
        var box = document.createElement('div');
        box.className = 'rbp-bar__mark';
        box.appendChild(iconSvg(name));
        return box;
    }

    // 🧹 Looped removal, not replaceChildren() - RedM ships CEF builds older than Chrome 86
    function setMark(box, name) {
        if (!box) return;
        while (box.firstChild) box.removeChild(box.firstChild);
        box.appendChild(iconSvg(name));
    }

    // 🏷️ Key cap comes straight from Lua, so the printed key is always the one that works
    function cancelEl(cancel) {
        var wrap = document.createElement('div');
        wrap.className = 'rbp-bar__cancel';

        var cap = document.createElement('span');
        cap.className = 'rbp-key';
        cap.textContent = cancel.key || '?';

        var txt = document.createElement('span');
        txt.className = 'rbp-bar__cancel-txt';
        txt.textContent = cancel.label || '';

        wrap.appendChild(cap);
        wrap.appendChild(txt);
        return wrap;
    }

    // 📊 Fill is set once and then driven by the compositor, !important shields it from resets
    function trackEl(duration) {
        var track = document.createElement('div');
        track.className = 'rbp-track';

        var fill = document.createElement('span');
        fill.className = 'rbp-track__fill';
        fill.style.setProperty('animation-duration', duration + 'ms', 'important');

        track.appendChild(fill);
        return track;
    }

    // 📐 Geometry arrives with every run and lands on the dock as CSS variables
    function applyGeometry(p) {
        var num = function (v, fallback) {
            var n = Number(v);
            return isFinite(n) && n > 0 ? n : fallback;
        };
        dock.style.setProperty('--rbp-bottom', num(p.bottom, 12) + 'vh');
        dock.style.setProperty('--rbp-min-w', num(p.minWidth, 34) + 'vh');
        dock.style.setProperty('--rbp-max-w', num(p.maxWidth, 60) + 'vh');
    }

    // 🧱 Layout: [icon] state ── [KEY] cancel / rule / title ── seconds / subtitle / track
    function build(p) {
        var el = document.createElement('div');
        el.className = 'rbp-bar is-entering';

        var mark = markEl(p.icon);
        el.appendChild(mark);

        var body = document.createElement('div');
        body.className = 'rbp-bar__body';

        // 🔝 Top row: state label + cancel key cap
        var meta = document.createElement('div');
        meta.className = 'rbp-bar__meta';

        var state = document.createElement('div');
        state.className = 'rbp-bar__state';
        state.textContent = STATE.running.text;
        meta.appendChild(state);

        // ↔️ Cap sits on this row, so a long title clips with … instead of pushing it out
        if (p.cancel) meta.appendChild(cancelEl(p.cancel));
        body.appendChild(meta);

        var rule = document.createElement('div');
        rule.className = 'rbp-bar__rule';
        body.appendChild(rule);

        // 📝 Title row: task name + remaining seconds
        var head = document.createElement('div');
        head.className = 'rbp-bar__head';
        var title = document.createElement('div');
        title.className = 'rbp-bar__title';
        title.textContent = p.label || '';
        head.appendChild(title);

        var time = null;
        if (p.showRemaining) {
            time = document.createElement('div');
            time.className = 'rbp-bar__time';
            head.appendChild(time);
        }
        body.appendChild(head);

        // 📄 Subtitle gets its own line rather than being glued onto the title
        if (p.description) {
            var sub = document.createElement('div');
            sub.className = 'rbp-bar__sub';
            sub.textContent = p.description;
            body.appendChild(sub);
        }

        el.appendChild(body);

        // 📊 Track lives outside the body - it spans the whole panel, not just the text column
        el.appendChild(trackEl(p.duration));

        dock.appendChild(el);

        // 🎬 Drop is-entering a frame later, so the transition has a start value to run from
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { el.classList.remove('is-entering'); });
        });

        return { el: el, timeEl: time, markEl: mark, stateEl: state };
    }

    // ⏱ One rAF per run, and only for runs that print the remaining seconds
    function startClock(run) {
        if (!run.timeEl) return;
        var tick = function () {
            if (!runs[run.id]) return;
            var left = Math.max(0, run.endsAt - performance.now());
            var next = (left / 1000).toFixed(1) + 's';
            if (next !== run.lastText) {          // 🚧 Do not touch the DOM every frame
                run.timeEl.textContent = next;
                run.lastText = next;
            }
            if (left > 0) run.raf = requestAnimationFrame(tick);
        };
        run.raf = requestAnimationFrame(tick);
    }

    function stopClock(run) {
        if (run.raf) cancelAnimationFrame(run.raf);
        run.raf = null;
    }

    // ▶️ Open a run
    function start(p) {
        if (!p || !p.id) return;
        if (runs[p.id]) remove(p.id, true);

        p.duration = Math.max(1, Number(p.duration) || 5000);
        applyGeometry(p);
        var built = build(p);

        var run = {
            id: p.id,
            el: built.el,
            timeEl: built.timeEl,
            markEl: built.markEl,
            stateEl: built.stateEl,
            endsAt: performance.now() + p.duration,
            lastText: null,
            raf: null
        };
        runs[p.id] = run;
        startClock(run);

        if (p.label) liveRegion.textContent = p.label;
    }

    // 🏁 Close a run
    function finish(id, ok) {
        var run = runs[id];
        if (!run) return;
        stopClock(run);

        var s = ok ? STATE.done : STATE.cancelled;

        // 🎨 One class flips --c, so icon, tick, seconds, state and track recolor together
        run.el.classList.add(ok ? 'rbp-done' : 'rbp-cancelled');

        // ✅ Word and icon carry the result too, color is only the third signal
        if (run.stateEl) run.stateEl.textContent = s.text;
        setMark(run.markEl, s.icon);

        if (run.timeEl && ok) run.timeEl.textContent = '0.0s';

        // ⏳ Hold the end state long enough to read it, longer when it is bad news
        setTimeout(function () { remove(id, false); }, ok ? 460 : 640);
    }

    function remove(id, now) {
        var run = runs[id];
        if (!run) return;
        stopClock(run);
        delete runs[id];

        var el = run.el;
        if (now) { el.remove(); return; }
        el.classList.add('is-leaving');
        setTimeout(function () { el.remove(); }, LEAVE_MS);
    }

    function clear() {
        Object.keys(runs).forEach(function (id) { remove(id, true); });
        liveRegion.textContent = '';
    }

    // 📨 Message router
    window.addEventListener('message', function (e) {
        var d = e.data || {};
        switch (d.action) {
            case 'start':  start(d.payload); break;
            case 'finish': finish(d.id, d.ok !== false); break;
            case 'clear':  clear(); break;
        }
    });

    // 🧪 Browser preview only - loops all three states outside CEF, silent in game
    (function demo() {
        if (/CitizenFX/i.test(navigator.userAgent)) return;
        document.body.style.background = 'var(--ink-void)';
        var samples = [
            { label:'กำลังขุด',   icon:'pickaxe', duration:6000, ok:true  },
            { label:'กำลังเติมน้ำ', icon:'pill',    duration:4200, ok:false,
              description:'3 / 10 หน่วย' },
            { label:'กำลังตัดฟืน', icon:'axe',     duration:5200, ok:true  }
        ];
        var i = 0;
        (function step() {
            var s = samples[i % samples.length];
            var id = 'demo' + (i++);
            window.postMessage({ action:'start', payload:{
                id:id, label:s.label, description:s.description, icon:s.icon,
                duration:s.duration, showRemaining:true,
                cancel:{ key:'X', label:'ยกเลิก' } } }, '*');
            // ⏹️ Close early on some samples, so both end states show up
            window.setTimeout(function () {
                window.postMessage({ action:'finish', id:id, ok:s.ok }, '*');
            }, s.duration * (s.ok ? 1 : .55));
            window.setTimeout(step, s.duration + 1100);
        })();
    })();
})();
