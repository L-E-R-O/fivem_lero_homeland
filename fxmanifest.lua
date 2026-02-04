fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'LERO'
description 'HOMELAND SECURITY - Tactical Operations System'
version '3.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}

ui_page 'ui/homeland.html'

files {
    'ui/homeland.html',
    'ui/homeland.css',
    'ui/homeland.js'
}