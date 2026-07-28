/* hexa_progbar — NUI front-end
   -------------------------------------------------------------------
   รูปแบบเดียว: แถบตรึงกลางจอด้านล่าง ขับด้วยข้อความจาก client:

     { action:'start',  payload:{ id,label,icon,duration,showRemaining,
                                  bottom,minWidth,maxWidth } }
     { action:'finish', id, ok }        -> ปิดรอบ (ok=false: ถูกยกเลิก)
     { action:'clear' }                 -> ล้างทุกอย่างทันที

   ไม่มีข้อความรายเฟรมเลย — ตำแหน่งเป็น CSS ล้วน (เดิมเป็นแถบลอยเกาะพิกัด
   ในโลก จึงต้องรับ x/y ที่ฉายแล้วมาทุกเฟรม ตอนนี้ตัดทิ้งทั้งเส้นทาง) ส่วน
   ที่วิ่งของแถบเป็น CSS animation ยาวเท่า `duration`

   ทุกขนาดคิดเป็น vh; ฟอนต์ + token มาจาก rb-ui.css */

(function () {
    'use strict';

    var dock = document.getElementById('rbp-dock');
    var liveRegion = document.getElementById('rbp-live');
    var runs = {};                   // id -> { el, endsAt, timeEl, raf }

    // rb-icons แปลงชื่อ Font Awesome แบบเก่าให้ ส่วน ligature ของ Material
    // ที่ถูกอยู่แล้วจะผ่านไปเฉย ๆ
    function iconEl(name, cls) {
        var el = (window.RBIcon && RBIcon.el)
            ? RBIcon.el(name || 'hourglass_top')
            : (function () {
                var s = document.createElement('span');
                s.className = 'material-symbols-outlined';
                s.textContent = name || 'hourglass_top';
                return s;
            })();
        var wrap = document.createElement('div');
        wrap.className = cls;
        wrap.appendChild(el);
        return wrap;
    }

    // animation-duration ของ fill ถูกเขียนตรงนี้เป็นค่า inline `!important`
    // และลำดับความสำคัญนั้นคือหัวใจ: rb-ui.css มี reduced-motion reset ระดับ
    // ทั้งไฟล์ — `*{ animation-duration:.01ms !important }` — ซึ่งเวลาระบบ
    // ขอ reduced motion (ปิด "เอฟเฟกต์ภาพเคลื่อนไหว" ใน Windows เป็นเรื่อง
    // ปกติมากบนเครื่องเล่นเกม) จะยุบ fill เหลือ .01ms แล้วมันจะเด้งไป 100%
    // ค้างทั้งรอบ ตัว fill คือ "ข้อมูล" ไม่ใช่ของประดับ มันจึงต้องรอด reset
    // นั้นให้ได้: การประกาศ inline แบบ !important ชนะ !important ใน
    // stylesheet ตาม cascade การใส่เป็นค่า ms ตรง ๆ (ไม่ใช่ var()) ยังทน
    // CEF ของ RedM ได้ดีกว่าด้วย ตั้งค่าก่อน element เข้า DOM เพื่อให้
    // animation เริ่มถูกตั้งแต่เฟรมแรก (ไม่มีอาการเต็มแป๊บ)
    function trackEl(cls, duration) {
        var track = document.createElement('div');
        track.className = 'rb-progress ' + cls;
        var fill = document.createElement('div');
        fill.className = 'rbp-fill';
        fill.style.setProperty('animation-duration', duration + 'ms', 'important');
        track.appendChild(fill);
        return track;
    }

    // ค่าตำแหน่ง/ขนาดมากับทุกรอบ เขียนลง dock เป็นตัวแปร CSS ตัวเดียวจบ
    // (เขียนซ้ำค่าเดิมทุกรอบไม่เสียอะไร — รอบหนึ่งมีข้อความ start ครั้งเดียว)
    function applyGeometry(p) {
        var num = function (v, fallback) {
            var n = Number(v);
            return isFinite(n) && n > 0 ? n : fallback;
        };
        dock.style.setProperty('--rbp-bottom', num(p.bottom, 12) + 'vh');
        dock.style.setProperty('--rbp-min-w', num(p.minWidth, 34) + 'vh');
        dock.style.setProperty('--rbp-max-w', num(p.maxWidth, 60) + 'vh');
    }

    // ---------------------------------------------------------------- build --
    function build(p) {
        var el = document.createElement('div');
        el.className = 'rbp-bar rbp-run is-entering';

        el.appendChild(iconEl(p.icon, 'rbp-bar__icon'));

        var body = document.createElement('div');
        body.className = 'rbp-bar__body';

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
        body.appendChild(trackEl('rbp-bar__track', p.duration));
        el.appendChild(body);

        dock.appendChild(el);

        // ถอด is-entering ในเฟรมถัดไป: ต้องให้เบราว์เซอร์ layout ตอนที่ยังมี
        // คลาสอยู่ก่อน ไม่งั้นไม่มีค่าเริ่มต้นให้ transition วิ่งจาก
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { el.classList.remove('is-entering'); });
        });

        return { el: el, timeEl: time };
    }

    // ---------------------------------------------------------------- clock --
    // rAF หนึ่งตัวต่อรอบ และเฉพาะรอบที่พิมพ์เวลาที่เหลือ ส่วน fill เป็น CSS
    function startClock(run) {
        if (!run.timeEl) return;
        var tick = function () {
            if (!runs[run.id]) return;
            var left = Math.max(0, run.endsAt - performance.now());
            var next = (left / 1000).toFixed(1) + 's';
            if (next !== run.lastText) {          // อย่าแตะ DOM ทุกเฟรม
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

    // ----------------------------------------------------------------- start --
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
            endsAt: performance.now() + p.duration,
            lastText: null,
            raf: null
        };
        runs[p.id] = run;
        startClock(run);

        if (p.label) liveRegion.textContent = p.label;
    }

    // ---------------------------------------------------------------- finish --
    function finish(id, ok) {
        var run = runs[id];
        if (!run) return;
        stopClock(run);

        // แช่ fill ไว้ก่อน: .rbp-run คือคลาสที่ขับ animation และสถานะ paused
        // ใน .rbp-cancelled จะอยู่ได้ก็ต่อเมื่อ animation ยังติดอยู่ ถ้าถอด
        // .rbp-run ตรงนี้ แถบจะดีดกลับไป scaleX(0)
        run.el.classList.add(ok ? 'rbp-done' : 'rbp-cancelled');
        if (run.timeEl && ok) run.timeEl.textContent = '0.0s';

        // ให้สถานะค้างให้อ่านสักครู่ แล้วค่อยออก
        setTimeout(function () { remove(id, false); }, ok ? 260 : 420);
    }

    function remove(id, now) {
        var run = runs[id];
        if (!run) return;
        stopClock(run);
        delete runs[id];

        var el = run.el;
        if (now) { el.remove(); return; }
        el.classList.add('is-leaving');
        setTimeout(function () { el.remove(); }, 260);
    }

    function clear() {
        Object.keys(runs).forEach(function (id) { remove(id, true); });
        liveRegion.textContent = '';
    }

    // ---------------------------------------------------------------- router --
    window.addEventListener('message', function (e) {
        var d = e.data || {};
        switch (d.action) {
            case 'start':  start(d.payload); break;
            case 'finish': finish(d.id, d.ok !== false); break;
            case 'clear':  clear(); break;
        }
    });
})();
