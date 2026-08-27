fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'hexa_progbar - Hexa progress. Screen-fixed bottom-center bar only (icon/title/description/progress + cancel key), vh-scaled, hexa_inventory design language.'
author 'Hexa'
version '1.1.0'

-- 🧹 CEF caches this page too: bump this ?v= together with the one in web/index.html
ui_page 'web/index.html?v=4'

-- 🖥️ Config is read on both sides, so config.lua ships to client and server
client_scripts {
    'config.lua',
    'client/client.lua',
}

server_scripts {
    'config.lua',
    'server/server.lua',
}

-- 📦 web/hexa-kit.css is left out on purpose - style.css stands alone
files {
    'web/index.html',
    'web/style.css',      -- 🎨 Theme + every component, tokens copied from hexa_inventory
    'web/hexa-icons.js',  -- ✏️ Inline SVG icons, no icon font file needed
    'web/app.js',
    'web/fonts/*.woff2',              -- 🔤 Kanit (latin + thai)
    'web/assets/RDRLino-Regular.ttf', -- 🅰️ Theme display font (same file as inventory)
}
