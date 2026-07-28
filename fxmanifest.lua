fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'hexa_progbar - Hexa progress. Screen-fixed bottom-center bar only (icon/title/progress), vh-scaled, IBM Plex Sans Thai.'
author 'Hexa'
version '1.0.0'

ui_page 'web/index.html'

-- resource นี้อ่าน Config ทั้งสองฝั่ง จึงต้องใส่ config.lua ทั้ง client และ server
client_scripts {
    'config.lua',
    'client/client.lua',
}

server_scripts {
    'config.lua',
    'server/server.lua',
}

files {
    'web/index.html',
    'web/rb-ui.css',
    'web/style.css',
    'web/rb-icons.js',
    'web/app.js',
    'web/fonts/*.woff2',
}
