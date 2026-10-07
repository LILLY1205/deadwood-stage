fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'Mack'
description 'Deadwood Stage Line - Escort a stagecoach from Deadwood to destination'
version '1.0.0'

dependencies {
    'rsg-core',
    'bln_notify',
    'rsg-target'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/clipboard.png',
    'html/font/crock.ttf'
}

shared_scripts {
    'shared/locales.lua',
    'locales/en.lua',
    'config.lua',
    'shared/utils.lua'
}

server_scripts {
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

escrow_ignore {
    'shared/locales.lua',
    'locales/en.lua',
    'config.lua',
    'shared/utils.lua',
    'server/server.lua',
    'client/client.lua'
}

lua54 'yes'
