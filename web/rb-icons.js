/* ============================================================================
   RB-UI · icon layer  —  one icon set (Material Symbols Outlined)
   ----------------------------------------------------------------------------
   Resources feed icons as data (often legacy Font Awesome names from Lua
   config). This shim maps those to Material Symbol ligatures and renders a
   <span class="material-symbols-outlined">. Colors are intentionally NOT
   applied here — the design system is monochrome; status color is styled in
   CSS, never per-icon inline.

   Usage:
     el.appendChild(RBIcon.el('user'));            // -> <span class=material...>person</span>
     el.innerHTML = RBIcon.html('fa-solid fa-gear');
     RBIcon.name('trash')  // -> "delete"
   ========================================================================= */
(function (root) {
  // Font Awesome (and shorthand) name -> Material Symbols ligature
  var MAP = {
    // people / identity
    'user':'person','users':'group','user-tie':'support_agent','user-secret':'shield_person',
    'user-shield':'admin_panel_settings','user-plus':'person_add','user-minus':'person_remove',
    'user-injured':'personal_injury','circle-user':'account_circle','id-badge':'badge',
    'id-card':'badge','id-card-clip':'badge','person':'person','person-dress':'woman',
    'person-walking':'directions_walk','hat-cowboy':'man','face-grin-squint-tears':'sentiment_very_satisfied',
    'hand':'front_hand','masks-theater':'theater_comedy',
    // animals / world
    'paw':'pets','horse':'pets','horse-head':'pets','fire':'local_fire_department',
    'snowflake':'ac_unit','cloud-sun':'wb_sunny','location-dot':'location_on',
    'location-crosshairs':'my_location','map-location-dot':'map','door-open':'meeting_room',
    // combat / admin actions
    'ghost':'blur_on','shield-halved':'shield','heart-pulse':'monitor_heart','eye':'visibility',
    'eye-slash':'visibility_off','ban':'block','unlock':'lock_open','lock':'lock','up-down-left-right':'open_with',
    'briefcase-medical':'medical_services','book-bible':'auto_stories','keyboard':'keyboard',
    'rotate-left':'rotate_left','hashtag':'tag',
    // money / server / dev
    'money-bill':'payments','building-columns':'account_balance','server':'dns','code':'code',
    'ticket':'confirmation_number','gift':'card_giftcard','box':'inventory_2','socks':'checkroom',
    // documents / reports
    'clipboard':'content_paste','list':'list','tasks':'checklist','file-lines':'description',
    'align-left':'format_align_left','image':'image','comments':'forum','comment':'chat_bubble',
    'reply':'reply','bell':'notifications','info-circle':'info','circle-info':'info',
    'triangle-exclamation':'warning','circle-exclamation':'error','circle-check':'check_circle',
    // generic controls
    'plus':'add','minus':'remove','check':'check','xmark':'close','times':'close','trash':'delete',
    'chevron-right':'chevron_right','chevron-left':'chevron_left','chevron-up':'expand_less','chevron-down':'expand_more',
    'arrow-left':'arrow_back','arrow-right':'arrow_forward','right-from-bracket':'logout',
    'magnifying-glass':'search','search':'search','bolt':'bolt','gear':'settings','cog':'settings',
    'chess-rook':'castle','star':'star','heart':'favorite','house':'home','home':'home',
    'circle':'circle','circle-question':'help','question':'help','gauge':'speed','gauge-high':'speed',
    // media / playback
    'play':'play_arrow','pause':'pause','stop':'stop','music':'music_note','headphones':'headphones',
    'volume-high':'volume_up','volume-up':'volume_up','volume-low':'volume_down',
    'volume-off':'volume_off','volume-xmark':'volume_off','volume-mute':'volume_off',
    'forward':'fast_forward','backward':'fast_rewind','forward-step':'skip_next','backward-step':'skip_previous'
  };
  var FALLBACK = 'circle';

  // Normalize any incoming icon string to a Material Symbol ligature name.
  function name(icon) {
    if (!icon || typeof icon !== 'string') return null;
    icon = icon.trim();
    if (!icon) return null;
    // bare single word: a Font Awesome shorthand ("user") if mapped, else
    // assume it's already a Material ligature ("list", "settings").
    if (icon.indexOf('fa-') === -1 && icon.indexOf(' ') === -1 && icon.indexOf('-') === -1) {
      return MAP[icon] || icon;
    }
    // pull the meaningful token out of "fa-solid fa-user" / "fa-user" / "user"
    var m = icon.match(/fa-([a-z0-9-]+)/g);
    var base = icon;
    if (m && m.length) {
      base = m[m.length - 1].replace('fa-', '');       // last fa-* token is the glyph
      if (base === 'solid' || base === 'regular' || base === 'brands' || base === 'light') {
        base = m.length > 1 ? m[0].replace('fa-', '') : base;
      }
    } else {
      base = icon.split(' ').pop();
    }
    return MAP[base] || (base.replace(/-/g, '_')) || FALLBACK;
  }

  function el(icon, extraClass) {
    var span = document.createElement('span');
    span.className = 'material-symbols-outlined' + (extraClass ? ' ' + extraClass : '');
    span.textContent = name(icon) || FALLBACK;
    return span;
  }

  function html(icon, extraClass) {
    return '<span class="material-symbols-outlined' + (extraClass ? ' ' + extraClass : '') +
           '">' + (name(icon) || FALLBACK) + '</span>';
  }

  root.RBIcon = { name: name, el: el, html: html, MAP: MAP, FALLBACK: FALLBACK };
})(window);
